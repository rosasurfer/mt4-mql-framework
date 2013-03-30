/**
 * Averaging Trademanager
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <history.mqh>

#include <core/expert.mqh>
#include <Scaling/define.mqh>
#include <Scaling/functions.mqh>


///////////////////////////////////////////////////////////////////// Konfiguration /////////////////////////////////////////////////////////////////////

extern double LotSize         = 0.1;                                 // LotSize der ersten Position
extern int    ProfitTarget    = 40;                                  // ProfitTarget der ersten Position in Pip
extern string StartConditions = "@trend(ALMA:3xD1)";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int    trade.id            [1];
bool   trade.isTest        [1];
int    trade.type          [1];
int    trade.direction     [1];
double trade.lotSize       [1];
int    trade.profitTarget  [1];
string trade.startCondition[1];
int    trade.status        [1];


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (trade.status[0] == STATUS_STOPPED)
      return(NO_ERROR);

   // (1) Trade wartet entweder auf Startsignal...
   if (trade.status[0] == STATUS_UNINITIALIZED) {
      if (IsStartSignal()) StartTrade();
   }

   // (2) ...oder läuft
   else if (UpdateStatus()) {
      if (IsStopSignal())  StopTrade();
   }

   // (3) Equity-Kurve aufzeichnen
   if (trade.status[0] != STATUS_UNINITIALIZED) {
      RecordEquity();
   }

   return(last_error);
}


/**
 * Signalgeber für StartTrade()
 *
 * @return bool - ob ein Signal aufgetreten ist
 */
bool IsStartSignal() {
   if (__STATUS_ERROR)
      return(false);
   return(false);
}


/**
 * Signalgeber für StopTrade()
 *
 * @return bool - ob ein Signal aufgetreten ist
 */
bool IsStopSignal() {
   if (__STATUS_ERROR)
      return(false);
   return(false);
}


/**
 * Startet einen neuen Trade.
 *
 * @return bool - Erfolgsstatus
 */
bool StartTrade() {
   if (__STATUS_ERROR)
      return(false);
   return(!__STATUS_ERROR);
}


/**
 * Stoppt den aktuellen Trade.
 *
 * @return bool - Erfolgsstatus
 */
bool StopTrade() {
   if (__STATUS_ERROR)
      return(false);
   return(!__STATUS_ERROR);
}


/**
 * Prüft und synchronisiert die im EA gespeicherten mit den aktuellen Laufzeitdaten.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateStatus() {
   if (__STATUS_ERROR)
      return(false);
   return(!__STATUS_ERROR);
}


/**
 * Zeichnet die Equity-Kurve des Trades auf.
 *
 * @return bool - Erfolgsstatus
 */
bool RecordEquity() {
   if (__STATUS_ERROR)
      return(false);
   return(!__STATUS_ERROR);
}
