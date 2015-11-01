/**
 * TestScript2
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_DOESNT_REQUIRE_BARS };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>


#import "Expander.Release.dll"
   bool SubclassWindow(int hWnd);
   bool UnsubclassWindow(int hWnd);
#import


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   int hWnd = WindowHandleEx(NULL); if (!hWnd) return(last_error);

   debug("onStart(1)  SubclassWindow()   => "+ SubclassWindow(hWnd));
   debug("onStart(2)  UnsubclassWindow() => "+ UnsubclassWindow(hWnd));

   return(NO_ERROR);
}


/**
 * @return int - Fehlerstatus
 */
int onDeinit() {
   return(last_error);
}
