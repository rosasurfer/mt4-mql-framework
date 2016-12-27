/**
 * Balance-Verlauf des aktuellen Accounts als Linienchart im Indikator-Subfenster
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
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
int onInit() {
   // ERS_TERMINAL_NOT_YET_READY abfangen
   if (!GetAccountNumber()) return(ec_MqlError(__ExecutionContext));

   SetIndexBuffer(0, iBalance);
   SetIndexLabel (0, "Balance");
   IndicatorShortName("Balance");
   IndicatorDigits(2);

   return(catch("onInit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 *
 * @throws ERS_TERMINAL_NOT_YET_READY
 */
int onTick() {
   // (1) IndicatorBuffer entsprechend ShiftedBars synchronisieren
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(iBalance, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // Abschluß der Buffer-Initialisierung überprüfen
   if (ArraySize(iBalance) == 0)                                     // kann bei Terminal-Start auftreten
      return(debug("onTick(1)  size(iBalance) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // Alle Werte komplett ...
   if (!ValidBars) {
      ArrayInitialize(iBalance, EMPTY_VALUE);                        // vor Neuberechnung alte Werte zurücksetzen (löscht Garbage hinter MaxValues)
      if (IsError(iAccountBalanceSeries(GetAccountNumber(), iBalance)))
         return(ec_MqlError(__ExecutionContext));
   }
   else {                                                            // ... oder nur die fehlenden Werte berechnen
      for (int bar=ChangedBars-1; bar >= 0; bar--) {
         if (IsError(iAccountBalance(GetAccountNumber(), iBalance, bar)))
            return(ec_MqlError(__ExecutionContext));
      }
   }

   return(last_error);
}


