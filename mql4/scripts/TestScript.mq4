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

   datetime times[] = {
/*
D'',
*/
};


   int size = ArraySize(times);

   for (int i=0;i < size;i++) {
      if (!times[i]) debug("onStart()  gmt='                  0'  fxt='                  0'");
      else           debug("onStart()  gmt="+ QuoteStr(TimeToStr(times[i], TIME_FULL)) +"  fxt="+ QuoteStr(TimeToStr(GmtToFxtTime(times[i]), TIME_FULL)));
   }

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
