/**
 * SendTestMail
 */
#include <stddefines.mqh>
int   __InitFlags[] = { INIT_NO_BARS_REQUIRED };
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   string message = "Test email "+ TimeToStr(GetLocalTime(), TIME_MINUTES);
   SendEmail("", "", message, message);
   return(catch("onStart(1)"));
}
