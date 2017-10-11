/**
 *
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////// Configuration ///////////////////////////////////////////////////////////////

extern double Lots              = 0.01;   // lot size for bidding start
extern double LotExponent       = 2;      // how much to multiply the lot when the next knee is set
extern int    lotdecimal        = 2;      // how many signs after the comma in the lot to calculate
extern int    MaxTrades         = 10;     // maximum number of simultaneously open orders

extern bool   UseTimeOut        = false;  // use a timeout (close deals if they "hang" too long)
extern double MaxTradeOpenHours = 48;     // the timeout of transactions in hours (how much to close the suspended transactions)

extern bool   DynamicPips       = true;
extern int    DefaultPips       = 12;
extern int    Glubina           = 24;
extern int    DEL               = 3;
extern double slip              = 3;      // on how much the price may differ on requotes
extern double TakeProfit        = 20;     // when many profit points are reached, close the deal
extern double Drop              = 500;
extern double RsiMinimum        = 30;     // lower bound of RSI
extern double RsiMaximum        = 70;     // upper limit of RSI
extern bool   UseEquityStop     = false;
extern double TotalEquityRisk   = 20;
extern bool   UseTrailingStop   = false;
extern int    MagicNumber       = 2222;   // magic number

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>

//extern double PipStep = 30;       // step between putting up new knees
int    PipStep=0;

double Stoploss   = 500;            // break-even level
double TrailStart =  10;
double TrailStop  =  10;

double PriceTarget, StartEquity, BuyTarget, SellTarget;
double AveragePrice, SellLimit, BuyLimit;
double LastBuyPrice, LastSellPrice;
bool   flag;
int    timeprev, expiration;
int    NumOfTrades;
double iLots;
int    total;
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
   if (DynamicPips)  {
      double hival = High[iHighest(NULL, 0, MODE_HIGH, Glubina, 1)];    // calculate highest and lowest price from last bar to 24 bars ago
      double loval = Low [ iLowest(NULL, 0, MODE_LOW,  Glubina, 1)];    // chart used for symbol and time period
      PipStep = NormalizeDouble((hival-loval)/DEL/Point, 0);            // calculate pips for spread between orders
      if (PipStep < DefaultPips/DEL) PipStep = NormalizeDouble(DefaultPips/DEL, 0);
      if (PipStep > DefaultPips*DEL) PipStep = NormalizeDouble(DefaultPips*DEL, 0); // if dynamic pips fail, assign pips extreme value
   }
   //else PipStep = DefaultPips;

   double PrevCl, CurrCl;

   if (UseTrailingStop)
      TrailingAlls(TrailStart, TrailStop, AveragePrice);

   if ((ShortTrade && iCCI(NULL, 15, 55, 0, 0) > Drop) || (LongTrade && iCCI(NULL, 15, 55, 0, 0) < -Drop)) {
      CloseThisSymbolAll();
      Print("Closed All due to TimeOut");
   }

   if (timeprev == Time[0])
      return (0);
   timeprev = Time[0];

   double CurrentPairProfit = CalculateProfit();
   if (UseEquityStop) {
      if (CurrentPairProfit < 0 && MathAbs(CurrentPairProfit) > AccountEquityHigh() * TotalEquityRisk/100) {
         CloseThisSymbolAll();
         Print("Closed All due to Stop Out");
         NewOrdersPlaced = FALSE;
      }
   }

   total = CountTrades();
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
      RefreshRates();
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
         iLots = NormalizeDouble(Lots * MathPow(LotExponent, NumOfTrades), lotdecimal);
         RefreshRates();
         ticket = OpenPendingOrder(1, iLots, Bid, slip, Ask, 0, 0, EAName +"-"+ NumOfTrades +"-"+ PipStep, MagicNumber, 0, HotPink);
         if (ticket < 0) {
            Print("Error: ", GetLastError());
            return (0);
         }
         LastSellPrice   = FindLastSellPrice();
         NewOrdersPlaced = true;
         TradeNow        = false;
      }
      else if (LongTrade) {
         NumOfTrades = total;
         iLots  = NormalizeDouble(Lots * MathPow(LotExponent, NumOfTrades), lotdecimal);
         ticket = OpenPendingOrder(0, iLots, Ask, slip, Bid, 0, 0, EAName +"-"+ NumOfTrades +"-"+ PipStep, MagicNumber, 0, Lime);
         if (ticket < 0) {
            Print("Error: ", GetLastError());
            return (0);
         }
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
         iLots = NormalizeDouble(Lots * MathPow(LotExponent, NumOfTrades), lotdecimal);
         if (PrevCl > CurrCl) {
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) > RsiMinimum ) {
               ticket = OpenPendingOrder(1, iLots, SellLimit, slip, SellLimit, 0, 0, EAName +"-"+ NumOfTrades, MagicNumber, 0, HotPink);
               if (ticket < 0) {
                  Print("Error: ", GetLastError());
                  return (0);
               }
               LastBuyPrice    = FindLastBuyPrice();
               NewOrdersPlaced = true;
            }
         }
         else {
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) < RsiMaximum ) {
               ticket = OpenPendingOrder(0, iLots, BuyLimit, slip, BuyLimit, 0, 0, EAName +"-"+ NumOfTrades, MagicNumber, 0, Lime);
               if (ticket < 0) {
                  Print("Error: ", GetLastError());
                  return (0);
               }
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
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
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
   }

   if (NewOrdersPlaced) {
      if (flag) {
         for (i=OrdersTotal()-1; i >= 0; i--) {
            OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
            if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
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
         if (OrderType() == OP_BUY)  OrderClose(OrderTicket(), OrderLots(), Bid, slip, Blue);
         if (OrderType() == OP_SELL) OrderClose(OrderTicket(), OrderLots(), Ask, slip, Red);
      }
   }
}


/**
 *
 */
int OpenPendingOrder(int pType, double pLots, double pLevel, int sp, double pr, int sl, int tp, string pComment, int pMagic, int pDatetime, color pColor) {
   int ticket, err;

   switch (pType) {
      case 2:
         ticket = OrderSend(Symbol(), OP_BUYLIMIT, pLots, pLevel, sp, StopLong(pr, sl), TakeLong(pLevel, tp), pComment, pMagic, pDatetime, pColor);
         err = GetLastError();
         if (err != NO_ERROR) Print("Error: ", err);
         break;

      case 4:
         ticket = OrderSend(Symbol(), OP_BUYSTOP, pLots, pLevel, sp, StopLong(pr, sl), TakeLong(pLevel, tp), pComment, pMagic, pDatetime, pColor);
         err = GetLastError();
         if (err != NO_ERROR) Print("Error: ", err);
         break;

      case 0:
         RefreshRates();
         ticket = OrderSend(Symbol(), OP_BUY, pLots, NormalizeDouble(Ask,Digits), sp, NormalizeDouble(StopLong(Bid, sl),Digits), NormalizeDouble(TakeLong(Ask, tp),Digits), pComment, pMagic, pDatetime, pColor);
         err = GetLastError();
         if (err != NO_ERROR) Print("Error: ", err);
         break;

      case 3:
         ticket = OrderSend(Symbol(), OP_SELLLIMIT, pLots, pLevel, sp, StopShort(pr, sl), TakeShort(pLevel, tp), pComment, pMagic, pDatetime, pColor);
         err = GetLastError();
         if (err != NO_ERROR) Print("Error: ", err);
         break;

      case 5:
         ticket = OrderSend(Symbol(), OP_SELLSTOP, pLots, pLevel, sp, StopShort(pr, sl), TakeShort(pLevel, tp), pComment, pMagic, pDatetime, pColor);
         err = GetLastError();
         if (err != NO_ERROR) Print("Error: ", err);
         break;

      case 1:
         ticket = OrderSend(Symbol(), OP_SELL, pLots, NormalizeDouble(Bid,Digits), sp, NormalizeDouble(StopShort(Ask, sl),Digits), NormalizeDouble(TakeShort(Bid, tp),Digits), pComment, pMagic, pDatetime, pColor);
         err = GetLastError();
         if (err != NO_ERROR) Print("Error: ", err);
   }
   return (ticket);
}


/**
 *
 */
double StopLong(double price, int stop) {
   if (!stop)
      return (0);
   return (price - stop * Point);
}


/**
 *
 */
double StopShort(double price, int stop) {
   if (!stop)
      return (0);
   return (price + stop * Point);
}


/**
 *
 */
double TakeLong(double price, int stop) {
   if (!stop)
      return (0);
   return (price + stop * Point);
}


/**
 *
 */
double TakeShort(double price, int stop) {
   if (!stop)
      return (0);
   return (price - stop * Point);
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
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY) {
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
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_SELL) {
         oldticketnumber = OrderTicket();
         if (oldticketnumber > ticketnumber) {
            oldorderopenprice = OrderOpenPrice();
            ticketnumber = oldticketnumber;
         }
      }
   }
   return (oldorderopenprice);
}
