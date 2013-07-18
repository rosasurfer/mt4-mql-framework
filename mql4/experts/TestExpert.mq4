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
   datetime time = D'2013.11.03 05:59:59';
   datetime lastTransition, nextTransition;
   int      lastOffset, nextOffset;

   if (GetTimezoneTransitions(time, lastTransition, lastOffset, nextTransition, nextOffset)) {
      debug("init()   time="+ DateToStr(time, "w, D.M.Y H:I"));
      if (lastTransition >= 0) debug("init()   lastTransition="+ DateToStr(lastTransition, "w, D.M.Y H:I") +" ("+ (lastOffset/HOURS) +")");
      if (nextTransition >= 0) debug("init()   nextTransition="+ DateToStr(nextTransition, "w, D.M.Y H:I") +" ("+ (nextOffset/HOURS) +")");
   }
   return(0);
}


/**
 * Ermittelt Zeitpunkt und Offset der jeweils nächsten DST-Wechsel der angebenen Zeit.
 *
 * @param  datetime  time           - Zeit
 * @param  datetime &lastTransition - Zeitpunkt des letzten DST-Wechsels oder -1, wenn der letzte Wechsel unbekannt ist
 * @param  int      &lastOffset     - GMT-Offset seit dem letzten Wechsel (der aktuelle Offset)
 * @param  datetime &nextTransition - Zeitpunkt des nächsten DST-Wechsels oder -1, wenn der nächste Wechsel unbekannt ist
 * @param  int      &nextOffset     - GMT-Offset nach dem nächsten Wechsel
 *
 * @return bool - Erfolgsstatus
 */
bool GetTimezoneTransitions(datetime time, datetime &lastTransition, int &lastOffset, datetime &nextTransition, int &nextOffset) {
   if (time < 0)              return(_false(catch("GetTimezoneTransitions(1)   invalid parameter time = "+ time +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (time >= D'2038.01.01') return(_false(catch("GetTimezoneTransitions(2)   illegal parameter time = '"+ DateToStr(time, "w, D.M.Y H:I") +"' (not supported)", ERR_INVALID_FUNCTION_PARAMVALUE)));
   /**
    * Logik:
    * ------
    *  if      (datetime < TR_TO_DST) offset = STD_OFFSET;     // Normalzeit zu Jahresbeginn
    *  else if (datetime < TR_TO_STD) offset = DST_OFFSET;     // DST
    *  else                           offset = STD_OFFSET;     // Normalzeit zu Jahresende
    *
    *
    * Szenarien:                       Wechsel zu DST (TR_TO_DST)                Wechsel zu Normalzeit (TR_TO_STD)
    * ----------                       ----------------------------------        ----------------------------------
    *  kein Wechsel, Normalzeit:       -1                      DST_OFFSET        -1                      STD_OFFSET        // das ganze Jahr Normalzeit
    *  kein Wechsel, DST:              -1                      DST_OFFSET        INT_MAX                 STD_OFFSET        // das ganze Jahr DST
    *  1 Wechsel zu DST:               1975.04.11 00:00:00     DST_OFFSET        INT_MAX                 STD_OFFSET        // das Jahr beginnt mit Normalzeit und endet mit DST
    *  1 Wechsel zu Normalzeit:        -1                      DST_OFFSET        1975.11.01 00:00:00     STD_OFFSET        // das Jahr beginnt mit DST und endet mit Normalzeit
    *  2 Wechsel:                      1975.04.01 00:00:00     DST_OFFSET        1975.11.01 00:00:00     STD_OFFSET        // Normalzeit -> DST -> Normalzeit
    */
   int y=TimeYear(time), i, iMin=0, iMax=2037-1970;
   datetime toDST, toSTD;


   // letzten Wechsel detektieren
   i = y-1970;
   while (true) {
      if (i < iMin) { lastTransition = -1; break; }

      toDST = transitions.America_New_York[i][TR_TO_DST.gmt];
      toSTD = transitions.America_New_York[i][TR_TO_STD.gmt];

      if (time >= toSTD) /*&&*/ if (toSTD != -1) { lastTransition = toSTD; lastOffset = transitions.America_New_York[i][STD_OFFSET]; break; }
      if (time >= toDST) /*&&*/ if (toDST != -1) { lastTransition = toDST; lastOffset = transitions.America_New_York[i][DST_OFFSET]; break; }

      i--;        // letzter Wechsel war früher
   }


   // nächsten Wechsel detektieren
   i = y-1970;
   while (true) {
      if (i > iMax) { nextTransition = -1; break; }

      toDST = transitions.America_New_York[i][TR_TO_DST.gmt];
      toSTD = transitions.America_New_York[i][TR_TO_STD.gmt];

      if (time < toDST)                            { nextTransition = toDST; nextOffset = transitions.America_New_York[i][DST_OFFSET]; break; }
      if (time < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition = toSTD; nextOffset = transitions.America_New_York[i][STD_OFFSET]; break; }

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
   catch("start()");
}
