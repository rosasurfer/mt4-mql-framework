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
 * Zeichnet das Grid.
 *
 * @return int - Fehlerstatus
 */
int DrawGrid() {
   if (Bars == 0)
      return(0);

   int tick   = GetTickCount();

   if (GetServerTimezone() == "")
      return(ERR_RUNTIME_ERROR);

   datetime easternTime, easternFrom, easternTo, serverTime, labelTime, chartTime, currentServerTime = TimeCurrent();
   int      bar, lastBar, sColor, sStyle;
   string   label, lastLabel, day, dd, mm, yyyy;

   // Zeitpunkte des ersten und letzten Separators in New Yorker Zeit berechen
   easternFrom = GetEasternSessionStartTime(ServerToEasternTime(Time[Bars-1]));
      if (EasternToServerTime(easternFrom) < Time[Bars-1])
         easternFrom += 1*DAY;
   easternTo   = GetEasternSessionStartTime(ServerToEasternTime(Time[0])) + 1*DAY;
   //Print("DrawGrid()   Grid from: "+ TimeToStr(easternFrom) +"     to: "+ TimeToStr(easternTo));


   // Separatoren zeichnen
   for (easternTime=easternFrom; easternTime <= easternTo; easternTime+=1*DAY) {
      // bei Perioden größer H1 nur den ersten Wochentag anzeigen (Wochenseparatoren)
      if (Period() > PERIOD_H1) if (TimeDayOfWeek(easternTime) != SUNDAY)
         continue;                                                         // TODO: Fehler, wenn Montag Feiertag ist

      serverTime = EasternToServerTime(easternTime);

      // Label des Separators zusammenstellen (Datum des Handelstages)
      labelTime  = easternTime + 7*HOURS;
      if (TimeDayOfWeek(labelTime) == SATURDAY)    // Wochenenden überspringen
         labelTime += 2*DAYS;
      label = TimeToStr(labelTime);
         day  = GetDayOfWeek(labelTime, false);
         dd   = StringSubstr(label, 8, 2);
         mm   = StringSubstr(label, 5, 2);
         yyyy = StringSubstr(label, 0, 4);
      label = StringConcatenate(day, " ", dd, ".", mm, ".", yyyy);

      // Chart-Time des Separators ermitteln
      if (serverTime > currentServerTime) {  // aktuelle Session, Separator liegt in der Zukunft, die berechnete Zeit wird verwendet
         bar = -1;
         chartTime = serverTime;
      }
      else {                                 // Separator liegt nicht in der Zukunft, die Zeit der ersten existierenden Session-Bar wird verwendet
         bar = iBarShiftNext(NULL, 0, serverTime);
         chartTime = Time[bar];
      }

      if (lastBar == bar)                    // eine Session fehlt, am wahrscheinlichsten wegen eines Feiertags
         ObjectDelete(lastLabel);            // Separator für die fehlende Session wieder löschen
      
      // Separator zeichnen
      ObjectDelete(label); GetLastError();
      if (!ObjectCreate(label, OBJ_VLINE, 0, chartTime, 0))
         return(catch("DrawGrid(1)  ObjectCreate(label="+ label +")"));
         if (day == "Mon") { sColor = C'231,192,221'; sStyle = STYLE_DASHDOTDOT; }
         else              { sColor = Grid.Color;     sStyle = STYLE_DOT;        }
      ObjectSet(label, OBJPROP_STYLE, sStyle);
      ObjectSet(label, OBJPROP_COLOR, sColor);
      ObjectSet(label, OBJPROP_BACK , true  );
      RegisterChartObject(label, labels);

      lastLabel = label;                     // letzte Separatordaten für Erkennung fehlender Sessions merken
      lastBar   = bar;
   }
   
   //Print("DrawGrid()    execution time: ", GetTickCount()-tick, " ms");

   return(catch("DrawGrid(2)"));
}


/**
 *
 */
int deinit() {
   RemoveChartObjects(labels);
   return(catch("deinit()"));
}

