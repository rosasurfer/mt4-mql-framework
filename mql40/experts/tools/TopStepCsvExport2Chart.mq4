/**
 * Helper EA to visualize the trade history of a TopStep account, exported in CSV format.
 *
 * The EA reads and parses the trade history and stores it in the framework's internal format, as if the EA traded it.
 * Then it uses the EA standard commands to show/hide the trade history.
 *
 *
 * TODO:
 *  - cache the parsed data over init cycles and convert to indicator
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern   string CsvFileName = "topstep-practice-150k.csv";
//extern string CsvFileName = "topstep-eval-50k.csv";

extern   string MapSymbol   = "";            // symbol from the CSV file to map to the chart symbol (empty: first found)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/expert.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/HandleCommands.mqh>

string Instance.ID = "999";                  // dummy, needed by StoreVolatileStatus()

// EA definitions
#include <rsf/experts/instance/defines.mqh>
#include <rsf/experts/metric/defines.mqh>
#include <rsf/experts/status/defines.mqh>
#include <rsf/experts/trade/defines.mqh>

// EA functions
#include <rsf/experts/status/ShowOpenOrders.mqh>
#include <rsf/experts/status/ShowTradeHistory.mqh>

#include <rsf/experts/status/volatile/StoreVolatileStatus.mqh>
#include <rsf/experts/status/volatile/RemoveVolatileStatus.mqh>
#include <rsf/experts/status/volatile/ToggleOpenOrders.mqh>
#include <rsf/experts/status/volatile/ToggleTradeHistory.mqh>

#include <rsf/experts/trade/AddHistoryRecord.mqh>


/**
 * Initialization.
 *
 * @return int - error status
 */
int onInit() {
   if (IsLastError()) return(last_error);
   if (__isTesting)   return(catch("onInit(1)  you can't test me", ERR_FUNC_NOT_ALLOWED_IN_TESTER));

   // enable routing of chart commands
   string label = "EA.status";
   if (ObjectFind(label) != 0) {
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
      ObjectSetText(label, "1|");
   }

   // reset the command handler
   string sNull[];
   GetChartCommand("", sNull);

   // parse the specified file
   int initReason = ProgramInitReason();
   if (initReason==IR_USER || initReason==IR_PARAMETERS || initReason==IR_TEMPLATE || initReason==IR_SYMBOLCHANGE) {
      if (ValidateInputs()) {
         string content = ReadFile(CsvFileName);
         if (content == "") return(last_error);
         ParseFileContent(content);

         // delete existing trades and show current ones
         status.showTradeHistory = true;
         if (ToggleTradeHistory(false)) {
            ToggleTradeHistory(true);
         }
      }
   }
   return(catch("onInit(1)"));
}


/**
 * Called when the expert is manually removed (Chart->Expert->Remove) or replaced.
 *
 * @return int - error status
 */
int onDeinitRemove() {
   RemoveVolatileStatus();
   return(last_error);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (__isChart) {
      if (!HandleCommands()) return(last_error);
   }
   return(catch("onTick(1)"));
}


/**
 * Process an incoming command.
 *
 * @param  string cmd    - command name
 * @param  string params - command parameters
 * @param  int    keys   - pressed modifier keys
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params, int keys) {
   string fullCmd = cmd +":"+ params +":"+ keys;
   fullCmd = StrLeftTo(fullCmd, "::0");

   if (cmd == "toggle-open-orders") {
      return(ToggleOpenOrders());
   }
   else if (cmd == "toggle-trade-history") {
      return(ToggleTradeHistory());
   }
   return(!logNotice("onCommand(1)  unsupported command: "+ DoubleQuoteStr(fullCmd)));
}


/**
 * Read the specified file into a string.
 *
 * @param  string fileName
 *
 * @return string - file content or an empty string in case of errors
 */
string ReadFile(string fileName) {
   int hFile = FileOpen(fileName, FILE_BIN|FILE_READ);
   if (hFile <= 0) return(_EMPTY_STR(catch("ReadFile(1)->FileOpen("+ DoubleQuoteStr(fileName) +") failed", intOr(GetLastError(), ERR_RUNTIME_ERROR))));

   int fileSize = FileSize(hFile);
   if (!fileSize) {
      FileClose(hFile);
      return(_EMPTY_STR(catch("ReadFile(2)  invalid file "+ DoubleQuoteStr(fileName) +" (file size: 0)", ERR_RUNTIME_ERROR)));
   }

   string content="", chunk="";
   int chunkSize = 4000;                              // MQL4.0 bug: FileReadString() stops reading after 4095 byte

   while (!FileIsEnding(hFile)) {
      chunk = FileReadString(hFile, chunkSize);
      content = StringConcatenate(content, chunk);
   }
   FileClose(hFile);

   int error = GetLastError();
   if (error && error!=ERR_END_OF_FILE) return(_EMPTY_STR(catch("ReadFile(3)", error)));
   if (fileSize != StringLen(content))  return(_EMPTY_STR(catch("ReadFile(4)  error reading file, size="+ fileSize +" vs. read-bytes="+ StringLen(content), ERR_FILE_READ_ERROR)));

   return(content);
}


/**
 * Parse the passed file content.
 *
 * @param  string content - file content
 *
 * @return bool - success status
 */
bool ParseFileContent(string content) {
   return(true);
}


/**
 * Validate input parameters. Called from onInit() only.
 *
 * @return bool - whether input parameters are valid
 */
bool ValidateInputs() {
   if (IsLastError()) return(false);

   // CsvFileName
   string fileName = StrTrim(CsvFileName);
   if (StrStartsWith(fileName, "\"") && StrEndsWith(fileName, "\"")) {
      fileName = StrTrim(StrSubstr(fileName, 1, StringLen(fileName)-2));
   }
   if (fileName == "")              return(!catch("ValidateInputs(1)  missing input parameter CsvFileName: \"\" (empty)", ERR_INVALID_PARAMETER));
   if (!IsFile(fileName, MODE_MQL)) return(!catch("ValidateInputs(2)  invalid input parameter CsvFileName: \""+ fileName +"\" (file not found)", ERR_FILE_NOT_FOUND));
   CsvFileName = fileName;

   // MapSymbol
   MapSymbol = StrToUpper(StrTrim(MapSymbol));

   return(!catch("ValidateInputs(3)"));
}


/**
 * Callback function invoked by the global error handler.
 */
void EmergencyStop() {
   // does nothing in this EA
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate(
      "CsvFileName=", DoubleQuoteStr(CsvFileName), ";", NL,
      "MapSymbol=",   DoubleQuoteStr(MapSymbol),   ";", NL
   ));
}
