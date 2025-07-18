/**
 * Keltner Channel - an ATR channel around a Moving Average
 *
 * Channel bands are defined as:
 *  UpperBand = MA + ATR * Multiplier
 *  LowerBand = MA - ATR * Multiplier
 *
 * Supported Moving-Averages:
 *  � SMA  - Simple Moving Average:          equal bar weighting
 *  � LWMA - Linear Weighted Moving Average: bar weighting using a linear function
 *  � EMA  - Exponential Moving Average:     bar weighting using an exponential function
 *  � ALMA - Arnaud Legoux Moving Average:   bar weighting using a Gaussian function
 *  � SMMA - Smoothed Moving Average:        an EMA, it holds: SMMA(n) = EMA(2*n-1)
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string MA.Method       = "SMA* | LWMA | EMA | SMMA | ALMA";
extern int    MA.Periods      = 10;
extern string MA.AppliedPrice = "Open | High | Low | Close* | Median | Typical | Weighted";
extern color  MA.Color        = CLR_NONE;

extern string ATR.Timeframe   = "current* | M1 | M5 | M15 | ..."; // empty: current
extern int    ATR.Periods     = 60;
extern double ATR.Multiplier  = 1;
extern color  Bands.Color     = Blue;
extern int    MaxBarsBack     = 10000;                            // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/functions/ta/ALMA.mqh>

#define MODE_MA               Bands.MODE_MA                       // indicator buffer ids
#define MODE_UPPER            Bands.MODE_UPPER
#define MODE_LOWER            Bands.MODE_LOWER

#property indicator_chart_window
#property indicator_buffers   3

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE

#property indicator_style1    STYLE_DOT
#property indicator_style2    STYLE_SOLID
#property indicator_style3    STYLE_SOLID


double ma       [];
double upperBand[];
double lowerBand[];

int    maMethod;
int    maPeriods;
int    maAppliedPrice;
double almaWeights[];                                             // ALMA bar weights

int    atrTimeframe;
int    atrPeriods;
double atrMultiplier;

string indicatorName = "";
string legendLabel   = "";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // MA.Method
   string sValues[], sValue = MA.Method;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   maMethod = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maMethod == -1)        return(catch("onInit(1)  invalid input parameter MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(maMethod);
   // MA.Periods
   if (MA.Periods < 0)        return(catch("onInit(2)  invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   maPeriods = ifInt(!MA.Periods, 1, MA.Periods);
   // MA.AppliedPrice
   sValue = StrToLower(MA.AppliedPrice);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                            // default price type
   maAppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maAppliedPrice == -1)  return(catch("onInit(3)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(maAppliedPrice);

   // ATR
   sValue = ATR.Timeframe;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue=="" || sValue=="0" || sValue=="current") {
      atrTimeframe  = Period();
      ATR.Timeframe = "current";
   }
   else {
      atrTimeframe = StrToTimeframe(sValue, F_ERR_INVALID_PARAMETER);
      if (atrTimeframe == -1) return(catch("onInit(4)  invalid input parameter ATR.Timeframe: "+ DoubleQuoteStr(ATR.Timeframe), ERR_INVALID_INPUT_PARAMETER));
      ATR.Timeframe = TimeframeDescription(atrTimeframe);
   }
   if (ATR.Periods < 1)       return(catch("onInit(5)  invalid input parameter ATR.Periods: "+ ATR.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (ATR.Multiplier < 0)    return(catch("onInit(6)  invalid input parameter ATR.Multiplier: "+ NumberToStr(ATR.Multiplier, ".+"), ERR_INVALID_INPUT_PARAMETER));
   atrPeriods    = ATR.Periods;
   atrMultiplier = ATR.Multiplier;

   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (MA.Color    == 0xFF000000) MA.Color    = CLR_NONE;
   if (Bands.Color == 0xFF000000) Bands.Color = CLR_NONE;

   // MaxBarsBack
   if (MaxBarsBack < -1)      return(catch("onInit(7)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // buffer management
   SetIndexBuffer(MODE_MA,    ma       );
   SetIndexBuffer(MODE_UPPER, upperBand);
   SetIndexBuffer(MODE_LOWER, lowerBand);

   // names, labels and display options
   legendLabel = CreateChartLegend();
   string sMa            = MA.Method +"("+ maPeriods +")";
   string sAtrMultiplier = ifString(atrMultiplier==1, "", NumberToStr(atrMultiplier, ".+") +"*");
   string sAtrTimeframe  = ifString(ATR.Timeframe=="current", "", "x"+ ATR.Timeframe);
   string sAtr           = sAtrMultiplier +"ATR("+ atrPeriods + sAtrTimeframe +")";
   indicatorName         = WindowExpertName() +" "+ sMa +" � "+ sAtr;
   IndicatorShortName(indicatorName);                 // chart tooltips and context menu
   SetIndexLabel(MODE_MA,    "KChannel MA"); if (MA.Color == CLR_NONE) SetIndexLabel(MODE_MA, NULL);
   SetIndexLabel(MODE_UPPER, "KChannel Upper");       // chart tooltips and "Data" window
   SetIndexLabel(MODE_LOWER, "KChannel Lower");

   IndicatorDigits(Digits);
   SetIndicatorOptions();

   // calculate ALMA bar weights
   if (maMethod == MODE_ALMA) {
      double almaOffset=0.85, almaSigma=6.0;
      ALMA.CalculateWeights(maPeriods, almaOffset, almaSigma, almaWeights);
   }
   return(catch("onInit(8)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(ma)) return(logInfo("onTick(1)  sizeof(ma) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(ma,        EMPTY_VALUE);
      ArrayInitialize(upperBand, EMPTY_VALUE);
      ArrayInitialize(lowerBand, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(ma,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(upperBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(lowerBand, Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack, ChangedBars, Bars-maPeriods+1) - 1;
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   if (maMethod == MODE_ALMA) {
      RecalcALMAChannel(startbar);
   }
   else {
      for (int bar=startbar; bar >= 0; bar--) {
         double atr = iATR(NULL, atrTimeframe, atrPeriods, bar) * atrMultiplier;

         ma       [bar] = iMA(NULL, NULL, maPeriods, 0, maMethod, maAppliedPrice, bar);
         upperBand[bar] = ma[bar] + atr;
         lowerBand[bar] = ma[bar] - atr;
      }
   }
   if (!__isSuperContext) {
      UpdateBandLegend(legendLabel, indicatorName, "", Bands.Color, upperBand[0], lowerBand[0]);
   }
   return(last_error);
}


/**
 * Recalculate the changed bars of an ALMA based Keltner Channel.
 *
 * @param  int startbar
 *
 * @return bool - success status
 */
bool RecalcALMAChannel(int startbar) {
   for (int i, j, bar=startbar; bar >= 0; bar--) {
      double atr = iATR(NULL, atrTimeframe, atrPeriods, bar) * atrMultiplier;

      ma[bar] = 0;
      for (i=0; i < maPeriods; i++) {
         ma[bar] += almaWeights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, maAppliedPrice, bar+i);
      }
      upperBand[bar] = ma[bar] + atr;
      lowerBand[bar] = ma[bar] - atr;
   }
   return(!catch("RecalcALMAChannel(1)"));
}


/**
 * Set indicator options. After recompilation the function must be called from start() for options not to be ignored.
 *
 * @param  bool redraw [optional] - whether to redraw the chart (default: no)
 *
 * @return bool - success status
 */
bool SetIndicatorOptions(bool redraw = false) {
   redraw = redraw!=0;
   int drawType = ifInt(MA.Color==CLR_NONE, DRAW_NONE, DRAW_LINE);

   SetIndexStyle(MODE_MA,    drawType,  EMPTY, EMPTY, MA.Color   );
   SetIndexStyle(MODE_UPPER, DRAW_LINE, EMPTY, EMPTY, Bands.Color);
   SetIndexStyle(MODE_LOWER, DRAW_LINE, EMPTY, EMPTY, Bands.Color);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Method=",       DoubleQuoteStr(MA.Method),         ";", NL,
                            "MA.Periods=",      MA.Periods,                        ";", NL,
                            "MA.AppliedPrice=", DoubleQuoteStr(MA.AppliedPrice),   ";", NL,
                            "MA.Color=",        ColorToStr(MA.Color),              ";", NL,
                            "ATR.Timeframe=",   DoubleQuoteStr(ATR.Timeframe),     ";", NL,
                            "ATR.Periods=",     ATR.Periods,                       ";", NL,
                            "ATR.Multiplier=",  NumberToStr(ATR.Multiplier, ".+"), ";", NL,
                            "Bands.Color=",     ColorToStr(Bands.Color),           ";", NL,
                            "MaxBarsBack=",     MaxBarsBack,                       ";")
   );
}
