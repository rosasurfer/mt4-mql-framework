/**
 * Opto123 Pattern EA
 *
 * A simplified and fixed version of the original 123 Pattern EA v1.0 published by Ronald Raygun. The trading logic is
 * unchanged.
 *
 * @source  https://www.forexfactory.com/thread/post/4090801#post4090801                            [Opto123 Pattern EA v1.0]
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___a__________________________ = "=== Signal settings ===";
extern int    ZigZag.Depth                   = 12;
extern int    ZigZag.Deviation               = 5;
extern int    ZigZag.Backstep                = 3;
extern int    PipBuffer                      = 0;

extern string ___b__________________________ = "=== Trade settings ===";
extern double Lots                           = 0.1;
extern int    StopLoss                       = 10;    // in pip
extern int    TakeProfit                     = 0;     // in pip         6.0
extern int    TrailingStop                   = 0;     // in pip         3.0
extern int    BreakevenStopWhenProfit        = 0;     // in pip         5.0
extern int    MagicNumber                    = 0;
extern int    Slippage                       = 5;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>

#define SIGNAL_BUY      1
#define SIGNAL_SELL     2

#define MODE_SEMAPHORE  0

string signalToStr[]    = {"-", "Buy", "Sell"};
string zigzagIndicator  = "ZigZag.orig";


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // manage open positions
   double PotentialStopLoss, BEven, TrailStop;
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
      double zz1, zz2, zz3, signalLevelLong, signalLevelShort;
      int bar=1, type, signal;

      while (true) {
         zz1 = iCustom(NULL, NULL, zigzagIndicator, ZigZag.Depth, ZigZag.Deviation, ZigZag.Backstep, MODE_SEMAPHORE, bar);
         if (EQ(zz1, High[bar])) { type = MODE_HIGH; break; }
         if (EQ(zz1,  Low[bar])) { type = MODE_LOW;  break; }
         bar++;
      }
      bar++;
      while (true) {
         zz2 = iCustom(NULL, NULL, zigzagIndicator, ZigZag.Depth, ZigZag.Deviation, ZigZag.Backstep, MODE_SEMAPHORE, bar);
         if (EQ(zz2, High[bar]) && type==MODE_LOW ) break;
         if (EQ(zz2,  Low[bar]) && type==MODE_HIGH) break;
         bar++;
      }
      bar++;
      while (true) {
         zz3 = iCustom(NULL, NULL, zigzagIndicator, ZigZag.Depth, ZigZag.Deviation, ZigZag.Backstep, MODE_SEMAPHORE, bar);
         if (EQ(zz3, High[bar]) && type==MODE_HIGH) break;
         if (EQ(zz3,  Low[bar]) && type==MODE_LOW ) break;
         bar++;
      }

      if (zz3 < zz2 && zz2 > zz1 && zz1 > zz3) signalLevelLong  = zz2 + PipBuffer*Point;
      if (zz3 > zz2 && zz2 < zz1 && zz1 < zz3) signalLevelShort = zz2 - PipBuffer*Point;

      if (Open[0] < signalLevelLong  && Close[0] >= signalLevelLong)  signal = SIGNAL_BUY;
      if (Open[0] > signalLevelShort && Close[0] <= signalLevelShort) signal = SIGNAL_SELL;

      Comment(NL, NL, NL,
              "Signal level long: ",  ifString(!signalLevelLong,  "-", NumberToStr(signalLevelLong,  PriceFormat)), NL,
              "Signal level short: ", ifString(!signalLevelShort, "-", NumberToStr(signalLevelShort, PriceFormat)), NL,
              "Signal: ",             signalToStr[signal]);

      // open new positions
      if (signal != NULL) {
         double sl, tp;
         if (signal == SIGNAL_BUY) {
            if (StopLoss   > 0) sl = Ask -   StopLoss*Pip;
            if (TakeProfit > 0) tp = Ask + TakeProfit*Pip;
            OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, sl, tp, "Opto123 Buy", MagicNumber, 0, DodgerBlue);
         }
         if (signal == SIGNAL_SELL) {
            if (StopLoss   > 0) sl = Bid +   StopLoss*Pip;
            if (TakeProfit > 0) tp = Bid - TakeProfit*Pip;
            OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, sl, tp, "Opto123 Sell", MagicNumber, 0, DeepPink);
         }
      }
   }
   return(catch("onTick(1)"));
}


/**
 * @return double
 */
double CalcBreakEven(int ticket) {
   if (BreakevenStopWhenProfit > 0) {
      OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);

      if (OrderType() == OP_BUY) {
         if (Bid-OrderOpenPrice() >= BreakevenStopWhenProfit*Pip) {
            return(OrderOpenPrice());
         }
      }
      else if (OrderType() == OP_SELL) {
         if (OrderOpenPrice()-Ask >= BreakevenStopWhenProfit*Pip) {
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
   if (TrailingStop > 0) {
      OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);

      if (OrderType() == OP_BUY) {
         if (Bid-OrderOpenPrice() > TrailingStop*Pip) {
            return(Bid - TrailingStop*Pip);
         }
      }
      else if (OrderType() == OP_SELL) {
         if (OrderOpenPrice()-Ask > TrailingStop*Pip) {
            return(Ask + TrailingStop*Pip);
         }
      }
   }
   return(NULL);
}
