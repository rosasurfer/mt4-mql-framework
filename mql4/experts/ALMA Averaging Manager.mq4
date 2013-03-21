/**
 * Averaging Trademanager
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <history.mqh>

#include <core/expert.mqh>


///////////////////////////////////////////////////////////////////// Konfiguration /////////////////////////////////////////////////////////////////////

extern double LotSize    = 0.1;
extern int    TakeProfit = 40;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


#define STRATEGY_ID 106                                              // eindeutige ID der Strategie (Bereich 101-1023)


/**
 *
 */
int onTick() {
   UpdateStatus();
   Strategy();
   RecordEquity();
   return(last_error);
}
