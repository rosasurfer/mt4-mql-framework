/**
 * Instrument Infos.mq4
 *
 * Zeigt die Eigenschaften eines Instruments an.
 */

#include <stdlib.mqh>


#property indicator_chart_window
#property indicator_buffers 0


//////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////

extern string Font.Name    = "Tahoma";
extern int    Font.Size    = 9;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


color  Background.Color    = C'212,208,200';
color  Font.Color.Active   = Blue;
color  Font.Color.Inactive = Gray;


string names[] = { "TRADEALLOWED","POINT","TICKSIZE","SPREAD","STOPLEVEL","FREEZELEVEL","LOTSIZE","TICKVALUE","MINLOT","MAXLOT","LOTSTEP","MARGINCALCMODE","MARGINREQUIRED","MARGININIT","MARGINMAINTENANCE","MARGINHEDGED","SWAPTYPE","SWAPLONG","SWAPSHORT","PROFITCALCMODE","STARTING","EXPIRATION","ACCOUNT_LEVERAGE","STOPOUT_MODE","STOPOUT_LEVEL" };

#define TRADEALLOWED       0
#define POINT              1
#define TICKSIZE           2
#define SPREAD             3
#define STOPLEVEL          4
#define FREEZELEVEL        5
#define LOTSIZE            6
#define TICKVALUE          7
#define MINLOT             8
#define MAXLOT             9
#define LOTSTEP           10
#define MARGINCALCMODE    11
#define MARGINREQUIRED    12
#define MARGININIT        13
#define MARGINMAINTENANCE 14
#define MARGINHEDGED      15
#define SWAPTYPE          16
#define SWAPLONG          17
#define SWAPSHORT         18
#define PROFITCALCMODE    19
#define STARTING          20
#define EXPIRATION        21
#define ACCOUNT_LEVERAGE  22
#define STOPOUT_MODE      23
#define STOPOUT_LEVEL     24


string labels[];


/**
 *
 */
int init() {
   CreateLabels();
   return(catch("init()"));
}


/**
 *
 */
int start() {
   static int error = ERR_NO_ERROR;

   if (error == ERR_NO_ERROR)
      error = UpdateInfos();

   return(catch("start()"));
}


/**
 *
 */
int deinit() {
   RemoveChartObjects(labels);
   return(catch("deinit()"));
}


/**
 *
 */
int CreateLabels() {
   string expertName = WindowExpertName();
   int c = 10;

   // Background
   c++;
   string label = StringConcatenate(expertName, ".", c, ".Background");
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE, 14);
      ObjectSet(label, OBJPROP_YDISTANCE, 166);
      ObjectSetText(label, "g", 168, "Webdings", Background.Color);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   c++;
   label = StringConcatenate(expertName, ".", c, ".Background");
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE, 14);
      ObjectSet(label, OBJPROP_YDISTANCE, 390);
      ObjectSetText(label, "g", 168, "Webdings", Background.Color);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   c++;
   label = StringConcatenate(expertName, ".", c, ".Background");
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE, 14);
      ObjectSet(label, OBJPROP_YDISTANCE, 412);
      ObjectSetText(label, "g", 168, "Webdings", Background.Color);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   // Textlabel
   int yCoord = 170;
   for (int i=0; i < ArraySize(names); i++) {
      c++;
      label = StringConcatenate(expertName, ".", c, ".", names[i]);
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet(label, OBJPROP_XDISTANCE,  20);
            if (i==POINT || i==SPREAD || i==LOTSIZE || i==MARGINCALCMODE || i==SWAPTYPE || i==PROFITCALCMODE || i==STARTING || i==ACCOUNT_LEVERAGE)
               yCoord += 8;
         ObjectSet(label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, " ", Font.Size, Font.Name);
         RegisterChartObject(label, labels);
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
   string strMCM[]  = { "Forex","CFD","CFD Futures","CFD Index","CFD Leverage" };            // margin calculation modes
   string strPCM[]  = { "Forex","CFD","Futures" };                                           // profit calculation modes
   string strSCM[]  = { "in points","in base currency","by interest","in margin currency" }; // swap calculation modes
   string strASM[]  = { "percent ratio","absolute value" };                                  // account stopout modes

   string symbol          = Symbol();
   string accountCurrency = AccountCurrency();

   bool   tradeAllowed = MarketInfo(symbol, MODE_TRADEALLOWED);
   color  Font.Color = ifInt(tradeAllowed, Font.Color.Active, Font.Color.Inactive);

                                                                ObjectSetText(names[TRADEALLOWED], StringConcatenate("Trading enabled: ", strBool[0+tradeAllowed]), Font.Size, Font.Name, Font.Color);
   double point        = Point;                                 ObjectSetText(names[POINT       ], StringConcatenate("Point size: ", DoubleToStr(point, Digits)), Font.Size, Font.Name, Font.Color);
   double tickSize     = MarketInfo(symbol, MODE_TICKSIZE);     ObjectSetText(names[TICKSIZE    ], StringConcatenate("Tick size: ", DoubleToStr(tickSize, Digits)), Font.Size, Font.Name, Font.Color);

   int    spread       = MarketInfo(symbol, MODE_SPREAD);
   int    stopLevel    = MarketInfo(symbol, MODE_STOPLEVEL);
   int    freezeLevel  = MarketInfo(symbol, MODE_FREEZELEVEL);
      string strSpread=spread, strStopLevel=stopLevel, strFreezeLevel=freezeLevel;
      if (Digits==3 || Digits==5) {
         strSpread      = DoubleToStr(spread     /10.0, 1);
         strStopLevel   = DoubleToStr(stopLevel  /10.0, 1);
         strFreezeLevel = DoubleToStr(freezeLevel/10.0, 1);
      }
      ObjectSetText(names[SPREAD     ], StringConcatenate("Spread: "      , strSpread     , " pip"), Font.Size, Font.Name, Font.Color);
      ObjectSetText(names[STOPLEVEL  ], StringConcatenate("Stop level: "  , strStopLevel  , " pip"), Font.Size, Font.Name, Font.Color);
      ObjectSetText(names[FREEZELEVEL], StringConcatenate("Freeze level: ", strFreezeLevel, " pip"), Font.Size, Font.Name, Font.Color);

   double lotSize  = MarketInfo(symbol, MODE_LOTSIZE); ObjectSetText(names[LOTSIZE], StringConcatenate("Lot size: ", FormatNumber(lotSize, ", .+"), " units"), Font.Size, Font.Name, Font.Color);
      if (MathRound(lotSize) != lotSize) return(catch("UpdateInfos()    found odd value for MarketInfo(MODE_LOTSIZE): "+ lotSize, ERR_RUNTIME_ERROR));

   double tickValue = MarketInfo(symbol, MODE_TICKVALUE);
   double pipValue  = tickValue * ifInt(Digits==3 || Digits==5, 10, 1);
         ObjectSetText(names[TICKVALUE], StringConcatenate("Pip value: ", FormatNumber(pipValue, ", .2+"), " ", accountCurrency), Font.Size, Font.Name, Font.Color);
   double lotValue  = Bid / tickSize * tickValue;

   double minLot            = MarketInfo(symbol, MODE_MINLOT           ); ObjectSetText(names[MINLOT           ], StringConcatenate("Min lot: ", FormatNumber(minLot, ", .+")), Font.Size, Font.Name, Font.Color);
   double maxLot            = MarketInfo(symbol, MODE_MAXLOT           ); ObjectSetText(names[MAXLOT           ], StringConcatenate("Max lot: ", FormatNumber(maxLot, ", .+")), Font.Size, Font.Name, Font.Color);
      if (MathRound(maxLot) != maxLot) return(catch("UpdateInfos()    found odd value for MarketInfo(MODE_MAXLOT): "+ maxLot, ERR_RUNTIME_ERROR));
   double lotStep           = MarketInfo(symbol, MODE_LOTSTEP          ); ObjectSetText(names[LOTSTEP          ], StringConcatenate("Lot step: ", FormatNumber(lotStep, ", .+")), Font.Size, Font.Name, Font.Color);

   int    marginCalcMode    = MarketInfo(symbol, MODE_MARGINCALCMODE   ); ObjectSetText(names[MARGINCALCMODE   ], StringConcatenate("Margin calculation mode: ", strMCM[marginCalcMode]), Font.Size, Font.Name, Font.Color);
   double marginRequired    = MarketInfo(symbol, MODE_MARGINREQUIRED   );
      double marginLeverage = lotValue / marginRequired;                  ObjectSetText(names[MARGINREQUIRED   ], StringConcatenate("Margin required: ", FormatNumber(marginRequired, ", .2+"), " ", accountCurrency, " (1:", DoubleToStr(marginLeverage, 0), ")"), Font.Size, Font.Name, Font.Color);

   double marginInit        = MarketInfo(symbol, MODE_MARGININIT       ); ObjectSetText(names[MARGININIT       ], StringConcatenate("Margin init: ", FormatNumber(marginInit, ", .2+"), " ", accountCurrency), Font.Size, Font.Name, Font.Color);
   double marginMaintenance = MarketInfo(symbol, MODE_MARGINMAINTENANCE); ObjectSetText(names[MARGINMAINTENANCE], StringConcatenate("Margin maintenance: ", FormatNumber(marginMaintenance, ", .2+"), " ", accountCurrency), Font.Size, Font.Name, Font.Color);
   double marginHedged      = MarketInfo(symbol, MODE_MARGINHEDGED     );
      marginHedged = NormalizeDouble(marginHedged/lotSize * 100, 1);      ObjectSetText(names[MARGINHEDGED     ], StringConcatenate("Margin hedged: ", FormatNumber(marginHedged, ".+"), " %"), Font.Size, Font.Name, Font.Color);

   int    swapType          = MarketInfo(symbol, MODE_SWAPTYPE         ); ObjectSetText(names[SWAPTYPE         ], StringConcatenate("Swap calculation: ", strSCM[swapType]), Font.Size, Font.Name, Font.Color);
   double swapLong          = MarketInfo(symbol, MODE_SWAPLONG         ); ObjectSetText(names[SWAPLONG         ], StringConcatenate("Swap long: ", FormatNumber(swapLong, ".+")), Font.Size, Font.Name, Font.Color);
   double swapShort         = MarketInfo(symbol, MODE_SWAPSHORT        ); ObjectSetText(names[SWAPSHORT        ], StringConcatenate("Swap short: ", FormatNumber(swapShort, ".+")), Font.Size, Font.Name, Font.Color);

   int    profitCalcMode    = MarketInfo(symbol, MODE_PROFITCALCMODE   ); ObjectSetText(names[PROFITCALCMODE   ], StringConcatenate("Profit calculation mode: ", strPCM[profitCalcMode]), Font.Size, Font.Name, Font.Color);

   double starts            = MarketInfo(symbol, MODE_STARTING         ); if (starts  > 0) ObjectSetText(names[STARTING  ], StringConcatenate("Future starts: ", TimeToStr(starts)), Font.Size, Font.Name, Font.Color);
   double expires           = MarketInfo(symbol, MODE_EXPIRATION       ); if (expires > 0) ObjectSetText(names[EXPIRATION], StringConcatenate("Future expires: ", TimeToStr(expires)), Font.Size, Font.Name, Font.Color);


   int    accountLeverage   = AccountLeverage();     ObjectSetText(names[ACCOUNT_LEVERAGE], StringConcatenate("Account leverage: 1:", accountLeverage), Font.Size, Font.Name, Font.Color);
   int    stopoutMode       = AccountStopoutMode();  ObjectSetText(names[STOPOUT_MODE    ], StringConcatenate("Account stopout mode: ", strASM[stopoutMode]), Font.Size, Font.Name, Font.Color);
   int    stopoutLevel      = AccountStopoutLevel(); ObjectSetText(names[STOPOUT_LEVEL   ], StringConcatenate("Account stopout level: ", stopoutLevel, ifString(stopoutMode==ASM_PERCENT, " %", " "+ accountCurrency)), Font.Size, Font.Name, Font.Color);

   int error = GetLastError();
   if (error==ERR_NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)
      return(ERR_NO_ERROR);
   return(catch("UpdateInfos()", error));
}

/*
MODE_TRADEALLOWED       Trade is allowed for the symbol.
MODE_DIGITS             Count of digits after decimal point in the symbol prices. For the current symbol, it is stored in the predefined variable Digits

MODE_POINT              Point size in the quote currency. For the current symbol, it is stored in the predefined variable Point
MODE_TICKSIZE           Tick size in the quote currency.

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