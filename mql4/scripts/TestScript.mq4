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

   //string value = GetIniString(GetLocalConfigPath(), "Logging", "TestKey", "~^o");
   //debug("onStart()  TestKey="+ DoubleQuoteStr(value));

   string value;

   value = "";      debug("onStart()  StringIsNumeric(\""+ value +"\") = "+ StringIsNumeric(value) +"  StrToDouble(\""+ value +"\") = "+ NumberToStr(StrToDouble(value), ".1+"));
   value =   "0.2"; debug("onStart()  StringIsNumeric(\""+ value +"\") = "+ StringIsNumeric(value) +"  StrToDouble(\""+ value +"\") = "+ NumberToStr(StrToDouble(value), ".1+"));
   value =  "-0.2"; debug("onStart()  StringIsNumeric(\""+ value +"\") = "+ StringIsNumeric(value) +"  StrToDouble(\""+ value +"\") = "+ NumberToStr(StrToDouble(value), ".1+"));
   value = "- 0.2"; debug("onStart()  StringIsNumeric(\""+ value +"\") = "+ StringIsNumeric(value) +"  StrToDouble(\""+ value +"\") = "+ NumberToStr(StrToDouble(value), ".1+"));
   value =  "1.";   debug("onStart()  StringIsNumeric(\""+ value +"\") = "+ StringIsNumeric(value) +"  StrToDouble(\""+ value +"\") = "+ NumberToStr(StrToDouble(value), ".1+"));
   value = "-1.";   debug("onStart()  StringIsNumeric(\""+ value +"\") = "+ StringIsNumeric(value) +"  StrToDouble(\""+ value +"\") = "+ NumberToStr(StrToDouble(value), ".1+"));
   value =  ".3";   debug("onStart()  StringIsNumeric(\""+ value +"\") = "+ StringIsNumeric(value) +"  StrToDouble(\""+ value +"\") = "+ NumberToStr(StrToDouble(value), ".1+"));
   value = "-.3";   debug("onStart()  StringIsNumeric(\""+ value +"\") = "+ StringIsNumeric(value) +"  StrToDouble(\""+ value +"\") = "+ NumberToStr(StrToDouble(value), ".1+"));

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
