/**
 * Heikin-Ashi Smoothed
 *
 *
 * Supported Moving Average types:
 *  • SMA  - Simple Moving Average:          equal bar weighting
 *  • LWMA - Linear Weighted Moving Average: bar weighting using a linear function
 *  • EMA  - Exponential Moving Average:     bar weighting using an exponential function
 *  • SMMA - Smoothed Moving Average:        same as EMA, it holds: SMMA(n) = EMA(2*n-1)
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Input.MA.Periods  = 6;
extern string Input.MA.Method   = "SMA | LWMA | EMA | SMMA*";     // averaging of input prices     SMMA(6) = EMA(11)

extern int    Output.MA.Periods = 2;
extern string Output.MA.Method  = "SMA | LWMA* | EMA | SMMA";     // averaging of HA values        LWMA(2)

extern color  Color.BarUp       = Blue;
extern color  Color.BarDown     = Red;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_HA_OPEN          0           // indicator buffer ids
#define MODE_HA_CLOSE         1
#define MODE_HA_HIGHLOW       2
#define MODE_HA_LOWHIGH       3

#property indicator_chart_window
#property indicator_buffers   4

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE

double haOpen   [];
double haClose  [];
double haHighLow[];                       // holds the High of a bearish HA bar
double haLowHigh[];                       // holds the High of a bullish HA bar

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
   if (Input.MA.Periods  < 1) return(catch("onInit(1)  Invalid input parameter Input.MA.Periods: "+ Input.MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (Output.MA.Periods < 1) return(catch("onInit(2)  Invalid input parameter Output.MA.Periods: "+ Output.MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   inputMaPeriods  = Input.MA.Periods;
   outputMaPeriods = Output.MA.Periods;

   // Input.MA.Method
   string sValues[], sValue=Input.MA.Method;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   inputMaMethod = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (inputMaMethod == -1)   return(catch("onInit(3)  Invalid input parameter Input.MA.Method: "+ DoubleQuoteStr(Input.MA.Method), ERR_INVALID_INPUT_PARAMETER));
   Input.MA.Method = MaMethodDescription(inputMaMethod);

   // Output.MA.Method
   sValue = Output.MA.Method;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   outputMaMethod = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (outputMaMethod == -1)  return(catch("onInit(5)  Invalid input parameter Output.MA.Method: "+ DoubleQuoteStr(Output.MA.Method), ERR_INVALID_INPUT_PARAMETER));
   Output.MA.Method = MaMethodDescription(outputMaMethod);

   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.BarUp   == 0xFF000000) Color.BarUp   = CLR_NONE;
   if (Color.BarDown == 0xFF000000) Color.BarDown = CLR_NONE;


   // buffer management
   SetIndexBuffer(MODE_HA_OPEN,    haOpen   );
   SetIndexBuffer(MODE_HA_CLOSE,   haClose  );
   SetIndexBuffer(MODE_HA_HIGHLOW, haHighLow);
   SetIndexBuffer(MODE_HA_LOWHIGH, haLowHigh);

   // chart legend
   if (!IsSuperContext()) {
       chartLegendLabel = CreateLegendLabel();
       RegisterObject(chartLegendLabel);
   }

   // names, labels and display options
   indicatorName = "Heikin-Ashi";
   IndicatorShortName(indicatorName);
   SetIndexLabel(MODE_HA_OPEN,    indicatorName +" Open");  // chart tooltips and "Data" window
   SetIndexLabel(MODE_HA_CLOSE,   indicatorName +" Close");
   SetIndexLabel(MODE_HA_HIGHLOW, indicatorName +" H/L");
   SetIndexLabel(MODE_HA_LOWHIGH, indicatorName +" L/H");
   IndicatorDigits(Digits);
   SetIndicatorOptions();

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

   // reset all buffers before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(haOpen,    EMPTY_VALUE);
      ArrayInitialize(haClose,   EMPTY_VALUE);
      ArrayInitialize(haHighLow, EMPTY_VALUE);
      ArrayInitialize(haLowHigh, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(haOpen,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(haClose,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(haHighLow, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(haLowHigh, Bars, ShiftedBars, EMPTY_VALUE);
   }

   double inO, inH, inL, inC;             // input prices
   double haO, haH, haL, haC;             // Heikin-Ashi values
   double maO, maH, maL, maC;             // smoothed Heikin-Ashi output values

   // calculate start bar
   int startBar = Min(ChangedBars-1, Bars-2);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));

   // initialize the oldest bar
   int bar = startBar;
   if (haOpen[bar+1] == EMPTY_VALUE) {
      haOpen [bar+1] =  Open[bar+1];
      haClose[bar+1] = (Open[bar+1] + High[bar+1] + Low[bar+1] + Close[bar+1])/4;
   }

   // recalculate changed bars
   for (; bar >= 0; bar--) {
      inO = Open [bar];
      inH = High [bar];
      inL = Low  [bar];
      inC = Close[bar];

      haO = (haOpen[bar+1] + haClose[bar+1])/2;
      haC = (inO + inH + inL + inC)/4;
      haH = MathMax(inH, MathMax(haO, haC));
      haL = MathMin(inL, MathMin(haO, haC));

      haOpen [bar] = haO;
      haClose[bar] = haC;

      if (haO < haC) {
         haLowHigh[bar] = haH;            // bullish HA bar, the High goes into the up-colored buffer
         haHighLow[bar] = haL;
      }
      else {
         haHighLow[bar] = haH;            // bearish HA bar, the High goes into the down-colored buffer
         haLowHigh[bar] = haL;
      }
   }

   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   SetIndexStyle(MODE_HA_OPEN,    DRAW_HISTOGRAM, EMPTY, 3, Color.BarDown);   // in histograms the larger of both values
   SetIndexStyle(MODE_HA_CLOSE,   DRAW_HISTOGRAM, EMPTY, 3, Color.BarUp  );   // determines the color to use
   SetIndexStyle(MODE_HA_HIGHLOW, DRAW_HISTOGRAM, EMPTY, 1, Color.BarDown);
   SetIndexStyle(MODE_HA_LOWHIGH, DRAW_HISTOGRAM, EMPTY, 1, Color.BarUp  );
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Input.MA.Periods=",  Input.MA.Periods,                 ";", NL,
                            "Input.MA.Method=",   DoubleQuoteStr(Input.MA.Method),  ";", NL,
                            "Output.MA.Periods=", Output.MA.Periods,                ";", NL,
                            "Output.MA.Method=",  DoubleQuoteStr(Output.MA.Method), ";", NL,
                            "Color.BarUp=",       ColorToStr(Color.BarUp),          ";", NL,
                            "Color.BarDown=",     ColorToStr(Color.BarDown),        ";")
   );
}
