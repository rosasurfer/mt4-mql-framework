/**
 * SendTestSMS
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   SendSMS("", "Test message "+ TimeToStr(GetLocalTime(), TIME_MINUTES));
   return(catch("onStart(1)"));
}
