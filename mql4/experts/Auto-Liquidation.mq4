/**
 * Auto-Liquidation
 *
 * The EA's purpose is protection of the trading account and supporting adherence to a daily loss/drawdown limit (DDL). It
 * monitors floating PnL of open positions, and once a predefined drawdown limit has been reached it closes all positions and
 * pending orders. The EA monitors all symbols, not only the symbol of the chart where it is attached.
 *
 * The EA should run in a separate trading terminal connected 24/7 to the trade server. For best operation it's strongly
 * advised to setup a hosted environment (VM or dedicated server).
 *
 *
 * Approaches:
 *  (1) total stoploss (faster to implement but not exact and too simple)
 *  -----------------------------------------------------------------------------
 *  determine total equity start value  => equity peak
 *  calculate total floating PL
 *  monitor total drawdown and trigger total liquidation
 *
 *
 *  (2) stoploss per single position (more exact but also more complex to implement)
 *  ----------------------------------------------------------------------------------------
 *  determine symbols with open positions/trade sequences
 *  determine equity start values per symbol  => reset on reset-custom-position  => manual reset, later signal order (issues with multiple charts)
 *  calculate PL of open positions per symbol
 *  monitor drawdown per position and trigger liquidation of single position
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_BUFFERED_LOG, INIT_NO_EXTERNAL_REPORTING};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Parameter = "dummy";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ComputeFloatingPnLs.mqh>


/**
 * Initialization.
 *
 * @return int - error status
 */
int onInit() {
   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // monitor total drawdown from last equity peak
   //if (!equityStart) equityStart = GetEquityHigh(PERIOD_D1);


   // compute floating PnL and resulting equity
   string symbols[];
   double profits[];                               // w/o spread: we don't want liquidation to be triggered by spread widening
   if (!ComputeFloatingPnLs(symbols, profits, true)) return(last_error);

   int size = ArraySize(symbols);
   double equity = AccountBalance();

   for (int i=0; i < size; i++) {
      equity += profits[i];
   }
   if (i > 0) debug("onTick(0.1)  equity="+ NumberToStr(equity, ".2") +"  "+ symbols[0] +"="+ NumberToStr(profits[0], ".2"));

   // monitor total drawdown and trigger total liquidation
   return(catch("onTick(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Parameter=", DoubleQuoteStr(Parameter), ";"));
}
