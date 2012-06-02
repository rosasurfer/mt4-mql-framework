/**
 * Chart-Grid. Die vertikalen Separatoren sind auf der ersten Bar der Session positioniert und tragen im Label das Datum der begonnenen Session.
 */
#include <types.mqh>
#define     __TYPE__      T_INDICATOR
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>


#property indicator_chart_window


////////////////////////////////////////////////////////////// Externe Konfiguration //////////////////////////////////////////////////////////////

extern color Grid.Color = LightGray;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);

   // nach Recompilation statische Arrays zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE)
      ArrayResize(objects, 0);

   // nach Parameteränderung nicht auf den nächsten Tick warten (nur im "Indicators List" window notwendig)
   if (UninitializeReason() == REASON_PARAMETERS)
      Chart.SendTick(false);

   return(catch("onInit()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   RemoveChartObjects(objects);
   return(catch("onDeinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (prev_error == ERR_HISTORY_UPDATE) {
      ValidBars   = 0;
      ChangedBars = Bars - ValidBars;
   }

   // TODO: Handler onAccountChanged() integrieren und alle Separatoren löschen.

   // Grid zeichnen
   if (ValidBars == 0)
      DrawGrid();

   return(catch("onTick()"));
}


/**
 * Zeichnet das Grid (ERR_INVALID_TIMEZONE_CONFIG wird in onInit() abgefangen).
 *
 * @return int - Fehlerstatus
 */
int DrawGrid() {
   datetime firstWeekDay, separatorTime, chartTime, lastChartTime;
   int      dow, dd, mm, yyyy, bar, sepColor, sepStyle;
   string   label, lastLabel;


   // (1) Zeitpunkte des ältesten und jüngsten Separators berechen
   datetime fromFXT = GetFXTNextSessionStartTime(ServerToFXT(Time[Bars-1]) - 1*SECOND);
   datetime toFXT   = GetFXTNextSessionStartTime(ServerToFXT(TimeCurrent()));

   // Tagesseparatoren
   if (Period() < PERIOD_H4) {                                       // fromFXT bleibt unverändert
      toFXT += (8-TimeDayOfWeek(toFXT))%7 * DAYS;                    // toFXT ist der nächste Montag (die restliche Woche wird komplett dargestellt)
   }

   // Wochenseparatoren
   else if (Period() == PERIOD_H4) {
      fromFXT += (8-TimeDayOfWeek(fromFXT))%7 * DAYS;                // fromFXT ist der erste Montag
      toFXT   += (8-TimeDayOfWeek(toFXT))%7 * DAYS;                  // toFXT ist der nächste Montag
   }

   // Monatsseparatoren
   else if (Period() == PERIOD_D1) {
      yyyy = TimeYear(fromFXT);                                      // fromFXT ist der erste Wochentag des ersten vollen Monats
      mm   = TimeMonth(fromFXT);
      firstWeekDay = GetFirstWeekdayOfMonth(yyyy, mm);

      if (firstWeekDay < fromFXT) {
         if (mm == 12) { yyyy++; mm = 0; }
         firstWeekDay = GetFirstWeekdayOfMonth(yyyy, mm+1);
      }
      fromFXT = firstWeekDay;
      // ------------------------------------------------------
      yyyy = TimeYear(toFXT);                                        // toFXT ist der erste Wochentag des nächsten Monats
      mm   = TimeMonth(toFXT);
      firstWeekDay = GetFirstWeekdayOfMonth(yyyy, mm);

      if (firstWeekDay < toFXT) {
         if (mm == 12) { yyyy++; mm = 0; }
         firstWeekDay = GetFirstWeekdayOfMonth(yyyy, mm+1);
      }
      toFXT = firstWeekDay;
   }

   // Jahresseparatoren
   else if (Period() > PERIOD_D1) {
      yyyy = TimeYear(fromFXT);                                      // fromFXT ist der erste Wochentag des ersten vollen Jahres
      firstWeekDay = GetFirstWeekdayOfMonth(yyyy, 1);
      if (firstWeekDay < fromFXT)
         firstWeekDay = GetFirstWeekdayOfMonth(yyyy+1, 1);
      fromFXT = firstWeekDay;
      // ------------------------------------------------------
      yyyy = TimeYear(toFXT);                                        // toFXT ist der erste Wochentag des nächsten Jahres
      firstWeekDay = GetFirstWeekdayOfMonth(yyyy, 1);
      if (firstWeekDay < toFXT)
         firstWeekDay = GetFirstWeekdayOfMonth(yyyy+1, 1);
      toFXT = firstWeekDay;
   }
   //debug("DrawGrid()   from \""+ GetDayOfWeek(fromFXT, false) +" "+ TimeToStr(fromFXT) +"\" to \""+ GetDayOfWeek(toFXT, false) +" "+ TimeToStr(toFXT) +"\"");


   // (2) Separatoren zeichnen
   for (datetime time=fromFXT; time <= toFXT; time+=1*DAY) {
      separatorTime = FXTToServerTime(time);                         // ERR_INVALID_TIMEZONE_CONFIG wird in onInit() abgefangen
      dow           = TimeDayOfWeek(time);

      // Bar und Chart-Time des Separators ermitteln
      if (Time[0] < separatorTime) {                                 // keine entsprechende Bar: aktuelle Session oder noch laufendes ERR_HISTORY_UPDATE
         bar = -1;
         chartTime = separatorTime;                                  // ursprüngliche Zeit verwenden
         if (dow == MONDAY)
            chartTime -= 2*DAYS;                                     // bei zukünftigen Separatoren Wochenenden von Hand "kollabieren" TODO: Bug bei Periode > H4
      }
      else {                                                         // Separator liegt innerhalb der Bar-Range, Zeit der ersten existierenden Bar verwenden
         bar = iBarShiftNext(NULL, 0, separatorTime);                // ERR_HISTORY_UPDATE ???
         if (bar == EMPTY_VALUE) {
            if (SetLastError(stdlib_PeekLastError()) != ERR_HISTORY_UPDATE)
               catch("DrawGrid(1)", last_error);
            return(last_error);
         }
         chartTime = Time[bar];
      }

      // Label des Separators zusammenstellen (ie. "Fri 23.12.2011")
      label = TimeToStr(time);
      label = StringConcatenate(GetDayOfWeek(time, false), " ", StringSubstr(label, 8, 2), ".", StringSubstr(label, 5, 2), ".", StringSubstr(label, 0, 4));

      if (lastChartTime == chartTime)                                // Bars der vorherigen Periode fehlen (noch laufendes ERR_HISTORY_UPDATE oder Kurslücke)
         ObjectDelete(lastLabel);                                    // Separator für die fehlende Periode wieder löschen

      // Separator zeichnen
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_VLINE, 0, chartTime, 0)) {
         sepStyle = STYLE_DOT;
         sepColor = Grid.Color;
         if (Period() < PERIOD_H4) {
            if (dow == MONDAY) {
               sepStyle = STYLE_DASHDOTDOT;
               sepColor = C'231,192,221';
            }
         }
         else if (Period() == PERIOD_H4) {
            sepStyle = STYLE_DASHDOTDOT;
            sepColor = C'231,192,221';
         }
         ObjectSet(label, OBJPROP_STYLE, sepStyle);
         ObjectSet(label, OBJPROP_COLOR, sepColor);
         ObjectSet(label, OBJPROP_BACK , true  );
         ArrayPushString(objects, label);
      }
      else GetLastError();
      lastChartTime = chartTime;
      lastLabel     = label;                                         // Daten des letzten Separators für Lückenerkennung merken


      // (2.1) je nach Periode einen Tag *vor* den nächsten Separator springen
      // Tagesseparatoren
      if (Period() < PERIOD_H4) {
         if (dow == FRIDAY)                                          // Wochenenden überspringen
            time += 2*DAYS;
      }
      // Wochenseparatoren
      else if (Period() == PERIOD_H4) {
         time += 6*DAYS;                                             // TimeDayOfWeek(time) == MONDAY
      }
      // Monatsseparatoren
      else if (Period() == PERIOD_D1) {                              // erster Wochentag des Monats
         yyyy = TimeYear(time);
         mm   = TimeMonth(time);
         if (mm == 12) { yyyy++; mm = 0; }
         time = GetFirstWeekdayOfMonth(yyyy, mm+1) - 1*DAY;
      }
      // Jahresseparatoren
      else if (Period() > PERIOD_D1) {                               // erster Wochentag des Jahres
         yyyy = TimeYear(time);
         time = GetFirstWeekdayOfMonth(yyyy+1, 1) - 1*DAY;
      }
   }
   return(catch("DrawGrid(2)"));
}


/**
 * Ermittelt den ersten Wochentag eines Monats.
 *
 * @param  int year  - Jahr (1970 bis 2037)
 * @param  int month - Monat
 *
 * @return datetime - erster Wochentag des Monats oder -1, falls ein Fehler auftrat
 */
datetime GetFirstWeekdayOfMonth(int year, int month) {
   if (1970 > year || year > 2037) {
      catch("GetFirstWeekdayOfMonth(1)  invalid parameter year: "+ year +" (not between 1970 and 2037)", ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   if (1 > month || month > 12) {
      catch("GetFirstWeekdayOfMonth(2)  invalid parameter month: "+ month, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   datetime result = StrToTime(StringConcatenate(year, ".", month, ".01 00:00:00"));

   int dow = TimeDayOfWeek(result);
   if      (dow == SATURDAY) result += 2*DAYS;
   else if (dow == SUNDAY  ) result += 1*DAY;

   return(result);
}
