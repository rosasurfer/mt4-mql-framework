/**
 * Triple Moving Average Oscillator (Trix)
 *
 * The Triple Moving Average Oscillator is a momentum indicator that displays the percentage rate of change between two
 * consecutive triple smoothed moving average values. The displayed unit is permille: 1 permille = 0.1 percent = 0.001
 * Enhanced version supporting all framework types of Moving Averages (not only EMA).
 *
 *
 * @see  https://www.tradingtechnologies.com/help/x-study/technical-indicator-definitions/triple-exponential-moving-average-tema/
 *
 *
 * TODO: fix EMA calculation
 * TODO: add trend buffers
 * TODO: add SMA signal line
 * TODO: support all framework MA types
 * TODO: support different price types
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int   MA.Periods            = 14;
extern color Color.MainLine        = Blue;                  // indicator style management in MQL
extern int   Style.MainLine.Width  = 1;
extern int   Max.Values            = 2000;                  // max. number of values to calculate: -1 = all

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>

#define MODE_MAIN             Trix.MODE_MAIN                // indicator buffer ids
#define MODE_MA1              1
#define MODE_MA2              2
#define MODE_MA3              3

#property indicator_separate_window
#property indicator_level1    0

#property indicator_buffers   4

#property indicator_width1    1
#property indicator_width2    0
#property indicator_width3    0
#property indicator_width4    0

double bufferTrix[];                                        // Trix main value: visible, displayed in "Data" window
double bufferMA1 [];                                        // first MA:        invisible
double bufferMA2 [];                                        // second MA:       invisible
double bufferMA3 [];                                        // third MA:        invisible


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // (1) validate inputs
   // MA.Periods
   if (MA.Periods < 1)           return(catch("onInit(1)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   // Colors                                                // can be messed-up by the terminal after deserialization
   if (Color.MainLine == 0xFF000000) Color.MainLine = CLR_NONE;
   // Styles
   if (Style.MainLine.Width < 1) return(catch("onInit(2)  Invalid input parameter Style.MainLine.Width = "+ Style.MainLine.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Style.MainLine.Width > 5) return(catch("onInit(3)  Invalid input parameter Style.MainLine.Width = "+ Style.MainLine.Width, ERR_INVALID_INPUT_PARAMETER));
   // Max.Values
   if (Max.Values < -1)          return(catch("onInit(4)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));


   // (2) setup buffer management
   IndicatorBuffers(4);
   SetIndexBuffer(MODE_MAIN, bufferTrix);                   // Trix main value: visible, displayed in "Data" window
   SetIndexBuffer(MODE_MA1,  bufferMA1);                    // first MA:        invisible
   SetIndexBuffer(MODE_MA2,  bufferMA2);                    // second MA:       invisible
   SetIndexBuffer(MODE_MA3,  bufferMA3);                    // third MA:        invisible


   // (3) data display configuration, names and labels
   string name = "TRIX("+ MA.Periods +")";
   IndicatorShortName(name +"  ");                          // indicator subwindow and context menu
   SetIndexLabel(MODE_MAIN, name);                          // "Data" window and tooltips
   SetIndexLabel(MODE_MA1, NULL);
   SetIndexLabel(MODE_MA2, NULL);
   SetIndexLabel(MODE_MA3, NULL);
   IndicatorDigits(3);


   // (4) drawing options and styles
   int startDraw = Max(MA.Periods-1, Bars-ifInt(Max.Values==-1, Bars, Max.Values));
   SetIndexDrawBegin(MODE_MAIN, startDraw);
   SetIndexDrawBegin(MODE_MA1,  startDraw);
   SetIndexDrawBegin(MODE_MA2,  startDraw);
   SetIndexDrawBegin(MODE_MA3,  startDraw);
   SetIndicatorStyles();                                    // fix for various terminal bugs

   return(catch("onInit(5)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check for finished buffer initialization
   if (ArraySize(bufferTrix) == 0)                          // can happen on terminal start
      return(debug("onTick(1)  size(bufferTrix) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferTrix, EMPTY_VALUE);
      ArrayInitialize(bufferMA1,  EMPTY_VALUE);
      ArrayInitialize(bufferMA2,  EMPTY_VALUE);
      ArrayInitialize(bufferMA3,  EMPTY_VALUE);
      SetIndicatorStyles();                                 // fix for various terminal bugs
   }

   // synchronize buffers with a shifted offline chart (if applicable)
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferTrix, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferMA1,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferMA2,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferMA3,  Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Values >= 0) /*&&*/ if (ChangedBars > Max.Values)
      changedBars = Max.Values;
   int bar, startBar = Min(changedBars-1, Bars-MA.Periods);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid bars
   // three MAs
   for (bar=startBar; bar >= 0; bar--) bufferMA1[bar] =        iMA(NULL, NULL,             MA.Periods, 0, MODE_EMA, PRICE_CLOSE, bar);
   for (bar=startBar; bar >= 0; bar--) bufferMA2[bar] = iMAOnArray(bufferMA1, WHOLE_ARRAY, MA.Periods, 0, MODE_EMA,              bar);
   for (bar=startBar; bar >= 0; bar--) bufferMA3[bar] = iMAOnArray(bufferMA2, WHOLE_ARRAY, MA.Periods, 0, MODE_EMA,              bar);

   // TRIX
   for (bar=startBar; bar >= 0; bar--) {
      if (!bufferMA3[bar+1]) bufferTrix[bar] = 0;                                                                 // prevent division by zero
      else                   bufferTrix[bar] = (bufferMA3[bar] - bufferMA3[bar+1]) / bufferMA3[bar+1] * 1000;     // convert to permille
   }
   return(last_error);
}


/**
 * Set indicator styles. Workaround for various terminal bugs when setting styles. Usually styles are applied in init().
 * However after recompilation styles must be applied in start() to not get lost.
 */
void SetIndicatorStyles() {
   SetIndexStyle(MODE_MAIN, DRAW_LINE, EMPTY, Style.MainLine.Width, Color.MainLine);
   SetIndexStyle(MODE_MA1,  DRAW_NONE, EMPTY, EMPTY,                CLR_NONE      );
   SetIndexStyle(MODE_MA2,  DRAW_NONE, EMPTY, EMPTY,                CLR_NONE      );
   SetIndexStyle(MODE_MA3,  DRAW_NONE, EMPTY, EMPTY,                CLR_NONE      );
}
