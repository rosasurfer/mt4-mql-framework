/**
 * SendTestSMS
 */
#include <stddefines.mqh>
int   __InitFlags[] = { INIT_NO_BARS_REQUIRED };
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   SendSMS("", "Test message "+ TimeToStr(GetLocalTime(), TIME_MINUTES));
   return(catch("onStart(1)"));
}
