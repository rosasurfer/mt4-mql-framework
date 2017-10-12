/**
 *
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////// Configuration ///////////////////////////////////////////////////////////////

extern double Lots.StartSize       = 0.01;   // lot size for bidding start
extern double Lots.Multiplier      = 2;      // how much to multiply the lot when the next knee is set
extern int    MaxTrades            = 10;     // maximum number of simultaneously open orders

extern int    DefaultGridSize      = 12;     // was "DefaultPips" in points
extern bool   DynamicGrid          = true;   // was "DynamicPips"
extern int    DynamicGrid.Lookback = 24;
extern int    DEL                  = 3;      // limiting grid size divisor/multiplier

extern double TakeProfit           = 20;     // when many profit points are reached, close the deal
extern double Drop                 = 500;
extern double RsiMinimum           = 30;     // lower bound of RSI
extern double RsiMaximum           = 70;     // upper limit of RSI
extern bool   UseEquityStop        = false;
extern double TotalEquityRisk      = 20;
extern bool   UseTrailingStop      = false;

extern bool   UseTimeOut           = false;  // use a timeout (close deals if they "hang" too long)
extern double MaxTradeOpenHours    = 48;     // the timeout of transactions in hours (how much to close the suspended transactions)

extern double Slippage             = 3;      // slippage in points
extern int    MagicNumber          = 2222;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>

int    PipStep;                              // grid size in points

double Stoploss   = 500;                     // break-even level
double TrailStart =  10;
double TrailStop  =  10;

double PriceTarget, StartEquity, BuyTarget, SellTarget;
double AveragePrice, SellLimit, BuyLimit;
double LastBuyPrice, LastSellPrice;
bool   flag;
int    timeprev, expiration;
int    NumOfTrades;
double Stopper;
bool   TradeNow, LongTrade, ShortTrade;
int    ticket;
bool   NewOrdersPlaced;
double AccountEquityHighAmt, PrevEquity;

string EAName = "AngryBird";


/**
 *
 */
int onTick() {
   if (DynamicGrid)  {
      double high = High[iHighest(NULL, 0, MODE_HIGH, DynamicGrid.Lookback, 1)];
      double low  = Low [ iLowest(NULL, 0, MODE_LOW,  DynamicGrid.Lookback, 1)];
      PipStep = NormalizeDouble((high-low)/DEL/Point, 0);                                    // calculate grid size
      if (PipStep < DefaultGridSize/DEL) PipStep = NormalizeDouble(DefaultGridSize/DEL, 0);
      if (PipStep > DefaultGridSize*DEL) PipStep = NormalizeDouble(DefaultGridSize*DEL, 0);  // if dynamic pips fail, assign pips extreme value
   }
   //else PipStep = DefaultGridSize;

   double PrevCl, CurrCl;

   if (UseTrailingStop)
      TrailingAlls(TrailStart, TrailStop, AveragePrice);

   if ((ShortTrade && iCCI(NULL, 15, 55, 0, 0) > Drop) || (LongTrade && iCCI(NULL, 15, 55, 0, 0) < -Drop)) {
      CloseThisSymbolAll();
      Print("Closed all due to timeout");
   }

   if (timeprev == Time[0])
      return (0);
   timeprev = Time[0];

   double CurrentPairProfit = CalculateProfit();
   if (UseEquityStop) {
      if (CurrentPairProfit < 0 && MathAbs(CurrentPairProfit) > AccountEquityHigh() * TotalEquityRisk/100) {
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
         ticket = OpenPosition(OP_SELL, lots, EAName +"-"+ NumOfTrades +"-"+ PipStep);
         LastSellPrice   = FindLastSellPrice();
         NewOrdersPlaced = true;
         TradeNow        = false;
      }
      else if (LongTrade) {
         NumOfTrades = total;
         lots  = NormalizeDouble(Lots.StartSize * MathPow(Lots.Multiplier, NumOfTrades), 2);
         ticket = OpenPosition(OP_BUY, lots, EAName +"-"+ NumOfTrades +"-"+ PipStep);
         LastBuyPrice    = FindLastBuyPrice();
         NewOrdersPlaced = true;
         TradeNow        = false;
      }
   }

   if (TradeNow && total < 1) {
      PrevCl = iClose(Symbol(), 0, 2);
      CurrCl = iClose(Symbol(), 0, 1);
      SellLimit = Bid;
      BuyLimit  = Ask;

      if (!ShortTrade && !LongTrade) {
         NumOfTrades = total;
         lots = NormalizeDouble(Lots.StartSize * MathPow(Lots.Multiplier, NumOfTrades), 2);
         if (PrevCl > CurrCl) {
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) > RsiMinimum ) {
               ticket = OpenPosition(OP_SELL, lots, EAName +"-"+ NumOfTrades);
               LastBuyPrice    = FindLastBuyPrice();
               NewOrdersPlaced = true;
            }
         }
         else {
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) < RsiMaximum ) {
               ticket = OpenPosition(OP_BUY, lots, EAName +"-"+ NumOfTrades);
               LastSellPrice   = FindLastSellPrice();
               NewOrdersPlaced = true;
            }
         }
         if (ticket > 0)
            expiration = TimeCurrent() + MaxTradeOpenHours * 60 * 60;
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
               Stopper = AveragePrice - Stoploss * Point;
               flag = true;
            }
            if (OrderType() == OP_SELL) {
               PriceTarget = AveragePrice - TakeProfit * Point;
               SellTarget = PriceTarget;
               Stopper = AveragePrice + Stoploss * Point;
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
 *
 */
void TrailingAlls(int pType, int stop, double AvgPrice) {
   int profit;
   double stoptrade;
   double stopcal;

   if (stop != 0) {
      for (int i=OrdersTotal()-1; i >= 0; i--) {
         if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderSymbol()==Symbol() || OrderMagicNumber()==MagicNumber) {
               if (OrderType() == OP_BUY) {
                  profit = NormalizeDouble((Bid - AvgPrice)/Point, 0);
                  if (profit < pType) continue;
                  stoptrade = OrderStopLoss();
                  stopcal   = Bid - stop * Point;
                  if (!stoptrade || (stoptrade && stopcal > stoptrade))
                     OrderModify(OrderTicket(), AvgPrice, stopcal, OrderTakeProfit(), 0, Aqua);
               }
               if (OrderType() == OP_SELL) {
                  profit = NormalizeDouble((AvgPrice - Ask)/Point, 0);
                  if (profit < pType) continue;
                  stoptrade = OrderStopLoss();
                  stopcal   = Ask + stop * Point;
                  if (!stoptrade || (stoptrade && stopcal < stoptrade))
                     OrderModify(OrderTicket(), AvgPrice, stopcal, OrderTakeProfit(), 0, Red);
               }
            }
         }
      }
   }
}


/**
 *
 */
double AccountEquityHigh() {
   if (AccountEquityHighAmt < PrevEquity) AccountEquityHighAmt = PrevEquity;
   else                                   AccountEquityHighAmt = AccountEquity();

   PrevEquity = AccountEquity();
   return (AccountEquityHighAmt);
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
