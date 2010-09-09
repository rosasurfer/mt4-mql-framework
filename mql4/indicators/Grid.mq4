/**
 * Chart-Grid
 *
 * Die vertikalen Separatoren sind auf der ersten tatsächlichen Bar der Session positioniert und tragen im Label das Datum der neuen Session.
 */

#include <stdlib.mqh>


#property indicator_chart_window


bool init       = false;
int  init_error = ERR_NO_ERROR;


//////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////

extern color Grid.Color = LightGray;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string labels[];     // Object-Labels


/**
 *
 */
int init() {
   init = true;
   init_error = ERR_NO_ERROR;

   // ERR_TERMINAL_NOT_YET_READY abfangen
   if (!GetAccountNumber()) {
      init_error = GetLastLibraryError();
      return(init_error);
   }

   // DataBox-Anzeige ausschalten
   SetIndexLabel(0, NULL);

   // nach Recompilation statische Arrays zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      ArrayResize(labels, 0);
   }

   // nach Parameteränderung sofort start() aufrufen und nicht auf den nächsten Tick warten
   if (UninitializeReason() == REASON_PARAMETERS) {
      start();
      WindowRedraw();
   }

   return(catch("init()"));
}


/**
 *
 */
int start() {
   int processedBars = IndicatorCounted();

   // Neuzeichnen übergreifend merken (falls ERR_HISTORY_WILL_UPDATED)
   static bool redraw = false;
   if (processedBars == 0) {                    redraw =  true; }
   else if (redraw)        { processedBars = 0; redraw = false; }

   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init) {                                      // Aufruf nach erstem init()
      init = false;
      if (init_error != ERR_NO_ERROR)               return(0);
   }
   else if (init_error != ERR_NO_ERROR) {           // Aufruf nach Tick
      if (init_error != ERR_TERMINAL_NOT_YET_READY) return(0);
      if (init()     != ERR_NO_ERROR)               return(0);
   }

   // TODO: Handler onAccountChanged() integrieren und alle Separatoren löschen.
   //HandleEvents(EVENT_POSITION_OPEN);


   // Grid zeichnen
   if (processedBars == 0) {
      redraw = (DrawGrid()==ERR_HISTORY_WILL_UPDATED);
   }

   return(catch("start()"));
}


/**
 *
 */
int deinit() {
   RemoveChartObjects(labels);
   return(catch("deinit()"));
}


/**
 * Zeichnet das Grid.
 *
 * @return int - Fehlerstatus
 */
int DrawGrid() {
   //int tick = GetTickCount();

   if (Bars == 0)
      return(0);

   if (GetServerTimezone() == "")
      return(ERR_RUNTIME_ERROR);

   datetime easternTime, easternFrom, easternTo, separatorTime, labelTime, chartTime, lastChartTime, currentServerTime = TimeCurrent();
   int      easternDow, bar, sColor, sStyle;
   string   label, lastLabel, day, dd, mm, yyyy;


   // Zeitpunkte des ersten und letzten Separators in New Yorker Zeit berechen
   easternFrom = GetEasternNextSessionStartTime(ServerToEasternTime(Time[Bars-1]) - 1*SECOND);
   easternTo   = GetEasternNextSessionStartTime(ServerToEasternTime(currentServerTime));
      if (Period()==PERIOD_H4) {                               // Wochenseparatoren
         easternDow = TimeDayOfWeek(easternTo);                // => easternTo ist der nächste Sonntag
         if (easternDow != SUNDAY) easternTo += (7-easternDow)*DAYS;
      }
      else if (Period()==PERIOD_D1 || Period() == PERIOD_W1) { // Monatsseparatoren
         int YYYY = TimeYear(easternTo);                       // => easternTo ist der 1. Handelstag des nächsten Monats
         int MM   = TimeMonth(easternTo);
         easternTo = GetEasternNextSessionStartTime(StrToTime(YYYY +"."+ (MM+1) +".01 00:00:00") - 8*HOURS);
      }
      else if (Period() == PERIOD_MN1) {                       // Quartalsseparatoren
      }                                                        // => easternTo ist der 1. Handelstag des nächsten Quartals
   //Print("DrawGrid()   Grid from: "+ GetDayOfWeek(easternFrom, false) +" "+ TimeToStr(easternFrom) +"     to: "+ GetDayOfWeek(easternTo, false) +" "+ TimeToStr(easternTo));


   // Separatoren zeichnen
   for (easternTime=easternFrom; easternTime <= easternTo; easternTime+=1*DAY) {
      // Wochenenden überspringen
      easternDow = TimeDayOfWeek(easternTime);
      if (easternDow == FRIDAY  ) continue;
      if (easternDow == SATURDAY) continue;

      // bei Perioden größer H1 nur den Wochenseparator zeichnen
      if (Period() > PERIOD_H1) if (easternDow != SUNDAY)   // TODO: Fehler, wenn Montag Feiertag ist
         continue;

      separatorTime = EasternToServerTime(easternTime);

      // Chart-Time des Separators ermitteln
      if (separatorTime > Time[0]) {                        // keine entsprechende Bar: ungeladene Daten oder aktuelle Session, die berechnete Zeit verwenden
         bar = -1;
         chartTime = separatorTime;
         // Wochenenden nach Bar 0 im Chart von Hand "kollabieren"
         if (easternDow == SUNDAY)                          // TODO: für alle Tage ohne Bars durchführen
            chartTime = EasternToServerTime(easternTime - 2*DAYS);
      }
      else {                                                // Separator liegt innerhalb der Bar-Range, die Zeit der ersten existierenden Session-Bar verwenden
         bar = iBarShiftNext(NULL, 0, separatorTime);
         if (bar == EMPTY_VALUE)
            return(GetLastLibraryError());
         chartTime = Time[bar];
      }

      // Label des Separators zusammenstellen (Datum des Handelstages)
      labelTime = easternTime + 7*HOURS;                    // 17:00 +7h = 00:00
      label = TimeToStr(labelTime);
         day  = GetDayOfWeek(labelTime, false);
         dd   = StringSubstr(label, 8, 2);
         mm   = StringSubstr(label, 5, 2);
         yyyy = StringSubstr(label, 0, 4);
      label = StringConcatenate(day, " ", dd, ".", mm, ".", yyyy);

      if (lastChartTime == chartTime)                       // mindestens eine Session fehlt, vermutlich wegen eines Feiertages
         ObjectDelete(lastLabel);                           // Separator für die fehlende Session wieder löschen

      // Separator zeichnen
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_VLINE, 0, chartTime, 0)) {
         if (easternDow == SUNDAY) { sColor = C'231,192,221'; sStyle = STYLE_DASHDOTDOT; }   // TODO: Fehler, wenn Montag Feiertag ist und fehlt
         else                      { sColor = Grid.Color;     sStyle = STYLE_DOT;        }
         ObjectSet(label, OBJPROP_STYLE, sStyle);
         ObjectSet(label, OBJPROP_COLOR, sColor);
         ObjectSet(label, OBJPROP_BACK , true  );
         RegisterChartObject(label, labels);
      }
      else GetLastError();

      lastLabel     = label;                     // letzte Separatordaten für Erkennung fehlender Sessions merken
      lastChartTime = chartTime;
   }

   //Print("DrawGrid()    execution time: ", GetTickCount()-tick, " ms");
   return(catch("DrawGrid()"));
}
