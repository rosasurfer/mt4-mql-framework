/**
 * Zeigt im Chart verschiedene aktuelle Informationen an.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE, INIT_PIPVALUE};
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
   if      (price == "bid"   ) chartInfos.appliedPrice = PRICE_BID;
   else if (price == "ask"   ) chartInfos.appliedPrice = PRICE_ASK;
   else if (price == "median") chartInfos.appliedPrice = PRICE_MEDIAN;
   else return(catch("onInit(1)   invalid configuration value [AppliedPrice], "+ StdSymbol() +" = \""+ price +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   chartInfos.leverage = GetGlobalConfigDouble("Leverage", "CurrencyPair", 1);
   if (LT(chartInfos.leverage, 1))
      return(catch("onInit(2)   invalid configuration value [Leverage] CurrencyPair = "+ NumberToStr(chartInfos.leverage, ".+"), ERR_INVALID_CONFIG_PARAMVALUE));

   // Label erzeugen
   ChartInfos.CreateLabels();

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
   chartInfos.positionsAnalyzed = false;

   ChartInfos.UpdatePrice();
   ChartInfos.UpdateSpread();
   ChartInfos.UpdateUnitSize();
   ChartInfos.UpdatePosition();
   ChartInfos.UpdateTime();
   ChartInfos.UpdateMarginLevels();

   return(last_error);
}
