/**
 * FDI - Fractal Dimension Index
 *
 * The Fractal Dimension Index describes market volatility and trendiness. It oscillates between 1 (a 1-dimensional market)
 * and 2 (a 2-dimensional market). An FDI below 1.5 indicates a market with mainly trending behaviour. An FDI above 1.5
 * indicates a market with mainly cyclic behaviour. An FDI at 1.5 indicates a market with nearly random behaviour. The FDI
 * does not indicate market direction.
 *
 * The index is computed using the Sevcik algorithm (3) which is an optimized estimation for the real fractal dimension of a
 * data set as described by Long (1). The modification by Matulich (4) changes the interpretion of an element of the data set
 * in the context of financial timeseries. Matulich doesn't change the algorithm. It holds:
 *
 *   FDI(N, Matulich) = FDI(N+1, Sevcik)
 *
 * @see  (1) "etc/doc/fdi/Making Sense of Fractals [Long, 2003].pdf"
 * @see  (2) http://web.archive.org/web/20120413090115/http://www.fractalfinance.com/fracdimin.html          [Long, 2004]
 * @see  (3) http://web.archive.org/web/20080726032123/http://complexity.org.au/ci/vol05/sevcik/sevcik.html  [Estimation of Fractal Dimension, Sevcik, 1998]
 * @see  (4) http://unicorn.us.com/trading/el.html#FractalDim                                                [Fractal Dimension, Matulich, 2006]
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int Periods    = 30;                              // number of periods (according to the average trend length?)
extern int Max.Values = 1000;                            // max. amount of values to calculate (-1: all)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_MAIN             0                          // indicator buffer ids
#define MODE_UPPER            1
#define MODE_LOWER            2

#property indicator_separate_window
#property indicator_buffers   3                          // buffers visible in input dialog

#property indicator_color1    Blue
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE

#property indicator_minimum   1
#property indicator_maximum   2

#property indicator_level1    1
#property indicator_level2    1.5
#property indicator_level3    2

double main [];                                          // all FDI values: invisible
double upper[];                                          // upper line:     visible (ranging)
double lower[];                                          // lower line:     visible (trending)

int fdiPeriods;
int maxValues;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // Periods
   if (Periods < 2)     return(catch("onInit(1)  Invalid input parameter Periods: "+ Periods +" (min. 2)", ERR_INVALID_INPUT_PARAMETER));
   fdiPeriods = Periods;
   // Max.Values
   if (Max.Values < -1) return(catch("onInit(2)  Invalid input parameter Max.Values: "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Values==-1, INT_MAX, Max.Values);

   // buffer management
   SetIndexBuffer(MODE_MAIN,  main );                    // all FDI values: invisible
   SetIndexBuffer(MODE_UPPER, upper);                    // upper line:     visible (ranging)
   SetIndexBuffer(MODE_LOWER, lower);                    // lower line:     visible (trending)

   // names, labels and display options
   string indicatorName = "FDI("+ fdiPeriods +")";
   IndicatorShortName(indicatorName +"  ");              // indicator subwindow and context menu
   SetIndexLabel(MODE_MAIN,  indicatorName);             // "Data" window and tooltips
   SetIndexLabel(MODE_UPPER, NULL);
   SetIndexLabel(MODE_LOWER, NULL);
   SetIndicatorOptions();

   return(catch("onInit(3)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // a not initialized buffer can happen on terminal start under specific circumstances
   if (!ArraySize(main)) return(log("onTick(1)  size(main) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
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
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));

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
   double log2        = MathLog(2);
   double log2Periods = MathLog(2 * fdiPeriods);
   double periodsPow2 = MathPow(fdiPeriods, -2);                        // = 1/MathPow(fdiPeriods, 2)

   // Sevcik's algorithm (3) adapted to financial timeseries by Matulich (4). It holds:
   //
   //  FDI(N, Matulich) = FDI(N+1, Sevcik)
   //
   for (int bar=startBar; bar >= 0; bar--) {
      double priceMax = Close[ArrayMaximum(Close, fdiPeriods+1, bar)];
      double priceMin = Close[ArrayMinimum(Close, fdiPeriods+1, bar)];
      double range    = NormalizeDouble(priceMax-priceMin, Digits), length=0, fdi=0;

      if (range > 0) {
         for (int i=0; i < fdiPeriods; i++) {
            double diff = (Close[bar+i]-Close[bar+i+1]) / range;
            length += MathSqrt(MathPow(diff, 2) + periodsPow2);
         }
         fdi = 1 + (MathLog(length) + log2)/log2Periods;                // Sevcik formula (6a) for small values of N

         if (fdi < 1 || fdi > 2) return(!catch("UpdateChangedBars(1)  bar="+ bar +"  fdi="+ fdi, ERR_RUNTIME_ERROR));
      }
      else {
         fdi = main[bar+1];                                             // no movement => Dimension = 0 (a point)
      }

      main[bar] = fdi;

      if (fdi > 1.5) {
         upper[bar] = fdi;
         lower[bar] = EMPTY_VALUE;
         if (upper[bar+1] == EMPTY_VALUE) upper[bar+1] = lower[bar+1];
      }
      else {
         upper[bar] = EMPTY_VALUE;
         lower[bar] = fdi;
         if (lower[bar+1] == EMPTY_VALUE) lower[bar+1] = upper[bar+1];
      }
   }
   return(true);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   //SetIndexStyle(int buffer, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL)
   SetIndexStyle(MODE_MAIN,  DRAW_LINE);

   SetIndexStyle(MODE_UPPER, DRAW_LINE, STYLE_SOLID, 1);
   SetIndexStyle(MODE_LOWER, DRAW_LINE, STYLE_SOLID, 1);

}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Periods=",    Periods,    ";", NL,
                            "Max.Values=", Max.Values, ";")
   );
}




/**
 * Fractal Dimension Index
 *
 * @source  https://www.mql5.com/en/code/7758                                               [iliko]
 * @see     https://www.mql5.com/en/forum/176309#comment_4308400                            [edited, Mladen]
 * @see     https://www.mql5.com/en/code/8844                                               [corrections, jjpoton]
 * @see     https://www.forexfactory.com/showthread.php?p=11504048#post11504048             [multiple mashed-up posts from JohnLast]
 *
 *
 *
 * Graphical Fractal Dimension Index
 *
 * @see  https://www.mql5.com/en/code/8844                                                  [Comparison to FDI, jppoton]
 * @see  http://fractalfinance.blogspot.com/2009/05/from-bollinger-to-fractal-bands.html    [Blog post, jppoton]
 *
 * @see  https://www.mql5.com/en/code/9604                                                  [Fractal Dispersion of FGDI, jppoton]
 * @see  http://fractalfinance.blogspot.com/2010/03/self-similarity-and-measure-of-it.html  [Blog post, jppoton]
 *
 * @see  https://www.mql5.com/en/forum/176309/page4#comment_4308422                         [Tampa]
 * @see  https://www.mql5.com/en/code/8997                                                  [Modification for small Periods, LastViking]
 * @see  https://www.mql5.com/en/code/16916                                                 [MT5-Version, Nikolay Kositsin, based on jppoton]
 */
