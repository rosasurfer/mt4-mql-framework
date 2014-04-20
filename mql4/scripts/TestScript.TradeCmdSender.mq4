/**
 * TradeCmd.Sender
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/script.mqh>
#include <MT4iQuickChannel.mqh>
#include <win32api.mqh>


// QuickChannel
int    hTradeCmdChannelSender;
string tradeCmdChannelName;


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   // QuickChannel-Sender stoppen
   if (hTradeCmdChannelSender != NULL)
      StopQCSender();

   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   // Trade-Command verschicken
   while (true) {
      if (!hTradeCmdChannelSender) /*&&*/ if (!StartQCSender())
         return(false);

      int result = QC_SendMessage(hTradeCmdChannelSender, "TradeCommand: open position", QC_FLAG_SEND_MSG_IF_RECEIVER);
      if (!result)
         return(catch("onStart(1)->MT4iQuickChannel::QC_SendMessage() = QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));
      if (result == QC_SEND_MSG_IGNORED) {
         debug("onStart()   receiver gone, message ignored");
         StopQCSender();
         continue;
      }
      debug("onStart()   message sent");
      break;
   }

   return(last_error);
}


/**
 * Startet einen QuickChannel-Sender für Trade-Commands.
 *
 * @return bool - Erfolgsstatus
 */
bool StartQCSender() {
   if (!hTradeCmdChannelSender) {
      // aktiven Channel ermitteln
      string file    = TerminalPath() +"\\experts\\files\\LiteForex\\remote_positions.ini";
      string section = "{account-no}";
      string keys[], value;
      int iValue, keysSize = GetIniKeys(file, section, keys);

      for (int i=0; i < keysSize; i++) {
         if (StringIStartsWith(keys[i], "Receiver.TradeCommands.")) {
            value = GetIniString(file, section, keys[i], "");
            if (value!="") /*&&*/ if (value!="0") {
               // Channel sollte aktiv sein, testen...
               int result = QC_ChannelHasReceiver(keys[i]);
               if (result == QC_CHECK_RECEIVER_OK)                   // Receiver ist da, Channel ist ok
                  break;
               if (result == QC_CHECK_CHANNEL_NONE) {                // kann theoretisch auftreten, wenn Receiver schon gestoppt, der .ini-Eintrag aber noch nicht aktualisiert ist
                  warn("StartQCSender(1)->MT4iQuickChannel::QC_ChannelHasReceiver(name=\""+ keys[i] +"\") doesn't exist anymore");
                  continue;
               }
               if (result == QC_CHECK_RECEIVER_NONE) return(!catch("StartQCSender(2)->MT4iQuickChannel::QC_ChannelHasReceiver(name=\""+ keys[i] +"\") has no reiver but a sender",          ERR_WIN32_ERROR));
               if (result == QC_CHECK_CHANNEL_ERROR) return(!catch("StartQCSender(3)->MT4iQuickChannel::QC_ChannelHasReceiver(name=\""+ keys[i] +"\") = QC_CHECK_CHANNEL_ERROR",            ERR_WIN32_ERROR));
                                                     return(!catch("StartQCSender(4)->MT4iQuickChannel::QC_ChannelHasReceiver(name=\""+ keys[i] +"\") = unexpected return value: "+ result, ERR_WIN32_ERROR));
            }
         }
      }
      if (i >= keysSize) {                                            // break wurde nicht getriggert
         Comment(NL, __NAME__, ":  ", TimeToStr(TimeLocal(), TIME_FULL), "  no active receiver found");
         return(false);
      }

      // Sender auf aktivem Channel starten
      tradeCmdChannelName    = keys[i];
      hTradeCmdChannelSender = QC_StartSender(tradeCmdChannelName);
      if (!hTradeCmdChannelSender)
         return(!catch("StartQCSender(5)->MT4iQuickChannel::QC_StartSender(channelName=\""+ tradeCmdChannelName +"\")   error ="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));
      Comment(NL, __NAME__, ":  ", TimeToStr(TimeLocal(), TIME_FULL), "  sender started");
      debug("StartQCSender()   sender startet on channel \""+ tradeCmdChannelName +"\"");
   }
   return(true);
}


/**
 * Stoppt den aktuellen QuickChannel-Sender.
 *
 * @return bool - Erfolgsstatus
 */
bool StopQCSender() {
   if (hTradeCmdChannelSender != NULL) {
      if (!QC_ReleaseSender(hTradeCmdChannelSender))
         return(!catch("StopQCSender(1)->MT4iQuickChannel::QC_ReleaseSender(hChannel=0x"+ IntToHexStr(hTradeCmdChannelSender) +")   error stopping QuickChannel sender: "+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));
      hTradeCmdChannelSender = NULL;
      tradeCmdChannelName    = "";

      Comment(NL, __NAME__, ":  ", TimeToStr(TimeLocal(), TIME_FULL) +"  sender stopped");
      debug("StopQCSender()   sender stopped");
   }
   return(true);
}
