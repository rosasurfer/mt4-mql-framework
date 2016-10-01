/**
 * Ein Keltner-Channel (ATR-Channel), der statt um einen Moving-Average um High und Low der aktuellen Bar berechnet wird. Der SuperTrend-Indikator wechselt seine
 * Farbe, wenn der Standard-CCI die Null-Linie kreuzt. Je nachdem, ob der CCI über oder unter der Null-Linie liegt, wird nur das obere oder nur das untere Band
 * dargestellt. Die Werte des Channels sind bis zum CCI-Wechsel auf das jeweils aufgetretene Channel-Minimum/-Maximum fixiert, die resultierende Linie kann im
 * Aufwärtstrend nur steigen und im Abwärtstrend nur fallen.
 *
 *
 * @source http://www.forexfactory.com/showthread.php?t=214635 (Andrew Forex Trading System)
 * @see    http://www.forexfactory.com/showthread.php?t=268038 (Plateman's CCI aka SuperTrend)
 * @see    http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:keltner_channels
 * @see    http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:commodity_channel_index_cci
 *
 * //+------------------------------------------------------------------+
 * //|                                                   Supertrend.mq4 |
 * //|                   Copyright © 2005, Jason Robinson (jnrtrading). |
 * //|                                      http://www.jnrtrading.co.uk |
 * //+------------------------------------------------------------------+
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern int ATR.Periods =  5;
extern int CCI.Periods = 50;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // (1) IndicatorBuffer entsprechend ShiftedBars synchronisieren
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(TrendUp,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(TrendDown, Bars, ShiftedBars, EMPTY_VALUE);
   }


   int counted_bars = IndicatorCounted();
   if (counted_bars < 0) return(-1);
   if (counted_bars > 0) counted_bars--;

   int limit = Bars-counted_bars;

   for (int i=limit; i >= 0; i--) {
      double currentCCI  = iCCI(NULL, NULL, CCI.Periods, PRICE_TYPICAL, i  );
      double previousCCI = iCCI(NULL, NULL, CCI.Periods, PRICE_TYPICAL, i+1);

      if (currentCCI > 0) {
         TrendUp[i] = Low[i] - iATR(NULL, NULL, ATR.Periods, i);
         if (previousCCI < 0           ) TrendUp[i+1] = TrendDown[i+1];          // Farbe sofort wechseln (MetaTrader braucht min. zwei Datenpunkte)
         if (TrendUp[i]  < TrendUp[i+1]) TrendUp[i  ] = TrendUp  [i+1];          // Werte auf das bisherige Maximum begrenzen
      }
      else {
         TrendDown[i] = High[i] + iATR(NULL, NULL, ATR.Periods, i);
         if (previousCCI  > 0             ) TrendDown[i+1] = TrendUp  [i+1];     // Farbe sofort wechseln (MetaTrader braucht min. zwei Datenpunkte)
         if (TrendDown[i] > TrendDown[i+1]) TrendDown[i  ] = TrendDown[i+1];     // Werte auf das bisherige Minimum begrenzen
      }
   }

   return(catch("onTick(1)"));
}



