/**
 * Zeigt im Chart verschiedene Informationen an:
 *
 * - oben links:     der Name des Instruments
 * - oben rechts:    der aktuelle Kurs: (Bid+Ask) / 2
 * - unter dem Kurs: der Spread
 * - unten rechts:   der Schlußkurs der letzten H1-Bar, wenn das Chartsymbol in Last.H1.Close.Symbols aufgeführt ist
 * - unten Mitte:    die Größe einer Handels-Unit
 * - unten Mitte:    die im Moment gehaltene Position
 */
#include <stdlib.mqh>


#property indicator_chart_window


bool init       = false;
int  init_error = NO_ERROR;


////////////////////////////////////////////////////////////////// User Variablen ////////////////////////////////////////////////////////////////

extern bool   Spread.Including.Commission = false;       // ob der Spread inklusive Commission angezeigt werden soll
extern string Last.H1.Close.Symbols       = "";          // Symbole, für die der Schlußkurs der letzten H1-Bar angezeigt werden soll

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string instrumentLabel, priceLabel, h1CloseLabel, spreadLabel, unitSizeLabel, positionLabel, freezeLevelLabel, stopoutLevelLabel;
string labels[];

bool lastH1Close, position.Checked;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true;
   init_error = NO_ERROR;

   // ERR_TERMINAL_NOT_YET_READY abfangen
   if (!GetAccountNumber()) {
      init_error = stdlib_GetLastError();
      return(init_error);
   }

   // DataBox-Anzeige ausschalten
   SetIndexLabel(0, NULL);

   // Konfiguration auswerten
   lastH1Close = StringIContains(","+ StringTrim(Last.H1.Close.Symbols) +",", ","+ FindNormalizedSymbol(Symbol(), Symbol()) +",");

   // Label definieren und erzeugen
   string indicatorName = WindowExpertName();
   instrumentLabel   = StringConcatenate(indicatorName, ".Instrument"        );
   priceLabel        = StringConcatenate(indicatorName, ".Price"             );
   h1CloseLabel      = StringConcatenate(indicatorName, ".H1-Close"          );
   spreadLabel       = StringConcatenate(indicatorName, ".Spread"            );
   unitSizeLabel     = StringConcatenate(indicatorName, ".UnitSize"          );
   positionLabel     = StringConcatenate(indicatorName, ".Position"          );
   freezeLevelLabel  = StringConcatenate(indicatorName, ".MarginFreezeLevel" );
   stopoutLevelLabel = StringConcatenate(indicatorName, ".MarginStopoutLevel");
   CreateLabels();

   // nach Parameteränderung nicht auf den nächsten Tick warten
   if (UninitializeReason() == REASON_PARAMETERS)
      SendFakeTick(false);

   return(catch("init()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   Tick++;
   ValidBars   = IndicatorCounted();
   ChangedBars = Bars - ValidBars;
   stdlib_onTick(ValidBars);

   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init) {                                      // Aufruf nach erstem init()
      init = false;
      if (init_error != NO_ERROR)                   return(0);
   }
   else if (init_error != NO_ERROR) {               // Aufruf nach Tick
      if (init_error != ERR_TERMINAL_NOT_YET_READY) return(0);
      if (init()     != NO_ERROR)                   return(0);
   }

   // Accountinitialiserung abfangen (bei Start und Accountwechsel)
   if (AccountNumber() == 0)
      return(ERR_NO_CONNECTION);

   position.Checked = false;

   UpdatePriceLabel();
   UpdateSpreadLabel();
   UpdateUnitSizeLabel();
   UpdatePositionLabel();
   UpdateMarginLevels();

   if (lastH1Close)
      UpdateH1CloseLabel();

   return(catch("start()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   RemoveChartObjects(labels);
   return(catch("deinit()"));
}


/**
 * Erzeugt die einzelnen Label.
 *
 * @return int - Fehlerstatus
 */
int CreateLabels() {
   // Instrument
   if (ObjectFind(instrumentLabel) >= 0)
      ObjectDelete(instrumentLabel);
   if (ObjectCreate(instrumentLabel, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(instrumentLabel, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(instrumentLabel, OBJPROP_XDISTANCE, 4);
      ObjectSet(instrumentLabel, OBJPROP_YDISTANCE, 1);
      RegisterChartObject(instrumentLabel, labels);
   }
   else GetLastError();

   string symbol = FindNormalizedSymbol(Symbol(), Symbol());
   string name   = FindSymbolLongName(symbol, FindSymbolName(symbol, symbol));
   if      (StringIEndsWith(Symbol(), "_ask")) name = StringConcatenate(name, " (Ask)");
   else if (StringIEndsWith(Symbol(), "_avg")) name = StringConcatenate(name, " (Avg)");
   ObjectSetText(instrumentLabel, name, 9, "Tahoma Fett", Black);       // Anzeige wird gleich hier (und nur ein einziges mal) gesetzt

   // aktueller Kurs
   if (ObjectFind(priceLabel) >= 0)
      ObjectDelete(priceLabel);
   if (ObjectCreate(priceLabel, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(priceLabel, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet(priceLabel, OBJPROP_XDISTANCE, 11);
      ObjectSet(priceLabel, OBJPROP_YDISTANCE, 9);
      ObjectSetText(priceLabel, " ", 1);
      RegisterChartObject(priceLabel, labels);
   }
   else GetLastError();

   // Spread
   if (ObjectFind(spreadLabel) >= 0)
      ObjectDelete(spreadLabel);
   if (ObjectCreate(spreadLabel, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(spreadLabel, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet(spreadLabel, OBJPROP_XDISTANCE, 30);
      ObjectSet(spreadLabel, OBJPROP_YDISTANCE, 32);
      ObjectSetText(spreadLabel, " ", 1);
      RegisterChartObject(spreadLabel, labels);
   }
   else GetLastError();

   // letzter H1-Schlußkurs
   if (lastH1Close) {
      if (ObjectFind(h1CloseLabel) >= 0)
         ObjectDelete(h1CloseLabel);
      if (ObjectCreate(h1CloseLabel, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(h1CloseLabel, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet(h1CloseLabel, OBJPROP_XDISTANCE, 11);
         ObjectSet(h1CloseLabel, OBJPROP_YDISTANCE, 9);
         ObjectSetText(h1CloseLabel, " ", 1);
         RegisterChartObject(h1CloseLabel, labels);
      }
      else GetLastError();
   }

   // UnitSize
   if (ObjectFind(unitSizeLabel) >= 0)
      ObjectDelete(unitSizeLabel);
   if (ObjectCreate(unitSizeLabel, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(unitSizeLabel, OBJPROP_CORNER, CORNER_BOTTOM_LEFT);
      ObjectSet(unitSizeLabel, OBJPROP_XDISTANCE, 290);
      ObjectSet(unitSizeLabel, OBJPROP_YDISTANCE, 9);
      ObjectSetText(unitSizeLabel, " ", 1);
      RegisterChartObject(unitSizeLabel, labels);
   }
   else GetLastError();

   // aktuelle Position
   if (ObjectFind(positionLabel) >= 0)
      ObjectDelete(positionLabel);
   if (ObjectCreate(positionLabel, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(positionLabel, OBJPROP_CORNER, CORNER_BOTTOM_LEFT);
      ObjectSet(positionLabel, OBJPROP_XDISTANCE, 530);
      ObjectSet(positionLabel, OBJPROP_YDISTANCE, 9);
      ObjectSetText(positionLabel, " ", 1);
      RegisterChartObject(positionLabel, labels);
   }
   else GetLastError();

   return(catch("CreateLabels()"));
}


/**
 * Aktualisiert die Kursanzeige.
 *
 * @return int - Fehlerstatus
 */
int UpdatePriceLabel() {
   if (Bid==0 || Ask==0)                  // bei Start oder Accountwechsel
      return(0);

   double price = (Bid + Ask) / 2;

   if (Digits==3 || Digits==5) string strPrice = NumberToStr(price, StringConcatenate(", .", Digits-1, "'"));
   else                               strPrice = NumberToStr(price, StringConcatenate(", .", Digits));

   ObjectSetText(priceLabel, strPrice, 13, "Microsoft Sans Serif", Black);

   int error = GetLastError();
   if (error==NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)   // bei offenem Properties-Dialog oder Object::onDrag()
      return(NO_ERROR);
   return(catch("UpdatePriceLabel()", error));
}


/**
 * Aktualisiert die Spreadanzeige.
 *
 * @return int - Fehlerstatus
 */
int UpdateSpreadLabel() {
   int spread = MarketInfo(Symbol(), MODE_SPREAD);

   int error = GetLastError();
   if (error == ERR_UNKNOWN_SYMBOL)       // bei Start oder Accountwechsel
      return(error);

   if (Spread.Including.Commission) if (AccountNumber()=={account-no} || AccountNumber()=={account-no})
      spread += 8;

   if (Digits==3 || Digits==5) string strSpread = DoubleToStr(spread/10.0, 1);
   else                               strSpread = spread;

   ObjectSetText(spreadLabel, strSpread, 9, "Tahoma", SlateGray);

   error = GetLastError();
   if (error==NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)   // bei offenem Properties-Dialog oder Object::onDrag()
      return(NO_ERROR);
   return(catch("UpdateSpreadLabel()", error));
}


/**
 * Aktualisiert die Anzeige des letzten H1-Schlußkurses.
 *
 * @return int - Fehlerstatus
 */
int UpdateH1CloseLabel() {
   if (!lastH1Close)
      return(0);

   double close = iClose(NULL, PERIOD_H1, 1);
   if (GetLastError() == ERR_HISTORY_UPDATE)
      return(ERR_HISTORY_UPDATE);

   static double lastClose = 0;
   if (lastClose == close)
      return(NO_ERROR);
   lastClose = close;

   if (Digits==3 || Digits==5) string strClose = NumberToStr(close, StringConcatenate(", .", Digits-1, "'"));
   else                               strClose = NumberToStr(close, StringConcatenate(", .", Digits));

   strClose = StringConcatenate("H1:  ", strClose);

   ObjectSetText(h1CloseLabel, strClose, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (error==NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)   // bei offenem Properties-Dialog oder Object::onDrag()
      return(NO_ERROR);
   return(catch("UpdateH1CloseLabel()", error));
}


/**
 * Aktualisiert die UnitSize-Anzeige.
 *
 * @return int - Fehlerstatus
 */
int UpdateUnitSizeLabel() {
   bool   tradeAllowed = MarketInfo(Symbol(), MODE_TRADEALLOWED);
   double tickSize     = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue    = MarketInfo(Symbol(), MODE_TICKVALUE);

   int error = GetLastError();
   if (Bid==0 || tickSize==0 || tickValue==0 || error==ERR_UNKNOWN_SYMBOL)    // bei Start oder Accountwechsel
      return(ERR_UNKNOWN_SYMBOL);

   string strUnitSize;

   if (!tradeAllowed) {
      strUnitSize = " ";      // der Labeltext darf nicht leer sein
   }
   else {
      double equity = AccountEquity() - AccountCredit();
      if (equity < 0)
         equity = 0;

      // Accountequity wird mit 'leverage' gehebelt
      int    leverage = 35;                              // leverage war bis 11/2010 = 7, ab dann mit GBP/JPY,H1-Scalper = 35
      double lotValue = Bid / tickSize * tickValue;      // Lotvalue in Account-Currency
      double unitSize = equity / lotValue * leverage;    // unitSize=equity/lotValue (Hebel von 1)

      // TODO: Volatilität oder ATR berücksichtigen

      if      (unitSize <=    0.02) unitSize = NormalizeDouble(MathRound(unitSize/  0.001) *   0.001, 3);   // 0.007-0.02: Vielfache von   0.001
      else if (unitSize <=    0.04) unitSize = NormalizeDouble(MathRound(unitSize/  0.002) *   0.002, 3);   //  0.02-0.04: Vielfache von   0.002
      else if (unitSize <=    0.07) unitSize = NormalizeDouble(MathRound(unitSize/  0.005) *   0.005, 3);   //  0.04-0.07: Vielfache von   0.005
      else if (unitSize <=    0.2 ) unitSize = NormalizeDouble(MathRound(unitSize/  0.01 ) *   0.01 , 2);   //   0.07-0.2: Vielfache von   0.01
      else if (unitSize <=    0.4 ) unitSize = NormalizeDouble(MathRound(unitSize/  0.02 ) *   0.02 , 2);   //    0.2-0.4: Vielfache von   0.02
      else if (unitSize <=    0.7 ) unitSize = NormalizeDouble(MathRound(unitSize/  0.05 ) *   0.05 , 2);   //    0.4-0.7: Vielfache von   0.05
      else if (unitSize <=    2   ) unitSize = NormalizeDouble(MathRound(unitSize/  0.1  ) *   0.1  , 1);   //      0.7-2: Vielfache von   0.1
      else if (unitSize <=    4   ) unitSize = NormalizeDouble(MathRound(unitSize/  0.2  ) *   0.2  , 1);   //        2-4: Vielfache von   0.2
      else if (unitSize <=    7   ) unitSize = NormalizeDouble(MathRound(unitSize/  0.5  ) *   0.5  , 1);   //        4-7: Vielfache von   0.5
      else if (unitSize <=   20   ) unitSize = NormalizeDouble(MathRound(unitSize/  1    ) *   1    , 0);   //       7-20: Vielfache von   1
      else if (unitSize <=   40   ) unitSize = NormalizeDouble(MathRound(unitSize/  2    ) *   2    , 0);   //      20-40: Vielfache von   2
      else if (unitSize <=   70   ) unitSize = NormalizeDouble(MathRound(unitSize/  5    ) *   5    , 0);   //      40-70: Vielfache von   5
      else if (unitSize <=  200   ) unitSize = NormalizeDouble(MathRound(unitSize/ 10    ) *  10    , 0);   //     70-200: Vielfache von  10
      else if (unitSize <=  400   ) unitSize = NormalizeDouble(MathRound(unitSize/ 20    ) *  20    , 0);   //    200-400: Vielfache von  20
      else if (unitSize <=  700   ) unitSize = NormalizeDouble(MathRound(unitSize/ 50    ) *  50    , 0);   //    400-700: Vielfache von  50
      else if (unitSize <= 2000   ) unitSize = NormalizeDouble(MathRound(unitSize/100    ) * 100    , 0);   //   700-2000: Vielfache von 100

      strUnitSize = StringConcatenate("UnitSize:  ", NumberToStr(unitSize, ", .+"), " Lot");
   }

   ObjectSetText(unitSizeLabel, strUnitSize, 9, "Tahoma", SlateGray);

   error = GetLastError();
   if (error==NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)   // bei offenem Properties-Dialog oder Object::onDrag()
      return(NO_ERROR);
   return(catch("UpdateUnitSizeLabel()", error));
}


bool   position.InMarket;
double position.Long, position.Short, position.Total;


/**
 * Aktualisiert die Positionsanzeige.
 *
 * @return int - Fehlerstatus
 */
int UpdatePositionLabel() {
   if (!position.Checked)
      CheckPosition();

   if      (!position.InMarket)  string strPosition = " ";
   else if (position.Total == 0)        strPosition = StringConcatenate("Position:  ±", NumberToStr(position.Long, ", .+"), " Lot (hedged)");
   else                                 strPosition = StringConcatenate("Position:  " , NumberToStr(position.Total, "+, .+"), " Lot");

   ObjectSetText(positionLabel, strPosition, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (error==NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)   // bei offenem Properties-Dialog oder Object::onDrag()
      return(NO_ERROR);
   return(catch("UpdatePositionLabel()", error));
}


/**
 * Aktualisiert die angezeigten Marginlevel.
 *
 * @return int - Fehlerstatus
 */
int UpdateMarginLevels() {
   if (!position.Checked)
      CheckPosition();


   if (position.Total == 0) {                // keine Position im Markt: evt. vorhandene Marker löschen
      ObjectDelete(freezeLevelLabel);
      ObjectDelete(stopoutLevelLabel);
   }
   else {
      // Kurslevel für Margin-Freeze und -Stopout berechnen und anzeigen
      double equity         = AccountEquity();
      double usedMargin     = AccountMargin();
      int    stopoutMode    = AccountStopoutMode();
      int    stopoutLevel   = AccountStopoutLevel();
      double marginRequired = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
      double tickSize       = MarketInfo(Symbol(), MODE_TICKSIZE);
      double tickValue      = MarketInfo(Symbol(), MODE_TICKVALUE);
      double marginLeverage = Bid / tickSize * tickValue / marginRequired;    // Hebel der real zur Verfügung gestellten Kreditlinie für das Symbol
             tickValue      = tickValue * MathAbs(position.Total);            // TickValue der gesamten Position

      int error = GetLastError();
      if (tickValue==0 || error==ERR_UNKNOWN_SYMBOL)                          // bei Start oder Accountwechsel
         return(ERR_UNKNOWN_SYMBOL);

      bool showFreezeLevel = true;

      if (stopoutMode == ASM_ABSOLUTE) { double equityStopoutLevel = stopoutLevel;                        }
      else if (stopoutLevel == 100)    {        equityStopoutLevel = usedMargin; showFreezeLevel = false; } // Freeze- und StopoutLevel sind identisch, nur StopOut anzeigen
      else                             {        equityStopoutLevel = stopoutLevel / 100.0 * usedMargin;   }

      double quoteFreezeDiff  = (equity - usedMargin        ) / tickValue * tickSize;
      double quoteStopoutDiff = (equity - equityStopoutLevel) / tickValue * tickSize;

      double quoteFreezeLevel, quoteStopoutLevel;

      if (position.Total > 0) {           // long position
         quoteFreezeLevel  = NormalizeDouble(Bid - quoteFreezeDiff, Digits);
         quoteStopoutLevel = NormalizeDouble(Bid - quoteStopoutDiff, Digits);
      }
      else {                              // short position
         quoteFreezeLevel  = NormalizeDouble(Ask + quoteFreezeDiff, Digits);
         quoteStopoutLevel = NormalizeDouble(Ask + quoteStopoutDiff, Digits);
      }
      /*
      Print("UpdateMarginLevels()"
                                  +"    equity="+ NumberToStr(equity, ", .2")
                            +"    equity(100%)="+ NumberToStr(usedMargin, ", .2") +" ("+ NumberToStr(equity-usedMargin, "+, .2") +" => "+ NumberToStr(quoteFreezeLevel, "."+ ifString(Digits==3 || Digits==5, (Digits-1)+"\'", Digits)) +")"
                            +"    equity(so:"+ ifString(stopoutMode==ASM_ABSOLUTE, "abs", stopoutLevel+"%") +")="+ NumberToStr(equityStopoutLevel, ", .2") +" ("+ NumberToStr(equity-equityStopoutLevel, "+, .2") +" => "+ NumberToStr(quoteStopoutLevel, "."+ ifString(Digits==3 || Digits==5, (Digits-1)+"\'", Digits)) +")"
      );
      */

      // FreezeLevel anzeigen
      if (showFreezeLevel) {
         if (ObjectFind(freezeLevelLabel) == -1) {
            ObjectCreate(freezeLevelLabel, OBJ_HLINE, 0, 0, 0);
            ObjectSet(freezeLevelLabel, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSet(freezeLevelLabel, OBJPROP_COLOR, C'0,201,206');
            ObjectSet(freezeLevelLabel, OBJPROP_BACK , true);
            ObjectSetText(freezeLevelLabel, StringConcatenate("Freeze   1:", DoubleToStr(marginLeverage, 0)));
            RegisterChartObject(freezeLevelLabel, labels);
         }
         ObjectSet(freezeLevelLabel, OBJPROP_PRICE1, quoteFreezeLevel);
      }

      // StopoutLevel anzeigen
      if (ObjectFind(stopoutLevelLabel) == -1) {
         ObjectCreate(stopoutLevelLabel, OBJ_HLINE, 0, 0, 0);
         ObjectSet(stopoutLevelLabel, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSet(stopoutLevelLabel, OBJPROP_COLOR, OrangeRed);
         ObjectSet(stopoutLevelLabel, OBJPROP_BACK , true);
            if (stopoutMode == ASM_PERCENT) string description = StringConcatenate("Stopout  1:", DoubleToStr(marginLeverage, 0));
            else                                   description = StringConcatenate("Stopout  ", NumberToStr(stopoutLevel, ", ."), AccountCurrency());
         ObjectSetText(stopoutLevelLabel, description);
         RegisterChartObject(stopoutLevelLabel, labels);
      }
      ObjectSet(stopoutLevelLabel, OBJPROP_PRICE1, quoteStopoutLevel);
   }


   error = GetLastError();
   if (error==NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)   // bei offenem Properties-Dialog oder Object::onDrag()
      return(NO_ERROR);
   return(catch("UpdateMarginLevels()", error));
}


/**
 * Ermittelt und speichert die momentane Marktpositionierung für das aktuelle Instrument.
 *
 * @return int - Fehlerstatus
 */
int CheckPosition() {
   if (position.Checked)
      return(NO_ERROR);

   position.Long  = 0;
   position.Short = 0;
   position.Total = 0;

   int orders = OrdersTotal();

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         break;

      if (OrderSymbol() == Symbol()) {
         if      (OrderType() == OP_BUY ) position.Long  += OrderLots();
         else if (OrderType() == OP_SELL) position.Short += OrderLots();
      }
   }
   position.Long  = NormalizeDouble(position.Long , 8);
   position.Short = NormalizeDouble(position.Short, 8);
   position.Total = NormalizeDouble(position.Long - position.Short, 8);

   position.InMarket = (position.Long > 0 || position.Short > 0);
   position.Checked  = true;

   return(catch("CheckPosition()"));
}