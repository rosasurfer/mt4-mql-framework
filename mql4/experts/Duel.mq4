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
 * - If both multipliers are "0" the EA trades like a regular single-position system (no grid).
 * - If "Pyramid.Multiplier" is between "0" and "1" the EA trades on the winning side like a regular pyramiding system.
 * - If "Pyramid.Multiplier" is greater than "1" the EA trades on the winning side like a reverse-martingale system.
 * - If "Martingale.Multiplier" is greater than "0" the EA trades on the losing side like a Martingale system.
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
double   sequence.totalLots;                             // total open lots: long.totalLots - short.totalLots
double   sequence.avgPrice;
double   sequence.floatingPL;                            // accumulated P/L of all open positions
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
double   long.pendingPrice[];
int      long.type        [];
datetime long.openTime    [];
double   long.openPrice   [];
datetime long.closeTime   [];
double   long.closePrice  [];
double   long.swap        [];
double   long.commission  [];
double   long.profit      [];
double   long.totalLots;                                 // total open long lots: 0...+n
double   long.avgPrice;
int      long.minLevel = INT_MAX;                        // lowest reached grid level
int      long.maxLevel = INT_MIN;                        // highest reached grid level
double   long.slippage;                                  // cumulated slippage in pip
double   long.floatingPL;
double   long.closedPL;
double   long.totalPL;
double   long.maxProfit;
double   long.maxDrawdown;

bool     short.enabled;
int      short.ticket      [];                           // records are ordered ascending by grid level
int      short.level       [];                           // grid level: -n...-1 | +1...+n
double   short.lots        [];
int      short.pendingType [];
datetime short.pendingTime [];
double   short.pendingPrice[];
int      short.type        [];
datetime short.openTime    [];
double   short.openPrice   [];
datetime short.closeTime   [];
double   short.closePrice  [];
double   short.swap        [];
double   short.commission  [];
double   short.profit      [];
double   short.totalLots;                                // total open short lots: 0...+n
double   short.avgPrice;
int      short.minLevel = INT_MAX;
int      short.maxLevel = INT_MIN;
double   short.slippage;
double   short.floatingPL;
double   short.closedPL;
double   short.totalPL;
double   short.maxProfit;
double   short.maxDrawdown;

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
string   sLongLots            = "";
string   sShortLots           = "";
string   sTotalLots           = "";
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
   if (sequence.status == STATUS_WAITING) {              // start a new sequence
      if (IsStartSignal()) StartSequence();
   }
   else if (sequence.status == STATUS_PROGRESSING) {     // manage a running sequence
      bool gridChanged = false;                          // whether the current gridbase or gridlevel changed
      if (UpdateStatus(gridChanged)) {                   // check pending orders and update PL
         if (IsStopSignal())   StopSequence();           // close all positions
         else if (gridChanged) UpdateOrders();           // add pending orders
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
      int i = Grid.AddPosition(D_LONG, 1); if (i < 0) return(false);    // open a long position for level 1
      long.avgPrice = long.openPrice[i];
   }
   if (short.enabled) {
      i = Grid.AddPosition(D_SHORT, 1); if (i < 0) return(false);       // open a short position for level 1
      short.avgPrice = short.openPrice[i];
   }

   sequence.totalLots = NormalizeDouble(long.totalLots - short.totalLots, 2); SS.TotalLots();

   if (!UpdateOrders()) return(false);                                  // update pending orders

   if (IsLogInfo()) logInfo("StartSequence(3)  "+ sequence.name +" sequence started (gridbase "+ NumberToStr(sequence.gridbase, PriceFormat) +")");
   return(!catch("StartSequence(4)"));
}


/**
 * Close all open positions, delete pending orders and stop the sequence.
 *
 * @return bool - success status
 */
bool StopSequence() {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("StopSequence(1)  "+ sequence.name +" cannot stop "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   int orders, oe[], oeFlags=NULL;

   // -----------------------------------------------------------------------------------------------------------------------
   if (long.enabled) {
      orders = ArraySize(long.ticket);
      long.floatingPL = 0;

      for (int i=0; i < orders; i++) {
         if (long.closeTime[i] > 0) continue;                        // skip tickets known as closed
         if (!SelectTicket(long.ticket[i], "StopSequence(2)")) return(false);

         if (long.type[i] == OP_UNDEFINED) {                         // a pending order
            if (!OrderDeleteEx(long.ticket[i], CLR_NONE, oeFlags, oe)) return(false);
            long.closeTime[i] = oe.CloseTime(oe);
         }
         else {                                                      // on open position
            if (!OrderCloseEx(long.ticket[i], NULL, NULL, CLR_CLOSE, oeFlags, oe)) return(false);
            long.closeTime [i] = oe.CloseTime(oe);
            long.closePrice[i] = oe.ClosePrice(oe);
            long.swap      [i] = oe.Swap(oe);
            long.commission[i] = oe.Commission(oe);
            long.profit    [i] = oe.Profit(oe);
            long.closedPL     += long.swap[i] + long.commission[i] + long.profit[i];
         }
      }

      long.totalPL     = long.floatingPL + long.closedPL;            // update PL numbers
      long.maxProfit   = MathMax(long.totalPL, long.maxProfit);
      long.maxDrawdown = MathMin(long.totalPL, long.maxDrawdown);
   }

   // -----------------------------------------------------------------------------------------------------------------------
   if (short.enabled) {
      orders = ArraySize(short.ticket);
      short.floatingPL = 0;

      for (i=0; i < orders; i++) {
         if (short.closeTime[i] > 0) continue;                       // skip tickets known as closed
         if (!SelectTicket(short.ticket[i], "StopSequence(3)")) return(false);

         if (short.type[i] == OP_UNDEFINED) {                        // a pending order
            if (!OrderDeleteEx(short.ticket[i], CLR_NONE, oeFlags, oe)) return(false);
            short.closeTime[i] = oe.CloseTime(oe);
         }
         else {                                                      // on open position
            if (!OrderCloseEx(short.ticket[i], NULL, NULL, CLR_CLOSE, oeFlags, oe)) return(false);
            short.closeTime [i] = oe.CloseTime(oe);
            short.closePrice[i] = oe.ClosePrice(oe);
            short.swap      [i] = oe.Swap(oe);
            short.commission[i] = oe.Commission(oe);
            short.profit    [i] = oe.Profit(oe);
            short.closedPL     += short.swap[i] + short.commission[i] + short.profit[i];
         }
      }

      short.totalPL     = short.floatingPL + short.closedPL;         // update PL numbers
      short.maxProfit   = MathMax(short.totalPL, short.maxProfit);
      short.maxDrawdown = MathMin(short.totalPL, short.maxDrawdown);
   }

   // update total PL numbers
   sequence.floatingPL = NormalizeDouble(long.floatingPL + short.floatingPL, 2);
   sequence.closedPL   = NormalizeDouble(long.closedPL   + short.closedPL, 2);
   sequence.totalPL    = NormalizeDouble(sequence.floatingPL + sequence.closedPL, 2); SS.TotalPL();
   if      (sequence.totalPL > sequence.maxProfit  ) { sequence.maxProfit   = sequence.totalPL; SS.MaxProfit();   }
   else if (sequence.totalPL < sequence.maxDrawdown) { sequence.maxDrawdown = sequence.totalPL; SS.MaxDrawdown(); }

   sequence.status = STATUS_STOPPED;
   SS.StopConditions();
   if (IsLogInfo()) logInfo("StopSequence(4)  "+ sequence.name +" sequence stopped");

   // pause/stop the tester according to the debug configuration
   if (IsTesting()) {
      if (!IsVisualMode())         Tester.Stop("StopSequence(5)");
      else if (tester.onStopPause) Tester.Pause("StopSequence(6)");
   }
   return(!catch("StopSequence(7)"));
}


/**
 * Update pending orders and PL with current market data.
 *
 * @param  _InOut_ bool gridChanged - whether the current gridlevel changed
 *
 * @return bool - success status
 */
bool UpdateStatus(bool &gridChanged) {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("UpdateStatus(1)  "+ sequence.name +" cannot update order status of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   gridChanged = gridChanged!=0;

   if (!UpdateStatus_(D_LONG,  gridChanged, long.totalLots, long.avgPrice,   long.minLevel,  long.maxLevel,  long.slippage,  long.floatingPL,  long.maxProfit,  long.maxDrawdown,  long.ticket,  long.level,  long.lots,  long.pendingType,  long.pendingPrice,  long.type,  long.openTime,  long.openPrice,  long.closeTime,  long.closePrice,  long.swap,  long.commission,  long.profit))  return(false);
   if (!UpdateStatus_(D_SHORT, gridChanged, short.totalLots, short.avgPrice, short.minLevel, short.maxLevel, short.slippage, short.floatingPL, short.maxProfit, short.maxDrawdown, short.ticket, short.level, short.lots, short.pendingType, short.pendingPrice, short.type, short.openTime, short.openPrice, short.closeTime, short.closePrice, short.swap, short.commission, short.profit)) return(false);

   if (gridChanged) {
      sequence.totalLots = NormalizeDouble(long.totalLots - short.totalLots, 2);
      sequence.avgPrice  = NormalizeDouble(MathDiv(long.totalLots*long.avgPrice - short.totalLots*short.avgPrice, sequence.totalLots), Digits);
      SS.TotalLots();
   }
   long.totalPL        = long.floatingPL;
   short.totalPL       = short.floatingPL;
   sequence.floatingPL = NormalizeDouble(long.floatingPL + short.floatingPL, 2);
   sequence.closedPL   = NormalizeDouble(long.closedPL   + short.closedPL,   2);
   sequence.totalPL    = NormalizeDouble(sequence.floatingPL + sequence.closedPL, 2); SS.TotalPL();

   if      (sequence.totalPL > sequence.maxProfit  ) { sequence.maxProfit   = sequence.totalPL; SS.MaxProfit();   }
   else if (sequence.totalPL < sequence.maxDrawdown) { sequence.maxDrawdown = sequence.totalPL; SS.MaxDrawdown(); }

   return(!catch("UpdateStatus(2)"));
}


/**
 * Helper for UpdateStatus(). Updates order and PL status of a single grid direction.
 *
 * @return bool - success status
 */
bool UpdateStatus_(int direction, bool &gridChanged, double &totalLots, double &avgPrice, int &minLevel, int &maxLevel, double &slippage, double &floatingPL, double &maxProfit, double &maxDrawdown, int tickets[], int levels[], double lots[], int pendingTypes[], double pendingPrices[], int &types[], datetime &openTimes[], double &openPrices[], datetime &closeTimes[], double &closePrices[], double &swaps[], double &commissions[], double &profits[]) {
   if (direction==D_LONG  && !long.enabled)  return(true);
   if (direction==D_SHORT && !short.enabled) return(true);

   double sumPrices = 0;
   floatingPL = 0;
   int orders = ArraySize(tickets);

   for (int i=0; i < orders; i++) {
      if (!SelectTicket(tickets[i], "UpdateStatus(3)")) return(false);

      if (types[i] == OP_UNDEFINED) {                             // last time a pending order
         if (OrderType() != pendingTypes[i]) {                    // the pending order was executed
            types      [i] = OrderType();
            openTimes  [i] = OrderOpenTime();
            openPrices [i] = OrderOpenPrice();
            swaps      [i] = OrderSwap();
            commissions[i] = OrderCommission();
            profits    [i] = OrderProfit();

            if (IsLogInfo()) logInfo("UpdateStatus(4)  "+ sequence.name +" "+ UpdateStatus.OrderFillMsg(direction, i));
            minLevel    = MathMin(levels[i], minLevel);
            maxLevel    = MathMax(levels[i], maxLevel);
            totalLots  += lots[i];
            sumPrices  += lots[i] * openPrices[i];
            slippage    = NormalizeDouble(slippage + ifDouble(direction==D_LONG, openPrices[i]-pendingPrices[i], pendingPrices[i]-openPrices[i]), 1);
            gridChanged = true;
         }
      }
      else {                                                      // last time an open position
         swaps      [i] = OrderSwap();
         commissions[i] = OrderCommission();
         profits    [i] = OrderProfit();
         sumPrices += lots[i] * openPrices[i];
      }
      floatingPL = floatingPL + swaps[i] + commissions[i] + profits[i];
   }

   avgPrice    = NormalizeDouble(MathDiv(sumPrices, totalLots), Digits);
   floatingPL  = NormalizeDouble(floatingPL, 2);                  // update PL numbers
   maxProfit   = MathMax(floatingPL, maxProfit);
   maxDrawdown = MathMin(floatingPL, maxDrawdown);
   return(!catch("UpdateStatus(5)"));
}


/**
 * Compose a log message for a filled entry order.
 *
 * @param  int direction - trade direction
 * @param  int i         - order index
 *
 * @return string
 */
string UpdateStatus.OrderFillMsg(int direction, int i) {
   // #1 Stop Sell 0.1 GBPUSD at 1.5457'2 ("L.8692.+3") was filled[ at 1.5457'2 with 0.3 pip [positive ]slippage] (market: Bid/Ask)
   int ticket, level, pendingType;
   double lots, pendingPrice, openPrice;

   if (direction == D_LONG) {
      ticket       = long.ticket[i];
      level        = long.level[i];
      lots         = long.lots[i];
      pendingType  = long.pendingType[i];
      pendingPrice = long.pendingPrice[i];
      openPrice    = long.openPrice[i];
   }
   else if (direction == D_SHORT) {
      ticket       = short.ticket[i];
      level        = short.level[i];
      lots         = short.lots[i];
      pendingType  = short.pendingType[i];
      pendingPrice = short.pendingPrice[i];
      openPrice    = short.openPrice[i];
   }
   else return(_EMPTY_STR(catch("UpdateStatus.OrderFillMsg(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER)));

   string sType         = OperationTypeDescription(pendingType);
   string sPendingPrice = NumberToStr(pendingPrice, PriceFormat);
   string comment       = ifString(direction==D_LONG, "L.", "S.") + sequence.id +"."+ NumberToStr(level, "+.");
   string message       = "#"+ ticket +" "+ sType +" "+ NumberToStr(lots, ".+") +" "+ Symbol() +" at "+ sPendingPrice +" (\""+ comment +"\") was filled";

   if (NE(pendingPrice, openPrice)) {
      double slippage = (openPrice - pendingPrice)/Pip; if (direction == OP_SELL) slippage = -slippage;
      string sSlippage;
      if (slippage > 0) sSlippage = DoubleToStr(slippage, Digits & 1) +" pip slippage";
      else              sSlippage = DoubleToStr(-slippage, Digits & 1) +" pip positive slippage";
      message = message +" at "+ NumberToStr(openPrice, PriceFormat) +" with "+ sSlippage;
   }
   return(message +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
}


/**
 * Update existing orders and add new or missing ones.
 *
 * @param  int direction [optional] - order direction flags (default: all currently active trade directions)
 *
 * @return bool - success status
 */
bool UpdateOrders(int direction = D_BOTH) {
   if (IsLastError())                         return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("UpdateOrders(1)  "+ sequence.name +" cannot update orders of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (direction & (~D_BOTH) && 1)            return(!catch("UpdateOrders(2)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   // (1) For scaling down (martingale) we use limit orders.  | if limits are filled new limits are added      | ok | Grid.AddPendingOrder(level) |
   //                                                         |                                                |    |                             |
   // (2) For scaling up (pyramid) we may use:                |                                                |    |                             |
   //     - stop orders (slippage and spread)                 | if stops are filled new stops are added        | ok | Grid.AddPendingOrder(level) | curently used
   //     - observe the market and add market orders (spread) | if levels are reached new positions are opened |    | Grid.AddPosition(level)     |
   //     - observe the market and add limit orders           | if levels are reached new limits are added     |    | Grid.AddPendingOrder(level) |
   //
   // (3) Depending on the used approach UpdateStatus() needs to monitor different conditions.

   if (direction & D_LONG && 1) {
      if (long.enabled) {
         int orders = ArraySize(long.ticket);
         if (!orders) return(!catch("UpdateOrders(3)  "+ sequence.name +" illegal size of long orders: 0", ERR_ILLEGAL_STATE));

         if (sequence.martingaleEnabled) {            // on Martingale ensure the next limit order for scaling down exists
            if (long.level[0] == long.minLevel) {
               if (!Grid.AddPendingOrder(D_LONG, Min(long.minLevel-1, -2))) return(false);
               orders++;
            }
         }
         if (sequence.pyramidEnabled) {               // on Pyramid ensure the next stop order for scaling up exists
            if (long.level[orders-1] == long.maxLevel) {
               if (!Grid.AddPendingOrder(D_LONG, long.maxLevel+1)) return(false);
               orders++;
            }
         }
      }
   }

   if (direction & D_SHORT && 1) {
      if (short.enabled) {
         orders = ArraySize(short.ticket);
         if (!orders) return(!catch("UpdateOrders(4)  "+ sequence.name +" illegal size of short orders: 0", ERR_ILLEGAL_STATE));

         if (sequence.martingaleEnabled) {            // on Martingale ensure the next limit order for scaling down exists
            if (short.level[0] == short.minLevel) {
               if (!Grid.AddPendingOrder(D_SHORT, Min(short.minLevel-1, -2))) return(false);
               orders++;
            }
         }
         if (sequence.pyramidEnabled) {               // on Pyramid ensure the next stop order for scaling up exists
            if (short.level[orders-1] == short.maxLevel) {
               if (!Grid.AddPendingOrder(D_SHORT, short.maxLevel+1)) return(false);
               orders++;
            }
         }
      }
   }
   return(!catch("UpdateOrders(5)"));
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
 * Return the full name of the instance logfile.
 *
 * @return string - filename or an empty string in tester (no separate logfile)
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
   //int    ticket       = ...                     // use as is
   //int    level        = ...                     // ...
   double   lots         = oe.Lots(oe);
   int      pendingType  = OP_UNDEFINED;
   datetime pendingTime  = NULL;
   double   pendingPrice = NULL;
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
         long.minLevel   = MathMin(level, long.minLevel);
         long.maxLevel   = MathMax(level, long.maxLevel);
         long.slippage   = NormalizeDouble(long.slippage + openPrice - CalculateGridLevel(direction, level), 1);
         long.totalLots += lots;
      }
      else {
         short.minLevel   = MathMin(level, short.minLevel);
         short.maxLevel   = MathMax(level, short.maxLevel);
         short.slippage   = NormalizeDouble(short.slippage + CalculateGridLevel(direction, level) - openPrice, 1);
         short.totalLots += lots;
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
      if (IsLogInfo()) logInfo("Grid.AddPendingOrder(3)  "+ sequence.name +" illegal price "+ OperationTypeDescription(oe.Type(oe)) +" at "+ NumberToStr(oe.OpenPrice(oe), PriceFormat) +" (market: "+ NumberToStr(oe.Bid(oe), PriceFormat) +"/"+ NumberToStr(oe.Ask(oe), PriceFormat) +"), opening "+ ifString(IsStopOrderType(oe.Type(oe)), "limit", "stop") +" order instead", error);
      type = ifInt(type==OA_LIMIT, OA_STOP, OA_LIMIT);
   }

   // prepare dataset
   //int    ticket       = ...                     // use as is
   //int    level        = ...                     // ...
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
 * @return int - index the record was inserted at or -1 (EMPTY) in case of errors
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
      ArrayInsertDouble(long.lots,         i, lots                                 );
      ArrayInsertInt   (long.pendingType,  i, pendingType                          );
      ArrayInsertInt   (long.pendingTime,  i, pendingTime                          );
      ArrayInsertDouble(long.pendingPrice, i, NormalizeDouble(pendingPrice, Digits));
      ArrayInsertInt   (long.type,         i, type                                 );
      ArrayInsertInt   (long.openTime,     i, openTime                             );
      ArrayInsertDouble(long.openPrice,    i, NormalizeDouble(openPrice, Digits)   );
      ArrayInsertInt   (long.closeTime,    i, closeTime                            );
      ArrayInsertDouble(long.closePrice,   i, NormalizeDouble(closePrice, Digits)  );
      ArrayInsertDouble(long.swap,         i, NormalizeDouble(swap,       2)       );
      ArrayInsertDouble(long.commission,   i, NormalizeDouble(commission, 2)       );
      ArrayInsertDouble(long.profit,       i, NormalizeDouble(profit,     2)       );
   }

   else if (direction == D_SHORT) {
      size = ArraySize(short.ticket);

      for (i=0; i < size; i++) {
         if (short.level[i] == level) return(_EMPTY(catch("Orders.AddRecord(2)  "+ sequence.name +" cannot overwrite ticket #"+ short.ticket[i] +" of level "+ level +" (index "+ i +")", ERR_ILLEGAL_STATE)));
         if (short.level[i] > level)  break;
      }
      ArrayInsertInt   (short.ticket,       i, ticket                               );
      ArrayInsertInt   (short.level,        i, level                                );
      ArrayInsertDouble(short.lots,         i, lots                                 );
      ArrayInsertInt   (short.pendingType,  i, pendingType                          );
      ArrayInsertInt   (short.pendingTime,  i, pendingTime                          );
      ArrayInsertDouble(short.pendingPrice, i, NormalizeDouble(pendingPrice, Digits));
      ArrayInsertInt   (short.type,         i, type                                 );
      ArrayInsertInt   (short.openTime,     i, openTime                             );
      ArrayInsertDouble(short.openPrice,    i, NormalizeDouble(openPrice, Digits)   );
      ArrayInsertInt   (short.closeTime,    i, closeTime                            );
      ArrayInsertDouble(short.closePrice,   i, NormalizeDouble(closePrice, Digits)  );
      ArrayInsertDouble(short.swap,         i, NormalizeDouble(swap,       2)       );
      ArrayInsertDouble(short.commission,   i, NormalizeDouble(commission, 2)       );
      ArrayInsertDouble(short.profit,       i, NormalizeDouble(profit,     2)       );
   }
   else return(_EMPTY(catch("Orders.AddRecord(3)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER)));

   return(ifInt(catch("Orders.AddRecord(4)"), EMPTY, i));
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
                                  "Long:            ",              sLongLots,                                          NL,
                                  "Short:            ",             sShortLots,                                         NL,
                                  "Total:            ",             sTotalLots,                                         NL,
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
      SS.TotalLots();
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
         sSequencePlStats = StringConcatenate("  (", sSequenceMaxProfit, "/", sSequenceMaxDrawdown, ")");
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
 * ShowStatus: Update the string representation of "long.totalLots", "short.totalLots" and "sequence.totalLots".
 */
void SS.TotalLots() {
   if (IsChart()) {
      if (!long.totalLots) sLongLots = "-";
      else                 sLongLots = NumberToStr(long.totalLots, "+.+") +" lot at level "+ long.maxLevel + ifString(long.slippage, ", slippage: "+ DoubleToStr(long.slippage, 1) +" pip", "");

      if (!short.totalLots) sShortLots = "-";
      else                  sShortLots = NumberToStr(-short.totalLots, "+.+") +" lot at level "+ short.maxLevel + ifString(short.slippage, ", slippage: "+ DoubleToStr(short.slippage, 1) +" pip", "");

      if (!long.totalLots && !short.totalLots) sTotalLots = "-";
      else if (!sequence.totalLots)            sTotalLots = "±0 (hedged)";
      else                                     sTotalLots = NumberToStr(sequence.totalLots, "+.+") +" lot @ "+ NumberToStr(sequence.avgPrice, PriceFormat);
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
