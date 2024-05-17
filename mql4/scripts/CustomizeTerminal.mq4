/**
 * Remove search box and MQL5 community button from the terminal's toolbar.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/win32api.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   int hWnd = GetTerminalMainWindow();           if (!hWnd)     return(last_error);
   int hToolbar = GetDlgItem(hWnd, IDC_TOOLBAR); if (!hToolbar) return(catch("onStart(1)  terminal toolbar not found", ERR_RUNTIME_ERROR));

   // find and remove a search box control (it contains the community button)
   int hSearchCtrl = GetDlgItem(hToolbar, IDC_TOOLBAR_SEARCHBOX);
   if (hSearchCtrl != 0) {
      PostMessageA(hSearchCtrl, WM_CLOSE, 0, 0);
      while (IsWindow(hSearchCtrl)) {
         Sleep(100);
      }
      if (!RedrawWindow(hToolbar, NULL, NULL, RDW_ERASE|RDW_INVALIDATE)) return(catch("onStart(2)->RedrawWindow()  failed", ERR_WIN32_ERROR));
   }

   // if search box control not found, find/remove an independent community button
   if (!hSearchCtrl) {
      int hBtnCtrl = GetDlgItem(hToolbar, IDC_TOOLBAR_COMMUNITY_BUTTON);
      if (hBtnCtrl != 0) PostMessageA(hBtnCtrl, WM_CLOSE, 0, 0);
   }
   return(catch("onStart(3)"));
}
