/**
 * Hinterlegt den Chart mit Bars oder Candles übergeordneter Timeframes.
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdlib.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);
   return(catch("onInit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (prev_error == ERS_HISTORY_UPDATE) {
   }

   if (IsError(prev_error)) {
      debug("onTick(0.1)   prev_error="+ ErrorToStr(prev_error));
   }

   debug("onTick(0.2)   Tick="+ Tick /*+"  ValidBars="+ValidBars*/ +"  IndicatorCounted="+ IndicatorCounted() +"  Bid="+ NumberToStr(Bid, PriceFormat) +"  Vol="+ _int(Volume[0]));

   return(last_error);
}
