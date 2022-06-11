/**
 * SuperBars Down
 *
 * Send the SuperBars indicator a command to switch to the next lower SuperBars timeframe.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   SendChartCommand("SuperBars.command", "timeframe:down");
   return(catch("onStart(1)"));
}
