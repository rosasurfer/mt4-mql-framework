/**
 * Grid Projection
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>


// Moneymanagement
#define DEFAULT_VOLATILITY    2.5                                    // Default-Volatilität einer Unit in Prozent Equity je Woche (Erfahrungswert)

double aum.value;                                                    // zusätzliche extern verwaltete und bei Equity-Berechnungen zu berücksichtigende Assets
string aum.currency = "";


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   if (!RefreshExternalAssets())
      return(last_error);
   return(catch("onInit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   // (1) unleveraged Lots
   double tickSize        = MarketInfo(Symbol(), MODE_TICKSIZE );
   double tickValue       = MarketInfo(Symbol(), MODE_TICKVALUE);
   double equity          = aum.value + MathMin(AccountBalance(), AccountEquity()-AccountCredit());
      if (!Close[0] || !tickSize || !tickValue || equity <= 0) return(catch("onStart(1)   unexpected NULL value for calculations", ERR_RUNTIME_ERROR));
   double lotValue        = Close[0]/tickSize * tickValue;                          // Value eines Lots in Account-Currency
   double unleveragedLots = equity/lotValue;                                        // ungehebelte Lotsize (Leverage 1:1)


   // (2) Expected TrueRange als Maximalwert von ATR und den letzten beiden Einzelwerten: ATR, TR[1] und TR[0]
   double a = ixATR(NULL, PERIOD_W1, 14, 1); if (a == EMPTY) return(last_error);    // ATR(14xW)
   double b = ixATR(NULL, PERIOD_W1,  1, 1); if (b == EMPTY) return(last_error);    // TrueRange letzte Woche
   double c = ixATR(NULL, PERIOD_W1,  1, 0); if (c == EMPTY) return(last_error);    // TrueRange aktuelle Woche
   double ETRwAbs = MathMax(a, MathMax(b, c));
      double C = iClose(NULL, PERIOD_W1, 1);
      double H = iHigh (NULL, PERIOD_W1, 0);
      double L = iLow  (NULL, PERIOD_W1, 0);
   double ETRwPct = ETRwAbs/((MathMax(C, H) + MathMax(C, L))/2);                    // median price


   // (5) Levelberechnung
   double weeklyVola     = DEFAULT_VOLATILITY;
   double gridSize       = ETRwAbs/weeklyVola;
   double takeProfitDist = gridSize / 2;
   double stopLossDist   = gridSize * 2;

   double tpPriceLong  = Close[0] + takeProfitDist;
   double tpPriceShort = Close[0] - takeProfitDist;

   double slPriceLong  = Close[0] - stopLossDist;
   double slPriceShort = Close[0] + stopLossDist;


   // (6) Gridanzeige
   datetime from = TimeCurrent() + 1*DAY;
   datetime to   = TimeCurrent() + 4*DAYS;

   string label = StringConcatenate(__NAME__, ".EntryLevel");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_TREND, 0, from, Close[0], to, Close[0])) {
      ObjectSet(label, OBJPROP_RAY  , false      );
      ObjectSet(label, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet(label, OBJPROP_COLOR, Blue       );
      ObjectSet(label, OBJPROP_BACK , false      );
   }
   label = StringConcatenate(__NAME__, ".TakeProfitLevel.Long");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_TREND, 0, from, tpPriceLong, to, tpPriceLong)) {
      ObjectSet(label, OBJPROP_RAY  , false      );
      ObjectSet(label, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet(label, OBJPROP_COLOR, LimeGreen  );
      ObjectSet(label, OBJPROP_BACK , true       );
   }
   label = StringConcatenate(__NAME__, ".TakeProfitLevel.Short");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_TREND, 0, from, tpPriceShort, to, tpPriceShort)) {
      ObjectSet(label, OBJPROP_RAY  , false      );
      ObjectSet(label, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet(label, OBJPROP_COLOR, LimeGreen  );
      ObjectSet(label, OBJPROP_BACK , true       );
   }
   label = StringConcatenate(__NAME__, ".StopLossLevel.Long");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_TREND, 0, from, slPriceLong, to, slPriceLong)) {
      ObjectSet(label, OBJPROP_RAY  , false      );
      ObjectSet(label, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet(label, OBJPROP_COLOR, Red        );
      ObjectSet(label, OBJPROP_BACK , true       );
   }
   label = StringConcatenate(__NAME__, ".StopLossLevel.Short");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_TREND, 0, from, slPriceShort, to, slPriceShort)) {
      ObjectSet(label, OBJPROP_RAY  , false      );
      ObjectSet(label, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet(label, OBJPROP_COLOR, Red        );
      ObjectSet(label, OBJPROP_BACK , true       );
   }


   // (7) Parameteranzeige
   string msg = StringConcatenate(__NAME__, "  for weekly volatility of "+ DoubleToStr(weeklyVola, 1) +"%",                                                       NL,
                                                                                                                                                                  NL,
                                 "ETR:        ",  DoubleToStr(ETRwAbs       /Pips, 1) +" pip = "+ NumberToStr(ETRwPct*100, "R.2") +"%",                           NL,
                                 "Gridsize:   ",  DoubleToStr(gridSize      /Pips, 1) +" pip  =  1.0%",                                                           NL,
                                 "TP:          ", DoubleToStr(takeProfitDist/Pips, 1) +" pip  =  0.5%",                                                           NL,
                                 "SL:          ", DoubleToStr(stopLossDist  /Pips, 1) +" pip  =  3.0%  =  ", DoubleToStr(0.03*equity, 2), " ", AccountCurrency(), NL,
                                 "");
   Comment(StringConcatenate(NL, NL, NL, msg));                                     // 3 Zeilen Abstand nach oben für evt. vorhandene andere Anzeigen

   return(catch("onStart(2)"));
}


/**
 * Liest die Konfiguration der zusätzlichen extern verwalteten Assets erneut ein.
 *
 * @return bool - Erfolgsstatus
 */
bool RefreshExternalAssets() {
   string mqlDir  = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string file    = TerminalPath() + mqlDir +"\\files\\"+ ShortAccountCompany() +"\\"+ GetAccountNumber() +"_config.ini";
   string section = "General";
   string key     = "AuM.Value";

   double value = GetIniDouble(file, section, key, 0);
   if (!value) {
      aum.value    = 0;
      aum.currency = "";
      return(!catch("RefreshExternalAssets(1)"));
   }
   if (value < 0) return(!catch("RefreshExternalAssets(2)   invalid ini entry ["+ section +"]->"+ key +"=\""+ GetIniString(file, section, key, "") +"\" (negative value) in \""+ file +"\"", ERR_RUNTIME_ERROR));


   key = "AuM.Currency";
   string currency = GetIniString(file, section, key, "");
   if (!StringLen(currency)) {
      if (!IsIniKey(file, section, key)) return(!catch("RefreshExternalAssets(3)   missing ini entry ["+ section +"]->"+ key +" in \""+ file +"\"", ERR_RUNTIME_ERROR));
                                         return(!catch("RefreshExternalAssets(4)   invalid ini entry ["+ section +"]->"+ key +"=\"\" (empty value) in \""+ file +"\"", ERR_RUNTIME_ERROR));
   }
   aum.value    = value;
   aum.currency = StringToUpper(currency);

   return(!catch("RefreshExternalAssets(5)"));
}
