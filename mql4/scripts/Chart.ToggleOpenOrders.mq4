/**
 * Zeigt in LiteForex-Charts in anderen Accounts gehalte offene LFX-Positionen an.
 */
#include <stdlib.mqh>
#include <win32api.mqh>

//#property show_inputs


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string Account.Company = "Alpari";
extern string Account.Number  = "8188497";

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


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
   if (init_error != NO_ERROR) return(init_error);
   // --------------------------------------------


   string section = Account.Company +"."+ Account.Number;
   string file    = TerminalPath() +"\\experts\\files\\"+ GetAccountHistoryDirectory() +"\\external_positions.ini";

   string keys[];
   int result = GetPrivateProfileKeys(section, keys, file);
   debug("start()   GetPrivateProfileKeys   "+ result +" keys = "+ StringArrayToStr(keys));


   return(catch("start()"));
}
