/**
 *                                                          Grid-Trading
 *                                                         ==============
 *
 *  - Ursprünglich waren BollingerBand-Setups für Swing-Trades von einem Band zum anderen gedacht. Dieses ProfitTarget erwies
 *    sich als unrealistisch (wird zu selten erreicht) und wurde zunächst auf 1.0% und dann auf 0.5% Equity reduziert.
 *
 *  - Nach den ersten Verlusten wurde ein StopLoss von 3.0% Equity definiert.
 *
 *  - Angesichts der Grid-Projection für TP=0.5% und SL=3.0% (Rangeverhältnis 1:4) erscheinen BollingerBänder nicht mehr als
 *    vernünftiges Einstiegskriterium. Statt dessen scheint die Weekly-Range aussichtsreicher, denn die Distance zwischen TakeProfit
 *    und StopLoss entspricht exakt der erwarteten wöchentlichen Trading-Range (ETR).
 *
 *  - Potentielle Setups sind der Bruch der Vorwochenrange, der ETR oder von wöchentlichen Insidebars. Dies können Extreme oder
 *    die Entstehung neuer Trends sein. Als Extreme sollten sie zuverlässig sein, wenn ein neuer Trend ausgeschlossen werden kann.
 *
 *
 *  TODO:
 *  -----
 *  - jeden Entry dokumentieren: Screenshot, Notizen
 *  - historische Grid-Projection
 *  - ETR-Channel im Chart
 *  - Gridmanager: TP-Anpassung bei Erreichen von Level 2, Trailing Stop bei Erreichen von TP
 *  - Alerts bei Bruch der ETR (evt. bereits bei 80% der Range)
 *  - Alerts bei Bruch von wöchentlichen Insidebars
 *  - Alerts bei Bruch BollingerBand
 *
 *
 *  Parameter:
 *  ----------
 *  - GridSize:   1.0% Equity/Woche
 *  - TakeProfit: 0.5% Equity
 *  - StopLoss:  -3.0% Equity = Gridlevel 3
 *
 *
 *  Einstieg:
 *  ---------
 *  - bei/nach Extremen: BollingerBänder, wenn sie weit auseinanderliegen (nicht mehr gültig)
 *  - Negativkriterien: StdDev, enge BollingerBänder (kündigen Extreme an, siehe Gold)
 *  - bei Start OpenEquity, Grid- und Stopout-Level speichern und alle Orders in den Markt legen (Ersatz für Grid-Trademanager)
 *  - bei Erreichen von Level 2 TakeProfit-Level anpassen
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>
#include <iFunctions/@ATR.mqh>


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
   double a = @ATR(NULL, PERIOD_W1, 14, 1); if (a == EMPTY) return(last_error);     // ATR(14xW)
   double b = @ATR(NULL, PERIOD_W1,  1, 1); if (b == EMPTY) return(last_error);     // TrueRange letzte Woche
   double c = @ATR(NULL, PERIOD_W1,  1, 0); if (c == EMPTY) return(last_error);     // TrueRange aktuelle Woche
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
