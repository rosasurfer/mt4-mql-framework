/**
 * Entfernt in neueren Builds die Suchbox.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
//#include <stdlib.mqh>
#include <win32api.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   int hWnd     = GetApplicationWindow();                      if (!hWnd    ) return(debug("onStart(1)  hWndMain not found", last_error));
   int hToolbar = GetDlgItem(hWnd,     IDC_TOOLBAR);           if (!hToolbar) return(debug("onStart(2)  Toolbar not found", last_error));
   int hCtrl    = GetDlgItem(hToolbar, IDC_TOOLBAR_SEARCHBOX); if (!hCtrl   ) return(debug("onStart(3)  Search box not found", last_error));

   if (!PostMessageA(hCtrl, WM_CLOSE, 0, 0))                                  return(catch("onStart(4)->PostMessageA()  failed", ERR_WIN32_ERROR));
   while (IsWindow(hCtrl)) Sleep(100);
   if (!RedrawWindow(hToolbar, NULL, NULL, RDW_ERASE|RDW_INVALIDATE))         return(catch("onStart(5)->RedrawWindow()  failed", ERR_WIN32_ERROR));

   return(catch("onStart(6)"));
}
