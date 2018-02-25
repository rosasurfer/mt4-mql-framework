/**
 * Triple Moving Average Oscillator (Trix)
 *
 *
 * The Triple Exponential Moving Average Oscillator (the name Trix is from "triple exponential") is a momentum indicator
 * displaying the rate of change (the slope) between two consecutive triple smoothed exponential moving average values.
 * This implementation additionally supports other MA types.
 *
 * @see  https://en.wikipedia.org/wiki/Trix_%28technical_analysis%29
 *
 *
 * TODO: support for other MA types
 * TODO: support for draw types "dot" and "histogram"
 * TODO: SMA signal line
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods      = 38;
extern string MA.Method       = "SMA | LWMA | EMA* | ALMA | DEMA | TEMA";
extern string MA.AppliedPrice = "Open | High | Low | Close* | Median | Typical | Weighted";

extern string Draw.Type       = "Line* | Dot | Histogram";
extern color  MainLine.Color  = Blue;                       // indicator style management in MQL
extern int    MainLine.Width  = 1;

extern int    Max.Values      = 3000;                       // max. number of values to display: -1 = all
extern string Unit            = "Percent* | Permille";      // display unit

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>

#define MODE_MAIN             Trix.MODE_MAIN       // indicator buffer ids
#define MODE_MA_1             1
#define MODE_MA_2             2
#define MODE_MA_3             3

#property indicator_separate_window

#property indicator_buffers   1
#property indicator_level1    0

double trix    [];                                 // Trix main value:               visible, "Data" window
double firstMa [];                                 // first intermediate MA buffer:  invisible
double secondMa[];                                 // second intermediate MA buffer: invisible
double thirdMa [];                                 // third intermediate MA buffer:  invisible

int    ma.appliedPrice;
int    draw.type     = DRAW_LINE;                  // DRAW_LINE | DRAW_ARROW
int    draw.dot.size = 1;                          // default symbol size for Draw.Type = "Dot"


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
   // MA.Periods
   if (MA.Periods < 1)     return(catch("onInit(1)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));

   // MA.AppliedPrice
   string elems[], sValue = MA.AppliedPrice;
   if (Explode(MA.AppliedPrice, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      sValue = elems[size-1];
   }
   sValue = StringTrim(sValue);
   if (sValue == "") sValue = "Close";                      // default
   ma.appliedPrice = StrToPriceType(sValue, F_ERR_INVALID_PARAMETER);
   if (ma.appliedPrice==-1 || ma.appliedPrice > PRICE_WEIGHTED)
                           return(catch("onInit(2)  Invalid input parameter MA.AppliedPrice = "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // Draw.Type
   sValue = StringToLower(Draw.Type);
   if (Explode(sValue, "*", elems, 2) > 1) {
      size = Explode(elems[0], "|", elems, NULL);
      sValue = elems[size-1];
   }
   sValue = StringTrim(sValue);
   if      (StringStartsWith("line", sValue)) { draw.type = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StringStartsWith("dot",  sValue)) { draw.type = DRAW_ARROW; Draw.Type = "Dot";  }
   else                    return(catch("onInit(3)  Invalid input parameter Draw.Type = "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // MainLine.Color
   if (MainLine.Color == 0xFF000000) MainLine.Color = CLR_NONE;   // after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)

   // MainLine.Width
   if (MainLine.Width < 1) return(catch("onInit(4)  Invalid input parameter MainLine.Width = "+ MainLine.Width, ERR_INVALID_INPUT_PARAMETER));
   if (MainLine.Width > 5) return(catch("onInit(5)  Invalid input parameter MainLine.Width = "+ MainLine.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)    return(catch("onInit(6)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));


   // (2) setup buffer management
   IndicatorBuffers(4);
   SetIndexBuffer(MODE_MAIN, trix    );
   SetIndexBuffer(MODE_MA_1, firstMa );
   SetIndexBuffer(MODE_MA_2, secondMa);
   SetIndexBuffer(MODE_MA_3, thirdMa );


   // (3) data display configuration, names and labels
   string name = "TRIX("+ MA.Periods +")";
   IndicatorShortName(name +"  ");                          // indicator subwindow and context menu
   SetIndexLabel(MODE_MAIN, name);                          // "Data" window and tooltips
   SetIndexLabel(MODE_MA_1, NULL);
   SetIndexLabel(MODE_MA_2, NULL);
   SetIndexLabel(MODE_MA_3, NULL);
   IndicatorDigits(3);


   // (4) drawing options and styles
   int startDraw = 0;
   if (Max.Values >= 0) startDraw += Bars - Max.Values;
   if (startDraw  <  0) startDraw  = 0;
   SetIndexDrawBegin(MODE_MAIN, startDraw);
   SetIndicatorStyles();

   return(catch("onInit(7)"));
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
   if (ArraySize(trix) == 0)                                   // can happen on terminal start
      return(debug("onTick(1)  size(trix) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(trix,     EMPTY_VALUE);
      ArrayInitialize(firstMa,  EMPTY_VALUE);
      ArrayInitialize(secondMa, EMPTY_VALUE);
      ArrayInitialize(thirdMa,  EMPTY_VALUE);
      SetIndicatorStyles();
   }

   // synchronize buffers with a shifted offline chart (if applicable)
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(trix,     Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(firstMa,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(secondMa, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(thirdMa,  Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Values >= 0) /*&&*/ if (Max.Values < ChangedBars)
      changedBars = Max.Values;                                      // Because EMA(EMA(EMA)) is used in the calculation, Trix needs 3*<period>-2 samples
   int bar, startBar = Min(changedBars-1, Bars - (3*MA.Periods-2));  // to start producing values in contrast to <period> samples needed by a regular EMA.
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid bars
   for (bar=ChangedBars-1; bar >= 0; bar--) firstMa [bar] =        iMA(NULL,     NULL,        MA.Periods, 0, MODE_EMA, ma.appliedPrice, bar);
   for (bar=ChangedBars-1; bar >= 0; bar--) secondMa[bar] = iMAOnArray(firstMa,  WHOLE_ARRAY, MA.Periods, 0, MODE_EMA,                  bar);
   for (bar=ChangedBars-1; bar >= 0; bar--) thirdMa [bar] = iMAOnArray(secondMa, WHOLE_ARRAY, MA.Periods, 0, MODE_EMA,                  bar);

   // Trix
   for (bar=startBar; bar >= 0; bar--) {
      trix[bar] = (thirdMa[bar]-thirdMa[bar+1]) / thirdMa[bar+1] * 1000;   // convert to permille
   }
   return(last_error);
}


/**
 * Set indicator styles. Workaround for various terminal bugs when setting styles. Usually styles are applied in init().
 * However after recompilation styles must be applied in start() to not get lost.
 */
void SetIndicatorStyles() {
   SetIndexStyle(MODE_MAIN, DRAW_LINE, EMPTY, MainLine.Width, MainLine.Color);
}


/**
 * Store input parameters in the chart for restauration after recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   Chart.StoreInt   (__NAME__ +".input.MA.Periods",      MA.Periods     );
   Chart.StoreString(__NAME__ +".input.MA.Method",       MA.Method      );
   Chart.StoreString(__NAME__ +".input.MA.AppliedPrice", MA.AppliedPrice);
   Chart.StoreString(__NAME__ +".input.Draw.Type",       Draw.Type      );
   Chart.StoreInt   (__NAME__ +".input.MainLine.Color",  MainLine.Color );
   Chart.StoreInt   (__NAME__ +".input.MainLine.Width",  MainLine.Width );
   Chart.StoreInt   (__NAME__ +".input.Max.Values",      Max.Values     );
   Chart.StoreString(__NAME__ +".input.Unit",            Unit           );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string label = __NAME__ +".input.MA.Periods";
   if (ObjectFind(label) == 0) {
      string sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(1)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      MA.Periods = StrToInteger(sValue);                          // (int) string
   }

   label = __NAME__ +".input.MA.Method";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      MA.Method = sValue;                                         // string
   }

   label = __NAME__ +".input.MA.AppliedPrice";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      MA.AppliedPrice = sValue;                                   // string
   }

   label = __NAME__ +".input.Draw.Type";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Draw.Type = sValue;                                         // string
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

   label = __NAME__ +".input.Max.Values";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(5)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Max.Values = StrToInteger(sValue);                          // (int) string
   }

   label = __NAME__ +".input.Unit";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Unit = sValue;                                              // string
   }

   return(!catch("RestoreInputParameters(6)"));
}
