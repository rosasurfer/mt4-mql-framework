/**
 * TestScript2
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_NO_BARS_REQUIRED };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <history.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   string sender   = "***REMOVED***";
   string receiver = "***REMOVED***";
   string subject  = "squote:'\r\ndquote:\"\npipe:|\r\nhalle luh-jah";
   string message  = subject + subject;

   SendEmail(sender, receiver, subject, message);
   return(last_error);
}
