/**
 * TestScript2
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <history.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   RecordEquity();
   //RecordEquity(HST_CACHE_TICKS);

   return(last_error);
}


/**
 * Zeichnet die Equity-Kurve des Accounts auf.
 *
 * @param  int flags - das Schreiben steuernde Flags (default: keine)
 *                     HST_CACHE_TICKS: speichert aufeinanderfolgende Ticks zwischen und schreibt die Daten beim jeweils nächsten BarOpen-Event
 *                     HST_FILL_GAPS:   füllt entstehende Gaps mit dem letzten Schlußkurs vor dem Gap
 *
 * @return bool - Erfolgsstatus
 */
bool RecordEquity(int flags=NULL) {
   if (IsTesting()) return(true);

   static int hHSet;
   if (!hHSet) {
      string symbol      = ifString(IsTesting(), "_", "") + GetAccountNumber() +".EQ";
      string description = "Account Equity #"+ GetAccountNumber();
      int    digits      = 2;

      hHSet = HistorySet.FindBySymbol(symbol);
      if (!hHSet) return(!SetLastError(history.GetLastError()));           // Fehler

      if (hHSet == -1) {                                                   // HistorySet nicht gefunden
         hHSet = HistorySet.Create(symbol, description, digits);
         if (hHSet <= 0) return(!SetLastError(history.GetLastError()));
      }
      else if (!HistorySet.Reset(hHSet)) return(!SetLastError(history.GetLastError()));
   }

   double equity = AccountEquity()-AccountCredit();

   if (HistorySet.AddTick(hHSet, Tick.Time, equity, flags))
      return(true);
   return(!SetLastError(history.GetLastError()));
}


/**
 * @return int - Fehlerstatus
 */
int afterDeinit() {
   history.CloseFiles(true);
   return(NO_ERROR);
}
