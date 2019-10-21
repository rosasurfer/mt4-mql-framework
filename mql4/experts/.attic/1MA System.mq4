/**
 * Simple system following a single Moving Average
 *
 *
 * Available Moving Average types:
 *  • SMA  - Simple Moving Average:          equal bar weighting
 *  • LWMA - Linear Weighted Moving Average: bar weighting using a linear function
 *  • EMA  - Exponential Moving Average:     bar weighting using an exponential function;       SMMA(n) = EMA(2*n-1)
 *  • ALMA - Arnaud Legoux Moving Average:   bar weighting using a Gaussian function
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods = 0;
extern string MA.Method  = "SMA* | LWMA | EMA | ALMA";
extern double Lotsize    = 0.1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/BarOpenEvent.mqh>
#include <iCustom/icMovingAverage.mqh>


int ma.periods;
int ma.method;


// position management
int long.position;
int short.position;


// order defaults
double o.slippage    = 0.1;
double o.takeProfit  = NULL;
double o.stopLoss    = NULL;
int    o.magicNumber = NULL;
string o.comment     = "";


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
      sValue = StrTrim(MA.Method);
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
   if (IsBarOpenEvent()) {
      if (!long.position) Long.CheckOpenPosition();
      else                Long.CheckClosePosition();

      if (!short.position) Short.CheckOpenPosition();
      else                 Short.CheckClosePosition();
   }
   return(last_error);
}


/**
 * Check for long entry conditions.
 *
 * @return bool - success status
 */
bool Long.CheckOpenPosition() {
   int trend = icMovingAverage(NULL, ma.periods, ma.method, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   if (trend == 1) {
      // entry if MA turned up
      int oe[], oeFlags=NULL;
      int ticket = OrderSendEx(Symbol(), OP_BUY, Lotsize, NULL, o.slippage, o.stopLoss, o.takeProfit, o.comment, o.magicNumber, NULL, CLR_OPEN_LONG, oeFlags, oe);
      if (!ticket) return(false);
      long.position = ticket;
   }
   return(!last_error);
}


/**
 * Check for long exit conditions.
 *
 * @return bool - success status
 */
bool Long.CheckClosePosition() {
   int trend = icMovingAverage(NULL, ma.periods, ma.method, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   if (trend == -1) {
      // exit if MA turned down
      int oe[], oeFlags=NULL;
      if (!OrderCloseEx(long.position, NULL, o.slippage, CLR_CLOSE, oeFlags, oe)) return(false);
      long.position = 0;
   }
   return(!last_error);
}


/**
 * Check for short entry conditions.
 *
 * @return bool - success status
 */
bool Short.CheckOpenPosition() {
   int trend = icMovingAverage(NULL, ma.periods, ma.method, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   if (trend == -1) {
      // entry if MA turned down
      int oe[], oeFlags=NULL;
      int ticket = OrderSendEx(Symbol(), OP_SELL, Lotsize, NULL, o.slippage, o.stopLoss, o.takeProfit, o.comment, o.magicNumber, NULL, CLR_OPEN_SHORT, oeFlags, oe);
      if (!ticket) return(false);
      short.position = ticket;
   }
   return(!last_error);
}


/**
 * Check for short exit conditions.
 *
 * @return bool - success status
 */
bool Short.CheckClosePosition() {
   int trend = icMovingAverage(NULL, ma.periods, ma.method, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   if (trend == 1) {
      // exit if MA turned up
      int oe[], oeFlags=NULL;
      if (!OrderCloseEx(short.position, NULL, o.slippage, CLR_CLOSE, oeFlags, oe)) return(false);
      short.position = 0;
   }
   return(!last_error);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=", MA.Periods,                  ";", NL,
                            "MA.Method=",  DoubleQuoteStr(MA.Method),   ";", NL,
                            "Lotsize=",    NumberToStr(Lotsize, ".1+"), ";")
   );
}
