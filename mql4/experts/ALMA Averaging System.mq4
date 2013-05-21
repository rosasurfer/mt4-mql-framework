/**
 * Averaging Trademanager Strategy
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/expert.mqh>

#include <Scaling/define.mqh>
#include <Scaling/functions.mqh>


///////////////////////////////////////////////////////////////////// Konfiguration /////////////////////////////////////////////////////////////////////

extern double LotSize         = 0.1;                                 // LotSize der ersten Position
extern int    ProfitTarget    = 40;                                  // ProfitTarget der ersten Position in Pip
extern string StartConditions = "@trend(ALMA:3xD1)";                 // || @bollinger(EMA:75xH1)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int    trade.id            [];
bool   trade.isTest        [];
int    trade.type          [];
int    trade.direction     [];
double trade.lotSize       [];
int    trade.profitTarget  [];
string trade.startCondition[];
int    trade.status        [];


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (IsStartSignal())
      Strategy.StartTrade();

   int trades = ArraySize(trade.id);
   for (int i=0; i < trades; i++) {
      Strategy(i);
   }

   //RecordEquity();                                                 // Gesamt-Equity
   return(last_error);
}


/**
 * Managed den angegebenen Trade.
 *
 * @param  int hTrade - Trade-Handle
 *
 * @return bool - Erfolgsstatus
 */
bool Strategy(int hTrade) {
   if (__STATUS_ERROR)
      return(false);

   //UpdateStatus(hTrade);
   //...
   //RecordEquity(hTrade);                                           // Trade-Equity

   return(!__STATUS_ERROR);
}


/**
 * Signalgeber für Strategy.StartTrade()
 *
 * @return bool - ob ein Signal aufgetreten ist
 */
bool IsStartSignal() {
   if (__STATUS_ERROR)
      return(false);
   return(false);
}


/**
 * Fügt der Strategie einen neuen Trade hinzu und startet ihn.
 *
 * @return bool - Erfolgsstatus
 */
bool Strategy.StartTrade() {
   if (__STATUS_ERROR)
      return(false);
   return(!__STATUS_ERROR);
}
