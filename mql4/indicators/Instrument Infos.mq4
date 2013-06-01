/**
 * Zeigt die Eigenschaften eines Instruments an.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/indicator.mqh>

#property indicator_chart_window


color  Background.Color    = C'212,208,200';
color  Font.Color.Enabled  = Blue;
color  Font.Color.Disabled = Gray;
string Font.Name           = "Tahoma";
int    Font.Size           = 9;

string names[] = {"TRADEALLOWED","POINT","TICKSIZE","TICKVALUE","SPREAD","STOPLEVEL","FREEZELEVEL","LOTSIZE","MINLOT","LOTSTEP","MAXLOT","MARGINREQUIRED","MARGINHEDGED","SWAPLONG","SWAPSHORT","ACCOUNT_SERVER","ACCOUNT_LEVERAGE","STOPOUT_LEVEL"};

#define I_TRADEALLOWED         0
#define I_POINT                1
#define I_TICKSIZE             2
#define I_TICKVALUE            3
#define I_SPREAD               4
#define I_STOPLEVEL            5
#define I_FREEZELEVEL          6
#define I_LOTSIZE              7
#define I_MINLOT               8
#define I_LOTSTEP              9
#define I_MAXLOT              10
#define I_MARGINREQUIRED      11
#define I_MARGINHEDGED        12
#define I_SWAPLONG            13
#define I_SWAPSHORT           14
#define I_ACCOUNT_SERVER      15
#define I_ACCOUNT_LEVERAGE    16
#define I_STOPOUT_LEVEL       17


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);

   CreateLabels();
   return(catch("onInit()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   RemoveChartObjects();
   return(catch("onDeinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (IsError(prev_error))
      return(SetLastError(prev_error));

   UpdateInfos();
   return(last_error);
}


/**
 *
 */
int CreateLabels() {
   int c = 10;

   // Background
   c++;
   string label = StringConcatenate(__NAME__, ".", c, ".Background");
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE, 14);
      ObjectSet(label, OBJPROP_YDISTANCE, 134);
      ObjectSetText(label, "g", 174, "Webdings", Background.Color);
      PushChartObject(label);
   }
   else GetLastError();

   c++;
   label = StringConcatenate(__NAME__, ".", c, ".Background");
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE, 14);
      ObjectSet(label, OBJPROP_YDISTANCE, 245);
      ObjectSetText(label, "g", 174, "Webdings", Background.Color);
      PushChartObject(label);
   }
   else GetLastError();

   // Textlabel
   int yCoord = 140;
   for (int i=0; i < ArraySize(names); i++) {
      c++;
      label = StringConcatenate(__NAME__, ".", c, ".", names[i]);
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet(label, OBJPROP_XDISTANCE,  20);
            static int fields[] = {I_POINT, I_SPREAD, I_LOTSIZE, I_MARGINREQUIRED, I_SWAPLONG, I_ACCOUNT_SERVER};
            if (IntInArray(fields, i))
               yCoord += 8;
         ObjectSet(label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, " ", Font.Size, Font.Name);
         PushChartObject(label);
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
   string strMCM [] = { "Forex","CFD","CFD Futures","CFD Index","CFD Leverage" };               // margin calculation modes
   string strPCM [] = { "Forex","CFD","Futures" };                                              // profit calculation modes
   string strSCM [] = { "in points","in base currency","by interest","in margin currency" };    // swap calculation modes

   string symbol          = Symbol();
   string accountCurrency = AccountCurrency();
   bool   tradeAllowed    = _bool(MarketInfo(symbol, MODE_TRADEALLOWED));
   color  Font.Color      = ifInt(tradeAllowed, Font.Color.Enabled, Font.Color.Disabled);

                                                                        ObjectSetText(names[I_TRADEALLOWED  ], "Trading enabled: "+ strBool[0+tradeAllowed], Font.Size, Font.Name, Font.Color);
                                                                        ObjectSetText(names[I_POINT         ], "Point size:  "    + NumberToStr(Point, PriceFormat), Font.Size, Font.Name, Font.Color);
   double tickSize     = MarketInfo(symbol, MODE_TICKSIZE);             ObjectSetText(names[I_TICKSIZE      ], "Tick size:   "    + NumberToStr(tickSize, PriceFormat), Font.Size, Font.Name, Font.Color);

   double spread       = MarketInfo(symbol, MODE_SPREAD     )/PipPoints;
   double stopLevel    = MarketInfo(symbol, MODE_STOPLEVEL  )/PipPoints;
   double freezeLevel  = MarketInfo(symbol, MODE_FREEZELEVEL)/PipPoints;
      string strSpread      = DoubleToStr(spread,      Digits<<31>>31); ObjectSetText(names[I_SPREAD        ], "Spread:        "  + strSpread +" pip", Font.Size, Font.Name, Font.Color);
      string strStopLevel   = DoubleToStr(stopLevel,   Digits<<31>>31); ObjectSetText(names[I_STOPLEVEL     ], "Stop level:   "   + strStopLevel +" pip", Font.Size, Font.Name, Font.Color);
      string strFreezeLevel = DoubleToStr(freezeLevel, Digits<<31>>31); ObjectSetText(names[I_FREEZELEVEL   ], "Freeze level: "   + strFreezeLevel +" pip", Font.Size, Font.Name, Font.Color);

   double tickValue         = MarketInfo(symbol, MODE_TICKVALUE     );
   double pointValue        = tickValue/(tickSize/Point);
   double pipValue          = PipPoints * pointValue;                   ObjectSetText(names[I_TICKVALUE     ], "Pip value:  "     + NumberToStr(pipValue, ", .2+") +" "+ accountCurrency, Font.Size, Font.Name, Font.Color);

   double lotSize           = MarketInfo(symbol, MODE_LOTSIZE       );  ObjectSetText(names[I_LOTSIZE       ], "Lot size:  "      + NumberToStr(lotSize, ", .+") +" units", Font.Size, Font.Name, Font.Color);
   double minLot            = MarketInfo(symbol, MODE_MINLOT        );  ObjectSetText(names[I_MINLOT        ], "Min lot:    "     + NumberToStr(minLot, ", .+"), Font.Size, Font.Name, Font.Color);
   double lotStep           = MarketInfo(symbol, MODE_LOTSTEP       );  ObjectSetText(names[I_LOTSTEP       ], "Lot step: "       + NumberToStr(lotStep, ", .+"), Font.Size, Font.Name, Font.Color);
   double maxLot            = MarketInfo(symbol, MODE_MAXLOT        );  ObjectSetText(names[I_MAXLOT        ], "Max lot:   "      + NumberToStr(maxLot, ", .+"), Font.Size, Font.Name, Font.Color);

   double marginRequired    = MarketInfo(symbol, MODE_MARGINREQUIRED); if (marginRequired == -92233720368547760.) marginRequired = EMPTY;
   double lotValue          = Close[0]/tickSize * tickValue;
   double leverage          = lotValue/marginRequired;                  ObjectSetText(names[I_MARGINREQUIRED], "Margin required: "+ ifString(marginRequired==EMPTY, "", NumberToStr(marginRequired, ", .2+") +" "+ accountCurrency +"  (1:"+ Round(leverage) +")"), Font.Size, Font.Name, ifInt(marginRequired==EMPTY, Font.Color.Disabled, Font.Color));
   double marginHedged      = MarketInfo(symbol, MODE_MARGINHEDGED  );
          marginHedged      = marginHedged/lotSize * 100;               ObjectSetText(names[I_MARGINHEDGED  ], "Margin hedged:  " + ifString(marginRequired==EMPTY, "", Round(marginHedged) +"%"), Font.Size, Font.Name, ifInt(marginRequired==EMPTY, Font.Color.Disabled, Font.Color));

   int    swapType          = MarketInfo(symbol, MODE_SWAPTYPE      );
   double swapLong          = MarketInfo(symbol, MODE_SWAPLONG      );
   double swapShort         = MarketInfo(symbol, MODE_SWAPSHORT     );
      double swapLongD, swapShortD, swapLongY, swapShortY;
      if (swapType == SCM_POINTS) {
         swapLongD  = swapLong *Point/Pip;       swapLongY  = swapLongD *Pip*360*100/Close[0];
         swapShortD = swapShort*Point/Pip;       swapShortY = swapShortD*Pip*360*100/Close[0];
      }
      else if (swapType == SCM_INTEREST) {
         swapLongD  = swapLong *Close[0]/100/360/Pip; swapLongY  = swapLong;
         swapShortD = swapShort*Close[0]/100/360/Pip; swapShortY = swapShort;
      }
      else {
         if (swapType == SCM_BASE_CURRENCY) {
         }
         else if (swapType == SCM_MARGIN_CURRENCY) {     // Deposit-Currency
         }
      }
      ObjectSetText(names[I_SWAPLONG ], "Swap long:  "+ NumberToStr(swapLongD,  "+.2") +" pip = "+ NumberToStr(swapLongY,  "+.2") +"% p.a.", Font.Size, Font.Name, Font.Color);
      ObjectSetText(names[I_SWAPSHORT], "Swap short: "+ NumberToStr(swapShortD, "+.2") +" pip = "+ NumberToStr(swapShortY, "+.2") +"% p.a.", Font.Size, Font.Name, Font.Color);

   string accountServer   = GetServerDirectory();                       ObjectSetText(names[I_ACCOUNT_SERVER  ], "Account server: "        + accountServer, Font.Size, Font.Name, ifInt(!StringLen(accountServer), Font.Color.Disabled, Font.Color));
   int    accountLeverage = AccountLeverage();                          ObjectSetText(names[I_ACCOUNT_LEVERAGE], "Account leverage:       "+ ifString(!accountLeverage, "", "1:"+ Round(accountLeverage)), Font.Size, Font.Name, ifInt(!accountLeverage, Font.Color.Disabled, Font.Color));
   int    stopoutLevel    = AccountStopoutLevel();                      ObjectSetText(names[I_STOPOUT_LEVEL   ], "Account stopout level: " + ifString(!accountLeverage, "",  NumberToStr(NormalizeDouble(stopoutLevel, 2), ", .+") + ifString(AccountStopoutMode()==ASM_PERCENT, "%", " "+ accountCurrency)), Font.Size, Font.Name, ifInt(!accountLeverage, Font.Color.Disabled, Font.Color));


   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)
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

MODE_PROFITCALCMODE     Profit calculation mode. 0 - Forex; 1 - CFD; 2 - Futures.

MODE_STARTING           Market starting date (usually used for futures).
MODE_EXPIRATION         Market expiration date (usually used for futures).
*/
