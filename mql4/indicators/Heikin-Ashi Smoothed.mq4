/**
 * A Heikin-Ashi indicator with optional smoothing of input and output values.
 *
 *
 * Supported Moving-Averages:
 *  • SMA  - Simple Moving Average:          equal bar weighting
 *  • LWMA - Linear Weighted Moving Average: bar weighting using a linear function
 *  • EMA  - Exponential Moving Average:     bar weighting using an exponential function
 *  • SMMA - Smoothed Moving Average:        same as EMA, it holds: SMMA(n) = EMA(2*n-1)
 *
 * Indicator buffers for iCustom():
 *  • HeikinAshi.MODE_TREND: trend direction and length
 *    - trend direction:     positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:        the absolute direction value is the length of the trend in bars since the last reversal
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Input.MA.Method   = "none | SMA | LWMA | EMA*";           // averaging of input prices        Genesis: SMMA(6) = EMA(11)
extern int    Input.MA.Periods  = 11;
extern string Output.MA.Method  = "none | SMA | LWMA* | EMA";           // averaging of HA values           Genesis: LWMA(2)
extern int    Output.MA.Periods = 2;

extern color  Color.BarUp       = Blue;
extern color  Color.BarDown     = Red;

extern bool   ShowWicks         = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@Trend.mqh>
#include <functions/ManageIndicatorBuffer.mqh>

#define MODE_OUT_OPEN         0                       // indicator buffer ids
#define MODE_OUT_CLOSE        1
#define MODE_OUT_HIGHLOW      2
#define MODE_OUT_LOWHIGH      3

#define MODE_TREND            HeikinAshi.MODE_TREND   // 4

#define MODE_HA_OPEN          5
#define MODE_HA_HIGH          6
#define MODE_HA_LOW           7
#define MODE_HA_CLOSE         8                       // managed by the framework


#property indicator_chart_window
#property indicator_buffers   4                       // buffers visible in input dialog
int       terminal_buffers  = 8;                      // buffers managed by the terminal
int       framework_buffers = 1;                      // buffers managed by the framework

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE

double haOpen [];
double haHigh [];
double haLow  [];
double haClose[];

double outOpen   [];
double outClose  [];
double outHighLow[];                                  // holds the High of a bearish output bar
double outLowHigh[];                                  // holds the High of a bullish output bar

double trend[];

int    inputMaMethod;
int    inputMaPeriods;

int    outputMaMethod;
int    outputMaPeriods;

string indicatorName;
string chartLegendLabel;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // Input.MA
   string sValues[], sValue=StrTrim(Input.MA.Method);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = StrTrim(sValues[size-1]);
   }
   if (!StringLen(sValue) || StrCompareI(sValue, "none")) {
      inputMaMethod = EMPTY;
   }
   else {
      inputMaMethod = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
      if (inputMaMethod == -1)   return(catch("onInit(1)  Invalid input parameter Input.MA.Method: "+ DoubleQuoteStr(Input.MA.Method), ERR_INVALID_INPUT_PARAMETER));
   }
   Input.MA.Method = MaMethodDescription(inputMaMethod, false);
   if (!IsEmpty(inputMaMethod)) {
      if (Input.MA.Periods < 0)  return(catch("onInit(2)  Invalid input parameter Input.MA.Periods: "+ Input.MA.Periods, ERR_INVALID_INPUT_PARAMETER));
      inputMaPeriods = ifInt(!Input.MA.Periods, 1, Input.MA.Periods);
      if (inputMaPeriods == 1) inputMaMethod = EMPTY;
   }

   // Output.MA
   sValue = StrTrim(Output.MA.Method);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = StrTrim(sValues[size-1]);
   }
   if (!StringLen(sValue) || StrCompareI(sValue, "none")) {
      outputMaMethod = EMPTY;
   }
   else {
      outputMaMethod = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
      if (outputMaMethod == -1)  return(catch("onInit(3)  Invalid input parameter Output.MA.Method: "+ DoubleQuoteStr(Output.MA.Method), ERR_INVALID_INPUT_PARAMETER));
   }
   Output.MA.Method = MaMethodDescription(outputMaMethod, false);
   if (!IsEmpty(outputMaMethod)) {
      if (Output.MA.Periods < 0) return(catch("onInit(4)  Invalid input parameter Output.MA.Periods: "+ Output.MA.Periods, ERR_INVALID_INPUT_PARAMETER));
      outputMaPeriods = ifInt(!Output.MA.Periods, 1, Output.MA.Periods);
      if (outputMaPeriods == 1) outputMaMethod = EMPTY;
   }

   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.BarUp   == 0xFF000000) Color.BarUp   = CLR_NONE;
   if (Color.BarDown == 0xFF000000) Color.BarDown = CLR_NONE;


   // buffer management
   SetIndexBuffer(MODE_OUT_OPEN,    outOpen   );
   SetIndexBuffer(MODE_OUT_CLOSE,   outClose  );
   SetIndexBuffer(MODE_OUT_HIGHLOW, outHighLow);
   SetIndexBuffer(MODE_OUT_LOWHIGH, outLowHigh);
   SetIndexBuffer(MODE_TREND,       trend     );
   SetIndexBuffer(MODE_HA_OPEN,     haOpen    );
   SetIndexBuffer(MODE_HA_HIGH,     haHigh    );
   SetIndexBuffer(MODE_HA_LOW,      haLow     );

   // chart legend
   if (!IsSuperContext()) {
       chartLegendLabel = CreateLegendLabel();
       RegisterObject(chartLegendLabel);
   }

   // names, labels and display options
   indicatorName = "Heikin-Ashi";               // or  Heikin-Ashi(SMA(10))  or  EMA(Heikin-Ashi(SMA(10)), 5)
   if (!IsEmpty(inputMaMethod))  indicatorName = indicatorName +"("+ Input.MA.Method +"("+ inputMaPeriods +"))";
   if (!IsEmpty(outputMaMethod)) indicatorName = Output.MA.Method +"("+ indicatorName +", "+ outputMaPeriods +")";

   IndicatorShortName(indicatorName);           // chart tooltips and context menu
   SetIndexLabel(MODE_OUT_OPEN,    NULL);       // chart tooltips and "Data" window
   SetIndexLabel(MODE_OUT_CLOSE,   NULL);
   SetIndexLabel(MODE_OUT_HIGHLOW, NULL);
   SetIndexLabel(MODE_OUT_LOWHIGH, NULL);
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   // after legend/label processing: replace disabled smoothing with equal SMA(1) to simplify calculations
   if (IsEmpty(inputMaMethod)) {
      inputMaMethod  = MODE_SMA;
      inputMaPeriods = 1;
   }
   if (IsEmpty(outputMaMethod)) {
      outputMaMethod  = MODE_SMA;
      outputMaPeriods = 1;
   }
   return(catch("onInit(7)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // under undefined conditions on the first tick after terminal start buffers may not yet be initialized
   if (!ArraySize(haOpen)) return(log("onTick(1)  size(haOpen) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   ManageIndicatorBuffer(MODE_HA_CLOSE, haClose);

   // reset all buffers before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(haOpen,     0);
      ArrayInitialize(haHigh,     0);
      ArrayInitialize(haLow,      0);
      ArrayInitialize(haClose,    0);
      ArrayInitialize(outOpen,    EMPTY_VALUE);
      ArrayInitialize(outClose,   EMPTY_VALUE);
      ArrayInitialize(outHighLow, EMPTY_VALUE);
      ArrayInitialize(outLowHigh, EMPTY_VALUE);
      ArrayInitialize(trend,      0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(haOpen,     Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(haHigh,     Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(haLow,      Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(haClose,    Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(outOpen,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(outClose,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(outHighLow, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(outLowHigh, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(trend,      Bars, ShiftedBars, 0);
   }


   // calculate start bars
   int haBars      = Bars-inputMaPeriods;
   int haStartBar  = Min(haBars, ChangedBars) - 1;
   int outInitBars = ifInt(outputMaMethod==MODE_EMA || outputMaMethod==MODE_SMMA, Max(10, outputMaPeriods*3), 0);    // IIR filters need at least 10 bars for initialization
   int outBars     = haBars-outInitBars+1;
   int outStartBar = Min(outBars, ChangedBars) - 1;
   if (outStartBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));

   double inO,  inH,  inL,  inC;                      // input prices
   double outO, outH, outL, outC, dNull[];            // output prices


   // initialize HA values of the oldest bar
   int bar = haStartBar;
   if (!haOpen[bar+1]) {
      inO = iMA(NULL, NULL, inputMaPeriods, 0, inputMaMethod, PRICE_OPEN,  bar+1);
      inH = iMA(NULL, NULL, inputMaPeriods, 0, inputMaMethod, PRICE_HIGH,  bar+1);
      inL = iMA(NULL, NULL, inputMaPeriods, 0, inputMaMethod, PRICE_LOW,   bar+1);
      inC = iMA(NULL, NULL, inputMaPeriods, 0, inputMaMethod, PRICE_CLOSE, bar+1);
      haOpen [bar+1] =  inO;
      haClose[bar+1] = (inO + inH + inL + inC)/4;
   }

   // recalculate changed HA bars
   for (; bar >= 0; bar--) {
      inO = iMA(NULL, NULL, inputMaPeriods, 0, inputMaMethod, PRICE_OPEN,  bar);
      inH = iMA(NULL, NULL, inputMaPeriods, 0, inputMaMethod, PRICE_HIGH,  bar);
      inL = iMA(NULL, NULL, inputMaPeriods, 0, inputMaMethod, PRICE_LOW,   bar);
      inC = iMA(NULL, NULL, inputMaPeriods, 0, inputMaMethod, PRICE_CLOSE, bar);

      haOpen [bar] = (haOpen[bar+1] + haClose[bar+1])/2;
      haClose[bar] = (inO + inH + inL + inC)/4;
      haHigh [bar] = MathMax(inH, haOpen[bar]);
      haLow  [bar] = MathMin(inL, haOpen[bar]);
   }

   // recalculate changed output bars (2nd smoothing)
   for (bar=outStartBar; bar >= 0; bar--) {
      outO = iMAOnArray(haOpen,  WHOLE_ARRAY, outputMaPeriods, 0, outputMaMethod, bar);
      outH = iMAOnArray(haHigh,  WHOLE_ARRAY, outputMaPeriods, 0, outputMaMethod, bar);
      outL = iMAOnArray(haLow,   WHOLE_ARRAY, outputMaPeriods, 0, outputMaMethod, bar);
      outC = iMAOnArray(haClose, WHOLE_ARRAY, outputMaPeriods, 0, outputMaMethod, bar);

      outOpen [bar] = outO;
      outClose[bar] = outC;

      if (outO < outC) {
         outLowHigh[bar] = outH;                      // bullish bar, the High goes into the up-colored buffer
         outHighLow[bar] = outL;
      }
      else {
         outHighLow[bar] = outH;                      // bearish bar, the High goes into the down-colored buffer
         outLowHigh[bar] = outL;
      }
      UpdateTrend(bar);
   }

   if (!IsSuperContext()) {
      @Trend.UpdateLegend(chartLegendLabel, indicatorName, "", Color.BarUp, Color.BarDown, outClose[0], Digits, trend[0], Time[0]);
   }
   return(last_error);
}


/**
 * Update the Heikin-Ashi trend buffer. Trend is considered up on a bullish and considered down on a bearish Heikin-Ashi bar.
 *
 * @param  int bar - bar offset to update
 */
void UpdateTrend(int bar) {
   int currTrend = 0;

   if (outOpen[bar]!=EMPTY_VALUE && outClose[bar]!=EMPTY_VALUE) {
      if (outClose[bar] > outOpen[bar]) currTrend = +1;
      else                              currTrend = -1;
   }

   if (bar == Bars-1) {
      trend[bar] = currTrend;
   }
   else {
      int prevTrend = trend[bar+1];

      if      (currTrend == +1) trend[bar] = Max(prevTrend, 0) + 1;
      else if (currTrend == -1) trend[bar] = Min(prevTrend, 0) - 1;
      else  /*!currTrend*/      trend[bar] = prevTrend + Sign(prevTrend);
   }
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(terminal_buffers);
   int drawType = ifInt(ShowWicks, DRAW_HISTOGRAM, DRAW_NONE);

   SetIndexStyle(MODE_OUT_OPEN,    DRAW_HISTOGRAM, EMPTY, 3, Color.BarDown);  // in histograms the larger of both values
   SetIndexStyle(MODE_OUT_CLOSE,   DRAW_HISTOGRAM, EMPTY, 3, Color.BarUp  );  // determines the color to use
   SetIndexStyle(MODE_OUT_HIGHLOW, drawType,       EMPTY, 1, Color.BarDown);
   SetIndexStyle(MODE_OUT_LOWHIGH, drawType,       EMPTY, 1, Color.BarUp  );
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Input.MA.Method=",   DoubleQuoteStr(Input.MA.Method),  ";", NL,
                            "Input.MA.Periods=",  Input.MA.Periods,                 ";", NL,
                            "Output.MA.Method=",  DoubleQuoteStr(Output.MA.Method), ";", NL,
                            "Output.MA.Periods=", Output.MA.Periods,                ";", NL,
                            "Color.BarUp=",       ColorToStr(Color.BarUp),          ";", NL,
                            "Color.BarDown=",     ColorToStr(Color.BarDown),        ";", NL,
                            "ShowWicks=",         BoolToStr(ShowWicks),             ";")
   );
}
