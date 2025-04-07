/**
 * Win32 struct SECURITY_ATTRIBUTES
 *
 * struct SECURITY_ATTRIBUTES {
 *    DWORD  nLength;                     //  4
 *    LPVOID lpSecurityDescriptor;        //  4
 *    BOOL   bInheritHandle;              //  4
 * };                                     // 12 byte
 */
#import "rsfMT4Expander.dll"
   int  sa_Length            (/*SECURITY_ATTRIBUTES*/int sa[]);
   int  sa_SecurityDescriptor(/*SECURITY_ATTRIBUTES*/int sa[]);
   bool sa_InheritHandle     (/*SECURITY_ATTRIBUTES*/int sa[]);
#import
