/**
 * SnowRoller-Strategy (2-Sequence-SnowRoller: maximal eine jeweils unabhängige Sequence je Richtung)
 */
#property stacksize 32768

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE, INIT_PIPVALUE, INIT_CUSTOMLOG};
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <win32api.mqh>

#include <core/expert.mqh>
#include <SnowRoller/define.mqh>
#include <SnowRoller/functions.mqh>


///////////////////////////////////////////////////////////////////// Konfiguration /////////////////////////////////////////////////////////////////////

extern /*sticky*/ string Sequence.ID             = "";
extern            int    GridSize                = 20;
extern            double LotSize                 = 0.1;
extern            string StartConditions         = "";
extern            string StopConditions          = "";
extern /*sticky*/ string Sequence.StatusLocation = "";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   return(last_error);
}


/**
 * Unterdrückt unnütze Compilerwarnungen.
 */
void DummyCalls() {
   CheckTrendChange(NULL, NULL, NULL, NULL, NULL, NULL, iNull);
   ConfirmTick1Trade(NULL, NULL);
   CreateEventId();
   CreateSequenceId();
   FindChartSequences(sNulls, iNulls);
   IsSequenceStatus(NULL);
}
