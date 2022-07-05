/**
 * Double Exponential Moving Average (DEMA) by Patrick G. Mulloy
 *
 * Opposite to what its name suggests the DEMA is not an EMA applied twice. Instead for calculation a double-smoothed EMA is
 * subtracted from a previously doubled regular EMA:
 *
 *   DEMA(n) = 2*EMA(n) - EMA(EMA(n))
 *
 *
 * Indicator buffers for iCustom():
 *  • MovingAverage.MODE_MA: MA values
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods      = 38;
extern string MA.AppliedPrice = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  MA.Color        = DodgerBlue;
extern string Draw.Type       = "Line* | Dot";
extern int    Draw.Width      = 2;

extern int    Max.Bars        = 10000;                   // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/Trend.mqh>

#define MODE_DEMA             MovingAverage.MODE_MA
#define MODE_EMA_1            1

#property indicator_chart_window
#property indicator_buffers   1                          // buffers visible to the user
int       terminal_buffers  = 2;                         // buffers managed by the terminal
#property indicator_width1    2

double dema    [];                                       // MA values: visible, displayed in "Data" window
double firstEma[];                                       // first EMA: invisible

int    ma.appliedPrice;
string ma.name = "";                                     // name for chart legend, "Data" window and context menues

int    drawType;
string legendLabel = "";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // (1) validate inputs
   // MA.Periods
   if (MA.Periods < 1) return(catch("onInit(1)  invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));

   // MA.AppliedPrice
   string values[], sValue = StrToLower(MA.AppliedPrice);
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                      // default price type
   ma.appliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (IsEmpty(ma.appliedPrice) || ma.appliedPrice > PRICE_WEIGHTED) {
                       return(catch("onInit(2)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   }
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // Colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (MA.Color == 0xFF000000) MA.Color = CLR_NONE;

   // Draw.Type
   sValue = StrToLower(Draw.Type);
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("line", sValue)) { drawType = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { drawType = DRAW_ARROW; Draw.Type = "Dot";  }
   else                return(catch("onInit(3)  invalid input parameter Draw.Type: "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // Draw.Width
   if (Draw.Width < 0) return(catch("onInit(4)  invalid input parameter Draw.Width: "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Bars
   if (Max.Bars < -1)  return(catch("onInit(5)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));


   // (2) setup buffer management
   SetIndexBuffer(MODE_DEMA,  dema    );
   SetIndexBuffer(MODE_EMA_1, firstEma);


   // (3) data display configuration, names and labels
   if (!IsSuperContext()) {                                    // no chart legend if called by iCustom()
       legendLabel = CreateLegendLabel();
       RegisterObject(legendLabel);
   }
   string shortName="DEMA("+ MA.Periods +")", strAppliedPrice="";
   if (ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ", "+ PriceTypeDescription(ma.appliedPrice);
   ma.name = "DEMA("+ MA.Periods + strAppliedPrice +")";
   IndicatorShortName(shortName);                              // chart tooltips and context menu
   SetIndexLabel(MODE_DEMA,  shortName);                       // chart tooltips and "Data" window
   SetIndexLabel(MODE_EMA_1, NULL);
   IndicatorDigits(Digits | 1);


   // (4) drawing options and styles
   int startDraw = 0;
   if (Max.Bars >= 0) startDraw = Bars - Max.Bars;
   if (startDraw < 0) startDraw = 0;
   SetIndexDrawBegin(MODE_DEMA, startDraw);
   SetIndicatorOptions();

   return(catch("onInit(6)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   RepositionLegend();
   return(catch("onDeinit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(dema)) return(logInfo("onTick(1)  sizeof(dema) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(dema,     EMPTY_VALUE);
      ArrayInitialize(firstEma, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(dema,     Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(firstEma, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Bars >= 0) /*&&*/ if (Max.Bars < ChangedBars)
      changedBars = Max.Bars;                                        // Because EMA(EMA) is used in the calculation, DEMA needs 2*<period>-1 samples
   int bar, startbar = Min(changedBars-1, Bars - (2*MA.Periods-1));  // to start producing values in contrast to <period> samples needed by a regular EMA.
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate changed bars
   double secondEma;
   for (bar=ChangedBars-1; bar >= 0; bar--)   firstEma[bar] =    iMA(NULL,     NULL,        MA.Periods, 0, MODE_EMA, ma.appliedPrice, bar);
   for (bar=startbar;      bar >= 0; bar--) { secondEma = iMAOnArray(firstEma, WHOLE_ARRAY, MA.Periods, 0, MODE_EMA,                  bar);
      dema[bar] = 2 * firstEma[bar] - secondEma;
   }


   // (3) update chart legend
   if (!IsSuperContext()) {
       Trend.UpdateLegend(legendLabel, ma.name, "", MA.Color, MA.Color, dema[0], Digits, NULL, Time[0]);
   }
   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(terminal_buffers);

   int draw_type = ifInt(Draw.Width, drawType, DRAW_NONE);

   SetIndexStyle(MODE_DEMA, draw_type, EMPTY, Draw.Width, MA.Color); SetIndexArrow(MODE_DEMA, 158);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",      MA.Periods,                      ";", NL,
                            "MA.AppliedPrice=", DoubleQuoteStr(MA.AppliedPrice), ";", NL,
                            "MA.Color=",        ColorToStr(MA.Color),            ";", NL,
                            "Draw.Type=",       DoubleQuoteStr(Draw.Type),       ";", NL,
                            "Draw.Width=",      Draw.Width,                      ";", NL,
                            "Max.Bars=",        Max.Bars,                        ";")
   );
}
