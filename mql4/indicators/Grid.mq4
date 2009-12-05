
#include <stdlib.mqh>


#property indicator_chart_window


string labelBaseName = "Vertical Grid Line ";


// User-Variablen
extern color  GridColor      = LightGray;    // Grid-Farbe 
//extern int  GridBrightness = 5;            // Grid-Helligkeit


// interne Variablen
bool gridDrawn = false;                      // Zeichenstatus


// -------------------------------------------------------------------------------------------------------


/**
 */
int init() {
   // DataBox-Anzeige ausschalten
   SetIndexLabel(0, NULL);
   
   // Grid zeichnen (ist hier immer wahr)
   if (!gridDrawn)
      gridDrawn = drawGrid();

   return(catch("init"));
}


/**
 */
int start() {
   // Grid zeichnen, falls noch nicht geschehen (keine Verbindung etc.)
   if (!gridDrawn)
      gridDrawn = drawGrid();

   return(catch("start"));
}


/**
 */
int deinit() {
   int length = StringLen(labelBaseName);
   int count  = ObjectsTotal();
   string label;

   // TODO: Label der zu löschenden Objekte anderweitig speichern, Iteration durch ObjectsTotal() ist Zeitverschwendung
   for (int i=count-1; i >= 0; i--) {
      label = ObjectName(i);
      if (StringSubstr(label, 0, length) == labelBaseName) {
         ObjectDelete(label);
      }
   }

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
   int offset = BrokerGmtOffset();
   //Print("broker offset: "+ offset);

   // Session-Ende ist um 22:00 GMT, mit Hilfe des Broker-Offsets die Uhrzeit (Stunde) berechnen: 
   // Zeitpunkt = 22:00 GMT + BrokerOffset
   int iHour = (22 + offset + 24) % 24;
   string strHour = iHour +":00";
   if (iHour < 10)
      strHour = "0"+ strHour;
   //Print("broker session break: "+ strHour);
   
   // Zeitpunkte der ersten und letzten senkrechten Linie des Grids berechen
   datetime from = StrToTime(TimeToStr(Time[Bars-1], TIME_DATE) +" "+ strHour);
   datetime to   = StrToTime(TimeToStr(Time[     0], TIME_DATE) +" "+ strHour) + 1*DAY;
   Print("Grid from: "+ TimeToStr(from, TIME_DATE|TIME_MINUTES) +", to: "+ TimeToStr(to, TIME_DATE|TIME_MINUTES));

   string label;
   for (int time=from; time < to; time += 1*DAY) {
      // Im Label der Line steht die korrekte Session-Endezeit, vom Zeitparameter der Line selbst wird 1 Minute abgezogen,
      // damit sie unter der vorherigen Bar (letzte Bar der alten Session) erscheint (MetaTrader verwendet statt Close- Open-Zeiten).
      label = labelBaseName + TimeToStr(time, TIME_DATE|TIME_MINUTES);

      if (!ObjectCreate(label, OBJ_VLINE, 0, time - 1*MINUTE, 0)) {
         int error = GetLastError();
         if (error != ERR_OBJECT_ALREADY_EXISTS) 
            return(catch("init, ObjectCreate", error));
         ObjectSet(label, OBJPROP_TIME1, time);
      }
      ObjectSet(label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet(label, OBJPROP_COLOR, GridColor);
      ObjectSet(label, OBJPROP_BACK , true     );
   }

 
   /*
   // waagerechtes Grid
   double level = 1.6512;
   string label;

   for (int i=0; i < 4; i++) {
      level = level + 0.0050;
      label = indicatorName +".hLine "+ DoubleToStr(level, 4);

      if (!ObjectCreate(label, OBJ_HLINE, 0, 0, level)) {
         int error = GetLastError();
         if (error != ERR_OBJECT_ALREADY_EXISTS) 
            return(catch("init, ObjectCreate", error));
         ObjectSet(label, OBJPROP_PRICE1, level);
      }
      ObjectSet(label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet(label, OBJPROP_COLOR, Blue     );
      ObjectSet(label, OBJPROP_BACK , true     );
   }
   */
   catch("drawGrid");

   return(true);
}

