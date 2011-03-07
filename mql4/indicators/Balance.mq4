/**
 * Zeigt den Balance-Verlauf des aktuellen Accounts als Linienchart im Indikatorfenster an.
 */
#include <stdlib.mqh>

#property indicator_separate_window
#property indicator_buffers 1

#property indicator_color1  Blue
#property indicator_width1  2


double iBufferBalance[];


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   // ERR_TERMINAL_NOT_YET_READY abfangen
   if (!GetAccountNumber()) {
      init_error = stdlib_GetLastError();
      return(init_error);
   }

   SetIndexBuffer(0, iBufferBalance);
   SetIndexLabel (0, "Balance");
   SetIndexStyle (0, DRAW_LINE);
   IndicatorDigits(2);

   // nach Parameteränderung nicht auf den nächsten Tick warten (nur im "Indicators List" window notwendig)
   if (UninitializeReason() == REASON_PARAMETERS)
      SendTick(false);

   return(catch("init()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   static int error = NO_ERROR;

   // Trat beim letzten Aufruf ein Fehler auf, wird der Indikator neuberechnet.
   Tick++;
   ValidBars   = ifInt(error!=NO_ERROR, 0, IndicatorCounted()); error = NO_ERROR;
   ChangedBars = Bars - ValidBars;
   stdlib_onTick(ValidBars);

   // bei Neuberechnung Indikatorwerte zurücksetzen
   if (ValidBars == 0) {
      ArrayInitialize(iBufferBalance, EMPTY_VALUE);
   }

   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init) {                                      // Aufruf nach erstem init()
      init = false;
      if (init_error != NO_ERROR)                   return(0);
   }
   else if (init_error != NO_ERROR) {               // Aufruf nach Tick
      if (init_error != ERR_TERMINAL_NOT_YET_READY) return(0);
      if (init()     != NO_ERROR)                   return(0);
   }


   // Entweder alle Werte ...
   if (ValidBars == 0) {
      error = iBalanceSeries(AccountNumber(), iBufferBalance);
   }
   else {
      // ... oder nur die fehlenden berechnen
      for (int bar=ChangedBars; bar > 0;) {
         bar--;
         error = iBalance(AccountNumber(), iBufferBalance, bar);
         if (error != NO_ERROR)
            break;
      }
   }

   if (error != NO_ERROR)
      log("start()", error);

   return(catch("start()"));
}


