/**
 * Zeigt im Chart verschiedene Informationen an:
 *
 * - oben links:     der Name des Instruments
 * - oben rechts:    der aktuelle Kurs (average price)
 * - unter dem Kurs: der Spread, wenn 'Show.Spread' TRUE ist
 * - unten Mitte:    die Größe einer Handels-Unit
 * - unten Mitte:    die im Moment gehaltene Position
 */
// - unten rechts:   die normalisierte Handelsperformance der letzten Wochen

#include <stdlib.mqh>


#property indicator_chart_window


bool init       = false;
int  init_error = ERR_NO_ERROR;


////////////////////////////////////////////////////////////////// User Variablen ////////////////////////////////////////////////////////////////

extern bool Show.Spread                 = false;      // ob der Spread angezeigt wird (default: ja)
extern bool Spread.Including.Commission = false;      // ob der Spread inklusive einer evt. Kommission angezeigt werden soll

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string instrumentLabel, priceLabel, spreadLabel, equityLabel, unitSizeLabel, positionLabel, performanceLabel;
string labels[];

bool Show.UnitSize           = false;
bool Show.Position           = false;
bool Show.PerformanceDisplay = false;


/**
 *
 */
int init() {
   init = true;
   init_error = ERR_NO_ERROR;


   //double number = 123.456789;
   //Print("init()   number="+ number + "    formatted=\""+ FormatNumber(number, "2.3") +"\"");


   // ERR_TERMINAL_NOT_YET_READY abfangen
   if (!GetAccountNumber()) {
      init_error = GetLastLibraryError();
      return(init_error);
   }

   // DataBox-Anzeige ausschalten
   SetIndexLabel(0, NULL);

   // Label initialisieren
   instrumentLabel  = StringConcatenate(WindowExpertName(), ".Instrument" );
   priceLabel       = StringConcatenate(WindowExpertName(), ".Price"      );
   spreadLabel      = StringConcatenate(WindowExpertName(), ".Spread"     );
   equityLabel      = StringConcatenate(WindowExpertName(), ".Equity"     );
   unitSizeLabel    = StringConcatenate(WindowExpertName(), ".UnitSize"   );
   positionLabel    = StringConcatenate(WindowExpertName(), ".Position"   );
   performanceLabel = StringConcatenate(WindowExpertName(), ".Performance");

   // TODO: UnitSize und Position bei Indizes, Aktien etc. ausblenden
   Show.UnitSize = true;
   Show.Position = true;
   Show.Spread   = true;

   CreateInstrumentLabel();
   CreatePriceLabel();
   CreateSpreadLabel();
   CreateUnitSizeLabel();
   CreatePositionLabel();
   CreatePerformanceDisplay();

   // nach Parameteränderung sofort start() aufrufen und nicht auf den nächsten Tick warten
   if (UninitializeReason() == REASON_PARAMETERS) {
      start();
      WindowRedraw();
   }

   return(catch("init()"));

   FormatNumber(1, "");
}


/**
 * Formats a number using a mask, and returns the resulting string.
 * The basic mask is "n" or "n.d" where n is the number of digits to the left and d is the number of digits to the right of the decimal point.
 *
 * Mask parameters:
 *
 *   n      = number of digits to the left of the decimal point, e.g. FormatNumber(123.456, "5") => "123"
 *   n.d    = number of digits to the left and the right of the decimal point, e.g. FormatNumber(123.456, "5.2") => "123.45"
 *   n.     = number of left and all right digits, e.g. FormatNumber(123.456, "2.") => "23.456"
 *    .d    = all left and number of right digits, e.g. FormatNumber(123.456, ".2") => "123.45"
 *    .d+   = + anywhere right of .d in mask: all left and minimum number of right digits, e.g. FormatNumber(123.456, ".2+") => "123.456"
 *  +n.d    = + anywhere left of n. in mask: plus sign for positive values
 * ( or )   = enclose negative values in parentheses
 *    %     = trailing % sign
 *    ‰     = trailing ‰ sign
 *    R     = round result in the last displayed digit, e.g. FormatNumber(123.456, "R3.2") => "123.46", e.g. FormatNumber(123.7, "R3") => "124"
 *    ,     = separate thousands by comma, e.g. FormatNumber(123456.789, ",6.3") => "123,456.789"
 *    ;     = switch thousands and decimal point separator (European format), e.g. FormatNumber(123456.789, ",;6.3") => "123.456,789"
 */
string FormatNumber(double number, string mask) {
   if (number == EMPTY_VALUE)
      number = 0;

   // === Beginn Maske parsen ===
   mask = StringReplace(mask, " ", "");
   int len = StringLen(mask);

   // Position des Dezimalpunktes
   int  dotPos   = StringFind(mask, ".");
   bool dotGiven = (dotPos > -1);
   if (!dotGiven)
      dotPos = len;

   // Anzahl der linken Stellen
   int char, nLeft;
   bool nDigit;
   for (int i=0; i < dotPos; i++) {
      char = StringGetChar(mask, i);
      if ('0' <= char) if (char <= '9') {    // (0 <= char && char <= 9)
         nLeft = 10*nLeft + char-'0';
         nDigit = true;
      }
   }
   if (!nDigit) nLeft = StringLen(StringConcatenate("", EMPTY_VALUE));

   // Anzahl der rechten Stellen
   int nRight;
   if (dotGiven) {
      nDigit = false;
      for (i=dotPos+1; i < len; i++) {
         char = StringGetChar(mask, i);
         if ('0' <= char) if (char <= '9') { // (0 <= char && char <= 9)
            nRight = 10*nRight + char-'0';
            nDigit = true;
         }
      }
      if (nDigit) {
         nRight = MathMin(nRight, 8);
      }
      else {
         string tmp = number;
         dotPos = StringFind(tmp, ".");
         for (i=StringLen(tmp)-1; i > dotPos; i--) {
            if (StringGetChar(tmp, i) != '0')
               break;
         }
         nRight = i - dotPos;
      }
      if (nRight == 0)
         dotGiven = false;
   }

   // Vorzeichen etc.
   string leadSign="", trailSign="";
   if (number < 0) {
      if (StringFind(mask, "(") > -1 || StringFind(mask, ")") > -1) {
         leadSign = "("; trailSign = ")";
      }
      else leadSign = "-";
   }
   else if (number > 0) if (StringFind(mask, "+") > -1) {
      leadSign = "+";
   }

   // Prozent- oder Promillezeichen
   if      (StringFind(mask, "%") > -1) trailSign = StringConcatenate("%", trailSign);
   else if (StringFind(mask, "‰") > -1) trailSign = StringConcatenate("‰", trailSign);

   // übrige Modifier
   bool round          = (StringFind(mask, "R")  > -1);
   bool separators     = (StringFind(mask, ",")  > -1);
   bool swapSeparators = (StringFind(mask, ";")  > -1);
   //
   // === Ende Maske parsen ===


   // === Beginn Wertverarbeitung ===
   // runden
   if (round)
      number = MathRoundFix(number, nRight);
   string outStr = number;

   // negatives Vorzeichen entfernen (ist in leadSign gespeichert)
   if (number < 0)
      outStr = StringSubstr(outStr, 1);

   // auf angegebene Länge kürzen
   int dLeft    = StringFind(outStr, ".");
   int dVisible = MathMin(nLeft, dLeft);
   outStr = StringSubstrFix(outStr, StringLen(outStr)-9-dVisible, dVisible+1+nRight-(!dotGiven));

   // Dezimal-Separator tauschen
   if (swapSeparators)
      outStr = StringSetChar(outStr, dVisible, ',');

   // 1000er-Separatoren einfügen
   if (separators) {
      if (swapSeparators) string separator = ".";
      else                       separator = ",";
      string out1;
      i = dVisible;
      while (i > 3) {
         out1 = StringSubstrFix(outStr, 0, i-3);
         if (StringGetChar(out1, i-4) == ' ')
            break;
         outStr = StringConcatenate(out1, separator, StringSubstr(outStr, i-3));
         i -= 3;
      }
   }

   // Vorzeichen etc. anfügen
   outStr = StringConcatenate(leadSign, outStr, trailSign);
   //
   // === Ende Wertverarbeitung ===

   Print("FormatNumber(double="+ DoubleToStr(number, 8) +", mask="+ mask +")    nLeft="+ nLeft +"    dLeft="+ dLeft +"    nRight="+ nRight +"    outStr=\""+ outStr +"\"");

   int error = GetLastError();
   if (error != ERR_NO_ERROR) {
      catch("FormatNumber()", error);
      return("");
   }
   return(outStr);
}


/**
 *
 */
int start() {
   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init) {                                      // Aufruf nach erstem init()
      init = false;
      if (init_error != ERR_NO_ERROR)               return(0);
   }
   else if (init_error != ERR_NO_ERROR) {           // Aufruf nach Tick
      if (init_error != ERR_TERMINAL_NOT_YET_READY) return(0);
      if (init()     != ERR_NO_ERROR)               return(0);
   }

   UpdatePriceLabel();
   UpdateSpreadLabel();
   UpdateUnitSizeLabel();
   UpdatePositionLabel();
   UpdatePerformanceDisplay();
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
 * Erzeugt das Instrument-Label.
 */
int CreateInstrumentLabel() {
   if (ObjectFind(instrumentLabel) > -1)
      ObjectDelete(instrumentLabel);
   if (ObjectCreate(instrumentLabel, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(instrumentLabel, OBJPROP_CORNER   , CORNER_TOP_LEFT);
      ObjectSet(instrumentLabel, OBJPROP_XDISTANCE, 4);
      ObjectSet(instrumentLabel, OBJPROP_YDISTANCE, 1);
      RegisterChartObject(instrumentLabel, labels);
   }
   else GetLastError();

   // Instrumentnamen einlesen und setzen
   string instrument = GetGlobalConfigString("Instruments", Symbol(), Symbol());
   string name       = GetGlobalConfigString("Instrument.Names", instrument, instrument);
   ObjectSetText(instrumentLabel, name, 9, "Tahoma Fett", Black);

   return(catch("CreateInstrumentLabel()"));
}


/**
 * Erzeugt das Kurslabel.
 */
int CreatePriceLabel() {
   if (ObjectFind(priceLabel) > -1)
      ObjectDelete(priceLabel);
   if (ObjectCreate(priceLabel, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(priceLabel, OBJPROP_CORNER   , CORNER_TOP_RIGHT);
      ObjectSet(priceLabel, OBJPROP_XDISTANCE, 11);
      ObjectSet(priceLabel, OBJPROP_YDISTANCE,  9);
      ObjectSetText(priceLabel, " ", 1);
      RegisterChartObject(priceLabel, labels);
   }
   else GetLastError();

   return(catch("CreatePriceLabel()"));
}


/**
 * Erzeugt das Spreadlabel.
 */
int CreateSpreadLabel() {
   if (!Show.Spread)
      return(0);

   if (ObjectFind(spreadLabel) > -1)
      ObjectDelete(spreadLabel);
   if (ObjectCreate(spreadLabel, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(spreadLabel, OBJPROP_CORNER   , CORNER_TOP_RIGHT);
      ObjectSet(spreadLabel, OBJPROP_XDISTANCE, 30);
      ObjectSet(spreadLabel, OBJPROP_YDISTANCE, 32);
      ObjectSetText(spreadLabel, " ", 1);
      RegisterChartObject(spreadLabel, labels);
   }
   else GetLastError();

   return(catch("CreateSpreadLabel()"));
}


/**
 * Erzeugt das UnitSize-Label.
 */
int CreateUnitSizeLabel() {
   if (!Show.UnitSize)
      return(0);

   if (ObjectFind(unitSizeLabel) > -1)
      ObjectDelete(unitSizeLabel);
   if (ObjectCreate(unitSizeLabel, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(unitSizeLabel, OBJPROP_CORNER   , CORNER_BOTTOM_LEFT);
      ObjectSet(unitSizeLabel, OBJPROP_XDISTANCE, 290);
      ObjectSet(unitSizeLabel, OBJPROP_YDISTANCE,  11);
      ObjectSetText(unitSizeLabel, " ", 1);
      RegisterChartObject(unitSizeLabel, labels);
   }
   else GetLastError();

   return(catch("CreateUnitSizeLabel()"));
}


/**
 * Erzeugt das Positionlabel.
 */
int CreatePositionLabel() {
   if (!Show.Position)
      return(0);

   if (ObjectFind(positionLabel) > -1)
      ObjectDelete(positionLabel);
   if (ObjectCreate(positionLabel, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(positionLabel, OBJPROP_CORNER   , CORNER_BOTTOM_LEFT);
      ObjectSet(positionLabel, OBJPROP_XDISTANCE, 530);
      ObjectSet(positionLabel, OBJPROP_YDISTANCE,  11);
      ObjectSetText(positionLabel, " ", 1);
      RegisterChartObject(positionLabel, labels);
   }
   else GetLastError();

   return(catch("CreatePositionLabel()"));
}


/**
 * Erzeugt das Performance-Display.
 */
int CreatePerformanceDisplay() {
   if (!Show.PerformanceDisplay)
      return(0);

   int xCoord = 250;
   int yCoord = 150;

   color backgroundColor  = C'212,208,200';  // DarkKhaki | Lavender | 213,208,159
   color frameBrightColor = White;           // SlateGray | 90,104,116
   color frameDarkColor   = C'128,128,128';  // SlateGray | 90,104,116
   color frameDarkerColor = C'64,64,64';     // SlateGray | 90,104,116
   color fontColor        = Black;           // SlateGray | 90,104,116

   string label;
   int lc;

   // 1. Anfasser (groß, fängt den Maus-Fokus)
   lc++;
   label = StringConcatenate(WindowExpertName(), ".Graphic_0", lc);
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xCoord-3);
      ObjectSet(label, OBJPROP_YDISTANCE, yCoord-7);
      ObjectSetText(label, "y", 20, "Wingdings 3", frameDarkerColor);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   // Background
   int xOffsets[4];
   xOffsets[0] = xCoord + 0*53;
   xOffsets[1] = xCoord + 1*53;
   xOffsets[2] = xCoord + 2*53;
   xOffsets[3] = xCoord + 3*53;

   for (int i=0; i < ArraySize(xOffsets); i++) {
      lc++;
      label = StringConcatenate(WindowExpertName(), ".Graphic_a", lc);
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[i]);
         ObjectSet(label, OBJPROP_YDISTANCE, yCoord);
         ObjectSetText(label, "g", 40, "Webdings", backgroundColor);
         RegisterChartObject(label, labels);
      }
      else GetLastError();
   }

   // Rahmen links
   int yOffsets[2];
   yOffsets[0] = yCoord;
   yOffsets[1] = yCoord+22;

   for (i=0; i < ArraySize(yOffsets); i++) {
      lc++;
      label = StringConcatenate(WindowExpertName(), ".Graphic_b", lc);
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[3]+40);
         ObjectSet(label, OBJPROP_YDISTANCE, yOffsets[i]-1);
         ObjectSetText(label, "|", 17, "Webdings", frameBrightColor);
         RegisterChartObject(label, labels);
      }
      else GetLastError();
   }
      lc++;
      label = StringConcatenate(WindowExpertName(), ".Graphic_b", lc);
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[3]+40);
         ObjectSet(label, OBJPROP_YDISTANCE, yCoord+28);
         ObjectSetText(label, "|", 17, "Webdings", frameBrightColor);
         RegisterChartObject(label, labels);
      }
      else GetLastError();

   // Rahmen oben
   lc++;
   label = StringConcatenate(WindowExpertName(), ".Graphic_b", lc);
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]);
      ObjectSet(label, OBJPROP_YDISTANCE, yCoord+51);
      ObjectSetText(label, "_________", 27, "Courier New", frameBrightColor);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   lc++;
   label = StringConcatenate(WindowExpertName(), ".Graphic_b", lc);
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[3]+30);
      ObjectSet(label, OBJPROP_YDISTANCE, yCoord+51);
      ObjectSetText(label, "_", 27, "Courier New", frameBrightColor);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   // Rahmen rechts
   for (i=0; i < ArraySize(yOffsets); i++) {
      lc++;
      label = StringConcatenate(WindowExpertName(), ".Graphic_c", lc);
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]-11);
         ObjectSet(label, OBJPROP_YDISTANCE, yOffsets[i]-2);
         ObjectSetText(label, "|", 17, "Webdings", frameDarkColor);
         RegisterChartObject(label, labels);
      }
      else GetLastError();
   }
      lc++;
      label = StringConcatenate(WindowExpertName(), ".Graphic_c", lc);
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]-11);
         ObjectSet(label, OBJPROP_YDISTANCE, yCoord+28);
         ObjectSetText(label, "|", 17, "Webdings", frameDarkColor);
         RegisterChartObject(label, labels);
      }
      else GetLastError();

   for (i=0; i < ArraySize(yOffsets); i++) {
      lc++;
      label = StringConcatenate(WindowExpertName(), ".Graphic_c", lc);
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]-12);
         ObjectSet(label, OBJPROP_YDISTANCE, yOffsets[i]-3);
         ObjectSetText(label, "|", 17, "Webdings", frameDarkerColor);
         RegisterChartObject(label, labels);
      }
      else GetLastError();
   }
      lc++;
      label = StringConcatenate(WindowExpertName(), ".Graphic_c", lc);
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]-12);
         ObjectSet(label, OBJPROP_YDISTANCE, yCoord+29);
         ObjectSetText(label, "|", 17, "Webdings", frameDarkerColor);
         RegisterChartObject(label, labels);
      }
      else GetLastError();

   // Rahmen unten
   lc++;
   label = StringConcatenate(WindowExpertName(), ".Graphic_d", lc);
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]);
      ObjectSet(label, OBJPROP_YDISTANCE, yCoord);
      ObjectSetText(label, "_________", 27, "Courier New", frameDarkColor);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   lc++;
   label = StringConcatenate(WindowExpertName(), ".Graphic_d", lc);
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[3]+30);
      ObjectSet(label, OBJPROP_YDISTANCE, yCoord);
      ObjectSetText(label, "_", 27, "Courier New", frameDarkColor);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   lc++;
   label = StringConcatenate(WindowExpertName(), ".Graphic_d", lc);
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]);
      ObjectSet(label, OBJPROP_YDISTANCE, yCoord-1);
      ObjectSetText(label, "_________", 27, "Courier New", frameDarkerColor);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   lc++;
   label = StringConcatenate(WindowExpertName(), ".Graphic_d", lc);
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[3]+31);
      ObjectSet(label, OBJPROP_YDISTANCE, yCoord-1);
      ObjectSetText(label, "_", 27, "Courier New", frameDarkerColor);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   // Text
   lc++;
   label = StringConcatenate(WindowExpertName(), ".Graphic_e", lc);
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]+11);
      ObjectSet(label, OBJPROP_YDISTANCE, yOffsets[1]-3);
      ObjectSetText(label, "-100     +23     +41     -90     +35", 9, "Tahoma", fontColor);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   /*
   // 2. Anfasser (klein, zur Visualisierung)
   lc++;
   label = StringConcatenate(indicatorName, ".Graphic_x", lc);
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xCoord-2);
      ObjectSet(label, OBJPROP_YDISTANCE, yCoord-3);
      ObjectSetText(label, "y", 9, "Wingdings 3", frameDarkerColor);
      RegisterChartObject(label, objects);
   }
   else GetLastError();
   */

   return(catch("CreatePerformanceDisplay()"));
}


/**
 * Aktualisiert das Kurslabel.
 */
int UpdatePriceLabel() {
   double price = (Bid + Ask) / 2;
   string major="", minor="", strPrice = DoubleToStr(price, Digits);

   // Kurs ggf. formatieren
   if (MathFloor(price) > 999 || Digits==3 || Digits==5) {
      // Nachkommastellen formatieren
      if (Digits > 0) {
         int pos = StringFind(strPrice, ".");
         major = StringSubstrFix(strPrice, 0, pos);
         minor = StringSubstr(strPrice, pos+1);
         if      (Digits == 3) minor = StringConcatenate(StringSubstr(minor, 0, 2), "\'", StringSubstr(minor, 2));
         else if (Digits == 5) minor = StringConcatenate(StringSubstr(minor, 0, 4), "\'", StringSubstr(minor, 4));
      }
      else {
         major = strPrice;
      }

      // Vorkommastellen formatieren
      int len = StringLen(major);
      if (len > 3)
         major = StringConcatenate(StringSubstrFix(major, 0, len-3), ",", StringSubstr(major, len-3));

      // Vor- und Nachkommastellen zu Gesamtwert zusammensetzen
      if (Digits > 0) strPrice = StringConcatenate(major, ".", minor);
      else            strPrice = major;
   }

   ObjectSetText(priceLabel, strPrice, 13, "Microsoft Sans Serif", Black);

   int error = GetLastError();
   if (error == ERR_NO_ERROR             ) return(ERR_NO_ERROR);
   if (error == ERR_OBJECT_DOES_NOT_EXIST) return(ERR_NO_ERROR);  // bei offenem Properties-Dialog oder Label::onDrag()
   return(catch("UpdatePriceLabel()", error));
}


/**
 * Aktualisiert das Spreadlabel.
 */
int UpdateSpreadLabel() {
   if (!Show.Spread)
      return(0);

   int spread = MarketInfo(Symbol(), MODE_SPREAD);

   if (Spread.Including.Commission) if (AccountNumber() == {account-no})
      spread += 8;

   if (Digits==3 || Digits==5) string strSpread = DoubleToStr(spread/10.0, 1);
   else                               strSpread = spread;

   ObjectSetText(spreadLabel, strSpread, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (error == ERR_NO_ERROR             ) return(ERR_NO_ERROR);
   if (error == ERR_OBJECT_DOES_NOT_EXIST) return(ERR_NO_ERROR);  // bei offenem Properties-Dialog oder Label::onDrag()
   return(catch("UpdateSpreadLabel()", error));
}


/**
 * Aktualisiert das UnitSize-Label.
 */
int UpdateUnitSizeLabel() {
   if (!Show.UnitSize)
      return(0);

   string strUnitSize = StringConcatenate("UnitSize:  ", DoubleToStrTrim(GetCurrentUnitSize()), " Lot");

   ObjectSetText(unitSizeLabel, strUnitSize, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (error == ERR_NO_ERROR             ) return(ERR_NO_ERROR);
   if (error == ERR_OBJECT_DOES_NOT_EXIST) return(ERR_NO_ERROR);  // bei offenem Properties-Dialog oder Label::onDrag()
   return(catch("UpdateUnitSizeLabel()", error));
}


/**
 * Aktualisiert das Position-Label.
 */
int UpdatePositionLabel() {
   if (!Show.Position)
      return(0);

   double position = GetCurrentPosition();
   string strPosition = "";

   if      (position < 0) strPosition = StringConcatenate("Position:  " , DoubleToStrTrim(position), " Lot");
   else if (position > 0) strPosition = StringConcatenate("Position:  +", DoubleToStrTrim(position), " Lot");

   ObjectSetText(positionLabel, strPosition, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (error == ERR_NO_ERROR             ) return(ERR_NO_ERROR);
   if (error == ERR_OBJECT_DOES_NOT_EXIST) return(ERR_NO_ERROR);  // bei offenem Properties-Dialog oder Label::onDrag()
   return(catch("UpdatePositionLabel()", error));
}


/**
 * Aktualisiert das Performance-Display.
 */
int UpdatePerformanceDisplay() {
   if (!Show.PerformanceDisplay)
      return(0);

   return(catch("UpdatePerformanceDisplay()"));
}


/**
 * Gibt die momentane Unit-Größe des aktuellen Instruments zurück.
 *
 * @return double - Größe einer Handels-Unit in Lot
 */
double GetCurrentUnitSize() {
   // TODO: Verwendung von Bid ist Unfug, funktioniert nur mit dem aktuellen Symbol

   if (Bid == 0)     // ohne Connection würde Division durch 0 ausgelöst
      return(0);

   double unitSize = (AccountEquity()-AccountCredit()) / 1000 * 0.07;   // 7% der Equity

   if (StringSubstr(Symbol(), 0, 3) != "USD")
      unitSize /= Bid;

   if      (unitSize < 0.9) unitSize = NormalizeDouble(unitSize, 2);
   else if (unitSize <   9) unitSize = NormalizeDouble(unitSize, 1);
   else                     unitSize = NormalizeDouble(unitSize, 0);

   catch("GetCurrentUnitSize()");
   return(unitSize);
}


/**
 * Gibt die momentan im aktuellen Instrument gehaltene Position zurück.
 *
 * @return double - Größe der gehaltenen Position in Lot
 */
double GetCurrentPosition() {
   int    type;
   double position = 0.0;

   // über offene Orders iterieren
   for (int i=0; i < OrdersTotal(); i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         return(catch("GetCurrentPosition(1), OrderSelect(pos="+ i +")"));

      // nur offene Orders des angegebenen Instruments berücksichtigen
      if (Symbol() == OrderSymbol()) {
         type = OrderType();
         if      (type == OP_BUY ) position += OrderLots();
         else if (type == OP_SELL) position -= OrderLots();
      }
   }

   catch("GetCurrentPosition(2)");
   return(position);
}
