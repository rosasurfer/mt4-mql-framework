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

   if (!StringContains(Symbol(), "LFX")) {
      PlaySound("notify.wav");
      MessageBox("The current instrument is not a LFX instrument: "+ GetSymbolName(GetStandardSymbol(Symbol())), __SCRIPT__, MB_ICONEXCLAMATION|MB_OK);
      init_error = ERR_RUNTIME_ERROR;
      return(init_error);
   }
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

   int size = GetPrivateProfileKeys(section, keys, file);
   debug("start()   keys = "+ StringArrayToStr(keys));


   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");
   int bufferSize = StringLen(buffer[0]);

   for (int i=0; i < size; i++) {
      GetPrivateProfileStringA(section, keys[i], "", buffer[0], bufferSize, file);
      debug("start()   \""+ keys[i] +"\" = \""+ buffer[0] +"\"");
   }


   return(catch("start()"));
}
