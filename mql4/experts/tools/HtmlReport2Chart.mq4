/**
 * Helper EA to visualize the trade history of an exported MT4 account statement or tester report.
 *
 *
 * TODO:
 *  - process account statements
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];
int __virtualTicks = 0;

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

//extern string HtmlFilename = "report.html";
extern string HtmlFilename = "report-with-partials.html";
//extern string HtmlFilename = "statement.html";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>

#define TYPE_TEST_REPORT         1
#define TYPE_ACCOUNT_STATEMENT   2

string Instance.ID = "999";            // dummy, needed by StoreVolatileStatus()


// EA definitions
#include <ea/functions/instance/defines.mqh>
#include <ea/functions/metric/defines.mqh>
#include <ea/functions/status/defines.mqh>
#include <ea/functions/trade/defines.mqh>

// EA functions
#include <ea/functions/status/ShowTradeHistory.mqh>

#include <ea/functions/status/volatile/StoreVolatileStatus.mqh>
#include <ea/functions/status/volatile/RemoveVolatileStatus.mqh>
#include <ea/functions/status/volatile/ToggleOpenOrders.mqh>
#include <ea/functions/status/volatile/ToggleTradeHistory.mqh>

#include <ea/functions/trade/AddHistoryRecord.mqh>


/**
 * Initialization.
 *
 * @return int - error status
 */
int onInit() {
   if (IsLastError()) return(last_error);
   if (__isTesting)   return(catch("onInit(1)  you can't test me", ERR_FUNC_NOT_ALLOWED_IN_TESTER));

   // parse the specified file
   int initReason = ProgramInitReason();
   if (initReason==IR_USER || initReason==IR_PARAMETERS || initReason==IR_TEMPLATE) {
      if (ValidateInputs()) {
         ArrayResize(history, 0);
         string content = ReadFile(HtmlFilename);
         if (content == "") return(last_error);
         ParseFileContent(content);
      }
   }

   // enable routing of chart commands
   string label = "EA.status";
   if (ObjectFind(label) != 0) {
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
      ObjectSetText(label, "1|");
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
   if (__isChart) HandleCommands();
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
 * @param  string filename
 *
 * @return string - file content or an empty string in case of errors
 */
string ReadFile(string filename) {
   int hFile = FileOpen(filename, FILE_BIN|FILE_READ);
   if (hFile <= 0) return(_EMPTY_STR(catch("ReadFile(1)->FileOpen("+ DoubleQuoteStr(filename) +") failed", intOr(GetLastError(), ERR_RUNTIME_ERROR))));

   int fileSize = FileSize(hFile);
   if (!fileSize) {
      FileClose(hFile);
      return(_EMPTY_STR(catch("ReadFile(2)  invalid file "+ DoubleQuoteStr(filename) +" (file size: 0)", ERR_RUNTIME_ERROR)));
   }

   string content="", chunk="";
   int chunkSize = 4000;                              // MQL4 bug: FileReadString() stops reading after 4095 chars

   while (!FileIsEnding(hFile)) {
      chunk = FileReadString(hFile, chunkSize);
      content = StringConcatenate(content, chunk);
   }
   FileClose(hFile);

   int error = GetLastError();
   if (error && error!=ERR_END_OF_FILE) return(_EMPTY_STR(catch("ReadFile(3)", error)));
   if (fileSize != StringLen(content))  return(_EMPTY_STR(catch("ReadFile(4)  error reading file, size: "+ fileSize +" vs. read bytes: "+ StringLen(content), ERR_FILE_READ_ERROR)));

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
   // detect file type
   string title = StrRightFrom(content, "<title>");
   if (title == "") return(!catch("ParseFileContent(1)  HtmlFile: \"<title>\" tag not found", ERR_INVALID_FILE_FORMAT));
   title = StrTrimLeft(title);

   if      (StrStartsWith(title, "Strategy Tester:")) int fileType = TYPE_TEST_REPORT;
   else if (StrStartsWith(title, "Statement:"))           fileType = TYPE_ACCOUNT_STATEMENT;
   else             return(!catch("ParseFileContent(2)  HtmlFile: unsupported \"<title>\" tag: "+ DoubleQuoteStr(StrLeft(title, 10) +"..."), ERR_INVALID_FILE_FORMAT));

   // parse file types
   if (fileType == TYPE_ACCOUNT_STATEMENT) ParseAccountStatement(content);
   else                                    ParseTestReport(content);
   return(!last_error);
}


/**
 * Parse the passed string as an account statement and store data in global arrays history[] and/or open[].
 *
 * @param  string content - file content
 *
 * @return bool - success status
 */
bool ParseAccountStatement(string content) {
   return(!catch("ParseAccountStatement(1)  not yet implemented", ERR_NOT_IMPLEMENTED));
}


/**
 * Parse the passed string as a test report and store data in global array history[].
 *
 * @param  string content - file content
 *
 * @return bool - success status
 */
bool ParseTestReport(string content) {
   // extract HTML tables
   string tables[], rows[], cells[];
   if (Explode(content, "<table ", tables, NULL) != 3) return(!catch("ParseTestReport(1)  HtmlFile: unsupported number of \"<table>\" tags: "+ (ArraySize(tables)-1), ERR_INVALID_FILE_FORMAT));
   string table1 = "<table "+ StrLeftTo(tables[1], "</table>") +"</table>";
   string table2 = "<table "+ StrLeftTo(tables[2], "</table>") +"</table>";

   // extract and validate symbol in table1
   string row1     = StrLeftTo(table1, "</tr>");
   string lastCell = StrRightFrom(row1, "<td", -1);      // <td colspan=4>GBPJPY (Great Britain Pound vs Japanese Yen)</td>
   string symbol   = StrTrim(StrLeftTo(StrLeftTo(StrRightFrom(lastCell, ">"), "<"), "("));
   if (!StrCompareI(symbol, Symbol()))                 return(!catch("ParseTestReport(2)  HtmlFile: symbol mis-match in report: "+ DoubleQuoteStr(symbol), ERR_INVALID_FILE_FORMAT));

   // split table2 into data rows
   table2 = StrLeftTo(StrRightFrom(table2, "<tr"), "</tr>", -1) +"</tr>";
   int sizeOfRows = Explode(table2, "<tr", rows, NULL);
   if (sizeOfRows < 2)                                 return(!catch("ParseTestReport(3)  HtmlFile: no trade records found in trade history", ERR_INVALID_FILE_FORMAT));

   #define I_LINE          0  // #
   #define I_TIME          1  // Time
   #define I_TYPE          2  // Type
   #define I_TICKET        3  // Order
   #define I_LOTS          4  // Size
   #define I_PRICE         5  // Price
   #define I_STOPLOSS      6  // S / L
   #define I_TAKEPROFIT    7  // T / P
   #define I_PROFIT        8  // Profit
   #define I_BALANCE       9  // Balance

   // validate above header fields
   if (Explode(StrRightFrom(rows[0], "<td"), "<td", cells, NULL) != 10)                                                return(!catch("ParseTestReport(4)  trade history: found "+ ArraySize(cells) +" header cells (expected 10)",                                           ERR_INVALID_FILE_FORMAT));
   string sLine       = StrTrim(StrLeftTo(StrRightFrom(cells[I_LINE      ], ">"), "<")); if (sLine       != "#"      ) return(!catch("ParseTestReport(5)  trade history: unexpected header of column " + (I_LINE      +1) +": \""+ sLine       +"\" (expected \"#\")",       ERR_INVALID_FILE_FORMAT));
   string sTime       = StrTrim(StrLeftTo(StrRightFrom(cells[I_TIME      ], ">"), "<")); if (sTime       != "Time"   ) return(!catch("ParseTestReport(6)  trade history: unexpected header of column " + (I_TIME      +1) +": \""+ sTime       +"\" (expected \"Time\")",    ERR_INVALID_FILE_FORMAT));
   string sType       = StrTrim(StrLeftTo(StrRightFrom(cells[I_TYPE      ], ">"), "<")); if (sType       != "Type"   ) return(!catch("ParseTestReport(7)  trade history: unexpected header of column " + (I_TYPE      +1) +": \""+ sType       +"\" (expected \"Type\")",    ERR_INVALID_FILE_FORMAT));
   string sTicket     = StrTrim(StrLeftTo(StrRightFrom(cells[I_TICKET    ], ">"), "<")); if (sTicket     != "Order"  ) return(!catch("ParseTestReport(8)  trade history: unexpected header of column " + (I_TICKET    +1) +": \""+ sTicket     +"\" (expected \"Order\")",   ERR_INVALID_FILE_FORMAT));
   string sLots       = StrTrim(StrLeftTo(StrRightFrom(cells[I_LOTS      ], ">"), "<")); if (sLots       != "Size"   ) return(!catch("ParseTestReport(9)  trade history: unexpected header of column " + (I_LOTS      +1) +": \""+ sLots       +"\" (expected \"Size\")",    ERR_INVALID_FILE_FORMAT));
   string sPrice      = StrTrim(StrLeftTo(StrRightFrom(cells[I_PRICE     ], ">"), "<")); if (sPrice      != "Price"  ) return(!catch("ParseTestReport(10)  trade history: unexpected header of column "+ (I_PRICE     +1) +": \""+ sPrice      +"\" (expected \"Price\")",   ERR_INVALID_FILE_FORMAT));
   string sStopLoss   = StrTrim(StrLeftTo(StrRightFrom(cells[I_STOPLOSS  ], ">"), "<")); if (sStopLoss   != "S / L"  ) return(!catch("ParseTestReport(11)  trade history: unexpected header of column "+ (I_STOPLOSS  +1) +": \""+ sStopLoss   +"\" (expected \"S / L\")",   ERR_INVALID_FILE_FORMAT));
   string sTakeProfit = StrTrim(StrLeftTo(StrRightFrom(cells[I_TAKEPROFIT], ">"), "<")); if (sTakeProfit != "T / P"  ) return(!catch("ParseTestReport(12)  trade history: unexpected header of column "+ (I_TAKEPROFIT+1) +": \""+ sTakeProfit +"\" (expected \"T / P\")",   ERR_INVALID_FILE_FORMAT));
   string sProfit     = StrTrim(StrLeftTo(StrRightFrom(cells[I_PROFIT    ], ">"), "<")); if (sProfit     != "Profit" ) return(!catch("ParseTestReport(13)  trade history: unexpected header of column "+ (I_PROFIT    +1) +": \""+ sProfit     +"\" (expected \"Profit\")",  ERR_INVALID_FILE_FORMAT));
   string sBalance    = StrTrim(StrLeftTo(StrRightFrom(cells[I_BALANCE   ], ">"), "<")); if (sBalance    != "Balance") return(!catch("ParseTestReport(14)  trade history: unexpected header of column "+ (I_BALANCE   +1) +": \""+ sBalance    +"\" (expected \"Balance\")", ERR_INVALID_FILE_FORMAT));

   datetime dtTime;
   int iLine, iTicket, iType;
   double dLots, dPrice, dStopLoss, dTakeProfit, dProfit, dBalance;
   string sTypes[] = {"buy", "sell", "t/p", "s/l", "close at stop"};

   // process all data rows
   for (int i=1; i < sizeOfRows; i++) {
      rows[i] = StrReplace(rows[i], " colspan=2>", "></td><td>");
      if (Explode(StrRightFrom(rows[i], "<td"), "<td", cells, NULL) != 10)                                                  return(!catch("ParseTestReport(15)  trade history: found "+ ArraySize(cells) +" cells in row "+ i +" (expected 10)", ERR_INVALID_FILE_FORMAT));

      // parse and validate a single row
      sLine = StrTrim(StrLeftTo(StrRightFrom(cells[I_LINE], ">"), "<")); if (!StrIsDigits(sLine))                           return(!catch("ParseTestReport(16)  trade history: unexpected \"Line\" number in row "+ i +", col "+ (I_LINE+1) +": \""+ sLine +"\" (expected digits only)", ERR_INVALID_FILE_FORMAT));
      iLine = StrToInteger(sLine);

      sTime = StrTrim(StrLeftTo(StrRightFrom(cells[I_TIME], ">"), "<"));
      dtTime = StrToTime(sTime); if (TimeToStr(dtTime) != sTime)                                                            return(!catch("ParseTestReport(17)  trade history: unexpected \"Time\" value in row "+ i +", col "+ (I_TIME+1) +": \""+ sTime +"\" (expected datetime)", ERR_INVALID_FILE_FORMAT));

      sType = StrTrim(StrLeftTo(StrRightFrom(cells[I_TYPE], ">"), "<")); if (!StringInArray(sTypes, sType))                 return(!catch("ParseTestReport(18)  trade history: unsupported \"Type\" value in row "+ i +", col "+ (I_TYPE+1) +": \""+ sType +"\"", ERR_INVALID_FILE_FORMAT));

      sTicket = StrTrim(StrLeftTo(StrRightFrom(cells[I_TICKET], ">"), "<")); if (!StrIsDigits(sTicket))                     return(!catch("ParseTestReport(19)  trade history: unexpected \"Order\" value in row "+ i +", col "+ (I_TICKET+1) +": \""+ sTicket +"\" (expected digits only)", ERR_INVALID_FILE_FORMAT));
      iTicket = StrToInteger(sTicket);                                       if (!iTicket)                                  return(!catch("ParseTestReport(20)  trade history: invalid \"Order\" value in row "+ i +", col "+ (I_TICKET+1) +": \""+ sTicket +"\" (expected positive integer)", ERR_INVALID_FILE_FORMAT));

      sLots = StrTrim(StrLeftTo(StrRightFrom(cells[I_LOTS], ">"), "<")); if (!StrIsNumeric(sLots))                          return(!catch("ParseTestReport(21)  trade history: unexpected \"Size\" value in row "+ i +", col "+ (I_LOTS+1) +": \""+ sLots +"\" (expected positive numeric value)", ERR_INVALID_FILE_FORMAT));
      dLots = StrToDouble(sLots);                                        if (dLots <= 0)                                    return(!catch("ParseTestReport(22)  trade history: unexpected \"Size\" value in row "+ i +", col "+ (I_LOTS+1) +": \""+ sLots +"\" (expected positive numeric value)", ERR_INVALID_FILE_FORMAT));

      sPrice = StrTrim(StrLeftTo(StrRightFrom(cells[I_PRICE], ">"), "<")); if (!StrIsNumeric(sPrice))                       return(!catch("ParseTestReport(23)  trade history: unexpected \"Price\" value in row "+ i +", col "+ (I_PRICE+1) +": \""+ sPrice +"\" (expected positive price value)", ERR_INVALID_FILE_FORMAT));
      dPrice = StrToDouble(sPrice);                                        if (dPrice <= 0)                                 return(!catch("ParseTestReport(24)  trade history: unexpected \"Price\" value in row "+ i +", col "+ (I_PRICE+1) +": \""+ sPrice +"\" (expected positive price value)", ERR_INVALID_FILE_FORMAT));

      sStopLoss = StrTrim(StrLeftTo(StrRightFrom(cells[I_STOPLOSS], ">"), "<")); if (!StrIsNumeric(sStopLoss))              return(!catch("ParseTestReport(25)  trade history: unexpected \"S/L\" value in row "+ i +", col "+ (I_STOPLOSS+1) +": \""+ sStopLoss +"\" (expected stoploss value)", ERR_INVALID_FILE_FORMAT));
      dStopLoss = StrToDouble(sStopLoss);                                        if (dStopLoss <= 0)                        return(!catch("ParseTestReport(26)  trade history: unexpected \"S/L\" value in row "+ i +", col "+ (I_STOPLOSS+1) +": \""+ sStopLoss +"\" (expected stoploss value)", ERR_INVALID_FILE_FORMAT));

      sTakeProfit = StrTrim(StrLeftTo(StrRightFrom(cells[I_TAKEPROFIT], ">"), "<")); if (!StrIsNumeric(sTakeProfit))        return(!catch("ParseTestReport(27)  trade history: unexpected \"T/P\" value in row "+ i +", col "+ (I_TAKEPROFIT+1) +": \""+ sTakeProfit +"\" (expected takeprofit value)", ERR_INVALID_FILE_FORMAT));
      dTakeProfit = StrToDouble(sTakeProfit);                                        if (dTakeProfit <= 0)                  return(!catch("ParseTestReport(28)  trade history: unexpected \"T/P\" value in row "+ i +", col "+ (I_TAKEPROFIT+1) +": \""+ sTakeProfit +"\" (expected takeprofit value)", ERR_INVALID_FILE_FORMAT));

      sProfit = StrTrim(StrLeftTo(StrRightFrom(cells[I_PROFIT], ">"), "<")); if (sProfit!="" && !StrIsNumeric(sProfit))     return(!catch("ParseTestReport(29)  trade history: unexpected \"Profit\" value in row "+ i +", col "+ (I_PROFIT+1) +": \""+ sProfit +"\" (expected numeric value)", ERR_INVALID_FILE_FORMAT));
      dProfit = StrToDouble(sProfit);

      sBalance = StrTrim(StrLeftTo(StrRightFrom(cells[I_BALANCE], ">"), "<")); if (sBalance!="" && !StrIsNumeric(sBalance)) return(!catch("ParseTestReport(30)  trade history: unexpected \"Balance\" value in row "+ i +", col "+ (I_BALANCE+1) +": \""+ sBalance +"\" (expected positive numeric value)", ERR_INVALID_FILE_FORMAT));
      dBalance = StrToDouble(sBalance);                                        if (dBalance < 0)                            return(!catch("ParseTestReport(31)  trade history: unexpected \"Balance\" value in row "+ i +", col "+ (I_BALANCE+1) +": \""+ sBalance +"\" (expected positive numeric value)", ERR_INVALID_FILE_FORMAT));

      if (sType=="buy" || sType=="sell") {               // position open: add new history record
         iType = ifInt(sType=="buy", OP_BUY, OP_SELL);
         if (AddHistoryRecord(iTicket, 0, 0, iType, dLots, 1, dtTime, dPrice, 0, dStopLoss, dTakeProfit, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) == EMPTY) return(false);
      }
      else {                                             // position close: update existing history record
         if (!UpdateHistoryRecord(iTicket, dStopLoss, dTakeProfit, dtTime, dPrice, dProfit)) return(false);
      }
   }
   return(!catch("ParseTestReport(32)"));
}


/**
 * Update an existing history record.
 *
 * @param  int      ticket
 * @param  double   stopLoss
 * @param  double   takeProfit
 * @param  datetime closeTime
 * @param  double   closePrice
 * @param  double   netProfit
 *
 * @return bool - success status
 */
bool UpdateHistoryRecord(int ticket, double stopLoss, double takeProfit, datetime closeTime, double closePrice, double netProfit) {
   int size = ArrayRange(history, 0);

   // find the ticket to update
   for (int i=size-1; i >= 0; i--) {                  // iterate from the end (in most use cases faster)
      if (ticket == history[i][H_TICKET]) break;
   }
   if (i < 0) return(!catch("UpdateHistoryRecord(1)  ticket #"+ ticket +" not found", ERR_INVALID_PARAMETER));

   // update the record
   history[i][H_STOPLOSS   ] = stopLoss;
   history[i][H_TAKEPROFIT ] = takeProfit;
   history[i][H_CLOSETIME  ] = closeTime;
   history[i][H_CLOSEPRICE ] = closePrice;
   history[i][H_NETPROFIT_M] = netProfit;
   return(true);
}


/**
 * Validate input parameters. Called from onInit() only.
 *
 * @return bool - whether input parameters are valid
 */
bool ValidateInputs() {
   if (IsLastError()) return(false);

   // HtmlFilename
   string filename = StrTrim(HtmlFilename);
   if (StrStartsWith(filename, "\"") && StrEndsWith(filename, "\"")) {
      filename = StrTrim(StrSubstr(filename, 1, StringLen(filename)-2));
   }
   if (filename == "")              return(!catch("ValidateInputs(1)  missing input parameter HtmlFilename: \"\" (empty)", ERR_INVALID_PARAMETER));
   if (!IsFile(filename, MODE_MQL)) return(!catch("ValidateInputs(2)  invalid input parameter HtmlFilename: "+ DoubleQuoteStr(filename) +" (file not found)", ERR_FILE_NOT_FOUND));
   HtmlFilename = filename;

   return(!catch("ValidateInputs(3)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("HtmlFilename=", DoubleQuoteStr(HtmlFilename), ";"));
}
