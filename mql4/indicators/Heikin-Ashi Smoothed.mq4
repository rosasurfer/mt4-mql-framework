/**
 * A Heikin-Ashi indicator with optional smoothing of input and output prices.
 *
 * Supported Moving-Average types:
 *  • SMA  - Simple Moving Average:          equal bar weighting
 *  • LWMA - Linear Weighted Moving Average: bar weighting using a linear function
 *  • EMA  - Exponential Moving Average:     bar weighting using an exponential function
 *  • SMMA - Smoothed Moving Average:        same as EMA, it holds: SMMA(n) = EMA(2*n-1)
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Input.MA.Method   = "none | SMA | LWMA | EMA | SMMA*";    // averaging of input prices        Genesis: SMMA(6) = EMA(11)
extern int    Input.MA.Periods  = 0;
extern string Output.MA.Method  = "none | SMA | LWMA* | EMA | SMMA";    // averaging of HA values           Genesis: LWMA(2)
extern int    Output.MA.Periods = 0;

extern color  Color.BarUp       = Blue;
extern color  Color.BarDown     = Red;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@Trend.mqh>

#define MODE_OUT_OPEN         0                 // indicator buffer ids
#define MODE_OUT_CLOSE        1
#define MODE_OUT_HIGHLOW      2
#define MODE_OUT_LOWHIGH      3
#define MODE_HA_OPEN          4
#define MODE_HA_HIGH          5
#define MODE_HA_LOW           6
#define MODE_HA_CLOSE         7
#define MODE_TREND            8

#property indicator_chart_window
#property indicator_buffers   4                 // buffers visible in input dialog
int       terminal_buffers  = 8;                // buffers managed by the terminal
int       framework_buffers = 1;                // buffers managed by the framework

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
double outHighLow[];                            // holds the High of a bearish output bar
double outLowHigh[];                            // holds the High of a bullish output bar

double doubleBuffer[];                          // manually managed buffers
int    intBuffer   [];

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

   // Output.MA.Method
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
   SetIndexBuffer(MODE_HA_OPEN,     haOpen    );
   SetIndexBuffer(MODE_HA_HIGH,     haHigh    );
   SetIndexBuffer(MODE_HA_LOW,      haLow     );
   SetIndexBuffer(MODE_HA_CLOSE,    haClose   );
   SetIndexBuffer(MODE_OUT_OPEN,    outOpen   );
   SetIndexBuffer(MODE_OUT_CLOSE,   outClose  );
   SetIndexBuffer(MODE_OUT_HIGHLOW, outHighLow);
   SetIndexBuffer(MODE_OUT_LOWHIGH, outLowHigh);

   // chart legend
   if (!IsSuperContext()) {
       chartLegendLabel = CreateLegendLabel();
       RegisterObject(chartLegendLabel);
   }

   // names, labels and display options
   indicatorName = "Heikin-Ashi";               // or  Heikin-Ashi(SMA(10))  or  EMA(Heikin-Ashi(SMA(10)), 5)
   if (!IsEmpty(inputMaMethod))  indicatorName = indicatorName +"("+ Input.MA.Method +"("+ inputMaPeriods +"))";
   if (!IsEmpty(outputMaMethod)) indicatorName = Output.MA.Method +"("+ indicatorName +", "+ outputMaPeriods +")";

   IndicatorShortName(indicatorName);           // chart context menu
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

   ManageIndicatorIntBuffer(MODE_TREND, intBuffer);

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
      ArrayInitialize(intBuffer,  0);
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
   }


   // calculate start bars
   int haBars      = Bars-inputMaPeriods;
   int haStartBar  = Min(haBars, ChangedBars) - 1;    // IIR filters need at least 10 bars for initialization
   int outInitBars = ifInt(outputMaMethod==MODE_EMA || outputMaMethod==MODE_SMMA, Max(10, outputMaPeriods*3), 0);
   int outBars     = haBars-outInitBars+1;
   int outStartBar = Min(outBars, ChangedBars) - 1;
   if (outStartBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));

   double inO,  inH,  inL,  inC;                      // input prices
   double outO, outH, outL, outC;                     // output prices


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
      intBuffer[bar] = bar;
   }

   if (!IsSuperContext()) {
      color legendColor = ifInt(outO < outC, Color.BarUp, Color.BarDown);
      @Trend.UpdateLegend(chartLegendLabel, indicatorName, "", legendColor, legendColor, outC, Digits, NULL, Time[0]);
   }
   return(last_error);
}


/**
 * Manage an additional indicator buffer for integers. In MQL4.0 the terminal manages a maximum of 8 indicator buffers.
 * Additional buffers must be managed by the framework. Additional buffers are for internal calculations only, they can't be
 * accessed via iCustom().
 *
 * @param  int id       - buffer id
 * @param  int buffer[] - buffer
 *
 * @return bool - success status
 */
bool ManageIndicatorIntBuffer(int id, int buffer[]) {
   if (id < 0)                                                 return(!catch("ManageIndicatorIntBuffer(1)  invalid parameter id: "+ id, ERR_INVALID_PARAMETER));
   if (__ExecutionContext[EC.programCoreFunction] != CF_START) return(!catch("ManageIndicatorIntBuffer(2)  invalid calling context: "+ ProgramTypeDescription(__ExecutionContext[EC.programType]) +"::"+ CoreFunctionDescription(__ExecutionContext[EC.programCoreFunction]), ERR_ILLEGAL_STATE));
   if (!Bars)                                                  return(!catch("ManageIndicatorIntBuffer(3)  Bars = 0", ERR_ILLEGAL_STATE));

   // maintain a metadata array {id => data[]} to support multiple buffers
   #define IB.Tick            0                                // last Tick value for detecting multiple calls during the same tick
   #define IB.Bars            1                                // last number of bars
   #define IB.FirstBarTime    2                                // last opentime of the newest bar
   #define IB.LastBarTime     3                                // last opentime of the oldest bar

   int data[][4];                                              // TODO: reset data on account change
   if (ArraySize(data) <= id) {
      ArrayResize(data, id+1);                                 // id => array key
   }
   if (Tick == data[id][IB.Tick]) return(true);                // execute only once per tick


   if (Bars == data[id][IB.Bars]) {                            // number of Bars unchanged
      if (Time[Bars-1] != data[id][IB.LastBarTime]) {          // last bar changed: bars have been shifted off the end
         warn("ManageIndicatorIntBuffer(4)  number of bars unchanged but oldest bar differs, hit timeseries MAX_CHART_BARS? (bars="+ Bars +", lastBar="+ TimeToStr(Time[Bars-1], TIME_FULL) +", prevLastBar="+ TimeToStr(data[id][IB.LastBarTime], TIME_FULL) +")");
         // TODO: find previous FirstBarTime and shift content accordingly
      }  //else                                                // last bar still the same: nothing to do (a regular tick)
   }
   else {                                                      // number of Bars changed
      if (Bars < data[id][IB.Bars]) return(!catch("ManageIndicatorIntBuffer(5)  number of bars decreased from "+ data[id][IB.Bars] +" to "+ Bars +" (lastBar="+ TimeToStr(Time[Bars-1], TIME_FULL) +", prevLastBar="+ TimeToStr(data[id][IB.LastBarTime], TIME_FULL) +")", ERR_ILLEGAL_STATE));
      ArraySetAsSeries(buffer, false);                         // update buffer size
      ArrayResize(buffer, Bars);
      ArraySetAsSeries(buffer, true);                          // new bars may have been inserted or appended: both cases are covered by ChangedBars
      debug("ManageIndicatorIntBuffer(6)  increased buffer size from "+ data[id][IB.Bars] +" to "+ Bars);

      if (Time[Bars-1] != data[id][IB.LastBarTime]) {          // last bar changed: additionally bars have been shifted off the end
         warn("ManageIndicatorIntBuffer(7)  number of bars unchanged but oldest bar differs, hit timeseries MAX_CHART_BARS? (bars="+ Bars +", lastBar="+ TimeToStr(Time[Bars-1], TIME_FULL) +", prevLastBar="+ TimeToStr(data[id][IB.LastBarTime], TIME_FULL) +")");
         // TODO: find previous FirstBarTime and shift content accordingly
      }
   }

   data[id][IB.Tick        ] = Tick;
   data[id][IB.Bars        ] = Bars;
   data[id][IB.FirstBarTime] = Time[0];
   data[id][IB.LastBarTime ] = Time[Bars-1];

   // safety double-check
   if (ArraySize(buffer) != Bars)
      return(!catch("ManageIndicatorIntBuffer(8)  size(buffer)="+ ArraySize(buffer) +" != Bars="+ Bars, ERR_RUNTIME_ERROR));
   return(!catch("ManageIndicatorIntBuffer(9)"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(terminal_buffers);

   SetIndexStyle(MODE_OUT_OPEN,    DRAW_HISTOGRAM, EMPTY, 3, Color.BarDown);  // in histograms the larger of both values
   SetIndexStyle(MODE_OUT_CLOSE,   DRAW_HISTOGRAM, EMPTY, 3, Color.BarUp  );  // determines the color to use
   SetIndexStyle(MODE_OUT_HIGHLOW, DRAW_HISTOGRAM, EMPTY, 1, Color.BarDown);
   SetIndexStyle(MODE_OUT_LOWHIGH, DRAW_HISTOGRAM, EMPTY, 1, Color.BarUp  );
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
                            "Color.BarDown=",     ColorToStr(Color.BarDown),        ";")
   );
}
