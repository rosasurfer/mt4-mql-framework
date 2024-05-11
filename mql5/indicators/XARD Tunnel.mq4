/**
 * XARD Tunnel - a tunnel built from two or three Moving Averages with unique visualization and optionally repainted candles.
 *
 * Moving Averages change color when price leaves the channel. Candles change color when price leaves the channel built from
 * all tunnels combined.
 *
 *
 * This indicator is a rewrite (bug fixes and performance improvements) and merger of two other indicators:
 *  - "XU-MA v3" from "XU-2nd Dot Edition" (22.10.2020), a tunnel built from two Moving Averages
 *  - "XU v4-XARDFX" from "XARD FX Final Edition" (04.05.2021), a tunnel built from three Moving Averages
 *
 *  @link  https://forex-station.com/viewtopic.php?p=1295421612#p1295421612                              [XU-2nd Dot Edition]
 *  @link  https://forex-station.com/viewtopic.php?p=1295434513#p1295434513                           [XARD FX Final Edition]
 */
#property strict
#include <stddefines.mqh>

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

input string         ___a__________________________ = "=== MA 1 settings ===";
input bool           ShowMA1                        = true;
input ENUM_MA_METHOD MA1_Method                     = MODE_EMA;
input int            MA1_Periods                    = 9;
input color          MA1_ColorUp                    = RoyalBlue;
input color          MA1_ColorDown                  = Gold;
input int            MA1_Width                      = 3;

input string         ___b__________________________ = "=== MA 2 settings ===";
input bool           ShowMA2                        = true;
input ENUM_MA_METHOD MA2_Method                     = MODE_EMA;
input int            MA2_Periods                    = 36;
input color          MA2_ColorUp                    = RoyalBlue;
input color          MA2_ColorDown                  = Gold;
input int            MA2_Width                      = 4;

input string         ___c__________________________ = "=== MA 3 settings ===";
input bool           ShowMA3                        = true;
input ENUM_MA_METHOD MA3_Method                     = MODE_EMA;
input int            MA3_Periods                    = 144;
input color          MA3_ColorUp                    = RoyalBlue;
input color          MA3_ColorDown                  = Gold;
input int            MA3_Width                      = 5;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <stdfunctions.mqh>

#property indicator_chart_window
#property indicator_buffers   1           // buffers visible to the user


double buffer[];


/**
 * Initialization
 *
 * @return int - error status
 */
int init() {
   // input validation
   // chart legend

   debug("init(0.1)  hello world");

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
 * Set indicator options.
 *
 * @param  bool redraw [optional] - whether to redraw the chart (default: no)
 */
void SetIndicatorOptions(bool redraw = false) {
   SetIndexBuffer(0, buffer);
   SetIndexStyle(0, DRAW_NONE);
}
