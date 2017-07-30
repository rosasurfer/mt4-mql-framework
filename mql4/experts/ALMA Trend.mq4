/**
 * ALMA trend following strategy (Arnaud Legoux Moving Average)
 *
 *
 * Rules (long and short):
 * -----------------------
 *  - Entry:      If the ALMA changes direction.
 *  - StopLoss:   At the extrem of the previous ALMA swing.
 *  - TakeProfit: At double the stoploss distance.
 *  - Exit:       If the ALMA changes direction again. Where and how exactly?
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////// Configuration ///////////////////////////////////////////////////////////////

extern int    Periods = 38;
extern double Lotsize = 0.1;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <iCustom/icMovingAverage.mqh>


// position management
int long.position;
int short.position;


// OrderSend() defaults
int      os.slippage    = 0;
double   os.stopLoss    = NULL;
double   os.takeProfit  = NULL;
datetime os.expiration  = NULL;
int      os.magicNumber = NULL;
string   os.comment     = "";


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
   if (Time[0] != lastBarOpenTime) {                        // tester BarOpen event, will fail live (on timeframe change)
      lastBarOpenTime = Time[0];

      // check long conditions
      if (trade.directions & TRADE_DIRECTIONS_LONG && 1) {
         if (!long.position) Long.CheckOpenSignal();
         else                Long.CheckCloseSignal();       // don't check for close on an open signal
      }

      // check short conditions
      if (trade.directions & TRADE_DIRECTIONS_SHORT && 1) {
         if (!short.position) Short.CheckOpenSignal();
         else                 Short.CheckCloseSignal();     // don't check for close on an open signal
      }
   }
   return(last_error);
}


/**
 * Check for long entry conditions.
 */
void Long.CheckOpenSignal() {
   int trend = icMovingAverage(NULL, Periods, "current", MODE_ALMA, PRICE_CLOSE, MovingAverage.MODE_TREND, 1);

   // entry: if ALMA turned up
   if (trend == 1) {
      int ticket = DoOrderSend(Symbol(), OP_BUY, Lotsize, Ask, os.slippage, os.stopLoss, os.takeProfit, os.comment, os.magicNumber, os.expiration, CLR_OPEN_LONG);
      long.position = ticket;
   }
}


/**
 * Check for long exit conditions.
 */
void Long.CheckCloseSignal() {
   int trend = icMovingAverage(NULL, Periods, "current", MODE_ALMA, PRICE_CLOSE, MovingAverage.MODE_TREND, 1);

   // exit: if ALMA turned down
   if (trend == -1) {
      int ticket = long.position;
      OrderSelect(ticket, SELECT_BY_TICKET);
      DoOrderClose(ticket, OrderLots(), Bid, os.slippage, CLR_CLOSE);
      long.position = 0;
   }
}


/**
 * Check for short entry conditions.
 */
void Short.CheckOpenSignal() {
   int trend = icMovingAverage(NULL, Periods, "current", MODE_ALMA, PRICE_CLOSE, MovingAverage.MODE_TREND, 1);

   // entry: if ALMA turned down
   if (trend == -1) {
      int ticket = DoOrderSend(Symbol(), OP_SELL, Lotsize, Bid, os.slippage, os.stopLoss, os.takeProfit, os.comment, os.magicNumber, os.expiration, CLR_OPEN_SHORT);
      short.position = ticket;
   }
}


/**
 * Check for short exit conditions.
 */
void Short.CheckCloseSignal() {
   int trend = icMovingAverage(NULL, Periods, "current", MODE_ALMA, PRICE_CLOSE, MovingAverage.MODE_TREND, 1);

   // exit: if ALMA turned up
   if (trend == 1) {
      int ticket = short.position;
      OrderSelect(ticket, SELECT_BY_TICKET);
      DoOrderClose(ticket, OrderLots(), Ask, os.slippage, CLR_CLOSE);
      short.position = 0;
   }
}


/**
 * Open an order with the specified details.
 *
 * @param  string   symbol
 * @param  int      type
 * @param  double   lots
 * @param  double   price
 * @param  int      slippage
 * @param  double   stopLoss
 * @param  double   takeProfit
 * @param  string   comment
 * @param  int      magicNumber
 * @param  datetime expiration
 * @param  color    marker
 *
 * @return int - the resulting order ticket
 */
int DoOrderSend(string symbol, int type, double lots, double price, int slippage, double stopLoss, double takeProfit, string comment, int magicNumber, datetime expiration, color marker) {
   if (Trades.Reverse) {
      if (type == OP_BUY ) {          type   = OP_SELL;
         if (EQ(price, Ask))          price  = Bid;
         if (marker == CLR_OPEN_LONG) marker = CLR_OPEN_SHORT;
      }
      else if (type == OP_SELL) {      type   = OP_BUY;
         if (EQ(price, Bid))           price  = Ask;
         if (marker == CLR_OPEN_SHORT) marker = CLR_OPEN_LONG;
      }
      double tmp = takeProfit;
      takeProfit = stopLoss;
      stopLoss   = takeProfit;
   }

   int ticket = OrderSend(symbol, type, lots, price, slippage, stopLoss, takeProfit, comment, magicNumber, expiration, marker);

   if (IsTesting()) /*&&*/ if (Tester.EnableReporting) {
      OrderSelect(ticket, SELECT_BY_TICKET);
      Test_OpenOrder(__ExecutionContext, ticket, type, lots, symbol, OrderOpenPrice(), OrderOpenTime(), stopLoss, takeProfit, OrderCommission(), magicNumber, comment);
   }
   return(ticket);
}


/**
 * Close the specified order.
 *
 * @param  int    ticket
 * @param  double lots
 * @param  double price
 * @param  int    slippage
 * @param  color  marker
 *
 * @return bool - success status
 */
bool DoOrderClose(int ticket, double lots, double price, int slippage, color marker) {
   if (Trades.Reverse) {
      OrderSelect(ticket, SELECT_BY_TICKET);
      int type = OrderType();

      if (type == OP_BUY ) {
         if (EQ(price, Ask)) price = Bid;
      }
      else if (type == OP_SELL) {
         if (EQ(price, Bid)) price = Ask;
      }
   }
   bool result = OrderClose(ticket, lots, price, slippage, marker);

   if (IsTesting()) /*&&*/ if (Tester.EnableReporting) {
      OrderSelect(ticket, SELECT_BY_TICKET);
      Test_CloseOrder(__ExecutionContext, ticket, OrderClosePrice(), OrderCloseTime(), OrderSwap(), OrderProfit());
   }
   return(result);
}
