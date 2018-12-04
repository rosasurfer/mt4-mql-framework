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
#include <functions/EventListener.BarOpen.mqh>
#include <iCustom/icTrix.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (EventListener.BarOpen()) {
      double trix = icTrix(NULL, 20, PRICE_CLOSE, Slope.MODE_MAIN,  1);
      int   trend = icTrix(NULL, 20, PRICE_CLOSE, Slope.MODE_TREND, 1);

      //if (trend ==  1) debug("onTick(1)  Trix turned up,   last bar value: "+ trix +"  last bar trend: "+ _int(trend));
      //if (trend == -1) debug("onTick(2)  Trix turned down, last bar value: "+ trix +"  last bar trend: "+ _int(trend));
      //if (Abs(trend) == 1) Tester.Pause();
   }
   return(last_error);

   ClosedProfiStdDev();
}


/**
 *
 */
double ClosedProfiStdDev() {
   int trade, orders=OrdersHistoryTotal();
   double totalPL;

   for (int i=0; i < orders; i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderType() <= OP_SELL) {
         trade++;
         totalPL += OrderProfit() + OrderCommission() + OrderSwap();
      }
   }
   double avgPL=totalPL/trade, cumPL, plDiffs[]; ArrayResize(plDiffs, trade);

   for (i=0, trade=0; i < orders; i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderType() <= OP_SELL) {
         cumPL         += OrderProfit() + OrderCommission() + OrderSwap();
         plDiffs[trade] = cumPL - avgPL*(trade+1);
         trade++;
      }
   }
   return(MathStdev(plDiffs));
}


/**
 *
 */
double MathStdev(double values[]) {
   int size = ArraySize(values);
   double sum, mean = MathAvg(values);

   for (int i=0; i < size; i++) {
      sum += MathPow((values[i] - mean), 2);
   }
   double stdDev = MathSqrt(sum / (size - 1));
   return(stdDev);
}


/**
 *
 */
double MathAvg(double values[]) {
   int size = ArraySize(values);
   double sum;

   for (int i=0; i < size; i++) {
      sum += values[i];
   }
   return(sum / size);
}