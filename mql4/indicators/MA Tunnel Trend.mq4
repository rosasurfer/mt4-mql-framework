/**
 *
 *
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>

#property indicator_chart_window
#property indicator_buffers   1              // buffers visible to the user


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   SetIndicatorOptions();
   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   return(catch("onTick(1)"));
}


/**
 * Set indicator options.
 *
 * @param  bool redraw [optional] - whether to redraw the chart (default: no)
 */
void SetIndicatorOptions(bool redraw = false) {
   //SetIndexBuffer(0, buffer);
   //SetIndexStyle(0, DRAW_NONE);
}
