/**
 * Win32 structure FILETIME
 *
 *
 * struct FILETIME {
 *    DWORD dwLowDateTime;          //  4         ft[0]
 *    DWORD dwHighDateTime;         //  4         ft[1]
 * } ft;                            //  8 byte = int[2]
 */
int ft.LowDateTime (/*FILETIME*/int ft[]) { return(ft[0]); }
int ft.HighDateTime(/*FILETIME*/int ft[]) { return(ft[1]); }


#import "Expander.dll"
   int ft_LowDateTime (/*FILETIME*/int ft[]);
   int ft_HighDateTime(/*FILETIME*/int ft[]);
#import
