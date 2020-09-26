/**
 * FX Turbo Marksman
 *
 *
 * EURCHF: int stochPercents =  9;
 * EURGBP: int stochPercents = 16;
 * EURJPY: int stochPercents =  6;
 * EURUSD: int stochPercents = 15;
 * GBPCHF: int stochPercents = 15;
 * GBPJPY: int stochPercents = 10;
 * GBPUSD: int stochPercents =  5;
 * USDCAD: int stochPercents =  9;
 * USDCHF: int stochPercents = 20;
 * USDJPY: int stochPercents =  9;
 *
 * DAX:    int stochPercents =  2;
 * DJIA:   int stochPercents = 15;
 * SP500:  int stochPercents = 16;
 *
 * CRUDE:  int stochPercents =  4;
 * XAUUSD: int stochPercents = 10;
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern bool SoundAlarm = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_DOWN             0           // indicator buffer ids
#define MODE_UP               1

#define SIGNAL_LONG           1           // signal ids used in GlobalVariable*()
#define SIGNAL_SHORT          2

#property indicator_chart_window
#property indicator_buffers   2

#property indicator_color1    Yellow
#property indicator_color2    Blue

double bufferDown[];
double bufferUp  [];

int    stochPercents = 6;               // EURJPY
bool   isLongSignal  = false;
bool   isShortSignal = false;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   SetIndexBuffer(MODE_DOWN, bufferDown);
   SetIndexBuffer(MODE_UP,   bufferUp);
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
   if (!ArraySize(bufferUp)) return(logInfo("onTick(1)  size(bufferUp) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Bars before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(bufferUp,   EMPTY_VALUE);
      ArrayInitialize(bufferDown, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferUp,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferDown, Bars, ShiftedBars, EMPTY_VALUE);
   }


   int startBar     = 500;
   int stochPeriods = stochPercents * 2 + 3;
   double stochHigh = 67 + stochPercents;
   double stochLow  = 33 - stochPercents;

   double stoch[1000];

   for (int bar=startBar-12; bar >= 0; bar--) {
      double sumRange = 0;
      for (int i=bar; i <= bar+9; i++) {
         sumRange += MathAbs(High[i] - Low[i]);
      }
      double avgRange = sumRange/10;

      bool strongMomentum = false;
      for (i=bar; i < bar+6; i++) {
         if (MathAbs(Close[i]-Close[i+3]) >= 4.6*avgRange) {
            strongMomentum = true;
            Alert("Strong momentum at bar "+ bar);
            break;
         }
      }

      if (strongMomentum) int periods = 4;
      else                    periods = stochPeriods;
      stoch[bar] = iStochastic(NULL, NULL, periods, 1, 1, MODE_SMA, 0, MODE_MAIN, bar);      // pricefield: 0=Low/High, 1=Close/Close

      bufferUp  [bar] = 0;
      bufferDown[bar] = 0;

      if (stoch[bar] < stochLow) {
         for (i=1; stoch[bar+i] >= stochLow && stoch[bar+i] <= stochHigh; i++) {}

         if (stoch[bar+i] > stochHigh) {
            bufferDown[bar] = High[bar] + avgRange/2;
            if (bar==1 && !isShortSignal) {
               isShortSignal = true;
               isLongSignal  = false;
            }
         }
      }

      if (stoch[bar] > stochHigh) {
         for (i=1; stoch[bar+i] >= stochLow && stoch[bar+i] <= stochHigh; i++) {}

         if (stoch[bar+i] < stochLow) {
            bufferUp[bar] = Low[bar] - avgRange/2;
            if (bar==1 && !isLongSignal) {
               isLongSignal  = true;
               isShortSignal = false;
            }
         }
      }
   }

   /*
   if (isLongSignal && TimeCurrent() > GlobalVariableGet("SignalTime"+ Symbol() + Period()) && GlobalVariableGet("SignalType" + Symbol() + Period()) != SIGNAL_LONG) {
      if (SoundAlarm) logNotice("onTick(1)  Buy signal");

      datetime time = TimeCurrent() + 60 * (Period() - MathMod(Minute(), Period()));
      GlobalVariableSet("SignalTime" + Symbol() + Period(), time);
      GlobalVariableSet("SignalType" + Symbol() + Period(), SIGNAL_LONG);
   }
   if (isShortSignal && TimeCurrent() > GlobalVariableGet("SignalTime"+ Symbol() + Period()) && GlobalVariableGet("SignalType"+ Symbol() + Period()) != SIGNAL_SHORT) {
      if (SoundAlarm) logNotice("onTick(2)  Sell signal");

      time = TimeCurrent() + 60 * (Period() - MathMod(Minute(), Period()));
      GlobalVariableSet("SignalTime" + Symbol() + Period(), time);
      GlobalVariableSet("SignalType" + Symbol() + Period(), SIGNAL_SHORT);
   }
   */
   return(catch("onTick(3)"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   //SetIndexStyle(int index, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL);

   SetIndexStyle(MODE_UP,   DRAW_ARROW); SetIndexArrow(MODE_UP,   233);    // arrow up
   SetIndexStyle(MODE_DOWN, DRAW_ARROW); SetIndexArrow(MODE_DOWN, 234);    // arrow down
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("SoundAlarm=", BoolToStr(SoundAlarm), ";"));
}
