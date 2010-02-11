/**
 * Chart-Grid
 */

#include <stdlib.mqh>


#property indicator_chart_window


////////////////////////////////////////////////////////// User Variablen /////////////////////////////////////////////////////////

extern color Grid.Color = LightGray;               // Grid-Farbe

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string labels[];     // Separatorlabels


/**
 *
 */
int init() {
   // DataBox-Anzeige ausschalten
   SetIndexLabel(0, NULL);

   // während der Entwicklung Arrays jedesmal zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      ArrayResize(labels,  0);
   }

   // nach Parameteränderung start() aufrufen (statt auf den nächsten Tick zu warten)
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

   if (processedBars == 0)    // 1. Aufruf oder nach Data-Pumping: alles neu zeichnen
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
   int offset = GetServerGMTOffset();                 // -23 bis +23
   int hour   = (22 + offset + 24) % 24;
   //Print("broker offset: ", GetServerGMTOffset(), " h    session ends: ", hour, ":00 broker time");


   // Zeitpunkte des ersten und letzten Separators berechen
   datetime from = StrToTime(StringConcatenate(TimeToStr(Time[Bars-1], TIME_DATE), " ", hour, ":00"));
   datetime to   = StrToTime(StringConcatenate(TimeToStr(Time[0],      TIME_DATE), " ", hour, ":00"));
   if (from <  Time[Bars-1]) from += 1*DAY;
   if (to   <= Time[0]     ) to   += 1*DAY;
   //Print("Grid from: "+ TimeToStr(from, TIME_DATE|TIME_MINUTES) +", to: "+ TimeToStr(to, TIME_DATE|TIME_MINUTES));


   string label, day, dd, mm, yyyy;

   // Separator zeichnen
   for (int time=from; time <= to; time+=1*DAY) {
      day = GetDayOfWeek(time - offset*HOURS + 2*HOURS, false);

      // Wochenenden in der Vergangenheit überspringen
      if (time < Time[0]) {
         if (day=="Sat") continue;  // für MQL optimiert
         if (day=="Sun") continue;
      }
      
      // Tagesseparatoren bei Perioden größer H1 überspringen (nur Wochenseparatoren)
      if (Period() > PERIOD_H1) if (day != "Mon")
         continue;

      // Label des Separators (Datum des Handelstages) zusammenstellen (Servertime - Offset + 2 h = 00:00)
      label = TimeToStr(time - offset*HOURS + 2*HOURS, TIME_DATE|TIME_MINUTES);
         dd   = StringSubstr(label, 8, 2);
         mm   = StringSubstr(label, 5, 2);
         yyyy = StringSubstr(label, 0, 4);
      label = StringConcatenate(day, " ", dd, ".", mm, ".", yyyy);

      // TODO: Separators von Feiertagen werden in den vorherigen Tag gezeichnet
      // TODO: Sa+So in Labels auf nächsten Wochentag shiften
      if (!ObjectCreate(label, OBJ_VLINE, 0, time, 0)) {
         int error = GetLastError();
         if (error != ERR_OBJECT_ALREADY_EXISTS)
            return(catch("DrawGrid(1)  ObjectCreate(label="+ label +")", error));
         ObjectSet(label, OBJPROP_TIME1, time);
      }
      ObjectSet(label, OBJPROP_STYLE, STYLE_DOT );
      ObjectSet(label, OBJPROP_COLOR, Grid.Color);
      ObjectSet(label, OBJPROP_BACK , true      );
      
      RegisterChartObject(label, labels);
   }

   return(catch("DrawGrid(2)"));
}