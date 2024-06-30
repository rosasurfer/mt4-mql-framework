/**
 * Trend Bars
 *
 * Colors chart bars according to the indicated trend:
 *  - Close prices above the tunnel are interpreted as "up trend".
 *  - Close prices below the tunnel are interpreted as "down trend".
 *  - Close prices in the tunnel are interpreted as "no trend".
 *
 *
 * TODO:
 *  - CCI as data source
 *  - MQL5 indicator as source for MQL5 chart properties
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
extern color  Color.DownTrend                = Red;
extern color  Color.NoTrend                  = Silver;
extern int    BarWidth                       = 2;
extern int    MaxBarsBack                    = 10000;       // max. values to calculate (-1: all available)
extern bool   ShowChartLegend                = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/HandleCommands.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/functions/iCustom/MaTunnel.mqh>

#define BUFFER_TREND_BODY_A      0        // indicator buffer ids
#define BUFFER_TREND_BODY_B      1
#define BUFFER_TREND_WICK_A      2
#define BUFFER_TREND_WICK_B      3
#define BUFFER_NOTREND_BODY_A    4
#define BUFFER_NOTREND_BODY_B    5
#define BUFFER_NOTREND_WICK_A    6
#define BUFFER_NOTREND_WICK_B    7

#property indicator_chart_window
#property indicator_buffers 8             // visible buffers

#property indicator_color1  CLR_NONE
#property indicator_color2  CLR_NONE
#property indicator_color3  CLR_NONE
#property indicator_color4  CLR_NONE
#property indicator_color5  CLR_NONE
#property indicator_color6  CLR_NONE
#property indicator_color7  CLR_NONE
#property indicator_color8  CLR_NONE

double trendBodyA[];                      // indicator buffers
double trendBodyB[];
double trendWickA[];
double trendWickB[];

double noTrendBodyA[];
double noTrendBodyB[];
double noTrendWickA[];
double noTrendWickB[];

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

   // reset the command handler
   if (__isChart) GetChartCommand("TrendBars", sValues);

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
   // process incoming commands
   if (__isChart) {
      if (!HandleCommands("TrendBars")) return(last_error);
   }

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(trendBodyA,   0);
      ArrayInitialize(trendBodyB,   0);
      ArrayInitialize(trendWickA,   0);
      ArrayInitialize(trendWickB,   0);
      ArrayInitialize(noTrendBodyA, 0);
      ArrayInitialize(noTrendBodyB, 0);
      ArrayInitialize(noTrendWickA, 0);
      ArrayInitialize(noTrendWickB, 0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(trendBodyA,   Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(trendBodyB,   Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(trendWickA,   Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(trendWickB,   Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(noTrendBodyA, Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(noTrendBodyB, Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(noTrendWickA, Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(noTrendWickB, Bars, ShiftedBars, 0);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-tunnel.periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      trendBodyA  [bar] = 0;
      trendBodyB  [bar] = 0;
      trendWickA  [bar] = 0;
      trendWickB  [bar] = 0;
      noTrendBodyA[bar] = 0;
      noTrendBodyB[bar] = 0;
      noTrendWickA[bar] = 0;
      noTrendWickB[bar] = 0;

      double upperBand = GetMaTunnel(MODE_UPPER, bar);
      double lowerBand = GetMaTunnel(MODE_LOWER, bar);

      if (Close[bar] > upperBand) {
         if (Open[bar] > Close[bar]) {
            trendBodyA[bar] = Open [bar];
            trendBodyB[bar] = Close[bar];
         }
         else {
            trendBodyA[bar] = Close[bar];
            trendBodyB[bar] = Open [bar];
         }
         trendWickA[bar] = High[bar];
         trendWickB[bar] = Low [bar];
      }
      else if (Close[bar] < lowerBand) {
         if (Open[bar] > Close[bar]) {
            trendBodyA[bar] = Close[bar];
            trendBodyB[bar] = Open [bar];
         }
         else {
            trendBodyA[bar] = Open [bar];
            trendBodyB[bar] = Close[bar];
         }
         trendWickA[bar] = Low [bar];
         trendWickB[bar] = High[bar];
      }
      else {
         noTrendBodyA[bar] = Open [bar];
         noTrendBodyB[bar] = Close[bar];
         noTrendWickA[bar] = High [bar];
         noTrendWickB[bar] = Low  [bar];
      }
   }
   return(catch("onTick(1)"));
}


/**
 * Process an incoming command.
 *
 * @param  string cmd    - command name
 * @param  string params - command parameters
 * @param  int    keys   - combination of pressed modifier keys
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params, int keys) {
   if (cmd == "barwidth") {
      if (params == "increase") {
         BarWidth = Min(BarWidth+1, 13);
         return(SetIndicatorOptions(true));
      }
      if (params == "decrease") {
         BarWidth = Max(BarWidth-1, 0);
         return(SetIndicatorOptions(true));
      }
   }
   return(!logNotice("onCommand(1)  unsupported command: "+ DoubleQuoteStr(cmd +":"+ params +":"+ keys)));
}


/**
 * Get a band value of the "MA Tunnel" indicator.
 *
 * @param  int mode - band identifier: MODE_UPPER | MODE_LOWER
 * @param  int bar  - bar offset
 *
 * @return double - band value or NULL in case of errors
 */
double GetMaTunnel(int mode, int bar) {
   if (tunnel.method == MODE_ALMA) {
      static int buffers[] = {0, MaTunnel.MODE_UPPER_BAND, MaTunnel.MODE_LOWER_BAND};
      return(icMaTunnel(NULL, tunnel.definition, buffers[mode], bar));
   }
   static int priceTypes[] = {0, PRICE_HIGH, PRICE_LOW};
   return(iMA(NULL, NULL, tunnel.periods, 0, tunnel.method, priceTypes[mode], bar));
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
   indicatorName = ProgramName();
   IndicatorShortName(indicatorName);

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(BUFFER_TREND_BODY_A,   trendBodyA);   SetIndexEmptyValue(BUFFER_TREND_BODY_A,   0);
   SetIndexBuffer(BUFFER_TREND_BODY_B,   trendBodyB);   SetIndexEmptyValue(BUFFER_TREND_BODY_B,   0);
   SetIndexBuffer(BUFFER_TREND_WICK_A,   trendWickA);   SetIndexEmptyValue(BUFFER_TREND_WICK_A,   0);
   SetIndexBuffer(BUFFER_TREND_WICK_B,   trendWickB);   SetIndexEmptyValue(BUFFER_TREND_WICK_B,   0);
   SetIndexBuffer(BUFFER_NOTREND_BODY_A, noTrendBodyA); SetIndexEmptyValue(BUFFER_NOTREND_BODY_A, 0);
   SetIndexBuffer(BUFFER_NOTREND_BODY_B, noTrendBodyB); SetIndexEmptyValue(BUFFER_NOTREND_BODY_B, 0);
   SetIndexBuffer(BUFFER_NOTREND_WICK_A, noTrendWickA); SetIndexEmptyValue(BUFFER_NOTREND_WICK_A, 0);
   SetIndexBuffer(BUFFER_NOTREND_WICK_B, noTrendWickB); SetIndexEmptyValue(BUFFER_NOTREND_WICK_B, 0);
   IndicatorDigits(Digits);

   int drawType = ifInt(BarWidth, DRAW_HISTOGRAM, DRAW_NONE);
   SetIndexStyle(BUFFER_TREND_BODY_A,   drawType, EMPTY, BarWidth, Color.UpTrend);     // in histograms the larger of both values
   SetIndexStyle(BUFFER_TREND_BODY_B,   drawType, EMPTY, BarWidth, Color.DownTrend);   // determines the applied color
   SetIndexStyle(BUFFER_TREND_WICK_A,   drawType, EMPTY, 1,        Color.UpTrend);
   SetIndexStyle(BUFFER_TREND_WICK_B,   drawType, EMPTY, 1,        Color.DownTrend);
   SetIndexStyle(BUFFER_NOTREND_BODY_A, drawType, EMPTY, BarWidth, Color.NoTrend);
   SetIndexStyle(BUFFER_NOTREND_BODY_B, drawType, EMPTY, BarWidth, Color.NoTrend);
   SetIndexStyle(BUFFER_NOTREND_WICK_A, drawType, EMPTY, 1,        Color.NoTrend);
   SetIndexStyle(BUFFER_NOTREND_WICK_B, drawType, EMPTY, 1,        Color.NoTrend);

   SetIndexLabel(BUFFER_TREND_BODY_A,   NULL);
   SetIndexLabel(BUFFER_TREND_BODY_B,   NULL);
   SetIndexLabel(BUFFER_TREND_WICK_A,   NULL);
   SetIndexLabel(BUFFER_TREND_WICK_B,   NULL);
   SetIndexLabel(BUFFER_NOTREND_BODY_A, NULL);
   SetIndexLabel(BUFFER_NOTREND_BODY_B, NULL);
   SetIndexLabel(BUFFER_NOTREND_WICK_A, NULL);
   SetIndexLabel(BUFFER_NOTREND_WICK_B, NULL);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
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
