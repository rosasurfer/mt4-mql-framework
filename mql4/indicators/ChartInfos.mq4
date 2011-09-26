/**
 * Zeigt im Chart verschiedene Informationen an:
 *
 * - oben links:     der Name des Instruments
 * - oben rechts:    der aktuelle Kurs
 * - unter dem Kurs: der Spread
 * - unten Mitte:    die Größe einer Handels-Unit
 * - unten Mitte:    die im Moment gehaltene Position
 */
#include <stdlib.mqh>


#property indicator_chart_window


#define PRICE_BID    1
#define PRICE_ASK    2


double Pip;
int    PipDigits;
int    PipPoints;
double TickSize;
string PriceFormat;

string instrumentLabel, priceLabel, spreadLabel, unitSizeLabel, positionLabel, freezeLevelLabel, stopoutLevelLabel;
string chartObjects[];

int    appliedPrice = PRICE_MEDIAN;                                  // Median(default) | Bid | Ask
double leverage;                                                     // Hebel zur UnitSize-Berechnung
bool   positionChecked;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   PipDigits   = Digits & (~1);
   PipPoints   = MathPow(10, Digits-PipDigits) +0.1;                 // (int) double
   Pip         = 1/MathPow(10, PipDigits);
   PriceFormat = "."+ PipDigits + ifString(Digits==PipDigits, "", "'");


   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);

   // Konfiguration auswerten
   string symbol = GetStandardSymbol(Symbol());
   string price  = StringToLower(GetGlobalConfigString("AppliedPrice", symbol, "median"));
   if      (price == "median") appliedPrice = PRICE_MEDIAN;
   else if (price == "bid"   ) appliedPrice = PRICE_BID;
   else if (price == "ask"   ) appliedPrice = PRICE_ASK;
   else
      catch("init(1)  Invalid configuration value [AppliedPrice], "+ symbol +" = \""+ price +"\"", ERR_INVALID_INPUT_PARAMVALUE);

   leverage = GetGlobalConfigDouble("Leverage", "CurrencyPair", 1);
   if (LT(leverage, 1))
      return(catch("init(2)  Invalid configuration value [Leverage] CurrencyPair = "+ NumberToStr(leverage, ".+"), ERR_INVALID_INPUT_PARAMVALUE));

   // Label definieren und erzeugen
   instrumentLabel   = StringConcatenate(__SCRIPT__, ".Instrument"        );
   priceLabel        = StringConcatenate(__SCRIPT__, ".Price"             );
   spreadLabel       = StringConcatenate(__SCRIPT__, ".Spread"            );
   unitSizeLabel     = StringConcatenate(__SCRIPT__, ".UnitSize"          );
   positionLabel     = StringConcatenate(__SCRIPT__, ".Position"          );
   freezeLevelLabel  = StringConcatenate(__SCRIPT__, ".MarginFreezeLevel" );
   stopoutLevelLabel = StringConcatenate(__SCRIPT__, ".MarginStopoutLevel");
   CreateLabels();

   // nach Parameteränderung nicht auf den nächsten Tick warten (nur im "Indicators List"-Window notwendig)
   if (UninitializeReason() == REASON_PARAMETERS)
      SendTick(false);

   return(catch("init()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   RemoveChartObjects(chartObjects);
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   Tick++;
   if      (init_error != NO_ERROR)                   UnchangedBars = 0;
   else if (last_error == ERR_TERMINAL_NOT_YET_READY) UnchangedBars = 0;
   else                                               UnchangedBars = IndicatorCounted();
   ChangedBars = Bars - UnchangedBars;
   stdlib_onTick(UnchangedBars);

   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init_error == ERR_TERMINAL_NOT_YET_READY) /*&&*/ if (!init)
      init();
   init = false;
   if (init_error != NO_ERROR)
      return(init_error);

   // Abschluß der Chart-Initialisierung überprüfen
   if (Bars == 0)                                                    // tritt u.U. bei Terminal-Start auf
      return(SetLastError(ERR_TERMINAL_NOT_YET_READY));
   last_error = NO_ERROR;
   // ---------------------------------------------------------------------------------------------------


   positionChecked = false;

   UpdatePriceLabel();
   UpdateSpreadLabel();
   UpdateUnitSizeLabel();
   UpdatePositionLabel();
   UpdateMarginLevels();

   return(catch("start()"));
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
      ArrayPushString(chartObjects, instrumentLabel);
   }
   else GetLastError();

   string name = GetLongSymbolNameOrAlt(Symbol(), GetSymbolName(Symbol()));
   if      (StringIEndsWith(Symbol(), "_ask")) name = StringConcatenate(name, " (Ask)");
   else if (StringIEndsWith(Symbol(), "_avg")) name = StringConcatenate(name, " (Avg)");
   ObjectSetText(instrumentLabel, name, 9, "Tahoma Fett", Black);                         // Anzeige wird sofort und nur hier gesetzt

   // Kurs
   if (ObjectFind(priceLabel) >= 0)
      ObjectDelete(priceLabel);
   if (ObjectCreate(priceLabel, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(priceLabel, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet(priceLabel, OBJPROP_XDISTANCE, 14);
      ObjectSet(priceLabel, OBJPROP_YDISTANCE, 15);
      ObjectSetText(priceLabel, " ", 1);
      ArrayPushString(chartObjects, priceLabel);
   }
   else GetLastError();

   // Spread
   if (ObjectFind(spreadLabel) >= 0)
      ObjectDelete(spreadLabel);
   if (ObjectCreate(spreadLabel, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(spreadLabel, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet(spreadLabel, OBJPROP_XDISTANCE, 33);
      ObjectSet(spreadLabel, OBJPROP_YDISTANCE, 38);
      ObjectSetText(spreadLabel, " ", 1);
      ArrayPushString(chartObjects, spreadLabel);
   }
   else GetLastError();

   // UnitSize
   if (ObjectFind(unitSizeLabel) >= 0)
      ObjectDelete(unitSizeLabel);
   if (ObjectCreate(unitSizeLabel, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(unitSizeLabel, OBJPROP_CORNER, CORNER_BOTTOM_LEFT);
      ObjectSet(unitSizeLabel, OBJPROP_XDISTANCE, 290);
      ObjectSet(unitSizeLabel, OBJPROP_YDISTANCE, 9);
      ObjectSetText(unitSizeLabel, " ", 1);
      ArrayPushString(chartObjects, unitSizeLabel);
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
      ArrayPushString(chartObjects, positionLabel);
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
   if (Bid < 0.00000001) {                                     // Symbol nicht subscribed (Market Watch bzw. "symbols.sel") => Start oder Accountwechsel
      string strPrice = " ";
   }
   else {
      static double lastBid, lastAsk;
      if (EQ(lastBid, Bid)) /*&&*/ if (EQ(lastAsk, Ask))
         return(NO_ERROR);
      lastBid = Bid;
      lastAsk = Ask;

      switch (appliedPrice) {
         case PRICE_MEDIAN: double price = (Bid + Ask)/2; break;
         case PRICE_BID:           price =  Bid;          break;
         case PRICE_ASK:           price =  Ask;          break;
      }
      strPrice = NumberToStr(price, StringConcatenate(",,", PriceFormat));
   }

   ObjectSetText(priceLabel, strPrice, 13, "Microsoft Sans Serif", Black);

   int error = GetLastError();
   if (error==NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)          // bei offenem Properties-Dialog oder Object::onDrag()
      return(NO_ERROR);
   return(catch("UpdatePriceLabel()", error));
}


/**
 * Aktualisiert die Spreadanzeige.
 *
 * @return int - Fehlerstatus
 */
int UpdateSpreadLabel() {
   int spread = MarketInfo(Symbol(), MODE_SPREAD) +0.1;              // (int) double
   int error  = GetLastError();

   if (error==ERR_UNKNOWN_SYMBOL || Bid < 0.00000001) {              // Symbol nicht subscribed (Market Watch bzw. "symbols.sel") => Start oder Accountwechsel
      string strSpread = " ";
   }
   else {
      static int lastSpread;
      if (lastSpread == spread)
         return(0);
      lastSpread = spread;
      strSpread  = DoubleToStr(spread / MathPow(10, Digits-PipDigits), Digits-PipDigits);
   }

   ObjectSetText(spreadLabel, strSpread, 9, "Tahoma", SlateGray);

   error = GetLastError();
   if (error==NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)          // bei offenem Properties-Dialog oder Object::onDrag()
      return(NO_ERROR);
   return(catch("UpdateSpreadLabel()", error));
}


/**
 * Aktualisiert die UnitSize-Anzeige.
 *
 * @return int - Fehlerstatus
 */
int UpdateUnitSizeLabel() {
   bool   tradeAllowed = NE(MarketInfo(Symbol(), MODE_TRADEALLOWED), 0);
   double tickSize     =    MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue    =    MarketInfo(Symbol(), MODE_TICKVALUE);

   int error = GetLastError();
   string strUnitSize;

   if (error==ERR_UNKNOWN_SYMBOL || Bid < 0.00000001 || tickSize < 0.00000001 || tickValue < 0.00000001 || !tradeAllowed) {   // bei Start oder Accountwechsel
      strUnitSize = " ";
   }
   else {
      double unitSize, equity=AccountEquity(), credit=AccountCredit();

      static double lastEquity, lastCredit, lastBid, lastTickSize, lastTickValue;
      if (EQ(Bid, lastBid)) /*&&*/ if (EQ(equity, lastEquity)) /*&&*/ if (EQ(tickValue, lastTickValue)) /*&&*/ if (EQ(credit, lastCredit)) /*&&*/ if (EQ(tickSize, lastTickSize))
         return(catch("UpdateUnitSizeLabel(1)"));

      lastEquity    = equity;
      lastCredit    = credit;
      lastBid       = Bid;
      lastTickSize  = tickSize;
      lastTickValue = tickValue;

      equity -= credit;
      if (equity > 0.00000001) {                            // Accountequity wird mit 'leverage' gehebelt
         double lotValue = Bid / tickSize * tickValue;      // Lotvalue in Account-Currency
         unitSize = equity / lotValue * leverage;           // unitSize = equity/lotValue entspricht Hebel von 1

         if      (unitSize <    0.02000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.001) *   0.001, 3);   // 0.007-0.02: Vielfache von   0.001
         else if (unitSize <    0.04000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.002) *   0.002, 3);   //  0.02-0.04: Vielfache von   0.002
         else if (unitSize <    0.07000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.005) *   0.005, 3);   //  0.04-0.07: Vielfache von   0.005
         else if (unitSize <    0.20000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.01 ) *   0.01 , 2);   //   0.07-0.2: Vielfache von   0.01
         else if (unitSize <    0.40000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.02 ) *   0.02 , 2);   //    0.2-0.4: Vielfache von   0.02
         else if (unitSize <    0.70000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.05 ) *   0.05 , 2);   //    0.4-0.7: Vielfache von   0.05
         else if (unitSize <    2.00000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.1  ) *   0.1  , 1);   //      0.7-2: Vielfache von   0.1
         else if (unitSize <    4.00000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.2  ) *   0.2  , 1);   //        2-4: Vielfache von   0.2
         else if (unitSize <    7.00000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.5  ) *   0.5  , 1);   //        4-7: Vielfache von   0.5
         else if (unitSize <   20.00000001) unitSize = MathRound      (MathRound(unitSize/  1    ) *   1);          //       7-20: Vielfache von   1
         else if (unitSize <   40.00000001) unitSize = MathRound      (MathRound(unitSize/  2    ) *   2);          //      20-40: Vielfache von   2
         else if (unitSize <   70.00000001) unitSize = MathRound      (MathRound(unitSize/  5    ) *   5);          //      40-70: Vielfache von   5
         else if (unitSize <  200.00000001) unitSize = MathRound      (MathRound(unitSize/ 10    ) *  10);          //     70-200: Vielfache von  10
         else if (unitSize <  400.00000001) unitSize = MathRound      (MathRound(unitSize/ 20    ) *  20);          //    200-400: Vielfache von  20
         else if (unitSize <  700.00000001) unitSize = MathRound      (MathRound(unitSize/ 50    ) *  50);          //    400-700: Vielfache von  50
         else if (unitSize < 2000.00000001) unitSize = MathRound      (MathRound(unitSize/100    ) * 100);          //   700-2000: Vielfache von 100
      }
      strUnitSize = StringConcatenate("UnitSize:  ", NumberToStr(unitSize, ", .+"), " lot");
   }

   ObjectSetText(unitSizeLabel, strUnitSize, 9, "Tahoma", SlateGray);

   error = GetLastError();
   if (error==NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)   // bei offenem Properties-Dialog oder Object::onDrag()
      return(NO_ERROR);
   return(catch("UpdateUnitSizeLabel(2)", error));
}


bool   anyPosition;
double longPosition, shortPosition, totalPosition;


/**
 * Aktualisiert die Positionsanzeige.
 *
 * @return int - Fehlerstatus
 */
int UpdatePositionLabel() {
   if (!positionChecked)
      CheckPosition();

   if      (!anyPosition)         string strPosition = " ";
   else if (EQ(totalPosition, 0))        strPosition = StringConcatenate("Position:  ±", NumberToStr(longPosition, ", .+"), " lot (hedged)");
   else                                  strPosition = StringConcatenate("Position:  " , NumberToStr(totalPosition, "+, .+"), " lot");

   ObjectSetText(positionLabel, strPosition, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (error==NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)    // bei offenem Properties-Dialog oder Object::onDrag()
      return(NO_ERROR);
   return(catch("UpdatePositionLabel()", error));
}


/**
 * Aktualisiert die angezeigten Marginlevel.
 *
 * @return int - Fehlerstatus
 */
int UpdateMarginLevels() {
   if (!positionChecked)
      CheckPosition();

   if (totalPosition < 0.00000001) {                                          // keine Position im Markt: ggf. vorhandene Marker löschen
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
             tickValue      = tickValue * MathAbs(totalPosition);             // TickValue der gesamten Position

      int error = GetLastError();
      if (tickValue < 0.00000001 || error==ERR_UNKNOWN_SYMBOL)                // bei Start oder Accountwechsel
         return(ERR_UNKNOWN_SYMBOL);

      bool showFreezeLevel = true;

      if (stopoutMode == ASM_ABSOLUTE) { double equityStopoutLevel = stopoutLevel;                        }
      else if (stopoutLevel == 100)    {        equityStopoutLevel = usedMargin; showFreezeLevel = false; } // Freeze- und StopoutLevel sind identisch, nur StopOut anzeigen
      else                             {        equityStopoutLevel = stopoutLevel / 100.0 * usedMargin;   }

      double quoteFreezeDiff  = (equity - usedMargin        ) / tickValue * tickSize;
      double quoteStopoutDiff = (equity - equityStopoutLevel) / tickValue * tickSize;

      double quoteFreezeLevel, quoteStopoutLevel;

      if (totalPosition > 0.00000001) {                                       // long position
         quoteFreezeLevel  = NormalizeDouble(Bid - quoteFreezeDiff, Digits);
         quoteStopoutLevel = NormalizeDouble(Bid - quoteStopoutDiff, Digits);
      }
      else {                                                                  // short position
         quoteFreezeLevel  = NormalizeDouble(Ask + quoteFreezeDiff, Digits);
         quoteStopoutLevel = NormalizeDouble(Ask + quoteStopoutDiff, Digits);
      }
      /*
      Print("UpdateMarginLevels()"
                                  +"    equity="+ NumberToStr(equity, ", .2")
                            +"    equity(100%)="+ NumberToStr(usedMargin, ", .2") +" ("+ NumberToStr(equity-usedMargin, "+, .2") +" => "+ NumberToStr(quoteFreezeLevel, PriceFormat) +")"
                            +"    equity(so:"+ ifString(stopoutMode==ASM_ABSOLUTE, "abs", stopoutLevel+"%") +")="+ NumberToStr(equityStopoutLevel, ", .2") +" ("+ NumberToStr(equity-equityStopoutLevel, "+, .2") +" => "+ NumberToStr(quoteStopoutLevel, PriceFormat) +")"
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
            ArrayPushString(chartObjects, freezeLevelLabel);
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
         ArrayPushString(chartObjects, stopoutLevelLabel);
      }
      ObjectSet(stopoutLevelLabel, OBJPROP_PRICE1, quoteStopoutLevel);
   }


   error = GetLastError();
   if (error==NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)    // bei offenem Properties-Dialog oder Object::onDrag()
      return(NO_ERROR);
   return(catch("UpdateMarginLevels()", error));
}


/**
 * Ermittelt und speichert die momentane Marktpositionierung für das aktuelle Instrument.
 *
 * @return int - Fehlerstatus
 */
int CheckPosition() {
   if (positionChecked)
      return(0);

   longPosition  = 0;
   shortPosition = 0;
   totalPosition = 0;

   int orders = OrdersTotal();

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))         // FALSE: während des Auslesens wird in einem anderen Thread eine aktive Order geschlossen oder gestrichen
         break;

      if (OrderSymbol() == Symbol()) {
         if      (OrderType() == OP_BUY ) longPosition  += OrderLots();
         else if (OrderType() == OP_SELL) shortPosition += OrderLots();
      }
   }
   totalPosition = longPosition - shortPosition;
   anyPosition   = (longPosition > 0.00000001 || shortPosition > 0.00000001);

   positionChecked = true;

   return(catch("CheckPosition()"));
}
