/**
 * Balance-Verlauf des aktuellen Accounts als Linienchart im Indikator-Subfenster
 */
#include <stdlib.mqh>

#property indicator_separate_window

#property indicator_buffers 1
#property indicator_color1  Blue


double iBalance[];


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   if (onInit(T_INDICATOR) != NO_ERROR)
      return(last_error);

   // ERR_TERMINAL_NOT_YET_READY abfangen
   if (!GetAccountNumber())
      return(SetLastError(stdlib_PeekLastError()));

   SetIndexBuffer(0, iBalance);
   SetIndexLabel (0, "Balance");
   IndicatorShortName("Balance");
   IndicatorDigits(2);

   // nach Parameteränderung nicht auf den nächsten Tick warten (nur im "Indicators List" window notwendig)
   if (UninitializeReason() == REASON_PARAMETERS)
      SendTick(false);

   return(catch("init()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // Abschluß der Buffer-Initialisierung überprüfen
   if (ArraySize(iBalance) == 0)                                     // kann bei Terminal-Start auftreten
      return(SetLastError(ERR_TERMINAL_NOT_YET_READY));

   // Alle Werte komplett ...
   if (ValidBars == 0) {
      ArrayInitialize(iBalance, EMPTY_VALUE);      // vor Neuberechnung alte Werte zurücksetzen
      last_error = iAccountBalanceSeries(AccountNumber(), iBalance);
   }
   else {                                          // ... oder nur die fehlenden Werte berechnen
      for (int bar=ChangedBars-1; bar >= 0; bar--) {
         last_error = iAccountBalance(AccountNumber(), iBalance, bar);
         if (last_error != NO_ERROR)
            break;
      }
   }

   return(catch("onTick()"));
}


