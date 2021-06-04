/**
 * Ehlers' Fisher Transform
 *
 * as described in his book "Cybernetic Analysis for Stocks and Futures". This indicator is a different visualization of a
 * smoothed Stochastic oscillator.
 *
 *
 * Indicator buffers for iCustom():
 *  • Fisher.MODE_MAIN:    oscillator main values
 *  • Fisher.MODE_SECTION: oscillator section and section length
 *    - section: positive values (+1...+n) denote an oscillator above zero, negative ones (-1...-n) an oscillator below zero
 *    - length:  the absolute value is each histogram's section length (bars since the last crossing of zero)
 *
 * @see  "/etc/doc/ehlers/Cybernetic Analysis for Stocks and Futures [Ehlers, 2004].pdf"
 *
 *
 * TODO:
 *    - implement customizable moving averages for Stochastic and Fisher Transform
 *    - implement Max.Bars
 *    - implement PRICE_* types
 *    - check required run-up period
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int   Fisher.Periods        = 10;

extern color Histogram.Color.Upper = LimeGreen;
extern color Histogram.Color.Lower = Red;
extern int   Histogram.Style.Width = 2;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_MAIN             Fisher.MODE_MAIN              // indicator buffer ids
#define MODE_SECTION          Fisher.MODE_SECTION
#define MODE_UPPER_SECTION    2
#define MODE_LOWER_SECTION    3
#define MODE_PRICE            4
#define MODE_NORMALIZED       5

#property indicator_separate_window
#property indicator_buffers   4                             // buffers visible in input dialog
int       terminal_buffers  = 6;                            // buffers managed by the terminal

double fisherMain      [];                                  // main value:                invisible, displayed in "Data" window
double fisherSection   [];                                  // direction and length:      invisible
double fisherUpper     [];                                  // positive histogram values: visible
double fisherLower     [];                                  // negative histogram values: visible
double rawPrices       [];                                  // used raw prices:           invisible
double normalizedPrices[];                                  // normalized prices:         invisible


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (ProgramInitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // (1) validate inputs
   // Fisher.Periods
   if (Fisher.Periods < 1)        return(catch("onInit(1)  Invalid input parameter Fisher.Periods = "+ Fisher.Periods, ERR_INVALID_INPUT_PARAMETER));

   // Colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Histogram.Color.Upper == 0xFF000000) Histogram.Color.Upper = CLR_NONE;
   if (Histogram.Color.Lower == 0xFF000000) Histogram.Color.Lower = CLR_NONE;

   // Styles
   if (Histogram.Style.Width < 0) return(catch("onInit(2)  Invalid input parameter Histogram.Style.Width = "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width > 5) return(catch("onInit(3)  Invalid input parameter Histogram.Style.Width = "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));


   // (2) setup buffer management
   SetIndexBuffer(MODE_MAIN,          fisherMain      );    // main values:               invisible, displayed in "Data" window
   SetIndexBuffer(MODE_SECTION,       fisherSection   );    // section and length:        invisible
   SetIndexBuffer(MODE_UPPER_SECTION, fisherUpper     );    // positive histogram values: visible
   SetIndexBuffer(MODE_LOWER_SECTION, fisherLower     );    // negative histogram values: visible
   SetIndexBuffer(MODE_PRICE,         rawPrices       );    // used raw prices:           invisible
   SetIndexBuffer(MODE_NORMALIZED,    normalizedPrices);    // normalized prices:         invisible


   // (3) data display configuration, names and labels
   string name = "Fisher Transform("+ Fisher.Periods +")";
   IndicatorShortName(name +"  ");                          // chart subwindow and context menu
   SetIndexLabel(MODE_MAIN,          name);                 // chart tooltips and "Data" window
   SetIndexLabel(MODE_SECTION,       NULL);
   SetIndexLabel(MODE_UPPER_SECTION, NULL);
   SetIndexLabel(MODE_LOWER_SECTION, NULL);
   SetIndexLabel(MODE_PRICE,         NULL);
   SetIndexLabel(MODE_NORMALIZED,    NULL);
   IndicatorDigits(2);


   // (4) drawing options and styles
   int startDraw = 0;
   //SetIndexDrawBegin(MODE_MAIN,        INT_MAX  );
   //SetIndexDrawBegin(MODE_SECTION,     INT_MAX  );
   SetIndexDrawBegin(MODE_UPPER_SECTION, startDraw);
   SetIndexDrawBegin(MODE_LOWER_SECTION, startDraw);
   SetIndicatorOptions();

   return(catch("onInit(4)"));
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
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(fisherMain)) return(logInfo("onTick(1)  size(fisherMain) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(fisherMain,       EMPTY_VALUE);
      ArrayInitialize(fisherSection,               0);
      ArrayInitialize(fisherUpper,      EMPTY_VALUE);
      ArrayInitialize(fisherLower,      EMPTY_VALUE);
      ArrayInitialize(rawPrices,        EMPTY_VALUE);
      ArrayInitialize(normalizedPrices, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(fisherMain,       Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(fisherSection,    Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(fisherUpper,      Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(fisherLower,      Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(rawPrices,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(normalizedPrices, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int maxBar = Bars-Fisher.Periods;
   int startbar = Min(ChangedBars-1, maxBar);
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid prices
   for (int bar=ChangedBars-1; bar >= 0; bar--) {
      rawPrices[bar] = iMA(NULL, NULL, 1, 0, MODE_SMA, PRICE_MEDIAN, bar);
   }


   double range, rangeHigh, rangeLow, relPrice, centeredPrice, limit=0.9999999999999;


   // (3) recalculate invalid indicator values
   for (bar=startbar; bar >= 0; bar--) {
      rangeHigh = rawPrices[ArrayMaximum(rawPrices, Fisher.Periods, bar)];
      rangeLow  = rawPrices[ArrayMinimum(rawPrices, Fisher.Periods, bar)];
      range     = rangeHigh - rangeLow;

      if (NE(rangeHigh, rangeLow, Digits)) relPrice = (rawPrices[bar]-rangeLow) / range;  // values: 0...1 (a Stochastic)
      else                                 relPrice = 0.5;                                // undefined: assume average value
      centeredPrice = 2*relPrice - 1;                                                     // values: -1...+1

      if (bar == maxBar) {
         normalizedPrices[bar] = centeredPrice;
         fisherMain      [bar] = MathLog((1+normalizedPrices[bar])/(1-normalizedPrices[bar]));
      }
      else {
         normalizedPrices[bar] = 0.33*centeredPrice + 0.67*normalizedPrices[bar+1];       // EMA(5): periods = 2/alpha - 1;   alpha = 2/(periods+1)
         normalizedPrices[bar] = MathMax(MathMin(normalizedPrices[bar], limit), -limit);  // limit values to the original range
         fisherMain      [bar] = 0.5*MathLog((1+normalizedPrices[bar])/(1-normalizedPrices[bar])) + 0.5*fisherMain[bar+1]; // EMA(3)
      }

      if (fisherMain[bar] > 0) {
         fisherUpper[bar] = fisherMain[bar];
         fisherLower[bar] = EMPTY_VALUE;
      }
      else {
         fisherUpper[bar] = EMPTY_VALUE;
         fisherLower[bar] = fisherMain[bar];
      }

      // update section length
      if      (fisherSection[bar+1] > 0 && fisherSection[bar] >= 0) fisherSection[bar] = fisherSection[bar+1] + 1;
      else if (fisherSection[bar+1] < 0 && fisherSection[bar] <= 0) fisherSection[bar] = fisherSection[bar+1] - 1;
      else                                                          fisherSection[bar] = Sign(fisherMain[bar]);
   }
   return(catch("onTick(2)"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(terminal_buffers);

   int drawType = ifInt(Histogram.Style.Width, DRAW_HISTOGRAM, DRAW_NONE);

   SetIndexStyle(MODE_MAIN,          DRAW_NONE, EMPTY, EMPTY,                 CLR_NONE             );
   SetIndexStyle(MODE_SECTION,       DRAW_NONE, EMPTY, EMPTY,                 CLR_NONE             );
   SetIndexStyle(MODE_UPPER_SECTION, drawType,  EMPTY, Histogram.Style.Width, Histogram.Color.Upper);
   SetIndexStyle(MODE_LOWER_SECTION, drawType,  EMPTY, Histogram.Style.Width, Histogram.Color.Lower);
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   string name = ProgramName();
   Chart.StoreInt   (name +".input.Fisher.Periods",        Fisher.Periods       );
   Chart.StoreColor (name +".input.Histogram.Color.Upper", Histogram.Color.Upper);
   Chart.StoreColor (name +".input.Histogram.Color.Lower", Histogram.Color.Lower);
   Chart.StoreInt   (name +".input.Histogram.Style.Width", Histogram.Style.Width);
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string name = ProgramName();
   Chart.RestoreInt  (name +".input.Fisher.Periods",        Fisher.Periods       );
   Chart.RestoreColor(name +".input.Histogram.Color.Upper", Histogram.Color.Upper);
   Chart.RestoreColor(name +".input.Histogram.Color.Lower", Histogram.Color.Lower);
   Chart.RestoreInt  (name +".input.Histogram.Style.Width", Histogram.Style.Width);
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Fisher.Periods=",        Fisher.Periods,                    ";", NL,
                            "Histogram.Color.Upper=", ColorToStr(Histogram.Color.Upper), ";", NL,
                            "Histogram.Color.Lower=", ColorToStr(Histogram.Color.Lower), ";", NL,
                            "Histogram.Style.Width=", Histogram.Style.Width,             ";")
   );
}
