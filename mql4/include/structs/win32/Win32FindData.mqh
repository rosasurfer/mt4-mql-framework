/**
 * Win32 structure WIN32_FIND_DATA
 *
 *
 * struct WIN32_FIND_DATAA {
 *    DWORD    dwFileAttributes;          //   4     => wfd[ 0]
 *    FILETIME ftCreationTime;            //   8     => wfd[ 1]
 *    FILETIME ftLastAccessTime;          //   8     => wfd[ 3]
 *    FILETIME ftLastWriteTime;           //   8     => wfd[ 5]
 *    DWORD    nFileSizeHigh;             //   4     => wfd[ 7]
 *    DWORD    nFileSizeLow;              //   4     => wfd[ 8]
 *    DWORD    dwReserved0;               //   4     => wfd[ 9]
 *    DWORD    dwReserved1;               //   4     => wfd[10]
 *    CHAR     cFileName[MAX_PATH];       // 260     => wfd[11]
 *    CHAR     cAlternateFileName[14];    //  14     => wfd[76]
 * } WIN32_FIND_DATA, wfd;                // 318 byte = int[80]      2 Byte Überhang
 */
int    wfd.FileAttributes            (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0]); }
string wfd.FileName                  (/*WIN32_FIND_DATA*/int wfd[]) { return(GetString(GetIntsAddress(wfd) +  44)); }
string wfd.AlternateFileName         (/*WIN32_FIND_DATA*/int wfd[]) { return(GetString(GetIntsAddress(wfd) + 304)); }


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
#define FILE_ATTRIBUTE_NOT_INDEXED        8192  // FILE_ATTRIBUTE_NOT_CONTENT_INDEXED ist zu lang für MQL
#define FILE_ATTRIBUTE_ENCRYPTED         16384
#define FILE_ATTRIBUTE_VIRTUAL           65536


bool   wfd.FileAttribute.ReadOnly    (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_READONLY      && 1); }
bool   wfd.FileAttribute.Hidden      (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_HIDDEN        && 1); }
bool   wfd.FileAttribute.System      (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_SYSTEM        && 1); }
bool   wfd.FileAttribute.Directory   (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_DIRECTORY     && 1); }
bool   wfd.FileAttribute.Archive     (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_ARCHIVE       && 1); }
bool   wfd.FileAttribute.Device      (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_DEVICE        && 1); }
bool   wfd.FileAttribute.Normal      (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_NORMAL        && 1); }
bool   wfd.FileAttribute.Temporary   (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_TEMPORARY     && 1); }
bool   wfd.FileAttribute.SparseFile  (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_SPARSE_FILE   && 1); }
bool   wfd.FileAttribute.ReparsePoint(/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_REPARSE_POINT && 1); }
bool   wfd.FileAttribute.Compressed  (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_COMPRESSED    && 1); }
bool   wfd.FileAttribute.Offline     (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_OFFLINE       && 1); }
bool   wfd.FileAttribute.NotIndexed  (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_NOT_INDEXED   && 1); }
bool   wfd.FileAttribute.Encrypted   (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_ENCRYPTED     && 1); }
bool   wfd.FileAttribute.Virtual     (/*WIN32_FIND_DATA*/int wfd[]) { return(wfd[0] & FILE_ATTRIBUTE_VIRTUAL       && 1); }


/**
 * Gibt die lesbare Version eines FileAttributes zurück.
 *
 * @param  int wfd[] - WIN32_FIND_DATA
 *
 * @return string
 */
string wfd.FileAttributesToStr(/*WIN32_FIND_DATA*/int wfd[]) {
   string result = "";
   int flags = wfd.FileAttributes(wfd);

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
      result = StringSubstr(result, 1);
   return(result);
}


#import "Expander.dll"
   int    wfd_FileAttributes            (/*WIN32_FIND_DATA*/int wfd[]);
   //     ...
   //     ...
   //     ...
   //     ...
   //     ...
   //     ...
   //     ...
   string wfd_FileName                  (/*WIN32_FIND_DATA*/int wfd[]);
   string wfd_AlternateFileName         (/*WIN32_FIND_DATA*/int wfd[]);

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
#import
