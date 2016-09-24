/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_DOESNT_REQUIRE_BARS };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   // Sender
   string section = "Mail";
   string key     = "Sender";
   string sender  = GetGlobalConfigString(section, key);
   if (!StringLen(sender)) return(!catch("onStart(1)  missing config setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));

   // Receiver
          key      = "Receiver";
   string receiver = GetGlobalConfigString(section, key);
   if (!StringLen(receiver)) return(!catch("onStart(2)  missing config setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));

   // Message
   string message = TimeToStr(TimeLocalEx("onStart(3)"), TIME_MINUTES) +" Test e-mail";

   // Versand
   SendEmail(sender, receiver, message, message);

   return(last_error);
}
