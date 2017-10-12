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

extern int    DefaultGridSize              = 12;      // was "DefaultPips" in points
extern bool   DynamicGrid                  = true;    // was "DynamicPips"
extern int    DynamicGrid.Lookback.Periods = 24;
extern int    DEL                          = 3;       // limiting grid size divisor/multiplier

extern double TakeProfit                   = 20;      // when many profit points are reached, close the deal
extern double RsiMinimum                   = 30;      // lower bound of RSI
extern double RsiMaximum                   = 70;      // upper limit of RSI

extern bool   UseEquityStop                = false;
extern int    EquityRisk.Percent           = 20;

extern bool   UseTrailingStop              = false;
extern double CCIStop                      = 500;

extern double Slippage                     = 3;       // slippage in points
extern int    MagicNumber                  = 2222;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>

int    PipStep;                                       // grid size in points

int    TrailingStop.StartProfit.Points = 10;
int    TrailinStop.Points              = 10;

double PriceTarget, StartEquity, BuyTarget, SellTarget;
double AveragePrice;
double LastBuyPrice, LastSellPrice;
bool   flag;
int    timeprev;
int    NumOfTrades;
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
      if (PipStep < DefaultGridSize/DEL) PipStep = NormalizeDouble(DefaultGridSize/DEL, 0);
      if (PipStep > DefaultGridSize*DEL) PipStep = NormalizeDouble(DefaultGridSize*DEL, 0);  // if dynamic pips fail, assign pips extreme value
   }
   //else PipStep = DefaultGridSize;

   if (UseTrailingStop)
      TrailStops(AveragePrice);

   if ((ShortTrade && iCCI(NULL, PERIOD_M15, 55, PRICE_CLOSE, 0) > CCIStop) || (LongTrade && iCCI(NULL, PERIOD_M15, 55, PRICE_CLOSE, 0) < -CCIStop)) {
      CloseThisSymbolAll();
      Print("Closed all due to timeout");
   }

   if (timeprev == Time[0])
      return (0);
   timeprev = Time[0];

   if (UseEquityStop) {
      double profitLoss = CalculateProfit();
      if (profitLoss < 0 && MathAbs(profitLoss) > AccountEquityHigh()*EquityRisk.Percent/100.) {
         CloseThisSymbolAll();
         Print("Closed all due to stopout");
         NewOrdersPlaced = FALSE;
      }
   }

   int total = CountTrades();
   if (total == 0)
      flag = false;

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
      ShortTrade = false;
      LongTrade  = false;
      TradeNow   = true;
      StartEquity = AccountEquity();
   }

   if (TradeNow) {
      LastBuyPrice  = FindLastBuyPrice();
      LastSellPrice = FindLastSellPrice();

      if (ShortTrade) {
         NumOfTrades = total;
         double lots = NormalizeDouble(Lots.StartSize * MathPow(Lots.Multiplier, NumOfTrades), 2);
         OpenPosition(OP_SELL, lots, EAName +"-"+ NumOfTrades +"-"+ PipStep);
         LastSellPrice   = FindLastSellPrice();
         NewOrdersPlaced = true;
         TradeNow        = false;
      }
      else if (LongTrade) {
         NumOfTrades = total;
         lots = NormalizeDouble(Lots.StartSize * MathPow(Lots.Multiplier, NumOfTrades), 2);
         OpenPosition(OP_BUY, lots, EAName +"-"+ NumOfTrades +"-"+ PipStep);
         LastBuyPrice    = FindLastBuyPrice();
         NewOrdersPlaced = true;
         TradeNow        = false;
      }
   }

   if (TradeNow && total < 1) {
      if (!ShortTrade && !LongTrade) {
         NumOfTrades = total;
         lots = NormalizeDouble(Lots.StartSize * MathPow(Lots.Multiplier, NumOfTrades), 2);
         if (Close[2] > Close[1]) {
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) > RsiMinimum ) {
               OpenPosition(OP_SELL, lots, EAName +"-"+ NumOfTrades);
               LastBuyPrice    = FindLastBuyPrice();
               NewOrdersPlaced = true;
            }
         }
         else {
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) < RsiMaximum ) {
               OpenPosition(OP_BUY, lots, EAName +"-"+ NumOfTrades);
               LastSellPrice   = FindLastSellPrice();
               NewOrdersPlaced = true;
            }
         }
         TradeNow = false;
      }
   }

   total = CountTrades();
   AveragePrice = 0;
   double Count = 0;

   for (i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
         if (OrderType()==OP_BUY || OrderType()==OP_SELL) {
            AveragePrice += OrderOpenPrice() * OrderLots();
            Count += OrderLots();
         }
      }
   }
   if (total > 0)
      AveragePrice = NormalizeDouble(AveragePrice/Count, Digits);

   if (NewOrdersPlaced) {
      for (i=OrdersTotal()-1; i >= 0; i--) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
            if (OrderType() == OP_BUY) {
               PriceTarget = AveragePrice + TakeProfit * Point;
               BuyTarget = PriceTarget;
               flag = true;
            }
            if (OrderType() == OP_SELL) {
               PriceTarget = AveragePrice - TakeProfit * Point;
               SellTarget = PriceTarget;
               flag = true;
            }
         }
      }
      if (flag) {
         for (i=OrdersTotal()-1; i >= 0; i--) {
            OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
            if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
               OrderModify(OrderTicket(), NormalizeDouble(AveragePrice,Digits), NormalizeDouble(OrderStopLoss(),Digits), NormalizeDouble(PriceTarget,Digits), 0, Yellow);
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
void CloseThisSymbolAll() {
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
   double Profit = 0;
   for (int i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
         if (OrderType()==OP_BUY || OrderType()==OP_SELL)
            Profit += OrderProfit();
      }
   }
   return (Profit);
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
 * ERROR: Implementation was wrong. Did always return current AccountEquity().
 *
 * @return double - observed maximum account equity value
 */
double AccountEquityHigh() {
   static double equityHigh, lastEquityHigh;

   if (equityHigh < lastEquityHigh) equityHigh = lastEquityHigh;
   else                             equityHigh = AccountEquity();

   lastEquityHigh = AccountEquity();
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
