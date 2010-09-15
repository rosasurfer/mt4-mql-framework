/**
 * Instrument Infos.mq4
 *
 * Zeigt die Eigenschaften eines Instruments an.
 */

#include <stdlib.mqh>


#property indicator_chart_window
#property indicator_buffers 0


#define TRADEALLOWED       0
#define DIGITS             1
#define POINT              2
#define SPREAD             3
#define TICKSIZE           4
#define TICKVALUE          5
#define STOPLEVEL          6
#define FREEZELEVEL        7
#define LOTSIZE            8
#define MINLOT             9
#define MAXLOT            10
#define LOTSTEP           11
#define MARGINCALCMODE    12
#define MARGINREQUIRED    13
#define MARGININIT        14
#define MARGINMAINTENANCE 15
#define MARGINHEDGED      16
#define SWAPTYPE          17
#define SWAPLONG          18
#define SWAPSHORT         19
#define PROFITCALCMODE    20
#define STARTING          21
#define EXPIRATION        22


string labels[] = { "TRADEALLOWED","DIGITS","POINT","SPREAD","TICKSIZE","TICKVALUE","STOPLEVEL","FREEZELEVEL","LOTSIZE","MINLOT","MAXLOT","LOTSTEP","MARGINCALCMODE","MARGINREQUIRED","MARGININIT","MARGINMAINTENANCE","MARGINHEDGED","SWAPTYPE","SWAPLONG","SWAPSHORT","PROFITCALCMODE","STARTING","EXPIRATION" };

string font      = "Tahoma";
int    fontSize  = 9;
color  fontColor = Blue;


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
   string tmp[];
   ArrayResize(tmp, ArraySize(labels));
   ArrayCopy(tmp, labels);
   RemoveChartObjects(tmp);      // RemoveChartObjects() setzt die Arraygröße auf 0 zurück

   for (int i=0; i < ArraySize(labels); i++) {
      if (ObjectCreate(labels[i], OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(labels[i], OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet(labels[i], OBJPROP_XDISTANCE,  20);
         ObjectSet(labels[i], OBJPROP_YDISTANCE, 170 + i*16);
         ObjectSetText(labels[i], " ", fontSize, font, fontColor);
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
   string strMCM[]  = { "Forex","CFD","Futures","CFD for Indices" };
   string strPCM[]  = { "Forex","CFD","Futures" };
   string strSCM[]  = { "in points","in base currency","by interest","in margin currency" };

   string symbol = Symbol();

   // über den MODE_PROFITCALCMODE definiert sich der Typ des Instruments, und den brauchen wir zuerst
   int    profitCalcMode    = MarketInfo(symbol, MODE_PROFITCALCMODE   ); ObjectSetText(labels[PROFITCALCMODE   ], StringConcatenate("Profit calculation mode: ", strPCM[profitCalcMode]), fontSize, font, fontColor);

   bool   tradeAllowed      = MarketInfo(symbol, MODE_TRADEALLOWED     ); ObjectSetText(labels[TRADEALLOWED     ], StringConcatenate("Trading enabled: ", strBool[0+tradeAllowed]), fontSize, font, fontColor);
   int    digits            = MarketInfo(symbol, MODE_DIGITS           ); ObjectSetText(labels[DIGITS           ], StringConcatenate("Digits: ", digits), fontSize, font, fontColor);

   double point             = MarketInfo(symbol, MODE_POINT            ); ObjectSetText(labels[POINT            ], StringConcatenate("1 point: ", DoubleToStrTrim(point)), fontSize, font, fontColor);
   int    spread            = MarketInfo(symbol, MODE_SPREAD           ); ObjectSetText(labels[SPREAD           ], StringConcatenate("Spread: ", spread, " points"), fontSize, font, fontColor);

   double tickSize          = MarketInfo(symbol, MODE_TICKSIZE         ); ObjectSetText(labels[TICKSIZE         ], StringConcatenate("Tick size: ", DoubleToStrTrim(tickSize)), fontSize, font, fontColor);
   double tickValue         = MarketInfo(symbol, MODE_TICKVALUE        ); ObjectSetText(labels[TICKVALUE        ], StringConcatenate("Tick value: ", DoubleToStrTrim(tickValue), " ", AccountCurrency()), fontSize, font, fontColor);
   int    stopLevel         = MarketInfo(symbol, MODE_STOPLEVEL        ); ObjectSetText(labels[STOPLEVEL        ], StringConcatenate("Stop level: ", stopLevel, " points"), fontSize, font, fontColor);
   int    freezeLevel       = MarketInfo(symbol, MODE_FREEZELEVEL      ); ObjectSetText(labels[FREEZELEVEL      ], StringConcatenate("Freeze level: ", freezeLevel, " points"), fontSize, font, fontColor);

   double lotSize           = MarketInfo(symbol, MODE_LOTSIZE          );
   int    iLotSize          = lotSize;                                    ObjectSetText(labels[LOTSIZE          ], StringConcatenate("Lot size: ", FormatPrice(iLotSize, 0), " units"), fontSize, font, fontColor);
      if (iLotSize != lotSize) return(catch("UpdateInfos()    got odd value for MarketInfo(MODE_LOTSIZE): "+ DoubleToStrTrim(lotSize), ERR_RUNTIME_ERROR));
   double minLot            = MarketInfo(symbol, MODE_MINLOT           ); ObjectSetText(labels[MINLOT           ], StringConcatenate("Min lot: ", DoubleToStrTrim(minLot)), fontSize, font, fontColor);
   double maxLot            = MarketInfo(symbol, MODE_MAXLOT           );
   int    iMaxLot           = maxLot;                                     ObjectSetText(labels[MAXLOT           ], StringConcatenate("Max lot: ", FormatPrice(iMaxLot, 0)), fontSize, font, fontColor);
      if (iMaxLot != maxLot)   return(catch("UpdateInfos()    got odd value for MarketInfo(MODE_MAXLOT): "+ DoubleToStrTrim(maxLot), ERR_RUNTIME_ERROR));
   double lotStep           = MarketInfo(symbol, MODE_LOTSTEP          ); ObjectSetText(labels[LOTSTEP          ], StringConcatenate("Lot step: ", DoubleToStrTrim(lotStep)), fontSize, font, fontColor);

   int    marginCalcMode    = MarketInfo(symbol, MODE_MARGINCALCMODE   ); ObjectSetText(labels[MARGINCALCMODE   ], StringConcatenate("Margin calculation mode: ", strMCM[marginCalcMode]), fontSize, font, fontColor);
   double marginRequired    = MarketInfo(symbol, MODE_MARGINREQUIRED   ); ObjectSetText(labels[MARGINREQUIRED   ], StringConcatenate("Margin required: ", DoubleToStrTrim(marginRequired)), fontSize, font, fontColor);
   double marginInit        = MarketInfo(symbol, MODE_MARGININIT       ); ObjectSetText(labels[MARGININIT       ], StringConcatenate("Margin init: ", DoubleToStrTrim(marginInit)), fontSize, font, fontColor);
   double marginMaintenance = MarketInfo(symbol, MODE_MARGINMAINTENANCE); ObjectSetText(labels[MARGINMAINTENANCE], StringConcatenate("Margin maintenance: ", DoubleToStrTrim(marginMaintenance)), fontSize, font, fontColor);
   double marginHedged      = MarketInfo(symbol, MODE_MARGINHEDGED     ); ObjectSetText(labels[MARGINHEDGED     ], StringConcatenate("Margin hedged: ", DoubleToStrTrim(marginHedged)), fontSize, font, fontColor);

   int    swapType          = MarketInfo(symbol, MODE_SWAPTYPE         ); ObjectSetText(labels[SWAPTYPE         ], StringConcatenate("Swap calculation: ", strSCM[swapType]), fontSize, font, fontColor);
   double swapLong          = MarketInfo(symbol, MODE_SWAPLONG         ); ObjectSetText(labels[SWAPLONG         ], StringConcatenate("Swap long: ", DoubleToStrTrim(swapLong)), fontSize, font, fontColor);
   double swapShort         = MarketInfo(symbol, MODE_SWAPSHORT        ); ObjectSetText(labels[SWAPSHORT        ], StringConcatenate("Swap short: ", DoubleToStrTrim(swapShort)), fontSize, font, fontColor);

   double starts            = MarketInfo(symbol, MODE_STARTING         ); if (starts  > 0) ObjectSetText(labels[STARTING  ], StringConcatenate("Future starts: ", TimeToStr(starts)), fontSize, font, fontColor);
   double expires           = MarketInfo(symbol, MODE_EXPIRATION       ); if (expires > 0) ObjectSetText(labels[EXPIRATION], StringConcatenate("Future expires: ", TimeToStr(expires)), fontSize, font, fontColor);

   int error = GetLastError();
   if (error==ERR_NO_ERROR || error==ERR_OBJECT_DOES_NOT_EXIST)
      return(ERR_NO_ERROR);
   return(catch("UpdateInfos()", error));
}

/*
MODE_TRADEALLOWED       Trade is allowed for the symbol.
MODE_DIGITS             Count of digits after decimal point in the symbol prices. For the current symbol, it is stored in the predefined variable Digits

MODE_POINT              Point size in the quote currency. For the current symbol, it is stored in the predefined variable Point
MODE_SPREAD             Spread value in points.

MODE_TICKSIZE           Tick size in the quote currency.
MODE_TICKVALUE          Tick value in the deposit currency.

MODE_STOPLEVEL          Stop level in points.
MODE_FREEZELEVEL        Order freeze level in points. If the execution price lies within the range defined by the freeze level, the order cannot be modified, cancelled or closed.

MODE_LOTSIZE            Lot size in the base currency.
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