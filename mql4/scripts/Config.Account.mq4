/**
 * Load the current trade account configuration file into the editor. A non-existing file is created.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <win32api.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   // get the current account configuration filename
   string filename = GetAccountConfigPath();

   // make sure the file exist
   if (IsDirectory(filename, MODE_OS)) return(catch("onStart(1)  assumed config file is a directory: "+ DoubleQuoteStr(filename), ERR_FILE_IS_DIRECTORY));

   if (!IsFileA(filename)) {
      // make sure the final directory exists
      int pos = Max(StrFindR(filename, "/"), StrFindR(filename, "\\"));
      if (pos == 0)          return(catch("onStart(2)  illegal config filename "+ DoubleQuoteStr(filename), ERR_ILLEGAL_STATE));
      if (pos > 0) {
         string dir = StrLeft(filename, pos);
         int error = CreateDirectoryA(dir, MODE_OS|MODE_MKPARENT);
         if (IsError(error)) return(catch("onStart(3)  cannot create directory "+ DoubleQuoteStr(dir), ERR_WIN32_ERROR+error));
      }
      // create the file
      int hFile = CreateFileA(filename,                                 // file name
                              GENERIC_READ, FILE_SHARE_READ,            // open for shared reading
                              NULL,                                     // default security
                              CREATE_NEW,                               // create file only if it doesn't exist
                              FILE_ATTRIBUTE_NORMAL,                    // normal file
                              NULL);                                    // no attribute template
      if (hFile == INVALID_HANDLE_VALUE) {
         error = GetLastWin32Error();
         if (error != ERROR_FILE_EXISTS) return(catch("onStart(4)->CreateFileA("+ DoubleQuoteStr(filename) +")", ERR_WIN32_ERROR+error));
      }
      else {
         CloseHandle(hFile);
      }
   }

   // load the file into the editor
   EditFile(filename);

   return(catch("onStart(5)"));
}
