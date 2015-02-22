/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>
#include <win32api.mqh>
//#include <iFunctions/iBarShiftNext.mqh>
//#include <iFunctions/iBarShiftPrevious.mqh>
//#include <iFunctions/iPreviousPeriodTimes.mqh>


#import "Expander.Release.dll"
   int   Test();
#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {


   int result = Test();
   debug("onStart()   result="+ result);
   return(catch("onStart(1)"));
}

/*
TODO Build 600+:
----------------
UninitializeReason()
--------------------
- in EXECUTION_CONTEXT speichern
- in InitReason und DeinitReason auftrennen

int init();
int deinit();
int OnInit(int reason);
int OnDeinit(int reason);

int DebugMarketInfo(string location);
int FileReadLines(string filename, string lines[], bool skipEmptyLines);
*/
