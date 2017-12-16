/**
 * AngryBird (aka Headless Chicken)
 *
 * A Martingale system with nearly random entry (like a headless chicken) and very low profit target. Always in the market.
 * Risk control via drawdown limit. Adding of positions on BarOpen only. The distance between consecutive trades adapts to
 * the past trading range.
 * The lower the equity drawdown limit and profit target the better (and less realistic) the observed results. As volatility
 * increases so does the probability of major losses.
 *
 *
 * Change log:
 * -----------
 *  - Removed RSI entry filter as it has no statistical edge but only reduces opportunities.
 *  - Removed CCI stop as the drawdown limit is a better stop condition.
 *  - Removed the MaxTrades limitation as the drawdown limit must trigger before that number anyway (on sane use).
 *  - Added explicit grid size limits (parameters "Grid.Min.Pips", "Grid.Max.Pips", "Grid.Contractable").
 *  - Added parameter "Start.Direction" to kick-start the chicken in a given direction (doesn't wait for BarOpen).
 *  - Added parameters "TakeProfit.Continue" and "StopLoss.Continue" to put the chicken to rest after TakeProfit or StopLoss
 *    are hit. Enough hip-hop.
 *  - Added parameter "Lots.StartVola.Percent" for volitility based lotsize calculation based on account balance and weekly
 *    instrument volatility. Can also be used for compounding.
 *  - If TakeProfit.Continue or StopLoss.Continue are set to FALSE the status display will freeze and keep the current status
 *    for inspection once the sequence has been finished.
 *
 *
 * Rewrite and extended version of AngryBird EA (see https://www.mql5.com/en/code/12872) wich in turn is a remake of
 * Ilan 1.6 Dynamic HT (see https://www.mql5.com/en/code/12220). The first checked-in version matches the original sources.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern double Lots.StartSize               = 0;          // fixed lotsize or 0 = dynamic lotsize using Lots.StartVola
extern int    Lots.StartVola.Percent       = 30;         // expected weekly equity volatility, see CalculateLotSize()
extern double Lots.Multiplier              = 1.4;        // was 2

extern string Start.Mode                   = "Long | Short | Headless | Legless | Auto*";

extern double TakeProfit.Pips              = 2;
extern bool   TakeProfit.Continue          = false;      // whether or not to continue after TakeProfit is hit

extern int    StopLoss.Percent             = 20;
extern bool   StopLoss.Continue            = false;      // whether or not to continue after StopLoss is hit

extern double Grid.Min.Pips                = 3.0;        // was "DefaultPips/DEL = 0.4"
extern double Grid.Max.Pips                = 0;          // was "DefaultPips*DEL = 3.6"
extern bool   Grid.Contractable            = false;      // whether or not the grid is allowed to contract (was TRUE)
extern int    Grid.Range.Periods           = 70;         // was 24
extern int    Grid.Range.Divider           = 3;          // was "DEL"
extern string _____________________________;

extern double Exit.Trail.Pips              = 0;          // trailing stop size in pips (was 1)
extern double Exit.Trail.MinProfit.Pips    = 1;          // minimum profit in pips to start trailing

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/EventListener.BarOpen.mqh>
#include <functions/JoinStrings.mqh>
#include <iFunctions/@ATR.mqh>
#include <structs/xtrade/OrderExecution.mqh>


// runtime status
#define STATUS_UNINITIALIZED  0
#define STATUS_PENDING        1
#define STATUS_STARTING       2
#define STATUS_PROGRESSING    3
#define STATUS_STOPPING       4
#define STATUS_STOPPED        5

int    status;
string statusDescr[] = {"uninitialized", "pending", "starting", "progressing", "stopping", "stopped"};

// lotsize management
double lots.calculatedSize;                  // calculated lot size (not used if Lots.StartSize is set)
double lots.startSize;                       // actual starting lot size (can differ from input Lots.StartSize)
int    lots.startVola;                       // resulting starting vola (can differ from input Lots.StartVola)

// grid management
int    grid.timeframe = PERIOD_M1;           // timeframe used for grid size calculation
string grid.startDirection;
int    grid.level;                           // current grid level: >= 0
double grid.currentSize;                     // current market grid size in pip (may be overridden by grid.minSize)
double grid.minSize;                         // enforced minimum grid size in pip (can change over time)
double grid.appliedSize;                     // last applied grid size in pip when calculating entry levels

// position tracking
int    position.tickets   [];                // currently open orders
double position.lots      [];                // order lot sizes
double position.openPrices[];                // order open prices

int    position.level;                       // current position level: positive or negative
double position.totalSize;                   // current total position size
double position.totalPrice;                  // current average position price
double position.tpPrice;                     // current TakeProfit price
double position.slPrice;                     // current StopLoss price
double position.startEquity;                 // equity in account currency at sequence start
double position.maxDrawdown;                 // max. drawdown in account currency
double position.plPip     = EMPTY_VALUE;     // current PL in pip
double position.plPipMin  = EMPTY_VALUE;     // min. PL in pip
double position.plPipMax  = EMPTY_VALUE;     // max. PL in pip
double position.plUPip    = EMPTY_VALUE;     // current PL in unit pip
double position.plUPipMin = EMPTY_VALUE;     // min. PL in unit pip
double position.plUPipMax = EMPTY_VALUE;     // max. PL in unit pip
double position.plPct     = EMPTY_VALUE;     // current PL in percent
double position.plPctMin  = EMPTY_VALUE;     // min. PL in percent
double position.plPctMax  = EMPTY_VALUE;     // max. PL in percent

bool   exit.trailStop;
double exit.trailLimitPrice;                 // current price limit to start trailing stops

// OrderSend() defaults
string os.name        = "AngryBird";
int    os.magicNumber = 2222;
double os.slippage    = 0.1;

// cache variables to speed-up execution of ShowStatus()
string str.lots.startSize     = "-";

string str.grid.currentSize   = "-";
string str.grid.minSize       = "-";

string str.position.slPrice   = "-";
string str.position.tpPip     = "-";
string str.position.plPip     = "-";
string str.position.plPipMin  = "-";
string str.position.plPipMax  = "-";
string str.position.plUPip    = "-";
string str.position.plUPipMin = "-";
string str.position.plUPipMax = "-";
string str.position.plPct     = "-";
string str.position.plPctMin  = "-";
string str.position.plPctMax  = "-";


// reasons for calling ResetRuntimeStatus()
#define REASON_TAKEPROFIT     1
#define REASON_STOPLOSS       2


#include <AngryBird/functions.mqh>
#include <AngryBird/init.mqh>
#include <AngryBird/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   UpdateStatus();

   // check exit conditions on every tick
   if (grid.level > 0) {
      CheckOpenOrders();
      CheckDrawdown();

      if (exit.trailStop)
         TrailProfits();                                    // fails live because done on every tick

      if (__STATUS_OFF) return(last_error);
   }


   if (grid.startDirection == "auto") {
      // check entry conditions on BarOpen
      if (EventListener.BarOpen(grid.timeframe)) {
         if (!position.level) {
            if      (Close[1] > Close[2]) OpenPosition(OP_BUY);
            else if (Close[1] < Close[2]) OpenPosition(OP_SELL);
         }
         else {
            double nextLevel = UpdateGridSize();
            if (!nextLevel) return(last_error);

            if (position.level > 0) {
               if (LE(Ask, nextLevel, Digits)) OpenPosition(OP_BUY);
            }
            else /*position.level < 0*/ {
               if (GE(Bid, nextLevel, Digits)) OpenPosition(OP_SELL);
            }
         }
      }
   }
   else {
      if (!grid.level)
         OpenPosition(ifInt(grid.startDirection=="long", OP_BUY, OP_SELL));
      grid.startDirection = "auto";
   }
   return(last_error);
}


/**
 * Calculate the current grid size and return the price at which to open the next position.
 *
 * @return double - price or NULL if the sequence was not yet started or if an error occurred
 */
double UpdateGridSize() {
   if (__STATUS_OFF) return(NULL);

   static int    lastTick;
   static double lastResult;
   if (Tick == lastTick)                                       // prevent multiple calculations per tick
      return(lastResult);

   double high = iHigh(NULL, grid.timeframe, iHighest(NULL, grid.timeframe, MODE_HIGH, Grid.Range.Periods, 1));
   double low  =  iLow(NULL, grid.timeframe,  iLowest(NULL, grid.timeframe, MODE_LOW,  Grid.Range.Periods, 1));

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("UpdateGridSize(1)", error));
      warn("UpdateGridSize(2)  "+ PeriodDescription(grid.timeframe) +" => ERS_HISTORY_UPDATE, reported "+ Grid.Range.Periods +"x"+ PeriodDescription(grid.timeframe) +" range: "+ DoubleToStr((high-low)/Pip, 1) +" pip", error);
   }

   double barRange  = (high-low) / Pip;
   double gridSize  = barRange / Grid.Range.Divider;
   SetGridCurrentSize(NormalizeDouble(gridSize, 1));

   double appliedSize = grid.currentSize;
   if (!Grid.Contractable)
      appliedSize = MathMax(appliedSize, grid.minSize);        // prevent grid size shrinking

   appliedSize = MathMax(appliedSize, Grid.Min.Pips);          // enforce lower limit
   if (Grid.Max.Pips > 0)
      appliedSize = MathMin(appliedSize, Grid.Max.Pips);       // enforce upper limit
   grid.appliedSize = NormalizeDouble(appliedSize, 1);

   double result = 0;

   if (grid.level > 0) {
      double lastPrice = position.openPrices[grid.level-1];
      double nextPrice = lastPrice - Sign(position.level) * grid.appliedSize * Pips;
      result = NormalizeDouble(nextPrice, Digits);
   }

   lastTick   = Tick;
   lastResult = result;

   return(result);
}


/**
 * Calculate the lot size to use for the specified sequence level.
 *
 * @param  int level
 *
 * @return double - lotsize or NULL in case of an error
 */
double CalculateLotsize(int level) {
   if (__STATUS_OFF) return(NULL);
   if (level < 1)    return(!catch("CalculateLotsize(1)  invalid parameter level = "+ level +" (not positive)", ERR_INVALID_PARAMETER));

   // decide whether to use manual or calculated mode
   bool   manualMode = Lots.StartSize > 0;
   double usedSize;


   // (1) manual mode
   if (manualMode) {
      if (!lots.startSize)
         SetLotsStartSize(Lots.StartSize);
      lots.calculatedSize = 0;
      usedSize = Lots.StartSize;
   }


   // (2) calculated mode
   else {
      if (!lots.calculatedSize) {
         // calculate using Lots.StartVola
         // unleveraged lotsize
         double tickSize        = MarketInfo(Symbol(), MODE_TICKSIZE);  if (!tickSize)  return(!catch("CalculateLotsize(2)  invalid MarketInfo(MODE_TICKSIZE) = 0", ERR_RUNTIME_ERROR));
         double tickValue       = MarketInfo(Symbol(), MODE_TICKVALUE); if (!tickValue) return(!catch("CalculateLotsize(3)  invalid MarketInfo(MODE_TICKVALUE) = 0", ERR_RUNTIME_ERROR));
         double lotValue        = Bid/tickSize * tickValue;                      // value of a full lot in account currency
         double unleveragedLots = AccountBalance() / lotValue;                   // unleveraged lotsize (leverage 1:1)
         if (unleveragedLots < 0) unleveragedLots = 0;

         // expected weekly range: maximum of ATR(14xW1), previous TrueRange(W1) and current TrueRange(W1)
         double a = @ATR(NULL, PERIOD_W1, 14, 1);                                // ATR(14xW1)
            if (!a) return(_NULL(debug("CalculateLotsize(4)  W1", last_error)));
         double b = @ATR(NULL, PERIOD_W1,  1, 1);                                // previous TrueRange(W1)
            if (!b) return(_NULL(debug("CalculateLotsize(5)  W1", last_error)));
         double c = @ATR(NULL, PERIOD_W1,  1, 0);                                // current TrueRange(W1)
            if (!c) return(_NULL(debug("CalculateLotsize(6)  W", last_error)));
         double expectedRange    = MathMax(a, MathMax(b, c));
         double expectedRangePct = expectedRange/Close[0] * 100;

         // leveraged lotsize = Lots.StartSize
         double leverage     = Lots.StartVola.Percent / expectedRangePct;        // leverage weekly range vola to user-defined vola
         lots.calculatedSize = leverage * unleveragedLots;
         double startSize    = SetLotsStartSize(NormalizeLots(lots.calculatedSize));
         lots.startVola      = Round(startSize / unleveragedLots * expectedRangePct);
      }
      if (!lots.startSize) {
         SetLotsStartSize(NormalizeLots(lots.calculatedSize));
      }
      usedSize = lots.calculatedSize;
   }


   // (3) calculate the requested level's lotsize
   double calculated = usedSize * MathPow(Lots.Multiplier, level-1);
   double result     = NormalizeLots(calculated);
   if (!result) return(!catch("CalculateLotsize(7)  The normalized lot size 0.0 for level "+ level +" is too small (calculated="+ NumberToStr(calculated, ".+") +"  MODE_MINLOT="+ NumberToStr(MarketInfo(Symbol(), MODE_MINLOT), ".+") +")", ERR_INVALID_TRADE_VOLUME));

   double ratio = result / calculated;
   if (ratio < 1) ratio = 1/ratio;
   if (ratio > 1.15) {                                                           // ask for confirmation if the resulting lotsize deviates > 15% from the calculation
      static bool lotsConfirmed = false; if (!lotsConfirmed) {
         PlaySoundEx("Windows Notify.wav");
         string msg = "The resulting lot size for level "+ level +" significantly deviates from the calculated one: "+ NumberToStr(result, ".+") +" instead of "+ NumberToStr(calculated, ".+");
         int button = MessageBoxEx(__NAME__ +" - CalculateLotsize()", ifString(IsDemoFix(), "", "- Real Account -\n\n") + msg, MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK)
            return(!SetLastError(ERR_CANCELLED_BY_USER));
         lotsConfirmed = true;
      }
   }
   return(result);
}


/**
 * Open a position at the next sequence level.
 *
 * @param  int type - order operation type: OP_BUY | OP_SELL
 *
 * @return bool - success status
 */
bool OpenPosition(int type) {
   if (__STATUS_OFF) return(false);

   if (InitReason() != IR_USER) {
      if (Tick <= 1) if (!ConfirmFirstTickTrade("OpenPosition()", "Do you really want to submit a Market "+ OrderTypeDescription(type) +" order now?"))
         return(!SetLastError(ERR_CANCELLED_BY_USER));
   }

   // reset the start lotsize of a new sequence to trigger re-calculation and thus provide compounding (if configured)
   if (!grid.level)
      SetLotsStartSize(NULL);

   string   symbol      = Symbol();
   double   price       = NULL;
   double   lots        = CalculateLotsize(grid.level+1); if (!lots) return(false);
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   string   comment     = os.name +"-"+ (grid.level+1) +"-"+ DoubleToStr(grid.appliedSize, 1);
   datetime expires     = NULL;
   color    markerColor = ifInt(type==OP_BUY, Blue, Red);
   int      oeFlags     = NULL;
   int      oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);

   int ticket = OrderSendEx(symbol, type, lots, price, os.slippage, stopLoss, takeProfit, comment, os.magicNumber, expires, markerColor, oeFlags, oe);
   if (IsEmpty(ticket)) return(false);

   // update levels and ticket data
   grid.level++;                                                  // update grid.level
   if (!Grid.Contractable) {
      SetGridMinSize(MathMax(grid.minSize, grid.appliedSize));    // update grid.minSize
   }
   if (type == OP_BUY) position.level++;                          // update position.level
   else                position.level--;

   ArrayPushInt   (position.tickets,    ticket);                  // store ticket data
   ArrayPushDouble(position.lots,       oe.Lots(oe));
   ArrayPushDouble(position.openPrices, oe.OpenPrice(oe));

   // update takeprofit and stoploss
   double avgPrice = UpdateTotalPosition();
   int direction   = Sign(position.level);
   double tpPrice  = NormalizeDouble(avgPrice + direction * TakeProfit.Pips*Pips, Digits);

   for (int i=0; i < grid.level; i++) {
      if (!OrderSelect(position.tickets[i], SELECT_BY_TICKET))
         return(false);
      OrderModify(OrderTicket(), NULL, OrderStopLoss(), tpPrice, NULL, Blue);
   }
   if (exit.trailStop)
      exit.trailLimitPrice = NormalizeDouble(avgPrice + direction * Exit.Trail.MinProfit.Pips*Pips, Digits);

   if (grid.level == 1) {
      position.startEquity = NormalizeDouble(AccountEquity() - AccountCredit(), 2);
      position.maxDrawdown = NormalizeDouble(position.startEquity * StopLoss.Percent/100, 2);
   }
   double maxDrawdownPips = position.maxDrawdown / PipValue(position.totalSize);
   SetPositionSlPrice(NormalizeDouble(avgPrice - direction * maxDrawdownPips*Pips, Digits));

   UpdateStatus();
   return(!catch("OpenPosition(1)"));
}


/**
 * Check if open orders have been closed.
 */
void CheckOpenOrders() {
   if (__STATUS_OFF || !position.level)
      return;

   OrderSelect(position.tickets[0], SELECT_BY_TICKET);
   if (!OrderCloseTime())
      return;

   ResetRuntimeStatus(REASON_TAKEPROFIT);
}


/**
 * Enforce the drawdown limit.
 */
void CheckDrawdown() {
   if (__STATUS_OFF || !position.level)
      return;

   if (position.level > 0) {                       // make sure the limit is not triggered by spread widening
      if (Ask > position.slPrice)
         return;
   }
   else if (Bid < position.slPrice) {
      return;
   }

   debug("CheckDrawdown(1)  Drawdown limit of "+ StopLoss.Percent +"% triggered, closing all trades.");

   ClosePositions();
   ResetRuntimeStatus(REASON_STOPLOSS);
}


/**
 * Close all open positions.
 */
void ClosePositions() {
   if (__STATUS_OFF || !grid.level)
      return;

   if (Tick <= 1) if (!ConfirmFirstTickTrade("ClosePositions()", "Do you really want to close all open positions now?"))
      return(SetLastError(ERR_CANCELLED_BY_USER));

   int oes[][ORDER_EXECUTION.intSize];
   ArrayResize(oes, grid.level);
   InitializeByteBuffer(oes, ORDER_EXECUTION.size);

   OrderMultiClose(position.tickets, os.slippage, Orange, NULL, oes);
}


/**
 * Reset runtime variables.
 *
 * @param  int reason - reason code: REASON_TAKEPROFIT | REASON_STOPLOSS
 *
 * @return bool - success status
 */
bool ResetRuntimeStatus(int reason) {
   if (reason!=REASON_TAKEPROFIT && reason!=REASON_STOPLOSS)
      return(!catch("ResetRuntimeStatus(1)  Invalid parameter reason: "+ reason +" (not a reason code)", ERR_INVALID_PARAMETER));

   if ((reason==REASON_TAKEPROFIT && TakeProfit.Continue) || (reason==REASON_STOPLOSS && StopLoss.Continue)) {
      grid.level          = 0;
      SetGridMinSize(Grid.Min.Pips);
      position.level      = 0;
      position.totalSize  = 0;
      position.totalPrice = 0;

      ArrayResize(position.tickets,    0);
      ArrayResize(position.lots,       0);
      ArrayResize(position.openPrices, 0);

      position.startEquity = 0;
      position.maxDrawdown = 0;
      SetPositionSlPrice  (0);
      SetPositionPlPip    (EMPTY_VALUE);
      SetPositionPlPipMin (EMPTY_VALUE);
      SetPositionPlPipMax (EMPTY_VALUE);
      SetPositionPlUPip   (EMPTY_VALUE);
      SetPositionPlUPipMin(EMPTY_VALUE);
      SetPositionPlUPipMax(EMPTY_VALUE);
      SetPositionPlPct    (EMPTY_VALUE);
      SetPositionPlPctMin (EMPTY_VALUE);
      SetPositionPlPctMax (EMPTY_VALUE);
   }
   else {
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = ERR_CANCELLED_BY_USER;
   }
   return(true);
}


/**
 * Trail stops of a profitable trade sequence. Will fail in real life because it trails each order on every tick.
 *
 * @return bool - function success status; not if orders have indeed beeen trailed on the current tick
 */
void TrailProfits() {
   if (__STATUS_OFF || !grid.level)
      return(true);

   if (position.level > 0) {
      if (Bid < exit.trailLimitPrice) return(true);
      double stop = Bid - Exit.Trail.Pips*Pips;
   }
   else /*position.level < 0*/ {
      if (Ask > exit.trailLimitPrice) return(true);
      stop = Ask + Exit.Trail.Pips*Pips;
   }
   stop = NormalizeDouble(stop, Digits);


   for (int i=0; i < grid.level; i++) {
      OrderSelect(position.tickets[i], SELECT_BY_TICKET);

      if (position.level > 0) {
         if (stop > OrderStopLoss()) {
            if (!ConfirmFirstTickTrade("TrailProfits(1)", "Do you really want to trail TakeProfit now?"))
               return(!SetLastError(ERR_CANCELLED_BY_USER));
            OrderModify(OrderTicket(), NULL, stop, OrderTakeProfit(), NULL, Red);
         }
      }
      else /*position.level < 0*/ {
         if (!OrderStopLoss() || stop < OrderStopLoss()) {
            if (!ConfirmFirstTickTrade("TrailProfits(2)", "Do you really want to trail TakeProfit now?"))
               return(!SetLastError(ERR_CANCELLED_BY_USER));
            OrderModify(OrderTicket(), NULL, stop, OrderTakeProfit(), NULL, Red);
         }
      }
   }
   return(!catch("TrailProfits(3)"));
}


/**
 * Update total position size and price.
 *
 * @return double - average position price
 */
double UpdateTotalPosition() {
   if (__STATUS_OFF) return(NULL);

   int    levels = ArraySize(position.lots);
   double sumPrice, sumLots;

   for (int i=0; i < levels; i++) {
      sumPrice += position.lots[i] * position.openPrices[i];
      sumLots  += position.lots[i];
   }

   if (!levels) {
      position.totalSize  = 0;
      position.totalPrice = 0;
   }
   else {
      position.totalSize  = NormalizeDouble(sumLots, 2);
      position.totalPrice = sumPrice / sumLots;
   }
   return(position.totalPrice);
}


/**
 * Additional safety net against execution errors. Ask for confirmation that a trade command is to be executed at the very
 * first tick (e.g. at terminal start). Will only ask once even if called multiple times during a single tick (in a loop).
 *
 * @param  string location - confirmation location for logging
 * @param  string message  - confirmation message
 *
 * @return bool - confirmation result
 */
bool ConfirmFirstTickTrade(string location, string message) {
   if (__STATUS_OFF) return(false);

   static bool done=false, confirmed=false;
   if (!done) {
      if (Tick > 1 || IsTesting()) {
         confirmed = true;
      }
      else {
         PlaySoundEx("Windows Notify.wav");
         int button = MessageBoxEx(__NAME__ + ifString(!StringLen(location), "", " - "+ location), ifString(IsDemoFix(), "", "- Real Account -\n\n") + message, MB_ICONQUESTION|MB_OKCANCEL);
         if (button == IDOK) confirmed = true;
      }
      done = true;
   }
   return(confirmed);
}


/**
 * Save input parameters and runtime status in the chart to be able to continue a sequence after terminal re-start, profile
 * change or recompilation.
 *
 * @return bool - success status
 */
bool StoreRuntimeStatus() {
   // input parameters
   Chart.StoreDouble(__NAME__ +".input.Lots.StartSize",            Lots.StartSize           );
   Chart.StoreInt   (__NAME__ +".input.Lots.StartVola.Percent",    Lots.StartVola.Percent   );
   Chart.StoreDouble(__NAME__ +".input.Lots.Multiplier",           Lots.Multiplier          );
   Chart.StoreString(__NAME__ +".input.Start.Mode",                Start.Mode               );
   Chart.StoreDouble(__NAME__ +".input.TakeProfit.Pips",           TakeProfit.Pips          );
   Chart.StoreBool  (__NAME__ +".input.TakeProfit.Continue",       TakeProfit.Continue      );
   Chart.StoreInt   (__NAME__ +".input.StopLoss.Percent",          StopLoss.Percent         );
   Chart.StoreBool  (__NAME__ +".input.StopLoss.Continue",         StopLoss.Continue        );
   Chart.StoreDouble(__NAME__ +".input.Grid.Min.Pips",             Grid.Min.Pips            );
   Chart.StoreDouble(__NAME__ +".input.Grid.Max.Pips",             Grid.Max.Pips            );
   Chart.StoreBool  (__NAME__ +".input.Grid.Contractable",         Grid.Contractable        );
   Chart.StoreInt   (__NAME__ +".input.Grid.Range.Periods",        Grid.Range.Periods       );
   Chart.StoreInt   (__NAME__ +".input.Grid.Range.Divider",        Grid.Range.Divider       );
   Chart.StoreDouble(__NAME__ +".input.Exit.Trail.Pips",           Exit.Trail.Pips          );
   Chart.StoreDouble(__NAME__ +".input.Exit.Trail.MinProfit.Pips", Exit.Trail.MinProfit.Pips);

   // runtime status
   Chart.StoreBool  (__NAME__ +".runtime.__STATUS_INVALID_INPUT", __STATUS_INVALID_INPUT);
   Chart.StoreBool  (__NAME__ +".runtime.__STATUS_OFF",           __STATUS_OFF          );
   Chart.StoreInt   (__NAME__ +".runtime.__STATUS_OFF.reason",    __STATUS_OFF.reason   );
   Chart.StoreDouble(__NAME__ +".runtime.lots.calculatedSize",    lots.calculatedSize   );
   Chart.StoreDouble(__NAME__ +".runtime.lots.startSize",         lots.startSize        );
   Chart.StoreInt   (__NAME__ +".runtime.lots.startVola",         lots.startVola        );
   Chart.StoreInt   (__NAME__ +".runtime.grid.level",             grid.level            );
   Chart.StoreDouble(__NAME__ +".runtime.grid.currentSize",       grid.currentSize      );
   Chart.StoreDouble(__NAME__ +".runtime.grid.minSize",           grid.minSize          );
   Chart.StoreDouble(__NAME__ +".runtime.position.startEquity",   position.startEquity  );
   Chart.StoreDouble(__NAME__ +".runtime.position.maxDrawdown",   position.maxDrawdown  );
   Chart.StoreDouble(__NAME__ +".runtime.position.slPrice",       position.slPrice      );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPip",         position.plPip        );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPipMin",      position.plPipMin     );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPipMax",      position.plPipMax     );
   Chart.StoreDouble(__NAME__ +".runtime.position.plUPip",        position.plUPip       );
   Chart.StoreDouble(__NAME__ +".runtime.position.plUPipMin",     position.plUPipMin    );
   Chart.StoreDouble(__NAME__ +".runtime.position.plUPipMax",     position.plUPipMax    );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPct",         position.plPct        );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPctMin",      position.plPctMin     );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPctMax",      position.plPctMax     );

   return(!catch("StoreRuntimeStatus(1)"));
}


/**
 * Restore stored input parameters and runtime status from the chart to continue a sequence after recompilation, terminal
 * re-start or profile change.
 *
 * @return bool - whether or not runtime data was found and successfully restored
 */
bool RestoreRuntimeStatus() {
   if (__STATUS_OFF) return(false);

   bool restored = false;

   // runtime status
   string label = __NAME__ + ".runtime.__STATUS_INVALID_INPUT";
   if (ObjectFind(label) == 0) {
      string sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreRuntimeStatus(1)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      __STATUS_INVALID_INPUT = StrToInteger(sValue) != 0;                  // (bool)(int) string
      restored = true;
   }

   label = __NAME__ +".runtime.__STATUS_OFF";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreRuntimeStatus(2)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      __STATUS_OFF = StrToInteger(sValue) != 0;                            // (bool)(int) string
      restored = true;
   }

   label = __NAME__ +".runtime.__STATUS_OFF.reason";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreRuntimeStatus(3)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      __STATUS_OFF.reason = StrToInteger(sValue);                          // (int) string
      restored = true;
   }

   label = __NAME__ +".runtime.lots.calculatedSize";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(4)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      double dValue = StrToDouble(sValue);
      if (LT(dValue, 0))            return(!catch("RestoreRuntimeStatus(5)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      lots.calculatedSize = dValue;                                        // (double) string
      restored = true;
   }

   label = __NAME__ +".runtime.lots.startSize";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(6)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      if (LT(dValue, 0))            return(!catch("RestoreRuntimeStatus(7)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      SetLotsStartSize(NormalizeDouble(dValue, 2));                        // (double) string
      restored = true;
   }

   label = __NAME__ +".runtime.lots.startVola";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreRuntimeStatus(8)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      lots.startVola = StrToInteger(sValue);                               // (int) string
      restored = true;
   }

   label = __NAME__ +".runtime.grid.level";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreRuntimeStatus(9)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      grid.level = StrToInteger(sValue);                                   // (int) string
      restored = true;
   }

   label = __NAME__ +".runtime.grid.currentSize";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(10)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      if (LT(dValue, 0))            return(!catch("RestoreRuntimeStatus(11)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      SetGridCurrentSize(NormalizeDouble(dValue, 1));                      // (double) string
      restored = true;
   }

   label = __NAME__ +".runtime.grid.minSize";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(12)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      if (LT(dValue, 0))            return(!catch("RestoreRuntimeStatus(13)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      SetGridMinSize(NormalizeDouble(dValue, 1));                          // (double) string
      restored = true;
   }

   label = __NAME__ +".runtime.position.startEquity";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(14)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      if (LT(dValue, 0))            return(!catch("RestoreRuntimeStatus(15)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      position.startEquity = NormalizeDouble(dValue, 2);                   // (double) string
      restored = true;
   }

   label = __NAME__ +".runtime.position.maxDrawdown";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(16)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      if (LT(dValue, 0))            return(!catch("RestoreRuntimeStatus(17)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      position.maxDrawdown = NormalizeDouble(dValue, 2);                   // (double) string
      restored = true;
   }

   label = __NAME__ +".runtime.position.slPrice";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(18)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      if (LT(dValue, 0))            return(!catch("RestoreRuntimeStatus(19)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      SetPositionSlPrice(NormalizeDouble(dValue, Digits));                 // (double) string
      restored = true;
   }

   label = __NAME__ +".runtime.position.plPip";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(20)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlPip(NormalizeDouble(dValue, 1));                        // (double) string
      restored = true;
   }

   label = __NAME__ +".runtime.position.plPipMin";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(21)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlPipMin(NormalizeDouble(dValue, 1));                     // (double) string
      restored = true;
   }

   label = __NAME__ +".runtime.position.plPipMax";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(22)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlPipMax(NormalizeDouble(dValue, 1));                     // (double) string
      restored = true;
   }

   label = __NAME__ +".runtime.position.plUPip";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(23)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlUPip(NormalizeDouble(dValue, 1));                       // (double) string
      restored = true;
   }

   label = __NAME__ +".runtime.position.plUPipMin";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(24)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlUPipMin(NormalizeDouble(dValue, 1));                    // (double) string
      restored = true;
   }

   label = __NAME__ +".runtime.position.plUPipMax";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(25)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlUPipMax(NormalizeDouble(dValue, 1));                    // (double) string
      restored = true;
   }

   label = __NAME__ +".runtime.position.plPct";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(26)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlPct(NormalizeDouble(dValue, 2));                        // (double) string
      restored = true;
   }

   label = __NAME__ +".runtime.position.plPctMin";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(27)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlPctMin(NormalizeDouble(dValue, 2));                     // (double) string
      restored = true;
   }

   label = __NAME__ +".runtime.position.plPctMax";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(28)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlPctMax(NormalizeDouble(dValue, 2));                     // (double) string
      restored = true;
   }

   if (!catch("RestoreRuntimeStatus(29)"))
      return(restored);
   return(false);
}


/**
 * Update the current runtime status (values that change on every tick).
 *
 * @return bool - success status
 */
bool UpdateStatus() {
   if (__STATUS_OFF) return(false);

   if (1 || !IsTesting())
      UpdateGridSize();                            // only for ShowStatus() on every tick/call

   if (position.level != 0) {
      // position.plPip
      double plPip;
      if (position.level > 0) plPip = SetPositionPlPip((Bid - position.totalPrice) / Pip);
      else                    plPip = SetPositionPlPip((position.totalPrice - Ask) / Pip);

      if (plPip  < position.plPipMin  || position.plPipMin==EMPTY_VALUE)  SetPositionPlPipMin(plPip);
      if (plPip  > position.plPipMax  || position.plPipMax==EMPTY_VALUE)  SetPositionPlPipMax(plPip);

      // position.plUPip
      double units  = position.totalSize / lots.startSize;
      double plUPip = SetPositionPlUPip(units * plPip);

      if (plUPip < position.plUPipMin || position.plUPipMin==EMPTY_VALUE) SetPositionPlUPipMin(plUPip);
      if (plUPip > position.plUPipMax || position.plUPipMax==EMPTY_VALUE) SetPositionPlUPipMax(plUPip);

      // position.plPct
      double profit = plPip * PipValue(position.totalSize);
      double plPct  = SetPositionPlPct(profit / position.startEquity * 100);

      if (plPct  < position.plPctMin  || position.plPctMin==EMPTY_VALUE)  SetPositionPlPctMin(plPct);
      if (plPct  > position.plPctMax  || position.plPctMax==EMPTY_VALUE)  SetPositionPlPctMax(plPct);
   }
   return(true);
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
      statusBox = ShowStatus.Box();

   string str.error;
   if      (__STATUS_OFF)    str.error = StringConcatenate(" switched OFF  [", ErrorDescription(__STATUS_OFF.reason), "]");
   else if (!lots.startSize) CalculateLotsize(1);

   string msg = StringConcatenate(" ", __NAME__, str.error,                                                                                                         NL,
                                  " --------------",                                                                                                                NL,
                                  " Grid level:   ",  grid.level,      "            Size:   ", str.grid.currentSize, "        MinSize:   ", str.grid.minSize,       NL,
                                  " StartLots:    ",  str.lots.startSize, "         Vola:   ", lots.startVola, " %",                                                NL,
                                  " TP:            ", str.position.tpPip,    "      Stop:   ", StopLoss.Percent,  " %         SL:   ",      str.position.slPrice,   NL,
                                  " PL:            ", str.position.plPip,    "      max:    ", str.position.plPipMax, "       min:    ",    str.position.plPipMin,  NL,
                                  " PL upip:     ",   str.position.plUPip,    "     max:    ", str.position.plUPipMax,  "     min:    ",    str.position.plUPipMin, NL,
                                  " PL %:        ",   str.position.plPct,     "     max:    ", str.position.plPctMax,  "      min:    ",    str.position.plPctMin,  NL);

   // 4 lines margin-top
   Comment(StringConcatenate(NL, NL, NL, NL, msg));
   if (__WHEREAMI__ == RF_INIT)
      WindowRedraw();

   return(error);
}


/**
 * Create and show a background box for the status display.
 *
 * @return bool - success status
 */
bool ShowStatus.Box() {
   if (!__CHART)
      return(false);

   int x[]={2, 120, 141}, y[]={59}, fontSize=90, cols=ArraySize(x), rows=ArraySize(y);
   color  bgColor = C'248,248,248';                                  // chart background color - LightSalmon
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

   return(!catch("ShowStatus.Box(1)"));
}


/**
 * Return a string presentation of the (modified) input parameters for logging.
 *
 * @return string
 */
string InputsToStr() {
   static string ss.Lots.StartSize;            string s.Lots.StartSize            = "Lots.StartSize="           + NumberToStr(Lots.StartSize, ".1+")            +"; ";
   static string ss.Lots.StartVola.Percent;    string s.Lots.StartVola.Percent    = "Lots.StartVola.Percent="   + Lots.StartVola.Percent                        +"; ";
   static string ss.Lots.Multiplier;           string s.Lots.Multiplier           = "Lots.Multiplier="          + NumberToStr(Lots.Multiplier, ".1+")           +"; ";

   static string ss.Start.Mode;                string s.Start.Mode                = "Start.Mode="               + DoubleQuoteStr(Start.Mode)                    +"; ";

   static string ss.TakeProfit.Pips;           string s.TakeProfit.Pips           = "TakeProfit.Pips="          + NumberToStr(TakeProfit.Pips, ".1+")           +"; ";
   static string ss.TakeProfit.Continue;       string s.TakeProfit.Continue       = "TakeProfit.Continue="      + BoolToStr(TakeProfit.Continue)                +"; ";

   static string ss.StopLoss.Percent;          string s.StopLoss.Percent          = "StopLoss.Percent="         + StopLoss.Percent                              +"; ";
   static string ss.StopLoss.Continue;         string s.StopLoss.Continue         = "StopLoss.Continue="        + BoolToStr(StopLoss.Continue)                  +"; ";

   static string ss.Grid.Min.Pips;             string s.Grid.Min.Pips             = "Grid.Min.Pips="            + NumberToStr(Grid.Min.Pips, ".1+")             +"; ";
   static string ss.Grid.Max.Pips;             string s.Grid.Max.Pips             = "Grid.Max.Pips="            + NumberToStr(Grid.Max.Pips, ".1+")             +"; ";
   static string ss.Grid.Contractable;         string s.Grid.Contractable         = "Grid.Contractable="        + BoolToStr(Grid.Contractable)                  +"; ";
   static string ss.Grid.Range.Periods;        string s.Grid.Range.Periods        = "Grid.Range.Periods="       + Grid.Range.Periods                            +"; ";
   static string ss.Grid.Range.Divider;        string s.Grid.Range.Divider        = "Grid.Range.Divider="       + Grid.Range.Divider                            +"; ";

   static string ss.Exit.Trail.Pips;           string s.Exit.Trail.Pips           = "Exit.Trail.Pips="          + NumberToStr(Exit.Trail.Pips, ".1+")           +"; ";
   static string ss.Exit.Trail.MinProfit.Pips; string s.Exit.Trail.MinProfit.Pips = "Exit.Trail.MinProfit.Pips="+ NumberToStr(Exit.Trail.MinProfit.Pips, ".1+") +"; ";

   string result;

   if (input.all == "") {
      // all input
      result = StringConcatenate("input: ",

                                 s.Lots.StartSize,
                                 s.Lots.StartVola.Percent,
                                 s.Lots.Multiplier,

                                 s.Start.Mode,

                                 s.TakeProfit.Pips,
                                 s.TakeProfit.Continue,

                                 s.StopLoss.Percent,
                                 s.StopLoss.Continue,

                                 s.Grid.Min.Pips,
                                 s.Grid.Max.Pips,
                                 s.Grid.Contractable,
                                 s.Grid.Range.Periods,
                                 s.Grid.Range.Divider,

                                 s.Exit.Trail.Pips,
                                 s.Exit.Trail.MinProfit.Pips);
   }
   else {
      // modified input
      result = StringConcatenate("modified input: ",

                                 ifString(s.Lots.StartSize            == ss.Lots.StartSize,            "", s.Lots.StartSize           ),
                                 ifString(s.Lots.StartVola.Percent    == ss.Lots.StartVola.Percent,    "", s.Lots.StartVola.Percent   ),
                                 ifString(s.Lots.Multiplier           == ss.Lots.Multiplier,           "", s.Lots.Multiplier          ),

                                 ifString(s.Start.Mode                == ss.Start.Mode,                "", s.Start.Mode               ),

                                 ifString(s.TakeProfit.Pips           == ss.TakeProfit.Pips,           "", s.TakeProfit.Pips          ),
                                 ifString(s.TakeProfit.Continue       == ss.TakeProfit.Continue,       "", s.TakeProfit.Continue      ),

                                 ifString(s.StopLoss.Percent          == ss.StopLoss.Percent,          "", s.StopLoss.Percent         ),
                                 ifString(s.StopLoss.Continue         == ss.StopLoss.Continue,         "", s.StopLoss.Continue        ),

                                 ifString(s.Grid.Min.Pips             == ss.Grid.Min.Pips,             "", s.Grid.Min.Pips            ),
                                 ifString(s.Grid.Max.Pips             == ss.Grid.Max.Pips,             "", s.Grid.Max.Pips            ),
                                 ifString(s.Grid.Contractable         == ss.Grid.Contractable,         "", s.Grid.Contractable        ),
                                 ifString(s.Grid.Range.Periods        == ss.Grid.Range.Periods,        "", s.Grid.Range.Periods       ),
                                 ifString(s.Grid.Range.Divider        == ss.Grid.Range.Divider,        "", s.Grid.Range.Divider       ),

                                 ifString(s.Exit.Trail.Pips           == ss.Exit.Trail.Pips,           "", s.Exit.Trail.Pips          ),
                                 ifString(s.Exit.Trail.MinProfit.Pips == ss.Exit.Trail.MinProfit.Pips, "", s.Exit.Trail.MinProfit.Pips));
   }

   ss.Lots.StartSize            = s.Lots.StartSize;
   ss.Lots.StartVola.Percent    = s.Lots.StartVola.Percent;
   ss.Lots.Multiplier           = s.Lots.Multiplier;

   ss.Start.Mode                = s.Start.Mode;

   ss.TakeProfit.Pips           = s.TakeProfit.Pips;
   ss.TakeProfit.Continue       = s.TakeProfit.Continue;

   ss.StopLoss.Percent          = s.StopLoss.Percent;
   ss.StopLoss.Continue         = s.StopLoss.Continue;

   ss.Grid.Min.Pips             = s.Grid.Min.Pips;
   ss.Grid.Max.Pips             = s.Grid.Max.Pips;
   ss.Grid.Contractable         = s.Grid.Contractable;
   ss.Grid.Range.Periods        = s.Grid.Range.Periods;
   ss.Grid.Range.Divider        = s.Grid.Range.Divider;

   ss.Exit.Trail.Pips           = s.Exit.Trail.Pips;
   ss.Exit.Trail.MinProfit.Pips = s.Exit.Trail.MinProfit.Pips;

   return(result);
}
