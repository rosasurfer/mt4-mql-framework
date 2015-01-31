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
   int hChart    = ec.hChart   (ec);

   __TYPE__      |=                   ec.Type    (ec);
   __NAME__       = StringConcatenate(ec.Name    (ec), "::", WindowExpertName());
   __WHEREAMI__   =                   ec.Whereami(ec);
   IsChart        = (hChart != 0);
   __LOG          =                   ec.Logging (ec);
   __LOG_CUSTOM   = (initFlags & INIT_CUSTOMLOG && 1);

   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
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
 */
int ex4_GetIntValue(int value) {
   int b = value + 666;
   return(b);
}


/*
#import "Expander.dll"
   int dll_GetIntValue(int value);
#import "test/testlibrary.ex4"
   int ex4_GetIntValue(int value);
#import


/**
 *
 *
int mql_GetIntValue(int value) {
   int b = value + 333;
   return(b);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 *
int onStart() {

   int result, n=20000000;

   dll_GetIntValue(0);
   mql_GetIntValue(0);
   ex4_GetIntValue(0);


   // DLL
   int startTime = GetTickCount();
   for (int i=0; i < n; i++) {
      result = dll_GetIntValue(i);
   }
   int endTime = GetTickCount();
   debug("onStart(0.1)  dll loop("+ n +") took "+ DoubleToStr((endTime-startTime)/1000., 3) +" sec");


   // MQL
   startTime = GetTickCount();
   for (i=0; i < n; i++) {
      result = mql_GetIntValue(i);
   }
   endTime = GetTickCount();
   debug("onStart(0.2)  mql loop("+ n +") took "+ DoubleToStr((endTime-startTime)/1000., 3) +" sec");


   // MQL-Library
   startTime = GetTickCount();
   for (i=0; i < n; i++) {
      result = ex4_GetIntValue(i);
   }
   endTime = GetTickCount();
   debug("onStart(0.3)  lib loop("+ n +") took "+ DoubleToStr((endTime-startTime)/1000., 3) +" sec");

   return(last_error);


   // 20.000.000 Durchläufe:
   // +-----------+----------+-------------------+-------------------------+------------+
   // |           |          | Toshiba Satellite |     Toshiba Portege     |  VPS       |
   // +-----------+----------+-------------------+------------+------------+------------+
   // | Build 225 | dll      |         1.711 sec |  0.897 sec |            |            |
   // |           | mql      |         3.312 sec |  1.607 sec |            |            |
   // |           | mql::lib |        61.640 sec | 23.931 sec | 29.281 sec |            |
   // +-----------+----------+-------------------+------------+------------+------------+
   // | Build 500 | dll      |         4.738 sec |  3.198 sec |  3.323 sec |  4.375 sec |
   // |           | mql      |         3.231 sec |  1.981 sec |  2.074 sec |  2.688 sec |
   // |           | mql::lib |        73.203 sec | 27.472 sec | 35.959 sec | 38.234 sec |
   // +-----------+----------+-------------------+------------+------------+------------+
   // | Build 670 | dll      |                   |  3.479 sec |            |            |
   // |           | mql      |                   |  1.888 sec |            |            |
   // |           | mql::lib |                   | 28.783 sec | 31.809 sec |            |
   // +-----------+----------+-------------------+------------+------------+------------+
   //
   // Auswertung:
   // -----------
   //  - Build 225 war am schnellsten. Nicht verwunderlich, da der Code ungeschützt und nicht in einem Protection-Wrapper läuft.
   //  - Die Geschwindigkeit aller getesteten geschützten Builds (ab 500) ist annähernd gleich.
   //  - MQL- und MQL-Library-Aufrufe sind in den getesteten geschützten Builds ca. 25% langsamer als im ungeschützten Build 225.
   //  - DLL-Aufrufe sind in den getesteten geschützten Builds erheblich langsamer, von fast doppelt so schnell wie reine MQL-Aufrufe
   //    in Build 225 über 35% langsamer in Build 500 zu 45% langsamer in Build 670. Trotzdem sind sie in Build 670 immer noch 8-10 mal
   //    schneller als MQL-Library-Aufrufe (in Build 225 waren sie noch bis zu 25 mal schneller).
   //
   // Fazit:
   // ------
   //  - MQL-Libraries sind möglichst zu vermeiden und durch DLL-Aufrufe zu ersetzen.
   //  - Ob eine Funktionalität in reinem MQL oder in einer DLL schneller ist, muß von Fall zu Fall geprüft werden.
   //    Innerhalb einer DLL kann der Geschwindigkeitsverlust zu reinem MQL in den ungeschützten Builds mit Leichtigkeit wettgemacht werden.
}*/
