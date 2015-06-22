/**
 * Win32 structure SYSTEMTIME
 *
 *
 * struct SYSTEMTIME {
 *    WORD wYear;                //  2
 *    WORD wMonth;               //  2
 *    WORD wDayOfWeek;           //  2
 *    WORD wDay;                 //  2
 *    WORD wHour;                //  2
 *    WORD wMinute;              //  2
 *    WORD wSecond;              //  2
 *    WORD wMilliseconds;        //  2
 * } st;                         // 16 byte = int[4]
 */
int st.Year        (/*SYSTEMTIME*/int st[]) { return(st[0] &  0x0000FFFF); }
int st.Month       (/*SYSTEMTIME*/int st[]) { return(st[0] >> 16        ); }
int st.DayOfWeek   (/*SYSTEMTIME*/int st[]) { return(st[1] &  0x0000FFFF); }
int st.Day         (/*SYSTEMTIME*/int st[]) { return(st[1] >> 16        ); }
int st.Hour        (/*SYSTEMTIME*/int st[]) { return(st[2] &  0x0000FFFF); }
int st.Minute      (/*SYSTEMTIME*/int st[]) { return(st[2] >> 16        ); }
int st.Second      (/*SYSTEMTIME*/int st[]) { return(st[3] &  0x0000FFFF); }
int st.Milliseconds(/*SYSTEMTIME*/int st[]) { return(st[3] >> 16        ); }


#import "Expander.dll"
   int st_Year        (/*SYSTEMTIME*/int st[]);
   int st_Month       (/*SYSTEMTIME*/int st[]);
   int st_DayOfWeek   (/*SYSTEMTIME*/int st[]);
   int st_Day         (/*SYSTEMTIME*/int st[]);
   int st_Hour        (/*SYSTEMTIME*/int st[]);
   int st_Minute      (/*SYSTEMTIME*/int st[]);
   int st_Second      (/*SYSTEMTIME*/int st[]);
   int st_Milliseconds(/*SYSTEMTIME*/int st[]);
#import
