/**
 * Helper EA to visualize the trade history of an MT4 account statement or a Strategy Tester report.
 *
 *
 * TODO
 *  - account statements
 *     process open orders
 *     on-load initialize display status with "show"
 *  - optional timezone configs (2) for runtime and statement server
 *  - cache the parsed data over init cycles
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];
int __virtualTicks = 0;

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

//extern string HtmlFilename = "report.html";
//extern string HtmlFilename = "report-with-partials.html";
//extern string HtmlFilename = "statement.html";
extern   string HtmlFilename = "ff-statement.html";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/expert.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/HandleCommands.mqh>

#define TYPE_TEST_REPORT         1
#define TYPE_ACCOUNT_STATEMENT   2

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
   string sValues[];
   GetChartCommand("", sValues);

   // parse the specified file
   int initReason = ProgramInitReason();
   if (initReason==IR_USER || initReason==IR_PARAMETERS || initReason==IR_TEMPLATE || initReason==IR_SYMBOLCHANGE) {
      if (ValidateInputs()) {
         string content = ReadFile(HtmlFilename);
         if (content == "") return(last_error);
         ParseFileContent(content);
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
   if (__isChart) if (!HandleCommands()) return(last_error);
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
      return(_EMPTY_STR(catch("ReadFile(2)  invalid file "+ DoubleQuoteStr(filename) +" (size: 0)", ERR_RUNTIME_ERROR)));
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
   // detect file type
   string title = StrRightFrom(content, "<title>");
   if (title == "") return(!catch("ParseFileContent(1)  HtmlFile: \"<title>\" tag not found", ERR_INVALID_FILE_FORMAT));
   title = StrTrimLeft(title);

   if      (StrStartsWith(title, "Strategy Tester:")) int fileType = TYPE_TEST_REPORT;
   else if (StrStartsWith(title, "Statement:"))           fileType = TYPE_ACCOUNT_STATEMENT;
   else return(!catch("ParseFileContent(2)  unsupported file type (unknown <title> "+ DoubleQuoteStr(StrLeft(title, 12) +"..."), ERR_INVALID_FILE_FORMAT));

   logInfo("ParseFileContent(3)  detected file type: "+ ifString(fileType == TYPE_TEST_REPORT, "test report", "account statement"));

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
   // extract HTML table
   string tables[], rows[], cells[], sValues[];
   if (Explode(content, "<table ", tables, NULL) != 2)      return(!catch("ParseAccountStatement(1)  HtmlFile: unsupported number of \"<table>\" tags: "+ (ArraySize(tables)-1), ERR_INVALID_FILE_FORMAT));
   string table = "<table "+ StrLeftTo(tables[1], "</table>") +"</table>";

   // split table into rows
   table = StrLeftTo(StrRightFrom(table, "<tr"), "</tr>", -1) +"</tr>";
   int sizeOfRows = Explode(table, "<tr", rows, NULL);
   if (sizeOfRows < 2)                                      return(!catch("ParseAccountStatement(2)  HtmlFile: no rows found in HTML table", ERR_INVALID_FILE_FORMAT));

   // extract rows with closed transactions
   if (!StrContains(rows[1], "Closed Transactions:"))       return(!catch("ParseAccountStatement(3)  HtmlFile: begin of section \"Closed Transactions\" not found in HTML table", ERR_INVALID_FILE_FORMAT));
   for (int i=2; i < sizeOfRows; i++) {
      if (StrContains(rows[i], "Closed P/L:")) break;
   }
   if (i == sizeOfRows)                                     return(!catch("ParseAccountStatement(4)  HtmlFile: end of section \"Closed Transactions\" not found in HTML table", ERR_INVALID_FILE_FORMAT));
   if (ArraySpliceStrings(rows, i-1, sizeOfRows-i+1) == -1) return(false);    // discard summary rows at the end
   if (ArraySpliceStrings(rows, 0, 2)                == -1) return(false);    // discard intro rows at the beginning
   sizeOfRows = ArraySize(rows);

   logInfo("ParseAccountStatement(5)  found data rows: "+ sizeOfRows);

   #define AS_TICKET        0    // ticket
   #define AS_OPENTIME      1    // open time (may/may not contain seconds)
   #define AS_TYPE          2    // type
   #define AS_LOTS          3    // size
   #define AS_SYMBOL        4    // item
   #define AS_OPENPRICE     5    // open price
   #define AS_STOPLOSS      6    // stoploss
   #define AS_TAKEPROFIT    7    // takeprofit
   #define AS_CLOSETIME     8    // close time (may/may not contain seconds)
   #define AS_CLOSEPRICE    9    // close price
   #define AS_COMMISSION   10    // commission
   #define AS_TAX          11    // taxes
   #define AS_SWAP         12    // swap
   #define AS_PROFIT       13    // profit

   #define AS_MAGICNUMBER   1    // magic number (if any)
   #define AS_COMMENT       2    // comment (if any)

   // parse/validate header fields
   if (Explode(StrRightFrom(rows[0], "<td"), "<td", cells, NULL) != 14)                                                    return(!catch("ParseAccountStatement(6)  trade history: found "+ ArraySize(cells) +" header cells (expected 14)",                                               ERR_INVALID_FILE_FORMAT));
   string sTicket     = StrTrim(StrLeftTo(StrRightFrom(cells[AS_TICKET    ], ">"), "<")); if (sTicket     != "Ticket"    ) return(!catch("ParseAccountStatement(7)  trade history: unexpected header of column " + (AS_TICKET    +1) +": \""+ sTicket     +"\" (expected \"Ticket\")",     ERR_INVALID_FILE_FORMAT));
   string sOpenTime   = StrTrim(StrLeftTo(StrRightFrom(cells[AS_OPENTIME  ], ">"), "<")); if (sOpenTime   != "Open Time" ) return(!catch("ParseAccountStatement(8)  trade history: unexpected header of column " + (AS_OPENTIME  +1) +": \""+ sOpenTime   +"\" (expected \"Open Time\")",  ERR_INVALID_FILE_FORMAT));
   string sType       = StrTrim(StrLeftTo(StrRightFrom(cells[AS_TYPE      ], ">"), "<")); if (sType       != "Type"      ) return(!catch("ParseAccountStatement(9)  trade history: unexpected header of column " + (AS_TYPE      +1) +": \""+ sType       +"\" (expected \"Type\")",       ERR_INVALID_FILE_FORMAT));
   string sLots       = StrTrim(StrLeftTo(StrRightFrom(cells[AS_LOTS      ], ">"), "<")); if (sLots       != "Size"      ) return(!catch("ParseAccountStatement(10)  trade history: unexpected header of column " + (AS_LOTS      +1) +": \""+ sLots       +"\" (expected \"Size\")",       ERR_INVALID_FILE_FORMAT));
   string sSymbol     = StrTrim(StrLeftTo(StrRightFrom(cells[AS_SYMBOL    ], ">"), "<")); if (sSymbol     != "Item"      ) return(!catch("ParseAccountStatement(11)  trade history: unexpected header of column "+ (AS_SYMBOL    +1) +": \""+ sSymbol     +"\" (expected \"Item\")",       ERR_INVALID_FILE_FORMAT));
   string sOpenPrice  = StrTrim(StrLeftTo(StrRightFrom(cells[AS_OPENPRICE ], ">"), "<")); if (sOpenPrice  != "Price"     ) return(!catch("ParseAccountStatement(12)  trade history: unexpected header of column "+ (AS_OPENPRICE +1) +": \""+ sOpenPrice  +"\" (expected \"Price\")",      ERR_INVALID_FILE_FORMAT));
   string sStopLoss   = StrTrim(StrLeftTo(StrRightFrom(cells[AS_STOPLOSS  ], ">"), "<")); if (sStopLoss   != "S / L"     ) return(!catch("ParseAccountStatement(13)  trade history: unexpected header of column "+ (AS_STOPLOSS  +1) +": \""+ sStopLoss   +"\" (expected \"S / L\")",      ERR_INVALID_FILE_FORMAT));
   string sTakeProfit = StrTrim(StrLeftTo(StrRightFrom(cells[AS_TAKEPROFIT], ">"), "<")); if (sTakeProfit != "T / P"     ) return(!catch("ParseAccountStatement(14)  trade history: unexpected header of column "+ (AS_TAKEPROFIT+1) +": \""+ sTakeProfit +"\" (expected \"T / P\")",      ERR_INVALID_FILE_FORMAT));
   string sCloseTime  = StrTrim(StrLeftTo(StrRightFrom(cells[AS_CLOSETIME ], ">"), "<")); if (sCloseTime  != "Close Time") return(!catch("ParseAccountStatement(15)  trade history: unexpected header of column "+ (AS_CLOSETIME +1) +": \""+ sCloseTime  +"\" (expected \"Close Time\")", ERR_INVALID_FILE_FORMAT));
   string sClosePrice = StrTrim(StrLeftTo(StrRightFrom(cells[AS_CLOSEPRICE], ">"), "<")); if (sClosePrice != "Price"     ) return(!catch("ParseAccountStatement(16)  trade history: unexpected header of column "+ (AS_CLOSEPRICE+1) +": \""+ sClosePrice +"\" (expected \"Price\")",      ERR_INVALID_FILE_FORMAT));
   string sCommission = StrTrim(StrLeftTo(StrRightFrom(cells[AS_COMMISSION], ">"), "<")); if (sCommission != "Commission") return(!catch("ParseAccountStatement(17)  trade history: unexpected header of column "+ (AS_COMMISSION+1) +": \""+ sCommission +"\" (expected \"Commission\")", ERR_INVALID_FILE_FORMAT));
   string sTax        = StrTrim(StrLeftTo(StrRightFrom(cells[AS_TAX       ], ">"), "<")); if (sTax        != "Taxes"     ) return(!catch("ParseAccountStatement(18)  trade history: unexpected header of column "+ (AS_TAX       +1) +": \""+ sTax        +"\" (expected \"Taxes\")",      ERR_INVALID_FILE_FORMAT));
   string sSwap       = StrTrim(StrLeftTo(StrRightFrom(cells[AS_SWAP      ], ">"), "<")); if (sSwap       != "Swap"      ) return(!catch("ParseAccountStatement(19)  trade history: unexpected header of column "+ (AS_SWAP      +1) +": \""+ sSwap       +"\" (expected \"Swap\")",       ERR_INVALID_FILE_FORMAT));
   string sProfit     = StrTrim(StrLeftTo(StrRightFrom(cells[AS_PROFIT    ], ">"), "<")); if (sProfit     != "Profit"    ) return(!catch("ParseAccountStatement(20)  trade history: unexpected header of column "+ (AS_PROFIT    +1) +": \""+ sProfit     +"\" (expected \"Profit\")",     ERR_INVALID_FILE_FORMAT));

   int iCells, iTicket, iMagicNumber, iType, n;
   bool timesWithSeconds=-1, closedByTP, closedBySL, cancelled;
   datetime dtOpenTime, dtCloseTime;
   double dLots, dOpenPrice, dClosePrice, dStopLoss, dTakeProfit, dCommission, dTax, dSwap, dProfit;
   string symbol="", sTitle="", sMagicNumber="", sComment="", sValue="", sTypes[] = {"buy", "sell"};

   ArrayResize(history, 0);

   // process all data rows
   for (i=1; i < sizeOfRows; i++) {
      iCells = Explode(StrRightFrom(rows[i], "<td"), "<td", cells, NULL);

      // parse non-trade rows
      if (iCells == 3) {                     // trade details after a trade
         if (!iTicket)                                                                                                return(!catch("ParseAccountStatement(21)  trade history: found 3 data cells in row "+ (i+1) +" after non-trade row", ERR_INVALID_FILE_FORMAT));
         // col 1: empty
         sTicket = StrTrim(StrReplace(StrLeftTo(StrRightFrom(cells[AS_TICKET], ">"), "<"), "&nbsp;", " "));
         if (sTicket != "")                                                                                           return(!catch("ParseAccountStatement(22)  trade history: unexpected ticket value in trade detail row "+ (i+1) +", col "+ (AS_TICKET+1) +": \""+ sTicket +"\"", ERR_INVALID_FILE_FORMAT));
         // col 2: magic number (if any)
         sMagicNumber = StrTrim(StrReplace(StrLeftTo(StrRightFrom(cells[AS_MAGICNUMBER], ">"), "<"), "&nbsp;", " "));
         if (sMagicNumber != "") {
            if (!StrIsDigits(sMagicNumber))                                                                           return(!catch("ParseAccountStatement(23)  trade history: unsupported magic number in trade detail row "+ (i+1) +", col "+ (AS_MAGICNUMBER+1) +": \""+ sMagicNumber +"\" (expected digits only)", ERR_INVALID_FILE_FORMAT));
            iMagicNumber = StrToInteger(sMagicNumber); if (!iMagicNumber)                                             return(!catch("ParseAccountStatement(24)  trade history: invalid magic number in row "+ (i+1) +", col "+ (AS_MAGICNUMBER+1) +": \""+ sMagicNumber +"\" (expected positive integer)", ERR_INVALID_FILE_FORMAT));
            if (!StrStartsWith(sTitle, "#"+ iMagicNumber))                                                            return(!catch("ParseAccountStatement(25)  trade history: magic number mis-match in rows "+ i +" and "+ (i+1) +": \""+ sTitle +"\" vs. #"+ iMagicNumber, ERR_INVALID_FILE_FORMAT));
         }
         // col 3: trade comment (if any)    // TODO: convert all HTML entities
         sComment = StrTrim(StrReplace(StrLeftTo(StrRightFrom(cells[AS_COMMENT], ">"), "<"), "&nbsp;", " "));
         if (sComment != "") if (!StrEndsWith(sTitle, sComment))                                                      return(!catch("ParseAccountStatement(26)  trade history: comment mis-match in rows "+ i +" and "+ (i+1) +": \""+ sTitle +"\" vs. \""+ sComment +"\"", ERR_INVALID_FILE_FORMAT));
         iTicket = NULL;
         continue;
      }
      else if (iCells == 5) {
         iTicket = NULL;
         sType = StrTrim(StrLeftTo(StrRightFrom(cells[AS_TYPE], ">"), "<"));
         if (sType == "balance") continue;
         return(!catch("ParseAccountStatement(27)  trade history: unsupported type value \""+ sType +"\" in row "+ (i+1), ERR_INVALID_FILE_FORMAT));
      }
      else if (iCells == 11) {
         iTicket = NULL;
         cancelled = StrContains(cells[AS_TICKET], " title=\"cancelled\"");
         sValue = StrTrim(StrLeftTo(StrRightFrom(cells[AS_COMMISSION], ">"), "<"));
         if (cancelled && sValue=="cancelled") continue;
         return(!catch("ParseAccountStatement(28)  trade history: unsupported commission value \""+ sValue +"\" for cancelled order in row "+ (i+1), ERR_INVALID_FILE_FORMAT));
      }
      if (iCells != 14) return(!catch("ParseAccountStatement(29)  trade history: found "+ ArraySize(cells) +" data cells in row "+ (i+1) +" (expected 14)", ERR_INVALID_FILE_FORMAT));
      iTicket = NULL;

      // parse a trade row
      sTicket    = StrTrim(StrLeftTo(StrRightFrom(cells[AS_TICKET], ">"), "<")); if (!StrIsDigits(sTicket))           return(!catch("ParseAccountStatement(30)  trade history: unexpected \"Ticket\" value in row "+ (i+1) +", col "+ (AS_TICKET+1) +": \""+ sTicket +"\" (expected digits only)", ERR_INVALID_FILE_FORMAT));
      iTicket    = StrToInteger(sTicket);                                        if (!iTicket)                        return(!catch("ParseAccountStatement(31)  trade history: invalid \"Ticket\" value in row "+ (i+1) +", col "+ (AS_TICKET+1) +": \""+ sTicket +"\" (expected positive integer)", ERR_INVALID_FILE_FORMAT));

      sTitle     = StrTrim(StrLeftTo(StrRightFrom(cells[AS_TICKET], " title=\""), "\""));
      closedBySL = StrEndsWithI(sTitle, "[sl]");
      closedByTP = StrEndsWithI(sTitle, "[tp]");

      sOpenTime = StrTrim(StrLeftTo(StrRightFrom(cells[AS_OPENTIME], ">"), "<"));
      if (timesWithSeconds == -1) {
         int size = Explode(sOpenTime, ":", sValues, NULL);       // check for seconds on first trade
         if (size < 2 || size > 3)                                                                                    return(!catch("ParseAccountStatement(32)  trade history: unexpected \"Open Time\" value in row "+ (i+1) +", col "+ (AS_OPENTIME+1) +": \""+ sOpenTime +"\" (expected datetime)", ERR_INVALID_FILE_FORMAT));
         timesWithSeconds = (size == 3);
      }
      dtOpenTime = StrToTime(sOpenTime);                          // may or may not contain seconds
      if (TimeToStr(dtOpenTime, ifInt(timesWithSeconds, TIME_FULL, TIME_DATE|TIME_MINUTES)) != sOpenTime)             return(!catch("ParseAccountStatement(33)  trade history: unexpected \"Open Time\" value in row "+ (i+1) +", col "+ (AS_OPENTIME+1) +": \""+ sOpenTime +"\" (expected datetime)", ERR_INVALID_FILE_FORMAT));

      sType = StrTrim(StrLeftTo(StrRightFrom(cells[AS_TYPE], ">"), "<")); if (!StringInArray(sTypes, sType))          return(!catch("ParseAccountStatement(34)  trade history: unsupported \"Type\" value in row "+ (i+1) +", col "+ (AS_TYPE+1) +": \""+ sType +"\"", ERR_INVALID_FILE_FORMAT));
      iType = ifInt(sType=="buy", OP_BUY, OP_SELL);

      sLots = StrTrim(StrLeftTo(StrRightFrom(cells[AS_LOTS], ">"), "<")); if (!StrIsNumeric(sLots))                   return(!catch("ParseAccountStatement(35)  trade history: unexpected \"Size\" value in row "+ (i+1) +", col "+ (AS_LOTS+1) +": \""+ sLots +"\" (expected numeric value)", ERR_INVALID_FILE_FORMAT));
      dLots = StrToDouble(sLots);                                         if (dLots <= 0)                             return(!catch("ParseAccountStatement(36)  trade history: unexpected \"Size\" value in row "+ (i+1) +", col "+ (AS_LOTS+1) +": \""+ sLots +"\" (expected positive value)", ERR_INVALID_FILE_FORMAT));

      symbol = StrTrim(StrLeftTo(StrRightFrom(cells[AS_SYMBOL], ">"), "<"));

      sOpenPrice = StrTrim(StrLeftTo(StrRightFrom(cells[AS_OPENPRICE], ">"), "<")); if (!StrIsNumeric(sOpenPrice))    return(!catch("ParseAccountStatement(37)  trade history: unexpected \"Price\" value in row "+ (i+1) +", col "+ (AS_OPENPRICE+1) +": \""+ sOpenPrice +"\" (expected numeric value)", ERR_INVALID_FILE_FORMAT));
      dOpenPrice = StrToDouble(sOpenPrice);                                         if (dOpenPrice <= 0)              return(!catch("ParseAccountStatement(38)  trade history: unexpected \"Price\" value in row "+ (i+1) +", col "+ (AS_OPENPRICE+1) +": \""+ sOpenPrice +"\" (expected positive value)", ERR_INVALID_FILE_FORMAT));

      sStopLoss = StrTrim(StrLeftTo(StrRightFrom(cells[AS_STOPLOSS], ">"), "<")); if (!StrIsNumeric(sStopLoss))       return(!catch("ParseAccountStatement(39)  trade history: unexpected \"S/L\" value in row "+ (i+1) +", col "+ (AS_STOPLOSS+1) +": \""+ sStopLoss +"\" (expected numeric value)", ERR_INVALID_FILE_FORMAT));
      dStopLoss = StrToDouble(sStopLoss);                                         if (dStopLoss < 0)                  return(!catch("ParseAccountStatement(40)  trade history: unexpected \"S/L\" value in row "+ (i+1) +", col "+ (AS_STOPLOSS+1) +": \""+ sStopLoss +"\" (expected non-negative value)", ERR_INVALID_FILE_FORMAT));

      sTakeProfit = StrTrim(StrLeftTo(StrRightFrom(cells[AS_TAKEPROFIT], ">"), "<")); if (!StrIsNumeric(sTakeProfit)) return(!catch("ParseAccountStatement(41)  trade history: unexpected \"T/P\" value in row "+ (i+1) +", col "+ (AS_TAKEPROFIT+1) +": \""+ sTakeProfit +"\" (expected numeric value)", ERR_INVALID_FILE_FORMAT));
      dTakeProfit = StrToDouble(sTakeProfit);                                         if (dTakeProfit < 0)            return(!catch("ParseAccountStatement(42)  trade history: unexpected \"T/P\" value in row "+ (i+1) +", col "+ (AS_TAKEPROFIT+1) +": \""+ sTakeProfit +"\" (expected non-negative value)", ERR_INVALID_FILE_FORMAT));

      sCloseTime  = StrTrim(StrLeftTo(StrRightFrom(cells[AS_CLOSETIME], ">"), "<"));
      dtCloseTime = StrToTime(sCloseTime);                        // may or may not contain seconds
      if (TimeToStr(dtCloseTime, ifInt(timesWithSeconds, TIME_FULL, TIME_DATE|TIME_MINUTES)) != sCloseTime)           return(!catch("ParseAccountStatement(43)  trade history: unexpected \"Close Time\" value in row "+ (i+1) +", col "+ (AS_CLOSETIME+1) +": \""+ sCloseTime +"\" (expected datetime)", ERR_INVALID_FILE_FORMAT));

      sClosePrice = StrTrim(StrLeftTo(StrRightFrom(cells[AS_CLOSEPRICE], ">"), "<")); if (!StrIsNumeric(sClosePrice)) return(!catch("ParseAccountStatement(44)  trade history: unexpected \"Price\" value in row "+ (i+1) +", col "+ (AS_CLOSEPRICE+1) +": \""+ sClosePrice +"\" (expected numeric value)", ERR_INVALID_FILE_FORMAT));
      dClosePrice = StrToDouble(sClosePrice);                                         if (dClosePrice <= 0)           return(!catch("ParseAccountStatement(45)  trade history: unexpected \"Price\" value in row "+ (i+1) +", col "+ (AS_CLOSEPRICE+1) +": \""+ sClosePrice +"\" (expected positive value)", ERR_INVALID_FILE_FORMAT));

      sCommission = StrTrim(StrLeftTo(StrRightFrom(cells[AS_COMMISSION], ">"), "<")); if (!StrIsNumeric(sCommission)) return(!catch("ParseAccountStatement(46)  trade history: unexpected \"Commission\" value in row "+ (i+1) +", col "+ (AS_COMMISSION+1) +": \""+ sCommission +"\" (expected numeric value)", ERR_INVALID_FILE_FORMAT));
      dCommission = StrToDouble(sCommission);                                         if (dCommission > 0)            return(!catch("ParseAccountStatement(47)  trade history: unexpected \"Commission\" value in row "+ (i+1) +", col "+ (AS_COMMISSION+1) +": \""+ sCommission +"\" (expected non-positive value)", ERR_INVALID_FILE_FORMAT));

      sTax = StrTrim(StrLeftTo(StrRightFrom(cells[AS_TAX], ">"), "<")); if (!StrIsNumeric(sTax))                      return(!catch("ParseAccountStatement(48)  trade history: unexpected \"Taxes\" value in row "+ (i+1) +", col "+ (AS_TAX+1) +": \""+ sTax +"\" (expected numeric value)", ERR_INVALID_FILE_FORMAT));
      dTax = StrToDouble(sTax);                                         if (dTax != 0)                                return(!catch("ParseAccountStatement(49)  trade history: unexpected \"Taxes\" value in row "+ (i+1) +", col "+ (AS_TAX+1) +": \""+ sTax +"\" (expected 0.00)", ERR_INVALID_FILE_FORMAT));

      sSwap = StrTrim(StrLeftTo(StrRightFrom(cells[AS_SWAP], ">"), "<")); if (!StrIsNumeric(sSwap))                   return(!catch("ParseAccountStatement(50)  trade history: unexpected \"Swap\" value in row "+ (i+1) +", col "+ (AS_SWAP+1) +": \""+ sSwap +"\" (expected numeric value)", ERR_INVALID_FILE_FORMAT));
      dSwap = StrToDouble(sSwap);

      sProfit = StrTrim(StrLeftTo(StrRightFrom(cells[AS_PROFIT], ">"), "<")); if (!StrIsNumeric(sProfit))             return(!catch("ParseAccountStatement(51)  trade history: unexpected \"Profit\" value in row "+ (i+1) +", col "+ (AS_PROFIT+1) +": \""+ sProfit +"\" (expected numeric value)", ERR_INVALID_FILE_FORMAT));
      dProfit = StrToDouble(sProfit);

      // add new history record
      if (FindStandardSymbol(symbol) == StdSymbol()) {
         if (AddHistoryRecord(iTicket, 0, 0, iType, dLots, 1, dtOpenTime, dOpenPrice, 0, dStopLoss, dTakeProfit, dtCloseTime, dClosePrice, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) == EMPTY) return(false);
         n++;
      }
   }

   log("ParseAccountStatement(52)  "+ ifString(!n, "no", n) +" trade"+ Pluralize(n) +" found for chart symbol "+ StdSymbol(), NO_ERROR, ifInt(!n, LOG_NOTICE, LOG_INFO));

   return(!catch("ParseAccountStatement(53)"));
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

   #define TR_LINE          0    // #
   #define TR_TIME          1    // Time
   #define TR_TYPE          2    // Type
   #define TR_TICKET        3    // Order
   #define TR_LOTS          4    // Size
   #define TR_PRICE         5    // Price
   #define TR_STOPLOSS      6    // S / L
   #define TR_TAKEPROFIT    7    // T / P
   #define TR_PROFIT        8    // Profit
   #define TR_BALANCE       9    // Balance

   // validate above header fields
   if (Explode(StrRightFrom(rows[0], "<td"), "<td", cells, NULL) != 10)                                                 return(!catch("ParseTestReport(4)  trade history: found "+ ArraySize(cells) +" header cells (expected 10)",                                            ERR_INVALID_FILE_FORMAT));
   string sLine       = StrTrim(StrLeftTo(StrRightFrom(cells[TR_LINE      ], ">"), "<")); if (sLine       != "#"      ) return(!catch("ParseTestReport(5)  trade history: unexpected header of column " + (TR_LINE      +1) +": \""+ sLine       +"\" (expected \"#\")",       ERR_INVALID_FILE_FORMAT));
   string sTime       = StrTrim(StrLeftTo(StrRightFrom(cells[TR_TIME      ], ">"), "<")); if (sTime       != "Time"   ) return(!catch("ParseTestReport(6)  trade history: unexpected header of column " + (TR_TIME      +1) +": \""+ sTime       +"\" (expected \"Time\")",    ERR_INVALID_FILE_FORMAT));
   string sType       = StrTrim(StrLeftTo(StrRightFrom(cells[TR_TYPE      ], ">"), "<")); if (sType       != "Type"   ) return(!catch("ParseTestReport(7)  trade history: unexpected header of column " + (TR_TYPE      +1) +": \""+ sType       +"\" (expected \"Type\")",    ERR_INVALID_FILE_FORMAT));
   string sTicket     = StrTrim(StrLeftTo(StrRightFrom(cells[TR_TICKET    ], ">"), "<")); if (sTicket     != "Order"  ) return(!catch("ParseTestReport(8)  trade history: unexpected header of column " + (TR_TICKET    +1) +": \""+ sTicket     +"\" (expected \"Order\")",   ERR_INVALID_FILE_FORMAT));
   string sLots       = StrTrim(StrLeftTo(StrRightFrom(cells[TR_LOTS      ], ">"), "<")); if (sLots       != "Size"   ) return(!catch("ParseTestReport(9)  trade history: unexpected header of column " + (TR_LOTS      +1) +": \""+ sLots       +"\" (expected \"Size\")",    ERR_INVALID_FILE_FORMAT));
   string sPrice      = StrTrim(StrLeftTo(StrRightFrom(cells[TR_PRICE     ], ">"), "<")); if (sPrice      != "Price"  ) return(!catch("ParseTestReport(10)  trade history: unexpected header of column "+ (TR_PRICE     +1) +": \""+ sPrice      +"\" (expected \"Price\")",   ERR_INVALID_FILE_FORMAT));
   string sStopLoss   = StrTrim(StrLeftTo(StrRightFrom(cells[TR_STOPLOSS  ], ">"), "<")); if (sStopLoss   != "S / L"  ) return(!catch("ParseTestReport(11)  trade history: unexpected header of column "+ (TR_STOPLOSS  +1) +": \""+ sStopLoss   +"\" (expected \"S / L\")",   ERR_INVALID_FILE_FORMAT));
   string sTakeProfit = StrTrim(StrLeftTo(StrRightFrom(cells[TR_TAKEPROFIT], ">"), "<")); if (sTakeProfit != "T / P"  ) return(!catch("ParseTestReport(12)  trade history: unexpected header of column "+ (TR_TAKEPROFIT+1) +": \""+ sTakeProfit +"\" (expected \"T / P\")",   ERR_INVALID_FILE_FORMAT));
   string sProfit     = StrTrim(StrLeftTo(StrRightFrom(cells[TR_PROFIT    ], ">"), "<")); if (sProfit     != "Profit" ) return(!catch("ParseTestReport(13)  trade history: unexpected header of column "+ (TR_PROFIT    +1) +": \""+ sProfit     +"\" (expected \"Profit\")",  ERR_INVALID_FILE_FORMAT));
   string sBalance    = StrTrim(StrLeftTo(StrRightFrom(cells[TR_BALANCE   ], ">"), "<")); if (sBalance    != "Balance") return(!catch("ParseTestReport(14)  trade history: unexpected header of column "+ (TR_BALANCE   +1) +": \""+ sBalance    +"\" (expected \"Balance\")", ERR_INVALID_FILE_FORMAT));

   datetime dtTime;
   int iLine, iTicket, iType;
   double dLots, dPrice, dStopLoss, dTakeProfit, dProfit, dBalance;
   string sTypes[] = {"buy", "sell", "t/p", "s/l", "close at stop"};

   ArrayResize(history, 0);

   // process all data rows
   for (int i=1; i < sizeOfRows; i++) {
      rows[i] = StrReplace(rows[i], " colspan=2>", "></td><td>");
      if (Explode(StrRightFrom(rows[i], "<td"), "<td", cells, NULL) != 10)                                                   return(!catch("ParseTestReport(15)  trade history: found "+ ArraySize(cells) +" data cells in row "+ i +" (expected 10)", ERR_INVALID_FILE_FORMAT));

      // parse/validate a single row
      sLine = StrTrim(StrLeftTo(StrRightFrom(cells[TR_LINE], ">"), "<")); if (!StrIsDigits(sLine))                           return(!catch("ParseTestReport(16)  trade history: unexpected \"Line\" number in row "+ i +", col "+ (TR_LINE+1) +": \""+ sLine +"\" (expected digits only)", ERR_INVALID_FILE_FORMAT));
      iLine = StrToInteger(sLine);

      sTime = StrTrim(StrLeftTo(StrRightFrom(cells[TR_TIME], ">"), "<"));
      dtTime = StrToTime(sTime); if (TimeToStr(dtTime) != sTime)                                                             return(!catch("ParseTestReport(17)  trade history: unexpected \"Time\" value in row "+ i +", col "+ (TR_TIME+1) +": \""+ sTime +"\" (expected datetime)", ERR_INVALID_FILE_FORMAT));

      sType = StrTrim(StrLeftTo(StrRightFrom(cells[TR_TYPE], ">"), "<")); if (!StringInArray(sTypes, sType))                 return(!catch("ParseTestReport(18)  trade history: unsupported \"Type\" value in row "+ i +", col "+ (TR_TYPE+1) +": \""+ sType +"\"", ERR_INVALID_FILE_FORMAT));

      sTicket = StrTrim(StrLeftTo(StrRightFrom(cells[TR_TICKET], ">"), "<")); if (!StrIsDigits(sTicket))                     return(!catch("ParseTestReport(19)  trade history: unexpected \"Order\" value in row "+ i +", col "+ (TR_TICKET+1) +": \""+ sTicket +"\" (expected digits only)", ERR_INVALID_FILE_FORMAT));
      iTicket = StrToInteger(sTicket);                                        if (!iTicket)                                  return(!catch("ParseTestReport(20)  trade history: invalid \"Order\" value in row "+ i +", col "+ (TR_TICKET+1) +": \""+ sTicket +"\" (expected positive integer)", ERR_INVALID_FILE_FORMAT));

      sLots = StrTrim(StrLeftTo(StrRightFrom(cells[TR_LOTS], ">"), "<")); if (!StrIsNumeric(sLots))                          return(!catch("ParseTestReport(21)  trade history: unexpected \"Size\" value in row "+ i +", col "+ (TR_LOTS+1) +": \""+ sLots +"\" (expected positive numeric value)", ERR_INVALID_FILE_FORMAT));
      dLots = StrToDouble(sLots);                                         if (dLots <= 0)                                    return(!catch("ParseTestReport(22)  trade history: unexpected \"Size\" value in row "+ i +", col "+ (TR_LOTS+1) +": \""+ sLots +"\" (expected positive numeric value)", ERR_INVALID_FILE_FORMAT));

      sPrice = StrTrim(StrLeftTo(StrRightFrom(cells[TR_PRICE], ">"), "<")); if (!StrIsNumeric(sPrice))                       return(!catch("ParseTestReport(23)  trade history: unexpected \"Price\" value in row "+ i +", col "+ (TR_PRICE+1) +": \""+ sPrice +"\" (expected positive price value)", ERR_INVALID_FILE_FORMAT));
      dPrice = StrToDouble(sPrice);                                         if (dPrice <= 0)                                 return(!catch("ParseTestReport(24)  trade history: unexpected \"Price\" value in row "+ i +", col "+ (TR_PRICE+1) +": \""+ sPrice +"\" (expected positive price value)", ERR_INVALID_FILE_FORMAT));

      sStopLoss = StrTrim(StrLeftTo(StrRightFrom(cells[TR_STOPLOSS], ">"), "<")); if (!StrIsNumeric(sStopLoss))              return(!catch("ParseTestReport(25)  trade history: unexpected \"S/L\" value in row "+ i +", col "+ (TR_STOPLOSS+1) +": \""+ sStopLoss +"\" (expected stoploss value)", ERR_INVALID_FILE_FORMAT));
      dStopLoss = StrToDouble(sStopLoss);                                         if (dStopLoss <= 0)                        return(!catch("ParseTestReport(26)  trade history: unexpected \"S/L\" value in row "+ i +", col "+ (TR_STOPLOSS+1) +": \""+ sStopLoss +"\" (expected stoploss value)", ERR_INVALID_FILE_FORMAT));

      sTakeProfit = StrTrim(StrLeftTo(StrRightFrom(cells[TR_TAKEPROFIT], ">"), "<")); if (!StrIsNumeric(sTakeProfit))        return(!catch("ParseTestReport(27)  trade history: unexpected \"T/P\" value in row "+ i +", col "+ (TR_TAKEPROFIT+1) +": \""+ sTakeProfit +"\" (expected takeprofit value)", ERR_INVALID_FILE_FORMAT));
      dTakeProfit = StrToDouble(sTakeProfit);                                         if (dTakeProfit <= 0)                  return(!catch("ParseTestReport(28)  trade history: unexpected \"T/P\" value in row "+ i +", col "+ (TR_TAKEPROFIT+1) +": \""+ sTakeProfit +"\" (expected takeprofit value)", ERR_INVALID_FILE_FORMAT));

      sProfit = StrTrim(StrLeftTo(StrRightFrom(cells[TR_PROFIT], ">"), "<")); if (sProfit!="" && !StrIsNumeric(sProfit))     return(!catch("ParseTestReport(29)  trade history: unexpected \"Profit\" value in row "+ i +", col "+ (TR_PROFIT+1) +": \""+ sProfit +"\" (expected numeric value)", ERR_INVALID_FILE_FORMAT));
      dProfit = StrToDouble(sProfit);

      sBalance = StrTrim(StrLeftTo(StrRightFrom(cells[TR_BALANCE], ">"), "<")); if (sBalance!="" && !StrIsNumeric(sBalance)) return(!catch("ParseTestReport(30)  trade history: unexpected \"Balance\" value in row "+ i +", col "+ (TR_BALANCE+1) +": \""+ sBalance +"\" (expected positive numeric value)", ERR_INVALID_FILE_FORMAT));
      dBalance = StrToDouble(sBalance);                                         if (dBalance < 0)                            return(!catch("ParseTestReport(31)  trade history: unexpected \"Balance\" value in row "+ i +", col "+ (TR_BALANCE+1) +": \""+ sBalance +"\" (expected positive numeric value)", ERR_INVALID_FILE_FORMAT));

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
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("HtmlFilename=", DoubleQuoteStr(HtmlFilename), ";"));
}
