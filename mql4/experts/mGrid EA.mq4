/**
 * Math Grid EA
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Increment       = 35;
extern double Lots            = 0.1;
extern int    Levels          = 3;
extern double MaxLots         = 99;
extern int    Magic           = 1803;
extern bool   Continue        = true;
extern bool   Moneymanagement = false;
extern int    RiskRatio       = 2;

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


/**
 * Initialization pre-processing hook.
 *
 * @return int - error status; in case of errors reason-specific event handlers are not executed
 */
int onInit() {
   nextTP = First_Target;
   return(NO_ERROR);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   int ticket, profit, total, BuyGoalProfit, SellGoalProfit, PipsLot;
   double InitialPrice, BuyGoal, SellGoal, spread=(Ask-Bid)/Point, ProfitTarget = 2 * Increment;

   if (Increment < MarketInfo(Symbol(), MODE_STOPLEVEL) + spread)
      Increment = 1 + MarketInfo(Symbol(), MODE_STOPLEVEL) + spread;

   if (Moneymanagement)
      Lots = NormalizeDouble(AccountBalance()*AccountLeverage()/1000000 * RiskRatio, 0) * MarketInfo(Symbol(), MODE_MINLOT);

   if (Lots < MarketInfo(Symbol(),MODE_MINLOT)) {
      Comment("Not Enough Free Margin to begin");
      return(0);
   }

   for (int cpt=1; cpt < Levels; cpt++) {
      PipsLot += cpt * Increment;
   }

   for (cpt=0; cpt < OrdersTotal(); cpt++) {
      OrderSelect(cpt, SELECT_BY_POS, MODE_TRADES);
      if (OrderMagicNumber()==Magic && OrderSymbol()==Symbol()) {
         total++;
         if (!InitialPrice) InitialPrice = StrToDouble(OrderComment());

         if (UsePartialProfitTarget && UseProfitTarget && OrderType() < 2) {
            double val = getPipValue(OrderOpenPrice(), OrderType());
            takeProfit(val, OrderTicket());
         }
      }
   }

   if (total<1 && Enter && (!UseEntryTime || (UseEntryTime && Hour()==EntryTime))) {
      if (AccountFreeMargin() < 100 * Lots) {
         Print("Not enough free margin to begin");
         return(0);
      }

      // Open Check - Start Cycle
      InitialPrice = Ask;
      SellGoal = InitialPrice - (Levels+1)*Increment*Point;
      BuyGoal  = InitialPrice + (Levels+1)*Increment*Point;

      for (cpt=1; cpt <= Levels; cpt++) {
         OrderSend(Symbol(), OP_BUYSTOP,  Lots, InitialPrice + cpt*Increment*Point, 2, SellGoal,               BuyGoal,                 DoubleToStr(InitialPrice, Digits), Magic, 0);
         OrderSend(Symbol(), OP_SELLSTOP, Lots, InitialPrice - cpt*Increment*Point, 2, BuyGoal + spread*Point, SellGoal + spread*Point, DoubleToStr(InitialPrice, Digits), Magic, 0);
      }
   }
   else {
      // We have open Orders
      BuyGoal  = InitialPrice + Increment*(Levels+1)*Point;
      SellGoal = InitialPrice - Increment*(Levels+1)*Point;
      total = OrdersHistoryTotal();

      for (cpt=0; cpt < total; cpt++) {
         OrderSelect(cpt, SELECT_BY_POS, MODE_HISTORY);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && StrToDouble(OrderComment())==InitialPrice) {
            EndSession();
            return(0);
         }
      }

      if (UseProfitTarget && CheckProfits(Lots, OP_SELL, true, InitialPrice) > ProfitTarget) {
         EndSession();
         return(0);
      }

      BuyGoalProfit  = CheckProfits(Lots, OP_BUY, false, InitialPrice);
      SellGoalProfit = CheckProfits(Lots, OP_SELL, false, InitialPrice);

      if (BuyGoalProfit < ProfitTarget) {
         // Incriment Lots Buy
         for (cpt=Levels; cpt >= 1 && BuyGoalProfit < ProfitTarget; cpt--) {
            if (Ask <= (InitialPrice + (cpt*Increment - MarketInfo(Symbol(), MODE_STOPLEVEL))*Point)) {
               ticket = OrderSend(Symbol(), OP_BUYSTOP, cpt*Lots, InitialPrice + cpt*Increment*Point, 2, SellGoal, BuyGoal, DoubleToStr(InitialPrice, Digits), Magic, 0);
            }
            if (ticket > 0) BuyGoalProfit += Lots * (BuyGoal - InitialPrice - cpt*Increment*Point)/Point;
         }
      }

      if (SellGoalProfit<ProfitTarget) {
         // Increment Lots Sell
         for (cpt=Levels; cpt >= 1 && SellGoalProfit < ProfitTarget; cpt--) {
            if (Bid >= (InitialPrice - (cpt*Increment - MarketInfo(Symbol(),MODE_STOPLEVEL))*Point)) {
               ticket = OrderSend(Symbol(), OP_SELLSTOP, cpt*Lots, InitialPrice - cpt*Increment*Point, 2, BuyGoal+spread*Point, SellGoal+spread*Point, DoubleToStr(InitialPrice, Digits), Magic, 0);
            }
            if (ticket > 0) SellGoalProfit += Lots * (InitialPrice - cpt*Increment*Point - SellGoal - spread*Point)/Point;
         }
      }
   }

   Comment("mGRID EXPERT ADVISOR ver 2.0\n",
           "Account Balance:  ", AccountBalance(), "\n",
           "Increment=", Increment, "\n",
           "Lots:  ", Lots, "\n",
           "Levels: ", Levels, "\n");
   return(0);
}


/**
 *
 */
int CheckProfits(double lots, int Goal, bool Current, double InitialPrice) {
   int profit;

   if (Current) {
      //return current profit
      for (int cpt=0; cpt < OrdersTotal(); cpt++) {
         OrderSelect(cpt, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && StrToDouble(OrderComment())==InitialPrice) {
            if(OrderType()==OP_BUY)  profit += (Bid - OrderOpenPrice())/Point * OrderLots()/lots;
            if(OrderType()==OP_SELL) profit += (OrderOpenPrice() - Ask)/Point * OrderLots()/lots;
         }
      }
      return(profit);
   }
   else {
      if (Goal == OP_BUY) {
         for (cpt=0; cpt < OrdersTotal(); cpt++) {
            OrderSelect(cpt, SELECT_BY_POS, MODE_TRADES);
            if (OrderSymbol()==Symbol() && StrToDouble(OrderComment())==InitialPrice) {
               if(OrderType()==OP_BUY)     profit += (OrderTakeProfit()-OrderOpenPrice())/Point * OrderLots()/lots;
               if(OrderType()==OP_SELL)    profit -= (OrderStopLoss()  -OrderOpenPrice())/Point * OrderLots()/lots;
               if(OrderType()==OP_BUYSTOP) profit += (OrderTakeProfit()-OrderOpenPrice())/Point * OrderLots()/lots;
            }
         }
         return(profit);
      }
      else {
         for (cpt=0; cpt < OrdersTotal(); cpt++) {
            OrderSelect(cpt, SELECT_BY_POS, MODE_TRADES);
            if (OrderSymbol()==Symbol() && StrToDouble(OrderComment())==InitialPrice) {
               if(OrderType()==OP_BUY)      profit -= (OrderOpenPrice()-OrderStopLoss()  )/Point * OrderLots()/lots;
               if(OrderType()==OP_SELL)     profit += (OrderOpenPrice()-OrderTakeProfit())/Point * OrderLots()/lots;
               if(OrderType()==OP_SELLSTOP) profit += (OrderOpenPrice()-OrderTakeProfit())/Point * OrderLots()/lots;
            }
         }
         return(profit);
      }
   }
}


/**
 *
 */
bool EndSession() {
   int total = OrdersTotal();

   for (int cpt=0; cpt < total; cpt++) {
      OrderSelect(cpt, SELECT_BY_POS, MODE_TRADES);
      if      (OrderSymbol()==Symbol() && OrderType() > 1)      OrderDelete(OrderTicket());
      else if (OrderSymbol()==Symbol() && OrderType()==OP_BUY)  OrderClose(OrderTicket(), OrderLots(), Bid, 3);
      else if (OrderSymbol()==Symbol() && OrderType()==OP_SELL) OrderClose(OrderTicket(), OrderLots(), Ask, 3);

   }
   if (!Continue)
      Enter = false;
   return(true);
}


/**
 *
 */
double getPipValue(double ord, int dir) {
   double val;
   if (dir == 1) val = NormalizeDouble(ord, Digits) - NormalizeDouble(Ask, Digits);
   else          val = NormalizeDouble(Bid, Digits) - NormalizeDouble(ord, Digits);
   return(val/Point);
}


/**
 *
 */
void takeProfit(int current_pips, int ticket) {
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
      if (current_pips >= nextTP && current_pips < nextTP+Target_Increment) {
         if (OrderType() == 1) {
            if (OrderClose(ticket, MaxLots, Ask, 3)) nextTP += Target_Increment;
            else Print("Error closing order : ", GetLastError());
         }
         else {
            if (OrderClose(ticket, MaxLots, Bid, 3)) nextTP += Target_Increment;
            else Print("Error closing order : ", GetLastError());
         }
      }
   }
}
