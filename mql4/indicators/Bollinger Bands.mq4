/**
 * Bollinger Bands
 *
 * For normal distribution of natural data:
 *
 *  @see  https://upload.wikimedia.org/wikipedia/commons/3/3a/Standard_deviation_diagram_micro.svg#         [68–95–99.7 Rule]
 *
 *
 * Indicator buffers for iCustom():
 *  • Bands.MODE_MA:    MA values
 *  • Bands.MODE_UPPER: upper band values
 *  • Bands.MODE_LOWER: lower band value
 *
 *
 * TODO:
 *  - replace manual calculation of StdDev(ALMA) with correct syntax for iStdDevOnArray()
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods      = 200;
extern string MA.Method       = "SMA | LWMA | EMA* | SMMA | ALMA";
extern string MA.AppliedPrice = "Open | High | Low | Close* | Median | Typical | Weighted";
extern color  MA.Color        = LimeGreen;
extern int    MA.Width        = 0;

extern int    Bands.StdDevs   = 2;
extern color  Bands.Color     = Blue;
extern int    Bands.Width     = 1;

extern int    MaxBarsBack     = 10000;                // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/functions/ta/ALMA.mqh>

#define MODE_MA              Bands.MODE_MA            // indicator buffer ids
#define MODE_UPPER           Bands.MODE_UPPER
#define MODE_LOWER           Bands.MODE_LOWER
#define MODE_WIDTH           Bands.MODE_WIDTH

#property indicator_chart_window
#property indicator_buffers  4
int       terminal_buffers = 4;

#property indicator_style1   STYLE_DOT
#property indicator_style2   STYLE_SOLID
#property indicator_style3   STYLE_SOLID

double ma[];                                          // MA:         visible if configured
double upperBand[];                                   // upper band: visible
double lowerBand[];                                   // lower band: visible
double bandWidth[];                                   // band width: invisible, displayed in "Data" window

int    maMethod;
int    maAppliedPrice;
double almaWeights[];

string indicatorName = "";                            // name for chart legend
string legendLabel   = "";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // MA.Periods
   if (MA.Periods < 1)       return(catch("onInit(1)  invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   // MA.Method
   string values[], sValue = MA.Method;
   if (Explode(MA.Method, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   maMethod = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maMethod == -1)       return(catch("onInit(2)  invalid input parameter MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(maMethod);
   // MA.AppliedPrice
   sValue = MA.AppliedPrice;
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if (sValue == "") sValue = "close";                         // default price type
   maAppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maAppliedPrice == -1) return(catch("onInit(3)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(maAppliedPrice);
   // MA.Width
   if (MA.Width < 0)         return(catch("onInit(4)  invalid input parameter MA.Width: "+ MA.Width, ERR_INVALID_INPUT_PARAMETER));
   // Bands.StdDevs
   if (Bands.StdDevs < 0)    return(catch("onInit(5)  invalid input parameter Bands.StdDevs: "+ Bands.StdDevs, ERR_INVALID_INPUT_PARAMETER));
   // Bands.Width
   if (Bands.Width < 0)      return(catch("onInit(6)  invalid input parameter Bands.Width: "+ Bands.Width, ERR_INVALID_INPUT_PARAMETER));
   // MaxBarsBack
   if (MaxBarsBack < -1)     return(catch("onInit(7)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (MA.Color    == 0xFF000000) MA.Color    = CLR_NONE;
   if (Bands.Color == 0xFF000000) Bands.Color = CLR_NONE;

   // initialize indicator calculation
   if (maMethod==MODE_ALMA && MA.Periods > 1) {
      double offset=0.85, sigma=6.0;
      ALMA.CalculateWeights(MA.Periods, offset, sigma, almaWeights);
   }

   legendLabel = CreateChartLegend();
   SetIndicatorOptions();
   return(catch("onInit(8)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(ma,        EMPTY_VALUE);
      ArrayInitialize(upperBand, EMPTY_VALUE);
      ArrayInitialize(lowerBand, EMPTY_VALUE);
      ArrayInitialize(bandWidth, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(ma,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(upperBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(lowerBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(bandWidth, Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-MA.Periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   double deviation, price, sum;

   for (int bar=startbar; bar >= 0; bar--) {
      if (maMethod == MODE_ALMA) {
         ma[bar] = 0;
         for (int i=0; i < MA.Periods; i++) {
            ma[bar] += almaWeights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, maAppliedPrice, bar+i);
         }
         // calculate deviation manually (for some reason iStdDevOnArray() fails)
         //deviation = iStdDevOnArray(ma, WHOLE_ARRAY, MA.Periods, 0, MODE_SMA, bar) * StdDev.Multiplier;
         sum = 0;
         for (int j=0; j < MA.Periods; j++) {
            price = iMA(NULL, NULL, 1, 0, MODE_SMA, maAppliedPrice, bar+j);
            sum += (price-ma[bar]) * (price-ma[bar]);
         }
         deviation = MathSqrt(sum/MA.Periods) * Bands.StdDevs;
      }
      else {
         ma[bar]   = iMA    (NULL, NULL, MA.Periods, 0, maMethod, maAppliedPrice, bar);
         deviation = iStdDev(NULL, NULL, MA.Periods, 0, maMethod, maAppliedPrice, bar) * Bands.StdDevs;
      }
      upperBand[bar] = ma[bar] + deviation;
      lowerBand[bar] = ma[bar] - deviation;
      bandWidth[bar] = upperBand[bar] - lowerBand[bar];
   }

   // update chart legend
   if (!__isSuperContext) {
      if (__isChart) UpdateTrendLegend(legendLabel, indicatorName, "", Bands.Color, Bands.Color, bandWidth[0]);
   }
   return(last_error);
}


/**
 * Set indicator options. After recompilation the function must be called from start() for options not to be ignored.
 *
 * @param  bool redraw [optional] - whether to redraw the chart (default: no)
 *
 * @return bool - success status
 */
bool SetIndicatorOptions(bool redraw = false) {
   string sMaAppliedPrice = ifString(maAppliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(maAppliedPrice));
   indicatorName = "BollingerBands "+ MA.Method +"("+ MA.Periods + sMaAppliedPrice +") ±"+ Bands.StdDevs +"SD";
   IndicatorShortName("BollingerBands("+ MA.Periods +")");

   IndicatorBuffers(terminal_buffers);
   SetIndexBuffer(MODE_MA,    ma);
   SetIndexBuffer(MODE_UPPER, upperBand);
   SetIndexBuffer(MODE_LOWER, lowerBand);
   SetIndexBuffer(MODE_WIDTH, bandWidth);
   IndicatorDigits(Digits);

   int startDraw = Bars - MaxBarsBack;
   SetIndexDrawBegin(MODE_MA,    startDraw);
   SetIndexDrawBegin(MODE_UPPER, startDraw);
   SetIndexDrawBegin(MODE_LOWER, startDraw);

   int maDrawType    = ifInt(!MA.Width    || MA.Color==CLR_NONE,    DRAW_NONE, DRAW_LINE);
   int bandsDrawType = ifInt(!Bands.Width || Bands.Color==CLR_NONE, DRAW_NONE, DRAW_LINE);
   SetIndexStyle(MODE_MA,    maDrawType,    EMPTY, MA.Width,    MA.Color   );
   SetIndexStyle(MODE_UPPER, bandsDrawType, EMPTY, Bands.Width, Bands.Color);
   SetIndexStyle(MODE_LOWER, bandsDrawType, EMPTY, Bands.Width, Bands.Color);
   SetIndexStyle(MODE_WIDTH, DRAW_NONE);

   SetIndexLabel(MODE_MA,    MA.Method +"("+ MA.Periods + sMaAppliedPrice +")"); if (maDrawType    == DRAW_NONE) SetIndexLabel(MODE_MA,    NULL);
   SetIndexLabel(MODE_UPPER, "BBand("+ MA.Periods +") upper");                   if (bandsDrawType == DRAW_NONE) SetIndexLabel(MODE_UPPER, NULL);
   SetIndexLabel(MODE_LOWER, "BBand("+ MA.Periods +") lower");                   if (bandsDrawType == DRAW_NONE) SetIndexLabel(MODE_LOWER, NULL);
   SetIndexLabel(MODE_WIDTH, "BBand("+ MA.Periods +") width");

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",      MA.Periods,                      ";", NL,
                            "MA.Method=",       DoubleQuoteStr(MA.Method),       ";", NL,
                            "MA.AppliedPrice=", DoubleQuoteStr(MA.AppliedPrice), ";", NL,
                            "MA.Color=",        ColorToStr(MA.Color),            ";", NL,
                            "MA.Width=",        MA.Width,                        ";", NL,
                            "Bands.StdDevs=",   Bands.StdDevs,                   ";", NL,
                            "Bands.Color=",     ColorToStr(Bands.Color),         ";", NL,
                            "Bands.Width=",     Bands.Width,                     ";", NL,
                            "MaxBarsBack=",     MaxBarsBack,                     ";")
   );
}
