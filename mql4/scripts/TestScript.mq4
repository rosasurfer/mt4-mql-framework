/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>
#include <win32api.mqh>
#include <history.mqh>
#include <structs/mt4/HISTORY_HEADER.mqh>


#import "Expander.Release.dll"
   int    Test(string s1, int i1, string s2);
   int    StringTest();
#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   /*
   int n = 1000000;
   string result;


   mql_DwordToHexStr(0);
   DwordToHexStr(0);
   dll_DwordToHexStr(0);


   // MQL
   int startTime = GetTickCount();
   for (int i=0; i < n; i++) {
      result = mql_DwordToHexStr(i);
   }
   int endTime = GetTickCount();
   debug("onStart(0.1)  mql loop("+ n +") took "+ DoubleToStr((endTime-startTime)/1000., 3) +" sec  0x"+ result);


   // MQL-Library
   startTime = GetTickCount();
   for (i=0; i < n; i++) {
      result = DwordToHexStr(i);
   }
   endTime = GetTickCount();
   debug("onStart(0.2)  lib loop("+ n +") took "+ DoubleToStr((endTime-startTime)/1000., 3) +" sec  0x"+ result);


   // DLL
   startTime = GetTickCount();
   for (i=0; i < n; i++) {
      result = dll_DwordToHexStr(i);
   }
   endTime = GetTickCount();
   debug("onStart(0.3)  dll loop("+ n +") took "+ DoubleToStr((endTime-startTime)/1000., 3) +" sec  0x"+ result);
   */












   return(catch("onStart(1)"));

   /*
   int result = StringTest();
   debug("onStart()  StringTest() = 0x"+ IntToHexStr(result));
   */

   /*
   string result = StringTest();
   debug("onStart()  StringTest() = "+ result);
   debug("onStart()  addr(result) = 0x"+ IntToHexStr(GetStringAddress(result)));
   */

   /*
   string results[1]; results[0] = StringTest();
   debug("onStart()  StringTest() = "+ results[0]);
   */

   string results[1];
   debug("onStart()  results="+ StringsToStr(results, NULL));
   int resultsAddr = GetStringsAddress(results);

   int mqlStr[2];
   int mqlStrAddr = GetBufferAddress(mqlStr);
   CopyMemory(resultsAddr, mqlStrAddr, 8);
   debug("onStart()  mqlStr={"+ mqlStr[0] +", 0x"+ IntToHexStr(mqlStr[1]) +"}");

   /*
   results[0] = StringConcatenate("erster string (18)", "");
   debug("onStart()  results="+ StringsToStr(results, NULL));
   resultsAddr = GetStringsAddress(results);
   debug("onStart()  addr(results) = 0x"+ IntToHexStr(resultsAddr));
   CopyMemory(resultsAddr, mqlStrAddr, 8);
   debug("onStart()  mqlStr={"+ mqlStr[0] +", 0x"+ IntToHexStr(mqlStr[1]) +"}");

   results[0] = StringConcatenate("zweiter, ", "etwas längerer string (35)");
   debug("onStart()  results="+ StringsToStr(results, NULL));
   resultsAddr = GetStringsAddress(results);
   debug("onStart()  addr(results) = 0x"+ IntToHexStr(resultsAddr));
   CopyMemory(resultsAddr, mqlStrAddr, 8);
   debug("onStart()  mqlStr={"+ mqlStr[0] +", 0x"+ IntToHexStr(mqlStr[1]) +"}");
   */

   results[0] = StringTest();
   debug("onStart()  results="+ StringsToStr(results, NULL));
   CopyMemory(resultsAddr, mqlStrAddr, 8);
   debug("onStart()  mqlStr={"+ mqlStr[0] +", 0x"+ IntToHexStr(mqlStr[1]) +"}");

   debug("onStart()  addr(results[0]) = 0x"+ IntToHexStr(GetStringAddress(results[0])));

   //"MetaTrader::%s%s::%s(%d)  %s"
   //"MetaTrader::%s%s::%s(%d)  %s MetaTrader::%s%s::%s(%d)  %s MetaTrader::%s%s::%s(%d)  %s MetaTrader::%s%s::%s(%d)  %s";



   return(catch("onStart(1)"));


   debug("onStart()  MathArccos(-1.1)  = "+ MathArccos(-1.1), GetLastError());
   debug("onStart()  MathArccos( 1.1)  = "+ MathArccos( 1.1), GetLastError());

   debug("onStart()  MathArcsin(-1.1)  = "+ MathArcsin(-1.1), GetLastError());
   debug("onStart()  MathArcsin( 1.1)  = "+ MathArcsin( 1.1), GetLastError());

   debug("onStart()  MathTan(  0°) = "+ MathTan(        0)  , GetLastError());
   debug("onStart()  MathTan( 45°) = "+ MathTan(Math.PI/4)  , GetLastError());
   debug("onStart()  MathTan( 90°) = "+ MathTan(Math.PI/2)  , GetLastError());
   debug("onStart()  MathTan(405°) = "+ MathTan(Math.PI*2.25), GetLastError());

   double a = MathLog(-1);
   double b = MathLog( 0);
   double c = -1* b;

   debug("onStart()  MathLog(-1)    = "+ a +" * -1 = "+ (-1*a) +"  (a!=a) => "+ BoolToStr(a != a), GetLastError());
   debug("onStart()  MathLog( 0)    = "+ b +" * -1 =  "+ (c)   +"  (b!=b) => "+ BoolToStr(b != b), GetLastError());
   debug("onStart()  -1.#INF + -1.#INF = "+ (b + b)+"  (b+b==b) => "+ BoolToStr(b+b == b), GetLastError());
   debug("onStart()  -1.#INF - -1.#INF = "+ (b - b), GetLastError());
   debug("onStart()   1.#INF +  1.#INF =  "+ (c + c)+"  (c+c==c) => "+ BoolToStr(c+c == c), GetLastError());
   debug("onStart()   1.#INF -  1.#INF = "+ (c - c), GetLastError());

   debug("onStart()  MathSqrt(-1)   = "+ MathSqrt(-1)      , GetLastError());

   return(catch("onStart(10)"));



   string symbol = "AUDLFX";
   int    period = PERIOD_M30;

   int  hHst    = HistoryFile.Open(symbol, "", 4, period, FILE_READ|FILE_WRITE);
   bool written = HistoryFile.AddTick(hHst, D'2014.08.26 02:55:01', 1.6244, NULL);
   bool closed  = HistoryFile.Close  (hHst);


   debug("onStart()  hHst="+ hHst +"  written="+ written +"  closed="+ closed);
   return(catch("onStart()"));

   int header[]; hf.Header(hHst, header);
   HISTORY_HEADER.toStr(header, true);
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



























































