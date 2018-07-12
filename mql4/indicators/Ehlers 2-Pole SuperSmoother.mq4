/**
 * Ehler's Two-Pole Super Smoother Filter
 *
 *
 * As described in his book "Cybernetics Analysis for Stocks and Futures".
 * Very similar to the ALMA. The SuperSmoother is a bit more smooth but has a bit more lag.
 *
 * Indicator buffers to use with iCustom():
 *  • MovingAverage.MODE_MA: MA values
 *
 *
 * TODO:
 *    - not an average but a filter => rename vars
 *    - CutoffPeriod => Filter.Periods
 *    - rename to "Ehlers 2-Pole-SuperSmoother"
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    CutoffPeriod    = 15;

extern color  Color.UpTrend   = Blue;                       // indicator style management in MQL
extern color  Color.DownTrend = Red;
extern string Draw.Type       = "Line* | Dot";
extern int    Draw.LineWidth  = 2;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/@Trend.mqh>

#define MODE_MA             MovingAverage.MODE_MA     // indicator buffer ids
#define MODE_TREND          MovingAverage.MODE_TREND  //
#define MODE_UPTREND        2                         // Draw.Type=Line: If a downtrend is interrupted by a one-bar uptrend this
#define MODE_DOWNTREND      3                         // uptrend is covered by the continuing downtrend. To make single-bar uptrends
#define MODE_UPTREND1       MODE_UPTREND              // visible they are copied to buffer MODE_UPTREND2 which overlays MODE_DOWNTREND.
#define MODE_UPTREND2       4                         //

#property indicator_chart_window

#property indicator_buffers 5

#property indicator_width1  0
#property indicator_width2  0
#property indicator_width3  2
#property indicator_width4  2
#property indicator_width5  2

double bufferMA       [];                             // all MA values:       invisible, displayed in "Data" window
double bufferTrend    [];                             // trend direction:     invisible
double bufferUpTrend1 [];                             // uptrend values:      visible
double bufferDownTrend[];                             // downtrend values:    visible, overlays uptrend values
double bufferUpTrend2 [];                             // single-bar uptrends: visible, overlays downtrend values

int    ma.periods;
string ma.legendLabel;
string ma.longName;                                   // name for chart legend
string ma.shortName;                                  // name "Data" window and context menues

int    draw.type     = DRAW_LINE;                     // DRAW_LINE | DRAW_ARROW
int    draw.dot.size = 1;                             // default symbol size for Draw.Type="Dot"


double coef1, coef2, coef3;


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
   // CutoffPeriod
   if (CutoffPeriod < 1)   return(catch("onInit(1)  Invalid input parameter CutoffPeriod = "+ CutoffPeriod, ERR_INVALID_INPUT_PARAMETER));

   // Colors: after unserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;

   // Draw.Type
   string values[], sValue = StringToLower(Draw.Type);
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StringTrim(sValue);
   if      (StringStartsWith("line", sValue)) { draw.type = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StringStartsWith("dot",  sValue)) { draw.type = DRAW_ARROW; Draw.Type = "Dot";  }
   else                    return(catch("onInit(2)  Invalid input parameter Draw.Type = "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // Draw.LineWidth
   if (Draw.LineWidth < 1) return(catch("onInit(3)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Draw.LineWidth > 5) return(catch("onInit(4)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));


   // (2) setup buffer management
   IndicatorBuffers(5);
   SetIndexBuffer(MODE_MA,        bufferMA       );            // all MA values:       invisible, displayed in "Data" window
   SetIndexBuffer(MODE_TREND,     bufferTrend    );            // trend direction:     invisible
   SetIndexBuffer(MODE_UPTREND1,  bufferUpTrend1 );            // uptrend values:      visible
   SetIndexBuffer(MODE_DOWNTREND, bufferDownTrend);            // downtrend values:    visible, overlays uptrend values
   SetIndexBuffer(MODE_UPTREND2,  bufferUpTrend2 );            // single-bar uptrends: visible, overlays downtrend values


   // (3) data display configuration, names and labels
   ma.shortName = "2P-SuperSmoother("+ CutoffPeriod +")";
   ma.longName  = "2-Pole-SuperSmoother("+ CutoffPeriod +")";
   if (!IsSuperContext()) {                                    // no chart legend if called by iCustom()
       ma.legendLabel = CreateLegendLabel(ma.longName);
       ObjectRegister(ma.legendLabel);
   }
   IndicatorShortName(ma.shortName);                           // context menu
   SetIndexLabel(MODE_MA,        ma.shortName);                // "Data" window and tooltips
   SetIndexLabel(MODE_TREND,     NULL);
   SetIndexLabel(MODE_UPTREND1,  NULL);
   SetIndexLabel(MODE_UPTREND2,  NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   IndicatorDigits(SubPipDigits);


   // (4) drawing options and styles
   int startDraw = 4;                                          // calculation of the the first bars is not exact
   SetIndexDrawBegin(MODE_UPTREND1,  startDraw);
   SetIndexDrawBegin(MODE_UPTREND2,  startDraw);
   SetIndexDrawBegin(MODE_DOWNTREND, startDraw);
   SetIndicatorStyles();


   // (5) init calculation coefficients
   double rad2Deg = 45.0 / MathArctan(1);
   double deg2Rad =  1.0 / rad2Deg;

   double a1 = MathExp(-MathSqrt(2.0) * Math.PI / CutoffPeriod);
   double b1 = 2 * a1 * MathCos(deg2Rad * MathSqrt(2.0) * 180.0 / CutoffPeriod);

   coef2 = b1;
   coef3 = -a1 * a1;
   coef1 = 1 - coef2 - coef3;

   return(catch("onInit(5)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   RepositionLegend();
   return(catch("onDeinit(1)"));
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
   if (!ArraySize(bufferMA))                                            // can happen on terminal start
      return(log("onTick(1)  size(bufferMA) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(bufferMA,        EMPTY_VALUE);
      ArrayInitialize(bufferTrend,               0);
      ArrayInitialize(bufferUpTrend1,  EMPTY_VALUE);
      ArrayInitialize(bufferUpTrend2,  EMPTY_VALUE);
      ArrayInitialize(bufferDownTrend, EMPTY_VALUE);
      SetIndicatorStyles();                                             // fix for various terminal bugs
   }

   // synchronize buffers with a shifted offline chart (if applicable)
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMA,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferTrend,     Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(bufferUpTrend1,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferUpTrend2,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferDownTrend, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) recalculate invalid bars
   for (int bar=ChangedBars-1; bar >= 0; bar--) {
      if (bar > Bars-3) bufferMA[bar] = Price(bar);                     // prevent index out of range errors
      else              bufferMA[bar] = coef1*Price(bar) + coef2*bufferMA[bar+1] + coef3*bufferMA[bar+2];

      // calculate trend direction and length
      @Trend.UpdateDirection(bufferMA, bar, bufferTrend, bufferUpTrend1, bufferDownTrend, bufferUpTrend2, draw.type, true, true, SubPipDigits);
   }


   // (2) update chart legend
   if (!IsSuperContext()) {
       @Trend.UpdateLegend(ma.legendLabel, ma.longName, "", Color.UpTrend, Color.DownTrend, bufferMA[0], bufferTrend[0], Time[0]);
   }
   return(last_error);
}


/**
 *
 */
double Price(int bar) {
   return((High[bar] + Low[bar]) / 2);
}


/**
 * Set indicator styles. Workaround for various terminal bugs when setting styles or levels. Usually styles are applied in
 * init(). However after recompilation styles must be applied in start() to not get ignored.
 */
void SetIndicatorStyles() {
   int width = ifInt(draw.type==DRAW_ARROW, draw.dot.size, Draw.LineWidth);

   SetIndexStyle(MODE_MA,        DRAW_NONE, EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY, CLR_NONE       );
   SetIndexStyle(MODE_UPTREND1,  draw.type, EMPTY, width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND1,  159);
   SetIndexStyle(MODE_DOWNTREND, draw.type, EMPTY, width, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 159);
   SetIndexStyle(MODE_UPTREND2,  draw.type, EMPTY, width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  159);
}


/**
 * Store input parameters in the chart for restauration after recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   Chart.StoreInt   (__NAME__ +".input.CutoffPeriod",    CutoffPeriod    );
   Chart.StoreInt   (__NAME__ +".input.Color.UpTrend",   Color.UpTrend  );
   Chart.StoreInt   (__NAME__ +".input.Color.DownTrend", Color.DownTrend);
   Chart.StoreString(__NAME__ +".input.Draw.Type",       Draw.Type      );
   Chart.StoreInt   (__NAME__ +".input.Draw.LineWidth",  Draw.LineWidth );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string label = __NAME__ +".input.CutoffPeriod";
   if (ObjectFind(label) == 0) {
      string sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(1)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      CutoffPeriod = StrToInteger(sValue);                        // (int) string
   }

   label = __NAME__ +".input.Color.UpTrend";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(2)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      int iValue = StrToInteger(sValue);
      if (iValue < CLR_NONE || iValue > C'255,255,255')
                                    return(!catch("RestoreInputParameters(3)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)) +" (0x"+ IntToHexStr(iValue) +")", ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Color.UpTrend = iValue;                                     // (color)(int) string
   }

   label = __NAME__ +".input.Color.DownTrend";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(4)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      iValue = StrToInteger(sValue);
      if (iValue < CLR_NONE || iValue > C'255,255,255')
                                    return(!catch("RestoreInputParameters(5)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)) +" (0x"+ IntToHexStr(iValue) +")", ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Color.DownTrend = iValue;                                   // (color)(int) string
   }

   label = __NAME__ +".input.Draw.Type";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Draw.Type = sValue;                                         // string
   }

   label = __NAME__ +".input.Draw.LineWidth";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(6)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Draw.LineWidth = StrToInteger(sValue);                      // (int) string
   }

   return(!catch("RestoreInputParameters(7)"));
}


/**
 * Return a string representation of the input parameters. Used when logging iCustom() calls.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "CutoffPeriod=",    CutoffPeriod,               "; ",

                            "Color.UpTrend=",   ColorToStr(Color.UpTrend),  "; ",
                            "Color.DownTrend=", ColorToStr(Color.DownTrend),"; ",
                            "Draw.Type=",       DoubleQuoteStr(Draw.Type),  "; ",
                            "Draw.LineWidth=",  Draw.LineWidth,             "; ")
   );
}
