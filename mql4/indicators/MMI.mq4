/**
 * Market Meanness Index
 *
 *
 * @see  http://www.financial-hacker.com/the-market-meanness-index/
 *
 * TODO: add a moving average as signal line
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int   MMI.Periods = 100;

extern color Line.Color  = Blue;
extern int   Line.Width  = 1;

extern int   Max.Values  = 6000;                            // max. number of values to display: -1 = all

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>

#define MODE_MAIN           MMI.MODE_MAIN                   // indicator buffer id

#property indicator_separate_window
#property indicator_buffers 1
#property indicator_color1  Blue

double bufferMMI[];
int    mmi.periods;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // (1) input validation
   // MMI.Periods
   if (MMI.Periods < 1) return(catch("onInit(1)  Invalid input parameter Periods = "+ MMI.Periods, ERR_INVALID_INPUT_PARAMETER));
   mmi.periods = MMI.Periods;

   // Colors (might be wrongly initialized after re-compilation or terminal restart)
   if (Line.Color == 0xFF000000) Line.Color = CLR_NONE;

   // Styles
   if (Line.Width < 1)  return(catch("onInit(2)  Invalid input parameter Line.Width = "+ Line.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Line.Width > 5)  return(catch("onInit(3)  Invalid input parameter Line.Width = "+ Line.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1) return(catch("onInit(4)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));


   // (2) indicator buffer management
   IndicatorBuffers(1);
   SetIndexBuffer(MODE_MAIN, bufferMMI);


   // (3) names, labels, data display
   string name = "Market Meanness("+ mmi.periods +")";
   SetIndexLabel(MODE_MAIN, name);                                   // "Data" window and tooltips
   IndicatorShortName(name +"  ");                                   // indicator subwindow and context menu
   IndicatorDigits(1);


   // (4) drawing options and styles
   int startDraw = 0;
   if (Max.Values >= 0) startDraw += Bars - Max.Values;
   if (startDraw  <  0) startDraw  = 0;
   SetIndexDrawBegin(MODE_MAIN, startDraw);
   SetLevelValue(0, 75);
   SetLevelValue(1, 50);
   SetIndicatorStyles();                                             // fix for various terminal bugs

   return(catch("onInit(5)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check for finished buffer initialization
   if (!ArraySize(bufferMMI))                                        // can happen on terminal start
      return(debug("onTick(1)  size(bufferMMI) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferMMI, EMPTY_VALUE);
      SetIndicatorStyles();                                          // fix for various terminal bugs
   }

   // synchronize buffers with a shifted offline chart (if applicable)
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMMI, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Values >= 0) /*&&*/ if (ChangedBars > Max.Values)
      changedBars = Max.Values;
   int startBar = Min(changedBars-1, Bars-mmi.periods);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid bars
   for (int bar=startBar; bar >= 0; bar--) {
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
 * Set indicator styles. Workaround for various terminal bugs when setting styles. Usually styles are applied in init().
 * However after recompilation styles must be applied in start() to not get lost.
 */
void SetIndicatorStyles() {
   SetIndexStyle(MODE_MAIN, DRAW_LINE, EMPTY, Line.Width, Line.Color);
}


/**
 * Return a string representation of the input parameters. Used when logging iCustom() calls.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "MMI.Periods=", MMI.Periods,            "; ",

                            "Line.Color=",  ColorToStr(Line.Color), "; ",
                            "Line.Width=",  Line.Width,             "; ",

                            "Max.Values=",  Max.Values,             "; ")
   );
}
