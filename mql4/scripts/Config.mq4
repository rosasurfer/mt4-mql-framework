/**
 * Load all configuration files of the current context into the editor. Non-existing files are created. That's:
 *
 *  - the global MetaTrader configuration (for all terminals)
 *  - the current MT4 terminal configuration (for a single terminal)
 *  - the current trade account configuration
 *  - the external trade account configuration (if used)
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <win32api.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   string files[];

   // get the global MetaTrader configuration file
   string globalConfig = GetGlobalConfigPathA();
   ArrayPushString(files, globalConfig);

   // get the current terminal configuration file
   string terminalConfig = GetTerminalConfigPathA();
   ArrayPushString(files, terminalConfig);

   // get the current account config file
   string currentAccountConfig = GetAccountConfigPath();
   ArrayPushString(files, currentAccountConfig);

   // get the external trade account config file (if configured)
   string label = "TradeAccount";
   if (ObjectFind(label) == 0) {
      string account = StrTrim(ObjectDescription(label));            // format "{account-company}:{account-number}"

      if (StringLen(account) > 0) {
         string company = StrLeftTo(account, ":");
         if (!StringLen(company)) {
            logNotice("onStart(1)  invalid chart object "+ DoubleQuoteStr(label) +": "+ DoubleQuoteStr(account) +" (invalid company)");
         }
         string number = StrRightFrom(account, ":");
         int iNumber = StrToInteger(number);
         if (!StrIsDigit(number) || !iNumber) {
            logNotice("onStart(2)  invalid chart object "+ DoubleQuoteStr(label) +": "+ DoubleQuoteStr(account) +" (invalid account number)");
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
      if (IsDirectoryA(files[i])) {
         logError("onStart(3)  assumed config file is a directory, skipping "+ DoubleQuoteStr(files[i]), ERR_FILE_IS_DIRECTORY);
         ArraySpliceStrings(files, i, 1);
         size--; i--;
         continue;
      }
      if (!IsFileA(files[i])) {
         // make sure the final directory exists
         int pos = Max(StrFindR(files[i], "/"), StrFindR(files[i], "\\"));
         if (pos == 0)          return(catch("onStart(4)  illegal filename in files["+ i +"]: "+ DoubleQuoteStr(files[i]), ERR_ILLEGAL_STATE));
         if (pos > 0) {
            string dir = StrLeft(files[i], pos);
            int error = CreateDirectoryA(dir, MKDIR_PARENT);
            if (IsError(error)) return(catch("onStart(5)  cannot create directory "+ DoubleQuoteStr(dir), ERR_WIN32_ERROR+error));
         }
         // create the file
         int hFile = CreateFileA(files[i],                                 // file name
                                 GENERIC_READ, FILE_SHARE_READ,            // open for shared reading
                                 NULL,                                     // default security
                                 CREATE_NEW,                               // creates file only if it doesn't exist
                                 FILE_ATTRIBUTE_NORMAL,                    // normal file
                                 NULL);                                    // no attribute template
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
