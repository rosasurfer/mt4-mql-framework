/**
 *
 */
#property library
#property stacksize 32768

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/library.mqh>
#include <stdlib.mqh>
#include <structs/pewa/EXECUTION_CONTEXT.mqh>


#include <test/teststatic.mqh>


/**
 * Initialisierung
 *
 * @param  int ec[] - EXECUTION_CONTEXT des Hauptmoduls
 *
 * @return int - Fehlerstatus
 */
int testlib.init(/*EXECUTION_CONTEXT*/int ec[]) {
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
   IsChart        =                  (ec.ChartProperties(ec) & CP_CHART   && 1);
   IsOfflineChart =                  (ec.ChartProperties(ec) & CP_OFFLINE && IsChart);
   __LOG          =                   ec.Logging        (ec);
   __LOG_CUSTOM   = (initFlags & INIT_CUSTOMLOG && 1);

   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits<<31>>31));               PipPoint          = PipPoints;
   Pip            = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   return(catch("testlib.init(1)"));
}


/**
 * Wird nur im Tester in library::init() aufgerufen, um alle verwendeten globalen Arrays zurücksetzen zu können (EA-Bugfix).
 */
void Tester.ResetGlobalArrays() {
   ArrayResize(stack.orderSelections, 0);
}


/**
 *
 *
int mql.GetIntValue(int value) {
   int b = value + 666;
   return(b);
}*/


/*
#import "stdlib.dll"
   int dll_GetIntValue(int value);

#import "stdlib.ex4"
   int ex4.GetIntValue(int value);
#import
*/


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 *
int onStart() {

   int result, n=20000000;

   dll_GetIntValue(0);
   mql.GetIntValue(0);
   ex4.GetIntValue(0);


   // DLL
   int startTime = GetTickCount();
   for (int i=0; i < n; i++) {
      result = dll_GetIntValue(i);
   }
   int endTime = GetTickCount();
   debug("onStart(0.1)   dll loop("+ n +") took "+ DoubleToStr((endTime-startTime)/1000., 3) +" sec");


   // MQL
   startTime = GetTickCount();
   for (i=0; i < n; i++) {
      result = mql.GetIntValue(i);
   }
   endTime = GetTickCount();
   debug("onStart(0.2)   mql loop("+ n +") took "+ DoubleToStr((endTime-startTime)/1000., 3) +" sec");


   // MQL-Library
   startTime = GetTickCount();
   for (i=0; i < n; i++) {
      result = ex4.GetIntValue(i);
   }
   endTime = GetTickCount();
   debug("onStart(0.3)   mql loop("+ n +") took "+ DoubleToStr((endTime-startTime)/1000., 3) +" sec");


   //                                                                       Toshiba Satellite     Toshiba Portege
   // Build 225
   // MetaTrader::TestScript::onStart(0.1)   dll      loop(20.000.000) took     1.711 sec             0.897 sec
   // MetaTrader::TestScript::onStart(0.2)   mql      loop(20.000.000) took     3.312 sec             1.630 sec
   // MetaTrader::TestScript::onStart(0.3)   mql::lib loop(20.000.000) took    61.640 sec            23.931 sec

   // Build 500
   // MetaTrader::TestScript::onStart(0.1)   dll      loop(20.000.000) took     4.738 sec             3.315 sec
   // MetaTrader::TestScript::onStart(0.2)   mql      loop(20.000.000) took     3.231 sec             1.642 sec
   // MetaTrader::TestScript::onStart(0.3)   mql::lib loop(20.000.000) took    73.203 sec            32.370 sec

   return(last_error);
}*/
