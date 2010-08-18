/**
 * Chart-Grid
 *
 * Die vertikalen Separatoren sind auf der letzten Bar der jeweiligen Session positioniert und tragen im Label das Datum
 * der neuen, beginnenden Session.
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

   // nach Chartänderung Flag für Neuzeichnen setzen
   static bool redraw = false;
   if (processedBars == 0)
      redraw = true;


   // init() nach Fehler ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init) {                                      // 1. Aufruf
      init = false;
      if (init_error != ERR_NO_ERROR)               return(0);
   }
   else if (init_error != ERR_NO_ERROR) {           // neuer Tick
      if (init_error != ERR_TERMINAL_NOT_YET_READY) return(0);
      if (init()     != ERR_NO_ERROR)               return(0);
   }


   // TODO: Handler onAccountChanged() integrieren und alle Separatoren löschen.

   if (redraw) {                    // Grid neu zeichnen
      redraw = false;
      DrawGrid();
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
   if (Bars == 0)
      return(0);

   // Stunde des Sessionwechsels ermitteln und Zeitpunkte des ersten und letzten Separators berechen
   int      hour = TimeHour(GetTradeServerSessionStart(TimeCurrent()));
   datetime from = StrToTime(StringConcatenate(TimeToStr(Time[Bars-1], TIME_DATE), " ", hour, ":00"));
   datetime to   = StrToTime(StringConcatenate(TimeToStr(Time[0],      TIME_DATE), " ", hour, ":00"));
   if (from <  Time[Bars-1]) from += 1*DAY;
   if (to   <= Time[0]     ) to   += 1*DAY;
   //Print("DrawGrid()   Grid from: "+ GetDayOfWeek(from, false) +" "+ TimeToStr(from) +"  to: "+ GetDayOfWeek(to, false) +" "+ TimeToStr(to));


   datetime time, eetSessionStart, chartTime, serverTime = TimeCurrent();
   string   day, dd, mm, yyyy, label, lastLabel;
   int      bar, lastBar;
   bool     weeklyDone;

   string timezone = GetTradeServerTimezone();
   int offset;
   if      (timezone == "EET" ) offset =  2;
   else if (timezone == "EEST") offset =  2;
   else if (timezone == "CET" ) offset =  1;
   else if (timezone == "CEST") offset =  1;
   else if (timezone == "GMT" ) offset =  0;
   else if (timezone == "BST" ) offset =  0;
   else if (timezone == "EST" ) offset = -5;
   else if (timezone == "EDT" ) offset = -5;
   //Print("DrawGrid()     timezone: "+ timezone +"      offset: "+ offset);

   // Separator zeichnen
   for (time=from; time <= to; time+=1*DAY) {
      eetSessionStart = time - offset*HOURS + 2*HOURS;   // EET = GMT+0200 = Datumsgrenze
      day = GetDayOfWeek(eetSessionStart, false);

      // Wochenenden überspringen
      if (day == "Sat") {
         time            += 2*DAY;
         eetSessionStart += 2*DAY;
         day              = "Mon";
      }

      // bei Perioden größer H1 nur den ersten Wochentag anzeigen (Wochenseparatoren)
      if (Period() > PERIOD_H1) if (day != "Mon")
         continue;                                       // TODO: Fehler, wenn Montag Feiertag ist

      // Label des Separators (Datum des Handelstages) zusammenstellen
      label = TimeToStr(eetSessionStart);
         dd   = StringSubstr(label, 8, 2);
         mm   = StringSubstr(label, 5, 2);
         yyyy = StringSubstr(label, 0, 4);
      label = StringConcatenate(day, " ", dd, ".", mm, ".", yyyy);

      if (time > serverTime) {               // aktuelle Session, Separator liegt in der Zukunft, die berechnete Zeit wird verwendet
         bar = -1;
         chartTime = time-1*MINUTE;
         if (day == "Mon")
            chartTime -= 2*DAY;
      }
      else {                                 // Separator liegt nicht in der Zukunft, die Zeit der letzten tatsächlichen Session-Bar wird verwendet
         bar = iBarShift(NULL, 0, time-1*MINUTE, false);
         chartTime = Time[bar];
      }

      if (lastBar == bar)                    // mindestens eine komplette Session fehlt, am wahrscheinlichsten wegen eines Feiertags
         ObjectDelete(lastLabel);            // Separator für die fehlende Session wieder löschen

      ObjectDelete(label); GetLastError();
      if (!ObjectCreate(label, OBJ_VLINE, 0, chartTime, 0))
         return(catch("DrawGrid(1)  ObjectCreate(label="+ label +")"));
      ObjectSet(label, OBJPROP_STYLE, STYLE_DOT );
      ObjectSet(label, OBJPROP_COLOR, Grid.Color);
      ObjectSet(label, OBJPROP_BACK , true      );

      RegisterChartObject(label, labels);

      lastLabel = label;                     // letzte Separatordaten für Feiertagserkenung merken
      lastBar   = bar;
   }

   return(catch("DrawGrid(2)"));
}