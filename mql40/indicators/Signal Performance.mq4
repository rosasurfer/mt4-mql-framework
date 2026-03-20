/**
 * Signal Performance
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int ZigZag.Periods = 50;
extern int MaxBarsBack    = 10000;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/iCustom/ZigZag.mqh>

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
   // ZigZag.Periods
   if (AutoConfiguration) ZigZag.Periods = GetConfigInt(indicator, "ZigZag.Periods", ZigZag.Periods);
   if (ZigZag.Periods < 2) return(catch("onInit(1)  invalid input parameter ZigZag.Periods: "+ ZigZag.Periods, ERR_INVALID_INPUT_PARAMETER));
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)   return(catch("onInit(2)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

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
      ArrayInitialize(main, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(main, Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1), trend, reversalOffset;
   bool isReversal, isPosition;
   double reversalUp, reversalDown, change;

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      if (!GetZigZagData(bar, trend, isReversal, reversalOffset, reversalUp, reversalDown)) {
         return(last_error);
      }
      isPosition = (main[bar+1] != EMPTY_VALUE);

      if (isReversal) {                                           // flip position
         if (isPosition) {
            if (trend > 0) {
               change     = reversalUp - Close[bar+1];
               main[bar]  = main[bar+1] - change/pUnit;           // close existing position
               main[bar] += (Close[bar] - reversalUp)/pUnit;      // open new position
            }
            else if (trend < 0) {
               change     = reversalDown - Close[bar+1];
               main[bar]  = main[bar+1] + change/pUnit;           // close existing position
               main[bar] += (reversalDown - Close[bar])/pUnit;    // open new position
            }
            else {
               debug("onTick(0.1)  cannot flip position with trend=0");
            }
         }
         else {
            if (trend > 0) {
               main[bar] = (Close[bar] - reversalUp)/pUnit;       // open long
            }
            else if (trend < 0) {
               main[bar] = (reversalDown - Close[bar])/pUnit;     // open short
            }
            else {
               debug("onTick(0.2)  cannot open position with trend=0");
            }
         }
      }
      else if (isPosition) {                                // update position
         change = Close[bar] - Close[bar+1];
         if (trend > 0) {
            main[bar] = main[bar+1] + change/pUnit;
         }
         else if (trend < 0) {
            main[bar] = main[bar+1] - change/pUnit;
         }
         else {
            debug("onTick(0.3)  cannot update position with trend=0");
         }
      }
      else {                                                // keep previous PnL
         main[bar] = main[bar+1];
      }
   }
   return(last_error);
}


/**
 * Get ZigZag buffer values at the specified bar offset.
 *
 * @param  _In_  int    bar               - bar offset
 * @param  _Out_ int    trend             - trend at the specified bar (internal buffer MODE_TREND)
 * @param  _Out_ bool   isReversal        - whether the specified bar is a reversal bar
 * @param  _Out_ int    reversalOffset    - buffer ZigZag.MODE_REVERSAL_OFFSET at the specified bar
 * @param  _Out_ double reversalPriceUp   - buffer ZigZag.MODE_UPPER_CROSS at the specified bar
 * @param  _Out_ double reversalPriceDown - buffer ZigZag.MODE_LOWER_CROSS at the specified bar
 *
 * @return bool - success status
 */
bool GetZigZagData(int bar, int &trend, bool &isReversal, int &reversalOffset, double &reversalPriceUp, double &reversalPriceDown) {
   int combinedTrend = MathRound(icZigZag(NULL, ZigZag.Periods, ZigZag.MODE_COMBINED_TREND,  bar));
   reversalOffset    = MathRound(icZigZag(NULL, ZigZag.Periods, ZigZag.MODE_REVERSAL_OFFSET, bar));
   reversalPriceUp   = 0;
   reversalPriceDown = 0;

   trend = combinedTrend % 100000;
   isReversal = (Abs(trend) == reversalOffset);

   if (isReversal) {
      reversalPriceUp   = icZigZag(NULL, ZigZag.Periods, ZigZag.MODE_UPPER_CROSS, bar);
      reversalPriceDown = icZigZag(NULL, ZigZag.Periods, ZigZag.MODE_LOWER_CROSS, bar);
   }
   return(!last_error);
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
   SetIndexBuffer(MODE_MAIN, main); SetIndexEmptyValue(MODE_MAIN, EMPTY_VALUE);
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
