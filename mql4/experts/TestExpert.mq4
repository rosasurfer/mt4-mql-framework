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
 * Ermittelt Zeitpunkt und Offset der jeweils nächsten DST-Wechsel der angebenen Serverzeit.
 *
 * @param  datetime serverTime       - Serverzeit
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
bool GetTimezoneTransitions(datetime serverTime, int &lastTransition[], int &nextTransition[]) {
   if (serverTime < 0)              return(_false(catch("GetTimezoneTransitions(1)   invalid parameter serverTime = "+ serverTime +" (not a time)", ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (serverTime >= D'2038.01.01') return(_false(catch("GetTimezoneTransitions(2)   too large parameter serverTime = '"+ DateToStr(serverTime, "w, D.M.Y H:I") +"' (unsupported)", ERR_INVALID_FUNCTION_PARAMVALUE)));
   string timezone = GetServerTimezone();
   if (!StringLen(timezone))        return(false);
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
   datetime toDST, toSTD;
   int i, iMax=2037-1970, y=TimeYear(serverTime);


   // letzter Wechsel
   if (ArraySize(lastTransition) < 3)
      ArrayResize(lastTransition, 3);
   ArrayInitialize(lastTransition, 0);
   i = y-1970;

   while (true) {
      if (i < 0)             { lastTransition[TR_TIME] = -1; break; }
      if (timezone == "GMT") { lastTransition[TR_TIME] = -1; break; }

      if (timezone == "America/New_York") {
         toDST = transitions.America_New_York[i][TR_TO_DST.local];
         toSTD = transitions.America_New_York[i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { lastTransition[TR_TIME] = toSTD; lastTransition[TR_OFFSET] = transitions.America_New_York[i][STD_OFFSET]; lastTransition[TR_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { lastTransition[TR_TIME] = toDST; lastTransition[TR_OFFSET] = transitions.America_New_York[i][DST_OFFSET]; lastTransition[TR_DST] = true;  break; }
      }

      else if (timezone == "Europe/Berlin") {
         toDST = transitions.Europe_Berlin   [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Berlin   [i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { lastTransition[TR_TIME] = toSTD; lastTransition[TR_OFFSET] = transitions.Europe_Berlin   [i][STD_OFFSET]; lastTransition[TR_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { lastTransition[TR_TIME] = toDST; lastTransition[TR_OFFSET] = transitions.Europe_Berlin   [i][DST_OFFSET]; lastTransition[TR_DST] = true;  break; }
      }

      else if (timezone == "Europe/Kiev") {
         toDST = transitions.Europe_Kiev     [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Kiev     [i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { lastTransition[TR_TIME] = toSTD; lastTransition[TR_OFFSET] = transitions.Europe_Kiev     [i][STD_OFFSET]; lastTransition[TR_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { lastTransition[TR_TIME] = toDST; lastTransition[TR_OFFSET] = transitions.Europe_Kiev     [i][DST_OFFSET]; lastTransition[TR_DST] = true;  break; }
      }

      else if (timezone == "Europe/London") {
         toDST = transitions.Europe_London   [i][TR_TO_DST.local];
         toSTD = transitions.Europe_London   [i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { lastTransition[TR_TIME] = toSTD; lastTransition[TR_OFFSET] = transitions.Europe_London   [i][STD_OFFSET]; lastTransition[TR_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { lastTransition[TR_TIME] = toDST; lastTransition[TR_OFFSET] = transitions.Europe_London   [i][DST_OFFSET]; lastTransition[TR_DST] = true;  break; }
      }

      else if (timezone == "Europe/Minsk") {
         toDST = transitions.Europe_Minsk    [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Minsk    [i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { lastTransition[TR_TIME] = toSTD; lastTransition[TR_OFFSET] = transitions.Europe_Minsk    [i][STD_OFFSET]; lastTransition[TR_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { lastTransition[TR_TIME] = toDST; lastTransition[TR_OFFSET] = transitions.Europe_Minsk    [i][DST_OFFSET]; lastTransition[TR_DST] = true;  break; }
      }

      else if (timezone == "FXT") {
         toDST = transitions.FXT             [i][TR_TO_DST.local];
         toSTD = transitions.FXT             [i][TR_TO_STD.local];
         if (serverTime >= toSTD) /*&&*/ if (toSTD != -1) { lastTransition[TR_TIME] = toSTD; lastTransition[TR_OFFSET] = transitions.FXT             [i][STD_OFFSET]; lastTransition[TR_DST] = false; break; }
         if (serverTime >= toDST) /*&&*/ if (toDST != -1) { lastTransition[TR_TIME] = toDST; lastTransition[TR_OFFSET] = transitions.FXT             [i][DST_OFFSET]; lastTransition[TR_DST] = true;  break; }
      }

      else return(_false(catch("GetTimezoneTransitions(3)   unknown timezone \""+ timezone +"\"", ERR_INVALID_TIMEZONE_CONFIG)));

      i--;        // letzter Wechsel war früher
   }


   // nächster Wechsel
   if (ArraySize(nextTransition) < 3)
      ArrayResize(nextTransition, 3);
   ArrayInitialize(nextTransition, 0);
   i = y-1970;

   while (true) {
      if (i > iMax)          { nextTransition[TR_TIME] = -1; break; }
      if (timezone == "GMT") { nextTransition[TR_TIME] = -1; break; }

      if (timezone == "America/New_York") {
         toDST = transitions.America_New_York[i][TR_TO_DST.local];
         toSTD = transitions.America_New_York[i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[TR_TIME] = toDST; nextTransition[TR_OFFSET] = transitions.America_New_York[i][DST_OFFSET]; nextTransition[TR_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[TR_TIME] = toSTD; nextTransition[TR_OFFSET] = transitions.America_New_York[i][STD_OFFSET]; nextTransition[TR_DST] = false; break; }
      }

      else if (timezone == "Europe/Berlin") {
         toDST = transitions.Europe_Berlin   [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Berlin   [i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[TR_TIME] = toDST; nextTransition[TR_OFFSET] = transitions.Europe_Berlin   [i][DST_OFFSET]; nextTransition[TR_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[TR_TIME] = toSTD; nextTransition[TR_OFFSET] = transitions.Europe_Berlin   [i][STD_OFFSET]; nextTransition[TR_DST] = false; break; }
      }

      else if (timezone == "Europe/Kiev") {
         toDST = transitions.Europe_Kiev     [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Kiev     [i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[TR_TIME] = toDST; nextTransition[TR_OFFSET] = transitions.Europe_Kiev     [i][DST_OFFSET]; nextTransition[TR_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[TR_TIME] = toSTD; nextTransition[TR_OFFSET] = transitions.Europe_Kiev     [i][STD_OFFSET]; nextTransition[TR_DST] = false; break; }
      }

      else if (timezone == "Europe/London") {
         toDST = transitions.Europe_London   [i][TR_TO_DST.local];
         toSTD = transitions.Europe_London   [i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[TR_TIME] = toDST; nextTransition[TR_OFFSET] = transitions.Europe_London   [i][DST_OFFSET]; nextTransition[TR_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[TR_TIME] = toSTD; nextTransition[TR_OFFSET] = transitions.Europe_London   [i][STD_OFFSET]; nextTransition[TR_DST] = false; break; }
      }

      else if (timezone == "Europe/Minsk") {
         toDST = transitions.Europe_Minsk    [i][TR_TO_DST.local];
         toSTD = transitions.Europe_Minsk    [i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[TR_TIME] = toDST; nextTransition[TR_OFFSET] = transitions.Europe_Minsk    [i][DST_OFFSET]; nextTransition[TR_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[TR_TIME] = toSTD; nextTransition[TR_OFFSET] = transitions.Europe_Minsk    [i][STD_OFFSET]; nextTransition[TR_DST] = false; break; }
      }

      else if (timezone == "FXT") {
         toDST = transitions.FXT             [i][TR_TO_DST.local];
         toSTD = transitions.FXT             [i][TR_TO_STD.local];
         if (serverTime < toDST)                            { nextTransition[TR_TIME] = toDST; nextTransition[TR_OFFSET] = transitions.FXT             [i][DST_OFFSET]; nextTransition[TR_DST] = true;  break; }
         if (serverTime < toSTD) /*&&*/ if (toSTD!=INT_MAX) { nextTransition[TR_TIME] = toSTD; nextTransition[TR_OFFSET] = transitions.FXT             [i][STD_OFFSET]; nextTransition[TR_DST] = false; break; }
      }

      else return(_false(catch("GetTimezoneTransitions(4)   unknown timezone \""+ timezone +"\"", ERR_INVALID_TIMEZONE_CONFIG)));

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
