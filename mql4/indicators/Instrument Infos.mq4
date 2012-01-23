/**
 * Zeigt die Eigenschaften eines Instruments an.
 */
#include <stdlib.mqh>

#property indicator_chart_window


color  Background.Color    = C'212,208,200';
color  Font.Color.Enabled  = Blue;
color  Font.Color.Disabled = Gray;
string Font.Name           = "Tahoma";
int    Font.Size           = 9;

string names[] = { "TRADEALLOWED","POINT","TICKSIZE","TICKVALUE","SPREAD","STOPLEVEL","FREEZELEVEL","LOTSIZE","MINLOT","LOTSTEP","MAXLOT","MARGINREQUIRED","MARGINHEDGED","SWAPLONG","SWAPSHORT","STARTING","EXPIRATION","ACCOUNT_LEVERAGE","STOPOUT_LEVEL" };

#define TRADEALLOWED       0
#define POINT              1
#define TICKSIZE           2
#define TICKVALUE          3
#define SPREAD             4
#define STOPLEVEL          5
#define FREEZELEVEL        6
#define LOTSIZE            7
#define MINLOT             8
#define LOTSTEP            9
#define MAXLOT            10
#define MARGINREQUIRED    11
#define MARGINHEDGED      12
#define SWAPLONG          13
#define SWAPSHORT         14
#define STARTING          15
#define EXPIRATION        16
#define ACCOUNT_LEVERAGE  17
#define STOPOUT_LEVEL     18


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   if (IsError(onInit(T_INDICATOR)))
      return(last_error);

   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);

   CreateLabels();
   return(catch("init()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   RemoveChartObjects(objects);
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (prev_error != NO_ERROR)
      return(SetLastError(prev_error));

   UpdateInfos();

   return(catch("onTick()"));
}


/**
 *
 */
int CreateLabels() {
   int c = 10;

   // Background
   c++;
   string label = StringConcatenate(__SCRIPT__, ".", c, ".Background");
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE, 14);
      ObjectSet(label, OBJPROP_YDISTANCE, 134);
      ObjectSetText(label, "g", 174, "Webdings", Background.Color);
      ArrayPushString(objects, label);
   }
   else GetLastError();

   c++;
   label = StringConcatenate(__SCRIPT__, ".", c, ".Background");
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE, 14);
      ObjectSet(label, OBJPROP_YDISTANCE, 269);
      ObjectSetText(label, "g", 174, "Webdings", Background.Color);
      ArrayPushString(objects, label);
   }
   else GetLastError();

   // Textlabel
   int yCoord = 140;
   for (int i=0; i < ArraySize(names); i++) {
      c++;
      label = StringConcatenate(__SCRIPT__, ".", c, ".", names[i]);
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet(label, OBJPROP_XDISTANCE,  20);
            if (i==POINT || i==SPREAD || i==LOTSIZE || i==MARGINREQUIRED || i==SWAPLONG || i==STARTING || i==ACCOUNT_LEVERAGE)
               yCoord += 8;
         ObjectSet(label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, " ", Font.Size, Font.Name);
         ArrayPushString(objects, label);
         names[i] = label;
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
   string strBool[] = { "no","yes" };
   string strMCM[]  = { "Forex","CFD","CFD Futures","CFD Index","CFD Leverage" };               // margin calculation modes
   string strPCM[]  = { "Forex","CFD","Futures" };                                              // profit calculation modes
   string strSCM[]  = { "in points","in base currency","by interest","in margin currency" };    // swap calculation modes

   string symbol          = Symbol();
   string accountCurrency = AccountCurrency();

   bool   tradeAllowed = NE(MarketInfo(symbol, MODE_TRADEALLOWED), 0);
   color  Font.Color   = ifInt(tradeAllowed, Font.Color.Enabled, Font.Color.Disabled);

                                                                          ObjectSetText(names[TRADEALLOWED  ], StringConcatenate("Trading enabled: ", strBool[0+tradeAllowed]), Font.Size, Font.Name, Font.Color);
                                                                          ObjectSetText(names[POINT         ], StringConcatenate("Point size:  ", NumberToStr(Point, PriceFormat)), Font.Size, Font.Name, Font.Color);
   double tickSize     = MarketInfo(symbol, MODE_TICKSIZE);               ObjectSetText(names[TICKSIZE      ], StringConcatenate("Tick size:   ", NumberToStr(tickSize, PriceFormat)), Font.Size, Font.Name, Font.Color);

   double spread       = MarketInfo(symbol, MODE_SPREAD     )/PipPoints;
   double stopLevel    = MarketInfo(symbol, MODE_STOPLEVEL  )/PipPoints;
   double freezeLevel  = MarketInfo(symbol, MODE_FREEZELEVEL)/PipPoints;
      string strSpread      = DoubleToStr(spread,      Digits-PipDigits); ObjectSetText(names[SPREAD        ], StringConcatenate("Spread:        "      , strSpread     , " pip"), Font.Size, Font.Name, Font.Color);
      string strStopLevel   = DoubleToStr(stopLevel,   Digits-PipDigits); ObjectSetText(names[STOPLEVEL     ], StringConcatenate("Stop level:   "  , strStopLevel  , " pip"), Font.Size, Font.Name, Font.Color);
      string strFreezeLevel = DoubleToStr(freezeLevel, Digits-PipDigits); ObjectSetText(names[FREEZELEVEL   ], StringConcatenate("Freeze level: ", strFreezeLevel, " pip"), Font.Size, Font.Name, Font.Color);

   double tickValue         = MarketInfo(symbol, MODE_TICKVALUE        );
   double pointValue        = tickValue / (tickSize/Point);
   double pipValue          = PipPoints * pointValue;                     ObjectSetText(names[TICKVALUE     ], StringConcatenate("Pip value:  ", NumberToStr(pipValue, ", .2+"), " ", accountCurrency), Font.Size, Font.Name, Font.Color);

   double lotSize           = MarketInfo(symbol, MODE_LOTSIZE          ); ObjectSetText(names[LOTSIZE       ], StringConcatenate("Lot size:  ", NumberToStr(lotSize, ", .+"), " units"), Font.Size, Font.Name, Font.Color);
   double minLot            = MarketInfo(symbol, MODE_MINLOT           ); ObjectSetText(names[MINLOT        ], StringConcatenate("Min lot:    ", NumberToStr(minLot, ", .+")), Font.Size, Font.Name, Font.Color);
   double lotStep           = MarketInfo(symbol, MODE_LOTSTEP          ); ObjectSetText(names[LOTSTEP       ], StringConcatenate("Lot step: ", NumberToStr(lotStep, ", .+")), Font.Size, Font.Name, Font.Color);
   double maxLot            = MarketInfo(symbol, MODE_MAXLOT           ); ObjectSetText(names[MAXLOT        ], StringConcatenate("Max lot:   ", NumberToStr(maxLot, ", .+")), Font.Size, Font.Name, Font.Color);

   double marginRequired    = MarketInfo(symbol, MODE_MARGINREQUIRED   );
   double lotValue          = Bid / tickSize * tickValue;
   double leverage          = lotValue / marginRequired;                  ObjectSetText(names[MARGINREQUIRED], StringConcatenate("Margin required: ", NumberToStr(marginRequired, ", .2+"), " ", accountCurrency, "  (1:", MathRound(leverage), ")"), Font.Size, Font.Name, Font.Color);

   double marginHedged      = MarketInfo(symbol, MODE_MARGINHEDGED     );
          marginHedged      = marginHedged / lotSize * 100;               ObjectSetText(names[MARGINHEDGED  ], StringConcatenate("Margin hedged:  ", MathRound(marginHedged), "%"), Font.Size, Font.Name, Font.Color);

   int    swapType          = MarketInfo(symbol, MODE_SWAPTYPE         );
   double swapLong          = MarketInfo(symbol, MODE_SWAPLONG         );
   double swapShort         = MarketInfo(symbol, MODE_SWAPSHORT        );
      double swapLongD, swapShortD, swapLongY, swapShortY;
      if (swapType == SCM_POINTS) {
         swapLongD  = swapLong *Point/Pip;       swapLongY  = swapLongD *Pip*360*100/Bid;
         swapShortD = swapShort*Point/Pip;       swapShortY = swapShortD*Pip*360*100/Bid;
      }
      else if (swapType == SCM_INTEREST) {
         swapLongD  = swapLong *Bid/100/360/Pip; swapLongY  = swapLong;
         swapShortD = swapShort*Bid/100/360/Pip; swapShortY = swapShort;
      }
      else {
         if (swapType == SCM_BASE_CURRENCY) {
         }
         else if (swapType == SCM_MARGIN_CURRENCY) {     // Deposit-Currency
         }
      }
      ObjectSetText(names[SWAPLONG         ], StringConcatenate("Swap long:  ", NumberToStr(swapLongD, "+.2"), " pip = ", NumberToStr(swapLongY, "+.2"), "% p.a."), Font.Size, Font.Name, Font.Color);
      ObjectSetText(names[SWAPSHORT        ], StringConcatenate("Swap short: ", NumberToStr(swapShortD, "+.2"), " pip = ", NumberToStr(swapShortY, "+.2"), "% p.a."), Font.Size, Font.Name, Font.Color);

   double starts            = MarketInfo(symbol, MODE_STARTING         ); if (starts  > 0) ObjectSetText(names[STARTING  ], StringConcatenate("Future starts: ", TimeToStr(starts)), Font.Size, Font.Name, Font.Color);
   double expires           = MarketInfo(symbol, MODE_EXPIRATION       ); if (expires > 0) ObjectSetText(names[EXPIRATION], StringConcatenate("Future expires: ", TimeToStr(expires)), Font.Size, Font.Name, Font.Color);

   int    accountLeverage   = AccountLeverage();                          ObjectSetText(names[ACCOUNT_LEVERAGE], StringConcatenate("Account leverage:       1:", MathRound(accountLeverage)), Font.Size, Font.Name, Font.Color);
   int    stopoutLevel      = AccountStopoutLevel();                      ObjectSetText(names[STOPOUT_LEVEL   ], StringConcatenate("Account stopout level: ", NumberToStr(NormalizeDouble(stopoutLevel, 2), ", .+"), ifString(AccountStopoutMode()==ASM_PERCENT, "%", " "+ accountCurrency)), Font.Size, Font.Name, Font.Color);

   int error = GetLastError();
   if (error==NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)
      return(NO_ERROR);
   return(catch("UpdateInfos()", error));
}

/*
MODE_TRADEALLOWED       Trade is allowed for the symbol.
MODE_DIGITS             Count of digits after decimal point in the symbol prices. For the current symbol, it is stored in the predefined variable Digits

MODE_POINT              Point size in the quote currency.   => Auflösung des Preises
MODE_TICKSIZE           Tick size in the quote currency.    => kleinste Änderung des Preises, Vielfaches von MODE_POINT

MODE_SPREAD             Spread value in points.
MODE_STOPLEVEL          Stop level in points.
MODE_FREEZELEVEL        Order freeze level in points. If the execution price lies within the range defined by the freeze level, the order cannot be modified, cancelled or closed.

MODE_LOTSIZE            Lot size in the base currency.
MODE_TICKVALUE          Tick value in the deposit currency.
MODE_MINLOT             Minimum permitted amount of a lot.
MODE_MAXLOT             Maximum permitted amount of a lot.
MODE_LOTSTEP            Step for changing lots.

MODE_MARGINCALCMODE     Margin calculation mode. 0 - Forex; 1 - CFD; 2 - Futures; 3 - CFD for indices.
MODE_MARGINREQUIRED     Free margin required to open 1 lot for buying.
MODE_MARGININIT         Initial margin requirements for 1 lot.
MODE_MARGINMAINTENANCE  Margin to maintain open positions calculated for 1 lot.
MODE_MARGINHEDGED       Hedged margin calculated for 1 lot.

MODE_SWAPTYPE           Swap calculation method. 0 - in points; 1 - in the symbol base currency; 2 - by interest; 3 - in the margin currency.
MODE_SWAPLONG           Swap of the long position.
MODE_SWAPSHORT          Swap of the short position.

MODE_PROFITCALCMODE     Profit calculation mode. 0 - Forex; 1 - CFD; 2 - Futures.

MODE_STARTING           Market starting date (usually used for futures).
MODE_EXPIRATION         Market expiration date (usually used for futures).
*/
