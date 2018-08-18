/**
 * Damiani Volameter
 *
 * Rewritten and fixed initial version.
 *
 * @see  version 1.0: https://www.mql5.com/en/code/10118
 * @see  version 3.2: http://www.damianifx.com.br/indicators1.php
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Fast.Periods    = 7;
extern int    Slow.Periods    = 50;
extern double Threshold.Level = 1.1;
extern bool   NonLag          = true;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>

#define MODE_ATR_RATIO        0
#define MODE_STDDEV_RATIO     1

#property indicator_separate_window
#property indicator_buffers   2                                   // configurable buffers (input dialog)
int       allocated_buffers = 2;                                  // used buffers

#property indicator_color1    LimeGreen
#property indicator_width1    2
#property indicator_color2    Tomato
#property indicator_width2    2

// buffers
double bufferAtrRatio   [];
double bufferStdDevRatio[];

double nonLag.K = 0.5;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (InitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // buffer management
   SetIndexBuffer(MODE_ATR_RATIO,    bufferAtrRatio   );
   SetIndexBuffer(MODE_STDDEV_RATIO, bufferStdDevRatio);

   // data display configuration, names and labels
   string shortName = "Damiani Volameter    NonLag="+ BoolToStr(NonLag) +"   ";
   IndicatorShortName(shortName);                                 // subwindow and context menu
   SetIndexLabel(MODE_ATR_RATIO,    "Damiani ATR ratio");         // "Data" window and tooltips
   SetIndexLabel(MODE_STDDEV_RATIO, "Damiani StdDev ratio");
   IndicatorDigits(4);

   // drawing options and styles
   SetIndicatorOptions();

   return(catch("onInit(1)"));
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
   // check for finished buffer initialization (needed on terminal start)
   if (!ArraySize(bufferAtrRatio))
      return(log("onTick(1)  size(bufferAtrRatio) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferAtrRatio,    EMPTY_VALUE);
      ArrayInitialize(bufferStdDevRatio, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferAtrRatio,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferStdDevRatio, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int maxBar = Bars - (Slow.Periods+3);                    // +3 only if NonLag=TRUE
   int startBar = Min(ChangedBars-1, maxBar);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid indicator values
   double fastAtr, slowAtr, atrRatio, fastStdDev, slowStdDev, stdDevRatio;

   for (int bar=startBar; bar >= 0; bar--) {
      fastAtr  = iATR(NULL, NULL, Fast.Periods, bar);
      slowAtr  = iATR(NULL, NULL, Slow.Periods, bar);
      atrRatio = fastAtr/slowAtr;
      if (NonLag)
         atrRatio += nonLag.K * (bufferAtrRatio[bar+1] - bufferAtrRatio[bar+3]);
      bufferAtrRatio[bar] = atrRatio;

      fastStdDev  = iStdDev(NULL, NULL, Fast.Periods, 0, MODE_LWMA, PRICE_TYPICAL, bar);
      slowStdDev  = iStdDev(NULL, NULL, Slow.Periods, 0, MODE_LWMA, PRICE_TYPICAL, bar);
      stdDevRatio = fastStdDev/slowStdDev;

      bufferStdDevRatio[bar] = Threshold.Level - stdDevRatio;
   }
   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(allocated_buffers);

   SetIndexStyle(MODE_ATR_RATIO,    ifInt(indicator_color1==CLR_NONE, DRAW_NONE, DRAW_LINE), EMPTY, EMPTY);
   SetIndexStyle(MODE_STDDEV_RATIO, ifInt(indicator_color2==CLR_NONE, DRAW_NONE, DRAW_LINE), EMPTY, EMPTY);
}


/**
 * Store input parameters in the chart for restauration after recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   Chart.StoreInt   (__NAME__ +".input.Fast.Periods",    Fast.Periods   );
   Chart.StoreInt   (__NAME__ +".input.Slow.Periods",    Slow.Periods   );
   Chart.StoreDouble(__NAME__ +".input.Threshold.Level", Threshold.Level);
   Chart.StoreBool  (__NAME__ +".input.NonLag",          NonLag         );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string label = __NAME__ +".input.Fast.Periods";
   if (ObjectFind(label) == 0) {
      string sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue)) return(!catch("RestoreInputParameters(1)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Fast.Periods = StrToInteger(sValue);                        // (int) string
   }

   label = __NAME__ +".input.Slow.Periods";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue)) return(!catch("RestoreInputParameters(2)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Slow.Periods = StrToInteger(sValue);                        // (int) string
   }

   label = __NAME__ +".input.Threshold.Level";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreInputParameters(3)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Threshold.Level = StrToDouble(sValue);                      // (double) string
   }

   label = __NAME__ +".input.NonLag";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue)) return(!catch("RestoreInputParameters(4)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      int iValue = StrToInteger(sValue);
      if (iValue > 1)             return(!catch("RestoreInputParameters(5)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      NonLag = (iValue);                                          // (bool) (int) string
   }
   return(!catch("RestoreInputParameters(6)"));
}


/**
 * Return a string representation of the input parameters. Used to log iCustom() calls.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "Fast.Periods=",    Fast.Periods,                        "; ",
                            "Slow.Periods=",    Slow.Periods,                        "; ",
                            "Threshold.Level=", NumberToStr(Threshold.Level, ".1+"), "; ",
                            "NonLag=",          BoolToStr(NonLag),                   "; ")
   );
}
