/**
 * Load all configuration files of the current context into the editor. Non-existing files are created. These files are:
 *
 *  - the global user configuration (settings for all MT4 terminals)
 *  - the current terminal configuration (settings for the MT4 terminal executing this script)
 *  - the current account configuration (settings for the active MT4 trade account)
 *
 * If the "Shift" key (VK_SHIFT) is pressed during execution only the account configuration is loaded.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/win32api.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   string files[], currentAccountConfig="";
   bool isVkShift = IsVirtualKeyDown(VK_SHIFT);

   if (!isVkShift) {
      // get the global user configuration filename
      ArrayPushString(files, GetGlobalConfigPathA());

      // get the current terminal configuration filename
      ArrayPushString(files, GetTerminalConfigPathA());
   }

   // get the current account configuration filename
   currentAccountConfig = GetAccountConfigPath();
   ArrayPushString(files, currentAccountConfig);

   // get the external trade account configuration filename (if configured)
   string label = "TradeAccount";
   if (!isVkShift && ObjectFind(label)==0) {
      string account = StrTrim(ObjectDescription(label));            // format "{company-id}:{account-number}"

      if (StringLen(account) > 0) {
         string company = StrLeftTo(account, ":");
         if (!StringLen(company)) {
            logNotice("onStart(1)  invalid chart object \""+ label +"\": \""+ account +"\" (invalid company)");
         }
         string number = StrRightFrom(account, ":");
         int iNumber = StrToInteger(number);
         if (!StrIsDigits(number) || !iNumber) {
            logNotice("onStart(2)  invalid chart object \""+ label +"\": \""+ account +"\" (invalid account number)");
         }
         if (StringLen(company) && iNumber) {
            string tradeAccountConfig = GetAccountConfigPath(company, iNumber);

            if (!StrCompareI(tradeAccountConfig, currentAccountConfig)) {
               ArrayPushString(files, tradeAccountConfig);
            }
         }
      }
   }

   // make sure all files exist
   int size = ArraySize(files);
   for (int i=0; i < size; i++) {
      if (IsDirectory(files[i], MODE_SYSTEM)) {
         logError("onStart(3)  assumed config file is a directory, skipping \""+ files[i] +"\"", ERR_FILE_IS_DIRECTORY);
         ArraySpliceStrings(files, i, 1);
         size--; i--;
         continue;
      }
      if (!IsFile(files[i], MODE_SYSTEM)) {
         // make sure the final directory exists
         int pos = Max(StrFindR(files[i], "/"), StrFindR(files[i], "\\"));
         if (pos == 0)          return(catch("onStart(4)  illegal filename in files["+ i +"]: \""+ files[i] +"\"", ERR_ILLEGAL_STATE));
         if (pos > 0) {
            string dir = StrLeft(files[i], pos);
            int error = CreateDirectoryA(dir, MODE_SYSTEM|MODE_MKPARENT);
            if (IsError(error)) return(catch("onStart(5)  cannot create directory \""+ dir +"\"", ERR_WIN32_ERROR+error));
         }
         // create the file
         int hFile = CreateFileA(files[i],                                 // file name
                                 GENERIC_READ,                             // desired access: read
                                 WIN32_FILE_SHARE_READ,                    // share mode
                                 NULL,                                     // default security
                                 CREATE_NEW,                               // create file only if it doesn't exist
                                 FILE_ATTRIBUTE_NORMAL,                    // flags and attributes: normal file
                                 NULL);                                    // no template file handle
         if (hFile == INVALID_HANDLE_VALUE) {
            error = GetLastWin32Error();
            if (error != ERROR_FILE_EXISTS) return(catch("onStart(6)->CreateFileA(\""+ files[i] +"\")", ERR_WIN32_ERROR+error));
         }
         else {
            CloseHandle(hFile);
         }
      }
   }

   // load all files into the editor
   EditFiles(files);

   return(catch("onStart(7)"));
}
