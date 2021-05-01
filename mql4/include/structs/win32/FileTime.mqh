/**
 * Win32 struct FILETIME
 *
 * struct FILETIME {
 *    DWORD dwLowDateTime;          //  4
 *    DWORD dwHighDateTime;         //  4
 * };                               //  8 byte
 */
#import "rsfMT4Expander.dll"
   int ft_LowDateTime (/*FILETIME*/int ft[]);
   int ft_HighDateTime(/*FILETIME*/int ft[]);
#import
