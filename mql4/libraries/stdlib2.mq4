/**
 * win32api-alt.mq4
 */
#property library


#include <stdlib.mqh>


#import "kernel32.dll"

   int  GetPrivateProfileIntA(string lpSection, int lpKey, int nDefault, string lpFileName);
   int  GetPrivateProfileStringA(string lpSection, int lpKey, string lpDefault, int lpBuffer, int bufferSize, string lpFileName);

#import



/**
 *
 */
int GetPrivateProfileIntA.alt(string lpSection, int lpKey, int nDefault, string lpFileName) {
   return(GetPrivateProfileIntA(lpSection, lpKey, nDefault, lpFileName));
}


/**
 *
 */
int GetPrivateProfileStringA.alt(string lpSection, int lpKey, string lpDefault, int& lpBuffer[], int bufferSize, string lpFileName) {
   debug("GetPrivateProfileStringA.alt(1)   size(lpBuffer) = "+ ArraySize(lpBuffer));

   int result = GetPrivateProfileStringA(lpSection, lpKey, lpDefault, lpBuffer[0], bufferSize, lpFileName);

   debug("GetPrivateProfileStringA.alt(2)   size(lpBuffer) = "+ ArraySize(lpBuffer) +"   result="+ result);

   return(result);
}