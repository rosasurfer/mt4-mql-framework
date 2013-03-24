/**
 * Averaging Trademanager Strategy
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
extern string StartConditions = "@trend(ALMA:3.5xD1)";               // || @cross(BB(EMA:75xH1))

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int    sequence.id            [];
bool   sequence.isTest        [];
int    sequence.type          [];
int    sequence.direction     [];
double sequence.lotSize       [];
int    sequence.profitTarget  [];
string sequence.startCondition[];
int    sequence.status        [];


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (IsStartSignal())
      Strategy.StartSequence();

   int sequences = ArraySize(sequence.id);
   for (int i=0; i < sequences; i++) {
      Strategy(i);
   }

   //RecordEquity();                                                 // Equity der gesamten Strategie
   return(last_error);
}


/**
 * Managed die angegebene Sequenz.
 *
 * @param  int hSeq - Sequenz-Handle
 *
 * @return bool - Erfolgsstatus
 */
bool Strategy(int hSeq) {
   if (__STATUS_ERROR)
      return(false);

   //UpdateStatus(hSeq);
   //...
   //RecordEquity(hSeq);                                             // Equity der einzelnen Sequenz

   return(!__STATUS_ERROR);
}


/**
 * Signalgeber für Strategy.StartSequence()
 *
 * @return bool - ob ein Signal aufgetreten ist
 */
bool IsStartSignal() {
   if (__STATUS_ERROR)
      return(false);
   return(false);
}


/**
 * Startet eine neue Sequenz.
 *
 * @return bool - Erfolgsstatus
 */
bool Strategy.StartSequence() {
   if (__STATUS_ERROR)
      return(false);
   return(!__STATUS_ERROR);
}
