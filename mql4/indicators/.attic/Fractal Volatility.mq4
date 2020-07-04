/**
 * Fractal Volatility as the amount price moved in any direction in a given time.
 *
 *
 * TODO:
 *  - The absolute price difference between two times may be equal but price activity (volatility) during that time can
 *    significantly differ. Imagine range bars. The value calculated by this indicator resembles something similar to the
 *    number of completed range bars per time. The displayed unit is "pip", that's range bars of 1 pip size.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Vola.Periods = 32;
extern string Vola.Type    = "Kaufman* | Intra-Bar";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define VOLA_KAUFMAN          1
#define VOLA_INTRABAR         2

#property indicator_separate_window
#property indicator_buffers   1

#property indicator_color1    Blue
#property indicator_width1    1

// buffers
double bufferVola[];

int volaType;
int volaPeriods;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (ProgramInitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // input validation
   // Vola.Periods
   if (Vola.Periods < 1) return(catch("onInit(1)  Invalid input parameter Vola.Periods = "+ Vola.Periods, ERR_INVALID_INPUT_PARAMETER));
   volaPeriods = Vola.Periods;

   // Vola.Type
   string values[], sValue = StrToLower(Vola.Type);
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("kaufman",   sValue)) { volaType = VOLA_KAUFMAN;  Vola.Type = "Kaufman";   }
   else if (StrStartsWith("intra-bar", sValue)) { volaType = VOLA_INTRABAR; Vola.Type = "Intra-Bar"; }
   else                  return(catch("onInit(2)  Invalid input parameter Vola.Type = "+ DoubleQuoteStr(Vola.Type), ERR_INVALID_INPUT_PARAMETER));

   // buffer management
   SetIndexBuffer(0, bufferVola);

   // data display configuration, names, labels
   string name = "Fractal Volatility("+ Vola.Periods +")";
   IndicatorShortName(name +"  ");                          // subwindow and context menu
   SetIndexLabel(0, name);                                  // "Data" window and tooltips
   IndicatorDigits(1);

   // drawing options and styles
   SetIndicatorOptions();

   return(catch("onInit(3)"));
}


/**
 * Called before recompilation.
 *
 * @return int - error status
 */
int onDeinitRecompile() {
   StoreInputParameters();
   return(last_error);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // under specific circumstances buffers may not be initialized on the first tick after terminal start
   if (!ArraySize(bufferVola)) return(log("onTick(1)  size(bufferVola) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(bufferVola, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferVola, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int startBar = Min(ChangedBars-1, Bars-volaPeriods-1);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid indicator values
   for (int bar=startBar; bar >= 0; bar--) {
      bufferVola[bar] = Volatility(bar);
   }
   return(last_error);
}


/**
 * Calculate and return the volatility for a bar.
 *
 * @param  int bar
 *
 * @return double - volatility in pip
 */
double Volatility(int bar) {
   int i, prev, curr;
   double vola = 0;

   switch (volaType) {
      case VOLA_KAUFMAN:
         for (i=volaPeriods-1; i >= 0; i--) {
            vola += MathAbs(Close[bar+i+1] - Close[bar+i]);
         }
         break;

      case VOLA_INTRABAR:
         for (i=volaPeriods-1; i >= 0; i--) {
            prev  = bar+i+1;
            curr  = bar+i;
            vola += MathAbs(Close[prev] - Open[curr]);

            if (LT(Open[curr], Close[curr])) {              // bullish bar
               vola += MathAbs(Open[curr] - Low  [curr]);
               vola += MathAbs(Low [curr] - High [curr]);
               vola += MathAbs(High[curr] - Close[curr]);
            }
            else {                                          // bearish or unchanged bar
               vola += MathAbs(Open[curr] - High [curr]);
               vola += MathAbs(High[curr] - Low  [curr]);
               vola += MathAbs(Low [curr] - Close[curr]);
            }
         }
         break;
   }
   return(NormalizeDouble(vola/Pips, 1));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   string name = __NAME();
   Chart.StoreInt   (name +".input.Vola.Periods", Vola.Periods);
   Chart.StoreString(name +".input.Vola.Type",    Vola.Type   );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string name = __NAME();
   Chart.RestoreInt   (name +".input.Vola.Periods", Vola.Periods);
   Chart.RestoreString(name +".input.Vola.Type",    Vola.Type   );
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Vola.Periods=", Vola.Periods,              ";", NL,
                            "Vola.Type=",    DoubleQuoteStr(Vola.Type), ";")
   );
}
