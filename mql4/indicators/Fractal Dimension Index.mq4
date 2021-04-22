/**
 * FDI - Fractal Dimension Index
 *
 * The Fractal Dimension Index describes the state of randomness or the existence of a long-term memory in a timeseries.
 * The FDI oscillates between 1 (1-dimensional behavior) and 2 (2-dimensional behavior). In financial contexts an FDI below
 * 1.5 indicates a market with trending behavior (the timeseries is persistent). An FDI above 1.5 indicates a market with
 * ranging or cyclic behavior (the timeseries is non-persistent). An FDI at 1.5 indicates a market with random behavior
 * (the timeseries has no long-term memory). The FDI does not indicate market direction.
 *
 * The index is computed using the Sevcik algorithm (3) which is an optimized estimation for the real fractal dimension of a
 * data set as described by Long (1). It holds:
 *
 *   Fractal Dimension (D) = 2 - Hurst exponent (H)
 *
 * The modification by Matulich (4) changes the interpretation of an element of the set in the context of financial markets.
 * Matulich doesn't change the algorithm. It holds:
 *
 *   FDI(N, Matulich) = FDI(N+1, Sevcik)
 *
 * The so-called "Fractal Graph Dimension Index" (FGDI) draws colored Bollinger Bands around the FDI but doesn't add any
 * value. The similar named "Fractal Dimension" by Ehlers is not related to this indicator.
 *
 * Indicator buffers for iCustom():
 *  • FDI.MODE_MAIN: FDI values
 *
 *
 * @see   "etc/doc/fdi/Making Sense of Fractals [Long, 2003].pdf"                                         [Long, 2003]
 * @link  http://web.archive.org/web/20120413090115/http://www.fractalfinance.com/fracdimin.html          [Long, 2004]
 * @link  http://web.archive.org/web/20080726032123/http://complexity.org.au/ci/vol05/sevcik/sevcik.html  [Estimation of Fractal Dimension, Sevcik, 1998]
 * @link  http://unicorn.us.com/trading/el.html#FractalDim                                                [Fractal Dimension, Matulich, 2006]
 * @link  http://beathespread.com/pages/view/2228/fractal-dimension-indicators-and-their-use              [FDI Usage, JohnLast, 2010]
 *
 * @link  https://www.mql5.com/en/code/8997                                                               [FGDI with fixed FDI issues, LastViking]
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Periods        = 30;                       // number of periods (according to average trend length?)
extern color  Color.Ranging  = Blue;
extern color  Color.Trending = Red;
extern string DrawType       = "Line* | Dot";
extern int    DrawWidth      = 1;
extern int    Max.Bars       = 10000;                    // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_MAIN             FDI.MODE_MAIN
#define MODE_UPPER            1                          // indicator buffer ids
#define MODE_LOWER            2

#property indicator_separate_window
#property indicator_buffers   3                          // buffers visible in input dialog

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE

#property indicator_level1    1
#property indicator_level2    1.5
#property indicator_level3    2

double main [];                                          // all FDI values: invisible
double upper[];                                          // upper line:     visible (ranging)
double lower[];                                          // lower line:     visible (trending)

int fdiPeriods;

int drawType;
int drawWidth;
int maxValues;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // Periods
   if (Periods < 2)   return(catch("onInit(1)  Invalid input parameter Periods: "+ Periods +" (min. 2)", ERR_INVALID_INPUT_PARAMETER));
   fdiPeriods = Periods;
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.Ranging  == 0xFF000000) Color.Ranging  = CLR_NONE;
   if (Color.Trending == 0xFF000000) Color.Trending = CLR_NONE;
   // DrawType
   string sValues[], sValue=StrToLower(DrawType);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("line", sValue)) { drawType = DRAW_LINE;  DrawType = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { drawType = DRAW_ARROW; DrawType = "Dot";  }
   else               return(catch("onInit(2)  Invalid input parameter DrawType = "+ DoubleQuoteStr(DrawType), ERR_INVALID_INPUT_PARAMETER));
   // DrawWidth
   if (DrawWidth < 0) return(catch("onInit(3)  Invalid input parameter DrawWidth = "+ DrawWidth, ERR_INVALID_INPUT_PARAMETER));
   if (DrawWidth > 5) return(catch("onInit(4)  Invalid input parameter DrawWidth = "+ DrawWidth, ERR_INVALID_INPUT_PARAMETER));
   drawWidth = DrawWidth;
   // Max.Bars
   if (Max.Bars < -1) return(catch("onInit(5)  Invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);

   // buffer management
   SetIndexBuffer(MODE_MAIN,  main );                    // all FDI values: invisible
   SetIndexBuffer(MODE_UPPER, upper);                    // upper line:     visible (ranging)
   SetIndexBuffer(MODE_LOWER, lower);                    // lower line:     visible (trending)

   // names, labels and display options
   string indicatorName = "FDI("+ fdiPeriods +")";
   IndicatorShortName(indicatorName +"  ");              // chart subwindow and context menu
   SetIndexLabel(MODE_MAIN,  indicatorName);             // chart tooltips and "Data" window
   SetIndexLabel(MODE_UPPER, NULL);
   SetIndexLabel(MODE_LOWER, NULL);
   SetIndicatorOptions();

   return(catch("onInit(6)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(main)) return(logDebug("onTick(1)  size(main) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Bars before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(main,  EMPTY_VALUE);
      ArrayInitialize(upper, EMPTY_VALUE);
      ArrayInitialize(lower, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(main,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(upper, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(lower, Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int bars     = Min(ChangedBars, maxValues);
   int startBar = Min(bars-1, Bars-fdiPeriods-1);
   if (startBar < 0) return(logDebug("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   UpdateChangedBars(startBar);

   return(last_error);
}


/**
 * Update changed bars.
 *
 * @param  int startBar - index of the oldest changed bar
 *
 * @return bool - success status
 */
bool UpdateChangedBars(int startBar) {
   int periodsPlus1   = fdiPeriods + 1;
   double log2        = MathLog(2);
   double log2Periods = MathLog(2 * fdiPeriods);
   double periodsPow2 = MathPow(fdiPeriods, -2);                           // same as: 1/MathPow(fdiPeriods, 2)

   // Sevcik's algorithm (3) adapted to financial timeseries by Matulich (4). It holds:
   //
   //   FDI(N, Matulich) = FDI(N+1, Sevcik)
   //
   for (int bar=startBar; bar >= 0; bar--) {
      double priceMax = Close[ArrayMaximum(Close, periodsPlus1, bar)];     // fixes a Matulich error
      double priceMin = Close[ArrayMinimum(Close, periodsPlus1, bar)];
      double range    = NormalizeDouble(priceMax-priceMin, Digits), length=0, fdi=0;

      if (range > 0) {
         for (int i=0; i < fdiPeriods; i++) {
            double diff = (Close[bar+i]-Close[bar+i+1]) / range;
            length += MathSqrt(MathPow(diff, 2) + periodsPow2);
         }
         fdi = 1 + (MathLog(length) + log2)/log2Periods;                   // Sevcik's formula (6a) for small values of N

         if (fdi < 1 || fdi > 2) return(!catch("UpdateChangedBars(1)  bar="+ bar +"  fdi="+ fdi, ERR_RUNTIME_ERROR));
      }
      else {
         fdi = main[bar+1];                                                // no movement: D = 0 (a point)
      }

      main[bar] = fdi;

      if (fdi > 1.5) {
         upper[bar] = fdi;
         lower[bar] = EMPTY_VALUE;

         if (drawType==DRAW_LINE) /*&&*/ if (upper[bar+1]==EMPTY_VALUE) {  // make sure the line is not interrupted
            upper[bar+1] = lower[bar+1];
         }
      }
      else {
         upper[bar] = EMPTY_VALUE;
         lower[bar] = fdi;

         if (drawType==DRAW_LINE) /*&&*/ if (lower[bar+1]==EMPTY_VALUE) {  // make sure the line is not interrupted
            lower[bar+1] = upper[bar+1];
         }
      }
   }
   return(true);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   SetIndexStyle(MODE_MAIN, DRAW_NONE);

   //SetIndexStyle(int buffer, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL)
   int draw_type = ifInt(drawWidth, drawType, DRAW_NONE);

   SetIndexStyle(MODE_UPPER, draw_type, EMPTY, drawWidth, Color.Ranging ); SetIndexArrow(MODE_UPPER, 158);
   SetIndexStyle(MODE_LOWER, draw_type, EMPTY, drawWidth, Color.Trending); SetIndexArrow(MODE_LOWER, 158);

}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Periods=",        Periods,                    ";", NL,
                            "Color.Ranging=",  ColorToStr(Color.Ranging),  ";", NL,
                            "Color.Trending=", ColorToStr(Color.Trending), ";", NL,
                            "DrawType=",       DoubleQuoteStr(DrawType),   ";", NL,
                            "DrawWidth=",      DrawWidth,                  ";", NL,
                            "Max.Bars=",       Max.Bars,                   ";")
   );
}
