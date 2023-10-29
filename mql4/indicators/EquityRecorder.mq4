/**
 * EquityRecorder
 *
 * Records the trade account's equity curve.
 *
 *
 * TODO:
 *  - document both equity curves
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string HistoryDirectory = "Synthetic-History";      // name of the directory to store recorded data
extern int    HistoryFormat    = 401;                      // written history format: 400 | 401

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <rsfHistory.mqh>
#include <functions/ComputeFloatingPnL.mqh>
#include <functions/legend.mqh>

#property indicator_chart_window
#property indicator_buffers   1                          // there's a minimum of 1 buffer
#property indicator_color1    CLR_NONE

#define I_EQUITY_ACCOUNT      0                          // equity values
#define I_EQUITY_ACCOUNT_EXT  1                          // equity values plus external assets (if configured for the account)

bool     isOpenPosition;                                 // whether we have any open positions
datetime lastTickTime;                                   // last tick time of all symbols with open positions
double   currEquity[2];                                  // current equity values
double   prevEquity[2];                                  // previous equity values
int      hSet      [2];                                  // HistorySet handles

string symbolSuffixes    [] = {".EA"                               , ".EX"                                                    };
string symbolDescriptions[] = {"Equity of account {account-number}", "Equity of account {account-number} plus external assets"};

string historyDirectory = "";                            // directory to store history data
int    historyFormat;                                    // format of new history files: 400 | 401

string indicatorName = "";
string legendLabel   = "";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // read auto-configuration
   string indicator = ProgramName();
   if (AutoConfiguration) {
      HistoryDirectory = GetConfigString(indicator, "HistoryDirectory", HistoryDirectory);
      HistoryFormat    = GetConfigInt   (indicator, "HistoryFormat",    HistoryFormat);
   }

   // validate inputs
   // HistoryDirectory
   historyDirectory = StrTrim(HistoryDirectory);
   if (IsAbsolutePath(historyDirectory))                       return(catch("onInit(1)  illegal input parameter HistoryDirectory: "+ DoubleQuoteStr(HistoryDirectory) +" (illegal directory name)", ERR_INVALID_INPUT_PARAMETER));
   int illegalChars[] = {':', '*', '?', '"', '<', '>', '|'};
   if (StrContainsChars(historyDirectory, illegalChars))       return(catch("onInit(2)  invalid input parameter HistoryDirectory: "+ DoubleQuoteStr(HistoryDirectory) +" (invalid directory name)", ERR_INVALID_INPUT_PARAMETER));
   historyDirectory = StrReplace(historyDirectory, "\\", "/");
   if (StrStartsWith(historyDirectory, "/"))                   return(catch("onInit(3)  invalid input parameter HistoryDirectory: "+ DoubleQuoteStr(HistoryDirectory) +" (must not start with a slash)", ERR_INVALID_INPUT_PARAMETER));
   if (!UseTradeServerPath(historyDirectory, "onInit(4)"))     return(last_error);

   // HistoryFormat
   if (HistoryFormat!=400 && HistoryFormat!=401)               return(catch("onInit(5)  invalid input parameter HistoryFormat: "+ HistoryFormat +" (must be 400 or 401)", ERR_INVALID_INPUT_PARAMETER));
   historyFormat = HistoryFormat;

   // setup a chart ticker (online only)
   if (!__isTesting) {
      int hWnd = __ExecutionContext[EC.hChart];
      int millis = 1000;                                 // a virtual tick every second (1000 milliseconds)
      __tickTimerId = SetupTickTimer(hWnd, millis, NULL);
      if (!__tickTimerId) return(catch("onInit(6)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
   }

   // indicator labels and display options
   legendLabel = CreateLegend();
   indicatorName = ProgramName();
   SetIndexStyle(0, DRAW_NONE, EMPTY, EMPTY, CLR_NONE);
   SetIndexLabel(0, NULL);

   return(catch("onInit(7)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   // close open history sets
   int size = ArraySize(hSet);
   for (int i=0; i < size; i++) {
      if (hSet[i] != 0) {
         int tmp = hSet[i]; hSet[i] = NULL;
         if (!HistorySet1.Close(tmp)) return(ERR_RUNTIME_ERROR);
      }
   }

   // uninstall the chart ticker
   if (__tickTimerId > NULL) {
      int id = __tickTimerId; __tickTimerId = NULL;
      if (!ReleaseTickTimer(id)) return(catch("onDeinit(1)->ReleaseTickTimer(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
   }
   return(catch("onDeinit(2)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!CalculateEquity()) return(last_error);
   if (!RecordEquity())    return(last_error);

   if (!__isSuperContext) {
      if (NE(currEquity[0], prevEquity[0], 2)) {
         ObjectSetText(legendLabel, indicatorName +"   "+ DoubleToStr(currEquity[0], 2), 9, "Arial Fett", Blue);
         int error = GetLastError();
         if (error && error!=ERR_OBJECT_DOES_NOT_EXIST)              // on ObjectDrag or opened "Properties" dialog
            return(catch("onTick(1)", error));
      }
   }
   prevEquity[0] = currEquity[0];
   prevEquity[1] = currEquity[1];
   return(last_error);
}


/**
 * Calculate current equity values.
 *
 * @return bool - success status
 */
bool CalculateEquity() {
   // calculate PL per symbol
   string symbols[];
   double profits[];
   if (!ComputeFloatingPnLs(symbols, profits)) return(false);

   // calculate current equity
   int size = ArraySize(symbols);
   double equity = AccountBalance();
   for (int error, i=0; i < size; i++) {
      equity      += profits[i];
      lastTickTime = Max(lastTickTime, MarketInfoEx(symbols[i], MODE_TIME, error, "CalculateEquity(1)")); if (error != NULL) return(false);
   }

   // store resulting equity values
   currEquity[I_EQUITY_ACCOUNT    ] = NormalizeDouble(equity, 2);
   currEquity[I_EQUITY_ACCOUNT_EXT] = NormalizeDouble(equity + GetExternalAssets(), 2);
   isOpenPosition = (size > 0);

   if (!last_error)
      return(!catch("CalculateEquity(2)"));
   return(false);
}


/**
 * Record the calculated equity values.
 *
 * @return bool - success status
 */
bool RecordEquity() {
   if (__isTesting) return(true);

   datetime now = TimeFXT(); if (!now) return(!logInfo("RecordEquity(1)->TimeFXT() => 0", ERR_RUNTIME_ERROR));
   int dow = TimeDayOfWeekEx(now);

   if (dow==SATURDAY || dow==SUNDAY) {
      if (!isOpenPosition || !prevEquity[0])              return(true);
      bool isStale = (lastTickTime < GetServerTime()-2*MINUTES);
      if (isStale && EQ(currEquity[0], prevEquity[0], 2)) return(true);
   }

   int size = ArraySize(hSet);
   for (int i=0; i < size; i++) {
      if (!hSet[i]) {
         string symbol      = StrLeft(GetAccountNumber(), 8) + symbolSuffixes[i];
         string description = StrReplace(symbolDescriptions[i], "{account-number}", GetAccountNumber());

         hSet[i] = HistorySet1.Get(symbol, historyDirectory);
         if (hSet[i] == -1)
            hSet[i] = HistorySet1.Create(symbol, description, 2, historyFormat, historyDirectory);
         if (!hSet[i]) return(false);
      }
      if (!HistorySet1.AddTick(hSet[i], now, currEquity[i], NULL)) return(false);
   }
   return(true);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("HistoryDirectory=", DoubleQuoteStr(HistoryDirectory), ";", NL,
                            "HistoryFormat=",    HistoryFormat,                    ";")
   );
}
