/**
 * TestIndicator
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#property indicator_chart_window

#import "rsfExpander.dll"
   bool SetCustomLogA(int ec[], string filename);
#import


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   string filename = GetMqlFilesPath() +"\\presets\\indicator.log";

   SetCustomLogA(__ExecutionContext, filename);

   log("onTick(1)  Tick="+ Tick +"  hello world");

   //SetCustomLogA(__ExecutionContext, "");

   return(catch("onTick(1)"));
}
