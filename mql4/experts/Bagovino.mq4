/**
 * Bagovino - a simple trend following system
 *
 * Features entries on Moving Average cross with RSI confirmation and partial profit taking.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Fast.MA.Periods      = 100;
extern string Fast.MA.Method       = "SMA* | LWMA | EMA | ALMA";

extern int    Slow.MA.Periods      = 200;
extern string Slow.MA.Method       = "SMA* | LWMA | EMA | ALMA";

extern double Lotsize              = 0.1;
extern double TakeProfit.Level.1   = 30;
extern double TakeProfit.Level.2   = 60;

extern string _1_____________________________;

extern string Notify.onEntrySignal = "on | off | auto*";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


/**
 * Initialization.
 *
 * @return int - error status
 */
int onInit() {
   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   return(last_error);
}
