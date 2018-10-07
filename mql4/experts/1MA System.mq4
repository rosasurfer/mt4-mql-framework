/**
 * Simple system using a single Moving Average
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Periods = 100;
extern double Lotsize = 0.1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <functions/EventListener.BarOpen.mqh>
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
#define CLR_OPEN_LONG         C'0,0,254'              // Blue - C'1,1,1'
#define CLR_OPEN_SHORT        C'254,0,0'              // Red  - C'1,1,1'
#define CLR_OPEN_TAKEPROFIT   Blue
#define CLR_OPEN_STOPLOSS     Red
#define CLR_CLOSE             Orange


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (Tick==1 || EventListener.BarOpen()) {
      // check long conditions
      if (!long.position) Long.CheckOpenSignal();
      else                Long.CheckCloseSignal();

      // check short conditions
      if (!short.position) Short.CheckOpenSignal();
      else                 Short.CheckCloseSignal();
   }
   return(last_error);
}


/**
 * Check for long entry conditions.
 */
void Long.CheckOpenSignal() {
   int trend = icMovingAverage(NULL, Periods, MODE_SMA, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   // entry if MA turned up
   if (trend == 1) {
      int ticket = DoOrderSend(Symbol(), OP_BUY, Lotsize, Ask, os.slippage, os.stopLoss, os.takeProfit, os.comment, os.magicNumber, os.expiration, CLR_OPEN_LONG);
      long.position = ticket;
   }
}


/**
 * Check for long exit conditions.
 */
void Long.CheckCloseSignal() {
   int trend = icMovingAverage(NULL, Periods, MODE_SMA, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   // exit if MA turned down
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
   int trend = icMovingAverage(NULL, Periods, MODE_SMA, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   // entry if MA turned down
   if (trend == -1) {
      int ticket = DoOrderSend(Symbol(), OP_SELL, Lotsize, Bid, os.slippage, os.stopLoss, os.takeProfit, os.comment, os.magicNumber, os.expiration, CLR_OPEN_SHORT);
      short.position = ticket;
   }
}


/**
 * Check for short exit conditions.
 */
void Short.CheckCloseSignal() {
   int trend = icMovingAverage(NULL, Periods, MODE_SMA, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   // exit if MA turned up
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
   return(OrderSend(symbol, type, lots, price, slippage, stopLoss, takeProfit, comment, magicNumber, expiration, marker));
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
   return(OrderClose(ticket, lots, price, slippage, marker));
}


/**
 * Return a string representation of the input parameters (used for logging).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "Periods=", Periods                    , "; ",
                            "Lotsize=", NumberToStr(Lotsize, ".1+"), "; ")
   );
}
