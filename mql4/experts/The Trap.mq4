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
int    long.order.ticket    [];                 // order tickets
int    long.order.level     [];                 // order grid level
double long.order.lots      [];                 // order lot sizes
double long.order.openPrice [];                 // order open prices
int    long.order.status    [];                 // whether the order is pending, open or closed

int    short.order.ticket   [];                 // order tickets
int    short.order.level    [];                 // order grid level
double short.order.lots     [];                 // order lot sizes
double short.order.openPrice[];                 // order open prices
int    short.order.status   [];                 // whether the order is pending, open or closed

// order status
#define ORDER_PENDING      0
#define ORDER_OPEN         1
#define ORDER_CLOSED      -1

// current position
// current pl
// breakeven price

double short.tpPrice;                           // TakeProfit prices
double long.tpPrice;

// OrderSend() defaults
int    os.magicNumber = 1803;
double os.slippage    = 3;
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
   if (IsTesting()) debug("onDeinit(1)  "+ Tick +" ticks, "+ test.orders +" orders, ? trades, time: "+ DoubleToStr((endTime-test.startTime)/1000., 3) +" sec");

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
   double price, stopPrice, tp, sl, long.targetUnits, short.targetUnits;
   int error, ticket, orders = OrdersTotal(); if (!test.startTime) test.startTime = GetTickCount();

   if (!IsTesting()) {                                               // in Tester the result of OrdersTotal() is sufficient
      for (int i=0; i < orders; i++) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber)
            break;
      }
      if (i >= orders) orders = 0;
   }

   // start new sequence if no orders exist
   if (!orders) {
      if (Trade.Sequences && (Trade.StartHour==-1 || Trade.StartHour==Hour())) {
         grid.id++;
         grid.startPrice = Ask;
         long.tpPrice    = NormalizeDouble(grid.startPrice + (Grid.Levels+1)*Grid.Size*Pip, Digits);
         short.tpPrice   = NormalizeDouble(grid.startPrice - (Grid.Levels+1)*Grid.Size*Pip, Digits);
         os.comment      = "sid: "+ grid.id +" @"+ DoubleToStr(grid.startPrice, Digits);

         tp = long.tpPrice;
         sl = short.tpPrice;
         for (i=1; i <= Grid.Levels; i++) {
            price  = NormalizeDouble(grid.startPrice + i*Grid.Size*Pip, Digits);
            ticket = OrderSend(Symbol(), OP_BUYSTOP, StartLots, price, NULL, sl, tp, os.comment, os.magicNumber);
            error  = GetLastError(); if (ticket < 1 || error) return(catch("onTick(1)  Tick="+ Tick +"  ticket="+ ticket +"  stopPrice="+ price +"  tp="+ tp +"  sl="+ sl +"  Bid/Ask: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat), ifInt(!error, ERR_RUNTIME_ERROR, error)));
            PushTicket(OP_LONG, ticket, i, StartLots, price, ORDER_PENDING);
         }

         tp = short.tpPrice;
         sl = long.tpPrice;
         for (i=1; i <= Grid.Levels; i++) {
            price  = NormalizeDouble(grid.startPrice - i*Grid.Size*Pip, Digits);
            ticket = OrderSend(Symbol(), OP_SELLSTOP, StartLots, price, NULL, sl, tp, os.comment, os.magicNumber);
            error  = GetLastError(); if (ticket < 1 || error) return(catch("onTick(2)  Tick="+ Tick +"  ticket="+ ticket +"  stopPrice="+ price +"  tp="+ tp +"  sl="+ sl +"  Bid/Ask: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat), ifInt(!error, ERR_RUNTIME_ERROR, error)));
            PushTicket(OP_SHORT, ticket, i, StartLots, price, ORDER_PENDING);
         }
         debug("onTick(3)   started new sequence at "+ NumberToStr(grid.startPrice, PriceFormat) +"  targets: "+ DoubleToStr(grid.firstSet.units, 0) +"/"+ DoubleToStr(grid.firstSet.units, 0) +" units");
      }
      if (!Trade.Sequences) return(SetLastError(ERR_CANCELLED_BY_USER));
   }


   // manage existing orders
   else {
      bool orderTriggered = false;

      // update the order status
      for (i=ArraySize(long.order.ticket)-1; i >= 0; i--) {
         OrderSelect(long.order.ticket[i], SELECT_BY_TICKET);
         if (!OrderCloseTime()) {
            if (long.order.status[i]==ORDER_PENDING) /*&&*/ if (OrderType()==OP_BUY) {
               long.order.status[i] = ORDER_OPEN;
               orderTriggered = true;
            }
         }
         else return(CloseSequence());                                  // close all if one was closed
      }
      for (i=ArraySize(short.order.ticket)-1; i >= 0; i--) {
         OrderSelect(short.order.ticket[i], SELECT_BY_TICKET);
         if (!OrderCloseTime()) {
            if (short.order.status[i]==ORDER_PENDING) /*&&*/ if (OrderType()==OP_SELL) {
               short.order.status[i] = ORDER_OPEN;
               orderTriggered = true;
            }
         }
         else return(CloseSequence());                                  // close all if one was closed
      }
      if (!orderTriggered)                                              // nothing to do
         return(last_error);

      // orders are managed only after one or more pending orders have been triggered
      long.targetUnits  = GetTargetUnits(OP_LONG);
      short.targetUnits = GetTargetUnits(OP_SHORT);

      int newOrders = 0, sets = 0;
      if (long.targetUnits + grid.addedSet.units < 2)                   // a single order set is not enough to re-balance the side
         sets = (2-long.targetUnits)/grid.addedSet.units;

      for (i=Grid.Levels; i >= 1 && long.targetUnits < 2; i--) {        // add long stop orders
         stopPrice = NormalizeDouble(grid.startPrice + i*Grid.Size*Pip, Digits);
         if (Ask <= stopPrice) {
            tp     = long.tpPrice;
            sl     = short.tpPrice;
            ticket = OrderSend(Symbol(), OP_BUYSTOP, (sets+1)*i*StartLots, stopPrice, NULL, sl, tp, os.comment, os.magicNumber);
            error  = GetLastError(); if (ticket < 1 || error) return(catch("onTick(4)  Tick="+ Tick +"  ticket="+ ticket +"  stopPrice="+ price +"  tp="+ tp +"  sl="+ sl +"  Bid/Ask: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat), ifInt(!error, ERR_RUNTIME_ERROR, error)));
            PushTicket(OP_LONG, ticket, i, (sets+1)*i*StartLots, stopPrice, ORDER_PENDING);

            long.targetUnits += NormalizeDouble((sets+1)*i*(Grid.Levels+1-i), 0);
            newOrders++;
         }
      }
      if (newOrders > 0) debug("onTick(5)  Tick="+ Tick +"  position: "+ GetPositionUnits() +" units, added "+ newOrders +" long orders, new targets: "+ DoubleToStr(long.targetUnits, 0) +"/"+ DoubleToStr(short.targetUnits, 0) +" units");

      sets = 0;
      if (short.targetUnits + grid.addedSet.units < 2)                  // a single order set is not enough to re-balance the side
         sets = (2-short.targetUnits)/grid.addedSet.units;

      newOrders = 0;
      for (i=Grid.Levels; i >= 1 && short.targetUnits < 2; i--) {       // add short stop orders
         stopPrice = NormalizeDouble(grid.startPrice - i*Grid.Size*Pip, Digits);
         if (Bid >= stopPrice) {
            tp     = short.tpPrice;
            sl     = long.tpPrice;
            ticket = OrderSend(Symbol(), OP_SELLSTOP, (sets+1)*i*StartLots, stopPrice, NULL, sl, tp, os.comment, os.magicNumber);
            error  = GetLastError(); if (ticket < 1 || error) return(catch("onTick(6)  Tick="+ Tick +"  ticket="+ ticket +"  stopPrice="+ price +"  tp="+ tp +"  sl="+ sl +"  Bid/Ask: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat), ifInt(!error, ERR_RUNTIME_ERROR, error)));
            PushTicket(OP_SHORT, ticket, i, (sets+1)*i*StartLots, stopPrice, ORDER_PENDING);

            short.targetUnits += NormalizeDouble((sets+1)*i*(Grid.Levels+1-i), 0);
            newOrders++;
         }
      }
      if (newOrders > 0) debug("onTick(7)  Tick="+ Tick +"  position: "+ GetPositionUnits() +" units, added "+ newOrders +" short orders, new targets: "+ DoubleToStr(long.targetUnits, 0) +"/"+ DoubleToStr(short.targetUnits, 0) +" units");
   }
   return(catch("onTick(8)"));
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
      ArrayPushInt   (long.order.ticket,    ticket);
      ArrayPushInt   (long.order.level,     level );
      ArrayPushDouble(long.order.lots,      lots  );
      ArrayPushDouble(long.order.openPrice, price );
      ArrayPushInt   (long.order.status,    status);
   }
   else if (direction == OP_SHORT) {
      ArrayPushInt   (short.order.ticket,    ticket);
      ArrayPushInt   (short.order.level,     level );
      ArrayPushDouble(short.order.lots,      lots  );
      ArrayPushDouble(short.order.openPrice, price );
      ArrayPushInt   (short.order.status,    status);
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
   double lots;
   int orders = OrdersTotal();

   for (int i=0; i < orders; i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber && StringStartsWith(OrderComment(), os.comment)) {
         if (OrderType()==OP_BUY)  lots += OrderLots();
         if (OrderType()==OP_SELL) lots -= OrderLots();
      }
   }
   catch("GetPositionUnits(1)");
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
 *
 */
double GetTargetUnits(int direction) {
   double unitPip;
   int orders = OrdersTotal();

   if (direction == OP_LONG) {
      // profit in units when TakeProfit is reached on the long side (1 unit = StartLots * Grid.Size)
      for (int i=0; i < orders; i++) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber && StringStartsWith(OrderComment(), os.comment)) {
            if (OrderType()==OP_BUY)     unitPip += (OrderTakeProfit()-OrderOpenPrice())/Pip * OrderLots()/StartLots;
            if (OrderType()==OP_BUYSTOP) unitPip += (OrderTakeProfit()-OrderOpenPrice())/Pip * OrderLots()/StartLots;
            if (OrderType()==OP_SELL)    unitPip -= (OrderStopLoss()  -OrderOpenPrice())/Pip * OrderLots()/StartLots;
         }
      }
      catch("GetTargetUnits(1)");
      return(unitPip/Grid.Size);
   }

   if (direction == OP_SHORT) {
      // profit in units when TakeProfit is reached on the short side (1 unit = StartLots * Grid.Size)
      for (i=0; i < orders; i++) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber && StringStartsWith(OrderComment(), os.comment)) {
            if (OrderType()==OP_SELL)     unitPip += (OrderOpenPrice()-OrderTakeProfit())/Pip * OrderLots()/StartLots;
            if (OrderType()==OP_SELLSTOP) unitPip += (OrderOpenPrice()-OrderTakeProfit())/Pip * OrderLots()/StartLots;
            if (OrderType()==OP_BUY)      unitPip -= (OrderOpenPrice()-OrderStopLoss()  )/Pip * OrderLots()/StartLots;
         }
      }
      catch("GetTargetUnits(2)");
      return(unitPip/Grid.Size);
   }

   return(!catch("GetTargetUnits(3)  illegal parameter direction: "+ direction, ERR_INVALID_PARAMETER));
}


/**
 *
 */
int CloseSequence() {
   int orders = ArraySize(long.order.ticket);
   for (int i=0; i < orders; i++) {
      OrderSelect(long.order.ticket[i], SELECT_BY_TICKET);
      if (!OrderCloseTime()) {
         RefreshRates();
         if (OrderType()==OP_BUY) OrderClose(OrderTicket(), OrderLots(), Bid, os.slippage);
         else                     OrderDelete(OrderTicket());
      }
      long.order.status[i] = ORDER_CLOSED;
   }

   orders = ArraySize(short.order.ticket);
   for (i=0; i < orders; i++) {
      OrderSelect(short.order.ticket[i], SELECT_BY_TICKET);
      if (!OrderCloseTime()) {
         RefreshRates();
         if (OrderType()==OP_SELL) OrderClose(OrderTicket(), OrderLots(), Ask, os.slippage);
         else                      OrderDelete(OrderTicket());
      }
      short.order.status[i] = ORDER_CLOSED;
   }

   ArrayResize(long.order.ticket,     0);
   ArrayResize(long.order.level,      0);
   ArrayResize(long.order.lots,       0);
   ArrayResize(long.order.openPrice,  0);
   ArrayResize(long.order.status,     0);

   ArrayResize(short.order.ticket,    0);
   ArrayResize(short.order.level,     0);
   ArrayResize(short.order.lots,      0);
   ArrayResize(short.order.openPrice, 0);
   ArrayResize(short.order.status,    0);

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
int ShowStatus(int error=NO_ERROR) {
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
2017.09.18-2017.09.19 EURUSD,M1: 223594 ticks, 385 orders, 164 trades, time: 42.869 sec

don't use the history:
2017.09.18-2017.09.19 EURUSD,M1: 223594 ticks, 385 orders, 164 trades, time: 8.222 sec

manage sequence only after triggering of pending orders:
2017.09.18-2017.09.19 EURUSD,M1: 223594 ticks, 385 orders, 164 trades, time: 1.918 sec
*/
