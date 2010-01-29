/**
 * Chart-Grid
 */

#include <stdlib.mqh>


#property indicator_chart_window


// User Variablen ////////////////////////////////////////////////

extern color Grid.Color = LightGray;   // Grid-Farbe

//////////////////////////////////////////////////////////////////


string chartObjects[];  // Label der Chartobjekte


/**
 *
 */
int init() {
   // DataBox-Anzeige ausschalten
   SetIndexLabel(0, NULL);

   // während der Entwicklung Arrays jedesmal zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      ArrayResize(chartObjects, 0);
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
   RemoveChartObjects(chartObjects);
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
   int hour = (22 + GetBrokerGmtOffset() + 24) % 24;   // offset: -23 bis +23
   Print("broker offset: ", GetBrokerGmtOffset(), " h    session ends: ", hour, ":00 broker time");


   // Zeitpunkte des ersten und letzten Separators berechen
   datetime from = StrToTime(StringConcatenate(TimeToStr(Time[Bars-1], TIME_DATE), " ", hour, ":00"));
   datetime to   = StrToTime(StringConcatenate(TimeToStr(Time[0],      TIME_DATE), " ", hour, ":00"));
   if (from <  Time[Bars-1]) from = from + 1*DAY;
   if (to   <= Time[0]     ) to   = to   + 1*DAY;
   //Print("Grid from: "+ TimeToStr(from, TIME_DATE|TIME_MINUTES) +", to: "+ TimeToStr(to, TIME_DATE|TIME_MINUTES));


   string label, day, dd, mm, yyyy;

   // Separator zeichnen
   for (int time=from; time <= to; time += 1*DAY) {
      label = TimeToStr(time + 2*HOURS, TIME_DATE|TIME_MINUTES);  // im Label steht der neue Handelstag: Sessionende (22:00 GMT) + 2 h = 00:00 GMT)
         day  = GetDayOfWeek(time + 2*HOURS, false);              // Kurzform des Wochentags
         dd   = StringSubstr(label, 8, 2);
         mm   = StringSubstr(label, 5, 2);
         yyyy = StringSubstr(label, 0, 4);
      label = StringConcatenate(day, " ", dd, ".", mm, ".", yyyy);

      // Wochenenden in der Vergangenheit überspringen
      if (time < Time[0]) {
         if (day=="Sat") continue;  // für MQL optimiert
         if (day=="Sun") continue;
      }

      // TODO: Separators von Feiertagen werden in den vorherigen Tag gezeichnet
      if (!ObjectCreate(label, OBJ_VLINE, 0, time, 0)) {
         int error = GetLastError();
         if (error != ERR_OBJECT_ALREADY_EXISTS)
            return(catch("DrawGrid(1)  ObjectCreate(label="+ label +")", error));
         ObjectSet(label, OBJPROP_TIME1, time);
      }
      ObjectSet(label, OBJPROP_STYLE, STYLE_DOT );
      ObjectSet(label, OBJPROP_COLOR, Grid.Color);
      ObjectSet(label, OBJPROP_BACK , true      );
      RegisterChartObject(label, chartObjects);
   }

   return(catch("DrawGrid(2)"));
}