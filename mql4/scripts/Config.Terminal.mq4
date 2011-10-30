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
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);
   return(catch("init()"));
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
int start() {
   init = false;
   if (init_error != NO_ERROR)
      return(init_error);
   // ------------------------


   string files[2];

   files[0] = GetGlobalConfigPath();
   files[1] = GetLocalConfigPath();

   string sNull;

   for (int i=0; i < 2; i++) {
      int hInstance = ShellExecuteA(NULL, "open", files[i], sNull, sNull, SW_SHOWNORMAL);
      if (hInstance < 33)
         return(catch("start(1) ->shell32.ShellExecuteA()   can't open \""+ files[i] +"\", error="+ hInstance +" ("+ ShellExecuteErrorToStr(hInstance) +")", ERR_WIN32_ERROR));
   }

   return(catch("start(2)"));
}
