/**
 * Donchian Channel
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

///////////////////////////////////////////////////// Input parameters //////////////////////////////////////////////////////

extern int   Periods         = 20;        // lookback period
extern color ChannelColor    = Blue;

extern bool  ShowChartLegend = true;
extern int   MaxBarsBack     = 10000;     // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>

#property indicator_chart_window
#property indicator_buffers   2

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_width1    2
#property indicator_width2    2

double upperBand[];
double lowerBand[];

#define MODE_UPPER_BAND       0           // indicator buffer ids
#define MODE_LOWER_BAND       1           //

string indicatorName = "";
string shortName     = "";
string legendLabel   = "";


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
   if (Periods < 2)      return(catch("onInit(1)  invalid input parameter Periods: "+ Periods, ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) ChannelColor = GetConfigColor(indicator, "ChannelColor", ChannelColor);
   if (ChannelColor == 0xFF000000) ChannelColor = CLR_NONE;
   // ShowChartLegend
   if (AutoConfiguration) ShowChartLegend = GetConfigBool(indicator, "ShowChartLegend", ShowChartLegend);
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1) return(catch("onInit(2)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // buffer management and display options
   SetIndicatorOptions();
   if (ShowChartLegend) legendLabel = CreateChartLegend();

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
      ArrayInitialize(upperBand, 0);
      ArrayInitialize(lowerBand, 0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(upperBand, Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(lowerBand, Bars, ShiftedBars, 0);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-Periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks +"  Bars="+ Bars +"  needed="+ Periods, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   if (startbar > 2) {
      upperBand[startbar] = 0;
      lowerBand[startbar] = 0;
   }
   for (int bar=startbar; bar >= 0; bar--) {
      if (bar > 0) {
         upperBand[bar] = High[iHighest(NULL, NULL, MODE_HIGH, Periods, bar)];
         lowerBand[bar] =  Low[ iLowest(NULL, NULL, MODE_LOW,  Periods, bar)];
      }
      else {
         upperBand[0] = MathMax(upperBand[1], High[0]);
         lowerBand[0] = MathMin(lowerBand[1],  Low[0]);
      }
   }

   if (__isChart && !__isSuperContext) {
      if (ShowChartLegend) UpdateBandLegend(legendLabel, indicatorName, "", ChannelColor, upperBand[0], lowerBand[0]);
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

   indicatorName = ProgramName() +"("+ Periods +")";
   shortName     = "Donchian("+ Periods +")";
   IndicatorShortName(shortName);

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(MODE_UPPER_BAND, upperBand); SetIndexEmptyValue(MODE_UPPER_BAND, 0); SetIndexLabel(MODE_UPPER_BAND, shortName +" upper");
   SetIndexBuffer(MODE_LOWER_BAND, lowerBand); SetIndexEmptyValue(MODE_LOWER_BAND, 0); SetIndexLabel(MODE_LOWER_BAND, shortName +" lower");
   IndicatorDigits(Digits);

   SetIndexStyle(MODE_UPPER_BAND, DRAW_LINE, EMPTY, EMPTY, ChannelColor);
   SetIndexStyle(MODE_LOWER_BAND, DRAW_LINE, EMPTY, EMPTY, ChannelColor);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Periods=",         Periods,                    ";", NL,
                            "ChannelColor=",    ColorToStr(ChannelColor),   ";", NL,
                            "ShowChartLegend=", BoolToStr(ShowChartLegend), ";", NL,
                            "MaxBarsBack=",     MaxBarsBack,                ";")
   );
}
