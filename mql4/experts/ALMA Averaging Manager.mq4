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
extern string StartConditions = "@trend(ALMA:3.5xD1)";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int    sequence.id            [1];
bool   sequence.isTest        [1];
int    sequence.type          [1];
int    sequence.direction     [1];
double sequence.lotSize       [1];
int    sequence.profitTarget  [1];
string sequence.startCondition[1];
int    sequence.status        [1];


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (sequence.status[0] == STATUS_STOPPED)
      return(NO_ERROR);

   // (1) Sequenz wartet entweder auf Startsignal...
   if (sequence.status[0] == STATUS_UNINITIALIZED) {
      if (IsStartSignal()) StartSequence();
   }

   // (2) ...oder läuft
   else if (UpdateStatus()) {
      if (IsStopSignal())  StopSequence();
   }

   // (3) Equity-Kurve aufzeichnen
   if (sequence.status[0] > STATUS_UNINITIALIZED) {
      RecordEquity();
   }

   return(last_error);
}
