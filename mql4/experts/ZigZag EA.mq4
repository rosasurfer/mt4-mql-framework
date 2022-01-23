/**
 * ZigZag EA
 *
 *
 * TODO:
 *  - every EA instance needs to track its PL curve
 *  - track full PL (min/max/current)
 *  - TakeProfit in {percent|pip}
 *
 *  - double ZigZag reversals during large bars are not recognized and ignored
 *  - build script for all .ex4 files after deployment
 *  - track slippage
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

extern string Sequence.ID                    = "";       // instance to load from a file (id between 1000-9999)

extern string ___a__________________________ = "=== Signal settings ========================";
extern int    ZigZag.Periods                 = 40;

extern string ___b__________________________ = "=== Trade settings ========================";
extern double Lots                           = 0.1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define STRATEGY_ID         107              // unique strategy id between 101-1023 (10 bit)

#define STATUS_WAITING        1              // sequence status values
#define STATUS_PROGRESSING    2
#define STATUS_STOPPED        3

#define SIGNAL_LONG           1
#define SIGNAL_SHORT          2

// sequence data
int      sequence.id;
datetime sequence.created;
int      sequence.status;
string   sequence.name = "";                 // "ZigZag.{sequence-id}"

// cache vars to speed-up ShowStatus()
string   sSequenceTotalPL = "";
string   sSequencePlStats = "";


// --- old ------------------------------------------------------------------------------------------------------------------
int ticket;
int lastSignal;
int magicNumber = 12345;
int slippage    = 2;                         // in point

#include <apps/zigzag-ea/init.mqh>
#include <apps/zigzag-ea/deinit.mqh>


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


/**
 * Display the current runtime status.
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error or the current error status if no error was specified
 */
int ShowStatus(int error = NO_ERROR) {
   if (!__isChart) return(error);

   static bool isRecursion = false;                   // to prevent recursive calls a specified error is displayed only once
   if (error != 0) {
      if (isRecursion) return(error);
      isRecursion = true;
   }
   string sStatus="", sError="";

   switch (sequence.status) {
      case NULL:               sStatus = "not initialized";                               break;
      case STATUS_WAITING:     sStatus = StringConcatenate(sequence.id, "  waiting");     break;
      case STATUS_PROGRESSING: sStatus = StringConcatenate(sequence.id, "  progressing"); break;
      case STATUS_STOPPED:     sStatus = StringConcatenate(sequence.id, "  stopped");     break;
      default:
         return(catch("ShowStatus(1)  "+ sequence.name +" illegal sequence status: "+ sequence.status, ERR_ILLEGAL_STATE));
   }
   if (__STATUS_OFF) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason), "]");

   string text = StringConcatenate(ProgramName(), "    ", sStatus, sError,                  NL,
                                                                                            NL,
                                  "Profit:    ",  sSequenceTotalPL, "  ", sSequencePlStats, NL
   );

   // 3 lines margin-top for instrument and indicator legends
   Comment(NL, NL, NL, text);
   if (__CoreFunction == CF_INIT) WindowRedraw();

   error = intOr(catch("ShowStatus(2)"), error);
   isRecursion = false;
   return(error);
}
