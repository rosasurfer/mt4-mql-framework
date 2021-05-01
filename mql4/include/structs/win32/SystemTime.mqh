/**
 * Win32 struct SYSTEMTIME
 *
 * struct SYSTEMTIME {
 *    WORD wYear;                   //  2
 *    WORD wMonth;                  //  2
 *    WORD wDayOfWeek;              //  2
 *    WORD wDay;                    //  2
 *    WORD wHour;                   //  2
 *    WORD wMinute;                 //  2
 *    WORD wSecond;                 //  2
 *    WORD wMilliseconds;           //  2
 * };                               // 16 byte
 */
#import "rsfMT4Expander.dll"
   int st_Year        (/*SYSTEMTIME*/int st[]);
   int st_Month       (/*SYSTEMTIME*/int st[]);
   int st_DayOfWeek   (/*SYSTEMTIME*/int st[]);
   int st_Day         (/*SYSTEMTIME*/int st[]);
   int st_Hour        (/*SYSTEMTIME*/int st[]);
   int st_Minute      (/*SYSTEMTIME*/int st[]);
   int st_Second      (/*SYSTEMTIME*/int st[]);
   int st_Milliseconds(/*SYSTEMTIME*/int st[]);
#import
