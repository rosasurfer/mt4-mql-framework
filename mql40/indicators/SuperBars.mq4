/**
 * SuperBars
 *
 * Draws rectangles of higher timeframe bars and/or trading sessions in the chart. The active timeframe/session can be changed
 * by executing the scripts "SuperBars.TimeframeUp" and "SuperBars.TimeframeDown".
 *
 * With input parameter "AutoConfiguration" enabled inputs found in the framework configuration override manual inputs.
 * Additional framewrk configuration settings without manual inputs:
 *
 * [SuperBars]
 *  Legend.Corner               = {int}      ; CORNER_TOP_LEFT* | CORNER_TOP_RIGHT | CORNER_BOTTOM_LEFT | CORNER_BOTTOM_RIGHT
 *  Legend.xDistance            = {int}      ; offset in pixels
 *  Legend.yDistance            = {int}      ; offset in pixels
 *  Legend.FontName             = {string}   ; font name
 *  Legend.FontSize             = {int}      ; font size
 *  Legend.FontColor            = {color}    ; font color (web color name, integer or RGB triplet)
 *  UnchangedBars.Threshold.Pct = {double}   ; max. change of a bar in percent to be colored "unchanged"
 *  MaxBars.H1                  = {int}      ; max. number of H1 super bars to draw (default: all available)
 *  ErrorSound                  = {string}   ; notification sound when no higher/lower timeframe is available (default: none)
 *
 * @see  https://www.forexfactory.com/thread/1078323-superbars-higher-timeframe-bars-with-cme-session-support
 *
 *
 * TODO:
 *  - replace input "WeekendSessions.Symbols" by actual symbol properties
 *  - implement more super timeframes and rewrite configuration of max. bars
 *  - SuperBar close markers in variable period charts (e.g. range bars) are incorrect
 *  - ETH/RTH separation for Frankfurt session
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern color  UpBars.Color            = PaleGreen;       // bullish bars
extern color  DownBars.Color          = Pink;            // bearish bars
extern color  UnchangedBars.Color     = Lavender;        // unchanged bars
extern bool   FillBars                = true;            //
extern color  CloseMarker.Color       = Gray;            // bar close marker
extern color  US.ETH.Color            = LemonChiffon;    // ETH sessions
extern string US.ETH.Symbols          = "";              // comma-separated list of symbols with US ETH sessions ("*": all symbols)
extern string US.RTH.Symbols          = "";              // comma-separated list of symbols with US RTH sessions ("*": all symbols)
extern string WeekendSessions.Symbols = "";              // comma-separated list of symbols with weekend sessions

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/HandleCommands.mqh>
#include <rsf/functions/iBarShiftNext.mqh>
#include <rsf/functions/iBarShiftPrevious.mqh>
#include <rsf/functions/iChangedBars.mqh>
#include <rsf/functions/iPreviousPeriod.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/win32api.mqh>

#define BUFFER_HIDDEN_BODY_A  0           // indicator buffer ids
#define BUFFER_HIDDEN_BODY_B  1
#define BUFFER_HIDDEN_WICK_A  2
#define BUFFER_HIDDEN_WICK_B  3

#property indicator_chart_window
#property indicator_buffers 4

#property indicator_color1  CLR_NONE
#property indicator_color2  CLR_NONE
#property indicator_color3  CLR_NONE
#property indicator_color4  CLR_NONE

double   hiddenBodyA[];                   // indicator buffers
double   hiddenBodyB[];
double   hiddenWickA[];
double   hiddenWickB[];

int      superTimeframe;                  // the currently active super bar period
double   unchangedTreshold = 0.05;        // max. price change in % for a super bar to be colored "unchanged"
bool     usEthEnabled;                    // whether US ETH sessions are enabled
bool     usRthEnabled;                    // whether US RTH sessions are enabled
bool     weekendSessionsEnabled;          // whether weekend sessions are enabled
datetime serverTime;                      // most recent server time
int      maxBarsH1;                       // max. number of H1 super bars to draw (performance)

string   legendLabel      = "";
int      legendCorner     = CORNER_TOP_LEFT;
int      legend_xDistance = 300;
int      legend_yDistance = 3;
string   legendFontName   = "";           // empty: OS menu font/size => "MS Sans Serif",8
int      legendFontSize   = 8;            //
color    legendFontColor  = Black;

string   errorSound = "";                 // sound when timeframe cycling hits min/max (default: none)

#define PERIOD_D1_US_RTH 1438             // PERIOD_D1 - 2 (only the US RTH session is drawn)
#define PERIOD_D1_US_ETH 1439             // PERIOD_D1 - 1 (D1 + a separate US ETH session are drawn)

#define STF_UP    1                       // super timeframe cycling directions
#define STF_DOWN -1                       //


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // colors: after deserialization the terminal may turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (UpBars.Color        == 0xFF000000) UpBars.Color        = CLR_NONE;
   if (DownBars.Color      == 0xFF000000) DownBars.Color      = CLR_NONE;
   if (UnchangedBars.Color == 0xFF000000) UnchangedBars.Color = CLR_NONE;
   if (CloseMarker.Color   == 0xFF000000) CloseMarker.Color   = CLR_NONE;
   if (US.ETH.Color        == 0xFF000000) US.ETH.Color        = CLR_NONE;
   if (AutoConfiguration) {
      UpBars.Color        = GetConfigColor(indicator, "UpBars.Color",        UpBars.Color);
      DownBars.Color      = GetConfigColor(indicator, "DownBars.Color",      DownBars.Color);
      UnchangedBars.Color = GetConfigColor(indicator, "UnchangedBars.Color", UnchangedBars.Color);
      CloseMarker.Color   = GetConfigColor(indicator, "CloseMarker.Color",   CloseMarker.Color);
      US.ETH.Color        = GetConfigColor(indicator, "US.ETH.Color",        US.ETH.Color);
   }
   // US.ETH.Symbols
   if (AutoConfiguration) US.ETH.Symbols = GetConfigString(indicator, "US.ETH.Symbols", US.ETH.Symbols);
   usEthEnabled = false;
   string sValues[], sValue = StrToLower(US.ETH.Symbols), symbol = StrToLower(Symbol()), stdSymbol = StrToLower(StdSymbol());
   int size = Explode(sValue, ",", sValues, NULL);
   for (int i=0; i < size; i++) {
      sValues[i] = StrTrim(sValues[i]);
      if (sValues[i] == "*") {
         usEthEnabled = true;
         break;
      }
   }
   if (!usEthEnabled) usEthEnabled = (StringInArray(sValues, symbol) || StringInArray(sValues, stdSymbol));
   // US.RTH.Symbols
   if (AutoConfiguration) US.RTH.Symbols = GetConfigString(indicator, "US.RTH.Symbols", US.RTH.Symbols);
   usRthEnabled = false;
   sValue = StrToLower(US.RTH.Symbols);
   size = Explode(sValue, ",", sValues, NULL);
   for (i=0; i < size; i++) {
      sValues[i] = StrTrim(sValues[i]);
      if (sValues[i] == "*") {
         usRthEnabled = true;
         break;
      }
   }
   if (!usRthEnabled) usRthEnabled = (StringInArray(sValues, symbol) || StringInArray(sValues, stdSymbol));
   // WeekendSessions.Symbols
   if (AutoConfiguration) WeekendSessions.Symbols = GetConfigString(indicator, "WeekendSessions.Symbols", WeekendSessions.Symbols);
   sValue = StrToLower(WeekendSessions.Symbols);
   size = Explode(sValue, ",", sValues, NULL);
   for (i=0; i < size; i++) {
      sValues[i] = StrTrim(sValues[i]);
   }
   weekendSessionsEnabled = (StringInArray(sValues, symbol) || StringInArray(sValues, stdSymbol));

   // read additional external configuration
   double dValue; int iValue;
   dValue          = GetConfigDouble(indicator, "UnchangedBars.Threshold.Pct");     unchangedTreshold = MathAbs(ifDouble(!dValue, unchangedTreshold, dValue));
   iValue          = GetConfigInt   (indicator, "MaxBars.H1",       -1);            maxBarsH1         = ifInt(iValue > 0, iValue, NULL);
   iValue          = GetConfigInt   (indicator, "Legend.Corner",    -1);            legendCorner      = ifInt(iValue >= CORNER_TOP_LEFT && iValue <= CORNER_BOTTOM_RIGHT, iValue, legendCorner);
   iValue          = GetConfigInt   (indicator, "Legend.xDistance", -1);            legend_xDistance  = ifInt(iValue >= 0, iValue, legend_xDistance);
   iValue          = GetConfigInt   (indicator, "Legend.yDistance", -1);            legend_yDistance  = ifInt(iValue >= 0, iValue, legend_yDistance);
   legendFontName  = GetConfigString(indicator, "Legend.FontName", legendFontName);
   iValue          = GetConfigInt   (indicator, "Legend.FontSize");                 legendFontSize    = ifInt(iValue > 0, iValue, legendFontSize);
   legendFontColor = GetConfigColor (indicator, "Legend.FontColor", legendFontColor);
   errorSound      = GetConfigString(indicator, "ErrorSound", errorSound);

   // reset the command handler
   if (__isChart) GetChartCommand("", sValues);
   RestoreStatus();

   ValidateSuperTimeframe();

   // buffer management and display options
   SetIndicatorOptions();
   legendLabel = CreateStatusLabel();

   return(catch("onInit(1)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   if (!StoreStatus()) {                                 // store runtime status in all deinit scenarios
      return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!__isChart || __isSuperContext) return(last_error);

   serverTime = TimeServer("onTick(1)", true);
   if (!serverTime) return(last_error);

   if (!HandleCommands()) return(last_error);            // process incoming commands

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(hiddenBodyA, 0);
      ArrayInitialize(hiddenBodyB, 0);
      ArrayInitialize(hiddenWickA, 0);
      ArrayInitialize(hiddenWickB, 0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(hiddenBodyA, Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(hiddenBodyB, Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(hiddenWickA, Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(hiddenWickB, Bars, ShiftedBars, 0);
   }

   UpdateSuperBars();                                 // update superbars
   return(last_error);
}


/**
 * Process an incoming command.
 *
 * @param  string cmd    - command name
 * @param  string params - command parameters
 * @param  int    keys   - flags of pressed modifier keys
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params, int keys) {
   if (cmd == "timeframe") {
      if (params == "up")   return(SwitchSuperTimeframe(STF_UP));
      if (params == "down") return(SwitchSuperTimeframe(STF_DOWN));
   }
   return(!logNotice("onCommand(1)  unsupported command: "+ DoubleQuoteStr(cmd +":"+ params +":"+ keys)));
}


/**
 * Change the currently active super bars timeframe.
 *
 * @param  int direction - direction to change: STF_UP | STF_DOWN
 *
 * @return bool - success status
 */
bool SwitchSuperTimeframe(int direction) {
   if (direction == STF_DOWN) {
      switch (superTimeframe) {
         case  INT_MIN:
            if (errorSound != "") PlaySoundEx(errorSound);  break;   // we hit the wall downwards

         case  PERIOD_H1:
         case -PERIOD_H1:        superTimeframe =  INT_MIN;    break;

         case  PERIOD_D1_US_RTH: superTimeframe =  PERIOD_H1;  break;
         case -PERIOD_D1_US_RTH: superTimeframe = -PERIOD_H1;  break;

         case  PERIOD_D1_US_ETH:
         case -PERIOD_D1_US_ETH:
            superTimeframe = Sign(superTimeframe) * ifInt(usRthEnabled, PERIOD_D1_US_RTH, PERIOD_H1);
            break;

         case  PERIOD_D1:
         case -PERIOD_D1:
            superTimeframe = Sign(superTimeframe) * ifInt(usEthEnabled, PERIOD_D1_US_ETH, ifInt(usRthEnabled, PERIOD_D1_US_RTH, PERIOD_H1));
            break;

         case  PERIOD_W1:        superTimeframe =  PERIOD_D1;  break;
         case -PERIOD_W1:        superTimeframe = -PERIOD_D1;  break;

         case  PERIOD_MN1:       superTimeframe =  PERIOD_W1;  break;
         case -PERIOD_MN1:       superTimeframe = -PERIOD_W1;  break;

         case  PERIOD_Q1:        superTimeframe =  PERIOD_MN1; break;
         case -PERIOD_Q1:        superTimeframe = -PERIOD_MN1; break;

         case  INT_MAX:          superTimeframe =  PERIOD_Q1;  break;
      }
   }
   else if (direction == STF_UP) {
      switch (superTimeframe) {
         case  INT_MIN:          superTimeframe =  PERIOD_H1;  break;

         case  PERIOD_H1:
         case -PERIOD_H1:
            superTimeframe = Sign(superTimeframe) * ifInt(usRthEnabled, PERIOD_D1_US_RTH, ifInt(usEthEnabled, PERIOD_D1_US_ETH, PERIOD_D1));
            break;

         case  PERIOD_D1_US_RTH:
         case -PERIOD_D1_US_RTH:
            superTimeframe = Sign(superTimeframe) * ifInt(usEthEnabled, PERIOD_D1_US_ETH, PERIOD_D1);
            break;

         case  PERIOD_D1_US_ETH: superTimeframe =  PERIOD_D1;  break;
         case -PERIOD_D1_US_ETH: superTimeframe = -PERIOD_D1;  break;

         case  PERIOD_D1:        superTimeframe =  PERIOD_W1;  break;
         case -PERIOD_D1:        superTimeframe = -PERIOD_W1;  break;

         case  PERIOD_W1:        superTimeframe =  PERIOD_MN1; break;
         case -PERIOD_W1:        superTimeframe = -PERIOD_MN1; break;

         case  PERIOD_MN1:       superTimeframe =  PERIOD_Q1;  break;
         case -PERIOD_MN1:       superTimeframe = -PERIOD_Q1;  break;

         case  PERIOD_Q1:        superTimeframe =  INT_MAX;    break;

         case  INT_MAX:
            if (errorSound != "") PlaySoundEx(errorSound);  break;   // we hit the wall upwards
      }
   }
   else return(!catch("SwitchSuperTimeframe(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   debug("SwitchSuperTimeframe(0.1)  superTF="+ SuperTimeframeToStr(superTimeframe));

   return(ValidateSuperTimeframe());                                 // validate the new setting
}


/**
 * Makes sure the selected super bar timeframe can be displayed on the current chart, otherwise temporarily disable the
 * selection (e.g. super bar timeframe H1 can't be displayed on an H4 chart).
 *
 * If no super bar timeframe is selected, it is initialized with a suitable default.
 *
 * @return bool - success status
 */
bool ValidateSuperTimeframe() {
   int currentTimeframe = Period();

   // handle offline charts with custom bar periods: we can't rely on Period()
   if (IsCustomTimeframe(currentTimeframe)) {
      int customTimeframe = MathRound(MathMin(Time[0]-Time[1], Time[1]-Time[2])/MINUTES);
      currentTimeframe = intOr(customTimeframe, PERIOD_M1);
   }

   switch (superTimeframe) {
      // off
      case  INT_MIN:
      case  INT_MAX: break;

      // positive value = active: deactivated if display on the current chart doesn't make sense
      case  PERIOD_H1:  if (currentTimeframe > PERIOD_M15)  superTimeframe *= -1; break;
      case  PERIOD_D1_US_RTH:
         if (usRthEnabled) {
            if (currentTimeframe > PERIOD_M30) superTimeframe *= -1; break;
         }
         superTimeframe = PERIOD_D1_US_ETH;                                     // fall-through
      case  PERIOD_D1_US_ETH:
         if (usEthEnabled) {
            if (currentTimeframe > PERIOD_M30) superTimeframe *= -1; break;
         }
         superTimeframe = PERIOD_D1;                                            // fall-through
      case  PERIOD_D1:  if (currentTimeframe > PERIOD_H4) superTimeframe *= -1; break;
      case  PERIOD_W1:  if (currentTimeframe > PERIOD_D1) superTimeframe *= -1; break;
      case  PERIOD_MN1: if (currentTimeframe > PERIOD_D1) superTimeframe *= -1; break;
      case  PERIOD_Q1:  if (currentTimeframe > PERIOD_W1) superTimeframe *= -1; break;

      // negative value = inactive: activated if display on the current chart makes sense
      case -PERIOD_H1:  if (currentTimeframe <= PERIOD_M15) superTimeframe *= -1; break;
      case -PERIOD_D1_US_RTH:
         if (usRthEnabled) {
            if (currentTimeframe < PERIOD_H1) superTimeframe *= -1; break;
         }
         superTimeframe = -PERIOD_D1_US_ETH;                                     // fall-through
      case -PERIOD_D1_US_ETH:
         if (usEthEnabled) {
            if (currentTimeframe < PERIOD_H1) superTimeframe *= -1; break;
         }
         superTimeframe = -PERIOD_H1;                                            // fall-through
      case -PERIOD_D1:  if (currentTimeframe <= PERIOD_H4) superTimeframe *= -1; break;
      case -PERIOD_W1:  if (currentTimeframe <= PERIOD_D1) superTimeframe *= -1; break;
      case -PERIOD_MN1: if (currentTimeframe <= PERIOD_D1) superTimeframe *= -1; break;
      case -PERIOD_Q1:  if (currentTimeframe <= PERIOD_W1) superTimeframe *= -1; break;

      // not initialized or invalid value: reset to a suitable default
      default:
         if      (currentTimeframe <= PERIOD_M5)  superTimeframe =  PERIOD_H1;
         else if (currentTimeframe <= PERIOD_H1)  superTimeframe =  PERIOD_D1;
         else if (currentTimeframe <= PERIOD_H4)  superTimeframe =  PERIOD_W1;
         else if (currentTimeframe <= PERIOD_D1)  superTimeframe =  PERIOD_MN1;
         else if (currentTimeframe <= PERIOD_MN1) superTimeframe = -PERIOD_MN1;
   }
   return(true);
}


/**
 * Update the displayed super bars.
 *
 * @return bool - success status
 */
bool UpdateSuperBars() {
   // on change of the super timeframe delete super bars of the previously active timeframe
   static int lastSuperTimeframe;
   bool isTimeframeChange = (superTimeframe != lastSuperTimeframe);  // for simplicity interpret the first comparison (lastSuperTimeframe==0) as a change, too

   if (isTimeframeChange) {
      if (lastSuperTimeframe >=PERIOD_M1 && lastSuperTimeframe <= PERIOD_Q1) {
         DeleteRegisteredObjects();                                  // in all other cases previous SuperBars have already been deleted
         legendLabel = CreateStatusLabel();
      }
      UpdateDescription();
   }

   // define the amount of superbars to draw
   int maxBars = INT_MAX;
   switch (superTimeframe) {
      case  INT_MIN:                                                 // inactive
      case  INT_MAX:                                                 // ...
      case -PERIOD_H1:                                               // ...
      case -PERIOD_D1_US_RTH:                                        // ...
      case -PERIOD_D1_US_ETH:                                        // ...
      case -PERIOD_D1:                                               // ...
      case -PERIOD_W1:                                               // ...
      case -PERIOD_MN1:                                              // ...
      case -PERIOD_Q1:                                               // ...
         lastSuperTimeframe = superTimeframe;                        // nothing to do
         return(true);

      case PERIOD_H1:                                                // limit number of H1 superbars (performance)
         if (maxBarsH1 > 0) maxBars = maxBarsH1;
         break;
      case PERIOD_D1_US_RTH:                                         // no limit for everything else
      case PERIOD_D1_US_ETH:
      case PERIOD_D1:
      case PERIOD_W1:
      case PERIOD_MN1:
      case PERIOD_Q1:
         break;
   }

   // For US ETH sessions the range of ChangedBars must also include the range of iChangedBars(M15).
   int changedBars = ChangedBars;
   bool includeEthSession = false;                                   // whether to draw a US ETH session in a D1 session
   if (isTimeframeChange) {
      changedBars = Bars;                                            // on isTimeframeChange mark all bars as changed
   }
   if (superTimeframe == PERIOD_D1_US_ETH) {
      // TODO: On isTimeframeChange the following block is obsolete (it holds true: changedBars = Bars). However in this case
      //       DrawSuperBar() must again detect and handle ERS_HISTORY_UPDATE and ERR_SERIES_NOT_AVAILABLE.
      int changedBarsM15 = iChangedBars(NULL, PERIOD_M15);
      if (changedBarsM15 == -1) return(false);

      if (changedBarsM15 > 0) {
         datetime lastBarTimeM15 = iTime(NULL, PERIOD_M15, changedBarsM15-1);

         if (Time[changedBars-1] > lastBarTimeM15) {
            int bar = iBarShiftPrevious(NULL, NULL, lastBarTimeM15); if (bar == EMPTY_VALUE) return(false);
            if (bar == -1) changedBars = Bars;                       // lastBarTimeM15 is too old for the current chart period
            else           changedBars = bar + 1;
         }
         includeEthSession = true;
      }
   }

   // update super bars
   // -----------------
   // - Update range is var changedBars from young to old.
   // - The youngest and still unfinished super bar is limited to the right by Bar[0] and grows with time.
   // - The oldest super bar to update exceedes var changedBars to the left if Bars > changedBars (the regular case).
   // - "super session" means the session of the super bar period.
   datetime openTimeFxt=NULL, closeTimeFxt, openTimeSrv, closeTimeSrv;
   int openBar, closeBar, lastChartBar=Bars-1;

   int prevPeriodTimeframe = superTimeframe, cmeOpenTime = 16*HOURS + 30*MINUTES;   // CME opening time: 16:30 FXT
   if (superTimeframe == PERIOD_D1_US_RTH || superTimeframe == PERIOD_D1_US_ETH) {
      prevPeriodTimeframe = PERIOD_D1;                                              // iPreviousPeriod() needs a standard timeframe
   }

   // loop over all super bars from young to old
   for (int i=0; i < maxBars; i++) {
      // get start/end times of every super timeframe period, starting with the current unfinished one
      if (!iPreviousPeriod(prevPeriodTimeframe, openTimeFxt, closeTimeFxt, openTimeSrv, closeTimeSrv, !weekendSessionsEnabled)) return(false);
      if (superTimeframe == PERIOD_D1_US_RTH) {
         openTimeFxt += cmeOpenTime;
         openTimeSrv += cmeOpenTime;
      }

      // In periods >= PERIOD_D1 rate times are always set to full days which yields incorrect bar times in non-FXT timezones.
      // The incorrect timestamp shifts the start of such a period wrongly to the previous/next period. Must be fixed if
      // start of the period falls on a trading day (no need for fixing on a weekend/non-trading day).
      if (Period() >= PERIOD_D1 && superTimeframe >= PERIOD_MN1) {
         if (openTimeSrv  < openTimeFxt ) /*&&*/ if (TimeDayOfWeekEx(openTimeSrv )!=SUNDAY  ) openTimeSrv  = openTimeFxt;     // Sunday bar:   server timezone west of FXT
         if (closeTimeSrv > closeTimeFxt) /*&&*/ if (TimeDayOfWeekEx(closeTimeSrv)!=SATURDAY) closeTimeSrv = closeTimeFxt;    // Saturday bar: server timezone east of FXT
      }

      openBar  = iBarShiftNext    (NULL, NULL, openTimeSrv);           if (openBar  == EMPTY_VALUE) return(false);
      closeBar = iBarShiftPrevious(NULL, NULL, closeTimeSrv-1*SECOND); if (closeBar == EMPTY_VALUE) return(false);
      if (closeBar == -1) break;                                     // closeTime is too old for the chart => stopping

      if (openBar >= closeBar) {
         if      (openBar != lastChartBar)                             { if (!DrawSuperBar(openBar, closeBar, openTimeFxt, openTimeSrv, includeEthSession)) return(false); }
         else if (openBar == iBarShift(NULL, NULL, openTimeSrv, true)) { if (!DrawSuperBar(openBar, closeBar, openTimeFxt, openTimeSrv, includeEthSession)) return(false); }
      }                                                              // The super session covering the last chart bar is rarely complete, check anyway with (..., exact=TRUE).
      else {
         i--;                                                        // no bars available for this super session
      }
      if (openBar >= changedBars-1) break;                           // only update the range of var changedBars
   }

   lastSuperTimeframe = superTimeframe;
   return(true);
}


/**
 * Draw a single super bar.
 *
 * @param  _In_    int      openBar        - chart bar offset of the super bar's open bar
 * @param  _In_    int      closeBar       - chart bar offset of the super bar's close bar
 * @param  _In_    datetime openTimeFxt    - start time of the super bar period in FXT
 * @param  _In_    datetime openTimeSrv    - start time of the super bar period in server time
 * @param  _InOut_ bool     drawEthSession - D1 only: Whether to draw the US ETH session of a D1 super bar. Switches to FALSE
 *                                           once all available M15 data is processed, irrespective of further D1 super bars.
 * @return bool - success status
 */
bool DrawSuperBar(int openBar, int closeBar, datetime openTimeFxt, datetime openTimeSrv, bool &drawEthSession) {
   // resolve High and Low offset
   int highBar = iHighest(NULL, NULL, MODE_HIGH, openBar-closeBar+1, closeBar);
   int lowBar  = iLowest (NULL, NULL, MODE_LOW , openBar-closeBar+1, closeBar);

   // resolve bar color
   color barColor = UnchangedBars.Color;
   if (openBar < Bars-1) double openPrice = Close[openBar+1];        // use previous Close as Open if available
   else                         openPrice = Open [openBar];
   double ratio = openPrice/Close[closeBar]; if (ratio < 1) ratio = 1/ratio;
   ratio = 100 * (ratio-1);
   if (ratio > unchangedTreshold) {                                  // a smaller change is colored "unchanged"
      if      (openPrice < Close[closeBar]) barColor = UpBars.Color;
      else if (openPrice > Close[closeBar]) barColor = DownBars.Color;
   }

   // Each super bar consists of 3 objects: an OBJ_RECTANGLE representing the super bar body, an OBJ_TREND line with the close
   // price in the tooltip representing the super bar's close, and an OBJ_LABEL holding a reference to the close marker.
   // On data pumping an already drawn super bar and/or it's close price may change. With the reference in the label the close
   // marker can be found and updated without iterating over all chart objects.
   string nameRectangle="", nameRectangleBg="", nameTrendline="", nameOldTrendline="", nameLabel="";

   // define object names
   switch (superTimeframe) {
      case PERIOD_H1:        nameRectangle =          GmtTimeFormat(openTimeFxt, "%d.%m.%Y %H:%M");                   break;
      case PERIOD_D1_US_RTH: nameRectangle =          GmtTimeFormat(openTimeFxt, "%a %d.%m.%Y CME");                  break;
      case PERIOD_D1_US_ETH:
      case PERIOD_D1:        nameRectangle =          GmtTimeFormat(openTimeFxt, "%a %d.%m.%Y ");                     break;  // plus an extra space as "%a %d.%m.%Y" is already used by the "Grid" indicator
      case PERIOD_W1:        nameRectangle = "Week "+ GmtTimeFormat(openTimeFxt,    "%d.%m.%Y");                      break;
      case PERIOD_MN1:       nameRectangle =          GmtTimeFormat(openTimeFxt,       "%B %Y");                      break;
      case PERIOD_Q1:        nameRectangle = ((TimeMonth(openTimeFxt)-1)/3+1) +". Quarter "+ TimeYearEx(openTimeFxt); break;
   }

   // draw super bar body
   int adjustedCloseBar = closeBar;
   if (closeBar > 0) {                                                           // check for consecutive bars and widen rectangles to the right to make bars touch each other
      if (Time[closeBar] + Period()*MINUTES >= Time[closeBar-1]) {
         adjustedCloseBar--;
      }
   }
   if (ObjectFind(nameRectangle) == -1) if (!ObjectCreateRegister(nameRectangle, OBJ_RECTANGLE)) return(false);
   ObjectSet(nameRectangle, OBJPROP_TIME1,  Time[openBar]);
   ObjectSet(nameRectangle, OBJPROP_PRICE1, High[highBar]);
   ObjectSet(nameRectangle, OBJPROP_TIME2,  Time[adjustedCloseBar]);
   ObjectSet(nameRectangle, OBJPROP_PRICE2, Low[lowBar]);
   ObjectSet(nameRectangle, OBJPROP_COLOR,  barColor);
   ObjectSet(nameRectangle, OBJPROP_BACK,   FillBars);

   // draw super bar close marker and referencing label
   if (closeBar > 0) {                                                           // except for the youngest (still unfinished) super bar
      int centerBar = (openBar+closeBar)/2;                                      // TODO: draw close marker for the youngest bar after market-close (weekend)

      if (centerBar > closeBar) {
         nameLabel     = nameRectangle +" Close";
         nameTrendline = nameLabel +" "+ NumberToStr(Close[closeBar], PriceFormat);

         if (ObjectFind(nameLabel) != -1) {
            nameOldTrendline = ObjectDescription(nameLabel);                     // delete an existing close marker with an outdated price
            if (nameOldTrendline != nameTrendline) {
               if (ObjectFind(nameOldTrendline) != -1) ObjectDelete(nameOldTrendline);
            }
         }

         if (ObjectFind(nameLabel) == -1) if (!ObjectCreateRegister(nameLabel, OBJ_LABEL)) return(false);
         ObjectSet    (nameLabel, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
         ObjectSetText(nameLabel, nameTrendline);

         if (ObjectFind(nameTrendline) == -1) if (!ObjectCreateRegister(nameTrendline, OBJ_TREND)) return(false);
         ObjectSet(nameTrendline, OBJPROP_TIME1,  Time[centerBar]);
         ObjectSet(nameTrendline, OBJPROP_PRICE1, Close[closeBar]);
         ObjectSet(nameTrendline, OBJPROP_TIME2,  Time[closeBar]);
         ObjectSet(nameTrendline, OBJPROP_PRICE2, Close[closeBar]);
         ObjectSet(nameTrendline, OBJPROP_RAY,    false);
         ObjectSet(nameTrendline, OBJPROP_STYLE,  STYLE_SOLID);
         ObjectSet(nameTrendline, OBJPROP_COLOR,  CloseMarker.Color);
         ObjectSet(nameTrendline, OBJPROP_BACK,   true);
      }
   }

   // for D1: draw the US ETH session if M15 data is available
   while (drawEthSession) {                                                      // the loop declares just a block which can be more easily left via "break"
      // resolve High and Low
      datetime ethOpenTimeSrv  = openTimeSrv;                                    // as regular starttime of a 24h session (00:00 FXT)
      datetime ethCloseTimeSrv = openTimeSrv + 16*HOURS + 30*MINUTES;            // CME opening time                      (16:30 FXT)

      int ethOpenBar  = openBar;                                                 // regular open bar of a 24h session
      int ethCloseBar = iBarShiftPrevious(NULL, NULL, ethCloseTimeSrv-1*SECOND); // here openBar is always >= closeBar (checked above)
         if (ethCloseBar == EMPTY_VALUE) return(false);
         if (ethOpenBar <= ethCloseBar) break;                                   // stop if openBar not greater as closeBar (no place for drawing)

      int ethM15openBar = iBarShiftNext(NULL, PERIOD_M15, ethOpenTimeSrv);
         if (ethM15openBar == EMPTY_VALUE) return(false);
         if (ethM15openBar == -1)          break;                                // HISTORY_UPDATE in progress

      int ethM15closeBar = iBarShiftPrevious(NULL, PERIOD_M15, ethCloseTimeSrv-1*SECOND);
         if (ethM15closeBar == EMPTY_VALUE) return(false);
         if (ethM15closeBar == -1) { drawEthSession = false; break; }            // insufficient data, skip further US ETH sessions
         if (ethM15openBar < ethM15closeBar) break;                              // data contains a gap

      int ethM15highBar = iHighest(NULL, PERIOD_M15, MODE_HIGH, ethM15openBar-ethM15closeBar+1, ethM15closeBar);
      int ethM15lowBar  = iLowest (NULL, PERIOD_M15, MODE_LOW , ethM15openBar-ethM15closeBar+1, ethM15closeBar);

      double ethOpen  = iOpen (NULL, PERIOD_M15, ethM15openBar );
      double ethHigh  = iHigh (NULL, PERIOD_M15, ethM15highBar );
      double ethLow   = iLow  (NULL, PERIOD_M15, ethM15lowBar  );
      double ethClose = iClose(NULL, PERIOD_M15, ethM15closeBar);

      // define object names
      nameRectangle   = nameRectangle +" ETH";
      nameRectangleBg = nameRectangle +" background";

      // draw ETH background (creates an optical hole in the SuperBar)
      if (ObjectFind(nameRectangleBg) == -1) if (!ObjectCreateRegister(nameRectangleBg, OBJ_RECTANGLE)) return(false);
      ObjectSet(nameRectangleBg, OBJPROP_TIME1,  Time[ethOpenBar]);              // Colors of overlapping shapes are mixed with the chart background color according to gdi32::SetROP2(HDC hdc, R2_NOTXORPEN),
      ObjectSet(nameRectangleBg, OBJPROP_PRICE1, ethHigh);                       // see example at function end. As MQL4.0 can't read the chart background color we use a trick: A color mixed with itself gives
      ObjectSet(nameRectangleBg, OBJPROP_TIME2,  Time[ethCloseBar]);             // White. White mixed with another color gives again the original color. With this we create an "optical hole" in the color
      ObjectSet(nameRectangleBg, OBJPROP_PRICE2, ethLow);                        // of the chart background in the SuperBar. Then we draw the ETH bar into this "hole". It's color doesn't get mixed with the
      ObjectSet(nameRectangleBg, OBJPROP_COLOR,  barColor);                      // hole's color. Presumably because the terminal uses a different drawing mode for this mixing.
      ObjectSet(nameRectangleBg, OBJPROP_BACK,   true);

      // draw ETH bar (fills the hole with the ETH color)
      if (ObjectFind(nameRectangle) == -1)
         if (!ObjectCreateRegister(nameRectangle, OBJ_RECTANGLE)) return(false);
      ObjectSet(nameRectangle, OBJPROP_TIME1,  Time[ethOpenBar]);
      ObjectSet(nameRectangle, OBJPROP_PRICE1, ethHigh);
      ObjectSet(nameRectangle, OBJPROP_TIME2,  Time[ethCloseBar]);
      ObjectSet(nameRectangle, OBJPROP_PRICE2, ethLow);
      ObjectSet(nameRectangle, OBJPROP_COLOR,  US.ETH.Color);
      ObjectSet(nameRectangle, OBJPROP_BACK,   true);

      // draw ETH close marker if the RTH session has started
      if (serverTime >= ethCloseTimeSrv) {
         int ethCenterBar = (ethOpenBar+ethCloseBar)/2;

         if (ethCenterBar > ethCloseBar) {
            nameLabel     = nameRectangle +" Close";
            nameTrendline = nameLabel +" "+ NumberToStr(ethClose, PriceFormat);

            if (ObjectFind(nameLabel) != -1) {
               nameOldTrendline = ObjectDescription(nameLabel);                  // delete an existing close marker with an outdated price
               if (nameOldTrendline != nameTrendline) {
                  if (ObjectFind(nameOldTrendline) != -1) ObjectDelete(nameOldTrendline);
               }
            }

            if (ObjectFind(nameLabel) == -1) if (!ObjectCreateRegister(nameLabel, OBJ_LABEL)) return(false);
            ObjectSet    (nameLabel, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
            ObjectSetText(nameLabel, nameTrendline);

            if (ObjectFind(nameTrendline) == -1) if (!ObjectCreateRegister(nameTrendline, OBJ_TREND)) return(false);
            ObjectSet(nameTrendline, OBJPROP_TIME1,  Time[ethCenterBar]);
            ObjectSet(nameTrendline, OBJPROP_PRICE1, ethClose);
            ObjectSet(nameTrendline, OBJPROP_TIME2,  Time[ethCloseBar]);
            ObjectSet(nameTrendline, OBJPROP_PRICE2, ethClose);
            ObjectSet(nameTrendline, OBJPROP_RAY,    false);
            ObjectSet(nameTrendline, OBJPROP_STYLE,  STYLE_SOLID);
            ObjectSet(nameTrendline, OBJPROP_COLOR,  CloseMarker.Color);
            ObjectSet(nameTrendline, OBJPROP_BACK,   true);
         }
      }
      break;
   }
   /*
   Example for mixing colors according to gdi32::SetROP2(HDC hdc, R2_NOTXORPEN):
   -----------------------------------------------------------------------------
   What color to assign to a shape to make it appear "green rgb(0,255,0)" after mixing with chart color rgb(48,248,248) and another shape "rose rgb(255,213,213)"?

      Chart R: 11111000  G: 11111000  B: 11111000 = rgb(248,248,248)
    + Rose     11111111     11010101     11010101 = rgb(255,213,213)
      -------------------------------------------
      NOT-XOR: 11111000     11010010     11010010 = chart + rose        NOT-XOR: set bits which are the same in OP1 and OP2
    +          00000111     11010010     00101101 = rgb(7,210,45)    -> color which mixed with the temporary color (chart + rose) results in the requested color
      ===========================================
      NOT-XOR: 00000000     11111111     00000000 = rgb(0,255,0) = green

   The shape color to use is rgb(7,210,45).
   */
   return(!catch("DrawSuperBar(1)"));
}


/**
 * Update the SuperBar legend.
 *
 * @return bool - success status
 */
bool UpdateDescription() {
   string descr = "";

   switch (superTimeframe) {
      case  PERIOD_M1:        descr = "Super Bars: M1";                break;
      case  PERIOD_M5:        descr = "Super Bars: M5";                break;
      case  PERIOD_M15:       descr = "Super Bars: M15";               break;
      case  PERIOD_M30:       descr = "Super Bars: M30";               break;
      case  PERIOD_H1:        descr = "Super Bars: H1";                break;
      case  PERIOD_H4:        descr = "Super Bars: H4";                break;
      case  PERIOD_D1_US_RTH: descr = "Super Bars: US RTH";            break;
      case  PERIOD_D1_US_ETH: descr = "Super Bars: D1 + US ETH";       break;
      case  PERIOD_D1:        descr = "Super Bars: D1";                break;
      case  PERIOD_W1:        descr = "Super Bars: W1";                break;
      case  PERIOD_MN1:       descr = "Super Bars: MN1";               break;
      case  PERIOD_Q1:        descr = "Super Bars: Q1";                break;

      case -PERIOD_M1:        descr = "Super Bars: M1 (n/a)";          break;
      case -PERIOD_M5:        descr = "Super Bars: M5 (n/a)";          break;
      case -PERIOD_M15:       descr = "Super Bars: M15 (n/a)";         break;
      case -PERIOD_M30:       descr = "Super Bars: M30 (n/a)";         break;
      case -PERIOD_H1:        descr = "Super Bars: H1 (n/a)";          break;
      case -PERIOD_H4:        descr = "Super Bars: H4 (n/a)";          break;
      case -PERIOD_D1_US_RTH: descr = "Super Bars: US RTH (n/a)";      break;
      case -PERIOD_D1_US_ETH: descr = "Super Bars: D1 + US ETH (n/a)"; break;
      case -PERIOD_D1:        descr = "Super Bars: D1 (n/a)";          break;
      case -PERIOD_W1:        descr = "Super Bars: W1 (n/a)";          break;
      case -PERIOD_MN1:       descr = "Super Bars: MN1 (n/a)";         break;
      case -PERIOD_Q1:        descr = "Super Bars: Q1 (n/a)";          break;

      case  INT_MIN:
      case  INT_MAX:          descr = "Super Bars: off"; break;      // manually deactivated
      default:                descr = "Super Bars: n/a";             // programmatically deactivated
   }
   ObjectSetText(legendLabel, descr, legendFontSize, legendFontName, legendFontColor);

   int error = GetLastError();
   if (error && error!=ERR_OBJECT_DOES_NOT_EXIST)                    // on ObjectDrag or opened "Properties" dialog
      return(!catch("UpdateDescription(1)", error));
   return(true);
}


/**
 * Return a human-readable representation of a super timeframe id.
 *
 * @param  int timeframe - super timeframe
 *
 * @return string
 */
string SuperTimeframeToStr(int timeframe) {
   switch (timeframe) {
      case  PERIOD_M1:        return("PERIOD_M1");
      case  PERIOD_M5:        return("PERIOD_M5");
      case  PERIOD_M15:       return("PERIOD_M15");
      case  PERIOD_M30:       return("PERIOD_M30");
      case  PERIOD_H1:        return("PERIOD_H1");
      case  PERIOD_H4:        return("PERIOD_H4");
      case  PERIOD_D1_US_RTH: return("PERIOD_D1_US_RTH");
      case  PERIOD_D1_US_ETH: return("PERIOD_D1_US_ETH");
      case  PERIOD_D1:        return("PERIOD_D1");
      case  PERIOD_W1:        return("PERIOD_W1");
      case  PERIOD_MN1:       return("PERIOD_MN1");
      case  PERIOD_Q1:        return("PERIOD_Q1");

      case -PERIOD_M1:        return("-PERIOD_M1");
      case -PERIOD_M5:        return("-PERIOD_M5");
      case -PERIOD_M15:       return("-PERIOD_M15");
      case -PERIOD_M30:       return("-PERIOD_M30");
      case -PERIOD_H1:        return("-PERIOD_H1");
      case -PERIOD_H4:        return("-PERIOD_H4");
      case -PERIOD_D1_US_RTH: return("-PERIOD_D1_US_RTH");
      case -PERIOD_D1_US_ETH: return("-PERIOD_D1_US_ETH");
      case -PERIOD_D1:        return("-PERIOD_D1");
      case -PERIOD_W1:        return("-PERIOD_W1");
      case -PERIOD_MN1:       return("-PERIOD_MN1");
      case -PERIOD_Q1:        return("-PERIOD_Q1");

      case  INT_MIN:          return("INT_MIN");
      case  INT_MAX:          return("INT_MAX");
   }
   return(timeframe +" (unknown)");
}


/**
 * Create a text label for the indicator status.
 *
 * @return string - the label name or an empty string in case of errors
 */
string CreateStatusLabel() {
   if (__isSuperContext) return("");

   string name = "rsf."+ WindowExpertName() +".status["+ __ExecutionContext[EC.pid] +"]";

   if (ObjectFind(name) == -1) if (!ObjectCreateRegister(name, OBJ_LABEL)) return("");
   ObjectSet    (name, OBJPROP_CORNER,    legendCorner);
   ObjectSet    (name, OBJPROP_XDISTANCE, legend_xDistance);
   ObjectSet    (name, OBJPROP_YDISTANCE, legend_yDistance);
   ObjectSetText(name, " ", 1);

   if (!catch("CreateStatusLabel(1)"))
      return(name);
   return("");
}


/**
 * Store the active SuperBars timeframe in the chart (for init cycle and terminal restart) and in
 * the window (for new chart templates).
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (!__isChart || !superTimeframe) return(true);

   string label = "rsf."+ WindowExpertName() +".superTimeframe";

   // store timeframe in the window
   int hWnd = __ExecutionContext[EC.chart];
   SetWindowIntegerA(hWnd, label, superTimeframe);

   // store timeframe in the chart
   if (ObjectFind(label) == -1) ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ superTimeframe);

   return(catch("StoreStatus(1)"));
}


/**
 * Restore the active SuperBars timeframe from the chart or the window.
 *
 * @return bool - success status
 */
bool RestoreStatus() {
   if (!__isChart) return(true);

   string label = "rsf."+ WindowExpertName() +".superTimeframe";

   // restore timeframe from the window (preferred due to performance)
   int hWnd = __ExecutionContext[EC.chart];
   int result = RemoveWindowIntegerA(hWnd, label);

   // on error restore from the chart
   if (!result) {
      if (ObjectFind(label) == 0) {
         string value = ObjectDescription(label);
         if (StrIsInteger(value)) {
            result = StrToInteger(value);
         }
      }
   }
   if (result != 0) superTimeframe = result;

   return(!catch("RestoreStatus(1)"));
}


/**
 * Set indicator options. After recompilation the function must be called from start() for options not to be ignored.
 *
 * @param  bool redraw [optional] - whether to redraw the chart (default: no)
 *
 * @return bool - success status
 */
bool SetIndicatorOptions(bool redraw = false) {
   redraw = redraw!=0;

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(BUFFER_HIDDEN_BODY_A, hiddenBodyA); SetIndexEmptyValue(BUFFER_HIDDEN_BODY_A, 0);
   SetIndexBuffer(BUFFER_HIDDEN_BODY_B, hiddenBodyB); SetIndexEmptyValue(BUFFER_HIDDEN_BODY_B, 0);
   SetIndexBuffer(BUFFER_HIDDEN_WICK_A, hiddenWickA); SetIndexEmptyValue(BUFFER_HIDDEN_WICK_A, 0);
   SetIndexBuffer(BUFFER_HIDDEN_WICK_B, hiddenWickB); SetIndexEmptyValue(BUFFER_HIDDEN_WICK_B, 0);
   IndicatorDigits(Digits);

   // in histograms the larger of both values determines the displayed color
   SetIndexStyle(BUFFER_HIDDEN_BODY_A, DRAW_HISTOGRAM, EMPTY, 1, CLR_NONE);
   SetIndexStyle(BUFFER_HIDDEN_BODY_B, DRAW_HISTOGRAM, EMPTY, 1, CLR_NONE);
   SetIndexStyle(BUFFER_HIDDEN_WICK_A, DRAW_HISTOGRAM, EMPTY, 1, CLR_NONE);
   SetIndexStyle(BUFFER_HIDDEN_WICK_B, DRAW_HISTOGRAM, EMPTY, 1, CLR_NONE);

   SetIndexLabel(BUFFER_HIDDEN_BODY_A, NULL);
   SetIndexLabel(BUFFER_HIDDEN_BODY_B, NULL);
   SetIndexLabel(BUFFER_HIDDEN_WICK_A, NULL);
   SetIndexLabel(BUFFER_HIDDEN_WICK_B, NULL);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate(
      "UpBars.Color=",            ColorToStr(UpBars.Color),                ";", NL,
      "DownBars.Color=",          ColorToStr(DownBars.Color),              ";", NL,
      "UnchangedBars.Color=",     ColorToStr(UnchangedBars.Color),         ";", NL,
      "CloseMarker.Color=",       ColorToStr(CloseMarker.Color),           ";", NL,
      "US.ETH.Color=",            ColorToStr(US.ETH.Color),                ";", NL,
      "US.ETH.Symbols=",          DoubleQuoteStr(US.ETH.Symbols),          ";", NL,
      "US.RTH.Symbols=",          DoubleQuoteStr(US.RTH.Symbols),          ";", NL,
      "WeekendSessions.Symbols=", DoubleQuoteStr(WeekendSessions.Symbols), ";", NL
   ));

   // suppress compiler warnings
   SuperTimeframeToStr(NULL);
}
