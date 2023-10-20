/**
 * Auto-Liquidation
 *
 * This EA's purpose is protection of the trading account and enforcing adherence to a daily loss/drawdown limit (DDL). It
 * monitors floating PnL of open positions. Once a predefined drawdown limit has been reached it closes all positions and
 * pending orders. The EA monitors positions of all symbols, not only the symbol of the chart where it's attached.
 *
 * The EA should run in a separate terminal connected 24/7 to the trade server. For best operation it's strongly advised to
 * setup a hosted environment (VM or dedicated server).
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_BUFFERED_LOG, INIT_NO_EXTERNAL_REPORTING};
int __DeinitFlags[];
int __virtualTicks  = 800;                         // every 0.8 seconds (must be short as it watches all symbols)

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string DrawdownLimit = "200.00 | 5%*";      // absolute or percentage limit
extern bool   IgnoreSpread  = false;               // whether to not track the spread of open positions (to prevent liquidation by spread widening)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ComputeFloatingPnL.mqh>


double prevEquity;                                 // equity value at the previous tick
bool   isPctLimit;                                 // whether a percent limit is configured
double absLimit;                                   // configured absolute drawdown limit
double pctLimit;                                   // configured percentage drawdown limit

string watchedSymbols  [];
double watchedPositions[][2];

#define I_DRAWDOWN_LIMIT   0                       // indexes of watchedPositions[]
#define I_PROFIT           1

datetime lastLiquidationTime;


/**
 * Initialization.
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs: DrawdownLimit
   string sValue="", values[];
   if (Explode(DrawdownLimit, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = StrTrim(values[size-1]);
   }
   else {
      sValue = StrTrim(DrawdownLimit);
   }
   isPctLimit = StrEndsWith(sValue, "%");
   if (isPctLimit) sValue = StrTrimRight(StrLeft(sValue, -1));
   if (!StrIsNumeric(sValue)) return(catch("onInit(1)  invalid parameter DrawdownLimit: "+ DoubleQuoteStr(DrawdownLimit), ERR_INVALID_PARAMETER));
   double dValue = NormalizeDouble(-MathAbs(StrToDouble(sValue)), 2);
   if (isPctLimit) {
      pctLimit = dValue;
      absLimit = NULL;
      if (!pctLimit)          return(catch("onInit(2)  illegal parameter DrawdownLimit: "+ DoubleQuoteStr(DrawdownLimit) +" (must be != 0)", ERR_INVALID_PARAMETER));
      if (pctLimit <= -100)   return(catch("onInit(3)  illegal parameter DrawdownLimit: "+ DoubleQuoteStr(DrawdownLimit) +" (must be > -100)", ERR_INVALID_PARAMETER));
      DrawdownLimit = NumberToStr(pctLimit, ".+") +"%";
   }
   else {
      pctLimit = NULL;
      absLimit = dValue;
      if (!absLimit)          return(catch("onInit(4)  illegal parameter DrawdownLimit: "+ DoubleQuoteStr(DrawdownLimit) +" (must be != 0)", ERR_INVALID_PARAMETER));
      DrawdownLimit = DoubleToStr(absLimit, 2);
   }
   return(catch("onInit(5)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // get open positions
   string openSymbols[];
   double openPositions[];
   if (!ComputeFloatingPnLs(openSymbols, openPositions, IgnoreSpread)) return(last_error);

   // calculate current equity
   double equity = AccountBalance();
   int openSize = ArraySize(openSymbols);
   for (int i=0; i < openSize; i++) {
      equity += openPositions[i];
   }

   // synchronize watched positions
   int watchedSize = ArraySize(watchedSymbols);
   for (i=0; i < watchedSize; i++) {
      int n = SearchStringArray(openSymbols, watchedSymbols[i]);
      if (n == -1) {
         // position closed, remove watched position
         logInfo("onTick(1)  "+ watchedSymbols[i] +" position closed");

         if (watchedSize > i+1) {
            ArrayCopy(watchedSymbols,   watchedSymbols,   i,   i+1);
            ArrayCopy(watchedPositions, watchedPositions, i*2, (i+1)*2);
         }
         watchedSize--;
         ArrayResize(watchedSymbols,   watchedSize);
         ArrayResize(watchedPositions, watchedSize);
         i--;
      }
      else {
         // update watched position and remove open position
         watchedPositions[i][I_PROFIT] = openPositions[n];
         if (openSize > n+1) {
            ArrayCopy(openSymbols,   openSymbols,   n, n+1);
            ArrayCopy(openPositions, openPositions, n, n+1);
         }
         openSize--;
         ArrayResize(openSymbols,   openSize);
         ArrayResize(openPositions, openSize);
      }
   }

   if (openSize > 0) {
      // auto-liquidate new positions after previous auto-liquidation on the same day
      datetime today = TimeFXT();
      today -= (today % DAY);
      datetime lastLiquidation = lastLiquidationTime - lastLiquidationTime % DAY;
      if (lastLiquidation == today) {
         logWarn("onTick(2)  liquidating illegal new position (auto-liquidation until end of day)");
         ArrayResize(watchedSymbols, 0);
         ArrayResize(watchedPositions, 0);
         CloseOpenOrders();
         return(catch("onTick(3)"));
      }
   }

   // watch new position
   for (i=0; prevEquity && i < openSize; i++) {
      ArrayResize(watchedSymbols,   watchedSize+1);
      ArrayResize(watchedPositions, watchedSize+1);
      watchedSymbols  [watchedSize]                   = openSymbols[i];
      watchedPositions[watchedSize][I_DRAWDOWN_LIMIT] = ifDouble(isPctLimit, NormalizeDouble(prevEquity * pctLimit/100, 2), absLimit);
      watchedPositions[watchedSize][I_PROFIT        ] = openPositions[i];
      logInfo("onTick(4)  watching "+ watchedSymbols[watchedSize] +" position, drawdownLimit="+ DoubleToStr(watchedPositions[watchedSize][I_DRAWDOWN_LIMIT], 2));
      watchedSize++;
   }
   prevEquity = equity;

   // monitor drawdown limit
   for (i=0; i < watchedSize; i++) {
      double profit  = watchedPositions[i][I_PROFIT];
      double ddLimit = watchedPositions[i][I_DRAWDOWN_LIMIT];
      if (profit < ddLimit) {
         lastLiquidationTime = TimeFXT();
         logWarn("onTick(5)  "+ watchedSymbols[i] +": drawdown limit of "+ DrawdownLimit +" reached, liquidating positions...");
         ArrayResize(watchedSymbols, 0);
         ArrayResize(watchedPositions, 0);
         CloseOpenOrders();
         break;
      }
   }
   return(catch("onTick(6)"));
}


/**
 * Close all open positions and pending orders.
 *
 * @return bool - success status
 */
bool CloseOpenOrders() {
   int orders = OrdersTotal(), pendings[], positions[];
   ArrayResize(pendings, 0);
   ArrayResize(positions, 0);

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;
      if (OrderType() > OP_SELLSTOP)                   continue;

      if (OrderType() > OP_SELL) ArrayPushInt(pendings, OrderTicket());
      else                       ArrayPushInt(positions, OrderTicket());
   }

   int oe[], oes[][ORDER_EXECUTION_intSize], oeFlags=NULL;

   if (ArraySize(positions) > 0) {
      if (!OrdersClose(positions, 1, CLR_NONE, oeFlags, oes)) return(false);
   }
   for (i=ArraySize(pendings)-1; i >= 0; i--) {
      if (!OrderDeleteEx(pendings[i], CLR_NONE, oeFlags, oe)) return(false);
   }
   return(!catch("CloseOpenOrders(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("DrawdownLimit=", DoubleQuoteStr(DrawdownLimit), ";", NL,
                            "IgnoreSpread=",  BoolToStr(IgnoreSpread),       ";"));
}
