/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>
#include <win32api.mqh>


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


   double a = MathLog(-1);
   double b = MathLog( 0);
   double c = -1* b;

   debug("onStart()  MathLog(-1)    = "+ a +" * -1 = "+ (-1*a) +"  (a!=a) => "+ BoolToStr(a != a), GetLastError());
   debug("onStart()  MathLog( 0)    = "+ b +" * -1 =  "+ (c)   +"  (b!=b) => "+ BoolToStr(b != b), GetLastError());
   debug("onStart()  MathSqrt(-1)   = "+ MathSqrt(-1)      , GetLastError());

   return(catch("onStart()"));
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
