/**
 * Matrix EA (Trix Convergence-Divergence)
 *
 * @see  https://www.mql5.com/en/code/165
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int Trix.Fast.Periods =    9;      // was "int    Fast = 9"
extern int Trix.Slow.Periods =   18;      // was "int    Slow = 9"
extern int TakeProfit.Pip    =  150;      // was "int    Tp   = 1500 point"
extern int StopLoss.Pip      =   50;      // was "int    Stop = 500 point"
extern int DoublingCount     =    1;      // was "int    Ud   = 1"
extern int BalanceDivider    = 1000;      // was "double DML  = 1000"

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <iCustom/icTrix.mqh>

int m.level;

// OrderSend() defaults
string os.name        = "Matrix";
int    os.magicNumber = 777;
int    os.slippage    = 1;


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (Volume[0] == 1) {
      if (!OrdersTotal())              // TODO: simplified, works in Tester only
         OpenPosition();
   }
   return(last_error);
}


/**
 *
 */
void OpenPosition() {
   double lots, tp, sl;

   int slowTrixTrend = icTrix(NULL, Trix.Slow.Periods, PRICE_MEDIAN, 100, Slope.MODE_TREND, 1);
   int fastTrixTrend = icTrix(NULL, Trix.Fast.Periods, PRICE_MEDIAN, 100, Slope.MODE_TREND, 1);

   if (slowTrixTrend > 0) {                        // if slowTrix[1] is rising
      if (fastTrixTrend == 1) {                    // and fastTrix[1] trend turned up
         lots = CalculateLots();
         tp   = Ask + TakeProfit.Pip * Pips;
         sl   = Bid -   StopLoss.Pip * Pips;
         OrderSend(Symbol(), OP_BUY, lots, Ask, os.slippage, sl, tp, os.name, os.magicNumber, NULL, Blue);
      }
   }

   else /*slowTrixTrend < 0*/ {                    // else if slowTrix[1] is falling
      if (fastTrixTrend == -1) {                   // and fastTrix[] trend turned down
         lots = CalculateLots();
         tp   = Bid - TakeProfit.Pip * Pips;
         sl   = Ask +   StopLoss.Pip * Pips;
         OrderSend(Symbol(), OP_SELL, lots, Bid, os.slippage, sl, tp, os.name, os.magicNumber, NULL, Red);
      }
   }
   return;


   // original logic
   /*
   int hFastTrix = iTrix(Symbol(), Period(), Fast, PRICE_MEDIAN);
   int hSlowTrix = iTrix(Symbol(), Period(), Slow, PRICE_MEDIAN);

   double fastTarget[3];     // bars = {0=>3, 1=>2, 2=>1}
   double slowTarget[2];     // bars = {      0=>2, 1=>1}

   int iBuffer  = 0;
   int startBar = 1;
   CopyBuffer(hFastTrix, iBuffer, startBar, bars=3, fastTarget);    // Data is copied so that the oldest copied element is located at
   CopyBuffer(hSlowTrix, iBuffer, startBar, bars=2, slowTarget);    // the start of the physical memory allocated for the target array.

   // if (slowTrix[1] is rising && fastTrixTrend[1] turned up)
   if (slowTrix[2] < slowTrix[1] && fastTrix[3] > fastTrix[2] && fastTrix[2] < fastTrix[1]) {
      OrderSend(ORDER_TYPE_BUY);
   }

   // if (slowTrix[1] is falling && fastTrixTrend[1] turned down)
   if (slowTrix[2] > slowTrix[1] && fastTrix[3] < fastTrix[2] && fastTrix[2] > fastTrix[1]) {
      OrderSend(ORDER_TYPE_SELL);
   }
   */
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
   int    prevType      = OrderType();
   double prevOpenPrice = OrderOpenPrice();
   double prevLots      = OrderLots();


   // this logic looks like complete non-sense
   if (prevType == OP_BUY) {
      if (prevOpenPrice > lastOpenPrice && m.level < DoublingCount) {
         lots = prevLots * 2;
         m.level++;
      }
      else {
         m.level = 0;
      }
   }

   else if (prevType == OP_SELL) {
      if (prevOpenPrice < lastOpenPrice && m.level < DoublingCount) {
         lots = prevLots * 2;
         m.level++;
      }
      else {
         m.level = 0;
      }
   }
   return(lots);
}


/**
 * Tester optimization criteria
 *
 * @return double - optimization score
 */
double OnTester() {
   if (TakeProfit.Pip < StopLoss.Pip)
      return(0);
   return(GetPlRatio() / (GetMaxConsecutiveLosses()+1));
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


/**
 *
 */
double GetMaxConsecutiveLosses() {
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
 * Return a string representation of the input parameters for logging.
 *
 * @return string
 */
string InputsToStr() {
   return(EMPTY_STR);

   // suppress compiler warnings
   OnTester();
}
