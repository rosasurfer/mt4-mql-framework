/**
 * SuperBars
 *
 * Draws rectangles of higher timeframe bars or trading sessions on the chart. The active higher timeframe can be changed by
 * executing the scripts "SuperBars.TimeframeUp" and "SuperBars.TimeframeDown".
 *
 * With input parameter "AutoConfiguration" enabled (default) inputs found in the framework configuration override manual
 * inputs. Additional framework config settings without manual inputs:
 *
 * [SuperBars]
 *  Legend.Corner                = {int}              ; CORNER_TOP_LEFT* | CORNER_TOP_RIGHT | CORNER_BOTTOM_LEFT | CORNER_BOTTOM_RIGHT
 *  Legend.xDistance             = {int}              ; offset in pixels
 *  Legend.yDistance             = {int}              ; offset in pixels
 *  Legend.FontName              = {string}           ; font name
 *  Legend.FontSize              = {int}              ; font size
 *  Legend.FontColor             = {color}            ; font color (web color name, integer or RGB triplet)
 *  UnchangedBars.MaxPriceChange = {double}           ; max. close change of a bar in percent to be drawn as "unchanged"
 *  MaxBars.H1                   = {int}              ; max. number of H1 superbars to draw (default: all available)
 *  ErrorSound                   = {string}           ; cycling sound if no higher/lower timeframe is available (default: none)
 *
 * @see  https://www.forexfactory.com/thread/1078323-superbars-higher-timeframe-bars-with-cme-session-support
 *
 * TODO:
 *  - implement more super timeframes and rewrite configuration of max. bars
 *  - SuperBar close markers in variable period charts (e.g. range bars) are incorrect
 *  - workaround for odd period start times on BTCUSD (everything > PERIOD_M5, ETH sessions)
 *  - ETH/RTH separation for Frankfurt session
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern color  UpBars.Color        = PaleGreen;        // bullish bars
extern color  DownBars.Color      = Pink;             // bearish bars
extern color  UnchangedBars.Color = Lavender;         // unchanged bars
extern color  CloseMarker.Color   = Gray;             // bar close marker
extern color  ETH.Color           = LemonChiffon;     // ETH sessions
extern string ETH.Symbols         = "";               // comma-separated list of symbols with RTH/ETH sessions
extern string Weekend.Symbols     = "";               // comma-separated list of symbols with weekend data

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/iBarShiftNext.mqh>
#include <functions/iBarShiftPrevious.mqh>
#include <functions/iChangedBars.mqh>
#include <functions/iPreviousPeriod.mqh>
#include <win32api.mqh>

#property indicator_chart_window

#define STF_UP             1
#define STF_DOWN          -1
#define PERIOD_D1_ETH   1439                          // that's PERIOD_D1 - 1

int      superTimeframe;                              // the currently active super bar period
double   maxChangeUnchanged = 0.05;                   // max. price change in % for a SuperBar to be drawn as unchanged
bool     ethEnabled;                                  // whether CME sessions are enabled
bool     weekendEnabled;                              // whether weekend data is enabled
datetime serverTime;                                  // most recent server time
int      maxBarsH1;                                   // max. number of H1 superbars to draw (performance)

string   legendLabel      = "";
int      legendCorner     = CORNER_TOP_LEFT;
int      legend_xDistance = 300;
int      legend_yDistance = 3;
string   legendFontName   = "";                       // default: empty = menu font ("MS Sans Serif")
int      legendFontSize   = 8;                        // "MS Sans Serif", size 8 corresponds matches the menu font/size
color    legendFontColor  = Black;

string   errorSound = "";                             // sound played when timeframe cycling is at min/max (default: none)


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = ProgramName();

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
   string sValue = StrTrim(ETH.Symbols), symbol=Symbol(), stdSymbol=StdSymbol(), sValues[];
   if (AutoConfiguration) sValue = GetConfigString(indicator, "ETH.Symbols", sValue);
   if (StringLen(sValue) > 0) {
      int size = Explode(StrToLower(sValue), ",", sValues, NULL);
      for (int i=0; i < size; i++) {
         sValues[i] = StrTrim(sValues[i]);
      }
      ethEnabled = (StringInArrayI(sValues, symbol) || StringInArrayI(sValues, stdSymbol));
   }
   // Weekend.Symbols
   sValue = StrTrim(Weekend.Symbols);
   if (AutoConfiguration) sValue = GetConfigString(indicator, "Weekend.Symbols", sValue);
   if (StringLen(sValue) > 0) {
      size = Explode(StrToLower(sValue), ",", sValues, NULL);
      for (i=0; i < size; i++) {
         sValues[i] = StrTrim(sValues[i]);
      }
      weekendEnabled = (StringInArrayI(sValues, symbol) || StringInArrayI(sValues, stdSymbol));
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
   legendLabel = CreateStatusLabel();

   // restore a stored runtime status
   if (!RestoreStatus()) return(last_error);

   CheckTimeframeAvailability();
   return(catch("onInit(1)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   if (!StoreStatus())                                   // store runtime status in all deinit scenarios
      return(last_error);
   return(NO_ERROR);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   serverTime = TimeServer("onTick(1)", true);
   if (!serverTime) return(ERR_RUNTIME_ERROR);

   HandleCommands();                                     // process incoming commands
   UpdateSuperBars();                                    // update superbars
   return(last_error);
}


/**
 * Process an incoming command.
 *
 * @param  string cmd    - command name
 * @param  string params - command parameters
 * @param  int    keys   - combination of pressed modifier keys
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
 * Change the currently active superbars timeframe.
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
 * Checks whether the selected SuperBar period can be displayed and disables superbars for the current chart period if this
 * is not the case (e.g. SuperBar period H1 can't be displayed on an H4 chart).
 *
 * @return bool - success status
 */
bool CheckTimeframeAvailability() {
   int currentTimeframe = Period();

   // handle offline charts with non-standard bar periods where we can't rely on the value of Period()
   if (IsCustomTimeframe(currentTimeframe)) {
      int customTimeframe = MathRound(MathMin(Time[0]-Time[1], Time[1]-Time[2])/MINUTES);
      currentTimeframe = intOr(customTimeframe, PERIOD_M1);
   }

   switch (superTimeframe) {
      // off: to be activated manually only
      case  INT_MIN:
      case  INT_MAX: break;

      // positive value = active: automatically deactivated if display on the current chart doesn't make sense
      case  PERIOD_H1:  if (currentTimeframe > PERIOD_M15)  superTimeframe *= -1; break;
      case  PERIOD_D1_ETH:
         if (!ethEnabled) superTimeframe = PERIOD_D1;
      case  PERIOD_D1:  if (currentTimeframe > PERIOD_H4)   superTimeframe *= -1; break;
      case  PERIOD_W1:  if (currentTimeframe > PERIOD_D1)   superTimeframe *= -1; break;
      case  PERIOD_MN1: if (currentTimeframe > PERIOD_D1)   superTimeframe *= -1; break;
      case  PERIOD_Q1:  if (currentTimeframe > PERIOD_W1)   superTimeframe *= -1; break;

      // negative value = inactive: automatically activated if display on the current chart makes sense
      case -PERIOD_H1:  if (currentTimeframe <= PERIOD_M15) superTimeframe *= -1; break;
      case -PERIOD_D1_ETH:
         if (!ethEnabled) superTimeframe = -PERIOD_H1;
      case -PERIOD_D1:  if (currentTimeframe <= PERIOD_H4)  superTimeframe *= -1; break;
      case -PERIOD_W1:  if (currentTimeframe <= PERIOD_D1)  superTimeframe *= -1; break;
      case -PERIOD_MN1: if (currentTimeframe <= PERIOD_D1)  superTimeframe *= -1; break;
      case -PERIOD_Q1:  if (currentTimeframe <= PERIOD_W1)  superTimeframe *= -1; break;

      // not initialized or invalid value: reset to default value
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
 * Update the displayed superbars.
 *
 * @return bool - success status
 */
bool UpdateSuperBars() {
   // on change of the supertimeframe delete superbars of the previously active timeframe
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

   // With enabled ETH sessions the range of ChangedBars must also include the range of iChangedBars(PERIOD_M15).
   int  changedBars=ChangedBars, localSuperTimeframe=superTimeframe;
   bool drawETH;
   if (isTimeframeChange)
      changedBars = Bars;                                            // on isTimeframeChange mark all bars as changed

   if (ethEnabled && superTimeframe==PERIOD_D1_ETH) {
      localSuperTimeframe = PERIOD_D1;                               // for iPreviousPeriod() which bails on non-standard timeframes
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
   // - Update range is var "changedBars" from young to old.
   // - The youngest and still unfinished SuperBar is limited to the right by Bar[0] and grows with time.
   // - The oldest SuperBar to update exceedes var "changedBars" to the left if Bars > changedBars (the regular case).
   // - "Super session" means the SuperBar period.
   datetime openTimeFxt=NULL, closeTimeFxt, openTimeSrv, closeTimeSrv;
   int openBar, closeBar, lastChartBar=Bars-1;

   // loop over all superbars from young to old
   for (int i=0; i < maxBars; i++) {
      // get start/end times of every previous timeframe period, starting with the current unfinshed one
      if (!iPreviousPeriod(localSuperTimeframe, openTimeFxt, closeTimeFxt, openTimeSrv, closeTimeSrv, !weekendEnabled)) return(false);

      // In periods >= PERIOD_D1 rate times are set to full days only which yields incorrect bar times in non-FXT timezones. The incorrect timestamp shifts the start of
      // such a period wrongly to the previous/next period. Must be fixed if start of the period falls on a trading day (no need for fixing on a weekend/non-trading day).
      if (Period() >= PERIOD_D1 && superTimeframe >= PERIOD_MN1) {
         if (openTimeSrv  < openTimeFxt ) /*&&*/ if (TimeDayOfWeekEx(openTimeSrv )!=SUNDAY  ) openTimeSrv  = openTimeFxt;     // Sunday bar:   server timezone west of FXT
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
      if (openBar >= changedBars-1) break;                                 // only update the range of var "changedBars"
   }

   lastSuperTimeframe = superTimeframe;
   return(true);
}


/**
 * Draw a single SuperBar.
 *
 * @param  _In_    int      openBar     - chart bar offset of the SuperBar's open bar
 * @param  _In_    int      closeBar    - chart bar offset of the SuperBar's close bar
 * @param  _In_    datetime openTimeFxt - super period starttime in FXT
 * @param  _In_    datetime openTimeSrv - super period starttime in server time
 * @param  _InOut_ bool     &drawETH    - Whether the ETH period of a D1 SuperBar can be drawn. Switches to FALSE once all
 *                                        available M15 data is processed, irrespective of further D1 SuperBars.
 * @return bool - success status
 */
bool DrawSuperBar(int openBar, int closeBar, datetime openTimeFxt, datetime openTimeSrv, bool &drawETH) {
   // resolve High and Low offset
   int highBar = iHighest(NULL, NULL, MODE_HIGH, openBar-closeBar+1, closeBar);
   int lowBar  = iLowest (NULL, NULL, MODE_LOW , openBar-closeBar+1, closeBar);

   // resolve bar color
   color barColor = UnchangedBars.Color;
   if (openBar < Bars-1) double openPrice = Close[openBar+1];        // use previous Close as Open if available
   else                         openPrice = Open [openBar];
   double ratio = openPrice/Close[closeBar]; if (ratio < 1) ratio = 1/ratio;
   ratio = 100 * (ratio-1);
   if (ratio > maxChangeUnchanged) {                                 // a change smaller is considered "unchanged"
      if      (openPrice < Close[closeBar]) barColor = UpBars.Color;
      else if (openPrice > Close[closeBar]) barColor = DownBars.Color;
   }

   // Each SuperBar consists of 3 objects: an OBJ_RECTANGLE representing the SuperBar body, an OBJ_TREND line with the close
   // price in the tooltip representing the SuperBar's close, and an OBJ_LABEL holding a reference to the close marker. On data
   // pumping an already drawed SuperBar and/or it's close price may change. With the reference in the label the close marker
   // can be found and updated without iterating over all chart objects.
   string nameRectangle="", nameRectangleBg="", nameTrendline="", nameOldTrendline="", nameLabel="";

   // define object names
   switch (superTimeframe) {
      case PERIOD_H1    : nameRectangle =          GmtTimeFormat(openTimeFxt, "%d.%m.%Y %H:%M");                   break;
      case PERIOD_D1_ETH:
      case PERIOD_D1    : nameRectangle =          GmtTimeFormat(openTimeFxt, "%a %d.%m.%Y ");                     break;  // plus an extra space as "%a %d.%m.%Y" is already used by the Grid indicator
      case PERIOD_W1    : nameRectangle = "Week "+ GmtTimeFormat(openTimeFxt,    "%d.%m.%Y");                      break;
      case PERIOD_MN1   : nameRectangle =          GmtTimeFormat(openTimeFxt,       "%B %Y");                      break;
      case PERIOD_Q1    : nameRectangle = ((TimeMonth(openTimeFxt)-1)/3+1) +". Quarter "+ TimeYearEx(openTimeFxt); break;
   }

   // draw SuperBar body
   int adjustedCloseBar = closeBar;
   if (closeBar > 0) {                                                           // check for consecutive bars and widen rectangles to the right to make bars touch each other
      if (Time[closeBar] + Period()*MINUTES >= Time[closeBar-1]) {
         adjustedCloseBar--;
      }
   }
   if (ObjectFind(nameRectangle) == -1) if (!ObjectCreateRegister(nameRectangle, OBJ_RECTANGLE, 0, 0, 0, 0, 0, 0, 0)) return(false);
   ObjectSet(nameRectangle, OBJPROP_COLOR,  barColor);
   ObjectSet(nameRectangle, OBJPROP_BACK,   true);
   ObjectSet(nameRectangle, OBJPROP_TIME1,  Time[openBar]);
   ObjectSet(nameRectangle, OBJPROP_PRICE1, High[highBar]);
   ObjectSet(nameRectangle, OBJPROP_TIME2,  Time[adjustedCloseBar]);
   ObjectSet(nameRectangle, OBJPROP_PRICE2, Low[lowBar]);

   // draw SuperBar close marker and referencing label
   if (closeBar > 0) {                                                           // except for the youngest (still unfinished) SuperBar
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

         if (ObjectFind(nameLabel) == -1) if (!ObjectCreateRegister(nameLabel, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
         ObjectSet    (nameLabel, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
         ObjectSetText(nameLabel, nameTrendline);

         if (ObjectFind(nameTrendline) == -1) if (!ObjectCreateRegister(nameTrendline, OBJ_TREND, 0, 0, 0, 0, 0, 0, 0)) return(false);
         ObjectSet(nameTrendline, OBJPROP_RAY,    false);
         ObjectSet(nameTrendline, OBJPROP_STYLE,  STYLE_SOLID);
         ObjectSet(nameTrendline, OBJPROP_COLOR,  CloseMarker.Color);
         ObjectSet(nameTrendline, OBJPROP_BACK,   true);
         ObjectSet(nameTrendline, OBJPROP_TIME1,  Time[centerBar]);
         ObjectSet(nameTrendline, OBJPROP_PRICE1, Close[closeBar]);
         ObjectSet(nameTrendline, OBJPROP_TIME2,  Time[closeBar]);
         ObjectSet(nameTrendline, OBJPROP_PRICE2, Close[closeBar]);
      }
   }

   // for D1 draw the ETH session if M15 data is available
   while (drawETH) {                                                             // the loop declares just a block which can be more easily left via "break"
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
         if (ethM15closeBar == EMPTY_VALUE)    return(false);
         if (ethM15closeBar == -1) { drawETH = false; break; }                   // available data is enough, stop drawing of further ETH sessions
         if (ethM15openBar < ethM15closeBar) break;                              // available data contains a gap

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
      if (ObjectFind(nameRectangleBg) == -1) if (!ObjectCreateRegister(nameRectangleBg, OBJ_RECTANGLE, 0, 0, 0, 0, 0, 0, 0)) return(false);
      ObjectSet(nameRectangleBg, OBJPROP_COLOR,  barColor);                      // Colors of overlapping shapes are mixed with the chart background color according to gdi32::SetROP2(HDC hdc, R2_NOTXORPEN),
      ObjectSet(nameRectangleBg, OBJPROP_BACK,   true);                          // see example at function end. As MQL4 can't read the chart background color we use a trick: A color mixed with itself gives
      ObjectSet(nameRectangleBg, OBJPROP_TIME1,  Time[ethOpenBar]);              // White. White mixed with another color gives again the original color. With this we create an "optical hole" in the color
      ObjectSet(nameRectangleBg, OBJPROP_PRICE1, ethHigh);                       // of the chart background in the SuperBar. Then we draw the ETH bar into this "hole". It's color doesn't get mixed with the
      ObjectSet(nameRectangleBg, OBJPROP_TIME2,  Time[ethCloseBar]);             // hole's color. Presumably because the terminal uses a different drawing mode for this mixing.
      ObjectSet(nameRectangleBg, OBJPROP_PRICE2, ethLow);

      // draw ETH bar (fills the hole with the ETH color)
      if (ObjectFind(nameRectangle) == -1)
         if (!ObjectCreateRegister(nameRectangle, OBJ_RECTANGLE, 0, 0, 0, 0, 0, 0, 0)) return(false);
      ObjectSet(nameRectangle, OBJPROP_COLOR,  ETH.Color);
      ObjectSet(nameRectangle, OBJPROP_BACK,   true);
      ObjectSet(nameRectangle, OBJPROP_TIME1,  Time[ethOpenBar]);
      ObjectSet(nameRectangle, OBJPROP_PRICE1, ethHigh);
      ObjectSet(nameRectangle, OBJPROP_TIME2,  Time[ethCloseBar]);
      ObjectSet(nameRectangle, OBJPROP_PRICE2, ethLow);

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

            if (ObjectFind(nameLabel) == -1) if (!ObjectCreateRegister(nameLabel, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
            ObjectSet    (nameLabel, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
            ObjectSetText(nameLabel, nameTrendline);

            if (ObjectFind(nameTrendline) == -1) if (!ObjectCreateRegister(nameTrendline, OBJ_TREND, 0, 0, 0, 0, 0, 0, 0)) return(false);
            ObjectSet(nameTrendline, OBJPROP_RAY,    false);
            ObjectSet(nameTrendline, OBJPROP_STYLE,  STYLE_SOLID);
            ObjectSet(nameTrendline, OBJPROP_COLOR,  CloseMarker.Color);
            ObjectSet(nameTrendline, OBJPROP_BACK,   true);
            ObjectSet(nameTrendline, OBJPROP_TIME1,  Time[ethCenterBar]);
            ObjectSet(nameTrendline, OBJPROP_PRICE1, ethClose);
            ObjectSet(nameTrendline, OBJPROP_TIME2,  Time[ethCloseBar]);
            ObjectSet(nameTrendline, OBJPROP_PRICE2, ethClose);
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
 * @return string - the label name or an empty string in case of errors
 */
string CreateStatusLabel() {
   if (__isSuperContext) return("");

   string name = "rsf."+ ProgramName() +".status["+ __ExecutionContext[EC.pid] +"]";

   if (ObjectFind(name) == -1) if (!ObjectCreateRegister(name, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return("");
   ObjectSet    (name, OBJPROP_CORNER,    legendCorner);
   ObjectSet    (name, OBJPROP_XDISTANCE, legend_xDistance);
   ObjectSet    (name, OBJPROP_YDISTANCE, legend_yDistance);
   ObjectSetText(name, " ", 1);

   if (!catch("CreateStatusLabel(1)"))
      return(name);
   return("");
}


/**
 * Store the currently active SuperBars timeframe in the window (for init cycle and new chart templates) and in the chart
 * (for terminal restart).
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (!__isChart || !superTimeframe) return(true);                              // skip on invalid timeframes

   string label = "rsf."+ ProgramName() +".superTimeframe";

   // store timeframe in the window
   int hWnd = __ExecutionContext[EC.hChart];
   SetWindowIntegerA(hWnd, label, superTimeframe);

   // store timeframe in the chart
   if (ObjectFind(label) == -1) ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ superTimeframe);

   return(catch("StoreStatus(1)"));
}


/**
 * Restore the active SuperBars timeframe from the window (preferred) or the chart.
 *
 * @return bool - success status
 */
bool RestoreStatus() {
   if (!__isChart) return(true);

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
      }
   }
   if (result != 0) superTimeframe = result;

   return(!catch("RestoreStatus(1)"));
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
                            "ETH.Symbols=",         DoubleQuoteStr(ETH.Symbols),     ";", NL,
                            "Weekend.Symbols=",     DoubleQuoteStr(Weekend.Symbols), ";")
   );
}
