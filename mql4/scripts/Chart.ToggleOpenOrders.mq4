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


string currency;


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
      MessageBox("The current instrument is not a LFX index: "+ GetSymbolName(Symbol()), __SCRIPT__, MB_ICONEXCLAMATION|MB_OK);
      init_error = ERR_RUNTIME_ERROR;
      return(init_error);
   }

   if (StringStartsWith(Symbol(), "LFX")) currency = StringRight(Symbol(), -3);
   else                                   currency = StringLeft (Symbol(), -3);

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


   string file    = TerminalPath() +"\\experts\\files\\"+ GetShortAccountCompany() +"\\external_positions.ini";
   string section = Account.Company +"."+ Account.Number;
   string keys[];

   int sizeOfKeys = GetPrivateProfileKeys(file, section, keys);

   for (int i=0; i < sizeOfKeys; i++) {
      if (StringIStartsWith(keys[i], currency)) {
         string values[], value=GetPrivateProfileString(file, section, keys[i], "");
         if (Explode(value, "|", values, NULL) != 4) {
            debug("start()   invalid entry: "+ keys[i] +" = "+ value);
            continue;
         }
         debug("start()   Position des aktuellen Instruments: "+ keys[i] +" = "+ StringArrayToStr(values, NULL));
      }
   }


   return(catch("start()"));
}

