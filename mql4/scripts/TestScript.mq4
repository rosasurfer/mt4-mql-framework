/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>


#import "StdLib.Release.dll"
   bool Test();
#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   debug("onStart()   IsMqlDirectory(\"ATC\") = "+ IsMqlDirectory("ATC"));

   return(last_error);
}

/*
todo:
-----
int DebugMarketInfo(string location);
int FileReadLines(string filename, string lines[], bool skipEmptyLines);

int init();
int deinit();
int OnInit();
int OnDeinit();
*/
