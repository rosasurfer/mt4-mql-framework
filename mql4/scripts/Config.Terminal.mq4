/**
 * Lädt die Konfigurationsdateien der MetaTrader-Instanz in den Editor.
 */
#include <stdlib.mqh>
#include <win32api.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   return(onInit(T_SCRIPT));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   string files[2];

   files[0] = GetGlobalConfigPath();
   files[1] = GetLocalConfigPath();

   string sNull;

   for (int i=0; i < 2; i++) {
      int hInstance = ShellExecuteA(NULL, "open", files[i], sNull, sNull, SW_SHOWNORMAL);
      if (hInstance < 33)
         return(catch("onStart(1) ->shell32::ShellExecuteA()   can't open \""+ files[i] +"\", error="+ hInstance +" ("+ ShellExecuteErrorToStr(hInstance) +")", ERR_WIN32_ERROR));
   }

   return(catch("onStart(2)"));
}
