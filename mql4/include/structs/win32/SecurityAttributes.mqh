/**
 * Win32 structure SECURITY_ATTRIBUTES
 *
 *
 * struct SECURITY_ATTRIBUTES {
 *    DWORD  nLength;                     //  4         sa[0]
 *    LPVOID lpSecurityDescriptor;        //  4         sa[1]
 *    BOOL   bInheritHandle;              //  4         sa[2]
 * } sa;                                  // 12 byte = int[3]
 */
int  sa.Length            (/*SECURITY_ATTRIBUTES*/int sa[]) { return(sa[0]     ); }
int  sa.SecurityDescriptor(/*SECURITY_ATTRIBUTES*/int sa[]) { return(sa[1]     ); }
bool sa.InheritHandle     (/*SECURITY_ATTRIBUTES*/int sa[]) { return(sa[2] != 0); }


#import "Expander.dll"
   int  sa_Length            (/*SECURITY_ATTRIBUTES*/int sa[]);
   int  sa_SecurityDescriptor(/*SECURITY_ATTRIBUTES*/int sa[]);
   bool sa_InheritHandle     (/*SECURITY_ATTRIBUTES*/int sa[]);
#import
