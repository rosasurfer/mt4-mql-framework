/**
 * Heikin-Ashi Smoothed
 *
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern color Color.BarUp       = Blue;
extern color Color.BarDown     = Red;

extern int   Input.MA.Periods  = 6;
extern int   Input.MA.Method   = 2;
extern int   Output.MA.Periods = 2;
extern int   Output.MA.Method  = 3;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_WICK_A           0                          // indicator buffer ids
#define MODE_WICK_B           1
#define MODE_BODY_A           2
#define MODE_BODY_B           3

#property indicator_chart_window
#property indicator_buffers   4

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE

#property indicator_width1    1
#property indicator_width2    1
#property indicator_width3    3
#property indicator_width4    3

double wickA[];
double wickB[];
double bodyA[];
double bodyB[];

string indicatorName;
string chartLegendLabel;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.BarUp   == 0xFF000000) Color.BarUp   = CLR_NONE;
   if (Color.BarDown == 0xFF000000) Color.BarDown = CLR_NONE;

   // buffer management
   SetIndexBuffer(MODE_WICK_A, wickA);
   SetIndexBuffer(MODE_WICK_B, wickB);
   SetIndexBuffer(MODE_BODY_A, bodyA);
   SetIndexBuffer(MODE_BODY_B, bodyB);

   // chart legend
   if (!IsSuperContext()) {
       chartLegendLabel = CreateLegendLabel();
       RegisterObject(chartLegendLabel);
   }

   // names, labels and display options
   indicatorName = "Heikin-Ashi";
   IndicatorShortName(indicatorName);
   SetIndexLabel(MODE_WICK_A, indicatorName +" wick A"); // chart tooltips and "Data" window
   SetIndexLabel(MODE_WICK_B, indicatorName +" wick B");
   SetIndexLabel(MODE_BODY_A, indicatorName +" body B");
   SetIndexLabel(MODE_BODY_B, indicatorName +" body B");
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // under unspecific circumstances on the first tick after terminal start buffers may not yet be initialized
   if (!ArraySize(wickA)) return(log("onTick(1)  size(wickA) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));



   double haOpen, haHigh, haLow, haClose;

   if (Bars <= 10) return(0);
   int ExtCountedBars = IndicatorCounted();
   if (ExtCountedBars > 0) ExtCountedBars--;

   for (int bar=Bars-ExtCountedBars-1; bar >= 0; bar--) {
      double inputO = iMA(NULL, NULL, Input.MA.Periods, 0, Input.MA.Method, PRICE_OPEN,  bar);
      double inputH = iMA(NULL, NULL, Input.MA.Periods, 0, Input.MA.Method, PRICE_HIGH,  bar);
      double inputL = iMA(NULL, NULL, Input.MA.Periods, 0, Input.MA.Method, PRICE_LOW,   bar);
      double inputC = iMA(NULL, NULL, Input.MA.Periods, 0, Input.MA.Method, PRICE_CLOSE, bar);

      haOpen  = (buffer5[bar+1] + buffer6[bar+1])/2;
      haClose = (inputO + inputH + inputL + inputC)/4;
      haHigh  = MathMax(inputH, MathMax(haOpen, haClose));
      haLow   = MathMin(inputL, MathMin(haOpen, haClose));

      if (haClose > haOpen) {          // bullish bar
         buffer8[bar] = haHigh;
         buffer7[bar] = haLow;
      }
      else {                           // bearish bar
         buffer7[bar] = haHigh;
         buffer8[bar] = haLow;
      }
      buffer5[bar] = haOpen;
      buffer6[bar] = haClose;
   }

   return(last_error);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Color.BarUp=",       ColorToStr(Color.BarUp),   ";", NL,
                            "Color.BarDown=",     ColorToStr(Color.BarDown), ";", NL,
                            "Input.MA.Periods=",  Input.MA.Periods,          ";", NL,
                            "Input.MA.Method=",   Input.MA.Method,           ";", NL,
                            "Output.MA.Periods=", Output.MA.Periods,         ";", NL,
                            "Output.MA.Method=",  Output.MA.Method,          ";")
   );
}
