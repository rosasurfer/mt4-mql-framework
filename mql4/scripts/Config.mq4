/**
 * Load all currently used configuration files into the editor. That's:
 *  - the global MT4 configuration (for all terminals)
 *  - current MT4 terminal configuration (for a single terminal)
 *  - current terminal account configuration
 *  - external trading account configuration (if used by an LFX terminal)
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   string files[];

   // get the global MT4 configuration
   string globalConfig = GetGlobalConfigPathA();
   ArrayPushString(files, globalConfig);

   // get the current MT4 terminal configuration
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

   // load the files
   EditFiles(files);

   return(catch("onStart(3)"));
}
