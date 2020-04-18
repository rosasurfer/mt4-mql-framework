/**
 * Marks long and short periods of BrokeTrader's 1-Hour-Swing system (corresponds with Jagg's version 8)
 *
 *
 * @see  https://www.forexfactory.com/showthread.php?t=970975
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods             = 96;               // 100
extern int    Stochastic.Periods     = 96;               // 100
extern int    Stochastic.MA1.Periods = 10;               //  30 first moving average periods
extern int    Stochastic.MA2.Periods = 6;                //   6 second moving average periods
extern int    RSI.Periods            = 96;               // 100

extern color  Color.MA.Long          = LimeGreen;
extern color  Color.MA.Short         = C'33,150,243';
extern color  Color.Section.Long     = GreenYellow;
extern color  Color.Section.Short    = C'81,211,255';

extern int  Max.Values               = 5000;             // max. amount of values to calculate (-1: all)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@Trend.mqh>

#define MODE_HIST_L_MA        0                          // indicator buffer ids
#define MODE_HIST_L_PRICE     1
#define MODE_HIST_S_MA        2
#define MODE_HIST_S_PRICE     3
#define MODE_MA_L             4                          // MA above histogram
#define MODE_MA_S             5

#property indicator_chart_window
#property indicator_buffers   6                          // buffers visible in input dialog

double maLong        [];                                 // MA long:               visible, displayed in legend
double maShort       [];                                 // MA short:              visible, displayed in legend
double histLongMa    [];                                 // MA long histogram:     visible
double histLongPrice [];                                 // price long histogram:  visible
double histShortMa   [];                                 // MA short histogram:    visible
double histShortPrice[];                                 // price short histogram: visible

int    maPeriods;
int    stochPeriods;
int    stochMa1Periods;
int    stochMa2Periods;
int    rsiPeriods;

bool   lastStateIsBull;
int    maxValues;

string indicatorName;
string chartLegendLabel;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   if (MA.Periods < 1)             return(catch("onInit(1)  Invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   maPeriods = MA.Periods;
   if (Stochastic.Periods < 1)     return(catch("onInit(2)  Invalid input parameter Stochastic.Periods: "+ Stochastic.Periods, ERR_INVALID_INPUT_PARAMETER));
   stochPeriods = Stochastic.Periods;
   if (Stochastic.MA1.Periods < 1) return(catch("onInit(3)  Invalid input parameter Stochastic.MA1.Periods: "+ Stochastic.MA1.Periods, ERR_INVALID_INPUT_PARAMETER));
   stochMa1Periods = Stochastic.MA1.Periods;
   if (Stochastic.MA2.Periods < 1) return(catch("onInit(4)  Invalid input parameter Stochastic.MA2.Periods: "+ Stochastic.MA2.Periods, ERR_INVALID_INPUT_PARAMETER));
   stochMa2Periods = Stochastic.MA2.Periods;
   if (RSI.Periods < 1)            return(catch("onInit(5)  Invalid input parameter RSI.Periods: "+ RSI.Periods, ERR_INVALID_INPUT_PARAMETER));
   rsiPeriods = RSI.Periods;
   if (Max.Values < -1)            return(catch("onInit(6)  Invalid input parameter Max.Values: "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Values==-1, INT_MAX, Max.Values);

   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.MA.Long       == 0xFF000000) Color.MA.Long       = CLR_NONE;
   if (Color.MA.Short      == 0xFF000000) Color.MA.Short      = CLR_NONE;
   if (Color.Section.Long  == 0xFF000000) Color.Section.Long  = CLR_NONE;
   if (Color.Section.Short == 0xFF000000) Color.Section.Short = CLR_NONE;

   // buffer management
   SetIndexBuffer(MODE_MA_L,         maLong        );    // MA long:               visible, displayed in legend
   SetIndexBuffer(MODE_MA_S,         maShort       );    // MA short:              visible, displayed in legend
   SetIndexBuffer(MODE_HIST_L_MA,    histLongMa    );    // MA long histogram:     visible
   SetIndexBuffer(MODE_HIST_L_PRICE, histLongPrice );    // price long histogram:  visible
   SetIndexBuffer(MODE_HIST_S_MA,    histShortMa   );    // MA short histogram:    visible
   SetIndexBuffer(MODE_HIST_S_PRICE, histShortPrice);    // price short histogram: visible

   // chart legend
   indicatorName = "SMA("+ MA.Periods +")";
   if (!IsSuperContext()) {
       chartLegendLabel = CreateLegendLabel(indicatorName);
       ObjectRegister(chartLegendLabel);
   }

   // names, labels and display options
   IndicatorShortName(indicatorName);
   SetIndexLabel(MODE_MA_L,         indicatorName);
   SetIndexLabel(MODE_MA_S,         indicatorName);
   SetIndexLabel(MODE_HIST_L_MA,    NULL);
   SetIndexLabel(MODE_HIST_L_PRICE, NULL);
   SetIndexLabel(MODE_HIST_S_MA,    NULL);
   SetIndexLabel(MODE_HIST_S_PRICE, NULL);
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   // adjust MTF settings
   switch (Period()) {
      //case PERIOD_M1:  smaPeriods *= 60; stochPeriods *= 60; stochMa1Periods *= 60; stochMa2Periods *= 60; rsiPeriods *= 60; break;
      //case PERIOD_M5:  smaPeriods *= 12; stochPeriods *= 12; stochMa1Periods *= 12; stochMa2Periods *= 12; rsiPeriods *= 12; break;
      //case PERIOD_M15: smaPeriods *= 4;  stochPeriods *= 4;  stochMa1Periods *= 4;  stochMa2Periods *= 4;  rsiPeriods *= 4;  break;
      //case PERIOD_M30: smaPeriods *= 2;  stochPeriods *= 2;  stochMa1Periods *= 2;  stochMa2Periods *= 2;  rsiPeriods *= 2;  break;
      //case PERIOD_H1:  smaPeriods *= 1;  stochPeriods *= 1;  stochMa1Periods *= 1;  stochMa2Periods *= 1;  rsiPeriods *= 1;  break;
   }
   return(catch("onInit(7)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   RepositionLegend();
   return(catch("onDeinit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // a not initialized buffer can happen on terminal start under specific circumstances
   if (!ArraySize(maLong)) return(log("onTick(1)  size(maLong) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(maLong,         EMPTY_VALUE);
      ArrayInitialize(maShort,        EMPTY_VALUE);
      ArrayInitialize(histLongMa,     EMPTY_VALUE);
      ArrayInitialize(histLongPrice,  EMPTY_VALUE);
      ArrayInitialize(histShortMa,    EMPTY_VALUE);
      ArrayInitialize(histShortPrice, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(maLong,         Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(maShort,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(histLongMa,     Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(histLongPrice,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(histShortMa,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(histShortPrice, Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int bars     = Min(ChangedBars, maxValues);
   int startBar = Min(bars-1, Bars-maPeriods);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));

   double ma, stoch, price;

   // recalculate changed bars
   for (int i=startBar; i >= 0; i--) {
      histLongMa    [i] = EMPTY_VALUE;
      histLongPrice [i] = EMPTY_VALUE;
      histShortMa   [i] = EMPTY_VALUE;
      histShortPrice[i] = EMPTY_VALUE;

      ma    = iMA(NULL, NULL, maPeriods, 0, MODE_SMA, PRICE_CLOSE, i);
      stoch = GetStochasticOfRSI(i); if (last_error || 0) return(last_error);

      if      (Close[i] > ma && Low [i] > ma) price = Close[i];
      else if (Close[i] < ma && High[i] < ma) price = Close[i];
      else                                    price = ma;

      if      (Close[i] >= ma && stoch >= 40) lastStateIsBull = true;
      else if (Close[i] <  ma && stoch <  60) lastStateIsBull = false;

      if (lastStateIsBull) {
         maLong        [i] = ma;
         maShort       [i] = EMPTY_VALUE;
         histLongMa    [i] = ma;
         histLongPrice [i] = price;
      }
      else {
         maLong        [i] = EMPTY_VALUE;
         maShort       [i] = ma;
         histShortMa   [i] = ma;
         histShortPrice[i] = price;
      }
   }

   if (!IsSuperContext()) {
      color legendColor = ifInt(lastStateIsBull, Green, DodgerBlue);
      @Trend.UpdateLegend(chartLegendLabel, indicatorName, "", legendColor, legendColor, ma, Digits, 0, Time[0]);
   }
   return(catch("onTick(3)"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);

   //SetIndexStyle(int buffer, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor)

   SetIndexStyle(MODE_MA_L,         DRAW_LINE,      EMPTY, 2, Color.MA.Long      );
   SetIndexStyle(MODE_MA_S,         DRAW_LINE,      EMPTY, 2, Color.MA.Short     );
   SetIndexStyle(MODE_HIST_L_MA   , DRAW_HISTOGRAM, EMPTY, 5, Color.Section.Long );
   SetIndexStyle(MODE_HIST_L_PRICE, DRAW_HISTOGRAM, EMPTY, 5, Color.Section.Long );
   SetIndexStyle(MODE_HIST_S_MA   , DRAW_HISTOGRAM, EMPTY, 5, Color.Section.Short);
   SetIndexStyle(MODE_HIST_S_PRICE, DRAW_HISTOGRAM, EMPTY, 5, Color.Section.Short);
}


/**
 * Return a Stochastic(RSI) indicator value.
 *
 * @param  int iBar - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double GetStochasticOfRSI(int iBar) {
   return(iStochasticOfRSI(NULL, stochPeriods, stochMa1Periods, stochMa2Periods, rsiPeriods, Stochastic.MODE_SIGNAL, iBar));
}


/**
 * Load the "Stochastic of RSI" and return an indicator value.
 *
 * @param  int timeframe            - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int stochasticPeriods    - indicator parameter
 * @param  int stochasticMa1Periods - indicator parameter
 * @param  int stochasticMa2Periods - indicator parameter
 * @param  int rsiPeriods           - indicator parameter
 * @param  int iBuffer              - indicator buffer index of the value to return
 * @param  int iBar                 - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double iStochasticOfRSI(int timeframe, int stochasticPeriods, int stochasticMa1Periods, int stochasticMa2Periods, int rsiPeriods, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "Stochastic of RSI",
                          stochasticPeriods,                               // int    Stochastic.Periods
                          stochasticMa1Periods,                            // int    Stochastic.MA1.Periods
                          stochasticMa2Periods,                            // int    Stochastic.MA2.Periods
                          rsiPeriods,                                      // int    RSI.Periods
                          CLR_NONE,                                        // color  Main.Color
                          DodgerBlue,                                      // color  Signal.Color
                          "Line",                                          // string Signal.DrawType
                          1,                                               // int    Signal.DrawWidth
                          -1,                                              // int    Max.Values
                          "",                                              // string ______________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("iStochasticOfRSI(1)", error));
      warn("iStochasticOfRSI(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",             MA.Periods,             ";", NL,
                            "Stochastic.Periods=",     Stochastic.Periods,     ";", NL,
                            "Stochastic.MA1.Periods=", Stochastic.MA1.Periods, ";", NL,
                            "Stochastic.MA2.Periods=", Stochastic.MA2.Periods, ";", NL,
                            "RSI.Periods=",            RSI.Periods,            ";", NL,
                            "Max.Values=",             Max.Values,             ";")
   );
}
