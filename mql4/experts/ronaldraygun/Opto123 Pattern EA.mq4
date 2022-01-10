/**
 * Opto123 Pattern EA
 *
 * A simplified, streamlined and fixed version of the original 123 Pattern EA v1.0 published by Ronald Raygun. The trading
 * logic is unchanged.
 *
 * @source  https://www.forexfactory.com/thread/post/4090801#post4090801                            [Opto123 Pattern EA v1.0]
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___a__________________________ = "=== Main Settings ===";
extern int    MagicNumber                    = 0;
extern int    PipBuffer                      = 0;
extern double Lots                           = 0;
extern bool   MoneyManagement                = false;
extern int    Risk                           = 0;
extern int    Slippage                       = 5;
extern bool   UseStopLoss                    = true;
extern int    StopLoss                       = 100;
extern bool   UseTakeProfit                  = false;
extern int    TakeProfit                     = 60;
extern bool   UseTrailingStop                = false;
extern int    TrailingStop                   = 30;
extern bool   MoveStopOnce                   = false;
extern int    MoveStopWhenPrice              = 50;

extern string ___b__________________________ = "=== ZigZag Settings ===";
extern int    ZigZag.Depth                   = 2;
extern int    ZigZag.Deviation               = 1;
extern int    ZigZag.Backstep                = 1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>

#define SIGNAL_BUY      1
#define SIGNAL_SELL     2

#define MODE_SEMAPHORE  0

string signalToStr[]    = {"-", "Buy", "Sell"};
string zigzagIndicator  = "ZigZag.orig";
int    BrokerMultiplier = 1;


/**
 * Initialization preprocessing.
 *
 * @return int - error status
 */
int onInit() {
   if (Digits==3 || Digits==5) BrokerMultiplier = 10;

   if (MoneyManagement && (Risk < 1 || Risk > 100))
      return(catch("onInit(1)", ERR_INVALID_INPUT_PARAMETER));
   return(catch("onInit(2)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // manage open positions
   double StopLossLevel, TakeProfitLevel, PotentialStopLoss, BEven, TrailStop;
   bool isOpenPosition = false;
   int orders = OrdersTotal();

   for (int i=0; i < orders; i ++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderType() > OP_SELL || OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      isOpenPosition = true;

      // long
      if (OrderType() == OP_BUY) {
         PotentialStopLoss = OrderStopLoss();
         BEven             = CalcBreakEven(OrderTicket());
         TrailStop         = CalcTrailingStop(OrderTicket());

         if (BEven     > PotentialStopLoss && BEven)     PotentialStopLoss = BEven;
         if (TrailStop > PotentialStopLoss && TrailStop) PotentialStopLoss = TrailStop;

         if (PotentialStopLoss != OrderStopLoss()) OrderModify(OrderTicket(), OrderOpenPrice(), PotentialStopLoss, OrderTakeProfit(), 0, MediumSeaGreen);
      }

      // short
      else {
         PotentialStopLoss = OrderStopLoss();
         BEven             = CalcBreakEven(OrderTicket());
         TrailStop         = CalcTrailingStop(OrderTicket());

         if ((BEven     < PotentialStopLoss && BEven)     || !PotentialStopLoss) PotentialStopLoss = BEven;
         if ((TrailStop < PotentialStopLoss && TrailStop) || !PotentialStopLoss) PotentialStopLoss = TrailStop;

         if (PotentialStopLoss != OrderStopLoss() || !OrderStopLoss()) OrderModify(OrderTicket(), OrderOpenPrice(), PotentialStopLoss, OrderTakeProfit(), 0, DarkOrange);
      }
   }

   // check entry signals and open new positions
   if (!isOpenPosition) {
      // get ZigZag values
      double zz1, zz2, zz3, longEntryLevel, shortEntryLevel;
      int bar=1, type, signal;

      while (true) {
         zz1 = iCustom(NULL, NULL, zigzagIndicator, ZigZag.Depth, ZigZag.Deviation, ZigZag.Backstep, MODE_SEMAPHORE, bar);
         if (zz1 == High[bar]) { type = MODE_HIGH; break; }
         if (zz1 ==  Low[bar]) { type = MODE_LOW;  break; }
         bar++;
      }
      bar++;
      while (true) {
         zz2 = iCustom(NULL, NULL, zigzagIndicator, ZigZag.Depth, ZigZag.Deviation, ZigZag.Backstep, MODE_SEMAPHORE, bar);
         if (zz2 == High[bar] && type==MODE_LOW ) break;
         if (zz2 ==  Low[bar] && type==MODE_HIGH) break;
         bar++;
      }
      bar++;
      while (true) {
         zz3 = iCustom(NULL, NULL, zigzagIndicator, ZigZag.Depth, ZigZag.Deviation, ZigZag.Backstep, MODE_SEMAPHORE, bar);
         if (zz3 == High[bar] && type==MODE_HIGH) break;
         if (zz3 ==  Low[bar] && type==MODE_LOW ) break;
         bar++;
      }

      if (zz3 < zz2 && zz2 > zz1 && zz1 > zz3) longEntryLevel  = zz2 + PipBuffer*Point;
      if (zz3 > zz2 && zz2 < zz1 && zz1 < zz3) shortEntryLevel = zz2 - PipBuffer*Point;

      if (Open[0] < longEntryLevel  && Close[0] >= longEntryLevel ) signal = SIGNAL_BUY;
      if (Open[0] > shortEntryLevel && Close[0] <= shortEntryLevel) signal = SIGNAL_SELL;

      Comment("Long Entry: ",  longEntryLevel,  NL,
              "Short Entry: ", shortEntryLevel, NL,
              "Signal: ",      signalToStr[signal]);

      // open new positions
      if (signal != NULL) {
         if (MoneyManagement) Lots = MathFloor((AccountFreeMargin()*AccountLeverage()*Risk*Point*BrokerMultiplier*100) / (Ask*MarketInfo(Symbol(), MODE_LOTSIZE)*MarketInfo(Symbol(), MODE_MINLOT))) * MarketInfo(Symbol(), MODE_MINLOT);

         if (signal == SIGNAL_BUY) {
            if (UseStopLoss)   StopLossLevel   = Ask -   StopLoss*Point; else StopLossLevel   = 0;
            if (UseTakeProfit) TakeProfitLevel = Ask + TakeProfit*Point; else TakeProfitLevel = 0;
            OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, StopLossLevel, TakeProfitLevel, "Opto123 Buy", MagicNumber, 0, DodgerBlue);
         }
         if (signal == SIGNAL_SELL) {
            if (UseStopLoss)   StopLossLevel   = Bid +   StopLoss*Point; else StopLossLevel   = 0;
            if (UseTakeProfit) TakeProfitLevel = Bid - TakeProfit*Point; else TakeProfitLevel = 0;
            OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, StopLossLevel, TakeProfitLevel, "Opto123 Sell", MagicNumber, 0, DeepPink);
         }
      }
   }
   return(catch("onTick(1)"));
}


/**
 * @return double
 */
double CalcBreakEven(int ticket) {
   if (MoveStopOnce && MoveStopWhenPrice) {
      OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);

      if (OrderType() == OP_BUY) {
         if (Bid-OrderOpenPrice() >= MoveStopWhenPrice*Point) {
            return(OrderOpenPrice());
         }
      }
      else if (OrderType() == OP_SELL) {
         if (OrderOpenPrice()-Ask >= MoveStopWhenPrice*Point) {
            return(OrderOpenPrice());
         }
      }
   }
   return(NULL);
}


/**
 * @return double
 */
double CalcTrailingStop(int ticket) {
   if (UseTrailingStop && TrailingStop) {
      OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);

      if (OrderType() == OP_BUY) {
         if (Bid-OrderOpenPrice() > TrailingStop*Point) {
            return(Bid - TrailingStop*Point);
         }
      }
      else if (OrderType() == OP_SELL) {
         if (OrderOpenPrice()-Ask > TrailingStop*Point) {
            return(Ask + TrailingStop*Point);
         }
      }
   }
   return(NULL);
}
