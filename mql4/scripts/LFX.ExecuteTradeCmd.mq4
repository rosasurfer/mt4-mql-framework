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


int    ticket;
string action;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Parameter einlesen
   string names[], values[];
   int size = GetScriptParameters(names, values);
   if (size == -1) return(last_error);
   for (int i=0; i < size; i++) {
      if (names[i] == "command") {
         command = values[i];
         break;
      }
   }
   if (i >= size) return(catch("onInit(1)   missing script parameter (command)", ERR_INVALID_INPUT_PARAMVALUE));

   // Parameter validieren, Format: "LFX.{Ticket}.{Action}", z.B. "LFX.428371265.open"
   if (StringLeft(command, 4) != "LFX.")  return(catch("onInit(2)   invalid parameter command = \""+ command +"\" (prefix)", ERR_INVALID_INPUT_PARAMVALUE));
   int pos = StringFind(command, ".", 4);
   if (pos == -1)                         return(catch("onInit(3)   invalid parameter command = \""+ command +"\" (action)", ERR_INVALID_INPUT_PARAMVALUE));
   string sValue = StringSubstrFix(command, 4, pos-4);
   if (!StringIsDigit(sValue))            return(catch("onInit(4)   invalid parameter command = \""+ command +"\" (ticket)", ERR_INVALID_INPUT_PARAMVALUE));
   ticket = StrToInteger(sValue);
   if (!ticket)                           return(catch("onInit(5)   invalid parameter command = \""+ command +"\" (ticket)", ERR_INVALID_INPUT_PARAMVALUE));
   action = StringToLower(StringSubstr(command, pos+1));
   if (action!="open" && action!="close") return(catch("onInit(6)   invalid parameter command = \""+ command +"\" (action)", ERR_INVALID_INPUT_PARAMVALUE));

   return(catch("onInit(7)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   debug("onStart()   ticket="+ ticket +", action="+ action);

   if (!LFX.GetOrder(ticket, lfxOrder))
      return(last_error);

   LFX_ORDER.toStr(lfxOrder, true);

   return(last_error);
}
