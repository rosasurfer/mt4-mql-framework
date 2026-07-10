/**
 * Win32 struct WIN32_FIND_DATAA (ANSI-Version)
 *
 * struct WIN32_FIND_DATAA {
 *    DWORD    dwFileAttributes;          //   4
 *    FILETIME ftCreationTime;            //   8
 *    FILETIME ftLastAccessTime;          //   8
 *    FILETIME ftLastWriteTime;           //   8
 *    DWORD    nFileSizeHigh;             //   4
 *    DWORD    nFileSizeLow;              //   4
 *    DWORD    dwReserved0;               //   4
 *    DWORD    dwReserved1;               //   4
 *    CHAR     cFileName[MAX_PATH];       // 260
 *    CHAR     cAlternateFileName[14];    //  14
 * } WIN32_FIND_DATA;                     // 318 byte       Ende liegt nicht an einem Integer-Boundary
 */
#import "rsfMT4Expander.dll"
   int    wfd_FileAttributes            (/*WIN32_FIND_DATA*/int wfd[]);
   bool   wfd_FileAttribute_ReadOnly    (/*WIN32_FIND_DATA*/int wfd[]);
   bool   wfd_FileAttribute_Hidden      (/*WIN32_FIND_DATA*/int wfd[]);
   bool   wfd_FileAttribute_System      (/*WIN32_FIND_DATA*/int wfd[]);
   bool   wfd_FileAttribute_Directory   (/*WIN32_FIND_DATA*/int wfd[]);
   bool   wfd_FileAttribute_Archive     (/*WIN32_FIND_DATA*/int wfd[]);
   bool   wfd_FileAttribute_Device      (/*WIN32_FIND_DATA*/int wfd[]);
   bool   wfd_FileAttribute_Normal      (/*WIN32_FIND_DATA*/int wfd[]);
   bool   wfd_FileAttribute_Temporary   (/*WIN32_FIND_DATA*/int wfd[]);
   bool   wfd_FileAttribute_SparseFile  (/*WIN32_FIND_DATA*/int wfd[]);
   bool   wfd_FileAttribute_ReparsePoint(/*WIN32_FIND_DATA*/int wfd[]);
   bool   wfd_FileAttribute_Compressed  (/*WIN32_FIND_DATA*/int wfd[]);
   bool   wfd_FileAttribute_Offline     (/*WIN32_FIND_DATA*/int wfd[]);
   bool   wfd_FileAttribute_NotIndexed  (/*WIN32_FIND_DATA*/int wfd[]);
   bool   wfd_FileAttribute_Encrypted   (/*WIN32_FIND_DATA*/int wfd[]);
   bool   wfd_FileAttribute_Virtual     (/*WIN32_FIND_DATA*/int wfd[]);
   //     ...
   string wfd_FileName                  (/*WIN32_FIND_DATA*/int wfd[]);
   string wfd_AlternateFileName         (/*WIN32_FIND_DATA*/int wfd[]);
#import


// File attributes
#define FILE_ATTRIBUTE_READONLY              1
#define FILE_ATTRIBUTE_HIDDEN                2
#define FILE_ATTRIBUTE_SYSTEM                4
#define FILE_ATTRIBUTE_DIRECTORY            16
#define FILE_ATTRIBUTE_ARCHIVE              32
#define FILE_ATTRIBUTE_DEVICE               64
#define FILE_ATTRIBUTE_NORMAL              128
#define FILE_ATTRIBUTE_TEMPORARY           256
#define FILE_ATTRIBUTE_SPARSE_FILE         512
#define FILE_ATTRIBUTE_REPARSE_POINT      1024
#define FILE_ATTRIBUTE_COMPRESSED         2048
#define FILE_ATTRIBUTE_OFFLINE            4096
#define FILE_ATTRIBUTE_NOT_INDEXED        8192     // FILE_ATTRIBUTE_NOT_CONTENT_INDEXED ist zu lang für MQL (nicht für C++)
#define FILE_ATTRIBUTE_ENCRYPTED         16384
#define FILE_ATTRIBUTE_VIRTUAL           65536


/**
 * Gibt die lesbare Version eines FileAttributes zurück.
 *
 * @param  int wfd[] - WIN32_FIND_DATA
 *
 * @return string
 */
string wfd.FileAttributesToStr(/*WIN32_FIND_DATA*/int wfd[]) {
   int    flags  = wfd_FileAttributes(wfd);
   string result = "";

   if (flags & FILE_ATTRIBUTE_READONLY      && 1) result = StringConcatenate(result, "|FILE_ATTRIBUTE_READONLY"     );
   if (flags & FILE_ATTRIBUTE_HIDDEN        && 1) result = StringConcatenate(result, "|FILE_ATTRIBUTE_HIDDEN"       );
   if (flags & FILE_ATTRIBUTE_SYSTEM        && 1) result = StringConcatenate(result, "|FILE_ATTRIBUTE_SYSTEM"       );
   if (flags & FILE_ATTRIBUTE_DIRECTORY     && 1) result = StringConcatenate(result, "|FILE_ATTRIBUTE_DIRECTORY"    );
   if (flags & FILE_ATTRIBUTE_ARCHIVE       && 1) result = StringConcatenate(result, "|FILE_ATTRIBUTE_ARCHIVE"      );
   if (flags & FILE_ATTRIBUTE_DEVICE        && 1) result = StringConcatenate(result, "|FILE_ATTRIBUTE_DEVICE"       );
   if (flags & FILE_ATTRIBUTE_NORMAL        && 1) result = StringConcatenate(result, "|FILE_ATTRIBUTE_NORMAL"       );
   if (flags & FILE_ATTRIBUTE_TEMPORARY     && 1) result = StringConcatenate(result, "|FILE_ATTRIBUTE_TEMPORARY"    );
   if (flags & FILE_ATTRIBUTE_SPARSE_FILE   && 1) result = StringConcatenate(result, "|FILE_ATTRIBUTE_SPARSE_FILE"  );
   if (flags & FILE_ATTRIBUTE_REPARSE_POINT && 1) result = StringConcatenate(result, "|FILE_ATTRIBUTE_REPARSE_POINT");
   if (flags & FILE_ATTRIBUTE_COMPRESSED    && 1) result = StringConcatenate(result, "|FILE_ATTRIBUTE_COMPRESSED"   );
   if (flags & FILE_ATTRIBUTE_OFFLINE       && 1) result = StringConcatenate(result, "|FILE_ATTRIBUTE_OFFLINE"      );
   if (flags & FILE_ATTRIBUTE_NOT_INDEXED   && 1) result = StringConcatenate(result, "|FILE_ATTRIBUTE_NOT_INDEXED"  );
   if (flags & FILE_ATTRIBUTE_ENCRYPTED     && 1) result = StringConcatenate(result, "|FILE_ATTRIBUTE_ENCRYPTED"    );
   if (flags & FILE_ATTRIBUTE_VIRTUAL       && 1) result = StringConcatenate(result, "|FILE_ATTRIBUTE_VIRTUAL"      );

   if (StringLen(result) > 0)
      result = StrSubstr(result, 1);
   return(result);
}
