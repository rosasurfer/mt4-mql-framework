/**
 * Funktionen zum Verwalten und Bearbeiten von Historydateien (Kursreihen im "history"-Verzeichnis).
 *
 *
 * NOTE: Libraries use predefined variables of the module that called the library.
 */
#property library
#property stacksize 32768

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/library.mqh>
#include <history.mq4>


/**
 * Initialisierung
 *
 * @param  int    type               - Typ des aufrufenden Programms
 * @param  string name               - Name des aufrufenden Programms
 * @param  int    whereami           - ID der vom Terminal ausgeführten Root-Funktion: FUNC_INIT | FUNC_START | FUNC_DEINIT
 * @param  bool   isChart            - Hauptprogramm-Variable IsChart
 * @param  bool   isOfflineChart     - Hauptprogramm-Variable IsOfflineChart
 * @param  int    _iCustom           - Speicheradresse der ICUSTOM-Struktur, falls das laufende Programm ein per iCustom() ausgeführter Indikator ist
 * @param  int    initFlags          - durchzuführende Initialisierungstasks (default: keine)
 * @param  int    uninitializeReason - der letzte UninitializeReason() des aufrufenden Programms
 *
 * @return int - Fehlerstatus
 */
int hstlib_init(int type, string name, int whereami, bool isChart, bool isOfflineChart, int _iCustom, int initFlags, int uninitializeReason) {
   prev_error = last_error;
   last_error = NO_ERROR;

   __TYPE__      |= type;
   __NAME__       = StringConcatenate(name, "::", WindowExpertName());
   __WHEREAMI__   = whereami;
   __InitFlags    = SumInts(__INIT_FLAGS__) | initFlags;
   __LOG_CUSTOM   = __InitFlags & INIT_CUSTOMLOG;                       // (bool) int
   __iCustom__    = _iCustom;                                           // (int) lpICUSTOM
      if (IsTesting())
   __LOG          = Tester.IsLogging();                                 // TODO: !!! bei iCustom(indicator) Status aus aufrufendem Modul übernehmen
   IsChart        = isChart;
   IsOfflineChart = isOfflineChart;


   // globale Variablen re-initialisieren
   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = Round(MathPow(10, Digits<<31>>31));                   PipPoint          = PipPoints;
   Pip            = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   return(catch("hstlib_init()"));
}


/**
 * Deinitialisierung
 *
 * @param  int deinitFlags        - durchzuführende Deinitialisierungstasks (default: keine)
 * @param  int uninitializeReason - der letzte UninitializeReason() des aufrufenden Programms
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: Bei VisualMode=Off und regulärem Testende (Testperiode zu Ende = REASON_UNDEFINED) bricht das Terminal komplexere deinit()-Funktionen
 *       verfrüht und nicht erst nach 2.5 Sekunden ab. Diese deinit()-Funktion wird deswegen u.U. nicht mehr ausgeführt.
 */
int hstlib_deinit(int deinitFlags, int uninitializeReason) {
   __WHEREAMI__  = FUNC_DEINIT;
   __DeinitFlags = SumInts(__DEINIT_FLAGS__) | deinitFlags;
   return(NO_ERROR);
}


/**
 * Gibt den letzten in der Library aufgetretenen Fehler zurück. Der Aufruf dieser Funktion setzt den Fehlercode *nicht* zurück.
 *
 * @return int - Fehlerstatus
 */
int hstlib_GetLastError() {
   return(last_error);
}
