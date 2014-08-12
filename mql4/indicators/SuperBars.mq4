/**
 * Hinterlegt den Chart mit Bars übergeordneter Timeframes.
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>


//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern string Timeframe          = "W";                  // anzuzeigender SuperTimeframe: [D | W* | M | Q]
extern color  Color.BarUp        = C'193,255,193';       // Up-Bars              blass: C'215,255,215'
extern color  Color.BarDown      = C'255,213,213';       // Down-Bars            blass: C'255,230,230'
extern color  Color.BarUnchanged = C'232,232,232';       // unveränderte Bars                               // oder Gray
extern color  Color.Close        = C'164,164,164';       // Close-Marker                                    // oder Black

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#include <core/indicator.mqh>


bool   superBars.off = false;                            // Die Anzeige wird ausgeschaltet, wenn der SuperTimeframe in der aktuellen Chartauflösung unsinnig ist.
int    superTimeframe;

string label.superbar = "SuperBar";                      // Label für Chartanzeige


#define STF_UP        1
#define STF_DOWN     -1


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   superBars.off = false;

   // (1) Parametervalidierung
   // Timeframe
   string value = StringToUpper(StringTrim(Timeframe));
   if      (value=="D" || value=="D1"  ) { superTimeframe = PERIOD_D1;  Timeframe = "D"; }
   else if (value=="W" || value=="W1"  ) { superTimeframe = PERIOD_W1;  Timeframe = "W"; }
   else if (value=="M" || value=="MN1" ) { superTimeframe = PERIOD_MN1; Timeframe = "M"; }
   else if (value=="Q" || value=="Q1"  ) { superTimeframe = PERIOD_Q1;  Timeframe = "Q"; }
   else return(catch("onInit(1)   Invalid input parameter Timeframe = \""+ Timeframe +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   switch (Period()) {
      case PERIOD_M1 :
      case PERIOD_M5 :
      case PERIOD_M15:
      case PERIOD_M30:
      case PERIOD_H1 :
      case PERIOD_H4 :
         break;

      case PERIOD_D1 :
         if (superTimeframe <= PERIOD_D1) superBars.off = true;      // min. W1 oder keine Anzeige
         break;

      case PERIOD_W1 :
         if (superTimeframe <= PERIOD_W1) superBars.off = true;      // min. MN1 oder keine Anzeige
         break;

      case PERIOD_MN1:
         superBars.off = true;                                       // keine Anzeige
         break;
   }

   // Colors
   if (Color.BarUp        == 0xFF000000) Color.BarUp   = CLR_NONE;   // CLR_NONE kann vom Terminal u.U. falsch gesetzt worden sein
   if (Color.BarDown      == 0xFF000000) Color.BarDown = CLR_NONE;
   if (Color.BarUnchanged == 0xFF000000) Color.BarDown = CLR_NONE;
   if (Color.Close        == 0xFF000000) Color.Close   = CLR_NONE;


   // (2) Label für Textanzeige erzeugen
   CreateDisplayLabel();


   // (3) Datenanzeige ausschalten
   SetIndexLabel(0, NULL);
   return(catch("onInit(2)"));
}


/**
 * Nach Änderung der aktuellen Chartperiode. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit.TimeframeChange() {
   RestoreStickyStatus();
   return(NO_ERROR);
}


/**
 * Nach Änderung des aktuellen Chartsymbols. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit.SymbolChange() {
   RestoreStickyStatus();
   return(NO_ERROR);
}


/**
 * Nach Laden des Indikators innerhalb eines Templates, auch bei Terminal-Start. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit.Template() {
   RestoreStickyStatus();        // Beim Umschalten zwischen Profilen wird so die letzte jeweilige Konfiguration reaktiviert.
   return(NO_ERROR);
}


/**
 * Bei Reload des Indikators nach Neukompilierung. Kein Input-Dialog
 *
 * @return int - Fehlerstatus
 */
int onInit.Recompile() {
   RestoreStickyStatus();
   return(NO_ERROR);
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   return(catch("onDeinit()"));
}


/**
 * außerhalb iCustom(): vor Symbol- oder Timeframewechsel
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onDeinitChartChange() {
   // bei Timeframe- und auch bei Symbolwechsel wird die aktuelle Konfiguration übernommen
   return(StoreStickyStatus());
}


/**
 * außerhalb iCustom(): Indikator von Hand entfernt oder Chart geschlossen, auch vorm Laden eines Profils oder Templates
 * innerhalb iCustom(): in allen deinit()-Fällen
 *
 * @return int - Fehlerstatus
 */
int onDeinitRemove() {
   // Terminal-Exit und bei Profilwechsel: beim Zurückwechseln zum selben Profil wird die letzte Konfiguration verwendet
   return(StoreStickyStatus());
}


/**
 * außerhalb iCustom(): bei Reload nach Recompilation
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onDeinitRecompile() {
   return(StoreStickyStatus());
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   HandleEvent(EVENT_CHART_CMD);    // ChartCommands verarbeiten
   UpdateSuperBars();               // SuperBars aktualisieren
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
      if      (commands[i] == "Timeframe=1" ) { if (!SwitchSuperTimeframe(STF_UP  )) return(false); }
      else if (commands[i] == "Timeframe=-1") { if (!SwitchSuperTimeframe(STF_DOWN)) return(false); }
      else
         warn("onChartCommand(2)   unknown chart command \""+ commands[i] +"\"");
   }
   return(!catch("onChartCommand(3)"));
}


/**
 * Schaltet den Parameter superTimeframe des Indikators um.
 *
 * @param  int id - Timeframe-ID
 *
 * @return bool - Erfolgsstatus
 */
bool SwitchSuperTimeframe(int id) {
   if (id == STF_UP) {
      switch (superTimeframe) {
         case PERIOD_D1 : superTimeframe = PERIOD_W1;  break;
         case PERIOD_W1 : superTimeframe = PERIOD_MN1; break;
         case PERIOD_MN1: superTimeframe = PERIOD_Q1;  break;
      }
   }
   else if (id == STF_DOWN) {
      switch (superTimeframe) {
         case PERIOD_W1 : superTimeframe = PERIOD_D1;  break;
         case PERIOD_MN1: superTimeframe = PERIOD_W1;  break;
         case PERIOD_Q1 : superTimeframe = PERIOD_MN1; break;
      }
   }
   else return(_true(warn("SwitchSuperTimeframe(1)   unknown parameter id = "+ id)));

   switch (Period()) {
      case PERIOD_D1 :
         if (superTimeframe <= PERIOD_D1) superBars.off = true;      // min. W1 oder keine Anzeige
         break;

      case PERIOD_W1 :
         if (superTimeframe <= PERIOD_W1) superBars.off = true;      // min. MN1 oder keine Anzeige
         break;

      case PERIOD_MN1:
         superBars.off = true;                                       // keine Anzeige
         break;
   }
   return(true);
}


/**
 * Aktualisiert die SuperBar-Anzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateSuperBars() {
   static bool lastSuperBars.off;
   static int  lastSuperTimeframe;

   // Wechseln SuperTimeframe oder der Status von superBars.off, müssen evt. vorhandene Bars gelöscht werden, solange
   // dies nicht der erste Aufruf nach einem init()-Cycle ist (statische Variablen sind noch nicht initialisiert).

   // (1) Konfigurationswechsel detektieren und vorhandene Bars löschen
   bool configChange = false;
   if (lastSuperTimeframe != 0) {                                    // 0: erster Aufruf seit init()
      if (superTimeframe != lastSuperTimeframe) {
         debug("UpdateSuperBars(0.1)   config change: lastStf="+ lastSuperTimeframe +"  now="+ superTimeframe);
         configChange = true;
      }
      else if (superBars.off != lastSuperBars.off) {
         debug("UpdateSuperBars(0.2)   config change: lastOff="+ lastSuperBars.off +"  now="+ superBars.off);
         configChange = true;
      }
      if (configChange) {
         DeleteRegisteredObjects(NULL);
         CreateDisplayLabel();
      }
   }


   // (2) Rückkehr bei ausgeschalteter Anzeige
   if (superBars.off) {
      lastSuperBars.off  = superBars.off;
      lastSuperTimeframe = superTimeframe;
      return(true);
   }


   // (3) Anzeige
   // - Zeichenbereich bei jedem Tick ist der Bereich von ChangedBars (jedoch keine for-Schleife über alle ChangedBars).
   // - Die erste, aktuelle Superbar reicht nur bis Bar[0], was Fortschritt und Relevanz der wachsenden Superbar veranschaulicht.
   // - Die letzte Superbar reicht nach links über ChangedBars hinaus, wenn Bars > ChangedBars (ist zur Laufzeit Normalfall).

   datetime openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv;
   int      openBar, closeBar, lastChartBar=Bars-1, i=-1, changedBars=ChangedBars;
   if (configChange)
      changedBars = Bars;                                            // bei Konfigurationswechsel müssen alle Bars neugezeichnet werden

   // Schleife über alle Superbars von "jung" nach "alt"
   //
   // Mit "Session" ist in der Folge keine 24-h-Session, sondern eine Periode des jeweiligen Super-Timeframes gemeint,
   // z.B. ein Tag, eine Woche oder ein Monat.
   while (true) {
      if (!GetPreviousSession(superTimeframe, openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv))
         return(false);

      // Ab Chartperiode PERIOD_D1 wird der Bar-Timestamp vom Broker nur noch in vollen Tagen gesetzt und der Timezone-Offset kann einen Monatsbeginn
      // fälschlicherweise in den vorherigen oder nächsten Monat setzen. Dies muß nur in der Woche, nicht jedoch am Wochenende korrigiert werden.
      if (Period()==PERIOD_D1) /*&&*/ if (superTimeframe>=PERIOD_MN1) {
         if (openTime.srv  < openTime.fxt ) /*&&*/ if (TimeDayOfWeek(openTime.srv )!=SUNDAY  ) openTime.srv  = openTime.fxt;     // Sonntagsbar: Server-Timezone westlich von FXT
         if (closeTime.srv > closeTime.fxt) /*&&*/ if (TimeDayOfWeek(closeTime.srv)!=SATURDAY) closeTime.srv = closeTime.fxt;    // Samstagsbar: Server-Timezone östlich von FXT
      }
      openBar = iBarShiftNext(NULL, NULL, openTime.srv);             // Da immer der aktuelle Timeframe benutzt wird, kann ERS_HISTORY_UPDATE eigentlich nie auftreten.
      if (openBar == EMPTY_VALUE) return(!SetLastError(warn("onTick(1)->iBarShiftNext() => EMPTY_VALUE", stdlib.GetLastError())));

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

   lastSuperBars.off  = superBars.off;
   lastSuperTimeframe = superTimeframe;
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
   else return(!catch("GetPreviousSession(1) unsupported timeframe = "+ PeriodToStr(timeframe), ERR_RUNTIME_ERROR));


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
      label = __NAME__ +"."+ label.superbar;
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
 * @param  string commands[] - Array zur Aufnahme aller eingetroffenen Commands
 * @param  int    flags      - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 */
bool EventListener.ChartCommand(string &commands[], int flags=NULL) {
   if (!IsChart)
      return(false);

   static string label="SuperBar.command", mutex="mutex.SuperBarCommand";


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
int CreateDisplayLabel() {
   string label = __NAME__ +"."+ label.superbar;

   if (ObjectFind(label) == 0)
      ObjectDelete(label);

   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 115);
      ObjectSet    (label, OBJPROP_YDISTANCE, 4  );
      ObjectSetText(label, " ", 1);
      ObjectRegister(label);
   }

   return(catch("CreateDisplayLabel(1)"));
}


/**
 * Speichert die volatile Konfiguration im Chart, sodaß sie im nächsten init()-Cycle daraus wiederhergestellt werden kann.
 * Die volatile Konfiguration umfaßt alle jenen internen Parameter, die sich zur Laufzeit ohne Aufruf des Config-Dialogs ändern können:
 *
 *  - bool superBars.off;
 *  - int  superTimeframe;
 *
 * @return int - Fehlerstatus
 */
int StoreStickyStatus() {
   // Die Konfiguration wird nur dann im Chart gespeichert, wenn sie gültig ist (z.B. nicht, wenn init() mit Fehler zurückkehrte).
   // TODO: Solange die Validierung nicht ausgelagert ist, muß superTimeframe hier nochmal manuell validiert werden.
   //
   // superBars.off                                                  // immer gültig
   // superTimeframe
   switch (superTimeframe) {
      case PERIOD_D1 :
      case PERIOD_W1 :
      case PERIOD_MN1:
      case PERIOD_Q1 : break;
      default:         return(NO_ERROR);
   }

   // Daten speichern
   string label = StringConcatenate(__NAME__, ".sticky.superBars.off");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, StringConcatenate("", superBars.off));       // (string) bool

   label = StringConcatenate(__NAME__, ".sticky.superTimeframe");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, StringConcatenate("", superTimeframe));      // (string) int

   return(catch("StoreStickyStatus(1)"));
}


/**
 * Restauriert die im Chart vorhandenen volatilen Konfigurationsdaten (@see StoreStickyStatus).
 *
 *  - bool superBars.off;
 *  - int  superTimeframe;
 *
 * @return bool - Erfolgsstatus (die gefundenen Daten werden nur übernommen, wenn sie vollständig gültig sind)
 */
bool RestoreStickyStatus() {
   // superBars.off
   string label = StringConcatenate(__NAME__, ".sticky.superBars.off");
   if (ObjectFind(label) != 0)   return(false);
   string strValue = StringTrim(ObjectDescription(label));
   if (!StringIsDigit(strValue)) return(_false(warn("RestoreStickyStatus(1)   unsupported chart value found \""+ label +"\" = \""+ ObjectDescription(label) +"\"")));
   bool _superBars.off = StrToInteger(strValue) != 0;

   // superTimeframe
   label = StringConcatenate(__NAME__, ".sticky.superTimeframe");
   if (ObjectFind(label) != 0)   return(false);
   strValue = StringTrim(ObjectDescription(label));
   if (!StringIsDigit(strValue)) return(_false(warn("RestoreStickyStatus(2)   unsupported chart value found \""+ label +"\" = \""+ ObjectDescription(label) +"\"")));
   int iValue = StrToInteger(strValue);
   switch (iValue) {
      case PERIOD_D1 :
      case PERIOD_W1 :
      case PERIOD_MN1:
      case PERIOD_Q1 : break;
      default:                   return(_false(warn("RestoreStickyStatus(3)   unsupported chart value found \""+ label +"\" = \""+ ObjectDescription(label) +"\"")));
   }
   int _superTimeframe = iValue;

   // globale Variablen erst nach vollständiger Validierung überschreiben
   superBars.off  = _superBars.off;
   superTimeframe = _superTimeframe;
   return(!catch("RestoreStickyStatus(4)"));
}
