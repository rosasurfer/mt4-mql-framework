/**
 * Test-Script für den MT4Expander
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>
#include <win32api.mqh>


//#import "expander.debug.dll"
#import "expander.release.dll"

   string Test_StringFromStack(string value);
   string Test_IntToHexStr(int value);

#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {


   Test.IntToHexStr();


   return(catch("onStart(1)"));
   Test.StringFromStack();
   Test.IntToHexStr();
}


/**
 * Tested einen von der DLL auf den Stack geschriebenen String.
 */
void Test.StringFromStack() {
   string result = "";

   string in  = "........................................";    // length = 40
   string out = Test_StringFromStack(in);

   if (in == out) result = "in == out";
   else           result = "in("+ StringLen(in) +") != out("+ StringLen(out) +"): "+ out;

   debug("StringFromStack(1)  "+ result);
}


/**
 *
 */
void Test.IntToHexStr() {
   int hWnd = WindowHandleEx(NULL);

   string s1 = Test_IntToHexStr(hWnd);
   debug("IntToHexStr(1)  s1="+ StringToStr(s1));

   string s2[1]; s2[0] = Test_IntToHexStr(hWnd);
   debug("IntToHexStr(1)  s2="+ StringToStr(s2[0]));

   string s3 = StringConcatenate("", IntToHexStr(hWnd));
   debug("IntToHexStr(1)  s3="+ StringToStr(s3));
}
