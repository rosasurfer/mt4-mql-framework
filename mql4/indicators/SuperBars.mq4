/**
 * Hinterlegt den Chart mit Bars oder Candles übergeordneter Timeframes.
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdlib.mqh>


color color.bar.up   = Green;          // Farbe der Up-Bars
color color.bar.down = Red;            // Farbe der Down-Bars


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
   // Ausschnitt aus "core/indicator.mqh" zur besseren Übersicht
   if (false) {
      prev_error = last_error;
      last_error = NO_ERROR;

      ValidBars = IndicatorCounted();
      if      (prev_error == ERS_TERMINAL_NOT_READY  ) ValidBars = 0;
      else if (prev_error == ERS_HISTORY_UPDATE      ) ValidBars = 0;
      else if (prev_error == ERR_HISTORY_INSUFFICIENT) ValidBars = 0;
      if      (__STATUS_HISTORY_UPDATE               ) ValidBars = 0;      // *_HISTORY_UPDATE und *_HISTORY_INSUFFICIENT können je nach Kontext Fehler und/oder Status sein.
      if      (__STATUS_HISTORY_INSUFFICIENT         ) ValidBars = 0;
      ChangedBars = Bars - ValidBars;

      __STATUS_HISTORY_UPDATE       = false;
      __STATUS_HISTORY_INSUFFICIENT = false;

      onTick();

      if      (last_error == ERS_HISTORY_UPDATE      ) __STATUS_HISTORY_UPDATE       = true;
      else if (last_error == ERR_HISTORY_INSUFFICIENT) __STATUS_HISTORY_INSUFFICIENT = true;

      //debug("onTick(0.1)   prev_error="+ ErrorToStr(prev_error));
      //debug("onTick(0.2)   Tick="+ Tick +"  ValidBars="+ ValidBars +"  IndicatorCounted="+ IndicatorCounted() +"  Bid="+ NumberToStr(Bid, PriceFormat) +"  Vol="+ _int(Volume[0]));
   }


   DrawSuperBars();
   return(last_error);
}


/**
 * Zeichnet die übergeordneten Bars.
 *
 * @return bool - Erfolgsstatus
 */
bool DrawSuperBars() {
   // (1) Timeframe der zu zeichnenden Bars bestimmen
   int superTimeframe;

   switch (Period()) {
      case PERIOD_M1 : superTimeframe = PERIOD_D1;
      case PERIOD_M5 : superTimeframe = PERIOD_D1;
      case PERIOD_M15: superTimeframe = PERIOD_D1;
      case PERIOD_M30: superTimeframe = PERIOD_D1;
      case PERIOD_H1 : superTimeframe = PERIOD_D1;
      case PERIOD_H4 : superTimeframe = PERIOD_W1;
      case PERIOD_D1 : superTimeframe = PERIOD_MN1;
      case PERIOD_W1 : superTimeframe = PERIOD_MN1 * 3;     // PERIOD_Q1 = Quartal
      case PERIOD_MN1: superTimeframe = PERIOD_MN1 * 3;     // PERIOD_Q1 = Quartal
   }



   // (2) ValidBars auswerten und Anfangszeitpunkt bestimmen

   return(true);
}
