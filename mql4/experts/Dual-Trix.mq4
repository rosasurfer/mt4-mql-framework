/**
 * Dual Trix EA
 *
 *
 * @see  https://www.mql5.com/en/code/165
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int BalanceDivider    = 1000;      // was "double DML"
extern int DoublingCount     =    1;      // was "int    Ud"
extern int TakeProfit        = 1500;      // was "Tp"
extern int StopLoss          =  500;      // was "Stop"
extern int Trix.Fast.Periods =    9;      // was "Fast = 9"
extern int Trix.Slow.Periods =   18;      // was "Slow = 9"

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>


int m.level;

// OrderSend() defaults
string os.name        = "Dual-Trix";
int    os.magicNumber = 777;
int    os.slippage    = 1;


/**
 *
 */
int onTick() {
   if (Volume[0] == 1) {
      if (!OrdersTotal())              // TODO: simplified, works in Tester only
         OpenPosition();
   }
   return(last_error);

   // dummy call suppress compiler warnings
   OnTester();
}


/**
 *
 */
double OnTester() {
   if (TakeProfit < StopLoss)
      return(0);
   return(GetPlRatio() / (GetMaxSeriesLoss()+1));
}


#define TRIX.MODE_MAIN     0
#define TRIX.MODE_TREND    1


/**
 *
 */
double iTrix(string symbol, int timeframe, int periods, int buffer, int bar) {
   return(1);
}


/**
 *
 */
void OpenPosition() {
   double tp, sl, lots;

   int fastTrixTrend = iTrix(Symbol(), NULL, Trix.Fast.Periods, TRIX.MODE_TREND, 1);
   int slowTrixTrend = iTrix(Symbol(), NULL, Trix.Slow.Periods, TRIX.MODE_TREND, 1);

   if (slowTrixTrend < 0) {                        // if slowTrix trend is down
      if (fastTrixTrend == 1) {                    // and fastTrix trend turned up
         lots = CalculateLots();
         tp   = Ask + TakeProfit * Point;
         sl   = Bid -   StopLoss * Point;
         OrderSend(Symbol(), OP_BUY, lots, Ask, os.slippage, sl, tp, os.name, os.magicNumber, NULL, Blue);
      }
   }

   else /*slowTrixTrend > 0*/ {                    // else if slowTrix trend is up
      if (fastTrixTrend == -1) {                   // and fastTrix trend turned down
         lots = CalculateLots();
         tp   = Bid - TakeProfit * Point;
         sl   = Ask +   StopLoss * Point;
         OrderSend(Symbol(), OP_SELL, lots, Bid, os.slippage, sl, tp, os.name, os.magicNumber, NULL, Red);
      }
   }
}


/**
 *
 */
double CalculateLots() {
   double lots = MathFloor(AccountBalance()/BalanceDivider) * MarketInfo(Symbol(), MODE_MINLOT);
   if (!lots) lots = MarketInfo(Symbol(), MODE_MINLOT);
   if (!DoublingCount)
      return(lots);

   int history = OrdersHistoryTotal();                   // TODO: over-simplified, works only in Tester
   if (history < 2) return(lots);

   OrderSelect(history-1, SELECT_BY_POS, MODE_HISTORY);  // last closed ticket
   double lastOpenPrice = OrderOpenPrice();
   OrderSelect(history-2, SELECT_BY_POS, MODE_HISTORY);  // previous closed ticket


   // this logic looks like complete non-sense
   if (OrderType() == OP_BUY) {
      if (OrderOpenPrice() > lastOpenPrice && m.level < DoublingCount) {
         lots = OrderLots() * 2;                         // previous closed ticket
         m.level++;
      }
      else {
         m.level = 0;
      }
   }

   else if (OrderType() == OP_SELL) {
      if (OrderOpenPrice() < lastOpenPrice && m.level < DoublingCount) {
         lots = OrderLots() * 2;                         // previous closed ticket
         m.level++;
      }
      else {
         m.level = 0;
      }
   }
   return(lots);
}


/**
 *
 */
double GetMaxSeriesLoss() {
   double thisOpenPrice, nextOpenPrice;
   int    thisType, counter, max, history = OrdersHistoryTotal();

   // again the logic is utter non-sense
   for (int i=0; i < history-1; i+=2) {
      OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
      thisType      = OrderType();
      thisOpenPrice = OrderOpenPrice();

      OrderSelect(i+1, SELECT_BY_POS, MODE_HISTORY);
      nextOpenPrice = OrderOpenPrice();

      if (thisType == OP_BUY) {
         if (nextOpenPrice > thisOpenPrice) {
            if (counter > max) max = counter;
            counter = 0;
         }
         else counter++;
      }
      else if (thisType == OP_SELL) {
         if (nextOpenPrice < thisOpenPrice) {
            if (counter > max) max = counter;
            counter = 0;
         }
         else counter++;
      }
   }
   return(max);
}


/**
 *
 */
double GetPlRatio() {
   double thisOpenPrice, nextOpenPrice;
   int    thisType, profits, losses=1, history=OrdersHistoryTotal();

   for (int i=0; i < history-1; i+=2) {
      OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
      thisType      = OrderType();
      thisOpenPrice = OrderOpenPrice();

      OrderSelect(i+1, SELECT_BY_POS, MODE_HISTORY);
      nextOpenPrice = OrderOpenPrice();

      if (thisType == OP_BUY) {
         if (nextOpenPrice > thisOpenPrice) profits++;
         else                               losses++;
      }
      else if (thisType == OP_SELL) {
         if (nextOpenPrice < thisOpenPrice) profits++;
         else                               losses++;
      }
   }
   return(1.* profits/losses);
}
