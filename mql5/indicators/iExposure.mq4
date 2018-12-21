//+------------------------------------------------------------------+
//|                                                    iExposure.mq4 |
//|                   Copyright 2007-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright "2007-2014, MetaQuotes Software Corp."
#property link      "http://www.mql4.com"
#property strict

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_minimum 0.0
#property indicator_maximum 0.1

#define SYMBOLS_MAX 1024
#define DEALS          0
#define BUY_LOTS       1
#define BUY_PRICE      2
#define SELL_LOTS      3
#define SELL_PRICE     4
#define NET_LOTS       5
#define PROFIT         6

input color InpColor=LightSeaGreen;  // Text color

string ExtName="Exposure";
string ExtSymbols[SYMBOLS_MAX];
int    ExtSymbolsTotal=0;
double ExtSymbolsSummaries[SYMBOLS_MAX][7];
int    ExtLines=-1;
string ExtCols[8]={"Symbol",
                   "Deals",
                   "Buy lots",
                   "Buy price",
                   "Sell lots",
                   "Sell price",
                   "Net lots",
                   "Profit"};
int    ExtShifts[8]={ 10, 80, 130, 180, 260, 310, 390, 460 };
int    ExtVertShift=14;
double ExtMapBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
	IndicatorShortName(ExtName);
   SetIndexBuffer(0,ExtMapBuffer);
   SetIndexStyle(0,DRAW_NONE);
   IndicatorDigits(0);
	SetIndexEmptyValue(0,0.0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   int windex=WindowFind(ExtName);
   if(windex>0)
      ObjectsDeleteAll(windex);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
  {
   string name;
   int    i,col,line,windex=WindowFind(ExtName);
//----
   if(windex<0)
      return(rates_total);
//---- header line
   if(ExtLines<0)
     {
      for(col=0; col<8; col++)
        {
         name="Head_"+string(col);
         if(ObjectCreate(name,OBJ_LABEL,windex,0,0))
           {
            ObjectSet(name,OBJPROP_XDISTANCE,ExtShifts[col]);
            ObjectSet(name,OBJPROP_YDISTANCE,ExtVertShift);
            ObjectSetText(name,ExtCols[col],9,"Arial",InpColor);
           }
        }
      ExtLines=0;
     }
//----
   ArrayInitialize(ExtSymbolsSummaries,0.0);
   int total=Analyze();
   if(total>0)
     {
      line=0;
      for(i=0; i<ExtSymbolsTotal; i++)
        {
         if(ExtSymbolsSummaries[i][DEALS]<=0) continue;
         line++;
         //---- add line
         if(line>ExtLines)
           {
            int y_dist=ExtVertShift*(line+1)+1;
            for(col=0; col<8; col++)
              {
               name="Line_"+string(line)+"_"+string(col);
               if(ObjectCreate(name,OBJ_LABEL,windex,0,0))
                 {
                  ObjectSet(name,OBJPROP_XDISTANCE,ExtShifts[col]);
                  ObjectSet(name,OBJPROP_YDISTANCE,y_dist);
                 }
              }
            ExtLines++;
           }
         //---- set line
         int    digits=(int)MarketInfo(ExtSymbols[i],MODE_DIGITS);
         double buy_lots=ExtSymbolsSummaries[i][BUY_LOTS];
         double sell_lots=ExtSymbolsSummaries[i][SELL_LOTS];
         double buy_price=0.0;
         double sell_price=0.0;
         if(buy_lots!=0)  buy_price=ExtSymbolsSummaries[i][BUY_PRICE]/buy_lots;
         if(sell_lots!=0) sell_price=ExtSymbolsSummaries[i][SELL_PRICE]/sell_lots;
         name="Line_"+string(line)+"_0";
         ObjectSetText(name,ExtSymbols[i],9,"Arial",InpColor);
         name="Line_"+string(line)+"_1";
         ObjectSetText(name,DoubleToStr(ExtSymbolsSummaries[i][DEALS],0),9,"Arial",InpColor);
         name="Line_"+string(line)+"_2";
         ObjectSetText(name,DoubleToStr(buy_lots,2),9,"Arial",InpColor);
         name="Line_"+string(line)+"_3";
         ObjectSetText(name,DoubleToStr(buy_price,digits),9,"Arial",InpColor);
         name="Line_"+string(line)+"_4";
         ObjectSetText(name,DoubleToStr(sell_lots,2),9,"Arial",InpColor);
         name="Line_"+string(line)+"_5";
         ObjectSetText(name,DoubleToStr(sell_price,digits),9,"Arial",InpColor);
         name="Line_"+string(line)+"_6";
         ObjectSetText(name,DoubleToStr(buy_lots-sell_lots,2),9,"Arial",InpColor);
         name="Line_"+string(line)+"_7";
         ObjectSetText(name,DoubleToStr(ExtSymbolsSummaries[i][PROFIT],2),9,"Arial",InpColor);
        }
     }
//---- remove lines
   if(total<ExtLines)
     {
      for(line=ExtLines; line>total; line--)
        {
         name="Line_"+string(line)+"_0";
         ObjectSetText(name,"");
         name="Line_"+string(line)+"_1";
         ObjectSetText(name,"");
         name="Line_"+string(line)+"_2";
         ObjectSetText(name,"");
         name="Line_"+string(line)+"_3";
         ObjectSetText(name,"");
         name="Line_"+string(line)+"_4";
         ObjectSetText(name,"");
         name="Line_"+string(line)+"_5";
         ObjectSetText(name,"");
         name="Line_"+string(line)+"_6";
         ObjectSetText(name,"");
         name="Line_"+string(line)+"_7";
         ObjectSetText(name,"");
        }
     }
//---- to avoid minimum==maximum
   ExtMapBuffer[Bars-1]=-1;
//----
   return(rates_total);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Analyze()
  {
   double profit;
   int    i,index,type,total=OrdersTotal();
//----
   for(i=0; i<total; i++)
     {
      if(!OrderSelect(i,SELECT_BY_POS)) continue;
      type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL) continue;
      index=SymbolsIndex(OrderSymbol());
      if(index<0 || index>=SYMBOLS_MAX) continue;
      //----
      ExtSymbolsSummaries[index][DEALS]++;
      profit=OrderProfit()+OrderCommission()+OrderSwap();
      ExtSymbolsSummaries[index][PROFIT]+=profit;
      if(type==OP_BUY)
        {
         ExtSymbolsSummaries[index][BUY_LOTS]+=OrderLots();
         ExtSymbolsSummaries[index][BUY_PRICE]+=OrderOpenPrice()*OrderLots();
        }
      else
        {
         ExtSymbolsSummaries[index][SELL_LOTS]+=OrderLots();
         ExtSymbolsSummaries[index][SELL_PRICE]+=OrderOpenPrice()*OrderLots();
        }
     }
//----
   total=0;
   for(i=0; i<ExtSymbolsTotal; i++)
     {
      if(ExtSymbolsSummaries[i][DEALS]>0) total++;
     }
//----
   return(total);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int SymbolsIndex(string SymbolName)
  {
   bool found=false;
   int  i;
//----
   for(i=0; i<ExtSymbolsTotal; i++)
     {
      if(SymbolName==ExtSymbols[i])
        {
         found=true;
         break;
        }
     }
//----
   if(found)
      return(i);
   if(ExtSymbolsTotal>=SYMBOLS_MAX)
      return(-1);
//----
   i=ExtSymbolsTotal;
   ExtSymbolsTotal++;
   ExtSymbols[i]=SymbolName;
   ExtSymbolsSummaries[i][DEALS]=0;
   ExtSymbolsSummaries[i][BUY_LOTS]=0;
   ExtSymbolsSummaries[i][BUY_PRICE]=0;
   ExtSymbolsSummaries[i][SELL_LOTS]=0;
   ExtSymbolsSummaries[i][SELL_PRICE]=0;
   ExtSymbolsSummaries[i][NET_LOTS]=0;
   ExtSymbolsSummaries[i][PROFIT]=0;
//----
   return(i);
  }
//+------------------------------------------------------------------+