/**
 * ALMA trend following system (Arnaud Legoux Moving Average).
 *
 *
 * Long + Short:
 * -------------
 *  - Entry:      If the ALMA changes direction.
 *  - StopLoss:   The extrem of the previous ALMA swing.
 *  - TakeProfit: Double of the stoploss distance.
 *  - Exit:       If the ALMA changes direction again. Where and how exactly?
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////// Configuration ///////////////////////////////////////////////////////////////

extern int    Periods          = 38;
extern double Lotsize          = 0.1;
extern bool   Reverse.Strategy = false;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>


// order marker colors
#define CLR_OPEN_LONG         C'0,0,254'              // Blue - rgb(1,1,1)
#define CLR_OPEN_SHORT        C'254,0,0'              // Red  - rgb(1,1,1)
#define CLR_OPEN_TAKEPROFIT   Blue
#define CLR_OPEN_STOPLOSS     Red
#define CLR_CLOSE             Orange


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   static datetime lastBarOpenTime = NULL;
   if (Time[0] != lastBarOpenTime) {                  // simplified BarOpen event, fails on Indicator::init()
      lastBarOpenTime = Time[0];
   }
   return(last_error);
}
