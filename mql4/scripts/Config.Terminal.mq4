/**
 * Lädt die Konfigurationsdateien der MetaTrader-Instanz in den Editor.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_NO_BARS_REQUIRED };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   string files[2];
   files[0] = GetGlobalConfigPath(); if (!StringLen(files[0])) return(ERR_RUNTIME_ERROR);
   files[1] = GetLocalConfigPath();  if (!StringLen(files[1])) return(ERR_RUNTIME_ERROR);

   if (!EditFiles(files)) return(ERR_RUNTIME_ERROR);

   return(catch("onStart(1)"));
}
