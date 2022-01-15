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
extern int    ZigZag.Periods                 = 12;
       int    ZigZag.Deviation               = 5;
       int    ZigZag.Backstep                = 3;

extern string ___b__________________________ = "=== Trade settings ===";
extern double Lots                           = 0.1;
extern int    StopLoss                       = 10;       // in pip            if enabled: 10
extern int    TakeProfit                     = 0;        // in pip            if enabled:  6
extern int    TrailingStop                   = 0;        // in pip            if enabled:  3
extern int    BreakevenStopWhenProfit        = 0;        // in pip            if enabled:  5
extern int    MagicNumber                    = 12345;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>

#define SIGNAL_BUY      1
#define SIGNAL_SELL     2

#define MODE_SEMAPHORE  0

string signalToStr[]    = {"-", "Buy", "Sell"};
string zigzagIndicator  = "ZigZag.orig";
int    slippage         = 5;                    // in point


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // manage open positions
   bool isOpenPosition = false;
   int orders = OrdersTotal(), oe[];

   for (int i=0; i < orders; i ++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderType() > OP_SELL || OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      isOpenPosition = true;
      double sl = CalcStopLoss();
      double tp = CalcTakeProfit();
      if (NE(OrderStopLoss(), sl) || NE(OrderTakeProfit(), tp)) OrderModifyEx(OrderTicket(), OrderOpenPrice(), sl, tp, NULL, Red, NULL, oe);
   }

   // check entry signals and open new positions
   if (!isOpenPosition) {
      // find the last 3 ZigZag semaphores
      int s1Bar, s2Bar, s3Bar, s2Type, signal, iNull;
      if (!FindNextZigzagSemaphore(    0, s1Bar, iNull))  return(last_error);
      if (!FindNextZigzagSemaphore(s1Bar, s2Bar, s2Type)) return(last_error);
      if (!FindNextZigzagSemaphore(s2Bar, s3Bar, iNull))  return(last_error);

      // check entry signals (always against s2 level)
      if (s2Type == MODE_HIGH) {
         if (Low[s1Bar] > Low[s3Bar] && Bid > High[s2Bar]) signal = SIGNAL_BUY;
      }
      else {
         if (High[s1Bar] < High[s3Bar] && Bid < Low[s2Bar]) signal = SIGNAL_SELL;
      }

      Comment(NL, NL, NL,
              "Signal level long: ",  ifString(s2Type==MODE_HIGH &&  Low[s1Bar] >  Low[s3Bar], NumberToStr(High[s2Bar], PriceFormat), "-"), NL,
              "Signal level short: ", ifString(s2Type==MODE_LOW  && High[s1Bar] < High[s3Bar], NumberToStr( Low[s2Bar], PriceFormat), "-"), NL,
              "Signal: ",             signalToStr[signal]);

      // open new positions
      if (signal != NULL) {
         int type = ifInt(signal==SIGNAL_BUY, OP_BUY, OP_SELL);
         color clr = ifInt(signal==SIGNAL_BUY, Blue, Red);
         OrderSendEx(Symbol(), type,  Lots, NULL, slippage, NULL, NULL, "Opto123 "+ OrderTypeDescription(type), MagicNumber, NULL, clr, NULL, oe);
      }
   }
   return(catch("onTick(1)"));
}


/**
 * @return double
 */
double CalcStopLoss() {
   double sl;

   if (OrderType() == OP_BUY) {
      sl = 0;
      if (StopLoss > 0) {
         sl = MathMax(sl, OrderOpenPrice() - StopLoss*Pip);
      }
      if (BreakevenStopWhenProfit > 0) {
         if (Bid-OrderOpenPrice() >= BreakevenStopWhenProfit*Pip) {
            sl = MathMax(sl, OrderOpenPrice());
         }
      }
      if (TrailingStop > 0) {
         if (Bid-OrderOpenPrice() > TrailingStop*Pip) {
            sl = MathMax(sl, Bid - TrailingStop*Pip);
         }
      }
   }

   else if (OrderType() == OP_SELL) {
      sl = INT_MAX;
      if (StopLoss > 0) {
         sl = MathMin(sl, OrderOpenPrice() + StopLoss*Pip);
      }
      if (BreakevenStopWhenProfit > 0) {
         if (OrderOpenPrice()-Ask >= BreakevenStopWhenProfit*Pip) {
            sl = MathMin(sl, OrderOpenPrice());
         }
      }
      if (TrailingStop > 0) {
         if (OrderOpenPrice()-Ask > TrailingStop*Pip) {
            sl = MathMin(sl, Ask + TrailingStop*Pip);
         }
      }
      if (EQ(sl, INT_MAX)) sl = 0;
   }

   return(NormalizeDouble(sl, Digits));
}


/**
 * @return double
 */
double CalcTakeProfit() {
   double tp = 0;

   if (TakeProfit > 0) {
      if (OrderType() == OP_BUY) {
         tp = OrderOpenPrice() + TakeProfit*Pip;
      }
      else if (OrderType() == OP_SELL) {
         tp = OrderOpenPrice() - TakeProfit*Pip;
      }
   }
   return(NormalizeDouble(tp, Digits));
}


/**
 * Find the next ZigZag semaphore starting from the specified bar offset.
 *
 * @param  _In_  int  startbar - startbar to search from
 * @param  _Out_ int &offset   - offset of the found ZigZag semaphore
 * @param  _Out_ int &type     - type of the found semaphore: MODE_HIGH|MODE_LOW
 *
 * @return bool - success status
 */
bool FindNextZigzagSemaphore(int bar, int &offset, int &type) {
   int trend = Round(icZigZag(NULL, ZigZag.Periods, false, false, ZigZag.MODE_TREND, bar));
   if (!trend) return(false);

   int absTrend = Abs(trend);
   offset = bar + (absTrend % 100000) + (absTrend / 100000);
   type   = ifInt(trend < 0, MODE_HIGH, MODE_LOW);

   debug("FindNextZigzagSemaphore(1)  Tick="+ Tick +"  bar="+ bar +"  trend="+ trend +"  semaphore["+ offset +"]="+ TimeToStr(Time[offset], TIME_DATE|TIME_MINUTES) +"  "+ PriceTypeDescription(type));
   return(true);
}
