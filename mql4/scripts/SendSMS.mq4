/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   // Receiver
   string section = "SMS";
   string key     = "Receiver";
   string receiver = GetGlobalConfigString(section, key, "");
   if (!StringLen(receiver)) return(!catch("onStart(1)   missing setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));

   // Message
   string message = TimeToStr(TimeLocal(), TIME_MINUTES) +" Test message";

   // Versand
   if (!SendSMS(receiver, message))
      return(SetLastError(stdlib.GetLastError()));

   return(last_error);
}
