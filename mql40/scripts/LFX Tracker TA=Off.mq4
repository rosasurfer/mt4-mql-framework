/**
 * LFX Tracker TA=Off
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
   SendChartCommand("LFX Tracker.command", "trade-account");   // switch back to the current/own trade account
   return(catch("onStart(1)"));
}
