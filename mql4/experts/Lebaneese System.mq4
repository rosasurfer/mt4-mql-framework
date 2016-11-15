/**
 * Lebaneese System.
 *
 * At the moment implemented for testing only.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

/////////////////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////////////////

extern double Lotsize = 0.1;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>


#define MODE_MA      MovingAverage.MODE_MA            // NonLagMA buffer indices
#define MODE_TREND   MovingAverage.MODE_TREND

int    nlma.cycles;                                   // NonLagMA parameters
int    nlma.cycleLength;
int    nlma.cycleWindowSize;
string nlma.filterVersion;
int    nlma.maxValues;

bool   isOpenPosition;


/**
 * Initialization
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
   static int counter;
   if (!counter) {
      debug("onTick(1)  Bars="+ Bars +"  T="+ TimeToStr(MarketInfo(Symbol(), MODE_TIME), TIME_FULL) +"  Spread="+ DoubleToStr((Ask-Bid)/Pip, 1) +"  V="+ _int(Volume[0]));
      counter++;
   }
   return(last_error);

   // check current position
   if (!isOpenPosition) CheckForOpenSignal();
   else                 CheckForCloseSignal();
   return(last_error);
}


/**
 * Check for entry conditions
 */
void CheckForOpenSignal() {
}


/**
 * Check for exit conditions
 */
void CheckForCloseSignal() {
}
