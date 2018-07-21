/**
 * Bollinger Bands
 *
 *
 * Indicator buffers to use with iCustom():
 *  • Bands.MODE_MA:    MA values
 *  • Bands.MODE_UPPER: upper band values
 *  • Bands.MODE_LOWER: lower band value
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods        = 200;
extern string MA.Method         = "SMA* | LWMA | EMA | ALMA";
extern string MA.AppliedPrice   = "Open | High | Low | Close* | Median | Typical | Weighted";
extern color  MA.Color          = Green;              // indicator style management in MQL
extern int    MA.LineWidth      = 0;

extern double StdDev.Multiplier = 2;

extern color  Bands.Color       = RoyalBlue;
extern int    Bands.LineWidth   = 2;

extern int    Max.Values        = 5000;               // max. number of values to display: -1 = all

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/@ALMA.mqh>

#define MODE_MA         Bands.MODE_MA                 // indicator buffer ids
#define MODE_UPPER      Bands.MODE_UPPER
#define MODE_LOWER      Bands.MODE_LOWER

#property indicator_chart_window
#property indicator_buffers 3

double bufferMa   [];                                 // MA values:         visible if configured
double bufferUpper[];                                 // upper band values: visible, displayed in "Data" window
double bufferLower[];                                 // lower band values: visible, displayed in "Data" window

int    ma.method;
int    ma.appliedPrice;
double alma.weights[];

string ind.longName;                                  // name for chart legend
string ind.shortName;                                 // name for "Data" window and context menues
string ind.legendLabel;


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
   if (MA.Periods < 1)        return(catch("onInit(1)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));

   // MA.Method
   string values[], sValue = MA.Method;
   if (Explode(MA.Method, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StringTrim(sValue);
   ma.method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (ma.method == -1)       return(catch("onInit(2)  Invalid input parameter MA.Method = "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(ma.method);

   // MA.AppliedPrice
   sValue = MA.AppliedPrice;
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StringToLower(StringTrim(sValue));
   if (sValue == "") sValue = "close";                                  // default price type
   if      (StringStartsWith("open",     sValue)) ma.appliedPrice = PRICE_OPEN;
   else if (StringStartsWith("high",     sValue)) ma.appliedPrice = PRICE_HIGH;
   else if (StringStartsWith("low",      sValue)) ma.appliedPrice = PRICE_LOW;
   else if (StringStartsWith("close",    sValue)) ma.appliedPrice = PRICE_CLOSE;
   else if (StringStartsWith("median",   sValue)) ma.appliedPrice = PRICE_MEDIAN;
   else if (StringStartsWith("typical",  sValue)) ma.appliedPrice = PRICE_TYPICAL;
   else if (StringStartsWith("weighted", sValue)) ma.appliedPrice = PRICE_WEIGHTED;
   else                       return(catch("onInit(3)  Invalid input parameter MA.AppliedPrice = "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // MA.Color: after unserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (MA.Color == 0xFF000000) MA.Color = CLR_NONE;

   // MA.LineWidth
   if (MA.LineWidth < 0)      return(catch("onInit(4)  Invalid input parameter MA.LineWidth = "+ MA.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (MA.LineWidth > 5)      return(catch("onInit(5)  Invalid input parameter MA.LineWidth = "+ MA.LineWidth, ERR_INVALID_INPUT_PARAMETER));

   // StdDev.Multiplier
   if (StdDev.Multiplier < 0) return(catch("onInit(6)  Invalid input parameter StdDev.Multiplier = "+ NumberToStr(StdDev.Multiplier, ".1+"), ERR_INVALID_INPUT_PARAMETER));

   // Bands.Color: after unserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Bands.Color == 0xFF000000) Bands.Color = CLR_NONE;

   // Bands.LineWidth
   if (Bands.LineWidth < 0)   return(catch("onInit(7)  Invalid input parameter Bands.LineWidth = "+ Bands.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Bands.LineWidth > 5)   return(catch("onInit(8)  Invalid input parameter Bands.LineWidth = "+ Bands.LineWidth, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)       return(catch("onInit(9)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));


   // (2) setup buffer management
   IndicatorBuffers(3);
   SetIndexBuffer(MODE_MA,    bufferMa   );                    // MA values:         visible if configured
   SetIndexBuffer(MODE_UPPER, bufferUpper);                    // upper band values: visible, displayed in "Data" window
   SetIndexBuffer(MODE_LOWER, bufferLower);                    // lower band values: visible, displayed in "Data" window


   // (3) data display configuration, names and labels
   string sMaAppliedPrice   = ifString(ma.appliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(ma.appliedPrice));
   string sStdDevMultiplier = ifString(EQ(StdDev.Multiplier, 2), "", ", "+ NumberToStr(StdDev.Multiplier, ".1+"));
   ind.shortName = __NAME__ +"("+ MA.Periods +")";
   ind.longName  = __NAME__ +"("+ MA.Periods +", "+ MA.Method + sMaAppliedPrice + sStdDevMultiplier +")";
   if (!IsSuperContext()) {
       ind.legendLabel = CreateLegendLabel(ind.longName);      // no chart legend if called by iCustom()
       ObjectRegister(ind.legendLabel);
   }
   IndicatorShortName(ind.shortName);                          // context menu
   SetIndexLabel(MODE_MA,    NULL);                            // "Data" window and tooltips
   SetIndexLabel(MODE_UPPER, "UpperBand("+ MA.Periods +")");
   SetIndexLabel(MODE_LOWER, "LowerBand("+ MA.Periods +")");
   IndicatorDigits(SubPipDigits);


   // (4) drawing options and styles
   int startDraw = MA.Periods;
   if (Max.Values >= 0)
      startDraw = Max(startDraw, Bars-Max.Values);
   SetIndexDrawBegin(MODE_MA,    startDraw);
   SetIndexDrawBegin(MODE_UPPER, startDraw);
   SetIndexDrawBegin(MODE_LOWER, startDraw);
   SetIndicatorStyles();


   // (5) init indicator calculation
   if (ma.method==MODE_ALMA && MA.Periods > 1) {
      @ALMA.CalculateWeights(alma.weights, MA.Periods);
   }

   return(catch("onInit(10)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);                              // TODO: on UR_PARAMETERS the legend must be kept
   RepositionLegend();
   return(last_error);
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
   if (!ArraySize(bufferMa))                                            // can happen on terminal start
      return(log("onTick(1)  size(buffeMa) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferMa,    EMPTY_VALUE);
      ArrayInitialize(bufferUpper, EMPTY_VALUE);
      ArrayInitialize(bufferLower, EMPTY_VALUE);
      SetIndicatorStyles();                                             // fix for various terminal bugs
   }

   // synchronize buffers with a shifted offline chart (if applicable)
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMa,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferUpper, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferLower, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (changedBars > Max.Values) /*&&*/ if (Max.Values >= 0)
      changedBars = Max.Values;
   int startBar = Min(changedBars-1, Bars-MA.Periods);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));

   double dev;


   // (2) recalculate invalid bars
   for (int bar=startBar; bar >= 0; bar--) {
      if (ma.method == MODE_ALMA) {
         bufferMa[bar] = 0;
         for (int i=0; i < MA.Periods; i++) {
            bufferMa[bar] += alma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, ma.appliedPrice, bar+i);
         }
         dev = iStdDevOnArray(bufferMa, WHOLE_ARRAY, MA.Periods, 0, MODE_SMA, bar) * StdDev.Multiplier;
      }
      else {
         bufferMa[bar] = iMA    (NULL, NULL, MA.Periods, 0, ma.method, ma.appliedPrice, bar);
         dev           = iStdDev(NULL, NULL, MA.Periods, 0, ma.method, ma.appliedPrice, bar) * StdDev.Multiplier;
      }
      bufferUpper[bar] = bufferMa[bar] + dev;
      bufferLower[bar] = bufferMa[bar] - dev;
   }
   return(last_error);
}


/**
 * Set indicator styles. Workaround for various terminal bugs when setting indicator styles and levels. Usually styles are
 * applied in init(). However after recompilation styles must be applied in start() to not get ignored.
 */
void SetIndicatorStyles() {
   if (!MA.LineWidth)    { int ma.drawType    = DRAW_NONE, ma.width    = EMPTY;           }
   else                  {     ma.drawType    = DRAW_LINE; ma.width    = MA.LineWidth;    }

   if (!Bands.LineWidth) { int bands.drawType = DRAW_NONE, bands.width = EMPTY;           }
   else                  {     bands.drawType = DRAW_LINE; bands.width = Bands.LineWidth; }

   SetIndexStyle(MODE_MA,    ma.drawType,    EMPTY, ma.width,    MA.Color   );
   SetIndexStyle(MODE_UPPER, bands.drawType, EMPTY, bands.width, Bands.Color);
   SetIndexStyle(MODE_LOWER, bands.drawType, EMPTY, bands.width, Bands.Color);
}


/**
 * Store input parameters in the chart for restauration after recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   Chart.StoreInt   (__NAME__ +".input.MA.Periods",        MA.Periods       );
   Chart.StoreString(__NAME__ +".input.MA.Method",         MA.Method        );
   Chart.StoreString(__NAME__ +".input.MA.AppliedPrice",   MA.AppliedPrice  );
   Chart.StoreInt   (__NAME__ +".input.MA.Color",          MA.Color         );
   Chart.StoreInt   (__NAME__ +".input.MA.LineWidth",      MA.LineWidth     );
   Chart.StoreDouble(__NAME__ +".input.StdDev.Multiplier", StdDev.Multiplier);
   Chart.StoreInt   (__NAME__ +".input.Bands.Color",       Bands.Color      );
   Chart.StoreInt   (__NAME__ +".input.Bands.LineWidth",   Bands.LineWidth  );
   Chart.StoreInt   (__NAME__ +".input.Max.Values",        Max.Values       );
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

   label = __NAME__ +".input.MA.Color";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(2)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      int iValue = StrToInteger(sValue);
      if (iValue < CLR_NONE || iValue > C'255,255,255')
                                    return(!catch("RestoreInputParameters(3)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)) +" (0x"+ IntToHexStr(iValue) +")", ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      MA.Color = iValue;                                          // (color)(int) string
   }

   label = __NAME__ +".input.MA.LineWidth";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(4)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      MA.LineWidth = StrToInteger(sValue);                        // (int) string
   }

   label = __NAME__ +".input.StdDev.Multiplier";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreInputParameters(5)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      StdDev.Multiplier = StrToDouble(sValue);                    // (double) string
   }

   label = __NAME__ +".input.Bands.Color";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(6)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      iValue = StrToInteger(sValue);
      if (iValue < CLR_NONE || iValue > C'255,255,255')
                                    return(!catch("RestoreInputParameters(7)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)) +" (0x"+ IntToHexStr(iValue) +")", ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Bands.Color = iValue;                                       // (color)(int) string
   }

   label = __NAME__ +".input.Bands.LineWidth";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(8)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Bands.LineWidth = StrToInteger(sValue);                     // (int) string
   }

   label = __NAME__ +".input.Max.Values";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(9)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Max.Values = StrToInteger(sValue);                          // (int) string
   }

   return(!catch("RestoreInputParameters(10)"));
}


/**
 * Return a string representation of the input parameters. Used to log iCustom() calls.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "MA.Periods=",        MA.Periods,                            "; ",
                            "MA.Method=",         DoubleQuoteStr(MA.Method),             "; ",
                            "MA.AppliedPrice=",   DoubleQuoteStr(MA.AppliedPrice),       "; ",
                            "MA.Color=",          ColorToStr(MA.Color),                  "; ",
                            "MA.LineWidth=",      MA.LineWidth,                          "; ",

                            "StdDev.Multiplier=", NumberToStr(StdDev.Multiplier, ".1+"), "; ",

                            "Bands.Color=",       ColorToStr(Bands.Color),               "; ",
                            "Bands.LineWidth=",   Bands.LineWidth,                       "; ",

                            "Max.Values=",        Max.Values,                            "; ")
   );
}
