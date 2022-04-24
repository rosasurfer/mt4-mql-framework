/**
 * Display instrument specifications and more.
 *
 *
 * TODO:
 *  - add money volatility per "Index Point/Pip/Tick" of min-lot
 *  - simplify calculation of required account size for 20 units taking 50% of available margin before stopout
 *
 *  - replace usage of PipPoints by PipTicks
 *  - implement MarketInfoEx()
 *  - change "Pip value" to "Pip/Point/Tick value"
 *  - normalize quote prices to best-matching unit (pip/index point)
 *  - rewrite "Margin hedged" display: from 0% (full reduction) to 100% (no reduction)
 *  - implement trade server configuration
 *  - fix symbol configuration bugs using trade server overrides
 *  - add futures expiration times
 *  - add trade sessions
 *  - FxPro: if all symbols are unsubscribed at a weekend (trading disabled) a template reload enables the full display
 *  - remove debug messages "...Digits/MODE_DIGITS..."
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>

#property indicator_chart_window

color  fgFontColorEnabled  = Blue;
color  fgFontColorDisabled = Gray;
string fgFontName          = "Tahoma";
int    fgFontSize          = 9;

string labels[] = {"TRADEALLOWED","DIGITS","TICKSIZE","PIPVALUE","ADR","STOPLEVEL","FREEZELEVEL","LOTSIZE","MINLOT","LOTSTEP","MAXLOT","MARGIN_INITIAL","MARGIN_HEDGED","I_MARGIN_MINLOT","SPREAD","COMMISSION","TOTALFEES","SWAPLONG","SWAPSHORT","ACCOUNT_LEVERAGE","STOPOUT_LEVEL","SERVER_NAME","SERVER_TIMEZONE","SERVER_SESSION"};

#define I_TRADEALLOWED         0
#define I_DIGITS               1
#define I_TICKSIZE             2
#define I_PIPVALUE             3
#define I_ADR                  4
#define I_STOPLEVEL            5
#define I_FREEZELEVEL          6
#define I_LOTSIZE              7
#define I_MINLOT               8
#define I_LOTSTEP              9
#define I_MAXLOT              10
#define I_MARGIN_INITIAL      11
#define I_MARGIN_HEDGED       12
#define I_MARGIN_MINLOT       13
#define I_SPREAD              14
#define I_COMMISSION          15
#define I_TOTALFEES           16
#define I_SWAPLONG            17
#define I_SWAPSHORT           18
#define I_ACCOUNT_LEVERAGE    19
#define I_STOPOUT_LEVEL       20
#define I_SERVER_NAME         21
#define I_SERVER_TIMEZONE     22
#define I_SERVER_SESSION      23


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   SetIndexLabel(0, NULL);             // "Data" window
   CreateChartObjects();
   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   //double mPoint  = MarketInfo(Symbol(), MODE_POINT);
   //int    mDigits = MarketInfo(Symbol(), MODE_DIGITS);
   //if (Ticks == 1) debug("onTick(0.1)  Digits/MODE_DIGITS="+ Digits +"/"+ mDigits +"  Point/MODE_POINT="+ NumberToStr(Point, ".1+") +"/"+ NumberToStr(mPoint, ".1+") +"  PriceFormat="+ DoubleQuoteStr(PriceFormat) +"  mPointToStr(PriceFormat)="+ NumberToStr(mPoint, PriceFormat));

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
      ObjectSet    (label, OBJPROP_YDISTANCE, yPos+150);          // line height: 14 pt
      ObjectSetText(label, "g", bgFontSize, bgFontName, bgColor);
      RegisterObject(label);
   }
   else GetLastError();

   // text labels: lines with some additional margin-top
   int marginTop[] = {I_DIGITS, I_ADR, I_STOPLEVEL, I_LOTSIZE, I_MARGIN_INITIAL, I_SPREAD, I_SWAPLONG, I_ACCOUNT_LEVERAGE, I_SERVER_NAME};
   int size   = ArraySize(labels);
   int yCoord = yPos+4;

   for (int i=0; i < size; i++) {
      n++;
      label = ProgramName() +"."+ n +"."+ labels[i];
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet    (label, OBJPROP_XDISTANCE, xPos+6);
         if (IntInArray(marginTop, i)) yCoord += 8;
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
   bool   tradingEnabled  = (MarketInfo(symbol, MODE_TRADEALLOWED) != 0);
   color  fgFontColor     = ifInt(tradingEnabled, fgFontColorEnabled, fgFontColorDisabled);

   // calculate needed values
   double tickSize       = MarketInfo(symbol, MODE_TICKSIZE);
   double tickValue      = MarketInfo(symbol, MODE_TICKVALUE);
   double pointValue     = MathDiv(tickValue, MathDiv(tickSize, Point));
   double pipValue       = PipPoints * pointValue;
   double stopLevel      = MarketInfo(symbol, MODE_STOPLEVEL)  /PipPoints;
   double freezeLevel    = MarketInfo(symbol, MODE_FREEZELEVEL)/PipPoints;

   double adr            = iADR();
   double volaADR        = adr/Close[0] * 100;

   int    lotSize        = MarketInfo(symbol, MODE_LOTSIZE);
   double lotValue       = MathDiv(Close[0], tickSize) * tickValue;
   double minLot         = MarketInfo(symbol, MODE_MINLOT);
   double lotStep        = MarketInfo(symbol, MODE_LOTSTEP);
   double maxLot         = MarketInfo(symbol, MODE_MAXLOT);

   double marginInitial  = MarketInfo(symbol, MODE_MARGINREQUIRED); if (marginInitial == -92233720368547760.) marginInitial = 0;
   double marginHedged   = MathDiv(MarketInfo(symbol, MODE_MARGINHEDGED), lotSize) * 100;
   double marginMinLot   = marginInitial * minLot;
   double symbolLeverage = MathDiv(lotValue, marginInitial);

   double spreadPip      = MarketInfo(symbol, MODE_SPREAD)/PipPoints;
   double commission     = GetCommission();
   double commissionPip  = NormalizeDouble(MathDiv(commission, pipValue), Max(Digits+1, 2));

   // populate display
   ObjectSetText(labels[I_TRADEALLOWED  ], "Trading enabled: "    + ifString(tradingEnabled, "yes", "no"),                                                                                                              fgFontSize, fgFontName, fgFontColor);

   ObjectSetText(labels[I_DIGITS        ], "Digits:      "        +                         Digits,                                                                                                                     fgFontSize, fgFontName, fgFontColor);
   ObjectSetText(labels[I_TICKSIZE      ], "Tick size:  "         +                         NumberToStr(tickSize, PriceFormat),                                                                                         fgFontSize, fgFontName, fgFontColor);
   ObjectSetText(labels[I_PIPVALUE      ], "Pip value:  "         + ifString(!pipValue, "", NumberToStr(pipValue, ".2+R") +" "+ accountCurrency),                                                                       fgFontSize, fgFontName, fgFontColor);

   ObjectSetText(labels[I_ADR           ], "ADR(20):  "           + ifString(!adr,   "n/a", PipToStr(adr/Pip, true, true) +" = "+ NumberToStr(NormalizeDouble(volaADR, 2), ".0+") +"%"),                                fgFontSize, fgFontName, fgFontColor);

   ObjectSetText(labels[I_STOPLEVEL     ], "Stop level:    "      +                         DoubleToStr(stopLevel,   Digits & 1) +" pip",                                                                               fgFontSize, fgFontName, fgFontColor);
   ObjectSetText(labels[I_FREEZELEVEL   ], "Freeze level: "       +                         DoubleToStr(freezeLevel, Digits & 1) +" pip",                                                                               fgFontSize, fgFontName, fgFontColor);

   ObjectSetText(labels[I_LOTSIZE       ], "Lot size:  "          + ifString(!lotSize,  "", NumberToStr(lotSize, ",'.+") +" unit"+ Pluralize(lotSize)),                                                                 fgFontSize, fgFontName, fgFontColor);
   ObjectSetText(labels[I_MINLOT        ], "Min lot:   "          + ifString(!minLot,   "", NumberToStr(minLot,  ",'.+")),                                                                                              fgFontSize, fgFontName, fgFontColor);
   ObjectSetText(labels[I_LOTSTEP       ], "Lot step: "           + ifString(!lotStep,  "", NumberToStr(lotStep, ",'.+")),                                                                                              fgFontSize, fgFontName, fgFontColor);
   ObjectSetText(labels[I_MAXLOT        ], "Max lot:  "           + ifString(!maxLot,   "", NumberToStr(maxLot,  ",'.+")),                                                                                              fgFontSize, fgFontName, fgFontColor);

   ObjectSetText(labels[I_MARGIN_INITIAL], "Margin initial:      "+ ifString(!marginInitial, "", NumberToStr(marginInitial, ",'.2R") +" "+ accountCurrency +"  (1:"+ Round(symbolLeverage) +")"),                       fgFontSize, fgFontName, fgFontColor);
   ObjectSetText(labels[I_MARGIN_HEDGED ], "Margin hedged:  "     + ifString(!marginInitial, "", ifString(!marginHedged, "none", Round(marginHedged) +"%")),                                                            fgFontSize, fgFontName, fgFontColor);
   ObjectSetText(labels[I_MARGIN_MINLOT ], "Margin minLot:   "    + ifString(!marginMinLot,  "", NumberToStr(marginMinLot, ",'.2R") +" "+ accountCurrency),                                                             fgFontSize, fgFontName, fgFontColor);

   ObjectSetText(labels[I_SPREAD        ], "Spread:        "      + PipToStr(spreadPip, true, true) + ifString(!adr, "", " = "+ DoubleToStr(MathDiv(spreadPip, adr)*Pip * 100, 1) +"% of ADR"),                         fgFontSize, fgFontName, fgFontColor);
   ObjectSetText(labels[I_COMMISSION    ], "Commission:  "        + ifString(!commission, "-", DoubleToStr(commission, 2) +" "+ accountCurrency +" = "+ NumberToStr(NormalizeDouble(commissionPip, 2), ".1+") +" pip"), fgFontSize, fgFontName, fgFontColor);
   ObjectSetText(labels[I_TOTALFEES     ], "Total cost:    "      + ifString(!commission, "-", NumberToStr(NormalizeDouble(spreadPip + commissionPip, 2), ".1+") +" pip"),                                              fgFontSize, fgFontName, fgFontColor);

   int    swapMode        = MarketInfo(symbol, MODE_SWAPTYPE );
   double swapLong        = MarketInfo(symbol, MODE_SWAPLONG );
   double swapShort       = MarketInfo(symbol, MODE_SWAPSHORT);
   double swapLongDaily, swapShortDaily, swapLongYearly, swapShortYearly;
   string sSwapLong="", sSwapShort="";

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
   }

                                                   ObjectSetText(labels[I_SWAPLONG        ], "Swap long:  "+ sSwapLong,  fgFontSize, fgFontName, fgFontColor);
                                                   ObjectSetText(labels[I_SWAPSHORT       ], "Swap short: "+ sSwapShort, fgFontSize, fgFontName, fgFontColor);

   int    accountLeverage = AccountLeverage();     ObjectSetText(labels[I_ACCOUNT_LEVERAGE], "Account leverage:      "+ ifString(!accountLeverage, "", "1:"+ accountLeverage), fgFontSize, fgFontName, ifInt(!accountLeverage, fgFontColorDisabled, fgFontColor));
   int    stopoutLevel    = AccountStopoutLevel(); ObjectSetText(labels[I_STOPOUT_LEVEL   ], "Account stopout level: "+ ifString(!accountLeverage, "", ifString(AccountStopoutMode()==MSM_PERCENT, stopoutLevel +"%", stopoutLevel +".00 "+ accountCurrency)), fgFontSize, fgFontName, ifInt(!accountLeverage, fgFontColorDisabled, fgFontColor));

   string serverName      = GetAccountServer();    ObjectSetText(labels[I_SERVER_NAME     ], "Server:               "+ serverName, fgFontSize, fgFontName, ifInt(!StringLen(serverName), fgFontColorDisabled, fgFontColor));
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

   string serverSession = ifString(serverTimezone=="", "", ifString(!tzOffset, "00:00-24:00", GmtTimeFormat(D'1970.01.02' + tzOffset, "%H:%M-%H:%M")));
                                                   ObjectSetText(labels[I_SERVER_SESSION], "Server session:    "+ serverSession, fgFontSize, fgFontName, ifInt(!StringLen(serverSession), fgFontColorDisabled, fgFontColor));
   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)
      return(NO_ERROR);
   return(catch("UpdateInstrumentInfos(1)", error));
}


/**
 * Calculate and return the average daily range. Implemented as LWMA(20, ATR(1)).
 *
 * @return double - ADR in absolute terms or NULL in case of errors
 */
double iADR() {
   static double adr;                                       // TODO: invalidate static cache on BarOpen(D1)
   if (!adr) {
      double ranges[];
      int maPeriods = 20;
      ArrayResize(ranges, maPeriods);
      ArraySetAsSeries(ranges, true);
      for (int i=0; i < maPeriods; i++) {
         ranges[i] = iATR(NULL, PERIOD_D1, 1, i+1);         // TODO: convert to current timeframe for non-FXT brokers
      }
      adr = iMAOnArray(ranges, WHOLE_ARRAY, maPeriods, 0, MODE_LWMA, 0);
   }
   return(adr);

   CalculateLeverage(NULL);
   CalculateLots(NULL);
   CalculateVola();
}


/**
 * Calculate the performance volatility of an unleveraged position per ADR. Allows to compare the effective volatility of
 * different instruments.
 *
 * @return double - equity change of an unleveraged position in percent or NULL in case of errors
 */
double CalculateVola() {
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double lotValue  = MathDiv(Close[0], tickSize) * tickValue;          // value of 1 lot in account currency
   double vola      = MathDiv(1, lotValue) * tickValue * MathDiv(iADR(), tickSize);
   return(vola * 100);
}


/**
 * Calculate and return the lots for the specified equity change per ADR.
 *
 * @param  double percent - equity change in percent
 *
 * @return double - lots or NULL in case of errors
 */
double CalculateLots(double percent) {
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double equity    = AccountEquity() - AccountCredit() + GetExternalAssets();
   double amount    = percent/100 * equity;                             // equity amount in account currency
   double adr       = MathDiv(iADR(), tickSize);                        // ADR in ticks
   double lots      = MathDiv(MathDiv(amount, adr), tickValue);         // lots for amount and ADR

   // normalize the result
   if (lots > 0) {                                                                              // max. 6.7% per step
      if      (lots <=    0.03) lots = NormalizeDouble(MathRound(lots/  0.001) *   0.001, 3);   //     0-0.03: multiple of   0.001
      else if (lots <=   0.075) lots = NormalizeDouble(MathRound(lots/  0.002) *   0.002, 3);   // 0.03-0.075: multiple of   0.002
      else if (lots <=    0.1 ) lots = NormalizeDouble(MathRound(lots/  0.005) *   0.005, 3);   //  0.075-0.1: multiple of   0.005
      else if (lots <=    0.3 ) lots = NormalizeDouble(MathRound(lots/  0.01 ) *   0.01 , 2);   //    0.1-0.3: multiple of   0.01
      else if (lots <=    0.75) lots = NormalizeDouble(MathRound(lots/  0.02 ) *   0.02 , 2);   //   0.3-0.75: multiple of   0.02
      else if (lots <=    1.2 ) lots = NormalizeDouble(MathRound(lots/  0.05 ) *   0.05 , 2);   //   0.75-1.2: multiple of   0.05
      else if (lots <=   10.  ) lots = NormalizeDouble(MathRound(lots/  0.1  ) *   0.1  , 1);   //     1.2-10: multiple of   0.1
      else if (lots <=   30.  ) lots =       MathRound(MathRound(lots/  1    ) *   1       );   //      12-30: multiple of   1
      else if (lots <=   75.  ) lots =       MathRound(MathRound(lots/  2    ) *   2       );   //      30-75: multiple of   2
      else if (lots <=  120.  ) lots =       MathRound(MathRound(lots/  5    ) *   5       );   //     75-120: multiple of   5
      else if (lots <=  300.  ) lots =       MathRound(MathRound(lots/ 10    ) *  10       );   //    120-300: multiple of  10
      else if (lots <=  750.  ) lots =       MathRound(MathRound(lots/ 20    ) *  20       );   //    300-750: multiple of  20
      else if (lots <= 1200.  ) lots =       MathRound(MathRound(lots/ 50    ) *  50       );   //   750-1200: multiple of  50
      else                      lots =       MathRound(MathRound(lots/100    ) * 100       );   //   1200-...: multiple of 100
   }
   return(lots);
}


/**
 * Calculate and return the leverage for the specified lotsize using the current account size.
 *
 * @param  double lots - lotsize
 *
 * @return double - resulting leverage value or NULL in case of errors
 */
double CalculateLeverage(double lots) {
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double equity    = AccountEquity() - AccountCredit() + GetExternalAssets();

   double lotValue        = MathDiv(Close[0], tickSize) * tickValue;    // value of 1 lot in account currency
   double unleveragedLots = MathDiv(equity, lotValue);                  // unleveraged lotsize
   double leverage        = MathDiv(lots, unleveragedLots);             // leverage of the specified lotsize

   return(leverage);
}
