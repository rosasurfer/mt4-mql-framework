/**
 * AngryBird (aka Headless Chicken)
 *
 * A Martingale system with nearly random entry (like a headless chicken) and very low profit target. Always in the market.
 * Risk control via drawdown limit. Adding of positions on BarOpen only. The distance between consecutive trades adapts to
 * the past trading range. As volatility increases so does the probability of major losses.
 *
 * @see  https://www.mql5.com/en/code/12872
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
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern double Lots.StartSize               = 0;          // fixed lotsize or 0 (dynamically calculated using Lots.StartVola)
extern int    Lots.StartVola.Percent       = 30;         // expected weekly equity volatility, see CalculateLotSize()
extern double Lots.Multiplier              = 1.4;        // was 2

extern string Start.Direction              = "Long | Short | Auto*";

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


// grid management
int    grid.timeframe = PERIOD_M1;        // timeframe used for grid size calculation
int    grid.level;                        // current grid level: >= 0
double grid.lastSize;                     // grid size of the last opened position in pip
double grid.currentSize;                  // current grid size in pip
string grid.startDirection;

// position tracking
int    position.tickets   [];             // currently open orders
double position.lots      [];             // order lot sizes
double position.openPrices[];             // order open prices

int    position.level;                    // current position level: positive or negative
double position.totalSize;                // current total position lotsize
double position.totalPrice;               // current average position open price
double position.tpPrice;                  // current TakeProfit price
double position.slPrice;                  // current StopLoss price
double position.maxDrawdown;              // max. drawdown in account currency

bool   useTrailingStop;
double position.trailLimitPrice;          // current price limit to start profit trailing

// OrderSend() defaults
string os.name        = "AngryBird";
int    os.magicNumber = 2222;
double os.slippage    = 0.1;


/**
 * Init event handler called after the expert was manually loaded by the user via the input dialog. Also in Strategy Tester
 * with both VisualMode=On|Off.
 *
 * @return int - error status
 */
int onInit_User() {
   // look for a running sequence
   // if sequence found:
   // - ask whether or not to manage the running sequence
   // - if yes: validate input in the context of the running sequence
   //   - overwrite Lots.StartSize, Start.Direction
   //
   // if no sequence found:
   // - validate input as a new sequence


   // validate input parameters
   // Start.Direction
   string value, elems[];
   if (Explode(Start.Direction, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      value = elems[size-1];
   }
   else value = Start.Direction;
   value = StringToLower(StringTrim(value));

   if      (value=="l" || value=="long" )             Start.Direction = "long";
   else if (value=="s" || value=="short")             Start.Direction = "short";
   else if (value=="a" || value=="auto" || value=="") Start.Direction = "auto";
   else return(catch("onInit_User(1)  Invalid input parameter Start.Direction = "+ DoubleQuoteStr(Start.Direction), ERR_INVALID_INPUT_PARAMETER));

   if (Start.Direction == "auto") {
      if (!IsTesting()) {
         PlaySoundEx("Windows Notify.wav");
         int button = MessageBoxEx(__NAME__, ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you really want to start the chicken in headless mode?", MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK) return(SetLastError(ERR_CANCELLED_BY_USER));
      }
   }
   grid.startDirection = Start.Direction;


   // read open positions and data
   int    lastTicket, orders=OrdersTotal();
   double profit;
   string lastComment = "";

   for (int i=0; i < orders; i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber) {
         if (OrderType() == OP_BUY) {
            if (position.level < 0) return(catch("onInit_User(2)  found open long and short positions", ERR_ILLEGAL_STATE));
            position.level++;
         }
         else if (OrderType() == OP_SELL) {
            if (position.level > 0) return(catch("onInit_User(3)  found open long and short positions", ERR_ILLEGAL_STATE));
            position.level--;
         }
         else continue;

         ArrayPushInt   (position.tickets,    OrderTicket());
         ArrayPushDouble(position.lots,       OrderLots());
         ArrayPushDouble(position.openPrices, OrderOpenPrice());
         profit += OrderProfit();

         if (OrderTicket() > lastTicket) {
            lastTicket  = OrderTicket();
            lastComment = OrderComment();
         }
      }
   }
   if (StringLen(lastComment) > 0) lastComment   = StringRightFrom(lastComment, "-", 2);  // "AngryBird-10-2.0" => "2.0"
   if (StringLen(lastComment) > 0) grid.lastSize = StrToDouble(lastComment);

 //grid.timeframe   = Period();
   grid.level       = Abs(position.level);
   grid.currentSize = grid.lastSize;


   // update stop conditions
   double startEquity   = NormalizeDouble(AccountEquity() - AccountCredit() - profit, 2);
   position.maxDrawdown = NormalizeDouble(startEquity * StopLoss.Percent/100, 2);
   UpdateTotalPosition();

   if (grid.level > 0) {
      int direction            = Sign(position.level);
      position.trailLimitPrice = NormalizeDouble(position.totalPrice + direction * Exit.Trail.MinProfit.Pips*Pips, Digits);

      double maxDrawdownPips = position.maxDrawdown/PipValue(position.totalSize);
      position.slPrice       = NormalizeDouble(position.totalPrice - direction * maxDrawdownPips*Pips, Digits);
   }
   useTrailingStop = Exit.Trail.Pips > 0;

   return(catch("onInit_User(4)"));
}


/**
 * Init event handler called after the input parameters were changed via the input dialog.
 *
 * @return int - error status
 */
int onInit_Parameters() {
   return(catch("onInit_Parameters(1)  input parameter changes not yet supported", ERR_NOT_IMPLEMENTED));
}


/**
 * Init event handler called after the expert was loaded by a chart template. Also at terminal start. No input dialog.
 *
 * @return int - error status
 */
int onInit_Template() {
   // restore a stored runtime status
   return(onInit_User());
}


/**
 * Init event handler called after the expert was recompiled. No input dialog.
 *
 * @return int - error status
 */
int onInit_Recompile() {
   // restore a stored runtime status
   return(onInit_User());
}


/**
 * Init event handler called after the current chart symbol has changed. No input dialog.
 *
 * @return int - error status
 */
int onInit_SymbolChange() {
   // must never happen
   catch("onInit_SymbolChange(1)  unsupported symbol change", ERR_ILLEGAL_STATE);
   return(-1);                // hard stop
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // update gridsize for ShowStatus() on every tick
   if (!IsTesting())
      UpdateGridSize();

   // check exit conditions on every tick
   if (grid.level > 0) {
      CheckProfit();
      CheckDrawdown();

      if (useTrailingStop)
         TrailProfits();                                    // fails live because done on every tick

      if (__STATUS_OFF)
         return(last_error);
   }

   if (grid.startDirection == "auto") {
      // check entry conditions on BarOpen
      if (EventListener.BarOpen(grid.timeframe)) {
         if (!grid.level) {
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
 * @return double - price or NULL if the sequence was not yet started or an error occurred
 */
double UpdateGridSize() {
   double high = iHigh(NULL, grid.timeframe, iHighest(NULL, grid.timeframe, MODE_HIGH, Grid.Range.Periods, 1));
   double low  =  iLow(NULL, grid.timeframe,  iLowest(NULL, grid.timeframe, MODE_LOW,  Grid.Range.Periods, 1));

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("UpdateGridSize(1)", error));
      warn("UpdateGridSize(2)  ERS_HISTORY_UPDATE, reported "+ Grid.Range.Periods +"x"+ PeriodDescription(grid.timeframe) +" range: "+ DoubleToStr((high-low)/Pip, 1) +" pip => gridSize: "+ DoubleToStr((high-low)/Pip/Grid.Range.Divider, 1) +" pip", error);
   }

   double barRange = (high-low) / Pip;
   double realSize = barRange / Grid.Range.Divider;
   double adjusted = MathMax(realSize, Grid.Min.Pips);         // enforce lower limit
   if (Grid.Max.Pips > 0) {
          adjusted = MathMin(adjusted, Grid.Max.Pips);         // enforce upper limit
   }
   adjusted = NormalizeDouble(adjusted, 1);

   if (adjusted > grid.lastSize || Grid.Contractable)
      grid.currentSize = adjusted;

   if (grid.level > 0) {
      double lastPrice = position.openPrices[grid.level-1];
      double nextPrice = lastPrice - Sign(position.level) * grid.currentSize * Pips;
      return(NormalizeDouble(nextPrice, Digits));
   }
   return(NULL);
}


/**
 * Calculate the lot size to use for the specified sequence level.
 *
 * @param  int level
 *
 * @return double - lotsize or NULL in case of an error
 */
double CalculateLotsize(int level) {
   if (level < 1) return(!catch("CalculateLotsize(1)  invalid parameter level = "+ level +" (not positive)", ERR_INVALID_PARAMETER));

   // if Lots.StartSize is not set calculate it using Lots.StartVola
   if (!Lots.StartSize) {
      // unleveraged lotsize
      double tickSize        = MarketInfo(Symbol(), MODE_TICKSIZE);  if (!tickSize)  return(!catch("CalculateLotsize(2)  invalid MarketInfo(MODE_TICKSIZE) = 0", ERR_RUNTIME_ERROR));
      double tickValue       = MarketInfo(Symbol(), MODE_TICKVALUE); if (!tickValue) return(!catch("CalculateLotsize(3)  invalid MarketInfo(MODE_TICKVALUE) = 0", ERR_RUNTIME_ERROR));
      double lotValue        = Bid/tickSize * tickValue;                // value of a full lot in account currency
      double unleveragedLots = AccountBalance() / lotValue;             // unleveraged lotsize (leverage 1:1)
      if (unleveragedLots < 0) unleveragedLots = 0;

      // expected weekly range: maximum of ATR(14xW1), previous TrueRange(W1) and current TrueRange(W1)
      double a = @ATR(NULL, PERIOD_W1, 14, 1);                          // ATR(14xW1)
         if (!a) return(_NULL(debug("CalculateLotsize(0.1)  "+  ErrorToStr(last_error) +" at iATR(W1, 14, 1)", last_error)));
      double b = @ATR(NULL, PERIOD_W1,  1, 1);                          // previous TrueRange(W1)
         if (!b) return(_NULL(debug("CalculateLotsize(0.2)  "+  ErrorToStr(last_error) +" at iATR(W1, 1, 1)", last_error)));
      double c = @ATR(NULL, PERIOD_W1,  1, 0);                          // current TrueRange(W1)
         if (!c) return(_NULL(debug("CalculateLotsize(0.3)  "+  ErrorToStr(last_error) +" at iATR(W1, 1, 0)", last_error)));
      double expectedRange    = MathMax(a, MathMax(b, c));
      double expectedRangePct = expectedRange/Close[0] * 100;

      // leveraged lotsize = Lots.StartSize
      double leverage = Lots.StartVola.Percent / expectedRangePct;      // leverage weekly range vola to user-defined vola
      Lots.StartSize  = NormalizeLots(leverage * unleveragedLots);
      if (!Lots.StartSize) return(!catch("CalculateLotsize(4)  The calculated start lot size of "+ NumberToStr(Lots.StartSize, ".+") +" is too small (MODE_MINLOT = "+ NumberToStr(MarketInfo(Symbol(), MODE_MINLOT), ".+") +")", ERR_RUNTIME_ERROR));
   }

   // Lots.StartSize is always set
   double calculated = Lots.StartSize * MathPow(Lots.Multiplier, level-1);
   double used       = NormalizeLots(calculated);
   if (!used) return(!catch("CalculateLotsize(5)  The resulting lot size "+ NumberToStr(calculated, ".+") +" for level "+ level +" is too small (MODE_MINLOT = "+ NumberToStr(MarketInfo(Symbol(), MODE_MINLOT), ".+") +")", ERR_RUNTIME_ERROR));

   double ratio = used / calculated;
   if (ratio < 1) ratio = 1/ratio;
   if (ratio > 1.15) {                                                  // warn if the resulting lotsize deviates > 15% from the calculation
      static bool lotsWarned = false;
      if (!lotsWarned) lotsWarned = _true(warn("CalculateLotsize(6)  The reslting lot size significantly deviates from the calculated one: "+ NumberToStr(used, ".+") +" instead of "+ NumberToStr(calculated, ".+")));
   }
   return(used);
}


/**
 * Open a position at the next sequence level.
 *
 * @param  int type - order operation type: OP_BUY | OP_SELL
 *
 * @return bool - success status
 */
bool OpenPosition(int type) {
   if (InitReason() != IR_USER) {
      if (Tick <= 1) if (!ConfirmFirstTickTrade("OpenPosition()", "Do you really want to submit a Market "+ OrderTypeDescription(type) +" order now?"))
         return(!SetLastError(ERR_CANCELLED_BY_USER));
   }
   string   symbol      = Symbol();
   double   price       = NULL;
   double   lots        = CalculateLotsize(grid.level+1); if (!lots) return(false);
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   string   comment     = os.name +"-"+ (grid.level+1) + ifString(!grid.level, "", "-"+ DoubleToStr(grid.currentSize, 1));
   datetime expires     = NULL;
   color    markerColor = ifInt(type==OP_BUY, Blue, Red);
   int      oeFlags     = NULL;
   int      oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);

   int ticket = OrderSendEx(symbol, type, lots, price, os.slippage, stopLoss, takeProfit, comment, os.magicNumber, expires, markerColor, oeFlags, oe);
   if (IsEmpty(ticket)) return(false);

   // update levels and ticket data
   grid.lastSize = ifDouble(!grid.level, 0, grid.currentSize);
   grid.level++;                                               // update grid.level
   if (type == OP_BUY) position.level++;                       // update position.level
   else                position.level--;
   ArrayPushInt   (position.tickets,    ticket);               // store ticket data
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
   position.trailLimitPrice = NormalizeDouble(avgPrice + direction * Exit.Trail.MinProfit.Pips*Pips, Digits);

   double maxDrawdownPips = position.maxDrawdown/PipValue(position.totalSize);
   position.slPrice       = NormalizeDouble(avgPrice - direction * maxDrawdownPips*Pips, Digits);

   //debug("OpenPosition(3)  maxDrawdown="+ DoubleToStr(position.maxDrawdown, 2) +"  lots="+ NumberToStr(position.totalLots, ".1+") +"  maxDrawdownPips="+ DoubleToStr(maxDrawdownPips, 1));
   return(!catch("OpenPosition(4)"));
}


/**
 *
 */
void ClosePositions() {
   if (!grid.level)
      return;

   if (Tick <= 1) if (!ConfirmFirstTickTrade("ClosePositions()", "Do you really want to close all open positions now?"))
      return(SetLastError(ERR_CANCELLED_BY_USER));

   int oes[][ORDER_EXECUTION.intSize];
   ArrayResize(oes, grid.level);
   InitializeByteBuffer(oes, ORDER_EXECUTION.size);

   if (!OrderMultiClose(position.tickets, os.slippage, Orange, NULL, oes))
      return;

   grid.level       = 0;
   grid.currentSize = 0;

   ArrayResize(position.tickets,    0);
   ArrayResize(position.lots,       0);
   ArrayResize(position.openPrices, 0);

   position.level      = 0;
   position.totalSize  = 0;
   position.totalPrice = 0;

   if (!StopLoss.Continue) {
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = ERR_CANCELLED_BY_USER;
   }
}


/**
 *
 */
void CheckProfit() {
   if (!grid.level)
      return;

   OrderSelect(position.tickets[0], SELECT_BY_TICKET);

   if (OrderCloseTime() && 1) {
      grid.level       = 0;
      grid.currentSize = 0;

      ArrayResize(position.tickets,    0);
      ArrayResize(position.lots,       0);
      ArrayResize(position.openPrices, 0);

      position.level      = 0;
      position.totalSize  = 0;
      position.totalPrice = 0;

      if (!TakeProfit.Continue) {
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = ERR_CANCELLED_BY_USER;
      }
   }
}


/**
 * Enforce the drawdown limit.
 */
void CheckDrawdown() {
   if (!grid.level)
      return;

   if (position.level > 0) {                       // make sure the limit is not triggered by spread widening
      if (Ask > position.slPrice)
         return;
   }
   else {
      if (Bid < position.slPrice)
         return;
   }
   debug("CheckDrawdown(1)  Drawdown limit of "+ StopLoss.Percent +"% triggered, closing all trades...");
   ClosePositions();
}


/**
 * Trail stops of profitable trades. Will fail in real life because it trails every order on every tick.
 *
 * @return bool - function success status; not, if orders have beeen trailed on the current tick
 */
void TrailProfits() {
   if (!grid.level)
      return(true);

   if (position.level > 0) {
      if (Bid < position.trailLimitPrice) return(true);
      double stop = Bid - Exit.Trail.Pips*Pips;
   }
   else if (position.level < 0) {
      if (Ask > position.trailLimitPrice) return(true);
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
      else {
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
   double sumPrice, sumLots;

   for (int i=0; i < grid.level; i++) {
      sumPrice += position.lots[i] * position.openPrices[i];
      sumLots  += position.lots[i];
   }

   if (!grid.level) {
      position.totalSize  = 0;
      position.totalPrice = 0;
   }
   else {
      position.totalSize  = NormalizeDouble(sumLots, 2);
      position.totalPrice = sumPrice/sumLots;
   }
   return(position.totalPrice);
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   int uninitReason = UninitializeReason();

   // clean-up created chart objects
   if (uninitReason!=UR_PARAMETERS && uninitReason!=UR_CHARTCHANGE) {
      if (!IsTesting())
         DeleteRegisteredObjects(NULL);
   }

   // store runtime status
   if (uninitReason==UR_RECOMPILE || uninitReason==UR_CHARTCLOSE || uninitReason==UR_CLOSE) {
      if (!IsTesting())
         StoreRuntimeStatus();
   }
   return(last_error);
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
   static bool done=false, confirmed=false;
   if (!done) {
      if (Tick > 1 || IsTesting()) {
         confirmed = true;
      }
      else {
         PlaySoundEx("Windows Notify.wav");
         int button = MessageBoxEx(__NAME__ + ifString(!StringLen(location), "", " - "+ location), ifString(IsDemoFix(), "", "- Real Account -\n\n") + message, MB_ICONQUESTION|MB_OKCANCEL);
         if (button == IDOK) confirmed = true;

         // refresh prices as waiting for user input will delay execution by multiple ticks
         RefreshRates();
      }
      done = true;
   }
   return(confirmed);
}


/**
 * Save input parameters and runtime status in the chart to be able to continue a sequence after reloading the profile,
 * terminal re-start or recompilation.
 *
 * Stored runtime values:
 *
 *  bool   __STATUS_INVALID_INPUT;
 *  bool   __STATUS_OFF;
 *  int    __STATUS_OFF.reason;
 *  double grid.lastSize;
 *  double position.maxDrawdown;
 *
 * @return bool - success status
 */
int StoreRuntimeStatus() {
   // (1) input parameters
   string label = __NAME__ +".input.Lots.StartSize";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, DoubleToStr(Lots.StartSize, 2), 1);             // (string) double

   label = __NAME__ +".input.Lots.Multiplier";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, DoubleToStr(Lots.Multiplier, 8), 1);            // (string) double

   label = __NAME__ + ".input.Start.Direction";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ Start.Direction, 1);                        // string

   label = __NAME__ +".input.TakeProfit.Pips";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, DoubleToStr(TakeProfit.Pips, 1), 1);            // (string) double

   label = __NAME__ +".input.TakeProfit.Continue";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ TakeProfit.Continue, 1);                    // (string)(int) bool

   label = __NAME__ +".input.StopLoss.Percent";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ StopLoss.Percent, 1);                       // (string) int

   label = __NAME__ +".input.StopLoss.Continue";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ StopLoss.Continue, 1);                      // (string)(int) bool

   label = __NAME__ +".input.Grid.Min.Pips";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, DoubleToStr(Grid.Min.Pips, 1), 1);              // (string) double

   label = __NAME__ +".input.Grid.Max.Pips";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, DoubleToStr(Grid.Max.Pips, 1), 1);              // (string) double

   label = __NAME__ +".input.Grid.Contractable";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ Grid.Contractable, 1);                      // (string)(int) bool

   label = __NAME__ +".input.Grid.Range.Periods";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ Grid.Range.Periods, 1);                     // (string) int

   label = __NAME__ +".input.Grid.Range.Divider";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ Grid.Range.Divider, 1);                     // (string) int

   label = __NAME__ +".input.Exit.Trail.Pips";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, DoubleToStr(Exit.Trail.Pips, 1), 1);            // (string) double

   label = __NAME__ +".input.Exit.Trail.MinProfit.Pips";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, DoubleToStr(Exit.Trail.MinProfit.Pips, 1), 1);  // (string) double


   // (2 runtime status
   label = __NAME__ + ".runtime.__STATUS_INVALID_INPUT";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ __STATUS_INVALID_INPUT, 1);                 // (string)(int) bool

   label = __NAME__ +".runtime.__STATUS_OFF";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ __STATUS_OFF, 1);                           // (string)(int) bool

   label = __NAME__ +".runtime.__STATUS_OFF.reason";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ __STATUS_OFF.reason, 1);                    // (string) int

   label = __NAME__ +".runtime.grid.lastSize";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, DoubleToStr(grid.lastSize, 1), 1);              // (string) double

   label = __NAME__ +".runtime.position.maxDrawdown";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, DoubleToStr(position.maxDrawdown, 2), 1);       // (string) double

   return(!catch("StoreRuntimeStatus(1)"));
}


/**
 * Show the current runtime status on screen.
 *
 * @param  int error - user-defined error to display (if any)
 *
 * @return int - the same error
 */
int ShowStatus(int error=NO_ERROR) {
   if (!__CHART)
      return(error);

   static bool statusBox; if (!statusBox)
      statusBox = ShowStatus.Box();

   string str.error;
   if (__STATUS_OFF) str.error = StringConcatenate(" switched OFF  [", ErrorDescription(__STATUS_OFF.reason), "]");

   string str.profit = "-";
   if      (position.level > 0) str.profit = DoubleToStr((Bid - position.totalPrice)/Pip, 1);
   else if (position.level < 0) str.profit = DoubleToStr((position.totalPrice - Ask)/Pip, 1);

   string msg = StringConcatenate(" ", __NAME__, str.error,                                                                                                                                                  NL,
                                  " --------------",                                                                                                                                                         NL,
                                  " Grid level:   ",  position.level,                   "           Size:   ", DoubleToStr(grid.currentSize, 1), " pip", "       Limit:     ... pip",                        NL,
                                  " StartLots:    ",  NumberToStr(Lots.StartSize, ".1+"),  "        Vola:   ", Lots.StartVola.Percent, "%",                                                                  NL,
                                  " TP:            ", DoubleToStr(TakeProfit.Pips, 1), " pip", "    Stop:   ", DoubleToStr(StopLoss.Percent, 0), "%", "          SL:  ",  NumberToStr(0, SubPipPriceFormat), NL,
                                  " PL:            ", str.profit,                          "        max:    ... upip",                                   "       min:     ... upip",                         NL,
                                  "");

   // 3 lines margin-top
   Comment(StringConcatenate(NL, NL, NL, msg));
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

   int x[]={2, 120, 141}, y[]={46}, fontSize=90, cols=ArraySize(x), rows=ArraySize(y);
   color  bgColor = C'248,248,248';                                  // chart background color - LightSalmon
   string label;

   for (int i, row=0; row < rows; row++) {
      for (int col=0; col < cols; col++, i++) {
         label = StringConcatenate(__NAME__, ".statusbox."+ (i+1));
         if (ObjectFind(label) != 0) {
            if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))
               return(!catch("ShowStatus.Box(1)"));
            ObjectRegister(label);
         }
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet    (label, OBJPROP_XDISTANCE, x[col]);
         ObjectSet    (label, OBJPROP_YDISTANCE, y[row]);
         ObjectSetText(label, "g", fontSize, "Webdings", bgColor);   // that's a rectangle
      }
   }

   return(!catch("ShowStatus.Box(2)"));
}


/**
 * Return a string presentation of the input parameters (for logging).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()  inputs: ",

                            "Lots.StartSize=",            NumberToStr(Lots.StartSize, ".1+")           , "; ",
                            "Lots.StartVola.Percent=",    Lots.StartVola.Percent                       , "; ",
                            "Lots.Multiplier=",           NumberToStr(Lots.Multiplier, ".1+")          , "; ",

                            "Start.Direction=",           DoubleQuoteStr(Start.Direction)              , "; ",

                            "TakeProfit.Pips=",           NumberToStr(TakeProfit.Pips, ".1+")          , "; ",
                            "TakeProfit.Continue=",       BoolToStr(TakeProfit.Continue)               , "; ",

                            "StopLoss.Percent=",          StopLoss.Percent                             , "; ",
                            "StopLoss.Continue=",         BoolToStr(StopLoss.Continue)                 , "; ",

                            "Grid.Min.Pips=",             NumberToStr(Grid.Min.Pips, ".1+")            , "; ",
                            "Grid.Max.Pips=",             NumberToStr(Grid.Max.Pips, ".1+")            , "; ",
                            "Grid.Contractable=",         BoolToStr(Grid.Contractable)                 , "; ",
                            "Grid.Range.Periods=",        Grid.Range.Periods                           , "; ",
                            "Grid.Range.Divider=",        Grid.Range.Divider                           , "; ",

                            "Exit.Trail.Pips=",           NumberToStr(Exit.Trail.Pips, ".1+")          , "; ",
                            "Exit.Trail.MinProfit.Pips=", NumberToStr(Exit.Trail.MinProfit.Pips, ".1+"), "; ")
   );
}
