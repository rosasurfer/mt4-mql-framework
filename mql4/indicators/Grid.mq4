/**
 * Chart grid
 *
 * Die vertikalen Separatoren sind auf der ersten Bar der Session positioniert und tragen im Label das Datum der begonnenen
 * Session.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern color Color.RegularGrid = Gainsboro;                          // C'220,220,220'
extern color Color.SuperGrid   = LightGray;                          // C'211,211,211'

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/iBarShiftNext.mqh>

#property indicator_chart_window


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   SetIndexLabel(0, NULL);
   return(catch("onInit(1)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   DeleteRegisteredObjects();
   return(catch("onDeinit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!UnchangedBars)
      DrawGrid();
   return(last_error);
}


/**
 * Zeichnet das Grid.
 *
 * @return bool - success status
 */
int DrawGrid() {
   datetime firstWeekDay, separatorTime, chartTime, lastChartTime;
   int      dow, dd, mm, yyyy, bar, sepColor, sepStyle;
   string   label, lastLabel;


   // (1) Zeitpunkte des ältesten und jüngsten Separators berechen
   datetime time    = ServerToFxtTime(Time[Bars-1]);                if (time    == NaT) return(false);
   datetime fromFXT = GetNextSessionStartTime.fxt(time - 1*SECOND); if (fromFXT == NaT) return(false);
   datetime now.fxt = TimeFXT();                                    if (!now.fxt)       return(false); // nicht TimeCurrent() verwenden, kann 0 sein
   datetime toFXT   = GetNextSessionStartTime.fxt(now.fxt);         if (toFXT   == NaT) return(false);

   // Tagesseparatoren
   if (Period() < PERIOD_H4) {                                                // fromFXT bleibt unverändert
      toFXT += (8-TimeDayOfWeekEx(toFXT))%7 * DAYS;                           // toFXT ist der nächste Montag (die restliche Woche wird komplett dargestellt)
   }

   // Wochenseparatoren
   else if (Period() == PERIOD_H4) {
      fromFXT += (8-TimeDayOfWeekEx(fromFXT))%7 * DAYS;                       // fromFXT ist der erste Montag
      toFXT   += (8-TimeDayOfWeekEx(toFXT))%7 * DAYS;                         // toFXT ist der nächste Montag
   }

   // Monatsseparatoren
   else if (Period() == PERIOD_D1) {
      yyyy = TimeYearFix(fromFXT);                                            // fromFXT ist der erste Wochentag des ersten vollen Monats
      mm   = TimeMonth(fromFXT);
      firstWeekDay = GetFirstWeekdayOfMonth(yyyy, mm);

      if (firstWeekDay < fromFXT) {
         if (mm == 12) { yyyy++; mm = 0; }
         firstWeekDay = GetFirstWeekdayOfMonth(yyyy, mm+1);
      }
      fromFXT = firstWeekDay;
      // ------------------------------------------------------
      yyyy = TimeYearFix(toFXT);                                              // toFXT ist der erste Wochentag des nächsten Monats
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
      yyyy = TimeYearFix(fromFXT);                                            // fromFXT ist der erste Wochentag des ersten vollen Jahres
      firstWeekDay = GetFirstWeekdayOfMonth(yyyy, 1);
      if (firstWeekDay < fromFXT)
         firstWeekDay = GetFirstWeekdayOfMonth(yyyy+1, 1);
      fromFXT = firstWeekDay;
      // ------------------------------------------------------
      yyyy = TimeYearFix(toFXT);                                              // toFXT ist der erste Wochentag des nächsten Jahres
      firstWeekDay = GetFirstWeekdayOfMonth(yyyy, 1);
      if (firstWeekDay < toFXT)
         firstWeekDay = GetFirstWeekdayOfMonth(yyyy+1, 1);
      toFXT = firstWeekDay;
   }
   //debug("DrawGrid()  from \""+ GmtTimeFormat(fromFXT, "%a, %d.%m.%Y %H:%M") +"\" to \""+ GmtTimeFormat(fromFXT, "%a, %d.%m.%Y %H:%M") +"\"");


   // (2) Separatoren zeichnen
   for (time=fromFXT; time <= toFXT; time+=1*DAY) {
      separatorTime = FxtToServerTime(time);                                  // ERR_INVALID_TIMEZONE_CONFIG wird in onInit() abgefangen
      dow           = TimeDayOfWeekEx(time);

      // Bar und Chart-Time des Separators ermitteln
      if (Time[0] < separatorTime) {                                          // keine entsprechende Bar: aktuelle Session oder noch laufendes ERS_HISTORY_UPDATE
         bar = -1;
         chartTime = separatorTime;                                           // ursprüngliche Zeit verwenden
         if (dow == MONDAY)
            chartTime -= 2*DAYS;                                              // bei zukünftigen Separatoren Wochenenden von Hand "kollabieren" TODO: Bug bei Periode > H4
      }
      else {                                                                  // Separator liegt innerhalb der Bar-Range, Zeit der ersten existierenden Bar verwenden
         bar = iBarShiftNext(NULL, NULL, separatorTime);
         if (bar == EMPTY_VALUE) return(false);
         chartTime = Time[bar];
      }

      // Label des Separators zusammenstellen (ie. "Fri 23.12.2011")
      label = TimeToStr(time);
      label = StringConcatenate(GmtTimeFormat(time, "%a"), " ", StringSubstr(label, 8, 2), ".", StringSubstr(label, 5, 2), ".", StringSubstr(label, 0, 4));

      if (lastChartTime == chartTime)                                         // Bars der vorherigen Periode fehlen (noch laufendes ERS_HISTORY_UPDATE oder Kurslücke)
         ObjectDelete(lastLabel);                                             // Separator für die fehlende Periode wieder löschen

      // Separator zeichnen
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_VLINE, 0, chartTime, 0)) {
         sepStyle = STYLE_DOT;
         sepColor = Color.RegularGrid;
         if (Period() < PERIOD_H4) {
            if (dow == MONDAY) {
               sepStyle = STYLE_DASHDOTDOT;
               sepColor = Color.SuperGrid;
            }
         }
         else if (Period() == PERIOD_H4) {
            sepStyle = STYLE_DASHDOTDOT;
            sepColor = Color.SuperGrid;
         }
         ObjectSet(label, OBJPROP_STYLE, sepStyle);
         ObjectSet(label, OBJPROP_COLOR, sepColor);
         ObjectSet(label, OBJPROP_BACK , true  );
         ObjectRegister(label);
      }
      else GetLastError();
      lastChartTime = chartTime;
      lastLabel     = label;                                                  // Daten des letzten Separators für Lückenerkennung merken


      // (2.1) je nach Periode einen Tag *vor* den nächsten Separator springen
      // Tagesseparatoren
      if (Period() < PERIOD_H4) {
         if (dow == FRIDAY)                                                   // Wochenenden überspringen
            time += 2*DAYS;
      }
      // Wochenseparatoren
      else if (Period() == PERIOD_H4) {
         time += 6*DAYS;                                                      // TimeDayOfWeek(time) == MONDAY
      }
      // Monatsseparatoren
      else if (Period() == PERIOD_D1) {                                       // erster Wochentag des Monats
         yyyy = TimeYearFix(time);
         mm   = TimeMonth(time);
         if (mm == 12) { yyyy++; mm = 0; }
         time = GetFirstWeekdayOfMonth(yyyy, mm+1) - 1*DAY;
      }
      // Jahresseparatoren
      else if (Period() > PERIOD_D1) {                                        // erster Wochentag des Jahres
         yyyy = TimeYearFix(time);
         time = GetFirstWeekdayOfMonth(yyyy+1, 1) - 1*DAY;
      }
   }
   return(!catch("DrawGrid(2)"));
}


/**
 * Ermittelt den ersten Wochentag eines Monats.
 *
 * @param  int year  - Jahr (1970 bis 2037)
 * @param  int month - Monat
 *
 * @return datetime - erster Wochentag des Monats oder -1 (EMPTY), falls ein Fehler auftrat
 */
datetime GetFirstWeekdayOfMonth(int year, int month) {
   if (year  < 1970 || 2037 < year ) return(_EMPTY(catch("GetFirstWeekdayOfMonth(1)  illegal parameter year = "+ year +" (not between 1970 and 2037)", ERR_INVALID_PARAMETER)));
   if (month <    1 ||   12 < month) return(_EMPTY(catch("GetFirstWeekdayOfMonth(2)  invalid parameter month = "+ month, ERR_INVALID_PARAMETER)));

   datetime firstDayOfMonth = StrToTime(StringConcatenate(year, ".", StrRight("0"+month, 2), ".01 00:00:00"));

   int dow = TimeDayOfWeekEx(firstDayOfMonth);
   if (dow == SATURDAY) return(firstDayOfMonth + 2*DAYS);
   if (dow == SUNDAY  ) return(firstDayOfMonth + 1*DAY );

   return(firstDayOfMonth);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Color.RegularGrid=", ColorToStr(Color.RegularGrid), ";", NL,
                            "Color.SuperGrid=",   ColorToStr(Color.SuperGrid),   ";")
   );
}
