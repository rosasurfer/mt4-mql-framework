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
   int    Test();
#import


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {

   debug("onStart(1)  0                ="+ DoubleQuoteStr(ErrorToStrEx(0)));
   debug("onStart(2)  -1               ="+ DoubleQuoteStr(ErrorToStrEx(-1)));
   debug("onStart(3)  ERR_RUNTIME_ERROR="+ DoubleQuoteStr(ErrorToStrEx(ERR_RUNTIME_ERROR)));


   return(catch("onStart(99)"));




   string version = GetTerminalVersion();
   int    build   = GetTerminalBuild();
   debug("onStart(1)  version="+ DoubleQuoteStr(version) +"  build="+ build);
   return(catch("onStart(99)"));


   int hWnd = WindowHandleEx(NULL); if (!hWnd) return(last_error);
   debug("onStart(2)  SubclassWindow()   => "+ SubclassWindow(hWnd));
   debug("onStart(3)  UnsubclassWindow() => "+ UnsubclassWindow(hWnd));
   return(catch("onStart(4)"));
}
