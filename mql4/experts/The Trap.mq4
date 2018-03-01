/**
 * The Trap - straddle trading with a twist
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_PIPVALUE};
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Grid.Range      = 15;             // in pip
extern int    Grid.Levels     = 3;
extern double StartLots       = 0.1;
extern int    Trade.StartHour = -1;             // hour to start sequences             (-1: any hour)
extern int    Trade.EndHour   = -1;             // hour to stop starting new sequences (-1: no hour)
extern int    Trade.Sequences = 1;              // number of sequences to trade        (-1: unlimited)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/xtrade/OrderExecution.mqh>

// grid and sequence management
double grid.size;                               // in pip
double grid.startPrice;
int    grid.firstSet.units;                     // total number of units of the initial order set
int    grid.addedSet.units;                     // total number of units of one additional order set
double grid.unitValue;                          // value of 1 unit in account currency

int    sequence.orders;                         // total number of currently open orders        (zero or positive)
double sequence.position;                       // current total position in lots: long + short (positive or negative)
double sequence.pl    = EMPTY_VALUE;            // current PL in account currency
double sequence.plMin = EMPTY_VALUE;            // minimum PL in account currency
double sequence.plMax = EMPTY_VALUE;            // maximum PL in account currency

int    realized.units;                          // realized profit in units                     (positive or negative)
double realized.fees;                           // realized trading costs in account currency   (positive or negative)
double realized.grossProfit;                    // realized gross profit in account currency    (positive or negative)
double realized.netProfit;                      // realized net profit in account currency      (positive or negative)

int    lastLevel.filled;                        // the last level filled in either direction    (positive or negative)
int    lastLevel.plUnits;                       // total PL in units at the last level filled   (positive = profitable)

// order status
#define ORDER_PENDING         0
#define ORDER_OPEN            1
#define ORDER_CLOSED         -1

// order management
int    long.orders.ticket    [];                // order tickets
int    long.orders.level     [];                // order grid level                                 (positive)
double long.orders.lots      [];                // order lot sizes                                  (positive)
double long.orders.openPrice [];                // order open prices
int    long.orders.status    [];                // whether the order is pending, open or closed
int    long.units.current    [];                // the current distribution of long units to add    (positive)
double long.position;                           // currently open long position in lots             (zero or positive)
double long.tpPrice;                            // long TakeProfit price
int    long.tpUnits;                            // profit in units at TakeProfit incl. realized     (positive = profitable)
double long.tpOrderSize;                        // pending and open lots in direction of TakeProfit (positive)

int    short.orders.ticket   [];                // order tickets
int    short.orders.level    [];                // order grid level                                 (positive)
double short.orders.lots     [];                // order lot sizes                                  (positive)
double short.orders.openPrice[];                // order open prices
int    short.orders.status   [];                // whether the order is pending, open or closed
int    short.units.current   [];                // the current distribution of short units to add   (positive)
double short.position;                          // currently open short position in lots            (zero or negative)
double short.tpPrice;                           // short TakeProfit price
int    short.tpUnits;                           // profit in units at TakeProfit incl. realized     (positive = profitable)
double short.tpOrderSize;                       // pending and open lots in direction of TakeProfit (negative)

// trade function defaults
int    os.magicNumber = 1803;
double os.slippage    = 0.1;                    // in pip
string os.comment     = "";

// cache variables to speed-up to-string operations
string str.long.units.swing  = "";              // the current swing's full distribution of units to add, e.g.: "0  1  1  1"
string str.short.units.swing = "";              // the current swing's full distribution of units to add, e.g.: "0  2  4  3"

// development
int test.startTime;


/**
 * Initialization.
 *
 * @return int - error status
 */
int onInit() {
   grid.size           = Grid.Range / (Grid.Levels+1.);
   grid.firstSet.units = Grid.Levels * (Grid.Levels+1)/2;
   grid.addedSet.units = 0;

   for (int i=Grid.Levels; i > 0; i-=2) {
      grid.addedSet.units += i*i;
   }
   return(catch("onInit(1)"));
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

         if (Hour() >= Trade.StartHour && Hour() < Trade.EndHour) {
            // follow start and end hour restrictions
            grid.startPrice = NormalizeDouble((Bid + Ask)/2, Digits);
            grid.unitValue  = grid.size * PipValue(StartLots); if (__STATUS_OFF) return(last_error);
            long.tpPrice    = NormalizeDouble(grid.startPrice + Grid.Range*Pip, Digits);
            short.tpPrice   = NormalizeDouble(grid.startPrice - Grid.Range*Pip, Digits);
            os.comment      = "Trap: "+ Grid.Range +"p "+ NumberToStr(grid.startPrice, PriceFormat);
            ArrayResize(long.units.current,  Grid.Levels + 1);
            ArrayResize(short.units.current, Grid.Levels + 1);

            for (int i=1; i <= Grid.Levels; i++) {
               double price = grid.startPrice + i*grid.size*Pip;
               if (!AddOrder(OP_LONG, NULL, i, StartLots, price, long.tpPrice, short.tpPrice, ORDER_PENDING)) return(last_error);
            }
            for (i=1; i <= Grid.Levels; i++) {
               price = grid.startPrice - i*grid.size*Pip;
               if (!AddOrder(OP_SHORT, NULL, i, StartLots, price, short.tpPrice, long.tpPrice, ORDER_PENDING)) return(last_error);
            }
            debug("onTick(1)  new sequence at "+ NumberToStr(grid.startPrice, PriceFormat) +"  target: "+ long.tpUnits +"/"+ short.tpUnits +" units, 1 unit: "+ DoubleToStr(grid.unitValue, 2));
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
   double profit;


   // (1) check for pending order fills and order closes (presumably TakeProfit)
   for (int i=0; i < longSize; i++) {
      OrderSelect(long.orders.ticket[i], SELECT_BY_TICKET);
      if (!OrderCloseTime()) {
         if (long.orders.status[i] == ORDER_PENDING) {
            if (OrderType() == OP_BUY) {
               long.orders.status[i] = ORDER_OPEN;
               long.stopsFilled      = true;
               units = MathRound(sequence.position/StartLots);                // lot units before crossing of this level

               //debug("UpdateOrders(1)   long  level "+ long.orders.level[i] +" filled:  "+ DoubleToStr(long.orders.lots[i], 1));
               if (lastLevel.filled <= 0) {
                  levels     = -lastLevel.filled;                             // levels between lastLevel.filled and mid level (zero)
                  plMidLevel = lastLevel.plUnits + levels * units;            // plUnits at the mid level (zero)
                  debug("UpdateOrders(2)   long  swing, @0: pl="+ plMidLevel +"  pos="+ units +"  orders="+ str.long.units.swing +"  target="+ long.tpUnits);
               }

               levels            = long.orders.level[i] - lastLevel.filled;   // levels between lastLevel.filled and the current level
               lastLevel.plUnits = lastLevel.plUnits + levels * units;        // plUnits at the current level
               lastLevel.filled  = long.orders.level[i];                      // the current level

               long.position     = NormalizeDouble(long.position + long.orders.lots[i], 2);
               sequence.position = NormalizeDouble(long.position + short.position, 2);
               levels            = (Grid.Levels+1) + long.orders.level[i];
               short.tpUnits    -= MathRound(levels * long.orders.lots[i]/StartLots);

               long.units.current[long.orders.level[i]] -= MathRound(long.orders.lots[i]/StartLots);
            }
         }
         else profit += OrderProfit() + OrderSwap() + OrderCommission();
      }
      else {
         if (OrderType()==OP_BUYSTOP) /*&&*/ if (OrderComment()=="deleted [no money]") {
            LogTicket(OrderTicket());
            catch("UpdateOrders(3)  #"+ OrderTicket() +" pending order was deleted", ERR_NOT_ENOUGH_MONEY);
         }
         return(_false(CloseSequence()));                                  // close all if one was closed/deleted
      }
   }

   for (i=0; i < shortSize; i++) {
      OrderSelect(short.orders.ticket[i], SELECT_BY_TICKET);
      if (!OrderCloseTime()) {
         if (short.orders.status[i] == ORDER_PENDING) {
            if (OrderType() == OP_SELL) {
               short.orders.status[i] = ORDER_OPEN;
               short.stopsFilled      = true;
               units = MathRound(sequence.position/StartLots);                // lot units before crossing of this level

               //debug("UpdateOrders(4)   short level "+ (-short.orders.level[i]) +" filled: "+ DoubleToStr(-short.orders.lots[i], 1));
               if (lastLevel.filled >= 0) {
                  levels     = lastLevel.filled;                              // levels between lastLevel.filled and mid level (zero)
                  plMidLevel = lastLevel.plUnits - levels * units;            // plUnits at the mid level (zero)
                  debug("UpdateOrders(5)   short swing, @0: pl="+ plMidLevel +"  pos="+ units +"  orders="+ str.short.units.swing +"  target="+ short.tpUnits);
               }

               levels            = lastLevel.filled + short.orders.level[i];  // levels between lastLevel.filled and the current level
               lastLevel.plUnits = lastLevel.plUnits - levels * units;        // plUnits at the current level
               lastLevel.filled  = -short.orders.level[i];                    // the current level

               short.position    = NormalizeDouble(short.position - short.orders.lots[i], 2);
               sequence.position = NormalizeDouble(long.position + short.position, 2);
               levels            = (Grid.Levels+1) + short.orders.level[i];
               long.tpUnits     -= MathRound(levels * short.orders.lots[i]/StartLots);

               short.units.current[short.orders.level[i]] -= MathRound(short.orders.lots[i]/StartLots);
            }
         }
         else profit += OrderProfit() + OrderSwap() + OrderCommission();
      }
      else {
         if (OrderType()==OP_SELLSTOP) /*&&*/ if (OrderComment()=="deleted [no money]") {
            LogTicket(OrderTicket());
            catch("UpdateOrders(6)  #"+ OrderTicket() +" pending order was deleted", ERR_NOT_ENOUGH_MONEY);
         }
         return(_false(CloseSequence()));                                  // close all if one was closed/deleted
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

      realized.grossProfit += oe.Profit(oe);                               // store realized amounts
    //realized.fees        += oe.Commission(oe) + oe.Swap(oe);
      realized.fees        += oe.Commission(oe);
      realized.netProfit    = realized.grossProfit + realized.fees;

      levels            = long.orders.level[longOrder] + short.orders.level[shortOrder];
      double closedLots = MathMin(long.orders.lots[longOrder], short.orders.lots[shortOrder]);
      units             = MathRound(levels * closedLots/StartLots);
      realized.units   -= units;                                           // always a loss
      //debug("UpdateOrders(8)  close by: profit="+ DoubleToStr(oe.Profit(oe), 2) +", commission="+ DoubleToStr(oe.Commission(oe), 2));
      //debug("UpdateOrders(9)  realized.profit: "+ DoubleToStr(realized.grossProfit, 2) +"  realized.fees: "+ DoubleToStr(realized.fees, 2)                   +"  realized.units: "+ realized.units);

      long.position      = NormalizeDouble(long.position - closedLots, 2);
      short.position     = NormalizeDouble(short.position + closedLots, 2);
      long.tpOrderSize  -= closedLots;
      short.tpOrderSize += closedLots;

      int ticket = oe.RemainingTicket(oe);
      if (!ticket) {                                                       // no remaining position
         ArraySpliceInts   (long.orders.ticket,     longOrder, 1);
         ArraySpliceInts   (long.orders.level,      longOrder, 1);         // drop long ticket
         ArraySpliceDoubles(long.orders.lots,       longOrder, 1);
         ArraySpliceDoubles(long.orders.openPrice,  longOrder, 1);
         ArraySpliceInts   (long.orders.status,     longOrder, 1);
         longSize--;

         ArraySpliceInts   (short.orders.ticket,    shortOrder, 1);        // drop short ticket
         ArraySpliceInts   (short.orders.level,     shortOrder, 1);
         ArraySpliceDoubles(short.orders.lots,      shortOrder, 1);
         ArraySpliceDoubles(short.orders.openPrice, shortOrder, 1);
         ArraySpliceInts   (short.orders.status,    shortOrder, 1);
         shortSize--;
         sequence.orders -= 2;
      }
      else if (OrderSelect(ticket, SELECT_BY_TICKET)) {
         //debug("UpdateOrders(10)  remaining ticket:");
         //LogOrder(ticket);

         if (OrderType() == OP_BUY) {                                      // remaining long position
            long.orders.ticket[longOrder] = ticket;                        // replace long ticket
            long.orders.lots  [longOrder] = OrderLots();

            ArraySpliceInts   (short.orders.ticket,    shortOrder, 1);     // drop short ticket
            ArraySpliceInts   (short.orders.level,     shortOrder, 1);
            ArraySpliceDoubles(short.orders.lots,      shortOrder, 1);
            ArraySpliceDoubles(short.orders.openPrice, shortOrder, 1);
            ArraySpliceInts   (short.orders.status,    shortOrder, 1);
            shortSize--;
         }
         else {                                                            // remaining short position
            short.orders.ticket[shortOrder] = ticket;                      // replace short ticket
            short.orders.lots  [shortOrder] = OrderLots();

            ArraySpliceInts   (long.orders.ticket,     longOrder, 1);      // drop long ticket
            ArraySpliceInts   (long.orders.level,      longOrder, 1);
            ArraySpliceDoubles(long.orders.lots,       longOrder, 1);
            ArraySpliceDoubles(long.orders.openPrice,  longOrder, 1);
            ArraySpliceInts   (long.orders.status,     longOrder, 1);
            longSize--;
         }
         sequence.orders--;
      }
      else return(_false(catch("UpdateOrders(11)")));
   }


   // (3) recursively call the function again to update open order profits
   if (longOrder!=-1 || shortOrder!=-1) UpdateOrders();
   else                                 sequence.pl = profit;


   // (4) adjust TakeProfit to compensate for trading costs
   if (long.stopsFilled)  AdjustTakeProfit(OP_LONG);
   if (short.stopsFilled) AdjustTakeProfit(OP_SHORT);


   //if (IsTesting() && (long.stopsFilled || short.stopsFilled)) Tester.Pause();
   return(long.stopsFilled || short.stopsFilled);
}


/**
 * Adjust TakeProfit of a grid side for commission.
 *
 * @param  int direction - grid side to adjust: OP_LONG | OP_SHORT
 *
 * @return bool - success status
 */
bool AdjustTakeProfit(int direction) {
   if (__STATUS_OFF) return(false);

   double lots, commission, pips, tpPrice;
   int size, oe[ORDER_EXECUTION.intSize];
   bool logged;


   // (1) adjust TakeProfit of long orders
   if (direction == OP_LONG) {
      lots       = long.tpOrderSize + short.position;
      commission = realized.fees + CommissionValue(-long.tpOrderSize);
      pips       = -commission / PipValue(lots); if (__STATUS_OFF) return(false);
      tpPrice    = RoundCeil(long.tpPrice + pips*Pip, Digits);
      size       = ArraySize(long.orders.ticket);
      logged     = false;

      for (int i=0; i < size; i++) {
         OrderSelect(long.orders.ticket[i], SELECT_BY_TICKET);
         if (NE(OrderTakeProfit(), tpPrice)) {
            if (!logged) {
               //debug("AdjustTakeProfit(1)  long commission="+ DoubleToStr(commission, 2) +" => "+ DoubleToStr(pips, 2) +" pip");
               logged = true;
            }
            if (!OrderModifyEx(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tpPrice, NULL, Blue, NULL, oe))
               return(false);
         }
      }
      return(true);
   }


   // (2) adjust TakeProfit of short orders
   if (direction == OP_SHORT) {
      lots       = short.tpOrderSize + long.position;
      commission = realized.fees + CommissionValue(short.tpOrderSize);
      pips       = commission / PipValue(lots); if (__STATUS_OFF) return(false);
      tpPrice    = RoundFloor(short.tpPrice - pips*Pip, Digits);
      size       = ArraySize(short.orders.ticket);
      logged     = false;

      for (i=0; i < size; i++) {
         OrderSelect(short.orders.ticket[i], SELECT_BY_TICKET);
         if (NE(OrderTakeProfit(), tpPrice)) {
            if (!logged) {
               //debug("AdjustTakeProfit(2)  short commission="+ DoubleToStr(commission, 2) +" => "+ DoubleToStr(pips, 2) +" pip");
               logged = true;
            }
            if (!OrderModifyEx(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tpPrice, NULL, Blue, NULL, oe))
               return(false);
         }
      }
      return(true);
   }
   return(!catch("AdjustTakeProfit(3)  illegal parameter direction: "+ direction, ERR_INVALID_PARAMETER));
}


/**
 * Re-balance both sides of the grid by placing additional pending orders.
 *
 * @return bool - success status
 */
bool RebalanceGrid() {
   if (__STATUS_OFF) return(false);
   //debug("RebalanceGrid(1)  tpUnits: "+ long.tpUnits +"/"+ short.tpUnits);

   double price, lots;
   int sets, addedOrders;
   if (long.tpUnits + grid.addedSet.units < 2)                       // one additional order set is not enough to re-balance the side
      sets = (2-long.tpUnits)/grid.addedSet.units;

   for (int i=Grid.Levels; i >= 1 && long.tpUnits < 2; i--) {        // add long stop orders
      price = NormalizeDouble(grid.startPrice + i*grid.size*Pip, Digits);
      lots  = (sets+1)*i*StartLots;
      //debug("RebalanceGrid(2)  adding Stop Buy order, level: "+ i +", lots: "+ DoubleToStr(lots, 2));
      if (!AddOrder(OP_LONG, NULL, i, lots, price, long.tpPrice, short.tpPrice, ORDER_PENDING)) return(false);
      addedOrders++;
      //debug("RebalanceGrid(3)  long.tpUnits now: "+ long.tpUnits);
   }
   //if (addedOrders > 0) debug("RebalanceGrid(4)  position: "+ ifString(total.position < 0, "", " ") + NumberToStr(total.position, ".1+") +" lot, added "+ addedOrders +" long order"+ ifString(addedOrders==1, "", "s") +", new tpUnits: "+ long.tpUnits +"/"+ short.tpUnits);

   sets        = 0;
   addedOrders = 0;
   if (short.tpUnits + grid.addedSet.units < 2)                      // one additional order set is not enough to re-balance the side
      sets = (2-short.tpUnits)/grid.addedSet.units;

   for (i=Grid.Levels; i >= 1 && short.tpUnits < 2; i--) {           // add short stop orders
      price = NormalizeDouble(grid.startPrice - i*grid.size*Pip, Digits);
      lots  = (sets+1)*i*StartLots;
      //debug("RebalanceGrid(5)  adding Stop Sell order, level: "+ i +", lots: "+ DoubleToStr(lots, 2));
      if (!AddOrder(OP_SHORT, NULL, i, lots, price, short.tpPrice, long.tpPrice, ORDER_PENDING)) return(false);
      addedOrders++;
      //debug("RebalanceGrid(6)  short.tpUnits now: "+ short.tpUnits);
   }
   //if (addedOrders > 0) debug("RebalanceGrid(7)  position: "+ ifString(total.position < 0, "", " ") + NumberToStr(total.position, ".1+") +" lot, added "+ addedOrders +" short order"+ ifString(addedOrders==1, "", "s") +", new tpUnits: "+ long.tpUnits +"/"+ short.tpUnits);

   return(!catch("RebalanceGrid(8)"));
}


/**
 * Add an order to the internally managed order stack. Stop orders at the same level are merged.
 *
 * @param  int    direction  - one of OP_LONG | OP_SHORT
 * @param  int    ticket
 * @param  int    level
 * @param  double lots
 * @param  double price
 * @param  double takeProfit
 * @param  double stopLoss
 * @param  int    status
 *
 * @return bool - success status
 */
bool AddOrder(int direction, int ticket, int level, double lots, double price, double takeProfit, double stopLoss, int status) {
   int sizeLong  = ArraySize(long.orders.ticket), levels;
   int sizeShort = ArraySize(short.orders.ticket), oe[ORDER_EXECUTION.intSize];
   lots  = NormalizeDouble(lots, 2);
   price = NormalizeDouble(price, Digits);

   double existingLots, newLots = lots;


   if (direction == OP_LONG) {
      levels        = (Grid.Levels+1) - level;
      long.tpUnits += MathRound(levels * lots/StartLots);               // increase long.tpUnits

      if (status == ORDER_PENDING) {
         if (!ticket) {
            // delete existing pending orders of the same level and remember lot sizes
            existingLots = 0;
            for (int i=sizeLong-1; i >= 0; i--) {
               if (long.orders.level[i]==level && long.orders.status[i]==status) {
                  if (!OrderDeleteEx(long.orders.ticket[i], CLR_NONE, NULL, oe))
                     return(!oe.Error(oe));
                  existingLots += long.orders.lots[i];
                  ArraySpliceInts   (long.orders.ticket,    i, 1);
                  ArraySpliceInts   (long.orders.level,     i, 1);
                  ArraySpliceDoubles(long.orders.lots,      i, 1);
                  ArraySpliceDoubles(long.orders.openPrice, i, 1);
                  ArraySpliceInts   (long.orders.status,    i, 1);
               }
            }
            if (existingLots > 0) {                                     // merge existing and new lot sizes into one order
               lots = NormalizeDouble(existingLots + lots, 2);
               //debug("AddOrder(1)  merging Stop Buy "+ NumberToStr(NormalizeDouble(existingLots, 2), ".1+") +" + "+ NumberToStr(NormalizeDouble(lots-existingLots, 2), ".1+") +" lot at level "+ level +" to "+ NumberToStr(lots, ".1+") +" lot");
            }
            ticket = OrderSendEx(Symbol(), OP_BUYSTOP, lots, price, NULL, stopLoss, takeProfit, os.comment +" L"+ level, os.magicNumber, NULL, Blue, NULL, oe);
            if (!ticket) return(!oe.Error(oe));
         }
         long.units.current[level] += MathRound(newLots/StartLots);
         str.long.units.swing       = IntsToStr(long.units.current, NULL);
      }
      else if (status == ORDER_OPEN) {
         levels            = (Grid.Levels+1) + level;
         short.tpUnits    -= MathRound(levels * lots/StartLots);        // decrease short.tpUnits
         long.position     = NormalizeDouble(long.position     + lots, 2);
         sequence.position = NormalizeDouble(sequence.position + lots, 2);
      }
      else return(!catch("AddOrder(2)  illegal parameter status: "+ status, ERR_INVALID_PARAMETER));

                 ArrayPushInt   (long.orders.ticket,    ticket);
                 ArrayPushInt   (long.orders.level,     level );
                 ArrayPushDouble(long.orders.lots,      lots  );
                 ArrayPushDouble(long.orders.openPrice, price );
      sizeLong = ArrayPushInt   (long.orders.status,    status);
      sequence.orders   = sizeLong + sizeShort;
      long.tpOrderSize += newLots;
      return(true);
   }


   if (direction == OP_SHORT) {
      levels         = (Grid.Levels+1) - level;
      short.tpUnits += MathRound(levels * lots/StartLots);              // increase short.tpUnits

      if (status == ORDER_PENDING) {
         if (!ticket) {
            // delete existing pending orders of the same level and remember lot sizes
            existingLots = 0;
            for (i=sizeShort-1; i >= 0; i--) {
               if (short.orders.level[i]==level && short.orders.status[i]==status) {
                  if (!OrderDeleteEx(short.orders.ticket[i], CLR_NONE, NULL, oe))
                     return(!oe.Error(oe));
                  existingLots += short.orders.lots[i];
                  ArraySpliceInts   (short.orders.ticket,    i, 1);
                  ArraySpliceInts   (short.orders.level,     i, 1);
                  ArraySpliceDoubles(short.orders.lots,      i, 1);
                  ArraySpliceDoubles(short.orders.openPrice, i, 1);
                  ArraySpliceInts   (short.orders.status,    i, 1);
               }
            }
            if (existingLots > 0) {                                     // merge existing and new lot sizes into one order
               lots = NormalizeDouble(existingLots + lots, 2);
               //debug("AddOrder(3)  merging Stop Sell "+ NumberToStr(NormalizeDouble(existingLots, 2), ".1+") +" + "+ NumberToStr(NormalizeDouble(lots-existingLots, 2), ".1+") +" lot at level "+ level +" to "+ NumberToStr(lots, ".1+") +" lot");
            }
            ticket = OrderSendEx(Symbol(), OP_SELLSTOP, lots, price, NULL, stopLoss, takeProfit, os.comment +" S"+ level, os.magicNumber, NULL, Red, NULL, oe);
            if (!ticket) return(!oe.Error(oe));
         }
         short.units.current[level] += MathRound(newLots/StartLots);
         str.short.units.swing       = IntsToStr(short.units.current, NULL);
      }
      else if (status == ORDER_OPEN) {
         levels            = (Grid.Levels+1) + level;
         long.tpUnits     -= MathRound(levels * lots/StartLots);        // decrease long.tpUnits
         sequence.position = NormalizeDouble(sequence.position - lots, 2);
         short.position    = NormalizeDouble(short.position    - lots, 2);
      }
      else return(!catch("AddOrder(4)  illegal parameter status: "+ status, ERR_INVALID_PARAMETER));

                  ArrayPushInt   (short.orders.ticket,    ticket);
                  ArrayPushInt   (short.orders.level,     level );
                  ArrayPushDouble(short.orders.lots,      lots  );
                  ArrayPushDouble(short.orders.openPrice, price );
      sizeShort = ArrayPushInt   (short.orders.status,    status);
      sequence.orders    = sizeLong + sizeShort;
      short.tpOrderSize -= newLots;
      return(true);
   }

   return(!catch("AddOrder(5)  illegal parameter direction: "+ direction, ERR_INVALID_PARAMETER));
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
   double profit, fees;

   // close remaining long orders
   int orders = ArraySize(long.orders.ticket);
   for (int i=0; i < orders; i++) {
      OrderSelect(long.orders.ticket[i], SELECT_BY_TICKET);
      if (!OrderCloseTime()) {
         if (OrderType() == OP_BUY) OrderCloseEx(long.orders.ticket[i], NULL, NULL, os.slippage, Orange, NULL, oe);
         else                       OrderDeleteEx(long.orders.ticket[i], CLR_NONE, NULL, oe);
      }
      if (OrderType() == OP_BUY) {
         profit += OrderProfit();
       //fees   += OrderCommission() + OrderSwap();
         fees   += OrderCommission();
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
         profit += OrderProfit();
       //fees   += OrderCommission() + OrderSwap();
         fees   += OrderCommission();
      }
      short.orders.status[i] = ORDER_CLOSED;
   }

   realized.grossProfit += profit;
   realized.fees        += fees;
   realized.netProfit    = NormalizeDouble(realized.grossProfit + realized.fees, 2);
   debug("CloseSequence(1)  "+ ifString(sequence.position > 0, "long", "short") +" profit="+ DoubleToStr(realized.netProfit, 2) +"  units="+ DoubleToStr(realized.netProfit/grid.unitValue, 1));


   // count down the sequence counter
   if (Trade.Sequences > 0)
      Trade.Sequences--;


   // reset order arrays and data if another sequence is going to be executed
   if (Trade.Sequences != 0) {
      ArrayResize(long.orders.ticket,     0);
      ArrayResize(long.orders.level,      0);
      ArrayResize(long.orders.lots,       0);
      ArrayResize(long.orders.openPrice,  0);
      ArrayResize(long.orders.status,     0);

      ArrayResize(short.orders.ticket,    0);
      ArrayResize(short.orders.level,     0);
      ArrayResize(short.orders.lots,      0);
      ArrayResize(short.orders.openPrice, 0);
      ArrayResize(short.orders.status,    0);

      ArrayInitialize(long.units.current,  0);
      ArrayInitialize(short.units.current, 0);
      str.long.units.swing  = "";
      str.short.units.swing = "";

      sequence.orders      = 0;
      sequence.position    = 0;
      sequence.pl          = EMPTY_VALUE;
      sequence.plMin       = EMPTY_VALUE;
      sequence.plMax       = EMPTY_VALUE;

      realized.units       = 0;
      realized.fees        = 0;
      realized.grossProfit = 0;
      realized.netProfit   = 0;

      lastLevel.filled     = 0;
      lastLevel.plUnits    = 0;

      long.position        = 0;
      long.tpPrice         = 0;
      long.tpUnits         = 0;
      long.tpOrderSize     = 0;

      short.position       = 0;
      short.tpPrice        = 0;
      short.tpUnits        = 0;
      short.tpOrderSize    = 0;
   }


   // else stop (this was the last sequence)
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

   string str.position.pl       = DoubleToStr(sequence.pl, 2), str.position.plMax="?",       str.position.plMin="?",
          str.position.plPct    = "?",                         str.position.plPctMax="?",    str.position.plPctMin="?",
          str.position.cumPlPct = "?",                         str.position.cumPlPctMax="?", str.position.cumPlPctMin="?", str.Cumulative="";

   static int iCumulative = -1; if (iCumulative == -1)
      iCumulative = (Trade.Sequences != 1);
   if (iCumulative == 1)
      str.Cumulative = StringConcatenate(" PL % cum:   ", str.position.cumPlPct, "     max:    ", str.position.cumPlPctMax, "      min:    ", str.position.cumPlPctMin, NL);


   // 4 lines margin-top
   Comment(NL, NL, NL, NL,
           "", __NAME__, str.status,                                                                                                  NL,
           " ------------",                                                                                                           NL,
           " Grid.Range:  ",    Grid.Range, " pip",                                                                                   NL,
           " Grid.Levels:  ",    Grid.Levels,                                                                                         NL,
           " StartLots:     ",   StartLots,                                                                                           NL,
           " PL:              ", str.position.pl,    "     max:    ", str.position.plMax,    "      min:    ", str.position.plMin,    NL,
           " PL %:          ",   str.position.plPct, "     max:    ", str.position.plPctMax, "      min:    ", str.position.plPctMin, NL,
           str.Cumulative);


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
   if (false && input.all == "") {
      return(StringConcatenate("input: ",

                               "Grid.Range=",      Grid.Range,                    "; ",
                               "Grid.Levels=",     Grid.Levels,                   "; ",
                               "StartLots=",       NumberToStr(StartLots, ".1+"), "; ",
                               "Trade.StartHour=", Trade.StartHour,               "; ",
                               "Trade.EndHour=",   Trade.EndHour,                 "; ",
                               "Trade.Sequences=", Trade.Sequences,               "; "));
   }
   return("");
}
