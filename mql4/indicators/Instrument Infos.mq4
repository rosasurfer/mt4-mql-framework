/**
 * Display instrument specifications and properties.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@ATR.mqh>

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
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   SetIndexLabel(0, NULL);          // not displayed in "Data" window
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
   color  bg.color    = C'212,208,200';
   string bg.fontName = "Webdings";
   int    bg.fontSize = 212;

   int x =  3;                            // X start coordinate
   int y = 73;                            // Y start coordinate
   int n = 10;                            // counter for unique labels (min. 2 digits)

   // background
   string label = ProgramName() +"."+ n +".background";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, x);
      ObjectSet    (label, OBJPROP_YDISTANCE, y);
      ObjectSetText(label, "g", bg.fontSize, bg.fontName, bg.color);
      RegisterObject(label);
   }
   else GetLastError();

   n++;
   label = ProgramName() +"."+ n +".background";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, x    );
      ObjectSet    (label, OBJPROP_YDISTANCE, y+196);
      ObjectSetText(label, "g", bg.fontSize, bg.fontName, bg.color);
      RegisterObject(label);
   }
   else GetLastError();

   // text labels
   int yCoord = y + 4;
   for (int i=0; i < ArraySize(labels); i++) {
      n++;
      label = ProgramName() +"."+ n +"."+ labels[i];
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet    (label, OBJPROP_XDISTANCE, x+6);
            // lines followed by extra space (paragraph end)
            static int fields[] = {I_POINT, I_ATR_D, I_STOPLEVEL, I_LOTSIZE, I_MARGINREQUIRED, I_SPREAD, I_SWAPLONG, I_ACCOUNT_LEVERAGE, I_SERVER_NAME};
            if (IntInArray(fields, i)) yCoord += 8;

         ObjectSet    (label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, " ", fg.fontSize, fg.fontName);
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

   double atrD1            = @ATR(NULL, PERIOD_D1, 100, 1, F_ERS_HISTORY_UPDATE); if (last_error && last_error!=ERS_HISTORY_UPDATE) return(last_error);
   double atrW1            = @ATR(NULL, PERIOD_W1, 100, 1, F_ERS_HISTORY_UPDATE); if (last_error && last_error!=ERS_HISTORY_UPDATE) return(last_error);
   double atrMN1           = @ATR(NULL, PERIOD_MN1, 24, 1, F_ERS_HISTORY_UPDATE); if (last_error && last_error!=ERS_HISTORY_UPDATE) return(last_error);
                                                                             ObjectSetText(labels[I_ATR_D         ], "ATR(D100):   "    + ifString(!atrD1,          "", Round(atrD1/Pips)  +" pip = "+ DoubleToStr(MathDiv(atrD1,  Close[0])*100, 1) +"% = "+ ifString(!atrW1,  "...", DoubleToStr(MathDiv(atrD1, atrW1),  2) +" ATR(W1)" )), fg.fontSize, fg.fontName, fg.fontColor);
                                                                             ObjectSetText(labels[I_ATR_W         ], "ATR(W100):  "     + ifString(!atrW1,          "", Round(atrW1/Pips)  +" pip = "+ DoubleToStr(MathDiv(atrW1,  Close[0])*100, 1) +"% = "+ ifString(!atrMN1, "...", DoubleToStr(MathDiv(atrW1, atrMN1), 2) +" ATR(MN1)")), fg.fontSize, fg.fontName, fg.fontColor);
                                                                             ObjectSetText(labels[I_ATR_M         ], "ATR(MN24):  "     + ifString(!atrMN1,         "", Round(atrMN1/Pips) +" pip = "+ DoubleToStr(MathDiv(atrMN1, Close[0])*100, 1) +"%"                                                                                  ), fg.fontSize, fg.fontName, fg.fontColor);

   double stopLevel        = MarketInfo(symbol, MODE_STOPLEVEL  )/PipPoints; ObjectSetText(labels[I_STOPLEVEL     ], "Stop level:    "  +                               DoubleToStr(stopLevel,   Digits & 1) +" pip",         fg.fontSize, fg.fontName, fg.fontColor);
   double freezeLevel      = MarketInfo(symbol, MODE_FREEZELEVEL)/PipPoints; ObjectSetText(labels[I_FREEZELEVEL   ], "Freeze level: "   +                               DoubleToStr(freezeLevel, Digits & 1) +" pip",         fg.fontSize, fg.fontName, fg.fontColor);

   double lotSize          = MarketInfo(symbol, MODE_LOTSIZE);               ObjectSetText(labels[I_LOTSIZE       ], "Lot size:  "      + ifString(!lotSize,        "", NumberToStr(lotSize, ", .+") +" units"),              fg.fontSize, fg.fontName, fg.fontColor);
   double minLot           = MarketInfo(symbol, MODE_MINLOT );               ObjectSetText(labels[I_MINLOT        ], "Min lot:    "     + ifString(!minLot,         "", NumberToStr(minLot,  ", .+")),                        fg.fontSize, fg.fontName, fg.fontColor);
   double lotStep          = MarketInfo(symbol, MODE_LOTSTEP);               ObjectSetText(labels[I_LOTSTEP       ], "Lot step:  "      + ifString(!lotStep,        "", NumberToStr(lotStep, ", .+")),                        fg.fontSize, fg.fontName, fg.fontColor);
   double maxLot           = MarketInfo(symbol, MODE_MAXLOT );               ObjectSetText(labels[I_MAXLOT        ], "Max lot:  "       + ifString(!maxLot,         "", NumberToStr(maxLot,  ", .+")),                        fg.fontSize, fg.fontName, fg.fontColor);

   double marginRequired   = MarketInfo(symbol, MODE_MARGINREQUIRED); if (marginRequired == -92233720368547760.) marginRequired = NULL;
   double lotValue         = MathDiv(Close[0], tickSize) * tickValue;
   double leverage         = MathDiv(lotValue, marginRequired);              ObjectSetText(labels[I_MARGINREQUIRED], "Margin required: "+ ifString(!marginRequired, "", NumberToStr(marginRequired, ", .2+R") +" "+ accountCurrency +"  (1:"+ Round(leverage) +")"), fg.fontSize, fg.fontName, ifInt(!marginRequired, fg.fontColor.Disabled, fg.fontColor));
   double marginHedged     = MarketInfo(symbol, MODE_MARGINHEDGED);
          marginHedged     = MathDiv(marginHedged, lotSize) * 100;           ObjectSetText(labels[I_MARGINHEDGED  ], "Margin hedged:  " + ifString(!marginRequired, "", ifString(!marginHedged, "none", Round(marginHedged) +"%")),               fg.fontSize, fg.fontName, ifInt(!marginRequired, fg.fontColor.Disabled, fg.fontColor));

   double spread           = MarketInfo(symbol, MODE_SPREAD)/PipPoints;      ObjectSetText(labels[I_SPREAD        ], "Spread:        "  + DoubleToStr(spread,      Digits & 1) +" pip"+ ifString(!atrD1, "", " = "+ DoubleToStr(MathDiv(spread*Point, atrD1) * 100, 1) +"% ATR(D1)"), fg.fontSize, fg.fontName, fg.fontColor);
   double commission       = GetCommission();
   double commissionPip    = NormalizeDouble(MathDiv(commission, pipValue), Digits+1-PipDigits);
                                                                             ObjectSetText(labels[I_COMMISSION    ], "Commission:  "    + ifString(IsEmpty(commission), "...", NumberToStr(commission, ".2R") +" "+ accountCurrency +" = "+ NumberToStr(commissionPip, ".1+") +" pip"), fg.fontSize, fg.fontName, fg.fontColor);
   double totalFees        = spread + commission;                            ObjectSetText(labels[I_TOTALFEES     ], "Total:           "+ ifString(IsEmpty(commission), "...", ""),                                                                                                     fg.fontSize, fg.fontName, fg.fontColor);

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
         if (swapMode == SCM_INTEREST) {                             // TODO: check "in percentage terms", e.g. LiteForex stock CFDs
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
            if (MathAbs(swapLongDaily ) <= 0.05) swapLongDaily = Sign(swapLongDaily) * 0.1;
            strSwapLong  = NumberToStr(swapLongDaily, "+.1R") +" pip = "+ NumberToStr(swapLongYearly, "+.1R") +"% p.a.";
         }
         if (!swapShort) strSwapShort = "none";
         else {
            if (MathAbs(swapShortDaily) <= 0.05) swapShortDaily = Sign(swapShortDaily) * 0.1;
            strSwapShort = NumberToStr(swapShortDaily, "+.1R") +" pip = "+ NumberToStr(swapShortYearly, "+.1R") +"% p.a.";
         }
      }                                            ObjectSetText(labels[I_SWAPLONG        ], "Swap long:   "+ strSwapLong,  fg.fontSize, fg.fontName, fg.fontColor);
                                                   ObjectSetText(labels[I_SWAPSHORT       ], "Swap short: "+  strSwapShort, fg.fontSize, fg.fontName, fg.fontColor);

   int    accountLeverage = AccountLeverage();     ObjectSetText(labels[I_ACCOUNT_LEVERAGE], "Account leverage:      "+ ifString(!accountLeverage, "", "1:"+ accountLeverage), fg.fontSize, fg.fontName, ifInt(!accountLeverage, fg.fontColor.Disabled, fg.fontColor));
   int    stopoutLevel    = AccountStopoutLevel(); ObjectSetText(labels[I_STOPOUT_LEVEL   ], "Account stopout level: "+ ifString(!accountLeverage, "", ifString(AccountStopoutMode()==MSM_PERCENT, stopoutLevel +"%", stopoutLevel +".00 "+ accountCurrency)), fg.fontSize, fg.fontName, ifInt(!accountLeverage, fg.fontColor.Disabled, fg.fontColor));

   string serverName      = GetAccountServer();    ObjectSetText(labels[I_SERVER_NAME     ], "Server:               "+  serverName, fg.fontSize, fg.fontName, ifInt(!StringLen(serverName), fg.fontColor.Disabled, fg.fontColor));
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
                                                   ObjectSetText(labels[I_SERVER_TIMEZONE], "Server timezone:  "+ serverTimezone, fg.fontSize, fg.fontName, ifInt(!StringLen(serverTimezone), fg.fontColor.Disabled, fg.fontColor));

   string serverSession = ifString(!StringLen(serverTimezone), "", ifString(!tzOffset, "00:00-24:00", GmtTimeFormat(D'1970.01.02' + tzOffset, "%H:%M-%H:%M")));

                                                   ObjectSetText(labels[I_SERVER_SESSION], "Server session:     "+ serverSession, fg.fontSize, fg.fontName, ifInt(!StringLen(serverSession), fg.fontColor.Disabled, fg.fontColor));
   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)
      return(NO_ERROR);
   return(catch("UpdateInstrumentInfos(1)", error));
}
