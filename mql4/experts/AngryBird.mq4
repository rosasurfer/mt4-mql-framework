/**
 * AngryBird (aka Headless Chicken)
 *
 * A Martingale system with nearly random entry (like a headless chicken) and very low profit target. Always in the market.
 * Risk control via drawdown limit. Adding of positions on BarOpen only. The distance between consecutive trades adapts to
 * the past trading range.
 *
 * @see  https://www.mql5.com/en/code/12872
 *
 *
 * Notes:
 *  - Removed RSI entry filter as it has no statistical edge but reduces opportunities.
 *  - Removed CCI stop as the drawdown limit is a better stop condition.
 *  - Removed the MaxTrades limitation as the drawdown limit must trigger before that number anyway.
 *  - Added explicit grid size limits.
 *  - Added option to kick-start the chicken in a custom direction (doesn't wait for BarOpen).
 *  - Added option to put the chicken to rest after TakeProfit or StopLoss are hit. Enough hip-hop (default=On).
 *  - As volatility increases so does the probability of major losses.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern double Lots.StartSize               = 0.02;
extern double Lots.Multiplier              = 1.4;        // was 2

extern string Start.Direction              = "Long | Short | Auto*";

extern double TakeProfit.Pips              = 2;
extern bool   TakeProfit.Continue          = false;      // whether or not to continue after TakeProfit is hit

extern int    StopLoss.Percent             = 20;
extern bool   StopLoss.Continue            = false;      // whether or not to continue after StopLoss is hit

extern double Grid.Min.Pips                = 3.0;        // was "DefaultPips/DEL = 0.4"
extern double Grid.Max.Pips                = 0;          // was "DefaultPips*DEL = 3.6"
extern bool   Grid.Contractable            = false;      // whether or not the grid is allowed to contract (was TRUE)
extern int    Grid.Range.Periods           = 60;
extern int    Grid.Range.Divider           = 3;          // was "DEL"
extern string _____________________________;

extern double Exit.Trail.Pips              = 0;          // trailing stop size in pips (was 1)
extern double Exit.Trail.MinProfit.Pips    = 1;          // minimum profit in pips to start trailing

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/EventListener.BarOpen.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/xtrade/OrderExecution.mqh>


// grid management
int    grid.timeframe;                    // timeframe used for grid size calculation
int    grid.level;                        // current grid level: >= 0
double grid.lastSize;                     // grid size of the last opened position in pip
double grid.currentSize;                  // current grid size in pip
string grid.startDirection;

// position tracking
int    position.tickets   [];             // currently open orders
double position.lots      [];             // order lot sizes
double position.openPrices[];             // order open prices

int    position.level;                    // current position level: positive or negative
double position.totalSize;                // current total position lotsize
double position.totalPrice;               // current average position open price
double position.tpPrice;                  // current TakeProfit price
double position.slPrice;                  // current StopLoss price
double position.maxDrawdown;              // max. drawdown in account currency

bool   useTrailingStop;
double position.trailLimitPrice;          // current price limit to start profit trailing

// OrderSend() defaults
string os.name        = "";
int    os.magicNumber = 2222;
double os.slippage    = 0.1;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (!grid.timeframe) {
      // validate input parameters
      // Start.Direction
      string value, elems[];
      if (Explode(Start.Direction, "*", elems, 2) > 1) {
         int size = Explode(elems[0], "|", elems, NULL);
         value = elems[size-1];
      }
      else value = Start.Direction;
      value = StringToLower(StringTrim(value));

      if      (value=="l" || value=="long" )             Start.Direction = "long";
      else if (value=="s" || value=="short")             Start.Direction = "short";
      else if (value=="a" || value=="auto" || value=="") Start.Direction = "auto";
      else return(catch("onInit(1)  Invalid input parameter Start.Direction = "+ DoubleQuoteStr(Start.Direction), ERR_INVALID_INPUT_PARAMETER));
      grid.startDirection = Start.Direction;

      os.name        = __NAME__;
      position.level = 0;
      ArrayResize(position.tickets,    0);
      ArrayResize(position.lots,       0);
      ArrayResize(position.openPrices, 0);

      double profit;

      // read open positions
      int lastTicket, orders=OrdersTotal();
      string lastComment = "";

      for (int i=0; i < orders; i++) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber) {
            if (OrderType() == OP_BUY) {
               if (position.level < 0) return(!catch("onInit(2)  found open long and short positions", ERR_ILLEGAL_STATE));
               position.level++;
            }
            else if (OrderType() == OP_SELL) {
               if (position.level > 0) return(!catch("onInit(3)  found open long and short positions", ERR_ILLEGAL_STATE));
               position.level--;
            }
            else continue;

            ArrayPushInt   (position.tickets,    OrderTicket());
            ArrayPushDouble(position.lots,       OrderLots());
            ArrayPushDouble(position.openPrices, OrderOpenPrice());
            profit += OrderProfit();

            if (OrderTicket() > lastTicket) {
               lastTicket  = OrderTicket();
               lastComment = OrderComment();
            }
         }
      }
      if (StringLen(lastComment) > 0) lastComment   = StringRightFrom(lastComment, "-", 2);  // "AngryBird-10-2.0" => "2.0"
      if (StringLen(lastComment) > 0) grid.lastSize = StrToDouble(lastComment);

      grid.timeframe   = Period();
      grid.level       = Abs(position.level);
      grid.currentSize = grid.lastSize;

      double startEquity   = NormalizeDouble(AccountEquity() - AccountCredit() - profit, 2);
      position.maxDrawdown = NormalizeDouble(startEquity * StopLoss.Percent/100, 2);

      UpdateTotalPosition();

      if (grid.level > 0) {
         int direction            = Sign(position.level);
         position.trailLimitPrice = NormalizeDouble(position.totalPrice + direction * Exit.Trail.MinProfit.Pips*Pips, Digits);

         double maxDrawdownPips = position.maxDrawdown/PipValue(position.totalSize);
         position.slPrice       = NormalizeDouble(position.totalPrice - direction * maxDrawdownPips*Pips, Digits);
      }

      useTrailingStop = Exit.Trail.Pips > 0;
   }
   return(catch("onInit(4)"));
}


/**
 *
 */
int onTick() {
   // check exit conditions on every tick
   if (grid.level > 0) {
      CheckProfit();
      CheckDrawdown();

      if (useTrailingStop)
         TrailProfits();                                    // fails live because done on every tick
   }

   if (grid.startDirection == "auto") {
      // check entry conditions on BarOpen
      if (EventListener.BarOpen(grid.timeframe)) {
         if (!grid.level) {
            if      (Close[1] > Close[2]) OpenPosition(OP_BUY);
            else if (Close[1] < Close[2]) OpenPosition(OP_SELL);
         }
         else {
            double nextLevel = UpdateGridSize();
            if (position.level > 0) {
               if (Ask <= nextLevel) OpenPosition(OP_BUY);
            }
            else /*position.level < 0*/ {
               if (Bid >= nextLevel) OpenPosition(OP_SELL);
            }
         }
      }
   }
   else {
      if (!grid.level)
         OpenPosition(ifInt(grid.startDirection=="long", OP_BUY, OP_SELL));
      grid.startDirection = "auto";
   }
   return(last_error);
}


/**
 * Calculate the current grid size and return the price at which to open the next position.
 *
 * @return double
 */
double UpdateGridSize() {
   double high = High[iHighest(NULL, grid.timeframe, MODE_HIGH, Grid.Range.Periods, 1)];
   double low  = Low [ iLowest(NULL, grid.timeframe, MODE_LOW,  Grid.Range.Periods, 1)];

   double barRange = (high-low) / Pip;
   double realSize = barRange / Grid.Range.Divider;
   double adjusted = MathMax(realSize, Grid.Min.Pips);         // enforce lower limit
   if (Grid.Max.Pips > 0) {
          adjusted = MathMin(adjusted, Grid.Max.Pips);         // enforce upper limit
   }
   adjusted = NormalizeDouble(adjusted, 1);

   if (adjusted > grid.lastSize || Grid.Contractable)
      grid.currentSize = adjusted;

   //if (NE(grid.currentSize, realSize, 1)) {
   //   debug("UpdateGridSize(1)  range="+ NumberToStr(barRange, "R.1") +"  realSize="+ DoubleToStr(realSize, 1) + ifString(EQ(realSize, adjusted, 1), "", "  adjusted="+ DoubleToStr(adjusted, 1)));
   //}

   double lastPrice = position.openPrices[grid.level-1];
   double nextPrice = lastPrice - Sign(position.level) * grid.currentSize * Pips;

   return(NormalizeDouble(nextPrice, Digits));
}


/**
 * @return bool - success status
 */
bool OpenPosition(int type) {
   double rawLots = Lots.StartSize * MathPow(Lots.Multiplier, grid.level);
   double lots = NormalizeLots(rawLots);
   if (!lots) return(!catch("OpenPosition(1)  The determined lotsize is zero: "+ NumberToStr(lots, ".+") +" instead of exactly "+ NumberToStr(rawLots, ".+"), ERR_INVALID_INPUT_PARAMETER));

   double ratio = lots / rawLots;
      static bool lots.warned = false;
      if (rawLots > lots) ratio = 1/ratio;
      if (ratio > 1.15) if (!lots.warned) lots.warned = _true(warn("OpenPosition(2)  The determined lotsize significantly deviates from the exact one: "+ NumberToStr(lots, ".+") +" instead of "+ NumberToStr(rawLots, ".+")));

   string   symbol      = Symbol();
   double   price       = NULL;
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   string   comment     = os.name +"-"+ (grid.level+1) + ifString(!grid.level, "", "-"+ DoubleToStr(grid.currentSize, 1));
   datetime expires     = NULL;
   color    markerColor = ifInt(type==OP_BUY, Blue, Red);
   int      oeFlags     = NULL;
   int      oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);

   int ticket = OrderSendEx(symbol, type, lots, price, os.slippage, stopLoss, takeProfit, comment, os.magicNumber, expires, markerColor, oeFlags, oe);
   if (IsEmpty(ticket)) return(false);

   // update levels and ticket data
   grid.lastSize = ifDouble(!grid.level, 0, grid.currentSize);
   grid.level++;                                               // update grid.level
   if (type == OP_BUY) position.level++;                       // update position.level
   else                position.level--;
   ArrayPushInt   (position.tickets,    ticket);               // store ticket data
   ArrayPushDouble(position.lots,       oe.Lots(oe));
   ArrayPushDouble(position.openPrices, oe.OpenPrice(oe));

   // update takeprofit and stoploss
   double avgPrice = UpdateTotalPosition();
   int direction   = Sign(position.level);
   double tpPrice  = NormalizeDouble(avgPrice + direction * TakeProfit.Pips*Pips, Digits);

   for (int i=0; i < grid.level; i++) {
      if (!OrderSelect(position.tickets[i], SELECT_BY_TICKET))
         return(false);
      OrderModify(OrderTicket(), NULL, OrderStopLoss(), tpPrice, NULL, Blue);
   }
   position.trailLimitPrice = NormalizeDouble(avgPrice + direction * Exit.Trail.MinProfit.Pips*Pips, Digits);

   double maxDrawdownPips = position.maxDrawdown/PipValue(position.totalSize);
   position.slPrice       = NormalizeDouble(avgPrice - direction * maxDrawdownPips*Pips, Digits);

   //debug("OpenPosition(3)  maxDrawdown="+ DoubleToStr(position.maxDrawdown, 2) +"  lots="+ NumberToStr(position.totalLots, ".1+") +"  maxDrawdownPips="+ DoubleToStr(maxDrawdownPips, 1));
   return(!catch("OpenPosition(4)"));
}


/**
 *
 */
void ClosePositions() {
   if (!grid.level)
      return;

   int oes[][ORDER_EXECUTION.intSize];
   ArrayResize(oes, grid.level);
   InitializeByteBuffer(oes, ORDER_EXECUTION.size);

   if (!OrderMultiClose(position.tickets, os.slippage, Orange, NULL, oes))
      return;

   grid.level       = 0;
   grid.currentSize = 0;

   ArrayResize(position.tickets,    0);
   ArrayResize(position.lots,       0);
   ArrayResize(position.openPrices, 0);

   position.level      = 0;
   position.totalSize  = 0;
   position.totalPrice = 0;

   if (!StopLoss.Continue) {
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = ERR_CANCELLED_BY_USER;
   }
}


/**
 *
 */
void CheckProfit() {
   if (!grid.level)
      return;

   OrderSelect(position.tickets[0], SELECT_BY_TICKET);

   if (OrderCloseTime() && 1) {
      grid.level       = 0;
      grid.currentSize = 0;

      ArrayResize(position.tickets,    0);
      ArrayResize(position.lots,       0);
      ArrayResize(position.openPrices, 0);

      position.level      = 0;
      position.totalSize  = 0;
      position.totalPrice = 0;

      if (!TakeProfit.Continue) {
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = ERR_CANCELLED_BY_USER;
      }
   }
}


/**
 * Enforce the drawdown limit.
 */
void CheckDrawdown() {
   if (!grid.level)
      return;

   if (position.level > 0) {                       // make sure the limit is not triggered by spread widening
      if (Ask > position.slPrice)
         return;
   }
   else {
      if (Bid < position.slPrice)
         return;
   }
   debug("CheckDrawdown(1)  Drawdown limit of "+ StopLoss.Percent +"% triggered, closing all trades...");
   ClosePositions();
}


/**
 * Trail stops of profitable trades. Will fail in real life because it trails every order on every tick.
 */
void TrailProfits() {
   if (!grid.level)
      return;

   if (position.level > 0) {
      if (Bid < position.trailLimitPrice) return;
      double stop = Bid - Exit.Trail.Pips*Pips;
   }
   else if (position.level < 0) {
      if (Ask > position.trailLimitPrice) return;
      stop = Ask + Exit.Trail.Pips*Pips;
   }
   stop = NormalizeDouble(stop, Digits);

   for (int i=0; i < grid.level; i++) {
      OrderSelect(position.tickets[i], SELECT_BY_TICKET);

      if (position.level > 0) {
         if (stop > OrderStopLoss())
            OrderModify(OrderTicket(), NULL, stop, OrderTakeProfit(), NULL, Red);
      }
      else {
         if (!OrderStopLoss() || stop < OrderStopLoss())
            OrderModify(OrderTicket(), NULL, stop, OrderTakeProfit(), NULL, Red);
      }
   }
}


/**
 * Update total position size and price.
 *
 * @return double - average position price
 */
double UpdateTotalPosition() {
   double sumPrice, sumLots;

   for (int i=0; i < grid.level; i++) {
      sumPrice += position.lots[i] * position.openPrices[i];
      sumLots  += position.lots[i];
   }

   if (!grid.level) {
      position.totalSize  = 0;
      position.totalPrice = 0;
   }
   else {
      position.totalSize  = NormalizeDouble(sumLots, 2);
      position.totalPrice = sumPrice/sumLots;
   }
   return(position.totalPrice);
}


/**
 * Display the current runtime status.
 *
 * @param  int error - possible error to display (if any)
 *
 * @return int - the same error
 */
int ShowStatus(int error=NO_ERROR) {
   if (!__CHART)
      return(error);

   string str.error;
   if (__STATUS_OFF) str.error = StringConcatenate("  [", ErrorDescription(__STATUS_OFF.reason), "]");

   string str.profit = "-";
   if      (position.level > 0) str.profit = DoubleToStr((Bid - position.totalPrice)/Pip, 1);
   else if (position.level < 0) str.profit = DoubleToStr((position.totalPrice - Ask)/Pip, 1);

   string msg = StringConcatenate(__NAME__, str.error,                                                                               NL,
                                  "--------------",                                                                                  NL,
                                  "Open lots:   ",    NumberToStr(position.totalSize, ".1+"),                                        NL,
                                  "Grid level:   ",   position.level, "           size: ", DoubleToStr(grid.currentSize, 1), " pip", NL,
                                  "Profit:         ", str.profit,"       min: -       max: -",                                       NL);

   // 3 lines margin-top
   Comment(StringConcatenate(NL, NL, NL, msg));
   if (__WHEREAMI__ == RF_INIT)
      WindowRedraw();

   return(error);
}


/**
 * Return a string presentation of the input parameters (for logging).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()  inputs: ",

                            "Lots.StartSize=",            NumberToStr(Lots.StartSize, ".1+")           , "; ",
                            "Lots.Multiplier=",           NumberToStr(Lots.Multiplier, ".1+")          , "; ",

                            "Start.Direction=",           DoubleQuoteStr(Start.Direction)              , "; ",

                            "TakeProfit.Pips=",           NumberToStr(TakeProfit.Pips, ".1+")          , "; ",
                            "TakeProfit.Continue=",       BoolToStr(TakeProfit.Continue)               , "; ",

                            "StopLoss.Percent=",          StopLoss.Percent                             , "; ",
                            "StopLoss.Continue=",         BoolToStr(StopLoss.Continue)                 , "; ",

                            "Grid.Min.Pips=",             NumberToStr(Grid.Min.Pips, ".1+")            , "; ",
                            "Grid.Max.Pips=",             NumberToStr(Grid.Max.Pips, ".1+")            , "; ",
                            "Grid.Contractable=",         BoolToStr(Grid.Contractable)                 , "; ",
                            "Grid.Range.Periods=",        Grid.Range.Periods                           , "; ",
                            "Grid.Range.Divider=",        Grid.Range.Divider                           , "; ",

                            "Exit.Trail.Pips=",           NumberToStr(Exit.Trail.Pips, ".1+")          , "; ",
                            "Exit.Trail.MinProfit.Pips=", NumberToStr(Exit.Trail.MinProfit.Pips, ".1+"), "; ")
   );
}
