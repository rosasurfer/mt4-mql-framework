/**
 * Zeigt die Eigenschaften eines Instruments an.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/indicator.mqh>

#property indicator_chart_window


color  bg.color              = C'212,208,200';
string bg.fontName           = "Webdings";
int    bg.fontSize           = 197;

color  fg.fontColor.Enabled  = Blue;
color  fg.fontColor.Disabled = Gray;
string fg.fontName           = "Tahoma";
int    fg.fontSize           = 9;

string labels[] = {"TRADEALLOWED","POINT","TICKSIZE","TICKVALUE","STOPLEVEL","FREEZELEVEL","LOTSIZE","MINLOT","LOTSTEP","MAXLOT","MARGINREQUIRED","MARGINHEDGED","SPREAD","COMMISSION","SWAPLONG","SWAPSHORT","ACCOUNT_LEVERAGE","STOPOUT_LEVEL","SERVER_NAME","SERVER_TIMEZONE","SERVER_SESSION"};

#define I_TRADEALLOWED         0
#define I_POINT                1
#define I_TICKSIZE             2
#define I_TICKVALUE            3
#define I_STOPLEVEL            4
#define I_FREEZELEVEL          5
#define I_LOTSIZE              6
#define I_MINLOT               7
#define I_LOTSTEP              8
#define I_MAXLOT               9
#define I_MARGINREQUIRED      10
#define I_MARGINHEDGED        11
#define I_SPREAD              12
#define I_COMMISSION          13
#define I_SWAPLONG            14
#define I_SWAPSHORT           15
#define I_ACCOUNT_LEVERAGE    16
#define I_STOPOUT_LEVEL       17
#define I_SERVER_NAME         18
#define I_SERVER_TIMEZONE     19
#define I_SERVER_SESSION      20


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
      ObjectSet    (label, OBJPROP_YDISTANCE, y+143);
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
            static int fields[] = {I_POINT, I_STOPLEVEL, I_LOTSIZE, I_MARGINREQUIRED, I_SPREAD, I_SWAPLONG, I_ACCOUNT_LEVERAGE, I_SERVER_NAME};
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

                                                                             ObjectSetText(labels[I_TRADEALLOWED  ], "Trading enabled: "+ ifString(tradeAllowed, "yes", "no"),                 fg.fontSize, fg.fontName, fg.fontColor);
                                                                             ObjectSetText(labels[I_POINT         ], "Point size:  "    + NumberToStr(Point, PriceFormat),                     fg.fontSize, fg.fontName, fg.fontColor);
   double tickSize         = MarketInfo(symbol, MODE_TICKSIZE);              ObjectSetText(labels[I_TICKSIZE      ], "Tick size:   "    + NumberToStr(tickSize, PriceFormat),                  fg.fontSize, fg.fontName, fg.fontColor);
   double tickValue        = MarketInfo(symbol, MODE_TICKVALUE);
   double pointValue       = tickValue/(tickSize/Point);
   double pipValue         = PipPoints * pointValue;                         ObjectSetText(labels[I_TICKVALUE     ], "Pip value:  "     + NumberToStr(pipValue, ".2+R") +" "+ accountCurrency, fg.fontSize, fg.fontName, fg.fontColor);

   double stopLevel        = MarketInfo(symbol, MODE_STOPLEVEL  )/PipPoints; ObjectSetText(labels[I_STOPLEVEL     ], "Stop level:   "   + DoubleToStr(stopLevel,   Digits<<31>>31) +" pip",    fg.fontSize, fg.fontName, fg.fontColor);
   double freezeLevel      = MarketInfo(symbol, MODE_FREEZELEVEL)/PipPoints; ObjectSetText(labels[I_FREEZELEVEL   ], "Freeze level: "   + DoubleToStr(freezeLevel, Digits<<31>>31) +" pip",    fg.fontSize, fg.fontName, fg.fontColor);

   double lotSize          = MarketInfo(symbol, MODE_LOTSIZE       );        ObjectSetText(labels[I_LOTSIZE       ], "Lot size:  "      + NumberToStr(lotSize, ", .+") +" units",              fg.fontSize, fg.fontName, fg.fontColor);
   double minLot           = MarketInfo(symbol, MODE_MINLOT        );        ObjectSetText(labels[I_MINLOT        ], "Min lot:    "     + NumberToStr(minLot, ", .+"),                         fg.fontSize, fg.fontName, fg.fontColor);
   double lotStep          = MarketInfo(symbol, MODE_LOTSTEP       );        ObjectSetText(labels[I_LOTSTEP       ], "Lot step: "       + NumberToStr(lotStep, ", .+"),                        fg.fontSize, fg.fontName, fg.fontColor);
   double maxLot           = MarketInfo(symbol, MODE_MAXLOT        );        ObjectSetText(labels[I_MAXLOT        ], "Max lot:   "      + NumberToStr(maxLot, ", .+"),                         fg.fontSize, fg.fontName, fg.fontColor);

   double marginRequired   = MarketInfo(symbol, MODE_MARGINREQUIRED); if (marginRequired == -92233720368547760.) marginRequired = NULL;
   double lotValue         = Close[0]/tickSize * tickValue;
   double leverage         = MathDiv(lotValue, marginRequired);              ObjectSetText(labels[I_MARGINREQUIRED], "Margin required: "+ ifString(!marginRequired, "", NumberToStr(marginRequired, ", .2+R") +" "+ accountCurrency +"  (1:"+ Round(leverage) +")"), fg.fontSize, fg.fontName, ifInt(!marginRequired, fg.fontColor.Disabled, fg.fontColor));
   double marginHedged     = MarketInfo(symbol, MODE_MARGINHEDGED  );
          marginHedged     = MathDiv(marginHedged, lotSize) * 100;           ObjectSetText(labels[I_MARGINHEDGED  ], "Margin hedged:  " + ifString(!marginRequired, "", Round(marginHedged) +"%"),                                                                   fg.fontSize, fg.fontName, ifInt(!marginRequired, fg.fontColor.Disabled, fg.fontColor));

   double spread           = MarketInfo(symbol, MODE_SPREAD     )/PipPoints; ObjectSetText(labels[I_SPREAD        ], "Spread:        "  + DoubleToStr(spread,      Digits<<31>>31) +" pip",    fg.fontSize, fg.fontName, fg.fontColor);
   double commission       = GetCommission();
   double commissionUSD    = ConvertCurrency(commission, accountCurrency, "USD");
   double commissionUSDLot = GetCommissionUSDLot(commissionUSD);
   double commissionPip    = NormalizeDouble(commission/pipValue, Digits+1-PipDigits);
                                                                             ObjectSetText(labels[I_COMMISSION    ], "Commission:  "    + NumberToStr(commission, ".2R") +" "+ accountCurrency +"/lot = "+ NumberToStr(commissionPip, ".1+") +" pip", fg.fontSize, fg.fontName, fg.fontColor);
                                                                           //ObjectSetText(labels[I_COMMISSION    ], "Commission:  $"   + NumberToStr(commission, ".2R") +"/USD-lot = "+ NumberToStr(commissionPip, ".1+") +" pip",                   fg.fontSize, fg.fontName, fg.fontColor);
   int    swapType         = MarketInfo(symbol, MODE_SWAPTYPE      );
   double swapLong         = MarketInfo(symbol, MODE_SWAPLONG      );
   double swapShort        = MarketInfo(symbol, MODE_SWAPSHORT     );
      double swapLongD, swapShortD, swapLongY, swapShortY;
      if (swapType == SCM_POINTS) {
         swapLongD  = swapLong *Point/Pip;            swapLongY  = swapLongD *Pip*360*100/Close[0];
         swapShortD = swapShort*Point/Pip;            swapShortY = swapShortD*Pip*360*100/Close[0];
      }
      else if (swapType == SCM_INTEREST) {
         swapLongD  = swapLong *Close[0]/100/360/Pip; swapLongY  = swapLong;
         swapShortD = swapShort*Close[0]/100/360/Pip; swapShortY = swapShort;
      }
      else {
         if      (swapType == SCM_BASE_CURRENCY  ) {}
         else if (swapType == SCM_MARGIN_CURRENCY) {} // Deposit-Currency
      }
      ObjectSetText(labels[I_SWAPLONG ], "Swap long:  "+ NumberToStr(swapLongD,  "+.1R") +" pip = "+ NumberToStr(swapLongY,  "+.1R") +"% p.a.", fg.fontSize, fg.fontName, fg.fontColor);
      ObjectSetText(labels[I_SWAPSHORT], "Swap short: "+ NumberToStr(swapShortD, "+.1R") +" pip = "+ NumberToStr(swapShortY, "+.1R") +"% p.a.", fg.fontSize, fg.fontName, fg.fontColor);

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
   return(catch("UpdateInfos()", error));
}


/**
 * Gibt die Commission-Rate des Accounts in USD je gehandelte USD-Lot zurück.
 *
 * @param  double stdCommission - Commission-Rate in USD je Lot der Basiswährung
 *
 * @return double
 */
double GetCommissionUSDLot(double stdCommission) {
   return(0);
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


/*
MODE_TRADEALLOWED       Trade is allowed for the symbol.
MODE_DIGITS             Count of digits after decimal point in the symbol prices. For the current symbol, it is stored in the predefined variable Digits

MODE_POINT              Point size in the quote currency.   => Auflösung des Preises
MODE_TICKSIZE           Tick size in the quote currency.    => kleinste Änderung des Preises, Vielfaches von MODE_POINT

MODE_SPREAD             Spread value in points.
MODE_STOPLEVEL          Stop level in points.
MODE_FREEZELEVEL        Order freeze level in points. If the execution price is within the defined range, the order cannot be modified, cancelled or closed.

MODE_LOTSIZE            Lot size in the base currency.
MODE_TICKVALUE          Tick value in the deposit currency.
MODE_MINLOT             Minimum permitted amount of a lot.
MODE_MAXLOT             Maximum permitted amount of a lot.
MODE_LOTSTEP            Step for changing lots.

MODE_MARGINCALCMODE     Margin calculation mode. 0 - Forex; 1 - CFD; 2 - Futures; 3 - CFD for indices.
MODE_MARGINREQUIRED     Free margin required to open 1 lot
MODE_MARGININIT         Initial margin requirements for 1 lot.
MODE_MARGINMAINTENANCE  Margin to maintain open positions calculated for 1 lot.
MODE_MARGINHEDGED       Hedged margin calculated for 1 lot.

MODE_SWAPTYPE           Swap calculation method. 0 - in points; 1 - in the symbol base currency; 2 - by interest; 3 - in the margin currency.
MODE_SWAPLONG           Swap of the long position.
MODE_SWAPSHORT          Swap of the short position.

MODE_TIME               The last incoming tick server time.
*/
