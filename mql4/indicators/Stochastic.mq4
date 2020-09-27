/**
 * FX Turbo Marksman
 *
 *
 * EURCHF: int StochPercents =  9;
 * EURGBP: int StochPercents = 16;
 * EURJPY: int StochPercents =  6;
 * EURUSD: int StochPercents = 15;
 * GBPCHF: int StochPercents = 15;
 * GBPJPY: int StochPercents = 10;
 * GBPUSD: int StochPercents =  5;
 * USDCAD: int StochPercents =  9;
 * USDCHF: int StochPercents = 20;
 * USDJPY: int StochPercents =  9;
 *
 * DAX:    int StochPercents =  2;
 * DJIA:   int StochPercents = 15;
 * SP500:  int StochPercents = 16;
 *
 * CRUDE:  int StochPercents =  4;
 * XAUUSD: int StochPercents = 10;
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int  StochPercents = 6;            // EURJPY
extern bool SoundAlarm    = true;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/BarOpenEvent.mqh>

#define MODE_DOWN             0           // indicator buffer ids
#define MODE_UP               1

#define SIGNAL_LONG           1           // signal ids used in GlobalVariable*()
#define SIGNAL_SHORT          2

#property indicator_chart_window
#property indicator_buffers   2

#property indicator_color1    Magenta
#property indicator_color2    Blue

double bufferDown[];
double bufferUp  [];

int    stochPeriods;
double stochLevelHigh;
double stochLevelLow;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   SetIndexBuffer(MODE_UP,   bufferUp  ); SetIndexEmptyValue(MODE_UP,   0);
   SetIndexBuffer(MODE_DOWN, bufferDown); SetIndexEmptyValue(MODE_DOWN, 0);
   SetIndicatorOptions();

   stochPeriods   = StochPercents * 2 + 3;
   stochLevelHigh = 67 + StochPercents;
   stochLevelLow  = 33 - StochPercents;

   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(bufferUp)) return(logInfo("onTick(1)  size(bufferUp) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Bars before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(bufferUp,   0);
      ArrayInitialize(bufferDown, 0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferUp,   Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(bufferDown, Bars, ShiftedBars, 0);
   }


   int startBar = 500;

   for (int bar=startBar-12; bar >= 0; bar--) {
      bufferUp  [bar] = 0;
      bufferDown[bar] = 0;

      double stoch = iStochastic(NULL, NULL, stochPeriods, 1, 1, MODE_SMA, 0, MODE_MAIN, bar);    // pricefield: 0=Low/High, 1=Close/Close

      if (stoch > stochLevelHigh) {
         for (int i=1; bar+i < Bars; i++) {
            if (bufferUp[bar+i] || bufferDown[bar+i]) break;
         }
         if (!bufferUp[bar+i]) bufferUp[bar] = Low[bar] - iATR(NULL, NULL, 10, bar)/2;
      }
      else if (stoch < stochLevelLow) {
         for (i=1; bar+i < Bars; i++) {
            if (bufferUp[bar+i] || bufferDown[bar+i]) break;
         }
         if (!bufferDown[bar+i]) bufferDown[bar] = High[bar] + iATR(NULL, NULL, 10, bar)/2;
      }
   }

   if (SoundAlarm) /*&&*/ if (!IsSuperContext()) {
      if (IsBarOpenEvent()) {
         if (bufferUp  [1] != 0) logNotice("onTick(2)  Buy signal");
         if (bufferDown[1] != 0) logNotice("onTick(3)  Sell signal");
      }
   }
   return(catch("onTick(4)"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   SetIndexStyle(MODE_UP,   DRAW_ARROW); SetIndexArrow(MODE_UP,   233);    // arrow up
   SetIndexStyle(MODE_DOWN, DRAW_ARROW); SetIndexArrow(MODE_DOWN, 234);    // arrow down
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("StochPercents=", StochPercents,         ";", NL,
                            "SoundAlarm=",    BoolToStr(SoundAlarm), ";")
   );
}
