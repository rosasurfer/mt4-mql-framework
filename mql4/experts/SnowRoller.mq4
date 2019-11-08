/**
 * SnowRoller - a pyramiding trade manager
 *
 *
 * With default settings this EA is only a trade manager and not a complete system. Start and stop conditions are defined
 * manually and the EA manages the resulting trades in a pyramiding way.
 *
 * Theoretical background and proof-of-concept were provided by Bernd Kreuss aka 7bit in "Snowballs and the Anti-Grid".
 *
 *  @see  https://sites.google.com/site/prof7bit/snowball
 *  @see  https://www.forexfactory.com/showthread.php?t=226059
 *  @see  https://www.forexfactory.com/showthread.php?t=239717
 *
 * The EA is not FIFO conforming, and will never be. A description of program actions, events and status changes is appended
 * at the end of this file.
 *
 * Risk warning: The market can range longer without reaching the profit target than a trading account can survive.
 */
#include <stddefines.mqh>
#include <app/SnowRoller/defines.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE, INIT_PIPVALUE, INIT_CUSTOMLOG};
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string   Sequence.ID            = "";
extern string   GridDirection          = "Long | Short";          // no bi-directional mode
extern int      GridSize               = 20;
extern double   LotSize                = 0.1;
extern int      StartLevel             = 0;
extern string   StartConditions        = "";                      // @trend(<indicator>:<timeframe>:<params>) | @price(double) | @time(datetime)
extern string   StopConditions         = "";                      // @trend(<indicator>:<timeframe>:<params>) | @price(double) | @time(datetime) | @profit(double[%])
extern bool     AutoResume             = false;                   // whether to automatically re-activate a trend StartCondition after StopSequence()
extern datetime Sessionbreak.StartTime = D'1970.01.01 23:56:00';  // in FXT, the date part is ignored
extern datetime Sessionbreak.EndTime   = D'1970.01.01 01:02:10';  // in FXT, the date part is ignored
extern bool     ShowProfitInPercent    = true;                    // whether PL values are displayed absolutely or in percent

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Input parameters:
 */
#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfHistory.mqh>
#include <rsfLibs.mqh>
#include <functions/BarOpenEvent.mqh>
#include <functions/JoinInts.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/rsf/OrderExecution.mqh>
#include <win32api.mqh>

int      sequence.id;
string   sequence.created = "";                    // GmtTimeFormat(datetime, "%a, %Y.%m.%d %H:%M:%S")
string   sequence.name    = "";                    // "L.1234" | "S.2345"
int      sequence.status;
bool     sequence.isTest;                          // whether the sequence was created in tester (a finished test may be loaded in a live chart)
int      sequence.direction;
int      sequence.level;                           // current grid level:      -n...0...+n
int      sequence.maxLevel;                        // max. reached grid level: -n...0...+n
int      sequence.missedLevels[];                  // missed grid levels, e.g. in a fast moving market
double   sequence.startEquity;
int      sequence.stops;                           // number of stopped-out positions: 0...+n
double   sequence.stopsPL;                         // accumulated P/L of all stopped-out positions
double   sequence.closedPL;                        // accumulated P/L of all positions closed at sequence stop
double   sequence.floatingPL;                      // accumulated P/L of all open positions
double   sequence.totalPL;                         // current total P/L of the sequence: totalPL = stopsPL + closedPL + floatingPL
double   sequence.maxProfit;                       // max. experienced total sequence profit:   0...+n
double   sequence.maxDrawdown;                     // max. experienced total sequence drawdown: -n...0
double   sequence.profitPerLevel;                  // current profit amount per grid level
double   sequence.breakeven;                       // current breakeven price
double   sequence.commission;                      // commission value per grid level:          -n...0

int      sequence.start.event [];                  // sequence starts (moment status changes to STATUS_PROGRESSING)
datetime sequence.start.time  [];
double   sequence.start.price [];
double   sequence.start.profit[];

int      sequence.stop.event  [];                  // sequence stops (moment status changes to STATUS_STOPPED)
datetime sequence.stop.time   [];
double   sequence.stop.price  [];                  // average realized close price of all closed positions
double   sequence.stop.profit [];

string   statusFile      = "";                     // filename of the status file
string   statusDirectory = "";                     // directory the status file is stored (relative to "files/")

// --- start conditions (AND combined) -----
bool     start.conditions;                         // whether any start condition is active

bool     start.trend.condition;
string   start.trend.indicator   = "";
int      start.trend.timeframe;
string   start.trend.params      = "";
string   start.trend.description = "";

bool     start.price.condition;
int      start.price.type;                         // PRICE_BID | PRICE_ASK | PRICE_MEDIAN
double   start.price.value;
double   start.price.lastValue;
string   start.price.description = "";

bool     start.time.condition;
datetime start.time.value;
string   start.time.description = "";

// --- stop conditions (OR combined) -------
bool     stop.trend.condition;                     // whether a stop trend condition is active
string   stop.trend.indicator   = "";
int      stop.trend.timeframe;
string   stop.trend.params      = "";
string   stop.trend.description = "";

bool     stop.price.condition;                     // whether a stop price condition is active
int      stop.price.type;                          // PRICE_BID | PRICE_ASK | PRICE_MEDIAN
double   stop.price.value;
double   stop.price.lastValue;
string   stop.price.description = "";

bool     stop.time.condition;                      // whether a stop time condition is active
datetime stop.time.value;
string   stop.time.description = "";

bool     stop.profitAbs.condition;                 // whether an absolute stop profit condition is active
double   stop.profitAbs.value;
string   stop.profitAbs.description = "";

bool     stop.profitPct.condition;                 // whether a percentage stop profit condition is active
double   stop.profitPct.value;
double   stop.profitPct.absValue    = INT_MAX;
string   stop.profitPct.description = "";

// --- session break management ------------
datetime sessionbreak.starttime;
datetime sessionbreak.endtime;
bool     sessionbreak.waiting;                     // whether the sequence waits to resume during and after a session break

// --- grid base management ----------------
double   grid.base;                                // current grid base
int      grid.base.event  [];                      // grid base history
datetime grid.base.time   [];
double   grid.base.value  [];

// --- order data --------------------------
int      orders.ticket         [];
int      orders.level          [];                 // order grid level: -n...-1 | 1...+n
double   orders.gridBase       [];                 // grid base when the order was active
int      orders.pendingType    [];                 // pending order type (if applicable)        or -1
datetime orders.pendingTime    [];                 // time of OrderOpen() or last OrderModify() or  0
double   orders.pendingPrice   [];                 // pending entry limit                       or  0
int      orders.type           [];
int      orders.openEvent      [];
datetime orders.openTime       [];
double   orders.openPrice      [];
int      orders.closeEvent     [];
datetime orders.closeTime      [];
double   orders.closePrice     [];
double   orders.stopLoss       [];
bool     orders.clientsideLimit[];                 // whether a limit is managed client-side
bool     orders.closedBySL     [];
double   orders.swap           [];
double   orders.commission     [];
double   orders.profit         [];

// --- other -------------------------------
int      ignorePendingOrders  [];                  // orphaned tickets to ignore
int      ignoreOpenPositions  [];                  // ...
int      ignoreClosedPositions[];                  // ...

int      startStopDisplayMode = SDM_PRICE;         // whether start/stop markers are displayed
int      orderDisplayMode     = ODM_PYRAMID;       // current order display mode

string   sLotSize                = "";             // caching vars to speed-up execution of ShowStatus()
string   sGridbase               = "";
string   sSequenceDirection      = "";
string   sSequenceMissedLevels   = "";
string   sSequenceStops          = "";
string   sSequenceStopsPL        = "";
string   sSequenceTotalPL        = "";
string   sSequenceMaxProfit      = "";
string   sSequenceMaxDrawdown    = "";
string   sSequenceProfitPerLevel = "";
string   sSequencePlStats        = "";
string   sStartConditions        = "";
string   sStopConditions         = "";
string   sAutoResume             = "";


#include <app/SnowRoller/init.mqh>
#include <app/SnowRoller/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (sequence.status == STATUS_UNDEFINED)
      return(NO_ERROR);

   // process chart commands
   if (!HandleEvent(EVENT_CHART_CMD))
      return(last_error);

   int  signal, activatedOrders[];                          // indexes of activated client-side orders
   bool gridChanged;                                        // whether the current grid base or level changed

   // sequence either waits for start/resume signal...
   if (sequence.status == STATUS_WAITING) {
      if (!IsSessionBreak()) {                              // pause during sessionbreaks
         signal = IsStartSignal();
         if (signal != 0) {
            if (!ArraySize(sequence.start.event)) StartSequence(signal);
            else                                  ResumeSequence(signal);
         }
      }
   }

   // ...or sequence is running...
   else if (sequence.status == STATUS_PROGRESSING) {
      if (UpdateStatus(gridChanged, activatedOrders)) {
         signal = IsStopSignal();
         if (!signal) {
            if (ArraySize(activatedOrders) > 0) ExecuteOrders(activatedOrders);
            if (Tick==1 || gridChanged)         UpdatePendingOrders();
         }
         else StopSequence(signal);
      }
   }

   // ...or sequence is stopped
   else if (sequence.status != STATUS_STOPPED) return(catch("onTick(1)  illegal sequence status: "+ StatusToStr(sequence.status), ERR_ILLEGAL_STATE));

   // update current equity value for equity recorder
   if (EA.RecordEquity)
      test.equity.value = sequence.startEquity + sequence.totalPL;

   // update profit targets
   if (IsBarOpenEvent(PERIOD_M1)) ShowProfitTargets();

   return(last_error);
}


/**
 * Handle incoming commands.
 *
 * @param  string commands[] - received external commands
 *
 * @return bool - success status
 */
bool onCommand(string commands[]) {
   if (!ArraySize(commands))
      return(_true(warn("onCommand(1)  empty parameter commands = {}")));

   string cmd = commands[0];

   if (cmd == "start") {
      switch (sequence.status) {
         case STATUS_WAITING:
         case STATUS_STOPPED:
            bool neverStarted = !ArraySize(sequence.start.event);
            if (neverStarted) StartSequence(NULL);
            else              ResumeSequence(NULL);

      }
      return(true);
   }

   else if (cmd == "stop") {
      switch (sequence.status) {
         case STATUS_PROGRESSING:
            bool bNull;
            int  iNull[];
            if (!UpdateStatus(bNull, iNull))
               return(false);                   // fall-through to STATUS_WAITING
         case STATUS_WAITING:
            return(StopSequence(NULL));
      }
      return(true);
   }

   else if (cmd ==     "orderdisplay") return(!ToggleOrderDisplayMode()    );
   else if (cmd == "startstopdisplay") return(!ToggleStartStopDisplayMode());

   // log unknown commands and let the EA continue
   return(_true(warn("onCommand(2)  unknown command \""+ cmd +"\"")));
}


/**
 * Start a new trade sequence.
 *
 * @param  int signal - signal which triggered a start condition or NULL if no condition was triggered (explicit start)
 *
 * @return bool - success status
 */
bool StartSequence(int signal) {
   if (IsLastError())                     return(false);
   if (sequence.status != STATUS_WAITING) return(!catch("StartSequence(1)  cannot start "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   if (Tick==1) /*&&*/ if (!ConfirmFirstTickTrade("StartSequence()", "Do you really want to start a new \""+ StrToLower(TradeDirectionDescription(sequence.direction)) +"\" sequence now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));

   sequence.status = STATUS_STARTING;
   if (__LOG()) log("StartSequence(2)  starting sequence "+ sequence.name + ifString(sequence.level, " at level "+ Abs(sequence.level), ""));

   // configure/deactivate start conditions
   sessionbreak.waiting  = false;
   start.price.condition = false;
   start.time.condition  = false;
   start.trend.condition = (start.trend.condition && AutoResume);
   start.conditions      = false; SS.StartStopConditions();

   sequence.startEquity = NormalizeDouble(AccountEquity()-AccountCredit(), 2);
   sequence.level       = ifInt(sequence.direction==D_LONG, StartLevel, -StartLevel);
   sequence.maxLevel    = sequence.level;

   datetime startTime  = TimeCurrentEx("StartSequence(3)");
   double   startPrice = ifDouble(sequence.direction==D_SHORT, Bid, Ask);

   ArrayPushInt   (sequence.start.event,  CreateEventId());
   ArrayPushInt   (sequence.start.time,   startTime      );
   ArrayPushDouble(sequence.start.price,  startPrice     );
   ArrayPushDouble(sequence.start.profit, 0              );

   ArrayPushInt   (sequence.stop.event,   0);               // keep sizes of sequence.start/stop.* synchronous
   ArrayPushInt   (sequence.stop.time,    0);
   ArrayPushDouble(sequence.stop.price,   0);
   ArrayPushDouble(sequence.stop.profit,  0);

   // set the grid base (event after sequence.start.time in time)
   double gridBase = NormalizeDouble(startPrice - sequence.level*GridSize*Pips, Digits);
   GridBase.Reset(startTime, gridBase);

   // open start positions if configured (and update sequence start price)
   if (sequence.level != 0) {
      if (!RestorePositions(startTime, startPrice)) return(false);
      sequence.start.price[ArraySize(sequence.start.price)-1] = startPrice;
   }
   sequence.status = STATUS_PROGRESSING;

   // open the next stop orders
   if (!UpdatePendingOrders()) return(false);

   if (!SaveSequence()) return(false);
   RedrawStartStop();

   if (__LOG()) log("StartSequence(4)  sequence "+ sequence.name +" started at "+ NumberToStr(startPrice, PriceFormat) + ifString(sequence.level, " and level "+ sequence.level, ""));
   return(!catch("StartSequence(5)"));
}


/**
 * Close all open positions and delete pending orders. Stop the sequence and configure auto-resuming: If auto-resuming for a
 * trend condition is enabled the sequence is automatically resumed the next time the trend condition is fulfilled. If the
 * sequence is stopped due to a session break it is automatically resumed after the session break ends.
 *
 * @param  int signal - signal which triggered the stop condition or NULL if no condition was triggered (explicit stop)
 *
 * @return bool - success status
 */
bool StopSequence(int signal) {
   if (IsLastError())                                                          return(false);
   if (sequence.status!=STATUS_WAITING && sequence.status!=STATUS_PROGRESSING) return(!catch("StopSequence(1)  cannot stop "+ StatusDescription(sequence.status) +" sequence "+ sequence.name, ERR_ILLEGAL_STATE));

   if (Tick==1) /*&&*/ if (!ConfirmFirstTickTrade("StopSequence()", "Do you really want to stop sequence "+ sequence.name +" now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));

   bool entryStatus = sequence.status;

   // a waiting sequence has no open orders (before first start or after stop)
   if (sequence.status == STATUS_WAITING) {
      sequence.status = STATUS_STOPPED;
      if (__LOG()) log("StopSequence(2)  sequence "+ sequence.name +" stopped");
   }

   // a progressing sequence has open orders to close
   else if (sequence.status == STATUS_PROGRESSING) {
      sequence.status = STATUS_STOPPING;
      if (__LOG()) log("StopSequence(3)  stopping sequence "+ sequence.name +" at level "+ sequence.level);

      // close open orders
      double stopPrice, slippage = 2;                                         // 2 pip
      int level, oeFlags, oes[][ORDER_EXECUTION.intSize];
      int pendingLimits[], openPositions[], sizeOfTickets = ArraySize(orders.ticket);
      ArrayResize(pendingLimits, 0);
      ArrayResize(openPositions, 0);

      // get all locally active orders (pending limits and open positions)
      for (int i=sizeOfTickets-1; i >= 0; i--) {
         if (!orders.closeTime[i]) {                                          // local: if (isOpen)
            level = orders.level[i];
            if (orders.ticket[i] < 0) {                                       // drop client-side managed pending orders
               if (!Grid.DropData(i)) return(false);
               sizeOfTickets--;
               ArrayAddInt(pendingLimits, -1);                                // decrease indexes of already stored limits
            }
            else {
               ArrayPushInt(pendingLimits, i);                                // pending entry or stop limit
               if (orders.type[i] != OP_UNDEFINED)
                  ArrayPushInt(openPositions, orders.ticket[i]);              // open position
            }
            if (Abs(level) == 1) break;
         }
      }

      // hedge open positions
      int sizeOfPositions = ArraySize(openPositions);
      if (sizeOfPositions > 0) {
         oeFlags = F_OE_DONT_CHECK_STATUS;                                    // skip status check to prevent errors
         int ticket = OrdersHedge(openPositions, slippage, oeFlags, oes); if (!ticket) return(!SetLastError(oes.Error(oes, 0)));
         ArrayPushInt(openPositions, ticket);
         sizeOfPositions++;
         stopPrice = oes.ClosePrice(oes, 0);
      }

      // delete all pending limits
      int sizeOfPendings = ArraySize(pendingLimits);
      for (i=0; i < sizeOfPendings; i++) {                                    // ordered by descending grid level
         if (orders.type[pendingLimits[i]] == OP_UNDEFINED) {
            int error = Grid.DeleteOrder(pendingLimits[i]);                   // removes the order from the order arrays
            if (!error) continue;
            if (error == -1) {                                                // entry stop is already executed
               if (!SelectTicket(orders.ticket[pendingLimits[i]], "StopSequence(4)")) return(false);
               orders.type      [pendingLimits[i]] = OrderType();
               orders.openEvent [pendingLimits[i]] = CreateEventId();
               orders.openTime  [pendingLimits[i]] = OrderOpenTime();
               orders.openPrice [pendingLimits[i]] = OrderOpenPrice();
               orders.swap      [pendingLimits[i]] = OrderSwap();
               orders.commission[pendingLimits[i]] = OrderCommission();
               orders.profit    [pendingLimits[i]] = OrderProfit();
               if (__LOG()) log("StopSequence(5)  "+ UpdateStatus.OrderFillMsg(pendingLimits[i]));
               if (IsStopOrderType(orders.pendingType[pendingLimits[i]])) {   // the next grid level was triggered
                  sequence.level   += Sign(orders.level[pendingLimits[i]]);
                  sequence.maxLevel = Sign(orders.level[pendingLimits[i]]) * Max(Abs(sequence.level), Abs(sequence.maxLevel));
               }
               else {                                                         // a previously missed grid level was triggered
                  ArrayDropInt(sequence.missedLevels, orders.level[pendingLimits[i]]);
                  SS.MissedLevels();
               }
               if (__LOG()) log("StopSequence(6)  sequence "+ sequence.name +" adding ticket #"+ OrderTicket() +" to open positions");
               ArrayPushInt(openPositions, OrderTicket());                    // add to open positions
               i--;                                                           // process the position's stoploss limit
            }
            else return(false);
         }
         else {
            error = Grid.DeleteLimit(pendingLimits[i]);
            if (!error) continue;
            if (error == -1) {                                                // stoploss is already executed
               if (!SelectTicket(orders.ticket[pendingLimits[i]], "StopSequence(7)")) return(false);
               orders.closeEvent[pendingLimits[i]] = CreateEventId();
               orders.closeTime [pendingLimits[i]] = OrderCloseTime();
               orders.closePrice[pendingLimits[i]] = OrderClosePrice();
               orders.closedBySL[pendingLimits[i]] = true;
               orders.swap      [pendingLimits[i]] = OrderSwap();
               orders.commission[pendingLimits[i]] = OrderCommission();
               orders.profit    [pendingLimits[i]] = OrderProfit();
               if (__LOG()) log("StopSequence(8)  "+ UpdateStatus.StopLossMsg(pendingLimits[i]));
               sequence.stops++;
               sequence.stopsPL = NormalizeDouble(sequence.stopsPL + orders.swap[pendingLimits[i]] + orders.commission[pendingLimits[i]] + orders.profit[pendingLimits[i]], 2); SS.Stops();
               ArrayDropInt(openPositions, OrderTicket());                    // remove from open positions
            }
            else return(false);
         }
      }

      // close open positions
      int pos;
      sizeOfPositions = ArraySize(openPositions);
      double remainingSwap, remainingCommission, remainingProfit;

      if (sizeOfPositions > 0) {
         if (!OrdersClose(openPositions, slippage, CLR_CLOSE, NULL, oes)) return(!SetLastError(oes.Error(oes, 0)));
         for (i=0; i < sizeOfPositions; i++) {
            pos = SearchIntArray(orders.ticket, openPositions[i]);
            if (pos != -1) {
               orders.closeEvent[pos] = CreateEventId();
               orders.closeTime [pos] = oes.CloseTime (oes, i);
               orders.closePrice[pos] = oes.ClosePrice(oes, i);
               orders.closedBySL[pos] = false;
               orders.swap      [pos] = oes.Swap      (oes, i);
               orders.commission[pos] = oes.Commission(oes, i);
               orders.profit    [pos] = oes.Profit    (oes, i);
            }
            else {
               remainingSwap       += oes.Swap      (oes, i);
               remainingCommission += oes.Commission(oes, i);
               remainingProfit     += oes.Profit    (oes, i);
            }
            sequence.closedPL = NormalizeDouble(sequence.closedPL + oes.Swap(oes, i) + oes.Commission(oes, i) + oes.Profit(oes, i), 2);
         }
         pos = ArraySize(orders.ticket)-1;                                    // the last ticket is always a closed position
         orders.swap      [pos] += remainingSwap;
         orders.commission[pos] += remainingCommission;
         orders.profit    [pos] += remainingProfit;
      }

      // update statistics and sequence status
      sequence.floatingPL = 0;
      sequence.totalPL    = NormalizeDouble(sequence.stopsPL + sequence.closedPL + sequence.floatingPL, 2); SS.TotalPL();
      if      (sequence.totalPL > sequence.maxProfit  ) { sequence.maxProfit   = sequence.totalPL; SS.MaxProfit();   }
      else if (sequence.totalPL < sequence.maxDrawdown) { sequence.maxDrawdown = sequence.totalPL; SS.MaxDrawdown(); }

      int n = ArraySize(sequence.stop.event) - 1;
      if (!stopPrice) stopPrice = ifDouble(sequence.direction==D_LONG, Bid, Ask);

      sequence.stop.event [n] = CreateEventId();
      sequence.stop.time  [n] = TimeCurrentEx("StopSequence(9)");
      sequence.stop.price [n] = stopPrice;
      sequence.stop.profit[n] = sequence.totalPL;
      RedrawStartStop();

      sequence.status = STATUS_STOPPED;
      if (__LOG()) log("StopSequence(10)  sequence "+ sequence.name +" stopped at "+ NumberToStr(stopPrice, PriceFormat) +", level "+ sequence.level);
      UpdateProfitTargets();
      ShowProfitTargets();
      SS.ProfitPerLevel();
   }

   // update start/stop/auto-resume configuration (sequence.status is STATUS_STOPPED)
   start.conditions = false;

   switch (signal) {
      case SIGNAL_SESSIONBREAK:                          // implies auto-resume and ignores all other conditions
         sessionbreak.waiting = (entryStatus == STATUS_PROGRESSING);
         sequence.status      = STATUS_WAITING;
         break;

      case SIGNAL_TREND:                                 // auto-resume if enabled and StartCondition is @trend
         if (AutoResume && start.trend.description!="") {
            start.trend.condition = true;
            start.conditions      = true;
            stop.trend.condition  = true;
            sequence.status       = STATUS_WAITING;
         }
         else {
            stop.trend.condition = false;
         }
         break;

      case SIGNAL_PRICETIME:                             // no auto-resume
         stop.price.condition = false;
         stop.time.condition  = false;
         break;

      case SIGNAL_TP:                                    // no auto-resume
         stop.profitAbs.condition = false;
         stop.profitPct.condition = false;
         break;

      case NULL:                                         // explicit stop (manual or at end of test)
         break;

      default: return(!catch("StopSequence(11)  unsupported stop signal = "+ signal, ERR_INVALID_PARAMETER));
   }
   SS.StartStopConditions();

   // save sequence
   if (!SaveSequence()) return(false);

   // in tester: pause or stop
   if (IsTesting()) {
      if (IsVisualMode())                         Tester.Pause();
      else if (sequence.status == STATUS_STOPPED) Tester.Stop();
   }
   return(!catch("StopSequence(12)"));
}


/**
 * Add a value to all elements of an integer array.
 *
 * @param  _InOut_ int &array[]
 * @param  _In_    int  value
 *
 * @return bool - success status
 */
bool ArrayAddInt(int &array[], int value) {
   int size = ArraySize(array);
   for (int i=0; i < size; i++) {
      array[i] += value;
   }
   return(!catch("ArrayAddInt(1)"));
}


/**
 * Resume a waiting or stopped trade sequence.
 *
 * @param  int signal - signal which triggered a resume condition or NULL if no condition was triggered (explicit resume)
 *
 * @return bool - success status
 */
bool ResumeSequence(int signal) {
   if (IsLastError())                                                      return(false);
   if (sequence.status!=STATUS_WAITING && sequence.status!=STATUS_STOPPED) return(!catch("ResumeSequence(1)  cannot resume "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   if (Tick==1) /*&&*/ if (!ConfirmFirstTickTrade("ResumeSequence()", "Do you really want to resume sequence "+ sequence.name +" now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));

   datetime startTime;
   double   gridBase, startPrice, lastStopPrice = sequence.stop.price[ArraySize(sequence.stop.price)-1];

   sequence.status = STATUS_STARTING;
   if (__LOG()) log("ResumeSequence(2)  resuming sequence "+ sequence.name +" at level "+ sequence.level +" (stopped at "+ NumberToStr(lastStopPrice, PriceFormat) +", gridbase "+ NumberToStr(grid.base, PriceFormat) +")");

   // configure/deactivate start conditions
   sessionbreak.waiting  = false;
   start.price.condition = false;
   start.time.condition  = false;
   start.trend.condition = (start.trend.condition && AutoResume);
   start.conditions      = false; SS.StartStopConditions();

   // Nach einem vorhergehenden Fehler kann es sein, daß einige Level bereits offen sind und andere noch fehlen.
   if (sequence.level > 0) {
      for (int level=1; level <= sequence.level; level++) {
         int i = Grid.FindOpenPosition(level);
         if (i != -1) {
            gridBase = orders.gridBase[i];                     // look-up a previously used gridbase
            break;
         }
      }
   }
   else if (sequence.level < 0) {
      for (level=-1; level >= sequence.level; level--) {
         i = Grid.FindOpenPosition(level);
         if (i != -1) {
            gridBase = orders.gridBase[i];
            break;
         }
      }
   }

   // Gridbasis neu setzen, wenn keine offenen Positionen gefunden wurden.
   if (!gridBase) {
      startTime  = TimeCurrentEx("ResumeSequence(3)");
      startPrice = ifDouble(sequence.direction==D_SHORT, Bid, Ask);
      GridBase.Change(startTime, grid.base + startPrice - lastStopPrice);
   }
   else {
      grid.base = NormalizeDouble(gridBase, Digits);           // Gridbasis der vorhandenen Positionen übernehmen (sollte schon gesetzt sein, doch wer weiß...)
   }

   // vorherige Positionen wieder in den Markt legen und last(OrderOpenTime) und avg(OrderOpenPrice) erhalten
   if (!RestorePositions(startTime, startPrice)) return(false);

   // neuen Sequenzstart speichern
   ArrayPushInt   (sequence.start.event,  CreateEventId() );
   ArrayPushInt   (sequence.start.time,   startTime       );
   ArrayPushDouble(sequence.start.price,  startPrice      );
   ArrayPushDouble(sequence.start.profit, sequence.totalPL);   // entspricht dem letzten Stop-Wert

   ArrayPushInt   (sequence.stop.event,  0);                   // sequence.starts/stops synchron halten
   ArrayPushInt   (sequence.stop.time,   0);
   ArrayPushDouble(sequence.stop.price,  0);
   ArrayPushDouble(sequence.stop.profit, 0);

   sequence.status = STATUS_PROGRESSING;                       // TODO: correct the resulting gridbase and adjust the previously set stoplosses

   // Stop-Orders vervollständigen
   if (!UpdatePendingOrders()) return(false);

   // Status aktualisieren und speichern
   bool changes;
   int  iNull[];                                               // Wurde in RestorePositions()->Grid.AddPosition() ein Magic-Ticket #-2 for "Spread violation"
   if (!UpdateStatus(changes, iNull)) return(false);           // erzeugt, wird es in UpdateStatus() mit PL=0.00 "geschlossen" und der Sequence-Level verringert.
   if (changes) UpdatePendingOrders();                         // In diesem Fall müssen die Pending-Orders nochmal aktualisiert werden.
   if (!SaveSequence()) return(false);
   RedrawStartStop();

   if (__LOG()) log("ResumeSequence(4)  sequence "+ sequence.name +" resumed at level "+ sequence.level +" (start price "+ NumberToStr(startPrice, PriceFormat) +", new gridbase "+ NumberToStr(grid.base, PriceFormat) +")");
   return(!last_error|catch("ResumeSequence(5)"));
}


/**
 * Restore open positions and limit orders for missed sequence levels. Called from StartSequence() and ResumeSequence().
 *
 * @param  datetime &lpOpenTime  - variable receiving the OpenTime of the last opened position
 * @param  double   &lpOpenPrice - variable receiving the average OpenPrice of all open positions
 *
 * @return bool - success status
 *
 * NOTE: If the sequence is at level 0 the passed variables are not modified.
 */
bool RestorePositions(datetime &lpOpenTime, double &lpOpenPrice) {
   if (IsLastError())                      return(false);
   if (sequence.status != STATUS_STARTING) return(!catch("RestorePositions(1)  cannot restore positions of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   int i, level, missedLevels=ArraySize(sequence.missedLevels);
   bool isMissedLevel, success;
   datetime openTime;
   double openPrice;

   // Long
   if (sequence.level > 0) {
      for (level=1; level <= sequence.level; level++) {
         isMissedLevel = IntInArray(sequence.missedLevels, level);
         i = Grid.FindOpenPosition(level);
         if (i == -1) {
            if (isMissedLevel) success = Grid.AddPendingOrder(level);
            else               success = Grid.AddPosition(level);
            if (!success) return(false);
            i = ArraySize(orders.ticket) - 1;
         }
         else {
            // TODO: check/update the stoploss
         }
         if (!isMissedLevel) {
            openTime   = Max(openTime, orders.openTime[i]);
            openPrice += orders.openPrice[i];
         }
      }
      openPrice /= (Abs(sequence.level)-missedLevels);                  // avg(OpenPrice)
   }

   // Short
   else if (sequence.level < 0) {
      for (level=-1; level >= sequence.level; level--) {
         isMissedLevel = IntInArray(sequence.missedLevels, level);
         i = Grid.FindOpenPosition(level);
         if (i == -1) {
            if (isMissedLevel) success = Grid.AddPendingOrder(level);
            else               success = Grid.AddPosition(level);
            if (!success) return(false);
            i = ArraySize(orders.ticket) - 1;
         }
         else {
            // TODO: check/update the stoploss
         }
         if (!isMissedLevel) {
            openTime   = Max(openTime, orders.openTime[i]);
            openPrice += orders.openPrice[i];
         }
      }
      openPrice /= (Abs(sequence.level)-missedLevels);                  // avg(OpenPrice)
   }

   // write-back results to the passed variables
   if (openTime != 0) {                                                 // sequence.level != 0
      lpOpenTime  = openTime;
      lpOpenPrice = NormalizeDouble(openPrice, Digits);
   }
   return(!catch("RestorePositions(2)"));
}


/**
 * Prüft und synchronisiert die im EA gespeicherten mit den aktuellen Laufzeitdaten.
 *
 * @param  _Out_ bool &gridChanged       - variable indicating whether the current grid base or level changed
 * @param  _Out_ int   activatedOrders[] - array receiving the order indexes of activated client-side stops/limits
 *
 * @return bool - success status
 */
bool UpdateStatus(bool &gridChanged, int activatedOrders[]) {
   gridChanged = gridChanged!=0;
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("UpdateStatus(1)  cannot update order status of "+ StatusDescription(sequence.status) +" sequence "+ sequence.name, ERR_ILLEGAL_STATE));

   ArrayResize(activatedOrders, 0);
   bool wasPending, isClosed, openPositions, updateStatusLocation;
   int  closed[][2], close[2], sizeOfTickets=ArraySize(orders.ticket); ArrayResize(closed, 0);
   sequence.floatingPL = 0;

   // Tickets aktualisieren
   for (int i=0; i < sizeOfTickets; i++) {
      if (!orders.closeTime[i]) {                                                   // Ticket prüfen, wenn es beim letzten Aufruf offen war
         wasPending = (orders.type[i] == OP_UNDEFINED);

         // client-seitige PendingOrders prüfen
         if (wasPending) /*&&*/ if (orders.ticket[i] == -1) {
            if (IsStopTriggered(orders.pendingType[i], orders.pendingPrice[i])) {   // handles stop and limit orders
               if (__LOG()) log("UpdateStatus(2)  "+ UpdateStatus.StopTriggerMsg(i));
               ArrayPushInt(activatedOrders, i);
            }
            continue;
         }

         // Magic-Ticket #-2 prüfen (wird sofort hier "geschlossen")
         if (orders.ticket[i] == -2) {
            orders.closeEvent[i] = CreateEventId();                                 // Event-ID kann sofort vergeben werden.
            orders.closeTime [i] = TimeCurrentEx("UpdateStatus(3)");
            orders.closePrice[i] = orders.openPrice[i];
            orders.closedBySL[i] = true;
            Chart.MarkPositionClosed(i);
            if (__LOG()) log("UpdateStatus(4)  "+ UpdateStatus.StopLossMsg(i));

            sequence.level  -= Sign(orders.level[i]);
            sequence.stops++; SS.Stops();
          //sequence.stopsPL = ...                                                  // unverändert, da P/L des Magic-Tickets #-2 immer 0.00 ist
            gridChanged      = true;
            continue;
         }

         // reguläre server-seitige Tickets
         if (!SelectTicket(orders.ticket[i], "UpdateStatus(5)")) return(false);

         if (wasPending) {
            // beim letzten Aufruf Pending-Order
            if (OrderType() != orders.pendingType[i]) {                             // order limit was executed
               orders.type      [i] = OrderType();
               orders.openEvent [i] = CreateEventId();
               orders.openTime  [i] = OrderOpenTime();
               orders.openPrice [i] = OrderOpenPrice();
               orders.swap      [i] = OrderSwap();
               orders.commission[i] = OrderCommission(); sequence.commission = OrderCommission(); SS.LotSize();
               orders.profit    [i] = OrderProfit();
               Chart.MarkOrderFilled(i);
               if (__LOG()) log("UpdateStatus(6)  "+ UpdateStatus.OrderFillMsg(i));

               if (IsStopOrderType(orders.pendingType[i])) {
                  sequence.level   += Sign(orders.level[i]);
                  sequence.maxLevel = Sign(orders.level[i]) * Max(Abs(sequence.level), Abs(sequence.maxLevel));
                  gridChanged       = true;
               }
               else {
                  ArrayDropInt(sequence.missedLevels, orders.level[i]);             // update missed grid levels
                  SS.MissedLevels();
               }
               updateStatusLocation = updateStatusLocation || !sequence.maxLevel;   // what's this needed for???
            }
         }
         else {
            // beim letzten Aufruf offene Position
            orders.swap      [i] = OrderSwap();
            orders.commission[i] = OrderCommission();
            orders.profit    [i] = OrderProfit();
         }

         isClosed = OrderCloseTime() != 0;                                          // Bei Spikes kann eine Pending-Order ausgeführt *und* bereits geschlossen sein.
         if (!isClosed) {                                                           // weiterhin offenes Ticket
            if (orders.type[i] != OP_UNDEFINED) {
               openPositions = true;
               if (orders.clientsideLimit[i]) /*&&*/ if (IsStopTriggered(orders.type[i], orders.stopLoss[i])) {
                  if (__LOG()) log("UpdateStatus(7)  "+ UpdateStatus.StopTriggerMsg(i));
                  ArrayPushInt(activatedOrders, i);
               }
            }
            sequence.floatingPL = NormalizeDouble(sequence.floatingPL + orders.swap[i] + orders.commission[i] + orders.profit[i], 2);
         }
         else if (orders.type[i] == OP_UNDEFINED) {                                 // jetzt geschlossenes Ticket: gestrichene Pending-Order
            Grid.DropData(i);
            sizeOfTickets--; i--;
         }
         else {
            orders.closeTime [i] = OrderCloseTime();                                // jetzt geschlossenes Ticket: geschlossene Position
            orders.closePrice[i] = OrderClosePrice();
            orders.closedBySL[i] = IsOrderClosedBySL();
            Chart.MarkPositionClosed(i);

            if (orders.closedBySL[i]) {                                             // ausgestoppt
               orders.closeEvent[i] = CreateEventId();                              // Event-ID kann sofort vergeben werden.
               if (__LOG()) log("UpdateStatus(8)  "+ UpdateStatus.StopLossMsg(i));
               sequence.level  -= Sign(orders.level[i]);
               sequence.stops++;
               sequence.stopsPL = NormalizeDouble(sequence.stopsPL + orders.swap[i] + orders.commission[i] + orders.profit[i], 2); SS.Stops();
               gridChanged      = true;
            }
            else {                                                                  // manually closed or automatically closed at test end
               close[0] = OrderCloseTime();
               close[1] = OrderTicket();                                            // Geschlossene Positionen werden zwischengespeichert, um ihnen Event-IDs
               ArrayPushInts(closed, close);                                        // zeitlich *nach* den ausgestoppten Positionen zuweisen zu können.
               if (__LOG()) log("UpdateStatus(9)  "+ UpdateStatus.PositionCloseMsg(i));
               sequence.closedPL = NormalizeDouble(sequence.closedPL + orders.swap[i] + orders.commission[i] + orders.profit[i], 2);
            }
         }
      }
   }

   // Event-IDs geschlossener Positionen setzen (zeitlich nach allen ausgestoppten Positionen)
   int sizeOfClosed = ArrayRange(closed, 0);
   if (sizeOfClosed > 0) {
      ArraySort(closed);
      for (i=0; i < sizeOfClosed; i++) {
         int n = SearchIntArray(orders.ticket, closed[i][1]);
         if (n == -1) return(!catch("UpdateStatus(10)  closed ticket #"+ closed[i][1] +" not found in order arrays", ERR_ILLEGAL_STATE));
         orders.closeEvent[n] = CreateEventId();
      }
      ArrayResize(closed, 0);
   }

   // update PL numbers
   sequence.totalPL = NormalizeDouble(sequence.stopsPL + sequence.closedPL + sequence.floatingPL, 2); SS.TotalPL();
   if      (sequence.totalPL > sequence.maxProfit  ) { sequence.maxProfit   = sequence.totalPL; SS.MaxProfit();   }
   else if (sequence.totalPL < sequence.maxDrawdown) { sequence.maxDrawdown = sequence.totalPL; SS.MaxDrawdown(); }

   // trail gridbase
   if (!sequence.level) {
      if (!sizeOfTickets) {                                                   // the pending order was manually cancelled
         SetLastError(ERR_CANCELLED_BY_USER);
      }
      else {
         double last = grid.base;
         if (sequence.direction == D_LONG) grid.base = MathMin(grid.base, NormalizeDouble((Bid + Ask)/2, Digits));
         else                              grid.base = MathMax(grid.base, NormalizeDouble((Bid + Ask)/2, Digits));

         if (NE(grid.base, last, Digits)) {
            GridBase.Change(TimeCurrentEx("UpdateStatus(11)"), grid.base);
            gridChanged = true;
         }
         else if (NE(orders.gridBase[sizeOfTickets-1], grid.base, Digits)) {  // Gridbasis des letzten Tickets inspizieren, da Trailing online
            gridChanged = true;                                               // u.U. verzögert wird
         }
      }
   }

   // update status file location                                             // TODO: obsolete
   if (updateStatusLocation)
      UpdateStatusLocation();
   return(!catch("UpdateStatus(12)"));
}


/**
 * Compose a log message for a filled entry order.
 *
 * @param  int i - order index
 *
 * @return string
 */
string UpdateStatus.OrderFillMsg(int i) {
   // #1 Stop Sell 0.1 GBPUSD at 1.5457'2 ("SR.8692.+17") was filled[ at 1.5457'2 (0.3 pip [positive ]slippage)]
   string sType         = OperationTypeDescription(orders.pendingType[i]);
   string sPendingPrice = NumberToStr(orders.pendingPrice[i], PriceFormat);
   string comment       = "SR."+ sequence.id +"."+ NumberToStr(orders.level[i], "+.");
   string message       = "#"+ orders.ticket[i] +" "+ sType +" "+ NumberToStr(LotSize, ".+") +" "+ Symbol() +" at "+ sPendingPrice +" (\""+ comment +"\") was filled";

   if (NE(orders.pendingPrice[i], orders.openPrice[i])) {
      double slippage = (orders.openPrice[i] - orders.pendingPrice[i])/Pip;
         if (orders.type[i] == OP_SELL)
            slippage = -slippage;
      string sSlippage;
      if (slippage > 0) sSlippage = DoubleToStr(slippage, Digits & 1) +" pip slippage";
      else              sSlippage = DoubleToStr(-slippage, Digits & 1) +" pip positive slippage";
      message = message +" at "+ NumberToStr(orders.openPrice[i], PriceFormat) +" ("+ sSlippage +")";
   }
   return(message);
}


/**
 * Compose a log message for a closed position.
 *
 * @param  int i - order index
 *
 * @return string
 */
string UpdateStatus.PositionCloseMsg(int i) {
   // #1 Sell 0.1 GBPUSD at 1.5457'2 ("SR.8692.+17") was closed at 1.5457'2
   string sType       = OperationTypeDescription(orders.type[i]);
   string sOpenPrice  = NumberToStr(orders.openPrice[i], PriceFormat);
   string sClosePrice = NumberToStr(orders.closePrice[i], PriceFormat);
   string comment     = "SR."+ sequence.id +"."+ NumberToStr(orders.level[i], "+.");
   string message     = "#"+ orders.ticket[i] +" "+ sType +" "+ NumberToStr(LotSize, ".+") +" "+ Symbol() +" at "+ sOpenPrice +" (\""+ comment +"\") was closed at "+ sClosePrice;

   return(message);
}


/**
 * Compose a log message for an executed stoploss.
 *
 * @param  int i - order index
 *
 * @return string
 */
string UpdateStatus.StopLossMsg(int i) {
   // [magic ticket ]#1 Sell 0.1 GBPUSD at 1.5457'2 ("SR.8692.+17"), [client-side ]stoploss 1.5457'2 was executed[ at 1.5457'2 (0.3 pip [positive ]slippage)]
   string sMagic     = ifString(orders.ticket[i]==-2, "magic ticket ", "");
   string sType      = OperationTypeDescription(orders.type[i]);
   string sOpenPrice = NumberToStr(orders.openPrice[i], PriceFormat);
   string sStopSide  = ifString(orders.clientsideLimit[i], "client-side ", "");
   string sStopLoss  = NumberToStr(orders.stopLoss[i], PriceFormat);
   string comment    = "SR."+ sequence.id +"."+ NumberToStr(orders.level[i], "+.");
   string message    = sMagic +"#"+ orders.ticket[i] +" "+ sType +" "+ NumberToStr(LotSize, ".+") +" "+ Symbol() +" at "+ sOpenPrice +" (\""+ comment +"\"), "+ sStopSide +"stoploss "+ sStopLoss +" was executed";

   if (NE(orders.closePrice[i], orders.stopLoss[i])) {
      double slippage = (orders.stopLoss[i] - orders.closePrice[i])/Pip;
         if (orders.type[i] == OP_SELL)
            slippage = -slippage;
      string sSlippage;
      if (slippage > 0) sSlippage = DoubleToStr(slippage, Digits & 1) +" pip slippage";
      else              sSlippage = DoubleToStr(-slippage, Digits & 1) +" pip positive slippage";
      message = message +" at "+ NumberToStr(orders.closePrice[i], PriceFormat) +" ("+ sSlippage +")";
   }
   return(message);
}


/**
 * Compose a log message for a triggered client-side stop or limit.
 *
 * @param  int i - order index
 *
 * @return string
 */
string UpdateStatus.StopTriggerMsg(int i) {
   string sSequence = sequence.name +"."+ NumberToStr(orders.level[i], "+.");

   if (orders.type[i] == OP_UNDEFINED) {
      // sequence L.8692.+17 client-side Stop Buy at 1.5457'2 was triggered
      return("sequence "+ sSequence +" client-side "+ OperationTypeDescription(orders.pendingType[i]) +" at "+ NumberToStr(orders.pendingPrice[i], PriceFormat) +" was triggered");
   }
   else {
      // sequence L.8692.+17 #1 client-side stoploss at 1.5457'2 was triggered
      return("sequence "+ sSequence +" #"+ orders.ticket[i] +" client-side stoploss at "+ NumberToStr(orders.stopLoss[i], PriceFormat) +" was triggered");
   }
}


/**
 * Whether a chart command was sent to the expert. If so, the command is retrieved and stored.
 *
 * @param  string commands[] - array to store received commands in
 *
 * @return bool
 */
bool EventListener_ChartCommand(string &commands[]) {
   if (!__CHART()) return(false);

   static string label, mutex; if (!StringLen(label)) {
      label = __NAME() +".command";
      mutex = "mutex."+ label;
   }

   // check non-synchronized (read-only) for a command to prevent aquiring the lock on each tick
   if (ObjectFind(label) == 0) {
      // aquire the lock for write-access if there's indeed a command
      if (!AquireLock(mutex, true)) return(false);

      ArrayPushString(commands, ObjectDescription(label));
      ObjectDelete(label);
      return(ReleaseLock(mutex));
   }
   return(false);
}


/**
 * Ob die aktuell selektierte Order durch den StopLoss geschlossen wurde (client- oder server-seitig).
 *
 * @return bool
 */
bool IsOrderClosedBySL() {
   bool position   = OrderType()==OP_BUY || OrderType()==OP_SELL;
   bool closed     = OrderCloseTime() != 0;                          // geschlossene Position
   bool closedBySL = false;

   if (closed) /*&&*/ if (position) {
      if (StrEndsWithI(OrderComment(), "[sl]")) {
         closedBySL = true;
      }
      else {
         // StopLoss aus Orderdaten verwenden (ist bei client-seitiger Verwaltung nur dort gespeichert)
         int i = SearchIntArray(orders.ticket, OrderTicket());

         if (i == -1)             return(!catch("IsOrderClosedBySL(1)  closed position #"+ OrderTicket() +" not found in order arrays", ERR_ILLEGAL_STATE));
         if (!orders.stopLoss[i]) return(!catch("IsOrderClosedBySL(2)  cannot resolve status of position #"+ OrderTicket() +" (closed but has neither local nor remote SL attached)", ERR_ILLEGAL_STATE));

         if      (orders.closedBySL[i])   closedBySL = true;
         else if (OrderType() == OP_BUY ) closedBySL = LE(OrderClosePrice(), orders.stopLoss[i]);
         else if (OrderType() == OP_SELL) closedBySL = GE(OrderClosePrice(), orders.stopLoss[i]);
      }
   }
   return(closedBySL);
}


/**
 * Whether a start or resume condition is satisfied for a waiting sequence. Price and time conditions are AND combined.
 *
 * @return int - the fulfilled start condition signal identfier or NULL if no start condition is satisfied
 */
int IsStartSignal() {
   if (last_error || sequence.status!=STATUS_WAITING) return(NULL);
   string message;
   bool triggered, resuming = (sequence.maxLevel != 0);

   // -- sessionbreak: wait for the stop price to be reached ----------------------------------------------------------------
   if (sessionbreak.waiting) {
      double price = sequence.stop.price[ArraySize(sequence.stop.price)-1];
      if (sequence.direction == D_LONG) triggered = (Ask <= price);
      else                              triggered = (Bid >= price);
      if (triggered) {
         if (__LOG()) log("IsStartSignal(1)  sequence "+ sequence.name +" resume condition \"@sessionbreak price "+ NumberToStr(price, PriceFormat) +"\" fulfilled ("+ ifString(sequence.direction==D_LONG, "ask", "bid") +": "+ NumberToStr(ifDouble(sequence.direction==D_LONG, Ask, Bid), PriceFormat) +")");
         return(SIGNAL_SESSIONBREAK);
      }
      return(NULL);                       // temporarily ignore all other conditions
   }

   if (start.conditions) {
      // -- start.trend: bei Trendwechsel in Richtung der Sequenz erfüllt ---------------------------------------------------
      if (start.trend.condition) {
         if (IsBarOpenEvent(start.trend.timeframe)) {
            int trend = GetStartTrendValue(1);

            if ((sequence.direction==D_LONG && trend==1) || (sequence.direction==D_SHORT && trend==-1)) {
               message = "IsStartSignal(2)  sequence "+ sequence.name +" "+ ifString(!resuming, "start", "resume") +" condition \"@"+ start.trend.description +"\" fulfilled ("+ ifString(sequence.direction==D_LONG, "ask", "bid") +": "+ NumberToStr(ifDouble(sequence.direction==D_LONG, Ask, Bid), PriceFormat) +")";
               if (!IsTesting()) warn(message);
               else if (__LOG()) log(message);
               return(SIGNAL_TREND);
            }
         }
         return(NULL);
      }

      // -- start.price: erfüllt, wenn der aktuelle Preis den Wert berührt oder kreuzt --------------------------------------
      if (start.price.condition) {
         triggered = false;
         switch (start.price.type) {
            case PRICE_BID:    price =  Bid;        break;
            case PRICE_ASK:    price =  Ask;        break;
            case PRICE_MEDIAN: price = (Bid+Ask)/2; break;
         }
         if (start.price.lastValue != 0) {
            if (start.price.lastValue < start.price.value) triggered = (price >= start.price.value);  // price crossed upwards
            else                                           triggered = (price <= start.price.value);  // price crossed downwards
         }
         start.price.lastValue = price;
         if (!triggered) return(NULL);

         message = "IsStartSignal(3)  sequence "+ sequence.name +" "+ ifString(!resuming, "start", "resume") +" condition \"@"+ start.price.description +"\" fulfilled";
         if (!IsTesting()) warn(message);
         else if (__LOG()) log(message);
      }

      // -- start.time: zum angegebenen Zeitpunkt oder danach erfüllt -------------------------------------------------------
      if (start.time.condition) {
         if (TimeCurrentEx("IsStartSignal(4)") < start.time.value)
            return(NULL);

         message = "IsStartSignal(5)  sequence "+ sequence.name +" "+ ifString(!resuming, "start", "resume") +" condition \"@"+ start.time.description +"\" fulfilled ("+ ifString(sequence.direction==D_LONG, "ask", "bid") +": "+ NumberToStr(ifDouble(sequence.direction==D_LONG, Ask, Bid), PriceFormat) +")";
         if (!IsTesting()) warn(message);
         else if (__LOG()) log(message);
      }

      // -- both price and time conditions are fullfilled (AND combined) ----------------------------------------------------
      return(SIGNAL_PRICETIME);
   }

   // no start condition is a valid start signal before first sequence start only
   if (!ArraySize(sequence.start.event)) {
      return(SIGNAL_PRICETIME);                    // a manual start implies a fulfilled price/time condition
   }

   return(NULL);
}


/**
 * Whether a stop condition is satisfied for a progressing sequence. All stop conditions are OR combined.
 *
 * @return int - the fulfilled stop condition signal identifier or NULL if no stop condition is satisfied
 */
int IsStopSignal() {
   if (last_error || sequence.status!=STATUS_PROGRESSING) return(NULL);
   string message;

   // -- stop.trend: bei Trendwechsel entgegen der Richtung der Sequenz erfüllt ---------------------------------------------
   if (stop.trend.condition) {
      if (IsBarOpenEvent(stop.trend.timeframe)) {
         int trend = GetStopTrendValue(1);

         if ((sequence.direction==D_LONG && trend==-1) || (sequence.direction==D_SHORT && trend==1)) {
            message = "IsStopSignal(1)  sequence "+ sequence.name +" stop condition \"@"+ stop.trend.description +"\" fulfilled ("+ ifString(sequence.direction==D_LONG, "bid", "ask") +": "+ NumberToStr(ifDouble(sequence.direction==D_LONG, Bid, Ask), PriceFormat) +")";
            if (!IsTesting()) warn(message);
            else if (__LOG()) log(message);
            return(SIGNAL_TREND);
         }
      }
   }

   // -- stop.price: erfüllt, wenn der aktuelle Preis den Wert berührt oder kreuzt ------------------------------------------
   if (stop.price.condition) {
      bool triggered = false;
      double price;
      switch (stop.price.type) {
         case PRICE_BID:    price =  Bid;        break;
         case PRICE_ASK:    price =  Ask;        break;
         case PRICE_MEDIAN: price = (Bid+Ask)/2; break;
      }
      if (stop.price.lastValue != 0) {
         if (stop.price.lastValue < stop.price.value) triggered = (price >= stop.price.value);  // price crossed upwards
         else                                         triggered = (price <= stop.price.value);  // price crossed downwards
      }
      stop.price.lastValue = price;

      if (triggered) {
         message = "IsStopSignal(2)  sequence "+ sequence.name +" stop condition \"@"+ stop.price.description +"\" fulfilled";
         if (!IsTesting()) warn(message);
         else if (__LOG()) log(message);
         stop.price.condition = false;
         return(SIGNAL_PRICETIME);
      }
   }

   // -- stop.time: zum angegebenen Zeitpunkt oder danach erfüllt -----------------------------------------------------------
   if (stop.time.condition) {
      if (TimeCurrentEx("IsStopSignal(3)") >= stop.time.value) {
         message = "IsStopSignal(4)  sequence "+ sequence.name +" stop condition \"@"+ stop.time.description +"\" fulfilled ("+ ifString(sequence.direction==D_LONG, "bid", "ask") +": "+ NumberToStr(ifDouble(sequence.direction==D_LONG, Bid, Ask), PriceFormat) +")";
         if (!IsTesting()) warn(message);
         else if (__LOG()) log(message);
         stop.time.condition = false;
         return(SIGNAL_PRICETIME);
      }
   }

   // -- stop.profitAbs: ----------------------------------------------------------------------------------------------------
   if (stop.profitAbs.condition) {
      if (sequence.totalPL >= stop.profitAbs.value) {
         message = "IsStopSignal(5)  sequence "+ sequence.name +" stop condition \"@"+ stop.profitAbs.description +"\" fulfilled ("+ ifString(sequence.direction==D_LONG, "bid", "ask") +": "+ NumberToStr(ifDouble(sequence.direction==D_LONG, Bid, Ask), PriceFormat) +")";
         if (!IsTesting()) warn(message);
         else if (__LOG()) log(message);
         stop.profitAbs.condition = false;
         return(SIGNAL_TP);
      }
   }

   // -- stop.profitPct: ----------------------------------------------------------------------------------------------------
   if (stop.profitPct.condition) {
      if (stop.profitPct.absValue == INT_MAX) {
         stop.profitPct.absValue = stop.profitPct.value/100 * sequence.startEquity;
      }
      if (sequence.totalPL >= stop.profitPct.absValue) {
         message = "IsStopSignal(6)  sequence "+ sequence.name +" stop condition \"@"+ stop.profitPct.description +"\" fulfilled ("+ ifString(sequence.direction==D_LONG, "bid", "ask") +": "+ NumberToStr(ifDouble(sequence.direction==D_LONG, Bid, Ask), PriceFormat) +")";
         if (!IsTesting()) warn(message);
         else if (__LOG()) log(message);
         stop.profitPct.condition = false;
         return(SIGNAL_TP);
      }
   }

   // -- session break ------------------------------------------------------------------------------------------------------
   if (IsSessionBreak()) {
      message = "IsStopSignal(7)  sequence "+ sequence.name +" stop condition \"sessionbreak from "+ GmtTimeFormat(sessionbreak.starttime, "%Y.%m.%d %H:%M:%S") +" to "+ GmtTimeFormat(sessionbreak.endtime, "%Y.%m.%d %H:%M:%S") +"\" fulfilled ("+ ifString(sequence.direction==D_LONG, "bid", "ask") +": "+ NumberToStr(ifDouble(sequence.direction==D_LONG, Bid, Ask), PriceFormat) +")";
      if (__LOG()) log(message);
      return(SIGNAL_SESSIONBREAK);
   }

   return(NULL);
}


/**
 * Whether the current server time falls into a sessionbreak. After function return the global vars sessionbreak.starttime
 * and sessionbreak.endtime are up-to-date (sessionbreak.active is not modified).
 *
 * @return bool
 */
bool IsSessionBreak() {
   if (IsLastError()) return(false);

   datetime serverTime = TimeServer();
   if (!serverTime) return(false);

   // check whether to recalculate sessionbreak times
   if (serverTime >= sessionbreak.endtime) {
      int startOffset = Sessionbreak.StartTime % DAYS;            // sessionbreak start time in seconds since Midnight
      int endOffset   = Sessionbreak.EndTime % DAYS;              // sessionbreak end time in seconds since Midnight
      if (!startOffset && !endOffset)
         return(false);                                           // skip session breaks if both values are set to Midnight

      // calculate today's sessionbreak end time
      datetime fxtNow  = ServerToFxtTime(serverTime);
      datetime today   = fxtNow - fxtNow%DAYS;                    // today's Midnight in FXT
      datetime fxtTime = today + endOffset;                       // today's sessionbreak end time in FXT

      // determine the next regular sessionbreak end time
      int dow = TimeDayOfWeekFix(fxtTime);
      while (fxtTime <= fxtNow || dow==SATURDAY || dow==SUNDAY) {
         fxtTime += 1*DAY;
         dow = TimeDayOfWeekFix(fxtTime);
      }
      datetime fxtResumeTime = fxtTime;
      sessionbreak.endtime = FxtToServerTime(fxtResumeTime);

      // determine the corresponding sessionbreak start time
      datetime resumeDay = fxtResumeTime - fxtResumeTime%DAYS;    // resume day's Midnight in FXT
      fxtTime = resumeDay + startOffset;                          // resume day's sessionbreak start time in FXT

      dow = TimeDayOfWeekFix(fxtTime);
      while (fxtTime >= fxtResumeTime || dow==SATURDAY || dow==SUNDAY) {
         fxtTime -= 1*DAY;
         dow = TimeDayOfWeekFix(fxtTime);
      }
      sessionbreak.starttime = FxtToServerTime(fxtTime);

      if (__LOG()) log("IsSessionBreak(1)  recalculated next sessionbreak: from "+ GmtTimeFormat(sessionbreak.starttime, "%a, %Y.%m.%d %H:%M:%S") +" to "+ GmtTimeFormat(sessionbreak.endtime, "%a, %Y.%m.%d %H:%M:%S"));
   }

   // perform the actual check
   return(serverTime >= sessionbreak.starttime);                  // here sessionbreak.endtime is always in the future
}


/**
 * Execute orders with activated client-side stops or limits. Called only from onTick().
 *
 * @param  int orders[] - indexes of orders with activated stops or limits
 *
 * @return bool - success status
 */
bool ExecuteOrders(int orders[]) {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("ExecuteOrders(1)  cannot execute client-side orders of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   int sizeOfOrders = ArraySize(orders);
   if (!sizeOfOrders) return(true);

   int button, ticket;
   int oe[];

   // Der Stop kann eine getriggerte Entry-Order oder ein getriggerter StopLoss sein.
   for (int i, n=0; n < sizeOfOrders; n++) {
      i = orders[n];
      if (i >= ArraySize(orders.ticket))     return(!catch("ExecuteOrders(2)  illegal order index "+ i +" in parameter orders = "+ IntsToStr(orders, NULL), ERR_INVALID_PARAMETER));

      // if getriggerte Entry-Order
      if (orders.ticket[i] == -1) {
         if (orders.type[i] != OP_UNDEFINED) return(!catch("ExecuteOrders(3)  "+ OperationTypeDescription(orders.pendingType[i]) +" order at index "+ i +" is already marked as open", ERR_ILLEGAL_STATE));

         if (Tick==1) /*&&*/ if (!ConfirmFirstTickTrade("ExecuteOrders()", "Do you really want to execute a triggered client-side "+ OperationTypeDescription(orders.pendingType[i]) +" order now?"))
            return(!SetLastError(ERR_CANCELLED_BY_USER));

         int type  = orders.pendingType[i] % 2;
         int level = orders.level[i];
         bool clientSL = false;                                               // zuerst versuchen, server-seitigen StopLoss zu setzen...

         ticket = SubmitMarketOrder(type, level, clientSL, oe);

         // ab dem letzten Level ggf. client-seitige Stop-Verwaltung
         orders.clientsideLimit[i] = (ticket <= 0);

         if (ticket <= 0) {
            if (level != sequence.level)          return(false);
            if (oe.Error(oe) != ERR_INVALID_STOP) return(false);
            // if market violated
            if (ticket == -1) {
               return(!catch("ExecuteOrders(4)  sequence "+ sequence.name +"."+ NumberToStr(level, "+.") +" spread violated ("+ NumberToStr(oe.Bid(oe), PriceFormat) +"/"+ NumberToStr(oe.Ask(oe), PriceFormat) +") by "+ OperationTypeDescription(type) +" at "+ NumberToStr(oe.OpenPrice(oe), PriceFormat) +", sl="+ NumberToStr(oe.StopLoss(oe), PriceFormat), oe.Error(oe)));
            }
            // if stop distance violated
            else if (ticket == -2) {
               clientSL = true;
               ticket = SubmitMarketOrder(type, level, clientSL, oe);         // danach client-seitige Stop-Verwaltung (ab dem letzten Level)
               if (ticket <= 0) return(false);
               warn("ExecuteOrders(5)  sequence "+ sequence.name +"."+ NumberToStr(level, "+.") +" #"+ ticket +" client-side stoploss at "+ NumberToStr(oe.StopLoss(oe), PriceFormat) +" installed");
            }
            // on all other errors
            else return(!catch("ExecuteOrders(6)  unknown ticket return value "+ ticket, oe.Error(oe)));
         }
         orders.ticket[i] = ticket;
         continue;
      }

      // getriggerter StopLoss
      if (orders.clientsideLimit[i]) {
         if (orders.ticket[i] == -2)         return(!catch("ExecuteOrders(7)  cannot process client-side stoploss of magic ticket #"+ orders.ticket[i], ERR_ILLEGAL_STATE));
         if (orders.type[i] == OP_UNDEFINED) return(!catch("ExecuteOrders(8)  #"+ orders.ticket[i] +" with client-side stoploss still marked as pending", ERR_ILLEGAL_STATE));
         if (orders.closeTime[i] != 0)       return(!catch("ExecuteOrders(9)  #"+ orders.ticket[i] +" with client-side stoploss already marked as closed", ERR_ILLEGAL_STATE));

         if (Tick==1) /*&&*/ if (!ConfirmFirstTickTrade("ExecuteOrders()", "Do you really want to execute a triggered client-side stoploss now?"))
            return(!SetLastError(ERR_CANCELLED_BY_USER));

         double lots        = NULL;
         double slippage    = 0.1;
         color  markerColor = CLR_NONE;
         int    oeFlags     = NULL;
         if (!OrderCloseEx(orders.ticket[i], lots, slippage, markerColor, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));

         orders.closedBySL[i] = true;
      }
   }
   ArrayResize(oe, 0);

   // Status aktualisieren und speichern
   bool bNull;
   int  iNull[];
   if (!UpdateStatus(bNull, iNull)) return(false);
   if (!SaveSequence()) return(false);

   return(!last_error|catch("ExecuteOrders(10)"));
}


/**
 * Trail existing, open missing and delete obsolete pending orders.
 *
 * @return bool - success status
 */
bool UpdatePendingOrders() {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("UpdatePendingOrders(1)  cannot update orders of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   int type, limitOrders, level, lastExistingLevel, nextLevel=sequence.level + ifInt(sequence.direction==D_LONG, 1, -1), sizeOfTickets=ArraySize(orders.ticket);
   bool nextStopExists, ordersChanged;
   string sMissedLevels = "";

   // check if the stop order for the next level exists (always at the last index)
   int i = sizeOfTickets - 1;
   if (sizeOfTickets > 0) {
      if (!orders.closeTime[i] && orders.type[i]==OP_UNDEFINED) { // a pending stop or limit order
         if (orders.level[i] == nextLevel) {                      // the next stop order
            nextStopExists = true;
         }
         else if (IsStopOrderType(orders.pendingType[i])) {
            int error = Grid.DeleteOrder(i);                      // delete an obsolete old stop order (always at the last index)
            if (!error) {
               sizeOfTickets--;
               ordersChanged = true;
            }
            else if (error == -1) {                               // TODO: handle the already opened pending order
               if (__LOG()) log("UpdatePendingOrders(2)  sequence "+ sequence.name +"."+ NumberToStr(orders.level[i], "+.") +" pending #"+ orders.ticket[i] +" was already executed");
               return(!catch("UpdatePendingOrders(3)", ERR_INVALID_TRADE_PARAMETERS));
            }
            else return(false);
         }
      }
   }

   // find the last open order of an active level (an open position or a pending limit order)
   if (sequence.level != 0) {
      for (i=sizeOfTickets-1; i >= 0; i--) {
         level = Abs(orders.level[i]);
         if (!orders.closeTime[i]) {
            if (level < Abs(nextLevel)) {
               lastExistingLevel = orders.level[i];
               break;
            }
         }
         if (level == 1) break;
      }
      if (lastExistingLevel != sequence.level) {
         return(!catch("UpdatePendingOrders(4)  lastExistingOrder("+ lastExistingLevel +") != sequence.level("+ sequence.level +")", ERR_ILLEGAL_STATE));
      }
   }

   // trail a first level stop order (always an existing next level order, thus at the last index)
   if (!sequence.level && nextStopExists) {
      i = sizeOfTickets - 1;
      if (NE(grid.base, orders.gridBase[i], Digits)) {
         static double lastTrailed = INT_MIN;                     // Avoid ERR_TOO_MANY_REQUESTS caused by contacting the trade server
         if (IsTesting() || GetTickCount()-lastTrailed > 3000) {  // at each tick. Wait 3 seconds between consecutive trailings.
            type = Grid.TrailPendingOrder(i); if (!type) return(false);
            if (IsLimitOrderType(type)) {                         // TrailPendingOrder() missed a level
               lastExistingLevel = nextLevel;                     // -1 | +1
               sequence.level    = nextLevel;
               sequence.maxLevel = Max(Abs(sequence.level), Abs(sequence.maxLevel)) * lastExistingLevel;
               nextLevel        += nextLevel;                     // -2 | +2
               nextStopExists    = false;
            }
            ordersChanged = true;
            lastTrailed = GetTickCount();
         }
      }
   }

   // add all missing levels (pending limit or stop orders) up to the next sequence level
   if (!nextStopExists) {
      while (true) {
         if (IsLimitOrderType(type)) {                            // TrailPendingOrder() or AddPendingOrder() missed a level
            limitOrders++;
            ArrayPushInt(sequence.missedLevels, lastExistingLevel);
            sMissedLevels = sMissedLevels +", "+ lastExistingLevel;
         }
         level = lastExistingLevel + Sign(nextLevel);
         type = Grid.AddPendingOrder(level); if (!type) return(false);
         if (level == nextLevel) {
            if (IsLimitOrderType(type)) {                         // a limit order was opened
               sequence.level    = nextLevel;
               sequence.maxLevel = Max(Abs(sequence.level), Abs(sequence.maxLevel)) * Sign(nextLevel);
               nextLevel        += Sign(nextLevel);
            }
            else {
               nextStopExists = true;
               ordersChanged = true;
               break;
            }
         }
         lastExistingLevel = level;
      }
   }

   if (limitOrders > 0) {
      sMissedLevels = StrRight(sMissedLevels, -2); SS.MissedLevels();
      if (__LOG()) log("UpdatePendingOrders(5)  sequence "+ sequence.name +" opened "+ limitOrders +" limit order"+ ifString(limitOrders==1, " for missed level", "s for missed levels") +" ["+ sMissedLevels +"]");
   }
   UpdateProfitTargets();
   ShowProfitTargets();
   SS.ProfitPerLevel();

   if (ordersChanged)
      if (!SaveSequence()) return(false);
   return(!catch("UpdatePendingOrders(6)"));
}


/**
 * Löscht alle gespeicherten Änderungen der Gridbasis und initialisiert sie mit dem angegebenen Wert.
 *
 * @param  datetime time  - Zeitpunkt
 * @param  double   value - neue Gridbasis
 *
 * @return double - neue Gridbasis oder 0, falls ein Fehler auftrat
 */
double GridBase.Reset(datetime time, double value) {
   if (IsLastError()) return(0);

   ArrayResize(grid.base.event, 0);
   ArrayResize(grid.base.time,  0);
   ArrayResize(grid.base.value, 0);

   return(GridBase.Change(time, value));
}


/**
 * Speichert eine Änderung der Gridbasis.
 *
 * @param  datetime time  - Zeitpunkt der Änderung
 * @param  double   value - neue Gridbasis
 *
 * @return double - die neue Gridbasis
 */
double GridBase.Change(datetime time, double value) {
   value = NormalizeDouble(value, Digits);

   if (sequence.maxLevel == 0) {                            // vor dem ersten ausgeführten Trade werden vorhandene Werte überschrieben
      ArrayResize(grid.base.event, 0);
      ArrayResize(grid.base.time,  0);
      ArrayResize(grid.base.value, 0);
   }

   int size = ArraySize(grid.base.event);                   // ab dem ersten ausgeführten Trade werden neue Werte angefügt
   if (size == 0) {
      ArrayPushInt   (grid.base.event, CreateEventId());
      ArrayPushInt   (grid.base.time,  time           );
      ArrayPushDouble(grid.base.value, value          );
      size++;
   }
   else {
      datetime lastStartTime = sequence.start.time[ArraySize(sequence.start.time)-1];
      int minute=time/MINUTE, lastMinute=grid.base.time[size-1]/MINUTE;

      if (time<=lastStartTime || minute!=lastMinute) {      // store all events
         ArrayPushInt   (grid.base.event, CreateEventId());
         ArrayPushInt   (grid.base.time,  time           );
         ArrayPushDouble(grid.base.value, value          );
         size++;
      }
      else {                                                // compact redundant events, store only the last one per minute
         grid.base.event[size-1] = CreateEventId();
         grid.base.time [size-1] = time;
         grid.base.value[size-1] = value;
      }
   }

   grid.base = value; SS.GridBase();
   return(value);
}


/**
 * Open a pending entry order for the specified grid level and add it to the order arrays. Depending on the market a stop or
 * a limit order is opened.
 *
 * @param  int level - grid level of the order to open: -n...1 | 1...+n
 *
 * @return int - order type of the openend pending order or NULL in case of errors
 */
int Grid.AddPendingOrder(int level) {
   if (IsLastError())                                                           return(NULL);
   if (sequence.status!=STATUS_STARTING && sequence.status!=STATUS_PROGRESSING) return(!catch("Grid.AddPendingOrder(1)  cannot add order to "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   int pendingType = ifInt(sequence.direction==D_LONG, OP_BUYSTOP, OP_SELLSTOP);

   if (Tick==1) /*&&*/ if (!ConfirmFirstTickTrade("Grid.AddPendingOrder()", "Do you really want to submit a new "+ OperationTypeDescription(pendingType) +" order now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));

   double price=grid.base + level*GridSize*Pips, bid=MarketInfo(Symbol(), MODE_BID), ask=MarketInfo(Symbol(), MODE_ASK);
   int counter, ticket, oe[];
   if (sequence.direction == D_LONG) pendingType = ifInt(GT(price, bid, Digits), OP_BUYSTOP, OP_BUYLIMIT);
   else                              pendingType = ifInt(LT(price, ask, Digits), OP_SELLSTOP, OP_SELLLIMIT);

   // loop until a pending order was opened or a non-fixable error occurred
   while (true) {
      if (IsStopOrderType(pendingType)) ticket = SubmitStopOrder(pendingType, level, oe);
      else                              ticket = SubmitLimitOrder(pendingType, level, oe);
      if (ticket > 0) break;
      if (oe.Error(oe) != ERR_INVALID_STOP) return(NULL);
      counter++;
      if (counter > 9) return(!catch("Grid.AddPendingOrder(2)  sequence "+ sequence.name +"."+ NumberToStr(level, "+.") +" stopping trade request loop after "+ counter +" unsuccessful tries, last error", oe.Error(oe)));
                                                               // market violated: switch order type and ignore price, thus preventing
      if (ticket == -1) {                                      // the same pending order type again and again caused by a stalled price feed
         if (__LOG()) log("Grid.AddPendingOrder(3)  sequence "+ sequence.name +"."+ NumberToStr(level, "+.") +" illegal price "+ OperationTypeDescription(pendingType) +" at "+ NumberToStr(oe.OpenPrice(oe), PriceFormat) +" (market "+ NumberToStr(oe.Bid(oe), PriceFormat) +"/"+ NumberToStr(oe.Ask(oe), PriceFormat) +"), opening "+ ifString(IsStopOrderType(pendingType), "limit", "stop") +" order instead", oe.Error(oe));
         pendingType += ifInt(pendingType <= OP_SELLLIMIT, 2, -2);
      }
      else if (ticket == -2) {                                 // stop distance violated: use client-side stop management
         ticket = -1;
         warn("Grid.AddPendingOrder(4)  sequence "+ sequence.name +"."+ NumberToStr(level, "+.") +" client-side "+ ifString(IsStopOrderType(pendingType), "stop", "limit") +" for "+ OperationTypeDescription(pendingType) +" at "+ NumberToStr(oe.OpenPrice(oe), PriceFormat) +" installed");
         break;
      }
      else return(!catch("Grid.AddPendingOrder(5)  unknown "+ ifString(IsStopOrderType(pendingType), "SubmitStopOrder", "SubmitLimitOrder") +" return value "+ ticket, oe.Error(oe)));
   }

   // prepare order dataset
   //int    ticket          = ...                  // use as is
   //int    level           = ...                  // ...
   //double grid.base       = ...                  // ...

   //int    pendingType     = ...                  // ...
   datetime pendingTime     = oe.OpenTime(oe); if (ticket < 0) pendingTime = TimeCurrentEx("Grid.AddPendingOrder(6)");
   double   pendingPrice    = oe.OpenPrice(oe);

   int      openType        = OP_UNDEFINED;
   int      openEvent       = NULL;
   datetime openTime        = NULL;
   double   openPrice       = NULL;
   int      closeEvent      = NULL;
   datetime closeTime       = NULL;
   double   closePrice      = NULL;
   double   stopLoss        = oe.StopLoss(oe);
   bool     clientsideLimit = (ticket <= 0);
   bool     closedBySL      = false;

   double   swap            = NULL;
   double   commission      = NULL;
   double   profit          = NULL;

   // store dataset
   if (!Grid.PushData(ticket, level, grid.base, pendingType, pendingTime, pendingPrice, openType, openEvent, openTime, openPrice, closeEvent, closeTime, closePrice, stopLoss, clientsideLimit, closedBySL, swap, commission, profit))
      return(NULL);

   if (last_error || catch("Grid.AddPendingOrder(7)"))
      return(NULL);
   return(pendingType);
}


/**
 * Legt die angegebene Position in den Markt und fügt den Gridarrays deren Daten hinzu. Aufruf nur in RestoreActiveGridLevels().
 *
 * @param  int level - Gridlevel der Position
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.AddPosition(int level) {
   if (IsLastError())                      return( false);
   if (sequence.status != STATUS_STARTING) return(_false(catch("Grid.AddPosition(1)  cannot add position to "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE)));
   if (!level)                             return(_false(catch("Grid.AddPosition(2)  illegal parameter level = "+ level, ERR_INVALID_PARAMETER)));

   int orderType = ifInt(sequence.direction==D_LONG, OP_BUY, OP_SELL);

   if (Tick==1) /*&&*/ if (!ConfirmFirstTickTrade("Grid.AddPosition()", "Do you really want to submit a Market "+ OperationTypeDescription(orderType) +" order now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));

   // Position öffnen
   bool clientsideSL = false;
   int oe[];
   int ticket = SubmitMarketOrder(orderType, level, clientsideSL, oe);     // zuerst server-seitigen StopLoss setzen (clientsideSL=FALSE)

   if (ticket <= 0) {
      if (oe.Error(oe) != ERR_INVALID_STOP) return(false);
      // if market violated
      if (ticket == -1) {
         ticket = -2;                                                      // assign ticket #-2 for decreased grid level, UpdateStatus() will "close" it with PL=0.00
         clientsideSL = true;
         oe.setOpenTime(oe, TimeCurrentEx("Grid.AddPosition(3)"));
         if (__LOG()) log("Grid.AddPosition(4)  sequence "+ sequence.name +" position at level "+ level +" would be immediately closed by SL="+ NumberToStr(oe.StopLoss(oe), PriceFormat) +" (market: "+ NumberToStr(oe.Bid(oe), PriceFormat) +"/"+ NumberToStr(oe.Ask(oe), PriceFormat) +"), decreasing grid level...");
      }
      // if stop distance violated
      else if (ticket == -2) {
         clientsideSL = true;
         ticket = SubmitMarketOrder(orderType, level, clientsideSL, oe);   // use client-side stop management
         if (ticket <= 0) return(false);
         warn("Grid.AddPosition(5)  sequence "+ sequence.name +" level "+ level +" #"+ ticket +" client-side stoploss installed at "+ NumberToStr(oe.StopLoss(oe), PriceFormat));
      }
      // on all other errors
      else return(_false(catch("Grid.AddPosition(6)  unknown ticket value "+ ticket, oe.Error(oe))));
   }

   // Daten speichern
   //int    ticket       = ...                     // unverändert
   //int    level        = ...                     // unverändert
   //double grid.base    = ...                     // unverändert

   int      pendingType  = OP_UNDEFINED;
   datetime pendingTime  = NULL;
   double   pendingPrice = NULL;

   int      type         = orderType;
   int      openEvent    = CreateEventId();
   datetime openTime     = oe.OpenTime (oe);
   double   openPrice    = oe.OpenPrice(oe);
   int      closeEvent   = NULL;
   datetime closeTime    = NULL;
   double   closePrice   = NULL;
   double   stopLoss     = oe.StopLoss(oe);
   //bool   clientsideSL = ...                     // unverändert
   bool     closedBySL   = false;

   double   swap         = oe.Swap      (oe);      // falls Swap bereits bei OrderOpen gesetzt sein sollte
   double   commission   = oe.Commission(oe);
   double   profit       = NULL;

   if (!Grid.PushData(ticket, level, grid.base, pendingType, pendingTime, pendingPrice, type, openEvent, openTime, openPrice, closeEvent, closeTime, closePrice, stopLoss, clientsideSL, closedBySL, swap, commission, profit))
      return(false);

   ArrayResize(oe, 0);
   return(!last_error|catch("Grid.AddPosition(7)"));
}


/**
 * Trail pending open price and stoploss of the specified pending order. If modification of an existing order is not allowed
 * (due to market or broker constraints) it may be replaced by a new stop or limit order.
 *
 * @param  int i - order index
 *
 * @return int - order type of the resulting pending order or NULL in case of errors
 */
int Grid.TrailPendingOrder(int i) {
   if (IsLastError())                         return(NULL);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("Grid.TrailPendingOrder(1)  cannot trail order of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (orders.type[i] != OP_UNDEFINED)        return(!catch("Grid.TrailPendingOrder(2)  cannot trail "+ OperationTypeDescription(orders.type[i]) +" position #"+ orders.ticket[i], ERR_ILLEGAL_STATE));
   if (orders.closeTime[i] != 0)              return(!catch("Grid.TrailPendingOrder(3)  cannot trail cancelled "+ OperationTypeDescription(orders.type[i]) +" order #"+ orders.ticket[i], ERR_ILLEGAL_STATE));

   if (Tick==1) /*&&*/ if (!ConfirmFirstTickTrade("Grid.TrailPendingOrder()", "Do you really want to modify the "+ OperationTypeDescription(orders.pendingType[i]) +" order #"+ orders.ticket[i] +" now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));

   // calculate changing data
   int      ticket       = orders.ticket[i], oe[];
   int      level        = orders.level[i];
   datetime pendingTime;
   double   pendingPrice = NormalizeDouble(grid.base +          level * GridSize * Pips, Digits);
   double   stopLoss     = NormalizeDouble(pendingPrice - Sign(level) * GridSize * Pips, Digits);

   if (!SelectTicket(ticket, "Grid.TrailPendingOrder(4)", true)) return(NULL);
   datetime prevPendingTime  = OrderOpenTime();
   double   prevPendingPrice = OrderOpenPrice();
   double   prevStoploss     = OrderStopLoss();
   OrderPop("Grid.TrailPendingOrder(5)");

   if (ticket < 0) {                                        // client-side managed limit
      // TODO: update chart markers
   }
   else {                                                   // server-side managed limit
      int error = ModifyStopOrder(ticket, pendingPrice, stopLoss, oe);
      pendingTime = oe.OpenTime(oe);

      if (IsError(error)) {
         if (oe.Error(oe) != ERR_INVALID_STOP) return(!SetLastError(oe.Error(oe)));
         if (error == -1) {                                 // market violated: delete stop order and open a limit order instead
            error = Grid.DeleteOrder(i);
            if (!error) return(Grid.AddPendingOrder(level));
            if (error == -1) {                              // the order was already executed
               pendingTime  = prevPendingTime;              // restore the original values
               pendingPrice = prevPendingPrice;
               stopLoss     = prevStoploss;                 // TODO: modify StopLoss of the now open position
               if (__LOG()) log("Grid.TrailPendingOrder(6)  sequence "+ sequence.name +"."+ NumberToStr(level, "+.") +" pending #"+ orders.ticket[i] +" was already executed");
            }
            else return(NULL);
         }
         if (error == -2) {                                 // stop distance violated: use client-side stop management
            return(!catch("Grid.TrailPendingOrder(7)  stop distance violated (TODO: implement client-side stop management)", oe.Error(oe)));
         }
         return(!catch("Grid.TrailPendingOrder(8)  unknown ModifyStopOrder() return value "+ error, oe.Error(oe)));
      }
   }

   // update changed data (ignore current ticket state which may be different)
   orders.gridBase    [i] = grid.base;
   orders.pendingTime [i] = pendingTime;
   orders.pendingPrice[i] = pendingPrice;
   orders.stopLoss    [i] = stopLoss;

   if (!catch("Grid.TrailPendingOrder(9)"))
      return(orders.pendingType[i]);
   return(NULL);
}


/**
 * Cancel the specified order and remove it from the order arrays.
 *
 * @param  int i - order index
 *
 * @return int - NULL on success or another value in case of errors, especially
 *               -1 if the order was already executed and is not pending anymore
 */
int Grid.DeleteOrder(int i) {
   if (IsLastError())                                                           return(last_error);
   if (sequence.status!=STATUS_PROGRESSING && sequence.status!=STATUS_STOPPING) return(catch("Grid.DeleteOrder(1)  cannot delete order of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (orders.type[i] != OP_UNDEFINED)                                          return(catch("Grid.DeleteOrder(2)  cannot delete "+ ifString(orders.closeTime[i], "closed", "open") +" "+ OperationTypeDescription(orders.type[i]) +" order", ERR_ILLEGAL_STATE));

   if (Tick==1) /*&&*/ if (!ConfirmFirstTickTrade("Grid.DeleteOrder()", "Do you really want to cancel the "+ OperationTypeDescription(orders.pendingType[i]) +" order at level "+ orders.level[i] +" now?"))
      return(SetLastError(ERR_CANCELLED_BY_USER));

   if (orders.ticket[i] > 0) {
      int oe[], oeFlags = F_ERR_INVALID_TRADE_PARAMETERS;            // accept the order already being executed
      if (!OrderDeleteEx(orders.ticket[i], CLR_NONE, oeFlags, oe)) {
         int error = oe.Error(oe);
         if (error == ERR_INVALID_TRADE_PARAMETERS)
            return(-1);
         return(SetLastError(error));
      }
   }
   if (!Grid.DropData(i)) return(last_error);

   ArrayResize(oe, 0);
   return(catch("Grid.DeleteOrder(3)"));
}


/**
 * Cancel the exit limit of the specified order.
 *
 * @param  int i - order index
 *
 * @return int - NULL on success or another value in case of errors, especially
 *               -1 if the limit was already executed
 */
int Grid.DeleteLimit(int i) {
   if (IsLastError())                                                                   return(last_error);
   if (sequence.status != STATUS_STOPPING)                                              return(catch("Grid.DeleteLimit(1)  cannot delete limit of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (orders.type[i]==OP_UNDEFINED || orders.type[i] > OP_SELL || orders.closeTime[i]) return(catch("Grid.DeleteLimit(2)  cannot delete limit of "+ ifString(orders.closeTime[i], "closed", "open") +" "+ OperationTypeDescription(orders.type[i]) +" order", ERR_ILLEGAL_STATE));

   if (Tick==1) /*&&*/ if (!ConfirmFirstTickTrade("Grid.DeleteLimit()", "Do you really want to delete the limit of the position at level "+ orders.level[i] +" now?"))
      return(SetLastError(ERR_CANCELLED_BY_USER));

   int oe[], oeFlags = F_ERR_INVALID_TRADE_PARAMETERS;         // accept the limit already being executed
   if (!OrderModifyEx(orders.ticket[i], orders.openPrice[i], NULL, NULL, NULL, CLR_NONE, oeFlags, oe)) {
      int error = oe.Error(oe);
      if (error == ERR_INVALID_TRADE_PARAMETERS)
         return(-1);
      return(SetLastError(error));
   }
   ArrayResize(oe, 0);
   return(catch("Grid.DeleteLimit(3)"));
}


/**
 * Fügt den Datenarrays der Sequenz die angegebenen Daten hinzu.
 *
 * @param  int      ticket
 * @param  int      level
 * @param  double   gridBase
 *
 * @param  int      pendingType
 * @param  datetime pendingTime
 * @param  double   pendingPrice
 *
 * @param  int      type
 * @param  int      openEvent
 * @param  datetime openTime
 * @param  double   openPrice
 * @param  int      closeEvent
 * @param  datetime closeTime
 * @param  double   closePrice
 * @param  double   stopLoss
 * @param  bool     clientLimit
 * @param  bool     closedBySL
 *
 * @param  double   swap
 * @param  double   commission
 * @param  double   profit
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.PushData(int ticket, int level, double gridBase, int pendingType, datetime pendingTime, double pendingPrice, int type, int openEvent, datetime openTime, double openPrice, int closeEvent, datetime closeTime, double closePrice, double stopLoss, bool clientLimit, bool closedBySL, double swap, double commission, double profit) {
   clientLimit = clientLimit!=0;
   closedBySL  = closedBySL!=0;
   return(Grid.SetData(-1, ticket, level, gridBase, pendingType, pendingTime, pendingPrice, type, openEvent, openTime, openPrice, closeEvent, closeTime, closePrice, stopLoss, clientLimit, closedBySL, swap, commission, profit));
}


/**
 * Schreibt die angegebenen Daten an die angegebene Position der Gridarrays.
 *
 * @param  int      offset - Arrayposition: Ist dieser Wert -1 oder sind die Gridarrays zu klein, werden sie vergrößert.
 *
 * @param  int      ticket
 * @param  int      level
 * @param  double   gridBase
 *
 * @param  int      pendingType
 * @param  datetime pendingTime
 * @param  double   pendingPrice
 *
 * @param  int      type
 * @param  int      openEvent
 * @param  datetime openTime
 * @param  double   openPrice
 * @param  int      closeEvent
 * @param  datetime closeTime
 * @param  double   closePrice
 * @param  double   stopLoss
 * @param  bool     clientLimit
 * @param  bool     closedBySL
 *
 * @param  double   swap
 * @param  double   commission
 * @param  double   profit
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.SetData(int offset, int ticket, int level, double gridBase, int pendingType, datetime pendingTime, double pendingPrice, int type, int openEvent, datetime openTime, double openPrice, int closeEvent, datetime closeTime, double closePrice, double stopLoss, bool clientLimit, bool closedBySL, double swap, double commission, double profit) {
   clientLimit = clientLimit!=0;
   closedBySL  = closedBySL!=0;

   if (offset < -1)
      return(_false(catch("Grid.SetData(1)  illegal parameter offset = "+ offset, ERR_INVALID_PARAMETER)));

   int i=offset, size=ArraySize(orders.ticket);

   if      (offset ==    -1) i = ResizeArrays(  size+1)-1;
   else if (offset > size-1) i = ResizeArrays(offset+1)-1;

   orders.ticket         [i] = ticket;
   orders.level          [i] = level;
   orders.gridBase       [i] = NormalizeDouble(gridBase, Digits);

   orders.pendingType    [i] = pendingType;
   orders.pendingTime    [i] = pendingTime;
   orders.pendingPrice   [i] = NormalizeDouble(pendingPrice, Digits);

   orders.type           [i] = type;
   orders.openEvent      [i] = openEvent;
   orders.openTime       [i] = openTime;
   orders.openPrice      [i] = NormalizeDouble(openPrice, Digits);
   orders.closeEvent     [i] = closeEvent;
   orders.closeTime      [i] = closeTime;
   orders.closePrice     [i] = NormalizeDouble(closePrice, Digits);
   orders.stopLoss       [i] = NormalizeDouble(stopLoss, Digits);
   orders.clientsideLimit[i] = clientLimit;
   orders.closedBySL     [i] = closedBySL;

   orders.swap           [i] = NormalizeDouble(swap,       2);
   orders.commission     [i] = NormalizeDouble(commission, 2); if (type != OP_UNDEFINED) { sequence.commission = orders.commission[i]; SS.LotSize(); }
   orders.profit         [i] = NormalizeDouble(profit,     2);

   return(!catch("Grid.SetData(2)"));
}


/**
 * Remove order data at the speciefied index from the order arrays.
 *
 * @param  int i - order index
 *
 * @return bool - success status
 */
bool Grid.DropData(int i) {
   if (i < 0 || i >= ArraySize(orders.ticket)) return(!catch("Grid.DropData(1)  illegal parameter i = "+ i, ERR_INVALID_PARAMETER));

   ArraySpliceInts   (orders.ticket,          i, 1);
   ArraySpliceInts   (orders.level,           i, 1);
   ArraySpliceDoubles(orders.gridBase,        i, 1);

   ArraySpliceInts   (orders.pendingType,     i, 1);
   ArraySpliceInts   (orders.pendingTime,     i, 1);
   ArraySpliceDoubles(orders.pendingPrice,    i, 1);

   ArraySpliceInts   (orders.type,            i, 1);
   ArraySpliceInts   (orders.openEvent,       i, 1);
   ArraySpliceInts   (orders.openTime,        i, 1);
   ArraySpliceDoubles(orders.openPrice,       i, 1);
   ArraySpliceInts   (orders.closeEvent,      i, 1);
   ArraySpliceInts   (orders.closeTime,       i, 1);
   ArraySpliceDoubles(orders.closePrice,      i, 1);
   ArraySpliceDoubles(orders.stopLoss,        i, 1);
   ArraySpliceBools  (orders.clientsideLimit, i, 1);
   ArraySpliceBools  (orders.closedBySL,      i, 1);

   ArraySpliceDoubles(orders.swap,            i, 1);
   ArraySpliceDoubles(orders.commission,      i, 1);
   ArraySpliceDoubles(orders.profit,          i, 1);

   return(!catch("Grid.DropData(2)"));
}


/**
 * Sucht eine als offene markierte Position des angegebenen Levels und gibt ihren Index zurück. Je Level kann es maximal nur
 * eine offene Position geben.
 *
 * @param  int level - Level der zu suchenden Position
 *
 * @return int - Index der gefundenen Position oder -1 (EMPTY), wenn keine offene Position des angegebenen Levels gefunden wurde
 */
int Grid.FindOpenPosition(int level) {
   if (!level) return(_EMPTY(catch("Grid.FindOpenPosition(1)  illegal parameter level = "+ level, ERR_INVALID_PARAMETER)));

   int size = ArraySize(orders.ticket);
   for (int i=size-1; i >= 0; i--) {                                 // rückwärts iterieren, um Zeit zu sparen
      if (orders.level[i] != level)       continue;                  // Orderlevel muß übereinstimmen
      if (orders.type[i] == OP_UNDEFINED) continue;                  // Order darf nicht pending sein (also Position)
      if (orders.closeTime[i] != 0)       continue;                  // Position darf nicht geschlossen sein
      return(i);
   }
   return(EMPTY);
}


/**
 * Öffnet eine Position zum aktuellen Preis.
 *
 * @param  _In_  int  type         - Ordertyp: OP_BUY | OP_SELL
 * @param  _In_  int  level        - Gridlevel der Order
 * @param  _In_  bool clientsideSL - ob der StopLoss client-seitig verwaltet wird
 * @param  _Out_ int  oe[]         - execution details (struct ORDER_EXECUTION)
 *
 * @return int - Orderticket (positiver Wert) oder ein anderer Wert, falls ein Fehler auftrat
 *
 * Spezielle Return-Codes:
 * -----------------------
 * -1: der StopLoss verletzt den aktuellen Spread
 * -2: der StopLoss verletzt die StopDistance des Brokers
 */
int SubmitMarketOrder(int type, int level, bool clientsideSL, int oe[]) {
   clientsideSL = clientsideSL!=0;
   if (IsLastError())                                                           return(0);
   if (sequence.status!=STATUS_STARTING && sequence.status!=STATUS_PROGRESSING) return(_NULL(catch("SubmitMarketOrder(1)  cannot submit market order for "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE)));
   if (type!=OP_BUY  && type!=OP_SELL)                                          return(_NULL(catch("SubmitMarketOrder(2)  illegal parameter type = "+ type, ERR_INVALID_PARAMETER)));
   if (type==OP_BUY  && level<=0)                                               return(_NULL(catch("SubmitMarketOrder(3)  illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_PARAMETER)));
   if (type==OP_SELL && level>=0)                                               return(_NULL(catch("SubmitMarketOrder(4)  illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_PARAMETER)));

   double   price       = NULL;
   double   slippage    = 0.1;
   double   stopLoss    = ifDouble(clientsideSL, NULL, grid.base + (level-Sign(level))*GridSize*Pips);
   double   takeProfit  = NULL;
   int      magicNumber = CreateMagicNumber(level);
   datetime expires     = NULL;
   string   comment     = "SR."+ sequence.id +"."+ NumberToStr(level, "+.");
   color    markerColor = ifInt(level > 0, CLR_LONG, CLR_SHORT); if (!orderDisplayMode) markerColor = CLR_NONE;
   int      oeFlags     = NULL;

   if (!clientsideSL) /*&&*/ if (Abs(level) >= Abs(sequence.level))
      oeFlags |= F_ERR_INVALID_STOP;            // ab dem letzten Level bei server-seitigem StopLoss ERR_INVALID_STOP abfangen

   int ticket = OrderSendEx(Symbol(), type, LotSize, price, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (ticket > 0) return(ticket);

   int error = oe.Error(oe);
   if (oeFlags & F_ERR_INVALID_STOP && 1) {
      if (error == ERR_INVALID_STOP) {          // Der StopLoss liegt entweder innerhalb des Spreads (-1) oder innerhalb der StopDistance (-2).
         bool insideSpread;
         if (type == OP_BUY) insideSpread = GE(oe.StopLoss(oe), oe.Bid(oe));
         else                insideSpread = LE(oe.StopLoss(oe), oe.Ask(oe));
         if (insideSpread)
            return(-1);
         return(-2);
      }
   }
   return(_NULL(SetLastError(error)));
}


/**
 * Open a pending stop order.
 *
 * @param  _In_  int type  - order type: OP_BUYSTOP | OP_SELLSTOP
 * @param  _In_  int level - order grid level
 * @param  _Out_ int oe[]  - execution details (struct ORDER_EXECUTION)
 *
 * @return int - order ticket (positive value) on success or another value in case of errors, especially
 *               -1 if the limit violates the current market or
 *               -2 if the limit violates the broker's stop distance
 */
int SubmitStopOrder(int type, int level, int oe[]) {
   if (IsLastError())                                                           return(0);
   if (sequence.status!=STATUS_STARTING && sequence.status!=STATUS_PROGRESSING) return(_NULL(catch("SubmitStopOrder(1)  cannot submit stop order of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE)));
   if (type!=OP_BUYSTOP  && type!=OP_SELLSTOP)                                  return(_NULL(catch("SubmitStopOrder(2)  illegal parameter type = "+ type, ERR_INVALID_PARAMETER)));
   if (type==OP_BUYSTOP  && level <= 0)                                         return(_NULL(catch("SubmitStopOrder(3)  illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_PARAMETER)));
   if (type==OP_SELLSTOP && level >= 0)                                         return(_NULL(catch("SubmitStopOrder(4)  illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_PARAMETER)));

   double   stopPrice   = grid.base + level*GridSize*Pips;
   double   slippage    = NULL;
   double   stopLoss    = stopPrice - Sign(level)*GridSize*Pips;
   double   takeProfit  = NULL;
   int      magicNumber = CreateMagicNumber(level);
   datetime expires     = NULL;
   string   comment     = "SR."+ sequence.id +"."+ NumberToStr(level, "+.");
   color    markerColor = CLR_PENDING; if (!orderDisplayMode) markerColor = CLR_NONE;
   int      oeFlags     = F_ERR_INVALID_STOP;      // accept ERR_INVALID_STOP

   int ticket = OrderSendEx(Symbol(), type, LotSize, stopPrice, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (ticket > 0) return(ticket);

   int error = oe.Error(oe);
   if (error == ERR_INVALID_STOP) {                // either the entry limit violates the market (-1) or the broker's stop distance (-2)
      bool violatedMarket;
      if (!oe.StopDistance(oe))    violatedMarket = true;
      else if (type == OP_BUYSTOP) violatedMarket = LE(oe.OpenPrice(oe), oe.Ask(oe));
      else                         violatedMarket = GE(oe.OpenPrice(oe), oe.Bid(oe));
      return(ifInt(violatedMarket, -1, -2));
   }
   return(_NULL(SetLastError(error)));
}


/**
 * Open a pending limit order.
 *
 * @param  _In_  int type  - order type: OP_BUYLIMIT | OP_SELLLIMIT
 * @param  _In_  int level - order grid level
 * @param  _Out_ int oe[]  - execution details (struct ORDER_EXECUTION)
 *
 * @return int - order ticket (positive value) on success or another value in case of errors, especially
 *               -1 if the limit violates the current market or
 *               -2 the limit violates the broker's stop distance
 */
int SubmitLimitOrder(int type, int level, int oe[]) {
   if (IsLastError())                                                           return(0);
   if (sequence.status!=STATUS_STARTING && sequence.status!=STATUS_PROGRESSING) return(_NULL(catch("SubmitLimitOrder(1)  cannot submit limit order for "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE)));
   if (type!=OP_BUYLIMIT  && type!=OP_SELLLIMIT)                                return(_NULL(catch("SubmitLimitOrder(2)  illegal parameter type = "+ type, ERR_INVALID_PARAMETER)));
   if (type==OP_BUYLIMIT  && level <= 0)                                        return(_NULL(catch("SubmitLimitOrder(3)  illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_PARAMETER)));
   if (type==OP_SELLLIMIT && level >= 0)                                        return(_NULL(catch("SubmitLimitOrder(4)  illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_PARAMETER)));

   double   limitPrice  = grid.base + level*GridSize*Pips;
   double   slippage    = NULL;
   double   stopLoss    = limitPrice - Sign(level)*GridSize*Pips;
   double   takeProfit  = NULL;
   int      magicNumber = CreateMagicNumber(level);
   datetime expires     = NULL;
   string   comment     = "SR."+ sequence.id +"."+ NumberToStr(level, "+.");
   color    markerColor = CLR_PENDING; if (!orderDisplayMode) markerColor = CLR_NONE;
   int      oeFlags     = F_ERR_INVALID_STOP;      // accept ERR_INVALID_STOP

   int ticket = OrderSendEx(Symbol(), type, LotSize, limitPrice, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (ticket > 0) return(ticket);

   int error = oe.Error(oe);
   if (error == ERR_INVALID_STOP) {                // either the entry limit violates the market (-1) or the broker's stop distance (-2)
      bool violatedMarket;
      if (!oe.StopDistance(oe))     violatedMarket = true;
      else if (type == OP_BUYLIMIT) violatedMarket = GE(oe.OpenPrice(oe), oe.Ask(oe));
      else                          violatedMarket = LE(oe.OpenPrice(oe), oe.Bid(oe));
      return(ifInt(violatedMarket, -1, -2));
   }
   return(_NULL(SetLastError(error)));
}


/**
 * Modify entry price and stoploss of a pending stop order (i.e. trail a first level order).
 *
 * @param  _Out_ int oe[] - order execution details (struct ORDER_EXECUTION)
 *
 * @return int - error status: NULL on success or another value in case of errors, especially
 *               -1 if the new entry price violates the current market or
 *               -2 if the new entry price violates the broker's stop distance
 */
int ModifyStopOrder(int ticket, double stopPrice, double stopLoss, int oe[]) {
   if (IsLastError())                         return(last_error);
   if (sequence.status != STATUS_PROGRESSING) return(catch("ModifyStopOrder(1)  cannot modify order of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   int oeFlags = F_ERR_INVALID_STOP;            // accept ERR_INVALID_STOP
   bool success = OrderModifyEx(ticket, stopPrice, stopLoss, NULL, NULL, CLR_PENDING, oeFlags, oe);
   if (success) return(NO_ERROR);

   int error = oe.Error(oe);
   if (error == ERR_INVALID_STOP) {             // either the entry price violates the market (-1) or it violates the broker's stop distance (-2)
      bool violatedMarket;
      if (!oe.StopDistance(oe))           violatedMarket = true;
      else if (oe.Type(oe) == OP_BUYSTOP) violatedMarket = GE(oe.Ask(oe), stopPrice);
      else                                violatedMarket = LE(oe.Bid(oe), stopPrice);
      return(ifInt(violatedMarket, -1, -2));
   }
   return(SetLastError(error));
}


/**
 * Generiert für den angegebenen Gridlevel eine MagicNumber.
 *
 * @param  int level - Gridlevel
 *
 * @return int - MagicNumber oder -1 (EMPTY), falls ein Fehler auftrat
 */
int CreateMagicNumber(int level) {
   if (sequence.id < SID_MIN) return(_EMPTY(catch("CreateMagicNumber(1)  illegal sequence.id = "+ sequence.id, ERR_RUNTIME_ERROR)));
   if (!level)                return(_EMPTY(catch("CreateMagicNumber(2)  illegal parameter level = "+ level, ERR_INVALID_PARAMETER)));

   // Für bessere Obfuscation ist die Reihenfolge der Werte [ea,level,sequence] und nicht [ea,sequence,level], was aufeinander folgende Werte wären.
   int ea       = STRATEGY_ID & 0x3FF << 22;                         // 10 bit (Bits größer 10 löschen und auf 32 Bit erweitern)  | Position in MagicNumber: Bits 23-32
       level    = Abs(level);                                        // der Level in MagicNumber ist immer positiv                |
       level    = level & 0xFF << 14;                                //  8 bit (Bits größer 8 löschen und auf 22 Bit erweitern)   | Position in MagicNumber: Bits 15-22
   int sequence = sequence.id & 0x3FFF;                              // 14 bit (Bits größer 14 löschen                            | Position in MagicNumber: Bits  1-14

   return(ea + level + sequence);
}


/**
 * Display the current runtime status.
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error or the current error status if no error was passed
 */
int ShowStatus(int error = NO_ERROR) {
   if (!__CHART()) return(error);

   string msg, sAtLevel, sError;

   if      (__STATUS_INVALID_INPUT) sError = StringConcatenate("  [",                 ErrorDescription(ERR_INVALID_INPUT_PARAMETER), "]");
   else if (__STATUS_OFF          ) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason        ), "]");

   switch (sequence.status) {
      case STATUS_UNDEFINED:   msg = " not initialized"; break;
      case STATUS_WAITING:           if (sequence.maxLevel != 0) sAtLevel = StringConcatenate(" at level ", sequence.level, "  (max: ", sequence.maxLevel, sSequenceMissedLevels, ")");
                               msg = StringConcatenate("  ", Sequence.ID, " waiting", sAtLevel); break;
      case STATUS_STARTING:    msg = StringConcatenate("  ", Sequence.ID, " starting at level ",    sequence.level, "  (max: ", sequence.maxLevel, sSequenceMissedLevels, ")"); break;
      case STATUS_PROGRESSING: msg = StringConcatenate("  ", Sequence.ID, " progressing at level ", sequence.level, "  (max: ", sequence.maxLevel, sSequenceMissedLevels, ")"); break;
      case STATUS_STOPPING:    msg = StringConcatenate("  ", Sequence.ID, " stopping at level ",    sequence.level, "  (max: ", sequence.maxLevel, sSequenceMissedLevels, ")"); break;
      case STATUS_STOPPED:     msg = StringConcatenate("  ", Sequence.ID, " stopped at level ",     sequence.level, "  (max: ", sequence.maxLevel, sSequenceMissedLevels, ")"); break;
      default:
         return(catch("ShowStatus(1)  illegal sequence status = "+ sequence.status, ERR_RUNTIME_ERROR));
   }

   msg = StringConcatenate(__NAME(), msg, sError,                                                  NL,
                                                                                                   NL,
                           "Grid:              ", GridSize, " pip", sGridbase, sSequenceDirection, NL,
                           "LotSize:          ",  sLotSize, sSequenceProfitPerLevel,               NL,
                           "Start:             ", sStartConditions,                                NL,
                           "Stop:              ", sStopConditions,                                 NL,
                           sAutoResume,                                     // if set it ends with NL,
                           "Stops:             ", sSequenceStops, sSequenceStopsPL,                NL,
                           "Profit/Loss:    ",   sSequenceTotalPL, sSequencePlStats,               NL,
                           "Breakeven: ",                                                          NL);

   // 3 lines margin-top for instrument and indicator legend
   Comment(StringConcatenate(NL, NL, NL, msg));
   if (__WHEREAMI__ == CF_INIT)
      WindowRedraw();

   // für Fernbedienung: versteckten Status im Chart speichern
   string label = "SnowRoller.status";
   if (ObjectFind(label) != 0) {
      if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))
         return(catch("ShowStatus(2)"));
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   }
   if (sequence.status == STATUS_UNDEFINED) ObjectDelete(label);
   else                                     ObjectSetText(label, StringConcatenate(Sequence.ID, "|", sequence.status), 1);

   if (!catch("ShowStatus(3)"))
      return(error);
   return(last_error);
}


/**
 * ShowStatus(): Aktualisiert alle in ShowStatus() verwendeten String-Repräsentationen.
 */
void SS.All() {
   if (!__CHART()) return;

   SS.SequenceId();
   SS.GridBase();
   SS.GridDirection();
   SS.MissedLevels();
   SS.LotSize();
   SS.StartStopConditions();
   SS.AutoResume();
   SS.Stops();
   SS.TotalPL();
   SS.MaxProfit();
   SS.MaxDrawdown();
   SS.ProfitPerLevel();
}


/**
 * ShowStatus(): Aktualisiert die Anzeige der Sequenz-ID in der Titelzeile des Testers.
 */
void SS.SequenceId() {
   if (IsTesting()) {
      if (!SetWindowTextA(FindTesterWindow(), "Tester - SR."+ sequence.id))
         catch("SS.SequenceId(1)->user32::SetWindowTextA()", ERR_WIN32_ERROR);
   }
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von grid.base.
 */
void SS.GridBase() {
   if (!__CHART()) return;
   if (ArraySize(grid.base.event) > 0) {
      sGridbase = " @ "+ NumberToStr(grid.base, PriceFormat);
   }
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von sequence.direction.
 */
void SS.GridDirection() {
   if (!__CHART()) return;
   sSequenceDirection = "  ("+ StrToLower(TradeDirectionDescription(sequence.direction)) +")";
}


/**
 * ShowStatus(): Update the string presentation of sequence.missedLevels.
 */
void SS.MissedLevels() {
   if (!__CHART()) return;

   int size = ArraySize(sequence.missedLevels);
   if (!size) sSequenceMissedLevels = "";
   else       sSequenceMissedLevels = ", missed: "+ JoinInts(sequence.missedLevels);
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von LotSize.
 */
void SS.LotSize() {
   if (!__CHART()) return;
   double stopSize = GridSize * PipValue(LotSize) - sequence.commission;

   if (ShowProfitInPercent) sLotSize = NumberToStr(LotSize, ".+") +" lot = "+ DoubleToStr(MathDiv(stopSize, sequence.startEquity) * 100, 2) +"%/stop";
   else                     sLotSize = NumberToStr(LotSize, ".+") +" lot = "+ DoubleToStr(stopSize, 2) +"/stop";
}


/**
 * ShowStatus(): Update the string representation of input parameters "StartConditions" and "StopConditions".
 */
void SS.StartStopConditions() {
   if (!__CHART()) return;

   string sValue = "";
   if (start.price.description!="" || start.time.description!="") {
      if (start.price.description != "") {
         sValue = ifString(start.price.condition, "@", "!") + start.price.description;
      }
      if (start.time.description != "") {
         sValue = sValue + ifString(sValue=="", "", " && ") + ifString(start.time.condition, "@", "!") + start.time.description;
      }
   }
   if (start.trend.description != "") {
      if (start.price.description!="" && start.time.description!="") {
         sValue = "("+ sValue +")";
      }
      if (start.price.description!="" || start.time.description!="") {
         sValue = sValue +" || ";
      }
      sValue = sValue + ifString(start.trend.condition, "@", "!") + start.trend.description;
   }
   if (sValue == "") sStartConditions = "-";
   else              sStartConditions = sValue;
   StartConditions = sValue;

   sValue = "";
   if (stop.price.description != "") {
      sValue = sValue + ifString(sValue=="", "", " || ") + ifString(stop.price.condition, "@", "!") + stop.price.description;
   }
   if (stop.time.description != "") {
      sValue = sValue + ifString(sValue=="", "", " || ") + ifString(stop.time.condition, "@", "!") + stop.time.description;
   }
   if (stop.profitAbs.description != "") {
      sValue = sValue + ifString(sValue=="", "", " || ") + ifString(stop.profitAbs.condition, "@", "!") + stop.profitAbs.description;
   }
   if (stop.profitPct.description != "") {
      sValue = sValue + ifString(sValue=="", "", " || ") + ifString(stop.profitPct.condition, "@", "!") + stop.profitPct.description;
   }
   if (stop.trend.description != "") {
      sValue = sValue + ifString(sValue=="", "", " || ") + ifString(stop.trend.condition, "@", "!") + stop.trend.description;
   }
   if (sValue == "") sStopConditions = "-";
   else              sStopConditions = sValue;
   StopConditions = sValue;
}


/**
 * ShowStatus(): Update the string representation of input parameter "AutoResume".
 */
void SS.AutoResume() {
   if (!__CHART()) return;
   if (AutoResume) sAutoResume = "AutoResume: On" + NL;
   else            sAutoResume = "AutoResume: Off"+ NL;
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentationen von sequence.stops und sequence.stopsPL.
 */
void SS.Stops() {
   if (!__CHART()) return;
   sSequenceStops = sequence.stops +" stop"+ ifString(sequence.stops==1, "", "s");

   // Anzeige wird nicht vor der ersten ausgestoppten Position gesetzt
   if (sequence.stops > 0) {
      if (ShowProfitInPercent) sSequenceStopsPL = " = "+ DoubleToStr(MathDiv(sequence.stopsPL, sequence.startEquity) * 100, 2) +"%";
      else                     sSequenceStopsPL = " = "+ DoubleToStr(sequence.stopsPL, 2);
   }
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von sequence.totalPL.
 */
void SS.TotalPL() {
   if (!__CHART()) return;
   if (sequence.maxLevel == 0)   sSequenceTotalPL = "-";           // Anzeige wird nicht vor der ersten offenen Position gesetzt
   else if (ShowProfitInPercent) sSequenceTotalPL = NumberToStr(MathDiv(sequence.totalPL, sequence.startEquity) * 100, "+.2") +"%";
   else                          sSequenceTotalPL = NumberToStr(sequence.totalPL, "+.2");
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von sequence.maxProfit.
 */
void SS.MaxProfit() {
   if (!__CHART()) return;
   if (ShowProfitInPercent) sSequenceMaxProfit = NumberToStr(MathDiv(sequence.maxProfit, sequence.startEquity) * 100, "+.2") +"%";
   else                     sSequenceMaxProfit = NumberToStr(sequence.maxProfit, "+.2");
   SS.PLStats();
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von sequence.maxDrawdown.
 */
void SS.MaxDrawdown() {
   if (!__CHART()) return;
   if (ShowProfitInPercent) sSequenceMaxDrawdown = NumberToStr(MathDiv(sequence.maxDrawdown, sequence.startEquity) * 100, "+.2") +"%";
   else                     sSequenceMaxDrawdown = NumberToStr(sequence.maxDrawdown, "+.2");
   SS.PLStats();
}


/**
 * ShowStatus(): Update the string representation of sequence.profitPerLevel.
 */
void SS.ProfitPerLevel() {
   if (!__CHART()) return;

   if (!sequence.level) {
      sSequenceProfitPerLevel = "";                // no display if no position is open
   }
   else {
      double stopSize = GridSize * PipValue(LotSize);
      int    levels   = Abs(sequence.level) - ArraySize(sequence.missedLevels);
      double profit   = levels * stopSize;

      if (ShowProfitInPercent) sSequenceProfitPerLevel = " = "+ DoubleToStr(MathDiv(profit, sequence.startEquity) * 100, 1) +"%/level";
      else                     sSequenceProfitPerLevel = " = "+ DoubleToStr(profit, 2) +"/level";
   }
}


/**
 * ShowStatus(): Aktualisiert die kombinierte String-Repräsentation der P/L-Statistik.
 */
void SS.PLStats() {
   if (!__CHART()) return;
   if (sequence.maxLevel != 0) {    // no display until a position was opened
      sSequencePlStats = "  ("+ sSequenceMaxProfit +"/"+ sSequenceMaxDrawdown +")";
   }
}


/**
 * Store sequence id and transient status in the chart before recompilation or terminal restart.
 *
 * @return int - error status
 */
int StoreChartStatus() {
   string name = __NAME();
   Chart.StoreString(name +".runtime.Sequence.ID",            Sequence.ID                      );
   Chart.StoreInt   (name +".runtime.startStopDisplayMode",   startStopDisplayMode             );
   Chart.StoreInt   (name +".runtime.orderDisplayMode",       orderDisplayMode                 );
   Chart.StoreBool  (name +".runtime.__STATUS_INVALID_INPUT", __STATUS_INVALID_INPUT           );
   Chart.StoreBool  (name +".runtime.CANCELLED_BY_USER",      last_error==ERR_CANCELLED_BY_USER);
   return(catch("StoreChartStatus(1)"));
}


/**
 * Restore sequence id and transient status found in the chart after recompilation or terminal restart.
 *
 * @return bool - whether a sequence id was found and restored
 */
bool RestoreChartStatus() {
   string name = __NAME();
   string key  = name +".runtime.Sequence.ID", sValue = "";

   if (ObjectFind(key) == 0) {
      Chart.RestoreString(key, sValue);

      if (StrStartsWith(sValue, "T")) {
         sequence.isTest = true;
         sValue = StrRight(sValue, -1);
      }
      int iValue = StrToInteger(sValue);
      if (!iValue) {
         sequence.status = STATUS_UNDEFINED;
      }
      else {
         sequence.id     = iValue; SS.SequenceId();
         Sequence.ID     = ifString(IsTestSequence(), "T", "") + sequence.id;
         sequence.name   = StrLeft(TradeDirectionDescription(sequence.direction), 1) +"."+ sequence.id;
         sequence.status = STATUS_WAITING;
         SetCustomLog(sequence.id, NULL);
      }
      bool bValue;
      Chart.RestoreInt (name +".runtime.startStopDisplayMode",   startStopDisplayMode  );
      Chart.RestoreInt (name +".runtime.orderDisplayMode",       orderDisplayMode      );
      Chart.RestoreBool(name +".runtime.__STATUS_INVALID_INPUT", __STATUS_INVALID_INPUT);
      Chart.RestoreBool(name +".runtime.CANCELLED_BY_USER",      bValue                ); if (bValue) SetLastError(ERR_CANCELLED_BY_USER);
      catch("RestoreChartStatus(1)");
      return(iValue != 0);
   }
   return(false);
}


/**
 * Löscht alle im Chart gespeicherten Sequenzdaten.
 *
 * @return int - Fehlerstatus
 */
int DeleteChartStatus() {
   string label, prefix=__NAME() +".runtime.";

   for (int i=ObjectsTotal()-1; i>=0; i--) {
      label = ObjectName(i);
      if (StrStartsWith(label, prefix)) /*&&*/ if (ObjectFind(label) == 0)
         ObjectDelete(label);
   }
   return(catch("DeleteChartStatus(1)"));
}


/**
 * Ermittelt die aktuell laufenden Sequenzen.
 *
 * @param  int ids[] - Array zur Aufnahme der gefundenen Sequenz-IDs
 *
 * @return bool - ob mindestens eine laufende Sequenz gefunden wurde
 */
bool GetRunningSequences(int ids[]) {
   ArrayResize(ids, 0);
   int id;

   for (int i=OrdersTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wurde in einem anderen Thread eine offene Order entfernt
         continue;

      if (IsMyOrder()) {
         id = OrderMagicNumber() & 0x3FFF;                           // 14 Bits (Bits 1-14) => sequence.id
         if (!IntInArray(ids, id))
            ArrayPushInt(ids, id);
      }
   }

   if (ArraySize(ids) != 0)
      return(ArraySort(ids));
   return(false);
}


/**
 * Ob die aktuell selektierte Order zu dieser Strategie gehört. Wird eine Sequenz-ID angegeben, wird zusätzlich überprüft,
 * ob die Order zur angegebenen Sequenz gehört.
 *
 * @param  int sequenceId - ID einer Sequenz (default: NULL)
 *
 * @return bool
 */
bool IsMyOrder(int sequenceId = NULL) {
   if (OrderSymbol() == Symbol()) {
      if (OrderMagicNumber() >> 22 == STRATEGY_ID) {
         if (sequenceId == NULL)
            return(true);
         return(sequenceId == OrderMagicNumber() & 0x3FFF);          // 14 Bits (Bits 1-14) => sequence.id
      }
   }
   return(false);
}


string   last.Sequence.ID;
string   last.GridDirection;
int      last.GridSize;
double   last.LotSize;
int      last.StartLevel;
string   last.StartConditions;
string   last.StopConditions;
bool     last.AutoResume;
datetime last.Sessionbreak.StartTime;
datetime last.Sessionbreak.EndTime;
bool     last.ShowProfitInPercent;


/**
 * Input parameters changed by the code don't survive init cycles. Therefore inputs are backed-up in deinit() by using this
 * function and can be restored in init(). Called only from onDeinitChartChange() and onDeinitParameterChange().
 */
void BackupInputs() {
   // backed-up inputs are also accessed from ValidateInputs()
   last.Sequence.ID            = StringConcatenate(Sequence.ID,   "");     // String inputs are references to internal C literals
   last.GridDirection          = StringConcatenate(GridDirection, "");     // and must be copied to break the reference.
   last.GridSize               = GridSize;
   last.LotSize                = LotSize;
   last.StartLevel             = StartLevel;
   last.StartConditions        = StringConcatenate(StartConditions, "");
   last.StopConditions         = StringConcatenate(StopConditions,  "");
   last.AutoResume             = AutoResume;
   last.Sessionbreak.StartTime = Sessionbreak.StartTime;
   last.Sessionbreak.EndTime   = Sessionbreak.EndTime;
   last.ShowProfitInPercent    = ShowProfitInPercent;
}


/**
 * Restore backed-up input parameters. Called only from onInitTimeframeChange() and onInitParameters().
 */
void RestoreInputs() {
   Sequence.ID            = last.Sequence.ID;
   GridDirection          = last.GridDirection;
   GridSize               = last.GridSize;
   LotSize                = last.LotSize;
   StartLevel             = last.StartLevel;
   StartConditions        = last.StartConditions;
   StopConditions         = last.StopConditions;
   AutoResume             = last.AutoResume;
   Sessionbreak.StartTime = last.Sessionbreak.StartTime;
   Sessionbreak.EndTime   = last.Sessionbreak.EndTime;
   ShowProfitInPercent    = last.ShowProfitInPercent;
}


/**
 * Validiert und setzt nur die in der Konfiguration angegebene Sequenz-ID. Called only from onInitUser().
 *
 * @param  bool interactive - whether parameters have been entered through the input dialog
 *
 * @return bool - ob eine gültige Sequenz-ID gefunden und restauriert wurde
 */
bool ValidateInputs.ID(bool interactive) {
   interactive = interactive!=0;

   bool isParameterChange = (ProgramInitReason() == IR_PARAMETERS);  // otherwise inputs have been applied programmatically
   if (isParameterChange)
      interactive = true;

   string strValue = StrToUpper(StrTrim(Sequence.ID));

   if (!StringLen(strValue))
      return(false);

   if (StrLeft(strValue, 1) == "T") {
      sequence.isTest = true;
      strValue = StrRight(strValue, -1);
   }
   if (!StrIsDigit(strValue))
      return(_false(ValidateInputs.OnError("ValidateInputs.ID(1)", "Illegal input parameter Sequence.ID = \""+ Sequence.ID +"\"", interactive)));

   int iValue = StrToInteger(strValue);
   if (iValue < SID_MIN || iValue > SID_MAX)
      return(_false(ValidateInputs.OnError("ValidateInputs.ID(2)", "Illegal input parameter Sequence.ID = \""+ Sequence.ID +"\"", interactive)));

   sequence.id   = iValue; SS.SequenceId();
   Sequence.ID   = ifString(IsTestSequence(), "T", "") + sequence.id;
   sequence.name = StrLeft(TradeDirectionDescription(sequence.direction), 1) +"."+ sequence.id;
   SetCustomLog(sequence.id, NULL);

   return(true);
}


/**
 * Validate new or changed input parameters of a sequence. Parameters may have been entered through the input dialog, may
 * have been read and applied from a sequence status file or may have been deserialized and applied programmatically by the
 * terminal (e.g. at terminal restart).
 *
 * @param  bool interactive - whether the parameters have been entered through the input dialog
 *
 * @return bool - whether the input parameters are valid
 */
bool ValidateInputs(bool interactive) {
   interactive = interactive!=0;
   if (IsLastError()) return(false);

   bool isParameterChange = (ProgramInitReason() == IR_PARAMETERS);  // otherwise inputs have been applied programmatically
   if (isParameterChange)
      interactive = true;

   // Sequence.ID
   if (isParameterChange) {
      if (sequence.status == STATUS_UNDEFINED) {
         if (Sequence.ID != last.Sequence.ID)                     return(_false(ValidateInputs.OnError("ValidateInputs(1)", "Changing the sequence at runtime is not supported. Unload the EA first.", interactive)));
      }
      else if (!StringLen(StrTrim(Sequence.ID))) {
         Sequence.ID = last.Sequence.ID;                          // apply the existing internal id
      }
      else if (StrTrim(Sequence.ID) != StrTrim(last.Sequence.ID)) return(_false(ValidateInputs.OnError("ValidateInputs(2)", "Changing the sequence at runtime is not supported. Unload the EA first.", interactive)));
   }
   else if (!StringLen(Sequence.ID)) {                            // wir müssen im STATUS_UNDEFINED sein (sequence.id = 0)
      if (sequence.id != 0)                                       return(_false(catch("ValidateInputs(3)  illegal Sequence.ID = \""+ Sequence.ID +"\" (sequence.id="+ sequence.id +")", ERR_RUNTIME_ERROR)));
   }
   else {}                                                        // wenn gesetzt, ist die ID schon validiert und die Sequenz geladen (sonst landen wir hier nicht)

   // GridDirection
   string sValue = StrToLower(StrTrim(GridDirection));
   if      (StrStartsWith("long",  sValue)) sValue = "Long";
   else if (StrStartsWith("short", sValue)) sValue = "Short";
   else                                                           return(_false(ValidateInputs.OnError("ValidateInputs(4)", "Invalid GridDirection = \""+ GridDirection +"\"", interactive)));
   if (isParameterChange && !StrCompareI(sValue, last.GridDirection)) {
      if (ArraySize(sequence.start.event) > 0)                    return(_false(ValidateInputs.OnError("ValidateInputs(5)", "Cannot change GridDirection of "+ StatusDescription(sequence.status) +" sequence", interactive)));
   }
   sequence.direction = StrToTradeDirection(sValue);
   GridDirection      = sValue; SS.GridDirection();
   sequence.name      = StrLeft(GridDirection, 1) +"."+ sequence.id;

   // GridSize
   if (isParameterChange) {
      if (GridSize != last.GridSize)
         if (ArraySize(sequence.start.event) > 0)                 return(_false(ValidateInputs.OnError("ValidateInputs(6)", "Cannot change GridSize of "+ StatusDescription(sequence.status) +" sequence", interactive)));
   }
   if (GridSize < 1)                                              return(_false(ValidateInputs.OnError("ValidateInputs(7)", "Invalid GridSize = "+ GridSize, interactive)));

   // LotSize
   if (isParameterChange) {
      if (NE(LotSize, last.LotSize))
         if (ArraySize(sequence.start.event) > 0)                 return(_false(ValidateInputs.OnError("ValidateInputs(8)", "Cannot change LotSize of "+ StatusDescription(sequence.status) +" sequence", interactive)));
   }
   if (LE(LotSize, 0))                                            return(_false(ValidateInputs.OnError("ValidateInputs(9)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+"), interactive)));
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT );
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT );
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   int error = GetLastError();
   if (IsError(error))                                            return(_false(catch("ValidateInputs(10)  symbol=\""+ Symbol() +"\"", error)));
   if (LT(LotSize, minLot))                                       return(_false(ValidateInputs.OnError("ValidateInputs(11)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+") +" (MinLot="+  NumberToStr(minLot, ".+" ) +")", interactive)));
   if (GT(LotSize, maxLot))                                       return(_false(ValidateInputs.OnError("ValidateInputs(12)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+") +" (MaxLot="+  NumberToStr(maxLot, ".+" ) +")", interactive)));
   if (MathModFix(LotSize, lotStep) != 0)                         return(_false(ValidateInputs.OnError("ValidateInputs(13)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", interactive)));
   SS.LotSize();

   // StartLevel
   if (isParameterChange) {
      if (StartLevel != last.StartLevel)
         if (ArraySize(sequence.start.event) > 0)                 return(_false(ValidateInputs.OnError("ValidateInputs(14)", "Cannot change StartLevel of "+ StatusDescription(sequence.status) +" sequence", interactive)));
   }
   if (sequence.direction == D_LONG) {
      if (StartLevel < 0)                                         return(_false(ValidateInputs.OnError("ValidateInputs(15)", "Invalid StartLevel = "+ StartLevel, interactive)));
   }
   StartLevel = Abs(StartLevel);

   string trendIndicators[] = {"ALMA", "MovingAverage", "NonLagMA", "TriEMA", "HalfTrend", "SuperTrend"};


   // StartConditions, AND combined: @trend(<indicator>:<timeframe>:<params>) | @[bid|ask|median|price](double) | @time(datetime)
   // ---------------------------------------------------------------------------------------------------------------------------
   // Bei Parameteränderung Werte nur übernehmen, wenn sie sich tatsächlich geändert haben, sodaß StartConditions nur bei Änderung (re-)aktiviert werden.
   if (!isParameterChange || StartConditions!=last.StartConditions) {
      start.conditions      = false;
      start.trend.condition = false;
      start.price.condition = false;
      start.time.condition  = false;

      // StartConditions in einzelne Ausdrücke zerlegen
      string exprs[], expr, elems[], key;
      int    iValue, time, sizeOfElems, sizeOfExprs = Explode(StartConditions, "&&", exprs, NULL);
      double dValue;

      // jeden Ausdruck parsen und validieren
      for (int i=0; i < sizeOfExprs; i++) {
         start.conditions = false;                      // im Fehlerfall ist start.conditions immer deaktiviert

         expr = StrTrim(exprs[i]);
         if (!StringLen(expr)) {
            if (sizeOfExprs > 1)                        return(_false(ValidateInputs.OnError("ValidateInputs(16)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions), interactive)));
            break;
         }
         if (StringGetChar(expr, 0) != '@')             return(_false(ValidateInputs.OnError("ValidateInputs(17)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions), interactive)));
         if (Explode(expr, "(", elems, NULL) != 2)      return(_false(ValidateInputs.OnError("ValidateInputs(18)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions), interactive)));
         if (!StrEndsWith(elems[1], ")"))               return(_false(ValidateInputs.OnError("ValidateInputs(19)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions), interactive)));
         key = StrTrim(elems[0]);
         sValue = StrTrim(StrLeft(elems[1], -1));
         if (!StringLen(sValue))                        return(_false(ValidateInputs.OnError("ValidateInputs(20)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions), interactive)));

         if (key == "@trend") {
            if (start.trend.condition)                  return(_false(ValidateInputs.OnError("ValidateInputs(21)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions) +" (multiple trend conditions)", interactive)));
            if (start.price.condition)                  return(_false(ValidateInputs.OnError("ValidateInputs(22)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions) +" (trend and price conditions)", interactive)));
            if (start.time.condition)                   return(_false(ValidateInputs.OnError("ValidateInputs(23)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions) +" (trend and time conditions)", interactive)));
            if (Explode(sValue, ":", elems, NULL) != 3) return(_false(ValidateInputs.OnError("ValidateInputs(24)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions), interactive)));
            sValue = StrTrim(elems[0]);
            int idx = SearchStringArrayI(trendIndicators, sValue);
            if (idx == -1)                              return(_false(ValidateInputs.OnError("ValidateInputs(25)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions) +" (unsupported trend indicator "+ DoubleQuoteStr(sValue) +")", interactive)));
            start.trend.indicator = StrToLower(sValue);
            start.trend.timeframe = StrToPeriod(elems[1], F_ERR_INVALID_PARAMETER);
            if (start.trend.timeframe == -1)            return(_false(ValidateInputs.OnError("ValidateInputs(26)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions) +" (trend indicator timeframe)", interactive)));
            start.trend.params = StrTrim(elems[2]);
            if (!StringLen(start.trend.params))         return(_false(ValidateInputs.OnError("ValidateInputs(27)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions) +" (trend indicator parameters)", interactive)));
            exprs[i] = "trend("+ trendIndicators[idx] +":"+ TimeframeDescription(start.trend.timeframe) +":"+ start.trend.params +")";
            start.trend.description = exprs[i];
            start.trend.condition   = true;
         }

         else if (key=="@bid" || key=="@ask" || key=="@median" || key=="@price") {
            if (start.trend.condition)                  return(_false(ValidateInputs.OnError("ValidateInputs(28)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions) +" (trend and price conditions)", interactive)));
            if (start.price.condition)                  return(_false(ValidateInputs.OnError("ValidateInputs(29)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions) +" (multiple price conditions)", interactive)));
            sValue = StrReplace(sValue, "'", "");
            if (!StrIsNumeric(sValue))                  return(_false(ValidateInputs.OnError("ValidateInputs(30)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions), interactive)));
            dValue = StrToDouble(sValue);
            if (dValue <= 0)                            return(_false(ValidateInputs.OnError("ValidateInputs(31)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions), interactive)));
            start.price.value     = NormalizeDouble(dValue, Digits);
            start.price.lastValue = NULL;
            if      (key == "@bid") start.price.type = PRICE_BID;
            else if (key == "@ask") start.price.type = PRICE_ASK;
            else                    start.price.type = PRICE_MEDIAN;
            exprs[i] = NumberToStr(start.price.value, PriceFormat);
            exprs[i] = StrSubstr(key, 1) +"("+ StrLeftTo(exprs[i], "'0") +")";   // cut "'0" for improved readability
            start.price.description = exprs[i];
            start.price.condition   = true;
         }

         else if (key == "@time") {
            if (start.trend.condition)                  return(_false(ValidateInputs.OnError("ValidateInputs(32)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions) +" (trend and time conditions)", interactive)));
            if (start.time.condition)                   return(_false(ValidateInputs.OnError("ValidateInputs(33)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions) +" (multiple time conditions)", interactive)));
            time = StrToTime(sValue);
            if (IsError(GetLastError()))                return(_false(ValidateInputs.OnError("ValidateInputs(34)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions), interactive)));
            // TODO: Validierung von @time ist unzureichend
            start.time.value = time;
            exprs[i]         = "time("+ TimeToStr(time) +")";
            start.time.description = exprs[i];
            start.time.condition   = true;
         }
         else                                           return(_false(ValidateInputs.OnError("ValidateInputs(35)", "Invalid StartConditions = "+ DoubleQuoteStr(StartConditions), interactive)));

         start.conditions = true;                       // im Erfolgsfall ist start.conditions aktiviert
      }
      if (start.conditions) StartConditions = JoinStrings(exprs, " && ");
      else                  StartConditions = "";
   }

   // StopConditions, OR combined: @trend(<indicator>:<timeframe>:<params>) | @[bid|ask|median|price](1.33) | @time(12:00) | @profit(1234[%])
   // ---------------------------------------------------------------------------------------------------------------------------------------
   // Bei Parameteränderung Werte nur übernehmen, wenn sie sich tatsächlich geändert haben, sodaß StopConditions nur bei Änderung (re-)aktiviert werden.
   if (!isParameterChange || StopConditions!=last.StopConditions) {
      stop.trend.condition     = false;
      stop.price.condition     = false;
      stop.time.condition      = false;
      stop.profitAbs.condition = false;
      stop.profitPct.condition = false;

      // StopConditions in einzelne Ausdrücke zerlegen
      sizeOfExprs = Explode(StrTrim(StopConditions), "||", exprs, NULL);

      // jeden Ausdruck parsen und validieren
      for (i=0; i < sizeOfExprs; i++) {
         expr = StrToLower(StrTrim(exprs[i]));
         if (!StringLen(expr)) {
            if (sizeOfExprs > 1)                        return(_false(ValidateInputs.OnError("ValidateInputs(36)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions), interactive)));
            break;
         }
         if (StringGetChar(expr, 0) != '@')             return(_false(ValidateInputs.OnError("ValidateInputs(37)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions), interactive)));
         if (Explode(expr, "(", elems, NULL) != 2)      return(_false(ValidateInputs.OnError("ValidateInputs(38)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions), interactive)));
         if (!StrEndsWith(elems[1], ")"))               return(_false(ValidateInputs.OnError("ValidateInputs(39)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions), interactive)));
         key = StrTrim(elems[0]);
         sValue = StrTrim(StrLeft(elems[1], -1));
         if (!StringLen(sValue))                        return(_false(ValidateInputs.OnError("ValidateInputs(40)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions), interactive)));

         if (key == "@trend") {
            if (stop.trend.condition)                   return(_false(ValidateInputs.OnError("ValidateInputs(41)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions) +" (multiple trend conditions)", interactive)));
            if (Explode(sValue, ":", elems, NULL) != 3) return(_false(ValidateInputs.OnError("ValidateInputs(42)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions), interactive)));
            sValue = StrTrim(elems[0]);
            idx = SearchStringArrayI(trendIndicators, sValue);
            if (idx == -1)                              return(_false(ValidateInputs.OnError("ValidateInputs(43)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions) +" (unsupported trend indicator "+ DoubleQuoteStr(sValue) +")", interactive)));
            stop.trend.indicator = StrToLower(sValue);
            stop.trend.timeframe = StrToPeriod(elems[1], F_ERR_INVALID_PARAMETER);
            if (stop.trend.timeframe == -1)             return(_false(ValidateInputs.OnError("ValidateInputs(44)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions) +" (trend indicator timeframe)", interactive)));
            stop.trend.params = StrTrim(elems[2]);
            if (!StringLen(stop.trend.params))          return(_false(ValidateInputs.OnError("ValidateInputs(45)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions) +" (trend indicator parameters)", interactive)));
            exprs[i] = "trend("+ trendIndicators[idx] +":"+ TimeframeDescription(stop.trend.timeframe) +":"+ stop.trend.params +")";
            stop.trend.description = exprs[i];
            stop.trend.condition   = true;
         }

         else if (key=="@bid" || key=="@ask" || key=="@median" || key=="@price") {
            if (stop.price.condition)                   return(_false(ValidateInputs.OnError("ValidateInputs(46)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions) +" (multiple price conditions)", interactive)));
            sValue = StrReplace(sValue, "'", "");
            if (!StrIsNumeric(sValue))                  return(_false(ValidateInputs.OnError("ValidateInputs(47)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions), interactive)));
            dValue = StrToDouble(sValue);
            if (dValue <= 0)                            return(_false(ValidateInputs.OnError("ValidateInputs(48)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions), interactive)));
            stop.price.value     = NormalizeDouble(dValue, Digits);
            stop.price.lastValue = NULL;
            if      (key == "@bid") stop.price.type = PRICE_BID;
            else if (key == "@ask") stop.price.type = PRICE_ASK;
            else                    stop.price.type = PRICE_MEDIAN;
            exprs[i] = NumberToStr(stop.price.value, PriceFormat);
            exprs[i] = StrSubstr(key, 1) +"("+ StrLeftTo(exprs[i], "'0") +")";   // cut "'0" for improved readability
            stop.price.description = exprs[i];
            stop.price.condition   = true;
         }

         else if (key == "@time") {
            if (stop.time.condition)                    return(_false(ValidateInputs.OnError("ValidateInputs(49)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions) +" (multiple time conditions)", interactive)));
            time = StrToTime(sValue);
            if (IsError(GetLastError()))                return(_false(ValidateInputs.OnError("ValidateInputs(50)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions), interactive)));
            // TODO: Validierung von @time ist unzureichend
            stop.time.value       = time;
            exprs[i]              = "time("+ TimeToStr(time) +")";
            stop.time.description = exprs[i];
            stop.time.condition   = true;
         }

         else if (key == "@profit") {
            if (stop.profitAbs.condition || stop.profitPct.condition)
                                                        return(_false(ValidateInputs.OnError("ValidateInputs(51)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions) +" (multiple profit conditions)", interactive)));
            sizeOfElems = Explode(sValue, "%", elems, NULL);
            if (sizeOfElems > 2)                        return(_false(ValidateInputs.OnError("ValidateInputs(52)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions), interactive)));
            sValue = StrTrim(elems[0]);
            if (!StringLen(sValue))                     return(_false(ValidateInputs.OnError("ValidateInputs(53)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions), interactive)));
            if (!StrIsNumeric(sValue))                  return(_false(ValidateInputs.OnError("ValidateInputs(54)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions), interactive)));
            dValue = StrToDouble(sValue);
            if (sizeOfElems == 1) {
               stop.profitAbs.value       = NormalizeDouble(dValue, 2);
               exprs[i]                   = "profit("+ DoubleToStr(dValue, 2) +")";
               stop.profitAbs.description = exprs[i];
               stop.profitAbs.condition   = true;
            }
            else {
               stop.profitPct.value       = dValue;
               stop.profitPct.absValue    = INT_MAX;
               exprs[i]                   = "profit("+ NumberToStr(dValue, ".+") +"%)";
               stop.profitPct.description = exprs[i];
               stop.profitPct.condition   = true;
            }
         }
         else                                           return(_false(ValidateInputs.OnError("ValidateInputs(55)", "Invalid StopConditions = "+ DoubleQuoteStr(StopConditions), interactive)));
      }
      StopConditions = JoinStrings(exprs, " || ");
   }

   // AutoResume
   if (AutoResume && !start.trend.condition)            return(_false(ValidateInputs.OnError("ValidateInputs(56)", "Invalid StartConditions for AutoResume = "+ DoubleQuoteStr(StartConditions), interactive)));

   // Sessionbreak.StartTime/EndTime
   if (Sessionbreak.StartTime!=last.Sessionbreak.StartTime || Sessionbreak.EndTime!=last.Sessionbreak.EndTime) {
      sessionbreak.starttime = NULL;
      sessionbreak.endtime   = NULL;                    // real times are updated automatically on next use
   }

   // ShowProfitInPercent: nothing to validate

   // reset __STATUS_INVALID_INPUT
   if (interactive)
      __STATUS_INVALID_INPUT = false;
   return(!last_error|catch("ValidateInputs(57)"));
}


/**
 * Error-Handler für ungültige Input-Parameter. Je nach Situation wird der Fehler an den Default-Errorhandler übergeben
 * oder zur Korrektur aufgefordert.
 *
 * @param  string location    - Ort, an dem der Fehler auftrat
 * @param  string message     - Fehlermeldung
 * @param  bool   interactive - ob der Fehler interaktiv behandelt werden kann
 *
 * @return int - der resultierende Fehlerstatus
 */
int ValidateInputs.OnError(string location, string message, bool interactive) {
   interactive = interactive!=0;
   if (IsTesting() || !interactive)
      return(catch(location +"   "+ message, ERR_INVALID_CONFIG_VALUE));

   int error = ERR_INVALID_INPUT_PARAMETER;
   __STATUS_INVALID_INPUT = true;

   if (__LOG()) log(location +"   "+ message, error);
   PlaySoundEx("Windows Chord.wav");
   int button = MessageBoxEx(__NAME() +" - "+ location, message, MB_ICONERROR|MB_RETRYCANCEL);
   if (button == IDRETRY)
      __STATUS_RELAUNCH_INPUT = true;
   return(error);
}


/**
 * Initialisiert die Dateinamensvariablen der Statusdatei mit den Ausgangswerten einer neuen Sequenz.
 *
 * @return bool - success status
 */
bool InitStatusLocation() {
   if (IsLastError()) return( false);
   if (!sequence.id)  return(_false(catch("InitStatusLocation(1)  illegal value of sequence.id = "+ sequence.id, ERR_RUNTIME_ERROR)));

   if      (IsTesting())      statusDirectory = "presets\\";
   else if (IsTestSequence()) statusDirectory = "presets\\tester\\";
   else                       statusDirectory = "presets\\"+ ShortAccountCompany() +"\\";

   statusFile = StrToLower(StdSymbol()) +".SR."+ sequence.id +".set";
   return(true);
}


/**
 * Aktualisiert die Dateinamensvariablen der Statusdatei. SaveSequence() erkennt die Änderung und verschiebt die Datei automatisch.
 *
 * @return bool - success status
 */
bool UpdateStatusLocation() {
   if (IsLastError()) return( false);
   if (!sequence.id)  return(_false(catch("UpdateStatusLocation(1)  illegal value of sequence.id = "+ sequence.id, ERR_RUNTIME_ERROR)));

   // TODO: Prüfen, ob statusFile existiert und ggf. aktualisieren

   if      (IsTesting())      statusDirectory = "presets\\";
   else if (IsTestSequence()) statusDirectory = "presets\\tester\\";
   else                       statusDirectory = "presets\\"+ ShortAccountCompany() +"\\";
   return(true);
}


/**
 * Restauriert anhand der verfügbaren Informationen Ort und Namen der Statusdatei, wird nur aus LoadSequence() heraus aufgerufen.
 *
 * @return bool - Erfolgsstatus
 */
bool ResolveStatusLocation() {
   if (IsLastError()) return(false);

   // Location-Variablen zurücksetzen
   InitStatusLocation();
   string filesDirectory  = GetFullMqlFilesPath() +"\\";
   string statusDirectory = MQL.GetStatusDirName();
   string directory="", subdirs[], subdir="", location="", file="";

   while (true) {
      if (location != "") {
         // mit location: das angegebene Unterverzeichnis durchsuchen
         directory = filesDirectory + statusDirectory + StdSymbol() +"\\"+ location +"\\";
         if (ResolveStatusLocation.FindFile(directory, file))
            break;
         return(false);
      }

      // ohne location: zuerst Basisverzeichnis durchsuchen...
      directory = filesDirectory + statusDirectory;
      if (ResolveStatusLocation.FindFile(directory, file))
         break;
      if (IsLastError()) return(false);

      // ohne location: ...dann Unterverzeichnisse des jeweiligen Symbols durchsuchen
      directory = directory + StdSymbol() +"\\";
      int size = FindFileNames(directory +"*", subdirs, FF_DIRSONLY); if (size == -1) return(false);

      for (int i=0; i < size; i++) {
         subdir = directory + subdirs[i] +"\\";
         if (ResolveStatusLocation.FindFile(subdir, file)) {
            directory = subdir;
            location  = subdirs[i];
            break;
         }
         if (IsLastError()) return(false);
      }
      if (StringLen(file) > 0)
         break;
      return(!catch("ResolveStatusLocation(1)  status file not found", ERR_FILE_NOT_FOUND));
   }

   statusDirectory = StrRight(directory, -StringLen(filesDirectory));
   statusFile      = file;
   return(true);
}


/**
 * Durchsucht das angegebene Verzeichnis nach einer passenden Statusdatei und schreibt das Ergebnis in die übergebene Variable.
 *
 * @param  string directory - vollständiger Name des zu durchsuchenden Verzeichnisses
 * @param  string lpFile    - Zeiger auf Variable zur Aufnahme des gefundenen Dateinamens
 *
 * @return bool - success status
 */
bool ResolveStatusLocation.FindFile(string directory, string &lpFile) {
   if (IsLastError()) return( false);
   if (!sequence.id)  return(_false(catch("ResolveStatusLocation.FindFile(1)  illegal value of sequence.id = "+ sequence.id, ERR_RUNTIME_ERROR)));

   if (!StrEndsWith(directory, "\\"))
      directory = directory +"\\";

   string sequencePattern = "SR*"+ sequence.id;                                  // * steht für [._-] (? für ein einzelnes Zeichen funktioniert nicht)
   string sequenceNames[2];
          sequenceNames[0]= "SR."+ sequence.id +".";
          sequenceNames[1]= "SR."+ sequence.id +"_";

   string filePattern = directory +"*"+ sequencePattern +"*set";
   string files[];

   int size = FindFileNames(filePattern, files, FF_FILESONLY);                   // Dateien suchen, die den Sequenznamen enthalten und mit "set" enden
   if (size == -1) return(false);

   for (int i=0; i < size; i++) {
      if (!StrStartsWithI(files[i], sequenceNames[0]))
         if (!StrStartsWithI(files[i], sequenceNames[1]))
            if (!StrContainsI(files[i], "."+ sequenceNames[0]))
               if (!StrContainsI(files[i], "."+ sequenceNames[1]))
         continue;
      if (StrEndsWithI(files[i], ".set")) {
         lpFile = files[i];                                                      // Abbruch nach Fund der ersten .set-Datei
         return(true);
      }
   }

   lpFile = "";
   return(false);
}


/**
 * Return the name of the status file directory relative to "files/".
 *
 * @return string - directory name ending with a backslash
 */
string MQL.GetStatusDirName() {
   return(statusDirectory);
}


/**
 * Return the name of the status file relative to "files/".
 *
 * @return string
 */
string MQL.GetStatusFileName() {
   return(statusDirectory + statusFile);
}


int lastEventId;


/**
 * Generate and return a new event id.
 *
 * @return int - new event id
 */
int CreateEventId() {
   lastEventId++;
   return(lastEventId);
}


/**
 * Store the current sequence status in a file. A sequence can be reloaded from such a file (e.g. on terminal restart).
 *
 * @return bool - success status
 */
bool SaveSequence() {
   if (IsLastError())                             return(false);
   if (!sequence.id)                              return(!catch("SaveSequence(1)  illegal value of sequence.id = "+ sequence.id, ERR_RUNTIME_ERROR));
   if (IsTestSequence()) /*&&*/ if (!IsTesting()) return(true);

   // Im Tester wird der Status zur Performancesteigerung nur beim ersten und letzten Aufruf gespeichert,
   // oder wenn die Sequenz gestoppt wurde.
   if (IsTesting() /*&& !__LOG()*/) {                                // enable !__LOG() to always save if logging is enabled
      static bool statusSaved = false;
      if (statusSaved && sequence.status!=STATUS_STOPPED && sequence.status!=STATUS_WAITING && __WHEREAMI__!=CF_DEINIT)
         return(true);                                               // skip saving
   }

   /*
   Speichernotwendigkeit der einzelnen Variablen
   ---------------------------------------------
   int      sequence.id;                  // nein: wird aus Statusdatei ermittelt
   int      sequence.status;              // nein: kann aus Orderdaten und offenen Positionen restauriert werden
   bool     sequence.isTest;              // nein: wird aus Statusdatei ermittelt
   int      sequence.direction;           // nein: wird aus Statusdatei ermittelt
   int      sequence.level;               // nein: kann aus Orderdaten restauriert werden
   int      sequence.maxLevel;            // nein: kann aus Orderdaten restauriert werden
   int      sequence.missedLevels[];      // optional: wird gespeichert, wenn belegt
   double   sequence.startEquity;         // ja
   int      sequence.stops;               // nein: kann aus Orderdaten restauriert werden
   double   sequence.stopsPL;             // nein: kann aus Orderdaten restauriert werden
   double   sequence.closedPL;            // nein: kann aus Orderdaten restauriert werden
   double   sequence.floatingPL;          // nein: kann aus offenen Positionen restauriert werden
   double   sequence.totalPL;             // nein: kann aus stopsPL, closedPL und floatingPL restauriert werden
   double   sequence.maxProfit;           // ja
   double   sequence.maxDrawdown;         // ja
   double   sequence.profitPerLevel;      // nein
   double   sequence.commission;          // nein: wird aus Config ermittelt

   int      sequence.start.event [];      // ja
   datetime sequence.start.time  [];      // ja
   double   sequence.start.price [];      // ja
   double   sequence.start.profit[];      // ja

   int      sequence.stop.event [];       // ja
   datetime sequence.stop.time  [];       // ja
   double   sequence.stop.price [];       // ja
   double   sequence.stop.profit[];       // ja

   bool     start.*.condition;            // nein: wird aus StartConditions abgeleitet
   bool     stop.*.condition;             // nein: wird aus StopConditions abgeleitet
   bool     sessionbreak.waiting;         // ja

   double   grid.base;                    // nein: wird aus Gridbase-History restauriert
   int      grid.base.event[];            // ja
   datetime grid.base.time [];            // ja
   double   grid.base.value[];            // ja

   int      orders.ticket         [];     // ja:  0
   int      orders.level          [];     // ja:  1
   double   orders.gridBase       [];     // ja:  2
   int      orders.pendingType    [];     // ja:  3
   datetime orders.pendingTime    [];     // ja:  4   kein Event
   double   orders.pendingPrice   [];     // ja:  5
   int      orders.type           [];     // ja:  6
   int      orders.openEvent      [];     // ja:  7
   datetime orders.openTime       [];     // ja:  8   EV_POSITION_OPEN
   double   orders.openPrice      [];     // ja:  9
   int      orders.closeEvent     [];     // ja: 10
   datetime orders.closeTime      [];     // ja: 11   EV_POSITION_STOPOUT | EV_POSITION_CLOSE
   double   orders.closePrice     [];     // ja: 12
   double   orders.stopLoss       [];     // ja: 13
   bool     orders.clientsideLimit[];     // ja: 14
   bool     orders.closedBySL     [];     // ja: 15
   double   orders.swap           [];     // ja: 16
   double   orders.commission     [];     // ja: 17
   double   orders.profit         [];     // ja: 18

   int      ignorePendingOrders  [];      // optional (werden nur gespeichert, wenn belegt)
   int      ignoreOpenPositions  [];      // optional (werden nur gespeichert, wenn belegt)
   int      ignoreClosedPositions[];      // optional (werden nur gespeichert, wenn belegt)
   */

   // Dateiinhalt zusammenstellen: Konfiguration und Input-Parameter
   string lines[]; ArrayResize(lines, 0);
   ArrayPushString(lines, /*string  */ "Account="+ ShortAccountCompany() +":"+ GetAccountNumber());
   ArrayPushString(lines, /*string  */ "Symbol="                + Symbol()              );
   ArrayPushString(lines, /*string  */ "Created="               + sequence.created      );
   ArrayPushString(lines, /*string  */ "Sequence.ID="           + Sequence.ID           );
   ArrayPushString(lines, /*string  */ "GridDirection="         + GridDirection         );
   ArrayPushString(lines, /*int     */ "GridSize="              + GridSize              );
   ArrayPushString(lines, /*double  */ "LotSize="+    NumberToStr(LotSize, ".+")        );
   ArrayPushString(lines, /*int     */ "StartLevel="            + StartLevel            );
   ArrayPushString(lines, /*string  */ "StartConditions="       + StartConditions       );
   ArrayPushString(lines, /*string  */ "StopConditions="        + StopConditions        );
   ArrayPushString(lines, /*bool    */ "AutoResume="            + AutoResume            );
   ArrayPushString(lines, /*datetime*/ "Sessionbreak.StartTime="+ Sessionbreak.StartTime);
   ArrayPushString(lines, /*datetime*/ "Sessionbreak.EndTime="  + Sessionbreak.EndTime  );
   ArrayPushString(lines, /*bool    */ "ShowProfitInPercent="   + ShowProfitInPercent   );

   // Laufzeit-Variablen
   ArrayPushString(lines, /*double*/ "rt.sequence.startEquity="+ NumberToStr(sequence.startEquity, ".+"));
      string values[]; ArrayResize(values, 0);
   ArrayPushString(lines, /*double*/ "rt.sequence.maxProfit="  + NumberToStr(sequence.maxProfit, ".+"));
   ArrayPushString(lines, /*double*/ "rt.sequence.maxDrawdown="+ NumberToStr(sequence.maxDrawdown, ".+"));
      int size = ArraySize(sequence.start.event);
      for (int i=0; i < size; i++)
         ArrayPushString(values, StringConcatenate(sequence.start.event[i], "|", sequence.start.time[i], "|", NumberToStr(sequence.start.price[i], ".+"), "|", NumberToStr(sequence.start.profit[i], ".+")));
      if (size == 0)
         ArrayPushString(values, "0|0|0|0");
   ArrayPushString(lines, /*string*/ "rt.sequence.starts="+ JoinStrings(values));
      ArrayResize(values, 0);
      size = ArraySize(sequence.stop.event);
      for (i=0; i < size; i++)
         ArrayPushString(values, StringConcatenate(sequence.stop.event[i], "|", sequence.stop.time[i], "|", NumberToStr(sequence.stop.price[i], ".+"), "|", NumberToStr(sequence.stop.profit[i], ".+")));
      if (size == 0)
         ArrayPushString(values, "0|0|0|0");
   ArrayPushString(lines, /*string*/ "rt.sequence.stops="       + JoinStrings(values));
      if (sequence.status==STATUS_WAITING)
   ArrayPushString(lines, /*int*/    "rt.sessionbreak.waiting=" + sessionbreak.waiting);
      if (ArraySize(sequence.missedLevels) > 0)
   ArrayPushString(lines, /*string*/ "rt.sequence.missedLevels="+ JoinInts(sequence.missedLevels));
      if (ArraySize(ignorePendingOrders) > 0)
   ArrayPushString(lines, /*string*/ "rt.ignorePendingOrders="  + JoinInts(ignorePendingOrders));
      if (ArraySize(ignoreOpenPositions) > 0)
   ArrayPushString(lines, /*string*/ "rt.ignoreOpenPositions="  + JoinInts(ignoreOpenPositions));
      if (ArraySize(ignoreClosedPositions) > 0)
   ArrayPushString(lines, /*string*/ "rt.ignoreClosedPositions="+ JoinInts(ignoreClosedPositions));
      ArrayResize(values, 0);
      size = ArraySize(grid.base.event);
      for (i=0; i < size; i++)
         ArrayPushString(values, StringConcatenate(grid.base.event[i], "|", grid.base.time[i], "|", NumberToStr(grid.base.value[i], ".+")));
      if (size == 0)
         ArrayPushString(values, "0|0|0");
   ArrayPushString(lines, /*string*/ "rt.grid.base="            + JoinStrings(values));

   size = ArraySize(orders.ticket);
   for (i=0; i < size; i++) {
      int      ticket       = orders.ticket         [i];    //  0
      int      level        = orders.level          [i];    //  1
      double   gridBase     = orders.gridBase       [i];    //  2
      int      pendingType  = orders.pendingType    [i];    //  3
      datetime pendingTime  = orders.pendingTime    [i];    //  4
      double   pendingPrice = orders.pendingPrice   [i];    //  5
      int      type         = orders.type           [i];    //  6
      int      openEvent    = orders.openEvent      [i];    //  7
      datetime openTime     = orders.openTime       [i];    //  8
      double   openPrice    = orders.openPrice      [i];    //  9
      int      closeEvent   = orders.closeEvent     [i];    // 10
      datetime closeTime    = orders.closeTime      [i];    // 11
      double   closePrice   = orders.closePrice     [i];    // 12
      double   stopLoss     = orders.stopLoss       [i];    // 13
      bool     clientLimit  = orders.clientsideLimit[i];    // 14
      bool     closedBySL   = orders.closedBySL     [i];    // 15
      double   swap         = orders.swap           [i];    // 16
      double   commission   = orders.commission     [i];    // 17
      double   profit       = orders.profit         [i];    // 18
      ArrayPushString(lines, StringConcatenate("rt.order.", i, "=", ticket, ",", level, ",", NumberToStr(NormalizeDouble(gridBase, Digits), ".+"), ",", pendingType, ",", pendingTime, ",", NumberToStr(NormalizeDouble(pendingPrice, Digits), ".+"), ",", type, ",", openEvent, ",", openTime, ",", NumberToStr(NormalizeDouble(openPrice, Digits), ".+"), ",", closeEvent, ",", closeTime, ",", NumberToStr(NormalizeDouble(closePrice, Digits), ".+"), ",", NumberToStr(NormalizeDouble(stopLoss, Digits), ".+"), ",", clientLimit, ",", closedBySL, ",", NumberToStr(swap, ".+"), ",", NumberToStr(commission, ".+"), ",", NumberToStr(profit, ".+")));
      //rt.order.{i}={ticket},{level},{gridBase},{pendingType},{pendingTime},{pendingPrice},{type},{openEvent},{openTime},{openPrice},{closeEvent},{closeTime},{closePrice},{stopLoss},{clientLimit},{closedBySL},{swap},{commission},{profit}
   }

   // alles speichern
   string filename = MQL.GetStatusFileName();
   int hFile = FileOpen(filename, FILE_CSV|FILE_WRITE);
   if (hFile < 0) return(_false(catch("SaveSequence(4)->FileOpen(\""+ filename +"\")")));

   for (i=0; i < ArraySize(lines); i++) {
      if (FileWrite(hFile, lines[i]) < 0) {
         int error = GetLastError();
         catch("SaveSequence(5)->FileWrite(line #"+ (i+1) +") failed to \""+ filename +"\"", ifInt(error, error, ERR_RUNTIME_ERROR));
         FileClose(hFile);
         return(false);
      }
   }
   FileClose(hFile);
   statusSaved = true;

   ArrayResize(lines,  0);
   ArrayResize(values, 0);
   return(!last_error|catch("SaveSequence(6)"));
}


/**
 * Liest den Status einer Sequenz aus der entsprechenden Datei ein und restauriert die internen Variablen.
 *
 * @return bool - ob der Status erfolgreich restauriert wurde
 */
bool LoadSequence() {
   if (IsLastError()) return( false);
   if (!sequence.id)  return(_false(catch("LoadSequence(1)  illegal value of sequence.id = "+ sequence.id, ERR_RUNTIME_ERROR)));

   // Pfade und Dateinamen bestimmen
   string fileName = MQL.GetStatusFileName();
   if (!MQL.IsFile(fileName)) {
      if (!ResolveStatusLocation()) return(false);
      fileName = MQL.GetStatusFileName();
   }

   // Datei einlesen
   string lines[];
   int size = FileReadLines(fileName, lines, true); if (size < 0) return(false);
   if (size == 0) {
      FileDelete(fileName);
      return(_false(catch("LoadSequence(2)  status for sequence "+ ifString(IsTestSequence(), "T", "") + sequence.id +" not found", ERR_RUNTIME_ERROR)));
   }

   // notwendige Schlüssel definieren
   string keys[] = { "Account", "Symbol", "Created", "Sequence.ID", "GridDirection", "GridSize", "LotSize", "StartLevel", "StartConditions", "StopConditions", "AutoResume", "Sessionbreak.StartTime", "Sessionbreak.EndTime", "rt.sequence.startEquity", "rt.sequence.maxProfit", "rt.sequence.maxDrawdown", "rt.sequence.starts", "rt.sequence.stops", "rt.grid.base" };
   /*                "Account"                 ,                        // Der Compiler kommt mit den Zeilennummern durcheinander, wenn der Initializer
                     "Symbol"                  ,                        //  nicht vollständig in einer einzigen Zeile steht.
                     "Created"                 ,
                     "Sequence.ID"             ,
                     "GridDirection"           ,
                     "GridSize"                ,
                     "LotSize"                 ,
                     "StartLevel"              ,
                     "StartConditions"         ,
                     "StopConditions"          ,
                     "AutoResume"              ,
                     "Sessionbreak.StartTime"  ,
                     "Sessionbreak.EndTime"    ,
                   //"ShowProfitInPercent"     ,                        // optional
                     ---------------------------
                     "rt.sequence.startEquity" ,
                     "rt.sequence.maxProfit"   ,
                     "rt.sequence.maxDrawdown" ,
                     "rt.sequence.starts"      ,
                     "rt.sequence.stops"       ,
                   //"rt.sessionbreak"         ,                        // optional
                   //"rt.sequence.missedLevels",                        // optional
                   //"rt.ignorePendingOrders"  ,                        // optional
                   //"rt.ignoreOpenPositions"  ,                        // optional
                   //"rt.ignoreClosedPositions",                        // optional
                     "rt.grid.base"            ,
   */


   // (3.1) Nicht-Runtime-Settings auslesen, validieren und übernehmen
   string parts[], key, value, accountValue;
   int    accountLine;

   for (int i=0; i < size; i++) {
      if (StrStartsWith(StrTrim(lines[i]), "#")) // Kommentare überspringen
         continue;

      if (Explode(lines[i], "=", parts, 2) < 2)  return(_false(catch("LoadSequence(3)  invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
      key   = StrTrim(parts[0]);
      value = StrTrim(parts[1]);

      if (key == "Account") {
         accountValue = value;
         accountLine  = i;
         ArrayDropString(keys, key);             // Abhängigkeit Account <=> Sequence.ID (siehe 3.2)
      }
      else if (key == "Symbol") {
         if (value != Symbol())                  return(_false(catch("LoadSequence(4)  symbol mis-match \""+ value +"\"/\""+ Symbol() +"\" in status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         ArrayDropString(keys, key);
      }
      else if (key == "Created") {
         sequence.created = value;
         ArrayDropString(keys, key);
      }
      else if (key == "Sequence.ID") {
         value = StrToUpper(value);
         if (StrLeft(value, 1) == "T") {
            sequence.isTest = true;
            value = StrRight(value, -1);
         }
         if (value != ""+ sequence.id)           return(_false(catch("LoadSequence(5)  invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         Sequence.ID = ifString(IsTestSequence(), "T", "") + sequence.id;
         ArrayDropString(keys, key);
      }
      else if (key == "GridDirection") {
         if (value == "")                        return(_false(catch("LoadSequence(6)  invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         GridDirection = value;
         ArrayDropString(keys, key);
      }
      else if (key == "GridSize") {
         if (!StrIsDigit(value))                 return(_false(catch("LoadSequence(7)  invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         GridSize = StrToInteger(value);
         ArrayDropString(keys, key);
      }
      else if (key == "LotSize") {
         if (!StrIsNumeric(value))               return(_false(catch("LoadSequence(8)  invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         LotSize = StrToDouble(value);
         ArrayDropString(keys, key);
      }
      else if (key == "StartLevel") {
         if (!StrIsDigit(value))                 return(_false(catch("LoadSequence(9)  invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         StartLevel = StrToInteger(value);
         ArrayDropString(keys, key);
      }
      else if (key == "StartConditions") {
         StartConditions = value;
         ArrayDropString(keys, key);
      }
      else if (key == "StopConditions") {
         StopConditions = value;
         ArrayDropString(keys, key);
      }
      else if (key == "AutoResume") {
         if (!StrIsDigit(value))                 return(_false(catch("LoadSequence(10)  invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         AutoResume = _bool(StrToInteger(value));
         ArrayDropString(keys, key);
      }
      else if (key == "Sessionbreak.StartTime") {
         if (!StrIsDigit(value))                 return(_false(catch("LoadSequence(11)  invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         Sessionbreak.StartTime = StrToInteger(value);
         ArrayDropString(keys, key);
      }
      else if (key == "Sessionbreak.EndTime") {
         if (!StrIsDigit(value))                 return(_false(catch("LoadSequence(12)  invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         Sessionbreak.EndTime = StrToInteger(value);
         ArrayDropString(keys, key);
      }
      else if (key == "ShowProfitInPercent") {
         if (!StrIsDigit(value))                 return(_false(catch("LoadSequence(13)  invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         ShowProfitInPercent = _bool(StrToInteger(value));
         ArrayDropString(keys, key);
      }
   }

   // Abhängigkeiten validieren
   // Account: Eine Testsequenz kann in einem anderen Account visualisiert werden, solange die Zeitzonen beider Accounts übereinstimmen.
   if (accountValue != ShortAccountCompany()+":"+GetAccountNumber()) {
      if (IsTesting() || !IsTestSequence() || !StrStartsWithI(accountValue, ShortAccountCompany() +":"))
         return(_false(catch("LoadSequence(14)  account mis-match "+ DoubleQuoteStr(ShortAccountCompany() +":"+ GetAccountNumber()) +"/"+ DoubleQuoteStr(accountValue) +" in status file "+ DoubleQuoteStr(fileName) +" (line "+ DoubleQuoteStr(lines[accountLine]) +")", ERR_RUNTIME_ERROR)));
   }

   // Runtime-Settings auslesen, validieren und übernehmen
   ArrayResize(sequence.start.event,  0);
   ArrayResize(sequence.start.time,   0);
   ArrayResize(sequence.start.price,  0);
   ArrayResize(sequence.start.profit, 0);
   ArrayResize(sequence.stop.event,   0);
   ArrayResize(sequence.stop.time,    0);
   ArrayResize(sequence.stop.price,   0);
   ArrayResize(sequence.stop.profit,  0);
   ArrayResize(sequence.missedLevels, 0);
   ArrayResize(ignorePendingOrders,   0);
   ArrayResize(ignoreOpenPositions,   0);
   ArrayResize(ignoreClosedPositions, 0);
   ArrayResize(grid.base.event,       0);
   ArrayResize(grid.base.time,        0);
   ArrayResize(grid.base.value,       0);
   lastEventId = 0;

   for (i=0; i < size; i++) {
      if (Explode(lines[i], "=", parts, 2) < 2)                            return(_false(catch("LoadSequence(15)  invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
      key   = StrTrim(parts[0]);
      value = StrTrim(parts[1]);

      if (StrStartsWith(key, "rt.")) {
         if (!LoadSequence.RuntimeStatus(fileName, lines[i], key, value, keys)) return(false);
      }
   }
   if (ArraySize(keys) > 0)                                                return(_false(catch("LoadSequence(16)  "+ ifString(ArraySize(keys)==1, "entry", "entries") +" \""+ JoinStrings(keys, "\", \"") +"\" missing in file \""+ fileName +"\"", ERR_RUNTIME_ERROR)));

   // Abhängigkeiten validieren
   if (ArraySize(sequence.start.event) != ArraySize(sequence.stop.event))  return(_false(catch("LoadSequence(17)  sequence.starts("+ ArraySize(sequence.start.event) +") / sequence.stops("+ ArraySize(sequence.stop.event) +") mis-match in file \""+ fileName +"\"", ERR_RUNTIME_ERROR)));
   if (IntInArray(orders.ticket, 0))                                       return(_false(catch("LoadSequence(18)  one or more order entries missing in file \""+ fileName +"\"", ERR_RUNTIME_ERROR)));

   ArrayResize(lines, 0);
   ArrayResize(keys,  0);
   ArrayResize(parts, 0);
   return(!last_error|catch("LoadSequence(19)"));
}


/**
 * Restauriert eine oder mehrere Laufzeitvariablen.
 *
 * @param  string file   - Name der Statusdatei, aus der die Einstellung stammt (für evt. Fehlermeldung)
 * @param  string line   - Statuszeile der Einstellung                          (für evt. Fehlermeldung)
 * @param  string key    - Schlüssel der Einstellung
 * @param  string value  - Wert der Einstellung
 * @param  string keys[] - Array für Rückmeldung des restaurierten Schlüssels
 *
 * @return bool - success status
 */
bool LoadSequence.RuntimeStatus(string file, string line, string key, string value, string keys[]) {
   if (IsLastError()) return(false);
   /*
   double   rt.sequence.startEquity=7801.13
   double   rt.sequence.maxProfit=200.13
   double   rt.sequence.maxDrawdown=-127.80
   string   rt.sequence.starts=1|1328701713|1.32677|1000, 2|1329999999|1.33215|1200
   string   rt.sequence.stops=3|1328701999|1.32734|1200, 0|0|0|0
   int      rt.sessionbreak.waiting=1
   string   rt.sequence.missedLevels=-6,-7,-8,-14
   string   rt.ignorePendingOrders=66064890,66064891,66064892
   string   rt.ignoreOpenPositions=66064890,66064891,66064892
   string   rt.ignoreClosedPositions=66064890,66064891,66064892
   string   rt.grid.base=4|1331710960|1.56743, 5|1331711010|1.56714
   string   rt.order.0=62544847,1,1.32067,4,1330932525,1.32067,1,100,1330936196,1.32067,0,101,1330938698,1.31897,1.31897,0,1,0,0,-17

            rt.order.{i}={ticket},{level},{gridBase},{pendingType},{pendingTime},{pendingPrice},{type},{openEvent},{openTime},{openPrice},{closeEvent},{closeTime},{closePrice},{stopLoss},{clientLimit},{closedBySL},{swap},{commission},{profit}
            -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
            int      ticket       = values[ 0];
            int      level        = values[ 1];
            double   gridBase     = values[ 2];
            int      pendingType  = values[ 3];
            datetime pendingTime  = values[ 4];
            double   pendingPrice = values[ 5];
            int      type         = values[ 6];
            int      openEvent    = values[ 7];
            datetime openTime     = values[ 8];
            double   openPrice    = values[ 9];
            int      closeEvent   = values[10];
            datetime closeTime    = values[11];
            double   closePrice   = values[12];
            double   stopLoss     = values[13];
            bool     clientLimit  = values[14];
            bool     closedBySL   = values[15];
            double   swap         = values[16];
            double   commission   = values[17];
            double   profit       = values[18];
   */
   string values[], data[];


   if (key == "rt.sequence.startEquity") {
      if (!StrIsNumeric(value))                                             return(_false(catch("LoadSequence.RuntimeStatus(1)  illegal sequence.startEquity \""+ value +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      sequence.startEquity = StrToDouble(value);
      if (LT(sequence.startEquity, 0))                                      return(_false(catch("LoadSequence.RuntimeStatus(2)  illegal sequence.startEquity "+ DoubleToStr(sequence.startEquity, 2) +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      ArrayDropString(keys, key);
   }
   else if (key == "rt.sequence.maxProfit") {
      if (!StrIsNumeric(value))                                             return(_false(catch("LoadSequence.RuntimeStatus(3)  illegal sequence.maxProfit \""+ value +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      sequence.maxProfit = StrToDouble(value); SS.MaxProfit();
      ArrayDropString(keys, key);
   }
   else if (key == "rt.sequence.maxDrawdown") {
      if (!StrIsNumeric(value))                                             return(_false(catch("LoadSequence.RuntimeStatus(4)  illegal sequence.maxDrawdown \""+ value +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      sequence.maxDrawdown = StrToDouble(value); SS.MaxDrawdown();
      ArrayDropString(keys, key);
   }
   else if (key == "rt.sequence.starts") {
      // rt.sequence.starts=1|1331710960|1.56743|1000, 2|1331711010|1.56714|1200
      int sizeOfValues = Explode(value, ",", values, NULL);
      for (int i=0; i < sizeOfValues; i++) {
         values[i] = StrTrim(values[i]);
         if (Explode(values[i], "|", data, NULL) != 4)                      return(_false(catch("LoadSequence.RuntimeStatus(5)  illegal number of sequence.starts["+ i +"] details (\""+ values[i] +"\" = "+ ArraySize(data) +") in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = StrTrim(data[0]);                 // sequence.start.event
         if (!StrIsDigit(value))                                            return(_false(catch("LoadSequence.RuntimeStatus(6)  illegal sequence.start.event["+ i +"] \""+ value +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         int startEvent = StrToInteger(value);
         if (startEvent == 0) {
            if (sizeOfValues==1 && values[i]=="0|0|0|0") {
               if (NE(sequence.startEquity, 0))                             return(_false(catch("LoadSequence.RuntimeStatus(7)  sequence.startEquity/sequence.start["+ i +"] mis-match "+ DoubleToStr(sequence.startEquity, 2) +"/\""+ values[i] +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
               break;
            }
            return(_false(catch("LoadSequence.RuntimeStatus(8)  illegal sequence.start.event["+ i +"] "+ startEvent +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         }
         if (EQ(sequence.startEquity, 0))                                   return(_false(catch("LoadSequence.RuntimeStatus(9)  sequence.startEquity/sequence.start["+ i +"] mis-match "+ DoubleToStr(sequence.startEquity, 2) +"/\""+ values[i] +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = StrTrim(data[1]);                 // sequence.start.time
         if (!StrIsDigit(value))                                            return(_false(catch("LoadSequence.RuntimeStatus(10)  illegal sequence.start.time["+ i +"] \""+ value +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         datetime startTime = StrToInteger(value);
         if (!startTime)                                                    return(_false(catch("LoadSequence.RuntimeStatus(11)  illegal sequence.start.time["+ i +"] "+ startTime +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = StrTrim(data[2]);                 // sequence.start.price
         if (!StrIsNumeric(value))                                          return(_false(catch("LoadSequence.RuntimeStatus(12)  illegal sequence.start.price["+ i +"] \""+ value +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         double startPrice = StrToDouble(value);
         if (LE(startPrice, 0))                                             return(_false(catch("LoadSequence.RuntimeStatus(13)  illegal sequence.start.price["+ i +"] "+ NumberToStr(startPrice, PriceFormat) +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = StrTrim(data[3]);                 // sequence.start.profit
         if (!StrIsNumeric(value))                                          return(_false(catch("LoadSequence.RuntimeStatus(14)  illegal sequence.start.profit["+ i +"] \""+ value +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         double startProfit = StrToDouble(value);

         ArrayPushInt   (sequence.start.event,  startEvent );
         ArrayPushInt   (sequence.start.time,   startTime  );
         ArrayPushDouble(sequence.start.price,  startPrice );
         ArrayPushDouble(sequence.start.profit, startProfit);
         lastEventId = Max(lastEventId, startEvent);
      }
      ArrayDropString(keys, key);
   }
   else if (key == "rt.sequence.stops") {
      // rt.sequence.stops=1|1331710960|1.56743|1200, 0|0|0|0
      sizeOfValues = Explode(value, ",", values, NULL);
      for (i=0; i < sizeOfValues; i++) {
         values[i] = StrTrim(values[i]);
         if (Explode(values[i], "|", data, NULL) != 4)                      return(_false(catch("LoadSequence.RuntimeStatus(15)  illegal number of sequence.stops["+ i +"] details (\""+ values[i] +"\" = "+ ArraySize(data) +") in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = StrTrim(data[0]);                 // sequence.stop.event
         if (!StrIsDigit(value))                                            return(_false(catch("LoadSequence.RuntimeStatus(16)  illegal sequence.stop.event["+ i +"] \""+ value +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         int stopEvent = StrToInteger(value);
         if (stopEvent == 0) {
            if (i < sizeOfValues-1)                                         return(_false(catch("LoadSequence.RuntimeStatus(17)  illegal sequence.stop["+ i +"] \""+ values[i] +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            if (values[i] != "0|0|0|0")                                     return(_false(catch("LoadSequence.RuntimeStatus(18)  illegal sequence.stop["+ i +"] \""+ values[i] +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            if (i==0 && ArraySize(sequence.start.event)==0)
               break;
         }

         value = StrTrim(data[1]);                 // sequence.stop.time
         if (!StrIsDigit(value))                                            return(_false(catch("LoadSequence.RuntimeStatus(19)  illegal sequence.stop.time["+ i +"] \""+ value +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         datetime stopTime = StrToInteger(value);
         if (!stopTime && stopEvent!=0)                                     return(_false(catch("LoadSequence.RuntimeStatus(20)  illegal sequence.stop.time["+ i +"] "+ stopTime +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         if (i >= ArraySize(sequence.start.event))                          return(_false(catch("LoadSequence.RuntimeStatus(21)  sequence.starts("+ ArraySize(sequence.start.event) +") / sequence.stops("+ sizeOfValues +") mis-match in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         if (stopTime!=0 && stopTime < sequence.start.time[i])              return(_false(catch("LoadSequence.RuntimeStatus(22)  sequence.start.time["+ i +"]/sequence.stop.time["+ i +"] mis-match '"+ TimeToStr(sequence.start.time[i], TIME_FULL) +"'/'"+ TimeToStr(stopTime, TIME_FULL) +"' in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = StrTrim(data[2]);                 // sequence.stop.price
         if (!StrIsNumeric(value))                                          return(_false(catch("LoadSequence.RuntimeStatus(23)  illegal sequence.stop.price["+ i +"] \""+ value +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         double stopPrice = StrToDouble(value);
         if (LT(stopPrice, 0))                                              return(_false(catch("LoadSequence.RuntimeStatus(24)  illegal sequence.stop.price["+ i +"] "+ NumberToStr(stopPrice, PriceFormat) +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         if (EQ(stopPrice, 0) && stopEvent!=0)                              return(_false(catch("LoadSequence.RuntimeStatus(25)  sequence.stop.time["+ i +"]/sequence.stop.price["+ i +"] mis-match '"+ TimeToStr(stopTime, TIME_FULL) +"'/"+ NumberToStr(stopPrice, PriceFormat) +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = StrTrim(data[3]);                 // sequence.stop.profit
         if (!StrIsNumeric(value))                                          return(_false(catch("LoadSequence.RuntimeStatus(26)  illegal sequence.stop.profit["+ i +"] \""+ value +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         double stopProfit = StrToDouble(value);

         ArrayPushInt   (sequence.stop.event,  stopEvent );
         ArrayPushInt   (sequence.stop.time,   stopTime  );
         ArrayPushDouble(sequence.stop.price,  stopPrice );
         ArrayPushDouble(sequence.stop.profit, stopProfit);
         lastEventId = Max(lastEventId, stopEvent);
      }
      ArrayDropString(keys, key);
   }
   else if (key == "rt.sessionbreak.waiting") {
      if (!StrIsDigit(value))                                               return(_false(catch("LoadSequence.RuntimeStatus(27)  illegal sessionbreak waiting status \""+ value +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      sessionbreak.waiting = (StrToInteger(value));
   }
   else if (key == "rt.sequence.missedLevels") {
      // rt.sequence.missedLevels=-6,-7,-8,-14
      if (StringLen(value) > 0) {
         sizeOfValues = Explode(value, ",", values, NULL);
         for (i=0; i < sizeOfValues; i++) {
            string sLevel = StrTrim(values[i]);
            if (!StrIsInteger(sLevel))                                      return(_false(catch("LoadSequence.RuntimeStatus(27)  illegal missed grid level \""+ sLevel +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            int level = StrToInteger(sLevel);
            if (!level)                                                     return(_false(catch("LoadSequence.RuntimeStatus(28)  illegal missed grid level "+ level +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            ArrayPushInt(sequence.missedLevels, level);
         }
      }
   }
   else if (key == "rt.ignorePendingOrders") {
      // rt.ignorePendingOrders=66064890,66064891,66064892
      if (StringLen(value) > 0) {
         sizeOfValues = Explode(value, ",", values, NULL);
         for (i=0; i < sizeOfValues; i++) {
            string sTicket = StrTrim(values[i]);
            if (!StrIsDigit(sTicket))                                       return(_false(catch("LoadSequence.RuntimeStatus(29)  illegal ticket \""+ sTicket +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            int ticket = StrToInteger(sTicket);
            if (!ticket)                                                    return(_false(catch("LoadSequence.RuntimeStatus(30)  illegal ticket #"+ ticket +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            ArrayPushInt(ignorePendingOrders, ticket);
         }
      }
   }
   else if (key == "rt.ignoreOpenPositions") {
      // rt.ignoreOpenPositions=66064890,66064891,66064892
      if (StringLen(value) > 0) {
         sizeOfValues = Explode(value, ",", values, NULL);
         for (i=0; i < sizeOfValues; i++) {
            sTicket = StrTrim(values[i]);
            if (!StrIsDigit(sTicket))                                       return(_false(catch("LoadSequence.RuntimeStatus(31)  illegal ticket \""+ sTicket +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            ticket = StrToInteger(sTicket);
            if (!ticket)                                                    return(_false(catch("LoadSequence.RuntimeStatus(32)  illegal ticket #"+ ticket +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            ArrayPushInt(ignoreOpenPositions, ticket);
         }
      }
   }
   else if (key == "rt.ignoreClosedPositions") {
      // rt.ignoreClosedPositions=66064890,66064891,66064892
      if (StringLen(value) > 0) {
         sizeOfValues = Explode(value, ",", values, NULL);
         for (i=0; i < sizeOfValues; i++) {
            sTicket = StrTrim(values[i]);
            if (!StrIsDigit(sTicket))                                       return(_false(catch("LoadSequence.RuntimeStatus(33)  illegal ticket \""+ sTicket +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            ticket = StrToInteger(sTicket);
            if (!ticket)                                                    return(_false(catch("LoadSequence.RuntimeStatus(34)  illegal ticket #"+ ticket +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            ArrayPushInt(ignoreClosedPositions, ticket);
         }
      }
   }
   else if (key == "rt.grid.base") {
      // rt.grid.base=1|1331710960|1.56743, 2|1331711010|1.56714
      sizeOfValues = Explode(value, ",", values, NULL);
      for (i=0; i < sizeOfValues; i++) {
         if (Explode(values[i], "|", data, NULL) != 3)                      return(_false(catch("LoadSequence.RuntimeStatus(35)  illegal number of grid.base["+ i +"] details (\""+ values[i] +"\" = "+ ArraySize(data) +") in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = StrTrim(data[0]);                 // GridBase-Event
         if (!StrIsDigit(value))                                            return(_false(catch("LoadSequence.RuntimeStatus(36)  illegal grid.base.event["+ i +"] \""+ value +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         int gridBaseEvent = StrToInteger(value);
         int starts = ArraySize(sequence.start.event);
         if (gridBaseEvent == 0) {
            if (sizeOfValues==1 && values[0]=="0|0|0") {
               if (starts > 0)                                              return(_false(catch("LoadSequence.RuntimeStatus(37)  sequence.start/grid.base["+ i +"] mis-match '"+ TimeToStr(sequence.start.time[0], TIME_FULL) +"'/\""+ values[i] +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
               break;
            }                                                               return(_false(catch("LoadSequence.RuntimeStatus(38)  illegal grid.base.event["+ i +"] "+ gridBaseEvent +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         }
         else if (!starts)                                                  return(_false(catch("LoadSequence.RuntimeStatus(39)  sequence.start/grid.base["+ i +"] mis-match "+ starts +"/\""+ values[i] +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = StrTrim(data[1]);                 // GridBase-Zeitpunkt
         if (!StrIsDigit(value))                                            return(_false(catch("LoadSequence.RuntimeStatus(40)  illegal grid.base.time["+ i +"] \""+ value +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         datetime gridBaseTime = StrToInteger(value);
         if (!gridBaseTime)                                                 return(_false(catch("LoadSequence.RuntimeStatus(41)  illegal grid.base.time["+ i +"] "+ gridBaseTime +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = StrTrim(data[2]);                 // GridBase-Wert
         if (!StrIsNumeric(value))                                          return(_false(catch("LoadSequence.RuntimeStatus(42)  illegal grid.base.value["+ i +"] \""+ value +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         double gridBaseValue = StrToDouble(value);
         if (LE(gridBaseValue, 0))                                          return(_false(catch("LoadSequence.RuntimeStatus(43)  illegal grid.base.value["+ i +"] "+ NumberToStr(gridBaseValue, PriceFormat) +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         ArrayPushInt   (grid.base.event, gridBaseEvent);
         ArrayPushInt   (grid.base.time,  gridBaseTime );
         ArrayPushDouble(grid.base.value, gridBaseValue);
         lastEventId = Max(lastEventId, gridBaseEvent);
      }
      ArrayDropString(keys, key);
   }
   else if (StrStartsWith(key, "rt.order.")) {
      // rt.order.{i}={ticket},{level},{gridBase},{pendingType},{pendingTime},{pendingPrice},{type},{openEvent},{openTime},{openPrice},{closeEvent},{closeTime},{closePrice},{stopLoss},{clientLimit},{closedBySL},{swap},{commission},{profit}
      // Orderindex
      string strIndex = StrRight(key, -9);
      if (!StrIsDigit(strIndex))                                            return(_false(catch("LoadSequence.RuntimeStatus(44)  illegal order index \""+ key +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      i = StrToInteger(strIndex);
      if (ArraySize(orders.ticket) > i) /*&&*/ if (orders.ticket[i]!=0)     return(_false(catch("LoadSequence.RuntimeStatus(45)  duplicate order index "+ key +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // Orderdaten
      if (Explode(value, ",", values, NULL) != 19)                          return(_false(catch("LoadSequence.RuntimeStatus(46)  illegal number of order details ("+ ArraySize(values) +") in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // ticket
      sTicket = StrTrim(values[0]);
      if (!StrIsInteger(sTicket))                                           return(_false(catch("LoadSequence.RuntimeStatus(47)  illegal ticket \""+ sTicket +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      ticket = StrToInteger(sTicket);
      if (ticket > 0) {
         if (IntInArray(orders.ticket, ticket))                             return(_false(catch("LoadSequence.RuntimeStatus(48)  duplicate ticket #"+ ticket +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      }
      else if (ticket!=-1 && ticket!=-2)                                    return(_false(catch("LoadSequence.RuntimeStatus(49)  illegal ticket #"+ ticket +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // level
      sLevel = StrTrim(values[1]);
      if (!StrIsInteger(sLevel))                                            return(_false(catch("LoadSequence.RuntimeStatus(50)  illegal grid level \""+ sLevel +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      level = StrToInteger(sLevel);
      if (!level)                                                           return(_false(catch("LoadSequence.RuntimeStatus(51)  illegal grid level "+ level +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // gridBase
      string sGridBase = StrTrim(values[2]);
      if (!StrIsNumeric(sGridBase))                                         return(_false(catch("LoadSequence.RuntimeStatus(52)  illegal order gridbase \""+ sGridBase +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double gridBase = StrToDouble(sGridBase);
      if (LE(gridBase, 0))                                                  return(_false(catch("LoadSequence.RuntimeStatus(53)  illegal order gridbase "+ NumberToStr(gridBase, PriceFormat) +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // pendingType
      string sPendingType = StrTrim(values[3]);
      if (!StrIsInteger(sPendingType))                                      return(_false(catch("LoadSequence.RuntimeStatus(54)  illegal pending order type \""+ sPendingType +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      int pendingType = StrToInteger(sPendingType);
      if (pendingType!=OP_UNDEFINED && !IsPendingOrderType(pendingType))    return(_false(catch("LoadSequence.RuntimeStatus(55)  illegal pending order type \""+ sPendingType +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // pendingTime
      string sPendingTime = StrTrim(values[4]);
      if (!StrIsDigit(sPendingTime))                                        return(_false(catch("LoadSequence.RuntimeStatus(56)  illegal pending order time \""+ sPendingTime +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      datetime pendingTime = StrToInteger(sPendingTime);
      if (pendingType==OP_UNDEFINED && pendingTime!=0)                      return(_false(catch("LoadSequence.RuntimeStatus(57)  pending order type/time mis-match "+ OperationTypeToStr(pendingType) +"/'"+ TimeToStr(pendingTime, TIME_FULL) +"' in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (pendingType!=OP_UNDEFINED && !pendingTime)                        return(_false(catch("LoadSequence.RuntimeStatus(58)  pending order type/time mis-match "+ OperationTypeToStr(pendingType) +"/"+ pendingTime +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // pendingPrice
      string sPendingPrice = StrTrim(values[5]);
      if (!StrIsNumeric(sPendingPrice))                                     return(_false(catch("LoadSequence.RuntimeStatus(59)  illegal pending order price \""+ sPendingPrice +"\" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double pendingPrice = StrToDouble(sPendingPrice);
      if (LT(pendingPrice, 0))                                              return(_false(catch("LoadSequence.RuntimeStatus(60)  illegal pending order price "+ NumberToStr(pendingPrice, PriceFormat) +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (pendingType==OP_UNDEFINED && NE(pendingPrice, 0))                 return(_false(catch("LoadSequence.RuntimeStatus(61)  pending order type/price mis-match "+ OperationTypeToStr(pendingType) +"/"+ NumberToStr(pendingPrice, PriceFormat) +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (pendingType!=OP_UNDEFINED) {
         if (EQ(pendingPrice, 0))                                           return(_false(catch("LoadSequence.RuntimeStatus(62)  pending order type/price mis-match "+ OperationTypeToStr(pendingType) +"/"+ NumberToStr(pendingPrice, PriceFormat) +" in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         if (NE(pendingPrice, gridBase+level*GridSize*Pips, Digits))        return(_false(catch("LoadSequence.RuntimeStatus(63)  gridbase/pending order price mis-match "+ NumberToStr(gridBase, PriceFormat) +"/"+ NumberToStr(pendingPrice, PriceFormat) +" (level "+ level +") in status file "+ DoubleQuoteStr(file) +" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      }

      // type
      string sType = StrTrim(values[6]);
      if (!StrIsInteger(sType))                                             return(_false(catch("LoadSequence.RuntimeStatus(64)  illegal order type \""+ sType +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      int type = StrToInteger(sType);
      if (type!=OP_UNDEFINED && !IsOrderType(type))                         return(_false(catch("LoadSequence.RuntimeStatus(65)  illegal order type \""+ sType +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (pendingType == OP_UNDEFINED) {
         if (type == OP_UNDEFINED)                                          return(_false(catch("LoadSequence.RuntimeStatus(66)  pending order type/open order type mis-match "+ OperationTypeToStr(pendingType) +"/"+ OperationTypeToStr(type) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      }
      else if (type != OP_UNDEFINED) {
         if (IsLongOrderType(pendingType)!=IsLongOrderType(type))           return(_false(catch("LoadSequence.RuntimeStatus(67)  pending order type/open order type mis-match "+ OperationTypeToStr(pendingType) +"/"+ OperationTypeToStr(type) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      }

      // openEvent
      string sOpenEvent = StrTrim(values[7]);
      if (!StrIsDigit(sOpenEvent))                                          return(_false(catch("LoadSequence.RuntimeStatus(68)  illegal order open event \""+ sOpenEvent +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      int openEvent = StrToInteger(sOpenEvent);
      if (type!=OP_UNDEFINED && !openEvent)                                 return(_false(catch("LoadSequence.RuntimeStatus(69)  illegal order open event "+ openEvent +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // openTime
      string sOpenTime = StrTrim(values[8]);
      if (!StrIsDigit(sOpenTime))                                           return(_false(catch("LoadSequence.RuntimeStatus(70)  illegal order open time \""+ sOpenTime +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      datetime openTime = StrToInteger(sOpenTime);
      if (type==OP_UNDEFINED && openTime!=0)                                return(_false(catch("LoadSequence.RuntimeStatus(71)  order type/time mis-match "+ OperationTypeToStr(type) +"/'"+ TimeToStr(openTime, TIME_FULL) +"' in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (type!=OP_UNDEFINED && !openTime)                                  return(_false(catch("LoadSequence.RuntimeStatus(72)  order type/time mis-match "+ OperationTypeToStr(type) +"/"+ openTime +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // openPrice
      string sOpenPrice = StrTrim(values[9]);
      if (!StrIsNumeric(sOpenPrice))                                        return(_false(catch("LoadSequence.RuntimeStatus(73)  illegal order open price \""+ sOpenPrice +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double openPrice = StrToDouble(sOpenPrice);
      if (LT(openPrice, 0))                                                 return(_false(catch("LoadSequence.RuntimeStatus(74)  illegal order open price "+ NumberToStr(openPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (type==OP_UNDEFINED && NE(openPrice, 0))                           return(_false(catch("LoadSequence.RuntimeStatus(75)  order type/price mis-match "+ OperationTypeToStr(type) +"/"+ NumberToStr(openPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (type!=OP_UNDEFINED && EQ(openPrice, 0))                           return(_false(catch("LoadSequence.RuntimeStatus(76)  order type/price mis-match "+ OperationTypeToStr(type) +"/"+ NumberToStr(openPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // closeEvent
      string sCloseEvent = StrTrim(values[10]);
      if (!StrIsDigit(sCloseEvent))                                         return(_false(catch("LoadSequence.RuntimeStatus(77)  illegal order close event \""+ sCloseEvent +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      int closeEvent = StrToInteger(sCloseEvent);

      // closeTime
      string sCloseTime = StrTrim(values[11]);
      if (!StrIsDigit(sCloseTime))                                          return(_false(catch("LoadSequence.RuntimeStatus(78)  illegal order close time \""+ sCloseTime +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      datetime closeTime = StrToInteger(sCloseTime);
      if (closeTime != 0) {
         if (closeTime < pendingTime)                                       return(_false(catch("LoadSequence.RuntimeStatus(79)  pending order time/delete time mis-match '"+ TimeToStr(pendingTime, TIME_FULL) +"'/'"+ TimeToStr(closeTime, TIME_FULL) +"' in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         if (closeTime < openTime)                                          return(_false(catch("LoadSequence.RuntimeStatus(80)  order open/close time mis-match '"+ TimeToStr(openTime, TIME_FULL) +"'/'"+ TimeToStr(closeTime, TIME_FULL) +"' in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      }
      if (closeTime!=0 && !closeEvent)                                      return(_false(catch("LoadSequence.RuntimeStatus(81)  illegal order close event "+ closeEvent +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // closePrice
      string sClosePrice = StrTrim(values[12]);
      if (!StrIsNumeric(sClosePrice))                                       return(_false(catch("LoadSequence.RuntimeStatus(82)  illegal order close price \""+ sClosePrice +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double closePrice = StrToDouble(sClosePrice);
      if (LT(closePrice, 0))                                                return(_false(catch("LoadSequence.RuntimeStatus(83)  illegal order close price "+ NumberToStr(closePrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // stopLoss
      string sStopLoss = StrTrim(values[13]);
      if (!StrIsNumeric(sStopLoss))                                         return(_false(catch("LoadSequence.RuntimeStatus(84)  illegal order stoploss \""+ sStopLoss +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double stopLoss = StrToDouble(sStopLoss);
      if (LE(stopLoss, 0))                                                  return(_false(catch("LoadSequence.RuntimeStatus(85)  illegal order stoploss "+ NumberToStr(stopLoss, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (NE(stopLoss, gridBase+(level-Sign(level))*GridSize*Pips, Digits)) return(_false(catch("LoadSequence.RuntimeStatus(86)  gridbase/stoploss mis-match "+ NumberToStr(gridBase, PriceFormat) +"/"+ NumberToStr(stopLoss, PriceFormat) +" (level "+ level +") in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // clientLimit
      string sClientLimit = StrTrim(values[14]);
      if (!StrIsDigit(sClientLimit))                                        return(_false(catch("LoadSequence.RuntimeStatus(87)  illegal clientLimit value \""+ sClientLimit +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      bool clientLimit = _bool(StrToInteger(sClientLimit));

      // closedBySL
      string sClosedBySL = StrTrim(values[15]);
      if (!StrIsDigit(sClosedBySL))                                         return(_false(catch("LoadSequence.RuntimeStatus(88)  illegal closedBySL value \""+ sClosedBySL +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      bool closedBySL = _bool(StrToInteger(sClosedBySL));

      // swap
      string sSwap = StrTrim(values[16]);
      if (!StrIsNumeric(sSwap))                                             return(_false(catch("LoadSequence.RuntimeStatus(89)  illegal order swap \""+ sSwap +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double swap = StrToDouble(sSwap);
      if (type==OP_UNDEFINED && NE(swap, 0))                                return(_false(catch("LoadSequence.RuntimeStatus(90)  pending order/swap mis-match "+ OperationTypeToStr(pendingType) +"/"+ DoubleToStr(swap, 2) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // commission
      string sCommission = StrTrim(values[17]);
      if (!StrIsNumeric(sCommission))                                       return(_false(catch("LoadSequence.RuntimeStatus(91)  illegal order commission \""+ sCommission +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double commission = StrToDouble(sCommission);
      if (type==OP_UNDEFINED && NE(commission, 0))                          return(_false(catch("LoadSequence.RuntimeStatus(92)  pending order/commission mis-match "+ OperationTypeToStr(pendingType) +"/"+ DoubleToStr(commission, 2) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // profit
      string sProfit = StrTrim(values[18]);
      if (!StrIsNumeric(sProfit))                                           return(_false(catch("LoadSequence.RuntimeStatus(93)  illegal order profit \""+ sProfit +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double profit = StrToDouble(sProfit);
      if (type==OP_UNDEFINED && NE(profit, 0))                              return(_false(catch("LoadSequence.RuntimeStatus(94)  pending order/profit mis-match "+ OperationTypeToStr(pendingType) +"/"+ DoubleToStr(profit, 2) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));


      // Daten speichern
      Grid.SetData(i, ticket, level, gridBase, pendingType, pendingTime, pendingPrice, type, openEvent, openTime, openPrice, closeEvent, closeTime, closePrice, stopLoss, clientLimit, closedBySL, swap, commission, profit);
      lastEventId = Max(lastEventId, Max(openEvent, closeEvent));
      // rt.order.{i}={ticket},{level},{gridBase},{pendingType},{pendingTime},{pendingPrice},{type},{openEvent},{openTime},{openPrice},{closeEvent},{closeTime},{closePrice},{stopLoss},{clientLimit},{closedBySL},{swap},{commission},{profit}
   }

   ArrayResize(values, 0);
   ArrayResize(data,   0);
   return(!last_error|catch("LoadSequence.RuntimeStatus(95)"));
}


/**
 * Gleicht den in der Instanz gespeicherten Laufzeitstatus mit den Online-Daten der laufenden Sequenz ab.
 * Aufruf nur direkt nach ValidateInputs()
 *
 * @return bool - Erfolgsstatus
 */
bool SynchronizeStatus() {
   if (IsLastError()) return(false);

   bool permanentStatusChange, permanentTicketChange, pendingOrder, openPosition;

   int orphanedPendingOrders  []; ArrayResize(orphanedPendingOrders,   0);
   int orphanedOpenPositions  []; ArrayResize(orphanedOpenPositions,   0);
   int orphanedClosedPositions[]; ArrayResize(orphanedClosedPositions, 0);

   int closed[][2], close[2], sizeOfTickets=ArraySize(orders.ticket); ArrayResize(closed, 0);


   // (1.1) alle offenen Tickets in Datenarrays synchronisieren, gestrichene PendingOrders löschen
   for (int i=0; i < sizeOfTickets; i++) {
      if (orders.ticket[i] < 0)                                            // client-seitige PendingOrders überspringen
         continue;

      if (!IsTestSequence() || !IsTesting()) {                             // keine Synchronization für abgeschlossene Tests
         if (orders.closeTime[i] == 0) {
            if (!IsTicket(orders.ticket[i])) {                             // bei fehlender History zur Erweiterung auffordern
               PlaySoundEx("Windows Notify.wav");
               int button = MessageBoxEx(__NAME() +" - SynchronizeStatus()", "Ticket #"+ orders.ticket[i] +" not found.\nPlease expand the available trade history.", MB_ICONERROR|MB_RETRYCANCEL);
               if (button != IDRETRY)
                  return(!SetLastError(ERR_CANCELLED_BY_USER));
               return(SynchronizeStatus());
            }
            if (!SelectTicket(orders.ticket[i], "SynchronizeStatus(1)  cannot synchronize "+ OperationTypeDescription(ifInt(orders.type[i]==OP_UNDEFINED, orders.pendingType[i], orders.type[i])) +" order (#"+ orders.ticket[i] +" not found)"))
               return(false);
            if (!Sync.UpdateOrder(i, permanentTicketChange))
               return(false);
            permanentStatusChange = permanentStatusChange || permanentTicketChange;
         }
      }

      if (orders.closeTime[i] != 0) {
         if (orders.type[i] == OP_UNDEFINED) {
            if (!Grid.DropData(i))                                         // geschlossene PendingOrders löschen
               return(false);
            sizeOfTickets--; i--;
            permanentStatusChange = true;
         }
         else if (!orders.closedBySL[i]) /*&&*/ if (!orders.closeEvent[i]) {
            close[0] = orders.closeTime[i];                                // bei StopSequence() geschlossene Position: Ticket zur späteren Vergabe der Event-ID zwichenspeichern
            close[1] = orders.ticket   [i];
            ArrayPushInts(closed, close);
         }
      }
   }

   // (1.2) Event-IDs geschlossener Positionen setzen (IDs für ausgestoppte Positionen wurden vorher in Sync.UpdateOrder() vergeben)
   int sizeOfClosed = ArrayRange(closed, 0);
   if (sizeOfClosed > 0) {
      ArraySort(closed);
      for (i=0; i < sizeOfClosed; i++) {
         int n = SearchIntArray(orders.ticket, closed[i][1]);
         if (n == -1)
            return(_false(catch("SynchronizeStatus(2)  closed ticket #"+ closed[i][1] +" not found in order arrays", ERR_RUNTIME_ERROR)));
         orders.closeEvent[n] = CreateEventId();
      }
      ArrayResize(closed, 0);
      ArrayResize(close,  0);
   }

   // (1.3) alle erreichbaren Tickets der Sequenz auf lokale Referenz überprüfen (außer für abgeschlossene Tests)
   if (!IsTestSequence() || IsTesting()) {
      for (i=OrdersTotal()-1; i >= 0; i--) {                               // offene Tickets
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))                  // FALSE: während des Auslesens wurde in einem anderen Thread eine offene Order entfernt
            continue;
         if (IsMyOrder(sequence.id)) /*&&*/ if (!IntInArray(orders.ticket, OrderTicket())) {
            pendingOrder = IsPendingOrderType(OrderType());                // kann PendingOrder oder offene Position sein
            openPosition = !pendingOrder;
            if (pendingOrder) /*&&*/ if (!IntInArray(ignorePendingOrders, OrderTicket())) ArrayPushInt(orphanedPendingOrders, OrderTicket());
            if (openPosition) /*&&*/ if (!IntInArray(ignoreOpenPositions, OrderTicket())) ArrayPushInt(orphanedOpenPositions, OrderTicket());
         }
      }

      for (i=OrdersHistoryTotal()-1; i >= 0; i--) {                        // geschlossene Tickets
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))                 // FALSE: während des Auslesens wurde der Anzeigezeitraum der History verkürzt
            continue;
         if (IsPendingOrderType(OrderType()))                              // gestrichene PendingOrders ignorieren
            continue;
         if (IsMyOrder(sequence.id)) /*&&*/ if (!IntInArray(orders.ticket, OrderTicket())) {
            if (!IntInArray(ignoreClosedPositions, OrderTicket()))         // kann nur geschlossene Position sein
               ArrayPushInt(orphanedClosedPositions, OrderTicket());
         }
      }
   }

   // (1.4) Vorgehensweise für verwaiste Tickets erfragen
   int size = ArraySize(orphanedPendingOrders);                            // TODO: Ignorieren nicht möglich; wenn die Tickets übernommen werden sollen,
   if (size > 0) {                                                         //       müssen sie richtig einsortiert werden.
      return(_false(catch("SynchronizeStatus(3)  unknown pending orders found: #"+ JoinInts(orphanedPendingOrders, ", #"), ERR_RUNTIME_ERROR)));
      //ArraySort(orphanedPendingOrders);
      //PlaySoundEx("Windows Notify.wav");
      //int button = MessageBoxEx(__NAME() +" - SynchronizeStatus()", ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Orphaned pending order"+ ifString(size==1, "", "s") +" found: #"+ JoinInts(orphanedPendingOrders, ", #") +"\nDo you want to ignore "+ ifString(size==1, "it", "them") +"?", MB_ICONWARNING|MB_OKCANCEL);
      //if (button != IDOK) {
      //   SetLastError(ERR_CANCELLED_BY_USER);
      //   return(_false(catch("SynchronizeStatus(4)")));
      //}
      ArrayResize(orphanedPendingOrders, 0);
   }
   size = ArraySize(orphanedOpenPositions);                                // TODO: Ignorieren nicht möglich; wenn die Tickets übernommen werden sollen,
   if (size > 0) {                                                         //       müssen sie richtig einsortiert werden.
      return(_false(catch("SynchronizeStatus(5)  unknown open positions found: #"+ JoinInts(orphanedOpenPositions, ", #"), ERR_RUNTIME_ERROR)));
      //ArraySort(orphanedOpenPositions);
      //PlaySoundEx("Windows Notify.wav");
      //button = MessageBoxEx(__NAME() +" - SynchronizeStatus()", ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Orphaned open position"+ ifString(size==1, "", "s") +" found: #"+ JoinInts(orphanedOpenPositions, ", #") +"\nDo you want to ignore "+ ifString(size==1, "it", "them") +"?", MB_ICONWARNING|MB_OKCANCEL);
      //if (button != IDOK) {
      //   SetLastError(ERR_CANCELLED_BY_USER);
      //   return(_false(catch("SynchronizeStatus(6)")));
      //}
      ArrayResize(orphanedOpenPositions, 0);
   }
   size = ArraySize(orphanedClosedPositions);
   if (size > 0) {
      ArraySort(orphanedClosedPositions);
      PlaySoundEx("Windows Notify.wav");
      button = MessageBoxEx(__NAME() +" - SynchronizeStatus()", ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Orphaned closed position"+ ifString(size==1, "", "s") +" found: #"+ JoinInts(orphanedClosedPositions, ", #") +"\nDo you want to ignore "+ ifString(size==1, "it", "them") +"?", MB_ICONWARNING|MB_OKCANCEL);
      if (button != IDOK) {
         SetLastError(ERR_CANCELLED_BY_USER);
         return(_false(catch("SynchronizeStatus(7)")));
      }
      MergeIntArrays(ignoreClosedPositions, orphanedClosedPositions, ignoreClosedPositions);
      ArraySort(ignoreClosedPositions);
      permanentStatusChange = true;
      ArrayResize(orphanedClosedPositions, 0);
   }

   if (ArraySize(sequence.start.event) > 0) /*&&*/ if (ArraySize(grid.base.event)==0)
      return(_false(catch("SynchronizeStatus(8)  illegal number of grid.base events = "+ 0, ERR_RUNTIME_ERROR)));


   // Status und Variablen synchronisieren
   /*int   */ lastEventId         = 0;
   /*int   */ sequence.status     = STATUS_WAITING;
   /*int   */ sequence.level      = 0;
   /*int   */ sequence.maxLevel   = 0;
   /*int   */ sequence.stops      = 0;
   /*double*/ sequence.stopsPL    = 0;
   /*double*/ sequence.closedPL   = 0;
   /*double*/ sequence.floatingPL = 0;
   /*double*/ sequence.totalPL    = 0;

   datetime   stopTime;
   double     stopPrice;

   if (!Sync.ProcessEvents(stopTime, stopPrice))
      return(false);

   // Wurde die Sequenz außerhalb gestoppt, EV_SEQUENCE_STOP erzeugen
   if (sequence.status == STATUS_STOPPING) {
      i = ArraySize(sequence.stop.event) - 1;
      if (sequence.stop.time[i] != 0)
         return(_false(catch("SynchronizeStatus(9)  unexpected sequence.stop.time = "+ IntsToStr(sequence.stop.time, NULL), ERR_RUNTIME_ERROR)));

      sequence.stop.event [i] = CreateEventId();
      sequence.stop.time  [i] = stopTime;
      sequence.stop.price [i] = NormalizeDouble(stopPrice, Digits);
      sequence.stop.profit[i] = sequence.totalPL;

      sequence.status       = STATUS_STOPPED;
      permanentStatusChange = true;
   }

   // validate sessionbreak status
   if (sessionbreak.waiting) /*&&*/ if (sequence.status!=STATUS_WAITING)
      return(_false(catch("SynchronizeStatus(10)  sessionbreak.waiting="+ sessionbreak.waiting +" / sequence.status="+ StatusToStr(sequence.status)+ " mis-match", ERR_RUNTIME_ERROR)));

   // permanente Statusänderungen speichern
   if (permanentStatusChange)
      if (!SaveSequence()) return(false);

   // Anzeigen aktualisieren, ShowStatus() folgt nach Funktionsende
   SS.All();
   RedrawStartStop();
   RedrawOrders();

   return(!catch("SynchronizeStatus(11)"));
}


/**
 * Aktualisiert die Daten des lokal als offen markierten Tickets mit dem Online-Status. Wird nur in SynchronizeStatus() verwendet.
 *
 * @param  int   i                 - Ticketindex
 * @param  bool &lpPermanentChange - Zeiger auf Variable, die anzeigt, ob dauerhafte Ticketänderungen vorliegen
 *
 * @return bool - success status
 */
bool Sync.UpdateOrder(int i, bool &lpPermanentChange) {
   lpPermanentChange = lpPermanentChange!=0;

   if (i < 0 || i > ArraySize(orders.ticket)-1) return(!catch("Sync.UpdateOrder(1)  illegal parameter i = "+ i, ERR_INVALID_PARAMETER));
   if (orders.closeTime[i] != 0)                return(!catch("Sync.UpdateOrder(2)  cannot update ticket #"+ orders.ticket[i] +" (marked as closed in grid arrays)", ERR_ILLEGAL_STATE));

   // das Ticket ist selektiert
   bool   wasPending = orders.type[i] == OP_UNDEFINED;               // vormals PendingOrder
   bool   wasOpen    = !wasPending;                                  // vormals offene Position
   bool   isPending  = IsPendingOrderType(OrderType());              // jetzt PendingOrder
   bool   isClosed   = OrderCloseTime() != 0;                        // jetzt geschlossen oder gestrichen
   bool   isOpen     = !isPending && !isClosed;                      // jetzt offene Position
   double lastSwap   = orders.swap[i];

   // Ticketdaten aktualisieren
   //orders.ticket       [i]                                         // unverändert
   //orders.level        [i]                                         // unverändert
   //orders.gridBase     [i]                                         // unverändert

   if (isPending) {
    //orders.pendingType [i]                                         // unverändert
    //orders.pendingTime [i]                                         // unverändert
      orders.pendingPrice[i] = OrderOpenPrice();
   }
   else if (wasPending) {
      orders.type        [i] = OrderType();
      orders.openEvent   [i] = CreateEventId();
      orders.openTime    [i] = OrderOpenTime();
      orders.openPrice   [i] = OrderOpenPrice();
   }

   if (EQ(OrderStopLoss(), 0)) {
      if (!orders.clientsideLimit[i]) {
         orders.stopLoss       [i] = NormalizeDouble(grid.base + (orders.level[i]-Sign(orders.level[i]))*GridSize*Pips, Digits);
         orders.clientsideLimit[i] = true;
         lpPermanentChange         = true;
      }
   }
   else {
      orders.stopLoss[i] = OrderStopLoss();
      if (orders.clientsideLimit[i]) {
         orders.clientsideLimit[i] = false;
         lpPermanentChange         = true;
      }
   }

   if (isClosed) {
      orders.closeTime   [i] = OrderCloseTime();
      orders.closePrice  [i] = OrderClosePrice();
      orders.closedBySL  [i] = IsOrderClosedBySL();
      if (orders.closedBySL[i])
         orders.closeEvent[i] = CreateEventId();                     // Event-IDs für ausgestoppte Positionen werden sofort, für geschlossene Positionen erst später vergeben.
   }

   if (!isPending) {
      orders.swap        [i] = OrderSwap();
      orders.commission  [i] = OrderCommission(); sequence.commission = OrderCommission(); SS.LotSize();
      orders.profit      [i] = OrderProfit();
   }

   // lpPermanentChange aktualisieren
   if      (wasPending) lpPermanentChange = lpPermanentChange || isOpen || isClosed;
   else if (  isClosed) lpPermanentChange = true;
   else                 lpPermanentChange = lpPermanentChange || NE(lastSwap, OrderSwap());

   return(!last_error|catch("Sync.UpdateOrder(3)"));
}


/**
 * Fügt den Breakeven-relevanten Events ein weiteres hinzu.
 *
 * @param  double   events[] - Event-Array
 * @param  int      id       - Event-ID
 * @param  datetime time     - Zeitpunkt des Events
 * @param  int      type     - Event-Typ
 * @param  double   gridBase - Gridbasis des Events
 * @param  int      index    - Index des originären Datensatzes innerhalb des entsprechenden Arrays
 */
void Sync.PushEvent(double &events[][], int id, datetime time, int type, double gridBase, int index) {
   if (type==EV_SEQUENCE_STOP) /*&&*/ if (!time)
      return;                                                        // nicht initialisierte Sequenz-Stops ignorieren (ggf. immer der letzte Stop)

   int size = ArrayRange(events, 0);
   ArrayResize(events, size+1);

   events[size][0] = id;
   events[size][1] = time;
   events[size][2] = type;
   events[size][3] = gridBase;
   events[size][4] = index;
}


/**
 *
 * @param  datetime &sequenceStopTime  - Variable, die die Sequenz-StopTime aufnimmt (falls die Stopdaten fehlen)
 * @param  double   &sequenceStopPrice - Variable, die den Sequenz-StopPrice aufnimmt (falls die Stopdaten fehlen)
 *
 * @return bool - Erfolgsstatus
 */
bool Sync.ProcessEvents(datetime &sequenceStopTime, double &sequenceStopPrice) {
   int    sizeOfTickets = ArraySize(orders.ticket);
   int    openLevels[]; ArrayResize(openLevels, 0);
   double events[][5];  ArrayResize(events,     0);
   bool   pendingOrder, openPosition, closedPosition, closedBySL;


   // (1) Breakeven-relevante Events zusammenstellen
   // (1.1) Sequenzstarts und -stops
   int sizeOfStarts = ArraySize(sequence.start.event);
   for (int i=0; i < sizeOfStarts; i++) {
    //Sync.PushEvent(events, id, time, type, gridBase, index);
      Sync.PushEvent(events, sequence.start.event[i], sequence.start.time[i], EV_SEQUENCE_START, NULL, i);
      Sync.PushEvent(events, sequence.stop.event [i], sequence.stop.time [i], EV_SEQUENCE_STOP,  NULL, i);
   }

   // (1.2) GridBase-Änderungen
   int sizeOfGridBase = ArraySize(grid.base.event);
   for (i=0; i < sizeOfGridBase; i++) {
      Sync.PushEvent(events, grid.base.event[i], grid.base.time[i], EV_GRIDBASE_CHANGE, grid.base.value[i], i);
   }

   // (1.3) Tickets
   for (i=0; i < sizeOfTickets; i++) {
      pendingOrder   = orders.type[i]  == OP_UNDEFINED;
      openPosition   = !pendingOrder   && orders.closeTime[i]==0;
      closedPosition = !pendingOrder   && !openPosition;
      closedBySL     =  closedPosition && orders.closedBySL[i];

      // nach offenen Levels darf keine geschlossene Position folgen
      if (closedPosition && !closedBySL)
         if (ArraySize(openLevels) > 0)                  return(_false(catch("Sync.ProcessEvents(1)  illegal sequence status, both open (#?) and closed (#"+ orders.ticket[i] +") positions found", ERR_RUNTIME_ERROR)));

      if (!pendingOrder) {
         Sync.PushEvent(events, orders.openEvent[i], orders.openTime[i], EV_POSITION_OPEN, NULL, i);

         if (openPosition) {
            if (IntInArray(openLevels, orders.level[i])) return(_false(catch("Sync.ProcessEvents(2)  duplicate order level "+ orders.level[i] +" of open position #"+ orders.ticket[i], ERR_RUNTIME_ERROR)));
            ArrayPushInt(openLevels, orders.level[i]);
            sequence.floatingPL = NormalizeDouble(sequence.floatingPL + orders.swap[i] + orders.commission[i] + orders.profit[i], 2);
         }
         else if (closedBySL) {
            Sync.PushEvent(events, orders.closeEvent[i], orders.closeTime[i], EV_POSITION_STOPOUT, NULL, i);
         }
         else /*(closed)*/ {
            Sync.PushEvent(events, orders.closeEvent[i], orders.closeTime[i], EV_POSITION_CLOSE, NULL, i);
         }
      }
      if (IsLastError()) return(false);
   }
   if (ArraySize(openLevels) != 0) {
      int min = openLevels[ArrayMinimum(openLevels)];
      int max = openLevels[ArrayMaximum(openLevels)];
      int maxLevel = Max(Abs(min), Abs(max));
      if (ArraySize(openLevels) != maxLevel) return(_false(catch("Sync.ProcessEvents(3)  illegal sequence status, missing one or more open positions", ERR_RUNTIME_ERROR)));
      ArrayResize(openLevels, 0);
   }


   // (2) Laufzeitvariablen restaurieren
   int      id, lastId, nextId, minute, lastMinute, type, lastType, nextType, index, nextIndex, iPositionMax, ticket, lastTicket, nextTicket, closedPositions, reopenedPositions;
   datetime time, lastTime, nextTime;
   double   gridBase;
   int      orderEvents[] = {EV_POSITION_OPEN, EV_POSITION_STOPOUT, EV_POSITION_CLOSE};
   int      sizeOfEvents = ArrayRange(events, 0);

   // (2.1) Events sortieren
   if (sizeOfEvents > 0) {
      ArraySort(events);
      int firstType = MathRound(events[0][2]);
      if (firstType != EV_SEQUENCE_START) return(_false(catch("Sync.ProcessEvents(4)  illegal first status event "+ StatusEventToStr(firstType) +" (id="+ Round(events[0][0]) +"   time='"+ TimeToStr(events[0][1], TIME_FULL) +"')", ERR_RUNTIME_ERROR)));
   }

   for (i=0; i < sizeOfEvents; i++) {
      id       = events[i][0];
      time     = events[i][1];
      type     = events[i][2];
      gridBase = events[i][3];
      index    = events[i][4];

      ticket     = 0; if (IntInArray(orderEvents, type)) { ticket = orders.ticket[index]; iPositionMax = Max(iPositionMax, index); }
      nextTicket = 0;
      if (i < sizeOfEvents-1) { nextId = events[i+1][0]; nextTime = events[i+1][1]; nextType = events[i+1][2]; nextIndex = events[i+1][4]; if (IntInArray(orderEvents, nextType)) nextTicket = orders.ticket[nextIndex]; }
      else                    { nextId = 0;              nextTime = 0;              nextType = 0;                                                                                               nextTicket = 0;                        }

      // (2.2) Events auswerten
      // -- EV_SEQUENCE_START --------------
      if (type == EV_SEQUENCE_START) {
         if (i && sequence.status!=STATUS_STARTING && sequence.status!=STATUS_STOPPED)   return(_false(catch("Sync.ProcessEvents(5)  illegal status event "+ StatusEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ TimeToStr(time, TIME_FULL) +") after "+ StatusEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(sequence.status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         if (sequence.status==STATUS_STARTING && reopenedPositions!=Abs(sequence.level)) return(_false(catch("Sync.ProcessEvents(6)  illegal status event "+ StatusEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ TimeToStr(time, TIME_FULL) +") after "+ StatusEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ TimeToStr(lastTime, TIME_FULL) +") and before "+ StatusEventToStr(nextType) +" ("+ nextId +", "+ ifString(nextTicket, "#"+ nextTicket +", ", "") +"time="+ nextTime +", "+ TimeToStr(nextTime, TIME_FULL) +") in "+ StatusToStr(sequence.status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         reopenedPositions = 0;
         sequence.status   = STATUS_PROGRESSING;
         sequence.start.event[index] = id;
      }
      // -- EV_GRIDBASE_CHANGE -------------
      else if (type == EV_GRIDBASE_CHANGE) {
         if (sequence.status!=STATUS_PROGRESSING && sequence.status!=STATUS_STOPPED)     return(_false(catch("Sync.ProcessEvents(7)  illegal status event "+ StatusEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ TimeToStr(time, TIME_FULL) +") after "+ StatusEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(sequence.status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         grid.base = gridBase;
         if (sequence.status == STATUS_PROGRESSING) {
            if (sequence.level != 0)                                                     return(_false(catch("Sync.ProcessEvents(8)  illegal status event "+ StatusEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ TimeToStr(time, TIME_FULL) +") after "+ StatusEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(sequence.status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         }
         else { // STATUS_STOPPED
            reopenedPositions = 0;
            sequence.status   = STATUS_STARTING;
         }
         grid.base.event[index] = id;
      }
      // -- EV_POSITION_OPEN ---------------
      else if (type == EV_POSITION_OPEN) {
         if (sequence.status!=STATUS_STARTING && sequence.status!=STATUS_PROGRESSING)    return(_false(catch("Sync.ProcessEvents(9)  illegal status event "+ StatusEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ TimeToStr(time, TIME_FULL) +") after "+ StatusEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(sequence.status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         if (sequence.status == STATUS_PROGRESSING) {                                    // nicht bei PositionReopen
            sequence.level   += Sign(orders.level[index]);
            sequence.maxLevel = ifInt(sequence.direction==D_LONG, Max(sequence.level, sequence.maxLevel), Min(sequence.level, sequence.maxLevel));
         }
         else {
            reopenedPositions++;
         }
         orders.openEvent[index] = id;
      }
      // -- EV_POSITION_STOPOUT ------------
      else if (type == EV_POSITION_STOPOUT) {
         if (sequence.status != STATUS_PROGRESSING)                                      return(_false(catch("Sync.ProcessEvents(10)  illegal status event "+ StatusEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ TimeToStr(time, TIME_FULL) +") after "+ StatusEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(sequence.status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         sequence.level  -= Sign(orders.level[index]);
         sequence.stops++;
         sequence.stopsPL = NormalizeDouble(sequence.stopsPL + orders.swap[index] + orders.commission[index] + orders.profit[index], 2);
         orders.closeEvent[index] = id;
      }
      // -- EV_POSITION_CLOSE --------------
      else if (type == EV_POSITION_CLOSE) {
         if (sequence.status!=STATUS_PROGRESSING && sequence.status!=STATUS_STOPPING)    return(_false(catch("Sync.ProcessEvents(11)  illegal status event "+ StatusEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ TimeToStr(time, TIME_FULL) +") after "+ StatusEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(sequence.status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         sequence.closedPL = NormalizeDouble(sequence.closedPL + orders.swap[index] + orders.commission[index] + orders.profit[index], 2);
         if (sequence.status == STATUS_PROGRESSING)
            closedPositions = 0;
         closedPositions++;
         sequence.status = STATUS_STOPPING;
         orders.closeEvent[index] = id;
      }
      // -- EV_SEQUENCE_STOP ---------------
      else if (type == EV_SEQUENCE_STOP) {
         if (sequence.status!=STATUS_PROGRESSING && sequence.status!=STATUS_STOPPING)    return(_false(catch("Sync.ProcessEvents(12)  illegal status event "+ StatusEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ TimeToStr(time, TIME_FULL) +") after "+ StatusEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(sequence.status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         if (closedPositions != Abs(sequence.level))                                     return(_false(catch("Sync.ProcessEvents(13)  illegal status event "+ StatusEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ TimeToStr(time, TIME_FULL) +") after "+ StatusEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ TimeToStr(lastTime, TIME_FULL) +") and before "+ StatusEventToStr(nextType) +" ("+ nextId +", "+ ifString(nextTicket, "#"+ nextTicket +", ", "") +"time="+ nextTime +", "+ TimeToStr(nextTime, TIME_FULL) +") in "+ StatusToStr(sequence.status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         closedPositions = 0;
         sequence.status = STATUS_STOPPED;
         sequence.stop.event[index] = id;
      }
      // -----------------------------------
      sequence.totalPL = NormalizeDouble(sequence.stopsPL + sequence.closedPL + sequence.floatingPL, 2);

      lastId     = id;
      lastTime   = time;
      lastType   = type;
      lastTicket = ticket;
   }
   lastEventId = id;


   // (4) Wurde die Sequenz außerhalb gestoppt, fehlende Stop-Daten ermitteln
   if (sequence.status == STATUS_STOPPING) {
      if (closedPositions != Abs(sequence.level)) return(_false(catch("Sync.ProcessEvents(14)  unexpected number of closed positions in "+ StatusDescription(sequence.status) +" sequence", ERR_RUNTIME_ERROR)));

      // (4.1) Stopdaten ermitteln
      int level = Abs(sequence.level);
      double stopPrice;
      for (i=sizeOfEvents-level; i < sizeOfEvents; i++) {
         time  = events[i][1];
         type  = events[i][2];
         index = events[i][4];
         if (type != EV_POSITION_CLOSE)
            return(_false(catch("Sync.ProcessEvents(15)  unexpected "+ StatusEventToStr(type) +" at index "+ i, ERR_RUNTIME_ERROR)));
         stopPrice += orders.closePrice[index];
      }
      stopPrice /= level;

      // (4.2) Stopdaten zurückgeben
      sequenceStopTime  = time;
      sequenceStopPrice = NormalizeDouble(stopPrice, Digits);
   }

   ArrayResize(events,      0);
   ArrayResize(orderEvents, 0);
   return(!catch("Sync.ProcessEvents(16)"));
}


/**
 * Redraw the sequence's start/stop marker.
 */
void RedrawStartStop() {
   if (!__CHART()) return;

   datetime time;
   double   price;
   double   profit;
   string   label;
   int starts = ArraySize(sequence.start.event);

   // start
   for (int i=0; i < starts; i++) {
      time   = sequence.start.time  [i];
      price  = sequence.start.price [i];
      profit = sequence.start.profit[i];

      label = "SR."+ sequence.id +".start."+ (i+1);
      if (ObjectFind(label) == 0)
         ObjectDelete(label);

      if (startStopDisplayMode != SDM_NONE) {
         ObjectCreate (label, OBJ_ARROW, 0, time, price);
         ObjectSet    (label, OBJPROP_ARROWCODE, startStopDisplayMode);
         ObjectSet    (label, OBJPROP_BACK,      false               );
         ObjectSet    (label, OBJPROP_COLOR,     Blue                );
         ObjectSetText(label, "Profit: "+ DoubleToStr(profit, 2));
      }
   }

   // stop
   for (i=0; i < starts; i++) {
      if (sequence.stop.time[i] > 0) {
         time   = sequence.stop.time [i];
         price  = sequence.stop.price[i];
         profit = sequence.stop.profit[i];

         label = "SR."+ sequence.id +".stop."+ (i+1);
         if (ObjectFind(label) == 0)
            ObjectDelete(label);

         if (startStopDisplayMode != SDM_NONE) {
            ObjectCreate (label, OBJ_ARROW, 0, time, price);
            ObjectSet    (label, OBJPROP_ARROWCODE, startStopDisplayMode);
            ObjectSet    (label, OBJPROP_BACK,      false               );
            ObjectSet    (label, OBJPROP_COLOR,     Blue                );
            ObjectSetText(label, "Profit: "+ DoubleToStr(profit, 2));
         }
      }
   }
   catch("RedrawStartStop(1)");
}


/**
 * Zeichnet die ChartMarker aller Orders neu.
 */
void RedrawOrders() {
   if (!__CHART()) return;

   bool wasPending, isPending, closedPosition;
   int  size = ArraySize(orders.ticket);

   for (int i=0; i < size; i++) {
      wasPending     = orders.pendingType[i] != OP_UNDEFINED;
      isPending      = orders.type[i] == OP_UNDEFINED;
      closedPosition = !isPending && orders.closeTime[i]!=0;

      if    (isPending)                         Chart.MarkOrderSent(i);
      else /*openPosition || closedPosition*/ {                                  // openPosition ist Folge einer
         if (wasPending)                        Chart.MarkOrderFilled(i);        // ...ausgeführten Pending-Order
         else                                   Chart.MarkOrderSent(i);          // ...oder Market-Order
         if (closedPosition)                    Chart.MarkPositionClosed(i);
      }
   }
}


/**
 * Wechselt den Modus der Start/Stopanzeige.
 *
 * @return int - Fehlerstatus
 */
int ToggleStartStopDisplayMode() {
   // Mode wechseln
   int i = SearchIntArray(startStopDisplayModes, startStopDisplayMode);    // #define SDM_NONE        - keine Anzeige -
   if (i == -1) {                                                          // #define SDM_PRICE       Markierung mit Preisangabe
      startStopDisplayMode = SDM_PRICE;           // default
   }
   else {
      int size = ArraySize(startStopDisplayModes);
      startStopDisplayMode = startStopDisplayModes[(i+1) % size];
   }

   // Anzeige aktualisieren
   RedrawStartStop();

   return(catch("ToggleStartStopDisplayMode()"));
}


/**
 * Wechselt den Modus der Orderanzeige.
 *
 * @return int - Fehlerstatus
 */
int ToggleOrderDisplayMode() {
   int pendings   = CountPendingOrders();
   int open       = CountOpenPositions();
   int stoppedOut = CountStoppedOutPositions();
   int closed     = CountClosedPositions();

   // Modus wechseln, dabei Modes ohne entsprechende Orders überspringen
   int oldMode      = orderDisplayMode;
   int size         = ArraySize(orderDisplayModes);
   orderDisplayMode = (orderDisplayMode+1) % size;

   while (orderDisplayMode != oldMode) {                                   // #define ODM_NONE        - keine Anzeige -
      if (orderDisplayMode == ODM_NONE) {                                  // #define ODM_STOPS       Pending,       StoppedOut
         break;                                                            // #define ODM_PYRAMID     Pending, Open,             Closed
      }                                                                    // #define ODM_ALL         Pending, Open, StoppedOut, Closed
      else if (orderDisplayMode == ODM_STOPS) {
         if (pendings+stoppedOut > 0)
            break;
      }
      else if (orderDisplayMode == ODM_PYRAMID) {
         if (pendings+open+closed > 0)
            if (open+stoppedOut+closed > 0)                                // ansonsten ist Anzeige identisch zu vorherigem Mode
               break;
      }
      else if (orderDisplayMode == ODM_ALL) {
         if (pendings+open+stoppedOut+closed > 0)
            if (stoppedOut > 0)                                            // ansonsten ist Anzeige identisch zu vorherigem Mode
               break;
      }
      orderDisplayMode = (orderDisplayMode+1) % size;
   }


   // Anzeige aktualisieren
   if (orderDisplayMode != oldMode) {
      RedrawOrders();
   }
   else {
      // nothing to change, Anzeige bleibt unverändert
      PlaySoundEx("Plonk.wav");
   }
   return(catch("ToggleOrderDisplayMode()"));
}


/**
 * Gibt die Anzahl der Pending-Orders der Sequenz zurück.
 *
 * @return int
 */
int CountPendingOrders() {
   int count, size=ArraySize(orders.ticket);

   for (int i=0; i < size; i++) {
      if (orders.type[i]==OP_UNDEFINED) /*&&*/ if (orders.closeTime[i]==0)
         count++;
   }
   return(count);
}


/**
 * Gibt die Anzahl der offenen Positionen der Sequenz zurück.
 *
 * @return int
 */
int CountOpenPositions() {
   int count, size=ArraySize(orders.ticket);

   for (int i=0; i < size; i++) {
      if (orders.type[i]!=OP_UNDEFINED) /*&&*/ if (orders.closeTime[i]==0)
         count++;
   }
   return(count);
}


/**
 * Gibt die Anzahl der ausgestoppten Positionen der Sequenz zurück.
 *
 * @return int
 */
int CountStoppedOutPositions() {
   int count, size=ArraySize(orders.ticket);

   for (int i=0; i < size; i++) {
      if (orders.closedBySL[i])
         count++;
   }
   return(count);
}


/**
 * Gibt die Anzahl der durch StopSequence() geschlossenen Positionen der Sequenz zurück.
 *
 * @return int
 */
int CountClosedPositions() {
   int count, size=ArraySize(orders.ticket);

   for (int i=0; i < size; i++) {
      if (orders.type[i]!=OP_UNDEFINED) /*&&*/ if (orders.closeTime[i]!=0) /*&&*/ if (!orders.closedBySL[i])
         count++;
   }
   return(count);
}


/**
 * Korrigiert die vom Terminal beim Abschicken einer Pending- oder Market-Order gesetzten oder nicht gesetzten Chart-Marker.
 *
 * @param  int i - Orderindex
 *
 * @return bool - success status
 */
bool Chart.MarkOrderSent(int i) {
   if (!__CHART()) return(true);
   /*
   #define ODM_NONE     0     // - keine Anzeige -
   #define ODM_STOPS    1     // Pending,       ClosedBySL
   #define ODM_PYRAMID  2     // Pending, Open,             Closed
   #define ODM_ALL      3     // Pending, Open, ClosedBySL, Closed
   */
   bool pending = orders.pendingType[i] != OP_UNDEFINED;

   int      type        =    ifInt(pending, orders.pendingType [i], orders.type     [i]);
   datetime openTime    =    ifInt(pending, orders.pendingTime [i], orders.openTime [i]);
   double   openPrice   = ifDouble(pending, orders.pendingPrice[i], orders.openPrice[i]);
   string   comment     = "SR."+ sequence.id +"."+ NumberToStr(orders.level[i], "+.");
   color    markerColor = CLR_NONE;

   if (orderDisplayMode != ODM_NONE) {
      if      (pending)                         markerColor = CLR_PENDING;
      else if (orderDisplayMode >= ODM_PYRAMID) markerColor = ifInt(IsLongOrderType(type), CLR_LONG, CLR_SHORT);
   }
   return(ChartMarker.OrderSent_B(orders.ticket[i], Digits, markerColor, type, LotSize, Symbol(), openTime, openPrice, orders.stopLoss[i], 0, comment));
}


/**
 * Korrigiert die vom Terminal beim Ausführen einer Pending-Order gesetzten oder nicht gesetzten Chart-Marker.
 *
 * @param  int i - Orderindex
 *
 * @return bool - success status
 */
bool Chart.MarkOrderFilled(int i) {
   if (!__CHART()) return(true);
   /*
   #define ODM_NONE     0     // - keine Anzeige -
   #define ODM_STOPS    1     // Pending,       ClosedBySL
   #define ODM_PYRAMID  2     // Pending, Open,             Closed
   #define ODM_ALL      3     // Pending, Open, ClosedBySL, Closed
   */
   string comment     = "SR."+ sequence.id +"."+ NumberToStr(orders.level[i], "+.");
   color  markerColor = CLR_NONE;

   if (orderDisplayMode >= ODM_PYRAMID)
      markerColor = ifInt(orders.type[i]==OP_BUY, CLR_LONG, CLR_SHORT);

   return(ChartMarker.OrderFilled_B(orders.ticket[i], orders.pendingType[i], orders.pendingPrice[i], Digits, markerColor, LotSize, Symbol(), orders.openTime[i], orders.openPrice[i], comment));
}


/**
 * Korrigiert den vom Terminal beim Schließen einer Position gesetzten oder nicht gesetzten Chart-Marker.
 *
 * @param  int i - Orderindex
 *
 * @return bool - success status
 */
bool Chart.MarkPositionClosed(int i) {
   if (!__CHART()) return(true);
   /*
   #define ODM_NONE     0     // - keine Anzeige -
   #define ODM_STOPS    1     // Pending,       ClosedBySL
   #define ODM_PYRAMID  2     // Pending, Open,             Closed
   #define ODM_ALL      3     // Pending, Open, ClosedBySL, Closed
   */
   color markerColor = CLR_NONE;

   if (orderDisplayMode != ODM_NONE) {
      if ( orders.closedBySL[i]) /*&&*/ if (orderDisplayMode != ODM_PYRAMID) markerColor = CLR_CLOSE;
      if (!orders.closedBySL[i]) /*&&*/ if (orderDisplayMode >= ODM_PYRAMID) markerColor = CLR_CLOSE;
   }
   return(ChartMarker.PositionClosed_B(orders.ticket[i], Digits, markerColor, orders.type[i], LotSize, Symbol(), orders.openTime[i], orders.openPrice[i], orders.closeTime[i], orders.closePrice[i]));
}


/**
 * Whether the current sequence was created in Strategy Tester and thus represents a test. Considers the fact that a test
 * sequence may be loaded in an online chart after the test (for visualization).
 *
 * @return bool
 */
bool IsTestSequence() {
   return(sequence.isTest || IsTesting());
}


/**
 * Setzt die Größe der Datenarrays auf den angegebenen Wert.
 *
 * @param  int  size  - neue Größe
 * @param  bool reset - ob die Arrays komplett zurückgesetzt werden sollen
 *                      (default: nur neu hinzugefügte Felder werden initialisiert)
 *
 * @return int - neue Größe der Arrays
 */
int ResizeArrays(int size, bool reset=false) {
   reset = reset!=0;

   int oldSize = ArraySize(orders.ticket);

   if (size != oldSize) {
      ArrayResize(orders.ticket,          size);
      ArrayResize(orders.level,           size);
      ArrayResize(orders.gridBase,        size);
      ArrayResize(orders.pendingType,     size);
      ArrayResize(orders.pendingTime,     size);
      ArrayResize(orders.pendingPrice,    size);
      ArrayResize(orders.type,            size);
      ArrayResize(orders.openEvent,       size);
      ArrayResize(orders.openTime,        size);
      ArrayResize(orders.openPrice,       size);
      ArrayResize(orders.closeEvent,      size);
      ArrayResize(orders.closeTime,       size);
      ArrayResize(orders.closePrice,      size);
      ArrayResize(orders.stopLoss,        size);
      ArrayResize(orders.clientsideLimit, size);
      ArrayResize(orders.closedBySL,      size);
      ArrayResize(orders.swap,            size);
      ArrayResize(orders.commission,      size);
      ArrayResize(orders.profit,          size);
   }

   if (reset) {                                                      // alle Felder zurücksetzen
      if (size != 0) {
         ArrayInitialize(orders.ticket,                 0);
         ArrayInitialize(orders.level,                  0);
         ArrayInitialize(orders.gridBase,               0);
         ArrayInitialize(orders.pendingType, OP_UNDEFINED);
         ArrayInitialize(orders.pendingTime,            0);
         ArrayInitialize(orders.pendingPrice,           0);
         ArrayInitialize(orders.type,        OP_UNDEFINED);
         ArrayInitialize(orders.openEvent,              0);
         ArrayInitialize(orders.openTime,               0);
         ArrayInitialize(orders.openPrice,              0);
         ArrayInitialize(orders.closeEvent,             0);
         ArrayInitialize(orders.closeTime,              0);
         ArrayInitialize(orders.closePrice,             0);
         ArrayInitialize(orders.stopLoss,               0);
         ArrayInitialize(orders.clientsideLimit,    false);
         ArrayInitialize(orders.closedBySL,         false);
         ArrayInitialize(orders.swap,                   0);
         ArrayInitialize(orders.commission,             0);
         ArrayInitialize(orders.profit,                 0);
      }
   }
   else {
      for (int i=oldSize; i < size; i++) {
         orders.pendingType[i] = OP_UNDEFINED;                       // Hinzugefügte pendingType- und type-Felder immer re-initialisieren,
         orders.type       [i] = OP_UNDEFINED;                       // 0 ist ein gültiger Wert und daher als Default unzulässig.
      }
   }
   return(size);
}


/**
 * Return a readable version of a status event identifier.
 *
 * @param  int event
 *
 * @return string
 */
string StatusEventToStr(int event) {
   switch (event) {
      case EV_SEQUENCE_START  : return("EV_SEQUENCE_START"  );
      case EV_SEQUENCE_STOP   : return("EV_SEQUENCE_STOP"   );
      case EV_GRIDBASE_CHANGE : return("EV_GRIDBASE_CHANGE" );
      case EV_POSITION_OPEN   : return("EV_POSITION_OPEN"   );
      case EV_POSITION_STOPOUT: return("EV_POSITION_STOPOUT");
      case EV_POSITION_CLOSE  : return("EV_POSITION_CLOSE"  );
   }
   return(_EMPTY_STR(catch("StatusEventToStr(1)  illegal parameter event = "+ event, ERR_INVALID_PARAMETER)));
}


/**
 * Generiert eine neue Sequenz-ID.
 *
 * @return int - Sequenz-ID im Bereich 1000-16383 (mindestens 4-stellig, maximal 14 bit)
 */
int CreateSequenceId() {
   MathSrand(GetTickCount());
   int id;                                               // TODO: Im Tester müssen fortlaufende IDs generiert werden.
   while (id < SID_MIN || id > SID_MAX) {
      id = MathRand();
   }
   return(id);                                           // TODO: ID auf Eindeutigkeit prüfen
}


/**
 * Holt eine Bestätigung für einen Trade-Request beim ersten Tick ein (um Programmfehlern vorzubeugen).
 *
 * @param  string location - Ort der Bestätigung
 * @param  string message  - Meldung
 *
 * @return bool - Ergebnis
 */
bool ConfirmFirstTickTrade(string location, string message) {
   static bool done, confirmed;
   if (!done) {
      if (Tick > 1 || IsTesting()) {
         confirmed = true;
      }
      else {
         PlaySoundEx("Windows Notify.wav");
         confirmed = (IDOK == MessageBoxEx(__NAME() + ifString(!StringLen(location), "", " - "+ location), ifString(IsDemoFix(), "", "- Real Account -\n\n") + message, MB_ICONQUESTION|MB_OKCANCEL));
         if (Tick > 0) RefreshRates();                   // bei Tick==0, also Aufruf in init(), ist RefreshRates() unnötig
      }
      done = true;
   }
   return(confirmed);
}


/**
 * Return a readable version of a sequence status code.
 *
 * @param  int status
 *
 * @return string
 */
string StatusToStr(int status) {
   switch (status) {
      case STATUS_UNDEFINED  : return("STATUS_UNDEFINED"  );
      case STATUS_WAITING    : return("STATUS_WAITING"    );
      case STATUS_STARTING   : return("STATUS_STARTING"   );
      case STATUS_PROGRESSING: return("STATUS_PROGRESSING");
      case STATUS_STOPPING   : return("STATUS_STOPPING"   );
      case STATUS_STOPPED    : return("STATUS_STOPPED"    );
   }
   return(_EMPTY_STR(catch("StatusToStr(1)  invalid parameter status = "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Return a description of a sequence status code.
 *
 * @param  int status
 *
 * @return string
 */
string StatusDescription(int status) {
   switch (status) {
      case STATUS_UNDEFINED  : return("undefined"  );
      case STATUS_WAITING    : return("waiting"    );
      case STATUS_STARTING   : return("starting"   );
      case STATUS_PROGRESSING: return("progressing");
      case STATUS_STOPPING   : return("stopping"   );
      case STATUS_STOPPED    : return("stopped"    );
   }
   return(_EMPTY_STR(catch("StatusDescription(1)  invalid parameter status = "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Ob der angegebene StopPrice erreicht wurde.
 *
 * @param  int    type  - stop or limit type: OP_BUY | OP_SELL | OP_BUYSTOP | OP_SELLSTOP | OP_BUYLIMIT | OP_SELLLIMIT
 * @param  double price - price
 *
 * @return bool
 */
bool IsStopTriggered(int type, double price) {
   if (type == OP_BUYSTOP )  return(Ask >= price);       // pending Buy Stop
   if (type == OP_SELLSTOP)  return(Bid <= price);       // pending Sell Stop

   if (type == OP_BUYLIMIT)  return(Ask <= price);       // pending Buy Limit
   if (type == OP_SELLLIMIT) return(Bid >= price);       // pending Sell Limit

   if (type == OP_BUY )      return(Bid <= price);       // stoploss Long
   if (type == OP_SELL)      return(Ask >= price);       // stoploss Short

   return(!catch("IsStopTriggered(1)  illegal parameter type = "+ type, ERR_INVALID_PARAMETER));

   // prevent compiler warnings
   datetime dNulls[];
   ReadTradeSessions(NULL, dNulls);
   ReadSessionBreaks(NULL, dNulls);
}


/**
 * Read the trade session configuration for the specified server time and copy it to the passed array.
 *
 * @param  _In_  datetime  time       - server time
 * @param  _Out_ datetime &config[][] - array receiving the trade session configuration
 *
 * @return bool - success status
 */
bool ReadTradeSessions(datetime time, datetime &config[][2]) {
   string section  = "TradeSessions";
   string symbol   = Symbol();
   string sDate    = TimeToStr(time, TIME_DATE);
   string sWeekday = GmtTimeFormat(time, "%A");
   string value;

   if      (IsConfigKey(section, symbol +"."+ sDate))    value = GetConfigString(section, symbol +"."+ sDate);
   else if (IsConfigKey(section, sDate))                 value = GetConfigString(section, sDate);
   else if (IsConfigKey(section, symbol +"."+ sWeekday)) value = GetConfigString(section, symbol +"."+ sWeekday);
   else if (IsConfigKey(section, sWeekday))              value = GetConfigString(section, sWeekday);
   else                                                  return(_false(debug("ReadTradeSessions(1)  no trade session configuration found")));

   // Monday    =                                  // no trade session
   // Tuesday   = 00:00-24:00                      // a full trade session
   // Wednesday = 01:02-20:00                      // a limited trade session
   // Thursday  = 03:00-12:10, 13:30-19:00         // multiple trade sessions

   ArrayResize(config, 0);
   if (value == "")
      return(true);

   string values[], sTimes[], sSession, sSessionStart, sSessionEnd;
   int sizeOfValues = Explode(value, ",", values, NULL);
   for (int i=0; i < sizeOfValues; i++) {
      sSession = StrTrim(values[i]);
      if (Explode(sSession, "-", sTimes, NULL) != 2) return(_false(catch("ReadTradeSessions(2)  illegal trade session configuration \""+ value +"\"", ERR_INVALID_CONFIG_VALUE)));
      sSessionStart = StrTrim(sTimes[0]);
      sSessionEnd   = StrTrim(sTimes[1]);
      debug("ReadTradeSessions(3)  start="+ sSessionStart +"  end="+ sSessionEnd);
   }
   return(true);
}


/**
 * Read the SnowRoller session break configuration for the specified server time and copy it to the passed array. SnowRoller
 * session breaks are symbol-specific. The configured times are applied session times, i.e. a session break will be enforced
 * if the current time is not in the configured time window.
 *
 * @param  _In_  datetime  time       - server time
 * @param  _Out_ datetime &config[][] - array receiving the session break configuration
 *
 * @return bool - success status
 */
bool ReadSessionBreaks(datetime time, datetime &config[][2]) {
   string section  = "SnowRoller.SessionBreaks";
   string symbol   = Symbol();
   string sDate    = TimeToStr(time, TIME_DATE);
   string sWeekday = GmtTimeFormat(time, "%A");
   string value;

   if      (IsConfigKey(section, symbol +"."+ sDate))    value = GetConfigString(section, symbol +"."+ sDate);
   else if (IsConfigKey(section, symbol +"."+ sWeekday)) value = GetConfigString(section, symbol +"."+ sWeekday);
   else                                                  return(_false(debug("ReadSessionBreaks(1)  no session break configuration found"))); // TODO: fall-back to auto-adjusted trade sessions

   // Tuesday   = 00:00-24:00                      // a full trade session:    no session breaks
   // Wednesday = 01:02-19:57                      // a limited trade session: session breaks before and after
   // Thursday  = 03:00-12:10, 13:30-19:00         // multiple trade sessions: session breaks before, after and in between
   // Saturday  =                                  // no trade session:        a 24 h session break
   // Sunday    =                                  //

   ArrayResize(config, 0);
   if (value == "")
      return(true);                                // TODO: fall-back to auto-adjusted trade sessions

   string   values[], sTimes[], sTime, sHours, sMinutes, sSession, sStartTime, sEndTime;
   datetime dStartTime, dEndTime, dSessionStart, dSessionEnd;
   int      sizeOfValues = Explode(value, ",", values, NULL), iHours, iMinutes;

   for (int i=0; i < sizeOfValues; i++) {
      sSession = StrTrim(values[i]);
      if (Explode(sSession, "-", sTimes, NULL) != 2) return(_false(catch("ReadSessionBreaks(2)  illegal session break configuration \""+ value +"\"", ERR_INVALID_CONFIG_VALUE)));

      sTime = StrTrim(sTimes[0]);
      if (StringLen(sTime) != 5)                     return(_false(catch("ReadSessionBreaks(3)  illegal session break configuration \""+ value +"\"", ERR_INVALID_CONFIG_VALUE)));
      if (StringGetChar(sTime, 2) != ':')            return(_false(catch("ReadSessionBreaks(4)  illegal session break configuration \""+ value +"\"", ERR_INVALID_CONFIG_VALUE)));
      sHours = StringSubstr(sTime, 0, 2);
      if (!StrIsDigit(sHours))                       return(_false(catch("ReadSessionBreaks(5)  illegal session break configuration \""+ value +"\"", ERR_INVALID_CONFIG_VALUE)));
      iHours = StrToInteger(sHours);
      if (iHours > 24)                               return(_false(catch("ReadSessionBreaks(6)  illegal session break configuration \""+ value +"\"", ERR_INVALID_CONFIG_VALUE)));
      sMinutes = StringSubstr(sTime, 3, 2);
      if (!StrIsDigit(sMinutes))                     return(_false(catch("ReadSessionBreaks(7)  illegal session break configuration \""+ value +"\"", ERR_INVALID_CONFIG_VALUE)));
      iMinutes = StrToInteger(sMinutes);
      if (iMinutes > 59)                             return(_false(catch("ReadSessionBreaks(8)  illegal session break configuration \""+ value +"\"", ERR_INVALID_CONFIG_VALUE)));
      dStartTime = DateTime(1970, 1, 1, iHours, iMinutes);

      sTime = StrTrim(sTimes[1]);
      if (StringLen(sTime) != 5)                     return(_false(catch("ReadSessionBreaks(9)  illegal session break configuration \""+ value +"\"", ERR_INVALID_CONFIG_VALUE)));
      if (StringGetChar(sTime, 2) != ':')            return(_false(catch("ReadSessionBreaks(10)  illegal session break configuration \""+ value +"\"", ERR_INVALID_CONFIG_VALUE)));
      sHours = StringSubstr(sTime, 0, 2);
      if (!StrIsDigit(sHours))                       return(_false(catch("ReadSessionBreaks(11)  illegal session break configuration \""+ value +"\"", ERR_INVALID_CONFIG_VALUE)));
      iHours = StrToInteger(sHours);
      if (iHours > 24)                               return(_false(catch("ReadSessionBreaks(12)  illegal session break configuration \""+ value +"\"", ERR_INVALID_CONFIG_VALUE)));
      sMinutes = StringSubstr(sTime, 3, 2);
      if (!StrIsDigit(sMinutes))                     return(_false(catch("ReadSessionBreaks(13)  illegal session break configuration \""+ value +"\"", ERR_INVALID_CONFIG_VALUE)));
      iMinutes = StrToInteger(sMinutes);
      if (iMinutes > 59)                             return(_false(catch("ReadSessionBreaks(14)  illegal session break configuration \""+ value +"\"", ERR_INVALID_CONFIG_VALUE)));
      dEndTime = DateTime(1970, 1, 1, iHours, iMinutes);

      debug("ReadSessionBreaks(15)  start="+ TimeToStr(dStartTime, TIME_FULL) +"  end="+ TimeToStr(dEndTime, TIME_FULL));
   }
   return(true);
}


/**
 * Update breakeven and profit targets.
 *
 * @return bool - success status
 */
bool UpdateProfitTargets() {
   if (IsLastError()) return(false);
   // 7bit:
   // double loss = currentPL - PotentialProfit(gridbaseDistance);
   // double be   = gridbase + RequiredDistance(loss);

   // calculate breakeven price (profit = losses)
   double price            = ifDouble(sequence.direction==D_LONG, Bid, Ask);
   double gridbaseDistance = MathAbs(price - grid.base)/Pip;
   double potentialProfit  = PotentialProfit(gridbaseDistance);
   double losses           = sequence.totalPL - potentialProfit;
   double beDistance       = RequiredDistance(MathAbs(losses));
   double bePrice          = grid.base + ifDouble(sequence.direction==D_LONG, beDistance, -beDistance)*Pip;
   sequence.breakeven      = NormalizeDouble(bePrice, Digits);
   //debug("UpdateProfitTargets(1)  level="+ sequence.level +"  gridbaseDist="+ DoubleToStr(gridbaseDistance, 1) +"  potential="+ DoubleToStr(potentialProfit, 2) +"  beDist="+ DoubleToStr(beDistance, 1) +" => "+ NumberToStr(bePrice, PriceFormat));

   // calculate TP price
   return(!catch("UpdateProfitTargets(2)"));
}


/**
 * Show the current profit targets.
 *
 * @return bool - success status
 */
bool ShowProfitTargets() {
   if (IsLastError())       return(false);
   if (!sequence.breakeven) return(true);

   datetime time = TimeCurrent(); time -= time % MINUTES;
   string label = "arrow_"+ time;
   double price = sequence.breakeven;

   if (ObjectFind(label) < 0) {
      ObjectCreate(label, OBJ_ARROW, 0, time, price);
   }
   else {
      ObjectSet(label, OBJPROP_TIME1,  time);
      ObjectSet(label, OBJPROP_PRICE1, price);
   }
   ObjectSet(label, OBJPROP_ARROWCODE, 4);
   ObjectSet(label, OBJPROP_SCALE,     1);
   ObjectSet(label, OBJPROP_COLOR,  Blue);
   ObjectSet(label, OBJPROP_BACK,   true);

   return(!catch("ShowProfitTargets(1)"));
}


/**
 * Calculate the theoretically possible maximum profit at the specified distance away from the gridbase. The calculation
 * assumes a perfect grid. It considers commissions but ignores missed grid levels and slippage.
 *
 * @param  double distance - distance from the gridbase in pip
 *
 * @return double - profit value
 */
double PotentialProfit(double distance) {
   // P = L * (L-1)/2 + partialP
   distance = NormalizeDouble(distance, 1);
   int    level = distance/GridSize;
   double partialLevel = MathModFix(distance/GridSize, 1);

   double units = (level-1)/2.*level + partialLevel*level;
   double unitSize = GridSize * PipValue(LotSize) + sequence.commission;

   double maxProfit = units * unitSize;
   if (partialLevel > 0) {
      maxProfit += (1-partialLevel)*level*sequence.commission;    // a partial level pays full commission
   }
   return(NormalizeDouble(maxProfit, 2));
}


/**
 * Calculate the minimum distance price has to move away from the gridbase to theoretically generate the specified floating
 * profit. The calculation assumes a perfect grid. It considers commissions but ignores missed grid levels and slippage.
 *
 * @param  double profit
 *
 * @return double - distance in pip
 */
double RequiredDistance(double profit) {
   // L = -0.5 + (0.25 + 2*units) ^ 1/2                           // quadratic equation solved with pq-formula
   double unitSize = GridSize * PipValue(LotSize) + sequence.commission;
   double units = MathAbs(profit)/unitSize;
   double level = MathPow(2*units + 0.25, 0.5) - 0.5;
   double distance = level * GridSize;
   return(RoundCeil(distance, 1));
}


/**
 * Return the trend value of a start condition's trend indicator.
 *
 * @param  int bar - bar index of the value to return
 *
 * @return int - trend value or NULL in case of errors
 */
int GetStartTrendValue(int bar) {
   if (start.trend.indicator == "alma"         ) return(GetALMA         (start.trend.timeframe, start.trend.params, MovingAverage.MODE_TREND, bar));
   if (start.trend.indicator == "movingaverage") return(GetMovingAverage(start.trend.timeframe, start.trend.params, MovingAverage.MODE_TREND, bar));
   if (start.trend.indicator == "nonlagma"     ) return(GetNonLagMA     (start.trend.timeframe, start.trend.params, MovingAverage.MODE_TREND, bar));
   if (start.trend.indicator == "triema"       ) return(GetTriEMA       (start.trend.timeframe, start.trend.params, MovingAverage.MODE_TREND, bar));
   if (start.trend.indicator == "halftrend"    ) return(GetHalfTrend    (start.trend.timeframe, start.trend.params, HalfTrend.MODE_TREND,     bar));
   if (start.trend.indicator == "supertrend"   ) return(GetSuperTrend   (start.trend.timeframe, start.trend.params, SuperTrend.MODE_TREND,    bar));

   return(!catch("GetStartTrendValue(1)  unsupported trend indicator "+ DoubleQuoteStr(StartConditions), ERR_INVALID_CONFIG_VALUE));
}


/**
 * Return the trend value of a stop condition's trend indicator.
 *
 * @param  int bar - bar index of the value to return
 *
 * @return int - trend value or NULL in case of errors
 */
int GetStopTrendValue(int bar) {
   if (stop.trend.indicator == "alma"         ) return(GetALMA         (stop.trend.timeframe, stop.trend.params, MovingAverage.MODE_TREND, bar));
   if (stop.trend.indicator == "movingaverage") return(GetMovingAverage(stop.trend.timeframe, stop.trend.params, MovingAverage.MODE_TREND, bar));
   if (stop.trend.indicator == "nonlagma"     ) return(GetNonLagMA     (stop.trend.timeframe, stop.trend.params, MovingAverage.MODE_TREND, bar));
   if (stop.trend.indicator == "triema"       ) return(GetTriEMA       (stop.trend.timeframe, stop.trend.params, MovingAverage.MODE_TREND, bar));
   if (stop.trend.indicator == "halftrend"    ) return(GetHalfTrend    (stop.trend.timeframe, stop.trend.params, HalfTrend.MODE_TREND,     bar));
   if (stop.trend.indicator == "supertrend"   ) return(GetSuperTrend   (stop.trend.timeframe, stop.trend.params, SuperTrend.MODE_TREND,    bar));

   return(!catch("GetStopTrendValue(1)  unsupported trend indicator "+ DoubleQuoteStr(StopConditions), ERR_INVALID_CONFIG_VALUE));
}


/**
 * Return an ALMA indicator value.
 *
 * @param  int    timeframe - timeframe to load the indicator (NULL: the current timeframe)
 * @param  string params    - additional comma-separated indicator parameters
 * @param  int    iBuffer   - buffer index of the value to return
 * @param  int    iBar      - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double GetALMA(int timeframe, string params, int iBuffer, int iBar) {
   if (!StringLen(params)) return(!catch("GetALMA(1)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));

   static int    maPeriods;
   static string maAppliedPrice;
   static double distributionOffset;
   static double distributionSigma;

   static string lastParams = "", elems[], sValue;
   if (params != lastParams) {
      if (Explode(params, ",", elems, NULL) != 4) return(!catch("GetALMA(2)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      sValue = StrTrim(elems[0]);
      if (!StrIsDigit(sValue))                    return(!catch("GetALMA(3)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      maPeriods = StrToInteger(sValue);
      sValue = StrTrim(elems[1]);
      if (!StringLen(sValue))                     return(!catch("GetALMA(4)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      maAppliedPrice = sValue;
      sValue = StrTrim(elems[2]);
      if (!StrIsNumeric(sValue))                  return(!catch("GetALMA(5)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      distributionOffset = StrToDouble(sValue);
      sValue = StrTrim(elems[3]);
      if (!StrIsNumeric(sValue))                  return(!catch("GetALMA(6)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      distributionSigma = StrToDouble(sValue);
      lastParams        = params;
   }
   return(icALMA(timeframe, maPeriods, maAppliedPrice, distributionOffset, distributionSigma, iBuffer, iBar));
}


/**
 * Return a Moving Average indicator value.
 *
 * @param  int    timeframe - timeframe to load the indicator (NULL: the current timeframe)
 * @param  string params    - additional comma-separated indicator parameters
 * @param  int    iBuffer   - buffer index of the value to return
 * @param  int    iBar      - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double GetMovingAverage(int timeframe, string params, int iBuffer, int iBar) {
   if (!StringLen(params)) return(!catch("GetMovingAverage(1)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));

   static int    maPeriods;
   static string maMethod;
   static string maAppliedPrice;

   static string lastParams = "", elems[], sValue;
   if (params != lastParams) {
      if (Explode(params, ",", elems, NULL) != 3) return(!catch("GetMovingAverage(2)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      sValue = StrTrim(elems[0]);
      if (!StrIsDigit(sValue))                    return(!catch("GetMovingAverage(3)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      maPeriods = StrToInteger(sValue);
      sValue = StrTrim(elems[1]);
      if (!StringLen(sValue))                     return(!catch("GetMovingAverage(4)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      maMethod = sValue;
      sValue = StrTrim(elems[2]);
      if (!StringLen(sValue))                     return(!catch("GetMovingAverage(5)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      maAppliedPrice = sValue;
      lastParams     = params;
   }
   return(icMovingAverage(timeframe, maPeriods, maMethod, maAppliedPrice, iBuffer, iBar));
}


/**
 * Return a NonLagMA indicator value.
 *
 * @param  int    timeframe - timeframe to load the indicator (NULL: the current timeframe)
 * @param  string params    - additional comma-separated indicator parameters
 * @param  int    iBuffer   - buffer index of the value to return
 * @param  int    iBar      - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double GetNonLagMA(int timeframe, string params, int iBuffer, int iBar) {
   if (!StringLen(params)) return(!catch("GetNonLagMA(1)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));

   static int cycleLength;

   static string lastParams = "";
   if (params != lastParams) {
      if (!StrIsDigit(params)) return(!catch("GetNonLagMA(2)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      cycleLength = StrToInteger(params);
      lastParams  = params;
   }
   return(icNonLagMA(timeframe, cycleLength, iBuffer, iBar));
}


/**
 * Return a TriEMA indicator value.
 *
 * @param  int    timeframe - timeframe to load the indicator (NULL: the current timeframe)
 * @param  string params    - additional comma-separated indicator parameters
 * @param  int    iBuffer   - buffer index of the value to return
 * @param  int    iBar      - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double GetTriEMA(int timeframe, string params, int iBuffer, int iBar) {
   if (!StringLen(params)) return(!catch("GetTriEMA(1)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));

   static int    maPeriods;
   static string maAppliedPrice;

   static string lastParams = "", elems[], sValue;
   if (params != lastParams) {
      if (Explode(params, ",", elems, NULL) != 2) return(!catch("GetTriEMA(2)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      sValue = StrTrim(elems[0]);
      if (!StrIsDigit(sValue))                    return(!catch("GetTriEMA(3)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      maPeriods = StrToInteger(sValue);
      sValue = StrTrim(elems[1]);
      if (!StringLen(sValue))                     return(!catch("GetTriEMA(4)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      maAppliedPrice = sValue;
      lastParams     = params;
   }
   return(icTriEMA(timeframe, maPeriods, maAppliedPrice, iBuffer, iBar));
}


/**
 * Return a HalfTrend indicator value.
 *
 * @param  int    timeframe - timeframe to load the indicator (NULL: the current timeframe)
 * @param  string params    - additional comma-separated indicator parameters
 * @param  int    iBuffer   - buffer index of the value to return
 * @param  int    iBar      - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double GetHalfTrend(int timeframe, string params, int iBuffer, int iBar) {
   if (!StringLen(params)) return(!catch("GetHalfTrend(1)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));

   static int periods;

   static string lastParams = "";
   if (params != lastParams) {
      if (!StrIsDigit(params)) return(!catch("GetHalfTrend(2)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      periods    = StrToInteger(params);
      lastParams = params;
   }
   return(icHalfTrend(timeframe, periods, iBuffer, iBar));
}


/**
 * Return a SuperTrend indicator value.
 *
 * @param  int    timeframe - timeframe to load the indicator (NULL: the current timeframe)
 * @param  string params    - additional comma-separated indicator parameters
 * @param  int    iBuffer   - buffer index of the value to return
 * @param  int    iBar      - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double GetSuperTrend(int timeframe, string params, int iBuffer, int iBar) {
   if (!StringLen(params)) return(!catch("GetSuperTrend(1)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));

   static int atrPeriods;
   static int smaPeriods;

   static string lastParams = "", elems[], sValue;
   if (params != lastParams) {
      if (Explode(params, ",", elems, NULL) != 2) return(!catch("GetSuperTrend(2)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      sValue = StrTrim(elems[0]);
      if (!StrIsDigit(sValue))                    return(!catch("GetSuperTrend(3)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      atrPeriods = StrToInteger(sValue);
      sValue = StrTrim(elems[1]);
      if (!StrIsDigit(sValue))                    return(!catch("GetSuperTrend(4)  invalid parameter params: "+ DoubleQuoteStr(params), ERR_INVALID_PARAMETER));
      smaPeriods = StrToInteger(sValue);
      lastParams = params;
   }
   return(icSuperTrend(timeframe, atrPeriods, smaPeriods, iBuffer, iBar));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Sequence.ID=",            DoubleQuoteStr(Sequence.ID),                  ";", NL,
                            "GridDirection=",          DoubleQuoteStr(GridDirection),                ";", NL,
                            "GridSize=",               GridSize,                                     ";", NL,
                            "LotSize=",                NumberToStr(LotSize, ".1+"),                  ";", NL,
                            "StartLevel=",             StartLevel,                                   ";", NL,
                            "StartConditions=",        DoubleQuoteStr(StartConditions),              ";", NL,
                            "StopConditions=",         DoubleQuoteStr(StopConditions),               ";", NL,
                            "AutoResume=",             BoolToStr(AutoResume),                        ";", NL,
                            "Sessionbreak.StartTime=", TimeToStr(Sessionbreak.StartTime, TIME_FULL), ";", NL,
                            "Sessionbreak.EndTime=",   TimeToStr(Sessionbreak.EndTime, TIME_FULL),   ";", NL,
                            "ShowProfitInPercent=",    BoolToStr(ShowProfitInPercent),               ";")
   );
}


/*
  Actions, events and status changes:
 +------------------+---------------------+--------------------+
 | Action           |       Events        |        Status      |
 +------------------+---------------------+--------------------+
 | EA::init()       |         -           | STATUS_UNDEFINED   |
 +------------------+---------------------+--------------------+
 | EA::start()      |         -           | STATUS_WAITING     |
 |                  |                     |                    |
 | StartSequence()  | EV_SEQUENCE_START   | STATUS_PROGRESSING |
 |                  |                     |                    |
 | TrailGridbase    | EV_GRIDBASE_CHANGE  | STATUS_PROGRESSING |
 |                  |                     |                    |
 | OrderFilled      | EV_POSITION_OPEN    | STATUS_PROGRESSING |
 |                  |                     |                    |
 | OrderStoppedOut  | EV_POSITION_STOPOUT | STATUS_PROGRESSING |
 |                  |                     |                    |
 | TrailGridbase    | EV_GRIDBASE_CHANGE  | STATUS_PROGRESSING |
 |                  |                     |                    |
 | StopSequence()   |         -           | STATUS_STOPPING    |
 | PositionClose    | EV_POSITION_CLOSE   | STATUS_STOPPING    |
 |                  | EV_SEQUENCE_STOP    | STATUS_STOPPED     |
 +------------------+---------------------+--------------------+
 | StartCondition   |         -           | STATUS_WAITING     |
 |                  |                     |                    |
 | ResumeSequence() |         -           | STATUS_STARTING    |
 | UpdateGridbase   | EV_GRIDBASE_CHANGE  | STATUS_STARTING    |
 | PositionOpen     | EV_POSITION_OPEN    | STATUS_STARTING    |
 |                  | EV_SEQUENCE_START   | STATUS_PROGRESSING |
 |                  |                     |                    |
 | OrderFilled      | EV_POSITION_OPEN    | STATUS_PROGRESSING |
 |                  |                     |                    |
 | OrderStoppedOut  | EV_POSITION_STOPOUT | STATUS_PROGRESSING |
 |                  |                     |                    |
 | TrailGridbase    | EV_GRIDBASE_CHANGE  | STATUS_PROGRESSING |
 | ...              |                     |                    |
 +------------------+---------------------+--------------------+
*/
