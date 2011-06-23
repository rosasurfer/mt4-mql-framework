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



   string file    = TerminalPath() +"\\experts\\files\\"+ GetAccountHistoryDirectory() +"\\external_positions.ini";
   string section = Account.Company +"."+ Account.Number;

   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, MAX_STRING_LITERAL, MAX_STRING_LITERAL, MAX_STRING_LITERAL, MAX_STRING_LITERAL, MAX_STRING_LITERAL);

   GetPrivateProfileStringA(section, NULL, "", buffer[0], StringLen(buffer[0]), file);
   debug("start()   GetPrivateProfileStringA     buffer[0] = \""+ buffer[0] +"\"");

   int iBuffer[300];
   debug("start()   GetPrivateProfileStringA.alt iBuffer("+ ArraySize(iBuffer) +") = \""+ StructToStr(iBuffer) +"\"");

   GetPrivateProfileStringA.alt(section, NULL, "", iBuffer, ArraySize(iBuffer)*4, file);
   debug("start()   GetPrivateProfileStringA.alt iBuffer("+ ArraySize(iBuffer) +") = \""+ StructToStr(iBuffer) +"\"");


   return(catch("start()"));

   // F:\MetaTrader\4\experts\files\SIG-Real.com\external_positions.ini
   GetLocalConfigString(NULL, NULL, NULL);
}



/**
 * Gibt einen lokalen Konfigurationswert als String zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  string defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return string - Konfigurationswert
 */
string GetLocalConfigString(string section, string key, string defaultValue="") {
   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, MAX_STRING_LITERAL, MAX_STRING_LITERAL, MAX_STRING_LITERAL);

   GetPrivateProfileStringA(section, key, defaultValue, buffer[0], StringLen(buffer[0]), GetLocalConfigPath());

   if (catch("GetLocalConfigString()") != NO_ERROR)
      return("");
   return(buffer[0]);
}
