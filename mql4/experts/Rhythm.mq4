/**
 * Rewritten version of "Rhythm-v2" by Ronald Raygun.
 *
 *  @source  https://www.forexfactory.com/thread/post/1733378#post1733378
 *
 *
 * Rules
 * -----
 *
 *
 * Changes
 * -------
 *
 *
 * TODO:
 *  - performance
 *     GBPJPY,M1 2024.02.01-2024.03.02, EveryTick: 12.4 sec, 56 trades        Rhythm w/ framework, built-in order functions
 *     GBPJPY,M1 2024.02.01-2024.03.02, EveryTick:  8.2 sec, 56 trades        Rhythm w/o framework
 *     GBPJPY,M1 2024.02.01-2024.03.02, EveryTick: 13.6 sec, 56 trades        Rhythm-v2 2007.11.28 @rraygun
 */
#define STRATEGY_ID  112                     // unique strategy id (used for generation of magic order numbers)

#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 0;

////////////////////////////////////////////////////////// Inputs ///////////////////////////////////////////////////////////

extern bool   OverruleDirection = false;
extern bool   DirectionLong     = false;
extern int    EntryTimeHour     = 0;
extern int    ExitTimeHour      = 23;        // set it equal of lower of
extern int    MaxTrades         = 0;         // set <= 0 to disable
extern bool   TrailOnceStop     = true;
extern bool   TrailingStop      = false;

extern double Lots              = 0.1;
extern int    StopLoss          = 40;
extern int    TakeProfit        = 100;
extern int    MagicNumber       = 12345;
extern int    Slippage          = 5;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// framework
#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   static int entryDirection = -1;
   static double entryLevel = 0;

   // Find trend (override possible and skip Sundays for Monday trend)
   if (entryDirection < 0) {
      if (OverruleDirection) {
         if (DirectionLong) entryDirection = OP_BUY;
         else               entryDirection = OP_SELL;
      }
      else {
         if (DayOfWeek() == MONDAY) int bs = iBarShift(NULL, PERIOD_D1, TimeCurrent()-72*HOURS);
         else                           bs = 1;
         if (iOpen(NULL, PERIOD_D1, bs) < iClose(NULL, PERIOD_D1, bs)) entryDirection = OP_BUY;
         else                                                          entryDirection = OP_SELL;
      }
      if (entryDirection == OP_BUY) entryLevel = _Ask;
      else                          entryLevel = _Bid;
   }

   if (IsTradingTime()) {
      // check for open position & whether the daily stop limit is reached
      if (!IsOpenPosition() && !IsDailyStop()) {
         double sl = CalculateStopLoss(entryDirection);
         double tp = CalculateTakeProfit(entryDirection);

         if (entryDirection == OP_BUY) {
            if (GE(_Ask, entryLevel)) {
               OrderSend(Symbol(), entryDirection, Lots, _Ask, Slippage, sl, tp, "Rhythm", MagicNumber, 0, Blue);
            }
         }
         else {
            if (LE(_Bid, entryLevel)) {
               OrderSend(Symbol(), entryDirection, Lots, _Bid, Slippage, sl, tp, "Rhythm", MagicNumber, 0, Red);
            }
         }
      }

      if (IsOpenPosition()) {                         // selects the ticket
         // find opposite entry level
         if (OrderType() == OP_BUY) entryDirection = OP_SELL;
         else                       entryDirection = OP_BUY;
         entryLevel = OrderStopLoss();

         // manage StopLoss
         if (TrailingStop) {
            if (OrderType() == OP_BUY) {
               double newSL = NormalizeDouble(OrderClosePrice() - StopLoss*Point, Digits);
               if (GT(newSL, OrderStopLoss())) {
                  OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), OrderExpiration(), Blue);
                  entryLevel = newSL;
               }
            }
            else {
               newSL = NormalizeDouble(OrderClosePrice() + StopLoss*Point, Digits);
               if (LT(newSL, OrderStopLoss())) {
                  OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), OrderExpiration(), Red);
                  entryLevel = newSL;
               }
            }
         }
         else if (TrailOnceStop) {
            newSL = OrderOpenPrice();
            if (NE(newSL, OrderStopLoss())) {
               if (OrderType() == OP_BUY) {
                  double triggerPrice = NormalizeDouble(OrderOpenPrice() + StopLoss*Point, Digits);
                  if (_Bid > triggerPrice) {                                                                            // TODO: it tests for "greater than" instead of >=
                     OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), OrderExpiration(), Blue);
                     entryLevel = newSL;
                  }
               }
               else {
                  triggerPrice = NormalizeDouble(OrderOpenPrice() - StopLoss*Point, Digits);
                  if (_Ask < triggerPrice) {                                                                            // TODO: it tests for "lower than" instead of <=
                     OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), OrderExpiration(), Blue);
                     entryLevel = newSL;
                  }
               }
            }
         }
      }
   }

   else {
      // close open positions
      for (int i=OrdersTotal()-1; i >= 0; i--) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if (OrderSymbol() != Symbol())                   continue;
         if (OrderMagicNumber() != MagicNumber)           continue;
         OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 1);
      }
      entryDirection = -1;
      entryLevel = 0;
   }
   return(last_error);
}


/**
 *
 */
bool IsDailyStop() {
   int today_trades = 0;
   datetime today = iTime(NULL, PERIOD_D1, 0);

   for (int i=OrdersHistoryTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
      if (OrderSymbol() != Symbol())         continue;
      if (OrderMagicNumber() != MagicNumber) continue;
      if (OrderOpenTime() < today)           continue;
      today_trades++;

      if (MaxTrades > 0 && today_trades >= MaxTrades) return(true);
      if (TakeProfit > 0) {
         if (StringFind(OrderComment(), "[tp]") >= 0) return(true);
      }
   }
   return(false);
}


/**
 *
 */
bool IsOpenPosition() {
   for (int i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderType() > OP_SELL)             continue;
      if (OrderSymbol() != Symbol())         continue;
      if (OrderMagicNumber() != MagicNumber) continue;
      return(true);
   }
  return(false);
}


/**
 *
 */
bool IsTradingTime() {
   int now   = TimeCurrent() % DAY;
   int start = EntryTimeHour*HOURS;
   int end   = ExitTimeHour*HOURS;
   return(start <= now && now < end);
}


/**
 *
 */
double CalculateStopLoss(int type) {
   double sl = 0;
   if (StopLoss > 0) {
      if      (type == OP_BUY)  sl = _Bid - StopLoss*Point;
      else if (type == OP_SELL) sl = _Ask + StopLoss*Point;
   }
   return(NormalizeDouble(sl, Digits));
}


/**
 *
 */
double CalculateTakeProfit(int type) {
   double tp = 0;
   if (TakeProfit > 0) {
      if      (type == OP_BUY)  tp = _Bid + TakeProfit*Point;
      else if (type == OP_SELL) tp = _Ask - TakeProfit*Point;
   }
   return(NormalizeDouble(tp, Digits));
}
