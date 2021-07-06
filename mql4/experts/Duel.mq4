/**
 * Duel: A bi-directional grid with optional pyramiding, martingale or reverse-martingale position sizing.
 *
 *  Eye to eye stand winners and losers
 *  Hurt by envy, cut by greed
 *  Face to face with their own disillusions
 *  The scars of old romances still on their cheeks
 *
 *  The first cut won't hurt at all
 *  The second only makes you wonder
 *  The third will have you on your knees
 *
 *
 * - If both multipliers are "0" the EA trades like a single-position system (no grid).
 * - If "Pyramid.Multiplier" is between "0" and "1" the EA trades on the winning side like a regular pyramiding system.
 * - If "Pyramid.Multiplier" is greater than "1" the EA trades on the winning side like a reverse-martingale system.
 * - If "Martingale.Multiplier" is greater than "0" the EA trades on the losing side like a regular martingale system.
 *
 * @link  https://www.youtube.com/watch?v=-ZryHMdvfJU#                                                             [The Grid]
 * @link  https://www.youtube.com/watch?v=NTM_apWWcO0#                       [Duel (I've looked at life from both sides now)]
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string   Sequence.ID            = "";                      // instance to load from a file, format /T?1[0-9]{3}/

extern string   GridDirection          = "Long | Short | Both*";
extern string   GridVolatility         = "{percent}";             // drawdown on a full ADR move to the losing side
extern double   GridSize               = 0;                       // in pip
extern double   UnitSize               = 0;                       // lots at the first grid level

extern double   Pyramid.Multiplier     = 1;                       // unitsize multiplier per grid level on the winning side
extern double   Martingale.Multiplier  = 0;                       // unitsize multiplier per grid level on the losing side

extern string   TakeProfit             = "{number}[%]";           // TP as absolute or percentage equity value
extern string   StopLoss               = "{number}[%]";           // SL as absolute or percentage equity value
extern bool     ShowProfitInPercent    = false;                   // whether PL is displayed as absolute or percentage value

extern datetime Sessionbreak.StartTime = D'1970.01.01 23:56:00';  // server time, the date part is ignored
extern datetime Sessionbreak.EndTime   = D'1970.01.01 00:02:10';  // server time, the date part is ignored

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define STRATEGY_ID         105                    // unique strategy id from 101-1023 (10 bit)

#define STATUS_UNDEFINED      0                    // sequence status values
#define STATUS_WAITING        1
#define STATUS_PROGRESSING    2
#define STATUS_STOPPED        3

#define SIGNAL_PRICETIME      1                    // a price and/or time condition
#define SIGNAL_TREND          2
#define SIGNAL_TAKEPROFIT     3
#define SIGNAL_STOPLOSS       4
#define SIGNAL_SESSION_BREAK  5

#define D_LONG                TRADE_DIRECTION_LONG
#define D_SHORT               TRADE_DIRECTION_SHORT
#define D_BOTH                TRADE_DIRECTION_BOTH

#define CLR_PENDING           DeepSkyBlue          // order marker colors
#define CLR_LONG              C'0,0,254'           // blue-ish: rgb(0,0,255) - rgb(1,1,1)
#define CLR_SHORT             C'254,0,0'           // red-ish:  rgb(255,0,0) - rgb(1,1,1)
#define CLR_CLOSE             Orange               //
                                                   //
// sequence data                                   //
int      sequence.id;                              //
datetime sequence.created;                         //
bool     sequence.isTest;                          // whether the sequence is a test (e.g. loaded into an online chart)
string   sequence.name = "";                       // "[LS].{sequence.id}"
int      sequence.status;                          //
int      sequence.direction;                       //
bool     sequence.pyramidEnabled;                  // whether the sequence scales in on the winning side (pyramid)
bool     sequence.martingaleEnabled;               // whether the sequence scales in on the losing side (martingale)
double   sequence.startEquity;                     //
double   sequence.gridvola;                        //
double   sequence.gridsize;                        //
double   sequence.unitsize;                        // lots at the first level
double   sequence.gridbase;                        //
double   sequence.openLots;                        // total open lots: long.openLots - short.openLots
double   sequence.hedgedPL;                        // P/L of the hedged open positions
double   sequence.floatingPL;                      // P/L of the floating open positions
double   sequence.openPL;                          // P/L of all open positions: hedgedPL + floatingPL
double   sequence.closedPL;                        // P/L of all closed positions
double   sequence.totalPL;                         // total P/L of the sequence: openPL + closedPL
double   sequence.maxProfit;                       // max. observed total sequence profit:   0...+n
double   sequence.maxDrawdown;                     // max. observed total sequence drawdown: -n...0
double   sequence.bePrice.long;                    //
double   sequence.bePrice.short;                   //
double   sequence.tpPrice;                         //
double   sequence.slPrice;                         //
                                                   //
// order management
bool     long.enabled;
int      long.ticket      [];                      // records are ordered ascending by grid level
int      long.level       [];                      // grid level: -n...-1 | +1...+n
double   long.lots        [];
int      long.pendingType [];
datetime long.pendingTime [];
double   long.pendingPrice[];                      // price of the grid level
int      long.type        [];
datetime long.openTime    [];
double   long.openPrice   [];
datetime long.closeTime   [];
double   long.closePrice  [];
double   long.swap        [];
double   long.commission  [];
double   long.profit      [];
double   long.slippage;                            // overall ippage of the long side
double   long.openLots;                            // total open long lots: 0...+n
double   long.openPL;
double   long.closedPL;
int      long.minLevel = INT_MAX;                  // lowest reached grid level
int      long.maxLevel = INT_MIN;                  // highest reached grid level

bool     short.enabled;
int      short.ticket      [];                     // records are ordered ascending by grid level
int      short.level       [];                     // grid level: -n...-1 | +1...+n
double   short.lots        [];
int      short.pendingType [];
datetime short.pendingTime [];
double   short.pendingPrice[];                     // price of the grid level
int      short.type        [];
datetime short.openTime    [];
double   short.openPrice   [];
datetime short.closeTime   [];
double   short.closePrice  [];
double   short.swap        [];
double   short.commission  [];
double   short.profit      [];
double   short.slippage;                           // overall slippage of the short side
double   short.openLots;                           // total open short lots: 0...+n
double   short.openPL;
double   short.closedPL;
int      short.minLevel = INT_MAX;
int      short.maxLevel = INT_MIN;

// takeprofit conditions
bool     tpAbs.condition;                          // whether an absolute TP condition is active
double   tpAbs.value;
string   tpAbs.description = "";

bool     tpPct.condition;                          // whether a percentage TP condition is active
double   tpPct.value;
double   tpPct.absValue    = INT_MAX;
string   tpPct.description = "";

// stoploss conditions
bool     slAbs.condition;                          // whether an absolute SL condition is active
double   slAbs.value;
string   slAbs.description = "";

bool     slPct.condition;                          // whether a percentage SL condition is active
double   slPct.value;
double   slPct.absValue    = INT_MIN;
string   slPct.description = "";

// sessionbreak management
datetime sessionbreak.starttime;                   // configurable via inputs and framework config
datetime sessionbreak.endtime;

// cache vars to speed-up ShowStatus()
string   sGridParameters  = "";
string   sGridVolatility  = "";
string   sStopConditions  = "";
string   sOpenLongLots    = "";
string   sOpenShortLots   = "";
string   sOpenTotalLots   = "";
string   sSequenceTotalPL = "";
string   sSequencePlStats = "";
string   sSequenceBePrice = "";
string   sSequenceTpPrice = "";
string   sSequenceSlPrice = "";

// debug settings                                  // configurable via framework config, see afterInit()
bool     test.onStopPause        = false;          // whether to pause a test after StopSequence()
bool     test.reduceStatusWrites = true;           // whether to minimize status file writing in tester

#include <apps/duel/init.mqh>
#include <apps/duel/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   int signal;
   if (__isChart) HandleCommands();                            // process chart commands

   if (sequence.status == STATUS_WAITING) {
      if (IsStartSignal(signal)) StartSequence(signal);
   }
   else if (sequence.status == STATUS_PROGRESSING) {           // manage a running sequence
      bool gridChanged=false, gridError=false;                 // whether the current gridlevel changed or a grid error occurred

      if (UpdateStatus(gridChanged, gridError)) {              // check pending orders and open positions
         if      (gridError)            StopSequence(NULL);
         else if (IsStopSignal(signal)) StopSequence(signal);
         else if (gridChanged)          UpdatePendingOrders(true);
      }
   }
   else if (sequence.status == STATUS_STOPPED) {
   }

   return(catch("onTick(1)"));

   // dummy call
   MakeScreenshot();
}


/**
 * Whether a chart command was sent to the EA. If the case, the command is retrieved and returned.
 *
 * @param  _Out_ string &commands[] - array to store received commands
 *
 * @return bool
 */
bool EventListener_ChartCommand(string &commands[]) {
   if (!__isChart) return(false);

   static string label, mutex; if (!StringLen(label)) {
      label = ProgramName() +".command";
      mutex = "mutex."+ label;
   }

   // check for existing commands in a non-synchronized way (read-only) to prevent aquiring the lock on every tick
   if (ObjectFind(label) == 0) {
      if (AquireLock(mutex, true)) {                                 // now aquire the lock (read-write)
         ArrayPushString(commands, ObjectDescription(label));
         ObjectDelete(label);
         return(ReleaseLock(mutex));
      }
   }
   return(false);
}


/**
 * Dispatch incoming commands.
 *
 * @param  string commands[] - received commands
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string commands[]) {
   if (!ArraySize(commands)) return(!logWarn("onCommand(1)  "+ sequence.name +" empty parameter commands: {}"));
   string cmd = commands[0];
   if (IsLogInfo()) logInfo("onCommand(2)  "+ sequence.name +" "+ DoubleQuoteStr(cmd));

   if (cmd == "start") {
      switch (sequence.status) {
         case STATUS_WAITING:
            return(StartSequence(NULL));
      }
   }
   else if (cmd == "stop") {
      switch (sequence.status) {
         case STATUS_WAITING:
         case STATUS_PROGRESSING:
            return(StopSequence(NULL));
      }
   }
   else return(_true(logWarn("onCommand(3)  "+ sequence.name +" unsupported command: "+ DoubleQuoteStr(cmd))));

   return(_true(logWarn("onCommand(4)  "+ sequence.name +" cannot execute "+ DoubleQuoteStr(cmd) +" command in "+ StatusToStr(sequence.status))));
}


/**
 * Whether a start condition is satisfied for a waiting sequence.
 *
 * @param  _Out_ int &signal - variable receiving the signal identifier of the fulfilled start condition
 *
 * @return bool
 */
bool IsStartSignal(int &signal) {
   signal = NULL;
   if (last_error || sequence.status!=STATUS_WAITING) return(false);

   if (IsSessionBreak()) {
      return(false);
   }

   if (IsTesting()) {
      // tester: auto-start
      if (!ArraySize(long.ticket) && !ArraySize(short.ticket)) return(true);
   }
   else {
      // online: not yet supported for this EA
   }
   return(false);
}


/**
 * Whether a stop condition is satisfied for a progressing sequence.
 *
 * @param  _Out_ int &signal - variable receiving the signal identifier of the fulfilled stop condition
 *
 * @return bool
 */
bool IsStopSignal(int &signal) {
   signal = NULL;
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("IsStopSignal(1)  "+ sequence.name +" cannot check stop signal of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   string message = "";

   // -- absolute TP --------------------------------------------------------------------------------------------------------
   if (tpAbs.condition) {
      if (sequence.totalPL >= tpAbs.value) {
         if (IsLogNotice()) logNotice("IsStopSignal(2)  "+ sequence.name +" stop condition \"@"+ tpAbs.description +"\" fulfilled (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         tpAbs.condition = false;
         signal = SIGNAL_TAKEPROFIT;
         return(true);
      }
   }

   // -- percentage TP ------------------------------------------------------------------------------------------------------
   if (tpPct.condition) {
      if (tpPct.absValue == INT_MAX) {
         tpPct.absValue = tpPct.value/100 * sequence.startEquity;
      }
      if (sequence.totalPL >= tpPct.absValue) {
         if (IsLogNotice()) logNotice("IsStopSignal(3)  "+ sequence.name +" stop condition \"@"+ tpPct.description +"\" fulfilled (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         tpPct.condition = false;
         signal = SIGNAL_TAKEPROFIT;
         return(true);
      }
   }

   // -- absolute SL --------------------------------------------------------------------------------------------------------
   if (slAbs.condition) {
      if (sequence.totalPL <= slAbs.value) {
         if (IsLogNotice()) logNotice("IsStopSignal(4)  "+ sequence.name +" stop condition \"@"+ slAbs.description +"\" fulfilled (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         slAbs.condition = false;
         signal = SIGNAL_STOPLOSS;
         return(true);
      }
   }

   // -- percentage SL ------------------------------------------------------------------------------------------------------
   if (slPct.condition) {
      if (slPct.absValue == INT_MIN) {
         slPct.absValue = slPct.value/100 * sequence.startEquity;
      }

      if (sequence.totalPL <= slPct.absValue) {
         if (IsLogNotice()) logNotice("IsStopSignal(5)  "+ sequence.name +" stop condition \"@"+ slPct.description +"\" fulfilled (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         slPct.condition = false;
         signal = SIGNAL_STOPLOSS;
         return(true);
      }
   }

   return(false);
}


/**
 * Whether the current server time falls into a sessionbreak. After function return the global vars sessionbreak.starttime
 * and sessionbreak.endtime are up-to-date.
 *
 * @return bool
 */
bool IsSessionBreak() {
   if (IsLastError()) return(false);

   datetime serverTime = Max(TimeCurrentEx(), TimeServer());

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
      int dow = TimeDayOfWeekEx(fxtTime);
      while (fxtTime <= fxtNow || dow==SATURDAY || dow==SUNDAY) {
         fxtTime += 1*DAY;
         dow = TimeDayOfWeekEx(fxtTime);
      }
      datetime fxtResumeTime = fxtTime;
      sessionbreak.endtime = FxtToServerTime(fxtResumeTime);

      // determine the corresponding sessionbreak start time
      datetime resumeDay = fxtResumeTime - fxtResumeTime%DAYS;    // resume day's Midnight in FXT
      fxtTime = resumeDay + startOffset;                          // resume day's sessionbreak start time in FXT

      dow = TimeDayOfWeekEx(fxtTime);
      while (fxtTime >= fxtResumeTime || dow==SATURDAY || dow==SUNDAY) {
         fxtTime -= 1*DAY;
         dow = TimeDayOfWeekEx(fxtTime);
      }
      sessionbreak.starttime = FxtToServerTime(fxtTime);

      if (IsLogDebug()) logDebug("IsSessionBreak(1)  "+ sequence.name +" recalculated "+ ifString(serverTime >= sessionbreak.starttime, "current", "next") +" sessionbreak: from "+ GmtTimeFormat(sessionbreak.starttime, "%a, %Y.%m.%d %H:%M:%S") +" to "+ GmtTimeFormat(sessionbreak.endtime, "%a, %Y.%m.%d %H:%M:%S"));
   }

   // perform the actual check
   return(serverTime >= sessionbreak.starttime);                  // here sessionbreak.endtime is always in the future
}


/**
 * Start the trade sequence. When called all previous sequence data was reset.
 *
 * @param  int signal - signal which triggered a start condition or NULL if no condition was triggered (manual start)
 *
 * @return bool - success status
 */
bool StartSequence(int signal) {
   if (sequence.status != STATUS_WAITING) return(!catch("StartSequence(1)  "+ sequence.name +" cannot start "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (IsLogDebug()) logDebug("StartSequence(2)  "+ sequence.name +" starting sequence...");

   if      (sequence.direction == D_LONG)  sequence.gridbase = Ask;
   else if (sequence.direction == D_SHORT) sequence.gridbase = Bid;
   else                                    sequence.gridbase = NormalizeDouble((Bid+Ask)/2, Digits);

   sequence.startEquity = NormalizeDouble(AccountEquity() - AccountCredit() + GetExternalAssets(), 2);
   sequence.status      = STATUS_PROGRESSING;
   int idxLong=-1, idxShort=-1;

   if (long.enabled) {
      idxLong = Grid.AddPosition(D_LONG, 1);          // open a long position for level 1
      if (idxLong < 0) return(false);
   }
   if (short.enabled) {
      idxShort = Grid.AddPosition(D_SHORT, 1);        // open a short position for level 1
      if (idxShort < 0) return(false);
   }

   // update the gridbase according to the realized price (slippage)
   if      (sequence.direction == D_LONG)  sequence.gridbase = long.openPrice [idxLong ];
   else if (sequence.direction == D_SHORT) sequence.gridbase = short.openPrice[idxShort];
   else                                    sequence.gridbase = NormalizeDouble((long.openPrice[idxLong]+short.openPrice[idxShort])/2, Digits);

   sequence.openLots = NormalizeDouble(long.openLots - short.openLots, 2); SS.OpenLots();

   if (!UpdatePendingOrders()) return(false);         // update pending orders
   if (IsLogInfo()) logInfo("StartSequence(3)  "+ sequence.name +" sequence started (gridbase "+ NumberToStr(sequence.gridbase, PriceFormat) +")");

   ComputeProfit(true);
   return(SaveStatus());
}


/**
 * Close open positions, delete pending orders and stop the sequence.
 *
 * @param  int signal - signal which triggered the stop condition or NULL if no condition was triggered (explicit/manual stop)
 *
 * @return bool - success status
 */
bool StopSequence(int signal) {
   if (IsLastError())                                                          return(false);
   if (sequence.status!=STATUS_WAITING && sequence.status!=STATUS_PROGRESSING) return(!catch("StopSequence(1)  "+ sequence.name +" cannot stop "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   if (sequence.status == STATUS_PROGRESSING) {                      // a progressing sequence has open orders to close (a waiting sequence has none)
      if (IsLogDebug()) logDebug("StopSequence(2)  "+ sequence.name +" stopping sequence...");
      int hedgeTicket, oe[];

      if (NE(sequence.openLots, 0)) {                                // hedge the total open position: execution price = sequence close price
         int      type        = ifInt(GT(sequence.openLots, 0), OP_SELL, OP_BUY);
         double   lots        = MathAbs(sequence.openLots);
         double   price       = NULL;
         int      slippage    = 10;                                  // point
         double   stopLoss    = NULL;
         double   takeProfit  = NULL;
         string   comment     = "";
         int      magicNumber = CreateMagicNumber();
         datetime expires     = NULL;
         color    markerColor = CLR_NONE;
         int      oeFlags     = NULL;
         if (!OrderSendEx(Symbol(), type, lots, price, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));
         hedgeTicket = oe.Ticket(oe);
      }

      if (!Grid.RemovePendingOrders()) return(false);                // cancel and remove all pending orders

      if (!StopSequence.ClosePositions(hedgeTicket)) return(false);  // close all open and the hedging position

      sequence.openPL   = 0;                                         // update total PL numbers
      sequence.closedPL = long.closedPL + short.closedPL;
      sequence.totalPL  = NormalizeDouble(sequence.openPL + sequence.closedPL, 2);
      if      (sequence.totalPL > sequence.maxProfit  ) sequence.maxProfit   = sequence.totalPL;
      else if (sequence.totalPL < sequence.maxDrawdown) sequence.maxDrawdown = sequence.totalPL;
      SS.TotalPL(true);
      SS.PLStats(true);
   }

   sequence.status = STATUS_STOPPED;
   SS.StopConditions();
   if (IsLogInfo()) logInfo("StopSequence(3)  "+ sequence.name +" sequence stopped, profit: "+ sSequenceTotalPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   SaveStatus();

   if (IsTesting()) {                                                // pause or stop the tester according to the debug configuration
      if (!IsVisualMode())       Tester.Stop("StopSequence(4)");
      else if (test.onStopPause) Tester.Pause("StopSequence(5)");
   }
   return(!catch("StopSequence(6)"));
}


/**
 * Close all open positions.
 *
 * @param  int hedgeTicket - ticket of the hedging close ticket or NULL if the total position was already hedged
 *
 * @return bool - success status
 */
bool StopSequence.ClosePositions(int hedgeTicket) {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("StopSequence.ClosePositions(1)  "+ sequence.name +" cannot close open positions of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   // collect all open positions
   int lastLongPosition=-1, lastShortPosition=-1, positions[]; ArrayResize(positions, 0);

   if (long.enabled) {
      int orders = ArraySize(long.ticket);
      for (int i=0; i < orders; i++) {
         if (!long.closeTime[i] && long.type[i]!=OP_UNDEFINED) {
            ArrayPushInt(positions, long.ticket[i]);
         }
      }
      lastLongPosition = orders - 1;
   }
   if (short.enabled) {
      orders = ArraySize(short.ticket);
      for (i=0; i < orders; i++) {
         if (!short.closeTime[i] && short.type[i]!=OP_UNDEFINED) {
            ArrayPushInt(positions, short.ticket[i]);
         }
      }
      lastShortPosition = orders - 1;
   }
   if (hedgeTicket != NULL) {
      ArrayPushInt(positions, hedgeTicket);
   }

   // close open positions and update local order state
   if (ArraySize(positions) > 0) {
      int slippage = 10;    // point
      int oeFlags, oes[][ORDER_EXECUTION.intSize], pos;
      if (!OrdersClose(positions, slippage, CLR_CLOSE, oeFlags, oes)) return(!SetLastError(oes.Error(oes, 0)));

      double remainingSwap, remainingCommission, remainingProfit;
      orders = ArrayRange(oes, 0);

      for (i=0; i < orders; i++) {
         if (oes.Type(oes, i) == OP_BUY) {
            pos = SearchIntArray(long.ticket, oes.Ticket(oes, i));
            if (pos >= 0) {
               long.closeTime [pos] = oes.CloseTime (oes, i);
               long.closePrice[pos] = oes.ClosePrice(oes, i);
               long.swap      [pos] = oes.Swap      (oes, i);
               long.commission[pos] = oes.Commission(oes, i);
               long.profit    [pos] = oes.Profit    (oes, i);
               long.closedPL += long.swap[pos] + long.commission[pos] + long.profit[pos];
            }
            else {
               remainingSwap       += oes.Swap      (oes, i);
               remainingCommission += oes.Commission(oes, i);
               remainingProfit     += oes.Profit    (oes, i);
            }
         }
         else {
            pos = SearchIntArray(short.ticket, oes.Ticket(oes, i));
            if (pos >= 0) {
               short.closeTime [pos] = oes.CloseTime (oes, i);
               short.closePrice[pos] = oes.ClosePrice(oes, i);
               short.swap      [pos] = oes.Swap      (oes, i);
               short.commission[pos] = oes.Commission(oes, i);
               short.profit    [pos] = oes.Profit    (oes, i);
               short.closedPL += short.swap[pos] + short.commission[pos] + short.profit[pos];
            }
            else {
               remainingSwap       += oes.Swap      (oes, i);
               remainingCommission += oes.Commission(oes, i);
               remainingProfit     += oes.Profit    (oes, i);
            }
         }
      }

      if (lastLongPosition >= 0) {
         long.swap      [lastLongPosition] += remainingSwap;
         long.commission[lastLongPosition] += remainingCommission;
         long.profit    [lastLongPosition] += remainingProfit;
         long.closedPL += remainingSwap + remainingCommission + remainingProfit;
      }
      else {
         short.swap      [lastShortPosition] += remainingSwap;
         short.commission[lastShortPosition] += remainingCommission;
         short.profit    [lastShortPosition] += remainingProfit;
         short.closedPL += remainingSwap + remainingCommission + remainingProfit;
      }

      long.openPL  = 0;
      short.openPL = 0;
   }
   return(!catch("StopSequence.ClosePositions(2)"));
}


/**
 * Delete the pending orders of a sequence and remove them from the order arrays. If an order was already executed local
 * state is updated and the order is kept.
 *
 * @return bool - success status
 */
bool Grid.RemovePendingOrders() {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("Grid.RemovePendingOrders(1)  "+ sequence.name +" cannot delete pending orders of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   if (long.enabled) {
      int orders = ArraySize(long.ticket), oeFlags, oe[];

      for (int i=0; i < orders; i++) {
         if (long.closeTime[i] > 0) continue;                           // skip tickets already known as closed
         if (long.type[i] == OP_UNDEFINED) {                            // an order locally known as pending
            oeFlags = F_ERR_INVALID_TRADE_PARAMETERS;                   // accept the order already being executed

            if (OrderDeleteEx(long.ticket[i], CLR_NONE, oeFlags, oe)) {
               if (!Orders.RemoveRecord(D_LONG, i)) return(false);
               orders--;
               i--;
               continue;
            }
            if (oe.Error(oe) != ERR_INVALID_TRADE_PARAMETERS) return(false);

            // the order was already executed: update local state
            if (!SelectTicket(long.ticket[i], "Grid.RemovePendingOrders(2)")) return(false);
            long.type      [i] = OrderType();
            long.openTime  [i] = OrderOpenTime();
            long.openPrice [i] = OrderOpenPrice();
            long.swap      [i] = OrderSwap();
            long.commission[i] = OrderCommission();
            long.profit    [i] = OrderProfit();
            if (IsLogDebug()) logDebug("Grid.RemovePendingOrders(3)  "+ sequence.name +" "+ UpdateStatus.OrderFillMsg(D_LONG, i));

            long.minLevel  = MathMin(long.level[i], long.minLevel);
            long.maxLevel  = MathMax(long.level[i], long.maxLevel);
            long.openLots += long.lots[i];
            long.slippage += oe.Slippage(oe)*Point;
         }
      }
   }

   if (short.enabled) {
      orders = ArraySize(short.ticket);

      for (i=0; i < orders; i++) {
         if (short.closeTime[i] > 0) continue;                          // skip tickets already known as closed
         if (short.type[i] == OP_UNDEFINED) {                           // an order locally known as pending
            oeFlags = F_ERR_INVALID_TRADE_PARAMETERS;                   // accept the order already being executed

            if (OrderDeleteEx(short.ticket[i], CLR_NONE, oeFlags, oe)) {
               if (!Orders.RemoveRecord(D_SHORT, i)) return(false);
               orders--;
               i--;
               continue;
            }
            if (oe.Error(oe) != ERR_INVALID_TRADE_PARAMETERS) return(false);

            // the order was already executed: update local state
            if (!SelectTicket(short.ticket[i], "Grid.RemovePendingOrders(4)")) return(false);
            short.type      [i] = OrderType();
            short.openTime  [i] = OrderOpenTime();
            short.openPrice [i] = OrderOpenPrice();
            short.swap      [i] = OrderSwap();
            short.commission[i] = OrderCommission();
            short.profit    [i] = OrderProfit();
            if (IsLogDebug()) logDebug("Grid.RemovePendingOrders(5)  "+ sequence.name +" "+ UpdateStatus.OrderFillMsg(D_SHORT, i));

            short.minLevel  = MathMin(short.level[i], short.minLevel);
            short.maxLevel  = MathMax(short.level[i], short.maxLevel);
            short.openLots += short.lots[i];
            short.slippage += oe.Slippage(oe)*Point;
         }
      }
   }

   return(!catch("Grid.RemovePendingOrders(6)"));
}


/**
 * Update order and PL status with current market data and signal status changes.
 *
 * @param  _Out_ bool gridChanged - whether the current gridlevel changed
 * @param  _Out_ bool gridError   - whether an external intervention was detected (cancellation or close)
 *
 * @return bool - success status
 */
bool UpdateStatus(bool &gridChanged, bool &gridError) {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("UpdateStatus(1)  "+ sequence.name +" cannot update order status of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   bool positionChanged=false, saveStatus=false;

   if (!UpdateStatus.Direction(D_LONG,  gridChanged, positionChanged, gridError, long.slippage,  long.openLots,  long.openPL,  long.closedPL,  long.minLevel,  long.maxLevel,  long.ticket,  long.level,  long.lots,  long.pendingType,  long.pendingPrice,  long.type,  long.openTime,  long.openPrice,  long.closeTime,  long.closePrice,  long.swap,  long.commission,  long.profit))  return(false);
   if (!UpdateStatus.Direction(D_SHORT, gridChanged, positionChanged, gridError, short.slippage, short.openLots, short.openPL, short.closedPL, short.minLevel, short.maxLevel, short.ticket, short.level, short.lots, short.pendingType, short.pendingPrice, short.type, short.openTime, short.openPrice, short.closeTime, short.closePrice, short.swap, short.commission, short.profit)) return(false);

   if (gridChanged || positionChanged) {
      sequence.openLots = NormalizeDouble(long.openLots - short.openLots, 2);
      SS.OpenLots();
      saveStatus = true;
   }
   if (!ComputeProfit(positionChanged)) return(false);

   if (saveStatus) SaveStatus();
   return(!catch("UpdateStatus(2)"));
}


/**
 * UpdateStatus() sub-routine. Updates order and PL status of a single trade direction.
 *
 * @param  _In_  int  direction       - trade direction
 * @param  _Out_ bool levelChanged    - whether the gridlevel changed
 * @param  _Out_ bool positionChanged - whether the total open position changed (position open or close)
 * @param  _Out_ bool gridError       - whether an external intervention occurred (order cancellation or position close)
 * @param  ...
 *
 * @return bool - success status
 */
bool UpdateStatus.Direction(int direction, bool &levelChanged, bool &positionChanged, bool &gridError, double &slippage, double &openLots, double &openPL, double &closedPL, int &minLevel, int &maxLevel, int tickets[], int levels[], double lots[], int pendingTypes[], double pendingPrices[], int &types[], datetime &openTimes[], double &openPrices[], datetime &closeTimes[], double &closePrices[], double &swaps[], double &commissions[], double &profits[]) {
   if (direction==D_LONG  && !long.enabled)  return(true);
   if (direction==D_SHORT && !short.enabled) return(true);

   int error, orders = ArraySize(tickets);
   bool updateSlippage=false, isLogDebug=IsLogDebug();
   openLots = 0;
   openPL   = 0;

   // update ticket status
   for (int i=0; i < orders; i++) {
      if (closeTimes[i] > 0) continue;                            // skip tickets already known as closed
      if (!SelectTicket(tickets[i], "UpdateStatus(3)")) return(false);

      bool wasPending  = (types[i] == OP_UNDEFINED);
      bool isPending   = (OrderType() > OP_SELL);
      bool wasPosition = !wasPending;
      bool isOpen      = !OrderCloseTime();
      bool isClosed    = !isOpen;

      if (wasPending) {
         if (!isPending) {                                        // the pending order was filled
            types     [i] = OrderType();
            openTimes [i] = OrderOpenTime();
            openPrices[i] = OrderOpenPrice();

            if (isLogDebug) logDebug("UpdateStatus(4)  "+ sequence.name +" "+ UpdateStatus.OrderFillMsg(direction, i));
            minLevel = MathMin(levels[i], minLevel);
            maxLevel = MathMax(levels[i], maxLevel);
            levelChanged    = true;
            positionChanged = true;
            updateSlippage  = true;
            wasPosition     = true;                               // mark as known open position
         }
         else if (isClosed) {                                     // the order was unexpectedly cancelled
            closeTimes[i] = OrderCloseTime();
            gridError = true;
            if (IsError(UpdateStatus.OnGridError("UpdateStatus(5)  "+ sequence.name +" "+ UpdateStatus.OrderCancelledMsg(direction, i, error), error))) return(false);
         }
      }

      if (wasPosition) {
         swaps      [i] = OrderSwap();
         commissions[i] = OrderCommission();
         profits    [i] = OrderProfit();

         if (isOpen) {                                            // update floating PL
            openPL   += swaps[i] + commissions[i] + profits[i];
            openLots += lots[i];
         }
         else {                                                   // the position was unexpectedly closed
            closeTimes [i] = OrderCloseTime();
            closePrices[i] = OrderClosePrice();
            closedPL += swaps[i] + commissions[i] + profits[i];   // update closed PL
            positionChanged = true;
            gridError       = true;
            if (IsError(UpdateStatus.OnGridError("UpdateStatus(6)  "+ sequence.name +" "+ UpdateStatus.PositionCloseMsg(direction, i, error), error))) return(false);
         }
      }
   }

   // update overall slippage
   if (updateSlippage) {
      double allLots, sumSlippage;

      for (i=0; i < orders; i++) {
         if (types[i] != OP_UNDEFINED) {
            sumSlippage += lots[i] * ifDouble(direction==D_LONG, pendingPrices[i]-openPrices[i], openPrices[i]-pendingPrices[i]);
            allLots     += lots[i];                               // sum slippage and all lots
         }
      }
      slippage = sumSlippage/allLots;                             // compute overall slippage
   }

   // normalize results
   openPL   = NormalizeDouble(openPL, 2);
   closedPL = NormalizeDouble(closedPL, 2);
   openLots = NormalizeDouble(openLots, 2);

   return(!catch("UpdateStatus(7)"));
}


/**
 * Compose a log message for a filled entry order.
 *
 * @param  int direction - trade direction
 * @param  int i         - order index
 *
 * @return string - log message or an empty string in case of errors
 */
string UpdateStatus.OrderFillMsg(int direction, int i) {
   // #1 Stop Sell 0.1 GBPUSD at 1.5457'2 ("L.8692.+3") was filled[ at 1.5457'2] (market: Bid/Ask[, 0.3 pip [positive ]slippage])
   int ticket, level, pendingType;
   double lots, pendingPrice, openPrice;

   if (direction == D_LONG) {
      ticket       = long.ticket      [i];
      level        = long.level       [i];
      lots         = long.lots        [i];
      pendingType  = long.pendingType [i];
      pendingPrice = long.pendingPrice[i];
      openPrice    = long.openPrice   [i];
   }
   else if (direction == D_SHORT) {
      ticket       = short.ticket      [i];
      level        = short.level       [i];
      lots         = short.lots        [i];
      pendingType  = short.pendingType [i];
      pendingPrice = short.pendingPrice[i];
      openPrice    = short.openPrice   [i];
   }
   else return(_EMPTY_STR(catch("UpdateStatus.OrderFillMsg(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER)));

   string sType         = OperationTypeDescription(pendingType);
   string sPendingPrice = NumberToStr(pendingPrice, PriceFormat);
   string comment       = ifString(direction==D_LONG, "L.", "S.") + sequence.id +"."+ NumberToStr(level, "+.");
   string message       = "#"+ ticket +" "+ sType +" "+ NumberToStr(lots, ".+") +" "+ Symbol() +" at "+ sPendingPrice +" (\""+ comment +"\") was filled";

   string sSlippage = "";
   if (NE(openPrice, pendingPrice, Digits)) {
      double slippage = NormalizeDouble((pendingPrice-openPrice)/Pip, 1); if (direction == D_SHORT) slippage = -slippage;
         if (slippage > 0) sSlippage = ", "+ DoubleToStr(slippage, Digits & 1) +" pip positive slippage";
         else              sSlippage = ", "+ DoubleToStr(-slippage, Digits & 1) +" pip slippage";
      message = message +" at "+ NumberToStr(openPrice, PriceFormat);
   }
   return(message +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) + sSlippage +")");
}


/**
 * Compose a log message for a cancelled pending entry order.
 *
 * @param  _In_  int direction - trade direction
 * @param  _In_  int i         - order index
 * @param  _Out_ int error     - error code to be attached to the log message (if any)
 *
 * @return string - log message or an empty string in case of errors
 */
string UpdateStatus.OrderCancelledMsg(int direction, int i, int &error) {
   // #1 Stop Sell 0.1 GBPUSD at 1.5457'2 ("L.8692.+3") was unexpectedly cancelled
   // #1 Stop Sell 0.1 GBPUSD at 1.5457'2 ("L.8692.+3") was deleted (not enough money)
   error = NO_ERROR;
   int ticket, level, pendingType;
   double lots, pendingPrice;

   if (direction == D_LONG) {
      ticket       = long.ticket      [i];
      level        = long.level       [i];
      lots         = long.lots        [i];
      pendingType  = long.pendingType [i];
      pendingPrice = long.pendingPrice[i];
   }
   else if (direction == D_SHORT) {
      ticket       = short.ticket      [i];
      level        = short.level       [i];
      lots         = short.lots        [i];
      pendingType  = short.pendingType [i];
      pendingPrice = short.pendingPrice[i];
   }
   else return(_EMPTY_STR(catch("UpdateStatus.OrderCancelledMsg(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER)));

   string sType         = OperationTypeDescription(pendingType);
   string sPendingPrice = NumberToStr(pendingPrice, PriceFormat);
   string comment       = ifString(direction==D_LONG, "L.", "S.") + sequence.id +"."+ NumberToStr(level, "+.");
   string message       = "#"+ ticket +" "+ sType +" "+ NumberToStr(lots, ".+") +" "+ Symbol() +" at "+ sPendingPrice +" (\""+ comment +"\") was ";
   string sReason       = "cancelled";

   SelectTicket(ticket, "UpdateStatus.OrderCancelledMsg(2)", /*push=*/true);
   sReason = "unexpectedly cancelled";
   if (OrderComment() == "deleted [no money]") {
      sReason = "deleted (not enough money)";
      error = ERR_NOT_ENOUGH_MONEY;
   }
   else if (!IsTesting() || __CoreFunction!=CF_DEINIT) {
      error = ERR_CONCURRENT_MODIFICATION;
   }
   OrderPop("UpdateStatus.OrderCancelledMsg(3)");

   return(message + sReason);
}


/**
 * Compose a log message for a closed open position.
 *
 * @param  _In_  int direction - trade direction
 * @param  _In_  int i         - order index
 * @param  _Out_ int error     - error code to be attached to the log message (if any)
 *
 * @return string - log message or an empty string in case of errors
 */
string UpdateStatus.PositionCloseMsg(int direction, int i, int &error) {
   // #1 Sell 0.1 GBPUSD at 1.5457'2 ("L.8692.+3") was unexpectedly closed at 1.5457'2 (market: Bid/Ask[, so: 47.7%/169.20/354.40])
   error = NO_ERROR;
   int ticket, level, type;
   double lots, openPrice, closePrice;

   if (direction == D_LONG) {
      ticket       = long.ticket    [i];
      level        = long.level     [i];
      type         = long.type      [i];
      lots         = long.lots      [i];
      openPrice    = long.openPrice [i];
      closePrice   = long.closePrice[i];
   }
   else if (direction == D_SHORT) {
      ticket       = short.ticket    [i];
      level        = short.level     [i];
      type         = short.type      [i];
      lots         = short.lots      [i];
      openPrice    = short.openPrice [i];
      closePrice   = short.closePrice[i];
   }
   else return(_EMPTY_STR(catch("UpdateStatus.PositionCloseMsg(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER)));

   string sType       = OperationTypeDescription(type);
   string sOpenPrice  = NumberToStr(openPrice, PriceFormat);
   string sClosePrice = NumberToStr(closePrice, PriceFormat);
   string comment     = ifString(direction==D_LONG, "L.", "S.") + sequence.id +"."+ NumberToStr(level, "+.");
   string message     = "#"+ ticket +" "+ sType +" "+ NumberToStr(lots, ".+") +" "+ Symbol() +" at "+ sOpenPrice +" (\""+ comment +"\") was unexpectedly closed at "+ sClosePrice;
   string sStopout    = "";

   SelectTicket(ticket, "UpdateStatus.PositionCloseMsg(2)", /*push=*/true);
   if (StrStartsWithI(OrderComment(), "so:")) {
      sStopout = ", "+ OrderComment();
      error = ERR_MARGIN_STOPOUT;
   }
   else if (!IsTesting() || __CoreFunction!=CF_DEINIT) {
      error = ERR_CONCURRENT_MODIFICATION;
   }
   OrderPop("UpdateStatus.PositionCloseMsg(3)");

   return(message +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) + sStopout +")");
}


/**
 * Error handler for unexpected order modifications.
 *
 * @param  string message - error message
 * @param  int    error   - error code
 *
 * @return int - the same error
 */
int UpdateStatus.OnGridError(string message, int error) {
   if (!IsTesting()) logError(message, error);        // onTick() will stop the sequence and halt the EA
   else if (!error)  logDebug(message, error);
   else              catch(message, error);
   return(error);
}


/**
 * Check existing pending orders and add new or missing ones.
 *
 * @param bool saveStatus [optional] - whether to save the sequence status before function return (default: no)
 *
 * @return bool - success status
 */
bool UpdatePendingOrders(bool saveStatus = false) {
   saveStatus = saveStatus!=0;
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("UpdatePendingOrders(1)  "+ sequence.name +" cannot update orders of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   bool gridChanged = false;

   // Scaling down
   //  - limit orders: @todo  If market moves too fast positions for missed levels must be opened immediately at the better price.
   // Scaling up
   //  - stop orders:  Regular slippage is not an issue. At worst the whole grid moves by the average slippage amount which is neglectable.
   //  - limit orders: Big slippage on price spikes affects only one (the next) level. For all other levels limit orders will be placed.

   if (long.enabled) {
      int orders = ArraySize(long.ticket);
      if (!orders) return(!catch("UpdatePendingOrders(2)  "+ sequence.name +" illegal size of long orders: 0", ERR_ILLEGAL_STATE));

      if (sequence.martingaleEnabled) {                        // on Martingale ensure the next limit order for scaling down exists
         if (long.level[0] == long.minLevel) {
            if (!Grid.AddPendingOrder(D_LONG, Min(long.minLevel-1, -2))) return(false);
            if (IsStopOrderType(long.pendingType[0])) {        // handle a missed sequence level
               long.minLevel = long.level[0];
               gridChanged = true;
            }
            orders++;
         }
      }
      if (sequence.pyramidEnabled) {                           // on Pyramid ensure the next stop order for scaling up exists
         if (long.level[orders-1] == long.maxLevel) {
            if (!Grid.AddPendingOrder(D_LONG, Max(long.maxLevel+1, 2))) return(false);
            if (IsLimitOrderType(long.pendingType[orders])) {  // handle a missed sequence level
               long.maxLevel = long.level[orders];
               gridChanged = true;
            }
            orders++;
         }
      }
   }

   if (short.enabled) {
      orders = ArraySize(short.ticket);
      if (!orders) return(!catch("UpdatePendingOrders(3)  "+ sequence.name +" illegal size of short orders: 0", ERR_ILLEGAL_STATE));

      if (sequence.martingaleEnabled) {                        // on Martingale ensure the next limit order for scaling down exists
         if (short.level[0] == short.minLevel) {
            if (!Grid.AddPendingOrder(D_SHORT, Min(short.minLevel-1, -2))) return(false);
            if (IsStopOrderType(short.pendingType[0])) {       // handle a missed sequence level
               short.minLevel = short.level[0];
               gridChanged = true;
            }
            orders++;
         }
      }
      if (sequence.pyramidEnabled) {                           // on Pyramid ensure the next stop order for scaling up exists
         if (short.level[orders-1] == short.maxLevel) {
            if (!Grid.AddPendingOrder(D_SHORT, Max(short.maxLevel+1, 2))) return(false);
            if (IsLimitOrderType(short.pendingType[orders])) { // handle a missed sequence level
               short.maxLevel = short.level[orders];
               gridChanged = true;
            }
            orders++;
         }
      }
   }

   if (gridChanged) UpdatePendingOrders(false);                // call the function again if sequence levels have been missed
   if (saveStatus)  SaveStatus();

   return(!catch("UpdatePendingOrders(4)"));
}


/**
 * Generate a new sequence id. Must be unique for all instances of this expert (strategy).
 *
 * @return int - sequence id in the range from 1000-9999
 */
int CreateSequenceId() {
   MathSrand(GetTickCount()-__ExecutionContext[EC.hChartWindow]);
   int id;
   while (id < SID_MIN || id > SID_MAX) {
      id = MathRand();                                         // TODO: in tester generate consecutive ids
   }                                                           // TODO: test id for uniqueness
   return(id);
}


/**
 * Generate a unique magic order number for the sequence.
 *
 * @return int - magic number or NULL in case of errors
 */
int CreateMagicNumber() {
   if (STRATEGY_ID < 101 || STRATEGY_ID > 1023)  return(!catch("CreateMagicNumber(1)  "+ sequence.name +" illegal strategy id: "+ STRATEGY_ID, ERR_ILLEGAL_STATE));
   if (sequence.id < 1000 || sequence.id > 9999) return(!catch("CreateMagicNumber(2)  "+ sequence.name +" illegal sequence id: "+ sequence.id, ERR_ILLEGAL_STATE));

   int strategy = STRATEGY_ID;                                 //  101-1023 (10 bit)
   int sequence = sequence.id;                                 // 1000-9999 (14 bit)
   int level    = 0;                                           //         0 (not used in this strategy)

   return((strategy<<22) + (sequence<<8) + (level<<0));
}


/**
 * Calculate the price of the specified trade direction and grid level.
 *
 * @param  int direction - trade direction
 * @param  int level     - gridlevel
 *
 * @return double - price or NULL in case of errors
 */
double CalculateGridLevel(int direction, int level) {
   if (IsLastError())                                   return(NULL);
   if      (direction == D_LONG)  { if (!long.enabled)  return(NULL); }
   else if (direction == D_SHORT) { if (!short.enabled) return(NULL); }
   else                                                 return(!catch("CalculateGridLevel(1)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (!level || level==-1)                             return(!catch("CalculateGridLevel(2)  "+ sequence.name +" invalid parameter level: "+ level, ERR_INVALID_PARAMETER));

   double price = 0;

   if (direction == D_LONG) {
      if (level > 0) price = sequence.gridbase + (level-1) * sequence.gridsize*Pip;
      else           price = sequence.gridbase + (level+1) * sequence.gridsize*Pip;
   }
   else {
      if (level > 0) price = sequence.gridbase - (level-1) * sequence.gridsize*Pip;
      else           price = sequence.gridbase - (level+1) * sequence.gridsize*Pip;
   }
   price = NormalizeDouble(price, Digits);

   return(ifDouble(catch("CalculateGridLevel(3)"), NULL, price));
}


/**
 * Calculate the order volume to use for the specified trade direction and grid level.
 *
 * @param  int direction - trade direction
 * @param  int level     - gridlevel
 *
 * @return double - normalized order volume or NULL in case of errors
 */
double CalculateLots(int direction, int level) {
   if (IsLastError())                                   return(NULL);
   if      (direction == D_LONG)  { if (!long.enabled)  return(NULL); }
   else if (direction == D_SHORT) { if (!short.enabled) return(NULL); }
   else                                                 return(!catch("CalculateLots(1)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (!level)                                          return(!catch("CalculateLots(2)  "+ sequence.name +" invalid parameter level: "+ level, ERR_INVALID_PARAMETER));
   double lots = 0;

   if (Abs(level) == 1) {             // covers +1 and -1
      lots = sequence.unitsize;
   }
   else if (level > 0) {              // pyramid levels
      if (sequence.pyramidEnabled)    lots = sequence.unitsize * MathPow(Pyramid.Multiplier, level-1);
   }
   else {                             // martingale levels
      if (sequence.martingaleEnabled) lots = sequence.unitsize * MathPow(Martingale.Multiplier, -level-1);
   }
   lots = NormalizeLots(lots); if (IsEmptyValue(lots)) return(NULL);

   return(ifDouble(catch("CalculateLots(3)"), NULL, lots));
}


/**
 * Compute and update the PL values of the sequence.
 *
 * @param  bool positionChanged - whether the open position changed since the last call (signals cache invalidation)
 *
 * @return bool - success status
 */
bool ComputeProfit(bool positionChanged) {
   positionChanged = positionChanged!=0;

   sequence.closedPL   = long.closedPL + short.closedPL;
   sequence.hedgedPL   = 0;
   sequence.floatingPL = 0;

   int longOrders=ArraySize(long.ticket), shortOrders=ArraySize(short.ticket), orders=longOrders + shortOrders;

   int    tickets    []; ArrayResize(tickets,     orders);
   int    types      []; ArrayResize(types,       orders);
   double lots       []; ArrayResize(lots,        orders);
   double openPrices []; ArrayResize(openPrices,  orders);
   double commissions[]; ArrayResize(commissions, orders);
   double swaps      []; ArrayResize(swaps,       orders);
   double profits    []; ArrayResize(profits,     orders);

   // copy open positions to temp. arrays (are modified in the process)
   for (int n, i=0; i < longOrders; i++) {
      if (long.type[i]!=OP_UNDEFINED && !long.closeTime[i]) {
         tickets    [n] = long.ticket    [i];
         types      [n] = long.type      [i];
         lots       [n] = long.lots      [i];
         openPrices [n] = long.openPrice [i];
         commissions[n] = long.commission[i];
         swaps      [n] = long.swap      [i];
         profits    [n] = long.profit    [i];
         n++;
      }
   }
   for (i=0; i < shortOrders; i++) {
      if (short.type[i]!=OP_UNDEFINED && !short.closeTime[i]) {
         tickets    [n] = short.ticket    [i];
         types      [n] = short.type      [i];
         lots       [n] = short.lots      [i];
         openPrices [n] = short.openPrice [i];
         commissions[n] = short.commission[i];
         swaps      [n] = short.swap      [i];
         profits    [n] = short.profit    [i];
         n++;
      }
   }
   if (n < orders) {
      ArrayResize(tickets,     n);
      ArrayResize(types,       n);
      ArrayResize(lots,        n);
      ArrayResize(openPrices,  n);
      ArrayResize(commissions, n);
      ArrayResize(swaps,       n);
      ArrayResize(profits,     n);
      orders = n;
   }

   // compute openPL = hedgedPL + floatingPL
   double hedgedLots, remainingLong, remainingShort, factor, sumOpenPrice, sumClosePrice, sumCommission, sumSwap, floatingPL, pipValue, pipDistance;

   // compute PL of a hedged part
   if (long.openLots && short.openLots) {
      hedgedLots     = MathMin(long.openLots, short.openLots);
      remainingLong  = hedgedLots;
      remainingShort = hedgedLots;

      for (i=0; i < orders; i++) {
         if (!tickets[i]) continue;

         if (types[i] == OP_BUY) {
            if (!remainingLong) continue;
            if (remainingLong >= lots[i]) {
               // apply all data except profit; afterwards nullify the ticket
               sumOpenPrice  += lots[i] * openPrices[i];
               sumSwap       += swaps[i];
               sumCommission += commissions[i];
               remainingLong = NormalizeDouble(remainingLong - lots[i], 3);
               tickets[i]    = NULL;
            }
            else {
               // apply all swap and partial commission; afterwards reduce the ticket's commission, profit and lotsize
               factor         = remainingLong/lots[i];
               sumOpenPrice  += remainingLong * openPrices[i];
               sumSwap       += swaps[i];                swaps      [i]  = 0;
               sumCommission += factor * commissions[i]; commissions[i] -= factor * commissions[i];
                                                         profits    [i] -= factor * profits    [i];
                                                         lots       [i]  = NormalizeDouble(lots[i]-remainingLong, 3);
               remainingLong = 0;
            }
         }
         else /*types[i] == OP_SELL*/ {
            if (!remainingShort) continue;
            if (remainingShort >= lots[i]) {
               // apply all swap; afterwards nullify the ticket
               sumClosePrice += lots[i] * openPrices[i];
               sumSwap       += swaps[i];                                              // commission is applied only at the long leg
               remainingShort = NormalizeDouble(remainingShort - lots[i], 3);
               tickets[i]     = NULL;
            }
            else {
               // apply all swap; afterwards reduce the ticket's commission, profit and lotsize
               factor         = remainingShort/lots[i];
               sumClosePrice += remainingShort * openPrices[i];
               sumSwap       += swaps[i]; swaps      [i]  = 0;
                                          commissions[i] -= factor * commissions[i];   // commission is applied only at the long leg
                                          profits    [i] -= factor * profits    [i];
                                          lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 3);
               remainingShort = 0;
            }
         }
      }
      if (remainingLong!=0 || remainingShort!=0) return(!catch("ComputeProfit(1)  illegal remaining "+ ifString(!remainingShort, "long", "short") +" position "+ NumberToStr(remainingLong, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR));

      // calculate profit from the difference openPrice-closePrice
      pipValue          = PipValue(hedgedLots); if (!pipValue) return(false);
      pipDistance       = (sumClosePrice - sumOpenPrice)/hedgedLots/Pip + (sumCommission + sumSwap)/pipValue;
      sequence.hedgedPL = pipDistance * pipValue;
      sumOpenPrice      = 0;
      sumCommission     = 0;
      sumSwap           = 0;
   }

   // compute PL of a floating long position
   if (sequence.openLots > 0) {
      remainingLong = sequence.openLots;
      sumOpenPrice  = 0;
      sumCommission = 0;
      sumSwap       = 0;
      floatingPL    = 0;

      for (i=0; i < orders; i++) {
         if (!tickets[i]   ) continue;
         if (!remainingLong) break;

         if (types[i] == OP_BUY) {
            if (remainingLong >= lots[i]) {
               // apply all data
               sumOpenPrice  += lots[i] * openPrices[i];
               sumSwap       += swaps[i];
               sumCommission += commissions[i];
               floatingPL    += profits[i];
               remainingLong  = NormalizeDouble(remainingLong - lots[i], 3);
            }
            else {
               // apply all swap, partial commission, partial profit; afterwards reduce the ticket's commission, profit and lotsize
               factor         = remainingLong/lots[i];
               sumOpenPrice  += remainingLong * openPrices[i];
               sumSwap       +=          swaps      [i]; swaps      [i]  = 0;
               sumCommission += factor * commissions[i]; commissions[i] -= factor * commissions[i];
               floatingPL    += factor * profits    [i]; profits    [i] -= factor * profits    [i];
                                                         lots       [i]  = NormalizeDouble(lots[i]-remainingLong, 3);
               remainingLong = 0;
            }
         }
      }
      if (remainingLong != 0) return(!catch("ComputeProfit(2)  illegal remaining long position "+ NumberToStr(remainingLong, ".+") +" of total position = "+ NumberToStr(sequence.openLots, ".+"), ERR_RUNTIME_ERROR));

      sequence.floatingPL = floatingPL + sumCommission + sumSwap;
   }

   // compute PL of a floating short position
   if (sequence.openLots < 0) {
      remainingShort = -sequence.openLots;
      sumOpenPrice   = 0;
      sumCommission  = 0;
      sumSwap        = 0;
      floatingPL     = 0;

      for (i=0; i < orders; i++) {
         if (!tickets[i]    ) continue;
         if (!remainingShort) break;

         if (types[i] == OP_SELL) {
            if (remainingShort >= lots[i]) {
               // apply all data
               sumOpenPrice  += lots[i] * openPrices[i];
               sumSwap       += swaps[i];
               sumCommission += commissions[i];
               floatingPL    += profits[i];
               remainingShort = NormalizeDouble(remainingShort - lots[i], 3);
            }
            else {
               // apply all swap, partial commission, partial profit; afterwards reduce the ticket's commission, profit and lotsize
               factor         = remainingShort/lots[i];
               sumOpenPrice  += remainingShort * openPrices[i];
               sumSwap       +=          swaps[i];       swaps      [i]  = 0;
               sumCommission += factor * commissions[i]; commissions[i] -= factor * commissions[i];
               floatingPL    += factor * profits[i];     profits    [i] -= factor * profits    [i];
                                                         lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 3);
               remainingShort = 0;
            }
         }
      }
      if (remainingShort != 0) return(!catch("ComputeProfit(3)  illegal remaining short position "+ NumberToStr(remainingShort, ".+") +" of total position = "+ NumberToStr(sequence.openLots, ".+"), ERR_RUNTIME_ERROR));

      sequence.floatingPL = floatingPL + sumCommission + sumSwap;
   }

   // calculate stop and profit targets
   if (positionChanged) {
      if (!ComputeProfitTargets(sequence.openLots, sumOpenPrice, sumCommission, sumSwap, sequence.hedgedPL, sequence.closedPL)) return(false);
   }

   // summarize and process results
   sequence.openPL   = NormalizeDouble(sequence.hedgedPL + sequence.floatingPL, 2);
   sequence.closedPL = NormalizeDouble(sequence.closedPL, 2);
   sequence.totalPL  = NormalizeDouble(sequence.openPL + sequence.closedPL, 2);
   bool statsChanged = false;
   if      (sequence.totalPL > sequence.maxProfit  ) { sequence.maxProfit   = sequence.totalPL; statsChanged = true; }
   else if (sequence.totalPL < sequence.maxDrawdown) { sequence.maxDrawdown = sequence.totalPL; statsChanged = true; }
   SS.TotalPL();
   if (statsChanged) SS.PLStats();
   SS.ProfitTargets();

   return(!catch("ComputeProfit(4)"));
}


/**
 * Compute and update the profit targets of the sequence.
 *
 * @return bool - success status
 */
bool ComputeProfitTargets(double lots, double sumOpenPrice, double commission, double swap, double hedgedPL, double closedPL) {
   double _lots, _sumOpenPrice, _commission, _swap, _hedgedPL, _closedPL;
   int _level;

   if (long.enabled) {
      _level        = long.maxLevel;
      _lots         = lots;
      _sumOpenPrice = sumOpenPrice;
      _commission   = commission;
      _swap         = swap;
      _hedgedPL     = hedgedPL;
      _closedPL     = closedPL;

      if (_lots <  0) Short2Hedged(_level, _lots, _sumOpenPrice, _commission, _swap, _hedgedPL);   // short: interpolate position to the next long or hedged position
      if (_lots == 0)  Hedged2Long(_level, _lots, _sumOpenPrice, _commission);                     // hedged: interpolate position to the next long position
      sequence.bePrice.long = ComputeBreakeven(D_LONG, _level, _lots, _sumOpenPrice, _commission, _swap, _hedgedPL, _closedPL);
   }

   if (short.enabled) {
      _level        = short.maxLevel;
      _lots         = lots;
      _sumOpenPrice = sumOpenPrice;
      _commission   = commission;
      _swap         = swap;
      _hedgedPL     = hedgedPL;
      _closedPL     = closedPL;

      if (_lots >  0)  Long2Hedged(_level, _lots, _sumOpenPrice, _commission, _swap, _hedgedPL);   // long: interpolate position to the next short or hedged position
      if (_lots == 0) Hedged2Short(_level, _lots, _sumOpenPrice, _commission);                     // hedged: interpolate position to the next short position
      sequence.bePrice.short = ComputeBreakeven(D_SHORT, _level, _lots, _sumOpenPrice, _commission, _swap, _hedgedPL, _closedPL);
   }

   if (IsVisualMode()) {                                                                           // for breakeven indicator: store results also in the chart window
      SetWindowDoubleA(__ExecutionContext[EC.hChart], "Duel.breakeven.long",  sequence.bePrice.long);
      SetWindowDoubleA(__ExecutionContext[EC.hChart], "Duel.breakeven.short", sequence.bePrice.short);
   }
   return(!catch("ComputeProfitTargets(1)"));
}


/**
 * @return bool - success status
 */
bool Short2Hedged(int &level, double &lots, double &sumOpenPrice, double &commission, double &swap, double &hedgedPL) {
   double avgPrice=-sumOpenPrice/lots, nextPrice, nextLots, pipValuePerLot=PipValue();

   while (lots < 0) {
      level++;
      nextPrice = CalculateGridLevel(D_LONG, level);
      nextLots  = CalculateLots(D_LONG, level);
      lots      = NormalizeDouble(lots + nextLots, 2);
      hedgedPL += (avgPrice-nextPrice)/Pip * (nextLots-MathMax(0, lots)) * pipValuePerLot;
   }

   hedgedPL    += commission + swap;
   sumOpenPrice = lots * nextPrice;
   commission   = -RoundCeil(GetCommission(lots), 2);
   swap         = 0;

   return(true);
}


/**
 * @return bool - success status
 */
bool Long2Hedged(int &level, double &lots, double &sumOpenPrice, double &commission, double &swap, double &hedgedPL) {
   double avgPrice=sumOpenPrice/lots, nextPrice, nextLots, pipValuePerLot=PipValue();

   while (lots > 0) {
      level++;
      nextPrice = CalculateGridLevel(D_SHORT, level);
      nextLots  = CalculateLots(D_SHORT, level);
      lots      = NormalizeDouble(lots - nextLots, 2);
      hedgedPL += (nextPrice-avgPrice)/Pip * (nextLots+MathMin(0, lots)) * pipValuePerLot;
   }

   hedgedPL    += commission + swap;
   sumOpenPrice = -lots * nextPrice;
   commission   = RoundCeil(GetCommission(lots), 2);
   swap         = 0;

   return(true);
}


/**
 * @return bool - success status
 */
bool Hedged2Long(int &level, double &lots, double &sumOpenPrice, double &commission) {
   if (lots || sumOpenPrice || commission) return(!catch("Hedged2Long(1)  invalid parameters: lots="+ NumberToStr(lots, ".+") +"  sumOpenPrice="+ NumberToStr(sumOpenPrice, ".+") +"  commission="+ NumberToStr(commission, ".+"), ERR_INVALID_PARAMETER));

   level++;
   lots         = CalculateLots(D_LONG, level);
   sumOpenPrice = lots * CalculateGridLevel(D_LONG, level);
   commission   = -RoundCeil(GetCommission(lots), 2);

   return(true);
}


/**
 * @return bool - success status
 */
bool Hedged2Short(int &level, double &lots, double &sumOpenPrice, double &commission) {
   if (lots || sumOpenPrice || commission) return(!catch("Hedged2Short(1)  invalid parameters: lots="+ NumberToStr(lots, ".+") +"  sumOpenPrice="+ NumberToStr(sumOpenPrice, ".+") +"  commission="+ NumberToStr(commission, ".+"), ERR_INVALID_PARAMETER));

   level++;
   lots         = -CalculateLots(D_SHORT, level);
   sumOpenPrice = -lots * CalculateGridLevel(D_SHORT, level);
   commission   = RoundCeil(GetCommission(lots), 2);

   return(true);
}


/**
 * Compute the breakeven price of the given position considering future grid positions.
 *
 * @return double - breakeven price or NULL in case of errors
 */
double ComputeBreakeven(int direction, int level, double lots, double sumOpenPrice, double commission, double swap, double hedgedPL, double closedPL) {
   int nextLevel;
   double nextLots, nextPrice, bePrice, pipValue, pipValuePerLot=PipValue(), commissionPerLot=GetCommission();
   if (!pipValuePerLot || IsEmpty(commissionPerLot)) return(NULL);

   // long
   if (direction == D_LONG) {
      if (lots <= 0) return(!catch("ComputeBreakeven(1)  not a long position: lots="+ NumberToStr(lots, ".1+"), ERR_RUNTIME_ERROR));

      pipValue  = lots * pipValuePerLot;                             // BE at the current level
      bePrice   = sumOpenPrice/lots - (closedPL + hedgedPL + commission + swap)/pipValue*Pip;
      nextLevel = level + 1;
      nextPrice = CalculateGridLevel(D_LONG, nextLevel);             // grid at the next level

      while (nextPrice < bePrice) {
         nextLots      = CalculateLots(D_LONG, nextLevel);
         lots         += nextLots;
         sumOpenPrice += nextLots * nextPrice;
         commission   -= RoundCeil(nextLots * commissionPerLot, 2);
         pipValue      = lots * pipValuePerLot;                      // BE at the next level
         bePrice       = sumOpenPrice/lots - (closedPL + hedgedPL + commission + swap)/pipValue*Pip;
         nextLevel++;
         nextPrice     = CalculateGridLevel(D_LONG, nextLevel);      // grid at the next level
      }
      return(bePrice);
   }

   // short
   if (direction == D_SHORT) {
      if (lots >= 0) return(!catch("ComputeBreakeven(2)  not a short position: lots="+ NumberToStr(lots, ".1+"), ERR_RUNTIME_ERROR));

      pipValue  = -lots * pipValuePerLot;                            // BE at the current level
      bePrice   = (closedPL + hedgedPL + commission + swap)/pipValue*Pip - sumOpenPrice/lots;
      nextLevel = level + 1;
      nextPrice = CalculateGridLevel(D_SHORT, nextLevel);            // grid at the next level

      while (nextPrice > bePrice) {
         nextLots      = CalculateLots(D_SHORT, nextLevel);
         lots         -= nextLots;
         sumOpenPrice += nextLots * nextPrice;
         commission   -= RoundCeil(nextLots * commissionPerLot, 2);
         pipValue      = -lots * pipValuePerLot;                     // BE at the next level
         bePrice       = (closedPL + hedgedPL + commission + swap)/pipValue*Pip - sumOpenPrice/lots;
         nextLevel++;
         nextPrice     = CalculateGridLevel(D_SHORT, nextLevel);     // grid at the next level
      }
      return(bePrice);
   }

   return(!catch("ComputeBreakeven(3)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
}


/**
 * Auto-configure and return missing grid parameters. At least 2 of the 3 parameters must have a value. If all 3 parameters
 * are set gridsize and unitsize override the specified volatility.
 *
 * @param  _InOut_ double &gridvola - the specified/resulting grid volatility
 * @param  _InOut_ double &gridsize - the specified/resulting gridsize
 * @param  _InOut_ double &unitsize - the specified/resulting unitsize
 *
 * @return bool - success status
 */
bool ConfigureGrid(double &gridvola, double &gridsize, double &unitsize) {
   bool wasSequenceStarted = (ArraySize(long.ticket) || ArraySize(short.ticket));
   if (wasSequenceStarted) return(false);                                           // skip reconfigurations after sequence start

   if (LT(gridvola, 0) || LT(gridsize, 0) || LT(unitsize, 0))
                    return(!catch("ConfigureGrid(1)  "+ sequence.name +" invalid parameters GridVolatility/GridSize/UnitSize (must be non-negative)", ERR_INVALID_PARAMETER));
   int empties = EQ(gridvola, 0) + EQ(gridsize, 0) + EQ(unitsize, 0);
   if (empties > 1) return(!catch("ConfigureGrid(2)  "+ sequence.name +" invalid parameters GridVolatility/GridSize/UnitSize (min. 2 values must be set)", ERR_INVALID_PARAMETER));

   double adr        = iADR();                                                  if (!adr)       return(logWarn("ConfigureGrid(3)  "+ sequence.name +" ADR=0"));
   double beDistance = adr/2;
   double tickSize   = MarketInfo(Symbol(), MODE_TICKSIZE);                     if (!tickSize)  return(logWarn("ConfigureGrid(4)  "+ sequence.name +" MODE_TICKSIZE=0"));
   double tickValue  = MarketInfo(Symbol(), MODE_TICKVALUE);                    if (!tickValue) return(logWarn("ConfigureGrid(5)  "+ sequence.name +" MODE_TICKVALUE=0"));
   double equity     = AccountEquity() - AccountCredit() + GetExternalAssets(); if (!equity)    return(logWarn("ConfigureGrid(6)  "+ sequence.name +" equity=0"));
   double adrLevels, adrLots, pl;

   if (gridsize && unitsize) {
      // calculate the resulting volatility
      adrLevels = adr/Pip/gridsize + 1;
      adrLots   = unitsize * adrLevels;
      pl        = beDistance/tickSize * tickValue * adrLots;
      gridvola  = pl/equity * 100;

      if (!gridvola) return(logWarn("ConfigureGrid(7)  "+ sequence.name +" resulting gridvola: 0"));
   }
   else if (gridvola && unitsize) {
      // calculate the resulting gridsize and round it up (for safety)
      pl        = gridvola/100 * equity;
      adrLots   = pl/beDistance/tickValue * tickSize;
      adrLevels = adrLots/unitsize;
      gridsize  = adr/Pip/(adrLevels-1);
      gridsize  = RoundCeil(gridsize, Digits & 1);

      if (!gridsize) return(logWarn("ConfigureGrid(8)  "+ sequence.name +" resulting gridsize: 0"));
      return(ConfigureGrid(gridvola, gridsize, unitsize));                 // recalculate vola after rounding up
   }
   else /*gridvola && gridsize*/ {
      // calculate the resulting unitsize and round it down (for safety)
      pl        = gridvola/100 * equity;
      adrLevels = adr/Pip/gridsize + 1;
      adrLots   = pl/beDistance/tickValue * tickSize;
      unitsize  = adrLots/adrLevels;
      unitsize  = NormalizeLots(unitsize, NULL, MODE_FLOOR);

      if (!unitsize) return(logWarn("ConfigureGrid(9)  "+ sequence.name +" resulting unitsize: 0"));
      return(ConfigureGrid(gridvola, gridsize, unitsize));                 // recalculate vola after rounding down
   }

   if (IsLogInfo()) logInfo("ConfigureGrid(10)  "+ sequence.name +"  gridsize="+ DoubleToStr(gridsize, Digits & 1) +"  unitsize="+ NumberToStr(unitsize, ".+") +"  gridvola="+ DoubleToStr(gridvola, 1) +"%");
   return(!catch("ConfigureGrid(11)"));
}


/**
 * Return the full name of the instance logfile.
 *
 * @return string - filename or an empty string in case of errors
 */
string GetLogFilename() {
   string name = GetStatusFilename();
   if (!StringLen(name)) return("");
   return(StrLeftTo(name, ".", -1) +".log");
}


/**
 * Return the full name of the instance status file.
 *
 * @param  relative [optional] - whether to return the absolute path or the path relative to the MQL "files" directory
 *                               (default: the absolute path)
 *
 * @return string - filename or an empty string in case of errors
 */
string GetStatusFilename(bool relative = false) {
   relative = relative!=0;
   if (!sequence.id) return(_EMPTY_STR(catch("GetStatusFilename(1)  "+ sequence.name +" illegal value of sequence.id: "+ sequence.id, ERR_ILLEGAL_STATE)));

   string directory = "presets\\" + ifString(IsTestSequence(), "Tester", GetAccountCompany()) +"\\";
   string baseName  = StrToLower(Symbol()) +".Duel."+ sequence.id +".set";

   if (relative)
      return(directory + baseName);
   return(GetMqlFilesPath() +"\\"+ directory + baseName);
}


/**
 * Open a market position for the specified grid level and add the order data to the order arrays. There is no check whether
 * the specified grid level matches the current market price.
 *
 * @param  int direction - trade direction: D_LONG | D_SHORT
 * @param  int level     - grid level of the position to open: -n...-1 | +1...+n
 *
 * @return int - array index the order record was stored at or EMPTY (-1) in case of errors
 */
int Grid.AddPosition(int direction, int level) {
   if (IsLastError())                         return(EMPTY);
   if (sequence.status != STATUS_PROGRESSING) return(_EMPTY(catch("Grid.AddPosition(1)  "+ sequence.name +" cannot add position to "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE)));

   int oe[];
   int ticket = SubmitMarketOrder(direction, level, oe);
   if (!ticket) return(EMPTY);

   // prepare dataset
   //int    ticket       = ...                                                   // use as is
   //int    level        = ...                                                   // ...
   double   lots         = oe.Lots(oe);
   int      pendingType  = OP_UNDEFINED;
   datetime pendingTime  = NULL;
   double   pendingPrice = ifDouble(direction==D_LONG, oe.Ask(oe), oe.Bid(oe));  // for tracking of slippage
   int      openType     = oe.Type(oe);
   datetime openTime     = oe.OpenTime(oe);
   double   openPrice    = oe.OpenPrice(oe);
   datetime closeTime    = NULL;
   double   closePrice   = NULL;
   double   swap         = oe.Swap(oe);
   double   commission   = oe.Commission(oe);
   double   profit       = NULL;

   int i = Orders.AddRecord(direction, ticket, level, lots, pendingType, pendingTime, pendingPrice, openType, openTime, openPrice, closeTime, closePrice, swap, commission, profit);
   if (i >= 0) {
      if (direction == D_LONG) {
         long.minLevel  = MathMin(level, long.minLevel);
         long.maxLevel  = MathMax(level, long.maxLevel);
         long.openLots += lots;
      }
      else {
         short.minLevel  = MathMin(level, short.minLevel);
         short.maxLevel  = MathMax(level, short.maxLevel);
         short.openLots += lots;
      }
   }
   return(i);
}


/**
 * Open a pending order for the specified grid level and add the order to the order arrays. Depending on the market a stop or
 * limit order will be opened.
 *
 * @param  int direction - trade direction: D_LONG | D_SHORT
 * @param  int level     - grid level of the order to open: -n...-1 | +1...+n
 *
 * @return bool - success status
 */
bool Grid.AddPendingOrder(int direction, int level) {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("Grid.AddPendingOrder(1)  "+ sequence.name +" cannot add pending order to "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   int type = ifInt(level > 0, OA_STOP, OA_LIMIT), ticket, oe[], counter;

   // loop until an order was opened or an unexpected error occurred
   while (true) {
      if (type == OA_STOP) ticket = SubmitStopOrder(direction, level, oe);
      else                 ticket = SubmitLimitOrder(direction, level, oe);
      if (ticket > 0) break;

      int error = oe.Error(oe);
      if (error != ERR_INVALID_STOP) return(false);

      counter++; if (counter > 9) return(!catch("Grid.AddPendingOrder(2)  "+ sequence.name +" stopping trade request loop after "+ counter +" unsuccessful tries, last error", error));
      if (IsLogDebug()) logDebug("Grid.AddPendingOrder(3)  "+ sequence.name +" illegal price "+ OperationTypeDescription(oe.Type(oe)) +" at "+ NumberToStr(oe.OpenPrice(oe), PriceFormat) +" (market: "+ NumberToStr(oe.Bid(oe), PriceFormat) +"/"+ NumberToStr(oe.Ask(oe), PriceFormat) +"), opening "+ ifString(IsStopOrderType(oe.Type(oe)), "limit", "stop") +" order instead...");
      type = ifInt(type==OA_LIMIT, OA_STOP, OA_LIMIT);
   }

   // prepare dataset
   //int    ticket       = ...                                    // use as is
   //int    level        = ...                                    // ...
   double   lots         = oe.Lots(oe);
   int      pendingType  = oe.Type(oe);
   datetime pendingTime  = oe.OpenTime(oe);
   double   pendingPrice = oe.OpenPrice(oe);
   int      openType     = OP_UNDEFINED;
   datetime openTime     = NULL;
   double   openPrice    = NULL;
   datetime closeTime    = NULL;
   double   closePrice   = NULL;
   double   swap         = NULL;
   double   commission   = NULL;
   double   profit       = NULL;

   int index = Orders.AddRecord(direction, ticket, level, lots, pendingType, pendingTime, pendingPrice, openType, openTime, openPrice, closeTime, closePrice, swap, commission, profit);
   return(!IsEmpty(index));
}


/**
 * Whether the current sequence was created in the tester. Considers the fact that a test sequence may be loaded into an
 * online chart after the test (for visualization).
 *
 * @return bool
 */
bool IsTestSequence() {
   return(sequence.isTest || IsTesting());
}


// backed-up input parameters
string   prev.Sequence.ID = "";
string   prev.GridDirection = "";
string   prev.GridVolatility;
double   prev.GridSize;
double   prev.UnitSize;
double   prev.Pyramid.Multiplier;
double   prev.Martingale.Multiplier;
string   prev.TakeProfit = "";
string   prev.StopLoss = "";
bool     prev.ShowProfitInPercent;
datetime prev.Sessionbreak.StartTime;
datetime prev.Sessionbreak.EndTime;

// backed-up status variables
int      prev.sequence.id;
datetime prev.sequence.created;
bool     prev.sequence.isTest;
string   prev.sequence.name = "";
int      prev.sequence.status;
int      prev.sequence.direction;
bool     prev.sequence.pyramidEnabled;
bool     prev.sequence.martingaleEnabled;
double   prev.sequence.unitsize;
double   prev.sequence.gridsize;

bool     prev.long.enabled;
bool     prev.short.enabled;

bool     prev.tpAbs.condition;
double   prev.tpAbs.value;
string   prev.tpAbs.description = "";
bool     prev.tpPct.condition;
double   prev.tpPct.value;
double   prev.tpPct.absValue;
string   prev.tpPct.description = "";

bool     prev.slAbs.condition;
double   prev.slAbs.value;
string   prev.slAbs.description = "";
bool     prev.slPct.condition;
double   prev.slPct.value;
double   prev.slPct.absValue;
string   prev.slPct.description = "";

datetime prev.sessionbreak.starttime;
datetime prev.sessionbreak.endtime;


/**
 * Programatically changed input parameters don't survive init cycles. Therefore inputs are backed-up in deinit() and can be
 * restored in init(). Called in onDeinitParameters() and onDeinitChartChange().
 */
void BackupInputs() {
   // backup input parameters, also used for comparison in ValidateInputs()
   prev.Sequence.ID            = StringConcatenate(Sequence.ID, "");       // string inputs are references to internal C literals...
   prev.GridDirection          = StringConcatenate(GridDirection, "");     // ...and must be copied to break the reference
   prev.GridVolatility         = StringConcatenate(GridVolatility, "");
   prev.GridSize               = GridSize;
   prev.UnitSize               = UnitSize;
   prev.Pyramid.Multiplier     = Pyramid.Multiplier;
   prev.Martingale.Multiplier  = Martingale.Multiplier;
   prev.TakeProfit             = StringConcatenate(TakeProfit, "");
   prev.StopLoss               = StringConcatenate(StopLoss, "");
   prev.ShowProfitInPercent    = ShowProfitInPercent;
   prev.Sessionbreak.StartTime = Sessionbreak.StartTime;
   prev.Sessionbreak.EndTime   = Sessionbreak.EndTime;

   // backup status variables which may change by modifying input parameters
   prev.sequence.id                = sequence.id;
   prev.sequence.created           = sequence.created;
   prev.sequence.isTest            = sequence.isTest;
   prev.sequence.name              = sequence.name;
   prev.sequence.status            = sequence.status;
   prev.sequence.direction         = sequence.direction;
   prev.sequence.pyramidEnabled    = sequence.pyramidEnabled;
   prev.sequence.martingaleEnabled = sequence.martingaleEnabled;
   prev.sequence.unitsize          = sequence.unitsize;
   prev.sequence.gridsize          = sequence.gridsize;

   prev.long.enabled               = long.enabled ;
   prev.short.enabled              = short.enabled;

   prev.tpAbs.condition            = tpAbs.condition;
   prev.tpAbs.value                = tpAbs.value;
   prev.tpAbs.description          = tpAbs.description;
   prev.tpPct.condition            = tpPct.condition;
   prev.tpPct.value                = tpPct.value;
   prev.tpPct.absValue             = tpPct.absValue;
   prev.tpPct.description          = tpPct.description;

   prev.slAbs.condition            = slAbs.condition;
   prev.slAbs.value                = slAbs.value;
   prev.slAbs.description          = slAbs.description;
   prev.slPct.condition            = slPct.condition;
   prev.slPct.value                = slPct.value;
   prev.slPct.absValue             = slPct.absValue;
   prev.slPct.description          = slPct.description;

   prev.sessionbreak.starttime     = sessionbreak.starttime;
   prev.sessionbreak.endtime       = sessionbreak.endtime;
}


/**
 * Restore backed-up input parameters and status variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // restore input parameters
   Sequence.ID            = prev.Sequence.ID;
   GridDirection          = prev.GridDirection;
   GridVolatility         = prev.GridVolatility;
   GridSize               = prev.GridSize;
   UnitSize               = prev.UnitSize;
   Pyramid.Multiplier     = prev.Pyramid.Multiplier;
   Martingale.Multiplier  = prev.Martingale.Multiplier;
   TakeProfit             = prev.TakeProfit;
   StopLoss               = prev.StopLoss;
   ShowProfitInPercent    = prev.ShowProfitInPercent;
   Sessionbreak.StartTime = prev.Sessionbreak.StartTime;
   Sessionbreak.EndTime   = prev.Sessionbreak.EndTime;

   // restore status variables
   sequence.id                = prev.sequence.id;
   sequence.created           = prev.sequence.created;
   sequence.isTest            = prev.sequence.isTest;
   sequence.name              = prev.sequence.name;
   sequence.status            = prev.sequence.status;
   sequence.direction         = prev.sequence.direction;
   sequence.pyramidEnabled    = prev.sequence.pyramidEnabled;
   sequence.martingaleEnabled = prev.sequence.martingaleEnabled;
   sequence.unitsize          = prev.sequence.unitsize;
   sequence.gridsize          = prev.sequence.gridsize;

   long.enabled               = prev.long.enabled ;
   short.enabled              = prev.short.enabled;

   tpAbs.condition            = prev.tpAbs.condition;
   tpAbs.value                = prev.tpAbs.value;
   tpAbs.description          = prev.tpAbs.description;
   tpPct.condition            = prev.tpPct.condition;
   tpPct.value                = prev.tpPct.value;
   tpPct.absValue             = prev.tpPct.absValue;
   tpPct.description          = prev.tpPct.description;

   slAbs.condition            = prev.slAbs.condition;
   slAbs.value                = prev.slAbs.value;
   slAbs.description          = prev.slAbs.description;
   slPct.condition            = prev.slPct.condition;
   slPct.value                = prev.slPct.value;
   slPct.absValue             = prev.slPct.absValue;
   slPct.description          = prev.slPct.description;

   sessionbreak.starttime     = prev.sessionbreak.starttime;
   sessionbreak.endtime       = prev.sessionbreak.endtime;
}


/**
 * Syntactically validate and restore a specified sequence id (format: /T?1[0-9]{3}/). Called only from onInitUser().
 *
 * @return bool - whether the input was valid and 'sequence.id'/'sequence.isTest' were restored (the status file is not checked)
 */
bool ValidateInputs.SID() {
   string sValue = StrTrim(Sequence.ID);
   if (!StringLen(sValue)) return(false);

   if (StrStartsWithI(sValue, "T")) {
      sequence.isTest = true;
      sValue = StrTrim(StrSubstr(sValue, 1));
   }
   if (!StrIsDigit(sValue))                  return(!onInputError("ValidateInputs.SID(1)  "+ sequence.name +" invalid input parameter Sequence.ID: "+ DoubleQuoteStr(Sequence.ID) +" (must be digits only)"));
   int iValue = StrToInteger(sValue);
   if (iValue < SID_MIN || iValue > SID_MAX) return(!onInputError("ValidateInputs.SID(2)  "+ sequence.name +" invalid input parameter Sequence.ID: "+ DoubleQuoteStr(Sequence.ID) +" (range error)"));

   sequence.id = iValue;
   Sequence.ID = ifString(IsTestSequence(), "T", "") + sequence.id;
   SS.SequenceName();
   return(true);
}


/**
 * Validate the input parameters. Parameters may have been entered through the input dialog, read from a status file or
 * deserialized and applied programmatically by the terminal (e.g. at terminal restart). Called only from onInitUser(),
 * onInitParameters() and onInitTemplate().
 *
 * @return bool - whether input parameters are valid
 */
bool ValidateInputs() {
   if (IsLastError()) return(false);
   bool isManualInput      = (ProgramInitReason()==IR_PARAMETERS);                  // whether we validate manual or programmatic inputs
   bool wasSequenceStarted = (ArraySize(long.ticket) || ArraySize(short.ticket));   // whether the sequence was already started

   // Sequence.ID ???

   // GridDirection
   string sValues[], sValue = GridDirection;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   int iValue = StrToTradeDirection(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (iValue == -1)                          return(!onInputError("ValidateInputs(1)  invalid input parameter GridDirection: "+ DoubleQuoteStr(GridDirection)));
   if (isManualInput && iValue!=prev.sequence.direction) {
      if (wasSequenceStarted)                 return(!onInputError("ValidateInputs(2)  cannot change input parameter GridDirection of already started sequence"));
   }
   sequence.direction = iValue;
   long.enabled  = (sequence.direction & D_LONG  && 1);
   short.enabled = (sequence.direction & D_SHORT && 1);
   GridDirection = TradeDirectionDescription(sequence.direction);

   // GridVolatility
   if (isManualInput && !StrCompareI(GridVolatility, prev.GridVolatility)) {
      if (wasSequenceStarted)                 return(!onInputError("ValidateInputs(3)  cannot change input parameter GridVolatility of already started sequence"));
   }
   sValue = StrTrim(GridVolatility);
   if (!StringLen(sValue) || sValue=="{percent}") {
      sequence.gridvola = NULL;
      GridVolatility = "";
   }
   else {
      if (StrEndsWith(sValue, "%"))
         sValue = StrTrim(StrLeft(sValue, -1));
      if (!StrIsNumeric(sValue))              return(!onInputError("ValidateInputs(4)  invalid input parameter GridVolatility: "+ DoubleQuoteStr(GridVolatility) +" (not numeric)"));
      sequence.gridvola = MathAbs(StrToDouble(sValue));
      GridVolatility = NumberToStr(sequence.gridvola, ".+") +"%";
   }

   // GridSize
   if (isManualInput && NE(GridSize, prev.GridSize)) {
      if (wasSequenceStarted)                 return(!onInputError("ValidateInputs(5)  cannot change input parameter GridSize of already started sequence"));
   }
   if (LT(GridSize, 0))                       return(!onInputError("ValidateInputs(6)  invalid input parameter GridSize: "+ NumberToStr(GridSize, ".+") +" (too small)"));
   if (MathModFix(GridSize*Pip, Point) != 0)  return(!onInputError("ValidateInputs(7)  invalid input parameter GridSize: "+ NumberToStr(GridSize, ".+") +" (not a multiple of Point)"));
   sequence.gridsize = GridSize;

   // UnitSize
   if (isManualInput && NE(UnitSize, prev.UnitSize)) {
      if (wasSequenceStarted)                 return(!onInputError("ValidateInputs(8)  cannot change input parameter UnitSize of already started sequence"));
   }
   if (LT(UnitSize, 0))                       return(!onInputError("ValidateInputs(9)  invalid input parameter UnitSize: "+ NumberToStr(UnitSize, ".1+") +" (too small)"));
   if (NE(UnitSize, NormalizeLots(UnitSize))) return(!onInputError("ValidateInputs(10)  invalid input parameter UnitSize: "+ NumberToStr(UnitSize, ".1+") +" (not a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));
   sequence.unitsize = UnitSize;

   int empties = EQ(sequence.gridvola, 0) + EQ(sequence.gridsize, 0) + EQ(sequence.unitsize, 0);
   if (empties > 1)                           return(!onInputError("ValidateInputs(11)  invalid input parameters GridVolatility/GridSize/UnitSize (min. 2 values must be set)"));

   // Pyramid.Multiplier
   if (isManualInput && NE(Pyramid.Multiplier, prev.Pyramid.Multiplier)) {
      if (wasSequenceStarted)                 return(!onInputError("ValidateInputs(12)  cannot change input parameter Pyramid.Multiplier of already started sequence"));
   }
   if (Pyramid.Multiplier < 0)                return(!onInputError("ValidateInputs(13)  invalid input parameter Pyramid.Multiplier: "+ NumberToStr(Pyramid.Multiplier, ".1+")));
   sequence.pyramidEnabled = (Pyramid.Multiplier > 0);

   // Martingale.Multiplier
   if (isManualInput && NE(Martingale.Multiplier, prev.Martingale.Multiplier)) {
      if (wasSequenceStarted)                 return(!onInputError("ValidateInputs(14)  cannot change input parameter Martingale.Multiplier of already started sequence"));
   }
   if (Martingale.Multiplier < 0)             return(!onInputError("ValidateInputs(15)  invalid input parameter Martingale.Multiplier: "+ NumberToStr(Martingale.Multiplier, ".1+")));
   sequence.martingaleEnabled = (Martingale.Multiplier > 0);

   // TakeProfit
   bool unsetTpPct = false, unsetTpAbs = false;
   sValue = StrTrim(TakeProfit);
   if (StringLen(sValue) && sValue!="{number}[%]") {
      bool isPercent = StrEndsWith(sValue, "%");
      if (isPercent) sValue = StrTrim(StrLeft(sValue, -1));
      if (!StrIsNumeric(sValue))              return(!onInputError("ValidateInputs(16)  invalid input parameter TakeProfit: "+ DoubleQuoteStr(TakeProfit) +" (not numeric)"));
      double dValue = StrToDouble(sValue);
      if (isPercent) {
         TakeProfit        = NumberToStr(dValue, ".+") +"%";
         tpPct.condition   = true;
         tpPct.value       = dValue;
         tpPct.absValue    = INT_MAX;
         tpPct.description = "profit("+ TakeProfit +")";
         unsetTpAbs        = true;
      }
      else {
         TakeProfit        = DoubleToStr(dValue, 2);
         tpAbs.condition   = true;
         tpAbs.value       = NormalizeDouble(dValue, 2);
         tpAbs.description = "profit("+ TakeProfit +")";
         unsetTpPct        = true;
      }
   }
   else {
      TakeProfit = "";
      unsetTpPct = true;
      unsetTpAbs = true;
   }
   if (tpPct.condition && unsetTpPct) {
      tpPct.condition   = false;
      tpPct.description = "";
   }
   if (tpAbs.condition && unsetTpAbs) {
      tpAbs.condition   = false;
      tpAbs.description = "";
   }

   // StopLoss
   bool unsetSlPct = false, unsetSlAbs = false;
   sValue = StrTrim(StopLoss);
   if (StringLen(sValue) && sValue!="{number}[%]") {
      isPercent = StrEndsWith(sValue, "%");
      if (isPercent) sValue = StrTrim(StrLeft(sValue, -1));
      if (!StrIsNumeric(sValue))              return(!onInputError("ValidateInputs(17)  invalid input parameter StopLoss: "+ DoubleQuoteStr(StopLoss) +" (not numeric)"));
      dValue = StrToDouble(sValue);
      if (isPercent) {
         StopLoss          = NumberToStr(dValue, ".+") +"%";
         slPct.condition   = true;
         slPct.value       = dValue;
         slPct.absValue    = INT_MIN;
         slPct.description = "loss("+ StopLoss +")";
         unsetSlAbs        = true;
      }
      else {
         StopLoss          = DoubleToStr(dValue, 2);
         slAbs.condition   = true;
         slAbs.value       = NormalizeDouble(dValue, 2);
         slAbs.description = "loss("+ StopLoss +")";
         unsetSlPct        = true;
      }
   }
   else {
      StopLoss   = "";
      unsetSlPct = true;
      unsetSlAbs = true;
   }
   if (slPct.condition && unsetSlPct) {
      slPct.condition   = false;
      slPct.description = "";
   }
   if (slAbs.condition && unsetSlAbs) {
      slAbs.condition   = false;
      slAbs.description = "";
   }

   // Sessionbreak.StartTime/EndTime
   if (Sessionbreak.StartTime!=prev.Sessionbreak.StartTime || Sessionbreak.EndTime!=prev.Sessionbreak.EndTime) {
      sessionbreak.starttime = NULL;                              // actual times are updated automatically on next use
      sessionbreak.endtime   = NULL;
   }
   return(!catch("ValidateInputs(18)"));
}


/**
 * Error handler for invalid input parameters. Depending on the execution context a (non-)terminating error is set.
 *
 * @param  string message - error message
 *
 * @return int - error status
 */
int onInputError(string message) {
   int error = ERR_INVALID_PARAMETER;

   if (ProgramInitReason() == IR_PARAMETERS)
      return(logError(message, error));                           // a non-terminating error
   return(catch(message, error));
}


/**
 * Add an order record to the order arrays. All records are ordered ascending by grid level and the new record is inserted at
 * the correct position. No data is overwritten.
 *
 * @param  int      direction
 * @param  int      ticket
 * @param  int      level
 * @param  double   lots
 * @param  int      pendingType
 * @param  datetime pendingTime
 * @param  double   pendingPrice
 * @param  int      type
 * @param  datetime openTime
 * @param  double   openPrice
 * @param  datetime closeTime
 * @param  double   closePrice
 * @param  double   swap
 * @param  double   commission
 * @param  double   profit
 *
 * @return int - index the record was inserted at or EMPTY (-1) in case of errors
 */
int Orders.AddRecord(int direction, int ticket, int level, double lots, int pendingType, datetime pendingTime, double pendingPrice, int type, datetime openTime, double openPrice, datetime closeTime, double closePrice, double swap, double commission, double profit) {
   int i = EMPTY;

   if (direction == D_LONG) {
      int size = ArraySize(long.ticket);

      for (i=0; i < size; i++) {
         if (long.level[i] == level) return(_EMPTY(catch("Orders.AddRecord(1)  "+ sequence.name +" cannot overwrite ticket #"+ long.ticket[i] +" of level "+ level +" (index "+ i +")", ERR_ILLEGAL_STATE)));
         if (long.level[i] > level)  break;
      }
      ArrayInsertInt   (long.ticket,       i, ticket                               );
      ArrayInsertInt   (long.level,        i, level                                );
      ArrayInsertDouble(long.lots,         i, NormalizeDouble(lots, 2)             );
      ArrayInsertInt   (long.pendingType,  i, pendingType                          );
      ArrayInsertInt   (long.pendingTime,  i, pendingTime                          );
      ArrayInsertDouble(long.pendingPrice, i, NormalizeDouble(pendingPrice, Digits));
      ArrayInsertInt   (long.type,         i, type                                 );
      ArrayInsertInt   (long.openTime,     i, openTime                             );
      ArrayInsertDouble(long.openPrice,    i, openPrice                            );
      ArrayInsertInt   (long.closeTime,    i, closeTime                            );
      ArrayInsertDouble(long.closePrice,   i, closePrice                           );
      ArrayInsertDouble(long.swap,         i, swap                                 );
      ArrayInsertDouble(long.commission,   i, commission                           );
      ArrayInsertDouble(long.profit,       i, profit                               );
   }

   else if (direction == D_SHORT) {
      size = ArraySize(short.ticket);

      for (i=0; i < size; i++) {
         if (short.level[i] == level) return(_EMPTY(catch("Orders.AddRecord(2)  "+ sequence.name +" cannot overwrite ticket #"+ short.ticket[i] +" of level "+ level +" (index "+ i +")", ERR_ILLEGAL_STATE)));
         if (short.level[i] > level)  break;
      }
      ArrayInsertInt   (short.ticket,       i, ticket                               );
      ArrayInsertInt   (short.level,        i, level                                );
      ArrayInsertDouble(short.lots,         i, NormalizeDouble(lots, 2)             );
      ArrayInsertInt   (short.pendingType,  i, pendingType                          );
      ArrayInsertInt   (short.pendingTime,  i, pendingTime                          );
      ArrayInsertDouble(short.pendingPrice, i, NormalizeDouble(pendingPrice, Digits));
      ArrayInsertInt   (short.type,         i, type                                 );
      ArrayInsertInt   (short.openTime,     i, openTime                             );
      ArrayInsertDouble(short.openPrice,    i, openPrice                            );
      ArrayInsertInt   (short.closeTime,    i, closeTime                            );
      ArrayInsertDouble(short.closePrice,   i, closePrice                           );
      ArrayInsertDouble(short.swap,         i, swap                                 );
      ArrayInsertDouble(short.commission,   i, commission                           );
      ArrayInsertDouble(short.profit,       i, profit                               );
   }
   else return(_EMPTY(catch("Orders.AddRecord(3)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER)));

   return(ifInt(catch("Orders.AddRecord(4)"), EMPTY, i));
}


/**
 * Remove the order record at the specified offset from the order arrays. After removal the array size has decreased.
 *
 * @param  int direction
 * @param  int offset    - position (array index) of the record to remove
 *
 * @return bool - success status
 */
bool Orders.RemoveRecord(int direction, int offset) {
   if (direction == D_LONG) {
      if (offset < 0 || offset >= ArraySize(long.ticket)) return(!catch("Orders.RemoveRecord(1)  "+ sequence.name +" invalid parameter offset: "+ offset +" (long order array size: "+ ArraySize(long.ticket) +")", ERR_INVALID_PARAMETER));
      ArraySpliceInts   (long.ticket,       offset, 1);
      ArraySpliceInts   (long.level,        offset, 1);
      ArraySpliceDoubles(long.lots,         offset, 1);
      ArraySpliceInts   (long.pendingType,  offset, 1);
      ArraySpliceInts   (long.pendingTime,  offset, 1);
      ArraySpliceDoubles(long.pendingPrice, offset, 1);
      ArraySpliceInts   (long.type,         offset, 1);
      ArraySpliceInts   (long.openTime,     offset, 1);
      ArraySpliceDoubles(long.openPrice,    offset, 1);
      ArraySpliceInts   (long.closeTime,    offset, 1);
      ArraySpliceDoubles(long.closePrice,   offset, 1);
      ArraySpliceDoubles(long.swap,         offset, 1);
      ArraySpliceDoubles(long.commission,   offset, 1);
      ArraySpliceDoubles(long.profit,       offset, 1);
   }
   else if (direction == D_SHORT) {
      if (offset < 0 || offset >= ArraySize(short.ticket)) return(!catch("Orders.RemoveRecord(2)  "+ sequence.name +" invalid parameter offset: "+ offset +" (short order array size: "+ ArraySize(short.ticket) +")", ERR_INVALID_PARAMETER));
      ArraySpliceInts   (short.ticket,       offset, 1); catch("RemoveRecord(0.2)");
      ArraySpliceInts   (short.level,        offset, 1); catch("RemoveRecord(0.3)");
      ArraySpliceDoubles(short.lots,         offset, 1); catch("RemoveRecord(0.4)");
      ArraySpliceInts   (short.pendingType,  offset, 1); catch("RemoveRecord(0.5)");
      ArraySpliceInts   (short.pendingTime,  offset, 1); catch("RemoveRecord(0.6)");
      ArraySpliceDoubles(short.pendingPrice, offset, 1); catch("RemoveRecord(0.7)");
      ArraySpliceInts   (short.type,         offset, 1); catch("RemoveRecord(0.8)");
      ArraySpliceInts   (short.openTime,     offset, 1); catch("RemoveRecord(0.9)");
      ArraySpliceDoubles(short.openPrice,    offset, 1); catch("RemoveRecord(0.10)");
      ArraySpliceInts   (short.closeTime,    offset, 1); catch("RemoveRecord(0.11)");
      ArraySpliceDoubles(short.closePrice,   offset, 1); catch("RemoveRecord(0.12)");
      ArraySpliceDoubles(short.swap,         offset, 1); catch("RemoveRecord(0.13)");
      ArraySpliceDoubles(short.commission,   offset, 1); catch("RemoveRecord(0.14)");
      ArraySpliceDoubles(short.profit,       offset, 1); catch("RemoveRecord(0.15)");
   }
   else return(!catch("Orders.RemoveRecord(3)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   return(!catch("Orders.RemoveRecord(4)"));
}


/**
 * Reset the specified order log and statistics.
 *
 * @param  int direction - D_LONG:  long orders
 *                         D_SHORT: short orders
 *
 * @return bool - success status
 */
bool ResetOrderLog(int direction) {
   if (direction == D_LONG) {
      long.enabled  = false;
      long.slippage = 0;
      long.openLots = 0;
      long.openPL   = 0;
      long.closedPL = 0;
      long.minLevel = INT_MAX;
      long.maxLevel = INT_MIN;

      ArrayResize(long.ticket,       0);
      ArrayResize(long.level,        0);
      ArrayResize(long.lots,         0);
      ArrayResize(long.pendingType,  0);
      ArrayResize(long.pendingTime,  0);
      ArrayResize(long.pendingPrice, 0);
      ArrayResize(long.type,         0);
      ArrayResize(long.openTime,     0);
      ArrayResize(long.openPrice,    0);
      ArrayResize(long.closeTime,    0);
      ArrayResize(long.closePrice,   0);
      ArrayResize(long.swap,         0);
      ArrayResize(long.commission,   0);
      ArrayResize(long.profit,       0);
      return(true);
   }

   if (direction == D_SHORT) {
      short.enabled  = false;
      short.slippage = 0;
      short.openLots = 0;
      short.openPL   = 0;
      short.closedPL = 0;
      short.minLevel = INT_MAX;
      short.maxLevel = INT_MIN;

      ArrayResize(short.ticket,       0);
      ArrayResize(short.level,        0);
      ArrayResize(short.lots,         0);
      ArrayResize(short.pendingType,  0);
      ArrayResize(short.pendingTime,  0);
      ArrayResize(short.pendingPrice, 0);
      ArrayResize(short.type,         0);
      ArrayResize(short.openTime,     0);
      ArrayResize(short.openPrice,    0);
      ArrayResize(short.closeTime,    0);
      ArrayResize(short.closePrice,   0);
      ArrayResize(short.swap,         0);
      ArrayResize(short.commission,   0);
      ArrayResize(short.profit,       0);
      return(true);
   }

   return(!catch("ResetOrderLog(1)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
}


/**
 * Open a market position at the current price.
 *
 * @param  _In_  int direction - trade direction
 * @param  _In_  int level     - order gridlevel
 * @param  _Out_ int oe[]      - execution details (struct ORDER_EXECUTION)
 *
 * @return int - order ticket or NULL in case of errors
 */
int SubmitMarketOrder(int direction, int level, int oe[]) {
   if (IsLastError())                           return(NULL);
   if (sequence.status != STATUS_PROGRESSING)   return(!catch("SubmitMarketOrder(1)  "+ sequence.name +" cannot submit market order for "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("SubmitMarketOrder(2)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (!level || level==-1)                     return(!catch("SubmitMarketOrder(3)  "+ sequence.name +" invalid parameter level: "+ level, ERR_INVALID_PARAMETER));

   int      type        = ifInt(direction==D_LONG, OP_BUY, OP_SELL);
   double   lots        = CalculateLots(direction, level);
   double   price       = NULL;
   int      slippage    = 1;
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   int      magicNumber = CreateMagicNumber();
   datetime expires     = NULL;
   string   comment     = "Duel."+ ifString(direction==D_LONG, "L.", "S.") + sequence.id +"."+ NumberToStr(level, "+.");
   color    markerColor = ifInt(direction==D_LONG, CLR_LONG, CLR_SHORT);
   int      oeFlags     = NULL;

   int ticket = OrderSendEx(Symbol(), type, lots, price, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (ticket > 0) return(ticket);

   return(!SetLastError(oe.Error(oe)));
}


/**
 * Open a pending limit order.
 *
 * @param  _In_  int direction - trade direction
 * @param  _In_  int level     - order gridlevel
 * @param  _Out_ int oe[]      - execution details (struct ORDER_EXECUTION)
 *
 * @return int - order ticket or NULL in case of errors
 */
int SubmitLimitOrder(int direction, int level, int &oe[]) {
   if (IsLastError())                           return(NULL);
   if (sequence.status!=STATUS_PROGRESSING)     return(!catch("SubmitLimitOrder(1)  "+ sequence.name +" cannot submit limit order for "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("SubmitLimitOrder(2)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (!level || level==-1)                     return(!catch("SubmitLimitOrder(3)  "+ sequence.name +" invalid parameter level: "+ level, ERR_INVALID_PARAMETER));

   int      type        = ifInt(direction==D_LONG, OP_BUYLIMIT, OP_SELLLIMIT);
   double   lots        = CalculateLots(direction, level);
   double   price       = CalculateGridLevel(direction, level);
   int      slippage    = NULL;
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   int      magicNumber = CreateMagicNumber();
   datetime expires     = NULL;
   string   comment     = "Duel."+ ifString(direction==D_LONG, "L.", "S.") + sequence.id +"."+ NumberToStr(level, "+.");
   color    markerColor = CLR_PENDING;
   int      oeFlags     = F_ERR_INVALID_STOP;         // custom handling of ERR_INVALID_STOP (market violated)

   int ticket = OrderSendEx(Symbol(), type, lots, price, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (ticket > 0) return(ticket);

   int error = oe.Error(oe);
   if (error != ERR_INVALID_STOP)
      SetLastError(error);
   return(NULL);
}


/**
 * Open a pending stop order.
 *
 * @param  _In_  int direction - trade direction
 * @param  _In_  int level     - order gridlevel
 * @param  _Out_ int oe[]      - execution details (struct ORDER_EXECUTION)
 *
 * @return int - order ticket or NULL in case of errors
 */
int SubmitStopOrder(int direction, int level, int &oe[]) {
   if (IsLastError())                           return(NULL);
   if (sequence.status!=STATUS_PROGRESSING)     return(!catch("SubmitStopOrder(1)  "+ sequence.name +" cannot submit stop order for "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("SubmitStopOrder(2)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   if (!level || level==-1)                     return(!catch("SubmitStopOrder(3)  "+ sequence.name +" invalid parameter level: "+ level, ERR_INVALID_PARAMETER));

   int      type        = ifInt(direction==D_LONG, OP_BUYSTOP, OP_SELLSTOP);
   double   lots        = CalculateLots(direction, level);
   double   price       = CalculateGridLevel(direction, level);
   int      slippage    = NULL;
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   int      magicNumber = CreateMagicNumber();
   datetime expires     = NULL;
   string   comment     = "Duel."+ ifString(direction==D_LONG, "L.", "S.") + sequence.id +"."+ NumberToStr(level, "+.");
   color    markerColor = CLR_PENDING;
   int      oeFlags     = F_ERR_INVALID_STOP;         // custom handling of ERR_INVALID_STOP (market violated)

   int ticket = OrderSendEx(Symbol(), type, lots, price, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (ticket > 0) return(ticket);

   int error = oe.Error(oe);
   if (error != ERR_INVALID_STOP)
      SetLastError(error);
   return(NULL);
}


/**
 * Calculate and return the average daily range. Implemented as LWMA(20, ATR(1)).
 *
 * @return double - ADR in absolute terms or NULL in case of errors
 */
double iADR() {
   static double adr;                                       // TODO: invalidate static cache on BarOpen(D1)
   if (!adr) {
      double ranges[];
      int maPeriods = 20;
      ArrayResize(ranges, maPeriods);
      ArraySetAsSeries(ranges, true);
      for (int i=0; i < maPeriods; i++) {
         ranges[i] = iATR(NULL, PERIOD_D1, 1, i+1);         // TODO: convert to current timeframe for non-FXT brokers
      }
      adr = iMAOnArray(ranges, WHOLE_ARRAY, maPeriods, 0, MODE_LWMA, 0);
   }
   return(adr);
}


/**
 * Write the current sequence status to a file.
 *
 * @return bool - success status
 */
bool SaveStatus() {
   if (last_error || !sequence.id) return(false);

   // In tester skip updating the status file on most calls; except at the first one, after sequence stop and at test end.
   if (IsTesting() && test.reduceStatusWrites) {
      static bool saved = false;
      if (saved && sequence.status!=STATUS_STOPPED && __CoreFunction!=CF_DEINIT) return(true);
      saved = true;
   }

   string section, file=GetStatusFilename(), separator="";
   if (!IsFileA(file)) separator = CRLF;                                   // an empty line as additional section separator

   // [General]
   section = "General";
   WriteIniString(file, section, "Account", GetAccountCompany() +":"+ GetAccountNumber());
   WriteIniString(file, section, "Symbol",  Symbol());
   WriteIniString(file, section, "Created", GmtTimeFormat(sequence.created, "%a, %Y.%m.%d %H:%M:%S") + separator);

   // [Inputs]
   section = "Inputs";
   WriteIniString(file, section, "Sequence.ID",            /*string  */ Sequence.ID);
   WriteIniString(file, section, "GridDirection",          /*string  */ GridDirection);
   WriteIniString(file, section, "GridVolatility",         /*string  */ GridVolatility);
   WriteIniString(file, section, "GridSize",               /*double  */ NumberToStr(GridSize, ".+"));
   WriteIniString(file, section, "UnitSize",               /*double  */ NumberToStr(UnitSize, ".+"));

   WriteIniString(file, section, "Pyramid.Multiplier",     /*double  */ NumberToStr(Pyramid.Multiplier, ".+"));
   WriteIniString(file, section, "Martingale.Multiplier",  /*double  */ NumberToStr(Martingale.Multiplier, ".+"));

   WriteIniString(file, section, "TakeProfit",             /*string  */ TakeProfit);
   WriteIniString(file, section, "StopLoss",               /*string  */ StopLoss);
   WriteIniString(file, section, "ShowProfitInPercent",    /*bool    */ ShowProfitInPercent);

   WriteIniString(file, section, "Sessionbreak.StartTime", /*datetime*/ Sessionbreak.StartTime);
   WriteIniString(file, section, "Sessionbreak.EndTime",   /*datetime*/ Sessionbreak.EndTime + separator);

   // [Runtime status]
   section = "Runtime status";      // On deletion of pending orders the number of stored order records decreases. To prevent
   EmptyIniSectionA(file, section); // orphaned records in the status file the section is emptied before writing to it.

   // sequence data
   WriteIniString(file, section, "sequence.id",                /*int     */ sequence.id               );
   WriteIniString(file, section, "sequence.created",           /*datetime*/ sequence.created          );
   WriteIniString(file, section, "sequence.isTest",            /*bool    */ sequence.isTest           );
   WriteIniString(file, section, "sequence.name",              /*string  */ sequence.name             );
   WriteIniString(file, section, "sequence.status",            /*int     */ sequence.status           );
   WriteIniString(file, section, "sequence.direction",         /*int     */ sequence.direction        );
   WriteIniString(file, section, "sequence.pyramidEnabled",    /*bool    */ sequence.pyramidEnabled   );
   WriteIniString(file, section, "sequence.martingaleEnabled", /*bool    */ sequence.martingaleEnabled);
   WriteIniString(file, section, "sequence.startEquity",       /*double  */ sequence.startEquity      );
   WriteIniString(file, section, "sequence.gridvola",          /*double  */ sequence.gridvola         );
   WriteIniString(file, section, "sequence.gridsize",          /*double  */ sequence.gridsize         );
   WriteIniString(file, section, "sequence.unitsize",          /*double  */ sequence.unitsize         );
   WriteIniString(file, section, "sequence.gridbase",          /*double  */ sequence.gridbase         );
   WriteIniString(file, section, "sequence.openLots",          /*double  */ sequence.openLots         );
   WriteIniString(file, section, "sequence.hedgedPL",          /*double  */ sequence.hedgedPL         );
   WriteIniString(file, section, "sequence.floatingPL",        /*double  */ sequence.floatingPL       );
   WriteIniString(file, section, "sequence.openPL",            /*double  */ sequence.openPL           );
   WriteIniString(file, section, "sequence.closedPL",          /*double  */ sequence.closedPL         );
   WriteIniString(file, section, "sequence.totalPL",           /*double  */ sequence.totalPL          );
   WriteIniString(file, section, "sequence.maxProfit",         /*double  */ sequence.maxProfit        );
   WriteIniString(file, section, "sequence.maxDrawdown",       /*double  */ sequence.maxDrawdown      );
   WriteIniString(file, section, "sequence.bePrice.long",      /*double  */ sequence.bePrice.long     );
   WriteIniString(file, section, "sequence.bePrice.short",     /*double  */ sequence.bePrice.short    );
   WriteIniString(file, section, "sequence.tpPrice",           /*double  */ sequence.tpPrice          );
   WriteIniString(file, section, "sequence.slPrice",           /*double  */ sequence.slPrice + CRLF   );

   // long order data
   WriteIniString(file, section, "long.enabled",               /*bool    */ long.enabled);
   int size = ArraySize(long.ticket);
   for (int i=0; i < size; i++) {
      WriteIniString(file, section, "long.order."+ StrPadLeft(i, 4, "0"), SaveStatus.OrderToStr(i, D_LONG));
   }
   WriteIniString(file, section, "long.slippage",              /*double  */ long.slippage);
   WriteIniString(file, section, "long.openLots",              /*double  */ long.openLots);
   WriteIniString(file, section, "long.openPL",                /*double  */ long.openPL  );
   WriteIniString(file, section, "long.closedPL",              /*double  */ long.closedPL);
   WriteIniString(file, section, "long.minLevel",              /*int     */ long.minLevel);
   WriteIniString(file, section, "long.maxLevel",              /*int     */ long.maxLevel + CRLF);

   // short order data
   WriteIniString(file, section, "short.enabled",              /*bool    */ short.enabled);
   size = ArraySize(short.ticket);
   for (i=0; i < size; i++) {
      WriteIniString(file, section, "short.order."+ StrPadLeft(i, 4, "0"), SaveStatus.OrderToStr(i, D_SHORT));
   }
   WriteIniString(file, section, "short.slippage",             /*double  */ short.slippage);
   WriteIniString(file, section, "short.openLots",             /*double  */ short.openLots);
   WriteIniString(file, section, "short.openPL",               /*double  */ short.openPL  );
   WriteIniString(file, section, "short.closedPL",             /*double  */ short.closedPL);
   WriteIniString(file, section, "short.minLevel",             /*int     */ short.minLevel);
   WriteIniString(file, section, "short.maxLevel",             /*int     */ short.maxLevel + CRLF);

   // other
   WriteIniString(file, section, "tpAbs.condition",            /*bool    */ tpAbs.condition  );
   WriteIniString(file, section, "tpAbs.value",                /*double  */ tpAbs.value      );
   WriteIniString(file, section, "tpAbs.description",          /*string  */ tpAbs.description);
   WriteIniString(file, section, "tpPct.condition",            /*bool    */ tpPct.condition  );
   WriteIniString(file, section, "tpPct.value",                /*double  */ tpPct.value      );
   WriteIniString(file, section, "tpPct.absValue",             /*double  */ tpPct.absValue   );
   WriteIniString(file, section, "tpPct.description",          /*string  */ tpPct.description + CRLF);

   WriteIniString(file, section, "slAbs.condition",            /*bool    */ slAbs.condition  );
   WriteIniString(file, section, "slAbs.value",                /*double  */ slAbs.value      );
   WriteIniString(file, section, "slAbs.description",          /*string  */ slAbs.description);
   WriteIniString(file, section, "slPct.condition",            /*bool    */ slPct.condition  );
   WriteIniString(file, section, "slPct.value",                /*double  */ slPct.value      );
   WriteIniString(file, section, "slPct.absValue",             /*double  */ slPct.absValue   );
   WriteIniString(file, section, "slPct.description",          /*string  */ slPct.description + CRLF);

   WriteIniString(file, section, "sessionbreak.starttime",     /*datetime*/ sessionbreak.starttime);
   WriteIniString(file, section, "sessionbreak.endtime",       /*datetime*/ sessionbreak.endtime  );

   return(!catch("SaveStatus(1)"));
}


/**
 * Restore the internal state of the EA from a status file. Requires 'sequence.id' and 'sequence.isTest' to be set.
 *
 * @return bool - success status
 */
bool RestoreSequence() {
   if (IsLastError())          return(false);
   if (!ReadStatus())          return(false);              // read and apply the status file
   //if (!ValidateInputs())    return(false);              // validate restored input parameters
   //if (!SynchronizeStatus()) return(false);              // synchronize restored state with the trade server
   return(true);
}


/**
 * Read the status file of the current sequence and restore all internal variables. Called only from RestoreSequence().
 * Only a syntactic variables check is performed (i.e. type match). Logical validation happens in ValidateInputs().
 *
 * @return bool - success status
 */
bool ReadStatus() {
   if (IsLastError()) return(false);
   if (!sequence.id)  return(!catch("ReadStatus(1)  "+ sequence.name +" illegal value of sequence.id: "+ sequence.id, ERR_ILLEGAL_STATE));

   string section, file=GetStatusFilename();
   if (!IsFileA(file)) return(!catch("ReadStatus(2)  "+ sequence.name +" status file "+ DoubleQuoteStr(file) +" not found", ERR_FILE_NOT_FOUND));

   // [General]
   section = "General";
   string sAccount = GetIniStringA(file, section, "Account", "");                               // string Account = ICMarkets:12345678
   string sSymbol  = GetIniStringA(file, section, "Symbol",  "");                               // string Symbol  = EURUSD
   string sThisAccount = GetAccountCompany() +":"+ GetAccountNumber();
   if (!StrCompareI(sAccount, sThisAccount)) return(!catch("ReadStatus(3)  "+ sequence.name +" account mis-match: "+ DoubleQuoteStr(sThisAccount) +" vs. "+ DoubleQuoteStr(sAccount) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));
   if (!StrCompareI(sSymbol, Symbol()))      return(!catch("ReadStatus(4)  "+ sequence.name +" symbol mis-match: "+ Symbol() +" vs. "+ sSymbol +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));

   // [Inputs]
   section = "Inputs";
   string sSequenceID            = GetIniStringA(file, section, "Sequence.ID",            "");  // string   Sequence.ID            = T1234
   string sGridDirection         = GetIniStringA(file, section, "GridDirection",          "");  // string   GridDirection          = Long
   string sGridVolatility        = GetIniStringA(file, section, "GridVolatility",         "");  // string   GridVolatility         = 30%
   string sGridSize              = GetIniStringA(file, section, "GridSize",               "");  // double   GridSize               = 2.3
   string sUnitSize              = GetIniStringA(file, section, "UnitSize",               "");  // double   UnitSize               = 0.01
   string sPyramidMultiplier     = GetIniStringA(file, section, "Pyramid.Multiplier",     "");  // double   Pyramid.Multiplier     = 1.1
   string sMartingaleMultiplier  = GetIniStringA(file, section, "Martingale.Multiplier",  "");  // double   Martingale.Multiplier  = 1.1
   string sTakeProfit            = GetIniStringA(file, section, "TakeProfit",             "");  // string   TakeProfit             = 3%
   string sStopLoss              = GetIniStringA(file, section, "StopLoss",               "");  // string   StopLoss               = 20.00
   string sShowProfitInPercent   = GetIniStringA(file, section, "ShowProfitInPercent",    "");  // bool     ShowProfitInPercent    = 1
   string sSessionbreakStartTime = GetIniStringA(file, section, "Sessionbreak.StartTime", "");  // datetime Sessionbreak.StartTime = 86160
   string sSessionbreakEndTime   = GetIniStringA(file, section, "Sessionbreak.EndTime",   "");  // datetime Sessionbreak.EndTime   = 3730

   if (!StrIsNumeric(sGridSize))             return(!catch("ReadStatus(5)  "+ sequence.name +" invalid input parameter GridSize "+ DoubleQuoteStr(sGridSize) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   if (!StrIsNumeric(sUnitSize))             return(!catch("ReadStatus(6)  "+ sequence.name +" invalid input parameter UnitSize "+ DoubleQuoteStr(sUnitSize) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   if (!StrIsNumeric(sPyramidMultiplier))    return(!catch("ReadStatus(7)  "+ sequence.name +" invalid input parameter Pyramid.Multiplier "+ DoubleQuoteStr(sPyramidMultiplier) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   if (!StrIsNumeric(sMartingaleMultiplier)) return(!catch("ReadStatus(8)  "+ sequence.name +" invalid input parameter Martingale.Multiplier "+ DoubleQuoteStr(sMartingaleMultiplier) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   if (!StrIsDigit(sSessionbreakStartTime))  return(!catch("ReadStatus(9)  "+ sequence.name +" invalid input parameter Sessionbreak.StartTime "+ DoubleQuoteStr(sSessionbreakStartTime) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));
   if (!StrIsDigit(sSessionbreakEndTime))    return(!catch("ReadStatus(10)  "+ sequence.name +" invalid input parameter Sessionbreak.EndTime "+ DoubleQuoteStr(sSessionbreakEndTime) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));

   Sequence.ID            = sSequenceID;
   GridDirection          = sGridDirection;
   GridVolatility         = sGridVolatility;
   GridSize               = StrToDouble(sGridSize);
   UnitSize               = StrToDouble(sUnitSize);
   Pyramid.Multiplier     = StrToDouble(sPyramidMultiplier);
   Martingale.Multiplier  = StrToDouble(sMartingaleMultiplier);
   TakeProfit             = sTakeProfit;
   StopLoss               = sStopLoss;
   ShowProfitInPercent    = StrToBool(sShowProfitInPercent);
   Sessionbreak.StartTime = StrToInteger(sSessionbreakStartTime);
   Sessionbreak.EndTime   = StrToInteger(sSessionbreakEndTime);

   // [Runtime status]
   section = "Runtime status";
   // sequence data
   sequence.id                = GetIniInt    (file, section, "sequence.id"               );     // int      sequence.id                = 1234
   sequence.created           = GetIniInt    (file, section, "sequence.created"          );     // datetime sequence.created           = 1624924800
   sequence.isTest            = GetIniBool   (file, section, "sequence.isTest"           );     // bool     sequence.isTest            = 1
   sequence.name              = GetIniStringA(file, section, "sequence.name",          "");     // string   sequence.name              = L.1234
   sequence.status            = GetIniInt    (file, section, "sequence.status"           );     // int      sequence.status            = 1
   sequence.direction         = GetIniInt    (file, section, "sequence.direction"        );     // int      sequence.direction         = 2
   sequence.pyramidEnabled    = GetIniBool   (file, section, "sequence.pyramidEnabled"   );     // bool     sequence.pyramidEnabled    = 1
   sequence.martingaleEnabled = GetIniBool   (file, section, "sequence.martingaleEnabled");     // bool     sequence.martingaleEnabled = 0
   sequence.startEquity       = GetIniDouble (file, section, "sequence.startEquity"      );     // double   sequence.startEquity       = 1000.00
   sequence.gridvola          = GetIniDouble (file, section, "sequence.gridvola"         );     // double   sequence.gridvola          = 29.5
   sequence.gridsize          = GetIniDouble (file, section, "sequence.gridsize"         );     // double   sequence.gridsize          = 3.5
   sequence.unitsize          = GetIniDouble (file, section, "sequence.unitsize"         );     // double   sequence.unitsize          = 0.01
   sequence.gridbase          = GetIniDouble (file, section, "sequence.gridbase"         );     // double   sequence.gridbase          = 1.17453
   sequence.openLots          = GetIniDouble (file, section, "sequence.openLots"         );     // double   sequence.openLots          = 0.12
   sequence.hedgedPL          = GetIniDouble (file, section, "sequence.hedgedPL"         );     // double   sequence.hedgedPL          = 34.56
   sequence.floatingPL        = GetIniDouble (file, section, "sequence.floatingPL"       );     // double   sequence.floatingPL        = 12.34
   sequence.openPL            = GetIniDouble (file, section, "sequence.openPL"           );     // double   sequence.openPL            = 23.45
   sequence.closedPL          = GetIniDouble (file, section, "sequence.closedPL"         );     // double   sequence.closedPL          = 45.67
   sequence.totalPL           = GetIniDouble (file, section, "sequence.totalPL"          );     // double   sequence.totalPL           = 123.45
   sequence.maxProfit         = GetIniDouble (file, section, "sequence.maxProfit"        );     // double   sequence.maxProfit         = 23.45
   sequence.maxDrawdown       = GetIniDouble (file, section, "sequence.maxDrawdown"      );     // double   sequence.maxDrawdown       = -11.23
   sequence.bePrice.long      = GetIniDouble (file, section, "sequence.bePrice.long"     );     // double   sequence.bePrice.long      = 1.17453
   sequence.bePrice.short     = GetIniDouble (file, section, "sequence.bePrice.short"    );     // double   sequence.bePrice.short     = 0
   sequence.tpPrice           = GetIniDouble (file, section, "sequence.tpPrice"          );     // double   sequence.tpPrice           = 1.17692
   sequence.slPrice           = GetIniDouble (file, section, "sequence.slPrice"          );     // double   sequence.slPrice           = 1.17051

   // long order data
   ResetOrderLog(D_LONG);
   long.enabled               = GetIniBool   (file, section, "long.enabled" );                  // bool     long.enabled  = 1
   long.slippage              = GetIniDouble (file, section, "long.slippage");                  // double   long.slippage = 0
   long.openLots              = GetIniDouble (file, section, "long.openLots");                  // double   long.openLots = 0.02
   long.openPL                = GetIniDouble (file, section, "long.openPL"  );                  // double   long.openPL   = 12.34
   long.closedPL              = GetIniDouble (file, section, "long.closedPL");                  // double   long.closedPL = 23.34
   long.minLevel              = GetIniInt    (file, section, "long.minLevel");                  // int      long.minLevel = -2
   long.maxLevel              = GetIniInt    (file, section, "long.maxLevel");                  // int      long.maxLevel = 7
   string sKeys[], sOrder;
   int size = ReadStatus.OrderKeys(file, section, sKeys, D_LONG); if (size < 0) return(false);
   for (int i=0; i < size; i++) {
      sOrder = GetIniStringA(file, section, sKeys[i], "");                                      // long.order.{i} = {data}
      if (!ReadStatus.ParseOrder(sOrder, D_LONG)) return(!catch("ReadStatus(11)  "+ sequence.name +" invalid order record in status file "+ DoubleQuoteStr(file) + NL + sKeys[i] +"="+ sOrder, ERR_INVALID_FILE_FORMAT));
   }

   // short order data
   ResetOrderLog(D_SHORT);
   short.enabled              = GetIniBool   (file, section, "short.enabled" );                 // bool     short.enabled  = 1
   short.slippage             = GetIniDouble (file, section, "short.slippage");                 // double   short.slippage = 0
   short.openLots             = GetIniDouble (file, section, "short.openLots");                 // double   short.openLots = 0.02
   short.openPL               = GetIniDouble (file, section, "short.openPL"  );                 // double   short.openPL   = 12.34
   short.closedPL             = GetIniDouble (file, section, "short.closedPL");                 // double   short.closedPL = 23.34
   short.minLevel             = GetIniInt    (file, section, "short.minLevel");                 // int      short.minLevel = -2
   short.maxLevel             = GetIniInt    (file, section, "short.maxLevel");                 // int      short.maxLevel = 7
   size = ReadStatus.OrderKeys(file, section, sKeys, D_SHORT); if (size < 0) return(false);
   for (i=0; i < size; i++) {
      sOrder = GetIniStringA(file, section, sKeys[i], "");                                      // short.order.{i} = {data}
      if (!ReadStatus.ParseOrder(sOrder, D_SHORT)) return(!catch("ReadStatus(12)  "+ sequence.name +" invalid order record in status file "+ DoubleQuoteStr(file) + NL + sKeys[i] +"="+ sOrder, ERR_INVALID_FILE_FORMAT));
   }

}


/**
 * Read and return the keys of the specified order records found in the status file, sorted in ascending order.
 *
 * @param  _In_  string file      - status filename
 * @param  _In_  string section   - status section
 * @param  _Out_ string &keys[]   - array receiving the found keys
 * @param  _In_  int    direction - D_LONG:  return long order records  (matching "long.order.{i}={data}")
 *                                  D_SHORT: return short order records (matching "short.order.{i}={data}")
 *
 * @return int - number of found keys or EMPTY (-1) in case of errors
 */
int ReadStatus.OrderKeys(string file, string section, string &keys[], int direction) {
   if (direction!=D_LONG && direction!=D_SHORT) return(_EMPTY(catch("ReadStatus.OrderKeys(1)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER)));

   int size = GetIniKeys(file, section, keys);
   if (size < 0) return(EMPTY);

   string prefix = ifString(direction==D_LONG, "long.order.", "short.order.");
   int prefixLen = StringLen(prefix);

   for (int i=size-1; i >= 0; i--) {
      if (StrStartsWithI(keys[i], prefix)) {
         if (StrIsDigit(StrSubstr(keys[i], prefixLen))) {
            continue;
         }
      }
      ArraySpliceStrings(keys, i, 1);                 // drop all non-matching keys
      size--;
   }
   if (!SortStrings(keys)) return(EMPTY);             // TODO: implement natural sorting
   return(size);
}


/**
 * Parse and store the string representation of an order.
 *
 * @param  string value     - string to parse
 * @param  int    direction - order direction type: D_LONG | D_SHORT
 *
 * @return bool - success status
 */
bool ReadStatus.ParseOrder(string value, int direction) {
   if (IsLastError()) return(false);
}


/**
 * Return a string representation of an order record to be stored by SaveStatus().
 *
 * @param  int index     - index of the order record
 * @param  int direction - D_LONG | D_SHORT
 *
 * @return string - string representation or an empty string in case of errors
 */
string SaveStatus.OrderToStr(int index, int direction) {
   int      ticket, level, pendingType, type;
   datetime pendingTime, openTime, closeTime;
   double   lots, pendingPrice, openPrice, closePrice, swap, commission, profit;

   // result: ticket,level,lots,pendingType,pendingTime,pendingPrice,type,openTime,openPrice,closeTime,closePrice,swap,commission,profit

   if (direction == D_LONG) {
      ticket       = long.ticket      [index];
      level        = long.level       [index];
      lots         = long.lots        [index];
      pendingType  = long.pendingType [index];
      pendingTime  = long.pendingTime [index];
      pendingPrice = long.pendingPrice[index];
      type         = long.type        [index];
      openTime     = long.openTime    [index];
      openPrice    = long.openPrice   [index];
      closeTime    = long.closeTime   [index];
      closePrice   = long.closePrice  [index];
      swap         = long.swap        [index];
      commission   = long.commission  [index];
      profit       = long.profit      [index];
   }
   else if (direction == D_SHORT) {
      ticket       = short.ticket      [index];
      level        = short.level       [index];
      lots         = short.lots        [index];
      pendingType  = short.pendingType [index];
      pendingTime  = short.pendingTime [index];
      pendingPrice = short.pendingPrice[index];
      type         = short.type        [index];
      openTime     = short.openTime    [index];
      openPrice    = short.openPrice   [index];
      closeTime    = short.closeTime   [index];
      closePrice   = short.closePrice  [index];
      swap         = short.swap        [index];
      commission   = short.commission  [index];
      profit       = short.profit      [index];
   }
   else return(_EMPTY_STR(catch("SaveStatus.OrderToStr(1)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER)));

   return(StringConcatenate(ticket, ",", level, ",", DoubleToStr(lots, 2), ",", pendingType, ",", pendingTime, ",", DoubleToStr(pendingPrice, Digits), ",", type, ",", openTime, ",", DoubleToStr(openPrice, Digits), ",", closeTime, ",", DoubleToStr(closePrice, Digits), ",", DoubleToStr(swap, 2), ",", DoubleToStr(commission, 2), ",", DoubleToStr(profit, 2)));
}


/**
 * Return a description of a sequence status code.
 *
 * @param  int status
 *
 * @return string - description or an empty string in case of errors
 */
string StatusDescription(int status) {
   switch (status) {
      case STATUS_UNDEFINED  : return("undefined"  );
      case STATUS_WAITING    : return("waiting"    );
      case STATUS_PROGRESSING: return("progressing");
      case STATUS_STOPPED    : return("stopped"    );
   }
   return(_EMPTY_STR(catch("StatusDescription(1)  "+ sequence.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
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
      case STATUS_PROGRESSING: return("STATUS_PROGRESSING");
      case STATUS_STOPPED    : return("STATUS_STOPPED"    );
   }
   return(_EMPTY_STR(catch("StatusToStr(1)  "+ sequence.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Display the current runtime status.
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error or the current error status if no error was passed
 */
int ShowStatus(int error = NO_ERROR) {
   if (!__isChart) return(error);

   static bool isRecursion = false;                   // to prevent recursive calls a specified error is displayed only once
   if (error != 0) {
      if (isRecursion) return(error);
      isRecursion = true;
   }

   string sSequence="", sDirection="", sError="";

   switch (sequence.direction) {
      case D_LONG:  sDirection = "Long";       break;
      case D_SHORT: sDirection = "Short";      break;
      case D_BOTH:  sDirection = "Long+Short"; break;
   }

   switch (sequence.status) {
      case STATUS_UNDEFINED:   sSequence = "not initialized";                                                 break;
      case STATUS_WAITING:     sSequence = StringConcatenate(sDirection, "  ", sequence.id, "  waiting");     break;
      case STATUS_PROGRESSING: sSequence = StringConcatenate(sDirection, "  ", sequence.id, "  progressing"); break;
      case STATUS_STOPPED:     sSequence = StringConcatenate(sDirection, "  ", sequence.id, "  stopped");     break;
      default:
         return(catch("ShowStatus(1)  "+ sequence.name +" illegal sequence status: "+ sequence.status, ERR_ILLEGAL_STATE));
   }
   if (__STATUS_OFF) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason), "]");

   string msg = StringConcatenate(ProgramName(), "           ", sSequence, sError,              NL,
                                                                                                NL,
                                  "Grid:          ",  sGridParameters,                          NL,
                                  "Volatility:   ",   sGridVolatility,                          NL,
                                                                                                NL,
                                  "Long:         ",   sOpenLongLots,                            NL,
                                  "Short:        ",   sOpenShortLots,                           NL,
                                  "Total:         ",  sOpenTotalLots,                           NL,
                                                                                                NL,
                                  "Stop:          ",  sStopConditions,                          NL,
                                  "BE:             ", sSequenceBePrice,                         NL,
                                  "TP:             ", sSequenceTpPrice,                         NL,
                                  "SL:             ", sSequenceSlPrice,                         NL,
                                                                                                NL,
                                  "Profit:        ",  sSequenceTotalPL, "  ", sSequencePlStats, NL
   );

   // 4 lines margin-top for instrument and indicator legends
   Comment(NL, NL, NL, NL, msg);
   if (__CoreFunction == CF_INIT) WindowRedraw();

   // store status in the chart to enable remote access by scripts
   string label = "Duel.status";
   if (ObjectFind(label) != 0) {
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
      RegisterObject(label);
   }
   ObjectSetText(label, StringConcatenate(sequence.id, "|", StatusDescription(sequence.status)));

   error = ifIntOr(catch("ShowStatus(2)"), error);
   isRecursion = false;
   return(error);
}


/**
 * ShowStatus: Update all string representations.
 */
void SS.All() {
   if (__isChart) {
      SS.SequenceName();
      SS.GridParameters();
      SS.StopConditions();
      SS.OpenLots();
      SS.ProfitTargets();
      SS.TotalPL();
      SS.PLStats();
   }
}


/**
 * ShowStatus: Update the string representations of grid parameters and volatility.
 */
void SS.GridParameters() {
   if (__isChart) {
      string sGridSize;
      if      (!sequence.gridsize)         sGridSize = "";
      else if (Digits==2 && Close[0]>=500) sGridSize = NumberToStr(sequence.gridsize/100, ",'R.2");      // 123 pip => 1.23
      else                                 sGridSize = NumberToStr(sequence.gridsize, ".+") +" pip";     // 12.3 pip

      string sUnitSize   = ifString(!sequence.unitsize, "", NumberToStr(sequence.unitsize, ".+") +" lot");
      string sPyramid    = ifString(sequence.pyramidEnabled,    "    Pyramid="+    NumberToStr(Pyramid.Multiplier, ".+"), "");
      string sMartingale = ifString(sequence.martingaleEnabled, "    Martingale="+ NumberToStr(Martingale.Multiplier, ".+"), "");

      if (sequence.gridsize && sequence.unitsize) {
         double adr        = iADR();
         double adrLevels  = adr/Pip/sequence.gridsize + 1;
         double adrLots    = sequence.unitsize * adrLevels;
         double beDistance = adr/2;
         double tickSize   = MarketInfo(Symbol(), MODE_TICKSIZE);
         double tickValue  = MarketInfo(Symbol(), MODE_TICKVALUE);
         double gridPL     = MathDiv(beDistance, tickSize) * tickValue * adrLots;
         double equity     = AccountEquity() - AccountCredit() + GetExternalAssets();     // TODO: should we use sequence.startEquity??
         double vola       = NormalizeDouble(MathDiv(gridPL, equity) * 100, 1);

         sGridParameters = sGridSize +" x "+ sUnitSize + sPyramid + sMartingale;
         sGridVolatility = NumberToStr(vola, ",'.+") +"%/ADR";
      }
      else {
         sGridParameters = "";
         sGridVolatility = "";
      }
   }
}


/**
 * ShowStatus: Update the string representation of "long.openLots", "short.openLots" and "sequence.openLots".
 */
void SS.OpenLots() {
   if (__isChart) {
      string sLevels="", sMinLevel="", sMaxLevel="", sSlippage="";
      int minusLevels;

      if (!long.openLots) sOpenLongLots = "-";
      else {
         sMinLevel   = ifString(long.minLevel==INT_MAX, "", long.minLevel);
         sMaxLevel   = ifString(long.maxLevel==INT_MIN, "", long.maxLevel);
         minusLevels = ifInt(long.minLevel < 0, long.minLevel+1, 0);

         if (sequence.pyramidEnabled && sequence.martingaleEnabled) sLevels = "levels: "+ (ifInt(long.maxLevel==INT_MIN, 0, long.maxLevel) - minusLevels) + ifString(minusLevels, " ("+ minusLevels +")", "");
         else                                                       sLevels = "level: "+ ifString(sequence.pyramidEnabled, sMaxLevel, sMinLevel);

         sSlippage = PipToStr(long.slippage/Pip, true);
         if (GT(long.slippage, 0)) sSlippage = "+"+ sSlippage;

         sOpenLongLots = NumberToStr(long.openLots, "+.+") +" lot    "+ sLevels + ifString(!long.slippage, "", "    slippage: "+ sSlippage);
      }

      if (!short.openLots) sOpenShortLots = "-";
      else {
         sMinLevel   = ifString(short.minLevel==INT_MAX, "", short.minLevel);
         sMaxLevel   = ifString(short.maxLevel==INT_MIN, "", short.maxLevel);
         minusLevels = ifInt(short.minLevel < 0, short.minLevel+1, 0);

         if (sequence.pyramidEnabled && sequence.martingaleEnabled) sLevels = "levels: "+ (ifInt(short.maxLevel==INT_MIN, 0, short.maxLevel) - minusLevels) + ifString(minusLevels, " ("+ minusLevels +")", "");
         else                                                       sLevels = "level: "+ ifString(sequence.pyramidEnabled, sMaxLevel, sMinLevel);

         sSlippage = PipToStr(short.slippage/Pip, true);
         if (GT(short.slippage, 0)) sSlippage = "+"+ sSlippage;

         sOpenShortLots = NumberToStr(-short.openLots, "+.+") +" lot    "+ sLevels + ifString(!short.slippage, "", "    slippage: "+ sSlippage);
      }

      if (!long.openLots && !short.openLots) sOpenTotalLots = "-";
      else if (!sequence.openLots)           sOpenTotalLots = "±0 (hedged)";
      else                                   sOpenTotalLots = NumberToStr(sequence.openLots, "+.+") +" lot";
   }
}


/**
 * ShowStatus: Update the string representation of "sequence.totalPL".
 *
 * @param  bool enforce [optional] - whether to perform the update unconditionally (default: no)
 */
void SS.TotalPL(bool enforce = false) {
   if (__isChart || enforce) {
      // not before a positions was opened
      if (!ArraySize(long.ticket) && !ArraySize(short.ticket)) sSequenceTotalPL = "-";
      else if (ShowProfitInPercent)                            sSequenceTotalPL = NumberToStr(MathDiv(sequence.totalPL, sequence.startEquity) * 100, "+.2") +"%";
      else                                                     sSequenceTotalPL = NumberToStr(sequence.totalPL, "+.2");
   }
}


/**
 * ShowStatus: Update the string representaton of all P/L statistics.
 *
 * @param  bool enforce [optional] - whether to perform the update unconditionally (default: no)
 */
void SS.PLStats(bool enforce = false) {
   if (__isChart || enforce) {
      // not before a positions was opened
      if (!ArraySize(long.ticket) && !ArraySize(short.ticket)) {
         sSequencePlStats = "";
      }
      else {
         string sSequenceMaxProfit, sSequenceMaxDrawdown;
         if (ShowProfitInPercent) {
            sSequenceMaxProfit   = NumberToStr(MathDiv(sequence.maxProfit, sequence.startEquity) * 100, "+.2") +"%";
            sSequenceMaxDrawdown = NumberToStr(MathDiv(sequence.maxDrawdown, sequence.startEquity) * 100, "+.2") +"%";
         }
         else {
            sSequenceMaxProfit   = NumberToStr(sequence.maxProfit, "+.2");
            sSequenceMaxDrawdown = NumberToStr(sequence.maxDrawdown, "+.2");
         }
         sSequencePlStats = StringConcatenate("(", sSequenceMaxProfit, " / ", sSequenceMaxDrawdown, ")");
      }
   }
}


/**
 * ShowStatus: Update the string representation of "sequence.bePrice", "sequence.tpPrice" and "sequence.slPrice".
 */
void SS.ProfitTargets() {
   if (__isChart) {
      sSequenceBePrice = "";
      if (long.enabled) {
         if (!sequence.bePrice.long)     sSequenceBePrice = sSequenceBePrice +"-";
         else                            sSequenceBePrice = sSequenceBePrice + NumberToStr(RoundCeil(sequence.bePrice.long, Digits), PriceFormat);
      }
      if (long.enabled && short.enabled) sSequenceBePrice = sSequenceBePrice +" / ";
      if (short.enabled) {
         if (!sequence.bePrice.short)    sSequenceBePrice = sSequenceBePrice +"-";
         else                            sSequenceBePrice = sSequenceBePrice + NumberToStr(RoundFloor(sequence.bePrice.short, Digits), PriceFormat);
      }

      if      (!sequence.tpPrice)     sSequenceTpPrice = "";
      else if (sequence.openLots > 0) sSequenceTpPrice = NumberToStr(RoundCeil(sequence.tpPrice, Digits), PriceFormat);
      else                            sSequenceTpPrice = NumberToStr(RoundFloor(sequence.tpPrice, Digits), PriceFormat);

      if      (!sequence.slPrice)     sSequenceSlPrice = "";
      else if (sequence.openLots > 0) sSequenceSlPrice = NumberToStr(RoundFloor(sequence.slPrice, Digits), PriceFormat);
      else                            sSequenceSlPrice = NumberToStr(RoundCeil(sequence.slPrice, Digits), PriceFormat);
   }
}


/**
 * ShowStatus: Update the string representations of standard and long sequence name.
 */
void SS.SequenceName() {
   sequence.name = "";
   if (long.enabled)  sequence.name = sequence.name +"L";
   if (short.enabled) sequence.name = sequence.name +"S";
   sequence.name = sequence.name +"."+ sequence.id;
}


/**
 * ShowStatus: Update the string representation of the configured stop conditions.
 */
void SS.StopConditions() {
   if (__isChart) {
      string sValue = "";
      if (tpAbs.description != "") {
         sValue = sValue + ifString(sValue=="", "", " || ") + ifString(tpAbs.condition, "@", "!") + tpAbs.description;
      }
      if (tpPct.description != "") {
         sValue = sValue + ifString(sValue=="", "", " || ") + ifString(tpPct.condition, "@", "!") + tpPct.description;
      }
      if (slAbs.description != "") {
         sValue = sValue + ifString(sValue=="", "", " || ") + ifString(slAbs.condition, "@", "!") + slAbs.description;
      }
      if (slPct.description != "") {
         sValue = sValue + ifString(sValue=="", "", " || ") + ifString(slPct.condition, "@", "!") + slPct.description;
      }
      if (sValue == "") sStopConditions = "-";
      else              sStopConditions = sValue;
   }
}


/**
 * Create the status display box. It consists of overlapping rectangles made of char "g", font "Webdings". Called only from
 * afterInit().
 *
 * @return int - error status
 */
int CreateStatusBox() {
   if (!__isChart) return(NO_ERROR);

   int x[]={2, 114}, y=58, fontSize=115, rectangles=ArraySize(x);
   color  bgColor = LemonChiffon;
   string label;

   for (int i=0; i < rectangles; i++) {
      label = ProgramName() +".statusbox."+ (i+1);
      if (ObjectFind(label) != 0) {
         ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
         RegisterObject(label);
      }
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE, x[i]);
      ObjectSet(label, OBJPROP_YDISTANCE, y);
      ObjectSetText(label, "g", fontSize, "Webdings", bgColor);
   }
   return(catch("CreateStatusBox(1)"));
}


/**
 * Create a screenshot of the running sequence and store it next to the status file.
 *
 * @param  string comment [optional] - additional comment to append to the filename (default: none)
 *
 * @return bool - success status
 */
bool MakeScreenshot(string comment = "") {
   string filename = GetStatusFilename(/*relative=*/true);
   if (!StringLen(filename)) return(false);

   filename = StrLeftTo(filename, ".", -1) +" "+ GmtTimeFormat(TimeServer(), "%Y.%m.%d %H.%M.%S") + ifString(StringLen(comment), " "+ comment, "") +".gif";

   int width      = 1600;
   int height     =  900;
   int startbar   =  360;        // left-side bar index for an image width of 1600 pixel and margin-right of ~70 pixel with scale=2
   int chartScale =    2;
   int barMode    =   -1;        // the current bar mode

   if (WindowScreenShot(filename, width, height, startbar, chartScale, barMode))
      return(true);
   return(!logError("MakeScreenshot(1)", ifIntOr(GetLastError(), ERR_RUNTIME_ERROR)));    // don't terminate the program
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Sequence.ID=",            DoubleQuoteStr(Sequence.ID),                  ";", NL,
                            "GridDirection=",          DoubleQuoteStr(GridDirection),                ";", NL,
                            "GridVolatility=",         DoubleQuoteStr(GridVolatility),               ";", NL,
                            "GridSize=",               NumberToStr(GridSize, ".1+"),                 ";", NL,
                            "UnitSize=",               NumberToStr(UnitSize, ".1+"),                 ";", NL,
                            "Pyramid.Multiplier=",     NumberToStr(Pyramid.Multiplier, ".1+"),       ";", NL,
                            "Martingale.Multiplier=",  NumberToStr(Martingale.Multiplier, ".1+"),    ";", NL,
                            "TakeProfit=",             DoubleQuoteStr(TakeProfit),                   ";", NL,
                            "StopLoss=",               DoubleQuoteStr(StopLoss),                     ";", NL,
                            "ShowProfitInPercent=",    BoolToStr(ShowProfitInPercent),               ";", NL,
                            "Sessionbreak.StartTime=", TimeToStr(Sessionbreak.StartTime, TIME_FULL), ";", NL,
                            "Sessionbreak.EndTime=",   TimeToStr(Sessionbreak.EndTime, TIME_FULL),   ";")
   );
}
