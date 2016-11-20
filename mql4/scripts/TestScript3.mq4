/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_DOESNT_REQUIRE_BARS };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>


#import "Expander.Release.dll"
   bool   SubclassWindow(int hWnd);
   bool   UnsubclassWindow(int hWnd);
#import


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {

   string version = GetTerminalVersion();
   int    build   = GetTerminalBuild();
   debug("onStart(1)  version="+ DoubleQuoteStr(version) +"  build="+ build);


   return(catch("onStart(99)"));







   int hWnd = WindowHandleEx(NULL); if (!hWnd) return(last_error);
   debug("onStart(2)  SubclassWindow()   => "+ SubclassWindow(hWnd));
   debug("onStart(3)  UnsubclassWindow() => "+ UnsubclassWindow(hWnd));
   return(catch("onStart(4)"));
}
