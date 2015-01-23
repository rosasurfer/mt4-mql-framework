/**
 * Hinterlegt den Chart mit Bars übergeordneter Timeframes. Die Änderung des Timeframes erfolgt per Hotkey.
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <win32api.mqh>

//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern color Color.BarUp        = C'193,255,193';        // Up-Bars
extern color Color.BarDown      = C'255,213,213';        // Down-Bars
extern color Color.BarUnchanged = C'232,232,232';        // (fast) unveränderte Bars
extern color Color.ETH          = C'255,255,176';        // Extended-Hours
extern color Color.CloseMarker  = C'164,164,164';        // Close-Marker

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#include <core/indicator.mqh>

int    superBars.timeframe;
bool   eth.likeFuture;                                   // ob das Instrument wie ein Globex-Derivat analysiert werden kann (Futures, Indizes, Commodities, Bonds, CFDs darauf)
bool   showOHLData;                                      // ob die aktuellen OHL-Daten angezeigt werden sollen

string label.description = "Description";                // Label für Chartanzeige


#define STF_UP             1
#define STF_DOWN          -1
#define PERIOD_D1_ETH   1441                             // PERIOD_D1 + 1


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Parametervalidierung
   // Colors
   if (Color.BarUp        == 0xFF000000) Color.BarUp       = CLR_NONE;  // aus CLR_NONE = 0xFFFFFFFF macht das Terminal nach Recompile oder Deserialisierung
   if (Color.BarDown      == 0xFF000000) Color.BarDown     = CLR_NONE;  // u.U. 0xFF000000 (entspricht Schwarz)
   if (Color.BarUnchanged == 0xFF000000) Color.BarDown     = CLR_NONE;
   if (Color.ETH          == 0xFF000000) Color.ETH         = CLR_NONE;
   if (Color.CloseMarker  == 0xFF000000) Color.CloseMarker = CLR_NONE;


   // (2) ETH/Future-Status ermitteln
   string futures[] = {"BRENT","DJIA","DJTA","EURUSD","EURX","NAS100","NASCOMP","RUS2000","SP500","USDX","WTI","XAGEUR","XAGJPY","XAGUSD","XAUEUR","XAUJPY","XAUUSD"};
   eth.likeFuture = StringInArray(futures, StdSymbol());


   // (3) Label für Superbar-Beschreibung erzeugen
   CreateDescriptionLabel();


   // (4) Status restaurieren
   if (!RestoreWindowStatus())
      return(last_error);


   // (5) Verfügbarkeit des eingestellten Superbar-Timeframes prüfen bzw. Default festlegen
   CheckSuperTimeframeAvailability();


   SetIndexLabel(0, NULL);                                              // Datenanzeige ausschalten
   return(catch("onInit(1)"));
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
   return(catch("onDeinit(1)"));
}


/**
 * Ermittelt die Anzahl der seit dem letzten Tick modifizierten Bars einer Datenreihe.  Entspricht der manuellen Ermittlung
 * der Variable ChangedBars für eine andere als die aktuelle Datenreihe.
 *
 * @param  string symbol    - Symbol der zu untersuchenden Zeitreihe  (default: NULL = aktuelles Symbol)
 * @param  int    period    - Periode der zu untersuchenden Zeitreihe (default: NULL = aktuelle Periode)
 * @param  int    execFlags - Ausführungssteuerung: Flags der Fehler, die still abgefangen werden sollen (default: keine)
 *
 * @return int - Baranzahl oder -1 (EMPTY), falls ein Fehler auftrat
 *
 * @throws ERS_HISTORY_UPDATE       - Wird still gesetzt, wenn im Parameter execFlags das Flag MUTE_ERS_HISTORY_UPDATE gesetzt ist. In diesem Fall ist der
 *                                    Rückgabewert der Funktion bei Auftreten des Fehlers der Wert der modifizierten Bars. Anderenfalls ist er -1 (Fehler).
 *
 * @throws ERR_SERIES_NOT_AVAILABLE - Wird still gesetzt, wenn im Parameter execFlags das Flag MUTE_ERR_SERIES_NOT_AVAILABLE gesetzt ist. Der Rückgabewert
 *                                    der Funktion bei Auftreten dieses Fehlers ist unabhängig von diesem Flag immer -1 (Fehler).
 */
int iChangedBars(string symbol/*=NULL*/, int period/*=NULL*/, int execFlags=NULL) {
   if (symbol == "0")                                                // (string) NULL
      symbol = Symbol();
   /*
   TODO:
   -----
   - statische Variablen müssen je Symbol und Periode zwichengespeichert werden
   - statische Variablen in Library speichern, um Timeframewechsel zu überdauern
   - statische Variablen bei Accountwechsel zurücksetzen
   */

   static int      prev.bars         = -1;
   static datetime prev.lastBarTime  =  0;
   static datetime prev.firstBarTime =  0;

   int bars  = iBars(symbol, period);
   int error = GetLastError();

   // Fehlerbehandlung je nach execFlags
   if (!bars || error) {
      if (!bars && error!=ERR_SERIES_NOT_AVAILABLE) {
         // - Beim ersten Zugriff auf die Datenreihe wird statt ERR_SERIES_NOT_AVAILABLE gewöhnlich ERS_HISTORY_UPDATE gesetzt.
         // - Ohne Server-Connection ist nach Recompilation u.U. gar kein Fehler gesetzt (trotz fehlender Bars).
         if (!error || error==ERS_HISTORY_UPDATE) error = ERR_SERIES_NOT_AVAILABLE;                // NO_ERROR und ERS_HISTORY_UPDATE überschreiben
         else warn("iChangedBars(1)->iBars("+ symbol +","+ PeriodDescription(period) +") = "+ bars, error);
      }

      if (error == ERR_SERIES_NOT_AVAILABLE) {
         prev.bars = 0;
         if (!execFlags & MUTE_ERR_SERIES_NOT_AVAILABLE) return(_EMPTY(catch("iChangedBars(2)->iBars("+ symbol +","+ PeriodDescription(period) +")", error)));
         else                                            return(_EMPTY(SetLastError(error)));
      }
      else if (error!=ERS_HISTORY_UPDATE || !execFlags & MUTE_ERS_HISTORY_UPDATE) {
         prev.bars = bars;                               return(_EMPTY(catch("iChangedBars(3)->iBars("+ symbol +","+ PeriodDescription(period) +")", error)));
      }
      SetLastError(error);                                                                         // ERS_HISTORY_UPDATE still setzen und fortfahren
   }
   // bars ist hier immer größer 0

   datetime lastBarTime  = iTime(symbol, period, bars-1);
   datetime firstBarTime = iTime(symbol, period, 0     );
   int      changedBars;

   if      (error==ERS_HISTORY_UPDATE || prev.bars==-1)       changedBars = bars;                  // erster Zugriff auf die Zeitreihe
   else if (bars==prev.bars && lastBarTime==prev.lastBarTime) changedBars = 1;                     // Baranzahl gleich und älteste Bar noch dieselbe = normaler Tick (mit/ohne Lücke)
   else if (firstBarTime != prev.firstBarTime)                changedBars = bars - prev.bars + 1;  // neue Bars zu Beginn hinzugekommen
   else                                                       changedBars = bars;                  // neue Bars in Lücke eingefügt (nicht eindeutig => alle als modifiziert melden)

   prev.bars         = bars;
   prev.lastBarTime  = lastBarTime;
   prev.firstBarTime = firstBarTime;

   error = GetLastError();
   if (!error)
      return(changedBars);
   return(_EMPTY(catch("iChangedBars(4)->iBars("+ symbol +","+ PeriodDescription(period) +")", error)));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   HandleEvent(EVENT_CHART_CMD);                                     // ChartCommands verarbeiten
   UpdateSuperBars();                                                // Superbars aktualisieren
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
 * Schaltet den Parameter superBars.timeframe des Indikators um.
 *
 * @param  int direction - Richtungs-ID:  STF_UP|STF_DOWN
 *
 * @return bool - Erfolgsstatus
 */
bool SwitchSuperTimeframe(int direction) {
   bool reset = false;

   if (direction == STF_DOWN) {
      switch (superBars.timeframe) {
         case  INT_MIN      : PlaySoundEx("Plonk.wav");          break;    // Plonk, we hit a wall!

         case  PERIOD_D1_ETH:
         case -PERIOD_D1_ETH: superBars.timeframe =  INT_MIN;    break;

         case  PERIOD_D1    : superBars.timeframe = ifInt(eth.likeFuture,  PERIOD_D1_ETH, INT_MIN); break;
         case -PERIOD_D1    : superBars.timeframe = ifInt(eth.likeFuture, -PERIOD_D1_ETH, INT_MIN); break;

         case  PERIOD_W1    : superBars.timeframe =  PERIOD_D1;  break;
         case -PERIOD_W1    : superBars.timeframe = -PERIOD_D1;  break;

         case  PERIOD_MN1   : superBars.timeframe =  PERIOD_W1;  break;
         case -PERIOD_MN1   : superBars.timeframe = -PERIOD_W1;  break;

         case  PERIOD_Q1    : superBars.timeframe =  PERIOD_MN1; break;
         case -PERIOD_Q1    : superBars.timeframe = -PERIOD_MN1; break;

         case  INT_MAX      : superBars.timeframe =  PERIOD_Q1;  break;
      }
   }
   else if (direction == STF_UP) {
      switch (superBars.timeframe) {
         case  INT_MIN      : superBars.timeframe =  ifInt(eth.likeFuture, PERIOD_D1_ETH, PERIOD_D1); break;

         case  PERIOD_D1_ETH: superBars.timeframe =  PERIOD_D1;  break;
         case -PERIOD_D1_ETH: superBars.timeframe = -PERIOD_D1;  break;

         case  PERIOD_D1    : superBars.timeframe =  PERIOD_W1;  break;
         case -PERIOD_D1    : superBars.timeframe = -PERIOD_W1;  break;

         case  PERIOD_W1    : superBars.timeframe =  PERIOD_MN1; break;
         case -PERIOD_W1    : superBars.timeframe = -PERIOD_MN1; break;

         case  PERIOD_MN1   : superBars.timeframe =  PERIOD_Q1;  break;
         case -PERIOD_MN1   : superBars.timeframe = -PERIOD_Q1;  break;

         case  PERIOD_Q1    : superBars.timeframe =  INT_MAX;    break;

         case  INT_MAX      : PlaySoundEx("Plonk.wav" );         break;   // Plonk, we hit a wall!
      }
   }
   else warn("SwitchSuperTimeframe(1)   unknown parameter direction = "+ direction);

   CheckSuperTimeframeAvailability();                                   // Verfügbarkeit der Einstellung prüfen
   return(true);
}


/**
 * Prüft, ob der gewählte Superbar-Timeframe in der aktuellen Chartperiode angezeigt werden kann und
 * aktiviert/deaktiviert ihn entsprechend.
 *
 * @return bool - Erfolgsstatus
 */
bool CheckSuperTimeframeAvailability() {

   // Timeframes prüfen und ggf. aktivieren/deaktivieren
   switch (superBars.timeframe) {
      // off: kann nur manuell aktiviert werden
      case  INT_MIN      :
      case  INT_MAX      : break;

      // aktiviert: wird automatisch deaktiviert, wenn Anzeige in aktueller Chartperiode unsinnig ist
      case  PERIOD_D1_ETH:
      case  PERIOD_D1    : if (Period() >  PERIOD_H1) superBars.timeframe *= -1; break;
      case  PERIOD_W1    : if (Period() >  PERIOD_H4) superBars.timeframe *= -1; break;
      case  PERIOD_MN1   : if (Period() >  PERIOD_D1) superBars.timeframe *= -1; break;
      case  PERIOD_Q1    : if (Period() >  PERIOD_W1) superBars.timeframe *= -1; break;

      // deaktiviert: wird automatisch aktiviert, wenn Anzeige in aktueller Chartperiode Sinn macht
      case -PERIOD_D1_ETH:
      case -PERIOD_D1    : if (Period() <= PERIOD_H1) superBars.timeframe *= -1; break;
      case -PERIOD_W1    : if (Period() <= PERIOD_H4) superBars.timeframe *= -1; break;
      case -PERIOD_MN1   : if (Period() <= PERIOD_D1) superBars.timeframe *= -1; break;
      case -PERIOD_Q1    : if (Period() <= PERIOD_W1) superBars.timeframe *= -1; break;

      // nicht initialisierter bzw. ungültiger Timeframe: Default festlegen
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
   return(true);
}


/**
 * Aktualisiert die Superbar-Anzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateSuperBars() {
   // (1) bei Superbar-Timeframe-Wechsel vorm Aktualisieren alle vorhandenen Bars löschen
   static int static.lastTimeframe;
   bool timeframeChanged = (superBars.timeframe != static.lastTimeframe);  // der erste Aufruf (lastTimeframe==0) wird auch als Wechsel interpretiert

   if (timeframeChanged) {
      if (PERIOD_M1 <= static.lastTimeframe) /*&&*/ if (static.lastTimeframe <= PERIOD_Q1) {
         DeleteRegisteredObjects(NULL);                                    // in allen anderen Fällen wurden vorhandene Superbars bereits vorher gelöscht
         CreateDescriptionLabel();
      }
      UpdateDescription();
   }


   // (2) bei deaktivierten Superbars sofortige Rückkehr
   switch (superBars.timeframe) {
      case  INT_MIN      :                                                 // manuell abgeschaltet
      case  INT_MAX      :
      case -PERIOD_D1_ETH:                                                 // automatisch abgeschaltet
      case -PERIOD_D1    :                                                 // automatisch abgeschaltet
      case -PERIOD_W1    :
      case -PERIOD_MN1   :
      case -PERIOD_Q1    :
         static.lastTimeframe = superBars.timeframe;
         return(true);
   }


   datetime openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv;
   int      openBar, closeBar, lastChartBar=Bars-1, changedBars=ChangedBars, superTimeframe=superBars.timeframe;
   bool     drawETH;
   if (timeframeChanged)
      changedBars = Bars;                                                  // bei Superbar-Timeframe-Wechsel müssen alle Bars neugezeichnet werden


   // (3) Sollen Extended-Hours angezeigt werden, muß der Bereich von ChangedBars immer auch iChangedBars(PERIOD_M15) einschließen
   if (eth.likeFuture) /*&&*/ if (superBars.timeframe==PERIOD_D1_ETH) {
      superTimeframe = PERIOD_D1;

      // TODO: Wenn timeframeChanged=TRUE läßt sich der ganze Block sparen, es gilt immer: changedBars = Bars
      //       Allerdings müssen dann in DrawSuperBar() nochmal ERS_HISTORY_UPDATE und ERR_SERIES_NOT_AVAILABLE behandelt werden.

      int prev_error      = last_error;
      int changedBars.M15 = iChangedBars(NULL, PERIOD_M15, MUTE_ERS_HISTORY_UPDATE|MUTE_ERR_SERIES_NOT_AVAILABLE);
      if (changedBars.M15 == -1) {
         if (last_error != ERR_SERIES_NOT_AVAILABLE)                       // ERR_SERIES_NOT_AVAILABLE ggf. unterdrücken und mit dem letzten vorherigen Fehler überschreiben
            return(false);
         SetLastError(prev_error);
      }

      if (changedBars.M15 > 0) {
         datetime lastBarTime.M15 = iTime(NULL, PERIOD_M15, changedBars.M15-1);

         if (Time[changedBars-1] > lastBarTime.M15) {
            int bar = iBarShiftPrevious(NULL, NULL, lastBarTime.M15);
            if (bar == -1) changedBars = Bars;                             // M15-Zeitpunkt ist zu alt für den aktuellen Chart
            else           changedBars = bar + 1;
         }
         drawETH = true;
      }
   }


   // (4) Superbars aktualisieren
   //   - Zeichenbereich bei jedem Tick ist der Bereich von ChangedBars (jedoch keine for-Schleife über alle ChangedBars).
   //   - Die jüngste Superbar reicht nach rechts nur bis Bar[0], was Fortschritt und Relevanz der wachsenden Superbar veranschaulicht.
   //   - Die älteste Superbar reicht nach links über ChangedBars hinaus, wenn Bars > ChangedBars (zur Laufzeit Normalfall).
   //   - Mit "Session" ist in der Folge keine 24-h-Session, sondern eine Periode des jeweiligen Super-Timeframes gemeint,
   //     z.B. ein Tag, eine Woche oder ein Monat.
   //
   // Schleife über alle Superbars von "jung" nach "alt"
   while (true) {
      if (!GetPreviousSession(superTimeframe, openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv))
         return(false);

      // Ab Chartperiode PERIOD_D1 wird der Bar-Timestamp vom Broker nur noch in vollen Tagen gesetzt und der Timezone-Offset kann einen Monatsbeginn
      // fälschlicherweise in den vorherigen oder nächsten Monat setzen. Dies muß nur in der Woche, nicht jedoch am Wochenende korrigiert werden.
      if (Period()==PERIOD_D1) /*&&*/ if (superTimeframe>=PERIOD_MN1) {
         if (openTime.srv  < openTime.fxt ) /*&&*/ if (TimeDayOfWeek(openTime.srv )!=SUNDAY  ) openTime.srv  = openTime.fxt;     // Sonntagsbar: Server-Timezone westlich von FXT
         if (closeTime.srv > closeTime.fxt) /*&&*/ if (TimeDayOfWeek(closeTime.srv)!=SATURDAY) closeTime.srv = closeTime.fxt;    // Samstagsbar: Server-Timezone östlich von FXT
      }
      openBar = iBarShiftNext(NULL, NULL, openTime.srv);                   // ERS_HISTORY_UPDATE kann nicht auftreten, da der aktuelle Timeframe benutzt wird
      if (openBar == EMPTY_VALUE) return(!SetLastError(warn("UpdateSuperBars(2)->iBarShiftNext() => EMPTY_VALUE", stdlib.GetLastError())));

      closeBar = iBarShiftPrevious(NULL, NULL, closeTime.srv-1*SECOND);
      if (closeBar == -1)                                                  // closeTime ist zu alt für den Chart => Abbruch
         break;

      if (openBar >= closeBar) {
         if      (openBar != lastChartBar)                              { if (!DrawSuperBar(openBar, closeBar, openTime.fxt, openTime.srv, drawETH)) return(false); }
         else if (openBar == iBarShift(NULL, NULL, openTime.srv, true)) { if (!DrawSuperBar(openBar, closeBar, openTime.fxt, openTime.srv, drawETH)) return(false); }
      }                                                                    // Die Supersession auf der letzten Chartbar ist selten genau vollständig, trotzdem mit (exact=TRUE) prüfen.
      if (openBar >= changedBars-1)
         break;                                                            // Superbars bis max. changedBars aktualisieren
   }


   // (5) OHL-Anzeige aktualisieren (falls zutreffend)
   if (showOHLData)
      UpdateDescription();

   static.lastTimeframe = superBars.timeframe;
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

   return(!catch("GetPreviousSession(2)"));
}


/**
 * Zeichnet eine einzelne Superbar.
 *
 * @param  int      openBar      - Chartoffset der Open-Bar der Superbar
 * @param  int      closeBar     - Chartoffset der Close-Bar der Superbar
 * @param  datetime openTime.fxt - FXT-Startzeit der Supersession
 * @param  datetime openTime.srv - Server-Startzeit der Supersession
 * @param  bool    &drawETH      - Zeiger auf Variable, die anzeigt, ob die ETH-Session der Superbar gezeichnet werden soll
 *
 * @return bool - Erfolgsstatus
 */
bool DrawSuperBar(int openBar, int closeBar, datetime openTime.fxt, datetime openTime.srv, bool &drawETH) {
   // (1.1) High- und Low-Bar ermitteln
   int highBar = iHighest(NULL, NULL, MODE_HIGH, openBar-closeBar+1, closeBar);
   int lowBar  = iLowest (NULL, NULL, MODE_LOW , openBar-closeBar+1, closeBar);

   // (1.2) Farbe bestimmen
   color barColor = Color.BarUnchanged;
   if (openBar < Bars-1) double openPrice = Close[openBar+1];                          // Als OpenPrice wird nach Möglichkeit das Close der vorherigen Bar verwendet.
   else                         openPrice = Open [openBar];
   if (MathMax(openPrice,  Close[closeBar])/MathMin(openPrice, Close[closeBar]) > 1.0005) {
      if      (openPrice < Close[closeBar]) barColor = Color.BarUp;                    // Ab ca. 5-10 pip Preisunterschied werden Color.BarUp bzw. Color.BarDown verwendet.
      else if (openPrice > Close[closeBar]) barColor = Color.BarDown;
   }

   // (1.3) Label definieren
   string label;
   switch (superBars.timeframe) {
      case PERIOD_D1_ETH:
      case PERIOD_D1    : label =          DateToStr(openTime.fxt, "w D.M.Y ");                            break; // "w D.M.Y" wird bereits vom Grid verwendet
      case PERIOD_W1    : label = "Week "+ DateToStr(openTime.fxt,   "D.M.Y" );                            break;
      case PERIOD_MN1   : label =          DateToStr(openTime.fxt,     "N Y" );                            break;
      case PERIOD_Q1    : label = ((TimeMonth(openTime.fxt)-1)/3+1) +". Quarter "+ TimeYear(openTime.fxt); break;
   }

   // (1.4) Superbar zeichnen
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
      int closeBar_j = closeBar; /*j: justified*/                                      // Rechtecke um eine Chartbar nach rechts verbreitern, damit sie sich gegenseitig berühren.
      if (closeBar > 0) closeBar_j--;                                                  // jedoch nicht bei der jüngsten Bar[0]
   if (ObjectCreate(label, OBJ_RECTANGLE, 0, Time[openBar], High[highBar], Time[closeBar_j], Low[lowBar])) {
      ObjectSet     (label, OBJPROP_COLOR, barColor);
      ObjectSet     (label, OBJPROP_BACK , true    );
      ObjectRegister(label);
   }
   else GetLastError();
                                                                                       // TODO: nach Market-Close Marker auch bei der jüngsten Session zeichnen
   // (1.5) Close-Marker zeichnen
   if (closeBar > 0) {                                                                 // jedoch nicht bei der jüngsten Bar[0], die Session ist noch nicht beendet
      int centerBar = (openBar+closeBar)/2;

      if (centerBar > closeBar) {
         string labelWithPrice, labelWithoutPrice=label +" Close";

         if (ObjectFind(labelWithoutPrice) == 0) {                                     // Jeder Marker besteht aus zwei Objekten: Ein unsichtbares Label (erstes Objekt) mit
            labelWithPrice = ObjectDescription(labelWithoutPrice);                     // festem Namen, das in der Beschreibung den veränderlichen Namen des sichtbaren Markers
            if (ObjectFind(labelWithPrice) == 0)                                       // (zweites Objekt) enthält. So kann ein bereits vorhandener Marker einer Superbar im
               ObjectDelete(labelWithPrice);                                           // Chart gefunden und durch einen neuen ersetzt werden, obwohl sich sein dynamischer Name
            ObjectDelete(labelWithoutPrice);                                           // geändert hat.
         }
         labelWithPrice = labelWithoutPrice +" "+ DoubleToStr(Close[closeBar], PipDigits);

         if (ObjectCreate(labelWithoutPrice, OBJ_LABEL, 0, 0, 0)) {
            ObjectSet    (labelWithoutPrice, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
            ObjectSetText(labelWithoutPrice, labelWithPrice);
            ObjectRegister(labelWithoutPrice);
         } else GetLastError();

         if (ObjectCreate(labelWithPrice, OBJ_TREND, 0, Time[centerBar], Close[closeBar], Time[closeBar], Close[closeBar])) {
            ObjectSet    (labelWithPrice, OBJPROP_RAY  , false);
            ObjectSet    (labelWithPrice, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSet    (labelWithPrice, OBJPROP_COLOR, Color.CloseMarker);
            ObjectSet    (labelWithPrice, OBJPROP_BACK , true);
            ObjectRegister(labelWithPrice);
         } else GetLastError();
      }
   }


   // (2) Extended-Hours markieren (falls zutreffend)
   while (drawETH) {                                                                   // die Schleife dient nur dem einfacheren Verlassen des ETH-Blocks
      // (2.1) High und Low ermitteln
      datetime eth.openTime.srv  = openTime.srv;                                       // wie reguläre Starttime der 24h-Session (00:00 FXT)
      datetime eth.closeTime.srv = openTime.srv + 16*HOURS + 30*MINUTES;               // Handelsbeginn Globex Chicago           (16:30 FXT)

      int eth.openBar  = openBar;                                                      // reguläre OpenBar der 24h-Session
      int eth.closeBar = iBarShiftPrevious(NULL, NULL, eth.closeTime.srv-1*SECOND);    // openBar ist hier immer >= closeBar (Prüfung oben)
         if (eth.openBar <= eth.closeBar) break;                                       // Abbruch, wenn openBar nicht größer als closeBar (kein Platz zum Zeichnen)

      int eth.M15.openBar = iBarShiftNext(NULL, PERIOD_M15, eth.openTime.srv);         // ERS_HISTORY_UPDATE kann nicht mehr aufreten, da schon iChangedBars(M15) aufgerufen wurde
         if (eth.M15.openBar == EMPTY_VALUE) return(!warn("DrawSuperBar(1)->iBarShiftNext("+ Symbol() +",M15) => EMPTY_VALUE", stdlib.GetLastError()));
         if (eth.M15.openBar == -1)          break;                                    // Daten sind noch nicht da (HISTORY_UPDATE sollte laufen)

      int eth.M15.closeBar = iBarShiftPrevious(NULL, PERIOD_M15, eth.closeTime.srv-1*SECOND);
         if (eth.M15.closeBar == EMPTY_VALUE)    return(!warn("DrawSuperBar(2)->iBarShiftPrevious() => EMPTY_VALUE", stdlib.GetLastError()));
         if (eth.M15.closeBar == -1) { drawETH = false; break; }                       // die vorhandenen Daten reichen nicht soweit zurück, Abbruch aller weiteren ETH's
         if (eth.M15.openBar < eth.M15.closeBar) break;                                // die vorhandenen Daten weisen eine Lücke auf

      int eth.M15.highBar = iHighest(NULL, PERIOD_M15, MODE_HIGH, eth.M15.openBar-eth.M15.closeBar+1, eth.M15.closeBar);
      int eth.M15.lowBar  = iLowest (NULL, PERIOD_M15, MODE_LOW , eth.M15.openBar-eth.M15.closeBar+1, eth.M15.closeBar);

      double eth.open     = iOpen (NULL, PERIOD_M15, eth.M15.openBar );
      double eth.high     = iHigh (NULL, PERIOD_M15, eth.M15.highBar );
      double eth.low      = iLow  (NULL, PERIOD_M15, eth.M15.lowBar  );
      double eth.close    = iClose(NULL, PERIOD_M15, eth.M15.closeBar);

      // (2.2) Label definieren
      string eth.label    = label +" ETH";
      string eth.bg.label = label +" ETH background";

      // (2.3) ETH-Background zeichnen (erzeugt ein optisches Loch in der Superbar)
      if (ObjectFind(eth.bg.label) == 0)
         ObjectDelete(eth.bg.label);
      if (ObjectCreate(eth.bg.label, OBJ_RECTANGLE, 0, Time[eth.openBar], eth.high, Time[eth.closeBar], eth.low)) {
         ObjectSet     (eth.bg.label, OBJPROP_COLOR, barColor);                        // NOTE: Die Farben sich überlappender Shape-Bereiche werden mit der Charthintergrundfarbe
         ObjectSet     (eth.bg.label, OBJPROP_BACK , true);                            //       gemäß gdi32::SetROP2(HDC hdc, R2_NOTXORPEN) gemischt (siehe Beispiel am Funktionsende).
         ObjectRegister(eth.bg.label);                                                 //       Da wir die Charthintergrundfarbe im Moment noch nicht ermitteln können, benutzen wir
      }                                                                                //       einen Trick: Eine Farbe mit sich selbst gemischt ergibt immer Weiß, Weiß mit einer
                                                                                       //       anderen Farbe gemischt ergibt wieder die andere Farbe.
      // (2.4) ETH-Bar zeichnen (füllt das Loch mit der ETH-Farbe)                     //       Damit erzeugen wir ein "Loch" in der Farbe des Charthintergrunds in der Superbar.
      if (ObjectFind(eth.label) == 0)                                                  //       In dieses Loch zeichnen wir die ETH-Bar. Ihre Farbe wird NICHT mit der Farbe des "Lochs"
         ObjectDelete(eth.label);                                                      //       gemischt (warum auch immer), vermutlich setzt das Terminal einen anderen Drawing-Mode.
      if (ObjectCreate(eth.label, OBJ_RECTANGLE, 0, Time[eth.openBar], eth.high, Time[eth.closeBar], eth.low)) {
         ObjectSet     (eth.label, OBJPROP_COLOR, Color.ETH);
         ObjectSet     (eth.label, OBJPROP_BACK , true     );
         ObjectRegister(eth.label);
      }

      // (2.5) ETH-Rahmen zeichnen

      // (2.6) ETH-Close-Marker zeichnen, wenn die Extended-Hours beendet sind
      if (TimeCurrent() > eth.closeTime.srv) {
         int eth.centerBar = (eth.openBar+eth.closeBar)/2;

         if (eth.centerBar > eth.closeBar) {
            string eth.labelWithPrice, eth.labelWithoutPrice=eth.label +" Close";

            if (ObjectFind(eth.labelWithoutPrice) == 0) {                              // Jeder Marker besteht aus zwei Objekten: Ein unsichtbares Label (erstes Objekt) mit
               eth.labelWithPrice = ObjectDescription(eth.labelWithoutPrice);          // festem Namen, das in der Beschreibung den veränderlichen Namen des sichtbaren Markers
               if (ObjectFind(eth.labelWithPrice) == 0)                                // (zweites Objekt) enthält. So kann ein bereits vorhandener Marker einer ETH-Bar im
                  ObjectDelete(eth.labelWithPrice);                                    // Chart gefunden und durch einen neuen ersetzt werden, obwohl sich sein dynamischer Name
               ObjectDelete(eth.labelWithoutPrice);                                    // geändert hat.
            }
            eth.labelWithPrice = eth.labelWithoutPrice +" "+ DoubleToStr(eth.close, PipDigits);

            if (ObjectCreate(eth.labelWithoutPrice, OBJ_LABEL, 0, 0, 0)) {
               ObjectSet    (eth.labelWithoutPrice, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
               ObjectSetText(eth.labelWithoutPrice, eth.labelWithPrice);
               ObjectRegister(eth.labelWithoutPrice);
            } else GetLastError();

            if (ObjectCreate(eth.labelWithPrice, OBJ_TREND, 0, Time[eth.centerBar], eth.close, Time[eth.closeBar], eth.close)) {
               ObjectSet    (eth.labelWithPrice, OBJPROP_RAY  , false);
               ObjectSet    (eth.labelWithPrice, OBJPROP_STYLE, STYLE_SOLID);
               ObjectSet    (eth.labelWithPrice, OBJPROP_COLOR, Color.CloseMarker);
               ObjectSet    (eth.labelWithPrice, OBJPROP_BACK , true);
               ObjectRegister(eth.labelWithPrice);
            } else GetLastError();
         }
      }
      break;
   }
   /*
   Beispiel zum Mischen von Farben gemäß gdi32::SetROP2(HDC hdc, R2_NOTXORPEN):
   ----------------------------------------------------------------------------
   Welche Farbe muß ein Shape haben, damit es nach dem Mischen mit der Chartfarbe {248,248,248} und einem rosa-farbenen Shape {255,213,213} grün {0,255,0} erscheint?

      Chart R: 11111000  G: 11111000  B: 11111000 = rgb(248,248,248)
    + Rosa     11111111     11010101     11010101 = rgb(255,213,213)
      -------------------------------------------
      NOT-XOR: 11111000     11010010     11010010 = chart + rosa        NOT-XOR: Bit wird gesetzt, wenn die Bits in OP1 und OP2 gleich sind.
    +          00000111     11010010     00101101 = rgb(7,210,45)    -> Farbe, die gemischt mit dem Zwischenergebnis (chart + rosa) die gewünschte Farbe ergibt.
      ===========================================
      NOT-XOR: 00000000     11111111     00000000 = rgb(0,255,0) = grün

   Die für das Shape zu verwendende Farbe ist rgb(7,210,45).
   */
   return(!catch("DrawSuperBar(3)"));
}


/**
 * Aktualisiert die Superbar-Textanzeige.
 *
 * @return bool - Ergebnis
 */
bool UpdateDescription() {
   string description;

   switch (superBars.timeframe) {
      case  PERIOD_M1    : description = "Superbars: 1 Minute";         break;
      case  PERIOD_M5    : description = "Superbars: 5 Minutes";        break;
      case  PERIOD_M15   : description = "Superbars: 15 Minutes";       break;
      case  PERIOD_M30   : description = "Superbars: 30 Minutes";       break;
      case  PERIOD_H1    : description = "Superbars: 1 Hour";           break;
      case  PERIOD_H4    : description = "Superbars: 4 Hours";          break;
      case  PERIOD_D1    : description = "Superbars: Days";             break;
      case  PERIOD_D1_ETH: description = "Superbars: Days + ETH";       break;
      case  PERIOD_W1    : description = "Superbars: Weeks";            break;
      case  PERIOD_MN1   : description = "Superbars: Months";           break;
      case  PERIOD_Q1    : description = "Superbars: Quarters";         break;

      case -PERIOD_M1    : description = "Superbars: 1 Minute (n/a)";   break;
      case -PERIOD_M5    : description = "Superbars: 5 Minutes (n/a)";  break;
      case -PERIOD_M15   : description = "Superbars: 15 Minutes (n/a)"; break;
      case -PERIOD_M30   : description = "Superbars: 30 Minutes (n/a)"; break;
      case -PERIOD_H1    : description = "Superbars: 1 Hour (n/a)";     break;
      case -PERIOD_H4    : description = "Superbars: 4 Hours (n/a)";    break;
      case -PERIOD_D1    : description = "Superbars: Days (n/a)";       break;
      case -PERIOD_D1_ETH: description = "Superbars: Days + ETH (n/a)"; break;
      case -PERIOD_W1    : description = "Superbars: Weeks (n/a)";      break;
      case -PERIOD_MN1   : description = "Superbars: Months (n/a)";     break;
      case -PERIOD_Q1    : description = "Superbars: Quarters (n/a)";   break;

      case  INT_MIN:
      case  INT_MAX:       description = "Superbars: off";              break;   // manuell abgeschaltet

      default:             description = "Superbars: n/a";                       // automatisch abgeschaltet
   }
   //sRange = StringConcatenate(sRange, "   O: ", NumberToStr(Open[openBar], PriceFormat), "   H: ", NumberToStr(High[highBar], PriceFormat), "   L: ", NumberToStr(Low[lowBar], PriceFormat));
   string label    = __NAME__ +"."+ label.description;
   string fontName = "";
   int    fontSize = 8;                                              // "MS Sans Serif"/8 entspricht in allen Builds der Menüschrift
   ObjectSetText(label, description, fontSize, fontName, Black);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateDescription(1)", error));
   return(true);
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

      // (2) erst, wenn ein Command eingetroffen ist, Lock für Schreibzugriff holen
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
 * Erzeugt das Textlabel für die Superbars-Beschreibung.
 *
 * @return int - Fehlerstatus
 */
int CreateDescriptionLabel() {
   string label = __NAME__ +"."+ label.description;

   if (ObjectFind(label) == 0)
      ObjectDelete(label);

   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 183);                  // min. Distance für Platzierung neben One-Click-Trading-Widget ist 180
      ObjectSet    (label, OBJPROP_YDISTANCE, 4  );
      ObjectSetText(label, " ", 1);
      ObjectRegister(label);
   }

   return(catch("CreateDescriptionLabel(1)"));
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
      int hWnd    = WindowHandle(Symbol(), NULL);
      if (!hWnd) hWnd = __WND_HANDLE;
      if (!hWnd) return(!catch("StoreWindowStatus(1)->WindowHandle() = 0 in context "+ ModuleTypeDescription(__TYPE__) +"::"+ __whereamiDescription(__WHEREAMI__), ERR_RUNTIME_ERROR));
   string key     = "SuperBars.Timeframe.0x"+ IntToHexStr(hWnd);
   if (!WritePrivateProfileStringA(section, key, value, file)) return(!catch("StoreWindowStatus(2)->kernel32::WritePrivateProfileStringA(section=\""+ section +"\", key=\""+ key +"\", value=\""+ value +"\", fileName=\""+ file +"\")", ERR_WIN32_ERROR));

   return(catch("StoreWindowStatus(3)"));
}


/**
 * Restauriert die Fenster-relevanten Konfigurationsdaten aus dem Chart oder der Terminalkonfiguration.
 *
 *  - Superbar-Timeframe
 *
 * @return bool - Erfolgsstatus
 */
bool RestoreWindowStatus() {
   bool success = false;
   int  timeframe;

   // Versuchen, die Konfiguration aus dem Chart zu restaurieren (ist nach Laden eines neuen Templates nicht vorhanden).
   string label = __NAME__ +".sticky.timeframe", empty="";
   if (ObjectFind(label) == 0) {
      string sValue = ObjectDescription(label);
      success       = StringIsInteger(sValue);
      timeframe     = StrToInteger(sValue);
   }

   // Bei Mißerfolg Konfiguration aus der Terminalkonfiguration restaurieren.
   if (!success) {
      int hWnd = WindowHandle(Symbol(), NULL); if (!hWnd) hWnd = __WND_HANDLE;
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
