/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
//#include <stdlib.mqh>


#import "stdlib1.ex4"
   string IntToHexStr(int integer);

#import "MT4Lib.dll"
   int    GetBoolsAddress  (bool   array[]);
   int    GetIntsAddress   (int    array[]);  int GetBufferAddress(int buffer[]); // Alias
   int    GetDoublesAddress(double array[]);
   int    GetStringsAddress(string array[]);
   int    GetStringAddress (string value  );
   string GetString(int address);
#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   string str = "hello world";
   debug("onStart()   pwAddr(string) = 0x"+ IntToHexStr(GetStringAddress(str)));

   /*
   bool bools[2];
   debug("onStart()   mqAddr(bools) = 0x"+ IntToHexStr(GetBoolsAddress(bools)));
   debug("onStart()   pwAddr(bools) = 0x"+ IntToHexStr(pw_GetBoolsAddress(bools)));

   int ints[2];
   debug("onStart()   mqAddr(ints)  = 0x"+ IntToHexStr(GetIntsAddress(ints)));
   debug("onStart()   pwAddr(ints)  = 0x"+ IntToHexStr(pw_GetIntsAddress(ints)));

   double doubles[2];
   debug("onStart()   mqAddr(doubles)  = 0x"+ IntToHexStr(GetDoublesAddress(doubles)));
   debug("onStart()   pwAddr(doubles)  = 0x"+ IntToHexStr(pw_GetDoublesAddress(doubles)));

   string strings[2] = {"a", "b"};
   debug("onStart()   mqAddr(strings)  = 0x"+ IntToHexStr(GetStringsAddress(strings)));
   debug("onStart()   pwAddr(strings)  = 0x"+ IntToHexStr(pw_GetStringsAddress(strings)));

   string str = "hello world";
   debug("onStart()   mqAddr(string) = 0x"+ IntToHexStr(GetStringAddress(str)));
   debug("onStart()   pwAddr(string) = 0x"+ IntToHexStr(pw_GetStringAddress(str)));

   string str = "hello world";
   int  lpStr = GetStringAddress(str);
   string mqStr = GetStringValue(lpStr);
   string pwStr = GetString(lpStr);
   debug("onStart()     str=\""+ str   +"\" (0x"+ IntToHexStr(lpStr)                   +")");
   debug("onStart()   mqStr=\""+ mqStr +"\" (0x"+ IntToHexStr(GetStringAddress(mqStr)) +")");
   debug("onStart()   pwStr=\""+ pwStr +"\" (0x"+ IntToHexStr(GetStringAddress(pwStr)) +")");
   */

   return(last_error);
}
