/**
 * stdlib.mq4
 *
 *
 * Datentypen und Speichergrößen in C, Win32-API (16-bit word size) und MQL:
 * ========================================================================
 *
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * |         |         |        |        |        |                 |              max(hex) |            signed range(dec) |            unsigned range(dec) |       C        |        Win32        |      MQL       |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * |         |         |        |        |  1 bit |                 |                  0x01 |                        0 - 1 |                            0-1 |                |                     |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * |         |         |        | 1 byte |  8 bit | 2 nibbles       |                  0xFF |                   -128 - 127 |                          0-255 |                |      BYTE,CHAR      |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * |         |         | 1 word | 2 byte | 16 bit | HIBYTE + LOBYTE |                0xFFFF |             -32.768 - 32.767 |                       0-65.535 |     short      |   SHORT,WORD,WCHAR  |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * |         | 1 dword | 2 word | 4 byte | 32 bit | HIWORD + LOWORD |            0xFFFFFFFF |             -2.147.483.648 - |              0 - 4.294.967.295 | int,long,float | BOOL,INT,LONG,DWORD |  bool,char,int |
 * |         |         |        |        |        |                 |                       |              2.147.483.647   |                                |                |    WPARAM,LPARAM    | color,datetime |
 * |         |         |        |        |        |                 |                       |                              |                                |                | (handles, pointers) |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 * | 1 qword | 2 dword | 4 word | 8 byte | 64 bit |                 | 0xFFFFFFFF 0xFFFFFFFF | -9.223.372.036.854.775.808 - | 0 - 18.446.744.073.709.551.616 |     double     |  LONGLONG,DWORDLONG |  double,string |
 * |         |         |        |        |        |                 |                       |  9.223.372.036.854.775.807   |                                |                |                     |                |
 * +---------+---------+--------+--------+--------+-----------------+-----------------------+------------------------------+--------------------------------+----------------+---------------------+----------------+
 */
#property library


#include <stddefine.mqh>
#include <timezones.mqh>
#include <win32api.mqh>


/**
 * Initialisierung interner Variablen der Library zur Verbesserung des Debuggings.
 *
 * @param  string scriptName - Name des Scriptes, das die Library lädt
 */
void stdlib_init(string scriptName) {
   __SCRIPT__ = StringConcatenate(scriptName, "::", WindowExpertName());
   //__TRACE__  = traceMode;
}


/**
 * Informiert die Library über das Eintreffen eines neuen Ticks. Ermöglicht den Libraray-Funktionen zu erkennen, ob der Aufruf während desselben
 * oder eines neuen Ticks erfolgt (z.B. in EventListenern).
 *
 * @param  int indicatorCounted - Rückgabewert von IndicatorCounted(), der direkte Aufruf in der Library gibt -1 zurück
 *
 * @return int - Fehlerstatus
 */
int stdlib_onTick(int indicatorCounted) {
   if (indicatorCounted < 0)
      return(catch("stdlib_onTick()  invalid parameter indicatorCounted = "+ indicatorCounted, ERR_INVALID_FUNCTION_PARAMVALUE));

   Tick++;                             // der Wert hat keine tatsächliche Bedeutung
   ValidBars   = indicatorCounted;
   ChangedBars = Bars - ValidBars;

   return(NO_ERROR);
}


/**
 * Gibt den letzten in dieser Library aufgetretenen Fehler zurück. Der Aufruf dieser Funktion setzt den internen Fehlercode zurück.
 *
 * @return int - Fehlercode
 */
int stdlib_GetLastError() {
   int error = last_error;
   last_error = NO_ERROR;
   return(error);
}


/**
 * Gibt den letzten in dieser Library aufgetretenen Fehler zurück. Der Aufruf dieser Funktion setzt den internen Fehlercode *nicht* zurück.
 *
 * @return int - Fehlercode
 */
int stdlib_PeekLastError() {
   return(last_error);
}


/**
 * Win32 structure WIN32_FIND_DATA
 *
 * typedef struct _WIN32_FIND_DATA {
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
 * } WIN32_FIND_DATA, wfd;                // 318 byte = int[80]      2 byte Überhang
 *
 * StructToHexStr(WIN32_FIND_DATA) = 20000000
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
int    wfd.FileAttributes            (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0]); }
bool   wfd.FileAttribute.ReadOnly    (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_READONLY      == FILE_ATTRIBUTE_READONLY     ); }
bool   wfd.FileAttribute.Hidden      (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_HIDDEN        == FILE_ATTRIBUTE_HIDDEN       ); }
bool   wfd.FileAttribute.System      (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_SYSTEM        == FILE_ATTRIBUTE_SYSTEM       ); }
bool   wfd.FileAttribute.Directory   (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_DIRECTORY     == FILE_ATTRIBUTE_DIRECTORY    ); }
bool   wfd.FileAttribute.Archive     (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_ARCHIVE       == FILE_ATTRIBUTE_ARCHIVE      ); }
bool   wfd.FileAttribute.Device      (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_DEVICE        == FILE_ATTRIBUTE_DEVICE       ); }
bool   wfd.FileAttribute.Normal      (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_NORMAL        == FILE_ATTRIBUTE_NORMAL       ); }
bool   wfd.FileAttribute.Temporary   (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_TEMPORARY     == FILE_ATTRIBUTE_TEMPORARY    ); }
bool   wfd.FileAttribute.SparseFile  (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_SPARSE_FILE   == FILE_ATTRIBUTE_SPARSE_FILE  ); }
bool   wfd.FileAttribute.ReparsePoint(/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_REPARSE_POINT == FILE_ATTRIBUTE_REPARSE_POINT); }
bool   wfd.FileAttribute.Compressed  (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_COMPRESSED    == FILE_ATTRIBUTE_COMPRESSED   ); }
bool   wfd.FileAttribute.Offline     (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_OFFLINE       == FILE_ATTRIBUTE_OFFLINE      ); }
bool   wfd.FileAttribute.NotIndexed  (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_NOT_INDEXED   == FILE_ATTRIBUTE_NOT_INDEXED  ); }
bool   wfd.FileAttribute.Encrypted   (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_ENCRYPTED     == FILE_ATTRIBUTE_ENCRYPTED    ); }
bool   wfd.FileAttribute.Virtual     (/*WIN32_FIND_DATA*/ int& wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_VIRTUAL       == FILE_ATTRIBUTE_VIRTUAL      ); }
string wfd.FileName                  (/*WIN32_FIND_DATA*/ int& wfd[]) { return(StructCharToStr(wfd, 11, 65)); }
string wfd.AlternateFileName         (/*WIN32_FIND_DATA*/ int& wfd[]) { return(StructCharToStr(wfd, 76,  4)); }


/**
 * Gibt die lesbare Version eines FileAttributes zurück.
 *
 * @param  int& wdf[] - WIN32_FIND_DATA structure
 *
 * @return string
 */
string wdf.FileAttributesToStr(/*WIN32_FIND_DATA*/ int& wdf[]) {
   string result = "";
   int flags = wfd.FileAttributes(wdf);

   if (flags & FILE_ATTRIBUTE_READONLY      == FILE_ATTRIBUTE_READONLY     ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_READONLY"     );
   if (flags & FILE_ATTRIBUTE_HIDDEN        == FILE_ATTRIBUTE_HIDDEN       ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_HIDDEN"       );
   if (flags & FILE_ATTRIBUTE_SYSTEM        == FILE_ATTRIBUTE_SYSTEM       ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_SYSTEM"       );
   if (flags & FILE_ATTRIBUTE_DIRECTORY     == FILE_ATTRIBUTE_DIRECTORY    ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_DIRECTORY"    );
   if (flags & FILE_ATTRIBUTE_ARCHIVE       == FILE_ATTRIBUTE_ARCHIVE      ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_ARCHIVE"      );
   if (flags & FILE_ATTRIBUTE_DEVICE        == FILE_ATTRIBUTE_DEVICE       ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_DEVICE"       );
   if (flags & FILE_ATTRIBUTE_NORMAL        == FILE_ATTRIBUTE_NORMAL       ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_NORMAL"       );
   if (flags & FILE_ATTRIBUTE_TEMPORARY     == FILE_ATTRIBUTE_TEMPORARY    ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_TEMPORARY"    );
   if (flags & FILE_ATTRIBUTE_SPARSE_FILE   == FILE_ATTRIBUTE_SPARSE_FILE  ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_SPARSE_FILE"  );
   if (flags & FILE_ATTRIBUTE_REPARSE_POINT == FILE_ATTRIBUTE_REPARSE_POINT) result = StringConcatenate(result, " | FILE_ATTRIBUTE_REPARSE_POINT");
   if (flags & FILE_ATTRIBUTE_COMPRESSED    == FILE_ATTRIBUTE_COMPRESSED   ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_COMPRESSED"   );
   if (flags & FILE_ATTRIBUTE_OFFLINE       == FILE_ATTRIBUTE_OFFLINE      ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_OFFLINE"      );
   if (flags & FILE_ATTRIBUTE_NOT_INDEXED   == FILE_ATTRIBUTE_NOT_INDEXED  ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_NOT_INDEXED"  );
   if (flags & FILE_ATTRIBUTE_ENCRYPTED     == FILE_ATTRIBUTE_ENCRYPTED    ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_ENCRYPTED"    );
   if (flags & FILE_ATTRIBUTE_VIRTUAL       == FILE_ATTRIBUTE_VIRTUAL      ) result = StringConcatenate(result, " | FILE_ATTRIBUTE_VIRTUAL"      );

   if (StringLen(result) > 0)
      result = StringSubstr(result, 3);
   return(result);
}


/**
 * Win32 structure FILETIME
 *
 * typedef struct _FILETIME {
 *    DWORD dwLowDateTime;
 *    DWORD dwHighDateTime;
 * } FILETIME, ft;
 *
 * StructToHexStr(FILETIME) =
 */


/**
 * Win32 structure PROCESS_INFORMATION
 *
 * typedef struct _PROCESS_INFORMATION {
 *    HANDLE hProcess;
 *    HANDLE hThread;
 *    DWORD  dwProcessId;
 *    DWORD  dwThreadId;
 * } PROCESS_INFORMATION, pi;       // = 16 byte = int[4]
 *
 * StructToHexStr(PROCESS_INFORMATION) = 68020000 74020000 D40E0000 B80E0000
 */
int pi.hProcess (/*PROCESS_INFORMATION*/ int& pi[]) { return(pi[0]); }
int pi.hThread  (/*PROCESS_INFORMATION*/ int& pi[]) { return(pi[1]); }
int pi.ProcessId(/*PROCESS_INFORMATION*/ int& pi[]) { return(pi[2]); }
int pi.ThreadId (/*PROCESS_INFORMATION*/ int& pi[]) { return(pi[3]); }


/**
 * Win32 structure SECURITY_ATTRIBUTES
 *
 * typedef struct _SECURITY_ATTRIBUTES {
 *    DWORD  nLength;
 *    LPVOID lpSecurityDescriptor;
 *    BOOL   bInheritHandle;
 * } SECURITY_ATTRIBUTES, sa;       // = 12 byte = int[3]
 *
 * StructToHexStr(SECURITY_ATTRIBUTES) = 0C000000 00000000 00000000
 */
int  sa.Length            (/*SECURITY_ATTRIBUTES*/ int& sa[]) { return(sa[0]); }
int  sa.SecurityDescriptor(/*SECURITY_ATTRIBUTES*/ int& sa[]) { return(sa[1]); }
bool sa.InheritHandle     (/*SECURITY_ATTRIBUTES*/ int& sa[]) { return(sa[2] != 0); }


/**
 * Win32 structure STARTUPINFO
 *
 * typedef struct _STARTUPINFO {
 *    DWORD  cb;                        =>  si[ 0]
 *    LPTSTR lpReserved;                =>  si[ 1]
 *    LPTSTR lpDesktop;                 =>  si[ 2]
 *    LPTSTR lpTitle;                   =>  si[ 3]
 *    DWORD  dwX;                       =>  si[ 4]
 *    DWORD  dwY;                       =>  si[ 5]
 *    DWORD  dwXSize;                   =>  si[ 6]
 *    DWORD  dwYSize;                   =>  si[ 7]
 *    DWORD  dwXCountChars;             =>  si[ 8]
 *    DWORD  dwYCountChars;             =>  si[ 9]
 *    DWORD  dwFillAttribute;           =>  si[10]
 *    DWORD  dwFlags;                   =>  si[11]
 *    WORD   wShowWindow;               =>  si[12]
 *    WORD   cbReserved2;               =>  si[12]
 *    LPBYTE lpReserved2;               =>  si[13]
 *    HANDLE hStdInput;                 =>  si[14]
 *    HANDLE hStdOutput;                =>  si[15]
 *    HANDLE hStdError;                 =>  si[16]
 * } STARTUPINFO, si;       // = 68 byte = int[17]
 *
 * StructToHexStr(STARTUPINFO) = 44000000 103E1500 703E1500 D83D1500 00000000 00000000 00000000 00000000 00000000 00000000 00000000 010E0000 03000000 00000000 41060000 01000100 00000000
 */
int si.cb            (/*STARTUPINFO*/ int& si[]) { return(si[ 0]); }
int si.Desktop       (/*STARTUPINFO*/ int& si[]) { return(si[ 2]); }
int si.Title         (/*STARTUPINFO*/ int& si[]) { return(si[ 3]); }
int si.X             (/*STARTUPINFO*/ int& si[]) { return(si[ 4]); }
int si.Y             (/*STARTUPINFO*/ int& si[]) { return(si[ 5]); }
int si.XSize         (/*STARTUPINFO*/ int& si[]) { return(si[ 6]); }
int si.YSize         (/*STARTUPINFO*/ int& si[]) { return(si[ 7]); }
int si.XCountChars   (/*STARTUPINFO*/ int& si[]) { return(si[ 8]); }
int si.YCountChars   (/*STARTUPINFO*/ int& si[]) { return(si[ 9]); }
int si.FillAttribute (/*STARTUPINFO*/ int& si[]) { return(si[10]); }
int si.Flags         (/*STARTUPINFO*/ int& si[]) { return(si[11]); }
int si.ShowWindow    (/*STARTUPINFO*/ int& si[]) { return(si[12] & 0xFFFF); }
int si.hStdInput     (/*STARTUPINFO*/ int& si[]) { return(si[14]); }
int si.hStdOutput    (/*STARTUPINFO*/ int& si[]) { return(si[15]); }
int si.hStdError     (/*STARTUPINFO*/ int& si[]) { return(si[16]); }

int si.setCb         (/*STARTUPINFO*/ int& si[], int size   ) { si[ 0] =  size; }
int si.setFlags      (/*STARTUPINFO*/ int& si[], int flags  ) { si[11] = flags; }
int si.setShowWindow (/*STARTUPINFO*/ int& si[], int cmdShow) { si[12] = (si[12] & 0xFFFF0000) + (cmdShow & 0xFFFF); }


/**
 * Gibt die lesbare Version eines STARTUPINFO-Flags zurück.
 *
 * @param  int& si[] - STARTUPINFO structure
 *
 * @return string
 */
string si.FlagsToStr(/*STARTUPINFO*/ int& si[]) {
   string result = "";
   int flags = si.Flags(si);

   if (flags & STARTF_FORCEONFEEDBACK  == STARTF_FORCEONFEEDBACK ) result = StringConcatenate(result, " | STARTF_FORCEONFEEDBACK" );
   if (flags & STARTF_FORCEOFFFEEDBACK == STARTF_FORCEOFFFEEDBACK) result = StringConcatenate(result, " | STARTF_FORCEOFFFEEDBACK");
   if (flags & STARTF_PREVENTPINNING   == STARTF_PREVENTPINNING  ) result = StringConcatenate(result, " | STARTF_PREVENTPINNING"  );
   if (flags & STARTF_RUNFULLSCREEN    == STARTF_RUNFULLSCREEN   ) result = StringConcatenate(result, " | STARTF_RUNFULLSCREEN"   );
   if (flags & STARTF_TITLEISAPPID     == STARTF_TITLEISAPPID    ) result = StringConcatenate(result, " | STARTF_TITLEISAPPID"    );
   if (flags & STARTF_TITLEISLINKNAME  == STARTF_TITLEISLINKNAME ) result = StringConcatenate(result, " | STARTF_TITLEISLINKNAME" );
   if (flags & STARTF_USECOUNTCHARS    == STARTF_USECOUNTCHARS   ) result = StringConcatenate(result, " | STARTF_USECOUNTCHARS"   );
   if (flags & STARTF_USEFILLATTRIBUTE == STARTF_USEFILLATTRIBUTE) result = StringConcatenate(result, " | STARTF_USEFILLATTRIBUTE");
   if (flags & STARTF_USEHOTKEY        == STARTF_USEHOTKEY       ) result = StringConcatenate(result, " | STARTF_USEHOTKEY"       );
   if (flags & STARTF_USEPOSITION      == STARTF_USEPOSITION     ) result = StringConcatenate(result, " | STARTF_USEPOSITION"     );
   if (flags & STARTF_USESHOWWINDOW    == STARTF_USESHOWWINDOW   ) result = StringConcatenate(result, " | STARTF_USESHOWWINDOW"   );
   if (flags & STARTF_USESIZE          == STARTF_USESIZE         ) result = StringConcatenate(result, " | STARTF_USESIZE"         );
   if (flags & STARTF_USESTDHANDLES    == STARTF_USESTDHANDLES   ) result = StringConcatenate(result, " | STARTF_USESTDHANDLES"   );

   if (StringLen(result) > 0)
      result = StringSubstr(result, 3);
   return(result);
}


/**
 * Gibt die lesbare Version einer STARTUPINFO ShowWindow-Command-ID zurück.
 *
 * @param  int& si[] - STARTUPINFO structure
 *
 * @return string
 */
string si.ShowWindowToStr(/*STARTUPINFO*/ int& si[]) {
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
 * typedef struct _SYSTEMTIME {
 *    WORD wYear;
 *    WORD wMonth;
 *    WORD wDayOfWeek;
 *    WORD wDay;
 *    WORD wHour;
 *    WORD wMinute;
 *    WORD wSecond;
 *    WORD wMilliseconds;
 * } SYSTEMTIME, st;       // = 16 byte = int[4]
 *
 * StructToHexStr(SYSTEMTIME) = DB070100 06000F00 12003600 05000A03
 */
int st.Year     (/*SYSTEMTIME*/ int& st[]) { return(st[0] &  0x0000FFFF); }
int st.Month    (/*SYSTEMTIME*/ int& st[]) { return(st[0] >> 16        ); }
int st.DayOfWeek(/*SYSTEMTIME*/ int& st[]) { return(st[1] &  0x0000FFFF); }
int st.Day      (/*SYSTEMTIME*/ int& st[]) { return(st[1] >> 16        ); }
int st.Hour     (/*SYSTEMTIME*/ int& st[]) { return(st[2] &  0x0000FFFF); }
int st.Minute   (/*SYSTEMTIME*/ int& st[]) { return(st[2] >> 16        ); }
int st.Second   (/*SYSTEMTIME*/ int& st[]) { return(st[3] &  0x0000FFFF); }
int st.MilliSec (/*SYSTEMTIME*/ int& st[]) { return(st[3] >> 16        ); }


/**
 * Win32 structure TIME_ZONE_INFORMATION
 *
 * typedef struct _TIME_ZONE_INFORMATION {
 *    LONG       Bias;                //     4     => tzi[ 0]     Formeln:               GMT = UTC
 *    WCHAR      StandardName[32];    //    64     => tzi[ 1]     --------              Bias = -Offset
 *    SYSTEMTIME StandardDate;        //    16     => tzi[17]               LocalTime + Bias = GMT        (LocalTime -> GMT)
 *    LONG       StandardBias;        //     4     => tzi[21]                   GMT + Offset = LocalTime  (GMT -> LocalTime)
 *    WCHAR      DaylightName[32];    //    64     => tzi[22]
 *    SYSTEMTIME DaylightDate;        //    16     => tzi[38]
 *    LONG       DaylightBias;        //     4     => tzi[42]
 * } TIME_ZONE_INFORMATION, tzi;      // = 172 byte = int[43]
 *
 * StructToHexStr(TIME_ZONE_INFORMATION) = 88FFFFFF
 *                                         47005400 42002000 4E006F00 72006D00 61006C00 7A006500 69007400 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                         G   T    B   .    N   o    r   m    a   l    z   e    i   t
 *                                         00000A00 00000500 04000000 00000000
 *                                         00000000
 *                                         47005400 42002000 53006F00 6D006D00 65007200 7A006500 69007400 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
 *                                         G   T    B   .    S   o    m   m    e   r    z   e    i   t
 *                                         00000300 00000500 03000000 00000000
 *                                         C4FFFFFF
 */
int    tzi.Bias        (/*TIME_ZONE_INFORMATION*/ int& tzi[])                           { return(tzi[0]); }                               // Bias in Minuten
string tzi.StandardName(/*TIME_ZONE_INFORMATION*/ int& tzi[])                           { return(StructWCharToStr(tzi, 1, 16)); }
void   tzi.StandardDate(/*TIME_ZONE_INFORMATION*/ int& tzi[], /*SYSTEMTIME*/ int& st[]) { ArrayCopy(st, tzi, 0, 17, 4); }
int    tzi.StandardBias(/*TIME_ZONE_INFORMATION*/ int& tzi[])                           { return(tzi[21]); }                              // Bias in Minuten
string tzi.DaylightName(/*TIME_ZONE_INFORMATION*/ int& tzi[])                           { return(StructWCharToStr(tzi, 22, 16)); }
void   tzi.DaylightDate(/*TIME_ZONE_INFORMATION*/ int& tzi[], /*SYSTEMTIME*/ int& st[]) { ArrayCopy(st, tzi, 0, 38, 4); }
int    tzi.DaylightBias(/*TIME_ZONE_INFORMATION*/ int& tzi[])                           { return(tzi[42]); }                              // Bias in Minuten


/**
 * Gibt den Inhalt einer Structure als hexadezimalen String zurück.
 *
 * @param  int& lpStruct[]
 *
 * @return string
 */
string StructToHexStr(int& lpStruct[]) {
   string result = "";
   int size = ArraySize(lpStruct);

   // Structs werden in MQL mit Hilfe von Integer-Arrays nachgebildet. Integers sind interpretierte binäre Werte (Reihenfolge von HIBYTE, LOBYTE, HIWORD, LOWORD).
   // Diese Interpretation muß wieder rückgängig gemacht werden.
   for (int i=0; i < size; i++) {
      string hex   = IntToHexStr(lpStruct[i]);
      string byte1 = StringSubstr(hex, 6, 2);
      string byte2 = StringSubstr(hex, 4, 2);
      string byte3 = StringSubstr(hex, 2, 2);
      string byte4 = StringSubstr(hex, 0, 2);
      result = StringConcatenate(result, " ", byte1, byte2, byte3, byte4);
   }

   if (size > 0)
      result = StringSubstr(result, 1);

   if (catch("StructToHexStr()") != NO_ERROR)
      return("");
   return(result);
}


/**
 * Gibt den Inhalt einer Structure als lesbaren String zurück. Nicht darstellbare Zeichen werden als Punkt "." dargestellt.
 * Nützlich, um im Struct enthaltene Strings schnell identifizieren zu können.
 *
 * @param  int& lpStruct[]
 *
 * @return string
 */
string StructToStr(int& lpStruct[]) {
   string result = "";
   int size = ArraySize(lpStruct);

   for (int i=0; i < size; i++) {
      string strInt = "0000";
      int value, shift=24, integer=lpStruct[i];

      // Structs werden in MQL mit Hilfe von Integer-Arrays nachgebildet. Integers sind interpretierte binäre Werte (Reihenfolge von HIBYTE, LOBYTE, HIWORD, LOWORD).
      // Diese Interpretation muß wieder rückgängig gemacht werden.
      for (int n=0; n < 4; n++) {
         value = (integer >> shift) & 0xFF;                                // Integer in Bytes zerlegen
         if (value < 0x20) strInt = StringSetChar(strInt, 3-n, '.');
         else              strInt = StringSetChar(strInt, 3-n, value);     // jedes Byte an der richtigen Stelle darstellen
         shift -= 8;
      }
      result = StringConcatenate(result, strInt);
   }

   if (catch("StructToStr()") != NO_ERROR)
      return("");
   return(result);
}


/**
 * Gibt den in einer Structure im angegebenen Bereich gespeicherten und mit einem NULL-Character terminierten ANSI-String zurück.
 *
 * @param  int& lpStruct[] - Structure
 * @param  int  from       - Index des ersten Integers der Charactersequenz
 * @param  int  len        - Anzahl der Integers des im Struct für die Charactersequenz reservierten Bereiches
 *
 * @return string
 *
 *
 * NOTE: Zur Zeit arbeitet diese Funktion nur mit Charactersequenzen, die an Integer-Boundaries beginnen und enden.
 * ----
 */
string StructCharToStr(int& lpStruct[], int from, int len) {
   if (from < 0)
      return(catch("StructCharToStr(1)  invalid parameter from = "+ from, ERR_INVALID_FUNCTION_PARAMVALUE));
   int to = from+len, size=ArraySize(lpStruct);
   if (to > size)
      return(catch("StructCharToStr(2)  invalid parameter len = "+ len, ERR_INVALID_FUNCTION_PARAMVALUE));

   string result = "";

   for (int i=from; i < to; i++) {
      int byte, shift=0, integer=lpStruct[i];

      for (int n=0; n < 4; n++) {
         byte = (integer >> shift) & 0xFF;
         if (byte == 0)                                        // termination character (0x00)
            break;
         result = StringConcatenate(result, CharToStr(byte));
         shift += 8;
      }
      if (byte == 0)
         break;
   }

   if (catch("StructCharToStr(3)") != NO_ERROR)
      return("");
   return(result);
}


/**
 * Gibt den in einer Structure im angegebenen Bereich gespeicherten mit einem NULL-Character terminierten WCHAR-String zurück (Multibyte-Characters).
 *
 * @param  int& lpStruct[] - Structure
 * @param  int  from       - Index des ersten Integers der Charactersequenz
 * @param  int  len        - Anzahl der Integers des im Struct für die Charactersequenz reservierten Bereiches
 *
 * @return string
 *
 *
 * NOTE: Zur Zeit arbeitet diese Funktion nur mit Charactersequenzen, die an Integer-Boundaries beginnen und enden.
 * ----
 */
string StructWCharToStr(int& lpStruct[], int from, int len) {
   if (from < 0)
      return(catch("StructWCharToStr(1)  invalid parameter from = "+ from, ERR_INVALID_FUNCTION_PARAMVALUE));
   int to = from+len, size=ArraySize(lpStruct);
   if (to > size)
      return(catch("StructWCharToStr(2)  invalid parameter len = "+ len, ERR_INVALID_FUNCTION_PARAMVALUE));

   string result = "";

   for (int i=from; i < to; i++) {
      string strChar;
      int word, shift=0, integer=lpStruct[i];

      for (int n=0; n < 2; n++) {
         word = (integer >> shift) & 0xFFFF;
         if (word == 0)                                        // termination character (0x00)
            break;
         int byte1 = (word >> 0) & 0xFF;
         int byte2 = (word >> 8) & 0xFF;

         if (byte1!=0 && byte2==0) strChar = CharToStr(byte1);
         else                      strChar = "?";              // multi-byte character
         result = StringConcatenate(result, strChar);
         shift += 16;
      }
      if (word == 0)
         break;
   }

   if (catch("StructWCharToStr(3)") != NO_ERROR)
      return("");
   return(result);
}


/**
 * Ermittelt den vollständigen Dateipfad der Zieldatei, auf die ein Windows-Shortcut (.lnk-File) zeigt.
 *
 * @return string lnkFile - Pfadangabe zum Shortcut
 *
 * @return string - Dateipfad der Zieldatei
 */
string GetShortcutTarget(string lnkFile) {
   /**
    * --------------------------------------------------------------------------
    *  How to read the target's path from a .lnk-file:
    * --------------------------------------------------------------------------
    *  Problem:
    *
    *     The COM interface to shell32.dll IShellLink::GetPath() fails!
    *
    *  Solution:
    *
    *    We need to parse the file manually. The path can be found like shown
    *    here.  If the shell item id list is not present (as signaled in flags),
    *    we have to assume A = -6.
    *
    *   +-----------------+----------------------------------------------------+
    *   |     Byte-Offset | Description                                        |
    *   +-----------------+----------------------------------------------------+
    *   |               0 | 'L' (magic value)                                  |
    *   +-----------------+----------------------------------------------------+
    *   |            4-19 | GUID                                               |
    *   +-----------------+----------------------------------------------------+
    *   |           20-23 | shortcut flags                                     |
    *   +-----------------+----------------------------------------------------+
    *   |             ... | ...                                                |
    *   +-----------------+----------------------------------------------------+
    *   |           76-77 | A (16 bit): size of shell item id list, if present |
    *   +-----------------+----------------------------------------------------+
    *   |             ... | shell item id list, if present                     |
    *   +-----------------+----------------------------------------------------+
    *   |      78 + 4 + A | B (32 bit): size of file location info             |
    *   +-----------------+----------------------------------------------------+
    *   |             ... | file location info                                 |
    *   +-----------------+----------------------------------------------------+
    *   |      78 + A + B | C (32 bit): size of local volume table             |
    *   +-----------------+----------------------------------------------------+
    *   |             ... | local volume table                                 |
    *   +-----------------+----------------------------------------------------+
    *   |  78 + A + B + C | target path string (ending with 0x00)              |
    *   +-----------------+----------------------------------------------------+
    *   |             ... | ...                                                |
    *   +-----------------+----------------------------------------------------+
    *   |             ... | 0x00                                               |
    *   +-----------------+----------------------------------------------------+
    *
    *  @see http://www.codeproject.com/KB/shell/ReadLnkFile.aspx
    * --------------------------------------------------------------------------
    */
   if (StringLen(lnkFile) < 4 || StringRight(lnkFile, 4)!=".lnk") {
      catch("GetShortcutTarget(1)  invalid parameter lnkFile = \""+ lnkFile +"\"", ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }

   // --------------------------------------------------------------------------
   // Get the .lnk-file content:
   // --------------------------------------------------------------------------
   int hFile = _lopen(string lnkFile, OF_READ);
   if (hFile == HFILE_ERROR) {                     // kernel32::GetLastError() ist nicht erreichbar, Existenz daher manuell prüfen
      if (IsFile(lnkFile)) catch("GetShortcutTarget(2)  access denied to \""+ lnkFile +"\"", ERR_CANNOT_OPEN_FILE);
      else                 catch("GetShortcutTarget(3)  file not found: \""+ lnkFile +"\"", ERR_CANNOT_OPEN_FILE);
      return("");
   }
   int fileSize = GetFileSize(hFile, NULL);
   int ints     = MathCeil(fileSize/4.0);          // noch keinen Weg gefunden, Strings mit 0-Bytes einzulesen, daher int-Array als Buffer
   int buffer[]; ArrayResize(buffer, ints);        // buffer[] ist maximal 3 Bytes größer als notwendig

   int bytes = _lread(hFile, buffer, ints * 4);    // 1 Integer = 4 Bytes
   _lclose(hFile);

   if (bytes != fileSize) {
      catch("GetShortcutTarget(4)  error reading \""+ lnkFile +"\"", ERR_WINDOWS_ERROR);
      return("");
   }
   if (bytes < 24) {
      catch("GetShortcutTarget(5)  unknown .lnk-file format in \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
      return("");
   }

   int charsSize = bytes;
   int chars[]; ArrayResize(chars, charsSize);     // int-Array in char-Array umwandeln
   for (int i, n=0; i < ints; i++) {
      for (int shift=0; shift < 32 && n < charsSize; shift+=8, n++) {
         chars[n] = (buffer[i] >> shift) & 0xFF;
      }
   }

   // --------------------------------------------------------------------------
   // Check the magic value (first byte) and the GUID (16 byte from 5th byte):
   // --------------------------------------------------------------------------
   // The GUID is telling the version of the .lnk-file format. We expect the
   // following GUID (hex): 01 14 02 00 00 00 00 00 C0 00 00 00 00 00 00 46.
   // --------------------------------------------------------------------------
   if (chars[0] != 'L') {                          // test the magic value
      catch("GetShortcutTarget(6)  unknown .lnk-file format in \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
      return("");
   }
   if (chars[ 4] != 0x01 ||                        // test the GUID
       chars[ 5] != 0x14 ||
       chars[ 6] != 0x02 ||
       chars[ 7] != 0x00 ||
       chars[ 8] != 0x00 ||
       chars[ 9] != 0x00 ||
       chars[10] != 0x00 ||
       chars[11] != 0x00 ||
       chars[12] != 0xC0 ||
       chars[13] != 0x00 ||
       chars[14] != 0x00 ||
       chars[15] != 0x00 ||
       chars[16] != 0x00 ||
       chars[17] != 0x00 ||
       chars[18] != 0x00 ||
       chars[19] != 0x46) {
      catch("GetShortcutTarget(7)  unknown .lnk-file format in \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
      return("");
   }

   // --------------------------------------------------------------------------
   // Get the flags (4 byte from 21st byte) and
   // --------------------------------------------------------------------------
   // Check if it points to a file or directory.
   // --------------------------------------------------------------------------
   // Flags (4 byte little endian):
   //        Bit 0 -> has shell item id list
   //        Bit 1 -> points to file or directory
   //        Bit 2 -> has description
   //        Bit 3 -> has relative path
   //        Bit 4 -> has working directory
   //        Bit 5 -> has commandline arguments
   //        Bit 6 -> has custom icon
   // --------------------------------------------------------------------------
   int dwFlags  = chars[20];
       dwFlags |= chars[21] <<  8;
       dwFlags |= chars[22] << 16;
       dwFlags |= chars[23] << 24;

   bool hasShellItemIdList = (dwFlags & 0x00000001 == 0x00000001);
   bool pointsToFileOrDir  = (dwFlags & 0x00000002 == 0x00000002);

   if (!pointsToFileOrDir) {
      log("GetShortcutTarget(8)  shortcut target is not a file or directory: \""+ lnkFile +"\"");
      return("");
   }

   // --------------------------------------------------------------------------
   // Shell item id list (starts at offset 76 with 2 byte length):
   // --------------------------------------------------------------------------
   int A = -6;
   if (hasShellItemIdList) {
      i = 76;
      if (charsSize < i+2) {
         catch("GetShortcutTarget(9)  unknown .lnk-file format in \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
         return("");
      }
      A  = chars[76];               // little endian format
      A |= chars[77] << 8;
   }

   // --------------------------------------------------------------------------
   // File location info:
   // --------------------------------------------------------------------------
   // Follows the shell item id list and starts with 4 byte structure length,
   // followed by 4 byte offset.
   // --------------------------------------------------------------------------
   i = 78 + 4 + A;
   if (charsSize < i+4) {
      catch("GetShortcutTarget(10)  unknown .lnk-file format in \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
      return("");
   }
   int B  = chars[i];       i++;    // little endian format
       B |= chars[i] <<  8; i++;
       B |= chars[i] << 16; i++;
       B |= chars[i] << 24;

   // --------------------------------------------------------------------------
   // Local volume table:
   // --------------------------------------------------------------------------
   // Follows the file location info and starts with 4 byte table length for
   // skipping the actual table and moving to the local path string.
   // --------------------------------------------------------------------------
   i = 78 + A + B;
   if (charsSize < i+4) {
      catch("GetShortcutTarget(11)  unknown .lnk-file format in \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
      return("");
   }
   int C  = chars[i];       i++;    // little endian format
       C |= chars[i] <<  8; i++;
       C |= chars[i] << 16; i++;
       C |= chars[i] << 24;

   // --------------------------------------------------------------------------
   // Local path string (ending with 0x00):
   // --------------------------------------------------------------------------
   i = 78 + A + B + C;
   if (charsSize < i+1) {
      catch("GetShortcutTarget(12)  unknown .lnk-file format in \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
      return("");
   }
   string target = "";
   for (; i < charsSize; i++) {
      if (chars[i] == 0x00)
         break;
      target = StringConcatenate(target, CharToStr(chars[i]));
   }
   if (StringLen(target) == 0) {
      catch("GetShortcutTarget(13)  invalid target in .lnk-file \""+ lnkFile +"\"", ERR_RUNTIME_ERROR);
      return("");
   }

   // --------------------------------------------------------------------------
   // Convert the target path into the long filename format:
   // --------------------------------------------------------------------------
   // GetLongPathNameA() fails it the target file doesn't exist!
   // --------------------------------------------------------------------------
   string lfnBuffer[1]; lfnBuffer[0] = StringConcatenate(MAX_STRING_LITERAL, ".....");    // 255 + 5 = MAX_PATH

   if (!GetLongPathNameA(target, lfnBuffer[0], MAX_PATH))
      return(target);                                                                     // file doesn't exist
   target = lfnBuffer[0];

   //debug("GetShortcutTarget()   chars = "+ ArraySize(chars) +"   A = "+ A +"   B = "+ B +"   C = "+ C +"   target = "+ target);

   if (catch("GetShortcutTarget(14)") != NO_ERROR)
      return("");
   return(target);
}


int WM_MT4;    // überdauert Timeframe-Wechsel

/**
 * Schickt einen einzelnen Fake-Tick an den aktuellen Chart.
 *
 * @param  bool sound - ob der Tick akustisch bestätigt werden soll oder nicht (default: nein)
 *
 * @return int - Fehlerstatus (-1, wenn das Script im Backtester läuft und WindowHandle() nicht benutzt werden kann)
 */
int SendTick(bool sound=false) {
   if (IsTesting())
      return(-1);

   if (WM_MT4 == 0)
      WM_MT4 = RegisterWindowMessageA("MetaTrader4_Internal_Message");

   int hWnd = WindowHandle(Symbol(), Period());
   PostMessageA(hWnd, WM_MT4, 2, 1);

   if (sound)
      PlaySound("tick1.wav");

   return(catch("SendTick()"));
}


/**
 * Gibt das History-Verzeichnis des aktuellen Tradeservers zurück.
 *
 * @return string
 */
string GetTradeServerDirectory() {
   string serverDirectory = "";

   // eindeutigen Dateinamen erzeugen und temporäre Datei anlegen
   string fileName = StringConcatenate("_t", GetCurrentThreadId(), ".tmp");

   int hFile = FileOpenHistory(fileName, FILE_BIN|FILE_WRITE);
   if (hFile < 0) {
      catch("GetTradeServerDirectory(1)  FileOpenHistory(\""+ fileName +"\")");
      return("");
   }
   FileClose(hFile);

   // Datei suchen und Tradeserver-Pfad auslesen
   string pattern = StringConcatenate(TerminalPath(), "\\history\\*");
   int /*WIN32_FIND_DATA*/ wfd[80];

   int hFindDir=FindFirstFileA(pattern, wfd), result=hFindDir;
   while (result > 0) {
      if (wfd.FileAttribute.Directory(wfd)) {
         string name = wfd.FileName(wfd);
         if (name != ".") /*&&*/ if (name != "..") {
            pattern = StringConcatenate(TerminalPath(), "\\history\\", name, "\\", fileName);
            int hFindFile=FindFirstFileA(pattern, wfd);
            if (hFindFile != INVALID_HANDLE_VALUE) {     // hier müßte eigentlich auf ERR_FILE_NOT_FOUND geprüft werden, doch MQL kann es nicht
               //debug("FindTradeServerDirectory()   file = "+ pattern +"   found");

               FindClose(hFindFile);
               serverDirectory = name;
               if (!DeleteFileA(pattern))                // tmp. Datei per Win-API löschen (MQL kann es im History-Verzeichnis nicht)
                  return(catch("GetTradeServerDirectory(2)   kernel32.DeleteFile(\""+ pattern +"\") => FALSE", ERR_WINDOWS_ERROR));
               break;
            }
         }
      }
      result = FindNextFileA(hFindDir, wfd);
   }
   if (result == INVALID_HANDLE_VALUE) {
      catch("GetTradeServerDirectory(3)  kernel32.FindFirstFile(\""+ pattern +"\") => INVALID_HANDLE_VALUE", ERR_WINDOWS_ERROR);
      return("");
   }
   FindClose(hFindDir);

   //debug("GetTradeServerDirectory()   serverDirectory = "+ serverDirectory);

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetTradeServerDirectory(4)", error);
      return("");
   }
   if (serverDirectory == "")
      catch("GetTradeServerDirectory(5)  cannot find trade server directory", ERR_RUNTIME_ERROR);
   return(serverDirectory);
}


/**
 * Gibt das files-Verzeichnis des angegebenen Accounts zurück.
 *
 * @param  int account - Account-Nummer
 *
 * @return string - Verzeichnisname, relativ zu "{terminal-directory}\experts\files"
 */
string GetAccountDirectory(int account) {
   switch (account) {
      case     {account-no}: return("AlpariUK-Demo"        );
      case    {account-no}: return("AlpariUK-Demo"        );
      case    {account-no}: return("AlpariUK-Micro-2"     );
      case    {account-no}: return("AlpariUK-Micro-1"     );
      case   {account-no}: return("APBGTrading-Server"   );
      case      {account-no}: return("ATCBrokers-Demo"      );
      case     {account-no}: return("ATCBrokers-Live"      );
      case      {account-no}: return("ForexBaltic-Server"   );
      case {account-no}: return("MBTrading-Demo Server");
      case     {account-no}: return("SIG-Real.com"         );
      case    {account-no}: return("FOREX-Server"         );
   }

   log("GetAccountDirectory()   unknown files directory for account #"+ AccountNumber());
   return(AccountNumber());
}


/**
 * Führt eine Anwendung aus und wartet, bis sie beendet ist.
 *
 * @param  string cmdLine - Befehlszeile
 * @param  int    cmdShow - ShowWindow() command id
 *
 * @return int - Fehlerstatus
 */
int WinExecAndWait(string cmdLine, int cmdShow) {
   int /*STARTUPINFO*/ si[17]; ArrayInitialize(si, 0);
      si.setCb        (si, 68);
      si.setFlags     (si, STARTF_USESHOWWINDOW);
      si.setShowWindow(si, cmdShow);
   int /*PROCESS_INFORMATION*/ pi[4]; ArrayInitialize(pi, 0);

   if (!CreateProcessA(NULL, cmdLine, NULL, NULL, false, 0, NULL, NULL, si, pi))
      return(catch("WinExecAndWait(1)   CreateProcess() failed", ERR_WINDOWS_ERROR));

   int result = WaitForSingleObject(pi.hProcess(pi), INFINITE);

   if (result != WAIT_OBJECT_0) {
      if (result == WAIT_FAILED) catch("WinExecAndWait(2)   WaitForSingleObject() => WAIT_FAILED", ERR_WINDOWS_ERROR);
      else                       log("WinExecAndWait()   WaitForSingleObject() => "+ WaitForSingleObjectToStr(result));
   }

   CloseHandle(pi.hProcess(pi));
   CloseHandle(pi.hThread(pi));

   return(catch("WinExecAndWait(3)"));
}


/**
 * Liest eine Datei zeilenweise (ohne Zeilenende-Zeichen) in ein Array ein.
 *
 * @param  string  filename       - Dateiname mit zu "{terminal-path}\experts\files" relativer Pfadangabe
 * @param  string& lpResult[]     - Zeiger auf ein Ergebnisarray für die Zeilen der Datei
 * @param  bool    skipEmptyLines - ob leere Zeilen übersprungen werden sollen oder nicht (default: FALSE)
 *
 * @return int - Fehlerstatus
 */
int FileReadLines(string filename, string& lpResult[], bool skipEmptyLines=false) {
   int fieldSeparator = '\t';

   // Datei öffnen
   int hFile = FileOpen(filename, FILE_CSV|FILE_READ, fieldSeparator);  // FileOpen() erwartet Pfadangabe relativ zu .\experts\files
   if (hFile < 0)
      return(catch("FileReadLines(1)   FileOpen(\""+ filename +"\")", GetLastError()));


   // Schnelle Rückkehr bei leerer Datei
   if (FileSize(hFile) == 0) {
      ArrayResize(lpResult, 0);
      return(catch("FileReadLines(2)"));
   }


   // Datei zeilenweise einlesen
   bool newLine=true, blankLine=false, lineEnd=true;
   string line, lines[]; ArrayResize(lines, 0);                         // Zwischenspeicher für gelesene Zeilen
   int i = 0;                                                           // Zeilenzähler

   while (!FileIsEnding(hFile)) {
      newLine = false;
      if (lineEnd) {                                                    // Wenn beim letzten Durchlauf das Zeilenende erreicht wurde,
         newLine   = true;                                              // Flags auf Zeilenbeginn setzen.
         blankLine = false;
         lineEnd   = false;
      }

      // Zeile auslesen
      string value = FileReadString(hFile);

      // auf Zeilen- und Dateiende prüfen
      if (FileIsLineEnding(hFile) || FileIsEnding(hFile)) {
         lineEnd = true;
         if (newLine) {
            if (StringLen(value) == 0) {
               if (FileIsEnding(hFile))                                 // Zeilenbeginn + Leervalue + Dateiende  => nichts, also Abbruch
                  break;
               blankLine = true;                                        // Zeilenbeginn + Leervalue + Zeilenende => Leerzeile
            }
         }
      }

      // Leerzeilen ggf. überspringen
      if (blankLine) /*&&*/ if (skipEmptyLines)
         continue;

      // Wert in neuer Zeile speichern oder vorherige Zeile aktualisieren
      if (newLine) {
         i++;
         ArrayResize(lines, i);
         lines[i-1] = value;
         //log("FileReadLines()   new line = \""+ lines[i-1] +"\"");
      }
      else {
         lines[i-1] = StringConcatenate(lines[i-1], CharToStr(fieldSeparator), value);
         //log("FileReadLines()   updated line = \""+ lines[i-1] +"\"");
      }
   }

   // Dateiende hat ERR_END_OF_FILE ausgelöst
   int error = GetLastError();
   if (error!=ERR_END_OF_FILE) /*&&*/ if (error!=NO_ERROR)
      return(catch("FileReadLines(2)", error));

   // Datei schließen
   FileClose(hFile);

   // Zeilen in Ergebnisarray kopieren
   ArrayResize(lpResult, i);
   if (i > 0)
      ArrayCopy(lpResult, lines);

   return(catch("FileReadLines(3)"));
}


/**
 * Gibt die lesbare Version eines Rückgabewertes von WaitForSingleObject() zurück.
 *
 * @param  int value - Rückgabewert
 *
 * @return string
 */
string WaitForSingleObjectToStr(int value) {
   switch (value) {
      case WAIT_FAILED   : return("WAIT_FAILED"   );
      case WAIT_ABANDONED: return("WAIT_ABANDONED");
      case WAIT_OBJECT_0 : return("WAIT_OBJECT_0" );
      case WAIT_TIMEOUT  : return("WAIT_TIMEOUT"  );
   }
   return("");
}


/**
 * Gibt für ein broker-spezifisches das allgemeingültige Symbol zurück.
 *
 * @param  string symbol - broker-spezifisches Symbol
 *
 * @return string - allgemeingültiges Symbol oder "", wenn kein allgemeingültiges Symbol gefunden wurde
 */
string NormalizeSymbol(string symbol) {
   symbol = StringToUpper(symbol);

   if      (StringEndsWith(symbol, "_ASK")) symbol = StringLeft(symbol, -4);
   else if (StringEndsWith(symbol, "_AVG")) symbol = StringLeft(symbol, -4);

   if (symbol == "#DAX.XEI" ) return("#DAX.X"  );
   if (symbol == "#DJI.XDJ" ) return("#DJI.X"  );
   if (symbol == "#DJT.XDJ" ) return("#DJT.X"  );
   if (symbol == "#SPX.X.XP") return("#SPX.X"  );
   if (symbol == "AUDCAD"   ) return("AUDCAD"  );
   if (symbol == "AUDCADMA" ) return("AUDCAD"  );
   if (symbol == "AUDCADMB" ) return("AUDCAD"  );
   if (symbol == "AUDCADMC" ) return("AUDCAD"  );
   if (symbol == "AUDCADMD" ) return("AUDCAD"  );
   if (symbol == "AUDCADX"  ) return("AUDCAD"  );
   if (symbol == "AUDCHF"   ) return("AUDCHF"  );
   if (symbol == "AUDCHFMA" ) return("AUDCHF"  );
   if (symbol == "AUDCHFMB" ) return("AUDCHF"  );
   if (symbol == "AUDCHFMC" ) return("AUDCHF"  );
   if (symbol == "AUDCHFMD" ) return("AUDCHF"  );
   if (symbol == "AUDCHFX"  ) return("AUDCHF"  );
   if (symbol == "AUDJPY"   ) return("AUDJPY"  );
   if (symbol == "AUDJPYMA" ) return("AUDJPY"  );
   if (symbol == "AUDJPYMB" ) return("AUDJPY"  );
   if (symbol == "AUDJPYMC" ) return("AUDJPY"  );
   if (symbol == "AUDJPYMD" ) return("AUDJPY"  );
   if (symbol == "AUDJPYX"  ) return("AUDJPY"  );
   if (symbol == "AUDLFX"   ) return("AUDLFX"  );
   if (symbol == "AUDNZD"   ) return("AUDNZD"  );
   if (symbol == "AUDNZDMA" ) return("AUDNZD"  );
   if (symbol == "AUDNZDMB" ) return("AUDNZD"  );
   if (symbol == "AUDNZDMC" ) return("AUDNZD"  );
   if (symbol == "AUDNZDMD" ) return("AUDNZD"  );
   if (symbol == "AUDNZDX"  ) return("AUDNZD"  );
   if (symbol == "AUDUSD"   ) return("AUDUSD"  );
   if (symbol == "AUDUSDMA" ) return("AUDUSD"  );
   if (symbol == "AUDUSDMB" ) return("AUDUSD"  );
   if (symbol == "AUDUSDMC" ) return("AUDUSD"  );
   if (symbol == "AUDUSDMD" ) return("AUDUSD"  );
   if (symbol == "AUDUSDX"  ) return("AUDUSD"  );
   if (symbol == "CADCHF"   ) return("CADCHF"  );
   if (symbol == "CADCHFMA" ) return("CADCHF"  );
   if (symbol == "CADCHFMB" ) return("CADCHF"  );
   if (symbol == "CADCHFMC" ) return("CADCHF"  );
   if (symbol == "CADCHFMD" ) return("CADCHF"  );
   if (symbol == "CADCHFX"  ) return("CADCHF"  );
   if (symbol == "CADJPY"   ) return("CADJPY"  );
   if (symbol == "CADJPYMA" ) return("CADJPY"  );
   if (symbol == "CADJPYMB" ) return("CADJPY"  );
   if (symbol == "CADJPYMC" ) return("CADJPY"  );
   if (symbol == "CADJPYMD" ) return("CADJPY"  );
   if (symbol == "CADJPYX"  ) return("CADJPY"  );
   if (symbol == "CADLFX"   ) return("CADLFX"  );
   if (symbol == "CHFJPY"   ) return("CHFJPY"  );
   if (symbol == "CHFJPYMA" ) return("CHFJPY"  );
   if (symbol == "CHFJPYMB" ) return("CHFJPY"  );
   if (symbol == "CHFJPYMC" ) return("CHFJPY"  );
   if (symbol == "CHFJPYMD" ) return("CHFJPY"  );
   if (symbol == "CHFJPYX"  ) return("CHFJPY"  );
   if (symbol == "CHFLFX"   ) return("CHFLFX"  );
   if (symbol == "EURAUD"   ) return("EURAUD"  );
   if (symbol == "EURAUDMA" ) return("EURAUD"  );
   if (symbol == "EURAUDMB" ) return("EURAUD"  );
   if (symbol == "EURAUDMC" ) return("EURAUD"  );
   if (symbol == "EURAUDMD" ) return("EURAUD"  );
   if (symbol == "EURAUDX"  ) return("EURAUD"  );
   if (symbol == "EURCAD"   ) return("EURCAD"  );
   if (symbol == "EURCADMA" ) return("EURCAD"  );
   if (symbol == "EURCADMB" ) return("EURCAD"  );
   if (symbol == "EURCADMC" ) return("EURCAD"  );
   if (symbol == "EURCADMD" ) return("EURCAD"  );
   if (symbol == "EURCADX"  ) return("EURCAD"  );
   if (symbol == "EURCHF"   ) return("EURCHF"  );
   if (symbol == "EURCHFMA" ) return("EURCHF"  );
   if (symbol == "EURCHFMB" ) return("EURCHF"  );
   if (symbol == "EURCHFMC" ) return("EURCHF"  );
   if (symbol == "EURCHFMD" ) return("EURCHF"  );
   if (symbol == "EURCHFX"  ) return("EURCHF"  );
   if (symbol == "EURDKK"   ) return("EURDKK"  );
   if (symbol == "EURDKKMA" ) return("EURDKK"  );
   if (symbol == "EURDKKMB" ) return("EURDKK"  );
   if (symbol == "EURDKKMC" ) return("EURDKK"  );
   if (symbol == "EURDKKMD" ) return("EURDKK"  );
   if (symbol == "EURDKKX"  ) return("EURDKK"  );
   if (symbol == "EURGBP"   ) return("EURGBP"  );
   if (symbol == "EURGBPMA" ) return("EURGBP"  );
   if (symbol == "EURGBPMB" ) return("EURGBP"  );
   if (symbol == "EURGBPMC" ) return("EURGBP"  );
   if (symbol == "EURGBPMD" ) return("EURGBP"  );
   if (symbol == "EURGBPX"  ) return("EURGBP"  );
   if (symbol == "EURJPY"   ) return("EURJPY"  );
   if (symbol == "EURJPYMA" ) return("EURJPY"  );
   if (symbol == "EURJPYMB" ) return("EURJPY"  );
   if (symbol == "EURJPYMC" ) return("EURJPY"  );
   if (symbol == "EURJPYMD" ) return("EURJPY"  );
   if (symbol == "EURJPYX"  ) return("EURJPY"  );
   if (symbol == "EURLFX"   ) return("EURLFX"  );
   if (symbol == "EURNOK"   ) return("EURNOK"  );
   if (symbol == "EURNOKMA" ) return("EURNOK"  );
   if (symbol == "EURNOKMB" ) return("EURNOK"  );
   if (symbol == "EURNOKMC" ) return("EURNOK"  );
   if (symbol == "EURNOKMD" ) return("EURNOK"  );
   if (symbol == "EURNOKX"  ) return("EURNOK"  );
   if (symbol == "EURNZD"   ) return("EURNZD"  );
   if (symbol == "EURNZDMA" ) return("EURNZD"  );
   if (symbol == "EURNZDMB" ) return("EURNZD"  );
   if (symbol == "EURNZDMC" ) return("EURNZD"  );
   if (symbol == "EURNZDMD" ) return("EURNZD"  );
   if (symbol == "EURNZDX"  ) return("EURNZD"  );
   if (symbol == "EURRUR"   ) return("EURRUR"  );
   if (symbol == "EURRURMA" ) return("EURRUR"  );
   if (symbol == "EURRURMB" ) return("EURRUR"  );
   if (symbol == "EURRURMC" ) return("EURRUR"  );
   if (symbol == "EURRURMD" ) return("EURRUR"  );
   if (symbol == "EURRURX"  ) return("EURRUR"  );
   if (symbol == "EURSEK"   ) return("EURSEK"  );
   if (symbol == "EURSEKMA" ) return("EURSEK"  );
   if (symbol == "EURSEKMB" ) return("EURSEK"  );
   if (symbol == "EURSEKMC" ) return("EURSEK"  );
   if (symbol == "EURSEKMD" ) return("EURSEK"  );
   if (symbol == "EURSEKX"  ) return("EURSEK"  );
   if (symbol == "EURUSD"   ) return("EURUSD"  );
   if (symbol == "EURUSDMA" ) return("EURUSD"  );
   if (symbol == "EURUSDMB" ) return("EURUSD"  );
   if (symbol == "EURUSDMC" ) return("EURUSD"  );
   if (symbol == "EURUSDMD" ) return("EURUSD"  );
   if (symbol == "EURUSDX"  ) return("EURUSD"  );
   if (symbol == "EURX"     ) return("EURX"    );
   if (symbol == "GBPAUD"   ) return("GBPAUD"  );
   if (symbol == "GBPAUDMA" ) return("GBPAUD"  );
   if (symbol == "GBPAUDMB" ) return("GBPAUD"  );
   if (symbol == "GBPAUDMC" ) return("GBPAUD"  );
   if (symbol == "GBPAUDMD" ) return("GBPAUD"  );
   if (symbol == "GBPAUDX"  ) return("GBPAUD"  );
   if (symbol == "GBPCAD"   ) return("GBPCAD"  );
   if (symbol == "GBPCADMA" ) return("GBPCAD"  );
   if (symbol == "GBPCADMB" ) return("GBPCAD"  );
   if (symbol == "GBPCADMC" ) return("GBPCAD"  );
   if (symbol == "GBPCADMD" ) return("GBPCAD"  );
   if (symbol == "GBPCADX"  ) return("GBPCAD"  );
   if (symbol == "GBPCHF"   ) return("GBPCHF"  );
   if (symbol == "GBPCHFMA" ) return("GBPCHF"  );
   if (symbol == "GBPCHFMB" ) return("GBPCHF"  );
   if (symbol == "GBPCHFMC" ) return("GBPCHF"  );
   if (symbol == "GBPCHFMD" ) return("GBPCHF"  );
   if (symbol == "GBPCHFX"  ) return("GBPCHF"  );
   if (symbol == "GBPJPY"   ) return("GBPJPY"  );
   if (symbol == "GBPJPYMA" ) return("GBPJPY"  );
   if (symbol == "GBPJPYMB" ) return("GBPJPY"  );
   if (symbol == "GBPJPYMC" ) return("GBPJPY"  );
   if (symbol == "GBPJPYMD" ) return("GBPJPY"  );
   if (symbol == "GBPJPYX"  ) return("GBPJPY"  );
   if (symbol == "GBPLFX"   ) return("GBPLFX"  );
   if (symbol == "GBPNZD"   ) return("GBPNZD"  );
   if (symbol == "GBPNZDMA" ) return("GBPNZD"  );
   if (symbol == "GBPNZDMB" ) return("GBPNZD"  );
   if (symbol == "GBPNZDMC" ) return("GBPNZD"  );
   if (symbol == "GBPNZDMD" ) return("GBPNZD"  );
   if (symbol == "GBPNZDX"  ) return("GBPNZD"  );
   if (symbol == "GBPRUR"   ) return("GBPRUR"  );
   if (symbol == "GBPRURMA" ) return("GBPRUR"  );
   if (symbol == "GBPRURMB" ) return("GBPRUR"  );
   if (symbol == "GBPRURMC" ) return("GBPRUR"  );
   if (symbol == "GBPRURMD" ) return("GBPRUR"  );
   if (symbol == "GBPRURX"  ) return("GBPRUR"  );
   if (symbol == "GBPUSD"   ) return("GBPUSD"  );
   if (symbol == "GBPUSDMA" ) return("GBPUSD"  );
   if (symbol == "GBPUSDMB" ) return("GBPUSD"  );
   if (symbol == "GBPUSDMC" ) return("GBPUSD"  );
   if (symbol == "GBPUSDMD" ) return("GBPUSD"  );
   if (symbol == "GBPUSDX"  ) return("GBPUSD"  );
   if (symbol == "GOLD"     ) return("XAUUSD"  );
   if (symbol == "LFXJPY"   ) return("JPYLFX"  );
   if (symbol == "NZDCAD"   ) return("NZDCAD"  );
   if (symbol == "NZDCADMA" ) return("NZDCAD"  );
   if (symbol == "NZDCADMB" ) return("NZDCAD"  );
   if (symbol == "NZDCADMC" ) return("NZDCAD"  );
   if (symbol == "NZDCADMD" ) return("NZDCAD"  );
   if (symbol == "NZDCADX"  ) return("NZDCAD"  );
   if (symbol == "NZDCHF"   ) return("NZDCHF"  );
   if (symbol == "NZDCHFMA" ) return("NZDCHF"  );
   if (symbol == "NZDCHFMB" ) return("NZDCHF"  );
   if (symbol == "NZDCHFMC" ) return("NZDCHF"  );
   if (symbol == "NZDCHFMD" ) return("NZDCHF"  );
   if (symbol == "NZDCHFX"  ) return("NZDCHF"  );
   if (symbol == "NZDJPY"   ) return("NZDJPY"  );
   if (symbol == "NZDJPYMA" ) return("NZDJPY"  );
   if (symbol == "NZDJPYMB" ) return("NZDJPY"  );
   if (symbol == "NZDJPYMC" ) return("NZDJPY"  );
   if (symbol == "NZDJPYMD" ) return("NZDJPY"  );
   if (symbol == "NZDJPYX"  ) return("NZDJPY"  );
   if (symbol == "NZDLFX"   ) return("NZDLFX"  );
   if (symbol == "NZDUSD"   ) return("NZDUSD"  );
   if (symbol == "NZDUSDMA" ) return("NZDUSD"  );
   if (symbol == "NZDUSDMB" ) return("NZDUSD"  );
   if (symbol == "NZDUSDMC" ) return("NZDUSD"  );
   if (symbol == "NZDUSDMD" ) return("NZDUSD"  );
   if (symbol == "NZDUSDX"  ) return("NZDUSD"  );
   if (symbol == "SGDJPY"   ) return("SGDJPY"  );
   if (symbol == "SGDJPYMA" ) return("SGDJPY"  );
   if (symbol == "SGDJPYMB" ) return("SGDJPY"  );
   if (symbol == "SGDJPYMC" ) return("SGDJPY"  );
   if (symbol == "SGDJPYMD" ) return("SGDJPY"  );
   if (symbol == "SGDJPYX"  ) return("SGDJPY"  );
   if (symbol == "USDCAD"   ) return("USDCAD"  );
   if (symbol == "USDCADMA" ) return("USDCAD"  );
   if (symbol == "USDCADMB" ) return("USDCAD"  );
   if (symbol == "USDCADMC" ) return("USDCAD"  );
   if (symbol == "USDCADMD" ) return("USDCAD"  );
   if (symbol == "USDCADX"  ) return("USDCAD"  );
   if (symbol == "USDCHF"   ) return("USDCHF"  );
   if (symbol == "USDCHFMA" ) return("USDCHF"  );
   if (symbol == "USDCHFMB" ) return("USDCHF"  );
   if (symbol == "USDCHFMC" ) return("USDCHF"  );
   if (symbol == "USDCHFMD" ) return("USDCHF"  );
   if (symbol == "USDCHFX"  ) return("USDCHF"  );
   if (symbol == "USDCZK"   ) return("USDCZK"  );
   if (symbol == "USDCZKMA" ) return("USDCZK"  );
   if (symbol == "USDCZKMB" ) return("USDCZK"  );
   if (symbol == "USDCZKMC" ) return("USDCZK"  );
   if (symbol == "USDCZKMD" ) return("USDCZK"  );
   if (symbol == "USDCZKX"  ) return("USDCZK"  );
   if (symbol == "USDDKK"   ) return("USDDKK"  );
   if (symbol == "USDDKKMA" ) return("USDDKK"  );
   if (symbol == "USDDKKMB" ) return("USDDKK"  );
   if (symbol == "USDDKKMC" ) return("USDDKK"  );
   if (symbol == "USDDKKMD" ) return("USDDKK"  );
   if (symbol == "USDDKKX"  ) return("USDDKK"  );
   if (symbol == "USDHKD"   ) return("USDHKD"  );
   if (symbol == "USDHKDMA" ) return("USDHKD"  );
   if (symbol == "USDHKDMB" ) return("USDHKD"  );
   if (symbol == "USDHKDMC" ) return("USDHKD"  );
   if (symbol == "USDHKDMD" ) return("USDHKD"  );
   if (symbol == "USDHKDX"  ) return("USDHKD"  );
   if (symbol == "USDHUF"   ) return("USDHUF"  );
   if (symbol == "USDHUFMA" ) return("USDHUF"  );
   if (symbol == "USDHUFMB" ) return("USDHUF"  );
   if (symbol == "USDHUFMC" ) return("USDHUF"  );
   if (symbol == "USDHUFMD" ) return("USDHUF"  );
   if (symbol == "USDHUFX"  ) return("USDHUF"  );
   if (symbol == "USDJPY"   ) return("USDJPY"  );
   if (symbol == "USDJPYMA" ) return("USDJPY"  );
   if (symbol == "USDJPYMB" ) return("USDJPY"  );
   if (symbol == "USDJPYMC" ) return("USDJPY"  );
   if (symbol == "USDJPYMD" ) return("USDJPY"  );
   if (symbol == "USDJPYX"  ) return("USDJPY"  );
   if (symbol == "USDLFX"   ) return("USDLFX"  );
   if (symbol == "USDMXN"   ) return("USDMXN"  );
   if (symbol == "USDMXNMA" ) return("USDMXN"  );
   if (symbol == "USDMXNMB" ) return("USDMXN"  );
   if (symbol == "USDMXNMC" ) return("USDMXN"  );
   if (symbol == "USDMXNMD" ) return("USDMXN"  );
   if (symbol == "USDMXNX"  ) return("USDMXN"  );
   if (symbol == "USDNOK"   ) return("USDNOK"  );
   if (symbol == "USDNOKMA" ) return("USDNOK"  );
   if (symbol == "USDNOKMB" ) return("USDNOK"  );
   if (symbol == "USDNOKMC" ) return("USDNOK"  );
   if (symbol == "USDNOKMD" ) return("USDNOK"  );
   if (symbol == "USDNOKX"  ) return("USDNOK"  );
   if (symbol == "USDPLN"   ) return("USDPLN"  );
   if (symbol == "USDPLNMA" ) return("USDPLN"  );
   if (symbol == "USDPLNMB" ) return("USDPLN"  );
   if (symbol == "USDPLNMC" ) return("USDPLN"  );
   if (symbol == "USDPLNMD" ) return("USDPLN"  );
   if (symbol == "USDPLNX"  ) return("USDPLN"  );
   if (symbol == "USDRUR"   ) return("USDRUR"  );
   if (symbol == "USDRURMA" ) return("USDRUR"  );
   if (symbol == "USDRURMB" ) return("USDRUR"  );
   if (symbol == "USDRURMC" ) return("USDRUR"  );
   if (symbol == "USDRURMD" ) return("USDRUR"  );
   if (symbol == "USDRURX"  ) return("USDRUR"  );
   if (symbol == "USDSEK"   ) return("USDSEK"  );
   if (symbol == "USDSEKMA" ) return("USDSEK"  );
   if (symbol == "USDSEKMB" ) return("USDSEK"  );
   if (symbol == "USDSEKMC" ) return("USDSEK"  );
   if (symbol == "USDSEKMD" ) return("USDSEK"  );
   if (symbol == "USDSEKX"  ) return("USDSEK"  );
   if (symbol == "USDSGD"   ) return("USDSGD"  );
   if (symbol == "USDSGDMA" ) return("USDSGD"  );
   if (symbol == "USDSGDMB" ) return("USDSGD"  );
   if (symbol == "USDSGDMC" ) return("USDSGD"  );
   if (symbol == "USDSGDMD" ) return("USDSGD"  );
   if (symbol == "USDSGDX"  ) return("USDSGD"  );
   if (symbol == "USDX"     ) return("USDX"    );
   if (symbol == "USDZAR"   ) return("USDZAR"  );
   if (symbol == "USDZARMA" ) return("USDZAR"  );
   if (symbol == "USDZARMB" ) return("USDZAR"  );
   if (symbol == "USDZARMC" ) return("USDZAR"  );
   if (symbol == "USDZARMD" ) return("USDZAR"  );
   if (symbol == "USDZARX"  ) return("USDZAR"  );
   if (symbol == "XAGUSD"   ) return("XAGUSD"  );
   if (symbol == "XAGUSDX"  ) return("XAGUSD"  );
   if (symbol == "XAUUSD"   ) return("XAUUSD"  );
   if (symbol == "XAUUSDX"  ) return("XAUUSD"  );
   if (symbol == "_DJI"     ) return("#DJI.X"  );
   if (symbol == "_DJT"     ) return("#DJT.X"  );
   if (symbol == "_N225"    ) return("#NIK.X"  );
   if (symbol == "_NQ100"   ) return("#N100.X" );
   if (symbol == "_NQCOMP"  ) return("#NCOMP.X");
   if (symbol == "_SP500"   ) return("#SPX.X"  );

   return("");
}


/**
 * Gibt die allgemeingültige Form eines Symbols zurück oder den angegebenen Defaultwert, wenn keine allgemeingültige dieses Symbols Form gefunden wurde.
 *
 * @param  string symbol       - broker-spezifisches Symbol
 * @param  string defaultValue - Default-Rückgabewert
 *
 * @return string - allgemeingültiger oder Default-Rückgabewert
 */
string FindNormalizedSymbol(string symbol, string defaultValue="") {
   string normalized = NormalizeSymbol(symbol);

   if (normalized == "")
      return(defaultValue);
   return(normalized);
}


/**
 * Gibt den Kurznamen eines Symbols zurück oder den angegebenen Defaultwert, wenn kein Kurzname für dieses Symbol gefunden wurde.
 *
 * @param  string symbol      - Symbol
 * @param  string defaultName - Default-Rückgabewert
 *
 * @return string
 */
string FindSymbolName(string symbol, string defaultName="") {
   symbol = StringToUpper(symbol);

   if (symbol == "#DAX.X"  ) return("DAX"      );
   if (symbol == "#DJI.X"  ) return("DJIA"     );
   if (symbol == "#DJT.X"  ) return("DJTA"     );
   if (symbol == "#N100.X" ) return("N100"     );
   if (symbol == "#NCOMP.X") return("NCOMP"    );
   if (symbol == "#NIK.X"  ) return("Nikkei"   );
   if (symbol == "#SPX.X"  ) return("SP500"    );
   if (symbol == "AUDCAD"  ) return("AUD/CAD"  );
   if (symbol == "AUDCHF"  ) return("AUD/CHF"  );
   if (symbol == "AUDJPY"  ) return("AUD/JPY"  );
   if (symbol == "AUDLFX"  ) return("AUD-Index");
   if (symbol == "AUDNZD"  ) return("AUD/NZD"  );
   if (symbol == "AUDUSD"  ) return("AUD/USD"  );
   if (symbol == "CADCHF"  ) return("CAD/CHF"  );
   if (symbol == "CADJPY"  ) return("CAD/JPY"  );
   if (symbol == "CADLFX"  ) return("CAD-Index");
   if (symbol == "CHFJPY"  ) return("CHF/JPY"  );
   if (symbol == "CHFLFX"  ) return("CHF-Index");
   if (symbol == "EURAUD"  ) return("EUR/AUD"  );
   if (symbol == "EURCAD"  ) return("EUR/CAD"  );
   if (symbol == "EURCHF"  ) return("EUR/CHF"  );
   if (symbol == "EURDKK"  ) return("EUR/DKK"  );
   if (symbol == "EURGBP"  ) return("EUR/GBP"  );
   if (symbol == "EURJPY"  ) return("EUR/JPY"  );
   if (symbol == "EURLFX"  ) return("EUR-Index");
   if (symbol == "EURNOK"  ) return("EUR/NOK"  );
   if (symbol == "EURNZD"  ) return("EUR/NZD"  );
   if (symbol == "EURRUR"  ) return("EUR/RUR"  );
   if (symbol == "EURSEK"  ) return("EUR/SEK"  );
   if (symbol == "EURUSD"  ) return("EUR/USD"  );
   if (symbol == "EURX"    ) return("EUR-Index");
   if (symbol == "GBPAUD"  ) return("GBP/AUD"  );
   if (symbol == "GBPCAD"  ) return("GBP/CAD"  );
   if (symbol == "GBPCHF"  ) return("GBP/CHF"  );
   if (symbol == "GBPJPY"  ) return("GBP/JPY"  );
   if (symbol == "GBPLFX"  ) return("GBP-Index");
   if (symbol == "GBPNZD"  ) return("GBP/NZD"  );
   if (symbol == "GBPRUR"  ) return("GBP/RUR"  );
   if (symbol == "GBPUSD"  ) return("GBP/USD"  );
   if (symbol == "JPYLFX"  ) return("JPY-Index");
   if (symbol == "NZDCAD"  ) return("NZD/CAD"  );
   if (symbol == "NZDCHF"  ) return("NZD/CHF"  );
   if (symbol == "NZDJPY"  ) return("NZD/JPY"  );
   if (symbol == "NZDLFX"  ) return("NZD-Index");
   if (symbol == "NZDUSD"  ) return("NZD/USD"  );
   if (symbol == "SGDJPY"  ) return("SGD/JPY"  );
   if (symbol == "USDCAD"  ) return("USD/CAD"  );
   if (symbol == "USDCHF"  ) return("USD/CHF"  );
   if (symbol == "USDCZK"  ) return("USD/CZK"  );
   if (symbol == "USDDKK"  ) return("USD/DKK"  );
   if (symbol == "USDHKD"  ) return("USD/HKD"  );
   if (symbol == "USDHUF"  ) return("USD/HUF"  );
   if (symbol == "USDJPY"  ) return("USD/JPY"  );
   if (symbol == "USDLFX"  ) return("USD-Index");
   if (symbol == "USDMXN"  ) return("USD/MXN"  );
   if (symbol == "USDNOK"  ) return("USD/NOK"  );
   if (symbol == "USDPLN"  ) return("USD/PLN"  );
   if (symbol == "USDRUR"  ) return("USD/RUR"  );
   if (symbol == "USDSEK"  ) return("USD/SEK"  );
   if (symbol == "USDSGD"  ) return("USD/SGD"  );
   if (symbol == "USDX"    ) return("USD-Index");
   if (symbol == "USDZAR"  ) return("USD/ZAR"  );
   if (symbol == "XAGUSD"  ) return("Silver"   );
   if (symbol == "XAUUSD"  ) return("Gold"     );

   return(defaultName);
}


/**
 * Gibt den Langnamen eines Symbols zurück oder den angegebenen Defaultwert, wenn kein Langname für dieses Symbol gefunden wurde.
 *
 * @param  string symbol      - Symbol
 * @param  string defaultName - Default-Rückgabewert
 *
 * @return string
 */
string FindSymbolLongName(string symbol, string defaultName="") {
   symbol = StringToUpper(symbol);

   if (symbol == "#DJI.X"  ) return("Dow Jones Industrial"    );
   if (symbol == "#DJT.X"  ) return("Dow Jones Transportation");
   if (symbol == "#N100.X" ) return("Nasdaq 100"              );
   if (symbol == "#NCOMP.X") return("Nasdaq Composite"        );
   if (symbol == "#NIK.X"  ) return("Nikkei 225"              );
   if (symbol == "#SPX.X"  ) return("S&P 500"                 );
   if (symbol == "AUDLFX"  ) return("AUD-Index © LiteForex"   );
   if (symbol == "CADLFX"  ) return("CAD-Index © LiteForex"   );
   if (symbol == "CHFLFX"  ) return("CHF-Index © LiteForex"   );
   if (symbol == "EURLFX"  ) return("EUR-Index © LiteForex"   );
   if (symbol == "EURX"    ) return("EUR-Index (Eurex)"       );
   if (symbol == "GBPLFX"  ) return("GBP-Index © LiteForex"   );
   if (symbol == "JPYLFX"  ) return("1/JPY-Index © LiteForex" );
   if (symbol == "NZDLFX"  ) return("NZD-Index © LiteForex"   );
   if (symbol == "USDLFX"  ) return("USD-Index © LiteForex"   );
   if (symbol == "USDX"    ) return("USD-Index (CME)"         );

   string prefix = StringLeft(symbol, -3);
   string suffix = StringRight(symbol, 3);

   if      (suffix == ".AB") if (StringIsDigit(prefix)) return(StringConcatenate("#", prefix, " Account Balance" ));
   else if (suffix == ".EQ") if (StringIsDigit(prefix)) return(StringConcatenate("#", prefix, " Account Equity"  ));
   else if (suffix == ".LV") if (StringIsDigit(prefix)) return(StringConcatenate("#", prefix, " Account Leverage"));
   else if (suffix == ".PL") if (StringIsDigit(prefix)) return(StringConcatenate("#", prefix, " Profit/Loss"     ));
   else if (suffix == ".FM") if (StringIsDigit(prefix)) return(StringConcatenate("#", prefix, " Free Margin"     ));
   else if (suffix == ".UM") if (StringIsDigit(prefix)) return(StringConcatenate("#", prefix, " Used Margin"     ));

   return(defaultName);
}


/**
 *
 */
void trace(string script, string function) {
   string stack[];
   int    stackSize = ArraySize(stack);

   if (script != "-1") {
      ArrayResize(stack, stackSize+1);
      stack[stackSize] = StringConcatenate(script, "::", function);
   }
   else if (stackSize > 0) {
      ArrayResize(stack, stackSize-1);
   }

   Print("trace()    ", script, "::", function, "   stackSize=", ArraySize(stack));
}


/**
 * Konvertiert einen Boolean in den String "true" oder "false".
 *
 * @param  bool value
 *
 * @return string
 */
string BoolToStr(bool value) {
   if (value)
      return("true");
   return("false");
}


/**
 * Alias für BoolToStr()
 */
string BooleanToStr(bool value) {
   return(BoolToStr(value));
}


/**
 * Gibt die aktuelle Zeit in GMT zurück (entspricht UTC).
 *
 * @return datetime - Timestamp oder -1, falls ein Fehler auftrat
 */
datetime TimeGMT() {
   int /*SYSTEMTIME*/ st[4];     // struct SYSTEMTIME = 16 byte
   GetSystemTime(st);

   int year  = st.Year(st);
   int month = st.Month(st);
   int day   = st.Day(st);
   int hour  = st.Hour(st);
   int min   = st.Minute(st);
   int sec   = st.Second(st);

   string strTime = StringConcatenate(year, ".", month, ".", day, " ", hour, ":", min, ":", sec);
   datetime time  = StrToTime(strTime);

   //Print("TimeGMT()   strTime = "+ strTime +"    StrToTime(strTime) = "+ TimeToStr(time, TIME_DATE|TIME_MINUTES|TIME_SECONDS));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("TimeGMT()", error);
      return(-1);
   }
   return(time);
}


/**
 * Inlined conditional String-Statement.
 *
 * @param  bool   condition
 * @param  string thenValue
 * @param  string elseValue
 *
 * @return string
 */
string ifString(bool condition, string thenValue, string elseValue) {
   if (condition)
      return(thenValue);
   return(elseValue);
}


/**
 * Inlined conditional Integer-Statement.
 *
 * @param  bool condition
 * @param  int  thenValue
 * @param  int  elseValue
 *
 * @return int
 */
int ifInt(bool condition, int thenValue, int elseValue) {
   if (condition)
      return(thenValue);
   return(elseValue);
}


/**
 * Inlined conditional Double-Statement.
 *
 * @param  bool   condition
 * @param  double thenValue
 * @param  double elseValue
 *
 * @return double
 */
double ifDouble(bool condition, double thenValue, double elseValue) {
   if (condition)
      return(thenValue);
   return(elseValue);
}


/**
 * Gibt die Anzahl der Dezimal- bzw. Nachkommastellen eines Zahlenwertes zurück.
 *
 * @param  double number
 *
 * @return int
 */
int CountDecimals(double number) {
   string str = number;
   int dot    = StringFind(str, ".");

   for (int i=StringLen(str)-1; i > dot; i--) {
      if (StringGetChar(str, i) != '0')
         break;
   }
   return(i - dot);
}


/**
 * Ob ein String mit einem angegebenen Substring beginnt. Groß-/Kleinschreibung wird beachtet.
 *
 * @param  string object - zu prüfender String
 * @param  string prefix - Substring
 *
 * @return bool
 */
bool StringStartsWith(string object, string prefix) {
   return(StringLeft(object, StringLen(prefix)) == prefix);
}


/**
 * Ob ein String mit einem angegebenen Substring beginnt. Groß-/Kleinschreibung wird nicht beachtet.
 *
 * @param  string object - zu prüfender String
 * @param  string prefix - Substring
 *
 * @return bool
 */
bool StringIStartsWith(string object, string prefix) {
   //if (__TRACE__) trace(__SCRIPT__, "StringIStartsWith()");

   object = StringToLower(object);
   prefix = StringToLower(prefix);

   //if (__TRACE__) trace(-1, 0);
   return(StringLeft(object, StringLen(prefix)) == prefix);
}


/**
 * Ob ein String mit einem angegebenen Substring endet. Groß-/Kleinschreibung wird beachtet.
 *
 * @param  string object  - zu prüfender String
 * @param  string postfix - Substring
 *
 * @return bool
 */
bool StringEndsWith(string object, string postfix) {
   return(StringRight(object, StringLen(postfix)) == postfix);
}


/**
 * Ob ein String mit einem angegebenen Substring endet. Groß-/Kleinschreibung wird nicht beachtet.
 *
 * @param  string object  - zu prüfender String
 * @param  string postfix - Substring
 *
 * @return bool
 */
bool StringIEndsWith(string object, string postfix) {
   object  = StringToLower(object);
   postfix = StringToLower(postfix);
   return(StringRight(object, StringLen(postfix)) == postfix);
}


/**
 * Gibt einen Substring eines Strings zurück.
 *
 * Ist N positiv, gibt StringLeft() die N am meisten links stehenden Zeichen des Strings zurück.
 *    z.B.  StringLeft("ABCDEFG",  2)  =>  "AB"
 *
 * Ist N negativ, gibt StringLeft() alle außer den N am meisten rechts stehenden Zeichen des Strings zurück.
 *    z.B.  StringLeft("ABCDEFG", -2)  =>  "ABCDE"
 *
 * @param  string value
 * @param  int    n
 *
 * @return string
 */
string StringLeft(string value, int n) {
   if      (n > 0) return(StringSubstr(value, 0, n));
   else if (n < 0) return(StringSubstrFix(value, 0, StringLen(value)+n));
   return("");
}


/**
 * Gibt einen Substring eines Strings zurück.
 *
 * Ist N positiv, gibt StringRight() die N am meisten rechts stehenden Zeichen des Strings zurück.
 *    z.B.  StringRight("ABCDEFG",  2)  =>  "FG"
 *
 * Ist N negativ, gibt StringLeft() alle außer den N am meisten links stehenden Zeichen des Strings zurück.
 *    z.B.  StringRight("ABCDEFG", -2)  =>  "CDEFG"
 *
 * @param  string value
 * @param  int    n
 *
 * @return string
 */
string StringRight(string value, int n) {
   if      (n > 0) return(StringSubstr(value, StringLen(value)-n));
   else if (n < 0) return(StringSubstr(value, -n));
   return("");
}


/**
 * Bugfix für StringSubstr(string, start, length=0), die MQL-Funktion gibt für length=0 Unfug zurück.
 * Ermöglicht die Angabe negativer Werte für start und length
 *
 * @param  string object
 * @param  int    start  - wenn negativ, Startindex vom Ende des Strings
 * @param  int    length - wenn negativ, Anzahl der zurückzugebenden Zeichen links vom Startindex
 *
 * @return string
 */
string StringSubstrFix(string object, int start, int length=EMPTY_VALUE) {
   if (length == 0)
      return("");

   if (start < 0)
      start = MathMax(0, start + StringLen(object));

   if (length < 0) {
      start += 1 + length;
      length = MathAbs(length);
   }
   return(StringSubstr(object, start, length));
}


/**
 * Ersetzt in einem String alle Vorkommen eines Substrings durch einen anderen String (arbeitet nicht rekursiv).
 *
 * @param  string object  - Ausgangsstring
 * @param  string search  - Suchstring
 * @param  string replace - Ersatzstring
 *
 * @return string
 */
string StringReplace(string object, string search, string replace) {
   if (StringLen(object) == 0) return(object);
   if (StringLen(search) == 0) return(object);

   int startPos = 0;
   int foundPos = StringFind(object, search, startPos);
   if (foundPos == -1) return(object);

   string result = "";

   while (foundPos > -1) {
      result   = StringConcatenate(result, StringSubstrFix(object, startPos, foundPos-startPos), replace);
      startPos = foundPos + StringLen(search);
      foundPos = StringFind(object, search, startPos);
   }
   result = StringConcatenate(result, StringSubstr(object, startPos));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("StringReplace()", error);
      return("");
   }
   return(result);
}


/**
 * Gibt die Startzeit der vorherigen Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetServerPrevSessionStartTime(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerPrevSessionStartTime(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = ServerToEasternTime(serverTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime previousStart = GetEasternPrevSessionStartTime(easternTime);
   datetime serverStart   = EasternToServerTime(previousStart);
   //Print("GetServerPrevSessionStartTime()  serverTime: "+ TimeToStr(serverTime) +"   previousStart: "+ TimeToStr(serverStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetServerPrevSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(serverStart);
}


/**
 * Gibt die Endzeit der vorherigen Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetServerPrevSessionEndTime(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerPrevSessionEndTime(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = ServerToEasternTime(serverTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime previousEnd = GetEasternPrevSessionEndTime(easternTime);
   datetime serverEnd   = EasternToServerTime(previousEnd);
   //Print("GetServerPrevSessionEndTime()  serverTime: "+ TimeToStr(serverTime) +"   previousEnd: "+ TimeToStr(serverEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetServerPrevSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(serverEnd);
}


/**
 * Gibt die Startzeit der Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder -1, falls der Markt zu diesem Zeitpunkt geschlossen ist (Wochenende);
 *                    EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetServerSessionStartTime(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerSessionStartTime(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = ServerToEasternTime(serverTime);
   if (easternTime == -1)  return(EMPTY_VALUE);

   datetime easternStart = GetEasternSessionStartTime(easternTime);
   if (easternStart == -1) return(-1);

   datetime serverStart = EasternToServerTime(easternStart);
   //Print("GetServerSessionStartTime()  time: "+ TimeToStr(serverTime) +"   serverSessionStart: "+ TimeToStr(serverStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetServerSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(serverStart);
}


/**
 * Gibt die Endzeit der Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder -1, falls der Markt zu diesem Zeitpunkt geschlossen ist (Wochenende);
 *                    EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetServerSessionEndTime(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerSessionEndTime(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = ServerToEasternTime(serverTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime easternEnd = GetEasternSessionEndTime(easternTime);
   if (easternEnd == EMPTY_VALUE) return(EMPTY_VALUE);
   if (easternEnd == -1)          return(-1);

   datetime serverEnd = EasternToServerTime(easternEnd);
    //Print("GetServerSessionEndTime()  time: "+ TimeToStr(serverTime) +"   serverEnd: "+ TimeToStr(serverEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetServerSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(serverEnd);
}


/**
 * Gibt die Startzeit der nächsten Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetServerNextSessionStartTime(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerNextSessionStartTime(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = ServerToEasternTime(serverTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime nextStart   = GetEasternNextSessionStartTime(easternTime);
   datetime serverStart = EasternToServerTime(nextStart);
   //Print("GetServerNextSessionStartTime()  serverTime: "+ TimeToStr(serverTime) +"   nextStart: "+ TimeToStr(serverStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetServerNextSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(serverStart);
}


/**
 * Gibt die Endzeit der nächsten Handelssession für den angegebenen Tradeserver-Zeitpunkt zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetServerNextSessionEndTime(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerNextSessionEndTime(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = ServerToEasternTime(serverTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime nextEnd   = GetEasternNextSessionEndTime(easternTime);
   datetime serverEnd = EasternToServerTime(nextEnd);
   //Print("GetServerNextSessionEndTime()  serverTime: "+ TimeToStr(serverTime) +"   nextEnd: "+ TimeToStr(serverEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetServerNextSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(serverEnd);
}


/**
 * Gibt die Startzeit der vorherigen Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetGmtPrevSessionStartTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtPrevSessionStartTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = GmtToEasternTime(gmtTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime previousStart = GetEasternPrevSessionStartTime(easternTime);
   datetime gmtStart      = EasternToGMT(previousStart);
   //Print("GetGmtPrevSessionStartTime()  gmtTime: "+ TimeToStr(gmtTime) +"   previousStart: "+ TimeToStr(gmtStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetGmtPrevSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(gmtStart);
}


/**
 * Gibt die Endzeit der vorherigen Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetGmtPrevSessionEndTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtPrevSessionEndTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = GmtToEasternTime(gmtTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime previousEnd = GetEasternPrevSessionEndTime(easternTime);
   datetime gmtEnd      = EasternToGMT(previousEnd);
   //Print("GetGmtPrevSessionEndTime()  gmtTime: "+ TimeToStr(gmtTime) +"   previousEnd: "+ TimeToStr(gmtEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetGmtPrevSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(gmtEnd);
}


/**
 * Gibt die Startzeit der Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls der Markt zu diesem Zeitpunkt geschlossen ist (Wochenende);
 *                    EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetGmtSessionStartTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtSessionStartTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = GmtToEasternTime(gmtTime);
   if (easternTime == -1)  return(EMPTY_VALUE);

   datetime easternStart = GetEasternSessionStartTime(easternTime);
   if (easternStart == -1) return(-1);

   datetime gmtStart = EasternToGMT(easternStart);
   //Print("GetGmtSessionStartTime()  gmtTime: "+ TimeToStr(gmtTime) +"   gmtStart: "+ TimeToStr(gmtStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetGmtSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(gmtStart);
}


/**
 * Gibt die Endzeit der Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls der Markt zu diesem Zeitpunkt geschlossen ist (Wochenende);
 *                    EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetGmtSessionEndTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtSessionEndTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = GmtToEasternTime(gmtTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime easternEnd = GetEasternSessionEndTime(easternTime);
   if (easternEnd == -1)  return(-1);

   datetime gmtEnd = EasternToGMT(easternEnd);
   //Print("GetGmtSessionEndTime()  gmtTime: "+ TimeToStr(gmtTime) +"   gmtEnd: "+ TimeToStr(gmtEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetGmtSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(gmtEnd);
}


/**
 * Gibt die Startzeit der nächsten Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetGmtNextSessionStartTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtNextSessionStartTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = GmtToEasternTime(gmtTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime nextStart = GetEasternNextSessionStartTime(easternTime);
   datetime gmtStart  = EasternToGMT(nextStart);
   //Print("GetGmtNextSessionStartTime()  gmtTime: "+ TimeToStr(gmtTime) +"   nextStart: "+ TimeToStr(gmtStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetGmtNextSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(gmtStart);
}


/**
 * Gibt die Endzeit der nächsten Handelssession für den angegebenen GMT-Zeitpunkt zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetGmtNextSessionEndTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtNextSessionEndTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternTime = GmtToEasternTime(gmtTime);
   if (easternTime == -1) return(EMPTY_VALUE);

   datetime nextEnd = GetEasternNextSessionEndTime(easternTime);
   datetime gmtEnd  = EasternToGMT(nextEnd);
   //Print("GetGmtNextSessionEndTime()  gmtTime: "+ TimeToStr(gmtTime) +"   nextEnd: "+ TimeToStr(gmtEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetGmtNextSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(gmtEnd);
}


/**
 * Gibt die Startzeit der vorherigen Handelssession für den angegebenen New Yorker Zeitpunkt (Eastern Time) zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime easternTime - Zeitpunkt New Yorker Zeit
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetEasternPrevSessionStartTime(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternPrevSessionStartTime(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   // aktuellen Sessionbeginn ermitteln (17:00)
   int hour = TimeHour(easternTime);
   datetime currentStart = easternTime -(hour+7)*HOURS - TimeMinute(easternTime)*MINUTES - TimeSeconds(easternTime);    // Time -hours -7h => 17:00 am vorherigen Tag
   if (hour >= 17)
      currentStart += 1*DAY;
   datetime previousStart = currentStart - 1*DAY;

   // Wochenenden berücksichtigen
   int dow = TimeDayOfWeek(previousStart);
   if      (dow == FRIDAY  ) previousStart -= 1*DAY;
   else if (dow == SATURDAY) previousStart -= 2*DAYS;
   //Print("GetEasternPrevSessionStartTime()  easternTime: "+ TimeToStr(easternTime) +"   previousStart: "+ TimeToStr(previousStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetEasternPrevSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(previousStart);
}


/**
 * Gibt die Endzeit der vorherigen Handelssession für den angegebenen New Yorker Zeitpunkt (Eastern Time) zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime easternTime - Zeitpunkt New Yorker Zeit
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetEasternPrevSessionEndTime(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternPrevSessionEndTime(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime previousStart = GetEasternPrevSessionStartTime(easternTime);
   if (previousStart == EMPTY_VALUE) return(EMPTY_VALUE);

   datetime previousEnd = previousStart + 1*DAY;
   //Print("GetEasternPrevSessionEndTime()  easternTime: "+ TimeToStr(easternTime) +"   previousEnd: "+ TimeToStr(previousEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetEasternPrevSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(previousEnd);
}


/**
 * Gibt die Startzeit der Handelssession für den angegebenen New Yorker Zeitpunkt (Eastern Time) zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime easternTime - Zeitpunkt New Yorker Zeit
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder -1, falls der Markt zu diesem Zeitpunkt geschlossen ist (Wochenende);
 *                    EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetEasternSessionStartTime(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternSessionStartTime(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   // aktuellen Sessionbeginn ermitteln (17:00)
   int hour = TimeHour(easternTime);
   datetime easternStart = easternTime + (17-hour)*HOURS - TimeMinute(easternTime)*MINUTES - TimeSeconds(easternTime);     // Time -hour +17h => 17:00
   if (hour < 17)
      easternStart -= 1*DAY;

   // Wochenenden berücksichtigen
   int dow = TimeDayOfWeek(easternStart);
   if (dow == FRIDAY  ) return(-1);
   if (dow == SATURDAY) return(-1);
   //Print("GetEasternSessionStartTime()  easternTime: "+ TimeToStr(easternTime) +"   sessionStart: "+ TimeToStr(easternStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetEasternSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(easternStart);
}


/**
 * Gibt die Endzeit der Handelssession für den angegebenen New Yorker Zeitpunkt (Eastern Time) zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime easternTime - Zeitpunkt New Yorker Zeit
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder -1, falls der Markt zu diesem Zeitpunkt geschlossen ist (Wochenende);
 *                    EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetEasternSessionEndTime(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternSessionEndTime(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime easternStart = GetEasternSessionStartTime(easternTime);
   if (easternStart == EMPTY_VALUE) return(EMPTY_VALUE);
   if (easternStart == -1)          return(-1);

   datetime easternEnd = easternStart + 1*DAY;
   //Print("GetEasternSessionEndTime()  easternTime: "+ TimeToStr(easternTime) +"   sessionEnd: "+ TimeToStr(easternEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetEasternSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(easternEnd);
}


/**
 * Gibt die Startzeit der nächsten Handelssession für den angegebenen New Yorker Zeitpunkt (Eastern Time) zurück.
 * Die Handelssessions beginnen um 17:00 New Yorker Zeit.
 *
 * @param  datetime easternTime - Zeitpunkt New Yorker Zeit
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetEasternNextSessionStartTime(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternNextSessionStartTime(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   // nächsten Sessionbeginn ermitteln (17:00)
   int hour = TimeHour(easternTime);
   datetime nextStart = easternTime + (17-hour)*HOURS - TimeMinute(easternTime)*MINUTES - TimeSeconds(easternTime);     // Time -hours +17h => 17:00
   if (hour >= 17)
      nextStart += 1*DAY;

   // Wochenenden berücksichtigen
   int dow = TimeDayOfWeek(nextStart);
   if      (dow == FRIDAY  ) nextStart += 2*DAYS;
   else if (dow == SATURDAY) nextStart += 1*DAY;
   //Print("GetEasternNextSessionStartTime()  easternTime: "+ TimeToStr(easternTime) +"   nextStart: "+ TimeToStr(nextStart));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetEasternNextSessionStartTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(nextStart);
}


/**
 * Gibt die Endzeit der nächsten Handelssession für den angegebenen New Yorker Zeitpunkt (Eastern Time) zurück.
 * Die Handelssessions enden um 17:00 New Yorker Zeit.
 *
 * @param  datetime easternTime - Zeitpunkt New Yorker Zeit
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder EMPTY_VALUE, falls ein Fehler auftrat
 */
datetime GetEasternNextSessionEndTime(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternNextSessionEndTime(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   datetime nextStart = GetEasternNextSessionStartTime(easternTime);
   if (nextStart == EMPTY_VALUE) return(EMPTY_VALUE);

   datetime nextEnd = nextStart + 1*DAY;
   //Print("GetEasternNextSessionEndTime()  easternTime: "+ TimeToStr(easternTime) +"   nextEnd: "+ TimeToStr(nextEnd));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("GetEasternNextSessionEndTime(2)", error);
      return(EMPTY_VALUE);
   }
   return(nextEnd);
}


/**
 * Korrekter Vergleich zweier Doubles.
 *
 * @param  double1 - erster Wert
 * @param  double2 - zweiter Wert
 *
 * @return bool - TRUE, wenn die Werte gleich sind; FALSE andererseits
 */
bool CompareDoubles(double double1, double double2) {
   return(NormalizeDouble(double1 - double2, 8) == 0);
}


/**
 * Gibt die hexadezimale Representation eines Integers zurück.
 *
 * @param  int i - Integer
 *
 * @return string - hexadezimaler Wert
 *
 * TODO: kann keine negativen Zahlen verarbeiten (gibt 0 zurück)
 */
string DecimalToHex(int i) {
   static string hexValues = "0123456789ABCDEF";
   string result = "";

   int a = i % 16;   // a = Divisionsrest
   int b = i / 16;   // b = ganzes Vielfaches

   if (b > 15) result = StringConcatenate(DecimalToHex(b), StringSubstr(hexValues, a, 1));
   else        result = StringConcatenate(StringSubstr(hexValues, b, 1), StringSubstr(hexValues, a, 1));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("DecimalToHex()", error);
      return("");
   }
   return(result);
}


/**
 * Gibt die nächstkleinere Periode der angegebenen Periode zurück.
 *
 * @param  int period - Timeframe-Periode (default: 0 - die aktuelle Periode)
 *
 * @return int - nächstkleinere Periode oder der ursprüngliche Wert, wenn keine kleinere Periode existiert
 */
int DecreasePeriod(int period = 0) {
   if (period == 0)
      period = Period();

   switch (period) {
      case PERIOD_M1 : return(PERIOD_M1 );
      case PERIOD_M5 : return(PERIOD_M1 );
      case PERIOD_M15: return(PERIOD_M5 );
      case PERIOD_M30: return(PERIOD_M15);
      case PERIOD_H1 : return(PERIOD_M30);
      case PERIOD_H4 : return(PERIOD_H1 );
      case PERIOD_D1 : return(PERIOD_H4 );
      case PERIOD_W1 : return(PERIOD_D1 );
      case PERIOD_MN1: return(PERIOD_W1 );
   }

   catch("DecreasePeriod()  invalid parameter period: "+ period, ERR_INVALID_FUNCTION_PARAMVALUE);
   return(0);
}


/**
 * Konvertiert einen Double in einen String und entfernt abschließende Nullstellen.
 *
 * @param  double value - Double
 *
 * @return string
 */
string DoubleToStrTrim(double value) {
   string result = value;

   int digits = MathMax(1, CountDecimals(value));  // mindestens eine Dezimalstelle wird erhalten

   if (digits < 8)
      result = StringLeft(result, digits-8);

   return(result);
}


/**
 * Konvertiert die angegebene New Yorker Zeit nach GMT (UTC).
 *
 * @param  datetime easternTime - New Yorker Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime EasternToGMT(datetime easternTime) {
   if (easternTime < 1) {
      catch("EasternToGMT(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   int easternToGmtOffset = GetEasternToGmtOffset(easternTime);
   if (easternToGmtOffset == EMPTY_VALUE)
      return(-1);

   datetime gmtTime = easternTime - easternToGmtOffset;

   //Print("EasternToGMT()    ET: "+ TimeToStr(easternTime) +"     GMT offset: "+ (easternToGmtOffset/HOURS) +"     GMT: "+ TimeToStr(gmtTime));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EasternToGMT(2)", error);
      return(-1);
   }
   return(gmtTime);
}


/**
 * Konvertiert die angegebene New Yorker Zeit (Eastern Time) nach Tradeserver-Zeit.
 *
 * @param  datetime easternTime - New Yorker Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime EasternToServerTime(datetime easternTime) {
   if (easternTime < 1) {
      catch("EasternToServerTime(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   string zone = GetServerTimezone();
   if (zone == "")
      return(-1);

   // schnelle Rückkehr, wenn der Tradeserver unter Eastern Time läuft
   if (zone == "EST,EDT")
      return(easternTime);

   // Offset Eastern zu GMT
   int easternToGmtOffset = GetEasternToGmtOffset(easternTime);

   // Offset GMT zu Tradeserver
   int gmtToServerTimeOffset;
   if (zone != "GMT")
      gmtToServerTimeOffset = GetGmtToServerTimeOffset(easternTime - easternToGmtOffset);
   datetime serverTime = easternTime - easternToGmtOffset - gmtToServerTimeOffset;

   //Print("EasternToServerTime()    ET: "+ TimeToStr(easternTime) +"     server: "+ TimeToStr(serverTime));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EasternToServerTime(2)", error);
      return(-1);
   }
   return(serverTime);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein Event des angegebenen Typs aufgetreten ist.
 *
 * @param  int  event       - Event
 * @param  int& lpResults[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int  flags       - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool EventListener(int event, int& lpResults[], int flags=0) {
   switch (event) {
      case EVENT_BAR_OPEN       : return(EventListener.BarOpen       (lpResults, flags));
      case EVENT_ORDER_PLACE    : return(EventListener.OrderPlace    (lpResults, flags));
      case EVENT_ORDER_CHANGE   : return(EventListener.OrderChange   (lpResults, flags));
      case EVENT_ORDER_CANCEL   : return(EventListener.OrderCancel   (lpResults, flags));
      case EVENT_POSITION_OPEN  : return(EventListener.PositionOpen  (lpResults, flags));
      case EVENT_POSITION_CLOSE : return(EventListener.PositionClose (lpResults, flags));
      case EVENT_ACCOUNT_CHANGE : return(EventListener.AccountChange (lpResults, flags));
      case EVENT_ACCOUNT_PAYMENT: return(EventListener.AccountPayment(lpResults, flags));
      case EVENT_HISTORY_CHANGE : return(EventListener.HistoryChange (lpResults, flags));
   }

   catch("EventListener()  invalid parameter event: "+ event, ERR_INVALID_FUNCTION_PARAMVALUE);
   return(false);
}


/**
 * Prüft unabhängig von der aktuell gewählten Chartperiode, ob der aktuelle Tick im angegebenen Zeitrahmen ein BarOpen-Event auslöst.
 *
 * @param  int& lpResults[] - Zielarray für die Flags der Timeframes, in denen das Event aufgetreten ist (mehrere sind möglich)
 * @param  int  flags       - ein oder mehrere Timeframe-Flags (default: Flag der aktuellen Chartperiode)
 *
 * @return bool - Ergebnis
 */
bool EventListener.BarOpen(int& lpResults[], int flags=0) {
   ArrayResize(lpResults, 1);
   lpResults[0] = 0;

   int currentPeriodFlag = GetPeriodFlag(Period());
   if (flags == 0)
      flags = currentPeriodFlag;

   // Die aktuelle Periode wird mit einem einfachen und schnelleren Algorythmus geprüft.
   if (flags & currentPeriodFlag != 0) {
      static datetime lastOpenTime = 0;
      if (lastOpenTime != 0) if (lastOpenTime != Time[0])
         lpResults[0] |= currentPeriodFlag;
      lastOpenTime = Time[0];
   }

   // Prüfungen für andere als die aktuelle Chartperiode
   else {
      static datetime lastTick   = 0;
      static int      lastMinute = 0;

      datetime tick = MarketInfo(Symbol(), MODE_TIME);      // nur Sekundenauflösung
      int minute;

      // PERIODFLAG_M1
      if (flags & PERIODFLAG_M1 != 0) {
         if (lastTick == 0) {
            lastTick   = tick;
            lastMinute = TimeMinute(tick);
            //Print("EventListener.BarOpen(M1)   initialisiert   lastTick: ", TimeToStr(lastTick, TIME_DATE|TIME_MINUTES|TIME_SECONDS), " (", lastMinute, ")");
         }
         else if (lastTick != tick) {
            minute = TimeMinute(tick);
            if (lastMinute < minute)
               lpResults[0] |= PERIODFLAG_M1;
            //Print("EventListener.BarOpen(M1)   prüfe   alt: ", TimeToStr(lastTick, TIME_DATE|TIME_MINUTES|TIME_SECONDS), " (", lastMinute, ")   neu: ", TimeToStr(tick, TIME_DATE|TIME_MINUTES|TIME_SECONDS), " (", minute, ")");
            lastTick   = tick;
            lastMinute = minute;
         }
         //else Print("EventListener.BarOpen(M1)   zwei Ticks in derselben Sekunde");
      }
   }

   // TODO: verbleibende Timeframe-Flags verarbeiten
   if (false) {
      if (flags & PERIODFLAG_M5  != 0) lpResults[0] |= PERIODFLAG_M5 ;
      if (flags & PERIODFLAG_M15 != 0) lpResults[0] |= PERIODFLAG_M15;
      if (flags & PERIODFLAG_M30 != 0) lpResults[0] |= PERIODFLAG_M30;
      if (flags & PERIODFLAG_H1  != 0) lpResults[0] |= PERIODFLAG_H1 ;
      if (flags & PERIODFLAG_H4  != 0) lpResults[0] |= PERIODFLAG_H4 ;
      if (flags & PERIODFLAG_D1  != 0) lpResults[0] |= PERIODFLAG_D1 ;
      if (flags & PERIODFLAG_W1  != 0) lpResults[0] |= PERIODFLAG_W1 ;
      if (flags & PERIODFLAG_MN1 != 0) lpResults[0] |= PERIODFLAG_MN1;
   }

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.BarOpen()", error);
      return(false);
   }
   return(lpResults[0] != 0);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein OrderChange-Event aufgetreten ist.
 *
 * @param  int& lpResults[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int  flags       - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool EventListener.OrderChange(int& lpResults[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(lpResults) > 0)
      ArrayResize(lpResults, 0);

   // TODO: implementieren

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.OrderChange()", error);
      return(false);
   }
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein OrderPlace-Event aufgetreten ist.
 *
 * @param  int& lpResults[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int  flags       - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool EventListener.OrderPlace(int& lpResults[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(lpResults) > 0)
      ArrayResize(lpResults, 0);

   // TODO: implementieren

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.OrderPlace()", error);
      return(false);
   }
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein OrderCancel-Event aufgetreten ist.
 *
 * @param  int& lpResults[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int  flags       - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool EventListener.OrderCancel(int& lpResults[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(lpResults) > 0)
      ArrayResize(lpResults, 0);

   // TODO: implementieren

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.OrderCancel()", error);
      return(false);
   }
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein PositionOpen-Event aufgetreten ist. Werden zusätzliche Orderkriterien angegeben, wird das Event nur
 * dann signalisiert, wenn alle angegebenen Kriterien erfüllt sind.
 *
 * @param  int& lpTickets[] - Zielarray für Ticketnummern neu geöffneter Positionen
 * @param  int  flags       - ein oder mehrere zusätzliche Orderkriterien: OFLAG_CURRENTSYMBOL, OFLAG_BUY, OFLAG_SELL, OFLAG_MARKETORDER, OFLAG_PENDINGORDER
 *                            (default: 0)
 * @return bool - Ergebnis
 */
bool EventListener.PositionOpen(int& lpTickets[], int flags=0) {
   // ohne Verbindung zum Tradeserver sofortige Rückkehr
   int account = AccountNumber();
   if (account == 0)
      return(false);

   // Ergebnisarray sicherheitshalber zurücksetzen
   if (ArraySize(lpTickets) > 0)
      ArrayResize(lpTickets, 0);

   static int      accountNumber[1];
   static datetime accountInitTime[1];                      // GMT-Zeit
   static int      knownPendings[][2];                      // die bekannten pending Orders und ihr Typ
   static int      knownPositions[];                        // die bekannten Positionen

   if (accountNumber[0] == 0) {                             // 1. Aufruf
      accountNumber[0]   = account;
      accountInitTime[0] = TimeGMT();
      //Print("EventListener.PositionOpen()   Account "+ account +" nach 1. Lib-Aufruf initialisiert, GMT-Zeit: "+ TimeToStr(accountInitTime[0], TIME_DATE|TIME_MINUTES|TIME_SECONDS));
   }
   else if (accountNumber[0] != account) {                  // Aufruf nach Accountwechsel zur Laufzeit: bekannte Positionen löschen
      accountNumber[0]   = account;
      accountInitTime[0] = TimeGMT();
      ArrayResize(knownPendings, 0);
      ArrayResize(knownPositions, 0);
      //Print("EventListener.PositionOpen()   Account "+ account +" nach Accountwechsel initialisiert, GMT-Zeit: "+ TimeToStr(accountInitTime[0], TIME_DATE|TIME_MINUTES|TIME_SECONDS));
   }

   int orders = OrdersTotal();

   // pending Orders und offene Positionen überprüfen
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         break;

      int n, pendings, positions, type=OrderType(), ticket=OrderTicket();

      // pending Orders überprüfen und ggf. aktualisieren
      if (type==OP_BUYLIMIT || type==OP_SELLLIMIT || type==OP_BUYSTOP || type==OP_SELLSTOP) {
         pendings = ArrayRange(knownPendings, 0);
         for (n=0; n < pendings; n++)
            if (knownPendings[n][0] == ticket)              // bekannte pending Order
               break;
         if (n < pendings) continue;

         ArrayResize(knownPendings, pendings+1);            // neue (unbekannte) pending Order
         knownPendings[pendings][0] = ticket;
         knownPendings[pendings][1] = type;
         //Print("EventListener.PositionOpen()   pending order #", ticket, " added: ", OperationTypeToStr(type));
      }

      // offene Positionen überprüfen und ggf. aktualisieren
      else if (type==OP_BUY || type==OP_SELL) {
         positions = ArraySize(knownPositions);
         for (n=0; n < positions; n++)
            if (knownPositions[n] == ticket)                // bekannte Position
               break;
         if (n < positions) continue;

         // Die offenen Positionen stehen u.U. (z.B. nach Accountwechsel) erst nach einigen Ticks zur Verfügung. Daher müssen
         // neue Positionen zusätzlich anhand ihres OrderOpen-Timestamps auf ihren jeweiligen Status überprüft werden.

         // neue (unbekannte) Position: prüfen, ob sie nach Accountinitialisierung geöffnet wurde (= wirklich neu ist)
         if (accountInitTime[0] <= ServerToGMT(OrderOpenTime())) {
            // ja, in flags angegebene Orderkriterien prüfen
            int event = 1;
            pendings = ArrayRange(knownPendings, 0);

            if (flags & OFLAG_CURRENTSYMBOL != 0)   event &= (OrderSymbol()==Symbol())+0;    // MQL kann Booleans für Binärops. nicht casten
            if (flags & OFLAG_BUY           != 0)   event &= (type==OP_BUY )+0;
            if (flags & OFLAG_SELL          != 0)   event &= (type==OP_SELL)+0;
            if (flags & OFLAG_MARKETORDER   != 0) {
               for (int z=0; z < pendings; z++)
                  if (knownPendings[z][0] == ticket)                                         // Order war pending
                     break;                         event &= (z==pendings)+0;
            }
            if (flags & OFLAG_PENDINGORDER  != 0) {
               for (z=0; z < pendings; z++)
                  if (knownPendings[z][0] == ticket)                                         // Order war pending
                     break;                         event &= (z<pendings)+0;
            }

            // wenn alle Kriterien erfüllt sind, Ticket in Resultarray speichern
            if (event == 1) {
               ArrayResize(lpTickets, ArraySize(lpTickets)+1);
               lpTickets[ArraySize(lpTickets)-1] = ticket;
            }
         }

         ArrayResize(knownPositions, positions+1);
         knownPositions[positions] = ticket;
         //Print("EventListener.PositionOpen()   position #", ticket, " added: ", OperationTypeToStr(type));
      }
   }

   bool eventStatus = (ArraySize(lpTickets) > 0);
   //Print("EventListener.PositionOpen()   eventStatus: "+ eventStatus);

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.PositionOpen()", error);
      return(false);
   }
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein PositionClose-Event aufgetreten ist. Werden zusätzliche Orderkriterien angegeben, wird das Event nur
 * dann signalisiert, wenn alle angegebenen Kriterien erfüllt sind.
 *
 * @param  int& lpTickets[] - Zielarray für Ticket-Nummern geschlossener Positionen
 * @param  int  flags       - ein oder mehrere zusätzliche Orderkriterien: OFLAG_CURRENTSYMBOL, OFLAG_BUY, OFLAG_SELL, OFLAG_MARKETORDER, OFLAG_PENDINGORDER
 *                            (default: 0)
 * @return bool - Ergebnis
 */
bool EventListener.PositionClose(int& lpTickets[], int flags=0) {
   // ohne Verbindung zum Tradeserver sofortige Rückkehr
   int account = AccountNumber();
   if (account == 0)
      return(false);

   // Ergebnisarray sicherheitshalber zurücksetzen
   if (ArraySize(lpTickets) > 0)
      ArrayResize(lpTickets, 0);

   static int accountNumber[1];
   static int knownPositions[];                                  // bekannte Positionen
          int noOfKnownPositions = ArraySize(knownPositions);

   if (accountNumber[0] == 0) {
      accountNumber[0] = account;
      //Print("EventListener.PositionClose()   Account "+ account +" nach 1. Lib-Aufruf initialisiert");
   }
   else if (accountNumber[0] != account) {
      accountNumber[0] = account;
      ArrayResize(knownPositions, 0);
      //Print("EventListener.PositionClose()   Account "+ account +" nach Accountwechsel initialisiert");
   }
   else {
      // alle beim letzten Aufruf offenen Positionen prüfen
      for (int i=0; i < noOfKnownPositions; i++) {
         if (!OrderSelect(knownPositions[i], SELECT_BY_TICKET)) {
            int error = GetLastError();
            if (error == NO_ERROR)
               error = ERR_RUNTIME_ERROR;
            catch("EventListener.PositionClose(1)   account "+ account +" ("+ AccountNumber() +"): error selecting position #"+ knownPositions[i] +", check your History tab filter settings", error);
            // TODO: bei offenen Orders in einem Account und dem ersten Login in einen neuen Account crasht alles (erster Login dauert länger)
            return(false);
         }

         if (OrderCloseTime() > 0) {   // Position geschlossen, in flags angegebene Orderkriterien prüfen
            int    event=1, type=OrderType();
            bool   pending;
            string comment = StringToLower(StringTrim(OrderComment()));

            if      (StringStartsWith(comment, "so:" )) pending = true;                      // Margin Stopout, wie pending behandeln
            else if (StringEndsWith  (comment, "[tp]")) pending = true;
            else if (StringEndsWith  (comment, "[sl]")) pending = true;
            else if (OrderTakeProfit() > 0) {
               if      (type == OP_BUY )                        pending = (OrderClosePrice() >= OrderTakeProfit());
               else if (type == OP_SELL)                        pending = (OrderClosePrice() <= OrderTakeProfit());
            }

            if (flags & OFLAG_CURRENTSYMBOL != 0) event &= (OrderSymbol()==Symbol())+0;      // MQL kann Booleans für Binärops. nicht casten
            if (flags & OFLAG_BUY           != 0) event &= (type==OP_BUY )+0;
            if (flags & OFLAG_SELL          != 0) event &= (type==OP_SELL)+0;
            if (flags & OFLAG_MARKETORDER   != 0) event &= (!pending)+0;
            if (flags & OFLAG_PENDINGORDER  != 0) event &= ( pending)+0;

            // wenn alle Kriterien erfüllt sind, Ticket in Resultarray speichern
            if (event == 1) {
               ArrayResize(lpTickets, ArraySize(lpTickets)+1);
               lpTickets[ArraySize(lpTickets)-1] = knownPositions[i];
            }
         }
      }
   }


   // offene Positionen jedes mal neu einlesen (löscht auch vorher gespeicherte und jetzt ggf. geschlossene Positionen)
   if (noOfKnownPositions > 0) {
      ArrayResize(knownPositions, 0);
      noOfKnownPositions = 0;
   }
   int orders = OrdersTotal();
   for (i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         break;
      if (OrderType()==OP_BUY || OrderType()==OP_SELL) {
         noOfKnownPositions++;
         ArrayResize(knownPositions, noOfKnownPositions);
         knownPositions[noOfKnownPositions-1] = OrderTicket();
         //Print("EventListener.PositionClose()   open position #", ticket, " added: ", OperationTypeToStr(OrderType()));
      }
   }

   bool eventStatus = (ArraySize(lpTickets) > 0);
   //Print("EventListener.PositionClose()   eventStatus: "+ eventStatus);

   error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.PositionClose(2)", error);
      return(false);
   }
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein AccountPayment-Event aufgetreten ist.
 *
 * @param  int& lpResults[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int  flags       - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool EventListener.AccountPayment(int& lpResults[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(lpResults) > 0)
      ArrayResize(lpResults, 0);

   // TODO: implementieren

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.AccountPayment()", error);
      return(false);
   }
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein HistoryChange-Event aufgetreten ist.
 *
 * @param  int& lpResults[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param  int  flags       - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool EventListener.HistoryChange(int& lpResults[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(lpResults) > 0)
      ArrayResize(lpResults, 0);

   // TODO: implementieren

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.HistoryChange()", error);
      return(false);
   }
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein AccountChange-Event aufgetreten ist.
 * Beim Start des Terminals und während eines Accountwechsels treten in der Initialiserungsphase "Ticks" mit AccountNumber() == 0 auf. Diese fehlerhaften Aufrufe des Terminals
 * werden nicht als Accountwechsel im Sinne dieses Listeners interpretiert.
 *
 * @param  int& lpResults[] - eventspezifische Detailinfos: { last_account_number, current_account_number, current_account_init_servertime }
 * @param  int  flags       - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool EventListener.AccountChange(int& lpResults[], int flags=0) {
   static int accountData[3];                         // { last_account_number, current_account_number, current_account_init_servertime }

   bool eventStatus = false;
   int  account = AccountNumber();

   if (account != 0) {                                // AccountNumber() == 0 ignorieren
      if (accountData[1] == 0) {                      // 1. Lib-Aufruf
         accountData[0] = 0;
         accountData[1] = account;
         accountData[2] = GmtToServerTime(TimeGMT());
         //Print("EventListener.AccountChange()   Account "+ account +" nach 1. Lib-Aufruf initialisiert, ServerTime="+ TimeToStr(accountData[2], TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      }
      else if (accountData[1] != account) {           // Aufruf nach Accountwechsel zur Laufzeit
         accountData[0] = accountData[1];
         accountData[1] = account;
         accountData[2] = GmtToServerTime(TimeGMT());
         //Print("EventListener.AccountChange()   Account "+ account +" nach Accountwechsel initialisiert, ServerTime="+ TimeToStr(accountData[2], TIME_DATE|TIME_MINUTES|TIME_SECONDS));
         eventStatus = true;
      }
   }
   //Print("EventListener.AccountChange()   eventStatus: "+ eventStatus);

   if (ArraySize(lpResults) != 3)
      ArrayResize(lpResults, 3);
   ArrayCopy(lpResults, accountData);

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventListener.AccountChange()", error);
      return(false);
   }
   return(eventStatus);
}


double EventTracker.bandLimits[3];

/**
 * Gibt die aktuellen BollingerBand-Limite des EventTrackers zurück. Die Limite werden aus Performancegründen timeframe-übergreifend
 * in der Library gespeichert.
 *
 * @param  double& lpResults[3] - Zeiger auf Array für die Ergebnisse { UPPER_VALUE, MA_VALUE, LOWER_VALUE }
 *
 * @return bool - Erfolgsstatus: TRUE, wenn die Daten erfolgreich gelesen wurden,
 *                               FALSE andererseits (nicht existierende Daten)
 */
bool EventTracker.GetBandLimits(double& lpResults[]) {
   // falls keine Daten gespeichert sind ...
   if (EventTracker.bandLimits[0]==0 || EventTracker.bandLimits[1]==0 || EventTracker.bandLimits[2]==0)
      return(false);

   lpResults[0] = EventTracker.bandLimits[0];
   lpResults[1] = EventTracker.bandLimits[1];
   lpResults[2] = EventTracker.bandLimits[2];

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventTracker.GetBandLimits()", error);
      return(false);
   }
   return(true);
}


/**
 * Setzt die aktuellen BollingerBand-Limite des EventTrackers. Die Limite werden aus Performancegründen timeframe-übergreifend
 * in der Library gespeichert.
 *
 * @param  double& lpLimits[3] - Array mit den aktuellen Limiten { UPPER_VALUE, MA_VALUE, LOWER_VALUE }
 *
 * @return bool - Erfolgsstatus
 */
bool EventTracker.SetBandLimits(double& lpLimits[]) {
   EventTracker.bandLimits[0] = lpLimits[0];
   EventTracker.bandLimits[1] = lpLimits[1];
   EventTracker.bandLimits[2] = lpLimits[2];

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventTracker.SetBandLimits()", error);
      return(false);
   }
   return(true);
}


double EventTracker.rateGridLimits[2];

/**
 * Gibt die aktuellen RateGrid-Limite des EventTrackers zurück. Die Limite werden aus Performancegründen timeframe-übergreifend
 * in der Library gespeichert.
 *
 * @param  double& lpResults[2] - Zeiger auf Array für die Ergebnisse { LOWER_VALUE, UPPER_VALUE }
 *
 * @return bool - Erfolgsstatus: TRUE, wenn die Daten erfolgreich gelesen wurden,
 *                               FALSE andererseits (nicht existierende Daten)
 */
bool EventTracker.GetRateGridLimits(double& lpResults[]) {
   // falls keine Daten gespeichert sind ...
   if (EventTracker.rateGridLimits[0]==0 || EventTracker.rateGridLimits[1]==0)
      return(false);

   lpResults[0] = EventTracker.rateGridLimits[0];
   lpResults[1] = EventTracker.rateGridLimits[1];

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventTracker.GetRateGridLimits()", error);
      return(false);
   }
   return(true);
}


/**
 * Setzt die aktuellen RateGrid-Limite des EventTrackers. Die Limite werden aus Performancegründen timeframe-übergreifend
 * in der Library gespeichert.
 *
 * @param  double& lpLimits[2] - Array mit den aktuellen Limiten { UPPER_VALUE, LOWER_VALUE }
 *
 * @return bool - Erfolgsstatus
 */
bool EventTracker.SetRateGridLimits(double& lpLimits[]) {
   EventTracker.rateGridLimits[0] = lpLimits[0];
   EventTracker.rateGridLimits[1] = lpLimits[1];

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("EventTracker.SetRateGridLimits()", error);
      return(false);
   }
   return(true);
}


/**
 * Zerlegt einen String in Teilstrings.
 *
 * @param  string  object      - zu zerlegender String
 * @param  string  separator   - Trennstring
 * @param  string& lpResults[] - Zielarray für die Teilstrings
 *
 * @return int - Fehlerstatus
 */
int Explode(string object, string separator, string& lpResults[]) {
   int lenObject    = StringLen(object),
       lenSeparator = StringLen(separator);

   if (lenObject == 0) {                     // Leerstring
      ArrayResize(lpResults, 1);
      lpResults[0] = object;
   }
   else if (separator == "") {               // String in einzelne Zeichen zerlegen
      ArrayResize(lpResults, lenObject);

      for (int i=0; i < lenObject; i++) {
         lpResults[i] = StringSubstr(object, i, 1);
      }
   }
   else {                                    // String in Substrings zerlegen
      int size, pos;
      i = 0;

      while (i < lenObject) {
         ArrayResize(lpResults, size+1);

         pos = StringFind(object, separator, i);
         if (pos == -1) {
            lpResults[size] = StringSubstr(object, i);
            break;
         }
         else if (i == pos) {
            lpResults[size] = "";
         }
         else {
            lpResults[size] = StringSubstrFix(object, i, pos-i);
         }
         size++;
         i = pos + lenSeparator;
      }
   }
   return(catch("Explode()"));
}


/**
 * Liest die History eines Accounts aus dem Dateisystem in das angegebene Ergebnisarray ein (Daten werden als Strings gespeichert).
 *
 * @param  int     account                      - Account-Nummer
 * @param  string& lpResults[][HISTORY_COLUMNS] - Zeiger auf Ergebnisarray
 *
 * @return int - Fehlerstatus: ERR_CANNOT_OPEN_FILE, wenn die Datei nicht gefunden wurde
 */
int GetAccountHistory(int account, string& lpResults[][HISTORY_COLUMNS]) {
   if (ArrayRange(lpResults, 1) != HISTORY_COLUMNS)
      return(catch("GetAccountHistory(1)   invalid parameter lpResults["+ ArrayRange(lpResults, 0) +"]["+ ArrayRange(lpResults, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   int    cache.account[1];
   string cache[][HISTORY_COLUMNS];

   ArrayResize(lpResults, 0);

   // Daten nach Möglichkeit aus dem Cache liefern
   if (cache.account[0] == account) {
      ArrayCopy(lpResults, cache);
      log("GetAccountHistory()   delivering "+ ArrayRange(cache, 0) +" history entries for account "+ account +" from cache");
      return(catch("GetAccountHistory(2)"));
   }

   // Cache-Miss, History-Datei auslesen
   string header[HISTORY_COLUMNS] = { "Ticket","OpenTime","OpenTimestamp","Description","Type","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","ExpirationTime","ExpirationTimestamp","MagicNumber","Commission","Swap","NetProfit","GrossProfit","Balance","Comment" };
   string filename = GetAccountDirectory(account) +"/"+ account + "_account_history.csv";
   int hFile = FileOpen(filename, FILE_CSV|FILE_READ, '\t');
   if (hFile < 0) {
      int error = GetLastError();
      if (error == ERR_CANNOT_OPEN_FILE)
         return(error);
      return(catch("GetAccountHistory(3)   FileOpen(\""+ filename +"\")", error));
   }

   string value;
   bool   newLine=true, blankLine=false, lineEnd=true;
   int    lines=0, row=-2, col=-1;
   string result[][HISTORY_COLUMNS]; ArrayResize(result, 0);   // tmp. Zwischenspeicher für ausgelesene Daten

   // Daten feldweise einlesen und Zeilen erkennen
   while (!FileIsEnding(hFile)) {
      newLine = false;
      if (lineEnd) {                                           // Wenn beim letzten Durchlauf das Zeilenende erreicht wurde,
         newLine   = true;                                     // Flags auf Zeilenbeginn setzen.
         blankLine = false;
         lineEnd   = false;
         col = -1;                                             // Spaltenindex vor der ersten Spalte (erste Spalte = 0)
      }

      // nächstes Feld auslesen
      value = FileReadString(hFile);

      // auf Leerzeilen, Zeilen- und Dateiende prüfen
      if (FileIsLineEnding(hFile) || FileIsEnding(hFile)) {
         lineEnd = true;
         if (newLine) {
            if (StringLen(value) == 0) {
               if (FileIsEnding(hFile))                        // Zeilenbeginn + Leervalue + Dateiende  => nichts, also Abbruch
                  break;
               blankLine = true;                               // Zeilenbeginn + Leervalue + Zeilenende => Leerzeile
            }
         }
         lines++;
      }

      // Leerzeilen überspringen
      if (blankLine)
         continue;

      value = StringTrim(value);

      // Kommentarzeilen überspringen
      if (newLine) /*&&*/ if (StringGetChar(value, 0)==35)     // char(35) = #
         continue;

      // Zeilen- und Spaltenindex aktualisieren und Bereich überprüfen
      col++;
      if (lineEnd) /*&&*/ if (col!=HISTORY_COLUMNS-1) {
         error = catch("GetAccountHistory(4)   data format error in \""+ filename +"\", column count in line "+ lines +" is not "+ HISTORY_COLUMNS, ERR_RUNTIME_ERROR);
         break;
      }
      if (newLine)
         row++;

      // Headerinformationen in der ersten Datenzeile überprüfen und Headerzeile überspringen
      if (row == -1) {
         if (value != header[col]) {
            error = catch("GetAccountHistory(5)   data format error in \""+ filename +"\", unexpected column header \""+ value +"\"", ERR_RUNTIME_ERROR);
            break;
         }
         continue;   // jmp
      }

      // Ergebnisarray vergrößern und Rohdaten speichern (als String)
      if (newLine)
         ArrayResize(result, row+1);
      result[row][col] = value;
   }

   // Hier hat entweder ein Formatfehler ERR_RUNTIME_ERROR (bereits gemeldet) oder das Dateiende END_OF_FILE ausgelöst.
   if (error == NO_ERROR) {
      error = GetLastError();
      if (error == ERR_END_OF_FILE) {
         error = NO_ERROR;
      }
      else {
         catch("GetAccountHistory(6)", error);
      }
   }

   // vor evt. Fehler-Rückkehr auf jeden Fall Datei schließen
   FileClose(hFile);

   if (error != NO_ERROR)    // ret
      return(error);


   // Daten in Zielarray kopieren und cachen
   if (ArrayRange(result, 0) > 0) {       // "leere" Historydaten nicht cachen (falls Datei noch erstellt wird)
      ArrayCopy(lpResults, result);

      cache.account[0] = account;
      ArrayResize(cache, 0); ArrayCopy(cache, result);
      log("GetAccountHistory()   caching "+ ArrayRange(cache, 0) +" history entries for account "+ account);
   }

   return(catch("GetAccountHistory(7)"));
}


/**
 * Gibt die aktuelle Account-Nummer zurück (unabhängig von einer Connection zum Tradeserver).
 *
 * @return int - Account-Nummer (positiver Wert) oder 0, falls ein Fehler aufgetreten ist.
 *
 *
 * NOTE:    Während des Terminalstarts kann der Fehler ERR_TERMINAL_NOT_YET_READY auftreten.
 * ----
 */
int GetAccountNumber() {
   int account = AccountNumber();

   if (account == 0) {                                // ohne Connection Titelzeile des Hauptfensters auswerten
      string title = GetWindowText(GetTerminalWindow());
      if (title == "") {
         last_error = ERR_TERMINAL_NOT_YET_READY;
         return(0);
      }

      int pos = StringFind(title, ":");
      if (pos < 1) {
         catch("GetAccountNumber(1)   account number separator not found in top window title \""+ title +"\"", ERR_RUNTIME_ERROR);
         return(0);
      }

      string strAccount = StringLeft(title, pos);
      if (!StringIsDigit(strAccount)) {
         catch("GetAccountNumber(2)   account number in top window title contains non-digit characters: "+ strAccount, ERR_RUNTIME_ERROR);
         return(0);
      }

      account = StrToInteger(strAccount);
   }

   if (catch("GetAccountNumber(3)") != NO_ERROR)
      return(0);
   return(account);
}


/**
 * Gibt den durchschnittlichen Spread des angegebenen Instruments zurück.
 *
 * @param  string symbol - Instrument
 *
 * @return double - Spread
 */
double GetAverageSpread(string symbol) {

   if      (symbol == "EURUSD") return(0.0001 );
   else if (symbol == "GBPJPY") return(0.05   );
   else if (symbol == "GBPCHF") return(0.0004 );
   else if (symbol == "GBPUSD") return(0.00012);
   else if (symbol == "USDCAD") return(0.0002 );
   else if (symbol == "USDCHF") return(0.0001 );

   //spread = MarketInfo(symbol, MODE_POINT) * MarketInfo(symbol, MODE_SPREAD); // aktueller Spread in Points
   catch("GetAverageSpread()  average spread for "+ symbol +" not found", ERR_UNKNOWN_SYMBOL);
   return(0);
}


/**
 * Schreibt die Balance-History eines Accounts in die angegebenen Ergebnisarrays (aufsteigend nach Zeitpunkt sortiert).
 *
 * @param  int       account    - Account-Nummer
 * @param  datetime& lpTimes[]  - Zeiger auf Ergebnisarray für die Zeitpunkte der Balanceänderung
 * @param  double&   lpValues[] - Zeiger auf Ergebnisarray der entsprechenden Balancewerte
 *
 * @return int - Fehlerstatus
 */
int GetBalanceHistory(int account, datetime& lpTimes[], double& lpValues[]) {
   int      cache.account[1];
   datetime cache.times[];
   double   cache.values[];

   ArrayResize(lpTimes,  0);
   ArrayResize(lpValues, 0);

   // Daten nach Möglichkeit aus dem Cache liefern       TODO: paralleles Cachen mehrerer Wertereihen ermöglichen
   if (cache.account[0] == account) {
      ArrayCopy(lpTimes , cache.times);
      ArrayCopy(lpValues, cache.values);
      log("GetBalanceHistory()   delivering "+ ArraySize(cache.times) +" balance values for account "+ account +" from cache");
      return(catch("GetBalanceHistory(1)"));
   }

   // Cache-Miss, Balance-Daten aus Account-History auslesen
   string data[][HISTORY_COLUMNS]; ArrayResize(data, 0);
   int error = GetAccountHistory(account, data);
   if (error == ERR_CANNOT_OPEN_FILE) return(catch("GetBalanceHistory(2)", error));
   if (error != NO_ERROR            ) return(catch("GetBalanceHistory(3)"));

   // Balancedatensätze einlesen und auswerten (History ist nach CloseTime sortiert)
   datetime time, lastTime;
   double   balance, lastBalance;
   int n, size=ArrayRange(data, 0);

   if (size == 0)
      return(catch("GetBalanceHistory(4)"));

   for (int i=0; i<size; i++) {
      balance = StrToDouble (data[i][AH_BALANCE       ]);
      time    = StrToInteger(data[i][AH_CLOSETIMESTAMP]);

      // der erste Datensatz wird immer geschrieben...
      if (i == 0) {
         ArrayResize(lpTimes,  n+1);
         ArrayResize(lpValues, n+1);
         lpTimes [n] = time;
         lpValues[n] = balance;
         n++;                                // n: Anzahl der existierenden Ergebnisdaten => ArraySize(lpTimes)
      }
      else if (balance != lastBalance) {
         // ... alle weiteren nur, wenn die Balance sich geändert hat
         if (time == lastTime) {             // Existieren mehrere Balanceänderungen zum selben Zeitpunkt,
            lpValues[n-1] = balance;         // wird der letzte Wert nur mit dem aktuellen überschrieben.
         }
         else {
            ArrayResize(lpTimes,  n+1);
            ArrayResize(lpValues, n+1);
            lpTimes [n] = time;
            lpValues[n] = balance;
            n++;
         }
      }
      lastTime    = time;
      lastBalance = balance;
   }

   // Daten cachen
   cache.account[0] = account;
   ArrayResize(cache.times,  0); ArrayCopy(cache.times,  lpTimes );
   ArrayResize(cache.values, 0); ArrayCopy(cache.values, lpValues);
   log("GetBalanceHistory()   caching "+ ArraySize(lpTimes) +" balance values for account "+ account);

   return(catch("GetBalanceHistory(5)"));
}


/**
 * Gibt den Rechnernamen des laufenden Systems zurück.
 *
 * @return string - Name
 */
string GetComputerName() {
   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");   // siehe MetaTrader.doc: Zeigerproblematik
   int lpBufferSize[1]; lpBufferSize[0] = MAX_STRING_LITERAL_LEN;

   if (!GetComputerNameA(buffer[0], lpBufferSize)) {
      catch("GetComputerName(1)   kernel32.GetComputerName(buffer, "+ lpBufferSize[0] +") = FALSE", ERR_WINDOWS_ERROR);
      return("");
   }

   if (catch("GetComputerName(2)") != NO_ERROR)
      return("");
   return(buffer[0]);
}


/**
 * Gibt einen Konfigurationswert als Boolean zurück.  Dabei werden die globale als auch die lokale Konfiguration der MetaTrader-Installation durchsucht.
 * Lokale Konfigurationswerte haben eine höhere Priorität als globale Werte.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  bool   defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return bool - Konfigurationswert
 */
bool GetConfigBool(string section, string key, bool defaultValue=false) {
   string localConfigFile  = StringConcatenate(TerminalPath(), "\\experts\\config\\metatrader-local-config.ini");
   string globalConfigFile = StringConcatenate(TerminalPath(), "\\..\\metatrader-global-config.ini");

   string strDefault = defaultValue;

   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");   // siehe MetaTrader.doc: Zeigerproblematik

   // zuerst globale, dann lokale Config auslesen
   GetPrivateProfileStringA(section, key, strDefault, buffer[0], MAX_STRING_LITERAL_LEN, globalConfigFile);
   GetPrivateProfileStringA(section, key, buffer[0] , buffer[0], MAX_STRING_LITERAL_LEN, localConfigFile);

   bool result = (buffer[0]=="1" || buffer[0]=="true" || buffer[0]=="yes" || buffer[0]=="on");

   if (catch("GetConfigBool()") != NO_ERROR)
      return(false);

   return(result);
}


/**
 * Gibt einen Konfigurationswert als Double zurück.  Dabei werden die globale als auch die lokale Konfiguration der MetaTrader-Installation durchsucht.
 * Lokale Konfigurationswerte haben eine höhere Priorität als globale Werte.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  double defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return double - Konfigurationswert
 */
double GetConfigDouble(string section, string key, double defaultValue=0) {
   string localConfigFile  = StringConcatenate(TerminalPath(), "\\experts\\config\\metatrader-local-config.ini");
   string globalConfigFile = StringConcatenate(TerminalPath(), "\\..\\metatrader-global-config.ini");

   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");   // siehe MetaTrader.doc: Zeigerproblematik

   // zuerst globale, dann lokale Config auslesen
   GetPrivateProfileStringA(section, key, DoubleToStr(defaultValue, 8), buffer[0], MAX_STRING_LITERAL_LEN, globalConfigFile);
   GetPrivateProfileStringA(section, key, buffer[0]                   , buffer[0], MAX_STRING_LITERAL_LEN, localConfigFile);

   double result = StrToDouble(buffer[0]);

   if (catch("GetConfigDouble()") != NO_ERROR)
      return(0);

   return(result);
}


/**
 * Gibt einen Konfigurationswert als Integer zurück.  Dabei werden die globale als auch die lokale Konfiguration der MetaTrader-Installation durchsucht.
 * Lokale Konfigurationswerte haben eine höhere Priorität als globale Werte.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  int    defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return int - Konfigurationswert
 */
int GetConfigInt(string section, string key, int defaultValue=0) {
   string localConfigFile  = StringConcatenate(TerminalPath(), "\\experts\\config\\metatrader-local-config.ini");
   string globalConfigFile = StringConcatenate(TerminalPath(), "\\..\\metatrader-global-config.ini");

   // zuerst globale, dann lokale Config auslesen
   int result = GetPrivateProfileIntA(section, key, defaultValue, globalConfigFile);   // gibt auch negative Werte richtig zurück
       result = GetPrivateProfileIntA(section, key, result      , localConfigFile);

   if (catch("GetConfigInt()") != NO_ERROR)
      return(0);

   return(result);
}


/**
 * Gibt einen Konfigurationswert als String zurück.  Dabei werden die globale als auch die lokale Konfiguration der MetaTrader-Installation durchsucht.
 * Lokale Konfigurationswerte haben eine höhere Priorität als globale Werte.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  string defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return string - Konfigurationswert
 */
string GetConfigString(string section, string key, string defaultValue="") {
   string localConfigFile  = StringConcatenate(TerminalPath(), "\\experts\\config\\metatrader-local-config.ini");
   string globalConfigFile = StringConcatenate(TerminalPath(), "\\..\\metatrader-global-config.ini");

   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");      // siehe MetaTrader.doc: Zeigerproblematik

   // zuerst globale, dann lokale Config auslesen
   GetPrivateProfileStringA(section, key, defaultValue, buffer[0], MAX_STRING_LITERAL_LEN, globalConfigFile);
   GetPrivateProfileStringA(section, key, buffer[0]   , buffer[0], MAX_STRING_LITERAL_LEN, localConfigFile);

   if (catch("GetConfigString()") != NO_ERROR)
      return("");

   return(buffer[0]);
}


/**
 * Gibt den Offset der angegebenen New Yorker Zeit (Eastern Time) zu GMT (Greenwich Mean Time) zurück.
 *
 * @param  datetime easternTime - New Yorker Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetEasternToGmtOffset(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternToGmtOffset(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   int offset, year = TimeYear(easternTime)-1970;

   // New York                                      GMT-0500,GMT-0400
   if      (easternTime < EDT_transitions[year][0]) offset = -5 * HOURS;
   else if (easternTime < EDT_transitions[year][1]) offset = -4 * HOURS;
   else                                             offset = -5 * HOURS;

   if (catch("GetEasternToGmtOffset(2)") != NO_ERROR)
      return(EMPTY_VALUE);

   return(offset);
}


/**
 * Gibt den Offset der angegebenen New Yorker Zeit (Eastern Time) zu Tradeserver-Zeit zurück.
 *
 * @param  datetime easternTime - New Yorker Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetEasternToServerTimeOffset(datetime easternTime) {
   if (easternTime < 1) {
      catch("GetEasternToServerTimeOffset(1)  invalid parameter easternTime: "+ easternTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   string zone = GetServerTimezone();
   if (zone == "")
      return(EMPTY_VALUE);

   // schnelle Rückkehr, wenn der Tradeserver unter Eastern Time läuft
   if (zone == "EST,EDT")
      return(0);

   // Offset Eastern zu GMT
   int easternToGmtOffset = GetEasternToGmtOffset(easternTime);

   // Offset GMT zu Tradeserver
   int gmtToServerTimeOffset;
   if (zone != "GMT")
      gmtToServerTimeOffset = GetGmtToServerTimeOffset(easternTime - easternToGmtOffset);

   if (catch("GetEasternToServerTimeOffset(2)") != NO_ERROR)
      return(EMPTY_VALUE);

   return(easternToGmtOffset + gmtToServerTimeOffset);
}


/**
 * Gibt einen globalen Konfigurationswert als Boolean zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  bool   defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return bool - Konfigurationswert
 */
bool GetGlobalConfigBool(string section, string key, bool defaultValue=false) {
   string configFile = StringConcatenate(TerminalPath(), "\\..\\metatrader-global-config.ini");
   string strDefault = defaultValue;

   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");      // siehe MetaTrader.doc: Zeigerproblematik

   GetPrivateProfileStringA(section, key, strDefault, buffer[0], MAX_STRING_LITERAL_LEN, configFile);

   buffer[0]   = StringToLower(buffer[0]);
   bool result = (buffer[0]=="1" || buffer[0]=="true" || buffer[0]=="yes" || buffer[0]=="on");

   if (catch("GetGlobalConfigBool()") != NO_ERROR)
      return(false);

   return(result);
}


/**
 * Gibt einen globalen Konfigurationswert als Double zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  double defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return double - Konfigurationswert
 */
double GetGlobalConfigDouble(string section, string key, double defaultValue=0) {
   string configFile = StringConcatenate(TerminalPath(), "\\..\\metatrader-global-config.ini");

   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");      // siehe MetaTrader.doc: Zeigerproblematik

   GetPrivateProfileStringA(section, key, DoubleToStr(defaultValue, 8), buffer[0], MAX_STRING_LITERAL_LEN, configFile);

   double result = StrToDouble(buffer[0]);

   if (catch("GetGlobalConfigDouble()") != NO_ERROR)
      return(0);

   return(result);
}


/**
 * Gibt einen globalen Konfigurationswert als Integer zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  int    defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return int - Konfigurationswert
 */
int GetGlobalConfigInt(string section, string key, int defaultValue=0) {
   string configFile = StringConcatenate(TerminalPath(), "\\..\\metatrader-global-config.ini");

   int result = GetPrivateProfileIntA(section, key, defaultValue, configFile);   // gibt auch negative Werte richtig zurück

   if (catch("GetGlobalConfigInt()") != NO_ERROR)
      return(0);

   return(result);
}


/**
 * Gibt einen globalen Konfigurationswert als String zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  string defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return string - Konfigurationswert
 */
string GetGlobalConfigString(string section, string key, string defaultValue="") {
   string configFile = StringConcatenate(TerminalPath(), "\\..\\metatrader-global-config.ini");

   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");      // siehe MetaTrader.doc: Zeigerproblematik

   GetPrivateProfileStringA(section, key, defaultValue, buffer[0], MAX_STRING_LITERAL_LEN, configFile);

   if (catch("GetGlobalConfigString()") != NO_ERROR)
      return("");

   return(buffer[0]);
}


/**
 * Gibt den Offset der angegebenen GMT-Zeit zu New Yorker Zeit (Eastern Time) zurück.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 *
 * NOTE:    Parameter ist ein GMT-Zeitpunkt, das Ergebnis ist daher der entgegengesetzte Wert des Offsets von Eastern Time zu GMT.
 * -----
 */
int GetGmtToEasternTimeOffset(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtToEasternTimeOffset(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   int offset, year = TimeYear(gmtTime)-1970;

   // New York                                  GMT-0500[,GMT-0400]
   if      (gmtTime < EDT_transitions[year][2]) offset = 5 * HOURS;
   else if (gmtTime < EDT_transitions[year][3]) offset = 4 * HOURS;
   else                                         offset = 5 * HOURS;

   if (catch("GetGmtToEasternTimeOffset(2)") != NO_ERROR)
      return(EMPTY_VALUE);

   return(offset);
}


/**
 * Gibt den Offset der angegebenen GMT-Zeit zur Tradeserver-Zeit zurück.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 *
 * NOTE:    Parameter ist ein GMT-Zeitpunkt, das Ergebnis ist daher der entgegengesetzte Wert des Offsets von Tradeserver-Zeit zu GMT.
 * -----
 */
int GetGmtToServerTimeOffset(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GetGmtToServerTimeOffset(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   string timezone = GetServerTimezone();
   if (timezone == "")
      return(EMPTY_VALUE);
   int offset, year = TimeYear(gmtTime)-1970;

   // Europe/Kiev                                   GMT+0200[,GMT+0300]
   if      (timezone == "EET"     )                 offset = -2 * HOURS;
   else if (timezone == "EET,EEST") {
      if      (gmtTime < EEST_transitions[year][2]) offset = -2 * HOURS;
      else if (gmtTime < EEST_transitions[year][3]) offset = -3 * HOURS;
      else                                          offset = -2 * HOURS;
   }

   // Europe/Berlin                                 GMT+0100[,GMT+0200]
   else if (timezone == "CET"     )                 offset = -1 * HOUR;
   else if (timezone == "CET,CEST") {
      if      (gmtTime < CEST_transitions[year][2]) offset = -1 * HOUR;
      else if (gmtTime < CEST_transitions[year][3]) offset = -2 * HOURS;
      else                                          offset = -1 * HOUR;
   }

   // GMT                                           GMT+0000
   else if (timezone == "GMT")                      offset =  0;

   // Europe/London                                 GMT+0000[,GMT+0100]
   else if (timezone == "GMT,BST") {
      if      (gmtTime < BST_transitions[year][2])  offset =  0;
      else if (gmtTime < BST_transitions[year][3])  offset = -1 * HOUR;
      else                                          offset =  0;
   }

   // America/New_York                              GMT-0500[,GMT-0400]
   else if (timezone == "EST"    )                  offset = 5 * HOURS;
   else if (timezone == "EST,EDT") {
      if      (gmtTime < EDT_transitions[year][2])  offset = 5 * HOURS;
      else if (gmtTime < EDT_transitions[year][3])  offset = 4 * HOURS;
      else                                          offset = 5 * HOURS;
   }

   else {
      catch("GetGmtToServerTimeOffset(2)  unknown timezone for account "+ GetAccountNumber() +": \""+ timezone +"\"", ERR_RUNTIME_ERROR);
      return(EMPTY_VALUE);
   }

   if (catch("GetGmtToServerTimeOffset(3)") != NO_ERROR)
      return(EMPTY_VALUE);

   return(offset);
}


/**
 * Gibt einen lokalen Konfigurationswert als Boolean zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  bool   defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return bool - Konfigurationswert
 */
bool GetLocalConfigBool(string section, string key, bool defaultValue=false) {
   string configFile = StringConcatenate(TerminalPath(), "\\experts\\config\\metatrader-local-config.ini");
   string strDefault = defaultValue;

   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");      // siehe MetaTrader.doc: Zeigerproblematik

   GetPrivateProfileStringA(section, key, strDefault, buffer[0], MAX_STRING_LITERAL_LEN, configFile);

   buffer[0]   = StringToLower(buffer[0]);
   bool result = (buffer[0]=="1" || buffer[0]=="true" || buffer[0]=="yes" || buffer[0]=="on");

   if (catch("GetLocalConfigBool()") != NO_ERROR)
      return(false);

   return(result);
}


/**
 * Gibt einen lokalen Konfigurationswert als Double zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  double defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return double - Konfigurationswert
 */
double GetLocalConfigDouble(string section, string key, double defaultValue=0) {
   string configFile = StringConcatenate(TerminalPath(), "\\experts\\config\\metatrader-local-config.ini");

   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");      // siehe MetaTrader.doc: Zeigerproblematik

   GetPrivateProfileStringA(section, key, DoubleToStr(defaultValue, 8), buffer[0], MAX_STRING_LITERAL_LEN, configFile);

   double result = StrToDouble(buffer[0]);

   if (catch("GetLocalConfigDouble()") != NO_ERROR)
      return(0);

   return(result);
}


/**
 * Gibt einen lokalen Konfigurationswert als Integer zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  int    defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return int - Konfigurationswert
 */
int GetLocalConfigInt(string section, string key, int defaultValue=0) {
   string configFile = StringConcatenate(TerminalPath(), "\\experts\\config\\metatrader-local-config.ini");

   int result = GetPrivateProfileIntA(section, key, defaultValue, configFile);   // gibt auch negative Werte richtig zurück

   if (catch("GetLocalConfigInt()") != NO_ERROR)
      return(0);

   return(result);
}


/**
 * Gibt einen lokalen Konfigurationswert als String zurück.
 *
 * @param  string section      - Name des Konfigurationsabschnittes
 * @param  string key          - Konfigurationsschlüssel
 * @param  string defaultValue - Wert, der zurückgegeben wird, wenn unter diesem Schlüssel kein Konfigurationswert gefunden wird
 *
 * @return string - Konfigurationswert
 */
string GetLocalConfigString(string section, string key, string defaultValue="") {
   string configFile = StringConcatenate(TerminalPath(), "\\experts\\config\\metatrader-local-config.ini");

   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");      // siehe MetaTrader.doc: Zeigerproblematik

   GetPrivateProfileStringA(section, key, buffer[0], buffer[0], MAX_STRING_LITERAL_LEN, configFile);

   if (catch("GetLocalConfigString()") != NO_ERROR)
      return("");

   return(buffer[0]);
}


/**
 * Gibt den Wochentag des angegebenen Zeitpunkts zurück.
 *
 * @param  datetime time - Zeitpunkt
 * @param  bool     long - TRUE, um die Langform zurückzugeben (default)
 *                         FALSE, um die Kurzform zurückzugeben
 *
 * @return string - Wochentag
 */
string GetDayOfWeek(datetime time, bool long=true) {
   if (time < 1) {
      catch("GetDayOfWeek(1)  invalid parameter time: "+ time, ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }

   static string weekDays[] = {"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"};

   string day = weekDays[TimeDayOfWeek(time)];

   if (!long)
      day = StringSubstr(day, 0, 3);

   return(day);
}


/**
 * Alias für ErrorToStr()
 */
string ErrorDescription(int error) {
   return(ErrorToStr(error));
}


/**
 * Gibt die lesbare Beschreibung eines MQL-Fehlercodes zurück.
 *
 * @param  int error - MQL-Fehlercode
 *
 * @return string
 */
string ErrorToStr(int error) {
   switch (error) {
      case NO_ERROR                       : return("no error"                                                      ); //    0

      // trade server errors
      case ERR_NO_RESULT                  : return("no result"                                                     ); //    1
      case ERR_COMMON_ERROR               : return("common error"                                                  ); //    2
      case ERR_INVALID_TRADE_PARAMETERS   : return("invalid trade parameters"                                      ); //    3
      case ERR_SERVER_BUSY                : return("trade server is busy"                                          ); //    4
      case ERR_OLD_VERSION                : return("old version of client terminal"                                ); //    5
      case ERR_NO_CONNECTION              : return("no connection to trade server"                                 ); //    6
      case ERR_NOT_ENOUGH_RIGHTS          : return("not enough rights"                                             ); //    7
      case ERR_TOO_FREQUENT_REQUESTS      : return("too frequent requests"                                         ); //    8
      case ERR_MALFUNCTIONAL_TRADE        : return("malfunctional trade operation (never returned error)"          ); //    9
      case ERR_ACCOUNT_DISABLED           : return("account disabled"                                              ); //   64
      case ERR_INVALID_ACCOUNT            : return("invalid account"                                               ); //   65
      case ERR_TRADE_TIMEOUT              : return("trade timeout"                                                 ); //  128
      case ERR_INVALID_PRICE              : return("invalid price"                                                 ); //  129
      case ERR_INVALID_STOPS              : return("invalid stop"                                                  ); //  130
      case ERR_INVALID_TRADE_VOLUME       : return("invalid trade volume"                                          ); //  131
      case ERR_MARKET_CLOSED              : return("market is closed"                                              ); //  132
      case ERR_TRADE_DISABLED             : return("trading is disabled"                                           ); //  133
      case ERR_NOT_ENOUGH_MONEY           : return("not enough money"                                              ); //  134
      case ERR_PRICE_CHANGED              : return("price changed"                                                 ); //  135
      case ERR_OFF_QUOTES                 : return("off quotes"                                                    ); //  136
      case ERR_BROKER_BUSY                : return("broker is busy (never returned error)"                         ); //  137
      case ERR_REQUOTE                    : return("requote"                                                       ); //  138
      case ERR_ORDER_LOCKED               : return("order is locked"                                               ); //  139
      case ERR_LONG_POSITIONS_ONLY_ALLOWED: return("long positions only allowed"                                   ); //  140
      case ERR_TOO_MANY_REQUESTS          : return("too many requests"                                             ); //  141
      case ERR_TRADE_MODIFY_DENIED        : return("modification denied because too close to market"               ); //  145
      case ERR_TRADE_CONTEXT_BUSY         : return("trade context is busy"                                         ); //  146
      case ERR_TRADE_EXPIRATION_DENIED    : return("expiration settings denied by broker"                          ); //  147
      case ERR_TRADE_TOO_MANY_ORDERS      : return("number of open and pending orders has reached the broker limit"); //  148
      case ERR_TRADE_HEDGE_PROHIBITED     : return("hedging prohibited"                                            ); //  149
      case ERR_TRADE_PROHIBITED_BY_FIFO   : return("prohibited by FIFO rules"                                      ); //  150

      // runtime errors
      case ERR_RUNTIME_ERROR              : return("runtime error"                                                 ); // 4000       common runtime error (no mql error)
      case ERR_WRONG_FUNCTION_POINTER     : return("wrong function pointer"                                        ); // 4001
      case ERR_ARRAY_INDEX_OUT_OF_RANGE   : return("array index out of range"                                      ); // 4002
      case ERR_NO_MEMORY_FOR_CALL_STACK   : return("no memory for function call stack"                             ); // 4003
      case ERR_RECURSIVE_STACK_OVERFLOW   : return("recursive stack overflow"                                      ); // 4004
      case ERR_NOT_ENOUGH_STACK_FOR_PARAM : return("not enough stack for parameter"                                ); // 4005
      case ERR_NO_MEMORY_FOR_PARAM_STRING : return("no memory for parameter string"                                ); // 4006
      case ERR_NO_MEMORY_FOR_TEMP_STRING  : return("no memory for temp string"                                     ); // 4007
      case ERR_NOT_INITIALIZED_STRING     : return("not initialized string"                                        ); // 4008
      case ERR_NOT_INITIALIZED_ARRAYSTRING: return("not initialized string in array"                               ); // 4009
      case ERR_NO_MEMORY_FOR_ARRAYSTRING  : return("no memory for string in array"                                 ); // 4010
      case ERR_TOO_LONG_STRING            : return("string too long"                                               ); // 4011
      case ERR_REMAINDER_FROM_ZERO_DIVIDE : return("remainder from division by zero"                               ); // 4012
      case ERR_ZERO_DIVIDE                : return("division by zero"                                              ); // 4013
      case ERR_UNKNOWN_COMMAND            : return("unknown command"                                               ); // 4014
      case ERR_WRONG_JUMP                 : return("wrong jump (never generated error)"                            ); // 4015
      case ERR_NOT_INITIALIZED_ARRAY      : return("array not initialized"                                         ); // 4016
      case ERR_DLL_CALLS_NOT_ALLOWED      : return("DLL calls are not allowed"                                     ); // 4017
      case ERR_CANNOT_LOAD_LIBRARY        : return("cannot load library"                                           ); // 4018
      case ERR_CANNOT_CALL_FUNCTION       : return("cannot call function"                                          ); // 4019
      case ERR_EXTERNAL_CALLS_NOT_ALLOWED : return("expert function calls are not allowed"                         ); // 4020
      case ERR_NO_MEMORY_FOR_RETURNED_STR : return("not enough memory for temp string returned from function"      ); // 4021
      case ERR_SYSTEM_BUSY                : return("system busy (never generated error)"                           ); // 4022
      case ERR_INVALID_FUNCTION_PARAMSCNT : return("invalid function parameter count"                              ); // 4050       invalid parameters count
      case ERR_INVALID_FUNCTION_PARAMVALUE: return("invalid function parameter value"                              ); // 4051       invalid parameter value
      case ERR_STRING_FUNCTION_INTERNAL   : return("string function internal error"                                ); // 4052
      case ERR_SOME_ARRAY_ERROR           : return("array error"                                                   ); // 4053       some array error
      case ERR_INCORRECT_SERIESARRAY_USING: return("incorrect series array using"                                  ); // 4054
      case ERR_CUSTOM_INDICATOR_ERROR     : return("custom indicator error"                                        ); // 4055       custom indicator error
      case ERR_INCOMPATIBLE_ARRAYS        : return("incompatible arrays"                                           ); // 4056       incompatible arrays
      case ERR_GLOBAL_VARIABLES_PROCESSING: return("global variables processing error"                             ); // 4057
      case ERR_GLOBAL_VARIABLE_NOT_FOUND  : return("global variable not found"                                     ); // 4058
      case ERR_FUNC_NOT_ALLOWED_IN_TESTING: return("function not allowed in test mode"                             ); // 4059
      case ERR_FUNCTION_NOT_CONFIRMED     : return("function not confirmed"                                        ); // 4060
      case ERR_SEND_MAIL_ERROR            : return("send mail error"                                               ); // 4061
      case ERR_STRING_PARAMETER_EXPECTED  : return("string parameter expected"                                     ); // 4062
      case ERR_INTEGER_PARAMETER_EXPECTED : return("integer parameter expected"                                    ); // 4063
      case ERR_DOUBLE_PARAMETER_EXPECTED  : return("double parameter expected"                                     ); // 4064
      case ERR_ARRAY_AS_PARAMETER_EXPECTED: return("array parameter expected"                                      ); // 4065
      case ERR_HISTORY_UPDATE             : return("requested history data in update state"                        ); // 4066       history in update state
      case ERR_TRADE_ERROR                : return("error in trading function"                                     ); // 4067       error in trading function
      case ERR_END_OF_FILE                : return("end of file"                                                   ); // 4099       end of file
      case ERR_SOME_FILE_ERROR            : return("file error"                                                    ); // 4100       some file error
      case ERR_WRONG_FILE_NAME            : return("wrong file name"                                               ); // 4101
      case ERR_TOO_MANY_OPENED_FILES      : return("too many opened files"                                         ); // 4102
      case ERR_CANNOT_OPEN_FILE           : return("cannot open file"                                              ); // 4103
      case ERR_INCOMPATIBLE_FILEACCESS    : return("incompatible file access"                                      ); // 4104
      case ERR_NO_ORDER_SELECTED          : return("no order selected"                                             ); // 4105
      case ERR_UNKNOWN_SYMBOL             : return("unknown symbol"                                                ); // 4106
      case ERR_INVALID_PRICE_PARAM        : return("invalid price parameter for trade function"                    ); // 4107
      case ERR_INVALID_TICKET             : return("invalid ticket"                                                ); // 4108
      case ERR_TRADE_NOT_ALLOWED          : return("live trading is not enabled"                                   ); // 4109
      case ERR_LONGS_NOT_ALLOWED          : return("long trades are not enabled"                                   ); // 4110
      case ERR_SHORTS_NOT_ALLOWED         : return("short trades are not enabled"                                  ); // 4111
      case ERR_OBJECT_ALREADY_EXISTS      : return("object already exists"                                         ); // 4200
      case ERR_UNKNOWN_OBJECT_PROPERTY    : return("unknown object property"                                       ); // 4201
      case ERR_OBJECT_DOES_NOT_EXIST      : return("object doesn\'t exist"                                         ); // 4202
      case ERR_UNKNOWN_OBJECT_TYPE        : return("unknown object type"                                           ); // 4203
      case ERR_NO_OBJECT_NAME             : return("no object name"                                                ); // 4204
      case ERR_OBJECT_COORDINATES_ERROR   : return("object coordinates error"                                      ); // 4205
      case ERR_NO_SPECIFIED_SUBWINDOW     : return("no specified subwindow"                                        ); // 4206
      case ERR_SOME_OBJECT_ERROR          : return("object error"                                                  ); // 4207

      // custom errors
      case ERR_WINDOWS_ERROR              : return("Windows error"                                                 ); // 5000       Windows error
      case ERR_FUNCTION_NOT_IMPLEMENTED   : return("function not implemented"                                      ); // 5001       function not implemented
      case ERR_INVALID_INPUT_PARAMVALUE   : return("invalid input parameter value"                                 ); // 5002       invalid input parameter value
      case ERR_TERMINAL_NOT_YET_READY     : return("terminal not yet ready"                                        ); // 5003       terminal not yet ready
   }
   return("unknown error");
}


/**
 * Gibt die lesbare Fehlerkonstante eines MQL-Fehlercodes zurück.
 *
 * @param  int error - MQL-Fehlercode
 *
 * @return string
 */
string ErrorID(int error) {
   switch (error) {
      case NO_ERROR                       : return("NO_ERROR"                       ); //    0

      // trade server errors
      case ERR_NO_RESULT                  : return("ERR_NO_RESULT"                  ); //    1
      case ERR_COMMON_ERROR               : return("ERR_COMMON_ERROR"               ); //    2
      case ERR_INVALID_TRADE_PARAMETERS   : return("ERR_INVALID_TRADE_PARAMETERS"   ); //    3
      case ERR_SERVER_BUSY                : return("ERR_SERVER_BUSY"                ); //    4
      case ERR_OLD_VERSION                : return("ERR_OLD_VERSION"                ); //    5
      case ERR_NO_CONNECTION              : return("ERR_NO_CONNECTION"              ); //    6
      case ERR_NOT_ENOUGH_RIGHTS          : return("ERR_NOT_ENOUGH_RIGHTS"          ); //    7
      case ERR_TOO_FREQUENT_REQUESTS      : return("ERR_TOO_FREQUENT_REQUESTS"      ); //    8
      case ERR_MALFUNCTIONAL_TRADE        : return("ERR_MALFUNCTIONAL_TRADE"        ); //    9
      case ERR_ACCOUNT_DISABLED           : return("ERR_ACCOUNT_DISABLED"           ); //   64
      case ERR_INVALID_ACCOUNT            : return("ERR_INVALID_ACCOUNT"            ); //   65
      case ERR_TRADE_TIMEOUT              : return("ERR_TRADE_TIMEOUT"              ); //  128
      case ERR_INVALID_PRICE              : return("ERR_INVALID_PRICE"              ); //  129
      case ERR_INVALID_STOPS              : return("ERR_INVALID_STOPS"              ); //  130
      case ERR_INVALID_TRADE_VOLUME       : return("ERR_INVALID_TRADE_VOLUME"       ); //  131
      case ERR_MARKET_CLOSED              : return("ERR_MARKET_CLOSED"              ); //  132
      case ERR_TRADE_DISABLED             : return("ERR_TRADE_DISABLED"             ); //  133
      case ERR_NOT_ENOUGH_MONEY           : return("ERR_NOT_ENOUGH_MONEY"           ); //  134
      case ERR_PRICE_CHANGED              : return("ERR_PRICE_CHANGED"              ); //  135
      case ERR_OFF_QUOTES                 : return("ERR_OFF_QUOTES"                 ); //  136
      case ERR_BROKER_BUSY                : return("ERR_BROKER_BUSY"                ); //  137
      case ERR_REQUOTE                    : return("ERR_REQUOTE"                    ); //  138
      case ERR_ORDER_LOCKED               : return("ERR_ORDER_LOCKED"               ); //  139
      case ERR_LONG_POSITIONS_ONLY_ALLOWED: return("ERR_LONG_POSITIONS_ONLY_ALLOWED"); //  140
      case ERR_TOO_MANY_REQUESTS          : return("ERR_TOO_MANY_REQUESTS"          ); //  141
      case ERR_TRADE_MODIFY_DENIED        : return("ERR_TRADE_MODIFY_DENIED"        ); //  145
      case ERR_TRADE_CONTEXT_BUSY         : return("ERR_TRADE_CONTEXT_BUSY"         ); //  146
      case ERR_TRADE_EXPIRATION_DENIED    : return("ERR_TRADE_EXPIRATION_DENIED"    ); //  147
      case ERR_TRADE_TOO_MANY_ORDERS      : return("ERR_TRADE_TOO_MANY_ORDERS"      ); //  148
      case ERR_TRADE_HEDGE_PROHIBITED     : return("ERR_TRADE_HEDGE_PROHIBITED"     ); //  149
      case ERR_TRADE_PROHIBITED_BY_FIFO   : return("ERR_TRADE_PROHIBITED_BY_FIFO"   ); //  150

      // runtime errors
      case ERR_RUNTIME_ERROR              : return("ERR_RUNTIME_ERROR"              ); // 4000
      case ERR_WRONG_FUNCTION_POINTER     : return("ERR_WRONG_FUNCTION_POINTER"     ); // 4001
      case ERR_ARRAY_INDEX_OUT_OF_RANGE   : return("ERR_ARRAY_INDEX_OUT_OF_RANGE"   ); // 4002
      case ERR_NO_MEMORY_FOR_CALL_STACK   : return("ERR_NO_MEMORY_FOR_CALL_STACK"   ); // 4003
      case ERR_RECURSIVE_STACK_OVERFLOW   : return("ERR_RECURSIVE_STACK_OVERFLOW"   ); // 4004
      case ERR_NOT_ENOUGH_STACK_FOR_PARAM : return("ERR_NOT_ENOUGH_STACK_FOR_PARAM" ); // 4005
      case ERR_NO_MEMORY_FOR_PARAM_STRING : return("ERR_NO_MEMORY_FOR_PARAM_STRING" ); // 4006
      case ERR_NO_MEMORY_FOR_TEMP_STRING  : return("ERR_NO_MEMORY_FOR_TEMP_STRING"  ); // 4007
      case ERR_NOT_INITIALIZED_STRING     : return("ERR_NOT_INITIALIZED_STRING"     ); // 4008
      case ERR_NOT_INITIALIZED_ARRAYSTRING: return("ERR_NOT_INITIALIZED_ARRAYSTRING"); // 4009
      case ERR_NO_MEMORY_FOR_ARRAYSTRING  : return("ERR_NO_MEMORY_FOR_ARRAYSTRING"  ); // 4010
      case ERR_TOO_LONG_STRING            : return("ERR_TOO_LONG_STRING"            ); // 4011
      case ERR_REMAINDER_FROM_ZERO_DIVIDE : return("ERR_REMAINDER_FROM_ZERO_DIVIDE" ); // 4012
      case ERR_ZERO_DIVIDE                : return("ERR_ZERO_DIVIDE"                ); // 4013
      case ERR_UNKNOWN_COMMAND            : return("ERR_UNKNOWN_COMMAND"            ); // 4014
      case ERR_WRONG_JUMP                 : return("ERR_WRONG_JUMP"                 ); // 4015
      case ERR_NOT_INITIALIZED_ARRAY      : return("ERR_NOT_INITIALIZED_ARRAY"      ); // 4016
      case ERR_DLL_CALLS_NOT_ALLOWED      : return("ERR_DLL_CALLS_NOT_ALLOWED"      ); // 4017
      case ERR_CANNOT_LOAD_LIBRARY        : return("ERR_CANNOT_LOAD_LIBRARY"        ); // 4018
      case ERR_CANNOT_CALL_FUNCTION       : return("ERR_CANNOT_CALL_FUNCTION"       ); // 4019
      case ERR_EXTERNAL_CALLS_NOT_ALLOWED : return("ERR_EXTERNAL_CALLS_NOT_ALLOWED" ); // 4020
      case ERR_NO_MEMORY_FOR_RETURNED_STR : return("ERR_NO_MEMORY_FOR_RETURNED_STR" ); // 4021
      case ERR_SYSTEM_BUSY                : return("ERR_SYSTEM_BUSY"                ); // 4022
      case ERR_INVALID_FUNCTION_PARAMSCNT : return("ERR_INVALID_FUNCTION_PARAMSCNT" ); // 4050
      case ERR_INVALID_FUNCTION_PARAMVALUE: return("ERR_INVALID_FUNCTION_PARAMVALUE"); // 4051
      case ERR_STRING_FUNCTION_INTERNAL   : return("ERR_STRING_FUNCTION_INTERNAL"   ); // 4052
      case ERR_SOME_ARRAY_ERROR           : return("ERR_SOME_ARRAY_ERROR"           ); // 4053
      case ERR_INCORRECT_SERIESARRAY_USING: return("ERR_INCORRECT_SERIESARRAY_USING"); // 4054
      case ERR_CUSTOM_INDICATOR_ERROR     : return("ERR_CUSTOM_INDICATOR_ERROR"     ); // 4055
      case ERR_INCOMPATIBLE_ARRAYS        : return("ERR_INCOMPATIBLE_ARRAYS"        ); // 4056
      case ERR_GLOBAL_VARIABLES_PROCESSING: return("ERR_GLOBAL_VARIABLES_PROCESSING"); // 4057
      case ERR_GLOBAL_VARIABLE_NOT_FOUND  : return("ERR_GLOBAL_VARIABLE_NOT_FOUND"  ); // 4058
      case ERR_FUNC_NOT_ALLOWED_IN_TESTING: return("ERR_FUNC_NOT_ALLOWED_IN_TESTING"); // 4059
      case ERR_FUNCTION_NOT_CONFIRMED     : return("ERR_FUNCTION_NOT_CONFIRMED"     ); // 4060
      case ERR_SEND_MAIL_ERROR            : return("ERR_SEND_MAIL_ERROR"            ); // 4061
      case ERR_STRING_PARAMETER_EXPECTED  : return("ERR_STRING_PARAMETER_EXPECTED"  ); // 4062
      case ERR_INTEGER_PARAMETER_EXPECTED : return("ERR_INTEGER_PARAMETER_EXPECTED" ); // 4063
      case ERR_DOUBLE_PARAMETER_EXPECTED  : return("ERR_DOUBLE_PARAMETER_EXPECTED"  ); // 4064
      case ERR_ARRAY_AS_PARAMETER_EXPECTED: return("ERR_ARRAY_AS_PARAMETER_EXPECTED"); // 4065
      case ERR_HISTORY_UPDATE             : return("ERR_HISTORY_UPDATE"             ); // 4066
      case ERR_TRADE_ERROR                : return("ERR_TRADE_ERROR"                ); // 4067
      case ERR_END_OF_FILE                : return("ERR_END_OF_FILE"                ); // 4099
      case ERR_SOME_FILE_ERROR            : return("ERR_SOME_FILE_ERROR"            ); // 4100
      case ERR_WRONG_FILE_NAME            : return("ERR_WRONG_FILE_NAME"            ); // 4101
      case ERR_TOO_MANY_OPENED_FILES      : return("ERR_TOO_MANY_OPENED_FILES"      ); // 4102
      case ERR_CANNOT_OPEN_FILE           : return("ERR_CANNOT_OPEN_FILE"           ); // 4103
      case ERR_INCOMPATIBLE_FILEACCESS    : return("ERR_INCOMPATIBLE_FILEACCESS"    ); // 4104
      case ERR_NO_ORDER_SELECTED          : return("ERR_NO_ORDER_SELECTED"          ); // 4105
      case ERR_UNKNOWN_SYMBOL             : return("ERR_UNKNOWN_SYMBOL"             ); // 4106
      case ERR_INVALID_PRICE_PARAM        : return("ERR_INVALID_PRICE_PARAM"        ); // 4107
      case ERR_INVALID_TICKET             : return("ERR_INVALID_TICKET"             ); // 4108
      case ERR_TRADE_NOT_ALLOWED          : return("ERR_TRADE_NOT_ALLOWED"          ); // 4109
      case ERR_LONGS_NOT_ALLOWED          : return("ERR_LONGS_NOT_ALLOWED"          ); // 4110
      case ERR_SHORTS_NOT_ALLOWED         : return("ERR_SHORTS_NOT_ALLOWED"         ); // 4111
      case ERR_OBJECT_ALREADY_EXISTS      : return("ERR_OBJECT_ALREADY_EXISTS"      ); // 4200
      case ERR_UNKNOWN_OBJECT_PROPERTY    : return("ERR_UNKNOWN_OBJECT_PROPERTY"    ); // 4201
      case ERR_OBJECT_DOES_NOT_EXIST      : return("ERR_OBJECT_DOES_NOT_EXIST"      ); // 4202
      case ERR_UNKNOWN_OBJECT_TYPE        : return("ERR_UNKNOWN_OBJECT_TYPE"        ); // 4203
      case ERR_NO_OBJECT_NAME             : return("ERR_NO_OBJECT_NAME"             ); // 4204
      case ERR_OBJECT_COORDINATES_ERROR   : return("ERR_OBJECT_COORDINATES_ERROR"   ); // 4205
      case ERR_NO_SPECIFIED_SUBWINDOW     : return("ERR_NO_SPECIFIED_SUBWINDOW"     ); // 4206
      case ERR_SOME_OBJECT_ERROR          : return("ERR_SOME_OBJECT_ERROR"          ); // 4207

      // custom errors
      case ERR_WINDOWS_ERROR              : return("ERR_WINDOWS_ERROR"              ); // 5000
      case ERR_FUNCTION_NOT_IMPLEMENTED   : return("ERR_FUNCTION_NOT_IMPLEMENTED"   ); // 5001
      case ERR_INVALID_INPUT_PARAMVALUE   : return("ERR_INVALID_INPUT_PARAMVALUE"   ); // 5002
      case ERR_TERMINAL_NOT_YET_READY     : return("ERR_TERMINAL_NOT_YET_READY"     ); // 5003
   }
   return(error);
}


/**
 * Gibt die lesbare Beschreibung eines ShellExecute() oder ShellExecuteEx()-Fehlercodes zurück.
 *
 * @param  int error - ShellExecute-Fehlercode
 *
 * @return string
 */
string ShellExecuteErrorToStr(int error) {
   switch (error) {
      case 0                     : return("Out of memory or resources."                        );
      case ERROR_BAD_FORMAT      : return(WindowsErrorToStr(error)                             );
      case SE_ERR_FNF            : return("File not found."                                    );
      case SE_ERR_PNF            : return("Path not found."                                    );
      case SE_ERR_ACCESSDENIED   : return("Access denied."                                     );
      case SE_ERR_OOM            : return("Out of memory."                                     );
      case SE_ERR_SHARE          : return("A sharing violation occurred."                      );
      case SE_ERR_ASSOCINCOMPLETE: return("File association information incomplete or invalid.");
      case SE_ERR_DDETIMEOUT     : return("DDE operation timed out."                           );
      case SE_ERR_DDEFAIL        : return("DDE operation failed."                              );
      case SE_ERR_DDEBUSY        : return("DDE operation is busy."                             );
      case SE_ERR_NOASSOC        : return("File association information not available."        );
      case SE_ERR_DLLNOTFOUND    : return("Dynamic-link library not found."                    );
   }
   return("unknown error");
}


/**
 * Gibt die lesbare Beschreibung eines Windows-Fehlercodes zurück.
 *
 * @param  int error - Win32-Fehlercode
 *
 * @return string
 */
string WindowsErrorToStr(int error) {
   switch (error) {
      case NO_ERROR                       : return("The operation completed successfully."                                                                                                                                         );

      // Windows Error Codes
      case ERROR_INVALID_FUNCTION         : return("Incorrect function."                                                                                                                                                           );
      case ERROR_FILE_NOT_FOUND           : return("The system cannot find the file specified."                                                                                                                                    );
      case ERROR_PATH_NOT_FOUND           : return("The system cannot find the path specified."                                                                                                                                    );
      case ERROR_TOO_MANY_OPEN_FILES      : return("The system cannot open the file."                                                                                                                                              );
      case ERROR_ACCESS_DENIED            : return("Access is denied."                                                                                                                                                             );
      case ERROR_INVALID_HANDLE           : return("The handle is invalid."                                                                                                                                                        );
      case ERROR_ARENA_TRASHED            : return("The storage control blocks were destroyed."                                                                                                                                    );
      case ERROR_NOT_ENOUGH_MEMORY        : return("Not enough storage is available to process this command."                                                                                                                      );
      case ERROR_INVALID_BLOCK            : return("The storage control block address is invalid."                                                                                                                                 );
      case ERROR_BAD_ENVIRONMENT          : return("The environment is incorrect."                                                                                                                                                 );
      case ERROR_BAD_FORMAT               : return("An attempt was made to load a program with an incorrect format."                                                                                                               );
      case ERROR_INVALID_ACCESS           : return("The access code is invalid."                                                                                                                                                   );
      case ERROR_INVALID_DATA             : return("The data is invalid."                                                                                                                                                          );
      case ERROR_OUTOFMEMORY              : return("Not enough storage is available to complete this operation."                                                                                                                   );
      case ERROR_INVALID_DRIVE            : return("The system cannot find the drive specified."                                                                                                                                   );
      case ERROR_CURRENT_DIRECTORY        : return("The directory cannot be removed."                                                                                                                                              );
      case ERROR_NOT_SAME_DEVICE          : return("The system cannot move the file to a different disk drive."                                                                                                                    );
      case ERROR_NO_MORE_FILES            : return("There are no more files."                                                                                                                                                      );
      case ERROR_WRITE_PROTECT            : return("The media is write protected."                                                                                                                                                 );
      case ERROR_BAD_UNIT                 : return("The system cannot find the device specified."                                                                                                                                  );
      case ERROR_NOT_READY                : return("The device is not ready."                                                                                                                                                      );
      case ERROR_BAD_COMMAND              : return("The device does not recognize the command."                                                                                                                                    );
      case ERROR_CRC                      : return("Data error (cyclic redundancy check)."                                                                                                                                         );
      case ERROR_BAD_LENGTH               : return("The program issued a command but the command length is incorrect."                                                                                                             );
      case ERROR_SEEK                     : return("The drive cannot locate a specific area or track on the disk."                                                                                                                 );
      case ERROR_NOT_DOS_DISK             : return("The specified disk or diskette cannot be accessed."                                                                                                                            );
      case ERROR_SECTOR_NOT_FOUND         : return("The drive cannot find the sector requested."                                                                                                                                   );
      case ERROR_OUT_OF_PAPER             : return("The printer is out of paper."                                                                                                                                                  );
      case ERROR_WRITE_FAULT              : return("The system cannot write to the specified device."                                                                                                                              );
      case ERROR_READ_FAULT               : return("The system cannot read from the specified device."                                                                                                                             );
      case ERROR_GEN_FAILURE              : return("A device attached to the system is not functioning."                                                                                                                           );
      case ERROR_SHARING_VIOLATION        : return("The process cannot access the file because it is being used by another process."                                                                                               );
      case ERROR_LOCK_VIOLATION           : return("The process cannot access the file because another process has locked a portion of the file."                                                                                  );
      case ERROR_WRONG_DISK               : return("The wrong diskette is in the drive."                                                                                                                                           );
      case ERROR_SHARING_BUFFER_EXCEEDED  : return("Too many files opened for sharing."                                                                                                                                            );
      case ERROR_HANDLE_EOF               : return("Reached the end of the file."                                                                                                                                                  );
      case ERROR_HANDLE_DISK_FULL         : return("The disk is full."                                                                                                                                                             );
      case ERROR_NOT_SUPPORTED            : return("The network request is not supported."                                                                                                                                         );
      case ERROR_REM_NOT_LIST             : return("The remote computer is not available."                                                                                                                                         );
      case ERROR_DUP_NAME                 : return("A duplicate name exists on the network."                                                                                                                                       );
      case ERROR_BAD_NETPATH              : return("The network path was not found."                                                                                                                                               );
      case ERROR_NETWORK_BUSY             : return("The network is busy."                                                                                                                                                          );
      case ERROR_DEV_NOT_EXIST            : return("The specified network resource or device is no longer available."                                                                                                              );
      case ERROR_TOO_MANY_CMDS            : return("The network BIOS command limit has been reached."                                                                                                                              );
      case ERROR_ADAP_HDW_ERR             : return("A network adapter hardware error occurred."                                                                                                                                    );
      case ERROR_BAD_NET_RESP             : return("The specified server cannot perform the requested operation."                                                                                                                  );
      case ERROR_UNEXP_NET_ERR            : return("An unexpected network error occurred."                                                                                                                                         );
      case ERROR_BAD_REM_ADAP             : return("The remote adapter is not compatible."                                                                                                                                         );
      case ERROR_PRINTQ_FULL              : return("The printer queue is full."                                                                                                                                                    );
      case ERROR_NO_SPOOL_SPACE           : return("Space to store the file waiting to be printed is not available on the server."                                                                                                 );
      case ERROR_PRINT_CANCELLED          : return("Your file waiting to be printed was deleted."                                                                                                                                  );
      case ERROR_NETNAME_DELETED          : return("The specified network name is no longer available."                                                                                                                            );
      case ERROR_NETWORK_ACCESS_DENIED    : return("Network access is denied."                                                                                                                                                     );
      case ERROR_BAD_DEV_TYPE             : return("The network resource type is not correct."                                                                                                                                     );
      case ERROR_BAD_NET_NAME             : return("The network name cannot be found."                                                                                                                                             );
      case ERROR_TOO_MANY_NAMES           : return("The name limit for the local computer network adapter card was exceeded."                                                                                                      );
      case ERROR_TOO_MANY_SESS            : return("The network BIOS session limit was exceeded."                                                                                                                                  );
      case ERROR_SHARING_PAUSED           : return("The remote server has been paused or is in the process of being started."                                                                                                      );
      case ERROR_REQ_NOT_ACCEP            : return("No more connections can be made to this remote computer at this time because there are already as many connections as the computer can accept."                                );
      case ERROR_REDIR_PAUSED             : return("The specified printer or disk device has been paused."                                                                                                                         );
      case ERROR_FILE_EXISTS              : return("The file exists."                                                                                                                                                              );
      case ERROR_CANNOT_MAKE              : return("The directory or file cannot be created."                                                                                                                                      );
      case ERROR_FAIL_I24                 : return("Fail on INT 24."                                                                                                                                                               );
      case ERROR_OUT_OF_STRUCTURES        : return("Storage to process this request is not available."                                                                                                                             );
      case ERROR_ALREADY_ASSIGNED         : return("The local device name is already in use."                                                                                                                                      );
      case ERROR_INVALID_PASSWORD         : return("The specified network password is not correct."                                                                                                                                );
      case ERROR_INVALID_PARAMETER        : return("The parameter is incorrect."                                                                                                                                                   );
      case ERROR_NET_WRITE_FAULT          : return("A write fault occurred on the network."                                                                                                                                        );
      case ERROR_NO_PROC_SLOTS            : return("The system cannot start another process at this time."                                                                                                                         );
      case ERROR_TOO_MANY_SEMAPHORES      : return("Cannot create another system semaphore."                                                                                                                                       );
      case ERROR_EXCL_SEM_ALREADY_OWNED   : return("The exclusive semaphore is owned by another process."                                                                                                                          );
      case ERROR_SEM_IS_SET               : return("The semaphore is set and cannot be closed."                                                                                                                                    );
      case ERROR_TOO_MANY_SEM_REQUESTS    : return("The semaphore cannot be set again."                                                                                                                                            );
      case ERROR_INVALID_AT_INTERRUPT_TIME: return("Cannot request exclusive semaphores at interrupt time."                                                                                                                        );
      case ERROR_SEM_OWNER_DIED           : return("The previous ownership of this semaphore has ended."                                                                                                                           );
      case ERROR_SEM_USER_LIMIT           : return("Insert the diskette for drive %1."                                                                                                                                             );
      case ERROR_DISK_CHANGE              : return("The program stopped because an alternate diskette was not inserted."                                                                                                           );
      case ERROR_DRIVE_LOCKED             : return("The disk is in use or locked by another process."                                                                                                                              );
      case ERROR_BROKEN_PIPE              : return("The pipe has been ended."                                                                                                                                                      );
      case ERROR_OPEN_FAILED              : return("The system cannot open the device or file specified."                                                                                                                          );
      case ERROR_BUFFER_OVERFLOW          : return("The file name is too long."                                                                                                                                                    );
      case ERROR_DISK_FULL                : return("There is not enough space on the disk."                                                                                                                                        );
      case ERROR_NO_MORE_SEARCH_HANDLES   : return("No more internal file identifiers available."                                                                                                                                  );
      case ERROR_INVALID_TARGET_HANDLE    : return("The target internal file identifier is incorrect."                                                                                                                             );
      case ERROR_INVALID_CATEGORY         : return("The IOCTL call made by the application program is not correct."                                                                                                                );
      case ERROR_INVALID_VERIFY_SWITCH    : return("The verify-on-write switch parameter value is not correct."                                                                                                                    );
      case ERROR_BAD_DRIVER_LEVEL         : return("The system does not support the command requested."                                                                                                                            );
      case ERROR_CALL_NOT_IMPLEMENTED     : return("This function is not supported on this system."                                                                                                                                );
      case ERROR_SEM_TIMEOUT              : return("The semaphore timeout period has expired."                                                                                                                                     );
      case ERROR_INSUFFICIENT_BUFFER      : return("The data area passed to a system call is too small."                                                                                                                           );
      case ERROR_INVALID_NAME             : return("The filename, directory name, or volume label syntax is incorrect."                                                                                                            );
      case ERROR_INVALID_LEVEL            : return("The system call level is not correct."                                                                                                                                         );
      case ERROR_NO_VOLUME_LABEL          : return("The disk has no volume label."                                                                                                                                                 );
      case ERROR_MOD_NOT_FOUND            : return("The specified module could not be found."                                                                                                                                      );
      case ERROR_PROC_NOT_FOUND           : return("The specified procedure could not be found."                                                                                                                                   );
      case ERROR_WAIT_NO_CHILDREN         : return("There are no child processes to wait for."                                                                                                                                     );
      case ERROR_CHILD_NOT_COMPLETE       : return("The %1 application cannot be run in Win32 mode."                                                                                                                               );
      case ERROR_DIRECT_ACCESS_HANDLE     : return("Attempt to use a file handle to an open disk partition for an operation other than raw disk I/O."                                                                              );
      case ERROR_NEGATIVE_SEEK            : return("An attempt was made to move the file pointer before the beginning of the file."                                                                                                );
      case ERROR_SEEK_ON_DEVICE           : return("The file pointer cannot be set on the specified device or file."                                                                                                               );
      case ERROR_IS_JOIN_TARGET           : return("A JOIN or SUBST command cannot be used for a drive that contains previously joined drives."                                                                                    );
      case ERROR_IS_JOINED                : return("An attempt was made to use a JOIN or SUBST command on a drive that has already been joined."                                                                                   );
      case ERROR_IS_SUBSTED               : return("An attempt was made to use a JOIN or SUBST command on a drive that has already been substituted."                                                                              );
      case ERROR_NOT_JOINED               : return("The system tried to delete the JOIN of a drive that is not joined."                                                                                                            );
      case ERROR_NOT_SUBSTED              : return("The system tried to delete the substitution of a drive that is not substituted."                                                                                               );
      case ERROR_JOIN_TO_JOIN             : return("The system tried to join a drive to a directory on a joined drive."                                                                                                            );
      case ERROR_SUBST_TO_SUBST           : return("The system tried to substitute a drive to a directory on a substituted drive."                                                                                                 );
      case ERROR_JOIN_TO_SUBST            : return("The system tried to join a drive to a directory on a substituted drive."                                                                                                       );
      case ERROR_SUBST_TO_JOIN            : return("The system tried to SUBST a drive to a directory on a joined drive."                                                                                                           );
      case ERROR_BUSY_DRIVE               : return("The system cannot perform a JOIN or SUBST at this time."                                                                                                                       );
      case ERROR_SAME_DRIVE               : return("The system cannot join or substitute a drive to or for a directory on the same drive."                                                                                         );
      case ERROR_DIR_NOT_ROOT             : return("The directory is not a subdirectory of the root directory."                                                                                                                    );
      case ERROR_DIR_NOT_EMPTY            : return("The directory is not empty."                                                                                                                                                   );
      case ERROR_IS_SUBST_PATH            : return("The path specified is being used in a substitute."                                                                                                                             );
      case ERROR_IS_JOIN_PATH             : return("Not enough resources are available to process this command."                                                                                                                   );
      case ERROR_PATH_BUSY                : return("The path specified cannot be used at this time."                                                                                                                               );
      case ERROR_IS_SUBST_TARGET          : return("An attempt was made to join or substitute a drive for which a directory on the drive is the target of a previous substitute."                                                  );
      case ERROR_SYSTEM_TRACE             : return("System trace information was not specified in your CONFIG.SYS file, or tracing is disallowed."                                                                                 );
      case ERROR_INVALID_EVENT_COUNT      : return("The number of specified semaphore events for DosMuxSemWait is not correct."                                                                                                    );
      case ERROR_TOO_MANY_MUXWAITERS      : return("DosMuxSemWait did not execute; too many semaphores are already set."                                                                                                           );
      case ERROR_INVALID_LIST_FORMAT      : return("The DosMuxSemWait list is not correct."                                                                                                                                        );
      case ERROR_LABEL_TOO_LONG           : return("The volume label you entered exceeds the label character limit of the target file system."                                                                                     );
      case ERROR_TOO_MANY_TCBS            : return("Cannot create another thread."                                                                                                                                                 );
      case ERROR_SIGNAL_REFUSED           : return("The recipient process has refused the signal."                                                                                                                                 );
      case ERROR_DISCARDED                : return("The segment is already discarded and cannot be locked."                                                                                                                        );
      case ERROR_NOT_LOCKED               : return("The segment is already unlocked."                                                                                                                                              );
      case ERROR_BAD_THREADID_ADDR        : return("The address for the thread ID is not correct."                                                                                                                                 );
      case ERROR_BAD_ARGUMENTS            : return("The argument string passed to DosExecPgm is not correct."                                                                                                                      );
      case ERROR_BAD_PATHNAME             : return("The specified path is invalid."                                                                                                                                                );
      case ERROR_SIGNAL_PENDING           : return("A signal is already pending."                                                                                                                                                  );
      case ERROR_MAX_THRDS_REACHED        : return("No more threads can be created in the system."                                                                                                                                 );
      case ERROR_LOCK_FAILED              : return("Unable to lock a region of a file."                                                                                                                                            );
      case ERROR_BUSY                     : return("The requested resource is in use."                                                                                                                                             );
      case ERROR_CANCEL_VIOLATION         : return("A lock request was not outstanding for the supplied cancel region."                                                                                                            );
      case 174                            : return("The file system does not support atomic changes to the lock type."                                                                                                             );
      case ERROR_INVALID_SEGMENT_NUMBER   : return("The system detected a segment number that was not correct."                                                                                                                    );
      case ERROR_INVALID_ORDINAL          : return("The operating system cannot run %1."                                                                                                                                           );
      case ERROR_ALREADY_EXISTS           : return("Cannot create a file when that file already exists."                                                                                                                           );
      case ERROR_INVALID_FLAG_NUMBER      : return("The flag passed is not correct."                                                                                                                                               );
      case ERROR_SEM_NOT_FOUND            : return("The specified system semaphore name was not found."                                                                                                                            );
      case ERROR_INVALID_STARTING_CODESEG : return("The operating system cannot run %1."                                                                                                                                           );
      case ERROR_INVALID_STACKSEG         : return("The operating system cannot run %1."                                                                                                                                           );
      case ERROR_INVALID_MODULETYPE       : return("The operating system cannot run %1."                                                                                                                                           );
      case ERROR_INVALID_EXE_SIGNATURE    : return("Cannot run %1 in Win32 mode."                                                                                                                                                  );
      case ERROR_EXE_MARKED_INVALID       : return("The operating system cannot run %1."                                                                                                                                           );
      case ERROR_BAD_EXE_FORMAT           : return("%1 is not a valid Win32 application."                                                                                                                                          );
      case ERROR_ITERATED_DATA_EXCEEDS_64k: return("The operating system cannot run %1."                                                                                                                                           );
      case ERROR_INVALID_MINALLOCSIZE     : return("The operating system cannot run %1."                                                                                                                                           );
      case ERROR_DYNLINK_FROM_INVALID_RING: return("The operating system cannot run this application program."                                                                                                                     );
      case ERROR_IOPL_NOT_ENABLED         : return("The operating system is not presently configured to run this application."                                                                                                     );
      case ERROR_INVALID_SEGDPL           : return("The operating system cannot run %1."                                                                                                                                           );
      case ERROR_AUTODATASEG_EXCEEDS_64k  : return("The operating system cannot run this application program."                                                                                                                     );
      case ERROR_RING2SEG_MUST_BE_MOVABLE : return("The code segment cannot be greater than or equal to 64K."                                                                                                                      );
      case ERROR_RELOC_CHAIN_XEEDS_SEGLIM : return("The operating system cannot run %1."                                                                                                                                           );
      case ERROR_INFLOOP_IN_RELOC_CHAIN   : return("The operating system cannot run %1."                                                                                                                                           );
      case ERROR_ENVVAR_NOT_FOUND         : return("The system could not find the environment option that was entered."                                                                                                            );
      case ERROR_NO_SIGNAL_SENT           : return("No process in the command subtree has a signal handler."                                                                                                                       );
      case ERROR_FILENAME_EXCED_RANGE     : return("The filename or extension is too long."                                                                                                                                        );
      case ERROR_RING2_STACK_IN_USE       : return("The ring 2 stack is in use."                                                                                                                                                   );
      case ERROR_META_EXPANSION_TOO_LONG  : return("The global filename characters, * or ?, are entered incorrectly or too many global filename characters are specified."                                                         );
      case ERROR_INVALID_SIGNAL_NUMBER    : return("The signal being posted is not correct."                                                                                                                                       );
      case ERROR_THREAD_1_INACTIVE        : return("The signal handler cannot be set."                                                                                                                                             );
      case ERROR_LOCKED                   : return("The segment is locked and cannot be reallocated."                                                                                                                              );
      case ERROR_TOO_MANY_MODULES         : return("Too many dynamic-link modules are attached to this program or dynamic-link module."                                                                                            );
      case ERROR_NESTING_NOT_ALLOWED      : return("Can't nest calls to LoadModule."                                                                                                                                               );
      case ERROR_EXE_MACHINE_TYPE_MISMATCH: return("The image file %1 is valid, but is for a machine type other than the current machine."                                                                                         );
      case ERROR_BAD_PIPE                 : return("The pipe state is invalid."                                                                                                                                                    );
      case ERROR_PIPE_BUSY                : return("All pipe instances are busy."                                                                                                                                                  );
      case ERROR_NO_DATA                  : return("The pipe is being closed."                                                                                                                                                     );
      case ERROR_PIPE_NOT_CONNECTED       : return("No process is on the other end of the pipe."                                                                                                                                   );
      case ERROR_MORE_DATA                : return("More data is available."                                                                                                                                                       );
      case ERROR_VC_DISCONNECTED          : return("The session was canceled."                                                                                                                                                     );
      case ERROR_INVALID_EA_NAME          : return("The specified extended attribute name was invalid."                                                                                                                            );
      case ERROR_EA_LIST_INCONSISTENT     : return("The extended attributes are inconsistent."                                                                                                                                     );
      case ERROR_NO_MORE_ITEMS            : return("No more data is available."                                                                                                                                                    );
      case ERROR_CANNOT_COPY              : return("The copy functions cannot be used."                                                                                                                                            );
      case ERROR_DIRECTORY                : return("The directory name is invalid."                                                                                                                                                );
      case ERROR_EAS_DIDNT_FIT            : return("The extended attributes did not fit in the buffer."                                                                                                                            );
      case ERROR_EA_FILE_CORRUPT          : return("The extended attribute file on the mounted file system is corrupt."                                                                                                            );
      case ERROR_EA_TABLE_FULL            : return("The extended attribute table file is full."                                                                                                                                    );
      case ERROR_INVALID_EA_HANDLE        : return("The specified extended attribute handle is invalid."                                                                                                                           );
      case ERROR_EAS_NOT_SUPPORTED        : return("The mounted file system does not support extended attributes."                                                                                                                 );
      case ERROR_NOT_OWNER                : return("Attempt to release mutex not owned by caller."                                                                                                                                 );
      case ERROR_TOO_MANY_POSTS           : return("Too many posts were made to a semaphore."                                                                                                                                      );
      case ERROR_PARTIAL_COPY             : return("Only part of a ReadProcessMemoty or WriteProcessMemory request was completed."                                                                                                 );
      case ERROR_OPLOCK_NOT_GRANTED       : return("The oplock request is denied."                                                                                                                                                 );
      case ERROR_INVALID_OPLOCK_PROTOCOL  : return("An invalid oplock acknowledgment was received by the system."                                                                                                                  );
      case ERROR_MR_MID_NOT_FOUND         : return("The system cannot find message text for message number 0x%1 in the message file for %2."                                                                                       );
      case ERROR_INVALID_ADDRESS          : return("Attempt to access invalid address."                                                                                                                                            );
      case ERROR_ARITHMETIC_OVERFLOW      : return("Arithmetic result exceeded 32 bits."                                                                                                                                           );
      case ERROR_PIPE_CONNECTED           : return("There is a process on other end of the pipe."                                                                                                                                  );
      case ERROR_PIPE_LISTENING           : return("Waiting for a process to open the other end of the pipe."                                                                                                                      );
      case ERROR_EA_ACCESS_DENIED         : return("Access to the extended attribute was denied."                                                                                                                                  );
      case ERROR_OPERATION_ABORTED        : return("The I/O operation has been aborted because of either a thread exit or an application request."                                                                                 );
      case ERROR_IO_INCOMPLETE            : return("Overlapped I/O event is not in a signaled state."                                                                                                                              );
      case ERROR_IO_PENDING               : return("Overlapped I/O operation is in progress."                                                                                                                                      );
      case ERROR_NOACCESS                 : return("Invalid access to memory location."                                                                                                                                            );
      case ERROR_SWAPERROR                : return("Error performing inpage operation."                                                                                                                                            );
      case ERROR_STACK_OVERFLOW           : return("Recursion too deep; the stack overflowed."                                                                                                                                     );
      case ERROR_INVALID_MESSAGE          : return("The window cannot act on the sent message."                                                                                                                                    );
      case ERROR_CAN_NOT_COMPLETE         : return("Cannot complete this function."                                                                                                                                                );
      case ERROR_INVALID_FLAGS            : return("Invalid flags."                                                                                                                                                                );
      case ERROR_UNRECOGNIZED_VOLUME      : return("The volume does not contain a recognized file system."                                                                                                                         );
      case ERROR_FILE_INVALID             : return("The volume for a file has been externally altered so that the opened file is no longer valid."                                                                                 );
      case ERROR_FULLSCREEN_MODE          : return("The requested operation cannot be performed in full-screen mode."                                                                                                              );
      case ERROR_NO_TOKEN                 : return("An attempt was made to reference a token that does not exist."                                                                                                                 );
      case ERROR_BADDB                    : return("The configuration registry database is corrupt."                                                                                                                               );
      case ERROR_BADKEY                   : return("The configuration registry key is invalid."                                                                                                                                    );
      case ERROR_CANTOPEN                 : return("The configuration registry key could not be opened."                                                                                                                           );
      case ERROR_CANTREAD                 : return("The configuration registry key could not be read."                                                                                                                             );
      case ERROR_CANTWRITE                : return("The configuration registry key could not be written."                                                                                                                          );
      case ERROR_REGISTRY_RECOVERED       : return("One of the files in the registry database had to be recovered by use of a log or alternate copy.  The recovery was successful."                                                );
      case ERROR_REGISTRY_CORRUPT         : return("The registry is corrupted."                                                                                                                                                    );
      case ERROR_REGISTRY_IO_FAILED       : return("An I/O operation initiated by the registry failed unrecoverably."                                                                                                              );
      case ERROR_NOT_REGISTRY_FILE        : return("The system has attempted to load or restore a file into the registry, but the specified file is not in a registry file format."                                                );
      case ERROR_KEY_DELETED              : return("Illegal operation attempted on a registry key that has been marked for deletion."                                                                                              );
      case ERROR_NO_LOG_SPACE             : return("System could not allocate the required space in a registry log."                                                                                                               );
      case ERROR_KEY_HAS_CHILDREN         : return("Cannot create a symbolic link in a registry key that already has subkeys or values."                                                                                           );
      case ERROR_CHILD_MUST_BE_VOLATILE   : return("Cannot create a stable subkey under a volatile parent key."                                                                                                                    );
      case ERROR_NOTIFY_ENUM_DIR          : return("A notify change request is being completed and the information is not being returned in the caller's buffer.  The caller now needs to enumerate the files to find the changes.");
      case 1051                           : return("A stop control has been sent to a service that other running services are dependent on."                                                                                       );
      case ERROR_INVALID_SERVICE_CONTROL  : return("The requested control is not valid for this service."                                                                                                                          );
      case ERROR_SERVICE_REQUEST_TIMEOUT  : return("The service did not respond to the start or control request in a timely fashion."                                                                                              );
      case ERROR_SERVICE_NO_THREAD        : return("A thread could not be created for the service."                                                                                                                                );
      case ERROR_SERVICE_DATABASE_LOCKED  : return("The service database is locked."                                                                                                                                               );
      case ERROR_SERVICE_ALREADY_RUNNING  : return("An instance of the service is already running."                                                                                                                                );
      case ERROR_INVALID_SERVICE_ACCOUNT  : return("The account name is invalid or does not exist."                                                                                                                                );
      case ERROR_SERVICE_DISABLED         : return("The service cannot be started, either because it is disabled or because it has no enabled devices associated with it."                                                         );
      case ERROR_CIRCULAR_DEPENDENCY      : return("Circular service dependency was specified."                                                                                                                                    );
      case ERROR_SERVICE_DOES_NOT_EXIST   : return("The specified service does not exist as an installed service."                                                                                                                 );
      case 1061                           : return("The service cannot accept control messages at this time."                                                                                                                      );
      case ERROR_SERVICE_NOT_ACTIVE       : return("The service has not been started."                                                                                                                                             );
      case 1063                           : return("The service process could not connect to the service controller."                                                                                                              );
      case ERROR_EXCEPTION_IN_SERVICE     : return("An exception occurred in the service when handling the control request."                                                                                                       );
      case ERROR_DATABASE_DOES_NOT_EXIST  : return("The database specified does not exist."                                                                                                                                        );
      case ERROR_SERVICE_SPECIFIC_ERROR   : return("The service has returned a service-specific error code."                                                                                                                       );
      case ERROR_PROCESS_ABORTED          : return("The process terminated unexpectedly."                                                                                                                                          );
      case ERROR_SERVICE_DEPENDENCY_FAIL  : return("The dependency service or group failed to start."                                                                                                                              );
      case ERROR_SERVICE_LOGON_FAILED     : return("The service did not start due to a logon failure."                                                                                                                             );
      case ERROR_SERVICE_START_HANG       : return("After starting, the service hung in a start-pending state."                                                                                                                    );
      case ERROR_INVALID_SERVICE_LOCK     : return("The specified service database lock is invalid."                                                                                                                               );
      case ERROR_SERVICE_MARKED_FOR_DELETE: return("The specified service has been marked for deletion."                                                                                                                           );
      case ERROR_SERVICE_EXISTS           : return("The specified service already exists."                                                                                                                                         );
      case ERROR_ALREADY_RUNNING_LKG      : return("The system is currently running with the last-known-good configuration."                                                                                                       );
      case 1075                           : return("The dependency service does not exist or has been marked for deletion."                                                                                                        );
      case ERROR_BOOT_ALREADY_ACCEPTED    : return("The current boot has already been accepted for use as the last-known-good control set."                                                                                        );
      case ERROR_SERVICE_NEVER_STARTED    : return("No attempts to start the service have been made since the last boot."                                                                                                          );
      case ERROR_DUPLICATE_SERVICE_NAME   : return("The name is already in use as either a service name or a service display name."                                                                                                );
      case ERROR_DIFFERENT_SERVICE_ACCOUNT: return("The account specified for this service is different from the account specified for other services running in the same process."                                                );
      case 1080                           : return("Failure actions can only be set for Win32 services, not for drivers."                                                                                                          );
      case 1081                           : return("This service runs in the same process as the service control manager."                                                                                                         );
      case ERROR_NO_RECOVERY_PROGRAM      : return("No recovery program has been configured for this service."                                                                                                                     );
      case ERROR_END_OF_MEDIA             : return("The physical end of the tape has been reached."                                                                                                                                );
      case ERROR_FILEMARK_DETECTED        : return("A tape access reached a filemark."                                                                                                                                             );
      case ERROR_BEGINNING_OF_MEDIA       : return("The beginning of the tape or a partition was encountered."                                                                                                                     );
      case ERROR_SETMARK_DETECTED         : return("A tape access reached the end of a set of files."                                                                                                                              );
      case ERROR_NO_DATA_DETECTED         : return("No more data is on the tape."                                                                                                                                                  );
      case ERROR_PARTITION_FAILURE        : return("Tape could not be partitioned."                                                                                                                                                );
      case ERROR_INVALID_BLOCK_LENGTH     : return("When accessing a new tape of a multivolume partition, the current blocksize is incorrect."                                                                                     );
      case ERROR_DEVICE_NOT_PARTITIONED   : return("Tape partition information could not be found when loading a tape."                                                                                                            );
      case ERROR_UNABLE_TO_LOCK_MEDIA     : return("Unable to lock the media eject mechanism."                                                                                                                                     );
      case ERROR_UNABLE_TO_UNLOAD_MEDIA   : return("Unable to unload the media."                                                                                                                                                   );
      case ERROR_MEDIA_CHANGED            : return("The media in the drive may have changed."                                                                                                                                      );
      case ERROR_BUS_RESET                : return("The I/O bus was reset."                                                                                                                                                        );
      case ERROR_NO_MEDIA_IN_DRIVE        : return("No media in drive."                                                                                                                                                            );
      case ERROR_NO_UNICODE_TRANSLATION   : return("No mapping for the Unicode character exists in the target multi-byte code page."                                                                                               );
      case ERROR_DLL_INIT_FAILED          : return("A DLL initialization routine failed."                                                                                                                                          );
      case ERROR_SHUTDOWN_IN_PROGRESS     : return("A system shutdown is in progress."                                                                                                                                             );
      case ERROR_NO_SHUTDOWN_IN_PROGRESS  : return("Unable to abort the system shutdown because no shutdown was in progress."                                                                                                      );
      case ERROR_IO_DEVICE                : return("The request could not be performed because of an I/O device error."                                                                                                            );
      case ERROR_SERIAL_NO_DEVICE         : return("No serial device was successfully initialized.  The serial driver will unload."                                                                                                );
      case ERROR_IRQ_BUSY                 : return("Unable to open a device that was sharing an interrupt request (IRQ) with other devices.  At least one other device that uses that IRQ was already opened."                     );
      case ERROR_MORE_WRITES              : return("A serial I/O operation was completed by another write to the serial port (the IOCTL_SERIAL_XOFF_COUNTER reached zero)."                                                        );
      case ERROR_COUNTER_TIMEOUT          : return("A serial I/O operation completed because the timeout period expired (the IOCTL_SERIAL_XOFF_COUNTER did not reach zero)."                                                       );
      case ERROR_FLOPPY_ID_MARK_NOT_FOUND : return("No ID address mark was found on the floppy disk."                                                                                                                              );
      case ERROR_FLOPPY_WRONG_CYLINDER    : return("Mismatch between the floppy disk sector ID field and the floppy disk controller track address."                                                                                );
      case ERROR_FLOPPY_UNKNOWN_ERROR     : return("The floppy disk controller reported an error that is not recognized by the floppy disk driver."                                                                                );
      case ERROR_FLOPPY_BAD_REGISTERS     : return("The floppy disk controller returned inconsistent results in its registers."                                                                                                    );
      case ERROR_DISK_RECALIBRATE_FAILED  : return("While accessing the hard disk, a recalibrate operation failed, even after retries."                                                                                            );
      case ERROR_DISK_OPERATION_FAILED    : return("While accessing the hard disk, a disk operation failed even after retries."                                                                                                    );
      case ERROR_DISK_RESET_FAILED        : return("While accessing the hard disk, a disk controller reset was needed, but even that failed."                                                                                      );
      case ERROR_EOM_OVERFLOW             : return("Physical end of tape encountered."                                                                                                                                             );
      case ERROR_NOT_ENOUGH_SERVER_MEMORY : return("Not enough server storage is available to process this command."                                                                                                               );
      case ERROR_POSSIBLE_DEADLOCK        : return("A potential deadlock condition has been detected."                                                                                                                             );
      case ERROR_MAPPED_ALIGNMENT         : return("The base address or the file offset specified does not have the proper alignment."                                                                                             );
      case ERROR_SET_POWER_STATE_VETOED   : return("An attempt to change the system power state was vetoed by another application or driver."                                                                                      );
      case ERROR_SET_POWER_STATE_FAILED   : return("The system BIOS failed an attempt to change the system power state."                                                                                                           );
      case ERROR_TOO_MANY_LINKS           : return("An attempt was made to create more links on a file than the file system supports."                                                                                             );
      case ERROR_OLD_WIN_VERSION          : return("The specified program requires a newer version of Windows."                                                                                                                    );
      case ERROR_APP_WRONG_OS             : return("The specified program is not a Windows or MS-DOS program."                                                                                                                     );
      case ERROR_SINGLE_INSTANCE_APP      : return("Cannot start more than one instance of the specified program."                                                                                                                 );
      case ERROR_RMODE_APP                : return("The specified program was written for an earlier version of Windows."                                                                                                          );
      case ERROR_INVALID_DLL              : return("One of the library files needed to run this application is damaged."                                                                                                           );
      case ERROR_NO_ASSOCIATION           : return("No application is associated with the specified file for this operation."                                                                                                      );
      case ERROR_DDE_FAIL                 : return("An error occurred in sending the command to the application."                                                                                                                  );
      case ERROR_DLL_NOT_FOUND            : return("One of the library files needed to run this application cannot be found."                                                                                                      );
      case ERROR_NO_MORE_USER_HANDLES     : return("The current process has used all of its system allowance of handles for Window Manager objects."                                                                               );
      case ERROR_MESSAGE_SYNC_ONLY        : return("The message can be used only with synchronous operations."                                                                                                                     );
      case ERROR_SOURCE_ELEMENT_EMPTY     : return("The indicated source element has no media."                                                                                                                                    );
      case ERROR_DESTINATION_ELEMENT_FULL : return("The indicated destination element already contains media."                                                                                                                     );
      case ERROR_ILLEGAL_ELEMENT_ADDRESS  : return("The indicated element does not exist."                                                                                                                                         );
      case ERROR_MAGAZINE_NOT_PRESENT     : return("The indicated element is part of a magazine that is not present."                                                                                                              );
      case 1164                           : return("The indicated device requires reinitialization due to hardware errors."                                                                                                        );
      case ERROR_DEVICE_REQUIRES_CLEANING : return("The device has indicated that cleaning is required before further operations are attempted."                                                                                   );
      case ERROR_DEVICE_DOOR_OPEN         : return("The device has indicated that its door is open."                                                                                                                               );
      case ERROR_DEVICE_NOT_CONNECTED     : return("The device is not connected."                                                                                                                                                  );
      case ERROR_NOT_FOUND                : return("Element not found."                                                                                                                                                            );
      case ERROR_NO_MATCH                 : return("There was no match for the specified key in the index."                                                                                                                        );
      case ERROR_SET_NOT_FOUND            : return("The property set specified does not exist on the object."                                                                                                                      );
      case ERROR_POINT_NOT_FOUND          : return("The point passed to GetMouseMovePoints is not in the buffer."                                                                                                                  );
      case ERROR_NO_TRACKING_SERVICE      : return("The tracking (workstation) service is not running."                                                                                                                            );
      case ERROR_NO_VOLUME_ID             : return("The Volume ID could not be found."                                                                                                                                             );

      // WinNet32 Status Codes
      case ERROR_CONNECTED_OTHER_PASSWORD : return("The network connection was made successfully, but the user had to be prompted for a password other than the one originally specified."                                         );
      case ERROR_BAD_USERNAME             : return("The specified username is invalid."                                                                                                                                            );
      case ERROR_NOT_CONNECTED            : return("This network connection does not exist."                                                                                                                                       );
      case ERROR_OPEN_FILES               : return("This network connection has files open or requests pending."                                                                                                                   );
      case ERROR_ACTIVE_CONNECTIONS       : return("Active connections still exist."                                                                                                                                               );
      case ERROR_DEVICE_IN_USE            : return("The device is in use by an active process and cannot be disconnected."                                                                                                         );
      case ERROR_BAD_DEVICE               : return("The specified device name is invalid."                                                                                                                                         );
      case ERROR_CONNECTION_UNAVAIL       : return("The device is not currently connected but it is a remembered connection."                                                                                                      );
      case ERROR_DEVICE_ALREADY_REMEMBERED: return("An attempt was made to remember a device that had previously been remembered."                                                                                                 );
      case ERROR_NO_NET_OR_BAD_PATH       : return("No network provider accepted the given network path."                                                                                                                          );
      case ERROR_BAD_PROVIDER             : return("The specified network provider name is invalid."                                                                                                                               );
      case ERROR_CANNOT_OPEN_PROFILE      : return("Unable to open the network connection profile."                                                                                                                                );
      case ERROR_BAD_PROFILE              : return("The network connection profile is corrupted."                                                                                                                                  );
      case ERROR_NOT_CONTAINER            : return("Cannot enumerate a noncontainer."                                                                                                                                              );
      case ERROR_EXTENDED_ERROR           : return("An extended error has occurred."                                                                                                                                               );
      case ERROR_INVALID_GROUPNAME        : return("The format of the specified group name is invalid."                                                                                                                            );
      case ERROR_INVALID_COMPUTERNAME     : return("The format of the specified computer name is invalid."                                                                                                                         );
      case ERROR_INVALID_EVENTNAME        : return("The format of the specified event name is invalid."                                                                                                                            );
      case ERROR_INVALID_DOMAINNAME       : return("The format of the specified domain name is invalid."                                                                                                                           );
      case ERROR_INVALID_SERVICENAME      : return("The format of the specified service name is invalid."                                                                                                                          );
      case ERROR_INVALID_NETNAME          : return("The format of the specified network name is invalid."                                                                                                                          );
      case ERROR_INVALID_SHARENAME        : return("The format of the specified share name is invalid."                                                                                                                            );
      case ERROR_INVALID_PASSWORDNAME     : return("The format of the specified password is invalid."                                                                                                                              );
      case ERROR_INVALID_MESSAGENAME      : return("The format of the specified message name is invalid."                                                                                                                          );
      case ERROR_INVALID_MESSAGEDEST      : return("The format of the specified message destination is invalid."                                                                                                                   );
      case 1219                           : return("The credentials supplied conflict with an existing set of credentials."                                                                                                        );
      case 1220                           : return("An attempt was made to establish a session to a network server, but there are already too many sessions established to that server."                                           );
      case ERROR_DUP_DOMAINNAME           : return("The workgroup or domain name is already in use by another computer on the network."                                                                                            );
      case ERROR_NO_NETWORK               : return("The network is not present or not started."                                                                                                                                    );
      case ERROR_CANCELLED                : return("The operation was canceled by the user."                                                                                                                                       );
      case ERROR_USER_MAPPED_FILE         : return("The requested operation cannot be performed on a file with a user-mapped section open."                                                                                        );
      case ERROR_CONNECTION_REFUSED       : return("The remote system refused the network connection."                                                                                                                             );
      case ERROR_GRACEFUL_DISCONNECT      : return("The network connection was gracefully closed."                                                                                                                                 );
      case 1227                           : return("The network transport endpoint already has an address associated with it."                                                                                                     );
      case ERROR_ADDRESS_NOT_ASSOCIATED   : return("An address has not yet been associated with the network endpoint."                                                                                                             );
      case ERROR_CONNECTION_INVALID       : return("An operation was attempted on a nonexistent network connection."                                                                                                               );
      case ERROR_CONNECTION_ACTIVE        : return("An invalid operation was attempted on an active network connection."                                                                                                           );
      case ERROR_NETWORK_UNREACHABLE      : return("The remote network is not reachable by the transport."                                                                                                                         );
      case ERROR_HOST_UNREACHABLE         : return("The remote system is not reachable by the transport."                                                                                                                          );
      case ERROR_PROTOCOL_UNREACHABLE     : return("The remote system does not support the transport protocol."                                                                                                                    );
      case ERROR_PORT_UNREACHABLE         : return("No service is operating at the destination network endpoint on the remote system."                                                                                             );
      case ERROR_REQUEST_ABORTED          : return("The request was aborted."                                                                                                                                                      );
      case ERROR_CONNECTION_ABORTED       : return("The network connection was aborted by the local system."                                                                                                                       );
      case ERROR_RETRY                    : return("The operation could not be completed.  A retry should be performed."                                                                                                           );
      case ERROR_CONNECTION_COUNT_LIMIT   : return("A connection to the server could not be made because the limit on the number of concurrent connections for this account has been reached."                                     );
      case ERROR_LOGIN_TIME_RESTRICTION   : return("Attempting to log in during an unauthorized time of day for this account."                                                                                                     );
      case ERROR_LOGIN_WKSTA_RESTRICTION  : return("The account is not authorized to log in from this station."                                                                                                                    );
      case ERROR_INCORRECT_ADDRESS        : return("The network address could not be used for the operation requested."                                                                                                            );
      case ERROR_ALREADY_REGISTERED       : return("The service is already registered."                                                                                                                                            );
      case ERROR_SERVICE_NOT_FOUND        : return("The specified service does not exist."                                                                                                                                         );
      case ERROR_NOT_AUTHENTICATED        : return("The operation being requested was not performed because the user has not been authenticated."                                                                                  );
      case ERROR_NOT_LOGGED_ON            : return("The operation being requested was not performed because the user has not logged on to the network.  The specified service does not exist."                                     );
      case ERROR_CONTINUE                 : return("Continue with work in progress."                                                                                                                                               );
      case ERROR_ALREADY_INITIALIZED      : return("An attempt was made to perform an initialization operation when initialization has already been completed."                                                                    );
      case ERROR_NO_MORE_DEVICES          : return("No more local devices."                                                                                                                                                        );
      case ERROR_NO_SUCH_SITE             : return("The specified site does not exist."                                                                                                                                            );
      case ERROR_DOMAIN_CONTROLLER_EXISTS : return("A domain controller with the specified name already exists."                                                                                                                   );
      case ERROR_DS_NOT_INSTALLED         : return("An error occurred while installing the Windows NT directory service.  Please view the event log for more information."                                                         );

      // Security Status Codes
      case ERROR_NOT_ALL_ASSIGNED         : return("Not all privileges referenced are assigned to the caller."                                                                                                                     );
      case ERROR_SOME_NOT_MAPPED          : return("Some mapping between account names and security IDs was not done."                                                                                                             );
      case ERROR_NO_QUOTAS_FOR_ACCOUNT    : return("No system quota limits are specifically set for this account."                                                                                                                 );
      case ERROR_LOCAL_USER_SESSION_KEY   : return("No encryption key is available.  A well-known encryption key was returned."                                                                                                    );
      case ERROR_NULL_LM_PASSWORD         : return("The Windows NT password is too complex to be converted to a LAN Manager password.  The LAN Manager password returned is a NULL string."                                        );
      case ERROR_UNKNOWN_REVISION         : return("The revision level is unknown."                                                                                                                                                );
      case ERROR_REVISION_MISMATCH        : return("Indicates two revision levels are incompatible."                                                                                                                               );
      case ERROR_INVALID_OWNER            : return("This security ID may not be assigned as the owner of this object."                                                                                                             );
      case ERROR_INVALID_PRIMARY_GROUP    : return("This security ID may not be assigned as the primary group of an object."                                                                                                       );
      case ERROR_NO_IMPERSONATION_TOKEN   : return("An attempt has been made to operate on an impersonation token by a thread that is not currently impersonating a client."                                                       );
      case ERROR_CANT_DISABLE_MANDATORY   : return("The group may not be disabled."                                                                                                                                                );
      case ERROR_NO_LOGON_SERVERS         : return("There are currently no logon servers available to service the logon request."                                                                                                  );
      case ERROR_NO_SUCH_LOGON_SESSION    : return("A specified logon session does not exist.  It may already have been terminated."                                                                                               );
      case ERROR_NO_SUCH_PRIVILEGE        : return("A specified privilege does not exist."                                                                                                                                         );
      case ERROR_PRIVILEGE_NOT_HELD       : return("A required privilege is not held by the client."                                                                                                                               );
      case ERROR_INVALID_ACCOUNT_NAME     : return("The name provided is not a properly formed account name."                                                                                                                      );
      case ERROR_USER_EXISTS              : return("The specified user already exists."                                                                                                                                            );
      case ERROR_NO_SUCH_USER             : return("The specified user does not exist."                                                                                                                                            );
      case ERROR_GROUP_EXISTS             : return("The specified group already exists."                                                                                                                                           );
      case ERROR_NO_SUCH_GROUP            : return("The specified group does not exist."                                                                                                                                           );
      case ERROR_MEMBER_IN_GROUP          : return("Either the specified user account is already a member of the specified group, or the specified group cannot be deleted because it contains a member."                          );
      case ERROR_MEMBER_NOT_IN_GROUP      : return("The specified user account is not a member of the specified group account."                                                                                                    );
      case ERROR_LAST_ADMIN               : return("The last remaining administration account cannot be disabled or deleted."                                                                                                      );
      case ERROR_WRONG_PASSWORD           : return("Unable to update the password.  The value provided as the current password is incorrect."                                                                                      );
      case ERROR_ILL_FORMED_PASSWORD      : return("Unable to update the password.  The value provided for the new password contains values that are not allowed in passwords."                                                    );
      case ERROR_PASSWORD_RESTRICTION     : return("Unable to update the password because a password update rule has been violated."                                                                                               );
      case ERROR_LOGON_FAILURE            : return("Logon failure: unknown user name or bad password."                                                                                                                             );
      case ERROR_ACCOUNT_RESTRICTION      : return("Logon failure: user account restriction."                                                                                                                                      );
      case ERROR_INVALID_LOGON_HOURS      : return("Logon failure: account logon time restriction violation."                                                                                                                      );
      case ERROR_INVALID_WORKSTATION      : return("Logon failure: user not allowed to log on to this computer."                                                                                                                   );
      case ERROR_PASSWORD_EXPIRED         : return("Logon failure: the specified account password has expired."                                                                                                                    );
      case ERROR_ACCOUNT_DISABLED         : return("Logon failure: account currently disabled."                                                                                                                                    );
      case ERROR_NONE_MAPPED              : return("No mapping between account names and security IDs was done."                                                                                                                   );
      case ERROR_TOO_MANY_LUIDS_REQUESTED : return("Too many local user identifiers (LUIDs) were requested at one time."                                                                                                           );
      case ERROR_LUIDS_EXHAUSTED          : return("No more local user identifiers (LUIDs) are available."                                                                                                                         );
      case ERROR_INVALID_SUB_AUTHORITY    : return("The subauthority part of a security ID is invalid for this particular use."                                                                                                    );
      case ERROR_INVALID_ACL              : return("The access control list (ACL) structure is invalid."                                                                                                                           );
      case ERROR_INVALID_SID              : return("The security ID structure is invalid."                                                                                                                                         );
      case ERROR_INVALID_SECURITY_DESCR   : return("The security descriptor structure is invalid."                                                                                                                                 );
      case ERROR_BAD_INHERITANCE_ACL      : return("The inherited access control list (ACL) or access control entry (ACE) could not be built."                                                                                     );
      case ERROR_SERVER_DISABLED          : return("The server is currently disabled."                                                                                                                                             );
      case ERROR_SERVER_NOT_DISABLED      : return("The server is currently enabled."                                                                                                                                              );
      case ERROR_INVALID_ID_AUTHORITY     : return("The value provided was an invalid value for an identifier authority."                                                                                                          );
      case ERROR_ALLOTTED_SPACE_EXCEEDED  : return("No more memory is available for security information updates."                                                                                                                 );
      case ERROR_INVALID_GROUP_ATTRIBUTES : return("The specified attributes are invalid, or incompatible with the attributes for the group as a whole."                                                                           );
      case ERROR_BAD_IMPERSONATION_LEVEL  : return("Either a required impersonation level was not provided, or the provided impersonation level is invalid."                                                                       );
      case ERROR_CANT_OPEN_ANONYMOUS      : return("Cannot open an anonymous level security token."                                                                                                                                );
      case ERROR_BAD_VALIDATION_CLASS     : return("The validation information class requested was invalid."                                                                                                                       );
      case ERROR_BAD_TOKEN_TYPE           : return("The type of the token is inappropriate for its attempted use."                                                                                                                 );
      case ERROR_NO_SECURITY_ON_OBJECT    : return("Unable to perform a security operation on an object that has no associated security."                                                                                          );
      case ERROR_CANT_ACCESS_DOMAIN_INFO  : return("Indicates a Windows NT Server could not be contacted or that objects within the domain are protected such that necessary information could not be retrieved."                  );
      case ERROR_INVALID_SERVER_STATE     : return("The security account manager (SAM) or local security authority (LSA) server was in the wrong state to perform the security operation."                                         );
      case ERROR_INVALID_DOMAIN_STATE     : return("The domain was in the wrong state to perform the security operation."                                                                                                          );
      case ERROR_INVALID_DOMAIN_ROLE      : return("This operation is only allowed for the Primary Domain Controller of the domain."                                                                                               );
      case ERROR_NO_SUCH_DOMAIN           : return("The specified domain did not exist."                                                                                                                                           );
      case ERROR_DOMAIN_EXISTS            : return("The specified domain already exists."                                                                                                                                          );
      case ERROR_DOMAIN_LIMIT_EXCEEDED    : return("An attempt was made to exceed the limit on the number of domains per server."                                                                                                  );
      case ERROR_INTERNAL_DB_CORRUPTION   : return("Unable to complete the requested operation because of either a catastrophic media failure or a data structure corruption on the disk."                                         );
      case ERROR_INTERNAL_ERROR           : return("The security account database contains an internal inconsistency."                                                                                                             );
      case ERROR_GENERIC_NOT_MAPPED       : return("Generic access types were contained in an access mask which should already be mapped to nongeneric types."                                                                     );
      case ERROR_BAD_DESCRIPTOR_FORMAT    : return("A security descriptor is not in the right format (absolute or self-relative)."                                                                                                 );
      case ERROR_NOT_LOGON_PROCESS        : return("The requested action is restricted for use by logon processes only.  The calling process has not registered as a logon process."                                               );
      case ERROR_LOGON_SESSION_EXISTS     : return("Cannot start a new logon session with an ID that is already in use."                                                                                                           );
      case ERROR_NO_SUCH_PACKAGE          : return("A specified authentication package is unknown."                                                                                                                                );
      case ERROR_BAD_LOGON_SESSION_STATE  : return("The logon session is not in a state that is consistent with the requested operation."                                                                                          );
      case ERROR_LOGON_SESSION_COLLISION  : return("The logon session ID is already in use."                                                                                                                                       );
      case ERROR_INVALID_LOGON_TYPE       : return("A logon request contained an invalid logon type value."                                                                                                                        );
      case ERROR_CANNOT_IMPERSONATE       : return("Unable to impersonate using a named pipe until data has been read from that pipe."                                                                                             );
      case ERROR_RXACT_INVALID_STATE      : return("The transaction state of a registry subtree is incompatible with the requested operation."                                                                                     );
      case ERROR_RXACT_COMMIT_FAILURE     : return("An internal security database corruption has been encountered."                                                                                                                );
      case ERROR_SPECIAL_ACCOUNT          : return("Cannot perform this operation on built-in accounts."                                                                                                                           );
      case ERROR_SPECIAL_GROUP            : return("Cannot perform this operation on this built-in special group."                                                                                                                 );
      case ERROR_SPECIAL_USER             : return("Cannot perform this operation on this built-in special user."                                                                                                                  );
      case ERROR_MEMBERS_PRIMARY_GROUP    : return("The user cannot be removed from a group because the group is currently the user's primary group."                                                                              );
      case ERROR_TOKEN_ALREADY_IN_USE     : return("The token is already in use as a primary token."                                                                                                                               );
      case ERROR_NO_SUCH_ALIAS            : return("The specified local group does not exist."                                                                                                                                     );
      case ERROR_MEMBER_NOT_IN_ALIAS      : return("The specified account name is not a member of the local group."                                                                                                                );
      case ERROR_MEMBER_IN_ALIAS          : return("The specified account name is already a member of the local group."                                                                                                            );
      case ERROR_ALIAS_EXISTS             : return("The specified local group already exists."                                                                                                                                     );
      case ERROR_LOGON_NOT_GRANTED        : return("Logon failure: the user has not been granted the requested logon type at this computer."                                                                                       );
      case ERROR_TOO_MANY_SECRETS         : return("The maximum number of secrets that may be stored in a single system has been exceeded."                                                                                        );
      case ERROR_SECRET_TOO_LONG          : return("The length of a secret exceeds the maximum length allowed."                                                                                                                    );
      case ERROR_INTERNAL_DB_ERROR        : return("The local security authority database contains an internal inconsistency."                                                                                                     );
      case ERROR_TOO_MANY_CONTEXT_IDS     : return("During a logon attempt, the user's security context accumulated too many security IDs."                                                                                        );
      case ERROR_LOGON_TYPE_NOT_GRANTED   : return("Logon failure: the user has not been granted the requested logon type at this computer."                                                                                       );
      case 1386                           : return("A cross-encrypted password is necessary to change a user password."                                                                                                            );
      case ERROR_NO_SUCH_MEMBER           : return("A new member could not be added to a local group because the member does not exist."                                                                                           );
      case ERROR_INVALID_MEMBER           : return("A new member could not be added to a local group because the member has the wrong account type."                                                                               );
      case ERROR_TOO_MANY_SIDS            : return("Too many security IDs have been specified."                                                                                                                                    );
      case 1390                           : return("A cross-encrypted password is necessary to change this user password."                                                                                                         );
      case ERROR_NO_INHERITANCE           : return("Indicates an ACL contains no inheritable components."                                                                                                                          );
      case ERROR_FILE_CORRUPT             : return("The file or directory is corrupted and unreadable."                                                                                                                            );
      case ERROR_DISK_CORRUPT             : return("The disk structure is corrupted and unreadable."                                                                                                                               );
      case ERROR_NO_USER_SESSION_KEY      : return("There is no user session key for the specified logon session."                                                                                                                 );
      case ERROR_LICENSE_QUOTA_EXCEEDED   : return("The service being accessed is licensed for a particular number of connections.  No more connections can be made to the service at this time."                                  );

      // WinUser Error Codes
      case ERROR_INVALID_WINDOW_HANDLE    : return("Invalid window handle."                                                                                                                                                        );
      case ERROR_INVALID_MENU_HANDLE      : return("Invalid menu handle."                                                                                                                                                          );
      case ERROR_INVALID_CURSOR_HANDLE    : return("Invalid cursor handle."                                                                                                                                                        );
      case ERROR_INVALID_ACCEL_HANDLE     : return("Invalid accelerator table handle."                                                                                                                                             );
      case ERROR_INVALID_HOOK_HANDLE      : return("Invalid hook handle."                                                                                                                                                          );
      case ERROR_INVALID_DWP_HANDLE       : return("Invalid handle to a multiple-window position structure."                                                                                                                       );
      case ERROR_TLW_WITH_WSCHILD         : return("Cannot create a top-level child window."                                                                                                                                       );
      case ERROR_CANNOT_FIND_WND_CLASS    : return("Cannot find window class."                                                                                                                                                     );
      case ERROR_WINDOW_OF_OTHER_THREAD   : return("Invalid window; it belongs to other thread."                                                                                                                                   );
      case ERROR_HOTKEY_ALREADY_REGISTERED: return("Hot key is already registered."                                                                                                                                                );
      case ERROR_CLASS_ALREADY_EXISTS     : return("Class already exists."                                                                                                                                                         );
      case ERROR_CLASS_DOES_NOT_EXIST     : return("Class does not exist."                                                                                                                                                         );
      case ERROR_CLASS_HAS_WINDOWS        : return("Class still has open windows."                                                                                                                                                 );
      case ERROR_INVALID_INDEX            : return("Invalid index."                                                                                                                                                                );
      case ERROR_INVALID_ICON_HANDLE      : return("Invalid icon handle."                                                                                                                                                          );
      case ERROR_PRIVATE_DIALOG_INDEX     : return("Using private DIALOG window words."                                                                                                                                            );
      case ERROR_LISTBOX_ID_NOT_FOUND     : return("The list box identifier was not found."                                                                                                                                        );
      case ERROR_NO_WILDCARD_CHARACTERS   : return("No wildcards were found."                                                                                                                                                      );
      case ERROR_CLIPBOARD_NOT_OPEN       : return("Thread does not have a clipboard open."                                                                                                                                        );
      case ERROR_HOTKEY_NOT_REGISTERED    : return("Hot key is not registered."                                                                                                                                                    );
      case ERROR_WINDOW_NOT_DIALOG        : return("The window is not a valid dialog window."                                                                                                                                      );
      case ERROR_CONTROL_ID_NOT_FOUND     : return("Control ID not found."                                                                                                                                                         );
      case ERROR_INVALID_COMBOBOX_MESSAGE : return("Invalid message for a combo box because it does not have an edit control."                                                                                                     );
      case ERROR_WINDOW_NOT_COMBOBOX      : return("The window is not a combo box."                                                                                                                                                );
      case ERROR_INVALID_EDIT_HEIGHT      : return("Height must be less than 256."                                                                                                                                                 );
      case ERROR_DC_NOT_FOUND             : return("Invalid device context (DC) handle."                                                                                                                                           );
      case ERROR_INVALID_HOOK_FILTER      : return("Invalid hook procedure type."                                                                                                                                                  );
      case ERROR_INVALID_FILTER_PROC      : return("Invalid hook procedure."                                                                                                                                                       );
      case ERROR_HOOK_NEEDS_HMOD          : return("Cannot set nonlocal hook without a module handle."                                                                                                                             );
      case ERROR_GLOBAL_ONLY_HOOK         : return("This hook procedure can only be set globally."                                                                                                                                 );
      case ERROR_JOURNAL_HOOK_SET         : return("The journal hook procedure is already installed."                                                                                                                              );
      case ERROR_HOOK_NOT_INSTALLED       : return("The hook procedure is not installed."                                                                                                                                          );
      case ERROR_INVALID_LB_MESSAGE       : return("Invalid message for single-selection list box."                                                                                                                                );
      case ERROR_SETCOUNT_ON_BAD_LB       : return("LB_SETCOUNT sent to non-lazy list box."                                                                                                                                        );
      case ERROR_LB_WITHOUT_TABSTOPS      : return("This list box does not support tab stops."                                                                                                                                     );
      case 1435                           : return("Cannot destroy object created by another thread."                                                                                                                              );
      case ERROR_CHILD_WINDOW_MENU        : return("Child windows cannot have menus."                                                                                                                                              );
      case ERROR_NO_SYSTEM_MENU           : return("The window does not have a system menu."                                                                                                                                       );
      case ERROR_INVALID_MSGBOX_STYLE     : return("Invalid message box style."                                                                                                                                                    );
      case ERROR_INVALID_SPI_VALUE        : return("Invalid system-wide (SPI_*) parameter."                                                                                                                                        );
      case ERROR_SCREEN_ALREADY_LOCKED    : return("Screen already locked."                                                                                                                                                        );
      case ERROR_HWNDS_HAVE_DIFF_PARENT   : return("All handles to windows in a multiple-window position structure must have the same parent."                                                                                     );
      case ERROR_NOT_CHILD_WINDOW         : return("The window is not a child window."                                                                                                                                             );
      case ERROR_INVALID_GW_COMMAND       : return("Invalid GW_* command."                                                                                                                                                         );
      case ERROR_INVALID_THREAD_ID        : return("Invalid thread identifier."                                                                                                                                                    );
      case ERROR_NON_MDICHILD_WINDOW      : return("Cannot process a message from a window that is not a multiple document interface (MDI) window."                                                                                );
      case ERROR_POPUP_ALREADY_ACTIVE     : return("Popup menu already active."                                                                                                                                                    );
      case ERROR_NO_SCROLLBARS            : return("The window does not have scroll bars."                                                                                                                                         );
      case ERROR_INVALID_SCROLLBAR_RANGE  : return("Scroll bar range cannot be greater than 0x7FFF."                                                                                                                               );
      case ERROR_INVALID_SHOWWIN_COMMAND  : return("Cannot show or remove the window in the way specified."                                                                                                                        );
      case ERROR_NO_SYSTEM_RESOURCES      : return("Insufficient system resources exist to complete the requested service."                                                                                                        );
      case ERROR_NONPAGED_SYSTEM_RESOURCES: return("Insufficient system resources exist to complete the requested service."                                                                                                        );
      case ERROR_PAGED_SYSTEM_RESOURCES   : return("Insufficient system resources exist to complete the requested service."                                                                                                        );
      case ERROR_WORKING_SET_QUOTA        : return("Insufficient quota to complete the requested service."                                                                                                                         );
      case ERROR_PAGEFILE_QUOTA           : return("Insufficient quota to complete the requested service."                                                                                                                         );
      case ERROR_COMMITMENT_LIMIT         : return("The paging file is too small for this operation to complete."                                                                                                                  );
      case ERROR_MENU_ITEM_NOT_FOUND      : return("A menu item was not found."                                                                                                                                                    );
      case ERROR_INVALID_KEYBOARD_HANDLE  : return("Invalid keyboard layout handle."                                                                                                                                               );
      case ERROR_HOOK_TYPE_NOT_ALLOWED    : return("Hook type not allowed."                                                                                                                                                        );
      case 1459                           : return("This operation requires an interactive window station."                                                                                                                        );
      case ERROR_TIMEOUT                  : return("This operation returned because the timeout period expired."                                                                                                                   );
      case ERROR_INVALID_MONITOR_HANDLE   : return("Invalid monitor handle."                                                                                                                                                       );

      /*
      // Eventlog Status Codes
      case ERROR_EVENTLOG_FILE_CORRUPT    : return("The event log file is corrupted."                                                                                                                                              );
      case ERROR_EVENTLOG_CANT_START      : return("No event log file could be opened, so the event logging service did not start."                                                                                                );
      case ERROR_LOG_FILE_FULL            : return("The event log file is full."                                                                                                                                                   );
      case ERROR_EVENTLOG_FILE_CHANGED    : return("The event log file has changed between read operations."                                                                                                                       );

      // MSI Error Codes
      case ERROR_INSTALL_SERVICE          : return("Failure accessing install service."                                                                                                                                            );
      case ERROR_INSTALL_USEREXIT         : return("The user canceled the installation."                                                                                                                                           );
      case ERROR_INSTALL_FAILURE          : return("Fatal error during installation."                                                                                                                                              );
      case ERROR_INSTALL_SUSPEND          : return("Installation suspended, incomplete."                                                                                                                                           );
      case ERROR_UNKNOWN_PRODUCT          : return("Product code not registered."                                                                                                                                                  );
      case ERROR_UNKNOWN_FEATURE          : return("Feature ID not registered."                                                                                                                                                    );
      case ERROR_UNKNOWN_COMPONENT        : return("Component ID not registered."                                                                                                                                                  );
      case ERROR_UNKNOWN_PROPERTY         : return("Unknown property."                                                                                                                                                             );
      case ERROR_INVALID_HANDLE_STATE     : return("Handle is in an invalid state."                                                                                                                                                );
      case ERROR_BAD_CONFIGURATION        : return("Configuration data corrupt."                                                                                                                                                   );
      case ERROR_INDEX_ABSENT             : return("Language not available."                                                                                                                                                       );
      case ERROR_INSTALL_SOURCE_ABSENT    : return("Install source unavailable."                                                                                                                                                   );
      case ERROR_BAD_DATABASE_VERSION     : return("Database version unsupported."                                                                                                                                                 );
      case ERROR_PRODUCT_UNINSTALLED      : return("Product is uninstalled."                                                                                                                                                       );
      case ERROR_BAD_QUERY_SYNTAX         : return("SQL query syntax invalid or unsupported."                                                                                                                                      );
      case ERROR_INVALID_FIELD            : return("Record field does not exist."                                                                                                                                                  );

      // RPC Status Codes
      case RPC_S_INVALID_STRING_BINDING   : return("The string binding is invalid."                                                                                                                                                );
      case RPC_S_WRONG_KIND_OF_BINDING    : return("The binding handle is not the correct type."                                                                                                                                   );
      case RPC_S_INVALID_BINDING          : return("The binding handle is invalid."                                                                                                                                                );
      case RPC_S_PROTSEQ_NOT_SUPPORTED    : return("The RPC protocol sequence is not supported."                                                                                                                                   );
      case RPC_S_INVALID_RPC_PROTSEQ      : return("The RPC protocol sequence is invalid."                                                                                                                                         );
      case RPC_S_INVALID_STRING_UUID      : return("The string universal unique identifier (UUID) is invalid."                                                                                                                     );
      case RPC_S_INVALID_ENDPOINT_FORMAT  : return("The endpoint format is invalid."                                                                                                                                               );
      case RPC_S_INVALID_NET_ADDR         : return("The network address is invalid."                                                                                                                                               );
      case RPC_S_NO_ENDPOINT_FOUND        : return("No endpoint was found."                                                                                                                                                        );
      case RPC_S_INVALID_TIMEOUT          : return("The timeout value is invalid."                                                                                                                                                 );
      case RPC_S_OBJECT_NOT_FOUND         : return("The object universal unique identifier (UUID) was not found."                                                                                                                  );
      case RPC_S_ALREADY_REGISTERED       : return("The object universal unique identifier (UUID) has already been registered."                                                                                                    );
      case RPC_S_TYPE_ALREADY_REGISTERED  : return("The type universal unique identifier (UUID) has already been registered."                                                                                                      );
      case RPC_S_ALREADY_LISTENING        : return("The RPC server is already listening."                                                                                                                                          );
      case RPC_S_NO_PROTSEQS_REGISTERED   : return("No protocol sequences have been registered."                                                                                                                                   );
      case RPC_S_NOT_LISTENING            : return("The RPC server is not listening."                                                                                                                                              );
      case RPC_S_UNKNOWN_MGR_TYPE         : return("The manager type is unknown."                                                                                                                                                  );
      case RPC_S_UNKNOWN_IF               : return("The interface is unknown."                                                                                                                                                     );
      case RPC_S_NO_BINDINGS              : return("There are no bindings."                                                                                                                                                        );
      case RPC_S_NO_PROTSEQS              : return("There are no protocol sequences."                                                                                                                                              );
      case RPC_S_CANT_CREATE_ENDPOINT     : return("The endpoint cannot be created."                                                                                                                                               );
      case RPC_S_OUT_OF_RESOURCES         : return("Not enough resources are available to complete this operation."                                                                                                                );
      case RPC_S_SERVER_UNAVAILABLE       : return("The RPC server is unavailable."                                                                                                                                                );
      case RPC_S_SERVER_TOO_BUSY          : return("The RPC server is too busy to complete this operation."                                                                                                                        );
      case RPC_S_INVALID_NETWORK_OPTIONS  : return("The network options are invalid."                                                                                                                                              );
      case RPC_S_NO_CALL_ACTIVE           : return("There are no remote procedure calls active on this thread."                                                                                                                    );
      case RPC_S_CALL_FAILED              : return("The remote procedure call failed."                                                                                                                                             );
      case RPC_S_CALL_FAILED_DNE          : return("The remote procedure call failed and did not execute."                                                                                                                         );
      case RPC_S_PROTOCOL_ERROR           : return("A remote procedure call (RPC) protocol error occurred."                                                                                                                        );
      case RPC_S_UNSUPPORTED_TRANS_SYN    : return("The transfer syntax is not supported by the RPC server."                                                                                                                       );
      case RPC_S_UNSUPPORTED_TYPE         : return("The universal unique identifier (UUID) type is not supported."                                                                                                                 );
      case RPC_S_INVALID_TAG              : return("The tag is invalid."                                                                                                                                                           );
      case RPC_S_INVALID_BOUND            : return("The array bounds are invalid."                                                                                                                                                 );
      case RPC_S_NO_ENTRY_NAME            : return("The binding does not contain an entry name."                                                                                                                                   );
      case RPC_S_INVALID_NAME_SYNTAX      : return("The name syntax is invalid."                                                                                                                                                   );
      case RPC_S_UNSUPPORTED_NAME_SYNTAX  : return("The name syntax is not supported."                                                                                                                                             );
      case RPC_S_UUID_NO_ADDRESS          : return("No network address is available to use to construct a universal unique identifier (UUID)."                                                                                     );
      case RPC_S_DUPLICATE_ENDPOINT       : return("The endpoint is a duplicate."                                                                                                                                                  );
      case RPC_S_UNKNOWN_AUTHN_TYPE       : return("The authentication type is unknown."                                                                                                                                           );
      case RPC_S_MAX_CALLS_TOO_SMALL      : return("The maximum number of calls is too small."                                                                                                                                     );
      case RPC_S_STRING_TOO_LONG          : return("The string is too long."                                                                                                                                                       );
      case RPC_S_PROTSEQ_NOT_FOUND        : return("The RPC protocol sequence was not found."                                                                                                                                      );
      case RPC_S_PROCNUM_OUT_OF_RANGE     : return("The procedure number is out of range."                                                                                                                                         );
      case RPC_S_BINDING_HAS_NO_AUTH      : return("The binding does not contain any authentication information."                                                                                                                  );
      case RPC_S_UNKNOWN_AUTHN_SERVICE    : return("The authentication service is unknown."                                                                                                                                        );
      case RPC_S_UNKNOWN_AUTHN_LEVEL      : return("The authentication level is unknown."                                                                                                                                          );
      case RPC_S_INVALID_AUTH_IDENTITY    : return("The security context is invalid."                                                                                                                                              );
      case RPC_S_UNKNOWN_AUTHZ_SERVICE    : return("The authorization service is unknown."                                                                                                                                         );
      case EPT_S_INVALID_ENTRY            : return("The entry is invalid."                                                                                                                                                         );
      case EPT_S_CANT_PERFORM_OP          : return("The server endpoint cannot perform the operation."                                                                                                                             );
      case EPT_S_NOT_REGISTERED           : return("There are no more endpoints available from the endpoint mapper."                                                                                                               );
      case RPC_S_NOTHING_TO_EXPORT        : return("No interfaces have been exported."                                                                                                                                             );
      case RPC_S_INCOMPLETE_NAME          : return("The entry name is incomplete."                                                                                                                                                 );
      case RPC_S_INVALID_VERS_OPTION      : return("The version option is invalid."                                                                                                                                                );
      case RPC_S_NO_MORE_MEMBERS          : return("There are no more members."                                                                                                                                                    );
      case RPC_S_NOT_ALL_OBJS_UNEXPORTED  : return("There is nothing to unexport."                                                                                                                                                 );
      case RPC_S_INTERFACE_NOT_FOUND      : return("The interface was not found."                                                                                                                                                  );
      case RPC_S_ENTRY_ALREADY_EXISTS     : return("The entry already exists."                                                                                                                                                     );
      case RPC_S_ENTRY_NOT_FOUND          : return("The entry is not found."                                                                                                                                                       );
      case RPC_S_NAME_SERVICE_UNAVAILABLE : return("The name service is unavailable."                                                                                                                                              );
      case RPC_S_INVALID_NAF_ID           : return("The network address family is invalid."                                                                                                                                        );
      case RPC_S_CANNOT_SUPPORT           : return("The requested operation is not supported."                                                                                                                                     );
      case RPC_S_NO_CONTEXT_AVAILABLE     : return("No security context is available to allow impersonation."                                                                                                                      );
      case RPC_S_INTERNAL_ERROR           : return("An internal error occurred in a remote procedure call (RPC)."                                                                                                                  );
      case RPC_S_ZERO_DIVIDE              : return("The RPC server attempted an integer division by zero."                                                                                                                         );
      case RPC_S_ADDRESS_ERROR            : return("An addressing error occurred in the RPC server."                                                                                                                               );
      case RPC_S_FP_DIV_ZERO              : return("A floating-point operation at the RPC server caused a division by zero."                                                                                                       );
      case RPC_S_FP_UNDERFLOW             : return("A floating-point underflow occurred at the RPC server."                                                                                                                        );
      case RPC_S_FP_OVERFLOW              : return("A floating-point overflow occurred at the RPC server."                                                                                                                         );
      case RPC_X_NO_MORE_ENTRIES          : return("The list of RPC servers available for the binding of auto handles has been exhausted."                                                                                         );
      case RPC_X_SS_CHAR_TRANS_OPEN_FAIL  : return("Unable to open the character translation table file."                                                                                                                          );
      case RPC_X_SS_CHAR_TRANS_SHORT_FILE : return("The file containing the character translation table has fewer than 512 bytes."                                                                                                 );
      case RPC_X_SS_IN_NULL_CONTEXT       : return("A null context handle was passed from the client to the host during a remote procedure call."                                                                                  );
      case RPC_X_SS_CONTEXT_DAMAGED       : return("The context handle changed during a remote procedure call."                                                                                                                    );
      case RPC_X_SS_HANDLES_MISMATCH      : return("The binding handles passed to a remote procedure call do not match."                                                                                                           );
      case RPC_X_SS_CANNOT_GET_CALL_HANDLE: return("The stub is unable to get the remote procedure call handle."                                                                                                                   );
      case RPC_X_NULL_REF_POINTER         : return("A null reference pointer was passed to the stub."                                                                                                                              );
      case RPC_X_ENUM_VALUE_OUT_OF_RANGE  : return("The enumeration value is out of range."                                                                                                                                        );
      case RPC_X_BYTE_COUNT_TOO_SMALL     : return("The byte count is too small."                                                                                                                                                  );
      case RPC_X_BAD_STUB_DATA            : return("The stub received bad data."                                                                                                                                                   );
      case ERROR_INVALID_USER_BUFFER      : return("The supplied user buffer is not valid for the requested operation."                                                                                                            );
      case ERROR_UNRECOGNIZED_MEDIA       : return("The disk media is not recognized.  It may not be formatted."                                                                                                                   );
      case ERROR_NO_TRUST_LSA_SECRET      : return("The workstation does not have a trust secret."                                                                                                                                 );
      case ERROR_NO_TRUST_SAM_ACCOUNT     : return("The SAM database on the Windows NT Server does not have a computer account for this workstation trust relationship."                                                           );
      case ERROR_TRUSTED_DOMAIN_FAILURE   : return("The trust relationship between the primary domain and the trusted domain failed."                                                                                              );
      case 1789                           : return("The trust relationship between this workstation and the primary domain failed."                                                                                                );
      case ERROR_TRUST_FAILURE            : return("The network logon failed."                                                                                                                                                     );
      case RPC_S_CALL_IN_PROGRESS         : return("A remote procedure call is already in progress for this thread."                                                                                                               );
      case ERROR_NETLOGON_NOT_STARTED     : return("An attempt was made to logon, but the network logon service was not started."                                                                                                  );
      case ERROR_ACCOUNT_EXPIRED          : return("The user\'s account has expired."                                                                                                                                               );
      case 1794                           : return("The redirector is in use and cannot be unloaded."                                                                                                                              );
      case 1795                           : return("The specified printer driver is already installed."                                                                                                                            );
      case ERROR_UNKNOWN_PORT             : return("The specified port is unknown."                                                                                                                                                );
      case ERROR_UNKNOWN_PRINTER_DRIVER   : return("The printer driver is unknown."                                                                                                                                                );
      case ERROR_UNKNOWN_PRINTPROCESSOR   : return("The print processor is unknown."                                                                                                                                               );
      case ERROR_INVALID_SEPARATOR_FILE   : return("The specified separator file is invalid."                                                                                                                                      );
      case ERROR_INVALID_PRIORITY         : return("The specified priority is invalid."                                                                                                                                            );
      case ERROR_INVALID_PRINTER_NAME     : return("The printer name is invalid."                                                                                                                                                  );
      case ERROR_PRINTER_ALREADY_EXISTS   : return("The printer already exists."                                                                                                                                                   );
      case ERROR_INVALID_PRINTER_COMMAND  : return("The printer command is invalid."                                                                                                                                               );
      case ERROR_INVALID_DATATYPE         : return("The specified datatype is invalid."                                                                                                                                            );
      case ERROR_INVALID_ENVIRONMENT      : return("The environment specified is invalid."                                                                                                                                         );
      case RPC_S_NO_MORE_BINDINGS         : return("There are no more bindings."                                                                                                                                                   );
      case 1807                           : return("The account used is an interdomain trust account.  Use your global user account or local user account to access this server."                                                  );
      case 1808                           : return("The account used is a computer account.  Use your global user account or local user account to access this server."                                                            );
      case 1809                           : return("The account used is a server trust account.  Use your global user account or local user account to access this server."                                                        );
      case ERROR_DOMAIN_TRUST_INCONSISTENT: return("The name or security ID (SID) of the domain specified is inconsistent with the trust information for that domain."                                                             );
      case ERROR_SERVER_HAS_OPEN_HANDLES  : return("The server is in use and cannot be unloaded."                                                                                                                                  );
      case ERROR_RESOURCE_DATA_NOT_FOUND  : return("The specified image file did not contain a resource section."                                                                                                                  );
      case ERROR_RESOURCE_TYPE_NOT_FOUND  : return("The specified resource type cannot be found in the image file."                                                                                                                );
      case ERROR_RESOURCE_NAME_NOT_FOUND  : return("The specified resource name cannot be found in the image file."                                                                                                                );
      case ERROR_RESOURCE_LANG_NOT_FOUND  : return("The specified resource language ID cannot be found in the image file."                                                                                                         );
      case ERROR_NOT_ENOUGH_QUOTA         : return("Not enough quota is available to process this command."                                                                                                                        );
      case RPC_S_NO_INTERFACES            : return("No interfaces have been registered."                                                                                                                                           );
      case RPC_S_CALL_CANCELLED           : return("The remote procedure call was cancelled."                                                                                                                                      );
      case RPC_S_BINDING_INCOMPLETE       : return("The binding handle does not contain all required information."                                                                                                                 );
      case RPC_S_COMM_FAILURE             : return("A communications failure occurred during a remote procedure call."                                                                                                             );
      case RPC_S_UNSUPPORTED_AUTHN_LEVEL  : return("The requested authentication level is not supported."                                                                                                                          );
      case RPC_S_NO_PRINC_NAME            : return("No principal name registered."                                                                                                                                                 );
      case RPC_S_NOT_RPC_ERROR            : return("The error specified is not a valid Windows RPC error code."                                                                                                                    );
      case RPC_S_UUID_LOCAL_ONLY          : return("A UUID that is valid only on this computer has been allocated."                                                                                                                );
      case RPC_S_SEC_PKG_ERROR            : return("A security package specific error occurred."                                                                                                                                   );
      case RPC_S_NOT_CANCELLED            : return("Thread is not canceled."                                                                                                                                                       );
      case RPC_X_INVALID_ES_ACTION        : return("Invalid operation on the encoding/decoding handle."                                                                                                                            );
      case RPC_X_WRONG_ES_VERSION         : return("Incompatible version of the serializing package."                                                                                                                              );
      case RPC_X_WRONG_STUB_VERSION       : return("Incompatible version of the RPC stub."                                                                                                                                         );
      case RPC_X_INVALID_PIPE_OBJECT      : return("The RPC pipe object is invalid or corrupted."                                                                                                                                  );
      case RPC_X_WRONG_PIPE_ORDER         : return("An invalid operation was attempted on an RPC pipe object."                                                                                                                     );
      case RPC_X_WRONG_PIPE_VERSION       : return("Unsupported RPC pipe version."                                                                                                                                                 );
      case RPC_S_GROUP_MEMBER_NOT_FOUND   : return("The group member was not found."                                                                                                                                               );
      case EPT_S_CANT_CREATE              : return("The endpoint mapper database entry could not be created."                                                                                                                      );
      case RPC_S_INVALID_OBJECT           : return("The object universal unique identifier (UUID) is the nil UUID."                                                                                                                );
      case ERROR_INVALID_TIME             : return("The specified time is invalid."                                                                                                                                                );
      case ERROR_INVALID_FORM_NAME        : return("The specified form name is invalid."                                                                                                                                           );
      case ERROR_INVALID_FORM_SIZE        : return("The specified form size is invalid."                                                                                                                                           );
      case ERROR_ALREADY_WAITING          : return("The specified printer handle is already being waited on"                                                                                                                       );
      case ERROR_PRINTER_DELETED          : return("The specified printer has been deleted."                                                                                                                                       );
      case ERROR_INVALID_PRINTER_STATE    : return("The state of the printer is invalid."                                                                                                                                          );
      case ERROR_PASSWORD_MUST_CHANGE     : return("The user must change his password before he logs on the first time."                                                                                                           );
      case 1908                           : return("Could not find the domain controller for this domain."                                                                                                                         );
      case ERROR_ACCOUNT_LOCKED_OUT       : return("The referenced account is currently locked out and may not be logged on to."                                                                                                   );
      case OR_INVALID_OXID                : return("The object exporter specified was not found."                                                                                                                                  );
      case OR_INVALID_OID                 : return("The object specified was not found."                                                                                                                                           );
      case OR_INVALID_SET                 : return("The object resolver set specified was not found."                                                                                                                              );
      case RPC_S_SEND_INCOMPLETE          : return("Some data remains to be sent in the request buffer."                                                                                                                           );
      case RPC_S_INVALID_ASYNC_HANDLE     : return("Invalid asynchronous remote procedure call handle."                                                                                                                            );
      case RPC_S_INVALID_ASYNC_CALL       : return("Invalid asynchronous RPC call handle for this operation."                                                                                                                      );
      case RPC_X_PIPE_CLOSED              : return("The RPC pipe object has already been closed."                                                                                                                                  );
      case RPC_X_PIPE_DISCIPLINE_ERROR    : return("The RPC call completed before all pipes were processed."                                                                                                                       );
      case RPC_X_PIPE_EMPTY               : return("No more data is available from the RPC pipe."                                                                                                                                  );
      case ERROR_NO_SITENAME              : return("No site name is available for this machine."                                                                                                                                   );
      case ERROR_CANT_ACCESS_FILE         : return("The file can not be accessed by the system."                                                                                                                                   );
      case ERROR_CANT_RESOLVE_FILENAME    : return("The name of the file cannot be resolved by the system."                                                                                                                        );
      case 1922                           : return("The directory service evaluated group memberships locally."                                                                                                                    );
      case ERROR_DS_NO_ATTRIBUTE_OR_VALUE : return("The specified directory service attribute or value does not exist."                                                                                                            );
      case 1924                           : return("The attribute syntax specified to the directory service is invalid."                                                                                                           );
      case 1925                           : return("The attribute type specified to the directory service is not defined."                                                                                                         );
      case 1926                           : return("The specified directory service attribute or value already exists."                                                                                                            );
      case ERROR_DS_BUSY                  : return("The directory service is busy."                                                                                                                                                );
      case ERROR_DS_UNAVAILABLE           : return("The directory service is unavailable."                                                                                                                                         );
      case ERROR_DS_NO_RIDS_ALLOCATED     : return("The directory service was unable to allocate a relative identifier."                                                                                                           );
      case ERROR_DS_NO_MORE_RIDS          : return("The directory service has exhausted the pool of relative identifiers."                                                                                                         );
      case ERROR_DS_INCORRECT_ROLE_OWNER  : return("The requested operation could not be performed because the directory service is not the master for that type of operation."                                                    );
      case ERROR_DS_RIDMGR_INIT_ERROR     : return("The directory service was unable to initialize the subsystem that allocates relative identifiers."                                                                             );
      case ERROR_DS_OBJ_CLASS_VIOLATION   : return("The requested operation did not satisfy one or more constraints associated with the class of the object."                                                                      );
      case ERROR_DS_CANT_ON_NON_LEAF      : return("The directory service can perform the requested operation only on a leaf object."                                                                                              );
      case ERROR_DS_CANT_ON_RDN           : return("The directory service cannot perform the requested operation on the RDN attribute of an object."                                                                               );
      case ERROR_DS_CANT_MOD_OBJ_CLASS    : return("The directory service detected an attempt to modify the object class of an object."                                                                                            );
      case ERROR_DS_CROSS_DOM_MOVE_ERROR  : return("The requested cross domain move operation could not be performed."                                                                                                             );
      case ERROR_DS_GC_NOT_AVAILABLE      : return("Unable to contact the global catalog server."                                                                                                                                  );
      case ERROR_NO_BROWSER_SERVERS_FOUND : return("The list of servers for this workgroup is not currently available"                                                                                                             );

      // OpenGL Error Codes
      case ERROR_INVALID_PIXEL_FORMAT     : return("The pixel format is invalid."                                                                                                                                                  );
      case ERROR_BAD_DRIVER               : return("The specified driver is invalid."                                                                                                                                              );
      case ERROR_INVALID_WINDOW_STYLE     : return("The window style or class attribute is invalid for this operation."                                                                                                            );
      case ERROR_METAFILE_NOT_SUPPORTED   : return("The requested metafile operation is not supported."                                                                                                                            );
      case ERROR_TRANSFORM_NOT_SUPPORTED  : return("The requested transformation operation is not supported."                                                                                                                      );
      case ERROR_CLIPPING_NOT_SUPPORTED   : return("The requested clipping operation is not supported."                                                                                                                            );

      // Image Color Management Error Codes
      case ERROR_INVALID_CMM              : return("The specified color management module is invalid."                                                                                                                             );
      case ERROR_INVALID_PROFILE          : return("The specified color profile is invalid."                                                                                                                                       );
      case ERROR_TAG_NOT_FOUND            : return("The specified tag was not found."                                                                                                                                              );
      case ERROR_TAG_NOT_PRESENT          : return("A required tag is not present."                                                                                                                                                );
      case ERROR_DUPLICATE_TAG            : return("The specified tag is already present."                                                                                                                                         );
      case 2305                           : return("The specified color profile is not associated with any device."                                                                                                                );
      case ERROR_PROFILE_NOT_FOUND        : return("The specified color profile was not found."                                                                                                                                    );
      case ERROR_INVALID_COLORSPACE       : return("The specified color space is invalid."                                                                                                                                         );
      case ERROR_ICM_NOT_ENABLED          : return("Image Color Management is not enabled."                                                                                                                                        );
      case ERROR_DELETING_ICM_XFORM       : return("There was an error while deleting the color transform."                                                                                                                        );
      case ERROR_INVALID_TRANSFORM        : return("The specified color transform is invalid."                                                                                                                                     );

      // Win32 Spooler Error Codes
      case ERROR_UNKNOWN_PRINT_MONITOR    : return("The specified print monitor is unknown."                                                                                                                                       );
      case ERROR_PRINTER_DRIVER_IN_USE    : return("The specified printer driver is currently in use."                                                                                                                             );
      case ERROR_SPOOL_FILE_NOT_FOUND     : return("The spool file was not found."                                                                                                                                                 );
      case ERROR_SPL_NO_STARTDOC          : return("A StartDocPrinter call was not issued."                                                                                                                                        );
      case ERROR_SPL_NO_ADDJOB            : return("An AddJob call was not issued."                                                                                                                                                );
      case 3005                           : return("The specified print processor has already been installed."                                                                                                                     );
      case 3006                           : return("The specified print monitor has already been installed."                                                                                                                       );
      case ERROR_INVALID_PRINT_MONITOR    : return("The specified print monitor does not have the required functions."                                                                                                             );
      case ERROR_PRINT_MONITOR_IN_USE     : return("The specified print monitor is currently in use."                                                                                                                              );
      case ERROR_PRINTER_HAS_JOBS_QUEUED  : return("The requested operation is not allowed when there are jobs queued to the printer."                                                                                             );
      case ERROR_SUCCESS_REBOOT_REQUIRED  : return("The requested operation is successful.  Changes will not be effective until the system is rebooted."                                                                           );
      case ERROR_SUCCESS_RESTART_REQUIRED : return("The requested operation is successful.  Changes will not be effective until the service is restarted."                                                                         );

      // WINS Error Codes
      case ERROR_WINS_INTERNAL            : return("WINS encountered an error while processing the command."                                                                                                                       );
      case ERROR_CAN_NOT_DEL_LOCAL_WINS   : return("The local WINS can not be deleted."                                                                                                                                            );
      case ERROR_STATIC_INIT              : return("The importation from the file failed."                                                                                                                                         );
      case ERROR_INC_BACKUP               : return("The backup failed.  Was a full backup done before?"                                                                                                                            );
      case ERROR_FULL_BACKUP              : return("The backup failed.  Check the directory to which you are backing the database."                                                                                                );
      case ERROR_REC_NON_EXISTENT         : return("The name does not exist in the WINS database."                                                                                                                                 );
      case ERROR_RPL_NOT_ALLOWED          : return("Replication with a nonconfigured partner is not allowed."                                                                                                                      );

      // DHCP Error Codes
      case ERROR_DHCP_ADDRESS_CONFLICT    : return("The DHCP client has obtained an IP address that is already in use on the network."                                                                                             );

      // WMI Error Codes
      case ERROR_WMI_GUID_NOT_FOUND       : return("The GUID passed was not recognized as valid by a WMI data provider."                                                                                                           );
      case ERROR_WMI_INSTANCE_NOT_FOUND   : return("The instance name passed was not recognized as valid by a WMI data provider."                                                                                                  );
      case ERROR_WMI_ITEMID_NOT_FOUND     : return("The data item ID passed was not recognized as valid by a WMI data provider."                                                                                                   );
      case ERROR_WMI_TRY_AGAIN            : return("The WMI request could not be completed and should be retried."                                                                                                                 );
      case ERROR_WMI_DP_NOT_FOUND         : return("The WMI data provider could not be located."                                                                                                                                   );
      case 4205                           : return("The WMI data provider references an instance set that has not been registered."                                                                                                );
      case ERROR_WMI_ALREADY_ENABLED      : return("The WMI data block or event notification has already been enabled."                                                                                                            );
      case ERROR_WMI_GUID_DISCONNECTED    : return("The WMI data block is no longer available."                                                                                                                                    );
      case ERROR_WMI_SERVER_UNAVAILABLE   : return("The WMI data service is not available."                                                                                                                                        );
      case ERROR_WMI_DP_FAILED            : return("The WMI data provider failed to carry out the request."                                                                                                                        );
      case ERROR_WMI_INVALID_MOF          : return("The WMI MOF information is not valid."                                                                                                                                         );
      case ERROR_WMI_INVALID_REGINFO      : return("The WMI registration information is not valid."                                                                                                                                );

      // NT Media Services Error Codes
      case ERROR_INVALID_MEDIA            : return("The media identifier does not represent a valid medium."                                                                                                                       );
      case ERROR_INVALID_LIBRARY          : return("The library identifier does not represent a valid library."                                                                                                                    );
      case ERROR_INVALID_MEDIA_POOL       : return("The media pool identifier does not represent a valid media pool."                                                                                                              );
      case ERROR_DRIVE_MEDIA_MISMATCH     : return("The drive and medium are not compatible or exist in different libraries."                                                                                                      );
      case ERROR_MEDIA_OFFLINE            : return("The medium currently exists in an offline library and must be online to perform this operation."                                                                               );
      case ERROR_LIBRARY_OFFLINE          : return("The operation cannot be performed on an offline library."                                                                                                                      );
      case ERROR_EMPTY                    : return("The library, drive, or media pool is empty."                                                                                                                                   );
      case ERROR_NOT_EMPTY                : return("The library, drive, or media pool must be empty to perform this operation."                                                                                                    );
      case ERROR_MEDIA_UNAVAILABLE        : return("No media is currently available in this media pool or library."                                                                                                                );
      case ERROR_RESOURCE_DISABLED        : return("A resource required for this operation is disabled."                                                                                                                           );
      case ERROR_INVALID_CLEANER          : return("The media identifier does not represent a valid cleaner."                                                                                                                      );
      case ERROR_UNABLE_TO_CLEAN          : return("The drive cannot be cleaned or does not support cleaning."                                                                                                                     );
      case ERROR_OBJECT_NOT_FOUND         : return("The object identifier does not represent a valid object."                                                                                                                      );
      case ERROR_DATABASE_FAILURE         : return("Unable to read from or write to the database."                                                                                                                                 );
      case ERROR_DATABASE_FULL            : return("The database is full."                                                                                                                                                         );
      case ERROR_MEDIA_INCOMPATIBLE       : return("The medium is not compatible with the device or media pool."                                                                                                                   );
      case ERROR_RESOURCE_NOT_PRESENT     : return("The resource required for this operation does not exist."                                                                                                                      );
      case ERROR_INVALID_OPERATION        : return("The operation identifier is not valid."                                                                                                                                        );
      case ERROR_MEDIA_NOT_AVAILABLE      : return("The media is not mounted or ready for use."                                                                                                                                    );
      case ERROR_DEVICE_NOT_AVAILABLE     : return("The device is not ready for use."                                                                                                                                              );
      case ERROR_REQUEST_REFUSED          : return("The operator or administrator has refused the request."                                                                                                                        );

      // NT Remote Storage Service Error Codes
      case ERROR_FILE_OFFLINE             : return("The remote storage service was not able to recall the file."                                                                                                                   );
      case ERROR_REMOTE_STORAGE_NOT_ACTIVE: return("The remote storage service is not operational at this time."                                                                                                                   );
      case 4352                           : return("The remote storage service encountered a media error."                                                                                                                         );

      // NT Reparse Points Error Codes
      case ERROR_NOT_A_REPARSE_POINT      : return("The file or directory is not a reparse point."                                                                                                                                 );
      case 4391                           : return("The reparse point attribute cannot be set because it conflicts with an existing attribute."                                                                                    );

      // Cluster Error Codes
      case ERROR_DEPENDENT_RESOURCE_EXISTS: return("The cluster resource cannot be moved to another group because other resources are dependent on it."                                                                            );
      case ERROR_DEPENDENCY_NOT_FOUND     : return("The cluster resource dependency cannot be found."                                                                                                                              );
      case ERROR_DEPENDENCY_ALREADY_EXISTS: return("The cluster resource cannot be made dependent on the specified resource because it is already dependent."                                                                      );
      case ERROR_RESOURCE_NOT_ONLINE      : return("The cluster resource is not online."                                                                                                                                           );
      case ERROR_HOST_NODE_NOT_AVAILABLE  : return("A cluster node is not available for this operation."                                                                                                                           );
      case ERROR_RESOURCE_NOT_AVAILABLE   : return("The cluster resource is not available."                                                                                                                                        );
      case ERROR_RESOURCE_NOT_FOUND       : return("The cluster resource could not be found."                                                                                                                                      );
      case ERROR_SHUTDOWN_CLUSTER         : return("The cluster is being shut down."                                                                                                                                               );
      case ERROR_CANT_EVICT_ACTIVE_NODE   : return("A cluster node cannot be evicted from the cluster while it is online."                                                                                                         );
      case ERROR_OBJECT_ALREADY_EXISTS    : return("The object already exists."                                                                                                                                                    );
      case ERROR_OBJECT_IN_LIST           : return("The object is already in the list."                                                                                                                                            );
      case ERROR_GROUP_NOT_AVAILABLE      : return("The cluster group is not available for any new requests."                                                                                                                      );
      case ERROR_GROUP_NOT_FOUND          : return("The cluster group could not be found."                                                                                                                                         );
      case ERROR_GROUP_NOT_ONLINE         : return("The operation could not be completed because the cluster group is not online."                                                                                                 );
      case 5015                           : return("The cluster node is not the owner of the resource."                                                                                                                            );
      case ERROR_HOST_NODE_NOT_GROUP_OWNER: return("The cluster node is not the owner of the group."                                                                                                                               );
      case ERROR_RESMON_CREATE_FAILED     : return("The cluster resource could not be created in the specified resource monitor."                                                                                                  );
      case ERROR_RESMON_ONLINE_FAILED     : return("The cluster resource could not be brought online by the resource monitor."                                                                                                     );
      case ERROR_RESOURCE_ONLINE          : return("The operation could not be completed because the cluster resource is online."                                                                                                  );
      case ERROR_QUORUM_RESOURCE          : return("The cluster resource could not be deleted or brought offline because it is the quorum resource."                                                                               );
      case ERROR_NOT_QUORUM_CAPABLE       : return("The cluster could not make the specified resource a quorum resource because it is not capable of being a quorum resource."                                                     );
      case ERROR_CLUSTER_SHUTTING_DOWN    : return("The cluster software is shutting down."                                                                                                                                        );
      case ERROR_INVALID_STATE            : return("The group or resource is not in the correct state to perform the requested operation."                                                                                         );
      case 5024                           : return("The properties were stored but not all changes will take effect until the next time the resource is brought online."                                                           );
      case ERROR_NOT_QUORUM_CLASS         : return("The cluster could not make the specified resource a quorum resource because it does not belong to a shared storage class."                                                     );
      case ERROR_CORE_RESOURCE            : return("The cluster resource could not be deleted since it is a core resource."                                                                                                        );
      case 5027                           : return("The quorum resource failed to come online."                                                                                                                                    );
      case ERROR_QUORUMLOG_OPEN_FAILED    : return("The quorum log could not be created or mounted successfully."                                                                                                                  );
      case ERROR_CLUSTERLOG_CORRUPT       : return("The cluster log is corrupt."                                                                                                                                                   );
      case 5030                           : return("The record could not be written to the cluster log since it exceeds the maximum size."                                                                                         );
      case 5031                           : return("The cluster log exceeds its maximum size."                                                                                                                                     );
      case 5032                           : return("No checkpoint record was found in the cluster log."                                                                                                                            );
      case 5033                           : return("The minimum required disk space needed for logging is not available."                                                                                                          );

      // EFS Error Codes
      case ERROR_ENCRYPTION_FAILED        : return("The specified file could not be encrypted."                                                                                                                                    );
      case ERROR_DECRYPTION_FAILED        : return("The specified file could not be decrypted."                                                                                                                                    );
      case ERROR_FILE_ENCRYPTED           : return("The specified file is encrypted and the user does not have the ability to decrypt it."                                                                                         );
      case ERROR_NO_RECOVERY_POLICY       : return("There is no encryption recovery policy configured for this system."                                                                                                            );
      case ERROR_NO_EFS                   : return("The required encryption driver is not loaded for this system."                                                                                                                 );
      case ERROR_WRONG_EFS                : return("The file was encrypted with a different encryption driver than is currently loaded."                                                                                           );
      case ERROR_NO_USER_KEYS             : return("There are no EFS keys defined for the user."                                                                                                                                   );
      case ERROR_FILE_NOT_ENCRYPTED       : return("The specified file is not encrypted."                                                                                                                                          );
      case ERROR_NOT_EXPORT_FORMAT        : return("The specified file is not in the defined EFS export format."                                                                                                                   );
      */
   }
   return("unknown error");
}


/**
 * Gibt die lesbare Version eines Events zurück.
 *
 * @param  int event - Event
 *
 * @return string
 */
string EventToStr(int event) {
   switch (event) {
      case EVENT_BAR_OPEN       : return("BarOpen"       );
      case EVENT_ORDER_PLACE    : return("OrderPlace"    );
      case EVENT_ORDER_CHANGE   : return("OrderChange"   );
      case EVENT_ORDER_CANCEL   : return("OrderCancel"   );
      case EVENT_POSITION_OPEN  : return("PositionOpen"  );
      case EVENT_POSITION_CLOSE : return("PositionClose" );
      case EVENT_ACCOUNT_CHANGE : return("AccountChange" );
      case EVENT_ACCOUNT_PAYMENT: return("AccountPayment");
      case EVENT_HISTORY_CHANGE : return("HistoryChange" );
   }

   catch("EventToStr()   unknown event: "+ event, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt den Offset der angegebenen lokalen Zeit zu GMT (Greenwich Mean Time) zurück.
 *
 * @param  datetime localTime - Zeitpunkt lokaler Zeit (default: aktuelle Zeit)
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetLocalToGmtOffset(datetime localTime=-1) {
   if (localTime != -1) {
      catch("GetLocalToGmtOffset()   support for parameter 'localTime' not yet implemented", ERR_RUNTIME_ERROR);
      return(EMPTY_VALUE);
   }

   int /*TIME_ZONE_INFORMATION*/ tzi[43];       // struct TIME_ZONE_INFORMATION = 172 byte
   int type = GetTimeZoneInformation(tzi);

   int offset = 0;

   if (type != TIME_ZONE_ID_UNKNOWN) {
      offset = tzi.Bias(tzi);
      if (type == TIME_ZONE_ID_DAYLIGHT)
         offset += tzi.DaylightBias(tzi);
      offset *= -60;
   }

   //Print("GetLocalToGmtOffset()   difference between local and GMT is: ", (offset/MINUTES), " minutes");

   if (catch("GetLocalToGmtOffset()") != NO_ERROR)
      return(EMPTY_VALUE);
   return(offset);
}


/**
 * Gibt den numerischen Code einer MovingAverage-Methode zurück.
 *
 * @param  string description - MA-Methode (SMA, EMA, SMMA, LWMA, MODE_SMA, MODE_EMA, MODE_SMMA, MODE_LWMA)
 *
 * @return int - MA-Code
 */
int GetMovingAverageMethod(string description) {
   description = StringToUpper(description);

   if (description == "SMA"      ) return(MODE_SMA );
   if (description == "MODE_SMA" ) return(MODE_SMA );
   if (description == "EMA"      ) return(MODE_EMA );
   if (description == "MODE_EMA" ) return(MODE_EMA );
   if (description == "SMMA"     ) return(MODE_SMMA);
   if (description == "MODE_SMMA") return(MODE_SMMA);
   if (description == "LWMA"     ) return(MODE_LWMA);
   if (description == "MODE_LWMA") return(MODE_LWMA);

   catch("GetMovingAverageMethod()  invalid parameter description: "+ description, ERR_INVALID_FUNCTION_PARAMVALUE);
   return(-1);
}


/**
 * Gibt die lesbare Version eines Operation-Types zurück.
 *
 * @param  int type - Operation-Type
 *
 * @return string
 */
string OperationTypeToStr(int type) {
   switch (type) {
      case OP_BUY      : return("Buy"       );
      case OP_SELL     : return("Sell"      );
      case OP_BUYLIMIT : return("Buy Limit" );
      case OP_SELLLIMIT: return("Sell Limit");
      case OP_BUYSTOP  : return("Stop Buy"  );
      case OP_SELLSTOP : return("Stop Sell" );
      case OP_BALANCE  : return("Balance"   );
      case OP_CREDIT   : return("Credit"    );
   }

   catch("OperationTypeToStr()  invalid paramter type: "+ type, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt den Code einer Timeframe-Beschreibung zurück.
 *
 * @param  string description - Timeframe-Beschreibung (M1, M5, M15, M30 etc.)
 *
 * @return int - Timeframe-Code
 */
int GetPeriod(string description) {
   description = StringToUpper(description);

   if (description == "M1" ) return(PERIOD_M1 );      //     1  1 minute
   if (description == "M5" ) return(PERIOD_M5 );      //     5  5 minutes
   if (description == "M15") return(PERIOD_M15);      //    15  15 minutes
   if (description == "M30") return(PERIOD_M30);      //    30  30 minutes
   if (description == "H1" ) return(PERIOD_H1 );      //    60  1 hour
   if (description == "H4" ) return(PERIOD_H4 );      //   240  4 hour
   if (description == "D1" ) return(PERIOD_D1 );      //  1440  daily
   if (description == "W1" ) return(PERIOD_W1 );      // 10080  weekly
   if (description == "MN1") return(PERIOD_MN1);      // 43200  monthly

   catch("GetPeriod()  invalid parameter description: "+ description, ERR_INVALID_FUNCTION_PARAMVALUE);
   return(0);
}


/**
 * Alias für PeriodToStr().
 */
string TimeframeToStr(int timeframe=0) {
   return(PeriodToStr(timeframe));
}


/**
 * Gibt die lesbare Version eines Timeframe-Codes zurück.
 *
 * @param  int period - Timeframe-Code bzw. Anzahl der Minuten je Chart-Bar (default: Periode des aktuellen Charts)
 *
 * @return string
 */
string PeriodToStr(int period=0) {
   if (period == 0)
      period = Period();

   switch (period) {
      case PERIOD_M1 : return("M1" );     //     1  1 minute
      case PERIOD_M5 : return("M5" );     //     5  5 minutes
      case PERIOD_M15: return("M15");     //    15  15 minutes
      case PERIOD_M30: return("M30");     //    30  30 minutes
      case PERIOD_H1 : return("H1" );     //    60  1 hour
      case PERIOD_H4 : return("H4" );     //   240  4 hour
      case PERIOD_D1 : return("D1" );     //  1440  daily
      case PERIOD_W1 : return("W1" );     // 10080  weekly
      case PERIOD_MN1: return("MN1");     // 43200  monthly
   }

   catch("PeriodToStr()  invalid parameter period: "+ period, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt das Timeframe-Flag der angegebenen Chartperiode zurück.
 *
 * @param  int period - Timeframe-Identifier (default: Periode des aktuellen Charts)
 *
 * @return int - Timeframe-Flag
 */
int GetPeriodFlag(int period=0) {
   if (period == 0)
      period = Period();

   switch (period) {
      case PERIOD_M1 : return(PERIODFLAG_M1 );
      case PERIOD_M5 : return(PERIODFLAG_M5 );
      case PERIOD_M15: return(PERIODFLAG_M15);
      case PERIOD_M30: return(PERIODFLAG_M30);
      case PERIOD_H1 : return(PERIODFLAG_H1 );
      case PERIOD_H4 : return(PERIODFLAG_H4 );
      case PERIOD_D1 : return(PERIODFLAG_D1 );
      case PERIOD_W1 : return(PERIODFLAG_W1 );
      case PERIOD_MN1: return(PERIODFLAG_MN1);
   }

   catch("GetPeriodFlag()  invalid parameter period: "+ period, ERR_INVALID_FUNCTION_PARAMVALUE);
   return(0);
}


/**
 * Gibt die lesbare Version eines Timeframe-Flags zurück.
 *
 * @param  int flags - Kombination verschiedener Timeframe-Flags
 *
 * @return string
 */
string PeriodFlagToStr(int flags) {
   string result = "";

   if (flags & PERIODFLAG_M1  != 0) result = StringConcatenate(result, " | M1" );
   if (flags & PERIODFLAG_M5  != 0) result = StringConcatenate(result, " | M5" );
   if (flags & PERIODFLAG_M15 != 0) result = StringConcatenate(result, " | M15");
   if (flags & PERIODFLAG_M30 != 0) result = StringConcatenate(result, " | M30");
   if (flags & PERIODFLAG_H1  != 0) result = StringConcatenate(result, " | H1" );
   if (flags & PERIODFLAG_H4  != 0) result = StringConcatenate(result, " | H4" );
   if (flags & PERIODFLAG_D1  != 0) result = StringConcatenate(result, " | D1" );
   if (flags & PERIODFLAG_W1  != 0) result = StringConcatenate(result, " | W1" );
   if (flags & PERIODFLAG_MN1 != 0) result = StringConcatenate(result, " | MN1");

   if (StringLen(result) > 0)
      result = StringSubstr(result, 3);
   return(result);
}


/**
 * Gibt die Zeitzone des Tradeservers zurück.
 *
 * @return string - 1 oder 2 Zeitzonenkürzel ("Standard-Zeitzone[,DaylightSaving-Zeitzone]")
 *                  oder ein Leerstring, falls ein Fehler auftrat
 */
string GetServerTimezone() {
   string account = GetAccountNumber();      // evt. ERR_TERMINAL_NOT_YET_READY
   if (account == "0")
      return("");

   string configValue = GetConfigString("Timezones", account, "");
   if (configValue == "") {
      catch("GetServerTimezone(1)  timezone configuration not found for account: "+ account, ERR_RUNTIME_ERROR);
      return("");
   }

   string values[];
   Explode(configValue, ",", values);
   if (ArraySize(values) > 2) {
      catch("GetServerTimezone(2)  invalid timezone configuration for account "+ account +": \""+ configValue +"\"", ERR_RUNTIME_ERROR);
      return("");
   }
   string zone = JoinStrings(values, ",");

   if      (zone == "EET"     ) {} // Europe/Kiev        GMT+0200[,GMT+0300]
   else if (zone == "EET,EET" ) {  zone = "EET"; }
   else if (zone == "EET,EEST") {}

   else if (zone == "CET"     ) {} // Europe/Berlin      GMT+0100[,GMT+0200]
   else if (zone == "CET,CET" ) {  zone = "CET"; }
   else if (zone == "CET,CEST") {}

   else if (zone == "GMT"     ) {} // GMT                GMT+0000[,GMT+0100]
   else if (zone == "GMT,GMT" ) {  zone = "GMT"; }
   else if (zone == "GMT,BST" ) {}

   else if (zone == "EST"     ) {} // America/New_York   GMT-0500[,GMT-0400]
   else if (zone == "EST,EST" ) {  zone = "EST"; }
   else if (zone == "EST,EDT" ) {}

   else {
      catch("GetServerTimezone(3)  unknown timezone configuration for account "+ account +": \""+ configValue +"\"", ERR_RUNTIME_ERROR);
      return("");
   }

   if (catch("GetServerTimezone(4)") != NO_ERROR)
      return("");

   return(zone);
}


/**
 * Gibt den Offset der angegebenen Serverzeit zu New Yorker Zeit (Eastern Time) zurück.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetServerToEasternTimeOffset(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerToEasternTimeOffset(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   string zone = GetServerTimezone();
   if (zone == "")
      return(EMPTY_VALUE);

   // schnelle Rückkehr, wenn der Tradeserver unter Eastern Time läuft
   if (zone == "EST,EDT")
      return(0);

   // Offset Server zu GMT
   int serverToGmtOffset;
   if (zone != "GMT")
      serverToGmtOffset = GetServerToGmtOffset(serverTime);

   // Offset GMT zu Eastern Time
   int gmtToEasternTimeOffset = GetGmtToEasternTimeOffset(serverTime - serverToGmtOffset);

   if (catch("GetServerToEasternTimeOffset(2)") != NO_ERROR)
      return(EMPTY_VALUE);

   return(serverToGmtOffset + gmtToEasternTimeOffset);
}


/**
 * Gibt den Offset der angegebenen Serverzeit zu GMT (Greenwich Mean Time) zurück.
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return int - Offset in Sekunden oder EMPTY_VALUE, falls ein Fehler auftrat
 */
int GetServerToGmtOffset(datetime serverTime) {
   if (serverTime < 1) {
      catch("GetServerToGmtOffset(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   string zone = GetServerTimezone();
   if (zone == "")
      return(EMPTY_VALUE);
   int offset, year = TimeYear(serverTime)-1970;

   // Europe/Kiev                                      GMT+0200[,GMT+0300]
   if      (zone == "EET"     )                        offset = 2 * HOURS;
   else if (zone == "EET,EEST") {
      if      (serverTime < EEST_transitions[year][0]) offset = 2 * HOURS;
      else if (serverTime < EEST_transitions[year][1]) offset = 3 * HOURS;
      else                                             offset = 2 * HOURS;
   }

   // Europe/Berlin                                    GMT+0100[,GMT+0200]
   else if (zone == "CET"     )                        offset = 1 * HOUR;
   else if (zone == "CET,CEST") {
      if      (serverTime < CEST_transitions[year][0]) offset = 1 * HOURS;
      else if (serverTime < CEST_transitions[year][1]) offset = 2 * HOURS;
      else                                             offset = 1 * HOURS;
   }

   // GMT                                              GMT+0000
   else if (zone == "GMT"    )                         offset = 0;

   // Europe/London                                    GMT+0000[,GMT+0100]
   else if (zone == "GMT,BST") {
      if      (serverTime < BST_transitions[year][0])  offset = 0;
      else if (serverTime < BST_transitions[year][1])  offset = 1 * HOUR;
      else                                             offset = 0;
   }

   // America/New_York                                 GMT-0500[,GMT-0400]
   else if (zone == "EST"    )                         offset = -5 * HOURS;
   else if (zone == "EST,EDT") {
      if      (serverTime < EDT_transitions[year][0])  offset = -5 * HOURS;
      else if (serverTime < EDT_transitions[year][1])  offset = -4 * HOURS;
      else                                             offset = -5 * HOURS;
   }

   else {
      catch("GetServerToGmtOffset(2)  unknown timezone for account "+ GetAccountNumber() +": \""+ zone +"\"", ERR_RUNTIME_ERROR);
      return(EMPTY_VALUE);
   }

   if (catch("GetServerToGmtOffset(3)") != NO_ERROR)
      return(EMPTY_VALUE);

   return(offset);
}


int hWndTerminal;

/**
 * Gibt das Handle des Hauptfensters des MetaTrader-Terminals zurück.
 *
 * @return int - Handle oder 0, falls ein Fehler auftrat
 */
int GetTerminalWindow() {
   if (hWndTerminal == 0) {
      int hWndChild, hWndParent=WindowHandle(Symbol(), Period());

      while (hWndParent != 0) {
         hWndChild  = hWndParent;
         hWndParent = GetParent(hWndChild);
      }
      hWndTerminal = hWndChild;

      if (catch("GetTerminalWindow()") != NO_ERROR)
         return(0);
   }

   return(hWndTerminal);
}


/**
 * Gibt die lesbare Version eines UninitializeReason-Codes zurück (siehe UninitializeReason()).
 *
 * @param  int reason - Code
 *
 * @return string
 */
string UninitializeReasonToStr(int reason) {
   switch (reason) {
      case REASON_FINISHED   : return("execution finished "                   );
      case REASON_REMOVE     : return("expert or indicator removed from chart");
      case REASON_RECOMPILE  : return("expert or indicator recompiled"        );
      case REASON_CHARTCHANGE: return("symbol or timeframe changed"           );
      case REASON_CHARTCLOSE : return("chart closed"                          );
      case REASON_PARAMETERS : return("input parameters changed"              );
      case REASON_ACCOUNT    : return("account changed"                       );
   }

   catch("UninitializeReasonToStr()  invalid parameter reason: "+ reason, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt den Text der Titelbar des angegebenen Fensters zurück (wenn es einen hat).  Ist das angegebene Fenster ein Windows-Control,
 * wird dessen Text zurückgegeben.
 *
 * @param  int hWnd - Handle des Fensters oder Controls
 *
 * @return string - Text
 */
string GetWindowText(int hWnd) {
   string buffer[1]; buffer[0] = StringConcatenate(MAX_STRING_LITERAL, "");      // siehe MetaTrader.doc: Zeigerproblematik

   GetWindowTextA(hWnd, buffer[0], MAX_STRING_LITERAL_LEN);

   if (catch("GetWindowText()") != NO_ERROR)
      return("");
   return(buffer[0]);
}


/**
 * Konvertiert die angegebene GMT-Zeit (UTC) nach Eastern Time (New Yorker Zeit).
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder -1, falls ein Fehler auftrat
 */
datetime GmtToEasternTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GmtToEasternTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   int gmtToEasternTimeOffset = GetGmtToEasternTimeOffset(gmtTime);  // Offset von GMT zu New Yorker Zeit
   if (gmtToEasternTimeOffset == EMPTY_VALUE)
      return(-1);

   datetime easternTime = gmtTime - gmtToEasternTimeOffset;

   //Print("GmtToEasternTime()    GMT: "+ TimeToStr(gmtTime) +"     ET offset: "+ (gmtToEasternTimeOffset/HOURS) +"     ET: "+ TimeToStr(easternTime));

   if (catch("GmtToEasternTime(2)") != NO_ERROR)
      return(-1);
   return(easternTime);
}


/**
 * Konvertiert die angegebene GMT-Zeit (UTC) nach Tradeserver-Zeit.
 *
 * @param  datetime gmtTime - GMT-Zeitpunkt
 *
 * @return datetime - Tradeserver-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime GmtToServerTime(datetime gmtTime) {
   if (gmtTime < 1) {
      catch("GmtToServerTime(1)  invalid parameter gmtTime: "+ gmtTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   // schnelle Rückkehr, wenn der Tradeserver unter GMT läuft
   if (GetServerTimezone() == "GMT")
      return(gmtTime);

   int gmtToServerTimeOffset = GetGmtToServerTimeOffset(gmtTime);
   if (gmtToServerTimeOffset == EMPTY_VALUE)
      return(-1);

   datetime serverTime = gmtTime - gmtToServerTimeOffset;

   //Print("GmtToServerTime()    GMT: "+ TimeToStr(gmtTime) +"     server offset: "+ (gmtToServerTimeOffset/HOURS) +"     server: "+ TimeToStr(serverTime));

   if (catch("GmtToServerTime(2)") != NO_ERROR)
      return(-1);
   return(serverTime);
}


/**
 * Berechnet den Balancewert eines Accounts am angegebenen Offset des aktuellen Charts und schreibt ihn in das Ergebnisarray.
 *
 * @param  int     account  - Account, für den der Wert berechnet werden soll
 * @param  double& lpBuffer - Zeiger auf Ergebnisarray (kann Indikatorpuffer sein)
 * @param  int     bar      - Barindex des zu berechnenden Wertes (Chart-Offset)
 *
 * @return int - Fehlerstatus
 */
int iBalance(int account, double& lpBuffer[], int bar) {
   // TODO: iBalance(int account, double& lpBuffer, int bar) implementieren

   // zur Zeit wird der Indikator hier noch komplett neuberechnet
   if (iBalanceSeries(account, lpBuffer) == ERR_HISTORY_UPDATE) {
      catch("iBalance(1)");
      return(ERR_HISTORY_UPDATE);
   }

   return(catch("iBalance(2)"));
}


/**
 * Berechnet den Balanceverlauf eines Accounts für alle Bars des aktuellen Charts und schreibt die Werte in das angegebene Zielarray.
 *
 * @param  int     account  - Account-Nummer
 * @param  double& lpBuffer - Zeiger auf Ergebnisarray (kann Indikatorpuffer sein)
 *
 * @return int - Fehlerstatus
 */
int iBalanceSeries(int account, double& lpBuffer[]) {
   if (ArrayRange(lpBuffer, 0) != Bars) {
      ArrayResize(lpBuffer, Bars);
      ArrayInitialize(lpBuffer, EMPTY_VALUE);
   }

   // Balance-History holen
   datetime times[];  ArrayResize(times , 0);
   double   values[]; ArrayResize(values, 0);

   int error = GetBalanceHistory(account, times, values);   // aufsteigend nach Zeit sortiert (times[0], values[0] sind älteste Werte)
   if (error != NO_ERROR) {
      catch("iBalanceSeries(1)");
      return(error);
   }

   int bar, lastBar, historySize=ArraySize(values);

   // Balancewerte für Bars des aktuellen Charts ermitteln und ins Ergebnisarray schreiben
   for (int i=0; i < historySize; i++) {
      // Barindex des Zeitpunkts berechnen
      bar = iBarShiftNext(NULL, 0, times[i]);
      if (bar == EMPTY_VALUE)                               // ERR_HISTORY_UPDATE ?
         return(stdlib_GetLastError());
      if (bar == -1)                                        // dieser und alle folgenden Werte sind zu neu für den Chart
         break;

      // Lücken mit vorherigem Balancewert füllen
      if (bar < lastBar-1) {
         for (int z=lastBar-1; z > bar; z--) {
            lpBuffer[z] = lpBuffer[lastBar];
         }
      }

      // aktuellen Balancewert eintragen
      lpBuffer[bar] = values[i];
      lastBar = bar;
   }

   // Ergebnisarray bis zur ersten Bar mit dem letzten bekannten Balancewert füllen
   for (bar=lastBar-1; bar >= 0; bar--) {
      lpBuffer[bar] = lpBuffer[lastBar];
   }

   return(catch("iBalanceSeries(2)"));
}


/**
 * Ermittelt den Chart-Offset (Bar) eines Zeitpunktes und gibt bei nicht existierender Bar die letzte vorherige existierende Bar zurück.
 *
 * @param  string   symbol - Symbol der zu verwendenden Datenreihe (default: NULL = aktuelles Symbol)
 * @param  int      period - Periode der zu verwendenden Datenreihe (default: 0 = aktuelle Periode)
 * @param  datetime time   - Zeitpunkt
 *
 * @return int - Bar-Index oder -1, wenn keine entsprechende Bar existiert (Zeitpunkt ist zu alt für den Chart);
 *               EMPTY_VALUE, wenn ein Fehler aufgetreten ist
 *
 * NOTE:    Kann ERR_HISTORY_UPDATE auslösen.
 * ----
 */
int iBarShiftPrevious(string symbol/*=NULL*/, int period/*=0*/, datetime time) {
   if (symbol == "0")                                       // NULL ist ein Integer (0)
      symbol = Symbol();

   if (time < 1) {
      catch("iBarShiftPrevious(1)  invalid parameter time: "+ time, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   // Datenreihe holen
   datetime times[];
   int bars  = ArrayCopySeries(times, MODE_TIME, symbol, period);
   int error = GetLastError();                              // ERR_HISTORY_UPDATE ???

   if (error == NO_ERROR) {
      // Bars überprüfen
      if (time < times[bars-1]) {
         int bar = -1;                                      // Zeitpunkt ist zu alt für den Chart
      }
      else {
         bar   = iBarShift(symbol, period, time);
         error = GetLastError();                            // ERR_HISTORY_UPDATE ???
      }
   }

   if (error != NO_ERROR) {
      last_error = error;
      if (error != ERR_HISTORY_UPDATE)
         catch("iBarShiftPrevious(2)", error);
      return(EMPTY_VALUE);
   }
   return(bar);
}


/**
 * Ermittelt den Chart-Offset (Bar) eines Zeitpunktes und gibt bei nicht existierender Bar die nächste existierende Bar zurück.
 *
 * @param  string   symbol - Symbol der zu verwendenden Datenreihe (default: NULL = aktuelles Symbol)
 * @param  int      period - Periode der zu verwendenden Datenreihe (default: 0 = aktuelle Periode)
 * @param  datetime time   - Zeitpunkt
 *
 * @return int - Bar-Index oder -1, wenn keine entsprechende Bar existiert (Zeitpunkt ist zu jung für den Chart);
 *               EMPTY_VALUE, wenn ein Fehler aufgetreten ist
 *
 * NOTE:    Kann ERR_HISTORY_UPDATE auslösen.
 * ----
 */
int iBarShiftNext(string symbol/*=NULL*/, int period/*=0*/, datetime time) {
   if (symbol == "0")                                       // NULL ist ein Integer (0)
      symbol = Symbol();

   if (time < 1) {
      catch("iBarShiftNext(1)  invalid parameter time: "+ time, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(EMPTY_VALUE);
   }

   int bar   = iBarShift(symbol, period, time, true);
   int error = GetLastError();                              // ERR_HISTORY_UPDATE ???

   if (error==NO_ERROR) if (bar==-1) {                      // falls die Bar nicht existiert und auch kein Update läuft
      // Datenreihe holen
      datetime times[];
      int bars = ArrayCopySeries(times, MODE_TIME, symbol, period);
      error = GetLastError();                               // ERR_HISTORY_UPDATE ???

      if (error == NO_ERROR) {
         // Bars überprüfen
         if (time < times[bars-1])                          // Zeitpunkt ist zu alt für den Chart, die älteste Bar zurückgeben
            bar = bars-1;

         else if (time < times[0]) {                        // Kurslücke, die nächste existierende Bar zurückgeben
            bar   = iBarShift(symbol, period, time) - 1;
            error = GetLastError();                         // ERR_HISTORY_UPDATE ???
         }
         //else: (time > times[0]) => bar=-1                // Zeitpunkt ist zu neu für den Chart, bar bleibt -1
      }
   }

   if (error != NO_ERROR) {
      last_error = error;
      if (error != ERR_HISTORY_UPDATE)
         catch("iBarShiftNext(2)", error);
      return(EMPTY_VALUE);
   }
   return(bar);
}


/**
 * Gibt die nächstgrößere Periode der angegebenen Periode zurück.
 *
 * @param  int period - Timeframe-Periode (default: 0 - die aktuelle Periode)
 *
 * @return int - Nächstgrößere Periode oder der ursprüngliche Wert, wenn keine größere Periode existiert.
 */
int IncreasePeriod(int period = 0) {
   if (period == 0)
      period = Period();

   switch (period) {
      case PERIOD_M1 : return(PERIOD_M5 );
      case PERIOD_M5 : return(PERIOD_M15);
      case PERIOD_M15: return(PERIOD_M30);
      case PERIOD_M30: return(PERIOD_H1 );
      case PERIOD_H1 : return(PERIOD_H4 );
      case PERIOD_H4 : return(PERIOD_D1 );
      case PERIOD_D1 : return(PERIOD_W1 );
      case PERIOD_W1 : return(PERIOD_MN1);
      case PERIOD_MN1: return(PERIOD_MN1);
   }

   catch("IncreasePeriod()  invalid parameter period: "+ period, ERR_INVALID_FUNCTION_PARAMVALUE);
   return(0);
}


/**
 * Verbindet die Werte eines Boolean-Arrays unter Verwendung des angegebenen Separators.
 *
 * @param  bool   values[]  - Array mit Ausgangswerten
 * @param  string separator - zu verwendender Separator
 *
 * @return string
 */
string JoinBools(bool values[], string separator) {
   string strings[];

   int size = ArraySize(values);
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      if (values[i]) strings[i] = "true";
      else           strings[i] = "false";
   }

   return(JoinStrings(strings, separator));
}


/**
 * Verbindet die Werte eines Double-Arrays unter Verwendung des angegebenen Separators.
 *
 * @param  double values[]  - Array mit Ausgangswerten
 * @param  string separator - zu verwendender Separator
 *
 * @return string
 */
string JoinDoubles(double values[], string separator) {
   string strings[];

   int size = ArraySize(values);
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = FormatNumber(values[i], ".1+");
   }

   return(JoinStrings(strings, separator));
}


/**
 * Verbindet die Werte eines Integer-Arrays unter Verwendung des angegebenen Separators.
 *
 * @param  int    values[]  - Array mit Ausgangswerten
 * @param  string separator - zu verwendender Separator
 *
 * @return string
 */
string JoinInts(int values[], string separator) {
   string strings[];

   int size = ArraySize(values);
   ArrayResize(strings, size);

   for (int i=0; i < size; i++) {
      strings[i] = values[i];
   }

   return(JoinStrings(strings, separator));
}


/**
 * Verbindet die Werte eines Stringarrays unter Verwendung des angegebenen Separators.
 *
 * @param  string values[]  - Array mit Ausgangswerten
 * @param  string separator - zu verwendender Separator
 *
 * @return string
 */
string JoinStrings(string values[], string separator) {
   string result = "";

   int size = ArraySize(values);

   for (int i=1; i < size; i++) {
      result = StringConcatenate(result, separator, values[i]);
   }
   if (size > 0) {
      result = StringConcatenate(values[0], result);
   }

   if (catch("JoinStrings()") != NO_ERROR)
      return("");
   return(result);
}


/**
 *
 *
abstract*/ int onBarOpen(int details[]) {
   return(catch("onBarOpen()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 *
 *
abstract*/ int onOrderPlace(int details[]) {
   return(catch("onOrderPlace()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 *
 *
abstract*/ int onOrderChange(int details[]) {
   return(catch("onOrderChange()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 *
 *
abstract*/ int onOrderCancel(int details[]) {
   return(catch("onOrderCancel()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Handler für PositionOpen-Events.
 *
 * @param  int tickets[] - Tickets der neuen Positionen
 *
 * @return int - Fehlerstatus
 *
abstract*/ int onPositionOpen(int tickets[]) {
   return(catch("onPositionOpen()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 *
 *
abstract*/ int onPositionClose(int details[]) {
   return(catch("onPositionClose()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 *
 *
abstract*/ int onAccountChange(int details[]) {
   return(catch("onAccountChange()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 *
 *
abstract*/ int onAccountPayment(int details[]) {
   return(catch("onAccountPayment()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 *
 *
abstract*/ int onHistoryChange(int details[]) {
   return(catch("onHistoryChange()   implementation not found", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Fügt das angegebene Objektlabel den bereits gespeicherten Labels hinzu.
 *
 * @param  string  label       - zu speicherndes Label
 * @param  string& lpObjects[] - Array mit bereits gespeicherten Labels
 *
 * @return int - Fehlerstatus
 */
int RegisterChartObject(string label, string& lpObjects[]) {
   int size = ArraySize(lpObjects);
   ArrayResize(lpObjects, size+1);
   lpObjects[size] = label;
   return(0);
}


/**
 * Entfernt die Objekte mit den angegebenen Labels aus dem aktuellen Chart.
 *
 * @param  string& lpLabels[] - Array mit Objektlabels
 *
 * @return int - Fehlerstatus
 */
int RemoveChartObjects(string& lpLabels[]) {
   int size = ArraySize(lpLabels);
   if (size == 0)
      return(0);

   for (int i=0; i < size; i++) {
      ObjectDelete(lpLabels[i]);
   }
   ArrayResize(lpLabels, 0);

   int error = GetLastError();
   if (error == ERR_OBJECT_DOES_NOT_EXIST)
      return(NO_ERROR);
   return(catch("RemoveChartObjects()", error));
}


/**
 * Verschickt eine SMS-Nachricht an eine Mobilfunknummer.
 *
 * @param  string receiver - Mobilfunknummer des Empfängers im internationalen Format (49123456789)
 * @param  string message  - zu verschickende Nachricht
 *
 * @return int - Fehlerstatus
 */
int SendTextMessage(string receiver, string message) {
   if (!StringIsDigit(receiver))
      return(catch("SendTextMessage(1)   invalid parameter receiver: "+ receiver, ERR_INVALID_FUNCTION_PARAMVALUE));

   // TODO: Gateway-Zugangsdaten auslagern

   message = UrlEncode(message);
   string url = StringConcatenate("https://api.clickatell.com/http/sendmsg?user={user}&password={password}&api_id={id}&to=", receiver, "&text=", message);

   /*
   string targetDir  = TerminalPath() +"\\experts\\files\\";
   string targetFile = "sms.txt";
   string logFile    = "sms.log";
   string lpCmdLine  = "wget.exe -b --no-check-certificate \""+url+"\" -O \""+targetDir+targetFile+"\" -a \""+targetDir+logFile+"\"";
   */
   string lpCmdLine  = StringConcatenate("wget.exe -b --no-check-certificate \"", url, "\"");

   int error = WinExec(lpCmdLine, SW_HIDE);     // SW_SHOWNORMAL|SW_HIDE
   if (error < 32)
      return(catch("SendTextMessage(1)  execution of \""+ lpCmdLine +"\" failed with error="+ error +" ("+ ShellExecuteErrorToStr(error) +")", ERR_WINDOWS_ERROR));

   return(catch("SendTextMessage(2)"));
}


/**
 * Konvertiert die angegebene Tradeserver-Zeit nach Eastern Time (New Yorker Zeit).
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - Zeitpunkt New Yorker Zeit oder -1, falls ein Fehler auftrat
 */
datetime ServerToEasternTime(datetime serverTime) {
   if (serverTime < 1) {
      catch("ServerToEasternTime(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   // schnelle Rückkehr, wenn der Tradeserver unter Eastern Time läuft
   if (GetServerTimezone() == "EST,EDT")
      return(serverTime);

   datetime gmtTime = ServerToGMT(serverTime);
   if (gmtTime == -1)
      return(-1);

   datetime easternTime = GmtToEasternTime(gmtTime);
   if (easternTime == -1)
      return(-1);

   //Print("ServerToEasternTime()    server: "+ TimeToStr(serverTime) +"     GMT: "+ TimeToStr(gmtTime) +"     ET: "+ TimeToStr(easternTime));

   if (catch("ServerToEasternTime(2)") != NO_ERROR)
      return(-1);
   return(easternTime);
}


/**
 * Konvertiert die angegebene Tradeserver-Zeit nach GMT (UTC).
 *
 * @param  datetime serverTime - Tradeserver-Zeitpunkt
 *
 * @return datetime - GMT-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime ServerToGMT(datetime serverTime) {
   if (serverTime < 1) {
      catch("ServerToGMT(1)  invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   // schnelle Rückkehr, wenn der Tradeserver unter GMT läuft
   if (GetServerTimezone() == "GMT")
      return(serverTime);

   int serverToGmtOffset = GetServerToGmtOffset(serverTime);
   if (serverToGmtOffset == EMPTY_VALUE)
      return(-1);

   datetime gmtTime = serverTime - serverToGmtOffset;
   if (gmtTime < 0) {
      catch("ServerToGMT(2)   invalid parameter serverTime: "+ serverTime, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   //Print("ServerToGMT()    server: "+ TimeToStr(serverTime) +"     GMT offset: "+ (serverToGmtOffset/HOURS) +"     GMT: "+ TimeToStr(gmtTime));

   if (catch("ServerToGMT(3)") != NO_ERROR)
      return(-1);
   return(gmtTime);
}


/**
 * Setzt den Text der Titelbar des angegebenen Fensters (wenn es eine hat). Ist das agegebene Fenster ein Control, wird dessen Text geändert.
 *
 * @param  int    hWnd - Handle des Fensters
 * @param  string text - Text
 *
 * @return int - Fehlerstatus
 */
int SetWindowText(int hWnd, string text) {
   if (!SetWindowTextA(hWnd, text))
      return(catch("SetWindowText()   user32.SetWindowText(hWnd="+ hWnd +", lpString=\""+ text +"\") => FALSE", ERR_WINDOWS_ERROR));

   return(0);
}


/**
 * Prüft, ob ein String einen Substring enthält.  Groß-/Kleinschreibung wird beachtet.
 *
 * @param  string object    - zu durchsuchender String
 * @param  string substring - zu suchender Substring
 *
 * @return bool
 */
bool StringContains(string object, string substring) {
   return(StringFind(object, substring) != -1);
}


/**
 * Prüft, ob ein String einen Substring enthält.  Groß-/Kleinschreibung wird nicht beachtet.
 *
 * @param  string object    - zu durchsuchender String
 * @param  string substring - zu suchender Substring
 *
 * @return bool
 */
bool StringIContains(string object, string substring) {
   object    = StringToUpper(object);
   substring = StringToUpper(substring);
   return(StringFind(object, substring) != -1);
}


/**
 * Vergleicht zwei Strings ohne Berücksichtigung der Groß-/Kleinschreibung.
 *
 * @param  string string1
 * @param  string string2
 *
 * @return bool
 */
bool StringICompare(string string1, string string2) {
   return(StringToUpper(string1) == StringToUpper(string2));
}


/**
 * Prüft, ob ein String nur numerische Zeichen enthält.
 *
 * @param  string value - zu prüfender String
 *
 * @return bool
 */
bool StringIsDigit(string value) {
   int len = StringLen(value);

   if (len == 0)
      return(false);

   for (int i=0; i < len; i++) {
      int char = StringGetChar(value, i);
      if (char < '0') return(false);
      if (char > '9') return(false);    // Conditions für MQL optimiert
   }

   return(true);
}


/**
 * Durchsucht einen String vom Ende aus nach einem Substring und gibt dessen Position zurück.
 *
 * @param  string object - zu durchsuchender String
 * @param  string search - zu suchender Substring
 *
 * @return int - letzte Position des Substrings oder -1, wenn der Substring nicht gefunden wurde
 */
int StringFindR(string object, string search) {
   int lenObject = StringLen(object),
       lastFound  = -1,
       result     =  0;

   for (int i=0; i < lenObject; i++) {
      result = StringFind(object, search, i);
      if (result == -1)
         break;
      lastFound = result;
   }

   if (catch("StringFindR()") != NO_ERROR)
      return(-1);
   return(lastFound);
}


/**
 * Konvertiert einen String in Kleinschreibweise.
 *
 * @param  string value
 *
 * @return string
 */
string StringToLower(string value) {
   string result = value;
   int char, len = StringLen(value);

   for (int i=0; i < len; i++) {
      char = StringGetChar(value, i);
      //logische Version
      //if      (64 < char && char < 91)              result = StringSetChar(result, i, char+32);
      //else if (char==138 || char==140 || char==142) result = StringSetChar(result, i, char+16);
      //else if (char==159)                           result = StringSetChar(result, i,     255);  // Ÿ -> ÿ
      //else if (191 < char && char < 223)            result = StringSetChar(result, i, char+32);

      // für MQL optimierte Version
      if      (char == 138)                 result = StringSetChar(result, i, char+16);
      else if (char == 140)                 result = StringSetChar(result, i, char+16);
      else if (char == 142)                 result = StringSetChar(result, i, char+16);
      else if (char == 159)                 result = StringSetChar(result, i,     255);   // Ÿ -> ÿ
      else if (char < 91) { if (char >  64) result = StringSetChar(result, i, char+32); }
      else if (191 < char)  if (char < 223) result = StringSetChar(result, i, char+32);
   }

   if (catch("StringToLower()") != NO_ERROR)
      return("");
   return(result);
}


/**
 * Konvertiert einen String in Großschreibweise.
 *
 * @param  string value
 *
 * @return string
 */
string StringToUpper(string value) {
   string result = value;
   int char, len = StringLen(value);

   for (int i=0; i < len; i++) {
      char = StringGetChar(value, i);
      //logische Version
      //if      (96 < char && char < 123)             result = StringSetChar(result, i, char-32);
      //else if (char==154 || char==156 || char==158) result = StringSetChar(result, i, char-16);
      //else if (char==255)                           result = StringSetChar(result, i,     159);  // ÿ -> Ÿ
      //else if (char > 223)                          result = StringSetChar(result, i, char-32);

      // für MQL optimierte Version
      if      (char == 255)                 result = StringSetChar(result, i,     159);   // ÿ -> Ÿ
      else if (char  > 223)                 result = StringSetChar(result, i, char-32);
      else if (char == 158)                 result = StringSetChar(result, i, char-16);
      else if (char == 156)                 result = StringSetChar(result, i, char-16);
      else if (char == 154)                 result = StringSetChar(result, i, char-16);
      else if (char  >  96) if (char < 123) result = StringSetChar(result, i, char-32);
   }

   if (catch("StringToUpper()") != NO_ERROR)
      return("");
   return(result);
}


/**
 * Trimmt einen String beidseitig.
 *
 * @param  string value
 *
 * @return string
 */
string StringTrim(string value) {
   return(StringTrimLeft(StringTrimRight(value)));
}


/**
 * URL-kodiert einen String.  Leerzeichen werden als "+"-Zeichen kodiert.
 *
 * @param  string value
 *
 * @return string - URL-kodierter String
 */
string UrlEncode(string value) {
   int char, len=StringLen(value);
   string charStr, result="";

   for (int i=0; i < len; i++) {
      charStr = StringSubstr(value, i, 1);
      char    = StringGetChar(charStr, 0);

      if ((47 < char && char < 58) || (64 < char && char < 91) || (96 < char && char < 123))
         result = StringConcatenate(result, charStr);
      else if (char == 32)
         result = StringConcatenate(result, "+");
      else
         result = StringConcatenate(result, "%", DecimalToHex(char));
   }

   if (catch("UrlEncode()") != NO_ERROR)
      return("");
   return(result);
}


/**
 * Alias für IntToHexStr()
 *
 * Konvertiert einen Integer in seine hexadezimale Representation.
 */
string IntegerToHexStr(int integer) {
   return(IntToHexStr(integer));
}


/**
 * Prüft, ob der angegebene Name eine existierende und normale Datei ist (kein Verzeichnis).
 *
 * @return string pathName - Pfadangabe
 *
 * @return bool
 */
bool IsFile(string pathName) {
   bool result = false;

   if (StringLen(pathName) > 0) {
      int /*WIN32_FIND_DATA*/ wfd[80];

      int hSearch = FindFirstFileA(pathName, wfd);

      if (hSearch != INVALID_HANDLE_VALUE) {
         FindClose(hSearch);
         result = !wfd.FileAttribute.Directory(wfd);
      }
   }

   catch("IsFile()");
   return(result);
}


/**
 * Prüft, ob der angegebene Name ein existierendes Verzeichnis ist (keine normale Datei).
 *
 * @return string pathName - Pfadangabe
 *
 * @return bool
 */
bool IsDir(string pathName) {
   bool result = false;

   if (StringLen(pathName) > 0) {
      int /*WIN32_FIND_DATA*/ wfd[80];

      int hSearch = FindFirstFileA(pathName, wfd);

      if (hSearch != INVALID_HANDLE_VALUE) {
         FindClose(hSearch);
         result = wfd.FileAttribute.Directory(wfd);
      }
   }

   catch("IsDir()");
   return(result);
}


/**
 * Konvertiert einen Integer in seine hexadezimale Representation.
 *
 * @param  string value
 *
 * @return string
 *
 * Beispiel: IntToHexStr(2026701066) => "78CD010A"
 */
string IntToHexStr(int integer) {
   string result = "00000000";
   int value, shift = 28;

   for (int i=0; i < 8; i++) {
      value = (integer >> shift) & 0x0F;
      if (value < 10) result = StringSetChar(result, i,  value     +'0');  // 0x30 = '0'        // Integer in Nibbles zerlegen und jedes
      else            result = StringSetChar(result, i, (value-10) +'A');  // 0x41 = 'A'        // einzelne Nibble hexadezimal darstellen
      shift -= 4;
   }
   return(result);
}


// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! //
// Original-MetaQuotes Funktionen             !!! NICHT VERWENDEN !!!                 //
//                                                                                    //
// Diese Funktionen stehen hier nur zur Dokumentation. Sie sind teilweise fehlerhaft. //
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! //


/**
 * convert red, green and blue values to color
 */
int RGB(int red, int green, int blue) {
   if (red   <   0) red   =   0;
   if (red   > 255) red   = 255;
   if (green <   0) green =   0;
   if (green > 255) green = 255;
   if (blue  <   0) blue  =   0;
   if (blue  > 255) blue  = 255;

   green <<=  8;
   blue  <<= 16;

   return (red + green + blue);
}


/**
 * up to 16 digits after decimal point
 */
string DoubleToStrMorePrecision(double number, int precision) {
   double rem, integer, integer2;
   /*
   Der Compiler interpretiert über mehrere Zeilen verteilte Array-Initializer als in einer Zeile stehend und gibt bei Fehlern falsche Zeilennummern zurück.
   double DecimalArray[17] = { 1.0,
                              10.0,
                             100.0,
                            1000.0,
                           10000.0,
                          100000.0,
                         1000000.0,
                        10000000.0,
                       100000000.0,
                      1000000000.0,
                     10000000000.0,
                    100000000000.0,
                   1000000000000.0,
                  10000000000000.0,
                 100000000000000.0,
                1000000000000000.0,
               10000000000000000.0 };
   */
   double DecimalArray[17] = { 1.0, 10.0, 100.0, 1000.0, 10000.0, 100000.0, 1000000.0, 10000000.0, 100000000.0, 1000000000.0, 10000000000.0, 100000000000.0, 1000000000000.0, 10000000000000.0, 100000000000000.0, 1000000000000000.0, 10000000000000000.0 };

   string intstring, remstring, retstring;
   bool   isnegative = false;
   int    rem2;

   if (precision <  0) precision =  0;
   if (precision > 16) precision = 16;

   double p = DecimalArray[precision];
   if (number < 0.0) {
      isnegative = true;
      number = -number;
   }

   integer = MathFloor(number);
   rem = MathRound((number-integer) * p);
   remstring = "";

   for (int i=0; i<precision; i++) {
      integer2 = MathFloor(rem/10);
      rem2 = NormalizeDouble(rem-integer2 * 10, 0);
      remstring = rem2 + remstring;
      rem = integer2;
   }

   intstring = DoubleToStr(integer, 0);

   if (isnegative) retstring = "-"+ intstring;
   else            retstring = intstring;

   if (precision > 0)
      retstring = retstring +"."+ remstring;

   return(retstring);
}



// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! //
//                                                                                    //
// MQL Utility Funktionen                                                             //
//                                                                                    //
// @see http://www.forexfactory.com/showthread.php?p=2695655                          //
//                                                                                    //
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! //


/**
 * Returns a numeric value rounded to the specified number of decimals - works around a precision bug in MQL4.
 *
 * @param  double number
 * @param  int    decimals
 *
 * @return double - rounded value
 */
double MathRoundFix(double number, int decimals) {
   // TODO: Verarbeitung negativer decimals prüfen

   double operand = MathPow(10, decimals);
   return(MathRound(number*operand + MathSign(number)*0.000000000001) / operand);
}


/**
 * Returns the sign of a number.
 *
 * @param  double number
 *
 * @return int - sign (-1, 0, +1)
 */
int MathSign(double number) {
   if      (number > 0) return( 1);
   else if (number < 0) return(-1);
   return(0);
}


/**
 * Repeats a string.
 *
 * @param  string input - The string to be repeated.
 * @param  int    times - Number of times the input string should be repeated.
 *
 * @return string - the repeated string
 */
string StringRepeat(string input, int times) {
   if (times < 0) {
      catch("StringRepeat()  invalid parameter times: "+ times, ERR_INVALID_FUNCTION_PARAMVALUE);
      return("");
   }

   if (StringLen(input) == 0) return("");
   if (times ==  0)           return("");

   string output = input;
   for (int i=1; i < times; i++) {
      output = StringConcatenate(output, input);
   }
   return(output);
}


/**
 * Alias für NumberToStr().
 */
string FormatNumber(double number, string mask) {
   return(NumberToStr(number, mask));
}


/**
 * Formatiert einen numerischen Wert im angegebenen Format und gibt den resultierneden String zurück.
 * The basic mask is "n" or "n.d" where n is the number of digits to the left and d is the number of digits to the right of the decimal point.
 *
 * Mask parameters:
 *
 *   n        = number of digits to the left of the decimal point, e.g. FormatNumber(123.456, "5") => "123"
 *   n.d      = number of left and right digits, e.g. FormatNumber(123.456, "5.2") => "123.45"
 *   n.       = number of left and all right digits, e.g. FormatNumber(123.456, "2.") => "23.456"
 *    .d      = all left and number of right digits, e.g. FormatNumber(123.456, ".2") => "123.45"
 *    .d'     = all left and number of right digits plus 1 additional subpip digit, e.g. FormatNumber(123.45678, ".4'") => "123.4567'8"
 *    .d+     = + anywhere right of .d in mask: all left and minimum number of right digits, e.g. FormatNumber(123.456, ".2+") => "123.456"
 *  +n.d      = + anywhere left of n. in mask: plus sign for positive values
 *    R       = round result in the last displayed digit, e.g. FormatNumber(123.456, "R3.2") => "123.46", e.g. FormatNumber(123.7, "R3") => "124"
 *    ;       = Separatoren tauschen (Europäisches Format), e.g. FormatNumber(123456.789, "6.2;") => "123456,78"
 *    ,       = Tausender-Separatoren einfügen, e.g. FormatNumber(123456.789, "6.2,") => "123,456.78"
 *              ein dem Komma folgendes Zeichen wird als User-spezifischer Separator interpretiert, siehe ,<char>
 *    ,<char> = Tausender-Separator auf <char> setzen, e.g. FormatNumber(123456.789, ", 6.2") => "123 456.78",
 *
 * @param  double number
 * @param  string mask
 *
 * @return string - formatierter String
 */
string NumberToStr(double number, string mask) {
   if (number == EMPTY_VALUE)
      number = 0;

   // === Beginn Maske parsen ===
   int maskLen = StringLen(mask);

   // zu allererst Separatorenformat erkennen
   bool swapSeparators = (StringFind(mask, ";")  > -1);
      string sepThousand=",", sepDecimal=".";
      if (swapSeparators) {
         sepThousand = ".";
         sepDecimal  = ",";
      }
      int sepPos = StringFind(mask, ",");
   bool separators = (sepPos  > -1);
      if (separators) if (sepPos+1 < maskLen) {
         sepThousand = StringSubstr(mask, sepPos+1, 1);  // user-spezifischen 1000-Separator auslesen und aus Maske löschen
         mask        = StringConcatenate(StringSubstr(mask, 0, sepPos+1), StringSubstr(mask, sepPos+2));
      }

   // white space entfernen
   mask    = StringReplace(mask, " ", "");
   maskLen = StringLen(mask);

   // Position des Dezimalpunktes
   int  dotPos   = StringFind(mask, ".");
   bool dotGiven = (dotPos > -1);
   if (!dotGiven)
      dotPos = maskLen;

   // Anzahl der linken Stellen
   int char, nLeft;
   bool nDigit;
   for (int i=0; i < dotPos; i++) {
      char = StringGetChar(mask, i);
      if ('0' <= char) if (char <= '9') {    // (0 <= char && char <= 9)
         nLeft = 10*nLeft + char-'0';
         nDigit = true;
      }
   }
   if (!nDigit) nLeft = -1;

   // Anzahl der rechten Stellen
   int nRight, nSubpip;
   if (dotGiven) {
      nDigit = false;
      for (i=dotPos+1; i < maskLen; i++) {
         char = StringGetChar(mask, i);
         if ('0' <= char && char <= '9') {   // (0 <= char && char <= 9)
            nRight = 10*nRight + char-'0';
            nDigit = true;
         }
         else if (nDigit && char == 39) {    // 39 => '
            nSubpip = nRight;
            continue;
         }
         else {
            if  (char == '+') nRight = MathMax(nRight+(nSubpip > 0), CountDecimals(number));
            else if (!nDigit) nRight = CountDecimals(number);
            break;
         }
      }
      if (nDigit) {
         if (nSubpip >  0) nRight++;
         if (nSubpip == 8) nSubpip = 0;
         nRight = MathMin(nRight, 8);
      }
   }

   // Vorzeichen
   string leadSign = "";
   if (number < 0) {
      leadSign = "-";
   }
   else if (number > 0) {
      int pos = StringFind(mask, "+");
      if (-1 < pos) if (pos < dotPos)        // (-1 < pos && pos < dotPos)
         leadSign = "+";
   }

   // übrige Modifier
   bool round = (StringFind(mask, "R")  > -1);
   //
   // === Ende Maske parsen ===

   // === Beginn Wertverarbeitung ===
   // runden
   if (round)
      number = MathRoundFix(number, nRight);
   string outStr = number;

   // negatives Vorzeichen entfernen (ist in leadSign gespeichert)
   if (number < 0)
      outStr = StringSubstr(outStr, 1);

   // auf angegebene Länge kürzen
   int dLeft = StringFind(outStr, ".");
   if (nLeft == -1) nLeft = dLeft;
   else             nLeft = MathMin(nLeft, dLeft);
   outStr = StringSubstrFix(outStr, StringLen(outStr)-9-nLeft, nLeft+(nRight>0)+nRight);

   // Dezimal-Separator anpassen
   if (swapSeparators)
      outStr = StringSetChar(outStr, nLeft, StringGetChar(sepDecimal, 0));

   // 1000er-Separatoren einfügen
   if (separators) {
      string out1;
      i = nLeft;
      while (i > 3) {
         out1 = StringSubstrFix(outStr, 0, i-3);
         if (StringGetChar(out1, i-4) == ' ')
            break;
         outStr = StringConcatenate(out1, sepThousand, StringSubstr(outStr, i-3));
         i -= 3;
      }
   }

   // Subpip-Separator einfügen
   if (nSubpip > 0)
      outStr = StringConcatenate(StringLeft(outStr, nSubpip-nRight), "'", StringRight(outStr, nRight-nSubpip));

   // Vorzeichen etc. anfügen
   outStr = StringConcatenate(leadSign, outStr);

   //Print("NumberToStr(double="+ DoubleToStr(number, 8) +", mask="+ mask +")    nLeft="+ nLeft +"    dLeft="+ dLeft +"    nRight="+ nRight +"    nSubpip="+ nSubpip +"    outStr=\""+ outStr +"\"");

   if (catch("NumberToStr()") != NO_ERROR)
      return("");
   return(outStr);
}


// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! //


/**
 * This formats a number (int or double) into a string, performing alignment, rounding, inserting commas (0,000,000 etc), floating signs, currency symbols, and so forth, according to the instructions provided in the 'mask'.
 *
 * The basic mask is "n" or "n.d" where n is the number of digits to the left of the decimal point, and d the number to the right,
 * e.g. NumberToStr(123.456,"5") will return "<space><space>123"
 * e.g. NumberToStr(123.456,"5.2") will return "<space><space>123.45"
 *
 * Other characters that may be used in the mask:
 *
 *    - Including a "-" anywhere to the left of "n.d" will cause a floating minus symbol to be included to the left of the number, if the nunber is negative; no symbol if positive
 *    - Including a "+" anywhere to the left of "n.d" will cause a floating plus or minus symbol to be included, to the left of the number
 *    - Including a "-" anywhere to the right of "n.d" will cause a minus to be included at the right of the number, e.g. NumberToStr(-123.456,"3.2-") will return "123.46-"
 *    - Including a "(" or ")" anywhere in the mask will cause any negative number to be enclosed in parentheses
 *    - Including an "R" or "r" anywhere in the mask will cause rounding, e.g. NumberToStr(123.456,"R3.2") will return "123.46"; e.g. NumberToStr(123.7,"R3") will return "124"
 *    - Including a "$", "€", "£" or "¥" anywhere in the mask will cause the designated floating currency symbol to be included, to the left of the number
 *    - Including a "," anywhere in the mask will cause commas to be inserted between every 3 digits, to separate thousands, millions, etc at the left of the number, e.g. NumberToStr(123456.789,",6.3") will return "123,456.789"
 *    - Including a "Z" or "z" anywhere in the mask will cause zeros (instead of spaces) to be used to fill any unused places at the left of the number, e.g. NumberToStr(123.456,"Z5.2") will return "00123.45"
 *    - Including a "B" or "b" anywhere in the mask ("blank if zero") will cause the entire output to be blanks, if the value of the number is zero
 *    - Including a "*" anywhere in the mask will cause an asterisk to be output, if overflow occurs (the value of n in "n.d" is too small to allow the number to be output in full)
 *    - Including a "L" or "l" anywhere in the mask will cause the output to be left aligned in the output field, e.g. NumberToStr(123.456,"L5.2") will return "123.45<space><space>"
 *    - Including a "T" or "t" anywhere in the mask will cause the output to be left aligned in the output field, and trailing spaces trimmed e.g. NumberToStr(123.456,"T5.2") will return "123.45"
 *    - Including a ";" anywhere in the mask will cause decimal point and comma to be juxtaposed, e.g. NumberToStr(123456.789,";,6.3") will return "123.456,789"
 *
 * ==================================================================================================================================================================
 *
 * Formats a number using a mask, and returns the resulting string
 *
 * Mask parameters:
 * n = number of digits to output, to the left of the decimal point
 * n.d = output n digits to left of decimal point; d digits to the right
 * -n.d = floating minus sign at left of output
 * n.d- = minus sign at right of output
 * +n.d = floating plus/minus sign at left of output
 * ( or ) = enclose negative number in parentheses
 * $ or £ or ¥ or € = include floating currency symbol at left of output
 * % = include trailing % sign
 * , = use commas to separate thousands
 * Z or z = left fill with zeros instead of spaces
 * R or r = round result in rightmost displayed digit
 * B or b = blank entire field if number is 0
 * * = show asterisk in leftmost position if overflow occurs
 * ; = switch use of comma and period (European format)
 * L or l = left align final string
 * T ot t = trim end result
 */
string orig_NumberToStr(double n, string mask) {
   if (MathAbs(n) == EMPTY_VALUE)
      n = 0;

   mask = StringToUpper(mask);
   int dotadj = 0;
   int dot    = StringFind(mask, ".");
   if (dot < 0) {
      dot    = StringLen(mask);
      dotadj = 1;
   }

   int nleft  = 0;
   int nright = 0;

   for (int i=0; i < dot; i++) {
      string char = StringSubstr(mask, i, 1);
      if (char >= "0" && char <= "9")
         nleft = 10*nleft + StrToInteger(char);
   }
   if (dotadj == 0) {
      for (i=dot+1; i <= StringLen(mask); i++) {
         char = StringSubstr(mask, i, 1);
         if (char >= "0" && char <= "9")
            nright = 10*nright + StrToInteger(char);
      }
   }
   nright = MathMin(nright, 7);

   if (dotadj == 1) {
      for (i=0; i < StringLen(mask); i++) {
         char = StringSubstr(mask, i, 1);
         if (char >= "0" && char <= "9") {
            dot = i;
            break;
         }
      }
   }

   string csym = "";
   if (StringFind(mask, "$") > -1) csym = "$";
   if (StringFind(mask, "£") > -1) csym = "£";
   if (StringFind(mask, "€") > -1) csym = "€";
   if (StringFind(mask, "¥") > -1) csym = "¥";

   string leadsign  = "";
   string trailsign = "";

   if (StringFind(mask, "+") > -1 && StringFind(mask, "+") < dot) {
      leadsign = " ";
      if (n > 0) leadsign = "+";
      if (n < 0) leadsign = "-";
   }
   if (StringFind(mask, "-") > -1 && StringFind(mask, "-") < dot) {
      if (n < 0) leadsign = "-";
      else       leadsign = " ";
   }
   if (StringFind(mask, "-") > -1 && StringFind(mask, "-") > dot) {
      if (n < 0) trailsign = "-";
      else       trailsign = " ";
   }
   if (StringFind(mask, "(") > -1 || StringFind(mask, ")") > -1) {
      leadsign  = " ";
      trailsign = " ";
      if (n < 0) {
         leadsign  = "(";
         trailsign = ")";
      }
   }
   if (StringFind(mask, "%") > -1)
      trailsign = "%" + trailsign;

   bool comma = (StringFind(mask, ",") > -1);
   bool zeros = (StringFind(mask, "Z") > -1);
   bool blank = (StringFind(mask, "B") > -1);
   bool round = (StringFind(mask, "R") > -1);
   bool overf = (StringFind(mask, "*") > -1);
   bool lftsh = (StringFind(mask, "L") > -1);
   bool swtch = (StringFind(mask, ";") > -1);
   bool trimf = (StringFind(mask, "T") > -1);

   if (round)
      n = MathRoundFix(n, nright);
   string outstr = n;

   int dleft = 0;
   for (i=0; i < StringLen(outstr); i++) {
      char = StringSubstr(outstr, i, 1);
      if (char >= "0" && char <= "9")
         dleft++;
      if (char == ".")
         break;
   }

   // Insert fill characters.......
   if (zeros) string fill = "0";
   else              fill = " ";
   if (n < 0) outstr = "-" + StringRepeat(fill, nleft-dleft) + StringSubstr(outstr, 1);
   else       outstr = StringRepeat(fill, nleft-dleft) + outstr;
   outstr = StringSubstrFix(outstr, StringLen(outstr)-9-nleft, nleft+1+nright-dotadj);

   // Insert the commas.......
   if (comma) {
      bool digflg = false;
      bool stpflg = false;
      string out1 = "";
      string out2 = "";
      for (i=0; i < StringLen(outstr); i++) {
         char = StringSubstr(outstr, i, 1);
         if (char == ".")
            stpflg = true;
         if (!stpflg && (nleft-i==3 || nleft-i==6 || nleft-i==9)) {
            if (digflg) out1 = out1 +",";
            else        out1 = out1 +" ";
         }
         out1 = out1 + char;
         if (char >= "0" && char <= "9")
            digflg = true;
      }
      outstr = out1;
   }

   // Add currency symbol and signs........
   outstr = csym + leadsign + outstr + trailsign;

   // 'Float' the currency symbol/sign.......
   out1 = "";
   out2 = "";
   bool fltflg = true;
   for (i=0; i < StringLen(outstr); i++) {
      char = StringSubstr(outstr, i, 1);
      if (char >= "0" && char <= "9")
         fltflg = false;
      if ((char==" " && fltflg) || (blank && n==0)) out1 = out1 + " ";
      else                                          out2 = out2 + char;
   }
   outstr = out1 + out2;

   // Overflow........
   if (overf && dleft > nleft)
      outstr = "*" + StringSubstr(outstr, 1);

   // Left shift.......
   if (lftsh) {
      int len = StringLen(outstr);
      outstr = StringTrimLeft(outstr);
      outstr = outstr + StringRepeat(" ", len-StringLen(outstr));
   }

   // Switch period and comma.......
   if (swtch) {
      out1 = "";
      for (i=0; i < StringLen(outstr); i++) {
         char = StringSubstr(outstr, i, 1);
         if      (char == ".") out1 = out1 +",";
         else if (char == ",") out1 = out1 +".";
         else                  out1 = out1 + char;
      }
      outstr = out1;
   }

   if (trimf)
      outstr = StringTrim(outstr);
   return(outstr);
}


/**
 * Returns the numeric value for an MQL4 color descriptor string.
 *
 *  Usage: StrToColor("Aqua")       => 16776960
 *  or:    StrToColor("0,255,255")  => 16776960  i.e. StrToColor("<red>,<green>,<blue>")
 *  or:    StrToColor("r0g255b255") => 16776960  i.e. StrToColor("r<nnn>g<nnn>b<nnn>")
 *  or:    StrToColor("0xFFFF00")   => 16776960  i.e. StrToColor("0xbbggrr")
 */
int StrToColor(string str) {
   str = StringToLower(str);

   if (str == "aliceblue"        ) return(0xFFF8F0);
   if (str == "antiquewhite"     ) return(0xD7EBFA);
   if (str == "aqua"             ) return(0xFFFF00);
   if (str == "aquamarine"       ) return(0xD4FF7F);
   if (str == "beige"            ) return(0xDCF5F5);
   if (str == "bisque"           ) return(0xC4E4FF);
   if (str == "black"            ) return(0x000000);
   if (str == "blanchedalmond"   ) return(0xCDEBFF);
   if (str == "blue"             ) return(0xFF0000);
   if (str == "blueviolet"       ) return(0xE22B8A);
   if (str == "brown"            ) return(0x2A2AA5);
   if (str == "burlywood"        ) return(0x87B8DE);
   if (str == "cadetblue"        ) return(0xA09E5F);
   if (str == "chartreuse"       ) return(0x00FF7F);
   if (str == "chocolate"        ) return(0x1E69D2);
   if (str == "coral"            ) return(0x507FFF);
   if (str == "cornflowerblue"   ) return(0xED9564);
   if (str == "cornsilk"         ) return(0xDCF8FF);
   if (str == "crimson"          ) return(0x3C14DC);
   if (str == "darkblue"         ) return(0x8B0000);
   if (str == "darkgoldenrod"    ) return(0x0B86B8);
   if (str == "darkgray"         ) return(0xA9A9A9);
   if (str == "darkgreen"        ) return(0x006400);
   if (str == "darkkhaki"        ) return(0x6BB7BD);
   if (str == "darkolivegreen"   ) return(0x2F6B55);
   if (str == "darkorange"       ) return(0x008CFF);
   if (str == "darkorchid"       ) return(0xCC3299);
   if (str == "darksalmon"       ) return(0x7A96E9);
   if (str == "darkseagreen"     ) return(0x8BBC8F);
   if (str == "darkslateblue"    ) return(0x8B3D48);
   if (str == "darkslategray"    ) return(0x4F4F2F);
   if (str == "darkturquoise"    ) return(0xD1CE00);
   if (str == "darkviolet"       ) return(0xD30094);
   if (str == "deeppink"         ) return(0x9314FF);
   if (str == "deepskyblue"      ) return(0xFFBF00);
   if (str == "dimgray"          ) return(0x696969);
   if (str == "dodgerblue"       ) return(0xFF901E);
   if (str == "firebrick"        ) return(0x2222B2);
   if (str == "forestgreen"      ) return(0x228B22);
   if (str == "gainsboro"        ) return(0xDCDCDC);
   if (str == "gold"             ) return(0x00D7FF);
   if (str == "goldenrod"        ) return(0x20A5DA);
   if (str == "gray"             ) return(0x808080);
   if (str == "green"            ) return(0x008000);
   if (str == "greenyellow"      ) return(0x2FFFAD);
   if (str == "honeydew"         ) return(0xF0FFF0);
   if (str == "hotpink"          ) return(0xB469FF);
   if (str == "indianred"        ) return(0x5C5CCD);
   if (str == "indigo"           ) return(0x82004B);
   if (str == "ivory"            ) return(0xF0FFFF);
   if (str == "khaki"            ) return(0x8CE6F0);
   if (str == "lavender"         ) return(0xFAE6E6);
   if (str == "lavenderblush"    ) return(0xF5F0FF);
   if (str == "lawngreen"        ) return(0x00FC7C);
   if (str == "lemonchiffon"     ) return(0xCDFAFF);
   if (str == "lightblue"        ) return(0xE6D8AD);
   if (str == "lightcoral"       ) return(0x8080F0);
   if (str == "lightcyan"        ) return(0xFFFFE0);
   if (str == "lightgoldenrod"   ) return(0xD2FAFA);
   if (str == "lightgray"        ) return(0xD3D3D3);
   if (str == "lightgreen"       ) return(0x90EE90);
   if (str == "lightpink"        ) return(0xC1B6FF);
   if (str == "lightsalmon"      ) return(0x7AA0FF);
   if (str == "lightseagreen"    ) return(0xAAB220);
   if (str == "lightskyblue"     ) return(0xFACE87);
   if (str == "lightslategray"   ) return(0x998877);
   if (str == "lightsteelblue"   ) return(0xDEC4B0);
   if (str == "lightyellow"      ) return(0xE0FFFF);
   if (str == "lime"             ) return(0x00FF00);
   if (str == "limegreen"        ) return(0x32CD32);
   if (str == "linen"            ) return(0xE6F0FA);
   if (str == "magenta"          ) return(0xFF00FF);
   if (str == "maroon"           ) return(0x000080);
   if (str == "mediumaquamarine" ) return(0xAACD66);
   if (str == "mediumblue"       ) return(0xCD0000);
   if (str == "mediumorchid"     ) return(0xD355BA);
   if (str == "mediumpurple"     ) return(0xDB7093);
   if (str == "mediumseagreen"   ) return(0x71B33C);
   if (str == "mediumslateblue"  ) return(0xEE687B);
   if (str == "mediumspringgreen") return(0x9AFA00);
   if (str == "mediumturquoise"  ) return(0xCCD148);
   if (str == "mediumvioletred"  ) return(0x8515C7);
   if (str == "midnightblue"     ) return(0x701919);
   if (str == "mintcream"        ) return(0xFAFFF5);
   if (str == "mistyrose"        ) return(0xE1E4FF);
   if (str == "moccasin"         ) return(0xB5E4FF);
   if (str == "navajowhite"      ) return(0xADDEFF);
   if (str == "navy"             ) return(0x800000);
   if (str == "none"             ) return(      -1);
   if (str == "oldlace"          ) return(0xE6F5FD);
   if (str == "olive"            ) return(0x008080);
   if (str == "olivedrab"        ) return(0x238E6B);
   if (str == "orange"           ) return(0x00A5FF);
   if (str == "orangered"        ) return(0x0045FF);
   if (str == "orchid"           ) return(0xD670DA);
   if (str == "palegoldenrod"    ) return(0xAAE8EE);
   if (str == "palegreen"        ) return(0x98FB98);
   if (str == "paleturquoise"    ) return(0xEEEEAF);
   if (str == "palevioletred"    ) return(0x9370DB);
   if (str == "papayawhip"       ) return(0xD5EFFF);
   if (str == "peachpuff"        ) return(0xB9DAFF);
   if (str == "peru"             ) return(0x3F85CD);
   if (str == "pink"             ) return(0xCBC0FF);
   if (str == "plum"             ) return(0xDDA0DD);
   if (str == "powderblue"       ) return(0xE6E0B0);
   if (str == "purple"           ) return(0x800080);
   if (str == "red"              ) return(0x0000FF);
   if (str == "rosybrown"        ) return(0x8F8FBC);
   if (str == "royalblue"        ) return(0xE16941);
   if (str == "saddlebrown"      ) return(0x13458B);
   if (str == "salmon"           ) return(0x7280FA);
   if (str == "sandybrown"       ) return(0x60A4F4);
   if (str == "seagreen"         ) return(0x578B2E);
   if (str == "seashell"         ) return(0xEEF5FF);
   if (str == "sienna"           ) return(0x2D52A0);
   if (str == "silver"           ) return(0xC0C0C0);
   if (str == "skyblue"          ) return(0xEBCE87);
   if (str == "slateblue"        ) return(0xCD5A6A);
   if (str == "slategray"        ) return(0x908070);
   if (str == "snow"             ) return(0xFAFAFF);
   if (str == "springgreen"      ) return(0x7FFF00);
   if (str == "steelblue"        ) return(0xB48246);
   if (str == "tan"              ) return(0x8CB4D2);
   if (str == "teal"             ) return(0x808000);
   if (str == "thistle"          ) return(0xD8BFD8);
   if (str == "tomato"           ) return(0x4763FF);
   if (str == "turquoise"        ) return(0xD0E040);
   if (str == "violet"           ) return(0xEE82EE);
   if (str == "wheat"            ) return(0xB3DEF5);
   if (str == "white"            ) return(0xFFFFFF);
   if (str == "whitesmoke"       ) return(0xF5F5F5);
   if (str == "yellow"           ) return(0x00FFFF);
   if (str == "yellowgreen"      ) return(0x32CD9A);

   int t1 = StringFind(str, ",", 0);
   int t2 = StringFind(str, ",", t1+1);

   if (t1>0 && t2>0) {
      int red   = StrToInteger(StringSubstrFix(str, 0, t1));
      int green = StrToInteger(StringSubstrFix(str, t1+1, t2-1));
      int blue  = StrToInteger(StringSubstr(str, t2+1));
      return(blue*256*256 + green*256 + red);
   }

   if (StringSubstr(str, 0, 2) == "0x") {
      string cnvstr = "0123456789abcdef";
      string seq    = "234567";
      int    retval = 0;
      for (int i=0; i < 6; i++) {
         int pos = StrToInteger(StringSubstr(seq, i, 1));
         int val = StringFind(cnvstr, StringSubstr(str, pos, 1), 0);
         if (val < 0)
            return(val);
         retval = retval * 16 + val;
      }
      return(retval);
   }

   string cclr = "", tmp = "";
   red   = 0;
   blue  = 0;
   green = 0;

   if (StringFind("rgb", StringSubstr(str, 0, 1)) >= 0) {
      for (i=0; i < StringLen(str); i++) {
         tmp = StringSubstr(str, i, 1);
         if (StringFind("rgb", tmp, 0) >= 0)
            cclr = tmp;
         else {
            if (cclr == "b") blue  = blue  * 10 + StrToInteger(tmp);
            if (cclr == "g") green = green * 10 + StrToInteger(tmp);
            if (cclr == "r") red   = red   * 10 + StrToInteger(tmp);
         }
      }
      return(blue*256*256 + green*256 + red);
   }

   return(0);
}


/**
 *
 */
bool StrToBool(string str) {
   str = StringToLower(StringSubstr(str, 0, 1));
   return(str=="t" || str=="y" || str=="1");
}


/**
 * Converts a timeframe string to its MT4-numeric value
 * Usage:   int x=StrToTF("M15")   returns x=15
 */
int StrToTF(string str) {
   str = StringToUpper(str);
   if (str == "M1" ) return(    1);
   if (str == "M5" ) return(    5);
   if (str == "M15") return(   15);
   if (str == "M30") return(   30);
   if (str == "H1" ) return(   60);
   if (str == "H4" ) return(  240);
   if (str == "D1" ) return( 1440);
   if (str == "W1" ) return(10080);
   if (str == "MN" ) return(43200);
   return(0);
}


/**
 * Converts a MT4-numeric timeframe to its descriptor string
 * Usage:   string s=TFToStr(15) returns s="M15"
 */
string TFToStr(int tf) {
   switch (tf) {
      case     1: return("M1" );
      case     5: return("M5" );
      case    15: return("M15");
      case    30: return("M30");
      case    60: return("H1" );
      case   240: return("H4" );
      case  1440: return("D1" );
      case 10080: return("W1" );
      case 43200: return("MN" );
   }
   return(0);
}


/**
 * Prepends occurrences of the string STR2 to the string STR to make a string N characters long
 * Usage:    string x=StringLeftPad("ABCDEFG",9," ")  returns x = "  ABCDEFG"
 */
string StringLeftPad(string str, int n, string str2) {
   return(StringRepeat(str2, n-StringLen(str)) + str);
}


/**
 * Appends occurrences of the string STR2 to the string STR to make a string N characters long
 * Usage:    string x=StringRightPad("ABCDEFG",9," ")  returns x = "ABCDEFG  "
 */
string StringRightPad(string str, int n, string str2) {
   return(str + StringRepeat(str2, n-StringLen(str)));
}


/**
 *
 */
string StringReverse(string str) {
   string outstr = "";
   for (int i=StringLen(str)-1; i >= 0; i--) {
      outstr = outstr + StringSubstr(str,i,1);
   }
   return(outstr);
}


/**
 *
 */
string StringLeftExtract(string str, int n, string str2, int m) {
   if (n > 0) {
      int j = -1;
      for (int i=1; i <= n; i++) {
         j = StringFind(str, str2, j+1);
      }
      if (j > 0)
         return(StringLeft(str, j+m));
   }

   if (n < 0) {
      int c = 0;
      j = 0;
      for (i=StringLen(str)-1; i >= 0; i--) {
         if (StringSubstrFix(str, i, StringLen(str2)) == str2) {
            c++;
            if (c == -n) {
               j = i;
               break;
            }
         }
      }
      if (j > 0)
         return(StringLeft(str, j+m));
   }
   return("");
}


/**
 *
 */
string StringRightExtract(string str, int n, string str2, int m) {
   if (n > 0) {
      int j = -1;
      for (int i=1; i <= n; i++) {
         j=StringFind(str,str2,j+1);
      }
      if (j > 0)
         return(StringRight(str, StringLen(str)-j-1+m));
   }

   if (n < 0) {
      int c = 0;
      j = 0;
      for (i=StringLen(str)-1; i >= 0; i--) {
         if (StringSubstrFix(str, i, StringLen(str2)) == str2) {
            c++;
            if (c == -n) {
               j = i;
               break;
            }
         }
      }
      if (j > 0)
         return(StringRight(str, StringLen(str)-j-1+m));
   }
   return("");
}


/**
 * Returns the number of occurrences of STR2 in STR
 * Usage:   int x = StringFindCount("ABCDEFGHIJKABACABB","AB")   returns x = 3
 */
int StringFindCount(string str, string str2) {
   int c = 0;
   for (int i=0; i < StringLen(str); i++) {
      if (StringSubstrFix(str, i, StringLen(str2)) == str2)
         c++;
   }
   return(c);
}


/**
 *
 */
double MathInt(double n, int d) {
   return(MathFloor(n*MathPow(10, d) + 0.000000000001) / MathPow(10, d));
}


/**
 * Converts a datetime value to a formatted string, according to the instructions in the 'mask'.
 *
 *    - A "d" in the mask will cause a 1-2 digit day-of-the-month to be inserted in the output, at that point
 *    - A "D" in the mask will cause a 2 digit day-of-the-month to be inserted in the output, at that point
 *    - A "m" in the mask will cause a 1-2 digit month number to be inserted in the output, at that point
 *    - A "M" in the mask will cause a 2 digit month number to be inserted in the output, at that point
 *    - A "y" in the mask will cause a 2 digit year to be inserted in the output, at that point
 *    - A "Y" in the mask will cause a 4 digit (Y2K compliant) year to be inserted in the output, at that point
 *    - A "W" in the mask will cause a day-of-the week ("Monday", "Tuesday", etc) description to be inserted in the output, at that point
 *    - A "w" in the mask will cause an abbreviated day-of-the week ("Mon", "Tue", etc) description to be inserted in the output, at that point
 *    - A "N" in the mask will cause a month name ("January", "February", etc) to be inserted in the output, at that point
 *    - A "n" in the mask will cause an abbreviated month name ("Jan", "Feb", etc) to be inserted in the output, at that point
 *    - A "h" in the mask will cause the hour-of-the-day to be inserted in the output, as 1 or 2 digits, at that point
 *    - A "H" in the mask will cause the hour-of-the-day to be inserted in the output, as 2 digits (with placeholding 0, if value < 10), at that point
 *    - An "I" or "i" in the mask will cause the minutes to be inserted in the output, as 2 digits (with placeholding 0, if value < 10), at that point
 *    - A "S" or "s" in the mask will cause the seconds to be inserted in the output, as 2 digits (with placeholding 0, if value < 10), at that point
 *    - An "a" in the mask will cause a 12-hour version of the time to be displayed, with "am" or "pm" at that point
 *    - An "A" in the mask will cause a 12-hour version of the time to be displayed, with "AM" or "PM" at that point
 *    - A "T" in the mask will cause "st" "nd" rd" or "th" to be inserted at that point, depending on the day of the month e.g. 13th, 22nd, etc
 *    - All other characters in the mask will be output, as is
 *
 * Examples: if date is June 04, 2009, then:
 *
 *    - DateToStr(date, "w m/d/Y") will output "Thu 6/4/2009"
 *    - DateToStr(date, "Y-MD") will output "2009-0604"
 *    - DateToStr(date, "d N, Y is a W") will output "4 June, 2009 is a Thursday"
 *    - DateToStr(date, "W D`M`y = W") will output "Thursday 04`06`09 = Thursday"
 */
string DateToStr(datetime mt4date, string mask) {
   int dd  = TimeDay(mt4date);
   int mm  = TimeMonth(mt4date);
   int yy  = TimeYear(mt4date);
   int dw  = TimeDayOfWeek(mt4date);
   int hr  = TimeHour(mt4date);
   int min = TimeMinute(mt4date);
   int sec = TimeSeconds(mt4date);
   int h12 = 12;
   if      (hr > 12) h12 = hr - 12;
   else if (hr >  0) h12 = hr;

   string ampm = "am";
   if (hr > 12)
      ampm = "pm";

   switch (MathMod(dd, 10)) {
      case 1: string d10 = "st"; break;
      case 2:        d10 = "nd"; break;
      case 3:        d10 = "rd"; break;
      default:       d10 = "th";
   }
   if (dd > 10 && dd < 14)
      d10 = "th";

   string mth[12] = { "January","February","March","April","May","June","July","August","September","October","November","December" };
   string dow[ 7] = { "Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday" };

   string outdate = "";

   for (int i=0; i < StringLen(mask); i++) {
      string char = StringSubstr(mask, i, 1);
      if      (char == "d")                outdate = outdate + StringTrim(NumberToStr(dd, "2"));
      else if (char == "D")                outdate = outdate + StringTrim(NumberToStr(dd, "Z2"));
      else if (char == "m")                outdate = outdate + StringTrim(NumberToStr(mm, "2"));
      else if (char == "M")                outdate = outdate + StringTrim(NumberToStr(mm, "Z2"));
      else if (char == "y")                outdate = outdate + StringTrim(NumberToStr(yy, "2"));
      else if (char == "Y")                outdate = outdate + StringTrim(NumberToStr(yy, "4"));
      else if (char == "n")                outdate = outdate + StringSubstr(mth[mm-1], 0, 3);
      else if (char == "N")                outdate = outdate + mth[mm-1];
      else if (char == "w")                outdate = outdate + StringSubstr(dow[dw], 0, 3);
      else if (char == "W")                outdate = outdate + dow[dw];
      else if (char == "h")                outdate = outdate + StringTrim(NumberToStr(h12, "2"));
      else if (char == "H")                outdate = outdate + StringTrim(NumberToStr(hr, "Z2"));
      else if (StringToUpper(char) == "I") outdate = outdate + StringTrim(NumberToStr(min, "Z2"));
      else if (StringToUpper(char) == "S") outdate = outdate + StringTrim(NumberToStr(sec, "Z2"));
      else if (char == "a")                outdate = outdate + ampm;
      else if (char == "A")                outdate = outdate + StringToUpper(ampm);
      else if (StringToUpper(char) == "T") outdate = outdate + d10;
      else                                 outdate = outdate + char;
   }
   return(outdate);
}


/**
 * Returns the base 10 version of a number in another base
 * Usage:   int x=BaseToNumber("DC",16)   returns x=220
 */
int BaseToNumber(string str, int base) {
   str = StringToUpper(str);
   string cnvstr = "0123456789ABCDEF";
   int    retval = 0;
   for (int i=0; i < StringLen(str); i++) {
      int val = StringFind(cnvstr, StringSubstr(str, i, 1), 0);
      if (val < 0)
         return(val);
      retval = retval * base + val;
   }
   return(retval);
}


/**
 * Converts a base 10 number to another base, left-padded with zeros
 * Usage:   int x=BaseToNumber(220,16,4)   returns x="00DC"
 */
string NumberToBase(int n, int base, int pad) {
   string cnvstr = "0123456789ABCDEF";
   string outstr = "";
   while (n > 0) {
      int x = MathMod(n, base);
      outstr = StringSubstr(cnvstr, x, 1) + outstr;
      n /= base;
   }
   x = StringLen(outstr);
   if (x < pad)
      outstr = StringRepeat("0", pad-x) + outstr;
   return(outstr);
}
