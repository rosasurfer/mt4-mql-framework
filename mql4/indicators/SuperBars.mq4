/**
 * Hinterlegt den Chart mit Bars übergeordneter Timeframes.
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <win32api.mqh>

//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern color Color.BarUp        = C'193,255,193';        // Up-Bars              blass: C'215,255,215'
extern color Color.BarDown      = C'255,213,213';        // Down-Bars            blass: C'255,230,230'
extern color Color.BarUnchanged = C'232,232,232';        // unveränderte Bars                               // oder Gray
extern color Color.Close        = C'164,164,164';        // Close-Marker                                    // oder Black

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#include <core/indicator.mqh>

int    superBars.timeframe;
string label.description = "Description";                // Label für Chartanzeige


#define STF_UP        1
#define STF_DOWN     -1


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Parametervalidierung
   // Colors
   if (Color.BarUp        == 0xFF000000) Color.BarUp   = CLR_NONE;   // CLR_NONE kann vom Terminal u.U. falsch gesetzt worden sein
   if (Color.BarDown      == 0xFF000000) Color.BarDown = CLR_NONE;
   if (Color.BarUnchanged == 0xFF000000) Color.BarDown = CLR_NONE;
   if (Color.Close        == 0xFF000000) Color.Close   = CLR_NONE;


   // (2) Textlabel erzeugen
   CreateLabels();


   // (3) Status restaurieren
   if (!RestoreWindowStatus())
      return(last_error);


   // (4) Anzeigestatus prüfen und ggf. Default festlegen
   switch (superBars.timeframe) {
      // off: kann nur manuell aktiviert werden
      case  INT_MIN   :
      case  INT_MAX   : break;

      // aktiviert: wird automatisch deaktiviert, wenn Anzeige in aktueller Chartperiode unsinnig ist
      case  PERIOD_D1 : if (Period() >  PERIOD_H1) superBars.timeframe = -superBars.timeframe; break;
      case  PERIOD_W1 : if (Period() >  PERIOD_H4) superBars.timeframe = -superBars.timeframe; break;
      case  PERIOD_MN1: if (Period() >  PERIOD_D1) superBars.timeframe = -superBars.timeframe; break;
      case  PERIOD_Q1 : if (Period() >  PERIOD_W1) superBars.timeframe = -superBars.timeframe; break;

      // deaktiviert: wird automatisch reaktiviert, wenn Anzeige in aktueller Chartperiode Sinn macht
      case -PERIOD_D1 : if (Period() <= PERIOD_H1) superBars.timeframe = -superBars.timeframe; break;
      case -PERIOD_W1 : if (Period() <= PERIOD_H4) superBars.timeframe = -superBars.timeframe; break;
      case -PERIOD_MN1: if (Period() <= PERIOD_D1) superBars.timeframe = -superBars.timeframe; break;
      case -PERIOD_Q1 : if (Period() <= PERIOD_W1) superBars.timeframe = -superBars.timeframe; break;

      // ungültiger Status: Default benutzen
      default:
         switch (Period()) {
            case PERIOD_M1 :
            case PERIOD_M5 :
            case PERIOD_M15:
            case PERIOD_M30:
            case PERIOD_H1 : superBars.timeframe =  PERIOD_D1;  break;
            case PERIOD_H4 : superBars.timeframe =  PERIOD_W1;  break;
            case PERIOD_D1 : superBars.timeframe =  PERIOD_MN1; break;
            case PERIOD_W1 :
            case PERIOD_MN1: superBars.timeframe = -PERIOD_MN1; break;
         }
   }


   SetIndexLabel(0, NULL);                                           // Datenanzeige ausschalten
   return(catch("onInit(3)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);

   // in allen deinit()-Szenarien Fensterstatus  speichern
   if (!StoreWindowStatus())
      return(last_error);
   return(catch("onDeinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   HandleEvent(EVENT_CHART_CMD);                                     // ChartCommands verarbeiten
   UpdateSuperBars();                                                // SuperBars aktualisieren
   return(last_error);
}


/**
 * Handler für ChartCommands.
 *
 * @param  string commands[] - die eingetroffenen Commands
 *
 * @return bool - Erfolgsstatus
 */
bool onChartCommand(string commands[]) {
   int size = ArraySize(commands);
   if (!size) return(!warn("onChartCommand(1)   empty parameter commands = {}"));

   for (int i=0; i < size; i++) {
      if      (commands[i] == "Timeframe=Up"  ) { if (!SwitchSuperTimeframe(STF_UP  )) return(false); }
      else if (commands[i] == "Timeframe=Down") { if (!SwitchSuperTimeframe(STF_DOWN)) return(false); }
      else
         warn("onChartCommand(2)   unknown chart command \""+ commands[i] +"\"");
   }
   return(!catch("onChartCommand(3)"));
}


/**
 * Schaltet den Parameter superTimeframe des Indikators um.
 *
 * @param  int direction - Richtungs-ID:  STF_UP|STF_DOWN
 *
 * @return bool - Erfolgsstatus
 */
bool SwitchSuperTimeframe(int direction) {
   bool reset = false;

   if (direction == STF_DOWN) {
      switch (superBars.timeframe) {
         case INT_MIN   : ForceSound("Plonk.wav");          break;   // Plonk!!! (we hit a wall)
         case PERIOD_D1 : superBars.timeframe = INT_MIN;    break;
         case PERIOD_W1 : superBars.timeframe = PERIOD_D1;  break;
         case PERIOD_MN1: superBars.timeframe = PERIOD_W1;  break;
         case PERIOD_Q1 : superBars.timeframe = PERIOD_MN1; break;
         case INT_MAX   : superBars.timeframe = PERIOD_Q1;  break;
         default:
            reset = true;
      }
   }
   else if (direction == STF_UP) {
      switch (superBars.timeframe) {
         case INT_MIN   : superBars.timeframe = PERIOD_D1;  break;
         case PERIOD_D1 : superBars.timeframe = PERIOD_W1;  break;
         case PERIOD_W1 : superBars.timeframe = PERIOD_MN1; break;
         case PERIOD_MN1: superBars.timeframe = PERIOD_Q1;  break;
         case PERIOD_Q1 : superBars.timeframe = INT_MAX;    break;
         case INT_MAX   : ForceSound("Plonk.wav");          break;   // Plonk!!! (we hit a wall)
         default:
            reset = true;
      }
   }
   else warn("SwitchSuperTimeframe(1)   unknown parameter direction = "+ direction);

   if (reset) {
      // Parameter superBars.timeframe war ungültig und wird auf den Default-Wert zurückgesetzt.
      switch (Period()) {
         case PERIOD_M1 :
         case PERIOD_M5 :
         case PERIOD_M15:
         case PERIOD_M30:
         case PERIOD_H1 : superBars.timeframe =  PERIOD_D1;  break;
         case PERIOD_H4 : superBars.timeframe =  PERIOD_W1;  break;
         case PERIOD_D1 : superBars.timeframe =  PERIOD_MN1; break;
         case PERIOD_W1 :
         case PERIOD_MN1: superBars.timeframe = -PERIOD_MN1; break;
      }
   }

   return(true);
}


/**
 * Aktualisiert die SuperBar-Anzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateSuperBars() {
   // (1) Konfigurationswechsel detektieren und ggf. vorhandene Bars löschen
   bool timeframeChanged = false;
   static int last.timeframe;
   if (last.timeframe != 0) {
      if (superBars.timeframe != last.timeframe) {
         timeframeChanged = true;
      }
      if (timeframeChanged) /*&&*/ if (last.timeframe!=INT_MIN) /*&&*/ if (last.timeframe!=INT_MAX) {
         DeleteRegisteredObjects(NULL);                              // War last.timeframe INT_MIN oder INT_MAX, wurden vorhandene Bars bereits gelöscht.
         CreateLabels();
      }
   }


   // (2) Rückkehr bei manuell abgeschalteter oder automatisch deaktivierter Anzeige
   switch (superBars.timeframe) {
      case  INT_MIN   :                   // manuell abgeschaltet
      case  INT_MAX   :
      case -PERIOD_D1 :                   // automatisch deaktiviert
      case -PERIOD_W1 :
      case -PERIOD_MN1:
      case -PERIOD_Q1 : return(true);
   }


   // (3) Anzeige
   // - Zeichenbereich bei jedem Tick ist der Bereich von ChangedBars (jedoch keine for-Schleife über alle ChangedBars).
   // - Die erste, aktuelle Superbar reicht nur bis Bar[0], was Fortschritt und Relevanz der wachsenden Superbar veranschaulicht.
   // - Die letzte Superbar reicht nach links über ChangedBars hinaus, wenn Bars > ChangedBars (ist zur Laufzeit Normalfall).
   datetime openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv;
   int      openBar, closeBar, lastChartBar=Bars-1, i=-1, changedBars=ChangedBars;
   if (timeframeChanged)
      changedBars = Bars;                                            // bei Timeframewechsel müssen immer alle Bars neugezeichnet werden

   // Schleife über alle Superbars von "jung" nach "alt"
   //
   // Mit "Session" ist in der Folge keine 24-h-Session, sondern eine Periode des jeweiligen Super-Timeframes gemeint,
   // z.B. ein Tag, eine Woche oder ein Monat.
   while (true) {
      if (!GetPreviousSession(superBars.timeframe, openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv))
         return(false);

      // Ab Chartperiode PERIOD_D1 wird der Bar-Timestamp vom Broker nur noch in vollen Tagen gesetzt und der Timezone-Offset kann einen Monatsbeginn
      // fälschlicherweise in den vorherigen oder nächsten Monat setzen. Dies muß nur in der Woche, nicht jedoch am Wochenende korrigiert werden.
      if (Period()==PERIOD_D1) /*&&*/ if (superBars.timeframe>=PERIOD_MN1) {
         if (openTime.srv  < openTime.fxt ) /*&&*/ if (TimeDayOfWeek(openTime.srv )!=SUNDAY  ) openTime.srv  = openTime.fxt;     // Sonntagsbar: Server-Timezone westlich von FXT
         if (closeTime.srv > closeTime.fxt) /*&&*/ if (TimeDayOfWeek(closeTime.srv)!=SATURDAY) closeTime.srv = closeTime.fxt;    // Samstagsbar: Server-Timezone östlich von FXT
      }
      openBar = iBarShiftNext(NULL, NULL, openTime.srv);             // Da immer der aktuelle Timeframe benutzt wird, kann ERS_HISTORY_UPDATE eigentlich nie auftreten.
      if (openBar == EMPTY_VALUE) return(!SetLastError(warn("UpdateSuperBars(1)->iBarShiftNext() => EMPTY_VALUE", stdlib.GetLastError())));

      closeBar = iBarShiftPrevious(NULL, NULL, closeTime.srv-1*SECOND);
      if (closeBar == -1)                                            // closeTime ist zu alt für den Chart => Abbruch
         break;

      if (openBar >= closeBar) {
         if      (openBar != lastChartBar)                              { i++; if (!DrawSuperBar(i, openTime.fxt, openBar, closeBar)) return(false); }
         else if (openBar == iBarShift(NULL, NULL, openTime.srv, true)) { i++; if (!DrawSuperBar(i, openTime.fxt, openBar, closeBar)) return(false); }
      }                                                              // Die Supersession auf der letzten Chartbar ist äußerst selten vollständig, trotzdem mit (exact=TRUE) prüfen.
      if (openBar >= changedBars-1)
         break;                                                      // Superbars bis max. changedBars aktualisieren
   }

   last.timeframe = superBars.timeframe;
   return(true);
}


/**
 * Ermittelt Beginn und Ende der dem Parameter openTime.fxt vorhergehenden Session und schreibt das Ergebnis in die übergebenen
 * Variablen. Ist der Parameter openTime.fxt nicht gesetzt, wird die jüngste Session (also ggf. die aktuelle) zurückgegeben.
 *
 * @param  int       timeframe     - Timeframe der zu ermittelnden Session
 * @param  datetime &openTime.fxt  - Variable zur Aufnahme des Beginns der resultierenden Session in FXT-Zeit
 * @param  datetime &closeTime.fxt - Variable zur Aufnahme des Endes der resultierenden Session in FXT-Zeit
 * @param  datetime &openTime.srv  - Variable zur Aufnahme des Beginns der resultierenden Session in Serverzeit
 * @param  datetime &closeTime.srv - Variable zur Aufnahme des Endes der resultierenden Session in Serverzeit
 *
 * @return bool - Erfolgsstatus
 */
bool GetPreviousSession(int timeframe, datetime &openTime.fxt, datetime &closeTime.fxt, datetime &openTime.srv, datetime &closeTime.srv) {
   int month, dom, dow;


   // (1) PERIOD_D1
   if (timeframe == PERIOD_D1) {
      // ist openTime.fxt nicht gesetzt, Variable mit Zeitpunkt des nächsten Tages initialisieren
      if (!openTime.fxt)
         openTime.fxt = GmtToFxtTime(TimeGMT()) + 1*DAY;

      // openTime.fxt auf 00:00 Uhr des vorherigen Tages setzen
      openTime.fxt -= (1*DAY + TimeHour(openTime.fxt)*HOURS + TimeMinute(openTime.fxt)*MINUTES + TimeSeconds(openTime.fxt));

      // Wochenenden in openTime.fxt überspringen
      dow = TimeDayOfWeek(openTime.fxt);
      if      (dow == SATURDAY) openTime.fxt -= 1*DAY;
      else if (dow == SUNDAY  ) openTime.fxt -= 2*DAYS;

      // closeTime.fxt auf 00:00 des folgenden Tages setzen
      closeTime.fxt = openTime.fxt + 1*DAY;
   }


   // (2) PERIOD_W1
   else if (timeframe == PERIOD_W1) {
      // ist openTime.fxt nicht gesetzt, Variable mit Zeitpunkt der nächsten Woche initialisieren
      if (!openTime.fxt)
         openTime.fxt = GmtToFxtTime(TimeGMT()) + 7*DAYS;

      // openTime.fxt auf Montag, 00:00 Uhr der vorherigen Woche setzen
      openTime.fxt -= (TimeHour(openTime.fxt)*HOURS + TimeMinute(openTime.fxt)*MINUTES + TimeSeconds(openTime.fxt));    // 00:00 des aktuellen Tages
      openTime.fxt -= (TimeDayOfWeek(openTime.fxt)+6)%7 * DAYS;                                                         // Montag der aktuellen Woche
      openTime.fxt -= 7*DAYS;                                                                                           // Montag der Vorwoche

      // closeTime.fxt auf 00:00 des folgenden Samstags setzen
      closeTime.fxt = openTime.fxt + 5*DAYS;
   }


   // (3) PERIOD_MN1
   else if (timeframe == PERIOD_MN1) {
      // ist openTime.fxt nicht gesetzt, Variable mit Zeitpunkt des nächsten Monats initialisieren
      if (!openTime.fxt)                                                                                                // Sollte dies der übernächste Monat sein, wird dies
         openTime.fxt = GmtToFxtTime(TimeGMT()) + 1*MONTH;                                                              // als Kurslücke interpretiert und übersprungen.

      openTime.fxt -= (TimeHour(openTime.fxt)*HOURS + TimeMinute(openTime.fxt)*MINUTES + TimeSeconds(openTime.fxt));    // 00:00 des aktuellen Tages

      // closeTime.fxt auf den 1. des folgenden Monats, 00:00 setzen
      dom = TimeDay(openTime.fxt);
      closeTime.fxt = openTime.fxt - (dom-1)*DAYS;                                                                      // erster des aktuellen Monats

      // openTime.fxt auf den 1. des vorherigen Monats, 00:00 Uhr setzen
      openTime.fxt  = closeTime.fxt - 1*DAYS;                                                                           // letzter Tag des vorherigen Monats
      openTime.fxt -= (TimeDay(openTime.fxt)-1)*DAYS;                                                                   // erster Tag des vorherigen Monats

      // Wochenenden in openTime.fxt überspringen
      dow = TimeDayOfWeek(openTime.fxt);
      if      (dow == SATURDAY) openTime.fxt += 2*DAYS;
      else if (dow == SUNDAY  ) openTime.fxt += 1*DAY;

      // Wochenenden in closeTime.fxt überspringen
      dow = TimeDayOfWeek(closeTime.fxt);
      if      (dow == SUNDAY) closeTime.fxt -= 1*DAY;
      else if (dow == MONDAY) closeTime.fxt -= 2*DAYS;
   }


   // (4) PERIOD_Q1
   else if (timeframe == PERIOD_Q1) {
      // ist openTime.fxt nicht gesetzt, Variable mit Zeitpunkt des nächsten Quartals initialisieren
      if (!openTime.fxt)                                                                                             // Sollte dies das übernächste Quartal sein, wird dies
         openTime.fxt = GmtToFxtTime(TimeGMT()) + 1*QUARTER;                                                         // als Kurslücke interpretiert und übersprungen.

      openTime.fxt -= (TimeHour(openTime.fxt)*HOURS + TimeMinute(openTime.fxt)*MINUTES + TimeSeconds(openTime.fxt)); // 00:00 des aktuellen Tages

      // closeTime.fxt auf den ersten Tag des folgenden Quartals, 00:00 setzen
      switch (TimeMonth(openTime.fxt)) {
         case JANUARY  :
         case FEBRUARY :
         case MARCH    : closeTime.fxt = openTime.fxt - (TimeDayOfYear(openTime.fxt)-1)*DAYS; break;                 // erster Tag des aktuellen Quartals (01.01.)
         case APRIL    : closeTime.fxt = openTime.fxt -       (TimeDay(openTime.fxt)-1)*DAYS; break;
         case MAY      : closeTime.fxt = openTime.fxt - (30+   TimeDay(openTime.fxt)-1)*DAYS; break;
         case JUNE     : closeTime.fxt = openTime.fxt - (30+31+TimeDay(openTime.fxt)-1)*DAYS; break;                 // erster Tag des aktuellen Quartals (01.04.)
         case JULY     : closeTime.fxt = openTime.fxt -       (TimeDay(openTime.fxt)-1)*DAYS; break;
         case AUGUST   : closeTime.fxt = openTime.fxt - (31+   TimeDay(openTime.fxt)-1)*DAYS; break;
         case SEPTEMBER: closeTime.fxt = openTime.fxt - (31+31+TimeDay(openTime.fxt)-1)*DAYS; break;                 // erster Tag des aktuellen Quartals (01.07.)
         case OCTOBER  : closeTime.fxt = openTime.fxt -       (TimeDay(openTime.fxt)-1)*DAYS; break;
         case NOVEMBER : closeTime.fxt = openTime.fxt - (31+   TimeDay(openTime.fxt)-1)*DAYS; break;
         case DECEMBER : closeTime.fxt = openTime.fxt - (31+30+TimeDay(openTime.fxt)-1)*DAYS; break;                 // erster Tag des aktuellen Quartals (01.10.)
      }

      // openTime.fxt auf den ersten Tag des vorherigen Quartals, 00:00 Uhr setzen
      openTime.fxt = closeTime.fxt - 1*DAY;                                                                          // letzter Tag des vorherigen Quartals
      switch (TimeMonth(openTime.fxt)) {
         case MARCH    : openTime.fxt -= (TimeDayOfYear(openTime.fxt)-1)*DAYS; break;                                // erster Tag des vorherigen Quartals (01.01.)
         case JUNE     : openTime.fxt -= (30+31+TimeDay(openTime.fxt)-1)*DAYS; break;                                // erster Tag des vorherigen Quartals (01.04.)
         case SEPTEMBER: openTime.fxt -= (31+31+TimeDay(openTime.fxt)-1)*DAYS; break;                                // erster Tag des vorherigen Quartals (01.07.)
         case DECEMBER : openTime.fxt -= (31+30+TimeDay(openTime.fxt)-1)*DAYS; break;                                // erster Tag des vorherigen Quartals (01.10.)
      }

      // Wochenenden in openTime.fxt überspringen
      dow = TimeDayOfWeek(openTime.fxt);
      if      (dow == SATURDAY) openTime.fxt += 2*DAYS;
      else if (dow == SUNDAY  ) openTime.fxt += 1*DAY;

      // Wochenenden in closeTime.fxt überspringen
      dow = TimeDayOfWeek(closeTime.fxt);
      if      (dow == SUNDAY) closeTime.fxt -= 1*DAY;
      else if (dow == MONDAY) closeTime.fxt -= 2*DAYS;
   }
   else return(!catch("GetPreviousSession(1) unsupported timeframe = "+ ifString(!timeframe, NULL, PeriodToStr(timeframe)), ERR_RUNTIME_ERROR));


   // (5) entsprechende Serverzeiten ermitteln
   openTime.srv  = FxtToServerTime(openTime.fxt );
   closeTime.srv = FxtToServerTime(closeTime.fxt);


   //static int i;
   //if (i == 2) {
   //   debug("GetPreviousSession("+ PeriodDescription(timeframe) +")   "+ i +" fxt:  from='"+ DateToStr(openTime.fxt, "w D.M.Y H:I:S") +"' to='"+ DateToStr(closeTime.fxt, "w D.M.Y H:I:S") +"'");
   //   debug("GetPreviousSession("+ PeriodDescription(timeframe) +")   "+ i +" srv:  from='"+ DateToStr(openTime.srv, "w D.M.Y H:I:S") +"' to='"+ DateToStr(closeTime.srv, "w D.M.Y H:I:S") +"'");
   //}
   //i++;
   return(!catch("GetPreviousSession(2)"));
}


/**
 * Zeichnet eine einzelne Superbar.
 *
 * @param  int      i        - Barindex (beginnend mit 0)
 * @param  datetime openTime - Startzeit der Supersession in FXT
 * @param  int      openBar  - Chartoffset der Open-Bar der Superbar
 * @param  int      closeBar - Chartoffset der Close-Bar der Superbar
 *
 * @return bool - Erfolgsstatus
 */
bool DrawSuperBar(int i, datetime openTime.fxt, int openBar, int closeBar) {
   // High- und Low-Bar ermitteln
   int highBar = iHighest(NULL, NULL, MODE_HIGH, openBar-closeBar+1, closeBar);
   int lowBar  = iLowest (NULL, NULL, MODE_LOW , openBar-closeBar+1, closeBar);

   // Farbe bestimmen
   color barColor = Color.BarUnchanged;
   if (openBar < Bars-1) double openPrice = Close[openBar + 1];
   else                         openPrice = Open [openBar];                                  // Als OpenPrice wird nach Möglichkeit das Close der vorherigen Bar verwendet.
   if (MathMax(openPrice,  Close[closeBar])/MathMin(openPrice, Close[closeBar]) > 1.0005) {  // Ab ca. 5-10 pip Preisunterschied wird Up- oder Down-Color angewendet.
      if      (openPrice < Close[closeBar]) barColor = Color.BarUp;
      else if (openPrice > Close[closeBar]) barColor = Color.BarDown;
   }

   // Label definieren
   string label;
   switch (superBars.timeframe) {
      case PERIOD_D1 : label =          DateToStr(openTime.fxt, "w D.M.Y ");                            break; // "w D.M.Y" wird bereits vom Grid verwendet
      case PERIOD_W1 : label = "Week "+ DateToStr(openTime.fxt,   "D.M.Y" );                            break;
      case PERIOD_MN1: label =          DateToStr(openTime.fxt,     "N Y" );                            break;
      case PERIOD_Q1 : label = ((TimeMonth(openTime.fxt)-1)/3+1) +". Quarter "+ TimeYear(openTime.fxt); break;
   }

   // Superbar zeichnen
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
      int closeBar_j = closeBar; /*j: justified*/                             // Rechtecke um eine Chartbar nach rechts verbreitern, damit sie sich gegenseitig berühren.
      if (closeBar > 0) closeBar_j--;                                         // jedoch nicht bei der jüngsten Bar[0]
   if (ObjectCreate(label, OBJ_RECTANGLE, 0, Time[openBar], High[highBar], Time[closeBar_j], Low[lowBar])) {
      ObjectSet     (label, OBJPROP_COLOR, barColor);
      ObjectSet     (label, OBJPROP_BACK , true    );
      ObjectRegister(label);
   }
   else GetLastError();

   // Close-Marker zeichnen
   if (closeBar > 0) {                                                        // jedoch nicht bei der jüngsten Bar[0] (unnötig)
      int centerBar = (openBar+closeBar_j)/2;
      if (centerBar > closeBar) {
         string labelWithPrice, labelWithoutPrice=label +" Close";

         if (ObjectFind(labelWithoutPrice) == 0) {                            // Jeder Marker besteht aus zwei Objekten: Ein unsichtbares Label (erstes Objekt) mit
            labelWithPrice = ObjectDescription(labelWithoutPrice);            // festem Namen, das in der Beschreibung den veränderlichen Namen des sichtbaren Markers
            if (ObjectFind(labelWithPrice) == 0)                              // (zweites Objekt) enthält. So kann ein bereits vorhandener Marker einer Superbar im
               ObjectDelete(labelWithPrice);                                  // Chart gefunden und durch einen neuen ersetzt werden, obwohl sich sein dynamischer Name
            ObjectDelete(labelWithoutPrice);                                  // geändert hat.
         }
         labelWithPrice = labelWithoutPrice +" "+ DoubleToStr(Close[closeBar], PipDigits);

         if (ObjectCreate(labelWithoutPrice, OBJ_LABEL, 0, 0, 0)) {
            ObjectSet    (labelWithoutPrice, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
            ObjectSetText(labelWithoutPrice, labelWithPrice);
            ObjectRegister(labelWithoutPrice);
         } else GetLastError();

         if (ObjectCreate(labelWithPrice, OBJ_TREND, 0, Time[centerBar], Close[closeBar], Time[closeBar], Close[closeBar])) {
            ObjectSet    (labelWithPrice, OBJPROP_RAY  , false      );
            ObjectSet    (labelWithPrice, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSet    (labelWithPrice, OBJPROP_COLOR, Color.Close);
            ObjectSet    (labelWithPrice, OBJPROP_BACK , true       );
            ObjectRegister(labelWithPrice);
         } else GetLastError();
      }
   }

   // bei Superbar[0] OHL-Anzeige aktualisieren
   if (closeBar == 0) {
      string sRange = "";
      switch (superBars.timeframe) {
         case PERIOD_M1 : sRange = "Superbars: 1 Minute";   break;
         case PERIOD_M5 : sRange = "Superbars: 5 Minutes";  break;
         case PERIOD_M15: sRange = "Superbars: 15 Minutes"; break;
         case PERIOD_M30: sRange = "Superbars: 30 Minutes"; break;
         case PERIOD_H1 : sRange = "Superbars: 1 Hour";     break;
         case PERIOD_H4 : sRange = "Superbars: 4 Hours";    break;
         case PERIOD_D1 : sRange = "Superbars: Days";       break;
         case PERIOD_W1 : sRange = "Superbars: Weeks";      break;
         case PERIOD_MN1: sRange = "Superbars: Months";     break;
         case PERIOD_Q1 : sRange = "Superbars: Quarters";   break;
      }
      //sRange = StringConcatenate(sRange, "   O: ", NumberToStr(Open[openBar], PriceFormat), "   H: ", NumberToStr(High[highBar], PriceFormat), "   L: ", NumberToStr(Low[lowBar], PriceFormat));
      label = __NAME__ +"."+ label.description;
      string fontName = "";
      int    fontSize = 8;                                                    // "MS Sans Serif"-8 entspricht in allen Builds der Menüschrift
      ObjectSetText(label, sRange, fontSize, fontName, Black);

      int error = GetLastError();
      if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)        // bei offenem Properties-Dialog oder Object::onDrag()
         return(!catch("DrawSuperBar(1)", error));
   }

   //static int i;
   //if (i <= 5) {
   //   debug("DrawSuperBar("+ PeriodDescription(superTimeframe) +")   from="+ openBar +"  to="+ closeBar +"  label=\""+ label +"\"");
   //   i++;
   //}
   return(!catch("DrawSuperBar(2)"));
}


/**
 * Prüft, ob seit dem letzten Aufruf ein ChartCommand für diesen Indikator eingetroffen ist.
 *
 * @param  string commands[] - Array zur Aufnahme der eingetroffenen Commands
 * @param  int    flags      - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 */
bool EventListener.ChartCommand(string &commands[], int flags=NULL) {
   if (!IsChart)
      return(false);

   static string label, mutex; if (!StringLen(label)) {
      label = __NAME__ +".command";
      mutex = "mutex."+ label;
   }


   // (1) zuerst nur Lesezugriff (unsynchronisiert möglich), um nicht bei jedem Tick das Lock erwerben zu müssen
   if (ObjectFind(label) == 0) {

      // (2) erst wenn ein Command eingetroffen ist, Lock für Schreibzugriff holen
      if (!AquireLock(mutex, true))
         return(!SetLastError(stdlib.GetLastError()));

      // (3) Command auslesen und Command-Object löschen
      ArrayResize(commands, 1);
      commands[0] = ObjectDescription(label);
      ObjectDelete(label);

      // (4) Lock wieder freigeben
      if (!ReleaseLock(mutex))
         return(!SetLastError(stdlib.GetLastError()));

      return(!catch("EventListener.ChartCommand(1)"));
   }
   return(false);
}


/**
 * Erzeugt das Label für die Textanzeige im Chart.
 *
 * @return int - Fehlerstatus
 */
int CreateLabels() {
   string label = __NAME__ +"."+ label.description;

   if (ObjectFind(label) == 0)
      ObjectDelete(label);

   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 115);
      ObjectSet    (label, OBJPROP_YDISTANCE, 4  );
      ObjectSetText(label, " ", 1);
      ObjectRegister(label);
   }

   return(catch("CreateLabels(1)"));
}


/**
 * Speichert die Fenster-relevanten Konfigurationsdaten im Chart und in der lokalen Terminalkonfiguration.
 * Dadurch gehen sie auch beim Laden eines neuen Chart-Templates nicht verloren.
 *
 * @return bool - Erfolgsstatus
 */
bool StoreWindowStatus() {
   // Die Konfiguration wird nur gespeichert, wenn sie gültig ist.
   if (!superBars.timeframe)
      return(true);

   // Konfiguration im Chart speichern
   string label = __NAME__ +".sticky.timeframe";
   string value = superBars.timeframe;                               // (string) int
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, value);

   // Konfiguration in Terminalkonfiguration speichern
   string file    = GetLocalConfigPath();
   string section = "WindowStatus";
      int hWnd    = WindowHandle(Symbol(), NULL); if (!hWnd)   return(!catch("StoreWindowStatus(1)->WindowHandle() = 0 in context "+ ModuleTypeDescription(__TYPE__) +"::"+ __whereamiDescription(__WHEREAMI__), ERR_RUNTIME_ERROR));
   string key     = "SuperBars.Timeframe.0x"+ IntToHexStr(hWnd);
   if (!WritePrivateProfileStringA(section, key, value, file)) return(!catch("StoreWindowStatus(2)->kernel32::WritePrivateProfileStringA(section=\""+ section +"\", key=\""+ key +"\", value=\""+ value +"\", fileName=\""+ file +"\")", ERR_WIN32_ERROR));

   //debug("StoreWindowStatus()   stored \""+ value +"\"");
   return(catch("StoreWindowStatus(3)"));
}


/**
 * Restauriert die Fenster-relevanten Konfigurationsdaten aus dem Chart oder der Terminalkonfiguration.
 *
 *  - SuperbarTimeframe
 *
 * @return bool - Erfolgsstatus
 */
bool RestoreWindowStatus() {
   bool success = false;
   int  timeframe;

   // Versuchen, die Konfiguration aus dem Chart zu restaurieren (kann nach Laden eines neuen Templates fehlschlagen).
   string label = __NAME__ +".sticky.timeframe", empty="";
   if (ObjectFind(label) == 0) {
      string sValue = ObjectDescription(label);
      success       = StringIsInteger(sValue);
      timeframe     = StrToInteger(sValue);
   }

   // Bei Mißerfolg Konfiguration aus der Terminalkonfiguration restaurieren.
   if (!success) {
      int hWnd = WindowHandle(Symbol(), NULL);
      if (hWnd != 0) {
         string section = "WindowStatus";
         string key     = "SuperBars.Timeframe.0x"+ IntToHexStr(hWnd);
         sValue         = GetLocalConfigString(section, key, "");
         success        = StringIsInteger(sValue);
         timeframe      = StrToInteger(sValue);
      }
   }

   if (success)
      superBars.timeframe = timeframe;
   return(!catch("RestoreWindowStatus(1)"));
}
