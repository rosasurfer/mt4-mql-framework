/**
 * The Trap - straddle trading with a twist
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_PIPVALUE};
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Grid.Range                      = 15;   // in pip
extern int    Grid.Levels                     = 3;
extern double StartLots                       = 0.1;
extern double StartPrice                      = 0;    // manually enforced midrange price of the next sequence
extern int    Trade.StartHour                 = -1;   // hour to start sequences             (-1: any hour)
extern int    Trade.EndHour                   = -1;   // hour to stop starting new sequences (-1: no hour)
extern int    Trade.Sequences                 = 1;    // number of sequences to trade        (-1: no limit)

extern string _____________________________1_ = "";
extern int    Tester.MinSlippage.Points       = 0;    // Tester: minimum slippage applied to entry orders
extern int    Tester.MaxSlippage.Points       = 0;    // Tester: maximum slippage applied to entry orders

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/xtrade/OrderExecution.mqh>

// order status
#define ORDER_PENDING         0
#define ORDER_OPEN            1
#define ORDER_CLOSED         -1

// grid and sequence management
int    sequence.orders;                         // total number of currently open orders        (zero or positive)
double sequence.position;                       // current total position in lots: long + short (positive or negative)
double sequence.pl;                             // current PL in account currency
double sequence.plMin;                          // minimum PL in account currency
double sequence.plMax;                          // maximum PL in account currency

double grid.size;                               // in pip
double grid.startPrice;
int    grid.firstSet.units;                     // total number of units of the initial order set
int    grid.addedSet.units;                     // total number of units of one additional order set
double grid.unitValue;                          // value of 1 unit in account currency

int    lastLevel.filled;                        // the last level filled in either direction        (positive or negative)
int    lastLevel.plUnits;                       // total PL in units at the last level filled       (positive = profitable)

double closed.grossProfit;                      // realized gross profit in account currency        (positive or negative)
double closed.netProfit;                        // realized net profit in account currency          (positive or negative)
double closed.commission;                       // realized commission in account currency          (positive or negative)
double open.swap;                               // open swap in account currency                    (positive or negative)
double closed.swap;                             // realized swap in account currency                (positive or negative)
double open.slippage;                           // open slippage in account currency                (positive or negative)
double closed.slippage;                         // closed slippage in account currency              (positive or negative)

// order management
int    long.orders.ticket    [];                // order tickets
int    long.orders.level     [];                // order grid level                                 (positive)
double long.orders.levelPrice[];                // order level price (raw unrounded value)
double long.orders.lots      [];                // order lot sizes                                  (positive)
double long.orders.openPrice [];                // order open prices (pending or effective)
double long.orders.slipValue [];                // value of slippage occurred in account currency   (negative = in favor of the client)
int    long.orders.status    [];                // whether the order is pending, open or closed
int    long.units.current    [];                // the current distribution of long units to add    (positive)
double long.position;                           // currently open long position in lots             (zero or positive)
double long.tpPrice;                            // long TakeProfit price
int    long.tpUnits;                            // profit in units at TakeProfit incl. realized     (positive = profitable)
double long.tpOrderSize;                        // pending and open lots in direction of TakeProfit (positive)
double long.tpCompensation  = EMPTY_VALUE;      // TakeProfit compensation for trading costs in pip (positive = widened range)

int    short.orders.ticket    [];               // order tickets
int    short.orders.level     [];               // order grid level                                 (positive)
double short.orders.levelPrice[];               // order level price (raw unrounded value)
double short.orders.lots      [];               // order lot sizes                                  (positive)
double short.orders.openPrice [];               // order open prices (pending or effective)
double short.orders.slipValue [];               // value of slippage occurred in account currency   (negative = in favor of the client)
int    short.orders.status    [];               // whether the order is pending, open or closed
int    short.units.current    [];               // the current distribution of short units to add   (positive)
double short.position;                          // currently open short position in lots            (zero or negative)
double short.tpPrice;                           // short TakeProfit price
int    short.tpUnits;                           // profit in units at TakeProfit incl. realized     (positive = profitable)
double short.tpOrderSize;                       // pending and open lots in direction of TakeProfit (negative)
double short.tpCompensation = EMPTY_VALUE;      // TakeProfit compensation for trading costs in pip (positive = widened range)

// trade function defaults
int    os.magicNumber = 1803;
double os.slippage    = 0.1;                    // in pip
string os.comment     = "";

// cache variables to speed-up toString operations
string str.range.tpCompensation = "";           // e.g.: "+0.7/-0.6"
string str.long.units.swing     = "";           // the current swing's full distribution of units to add, e.g.: "0  1  1  1"
string str.short.units.swing    = "";           // the current swing's full distribution of units to add, e.g.: "0  2  4  3"


double commissionRate = EMPTY_VALUE;            // commission rate per lot in account currency (zero or positive)
int    test.startTime;                          // development


#include <The Trap/setter.mqh>


/**
 * Initialization.
 *
 * @return int - error status
 */
int onInit() {
   if (LT(StartPrice, 0))                                     return(catch("onInit(1)  Invalid input parameter StartPrice: "+ NumberToStr(StartPrice, ".+"), ERR_INVALID_INPUT_PARAMETER));
   if (Tester.MinSlippage.Points > Tester.MaxSlippage.Points) return(catch("onInit(2)  Input parameters mis-match: Tester.MinSlippage="+ Tester.MinSlippage.Points +"/Tester.MaxSlippage="+ Tester.MaxSlippage.Points +" (MinSlippage cannot exceed MaxSlippage)" , ERR_INVALID_INPUT_PARAMETER));

   grid.size           = Grid.Range  / (Grid.Levels+1.);
   grid.firstSet.units = Grid.Levels * (Grid.Levels+1)/2;
   grid.addedSet.units = 0;

   for (int i=Grid.Levels; i > 0; i-=2) {
      grid.addedSet.units += i*i;
   }
   return(catch("onInit(3)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   int endTime = GetTickCount();
   if (IsTesting()/* && !IsVisualMode()*/) debug("onDeinit(1)  test time: "+ DoubleToStr((endTime-test.startTime)/1000., 3) +" sec");

   // clean-up chart objects
   int uninitReason = UninitializeReason();
   if (uninitReason!=UR_CHARTCHANGE && uninitReason!=UR_PARAMETERS) {
      if (!IsTesting()) DeleteRegisteredObjects(NULL);
   }
   return(last_error);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (IsTesting()) /*&&*/ if (!test.startTime)
      test.startTime = GetTickCount();

   // start a new sequence if no orders exist
   if (!sequence.orders) {
      if (Trade.Sequences != 0) {
         if (Trade.EndHour == -1)
            Trade.EndHour = 24;

         // apply start and end hour restrictions
         if (Hour() >= Trade.StartHour && Hour() < Trade.EndHour) {
            grid.startPrice = NormalizeDouble(ifDouble(StartPrice, StartPrice, (Bid + Ask)/2), Digits);
            grid.unitValue  = grid.size * PipValue(StartLots); if (__STATUS_OFF) return(last_error);
            long.tpPrice    = NormalizeDouble(grid.startPrice + Grid.Range*Pip, Digits);
            short.tpPrice   = NormalizeDouble(grid.startPrice - Grid.Range*Pip, Digits);
            os.comment      = "Trap: "+ NumberToStr(grid.startPrice, PriceFormat) +", "+ Grid.Range +"p";
            ArrayResize(long.units.current,  Grid.Levels + 1);
            ArrayResize(short.units.current, Grid.Levels + 1);

            for (int i=1; i <= Grid.Levels; i++) {
               double levelPrice = grid.startPrice + i*grid.size*Pip;
               if (!AddOrder(OP_LONG, NULL, i, levelPrice, StartLots, levelPrice, long.tpPrice, short.tpPrice, NULL, ORDER_PENDING))  return(last_error);
            }
            for (i=1; i <= Grid.Levels; i++) {
               levelPrice = grid.startPrice - i*grid.size*Pip;
               if (!AddOrder(OP_SHORT, NULL, i, levelPrice, StartLots, levelPrice, short.tpPrice, long.tpPrice, NULL, ORDER_PENDING)) return(last_error);
            }
            debug("onTick(1)  new sequence at "+ NumberToStr(grid.startPrice, PriceFormat) +"  range=2*"+ Grid.Range +" pip, target="+ long.tpUnits +" units, 1 unit="+ DoubleToStr(grid.unitValue, 2));
         }
      }

      if (!Trade.Sequences)
         return(SetLastError(ERR_CANCELLED_BY_USER));
      return(catch("onTick(2)"));
   }

   // update existing orders
   bool ordersFilled = UpdateOrders();
   if (ordersFilled)
      RebalanceGrid();

   return(catch("onTick(3)"));
}


/**
 * Update the existing order's status. Automatically resolves opposite open positions.
 *
 * @return bool - whether or not pending orders have been executed
 */
bool UpdateOrders() {
   if (__STATUS_OFF) return(false);

   int    longOrder  = -1, longSize  = ArraySize(long.orders.ticket), levels, units, plMidLevel;
   int    shortOrder = -1, shortSize = ArraySize(short.orders.ticket), oe[ORDER_EXECUTION.intSize];
   bool   long.stopsFilled, short.stopsFilled;
   double levelPrice, stopPrice, openPrice, profit, swap, slippage, slipValue, closedLots, closedPart;
   string slipMsg = "";


   // (1) check for pending order fills and order closes (presumably TakeProfit)
   for (int i=0; i < longSize; i++) {
      OrderSelect(long.orders.ticket[i], SELECT_BY_TICKET);
      if (!OrderCloseTime()) {
         if (long.orders.status[i] == ORDER_PENDING) {
            if (OrderType() == OP_BUY) {
               units = Round(sequence.position/StartLots);                    // lot units before crossing of this level

               if (lastLevel.filled <= 0) {
                  levels     = -lastLevel.filled;                             // levels between lastLevel.filled and midlevel (zero)
                  plMidLevel = lastLevel.plUnits + levels * units;            // plUnits at the mid level (zero)
                  debug("UpdateOrders(1)   long  swing, @0: pl="+ plMidLevel +"  pos="+ units +"  orders="+ str.long.units.swing +"  target="+ long.tpUnits);
               }

               levels            = long.orders.level[i] - lastLevel.filled;   // levels between lastLevel.filled and the current level
               lastLevel.plUnits = lastLevel.plUnits + levels * units;        // plUnits at the current level
               lastLevel.filled  = long.orders.level[i];                      // the current level

               long.position     = NormalizeDouble(long.position + long.orders.lots[i], 2);
               sequence.position = NormalizeDouble(long.position + short.position, 2);
               levels            = (Grid.Levels+1) + long.orders.level[i];
               short.tpUnits    -= MathRound(levels * long.orders.lots[i]/StartLots);

               long.units.current[long.orders.level[i]] -= MathRound(long.orders.lots[i]/StartLots);

               levelPrice = long.orders.levelPrice[i];
               stopPrice  = long.orders.openPrice [i];
               openPrice  = OrderOpenPrice();
               slipValue  = 0;
               slipMsg    = "";

               if (NE(levelPrice, openPrice)) {
                  slippage       = (openPrice-levelPrice)/Pip;
                  slipValue      = -slippage * PipValue(long.orders.lots[i]); if (__STATUS_OFF) return(false);
                  open.slippage += slipValue;
                  //slipMsg = ", slipValue = "+ DoubleToStr(slipValue, 2);
               }
               if (NE(stopPrice, openPrice)) {
                  slippage = (openPrice-stopPrice)/Pip;
                  slipMsg  = " instead of "+ NumberToStr(stopPrice, PriceFormat) +" ("+ DoubleToStr(MathAbs(slippage), Digits & 1) +" pip "+ ifString(LT(openPrice, stopPrice), "positive ", "") +"slippage = "+ DoubleToStr(slipValue, 2) +")";
               }
               //debug("UpdateOrders(2)   long  level "+ long.orders.level[i] +" filled at "+ NumberToStr(openPrice, PriceFormat) + slipMsg);

               long.orders.openPrice[i] = openPrice;
               long.orders.slipValue[i] = slipValue;
               long.orders.status   [i] = ORDER_OPEN;
               long.stopsFilled         = true;
            }
         }
         if (long.orders.status[i] == ORDER_OPEN) {
            profit += OrderProfit() + OrderCommission() + OrderSwap();
            swap   += OrderSwap();
         }
      }
      else {
         if (OrderType()==OP_BUYSTOP) /*&&*/ if (OrderComment()=="deleted [no money]") {
            LogTicket(OrderTicket());
            catch("UpdateOrders(3)  #"+ OrderTicket() +" pending order was deleted", ERR_NOT_ENOUGH_MONEY);
         }
         return(_false(CloseSequence()));                                     // close all if one was closed/deleted
      }
   }

   for (i=0; i < shortSize; i++) {
      OrderSelect(short.orders.ticket[i], SELECT_BY_TICKET);
      if (!OrderCloseTime()) {
         if (short.orders.status[i] == ORDER_PENDING) {
            if (OrderType() == OP_SELL) {
               units = Round(sequence.position/StartLots);                    // lot units before crossing of this level

               if (lastLevel.filled >= 0) {
                  levels     = lastLevel.filled;                              // levels between lastLevel.filled and midlevel (zero)
                  plMidLevel = lastLevel.plUnits - levels * units;            // plUnits at the mid level (zero)
                  debug("UpdateOrders(4)   short swing, @0: pl="+ plMidLevel +"  pos="+ units +"  orders="+ str.short.units.swing +"  target="+ short.tpUnits);
               }

               levels            = lastLevel.filled + short.orders.level[i];  // levels between lastLevel.filled and the current level
               lastLevel.plUnits = lastLevel.plUnits - levels * units;        // plUnits at the current level
               lastLevel.filled  = -short.orders.level[i];                    // the current level

               short.position    = NormalizeDouble(short.position - short.orders.lots[i], 2);
               sequence.position = NormalizeDouble(long.position + short.position, 2);
               levels            = (Grid.Levels+1) + short.orders.level[i];
               long.tpUnits     -= MathRound(levels * short.orders.lots[i]/StartLots);

               short.units.current[short.orders.level[i]] -= MathRound(short.orders.lots[i]/StartLots);

               levelPrice = short.orders.levelPrice[i];
               stopPrice  = short.orders.openPrice [i];
               openPrice  = OrderOpenPrice();
               slipValue  = 0;
               slipMsg    = "";

               if (NE(levelPrice, openPrice)) {
                  slippage       = (levelPrice-openPrice)/Pip;
                  slipValue      = -slippage * PipValue(short.orders.lots[i]); if (__STATUS_OFF) return(false);
                  open.slippage += slipValue;
                  //slipMsg = ", slipValue = "+ DoubleToStr(slipValue, 2);
               }
               if (NE(stopPrice, openPrice)) {
                  slippage = (stopPrice-openPrice)/Pip;
                  slipMsg  = " instead of "+ NumberToStr(stopPrice, PriceFormat) +" ("+ DoubleToStr(MathAbs(slippage), Digits & 1) +" pip "+ ifString(GT(openPrice, stopPrice), "positive ", "") +"slippage = "+ DoubleToStr(slipValue, 2) +")";
               }
               //debug("UpdateOrders(5)   short level "+ (-short.orders.level[i]) +" filled at "+ NumberToStr(openPrice, PriceFormat) + slipMsg);

               short.orders.openPrice[i] = openPrice;
               short.orders.slipValue[i] = slipValue;
               short.orders.status   [i] = ORDER_OPEN;
               short.stopsFilled         = true;
            }
         }
         if (short.orders.status[i] == ORDER_OPEN) {
            profit += OrderProfit() + OrderCommission() + OrderSwap();
            swap   += OrderSwap();
         }
      }
      else {
         if (OrderType()==OP_SELLSTOP) /*&&*/ if (OrderComment()=="deleted [no money]") {
            LogTicket(OrderTicket());
            catch("UpdateOrders(6)  #"+ OrderTicket() +" pending order was deleted", ERR_NOT_ENOUGH_MONEY);
         }
         return(_false(CloseSequence()));                                     // close all if one was closed/deleted
      }
   }


   // (2) close opposite positions
   while (long.position && short.position) {
      for (i=0; i < longSize; i++) {                                       // next long order to close
         if (long.orders.status[i] == ORDER_OPEN)  { longOrder = i; break; }
      }
      for (i=0; i < shortSize; i++) {                                      // next short order to close
         if (short.orders.status[i] == ORDER_OPEN) { shortOrder = i; break; }
      }
                                                                           // close opposite positions
      //debug("UpdateOrders(7)  closing "+ DoubleToStr(long.orders.lots[longOrder], 1) +" long (level "+ long.orders.level[longOrder] +") by "+ DoubleToStr(short.orders.lots[shortOrder], 1) +" short (level "+ short.orders.level[shortOrder] +")");
      if (!OrderCloseByEx(long.orders.ticket[longOrder], short.orders.ticket[shortOrder], Orange, NULL, oe))
         return(false);
      //ORDER_EXECUTION.toStr(oe, true);

      closed.grossProfit += oe.Profit    (oe);                             // store realized amounts
      closed.commission  += oe.Commission(oe);
      open.swap          -= oe.Swap      (oe);
      closed.swap        += oe.Swap      (oe);
      closed.netProfit    = closed.grossProfit + closed.commission + closed.swap;
      //debug("UpdateOrders(8)  close by: profit="+ DoubleToStr(oe.Profit(oe), 2) +", commission="+ DoubleToStr(oe.Commission(oe), 2) +", swap="+ DoubleToStr(oe.Swap(oe), 2));
      //debug("UpdateOrders(9)  closed.grossProfit="+ DoubleToStr(closed.grossProfit, 2) +"  closed.costs="+ DoubleToStr(closed.commission + closed.swap, 2));

      closedLots         = MathMin(long.orders.lots[longOrder], short.orders.lots[shortOrder]);
      long.position      = NormalizeDouble(long.position  - closedLots, 2);
      short.position     = NormalizeDouble(short.position + closedLots, 2);
      long.tpOrderSize  -= closedLots;
      short.tpOrderSize += closedLots;

      int ticket = oe.RemainingTicket(oe);
      if (!ticket) {                                                       // no remaining position
         open.slippage   -= long.orders.slipValue[longOrder] + short.orders.slipValue[shortOrder];
         closed.slippage += long.orders.slipValue[longOrder] + short.orders.slipValue[shortOrder];

         ArraySpliceInts   (long.orders.ticket,      longOrder, 1);
         ArraySpliceInts   (long.orders.level,       longOrder, 1);        // drop long ticket
         ArraySpliceDoubles(long.orders.levelPrice,  longOrder, 1);
         ArraySpliceDoubles(long.orders.lots,        longOrder, 1);
         ArraySpliceDoubles(long.orders.openPrice,   longOrder, 1);
         ArraySpliceDoubles(long.orders.slipValue,   longOrder, 1);
         ArraySpliceInts   (long.orders.status,      longOrder, 1);
         longSize--;
         sequence.orders--;

         ArraySpliceInts   (short.orders.ticket,     shortOrder, 1);       // drop short ticket
         ArraySpliceInts   (short.orders.level,      shortOrder, 1);
         ArraySpliceDoubles(short.orders.levelPrice, shortOrder, 1);
         ArraySpliceDoubles(short.orders.lots,       shortOrder, 1);
         ArraySpliceDoubles(short.orders.openPrice,  shortOrder, 1);
         ArraySpliceDoubles(short.orders.slipValue,  shortOrder, 1);
         ArraySpliceInts   (short.orders.status,     shortOrder, 1);
         shortSize--;
         sequence.orders--;
      }
      else if (OrderSelect(ticket, SELECT_BY_TICKET)) {
         //debug("UpdateOrders(10)  remaining ticket:");
         //LogOrder(ticket);

         if (OrderType() == OP_BUY) {                                      // remaining long position
            closedPart       = closedLots / long.orders.lots     [longOrder];
            open.slippage   -= closedPart * long.orders.slipValue[longOrder] + short.orders.slipValue[shortOrder];
            closed.slippage += closedPart * long.orders.slipValue[longOrder] + short.orders.slipValue[shortOrder];

            long.orders.ticket   [longOrder]  = ticket;                    // update remaining long ticket
            long.orders.lots     [longOrder]  = OrderLots();
            long.orders.slipValue[longOrder] *= 1-closedPart;

            ArraySpliceInts   (short.orders.ticket,     shortOrder, 1);    // drop short ticket
            ArraySpliceInts   (short.orders.level,      shortOrder, 1);
            ArraySpliceDoubles(short.orders.levelPrice, shortOrder, 1);
            ArraySpliceDoubles(short.orders.lots,       shortOrder, 1);
            ArraySpliceDoubles(short.orders.openPrice,  shortOrder, 1);
            ArraySpliceDoubles(short.orders.slipValue,  shortOrder, 1);
            ArraySpliceInts   (short.orders.status,     shortOrder, 1);
            shortSize--;
         }
         else {                                                            // remaining short position
            closedPart       = closedLots / short.orders.lots     [shortOrder];
            open.slippage   -= closedPart * short.orders.slipValue[shortOrder] + long.orders.slipValue[longOrder];
            closed.slippage += closedPart * short.orders.slipValue[shortOrder] + long.orders.slipValue[longOrder];

            short.orders.ticket   [shortOrder]  = ticket;                  // update remaining short ticket
            short.orders.lots     [shortOrder]  = OrderLots();
            short.orders.slipValue[shortOrder] *= 1-closedPart;

            ArraySpliceInts   (long.orders.ticket,      longOrder, 1);     // drop long ticket
            ArraySpliceInts   (long.orders.level,       longOrder, 1);
            ArraySpliceDoubles(long.orders.levelPrice,  longOrder, 1);
            ArraySpliceDoubles(long.orders.lots,        longOrder, 1);
            ArraySpliceDoubles(long.orders.openPrice,   longOrder, 1);
            ArraySpliceDoubles(long.orders.slipValue,   longOrder, 1);
            ArraySpliceInts   (long.orders.status,      longOrder, 1);
            longSize--;
         }
         sequence.orders--;
      }
      else return(_false(catch("UpdateOrders(11)")));
   }


   // (3) call the function again if hedges have been closed to update open profits
   if (longOrder != -1) UpdateOrders();
   else {
      sequence.pl = profit;                                                // TODO: this is just wrong
      open.swap   = swap;
   }


   // (4) adjust TakeProfit to compensate for trading costs
   if (long.stopsFilled)  AdjustTakeProfit(OP_LONG);
   if (short.stopsFilled) AdjustTakeProfit(OP_SHORT);


   //if (IsVisualMode() && (long.stopsFilled || short.stopsFilled)) Tester.Pause();
   return(long.stopsFilled || short.stopsFilled);
}


/**
 * Adjust TakeProfit of a side to compensate for trading costs (commission, swap, slippage). Called after a pending order
 * was filled. Commission is pre-calculated up to TakeProfit and doesn't change. Slippage and swap may vary with each fill.
 *
 * @param  int direction - range side to adjust: OP_LONG | OP_SHORT
 *
 * @return bool - success status
 */
bool AdjustTakeProfit(int direction) {
   if (__STATUS_OFF) return(false);

   double openCommission, costs, lots, pipValue, pips, tpPrice;
   int size, oe[ORDER_EXECUTION.intSize];
   bool logged;


   // (1) adjust TakeProfit of long orders
   if (direction == OP_LONG) {
      openCommission = -long.tpOrderSize * GetCommissionRate(); if (__STATUS_OFF) return(false);
      costs          = openCommission + closed.commission + open.swap + closed.swap + open.slippage + closed.slippage;
      lots           = long.tpOrderSize + short.position;       // effective lots at TakeProfit (positive)
      pipValue       = PipValue(lots);                          if (__STATUS_OFF) return(false);
      pips           = SetLongTPCompensation(-costs/pipValue);
      pips          += ifDouble(IsTesting(), 0, 2*Point);       // online only: adjust TakeProfit for expected 2 point closing slippage
      tpPrice        = RoundCeil(long.tpPrice + pips*Pip, Digits);
      size           = ArraySize(long.orders.ticket);
      logged         = false;

      for (int i=0; i < size; i++) {
         OrderSelect(long.orders.ticket[i], SELECT_BY_TICKET);
         if (NE(OrderTakeProfit(), tpPrice)) {
            if (!logged) {
               //debug("AdjustTakeProfit(1)  long: default TakeProfit="+ NumberToStr(OrderTakeProfit(), PriceFormat) +", costs="+ DoubleToStr(costs, 2) +" => "+ DoubleToStr(long.tpCompensation, 2) +" pip, new TakeProfit="+ NumberToStr(tpPrice, PriceFormat));
               logged = true;
            }
            if (!OrderModifyEx(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tpPrice, NULL, Blue, NULL, oe)) return(false);
         }
      }
      return(true);
   }


   // (2) adjust TakeProfit of short orders
   if (direction == OP_SHORT) {
      openCommission = short.tpOrderSize * GetCommissionRate(); if (__STATUS_OFF) return(false);
      costs          = openCommission + closed.commission + open.swap + closed.swap + open.slippage + closed.slippage;
      lots           = -short.tpOrderSize - long.position;      // effective lots at TakeProfit (positive)
      pipValue       = PipValue(lots);                          if (__STATUS_OFF) return(false);
      pips           = SetShortTPCompensation(-costs/pipValue);
      pips          += ifDouble(IsTesting(), 0, 2*Point);      // online only: adjust TakeProfit for expected 2 point closing slippage
      tpPrice        = RoundFloor(short.tpPrice - pips*Pip, Digits);
      size           = ArraySize(short.orders.ticket);
      logged         = false;

      for (i=0; i < size; i++) {
         OrderSelect(short.orders.ticket[i], SELECT_BY_TICKET);
         if (NE(OrderTakeProfit(), tpPrice)) {
            if (!logged) {
               //debug("AdjustTakeProfit(2)  short: default TakeProfit="+ NumberToStr(OrderTakeProfit(), PriceFormat) +", costs="+ DoubleToStr(costs, 2) +" => "+ DoubleToStr(short.tpCompensation, 2) +" pip, new TakeProfit="+ NumberToStr(tpPrice, PriceFormat));
               logged = true;
            }
            if (!OrderModifyEx(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tpPrice, NULL, Blue, NULL, oe)) return(false);
         }
      }
      return(true);
   }
   return(!catch("AdjustTakeProfit(3)  illegal parameter direction: "+ direction, ERR_INVALID_PARAMETER));
}


/**
 * Determine and return the commission arte for the current symbol.
 *
 * @return double - commission rate (zero or positive) or -1 (EMPTY) in case of errors
 */
double GetCommissionRate() {
   if (__STATUS_OFF) return(EMPTY);

   if (IsEmptyValue(commissionRate)) {
      int size = ArraySize(long.orders.ticket);
      for (int i=0; i < size; i++) {
         if (long.orders.status[i] == ORDER_OPEN) {
            OrderSelect(long.orders.ticket[i], SELECT_BY_TICKET);
            commissionRate = -OrderCommission()/OrderLots();
            break;
         }
      }
      if (i >= size) {
         size = ArraySize(short.orders.ticket);
         for (i=0; i < size; i++) {
            if (short.orders.status[i] == ORDER_OPEN) {
               OrderSelect(short.orders.ticket[i], SELECT_BY_TICKET);
               commissionRate = -OrderCommission()/OrderLots();
               break;
            }
         }
      }
      if (i >= size) return(_EMPTY(catch("GetCommissionRate(1)  cannot determine commission rate, no open position found", ERR_RUNTIME_ERROR)));
   }
   return(commissionRate);
}


/**
 * Re-balance both sides of the straddle by placing additional pending orders.
 *
 * @return bool - success status
 */
bool RebalanceGrid() {
   if (__STATUS_OFF) return(false);
   //debug("RebalanceGrid(1)  long/short tpUnits="+ long.tpUnits +"/"+ short.tpUnits);

   double price, lots;
   int    levels, newUnits, plUnits, tpUnits, prevUnits, addedOrders;
   int    units[]; ArrayResize(units, Grid.Levels+1);


   // long side
   tpUnits     = long.tpUnits;
   prevUnits   = tpUnits;
   addedOrders = 0;
   ArrayInitialize(units, 0);

   while (tpUnits < 2) {                                                // calculate long units to add
      for (int level=Grid.Levels; level >= 1 && tpUnits < 2; level--) {
         newUnits      = level;
         units[level] += newUnits;
         levels        = (Grid.Levels+1) - level;
         plUnits       = newUnits * levels;
         tpUnits      += plUnits;
      }
   }
   for (level=Grid.Levels; level >= 1; level--) {                       // add long stop orders
      if (units[level] > 0) {
         price = grid.startPrice + level*grid.size*Pip;
         lots  = units[level] * StartLots;
         //debug("RebalanceGrid(2)  adding Stop Buy order, level="+ level +", units="+ units[level]);
         if (!AddOrder(OP_LONG, NULL, level, price, lots, price, long.tpPrice, short.tpPrice, NULL, ORDER_PENDING)) return(false);
         addedOrders++;
         //debug("RebalanceGrid(3)  now long.tpUnits="+ long.tpUnits);
      }
   }
   //if (addedOrders > 0) debug("RebalanceGrid(4)  pos="+ Round(sequence.position/StartLots) +", previous long.tpUnits="+ prevUnits +", added units="+ IntsToStr(units, NULL) +", new long.tpUnits="+ long.tpUnits);


   // short side
   tpUnits     = short.tpUnits;
   prevUnits   = tpUnits;
   addedOrders = 0;
   ArrayInitialize(units, 0);

   while (tpUnits < 2) {                                                // calculate short units to add
      for (level=Grid.Levels; level >= 1 && tpUnits < 2; level--) {
         newUnits      = level;
         units[level] += newUnits;
         levels        = (Grid.Levels+1) - level;
         plUnits       = newUnits * levels;
         tpUnits      += plUnits;
      }
   }
   for (level=Grid.Levels; level >= 1; level--) {                       // add short stop orders
      if (units[level] > 0) {
         price = grid.startPrice - level*grid.size*Pip;
         lots  = units[level] * StartLots;
         //debug("RebalanceGrid(5)  adding Stop Sell order, level="+ level +", units="+ units[level]);
         if (!AddOrder(OP_SHORT, NULL, level, price, lots, price, short.tpPrice, long.tpPrice, NULL, ORDER_PENDING)) return(false);
         addedOrders++;
         //debug("RebalanceGrid(6)  now short.tpUnits="+ short.tpUnits);
      }
   }
   //if (addedOrders > 0) debug("RebalanceGrid(7)  pos="+ Round(sequence.position/StartLots) +", previous short.tpUnits="+ prevUnits +", added units="+ IntsToStr(units, NULL) +", new short.tpUnits="+ short.tpUnits);


   if (long.tpUnits  > 6) return(!catch("RebalanceGrid(8)  unexpected calculation result for long.tpUnits: "+ long.tpUnits +" (greater 6)", ERR_RUNTIME_ERROR));
   if (short.tpUnits > 6) return(!catch("RebalanceGrid(9)  unexpected calculation result for short.tpUnits: "+ short.tpUnits +" (greater 6)", ERR_RUNTIME_ERROR));

   return(!catch("RebalanceGrid(10)"));
}


/**
 * Add an order to the internally managed order stack. Pending entry orders of the same grid level are merged.
 *
 * @param  int    direction  - one of OP_LONG | OP_SHORT
 * @param  int    ticket
 * @param  int    level
 * @param  double levelPrice
 * @param  double lots
 * @param  double orderPrice
 * @param  double takeProfit
 * @param  double stopLoss
 * @param  double slipValue
 * @param  int    status
 *
 * @return bool - success status
 */
bool AddOrder(int direction, int ticket, int level, double levelPrice, double lots, double orderPrice, double takeProfit, double stopLoss, double slipValue, int status) {
   int sizeLong  = ArraySize(long.orders.ticket),  minSlippage = Tester.MinSlippage.Points, levels;
   int sizeShort = ArraySize(short.orders.ticket), maxSlippage = Tester.MaxSlippage.Points, oe[ORDER_EXECUTION.intSize];
   lots       = NormalizeDouble(lots, 2);
   orderPrice = NormalizeDouble(orderPrice, Digits);

   double stopPrice, existingLots, newLots = lots;


   if (direction == OP_LONG) {
      levels        = (Grid.Levels+1) - level;
      long.tpUnits += Round(levels * lots/StartLots);                   // increase long.tpUnits

      if (status == ORDER_PENDING) {
         if (!ticket) {
            // delete existing pending orders of the same level and remember lot sizes
            existingLots = 0;
            for (int i=sizeLong-1; i >= 0; i--) {
               if (long.orders.level[i]==level && long.orders.status[i]==status) {
                  if (!OrderDeleteEx(long.orders.ticket[i], CLR_NONE, NULL, oe))
                     return(!oe.Error(oe));
                  existingLots += long.orders.lots[i];
                  ArraySpliceInts   (long.orders.ticket,     i, 1);
                  ArraySpliceInts   (long.orders.level,      i, 1);
                  ArraySpliceDoubles(long.orders.levelPrice, i, 1);
                  ArraySpliceDoubles(long.orders.lots,       i, 1);
                  ArraySpliceDoubles(long.orders.openPrice,  i, 1);
                  ArraySpliceDoubles(long.orders.slipValue,  i, 1);
                  ArraySpliceInts   (long.orders.status,     i, 1);
               }
            }
            if (existingLots > 0) {                                     // merge existing and new lot sizes into one order
               lots = NormalizeDouble(existingLots + lots, 2);
               //debug("AddOrder(1)  merging Stop Buy "+ NumberToStr(NormalizeDouble(existingLots, 2), ".1+") +" + "+ NumberToStr(NormalizeDouble(lots-existingLots, 2), ".1+") +" lot at level "+ level +" to "+ NumberToStr(lots, ".1+") +" lot");
            }
            stopPrice = Tester.AddRandomSlippage(orderPrice, minSlippage, maxSlippage);
            ticket    = OrderSendEx(Symbol(), OP_BUYSTOP, lots, stopPrice, NULL, stopLoss, takeProfit, os.comment +", L"+ level, os.magicNumber, NULL, Blue, NULL, oe);
            if (!ticket) return(!oe.Error(oe));
         }
         long.units.current[level] += Round(newLots/StartLots);
         str.long.units.swing       = IntsToStr(long.units.current, NULL);
      }
      else if (status == ORDER_OPEN) {
         levels            = (Grid.Levels+1) + level;
         short.tpUnits    -= Round(levels * lots/StartLots);            // decrease short.tpUnits
         long.position     = NormalizeDouble(long.position     + lots, 2);
         sequence.position = NormalizeDouble(sequence.position + lots, 2);
      }
      else return(!catch("AddOrder(2)  illegal parameter status: "+ status, ERR_INVALID_PARAMETER));

                 ArrayPushInt   (long.orders.ticket,     ticket    );
                 ArrayPushInt   (long.orders.level,      level     );
                 ArrayPushDouble(long.orders.levelPrice, levelPrice);
                 ArrayPushDouble(long.orders.lots,       lots      );
                 ArrayPushDouble(long.orders.openPrice,  orderPrice);
                 ArrayPushDouble(long.orders.slipValue,  slipValue );
      sizeLong = ArrayPushInt   (long.orders.status,     status    );
      sequence.orders   = sizeLong + sizeShort;
      long.tpOrderSize += newLots;
      return(true);
   }


   if (direction == OP_SHORT) {
      levels         = (Grid.Levels+1) - level;
      short.tpUnits += Round(levels * lots/StartLots);                  // increase short.tpUnits

      if (status == ORDER_PENDING) {
         if (!ticket) {
            // delete existing pending orders of the same level and remember lot sizes
            existingLots = 0;
            for (i=sizeShort-1; i >= 0; i--) {
               if (short.orders.level[i]==level && short.orders.status[i]==status) {
                  if (!OrderDeleteEx(short.orders.ticket[i], CLR_NONE, NULL, oe))
                     return(!oe.Error(oe));
                  existingLots += short.orders.lots[i];
                  ArraySpliceInts   (short.orders.ticket,     i, 1);
                  ArraySpliceInts   (short.orders.level,      i, 1);
                  ArraySpliceDoubles(short.orders.levelPrice, i, 1);
                  ArraySpliceDoubles(short.orders.lots,       i, 1);
                  ArraySpliceDoubles(short.orders.openPrice,  i, 1);
                  ArraySpliceDoubles(short.orders.slipValue,  i, 1);
                  ArraySpliceInts   (short.orders.status,     i, 1);
               }
            }
            if (existingLots > 0) {                                     // merge existing and new lot sizes into one order
               lots = NormalizeDouble(existingLots + lots, 2);
               //debug("AddOrder(3)  merging Stop Sell "+ NumberToStr(NormalizeDouble(existingLots, 2), ".1+") +" + "+ NumberToStr(NormalizeDouble(lots-existingLots, 2), ".1+") +" lot at level "+ level +" to "+ NumberToStr(lots, ".1+") +" lot");
            }
            stopPrice = Tester.AddRandomSlippage(orderPrice, -maxSlippage, -minSlippage);
            ticket    = OrderSendEx(Symbol(), OP_SELLSTOP, lots, stopPrice, NULL, stopLoss, takeProfit, os.comment +", S"+ level, os.magicNumber, NULL, Red, NULL, oe);
            if (!ticket) return(!oe.Error(oe));
         }
         short.units.current[level] += Round(newLots/StartLots);
         str.short.units.swing       = IntsToStr(short.units.current, NULL);
      }
      else if (status == ORDER_OPEN) {
         levels            = (Grid.Levels+1) + level;
         long.tpUnits     -= Round(levels * lots/StartLots);            // decrease long.tpUnits
         sequence.position = NormalizeDouble(sequence.position - lots, 2);
         short.position    = NormalizeDouble(short.position    - lots, 2);
      }
      else return(!catch("AddOrder(4)  illegal parameter status: "+ status, ERR_INVALID_PARAMETER));

                  ArrayPushInt   (short.orders.ticket,     ticket    );
                  ArrayPushInt   (short.orders.level,      level     );
                  ArrayPushDouble(short.orders.levelPrice, levelPrice);
                  ArrayPushDouble(short.orders.lots,       lots      );
                  ArrayPushDouble(short.orders.openPrice,  orderPrice);
                  ArrayPushDouble(short.orders.slipValue,  slipValue );
      sizeShort = ArrayPushInt   (short.orders.status,     status    );
      sequence.orders    = sizeLong + sizeShort;
      short.tpOrderSize -= newLots;
      return(true);
   }

   return(!catch("AddOrder(5)  illegal parameter direction: "+ direction, ERR_INVALID_PARAMETER));
}


/**
 * Adjusts a price by a random amount of slippage to simulate slipped entry prices in Tester. If not run in Tester
 * the function does nothing.
 *
 * @param  double price          - original price
 * @param  int    min [optional] - minimum slippage in points to add (default: -5 point)
 * @param  int    max [optional] - maximum slippage in points to add (default: +5 point)
 *
 * @return double - randomly modified price
 */
double Tester.AddRandomSlippage(double price, int min=-5, int max=5) {
   if (!IsTesting())
      return(price);

   static bool seeded; if (!seeded) {
      MathSrand(GetTickCount());
      seeded = true;
   }
   int slippage = Round(MathRand()/32767. * (max-min) + min);  // range: -5...+5 for slippage=5
   //int slippage = MathRand() % (max-min) + min;
   //debug("Tester.AddRandomSlippage(1)  price="+ NumberToStr(price, PriceFormat) +"  slippage="+ DoubleToStr(slippage*Point/Pip, Digits & 1) +" pip");

   return(NormalizeDouble(price + slippage*Point, Digits));
}


/**
 * Close the remaining pending orders and open positions of the sequence.
 *
 * @return int - error status
 *
 *
 * TODO: - close open positions optimized
 * TODO: - close open positions before deletion of pending orders
 * TODO: - handle parallel close errors
 */
int CloseSequence() {
   int oe[ORDER_EXECUTION.intSize];
   double profit, commission, swap, slippage;

   // close remaining long orders
   int orders = ArraySize(long.orders.ticket);
   for (int i=0; i < orders; i++) {
      OrderSelect(long.orders.ticket[i], SELECT_BY_TICKET);
      if (!OrderCloseTime()) {
         if (OrderType() == OP_BUY) OrderCloseEx(long.orders.ticket[i], NULL, NULL, os.slippage, Orange, NULL, oe);
         else                       OrderDeleteEx(long.orders.ticket[i], CLR_NONE, NULL, oe);
      }
      if (OrderType() == OP_BUY) {
         profit     += OrderProfit();
         commission += OrderCommission();
         swap       += OrderSwap();
      }
      long.orders.status[i] = ORDER_CLOSED;
   }

   // close remaining short orders
   orders = ArraySize(short.orders.ticket);
   for (i=0; i < orders; i++) {
      OrderSelect(short.orders.ticket[i], SELECT_BY_TICKET);
      if (!OrderCloseTime()) {
         if (OrderType() == OP_SELL) OrderCloseEx(short.orders.ticket[i], NULL, NULL, os.slippage, Orange, NULL, oe);
         else                        OrderDeleteEx(short.orders.ticket[i], CLR_NONE, NULL, oe);
      }
      if (OrderType() == OP_SELL) {
         profit     += OrderProfit();
         commission += OrderCommission();
         swap       += OrderSwap();
      }
      short.orders.status[i] = ORDER_CLOSED;
   }

   closed.grossProfit += profit;
   closed.commission  += commission;
   closed.swap        += swap;
   open.swap           = 0;
   closed.slippage    += open.slippage;
   open.slippage       = 0;
   closed.netProfit    = closed.grossProfit + closed.commission + closed.swap;
   sequence.pl         = closed.netProfit;
   debug("CloseSequence(1)  "+ ifString(sequence.position > 0, "long", "short") +" profit="+ DoubleToStr(closed.netProfit, 2) +"  units="+ DoubleToStr(closed.netProfit/grid.unitValue, 1));


   // count down the sequence counter
   if (Trade.Sequences > 0)
      Trade.Sequences--;


   // reset runtime vars if another sequence is going to get started
   if (Trade.Sequences != 0) {
      StartPrice           = 0;                 // reset input parameter

      sequence.orders      = 0;
      sequence.position    = 0;
      sequence.pl          = 0;
      sequence.plMin       = 0;
      sequence.plMax       = 0;

    //grid.size...                              // unchanged
      grid.startPrice      = 0;
    //grid.firstSet.units...                    // unchanged
    //grid.addedSet.units...                    // unchanged
      grid.unitValue       = 0;

      lastLevel.filled     = 0;
      lastLevel.plUnits    = 0;

      closed.grossProfit   = 0;
      closed.netProfit     = 0;
      closed.commission    = 0;
      open.swap            = 0;
      closed.swap          = 0;
      open.slippage        = 0;
      closed.slippage      = 0;

      ArrayResize(long.orders.ticket,      0);
      ArrayResize(long.orders.level,       0);
      ArrayResize(long.orders.levelPrice,  0);
      ArrayResize(long.orders.lots,        0);
      ArrayResize(long.orders.openPrice,   0);
      ArrayResize(long.orders.slipValue,   0);
      ArrayResize(long.orders.status,      0);
      ArrayResize(long.units.current,      0);
      long.position    =                   0;
      long.tpPrice     =                   0;
      long.tpUnits     =                   0;
      long.tpOrderSize =                   0;
      SetLongTPCompensation(EMPTY_VALUE);

      ArrayResize(short.orders.ticket,     0);
      ArrayResize(short.orders.level,      0);
      ArrayResize(short.orders.levelPrice, 0);
      ArrayResize(short.orders.lots,       0);
      ArrayResize(short.orders.openPrice,  0);
      ArrayResize(short.orders.slipValue,  0);
      ArrayResize(short.orders.status,     0);
      ArrayResize(short.units.current,     0);
      short.position    =                  0;
      short.tpPrice     =                  0;
      short.tpUnits     =                  0;
      short.tpOrderSize =                  0;
      SetShortTPCompensation(EMPTY_VALUE);

    //os.magicNumber...                         // unchanged
    //os.slippage...                            // unchanged
      os.comment = "";

    //str.range.tpCompensation...               // reset by SetLongTPCompensation()/SetShortTPCompensation()
      str.long.units.swing  = "";
      str.short.units.swing = "";

      commissionRate = EMPTY_VALUE;

      //if (IsVisualMode()) Tester.Pause();
   }


   // else stop and keep values (this was the last sequence)
   else {
      SetLastError(ERR_CANCELLED_BY_USER);
   }

   return(catch("CloseSequence(2)"));
}


/**
 * Show the current runtime status on screen.
 *
 * @param  int error [optional] - user-defined error to display (default: none)
 *
 * @return int - the same error
 */
int ShowStatus(int error = NO_ERROR) {
   if (!__CHART)
      return(error);

   static bool statusBox; if (!statusBox)
      statusBox = ShowStatusBox();

   string str.status = "";
   if (__STATUS_OFF) str.status = StringConcatenate(" switched OFF  [", ErrorDescription(__STATUS_OFF.reason), "]");

   string str.sequence.pl       = DoubleToStr(sequence.pl, 2), str.sequence.plMax="?",       str.sequence.plMin="?",
          str.sequence.plPct    = "?",                         str.sequence.plPctMax="?",    str.sequence.plPctMin="?",
          str.sequence.cumPlPct = "?",                         str.sequence.cumPlPctMax="?", str.sequence.cumPlPctMin="?", str.cumulated="";

   static int iCumulated = -1; if (iCumulated == -1)
      iCumulated = (Trade.Sequences != 1);
   if (iCumulated == 1)
      str.cumulated = StringConcatenate(" PL % cum:  ", str.sequence.cumPlPct, "     max:    ", str.sequence.cumPlPctMax, "      min:    ", str.sequence.cumPlPctMin, NL);


   // 4 lines margin-top
   Comment(NL, NL, NL, NL,
           "", __NAME__, str.status,                                                                                                  NL,
           " ------------",                                                                                                           NL,
           " Range:       2 x ", Grid.Range, " pip   ", str.range.tpCompensation,                                                     NL,
           " Grid:          ",   Grid.Levels, " x ", DoubleToStr(grid.size, 1), " pip",                                               NL,
           " StartLots:    ",    StartLots,                                                                                           NL,
           " PL:             ",  str.sequence.pl,    "     max:    ", str.sequence.plMax,    "      min:    ", str.sequence.plMin,    NL,
           " PL %:         ",    str.sequence.plPct, "     max:    ", str.sequence.plPctMax, "      min:    ", str.sequence.plPctMin, NL,
           str.cumulated);


   if (__WHEREAMI__ == RF_INIT)
      WindowRedraw();
   return(error);
}


/**
 * Create and show a background box for the status display.
 *
 * @return bool - success status
 */
bool ShowStatusBox() {
   if (!__CHART)
      return(false);

   int x[]={2, 120, 141}, y[]={59}, fontSize=90, cols=ArraySize(x), rows=ArraySize(y);
   color  bgColor = C'248,248,248';                                  // chart background color     //LightSalmon
   string label;

   for (int i, row=0; row < rows; row++) {
      for (int col=0; col < cols; col++, i++) {
         label = StringConcatenate(__NAME__, ".status."+ (i+1));
         if (ObjectFind(label) != 0)
            ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet    (label, OBJPROP_XDISTANCE, x[col]);
         ObjectSet    (label, OBJPROP_YDISTANCE, y[row]);
         ObjectSetText(label, "g", fontSize, "Webdings", bgColor);   // "g" is a rectangle
         ObjectRegister(label);
      }
   }
   return(!catch("ShowStatusBox(1)"));
}


/**
 * Return a string representation of the input parameters for logging.
 *
 * @return string
 */
string InputsToStr() {
   string result = "";

   if (false && input.all == "") {
      result = StringConcatenate("input: ",

                                 "Grid.Range=",                Grid.Range,                                                      "; ",
                                 "Grid.Levels=",               Grid.Levels,                                                     "; ",
                                 "StartLots=",                 NumberToStr(StartLots, ".1+"),                                   "; ",
                                 "StartPrice=",                ifString(StartPrice, NumberToStr(StartPrice, PriceFormat), "0"), "; ",
                                 "Trade.StartHour=",           Trade.StartHour,                                                 "; ",
                                 "Trade.EndHour=",             Trade.EndHour,                                                   "; ",
                                 "Trade.Sequences=",           Trade.Sequences,                                                 "; ");
      if (IsTesting()) {
         result = StringConcatenate(result,
                                 "Tester.MinSlippage.Points=", Tester.MinSlippage.Points,                                       "; ",
                                 "Tester.MaxSlippage.Points=", Tester.MaxSlippage.Points,                                       "; ");
      }
   }
   return(result);
}
