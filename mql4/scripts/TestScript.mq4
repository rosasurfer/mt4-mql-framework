/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>


#import "MT4Lib.dll"
   string GetString(int address);
#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   /*
   string str = "hello world";
   int  lpStr = GetStringAddress(str);

   string mqStr = GetStringValue(lpStr);
   string pwStr = GetString(lpStr);

   debug("onStart()   mqStr=\""+ mqStr +"\" (0x"+ IntToHexStr(GetStringAddress(mqStr)) +")");
   debug("onStart()   pwStr=\""+ pwStr +"\" (0x"+ IntToHexStr(GetStringAddress(pwStr)) +")");
   */

   return(last_error);
}
