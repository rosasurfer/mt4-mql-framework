/**
 * TestExpert
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string sParameter = "dummy";
extern int    iParameter = 12345;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/BarOpenEvent.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/rsf/OrderExecution.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {

   int oe[];
   int longTicket = OrderSendEx("EURUSD", OP_BUY, 1.4, NULL, NULL, NULL, NULL, NULL, NULL, NULL, Blue, NULL, oe);
   if (!longTicket) return(SetLastError(oe.Error(oe)));
   int shortTicket = OrderSendEx("EURUSD", OP_SELL, 0.2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, Red, NULL, oe);
   if (!shortTicket) return(SetLastError(oe.Error(oe)));
   OrderCloseByEx(longTicket, shortTicket, CLR_NONE, NULL, oe);
   ORDER_EXECUTION.toStr(oe, true);

   longTicket = OrderSendEx("EURUSD", OP_BUY, 0.2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, Blue, NULL, oe);
   if (!longTicket) return(SetLastError(oe.Error(oe)));
   shortTicket = OrderSendEx("EURUSD", OP_SELL, 1.4, NULL, NULL, NULL, NULL, NULL, NULL, NULL, Red, NULL, oe);
   if (!shortTicket) return(SetLastError(oe.Error(oe)));
   OrderCloseByEx(longTicket, shortTicket, CLR_NONE, NULL, oe);
   ORDER_EXECUTION.toStr(oe, true);

   longTicket = OrderSendEx("EURUSD", OP_BUY, 1.4, NULL, NULL, NULL, NULL, NULL, NULL, NULL, Blue, NULL, oe);
   if (!longTicket) return(SetLastError(oe.Error(oe)));
   shortTicket = OrderSendEx("EURUSD", OP_SELL, 1.4, NULL, NULL, NULL, NULL, NULL, NULL, NULL, Red, NULL, oe);
   if (!shortTicket) return(SetLastError(oe.Error(oe)));
   OrderCloseByEx(longTicket, shortTicket, CLR_NONE, NULL, oe);
   ORDER_EXECUTION.toStr(oe, true);


   if (IsTesting()) Tester.Stop("onTick(1)");
   return(last_error);


   if (IsBarOpenEvent()) {
      double trix = icTrix(NULL, 20, PRICE_CLOSE, Slope.MODE_MAIN,  1);
      int   trend = icTrix(NULL, 20, PRICE_CLOSE, Slope.MODE_TREND, 1);
      //if (trend ==  1) debug("onTick(1)  Trix turned up,   last bar value: "+ trix +"  last bar trend: "+ _int(trend));
      //if (trend == -1) debug("onTick(2)  Trix turned down, last bar value: "+ trix +"  last bar trend: "+ _int(trend));
      //if (Abs(trend) == 1) Tester.Pause("onTick(2)");
   }
   return(last_error);
}
