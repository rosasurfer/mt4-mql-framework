
#include <stdlib.mqh>


#property indicator_chart_window


// User-Variablen
extern color Grid.Color      = LightGray;    // Grid-Farbe
extern int   Grid.Brightness = 5;            // Grid-Helligkeit


string chartObjects[];     // Label der Chartobjekte


/**
 *
 */
int init() {
   // DataBox-Anzeige ausschalten
   SetIndexLabel(0, NULL);

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

   // Stunde des Session-Endes des Brokers berechnen (22:00 GMT + Broker-Offset)
   int iHour  = (22 + GetBrokerGmtOffset() + 24) % 24;   // offset: -23 bis +23
   string strHour = StringConcatenate(iHour, ":00");
   if (iHour < 10)
      strHour = StringConcatenate("0", strHour);
   //Print("broker offset: ", GetBrokerGmtOffset(), " h    broker session break: ", strHour);

   
   // Zeitpunkte des ersten und letzten Separators berechen
   datetime from = StrToTime(StringConcatenate(TimeToStr(Time[Bars-1], TIME_DATE), " ", strHour));
   datetime to   = StrToTime(StringConcatenate(TimeToStr(Time[0],      TIME_DATE), " ", strHour));
   if (from <  Time[Bars-1]) from = from + 1*DAY;
   if (to   <= Time[0]     ) to   = to   + 1*DAY;
   //Print("Grid from: "+ TimeToStr(from, TIME_DATE|TIME_MINUTES) +", to: "+ TimeToStr(to, TIME_DATE|TIME_MINUTES));


   string label, day, dd, mm, yyyy;
   
   // Separator zeichnen
   for (int time=from; time <= to; time += 1*DAY) {
      // TODO: die Separators fehlender Tage (Feiertage innerhalb der Woche) werden in den vorherigen Tag gezeichnet
   
      label = TimeToStr(time + 2*HOURS, TIME_DATE|TIME_MINUTES);  // im Label steht der neue Handelstag: Sessionende (22:00 GMT) + 2 h = 00:00 GMT)
         day  = GetDayOfWeek(time + 2*HOURS, false);              // Kurzform des Wochentags
         dd   = StringSubstr(label, 8, 2);
         mm   = StringSubstr(label, 5, 2);
         yyyy = StringSubstr(label, 0, 4);
      label = StringConcatenate(day, " ", dd, ".", mm, ".", yyyy);

      if (time > D'2010.01.13 12:00' && time < D'2010.01.18 12:00') {
         Print("draw separator \'"+ label +"\' at "+ GetDayOfWeek(time, false) +" "+ TimeToStr(time));
      }

      // Wochenenden überspringen
      if (day!="Sat" && day!="Sun") {
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
   }

   return(catch("DrawGrid(2)"));
}