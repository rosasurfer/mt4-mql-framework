/**
 * TestIndicator
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdlib.mqh>

#include <MT4iQuickChannel.mqh>
#include <win32api.mqh>


#import "StdLib.Release.dll"
   bool Test();
#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {

   //bool result = Test();
   //debug("onTick()->Test() => "+ result);
   //debug("onTick()   Tick="+ Tick);

   return(last_error);
}
