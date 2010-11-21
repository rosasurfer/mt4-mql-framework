/**
 * Zeichnet den Balance-Verlauf eines Accounts.
 */
#include <stdlib.mqh>


#property indicator_separate_window

#property indicator_buffers 1

#property indicator_color1  Blue
#property indicator_width1  2


bool init       = false;
int  init_error = ERR_NO_ERROR;


////////////////////////////////////////////////////////////////// User Variablen ////////////////////////////////////////////////////////////////

extern int account = 0;    // Account, dessen Balance angezeigt werden soll (default: der aktuelle Account)

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double Balance[];


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true;
   init_error = ERR_NO_ERROR;

   // ERR_TERMINAL_NOT_YET_READY abfangen
   if (!GetAccountNumber()) {
      init_error = stdlib_GetLastError();
      return(init_error);
   }


   SetIndexBuffer(0, Balance);
   SetIndexLabel (0, "Balance");
   SetIndexStyle (0, DRAW_LINE);

   IndicatorDigits(2);

   // nach Recompilation statische Arrays zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      if (Bars > 0)
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
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init) {                                      // Aufruf nach erstem init()
      init = false;
      if (init_error != ERR_NO_ERROR)               return(0);
   }
   else if (init_error != ERR_NO_ERROR) {           // Aufruf nach Tick
      if (init_error != ERR_TERMINAL_NOT_YET_READY) return(0);
      if (init()     != ERR_NO_ERROR)               return(0);
   }


   if (account == 0)
      account = GetAccountNumber();

   int UnchangedBars = IndicatorCounted();

   if (UnchangedBars == 0) {                             // 1. Aufruf oder nach Data-Pumping: alles neu berechnen
      iBalanceSeries(account, Balance);
   }
   else {
      for (int i=Bars-UnchangedBars; i >= 0; i--) {      // nur fehlende Werte neu berechnen
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
 * @param int     account  - Account, für den der Indikator berechnet werden soll
 * @param double& lpBuffer - Zeichenpuffer, muß dem aktuellen Chart entsprechend dimensioniert sein
 * @param int     offset   - Chart-Offset des zu berechnenden Wertes (Barindex)
 *
 * @return int - Fehlerstatus
 *
 * NOTE:    Die einzelnen Werte dieses Indikators hängen von vorhergehenden Werten desselben Indikators ab. Daher vereinfacht
 * -----    und beschleunigt der übergebene Indikatorpuffer die Berechnung einzelner Werte ganz wesentlich.
 */
int iBalance(int account, double& lpBuffer[], int offset) {

   // TODO: zur Vereinfachung wird der Indikator hier noch komplett neuberechnet
   iBalanceSeries(account, lpBuffer);

   return(catch("iBalance()"));
}

