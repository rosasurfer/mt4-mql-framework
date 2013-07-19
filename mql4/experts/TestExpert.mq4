/**
 * TestExpert
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
//#include <core/expert.mqh>


//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern string sParameter = "dummy";
extern int    iParameter = 12345;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


#include <timezones.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   datetime time = D'2011.01.03 05:59:59';
   int lastTransition[], nextTransition[];

   if (GetTimezoneTransitions(time, lastTransition, nextTransition)) {
      debug("init()   time="+ DateToStr(time, "w, D.M.Y H:I"));

      if (lastTransition[TR_TIME] >= 0) debug("init()   lastTransition="+ DateToStr(lastTransition[TR_TIME], "w, D.M.Y H:I") +" ("+ ifString(lastTransition[TR_OFFSET]>=0, "+", "") + (lastTransition[TR_OFFSET]/HOURS) +"), DST="+ lastTransition[TR_DST]);
      else                              debug("init()   lastTransition="+ lastTransition[TR_TIME]);

      if (nextTransition[TR_TIME] >= 0) debug("init()   nextTransition="+ DateToStr(nextTransition[TR_TIME], "w, D.M.Y H:I") +" ("+ ifString(nextTransition[TR_OFFSET]>=0, "+", "") + (nextTransition[TR_OFFSET]/HOURS) +"), DST="+ nextTransition[TR_DST]);
      else                              debug("init()   nextTransition="+ nextTransition[TR_TIME]);
   }
   return(0);
}


/**
 * Ermittelt Zeitpunkt und Offset der jeweils nächsten DST-Wechsel der angebenen Zeit.
 *
 * @param  datetime time             - Zeit
 * @param  datetime lastTransition[] - Array zur Aufnahme der letzten Transitionsdaten
 * @param  datetime nextTransition[] - Array zur Aufnahme der nächsten Transitionsdaten
 *
 * @return bool - Erfolgsstatus
 *
 *
 * Datenformat:
 * ------------
 *  transition[TR_TIME  ] - GMT-Zeitpunkt des Wechsels oder -1, wenn der Wechsel unbekannt ist
 *  transition[TR_OFFSET] - GMT-Offset nach dem Wechsel
 *  transition[TR_DST   ] - ob nach dem Wechsel DST gilt oder nicht
 */
bool GetTimezoneTransitions(datetime time, int &lastTransition[], int &nextTransition[]) {
   if (time < 0)              return(_false(catch("GetTimezoneTransitions(1)   invalid parameter time = "+ time +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (time >= D'2038.01.01') return(_false(catch("GetTimezoneTransitions(2)   too large parameter time = '"+ DateToStr(time, "w, D.M.Y H:I") +"' (not supported)", ERR_INVALID_FUNCTION_PARAMVALUE)));
   /**
    * Logik:
    * ------
    *  if      (datetime < TR_TO_DST) offset = STD_OFFSET;     // Normalzeit zu Jahresbeginn
    *  else if (datetime < TR_TO_STD) offset = DST_OFFSET;     // DST
    *  else                           offset = STD_OFFSET;     // Normalzeit zu Jahresende
    *
    *
    * Szenarien:                           Wechsel zu DST (TR_TO_DST)              Wechsel zu Normalzeit (TR_TO_STD)
    * ----------                           ----------------------------------      ----------------------------------
    *  kein Wechsel, ständig Normalzeit:   -1                      DST_OFFSET      -1                      STD_OFFSET      // durchgehend Normalzeit
    *  kein Wechsel, ständig DST:          -1                      DST_OFFSET      INT_MAX                 STD_OFFSET      // durchgehend DST
    *  1 Wechsel zu DST:                   1975.04.11 00:00:00     DST_OFFSET      INT_MAX                 STD_OFFSET      // Jahr beginnt mit Normalzeit und endet mit DST
    *  1 Wechsel zu Normalzeit:            -1                      DST_OFFSET      1975.11.01 00:00:00     STD_OFFSET      // Jahr beginnt mit DST und endet mit Normalzeit
    *  2 Wechsel:                          1975.04.01 00:00:00     DST_OFFSET      1975.11.01 00:00:00     STD_OFFSET      // Normalzeit -> DST -> Normalzeit
    */
   int y=TimeYear(time), i, iMin=0, iMax=2037-1970;
   datetime toDST, toSTD;


   // letzter Wechsel
   if (ArraySize(lastTransition) < 3)
      ArrayResize(lastTransition, 3);
   ArrayInitialize(lastTransition, 0);

   i = y-1970;
   while (true) {
      if (i < iMin) { lastTransition[TR_TIME] = -1; break; }

      toDST = transitions.Europe_Minsk[i][TR_TO_DST.gmt];
      toSTD = transitions.Europe_Minsk[i][TR_TO_STD.gmt];

      if (time >= toSTD) /*&&*/ if (toSTD != -1) { lastTransition[TR_TIME] = toSTD; lastTransition[TR_OFFSET] = transitions.Europe_Minsk[i][STD_OFFSET]; lastTransition[TR_DST] = false; break; }
      if (time >= toDST) /*&&*/ if (toDST != -1) { lastTransition[TR_TIME] = toDST; lastTransition[TR_OFFSET] = transitions.Europe_Minsk[i][DST_OFFSET]; lastTransition[TR_DST] = true;  break; }

      i--;        // letzter Wechsel war früher
   }


   // nächster Wechsel
   if (ArraySize(nextTransition) < 3)
      ArrayResize(nextTransition, 3);
   ArrayInitialize(nextTransition, 0);

   i = y-1970;
   while (true) {
      if (i > iMax) { nextTransition[TR_TIME] = -1; break; }

      toDST = transitions.Europe_Minsk[i][TR_TO_DST.gmt];
      toSTD = transitions.Europe_Minsk[i][TR_TO_STD.gmt];

      if (time < toDST)                            { nextTransition[TR_TIME] = toDST; nextTransition[TR_OFFSET] = transitions.Europe_Minsk[i][DST_OFFSET]; nextTransition[TR_DST] = true;  break; }
      if (time < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[TR_TIME] = toSTD; nextTransition[TR_OFFSET] = transitions.Europe_Minsk[i][STD_OFFSET]; nextTransition[TR_DST] = false; break; }

      i++;        // nächster Wechsel ist später
   }
   return(true);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   return(last_error);

   int iNulls[];
   catch(NULL);
   GetTimezoneTransitions(NULL, iNulls, iNulls);
}
