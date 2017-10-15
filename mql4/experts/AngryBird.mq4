/**
 * AngryBird
 *
 * A Martingale system with almost random entry and unrealistic low profit target (2 pip). It tries to reduce losses by using
 * a dynamically adjusted distance between consecutive trades (grid size can increase and decrease). Further life-prolonging
 * feature is the opening of new positions only on BarOpen.
 * Let's try to move the profit target near 5 pip and turn the whole thing into a somewhat stable loser. A death trade or at
 * least a reasonable drawdown per day would be nice.
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

extern double Entry.Long.RsiMaximum         = 70;              // upper RSI limit for long entry conditions
extern double Entry.Short.RsiMinimum        = 30;              // lower RSI limit for short entry conditions

extern bool   UseEquityStop                 = false;           // checked on BarOpen only
extern int    EquityRisk.Percent            = 20;

extern bool   UseCCIStop                    = true;            // checked on every tick
extern double CCIStop                       = 500;

extern int    TakeProfit.Points             = 20;

extern bool   UseTrailingStop               = false;           // trailed on every tick
extern int    TrailingStop.Points           = 10;
extern int    TrailingStop.MinProfit.Points = 10;

extern double Slippage                      = 3;               // acceptable slippage in points
extern int    MagicNumber                   = 2222;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>


// grid management
int    grid.size;                                              // current grid size in points
int    grid.level;                                             // current grid level
int    grid.maxLevel;                                          // maximum grid level
double grid.avgPrice;                                          // average full position price

// position tracking
int    long.positions;                                         // number of open positions = current grid level per direction
int    short.positions;


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
 */                                                            // No check if orders have been closed by TakeProfit.
int onTick() {
   if (grid.level && UseCCIStop)                               // Will it ever happen?
      CheckCCIStop();

   if (grid.level && UseTrailingStop)                          // Fails live because done on every tick.
      TrailProfits(grid.avgPrice);


   // continue only on BarOpen                                 // Fails live on timeframe changes.
   static datetime lastBarOpentime;
   if (Time[0] == lastBarOpentime)
      return(0);
   lastBarOpentime = Time[0];

   if (grid.level && UseEquityStop)                            // How only on BarOpen? Hello margin call!
      CheckEquityStop();




   bool NewOrdersPlaced = false;

   if (!grid.level) {                                       // The next sequence is opened immediately.
      double lots = NormalizeDouble(Lots.StartSize, 2);
      if (Close[2] > Close[1]) {                            // The RSI condition is almost always (>95%) fulfilled.
         if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) > Entry.Short.RsiMinimum) {
            OpenPosition(OP_SELL, lots, __NAME__ +"-"+ (grid.level+1));
            NewOrdersPlaced = true;
            short.positions++;
            grid.level++;
         }
      }
      else {                                                // The RSI condition is almost always (>95%) fulfilled.
         if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) < Entry.Long.RsiMaximum) {
            OpenPosition(OP_BUY, lots, __NAME__ +"-"+ (grid.level+1));
            NewOrdersPlaced = true;
            long.positions++;
            grid.level++;
         }
      }
   }
   else if (grid.level < grid.maxLevel) {
      if (long.positions > 0) {
         if (FindLastBuyPrice()-Ask  >= grid.size*Point) {
            lots = NormalizeDouble(Lots.StartSize * MathPow(Lots.Multiplier, grid.level), 2);
            OpenPosition(OP_BUY, lots, __NAME__ +"-"+ (grid.level+1) +"-"+ grid.size);
            NewOrdersPlaced = true;
            long.positions++;
            grid.level++;
         }
      }
      else {
         if (Bid-FindLastSellPrice() >= grid.size*Point) {
            lots = NormalizeDouble(Lots.StartSize * MathPow(Lots.Multiplier, grid.level), 2);
            OpenPosition(OP_SELL, lots, __NAME__ +"-"+ (grid.level+1) +"-"+ grid.size);
            NewOrdersPlaced = true;
            short.positions++;
            grid.level++;
         }
      }
   }





   // calculate average full position price
   grid.avgPrice = 0;
   lots = 0;
   for (int i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
         if (OrderType()==OP_BUY || OrderType()==OP_SELL) {
            grid.avgPrice += OrderOpenPrice() * OrderLots();
            lots          += OrderLots();
         }
      }
   }
   if (grid.level > 0)
      grid.avgPrice = NormalizeDouble(grid.avgPrice/lots, Digits);



   // update TakeProfit of all positions
   if (NewOrdersPlaced) {
      double tp.long  = NormalizeDouble(grid.avgPrice + TakeProfit.Points*Point, Digits);
      double tp.short = NormalizeDouble(grid.avgPrice - TakeProfit.Points*Point, Digits);

      for (i=OrdersTotal()-1; i >= 0; i--) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
            if (OrderType() == OP_BUY)  OrderModify(OrderTicket(), NULL, OrderStopLoss(), tp.long,  NULL, Blue);
            if (OrderType() == OP_SELL) OrderModify(OrderTicket(), NULL, OrderStopLoss(), tp.short, NULL, Blue);
         }
      }
   }
   return(0);
}


/**
 * Initialize the current status of grid and open positions.
 *
 * @return bool - success status
 */
int InitStatus() {
   if (!grid.size) {
      long.positions  = 0;
      short.positions = 0;

      // check open positions
      for (int i=OrdersTotal()-1; i >= 0; i--) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
            if      (OrderType() == OP_BUY)  long.positions++;
            else if (OrderType() == OP_SELL) short.positions++;
         }
      }
      if (long.positions && short.positions)
         return(!catch("InitStatus(1)  found open long and short positions", ERR_ILLEGAL_STATE));

      // initialize current grid.size
      if (DynamicGrid)  {
         double high = High[iHighest(NULL, NULL, MODE_HIGH, DynamicGrid.Lookback.Periods, 1)];
         double low  = Low [ iLowest(NULL, NULL, MODE_LOW,  DynamicGrid.Lookback.Periods, 1)];
         grid.size = NormalizeDouble((high-low)/DEL/Point, 0);
         if (grid.size < 1.*DefaultGridSize.Points/DEL) grid.size = NormalizeDouble(1.* DefaultGridSize.Points/DEL, 0);
         if (grid.size > 1.*DefaultGridSize.Points*DEL) grid.size = NormalizeDouble(1.* DefaultGridSize.Points*DEL, 0);
      }
      //else grid.size = DefaultGridSize.Points;
      grid.level    = Max(long.positions, short.positions);
      grid.maxLevel = MaxTrades;
   }
   return(true);
}


/**
 *
 */
void OpenPosition(int type, double lots, string comment) {
   switch (type) {
      case OP_BUY : OrderSend(Symbol(), OP_BUY,  lots, Ask, Slippage, NULL, NULL, comment, MagicNumber, NULL, Blue); break;
      case OP_SELL: OrderSend(Symbol(), OP_SELL, lots, Bid, Slippage, NULL, NULL, comment, MagicNumber, NULL, Red);  break;
   }
}


/**
 *
 */
void CloseAllPositions() {
   for (int i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
         if      (OrderType() == OP_BUY)  OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, Orange);
         else if (OrderType() == OP_SELL) OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, Orange);
      }
   }
}


/**
 *
 */
double CalculateProfit() {
   double profit;

   for (int i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
         if (OrderType()==OP_BUY || OrderType()==OP_SELL)
            profit += OrderProfit();
      }
   }
   return(profit);
}


/**
 * Check and execute a CCI stop.
 */
void CheckCCIStop() {
   if (grid.level > 0) {
      double cci = iCCI(NULL, PERIOD_M15, 55, PRICE_CLOSE, 0);
      int  sign = ifInt(long.positions, -1, +1);

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
 * Trail stops of profitable trades. Will fail in real life because it trails every order on every tick.
 */
void TrailProfits(double avgPrice) {
   if (!TrailingStop.Points)
      return;

   double stop;

   for (int i=OrdersTotal()-1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderSymbol()==Symbol() || OrderMagicNumber()==MagicNumber) {
            if (OrderType() == OP_BUY) {
               if (Bid < avgPrice + TrailingStop.MinProfit.Points*Point)
                  continue;

               stop = Bid - TrailingStop.Points*Point;
               if (stop > OrderStopLoss())
                  OrderModify(OrderTicket(), NULL, stop, OrderTakeProfit(), NULL, Red);
            }
            else if (OrderType() == OP_SELL) {
               if (Ask > avgPrice - TrailingStop.MinProfit.Points*Point)
                  continue;

               stop = Ask + TrailingStop.Points*Point;
               if (!OrderStopLoss() || stop < OrderStopLoss())
                  OrderModify(OrderTicket(), NULL, stop, OrderTakeProfit(), NULL, Red);
            }
         }
      }
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
double FindLastBuyPrice() {
   int ticketnumber, oldticketnumber;
   double oldorderopenprice;

   for (int i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber && OrderType()==OP_BUY) {
         oldticketnumber = OrderTicket();
         if (oldticketnumber > ticketnumber) {
            oldorderopenprice = OrderOpenPrice();
            ticketnumber = oldticketnumber;
         }
      }
   }
   return(oldorderopenprice);
}


/**
 *
 */
double FindLastSellPrice() {
   int ticketnumber, oldticketnumber;
   double oldorderopenprice;

   for (int i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber && OrderType()==OP_SELL) {
         oldticketnumber = OrderTicket();
         if (oldticketnumber > ticketnumber) {
            oldorderopenprice = OrderOpenPrice();
            ticketnumber = oldticketnumber;
         }
      }
   }
   return(oldorderopenprice);
}
