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
 *
 */

/**
Alan Strawbridge [strawstock2@yahoo.com]

Name: Rhythm    Pair: Any Pair You like.

This is a simple Stop @ Reverse system. It should be able to be used with daily and weekly trading.

Once a trade is initiated stoploss and reversals are equal.
Example: the stop is placed at 40 PIPs and the reversal is likewise placed at 40 PIPs.
When the stop is activated, the reversal is simultaneously activated.  There is no limit on how
many reversals there can be in a day unless Max Trades variable is used

Inputs:
Overrule Direction: = True/False EA makes next day trade decision on the basis of the previous Days trend
(i.e.; previous day up, Place "Buy" market order, previous day down, enter "Sell" market order)
Example: Yesterdays open/close positive = LongEntry) (Yesterdays open/close negative = ShortEntry)
00:00 >< 23:55  Set it to False if you want to choose your own initial entry direction

Direction Long: =True/False  this is the manual way to either go Long or Short for your opening trade.
If using this variable Overrule Direction should be set to True

EntryTime Hour: = Entry will execute on the Open of the hour chosen. 00:00 thru 23:00

ExitTime Hour: =  00:00 thru 23:00 Exit will execute on the Open of the preceding bar from exit hour chosen
Example: exit set for 17:00 exit will execute on the open of the 18:00 bar.

Max Trades: = 0=False or 1,2,3,4 etc  Set this variable if you want to limit on how many whipsaws you want in a day or week.
EA will not take anymore trades for current day or week once variable is reached

TrailStop Once: = True/False (If set to True, Stop and Reverse order will move positive one time at
the value of the Stop loss variable)  Example: I am long at 1.2000 and I have my stop set at 1.1960 (-40)
If price was to advance to 1.2040 then my Stop & Reverse orders would move positive to 1.2000 This would be
the only positive move they would make.

Trailing Stop: = True/False (If set to True, Stop and Reverse order will move
every time price moves positive at the value of the Stop loss variable)

Stoploss: = Default 40  "Very important". It is the Value that all Stops will use.
(i.e.; TrailStop Once, Trailing Stop) It is the value that all Stop and Reverse orders are placed.

ProfitTarget: = 0=False, Default 120  If Profit Target or Time exit is not used than trade will remain
open until manually closed or when Profit Target or Time exit is initiated and executed in the future.

Lots = 0.1
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


/**
 *
 */
int start() {
   static int entryDirection = -1;
   static double entryLevel = 0;

   // Find trend (override possible and skip Sundays for Monday trend)
   if (entryDirection < 0) {
      if (OverruleDirection) {
         if (DirectionLong) entryDirection = OP_BUY;
         else               entryDirection = OP_SELL;
      }
      else {
         if (DayOfWeek() == 1) int bs = iBarShift(NULL, PERIOD_D1, TimeCurrent()-72*3600);
         else                  bs = 1;
         if (iOpen(NULL, PERIOD_D1, bs) < iClose(NULL, PERIOD_D1, bs)) entryDirection = OP_BUY;
         else                                                          entryDirection = OP_SELL;
      }
      if (entryDirection == OP_BUY) entryLevel = Ask;
      else                          entryLevel = Bid;
   }

   if (IsTradingTime()) {
      // check for open position & whether the daily stop limit is reached
      if (!IsOpenPosition() && !IsDailyStop()) {
         double sl = CalculateStopLoss(entryDirection);
         double tp = CalculateTakeProfit(entryDirection);

         if (entryDirection == OP_BUY) {
            if (NormalizeDouble(Ask, Digits) >= NormalizeDouble(entryLevel, Digits)) {                                  // TODO: Ask may not always be normalized
               OrderSend(Symbol(), entryDirection, Lots, Ask, Slippage, sl, tp, "Rhythm", MagicNumber, 0, Blue);
            }
         }
         else {
            if (NormalizeDouble(Bid, Digits) <= NormalizeDouble(entryLevel, Digits)) {                                  // TODO: Bid may not always be normalized
               OrderSend(Symbol(), entryDirection, Lots, Bid, Slippage, sl, tp, "Rhythm", MagicNumber, 0, Red);
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
               if (newSL > OrderStopLoss()) {
                  OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), OrderExpiration(), Blue);
                  entryLevel = newSL;
               }
            }
            else {
               newSL = NormalizeDouble(OrderClosePrice() + StopLoss*Point, Digits);
               if (newSL < OrderStopLoss()) {
                  OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), OrderExpiration(), Red);
                  entryLevel = newSL;
               }
            }
         }
         else if (TrailOnceStop) {
            newSL = OrderOpenPrice();
            if (OrderStopLoss() != newSL) {
               if (OrderType() == OP_BUY) {
                  double triggerPrice = NormalizeDouble(OrderOpenPrice() + StopLoss*Point, Digits);
                  if (Bid > triggerPrice) {                                                                             // TODO: it tests for "greater than" instead of >=
                     OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), OrderExpiration(), Blue);
                     entryLevel = newSL;
                  }
               }
               else {
                  triggerPrice = NormalizeDouble(OrderOpenPrice() - StopLoss*Point, Digits);
                  if (Ask < triggerPrice) {                                                                             // TODO: it tests for "lower than" instead of <=
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
   return(0);
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
      if      (type == OP_BUY)  sl = Bid - StopLoss*Point;
      else if (type == OP_SELL) sl = Ask + StopLoss*Point;
   }
   return(NormalizeDouble(sl, Digits));
}


/**
 *
 */
double CalculateTakeProfit(int type) {
   double tp = 0;
   if (TakeProfit > 0) {
      if      (type == OP_BUY)  tp = Bid + TakeProfit*Point;
      else if (type == OP_SELL) tp = Ask - TakeProfit*Point;
   }
   return(NormalizeDouble(tp, Digits));
}
