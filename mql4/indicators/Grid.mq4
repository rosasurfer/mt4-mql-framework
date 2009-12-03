
#include <stdlib.mqh>


#property indicator_chart_window



/**
 */
int init() {
   // DataBox-Anzeige aus
   SetIndexLabel(0, NULL);
   return(catch("init"));
}


/**
 */
int start() {
   double level = 1.6730;
   string name;

   for (int i=0; i < 4; i++) {
      level = level + 0.0050;
      name  = "xtrade.iGrid.hLine "+ DoubleToStr(level, 4);

      if (!ObjectCreate(name, OBJ_HLINE, 0, 0, level)) {
         int error = GetLastError();
         if (error != ERR_OBJECT_ALREADY_EXISTS) 
            return(catch("start, ObjectCreate", error));
         ObjectSet(name, OBJPROP_PRICE1, level);
      }
      ObjectSet(name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet(name, OBJPROP_COLOR, Blue     );
      ObjectSet(name, OBJPROP_WIDTH, 1        );
      ObjectSet(name, OBJPROP_BACK , true     );
   }

   return(catch("start"));
}


/**
 */
int deinit() {
   int count = ObjectsTotal();

   for (int i=count-1; i >= 0; i--) {
      string name = ObjectName(i);

      if (StringSubstr(name, 0, 11) == "xtrade.iGrid.")
         ObjectDelete(name);
   }

   return(catch("deinit"));
}

