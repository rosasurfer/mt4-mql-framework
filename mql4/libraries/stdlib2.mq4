/**
 * win32api-alt.mq4
 */
#property library


#include <stdlib.mqh>


#import "kernel32.dll"

 //int  GetPrivateProfileIntA(string lpSection, int lpKey, int nDefault, string lpFileName);
   int  GetPrivateProfileStringA(string lpSection, int lpKey, string lpDefault, int lpBuffer[], int bufferSize, string lpFileName);
   int  GetPrivateProfileSectionNamesA(int lpBuffer[], int bufferSize, string lpFileName);

#import


/**
 *
 */
int GetPrivateProfileKeys(string section, string& results[], string fileName) {
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
int GetPrivateProfileSectionNames(string& results[], string fileName) {
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
int GetPrivateProfileIntA.alt(string lpSection, int lpKey, int nDefault, string lpFileName) {
   return(GetPrivateProfileIntA(lpSection, lpKey, nDefault, lpFileName));
}
 */
