/**
 * Commodity Channel Index - a momentum indicator
 *
 * Defined as the upscaled ratio of current distance to average distance from a Moving Average. The scaling factor of 66.67
 * was chosen so that the majority of indicator values falls between -200 and +200.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    CCI.Periods           = 14;
extern string CCI.AppliedPrice      = "Open | High | Low | Close | Median | Typical* | Weighted";

extern color  Histogram.Color.Long  = LimeGreen;
extern color  Histogram.Color.Short = Red;
extern int    Histogram.Width       = 2;

extern int    MaxBarsBack           = 10000;       // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>

#define MODE_MAIN            0                     // indicator buffer ids
#define MODE_TREND           1
#define MODE_LONG            2
#define MODE_SHORT           3

#property indicator_separate_window
#property indicator_buffers  4                     // visible buffers

#property indicator_color1   CLR_NONE
#property indicator_color2   CLR_NONE
#property indicator_color3   CLR_NONE
#property indicator_color4   CLR_NONE

#property indicator_level1   +100
#property indicator_level2      0
#property indicator_level3   -100

#property indicator_maximum  +180
#property indicator_minimum  -180

double cci     [];                                 // all CCI values: displayed in "Data" window
double cciLong [];                                 // long trade segments
double cciShort[];                                 // short trade segments
double trend   [];                                 // trade segment length

int cci.appliedPrice;

string indicatorName = "";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   string indicator = WindowExpertName();

   // CCI.Periods
   if (AutoConfiguration) CCI.Periods = GetConfigInt(indicator, "CCI.Periods", CCI.Periods);
   if (CCI.Periods < 1)        return(catch("onInit(1)  invalid input parameter CCI.Periods: "+ CCI.Periods +" (must be > 0)", ERR_INVALID_INPUT_PARAMETER));

   // CCI.AppliedPrice
   string sValues[], sValue = CCI.AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "CCI.AppliedPrice", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "typical";              // default price type
   cci.appliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (cci.appliedPrice == -1) return(catch("onInit(2)  invalid input parameter CCI.AppliedPrice: "+ DoubleQuoteStr(CCI.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   CCI.AppliedPrice = PriceTypeDescription(cci.appliedPrice);

   // Histogram.Width
   if (AutoConfiguration) Histogram.Width = GetConfigInt(indicator, "Histogram.Width", Histogram.Width);
   if (Histogram.Width < 0)    return(catch("onInit(3)  invalid input parameter Histogram.Width: "+ Histogram.Width +" (must be from 0-5)", ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Width > 5)    return(catch("onInit(4)  invalid input parameter Histogram.Width: "+ Histogram.Width +" (must be from 0-5)", ERR_INVALID_INPUT_PARAMETER));

   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Histogram.Color.Long  = GetConfigColor(indicator, "Histogram.Color.Long",  Histogram.Color.Long);
   if (AutoConfiguration) Histogram.Color.Short = GetConfigColor(indicator, "Histogram.Color.Short", Histogram.Color.Short);
   if (Histogram.Color.Long  == 0xFF000000) Histogram.Color.Long  = CLR_NONE;
   if (Histogram.Color.Short == 0xFF000000) Histogram.Color.Short = CLR_NONE;

   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)       return(catch("onInit(5)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   SetIndicatorOptions();
   return(catch("onInit(6)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // process incoming commands
   if (__isChart) {}

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(cci,      EMPTY_VALUE);
      ArrayInitialize(cciLong,  EMPTY_VALUE);
      ArrayInitialize(cciShort, EMPTY_VALUE);
      ArrayInitialize(trend,              0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(cci,      Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(cciLong,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(cciShort, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(trend,    Bars, ShiftedBars,           0);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-CCI.Periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      // CCI: upscaled ratio of current to average distance from MA
      // ----------------------------------------------------------
      // double ma       = iMA(NULL, NULL, CCI.Periods, 0, MODE_SMA, cci.appliedPrice, bar);
      // double distance = GetPrice(bar) - ma;
      // double sum = 0;
      // for (int n=bar+CCI.Periods-1; n >= bar; n--) {
      //    sum += MathAbs(GetPrice(n) - ma);
      // }
      // double avgDistance = sum / CCI.Periods;
      // cci[bar] = MathDiv(distance, avgDistance) / 0.015;                // 1/0.015 = 66.6667

      cci[bar] = iCCI(NULL, NULL, CCI.Periods, cci.appliedPrice, bar);

      if (bar < Bars-1) {
         int prevTrend = trend[bar+1];

         // update trade direction and length
         if (prevTrend > 0) {
            if (cci[bar] > -100) trend[bar] = prevTrend + 1;   // continue long segment
            else                 trend[bar] = -1;              // new short signal
         }
         else if (prevTrend < 0) {
            if (cci[bar] < 100) trend[bar] = prevTrend - 1;    // continue short segment
            else                trend[bar] = 1;                // long signal
         }
         else if (cci[bar+1] != EMPTY_VALUE) {
            if (cci[bar+1] < 100 && cci[bar] >= 100) {
               trend[bar] = 1;                                 // 1st long signal
            }
            else if (cci[bar+1] > -100 && cci[bar] <= -100) {
               trend[bar] = -1;                                // 1st short signal
            }
         }

         // update direction buffers
         if (trend[bar] > 0) {
            cciLong [bar] = cci[bar];
            cciShort[bar] = EMPTY_VALUE;
         }
         else if (trend[bar] < 0) {
            cciLong [bar] = EMPTY_VALUE;
            cciShort[bar] = cci[bar];
         }
         else {
            cciLong [bar] = EMPTY_VALUE;
            cciShort[bar] = EMPTY_VALUE;
         }
      }
   }
   return(catch("onTick(2)"));
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
   indicatorName = "CCI("+ CCI.Periods +")";
   IndicatorShortName(indicatorName);

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(MODE_MAIN,  cci     );
   SetIndexBuffer(MODE_LONG,  cciLong );
   SetIndexBuffer(MODE_SHORT, cciShort);
   SetIndexBuffer(MODE_TREND, trend   );
   IndicatorDigits(2);

   int drawBegin = Max(CCI.Periods-1, Bars-MaxBarsBack);
   SetIndexDrawBegin(MODE_LONG,  drawBegin);
   SetIndexDrawBegin(MODE_SHORT, drawBegin);

   SetIndexLabel(MODE_MAIN,  indicatorName);
   SetIndexLabel(MODE_LONG,  NULL);
   SetIndexLabel(MODE_SHORT, NULL);
   SetIndexLabel(MODE_TREND, NULL);

   SetIndexStyle(MODE_MAIN,  DRAW_NONE);
   SetIndexStyle(MODE_TREND, DRAW_NONE);

   int drawType = ifInt(Histogram.Width, DRAW_HISTOGRAM, DRAW_NONE);
   SetIndexStyle(MODE_LONG,  drawType, EMPTY, Histogram.Width, Histogram.Color.Long);
   SetIndexStyle(MODE_SHORT, drawType, EMPTY, Histogram.Width, Histogram.Color.Short);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("CCI.Periods=",           CCI.Periods,                       ";", NL,
                            "CCI.AppliedPrice=",      DoubleQuoteStr(CCI.AppliedPrice),  ";", NL,
                            "Histogram.Color.Long=",  ColorToStr(Histogram.Color.Long),  ";", NL,
                            "Histogram.Color.Short=", ColorToStr(Histogram.Color.Short), ";", NL,
                            "Histogram.Width=",       Histogram.Width,                   ";", NL,
                            "MaxBarsBack=",           MaxBarsBack,                       ";")
   );
}
