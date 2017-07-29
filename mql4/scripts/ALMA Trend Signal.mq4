/**
 * Mark entry and exit signals of the "ALMA Trend" strategy in the chart.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

#property show_inputs

////////////////////////////////////////////////////////////// Configuration ///////////////////////////////////////////////////////////////

extern datetime Signal.Startdate = D'2016.01.01';
extern string   Signal.Timeframe = "current";            // "" = current timeframe              // TODO: [M1|M5|M15|...]
extern string   _______________________________;
extern int      Periods          = 38;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <iFunctions/iBarShiftNext.mqh>
#include <iFunctions/iBarShiftPrevious.mqh>


// virtual ticket number
int ticket = 0;


// position tracking
int      long.positions      = 0;
double   long.lastEntryLevel = INT_MAX;
int      long.tickets   [];
datetime long.openTimes [];
double   long.openPrices[];

int      short.positions      = 0;
double   short.lastEntryLevel = INT_MIN;
int      short.tickets   [];
datetime short.openTimes [];
double   short.openPrices[];


// order marker colors
#define CLR_OPEN_LONG      C'0,0,254'                    // Blue - rgb(1,1,1)
#define CLR_OPEN_SHORT     C'254,0,0'                    // Red  - rgb(1,1,1)
#define CLR_CLOSE          Orange


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate input parameters
   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   // (1) calculate start bar                                  // TODO: check available bars for indicator calculation
   int bar = iBarShiftPrevious(NULL, NULL, Signal.Startdate);
   if (bar == -1) return(catch("onStart(1)  No history found for "+ TimeToStr(Signal.Startdate, TIME_DATE|TIME_MINUTES), ERR_HISTORY_INSUFFICIENT));

   int startBar = iBarShiftNext(NULL, NULL, Signal.Startdate);
   if (startBar == -1) return(catch("onStart(2)  History not loaded for "+ TimeToStr(Signal.Startdate, TIME_DATE|TIME_MINUTES), ERR_HISTORY_INSUFFICIENT));


   // (2) calculate signals for each bar
   for (bar=startBar; bar >= 0; bar--) {
      //// check long conditions
      //int lastPositions = long.positions;
      //if (long.positions < Open.Max.Positions)             Long.CheckOpenSignal(bar);
      //if (long.positions && long.positions==lastPositions) Long.CheckCloseSignal(bar);    // don't check for close on an open signal
      //
      //// check short conditions
      //lastPositions = short.positions;
      //if (short.positions < Open.Max.Positions)              Short.CheckOpenSignal(bar);
      //if (short.positions && short.positions==lastPositions) Short.CheckCloseSignal(bar); // don't check for close on an open signal
   }

   return(catch("onStart(3)"));
}


/**
 * Check for long entry conditions.
 *
 * @param  int bar - bar offset
 */
void Long.CheckOpenSignal(int bar) {
}


/**
 * Check for long exit conditions.
 *
 * @param  int bar - bar offset
 */
void Long.CheckCloseSignal(int bar) {
}


/**
 * Check for short entry conditions.
 *
 * @param  int bar - bar offset
 */
void Short.CheckOpenSignal(int bar) {
}


/**
 * Check for short exit conditions.
 *
 * @param  int bar - bar offset
 */
void Short.CheckCloseSignal(int bar) {
}


/**
 * Draw an "open position" marker.
 *
 * @param  int      direction - trade direction: OP_LONG|OP_SHORT
 * @param  int      ticket    - ticket number
 * @param  datetime time      - position open time
 * @param  double   price     - position open price
 */
void MarkOpen(int direction, int ticket, datetime time, double price) {
   if (direction == OP_LONG) {
      string label = StringConcatenate("#", ticket, " buy at ", NumberToStr(price, PriceFormat));
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_ARROW, 0, time, price)) {
         ObjectSet(label, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet(label, OBJPROP_COLOR,     CLR_OPEN_LONG   );
      }
      return;
   }

   if (direction == OP_SHORT) {
      label = StringConcatenate("#", ticket, " sell at ", NumberToStr(price, PriceFormat));
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_ARROW, 0, time, price)) {
         ObjectSet(label, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet(label, OBJPROP_COLOR,     CLR_OPEN_SHORT  );
      }
      return;
   }

   catch("MarkOpen(1)  invalid parameter direction = "+ direction, ERR_INVALID_PARAMETER);
}


/**
 * Draw a "close position" marker and the connecting line.
 *
 * @param  int      direction  - trade direction: OP_LONG|OP_SHORT
 * @param  int      ticket     - ticket number
 * @param  datetime openTime   - position open time
 * @param  double   openPrice  - position open price
 * @param  datetime closeTime  - position close time
 * @param  double   closePrice - position close price
 */
void MarkClose(int direction, int ticket, datetime openTime, double openPrice, datetime closeTime, double closePrice) {
   int lineColors[] = {Blue, Red};

   string sOpenPrice  = NumberToStr(openPrice, PriceFormat);
   string sClosePrice = NumberToStr(closePrice, PriceFormat);


   if (direction == OP_LONG) {
      // connecting line
      string lineLabel = StringConcatenate("#", ticket, " ", sOpenPrice, " -> ", sClosePrice);
      if (ObjectFind(lineLabel) == 0)
         ObjectDelete(lineLabel);
      if (ObjectCreate(lineLabel, OBJ_TREND, 0, openTime, openPrice, closeTime, closePrice)) {
         ObjectSet(lineLabel, OBJPROP_RAY,   false                );
         ObjectSet(lineLabel, OBJPROP_STYLE, STYLE_DOT            );
         ObjectSet(lineLabel, OBJPROP_COLOR, lineColors[direction]);
         ObjectSet(lineLabel, OBJPROP_BACK,  true                 );
      }

      // close marker
      string closeLabel = StringConcatenate("#", ticket, " close buy at ", sClosePrice);
      if (ObjectFind(closeLabel) == 0)
         ObjectDelete(closeLabel);
      if (ObjectCreate(closeLabel, OBJ_ARROW, 0, closeTime, closePrice)) {
         ObjectSet(closeLabel, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
         ObjectSet(closeLabel, OBJPROP_COLOR,     CLR_CLOSE        );
      }
      return;
   }


   if (direction == OP_SHORT) {
      // connecting line
      lineLabel = StringConcatenate("#", ticket, " ", sOpenPrice, " -> ", sClosePrice);
      if (ObjectFind(lineLabel) == 0)
         ObjectDelete(lineLabel);
      if (ObjectCreate(lineLabel, OBJ_TREND, 0, openTime, openPrice, closeTime, closePrice)) {
         ObjectSet(lineLabel, OBJPROP_RAY,   false                );
         ObjectSet(lineLabel, OBJPROP_STYLE, STYLE_DOT            );
         ObjectSet(lineLabel, OBJPROP_COLOR, lineColors[direction]);
         ObjectSet(lineLabel, OBJPROP_BACK,  true                 );
      }

      // close marker
      closeLabel = StringConcatenate("#", ticket, " close sell at ", sClosePrice);
      if (ObjectFind(closeLabel) == 0)
         ObjectDelete(closeLabel);
      if (ObjectCreate(closeLabel, OBJ_ARROW, 0, closeTime, closePrice)) {
         ObjectSet(closeLabel, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
         ObjectSet(closeLabel, OBJPROP_COLOR,     CLR_CLOSE        );
      }
      return;
   }

   catch("MarkClose(1)  invalid parameter direction = "+ direction, ERR_INVALID_PARAMETER);
}
