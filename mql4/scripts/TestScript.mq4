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



/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   double a;
   int digits;

   a      = 1.49999991;
   digits = 0;
 //debug("onStart(1)  NormalizeDouble("+ NumberToStr(a, ".8+") +", "+ digits +") = "+ DoubleToStrEx(NormalizeDouble(a, digits), 16));
   debug("onStart(1)  NormalizeDouble(a="+ a +", "+ digits +") = "+ DoubleToStrEx(NormalizeDouble(a, digits), 16));
 //debug("onStart()  MathRound      ("+ NumberToStr(a, ".+")            +")    = "+ DoubleToStrEx(MathRound(a), 16));

   a      = 1.54999999;
   digits = 1;
 //debug("onStart(2)  NormalizeDouble("+ NumberToStr(a, ".8+") +", "+ digits +") = "+ DoubleToStrEx(NormalizeDouble(a, digits), 16));
   debug("onStart(2)  NormalizeDouble(a="+ a +", "+ digits +") = "+ DoubleToStrEx(NormalizeDouble(a, digits), 16));

   a      = 0.15499999;
   digits = 2;
   debug("onStart(3)  NormalizeDouble("+ NumberToStr(a, ".8+") +", "+ digits +") = "+ DoubleToStrEx(NormalizeDouble(a, digits), 16));

   a++;
   digits = 2;
   debug("onStart(4)  NormalizeDouble("+ NumberToStr(a, ".8+") +", "+ digits +") = "+ DoubleToStrEx(NormalizeDouble(a, digits), 16));


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
