/**
 * The Trap - range trading with a twist
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern double Grid.Size       = 4;              // pips
extern int    Grid.Levels     = 3;
extern double StartLots       = 0.1;
extern int    Trade.Sequences = -1;             // number of sequences to trade (-1: unlimited)
extern int    Trade.StartHour = -1;             // hour to start a sequence (-1: any hour)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/xtrade/OrderExecution.mqh>

// grid management
int    grid.id;
double grid.startPrice;
int    grid.firstSet.units;                     // total number of units of the initial order set
int    grid.addedSet.units;                     // total number of units of one additional order set
double grid.unitValue;                          // unit value in account currency

int    total.orders;                            // total number of open orders of a sequence
double total.position;                          // total sequence position in lots (long + short)
double total.plUnits;                           // total sequence profit in units
double total.grossProfit;                       // total sequence gross profit in account currency
double total.fees;                              // total sequence trading costs in account currency
double total.netProfit;                         // total sequence net profit in account currency

// breakeven price

// order status
#define ORDER_PENDING         0
#define ORDER_OPEN            1
#define ORDER_CLOSED         -1

// order management
int    long.orders.ticket    [];                // order tickets
int    long.orders.level     [];                // order grid level
double long.orders.lots      [];                // order lot sizes
double long.orders.openPrice [];                // order open prices
int    long.orders.status    [];                // whether the order is pending, open or closed
double long.position;                           // full long position in lots
double long.tpPrice;                            // long TakeProfit price

int    short.orders.ticket   [];                // order tickets
int    short.orders.level    [];                // order grid level
double short.orders.lots     [];                // order lot sizes
double short.orders.openPrice[];                // order open prices
int    short.orders.status   [];                // whether the order is pending, open or closed
double short.position;                          // full short position in lots
double short.tpPrice;                           // short TakeProfit price

// trade function defaults
int    os.magicNumber = 1803;
double os.slippage    = 0.0;                    // in pip
string os.comment     = "";

// development
int test.startTime;
int test.orders;
int test.trades;


/**
 * Initialization.
 *
 * @return int - error status
 */
int onInit() {
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
   if (IsTesting()/* && !IsVisualMode()*/) debug("onDeinit(1)  "+ Tick +" ticks, "+ test.orders +" orders, "+ test.trades +" trades, time: "+ DoubleToStr((endTime-test.startTime)/1000., 3) +" sec");

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
   if (IsTesting()) {                              // 2017.09.18 14:41 @ 1.19531
      if (!test.startTime)                         // 2017.09.20 04:40 @ 1.20102
         test.startTime = GetTickCount();
      if (Tester.StartAtTime != 0) {
         if (Tick.Time < Tester.StartAtTime)
            return(last_error);
         Tester.StartAtTime = 0;
      }
      if (Tester.StartAtPrice != 0) {
         static double tester.lastPrice; if (!tester.lastPrice) {
            tester.lastPrice = Bid;
            return(last_error);
         }
         if (LT(tester.lastPrice, Tester.StartAtPrice) && LT(Bid, Tester.StartAtPrice)) {
            tester.lastPrice = Bid;
            return(last_error);
         }
         if (GT(tester.lastPrice, Tester.StartAtPrice) && GT(Bid, Tester.StartAtPrice)) {
            tester.lastPrice = Bid;
            return(last_error);
         }
         Tester.StartAtPrice = 0;
      }
   }

   double lots, stopPrice;
   int oe[ORDER_EXECUTION.intSize];


   // (1) without orders start a new sequence
   if (!total.orders) {
      if (Trade.Sequences && (Trade.StartHour==-1 || Trade.StartHour==Hour())) {
         grid.id++;
         grid.startPrice = NormalizeDouble((Bid + Ask)/2, Digits);
         grid.unitValue  = Grid.Size * PipValue(StartLots);
         long.tpPrice    = NormalizeDouble(grid.startPrice + (Grid.Levels+1)*Grid.Size*Pip, Digits);
         short.tpPrice   = NormalizeDouble(grid.startPrice - (Grid.Levels+1)*Grid.Size*Pip, Digits);
         os.comment      = __NAME__ +": "+ grid.id +" @"+ NumberToStr(grid.startPrice, PriceFormat);

         for (int i=1; i <= Grid.Levels; i++) {
            stopPrice = grid.startPrice + i*Grid.Size*Pip;
            if (!AddOrder(OP_LONG, NULL, i, StartLots, stopPrice, long.tpPrice, short.tpPrice, ORDER_PENDING)) return(last_error);
         }

         for (i=1; i <= Grid.Levels; i++) {
            stopPrice = grid.startPrice - i*Grid.Size*Pip;
            if (!AddOrder(OP_SHORT, NULL, i, StartLots, stopPrice, short.tpPrice, long.tpPrice, ORDER_PENDING)) return(last_error);
         }
         debug("onTick(1)   new sequence at "+ NumberToStr(grid.startPrice, PriceFormat) +"  target: "+ DoubleToStr(grid.firstSet.units, 0) +"/"+ DoubleToStr(grid.firstSet.units, 0) +" units, 1 unit: "+ DoubleToStr(grid.unitValue, 2));
      }
      if (!Trade.Sequences)
         return(SetLastError(ERR_CANCELLED_BY_USER));
      return(catch("onTick(2)"));
   }


   // (2) update the existing order's status
   bool stopsFilled = UpdateOrderStatus();
   if (!stopsFilled)                                                 // nothing to do
      return(last_error);


   // (3) stop orders have been filled: re-balance the sides
   double long.targetUnits  = GetTargetUnits(OP_LONG);
   double short.targetUnits = GetTargetUnits(OP_SHORT);
   //debug("onTick(2.1)  long.targetUnits: "+ DoubleToStr(long.targetUnits, 1) +", short.targetUnits: "+ DoubleToStr(short.targetUnits, 1));

   int sets, addedOrders;
   if (long.targetUnits + grid.addedSet.units < 2)                   // one additional order set is not enough to re-balance the side
      sets = (2-long.targetUnits)/grid.addedSet.units;

   for (i=Grid.Levels; i >= 1 && long.targetUnits < 2; i--) {        // add long stop orders
      stopPrice = NormalizeDouble(grid.startPrice + i*Grid.Size*Pip, Digits);
      if (Ask <= stopPrice) {
         lots = (sets+1)*i*StartLots;
         //debug("onTick(2.2)  adding Stop Buy order, level: "+ i +", lots: "+ DoubleToStr(lots, 2));
         if (!AddOrder(OP_LONG, NULL, i, lots, stopPrice, long.tpPrice, short.tpPrice, ORDER_PENDING)) return(false);
         addedOrders++;
         long.targetUnits += MathRound((sets+1)*i*(Grid.Levels+1-i));
         //debug("onTick(2.3)  new long target: "+ DoubleToStr(long.targetUnits, 1));
      }
   }
   if (addedOrders > 0) {
      string sPosition  = NumberToStr(total.position, ".1+"); if (total.position >= 0) sPosition = " "+ sPosition;
      double hedgedLots = MathMin(long.position, -short.position);
      if (hedgedLots != 0) sPosition = sPosition +" ±"+ NumberToStr(hedgedLots, ".1+");
      debug("onTick(3)  position: "+ sPosition +" lot, added "+ addedOrders +" long order"+ ifString(addedOrders==1, "", "s") +", new target: "+ DoubleToStr(long.targetUnits, 0) +"/"+ DoubleToStr(short.targetUnits, 0) +" units");
   }

   sets        = 0;
   addedOrders = 0;
   if (short.targetUnits + grid.addedSet.units < 2)                  // one additional order set is not enough to re-balance the side
      sets = (2-short.targetUnits)/grid.addedSet.units;

   for (i=Grid.Levels; i >= 1 && short.targetUnits < 2; i--) {       // add short stop orders
      stopPrice = NormalizeDouble(grid.startPrice - i*Grid.Size*Pip, Digits);
      if (Bid >= stopPrice) {
         lots = (sets+1)*i*StartLots;
         //debug("onTick(2.4)  adding Stop Sell order, level: "+ i +", lots: "+ DoubleToStr(lots, 2));
         if (!AddOrder(OP_SHORT, NULL, i, lots, stopPrice, short.tpPrice, long.tpPrice, ORDER_PENDING)) return(false);
         addedOrders++;
         short.targetUnits += MathRound((sets+1)*i*(Grid.Levels+1-i));
         //debug("onTick(2.5)  new short target: "+ DoubleToStr(short.targetUnits, 1));
      }
   }
   if (addedOrders > 0) {
      sPosition  = NumberToStr(total.position, ".1+"); if (total.position >= 0) sPosition = " "+ sPosition;
      hedgedLots = MathMin(long.position, -short.position);
      if (hedgedLots != 0) sPosition = sPosition +" ±"+ NumberToStr(hedgedLots, ".1+");
      debug("onTick(4)  position: "+ sPosition +" lot, added "+ addedOrders +" short order"+ ifString(addedOrders==1, "", "s") +", new target: "+ DoubleToStr(long.targetUnits, 0) +"/"+ DoubleToStr(short.targetUnits, 0) +" units");
   }

   return(catch("onTick(5)"));
}


/**
 * Update the existing order's status. Opposite open positions will be automatically resolved.
 *
 * @return bool - whether or not pending orders have been executed
 */
bool UpdateOrderStatus() {
   if (__STATUS_OFF) return(false);

   int longOrder=-1,  longSize  = ArraySize(long.orders.ticket);
   int shortOrder=-1, shortSize = ArraySize(short.orders.ticket), oe[ORDER_EXECUTION.intSize];
   bool stopsFilled = false;

   for (int i=0; i < longSize; i++) {
      OrderSelect(long.orders.ticket[i], SELECT_BY_TICKET);
      if (!OrderCloseTime()) {
         if (long.orders.status[i]==ORDER_PENDING) /*&&*/ if (OrderType()==OP_BUY) {
            long.orders.status[i] = ORDER_OPEN;
            long.position = NormalizeDouble(long.position + long.orders.lots[i], 2);
            stopsFilled   = true;
            test.trades++;
            //debug("UpdateOrderStatus(0.1)  #"+ long.orders.ticket[i] +" Stop Buy "+ DoubleToStr(long.orders.lots[i], 1) +" lot at level "+ long.orders.level[i] +" filled");
         }
      }
      else {
         if (IsPendingTradeOperation(OrderType()) && OrderComment()=="deleted [no money]") {
            LogTicket(OrderTicket());
            catch("UpdateOrderStatus(1)  #"+ OrderTicket() +" pending order was deleted", ERR_NOT_ENOUGH_MONEY);
         }
         return(_false(CloseSequence()));                               // close all if one was closed/deleted
      }
   }

   for (i=0; i < shortSize; i++) {
      OrderSelect(short.orders.ticket[i], SELECT_BY_TICKET);
      if (!OrderCloseTime()) {
         if (short.orders.status[i]==ORDER_PENDING) /*&&*/ if (OrderType()==OP_SELL) {
            short.orders.status[i] = ORDER_OPEN;
            short.position = NormalizeDouble(short.position - short.orders.lots[i], 2);
            stopsFilled    = true;
            test.trades++;
            //debug("UpdateOrderStatus(0.2)  #"+ short.orders.ticket[i] +" Stop Sell "+ DoubleToStr(short.orders.lots[i], 1) +" lot at level "+ short.orders.level[i] +" filled");
         }
      }
      else {
         if (IsPendingTradeOperation(OrderType()) && OrderComment()=="deleted [no money]") {
            LogTicket(OrderTicket());
            catch("UpdateOrderStatus(2)  #"+ OrderTicket() +" pending order was deleted", ERR_NOT_ENOUGH_MONEY);
         }
         return(_false(CloseSequence()));                               // close all if one was closed/deleted
      }
   }

   while (long.position && short.position) {                            // merge opposite open positions
      for (i=0; i < longSize; i++) {                                    // next long order to close
         if (long.orders.status[i] == ORDER_OPEN)  { longOrder = i; break; }
      }
      for (i=0; i < shortSize; i++) {                                   // next short order to close
         if (short.orders.status[i] == ORDER_OPEN) { shortOrder = i; break; }
      }
                                                                        // close opposite positions
      //debug("UpdateOrderStatus(3)  closing #"+ long.orders.ticket[longOrder] +" Buy "+ DoubleToStr(long.orders.lots[longOrder], 1) +" lot at level "+ long.orders.level[longOrder] +" by #"+ short.orders.ticket[shortOrder] +" Sell "+ DoubleToStr(short.orders.lots[shortOrder], 1) +" lot at level "+ short.orders.level[shortOrder]);
      if (!OrderCloseByEx(long.orders.ticket[longOrder], short.orders.ticket[shortOrder], Orange, NULL, oe))
         return(false);
      //ORDER_EXECUTION.toStr(oe, true);

      total.grossProfit += oe.Profit(oe);                               // store realized amounts
      total.fees        += oe.Swap(oe) + oe.Commission(oe);
      total.netProfit    = total.grossProfit + total.fees;
      double closedLots  = MathMin(long.orders.lots[longOrder], short.orders.lots[shortOrder]);
      double units       = (short.orders.openPrice[shortOrder] - long.orders.openPrice[longOrder]) * closedLots/StartLots/Grid.Size/Pip;
      total.plUnits     += units;

      //debug("UpdateOrderStatus(4)        profit: "+ DoubleToStr(oe.Profit(oe), 2) +"        fees: "+ DoubleToStr(oe.Swap(oe) + oe.Commission(oe), 2) +"        units: "+ DoubleToStr(units, 1));
      //debug("UpdateOrderStatus(5)  total.profit: "+ DoubleToStr(total.grossProfit, 2) +"  total.fees: "+ DoubleToStr(total.fees, 2) +"  total.units: "+ DoubleToStr(total.plUnits, 1));

      long.position  = NormalizeDouble(long.position  - closedLots, 2);
      short.position = NormalizeDouble(short.position + closedLots, 2);

      int ticket = oe.RemainingTicket(oe);
      if (!ticket) {                                                    // no remaining position
         //debug("UpdateOrderStatus(6)  no remaining ticket");
         ArraySpliceInts   (long.orders.ticket,     longOrder, 1);
         ArraySpliceInts   (long.orders.level,      longOrder, 1);      // drop long ticket
         ArraySpliceDoubles(long.orders.lots,       longOrder, 1);
         ArraySpliceDoubles(long.orders.openPrice,  longOrder, 1);
         ArraySpliceInts   (long.orders.status,     longOrder, 1);

         ArraySpliceInts   (short.orders.ticket,    shortOrder, 1);     // drop short ticket
         ArraySpliceInts   (short.orders.level,     shortOrder, 1);
         ArraySpliceDoubles(short.orders.lots,      shortOrder, 1);
         ArraySpliceDoubles(short.orders.openPrice, shortOrder, 1);
         ArraySpliceInts   (short.orders.status,    shortOrder, 1);
         total.orders--;
         test.trades--;
      }
      else if (OrderSelect(ticket, SELECT_BY_TICKET)) {
         //debug("UpdateOrderStatus(7)  remaining ticket:");
         //LogOrder(ticket);

         if (OrderType() == OP_BUY) {                                   // remaining long position
            long.orders.ticket[longOrder] = ticket;                     // replace long ticket
            long.orders.lots  [longOrder] = OrderLots();

            ArraySpliceInts   (short.orders.ticket,    shortOrder, 1);  // drop short ticket
            ArraySpliceInts   (short.orders.level,     shortOrder, 1);
            ArraySpliceDoubles(short.orders.lots,      shortOrder, 1);
            ArraySpliceDoubles(short.orders.openPrice, shortOrder, 1);
            ArraySpliceInts   (short.orders.status,    shortOrder, 1);
         }
         else {                                                         // remaining short position
            ArraySpliceInts   (long.orders.ticket,     longOrder, 1);   // drop long ticket
            ArraySpliceInts   (long.orders.level,      longOrder, 1);
            ArraySpliceDoubles(long.orders.lots,       longOrder, 1);
            ArraySpliceDoubles(long.orders.openPrice,  longOrder, 1);
            ArraySpliceInts   (long.orders.status,     longOrder, 1);

            short.orders.ticket[shortOrder] = ticket;                   // replace short ticket
            short.orders.lots  [shortOrder] = OrderLots();
         }
      }
      else return(_false(catch("UpdateOrderStatus(2)")));
   }

   //if (IsTesting() && stopsFilled) Tester.Pause();

   total.position = NormalizeDouble(long.position + short.position, 2);
   return(stopsFilled);
}


/**
 * Add an order to the internally managed order stack. If a stop order is added all stop orders of the corresponding level
 * are merged into one.
 *
 * @param  int    direction
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
   int sizeLong  = ArraySize(long.orders.ticket);
   int sizeShort = ArraySize(short.orders.ticket), oe[ORDER_EXECUTION.intSize];
   lots  = NormalizeDouble(lots, 2);
   price = NormalizeDouble(price, Digits);

   if (direction == OP_LONG) {
      if (status==ORDER_PENDING && !ticket) {
         // merge existing pending lots of the corresponding level and send pending order
         double existingLots = 0;
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
               test.orders--;
            }
         }
         if (existingLots > 0) {
            lots = NormalizeDouble(existingLots + lots, 2);
            //debug("AddOrder(1)  merging Stop Buy "+ NumberToStr(NormalizeDouble(existingLots, 2), ".1+") +" + "+ NumberToStr(NormalizeDouble(lots-existingLots, 2), ".1+") +" lot at level "+ level +" to "+ NumberToStr(lots, ".1+") +" lot");
         }
         ticket = OrderSendEx(Symbol(), OP_BUYSTOP, lots, price, NULL, stopLoss, takeProfit, os.comment, os.magicNumber, NULL, Blue, NULL, oe);
         if (!ticket) return(!oe.Error(oe));
      }
      else if (status == ORDER_OPEN) {
         total.position = NormalizeDouble(total.position + lots, 2);
         long.position  = NormalizeDouble(long.position  + lots, 2);
      }
                 ArrayPushInt   (long.orders.ticket,    ticket);
                 ArrayPushInt   (long.orders.level,     level );
                 ArrayPushDouble(long.orders.lots,      lots  );
                 ArrayPushDouble(long.orders.openPrice, price );
      sizeLong = ArrayPushInt   (long.orders.status,    status);
      total.orders = sizeLong + sizeShort;
      test.orders++;
      return(true);
   }


   if (direction == OP_SHORT) {
      if (status==ORDER_PENDING && !ticket) {
         // merge existing pending lots of the corresponding level and send pending order
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
               test.orders--;
            }
         }
         if (existingLots > 0) {
            lots = NormalizeDouble(existingLots + lots, 2);
            //debug("AddOrder(2)  merging Stop Sell "+ NumberToStr(NormalizeDouble(existingLots, 2), ".1+") +" + "+ NumberToStr(NormalizeDouble(lots-existingLots, 2), ".1+") +" lot at level "+ level +" to "+ NumberToStr(lots, ".1+") +" lot");
         }
         ticket = OrderSendEx(Symbol(), OP_SELLSTOP, lots, price, NULL, stopLoss, takeProfit, os.comment, os.magicNumber, NULL, Red, NULL, oe);
         if (!ticket) return(!oe.Error(oe));
      }
      else if (status == ORDER_OPEN) {
         total.position = NormalizeDouble(total.position - lots, 2);
         short.position = NormalizeDouble(short.position - lots, 2);
      }
                  ArrayPushInt   (short.orders.ticket,    ticket);
                  ArrayPushInt   (short.orders.level,     level );
                  ArrayPushDouble(short.orders.lots,      lots  );
                  ArrayPushDouble(short.orders.openPrice, price );
      sizeShort = ArrayPushInt   (short.orders.status,    status);
      total.orders = sizeLong + sizeShort;
      test.orders++;
      return(true);
   }

   return(!catch("AddOrder(3)  illegal parameter direction: "+ direction, ERR_INVALID_PARAMETER));
}


/**
 * Get the expected profit in units when TakeProfit is reached (1 unit = StartLots * Grid.Size).
 *
 * @param  int direction - TakeProfit side being reached: OP_LONG | OP_SHORT
 *
 * @return double
 */
double GetTargetUnits(int direction) {
   double units;
   int sizeLong  = ArraySize(long.orders.ticket);
   int sizeShort = ArraySize(short.orders.ticket);

   // profit units when TakeProfit is reached on the long side
   if (direction == OP_LONG) {
      for (int i=0; i < sizeLong; i++) {
         if (long.orders.status[i] != ORDER_CLOSED) units += (long.tpPrice-long.orders.openPrice[i]) * long.orders.lots[i];
      }
      for (i=0; i < sizeShort; i++) {
         if (short.orders.status[i] == ORDER_OPEN)  units -= (long.tpPrice-short.orders.openPrice[i]) * short.orders.lots[i];
      }
      return(total.plUnits + units/StartLots/Grid.Size/Pip);
   }

   // profit units when TakeProfit is reached on the short side
   if (direction == OP_SHORT) {
      for (i=0; i < sizeShort; i++) {
         if (short.orders.status[i] != ORDER_CLOSED) units += (short.orders.openPrice[i]-short.tpPrice) * short.orders.lots[i];
      }
      for (i=0; i < sizeLong; i++) {
         if (long.orders.status[i] == ORDER_OPEN)    units -= (long.orders.openPrice[i]-short.tpPrice) * long.orders.lots[i];
      }
      return(total.plUnits + units/StartLots/Grid.Size/Pip);
   }

   return(!catch("GetTargetUnits(1)  illegal parameter direction: "+ direction, ERR_INVALID_PARAMETER));
}


/**
 * Close the remaining pending orders and open positions of the sequence.
 *
 * @return int - error status
 *
 *
 * TODO: close open positions optimized and before deletion of pending orders
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
         fees   += OrderCommission() + OrderSwap();
         if (long.orders.status[i] == ORDER_PENDING) test.trades++;
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
         fees   += OrderCommission() + OrderSwap();
         if (short.orders.status[i]==ORDER_PENDING) test.trades++;
      }
      short.orders.status[i] = ORDER_CLOSED;
   }
   debug("CloseSequence(1)  gross profit: "+ DoubleToStr(total.grossProfit + profit, 2) +", fees: "+ DoubleToStr(total.fees + fees, 2));

   // reset order arrays
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

   total.orders      = 0;
   total.position    = 0;
   total.plUnits     = 0;
   total.grossProfit = 0;
   total.fees        = 0;
   total.netProfit   = 0;

   long.position     = 0;
   long.tpPrice      = 0;

   short.position    = 0;
   short.tpPrice     = 0;

   // count down the sequence counter
   if (Trade.Sequences > 0)
      Trade.Sequences--;
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

   // 4 lines margin-top
   Comment(NL, NL, NL, NL,
           "", __NAME__, str.status,                                         NL,
           " ------------",                                                  NL,
           " Balance:       ",   AccountBalance(),                           NL,
           " Profit:          ", AccountProfit(),                            NL,
           " Equity:        ",   AccountEquity(),                            NL,
           " Grid.Size:     ",   DoubleToStr(Grid.Size, Digits & 1), " pip", NL,
           " Grid.Levels:  ",    Grid.Levels,                                NL,
           " StartLots:     ",   StartLots,                                  NL);

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

                               "Grid.Size=",       NumberToStr(Grid.Size, ".1+"), "; ",
                               "Grid.Levels=",     Grid.Levels,                   "; ",
                               "StartLots=",       NumberToStr(StartLots, ".1+"), "; ",
                               "Trade.Sequences=", Trade.Sequences,               "; ",
                               "Trade.StartHour=", Trade.StartHour,               "; "));
   }
   return("");
}


/*
original:
2017.09.18-2017.09.19  EURUSD,M1: 223594 ticks, 385 orders, 164 trades, time: 42.869 sec

don't use the history:
2017.09.18-2017.09.19  EURUSD,M1: 223594 ticks, 385 orders, 164 trades, time: 8.222 sec

order management only after execution of pending orders:
2017.09.18-2017.09.19  EURUSD,M1: 223594 ticks, 385 orders, 164 trades, time: 1.918 sec

use the framework's order functions:
2017.09.18-2017.09.19  EURUSD,M1: 223594 ticks, 385 orders, 164 trades, time: 2.434 sec

merge pending orders:
2017.09.18-2017.09.19  EURUSD,M1: 223594 ticks, 195 orders, 120 trades, time: 2.059 sec

optimize open positions:
2017.09.18-2017.09.19  EURUSD,M1: 223594 ticks, 200 orders, 106 trades, time: 1.544 sec


original orders:
20.09.17 00:00:00 Tester::EURUSD,M1::The Trap::MarketInfo()  Time=Wed, 20.09.2017 00:00  Spread=0.1  MinLot=0.01  LotStep=0.01  StopLevel=0  FreezeLevel=0  PipValue=8.16206598 EUR  Account=10,000 EUR  Leverage=1:489  Stopout=50%  MarginHedged=none
20.09.17 04:40:02 Tester::EURUSD,M1::The Trap::onTick(1)   new sequence at 1.2010'3  target: 6/6 units, 1 unit: 3.26
20.09.17 04:40:37 Tester::EURUSD,M1::The Trap::onTick(3)  position: -0.1 lot, added 1 long order, new target: 4/6 units
20.09.17 04:41:39 Tester::EURUSD,M1::The Trap::onTick(4)  position:  0.0 ±0.1 lot, added 1 short order, new target: 4/4 units
20.09.17 04:44:39 Tester::EURUSD,M1::The Trap::onTick(4)  position:  0.1 ±0.1 lot, added 2 short orders, new target: 4/5 units
20.09.17 09:18:28 Tester::EURUSD,M1::The Trap::onTick(3)  position: -0.2 ±0.2 lot, added 3 long orders, new target: 6/5 units
20.09.17 09:39:18 Tester::EURUSD,M1::The Trap::onTick(3)  position: -0.9 ±0.2 lot, added 3 long orders, new target: 7/5 units
20.09.17 12:35:29 Tester::EURUSD,M1::The Trap::onTick(4)  position: -0.2 ±0.9 lot, added 3 short orders, new target: 7/10 units
20.09.17 12:48:05 Tester::EURUSD,M1::The Trap::onTick(4)  position:  1.2 ±1.1 lot, added 3 short orders, new target: 7/6 units
20.09.17 13:15:29 Tester::EURUSD,M1::The Trap::onTick(3)  position:  0.0 ±2.3 lot, added 3 long orders, new target: 7/6 units
20.09.17 13:28:29 Tester::EURUSD,M1::The Trap::onTick(3)  position: -2.4 ±2.3 lot, added 3 long orders, new target: 3/6 units
20.09.17 15:22:39 Tester::EURUSD,M1::The Trap::onTick(3)  position: -6.0 ±2.3 lot, added 3 long orders, new target: 11/6 units
20.09.17 15:40:16 Tester::EURUSD,M1::The Trap::CloseSequence(1)  sequence closed, profit: 13.08, fees: -45.58
20.09.17 15:40:21 Tester::EURUSD,M1::The Trap::onDeinit(1)  63112 ticks, 31 orders, 18 trades, time: 1.373 sec


merged pending orders:
20.09.17 00:00:00 Tester::EURUSD,M1::The Trap::MarketInfo()  Time=Wed, 20.09.2017 00:00  Spread=0.1  MinLot=0.01  LotStep=0.01  StopLevel=0  FreezeLevel=0  PipValue=8.16206598 EUR  Account=10,000 EUR  Leverage=1:489  Stopout=50%  MarginHedged=none
20.09.17 04:40:02 Tester::EURUSD,M1::The Trap::onTick(1)   new sequence at 1.2010'3  target: 6/6 units, 1 unit: 3.26
20.09.17 04:40:37 Tester::EURUSD,M1::The Trap::onTick(3)  position: -0.1 lot, added 1 long order, new target: 4/6 units
20.09.17 04:41:39 Tester::EURUSD,M1::The Trap::onTick(4)  position:  0.0 ±0.1 lot, added 1 short order, new target: 4/4 units
20.09.17 04:44:39 Tester::EURUSD,M1::The Trap::onTick(4)  position:  0.1 ±0.1 lot, added 2 short orders, new target: 4/5 units
20.09.17 09:18:28 Tester::EURUSD,M1::The Trap::onTick(3)  position: -0.2 ±0.2 lot, added 3 long orders, new target: 6/5 units
20.09.17 09:39:18 Tester::EURUSD,M1::The Trap::onTick(3)  position: -0.9 ±0.2 lot, added 3 long orders, new target: 7/5 units
20.09.17 12:35:29 Tester::EURUSD,M1::The Trap::onTick(4)  position: -0.2 ±0.9 lot, added 3 short orders, new target: 7/10 units
20.09.17 12:48:05 Tester::EURUSD,M1::The Trap::onTick(4)  position:  1.2 ±1.1 lot, added 3 short orders, new target: 7/6 units
20.09.17 13:15:29 Tester::EURUSD,M1::The Trap::onTick(3)  position:  0.0 ±2.3 lot, added 3 long orders, new target: 7/6 units
20.09.17 13:28:29 Tester::EURUSD,M1::The Trap::onTick(3)  position: -2.4 ±2.3 lot, added 3 long orders, new target: 3/6 units
20.09.17 15:22:39 Tester::EURUSD,M1::The Trap::onTick(3)  position: -6.0 ±2.3 lot, added 3 long orders, new target: 11/6 units
20.09.17 15:40:16 Tester::EURUSD,M1::The Trap::CloseSequence(1)  sequence closed, profit: 13.09, fees: -45.58
20.09.17 15:40:21 Tester::EURUSD,M1::The Trap::onDeinit(1)  63112 ticks, 13 orders, 10 trades, time: 1.076 sec


optimized open positions:
20.09.17 00:00:00 Tester::EURUSD,M1::The Trap::MarketInfo()  Time=Wed, 20.09.2017 00:00  Spread=0.1  MinLot=0.01  LotStep=0.01  StopLevel=0  FreezeLevel=0  PipValue=8.1323954 EUR  Account=10,000 EUR  Leverage=1:488  Stopout=50%  MarginHedged=none
20.09.17 04:40:02 Tester::EURUSD,M1::The Trap::onTick(1)   new sequence at 1.2010'3  target: 6/6 units, 1 unit: 3.25
20.09.17 04:40:37 Tester::EURUSD,M1::The Trap::onTick(3)  position: -0.1 lot, added 1 long order, new target: 4/6 units
20.09.17 04:41:39 Tester::EURUSD,M1::The Trap::onTick(4)  position:  0.0 lot, added 1 short order, new target: 4/4 units
20.09.17 04:44:39 Tester::EURUSD,M1::The Trap::onTick(4)  position:  0.1 lot, added 2 short orders, new target: 4/5 units
20.09.17 09:18:28 Tester::EURUSD,M1::The Trap::onTick(3)  position: -0.2 lot, added 3 long orders, new target: 6/5 units
20.09.17 09:39:18 Tester::EURUSD,M1::The Trap::onTick(3)  position: -0.9 lot, added 3 long orders, new target: 7/5 units
20.09.17 12:35:29 Tester::EURUSD,M1::The Trap::onTick(4)  position: -0.2 lot, added 3 short orders, new target: 7/10 units
20.09.17 12:48:05 Tester::EURUSD,M1::The Trap::onTick(4)  position:  1.2 lot, added 3 short orders, new target: 7/6 units
20.09.17 13:15:29 Tester::EURUSD,M1::The Trap::onTick(3)  position:  0.0 lot, added 3 long orders, new target: 7/6 units
20.09.17 13:28:29 Tester::EURUSD,M1::The Trap::onTick(3)  position: -2.4 lot, added 3 long orders, new target: 3/6 units
20.09.17 15:22:39 Tester::EURUSD,M1::The Trap::onTick(3)  position: -6.0 lot, added 3 long orders, new target: 11/6 units
20.09.17 15:40:17 Tester::EURUSD,M1::The Trap::CloseSequence(1)  sequence closed, profit: 20.36, fees: -35.69
20.09.17 16:03:52 Tester::EURUSD,M1::The Trap::onDeinit(1)  63113 ticks, 13 orders, 7 trades, time: 0.374 sec
*/
