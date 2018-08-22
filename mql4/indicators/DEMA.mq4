/**
 * Derived Double Exponential Moving Average (DEMA) by Patrick G. Mulloy
 *
 *
 * The name suggests the DEMA is calculated by simply applying exponential smoothing twice which is not the case. Instead
 * the name "double" comes from the fact that for the calculation a double-smoothed EMA is subtracted from a previously
 * doubled regular EMA:
 *
 *   DEMA(n) = 2*EMA(n) - EMA(EMA(n))
 *
 * Indicator buffers to use with iCustom():
 *  • MovingAverage.MODE_MA: MA values
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods      = 38;
extern string MA.AppliedPrice = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  MA.Color        = DodgerBlue;              // indicator style management in MQL
extern string Draw.Type       = "Line* | Dot";
extern int    Draw.LineWidth  = 2;

extern int    Max.Values      = 5000;                    // max. number of values to display: -1 = all

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/@Trend.mqh>

#define MODE_DEMA             MovingAverage.MODE_MA
#define MODE_EMA_1            1

#property indicator_chart_window
#property indicator_buffers   1                          // configurable buffers (input dialog)
int       allocated_buffers = 2;                         // used buffers
#property indicator_width1    2

double dema    [];                                       // MA values: visible, displayed in "Data" window
double firstEma[];                                       // first EMA: invisible

int    ma.appliedPrice;
string ma.name;                                          // name for chart legend, "Data" window and context menues

int    draw.type      = DRAW_LINE;                       // DRAW_LINE | DRAW_ARROW
int    draw.arrowSize = 1;                               // default symbol size for Draw.Type="dot"
string legendLabel;


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
   string values[], sValue = StringToLower(MA.AppliedPrice);
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StringTrim(sValue);
   if (sValue == "") sValue = "close";                      // default price type
   if      (StringStartsWith("open",     sValue)) ma.appliedPrice = PRICE_OPEN;
   else if (StringStartsWith("high",     sValue)) ma.appliedPrice = PRICE_HIGH;
   else if (StringStartsWith("low",      sValue)) ma.appliedPrice = PRICE_LOW;
   else if (StringStartsWith("close",    sValue)) ma.appliedPrice = PRICE_CLOSE;
   else if (StringStartsWith("median",   sValue)) ma.appliedPrice = PRICE_MEDIAN;
   else if (StringStartsWith("typical",  sValue)) ma.appliedPrice = PRICE_TYPICAL;
   else if (StringStartsWith("weighted", sValue)) ma.appliedPrice = PRICE_WEIGHTED;
   else                    return(catch("onInit(2)  Invalid input parameter MA.AppliedPrice = "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // MA.Color
   if (MA.Color == 0xFF000000) MA.Color = CLR_NONE;         // after unserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)

   // Draw.Type
   sValue = StringToLower(Draw.Type);
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StringTrim(sValue);
   if      (StringStartsWith("line", sValue)) { draw.type = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StringStartsWith("dot",  sValue)) { draw.type = DRAW_ARROW; Draw.Type = "Dot";  }
   else                    return(catch("onInit(3)  Invalid input parameter Draw.Type = "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // Draw.LineWidth
   if (Draw.LineWidth < 0) return(catch("onInit(4)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Draw.LineWidth > 5) return(catch("onInit(5)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)    return(catch("onInit(6)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));


   // (2) setup buffer management
   SetIndexBuffer(MODE_DEMA,  dema    );
   SetIndexBuffer(MODE_EMA_1, firstEma);


   // (3) data display configuration, names and labels
   string shortName="DEMA("+ MA.Periods +")", strAppliedPrice="";
   if (ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ", "+ PriceTypeDescription(ma.appliedPrice);
   ma.name = "DEMA("+ MA.Periods + strAppliedPrice +")";
   if (!IsSuperContext()) {                                    // no chart legend if called by iCustom()
       legendLabel = CreateLegendLabel(ma.name);
       ObjectRegister(legendLabel);
   }
   IndicatorShortName(shortName);                              // context menu
   SetIndexLabel(MODE_DEMA,  shortName);                       // "Data" window and tooltips
   SetIndexLabel(MODE_EMA_1, NULL);
   IndicatorDigits(SubPipDigits);


   // (4) drawing options and styles
   int startDraw = 0;
   if (Max.Values >= 0) startDraw = Bars - Max.Values;
   if (startDraw  <  0) startDraw = 0;
   SetIndexDrawBegin(MODE_DEMA, startDraw);
   SetIndicatorOptions();

   return(catch("onInit(7)"));
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
   // check for finished buffer initialization (needed on terminal start)
   if (!ArraySize(dema))
      return(log("onTick(1)  size(dema) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(dema,     EMPTY_VALUE);
      ArrayInitialize(firstEma, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(dema,     Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(firstEma, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Values >= 0) /*&&*/ if (Max.Values < ChangedBars)
      changedBars = Max.Values;                                      // Because EMA(EMA) is used in the calculation, DEMA needs 2*<period>-1 samples
   int bar, startBar = Min(changedBars-1, Bars - (2*MA.Periods-1));  // to start producing values in contrast to <period> samples needed by a regular EMA.
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid bars
   double secondEma;
   for (bar=ChangedBars-1; bar >= 0; bar--)   firstEma[bar] =    iMA(NULL,     NULL,        MA.Periods, 0, MODE_EMA, ma.appliedPrice, bar);
   for (bar=startBar;      bar >= 0; bar--) { secondEma = iMAOnArray(firstEma, WHOLE_ARRAY, MA.Periods, 0, MODE_EMA,                  bar);
      dema[bar] = 2 * firstEma[bar] - secondEma;
   }


   // (3) update chart legend
   if (!IsSuperContext()) {
       @Trend.UpdateLegend(legendLabel, ma.name, "", MA.Color, MA.Color, dema[0], NULL, Time[0]);
   }
   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(allocated_buffers);

   int drawType  = ifInt(draw.type==DRAW_ARROW, DRAW_ARROW, ifInt(Draw.LineWidth, DRAW_LINE, DRAW_NONE));
   int drawWidth = ifInt(draw.type==DRAW_ARROW, draw.arrowSize, Draw.LineWidth);

   SetIndexStyle(MODE_DEMA, drawType, EMPTY, drawWidth, MA.Color); SetIndexArrow(MODE_DEMA, 159);
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   Chart.StoreInt   (__NAME__ +".input.MA.Periods",      MA.Periods     );
   Chart.StoreString(__NAME__ +".input.MA.AppliedPrice", MA.AppliedPrice);
   Chart.StoreColor (__NAME__ +".input.MA.Color",        MA.Color       );
   Chart.StoreString(__NAME__ +".input.Draw.Type",       Draw.Type      );
   Chart.StoreInt   (__NAME__ +".input.Draw.LineWidth",  Draw.LineWidth );
   Chart.StoreInt   (__NAME__ +".input.Max.Values",      Max.Values     );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   Chart.RestoreInt   ("MA.Periods",      MA.Periods     );
   Chart.RestoreString("MA.AppliedPrice", MA.AppliedPrice);
   Chart.RestoreColor ("MA.Color",        MA.Color       );
   Chart.RestoreString("Draw.Type",       Draw.Type      );
   Chart.RestoreInt   ("Draw.LineWidth",  Draw.LineWidth );
   Chart.RestoreInt   ("Max.Values",      Max.Values     );
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters. Used to log iCustom() calls.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "MA.Periods=",      MA.Periods,                      "; ",
                            "MA.AppliedPrice=", DoubleQuoteStr(MA.AppliedPrice), "; ",
                            "MA.Color=",        ColorToStr(MA.Color),            "; ",

                            "Draw.Type=",       DoubleQuoteStr(Draw.Type),       "; ",
                            "Draw.LineWidth=",  Draw.LineWidth,                  "; ",

                            "Max.Values=",      Max.Values,                      "; ")
   );
}
