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


#import "Expander.Release.dll"

#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   RecordEquity();
   return(last_error);



   int hSet = HistorySet.Get(Symbol());
   debug("onStart()  hSet = "+ hSet);
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

   string symbol      = GetAccountNumber() +".EQ";
   string description = "Account Equity #"+ GetAccountNumber();
   int    digits      = 2;

   int hSet = HistorySet.Get(symbol);
   debug("RecordEquity()  hSet = "+ hSet);
   if (!hSet) return(!SetLastError(history.GetLastError()));            // Fehler

   /*
   static int hSet;
   if (!hSet) {
      string symbol      = GetAccountNumber() +".EQ";
      string description = "Account Equity #"+ GetAccountNumber();
      int    digits      = 2;

      hSet = HistorySet.FindBySymbol(symbol);
      if (!hSet) return(!SetLastError(history.GetLastError()));            // Fehler

      if (hSet == -1) {                                                    // HistorySet nicht gefunden
         hSet = HistorySet.Create.Old(symbol, description, digits);
         if (hSet <= 0) return(!SetLastError(history.GetLastError()));
      }
      else if (!HistorySet.Reset(hSet)) return(!SetLastError(history.GetLastError()));
   }

   double equity = AccountEquity()-AccountCredit();

   if (HistorySet.AddTick(hSet, Tick.Time, equity, flags))
      return(true);
   */
   return(!SetLastError(history.GetLastError()));
}


/**
 * @return int - Fehlerstatus
 */
int afterDeinit() {
   history.CloseFiles(true);
   return(NO_ERROR);
}
