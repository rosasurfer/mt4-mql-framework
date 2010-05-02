/**
 * Zeichnet den Balance-Verlauf eines Accounts.
 */

#include <stdlib.mqh>


#property indicator_separate_window

#property indicator_buffers 1

#property indicator_color1  Blue
#property indicator_width1  2


// Account, dessen Balance angezeigt werden soll (default: der aktuelle Account)
extern int account = 0;


double Balance[];


/**
 *
 */
int init() {
   SetIndexBuffer(0, Balance);
   SetIndexLabel (0, "Balance");
   SetIndexStyle (0, DRAW_LINE);

   IndicatorDigits(2);

   // nach jeder Recompilation statische Arrays zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      ArrayInitialize(Balance, EMPTY_VALUE);
   }

   // nach Parameteränderung sofort start() aufrufen und nicht auf den nächsten Tick warten
   if (UninitializeReason() == REASON_PARAMETERS) {
      start();
      WindowRedraw();
   }

   return(catch("init()"));
}


/**
 *
 */
int start() {
   if (account == 0)
      account = GetAccountNumber();
   if (account <= 0) {                                   // evt. ERR_TERMINAL_NOT_YET_READY
      int error = MathAbs(account);
      account = 0;
      return(error);
   }

   int processedBars = IndicatorCounted();

   if (processedBars == 0) {                             // 1. Aufruf oder nach Data-Pumping: alles neu berechnen
      iBalanceSeries(account, Balance);
   }
   else {
      for (int i=Bars-processedBars; i >= 0; i--) {      // nur fehlende Werte neu berechnen
         iBalance(account, Balance, i);
      }
   }

   //Print("start()  Balance: "+ Balance[0]);
   return(catch("start()"));
}


/**
 * Berechnet den Balancewert am angegebenen Offset des aktuellen Charts und schreibt ihn in den bereitgestellten
 * Indikatorpuffer.
 *
 * NOTE:
 * -----
 * Die einzelnen Werte dieses Indikators hängen von vorhergehenden Werten desselben Indikators ab. Daher vereinfacht
 * und beschleunigt der übergebene Indikatorpuffer die Berechnung einzelner Werte ganz wesentlich.
 *
 * @param int     account - Account, für den der Indikator berechnet werden soll
 * @param double& iBuffer - Zeichenpuffer, muß dem aktuellen Chart entsprechend dimensioniert sein
 * @param int     offset  - Chart-Offset des zu berechnenden Wertes (Barindex)
 *
 * @return int - Fehlerstatus
 */
int iBalance(int account, double& iBuffer[], int offset) {

   // TODO: zur Vereinfachung wird der Indikator hier noch komplett neuberechnet
   iBalanceSeries(account, iBuffer);

   return(catch("iBalance()"));
}

