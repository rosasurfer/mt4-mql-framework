/**
 * TestIndicator
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdlib.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   double atr = iATR(NULL, PERIOD_W1, 14, 0);// throws ERS_HISTORY_UPDATE, ERR_TIMEFRAME_NOT_AVAILABLE

   debug("onTick()   atr(14xW)="+ NumberToStr(atr, ".+"));

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
