/**
 * Win32 struct STARTUPINFOA (Ansi-Version)
 *
 * struct STARTUPINFOA {
 *    DWORD   cb;                         //  4    Getter/Setter-Alias: si_Size() / si_setSize()
 *    LPSTR   lpReserved;                 //  4
 *    LPSTR   lpDesktop;                  //  4
 *    LPSTR   lpTitle;                    //  4
 *    DWORD   dwX;                        //  4
 *    DWORD   dwY;                        //  4
 *    DWORD   dwXSize;                    //  4
 *    DWORD   dwYSize;                    //  4
 *    DWORD   dwXCountChars;              //  4
 *    DWORD   dwYCountChars;              //  4
 *    DWORD   dwFillAttribute;            //  4
 *    DWORD   dwFlags;                    //  4
 *    WORD    wShowWindow;                //  2
 *    WORD    cbReserved2;                //  2
 *    LPBYTE  lpReserved2;                //  4
 *    HANDLE  hStdInput;                  //  4
 *    HANDLE  hStdOutput;                 //  4
 *    HANDLE  hStdError;                  //  4
 * } STARTUPINFO;                         // 68 byte
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
      result = StrSubstr(result, 1);
   return(result);
}


#import "rsfMT4Expander.dll"
   int si_setSize      (/*STARTUPINFO*/int si[], int size   );
   //  ...
   int si_setFlags     (/*STARTUPINFO*/int si[], int flags  );
   int si_setShowWindow(/*STARTUPINFO*/int si[], int cmdShow);
   //  ...
#import
