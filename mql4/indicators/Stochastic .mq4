/**
 * Stochastic Oscillator
 *
 *
 * The Stochastic oscillator shows the relative position of current price compared to the price range of the lookback period,
 * normalized to a value from 0 to 100. The fast Stochastic is smoothed once, the slow Stochastic is smoothed twice.
 *
 * Indicator buffers for iCustom():
 *  • Stochastic.MODE_MAIN:   indicator base line (fast Stochastic) or first moving average (slow Stochastic)
 *  • Stochastic.MODE_SIGNAL: indicator signal line (last moving average)
 *
 * If only one Moving Average is configured (MA1 or MA2) the indicator calculates the "Fast Stochastic" and MODE_MAIN contains
 * the raw Stochastic. If both Moving Averages are configured the indicator calculates the "Slow Stochastic" and MODE_MAIN
 * contains MA1(StochRaw). MODE_SIGNAL always contains the last configured Moving Average.
 *
 *
 *
 *
 *
 *
 * --------------------------------------------------------------------------------------------------------------------------
 * FX Turbo Marksman values:
 * -------------------------
 * GBPUSD: StochPercents =  5,   Stoch(13),   LS=72:28
 * EURJPY: StochPercents =  6,   Stoch(15),   LS=73:27
 * EURCHF: StochPercents =  9,   Stoch(21),   LS=76:24
 * USDCAD: StochPercents =  9,   Stoch(21),   LS=76:24
 * USDJPY: StochPercents =  9,   Stoch(21),   LS=76:24
 * GBPJPY: StochPercents = 10,   Stoch(23),   LS=77:23
 * EURUSD: StochPercents = 15,   Stoch(33),   LS=82:18
 * GBPCHF: StochPercents = 15,   Stoch(33),   LS=82:18
 * EURGBP: StochPercents = 16,   Stoch(35),   LS=83:17
 * USDCHF: StochPercents = 20,   Stoch(43),   LS=87:13
 *
 * DAX:    StochPercents =  2,   Stoch(7),    LS=69:31
 * DJIA:   StochPercents = 15,   Stoch(33),   LS=82:18
 * SP500:  StochPercents = 16,   Stoch(35),   LS=83:17
 *
 * CRUDE:  StochPercents =  4,   Stoch(11),   LS=71:29
 * XAUUSD: StochPercents = 10,   Stoch(23),   LS=77:23
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

#property indicator_chart_window
#property indicator_buffers   2

#property indicator_color1    Magenta
#property indicator_color2    Blue

double bufferDown[];
double bufferUp  [];

int    periods;
int    signalLevelLong;
int    signalLevelShort;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   SetIndexBuffer(MODE_UP,   bufferUp  ); SetIndexEmptyValue(MODE_UP,   0);
   SetIndexBuffer(MODE_DOWN, bufferDown); SetIndexEmptyValue(MODE_DOWN, 0);
   SetIndicatorOptions();

   periods          = StochPercents * 2 + 3;
   signalLevelLong  = 67 + StochPercents;
   signalLevelShort = 33 - StochPercents;

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

      double stoch = iStochastic(NULL, NULL, periods, 1, 1, MODE_SMA, 0, MODE_MAIN, bar);    // pricefield: 0=Low/High, 1=Close/Close

      if (stoch >= signalLevelLong) {
         for (int i=1; bar+i < Bars; i++) {
            if (bufferUp[bar+i] || bufferDown[bar+i]) break;
         }
         if (!bufferUp[bar+i]) bufferUp[bar] = Low[bar] - iATR(NULL, NULL, 10, bar)/2;
      }
      else if (stoch <= signalLevelShort) {
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
