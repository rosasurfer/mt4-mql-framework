/**
 * Zeigt einen Schriftzug in unterschiedlichen Größen und Schriften an.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/indicator.mqh>

#property indicator_chart_window

string text            = "jagt im komplett verwahrl. Taxi 1234,567.80 | ";
color  backgroundColor = C'212,208,200';
color  fontColor       = Blue;
string fontNames[]     = { "(empty)", "System", "Arial", "Arial Kursiv", "Arial Fett", "Arial Black", "Comic Sans MS", "Comic Sans MS Fett", "Franklin Gothic Medium", "Lucida Console", "Lucida Sans", "Microsoft Sans Serif", "MS Sans Serif", "Tahoma", "Tahoma Fett", "Trebuchet MS", "Trebuchet MS Fett", "Verdana", "Verdana Fett", "Vrinda", "Courier", "Courier New", "Courier New Fett", "MS Serif" };


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);

   CreateLabels();
   return(catch("onInit()"));
}


/**
 *
 */
int CreateLabels() {
   int fontSize_from = 8;
   int fontSize_to   = 14;

   int names = ArraySize(fontNames);
   int c = 100;

   for (int fontSize=fontSize_from; fontSize < fontSize_to; fontSize++) {
      // Backgrounds
      c++;
      string label = StringConcatenate(__NAME__, ".", c, ".Background");
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet    (label, OBJPROP_XDISTANCE, (fontSize-fontSize_from)*450 + 14);
         ObjectSet    (label, OBJPROP_YDISTANCE, 90);
         ObjectSetText(label, "g", 390, "Webdings", backgroundColor);
         ObjectRegister(label);
      }
      else GetLastError();

      // Textlabel
      int yCoord = 100;
      for (int i=0; i < names; i++) {
         c++;
         label = StringConcatenate(__NAME__, ".", c, ".", fontNames[i]);
         if (ObjectFind(label) == 0)
            ObjectDelete(label);
         if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
            ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
            ObjectSet    (label, OBJPROP_XDISTANCE, (fontSize-fontSize_from)*450 + 20);
            ObjectSet    (label, OBJPROP_YDISTANCE, i*17 + yCoord);
            ObjectSetText(label, StringConcatenate(text, fontNames[i], ifString(!i, " size: "+ fontSize, "")), fontSize, fontNames[i], fontColor);
            ObjectRegister(label);
         }
         else GetLastError();
      }
   }

   return(catch("CreateLabels()"));
}
