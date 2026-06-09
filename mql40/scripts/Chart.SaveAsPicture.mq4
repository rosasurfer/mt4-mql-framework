/**
 * Chart.SaveAsPicture
 *
 * Triggers the chart context command Chart->Save-as-Picture.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   int hWnd = __ExecutionContext[EC.chartWindow];
   PostMessageA(hWnd, WM_COMMAND, ID_CHART_SAVE_AS_PICTURE, 0);
   return(last_error);
}
