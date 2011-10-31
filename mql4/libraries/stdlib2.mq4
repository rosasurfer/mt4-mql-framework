/**
 *
 */
#property library

#include <stdlib.mqh>

#import "kernel32.dll"

   int  GetPrivateProfileStringA(string lpSection, string lpKey, string lpDefault, int lpBuffer[], int bufferSize, string lpFileName);

#import


/**
 *
 */
int GetPrivateProfileKeys(string fileName, string section, string keys[]) {
   string sNull;
   int    bufferSize = 200;
   int    buffer[]; InitializeBuffer(buffer, bufferSize);

   int chars = GetPrivateProfileStringA(section, sNull, "", buffer, bufferSize, fileName);

   // zu kleinen Buffer abfangen
   while (chars == bufferSize-2) {
      bufferSize <<= 1;
      InitializeBuffer(buffer, bufferSize);
      chars = GetPrivateProfileStringA(section, sNull, "", buffer, bufferSize, fileName);
   }

   int length;

   if (chars == 0) length = ArrayResize(keys, 0);                    // keine Schlüssel gefunden (File/Section nicht gefunden oder Section ist leer)
   else            length = ExplodeStrings(buffer, keys);

   return(length);
}