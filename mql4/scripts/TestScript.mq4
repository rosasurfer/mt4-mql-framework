/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>

#include <win32api.mqh>
#include <stdlib.mqh>
#include <LFX/functions.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   /*LFX_ORDER*/int los[][LFX_ORDER.intSize];

   // alle Orders holen
   int orders = LFX.GetOrders(NULL, NULL, los);


   //Real-Price + lfxDeviation = LFX-ChartPrice


   for (int i=0; i < orders; i++) {
      string sOpenPrice  = "0";
      string sTakeProfit = "0";
      string sClosePrice = "0";

      double openPrice  = los.OpenPrice (los, i);
      double takeProfit = los.TakeProfit(los, i);
      double closePrice = los.ClosePrice(los, i);
      double deviation  = los.Deviation (los, i);

      if (openPrice  != 0) sOpenPrice  = DoubleToStr(openPrice  + deviation, los.Digits(los, i));
      if (takeProfit != 0) sTakeProfit = DoubleToStr(takeProfit + deviation, los.Digits(los, i));
      if (closePrice != 0) sClosePrice = DoubleToStr(closePrice + deviation, los.Digits(los, i));

      debug("onStart()   "+ los.Ticket(los, i) +", "+ los.Currency(los, i) +", "+ StringLeftPad(los.Comment(los, i), 8, " ") +", "+ StringLeftPad(sOpenPrice, 7, " ") +", "+ StringLeftPad(sTakeProfit, 7, " ") +", "+ StringLeftPad(sClosePrice, 7, " "));
   }



   return(last_error);
}
