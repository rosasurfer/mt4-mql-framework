/**
 *
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Offered.Symbols = "LFX";                // die anzubietenden Symbole (kommagetrennt): LFX = alle LFX-Symbole

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#include <MT4iQuickChannel.mqh>
#include <etc/offline/QuoteServer.mqh>

#property indicator_chart_window


// Serverdaten
string servedSymbols          [];                     // die angebotenen Symbole
string qc.SubscriptionChannels[];                     // die dazugehörenden Subscription-Channels
int   hQC.Receivers           [];                     // die zu den Channels gehörenden Receiver-Handles

// Subscriberdaten
string  qc.Subscribers  [];                           // die Backchannel der Subscriber
int    hQC.Senders      [];                           // die zu den Backchanneln gehörenden Sender-Handles
int    hQC.hWnds        [];                           // die zu den Subscribern gehörenden Fenster-Handles (für Quote-Updates)
int    subscribedSymbols[];                           // Indizes des jeweils registrierten Symbols in servedSymbols[]


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // TODO: (1) Receiver erst starten, wenn neue Kurse vorliegen, damit ein alternativer QuoteServer den Feed übernehmen kann.
   // TODO: (2) Ist bereits ein anderer QuoteServer online, diesen QuoteServer dort als QuoteClient registrieren.

   if (!This.IsTesting()) {
      // Parameter-Validierung
      // Offered.Symbols                              // "LFX, USDX, EURX"
      string values[], value;
      int size = Explode(Offered.Symbols, ",", values, NULL);

      for (int i=0; i < size; i++) {
         value = StrTrim(values[i]);
         if (value == "LFX") {
            if (!AddSymbol("AUDLFX")) return(last_error);
            if (!AddSymbol("CADLFX")) return(last_error);
            if (!AddSymbol("CHFLFX")) return(last_error);
            if (!AddSymbol("EURLFX")) return(last_error);
            if (!AddSymbol("GBPLFX")) return(last_error);
            if (!AddSymbol("JPYLFX")) return(last_error);
            if (!AddSymbol("NZDLFX")) return(last_error);
            if (!AddSymbol("USDLFX")) return(last_error);
         }
         else if (!AddSymbol(value))  return(last_error);
      }
      ArrayResize(values, 0);
   }
   return(last_error);
}


/**
 * Prüft, ob die für das angegebene Symbol notwendigen Instrumente geladen sind und fügt es zur Liste der vom QuoteServer angebotenen
 * Symbole hinzu.
 *
 * @param  string symbol
 *
 * @return bool - Erfolgsstatus
 */
bool AddSymbol(string symbol) {
   if (!StringLen(symbol))
      return(catch("AddSymbol(1)  invalid parameter symbol = "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER));

   if (StringInArray(servedSymbols, symbol))
      return(true);

   string lfx.symbols[] = { "AUDLFX", "CADLFX", "CHFLFX", "EURLFX", "GBPLFX", "JPYLFX", "NZDLFX", "USDLFX" };
   string lfx.pairs  [] = { "AUDUSD", "USDCAD", "USDCHF", "EURUSD", "GBPUSD", "USDJPY" };

   string ice.symbols[] = { "EURX", "USDX" };
   string eurx.pairs [] = { "EURUSD", "EURCHF", "EURGBP", "EURJPY", "EURSEK" };
   string usdx.pairs [] = { "EURUSD", "GBPUSD", "USDCAD", "USDCHF", "USDJPY", "USDSEK" };

   int error;


   // (1) LFX-Indizes
   if (StringInArray(lfx.symbols, symbol)) {
      int size = ArraySize(lfx.pairs);
      for (int i=0; i < size; i++) {
         MarketInfo(lfx.pairs[i], MODE_TICKSIZE);
         error = GetLastError(); if (IsError(error)) return(!catch("AddSymbol(2)  "+ symbol +" requires "+ lfx.pairs[i] +" data", error));
      }
      if (symbol == "NZDLFX") {
         MarketInfo("NZDUSD", MODE_TICKSIZE);
         error = GetLastError(); if (IsError(error)) return(!catch("AddSymbol(3)  "+ symbol +" requires NZDUSD data", error));
      }
   }


   // (2) ICE-Indizes
   else if (symbol == "EURX") {
      size = ArraySize(eurx.pairs);
      for (i=0; i < size; i++) {
         MarketInfo(eurx.pairs[i], MODE_TIME);
         error = GetLastError(); if (IsError(error)) return(!catch("AddSymbol(4)  "+ symbol +" requires "+ eurx.pairs[i] +" data", error));
      }
   }
   else if (symbol == "USDX") {
      size = ArraySize(usdx.pairs);
      for (i=0; i < size; i++) {
         MarketInfo(usdx.pairs[i], MODE_TICKSIZE);
         error = GetLastError(); if (IsError(error)) return(!catch("AddSymbol(5)  "+ symbol +" requires "+ usdx.pairs[i] +" data", error));
      }
   }
   else return(!catch("AddSymbol(6)  unsupported symbol = \""+ symbol +"\"", ERR_INVALID_CONFIG_VALUE));


   // (3) Subscription-Daten initialisieren, Channel: "MetaTrader::QuoteServer::{Symbol}"
   ArrayPushString(servedSymbols,           symbol                             );
   ArrayPushString(qc.SubscriptionChannels, "MetaTrader::QuoteServer::"+ symbol);
   ArrayPushInt   (hQC.Receivers,           NULL                               );

   return(true);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // (1) Preis-Updates an alle aktiven Subscriber schicken
   if (!ProcessQuoteUpdates()) return(last_error);

   // (2) eingehende Messages in den Subscription-Channels verarbeiten
   if (!ProcessMessages())     return(last_error);

   // (3) regelmäßig prüfen, ob die Subscriber noch online sind
   return(last_error);
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   // (1) alle Subscription-Channels verlassen
   StopReceivers();

   // (2) allen aktiven Subscribern Unsubscribe-Benachrichtigung schicken (löscht sie)
   UnsubscribeAll();

   // (3) alle Backchannel verlassen (sofern nicht schon geschehen)
   StopSenders();
   return(last_error);
}


/**
 * Berechnet und speichert die Preis-Updates der angebotenen Symbole und benachrichtigt die entsprechenden Subscriber.
 *
 * @return bool - Erfolgsstatus
 */
bool ProcessQuoteUpdates() {
   return(true);
}


/**
 * Verarbeitet eingehende Messages in den Subscription-Channels.
 *
 * @return bool - Erfolgsstatus
 */
bool ProcessMessages() {
   string messageBuffer[]; if (!ArraySize(messageBuffer)) InitializeStringBuffer(messageBuffer, QC_MAX_BUFFER_SIZE);
   int    size = ArraySize(hQC.Receivers);

   for (int i=0; i < size; i++) {
      // (1) Channel auf neue Messages prüfen
      int checkResult = QC_CheckChannel(qc.SubscriptionChannels[i]);
      if (checkResult == QC_CHECK_CHANNEL_EMPTY)
         continue;
      if (checkResult < QC_CHECK_CHANNEL_EMPTY) {
         if (checkResult == QC_CHECK_CHANNEL_ERROR)  return(!catch("ProcessMessages(1)->MT4iQuickChannel::QC_CheckChannel(ch=\""+ qc.SubscriptionChannels[i] +"\") => QC_CHECK_CHANNEL_ERROR",                ERR_WIN32_ERROR));
         if (checkResult == QC_CHECK_CHANNEL_NONE )  return(!catch("ProcessMessages(2)->MT4iQuickChannel::QC_CheckChannel(ch=\""+ qc.SubscriptionChannels[i] +"\")  channel doesn't exist",                   ERR_WIN32_ERROR));
                                                     return(!catch("ProcessMessages(3)->MT4iQuickChannel::QC_CheckChannel(ch=\""+ qc.SubscriptionChannels[i] +"\")  unexpected return value = "+ checkResult, ERR_WIN32_ERROR));
      }

      if (!hQC.Receivers[i]) /*&&*/ if (!StartReceiver(i)) return(false);

      // (2) neue Messages abholen
      int getResult = QC_GetMessages3(hQC.Receivers[i], messageBuffer, QC_MAX_BUFFER_SIZE);
      if (getResult != QC_GET_MSG3_SUCCESS) {
         if (getResult == QC_GET_MSG3_CHANNEL_EMPTY) return(!catch("ProcessMessages(4)->MT4iQuickChannel::QC_GetMessages3()  QuickChannel mis-match: QC_CheckChannel="+ checkResult +"chars/QC_GetMessages3=CHANNEL_EMPTY", ERR_WIN32_ERROR));
         if (getResult == QC_GET_MSG3_INSUF_BUFFER ) return(!catch("ProcessMessages(5)->MT4iQuickChannel::QC_GetMessages3()  QuickChannel mis-match: QC_CheckChannel="+ checkResult +"chars/QC_MAX_BUFFER_SIZE="+ QC_MAX_BUFFER_SIZE +"/size(buffer)="+ (StringLen(messageBuffer[0])+1) +"/QC_GetMessages3=INSUF_BUFFER", ERR_WIN32_ERROR));
                                                     return(!catch("ProcessMessages(6)->MT4iQuickChannel::QC_GetMessages3()  unexpected return value = "+ getResult, ERR_WIN32_ERROR));
      }

      // (3) Messages verarbeiten
      string msgs[], terms[], sValue, backChannel, msgId, msg;
      int    msgsSize=Explode(messageBuffer[0], TAB, msgs, NULL), termsSize, hWndSubscriber;

      for (int j=0; j < msgsSize; j++) {
         if (!StringLen(msgs[j]))
            continue;
         debug("ProcessMessages(7)  received "+ servedSymbols[i] +" msg \""+ msgs[j] +"\"");

         termsSize = Explode(msgs[j], "|", terms, 5);

         // (4.1) "Subscribe|{HWND}|{BackChannelName}"
         if (terms[0] == "Subscribe") {
            if (termsSize < 3)             { warn("ProcessMessages(8)  received invalid "+ servedSymbols[i] +" message \""+ msgs[j] +"\" (missing parameters)"); continue; }
            // HWND
            sValue = terms[1];
            if (!StrIsDigit(sValue))       { warn("ProcessMessages(9)  invalid HWND value in "+ servedSymbols[i] +" message \""+ msgs[j] +"\" (non-digits)");    continue; }
            hWndSubscriber = StrToInteger(sValue);
            if (!IsWindow(hWndSubscriber)) { warn("ProcessMessages(10)  invalid HWND in "+ servedSymbols[i] +" message \""+ msgs[j] +"\" (not a window)");       continue; }
            // BackChannelName
            backChannel = terms[2];
            if (!StringLen(backChannel))   { warn("ProcessMessages(11)  invalid backchannel name in "+ servedSymbols[i] +" message \""+ msgs[j] +"\" (empty)");  continue; }

            // prüfen, ob auf dem angegebenen Backchannel ein Receiver online ist
            int result = QC_ChannelHasReceiver(backChannel);
            if (result < 0) return(!catch("ProcessMessages(12)->MT4iQuickChannel::QC_ChannelHasReceiver(ch=\""+ backChannel +"\") => "+ ifString(result==QC_CHECK_CHANNEL_ERROR, "QC_CHECK_CHANNEL_ERROR", result), ERR_WIN32_ERROR));
            if (result != QC_CHECK_RECEIVER_OK) {
               debug("ProcessMessages(13)  no receiver auf backchannel \""+ backChannel +"\", ignoring message \""+ msgs[j] +"\"");
               continue;
            }

            // Subscriber speichern
            ArrayPushString( qc.Subscribers  , backChannel   );
            ArrayPushInt   (hQC.Senders      , NULL          );
            ArrayPushInt   (hQC.hWnds        , hWndSubscriber);
            ArrayPushInt   (subscribedSymbols, i             );
            debug("ProcessMessages(14)  added "+ servedSymbols[i] +" subscription for 0x"+ IntToHexStr(hWndSubscriber));
            continue;
         }

         // (4.2) "Unsubscribe|{HWND}"
         if (terms[0] == "Unsubscribe") {
            if (termsSize < 2)       { warn("ProcessMessages(15)  received invalid "+ servedSymbols[i] +" message \""+ msgs[j] +"\" (missing parameters)"); continue; }
            // HWND
            sValue = terms[1];
            if (!StrIsDigit(sValue)) { warn("ProcessMessages(16)  invalid HWND value in "+ servedSymbols[i] +" message \""+ msgs[j] +"\" (non-digits)");    continue; }
            hWndSubscriber = StrToInteger(sValue);

            int n = SearchIntArray(hQC.hWnds, hWndSubscriber);
            if (n == -1)             { warn("ProcessMessages(17)  unknown subscriber in "+ servedSymbols[i] +" unsubscribe message \""+ msgs[j] +"\"");     continue; }

            // Backchannel schließen und Subscriber löschen
            if (!StopSender(n)) return(false);
            ArraySpliceStrings( qc.Subscribers  , n, 1);
            ArraySpliceInts   (hQC.Senders      , n, 1);
            ArraySpliceInts   (hQC.hWnds        , n, 1);
            ArraySpliceInts   (subscribedSymbols, n, 1);
            debug("ProcessMessages(18)  removed "+ servedSymbols[i] +" subscription for 0x"+ IntToHexStr(hWndSubscriber));
            continue;
         }
         warn("ProcessMessages(19)  received unsupported "+ servedSymbols[i] +" message \""+ msgs[j] +"\"");
      }

      ArrayResize(msgs,  0);
      ArrayResize(terms, 0);
   }
   return(true);
}


/**
 * Started den Sender für den Backchannel des angegebenen Suscribers.
 *
 * @param  int i - Index des Subscribers
 *
 * @return bool - Erfolgsstatus
 */
bool StartSender(int i) {
   int size = ArraySize(hQC.Senders);
   if (i < 0)     return(!catch("StartSender(1)  invalid parameter i = "+ i, ERR_INVALID_PARAMETER));
   if (i >= size) return(!catch("StartSender(2)  invalid parameter i = "+ i +" (max. "+ (size-1) +")", ERR_INVALID_PARAMETER));

   if (!hQC.Senders[i]) {
      hQC.Senders[i] = QC_StartSender(qc.Subscribers[i]);
      if (!hQC.Senders[i]) return(!catch("StartSender(3)->MT4iQuickChannel::QC_StartSender(ch=\""+ qc.Subscribers[i] +"\")", ERR_WIN32_ERROR));
      debug("StartSender(4)  sender on \""+ qc.Subscribers[i] +"\" for "+ servedSymbols[subscribedSymbols[i]] +" started");
   }
   return(true);
}


/**
 * Stoppt den Sender für den Backchannel des angegebenen Suscribers.
 *
 * @param  int i - Index des Subscribers
 *
 * @return bool - Erfolgsstatus
 */
bool StopSender(int i) {
   int size = ArraySize(hQC.Senders);
   if (i < 0)     return(!catch("StopSender(1)  invalid parameter i = "+ i, ERR_INVALID_PARAMETER));
   if (i >= size) return(!catch("StopSender(2)  invalid parameter i = "+ i +" (max. "+ (size-1) +")", ERR_INVALID_PARAMETER));

   if (hQC.Senders[i] != NULL) {
      int hTmp = hQC.Senders[i];
                 hQC.Senders[i] = NULL;                              // Handle zurücksetzen, um mehrfache Stopversuche bei Fehlern zu verhindern
      if (!QC_ReleaseSender(hTmp)) return(!catch("StopSender(3)->MT4iQuickChannel::QC_ReleaseSender(ch=\""+ qc.Subscribers[i] +"\")  error stopping sender", ERR_WIN32_ERROR));
      debug("StopSender(4)  sender on \""+ qc.Subscribers[i] +"\" for "+ servedSymbols[subscribedSymbols[i]] +" stopped");
   }
   return(true);
}


/**
 * Started den Receiver für den Suscription-Channel des angegebenen Symbols.
 *
 * @param  int i - Index des vom QuoteServer angebotenen Symbols
 *
 * @return bool - Erfolgsstatus
 */
bool StartReceiver(int i) {
   int size = ArraySize(hQC.Receivers);
   if (i < 0)     return(!catch("StartReceiver(1)  invalid parameter i = "+ i, ERR_INVALID_PARAMETER));
   if (i >= size) return(!catch("StartReceiver(2)  invalid parameter i = "+ i +" (max. "+ (size-1) +")", ERR_INVALID_PARAMETER));

   if (!hQC.Receivers[i]) {
      // TODO: Prüfen, ob bereits ein Receiver (= alternativer QuoteServer) auf dem Channel existiert und in diesem Fall nach "waiting" verzweigen
      int hWnd = __ExecutionContext[EC.hChart];
      hQC.Receivers[i] = QC_StartReceiver(qc.SubscriptionChannels[i], hWnd);
      if (!hQC.Receivers[i]) return(!catch("StartReceiver(3)->MT4iQuickChannel::QC_StartReceiver(ch=\""+ qc.SubscriptionChannels[i] +"\", hWnd="+ IntToHexStr(hWnd) +") => 0", ERR_WIN32_ERROR));
      debug("StartReceiver(4)  receiver on \""+ qc.SubscriptionChannels[i] +"\" started");
   }
   return(true);
}


/**
 * Stopped den Receiver für den Suscription-Channel des angegebenen Symbols.
 *
 * @param  int i - Index des vom QuoteServer angebotenen Symbols
 *
 * @return bool - Erfolgsstatus
 */
bool StopReceiver(int i) {
   int size = ArraySize(hQC.Receivers);
   if (i < 0)     return(!catch("StopReceiver(1)  invalid parameter i = "+ i, ERR_INVALID_PARAMETER));
   if (i >= size) return(!catch("StopReceiver(2)  invalid parameter i = "+ i +" (max. "+ (size-1) +")", ERR_INVALID_PARAMETER));

   if (hQC.Receivers[i] != NULL) {
      int hTmp = hQC.Receivers[i];
                 hQC.Receivers[i] = NULL;                            // Handle zurücksetzen, um mehrfache Stopversuche bei Fehlern zu verhindern
      if (!QC_ReleaseReceiver(hTmp)) return(!catch("StopReceiver(3)->MT4iQuickChannel::QC_ReleaseReceiver(ch=\""+ qc.SubscriptionChannels[i] +"\")  error stopping receiver", ERR_WIN32_ERROR));
      debug("StopReceiver(4)  receiver on \""+ qc.SubscriptionChannels[i] +"\" stopped");
   }
   return(true);
}


/**
 * Stoppt alle aktiven Sender.
 *
 * @return bool - Erfolgsstatus
 */
bool StopSenders() {
   int size = ArraySize(hQC.Senders);
   for (int i=0; i < size; i++) {
      if (!StopSender(i)) return(false);
   }
   return(true);
}


/**
 * Stoppt alle aktiven Receiver.
 *
 * @return bool - Erfolgsstatus
 */
bool StopReceivers() {
   int size = ArraySize(hQC.Receivers);
   for (int i=0; i < size; i++) {
      if (!StopReceiver(i)) return(false);
   }
   return(true);
}


/**
 * Schickt allen aktiven Subscribern eine Unsubscribe-Benachrichtigung und löscht sie.
 *
 * @return bool - Erfolgsstatus
 */
bool UnsubscribeAll() {
   int size = ArraySize(qc.Subscribers);

   for (int i=size-1; i>=0; i--) {                                   // RÜCKWÄRTS, da die Arrays beim Löschen des Subscribers modifiziert werden.
      // prüfen, ob der Subscriber noch online ist
      int result = QC_ChannelHasReceiver(qc.Subscribers[i]);
      if (result < 0) return(!catch("UnsubscribeAll(1)->MT4iQuickChannel::QC_ChannelHasReceiver(ch=\""+ qc.Subscribers[i] +"\") => "+ ifString(result==QC_CHECK_CHANNEL_ERROR, "QC_CHECK_CHANNEL_ERROR", result), ERR_WIN32_ERROR));

      if (result == QC_CHECK_RECEIVER_OK) {
         // Unsubscribe-Message zusammenstellen: "QuoteServer|{HWND}|Unsubscribed|{Reason}"
         int hWndSubscriber = hQC.hWnds[i];
         string msg = "QuoteServer|"+ hWndSubscriber +"|Unsubscribed|deinit";

         // Unsubscribe-Message verschicken
         if (!StartSender(i)) return(false);
         if (!QC_SendMessage(hQC.Senders[i], msg, NULL))
            return(!catch("UnsubscribeAll(2)->MT4iQuickChannel::QC_SendMessage(ch=\""+ qc.Subscribers[i] +"\", msg=\""+ msg +"\", flags=NULL) => QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));
         debug("UnsubscribeAll(3)  message \""+ msg +"\" sent");
      }

      // Backchannel schließen und Subscriber löschen
      int iSymbol = subscribedSymbols[i];
      if (!StopSender(i)) return(false);
      ArraySpliceStrings( qc.Subscribers  , i, 1);
      ArraySpliceInts   (hQC.Senders      , i, 1);
      ArraySpliceInts   (hQC.hWnds        , i, 1);
      ArraySpliceInts   (subscribedSymbols, i, 1);
      debug("UnsubscribeAll(4)  removed "+ servedSymbols[iSymbol] +" subscription for 0x"+ IntToHexStr(hWndSubscriber));
   }
   return(true);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Offered.Symbols=", DoubleQuoteStr(Offered.Symbols), ";"));
}
