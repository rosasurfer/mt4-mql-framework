/**
 * AngryBird
 *
 * A Martingale system with almost random entry and unrealistic low profit target (2 pip). Tries to reduce losses by using a
 * dynamically adjusted trade spacing which adapts to the true range of a lookback period. Another feature is the opening of
 * positions only on BarOpen.
 *
 * Suggested for M1 (losing guaranteed). Let's try to move the profit target a few pips up and turn it into a somewhat stable
 * loser for reversion. A death trade or at least a reasonable drawdown per day would be nice.
 *
 * @see  https://www.mql5.com/en/code/12872
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern double Lots.StartSize                = 0.01;
extern double Lots.Multiplier               = 2;
extern int    MaxPositions                  = 10;              // was "MaxTrades"

extern double DefaultGridSize.Pip           = 1.2;             // was "DefaultPips" in points
extern int    DynamicGrid.Lookback.Periods  = 24;
extern int    DEL                           = 3;               // limiting grid size divider/multiplier

extern double Entry.RSI.UpperLimit          = 70;              // upper RSI limit (long entry)
extern double Entry.RSI.LowerLimit          = 30;              // lower RSI limit (short entry)

extern double TakeProfit.Pip                = 2;

extern bool   UseTrailingStop               = false;           // trailed on every tick
extern double TrailingStop.Size.Pip         = 1;               // trailing stop size
extern double TrailingStop.MinProfit.Pip    = 1;               // minimum profit to start trailing

extern bool   UseEquityStop                 = false;           // checked on BarOpen only
extern int    EquityRisk.Percent            = 20;

extern bool   UseCCIStop                    = false;           // checked on every tick
extern double CCIStop                       = 500;

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
int    grid.maxLevel;                     // maximum grid level:  > 0

// position tracking
int    position.tickets  [];              // currently open orders
double position.lots     [];              // order lot sizes
double position.openPrice[];              // order open prices
int    position.level;                    // current position level:  positive or negative
double position.tpPrice;                  // current TakeProfit price
double position.trailLimitPrice;          // current price limit for profit trailing

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
      ArrayResize(position.tickets,   0);
      ArrayResize(position.lots,      0);
      ArrayResize(position.openPrice, 0);

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

            ArrayPushInt   (position.tickets,   OrderTicket());
            ArrayPushDouble(position.lots,      OrderLots());
            ArrayPushDouble(position.openPrice, OrderOpenPrice());
         }
      }

      grid.timeframe = Period();
      grid.level     = Abs(position.level);
      grid.maxLevel  = MaxPositions;
   }
   return(catch("onInit(1)"));
}


/**
 *
 */
int onTick() {
   // check exit conditions on every tick
   if (grid.level > 0) {
      CheckTakeProfit();

      if (UseCCIStop)
         CheckCCIStop();                                    // Will it ever be triggered?

      if (UseEquityStop)
         CheckEquityStop();

      if (UseTrailingStop)
         TrailProfits();                                    // fails live because done on every tick
   }

   // stop adding more trades once MaxTrades has been reached
   if (grid.level == grid.maxLevel)
      return(last_error);


   // check entry conditions on BarOpen
   if (Tick==1 || EventListener.BarOpen(grid.timeframe)) {
      if (!grid.level) {
         if (Close[1] > Close[2]) {                         // the RSI conditions are almost always met
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) < Entry.RSI.UpperLimit) {
               OpenPosition(OP_BUY);
            }
         }
         else if (Close[1] < Close[2]) {
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) > Entry.RSI.LowerLimit) {
               OpenPosition(OP_SELL);
            }
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
   if (grid.size != last.size)
      debug("UpdateGrid(1)  range="+ NumberToStr((high-low)/Pip, "R.1") +" pip  next-level="+ DoubleToStr(grid.size, 1) +" pip");
   last.size = grid.size;

   double lastPrice = position.openPrice[grid.level-1];
   double nextPrice = lastPrice - Sign(position.level)*grid.size*Pips;

   return(NormalizeDouble(nextPrice, Digits));
}


/**
 * @return double - new average position price
 */
double UpdateAvgPrice() {
   double sumPrice, sumLots;

   for (int i=0; i < grid.level; i++) {
      sumPrice += position.lots[i] * position.openPrice[i];
      sumLots  += position.lots[i];
   }

   if (!grid.level)
      return(0);
   return(NormalizeDouble(sumPrice/sumLots, Digits));
}


/**
 * @return bool - success status
 */
bool OpenPosition(int type) {
   static int lotDecimals; if (!lotDecimals)
      lotDecimals = CountDecimals(MarketInfo(Symbol(), MODE_LOTSTEP));

   string   symbol      = Symbol();
   double   lots        = NormalizeDouble(Lots.StartSize * MathPow(Lots.Multiplier, grid.level), lotDecimals);
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
   ArrayPushInt   (position.tickets,   ticket);             // store ticket data
   ArrayPushDouble(position.lots,      oe.Lots(oe));
   ArrayPushDouble(position.openPrice, oe.OpenPrice(oe));

   // update TakeProfits
   double avgPrice = UpdateAvgPrice();
   int direction   = Sign(position.level);
   double tp       = NormalizeDouble(avgPrice + direction * TakeProfit.Pip*Pips, Digits);

   for (int i=0; i < grid.level; i++) {
      if (!OrderSelect(position.tickets[i], SELECT_BY_TICKET))
         return(false);
      OrderModify(OrderTicket(), NULL, OrderStopLoss(), tp, NULL, Blue);
   }
   position.trailLimitPrice = NormalizeDouble(avgPrice + direction * TrailingStop.MinProfit.Pip*Pips, Digits);

   return(true);
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

   ArrayResize(position.tickets,   0);
   ArrayResize(position.lots,      0);
   ArrayResize(position.openPrice, 0);
}


/**
 *
 */
void CheckTakeProfit() {
   if (!grid.level)
      return;

   OrderSelect(position.tickets[0], SELECT_BY_TICKET);

   if (OrderCloseTime() != 0) {
      grid.level     = 0;
      position.level = 0;
      ArrayResize(position.tickets,   0);
      ArrayResize(position.lots,      0);
      ArrayResize(position.openPrice, 0);
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

   if (sign * cci > CCIStop) {
      debug("CheckCCIStop(1)  CCI stop of "+ CCIStop +" triggered, closing all trades...");
      ClosePositions();
   }
}


/**
 * Check and enforce a drawdown limit.
 */
void CheckEquityStop() {
   if (!grid.level)
      return;

   double equityHigh = AccountEquityHigh();
   double equityStop = equityHigh * (100-EquityRisk.Percent)/100;

   if (equityHigh + CalculateProfit() <= equityStop) {
      debug("CheckEquityStop(1)  Drawdown limit of "+ EquityRisk.Percent +"% triggered, closing all trades...");
      ClosePositions();
   }
}


/**
 * Return the observed maximum account equity value of the current trade sequence (including unrealized profits).
 *
 * @return double
 *
 * Note: The original function didn't return the maximum value but the current equity value. A configured equity stop of
 *       e.g. 20% was in fact triggered at around 16%.
 */
double AccountEquityHigh() {
   static double equityHigh;
   if (!grid.level) equityHigh = AccountEquity();
   else             equityHigh = MathMax(AccountEquity(), equityHigh);
   return(equityHigh);
}


/**
 *
 */
double CalculateProfit() {
   double profit;

   for (int i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber) {
         if (OrderType()==OP_BUY || OrderType()==OP_SELL)
            profit += OrderProfit();
      }
   }
   return(profit);
}


/**
 * Trail stops of profitable trades. Will fail in real life because it trails every order on every tick.
 */
void TrailProfits() {
   if (!grid.level)
      return;

   if (position.level > 0) {
      if (Bid < position.trailLimitPrice) return;
      double stop = Bid - TrailingStop.Size.Pip*Pips;
   }
   else if (position.level < 0) {
      if (Ask > position.trailLimitPrice) return;
      stop = Ask + TrailingStop.Size.Pip*Pips;
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
