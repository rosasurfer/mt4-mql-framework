/**
 * AngryBird (aka Headless Chicken)
 *
 * A Martingale system with more or less random entry (like a headless chicken) and very low profit target. Always in the
 * market. Risk control via drawdown limit, adding of positions on BarOpen only. The distance between consecutive trades is
 * calculated dynamically.
 *
 * @see  https://www.mql5.com/en/code/12872
 *
 *
 * Notes:
 *  - Removed parameter "MaxTrades" as the drawdown limit must trigger before that number anyway.
 *  - Added explicit grid size limits.
 *  - Due to the near-random entries the probability of major losses increases with increasing volatility.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern double Lots.StartSize               = 0.02;
extern double Lots.Multiplier              = 1.4;        // was 2

extern double Grid.Min.Pips                = 2;          // was "DefaultPips/DEL = 0.4"
extern double Grid.Max.Pips                = 0;          // was "DefaultPips*DEL = 3.6"
extern int    Grid.TrueRange.Periods       = 24;
extern int    Grid.TrueRange.Divider       = 3;          // was "DEL"
extern bool   Grid.Contractable            = false;      // whether or not the grid is allowed to contract (was TRUE)

extern double TakeProfit.Pips              = 2;
extern int    DrawdownLimit.Percent        = 20;
extern string _____________________________;

extern int    Entry.RSI.UpperLimit         = 70;         // questionable
extern int    Entry.RSI.LowerLimit         = 30;         // long and short RSI entry filters

extern int    Exit.CCIStop                 = 0;          // questionable (was 500)
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
double grid.currentSize;                  // current grid size in pip
double grid.lastSize;                     // grid size of the last opened position in pip
int    grid.level;                        // current grid level: >= 0

// position tracking
int    position.tickets   [];             // currently open orders
double position.lots      [];             // order lot sizes
double position.openPrices[];             // order open prices
int    position.level;                    // current position level: positive or negative
double position.trailLimitPrice;          // current price limit to start profit trailing
double position.maxDrawdown;              // max. drawdown in account currency
double position.maxDrawdownPrice;         // stoploss price

bool   useTrailingStop;
bool   useCCIStop;

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
      os.name        = __NAME__;
      position.level = 0;
      ArrayResize(position.tickets,    0);
      ArrayResize(position.lots,       0);
      ArrayResize(position.openPrices, 0);

      double profit, lots;

      // read open positions
      int orders = OrdersTotal();
      for (int i=0; i < orders; i++) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber) {
            if (OrderType() == OP_BUY) {
               if (position.level < 0) return(!catch("InitStatus(1)  found open long and short positions", ERR_ILLEGAL_STATE));
               position.level++;
            }
            else if (OrderType() == OP_SELL) {
               if (position.level > 0) return(!catch("InitStatus(2)  found open long and short positions", ERR_ILLEGAL_STATE));
               position.level--;
            }
            else continue;

            ArrayPushInt   (position.tickets,    OrderTicket());
            ArrayPushDouble(position.lots,       OrderLots());
            ArrayPushDouble(position.openPrices, OrderOpenPrice());
            profit += OrderProfit();
            lots   += OrderLots();
         }
      }
      grid.timeframe = Period();
      grid.level     = Abs(position.level);

      double equityStart   = (AccountEquity()-AccountCredit()) - profit;
      position.maxDrawdown = NormalizeDouble(equityStart * DrawdownLimit.Percent/100, 2);

      if (grid.level > 0) {
         int    direction          = Sign(position.level);
         double avgPrice           = GetAvgPositionPrice();
         position.trailLimitPrice  = NormalizeDouble(avgPrice + direction * Exit.Trail.MinProfit.Pips*Pips, Digits);

         double maxDrawdownPips    = position.maxDrawdown/PipValue(lots);
         position.maxDrawdownPrice = NormalizeDouble(avgPrice - direction * maxDrawdownPips*Pips, Digits);
      }

      useTrailingStop = Exit.Trail.Pips > 0;
      useCCIStop      = Exit.CCIStop > 0;
   }
   return(catch("onInit(1)"));
}


/**
 *
 */
int onTick() {
   // check exit conditions on every tick
   if (grid.level > 0) {
      CheckOrders();
      CheckDrawdown();

      if (useCCIStop)
         CheckCCIStop();                                    // Will it ever be triggered?

      if (useTrailingStop)
         TrailProfits();                                    // fails live because done on every tick
   }


   // check entry conditions on BarOpen
   if (Tick==1 || EventListener.BarOpen(grid.timeframe)) {
      if (!grid.level) {
         if (Close[1] > Close[2]) {
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) < Entry.RSI.UpperLimit) {
               OpenPosition(OP_BUY);
            }
            else debug("onTick(1)  RSI(14xH1) filter: skipping long entry");
         }
         else if (Close[1] < Close[2]) {
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) > Entry.RSI.LowerLimit) {
               OpenPosition(OP_SELL);
            }
            else debug("onTick(2)  RSI(14xH1) filter: skipping short entry");
         }
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
   return(last_error);
}


/**
 * Calculate the current grid size and return the price at which to open the next position.
 *
 * @return double
 */
double UpdateGridSize() {
   double high = High[iHighest(NULL, grid.timeframe, MODE_HIGH, Grid.TrueRange.Periods, 1)];
   double low  = Low [ iLowest(NULL, grid.timeframe, MODE_LOW,  Grid.TrueRange.Periods, 1)];

   double barRange = (high-low) / Pip;
   double realSize = barRange / Grid.TrueRange.Divider;
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
   double avgPrice = GetAvgPositionPrice();
   int direction   = Sign(position.level);
   double tpPrice  = NormalizeDouble(avgPrice + direction * TakeProfit.Pips*Pips, Digits);

   for (int i=0; i < grid.level; i++) {
      if (!OrderSelect(position.tickets[i], SELECT_BY_TICKET))
         return(false);
      OrderModify(OrderTicket(), NULL, OrderStopLoss(), tpPrice, NULL, Blue);
   }
   position.trailLimitPrice = NormalizeDouble(avgPrice + direction * Exit.Trail.MinProfit.Pips*Pips, Digits);

   double maxDrawdownPips    = position.maxDrawdown/PipValue(GetFullPositionSize());
   position.maxDrawdownPrice = NormalizeDouble(avgPrice - direction * maxDrawdownPips*Pips, Digits);

   //debug("OpenPosition(3)  maxDrawdown="+ DoubleToStr(position.maxDrawdown, 2) +"  lots="+ DoubleToStr(GetFullPositionSize(), 1) +"  maxDrawdownPips="+ DoubleToStr(maxDrawdownPips, 1));
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

   grid.level     = 0;
   position.level = 0;

   ArrayResize(position.tickets,    0);
   ArrayResize(position.lots,       0);
   ArrayResize(position.openPrices, 0);
}


/**
 *
 */
void CheckOrders() {
   if (!grid.level)
      return;

   OrderSelect(position.tickets[0], SELECT_BY_TICKET);

   if (OrderCloseTime() != 0) {
      grid.level     = 0;
      position.level = 0;
      ArrayResize(position.tickets,    0);
      ArrayResize(position.lots,       0);
      ArrayResize(position.openPrices, 0);
   }
}


/**
 * Check and execute a CCI stop.
 */
void CheckCCIStop() {
   if (!grid.level)
      return;

   double cci = iCCI(NULL, PERIOD_M15, 55, PRICE_CLOSE, 0);
   int sign = -Sign(position.level);

   if (sign * cci > Exit.CCIStop) {
      debug("CheckCCIStop(1)  CCI stop of "+ Exit.CCIStop +" triggered, closing all trades...");
      ClosePositions();
   }
}


/**
 * Enforce the drawdown limit.
 */
void CheckDrawdown() {
   if (!grid.level)
      return;

   if (position.level > 0) {                       // make sure the limit is not triggered by spread widening
      if (Ask > position.maxDrawdownPrice)
         return;
   }
   else {
      if (Bid < position.maxDrawdownPrice)
         return;
   }
   debug("CheckDrawdown(1)  Drawdown limit of "+ DrawdownLimit.Percent +"% triggered, closing all trades...");
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
 * @return double - average full position price
 */
double GetAvgPositionPrice() {
   double sumPrice, sumLots;

   for (int i=0; i < grid.level; i++) {
      sumPrice += position.lots[i] * position.openPrices[i];
      sumLots  += position.lots[i];
   }

   if (!grid.level)
      return(0);
   return(sumPrice/sumLots);
}


/**
 * @return double - full position size
 */
double GetFullPositionSize() {
   double lots = 0;

   for (int i=0; i < grid.level; i++) {
      lots += position.lots[i];
   }
   return(NormalizeDouble(lots, 2));
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

                            "Grid.Min.Pips=",             NumberToStr(Grid.Min.Pips, ".1+")            , "; ",
                            "Grid.Max.Pips=",             NumberToStr(Grid.Max.Pips, ".1+")            , "; ",
                            "Grid.TrueRange.Periods=",    Grid.TrueRange.Periods                       , "; ",
                            "Grid.TrueRange.Divider=",    Grid.TrueRange.Divider                       , "; ",
                            "Grid.Contractable=",         BoolToStr(Grid.Contractable)                 , "; ",

                            "TakeProfit.Pips=",           NumberToStr(TakeProfit.Pips, ".1+")          , "; ",
                            "DrawdownLimit.Percent=",     DrawdownLimit.Percent                        , "; ",

                            "Exit.Trail.Pips=",           NumberToStr(Exit.Trail.Pips, ".1+")          , "; ",
                            "Exit.Trail.MinProfit.Pips=", NumberToStr(Exit.Trail.MinProfit.Pips, ".1+"), "; ",
                            "Exit.CCIStop=",              Exit.CCIStop                                 , "; ",

                            "Entry.RSI.UpperLimit=",      Entry.RSI.UpperLimit                         , "; ",
                            "Entry.RSI.LowerLimit=",      Entry.RSI.LowerLimit                         , "; ")
   );
}
