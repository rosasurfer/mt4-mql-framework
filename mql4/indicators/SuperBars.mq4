/**
 * Hinterlegt den Chart mit Bars oder Candles übergeordneter Timeframes.
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdlib.mqh>


int   superTimeframe;
color color.bar.up   = C'0,200,0';          // Farbe der Up-Bars: Green, Lime
color color.bar.down = Red;            // Farbe der Down-Bars


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Timeframe der Superbars bestimmen
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

   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);
   return(catch("onInit()")); x.start();
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
   /*
   - Zeichenbereich bei jedem Tick ist der Bereich von ChangedBars (keine for-Schleife über alle ChangedBars).
   - Die erste Superbar reicht nach rechts über Bar[0] bis zum zukünftigen Supersession-Ende hinaus.
   - Die letzte Superbar reicht nach links über ChangedBars hinaus, wenn Bars > ChangedBars (ist zur Laufzeit Normalfall).
   */
   datetime openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv;
   int i,   openBar, closeBar, lastChartBar=Bars-1;


   datetime startTime = GetTickCount();


   // Schleife über alle Supersessions von "jung" nach "alt"
   while (true) { i++;
      if (!GetPreviousSession(superTimeframe, openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv))
         return(last_error);

      openBar = iBarShiftNext(NULL, NULL, openTime.srv);             // falls ERS_HISTORY_UPDATE auftritt, passiert das nur ein einziges mal (und genau hier)
      if (openBar == EMPTY_VALUE) return(SetLastError(warn("onTick(1)->iBarShiftNext() => EMPTY_VALUE", stdlib.GetLastError())));

      closeBar = iBarShiftPrevious(NULL, NULL, closeTime.srv-1*SECOND);
      if (closeBar == -1)                                            // closeTime ist zu alt für den Chart => Abbruch
         break;

      if (openBar >= closeBar) {
         if      (openBar != lastChartBar)                              { if (!DrawSuperBar(openTime.fxt, openBar, closeBar)) return(last_error); }
         else if (openBar == iBarShift(NULL, NULL, openTime.srv, true)) { if (!DrawSuperBar(openTime.fxt, openBar, closeBar)) return(last_error); }
      }                                                              // Die Supersession auf der letzten Chartbar ist fast nie vollständig, trotzdem mit (exact=TRUE) prüfen.
      if (openBar >= ChangedBars-1)
         break;                                                      // Superbars bis max. ChangedBars aktualisieren
   }

   datetime endTime = GetTickCount();


   //if (ChangedBars > 1) debug("onTick(0.1)   ChangedBars="+ ChangedBars +"  i="+ i +"  time: "+ DoubleToStr((endTime-startTime)/1000., 3) +" sec");

   return(last_error);
}


/**
 * Ermittelt Beginn und Ende der dem Parameter openTime.fxt vorhergehenden Session und schreibt das Ergebnis in die übergebenen
 * Variablen. Ist der Parameter openTime.fxt nicht gesetzt, wird die jüngste Session (also ggf. die aktuelle) zurückgegeben.
 *
 * @param  int       timeframe            - Timeframe der zu ermittelnden Session
 * @param  datetime &openTime.fxt         - Variable zur Aufnahme des Beginns der resultierenden Session in FXT-Zeit
 * @param  datetime &closeTime.fxt        - Variable zur Aufnahme des Endes der resultierenden Session in FXT-Zeit
 * @param  datetime &openTime.srv         - Variable zur Aufnahme des Beginns der resultierenden Session in Serverzeit
 * @param  datetime &closeTime.srv        - Variable zur Aufnahme des Endes der resultierenden Session in Serverzeit
 *
 * @return bool - Erfolgsstatus
 */
bool GetPreviousSession(int timeframe, datetime &openTime.fxt, datetime &closeTime.fxt, datetime &openTime.srv, datetime &closeTime.srv) {
   int month, dom, dow;


   // (1) PERIOD_D1
   if (timeframe == PERIOD_D1) {
      // ist openTime.fxt nicht gesetzt, mit Zeitpunkt des nächsten Tages initialisieren
      if (!openTime.fxt)
         openTime.fxt = TimeCurrent() + 1*DAY;     // TODO: TimeCurrent() kann NULL sein, statt dessen Serverzeit selbst berechnen

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
      // ist openTime.fxt nicht gesetzt, mit Zeitpunkt der nächsten Woche initialisieren
      if (!openTime.fxt)
         openTime.fxt = TimeCurrent() + 7*DAYS;    // TODO: TimeCurrent() kann NULL sein, statt dessen Serverzeit selbst berechnen

      // openTime.fxt auf Montag, 00:00 Uhr der vorherigen Woche setzen
      openTime.fxt -= (TimeHour(openTime.fxt)*HOURS + TimeMinute(openTime.fxt)*MINUTES + TimeSeconds(openTime.fxt));    // 00:00 des aktuellen Tages
      openTime.fxt -= (TimeDayOfWeek(openTime.fxt)+6)%7 * DAYS;                                                         // Montag der aktuellen Woche
      openTime.fxt -= 7*DAYS;                                                                                           // Montag der Vorwoche

      // closeTime.fxt auf 00:00 des folgenden Samstags setzen
      closeTime.fxt = openTime.fxt + 5*DAYS;
   }


   // (3) PERIOD_MN1
   else if (timeframe == PERIOD_MN1) {
      // ist openTime.fxt nicht gesetzt, mit Zeitpunkt des nächsten Monats initialisieren
      if (!openTime.fxt)                           // TODO: TimeCurrent() kann NULL sein, statt dessen Serverzeit selbst berechnen
         openTime.fxt = TimeCurrent() + 1*MONTH;   // 31 Tage oder mehr sind ok, wird falls ungenau als Kurslücke interpretiert und ausgelassen

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
      // ist openTime.fxt nicht gesetzt, mit Zeitpunkt des nächsten Quartals initialisieren
      if (!openTime.fxt)                           // TODO: TimeCurrent() kann NULL sein, statt dessen Serverzeit selbst berechnen
         openTime.fxt = TimeCurrent() + 1*QUARTER; // 3 Monate oder mehr sind ok, wird falls ungenau als Kurslücke interpretiert und ausgelassen

      openTime.fxt -= (TimeHour(openTime.fxt)*HOURS + TimeMinute(openTime.fxt)*MINUTES + TimeSeconds(openTime.fxt));    // 00:00 des aktuellen Tages

      // closeTime.fxt auf den ersten Tag des folgenden Quartals, 00:00 setzen
      switch (TimeMonth(openTime.fxt)) {
         case JANUARY  :
         case FEBRUARY :
         case MARCH    : closeTime.fxt = openTime.fxt - (TimeDayOfYear(openTime.fxt)-1)*DAYS; break;                    // erster Tag des aktuellen Quartals (01.01.)
         case APRIL    : closeTime.fxt = openTime.fxt -       (TimeDay(openTime.fxt)-1)*DAYS; break;
         case MAY      : closeTime.fxt = openTime.fxt - (30+   TimeDay(openTime.fxt)-1)*DAYS; break;
         case JUNE     : closeTime.fxt = openTime.fxt - (30+31+TimeDay(openTime.fxt)-1)*DAYS; break;                    // erster Tag des aktuellen Quartals (01.04.)
         case JULY     : closeTime.fxt = openTime.fxt -       (TimeDay(openTime.fxt)-1)*DAYS; break;
         case AUGUST   : closeTime.fxt = openTime.fxt - (31+   TimeDay(openTime.fxt)-1)*DAYS; break;
         case SEPTEMBER: closeTime.fxt = openTime.fxt - (31+31+TimeDay(openTime.fxt)-1)*DAYS; break;                    // erster Tag des aktuellen Quartals (01.07.)
         case OCTOBER  : closeTime.fxt = openTime.fxt -       (TimeDay(openTime.fxt)-1)*DAYS; break;
         case NOVEMBER : closeTime.fxt = openTime.fxt - (31+   TimeDay(openTime.fxt)-1)*DAYS; break;
         case DECEMBER : closeTime.fxt = openTime.fxt - (31+30+TimeDay(openTime.fxt)-1)*DAYS; break;                    // erster Tag des aktuellen Quartals (01.10.)
      }

      // openTime.fxt auf den ersten Tag des vorherigen Quartals, 00:00 Uhr setzen
      openTime.fxt = closeTime.fxt - 1*DAY;                                                                             // letzter Tag des vorherigen Quartals
      switch (TimeMonth(openTime.fxt)) {
         case MARCH    : openTime.fxt -= (TimeDayOfYear(openTime.fxt)-1)*DAYS; break;                                   // erster Tag des vorherigen Quartals (01.01.)
         case JUNE     : openTime.fxt -= (30+31+TimeDay(openTime.fxt)-1)*DAYS; break;                                   // erster Tag des vorherigen Quartals (01.04.)
         case SEPTEMBER: openTime.fxt -= (31+31+TimeDay(openTime.fxt)-1)*DAYS; break;                                   // erster Tag des vorherigen Quartals (01.07.)
         case DECEMBER : openTime.fxt -= (31+30+TimeDay(openTime.fxt)-1)*DAYS; break;                                   // erster Tag des vorherigen Quartals (01.10.)
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



   static int i;
   if (i <= 5) {
      //debug("GetPreviousSession("+ PeriodDescription(timeframe) +")   "+ i +" from '"+ DateToStr(openTime.fxt, "w D.M.Y H:I:S") +"' to '"+ DateToStr(closeTime.fxt, "w D.M.Y H:I:S") +"'");
      i++;
   }
   return(!catch("GetPreviousSession(2)"));
}


/**
 * Zeichnet eine einzelne Superbar.
 *
 * @param  datetime openTime - Startzeit der Supersession in FXT
 * @param  int      openBar  - Chartoffset der Open-Bar der Superbar
 * @param  int      closeBar - Chartoffset der Close-Bar der Superbar
 *
 * @return bool - Erfolgsstatus
 */
bool DrawSuperBar(datetime openTime.fxt, int openBar, int closeBar) {
   // High- und Low-Bar ermitteln
   int highBar = iHighest(NULL, NULL, MODE_HIGH, openBar-closeBar+1, closeBar);
   int lowBar  = iLowest (NULL, NULL, MODE_LOW , openBar-closeBar+1, closeBar);

   // Farbe bestimmen
   color barColor = Gray;     // C'232,232,232'                                                       // Ausgangsfarbe ist hellgrau,
   if (MathMax(Open[openBar],  Close[closeBar])/MathMin(Open[openBar], Close[closeBar]) > 1.0005) {   // ab ca. 5-8 pip Unterschied grün oder rot
      if      (Open[openBar] < Close[closeBar]) barColor = color.bar.up;
      else if (Open[openBar] > Close[closeBar]) barColor = color.bar.down;
   }

   // Label definieren
   string label;
   switch (superTimeframe) {
      case PERIOD_D1 : label = "Bar "+  DateToStr(openTime.fxt, "w D.M.Y");                             break;    // "w D.M.Y" wird bereits vom Grid verwendet
      case PERIOD_W1 : label = "Week "+ DateToStr(openTime.fxt,   "D.M.Y");                             break;
      case PERIOD_MN1: label =          DateToStr(openTime.fxt,     "N Y");                             break;
      case PERIOD_Q1 : label = ((TimeMonth(openTime.fxt)-1)/3+1) +". Quarter "+ TimeYear(openTime.fxt); break;
   }

   // Superbar zeichnen
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
      int closeBar_j = closeBar; /*endBar_justified*/                // Rechtecke um eine Chartbar nach rechts verbreitern, damit sie sich gegenseitig berühren
      //if (closeBar > 0) closeBar_j--;                                // außer bei Bar[0]
   if (ObjectCreate(label, OBJ_RECTANGLE, 0, Time[openBar], High[highBar], Time[closeBar_j], Low[lowBar])) {
      ObjectSet (label, OBJPROP_COLOR, barColor);
      ObjectSet (label, OBJPROP_BACK , true);
      PushObject(label);
   }
   else GetLastError();

   /*
   // (2.7) Close-Marker einzeichnen
   int centerBar = (startBar+endBar_j)/2;
   if (centerBar > endBar) {
      label = StringConcatenate(StringSubstr(label, 7), " Close");
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_TREND, 0, Time[centerBar], Close[endBar], Time[endBar], Close[endBar])) {
         ObjectSet (label, OBJPROP_RAY  , false);
         ObjectSet (label, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSet (label, OBJPROP_COLOR, Color.Close.Marker);
         ObjectSet (label, OBJPROP_BACK , true);
         PushObject(label);
      }
      else GetLastError();
   }
   */



   static int i;
   if (i <= 5) {
      //debug("DrawSuperBar("+ PeriodDescription(superTimeframe) +")   from="+ openBar +"  to="+ closeBar);
      //debug("DrawSuperBar("+ PeriodDescription(superTimeframe) +")   label=\""+ label +"\"");
      i++;
   }
   return(!catch("DrawSuperBar()"));
}


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
