/**
 *
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#include <MT4iQuickChannel.mqh>
#include <etc/offline/QuoteClient.mqh>

#property indicator_chart_window


string qc.quotes.SubscribeChannel;     // Subscribe-Channel: "MetaTrader::QuoteServer::{Symbol}"             (Chart -> QuoteServer)
string qc.quotes.BackChannel;          // Backchannel:       "MetaTrader::QuoteClient::{Symbol}::{UniqueId}" (QuoteServer -> Chart)

int    hQC.quotes.Sender;              // Sender-Handle (Subscribe-Channel)
int    hQC.quotes.Receiver;            // Receiver-Handle (Backchannel)


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   if (!This.IsTesting()) {
      // Chart ggf. für Offline-Quote-Updates anmelden
      if (true || StrCompareI(GetServerName(), "XTrade-Synthetic") /*|| isOfflineChart*/)
         if (!StartSender())   return(last_error);                   // qc.quotes.SubscribeChannel initialisieren
         if (!StartReceiver()) return(last_error);                   // qc.quotes.BackChannel initialisieren
         if (!Subscribe())     return(last_error);
   }
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // vom QuoteServer eingehende Messages verarbeiten
   if (!ProcessMessages())
      return(last_error);
   return(last_error);
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   if (!This.IsTesting()) {
      // Chart ggf. von Offline-Quote-Updates abmelden
      if (true || StrCompareI(GetServerName(), "XTrade-Synthetic") /*|| isOfflineChart*/) {
         if (!Unsubscribe()) return(last_error);
      }

      // alle aktiven Channel stoppen
      StopChannels();
   }
   return(last_error);
}


/**
 * Meldet den Chart für Offline-Quote-Updates an.
 *
 * @return bool - Erfolgsstatus
 */
bool Subscribe() {
   // Subscribe-Message zusammenstellen: "Subscribe|{HWND_CHART}|{BackChannelName}"
   int hWndChart = __ExecutionContext[EC.hChart];
   string msg    = "Subscribe|"+ hWndChart +"|"+ qc.quotes.BackChannel;

   // Subscribe-Message verschicken
   if (!StartSender())
      return(false);
   int result = QC_SendMessage(hQC.quotes.Sender, msg, NULL);
   if (!result) return(!catch("Subscribe(1)->MT4iQuickChannel::QC_SendMessage(ch=\""+ qc.quotes.SubscribeChannel +"\", msg=\""+ msg +"\", flags=NULL) => QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));

   debug("Subscribe(2)  message \""+ msg +"\" sent");
   return(true);                                                     // ohne aktiven QuoteServer wartet der Subscriber, bis der QuoteServer online kommt
}


/**
 * Meldet den Chart für Offline-Quote-Updates ab.
 *
 * @return bool - Erfolgsstatus
 */
bool Unsubscribe() {
   // Unsubscribe-Message zusammenstellen: "Unsubscribe|{HWND_CHART}"
   int hWndChart = __ExecutionContext[EC.hChart];
   string msg    = "Unsubscribe|"+ hWndChart;

   // Unsubscribe-Message verschicken
   if (!StartSender())
      return(false);
   if (!QC_SendMessage(hQC.quotes.Sender, msg, NULL))
      return(!catch("Unsubscribe(1)->MT4iQuickChannel::QC_SendMessage(ch=\""+ qc.quotes.SubscribeChannel +"\", msg=\""+ msg +"\", flags=NULL) => QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));

   debug("Unsubscribe(2)  message \""+ msg +"\" sent");
   return(true);
}


/**
 * Verarbeitet vom QuoteServer eingehende Messages.
 *
 * @return bool - Erfolgsstatus
 */
bool ProcessMessages() {
   // (1) ggf. Receiver starten
   if (!hQC.quotes.Receiver) /*&&*/ if (!StartReceiver())
      return(false);

   // (2) Channel auf neue Messages prüfen
   int checkResult = QC_CheckChannel(qc.quotes.BackChannel);
   if (checkResult == QC_CHECK_CHANNEL_EMPTY)
      return(true);
   if (checkResult < QC_CHECK_CHANNEL_EMPTY) {
      if (checkResult == QC_CHECK_CHANNEL_ERROR)  return(!catch("ProcessMessages(1)->MT4iQuickChannel::QC_CheckChannel(ch=\""+ qc.quotes.BackChannel +"\") => QC_CHECK_CHANNEL_ERROR",                ERR_WIN32_ERROR));
      if (checkResult == QC_CHECK_CHANNEL_NONE )  return(!catch("ProcessMessages(2)->MT4iQuickChannel::QC_CheckChannel(ch=\""+ qc.quotes.BackChannel +"\")  channel doesn't exist",                   ERR_WIN32_ERROR));
                                                  return(!catch("ProcessMessages(3)->MT4iQuickChannel::QC_CheckChannel(ch=\""+ qc.quotes.BackChannel +"\")  unexpected return value = "+ checkResult, ERR_WIN32_ERROR));
   }

   // (3) neue Messages abholen
   string messageBuffer[]; if (!ArraySize(messageBuffer)) InitializeStringBuffer(messageBuffer, QC_MAX_BUFFER_SIZE);
   int getResult = QC_GetMessages3(hQC.quotes.Receiver, messageBuffer, QC_MAX_BUFFER_SIZE);
   if (getResult != QC_GET_MSG3_SUCCESS) {
      if (getResult == QC_GET_MSG3_CHANNEL_EMPTY) return(!catch("ProcessMessages(4)->MT4iQuickChannel::QC_GetMessages3()  QuickChannel mis-match: QC_CheckChannel="+ checkResult +"chars/QC_GetMessages3=CHANNEL_EMPTY", ERR_WIN32_ERROR));
      if (getResult == QC_GET_MSG3_INSUF_BUFFER ) return(!catch("ProcessMessages(5)->MT4iQuickChannel::QC_GetMessages3()  QuickChannel mis-match: QC_CheckChannel="+ checkResult +"chars/QC_MAX_BUFFER_SIZE="+ QC_MAX_BUFFER_SIZE +"/size(buffer)="+ (StringLen(messageBuffer[0])+1) +"/QC_GetMessages3=INSUF_BUFFER", ERR_WIN32_ERROR));
                                                  return(!catch("ProcessMessages(6)->MT4iQuickChannel::QC_GetMessages3()  unexpected return value = "+ getResult, ERR_WIN32_ERROR));
   }

   // (4) Messages verarbeiten
   static int hWndChart; if (!hWndChart) {
      hWndChart = __ExecutionContext[EC.hChart];
   }
   string msgs[], terms[], sValue, sReason;
   int    termsSize, hWnd, msgId, msgsSize=Explode(messageBuffer[0], TAB, msgs, NULL);


   for (int i=0; i < msgsSize; i++) {
      if (!StringLen(msgs[i]))
         continue;
      debug("ProcessMessages(7)  received msg \""+ msgs[i] +"\"");

      termsSize = Explode(msgs[i], "|", terms, 4);

      // (4.1) vom QuoteServer initiiertes Unsubscribe: "QuoteServer|{HWND}|Unsubscribed|{Reason}"
      if (terms[0] == "QuoteServer") {
         if (termsSize < 3)            { warn("ProcessMessages(8)  invalid message \""+ msgs[i] +"\" (missing parameters)");                      continue; }
         // HWND
         sValue = terms[1];
         if (!StrIsDigit(sValue))      { warn("ProcessMessages(9)  invalid HWND value in message \""+ msgs[i] +"\" (non-digits)");                continue; }
         hWnd = StrToInteger(sValue);
         if (hWnd != hWndChart)        { warn("ProcessMessages(10)  invalid HWND in message \""+ msgs[i] +"\" (not my window)");                  continue; }
         // Unsubscribed
         sValue = terms[2];
         if (sValue != "Unsubscribed") { warn("ProcessMessages(11)  unsupported message \""+ msgs[i] +"\" (unknown parameter \""+ sValue +"\")"); continue; }
         // Reason
         sReason = terms[3];

         debug("ProcessMessages(12)  disconnected (reason="+ sReason +"), reconnecting...");
         if (!Subscribe()) return(false);
         continue;
      }

      warn("ProcessMessages(13)  received unsupported message \""+ msgs[i] +"\"");
   }

   ArrayResize(msgs,  0);
   ArrayResize(terms, 0);
   return(true);
}


/**
 * Startet den QuickChannel-Sender auf dem Subscription-Channel: "MetaTrader::QuoteServer::{Symbol}"
 *
 * @return bool - Erfolgsstatus
 */
bool StartSender() {
   if (!hQC.quotes.Sender) {
      qc.quotes.SubscribeChannel = "MetaTrader::QuoteServer::"+ Symbol();

      hQC.quotes.Sender = QC_StartSender(qc.quotes.SubscribeChannel);
      if (!hQC.quotes.Sender) return(!catch("StartSender(1)->MT4iQuickChannel::QC_StartSender(ch=\""+ qc.quotes.SubscribeChannel +"\")", ERR_WIN32_ERROR));

      debug("StartSender(2)  sender on \""+ qc.quotes.SubscribeChannel +"\" started");
   }
   return(true);
}


/**
 * Stoppt einen aktiven QuickChannel-Sender.
 *
 * @return bool - Erfolgsstatus
 */
bool StopSender() {
   if (hQC.quotes.Sender != NULL) {
      int hTmp = hQC.quotes.Sender;
                 hQC.quotes.Sender = NULL;                           // Handle zurücksetzen, um mehrfache Stopversuche bei Fehlern zu verhindern
      if (!QC_ReleaseSender(hTmp))
         return(!catch("StopSender(1)->MT4iQuickChannel::QC_ReleaseSender(ch=\""+ qc.quotes.SubscribeChannel +"\")  error stopping sender", ERR_WIN32_ERROR));
      debug("StopSender(2)  sender on \""+ qc.quotes.SubscribeChannel +"\" stopped");
   }
   return(true);
}


/**
 * Startet den QuickChannel-Receiver auf dem Backchannel: "MetaTrader::QuoteClient::{Symbol}::{UniqueId}"
 *
 * @return bool - Erfolgsstatus
 */
bool StartReceiver() {
   if (!hQC.quotes.Receiver) {
      int hWndChart = __ExecutionContext[EC.hChart];                 // das ChartHandle wird als {UniqueId} benutzt
      qc.quotes.BackChannel = "MetaTrader::QuoteClient::"+ Symbol() +"::"+ IntToHexStr(hWndChart);

      hQC.quotes.Receiver = QC_StartReceiver(qc.quotes.BackChannel, hWndChart);
      if (!hQC.quotes.Receiver) return(!catch("StartReceiver(1)->MT4iQuickChannel::QC_StartReceiver(ch=\""+ qc.quotes.BackChannel +"\", hWnd="+ IntToHexStr(hWndChart) +") => 0", ERR_WIN32_ERROR));

      debug("StartReceiver(2)  receiver on \""+ qc.quotes.BackChannel +"\" started");
   }
   return(true);
}


/**
 * Stoppt eine aktiven QuickChannel-Receiver.
 *
 * @return bool - Erfolgsstatus
 */
bool StopReceiver() {
   if (hQC.quotes.Receiver != NULL) {
      int hTmp = hQC.quotes.Receiver;
                 hQC.quotes.Receiver = NULL;                         // Handle zurücksetzen, um mehrfache Stopversuche bei Fehlern zu verhindern
      if (!QC_ReleaseReceiver(hTmp))
         return(!catch("StopReceiver(1)->MT4iQuickChannel::QC_ReleaseReceiver(ch=\""+ qc.quotes.BackChannel +"\")  error stopping receiver", ERR_WIN32_ERROR));
      debug("StopReceiver(2)  receiver on \""+ qc.quotes.BackChannel +"\" stopped");
   }
   return(true);
}


/**
 * Stoppt alle aktiven Sender oder Receiver.
 *
 * @return bool - Erfolgsstatus
 */
bool StopChannels() {
   if (!StopSender())   return(false);
   if (!StopReceiver()) return(false);
   return(true);
}
