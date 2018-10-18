/**
 * Simple system following a single Moving Average
 *
 *
 * Available Moving Average types:
 *  • SMA  - Simple Moving Average:          equal bar weighting
 *  • LWMA - Linear Weighted Moving Average: bar weighting using a linear function
 *  • EMA  - Exponential Moving Average:     bar weighting using an exponential function
 *  • ALMA - Arnaud Legoux Moving Average:   bar weighting using a Gaussian function
 *  ----------------------------------------------------------------------------------------------------------------------
 *  • SMMA - Smoothed Moving Average:        not supported as it's just an EMA of a different period: SMMA(n) = EMA(2*n-1)
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
#include <rsfLibs.mqh>


int ma.periods;
int ma.method;


// position management
int long.position;
int short.position;


// OrderSend() defaults
double   os.slippage    = 0.1;
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
   if (EventListener.BarOpen()) {
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
   int trend = icMovingAverage(NULL, ma.periods, ma.method, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   if (trend == 1) {
      // entry if MA turned up
      int oe[], oeFlags=NULL;
      int ticket = OrderSendEx(Symbol(), OP_BUY, Lotsize, NULL, os.slippage, os.stopLoss, os.takeProfit, os.comment, os.magicNumber, os.expiration, CLR_OPEN_LONG, oeFlags, oe);
      if (!ticket) return;

      if (IsTesting()) /*&&*/ if (Test.ExternalReporting) {
         OrderSelect(ticket, SELECT_BY_TICKET);
         Test_onPositionOpen(__ExecutionContext, ticket, OP_BUY, Lotsize, Symbol(), OrderOpenPrice(), OrderOpenTime(), os.stopLoss, os.takeProfit, OrderCommission(), os.magicNumber, os.comment);
      }
      long.position = ticket;
   }
}


/**
 * Check for long exit conditions.
 */
void Long.CheckCloseSignal() {
   int trend = icMovingAverage(NULL, ma.periods, ma.method, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   if (trend == -1) {
      // exit if MA turned down
      int oe[], oeFlags=NULL;
      if (!OrderCloseEx(long.position, NULL, NULL, os.slippage, CLR_CLOSE, oeFlags, oe)) return;

      if (IsTesting()) /*&&*/ if (Test.ExternalReporting) {
         OrderSelect(long.position, SELECT_BY_TICKET);
         Test_onPositionClose(__ExecutionContext, long.position, OrderClosePrice(), OrderCloseTime(), OrderSwap(), OrderProfit());
      }
      long.position = 0;
   }
}


/**
 * Check for short entry conditions.
 */
void Short.CheckOpenSignal() {
   int trend = icMovingAverage(NULL, ma.periods, ma.method, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   if (trend == -1) {
      // entry if MA turned down
      int oe[], oeFlags=NULL;
      int ticket = OrderSendEx(Symbol(), OP_SELL, Lotsize, NULL, os.slippage, os.stopLoss, os.takeProfit, os.comment, os.magicNumber, os.expiration, CLR_OPEN_SHORT, oeFlags, oe);
      if (!ticket) return;

      if (IsTesting()) /*&&*/ if (Test.ExternalReporting) {
         OrderSelect(ticket, SELECT_BY_TICKET);
         Test_onPositionOpen(__ExecutionContext, ticket, OP_SELL, Lotsize, Symbol(), OrderOpenPrice(), OrderOpenTime(), os.stopLoss, os.takeProfit, OrderCommission(), os.magicNumber, os.comment);
      }
      short.position = ticket;
   }
}


/**
 * Check for short exit conditions.
 */
void Short.CheckCloseSignal() {
   int trend = icMovingAverage(NULL, ma.periods, ma.method, PRICE_CLOSE, 10, MovingAverage.MODE_TREND, 1);

   if (trend == 1) {
      // exit if MA turned up
      int oe[], oeFlags=NULL;
      if (!OrderCloseEx(short.position, NULL, NULL, os.slippage, CLR_CLOSE, oeFlags, oe)) return;

      if (IsTesting()) /*&&*/ if (Test.ExternalReporting) {
         OrderSelect(short.position, SELECT_BY_TICKET);
         Test_onPositionClose(__ExecutionContext, short.position, OrderClosePrice(), OrderCloseTime(), OrderSwap(), OrderProfit());
      }
      short.position = 0;
   }
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
