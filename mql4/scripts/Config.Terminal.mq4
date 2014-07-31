/**
 * Lädt die Konfigurationsdateien der MetaTrader-Instanz in den Editor.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>

#include <win32api.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   string sNull, files[2];
   files[0] = GetGlobalConfigPath(); if (!StringLen(files[0])) return(SetLastError(stdlib.GetLastError()));
   files[1] = GetLocalConfigPath();  if (!StringLen(files[1])) return(SetLastError(stdlib.GetLastError()));

   for (int i=0; i < 2; i++) {
      int result = ShellExecuteA(NULL, "open", files[i], sNull, sNull, SW_SHOWNORMAL);
      if (result <= 32)
         return(catch("onStart()->shell32::ShellExecuteA(file=\""+ files[i] +"\")   "+ ShellExecuteErrorDescription(result), ERR_WIN32_ERROR+result));
   }

   return(last_error);
}
