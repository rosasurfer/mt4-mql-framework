/**
 * Dual Trix EA
 *
 *
 * @see  https://www.mql5.com/en/code/165
 */

// input parameters
extern double DML      = 1000;
extern int    Ud       =    1;
extern int    Stop     =  500;
extern int    Tp       = 1500;
extern int    Slippage =   50;
extern int    Fast     =    9;
extern int    Slow     =    9;


// Martingale management
int    marti.ud;
double marti.shape;
int    marti.doublingCount;
string marti.gVarName = "MG_2";

int    m1;
int    m2;


/**
 *
 */
int OnInit() {
   m1 = iTriX(Symbol(), 0, Fast, PRICE_MEDIAN);
   m2 = iTriX(Symbol(), 0, Slow, PRICE_MEDIAN);
   marti.shape         = DML;
   marti.doublingCount = Ud;
   marti.GVarGet();
   return(0);
}


/**
 *
 */
void OnDeinit() {
   marti.GVarSet();
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
   double p = GetPlRatio();
   double s = GetMaxSeriesLoss();
   if (Tp < Stop)
      return(0);
   s += 1;
   return(p/s);
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
      lots = marti.Lot();
      sl   = Bid - Stop * Point;
      tp   = Ask +   Tp * Point;
      OrderSend(Symbol(), OP_BUY, lots, Ask, Slippage, sl, tp, "", magicNumber, NULL, Blue);
   }

   if (t[0] < t[1] && t[1] > t[2] && k[1] < k[0]) {
      lots = marti.Lot();
      sl   = Ask + Stop * Point;
      tp   = Bid -   Tp * Point;
      OrderSend(Symbol(), OP_SELL, lots, Bid, Slippage, sl, tp, "", magicNumber, NULL, Red);
   }
}


/**
 *
 */
double GetMaxSeriesLoss() {
   HistorySelect(0, TimeCurrent());
   int ser, max;
   double thisOpenPrice, nextOpenPrice;

   for (int i=0; i < HistoryOrdersTotal()-1; i+=2) {
      thisOpenPrice = OrderOpenPrice();
      nextOpenPrice = OrderOpenPrice(i+1);

      if (OrderType() == OP_BUY) {
         if (nextOpenPrice-thisOpenPrice > 0) {
            if (ser > max) max = ser;
            ser = 0;
         }
         else ser++;
      }
      else {
         if (nextOpenPrice-thisOpenPrice < 0) {
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
   HistorySelect(0, TimeCurrent());

   double thisOpenPrice, nextOpenPrice;
   int pr, ls=1;

   for (int i=0; i < HistoryOrdersTotal()-1; i+=2) {
      thisOpenPrice = OrderOpenPrice();
      nextOpenPrice = OrderOpenPrice(i+1);

      if (OrderType() == OP_BUY) {
         if (nextOpenPrice-thisOpenPrice > 0) pr++;
         else                                 ls++;
      }
      else {
         if (nextOpenPrice-thisOpenPrice < 0) pr++;
         else                                 ls++;
      }
   }
   return(1.* pr/ls);
}


/**
 *
 */
void GVarGet() {
   if (GlobalVariableCheck(marti.gVarName))
      GlobalVariableSet(marti.gVarName, 0);
   marti.ud = GlobalVariableGet(marti.gVarName);
}


/**
 *
 */
void GVarSet() {
   GlobalVariableSet(marti.gVarName, marti.ud);
}


/**
 *
 */
double CalculateLots() {
   double Lot=MathFloor(AccountInfoDouble(ACCOUNT_BALANCE)/Shape)*SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   if(Lot==0)Lot=SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   if(DoublingCount<=0) return Lot;
   double MaxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);

   if(Lot>MaxLot)Lot=MaxLot;
   double lt1=Lot;
   HistorySelect(0,TimeCurrent());
   if(HistoryOrdersTotal()==0)return(Lot);
   double cl=HistoryOrderGetDouble(HistoryOrderGetTicket(HistoryOrdersTotal()-1),ORDER_PRICE_OPEN);
   double op=HistoryOrderGetDouble(HistoryOrderGetTicket(HistoryOrdersTotal()-2),ORDER_PRICE_OPEN);

   long typeor=HistoryOrderGetInteger(HistoryOrderGetTicket(HistoryOrdersTotal()-2),ORDER_TYPE);
   if(typeor==ORDER_TYPE_BUY)
     {
      if(op>cl)
        {
         if(ud<DoublingCount)
           {
            lt1=HistoryOrderGetDouble(HistoryOrderGetTicket(HistoryOrdersTotal()-2),ORDER_VOLUME_INITIAL)*2;
            ud++;
           }
         else ud=0;
        }
      else ud=0;
     }
   if(typeor==ORDER_TYPE_SELL)
     {
      if(cl>op)
        {
         if(ud<DoublingCount)
           {
            lt1=HistoryOrderGetDouble(HistoryOrderGetTicket(HistoryOrdersTotal()-2),ORDER_VOLUME_INITIAL)*2;
            ud++;
           }
         else ud=0;
        }
      else ud=0;
     }
   if(lt1>MaxLot)lt1=MaxLot;
   return(lt1);
}
