/**
 * Display instrument specifications and related infos.
 *
 *
 * TODO:
 *  - rewrite "Margin hedged" display: from 0% (full reduction) to 100% (no reduction)
 *  - replace usage of PipPoints by PipTicks
 *  - implement MarketInfoEx()
 *  - change "Pip value" to "Pip/Point/Tick value"
 *  - normalize quote prices to best-matching unit (pip/index point)
 *  - implement trade server configuration
 *  - fix symbol configuration bugs using trade server overrides
 *  - add futures expiration times
 *  - add trade sessions
 *  - FxPro: if all symbols are unsubscribed at a weekend (trading disabled) a template reload enables the full display
 *  - remove debug messages "...Digits/MODE_DIGITS..."
 *  - get an instrument's base currency: https://www.mql5.com/en/code/28029#
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    AccountSize.NumberOfUnits  = 20;     // number of available bullets of MODE_MINLOT size
extern int    AccountSize.MaxRiskPerUnit = 10;     // max. risk per unit in % on an ADR move against it
extern int    AccountSize.FreeMargin     = 25;     // max. margin utilization: required free margin in %

extern double StopLoss.Size              = 20;     // in pip to calculate risk of MODE_MINLOT position

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/iADR.mqh>

#property indicator_chart_window

color  fontColorEnabled  = Blue;
color  fontColorDisabled = Gray;
string fontName          = "Tahoma";
int    fontSize          = 9;

string labels[] = {"TRADEALLOWED","DIGITS","TICKSIZE","PIPVALUE","ADR","STOPLEVEL","FREEZELEVEL","LOTSIZE","LOTSTEP","MINLOT","STOPLOSS_SIZE","MAXLOT","MARGIN_INITIAL","MARGIN_INITIAL_DATA","MARGIN_MINLOT","MARGIN_MINLOT_DATA","MARGIN_MAINTENANCE","MARGIN_MAINTENANCE_DATA","MARGIN_HEDGED","MARGIN_HEDGED_DATA","SPREAD","SPREAD_DATA","COMMISSION","COMMISSION_DATA","TOTAL_COST","TOTAL_COST_DATA","SWAPLONG","SWAPLONG_DATA","SWAPSHORT","SWAPSHORT_DATA","ACCOUNT_LEVERAGE","ACCOUNT_LEVERAGE_DATA","ACCOUNT_STOPOUT","ACCOUNT_STOPOUT_DATA","ACCOUNT_MM","ACCOUNT_MM_DATA","ACCOUNT_REQUIRED","ACCOUNT_REQUIRED_DATA","SERVER_NAME","SERVER_NAME_DATA","SERVER_TIMEZONE","SERVER_TIMEZONE_DATA","SERVER_SESSION","SERVER_SESSION_DATA"};

#define I_TRADEALLOWED             0
#define I_DIGITS                   1
#define I_TICKSIZE                 2
#define I_PIPVALUE                 3
#define I_ADR                      4
#define I_STOPLEVEL                5
#define I_FREEZELEVEL              6
#define I_LOTSIZE                  7
#define I_LOTSTEP                  8
#define I_MINLOT                   9
#define I_STOPLOSS_SIZE           10
#define I_MAXLOT                  11
#define I_MARGIN_INITIAL          12
#define I_MARGIN_INITIAL_DATA     13
#define I_MARGIN_MINLOT           14
#define I_MARGIN_MINLOT_DATA      15
#define I_MARGIN_MAINTENANCE      16
#define I_MARGIN_MAINTENANCE_DATA 17
#define I_MARGIN_HEDGED           18
#define I_MARGIN_HEDGED_DATA      19
#define I_SPREAD                  20
#define I_SPREAD_DATA             21
#define I_COMMISSION              22
#define I_COMMISSION_DATA         23
#define I_TOTAL_COST              24
#define I_TOTAL_COST_DATA         25
#define I_SWAPLONG                26
#define I_SWAPLONG_DATA           27
#define I_SWAPSHORT               28
#define I_SWAPSHORT_DATA          29
#define I_ACCOUNT_LEVERAGE        30
#define I_ACCOUNT_LEVERAGE_DATA   31
#define I_ACCOUNT_STOPOUT         32
#define I_ACCOUNT_STOPOUT_DATA    33
#define I_ACCOUNT_MM              34
#define I_ACCOUNT_MM_DATA         35
#define I_ACCOUNT_REQUIRED        36
#define I_ACCOUNT_REQUIRED_DATA   37
#define I_SERVER_NAME             38
#define I_SERVER_NAME_DATA        39
#define I_SERVER_TIMEZONE         40
#define I_SERVER_TIMEZONE_DATA    41
#define I_SERVER_SESSION          42
#define I_SERVER_SESSION_DATA     43


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
   string indicatorName = ProgramName(MODE_NICE);
   color  bgColor    = C'212,208,200';
   string bgFontName = "Webdings";
   int    bgFontSize = 238;

   int xPos =  3;                         // X start coordinate
   int yPos = 83;                         // Y start coordinate
   int n    = 10;                         // counter for unique labels (min. 2 digits)

   // background rectangles
   string label = indicatorName +"."+ n +".background";
   if (ObjectFind(label) == 0) ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, xPos);
      ObjectSet    (label, OBJPROP_YDISTANCE, yPos);
      ObjectSetText(label, "g", bgFontSize, bgFontName, bgColor);
      RegisterObject(label);
   }
   else GetLastError();

   n++;
   label = indicatorName +"."+ n +".background";
   if (ObjectFind(label) == 0) ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, xPos);
      ObjectSet    (label, OBJPROP_YDISTANCE, yPos+124);          // line height: 14 pt
      ObjectSetText(label, "g", bgFontSize, bgFontName, bgColor);
      RegisterObject(label);
   }
   else GetLastError();

   // text labels: lines with additional margin-top
   int marginTop  [] = {I_DIGITS, I_ADR, I_STOPLEVEL, I_LOTSIZE, I_MARGIN_INITIAL, I_MARGIN_INITIAL_DATA, I_SPREAD, I_SWAPLONG, I_ACCOUNT_LEVERAGE, I_SERVER_NAME};
   int col2Lots   [] = {I_STOPLOSS_SIZE};
   int col2Margin [] = {I_MARGIN_INITIAL_DATA, I_MARGIN_MINLOT_DATA, I_MARGIN_MAINTENANCE_DATA, I_MARGIN_HEDGED_DATA};
   int col2Spread [] = {I_SPREAD_DATA, I_COMMISSION_DATA, I_TOTAL_COST_DATA};
   int col2Swap   [] = {I_SWAPLONG_DATA, I_SWAPSHORT_DATA};
   int col2Account[] = {I_ACCOUNT_LEVERAGE_DATA, I_ACCOUNT_STOPOUT_DATA, I_ACCOUNT_MM_DATA, I_ACCOUNT_REQUIRED_DATA};
   int col2Server [] = {I_SERVER_NAME_DATA, I_SERVER_TIMEZONE_DATA, I_SERVER_SESSION_DATA};

   int size = ArraySize(labels);
   int xCoord, yCoord = yPos + 4;

   for (int i=0; i < size; i++) {
      n++;
      label = indicatorName +"."+ n +"."+ labels[i];
      if (ObjectFind(label) == 0) ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);

         if (IntInArray(col2Lots, i)) {                  // lots column 2
            xCoord = xPos + 148;
            yCoord -= 16;
         }
         else if (IntInArray(col2Margin, i)) {           // margin column 2
            xCoord = xPos + 148;
            yCoord -= 16;
         }
         else if (IntInArray(col2Spread, i)) {           // spread column 2
            xCoord = xPos + 148;
            yCoord -= 16;
         }
         else if (IntInArray(col2Swap, i)) {             // swap column 2
            xCoord = xPos + 148;
            yCoord -= 16;
         }
         else if (IntInArray(col2Account, i)) {          // account column 2
            xCoord = xPos + 148;
            yCoord -= 16;
         }
         else if (IntInArray(col2Server, i)) {           // server column 2
            xCoord = xPos + 148;
            yCoord -= 16;
         }
         else {                                          // all remaining fields: column 1
            xCoord = xPos + 6;
            if (IntInArray(marginTop, i)) yCoord += 8;
         }

         ObjectSet(label, OBJPROP_XDISTANCE, xCoord);
         ObjectSet(label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, " ", fontSize, fontName);
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
   bool   tradingEnabled  = (MarketInfo(symbol, MODE_TRADEALLOWED) != 0);
   color  fontColor       = ifInt(tradingEnabled, fontColorEnabled, fontColorDisabled);

   string accountCurrency = AccountCurrency();
   int    accountLeverage = AccountLeverage();
   int    accountStopout  = AccountStopoutLevel();
   int    stopoutMode     = AccountStopoutMode();

   // calculate required values
   double tickSize    = MarketInfo(symbol, MODE_TICKSIZE);
   double tickValue   = MarketInfo(symbol, MODE_TICKVALUE);
   double pointValue  = MathDiv(tickValue, MathDiv(tickSize, Point));
   double pipValue    = PipPoints * pointValue;
   double stopLevel   = MarketInfo(symbol, MODE_STOPLEVEL)  /PipPoints;
   double freezeLevel = MarketInfo(symbol, MODE_FREEZELEVEL)/PipPoints;

   double adr         = GetADR(); if (!adr && last_error && last_error!=ERS_TERMINAL_NOT_YET_READY) return(last_error);
   double volaPerADR  = adr/Close[0] * 100;                   // instrument volatility per ADR move in percent

   int    lotSize     = MarketInfo(symbol, MODE_LOTSIZE);
   double lotValue    = MathDiv(Close[0], tickSize) * tickValue;
   double lotStep     = MarketInfo(symbol, MODE_LOTSTEP);
   double minLot      = MarketInfo(symbol, MODE_MINLOT);
   double maxLot      = MarketInfo(symbol, MODE_MAXLOT);

   double stopSize        = StopLoss.Size * Pip;
   double stopValue       = stopSize/Pip * pipValue * minLot;
   double accountEquity   = AccountEquity() - AccountCredit() + GetExternalAssets();
   double stopPct         = MathDiv(stopValue, accountEquity) * 100;

   double marginInitial   = MarketInfo(symbol, MODE_MARGINREQUIRED); if (Symbol() == "#Germany40")             marginInitial = 751.93;    // TODO: implement MarketInfoEx() with overrides
                                                                     if (marginInitial == -92233720368547760.) marginInitial = 0;
   double marginMinLot    = marginInitial * minLot;
   double symbolLeverage  = MathDiv(lotValue, marginInitial);
   double marginMaintnc   = ifDouble(stopoutMode==MSM_PERCENT, marginInitial * accountStopout/100, marginInitial);
   double maintncLeverage = MathDiv(lotValue, marginMaintnc);
   double marginHedged    = MathDiv(MarketInfo(symbol, MODE_MARGINHEDGED), lotSize) * 100;

   double spreadPip       = MarketInfo(symbol, MODE_SPREAD)/PipPoints;
   double commission      = GetCommission();
   double commissionPip   = NormalizeDouble(MathDiv(commission, pipValue), Max(Digits+1, 2));

   int    swapMode        = MarketInfo(symbol, MODE_SWAPTYPE);
   double swapLong        = MarketInfo(symbol, MODE_SWAPLONG);
   double swapShort       = MarketInfo(symbol, MODE_SWAPSHORT);
   double swapLongD, swapShortD, swapLongY, swapShortY;
   string sSwapLong=" ", sSwapShort=" ";

   if (swapMode == SCM_POINTS) {                                  // in points of quote currency
      swapLongD  = swapLong *Point/Pip; swapLongY  = MathDiv(swapLongD *Pip*360, Close[0]) * 100;
      swapShortD = swapShort*Point/Pip; swapShortY = MathDiv(swapShortD*Pip*360, Close[0]) * 100;
   }
   else {
      /*
      if (swapMode == SCM_INTEREST) {                             // TODO: check "in percentage terms", e.g. LiteForex stock CFDs
         //swapLongD  = swapLong *Close[0]/100/360/Pip; swapLong  = swapLong;
         //swapShortD = swapShort*Close[0]/100/360/Pip; swapShort = swapShort;
      }
      else if (swapMode == SCM_BASE_CURRENCY  ) {}                // as amount of base currency   (see "symbols.raw")
      else if (swapMode == SCM_MARGIN_CURRENCY) {}                // as amount of margin currency (see "symbols.raw")
      */
      sSwapLong  = ifString(!swapLong,  "none", SwapCalculationModeToStr(swapMode) +"  "+ NumberToStr(swapLong,  ".+"));
      sSwapShort = ifString(!swapShort, "none", SwapCalculationModeToStr(swapMode) +"  "+ NumberToStr(swapShort, ".+"));
      swapMode = -1;
   }
   if (swapMode != -1) {
      sSwapLong  = ifString(!swapLong,  "none", NumberToStr(swapLongD,  "+.1R") +" pip = "+ NumberToStr(swapLongY,  "+.1R") +"% p.a.");
      sSwapShort = ifString(!swapShort, "none", NumberToStr(swapShortD, "+.1R") +" pip = "+ NumberToStr(swapShortY, "+.1R") +"% p.a.");
   }

   int    requiredUnits   = AccountSize.NumberOfUnits;            // units of MODE_MINLOT size
   int    maxUsedMargin   = 100 - AccountSize.FreeMargin;         // max. margin utilization
   double fullLots        = requiredUnits * minLot;
   double fullLotsMargin  = fullLots * marginMaintnc;             // calculate account size using marginMaintenance
   double accountRequired = MathDiv(fullLotsMargin, maxUsedMargin) * 100;

   fullLotsMargin = fullLots * marginInitial;                     // check whether account has enough buying power
   if (accountRequired < fullLotsMargin) {                        //
      accountRequired = fullLotsMargin;                           // if not re-calculate account size using marginInitial
   }

   double unleveragedLots  = MathDiv(accountRequired, lotValue);
   double fullLotsLeverage = MathDiv(fullLots, unleveragedLots);

   string serverName = GetAccountServer();
   string serverTimezone = GetServerTimezone(), strOffset="";
   if (serverTimezone != "") {
      datetime lastTime = MarketInfo(symbol, MODE_TIME);
      if (lastTime > 0) {
         int tzOffset = GetServerToFxtTimeOffset(lastTime);
         if (!IsEmptyValue(tzOffset)) strOffset = ifString(tzOffset>= 0, "+", "-") + StrRight("0"+ Abs(tzOffset/HOURS), 2) + StrRight("0"+ tzOffset%HOURS, 2);
      }
      serverTimezone = serverTimezone + ifString(StrStartsWithI(serverTimezone, "FXT"), "", " (FXT"+ strOffset +")");
   }
   string serverSession = ifString(serverTimezone=="", "", ifString(!tzOffset, "00:00-24:00", GmtTimeFormat(D'1970.01.02' + tzOffset, "%H:%M-%H:%M")));

   // populate display
   ObjectSetText(labels[I_TRADEALLOWED           ], "Trading enabled: "+ ifString(tradingEnabled, "yes", "no"),                                                                                                                fontSize, fontName, fontColor);

   ObjectSetText(labels[I_DIGITS                 ], "Digits:      "    +                         Digits,                                                                                                                       fontSize, fontName, fontColor);
   ObjectSetText(labels[I_TICKSIZE               ], "Tick size:  "     +                         NumberToStr(tickSize, PriceFormat),                                                                                           fontSize, fontName, fontColor);
   ObjectSetText(labels[I_PIPVALUE               ], "Pip value:  "     + ifString(!pipValue, "", NumberToStr(pipValue, ".2+R") +" "+ accountCurrency),                                                                         fontSize, fontName, fontColor);

   ObjectSetText(labels[I_ADR                    ], "ADR(20):  "       + ifString(!adr,   "n/a", PipToStr(adr/Pip, true, true) +" = "+ NumberToStr(NormalizeDouble(volaPerADR, 2), ".0+") +"%"),                               fontSize, fontName, fontColor);

   ObjectSetText(labels[I_STOPLEVEL              ], "Stop level:    "  +                         DoubleToStr(stopLevel,   Digits & 1) +" pip",                                                                                 fontSize, fontName, fontColor);
   ObjectSetText(labels[I_FREEZELEVEL            ], "Freeze level: "   +                         DoubleToStr(freezeLevel, Digits & 1) +" pip",                                                                                 fontSize, fontName, fontColor);

   ObjectSetText(labels[I_LOTSIZE                ], "Lot size:  "      + ifString(!lotSize,  "", NumberToStr(lotSize, ",'.+") +" unit"+ Pluralize(lotSize)),                                                                   fontSize, fontName, fontColor);
   ObjectSetText(labels[I_LOTSTEP                ], "Lot step: "       + ifString(!lotStep,  "", NumberToStr(lotStep, ".+")),                                                                                                  fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MINLOT                 ], "Min lot:   "      + ifString(!minLot,   "", NumberToStr(minLot,  ".+")), fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MAXLOT                 ], "Max lot:  "       + ifString(!maxLot,   "", NumberToStr(maxLot,  ",'.+")),                                                                                                fontSize, fontName, fontColor);

   ObjectSetText(labels[I_STOPLOSS_SIZE          ],                      ifString(!stopPct,  "", NumberToStr(StopLoss.Size, ".+") +" pip = "+ NumberToStr(NormalizeDouble(stopPct, Max(0, 1-DoubleExp(stopPct))), ".+") +"%"), fontSize, fontName, fontColor);

   ObjectSetText(labels[I_MARGIN_INITIAL         ], "Margin initial:",                                                                                                                                                         fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MARGIN_MINLOT          ], "Margin minLot:",                                                                                                                                                          fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MARGIN_MAINTENANCE     ], "Margin maintenance:",                                                                                                                                                        fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MARGIN_HEDGED          ], "Margin hedged:",                                                                                                                                                             fontSize, fontName, fontColor);

   ObjectSetText(labels[I_MARGIN_INITIAL_DATA    ],                      ifString(!marginInitial, " ", NumberToStr(marginInitial, ",'.2R") +" "+ accountCurrency +"  (1:"+ Round(symbolLeverage) +")"),                        fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MARGIN_MINLOT_DATA     ],                      ifString(!marginMinLot,  " ", NumberToStr(marginMinLot, ",'.2R") +" "+ accountCurrency),                                                              fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MARGIN_MAINTENANCE_DATA],                      ifString(!marginMaintnc, " ", NumberToStr(marginMaintnc, ",'.2R") +" "+ accountCurrency +"  (1:"+ Round(maintncLeverage) +")"),                       fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MARGIN_HEDGED_DATA     ],                      ifString(!marginInitial, " ", ifString(!marginHedged, "none", Round(marginHedged) +"%")),                                                             fontSize, fontName, fontColor);

   ObjectSetText(labels[I_SPREAD                 ], "Spread:",                                                                                                                                                                 fontSize, fontName, fontColor);
   ObjectSetText(labels[I_COMMISSION             ], "Commission:",                                                                                                                                                             fontSize, fontName, fontColor);
   ObjectSetText(labels[I_TOTAL_COST             ], "Total cost:",                                                                                                                                                             fontSize, fontName, fontColor);

   ObjectSetText(labels[I_SPREAD_DATA            ],                      PipToStr(spreadPip, true, true) + ifString(!adr, "", " = "+ DoubleToStr(MathDiv(spreadPip, adr)*Pip * 100, 1) +"% of ADR"),                           fontSize, fontName, fontColor);
   ObjectSetText(labels[I_COMMISSION_DATA        ],                      ifString(!commission, "-", DoubleToStr(commission, 2) +" "+ accountCurrency +" = "+ NumberToStr(NormalizeDouble(commissionPip, 2), ".1+") +" pip"),   fontSize, fontName, fontColor);
   ObjectSetText(labels[I_TOTAL_COST_DATA        ],                      ifString(!commission, "-", NumberToStr(NormalizeDouble(spreadPip + commissionPip, 2), ".1+") +" pip"),                                                fontSize, fontName, fontColor);

   ObjectSetText(labels[I_SWAPLONG               ], "Swap long:",                                                                                                                                                              fontSize, fontName, fontColor);
   ObjectSetText(labels[I_SWAPSHORT              ], "Swap short:",                                                                                                                                                             fontSize, fontName, fontColor);

   ObjectSetText(labels[I_SWAPLONG_DATA          ],                      sSwapLong,                                                                                                                                            fontSize, fontName, fontColor);
   ObjectSetText(labels[I_SWAPSHORT_DATA         ],                      sSwapShort,                                                                                                                                           fontSize, fontName, fontColor);

   ObjectSetText(labels[I_ACCOUNT_LEVERAGE       ], "Account leverage:",                                                                                                                                                       fontSize, fontName, fontColor);
   ObjectSetText(labels[I_ACCOUNT_STOPOUT        ], "Account stopout:",                                                                                                                                                        fontSize, fontName, fontColor);
   ObjectSetText(labels[I_ACCOUNT_MM             ], "Account MM:",                                                                                                                                                             fontSize, fontName, fontColor);
   ObjectSetText(labels[I_ACCOUNT_REQUIRED       ], "Account required:",                                                                                                                                                       fontSize, fontName, fontColor);

   ObjectSetText(labels[I_ACCOUNT_LEVERAGE_DATA  ],                      ifString(!accountLeverage, " ", "1:"+ accountLeverage),                                                                                               fontSize, fontName, fontColor);
   ObjectSetText(labels[I_ACCOUNT_STOPOUT_DATA   ],                      ifString(!accountLeverage, " ", ifString(stopoutMode==MSM_PERCENT, accountStopout +"%", accountStopout +".00 "+ accountCurrency)),                    fontSize, fontName, fontColor);
   ObjectSetText(labels[I_ACCOUNT_MM_DATA        ],                      requiredUnits +" x "+ NumberToStr(minLot, ".+") +", free margin: "+ AccountSize.FreeMargin +"%",                                                      fontSize, fontName, fontColor);
   ObjectSetText(labels[I_ACCOUNT_REQUIRED_DATA  ],                      NumberToStr(MathRound(accountRequired), ",'.2") +" "+ accountCurrency +"  (1:"+ Round(fullLotsLeverage) +")",                                         fontSize, fontName, fontColor);

   ObjectSetText(labels[I_SERVER_NAME            ], "Server:",                                                                                                                                                                 fontSize, fontName, fontColor);
   ObjectSetText(labels[I_SERVER_TIMEZONE        ], "Server timezone:",                                                                                                                                                        fontSize, fontName, fontColor);
   ObjectSetText(labels[I_SERVER_SESSION         ], "Server session:",                                                                                                                                                         fontSize, fontName, fontColor);

   ObjectSetText(labels[I_SERVER_NAME_DATA       ],                      serverName,                                                                                                                                           fontSize, fontName, fontColor);
   ObjectSetText(labels[I_SERVER_TIMEZONE_DATA   ],                      serverTimezone,                                                                                                                                       fontSize, fontName, fontColor);
   ObjectSetText(labels[I_SERVER_SESSION_DATA    ],                      serverSession,                                                                                                                                        fontSize, fontName, fontColor);

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)
      return(NO_ERROR);
   return(catch("UpdateInstrumentInfos(1)", error));
}


/**
 * Resolve the current Average Daily Range.
 *
 * @return double - ADR value or NULL in case of errors
 */
double GetADR() {
   static double adr = 0;                                   // TODO: invalidate static var on BarOpen(D1)

   if (!adr) {
      adr = iADR(F_ERR_NO_HISTORY_DATA);

      if (!adr && last_error==ERR_NO_HISTORY_DATA) {
         SetLastError(ERS_TERMINAL_NOT_YET_READY);
      }
   }
   return(adr);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("AccountSize.NumberOfUnits=",  AccountSize.NumberOfUnits,         ";", NL,
                            "AccountSize.MaxRiskPerUnit=", AccountSize.MaxRiskPerUnit,        ";", NL,
                            "AccountSize.FreeMargin=",     AccountSize.FreeMargin,            ";", NL,
                            "StopLoss.Size=",              NumberToStr(StopLoss.Size, ".1+"), ";")
   );
}
