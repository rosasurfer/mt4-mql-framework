/**
 * BollingerBand Trend System.
 *
 * Long
 * ----
 *  - Buy:        If price crosses BBand(40, MODE_UPPER).
 *  - StopLoss:   If the last bar closed below BBand(40, MODE_MAIN) = Risk.
 *  - TakeProfit: If price crosses BBand(40, MODE_UPPER) + 1*Risk = BBand(40, 4, MODE_UPPER).
 *  - Skip the signal if it occures at or above the TakeProfit level.
 *
 * Short
 * -----
 *  - Sell:       If price crosses BBand(40, MODE_LOWER).
 *  - StopLoss:   If the last bar closed above BBand(40, MODE_MAIN) = Risk.
 *  - TakeProfit: If price crosses BBand(40, MODE_LOWER) - 1*Risk = BBand(40, 4, MODE_LOWER).
 *  - Skip the signal if it occures at or below the TakeProfit level.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////// Configuration ///////////////////////////////////////////////////////////////

extern int    BB.Periods   = 40;
extern double BB.Deviation = 2;
extern double Risk.Reward  = 1;
extern double Lotsize      = 0.1;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>


// position management
int    long.position;
double long.takeProfit;

int    short.position;
double short.takeProfit;


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
   if (Time[0] != lastBarOpenTime) {                     // simplified BarOpen event, fails on Indicator::init()
      lastBarOpenTime = Time[0];

      // check long conditions
      if (!long.position) Long.CheckOpenSignal();
      else                Long.CheckCloseSignal();       // don't check for close on an open signal

      // check short conditions
      if (!short.position) Short.CheckOpenSignal();
      else                 Short.CheckCloseSignal();     // don't check for close on an open signal
   }
   return(last_error);
}


/**
 * Check for long entry conditions.
 */
void Long.CheckOpenSignal() {
   double bb2.Upper  = iBands(NULL, NULL, BB.Periods,                 BB.Deviation, 0, PRICE_CLOSE, MODE_UPPER, 2);
   double bb1.Upper  = iBands(NULL, NULL, BB.Periods,                 BB.Deviation, 0, PRICE_CLOSE, MODE_UPPER, 1);
   double takeProfit = iBands(NULL, NULL, BB.Periods, (1+Risk.Reward)*BB.Deviation, 0, PRICE_CLOSE, MODE_UPPER, 1);

   if ((Close[2] < bb2.Upper && Close[1] > bb1.Upper) || (Close[1] < bb1.Upper && Open[0] > bb1.Upper)) {
      if (Open[0] < takeProfit) {
         int ticket = DoOrderSend(Symbol(), OP_BUY, Lotsize, Ask, os.slippage, os.stopLoss, os.takeProfit, os.comment, os.magicNumber, os.expiration, CLR_OPEN_LONG);
         long.position   = ticket;
         long.takeProfit = takeProfit;
      }
   }
}


/**
 * Check for long exit conditions.
 */
void Long.CheckCloseSignal() {
   bool close = false;

   // TakeProfit
   if (Close[1] >= long.takeProfit || Open[0] >= long.takeProfit) {
      close = true;
   }
   // StopLoss
   else if (Close[1] <= iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_MAIN, 1)) {
      close = true;
   }

   if (close) {
      int ticket = long.position;
      OrderSelect(ticket, SELECT_BY_TICKET);
      DoOrderClose(ticket, OrderLots(), Bid, os.slippage, CLR_CLOSE);
      long.position   = 0;
      long.takeProfit = 0;
   }
}


/**
 * Check for short entry conditions.
 */
void Short.CheckOpenSignal() {
   double bb2.Lower  = iBands(NULL, NULL, BB.Periods,                 BB.Deviation, 0, PRICE_CLOSE, MODE_LOWER, 2);
   double bb1.Lower  = iBands(NULL, NULL, BB.Periods,                 BB.Deviation, 0, PRICE_CLOSE, MODE_LOWER, 1);
   double takeProfit = iBands(NULL, NULL, BB.Periods, (1+Risk.Reward)*BB.Deviation, 0, PRICE_CLOSE, MODE_LOWER, 1);

   if ((Close[2] > bb2.Lower && Close[1] < bb1.Lower) || (Close[1] > bb1.Lower && Open[0] < bb1.Lower)) {
      if (Open[0] > takeProfit) {
         int ticket = DoOrderSend(Symbol(), OP_SELL, Lotsize, Bid, os.slippage, os.stopLoss, os.takeProfit, os.comment, os.magicNumber, os.expiration, CLR_OPEN_SHORT);
         short.position   = ticket;
         short.takeProfit = takeProfit;
      }
   }
}


/**
 * Check for short exit conditions.
 */
void Short.CheckCloseSignal() {
   bool close = false;

   // TakeProfit
   if (Close[1] <= short.takeProfit || Open[0] <= short.takeProfit) {
      close = true;
   }
   // StopLoss
   else if (Close[1] >= iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_MAIN, 1)) {
      close = true;
   }

   if (close) {
      int ticket = short.position;
      OrderSelect(ticket, SELECT_BY_TICKET);
      DoOrderClose(ticket, OrderLots(), Ask, os.slippage, CLR_CLOSE);
      short.position   = 0;
      short.takeProfit = 0;
   }
}


/**
 * Open an order with the specified order details.
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

   if (IsTesting()) {
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

   if (IsTesting()) {
      OrderSelect(ticket, SELECT_BY_TICKET);
      Test_CloseOrder(__ExecutionContext, ticket, OrderClosePrice(), OrderCloseTime(), OrderSwap(), OrderProfit());
   }
   return(result);
}
