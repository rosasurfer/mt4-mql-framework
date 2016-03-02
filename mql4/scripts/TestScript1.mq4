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
#include <iFunctions/iChangedBars.mqh>


#import "Expander.Release.dll"
#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   double value;
   string format;

   value  = 9.567;
   format = "+R3";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));
   format = "+R.0";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));

   value  = 9.456;
   format = "+R3";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));
   format = "+R.0";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));


   value  = -9.567;
   format = "+R3";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));
   format = "+R.0";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));

   value  = -9.456;
   format = "+R3";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));
   format = "+R.0";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));



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
TODO Builds > 509:
------------------
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
