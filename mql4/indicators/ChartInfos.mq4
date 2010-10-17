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

   if (Digits==3 || Digits==5) string strPrice = FormatNumber(price, StringConcatenate(", .", Digits-1, "'"));
   else                               strPrice = FormatNumber(price, StringConcatenate(", .", Digits));

   ObjectSetText(priceLabel, strPrice, 13, "Microsoft Sans Serif", Black);

   int error = GetLastError();
   if (error==ERR_NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)   // bei offenem Properties-Dialog oder Label::onDrag()
      return(ERR_NO_ERROR);
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
   if (error==ERR_NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)   // bei offenem Properties-Dialog oder Label::onDrag()
      return(ERR_NO_ERROR);
   return(catch("UpdateSpreadLabel()", error));
}


/**
 * Aktualisiert das UnitSize-Label.
 */
int UpdateUnitSizeLabel() {
   if (!Show.UnitSize)
      return(0);

   double unitSize = (AccountEquity()-AccountCredit()) / 1000 * 0.07;   // 7% der Equity

   if (StringSubstr(Symbol(), 0, 3) != "USD")
      unitSize /= Close[0];
   
   if      (unitSize < 0.9) unitSize = NormalizeDouble(unitSize, 2);
   else if (unitSize <   9) unitSize = NormalizeDouble(unitSize, 1);
   else                     unitSize = NormalizeDouble(unitSize, 0);

   //Print("UpdateUnitSizeLabel()    unitSize="+ FormatNumber(unitSize, ".+"));

   string strUnitSize = StringConcatenate("UnitSize:  ", FormatNumber(unitSize, ".+"), " Lot");

   ObjectSetText(unitSizeLabel, strUnitSize, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (error==ERR_NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)   // bei offenem Properties-Dialog oder Label::onDrag()
      return(ERR_NO_ERROR);
   return(catch("UpdateUnitSizeLabel()", error));
}


/**
 * Aktualisiert das Position-Label.
 */
int UpdatePositionLabel() {
   if (!Show.Position)
      return(0);

   bool   inMarket;
   double long, short, position;

   int orders = OrdersTotal();

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         break;

      if (OrderSymbol() == Symbol()) {
         inMarket = true;
         if      (OrderType() == OP_BUY ) long  += OrderLots();
         else if (OrderType() == OP_SELL) short += OrderLots();
      }
   }
   long     = NormalizeDouble(long , 8);        // Floating-Point-Fehler bereinigen
   short    = NormalizeDouble(short, 8);
   position = NormalizeDouble(long - short, 8);
   
   if      (!inMarket)     string strPosition = " ";
   else if (position == 0)        strPosition = StringConcatenate("Position:  ±", FormatNumber(long, ".+"), " Lot (fully hedged)");
   else                           strPosition = StringConcatenate("Position:  " , FormatNumber(position, "+.+"), " Lot");

   ObjectSetText(positionLabel, strPosition, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (error==ERR_NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)   // bei offenem Properties-Dialog oder Label::onDrag()
      return(ERR_NO_ERROR);
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

