/**
 * Display instrument specifications and related infos.
 *
 *
 * TODO:
 *  - implement trade server configuration
 *  - fix symbol configuration bugs using trade server overrides
 *  - FxPro: if all symbols are unsubscribed at a weekend (trading disabled) a template reload enables the full display
 *  - get an instrument's base currency: https://www.mql5.com/en/book/automation/symbols/symbols_currencies
 *  - config override: if (Symbol() == "#Germany40") marginInitial = 751.93;
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int AccountSize.NumberOfUnits     = 20;     // number of available bullets of MODE_MINLOT size
extern int AccountSize.MaxUnitRisk.Pct   = 10;     // max. risk per bullet in % on an ADR move against it
extern int AccountSize.MaxUsedMargin.Pct = 75;     // max. margin utilization in %

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/functions/ta/ADR.mqh>

#property indicator_chart_window

color  fontColorEnabled  = Blue;
color  fontColorDisabled = Gray;
string fontName          = "Tahoma";
int    fontSize          = 9;

string labels[] = {"TRADING_ENABLED","TRADING_ENABLED_DATA","DIGITS","DIGITS_DATA","TICKSIZE","TICKSIZE_DATA","PUNITVALUE","PUNITVALUE_DATA","ADR","ADR_DATA","STOPLEVEL","STOPLEVEL_DATA","FREEZELEVEL","FREEZELEVEL_DATA","LOTSIZE","LOTSIZE_DATA","LOTSTEP","LOTSTEP_DATA","MINLOT","MINLOT_DATA","MAXLOT","MAXLOT_DATA","MARGIN_INITIAL","MARGIN_INITIAL_DATA","MARGIN_MAINTENANCE","MARGIN_MAINTENANCE_DATA","MARGIN_HEDGED","MARGIN_HEDGED_DATA","MARGIN_MINLOT","MARGIN_MINLOT_DATA","SPREAD","SPREAD_DATA","COMMISSION","COMMISSION_DATA","TOTAL_COST","TOTAL_COST_DATA","SWAPLONG","SWAPLONG_DATA","SWAPSHORT","SWAPSHORT_DATA","ACCOUNT_LEVERAGE","ACCOUNT_LEVERAGE_DATA","ACCOUNT_STOPOUT","ACCOUNT_STOPOUT_DATA","ACCOUNT_MM","ACCOUNT_MM_DATA","ACCOUNT_REQUIRED","ACCOUNT_REQUIRED_DATA","SERVER_NAME","SERVER_NAME_DATA","SERVER_TIMEZONE","SERVER_TIMEZONE_DATA","SERVER_SESSION","SERVER_SESSION_DATA"};

#define I_TRADING_ENABLED          0
#define I_TRADING_ENABLED_DATA     1
#define I_DIGITS                   2
#define I_DIGITS_DATA              3
#define I_TICKSIZE                 4
#define I_TICKSIZE_DATA            5
#define I_PUNITVALUE               6
#define I_PUNITVALUE_DATA          7
#define I_ADR                      8
#define I_ADR_DATA                 9
#define I_STOPLEVEL               10
#define I_STOPLEVEL_DATA          11
#define I_FREEZELEVEL             12
#define I_FREEZELEVEL_DATA        13
#define I_LOTSIZE                 14
#define I_LOTSIZE_DATA            15
#define I_LOTSTEP                 16
#define I_LOTSTEP_DATA            17
#define I_MINLOT                  18
#define I_MINLOT_DATA             19
#define I_MAXLOT                  20
#define I_MAXLOT_DATA             21
#define I_MARGIN_INITIAL          22
#define I_MARGIN_INITIAL_DATA     23
#define I_MARGIN_MAINTENANCE      24
#define I_MARGIN_MAINTENANCE_DATA 25
#define I_MARGIN_HEDGED           26
#define I_MARGIN_HEDGED_DATA      27
#define I_MARGIN_MINLOT           28
#define I_MARGIN_MINLOT_DATA      29
#define I_SPREAD                  30
#define I_SPREAD_DATA             31
#define I_COMMISSION              32
#define I_COMMISSION_DATA         33
#define I_TOTAL_COST              34
#define I_TOTAL_COST_DATA         35
#define I_SWAPLONG                36
#define I_SWAPLONG_DATA           37
#define I_SWAPSHORT               38
#define I_SWAPSHORT_DATA          39
#define I_ACCOUNT_LEVERAGE        40
#define I_ACCOUNT_LEVERAGE_DATA   41
#define I_ACCOUNT_STOPOUT         42
#define I_ACCOUNT_STOPOUT_DATA    43
#define I_ACCOUNT_MM              44
#define I_ACCOUNT_MM_DATA         45
#define I_ACCOUNT_REQUIRED        46
#define I_ACCOUNT_REQUIRED_DATA   47
#define I_SERVER_NAME             48
#define I_SERVER_NAME_DATA        49
#define I_SERVER_TIMEZONE         50
#define I_SERVER_TIMEZONE_DATA    51
#define I_SERVER_SESSION          52
#define I_SERVER_SESSION_DATA     53

string swapCalcModeDescr[] = {"point", "base currency", "interest", "margin currency"};


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
   UpdateInstrumentInfos();
   return(last_error);
}


/**
 * Create needed chart objects.
 *
 * @return bool - success status
 */
bool CreateChartObjects() {
   string indicatorName = ProgramName();
   color  bgColor    = C'212,208,200';
   string bgFontName = "Webdings";
   int    bgFontSize = 200;

   int xPos =  3;                         // X start coordinate
   int yPos = 83;                         // Y start coordinate
   int n    = 10;                         // counter for unique labels (min. 2 digits)

   // background rectangles
   string label = indicatorName +"."+ n +".background";
   if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL)) return(false);
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
   ObjectSet    (label, OBJPROP_XDISTANCE, xPos);
   ObjectSet    (label, OBJPROP_YDISTANCE, yPos);
   ObjectSetText(label, "g", bgFontSize, bgFontName, bgColor);

   n++;
   label = indicatorName +"."+ n +".background";
   if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL)) return(false);
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
   ObjectSet    (label, OBJPROP_XDISTANCE, xPos);
   ObjectSet    (label, OBJPROP_YDISTANCE, yPos+186);          // line height: 14 pt
   ObjectSetText(label, "g", bgFontSize, bgFontName, bgColor);

   // text labels
   int addMarginTop[] = {I_DIGITS, I_DIGITS_DATA, I_ADR, I_ADR_DATA, I_STOPLEVEL, I_STOPLEVEL_DATA, I_LOTSIZE, I_LOTSIZE_DATA, I_MARGIN_INITIAL, I_MARGIN_INITIAL_DATA, I_SPREAD, I_SWAPLONG, I_ACCOUNT_LEVERAGE, I_SERVER_NAME};
   int col2Data    [] = {I_TRADING_ENABLED_DATA,I_DIGITS_DATA, I_TICKSIZE_DATA, I_PUNITVALUE_DATA, I_ADR_DATA, I_STOPLEVEL_DATA, I_FREEZELEVEL_DATA, I_LOTSIZE_DATA, I_LOTSTEP_DATA, I_MINLOT_DATA, I_MAXLOT_DATA, I_MARGIN_INITIAL_DATA, I_MARGIN_MAINTENANCE_DATA, I_MARGIN_HEDGED_DATA, I_MARGIN_MINLOT_DATA, I_SPREAD_DATA, I_COMMISSION_DATA, I_TOTAL_COST_DATA, I_SWAPLONG_DATA, I_SWAPSHORT_DATA, I_ACCOUNT_LEVERAGE_DATA, I_ACCOUNT_STOPOUT_DATA, I_ACCOUNT_MM_DATA, I_ACCOUNT_REQUIRED_DATA, I_SERVER_NAME_DATA, I_SERVER_TIMEZONE_DATA, I_SERVER_SESSION_DATA};
   int size = ArraySize(labels);
   int xCoord, yCoord = yPos + 4;

   for (int i=0; i < size; i++) {
      n++;
      label = indicatorName +"."+ n +"."+ labels[i];
      if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL)) return(false);
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);

      if (IntInArray(col2Data, i)) {                  // column 2 data
         xCoord = xPos + 132;
         yCoord -= 16;
      }
      else {                                          // column 1 data
         xCoord = xPos + 6;
         if (IntInArray(addMarginTop, i)) yCoord += 8;
      }

      ObjectSet(label, OBJPROP_XDISTANCE, xCoord);
      ObjectSet(label, OBJPROP_YDISTANCE, yCoord + i*16);
      ObjectSetText(label, " ", fontSize, fontName);
      labels[i] = label;
   }
   return(!catch("CreateChartObjects(1)"));
}


/**
 * Update instrument infos.
 *
 * @return int - error status
 */
int UpdateInstrumentInfos() {
   string _spUnit = ifString(pUnit==1, "", " "+ spUnit);

   string symbol          = Symbol();
   bool   tradingEnabled  = (MarketInfo(symbol, MODE_TRADEALLOWED) != 0);
   color  fontColor       = ifInt(tradingEnabled, fontColorEnabled, fontColorDisabled);

   string accountCurrency = AccountCurrency();
   int    accountLeverage = AccountLeverage();
   int    accountStopout  = AccountStopoutLevel();
   int    stopoutMode     = AccountStopoutMode(), error;

   // calculate required values
   double tickSize        = MarketInfo(symbol, MODE_TICKSIZE);
   double tickValue       = MarketInfoEx(Symbol(), MODE_TICKVALUE, error, "UpdateInstrumentInfos(1)");
   double fullPointValue  = MathDiv(tickValue, tickSize);
   double stopLevel       = NormalizeDouble(MarketInfo(symbol, MODE_STOPLEVEL)   * Point, Digits);
   double freezeLevel     = NormalizeDouble(MarketInfo(symbol, MODE_FREEZELEVEL) * Point, Digits);

   double adr             = GetADR(); if (!adr && last_error && last_error!=ERS_TERMINAL_NOT_YET_READY) return(last_error);
   double volaPerADR      = adr/Close[0] * 100;                   // instrument volatility per ADR move in percent

   int    lotSize         = MarketInfo(symbol, MODE_LOTSIZE);
   double lotValue        = MathDiv(Close[0], tickSize) * tickValue;
   double lotStep         = MarketInfo(symbol, MODE_LOTSTEP);
   double minLot          = MarketInfo(symbol, MODE_MINLOT);
   double maxLot          = MarketInfo(symbol, MODE_MAXLOT);

   double marginInitial   = MarketInfo(symbol, MODE_MARGINREQUIRED); if (marginInitial == -92233720368547760.) marginInitial = 0;
   double marginMinLot    = marginInitial * minLot;
   double symbolLeverage  = MathDiv(lotValue, marginInitial);
   double marginMaint     = ifDouble(stopoutMode==MSM_PERCENT, marginInitial * accountStopout/100, marginInitial);
   double maintLeverage   = MathDiv(lotValue, marginMaint);
   double marginHedged    = MathDiv(MarketInfo(symbol, MODE_MARGINHEDGED), lotSize) * 100;

   double spreadP         = NormalizeDouble(MarketInfo(symbol, MODE_SPREAD) * Point, Digits);
   double spreadM         = spreadP * fullPointValue;
   double commissionM     = GetCommission();
   double commissionP     = NormalizeDouble(MathDiv(commissionM, fullPointValue), Digits+1); // +1 digit for sub-precision
   double commissionPunit = NormalizeDouble(commissionP/pUnit, Digits+1);                    // ...
   double totalCostP      = NormalizeDouble(spreadP + commissionP, Digits+1);                // ...
   double totalCostPunit  = NormalizeDouble(totalCostP/pUnit, Digits+1);                     // ...
   double totalCostPct    = MathDiv(spreadM + commissionM, lotValue) * 100;

   string pUnitFormat = "."+ pDigits +"+";
   if (pUnit==1) if (CountDecimals(commissionPunit) > 2) pUnitFormat = ".2'+";

   int    swapMode        = MarketInfo(symbol, MODE_SWAPTYPE);
   double swapLong        = MarketInfo(symbol, MODE_SWAPLONG);
   double swapShort       = MarketInfo(symbol, MODE_SWAPSHORT);
   double swapLongD, swapShortD, swapLongY, swapShortY;
   string sSwapLong=" ", sSwapShort=" ";

   if (swapMode == SCM_POINTS) {                                  // in MQL point of quote currency
      swapLongD  = NormalizeDouble(swapLong *Point, 8); swapLongY  = MathDiv(swapLongD  * 360, Close[0]) * 100;
      swapShortD = NormalizeDouble(swapShort*Point, 8); swapShortY = MathDiv(swapShortD * 360, Close[0]) * 100;
      sSwapLong  = ifString(!swapLong,  "none", NumberToStr(swapLongD /pUnit, "+."+ ifString(pUnit==1, "2'", "1+")) + _spUnit + " = "+ NumberToStr(swapLongY,  "+.1R") +"% p.a.");
      sSwapShort = ifString(!swapShort, "none", NumberToStr(swapShortD/pUnit, "+."+ ifString(pUnit==1, "2'", "1+")) + _spUnit + " = "+ NumberToStr(swapShortY, "+.1R") +"% p.a.");
   }
   else if (swapMode == SCM_INTEREST) {                           // in % p.a. of quote value
      swapLongY  = swapLong;  swapLongD  = NormalizeDouble(swapLongY /100 * Close[0] / 360, 8);
      swapShortY = swapShort; swapShortD = NormalizeDouble(swapShortY/100 * Close[0] / 360, 8);
      sSwapLong  = ifString(!swapLong,  "none", NumberToStr(swapLongD /pUnit, "+."+ ifString(pUnit==1, "2'", "1+")) + _spUnit + " = "+ NumberToStr(swapLongY,  "+.1R") +"% p.a.");
      sSwapShort = ifString(!swapShort, "none", NumberToStr(swapShortD/pUnit, "+."+ ifString(pUnit==1, "2'", "1+")) + _spUnit + " = "+ NumberToStr(swapShortY, "+.1R") +"% p.a.");
   }
   else {
      /*
      if      (swapMode == SCM_BASE_CURRENCY  ) {}                // TODO: as amount of base currency   (see "symbols.raw")
      else if (swapMode == SCM_MARGIN_CURRENCY) {}                // TODO: as amount of margin currency (see "symbols.raw")
      */
      sSwapLong  = ifString(!swapLong,  "none", NumberToStr(swapLong,  "+.+") +" "+ swapCalcModeDescr[swapMode]);
      sSwapShort = ifString(!swapShort, "none", NumberToStr(swapShort, "+.+") +" "+ swapCalcModeDescr[swapMode]);
   }

   double usedLeverage   = symbolLeverage * AccountSize.MaxUsedMargin.Pct/100;
   double maxUnits       = MathDiv(symbolLeverage, usedLeverage) * AccountSize.NumberOfUnits;
   double minAccountSize = maxUnits * marginMinLot;

   string serverName     = GetAccountServer();
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
   ObjectSetText(labels[I_TRADING_ENABLED        ], "Trading enabled:",                                                                                                                                                           fontSize, fontName, fontColor);
   ObjectSetText(labels[I_TRADING_ENABLED_DATA   ],                      ifString(tradingEnabled, "yes", "no"),                                                                                                                   fontSize, fontName, fontColor);

   ObjectSetText(labels[I_DIGITS                 ], "Digits:",                                                                                                                                                                    fontSize, fontName, fontColor);
   ObjectSetText(labels[I_DIGITS_DATA            ],                      ""+ Digits,                                                                                                                                              fontSize, fontName, fontColor);
   ObjectSetText(labels[I_TICKSIZE               ], "Tick size:",                                                                                                                                                                 fontSize, fontName, fontColor);
   ObjectSetText(labels[I_TICKSIZE_DATA          ],                      ifString(!tickSize,       " ", NumberToStr(tickSize, PriceFormat)),                                                                                      fontSize, fontName, fontColor);
   ObjectSetText(labels[I_PUNITVALUE             ], "Punit value:",                                                                                                                                                               fontSize, fontName, fontColor);
   ObjectSetText(labels[I_PUNITVALUE_DATA        ],                      ifString(!fullPointValue, " ", NumberToStr(fullPointValue*pUnit, "R.2+") +" "+ accountCurrency +"/lot"),                                                 fontSize, fontName, fontColor);

   ObjectSetText(labels[I_ADR                    ], "ADR(20):",                                                                                                                                                                   fontSize, fontName, fontColor);
   ObjectSetText(labels[I_ADR_DATA               ],                      ifString(!adr, "n/a", DoubleToStr(adr/pUnit, pDigits) + _spUnit +" = "+ NumberToStr(NormalizeDouble(volaPerADR, 2), ".0+") +"%/price"),                  fontSize, fontName, fontColor);

   ObjectSetText(labels[I_STOPLEVEL              ], "Stop level:",                                                                                                                                                                fontSize, fontName, fontColor);
   ObjectSetText(labels[I_STOPLEVEL_DATA         ],                      ifString(!stopLevel,   "0", DoubleToStr(stopLevel/pUnit,   pDigits) + _spUnit),                                                                          fontSize, fontName, fontColor);
   ObjectSetText(labels[I_FREEZELEVEL            ], "Freeze level:",                                                                                                                                                              fontSize, fontName, fontColor);
   ObjectSetText(labels[I_FREEZELEVEL_DATA       ],                      ifString(!freezeLevel, "0", DoubleToStr(freezeLevel/pUnit, pDigits) + _spUnit),                                                                          fontSize, fontName, fontColor);

   ObjectSetText(labels[I_LOTSIZE                ], "Lot size:",                                                                                                                                                                  fontSize, fontName, fontColor);
   ObjectSetText(labels[I_LOTSIZE_DATA           ],                      ifString(!lotSize, " ", NumberToStr(lotSize, ",'.+") +" unit"+ Pluralize(lotSize)),                                                                      fontSize, fontName, fontColor);
   ObjectSetText(labels[I_LOTSTEP                ], "Lot step:",                                                                                                                                                                  fontSize, fontName, fontColor);
   ObjectSetText(labels[I_LOTSTEP_DATA           ],                      ifString(!lotStep, " ", NumberToStr(lotStep, ".+")),                                                                                                     fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MINLOT                 ], "Min lot:",                                                                                                                                                                   fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MINLOT_DATA            ],                      ifString(!minLot,  " ", NumberToStr(minLot,  ".+")),                                                                                                     fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MAXLOT                 ], "Max lot:",                                                                                                                                                                   fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MAXLOT_DATA            ],                      ifString(!maxLot,  " ", NumberToStr(maxLot,  ",'.+")),                                                                                                   fontSize, fontName, fontColor);

   ObjectSetText(labels[I_MARGIN_INITIAL         ], "Margin initial:",                                                                                                                                                            fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MARGIN_INITIAL_DATA    ],                      ifString(!marginInitial, " ", NumberToStr(marginInitial, ",'.2R") +" "+ accountCurrency +"  (1:"+ Round(symbolLeverage) +")"),                           fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MARGIN_MAINTENANCE     ], "Margin maint.:",                                                                                                                                                             fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MARGIN_MAINTENANCE_DATA],                      ifString(!marginMaint,   " ", NumberToStr(marginMaint,   ",'.2R") +" "+ accountCurrency +"  (1:"+ Round(maintLeverage) +")"),                            fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MARGIN_HEDGED          ], "Margin hedged:",                                                                                                                                                             fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MARGIN_HEDGED_DATA     ],                      ifString(!marginInitial, " ", Round(marginHedged) +"%"),                                                                                                 fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MARGIN_MINLOT          ], "Margin minLot:",                                                                                                                                                             fontSize, fontName, fontColor);
   ObjectSetText(labels[I_MARGIN_MINLOT_DATA     ],                      ifString(!marginMinLot,  " ", NumberToStr(marginMinLot, ",'.2R") +" "+ accountCurrency),                                                                 fontSize, fontName, fontColor);

   ObjectSetText(labels[I_SPREAD                 ], "Spread:",                                                                                                                                                                    fontSize, fontName, fontColor);
   ObjectSetText(labels[I_SPREAD_DATA            ],                      DoubleToStr(spreadP/pUnit, pDigits) + _spUnit + ifString(!adr, "", " = "+ DoubleToStr(MathDiv(spreadP, adr) * 100, 1) +"%/ADR"),                         fontSize, fontName, fontColor);
   ObjectSetText(labels[I_COMMISSION             ], "Commission:",                                                                                                                                                                fontSize, fontName, fontColor);
   ObjectSetText(labels[I_COMMISSION_DATA        ],                      ifString(!commissionM, "-", DoubleToStr(commissionM, 2) +" "+ accountCurrency +"/lot = "+ NumberToStr(commissionPunit, pUnitFormat) + _spUnit),          fontSize, fontName, fontColor);
   ObjectSetText(labels[I_TOTAL_COST             ], "Total cost:",                                                                                                                                                                fontSize, fontName, fontColor);
   ObjectSetText(labels[I_TOTAL_COST_DATA        ],                      ifString(!totalCostP,  "-", NumberToStr(totalCostPunit, pUnitFormat) + _spUnit) +" = "+ NumberToStr(NormalizeDouble(totalCostPct, 3), ".1+") +"%/TxVol", fontSize, fontName, fontColor);

   ObjectSetText(labels[I_SWAPLONG               ], "Swap long:",                                                                                                                                                                 fontSize, fontName, fontColor);
   ObjectSetText(labels[I_SWAPLONG_DATA          ],                      sSwapLong,                                                                                                                                               fontSize, fontName, fontColor);
   ObjectSetText(labels[I_SWAPSHORT              ], "Swap short:",                                                                                                                                                                fontSize, fontName, fontColor);
   ObjectSetText(labels[I_SWAPSHORT_DATA         ],                      sSwapShort,                                                                                                                                              fontSize, fontName, fontColor);

   ObjectSetText(labels[I_ACCOUNT_LEVERAGE       ], "Account leverage:",                                                                                                                                                          fontSize, fontName, fontColor);
   ObjectSetText(labels[I_ACCOUNT_LEVERAGE_DATA  ],                      ifString(!accountLeverage, " ", "1:"+ accountLeverage),                                                                                                  fontSize, fontName, fontColor);
   ObjectSetText(labels[I_ACCOUNT_STOPOUT        ], "Account stopout:",                                                                                                                                                           fontSize, fontName, fontColor);
   ObjectSetText(labels[I_ACCOUNT_STOPOUT_DATA   ],                      ifString(!accountLeverage, " ", ifString(stopoutMode==MSM_PERCENT, accountStopout +"%", accountStopout +".00 "+ accountCurrency)),                       fontSize, fontName, fontColor);
   ObjectSetText(labels[I_ACCOUNT_MM             ], "Account MM:",                                                                                                                                                                fontSize, fontName, fontColor);
   ObjectSetText(labels[I_ACCOUNT_MM_DATA        ],                      ifString(!minLot,          " ", AccountSize.NumberOfUnits +" x "+ NumberToStr(minLot, ".+")),                                                            fontSize, fontName, fontColor);
   ObjectSetText(labels[I_ACCOUNT_REQUIRED       ], "Account required:",                                                                                                                                                          fontSize, fontName, fontColor);
   ObjectSetText(labels[I_ACCOUNT_REQUIRED_DATA  ],                      ifString(!minAccountSize,  " ", NumberToStr(MathRound(minAccountSize), ",'.2") +" "+ accountCurrency +"  (1:"+ Round(usedLeverage) +")"),                fontSize, fontName, fontColor);

   ObjectSetText(labels[I_SERVER_NAME            ], "Server:",                                                                                                                                                                    fontSize, fontName, fontColor);
   ObjectSetText(labels[I_SERVER_NAME_DATA       ],                      serverName,                                                                                                                                              fontSize, fontName, fontColor);
   ObjectSetText(labels[I_SERVER_TIMEZONE        ], "Server timezone:",                                                                                                                                                           fontSize, fontName, fontColor);
   ObjectSetText(labels[I_SERVER_TIMEZONE_DATA   ],                      serverTimezone,                                                                                                                                          fontSize, fontName, fontColor);
   ObjectSetText(labels[I_SERVER_SESSION         ], "Server session:",                                                                                                                                                            fontSize, fontName, fontColor);
   ObjectSetText(labels[I_SERVER_SESSION_DATA    ],                      serverSession,                                                                                                                                           fontSize, fontName, fontColor);

   error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)
      return(NO_ERROR);
   return(catch("UpdateInstrumentInfos(2)", error));
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
   return(StringConcatenate("AccountSize.NumberOfUnits=",    AccountSize.NumberOfUnits,     ";", NL,
                            "AccountSize.MaxUnitRiskPct=",   AccountSize.MaxUnitRisk.Pct,   ";", NL,
                            "AccountSize.MaxUsedMarginPct=", AccountSize.MaxUsedMargin.Pct, ";")
   );
}
