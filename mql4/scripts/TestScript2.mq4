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


int equity.hSet;


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   RecordEquity();
   return(last_error);

   RecordEquity(HST_COLLECT_TICKS);
   return(last_error);
}


/**
 * Zeichnet die Equity-Kurve des Accounts auf.
 *
 * @param  int flags - das Schreiben steuernde Flags (default: keine)
 *                     HST_COLLECT_TICKS: sammelt aufeinanderfolgende Ticks und schreibt die Daten erst beim jeweils nächsten BarOpen-Event
 *                     HST_FILL_GAPS:     füllt entstehende Gaps mit dem letzten Schlußkurs vor dem Gap
 *
 * @return bool - Erfolgsstatus
 */
bool RecordEquity(int flags=NULL) {
   if (!equity.hSet) {
      string symbol      = ifString(IsTesting(), "_", "") + GetAccountNumber() +".EQ";
      string description = "Account Equity #"+ GetAccountNumber();
      int    digits      = 2;
      int    format      = 400;
      bool   synthetic   = true;
      equity.hSet = HistorySet.Create(symbol, description, digits, format, synthetic);
      if (!equity.hSet) return(!SetLastError(history.GetLastError()));
   }

   double equity = AccountEquity()-AccountCredit();
   if (!HistorySet.AddTick(equity.hSet, Tick.Time, equity, flags)) return(!SetLastError(history.GetLastError()));

   return(true);
}


/**
 * @return int - Fehlerstatus
 */
int onDeinit() {
   if (equity.hSet != 0) {
      if (!HistorySet.Close(equity.hSet)) return(!SetLastError(history.GetLastError()));
      equity.hSet = NULL;
   }
   return(NO_ERROR);
}
