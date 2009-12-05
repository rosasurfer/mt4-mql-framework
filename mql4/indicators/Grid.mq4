
#include <stdlib.mqh>


#property indicator_chart_window


string labelBase = "Vertical Grid Line ";


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

   return(0);
   return(catch("start"));
}


/**
 */
int deinit() {
   int length = StringLen(labelBase);

   // TODO: Label der zu löschenden Objekte anderweitig speichern, Iteration durch ObjectsTotal() ist Zeitverschwendung
   int count = ObjectsTotal();

   for (int i=count-1; i >= 0; i--) {
      string label = ObjectName(i);
      if (StringSubstr(label, 0, length) == labelBase) {
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

   // vertikales Grid zeichnen
   // ------------------------
   // Von den berechneten Zeitpunkten wird 1 Minute abgezogen, damit das Grid wirklich unter der jeweils letzten Bar 
   // der Session gezeichnet wird (nach MetaTrader-Philosophie werden statt Close- überall Open-Zeiten verwendet).

   // Time-Offset des Brokers bestimmen
   int offset = BrokerGmtOffset();
   Print("broker offset: "+ offset);

   datetime from = StrToTime(TimeToStr(Time[Bars-1], TIME_DATE) +" 23:00") - 1*MINUTE;
   datetime to   = StrToTime(TimeToStr(Time[     0], TIME_DATE) +" 23:00") - 1*MINUTE + 1*DAY;
   //Print("from: "+ TimeToStr(from, TIME_DATE|TIME_MINUTES) +", to: "+ TimeToStr(to, TIME_DATE|TIME_MINUTES));

   string label;
   for (int time=from; time < to; time += 1*DAY) {
      // Im Label des Grids erscheint die korrekte Zeit des Session-Endes
      label = labelBase + TimeToStr(time + 1*MINUTE, TIME_DATE|TIME_MINUTES);

      if (!ObjectCreate(label, OBJ_VLINE, 0, time, 0)) {
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

