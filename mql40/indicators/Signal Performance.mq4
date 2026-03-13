/**
 * Signal Performance
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int MaxBarsBack = 10000;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>

#property indicator_separate_window
#property indicator_buffers  1
#property indicator_color1   Blue

// indicator buffer ids
#define MODE_MAIN            0

double main[];


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1) return(catch("onInit(1)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   SetIndicatorOptions();
   return(catch("onInit(2)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(main, 0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(main, Bars, ShiftedBars, 0);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1);

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      main[bar] = Close[bar]/pUnit;
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

   string indicatorName = WindowExpertName();
   IndicatorShortName(indicatorName);

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(MODE_MAIN, main); SetIndexEmptyValue(MODE_MAIN, 0);
   IndicatorDigits(pDigits);

   SetIndexStyle(MODE_MAIN, DRAW_LINE, EMPTY, EMPTY, indicator_color1);
   SetIndexLabel(MODE_MAIN, indicatorName);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MaxBarsBack=", MaxBarsBack, ";"));
}
