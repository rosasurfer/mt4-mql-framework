/**
 * Chart-Grid
 */

#include <stdlib.mqh>


#property indicator_chart_window


////////////////////////////////////////////////////////// User Variablen /////////////////////////////////////////////////////////

extern color Grid.Color = LightGray;               // Grid-Farbe

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string labels[];     // Object-Labels


/**
 *
 */
int init() {
   // DataBox-Anzeige ausschalten
   SetIndexLabel(0, NULL);

   // während der Entwicklung Arrays jedesmal zurücksetzen
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

   if (processedBars == 0)    // erster Aufruf oder nach Data-Pumping: alles neu zeichnen
      DrawGrid();

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


   // Stunde des Session-Endes beim Broker berechnen (22:00 GMT + Broker-Offset)
   int offset = GetTradeServerGMTOffset();            // -23 bis +23
   int hour   = (22 + offset + 24) % 24;
   //Print("broker offset: ", GetTradeServerGMTOffset(), " h    session ends: ", hour, ":00 broker time");


   // Zeitpunkte des ersten und letzten Separators berechen
   datetime from = StrToTime(StringConcatenate(TimeToStr(Time[Bars-1], TIME_DATE), " ", hour, ":00"));
   datetime to   = StrToTime(StringConcatenate(TimeToStr(Time[0],      TIME_DATE), " ", hour, ":00"));
   if (from <  Time[Bars-1]) from += 1*DAY;
   if (to   <= Time[0]     ) to   += 1*DAY;
   //Print("Grid from: "+ GetDayOfWeek(from, false) +" "+ TimeToStr(from) +"  to: "+ GetDayOfWeek(to, false) +" "+ TimeToStr(to));


   string day, dd, mm, yyyy, label, lastLabel;
   int bar, lastBar;
   int time, chartTime;

   // Separator zeichnen
   for (time=from; time <= to; time+=1*DAY) {
      day = GetDayOfWeek(time - offset*HOURS + 2*HOURS, false);

      // TODO: Labels mit Sa+So in der Zukunft auf nächsten Wochentag shiften

      // Wochenenden überspringen
      if (day=="Sat") continue;  // conditions für MQL optimiert
      if (day=="Sun") continue;

      // Tagesseparatoren bei Perioden größer H1 überspringen (nur Wochenseparatoren)
      if (Period() > PERIOD_H1) if (day != "Mon")
         continue;

      // Label des Separators (Datum des Handelstages) zusammenstellen (Servertime - Offset + 2 h = 00:00)
      label = TimeToStr(time - offset*HOURS + 2*HOURS);
         dd   = StringSubstr(label, 8, 2);
         mm   = StringSubstr(label, 5, 2);
         yyyy = StringSubstr(label, 0, 4);
      label = StringConcatenate(day, " ", dd, ".", mm, ".", yyyy);

      // Existiert zum Zeitpunkt time keine Bar, zeichnet MetaTrader den Separator fälschlicherweise in die vorhergehende Session.
      // Daher muß für den time-Parameter des Separators der Zeitpunkt der ersten tatsächlichen Bar der betreffenden Session ermittelt werden.
      bar = iBarShiftNext(NULL, 0, time);
      if (bar == -1) {                 // Separator liegt in der Zukunft, die berechnete Zeit wird verwendet
         chartTime = time;
      }
      else {
         if (lastBar == bar)           // mindestens eine komplette Session fehlt, am wahrscheinlichsten wegen eines Feiertags
            ObjectDelete(lastLabel);   // Separator für die fehlende Session wieder löschen
         chartTime = Time[bar];        // Separator liegt nicht in der Zukunft, die Zeit der ersten tatsächlichen Session-Bar wird verwendet
      }

      ObjectDelete(label); GetLastError();
      if (!ObjectCreate(label, OBJ_VLINE, 0, chartTime, 0))
         return(catch("DrawGrid(1)  ObjectCreate(label="+ label +")"));
      ObjectSet(label, OBJPROP_STYLE, STYLE_DOT );
      ObjectSet(label, OBJPROP_COLOR, Grid.Color);
      ObjectSet(label, OBJPROP_BACK , true      );

      RegisterChartObject(label, labels);

      lastLabel = label;   // letzte Separatordaten für Feiertagserkenung merken
      lastBar   = bar;
   }

   return(catch("DrawGrid(2)"));
}