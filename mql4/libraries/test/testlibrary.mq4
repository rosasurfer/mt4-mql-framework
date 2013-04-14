/**
 *
 */
#property library
#property stacksize 32768

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <win32api.mqh>

#include <core/library.mqh>

#include <test/teststatic.mqh>


/**
 * Initialisierung
 *
 * @param  int    type               - Typ des aufrufenden Programms
 * @param  string name               - Name des aufrufenden Programms
 * @param  int    whereami           - ID der vom Terminal ausgeführten Root-Funktion: FUNC_INIT | FUNC_START | FUNC_DEINIT
 * @param  bool   isChart            - Hauptprogramm-Variable IsChart
 * @param  bool   isOfflineChart     - Hauptprogramm-Variable IsOfflineChart
 * @param  bool   loggingEnabled     - Hauptprogramm-Variable __LOG
 * @param  int    lpICUSTOM          - Speicheradresse der ICUSTOM-Struktur, falls das laufende Programm ein per iCustom() ausgeführter Indikator ist
 * @param  int    initFlags          - durchzuführende Initialisierungstasks (default: keine)
 * @param  int    uninitializeReason - der letzte UninitializeReason() des aufrufenden Programms
 *
 * @return int - Fehlerstatus
 */
int testlib_init(int type, string name, int whereami, bool isChart, bool isOfflineChart, bool loggingEnabled, int lpICUSTOM, int initFlags, int uninitializeReason) {
   prev_error = last_error;
   last_error = NO_ERROR;

   __TYPE__      |= type;
   __NAME__       = StringConcatenate(name, "::", WindowExpertName());
   __WHEREAMI__   = whereami;
   __InitFlags    = SumInts(__INIT_FLAGS__) | initFlags;
   IsChart        = isChart;
   IsOfflineChart = isOfflineChart;
   __LOG          = loggingEnabled;
   __LOG_CUSTOM   = _bool(__InitFlags & INIT_CUSTOMLOG);
   __iCustom__    = lpICUSTOM;


   // globale Variablen re-initialisieren
   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits<<31>>31));               PipPoint          = PipPoints;
   Pip            = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   return(catch("testlib_init()"));
}


/**
 * Setzt die globalen Arrays zurück. Wird nur im Tester und in library::init() aufgerufen.
 */
void Tester.ResetGlobalArrays() {
   if (IsTesting()) {
      ArrayResize(stack.orderSelections, 0);
   }
}
