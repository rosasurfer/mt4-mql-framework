/**
 * Market Meanness Index
 *
 *
 * @link  http://www.financial-hacker.com/the-market-meanness-index/
 *
 * TODO: add a moving average as signal line
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int   MMI.Periods = 100;

extern color Line.Color  = Blue;
extern int   Line.Width  = 1;

extern int   Max.Bars    = 10000;                           // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_MAIN           MMI.MODE_MAIN                   // indicator buffer id

#property indicator_separate_window
#property indicator_buffers   1
#property indicator_color1    Blue

double bufferMMI[];

int mmi.periods;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // (1) input validation
   // MMI.Periods
   if (MMI.Periods < 1) return(catch("onInit(1)  invalid input parameter Periods: "+ MMI.Periods, ERR_INVALID_INPUT_PARAMETER));
   mmi.periods = MMI.Periods;

   // Colors (might be wrongly initialized after re-compilation or terminal restart)
   if (Line.Color == 0xFF000000) Line.Color = CLR_NONE;

   // Styles
   if (Line.Width < 0)  return(catch("onInit(2)  invalid input parameter Line.Width: "+ Line.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Bars
   if (Max.Bars < -1)   return(catch("onInit(3)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));


   // (2) indicator buffer management
   SetIndexBuffer(MODE_MAIN, bufferMMI);


   // (3) names, labels, data display
   string name = "Market Meanness("+ mmi.periods +")";
   IndicatorShortName(name +"  ");                                   // chart subwindow and context menu
   SetIndexLabel(MODE_MAIN, name);                                   // chart tooltips and "Data" window
   IndicatorDigits(1);


   // (4) drawing options and styles
   int startDraw = 0;
   if (Max.Bars >= 0) startDraw += Bars - Max.Bars;
   if (startDraw < 0) startDraw = 0;
   SetIndexDrawBegin(MODE_MAIN, startDraw);
   SetLevelValue(0, 75);
   SetLevelValue(1, 50);
   SetIndicatorOptions();

   return(catch("onInit(4)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(bufferMMI)) return(logInfo("onTick(1)  size(bufferMMI) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferMMI, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(bufferMMI, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Bars >= 0) /*&&*/ if (ChangedBars > Max.Bars)
      changedBars = Max.Bars;
   int startbar = Min(changedBars-1, Bars-mmi.periods);
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      int revertingUp   = 0;
      int revertingDown = 0;
      double avgPrice   = iMA(NULL, NULL, mmi.periods+1, 0, MODE_SMA, PRICE_CLOSE, bar);

      for (int i=bar+mmi.periods; i > bar; i--) {
         if (Close[i] < avgPrice) {
            if (Close[i-1] > Close[i]) revertingUp++;
         }
         else if (Close[i-1] < Close[i]) revertingDown++;
      }
      bufferMMI[bar] = 100. * (revertingUp + revertingDown)/mmi.periods;
   }
   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);

   int drawStyle = ifInt(!Line.Width, DRAW_NONE, DRAW_LINE);
   SetIndexStyle(MODE_MAIN, drawStyle, EMPTY, Line.Width, Line.Color);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MMI.Periods=", MMI.Periods,            ";", NL,
                            "Line.Color=",  ColorToStr(Line.Color), ";", NL,
                            "Line.Width=",  Line.Width,             ";", NL,
                            "Max.Bars=",    Max.Bars,               ";")
   );
}
