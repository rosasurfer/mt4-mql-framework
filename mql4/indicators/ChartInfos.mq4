/**
 * Zeigt im Chart verschiedene aktuelle Informationen an.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/indicator.mqh>

#include <LFX/define.mqh>
#include <LFX/functions.mqh>

#include <win32api.mqh>
#include <MT4iQuickChannel.mqh>

#property indicator_chart_window


string label.instrument   = "Instrument";                   // Label der einzelnen Anzeigen
string label.ohlc         = "OHLC";
string label.price        = "Price";
string label.spread       = "Spread";
string label.unitSize     = "UnitSize";
string label.position     = "Position";
string label.time         = "Time";
string label.stopoutLevel = "StopoutLevel";

int    appliedPrice = PRICE_MEDIAN;                         // Bid | Ask | Median (default)
double leverage;                                            // Hebel zur UnitSize-Berechnung


// Positionsanzeige
bool   isPosition;
bool   positionsAnalyzed;

double totalPosition;                                       // Gesamtposition total
double longPosition;                                        //                long
double shortPosition;                                       //                short

double local.position.conf    [][2];                        // individuelle Konfiguration: = {LotSize, Ticket|DirectionType}
int    local.position.types   [][2];                        // Positionsdetails:           = {PositionType, DirectionType}
double local.position.data    [][4];                        //                             = {DirectionalLotSize, HedgedLotSize, BreakevenPrice|Pips, Profit}

int    remote.position.tickets[];                           // Remote-Positionsdaten sind im Gegensatz zu lokalen Positionsdaten statisch. Die lokalen Positionsdaten
int    remote.position.types  [][2];                        // werden bei jedem Tick zurückgesetzt und neu eingelesen.
double remote.position.data   [][4];

#define TYPE_DEFAULT       0                                // PositionTypes: normale Terminalposition (lokal oder remote)
#define TYPE_CUSTOM        1                                //                individuell konfigurierte reale Position
#define TYPE_VIRTUAL       2                                //                individuell konfigurierte virtuelle Position (existiert nicht)

#define TYPE_LONG          1                                // DirectionTypes
#define TYPE_SHORT         2
#define TYPE_HEDGE         3

#define I_DIRECTLOTSIZE    0                                // Arrayindizes von positions.data[]
#define I_HEDGEDLOTSIZE    1
#define I_BREAKEVEN        2
#define I_PROFIT           3

string positions.fontName     = "MS Sans Serif";
int    positions.fontSize     = 8;
color  positions.fontColors[] = {Blue, DeepPink, Green};    // für unterschiedliche PositionTypes: {TYPE_DEFAULT, TYPE_CUSTOM, TYPE_VIRTUAL}


// QuickChannel
bool   isLfxChart;
int    hLfxSenderChannels[9];                               // QuickChannel-Sender-Handles, Größe entspricht der größten LFX-Currency-ID, @see "LFX/define.mqh"
int    hLfxReceiverChannel;                                 // QuickChannel-Receiver-Handle
string lfxReceiverChannelName;                              // QuickChannel-Receiver Channel-Name
string lfxReceiverChannelBuffer[];                          // QuickChannel-Receiver Channel-Buffer


// Debugging (temporär)
string lines[];


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

   // Label erzeugen
   CreateLabels();

   // Prüfen, ob wir auf einem LFX-Chart laufen
   isLfxChart = (StringLeft(Symbol(), 3)=="LFX" || StringRight(Symbol(), 3)=="LFX");

   return(catch("onInit(2)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   RemoveChartObjects();

   // QuickChannel-Sender-Handles schließen
   for (int i=ArraySize(hLfxSenderChannels)-1; i >= 0; i--) {
      if (hLfxSenderChannels[i] != NULL) {
         if (!QC_ReleaseSender(hLfxSenderChannels[i]))
            catch("onDeinit(1)->MT4iQuickChannel::QC_ReleaseSender(hChannel=0x"+ IntToHexStr(hLfxSenderChannels[i]) +")   error closing QuickChannel sender: "+ RtlGetLastWin32Error(), ERR_WIN32_ERROR);
         hLfxSenderChannels[i] = NULL;
      }
   }

   // QuickChannel-Receiver-Handle schließen
   if (hLfxReceiverChannel != NULL) {
      if (!QC_ReleaseReceiver(hLfxReceiverChannel))
         catch("onDeinit(2)->MT4iQuickChannel::QC_ReleaseReceiver(hChannel=0x"+ IntToHexStr(hLfxReceiverChannel) +")   error releasing QuickChannel receiver: "+ RtlGetLastWin32Error(), ERR_WIN32_ERROR);
      hLfxReceiverChannel = NULL;
   }

   return(catch("onDeinit(3)"));
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
   if (!UpdatePositions()   ) return(last_error);
   if (!UpdateStopoutLevel()) return(last_error);
   if (!UpdateOHLC()        ) return(last_error);
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
   label.ohlc         = __NAME__ +"."+ label.ohlc;
   label.price        = __NAME__ +"."+ label.price;
   label.spread       = __NAME__ +"."+ label.spread;
   label.unitSize     = __NAME__ +"."+ label.unitSize;
   label.position     = __NAME__ +"."+ label.position;
   label.time         = __NAME__ +"."+ label.time;
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


   // OHLC-Label
   if (ObjectFind(label.ohlc) == 0)
      ObjectDelete(label.ohlc);
   if (ObjectCreate(label.ohlc, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.ohlc, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label.ohlc, OBJPROP_XDISTANCE, 110);
      ObjectSet    (label.ohlc, OBJPROP_YDISTANCE, 4  );
      ObjectSetText(label.ohlc, " ", 1);
      PushObject   (label.ohlc);
   }
   else GetLastError();


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
bool UpdateUnitSize() {
   if (IsTesting())                                                           // Anzeige wird im Tester nicht benötigt
      return(true);

   // (1) Konfiguration einlesen
   static double leverage;
   static int    soDistance;

   if (!leverage) /*&&*/ if (!soDistance) {
      string sValue, confValue, iniSection="Leverage", iniKey="Pair";
      if (IsGlobalConfigKey(iniSection, iniKey)) {
         confValue = GetGlobalConfigString(iniSection, iniKey, "");
         int n = StringFind(confValue, ";");
         if (n != -1) sValue = StringTrimRight(StringSubstrFix(confValue, 0, n));
         else         sValue = confValue;

         if (StringIsNumeric(sValue)) {
            // (1.1) numerischer Wert des Hebels
            double dValue = StrToDouble(sValue);
            if (dValue < 1)                      return(!catch("UpdateUnitSize(1)   invalid configuration value ["+ iniSection +"] "+ iniKey +" = "+ sValue, ERR_INVALID_CONFIG_PARAMVALUE));
            leverage = dValue;
         }
         else {
            // (1.2) nicht-numerisch, Stopout-Distanz parsen
            sValue = StringToLower(sValue);
            if (!StringStartsWith(sValue, "so")) return(!catch("UpdateUnitSize(2)   invalid configuration value ["+ iniSection +"] "+ iniKey +" = \""+ confValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
            sValue = StringTrimLeft(StringRight(sValue, -2));
            if (!StringStartsWith(sValue, ":"))  return(!catch("UpdateUnitSize(3)   invalid configuration value ["+ iniSection +"] "+ iniKey +" = \""+ confValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
            sValue = StringTrimLeft(StringRight(sValue, -1));
            if (!StringEndsWith(sValue, "p"))    return(!catch("UpdateUnitSize(4)   invalid configuration value ["+ iniSection +"] "+ iniKey +" = \""+ confValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
            sValue = StringTrimRight(StringLeft(sValue, -1));
            if (!StringIsInteger(sValue))        return(!catch("UpdateUnitSize(5)   invalid configuration value ["+ iniSection +"] "+ iniKey +" = \""+ confValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
            int iValue = StrToInteger(sValue);
            if (iValue >= 0)                     return(!catch("UpdateUnitSize(6)   invalid configuration value ["+ iniSection +"] "+ iniKey +" = \""+ confValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
            soDistance = -iValue;
         }
      }
      else {
         leverage = -1;
      }
   }


   // (2) Anzeige berechnen
   string strUnitSize = "UnitSize:  -";

   if (leverage > 0 || soDistance) {
      bool   tradeAllowed   = _bool(MarketInfo(Symbol(), MODE_TRADEALLOWED ));
      double tickSize       =       MarketInfo(Symbol(), MODE_TICKSIZE      );
      double tickValue      =       MarketInfo(Symbol(), MODE_TICKVALUE     );
      double marginRequired =       MarketInfo(Symbol(), MODE_MARGINREQUIRED); if (marginRequired == -92233720368547760.) marginRequired = 0;

      int error = GetLastError();
      if (IsError(error)) {
         if (error == ERR_UNKNOWN_SYMBOL)
            return(true);
         return(!catch("UpdateUnitSize(7)", error));
      }

      if (tradeAllowed) {                                                     // bei Start oder Accountwechsel können Werte noch ungesetzt sein
         double unitSize, equity=MathMin(AccountBalance(), AccountEquity()-AccountCredit());

         if (tickSize && tickValue && marginRequired && equity > 0) {
            double lotValue = Close[0]/tickSize * tickValue;                  // Lotvalue eines Lots in Account-Currency
            int iLeverage;

            if (leverage > 0) {
               // (2.1) Hebel angegeben
               unitSize  = equity / lotValue * leverage;                      // Equity wird mit 'leverage' gehebelt (equity/lotValue entspricht Hebel 1)
               iLeverage = MathRound(leverage);
            }
            else /*(soDistance > 0)*/ {
               // (2.2) Stopout-Distanz in Pip angegeben
               double pointValue = tickValue/(tickSize/Point);
               double pipValue   = PipPoints * pointValue;                    // Pipvalue eines Lots in Account-Currency
               unitSize  = equity / (marginRequired + soDistance*pipValue);
               iLeverage = MathRound(unitSize * lotValue / equity);           // effektiver Hebel dieser UnitSize
            }

            // (2.3) UnitSize immer ab-, niemals aufrunden                                                                                      Abstufung max. 6.7% je Schritt
            if      (unitSize <=    0.03) unitSize = NormalizeDouble(MathFloor(unitSize/  0.001) *   0.001, 3);   //     0-0.03: Vielfaches von   0.001
            else if (unitSize <=   0.075) unitSize = NormalizeDouble(MathFloor(unitSize/  0.002) *   0.002, 3);   // 0.03-0.075: Vielfaches von   0.002
            else if (unitSize <=    0.1 ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.005) *   0.005, 3);   //  0.075-0.1: Vielfaches von   0.005
            else if (unitSize <=    0.3 ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.01 ) *   0.01 , 2);   //    0.1-0.3: Vielfaches von   0.01
            else if (unitSize <=    0.75) unitSize = NormalizeDouble(MathFloor(unitSize/  0.02 ) *   0.02 , 2);   //   0.3-0.75: Vielfaches von   0.02
            else if (unitSize <=    1.2 ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.05 ) *   0.05 , 2);   //   0.75-1.2: Vielfaches von   0.05
            else if (unitSize <=    3.  ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.1  ) *   0.1  , 1);   //      1.2-3: Vielfaches von   0.1
            else if (unitSize <=    7.5 ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.2  ) *   0.2  , 1);   //      3-7.5: Vielfaches von   0.2
            else if (unitSize <=   12.  ) unitSize = NormalizeDouble(MathFloor(unitSize/  0.5  ) *   0.5  , 1);   //     7.5-12: Vielfaches von   0.5
            else if (unitSize <=   30.  ) unitSize = MathRound      (MathFloor(unitSize/  1    ) *   1       );   //      12-30: Vielfaches von   1
            else if (unitSize <=   75.  ) unitSize = MathRound      (MathFloor(unitSize/  2    ) *   2       );   //      30-75: Vielfaches von   2
            else if (unitSize <=  120.  ) unitSize = MathRound      (MathFloor(unitSize/  5    ) *   5       );   //     75-120: Vielfaches von   5
            else if (unitSize <=  300.  ) unitSize = MathRound      (MathFloor(unitSize/ 10    ) *  10       );   //    120-300: Vielfaches von  10
            else if (unitSize <=  750.  ) unitSize = MathRound      (MathFloor(unitSize/ 20    ) *  20       );   //    300-750: Vielfaches von  20
            else if (unitSize <= 1200.  ) unitSize = MathRound      (MathFloor(unitSize/ 50    ) *  50       );   //   750-1200: Vielfaches von  50
            else                          unitSize = MathRound      (MathFloor(unitSize/100    ) * 100       );   //   1200-...: Vielfaches von 100

            strUnitSize = StringConcatenate("UnitSize:  ", NumberToStr(unitSize, ", .+"), " lot");
            strUnitSize = StringConcatenate("(1:", iLeverage, ")    ", strUnitSize);
         }
      }
   }


   // (3) Anzeige setzen
   ObjectSetText(label.unitSize, strUnitSize, 9, "Tahoma", SlateGray);

   error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)           // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateUnitSize(8)", error));
   return(true);
}


/**
 * Aktualisiert die Positionsanzeigen: Gesamtposition unten rechts, Einzelpositionen unten links.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdatePositions() {
   if (!positionsAnalyzed) /*&&*/ if (!AnalyzePositions())
      return(false);


   // (1) Gesamtpositionsanzeige unten rechts
   string strPosition;
   if      (!isPosition   ) strPosition = " ";
   else if (!totalPosition) strPosition = StringConcatenate("Position:  ±", NumberToStr(longPosition, ", .+"), " lot (hedged)");
   else                     strPosition = StringConcatenate("Position:  " , NumberToStr(totalPosition, "+, .+"), " lot");
   ObjectSetText(label.position, strPosition, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdatePositions(1)", error));


   // (2) Einzelpositionsanzeige unten links: ggf. mit Breakeven und Profit/Loss
   // Spalten:            Direction:, LotSize, BE:, BePrice, Profit:, ProfitAmount
   int col.xShifts[]   = {20,         59,      135, 160,     236,     268}, cols=ArraySize(col.xShifts), yDist=3;
   int localPositions  = ArrayRange(local.position.types,  0);
   int remotePositions = ArrayRange(remote.position.types, 0);
   int positions       = localPositions + remotePositions;

   // (2.1) ggf. weitere Zeilen hinzufügen
   static int lines;
   while (lines < positions) {
      lines++;
      for (int col=0; col < cols; col++) {
         string label = label.position +".line"+ lines +"_col"+ col;
         if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
            ObjectSet    (label, OBJPROP_CORNER, CORNER_BOTTOM_LEFT);
            ObjectSet    (label, OBJPROP_XDISTANCE, col.xShifts[col]              );
            ObjectSet    (label, OBJPROP_YDISTANCE, yDist + (lines-1)*(positions.fontSize+8));
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

   // (2.3) Zeilen von unten nach oben schreiben: "{Type}: {LotSize}   BE|Dist: {BePrice}   Profit: {ProfitAmount}"
   string strLotSize, strTypes[]={"", "Long:", "Short:", "Hedge:"};  // DirectionTypes (1, 2, 3) werden als Indizes benutzt
   int line;

   for (int i=localPositions-1; i >= 0; i--) {
      line++;
      if (local.position.types[i][1] == TYPE_HEDGE) {
         ObjectSetText(label.position +".line"+ line +"_col0",    strTypes[local.position.types[i][1]],                                                                  positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col1", NumberToStr(local.position.data [i][I_HEDGEDLOTSIZE], ".+") +" lot",                                      positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col2", "Dist:",                                                                                                  positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            if (!local.position.data[i][I_BREAKEVEN])
         ObjectSetText(label.position +".line"+ line +"_col3", "...",                                                                                                    positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            else
         ObjectSetText(label.position +".line"+ line +"_col3", DoubleToStr(RoundFloor(local.position.data[i][I_BREAKEVEN], Digits-PipDigits), Digits-PipDigits) +" pip", positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col4", "Profit:",                                                                                                positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            if (!local.position.data[i][I_PROFIT])
         ObjectSetText(label.position +".line"+ line +"_col5", "...",                                                                                                    positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            else
         ObjectSetText(label.position +".line"+ line +"_col5", DoubleToStr(local.position.data[i][I_PROFIT], 2),                                                         positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
      }
      else {
         ObjectSetText(label.position +".line"+ line +"_col0",            strTypes[local.position.types[i][1]],                                                          positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            if (!local.position.data[i][I_HEDGEDLOTSIZE]) strLotSize = NumberToStr(local.position.data [i][I_DIRECTLOTSIZE], ".+");
            else                                          strLotSize = NumberToStr(local.position.data [i][I_DIRECTLOTSIZE], ".+") +" ±"+ NumberToStr(local.position.data[i][I_HEDGEDLOTSIZE], ".+");
         ObjectSetText(label.position +".line"+ line +"_col1", strLotSize +" lot",                                                                                       positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col2", "BE:",                                                                                                    positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            if (!local.position.data[i][I_BREAKEVEN])
         ObjectSetText(label.position +".line"+ line +"_col3", "...",                                                                                                    positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            else if (local.position.types[i][1] == TYPE_LONG)
         ObjectSetText(label.position +".line"+ line +"_col3", NumberToStr(RoundCeil (local.position.data[i][I_BREAKEVEN], Digits), PriceFormat),                        positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
            else
         ObjectSetText(label.position +".line"+ line +"_col3", NumberToStr(RoundFloor(local.position.data[i][I_BREAKEVEN], Digits), PriceFormat),                        positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col4", "Profit:",                                                                                                positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col5",            DoubleToStr(local.position.data[i][I_PROFIT], 2),                                              positions.fontSize, positions.fontName, positions.fontColors[local.position.types[i][0]]);
      }
   }

   for (i=remotePositions-1; i >= 0; i--) {
      line++;
      if (remote.position.types[i][1] == TYPE_HEDGE) {
      }
      else {
         ObjectSetText(label.position +".line"+ line +"_col0",    strTypes[remote.position.types[i][1]],                                                                 positions.fontSize, positions.fontName, positions.fontColors[remote.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col1", NumberToStr(remote.position.data [i][I_DIRECTLOTSIZE], ".+") +" units",                                   positions.fontSize, positions.fontName, positions.fontColors[remote.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col2", "BE:",                                                                                                    positions.fontSize, positions.fontName, positions.fontColors[remote.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col3", "...",                                                                                                    positions.fontSize, positions.fontName, positions.fontColors[remote.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col4", "Profit:",                                                                                                positions.fontSize, positions.fontName, positions.fontColors[remote.position.types[i][0]]);
         ObjectSetText(label.position +".line"+ line +"_col5",  DoubleToStr(remote.position.data[i][I_PROFIT], 2),                                                       positions.fontSize, positions.fontName, positions.fontColors[remote.position.types[i][0]]);
      }
   }
   return(!catch("UpdatePositions(2)"));
}


/**
 * Aktualisiert die Anzeige des aktuellen Stopout-Levels.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateStopoutLevel() {
   if (!positionsAnalyzed) /*&&*/ if (!AnalyzePositions())
      return(false);

   if (!totalPosition) {                                                               // keine Position im Markt: vorhandene Marker löschen
      ObjectDelete(label.stopoutLevel);
      int error = GetLastError();
      if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)                 // bei offenem Properties-Dialog oder Object::onDrag()
         return(!catch("UpdateStopoutLevel(1)", error));
      return(true);
   }


   // (1) Stopout-Preis berechnen
   double equity     = AccountEquity();
   double usedMargin = AccountMargin();
   int    soMode     = AccountStopoutMode();
   double soEquity   = AccountStopoutLevel(); if (soMode != ASM_ABSOLUTE) soEquity /= (100/usedMargin);
   double tickSize   = MarketInfo(Symbol(), MODE_TICKSIZE );
   double tickValue  = MarketInfo(Symbol(), MODE_TICKVALUE) * MathAbs(totalPosition);  // TickValue der aktuellen Position
      if (!tickSize || !tickValue)
         return(!SetLastError(ERR_UNKNOWN_SYMBOL));                                    // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
   double soDistance = (equity - soEquity)/tickValue * tickSize;
   double soPrice;
   if (totalPosition > 0) soPrice = NormalizeDouble(Bid - soDistance, Digits);
   else                   soPrice = NormalizeDouble(Ask + soDistance, Digits);


   // (2) Stopout-Preis anzeigen
   if (ObjectFind(label.stopoutLevel) == -1) {
      ObjectCreate (label.stopoutLevel, OBJ_HLINE, 0, 0, 0);
      ObjectSet    (label.stopoutLevel, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet    (label.stopoutLevel, OBJPROP_COLOR, OrangeRed);
      ObjectSet    (label.stopoutLevel, OBJPROP_BACK , true);
         if (soMode == ASM_PERCENT) string description = StringConcatenate("Stopout  ", Round(AccountStopoutLevel()), "%");
         else                              description = StringConcatenate("Stopout  ", DoubleToStr(soEquity, 2), AccountCurrency());
      ObjectSetText(label.stopoutLevel, description);
      PushObject   (label.stopoutLevel);
   }
   ObjectSet(label.stopoutLevel, OBJPROP_PRICE1, soPrice);


   error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)                    // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateStopoutLevel(2)", error));
   return(true);
}


/**
 * Aktualisiert die OHLC-Anzeige (trotz des 'C' im Funktionsnamen wird der Close-Preis nicht ein weiteres mal angezeigt).
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateOHLC() {
   // TODO: noch nicht zufriedenstellend implementiert
   return(true);


   // (1) Zeit des letzten Ticks holen
   datetime lastTickTime = MarketInfo(Symbol(), MODE_TIME);
   if (!lastTickTime) {                                                          // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
      if (!SetLastError(GetLastError()))
         SetLastError(ERR_UNKNOWN_SYMBOL);
      return(false);
   }


   // (2) Beginn und Ende der aktuellen Session ermitteln
   datetime sessionStart = GetServerSessionStartTime(lastTickTime);              // throws ERR_MARKET_CLOSED
   if (sessionStart == -1) {
      if (SetLastError(stdlib_GetLastError()) != ERR_MARKET_CLOSED)              // am Wochenende die letzte Session verwenden
         return(false);
      sessionStart = GetServerPrevSessionStartTime(lastTickTime);
   }
   datetime sessionEnd = sessionStart + 1*DAY;


   // (3) Baroffsets von Sessionbeginn und -ende ermitteln
   int openBar = iBarShiftNext(NULL, NULL, sessionStart);
      if (openBar == EMPTY_VALUE) return(!SetLastError(stdlib_GetLastError()));  // Fehler
      if (openBar ==          -1) return(true);                                  // sessionStart ist zu jung für den Chart
   int closeBar = iBarShiftPrevious(NULL, NULL, sessionEnd);
      if (closeBar == EMPTY_VALUE) return(!SetLastError(stdlib_GetLastError())); // Fehler
      if (closeBar ==          -1) return(true);                                 // sessionEnd ist zu alt für den Chart
   if (openBar < closeBar)
      return(!catch("UpdateOHLC(1)   illegal open/close bar offsets for session from="+ DateToStr(sessionStart, "w D.M.Y H:I") +" (bar="+ openBar +")  to="+ DateToStr(sessionEnd, "w D.M.Y H:I") +" (bar="+ closeBar +")", ERR_RUNTIME_ERROR));


   // (4) Baroffsets von Session-High und -Low ermitteln
   int highBar = iHighest(NULL, NULL, MODE_HIGH, openBar-closeBar+1, closeBar);
   int lowBar  = iLowest (NULL, NULL, MODE_LOW , openBar-closeBar+1, closeBar);


   // (5) Anzeige aktualisieren
   string strOHLC = "O="+ NumberToStr(Open[openBar], PriceFormat) +"   H="+ NumberToStr(High[highBar], PriceFormat) +"   L="+ NumberToStr(Low[lowBar], PriceFormat);
   ObjectSetText(label.ohlc, strOHLC, 8, "", Black);


   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)           // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateOHLC(2)", error));
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
   int sortKeys[][2];                                                // Sortierschlüssel der offenen Positionen: {OpenTime, Ticket}
   ArrayResize(sortKeys, orders);

   int pos, lfxMagics []={0}; ArrayResize(lfxMagics , 1);            // Die Arrays für die P/L-daten detektierter LFX-Positionen werden mit Größe 1 initialisiert.
   double   lfxProfits[]={0}; ArrayResize(lfxProfits, 1);            // So sparen wir den ständigen Test auf einen ungültigen Index bei Arraygröße 0.


   // (1) Gesamtposition ermitteln
   for (int n, i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;        // FALSE: während des Auslesens wurde woanders ein offenes Ticket entfernt
      if (OrderType() > OP_SELL) continue;
      if (LFX.IsMyOrder()) {                                         // dabei P/L-Daten detektierter LFX-Positionen aufaddieren
         if (lfxMagics[pos] != OrderMagicNumber()) {
            pos = SearchMagicNumber(lfxMagics, OrderMagicNumber());
            if (pos == -1)
               pos = ArrayResize(lfxProfits, ArrayPushInt(lfxMagics, OrderMagicNumber()))-1;
         }
         lfxProfits[pos] += OrderCommission() + OrderSwap() + OrderProfit();
      }
      if (OrderSymbol() != Symbol()) continue;

      if (OrderType() == OP_BUY) longPosition  += OrderLots();       // Gesamtposition aufaddieren
      else                       shortPosition += OrderLots();

      sortKeys[n][0] = OrderOpenTime();                              // Sortierschlüssel der Tickets auslesen
      sortKeys[n][1] = OrderTicket();
      n++;
   }
   if (n < orders) {
      ArrayResize(sortKeys, n);
      orders = n;
   }
   totalPosition = NormalizeDouble(longPosition - shortPosition, 2);
   isPosition    = (longPosition || shortPosition);


   // (2) P/L detektierter LFX-Positionen per QuickChannel an LFX-Terminal schicken (nur, wenn sich der Wert seit der letzten Message geändert hat)
   double lastLfxProfit;
   string lfxMessages[]; ArrayResize(lfxMessages, 0); ArrayResize(lfxMessages, ArraySize(hLfxSenderChannels));    // 2 x ArrayResize() = ArrayInitialize(string array)
   string globalLfxVarName;
   int    error;

   for (i=ArraySize(lfxMagics)-1; i > 0; i--) {                      // Index 0 ist unbenutzt
      // (2.1) prüfen, ob sich der aktuelle vom letzten verschickten Wert unterscheidet
      globalLfxVarName = "LFX.Profit."+ lfxMagics[i];
      lastLfxProfit    = GlobalVariableGet(globalLfxVarName);
      if (!lastLfxProfit) {                                          // 0 oder Fehler
         error = GetLastError();
         if (error!=NO_ERROR) /*&&*/ if (error!=ERR_GLOBAL_VARIABLE_NOT_FOUND)
            return(!catch("AnalyzePositions(1)->GlobalVariableGet()", error));
      }
      if (EQ(lfxProfits[i], lastLfxProfit)) {                        // Wert hat sich nicht geändert
         lfxMagics[i] = NULL;                                        // MagicNo zurücksetzen, um Marker für (2.4) Speichern in globaler Variable zu haben
         continue;
      }

      // (2.2) geänderten Wert zu Messages des entsprechenden Channels hinzufügen (Messages eines Channels werden gemeinsam, nicht einzeln verschickt)
      int cid = LFX.GetCurrencyId(lfxMagics[i]);
      if (!StringLen(lfxMessages[cid])) lfxMessages[cid] = StringConcatenate(                       AccountNumber(), ",", lfxMagics[i], ",", DoubleToStr(lfxProfits[i], 2));
      else                              lfxMessages[cid] = StringConcatenate(lfxMessages[cid], TAB, AccountNumber(), ",", lfxMagics[i], ",", DoubleToStr(lfxProfits[i], 2));
   }

   // (2.3) angesammelte Messages verschicken (Messages je Channel werden gemeinsam, nicht einzeln verschickt)
   for (i=ArraySize(lfxMessages)-1; i > 0; i--) {                    // Index 0 ist unbenutzt
      if (StringLen(lfxMessages[i]) > 0) {
         if (!hLfxSenderChannels[i]) /*&&*/ if (!StartQCSender(i))
            return(false);
         if (!QC_SendMessage(hLfxSenderChannels[i], lfxMessages[i], QC_FLAG_SEND_MSG_IF_RECEIVER))
            return(!catch("AnalyzePositions(2)->MT4iQuickChannel::QC_SendMessage() = QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));
      }
   }

   // (2.4) alle verschickten Werte in globaler Variable speichern
   for (i=ArraySize(lfxMagics)-1; i > 0; i--) {                      // Index 0 ist unbenutzt
      // Marker aus (2.1) verwenden: MagicNumbers unveränderter Werte wurden zurückgesetzt
      if (lfxMagics[i] != 0) {
         globalLfxVarName = "LFX.Profit."+ lfxMagics[i];
         if (!GlobalVariableSet(globalLfxVarName, lfxProfits[i])) {
            error = GetLastError();
            return(!catch("AnalyzePositions(3)->GlobalVariableSet(name=\""+ globalLfxVarName +"\", value="+ lfxProfits[i] +")", ifInt(!error, ERR_RUNTIME_ERROR, error)));
         }
      }
   }


   // (3) Positionsdetails analysieren und in *.position.types[] und *.position.data[] speichern
   if (ArrayRange(local.position.types, 0) > 0) {
      ArrayResize(local.position.types, 0);                          // lokale Positionsdaten werden bei jedem Tick zurückgesetzt und neu eingelesen
      ArrayResize(local.position.data,  0);
   }

   if (isPosition) {
      // (3.1) offene lokale Position, individuelle Konfiguration einlesen (Remote-Positionen werden ignoriert)
      if (ArrayRange(local.position.conf, 0)==0) /*&&*/ if (!ReadLocalPositionConfig()) {
         positionsAnalyzed = !last_error;                            // MarketInfo()-Daten stehen ggf. noch nicht zur Verfügung,
         return(positionsAnalyzed);                                  // in diesem Fall nächster Versuch beim nächsten Tick.
      }

      // (3.2) offene Tickets sortieren und einlesen
      if (orders > 1) /*&&*/ if (!SortTickets(sortKeys))
         return(false);

      int    tickets    [], customTickets    []; ArrayResize(tickets    , orders);
      int    types      [], customTypes      []; ArrayResize(types      , orders);
      double lotSizes   [], customLotSizes   []; ArrayResize(lotSizes   , orders);
      double openPrices [], customOpenPrices []; ArrayResize(openPrices , orders);
      double commissions[], customCommissions[]; ArrayResize(commissions, orders);
      double swaps      [], customSwaps      []; ArrayResize(swaps      , orders);
      double profits    [], customProfits    []; ArrayResize(profits    , orders);

      for (i=0; i < orders; i++) {
         if (!SelectTicket(sortKeys[i][1], "AnalyzePositions(4)"))
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


      // (3.3) individuell konfigurierte Position extrahieren
      int confSize = ArrayRange(local.position.conf, 0);

      for (i=0; i < confSize; i++) {
         lotSize = local.position.conf[i][0];
         ticket  = local.position.conf[i][1];

         if (!i || !ticket) {
            // (3.4) individuell konfigurierte Position speichern
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

      // (3.5) verbleibende Position speichern
      if (!StorePosition.Separate(local.longPosition, local.shortPosition, local.totalPosition, tickets, types, lotSizes, openPrices, commissions, swaps, profits))
         return(false);
   }

   // (3.6) keine lokalen Positionen
   else if (isLfxChart) {
      // per QuickChannel eingehende Remote-Positionsdetails auswerten
      if (!hLfxReceiverChannel) /*&&*/ if (!StartQCReceiver())
         return(false);

      int result = QC_CheckChannel(lfxReceiverChannelName);
      if (result > QC_CHECK_CHANNEL_EMPTY) {
         result = QC_GetMessages3(hLfxReceiverChannel, lfxReceiverChannelBuffer, QC_MAX_BUFFER_SIZE);
         if (result != QC_GET_MSG3_SUCCESS) {
            if (result == QC_GET_MSG3_CHANNEL_EMPTY) return(!catch("AnalyzePositions(5)->MT4iQuickChannel::QC_GetMessages3()   QC_CheckChannel not empty/QC_GET_MSG3_CHANNEL_EMPTY mismatch error",     ERR_WIN32_ERROR));
            if (result == QC_GET_MSG3_INSUF_BUFFER ) return(!catch("AnalyzePositions(6)->MT4iQuickChannel::QC_GetMessages3()   buffer to small (QC_MAX_BUFFER_SIZE/QC_GET_MSG3_INSUF_BUFFER mismatch)", ERR_WIN32_ERROR));
                                                     return(!catch("AnalyzePositions(7)->MT4iQuickChannel::QC_GetMessages3() = unexpected return value: "+ result,                                      ERR_WIN32_ERROR));
         }
         string values = lfxReceiverChannelBuffer[0];
         int lenValues = StringLen(values);
         i = 0; pos = 0;

         while (i < lenValues) {
            pos = StringFind(values, TAB, i);
            if (pos == -1) {                                         // kein weiterer Separator
               if (!StorePosition.QC_Message(StringSubstr(values, i)))
                  return(false);
               ArrayUnshiftString(lines, StringSubstr(values, i));
               break;
            }
            else if (pos != i) {                                     // Separator-Value-Separator
               if (!StorePosition.QC_Message(StringSubstr(values, i, pos-i)))
                  return(false);
               ArrayUnshiftString(lines, StringSubstr(values, i, pos-i));
            }
            i = pos + 1;
         }                                                           // aufeinanderfolgende (pos == i) und abschließende Separatoren (i == lenValues) werden ignoriert
      }
      else if (result < QC_CHECK_CHANNEL_EMPTY) {
         if (result == QC_CHECK_CHANNEL_ERROR) return(!catch("AnalyzePositions(8)->MT4iQuickChannel::QC_CheckChannel(name=\""+ lfxReceiverChannelName +"\") = QC_CHECK_CHANNEL_ERROR",            ERR_WIN32_ERROR));
         if (result == QC_CHECK_CHANNEL_NONE ) return(!catch("AnalyzePositions(9)->MT4iQuickChannel::QC_CheckChannel(name=\""+ lfxReceiverChannelName +"\") doesn't exist",                       ERR_WIN32_ERROR));
                                               return(!catch("AnalyzePositions(10)->MT4iQuickChannel::QC_CheckChannel(name=\""+ lfxReceiverChannelName +"\") = unexpected return value: "+ result, ERR_WIN32_ERROR));
      }

      if (ArraySize(lines) > 40)
         ArrayResize(lines, 40);
      Comment(NL, __NAME__, ":  \"", lfxReceiverChannelName, "\"", NL, NL, JoinStrings(lines, NL));
   }

   positionsAnalyzed = true;
   return(!catch("AnalyzePositions(11)"));
}


/**
 * Durchsucht das übergebene Integer-Array nach der angegebenen MagicNumber. Schnellerer Ersatz für SearchIntArray(int haystack[], int needle),
 * da kein Library-Aufruf.
 *
 * @param  int array[] - zu durchsuchendes Array
 * @param  int number  - zu suchende MagicNumber
 *
 * @return int - Index der MagicNumber oder -1, wenn der Wert nicht im Array enthalten ist
 */
int SearchMagicNumber(int array[], int number) {
   int size = ArraySize(array);
   for (int i=0; i < size; i++) {
      if (array[i] == number)
         return(i);
   }
   return(-1);
}


/**
 * Liest die individuell konfigurierten lokalen Positionsdaten neu ein.
 *
 * @return bool - Erfolgsstatus
 */
bool ReadLocalPositionConfig() {
   if (ArrayRange(local.position.conf, 0) > 0)
      ArrayResize(local.position.conf, 0);

   string keys[], values[], value, details[], strLotSize, strTicket, sNull, section="BreakevenCalculation", stdSymbol=StdSymbol();
   double lotSize, minLotSize=MarketInfo(Symbol(), MODE_MINLOT), lotStep=MarketInfo(Symbol(), MODE_LOTSTEP);
   int    valuesSize, detailsSize, confSize, m, n, ticket;
   if (!minLotSize) return(false);                                   // falls MarketInfo()-Daten noch nicht verfügbar sind
   if (!lotStep   ) return(false);

   int keysSize = GetIniKeys(GetLocalConfigPath(), section, keys);

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
                  else return(!catch("ReadLocalPositionConfig(3)   illegal configuration \""+ section +"\": "+ keys[i] +"=\""+ value +"\" in \""+ GetLocalConfigPath() +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
               }
               details[0] =               StringTrim(details[0]);  strLotSize = details[0];
               details[1] = StringToUpper(StringTrim(details[1])); strTicket  = details[1];

               // Lotsize validieren
               lotSize = 0;
               if (StringLen(strLotSize) > 0) {
                  if (!StringIsNumeric(strLotSize))      return(!catch("ReadLocalPositionConfig(4)   illegal configuration \""+ section +"\": "+ keys[i] +"=\""+ value +"\" in \""+ GetLocalConfigPath() +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  lotSize = StrToDouble(strLotSize);
                  if (LT(lotSize, minLotSize))           return(!catch("ReadLocalPositionConfig(5)   illegal configuration \""+ section +"\": "+ keys[i] +"=\""+ value +"\" in \""+ GetLocalConfigPath() +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  if (MathModFix(lotSize, lotStep) != 0) return(!catch("ReadLocalPositionConfig(6)   illegal configuration \""+ section +"\": "+ keys[i] +"=\""+ value +"\" in \""+ GetLocalConfigPath() +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
               }

               // Ticket validieren
               if (StringIsDigit(strTicket)) ticket = StrToInteger(strTicket);
               else if (strTicket == "L")    ticket = TYPE_LONG;
               else if (strTicket == "S")    ticket = TYPE_SHORT;
               else return(!catch("ReadLocalPositionConfig(7)   illegal configuration \""+ section +"\": "+ keys[i] +"=\""+ value +"\" in \""+ GetLocalConfigPath() +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

               // Virtuelle Positionen müssen an erster Stelle notiert sein
               if (m && lotSize && ticket<=TYPE_SHORT) return(!catch("ReadLocalPositionConfig(8)   illegal configuration, virtual positions must be noted first in \""+ section +"\": "+ keys[i] +"=\""+ value +"\" in \""+ GetLocalConfigPath() +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

               confSize = ArrayRange(local.position.conf, 0);
               ArrayResize(local.position.conf, confSize+1);
               local.position.conf[confSize][0] = lotSize;
               local.position.conf[confSize][1] = ticket;
               m++;
            }
            if (m > 0) {
               confSize = ArrayRange(local.position.conf, 0);
               ArrayResize(local.position.conf, confSize+1);
               local.position.conf[confSize][0] = NULL;
               local.position.conf[confSize][1] = NULL;
            }
         }
      }
   }
   confSize = ArrayRange(local.position.conf, 0);
   if (!confSize) {
      ArrayResize(local.position.conf, 1);
      local.position.conf[confSize][0] = NULL;
      local.position.conf[confSize][1] = NULL;
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
         size = ArrayRange(local.position.types, 0);
         ArrayResize(local.position.types, size+1);
         ArrayResize(local.position.data,  size+1);

         local.position.types[size][0]               = TYPE_CUSTOM + isVirtual;
         local.position.types[size][1]               = TYPE_HEDGE;
         local.position.data [size][I_DIRECTLOTSIZE] = 0;
         local.position.data [size][I_HEDGEDLOTSIZE] = hedgedLotSize;
         local.position.data [size][I_BREAKEVEN    ] = pipDistance;
         local.position.data [size][I_PROFIT       ] = hedgedProfit;
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
      size = ArrayRange(local.position.types, 0);
      ArrayResize(local.position.types, size+1);
      ArrayResize(local.position.data,  size+1);

      local.position.types[size][0]               = TYPE_CUSTOM + isVirtual;
      local.position.types[size][1]               = TYPE_LONG;
      local.position.data [size][I_DIRECTLOTSIZE] = totalPosition;
      local.position.data [size][I_HEDGEDLOTSIZE] = hedgedLotSize;
         pipValue = PipValue(totalPosition, true);                   // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      local.position.data [size][I_BREAKEVEN    ] = openPrice/totalPosition - (hedgedProfit + commission + swap)/pipValue*Pips;
      local.position.data [size][I_PROFIT       ] = hedgedProfit + commission + swap + profit;
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
      size = ArrayRange(local.position.types, 0);
      ArrayResize(local.position.types, size+1);
      ArrayResize(local.position.data,  size+1);

      local.position.types[size][0]               = TYPE_CUSTOM + isVirtual;
      local.position.types[size][1]               = TYPE_SHORT;
      local.position.data [size][I_DIRECTLOTSIZE] = -totalPosition;
      local.position.data [size][I_HEDGEDLOTSIZE] = hedgedLotSize;
         pipValue = PipValue(-totalPosition, true);                  // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      local.position.data [size][I_BREAKEVEN    ] = (hedgedProfit + commission + swap)/pipValue*Pips - openPrice/totalPosition;
      local.position.data [size][I_PROFIT       ] =  hedgedProfit + commission + swap + profit;
   }

   return(!catch("StorePosition.Consolidate(6)"));
}


/**
 * Speichert die übergebenen Teilpositionen getrennt nach Long/Short/Hedge in den globalen Variablen local.position.types[] und local.position.data[].
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
      int size = ArrayRange(local.position.types, 0);
      ArrayResize(local.position.types, size+1);
      ArrayResize(local.position.data,  size+1);

      local.position.types[size][0]               = TYPE_DEFAULT;
      local.position.types[size][1]               = TYPE_LONG;
      local.position.data [size][I_DIRECTLOTSIZE] = totalPosition;
      local.position.data [size][I_HEDGEDLOTSIZE] = 0;
         pipValue = PipValue(totalPosition, true);                   // TRUE = Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      local.position.data [size][I_BREAKEVEN    ] = openPrice/totalPosition - (commission+swap)/pipValue*Pips;
      local.position.data [size][I_PROFIT       ] = commission + swap + profit;
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
      size = ArrayRange(local.position.types, 0);
      ArrayResize(local.position.types, size+1);
      ArrayResize(local.position.data,  size+1);

      local.position.types[size][0]               = TYPE_DEFAULT;
      local.position.types[size][1]               = TYPE_SHORT;
      local.position.data [size][I_DIRECTLOTSIZE] = -totalPosition;
      local.position.data [size][I_HEDGEDLOTSIZE] = 0;
         pipValue = PipValue(-totalPosition, true);                  // TRUE = Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      local.position.data [size][I_BREAKEVEN    ] = (commission+swap)/pipValue*Pips - openPrice/totalPosition;
      local.position.data [size][I_PROFIT       ] = commission + swap + profit;
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
      size = ArrayRange(local.position.types, 0);
      ArrayResize(local.position.types, size+1);
      ArrayResize(local.position.data,  size+1);

      local.position.types[size][0]               = TYPE_DEFAULT;
      local.position.types[size][1]               = TYPE_HEDGE;
      local.position.data [size][I_DIRECTLOTSIZE] = 0;
      local.position.data [size][I_HEDGEDLOTSIZE] = hedgedLotSize;
         pipValue = PipValue(hedgedLotSize, true);                   // TRUE = Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      local.position.data [size][I_BREAKEVEN    ] = (closePrice-openPrice)/hedgedLotSize/Pips + (commission+swap)/pipValue;
      local.position.data [size][I_PROFIT       ] = local.position.data[size][I_BREAKEVEN] * pipValue;
   }

   return(!catch("StorePosition.Separate(5)"));
}


/**
 * Speichert die in der übergebenen QuickChannel-Message enthaltenen Positionsdetails in den globalen Variablen remote.position.types[] und remote.position.data[].
 *
 * @param  string message - QuickChannel-Message, Format: "iAccountNumber,iMagicNumber,dProfit"
 *
 * @return bool - Erfolgsstatus
 */
bool StorePosition.QC_Message(string message) {
   // NOTE: Anstatt die Message mit Explode() zu zerlegen, wird sie zur Beschleunigung manuell geparst.

   // AccountNumber
   int from=0, to=StringFind(message, ",");                         if (to <= from)   return(!catch("StorePosition.QC_Message(1)   illegal parameter message=\""+ message +"\"", ERR_INVALID_FUNCTION_PARAMVALUE));
   int account = StrToInteger(StringSubstr(message, from, to));     if (account <= 0) return(!catch("StorePosition.QC_Message(2)   illegal parameter message=\""+ message +"\"", ERR_INVALID_FUNCTION_PARAMVALUE));

   // MagicNumber, übernimmt die Funktion eines eindeutigen Tickets für die gesamte Position
   from = to+1; to = StringFind(message, ",", from);                if (to <= from)   return(!catch("StorePosition.QC_Message(3)   illegal parameter message=\""+ message +"\"", ERR_INVALID_FUNCTION_PARAMVALUE));
   int ticket = StrToInteger(StringSubstr(message, from, to-from)); if (ticket <= 0)  return(!catch("StorePosition.QC_Message(4)   illegal parameter message=\""+ message +"\"", ERR_INVALID_FUNCTION_PARAMVALUE));

   // aktueller P/L-Value
   from = to+1; to = StringFind(message, ",", from);                if (to != -1)     return(!catch("StorePosition.QC_Message(5)   illegal parameter message=\""+ message +"\"", ERR_INVALID_FUNCTION_PARAMVALUE));
   double profit = StrToDouble(StringSubstr(message, from));

   // Ticket in vorhandenen Remote-Positionen suchen
   int pos = SearchMagicNumber(remote.position.tickets, ticket);
   if (pos == -1) {
      // bei Mißerfolg Positionsdetails aus "remote_positions.ini" auslesen
      int    orderType, iNull;
      double orderUnits, dNull;
      string sNull = "";

      if (!ReadLfxRemotePosition(account, ticket, iNull, orderType, dNull, orderUnits, dNull, dNull, sNull))
         return(false);

      // Positionsdetails zu Remote-Positionen hinzufügen
      pos = ArraySize(remote.position.tickets);
      ArrayResize(remote.position.tickets, pos+1);
      ArrayResize(remote.position.types,   pos+1);
      ArrayResize(remote.position.data,    pos+1);

      remote.position.tickets[pos]                  = ticket;
      remote.position.types  [pos][0]               = TYPE_DEFAULT;
      remote.position.types  [pos][1]               = orderType;
      remote.position.data   [pos][I_DIRECTLOTSIZE] = LFX.GetUnits(ticket);
      remote.position.data   [pos][I_HEDGEDLOTSIZE] = 0;
      remote.position.data   [pos][I_BREAKEVEN    ] = 0;
   }
   // P/L aktualisieren
   remote.position.data      [pos][I_PROFIT       ] = profit;

   return(true);
}


/**
 * Liest die Orderdetails der angegebenen LFX-Remote-Position in die übergebenen Variablen ein.
 *
 * @param  int       account     - AccountNumber der einzulesenden Position
 * @param  int       magicNumber - MagicNumber der einzulesenden Position
 * @param  datetime &openTime    - Variable zur Aufnahme der OrderOpenTime
 * @param  int      &orderType   - Variable zur Aufnahme des OrderTypes
 * @param  double   &orderLots   - Variable zur Aufnahme der OrderLotsize
 * @param  double   &orderUnits  - Variable zur Aufnahme der OrderUnits
 * @param  double   &openPrice   - Variable zur Aufnahme des OrderOpenPrice
 * @param  double   &orderProfit - Variable zur Aufnahme des OrderProfits
 * @param  string   &comment     - Variable zur Aufnahme des OrderComments
 *
 * @return bool - Erfolgsstatus
 */
bool ReadLfxRemotePosition(int account, int magicNumber, datetime &openTime, int &orderType, double &orderLots, double &orderUnits, double &openPrice, double &orderProfit, string &comment) {
   return(true);
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
 * Startet für die LFX-Währung mit der angegebenen ID einen QuickChannel-Sender.
 *
 * @param  int cid - Currency-ID
 *
 * @return bool - Erfolgsstatus
 */
bool StartQCSender(int cid) {
   if (cid < 1 || cid >= ArraySize(hLfxSenderChannels))
      return(!catch("StartQCSender(1)   illegal parameter cid = "+ cid, ERR_INVALID_FUNCTION_PARAMVALUE));

   if (!hLfxSenderChannels[cid]) {
      hLfxSenderChannels[cid] = QC_StartSender(channels.lfxProfit[cid]);
      if (!hLfxSenderChannels[cid])
         return(!catch("StartQCSender(2)->MT4iQuickChannel::QC_StartSender(channelName=\""+ channels.lfxProfit[cid] +"\")   error ="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));
   }
   return(true);
}


/**
 * Startet für die LFX-Währung des aktuellen Charts einen QuickChannel-Receiver.
 *
 * @return bool - Erfolgsstatus
 */
bool StartQCReceiver() {
   if (hLfxReceiverChannel != NULL) return(true);
   if (!IsChart)                    return(false);

   // LFX-ChannelName des aktuellen Charts ermitteln
   if      (StringLeft (Symbol(), 3) == "LFX") lfxReceiverChannelName = channels.lfxProfit[GetCurrencyId(StringRight(Symbol(), -3))];
   else if (StringRight(Symbol(), 3) == "LFX") lfxReceiverChannelName = channels.lfxProfit[GetCurrencyId(StringLeft (Symbol(), -3))];
   else return(false);                                               // kein LFX-Chart

   int hChartWnd = WindowHandle(Symbol(), NULL);
   if (!hChartWnd)
      return(_false(debug("StartQCReceiver(1)->WindowHandle() = 0   _whereami="+ __whereamiToStr(__WHEREAMI__))));

   hLfxReceiverChannel = QC_StartReceiver(lfxReceiverChannelName, hChartWnd);
   if (!hLfxReceiverChannel)
      return(!catch("StartQCReceiver(2)->MT4iQuickChannel::QC_StartReceiver(channelName=\""+ lfxReceiverChannelName +"\", hChartWnd=0x"+ IntToHexStr(hChartWnd) +")   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));

   InitializeStringBuffer(lfxReceiverChannelBuffer, QC_MAX_BUFFER_SIZE);
   return(true);
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
