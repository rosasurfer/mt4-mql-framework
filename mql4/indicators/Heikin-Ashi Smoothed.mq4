/**
 * Heikin-Ashi Smoothed
 *
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int Input.MA.Periods  = 6;
extern int Input.MA.Method   = 2;

extern int Output.MA.Periods = 2;
extern int Output.MA.Method  = 3;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define MODE_WICK_DOWN        0           // indicator buffer ids
#define MODE_WICK_UP          1
#define MODE_BODY_DOWN        2
#define MODE_BODY_UP          3

#property indicator_chart_window
#property indicator_buffers   4

#property indicator_color1    Red         // bull bar low, bear bar high
#property indicator_color2    Blue        // bull bar high, bear bar low
#property indicator_color3    Red         // body down
#property indicator_color4    Blue        // body up

#property indicator_width1    1           // bull bar high, bear bar low
#property indicator_width2    1           // bull bar low, bear bar high
#property indicator_width3    3           // body down
#property indicator_width4    3           // body up




double buffer1[];                         // output bull bar high, bear bar low
double buffer2[];                         // output bull bar low, bear bar high
double buffer3[];                         // output body down
double buffer4[];                         // output body up

double buffer5[];
double buffer6[];
double buffer7[];
double buffer8[];


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   IndicatorBuffers(8);

   SetIndexBuffer(0, buffer1); SetIndexStyle(0, DRAW_HISTOGRAM, 0);
   SetIndexBuffer(1, buffer2); SetIndexStyle(1, DRAW_HISTOGRAM, 0);
   SetIndexBuffer(2, buffer3); SetIndexStyle(2, DRAW_HISTOGRAM, 0);
   SetIndexBuffer(3, buffer4); SetIndexStyle(3, DRAW_HISTOGRAM, 0);

   SetIndexBuffer(4, buffer5);
   SetIndexBuffer(5, buffer6);
   SetIndexBuffer(6, buffer7);
   SetIndexBuffer(7, buffer8);

   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
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

   for (bar=0; bar < Bars; bar++) buffer1[bar] = iMAOnArray(buffer7, Bars, Output.MA.Periods, 0, Output.MA.Method, bar);   // output bull bar low, bear bar high
   for (bar=0; bar < Bars; bar++) buffer2[bar] = iMAOnArray(buffer8, Bars, Output.MA.Periods, 0, Output.MA.Method, bar);   // output bull bar high, bear bar low
   for (bar=0; bar < Bars; bar++) buffer3[bar] = iMAOnArray(buffer5, Bars, Output.MA.Periods, 0, Output.MA.Method, bar);   // output body down
   for (bar=0; bar < Bars; bar++) buffer4[bar] = iMAOnArray(buffer6, Bars, Output.MA.Periods, 0, Output.MA.Method, bar);   // output body up

   return(last_error);

   Crossed(NULL, NULL);
}


/**
 *
 */
bool Crossed(double open, double close) {
   static string last_direction = "";

   if (open <= close) string current_direction = "LONG";
   if (open >  close)        current_direction = "SHORT";

   bool POP_UP_Box_Alert = false;
   bool Sound_Alert = false;

   if (current_direction != last_direction) {
      if (POP_UP_Box_Alert) Alert("H/Ashi Direction change "+ current_direction +"  "+ Symbol() +" "+ Period() +" @ "+ Bid);
      if (Sound_Alert)      PlaySound("alert2.wav");
      last_direction = current_direction;
      return(true);
   }
   return (false);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Input.MA.Periods=",  Input.MA.Periods,  ";", NL,
                            "Input.MA.Method=",   Input.MA.Method,   ";", NL,
                            "Output.MA.Periods=", Output.MA.Periods, ";", NL,
                            "Output.MA.Method=",  Output.MA.Method,  ";")
   );
}
