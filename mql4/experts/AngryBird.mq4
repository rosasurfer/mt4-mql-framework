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
 *  - Removed input parameter "MaxTrades" as the drawdown limit must trigger before that number anyway.
 *  - Caused by the random entries the probability of major losses increases with increasing volatility.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern double Lots.StartSize               = 0.05;
extern double Lots.Multiplier              = 1.4;

extern double DefaultGridSize.Pip          = 1.2;              // was "DefaultPips"
extern int    DynamicGrid.Lookback.Periods = 24;
extern int    DEL                          = 3;                // limiting grid distance divider/multiplier

extern double Entry.RSI.UpperLimit         = 70;               // questionable
extern double Entry.RSI.LowerLimit         = 30;               // long and short RSI entry filters

extern double Exit.TakeProfit.Pip          = 2;
extern int    Exit.DrawdownLimit.Percent   = 20;

extern double Exit.TrailingStop.Pip        = 0;                // trailing stop size in pip (was 1)
extern double Exit.TrailingStop.MinProfit  = 1;                // minimum profit in pips to start trailing

extern int    Exit.CCIStop                 = 0;                // questionable (was 500)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/EventListener.BarOpen.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/xtrade/OrderExecution.mqh>


// grid management
int    grid.timeframe;                    // timeframe used for dynamic grid calculation
double grid.size;                         // current grid size in pip
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
double os.slippage    = 0.1;
int    os.magicNumber = 2222;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (!grid.timeframe) {
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
      position.maxDrawdown = NormalizeDouble(equityStart * Exit.DrawdownLimit.Percent/100, 2);

      if (grid.level > 0) {
         int    direction          = Sign(position.level);
         double avgPrice           = GetAvgPositionPrice();
         position.trailLimitPrice  = NormalizeDouble(avgPrice + direction * Exit.TrailingStop.MinProfit*Pips, Digits);

         double maxDrawdownPips    = position.maxDrawdown/PipValue(lots);
         position.maxDrawdownPrice = NormalizeDouble(avgPrice - direction * maxDrawdownPips*Pips, Digits);
      }

      useTrailingStop = Exit.TrailingStop.Pip > 0;
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
      CheckProfit();
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
         double nextLevel = UpdateGrid();
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
 * @return double - price at which the next position will be opened
 */
double UpdateGrid() {
   static double last.size;

   double high = High[iHighest(NULL, grid.timeframe, MODE_HIGH, DynamicGrid.Lookback.Periods, 1)];
   double low  = Low [ iLowest(NULL, grid.timeframe, MODE_LOW,  DynamicGrid.Lookback.Periods, 1)];

   double size = (high-low) / DEL / Pip;

   size = MathMax(size, DefaultGridSize.Pip / DEL);
   size = MathMin(size, DefaultGridSize.Pip * DEL);

   grid.size = NormalizeDouble(size, 1);
   if (grid.size != last.size) {
      //debug("UpdateGrid(1)  range="+ NumberToStr((high-low)/Pip, "R.1") +" pip  next-level="+ DoubleToStr(grid.size, 1) +" pip");
   }
   last.size = grid.size;

   double lastPrice = position.openPrices[grid.level-1];
   double nextPrice = lastPrice - Sign(position.level)*grid.size*Pips;

   return(NormalizeDouble(nextPrice, Digits));
}


/**
 * @return bool - success status
 */
bool OpenPosition(int type) {
   double rawLots = Lots.StartSize * MathPow(Lots.Multiplier, grid.level);
   double lots    = NormalizeLots(rawLots);
   double ratio   = lots / rawLots;
      static bool lots.warned = false;
      if (rawLots > lots) ratio = 1/ratio;
      if (ratio > 1.15) if (!lots.warned) lots.warned = _true(warn("OpenPosition(1)  The applied lotsize significantly deviates from the calculated one: "+ NumberToStr(lots, ".+") +" instead of "+ NumberToStr(rawLots, ".+")));

   string   symbol      = Symbol();
   double   price       = NULL;
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   string   comment     = __NAME__ +"-"+ (grid.level+1) + ifString(!grid.level, "", "-"+ DoubleToStr(grid.size, 1));
   datetime expires     = NULL;
   color    markerColor = ifInt(type==OP_BUY, Blue, Red);
   int      oeFlags     = NULL;
   int      oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);

   int ticket = OrderSendEx(symbol, type, lots, price, os.slippage, stopLoss, takeProfit, comment, os.magicNumber, expires, markerColor, oeFlags, oe);
   if (IsEmpty(ticket)) return(false);

   // update levels and ticket data
   grid.level++;                                            // update grid.level
   if (type == OP_BUY) position.level++;                    // update position.level
   else                position.level--;
   ArrayPushInt   (position.tickets,    ticket);            // store ticket data
   ArrayPushDouble(position.lots,       oe.Lots(oe));
   ArrayPushDouble(position.openPrices, oe.OpenPrice(oe));

   // update takeprofit and stoploss
   double avgPrice = GetAvgPositionPrice();
   int direction   = Sign(position.level);
   double tpPrice  = NormalizeDouble(avgPrice + direction * Exit.TakeProfit.Pip*Pips, Digits);

   for (int i=0; i < grid.level; i++) {
      if (!OrderSelect(position.tickets[i], SELECT_BY_TICKET))
         return(false);
      OrderModify(OrderTicket(), NULL, OrderStopLoss(), tpPrice, NULL, Blue);
   }
   position.trailLimitPrice = NormalizeDouble(avgPrice + direction * Exit.TrailingStop.MinProfit*Pips, Digits);

   double maxDrawdownPips    = position.maxDrawdown/PipValue(GetFullPositionSize());
   position.maxDrawdownPrice = NormalizeDouble(avgPrice - direction * maxDrawdownPips*Pips, Digits);

   //debug("OpenPosition(2)  maxDrawdown="+ DoubleToStr(position.maxDrawdown, 2) +"  lots="+ DoubleToStr(GetFullPositionSize(), 1) +"  maxDrawdownPips="+ DoubleToStr(maxDrawdownPips, 1));
   return(!catch("OpenPosition(3)"));
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
void CheckProfit() {
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
   debug("CheckDrawdown(1)  Drawdown limit of "+ Exit.DrawdownLimit.Percent +"% triggered, closing all trades...");
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
      double stop = Bid - Exit.TrailingStop.Pip*Pips;
   }
   else if (position.level < 0) {
      if (Ask > position.trailLimitPrice) return;
      stop = Ask + Exit.TrailingStop.Pip*Pips;
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
