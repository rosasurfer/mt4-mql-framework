/**
 * Display instrument specifications and properties.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#property indicator_chart_window

color  fgFontColorEnabled  = Blue;
color  fgFontColorDisabled = Gray;
string fgFontName          = "Tahoma";
int    fgFontSize          = 9;

string labels[] = {"TRADEALLOWED","POINT","TICKSIZE","PIPVALUE","ADR","STOPLEVEL","FREEZELEVEL","LOTSIZE","MINLOT","LOTSTEP","MAXLOT","MARGINREQUIRED","MARGINHEDGED","SPREAD","COMMISSION","TOTALFEES","SWAPLONG","SWAPSHORT","ACCOUNT_LEVERAGE","STOPOUT_LEVEL","SERVER_NAME","SERVER_TIMEZONE","SERVER_SESSION"};

#define I_TRADEALLOWED         0
#define I_POINT                1
#define I_TICKSIZE             2
#define I_PIPVALUE             3
#define I_ADR                  4
#define I_STOPLEVEL            5
#define I_FREEZELEVEL          6
#define I_LOTSIZE              7
#define I_MINLOT               8
#define I_LOTSTEP              9
#define I_MAXLOT              10
#define I_MARGINREQUIRED      11
#define I_MARGINHEDGED        12
#define I_SPREAD              13
#define I_COMMISSION          14
#define I_TOTALFEES           15
#define I_SWAPLONG            16
#define I_SWAPSHORT           17
#define I_ACCOUNT_LEVERAGE    18
#define I_STOPOUT_LEVEL       19
#define I_SERVER_NAME         20
#define I_SERVER_TIMEZONE     21
#define I_SERVER_SESSION      22


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   SetIndexLabel(0, NULL);          // "Data" window
   CreateChartObjects();
   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   UpdateInstrumentInfos();
   return(last_error);
}


/**
 * Create needed chart objects.
 *
 * @return int - error status
 */
int CreateChartObjects() {
   color  bgColor    = C'212,208,200';
   string bgFontName = "Webdings";
   int    bgFontSize = 192;

   int xPos =  3;                         // X start coordinate
   int yPos = 80;                         // Y start coordinate
   int n    = 10;                         // counter for unique labels (min. 2 digits)

   // background rectangles
   string label = ProgramName() +"."+ n +".background";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, xPos);
      ObjectSet    (label, OBJPROP_YDISTANCE, yPos);
      ObjectSetText(label, "g", bgFontSize, bgFontName, bgColor);
      RegisterObject(label);
   }
   else GetLastError();

   n++;
   label = ProgramName() +"."+ n +".background";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, xPos    );
      ObjectSet    (label, OBJPROP_YDISTANCE, yPos+136);
      ObjectSetText(label, "g", bgFontSize, bgFontName, bgColor);
      RegisterObject(label);
   }
   else GetLastError();

   // text labels
   int yCoord = yPos + 4;
   for (int i=0; i < ArraySize(labels); i++) {
      n++;
      label = ProgramName() +"."+ n +"."+ labels[i];
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet    (label, OBJPROP_XDISTANCE, xPos+6);
            // lines followed by extra space (paragraph end)
            static int fields[] = {I_POINT, I_ADR, I_STOPLEVEL, I_LOTSIZE, I_MARGINREQUIRED, I_SPREAD, I_SWAPLONG, I_ACCOUNT_LEVERAGE, I_SERVER_NAME};
            if (IntInArray(fields, i)) yCoord += 8;

         ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, " ", fgFontSize, fgFontName);
         RegisterObject(label);
         labels[i] = label;
      }
      else GetLastError();
   }
   return(catch("CreateChartObjects(1)"));
}


/**
 * Update instrument infos.
 *
 * @return int - error status
 */
int UpdateInstrumentInfos() {
   string symbol          = Symbol();
   string accountCurrency = AccountCurrency();
   bool   tradeAllowed    = (MarketInfo(symbol, MODE_TRADEALLOWED) && 1);
   color  fgFontColor     = ifInt(tradeAllowed, fgFontColorEnabled, fgFontColorDisabled);

                                                                            ObjectSetText(labels[I_TRADEALLOWED  ], "Trading enabled: "+ ifString(tradeAllowed, "yes", "no"),                        fgFontSize, fgFontName, fgFontColor);
                                                                            ObjectSetText(labels[I_POINT         ], "Point size: "     +                         NumberToStr(Point,    PriceFormat), fgFontSize, fgFontName, fgFontColor);
   double tickSize        = MarketInfo(symbol, MODE_TICKSIZE );             ObjectSetText(labels[I_TICKSIZE      ], "Tick size:  "     +                         NumberToStr(tickSize, PriceFormat), fgFontSize, fgFontName, fgFontColor);
   double tickValue       = MarketInfo(symbol, MODE_TICKVALUE);
   double pointValue      = MathDiv(tickValue, MathDiv(tickSize, Point));
   double pipValue        = PipPoints * pointValue;                         ObjectSetText(labels[I_PIPVALUE      ], "Pip value:  "     + ifString(!pipValue, "", NumberToStr(pipValue, ".2+R") +" "+ accountCurrency), fgFontSize, fgFontName, fgFontColor);

   double adr             = iADR();                                         ObjectSetText(labels[I_ADR           ], "ADR(20):  "       + ifString(!adr,      "", Round(adr/Pips) +" pip"),                     fgFontSize, fgFontName, fgFontColor);

   double stopLevel       = MarketInfo(symbol, MODE_STOPLEVEL  )/PipPoints; ObjectSetText(labels[I_STOPLEVEL     ], "Stop level:    "  +                         DoubleToStr(stopLevel,   Digits & 1) +" pip", fgFontSize, fgFontName, fgFontColor);
   double freezeLevel     = MarketInfo(symbol, MODE_FREEZELEVEL)/PipPoints; ObjectSetText(labels[I_FREEZELEVEL   ], "Freeze level: "   +                         DoubleToStr(freezeLevel, Digits & 1) +" pip", fgFontSize, fgFontName, fgFontColor);

   double lotSize         = MarketInfo(symbol, MODE_LOTSIZE);               ObjectSetText(labels[I_LOTSIZE       ], "Lot size:  "      + ifString(!lotSize,  "", NumberToStr(lotSize, ", .+") +" units"),      fgFontSize, fgFontName, fgFontColor);
   double minLot          = MarketInfo(symbol, MODE_MINLOT );               ObjectSetText(labels[I_MINLOT        ], "Min lot:   "      + ifString(!minLot,   "", NumberToStr(minLot,  ", .+")),                fgFontSize, fgFontName, fgFontColor);
   double lotStep         = MarketInfo(symbol, MODE_LOTSTEP);               ObjectSetText(labels[I_LOTSTEP       ], "Lot step: "       + ifString(!lotStep,  "", NumberToStr(lotStep, ", .+")),                fgFontSize, fgFontName, fgFontColor);
   double maxLot          = MarketInfo(symbol, MODE_MAXLOT );               ObjectSetText(labels[I_MAXLOT        ], "Max lot:  "       + ifString(!maxLot,   "", NumberToStr(maxLot,  ", .+")),                fgFontSize, fgFontName, fgFontColor);

   double marginRequired  = MarketInfo(symbol, MODE_MARGINREQUIRED); if (marginRequired == -92233720368547760.) marginRequired = NULL;
   double lotValue        = MathDiv(Close[0], tickSize) * tickValue;
   double leverage        = MathDiv(lotValue, marginRequired);              ObjectSetText(labels[I_MARGINREQUIRED], "Margin required: "+ ifString(!marginRequired, "", NumberToStr(marginRequired, ", .2+R") +" "+ accountCurrency +"  (1:"+ Round(leverage) +")"), fgFontSize, fgFontName, ifInt(!marginRequired, fgFontColorDisabled, fgFontColor));
   double marginHedged    = MarketInfo(symbol, MODE_MARGINHEDGED);
          marginHedged    = MathDiv(marginHedged, lotSize) * 100;           ObjectSetText(labels[I_MARGINHEDGED  ], "Margin hedged:  " + ifString(!marginRequired, "", ifString(!marginHedged, "none", Round(marginHedged) +"%")),                                  fgFontSize, fgFontName, ifInt(!marginRequired, fgFontColorDisabled, fgFontColor));

   double spread          = MarketInfo(symbol, MODE_SPREAD)/PipPoints;      ObjectSetText(labels[I_SPREAD        ], "Spread:        "  + DoubleToStr(spread, Digits & 1) +" pip"+ ifString(!adr, "", " = "+ DoubleToStr(MathDiv(spread, adr)*Pip * 100, 1) +"% ADR"), fgFontSize, fgFontName, fgFontColor);
   double commission      = GetCommission();
   double commissionPip   = NormalizeDouble(MathDiv(commission, pipValue), Digits+1-PipDigits);
                                                                            ObjectSetText(labels[I_COMMISSION    ], "Commission:  "    + ifString(IsEmpty(commission), "...", DoubleToStr(commission, 2) +" "+ accountCurrency +" = "+ NumberToStr(commissionPip, ".1+") +" pip"), fgFontSize, fgFontName, fgFontColor);
   double totalFees       = spread + commission;                            ObjectSetText(labels[I_TOTALFEES     ], "Total:           "+ ifString(IsEmpty(commission), "...", ""),                                                                                                 fgFontSize, fgFontName, fgFontColor);

   int    swapMode        = MarketInfo(symbol, MODE_SWAPTYPE );
   double swapLong        = MarketInfo(symbol, MODE_SWAPLONG );
   double swapShort       = MarketInfo(symbol, MODE_SWAPSHORT);
      double swapLongDaily, swapShortDaily, swapLongYearly, swapShortYearly;
      string sSwapLong, sSwapShort;

      if (swapMode == SCM_POINTS) {                                  // in points of quote currency
         swapLongDaily  = swapLong *Point/Pip; swapLongYearly  = MathDiv(swapLongDaily *Pip*365, Close[0]) * 100;
         swapShortDaily = swapShort*Point/Pip; swapShortYearly = MathDiv(swapShortDaily*Pip*365, Close[0]) * 100;
      }
      else {
         /*
         if (swapMode == SCM_INTEREST) {                             // TODO: check "in percentage terms", e.g. LiteForex stock CFDs
            //swapLongDaily  = swapLong *Close[0]/100/365/Pip; swapLongY  = swapLong;
            //swapShortDaily = swapShort*Close[0]/100/365/Pip; swapShortY = swapShort;
         }
         else if (swapMode == SCM_BASE_CURRENCY  ) {}                // as amount of base currency   (see "symbols.raw")
         else if (swapMode == SCM_MARGIN_CURRENCY) {}                // as amount of margin currency (see "symbols.raw")
         */
         sSwapLong  = ifString(!swapLong,  "none", SwapCalculationModeToStr(swapMode) +"  "+ NumberToStr(swapLong,  ".+"));
         sSwapShort = ifString(!swapShort, "none", SwapCalculationModeToStr(swapMode) +"  "+ NumberToStr(swapShort, ".+"));
         swapMode = -1;
      }
      if (swapMode != -1) {
         sSwapLong  = ifString(!swapLong,  "none", NumberToStr(swapLongDaily,  "+.1R") +" pip = "+ NumberToStr(swapLongYearly,  "+.1R") +"% p.a.");
         sSwapShort = ifString(!swapShort, "none", NumberToStr(swapShortDaily, "+.1R") +" pip = "+ NumberToStr(swapShortYearly, "+.1R") +"% p.a.");
      }                                            ObjectSetText(labels[I_SWAPLONG        ], "Swap long:  "+ sSwapLong,  fgFontSize, fgFontName, fgFontColor);
                                                   ObjectSetText(labels[I_SWAPSHORT       ], "Swap short: "+ sSwapShort, fgFontSize, fgFontName, fgFontColor);

   int    accountLeverage = AccountLeverage();     ObjectSetText(labels[I_ACCOUNT_LEVERAGE], "Account leverage:      "+ ifString(!accountLeverage, "", "1:"+ accountLeverage), fgFontSize, fgFontName, ifInt(!accountLeverage, fgFontColorDisabled, fgFontColor));
   int    stopoutLevel    = AccountStopoutLevel(); ObjectSetText(labels[I_STOPOUT_LEVEL   ], "Account stopout level: "+ ifString(!accountLeverage, "", ifString(AccountStopoutMode()==MSM_PERCENT, stopoutLevel +"%", stopoutLevel +".00 "+ accountCurrency)), fgFontSize, fgFontName, ifInt(!accountLeverage, fgFontColorDisabled, fgFontColor));

   string serverName      = GetAccountServer();    ObjectSetText(labels[I_SERVER_NAME     ], "Server:               "+  serverName, fgFontSize, fgFontName, ifInt(!StringLen(serverName), fgFontColorDisabled, fgFontColor));
   string serverTimezone  = GetServerTimezone();
      string strOffset = "";
      if (StringLen(serverTimezone) > 0) {
         datetime lastTime = MarketInfo(symbol, MODE_TIME);
         if (lastTime > 0) {
            int tzOffset = GetServerToFxtTimeOffset(lastTime);
            if (!IsEmptyValue(tzOffset))
               strOffset = ifString(tzOffset>= 0, "+", "-") + StrRight("0"+ Abs(tzOffset/HOURS), 2) + StrRight("0"+ tzOffset%HOURS, 2);
         }
         serverTimezone = serverTimezone + ifString(StrStartsWithI(serverTimezone, "FXT"), "", " (FXT"+ strOffset +")");
      }
                                                   ObjectSetText(labels[I_SERVER_TIMEZONE], "Server timezone:  "+ serverTimezone, fgFontSize, fgFontName, ifInt(!StringLen(serverTimezone), fgFontColorDisabled, fgFontColor));

   string serverSession = ifString(!StringLen(serverTimezone), "", ifString(!tzOffset, "00:00-24:00", GmtTimeFormat(D'1970.01.02' + tzOffset, "%H:%M-%H:%M")));

                                                   ObjectSetText(labels[I_SERVER_SESSION], "Server session:    "+ serverSession, fgFontSize, fgFontName, ifInt(!StringLen(serverSession), fgFontColorDisabled, fgFontColor));
   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)
      return(NO_ERROR);
   return(catch("UpdateInstrumentInfos(1)", error));
}


/**
 * Calculate and return the ADR (average daily range) which is implemented as an approximation of LWMA(20xADR(1)).
 *
 * @return double
 */
double iADR() {
   double adr1  = iATR(NULL, PERIOD_D1, 1, 1);     // TODO: convert to current timeframe and real ADR
   double adr5  = iATR(NULL, PERIOD_D1, 5, 1);
   double adr10 = iATR(NULL, PERIOD_D1, 10, 1);
   double adr20 = iATR(NULL, PERIOD_D1, 20, 1);

   return((adr1 + adr5 + adr10 + adr20)/4);
}
