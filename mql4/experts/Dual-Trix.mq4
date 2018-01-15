/**
 * Dual Trix EA
 *
 *
 * @see  https://www.mql5.com/en/code/165
 */

// input parameters
extern int BalanceDivider = 1000;      // was "double DML"
extern int DoublingCount  =    1;      // was "int    Ud"
extern int Stop           =  500;
extern int Tp             = 1500;
extern int Slippage       =   50;
extern int Fast           =    9;
extern int Slow           =    9;


int    m.ud;
int    m1;
int    m2;
string terminalVarName = "MG_2";


/**
 *
 */
int OnInit() {
   m1 = iTrix(Symbol(), 0, Fast, PRICE_MEDIAN);
   m2 = iTrix(Symbol(), 0, Slow, PRICE_MEDIAN);

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

   if (!PositionSelect(Symbol()))
      OpenPosition();
}


/**
 *
 */
double OnTester() {
   if (Tp < Stop)
      return(0);
   return(GetPlRatio() / (GetMaxSeriesLoss()+1));
}


/**
 *
 */
void OpenPosition() {
   double t[3];
   double k[2];

   if (CopyBuffer(m1, 0, 1, 3, t) < 0) return;
   if (CopyBuffer(m2, 0, 1, 2, k) < 0) return;

   double lots;
   double sl;
   double tp;
   int    magicNumber = 777;

   if (t[0] > t[1] && t[1] < t[2] && k[1] > k[0]) {
      lots = CalculateLots();
      sl   = Bid - Stop * Point;
      tp   = Ask +   Tp * Point;
      OrderSend(Symbol(), OP_BUY, lots, Ask, Slippage, sl, tp, "", magicNumber, NULL, Blue);
   }

   if (t[0] < t[1] && t[1] > t[2] && k[1] < k[0]) {
      lots = CalculateLots();
      sl   = Ask + Stop * Point;
      tp   = Bid -   Tp * Point;
      OrderSend(Symbol(), OP_SELL, lots, Bid, Slippage, sl, tp, "", magicNumber, NULL, Red);
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

   if (OrdersHistoryTotal() == 0) return(Lot);

   double lastOpenPrice = OrderOpenPrice(-1);         // last history ticket
   double prevOpenPrice = OrderOpenPrice(-2);         // previous history ticket
   int    prevType      = OrderType(-2);              // previous history ticket

   if (prevType == OP_BUY) {
      if (prevOpenPrice > lastOpenPrice && m.ud < DoublingCount) {
         lots = OrderLots(-2) * 2;                    // previous history ticket
         m.ud++;
      }
      else {
         m.ud = 0;
      }
   }

   if (prevType == OP_SELL) {
      if (prevOpenPrice < lastOpenPrice && m.ud < DoublingCount) {
         lots = OrderLots(-2) * 2;                    // previous history ticket
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
   int ser, max;
   double thisOpenPrice, nextOpenPrice;

   for (int i=0; i < HistoryOrdersTotal()-1; i+=2) {
      thisOpenPrice = OrderOpenPrice();
      nextOpenPrice = OrderOpenPrice(i+1);

      if (OrderType() == OP_BUY) {
         if (nextOpenPrice > thisOpenPrice) {
            if (ser > max) max = ser;
            ser = 0;
         }
         else ser++;
      }
      else {
         if (nextOpenPrice < thisOpenPrice) {
            if (ser > max) max = ser;
            ser = 0;
         }
         else ser++;
      }
   }
   return(max);
}


/**
 *
 */
double GetPlRatio() {
   double thisOpenPrice, nextOpenPrice;
   int pr, ls=1;

   for (int i=0; i < HistoryOrdersTotal()-1; i+=2) {
      thisOpenPrice = OrderOpenPrice();
      nextOpenPrice = OrderOpenPrice(i+1);

      if (OrderType() == OP_BUY) {
         if (nextOpenPrice > thisOpenPrice) pr++;
         else                               ls++;
      }
      else {
         if (nextOpenPrice < thisOpenPrice) pr++;
         else                               ls++;
      }
   }
   return(1.* pr/ls);
}
