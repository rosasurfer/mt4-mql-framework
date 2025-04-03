/**
 * Donchian Channel Width
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int   Donchian.Periods = 20;          // Donchian Channel periods
extern color LineColor        = Blue;
extern int   MaxBarsBack      = 10000;       // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>

#define MODE_MAIN             0              // indicator buffer ids

#property indicator_separate_window
#property indicator_buffers   1
int       terminal_buffers =  3;

#property indicator_color1    CLR_NONE

double main     [];
double upperBand[];
double lowerBand[];

#define MODE_MAIN             0              // indicator buffer ids
#define MODE_UPPER_BAND       1              //
#define MODE_LOWER_BAND       2              //

string indicatorName = "";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // Periods
   if (AutoConfiguration) Donchian.Periods = GetConfigInt(indicator, "Donchian.Periods", Donchian.Periods);
   if (Donchian.Periods < 2) return(catch("onInit(1)  invalid input parameter Donchian.Periods: "+ Donchian.Periods, ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) LineColor = GetConfigColor(indicator, "LineColor", LineColor);
   if (LineColor == 0xFF000000) LineColor = CLR_NONE;
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)     return(catch("onInit(2)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // buffer management and display options
   SetIndicatorOptions();

   return(catch("onInit(3)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(main,      0);
      ArrayInitialize(upperBand, 0);
      ArrayInitialize(lowerBand, 0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(main,      Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(upperBand, Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(lowerBand, Bars, ShiftedBars, 0);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-Donchian.Periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks +"  Bars="+ Bars +"  needed="+ Donchian.Periods, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   if (startbar > 2) {
      upperBand[startbar] = 0;
      lowerBand[startbar] = 0;
   }
   for (int bar=startbar; bar >= 0; bar--) {
      if (bar > 0) {
         upperBand[bar] = High[iHighest(NULL, NULL, MODE_HIGH, Donchian.Periods, bar)];
         lowerBand[bar] =  Low[ iLowest(NULL, NULL, MODE_LOW,  Donchian.Periods, bar)];
      }
      else {
         upperBand[0] = MathMax(upperBand[1], High[0]);
         lowerBand[0] = MathMin(lowerBand[1],  Low[0]);
      }
      main[bar] = (upperBand[bar] - lowerBand[bar])/pUnit;
   }
   return(last_error);
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

   indicatorName = "Donchian Channel("+ Donchian.Periods +") Width";
   IndicatorShortName(indicatorName);

   IndicatorBuffers(terminal_buffers);
   SetIndexBuffer(MODE_MAIN,       main     ); SetIndexEmptyValue(MODE_MAIN,       0);
   SetIndexBuffer(MODE_UPPER_BAND, upperBand); SetIndexEmptyValue(MODE_UPPER_BAND, 0);
   SetIndexBuffer(MODE_LOWER_BAND, lowerBand); SetIndexEmptyValue(MODE_LOWER_BAND, 0);
   IndicatorDigits(pDigits);

   SetIndexStyle(MODE_MAIN, DRAW_LINE, EMPTY, EMPTY, LineColor);
   SetIndexLabel(MODE_MAIN, "Donchian("+ Donchian.Periods +") Width");

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Donchian.Periods=", Donchian.Periods,      ";", NL,
                            "LineColor=",        ColorToStr(LineColor), ";", NL,
                            "MaxBarsBack=",      MaxBarsBack,           ";")
   );
}
