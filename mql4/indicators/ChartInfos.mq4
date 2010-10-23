/**
 * Zeigt im Chart verschiedene Informationen an:
 *
 * - oben links:     der Name des Instruments
 * - oben rechts:    der aktuelle Kurs (average price)
 * - unter dem Kurs: der Spread, wenn 'Show.Spread' TRUE ist
 * - unten Mitte:    die Größe einer Handels-Unit
 * - unten Mitte:    die im Moment gehaltene Position
 */

#include <stdlib.mqh>


#property indicator_chart_window


bool init       = false;
int  init_error = ERR_NO_ERROR;


////////////////////////////////////////////////////////////////// User Variablen ////////////////////////////////////////////////////////////////

extern bool Show.Spread                 = false;         // ob der Spread angezeigt wird (default: ja)
extern bool Spread.Including.Commission = false;         // ob der Spread inklusive einer evt. Commission angezeigt werden soll

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string instrumentLabel, priceLabel, spreadLabel, equityLabel, unitSizeLabel, positionLabel, performanceLabel;
string labels[];

bool Show.UnitSize           = false;
bool Show.Position           = false;


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

   // TODO: UnitSize und Position bei Indizes, Aktien etc. ausblenden
   Show.UnitSize = true;
   Show.Position = true;
   Show.Spread   = true;

   CreateInstrumentLabel();
   CreatePriceLabel();
   CreateSpreadLabel();
   CreateUnitSizeLabel();
   CreatePositionLabel();

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
 * Aktualisiert das Kurslabel.
 */
int UpdatePriceLabel() {
   if (Bid==0 || Ask==0)               // bei Start oder Accountwechsel
      return(0);

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

   int error = GetLastError();
   if (error == ERR_UNKNOWN_SYMBOL)       // bei Start oder Accountwechsel
      return(ERR_NO_ERROR);

   if (Spread.Including.Commission) if (AccountNumber() == {account-no})
      spread += 8;

   if (Digits==3 || Digits==5) string strSpread = DoubleToStr(spread/10.0, 1);
   else                               strSpread = spread;

   ObjectSetText(spreadLabel, strSpread, 9, "Tahoma", SlateGray);

   error = GetLastError();
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
      
   double equity = AccountEquity() - AccountCredit();
   if (equity < 0)
      return(0);

   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);

   int error = GetLastError();
   if (error == ERR_UNKNOWN_SYMBOL)       // bei Start oder Accountwechsel
      return(ERR_NO_ERROR);

   if (Bid==0 || tickSize==0 || tickValue==0)
      return(0);


   // AccountEquity wird mit realem Hebel 7 gehebelt (= 7% der Equity mit Hebel 1:100)
   double leverage = 7;
   double lotValue = Bid / tickSize * tickValue;
   double unitSize = equity * leverage / lotValue;

   if      (unitSize <=    0.02) unitSize = NormalizeDouble(MathRound(unitSize/  0.001) *   0.001, 3);   // 0.007-0.02: Vielfache von   0.001 (0.007,0.008,0.009,...)
   else if (unitSize <=    0.04) unitSize = NormalizeDouble(MathRound(unitSize/  0.002) *   0.002, 3);   //  0.02-0.04: Vielfache von   0.002 (0.02,0.022,0.024,...)
   else if (unitSize <=    0.07) unitSize = NormalizeDouble(MathRound(unitSize/  0.005) *   0.005, 3);   //  0.04-0.07: Vielfache von   0.005 (0.04,0.045,0.05,...)
   else if (unitSize <=    0.2 ) unitSize = NormalizeDouble(MathRound(unitSize/  0.01 ) *   0.01 , 2);   //   0.07-0.2: Vielfache von   0.01  (0.07,0.08,0.09,...)
   else if (unitSize <=    0.4 ) unitSize = NormalizeDouble(MathRound(unitSize/  0.02 ) *   0.02 , 2);   //    0.2-0.4: Vielfache von   0.02  (0.2,0.22,0.24,...)
   else if (unitSize <=    0.7 ) unitSize = NormalizeDouble(MathRound(unitSize/  0.05 ) *   0.05 , 2);   //    0.4-0.7: Vielfache von   0.05  (0.4,0.45,0.5,...)
   else if (unitSize <=    2   ) unitSize = NormalizeDouble(MathRound(unitSize/  0.1  ) *   0.1  , 1);   //      0.7-2: Vielfache von   0.1   (0.7,0.8,0.9,...)
   else if (unitSize <=    4   ) unitSize = NormalizeDouble(MathRound(unitSize/  0.2  ) *   0.2  , 1);   //        2-4: Vielfache von   0.2   (2,2.2,2.4,...)
   else if (unitSize <=    7   ) unitSize = NormalizeDouble(MathRound(unitSize/  0.5  ) *   0.5  , 1);   //        4-7: Vielfache von   0.5   (4,4.5,5,...)
   else if (unitSize <=   20   ) unitSize = NormalizeDouble(MathRound(unitSize/  1    ) *   1    , 0);   //       7-20: Vielfache von   1     (7,8,9,...)
   else if (unitSize <=   40   ) unitSize = NormalizeDouble(MathRound(unitSize/  2    ) *   2    , 0);   //      20-40: Vielfache von   2     (20,22,24,...)
   else if (unitSize <=   70   ) unitSize = NormalizeDouble(MathRound(unitSize/  5    ) *   5    , 0);   //      40-70: Vielfache von   5     (40,45,50,...)
   else if (unitSize <=  200   ) unitSize = NormalizeDouble(MathRound(unitSize/ 10    ) *  10    , 0);   //     70-200: Vielfache von  10     (70,80,90,...)
   else if (unitSize <=  400   ) unitSize = NormalizeDouble(MathRound(unitSize/ 20    ) *  20    , 0);   //    200-400: Vielfache von  20     (200,220,240,...)
   else if (unitSize <=  700   ) unitSize = NormalizeDouble(MathRound(unitSize/ 50    ) *  50    , 0);   //    400-700: Vielfache von  50     (400,450,500,...)
   else if (unitSize <= 2000   ) unitSize = NormalizeDouble(MathRound(unitSize/100    ) * 100    , 0);   //   700-2000: Vielfache von 100     (700,800,900,...)

   string strUnitSize = StringConcatenate("UnitSize:  ", FormatNumber(unitSize, ", .+"), " Lot");

   ObjectSetText(unitSizeLabel, strUnitSize, 9, "Tahoma", SlateGray);

   error = GetLastError();
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
         if      (OrderType() == OP_BUY ) long  += OrderLots();
         else if (OrderType() == OP_SELL) short += OrderLots();
      }
   }
   long     = NormalizeDouble(long , 8);        // Floating-Point-Fehler bereinigen
   short    = NormalizeDouble(short, 8);
   position = NormalizeDouble(long - short, 8);
   inMarket = (long > 0 || short > 0);

   if      (!inMarket)     string strPosition = " ";
   else if (position == 0)        strPosition = StringConcatenate("Position:  ±", FormatNumber(long, ".+"), " Lot (fully hedged)");
   else                           strPosition = StringConcatenate("Position:  " , FormatNumber(position, "+.+"), " Lot");

   ObjectSetText(positionLabel, strPosition, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (error==ERR_NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)   // bei offenem Properties-Dialog oder Label::onDrag()
      return(ERR_NO_ERROR);
   return(catch("UpdatePositionLabel()", error));
}

