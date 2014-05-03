/**
 * LFX.ExecuteTradeCmd
 *
 * Script, daß intern zur Ausführung von zwischen den Terminals verschickten TradeCommands benutzt wird. Parameter werden per QuickChannel übergeben.
 * Ein manueller Aufruf ist nicht möglich.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/script.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   debug("onStart()   running");
   return(last_error);
}
