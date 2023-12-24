/**
 * Vegas EA (don't use, work-in-progress)
 *
 * A hybrid strategy using ideas of the "Vegas H1 Tunnel" system, the system of the "Turtle Traders" and a regular grid.
 *
 *
 *  @see  https://www.forexfactory.com/thread/4365-all-vegas-documents-located-here#                 [Vegas H1 Tunnel Method]
 *  @see  https://analyzingalpha.com/turtle-trading#                                                         [Turtle Trading]
 *  @see  https://github.com/rosasurfer/mt4-mql/blob/master/mql4/experts/Duel.mq4#                             [Duel Grid EA]
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 0;

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID = "";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/iCustom/MaTunnel.mqh>

#define STRATEGY_ID  108                        // unique strategy id (10 bit, between 101-1023)


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   double value = icMaTunnel(NULL, "EMA(36)", 0, 0);

   debug("onTick(0.1)  Tick="+ Ticks +"  MaTunnel[0]="+ NumberToStr(value, PriceFormat));

   return(catch("onTick(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Instance.ID=", DoubleQuoteStr(Instance.ID), ";"));
}
