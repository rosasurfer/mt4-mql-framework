/**
 * Heiken Ashi
 *
 *
 * For Heiken Ashi the following chart settings are recommended:
 *  - Menu -> Charts -> Properties -> Colors -> Line graph: "None"
 *  - Select Menu -> Charts -> Line Chart
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern color color1 = Red;
extern color color2 = Green;
extern color color3 = Red;
extern color color4 = Green;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>

#property indicator_chart_window

#property indicator_buffers 4

#property indicator_color1 Red
#property indicator_color2 Green
#property indicator_color3 Red
#property indicator_color4 Green

#property indicator_width1 2
#property indicator_width2 2
#property indicator_width3 1
#property indicator_width4 1


//---- buffers
double haOpen   [];
double haClose  [];
double haBuffer3[];
double haBuffer4[];


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // indicator styles
   SetIndexStyle(0, DRAW_HISTOGRAM, EMPTY, EMPTY, color1);
   SetIndexStyle(1, DRAW_HISTOGRAM, EMPTY, EMPTY, color2);
   SetIndexStyle(2, DRAW_HISTOGRAM, EMPTY, EMPTY, color3);
   SetIndexStyle(3, DRAW_HISTOGRAM, EMPTY, EMPTY, color4);

   // indicator buffers mapping
   SetIndexBuffer(0, haOpen   );
   SetIndexBuffer(1, haClose  );
   SetIndexBuffer(2, haBuffer3);
   SetIndexBuffer(3, haBuffer4);

   SetIndexDrawBegin(0, 10);
   SetIndexDrawBegin(1, 10);
   SetIndexDrawBegin(2, 10);
   SetIndexDrawBegin(3, 10);

   return(catch("onInit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (Bars <= 10)
      return(0);

   // check for possible errors
   int ExtCountedBars = IndicatorCounted();
   if (ExtCountedBars < 0)
      return(-1);

   // last counted bar will be recounted
   if (ExtCountedBars > 0)
      ExtCountedBars--;

   double O, H, L, C;
   int bar = Bars - ExtCountedBars - 1;

   while (bar >= 0) {
      O = (haOpen[bar+1] + haClose[bar+1])/2;
      C = (Open[bar] + High[bar] + Low[bar] + Close[bar])/4;
      H = MathMax(High[bar], MathMax(O, C));
      L = MathMin(Low [bar], MathMin(O, C));

      haOpen [bar] = O;
      haClose[bar] = C;

      if (O < C) { haBuffer3[bar] = L; haBuffer4[bar] = H; }
      else       { haBuffer3[bar] = H; haBuffer4[bar] = L; }

      bar--;
   }
   return(last_error);
}
