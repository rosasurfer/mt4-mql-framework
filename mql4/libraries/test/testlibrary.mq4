/**
 *
 */
#property library

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/library.mqh>
#include <stdfunctions.mqh>
//#include <stdlib.mqh>


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   return(last_error);
}


/**
 * Wird von Expert::Library::init() bei Init-Cycle im Tester aufgerufen, um die verwendeten globalen Variablen vor dem nächsten
 * Test zurückzusetzen.
 */
void Tester.ResetGlobalLibraryVars() {
}


/**
 *
 */
int ex4_GetIntValue(int value) {
   int b = value + 666;
   return(b);
}


/**
 *
 */
void fn() {
   debug("fn(1)");
   SetLastError(ERR_AUTOMATED_TRADING_DISABLED);
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

   int startTime, endTime, i, n=1000000;
   string result;


   mql_IntToHexStr(0);
   IntToHexStr(0);
   dll_IntToHexStr(0);


   // MQL
   startTime = GetTickCount();
   for (i=0; i < n; i++) {
      result = mql_IntToHexStr(i);
   }
   endTime = GetTickCount();
   debug("onStart(0.1)  mql loop("+ n +") took "+ DoubleToStr((endTime-startTime)/1000., 3) +" sec  0x"+ result);


   // MQL-Library
   startTime = GetTickCount();
   for (i=0; i < n; i++) {
      result = IntToHexStr(i);
   }
   endTime = GetTickCount();
   debug("onStart(0.2)  lib loop("+ n +") took "+ DoubleToStr((endTime-startTime)/1000., 3) +" sec  0x"+ result);


   // DLL
   startTime = GetTickCount();
   for (i=0; i < n; i++) {
      result = dll_IntToHexStr(i);
   }
   endTime = GetTickCount();
   debug("onStart(0.3)  dll loop("+ n +") took "+ DoubleToStr((endTime-startTime)/1000., 3) +" sec  0x"+ result);

   return(catch("onStart(1)"));


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
