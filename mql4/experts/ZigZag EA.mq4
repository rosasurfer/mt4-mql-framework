/**
 * ZigZag EA
 *
 *
 * TODO:
 *  - build script for all .ex4 files after deployment
 *  - EquityRecorder stopped working
 *  - EquityRecorder receives no ticks during market-closed times and produces gaps
 *  - double ZigZag reversals during a large bars are not recognized and ignored
 *  - track full PL (min/max/current)
 *  - every instance needs to track its PL curve
 *  - track slippage
 *  - TakeProfit in {percent|pip}
 *  - input option to pick-up the last signal on start
 *
 *  - delete old/dead screen sockets on restart
 *  - ToggleOpenOrders() works only after ToggleHistory()
 *  - ChartInfos::onPositionOpen() doesn't log slippage
 *  - reduce slippage on reversal: replace Close+Open by Hedge+CloseBy
 *  - configuration/start at a specific time of day
 *  - make slippage an input parameter
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    ZigZag.Periods = 40;
extern double Lots           = 0.1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define SIGNAL_LONG  1
#define SIGNAL_SHORT 2

int ticket;
int lastSignal;

int magicNumber = 12345;
int slippage    = 2;       // point


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // get ZigZag data and check for new signals
   int trend, reversal, signal;
   if (!GetZigZagData(0, trend, reversal))  return(last_error);

   if (Abs(trend) == reversal) {
      if (trend > 0) {
         if (lastSignal != SIGNAL_LONG) {
            signal = SIGNAL_LONG;
         }
      }
      else if (lastSignal != SIGNAL_SHORT) {
         signal = SIGNAL_SHORT;
      }
   }

   // manage positions
   if (signal != NULL) {
      int oeFlags, oe[];

      // close existing position
      if (ticket > 0) {
         if (!OrderCloseEx(ticket, NULL, NULL, CLR_NONE, oeFlags, oe)) return(SetLastError(oe.Error(oe)));
         ticket = NULL;
      }

      // open new position
      int type  = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL);
      color clr = ifInt(signal==SIGNAL_LONG, Blue, Red);
      ticket = OrderSendEx(Symbol(), type,  Lots, NULL, slippage, NULL, NULL, "ZigZag", magicNumber, NULL, clr, oeFlags, oe);
      if (!ticket) return(SetLastError(oe.Error(oe)));

      lastSignal = signal;
   }
   return(catch("onTick(1)"));
}


/**
 * Get the data of the last ZigZag semaphore preceding the specified bar.
 *
 * @param  _In_  int startbar       - startbar to look for the next semaphore
 * @param  _Out_ int &combinedTrend - combined trend value at the startbar offset
 * @param  _Out_ int &reversal      - reversal bar value at the startbar offset
 *
 * @return bool - success status
 */
bool GetZigZagData(int bar, int &combinedTrend, int &reversal) {
   combinedTrend = Round(icZigZag(NULL, ZigZag.Periods, false, false, ZigZag.MODE_TREND,    bar));
   reversal      = Round(icZigZag(NULL, ZigZag.Periods, false, false, ZigZag.MODE_REVERSAL, bar));
   return(combinedTrend != 0);
}
