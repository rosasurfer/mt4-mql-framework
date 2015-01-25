/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>
#include <history.mqh>
#include <structs/mt4/HISTORY_HEADER.mqh>


#import "StdLib.Release.dll"
   bool Test();
#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   double a = -5;
   double b = MathLog(a);

   debug("onStart()   b="+ StringRight(DoubleToStrEx(b, 16), -1) +" or "+ b);

   int    ints   [2]; ints   [0] = a; ints   [1] = a*2;
   double doubles[2]; doubles[0] = a; doubles[1] = b;

   debug("onStart()   addr(ints)   =0x"+ IntToHexStr(GetIntsAddress(ints)));
   debug("onStart()   addr(doubles)=0x"+ IntToHexStr(GetDoublesAddress(doubles)));


   //[2192] MetaTrader::EURUSD,M30::TestScript::onStart()   a=-5  b=- or -1.#IND0000



   return(catch("onStart(2)"));



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
UnintializeReason()
-------------------
- wird in EXECUTION_CONTEXT gespeichert
- in InitReason und DeinitReason auftrennen

int init();
int deinit();
int OnInit(int reason);
int OnDeinit(int reason);

int DebugMarketInfo(string location);
int FileReadLines(string filename, string lines[], bool skipEmptyLines);
*/



























































