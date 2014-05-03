/**
 * LFX.ExecuteTradeCmd
 *
 * Script, daß intern zur Ausführung von zwischen den Terminals verschickten TradeCommands benutzt wird. Parameter werden per QuickChannel übergeben.
 * Ein manueller Aufruf ist nicht möglich.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/script.mqh>

#include <win32api.mqh>
#include <lfx.mqh>
#include <MT4iQuickChannel.mqh>
#include <ChartInfos/quickchannel.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   // (1) Parameter einlesen
   string parameters = GetScriptParameters();
   if (!StringLen(parameters))
      return(last_error);

   debug("onStart()   script parameters=\""+ parameters +"\"");


   // (2) TradeCommands ausführen
   return(last_error);
}


/**
 * Gibt die per QuickChannel übergebenen Parameter des aktuellen Scripts zurück.
 *
 * @return string - String mit Parametern oder Leerstring, falls ein Fehler auftrat
 */
string GetScriptParameters() {
   if (IsLastError())
      return("");

   string parameters = "";


   // Um für den QC-Receiver kein Fenster registrieren zu müssen (löst unnötige Ticks aus), benutzen wir zum Lesen des Channels einen weiteren Sender.
   if (!hQC.ScriptParameterSender) /*&&*/ if (!QC.StartScriptParameterSender())
      return("");

   // check channel
   int result = QC_CheckChannel(qc.ScriptParameterChannel);
   if (result <= QC_CHECK_CHANNEL_EMPTY) {
      if      (result == QC_CHECK_CHANNEL_ERROR) catch("GetScriptParameters(1)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\") = QC_CHECK_CHANNEL_ERROR", ERR_WIN32_ERROR);
      else if (result == QC_CHECK_CHANNEL_NONE ) catch("GetScriptParameters(2)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\") doesn't exist", ERR_WIN32_ERROR);
      else if (result == QC_CHECK_CHANNEL_EMPTY) catch("GetScriptParameters(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\") is empty (no script parameters found)", ERR_RUNTIME_ERROR);
      else                                       catch("GetScriptParameters(4)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\") unexpected return value = "+ result, ERR_WIN32_ERROR);
   }
   else {
      // get messages
      result = QC_GetMessages3(hQC.ScriptParameterSender, qc.msgBuffer, QC_MAX_BUFFER_SIZE);
      if (result != QC_GET_MSG3_SUCCESS) {
         if      (result == QC_GET_MSG3_CHANNEL_EMPTY) catch("GetScriptParameters(5)->MT4iQuickChannel::QC_GetMessages3()   QC_CheckChannel not empty/QC_GET_MSG3_CHANNEL_EMPTY mismatch error", ERR_WIN32_ERROR);
         else if (result == QC_GET_MSG3_INSUF_BUFFER ) catch("GetScriptParameters(6)->MT4iQuickChannel::QC_GetMessages3()   buffer to small (QC_MAX_BUFFER_SIZE/QC_GET_MSG3_INSUF_BUFFER mismatch)", ERR_WIN32_ERROR);
         else                                          catch("GetScriptParameters(7)->MT4iQuickChannel::QC_GetMessages3()   unexpected return value = "+ result, ERR_WIN32_ERROR);
      }
      else {
         parameters = qc.msgBuffer[0];
      }
   }

   // stop sender
   if (!QC.StopScriptParameterSender())
      return("");

   if (!last_error)
      return(parameters);
   return("");
}
