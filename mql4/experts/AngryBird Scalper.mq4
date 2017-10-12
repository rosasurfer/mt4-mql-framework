/**
 *
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////// Configuration ///////////////////////////////////////////////////////////////

extern double Lots.StartSize               = 0.01;
extern double Lots.Multiplier              = 2;
extern int    MaxTrades                    = 10;      // maximum number of simultaneously open orders

extern int    DefaultGridSize.Points       = 12;      // was "DefaultPips" in points
extern bool   DynamicGrid                  = true;    // was "DynamicPips"
extern int    DynamicGrid.Lookback.Periods = 24;
extern int    DEL                          = 3;       // limiting grid size divisor/multiplier

extern int    TakeProfit.Points            = 20;
extern double RsiMaximum                   = 70;      // upper limit of RSI
extern double RsiMinimum                   = 30;      // lower bound of RSI

extern bool   UseTrailingStop              = false;   // checked on every tick
extern double CCIStop                      = 500;

extern bool   UseEquityStop                = false;   // checked only on BarOpen
extern int    EquityRisk.Percent           = 20;

extern double Slippage                     = 3;       // acceptable slippage in points
extern int    MagicNumber                  = 2222;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>

int    PipStep;                                       // grid size in points

int    TrailingStop.StartProfit.Points = 10;
int    TrailinStop.Points              = 10;

double AveragePrice;
double LastBuyPrice, LastSellPrice;
bool   TradeNow, LongTrade, ShortTrade;
bool   NewOrdersPlaced;

string EAName = "AngryBird";


/**
 *
 */
int onTick() {
   if (DynamicGrid)  {
      double high = High[iHighest(NULL, NULL, MODE_HIGH, DynamicGrid.Lookback.Periods, 1)];
      double low  = Low [ iLowest(NULL, NULL, MODE_LOW,  DynamicGrid.Lookback.Periods, 1)];
      PipStep = NormalizeDouble((high-low)/DEL/Point, 0);                                    // calculate grid size
      if (PipStep < 1.*DefaultGridSize.Points/DEL) PipStep = NormalizeDouble(1.*DefaultGridSize.Points/DEL, 0);
      if (PipStep > 1.*DefaultGridSize.Points*DEL) PipStep = NormalizeDouble(1.*DefaultGridSize.Points*DEL, 0);  // if dynamic pips fail, assign pips extreme value
   }
   //else PipStep = DefaultGridSize.Points;

   if (UseTrailingStop)
      TrailStops(AveragePrice);

   if ((ShortTrade && iCCI(NULL, PERIOD_M15, 55, PRICE_CLOSE, 0) > CCIStop) || (LongTrade && iCCI(NULL, PERIOD_M15, 55, PRICE_CLOSE, 0) < -CCIStop)) {
      CloseAll();
      Print("Closed all trades (CCI stop triggered");
   }


   // continue only on BarOpen
   static datetime lastBarOpentime;
   if (Time[0] == lastBarOpentime)
      return(0);
   lastBarOpentime = Time[0];


   if (UseEquityStop) {
      double equityHigh = AccountEquityHigh();
      double equityStop = equityHigh * (100-EquityRisk.Percent)/100;

      if (equityHigh + CalculateProfit() <= equityStop) {
         CloseAll();
         Print("Closed all trades (equity stop triggerd)");
         NewOrdersPlaced = false;
      }
   }

   int total = CountTrades();

   for (int i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);

      if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
         if (OrderType() == OP_BUY) {
            LongTrade  = true;
            ShortTrade = false;
            break;
         }
         if (OrderType() == OP_SELL) {
            LongTrade  = false;
            ShortTrade = true;
            break;
         }
      }
   }

   if (total && total <= MaxTrades) {
      LastBuyPrice  = FindLastBuyPrice();
      LastSellPrice = FindLastSellPrice();
      if (LongTrade  && LastBuyPrice-Ask  >= PipStep*Point) TradeNow = true;
      if (ShortTrade && Bid-LastSellPrice >= PipStep*Point) TradeNow = true;
   }

   if (!total) {
      LongTrade  = false;
      ShortTrade = false;
      TradeNow   = true;
   }

   if (TradeNow) {
      LastBuyPrice  = FindLastBuyPrice();
      LastSellPrice = FindLastSellPrice();

      if (LongTrade) {
         double lots = NormalizeDouble(Lots.StartSize * MathPow(Lots.Multiplier, total), 2);
         OpenPosition(OP_BUY, lots, EAName +"-"+ total +"-"+ PipStep);
         LastBuyPrice    = FindLastBuyPrice();
         NewOrdersPlaced = true;
         TradeNow        = false;
      }
      if (ShortTrade) {
         lots = NormalizeDouble(Lots.StartSize * MathPow(Lots.Multiplier, total), 2);
         OpenPosition(OP_SELL, lots, EAName +"-"+ total +"-"+ PipStep);
         LastSellPrice   = FindLastSellPrice();
         NewOrdersPlaced = true;
         TradeNow        = false;
      }
   }

   if (TradeNow && total < 1) {
      if (!ShortTrade && !LongTrade) {
         lots = NormalizeDouble(Lots.StartSize * MathPow(Lots.Multiplier, total), 2);
         if (Close[2] > Close[1]) {
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) > RsiMinimum) {
               OpenPosition(OP_SELL, lots, EAName +"-"+ total);
               LastBuyPrice    = FindLastBuyPrice();
               NewOrdersPlaced = true;
            }
         }
         else {
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) < RsiMaximum) {
               OpenPosition(OP_BUY, lots, EAName +"-"+ total);
               LastSellPrice   = FindLastSellPrice();
               NewOrdersPlaced = true;
            }
         }
         TradeNow = false;
      }
   }

   total = CountTrades();
   AveragePrice = 0;
   double sumLots = 0;

   for (i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
         if (OrderType()==OP_BUY || OrderType()==OP_SELL) {
            AveragePrice += OrderOpenPrice() * OrderLots();
            sumLots += OrderLots();
         }
      }
   }
   if (total > 0)
      AveragePrice = NormalizeDouble(AveragePrice/sumLots, Digits);

   if (NewOrdersPlaced) {
      double tpPrice = 0;

      for (i=OrdersTotal()-1; i >= 0; i--) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
            if (OrderType() == OP_BUY) {
               tpPrice = AveragePrice + TakeProfit.Points*Point;
               break;
            }
            if (OrderType() == OP_SELL) {
               tpPrice = AveragePrice - TakeProfit.Points*Point;
               break;
            }
         }
      }
      if (tpPrice != 0) {
         for (i=OrdersTotal()-1; i >= 0; i--) {
            OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
            if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
               OrderModify(OrderTicket(), NULL, OrderStopLoss(), NormalizeDouble(tpPrice, Digits), NULL, Blue);
               NewOrdersPlaced = false;
            }
         }
      }
   }
   return (0);
}


/**
 *
 */
int CountTrades() {
   int count = 0;
   for (int i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
         if (OrderType()==OP_SELL || OrderType()==OP_BUY) count++;
      }
   }
   return (count);
}


/**
 *
 */
void CloseAll() {
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
int OpenPosition(int type, double lots, string comment) {
   switch (type) {
      case OP_BUY : return(OrderSend(Symbol(), OP_BUY,  lots, Ask, Slippage, NULL, NULL, comment, MagicNumber, NULL, Blue));
      case OP_SELL: return(OrderSend(Symbol(), OP_SELL, lots, Bid, Slippage, NULL, NULL, comment, MagicNumber, NULL, Red));
   }
   return(0);
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
 * Trail stops of all open trades. Will fail in real trading because it's called on every tick.
 */
void TrailStops(double avgPrice) {
   if (!TrailinStop.Points)
      return;

   double stop;

   for (int i=OrdersTotal()-1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderSymbol()==Symbol() || OrderMagicNumber()==MagicNumber) {
            if (OrderType() == OP_BUY) {
               if (Bid < avgPrice + TrailingStop.StartProfit.Points*Point)
                  continue;

               stop = Bid - TrailinStop.Points*Point;
               if (stop > OrderStopLoss())
                  OrderModify(OrderTicket(), NULL, stop, OrderTakeProfit(), NULL, Red);
            }
            else if (OrderType() == OP_SELL) {
               if (Ask > avgPrice - TrailingStop.StartProfit.Points*Point)
                  continue;

               stop = Ask + TrailinStop.Points*Point;
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
 * ERROR: The original function returned instead of the maximum value the current equity value. A configured equity stop of e.g. 20% was
 *        in fact triggered at around 16%.
 */
double AccountEquityHigh() {
   static double equityHigh;
   if (CountTrades() == 0) equityHigh = AccountEquity();
   else                    equityHigh = MathMax(AccountEquity(), equityHigh);
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
   return (oldorderopenprice);
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
   return (oldorderopenprice);
}
