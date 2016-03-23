/**
 * TestScript2
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_DOESNT_REQUIRE_BARS };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <history.mqh>


/**
 *
 */
int _Digits(string symbol="") {
   return(Digits);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   int d = _Digits();

   int counter = 32;

   // Symbole erzeugen
   for (int i=0; i < counter; i++) {
      string symbol         = "MyFX E~"+ StringPadLeft(i+1, 3, "0") +".";
      string description    = "MyFX Example MA "+ StringPadLeft(i+1, 3, "0") +"."+ TimeToStr(GetLocalTime(), TIME_FULL);
      string groupName      = "MyFX Example "+ i;
      int    digits         = 2;
      string baseCurrency   = "USD";
      string marginCurrency = "USD";
      string serverName     = "MyFX-Testresults";
      int id = CreateSymbol(symbol, description, groupName, digits, baseCurrency, marginCurrency, serverName);

      debug("onStart()  id="+ id);

      if (id < 0) return(SetLastError(history.GetLastError()));
   }

   return(NO_ERROR);
}
