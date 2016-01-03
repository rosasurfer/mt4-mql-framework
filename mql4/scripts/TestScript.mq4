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
   int Test();
#import



/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   string value  = "abc.123.def.123";
   string substr = ".";
   int    count  = 5;

   debug("onStart(0.1)  StringLeftTo ("+ QuoteStr(value) +", "+ QuoteStr(substr) +", count="+ count +") = "+ QuoteStr(StringLeftTo   (value, substr, count)));
   debug("onStart(0.2)  StringRightTo("+ QuoteStr(value) +", "+ QuoteStr(substr) +", count="+ count +") = "+ QuoteStr(StringRightFrom(value, substr, count)));


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
