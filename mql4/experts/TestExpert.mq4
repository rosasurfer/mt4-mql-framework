/**
 * TestExpert
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/expert.mqh>
#include <stdlib.mqh>
#include <win32api.mqh>


//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern string sParameter = "dummy";
extern int    iParameter = 12345;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   string symbol         = Symbol();
   int    timeframe      = Period();
   string name           = "TestIndicator2";
   string separator      = "";
   int    lpLocalContext = GetBufferAddress(__ExecutionContext);

   static bool done;
   if (!done) {
      int currentThread=GetCurrentThreadId(), uiThread=GetUIThreadId();
      debug("onTick(1)     "+ ifString(currentThread==uiThread, "ui", "  ") +"thread="+ GetCurrentThreadId() +"  ec="+ lpLocalContext +"  Visual="+ IsVisualMode() +"  Testing="+ IsTesting());
      done = true;
   }


   iCustom(symbol, timeframe, name,                //
           separator,                              // ________________
           lpLocalContext,                         // __SuperContext__
           0,                                      // iBuffer
           0);                                     // iBar

   int error = GetLastError();
   if (IsError(error))
      return(catch("onTick(2)", error));

   error = ec.LastError(__ExecutionContext);
   if (IsError(error))
      return(catch("onTick(3)", error));

   return(last_error);
}
