/**
 *
 */
#property library

#include <stdlib.mqh>

#import "kernel32.dll"

   int  GetPrivateProfileStringA(string lpSection, int lpKey, string lpDefault, int lpBuffer[], int bufferSize, string lpFileName);
   int  GetPrivateProfileSectionNamesA(int lpBuffer[], int bufferSize, string lpFileName);
   bool WritePrivateProfileStringA(string lpSection, string lpKey, int lpValue, string lpFileName);

#import


/**
 *
 */
int GetPrivateProfileKeys(string fileName, string section, string results[]) {
   int buffer[200];
   int bufferSize = ArraySize(buffer) * 4;

   int result = GetPrivateProfileStringA(section, NULL, "", buffer, bufferSize, fileName);

   // zu kleinen Buffer abfangen
   while (result == bufferSize-2) {
      ArrayResize(buffer, ArraySize(buffer) * 2);
      bufferSize = ArraySize(buffer) * 4;

      result = GetPrivateProfileStringA(section, NULL, "", buffer, bufferSize, fileName);
   }

   if (result == 0) {
      ArrayResize(results, 0);                  // keine Schlüssel gefunden (File/Section nicht gefunden oder Section ist leer)
   }
   else {
      StringBufferToArray(buffer, results);
   }
   return(ArraySize(results));
}


/**
 *
 */
int GetPrivateProfileSectionNames(string fileName, string results[]) {
   int buffer[200];
   int bufferSize = ArraySize(buffer) * 4;

   int result = GetPrivateProfileSectionNamesA(buffer, bufferSize, fileName);

   // zu kleinen Buffer abfangen
   while (result == bufferSize-2) {
      ArrayResize(buffer, ArraySize(buffer) * 2);
      bufferSize = ArraySize(buffer) * 4;

      result = GetPrivateProfileSectionNamesA(buffer, bufferSize, fileName);
   }

   if (result == 0) {
      ArrayResize(results, 0);                  // keine Sections gefunden (File nicht gefunden oder leer)
   }
   else {
      StringBufferToArray(buffer, results);
   }
   return(ArraySize(results));
}


/**
 *
 */
int DeletePrivateProfileKey(string fileName, string section, string key) {
   if (!WritePrivateProfileStringA(section, key, NULL, fileName))
      return(catch("DeletePrivateProfileKey()   kernel32::WritePrivateProfileStringA(section=\""+ section +"\", key=\""+ key +"\", value=(int) NULL, fileName=\""+ fileName +"\") failed", ERR_WINDOWS_ERROR));
   return(NO_ERROR);
}
