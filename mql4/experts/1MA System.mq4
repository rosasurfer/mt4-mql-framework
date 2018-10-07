/**
 * Simple system following a single Moving Average
 *
 *
 * Available Moving Average types:
 *  • SMA  - Simple Moving Average:          equal bar weighting
 *  • LWMA - Linear Weighted Moving Average: bar weighting using a linear function
 *  • EMA  - Exponential Moving Average:     bar weighting using an exponential function
 *  • ALMA - Arnaud Legoux Moving Average:   bar weighting using a Gaussian function
 *
 * The Smoothed Moving Average (SMMA) is omitted as it's just an EMA of a different period: SMMA(n) = EMA(2*n-1)
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods = 100;
extern string MA.Method  = "SMA* | LWMA | EMA | ALMA";
extern double Lotsize    = 0.1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <functions/EventListener.BarOpen.mqh>
#include <iCustom/icMovingAverage.mqh>


int ma.periods;
int ma.method;


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
 * Initialization.
 *
 * @return int - error status
 */
int onInit() {
   // (1) validate inputs
   // MA.Periods
   if (MA.Periods < 1)     return(catch("onInit(1)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   ma.periods = MA.Periods;

   // MA.Method
   string sValue, values[];
   if (Explode(MA.Method, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   else {
      sValue = StringTrim(MA.Method);
      if (sValue == "") sValue = "SMA";                                 // default MA method
   }
   ma.method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (ma.method == -1)    return(catch("onInit(2)  Invalid input parameter MA.Method = "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(ma.method);

   return(catch("onInit(3)"));
}


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
   int trend = icMovingAverage(NULL, ma.periods, MA.Method, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   // entry if MA turned up
   if (trend == 1) {
      long.position = OrderSend(Symbol(), OP_BUY, Lotsize, Ask, os.slippage, os.stopLoss, os.takeProfit, os.comment, os.magicNumber, os.expiration, CLR_OPEN_LONG);
   }
}


/**
 * Check for long exit conditions.
 */
void Long.CheckCloseSignal() {
   int trend = icMovingAverage(NULL, ma.periods, MA.Method, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   // exit if MA turned down
   if (trend == -1) {
      OrderSelect(long.position, SELECT_BY_TICKET);
      OrderClose(long.position, OrderLots(), Bid, os.slippage, CLR_CLOSE);
      long.position = 0;
   }
}


/**
 * Check for short entry conditions.
 */
void Short.CheckOpenSignal() {
   int trend = icMovingAverage(NULL, ma.periods, MA.Method, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   // entry if MA turned down
   if (trend == -1) {
      short.position = OrderSend(Symbol(), OP_SELL, Lotsize, Bid, os.slippage, os.stopLoss, os.takeProfit, os.comment, os.magicNumber, os.expiration, CLR_OPEN_SHORT);
   }
}


/**
 * Check for short exit conditions.
 */
void Short.CheckCloseSignal() {
   int trend = icMovingAverage(NULL, ma.periods, MA.Method, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   // exit if MA turned up
   if (trend == 1) {
      OrderSelect(short.position, SELECT_BY_TICKET);
      OrderClose(short.position, OrderLots(), Ask, os.slippage, CLR_CLOSE);
      short.position = 0;
   }
}


/**
 * Return a string representation of the input parameters (used for logging).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",
                            "MA.Periods=", MA.Periods,                  "; ",
                            "MA.Method=",  DoubleQuoteStr(MA.Method),   "; ",
                            "Lotsize=",    NumberToStr(Lotsize, ".1+"), "; ")
   );
}
