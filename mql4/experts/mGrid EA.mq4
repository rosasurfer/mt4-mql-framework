/**
 * Math Grid EA (rewrite)
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern double Grid.Size       = 4;           // pips
extern int    Grid.Levels     = 3;
extern double StartLots       = 0.1;
extern int    Trade.Sequences = -1;          // number of sequences to trade (-1: unlimited)
extern int    Trade.StartHour = -1;          // hour to start sequence (-1: any hour)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>


// original vars
bool   useProfitTarget             = false;
bool   usePartialProfitTarget      = false;
double partialTakeProfit.Increment = 5;
double partialTakeProfit.Pip       = 2;

bool   trade.stop = false;


// grid management
double grid.startPrice;
double long.tpPrice;
double short.tpPrice;

// order defaults
int    os.magicNumber = 1803;
double os.slippage    = 3;
string os.comment     = "";


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   double stopPrice, tp, sl, long.tpUnits, short.tpUnits, spread=(Ask-Bid)/Pip;
   int error, ticket, openOrders, orders=OrdersTotal();

   if (IsTesting()) {
      openOrders = orders;
   }
   else {
      for (int i=0; i < orders; i++) {
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber) {
            openOrders++;
            //if (useProfitTarget && usePartialProfitTarget) {
            //   if (OrderType() <= OP_SELL) {
            //      if (CheckPartialTakeProfit(OrderTicket())) {
            //         openOrders--;
            //         orders--;
            //         i--;
            //      }
            //   }
            //}
         }
      }
   }

   // start sequence if no open orders
   if (!openOrders) {
      if (Trade.Sequences && (Trade.StartHour==-1 || Trade.StartHour==Hour())) {
         grid.startPrice = Ask;
         long.tpPrice    = NormalizeDouble(grid.startPrice + (Grid.Levels+1)*Grid.Size*Pip, Digits);
         short.tpPrice   = NormalizeDouble(grid.startPrice - (Grid.Levels+1)*Grid.Size*Pip, Digits);
         os.comment      = DoubleToStr(grid.startPrice, Digits);

         tp = long.tpPrice;
         sl = short.tpPrice;
         for (i=1; i <= Grid.Levels; i++) {
            stopPrice = NormalizeDouble(grid.startPrice + i*Grid.Size*Pip, Digits);
            ticket    = OrderSend(Symbol(), OP_BUYSTOP, StartLots, stopPrice, NULL, sl, tp, os.comment, os.magicNumber);
            error     = GetLastError();
            if (ticket < 1 || error) return(catch("onTick(1)  Tick="+ Tick +"  ticket="+ ticket +"  stopPrice="+ stopPrice +"  tp="+ tp +"  sl="+ sl +"  Bid/Ask: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat), ifInt(!error, ERR_RUNTIME_ERROR, error)));
         }
         tp = short.tpPrice;
         sl = long.tpPrice;
         for (i=1; i <= Grid.Levels; i++) {
            stopPrice = NormalizeDouble(grid.startPrice - i*Grid.Size*Pip, Digits);
            ticket    = OrderSend(Symbol(), OP_SELLSTOP, StartLots, stopPrice, NULL, sl, tp, os.comment, os.magicNumber);
            error     = GetLastError();
            if (ticket < 1 || error) return(catch("onTick(2)  Tick="+ Tick +"  ticket="+ ticket +"  stopPrice="+ stopPrice +"  tp="+ tp +"  sl="+ sl +"  Bid/Ask: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat), ifInt(!error, ERR_RUNTIME_ERROR, error)));
         }
         long.tpUnits = GetTargetUnits(OP_LONG);
         debug("onTick(3)   started new sequence at "+ NumberToStr(grid.startPrice, PriceFormat) +"  targets: "+ DoubleToStr(long.tpUnits, 0) +"/"+ DoubleToStr(long.tpUnits, 0) +" units");
      }
      if (!Trade.Sequences) return(SetLastError(ERR_CANCELLED_BY_USER));
   }


   // open orders exist
   else {
      orders = OrdersHistoryTotal();

      for (i=0; i < orders; i++) {
         OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
         if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber && StringStartsWith(OrderComment(), os.comment))
            return(CloseSequence());
      }

      //if (useProfitTarget) /*&&*/ if (GetProfitUnits() >= 2)
      //   return(CloseSequence());

      long.tpUnits  = GetTargetUnits(OP_LONG);
      short.tpUnits = GetTargetUnits(OP_SHORT);

      int n = 0;
      for (i=Grid.Levels; i >= 1 && long.tpUnits < 2; i--) {         // add long stop orders
         stopPrice = NormalizeDouble(grid.startPrice + i*Grid.Size*Pip, Digits);
         if (Ask <= stopPrice) {
            tp     = long.tpPrice;
            sl     = short.tpPrice;
            ticket = OrderSend(Symbol(), OP_BUYSTOP, i*StartLots, stopPrice, NULL, sl, tp, os.comment, os.magicNumber);
            error  = GetLastError();
            if (ticket < 1 || error) return(catch("onTick(4)  Tick="+ Tick +"  ticket="+ ticket +"  stopPrice="+ stopPrice +"  tp="+ tp +"  sl="+ sl +"  Bid/Ask: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat), ifInt(!error, ERR_RUNTIME_ERROR, error)));
            long.tpUnits += NormalizeDouble(i*(Grid.Levels+1-i), 0);
            n++;
         }
      }
      if (n > 0) debug("onTick(5)  Tick="+ Tick +"  "+ n +" more long orders, new targets: "+ DoubleToStr(long.tpUnits, 0) +"/"+ DoubleToStr(short.tpUnits, 0) +" units");

      n = 0;
      for (i=Grid.Levels; i >= 1 && short.tpUnits < 2; i--) {        // add short stop orders
         stopPrice = NormalizeDouble(grid.startPrice - i*Grid.Size*Pip, Digits);
         if (Bid >= stopPrice) {
            tp     = short.tpPrice;
            sl     = long.tpPrice;
            ticket = OrderSend(Symbol(), OP_SELLSTOP, i*StartLots, stopPrice, NULL, sl, tp, os.comment, os.magicNumber);
            error  = GetLastError();
            if (ticket < 1 || error) return(catch("onTick(6)  Tick="+ Tick +"  ticket="+ ticket +"  stopPrice="+ stopPrice +"  tp="+ tp +"  sl="+ sl +"  Bid/Ask: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat), ifInt(!error, ERR_RUNTIME_ERROR, error)));
            short.tpUnits += NormalizeDouble(i*(Grid.Levels+1-i), 0);
            n++;
         }
      }
      if (n > 0) debug("onTick(7)  Tick="+ Tick +"  "+ n +" more short orders, new targets: "+ DoubleToStr(long.tpUnits, 0) +"/"+ DoubleToStr(short.tpUnits, 0) +" units");
   }
   return(catch("onTick(8)"));
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
         if      (OrderType()==OP_BUY)  OrderClose(OrderTicket(), OrderLots(), Bid, os.slippage);
         else if (OrderType()==OP_SELL) OrderClose(OrderTicket(), OrderLots(), Ask, os.slippage);
         else                           OrderDelete(OrderTicket());
      }
   }
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

   string str.status = "";
   if (__STATUS_OFF) str.status = StringConcatenate(" switched OFF  [", ErrorDescription(__STATUS_OFF.reason), "]");

   Comment(NL,
           __NAME__, str.status,                                            NL,
           "--------------",                                                NL,
           "Balance:       ",   AccountBalance(),                           NL,
           "Profit:          ", AccountProfit(),                            NL,
           "Equity:        ",   AccountEquity(),                            NL,
           "Grid.Size:     ",   DoubleToStr(Grid.Size, Digits & 1), " pip", NL,
           "Grid.Levels:  ",    Grid.Levels,                                NL,
           "StartLots:     ",   StartLots,                                  NL);

   if (__WHEREAMI__ == RF_INIT)
      WindowRedraw();
   return(error);
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
   CheckPartialTakeProfit(NULL);
}
