/**
 * MA Tunnel Trend
 *
 *
 * Colors chart bars according to the indicated trend:
 *  - Close prices above the tunnel are interpreted as "up trend".
 *  - Close prices below the tunnel are interpreted as "down trend".
 *  - Close prices in the tunnel are interpreted as "no trend".
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___a__________________________ = "=== Tunnel settings ===";
extern int    Tunnel.Periods                 = 55;
extern string Tunnel.Method                  = "SMA | LWMA* | EMA | SMMA | ALMA";

extern string ___b__________________________ = "=== Bar settings ===";
extern color  Color.UpTrend                  = Blue;
extern color  Color.DownTrend                = Gold;
extern color  Color.NoTrend                  = Gray;
extern int    BarWidth                       = 2;
extern int    MaxBarsBack                    = 10000;       // max. values to calculate (-1: all available)
extern bool   ShowChartLegend                = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>

#define BUFFER_BAR_OPEN      0         // indicator buffer ids
#define BUFFER_BAR_CLOSE     1         //

#property indicator_chart_window
#property indicator_buffers  2         // visible buffers
int       terminal_buffers = 2;

#property indicator_color1   CLR_NONE
#property indicator_color2   CLR_NONE

double barOpen [];                     // indicator buffers
double barClose[];

int    tunnel.periods;
int    tunnel.method;
string tunnel.definition = "";

string indicatorName = "";
string legendLabel   = "";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // input validation
   string indicator = WindowExpertName();

   // Tunnel.Periods
   if (AutoConfiguration) Tunnel.Periods = GetConfigInt(indicator, "Tunnel.Periods", Tunnel.Periods);
   if (Tunnel.Periods < 1)  return(catch("onInit(1)  invalid input parameter Tunnel.Periods: "+ Tunnel.Periods +" (must be positive)", ERR_INVALID_INPUT_PARAMETER));
   tunnel.periods = Tunnel.Periods;
   // Tunnel.Method
   string sValues[], sValue = Tunnel.Method;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "Tunnel.Method", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   tunnel.method = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (tunnel.method == -1) return(catch("onInit(2)  invalid input parameter Tunnel.Method: "+ DoubleQuoteStr(Tunnel.Method), ERR_INVALID_INPUT_PARAMETER));
   Tunnel.Method = MaMethodDescription(tunnel.method);
   tunnel.definition = Tunnel.Method +"("+ tunnel.periods+")";
   // Color.*: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Color.UpTrend   = GetConfigColor(indicator, "Color.UpTrend",   Color.UpTrend);
   if (AutoConfiguration) Color.DownTrend = GetConfigColor(indicator, "Color.DownTrend", Color.DownTrend);
   if (AutoConfiguration) Color.NoTrend   = GetConfigColor(indicator, "Color.NoTrend",   Color.NoTrend);
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;
   if (Color.NoTrend   == 0xFF000000) Color.NoTrend   = CLR_NONE;
   // BarWidth
   if (BarWidth < 0)        return(catch("onInit(3)  invalid input parameter BarWidth: "+ BarWidth, ERR_INVALID_INPUT_PARAMETER));
   if (BarWidth > 13)       return(catch("onInit(4)  invalid input parameter BarWidth: "+ BarWidth, ERR_INVALID_INPUT_PARAMETER));
   // MaxBarsBack
   if (MaxBarsBack < -1)    return(catch("onInit(5)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // display options
   if (ShowChartLegend) legendLabel = CreateChartLegend();

   SetIndicatorOptions();
   return(catch("onInit(6)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(barOpen,  0);
      ArrayInitialize(barClose, 0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(barOpen,  Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(barClose, Bars, ShiftedBars, 0);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1);

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      barOpen [bar] = Open [bar];
      barClose[bar] = Close[bar];
   }

   if (!__isSuperContext) {
      //if (__isChart && ShowChartLegend) UpdateTrendLegend(legendLabel, indicatorName, legendInfo, UpTrend.Color, DownTrend.Color, main[0], trend[0]);
   }
   return(catch("onTick(1)"));
}


/**
 * Set indicator options. After recompilation the function must be called from start() for options not to be ignored.
 *
 * @param  bool redraw [optional] - whether to redraw the chart (default: no)
 */
void SetIndicatorOptions(bool redraw = false) {
   indicatorName = ProgramName();
   IndicatorShortName(indicatorName);

   IndicatorBuffers(terminal_buffers);
   SetIndexBuffer(BUFFER_BAR_OPEN,  barOpen);  SetIndexEmptyValue(BUFFER_BAR_OPEN,  0);
   SetIndexBuffer(BUFFER_BAR_CLOSE, barClose); SetIndexEmptyValue(BUFFER_BAR_CLOSE, 0);
   IndicatorDigits(Digits);

   int drawTypeBars = ifInt(BarWidth, DRAW_HISTOGRAM, DRAW_NONE);
   SetIndexStyle(BUFFER_BAR_OPEN,  drawTypeBars, EMPTY, BarWidth, Color.DownTrend);    // in histograms the larger of both values
   SetIndexStyle(BUFFER_BAR_CLOSE, drawTypeBars, EMPTY, BarWidth, Color.UpTrend);      // determines the applied color

   SetIndexLabel(BUFFER_BAR_OPEN,  NULL);
   SetIndexLabel(BUFFER_BAR_CLOSE, NULL);

   if (redraw) WindowRedraw();
   catch("SetIndicatorOptions(1)");
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Tunnel.Periods=",  Tunnel.Periods,                ";", NL,
                            "Tunnel.Method=",   DoubleQuoteStr(Tunnel.Method), ";", NL,

                            "Color.UpTrend=",   ColorToStr(Color.UpTrend),     ";", NL,
                            "Color.DownTrend=", ColorToStr(Color.DownTrend),   ";", NL,
                            "Color.NoTrend=",   ColorToStr(Color.NoTrend),     ";", NL,
                            "BarWidth=",        BarWidth,                      ";", NL,
                            "MaxBarsBack=",     MaxBarsBack,                   ";", NL,
                            "ShowChartLegend=", BoolToStr(ShowChartLegend),    ";")
   );
}
