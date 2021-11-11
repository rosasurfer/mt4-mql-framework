/**
 * PeriodStepper Down
 *
 * Broadcast a command to listening indicators to decrease their dynamic period.
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
   SendChartCommand("PeriodStepper.command", GetTickCount() +"|down");
   return(catch("onStart(1)"));
}
