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


/**
 * Initialization post-processing hook. Called only if neither the pre-processing hook nor the reason-specific event handler
 * returned with -1 (which signals a hard stop as opposite to a regular error).
 *
 * @return int - error status
 */
int afterInit() {
   if (Tick ==  1) SetCustomLog(GetMqlFilesPath() +"\\presets\\indicator.log");
   if (Tick == 11) SetCustomLog("");

   debug("afterInit(1)  Tick="+ Tick +"  logEnabled="+ __ExecutionContext[EC.logEnabled] +"  logToDebug="+ __ExecutionContext[EC.logToDebugEnabled] +"  logToTerminal="+ __ExecutionContext[EC.logToTerminalEnabled] +"  logToCustom="+ __ExecutionContext[EC.logToCustomEnabled]);
   return(NO_ERROR);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   log("onTick(1)  Tick="+ Tick +"  hello world");
   return(catch("onTick(2)"));
}
