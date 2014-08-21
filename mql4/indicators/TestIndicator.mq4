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
   int periods = 3;
   int bar     = 1;

   double atr = ixATR(NULL, PERIOD_W1, periods, bar);// throws ERS_HISTORY_UPDATE
      if (atr == EMPTY)                                                   return(last_error);
      if (last_error==ERS_HISTORY_UPDATE) /*&&*/ if (Period()!=PERIOD_W1) SetLastError(NO_ERROR);

   debug("onTick(1)   Tick="+ Tick +"  atr("+ periods +")["+ bar +"]="+ NumberToStr(atr, ".+"));

   return(last_error);
}


/**
 * Ermittelt einen ATR-Value. Die Funktion setzt immer den internen Fehlercode, bei Erfolg also zurück.
 *
 * @param  string symbol    - Symbol    (default: NULL = das aktuelle Symbol   )
 * @param  int    timeframe - Timeframe (default: NULL = der aktuelle Timeframe)
 * @param  int    periods
 * @param  int    offset
 *
 * @return double - ATR-Value oder -1 (EMPTY), falls ein Fehler auftrat
 */
double ixATR(string symbol, int timeframe, int periods, int offset) {// throws ERS_HISTORY_UPDATE
   if (symbol == "0")         // (string) NULL
      symbol = Symbol();

   double atr = iATR(symbol, timeframe, periods, offset);// throws ERS_HISTORY_UPDATE, ERR_TIMEFRAME_NOT_AVAILABLE

   int error = GetLastError();
   if (IsError(error)) {
      if      (timeframe == Period()               ) {                                     return(_EMPTY(catch("ixATR(1)", error))); }    // sollte niemals auftreten
      if      (error == ERR_TIMEFRAME_NOT_AVAILABLE) { if (!IsBuiltinTimeframe(timeframe)) return(_EMPTY(catch("ixATR(2)", error))); }
      else if (error != ERS_HISTORY_UPDATE         ) {                                     return(_EMPTY(catch("ixATR(3)", error))); }

      debug("ixATR(4)", error);
      atr   = 0;
      error = ERS_HISTORY_UPDATE;
   }

   SetLastError(error);
   return(atr);
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
