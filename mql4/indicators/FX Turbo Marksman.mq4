/**
 * FX Turbo Marksman
 *
 *
 * EURCHF: int lookbackPeriods =  9;
 * EURGBP: int lookbackPeriods = 16;
 * EURJPY: int lookbackPeriods =  6;
 * EURUSD: int lookbackPeriods = 15;
 * GBPCHF: int lookbackPeriods = 15;
 * GBPJPY: int lookbackPeriods = 10;
 * GBPUSD: int lookbackPeriods =  5;
 * USDCAD: int lookbackPeriods =  9;
 * USDCHF: int lookbackPeriods = 20;
 * USDJPY: int lookbackPeriods =  9;
 *
 * DAX:    int lookbackPeriods =  2;
 * DJIA:   int lookbackPeriods = 15;
 * SP500:  int lookbackPeriods = 16;
 *
 * CRUDE:  int lookbackPeriods =  4;
 * XAUUSD: int lookbackPeriods = 10;
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern bool SoundAlarm = true;

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

int    lookbackPeriods = 6;               // EURJPY

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

   GlobalVariableSet("SignalTime"+ Symbol() + Period(), TimeCurrent());
   GlobalVariableSet("SignalType"+ Symbol() + Period(), 0);
   return(catch("onInit(1)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   if (!catch("onDeinit(1)")) {

      GlobalVariableDel("SignalTime"+ Symbol() + Period());
      GlobalVariableDel("SignalType"+ Symbol() + Period());

      if (IsTesting()) {
         int error = GetLastError();
         if (error != ERR_GLOBAL_VARIABLES_PROCESSING) {
            catch("onDeinit(2)", error);
         }
      }
   }
   return(last_error);
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
   int li_36        = lookbackPeriods + 67;
   int li_44        = 33 - lookbackPeriods;
   int stochPeriods = lookbackPeriods * 2 + 3;

   double stoch[1000];

   for (int bar=startBar-12; bar >= 0; bar--) {
      double ld_84 = 0;
      for (int i=bar; i <= bar+9; i++) {
         ld_84 += MathAbs(High[i] - Low[i]);
      }
      double ld_76 = ld_84 / 10;

      bool found = false;
      for (i=bar; i < bar+6; i++) {
         if (MathAbs(Close[i]-Close[i+3]) >= 4.6 * ld_76) {
            found = true;
            break;
         }
      }
      if (found) stochPeriods = 4;

      stoch[bar] = iStochastic(NULL, NULL, stochPeriods, 1, 1, MODE_SMA, 0, MODE_MAIN, bar);     // pricefield: 0=Low/High, 1=Close/Close

      bufferUp  [bar] = 0;
      bufferDown[bar] = 0;

      if (stoch[bar] < li_44) {
         for (int li_16=1; stoch[bar+li_16] >= li_44 && stoch[bar+li_16] <= li_36; li_16++) {}

         if (stoch[bar+li_16] > li_36) {
            bufferDown[bar] = High[bar] + ld_76/2;
            if (bar==1 && !isShortSignal) {
               isShortSignal = true;
               isLongSignal  = false;
            }
         }
      }

      if (stoch[bar] > li_36) {
         for (li_16=1; stoch[bar+li_16] >= li_44 && stoch[bar+li_16] <= li_36; li_16++) {}

         if (stoch[bar+li_16] < li_44) {
            bufferUp[bar] = Low[bar] - ld_76/2;
            if (bar==1 && !isLongSignal) {
               isLongSignal  = true;
               isShortSignal = false;
            }
         }
      }
   }

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
