/**
 * TestIndicator
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdlib.mqh>
#include <iFunctions/@ATR.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   int periods = 3;
   int bar     = 1;

   double atr = @ATR(NULL, PERIOD_W1, periods, bar);// throws ERS_HISTORY_UPDATE
      if (atr == EMPTY)                                                   return(last_error);
      if (last_error==ERS_HISTORY_UPDATE) /*&&*/ if (Period()!=PERIOD_W1) SetLastError(NO_ERROR);

   debug("onTick(1)   Tick="+ Tick +"  atr("+ periods +")["+ bar +"]="+ NumberToStr(atr, ".+"));

   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 *
int onTick() {
   //debug("onTick(1)");

   string separator      = "";
   int    lpLocalContext = GetBufferAddress(__ExecutionContext);

   iCustom(NULL, Period(), "TestIndicator2",       //
           separator,                              // ________________
           lpLocalContext,                         // __SuperContext__
           0,                                      // iBuffer
           0);                                     // iBar

   int error = GetLastError();
   if (IsError(error))
      return(error);

   error = ec.LastError(__ExecutionContext);
   if (IsError(error))
      return(error);

   return(last_error);
}


#import "struct.EXECUTION_CONTEXT.ex4"
   int ec.LastError(int ec[]);
#import
*/
