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
#include <structs.mqh>
#include <test/teststatic.mqh>


/**
 * Initialisierung
 *
 * @param  int ec[] - EXECUTION_CONTEXT des Hauptmoduls
 *
 * @return int - Fehlerstatus
 */
int testlib_init(/*EXECUTION_CONTEXT*/int ec[]) {
   prev_error = last_error;
   last_error = NO_ERROR;

   // (1) Context in die Library kopieren
   ArrayCopy(__ExecutionContext, ec);
   __lpSuperContext = ec.lpSuperContext(ec);


   // (2) globale Variablen (re-)initialisieren
   int initFlags = ec.InitFlags(ec) | SumInts(__INIT_FLAGS__);

   __TYPE__      |=                   ec.Type           (ec);
   __NAME__       = StringConcatenate(ec.Name           (ec), "::", WindowExpertName());
   __WHEREAMI__   =                   ec.Whereami       (ec);
   IsChart        =             _bool(ec.ChartProperties(ec) & CP_CHART);
   IsOfflineChart =                   ec.ChartProperties(ec) & CP_OFFLINE && IsChart;
   __LOG          =                   ec.Logging        (ec);
   __LOG_CUSTOM   = _bool(initFlags & INIT_CUSTOMLOG);

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
