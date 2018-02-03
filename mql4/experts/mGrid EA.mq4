/**
 * Math Grid EA (rewrite)
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Grid.Size              = 100;     // points
extern int    Grid.Levels            = 3;
extern double StartLots              = 0.1;
extern int    Trade.Filter.StartHour = -1;      // -1: sequence start at any time/hour
extern bool   Trade.Continue         = true;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>


// legacy vars
bool   UseProfitTarget             = false;
bool   UsePartialProfitTarget      = false;
double partialTakeProfit.Increment = 5;
double partialTakeProfit.Pip       = 2;

bool   trade.stop = false;


// grid management
double grid.startPrice;

// OrderSend() defaults
int    os.magicNumber = 1803;
double os.slippage    = 3;
string os.comment     = "";


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   double BuyGoal, BuyGoalProfit, SellGoal, SellGoalProfit, price, tp, sl, spread=(Ask-Bid)/Point;
   int error, ticket, openOrders, orders=OrdersTotal();
   grid.startPrice = 0;

   for (int i=0; i < orders; i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber) {
         if (OrderType() <= OP_SELL) {
            if (UseProfitTarget && UsePartialProfitTarget) {
               if (CheckPartialTakeProfit(OrderTicket())) {
                  orders--;
                  i--;
                  continue;
               }
            }
         }
         openOrders++;
         if (!grid.startPrice) grid.startPrice = StrToDouble(OrderComment());
      }
   }

   if (!openOrders) {
      grid.startPrice = Ask;
      os.comment      = DoubleToStr(grid.startPrice, Digits);
   }

   BuyGoal  = grid.startPrice + (Grid.Levels+1)*Grid.Size*Point;
   SellGoal = grid.startPrice - (Grid.Levels+1)*Grid.Size*Point;


   // start sequence if no open orders
   if (!openOrders) {
      if (!trade.stop && (Trade.Filter.StartHour==-1 || Trade.Filter.StartHour==Hour())) {
         tp = BuyGoal;
         sl = SellGoal - spread*Point;
         for (i=1; i <= Grid.Levels; i++) {
            price  = grid.startPrice + i*Grid.Size*Point;
            ticket = OrderSend(Symbol(), OP_BUYSTOP, StartLots, price, NULL, sl, tp, os.comment, os.magicNumber);
            error  = GetLastError();
            if (ticket < 1 || error) return(catch("onTick(1)  Tick="+ Tick +"  ticket="+ ticket +"  price="+ price +"  tp="+ tp +"  sl="+ sl +"  Bid/Ask: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat), ifInt(!error, ERR_RUNTIME_ERROR, error)));
         }
         tp = SellGoal;
         sl = BuyGoal + spread*Point;
         for (i=1; i <= Grid.Levels; i++) {
            price  = grid.startPrice - i*Grid.Size*Point;
            ticket = OrderSend(Symbol(), OP_SELLSTOP, StartLots, price, NULL, sl, tp, os.comment, os.magicNumber);
            error  = GetLastError();
            if (ticket < 1 || error) return(catch("onTick(2)  Tick="+ Tick +"  ticket="+ ticket +"  price="+ price +"  tp="+ tp +"  sl="+ sl +"  Bid/Ask: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat), ifInt(!error, ERR_RUNTIME_ERROR, error)));
         }
      }
   }


   // if open orders exist
   else {
      orders = OrdersHistoryTotal();

      for (i=0; i < orders; i++) {
         OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber && StrToDouble(OrderComment())==grid.startPrice)
            return(CloseSequence());
      }
      if (UseProfitTarget) {
         if (CheckProfit(OP_SELL, true) > 2*Grid.Size)
            return(CloseSequence());
      }

      BuyGoalProfit = CheckProfit(OP_BUY, false);
      if (BuyGoalProfit < 2*Grid.Size) {                                   // increment long lots
         for (i=Grid.Levels; i >= 1 && BuyGoalProfit < 2*Grid.Size; i--) {
            if (Ask <= (grid.startPrice + i*Grid.Size*Point)) {
               price  = grid.startPrice + i*Grid.Size*Point;
               tp     = BuyGoal;
               sl     = SellGoal - spread*Point;
               ticket = OrderSend(Symbol(), OP_BUYSTOP, i*StartLots, price, NULL, sl, tp, os.comment, os.magicNumber);
               error  = GetLastError();
               if (ticket < 1 || error) return(catch("onTick(3)  Tick="+ Tick +"  ticket="+ ticket +"  price="+ price +"  tp="+ tp +"  sl="+ sl +"  Bid/Ask: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat), ifInt(!error, ERR_RUNTIME_ERROR, error)));

               BuyGoalProfit += StartLots * (BuyGoal - grid.startPrice - i*Grid.Size*Point)/Point;
            }
         }
      }

      SellGoalProfit = CheckProfit(OP_SELL, false);
      if (SellGoalProfit < 2*Grid.Size) {                                  // increment short lots
         for (i=Grid.Levels; i >= 1 && SellGoalProfit < 2*Grid.Size; i--) {
            if (Bid >= (grid.startPrice - i*Grid.Size*Point)) {
               price  = grid.startPrice - i*Grid.Size*Point;
               tp     = SellGoal;
               sl     = BuyGoal + spread*Point;
               ticket = OrderSend(Symbol(), OP_SELLSTOP, i*StartLots, price, NULL, sl, tp, os.comment, os.magicNumber);
               error  = GetLastError();
               if (ticket < 1 || error) return(catch("onTick(4)  Tick="+ Tick +"  ticket="+ ticket +"  price="+ price +"  tp="+ tp +"  sl="+ sl +"  Bid/Ask: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat), ifInt(!error, ERR_RUNTIME_ERROR, error)));

               SellGoalProfit += StartLots * (grid.startPrice - i*Grid.Size*Point - SellGoal - spread*Point)/Point;
            }
         }
      }
   }
   return(catch("onTick(5)"));
}


/**
 *
 */
double CheckProfit(int direction, bool current) {
   double profit;
   int orders = OrdersTotal();

   if (current) {
      for (int i=0; i < orders; i++) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber && StrToDouble(OrderComment())==grid.startPrice) {
            if(OrderType()==OP_BUY)  profit += (Bid - OrderOpenPrice())/Point * OrderLots()/StartLots;
            if(OrderType()==OP_SELL) profit += (OrderOpenPrice() - Ask)/Point * OrderLots()/StartLots;
         }
      }
   }
   else if (direction == OP_LONG) {
      for (i=0; i < orders; i++) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber && StrToDouble(OrderComment())==grid.startPrice) {
            if(OrderType()==OP_BUY)     profit += (OrderTakeProfit()-OrderOpenPrice())/Point * OrderLots()/StartLots;
            if(OrderType()==OP_SELL)    profit -= (OrderStopLoss()  -OrderOpenPrice())/Point * OrderLots()/StartLots;
            if(OrderType()==OP_BUYSTOP) profit += (OrderTakeProfit()-OrderOpenPrice())/Point * OrderLots()/StartLots;
         }
      }
   }
   else if (direction == OP_SHORT) {
      for (i=0; i < orders; i++) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber && StrToDouble(OrderComment())==grid.startPrice) {
            if(OrderType()==OP_BUY)      profit -= (OrderOpenPrice()-OrderStopLoss()  )/Point * OrderLots()/StartLots;
            if(OrderType()==OP_SELL)     profit += (OrderOpenPrice()-OrderTakeProfit())/Point * OrderLots()/StartLots;
            if(OrderType()==OP_SELLSTOP) profit += (OrderOpenPrice()-OrderTakeProfit())/Point * OrderLots()/StartLots;
         }
      }
   }
   catch("CheckProfit(1)");
   return(profit);
}


/**
 *
 * @return bool - whether or not the ticket was closed
 */
bool CheckPartialTakeProfit(int ticket) {
   if    (OrderType() == OP_BUY)   double plPips = (Bid - OrderOpenPrice())/Pip;
   else /*OrderType() == OP_SELL*/        plPips = (OrderOpenPrice() - Ask)/Pip;

   if (plPips >= partialTakeProfit.Pip && plPips < partialTakeProfit.Pip + partialTakeProfit.Increment) {
      OrderClose(ticket, OrderLots(), ifDouble(OrderType()==OP_BUY, Bid, Ask), os.slippage);
      partialTakeProfit.Pip += partialTakeProfit.Increment;
      return(_true(catch("CheckPartialTakeProfit(1)")));
   }
   return(_false(catch("CheckPartialTakeProfit(2)")));
}


/**
 *
 */
int CloseSequence() {
   int orders = OrdersTotal();

   for (int i=orders-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber) {
         if (OrderType()==OP_BUY)       OrderClose(OrderTicket(), OrderLots(), Bid, os.slippage);
         else if (OrderType()==OP_SELL) OrderClose(OrderTicket(), OrderLots(), Ask, os.slippage);
         else                           OrderDelete(OrderTicket());
      }
   }
   if (!Trade.Continue)
      trade.stop = true;

   return(catch("CloseSequence(1)"));
}


/**
 * Show the current runtime status on screen.
 *
 * @param  int error [optional] - user-defined error to display (default: none)
 *
 * @return int - the same error
 */
int ShowStatus(int error=NO_ERROR) {
   if (!__CHART)
      return(error);

   Comment(NL,
           "Account Balance:  ",   AccountBalance(),                                     NL,
           "Account Profit:     ", AccountProfit(),                                      NL,
           "Account Equity:   ",   AccountEquity(),                                      NL,
           "Grid.Levels:  ",       Grid.Levels,                                          NL,
           "Grid.Size:     ",      DoubleToStr(Grid.Size*Point/Pip, Digits & 1), " pip", NL,
           "StartLots:     ",      StartLots,                                            NL);
   return(error);
}


/**
 * Return a string representation of the input parameters for logging.
 *
 * @return string
 */
string InputsToStr() {
   return("");
}
