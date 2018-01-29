/**
 * Monitor the market for an ALMA trend change and execute a trade command.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    ALMA.Periods                    = 38;
extern string ALMA.Timeframe                  = "";      // M1 | M5 | M15...
extern string _1_____________________________ = "";
extern double Open.Lots                       = 0.01;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/EventListener.BarOpen.mqh>
#include <functions/JoinStrings.mqh>
#include <iCustom/icMovingAverage.mqh>
#include <MT4iQuickChannel.mqh>
#include <lfx.mqh>
#include <structs/xtrade/LFXOrder.mqh>


int ma.periods;
int ma.timeframe;


// order marker colors
#define CLR_OPEN_LONG      C'0,0,254'           // Blue - (1,1,1)
#define CLR_OPEN_SHORT     C'254,0,0'           // Red  - (1,1,1)


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // (1) initialize trade account
   if (!InitTradeAccount())
      return(last_error);

   // (2) validate input parameters
   // ALMA.Periods
   if (ALMA.Periods < 2)                    return(catch("onInit(1)  Invalid input parameter ALMA.Periods = "+ ALMA.Periods, ERR_INVALID_INPUT_PARAMETER));
   ma.periods = ALMA.Periods;

   // ALMA.Timeframe
   if (This.IsTesting() && ALMA.Timeframe=="") ma.timeframe = Period();
   else                                        ma.timeframe = StrToTimeframe(ALMA.Timeframe, F_ERR_INVALID_PARAMETER);
   if (ma.timeframe == -1)                  return(catch("onInit(2)  Invalid input parameter ALMA.Timeframe = "+ DoubleQuoteStr(ALMA.Timeframe), ERR_INVALID_INPUT_PARAMETER));
   ALMA.Timeframe = TimeframeDescription(ma.timeframe);

   // Open.Lots
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   if (LT(Open.Lots, minLot))               return(catch("onInit(3)  Illegal input parameter lots = "+ NumberToStr(Open.Lots, ".+") +" (MinLot="+ NumberToStr(minLot, ".+") +")", ERR_INVALID_INPUT_PARAMETER));
   if (GT(Open.Lots, maxLot))               return(catch("onInit(4)  Illegal input parameter lots = "+ NumberToStr(Open.Lots, ".+") +" (MaxLot="+ NumberToStr(maxLot, ".+") +")", ERR_INVALID_INPUT_PARAMETER));
   if (MathModFix(Open.Lots, lotStep) != 0) return(catch("onInit(5)  Illegal input parameter lots = "+ NumberToStr(Open.Lots, ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", ERR_INVALID_INPUT_PARAMETER));
   Open.Lots = NormalizeDouble(Open.Lots, CountDecimals(lotStep));

   return(catch("onInit(6)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check ALMA trend on BarOpen
   if (EventListener.BarOpen(ma.timeframe)) {
      int trend = GetALMA(MovingAverage.MODE_TREND, 1);

      if (trend == 1) {
         DoOrderSend(OP_BUY, Open.Lots);
      }
      else if (trend == -1) {
         DoOrderSend(OP_SELL, Open.Lots);
      }
   }
   return(last_error);
}


/**
 * Return an ALMA indicator value.
 *
 * @param  int buffer - buffer index of the value to return
 * @param  int bar    - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of an error
 */
double GetALMA(int buffer, int bar) {
   int maxValues = 150;                         // should cover the longest possible trending period (seen: 95)
   return(icMovingAverage(ma.timeframe, ALMA.Periods, ALMA.Timeframe, MODE_ALMA, PRICE_CLOSE, maxValues, buffer, bar));
}


/**
 * Open a position at the current price.
 *
 * @param  int    type - position type: OP_BUY|OP_SELL
 * @param  double lots - position size
 *
 * @return int - order ticket or NULL in case of errors
 */
int DoOrderSend(int type, double lots) {
   string   symbol      = Symbol();
   double   price       = NULL;
   double   slippage    = 0.1;
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   string   comment     = "";
   int      magicNumber = NULL;
   datetime expires     = NULL;
   color    markerColor = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);
   int      oeFlags     = NULL;
   int      oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);

   return(OrderSendEx(symbol, type, lots, price, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe));
}
