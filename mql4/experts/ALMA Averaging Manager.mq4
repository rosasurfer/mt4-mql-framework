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
   return(last_error);
}
