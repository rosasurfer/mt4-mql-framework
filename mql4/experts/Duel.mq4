/**
 * Duel
 *
 * Eye to eye stand winners and losers
 * Hurt by envy, cut by greed
 * Face to face with their own disillusions
 * The scars of old romances still on their cheeks
 *
 *
 * A uni- or bi-directional grid with optional pyramiding, martingale or reverse-martingale position sizing.
 *
 * - If both multipliers are "0" the EA trades like a single-position system (no grid).
 * - If "Pyramid.Multiplier" is between "0" and "1" the EA trades on the winning side like a regular pyramiding system.
 * - If "Pyramid.Multiplier" is greater than "1" the EA trades on the winning side like a reverse-martingale system.
 * - If "Martingale.Multiplier" is greater than "0" the EA trades on the losing side like a regular Martingale system.
 *
 * @todo  add TP and SL conditions in pip
 * @todo  rounding down mode for CalculateLots()
 * @todo  test generated sequence ids for uniqueness
 * @todo  in tester generate consecutive sequence ids
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string   GridDirections         = "Long | Short | Both*";
extern int      GridSize               = 20;
extern double   UnitSize               = 0.1;                     // lots at the first grid level

extern double   Pyramid.Multiplier     = 1;                       // unitsize multiplier per grid level on the winning side
extern double   Martingale.Multiplier  = 1;                       // unitsize multiplier per grid level on the losing side

extern string   TakeProfit             = "{numeric}[%]";          // TP as absolute or percentage value
extern string   StopLoss               = "{numeric}[%]";          // SL as absolute or percentage value
extern bool     ShowProfitInPercent    = false;                   // whether PL is displayed as absolute or percentage value

extern datetime Sessionbreak.StartTime = D'1970.01.01 23:56:00';  // server time, the date part is ignored
extern datetime Sessionbreak.EndTime   = D'1970.01.01 00:02:10';  // server time, the date part is ignored

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/rsf/OrderExecution.mqh>


#define STRATEGY_ID         105                          // unique strategy id from 101-1023 (10 bit)
#define SEQUENCE_ID_MIN    1000                          // min. sequence id value (min. 4 digits)
#define SEQUENCE_ID_MAX   16383                          // max. sequence id value (max. 14 bit value)

#define STATUS_UNDEFINED      0                          // sequence status values
#define STATUS_WAITING        1
#define STATUS_PROGRESSING    2
#define STATUS_STOPPED        3

#define SIGNAL_TAKEPROFIT     1                          // start/stop signal types
#define SIGNAL_STOPLOSS       2
#define SIGNAL_SESSION_BREAK  3
#define SIGNAL_MARGIN_ERROR   4

#define D_LONG                TRADE_DIRECTION_LONG
#define D_SHORT               TRADE_DIRECTION_SHORT
#define D_BOTH                TRADE_DIRECTION_BOTH

#define CLR_PENDING           DeepSkyBlue                // order marker colors
#define CLR_LONG              Blue
#define CLR_SHORT             Red
#define CLR_CLOSE             Orange


// sequence data
int      sequence.id;
datetime sequence.created;
bool     sequence.isTest;                                // whether the sequence is a test (a finished test can be loaded into an online chart)
string   sequence.name = "";                             // "[LS].{sequence.id}"
int      sequence.status;
int      sequence.directions;
bool     sequence.pyramidEnabled;                        // whether the sequence scales in on the winning side (pyramid)
bool     sequence.martingaleEnabled;                     // whether the sequence scales in on the losing side (martingale)
double   sequence.startEquity;
double   sequence.gridbase;
double   sequence.unitsize;                              // lots at the first level
double   sequence.openLots;                              // total open lots: long.totalLots - short.totalLots
double   sequence.openPL;                                // accumulated P/L of all open positions
double   sequence.closedPL;                              // accumulated P/L of all closed positions
double   sequence.totalPL;                               // current total P/L of the sequence: totalPL = floatingPL + closedPL
double   sequence.maxProfit;                             // max. observed total sequence profit:   0...+n
double   sequence.maxDrawdown;                           // max. observed total sequence drawdown: -n...0

// order management
bool     long.enabled;
int      long.ticket      [];                            // records are ordered ascending by grid level
int      long.level       [];                            // grid level: -n...-1 | +1...+n
double   long.lots        [];
int      long.pendingType [];
datetime long.pendingTime [];
double   long.pendingPrice[];                            // price of the grid level
int      long.type        [];
datetime long.openTime    [];
double   long.openPrice   [];
datetime long.closeTime   [];
double   long.closePrice  [];
double   long.swap        [];
double   long.commission  [];
double   long.profit      [];
double   long.slippage;                                  // overall ippage of the long side
double   long.openLots;                                  // total open long lots: 0...+n
double   long.openPL;
double   long.closedPL;
int      long.minLevel = INT_MAX;                        // lowest reached grid level
int      long.maxLevel = INT_MIN;                        // highest reached grid level

bool     short.enabled;
int      short.ticket      [];                           // records are ordered ascending by grid level
int      short.level       [];                           // grid level: -n...-1 | +1...+n
double   short.lots        [];
int      short.pendingType [];
datetime short.pendingTime [];
double   short.pendingPrice[];                           // price of the grid level
int      short.type        [];
datetime short.openTime    [];
double   short.openPrice   [];
datetime short.closeTime   [];
double   short.closePrice  [];
double   short.swap        [];
double   short.commission  [];
double   short.profit      [];
double   short.slippage;                                 // overall slippage of the short side
double   short.openLots;                                 // total open short lots: 0...+n
double   short.openPL;
double   short.closedPL;
int      short.minLevel = INT_MAX;
int      short.maxLevel = INT_MIN;

// takeprofit conditions
bool     tpAbs.condition;                                // whether an absolute TP condition is active
double   tpAbs.value;
string   tpAbs.description = "";

bool     tpPct.condition;                                // whether a percentage TP condition is active
double   tpPct.value;
double   tpPct.absValue    = INT_MAX;
string   tpPct.description = "";

// stoploss conditions
bool     slAbs.condition;                                // whether an absolute SL condition is active
double   slAbs.value;
string   slAbs.description = "";

bool     slPct.condition;                                // whether a percentage SL condition is active
double   slPct.value;
double   slPct.absValue    = INT_MIN;
string   slPct.description = "";

// sessionbreak management
datetime sessionbreak.starttime;                         // configurable via inputs and framework config
datetime sessionbreak.endtime;

// caching vars to speed-up ShowStatus()
string   sUnitSize            = "";
string   sGridBase            = "";
string   sPyramid             = "";
string   sMartingale          = "";
string   sStopConditions      = "";
string   sOpenLongLots        = "";
string   sOpenShortLots       = "";
string   sOpenTotalLots       = "";
string   sSequenceTotalPL     = "";
string   sSequenceMaxProfit   = "";
string   sSequenceMaxDrawdown = "";
string   sSequencePlStats     = "";

// debug settings                                        // configurable via framework config, @see Duel::afterInit()
bool     tester.onStopPause = false;                     // whether to pause the tester after StopSequence()

#include <apps/duel/init.mqh>
#include <apps/duel/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (IsTesting() && IsVisualMode()) {
      if (!icChartInfos()) return(last_error);
   }

   if (sequence.status == STATUS_WAITING) {              // start a new sequence
      if (IsStartSignal()) StartSequence();
   }
   else if (sequence.status == STATUS_PROGRESSING) {     // manage a running sequence
      bool gridChanged=false, gridError=false;           // whether the current gridlevel changed, and/or a grid error occurred

      if (UpdateStatus(gridChanged, gridError)) {        // check pending orders and open positions
         if      (gridError)      StopSequence();
         else if (IsStopSignal()) StopSequence();
         else if (gridChanged)    UpdatePendingOrders(); // update pending orders
      }
   }
   else if (sequence.status == STATUS_STOPPED) {
   }

   return(catch("onTick(1)"));
}


/**
 * Whether a start condition is satisfied for a waiting sequence.
 *
 * @return bool
 */
bool IsStartSignal() {
   if (last_error || sequence.status!=STATUS_WAITING) return(false);

   if (IsSessionBreak()) {
      return(false);
   }
   return(true);
}


/**
 * Whether a stop condition is satisfied for a progressing sequence.
 *
 * @return bool
 */
bool IsStopSignal() {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("IsStopSignal(1)  "+ sequence.name +" cannot check stop signal of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   string message = "";

   // -- absolute TP --------------------------------------------------------------------------------------------------------
   if (tpAbs.condition) {
      if (sequence.totalPL >= tpAbs.value) {
         if (IsLogNotice()) logNotice("IsStopSignal(2)  "+ sequence.name +" stop condition \"@"+ tpAbs.description +"\" fulfilled (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         tpAbs.condition = false;
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
         return(true);
      }
   }

   // -- absolute SL --------------------------------------------------------------------------------------------------------
   if (slAbs.condition) {
      if (sequence.totalPL <= slAbs.value) {
         if (IsLogNotice()) logNotice("IsStopSignal(4)  "+ sequence.name +" stop condition \"@"+ slAbs.description +"\" fulfilled (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         slAbs.condition = false;
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

      if (IsLogInfo()) logInfo("IsSessionBreak(1)  "+ sequence.name +" recalculated "+ ifString(serverTime >= sessionbreak.starttime, "current", "next") +" sessionbreak: from "+ GmtTimeFormat(sessionbreak.starttime, "%a, %Y.%m.%d %H:%M:%S") +" to "+ GmtTimeFormat(sessionbreak.endtime, "%a, %Y.%m.%d %H:%M:%S"));
   }

   // perform the actual check
   return(serverTime >= sessionbreak.starttime);                  // here sessionbreak.endtime is always in the future
}


/**
 * Start a new sequence. When called all previous sequence data was reset.
 *
 * @return bool - success status
 */
bool StartSequence() {
   if (sequence.status != STATUS_WAITING) return(!catch("StartSequence(1)  "+ sequence.name +" cannot start "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (IsLogInfo()) logInfo("StartSequence(2)  "+ sequence.name +" starting sequence...");

   if      (sequence.directions == D_LONG)  sequence.gridbase = Ask;
   else if (sequence.directions == D_SHORT) sequence.gridbase = Bid;
   else                                     sequence.gridbase = NormalizeDouble((Bid+Ask)/2, Digits);
   SS.GridBase();

   sequence.startEquity = NormalizeDouble(AccountEquity()-AccountCredit(), 2);
   sequence.status      = STATUS_PROGRESSING;

   if (long.enabled) {
      if (Grid.AddPosition(D_LONG, 1) < 0)  return(false);              // open a long position for level 1
   }
   if (short.enabled) {
      if (Grid.AddPosition(D_SHORT, 1) < 0) return(false);              // open a short position for level 1
   }

   sequence.openLots = NormalizeDouble(long.openLots - short.openLots, 2); SS.OpenLots();

   if (!UpdatePendingOrders()) return(false);                           // update pending orders

   if (IsLogInfo()) logInfo("StartSequence(3)  "+ sequence.name +" sequence started (gridbase "+ NumberToStr(sequence.gridbase, PriceFormat) +")");
   return(!catch("StartSequence(4)"));
}


/**
 * Close open positions, delete pending orders and stop the sequence.
 *
 * @return bool - success status
 */
bool StopSequence() {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("StopSequence(1)  "+ sequence.name +" cannot stop "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (IsLogInfo()) logInfo("StopSequence(2)  "+ sequence.name +" stopping sequence...");

   int hedgeTicket, oe[];

   // hedge the total open position: execution price = sequence close price
   if (NE(sequence.openLots, 0)) {
      int      type        = ifInt(GT(sequence.openLots, 0), OP_SELL, OP_BUY);
      double   lots        = MathAbs(sequence.openLots);
      double   price       = NULL;
      double   slippage    = 1;  // in pip
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

   // cancel and remove all pending orders
   if (!Grid.RemovePendingOrders()) return(false);

   // close all open and the hedging position
   if (!StopSequence.ClosePositions(hedgeTicket)) return(false);

   // update total PL numbers
   sequence.openPL   = 0;
   sequence.closedPL = long.closedPL + short.closedPL;
   sequence.totalPL  = NormalizeDouble(sequence.openPL + sequence.closedPL, 2); SS.TotalPL();
   if      (sequence.totalPL > sequence.maxProfit  ) { sequence.maxProfit   = sequence.totalPL; SS.MaxProfit();   }
   else if (sequence.totalPL < sequence.maxDrawdown) { sequence.maxDrawdown = sequence.totalPL; SS.MaxDrawdown(); }

   sequence.status = STATUS_STOPPED;
   SS.StopConditions();
   if (IsLogInfo()) logInfo("StopSequence(3)  "+ sequence.name +" sequence stopped");

   // pause/stop the tester according to the debug configuration
   if (IsTesting()) {
      if (!IsVisualMode())         Tester.Stop("StopSequence(4)");
      else if (tester.onStopPause) Tester.Pause("StopSequence(5)");
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
      double slippage = 1; // in pip
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
            if (IsLogInfo()) logInfo("Grid.RemovePendingOrders(3)  "+ sequence.name +" "+ UpdateStatus.OrderFillMsg(D_LONG, i));

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
            if (IsLogInfo()) logInfo("Grid.RemovePendingOrders(5)  "+ sequence.name +" "+ UpdateStatus.OrderFillMsg(D_SHORT, i));

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
   bool positionChanged = false;

   if (!UpdateStatus.Direction(D_LONG,  gridChanged, positionChanged, gridError, long.slippage,  long.openLots,  long.openPL,  long.closedPL,  long.minLevel,  long.maxLevel,  long.ticket,  long.level,  long.lots,  long.pendingType,  long.pendingPrice,  long.type,  long.openTime,  long.openPrice,  long.closeTime,  long.closePrice,  long.swap,  long.commission,  long.profit))  return(false);
   if (!UpdateStatus.Direction(D_SHORT, gridChanged, positionChanged, gridError, short.slippage, short.openLots, short.openPL, short.closedPL, short.minLevel, short.maxLevel, short.ticket, short.level, short.lots, short.pendingType, short.pendingPrice, short.type, short.openTime, short.openPrice, short.closeTime, short.closePrice, short.swap, short.commission, short.profit)) return(false);

   if (gridChanged || positionChanged) {
      sequence.openLots = NormalizeDouble(long.openLots - short.openLots, 2);
      SS.OpenLots();
   }
   if (!ComputeProfit(positionChanged)) return(false);

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
   bool updateSlippage=false, isLogInfo=IsLogInfo();
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

            if (isLogInfo) logInfo("UpdateStatus(4)  "+ sequence.name +" "+ UpdateStatus.OrderFillMsg(direction, i));
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

   SelectTicket(ticket, "UpdateStatus.OrderCancelledMsg(2)", /*pushTicket=*/true);
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

   SelectTicket(ticket, "UpdateStatus.PositionCloseMsg(2)", /*pushTicket=*/true);
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
   else if (!error)  logInfo(message, error);
   else              catch(message, error);
   return(error);
}


/**
 * Check existing pending orders and add new or missing ones.
 *
 * @return bool - success status
 */
bool UpdatePendingOrders() {
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

   if (gridChanged)                                            // call the function again if sequence levels have been missed
      return(UpdatePendingOrders());
   return(!catch("UpdatePendingOrders(4)"));
}


/**
 * Generate a new sequence id. Because strategy ids differ multiple strategies may use the same sequence ids.
 *
 * @return int - sequence id between SEQUENCE_ID_MIN and SEQUENCE_ID_MAX (1000-16383)
 */
int CreateSequenceId() {
   MathSrand(GetTickCount());
   int id;
   while (id < SEQUENCE_ID_MIN || id > SEQUENCE_ID_MAX) {
      id = MathRand();
   }
   return(id);
}


/**
 * Generate a unique magic order number for the sequence.
 *
 * @return int - magic number or NULL in case of errors
 */
int CreateMagicNumber() {
   if (STRATEGY_ID & ( ~0x3FF) != 0) return(!catch("CreateMagicNumber(1)  "+ sequence.name +" illegal strategy id: "+ STRATEGY_ID, ERR_ILLEGAL_STATE));
   if (sequence.id & (~0x3FFF) != 0) return(!catch("CreateMagicNumber(2)  "+ sequence.name +" illegal sequence id: "+ sequence.id, ERR_ILLEGAL_STATE));

   int strategy = STRATEGY_ID;                              // 101-1023   (max. 10 bit)
   int sequence = sequence.id;                              // 1000-16383 (max. 14 bit)
   int level    = 0;                                        // 0          (not needed for this strategy)

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
      if (level > 0) price = sequence.gridbase + (level-1) * GridSize*Pip;
      else           price = sequence.gridbase + (level+1) * GridSize*Pip;
   }
   else {
      if (level > 0) price = sequence.gridbase - (level-1) * GridSize*Pip;
      else           price = sequence.gridbase - (level+1) * GridSize*Pip;
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
   if (!level || level==-1)                             return(!catch("CalculateLots(2)  "+ sequence.name +" invalid parameter level: "+ level, ERR_INVALID_PARAMETER));

   double lots = 0;

   if (level > 0) {
      if (sequence.pyramidEnabled)      lots = sequence.unitsize * MathPow(Pyramid.Multiplier, level-1);
      else if (level == 1)              lots = sequence.unitsize;
   }
   else if (sequence.martingaleEnabled) lots = sequence.unitsize * MathPow(Martingale.Multiplier, -level-1);
   lots = NormalizeLots(lots);

   return(ifDouble(catch("CalculateLots(3)"), NULL, lots));
}


/**
 * Compute and update the current total PL of the sequence.
 *
 * @param  bool positionChanged - whether the open position changed since the last call (used to invalidate caches)
 *
 * @return bool - success status
 */
bool ComputeProfit(bool positionChanged) {
   if (!long.enabled || !short.enabled) {
      sequence.openPL = long.openPL + short.openPL;               // one of both is 0 (zero)
   }
   else {
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
      double hedgedLots, remainingLong, remainingShort, factor, openPrice, closePrice, commission, swap, floatingProfit;
      sequence.openPL = 0;

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
                  // apply all data except profit; after nullify the ticket
                  openPrice     = NormalizeDouble(openPrice + lots[i] * openPrices[i], 8);
                  swap         += swaps      [i];
                  commission   += commissions[i];
                  remainingLong = NormalizeDouble(remainingLong - lots[i], 3);
                  tickets[i]    = NULL;
               }
               else {
                  // apply all swap and partial commission; after reduce the ticket's commission, profit and lotsize
                  factor        = remainingLong/lots[i];
                  openPrice     = NormalizeDouble(openPrice + remainingLong * openPrices[i], 8);
                  swap         += swaps[i];                swaps      [i]  = 0;
                  commission   += factor * commissions[i]; commissions[i] -= factor * commissions[i];
                                                           profits    [i] -= factor * profits    [i];
                                                           lots       [i]  = NormalizeDouble(lots[i]-remainingLong, 3);
                  remainingLong = 0;
               }
            }
            else /*types[i] == OP_SELL*/ {
               if (!remainingShort) continue;
               if (remainingShort >= lots[i]) {
                  // apply all swap; after nullify the ticket
                  closePrice     = NormalizeDouble(closePrice + lots[i] * openPrices[i], 8);
                  swap          += swaps      [i];
                  //commission  += commissions[i];                                        // commission is applied only at the long leg
                  remainingShort = NormalizeDouble(remainingShort - lots[i], 3);
                  tickets[i]     = NULL;
               }
               else {
                  // apply all swap; after reduce the ticket's commission, profit and lotsize
                  factor         = remainingShort/lots[i];
                  closePrice     = NormalizeDouble(closePrice + remainingShort * openPrices[i], 8);
                  swap          += swaps[i]; swaps      [i]  = 0;
                                             commissions[i] -= factor * commissions[i];   // commission is applied only at the long leg
                                             profits    [i] -= factor * profits    [i];
                                             lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 3);
                  remainingShort = 0;
               }
            }
         }
         if (remainingLong!=0 || remainingShort!=0) return(!catch("ComputeProfit(1)  illegal remaining "+ ifString(!remainingShort, "long", "short") +" position "+ NumberToStr(remainingLong, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR));

         // calculate profit from the difference openPrice-closePrice
         double pipValue    = PipValue(hedgedLots, true);
         double pipDistance = (closePrice-openPrice)/hedgedLots/Pips + (commission+swap)/pipValue;
         sequence.openPL   += pipDistance * pipValue;
      }

      // compute PL of a floating long position
      if (sequence.openLots > 0) {
         remainingLong  = sequence.openLots;
         openPrice      = 0;
         swap           = 0;
         commission     = 0;
         floatingProfit = 0;

         for (i=0; i < orders; i++) {
            if (!tickets[i]   ) continue;
            if (!remainingLong) break;

            if (types[i] == OP_BUY) {
               if (remainingLong >= lots[i]) {
                  // apply all data
                  openPrice       = NormalizeDouble(openPrice + lots[i] * openPrices[i], 8);
                  swap           += swaps      [i];
                  commission     += commissions[i];
                  floatingProfit += profits    [i];
                  remainingLong   = NormalizeDouble(remainingLong - lots[i], 3);
               }
               else {
                  // apply all swap, partial commission, partial profit; after reduce the ticket's commission, profit and lotsize
                  factor          = remainingLong/lots[i];
                  openPrice       = NormalizeDouble(openPrice + remainingLong * openPrices[i], 8);
                  swap           +=          swaps      [i]; swaps      [i]  = 0;
                  commission     += factor * commissions[i]; commissions[i] -= factor * commissions[i];
                  floatingProfit += factor * profits    [i]; profits    [i] -= factor * profits    [i];
                                                             lots       [i]  = NormalizeDouble(lots[i]-remainingLong, 3);
                  remainingLong = 0;
               }
            }
         }
         if (remainingLong != 0) return(!catch("ComputeProfit(2)  illegal remaining long position "+ NumberToStr(remainingLong, ".+") +" of total position = "+ NumberToStr(sequence.openLots, ".+"), ERR_RUNTIME_ERROR));

         sequence.openPL += floatingProfit + commission + swap;
      }

      // compute PL of a floating short position
      if (sequence.openLots < 0) {
         remainingShort = -sequence.openLots;
         openPrice      = 0;
         swap           = 0;
         commission     = 0;
         floatingProfit = 0;

         for (i=0; i < orders; i++) {
            if (!tickets[i]    ) continue;
            if (!remainingShort) break;

            if (types[i] == OP_SELL) {
               if (remainingShort >= lots[i]) {
                  // apply all data
                  openPrice       = NormalizeDouble(openPrice + lots[i] * openPrices[i], 8);
                  swap           += swaps      [i];
                  commission     += commissions[i];
                  floatingProfit += profits    [i];
                  remainingShort  = NormalizeDouble(remainingShort - lots[i], 3);
               }
               else {
                  // apply all swap, partial commission, partial profit; after reduce the ticket's commission, profit and lotsize
                  factor          = remainingShort/lots[i];
                  openPrice       = NormalizeDouble(openPrice + remainingShort * openPrices[i], 8);
                  swap           +=          swaps      [i]; swaps      [i]  = 0;
                  commission     += factor * commissions[i]; commissions[i] -= factor * commissions[i];
                  floatingProfit += factor * profits    [i]; profits    [i] -= factor * profits    [i];
                                                             lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 3);
                  remainingShort = 0;
               }
            }
         }
         if (remainingShort != 0) return(!catch("ComputeProfit(3)  illegal remaining short position "+ NumberToStr(remainingShort, ".+") +" of total position = "+ NumberToStr(sequence.openLots, ".+"), ERR_RUNTIME_ERROR));

         sequence.openPL += floatingProfit + commission + swap;
      }
   }

   // summarize and process results
   sequence.openPL   = NormalizeDouble(sequence.openPL, 2);
   sequence.closedPL = NormalizeDouble(long.closedPL + short.closedPL, 2);
   sequence.totalPL  = NormalizeDouble(sequence.openPL + sequence.closedPL, 2); SS.TotalPL();
   if      (sequence.totalPL > sequence.maxProfit  ) { sequence.maxProfit   = sequence.totalPL; SS.MaxProfit();   }
   else if (sequence.totalPL < sequence.maxDrawdown) { sequence.maxDrawdown = sequence.totalPL; SS.MaxDrawdown(); }

   return(!catch("ComputeProfit(4)"));
}


/**
 * Return the full name of the instance logfile.
 *
 * @return string - filename or an empty string in case of errors
 */
string GetLogFilename() {
   string name = GetStatusFilename();
   if (!StringLen(name)) return("");
   return(StrLeft(name, -3) +"log");
}


/**
 * Return the full name of the instance status file.
 *
 * @return string - filename or an empty string in case of errors
 */
string GetStatusFilename() {
   if (!sequence.id) return(_EMPTY_STR(catch("GetStatusFilename(1)  "+ sequence.name +" illegal value of sequence.id: "+ sequence.id, ERR_ILLEGAL_STATE)));

   string directory = "\\presets\\" + ifString(IsTestSequence(), "Tester", GetAccountCompany()) +"\\";
   string baseName  = StrToLower(Symbol()) +".Duel."+ sequence.id +".set";

   return(GetMqlFilesPath() + directory + baseName);
}


/**
 * Open a market position for the specified grid level and add the order data to the order arrays. There is no check whether
 * the specified grid level matches the current market price.
 *
 * @param  int direction - trade direction: D_LONG | D_SHORT
 * @param  int level     - grid level of the position to open: -n...-1 | +1...+n
 *
 * @return int - array index the order record was stored at or -1 (EMPTY) in case of errors
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
      if (IsLogInfo()) logInfo("Grid.AddPendingOrder(3)  "+ sequence.name +" illegal price "+ OperationTypeDescription(oe.Type(oe)) +" at "+ NumberToStr(oe.OpenPrice(oe), PriceFormat) +" (market: "+ NumberToStr(oe.Bid(oe), PriceFormat) +"/"+ NumberToStr(oe.Ask(oe), PriceFormat) +"), opening "+ ifString(IsStopOrderType(oe.Type(oe)), "limit", "stop") +" order instead...");
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


string   last.GridDirections = "";
int      last.GridSize;
double   last.UnitSize;
double   last.Pyramid.Multiplier;
double   last.Martingale.Multiplier;
string   last.TakeProfit = "";
string   last.StopLoss = "";
bool     last.ShowProfitInPercent;
datetime last.Sessionbreak.StartTime;
datetime last.Sessionbreak.EndTime;


/**
 * Input parameters changed by the code don't survive init cycles. Therefore inputs are backed-up in deinit() and can be
 * restored in init(). Called only from onDeinitParameters() and onDeinitChartChange().
 */
void BackupInputs() {
   // backed-up inputs are also accessed from ValidateInputs()
   last.GridDirections         = StringConcatenate(GridDirections, ""); // string inputs are references to internal C literals
   last.GridSize               = GridSize;                              // and must be copied to break the reference
   last.UnitSize               = UnitSize;
   last.Pyramid.Multiplier     = Pyramid.Multiplier;
   last.Martingale.Multiplier  = Martingale.Multiplier;
   last.TakeProfit             = StringConcatenate(TakeProfit, "");
   last.StopLoss               = StringConcatenate(StopLoss, "");
   last.ShowProfitInPercent    = ShowProfitInPercent;
   last.Sessionbreak.StartTime = Sessionbreak.StartTime;
   last.Sessionbreak.EndTime   = Sessionbreak.EndTime;
}


/**
 * Restore backed-up input parameters. Called only from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   GridDirections         = last.GridDirections;
   GridSize               = last.GridSize;
   UnitSize               = last.UnitSize;
   Pyramid.Multiplier     = last.Pyramid.Multiplier;
   Martingale.Multiplier  = last.Martingale.Multiplier;
   TakeProfit             = last.TakeProfit;
   StopLoss               = last.StopLoss;
   ShowProfitInPercent    = last.ShowProfitInPercent;
   Sessionbreak.StartTime = last.Sessionbreak.StartTime;
   Sessionbreak.EndTime   = last.Sessionbreak.EndTime;
}


/**
 * Backup status variables which may change by modifying input parameters. This way status can be restored in case of input
 * errors. Called only from onInitParameters().
 */
void BackupInputStatus() {
   CopyInputStatus(true);
}


/**
 * Restore status variables from the backup. Called only from onInitParameters().
 */
void RestoreInputStatus() {
   CopyInputStatus(false);
}


/**
 * Backup or restore status variables related to input parameter changes. Called only from BackupInputStatus() and
 * RestoreInputStatus() in onInitParameters().
 *
 * @param  bool store - TRUE:  copy status to internal storage (backup)
 *                      FALSE: copy internal storage to status (restore)
 */
void CopyInputStatus(bool store) {
   store = store!=0;

   static int      _sequence.id;
   static datetime _sequence.created;
   static bool     _sequence.isTest;
   static string   _sequence.name = "";
   static int      _sequence.status;
   static int      _sequence.directions;
   static bool     _sequence.pyramidEnabled;
   static bool     _sequence.martingaleEnabled;
   static double   _sequence.unitsize;

   static bool     _tpAbs.condition;
   static double   _tpAbs.value;
   static string   _tpAbs.description = "";
   static bool     _tpPct.condition;
   static double   _tpPct.value;
   static double   _tpPct.absValue;
   static string   _tpPct.description = "";

   static bool     _slAbs.condition;
   static double   _slAbs.value;
   static string   _slAbs.description = "";
   static bool     _slPct.condition;
   static double   _slPct.value;
   static double   _slPct.absValue;
   static string   _slPct.description = "";

   static datetime _sessionbreak.starttime;
   static datetime _sessionbreak.endtime;

   if (store) {
      _sequence.id                = sequence.id;
      _sequence.created           = sequence.created;
      _sequence.isTest            = sequence.isTest;
      _sequence.name              = sequence.name;
      _sequence.status            = sequence.status;
      _sequence.directions        = sequence.directions;
      _sequence.pyramidEnabled    = sequence.pyramidEnabled;
      _sequence.martingaleEnabled = sequence.martingaleEnabled;
      _sequence.unitsize          = sequence.unitsize;

      _tpAbs.condition            = tpAbs.condition;
      _tpAbs.value                = tpAbs.value;
      _tpAbs.description          = tpAbs.description;
      _tpPct.condition            = tpPct.condition;
      _tpPct.value                = tpPct.value;
      _tpPct.absValue             = tpPct.absValue;
      _tpPct.description          = tpPct.description;

      _slAbs.condition            = slAbs.condition;
      _slAbs.value                = slAbs.value;
      _slAbs.description          = slAbs.description;
      _slPct.condition            = slPct.condition;
      _slPct.value                = slPct.value;
      _slPct.absValue             = slPct.absValue;
      _slPct.description          = slPct.description;

      _sessionbreak.starttime     = sessionbreak.starttime;
      _sessionbreak.endtime       = sessionbreak.endtime;
   }
   else {
      sequence.id                = _sequence.id;
      sequence.created           = _sequence.created;
      sequence.isTest            = _sequence.isTest;
      sequence.name              = _sequence.name;
      sequence.status            = _sequence.status;
      sequence.directions        = _sequence.directions;
      sequence.pyramidEnabled    = _sequence.pyramidEnabled;
      sequence.martingaleEnabled = _sequence.martingaleEnabled;
      sequence.unitsize          = _sequence.unitsize;

      tpAbs.condition            = _tpAbs.condition;
      tpAbs.value                = _tpAbs.value;
      tpAbs.description          = _tpAbs.description;
      tpPct.condition            = _tpPct.condition;
      tpPct.value                = _tpPct.value;
      tpPct.absValue             = _tpPct.absValue;
      tpPct.description          = _tpPct.description;

      slAbs.condition            = _slAbs.condition;
      slAbs.value                = _slAbs.value;
      slAbs.description          = _slAbs.description;
      slPct.condition            = _slPct.condition;
      slPct.value                = _slPct.value;
      slPct.absValue             = _slPct.absValue;
      slPct.description          = _slPct.description;

      sessionbreak.starttime     = _sessionbreak.starttime;
      sessionbreak.endtime       = _sessionbreak.endtime;
   }
}


/**
 * Validate all input parameters. Parameters may have been entered through the input dialog, may have been read and applied
 * from a status file or may have been deserialized and applied programmatically by the terminal (e.g. at terminal restart).
 *
 * @param  bool interactive - whether parameters have been entered through the input dialog
 *
 * @return bool - whether input parameters are valid
 */
bool ValidateInputs(bool interactive) {
   interactive = interactive!=0;
   if (IsLastError()) return(false);

   bool isParameterChange = (ProgramInitReason()==IR_PARAMETERS); // otherwise inputs have been applied programmatically
   if (isParameterChange)
      interactive = true;

   // GridDirections
   string sValues[], sValue = GridDirections;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   int iValue = StrToTradeDirection(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (iValue == -1)                                         return(_false(ValidateInputs.OnError("ValidateInputs(1)", "Invalid input parameter GridDirections: "+ DoubleQuoteStr(GridDirections), interactive)));
   if (isParameterChange && !StrCompareI(sValue, last.GridDirections)) {
      if (ArraySize(long.ticket) || ArraySize(short.ticket)) return(_false(ValidateInputs.OnError("ValidateInputs(2)", "Cannot change input parameter GridDirections of "+ StatusDescription(sequence.status) +" sequence", interactive)));
   }
   sequence.directions = iValue;
   GridDirections = TradeDirectionDescription(sequence.directions);

   // GridSize
   if (isParameterChange && GridSize!=last.GridSize) {
      if (ArraySize(long.ticket) || ArraySize(short.ticket)) return(_false(ValidateInputs.OnError("ValidateInputs(3)", "Cannot change input parameter GridSize of "+ StatusDescription(sequence.status) +" sequence", interactive)));
   }
   if (GridSize < 1)                                         return(_false(ValidateInputs.OnError("ValidateInputs(4)", "Invalid input parameter GridSize: "+ GridSize, interactive)));

   // UnitSize
   if (isParameterChange && NE(UnitSize, last.UnitSize)) {
      if (ArraySize(long.ticket) || ArraySize(short.ticket)) return(_false(ValidateInputs.OnError("ValidateInputs(5)", "Cannot change input parameter UnitSize of "+ StatusDescription(sequence.status) +" sequence", interactive)));
   }
   if (LT(UnitSize, 0.01))                                   return(_false(ValidateInputs.OnError("ValidateInputs(6)", "Invalid input parameter UnitSize: "+ NumberToStr(UnitSize, ".1+"), interactive)));
   sequence.unitsize = UnitSize;

   // Pyramid.Multiplier
   if (isParameterChange && NE(Pyramid.Multiplier, last.Pyramid.Multiplier)) {
      if (ArraySize(long.ticket) || ArraySize(short.ticket)) return(_false(ValidateInputs.OnError("ValidateInputs(7)", "Cannot change input parameter Pyramid.Multiplier of "+ StatusDescription(sequence.status) +" sequence", interactive)));
   }
   if (Pyramid.Multiplier < 0)                               return(_false(ValidateInputs.OnError("ValidateInputs(8)", "Invalid input parameter Pyramid.Multiplier: "+ NumberToStr(Pyramid.Multiplier, ".1+"), interactive)));
   sequence.pyramidEnabled = (Pyramid.Multiplier > 0);

   // Martingale.Multiplier
   if (isParameterChange && NE(Martingale.Multiplier, last.Martingale.Multiplier)) {
      if (ArraySize(long.ticket) || ArraySize(short.ticket)) return(_false(ValidateInputs.OnError("ValidateInputs(9)", "Cannot change input parameter Martingale.Multiplier of "+ StatusDescription(sequence.status) +" sequence", interactive)));
   }
   if (Martingale.Multiplier < 0)                            return(_false(ValidateInputs.OnError("ValidateInputs(10)", "Invalid input parameter Martingale.Multiplier: "+ NumberToStr(Martingale.Multiplier, ".1+"), interactive)));
   sequence.martingaleEnabled = (Martingale.Multiplier > 0);

   // TakeProfit
   bool unsetTpPct = false, unsetTpAbs = false;
   sValue = StrTrim(TakeProfit);
   if (StringLen(sValue) && sValue!="{numeric}[%]") {
      bool isPercent = StrEndsWith(sValue, "%");
      if (isPercent) sValue = StrTrim(StrLeft(sValue, -1));
      if (!StrIsNumeric(sValue))                             return(_false(ValidateInputs.OnError("ValidateInputs(11)", "Invalid input parameter TakeProfit: "+ DoubleQuoteStr(TakeProfit), interactive)));
      double dValue = StrToDouble(sValue);
      if (isPercent) {
         tpPct.condition   = true;
         tpPct.value       = dValue;
         tpPct.absValue    = INT_MAX;
         tpPct.description = "profit("+ NumberToStr(dValue, ".+") +"%)";
         unsetTpAbs        = true;
      }
      else {
         tpAbs.condition   = true;
         tpAbs.value       = NormalizeDouble(dValue, 2);
         tpAbs.description = "profit("+ DoubleToStr(dValue, 2) +")";
         unsetTpPct        = true;
      }
   }
   else {
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
   if (StringLen(sValue) && sValue!="{numeric}[%]") {
      isPercent = StrEndsWith(sValue, "%");
      if (isPercent) sValue = StrTrim(StrLeft(sValue, -1));
      if (!StrIsNumeric(sValue))                             return(_false(ValidateInputs.OnError("ValidateInputs(12)", "Invalid input parameter StopLoss: "+ DoubleQuoteStr(StopLoss), interactive)));
      dValue = StrToDouble(sValue);
      if (isPercent) {
         slPct.condition   = true;
         slPct.value       = dValue;
         slPct.absValue    = INT_MIN;
         slPct.description = "loss("+ NumberToStr(dValue, ".+") +"%)";
         unsetSlAbs        = true;
      }
      else {
         slAbs.condition   = true;
         slAbs.value       = NormalizeDouble(dValue, 2);
         slAbs.description = "loss("+ DoubleToStr(dValue, 2) +")";
         unsetSlPct        = true;
      }
   }
   else {
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
   if (Sessionbreak.StartTime!=last.Sessionbreak.StartTime || Sessionbreak.EndTime!=last.Sessionbreak.EndTime) {
      sessionbreak.starttime = NULL;
      sessionbreak.endtime   = NULL;                              // real times are updated automatically on next use
   }
   return(!catch("ValidateInputs(13)"));
}


/**
 * Error handler for invalid input parameters. Either prompts for input correction or passes on execution to the standard
 * error handler.
 *
 * @param  string location    - error location identifier
 * @param  string message     - error message
 * @param  bool   interactive - whether the error occurred in an interactive or programatic context
 *
 * @return int - resulting error status
 */
int ValidateInputs.OnError(string location, string message, bool interactive) {
   interactive = interactive!=0;
   if (IsTesting() || !interactive)
      return(catch(location +"  "+ message, ERR_INVALID_CONFIG_VALUE));

   int error = ERR_INVALID_INPUT_PARAMETER;
   __STATUS_INVALID_INPUT = true;

   if (IsLogNotice()) logNotice(location +"  "+ message, error);

   PlaySoundEx("Windows Chord.wav");
   int button = MessageBoxEx(ProgramName() +" - "+ location, message, MB_ICONERROR|MB_RETRYCANCEL);
   if (button == IDRETRY) __STATUS_RELAUNCH_INPUT = true;
   return(error);
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
   double   slippage    = 0.1;
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
   double   slippage    = NULL;
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
   double   slippage    = NULL;
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
 * Display the current runtime status.
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error or the current error status if no error was passed
 */
int ShowStatus(int error = NO_ERROR) {
   if (!IsChart()) return(error);
   string sSequence="", sDirection="", sError="";

   switch (sequence.directions) {
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
   if      (__STATUS_INVALID_INPUT) sError = StringConcatenate("  [",                 ErrorDescription(ERR_INVALID_INPUT_PARAMETER), "]");
   else if (__STATUS_OFF          ) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason),         "]");

   string msg = StringConcatenate(ProgramName(), "               ", sSequence, sError,                                  NL,
                                                                                                                        NL,
                                  "Grid:              ",            GridSize, " pip", sGridBase, sPyramid, sMartingale, NL,
                                  "UnitSize:        ",              sUnitSize,                                          NL,
                                  "Stop:             ",             sStopConditions,                                    NL,
                                                                                                                        NL,
                                  "Long:             ",             sOpenLongLots,                                      NL,
                                  "Short:            ",             sOpenShortLots,                                     NL,
                                  "Total:            ",             sOpenTotalLots,                                     NL,
                                                                                                                        NL,
                                  "Profit/Loss:   ",                sSequenceTotalPL, sSequencePlStats,                 NL
   );

   // 4 lines margin-top for instrument and indicator legends
   Comment(NL, NL, NL, NL, msg);
   if (__CoreFunction == CF_INIT) WindowRedraw();

   if (!catch("ShowStatus(2)"))
      return(error);
   return(last_error);
}


/**
 * ShowStatus: Update all string representations.
 */
void SS.All() {
   if (IsChart()) {
      SS.SequenceName();
      SS.GridBase();
      SS.UnitSize();
      SS.StopConditions();
      SS.OpenLots();
      SS.TotalPL();
      SS.MaxProfit();
      SS.MaxDrawdown();
      sPyramid    = ifString(sequence.pyramidEnabled,    ", Pyramid: "+    NumberToStr(Pyramid.Multiplier, ".1+"),    "");
      sMartingale = ifString(sequence.martingaleEnabled, ", Martingale: "+ NumberToStr(Martingale.Multiplier, ".1+"), "");
   }
}


/**
 * ShowStatus: Update the string representation of the grid base.
 */
void SS.GridBase() {
   if (IsChart()) {
      sGridBase = "";
      if (!sequence.gridbase) return;
      sGridBase = " @ "+ NumberToStr(sequence.gridbase, PriceFormat);
   }
}


/**
 * ShowStatus: Update the string representation of "sequence.maxDrawdown".
 */
void SS.MaxDrawdown() {
   if (IsChart()) {
      if (ShowProfitInPercent) sSequenceMaxDrawdown = NumberToStr(MathDiv(sequence.maxDrawdown, sequence.startEquity) * 100, "+.2") +"%";
      else                     sSequenceMaxDrawdown = NumberToStr(sequence.maxDrawdown, "+.2");
      SS.PLStats();
   }
}


/**
 * ShowStatus: Update the string representation of "sequence.maxProfit".
 */
void SS.MaxProfit() {
   if (IsChart()) {
      if (ShowProfitInPercent) sSequenceMaxProfit = NumberToStr(MathDiv(sequence.maxProfit, sequence.startEquity) * 100, "+.2") +"%";
      else                     sSequenceMaxProfit = NumberToStr(sequence.maxProfit, "+.2");
      SS.PLStats();
   }
}


/**
 * ShowStatus: Update the string representaton of the P/L statistics.
 */
void SS.PLStats() {
   if (IsChart()) {
      if (ArraySize(long.ticket) || ArraySize(short.ticket)) {          // not before a positions was opened
         sSequencePlStats = StringConcatenate("  (", sSequenceMaxProfit, " / ", sSequenceMaxDrawdown, ")");
      }
      else sSequencePlStats = "";
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
   if (IsChart()) {
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
 * ShowStatus: Update the string representation of "long.openLots", "short.openLots" and "sequence.openLots".
 */
void SS.OpenLots() {
   if (IsChart()) {
      if (!long.openLots) sOpenLongLots = "-";
      else                sOpenLongLots = NumberToStr(long.openLots, "+.+") +" lot, level "+ long.maxLevel + ifString(!long.slippage, "", ", slippage: "+ NumberToStr(long.slippage/Pip, "+.1R") +" pip");

      if (!short.openLots) sOpenShortLots = "-";
      else                 sOpenShortLots = NumberToStr(-short.openLots, "+.+") +" lot, level "+ short.maxLevel + ifString(!short.slippage, "", ", slippage: "+ NumberToStr(short.slippage/Pip, "+.1R") +" pip");

      if (!long.openLots && !short.openLots) sOpenTotalLots = "-";
      else if (!sequence.openLots)           sOpenTotalLots = "±0 (hedged)";
      else                                   sOpenTotalLots = NumberToStr(sequence.openLots, "+.+") +" lot";   // +" lot @ "+ NumberToStr(sequence.avgPrice, PriceFormat);
   }
}


/**
 * ShowStatus: Update the string representation of "sequence.totalPL".
 */
void SS.TotalPL() {
   if (IsChart()) {
      if (ArraySize(long.ticket) || ArraySize(short.ticket)) {          // not before a positions was opened
         if (ShowProfitInPercent) sSequenceTotalPL = NumberToStr(MathDiv(sequence.totalPL, sequence.startEquity) * 100, "+.2") +"%";
         else                     sSequenceTotalPL = NumberToStr(sequence.totalPL, "+.2");
      }
      else sSequenceTotalPL = "-";
   }
}


/**
 * ShowStatus: Update the string representation of the unitsize.
 */
void SS.UnitSize() {
   if (IsChart()) {
      sUnitSize = NumberToStr(sequence.unitsize, ".+") +" lot";
   }
}


/**
 * Create the status display box. It consists of overlapping rectangles made of char "g" font "Webdings". Called only from
 * afterInit().
 *
 * @return int - error status
 */
int CreateStatusBox() {
   if (!IsChart()) return(NO_ERROR);

   int x[]={2, 101, 165}, y=62, fontSize=83, rectangles=ArraySize(x);   // 75
   color  bgColor = LemonChiffon;                                       // Cyan LemonChiffon bgColor=C'248,248,248'
   string label;

   for (int i=0; i < rectangles; i++) {
      label = ProgramName() +".statusbox."+ (i+1);
      if (ObjectFind(label) != 0) {
         ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
         RegisterObject(label);
      }
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, x[i]);
      ObjectSet    (label, OBJPROP_YDISTANCE, y   );
      ObjectSetText(label, "g", fontSize, "Webdings", bgColor);
   }
   return(catch("CreateStatusBox(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("GridDirections=",         DoubleQuoteStr(GridDirections),               ";", NL,
                            "GridSize=",               GridSize,                                     ";", NL,
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
