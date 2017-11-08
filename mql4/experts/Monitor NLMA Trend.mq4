/**
 * Monitor the market for a NonlagMA trend change and execute a trade command.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern double Lotsize = 0.1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   /*
   // initialize trade account
   if (!InitTradeAccount())
      return(last_error);

   // read trade settings
   string mqlDir   = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string file     = TerminalPath() + mqlDir +"\\files\\"+ tradeAccount.company +"\\"+ tradeAccount.number +"_config.ini";
   string section  = "TradeMonitor", keys[], stdSymbol = StdSymbol();
   int    keysSize = GetIniKeys(file, section, keys);

   for (int i=0; i < keysSize; i++) {
      debug("onInit(0.1)  "+ keys[i]);

      if (StringStartsWithI(keys[i], stdSymbol)) {
         string iniValue = GetIniString(file, section, keys[i], "");

         // schlüssel zerlegen nach "."
         // symbol vergleichen
         // trade type vergleichen: alma-trend[-(up|down)]  (periods x timframe)
         // signal-id speichern
         // nach erstem gefundenen trade setup abbrechen

         //debug("onInit(0.2)  "+ keys[i] +" = "+ iniValue);
      }
   }
   //debug("onStart(1)  keys="+ StringsToStr(keys, NULL));

   // AUDUSD.S01.nlma-trend(20xM5)      = trade-command
   // AUDUSD.S02.nlma-trend-up(20xM5)   = trade-command
   // AUDUSD.S03.nlma-trend-down(20xM5) = trade-command
   */

   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   return(last_error);
}


/**
 * Return a string presentation of the input parameters (for logging).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()  inputs: ",

                            "Lotsize=", NumberToStr(Lotsize, ".1+"), "; ")
   );
}
