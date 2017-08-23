/**
 * Open a chart window.
 */
#property show_inputs

////////////////////////////////////////////////////////////// Configuration ///////////////////////////////////////////////////////////////

extern int Symbol.Id = 36000;     // symbol id in MarketWatch window starting at 36000 for the top-most symbol

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


#import "Expander.dll"
   int  GetApplicationWindow();
   int  MT4InternalMsg();
#import "user32.dll"
   bool PostMessageA(int hWnd, int msg, int wParam, int lParam);
#import


#define MT4_OPEN_CHART           51
#define ERR_USER_ERROR_FIRST  65536


/**
 * Main function
 *
 * @return int - error status
 */
int start() {
   int hWnd = GetApplicationWindow();
   if (!hWnd) return(ERR_USER_ERROR_FIRST);

   PostMessageA(hWnd, MT4InternalMsg(), MT4_OPEN_CHART, Chart.Id);

   return(0);
}
