/**
 * Instrument Infos.mq4
 *
 * Zeigt die Eigenschaften eines Instruments an.
 */

#include <stdlib.mqh>


#property indicator_chart_window
#property indicator_buffers 0


//////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////

       string Font.Name        = "Tahoma";
extern int    Font.Size        = 9;
extern color  Font.Color       = Blue;
extern color  Background.Color = C'212,208,200';   // C'212,208,200'

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string names[] = { "TRADEALLOWED","DIGITS","POINT","TICKSIZE","TICKVALUE","SPREAD","STOPLEVEL","FREEZELEVEL","LOTSIZE","MINLOT","MAXLOT","LOTSTEP","MARGINCALCMODE","MARGINREQUIRED","MARGININIT","MARGINMAINTENANCE","MARGINHEDGED","SWAPTYPE","SWAPLONG","SWAPSHORT","PROFITCALCMODE","STARTING","EXPIRATION" };

#define TRADEALLOWED       0
#define DIGITS             1
#define POINT              2
#define TICKSIZE           3
#define TICKVALUE          4
#define SPREAD             5
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
      ObjectSetText(label, "g", 140, "Webdings", Background.Color);
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
      ObjectSet(label, OBJPROP_YDISTANCE, 164 + 158);
      ObjectSetText(label, "g", 140, "Webdings", Background.Color);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   // Textlabel
   for (int i=0; i < ArraySize(names); i++) {
      c++;
      label = StringConcatenate(expertName, ".", c, ".", names[i]);
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet(label, OBJPROP_XDISTANCE,  20);
         ObjectSet(label, OBJPROP_YDISTANCE, 170 + i*16);
         ObjectSetText(label, " ", Font.Size, Font.Name, Font.Color);
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
   string strMCM[]  = { "Forex","CFD","Futures","CFD for Indices" };                         // margin calculation modes
   string strPCM[]  = { "Forex","CFD","Futures" };                                           // profit calculation modes
   string strSCM[]  = { "in points","in base currency","by interest","in margin currency" }; // swap calculation modes

   string symbol = Symbol();

   bool   tradeAllowed = MarketInfo(symbol, MODE_TRADEALLOWED);           ObjectSetText(names[TRADEALLOWED     ], StringConcatenate("Trading enabled: ", strBool[0+tradeAllowed]), Font.Size, Font.Name, Font.Color);
   double point        = Point;                                           ObjectSetText(names[POINT            ], StringConcatenate("1 point: ", DoubleToStrTrim(point)), Font.Size, Font.Name, Font.Color);
   double tickSize     = MarketInfo(symbol, MODE_TICKSIZE);               ObjectSetText(names[TICKSIZE         ], StringConcatenate("Tick size: ", DoubleToStrTrim(tickSize)), Font.Size, Font.Name, Font.Color);
   double tickValue    = MarketInfo(symbol, MODE_TICKVALUE);              ObjectSetText(names[TICKVALUE        ], StringConcatenate("Tick value: ", DoubleToStrTrim(tickValue), " ", AccountCurrency()), Font.Size, Font.Name, Font.Color);

   int    spread       = MarketInfo(symbol, MODE_SPREAD); 
   int    stopLevel    = MarketInfo(symbol, MODE_STOPLEVEL);
   int    freezeLevel  = MarketInfo(symbol, MODE_FREEZELEVEL);
      string strSpread=spread, strStopLevel=stopLevel, strFreezeLevel=freezeLevel; 
      if (Digits==3 || Digits==5) {
         strSpread      = NumberToStr(spread     /10.0, ".1");                  
         strStopLevel   = NumberToStr(stopLevel  /10.0, ".1");            
         strFreezeLevel = NumberToStr(freezeLevel/10.0, ".1");        
      }
      ObjectSetText(names[SPREAD     ], StringConcatenate("Spread: ", strSpread, " pip"), Font.Size, Font.Name, Font.Color);
      ObjectSetText(names[STOPLEVEL  ], StringConcatenate("Stop level: ", strStopLevel, " pip"), Font.Size, Font.Name, Font.Color);      
      ObjectSetText(names[FREEZELEVEL], StringConcatenate("Freeze level: ", strFreezeLevel, " pip"), Font.Size, Font.Name, Font.Color);

   double lotSize           = MarketInfo(symbol, MODE_LOTSIZE          );
   int    iLotSize          = lotSize;                                    ObjectSetText(names[LOTSIZE          ], StringConcatenate("Lot size: ", FormatPrice(iLotSize, 0), " units"), Font.Size, Font.Name, Font.Color);
      if (iLotSize != lotSize) return(catch("UpdateInfos()    got odd value for MarketInfo(MODE_LOTSIZE): "+ DoubleToStrTrim(lotSize), ERR_RUNTIME_ERROR));
   double minLot            = MarketInfo(symbol, MODE_MINLOT           ); ObjectSetText(names[MINLOT           ], StringConcatenate("Min lot: ", DoubleToStrTrim(minLot)), Font.Size, Font.Name, Font.Color);
   double maxLot            = MarketInfo(symbol, MODE_MAXLOT           );
   int    iMaxLot           = maxLot;                                     ObjectSetText(names[MAXLOT           ], StringConcatenate("Max lot: ", FormatPrice(iMaxLot, 0)), Font.Size, Font.Name, Font.Color);
      if (iMaxLot != maxLot)   return(catch("UpdateInfos()    got odd value for MarketInfo(MODE_MAXLOT): "+ DoubleToStrTrim(maxLot), ERR_RUNTIME_ERROR));
   double lotStep           = MarketInfo(symbol, MODE_LOTSTEP          ); ObjectSetText(names[LOTSTEP          ], StringConcatenate("Lot step: ", DoubleToStrTrim(lotStep)), Font.Size, Font.Name, Font.Color);

   int    marginCalcMode    = MarketInfo(symbol, MODE_MARGINCALCMODE   ); ObjectSetText(names[MARGINCALCMODE   ], StringConcatenate("Margin calculation mode: ", strMCM[marginCalcMode]), Font.Size, Font.Name, Font.Color);
   double marginRequired    = MarketInfo(symbol, MODE_MARGINREQUIRED   ); ObjectSetText(names[MARGINREQUIRED   ], StringConcatenate("Margin required: ", DoubleToStrTrim(marginRequired)), Font.Size, Font.Name, Font.Color);
   double marginInit        = MarketInfo(symbol, MODE_MARGININIT       ); ObjectSetText(names[MARGININIT       ], StringConcatenate("Margin init: ", DoubleToStrTrim(marginInit)), Font.Size, Font.Name, Font.Color);
   double marginMaintenance = MarketInfo(symbol, MODE_MARGINMAINTENANCE); ObjectSetText(names[MARGINMAINTENANCE], StringConcatenate("Margin maintenance: ", DoubleToStrTrim(marginMaintenance)), Font.Size, Font.Name, Font.Color);
   double marginHedged      = MarketInfo(symbol, MODE_MARGINHEDGED     ); ObjectSetText(names[MARGINHEDGED     ], StringConcatenate("Margin hedged: ", DoubleToStrTrim(marginHedged)), Font.Size, Font.Name, Font.Color);

   int    swapType          = MarketInfo(symbol, MODE_SWAPTYPE         ); ObjectSetText(names[SWAPTYPE         ], StringConcatenate("Swap calculation: ", strSCM[swapType]), Font.Size, Font.Name, Font.Color);
   double swapLong          = MarketInfo(symbol, MODE_SWAPLONG         ); ObjectSetText(names[SWAPLONG         ], StringConcatenate("Swap long: ", DoubleToStrTrim(swapLong)), Font.Size, Font.Name, Font.Color);
   double swapShort         = MarketInfo(symbol, MODE_SWAPSHORT        ); ObjectSetText(names[SWAPSHORT        ], StringConcatenate("Swap short: ", DoubleToStrTrim(swapShort)), Font.Size, Font.Name, Font.Color);

   int    profitCalcMode    = MarketInfo(symbol, MODE_PROFITCALCMODE   ); ObjectSetText(names[PROFITCALCMODE   ], StringConcatenate("Profit calculation mode: ", strPCM[profitCalcMode]), Font.Size, Font.Name, Font.Color);

   double starts            = MarketInfo(symbol, MODE_STARTING         ); if (starts  > 0) ObjectSetText(names[STARTING  ], StringConcatenate("Future starts: ", TimeToStr(starts)), Font.Size, Font.Name, Font.Color);
   double expires           = MarketInfo(symbol, MODE_EXPIRATION       ); if (expires > 0) ObjectSetText(names[EXPIRATION], StringConcatenate("Future expires: ", TimeToStr(expires)), Font.Size, Font.Name, Font.Color);

   int error = GetLastError();
   if (error==ERR_NO_ERROR /*|| error==ERR_OBJECT_DOES_NOT_EXIST*/)
      return(ERR_NO_ERROR);
   return(catch("UpdateInfos()", error));
}

/*
MODE_TRADEALLOWED       Trade is allowed for the symbol.
MODE_DIGITS             Count of digits after decimal point in the symbol prices. For the current symbol, it is stored in the predefined variable Digits

MODE_POINT              Point size in the quote currency. For the current symbol, it is stored in the predefined variable Point
MODE_TICKSIZE           Tick size in the quote currency.
MODE_TICKVALUE          Tick value in the deposit currency.

MODE_SPREAD             Spread value in points.
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