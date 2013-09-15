/**
 * Zeigt im Chart verschiedene aktuelle Informationen an.
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
   if      (price == "bid"   ) ci.appliedPrice = PRICE_BID;
   else if (price == "ask"   ) ci.appliedPrice = PRICE_ASK;
   else if (price == "median") ci.appliedPrice = PRICE_MEDIAN;
   else return(catch("onInit(1)   invalid configuration value [AppliedPrice], "+ StdSymbol() +" = \""+ price +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

   ci.leverage = GetGlobalConfigDouble("Leverage", "CurrencyPair", 1);
   if (LT(ci.leverage, 1))
      return(catch("onInit(2)   invalid configuration value [Leverage] CurrencyPair = "+ NumberToStr(ci.leverage, ".+"), ERR_INVALID_CONFIG_PARAMVALUE));

   // Label erzeugen
   CI.CreateLabels();

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
   ci.positionsAnalyzed = false;

   if (!CI.UpdatePrice()       ) return(last_error);
   if (!CI.UpdateSpread()      ) return(last_error);
   if (!CI.UpdateUnitSize()    ) return(last_error);
   if (!CI.UpdatePosition()    ) return(last_error);
   if (!CI.UpdateMarginLevels()) return(last_error);
   if (!CI.UpdateTime()        ) return(last_error);

   return(last_error);
}
