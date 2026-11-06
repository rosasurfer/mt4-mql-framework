/**
 * Chart Legend
 *
 * This indicator displays just a configurable chart legend.
 *
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Text       = "Chart Legend";
extern color  Text.Color = Blue;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_color1  CLR_NONE


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (__isChart && !__isSuperContext) {
      if (AutoConfiguration) Text = GetConfigString(WindowExpertName(), "Text", Text);

      string legendLabel = CreateChartLegend();
      string legendText  = Text;
      color  legendColor = Text.Color;

      if      (legendColor == Aqua        ) legendColor = DodgerBlue;
      else if (legendColor == Gold        ) legendColor = Orange;
      else if (legendColor == LightSkyBlue) legendColor = C'94,174,255';
      else if (legendColor == Lime        ) legendColor = LimeGreen;
      else if (legendColor == Yellow      ) legendColor = Orange;

      ObjectSetText(legendLabel, legendText, 9, "Arial Fett", legendColor);
      int error = GetLastError();
      if (error && error!=ERR_OBJECT_DOES_NOT_EXIST) catch("onInit(1)", error);  // on ObjectDrag or opened "Properties" dialog
   }

   SetIndicatorOptions();
   return(catch("onInit(4)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // reset indicator options before first usage
   if (!ValidBars) {
      SetIndicatorOptions();
   }
   return(last_error);
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

   // the indicator dialog always displays at least one buffer, colored black
   IndicatorBuffers(indicator_buffers);
   SetIndexStyle(0, DRAW_NONE, EMPTY, EMPTY, CLR_NONE);
   SetIndexLabel(0, NULL);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate(
      "Text=",       DoubleQuoteStr(Text),   ";", NL,
      "Text.Color=", ColorToStr(Text.Color), ";", NL
   ));
}
