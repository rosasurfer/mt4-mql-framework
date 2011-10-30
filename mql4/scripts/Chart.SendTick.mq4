/**
 * Schickt einen einzelnen Fake-Tick an den aktuellen Chart.
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

   string null;
   int hModule = GetModuleHandleA(null);   // NULL-Pointer

   if (hModule == NULL)
      return(catch("start(1) ->kernel32.GetModuleHandleA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));

   debug("start()   hModule = "+ hModule);



   string filename = "F:/MetaTrader/shared/metatrader-global-config.ini";
   string names[];
   GetPrivateProfileSectionNames(filename, names);

   debug("start()   sections = "+ StringArrayToStr(names, NULL));




   //SendTick(true);
   return(catch("start()"));
}


