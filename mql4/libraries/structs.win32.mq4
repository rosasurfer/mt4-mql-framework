/**
 * Win32 structures PROCESS_INFORMATION, SECURITY_ATTRIBUTES, STARTUPINFO, SYSTEMTIME, TIME_ZONE_INFORMATION, WIN32_FIND_DATA
 *
 * NOTE: MetaTrader 4 unterstützt maximal 512 deklarierte Arrays je Modul.
 */
#property library
#property stacksize 32768

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/library.mqh>
#include <stdlib.mqh>
#include <win32api.mqh>


/**
 * Win32 structure FILETIME
 *
 * struct FILETIME {
 *    int lowDateTime;        //  4
 *    int highDateTime;       //  4
 * }ft;                       //  8 byte = int[2]
 */


/**
 * Win32 structure PROCESS_INFORMATION
 *
 * struct PROCESS_INFORMATION {
 *    int hProcess;              //  4
 *    int hThread;               //  4
 *    int processId;             //  4
 *    int threadId;              //  4
 * } pi;                         // 16 byte = int[4]
 */
int pi.hProcess (/*PROCESS_INFORMATION*/int pi[]) { return(pi[0]); }
int pi.hThread  (/*PROCESS_INFORMATION*/int pi[]) { return(pi[1]); }
int pi.ProcessId(/*PROCESS_INFORMATION*/int pi[]) { return(pi[2]); }
int pi.ThreadId (/*PROCESS_INFORMATION*/int pi[]) { return(pi[3]); }


/**
 * Win32 structure SECURITY_ATTRIBUTES
 *
 * struct SECURITY_ATTRIBUTES {
 *    DWORD nLength;                      //  4
 *    int   lpSecurityDescriptor;         //  4
 *    BOOL  bInheritHandle;               //  4
 * } sa;                                  // 12 byte = int[3]
 */
int  sa.Length            (/*SECURITY_ATTRIBUTES*/int sa[]) { return(sa[0]); }
int  sa.SecurityDescriptor(/*SECURITY_ATTRIBUTES*/int sa[]) { return(sa[1]); }
bool sa.InheritHandle     (/*SECURITY_ATTRIBUTES*/int sa[]) { return(sa[2]); }


/**
 * Win32 structure STARTUPINFO
 *
 * struct STARTUPINFO {
 *    DWORD  cb;                          //  4      => si[ 0]
 *    LPTSTR lpReserved;                  //  4      => si[ 1]
 *    LPTSTR lpDesktop;                   //  4      => si[ 2]
 *    LPTSTR lpTitle;                     //  4      => si[ 3]
 *    DWORD  dwX;                         //  4      => si[ 4]
 *    DWORD  dwY;                         //  4      => si[ 5]
 *    DWORD  dwXSize;                     //  4      => si[ 6]
 *    DWORD  dwYSize;                     //  4      => si[ 7]
 *    DWORD  dwXCountChars;               //  4      => si[ 8]
 *    DWORD  dwYCountChars;               //  4      => si[ 9]
 *    DWORD  dwFillAttribute;             //  4      => si[10]
 *    DWORD  dwFlags;                     //  4      => si[11]
 *    WORD   wShowWindow;                 //  2      => si[12]
 *    WORD   cbReserved2;                 //  2      => si[12]
 *    LPBYTE lpReserved2;                 //  4      => si[13]
 *    HANDLE hStdInput;                   //  4      => si[14]
 *    HANDLE hStdOutput;                  //  4      => si[15]
 *    HANDLE hStdError;                   //  4      => si[16]
 * } si;                                  // 68 byte = int[17]
 */
int si.cb           (/*STARTUPINFO*/int si[]) { return(si[ 0]); }
int si.Desktop      (/*STARTUPINFO*/int si[]) { return(si[ 2]); }
int si.Title        (/*STARTUPINFO*/int si[]) { return(si[ 3]); }
int si.X            (/*STARTUPINFO*/int si[]) { return(si[ 4]); }
int si.Y            (/*STARTUPINFO*/int si[]) { return(si[ 5]); }
int si.XSize        (/*STARTUPINFO*/int si[]) { return(si[ 6]); }
int si.YSize        (/*STARTUPINFO*/int si[]) { return(si[ 7]); }
int si.XCountChars  (/*STARTUPINFO*/int si[]) { return(si[ 8]); }
int si.YCountChars  (/*STARTUPINFO*/int si[]) { return(si[ 9]); }
int si.FillAttribute(/*STARTUPINFO*/int si[]) { return(si[10]); }
int si.Flags        (/*STARTUPINFO*/int si[]) { return(si[11]); }
int si.ShowWindow   (/*STARTUPINFO*/int si[]) { return(si[12] & 0xFFFF); }
int si.hStdInput    (/*STARTUPINFO*/int si[]) { return(si[14]); }
int si.hStdOutput   (/*STARTUPINFO*/int si[]) { return(si[15]); }
int si.hStdError    (/*STARTUPINFO*/int si[]) { return(si[16]); }

int si.setCb        (/*STARTUPINFO*/int &si[], int size   ) { si[ 0] =  size; }
int si.setFlags     (/*STARTUPINFO*/int &si[], int flags  ) { si[11] = flags; }
int si.setShowWindow(/*STARTUPINFO*/int &si[], int cmdShow) { si[12] = (si[12] & 0xFFFF0000) + (cmdShow & 0xFFFF); }


/**
 * Gibt die lesbare Version eines STARTUPINFO-Flags zurück.
 *
 * @param  int si[] - STARTUPINFO structure
 *
 * @return string
 */
string si.FlagsToStr(/*STARTUPINFO*/int si[]) {
   string result = "";
   int flags = si.Flags(si);

   if (_bool(flags & STARTF_FORCEONFEEDBACK )) result = StringConcatenate(result, "|STARTF_FORCEONFEEDBACK" );
   if (_bool(flags & STARTF_FORCEOFFFEEDBACK)) result = StringConcatenate(result, "|STARTF_FORCEOFFFEEDBACK");
   if (_bool(flags & STARTF_PREVENTPINNING  )) result = StringConcatenate(result, "|STARTF_PREVENTPINNING"  );
   if (_bool(flags & STARTF_RUNFULLSCREEN   )) result = StringConcatenate(result, "|STARTF_RUNFULLSCREEN"   );
   if (_bool(flags & STARTF_TITLEISAPPID    )) result = StringConcatenate(result, "|STARTF_TITLEISAPPID"    );
   if (_bool(flags & STARTF_TITLEISLINKNAME )) result = StringConcatenate(result, "|STARTF_TITLEISLINKNAME" );
   if (_bool(flags & STARTF_USECOUNTCHARS   )) result = StringConcatenate(result, "|STARTF_USECOUNTCHARS"   );
   if (_bool(flags & STARTF_USEFILLATTRIBUTE)) result = StringConcatenate(result, "|STARTF_USEFILLATTRIBUTE");
   if (_bool(flags & STARTF_USEHOTKEY       )) result = StringConcatenate(result, "|STARTF_USEHOTKEY"       );
   if (_bool(flags & STARTF_USEPOSITION     )) result = StringConcatenate(result, "|STARTF_USEPOSITION"     );
   if (_bool(flags & STARTF_USESHOWWINDOW   )) result = StringConcatenate(result, "|STARTF_USESHOWWINDOW"   );
   if (_bool(flags & STARTF_USESIZE         )) result = StringConcatenate(result, "|STARTF_USESIZE"         );
   if (_bool(flags & STARTF_USESTDHANDLES   )) result = StringConcatenate(result, "|STARTF_USESTDHANDLES"   );

   if (StringLen(result) > 0)
      result = StringSubstr(result, 1);
   return(result);
}


/**
 * Gibt die lesbare Konstante einer STARTUPINFO ShowWindow-ID zurück.
 *
 * @param  int si[] - STARTUPINFO structure
 *
 * @return string
 */
string si.ShowWindowToStr(/*STARTUPINFO*/int si[]) {
   switch (si.ShowWindow(si)) {
      case SW_HIDE           : return("SW_HIDE"           );
      case SW_SHOWNORMAL     : return("SW_SHOWNORMAL"     );
      case SW_SHOWMINIMIZED  : return("SW_SHOWMINIMIZED"  );
      case SW_SHOWMAXIMIZED  : return("SW_SHOWMAXIMIZED"  );
      case SW_SHOWNOACTIVATE : return("SW_SHOWNOACTIVATE" );
      case SW_SHOW           : return("SW_SHOW"           );
      case SW_MINIMIZE       : return("SW_MINIMIZE"       );
      case SW_SHOWMINNOACTIVE: return("SW_SHOWMINNOACTIVE");
      case SW_SHOWNA         : return("SW_SHOWNA"         );
      case SW_RESTORE        : return("SW_RESTORE"        );
      case SW_SHOWDEFAULT    : return("SW_SHOWDEFAULT"    );
      case SW_FORCEMINIMIZE  : return("SW_FORCEMINIMIZE"  );
   }
   return("");
}


/**
 * Win32 structure SYSTEMTIME
 *
 * struct SYSTEMTIME {
 *    WORD wYear;             //  2
 *    WORD wMonth;            //  2
 *    WORD wDayOfWeek;        //  2
 *    WORD wDay;              //  2
 *    WORD wHour;             //  2
 *    WORD wMinute;           //  2
 *    WORD wSecond;           //  2
 *    WORD wMilliseconds;     //  2
 * } st;                      // 16 byte = int[4]
 */
int st.Year     (/*SYSTEMTIME*/int st[]) { return(st[0] &  0x0000FFFF); }
int st.Month    (/*SYSTEMTIME*/int st[]) { return(st[0] >> 16        ); }
int st.DayOfWeek(/*SYSTEMTIME*/int st[]) { return(st[1] &  0x0000FFFF); }
int st.Day      (/*SYSTEMTIME*/int st[]) { return(st[1] >> 16        ); }
int st.Hour     (/*SYSTEMTIME*/int st[]) { return(st[2] &  0x0000FFFF); }
int st.Minute   (/*SYSTEMTIME*/int st[]) { return(st[2] >> 16        ); }
int st.Second   (/*SYSTEMTIME*/int st[]) { return(st[3] &  0x0000FFFF); }
int st.MilliSec (/*SYSTEMTIME*/int st[]) { return(st[3] >> 16        ); }


/**
 * Win32 structure TIME_ZONE_INFORMATION
 *
 * struct TIME_ZONE_INFORMATION {
 *    LONG       Bias;                    //   4     => tzi[ 0]      // Bias             = -Offset
 *    WCHAR      StandardName[32];        //  64     => tzi[ 1]      // LocalTime + Bias = GMT        (LocalTime -> GMT)
 *    SYSTEMTIME StandardDate;            //  16     => tzi[17]      // GMT + Offset     = LocalTime  (GMT -> LocalTime)
 *    LONG       StandardBias;            //   4     => tzi[21]
 *    WCHAR      DaylightName[32];        //  64     => tzi[22]
 *    SYSTEMTIME DaylightDate;            //  16     => tzi[38]
 *    LONG       DaylightBias;            //   4     => tzi[42]
 * } tzi;                                 // 172 byte = int[43]
 *
 * BufferToHexStr(TIME_ZONE_INFORMATION) = 88FFFFFF
 *                                         47005400 42002000 4E006F00 72006D00 61006C00 7A006500 69007400 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                         G   T    B   .    N   o    r   m    a   l    z   e    i   t
 *                                         00000A00 00000500 04000000 00000000
 *                                         00000000
 *                                         47005400 42002000 53006F00 6D006D00 65007200 7A006500 69007400 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                         G   T    B   .    S   o    m   m    e   r    z   e    i   t
 *                                         00000300 00000500 03000000 00000000
 *                                         C4FFFFFF
 */
int    tzi.Bias        (/*TIME_ZONE_INFORMATION*/int tzi[])                         { return(tzi[0]); }                               // Bias in Minuten
string tzi.StandardName(/*TIME_ZONE_INFORMATION*/int tzi[])                         { return(BufferWCharsToStr(tzi, 1, 16)); }
void   tzi.StandardDate(/*TIME_ZONE_INFORMATION*/int tzi[], /*SYSTEMTIME*/int st[]) { ArrayCopy(st, tzi, 0, 17, 4); }
int    tzi.StandardBias(/*TIME_ZONE_INFORMATION*/int tzi[])                         { return(tzi[21]); }                              // Bias in Minuten
string tzi.DaylightName(/*TIME_ZONE_INFORMATION*/int tzi[])                         { return(BufferWCharsToStr(tzi, 22, 16)); }
void   tzi.DaylightDate(/*TIME_ZONE_INFORMATION*/int tzi[], /*SYSTEMTIME*/int st[]) { ArrayCopy(st, tzi, 0, 38, 4); }
int    tzi.DaylightBias(/*TIME_ZONE_INFORMATION*/int tzi[])                         { return(tzi[42]); }                              // Bias in Minuten


/**
 * Win32 structure WIN32_FIND_DATA
 *
 * struct WIN32_FIND_DATA {
 *    DWORD    dwFileAttributes;          //   4     => wfd[ 0]
 *    FILETIME ftCreationTime;            //   8     => wfd[ 1]
 *    FILETIME ftLastAccessTime;          //   8     => wfd[ 3]
 *    FILETIME ftLastWriteTime;           //   8     => wfd[ 5]
 *    DWORD    nFileSizeHigh;             //   4     => wfd[ 7]
 *    DWORD    nFileSizeLow;              //   4     => wfd[ 8]
 *    DWORD    dwReserved0;               //   4     => wfd[ 9]
 *    DWORD    dwReserved1;               //   4     => wfd[10]
 *    TCHAR    cFileName[MAX_PATH];       // 260     => wfd[11]      A: 260 * 1 byte      W: 260 * 2 byte
 *    TCHAR    cAlternateFileName[14];    //  14     => wfd[76]      A:  14 * 1 byte      W:  14 * 2 byte
 * } wfd;                                 // 318 byte = int[80]      2 byte Überhang
 *
 * BufferToHexStr(WIN32_FIND_DATA) = 20000000
 *                                   C0235A72 81BDC801
 *                                   00F0D85B C9CBCB01
 *                                   00884084 D32BC101
 *                                   00000000 D2430000 05000000 3FE1807C
 *
 *                                   52686F64 6F64656E 64726F6E 2E626D70 00000000 00000000 00000000 00000000 00000000 00000000
 *                                    R h o d  o d e n  d r o n  . b m p
 *                                   00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                   00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                   00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                   00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                   00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                   00000000 00000000 00000000 00000000 00000000
 *
 *                                   52484F44 4F447E31 2E424D50 00000000
 *                                    R H O D  O D ~ 1  . B M P
 */
int    wfd.FileAttributes            (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0]); }
bool   wfd.FileAttribute.ReadOnly    (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_READONLY     ); }
bool   wfd.FileAttribute.Hidden      (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_HIDDEN       ); }
bool   wfd.FileAttribute.System      (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_SYSTEM       ); }
bool   wfd.FileAttribute.Directory   (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_DIRECTORY    ); }
bool   wfd.FileAttribute.Archive     (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_ARCHIVE      ); }
bool   wfd.FileAttribute.Device      (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_DEVICE       ); }
bool   wfd.FileAttribute.Normal      (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_NORMAL       ); }
bool   wfd.FileAttribute.Temporary   (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_TEMPORARY    ); }
bool   wfd.FileAttribute.SparseFile  (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_SPARSE_FILE  ); }
bool   wfd.FileAttribute.ReparsePoint(/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_REPARSE_POINT); }
bool   wfd.FileAttribute.Compressed  (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_COMPRESSED   ); }
bool   wfd.FileAttribute.Offline     (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_OFFLINE      ); }
bool   wfd.FileAttribute.NotIndexed  (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_NOT_INDEXED  ); }
bool   wfd.FileAttribute.Encrypted   (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_ENCRYPTED    ); }
bool   wfd.FileAttribute.Virtual     (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_VIRTUAL      ); }
string wfd.FileName                  (/*WIN32_FIND_DATA*/int wfd[]) { return(BufferCharsToStr(wfd, 44, MAX_PATH)); }
string wfd.AlternateFileName         (/*WIN32_FIND_DATA*/int wfd[]) { return(BufferCharsToStr(wfd, 304, 14)); }


/**
 * Gibt die lesbare Version eines FileAttributes zurück.
 *
 * @param  int wfd[] - WIN32_FIND_DATA structure
 *
 * @return string
 */
string wfd.FileAttributesToStr(/*WIN32_FIND_DATA*/int wfd[]) {
   string result = "";
   int flags = wfd.FileAttributes(wfd);

   if (_bool(flags & FILE_ATTRIBUTE_READONLY     )) result = StringConcatenate(result, "|FILE_ATTRIBUTE_READONLY"     );
   if (_bool(flags & FILE_ATTRIBUTE_HIDDEN       )) result = StringConcatenate(result, "|FILE_ATTRIBUTE_HIDDEN"       );
   if (_bool(flags & FILE_ATTRIBUTE_SYSTEM       )) result = StringConcatenate(result, "|FILE_ATTRIBUTE_SYSTEM"       );
   if (_bool(flags & FILE_ATTRIBUTE_DIRECTORY    )) result = StringConcatenate(result, "|FILE_ATTRIBUTE_DIRECTORY"    );
   if (_bool(flags & FILE_ATTRIBUTE_ARCHIVE      )) result = StringConcatenate(result, "|FILE_ATTRIBUTE_ARCHIVE"      );
   if (_bool(flags & FILE_ATTRIBUTE_DEVICE       )) result = StringConcatenate(result, "|FILE_ATTRIBUTE_DEVICE"       );
   if (_bool(flags & FILE_ATTRIBUTE_NORMAL       )) result = StringConcatenate(result, "|FILE_ATTRIBUTE_NORMAL"       );
   if (_bool(flags & FILE_ATTRIBUTE_TEMPORARY    )) result = StringConcatenate(result, "|FILE_ATTRIBUTE_TEMPORARY"    );
   if (_bool(flags & FILE_ATTRIBUTE_SPARSE_FILE  )) result = StringConcatenate(result, "|FILE_ATTRIBUTE_SPARSE_FILE"  );
   if (_bool(flags & FILE_ATTRIBUTE_REPARSE_POINT)) result = StringConcatenate(result, "|FILE_ATTRIBUTE_REPARSE_POINT");
   if (_bool(flags & FILE_ATTRIBUTE_COMPRESSED   )) result = StringConcatenate(result, "|FILE_ATTRIBUTE_COMPRESSED"   );
   if (_bool(flags & FILE_ATTRIBUTE_OFFLINE      )) result = StringConcatenate(result, "|FILE_ATTRIBUTE_OFFLINE"      );
   if (_bool(flags & FILE_ATTRIBUTE_NOT_INDEXED  )) result = StringConcatenate(result, "|FILE_ATTRIBUTE_NOT_INDEXED"  );
   if (_bool(flags & FILE_ATTRIBUTE_ENCRYPTED    )) result = StringConcatenate(result, "|FILE_ATTRIBUTE_ENCRYPTED"    );
   if (_bool(flags & FILE_ATTRIBUTE_VIRTUAL      )) result = StringConcatenate(result, "|FILE_ATTRIBUTE_VIRTUAL"      );

   if (StringLen(result) > 0)
      result = StringSubstr(result, 1);
   return(result);
}


/**
 * Wird nur im Tester in library::init() aufgerufen, um alle verwendeten globalen Arrays zurücksetzen zu können (EA-Bugfix).
 */
void Tester.ResetGlobalArrays() {
   ArrayResize(stack.orderSelections, 0);
}
