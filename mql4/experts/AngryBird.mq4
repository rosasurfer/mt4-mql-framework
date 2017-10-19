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
extern int    MaxTrades                     = 10;              // maximum number of simultaneously open orders

extern int    DefaultGridSize.Points        = 12;              // was "DefaultPips" in points
extern bool   DynamicGrid                   = true;            // was "DynamicPips"
extern int    DynamicGrid.Lookback.Periods  = 24;
extern int    DEL                           = 3;               // limiting grid size divisor/multiplier

extern double Entry.RSI.UpperLimit          = 70;              // upper RSI limit (long entry)
extern double Entry.RSI.LowerLimit          = 30;              // lower RSI limit (short entry)

extern int    TakeProfit.Points             = 20;

extern bool   UseTrailingStop               = false;           // trailed on every tick
extern int    TrailingStop.Points           = 10;
extern int    TrailingStop.MinProfit.Points = 10;

extern bool   UseEquityStop                 = false;           // checked on BarOpen only
extern int    EquityRisk.Percent            = 20;

extern bool   UseCCIStop                    = false;           // checked on every tick
extern double CCIStop                       = 500;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/xtrade/OrderExecution.mqh>


// grid management
int    grid.size;                         // current grid size in points
int    grid.level;                        // current grid level: >= 0
int    grid.maxLevel;                     // maximum grid level:  > 0

// position tracking
int    position.tickets  [];              // currently open orders
double position.lots     [];              // order lot sizes
double position.openPrice[];              // order open prices
int    position.level;                    // current position level:  positive or negative
double position.avgPrice;                 // current average position price

// OrderSend() defaults
double os.slippage    = 0.1;
int    os.magicNumber = 2222;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   InitStatus();
   return(catch("onInit(1)"));
}


/**
 *
 */
int onTick() {
   // no check whether or not pending close orders have been triggered

   if (grid.level && UseCCIStop)                            // Will it ever happen?
      CheckCCIStop();

   if (grid.level && UseTrailingStop)                       // fails live because done on every tick
      TrailProfits();


   // continue only on BarOpen                              // fails live on timeframe changes
   static datetime lastBarOpentime;
   if (Time[0] == lastBarOpentime)
      return(0);
   lastBarOpentime = Time[0];


   if (grid.level && UseEquityStop)                         // Why only on BarOpen? Hello margin call!
      CheckEquityStop();


   // a new sequence is started immediately after the last one was closed
   if (grid.level < grid.maxLevel) {
      if (!position.level) {
         if (Close[1] > Close[2]) {                         // the RSI condition is almost always fulfilled
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) < Entry.RSI.UpperLimit) {
               OpenPosition(OP_BUY, Lots.StartSize, __NAME__ +"-"+ (grid.level+1));
            }
         }
         else if (Close[1] < Close[2]) {                    // the RSI condition is almost always fulfilled
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) > Entry.RSI.LowerLimit) {
               OpenPosition(OP_SELL, Lots.StartSize, __NAME__ +"-"+ (grid.level+1));
            }
         }
      }
      else if (position.level > 0) {
         if (position.openPrice[grid.level-1]-Ask >= grid.size*Point) {
            double lots = NormalizeDouble(Lots.StartSize * MathPow(Lots.Multiplier, grid.level), 2);
            OpenPosition(OP_BUY, lots, __NAME__ +"-"+ (grid.level+1) +"-"+ grid.size);
         }
      }
      else /* position.level < 0 */ {
         if (Bid-position.openPrice[grid.level-1] >= grid.size*Point) {
            lots = NormalizeDouble(Lots.StartSize * MathPow(Lots.Multiplier, grid.level), 2);
            OpenPosition(OP_SELL, lots, __NAME__ +"-"+ (grid.level+1) +"-"+ grid.size);
         }
      }
   }

   return(last_error);
}


/**
 * Initialize the current status of grid and open positions.
 *
 * @return bool - success status
 */
int InitStatus() {
   if (!grid.size) {
      position.level    = 0;
      position.avgPrice = 0;
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
      grid.level    = Abs(position.level);
      grid.maxLevel = MaxTrades;


      // re-calculate average price
      double sumPrice, sumLots;
      for (i=0; i < grid.level; i++) {
         sumPrice += position.lots[i] * position.openPrice[i];
         sumLots  += position.lots[i];
      }
      if (grid.level > 0) position.avgPrice = NormalizeDouble(sumPrice/sumLots, Digits);


      // initialize grid.size
      if (DynamicGrid)  {
         double high = High[iHighest(NULL, NULL, MODE_HIGH, DynamicGrid.Lookback.Periods, 1)];
         double low  = Low [ iLowest(NULL, NULL, MODE_LOW,  DynamicGrid.Lookback.Periods, 1)];
         grid.size = NormalizeDouble((high-low)/DEL/Point, 0);
         if (grid.size < 1.*DefaultGridSize.Points/DEL) grid.size = NormalizeDouble(1.* DefaultGridSize.Points/DEL, 0);
         if (grid.size > 1.*DefaultGridSize.Points*DEL) grid.size = NormalizeDouble(1.* DefaultGridSize.Points*DEL, 0);
      }
      //else grid.size = DefaultGridSize.Points;
   }
   return(true);
}


/**
 *
 * @return bool - success status
 */
bool OpenPosition(int type, double lots, string comment) {
   string   symbol      = NULL;
   double   price       = NULL;
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   datetime expires     = NULL;
   color    markerColor = ifInt(type==OP_BUY, Blue, Red);
   int      oeFlags     = NULL;
   int      oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);

   int ticket = OrderSendEx(symbol, type, lots, price, os.slippage, stopLoss, takeProfit, comment, os.magicNumber, expires, markerColor, oeFlags, oe);
   if (IsEmpty(ticket)) return(false);

   // update levels & ticket data
   grid.level++;                                            // update grid.level
   if (type == OP_BUY) position.level++;                    // update position.level
   else                position.level--;
   ArrayPushInt   (position.tickets,   ticket);             // store ticket data
   ArrayPushDouble(position.lots,      oe.Lots(oe));
   ArrayPushDouble(position.openPrice, oe.OpenPrice(oe));

   // re-calculate average price
   double sumPrice, sumLots;
   for (int i=0; i < grid.level; i++) {
      sumPrice += position.lots[i] * position.openPrice[i];
      sumLots  += position.lots[i];
   }
   position.avgPrice = NormalizeDouble(sumPrice/sumLots, Digits);

   // update TakeProfits
   double tp = NormalizeDouble(position.avgPrice + Sign(position.level)*TakeProfit.Points*Point, Digits);
   for (i=0; i < grid.level; i++) {
      if (!OrderSelect(position.tickets[i], SELECT_BY_TICKET))
         return(false);
      OrderModify(OrderTicket(), NULL, OrderStopLoss(), tp, NULL, Blue);
   }
   return(true);
}


/**
 *
 */
void CloseAllPositions() {
   for (int i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber) {
         if      (OrderType() == OP_BUY)  OrderClose(OrderTicket(), OrderLots(), Bid, os.slippage*Pip/Point, Orange);
         else if (OrderType() == OP_SELL) OrderClose(OrderTicket(), OrderLots(), Ask, os.slippage*Pip/Point, Orange);
      }
   }
}


/**
 * Check and execute a CCI stop.
 */
void CheckCCIStop() {
   if (grid.level > 0) {
      double cci = iCCI(NULL, PERIOD_M15, 55, PRICE_CLOSE, 0);
      int sign = -Sign(position.level);

      if (sign * cci > CCIStop) {
         debug("CheckCCIStop(1)  CCI stop of "+ CCIStop +" triggered, closing all trades...");
         CloseAllPositions();
      }
   }
   catch("CheckCCIStop(2)");
}


/**
 * Check and enforce a drawdown limit.
 */
void CheckEquityStop() {
   double equityHigh = AccountEquityHigh();
   double equityStop = equityHigh * (100-EquityRisk.Percent)/100;

   if (equityHigh + CalculateProfit() <= equityStop) {
      debug("CheckEquityStop(1)  Drawdown limit of "+ EquityRisk.Percent +"% triggered, closing all trades...");
      CloseAllPositions();
   }
   catch("CheckEquityStop(2)");
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
   if (!TrailingStop.Points)
      return;

   double stop;

   for (int i=OrdersTotal()-1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderSymbol()==Symbol() || OrderMagicNumber()==os.magicNumber) {
            if (OrderType() == OP_BUY) {
               if (Bid < position.avgPrice + TrailingStop.MinProfit.Points*Point)
                  continue;

               stop = Bid - TrailingStop.Points*Point;
               if (stop > OrderStopLoss())
                  OrderModify(OrderTicket(), NULL, stop, OrderTakeProfit(), NULL, Red);
            }
            else if (OrderType() == OP_SELL) {
               if (Ask > position.avgPrice - TrailingStop.MinProfit.Points*Point)
                  continue;

               stop = Ask + TrailingStop.Points*Point;
               if (!OrderStopLoss() || stop < OrderStopLoss())
                  OrderModify(OrderTicket(), NULL, stop, OrderTakeProfit(), NULL, Red);
            }
         }
      }
   }
}
