/**
 * Lädt die Konfigurationsdateien der MetaTrader-Instanz in den Editor.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <win32api.mqh>

#include <core/script.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   string files[2];

   files[0] = GetGlobalConfigPath();
   files[1] = GetLocalConfigPath();

   for (int i=0; i < 2; i++) {
      int hInstance = ShellExecuteA(NULL, "open", files[i], sNull, sNull, SW_SHOWNORMAL);
      if (hInstance < 33)
         return(catch("onStart()->shell32::ShellExecuteA()   can't open \""+ files[i] +"\", error="+ hInstance +" ("+ ShellExecuteErrorToStr(hInstance) +")", ERR_WIN32_ERROR));
   }

   return(last_error);
}
