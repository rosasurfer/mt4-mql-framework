/**
 * LFX Tracker TA=123456
 *
 * Sends a command to the "LFX Tracker" indicator in the current chart to switch the used trading account.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   SendChartCommand("LFX Tracker.command", "trade-account:{account-company},{account-number}");
   return(catch("onStart(1)"));
}
