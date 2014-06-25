/**
 * Hinterlegt den Chart mit Bars oder Candles übergeordneter Timeframes.
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>


//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern color Color.BarUp        = C'215,255,215';     // Up-Bars              kräftiger: C'170,255,170'     // neu: C'0,210,0'      Green, Lime
extern color Color.BarDown      = C'255,230,230';     // Down-Bars            kräftiger: C'255,193,193'     // neu: C'255,47,47'    Red
extern color Color.BarUnchanged = C'232,232,232';     // unveränderte Bars                                  // neu: Gray
extern color Color.CloseMarker  = C'164,164,164';     // Close-Marker                                       // neu: Black

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#include <core/indicator.mqh>


int    superTimeframe;
string label.superbar = "SuperBar";                                     // Label für Chartanzeige


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Color-Validierung
   if (Color.BarUp        == 0xFF000000) Color.BarUp       = CLR_NONE;  // CLR_NONE kann u.U. vom Terminal falsch gesetzt worden sein.
   if (Color.BarDown      == 0xFF000000) Color.BarDown     = CLR_NONE;
   if (Color.BarUnchanged == 0xFF000000) Color.BarDown     = CLR_NONE;
   if (Color.CloseMarker  == 0xFF000000) Color.CloseMarker = CLR_NONE;

   // anzuzeigenden Timeframe der Superbars bestimmen
   switch (Period()) {
      case PERIOD_M1 :
      case PERIOD_M5 :
      case PERIOD_M15:
      case PERIOD_M30:
      case PERIOD_H1 : superTimeframe = PERIOD_D1;  break;
      case PERIOD_H4 : superTimeframe = PERIOD_W1;  break;
      case PERIOD_D1 : superTimeframe = PERIOD_MN1; break;
      case PERIOD_W1 :
      case PERIOD_MN1: superTimeframe = PERIOD_Q1;  break;
   }

   // Label erzeugen
   CreateLabels();

   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);
   return(catch("onInit()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   RemoveChartObjects();
   return(catch("onDeinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (Period() == PERIOD_MN1)
      return(last_error);

   // - Zeichenbereich bei jedem Tick ist der Bereich von ChangedBars (keine for-Schleife über alle ChangedBars).
   // - Die erste, aktuelle Superbar reicht nur bis Bar[0], was Sessionfortschritt und Relevanz der wachsenden Bar veranschaulicht.
   // - Die letzte Superbar reicht nach links über ChangedBars hinaus, wenn Bars > ChangedBars (ist zur Laufzeit Normalfall).

   datetime openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv;
   int      openBar, closeBar, lastChartBar=Bars-1, i=-1;

   // Schleife über alle Supersessions von "jung" nach "alt"
   while (true) {
      if (!GetPreviousSession(superTimeframe, openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv))
         return(last_error);

      // Ab PERIOD_D1 ist die Barauflösung der Broker nur noch 1 Tag (keine Minuten mehr; praktisch fehlt der Zeitzonenoffset).
      if (Period() >= PERIOD_D1) {
         openTime.srv  = openTime.fxt;                               // TODO: Hier ist zusätzlich die berüchtigte 6. Sonntags-Bar möglich (z.B. bei Forex Ltd).
         closeTime.srv = closeTime.fxt;
      }
                                                                     // Da hier immer der aktuelle Timeframe benutzt wird, sollte ERS_HISTORY_UPDATE nie auftreten.
      openBar = iBarShiftNext(NULL, NULL, openTime.srv);             // Wenn doch, dann nur ein einziges mal (und nur hier).
      if (openBar == EMPTY_VALUE) return(SetLastError(warn("onTick(1)->iBarShiftNext() => EMPTY_VALUE", stdlib.GetLastError())));

      closeBar = iBarShiftPrevious(NULL, NULL, closeTime.srv-1*SECOND);
      if (closeBar == -1)                                            // closeTime ist zu alt für den Chart => Abbruch
         break;

      if (openBar >= closeBar) {
         if      (openBar != lastChartBar)                              { i++; if (!DrawSuperBar(i, openTime.fxt, openBar, closeBar)) return(last_error); }
         else if (openBar == iBarShift(NULL, NULL, openTime.srv, true)) { i++; if (!DrawSuperBar(i, openTime.fxt, openBar, closeBar)) return(last_error); }
      }                                                              // Die Supersession auf der letzten Chartbar ist äußerst selten vollständig, trotzdem mit (exact=TRUE) prüfen.
      if (openBar >= ChangedBars-1)
         break;                                                      // Superbars bis max. ChangedBars aktualisieren
   }
   return(last_error);
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
   else return(!catch("GetPreviousSession(1) unsupported timeframe = "+ PeriodToStr(timeframe), ERR_RUNTIME_ERROR));


   // (5) entsprechende Serverzeiten ermitteln
   openTime.srv  = FxtToServerTime(openTime.fxt );
   closeTime.srv = FxtToServerTime(closeTime.fxt);

   //static int i;
   //if (i <= 10) {
   //   debug("GetPreviousSession("+ PeriodDescription(timeframe) +")   "+ i +" from '"+ DateToStr(openTime.fxt, "w D.M.Y H:I:S") +"' to '"+ DateToStr(closeTime.fxt, "w D.M.Y H:I:S") +"'");
   //   i++;
   //}
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
   switch (superTimeframe) {
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
      ObjectSet (label, OBJPROP_COLOR, barColor);
      ObjectSet (label, OBJPROP_BACK , true    );
      PushObject(label);
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
            PushObject   (labelWithoutPrice);
         } else GetLastError();

         if (ObjectCreate(labelWithPrice, OBJ_TREND, 0, Time[centerBar], Close[closeBar], Time[closeBar], Close[closeBar])) {
            ObjectSet    (labelWithPrice, OBJPROP_RAY  , false            );
            ObjectSet    (labelWithPrice, OBJPROP_STYLE, STYLE_SOLID      );
            ObjectSet    (labelWithPrice, OBJPROP_COLOR, Color.CloseMarker);
            ObjectSet    (labelWithPrice, OBJPROP_BACK , true             );
            PushObject   (labelWithPrice);
         } else GetLastError();
      }
   }

   // bei Superbar[0] OHL-Anzeige aktualisieren
   if (closeBar == 0) {
      string sRange = "";
      switch (superTimeframe) {
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
      string fontName = "";
      int    fontSize = 8;                                                    // "MS Sans Serif"-8 entspricht in allen Builds der Menüschrift
      ObjectSetText(label.superbar, sRange, fontSize, fontName, Black);

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
 * Erzeugt das Label für die Chartanzeige.
 *
 * @return int - Fehlerstatus
 */
int CreateLabels() {
   // SuperBar-Label
   label.superbar = __NAME__ +"."+ label.superbar;

   if (ObjectFind(label.superbar) == 0)
      ObjectDelete(label.superbar);
   if (ObjectCreate(label.superbar, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.superbar, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label.superbar, OBJPROP_XDISTANCE, 115);
      ObjectSet    (label.superbar, OBJPROP_YDISTANCE, 4  );
      ObjectSetText(label.superbar, " ", 1);
      PushObject   (label.superbar);
   }
   else GetLastError();

   return(catch("CreateLabels()"));
}
