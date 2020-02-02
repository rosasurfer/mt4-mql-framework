/**
 * Mark entry and exit signals of the "ALMA Trend" strategy.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

#property show_inputs

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern datetime Trades.Startdate  = D'2016.01.01';
extern string   Trades.Directions = "Long | Short | Both*";
extern string   _______________________________;
extern int      Periods           = 38;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/iBarShiftNext.mqh>
#include <functions/iBarShiftPrevious.mqh>


// trading configuration
int trade.directions = TRADE_DIRECTION_BOTH;
int trade.startBar;
int ticket;                                              // virtual ticket number

// position tracking
int      long.position;
datetime long.openTime;
double   long.openPrice;

int      short.position;
datetime short.openTime;
double   short.openPrice;


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
   // Trades.Direction
   string strValue, elems[];
   if (Explode(Trades.Directions, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      strValue = elems[size-1];
   }
   else strValue = Trades.Directions;
   trade.directions = StrToTradeDirection(strValue, F_ERR_INVALID_PARAMETER);
   if (trade.directions <= 0 || trade.directions > TRADE_DIRECTION_BOTH)
      return(catch("onInit(1)  Invalid input parameter Trades.Directions = "+ DoubleQuoteStr(Trades.Directions), ERR_INVALID_INPUT_PARAMETER));
   Trades.Directions = TradeDirectionDescription(trade.directions);

   return(catch("onInit(2)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   // (1) calculate start bar                                  // TODO: check available bars for indicator calculation
   int bar = iBarShiftPrevious(NULL, NULL, Trades.Startdate);
   if (bar == -1) return(catch("onStart(1)  No history found for "+ TimeToStr(Trades.Startdate, TIME_DATE|TIME_MINUTES), ERR_HISTORY_INSUFFICIENT));

   trade.startBar = iBarShiftNext(NULL, NULL, Trades.Startdate);
   if (trade.startBar == -1) return(catch("onStart(2)  History not loaded for "+ TimeToStr(Trades.Startdate, TIME_DATE|TIME_MINUTES), ERR_HISTORY_INSUFFICIENT));


   // (2) calculate signals for each bar
   for (bar=trade.startBar; bar >= 0; bar--) {
      // check long conditions
      if (trade.directions & TRADE_DIRECTION_LONG && 1) {
         if (!long.position) Long.CheckOpenSignal(bar);
         else                Long.CheckCloseSignal(bar);       // don't check for close on an open signal
      }

      // check short conditions
      if (trade.directions & TRADE_DIRECTION_SHORT && 1) {
         if (!short.position) Short.CheckOpenSignal(bar);
         else                 Short.CheckCloseSignal(bar);     // don't check for close on an open signal
      }
   }
   return(catch("onStart(3)"));
}


/**
 * Check for long entry conditions.
 *
 * @param  int bar - bar offset
 */
void Long.CheckOpenSignal(int bar) {
   int trend = iMovingAverage(NULL, Periods, MODE_ALMA, PRICE_CLOSE, MovingAverage.MODE_TREND, bar+1);

   // entry: if ALMA turned up
   if (trend == 1) {
      ticket++;
      long.position  = ticket;
      long.openTime  = Time[bar];
      long.openPrice = Open[bar];
      MarkOpen(OP_LONG, long.position, long.openTime, long.openPrice);
   }
}


/**
 * Check for long exit conditions.
 *
 * @param  int bar - bar offset
 */
void Long.CheckCloseSignal(int bar) {
   int trend = iMovingAverage(NULL, Periods, MODE_ALMA, PRICE_CLOSE, MovingAverage.MODE_TREND, bar+1);

   // exit: if ALMA turned down
   if (trend == -1) {
      MarkClose(OP_LONG, long.position, long.openTime, long.openPrice, Time[bar], Open[bar]);
      long.position = 0;
   }
}


/**
 * Check for short entry conditions.
 *
 * @param  int bar - bar offset
 */
void Short.CheckOpenSignal(int bar) {
   int trend = iMovingAverage(NULL, Periods, MODE_ALMA, PRICE_CLOSE, MovingAverage.MODE_TREND, bar+1);

   // entry: if ALMA turned down
   if (trend == -1) {
      ticket++;
      short.position  = ticket;
      short.openTime  = Time[bar];
      short.openPrice = Open[bar];
      MarkOpen(OP_SHORT, short.position, short.openTime, short.openPrice);
   }
}


/**
 * Check for short exit conditions.
 *
 * @param  int bar - bar offset
 */
void Short.CheckCloseSignal(int bar) {
   int trend = iMovingAverage(NULL, Periods, MODE_ALMA, PRICE_CLOSE, MovingAverage.MODE_TREND, bar+1);

   // exit: if ALMA turned up
   if (trend == 1) {
      MarkClose(OP_SHORT, short.position, short.openTime, short.openPrice, Time[bar], Open[bar]);
      short.position = 0;
   }
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
