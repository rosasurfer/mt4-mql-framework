/**
 * Auto-Liquidation
 *
 * The EA's purpose is protection of the trading account and supporting adherence to a daily loss/drawdown limit (DDL). It
 * monitors floating PnL of open positions, and once a predefined drawdown limit has been reached it closes all positions and
 * pending orders. The EA monitors all symbols, not only the symbol of the chart where it is attached.
 *
 * The EA should run in a separate trading terminal connected 24/7 to the trade server. For best operation it's strongly
 * advised to setup a hosted environment (VM or similar).
 *
 *
 * Note: A common approach to enforce an account lockout is setting a new account password without memorizing it. If you use
 *       a hosted environment (recommended) don't forget to update the password of the hosted terminal before you continue
 *       trading, or the EA will not be able to protect you.
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


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
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
