/**
 * Zeigt die Eigenschaften eines Instruments an.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/indicator.mqh>

#property indicator_chart_window


color  fg.fontColor.Enabled  = Blue;
color  fg.fontColor.Disabled = Gray;
string fg.fontName           = "Tahoma";
int    fg.fontSize           = 9;

string labels[] = {"TRADEALLOWED","POINT","TICKSIZE","PIPVALUE","ATR_D","ATR_W","ATR_M","STOPLEVEL","FREEZELEVEL","LOTSIZE","MINLOT","LOTSTEP","MAXLOT","MARGINREQUIRED","MARGINHEDGED","SPREAD","COMMISSION","TOTALFEES","SWAPLONG","SWAPSHORT","ACCOUNT_LEVERAGE","STOPOUT_LEVEL","SERVER_NAME","SERVER_TIMEZONE","SERVER_SESSION"};

#define I_TRADEALLOWED         0
#define I_POINT                1
#define I_TICKSIZE             2
#define I_PIPVALUE             3
#define I_ATR_D                4
#define I_ATR_W                5
#define I_ATR_M                6
#define I_STOPLEVEL            7
#define I_FREEZELEVEL          8
#define I_LOTSIZE              9
#define I_MINLOT              10
#define I_LOTSTEP             11
#define I_MAXLOT              12
#define I_MARGINREQUIRED      13
#define I_MARGINHEDGED        14
#define I_SPREAD              15
#define I_COMMISSION          16
#define I_TOTALFEES           17
#define I_SWAPLONG            18
#define I_SWAPSHORT           19
#define I_ACCOUNT_LEVERAGE    20
#define I_STOPOUT_LEVEL       21
#define I_SERVER_NAME         22
#define I_SERVER_TIMEZONE     23
#define I_SERVER_SESSION      24


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   SetIndexLabel(0, NULL);                                           // Datenanzeige ausschalten

   CreateLabels();
   return(catch("onInit()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   return(catch("onDeinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   UpdateInfos();
   return(last_error);
}


/**
 *
 */
int CreateLabels() {
   color  bg.color    = C'212,208,200';
   string bg.fontName = "Webdings";
   int    bg.fontSize = 212;

   int x =  3;                   // X-Ausgangskoordinate
   int y = 73;                   // Y-Ausgangskoordinate
   int n = 10;                   // Counter für eindeutige Labels (mind. zweistellig)

   // Background
   string label = StringConcatenate(__NAME__, ".", n, ".Background");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, x);
      ObjectSet    (label, OBJPROP_YDISTANCE, y);
      ObjectSetText(label, "g", bg.fontSize, bg.fontName, bg.color);
      ObjectRegister(label);
   }
   else GetLastError();

   n++;
   label = StringConcatenate(__NAME__, ".", n, ".Background");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, x    );
      ObjectSet    (label, OBJPROP_YDISTANCE, y+196);
      ObjectSetText(label, "g", bg.fontSize, bg.fontName, bg.color);
      ObjectRegister(label);
   }
   else GetLastError();

   // Textlabel
   int yCoord = y + 4;
   for (int i=0; i < ArraySize(labels); i++) {
      n++;
      label = StringConcatenate(__NAME__, ".", n, ".", labels[i]);
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet    (label, OBJPROP_XDISTANCE, x+6);
            // größerer Zeilenabstand vor den folgenden Labeln
            static int fields[] = {I_POINT, I_ATR_D, I_STOPLEVEL, I_LOTSIZE, I_MARGINREQUIRED, I_SPREAD, I_SWAPLONG, I_ACCOUNT_LEVERAGE, I_SERVER_NAME};
            if (IntInArray(fields, i))
               yCoord += 8;
         ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, " ", fg.fontSize, fg.fontName);
         ObjectRegister(label);
         labels[i] = label;
      }
      else GetLastError();
   }

   return(catch("CreateLabels()"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int UpdateInfos() {
   string symbol           = Symbol();
   string accountCurrency  = AccountCurrency();
   bool   tradeAllowed     = (MarketInfo(symbol, MODE_TRADEALLOWED) && 1);
   color  fg.fontColor     = ifInt(tradeAllowed, fg.fontColor.Enabled, fg.fontColor.Disabled);

                                                                             ObjectSetText(labels[I_TRADEALLOWED  ], "Trading enabled: "+ ifString(tradeAllowed, "yes", "no"),                                                fg.fontSize, fg.fontName, fg.fontColor);
                                                                             ObjectSetText(labels[I_POINT         ], "Point size:  "    +                               NumberToStr(Point,    PriceFormat),                   fg.fontSize, fg.fontName, fg.fontColor);
   double tickSize         = MarketInfo(symbol, MODE_TICKSIZE );             ObjectSetText(labels[I_TICKSIZE      ], "Tick size:   "    +                               NumberToStr(tickSize, PriceFormat),                   fg.fontSize, fg.fontName, fg.fontColor);
   double tickValue        = MarketInfo(symbol, MODE_TICKVALUE);
   double pointValue       = MathDiv(tickValue, MathDiv(tickSize, Point));
   double pipValue         = PipPoints * pointValue;                         ObjectSetText(labels[I_PIPVALUE      ], "Pip value:  "     + ifString(!pipValue,       "", NumberToStr(pipValue, ".2+R") +" "+ accountCurrency), fg.fontSize, fg.fontName, fg.fontColor);

   double atr_d            = ixATR(NULL, PERIOD_D1,  14, 1); if (atr_d == EMPTY) return(last_error);
                                                                             ObjectSetText(labels[I_ATR_D         ], "ATR(d):     "     + ifString(!atr_d,          "", Round(atr_d/Pips) +" pip = "+ DoubleToStr(MathDiv(atr_d, Close[0])*100, 2) +"%"), fg.fontSize, fg.fontName, fg.fontColor);
   double atr_w            = ixATR(NULL, PERIOD_W1,  14, 1); if (atr_w == EMPTY) return(last_error);
                                                                             ObjectSetText(labels[I_ATR_W         ], "ATR(w):   "       + ifString(!atr_w,          "", Round(atr_w/Pips) +" pip = "+ DoubleToStr(MathDiv(atr_w, Close[0])*100, 2) +"%"), fg.fontSize, fg.fontName, fg.fontColor);
   double atr_m            = ixATR(NULL, PERIOD_MN1, 14, 1); if (atr_m == EMPTY) return(last_error);
                                                                             ObjectSetText(labels[I_ATR_M         ], "ATR(m):   "       + ifString(!atr_m,          "", Round(atr_m/Pips) +" pip = "+ DoubleToStr(MathDiv(atr_m, Close[0])*100, 2) +"%"+ ifString(!atr_w, "", " = "+ DoubleToStr(MathDiv(atr_m, atr_w), 1) +" ATR(w)")), fg.fontSize, fg.fontName, fg.fontColor);

   double stopLevel        = MarketInfo(symbol, MODE_STOPLEVEL  )/PipPoints; ObjectSetText(labels[I_STOPLEVEL     ], "Stop level:   "   +                               DoubleToStr(stopLevel,   Digits<<31>>31) +" pip",     fg.fontSize, fg.fontName, fg.fontColor);
   double freezeLevel      = MarketInfo(symbol, MODE_FREEZELEVEL)/PipPoints; ObjectSetText(labels[I_FREEZELEVEL   ], "Freeze level: "   +                               DoubleToStr(freezeLevel, Digits<<31>>31) +" pip",     fg.fontSize, fg.fontName, fg.fontColor);

   double lotSize          = MarketInfo(symbol, MODE_LOTSIZE);               ObjectSetText(labels[I_LOTSIZE       ], "Lot size:  "      + ifString(!lotSize,        "", NumberToStr(lotSize, ", .+") +" units"),              fg.fontSize, fg.fontName, fg.fontColor);
   double minLot           = MarketInfo(symbol, MODE_MINLOT );               ObjectSetText(labels[I_MINLOT        ], "Min lot:    "     + ifString(!minLot,         "", NumberToStr(minLot,  ", .+")),                        fg.fontSize, fg.fontName, fg.fontColor);
   double lotStep          = MarketInfo(symbol, MODE_LOTSTEP);               ObjectSetText(labels[I_LOTSTEP       ], "Lot step: "       + ifString(!lotStep,        "", NumberToStr(lotStep, ", .+")),                        fg.fontSize, fg.fontName, fg.fontColor);
   double maxLot           = MarketInfo(symbol, MODE_MAXLOT );               ObjectSetText(labels[I_MAXLOT        ], "Max lot:   "      + ifString(!maxLot,         "", NumberToStr(maxLot,  ", .+")),                        fg.fontSize, fg.fontName, fg.fontColor);

   double marginRequired   = MarketInfo(symbol, MODE_MARGINREQUIRED); if (marginRequired == -92233720368547760.) marginRequired = NULL;
   double lotValue         = MathDiv(Close[0], tickSize) * tickValue;
   double leverage         = MathDiv(lotValue, marginRequired);              ObjectSetText(labels[I_MARGINREQUIRED], "Margin required: "+ ifString(!marginRequired, "", NumberToStr(marginRequired, ", .2+R") +" "+ accountCurrency +"  (1:"+ Round(leverage) +")"), fg.fontSize, fg.fontName, ifInt(!marginRequired, fg.fontColor.Disabled, fg.fontColor));
   double marginHedged     = MarketInfo(symbol, MODE_MARGINHEDGED);
          marginHedged     = MathDiv(marginHedged, lotSize) * 100;           ObjectSetText(labels[I_MARGINHEDGED  ], "Margin hedged:  " + ifString(!marginRequired, "", ifString(!marginHedged, "none", Round(marginHedged) +"%")),               fg.fontSize, fg.fontName, ifInt(!marginRequired, fg.fontColor.Disabled, fg.fontColor));

   double spread           = MarketInfo(symbol, MODE_SPREAD)/PipPoints;      ObjectSetText(labels[I_SPREAD        ], "Spread:        "  + DoubleToStr(spread,      Digits<<31>>31) +" pip"+ ifString(!atr_w, "", " = "+ DoubleToStr(MathDiv(spread*Point, atr_w) * 100, 2) +"% ATR(w)"), fg.fontSize, fg.fontName, fg.fontColor);
   double commission       = GetCommission();
   double commissionPip    = NormalizeDouble(MathDiv(commission, pipValue), Digits+1-PipDigits);
                                                                             ObjectSetText(labels[I_COMMISSION    ], "Commission:  "    + NumberToStr(commission, ".2R") +" "+ accountCurrency +" = "+ NumberToStr(commissionPip, ".1+") +" pip", fg.fontSize, fg.fontName, fg.fontColor);
   double totalFees        = spread + commission;                            ObjectSetText(labels[I_TOTALFEES     ], "Total:       "                                                                                                            , fg.fontSize, fg.fontName, fg.fontColor);

   int    swapMode         = MarketInfo(symbol, MODE_SWAPTYPE );
   double swapLong         = MarketInfo(symbol, MODE_SWAPLONG );
   double swapShort        = MarketInfo(symbol, MODE_SWAPSHORT);
      double swapLongDaily, swapShortDaily, swapLongYearly, swapShortYearly;
      string strSwapLong, strSwapShort;

      if (swapMode == SCM_POINTS) {                                  // in points of quote currency
         swapLongDaily  = swapLong *Point/Pip; swapLongYearly  = MathDiv(swapLongDaily *Pip*365, Close[0]) * 100;
         swapShortDaily = swapShort*Point/Pip; swapShortYearly = MathDiv(swapShortDaily*Pip*365, Close[0]) * 100;
      }
      else {
         /*
         if (swapMode == SCM_INTEREST) {                             // TODO: prüfen "in percentage terms" z.B. LiteForex Aktien-CFDs
            //swapLongDaily  = swapLong *Close[0]/100/365/Pip; swapLongY  = swapLong;
            //swapShortDaily = swapShort*Close[0]/100/365/Pip; swapShortY = swapShort;
         }
         else if (swapMode == SCM_BASE_CURRENCY  ) {}                // as amount of base currency   (see "symbols.raw")
         else if (swapMode == SCM_MARGIN_CURRENCY) {}                // as amount of margin currency (see "symbols.raw")
         */
         strSwapLong  = ifString(!swapLong,  "none", SwapCalculationModeToStr(swapMode) +"  "+ NumberToStr(swapLong,  ".+"));
         strSwapShort = ifString(!swapShort, "none", SwapCalculationModeToStr(swapMode) +"  "+ NumberToStr(swapShort, ".+"));
         swapMode     = -1;
      }
      if (swapMode != -1) {
         if (!swapLong)  strSwapLong  = "none";
         else {
            if (MathAbs(swapLongDaily ) <= 0.05) swapLongDaily  = Sign(swapLongDaily ) * 0.1;
            strSwapLong  = NumberToStr(swapLongDaily,  "+.1R") +" pip = "+ NumberToStr(swapLongYearly,  "+.1R") +"% p.a.";
         }
         if (!swapShort) strSwapShort = "none";
         else {
            if (MathAbs(swapShortDaily) <= 0.05) swapShortDaily = Sign(swapShortDaily) * 0.1;
            strSwapShort = NumberToStr(swapShortDaily, "+.1R") +" pip = "+ NumberToStr(swapShortYearly, "+.1R") +"% p.a.";
         }
      }                                            ObjectSetText(labels[I_SWAPLONG        ], "Swap long:  "+ strSwapLong,                fg.fontSize, fg.fontName, fg.fontColor);
                                                   ObjectSetText(labels[I_SWAPSHORT       ], "Swap short: "+ strSwapShort,               fg.fontSize, fg.fontName, fg.fontColor);

   int    accountLeverage = AccountLeverage();     ObjectSetText(labels[I_ACCOUNT_LEVERAGE], "Account leverage:       "+ ifString(!accountLeverage, "", "1:"+ accountLeverage), fg.fontSize, fg.fontName, ifInt(!accountLeverage, fg.fontColor.Disabled, fg.fontColor));
   int    stopoutLevel    = AccountStopoutLevel(); ObjectSetText(labels[I_STOPOUT_LEVEL   ], "Account stopout level: " + ifString(!accountLeverage, "",  NumberToStr(NormalizeDouble(stopoutLevel, 2), ", .+") + ifString(AccountStopoutMode()==ASM_PERCENT, "%", " "+ accountCurrency)), fg.fontSize, fg.fontName, ifInt(!accountLeverage, fg.fontColor.Disabled, fg.fontColor));

   string serverName      = GetServerDirectory();  ObjectSetText(labels[I_SERVER_NAME     ], "Server:               "  + serverName,     fg.fontSize, fg.fontName, ifInt(!StringLen(serverName),     fg.fontColor.Disabled, fg.fontColor));
   string serverTimezone  = GetServerTimezone();
      string strOffset = "";
      if (StringLen(serverTimezone) > 0) {
         datetime lastTime = MarketInfo(symbol, MODE_TIME);
         if (lastTime > 0) {
            int tzOffset = GetServerToFxtTimeOffset(lastTime);
            if (tzOffset != EMPTY_VALUE)
               strOffset = ifString(tzOffset>= 0, "+", "-") + StringRight("0"+ Abs(tzOffset/HOURS), 2) + StringRight("0"+ tzOffset%HOURS, 2);
         }
         serverTimezone = serverTimezone + ifString(StringStartsWith(serverTimezone, "FXT"), "", " (FXT"+ strOffset +")");
      }
                                                   ObjectSetText(labels[I_SERVER_TIMEZONE ], "Server timezone:  "      + serverTimezone, fg.fontSize, fg.fontName, ifInt(!StringLen(serverTimezone), fg.fontColor.Disabled, fg.fontColor));

   string serverSession   = ifString(!StringLen(serverTimezone), "", ifString(!tzOffset, "00:00-24:00", DateToStr(D'1970.01.02' + tzOffset, "H:I-H:I")));

                                                   ObjectSetText(labels[I_SERVER_SESSION  ], "Server session:     "    + serverSession,  fg.fontSize, fg.fontName, ifInt(!StringLen(serverSession),  fg.fontColor.Disabled, fg.fontColor));
   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)
      return(NO_ERROR);
   return(catch("UpdateInfos(2)", error));

   ConvertCurrency(NULL, NULL, NULL);
}


/**
 * Konvertiert den angegebenen Betrag einer Währung in eine andere Währung.
 *
 * @param  double amount - Betrag
 * @param  string from   - Ausgangswährung
 * @param  string to     - Zielwährung
 *
 * @return double
 */
double ConvertCurrency(double amount, string from, string to) {
   double result = amount;

   if (NE(amount, 0)) {
      from = StringToUpper(from);
      to   = StringToUpper(to);
      if (from != to) {
         // direktes Currency-Pair suchen
         // bei Mißerfolg Crossrates zum USD bestimmen
         // Kurse ermitteln
         // Ergebnis berechnen
      }
   }

   static bool done;
   if (!done) {
      //debug("ConvertCurrency()   "+ NumberToStr(amount, ".2+") +" "+ from +" = "+ NumberToStr(result, ".2+R") +" "+ to);
      done = true;
   }
   return(result);
}
