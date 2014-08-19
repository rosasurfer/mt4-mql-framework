/**
 * Lädt die Konfigurationsdateien der MetaTrader-Instanz in den Editor.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   string files[2];
   files[0] = GetGlobalConfigPath(); if (!StringLen(files[0])) return(SetLastError(stdlib.GetLastError()));
   files[1] = GetLocalConfigPath();  if (!StringLen(files[1])) return(SetLastError(stdlib.GetLastError()));

   if (!EditFiles(files))
      return(SetLastError(stdlib.GetLastError()));

   return(catch("onStart(1)"));
}
