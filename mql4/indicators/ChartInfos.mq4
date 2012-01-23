/**
 * Zeigt im Chart verschiedene Informationen an:
 *
 * - oben links:  Name des Instruments
 * - oben rechts: aktueller Kurs und Spread
 * - unten Mitte: Größe einer Handels-Unit und im Moment gehaltene Position
 */
#include <stdlib.mqh>

#property indicator_chart_window


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   if (IsError(onInit(T_INDICATOR, IT_CHECK_TIMEZONE_CONFIG)))
      return(last_error);

   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);

   // Konfiguration auswerten
   string price  = StringToLower(GetGlobalConfigString("AppliedPrice", StdSymbol(), "median"));
   if      (price == "bid"   ) ChartInfo.appliedPrice = PRICE_BID;
   else if (price == "ask"   ) ChartInfo.appliedPrice = PRICE_ASK;
   else if (price == "median") ChartInfo.appliedPrice = PRICE_MEDIAN;
   else return(catch("init(1)  invalid configuration value [AppliedPrice], "+ StdSymbol() +" = \""+ price +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   ChartInfo.leverage = GetGlobalConfigDouble("Leverage", "CurrencyPair", 1);
   if (LT(ChartInfo.leverage, 1))
      return(catch("init(2)  invalid configuration value [Leverage] CurrencyPair = "+ NumberToStr(ChartInfo.leverage, ".+"), ERR_INVALID_CONFIG_PARAMVALUE));

   // Label erzeugen
   ChartInfo.CreateLabels();

   // nach Parameteränderung nicht auf den nächsten Tick warten (nur im "Indicators List"-Window notwendig)
   if (UninitializeReason() == REASON_PARAMETERS)
      SendTick(false);

   return(catch("init(3)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   RemoveChartObjects(objects);
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (Bid < 0.00000001)                                             // Symbol nicht subscribed (Start, Account- oder Templatewechsel)
      return(catch("onTick(1)"));

   ChartInfo.positionChecked = false;

   ChartInfo.UpdatePrice();
   ChartInfo.UpdateSpread();
   ChartInfo.UpdateUnitSize();
   ChartInfo.UpdatePosition();
   ChartInfo.UpdateMarginLevels();

   return(catch("onTick(2)"));
}
