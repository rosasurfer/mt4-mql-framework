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
   string sound.order.failed   = "speech/OrderExecutionFailed.wav";
   string sound.position.open  = "speech/OrderFilled.wav";
   string sound.position.close = "speech/PositionClosed.wav";

   PlaySoundEx(sound.position.close);

   return(catch("onStart()"));



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



























































