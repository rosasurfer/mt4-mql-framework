/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/script.mqh>

#include <win32api.mqh>
#include <MT4iQuickChannel.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   // start sender
   string channel = "TestChannel";
   int hQC = QC_StartSender(channel);
   if (!hQC)
      return(catch("onStart(1)->MT4iQuickChannel::QC_StartSender(channel=\""+ channel +"\")   error ="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));
   debug("onStart()   sender started");


   // send message
   int result = QC_SendMessage(hQC, "test message", NULL);
   if (!result)
      return(catch("onStart(2)->MT4iQuickChannel::QC_SendMessage() = QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));
   debug("onStart()   message sent");


   // check channel
   result = QC_CheckChannel(channel);
   if (result < QC_CHECK_CHANNEL_EMPTY) {
      if      (result == QC_CHECK_CHANNEL_ERROR) warn("onStart(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ channel +"\") = QC_CHECK_CHANNEL_ERROR", ERR_WIN32_ERROR);
      else if (result == QC_CHECK_CHANNEL_NONE ) warn("onStart(4)->MT4iQuickChannel::QC_CheckChannel(name=\""+ channel +"\") doesn't exist", ERR_WIN32_ERROR);
      else                                       warn("onStart(5)->MT4iQuickChannel::QC_CheckChannel(name=\""+ channel +"\") unexpected return value = "+ result, ERR_WIN32_ERROR);
   }
   else if (result == QC_CHECK_CHANNEL_EMPTY)    debug("onStart()   CheckChannel = empty");
   else {                                        debug("onStart()   CheckChannel = not empty ("+ result +" chars)");


      // get messages
      string buffer[]; InitializeStringBuffer(buffer, QC_MAX_BUFFER_SIZE);
      result = QC_GetMessages3(hQC, buffer, QC_MAX_BUFFER_SIZE);
      if (result != QC_GET_MSG3_SUCCESS) {
         if      (result == QC_GET_MSG3_CHANNEL_EMPTY) warn("onStart(6)->MT4iQuickChannel::QC_GetMessages3()   QC_CheckChannel not empty/QC_GET_MSG3_CHANNEL_EMPTY mismatch error", ERR_WIN32_ERROR);
         else if (result == QC_GET_MSG3_INSUF_BUFFER ) warn("onStart(7)->MT4iQuickChannel::QC_GetMessages3()   buffer to small (QC_MAX_BUFFER_SIZE/QC_GET_MSG3_INSUF_BUFFER mismatch)", ERR_WIN32_ERROR);
                                                       warn("onStart(8)->MT4iQuickChannel::QC_GetMessages3()   unexpected return value = "+ result, ERR_WIN32_ERROR);
      }
      debug("onStart()   got message \""+ buffer[0] +"\"");
   }


   // stop sender
   if (!QC_ReleaseSender(hQC))
      return(catch("onStart(12)->MT4iQuickChannel::QC_ReleaseSender(channel=\""+ channel +"\")   error stopping sender: "+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));
   debug("onStart()   sender stopped");

   return(last_error);
}
