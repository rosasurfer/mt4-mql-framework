/**
 * Zeigt im Chart verschiedene Informationen an:
 *
 * - oben links:  Name des Instruments
 * - oben rechts: aktueller Kurs und Spread
 * - unten Mitte: Größe einer Handels-Unit und die im Moment gehaltene Position
 *
 *
 * letzte Version mit Performance-Display: v1.38
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/indicator.mqh>
#include <ChartInfos/functions.mqh>

#property indicator_chart_window


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);

   // Konfiguration auswerten
   string price  = StringToLower(GetGlobalConfigString("AppliedPrice", StdSymbol(), "median"));
   if      (price == "bid"   ) chartInfo.appliedPrice = PRICE_BID;
   else if (price == "ask"   ) chartInfo.appliedPrice = PRICE_ASK;
   else if (price == "median") chartInfo.appliedPrice = PRICE_MEDIAN;
   else return(catch("onInit(1)   invalid configuration value [AppliedPrice], "+ StdSymbol() +" = \""+ price +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   chartInfo.leverage = GetGlobalConfigDouble("Leverage", "CurrencyPair", 1);
   if (LT(chartInfo.leverage, 1))
      return(catch("onInit(2)   invalid configuration value [Leverage] CurrencyPair = "+ NumberToStr(chartInfo.leverage, ".+"), ERR_INVALID_CONFIG_PARAMVALUE));

   // Label erzeugen
   ChartInfo.CreateLabels();

   return(catch("onInit(3)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   RemoveChartObjects(objects);
   return(catch("onDeinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   chartInfo.positionChecked = false;

   ChartInfo.UpdatePrice();
   ChartInfo.UpdateSpread();
   ChartInfo.UpdateUnitSize();
   ChartInfo.UpdatePosition();
   ChartInfo.UpdateMarginLevels();

   return(catch("onTick()"));
}
