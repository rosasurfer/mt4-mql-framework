/**
 * Zeigt im Chart verschiedene aktuelle Informationen an.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/indicator.mqh>

#property indicator_chart_window


string label.instrument   = "Instrument";                   // Label der einzelnen Anzeigen
string label.price        = "Price";
string label.spread       = "Spread";
string label.unitSize     = "UnitSize";
string label.position     = "Position";
string label.time         = "Time";
string label.freezeLevel  = "MarginFreezeLevel";
string label.stopoutLevel = "MarginStopoutLevel";

int    appliedPrice = PRICE_MEDIAN;                         // Bid | Ask | Median (default)
double leverage;                                            // Hebel zur UnitSize-Berechnung

bool   isPosition;
bool   positionsAnalyzed;

double longPosition;                                        // Gesamtposition
double shortPosition;
double totalPosition;

double customPositions.conf [][2];                          // individuelle Positionskonfiguration: = {LotSize, Ticket/ID}
int    customPositions.types[][2];                          // Positionsdetails: = {PositionType, DirectionType}
double customPositions.data [][4];                          //                   = {DirectionalLotSize, HedgedLotSize, BreakevenPrice/Pips, Profit}


#define TYPE_DEFAULT       0                                // PositionTypes
#define TYPE_CUSTOM        1
#define TYPE_VIRTUAL       2

#define TYPE_LONG          1                                // DirectionType-Flags
#define TYPE_SHORT         2
#define TYPE_HEDGE         4

#define I_DIRECTLOTSIZE    0                                // Arrayindizes von customPositions.data[]
#define I_HEDGEDLOTSIZE    1
#define I_BREAKEVEN        2
#define I_PROFIT           3


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);

   // Konfiguration auswerten
   string price = "bid";
   if (!IsVisualMode())                                              // im Tester wird immer PRICE_BID verwendet (ist ausreichend und schneller)
      price = StringToLower(GetGlobalConfigString("AppliedPrice", StdSymbol(), "median"));
   if      (price == "bid"   ) appliedPrice = PRICE_BID;
   else if (price == "ask"   ) appliedPrice = PRICE_ASK;
   else if (price == "median") appliedPrice = PRICE_MEDIAN;
   else return(catch("onInit(1)   invalid configuration value [AppliedPrice], "+ StdSymbol() +" = \""+ price +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   leverage = GetGlobalConfigDouble("Leverage", "Pair", 1);
   if (leverage < 1)
      return(catch("onInit(2)   invalid configuration value [Leverage] Pair = "+ NumberToStr(leverage, ".+"), ERR_INVALID_CONFIG_PARAMVALUE));

   // Label erzeugen
   CreateLabels();

   return(catch("onInit(3)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   RemoveChartObjects();
   return(catch("onDeinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   positionsAnalyzed = false;

   if (!UpdatePrice()       ) return(last_error);
   if (!UpdateSpread()      ) return(last_error);
   if (!UpdateUnitSize()    ) return(last_error);
   if (!UpdatePosition()    ) return(last_error);
   if (!UpdateMarginLevels()) return(last_error);
   if (!UpdateTime()        ) return(last_error);

   return(last_error);
}


/**
 * Erzeugt die einzelnen ChartInfo-Label.
 *
 * @return int - Fehlerstatus
 */
int CreateLabels() {
   // Label definieren
   label.instrument   = __NAME__ +"."+ label.instrument;
   label.price        = __NAME__ +"."+ label.price;
   label.spread       = __NAME__ +"."+ label.spread;
   label.unitSize     = __NAME__ +"."+ label.unitSize;
   label.position     = __NAME__ +"."+ label.position;
   label.time         = __NAME__ +"."+ label.time;
   label.freezeLevel  = __NAME__ +"."+ label.freezeLevel;
   label.stopoutLevel = __NAME__ +"."+ label.stopoutLevel;


   // Instrument-Label
   if (ObjectFind(label.instrument) == 0)
      ObjectDelete(label.instrument);
   if (ObjectCreate(label.instrument, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet (label.instrument, OBJPROP_CORNER, CORNER_TOP_LEFT);
         int build = GetTerminalBuild();
      ObjectSet (label.instrument, OBJPROP_XDISTANCE, ifInt(build < 479, 4, 13));
      ObjectSet (label.instrument, OBJPROP_YDISTANCE, ifInt(build < 479, 1,  3));
      PushObject(label.instrument);
   }
   else GetLastError();
      // Die Instrumentanzeige wird sofort und nur einmal gesetzt.
      string name = GetLongSymbolNameOrAlt(Symbol(), GetSymbolName(Symbol()));
      if      (StringIEndsWith(Symbol(), "_ask")) name = StringConcatenate(name, " (Ask)");
      else if (StringIEndsWith(Symbol(), "_avg")) name = StringConcatenate(name, " (Avg)");
      ObjectSetText(label.instrument, name, 9, "Tahoma Fett", Black);


   // Price-Label
   if (ObjectFind(label.price) == 0)
      ObjectDelete(label.price);
   if (ObjectCreate(label.price, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.price, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label.price, OBJPROP_XDISTANCE, 14);
      ObjectSet    (label.price, OBJPROP_YDISTANCE, 15);
      ObjectSetText(label.price, " ", 1);
      PushObject   (label.price);
   }
   else GetLastError();


   // Spread-Label
   if (ObjectFind(label.spread) == 0)
      ObjectDelete(label.spread);
   if (ObjectCreate(label.spread, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.spread, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label.spread, OBJPROP_XDISTANCE, 33);
      ObjectSet    (label.spread, OBJPROP_YDISTANCE, 38);
      ObjectSetText(label.spread, " ", 1);
      PushObject   (label.spread);
   }
   else GetLastError();


   // UnitSize-Label
   if (ObjectFind(label.unitSize) == 0)
      ObjectDelete(label.unitSize);
   if (ObjectCreate(label.unitSize, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.unitSize, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet    (label.unitSize, OBJPROP_XDISTANCE, 9);
      ObjectSet    (label.unitSize, OBJPROP_YDISTANCE, 9);
      ObjectSetText(label.unitSize, " ", 1);
      PushObject   (label.unitSize);
   }
   else GetLastError();


   // Position-Label
   if (ObjectFind(label.position) == 0)
      ObjectDelete(label.position);
   if (ObjectCreate(label.position, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.position, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet    (label.position, OBJPROP_XDISTANCE,  9);
      ObjectSet    (label.position, OBJPROP_YDISTANCE, 29);
      ObjectSetText(label.position, " ", 1);
      PushObject   (label.position);
   }
   else GetLastError();


   // nur im Tester: Time-Label
   if (IsVisualMode()) {
      if (ObjectFind(label.time) == 0)
         ObjectDelete(label.time);
      if (ObjectCreate(label.time, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label.time, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet    (label.time, OBJPROP_XDISTANCE,  9);
         ObjectSet    (label.time, OBJPROP_YDISTANCE, 49);
         ObjectSetText(label.time, " ", 1);
         PushObject   (label.time);
      }
      else GetLastError();
   }

   return(catch("CreateLabels()"));
}


/**
 * Aktualisiert die Kursanzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdatePrice() {
   static string priceFormat;
   if (!StringLen(priceFormat))
      priceFormat = StringConcatenate(",,", PriceFormat);

   double price;

   if (!Bid) {                                                                // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
      price = Close[0];
   }
   else {
      switch (appliedPrice) {
         case PRICE_BID   : price =  Bid;          break;
         case PRICE_ASK   : price =  Ask;          break;
         case PRICE_MEDIAN: price = (Bid + Ask)/2; break;
      }
   }
   ObjectSetText(label.price, NumberToStr(price, priceFormat), 13, "Microsoft Sans Serif", Black);

   int error = GetLastError();
   if (!error)                             return(true);
   if (error == ERR_OBJECT_DOES_NOT_EXIST) return(true);                      // bei offenem Properties-Dialog oder Object::onDrag()

   return(!catch("UpdatePrice(2)", error));
}


/**
 * Aktualisiert die Spreadanzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateSpread() {
   if (!Bid)                                                                  // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
      return(true);

   string strSpread = DoubleToStr(MarketInfo(Symbol(), MODE_SPREAD)/PipPoints, Digits<<31>>31);

   ObjectSetText(label.spread, strSpread, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)           // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateSpread()", error));
   return(true);
}


/**
 * Aktualisiert die UnitSize-Anzeige.
 *
 * @return bool - Erfolgsstatus
 */
int UpdateUnitSize() {
   if (IsTesting())                                                           // Unit-Anzeige wird im Tester nicht benötigt
      return(true);

   bool   tradeAllowed = MarketInfo(Symbol(), MODE_TRADEALLOWED);
   double tickSize     = MarketInfo(Symbol(), MODE_TICKSIZE    );
   double tickValue    = MarketInfo(Symbol(), MODE_TICKVALUE   );

   int error = GetLastError();
   if (IsError(error)) {
      if (error == ERR_UNKNOWN_SYMBOL)
         return(true);
      return(!catch("UpdateUnitSize(1)", error));
   }


   if (tradeAllowed) {
      if (tickSize != 0) /*&&*/ if (tickValue != 0) {                         // bei Start oder Accountwechsel können Werte noch nicht gesetzt sein

         double price, equity=MathMin(AccountBalance(), AccountEquity()-AccountCredit());
         if (!Bid) price = Close[0];                                          // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
         else      price = Bid;

         if (equity > 0.00000001) {
            double lotValue =  price / tickSize * tickValue;                  // Lotvalue in Account-Currency
            double unitSize = equity / lotValue * leverage;                   // Equity wird mit 'leverage' gehebelt (equity/lotValue entspricht Hebel 1)
                                                                              // das Ergebnis wird immer ab-, niemals aufgerundet
            if      (unitSize <=    0.03) unitSize = NormalizeDouble(MathFloor(unitSize/  0.001) *   0.001, 3);   //     0-0.03: Vielfaches von   0.001
            else if (unitSize <=    0.05) unitSize = NormalizeDouble(MathFloor(unitSize/  0.002) *   0.002, 3);   //  0.03-0.05: Vielfaches von   0.002
            else if (unitSize <=    0.12) unitSize = NormalizeDouble(MathFloor(unitSize/  0.005) *   0.005, 3);   //  0.05-0.12: Vielfaches von   0.005
            else if (unitSize <=    0.3 ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.01 ) *   0.01 , 2);   //   0.12-0.3: Vielfaches von   0.01
            else if (unitSize <=    0.5 ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.02 ) *   0.02 , 2);   //    0.3-0.5: Vielfaches von   0.02
            else if (unitSize <=    1.2 ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.05 ) *   0.05 , 2);   //    0.5-1.2: Vielfaches von   0.05
            else if (unitSize <=    3.  ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.1  ) *   0.1  , 1);   //      1.2-3: Vielfaches von   0.1
            else if (unitSize <=    5.  ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.2  ) *   0.2  , 1);   //        3-5: Vielfaches von   0.2
            else if (unitSize <=   12.  ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.5  ) *   0.5  , 1);   //       5-12: Vielfaches von   0.5
            else if (unitSize <=   30.  ) unitSize = MathRound      (MathFloor(unitSize/  1    ) *   1       );   //      12-30: Vielfaches von   1
            else if (unitSize <=   50.  ) unitSize = MathRound      (MathFloor(unitSize/  2    ) *   2       );   //      30-50: Vielfaches von   2
            else if (unitSize <=  120.  ) unitSize = MathRound      (MathFloor(unitSize/  5    ) *   5       );   //     50-120: Vielfaches von   5
            else if (unitSize <=  300.  ) unitSize = MathRound      (MathFloor(unitSize/ 10    ) *  10       );   //    120-300: Vielfaches von  10
            else if (unitSize <=  500.  ) unitSize = MathRound      (MathFloor(unitSize/ 20    ) *  20       );   //    300-500: Vielfaches von  20
            else if (unitSize <= 1200.  ) unitSize = MathRound      (MathFloor(unitSize/ 50    ) *  50       );   //   500-1200: Vielfaches von  50
            else                          unitSize = MathRound      (MathFloor(unitSize/100    ) * 100       );   //   1200-...: Vielfaches von 100

            string strUnitSize = StringConcatenate("UnitSize:  ", NumberToStr(unitSize, ", .+"), " lot");
            ObjectSetText(label.unitSize, strUnitSize, 9, "Tahoma", SlateGray);

            error = GetLastError();
            if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
               return(!catch("UpdateUnitSize(2)", error));
         }
      }
   }
   return(true);
}


/**
 * Aktualisiert die Positionsanzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdatePosition() {
   if (!positionsAnalyzed)
      if (!AnalyzePositions())
         return(false);


   // (1) Gesamtpositionsanzeige unten rechts
   string strPosition;
   if      (!isPosition   ) strPosition = " ";
   else if (!totalPosition) strPosition = StringConcatenate("Position:  ±", NumberToStr(longPosition, ", .+"), " lot (hedged)");
   else                     strPosition = StringConcatenate("Position:  " , NumberToStr(totalPosition, "+, .+"), " lot");
   ObjectSetText(label.position, strPosition, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdatePosition(1)", error));


   // (2) detaillierte Positionsanzeige unten links
   int    fontSize         = 8;
   string fontName.regular = "MS Sans Serif";
   string fontName.bold    = "Arial Fett";
   color  fontColors[]     = {Blue, DeepPink, Green};                // ={COLOR_DEFAULT, COLOR_CUSTOM, COLOR_VIRTUAL}

   // Spalten:      Direction:, LotSize, BE:, BePrice, SL:, SlPrice, Profit:, ProfitAmount
   int xShifts[] = {20,         59,      135, 160,     231, 252,     323,     355};
   int positions=ArrayRange(customPositions.types, 0), cols=ArraySize(xShifts), yDist=3;

   // (2.1) ggf. weitere Zeilen hinzufügen
   static int lines;
   while (lines < positions) {
      lines++;
      for (int col=0; col < cols; col++) {
         string label = label.position +".line"+ lines +"_col"+ col;
         if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
            ObjectSet    (label, OBJPROP_CORNER, CORNER_BOTTOM_LEFT);
            ObjectSet    (label, OBJPROP_XDISTANCE, xShifts[col]                  );
            ObjectSet    (label, OBJPROP_YDISTANCE, yDist + (lines-1)*(fontSize+8));
            ObjectSetText(label, " ", 1);
            PushObject   (label);
         }
         else GetLastError();
      }
   }
   // (2.2) nicht benötigte Zeilen löschen
   while (lines > positions) {
      for (col=0; col < cols; col++) {
         label = label.position +".line"+ lines +"_col"+ col;
         if (ObjectFind(label) != -1)
            ObjectDelete(label);
      }
      lines--;
   }

   // (2.3) Zeilen von unten nach oben schreiben:   "{Type}: {LotSize}   BE|Dist: {BePrice}   SL: {SlPrice}   Profit: {ProfitAmount}"
   string strLotSize, strTypes[]={"", "Long:", "Short:", "", "Hedge:"};

   for (int line, i=positions-1; i >= 0; i--) {
      line++;
      if (customPositions.types[i][1] == TYPE_HEDGE) {
         ObjectSetText(label.position +".line"+ line +"_col0",    strTypes[customPositions.types[i][1]],                                                                  fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col1", NumberToStr(customPositions.data [i][I_HEDGEDLOTSIZE], ".+") +" lot",                                      fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col2", "Dist:",                                                                                                   fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
            if (!customPositions.data[i][I_BREAKEVEN])
         ObjectSetText(label.position +".line"+ line +"_col3", "...",                                                                                                     fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
            else
         ObjectSetText(label.position +".line"+ line +"_col3", DoubleToStr(RoundFloor(customPositions.data[i][I_BREAKEVEN], Digits-PipDigits), Digits-PipDigits) +" pip", fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col4", " ",                                                                                                       fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col5", " ",                                                                                                       fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col6", "Profit:",                                                                                                 fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
            if (!customPositions.data[i][I_PROFIT])
         ObjectSetText(label.position +".line"+ line +"_col7", "...",                                                                                                     fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
            else
         ObjectSetText(label.position +".line"+ line +"_col7", DoubleToStr(customPositions.data[i][I_PROFIT], 2),                                                         fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
      }
      else {
         ObjectSetText(label.position +".line"+ line +"_col0",             strTypes[customPositions.types[i][1]],                                                         fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
            if (!customPositions.data[i][I_HEDGEDLOTSIZE]) strLotSize = NumberToStr(customPositions.data [i][I_DIRECTLOTSIZE], ".+");
            else                                           strLotSize = NumberToStr(customPositions.data [i][I_DIRECTLOTSIZE], ".+") +" ±"+ NumberToStr(customPositions.data[i][I_HEDGEDLOTSIZE], ".+");
         ObjectSetText(label.position +".line"+ line +"_col1", strLotSize +" lot",                                                                                        fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col2", "BE:",                                                                                                     fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
            if (!customPositions.data[i][I_BREAKEVEN])
         ObjectSetText(label.position +".line"+ line +"_col3", "...",                                                                                                     fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
            else if (customPositions.types[i][1] == TYPE_LONG)
         ObjectSetText(label.position +".line"+ line +"_col3", NumberToStr(RoundCeil(customPositions.data[i][I_BREAKEVEN], Digits), PriceFormat),                         fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
            else
         ObjectSetText(label.position +".line"+ line +"_col3", NumberToStr(RoundFloor(customPositions.data[i][I_BREAKEVEN], Digits), PriceFormat),                        fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col4", "SL:",                                                                                                     fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col5", NumberToStr(0, PriceFormat),                                                                               fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col6", "Profit:",                                                                                                 fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col7", DoubleToStr(customPositions.data[i][I_PROFIT], 2),                                                         fontSize, fontName.regular, fontColors[customPositions.types[i][0]]);
      }
   }
   return(!catch("UpdatePosition(2)"));
}


/**
 * Aktualisiert die Anzeige der aktuellen Freeze- und Stopoutlevel.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateMarginLevels() {
   if (!positionsAnalyzed)
      if (!AnalyzePositions())
         return(false);

   if (!totalPosition) {                                                   // keine Position im Markt: ggf. vorhandene Marker löschen
      ObjectDelete(label.freezeLevel);
      ObjectDelete(label.stopoutLevel);
   }
   else {
      // Kurslevel für Margin-Freeze/-Stopout berechnen und anzeigen
      double equity         = AccountEquity();
      double usedMargin     = AccountMargin();
      int    stopoutMode    = AccountStopoutMode();
      int    stopoutLevel   = AccountStopoutLevel();
      double marginRequired = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
      double tickSize       = MarketInfo(Symbol(), MODE_TICKSIZE      );
      double tickValue      = MarketInfo(Symbol(), MODE_TICKVALUE     );
      double marginLeverage = Bid / tickSize * tickValue / marginRequired;    // Hebel der real zur Verfügung gestellten Kreditlinie für das Symbol
             tickValue      = tickValue * MathAbs(totalPosition);             // TickValue der gesamten Position

      int error = GetLastError();
      if (!tickSize || !tickValue)                                            // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
         return(SetLastError(ERR_UNKNOWN_SYMBOL));

      bool showFreezeLevel = true;

      if (stopoutMode == ASM_ABSOLUTE) { double equityStopoutLevel = stopoutLevel;                        }
      else if (stopoutLevel == 100)    {        equityStopoutLevel = usedMargin; showFreezeLevel = false; } // Freeze- und StopoutLevel sind identisch, nur StopOut anzeigen
      else                             {        equityStopoutLevel = stopoutLevel / 100.0 * usedMargin;   }

      double quoteFreezeDiff  = (equity - usedMargin        ) / tickValue * tickSize;
      double quoteStopoutDiff = (equity - equityStopoutLevel) / tickValue * tickSize;

      double quoteFreezeLevel, quoteStopoutLevel;

      if (totalPosition > 0.00000001) {                                    // long position
         quoteFreezeLevel  = NormalizeDouble(Bid - quoteFreezeDiff, Digits);
         quoteStopoutLevel = NormalizeDouble(Bid - quoteStopoutDiff, Digits);
      }
      else {                                                                  // short position
         quoteFreezeLevel  = NormalizeDouble(Ask + quoteFreezeDiff, Digits);
         quoteStopoutLevel = NormalizeDouble(Ask + quoteStopoutDiff, Digits);
      }
      /*
      debug("UpdateMarginLevels()  equity="      + NumberToStr(equity, ", .2")
                              +"   equity(100%)="+ NumberToStr(usedMargin, ", .2") +" ("+ NumberToStr(equity-usedMargin, "+, .2") +" => "+ NumberToStr(quoteFreezeLevel, PriceFormat) +")"
                              +"   equity(so:"+ ifString(stopoutMode==ASM_ABSOLUTE, "abs", stopoutLevel+"%") +")="+ NumberToStr(equityStopoutLevel, ", .2") +" ("+ NumberToStr(equity-equityStopoutLevel, "+, .2") +" => "+ NumberToStr(quoteStopoutLevel, PriceFormat) +")"
      );
      */

      // FreezeLevel anzeigen
      if (showFreezeLevel) {
         if (ObjectFind(label.freezeLevel) == -1) {
            ObjectCreate (label.freezeLevel, OBJ_HLINE, 0, 0, 0);
            ObjectSet    (label.freezeLevel, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSet    (label.freezeLevel, OBJPROP_COLOR, C'0,201,206');
            ObjectSet    (label.freezeLevel, OBJPROP_BACK , true);
            ObjectSetText(label.freezeLevel, StringConcatenate("Freeze   1:", DoubleToStr(marginLeverage, 0)));
            PushObject   (label.freezeLevel);
         }
         ObjectSet(label.freezeLevel, OBJPROP_PRICE1, quoteFreezeLevel);
      }

      // StopoutLevel anzeigen
      if (ObjectFind(label.stopoutLevel) == -1) {
         ObjectCreate (label.stopoutLevel, OBJ_HLINE, 0, 0, 0);
         ObjectSet    (label.stopoutLevel, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSet    (label.stopoutLevel, OBJPROP_COLOR, OrangeRed);
         ObjectSet    (label.stopoutLevel, OBJPROP_BACK , true);
            if (stopoutMode == ASM_PERCENT) string description = StringConcatenate("Stopout  1:", DoubleToStr(marginLeverage, 0));
            else                                   description = StringConcatenate("Stopout  ", NumberToStr(stopoutLevel, ", ."), AccountCurrency());
         ObjectSetText(label.stopoutLevel, description);
         PushObject   (label.stopoutLevel);
      }
      ObjectSet(label.stopoutLevel, OBJPROP_PRICE1, quoteStopoutLevel);
   }

   error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)           // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateMarginLevels()", error));
   return(true);
}


/**
 * Aktualisiert die Zeitanzeige (nur im Tester bei VisualMode = On).
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateTime() {
   static datetime lastTime;

   datetime now = TimeCurrent();
   if (now == lastTime)
      return(true);

   string date = TimeToStr(now, TIME_DATE),
          yyyy = StringSubstr(date, 0, 4),
          mm   = StringSubstr(date, 5, 2),
          dd   = StringSubstr(date, 8, 2),
          time = TimeToStr(now, TIME_MINUTES|TIME_SECONDS);

   ObjectSetText(label.time, StringConcatenate(dd, ".", mm, ".", yyyy, " ", time), 9, "Tahoma", SlateGray);

   lastTime = now;

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)           // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateTime()", error));
   return(true);
}


/**
 * Ermittelt die momentane Marktpositionierung im aktuellen Instrument.
 *
 * @return bool - Erfolgsstatus
 */
bool AnalyzePositions() {
   if (positionsAnalyzed)
      return(true);

   longPosition  = 0;
   shortPosition = 0;
   totalPosition = 0;

   int orders = OrdersTotal();
   int sortKeys[][2];                                                // ={OpenTime, Ticket}
   ArrayResize(sortKeys, orders);


   // (1) Gesamtposition ermitteln
   for (int n, i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;        // FALSE: während des Auslesens wurde woanders ein offenes Ticket entfernt
      if (OrderSymbol() != Symbol()) continue;
      if (OrderType() > OP_SELL)     continue;

      if (OrderType() == OP_BUY) longPosition  += OrderLots();
      else                       shortPosition += OrderLots();

      sortKeys[n][0] = OrderOpenTime();                              // dabei Sortierschlüssel der Tickets auslesen
      sortKeys[n][1] = OrderTicket();
      n++;
   }
   if (n < orders) {
      ArrayResize(sortKeys, n);
      orders = n;
   }
   totalPosition = NormalizeDouble(longPosition - shortPosition, 2);
   isPosition    = (longPosition || shortPosition);

   if (ArrayRange(customPositions.types, 0) > 0) {
      ArrayResize(customPositions.types, 0);
      ArrayResize(customPositions.data,  0);
   }


   // (2) Positionsdetails analysieren
   if (isPosition) {
      // (2.1) individuelle Konfiguration einlesen
      if (ArrayRange(customPositions.conf, 0) == 0)
         if (!ReadCustomPositions())
            if (IsLastError()) return(false);

      // (2.2) offene Tickets sortieren und einlesen
      if (orders > 1)
         if (!SortTickets(sortKeys))
            return(false);
      int    tickets    [], customTickets    []; ArrayResize(tickets    , orders);
      int    types      [], customTypes      []; ArrayResize(types      , orders);
      double lotSizes   [], customLotSizes   []; ArrayResize(lotSizes   , orders);
      double openPrices [], customOpenPrices []; ArrayResize(openPrices , orders);
      double commissions[], customCommissions[]; ArrayResize(commissions, orders);
      double swaps      [], customSwaps      []; ArrayResize(swaps      , orders);
      double profits    [], customProfits    []; ArrayResize(profits    , orders);

      for (i=0; i < orders; i++) {
         if (!SelectTicket(sortKeys[i][1], "AnalyzePositions(1)"))
            return(false);
         tickets    [i] = OrderTicket();
         types      [i] = OrderType();
         lotSizes   [i] = OrderLots();
         openPrices [i] = OrderOpenPrice();
         commissions[i] = OrderCommission();
         swaps      [i] = OrderSwap();
         profits    [i] = OrderProfit();
      }
      double lotSize, customLongPosition, customShortPosition, customTotalPosition, local.longPosition=longPosition, local.shortPosition=shortPosition, local.totalPosition=totalPosition;
      int    ticket;
      bool   isVirtual;


      // (2.3) individuell konfigurierte Position extrahieren
      int cpSize = ArrayRange(customPositions.conf, 0);

      for (i=0; i < cpSize; i++) {
         lotSize = customPositions.conf[i][0];
         ticket  = customPositions.conf[i][1];

         if (!i || !ticket) {
            // (2.4) individuell konfigurierte Position speichern
            if (ArraySize(customTickets) > 0)
               if (!StorePosition.Consolidate(isVirtual, customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLotSizes, customOpenPrices, customCommissions, customSwaps, customProfits))
                  return(false);
            isVirtual           = false;
            customLongPosition  = 0;
            customShortPosition = 0;
            customTotalPosition = 0;
            ArrayResize(customTickets    , 0);
            ArrayResize(customTypes      , 0);
            ArrayResize(customLotSizes   , 0);
            ArrayResize(customOpenPrices , 0);
            ArrayResize(customCommissions, 0);
            ArrayResize(customSwaps      , 0);
            ArrayResize(customProfits    , 0);
            if (!ticket)
               continue;
         }
         if (!ExtractPosition(lotSize, ticket, local.longPosition, local.shortPosition, local.totalPosition,       tickets,       types,       lotSizes,       openPrices,       commissions,       swaps,       profits,
                              isVirtual,       customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLotSizes, customOpenPrices, customCommissions, customSwaps, customProfits))
            return(false);
      }

      // (2.5) verbleibende Position speichern
      if (!StorePosition.Separate(local.longPosition, local.shortPosition, local.totalPosition, tickets, types, lotSizes, openPrices, commissions, swaps, profits))
         return(false);
   }

   if (cpSize > 0)
      positionsAnalyzed = true;
   return(!catch("AnalyzePositions(2)"));
}


/**
 * Liest die individuell konfigurierten Positionen neu ein.
 *
 * @return bool - Erfolgsstatus
 */
bool ReadCustomPositions() {
   if (ArrayRange(customPositions.conf, 0) > 0)
      ArrayResize(customPositions.conf, 0);

   string keys[], values[], value, details[], strLotSize, strTicket, sNull, section="BreakevenCalculation", stdSymbol=StdSymbol();
   double lotSize, minLotSize=MarketInfo(Symbol(), MODE_MINLOT), lotStep=MarketInfo(Symbol(), MODE_LOTSTEP);
   int    valuesSize, detailsSize, cpSize, m, n, ticket;
   if (!minLotSize) return(false);                                   // falls MarketInfo()-Daten noch nicht verfügbar sind
   if (!lotStep   ) return(false);

   int keysSize = GetPrivateProfileKeys(GetLocalConfigPath(), section, keys);

   for (int i=0; i < keysSize; i++) {
      if (StringIStartsWith(keys[i], stdSymbol)) {
         if (SearchStringArrayI(keys, keys[i]) == i) {
            value = GetLocalConfigString(section, keys[i], "");
            n = StringFind(value, ";");
            if (n != -1)
               value = StringSubstrFix(value, 0, n);
            value = StringTrimRight(value);
            valuesSize = Explode(value, ",", values, NULL);
            m = 0;
            for (n=0; n < valuesSize; n++) {
               detailsSize = Explode(values[n], "#", details, NULL);
               if (detailsSize != 2) {
                  if (detailsSize == 1) {
                     if (!StringLen(StringTrim(values[n])))
                        continue;
                     ArrayResize(details, 2);
                     details[0] = "";
                     details[1] = values[n];
                  }
                  else return(!catch("ReadCustomPositions(3)   illegal configuration \""+ section +"\": "+ keys[i] +"=\""+ value +"\" in \""+ GetLocalConfigPath() +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
               }
               details[0] =               StringTrim(details[0]);  strLotSize = details[0];
               details[1] = StringToUpper(StringTrim(details[1])); strTicket  = details[1];

               // Lotsize validieren
               lotSize = 0;
               if (StringLen(strLotSize) > 0) {
                  if (!StringIsNumeric(strLotSize))      return(!catch("ReadCustomPositions(4)   illegal configuration \""+ section +"\": "+ keys[i] +"=\""+ value +"\" in \""+ GetLocalConfigPath() +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  lotSize = StrToDouble(strLotSize);
                  if (LT(lotSize, minLotSize))           return(!catch("ReadCustomPositions(5)   illegal configuration \""+ section +"\": "+ keys[i] +"=\""+ value +"\" in \""+ GetLocalConfigPath() +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  if (MathModFix(lotSize, lotStep) != 0) return(!catch("ReadCustomPositions(6)   illegal configuration \""+ section +"\": "+ keys[i] +"=\""+ value +"\" in \""+ GetLocalConfigPath() +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
               }

               // Ticket validieren
               if (StringIsDigit(strTicket)) ticket = StrToInteger(strTicket);
               else if (strTicket == "L")    ticket = TYPE_LONG;
               else if (strTicket == "S")    ticket = TYPE_SHORT;
               else return(!catch("ReadCustomPositions(7)   illegal configuration \""+ section +"\": "+ keys[i] +"=\""+ value +"\" in \""+ GetLocalConfigPath() +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

               // Virtuelle Positionen müssen an erster Stelle notiert sein
               if (m && lotSize && ticket<=TYPE_SHORT) return(!catch("ReadCustomPositions(8)   illegal configuration, virtual positions must be noted first in \""+ section +"\": "+ keys[i] +"=\""+ value +"\" in \""+ GetLocalConfigPath() +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

               cpSize = ArrayRange(customPositions.conf, 0);
               ArrayResize(customPositions.conf, cpSize+1);
               customPositions.conf[cpSize][0] = lotSize;
               customPositions.conf[cpSize][1] = ticket;
               m++;
            }
            if (m > 0) {
               cpSize = ArrayRange(customPositions.conf, 0);
               ArrayResize(customPositions.conf, cpSize+1);
               customPositions.conf[cpSize][0] = NULL;
               customPositions.conf[cpSize][1] = NULL;
            }
         }
      }
   }
   cpSize = ArrayRange(customPositions.conf, 0);
   if (!cpSize) {
      ArrayResize(customPositions.conf, cpSize+1);
      customPositions.conf[cpSize][0] = NULL;
      customPositions.conf[cpSize][1] = NULL;
   }
   return(true);
}


/**
 * Extrahiert eine Teilposition aus den übergebenen Positionen.
 *
 * @param  double lotSize    - zu extrahierende LotSize
 * @param  int    ticket     - zu extrahierendes Ticket
 *
 * @param  mixed  vars       - Variablen, aus denen die Position extrahiert wird
 * @param  bool   isVirtual  - ob die extrahierte Position virtuell ist
 * @param  mixed  customVars - Variablen, denen die extrahierte Position hinzugefügt wird
 *
 * @return bool - Erfolgsstatus
 */
bool ExtractPosition(double lotSize, int ticket, double       &longPosition, double       &shortPosition, double       &totalPosition, int       &tickets[], int       &types[], double       &lotSizes[], double       &openPrices[], double       &commissions[], double       &swaps[], double       &profits[],
                                bool &isVirtual, double &customLongPosition, double &customShortPosition, double &customTotalPosition, int &customTickets[], int &customTypes[], double &customLotSizes[], double &customOpenPrices[], double &customCommissions[], double &customSwaps[], double &customProfits[]) {
   int sizeTickets = ArraySize(tickets);

   if (ticket == TYPE_LONG) {
      if (!lotSize) {
         // alle Long-Positionen
         if (longPosition > 0) {
            for (int i=0; i < sizeTickets; i++) {
               if (!tickets[i])
                  continue;
               if (types[i] == OP_BUY) {
                  // Daten nach custom.* übernehmen und Ticket ggf. auf NULL setzen
                  ArrayPushInt   (customTickets,     tickets    [i]);
                  ArrayPushInt   (customTypes,       types      [i]);
                  ArrayPushDouble(customLotSizes,    lotSizes   [i]);
                  ArrayPushDouble(customOpenPrices,  openPrices [i]);
                  ArrayPushDouble(customCommissions, commissions[i]);
                  ArrayPushDouble(customSwaps,       swaps      [i]);
                  ArrayPushDouble(customProfits,     profits    [i]);
                  if (!isVirtual) {
                     longPosition  = NormalizeDouble(longPosition - lotSizes[i],   2);
                     totalPosition = NormalizeDouble(longPosition - shortPosition, 2);
                     tickets[i]    = NULL;
                  }
                  customLongPosition  = NormalizeDouble(customLongPosition + lotSizes[i],         2);
                  customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 2);
               }
            }
         }
      }
      else {
         // virtuelle Long-Position zu custom.* hinzufügen (Ausgangsdaten bleiben unverändert)
         ArrayPushInt   (customTickets,     TYPE_LONG                                     );
         ArrayPushInt   (customTypes,       OP_BUY                                        );
         ArrayPushDouble(customLotSizes,    lotSize                                       );
         ArrayPushDouble(customOpenPrices,  Ask                                           );
         ArrayPushDouble(customCommissions, NormalizeDouble(-GetCommission() * lotSize, 2));
         ArrayPushDouble(customSwaps,       0                                             );
         ArrayPushDouble(customProfits,     (Bid-Ask)/Pips * PipValue(lotSize, true)      ); // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         customLongPosition  = NormalizeDouble(customLongPosition + lotSize,             2);
         customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 2);
         isVirtual           = true;
      }
   }
   else if (ticket == TYPE_SHORT) {
      if (!lotSize) {
         // alle Short-Positionen
         if (shortPosition > 0) {
            for (i=0; i < sizeTickets; i++) {
               if (!tickets[i])
                  continue;
               if (types[i] == OP_SELL) {
                  // Daten nach custom.* übernehmen und Ticket ggf. auf NULL setzen
                  ArrayPushInt   (customTickets,     tickets    [i]);
                  ArrayPushInt   (customTypes,       types      [i]);
                  ArrayPushDouble(customLotSizes,    lotSizes   [i]);
                  ArrayPushDouble(customOpenPrices,  openPrices [i]);
                  ArrayPushDouble(customCommissions, commissions[i]);
                  ArrayPushDouble(customSwaps,       swaps      [i]);
                  ArrayPushDouble(customProfits,     profits    [i]);
                  if (!isVirtual) {
                     shortPosition = NormalizeDouble(shortPosition - lotSizes[i],   2);
                     totalPosition = NormalizeDouble(longPosition  - shortPosition, 2);
                     tickets[i]    = NULL;
                  }
                  customShortPosition = NormalizeDouble(customShortPosition + lotSizes[i],         2);
                  customTotalPosition = NormalizeDouble(customLongPosition  - customShortPosition, 2);
               }
            }
         }
      }
      else {
         // virtuelle Short-Position zu custom.* hinzufügen (Ausgangsdaten bleiben unverändert)
         ArrayPushInt   (customTickets,     TYPE_SHORT                                    );
         ArrayPushInt   (customTypes,       OP_SELL                                       );
         ArrayPushDouble(customLotSizes,    lotSize                                       );
         ArrayPushDouble(customOpenPrices,  Bid                                           );
         ArrayPushDouble(customCommissions, NormalizeDouble(-GetCommission() * lotSize, 2));
         ArrayPushDouble(customSwaps,       0                                             );
         ArrayPushDouble(customProfits,     (Bid-Ask)/Pips * PipValue(lotSize, true)      ); // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         customShortPosition = NormalizeDouble(customShortPosition + lotSize,            2);
         customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 2);
         isVirtual           = true;
      }
   }
   else {
      if (!lotSize) {
         // komplettes Ticket
         for (i=0; i < sizeTickets; i++) {
            if (tickets[i] == ticket) {
               // Daten nach custom.* übernehmen und Ticket ggf. auf NULL setzen
               ArrayPushInt   (customTickets,     tickets    [i]);
               ArrayPushInt   (customTypes,       types      [i]);
               ArrayPushDouble(customLotSizes,    lotSizes   [i]);
               ArrayPushDouble(customOpenPrices,  openPrices [i]);
               ArrayPushDouble(customCommissions, commissions[i]);
               ArrayPushDouble(customSwaps,       swaps      [i]);
               ArrayPushDouble(customProfits,     profits    [i]);
               if (!isVirtual) {
                  if (types[i] == OP_BUY) longPosition        = NormalizeDouble(longPosition  - lotSizes[i],   2);
                  else                    shortPosition       = NormalizeDouble(shortPosition - lotSizes[i],   2);
                                          totalPosition       = NormalizeDouble(longPosition  - shortPosition, 2);
                                          tickets[i]          = NULL;
               }
               if (types[i] == OP_BUY)    customLongPosition  = NormalizeDouble(customLongPosition  + lotSizes[i], 2);
               else                       customShortPosition = NormalizeDouble(customShortPosition + lotSizes[i], 2);
                                          customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 2);
               break;
            }
         }
      }
      else {
         // partielles Ticket
         for (i=0; i < sizeTickets; i++) {
            if (tickets[i] == ticket) {
               if (GT(lotSize, lotSizes[i])) return(!catch("ExtractPosition(1)   illegal partial lotsize "+ NumberToStr(lotSize, ".+") +" for ticket #"+ tickets[i] +" ("+ NumberToStr(lotSizes[i], ".+") +" lot)", ERR_RUNTIME_ERROR));
               if (EQ(lotSize, lotSizes[i])) {
                  if (!ExtractPosition(0, ticket, longPosition,       shortPosition,       totalPosition,       tickets,       types,       lotSizes,       openPrices,       commissions,       swaps,       profits,
                                 isVirtual, customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLotSizes, customOpenPrices, customCommissions, customSwaps, customProfits))
                     return(false);
               }
               else {
                  // Daten anteilig nach custom.* übernehmen und Ticket ggf. reduzieren
                  double factor = lotSize/lotSizes[i];
                  ArrayPushInt   (customTickets,     tickets    [i]         );
                  ArrayPushInt   (customTypes,       types      [i]         );
                  ArrayPushDouble(customLotSizes,    lotSize                ); if (!isVirtual) lotSizes   [i]  = NormalizeDouble(lotSizes[i]-lotSize, 2); // reduzieren
                  ArrayPushDouble(customOpenPrices,  openPrices [i]         );
                  ArrayPushDouble(customSwaps,       swaps      [i]         ); if (!isVirtual) swaps      [i]  = NULL;                                    // komplett
                  ArrayPushDouble(customCommissions, commissions[i] * factor); if (!isVirtual) commissions[i] *= (1-factor);                              // anteilig
                  ArrayPushDouble(customProfits,     profits    [i] * factor); if (!isVirtual) profits    [i] *= (1-factor);                              // anteilig
                  if (!isVirtual) {
                     if (types[i] == OP_BUY) longPosition        = NormalizeDouble(longPosition  - lotSize, 2);
                     else                    shortPosition       = NormalizeDouble(shortPosition - lotSize, 2);
                                             totalPosition       = NormalizeDouble(longPosition  - shortPosition, 2);
                  }
                  if (types[i] == OP_BUY)    customLongPosition  = NormalizeDouble(customLongPosition  + lotSize, 2);
                  else                       customShortPosition = NormalizeDouble(customShortPosition + lotSize, 2);
                                             customTotalPosition = NormalizeDouble(customLongPosition  - customShortPosition, 2);
               }
               break;
            }
         }
      }
   }
   return(!catch("ExtractPosition(2)"));
}


/**
 * Speichert die übergebene Teilposition zusammengefaßt in den globalen Variablen.
 *
 * @return bool - Erfolgsstatus
 */
bool StorePosition.Consolidate(bool isVirtual, double longPosition, double shortPosition, double totalPosition, int &tickets[], int &types[], double &lotSizes[], double &openPrices[], double &commissions[], double &swaps[], double &profits[]) {
   double hedgedLotSize, remainingLong, remainingShort, factor, openPrice, closePrice, commission, swap, profit, hedgedProfit, pipDistance, pipValue;
   int size, ticketsSize=ArraySize(tickets);

   // Die Gesamtposition besteht aus einem gehedgtem Anteil (konstanter Profit) und einem direktionalen Anteil (variabler Profit).
   // - kein direktionaler Anteil:  BE-Distance berechnen
   // - direktionaler Anteil:       Breakeven unter Berücksichtigung des Profits eines gehedgten Anteils berechnen


   // (1) BE-Distance und Profit einer eventuellen Hedgeposition ermitteln
   if (longPosition && shortPosition) {
      hedgedLotSize  = MathMin(longPosition, shortPosition);
      remainingLong  = hedgedLotSize;
      remainingShort = hedgedLotSize;
      openPrice      = 0;
      closePrice     = 0;
      swap           = 0;
      commission     = 0;
      pipDistance    = 0;
      hedgedProfit   = 0;

      for (int i=0; i < ticketsSize; i++) {
         if (!tickets[i]) continue;

         if (types[i] == OP_BUY) {
            if (!remainingLong) continue;
            if (remainingLong >= lotSizes[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice    += lotSizes   [i] * openPrices[i];
               swap         += swaps      [i];
               commission   += commissions[i];
               remainingLong = NormalizeDouble(remainingLong - lotSizes[i], 2);
               tickets[i]    = NULL;
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor        = remainingLong/lotSizes[i];
               openPrice    += remainingLong * openPrices [i];
               swap         +=                 swaps      [i]; swaps      [i]  = 0;
               commission   += factor        * commissions[i]; commissions[i] -= factor * commissions[i];
                                                               profits    [i] -= factor * profits    [i];
                                                               lotSizes   [i]  = NormalizeDouble(lotSizes[i]-remainingLong, 2);
               remainingLong = 0;
            }
         }
         else { /*OP_SELL*/
            if (!remainingShort) continue;
            if (remainingShort >= lotSizes[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               closePrice    += lotSizes   [i] * openPrices[i];
               swap          += swaps      [i];
               //commission  += commissions[i];                                                          // Commission wird nur für Long-Leg übernommen
               remainingShort = NormalizeDouble(remainingShort - lotSizes[i], 2);
               tickets[i]     = NULL;
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor      = remainingShort/lotSizes[i];
               closePrice += remainingShort * openPrices[i];
               swap       +=                  swaps     [i]; swaps      [i]  = 0;
                                                             commissions[i] -= factor * commissions[i];  // Commission wird nur für Long-Leg übernommen
                                                             profits    [i] -= factor * profits    [i];
                                                             lotSizes   [i]  = NormalizeDouble(lotSizes[i]-remainingShort, 2);
               remainingShort = 0;
            }
         }
      }
      if (remainingLong  != 0) return(!catch("StorePosition.Consolidate(1)   illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of custom hedged position = "+ NumberToStr(hedgedLotSize, ".+"), ERR_RUNTIME_ERROR));
      if (remainingShort != 0) return(!catch("StorePosition.Consolidate(2)   illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of custom hedged position = "+ NumberToStr(hedgedLotSize, ".+"), ERR_RUNTIME_ERROR));

      // BE-Distance und Profit berechnen
      pipValue = PipValue(hedgedLotSize, true);                      // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
      if (pipValue != 0) {
         pipDistance  = (closePrice-openPrice)/hedgedLotSize/Pips + (commission+swap)/pipValue;
         hedgedProfit = pipDistance * pipValue;
      }

      // (1.1) Kein direktionaler Anteil: Position speichern und Rückkehr
      if (!totalPosition) {
         size = ArrayRange(customPositions.types, 0);
         ArrayResize(customPositions.types, size+1);
         ArrayResize(customPositions.data,  size+1);

         customPositions.types[size][0]               = TYPE_CUSTOM + isVirtual;
         customPositions.types[size][1]               = TYPE_HEDGE;
         customPositions.data [size][I_DIRECTLOTSIZE] = 0;
         customPositions.data [size][I_HEDGEDLOTSIZE] = hedgedLotSize;
         customPositions.data [size][I_BREAKEVEN    ] = pipDistance;
         customPositions.data [size][I_PROFIT       ] = hedgedProfit;
         return(!catch("StorePosition.Consolidate(3)"));
      }
   }


   // (2) Direktionaler Anteil: Bei Breakeven-Berechnung den Profit eines gehedgten Anteils mit einschließen
   // (2.1) eventuelle Longposition ermitteln
   if (totalPosition > 0) {
      remainingLong = totalPosition;
      openPrice     = 0;
      swap          = 0;
      commission    = 0;
      profit        = 0;

      for (i=0; i < ticketsSize; i++) {
         if (!tickets[i]   ) continue;
         if (!remainingLong) continue;

         if (types[i] == OP_BUY) {
            if (remainingLong >= lotSizes[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice    += lotSizes   [i] * openPrices[i];
               swap         += swaps      [i];
               commission   += commissions[i];
               profit       += profits    [i];
               tickets[i]    = NULL;
               remainingLong = NormalizeDouble(remainingLong - lotSizes[i], 2);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor        = remainingLong/lotSizes[i];
               openPrice    += remainingLong * openPrices [i];
               swap         +=                 swaps      [i]; swaps      [i]  = 0;
               commission   += factor        * commissions[i]; commissions[i] -= factor * commissions[i];
               profit       += factor        * profits    [i]; profits    [i] -= factor * profits    [i];
                                                               lotSizes   [i]  = NormalizeDouble(lotSizes[i]-remainingLong, 2);
               remainingLong = 0;
            }
         }
      }
      if (remainingLong != 0) return(!catch("StorePosition.Consolidate(4)   illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of custom long position = "+ NumberToStr(totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      size = ArrayRange(customPositions.types, 0);
      ArrayResize(customPositions.types, size+1);
      ArrayResize(customPositions.data,  size+1);

      customPositions.types[size][0]               = TYPE_CUSTOM + isVirtual;
      customPositions.types[size][1]               = TYPE_LONG;
      customPositions.data [size][I_DIRECTLOTSIZE] = totalPosition;
      customPositions.data [size][I_HEDGEDLOTSIZE] = hedgedLotSize;
         pipValue = PipValue(totalPosition, true);                   // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      customPositions.data [size][I_BREAKEVEN    ] = openPrice/totalPosition - (hedgedProfit + commission + swap)/pipValue*Pips;
      customPositions.data [size][I_PROFIT       ] = hedgedProfit + commission + swap + profit;
   }


   // (2.2) eventuelle Shortposition ermitteln
   if (totalPosition < 0) {
      remainingShort = -totalPosition;
      openPrice      = 0;
      swap           = 0;
      commission     = 0;
      profit         = 0;

      for (i=0; i < ticketsSize; i++) {
         if (!tickets[i]    ) continue;
         if (!remainingShort) continue;

         if (types[i] == OP_SELL) {
            if (remainingShort >= lotSizes[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice     += lotSizes   [i] * openPrices[i];
               swap          += swaps      [i];
               commission    += commissions[i];
               profit        += profits    [i];
               tickets[i]     = NULL;
               remainingShort = NormalizeDouble(remainingShort - lotSizes[i], 2);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor         = remainingShort/lotSizes[i];
               openPrice     += remainingShort * openPrices [i];
               swap          +=                  swaps      [i]; swaps      [i]  = 0;
               commission    += factor         * commissions[i]; commissions[i] -= factor * commissions[i];
               profit        += factor         * profits    [i]; profits    [i] -= factor * profits    [i];
                                                                 lotSizes   [i]  = NormalizeDouble(lotSizes[i]-remainingShort, 2);
               remainingShort = 0;
            }
         }
      }
      if (remainingShort != 0) return(!catch("StorePosition.Consolidate(5)   illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of custom short position = "+ NumberToStr(-totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      size = ArrayRange(customPositions.types, 0);
      ArrayResize(customPositions.types, size+1);
      ArrayResize(customPositions.data,  size+1);

      customPositions.types[size][0]               = TYPE_CUSTOM + isVirtual;
      customPositions.types[size][1]               = TYPE_SHORT;
      customPositions.data [size][I_DIRECTLOTSIZE] = -totalPosition;
      customPositions.data [size][I_HEDGEDLOTSIZE] = hedgedLotSize;
         pipValue = PipValue(-totalPosition, true);                  // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      customPositions.data [size][I_BREAKEVEN    ] = (hedgedProfit + commission + swap)/pipValue*Pips - openPrice/totalPosition;
      customPositions.data [size][I_PROFIT       ] =  hedgedProfit + commission + swap + profit;
   }

   return(!catch("StorePosition.Consolidate(6)"));
}


/**
 * Speichert die übergebenen Teilpositionen getrennt nach Long/Short/Hedge in den globalen Variablen.
 *
 * @return bool - Erfolgsstatus
 */
bool StorePosition.Separate(double longPosition, double shortPosition, double totalPosition, int &tickets[], int &types[], double &lotSizes[], double &openPrices[], double &commissions[], double &swaps[], double &profits[]) {
   double hedgedLotSize, remainingLong, remainingShort, factor, openPrice, closePrice, commission, swap, profit, pipValue;
   int ticketsSize = ArraySize(tickets);

   // (1) eventuelle Longposition selektieren
   if (totalPosition > 0) {
      remainingLong = totalPosition;
      openPrice     = 0;
      swap          = 0;
      commission    = 0;
      profit        = 0;

      for (int i=ticketsSize-1; i >= 0; i--) {                       // jüngstes Ticket zuerst
         if (!tickets[i]   ) continue;
         if (!remainingLong) continue;

         if (types[i] == OP_BUY) {
            if (remainingLong >= lotSizes[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice    += lotSizes   [i] * openPrices[i];
               swap         += swaps      [i];
               commission   += commissions[i];
               profit       += profits    [i];
               tickets[i]    = NULL;
               remainingLong = NormalizeDouble(remainingLong - lotSizes[i], 2);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor        = remainingLong/lotSizes[i];
               openPrice    += remainingLong * openPrices [i];
               swap         +=                 swaps      [i]; swaps      [i]  = 0;
               commission   += factor        * commissions[i]; commissions[i] -= factor * commissions[i];
               profit       += factor        * profits    [i]; profits    [i] -= factor * profits    [i];
                                                               lotSizes   [i]  = NormalizeDouble(lotSizes[i]-remainingLong, 2);
               remainingLong = 0;
            }
         }
      }
      if (remainingLong != 0) return(!catch("StorePosition.Separate(1)   illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of effective long position = "+ NumberToStr(totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      int size = ArrayRange(customPositions.types, 0);
      ArrayResize(customPositions.types, size+1);
      ArrayResize(customPositions.data,  size+1);

      customPositions.types[size][0]               = TYPE_DEFAULT;
      customPositions.types[size][1]               = TYPE_LONG;
      customPositions.data [size][I_DIRECTLOTSIZE] = totalPosition;
      customPositions.data [size][I_HEDGEDLOTSIZE] = 0;
         pipValue = PipValue(totalPosition, true);                   // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      customPositions.data [size][I_BREAKEVEN    ] = openPrice/totalPosition - (commission+swap)/pipValue*Pips;
      customPositions.data [size][I_PROFIT       ] = commission + swap + profit;
   }


   // (2) eventuelle Shortposition selektieren
   if (totalPosition < 0) {
      remainingShort = -totalPosition;
      openPrice      = 0;
      swap           = 0;
      commission     = 0;
      profit         = 0;

      for (i=ticketsSize-1; i >= 0; i--) {                           // jüngstes Ticket zuerst
         if (!tickets[i]    ) continue;
         if (!remainingShort) continue;

         if (types[i] == OP_SELL) {
            if (remainingShort >= lotSizes[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice     += lotSizes   [i] * openPrices[i];
               swap          += swaps      [i];
               commission    += commissions[i];
               profit        += profits    [i];
               tickets[i]     = NULL;
               remainingShort = NormalizeDouble(remainingShort - lotSizes[i], 2);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor         = remainingShort/lotSizes[i];
               openPrice     += remainingShort * openPrices [i];
               swap          +=                  swaps      [i]; swaps      [i]  = 0;
               commission    += factor         * commissions[i]; commissions[i] -= factor * commissions[i];
               profit        += factor         * profits    [i]; profits    [i] -= factor * profits    [i];
                                                                 lotSizes   [i]  = NormalizeDouble(lotSizes[i]-remainingShort, 2);
               remainingShort = 0;
            }
         }
      }
      if (remainingShort != 0) return(!catch("StorePosition.Separate(2)   illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of effective short position = "+ NumberToStr(-totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      size = ArrayRange(customPositions.types, 0);
      ArrayResize(customPositions.types, size+1);
      ArrayResize(customPositions.data,  size+1);

      customPositions.types[size][0]               = TYPE_DEFAULT;
      customPositions.types[size][1]               = TYPE_SHORT;
      customPositions.data [size][I_DIRECTLOTSIZE] = -totalPosition;
      customPositions.data [size][I_HEDGEDLOTSIZE] = 0;
         pipValue = PipValue(-totalPosition, true);                  // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      customPositions.data [size][I_BREAKEVEN    ] = (commission+swap)/pipValue*Pips - openPrice/totalPosition;
      customPositions.data [size][I_PROFIT       ] = commission + swap + profit;
   }


   // (3) verbleibende Hedgeposition selektieren
   if (longPosition && shortPosition) {
      hedgedLotSize  = MathMin(longPosition, shortPosition);
      remainingLong  = hedgedLotSize;
      remainingShort = hedgedLotSize;
      openPrice      = 0;
      closePrice     = 0;
      swap           = 0;
      commission     = 0;

      for (i=ticketsSize-1; i >= 0; i--) {                           // jüngstes Ticket zuerst
         if (!tickets[i]) continue;
         if (types[i] == OP_BUY) {
            if (!remainingLong) continue;
            if (remainingLong < lotSizes[i]) return(!catch("StorePosition.Separate(3)   illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of hedged position = "+ NumberToStr(hedgedLotSize, ".+"), ERR_RUNTIME_ERROR));

            // Daten komplett übernehmen, Ticket auf NULL setzen
            openPrice    += lotSizes   [i] * openPrices[i];
            swap         += swaps      [i];
            commission   += commissions[i];
            remainingLong = NormalizeDouble(remainingLong - lotSizes[i], 2);
            tickets[i]    = NULL;
         }
         else { /*OP_SELL*/
            if (!remainingShort) continue;
            if (remainingShort < lotSizes[i]) return(!catch("StorePosition.Separate(4)   illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of hedged position = "+ NumberToStr(hedgedLotSize, ".+"), ERR_RUNTIME_ERROR));

            // Daten komplett übernehmen, Ticket auf NULL setzen
            closePrice    += lotSizes   [i] * openPrices[i];
            swap          += swaps      [i];
            //commission  += commissions[i];                         // Commissions nur für eine Seite übernehmen
            remainingShort = NormalizeDouble(remainingShort - lotSizes[i], 2);
            tickets[i]     = NULL;
         }
      }

      // Position speichern
      size = ArrayRange(customPositions.types, 0);
      ArrayResize(customPositions.types, size+1);
      ArrayResize(customPositions.data,  size+1);

      customPositions.types[size][0]               = TYPE_DEFAULT;
      customPositions.types[size][1]               = TYPE_HEDGE;
      customPositions.data [size][I_DIRECTLOTSIZE] = 0;
      customPositions.data [size][I_HEDGEDLOTSIZE] = hedgedLotSize;
         pipValue = PipValue(hedgedLotSize, true);                   // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      customPositions.data [size][I_BREAKEVEN    ] = (closePrice-openPrice)/hedgedLotSize/Pips + (commission+swap)/pipValue;
      customPositions.data [size][I_PROFIT       ] = customPositions.data[size][I_BREAKEVEN] * pipValue;
   }

   return(!catch("StorePosition.Separate(5)"));
}


/**
 * Sortiert die übergebenen Ticketdaten nach OpenTime_asc, Ticket_asc.
 *
 * @param  int keys[] - Array mit Sortierschlüsseln
 *
 * @return bool - Erfolgsstatus
 */
bool SortTickets(int keys[][/*{OpenTime, Ticket}*/]) {
   int rows = ArrayRange(keys, 0);
   if (rows < 2)
      return(true);                                                  // weniger als 2 Zeilen

   // Zeilen nach OpenTime sortieren
   ArraySort(keys);

   // Zeilen mit derselben OpenTime zusätzlich nach Ticket sortieren
   int open, lastOpen, ticket, n, sameOpens[][2];
   ArrayResize(sameOpens, 1);

   for (int i=0; i < rows; i++) {
      open   = keys[i][0];
      ticket = keys[i][1];

      if (open == lastOpen) {
         n++;
         ArrayResize(sameOpens, n+1);
      }
      else if (n > 0) {
         // in sameOpens[] angesammelte Zeilen nach Ticket sortieren und zurück nach keys[] schreiben
         if (!SortSameOpens(sameOpens, keys))
            return(false);
         ArrayResize(sameOpens, 1);
         n = 0;
      }
      sameOpens[n][0] = ticket;
      sameOpens[n][1] = i;                                           // Originalposition der Zeile in keys[]

      lastOpen = open;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameOpens[] angesammelte Zeilen müssen auch verarbeitet werden
      if (!SortSameOpens(sameOpens, keys))
         return(false);
      n = 0;
   }
   return(!catch("SortTickets()"));
}


/**
 * Sortiert die in sameOpens[] übergebenen Daten und aktualisiert die entsprechenden Einträge in data[].
 *
 * @param  int  sameOpens[] - Array mit Ausgangsdaten
 * @param  int &data[]      - das zu aktualisierende Originalarray
 *
 * @return bool - Erfolgsstatus
 */
bool SortSameOpens(int sameOpens[][/*{Ticket, i}*/], int &data[][/*{OpenTime, Ticket}*/]) {
   int sameOpens.copy[][2]; ArrayResize(sameOpens.copy, 0);
   ArrayCopy(sameOpens.copy, sameOpens);                             // Originalreihenfolge der Indizes in Kopie speichern

   // Zeilen nach Ticket sortieren
   ArraySort(sameOpens);

   // Original-Daten mit den sortierten Werten überschreiben
   int ticket, i, rows=ArrayRange(sameOpens, 0);

   for (int n=0; n < rows; n++) {
      ticket = sameOpens     [n][0];
      i      = sameOpens.copy[n][1];
      data[i][1] = ticket;                                           // Originaldaten mit den sortierten Werten überschreiben
   }
   return(!catch("SortSameOpens()"));
}


/**
 * String-Repräsentation der Input-Parameter fürs Logging bei Aufruf durch iCustom().
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()   inputs: ",

                            "appliedPrice=", PriceTypeToStr(appliedPrice), "; ",
                            "leverage=",     DoubleToStr(leverage, 1)    , "; ")
   );
}
