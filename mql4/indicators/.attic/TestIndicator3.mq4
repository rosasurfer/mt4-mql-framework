/**
 *
 */
#property indicator_chart_window
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


#import "rsfExpander.Release.dll"
   bool SubclassWindow(int hWnd);
   bool UnsubclassWindow(int hWnd);
#import


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   int hWnd = ec_hChart(__ExecutionContext);
   SubclassWindow(hWnd);
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   int hWnd = ec_hChart(__ExecutionContext);
   UnsubclassWindow(hWnd);
   return(last_error);
}
