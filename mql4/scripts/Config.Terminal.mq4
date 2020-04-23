/**
 * Load global and current terminal configurations into the editor.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = {INIT_NO_BARS_REQUIRED};
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   string files[2];
   files[0] = GetGlobalConfigPathA(); if (!StringLen(files[0])) return(ERR_RUNTIME_ERROR);
   files[1] = GetLocalConfigPathA();  if (!StringLen(files[1])) return(ERR_RUNTIME_ERROR);

   EditFiles(files);
   return(catch("onStart(1)"));
}
