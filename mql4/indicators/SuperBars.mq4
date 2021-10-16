/**
 * SuperBars
 *
 * Draws bars of higher timeframes on the chart. The active timeframe can be changed with the scripts "SuperBars.TimeframeUp"
 * and "SuperBars.TimeframeDown".
 *
 * With input parameter "AutoConfiguration" enabled (default) inputs found in the external framework configuration have
 * precedence over manual inputs. Additional external configuration settings (no manual inputs):
 *
 * [SuperBars]
 *  Legend.Corner                = {int}              ; CORNER_TOP_LEFT* | CORNER_TOP_RIGHT | CORNER_BOTTOM_LEFT | CORNER_BOTTOM_RIGHT
 *  Legend.xDistance             = {int}              ; offset in pixels
 *  Legend.yDistance             = {int}              ; offset in pixels
 *  Legend.FontName              = {string}           ; font family
 *  Legend.FontSize              = {int}              ; font size
 *  Legend.FontColor             = {color}            ; font color (web color name or integer triplet)
 *  UnchangedBars.MaxPriceChange = {double}           ; max. close change of a bar in percent to be drawn as "unchanged"
 *  MaxBars.H1                   = {int}              ; max. number of H1 superbars (performance, default: all)
 *  ErrorSound                   = {string}           ; sound played when timeframe cycling is at min/max (default: none)
 *
 * @see  https://www.forexfactory.com/thread/1078323-superbars-higher-timeframe-bars-with-cme-session-support
 *
 * TODO:
 *  - doesn't work on offline charts
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_AUTOCONFIG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern color  UpBars.Color        = PaleGreen;        // bullish bars
extern color  DownBars.Color      = Pink;             // bearish bars
extern color  UnchangedBars.Color = Lavender;         // unchanged bars
extern color  CloseMarker.Color   = Gray;             // bar close marker
extern color  ETH.Color           = LemonChiffon;     // ETH sessions
extern string ETH.Symbols         = "";               // comma-separated list of symbols with RTH/ETH sessions

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/iBarShiftNext.mqh>
#include <functions/iBarShiftPrevious.mqh>
#include <functions/iChangedBars.mqh>
#include <functions/iPreviousPeriodTimes.mqh>
#include <win32api.mqh>

#property indicator_chart_window

#define STF_UP             1
#define STF_DOWN          -1
#define PERIOD_D1_ETH   1439                          // that's PERIOD_D1 - 1

int    superTimeframe;                                // the currently active super bar period
double maxChangeUnchanged = 0.05;                     // max. price change in % for a superbar to be drawn as unchanged
bool   ethEnabled;                                    // whether CME sessions are enabled
int    maxBarsH1;                                     // max. number of H1 superbars to draw (performance)

string legendLabel      = "";
int    legendCorner     = CORNER_TOP_LEFT;
int    legend_xDistance = 300;
int    legend_yDistance = 3;
string legendFontName   = "";                         // default: empty = menu font ("MS Sans Serif")
int    legendFontSize   = 8;                          // "MS Sans Serif", size 8 corresponds with the menu font
color  legendFontColor  = Black;

string errorSound = "";                               // sound played when timeframe cycling is at min/max (default: none)


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (UpBars.Color        == 0xFF000000) UpBars.Color        = CLR_NONE;
   if (DownBars.Color      == 0xFF000000) DownBars.Color      = CLR_NONE;
   if (UnchangedBars.Color == 0xFF000000) UnchangedBars.Color = CLR_NONE;
   if (CloseMarker.Color   == 0xFF000000) CloseMarker.Color   = CLR_NONE;
   if (ETH.Color           == 0xFF000000) ETH.Color           = CLR_NONE;
   if (AutoConfiguration) {
      UpBars.Color        = GetConfigColor(indicator, "UpBars.Color",        UpBars.Color);
      DownBars.Color      = GetConfigColor(indicator, "DownBars.Color",      DownBars.Color);
      UnchangedBars.Color = GetConfigColor(indicator, "UnchangedBars.Color", UnchangedBars.Color);
      CloseMarker.Color   = GetConfigColor(indicator, "CloseMarker.Color",   CloseMarker.Color);
      ETH.Color           = GetConfigColor(indicator, "ETH.Color",           ETH.Color);
   }
   // ETH.Symbols
   string values[], sValue = StrTrim(ETH.Symbols);
   if (AutoConfiguration) sValue = GetConfigString(indicator, "ETH.Symbols", sValue);
   if (StringLen(sValue) > 0) {
      int size = Explode(StrToLower(sValue), ",", values, NULL);
      for (int i=0; i < size; i++) {
         values[i] = StrTrim(values[i]);
      }
      ethEnabled = (StringInArrayI(values, Symbol()) || StringInArrayI(values, StdSymbol()));
   }

   // read external configuration
   double dValue; int iValue;
   dValue          = GetConfigDouble(indicator, "UnchangedBars.MaxPriceChange");    maxChangeUnchanged = MathAbs(ifDouble(!dValue, maxChangeUnchanged, dValue));
   iValue          = GetConfigInt   (indicator, "MaxBars.H1",       -1);            maxBarsH1          = ifInt(iValue > 0, iValue, NULL);
   iValue          = GetConfigInt   (indicator, "Legend.Corner",    -1);            legendCorner       = ifInt(iValue >= CORNER_TOP_LEFT && iValue <= CORNER_BOTTOM_RIGHT, iValue, legendCorner);
   iValue          = GetConfigInt   (indicator, "Legend.xDistance", -1);            legend_xDistance   = ifInt(iValue >= 0, iValue, legend_xDistance);
   iValue          = GetConfigInt   (indicator, "Legend.yDistance", -1);            legend_yDistance   = ifInt(iValue >= 0, iValue, legend_yDistance);
   legendFontName  = GetConfigString(indicator, "Legend.FontName", legendFontName);
   iValue          = GetConfigInt   (indicator, "Legend.FontSize");                 legendFontSize     = ifInt(iValue > 0, iValue, legendFontSize);
   legendFontColor = GetConfigColor (indicator, "Legend.FontColor", legendFontColor);
   errorSound      = GetConfigString(indicator, "ErrorSound", errorSound);

   // display configuration, names, labels
   SetIndexLabel(0, NULL);                               // no entries in "Data" window
   legendLabel = CreateStatusLabel();                    // create status label

   // restore a stored runtime status
   if (!RestoreRuntimeStatus()) return(last_error);

   CheckTimeframeAvailability();
   return(catch("onInit(1)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   if (!StoreRuntimeStatus())                            // store runtime status in all deinit scenarios
      return(last_error);
   return(NO_ERROR);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   HandleCommands();                                                 // process incoming commands
   UpdateSuperBars();                                                // update superbars
   return(last_error);
}


/**
 * Dispatch incoming commands.
 *
 * @param  string commands[] - received commands
 *
 * @return bool - success status
 */
bool onCommand(string commands[]) {
   if (!ArraySize(commands)) return(!logWarn("onCommand(1)  empty parameter commands: {}"));
   string cmd = commands[0];
   if (IsLogDebug()) logDebug("onCommand(2)  "+ DoubleQuoteStr(cmd));

   if (cmd == "Timeframe=Up")   return(SwitchSuperTimeframe(STF_UP));
   if (cmd == "Timeframe=Down") return(SwitchSuperTimeframe(STF_DOWN));

   logWarn("onCommand(3)  unsupported command: "+ DoubleQuoteStr(cmd));
   return(true);                                                     // continue anyway
}


/**
 * Change the currently active superbars timeframe.
 *
 * @param  int direction - direction to change: STF_UP | STF_DOWN
 *
 * @return bool - success status
 */
bool SwitchSuperTimeframe(int direction) {
   bool reset = false;

   if (direction == STF_DOWN) {
      switch (superTimeframe) {
         case  INT_MIN:
            if (errorSound != "") PlaySoundEx(errorSound);  break;   // we hit the wall downwards

         case  PERIOD_H1:
         case -PERIOD_H1:     superTimeframe =  INT_MIN;    break;

         case  PERIOD_D1_ETH: superTimeframe =  PERIOD_H1;  break;
         case -PERIOD_D1_ETH: superTimeframe = -PERIOD_H1;  break;

         case  PERIOD_D1:     superTimeframe =  ifInt(ethEnabled, PERIOD_D1_ETH, PERIOD_H1); break;
         case -PERIOD_D1:     superTimeframe = -ifInt(ethEnabled, PERIOD_D1_ETH, PERIOD_H1); break;

         case  PERIOD_W1:     superTimeframe =  PERIOD_D1;  break;
         case -PERIOD_W1:     superTimeframe = -PERIOD_D1;  break;

         case  PERIOD_MN1:    superTimeframe =  PERIOD_W1;  break;
         case -PERIOD_MN1:    superTimeframe = -PERIOD_W1;  break;

         case  PERIOD_Q1:     superTimeframe =  PERIOD_MN1; break;
         case -PERIOD_Q1:     superTimeframe = -PERIOD_MN1; break;

         case  INT_MAX:       superTimeframe =  PERIOD_Q1;  break;
      }
   }
   else if (direction == STF_UP) {
      switch (superTimeframe) {
         case  INT_MIN:       superTimeframe =  PERIOD_H1;  break;

         case  PERIOD_H1:     superTimeframe =  ifInt(ethEnabled, PERIOD_D1_ETH, PERIOD_D1); break;
         case -PERIOD_H1:     superTimeframe = -ifInt(ethEnabled, PERIOD_D1_ETH, PERIOD_D1); break;

         case  PERIOD_D1_ETH: superTimeframe =  PERIOD_D1;  break;
         case -PERIOD_D1_ETH: superTimeframe = -PERIOD_D1;  break;

         case  PERIOD_D1:     superTimeframe =  PERIOD_W1;  break;
         case -PERIOD_D1:     superTimeframe = -PERIOD_W1;  break;

         case  PERIOD_W1:     superTimeframe =  PERIOD_MN1; break;
         case -PERIOD_W1:     superTimeframe = -PERIOD_MN1; break;

         case  PERIOD_MN1:    superTimeframe =  PERIOD_Q1;  break;
         case -PERIOD_MN1:    superTimeframe = -PERIOD_Q1;  break;

         case  PERIOD_Q1:     superTimeframe =  INT_MAX;    break;

         case  INT_MAX:
            if (errorSound != "") PlaySoundEx(errorSound);  break;   // we hit the wall upwards
      }
   }
   else return(!catch("SwitchSuperTimeframe(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   return(CheckTimeframeAvailability());                             // check availability of the new setting
}


/**
 * Whether the selected superbar timeframe can be displayed on the current chart, e.g. the bar period H1 can't be displayed
 * on an H4 chart. If the superbar timeframe can't be displayed superbars are disabled for that chart period.
 *
 * @return bool - success status
 */
bool CheckTimeframeAvailability() {
   switch (superTimeframe) {
      // off: to be activated manually only
      case  INT_MIN      :
      case  INT_MAX      : break;

      // positive value = active: automatically deactivated if display on the current doesn't make sense
      case  PERIOD_H1    : if (Period() >  PERIOD_M15) superTimeframe *= -1; break;
      case  PERIOD_D1_ETH:
         if (!ethEnabled) superTimeframe = PERIOD_D1;
      case  PERIOD_D1    : if (Period() >  PERIOD_H4 ) superTimeframe *= -1; break;
      case  PERIOD_W1    : if (Period() >  PERIOD_D1 ) superTimeframe *= -1; break;
      case  PERIOD_MN1   : if (Period() >  PERIOD_D1 ) superTimeframe *= -1; break;
      case  PERIOD_Q1    : if (Period() >  PERIOD_W1 ) superTimeframe *= -1; break;

      // negative value = inactive: automatically activated if display on the current chart makes sense
      case -PERIOD_H1    : if (Period() <= PERIOD_M15) superTimeframe *= -1; break;
      case -PERIOD_D1_ETH:
         if (!ethEnabled) superTimeframe = -PERIOD_H1;
      case -PERIOD_D1    : if (Period() <= PERIOD_H4 ) superTimeframe *= -1; break;
      case -PERIOD_W1    : if (Period() <= PERIOD_D1 ) superTimeframe *= -1; break;
      case -PERIOD_MN1   : if (Period() <= PERIOD_D1 ) superTimeframe *= -1; break;
      case -PERIOD_Q1    : if (Period() <= PERIOD_W1 ) superTimeframe *= -1; break;

      // not initialized or invalid value: reset to default value
      default:
         switch (Period()) {
            case PERIOD_M1 :
            case PERIOD_M5 :
            case PERIOD_M15:
            case PERIOD_M30:
            case PERIOD_H1 : superTimeframe =  PERIOD_D1;  break;
            case PERIOD_H4 : superTimeframe =  PERIOD_W1;  break;
            case PERIOD_D1 : superTimeframe =  PERIOD_MN1; break;
            case PERIOD_W1 :
            case PERIOD_MN1: superTimeframe = -PERIOD_MN1; break;
         }
   }
   return(true);
}


/**
 * Update the superbars display.
 *
 * @return bool - success status
 */
bool UpdateSuperBars() {
   // on a supertimeframe change delete the superbars of the previously active timeframe
   static int lastSuperTimeframe;
   bool isTimeframeChange = (superTimeframe != lastSuperTimeframe);  // for simplicity interpret the first comparison (lastSuperTimeframe==0) as a change, too

   if (isTimeframeChange) {
      if (PERIOD_M1 <= lastSuperTimeframe && lastSuperTimeframe <= PERIOD_Q1) {
         DeleteRegisteredObjects();                                  // in all other cases previous SuperBars have already been deleted
         legendLabel = CreateStatusLabel();
      }
      UpdateDescription();
   }

   // define the amount of superbars to draw
   int maxBars = INT_MAX;
   switch (superTimeframe) {
      case  INT_MIN:                                                 // manually deactivated
      case  INT_MAX:                                                 // ...
      case -PERIOD_H1:                                               // automatically deactivated
      case -PERIOD_D1_ETH:                                           // ...
      case -PERIOD_D1:                                               // ...
      case -PERIOD_W1:                                               // ...
      case -PERIOD_MN1:                                              // ...
      case -PERIOD_Q1:                                               // ...
         lastSuperTimeframe = superTimeframe;                        // nothing to do
         return(true);

      case PERIOD_H1:                                                // limit number of H1 superbars (performance)
         if (maxBarsH1 > 0) maxBars = maxBarsH1;
         break;

      case PERIOD_D1_ETH:                                            // no limit for everything else
      case PERIOD_D1:
      case PERIOD_W1:
      case PERIOD_MN1:
      case PERIOD_Q1:
         break;
   }


   // With enabled ETH sessions the range of ChangedBars must include the range of iChangedBars(PERIOD_M15).
   int  changedBars=ChangedBars, timeframe=superTimeframe;
   bool drawETH;
   if (isTimeframeChange)
      changedBars = Bars;                                            // on isTimeframeChange mark all bars as changed

   if (ethEnabled && superTimeframe==PERIOD_D1_ETH) {
      timeframe = PERIOD_D1;
      // TODO: On isTimeframeChange the following block is obsolete (it holds: changedBars = Bars). However in this case
      //       DrawSuperBar() must again detect and handle ERS_HISTORY_UPDATE and ERR_SERIES_NOT_AVAILABLE.
      int changedBarsM15 = iChangedBars(NULL, PERIOD_M15);
      if (changedBarsM15 == -1) return(false);

      if (changedBarsM15 > 0) {
         datetime lastBarTimeM15 = iTime(NULL, PERIOD_M15, changedBarsM15-1);

         if (Time[changedBars-1] > lastBarTimeM15) {
            int bar = iBarShiftPrevious(NULL, NULL, lastBarTimeM15); if (bar == EMPTY_VALUE) return(false);
            if (bar == -1) changedBars = Bars;                       // M15-Zeitpunkt ist zu alt für den aktuellen Chart
            else           changedBars = bar + 1;
         }
         drawETH = true;
      }
   }


   // update superbars
   // ----------------
   //  - Drawing range is ChangedBars but we don't use a loop over the ChangedBars.
   //  - The youngest - still open - SuperBar is limited on the right by Bar[0] and grows with progression of time.
   //  - The oldest SuperBar exceedes ChangedBars on the left if Bars > ChangedBars (the regular runtime case).
   //  - In the following a "super session" doesn't mean 24h but the superbar period.
   datetime openTimeFxt, closeTimeFxt, openTimeSrv, closeTimeSrv;
   int      openBar, closeBar, lastChartBar=Bars-1;

   // loop over all superbars from young to old (right to left)
   for (int i=0; i < maxBars; i++) {
      if (!iPreviousPeriodTimes(timeframe, openTimeFxt, closeTimeFxt, openTimeSrv, closeTimeSrv))
         return(false);

      // From chart timeframe PERIOD_D1 times in the rates array are set only to full days. The timezone offset may shift the start of a month wrongly to the
      // previous or the next month. Must be fixed if the start of month falls in the middle of a week (no need for fixing if start of month falls on a weekend).
      if (Period()==PERIOD_D1) /*&&*/ if (timeframe >= PERIOD_MN1) {
         if (openTimeSrv  < openTimeFxt ) /*&&*/ if (TimeDayOfWeekEx(openTimeSrv )!=SUNDAY  ) openTimeSrv  = openTimeFxt;     // Sunday bar:  server timezone west of FXT
         if (closeTimeSrv > closeTimeFxt) /*&&*/ if (TimeDayOfWeekEx(closeTimeSrv)!=SATURDAY) closeTimeSrv = closeTimeFxt;    // Saturday bar: server timezone east of FXT
      }

      openBar  = iBarShiftNext    (NULL, NULL, openTimeSrv);           if (openBar  == EMPTY_VALUE) return(false);
      closeBar = iBarShiftPrevious(NULL, NULL, closeTimeSrv-1*SECOND); if (closeBar == EMPTY_VALUE) return(false);
      if (closeBar == -1) break;                                           // closeTime is too old for the chart => stopping

      if (openBar >= closeBar) {
         if      (openBar != lastChartBar)                             { if (!DrawSuperBar(openBar, closeBar, openTimeFxt, openTimeSrv, drawETH)) return(false); }
         else if (openBar == iBarShift(NULL, NULL, openTimeSrv, true)) { if (!DrawSuperBar(openBar, closeBar, openTimeFxt, openTimeSrv, drawETH)) return(false); }
      }                                                                    // The super session covering the last chart bar is rarely complete, check anyway with (..., exact=TRUE).
      else {
         i--;                                                              // no bars available for this super session
      }
      if (openBar >= changedBars-1) break;                                 // update superbars until max. changedBars
   }

   lastSuperTimeframe = superTimeframe;
   return(true);
}


/**
 * Draw a single Superbar.
 *
 * @param  _In_    int      openBar     - chart period bar offset of the SuperBar's open bar
 * @param  _In_    int      closeBar    - chart period bar offset of the SuperBar's close bar
 * @param  _In_    datetime openTimeFxt - super session starttime in FXT
 * @param  _In_    datetime openTimeSrv - super session starttime in server time
 * @param  _InOut_ bool     &drawETH    - Variable signaling whether the ETH session of a D1 superbar can be drawn. If all
 *                                        available M15 data is processed the variable switches to FALSE irrespective of
 *                                        further D1 SuperBars.
 * @return bool - success status
 */
bool DrawSuperBar(int openBar, int closeBar, datetime openTimeFxt, datetime openTimeSrv, bool &drawETH) {
   // draw superbar session
   // resolve High and Low bar offset
   int highBar = iHighest(NULL, NULL, MODE_HIGH, openBar-closeBar+1, closeBar);
   int lowBar  = iLowest (NULL, NULL, MODE_LOW , openBar-closeBar+1, closeBar);

   // resolve bar color
   color barColor = UnchangedBars.Color;
   if (openBar < Bars-1) double openPrice = Close[openBar+1];                       // use previous Close as Open if available
   else                         openPrice = Open [openBar];
   double ratio = openPrice/Close[closeBar]; if (ratio < 1) ratio = 1/ratio;
   ratio = 100 * (ratio-1);
   if (ratio > maxChangeUnchanged) {                                                // a change smaller is considered "unchanged"
      if      (openPrice < Close[closeBar]) barColor = UpBars.Color;
      else if (openPrice > Close[closeBar]) barColor = DownBars.Color;
   }

   // define object labels
   string label = "";
   switch (superTimeframe) {
      case PERIOD_H1    : label =          GmtTimeFormat(openTimeFxt, "%d.%m.%Y %H:%M");                   break;
      case PERIOD_D1_ETH:
      case PERIOD_D1    : label =          GmtTimeFormat(openTimeFxt, "%a %d.%m.%Y ");                     break; // "aaa dd.mm.YYYY" is already used by the Grid indicator
      case PERIOD_W1    : label = "Week "+ GmtTimeFormat(openTimeFxt,    "%d.%m.%Y");                      break;
      case PERIOD_MN1   : label =          GmtTimeFormat(openTimeFxt,       "%B %Y");                      break;
      case PERIOD_Q1    : label = ((TimeMonth(openTimeFxt)-1)/3+1) +". Quarter "+ TimeYearEx(openTimeFxt); break;
   }

   // draw Superbar
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
      int closeBar_j = closeBar; /*_j as justified*/                                // Widen rectangles by one bar to the right to make consecutives bars touch each other,
      if (closeBar > 0) closeBar_j--;                                               // but not for the youngest - still open - SuperBar.
   if (ObjectCreate (label, OBJ_RECTANGLE, 0, Time[openBar], High[highBar], Time[closeBar_j], Low[lowBar])) {
      ObjectSet     (label, OBJPROP_COLOR, barColor);
      ObjectSet     (label, OBJPROP_BACK , true    );
      RegisterObject(label);
   }
   else GetLastError();

   // draw close marker
   if (closeBar > 0) {                                                              // except for the youngest - still unfinished - SuperBar
      int centerBar = (openBar+closeBar)/2;                                         // TODO: draw close marker for the youngest bar after market-close (weekend)

      if (centerBar > closeBar) {
         string labelWithPrice="", labelWithoutPrice=label +" Close";

         if (ObjectFind(labelWithoutPrice) == 0) {                                  // Every marker consists of two objects: an invisible label (1st object) with a fixed name
            labelWithPrice = ObjectDescription(labelWithoutPrice);                  // holding in the description the dynamic and variable name of the visible marker (2nd object).
            if (ObjectFind(labelWithPrice) == 0)                                    // This way an existing marker can be found and replaced, even if the dynamic name changes.
               ObjectDelete(labelWithPrice);
            ObjectDelete(labelWithoutPrice);
         }
         labelWithPrice = labelWithoutPrice +" "+ NumberToStr(Close[closeBar], PriceFormat);

         if (ObjectCreate (labelWithoutPrice, OBJ_LABEL, 0, 0, 0)) {
            ObjectSet     (labelWithoutPrice, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
            ObjectSetText (labelWithoutPrice, labelWithPrice);
            RegisterObject(labelWithoutPrice);
         } else GetLastError();

         if (ObjectCreate (labelWithPrice, OBJ_TREND, 0, Time[centerBar], Close[closeBar], Time[closeBar], Close[closeBar])) {
            ObjectSet     (labelWithPrice, OBJPROP_RAY  , false);
            ObjectSet     (labelWithPrice, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSet     (labelWithPrice, OBJPROP_COLOR, CloseMarker.Color);
            ObjectSet     (labelWithPrice, OBJPROP_BACK , true);
            RegisterObject(labelWithPrice);
         } else GetLastError();
      }
   }


   // draw ETH session if enough M15 data is available
   while (drawETH) {                                                                // the loop declares just a block which can be more easily left via "break"
      // resolve High and Low
      datetime ethOpenTimeSrv  = openTimeSrv;                                       // as regular starttime of a 24h session (00:00 FXT)
      datetime ethCloseTimeSrv = openTimeSrv + 16*HOURS + 30*MINUTES;               // CME opening time                      (16:30 FXT)

      int ethOpenBar  = openBar;                                                    // regular open bar of a 24h session
      int ethCloseBar = iBarShiftPrevious(NULL, NULL, ethCloseTimeSrv-1*SECOND);    // here openBar is always >= closeBar (checked above)
         if (ethCloseBar == EMPTY_VALUE) return(false);
         if (ethOpenBar <= ethCloseBar) break;                                      // stop if openBar not greater as closeBar (no place for drawing)

      int ethM15openBar = iBarShiftNext(NULL, PERIOD_M15, ethOpenTimeSrv);
         if (ethM15openBar == EMPTY_VALUE) return(false);
         if (ethM15openBar == -1)          break;                                   // HISTORY_UPDATE in progress

      int ethM15closeBar = iBarShiftPrevious(NULL, PERIOD_M15, ethCloseTimeSrv-1*SECOND);
         if (ethM15closeBar == EMPTY_VALUE)    return(false);
         if (ethM15closeBar == -1) { drawETH = false; break; }                      // available data is enough, stop drawing of further ETH sessions
         if (ethM15openBar < ethM15closeBar) break;                                 // available data contains a gap

      int ethM15highBar = iHighest(NULL, PERIOD_M15, MODE_HIGH, ethM15openBar-ethM15closeBar+1, ethM15closeBar);
      int ethM15lowBar  = iLowest (NULL, PERIOD_M15, MODE_LOW , ethM15openBar-ethM15closeBar+1, ethM15closeBar);

      double ethOpen  = iOpen (NULL, PERIOD_M15, ethM15openBar );
      double ethHigh  = iHigh (NULL, PERIOD_M15, ethM15highBar );
      double ethLow   = iLow  (NULL, PERIOD_M15, ethM15lowBar  );
      double ethClose = iClose(NULL, PERIOD_M15, ethM15closeBar);

      // define labels
      string ethLabel   = label +" ETH";
      string ethBgLabel = label +" ETH background";

      // drwa ETH background (creates an optical whole in the Superbar)
      if (ObjectFind(ethBgLabel) == 0)
         ObjectDelete(ethBgLabel);
      if (ObjectCreate(ethBgLabel, OBJ_RECTANGLE, 0, Time[ethOpenBar], ethHigh, Time[ethCloseBar], ethLow)) {
         ObjectSet     (ethBgLabel, OBJPROP_COLOR, barColor);
         ObjectSet     (ethBgLabel, OBJPROP_BACK, true);                            // Colors of overlapping shapes are mixed with the chart background color according to
         RegisterObject(ethBgLabel);                                                // gdi32::SetROP2(HDC hdc, R2_NOTXORPEN); see example at function end.
      }                                                                             // As MQL4 can't read the chart background color, we use a trick: A color mixed with itself
                                                                                    // gives White. White mixed with another color gives again the original color.
      // draw ETH bar (fills the whole with the ETH color)                          // With this we create an "optical whole" in the color of the chart background in the SuperBar.
      if (ObjectFind(ethLabel) == 0)                                                // Then we draw the ETH bar into this "whole". It's color doesn't get mixed with the "whole"'s color
         ObjectDelete(ethLabel);                                                    // Presumably because the terminal uses a different drawing mode for this mixing.
      if (ObjectCreate(ethLabel, OBJ_RECTANGLE, 0, Time[ethOpenBar], ethHigh, Time[ethCloseBar], ethLow)) {
         ObjectSet     (ethLabel, OBJPROP_COLOR, ETH.Color);
         ObjectSet     (ethLabel, OBJPROP_BACK, true);
         RegisterObject(ethLabel);
      }

      // draw ETH close marker if the RTH session has started
      if (TimeServer() >= ethCloseTimeSrv) {
         int ethCenterBar = (ethOpenBar+ethCloseBar)/2;

         if (ethCenterBar > ethCloseBar) {
            string ethLabelWithPrice="", ethLabelWithoutPrice=ethLabel +" Close";

            if (ObjectFind(ethLabelWithoutPrice) == 0) {                            // Every marker consists of two objects: an invisible label (1st object) with a fixed name
               ethLabelWithPrice = ObjectDescription(ethLabelWithoutPrice);         // holding in the description the dynamic and variable name of the visible marker (2nd object).
               if (ObjectFind(ethLabelWithPrice) == 0)                              // This way an existing ETH marker can be found and replaced, even if the dynamic name changes.
                  ObjectDelete(ethLabelWithPrice);
               ObjectDelete(ethLabelWithoutPrice);
            }
            ethLabelWithPrice = ethLabelWithoutPrice +" "+ NumberToStr(ethClose, PriceFormat);

            if (ObjectCreate(ethLabelWithoutPrice, OBJ_LABEL, 0, 0, 0)) {
               ObjectSet    (ethLabelWithoutPrice, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
               ObjectSetText(ethLabelWithoutPrice, ethLabelWithPrice);
               RegisterObject(ethLabelWithoutPrice);
            } else GetLastError();

            if (ObjectCreate(ethLabelWithPrice, OBJ_TREND, 0, Time[ethCenterBar], ethClose, Time[ethCloseBar], ethClose)) {
               ObjectSet    (ethLabelWithPrice, OBJPROP_RAY,   false);
               ObjectSet    (ethLabelWithPrice, OBJPROP_STYLE, STYLE_SOLID);
               ObjectSet    (ethLabelWithPrice, OBJPROP_COLOR, CloseMarker.Color);
               ObjectSet    (ethLabelWithPrice, OBJPROP_BACK,  true);
               RegisterObject(ethLabelWithPrice);
            } else GetLastError();
         }
      }
      break;
   }
   /*
   Example for mixing colors according to gdi32::SetROP2(HDC hdc, R2_NOTXORPEN):
   -----------------------------------------------------------------------------
   What color to assign to a shape to make it appear "Green rgb(0,255,0)" after mixing with chart color rgb(48,248,248) and another shape "rose rgb(255,213,213)"?

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
 * Update the Superbar legend.
 *
 * @return bool - success status
 */
bool UpdateDescription() {
   string description = "";

   switch (superTimeframe) {
      case  PERIOD_M1    : description = "Superbars: 1 Minute";         break;
      case  PERIOD_M5    : description = "Superbars: 5 Minutes";        break;
      case  PERIOD_M15   : description = "Superbars: 15 Minutes";       break;
      case  PERIOD_M30   : description = "Superbars: 30 Minutes";       break;
      case  PERIOD_H1    : description = "Superbars: 1 Hour";           break;
      case  PERIOD_H4    : description = "Superbars: 4 Hours";          break;
      case  PERIOD_D1    : description = "Superbars: Days";             break;
      case  PERIOD_D1_ETH: description = "Superbars: Days + ETH";       break;
      case  PERIOD_W1    : description = "Superbars: Weeks";            break;
      case  PERIOD_MN1   : description = "Superbars: Months";           break;
      case  PERIOD_Q1    : description = "Superbars: Quarters";         break;

      case -PERIOD_M1    : description = "Superbars: 1 Minute (n/a)";   break;
      case -PERIOD_M5    : description = "Superbars: 5 Minutes (n/a)";  break;
      case -PERIOD_M15   : description = "Superbars: 15 Minutes (n/a)"; break;
      case -PERIOD_M30   : description = "Superbars: 30 Minutes (n/a)"; break;
      case -PERIOD_H1    : description = "Superbars: 1 Hour (n/a)";     break;
      case -PERIOD_H4    : description = "Superbars: 4 Hours (n/a)";    break;
      case -PERIOD_D1    : description = "Superbars: Days (n/a)";       break;
      case -PERIOD_D1_ETH: description = "Superbars: Days + ETH (n/a)"; break;
      case -PERIOD_W1    : description = "Superbars: Weeks (n/a)";      break;
      case -PERIOD_MN1   : description = "Superbars: Months (n/a)";     break;
      case -PERIOD_Q1    : description = "Superbars: Quarters (n/a)";   break;

      case  INT_MIN:
      case  INT_MAX:       description = "Superbars: off";              break;   // manually deactivated

      default:             description = "Superbars: n/a";                       // programmatically deactivated
   }
   ObjectSetText(legendLabel, description, legendFontSize, legendFontName, legendFontColor);

   int error = GetLastError();
   if (error && error!=ERR_OBJECT_DOES_NOT_EXIST)                                // on ObjectDrag or opened "Properties" dialog
      return(!catch("UpdateDescription(1)", error));
   return(true);
}


/**
 * Create a text label for the indicator status.
 *
 * @return string - the label or an empty string in case of errors
 */
string CreateStatusLabel() {
   if (IsSuperContext()) return("");

   string label = "rsf."+ ProgramName() +".status["+ __ExecutionContext[EC.pid] +"]";

   if (ObjectFind(label) == 0)
      ObjectDelete(label);

   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER,    legendCorner);
      ObjectSet    (label, OBJPROP_XDISTANCE, legend_xDistance);
      ObjectSet    (label, OBJPROP_YDISTANCE, legend_yDistance);
      ObjectSetText(label, " ", 1);
      RegisterObject(label);
   }

   if (!catch("CreateStatusLabel(1)"))
      return(label);
   return("");
}


/**
 * Store the currently active SuperBars timeframe in the window (for init cycle and new chart templates) and in the chart
 * (for terminal restart).
 *
 * @return bool - success status
 */
bool StoreRuntimeStatus() {
   if (!superTimeframe) return(true);                             // skip on invalid timeframes

   string label = "rsf."+ ProgramName() +".superTimeframe";

   // store timeframe in the window
   int hWnd = __ExecutionContext[EC.hChart];
   SetWindowIntegerA(hWnd, label, superTimeframe);

   // store timeframe in the chart
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ superTimeframe);

   return(catch("StoreRuntimeStatus(1)"));
}


/**
 * Restore the active SuperBars timeframe from the window (preferred) or the chart.
 *
 * @return bool - success status
 */
bool RestoreRuntimeStatus() {
   string label = "rsf."+ ProgramName() +".superTimeframe";

   // look-up a stored timeframe in the window
   int hWnd = __ExecutionContext[EC.hChart];
   int result = RemoveWindowIntegerA(hWnd, label);

   // on error look-up a stored timeframe in the chart
   if (!result) {
      if (ObjectFind(label) == 0) {
         string value = ObjectDescription(label);
         if (StrIsInteger(value))
            result = StrToInteger(value);
         ObjectDelete(label);
      }
   }
   if (result != 0) superTimeframe = result;

   return(!catch("RestoreRuntimeStatus(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("UpBars.Color=",        ColorToStr(UpBars.Color),        ";", NL,
                            "DownBars.Color=",      ColorToStr(DownBars.Color),      ";", NL,
                            "UnchangedBars.Color=", ColorToStr(UnchangedBars.Color), ";", NL,
                            "CloseMarker.Color=",   ColorToStr(CloseMarker.Color),   ";", NL,
                            "ETH.Color=",           ColorToStr(ETH.Color),           ";", NL,
                            "ETH.Symbols=",         DoubleQuoteStr(ETH.Symbols),     ";")
   );
}
