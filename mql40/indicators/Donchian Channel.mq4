/**
 * Donchian Channel
 *
 * The indicator supports manual stepping of the Donchian Channel period via hotkey.
 *
 *
 * Input parameters
 * ----------------
 *  • Periods:            Look-back periods of the Donchian Channel.
 *  • Periods.Step:       Option to control parameter "Period" via keyboard. If non-zero it defines the step size of the
 *                        parameter stepper. If 0 (zero) parameter stepping is disabled.
 *
 *  • Channel.UpperColor: Color of the upper Donchian Channel band.
 *  • Channel.LowerColor: Color of the lower Donchian Channel band.
 *
 *  • ShowReversals:      Whether to display Donchian Channel reversals.
 *  • Reversal.Symbol:    Graphic symbol used for Donchian Channel reversals.
 *  • Reversal.Width:     Size of displayed Donchian Channel reversals.
 *  • Reversal.Color:     Custom color of channel reversals (default: color of channel bands).
 *
 *  • ShowChartLegend:    Whether do display the chart legend.
 *  • MaxBarsBack:        Maximum number of bars back to calculate the indicator for (affects performance).

 *  • AutoConfiguration:  If enabled all input parameters can use predefined defaults from the configuration.
 *
 *
 * Usage with iCustom()
 * --------------------
 * @see /mql40/include/rsf/functions/iCustom/DonchianChannel.mqh
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

///////////////////////////////////////////////////// Input parameters //////////////////////////////////////////////////////

extern int    Periods            = 200;       // look-back period
extern int    Periods.Step       = 0;         // step size for parameter stepping

extern color  Channel.UpperColor = Blue;
extern color  Channel.LowerColor = Red;

extern bool   ShowReversals      = true;      // whether to display channel reversals
extern string Reversal.Symbol    = "dot | thin-ring | ring | thick-ring*";
extern int    Reversal.Width     = 1;
extern color  Reversal.Color     = CLR_NONE;

extern bool   ShowChartLegend    = true;
extern int    MaxBarsBack        = 10000;     // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/HandleCommands.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>

#property indicator_chart_window
#property indicator_buffers 5

// indicator buffer ids
#define MODE_UPPER_BAND    0                 // upper channel band
#define MODE_LOWER_BAND    1                 // lower channel band
#define MODE_UPPER_CROSS   2                 // upper channel band crossings
#define MODE_LOWER_CROSS   3                 // lower channel band crossings
#define MODE_TREND         4                 // int: direction and length of channel reversals

#property indicator_color1 Blue              // upper channel band
#property indicator_style1 STYLE_DOT         //
#property indicator_color2 Red               // lower channel band
#property indicator_style2 STYLE_DOT         //

#property indicator_color3 indicator_color1  // upper channel band crossings
#property indicator_width3 0                 //
#property indicator_color4 indicator_color2  // lower channel band crossings
#property indicator_width4 0                 //


double upperBand [];
double lowerBand [];
double upperCross[];
double lowerCross[];
double trend     [];                         // int: direction and length of channel reversals

string indicatorName = "";
string shortName     = "";
string legendLabel   = "";

int reversalDrawType;
int reversalSymbol;

bool signal.onReversal.sound;
bool signal.onReversal.alert;
bool signal.onReversal.mail;
bool signal.onReversal.telegram;

datetime skipSignals;                        // skip signals until the specified time to wait for possible data pumping
datetime lastTick;


// signal direction types
#define D_LONG  TRADE_DIRECTION_LONG         // 1
#define D_SHORT TRADE_DIRECTION_SHORT        // 2

// parameter stepper directions
#define STEP_UP    1
#define STEP_DOWN -1


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // Periods
   if (AutoConfiguration) Periods = GetConfigInt(indicator, "Periods", Periods);
   if (Periods < 2) return(catch("onInit(1)  invalid input parameter Periods: "+ Periods, ERR_INVALID_INPUT_PARAMETER));
   // Periods.Step
   if (AutoConfiguration) Periods.Step = GetConfigInt(indicator, "Periods.Step", Periods.Step);
   if (Periods.Step < 0) return(catch("onInit(2)  invalid input parameter Periods.Step: "+ Periods.Step +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // Reversal.Symbol
   if (AutoConfiguration) Reversal.Symbol = GetConfigString(indicator, "Reversal.Symbol", Reversal.Symbol);
   string sValues[], sValue = Reversal.Symbol;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (sValue == "dot"       ) reversalSymbol = 108;   // that's Wingding characters
   else if (sValue == "thin-ring" ) reversalSymbol = 161;   // ...
   else if (sValue == "ring"      ) reversalSymbol = 162;   // ...
   else if (sValue == "thick-ring") reversalSymbol = 163;   // ...
   else return(catch("onInit(3)  invalid input parameter Reversal.Symbol: "+ DoubleQuoteStr(Reversal.Symbol), ERR_INVALID_INPUT_PARAMETER));
   Reversal.Symbol = sValue;
   // Reversal.Width
   if (AutoConfiguration) Reversal.Width = GetConfigInt(indicator, "Reversal.Width", Reversal.Width);
   if (Reversal.Width < 0) return(catch("onInit(4)  invalid input parameter Reversal.Width: "+ Reversal.Width, ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Channel.UpperColor = GetConfigColor(indicator, "Channel.UpperColor", Channel.UpperColor);
   if (AutoConfiguration) Channel.LowerColor = GetConfigColor(indicator, "Channel.LowerColor", Channel.LowerColor);
   if (AutoConfiguration) Reversal.Color     = GetConfigColor(indicator, "Reversal.Color",     Reversal.Color);
   if (Channel.UpperColor == 0xFF000000) Channel.UpperColor = CLR_NONE;
   if (Channel.LowerColor == 0xFF000000) Channel.LowerColor = CLR_NONE;
   if (Reversal.Color     == 0xFF000000) Reversal.Color     = CLR_NONE;
   // ShowChartLegend
   if (AutoConfiguration) ShowChartLegend = GetConfigBool(indicator, "ShowChartLegend", ShowChartLegend);
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1) return(catch("onInit(5)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // reset an active command handler
   if (__isChart && Periods.Step) {
      GetChartCommand("ParameterStepper", sValues);
   }
   RestoreStatus();

   // buffer management and display options
   SetIndicatorOptions();
   if (ShowChartLegend) legendLabel = CreateChartLegend();

   // Indicator event "breakout" occurs on tick, not on "bar-open" or "bar-close".
   // We need a chart ticker to prevent invalid signals caused by ticks during data pumping.
   if (!__isTesting && !__virtualTicksTimerId) {
      int hWnd = __ExecutionContext[EC.chart];
      int millis = 2000;                                         // a virtual tick every 2 seconds
      __virtualTicksTimerId = SetupTickTimer(hWnd, millis, NULL);
      if (!__virtualTicksTimerId) return(catch("onInit(6)->SetupTickTimer() failed", ERR_RUNTIME_ERROR));
   }
   return(catch("onInit(7)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   StoreStatus();

   // release the chart ticker
   if (__virtualTicksTimerId > 0) {
      int tmp = __virtualTicksTimerId;
      __virtualTicksTimerId = NULL;
      if (!ReleaseTickTimer(tmp)) return(catch("onDeinit(1)->ReleaseTickTimer(timerId="+ tmp +") failed", ERR_RUNTIME_ERROR));
   }
   return(catch("onDeinit(2)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // process incoming commands (rewrites ValidBars/ChangedBars/ShiftedBars)
   if (__isChart && Periods.Step) {
      if (!HandleCommands("ParameterStepper")) return(last_error);
   }

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(upperBand,  0);
      ArrayInitialize(lowerBand,  0);
      ArrayInitialize(upperCross, 0);
      ArrayInitialize(lowerCross, 0);
      ArrayInitialize(trend,      0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(upperBand,  Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(lowerBand,  Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(upperCross, Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(lowerCross, Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(trend,      Bars, ShiftedBars, 0);
   }

   // check data pumping on every tick so the breakout handler can skip errornous signals
   if (!__isTesting) IsPossibleDataPumping();

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-Periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks +"  Bars="+ Bars +"  needed="+ Periods, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      // reset the bar to update
      upperBand [bar] = 0;
      lowerBand [bar] = 0;
      upperCross[bar] = 0;
      lowerCross[bar] = 0;
      trend     [bar] = 0;

      // recalculate Donchian Channel
      if (bar > 0) {
         upperBand[bar] = High[iHighest(NULL, NULL, MODE_HIGH, Periods, bar)];
         lowerBand[bar] =  Low[ iLowest(NULL, NULL, MODE_LOW,  Periods, bar)];
      }
      else {
         upperBand[0] = MathMax(upperBand[1], High[0]);
         lowerBand[0] = MathMin(lowerBand[1],  Low[0]);
      }

      // recalculate channel crossings
      if (upperBand[bar] > upperBand[bar+1] && upperBand[bar+1]) {
         upperCross[bar] = upperBand[bar+1] + Point;
      }
      if (lowerBand[bar] < lowerBand[bar+1]) {
         lowerCross[bar] = lowerBand[bar+1] - Point;
      }

      // whether the processed bar is a reversal bar (not whether the current tick triggered the reversal)
      bool isReversalBar = false, c1_isReversalBar = false, isUpperCrossLast = false;

      // recalculate trend data
      // if no channel crossing
      if (!upperCross[bar] && !lowerCross[bar]) {
         int iTrend = trend[bar+1];
         trend[bar] = iTrend + Sign(iTrend);                // increase trend if it was set
      }

      // if two channel crossings (upper and lower band crossed by the same bar)
      else if (upperCross[bar] && lowerCross[bar]) {
         isUpperCrossLast = IsUpperCrossLast(bar);
         if (isUpperCrossLast) {
            c1_isReversalBar = ProcessLowerCross(bar);      // process both crossings in order
            isReversalBar    = ProcessUpperCross(bar);
         }
         else {
            c1_isReversalBar = ProcessUpperCross(bar);      // process both crossings in order
            isReversalBar    = ProcessLowerCross(bar);
         }
      }

      // else a single channel crossing
      else if (upperCross[bar] != 0) isReversalBar = ProcessUpperCross(bar);
      else                           isReversalBar = ProcessLowerCross(bar);

      // show/hide reversals: hide all crossings or keep the 1st one
      if (!ShowReversals || !isReversalBar) {
         upperCross[bar] = 0;
         lowerCross[bar] = 0;
      }
      else if (upperCross[bar] && lowerCross[bar]) {        // special handling for the 1st of a double crossing
         if (!c1_isReversalBar) {                           // whether the 1st crossing created a reversal
            if (isUpperCrossLast) lowerCross[bar] = 0;
            else                  upperCross[bar] = 0;
         }
         // always keep the 2nd crossing (it's the final reversal)
      }
   }

   if (__isChart && !__isSuperContext) {
      if (ShowChartLegend) UpdateChartLegend();
   }
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
   if (cmd == "parameter") {
      if (params == "up")   return(ParameterStepper(STEP_UP,   keys));
      if (params == "down") return(ParameterStepper(STEP_DOWN, keys));
   }
   return(!logNotice("onCommand(1)  unsupported command: "+ DoubleQuoteStr(cmd +":"+ params +":"+ keys)));
}


/**
 * Step up/down input parameter "Periods".
 *
 * @param  int direction - STEP_UP | STEP_DOWN
 * @param  int keys      - modifier keys
 *
 * @return bool - success status
 */
bool ParameterStepper(int direction, int keys) {
   if (direction!=STEP_UP && direction!=STEP_DOWN) return(!catch("ParameterStepper(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   int step = Periods.Step;
   if (!step || Periods + direction*step < 2) {       // stop if parameter limit reached
      PlaySoundEx("Plonk.wav");
      return(false);
   }
   if (direction == STEP_UP) Periods += step;
   else                      Periods -= step;

   ChangedBars = Bars;
   ValidBars   = 0;

   PlaySoundEx("Parameter Step.wav");
   return(true);
}


/**
 * Whether the current tick may have occurred during data pumping.
 *
 * @return bool
 */
bool IsPossibleDataPumping() {
   int waitPeriod = 20 * SECONDS;      // TODO: review this seemingly strange implementation
   datetime now = GetGmtTime();
   bool isPumping = true;

   if (now > skipSignals) skipSignals = 0;
   if (!skipSignals) {
      if (now > lastTick + waitPeriod) skipSignals = now + waitPeriod;
      else                             isPumping = false;
   }
   lastTick = now;
   return(isPumping);
}


/**
 * Whether a bar crossing both channel bands crossed the upper band last. The result is just a "best guess".
 *
 * @param  int bar - bar offset
 *
 * @return bool
 */
bool IsUpperCrossLast(int bar) {
   double ho = High [bar] - Open [bar];
   double ol = Open [bar] - Low  [bar];
   double hc = High [bar] - Close[bar];
   double cl = Close[bar] - Low  [bar];

   double minOpen  = MathMin(ho, ol);
   double minClose = MathMin(hc, cl);

   if (minOpen < minClose) {
      return(ho > ol);
   }
   return(hc < cl);
}


/**
 * Update buffers at the specified bar offset after an upper channel band crossing. If bar 0 (zero) crosses the upper band
 * this function will be called for all following ticks of the bar, even for ticks below the crossing level.
 *
 * @param  int bar - offset
 *
 * @return bool - whether the bar is a reversal bar (not whether the current tick triggered the reversal)
 */
bool ProcessUpperCross(int bar) {
   bool isReversalBar = false;

   if (!trend[bar]) {                     // 1st channel crossing
      if (trend[bar+1] > 0) {
         int iTrend = trend[bar+1];
         trend[bar] = iTrend + 1;
      }
      else /*trend[bar+1] <= 0*/ {
         trend[bar] = 1;
         isReversalBar = true;
      }
   }
   else {                                 // 2nd channel crossing
      if (trend[bar] > 0) return(!catch("ProcessUpperCross(1)  bar="+ bar +"|"+ TimeToStr(Time[bar]) +"  unexpected 2nd upper cross: trend["+ (bar+1) +"]="+ _int(trend[bar+1]) +"  trend["+ bar +"]="+ _int(trend[bar]), ERR_ILLEGAL_STATE));
      trend[bar] = 1;
      isReversalBar = true;
   }
   return(isReversalBar);
}


/**
 * Update buffers at the specified bar offset after a lower channel band crossing. If bar 0 (zero) crosses the lower band
 * this function will be called for all following ticks of the bar, even for ticks above the crossing level.
 *
 * @param  int bar - offset
 *
 * @return bool - whether the bar is a reversal bar (not whether the current tick triggered the reversal)
 */
bool ProcessLowerCross(int bar) {
   bool isReversalBar = false;

   if (!trend[bar]) {                     // 1st channel crossing
      if (trend[bar+1] < 0) {
         int iTrend = trend[bar+1];
         trend[bar] = iTrend - 1;
      }
      else /*trend[bar+1] >= 0*/ {
         trend[bar] = -1;
         isReversalBar = true;
      }
   }
   else {                                 // 2nd channel crossing
      if (trend[bar] < 0) return(!catch("ProcessLowerCross(1)  bar="+ bar +"|"+ TimeToStr(Time[bar]) +"  unexpected 2nd lower cross: trend["+ (bar+1) +"]="+ _int(trend[bar+1]) +"  trend["+ bar +"]="+ _int(trend[bar]), ERR_ILLEGAL_STATE));
      trend[bar] = -1;
      isReversalBar = true;
   }
   return(isReversalBar);
}


/**
 * Update the chart legend.
 */
void UpdateChartLegend() {
   //static int lastZzCombined, lastTime, lastAccount;
   //
   //// update on full recalculation or if indicator name, trend, current bar or the account changed
   //if (!ValidBars || zzCombined[0]!=lastZzCombined || Time[0]!=lastTime || AccountNumber()!=lastAccount) {
   //   string sTrend    = "   "+ NumberToStr(zzTrend[0], "+.");
   //   string sUnknown  = ifString(!zzUnknownTrend[0], "", "/"+ zzUnknownTrend[0]);
   //   string sReversal = "   next reversal @" + NumberToStr(ifDouble(zzTrend[0] < 0, upperBand[0]+Point, lowerBand[0]-Point), PriceFormat);
   //   string sSignal   = ifString(Signal.onReversal || Sound.onChannelWidening, "  "+ legendInfo, "");
   //   string text      = StringConcatenate(indicatorName, sTrend, sUnknown, sReversal, sSignal);
   //
   //   color clr = ZigZag.Color;
   //   if      (clr == Aqua        ) clr = DodgerBlue;
   //   else if (clr == Gold        ) clr = Orange;
   //   else if (clr == LightSkyBlue) clr = C'94,174,255';
   //   else if (clr == Lime        ) clr = LimeGreen;
   //   else if (clr == Yellow      ) clr = Orange;
   //
   //   ObjectSetText(legendLabel, text, 9, "Arial Fett", clr);
   //   int error = GetLastError();
   //   if (error && error!=ERR_OBJECT_DOES_NOT_EXIST) catch("UpdateChartLegend(1)", error);     // on ObjectDrag or opened "Properties" dialog
   //
   //   lastZzCombined = zzCombined[0];
   //   lastTime       = Time[0];
   //   lastAccount    = AccountNumber();
   //}
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

   indicatorName = WindowExpertName() +"("+ Periods + ifString(Periods.Step, ":"+ Periods.Step, "") +")";
   shortName     = "Donchian("+ Periods +")";
   IndicatorShortName(shortName);

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(MODE_UPPER_BAND,  upperBand ); SetIndexEmptyValue(MODE_UPPER_BAND,  0); SetIndexLabel(MODE_UPPER_BAND,  shortName +" upper band");
   SetIndexBuffer(MODE_LOWER_BAND,  lowerBand ); SetIndexEmptyValue(MODE_LOWER_BAND,  0); SetIndexLabel(MODE_LOWER_BAND,  shortName +" lower band");
   SetIndexBuffer(MODE_UPPER_CROSS, upperCross); SetIndexEmptyValue(MODE_UPPER_CROSS, 0); SetIndexLabel(MODE_UPPER_CROSS, shortName +" extension up");   if (!reversalDrawType) SetIndexLabel(MODE_UPPER_CROSS, NULL);
   SetIndexBuffer(MODE_LOWER_CROSS, lowerCross); SetIndexEmptyValue(MODE_LOWER_CROSS, 0); SetIndexLabel(MODE_LOWER_CROSS, shortName +" extension down"); if (!reversalDrawType) SetIndexLabel(MODE_LOWER_CROSS, NULL);
   SetIndexBuffer(MODE_TREND,       trend     ); SetIndexEmptyValue(MODE_TREND,       0); SetIndexLabel(MODE_TREND,       shortName +" trend");
   IndicatorDigits(Digits);

   SetIndexStyle(MODE_UPPER_BAND, DRAW_LINE, EMPTY, EMPTY, Channel.UpperColor);
   SetIndexStyle(MODE_LOWER_BAND, DRAW_LINE, EMPTY, EMPTY, Channel.LowerColor);

   int drawType = ifInt(ShowReversals && Reversal.Width, DRAW_ARROW, DRAW_NONE);
   SetIndexStyle(MODE_UPPER_CROSS, drawType, EMPTY, Reversal.Width, colorOr(Reversal.Color, Channel.UpperColor)); SetIndexArrow(MODE_UPPER_CROSS, reversalSymbol);
   SetIndexStyle(MODE_LOWER_CROSS, drawType, EMPTY, Reversal.Width, colorOr(Reversal.Color, Channel.LowerColor)); SetIndexArrow(MODE_LOWER_CROSS, reversalSymbol);

   SetIndexStyle(MODE_TREND, DRAW_NONE);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Store the status of the parameter stepper in the chart (for init cyles, template reloads and terminal restarts).
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (__isChart && Periods.Step) {
      string prefix = "rsf."+ WindowExpertName() +".";
      Chart.StoreInt(prefix +"Periods", Periods);
   }
   return(catch("StoreStatus(1)"));
}


/**
 * Restore the status of the parameter stepper from the chart.
 *
 * @return bool - success status
 */
bool RestoreStatus() {
   if (!__isChart) return(true);
   string prefix = "rsf."+ WindowExpertName() +".";

   int iValue;
   if (Chart.RestoreInt(prefix +"Periods", iValue)) {    // restore and remove it
      if (Periods.Step > 0) {                            // apply if stepper is still active
         if (iValue >= 2) Periods = iValue;              // silent validation
      }
   }
   return(!catch("RestoreStatus(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Periods=",            Periods,                         ";", NL,
                            "Periods.Step=",       Periods.Step,                    ";", NL,

                            "Channel.UpperColor=", ColorToStr(Channel.UpperColor),  ";", NL,
                            "Channel.LowerColor=", ColorToStr(Channel.LowerColor),  ";", NL,

                            "ShowReversals=",      BoolToStr(ShowReversals),        ";", NL,
                            "Reversal.Symbol=",    DoubleQuoteStr(Reversal.Symbol), ";", NL,
                            "Reversal.Width=",     Reversal.Width,                  ";", NL,
                            "Reversal.Color=",     ColorToStr(Reversal.Color),      ";", NL,

                            "ShowChartLegend=",    BoolToStr(ShowChartLegend),      ";", NL,
                            "MaxBarsBack=",        MaxBarsBack,                     ";")
   );
}
