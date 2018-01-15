/**
 * Dual Trix EA
 *
 *
 * @see  https://www.mql5.com/en/code/165
 */

// input parameters
extern int BalanceDivider    = 1000;      // was "double DML"
extern int DoublingCount     =    1;      // was "int    Ud"
extern int TakeProfit        = 1500;      // was "Tp"
extern int StopLoss          =  500;      // was "Stop"
extern int Slippage          =   50;
extern int Trix.Fast.Periods =    9;      // was "Fast = 9"
extern int Trix.Slow.Periods =   18;      // was "Slow = 9"


int    m.ud;
string terminalVarName = "MG_2";


/**
 *
 */
int OnInit() {
   if (!GlobalVariableCheck(terminalVarName))
      GlobalVariableSet(terminalVarName, 0);
   m.ud = GlobalVariableGet(terminalVarName);
   return(0);
}


/**
 *
 */
void OnDeinit() {
   GlobalVariableSet(terminalVarName, m.ud);
}


/**
 *
 */
void OnTick() {
   if (Volume[0] > 1)
      return;

   if (!OrdersTotal())              // TODO: simplified, works in Tester only
      OpenPosition();
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
         OrderSend(Symbol(), OP_BUY, lots, Ask, Slippage, sl, tp, NULL, NULL, NULL, Blue);
      }
   }

   else /*slowTrixTrend > 0*/ {                    // else if slowTrix trend is up
      if (fastTrixTrend == -1) {                   // and fastTrix trend turned down
         lots = CalculateLots();
         tp   = Bid - TakeProfit * Point;
         sl   = Ask +   StopLoss * Point;
         OrderSend(Symbol(), OP_SELL, lots, Bid, Slippage, sl, tp, NULL, NULL, NULL, Red);
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
      if (OrderOpenPrice() > lastOpenPrice && m.ud < DoublingCount) {
         lots = OrderLots() * 2;                         // previous closed ticket
         m.ud++;
      }
      else {
         m.ud = 0;
      }
   }

   else if (OrderType() == OP_SELL) {
      if (OrderOpenPrice() < lastOpenPrice && m.ud < DoublingCount) {
         lots = OrderLots() * 2;                         // previous closed ticket
         m.ud++;
      }
      else {
         m.ud = 0;
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
