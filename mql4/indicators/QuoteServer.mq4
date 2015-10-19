/**
 *
 */
#property indicator_chart_window
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>

#include <MT4iQuickChannel.mqh>
#include <offline/QuoteServer.mqh>


#define SERVER_STATUS_STOPPED    0
#define SERVER_STATUS_STARTED    1

int       status;

string    symbols             [];                                    // die angebotenen Symbole
string qc.SubscriptionChannels[];                                    // die dazugehörenden Subscription-Channels
int   hQC.Receivers           [];                                    // die zu den Channels gehörenden Receiver-Handles

string qc.Subscribers[];                                             // die Back-Channel der aktuellen Subscriber
int   hQC.Senders    [];                                             // die zu den Back-Channels gehörenden Sender-Handles
int   hQC.hWnds      [];                                             // die zu den Subscribern gehörenden Fenster-Handles (für Quote-Updates)


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   if (!This.IsTesting()) {
      // ggf. QuoteServer starten
      if (status != SERVER_STATUS_STARTED) {

         // Subscription-Channels initialisieren: "MetaTrader::QuoteServer::{Symbol}"
         ArrayPushString(    symbols,              Symbol()                             );
         ArrayPushString( qc.SubscriptionChannels, "MetaTrader::QuoteServer::"+ Symbol());
         ArrayPushInt   (hQC.Receivers,            NULL                                 );

         ArrayPushString(    symbols,              "AUDLFX"                             );
         ArrayPushString( qc.SubscriptionChannels, "MetaTrader::QuoteServer::AUDLFX"    );
         ArrayPushInt   (hQC.Receivers,            NULL                                 );

         if (!QuoteServer.Start()) return(last_error);
      }
   }
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (status == SERVER_STATUS_STARTED) {
      // (1) Preis-Updates an die jeweiligen Subscriber schicken

      // (2) eingehende Messages in den Subscription-Channels verarbeiten
      if (!ProcessMessages()) return(last_error);

      // (3) regelmäßig prüfen, ob die Subscriber noch online sind
   }
   return(last_error);
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   return(last_error);
}


/**
 * Startet den QuoteServer.
 *
 * @return bool - Erfolgsstatus
 */
bool QuoteServer.Start() {
   if (status == SERVER_STATUS_STARTED)
      return(false);

   // TODO: (1) Receiver erst starten, wenn neue Kurse vorliegen, damit ein alternativer QuoteServer den Feed übernehmen kann.
   // TODO: (2) Ist bereits ein anderer QuoteServer online, diesen QuoteServer dort als QuoteClient registrieren.

   if (!QC.StartReceivers())
      return(false);

   status = SERVER_STATUS_STARTED;
   return(true);
}


/**
 * Verarbeitet eingehende Messages in den Subscription-Channels.
 *
 * @return bool - Erfolgsstatus
 */
bool ProcessMessages() {
   int size = ArraySize(symbols);

   // Messagebuffer initialisieren
   string messageBuffer[]; if (!ArraySize(messageBuffer)) InitializeStringBuffer(messageBuffer, QC_MAX_BUFFER_SIZE);


   // auf den Subscription-Channels eingehende Messages verarbeiten
   for (int i=0; i < size; i++) {
      // (1) ggf. Receiver starten
      if (!hQC.Receivers[i]) /*&&*/ if (!StartReceiver(i))
         return(false);

      // (2) Channel auf neue Messages prüfen
      int result = QC_CheckChannel(qc.SubscriptionChannels[i]);
      if (result < QC_CHECK_CHANNEL_EMPTY) {
         if (result == QC_CHECK_CHANNEL_ERROR)    return(!catch("ProcessMessages(1)->MT4iQuickChannel::QC_CheckChannel(ch=\""+ qc.SubscriptionChannels[i] +"\") => QC_CHECK_CHANNEL_ERROR",           ERR_WIN32_ERROR));
         if (result == QC_CHECK_CHANNEL_NONE )    return(!catch("ProcessMessages(2)->MT4iQuickChannel::QC_CheckChannel(ch=\""+ qc.SubscriptionChannels[i] +"\")  channel doesn't exist",              ERR_WIN32_ERROR));
                                                  return(!catch("ProcessMessages(3)->MT4iQuickChannel::QC_CheckChannel(ch=\""+ qc.SubscriptionChannels[i] +"\")  unexpected return value = "+ result, ERR_WIN32_ERROR));
      }
      if (result == QC_CHECK_CHANNEL_EMPTY)
         continue;

      // (3) neue Messages abholen
      result = QC_GetMessages3(hQC.Receivers[i], messageBuffer, QC_MAX_BUFFER_SIZE);
      if (result != QC_GET_MSG3_SUCCESS) {
         if (result == QC_GET_MSG3_CHANNEL_EMPTY) return(!catch("ProcessMessages(4)->MT4iQuickChannel::QC_GetMessages3()  QC_CheckChannel not empty/QC_GET_MSG3_CHANNEL_EMPTY mismatch",           ERR_WIN32_ERROR));
         if (result == QC_GET_MSG3_INSUF_BUFFER ) return(!catch("ProcessMessages(5)->MT4iQuickChannel::QC_GetMessages3()  buffer to small (QC_MAX_BUFFER_SIZE/QC_GET_MSG3_INSUF_BUFFER mismatch)", ERR_WIN32_ERROR));
                                                  return(!catch("ProcessMessages(6)->MT4iQuickChannel::QC_GetMessages3()  unexpected return value = "+ result,                                     ERR_WIN32_ERROR));
      }

      // (4) Messages verarbeiten
      string msgs[], terms[], sValue, backChannel, msgId, msg;
      int    msgsSize=Explode(messageBuffer[0], TAB, msgs, NULL), termsSize, hWnd, n;

      for (int j=0; j < msgsSize; j++) {
         if (!StringLen(msgs[j]))
            continue;
         debug("ProcessMessages(7)  received "+ symbols[i] +" msg \""+ msgs[j] +"\"");

         termsSize = Explode(msgs[j], "|", terms, 5);

         // (4.1) "Subscribe|{HWND}|{BackChannelName}|{ChannelMsgId}"
         if (terms[0] == "Subscribe") {
            if (termsSize < 4)           { warn("ProcessMessages(8)  received invalid "+ symbols[i] +" message \""+ msgs[j] +"\" (missing parameters)"); continue; }
            sValue      = terms[1];
            if (!StringIsDigit(sValue))  { warn("ProcessMessages(9)  invalid HWND value in "+ symbols[i] +" message \""+ msgs[j] +"\" (non-digits)");    continue; }
            hWnd = StrToInteger(sValue);
            if (!IsWindow(hWnd))         { warn("ProcessMessages(10)  invalid HWND in "+ symbols[i] +" message \""+ msgs[j] +"\" (not a window)");       continue; }
            backChannel = terms[2];
            if (!StringLen(backChannel)) { warn("ProcessMessages(11)  invalid backchannel name in "+ symbols[i] +" message \""+ msgs[j] +"\" (empty)");  continue; }
            msgId       = terms[3];
            if (!StringLen(msgId))       { warn("ProcessMessages(12)  invalid message id in "+ symbols[i] +" message \""+ msgs[j] +"\" (empty)");        continue; }

            // prüfen, ob auf dem angegebenen BackChannel ein Receiver online ist
            result = QC_ChannelHasReceiver(backChannel);
            if (result < 0) return(!catch("ProcessMessages(13)->MT4iQuickChannel::QC_ChannelHasReceiver(ch=\""+ backChannel +"\") => "+ ifString(result==QC_CHECK_CHANNEL_ERROR, "QC_CHECK_CHANNEL_ERROR", result), ERR_WIN32_ERROR));
            if (result != QC_CHECK_RECEIVER_OK) {
               debug("ProcessMessages(14)  no receiver auf backchannel \""+ backChannel +"\", ignoring message \""+ msgs[j] +"\"");
               continue;
            }

            // Subscriber speichern und Bestätigung auf BackChannel verschicken: "{ChannelMsgId}|OK"
            n = ArraySize(qc.Subscribers);
            ArrayPushString( qc.Subscribers, backChannel);
            ArrayPushInt   (hQC.Senders    , NULL       ); if (!StartSender(n)) return(false);
            ArrayPushInt   (hQC.hWnds      , hWnd       );

            msg    = msgId +"|OK";
            result = QC_SendMessage(hQC.Senders[n], msg, NULL);
            if (!result) return(!catch("ProcessMessages(15)->MT4iQuickChannel::QC_SendMessage(ch=\""+ qc.Subscribers[n] +"\", msg=\""+ msg +"\", flags=NULL) => QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));
            debug("ProcessMessages(16)  subscribe confirmation \""+ msg +"\" sent");

            continue;
         }

         // (4.2) "Unsubscribe|{HWND}|{ChannelMsgId}"
         if (terms[0] == "Unsubscribe") {
            if (termsSize < 3)          { warn("ProcessMessages(17)  received invalid "+ symbols[i] +" message \""+ msgs[j] +"\" (missing parameters)"); continue; }
            sValue = terms[1];
            if (!StringIsDigit(sValue)) { warn("ProcessMessages(18)  invalid HWND value in "+ symbols[i] +" message \""+ msgs[j] +"\" (non-digits)");    continue; }
            hWnd = StrToInteger(sValue);
            msgId  = terms[2];
            if (!StringLen(msgId))      { warn("ProcessMessages(19)  invalid message id in "+ symbols[i] +" message \""+ msgs[j] +"\" (empty)");         continue; }

            n = SearchIntArray(hQC.hWnds, hWnd);
            if (n == -1)                { warn("ProcessMessages(20)  unknown subscriber in "+ symbols[i] +" unsubscribe message \""+ msgs[j] +"\"");     continue; }

            // Bestätigung verschicken, BackChannel schließen und Subscriber löschen
            if (!hQC.Senders[n]) /*&&*/ if (!StartSender(n)) return(false);
            msg    = msgId +"|OK";
            result = QC_SendMessage(hQC.Senders[n], msg, NULL);
            if (!result) return(!catch("ProcessMessages(21)->MT4iQuickChannel::QC_SendMessage(ch=\""+ qc.Subscribers[n] +"\", msg=\""+ msg +"\", flags=NULL) => QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));
            debug("ProcessMessages(22)  unsubscribe confirmation \""+ msg +"\" sent");

            if (!StopSender(n)) return(false);
            ArraySpliceStrings( qc.Subscribers, n, 1);
            ArraySpliceInts   (hQC.Senders    , n, 1);
            ArraySpliceInts   (hQC.hWnds      , n, 1);

            continue;
         }
         warn("ProcessMessages(23)  received unsupported "+ symbols[i] +" message \""+ msgs[j] +"\"");
      }

      ArrayResize(msgs,  0);
      ArrayResize(terms, 0);
   }
   return(true);
}


/**
 * Started einen Receiver für den angegebenen Suscription-Channel.
 *
 * @param  int i - Index des vom QuoteServer angebotenen Symbols bzw. dessen Channels
 *
 * @return bool - Erfolgsstatus
 */
bool StartReceiver(int i) {
   int size = ArraySize(symbols);
   if (i < 0)     return(!catch("StartReceiver(1)  invalid parameter i = "+ i, ERR_INVALID_PARAMETER));
   if (i >= size) return(!catch("StartReceiver(2)  invalid parameter i = "+ i +" (max. "+ (size-1) +")", ERR_INVALID_PARAMETER));

   int hWndChart = WindowHandleEx(NULL);
   if (!hWndChart) return(false);

   if (!hQC.Receivers[i]) {
      qc.SubscriptionChannels[i] = "MetaTrader::QuoteServer::"+ symbols[i];

      // TODO: Prüfen, ob bereits ein Receiver (= alternativer QuoteServer) existiert und in diesem Fall nach "waiting" verzweigen

      hQC.Receivers[i] = QC_StartReceiver(qc.SubscriptionChannels[i], hWndChart);
      if (!hQC.Receivers[i]) return(!catch("StartReceiver(3)->MT4iQuickChannel::QC_StartReceiver(ch=\""+ qc.SubscriptionChannels[i] +"\", hWnd=0x"+ IntToHexStr(hWndChart) +") => 0", ERR_WIN32_ERROR));
      debug("StartReceiver()  receiver on \""+ qc.SubscriptionChannels[i] +"\" started");
   }
   else {
      // Receiver-Handle testen
   }
   return(true);
}


/**
 * Started den Sender für den BackChannel des angegebenen Suscribers.
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

      debug("StartSender(4)  sender on \""+ qc.Subscribers[i] +"\" started");
   }
   return(true);
}


/**
 * Stoppt den Sender für den BackChannel des angegebenen Suscribers.
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
      if (!QC_ReleaseSender(hTmp))
         return(!catch("StopSender(3)->MT4iQuickChannel::QC_ReleaseSender(ch=\""+ qc.Subscribers[i] +"\")  error stopping sender", ERR_WIN32_ERROR));
      debug("StopSender()  sender on \""+ qc.Subscribers[i] +"\" stopped");
   }
   return(true);
}


/**
 * Stellt sicher, daß für jedes angebotene Symbol auf dem dazugehörenden Subscription-Channel ein Receiver läuft.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StartReceivers() {
   int hWndChart = WindowHandleEx(NULL);
   if (!hWndChart) return(false);

   int size = ArraySize(symbols);

   for (int i=0; i < size; i++) {
      if (!hQC.Receivers[i]) {
         qc.SubscriptionChannels[i] = "MetaTrader::QuoteServer::"+ symbols[i];

         hQC.Receivers[i] = QC_StartReceiver(qc.SubscriptionChannels[i], hWndChart);
         if (!hQC.Receivers[i])
            return(!catch("QC.StartReceivers(1)->MT4iQuickChannel::QC_StartReceiver(ch=\""+ qc.SubscriptionChannels[i] +"\", hWnd=0x"+ IntToHexStr(hWndChart) +") => 0", ERR_WIN32_ERROR));

         debug("StartReceivers()  receiver on \""+ qc.SubscriptionChannels[i] +"\" started");
      }
      else {
         // Receiver-Handle testen
      }
   }
   return(true);
}
