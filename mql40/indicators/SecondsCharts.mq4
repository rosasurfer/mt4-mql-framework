/**
 * SecondsCharts
 *
 * @see  https://github.com/rosasurfer/mt4-mql-framework/issues/71
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Chart.Period = "S1";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>

#property indicator_chart_window
#property indicator_buffers   1              // there is a minimum of 1 buffer (even if unused)
#property indicator_color1    CLR_NONE


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   return(last_error);
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Chart.Period=", DoubleQuoteStr(Chart.Period), ";"));
}
