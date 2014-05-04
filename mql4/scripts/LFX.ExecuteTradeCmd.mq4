/**
 * LFX.ExecuteTradeCmd
 *
 * Script, daß nur intern zur Ausführung von zwischen den Terminals verschickten TradeCommands benutzt wird. Ein manueller Aufruf ist nicht möglich.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/script.mqh>

#include <lfx.mqh>
#include <win32api.mqh>
#include <MT4iQuickChannel.mqh>
#include <core/script.ParameterProvider.mqh>


//////////////////////////////////////////////////////////////////////  Scriptparameter (Übergabe per QickChannel)  ///////////////////////////////////////////////////////////////////////

string command = "";

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Parameter einlesen
   string names[], values[];
   int size = GetScriptParameters(names, values);
   if (size == -1) return(last_error);
   if (size ==  0) return(catch("onInit(1)   missing script parameters", ERR_INVALID_INPUT_PARAMVALUE));

   for (int i=0; i < size; i++) {
      if (names[i] == "command") {
         command = values[i];
         break;
      }
   }
   if (i >= size) return(catch("onInit(2)   missing script parameter 'command'", ERR_INVALID_INPUT_PARAMVALUE));


   // (2) Parameter validieren
   debug("onInit()   command=\""+ command +"\"");



   return(catch("onInit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {


   // (2) TradeCommands ausführen
   return(last_error);
}
