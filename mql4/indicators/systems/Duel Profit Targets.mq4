/**
 * Duel Profit Targets
 *
 * Visualizes breakeven, profit and stoploss targets of the Duel system. The indicator gets its values directly from the
 * Duel expert running in the same chart (online and tester).
 *
 * @see  mql4/experts/Duel.mq4
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_BE_LONG          0                    // indicator buffer ids
#define MODE_BE_SHORT         1

#property indicator_chart_window
#property indicator_buffers   2

#property indicator_color1    Blue
#property indicator_color2    Blue

double beLong [];
double beShort[];


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   SetIndexBuffer(MODE_BE_LONG,  beLong);
   SetIndexBuffer(MODE_BE_SHORT, beShort);

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
   if (!ArraySize(beLong)) return(logInfo("onTick(1)  size(beLong) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Bars before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(beLong,  EMPTY_VALUE);
      ArrayInitialize(beShort, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(beLong,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(beShort, Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int startBar = ChangedBars-1;
   if (startBar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int i=startBar; i >= 0; i--) {
      beLong [i] = 0;
      beShort[i] = 0;
   }
   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   SetIndexStyle(MODE_BE_LONG,  DRAW_LINE, EMPTY, EMPTY);
   SetIndexStyle(MODE_BE_SHORT, DRAW_LINE, EMPTY, EMPTY);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return("");
}
