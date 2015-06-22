/**
 * Win32 structure STARTUPINFO
 *
 *
 * struct STARTUPINFOA {
 *    DWORD  cb;                          //  4      => si[ 0]    // Getter/Setter mit Alias: si.Size
 *    LPSTR  lpReserved;                  //  4      => si[ 1]
 *    LPSTR  lpDesktop;                   //  4      => si[ 2]
 *    LPSTR  lpTitle;                     //  4      => si[ 3]
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
 * } STARTUPINFO, si;                     // 68 byte = int[17]
 */
int si.Size         (/*STARTUPINFO*/int si[]) { return(si[ 0]); }
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

int si.setSize      (/*STARTUPINFO*/int &si[], int size   ) { si[ 0] =  size;                                      return(size   ); }
int si.setFlags     (/*STARTUPINFO*/int &si[], int flags  ) { si[11] = flags;                                      return(flags  ); }
int si.setShowWindow(/*STARTUPINFO*/int &si[], int cmdShow) { si[12] = (si[12] & 0xFFFF0000) + (cmdShow & 0xFFFF); return(cmdShow); }


// STARTUPINFO flags
#define STARTF_FORCEONFEEDBACK      0x0040
#define STARTF_FORCEOFFFEEDBACK     0x0080
#define STARTF_PREVENTPINNING       0x2000
#define STARTF_RUNFULLSCREEN        0x0020
#define STARTF_TITLEISAPPID         0x1000
#define STARTF_TITLEISLINKNAME      0x0800
#define STARTF_USECOUNTCHARS        0x0008
#define STARTF_USEFILLATTRIBUTE     0x0010
#define STARTF_USEHOTKEY            0x0200
#define STARTF_USEPOSITION          0x0004
#define STARTF_USESHOWWINDOW        0x0001
#define STARTF_USESIZE              0x0002
#define STARTF_USESTDHANDLES        0x0100


/**
 * Gibt die lesbare Version ein oder mehrerer STARTUPINFO-Flags zurück.
 *
 * @param  int si[] - STARTUPINFO
 *
 * @return string
 */
string si.FlagsToStr(/*STARTUPINFO*/int si[]) {
   string result = "";
   int flags = si.Flags(si);

   if (flags & STARTF_FORCEONFEEDBACK  && 1) result = StringConcatenate(result, "|STARTF_FORCEONFEEDBACK" );
   if (flags & STARTF_FORCEOFFFEEDBACK && 1) result = StringConcatenate(result, "|STARTF_FORCEOFFFEEDBACK");
   if (flags & STARTF_PREVENTPINNING   && 1) result = StringConcatenate(result, "|STARTF_PREVENTPINNING"  );
   if (flags & STARTF_RUNFULLSCREEN    && 1) result = StringConcatenate(result, "|STARTF_RUNFULLSCREEN"   );
   if (flags & STARTF_TITLEISAPPID     && 1) result = StringConcatenate(result, "|STARTF_TITLEISAPPID"    );
   if (flags & STARTF_TITLEISLINKNAME  && 1) result = StringConcatenate(result, "|STARTF_TITLEISLINKNAME" );
   if (flags & STARTF_USECOUNTCHARS    && 1) result = StringConcatenate(result, "|STARTF_USECOUNTCHARS"   );
   if (flags & STARTF_USEFILLATTRIBUTE && 1) result = StringConcatenate(result, "|STARTF_USEFILLATTRIBUTE");
   if (flags & STARTF_USEHOTKEY        && 1) result = StringConcatenate(result, "|STARTF_USEHOTKEY"       );
   if (flags & STARTF_USEPOSITION      && 1) result = StringConcatenate(result, "|STARTF_USEPOSITION"     );
   if (flags & STARTF_USESHOWWINDOW    && 1) result = StringConcatenate(result, "|STARTF_USESHOWWINDOW"   );
   if (flags & STARTF_USESIZE          && 1) result = StringConcatenate(result, "|STARTF_USESIZE"         );
   if (flags & STARTF_USESTDHANDLES    && 1) result = StringConcatenate(result, "|STARTF_USESTDHANDLES"   );

   if (StringLen(result) > 0)
      result = StringSubstr(result, 1);
   return(result);
}


// ShowWindow() constants
#define SW_SHOW                           5
#define SW_SHOWNA                         8
#define SW_HIDE                           0
#define SW_SHOWMAXIMIZED                  3
#define SW_SHOWMINIMIZED                  2
#define SW_SHOWMINNOACTIVE                7
#define SW_MINIMIZE                       6
#define SW_FORCEMINIMIZE                 11
#define SW_SHOWNORMAL                     1
#define SW_SHOWNOACTIVATE                 4
#define SW_RESTORE                        9
#define SW_SHOWDEFAULT                   10


/**
 * Gibt die lesbare ShowWindow()-Konstante einer STARTUPINFO zurück.
 *
 * @param  int si[] - STARTUPINFO
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


#import "Expander.dll"
   int si_setSize      (/*STARTUPINFO*/int si[], int size   );
   //  ...
   //  ...
   //  ...
   //  ...
   //  ...
   //  ...
   //  ...
   //  ...
   //  ...
   int si_setFlags     (/*STARTUPINFO*/int si[], int flags  );
   //  ...
   int si_setShowWindow(/*STARTUPINFO*/int si[], int cmdShow);
   //  ...
   //  ...
   //  ...
   //  ...
   //  ...
#import
