/**
 * Rules Monitor
 *
 * Monitors and signals pre-defined trading rules.
 */
#property indicator_chart_window

#include <rsf/stddefines.mqh>
int   __InitFlags[] = { INIT_TIMEZONE };
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string MaChannel.Method       = "SMA | LWMA | EMA* | SMMA | ALMA";
extern int    MaChannel.Periods      = 100;
extern int    Trend.BarsOutOfChannel = 1;

extern color  Color.UpTrend          = C'55,130,55';
extern color  Color.DownTrend        = Sienna;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/functions/iCustom/MaChannel.mqh>

#property indicator_buffers 2

#property indicator_color1  CLR_NONE
#property indicator_color2  CLR_NONE

#define MODE_CHANNEL_TREND  0
#define MODE_SYSTEM_TREND   1

double channelTrend[];                    // channel trend direction + length: amount of bars above/below the channel
double systemTrend [];                    // trend according to the system rules

int    maChannel.method;
int    maChannel.periods;
string maChannel.definition = "";
int    maChannel.trendBars;

int    maxBarsBack = 5000;

int    panel.xPos = 40;
int    panel.yPos = 390;

#define D_LONG  TRADE_DIRECTION_LONG      // trend direction types
#define D_SHORT TRADE_DIRECTION_SHORT     //


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // MaChannel.Method
   if (AutoConfiguration) MaChannel.Method = GetConfigString(indicator, "MaChannel.Method", MaChannel.Method);
   string sValues[], sValue = MaChannel.Method;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   maChannel.method = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maChannel.method == -1) return(catch("onInit(1)  invalid input parameter MaChannel.Method: "+ DoubleQuoteStr(MaChannel.Method), ERR_INVALID_INPUT_PARAMETER));
   MaChannel.Method = MaMethodDescription(maChannel.method);
   // MaChannel.Periods
   if (AutoConfiguration) MaChannel.Periods = GetConfigInt(indicator, "MaChannel.Periods", MaChannel.Periods);
   if (MaChannel.Periods < 1)  return(catch("onInit(2)  invalid input parameter MaChannel.Periods: "+ MaChannel.Periods +" (must be positive)", ERR_INVALID_INPUT_PARAMETER));
   maChannel.periods = MaChannel.Periods;
   maChannel.definition = MaChannel.Method +"("+ maChannel.periods+")";
   // Trend.BarsOutOfChannel
   if (AutoConfiguration) Trend.BarsOutOfChannel = GetConfigInt(indicator, "Trend.BarsOutOfChannel", Trend.BarsOutOfChannel);
   if (Trend.BarsOutOfChannel < 1) return(catch("onInit(3)  invalid input parameter Trend.BarsOutOfChannel: "+ Trend.BarsOutOfChannel +" (must be positive)", ERR_INVALID_INPUT_PARAMETER));
   maChannel.trendBars = Trend.BarsOutOfChannel;
   // colors: after deserialization the terminal may turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;
   if (AutoConfiguration) {
      Color.UpTrend   = GetConfigColor(indicator, "Color.UpTrend",   Color.UpTrend);
      Color.DownTrend = GetConfigColor(indicator, "Color.DownTrend", Color.DownTrend);
   }

   RestoreStatus();
   SetIndicatorOptions();

   return(catch("onInit(3)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   StoreStatus();
   return(catch("onDeinit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(channelTrend, 0);
      ArrayInitialize(systemTrend,  0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(channelTrend, Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(systemTrend,  Bars, ShiftedBars, 0);
   }

   // calculate start bar
   int startbar = Min(maxBarsBack-1, ChangedBars-1, Bars-maChannel.periods);
   if (startbar < 0) return(logInfo("onTick(1)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   int trendBars = maChannel.trendBars;

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      channelTrend[bar] = 0;                             // reset the bar to update
      systemTrend [bar] = 0;

      double upperBand = icMaChannel(NULL, maChannel.definition, MaChannel.MODE_UPPER_BAND, bar);
      double lowerBand = icMaChannel(NULL, maChannel.definition, MaChannel.MODE_LOWER_BAND, bar);
      if (!upperBand || !lowerBand) return(catch("onTick(2)->icMaChannel()  unexpected result: bar="+ bar +"|"+ TimeToStr(Time[bar]) +"  upperBand="+ NumberToStr(upperBand, PriceFormat) +"  lowerBand="+ NumberToStr(lowerBand, PriceFormat), ERR_ILLEGAL_STATE));

      // channel trend changes direction on cross of the opposite channel band
      if      (Close[bar] > upperBand) channelTrend[bar] = Max(channelTrend[bar+1], 0) + 1;
      else if (Close[bar] < lowerBand) channelTrend[bar] = Min(channelTrend[bar+1], 0) - 1;

      // system trend changes direction after {trendBars} above/below the channel band
      if (systemTrend[bar+1] > 0) {
         if (channelTrend[bar+1] <= -trendBars) systemTrend[bar] = _int(channelTrend[bar+1]) + (trendBars-1);
         else                                   systemTrend[bar] = _int(systemTrend [bar+1]) + 1;
      }
      else if (systemTrend[bar+1] < 0) {
         if (channelTrend[bar+1] >= trendBars) systemTrend[bar] = _int(channelTrend[bar+1]) - (trendBars-1);
         else                                  systemTrend[bar] = _int(systemTrend [bar+1]) - 1;
      }
      else {
         if      (channelTrend[bar+1] >=  trendBars) systemTrend[bar] = _int(channelTrend[bar+1]) - (trendBars-1);
         else if (channelTrend[bar+1] <= -trendBars) systemTrend[bar] = _int(channelTrend[bar+1]) + (trendBars-1);
      }
   }

   // resolve the overall trend of finished bar 1
   int trend = 0;
   if (Abs(channelTrend[1]) >= trendBars) trend = Sign(channelTrend[1]);
   else                                   trend = Sign(systemTrend [1]);

   UpdateStatusPanel(trend);

   return(last_error);
}


/**
 * Create the status panel and return its current position.
 *
 * @param  int direction - trend direction, determines panel color
 *
 * @return bool - success status
 */
bool CreateStatusPanel(int direction) {
   if (!direction) return(!catch("CreateStatusPanel(1)  invalid parameter direction: 0", ERR_INVALID_PARAMETER));
   if (!__isChart) return(false);

   int fontSize = 15;
   color bgColor = ifInt(direction > 0, Color.UpTrend, Color.DownTrend);

   // create background
   string label = WindowExpertName() +".panel.bg";
   if (ObjectFind(label) == -1) {
      if (!ObjectCreateRegister(label, OBJ_LABEL)) return(false);
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE, panel.xPos);
      ObjectSet(label, OBJPROP_YDISTANCE, panel.yPos);
   }
   ObjectSetText(label, "ggggggggg", fontSize, "Webdings", bgColor);

   // get current position
   panel.xPos = ObjectGet(label, OBJPROP_XDISTANCE);
   panel.yPos = ObjectGet(label, OBJPROP_YDISTANCE);

   return(!catch("CreateStatusPanel(2)"));
}


/**
 * Update the status panel.
 *
 * @param  int direction - trend direction
 *
 * @return bool - success status
 */
bool UpdateStatusPanel(int direction) {
   if (!direction)                    return(false);
   if (!CreateStatusPanel(direction)) return(false);

   string label = WindowExpertName() +".msg";
   if (ObjectFind(label) == -1) {
      if (!ObjectCreateRegister(label, OBJ_LABEL)) return(false);
      ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_LEFT);
   }
   ObjectSet(label, OBJPROP_XDISTANCE, panel.xPos + 4);
   ObjectSet(label, OBJPROP_YDISTANCE, panel.yPos);

   string message = ifString(direction > 0, "LONG ONLY", "SHORT ONLY");
   ObjectSetText(label, message, 12, "Arial Black", Snow);

   return(true);
}


/**
 * Store the panel position in the chart (for init cyles, template reloads and terminal restart) and in
 * the chart window (for applying of a new template).
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (!__isChart) return(true);
   string indicatorName = WindowExpertName();

   // int panel.xPos
   string key = "rsf."+ indicatorName +".panel.xPos";
   string sValue = Max(panel.xPos, 1);                               // GetWindowInteger() cannot restore integer 0
   SetWindowStringA(__ExecutionContext[EC.chart], key, sValue);      // chart window
   Chart.StoreString(key, sValue);                                   // chart

   // int panel.yPos
   key = "rsf."+ indicatorName +".panel.yPos";
   sValue = Max(panel.yPos, 1);                                      // GetWindowInteger() cannot restore integer 0
   SetWindowStringA(__ExecutionContext[EC.chart], key, sValue);      // chart window
   Chart.StoreString(key, sValue);                                   // chart

   return(catch("StoreStatus(1)"));
}


/**
 * Restore a stored panel position.
 *
 * @return bool - success status
 */
bool RestoreStatus() {
   if (!__isChart) return(true);
   string indicatorName = WindowExpertName();

   // int panel.xPos
   string key = "rsf."+ indicatorName +".panel.xPos";
   string sValue1 = RemoveWindowStringA(__ExecutionContext[EC.chart], key), sValue2 = "";
   Chart.RestoreString(key, sValue2);
   int iValue = StrToInteger(stringOr(sValue1, sValue2));
   if (iValue > 0) panel.xPos = iValue;

   // int panel.yPos
   key = "rsf."+ indicatorName +".panel.yPos";
   sValue1 = RemoveWindowStringA(__ExecutionContext[EC.chart], key);
   Chart.RestoreString(key, sValue2);
   iValue = StrToInteger(stringOr(sValue1, sValue2));
   if (iValue > 0) panel.yPos = iValue;

   return(!catch("RestoreStatus(1)"));
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

   IndicatorBuffers(indicator_buffers);
   IndicatorDigits(0);

   SetIndexBuffer(MODE_CHANNEL_TREND, channelTrend);
   SetIndexStyle (MODE_CHANNEL_TREND, DRAW_NONE);
   SetIndexLabel (MODE_CHANNEL_TREND, "Rules: channel trend");

   SetIndexBuffer(MODE_SYSTEM_TREND, systemTrend);
   SetIndexStyle (MODE_SYSTEM_TREND, DRAW_NONE);
   SetIndexLabel (MODE_SYSTEM_TREND, "Rules: system trend");

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MaChannel.Method=",       DoubleQuoteStr(MaChannel.Method), ";", NL,
                            "MaChannel.Periods=",      MaChannel.Periods,                ";", NL,
                            "Trend.BarsOutOfChannel=", Trend.BarsOutOfChannel,           ";", NL,

                            "Color.UpTrend=",          ColorToStr(Color.UpTrend),        ";", NL,
                            "Color.DownTrend=",        ColorToStr(Color.DownTrend),      ";")
   );
}


#import "rsfMT4Expander.dll"
   int RulesMonitor_CreateStatusPanel(int pid);
   int RulesMonitor_UpdateStatusPanel(int pid);
   int RulesMonitor_RemoveStatusPanel(int pid);
#import
