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
 * Ausschnitt aus "core/indicator.mqh" zur besseren Übersicht
 *
 * @return int - Fehlerstatus
 */
int x.start() {
   if (false) {
      // ...
      prev_error = last_error;
      last_error = NO_ERROR;

      ValidBars = IndicatorCounted();
      if      (prev_error == ERS_TERMINAL_NOT_READY) ValidBars = 0;
      else if (prev_error == ERS_HISTORY_UPDATE    ) ValidBars = 0;
      ChangedBars = Bars - ValidBars;

      onTick();
      // ...
   }
   return(last_error);
}


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);
   return(catch("onInit()")); x.start();
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   /*
   Ablauf beim Zeichnen von "jung" nach "alt"
   ----------------------------------------------
   - Zeichenbereich bei jedem Tick ist der Bereich von ChangedBars (jedoch keine for-Schleife über alle ChangedBars).
   - Die erste Superbar wird nach rechts über Bar[0] hinaus bis zum zukünftigen Supersession-Ende verbreitert.
   - Die letzte Superbar wird nach links über ChangedBars hinausreichen, wenn Bars > ChangedBars (ist zur Laufzeit Normalfall).
   */

   // (1) Timeframe der Superbars bestimmen
   int superTimeframe;
   switch (Period()) {
      case PERIOD_M1 : superTimeframe = PERIOD_D1;      break;
      case PERIOD_M5 : superTimeframe = PERIOD_D1;      break;
      case PERIOD_M15: superTimeframe = PERIOD_D1;      break;
      case PERIOD_M30: superTimeframe = PERIOD_D1;      break;
      case PERIOD_H1 : superTimeframe = PERIOD_D1;      break;
      case PERIOD_H4 : superTimeframe = PERIOD_W1;      break;
      case PERIOD_D1 : superTimeframe = PERIOD_MN1;     break;
      case PERIOD_W1 : superTimeframe = PERIOD_MN1 * 3; break;       // PERIOD_Q1 = Quartal
      case PERIOD_MN1: superTimeframe = PERIOD_MN1 * 3; break;       // PERIOD_Q1 = Quartal
   }

   datetime openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv;
   int i,   openBar, closeBar, lastChartBar=Bars-1;


   // (2) Schleife über die jeweils nächste Supersession
   while (true) { i++;
      if (!GetNextSuperSession(superTimeframe, openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv))
         return(last_error);

      openBar = iBarShiftNext(NULL, NULL, openTime.srv);             // falls ERS_HISTORY_UPDATE auftritt, passiert das nur ein einziges mal (und genau hier)
      if (openBar == EMPTY_VALUE) return(SetLastError(warn("onTick(1)->iBarShiftNext() => EMPTY_VALUE", stdlib.GetLastError())));

      closeBar = iBarShiftPrevious(NULL, NULL, closeTime.srv-1*SECOND);
      if (closeBar == -1)                                            // closeTime ist zu alt für den Chart => Abbruch
         break;

      if (openBar >= closeBar) {
         if      (openBar != lastChartBar)                              if (!DrawSuperBar(openBar, closeBar)) return(last_error);   // Die Supersession auf der letzten Chartbar ist fast
         else if (openBar == iBarShift(NULL, NULL, openTime.srv, true)) if (!DrawSuperBar(openBar, closeBar)) return(last_error);   // nie vollständig, trotzdem mit (exact=TRUE) prüfen.
      }
      //else /*openBar < closeBar*/                                  // Kurslücke

      if (openBar >= ChangedBars-1)                                  // Superbars bis max. ChangedBars aktualisieren
         break;
   }


   debug("onTick(0.1)   ChangedBars="+ ChangedBars +"  i="+ i);
   return(last_error);
}


/**
 * Ermittelt Beginn und Ende der nächst-älteren Supersession und schreibt das Ergebnis in die übergebenen Variablen.
 *
 * @param  int       timeframe     - Timeframe der zu ermittelnden Supersession
 * @param  datetime &openTime.fxt  - Zeiger auf Variable, die den Beginn der letzten Supersession in FXT-Zeit enthält
 * @param  datetime &closeTime.fxt - Zeiger auf Variable, die das Ende der letzten Supersession in FXT-Zeit enthält
 * @param  datetime &openTime.srv  - Zeiger auf Variable, die den Beginn der letzten Supersession in Serverzeit enthält
 * @param  datetime &closeTime.srv - Zeiger auf Variable, die das Ende der letzten Supersession in Serverzeit enthält
 *
 * @return bool - Erfolgsstatus
 */
bool GetNextSuperSession(int timeframe, datetime &openTime.fxt, datetime &closeTime.fxt, datetime &openTime.srv, datetime &closeTime.srv) {
   // sind die Variablen nicht initialisiert, wird die erste Supersession zurückgegeben
   if (!openTime.srv) {
      openTime.srv  = TimeCurrent();
      closeTime.srv = TimeCurrent() + 1*DAY;
   }

   openTime.srv  = openTime.srv  - 1*DAY;
   closeTime.srv = closeTime.srv - 1*DAY;

   return(!catch("GetNextSuperSession()"));
}


/**
 * Zeichnet eine einzelne Superbar.
 *
 * @param  int openBar  - Chartoffset der Open-Bar der Superbar
 * @param  int closeBar - Chartoffset der Close-Bar der Superbar
 *
 * @return bool - Erfolgsstatus
 */
bool DrawSuperBar(int openBar, int closeBar) {
   // High- und Low-Bar ermitteln
   int highBar = iHighest(NULL, NULL, MODE_HIGH, openBar-closeBar+1, closeBar);
   int lowBar  = iLowest (NULL, NULL, MODE_LOW , openBar-closeBar+1, closeBar);
   return(!catch("DrawSuperBar()"));
}
