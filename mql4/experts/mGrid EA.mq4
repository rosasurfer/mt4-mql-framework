/**
 * Math Grid EA
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Grid.Size   = 35;     // points
extern int    Grid.Levels = 3;
extern double StartLots   = 0.1;
extern bool   Continue    = true;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>


bool UseProfitTarget;
bool UsePartialProfitTarget;
int  Target_Increment = 50;
int  First_Target     = 20;
bool UseEntryTime;
int  EntryTime;
bool Enter = true;
int  nextTP;

// OrderSend() defaults
int    os.magicNumber = 1803;
double os.slippage    = 3;


/**
 * Initialization pre-processing hook.
 *
 * @return int - error status; in case of errors reason-specific event handlers are not executed
 */
int onInit() {
   nextTP = First_Target;
   return(last_error);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   double InitialPrice, BuyGoal, BuyGoalProfit, SellGoal, SellGoalProfit, spread=(Ask-Bid)/Point, profitTarget = 2 * Grid.Size;

   if (Grid.Size < spread)
      Grid.Size = spread + 1;

   int openOrders, orders = OrdersTotal();

   for (int i=0; i < orders; i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber) {
         openOrders++;
         if (!InitialPrice) InitialPrice = StrToDouble(OrderComment());

         if (OrderType() <= OP_SELL) {
            if (UsePartialProfitTarget && UseProfitTarget) {
               CheckTakeProfit(OrderTicket());
            }
         }
      }
   }

   if (!openOrders && Enter && (!UseEntryTime || (UseEntryTime && Hour()==EntryTime))) {
      // Open Check - Start Cycle
      InitialPrice = Ask;
      SellGoal = InitialPrice - (Grid.Levels+1)*Grid.Size*Point;
      BuyGoal  = InitialPrice + (Grid.Levels+1)*Grid.Size*Point;

      for (i=1; i <= Grid.Levels; i++) {
         OrderSend(Symbol(), OP_BUYSTOP,  StartLots, InitialPrice + i*Grid.Size*Point, NULL, SellGoal,               BuyGoal,                 DoubleToStr(InitialPrice, Digits), os.magicNumber, 0);
         OrderSend(Symbol(), OP_SELLSTOP, StartLots, InitialPrice - i*Grid.Size*Point, NULL, BuyGoal + spread*Point, SellGoal + spread*Point, DoubleToStr(InitialPrice, Digits), os.magicNumber, 0);
      }
   }
   else {
      // We have open Orders
      BuyGoal  = InitialPrice + Grid.Size*(Grid.Levels+1)*Point;
      SellGoal = InitialPrice - Grid.Size*(Grid.Levels+1)*Point;
      orders = OrdersHistoryTotal();

      for (i=0; i < orders; i++) {
         OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber && StrToDouble(OrderComment())==InitialPrice)
            return(CloseSequence());
      }
      if (UseProfitTarget && CheckProfit(OP_SELL, true, InitialPrice) > profitTarget)
         return(CloseSequence());

      BuyGoalProfit = CheckProfit(OP_BUY, false, InitialPrice);
      if (BuyGoalProfit < profitTarget) {                            // increment long lots
         for (i=Grid.Levels; i >= 1 && BuyGoalProfit < profitTarget; i--) {
            if (Ask <= (InitialPrice + i*Grid.Size*Point)) {
               OrderSend(Symbol(), OP_BUYSTOP, i*StartLots, InitialPrice + i*Grid.Size*Point, NULL, SellGoal, BuyGoal, DoubleToStr(InitialPrice, Digits), os.magicNumber, 0);
               BuyGoalProfit += StartLots * (BuyGoal - InitialPrice - i*Grid.Size*Point)/Point;
            }
         }
      }

      SellGoalProfit = CheckProfit(OP_SELL, false, InitialPrice);
      if (SellGoalProfit < profitTarget) {                           // increment short lots
         for (i=Grid.Levels; i >= 1 && SellGoalProfit < profitTarget; i--) {
            if (Bid >= (InitialPrice - i*Grid.Size*Point)) {
               OrderSend(Symbol(), OP_SELLSTOP, i*StartLots, InitialPrice - i*Grid.Size*Point, NULL, BuyGoal+spread*Point, SellGoal+spread*Point, DoubleToStr(InitialPrice, Digits), os.magicNumber, 0);
               SellGoalProfit += StartLots * (InitialPrice - i*Grid.Size*Point - SellGoal - spread*Point)/Point;
            }
         }
      }
   }

   Comment("Account Balance:  ", AccountBalance(), "\n",
           "Grid.Levels: ", Grid.Levels, "\n",
           "Grid.Size=", Grid.Size, " point\n",
           "StartLots:  ", StartLots, "\n");
   return(last_error);
}


/**
 *
 */
double CheckProfit(int Goal, bool Current, double InitialPrice) {
   double profit;
   int orders = OrdersTotal();

   if (Current) {
      for (int i=0; i < orders; i++) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber && StrToDouble(OrderComment())==InitialPrice) {
            if(OrderType()==OP_BUY)  profit += (Bid - OrderOpenPrice())/Point * OrderLots()/StartLots;
            if(OrderType()==OP_SELL) profit += (OrderOpenPrice() - Ask)/Point * OrderLots()/StartLots;
         }
      }
   }
   else if (Goal == OP_BUY) {
      for (i=0; i < orders; i++) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber && StrToDouble(OrderComment())==InitialPrice) {
            if(OrderType()==OP_BUY)     profit += (OrderTakeProfit()-OrderOpenPrice())/Point * OrderLots()/StartLots;
            if(OrderType()==OP_SELL)    profit -= (OrderStopLoss()  -OrderOpenPrice())/Point * OrderLots()/StartLots;
            if(OrderType()==OP_BUYSTOP) profit += (OrderTakeProfit()-OrderOpenPrice())/Point * OrderLots()/StartLots;
         }
      }
   }
   else {
      for (i=0; i < orders; i++) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber && StrToDouble(OrderComment())==InitialPrice) {
            if(OrderType()==OP_BUY)      profit -= (OrderOpenPrice()-OrderStopLoss()  )/Point * OrderLots()/StartLots;
            if(OrderType()==OP_SELL)     profit += (OrderOpenPrice()-OrderTakeProfit())/Point * OrderLots()/StartLots;
            if(OrderType()==OP_SELLSTOP) profit += (OrderOpenPrice()-OrderTakeProfit())/Point * OrderLots()/StartLots;
         }
      }
   }
   return(profit);
}


/**
 *
 */
void CheckTakeProfit(int ticket) {
   if    (OrderType() == OP_BUY)   double plPoints = (Bid - OrderOpenPrice())/Point;
   else /*OrderType() == OP_SELL*/        plPoints = (OrderOpenPrice() - Ask)/Point;

   if (plPoints >= nextTP && plPoints < nextTP+Target_Increment) {
      if (   OrderType() == OP_BUY)   OrderClose(ticket, OrderLots(), Bid, os.slippage);
      else /*OrderType() == OP_SELL*/ OrderClose(ticket, OrderLots(), Ask, os.slippage);
      nextTP += Target_Increment;
   }
}


/**
 *
 */
int CloseSequence() {
   int orders = OrdersTotal();

   for (int i=0; i < orders; i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber) {
         if      (OrderType()==OP_BUY)  OrderClose(OrderTicket(), OrderLots(), Bid, os.slippage);
         else if (OrderType()==OP_SELL) OrderClose(OrderTicket(), OrderLots(), Ask, os.slippage);
         else                           OrderDelete(OrderTicket());
      }
   }
   if (!Continue)
      Enter = false;
   return(last_error);
}
