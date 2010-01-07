
#include <stdlib.mqh>


#property indicator_chart_window


// User-Variablen
extern color Grid.Color      = LightGray;    // Grid-Farbe
extern int   Grid.Brightness = 5;            // Grid-Helligkeit


// interne Variablen
bool   gridDrawn = false;  // Zeichenstatus
string chartObjects[];     // Label der Chartobjekte


/**
 *
 */
int init() {
   // DataBox-Anzeige ausschalten
   SetIndexLabel(0, NULL);

   // Grid zeichnen
   gridDrawn = drawGrid();

   return(catch("init"));
}


/**
 *
 */
int start() {
   // (falls noch nicht geschehen) Grid zeichnen
   if (!gridDrawn)
      gridDrawn = drawGrid();

   return(catch("start"));
}


/**
 *
 */
int deinit() {
   RemoveChartObjects(chartObjects);
   return(catch("deinit"));
}


/**
 * Zeichnet das Grid.
 *
 * @return bool - Erfolgsstatus
 */
bool drawGrid() {
   if (gridDrawn)
      return(true);

   if (Bars == 0)
      return(false);

   // vertikales Grid
   // ---------------
   // GMT-Offset des Brokers ermitteln (mögliche Werte: -23 bis +23)
   int offset = GetBrokerGmtOffset();
   //Print("broker offset: "+ offset);

   // Session-Ende ist um 22:00 GMT, mit Hilfe des Broker-Offsets die Uhrzeit (Stunde) berechnen:
   // Zeitpunkt = 22:00 GMT + BrokerOffset
   int    iHour   = (22 + offset + 24) % 24;
   string strHour = StringConcatenate(iHour, ":00");
   if (iHour < 10)
      strHour = StringConcatenate("0", strHour);
   //Print("broker session break: "+ strHour);

   // Zeitpunkte der ersten und letzten senkrechten Linie des Grids berechen
   datetime from = StrToTime(StringConcatenate(TimeToStr(Time[Bars-1], TIME_DATE), " ", strHour));
   datetime to   = StrToTime(StringConcatenate(TimeToStr(Time[     0], TIME_DATE), " ", strHour));
   if (from <  Time[Bars-1]) from = from + 1*DAY;
   if (to   <= Time[0     ]) to   = to   + 1*DAY;
   //Print("Grid from: "+ TimeToStr(from, TIME_DATE|TIME_MINUTES) +", to: "+ TimeToStr(to, TIME_DATE|TIME_MINUTES));

   string label;

   for (int time=from; time <= to; time += 1*DAY) {
      // Im Label der Line steht die korrekte Session-Endezeit, vom Zeitparameter der Line selbst wird jedoch 1 Minute abgezogen,
      // damit sie unter der vorherigen Bar (letzte Bar der alten Session) erscheint (MetaTrader verwendet statt Close- Open-Zeiten).
      label = TimeToStr(time, TIME_DATE|TIME_MINUTES);

      if (!ObjectCreate(label, OBJ_VLINE, 0, time - 1*MINUTE, 0)) {
         int error = GetLastError();
         if (error != ERR_OBJECT_ALREADY_EXISTS)
            return(catch("drawGrid, ObjectCreate", error));
         ObjectSet(label, OBJPROP_TIME1, time);
      }
      ObjectSet(label, OBJPROP_STYLE, STYLE_DOT );
      ObjectSet(label, OBJPROP_COLOR, Grid.Color);
      ObjectSet(label, OBJPROP_BACK , true      );
      RegisterChartObject(label, chartObjects);
   }

   /*
   // waagerechtes Grid
   // -----------------
   double level = 1.6512;
   string label;

   for (int i=0; i < 4; i++) {
      level = level + 0.0050;
      label = indicatorName +".hLine "+ DoubleToStr(level, 4);

      if (!ObjectCreate(label, OBJ_HLINE, 0, 0, level)) {
         int error = GetLastError();
         if (error != ERR_OBJECT_ALREADY_EXISTS)
            return(catch("drawGrid, ObjectCreate", error));
         ObjectSet(label, OBJPROP_PRICE1, level);
      }
      ObjectSet(label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet(label, OBJPROP_COLOR, Blue);
      ObjectSet(label, OBJPROP_BACK , true);
      RegisterChartObject(label, chartObjects);
   }
   */

   catch("drawGrid");
   return(true);
}
