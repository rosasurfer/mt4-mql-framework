/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_DOESNT_REQUIRE_BARS };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <win32api.mqh>
//#include <iFunctions/iBarShiftNext.mqh>
//#include <iFunctions/iBarShiftPrevious.mqh>
#include <iFunctions/iChangedBars.mqh>
//#include <iFunctions/iPreviousPeriodTimes.mqh>



#import "Expander.Release.dll"
#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   string values[3], value;
   values[0] = "0";
 //values[1] = "1"; // NULL-Pointer
   values[2] = "2";


   value = StringToStr(values[0]);
   if (!catch("onStart(2)")) debug("onStart(2)  values[0]="+ value);

   value = StringToStr(values[1]);
   if (!catch("onStart(3)")) debug("onStart(3)  values[1]="+ value);

   value = StringToStr(values[2]);
   if (!catch("onStart(4)")) debug("onStart(4)  values[2]="+ value);

   return(last_error);



   int cb1, cb2;
   cb1 = iChangedBars(NULL, PERIOD_M15, MUTE_ERR_SERIES_NOT_AVAILABLE);
   cb2 = iChangedBars("EURUSD", PERIOD_M30, MUTE_ERR_SERIES_NOT_AVAILABLE);
   debug("onStart()  changedBars(M15)="+ cb1 +"  changedBars(M30)="+ cb2);

   cb1 = iChangedBars(NULL, PERIOD_M15, MUTE_ERR_SERIES_NOT_AVAILABLE);
   cb2 = iChangedBars("EURUSD", PERIOD_M30, MUTE_ERR_SERIES_NOT_AVAILABLE);
   debug("onStart()  changedBars(M15)="+ cb1 +"  changedBars(M30)="+ cb2);
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
