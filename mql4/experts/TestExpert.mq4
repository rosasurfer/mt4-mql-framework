/**
 * TestExpert
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern string sParameter = "dummy";
extern int    iParameter = 12345;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {

   if (Tick == 10) {
      DebugMarketInfo("onTick(1:"+ Tick +")");
      debug("onTick(2:"+ Tick +")  Balance="+ DoubleToStr(AccountBalance(), 2) +"  Profit="+ DoubleToStr(AccountProfit(), 2) +"  Equity="+ DoubleToStr(AccountEquity(), 2) +"  Margin="+ DoubleToStr(AccountMargin(), 2) +"  FreeMargin="+ DoubleToStr(AccountFreeMargin(), 2));
   }

   if (Tick >= 1000) {
      static int ticket;

      if (Tick == 1000) {
         string symbol     = Symbol();
         int    type       = OP_SELL;
         double lots       = 1;
         double openPrice  = Bid;
         int    slippage   = 10;
         double stoploss   = NULL;
         double takeprofit = openPrice - 100*Pips;

         ticket = OrderSend(symbol, type, lots, openPrice, slippage, stoploss, takeprofit); if (ticket <= 0) return(catch("onTick(3)"));
         OrderLog(ticket);
         debug("onTick(4:"+ Tick +")  Balance="+ DoubleToStr(AccountBalance(), 2) +"  Profit="+ DoubleToStr(AccountProfit(), 2) +"  Equity="+ DoubleToStr(AccountEquity(), 2) +"  Margin="+ DoubleToStr(AccountMargin(), 2) +"  FreeMargin="+ DoubleToStr(AccountFreeMargin(), 2));
      }

      static bool closed = false;
      if (!closed) {
         if (!OrdersTotal()) {
            OrderLog(ticket);
            debug("onTick(5:"+ Tick +")  Balance="+ DoubleToStr(AccountBalance(), 2) +"  Profit="+ DoubleToStr(AccountProfit(), 2) +"  Equity="+ DoubleToStr(AccountEquity(), 2) +"  Margin="+ DoubleToStr(AccountMargin(), 2) +"  FreeMargin="+ DoubleToStr(AccountFreeMargin(), 2));
            closed = true;
         }
      }
   }
   return(last_error);
}


/**
 * @return int - Fehlerstatus
 */
int onDeinit() {
   return(NO_ERROR);
}