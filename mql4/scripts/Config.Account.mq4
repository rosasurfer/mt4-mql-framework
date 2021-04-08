/**
 * Load the current account and the trading account (if any) configuration into the editor.
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
   // get the current account config file
   string currentConfig=GetAccountConfigPath(), tradeConfig="";

   // get the trade account config file (if configured)
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
            tradeConfig = GetAccountConfigPath(company, iNumber);
         }
      }
   }

   // load the files
   string files[];
   ArrayPushString(files, currentConfig);

   if (tradeConfig!="" && tradeConfig!=currentConfig) {
      ArrayPushString(files, tradeConfig);
   }
   EditFiles(files);

   return(catch("onStart(3)"));
}
