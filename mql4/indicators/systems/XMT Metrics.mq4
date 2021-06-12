/**
 * wip: XMT Metrics
 *
 * Visualizes performance metrics of an XMT-Scalper sequence.
 *
 * @see  mql4/experts/XMT-Scalper.mq4
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Dummy = "";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_OPEN             0
#define MODE_LOW              1
#define MODE_HIGH             2
#define MODE_CLOSE            3

#property indicator_separate_window
#property indicator_buffers   4

#property indicator_color1    Blue
#property indicator_color2    Blue
#property indicator_color3    Blue
#property indicator_color4    Blue

double open [];
double high [];
double low  [];
double close[];


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // buffer management
   SetIndexBuffer(MODE_OPEN,  open );
   SetIndexBuffer(MODE_HIGH,  high );
   SetIndexBuffer(MODE_LOW,   low  );
   SetIndexBuffer(MODE_CLOSE, close);

   // names, labels and display options
   SetIndexLabel(MODE_OPEN,  "Open" );
   SetIndexLabel(MODE_HIGH,  "High" );
   SetIndexLabel(MODE_LOW,   "Low"  );
   SetIndexLabel(MODE_CLOSE, "Close");
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(open)) return(logDebug("onTick(1)  size(open) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(open,  EMPTY_VALUE);
      ArrayInitialize(high,  EMPTY_VALUE);
      ArrayInitialize(low,   EMPTY_VALUE);
      ArrayInitialize(close, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(open,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(high,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(low,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(close, Bars, ShiftedBars, EMPTY_VALUE);
   }

   int startbar = ChangedBars-1;

   // recalculate changed bars
   for (int i=startbar; i >= 0; i--) {
      //open[i] = Open[i];
      //high[i] = High[i];
      //low [i] = Low [i];
      close[i] = Close[i];
   }
   return(catch("onTick(2)"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   SetIndexStyle(MODE_OPEN,  DRAW_LINE, STYLE_SOLID, 1, Blue);
   SetIndexStyle(MODE_HIGH,  DRAW_LINE, STYLE_SOLID, 1, Blue);
   SetIndexStyle(MODE_LOW,   DRAW_LINE, STYLE_SOLID, 1, Blue);
   SetIndexStyle(MODE_CLOSE, DRAW_LINE, STYLE_SOLID, 1, Blue);
}
