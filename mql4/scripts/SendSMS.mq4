/**
 * TestScript
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = { INIT_NO_BARS_REQUIRED };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   // Receiver
   string section = "SMS";
   string key     = "Receiver";
   string receiver = GetGlobalConfigString(section, key);
   if (!StringLen(receiver)) return(!catch("onStart(1)  missing setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));

   // Message
   string message = TimeToStr(TimeLocalEx("onStart(2)"), TIME_MINUTES) +" Test message";

   // Versand
   SendSMS(receiver, message);

   return(last_error);
}
