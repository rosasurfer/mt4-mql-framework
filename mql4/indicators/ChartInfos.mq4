/**
 * Zeigt im Chart verschiedene Informationen an:
 *
 * - oben links: das Symbol des Instruments
 * - oben rechts: den aktuellen Kurs (Bid oder Mittel Bid/Ask)
 * - unter dem Kurs: den Spread, wenn 'Show.Spread' TRUE oder das Symbol in 'TradeInfo.Symbols' eingetragen ist
 * - unten Mitte: die Größe einer Unit, wenn das Symbol in 'TradeInfo.Symbols' eingetragen ist oder eine Position darin gehalten wird
 * - unten Mitte: die in diesem Instrument gehaltene Position
 * - unten rechts: die normalisierte Handelsperformance der letzten Wochen im Instrument
 */

#include <stdlib.mqh>
#include <win32api.mqh>


#property indicator_chart_window


////////////////////////////////////////////////////////////////// User Variablen ////////////////////////////////////////////////////////////////

extern string TradeInfo.Symbols           = "GBPUSD"; // Instrumente, zu denen Handelsinfos angezeigt werden (UnitSize, Position)
extern bool   Show.Spread                 = false;    // ob der Spread angezeigt wird (default: nein; ja, wenn Instrument in TradeInfo.Symbols)
extern bool   Spread.Including.Commission = false;    // ob der Spread nach Broker-Kommission angezeigt werden soll
extern bool   Show.PerformanceDisplay     = true;     // ob das Performance-Display angezeigt werden soll

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string indicatorName = "ChartInfos";
string instrumentLabel, priceLabel, spreadLabel, equityLabel, unitSizeLabel, positionLabel, performanceLabel;
string objects[];

bool Show.UnitSize = false;
bool Show.Position = false;


/**
 *
 */
int init() {
   // DataBox-Anzeige ausschalten
   SetIndexLabel(0, NULL);

   // Label initialisieren
   instrumentLabel  = StringConcatenate(indicatorName, ".Instrument" );
   priceLabel       = StringConcatenate(indicatorName, ".Price"      );
   spreadLabel      = StringConcatenate(indicatorName, ".Spread"     );
   equityLabel      = StringConcatenate(indicatorName, ".Equity"     );
   unitSizeLabel    = StringConcatenate(indicatorName, ".UnitSize"   );
   positionLabel    = StringConcatenate(indicatorName, ".Position"   );
   performanceLabel = StringConcatenate(indicatorName, ".Performance");

   if (StringFind(","+ TradeInfo.Symbols +",", ","+ Symbol() +",") != -1) {
      Show.UnitSize = true;
      Show.Position = true;
      Show.Spread   = true;
   }

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
}


/**
 *
 */
int start() {
   UpdatePriceLabel();
   UpdateSpreadLabel();
   UpdateUnitSizeLabel();
   UpdatePositionLabel();
   UpdatePerformanceDisplay();
   return(catch("start()"));
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
   label = StringConcatenate(indicatorName, ".Graphic_0", lc);
   ObjectDelete(label); GetLastError();
   ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet(label, OBJPROP_XDISTANCE, xCoord-3);
   ObjectSet(label, OBJPROP_YDISTANCE, yCoord-7);
   ObjectSetText(label, "y", 20, "Wingdings 3", frameDarkerColor);
   RegisterChartObject(label, objects);

   // Background
   int xOffsets[4];
   xOffsets[0] = xCoord + 0*53;
   xOffsets[1] = xCoord + 1*53;
   xOffsets[2] = xCoord + 2*53;
   xOffsets[3] = xCoord + 3*53;

   for (int i=0; i < ArraySize(xOffsets); i++) {
      lc++;
      label = StringConcatenate(indicatorName, ".Graphic_a", lc);
      ObjectDelete(label); GetLastError();
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[i]);
      ObjectSet(label, OBJPROP_YDISTANCE, yCoord);
      ObjectSetText(label, "g", 40, "Webdings", backgroundColor);
      RegisterChartObject(label, objects);
   }

   // Rahmen links
   int yOffsets[2];
   yOffsets[0] = yCoord;
   yOffsets[1] = yCoord+22;

   for (i=0; i < ArraySize(yOffsets); i++) {
      lc++;
      label = StringConcatenate(indicatorName, ".Graphic_b", lc);
      ObjectDelete(label); GetLastError();
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[3]+40);
      ObjectSet(label, OBJPROP_YDISTANCE, yOffsets[i]-1);
      ObjectSetText(label, "|", 17, "Webdings", frameBrightColor);
      RegisterChartObject(label, objects);
   }
      lc++;
      label = StringConcatenate(indicatorName, ".Graphic_b", lc);
      ObjectDelete(label); GetLastError();
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[3]+40);
      ObjectSet(label, OBJPROP_YDISTANCE, yCoord+28);
      ObjectSetText(label, "|", 17, "Webdings", frameBrightColor);
      RegisterChartObject(label, objects);

   // Rahmen oben
   lc++;
   label = StringConcatenate(indicatorName, ".Graphic_b", lc);
   ObjectDelete(label); GetLastError();
   ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]);
   ObjectSet(label, OBJPROP_YDISTANCE, yCoord+51);
   ObjectSetText(label, "_________", 27, "Courier New", frameBrightColor);
   RegisterChartObject(label, objects);

   lc++;
   label = StringConcatenate(indicatorName, ".Graphic_b", lc);
   ObjectDelete(label); GetLastError();
   ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[3]+30);
   ObjectSet(label, OBJPROP_YDISTANCE, yCoord+51);
   ObjectSetText(label, "_", 27, "Courier New", frameBrightColor);
   RegisterChartObject(label, objects);

   // Rahmen rechts
   for (i=0; i < ArraySize(yOffsets); i++) {
      lc++;
      label = StringConcatenate(indicatorName, ".Graphic_c", lc);
      ObjectDelete(label); GetLastError();
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]-11);
      ObjectSet(label, OBJPROP_YDISTANCE, yOffsets[i]-2);
      ObjectSetText(label, "|", 17, "Webdings", frameDarkColor);
      RegisterChartObject(label, objects);
   }
      lc++;
      label = StringConcatenate(indicatorName, ".Graphic_c", lc);
      ObjectDelete(label); GetLastError();
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]-11);
      ObjectSet(label, OBJPROP_YDISTANCE, yCoord+28);
      ObjectSetText(label, "|", 17, "Webdings", frameDarkColor);
      RegisterChartObject(label, objects);

   for (i=0; i < ArraySize(yOffsets); i++) {
      lc++;
      label = StringConcatenate(indicatorName, ".Graphic_c", lc);
      ObjectDelete(label); GetLastError();
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]-12);
      ObjectSet(label, OBJPROP_YDISTANCE, yOffsets[i]-3);
      ObjectSetText(label, "|", 17, "Webdings", frameDarkerColor);
      RegisterChartObject(label, objects);
   }
      lc++;
      label = StringConcatenate(indicatorName, ".Graphic_c", lc);
      ObjectDelete(label); GetLastError();
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]-12);
      ObjectSet(label, OBJPROP_YDISTANCE, yCoord+29);
      ObjectSetText(label, "|", 17, "Webdings", frameDarkerColor);
      RegisterChartObject(label, objects);

   // Rahmen unten
   lc++;
   label = StringConcatenate(indicatorName, ".Graphic_d", lc);
   ObjectDelete(label); GetLastError();
   ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]);
   ObjectSet(label, OBJPROP_YDISTANCE, yCoord);
   ObjectSetText(label, "_________", 27, "Courier New", frameDarkColor);
   RegisterChartObject(label, objects);

   lc++;
   label = StringConcatenate(indicatorName, ".Graphic_d", lc);
   ObjectDelete(label); GetLastError();
   ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[3]+30);
   ObjectSet(label, OBJPROP_YDISTANCE, yCoord);
   ObjectSetText(label, "_", 27, "Courier New", frameDarkColor);
   RegisterChartObject(label, objects);

   lc++;
   label = StringConcatenate(indicatorName, ".Graphic_d", lc);
   ObjectDelete(label); GetLastError();
   ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]);
   ObjectSet(label, OBJPROP_YDISTANCE, yCoord-1);
   ObjectSetText(label, "_________", 27, "Courier New", frameDarkerColor);
   RegisterChartObject(label, objects);

   lc++;
   label = StringConcatenate(indicatorName, ".Graphic_d", lc);
   ObjectDelete(label); GetLastError();
   ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[3]+31);
   ObjectSet(label, OBJPROP_YDISTANCE, yCoord-1);
   ObjectSetText(label, "_", 27, "Courier New", frameDarkerColor);
   RegisterChartObject(label, objects);

   // Text
   lc++;
   label = StringConcatenate(indicatorName, ".Graphic_e", lc);
   ObjectDelete(label); GetLastError();
   ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet(label, OBJPROP_XDISTANCE, xOffsets[0]+11);
   ObjectSet(label, OBJPROP_YDISTANCE, yOffsets[1]-3);
   ObjectSetText(label, "-100     +23     +41     -90     +35", 9, "Tahoma", fontColor);
   RegisterChartObject(label, objects);

   /*
   // 2. Anfasser (klein, zur Visualisierung)
   lc++;
   label = StringConcatenate(indicatorName, ".Graphic_x", lc);
   ObjectDelete(label); GetLastError();
   ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet(label, OBJPROP_XDISTANCE, xCoord-2);
   ObjectSet(label, OBJPROP_YDISTANCE, yCoord-3);
   ObjectSetText(label, "y", 9, "Wingdings 3", frameDarkerColor);
   RegisterChartObject(label, objects);
   */

   return(catch("CreatePerformanceDisplay(1)"));
}


/**
 *
 */
int deinit() {
   RemoveChartObjects(objects);
   return(catch("deinit()"));
}


/**
 * Erzeugt das Instrument-Label.
 */
int CreateInstrumentLabel() {
   ObjectDelete(instrumentLabel); GetLastError();
   if (!ObjectCreate(instrumentLabel, OBJ_LABEL, 0, 0, 0))
      return(catch("CreateInstrumentLabel(1), ObjectCreate(label="+ instrumentLabel +")"));
   RegisterChartObject(instrumentLabel, objects);
   ObjectSet(instrumentLabel, OBJPROP_CORNER   , CORNER_TOP_LEFT);
   ObjectSet(instrumentLabel, OBJPROP_XDISTANCE, 4);
   ObjectSet(instrumentLabel, OBJPROP_YDISTANCE, 1);

   // Instrumentnamen einlesen
   string buffer[1]; buffer[0] = StringConcatenate(MAX_LEN_STRING, "");             // !!! Zeigerproblematik
   int bufferSize = StringLen(buffer[0]);
   GetPrivateProfileStringA("Instruments", Symbol(), Symbol(), buffer[0], bufferSize, StringConcatenate(GetMetaTraderDirectory(), "\\experts\\config\\Config.ini"));
   string symbol = buffer[0];

   // Instrumentnamen setzen
   ObjectSetText(instrumentLabel, symbol, 9, "Tahoma Fett", Black);

   return(catch("CreateInstrumentLabel(2)"));
}


/**
 * Erzeugt das Kurslabel.
 */
int CreatePriceLabel() {
   ObjectDelete(priceLabel); GetLastError();
   if (!ObjectCreate(priceLabel, OBJ_LABEL, 0, 0, 0))
      return(catch("CreatePriceLabel(1), ObjectCreate(label="+ priceLabel +")"));
   RegisterChartObject(priceLabel, objects);
   ObjectSet(priceLabel, OBJPROP_CORNER   , CORNER_TOP_RIGHT);
   ObjectSet(priceLabel, OBJPROP_XDISTANCE, 11);
   ObjectSet(priceLabel, OBJPROP_YDISTANCE,  9);
   ObjectSetText(priceLabel, "", 1);

   return(catch("CreatePriceLabel(2)"));
}


/**
 * Erzeugt das Spreadlabel.
 */
int CreateSpreadLabel() {
   if (!Show.Spread)
      return(0);

   ObjectDelete(spreadLabel); GetLastError();
   if (!ObjectCreate(spreadLabel, OBJ_LABEL, 0, 0, 0))
      return(catch("CreateSpreadLabel(1), ObjectCreate(label="+ spreadLabel +")"));
   RegisterChartObject(spreadLabel, objects);
   ObjectSet(spreadLabel, OBJPROP_CORNER   , CORNER_TOP_RIGHT);
   ObjectSet(spreadLabel, OBJPROP_XDISTANCE, 30);
   ObjectSet(spreadLabel, OBJPROP_YDISTANCE, 32);
   ObjectSetText(spreadLabel, "", 1);

   return(catch("CreateSpreadLabel(2)"));
}


/**
 * Erzeugt das UnitSize-Label.
 */
int CreateUnitSizeLabel() {
   if (!Show.UnitSize)
      return(0);

   ObjectDelete(unitSizeLabel); GetLastError();
   if (!ObjectCreate(unitSizeLabel, OBJ_LABEL, 0, 0, 0))
      return(catch("CreateUnitSizeLabel(1), ObjectCreate(label="+ unitSizeLabel +")"));
   RegisterChartObject(unitSizeLabel, objects);
   ObjectSet(unitSizeLabel, OBJPROP_CORNER   , CORNER_BOTTOM_LEFT);
   ObjectSet(unitSizeLabel, OBJPROP_XDISTANCE, 290);
   ObjectSet(unitSizeLabel, OBJPROP_YDISTANCE,  11);
   ObjectSetText(unitSizeLabel, "", 1);

   return(catch("CreateUnitSizeLabel(2)"));
}


/**
 * Erzeugt das Positionlabel.
 */
int CreatePositionLabel() {
   if (!Show.Position)
      return(0);

   ObjectDelete(positionLabel); GetLastError();
   if (!ObjectCreate(positionLabel, OBJ_LABEL, 0, 0, 0))
      return(catch("CreatePositionLabel(1), ObjectCreate(label="+ positionLabel +")"));
   RegisterChartObject(positionLabel, objects);
   ObjectSet(positionLabel, OBJPROP_CORNER   , CORNER_BOTTOM_LEFT);
   ObjectSet(positionLabel, OBJPROP_XDISTANCE, 530);
   ObjectSet(positionLabel, OBJPROP_YDISTANCE,  11);
   ObjectSetText(positionLabel, "", 1);

   return(catch("CreatePositionLabel(2)"));
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
         major = StringSubstr(strPrice, 0, pos);
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
         major = StringConcatenate(StringSubstr(major, 0, len-3), ",", StringSubstr(major, len-3));

      // Vor- und Nachkommastellen zu Gesamtwert zusammensetzen
      if (Digits > 0) strPrice = StringConcatenate(major, ".", minor);
      else            strPrice = major;
   }

   // Wert setzen
   if (!ObjectSetText(priceLabel, strPrice, 13, "Microsoft Sans Serif", Black)) {
      int error = GetLastError();
      if (error != ERR_OBJECT_DOES_NOT_EXIST)      // bei geöffnetem Properties-Dialog oder bei Label::onDrag()
         return(catch("UpdatePriceLabel(1), ObjectSetText(label="+ priceLabel +")", error));
   }

   return(catch("UpdatePriceLabel(2)"));
}


/**
 * Aktualisiert das Spreadlabel.
 */
int UpdateSpreadLabel() {
   if (!Show.Spread)
      return(0);

   double spread = (Ask-Bid) * MathPow(10, Digits-1);

   if (Spread.Including.Commission) if (AccountNumber() == {account-no})
      spread += 0.8;

   if (!ObjectSetText(spreadLabel, DoubleToStr(spread, 1), 9, "Tahoma", SlateGray)) {
      int error = GetLastError();
      if (error != ERR_OBJECT_DOES_NOT_EXIST)      // bei geöffnetem Properties-Dialog oder bei Label::onDrag()
         return(catch("UpdateSpreadLabel(1), ObjectSetText(label="+ spreadLabel +")", error));
   }

   return(catch("UpdateSpreadLabel(2)"));
}


/**
 * Aktualisiert das UnitSize-Label.
 */
int UpdateUnitSizeLabel() {
   if (!Show.UnitSize)
      return(0);

   string strUnitSize = StringConcatenate("UnitSize:  ", DoubleToStrTrim(GetCurrentUnitSize()), " Lot");

   if (!ObjectSetText(unitSizeLabel, strUnitSize, 9, "Tahoma", SlateGray)) {
      int error = GetLastError();
      if (error != ERR_OBJECT_DOES_NOT_EXIST)      // bei geöffnetem Properties-Dialog oder bei Label::onDrag()
         return(catch("UpdateUnitSizeLabel(1), ObjectSetText(label="+ unitSizeLabel +")", error));
   }

   return(catch("UpdateUnitSizeLabel(2)"));
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

   if (!ObjectSetText(positionLabel, strPosition, 9, "Tahoma", SlateGray)) {
      int error = GetLastError();
      if (error != ERR_OBJECT_DOES_NOT_EXIST)      // bei geöffnetem Properties-Dialog oder bei Label::onDrag()
         return(catch("UpdatePositionLabel(1), ObjectSetText(label="+ positionLabel +")", error));
   }

   return(catch("UpdatePositionLabel(2)"));
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
 * @return double - Größe einer Unit in Lot
 */
double GetCurrentUnitSize() {
   // TODO: Verwendung von Bid ist Unfug, funktioniert nur mit dem aktuellen Symbol

   if (Bid == 0)     // ohne Connection würde Division durch 0 ausgelöst
      return(0);

   double unitSize = (AccountEquity()-AccountCredit()) / Bid / 100000 * 7;

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

