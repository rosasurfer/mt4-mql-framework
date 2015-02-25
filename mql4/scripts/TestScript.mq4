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
#include <iFunctions/iChangedBars.mqh>
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

   int changedBars1 = iChangedBars(NULL, PERIOD_M1, MUTE_ERR_SERIES_NOT_AVAILABLE);
   int changedBars2 = iChangedBars(NULL, PERIOD_M1, MUTE_ERR_SERIES_NOT_AVAILABLE);

   debug("onStart()  changedBars:  1="+ changedBars1 +"  2="+ changedBars2);



   return(catch("onStart(1)"));

   iChangedBars(NULL, NULL);
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
