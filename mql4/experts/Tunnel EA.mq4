/**
 * Tunnel EA
 *
 * wip: work-in-progress
 */
#include <stddefines.mqh>
int   __InitFlags[] = { INIT_PIPVALUE, INIT_BUFFERED_LOG };
int __DeinitFlags[];
int __virtualTicks  = 10000;                    // every 10 seconds to continue operation on a stalled data feed

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Sequence.ID = "";                 // instance to load from a status file

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/iCustom/MaTunnel.mqh>

#define STRATEGY_ID  108                        // unique strategy id (between 101-1023, 10 bit)


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   double value = icMaTunnel(NULL, 34, "EMA", 0, 0);

   debug("onTick(0.1)  Tick="+ Ticks +"  MaTunnel[0]="+ NumberToStr(value, PriceFormat));

   return(catch("onTick(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Sequence.ID=", DoubleQuoteStr(Sequence.ID), ";"));
}
