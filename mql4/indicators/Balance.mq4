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
   Tick++;
   if      (init_error!=NO_ERROR)                   ValidBars = 0;
 //else if (last_error==ERR_TERMINAL_NOT_YET_READY) ValidBars = 0;
   else if (last_error!=NO_ERROR                  ) ValidBars = 0;                     // Trat beim letzten Aufruf ein Fehler auf, wird der Indikator neuberechnet.
   else                                             ValidBars = IndicatorCounted();
   ChangedBars = Bars - ValidBars;
   stdlib_onTick(ValidBars);

   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init_error == ERR_TERMINAL_NOT_YET_READY) /*&&*/ if (!init)
      init();
   init = false;
   if (init_error != NO_ERROR)
      return(init_error);

   // Abschluß der Initialisierung nach Terminal-Start prüfen
   if (Bars == 0 || ArraySize(iBufferBalance) == 0) {
      last_error = ERR_TERMINAL_NOT_YET_READY;
      return(last_error);
   }
   last_error = 0;
   // -----------------------------------------------------------------------------


   // vor Neuberechnung alle Indikatorwerte zurücksetzen
   if (ValidBars == 0) {
      ArrayInitialize(iBufferBalance, EMPTY_VALUE);
   }

   // Entweder alle Werte ...
   if (ValidBars == 0) {
      last_error = iBalanceSeries(AccountNumber(), iBufferBalance);
   }
   else {
      // ... oder nur die fehlenden berechnen
      for (int bar=ChangedBars; bar > 0;) {
         bar--;
         last_error = iBalance(AccountNumber(), iBufferBalance, bar);
         if (last_error != NO_ERROR)
            break;
      }
   }

   if (last_error != NO_ERROR)
      log("start()", last_error);

   return(catch("start()"));
}


