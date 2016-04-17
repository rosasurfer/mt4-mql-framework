// @see  http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:commodity_channel_index_cci
//+------------------------------------------------------------------+
//|                                                   Supertrend.mq4 |
//|                   Copyright © 2005, Jason Robinson (jnrtrading). |
//|                                      http://www.jnrtrading.co.uk |
//+------------------------------------------------------------------+
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 Lime
#property indicator_color2 Red
#property indicator_width1 2
#property indicator_width2 2

double TrendUp  [];
double TrendDown[];


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   SetIndexBuffer(0, TrendUp);
   SetIndexBuffer(1, TrendDown);

   //SetIndexStyle(0, DRAW_LINE, STYLE_SOLID, 2);
   //SetIndexStyle(1, DRAW_LINE, STYLE_SOLID, 2);

   return(catch("onInit(1)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   return(catch("onDeinit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   int counted_bars = IndicatorCounted();
   if (counted_bars < 0) return(-1);
   if (counted_bars > 0) counted_bars--;

   int limit = Bars-counted_bars;

   for (int i=limit; i >= 0; i--) {
      double cci     = iCCI(NULL, NULL, 50, PRICE_TYPICAL, i  );
      double cciPrev = iCCI(NULL, NULL, 50, PRICE_TYPICAL, i+1);

      if (cci > 0) {
         if (cciPrev < 0)
            TrendUp[i+1] = TrendDown[i+1];
         TrendUp[i] = Low[i] - iATR(NULL, NULL, 5, i);
         if (TrendUp[i] < TrendUp[i+1])
            TrendUp[i] = TrendUp[i+1];
      }

      if (cci < 0) {
         if (cciPrev > 0)
            TrendDown[i+1] = TrendUp[i+1];
         TrendDown[i] = High[i] + iATR(NULL, NULL, 5, i);
         if (TrendDown[i] > TrendDown[i+1])
            TrendDown[i] = TrendDown[i+1];
      }
   }

   return(catch("onTick(1)"));
}



