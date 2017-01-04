/**
 * TestExpert
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

/////////////////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////////////////

extern string sParameter = "dummy";
extern int    iParameter = 12345;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <structs/myfx/ExecutionContext.mqh>


#import "Expander.dll"

   bool CollectTestData(int ec[], datetime from, datetime to, double bid, double ask, int bars, double accountBalance, string accountCurrency, string reportSymbol);

#import


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   static bool test.init = false;
   if (!test.init) {
      datetime startTime       = MarketInfo(Symbol(), MODE_TIME);
      double   accountBalance  = AccountBalance();
      string   accountCurrency = AccountCurrency();
      CollectTestData(__ExecutionContext, startTime, NULL, Bid, Ask, Bars, accountBalance, accountCurrency, NULL);
      test.init = true;
   }
   //debug("onTick(1)  bars="+ Bars +"  ticks="+ Tick +"  ec.ticks="+ ec_Ticks(__ExecutionContext));
   return(last_error);
}


/**
 * @return int - error status
 */
int onDeinit() {
   datetime endTime      = MarketInfo(Symbol(), MODE_TIME);
   string   reportSymbol = equityChart.symbol;
   CollectTestData(__ExecutionContext, NULL, endTime, NULL, NULL, Bars, NULL, NULL, reportSymbol);
   return(NO_ERROR);
}