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

   static bool done = false;
   if (!done) {
      if (AccountProfit() || Tick == 10) {
         DebugMarketInfo("onTick("+ Tick +")");

         debug("onTick("+ Tick +")  AccountBalance        = "+ AccountBalance       ());
         debug("onTick("+ Tick +")  AccountCurrency       = "+ AccountCurrency      ());
         debug("onTick("+ Tick +")  AccountEquity         = "+ AccountEquity        ());
         debug("onTick("+ Tick +")  AccountFreeMargin     = "+ AccountFreeMargin    ());
         debug("onTick("+ Tick +")  AccountFreeMarginMode = "+ AccountFreeMarginMode());
         debug("onTick("+ Tick +")  AccountLeverage       = "+ AccountLeverage      ());
         debug("onTick("+ Tick +")  AccountMargin         = "+ AccountMargin        ());
         debug("onTick("+ Tick +")  AccountProfit         = "+ AccountProfit        ());
         debug("onTick("+ Tick +")  AccountStopoutLevel   = "+ AccountStopoutLevel  ());
         debug("onTick("+ Tick +")  AccountStopoutMode    = "+ AccountStopoutMode   ());

         if (AccountProfit() != 0) {
            done = true;
         }
      }
   }

   if (Tick == 1000) {
      int res = OrderSend(Symbol(), OP_SELL,     1,   Bid,        5,        0,         0);
   }


   return(last_error);


   static int lastTickCount;
   int tickCount = GetTickCount();
   debug("onTick()  Tick="+ Tick +"  vol="+ _int(Volume[0]) +"  ChangedBars="+ ChangedBars +"  after "+ (tickCount-lastTickCount) +" msec");

   lastTickCount = tickCount;
   return(last_error);
}


/**
 * @return int - Fehlerstatus
 */
int onDeinit() {
   return(NO_ERROR);
}
