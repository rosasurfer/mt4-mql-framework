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
extern string _____________________________1_;

extern string Tester.StartAtTime;               // date/time to start
extern string Tester.StartAtPrice;              // sequence start price

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>

// grid management
int    grid.id;
double grid.startPrice;
int    grid.firstSet.units;                     // total number of units of the initial order set
int    grid.addedSet.units;                     // total number of units of one additional order set

// order tracking
int    long.orders.ticket    [];                // order tickets
int    long.orders.level     [];                // order grid level
double long.orders.lots      [];                // order lot sizes
double long.orders.openPrice [];                // order open prices
int    long.orders.status    [];                // whether the order is pending, open or closed
double long.tpPrice;                            // long TakeProfit price

int    short.orders.ticket   [];                // order tickets
int    short.orders.level    [];                // order grid level
double short.orders.lots     [];                // order lot sizes
double short.orders.openPrice[];                // order open prices
int    short.orders.status   [];                // whether the order is pending, open or closed
double short.tpPrice;                           // short TakeProfit price

// order status
#define ORDER_PENDING      0
#define ORDER_OPEN         1
#define ORDER_CLOSED      -1

// current position
// current pl
// breakeven price


// OrderSend() defaults
int    os.magicNumber = 1803;
double os.slippage    = 0.3;
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
   if (IsTesting() && !IsVisualMode()) debug("onDeinit(1)  "+ Tick +" ticks, "+ test.orders +" orders, ? trades, time: "+ DoubleToStr((endTime-test.startTime)/1000., 3) +" sec");

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
   double lots, stopPrice, takeProfit, stopLoss, long.targetUnits, short.targetUnits;
   int ticket, oe[ORDER_EXECUTION.intSize]; if (!test.startTime) test.startTime = GetTickCount();


   // (1) without orders start a new sequence
   if (!ArraySize(long.orders.ticket) && !ArraySize(short.orders.ticket)) {
      if (Trade.Sequences && (Trade.StartHour==-1 || Trade.StartHour==Hour())) {
         grid.id++;
         grid.startPrice = NormalizeDouble((Bid + Ask)/2, Digits);
         long.tpPrice    = NormalizeDouble(grid.startPrice + (Grid.Levels+1)*Grid.Size*Pip, Digits);
         short.tpPrice   = NormalizeDouble(grid.startPrice - (Grid.Levels+1)*Grid.Size*Pip, Digits);
         os.comment      = __NAME__ +": "+ grid.id +" @"+ NumberToStr(grid.startPrice, PriceFormat);

         takeProfit = long.tpPrice;
         stopLoss   = short.tpPrice;
         for (int i=1; i <= Grid.Levels; i++) {
            stopPrice = NormalizeDouble(grid.startPrice + i*Grid.Size*Pip, Digits);
            ticket    = OrderSendEx(Symbol(), OP_BUYSTOP, StartLots, stopPrice, NULL, stopLoss, takeProfit, os.comment, os.magicNumber, NULL, Blue, NULL, oe);
            if (!ticket) return(last_error);
            PushTicket(OP_LONG, ticket, i, StartLots, stopPrice, ORDER_PENDING);
         }

         takeProfit = short.tpPrice;
         stopLoss   = long.tpPrice;
         for (i=1; i <= Grid.Levels; i++) {
            stopPrice = NormalizeDouble(grid.startPrice - i*Grid.Size*Pip, Digits);
            ticket    = OrderSendEx(Symbol(), OP_SELLSTOP, StartLots, stopPrice, NULL, stopLoss, takeProfit, os.comment, os.magicNumber, NULL, Red, NULL, oe);
            if (!ticket) return(last_error);
            PushTicket(OP_SHORT, ticket, i, StartLots, stopPrice, ORDER_PENDING);
         }
         debug("onTick(1)   new sequence at "+ NumberToStr(grid.startPrice, PriceFormat) +"  targets: "+ DoubleToStr(grid.firstSet.units, 0) +"/"+ DoubleToStr(grid.firstSet.units, 0) +" units");
      }
      if (!Trade.Sequences)
         return(SetLastError(ERR_CANCELLED_BY_USER));
      return(catch("onTick(2)"));
   }


   // (2) update the existing order's status
   bool ordersTriggered = UpdateOrderStatus();
   if (!ordersTriggered)                                             // nothing to do
      return(last_error);


   // (3) pending orders have been executed: re-balance the sequence
   long.targetUnits  = GetTargetUnits(OP_LONG);
   short.targetUnits = GetTargetUnits(OP_SHORT);

   int sets, addedOrders;
   if (long.targetUnits + grid.addedSet.units < 2)                   // a single order set is not enough to re-balance the side
      sets = (2-long.targetUnits)/grid.addedSet.units;

   for (i=Grid.Levels; i >= 1 && long.targetUnits < 2; i--) {        // add long stop orders
      stopPrice = NormalizeDouble(grid.startPrice + i*Grid.Size*Pip, Digits);
      if (Ask <= stopPrice) {
         lots       = NormalizeDouble((sets+1)*i*StartLots, 2);
         takeProfit = long.tpPrice;
         stopLoss   = short.tpPrice;
         ticket = OrderSendEx(Symbol(), OP_BUYSTOP, lots, stopPrice, NULL, stopLoss, takeProfit, os.comment, os.magicNumber, NULL, Blue, NULL, oe);
         if (!ticket) return(last_error);
         PushTicket(OP_LONG, ticket, i, lots, stopPrice, ORDER_PENDING);

         long.targetUnits += MathRound((sets+1)*i*(Grid.Levels+1-i));
         addedOrders++;
      }
   }
   if (addedOrders > 0) debug("onTick(3)  Tick="+ Tick +"  position: "+ GetPositionUnits() +" units, added "+ addedOrders +" long orders, new targets: "+ DoubleToStr(long.targetUnits, 0) +"/"+ DoubleToStr(short.targetUnits, 0) +" units");

   sets = 0;
   if (short.targetUnits + grid.addedSet.units < 2)                  // a single order set is not enough to re-balance the side
      sets = (2-short.targetUnits)/grid.addedSet.units;

   addedOrders = 0;
   for (i=Grid.Levels; i >= 1 && short.targetUnits < 2; i--) {       // add short stop orders
      stopPrice = NormalizeDouble(grid.startPrice - i*Grid.Size*Pip, Digits);
      if (Bid >= stopPrice) {
         lots       = NormalizeDouble((sets+1)*i*StartLots, 2);
         takeProfit = short.tpPrice;
         stopLoss   = long.tpPrice;
         ticket = OrderSendEx(Symbol(), OP_SELLSTOP, lots, stopPrice, NULL, stopLoss, takeProfit, os.comment, os.magicNumber, NULL, Red, NULL, oe);
         if (!ticket) return(last_error);
         PushTicket(OP_SHORT, ticket, i, lots, stopPrice, ORDER_PENDING);

         short.targetUnits += MathRound((sets+1)*i*(Grid.Levels+1-i));
         addedOrders++;
      }
   }
   if (addedOrders > 0) debug("onTick(4)  Tick="+ Tick +"  position: "+ GetPositionUnits() +" units, added "+ addedOrders +" short orders, new targets: "+ DoubleToStr(long.targetUnits, 0) +"/"+ DoubleToStr(short.targetUnits, 0) +" units");

   return(catch("onTick(5)"));
}


/**
 * Update the existing order's status.
 *
 * @return bool - whether or not a pending oder has been executed
 */
bool UpdateOrderStatus() {
   if (__STATUS_OFF) return(false);

   bool ordersTriggered = false;

   int size = ArraySize(long.orders.ticket);
   for (int i=0; i < size; i++) {
      OrderSelect(long.orders.ticket[i], SELECT_BY_TICKET);
      if (!OrderCloseTime()) {
         if (long.orders.status[i]==ORDER_PENDING) /*&&*/ if (OrderType()==OP_BUY) {
            long.orders.status[i] = ORDER_OPEN;
            ordersTriggered = true;
         }
      }
      else return(_false(CloseSequence()));                          // close all if one was closed
   }

   size = ArraySize(short.orders.ticket);
   for (i=0; i < size; i++) {
      OrderSelect(short.orders.ticket[i], SELECT_BY_TICKET);
      if (!OrderCloseTime()) {
         if (short.orders.status[i]==ORDER_PENDING) /*&&*/ if (OrderType()==OP_SELL) {
            short.orders.status[i] = ORDER_OPEN;
            ordersTriggered = true;
         }
      }
      else return(_false(CloseSequence()));                          // close all if one was closed
   }

   return(ordersTriggered);
}


/**
 * Push a ticket onto the internal order stack.
 *
 * @param  int    direction
 * @param  int    ticket
 * @param  int    level
 * @param  double lots
 * @param  double price
 * @param  int    status
 *
 * @return bool - success status
 */
bool PushTicket(int direction, int ticket, int level, double lots, double price, int status) {
   if (direction == OP_LONG) {
      ArrayPushInt   (long.orders.ticket,    ticket);
      ArrayPushInt   (long.orders.level,     level );
      ArrayPushDouble(long.orders.lots,      lots  );
      ArrayPushDouble(long.orders.openPrice, price );
      ArrayPushInt   (long.orders.status,    status);
   }
   else if (direction == OP_SHORT) {
      ArrayPushInt   (short.orders.ticket,    ticket);
      ArrayPushInt   (short.orders.level,     level );
      ArrayPushDouble(short.orders.lots,      lots  );
      ArrayPushDouble(short.orders.openPrice, price );
      ArrayPushInt   (short.orders.status,    status);
   }
   else return(!catch("PushTicket(1)  illegal parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   test.orders++;
   return(true);
}


/**
 * Get the currently open position in units (1 unit = StartLots).
 *
 * @return int
 */
int GetPositionUnits() {
   if (__STATUS_OFF) return(NULL);
   double lots;

   int size = ArraySize(long.orders.ticket);
   for (int i=0; i < size; i++) {
      if (long.orders.status[i] == ORDER_OPEN) lots += long.orders.lots[i];
   }
   size = ArraySize(short.orders.ticket);
   for (i=0; i < size; i++) {
      if (short.orders.status[i] == ORDER_OPEN) lots -= short.orders.lots[i];
   }
   return(MathRound(lots/StartLots));
}


/**
 *
 */
double GetProfitUnits() {
   double unitPip;
   int orders = OrdersTotal();

   // current floating profit in units (1 unit = StartLots * Grid.Size)
   for (int i=0; i < orders; i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber && StringStartsWith(OrderComment(), os.comment)) {
         if (OrderType()==OP_BUY)  unitPip += (Bid - OrderOpenPrice())/Pip * OrderLots()/StartLots;
         if (OrderType()==OP_SELL) unitPip += (OrderOpenPrice() - Ask)/Pip * OrderLots()/StartLots;
      }
   }
   catch("GetProfitUnits(1)");
   return(unitPip/Grid.Size);
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
      return(units/Pip/StartLots/Grid.Size);
   }

   // profit units when TakeProfit is reached on the short side
   if (direction == OP_SHORT) {
      for (i=0; i < sizeShort; i++) {
         if (short.orders.status[i] != ORDER_CLOSED) units += (short.orders.openPrice[i]-short.tpPrice) * short.orders.lots[i];
      }
      for (i=0; i < sizeLong; i++) {
         if (long.orders.status[i] == ORDER_OPEN)    units -= (long.orders.openPrice[i]-short.tpPrice) * long.orders.lots[i];
      }
      return(units/Pip/StartLots/Grid.Size);
   }

   return(!catch("GetTargetUnits(1)  illegal parameter direction: "+ direction, ERR_INVALID_PARAMETER));
}


/**
 * Close the remaining pending orders and open positions of the sequence.
 *
 * @return int - error status
 */
int CloseSequence() {
   int oe[ORDER_EXECUTION.intSize];

   // close remaining long orders
   int orders = ArraySize(long.orders.ticket);
   for (int i=0; i < orders; i++) {
      OrderSelect(long.orders.ticket[i], SELECT_BY_TICKET);
      if (!OrderCloseTime()) {
         if (OrderType() == OP_BUY) OrderCloseEx(long.orders.ticket[i], NULL, NULL, os.slippage, Orange, NULL, oe);
         else                       OrderDeleteEx(long.orders.ticket[i], CLR_NONE, NULL, oe);
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
      short.orders.status[i] = ORDER_CLOSED;
   }

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

   long.tpPrice  = 0;
   short.tpPrice = 0;

   // count down the sequence counter
   if (Trade.Sequences > 0)
      Trade.Sequences--;
   return(catch("CloseSequence(1)"));
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
   return("");
   // dummy calls
   GetProfitUnits();
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
*/
