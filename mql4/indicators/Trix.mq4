/**
 * Triple Smoothed Exponential Moving Average Oscillator = Slope(TriEMA, Lookback=1)
 *
 *
 * The Trix Oscillator displays the rate of change (the slope) between two consecutive triple smoothed EMA (TriEMA) values.
 * The unit is "bps" (1 base point = 1/100th of a percent).
 *
 * Indicator buffers to use with iCustom():
 *  • Slope.MODE_MAIN:   Trix main value
 *  • Slope.MODE_TREND:  trend direction and length
 *    - trend direction: positive values represent an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:    the absolute direction value is the length of the trend in bars since the last reversal
 *
 * To detect a crossing of the zero line use MovingAverage.MODE_TREND of the underlying TriEMA.
 *
 *
 * TODO: SMA signal line
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    EMA.Periods           = 38;
extern string EMA.AppliedPrice      = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  MainLine.Color        = DodgerBlue;           // indicator style management in MQL
extern int    MainLine.Width        = 1;

extern color  Histogram.Color.Upper = LimeGreen;
extern color  Histogram.Color.Lower = Red;
extern int    Histogram.Style.Width = 2;

extern int    Max.Values            = 3000;                 // max. number of values to display: -1 = all

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/@Trend.mqh>

#define MODE_MAIN             Slope.MODE_MAIN               // indicator buffer ids
#define MODE_TREND            Slope.MODE_TREND
#define MODE_UPPER_SECTION    2
#define MODE_LOWER_SECTION    3
#define MODE_EMA_1            4
#define MODE_EMA_2            5
#define MODE_EMA_3            6

#property indicator_separate_window
#property indicator_level1    0

#property indicator_buffers   4

#property indicator_width1    1
#property indicator_width2    0
#property indicator_width3    2
#property indicator_width4    2

double trixMain [];                                         // Trix main line:                 visible, "Data" window
double trixTrend[];                                         // trend direction and length:     invisible
double trixUpper[];                                         // positive histogram values:      visible
double trixLower[];                                         // negative histogram values:      visible
double firstEma [];                                         // first intermediate EMA buffer:  invisible
double secondEma[];                                         // second intermediate EMA buffer: invisible
double thirdEma [];                                         // third intermediate EMA buffer:  invisible

int    ema.appliedPrice;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (InitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // (1) validate inputs
   // EMA.Periods
   if (EMA.Periods < 1)           return(catch("onInit(1)  Invalid input parameter EMA.Periods = "+ EMA.Periods, ERR_INVALID_INPUT_PARAMETER));

   // EMA.AppliedPrice
   string elems[], sValue = EMA.AppliedPrice;
   if (Explode(EMA.AppliedPrice, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      sValue = elems[size-1];
   }
   sValue = StringTrim(sValue);
   if (sValue == "") sValue = "Close";                                           // default: PRICE_CLOSE
   ema.appliedPrice = StrToPriceType(sValue, F_ERR_INVALID_PARAMETER);
   if (ema.appliedPrice==-1 || ema.appliedPrice > PRICE_WEIGHTED)
                                  return(catch("onInit(2)  Invalid input parameter EMA.AppliedPrice = "+ DoubleQuoteStr(EMA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   EMA.AppliedPrice = PriceTypeDescription(ema.appliedPrice);

   // Colors
   if (MainLine.Color        == 0xFF000000) MainLine.Color        = CLR_NONE;    // after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF)
   if (Histogram.Color.Upper == 0xFF000000) Histogram.Color.Upper = CLR_NONE;    // into Black (0xFF000000)
   if (Histogram.Color.Lower == 0xFF000000) Histogram.Color.Lower = CLR_NONE;

   // Styles
   if (MainLine.Width < 0)        return(catch("onInit(3)  Invalid input parameter MainLine.Width = "+ MainLine.Width, ERR_INVALID_INPUT_PARAMETER));
   if (MainLine.Width > 5)        return(catch("onInit(4)  Invalid input parameter MainLine.Width = "+ MainLine.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width < 0) return(catch("onInit(5)  Invalid input parameter Histogram.Style.Width = "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width > 5) return(catch("onInit(6)  Invalid input parameter Histogram.Style.Width = "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)           return(catch("onInit(7)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));


   // (2) setup buffer management
   IndicatorBuffers(7);
   SetIndexBuffer(MODE_EMA_1,         firstEma );
   SetIndexBuffer(MODE_EMA_2,         secondEma);
   SetIndexBuffer(MODE_EMA_3,         thirdEma );
   SetIndexBuffer(MODE_MAIN,          trixMain );
   SetIndexBuffer(MODE_UPPER_SECTION, trixUpper);
   SetIndexBuffer(MODE_LOWER_SECTION, trixLower);
   SetIndexBuffer(MODE_TREND,         trixTrend);


   // (3) data display configuration and names
   string sAppliedPrice = "";
      if (ema.appliedPrice != PRICE_CLOSE) sAppliedPrice = ","+ PriceTypeDescription(ema.appliedPrice);
   string name = "TRIX("+ EMA.Periods + sAppliedPrice +")  ";
   IndicatorShortName(name);                                // indicator subwindow and context menus

   name = "TRIX("+ EMA.Periods +")";                        // "Data" window and tooltips
   SetIndexLabel(MODE_EMA_1,         NULL);
   SetIndexLabel(MODE_EMA_2,         NULL);
   SetIndexLabel(MODE_EMA_3,         NULL);
   SetIndexLabel(MODE_MAIN,          name);
   SetIndexLabel(MODE_UPPER_SECTION, NULL);
   SetIndexLabel(MODE_LOWER_SECTION, NULL);
   SetIndexLabel(MODE_TREND,         NULL);
   IndicatorDigits(3);


   // (4) drawing options and styles
   int startDraw = 0;
   if (Max.Values >= 0) startDraw += Bars - Max.Values;
   if (startDraw  <  0) startDraw  = 0;
   SetIndexDrawBegin(MODE_MAIN,          startDraw);
   SetIndexDrawBegin(MODE_UPPER_SECTION, startDraw);
   SetIndexDrawBegin(MODE_LOWER_SECTION, startDraw);
   SetIndicatorStyles();

   return(catch("onInit(8)"));
}


/**
 * Called before recompilation.
 *
 * @return int - error status
 */
int onDeinitRecompile() {
   StoreInputParameters();
   return(last_error);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check for finished buffer initialization
   if (!ArraySize(trixMain))                                         // can happen on terminal start
      return(log("onTick(1)  size(trix) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(firstEma,  EMPTY_VALUE);
      ArrayInitialize(secondEma, EMPTY_VALUE);
      ArrayInitialize(thirdEma,  EMPTY_VALUE);
      ArrayInitialize(trixMain,  EMPTY_VALUE);
      ArrayInitialize(trixUpper, EMPTY_VALUE);
      ArrayInitialize(trixLower, EMPTY_VALUE);
      ArrayInitialize(trixTrend,           0);
      SetIndicatorStyles();
   }

   // synchronize buffers with a shifted offline chart (if applicable)
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(firstEma,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(secondEma, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(thirdEma,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(trixMain,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(trixUpper, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(trixLower, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(trixTrend, Bars, ShiftedBars,           0);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Values >= 0) /*&&*/ if (Max.Values < ChangedBars)         // Because EMA(EMA(EMA)) is used in the calculation, TriEMA needs
      changedBars = Max.Values;                                      // 3*<period>-2 samples to start producing values in contrast to
   int bar, startBar = Min(changedBars-1, Bars - (3*EMA.Periods-2)); // <period> samples needed by a regular EMA.
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));

   double dNull[];


   // (2) recalculate invalid bars
   for (bar=ChangedBars-1; bar >= 0; bar--) firstEma [bar] =        iMA(NULL,      NULL,        EMA.Periods, 0, MODE_EMA, ema.appliedPrice, bar);
   for (bar=ChangedBars-1; bar >= 0; bar--) secondEma[bar] = iMAOnArray(firstEma,  WHOLE_ARRAY, EMA.Periods, 0, MODE_EMA,                   bar);
   for (bar=ChangedBars-1; bar >= 0; bar--) thirdEma [bar] = iMAOnArray(secondEma, WHOLE_ARRAY, EMA.Periods, 0, MODE_EMA,                   bar);

   for (bar=startBar; bar >= 0; bar--) {
      // Trix main value
      trixMain[bar] = (thirdEma[bar] - thirdEma[bar+1]) / thirdEma[bar+1] * 10000;              // convert to bps

      // histogram sections
      if (trixMain[bar] > 0) { trixUpper[bar] = trixMain[bar]; trixLower[bar] = EMPTY_VALUE;   }
      else                   { trixUpper[bar] = EMPTY_VALUE;   trixLower[bar] = trixMain[bar]; }

      // trend direction and length
      @Trend.UpdateDirection(trixMain, bar, trixTrend, dNull, dNull, dNull, DRAW_NONE);
   }
   return(last_error);
}


/**
 * Set indicator styles. Workaround for various terminal bugs when setting styles or levels. Usually styles are applied in
 * init(). However after recompilation styles must be applied in start() to not get ignored.
 */
void SetIndicatorStyles() {
   int mainShape    = ifInt(!MainLine.Width,        DRAW_NONE, DRAW_LINE     );
   int sectionShape = ifInt(!Histogram.Style.Width, DRAW_NONE, DRAW_HISTOGRAM);

   SetIndexStyle(MODE_MAIN,          mainShape,    EMPTY, MainLine.Width,        MainLine.Color       );
   SetIndexStyle(MODE_UPPER_SECTION, sectionShape, EMPTY, Histogram.Style.Width, Histogram.Color.Upper);
   SetIndexStyle(MODE_LOWER_SECTION, sectionShape, EMPTY, Histogram.Style.Width, Histogram.Color.Lower);
   SetIndexStyle(MODE_TREND,         DRAW_NONE,    EMPTY, EMPTY,                 CLR_NONE             );
}


/**
 * Store input parameters in the chart for restauration after recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   Chart.StoreInt   (__NAME__ +".input.EMA.Periods",           EMA.Periods          );
   Chart.StoreString(__NAME__ +".input.EMA.AppliedPrice",      EMA.AppliedPrice     );
   Chart.StoreInt   (__NAME__ +".input.MainLine.Color",        MainLine.Color       );
   Chart.StoreInt   (__NAME__ +".input.MainLine.Width",        MainLine.Width       );
   Chart.StoreInt   (__NAME__ +".input.Histogram.Color.Upper", Histogram.Color.Upper);
   Chart.StoreInt   (__NAME__ +".input.Histogram.Color.Lower", Histogram.Color.Lower);
   Chart.StoreInt   (__NAME__ +".input.Histogram.Style.Width", Histogram.Style.Width);
   Chart.StoreInt   (__NAME__ +".input.Max.Values",            Max.Values           );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string label = __NAME__ +".input.EMA.Periods";
   if (ObjectFind(label) == 0) {
      string sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(1)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      EMA.Periods = StrToInteger(sValue);                         // (int) string
   }

   label = __NAME__ +".input.EMA.AppliedPrice";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      EMA.AppliedPrice = sValue;                                  // string
   }

   label = __NAME__ +".input.MainLine.Color";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(2)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      int iValue = StrToInteger(sValue);
      if (iValue < CLR_NONE || iValue > C'255,255,255')
                                    return(!catch("RestoreInputParameters(3)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)) +" (0x"+ IntToHexStr(iValue) +")", ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      MainLine.Color = iValue;                                    // (color)(int) string
   }

   label = __NAME__ +".input.MainLine.Width";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(4)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      MainLine.Width = StrToInteger(sValue);                      // (int) string
   }

   label = __NAME__ +".input.Histogram.Color.Upper";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(5)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      iValue = StrToInteger(sValue);
      if (iValue < CLR_NONE || iValue > C'255,255,255')
                                    return(!catch("RestoreInputParameters(6)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)) +" (0x"+ IntToHexStr(iValue) +")", ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Histogram.Color.Upper = iValue;                             // (color)(int) string
   }

   label = __NAME__ +".input.Histogram.Color.Lower";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(7)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      iValue = StrToInteger(sValue);
      if (iValue < CLR_NONE || iValue > C'255,255,255')
                                    return(!catch("RestoreInputParameters(8)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)) +" (0x"+ IntToHexStr(iValue) +")", ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Histogram.Color.Lower = iValue;                             // (color)(int) string
   }

   label = __NAME__ +".input.Histogram.Style.Width";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(9)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Histogram.Style.Width = StrToInteger(sValue);               // (int) string
   }

   label = __NAME__ +".input.Max.Values";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(10)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Max.Values = StrToInteger(sValue);                          // (int) string
   }

   return(!catch("RestoreInputParameters(11)"));
}


/**
 * Return a string representation of the input parameters. Used when logging iCustom() calls.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "EMA.Periods=",           EMA.Periods,                       "; ",
                            "EMA.AppliedPrice=",      DoubleQuoteStr(EMA.AppliedPrice),  "; ",

                            "MainLine.Color=",        ColorToStr(MainLine.Color),        "; ",
                            "MainLine.Width=",        MainLine.Width,                    "; ",

                            "Histogram.Color.Upper=", ColorToStr(Histogram.Color.Upper), "; ",
                            "Histogram.Color.Lower=", ColorToStr(Histogram.Color.Lower), "; ",
                            "Histogram.Style.Width=", Histogram.Style.Width,             "; ",

                            "Max.Values=",            Max.Values,                        "; ")
   );
}
