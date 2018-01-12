/**
 * Dual Trix EA
 *
 *
 * @see  https://www.mql5.com/en/code/165
 */

// input parameters
input double   DML=1000;
input int      Ud=1;
input int      Stop=500;
input int      Tp=1500;
input int      Slipage=50;
input int      Fast=9;
input int      Slow=9;

int m1=0;
int m2=0;

Martingail lt;
//+------------------------------------------------------------------+
//| Open                                                             |
//+------------------------------------------------------------------+
void Open()
  {
   double t[3];
   double k[2];

   if(CopyBuffer(m1,0,1,3,t)<0) return;
   if(CopyBuffer(m2,0,1,2,k)<0) return;

   MqlTick last_tick;
   SymbolInfoTick(_Symbol,last_tick);
   MqlTradeResult result;
   MqlTradeRequest request;

   ZeroMemory(result);
   ZeroMemory(request);

   request.symbol=_Symbol;
   request.magic=777;
   request.deviation=Slipage;
   request.action=TRADE_ACTION_DEAL;
   request.type_filling=ORDER_FILLING_FOK;
   if(t[0]>t[1] && t[1]<t[2] && k[1]>k[0])
     {
      request.volume=lt.Lot();
      request.price=last_tick.ask;
      request.type=ORDER_TYPE_BUY;
      request.sl=last_tick.bid-Stop*Point();
      request.tp=last_tick.ask+Tp*Point();
      OrderSend(request,result);

     }
   if(t[0]<t[1] && t[1]>t[2] && k[1]<k[0])
     {
      request.volume=lt.Lot();
      request.price=last_tick.bid;
      request.type=ORDER_TYPE_SELL;
      request.sl=last_tick.ask+Stop*Point();
      request.tp=last_tick.bid-Tp*Point();
      OrderSend(request,result);

     }
  }
//+------------------------------------------------------------------+
//|  Expert initialization function                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   m1=iTriX(_Symbol,0,Fast,PRICE_MEDIAN);
   m2=iTriX(_Symbol,0,Slow,PRICE_MEDIAN);
   lt.GVarName="MG_2";
   lt.Shape=DML;
   lt.DoublingCount=Ud;
   lt.GVarGet();
//---
   return(0);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   lt.GVarSet();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   MqlRates rt[1];
   if(CopyRates(Symbol(),_Period,0,1,rt)<0) return;
   if(rt[0].tick_volume>1) return;
   if(!PositionSelect(_Symbol))Open();
  }
//+------------------------------------------------------------------+
//| Expert OnTester function                                         |
//+------------------------------------------------------------------+
double OnTester()
  {
   double p=profitc_divide_lossc();
   double s=max_series_loss();
   if(Tp<Stop) return 0;
   s=s+1;
   return p/s;
  }



//+------------------------------------------------------------------+
//| max_series_loss                                                  |
//+------------------------------------------------------------------+
double max_series_loss()
  {
   HistorySelect(0,TimeCurrent());
   int ser=0;
   double max=0;
   double o,c;
   long t;
   for(int i=0;i<HistoryOrdersTotal()-1;i=i+2)
     {
      o=HistoryOrderGetDouble(HistoryOrderGetTicket(i),ORDER_PRICE_OPEN);
      c=HistoryOrderGetDouble(HistoryOrderGetTicket(i+1),ORDER_PRICE_OPEN);
      t=HistoryOrderGetInteger(HistoryOrderGetTicket(i),ORDER_TYPE);

      if(t==ORDER_TYPE_BUY)
        {
         if(c-o>0)
           {
            if(ser>max)max=ser;
            ser=0;
           }
         else ser++;
        }
      else
        {
         if(c-o<0)
           {
            if(ser>max)max=ser;
            ser=0;
           }
         else ser++;
        }
     }
   return max;
  }

//+------------------------------------------------------------------+
//| profitc_divide_lossc                                             |
//+------------------------------------------------------------------+
double profitc_divide_lossc()
  {
   HistorySelect(0,TimeCurrent());
   double pr=0,ls=1;

   double o,c,p=0;
   long t;
   for(int i=0;i<HistoryOrdersTotal()-1;i=i+2)
     {
      o=HistoryOrderGetDouble(HistoryOrderGetTicket(i),ORDER_PRICE_OPEN);
      c=HistoryOrderGetDouble(HistoryOrderGetTicket(i+1),ORDER_PRICE_OPEN);
      t=HistoryOrderGetInteger(HistoryOrderGetTicket(i),ORDER_TYPE);

      if(t==ORDER_TYPE_BUY)
        {
         if(c-o>0)
           {
            pr=pr+1;
           }
         else ls=ls+1;
        }
      else
        {
         if(c-o<0)
           {
            pr=pr+1;
           }
         else ls=ls+1;
        }
     }
   p=pr/ls;

   return p;
}


/**
 * Martingale class
 */
class Martingale {

   private:
      int ud;

   public:
      double Shape;
      int    DoublingCount;
      string GVarName;
      void   GVarGet();
      void   GVarSet();
      double Lot();
};


/**
 * GVarGet
 */
void Martingail::GVarGet(void) {
   if(GlobalVariableCheck(GVarName)) GlobalVariableSet(GVarName,0);
   ud=(int)GlobalVariableGet(GVarName);
}


/**
 * GVarSet
 */
void Martingail::GVarSet(void) {
   GlobalVariableSet(GVarName,ud);
}


/**
 * Lot
 */
double Martingail::Lot(void) {
   double Lot=MathFloor(AccountInfoDouble(ACCOUNT_BALANCE)/Shape)*SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(Lot==0)Lot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(DoublingCount<=0) return Lot;
   double MaxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);

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
