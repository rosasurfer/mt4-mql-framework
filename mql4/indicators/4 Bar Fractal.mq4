/**
 * 4 Bar Indi.mq4
 * Mahadi Hasan Razu, 2021
 * https://www.mql5.com/en/users/hermesmercury
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>

#property indicator_chart_window
#property indicator_buffers   2

#property indicator_color1    Blue
#property indicator_color2    Red

#property indicator_width1    1
#property indicator_width2    1

double up[];
double down[];


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int onInit() {
   SetIndexBuffer(0, up);   SetIndexStyle (0, DRAW_ARROW); SetIndexArrow (0, 241); SetIndexLabel (0, "Buy");
   SetIndexBuffer(1, down); SetIndexStyle (1, DRAW_ARROW); SetIndexArrow (1, 242); SetIndexLabel (1, "Sell");

   IndicatorShortName(WindowExpertName());
   return(0);
}


//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int onTick() {
   for (int bar=1; bar <= ChangedBars; bar++) {
      if (bar+3 <= Bars) {
         if (Close[bar] > Open[bar] && Close[bar] > High[bar+1] && Close[bar] > High[bar+3]) {
            up[bar-1] = Low[bar-1] - 0.5*iATR(NULL, NULL, 10, bar);
         }
         if (Close[bar] < Open[bar] && Close[bar] < Low[bar+1] && Close[bar] < Low[bar+3]) {
            down[bar-1] = High[bar-1] + 0.5*iATR(NULL, NULL, 10, bar);
         }
      }
   }
   return(catch("onTick(1)"));
}
