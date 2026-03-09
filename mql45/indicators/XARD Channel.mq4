/**
 * XARD Channel - a channel built from multiple Moving Averages visualized by candle color.
 *
 *
 * A Moving Average channel is a channel formed by MA(Periods, PRICE_HIGH) and MA(Periods, PRICE_LOW).
 *
 * Each Moving Average changes color when BarClose crosses the outer (i.e. opposite) side of its channel.
 *
 * Candles are bullish if BarClose is above all MA channels.
 * Candles are bearish if BarClose is below all MA channels.
 * Candles are neutral if BarClose position relative to the channels is mixed.
 *
 *
 * This indicator is a combination of:
 *  - "XU-MA v3" from "XU-2nd Dot Edition", a channel built from two Moving Averages
 *  - "XU v4-XARDFX" from "XARD FX Final Edition", a channel built from three Moving Averages
 *
 *  @link  https://forex-station.com/viewtopic.php?p=1295421612#p1295421612                              [XU-2nd Dot Edition]
 *  @link  https://forex-station.com/viewtopic.php?p=1295434513#p1295434513                           [XARD FX Final Edition]
 */
#property strict
#include <rsf/stddefines.mqh>

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

input string         ___a__________________________ = "=== MA 1 settings ===";
input bool           UseMA1                         = true;
input ENUM_MA_METHOD MA1_Method                     = MODE_EMA;
input int            MA1_Periods                    = 144;
input color          MA1_ColorUp                    = RoyalBlue;
input color          MA1_ColorDown                  = Gold;
input int            MA1_Width                      = 5;

input string         ___b__________________________ = "=== MA 2 settings ===";
input bool           UseMA2                         = true;
input ENUM_MA_METHOD MA2_Method                     = MODE_EMA;
input int            MA2_Periods                    = 36;
input color          MA2_ColorUp                    = RoyalBlue;
input color          MA2_ColorDown                  = Gold;
input int            MA2_Width                      = 4;

input string         ___c__________________________ = "=== MA 3 settings ===";
input bool           UseMA3                         = true;
input ENUM_MA_METHOD MA3_Method                     = MODE_EMA;
input int            MA3_Periods                    = 9;
input color          MA3_ColorUp                    = RoyalBlue;
input color          MA3_ColorDown                  = Gold;
input int            MA3_Width                      = 3;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/stdfunctions.mqh>

#property indicator_chart_window
#property indicator_buffers   1


double buffer[];


/**
 * Initialization
 *
 * @return int - error status
 */
int init() {
   SetIndicatorOptions();
   return(catch("init(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int start() {
   debug("start(0.1)  Bars="+ (string)Bars +"  scale="+ (string)ChartGetInteger(0, CHART_SCALE));
   return(catch("start(1)"));
}


/**
 * Callback handler for chart events
 */
void OnChartEvent(const int event, const long &lParam, const double &dParam, const string &sParam) {
   if (event == CHARTEVENT_CHART_CHANGE) {
      debug("OnChartEvent(0.1)  CHARTEVENT_CHART_CHANGE  scale="+ (string)ChartGetInteger(0, CHART_SCALE));
      SetIndicatorOptions(true);
   }
   catch("OnChartEvent(1)");
}


/**
 * Set indicator options. After recompilation the function must be called from start() for options not to be ignored.
 *
 * @param  bool redraw [optional] - whether to redraw the chart (default: no)
 *
 * @return bool - success status
 */
bool SetIndicatorOptions(bool redraw = false) {
   SetIndexBuffer(0, buffer);
   SetIndexStyle(0, DRAW_NONE);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}
