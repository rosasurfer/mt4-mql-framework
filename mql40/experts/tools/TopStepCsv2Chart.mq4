/**
 * Helper EA to visualize the trade history of a TopStep account, exported in CSV format.
 *
 * The EA parses the trade history and converts it to the framework's internal format. Then the history is processed
 * as if the EA traded it. Use the EA standard commands to show/hide the history.
 *
 *
 * Input parameters
 * ----------------
 *  • CsvFileName: File path/name containing the CSV data export. Must be located in the MQL "files" directory.
 *  • CsvSymbol:   Symbol from the CSV file to map to the current chart. If empty the chart symbol is used.
 *
 *
 * Example data:
 * -------------
 *  Id,ContractName,EnteredAt,ExitedAt,EntryPrice,ExitPrice,Fees,PnL,Size,Type,TradeDay,TradeDuration,Commissions
 *  3042479400,MGCZ6,08/31/2026 01:06:17 +03:00,08/31/2026 01:31:21 +03:00,4501.400000000,4506.700000000,4.26000,-159.000000000,3,Short,08/31/2026 00:00:00 -05:00,00:25:03.7342440,1.50000
 *  3044000436,MGCZ6,08/31/2026 08:42:30 +03:00,08/31/2026 08:57:49 +03:00,4486.100000000,4490.900000000,4.26000,144.000000000,3,Long,08/31/2026 00:00:00 -05:00,00:15:19.3129020,1.50000
 *
 *
 * TODO:
 *  - cache the parsed data over init cycles and convert to indicator
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = { INIT_TIMEZONE };
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern   string CsvFileName = "topstep-practice-150k.csv";
//extern string CsvFileName = "topstep-eval-50k.csv";

extern   string CsvSymbol   = "MGCZ6";             // CSV symbol to map to the current chart (empty: chart symbol)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/expert.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/HandleCommands.mqh>

string Instance.ID = "999";                        // dummy, needed by StoreVolatileStatus()

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
         string lines[];
         if (!ReadFile(CsvFileName, lines)) return(last_error);
         if (!ParseLines(lines))            return(last_error);

         // hide existing trade markers and show imported trades
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
 * Read the specified file into an array of lines.
 *
 * @param  _In_  string fileName
 * @param  _Out_ string lines[]
 *
 * @return bool - success status
 */
bool ReadFile(string fileName, string &lines[]) {
   int size = FileReadLines(fileName, lines, false);
   if (size < 0)  return(false);
   if (size == 0) return(!catch("ReadFile(1)  invalid file "+ DoubleQuoteStr(fileName) +" (empty)", ERR_RUNTIME_ERROR));

   logInfo("ReadFile(2)  "+ size +" line"+ Pluralize(size) +" read");
   return(true);
}


/**
 * Parse the lines of the CSV file.
 *
 * @param  string lines[]
 *
 * @return bool - success status
 */
bool ParseLines(string lines[]) {
   int sizeLines = ArraySize(lines);
   if (!sizeLines) return(!catch("ParseLines(1)  invalid parameter lines[]: empty", ERR_INVALID_FILE_FORMAT));

   // define file format
   string csvHeader = "Id,ContractName,EnteredAt,ExitedAt,EntryPrice,ExitPrice,Fees,PnL,Size,Type,TradeDay,TradeDuration,Commissions";
   int sizeCols = 13;

   #define I_TICKET            0    // Id (unsigned int greater than INT_MAX)
   #define I_SYMBOL            1    // ContractName
   #define I_OPENTIME          2    // EnteredAt (with TZ offset)
   #define I_CLOSETIME         3    // ExitedAt (with TZ offset)
   #define I_OPENPRICE         4    // EntryPrice
   #define I_CLOSEPRICE        5    // ExitPrice
   #define I_FEE               6    // Fees (exchange fee, absolute value)
   #define I_PROFIT            7    // PnL
   #define I_LOTS              8    // Size
   #define I_TYPE              9    // Type
   #define I_TRADE_DAY        10    // TradeDay (skipped)
   #define I_TRADE_DURATION   11    // TradeDuration (skipped)
   #define I_COMMISSION       12    // Commissions (absolute value)

   string line, cols[], sTicket, symbol, sType, sLots, sOpenTime, sCloseTime, sOpenPrice, sClosePrice, sProfit, sCommission, sFee;
   int foundCols, ticket, type, lots;
   datetime openTime, closeTime;
   double openPrice, closePrice, profit, commission, fee, totalCosts;

   // parse lines
   for (int i=0; i < sizeLines; i++) {
      line = StrTrim(lines[i]);

      // validate file header
      if (i == 0) {
         if (StrStartsWith(line, UTF8_BOM)) {           // remove an existing UTF-8 BOM
            line = StrSubstr(line, StringLen(UTF8_BOM));
         }
         if (!StrCompareI(line, csvHeader))             return(!catch("ParseLines(2)  unsupported file format: TopStep CSV header not found", ERR_INVALID_FILE_FORMAT));
         continue;
      }
      if (line == "") continue;                         // skip empty lines

      // split line into columns and parse cells
      foundCols = Explode(line, ",", cols, NULL);
      if (foundCols != sizeCols)                        return(!catch("ParseLines(3)  unsupported file format in line "+ (i+1) +": found "+ foundCols +" data cells (expected "+ sizeCols +")", ERR_INVALID_FILE_FORMAT));

      // ticket (32-bit unsigned int)
      sTicket = StrTrim(cols[I_TICKET]);
      if (!StrIsDigits(sTicket))                        return(!catch("ParseLines(4)  unexpected format of field \"Id\" in line "+ (i+1) +": "+ DoubleQuoteStr(sTicket), ERR_INVALID_FILE_FORMAT));
      if (!ParseUint32(sTicket, ticket))                return(!catch("ParseLines(5)  unexpected range of field \"Id\" in line "+ (i+1) +": "+ DoubleQuoteStr(sTicket), ERR_INVALID_FILE_FORMAT));

      // symbol
      symbol = StrTrim(cols[I_SYMBOL]);
      if (symbol == "")                                 return(!catch("ParseLines(6)  invalid field \"ContractName\" in line "+ (i+1) +": \"\" (empty)", ERR_INVALID_FILE_FORMAT));

      // type
      sType = StrToLower(StrTrim(cols[I_TYPE]));
      if      (sType == "long")  type = OP_BUY;
      else if (sType == "short") type = OP_SELL;
      else                                              return(!catch("ParseLines(7)  unexpected format of field \"Type\" in line "+ (i+1) +": "+ DoubleQuoteStr(sType), ERR_INVALID_FILE_FORMAT));

      // lots
      sLots = StrTrim(cols[I_LOTS]);
      if (!StrIsDigits(sLots))                          return(!catch("ParseLines(8)  unexpected format of field \"Size\" in line "+ (i+1) +": "+ DoubleQuoteStr(sLots), ERR_INVALID_FILE_FORMAT));
      lots = StrToInteger(sLots);
      if (!lots)                                        return(!catch("ParseLines(9)  invalid field \"Size\" in line "+ (i+1) +": "+ DoubleQuoteStr(sLots), ERR_INVALID_FILE_FORMAT));

      // openTime: 08/31/2026 02:13:26 +03:00
      sOpenTime = StrTrim(cols[I_OPENTIME]);
      if (!ParseTopStepDateTime(sOpenTime, openTime))   return(!catch("ParseLines(10)  unexpected format of field \"EnteredAt\" in line "+ (i+1) +": "+ DoubleQuoteStr(sOpenTime), ERR_INVALID_FILE_FORMAT));
      openTime = GmtToServerTime(openTime);
      if (IsNaT(openTime))                              return(!catch("ParseLines(11)  can't convert field \"EnteredAt\" in line "+ (i+1) +" to server time: "+ DoubleQuoteStr(sOpenTime), ERR_INVALID_FILE_FORMAT));

      // closeTime: 08/31/2026 02:13:26 +03:00
      sCloseTime = StrTrim(cols[I_CLOSETIME]);
      if (!ParseTopStepDateTime(sCloseTime, closeTime)) return(!catch("ParseLines(12)  unexpected format of field \"ExitedAt\" in line "+ (i+1) +": "+ DoubleQuoteStr(sCloseTime), ERR_INVALID_FILE_FORMAT));
      closeTime = GmtToServerTime(closeTime);
      if (IsNaT(closeTime))                             return(!catch("ParseLines(13)  can't convert field \"ExitedAt\" in line "+ (i+1) +" to server time: "+ DoubleQuoteStr(sCloseTime), ERR_INVALID_FILE_FORMAT));

      // openPrice
      sOpenPrice = StrTrim(cols[I_OPENPRICE]);
      if (!StrIsNumeric(sOpenPrice))                    return(!catch("ParseLines(14)  unexpected format of field \"EntryPrice\" in line "+ (i+1) +": "+ DoubleQuoteStr(sOpenPrice), ERR_INVALID_FILE_FORMAT));
      openPrice = StrToDouble(sOpenPrice);
      if (openPrice <= 0)                               return(!catch("ParseLines(15)  invalid field \"EntryPrice\" in line "+ (i+1) +": "+ DoubleQuoteStr(sOpenPrice), ERR_INVALID_FILE_FORMAT));

      // closePrice
      sClosePrice = StrTrim(cols[I_CLOSEPRICE]);
      if (!StrIsNumeric(sClosePrice))                    return(!catch("ParseLines(16)  unexpected format of field \"ExitPrice\" in line "+ (i+1) +": "+ DoubleQuoteStr(sClosePrice), ERR_INVALID_FILE_FORMAT));
      closePrice = StrToDouble(sClosePrice);
      if (closePrice <= 0)                               return(!catch("ParseLines(17)  invalid field \"ExitPrice\" in line "+ (i+1) +": "+ DoubleQuoteStr(sClosePrice), ERR_INVALID_FILE_FORMAT));

      // profit
      sProfit = StrTrim(cols[I_PROFIT]);
      if (!StrIsNumeric(sProfit))                        return(!catch("ParseLines(18)  unexpected format of field \"PnL\" in line "+ (i+1) +": "+ DoubleQuoteStr(sClosePrice), ERR_INVALID_FILE_FORMAT));
      profit = StrToDouble(sProfit);

      // commission (absolute value)
      sCommission = StrTrim(cols[I_COMMISSION]);
      if (!StrIsNumeric(sCommission))                    return(!catch("ParseLines(19)  unexpected format of field \"Commissions\" in line "+ (i+1) +": "+ DoubleQuoteStr(sClosePrice), ERR_INVALID_FILE_FORMAT));
      commission = StrToDouble(sCommission);
      commission = -MathAbs(commission);

      // exchange fee (absolute value)
      sFee = StrTrim(cols[I_FEE]);
      if (!StrIsNumeric(sFee))                           return(!catch("ParseLines(20)  unexpected format of field \"Fees\" in line "+ (i+1) +": "+ DoubleQuoteStr(sClosePrice), ERR_INVALID_FILE_FORMAT));
      fee = StrToDouble(sFee);
      fee = -MathAbs(fee);
      totalCosts = commission + fee;

      // add history record if the row belongs to the mapped symbol
      if (symbol == CsvSymbol) {
         if (AddHistoryRecord(ticket, NULL, NULL, type, lots, 1, openTime, openPrice, 0, 0, 0, closeTime, closePrice, 0, 0, 0, totalCosts, profit, 0, 0, 0, 0, 0, 0, 0) == EMPTY) {
            return(!catch("ParseLines(21)  invalid file format in line "+ (i+1) +": "+ DoubleQuoteStr(line), ERR_INVALID_FILE_FORMAT));
         }
      }
   }

   int size = ArrayRange(history, 0);
   logInfo("ParseLines(22)  "+ size +" history record"+ Pluralize(size) +" parsed");
   return(true);
}


/**
 * Parse a string containing a 32-bit unsigned integer and convert it to a signed integer.
 * Helper for MQL4.0 which has no `unsigned int` type.
 *
 * @param  _In_  string sUnsigned - uint32 string to parse
 * @param  _Out_ int    signed    - parsed signed int
 *
 * @return bool - success status
 */
bool ParseUint32(string sUnsigned, int &signed) {
   string s = StrTrim(sUnsigned);
   int sLen = StringLen(s);
   if (!sLen) return(false);

   int hi = 0, lo = 0;

   for (int i=0; i < sLen; i++) {
      int d = StringGetChar(s, i) - '0';
      if (d < 0 || d > 9) return(false);     // not numeric

      lo = lo * 10 + d;                      // reconstruct low word
      hi = hi * 10 + lo / 65536;             // reconstruct high word
      if (hi > 65535) return(false);         // exceeds 32-bit range: > 0xFFFFFFFF

      lo %= 65536;
   }

   int value = 0;

   if (hi < 32768) {
      value = hi * 65536 + lo;               // positive signed value
   }
   else {
      value  = (hi - 32768) * 65536 + lo;    // negative signed value
      value += (-2147483647 - 1);
   }

   signed = value;
   return(true);
}


/**
 * Parse and validate a TopStep datetime string. Format: "08/31/2026 02:30:46 +03:00"
 * Without a timezone offset GMT time (offset +00:00) is assumed.
 *
 * @param  _In_  string   sDateTime - datetime string to parse
 * @param  _Out_ datetime timestamp - parsed datetime string
 *
 * @return bool - success status
 */
datetime ParseTopStepDateTime(string sDateTime, datetime &timestamp) {
   string sValue, sValues[], sDate, sYY, sMM, sDD, sTime, sHH, sII, sSS, sOffsetHH, sOffsetII;
   int size, iYY, iMM, iDD, iHH, iII, iSS, iTzOffset, iOffsetHH, iOffsetII, chr;

   sDateTime = StrTrim(sDateTime);

   // explode words by " " (space)
   size = Explode(sDateTime, " ", sValues, NULL);
   if (size < 2 || size > 3)                return(false);
   sDate = sValues[0];
   sTime = sValues[1];

   // parse timezone offset: +03:00
   if (size == 3) {
      sValue = sValues[2];
      if (StringLen(sValue) != 6)           return(false);
      chr = StringGetChar(sValue, 0);
      if (chr != '+' && chr != '-')         return(false);

      if (StringGetChar(sValue, 3) != ':')  return(false);

      sOffsetHH = StrSubstr(sValue, 1, 2);
      if (!StrIsDigits(sOffsetHH))          return(false);
      iOffsetHH = StrToInteger(sOffsetHH);
      if (iOffsetHH > 14)                   return(false);

      sOffsetII = StrSubstr(sValue, 4, 2);
      if (!StrIsDigits(sOffsetII))          return(false);
      iOffsetII = StrToInteger(sOffsetII);
      if (iOffsetII > 45)                   return(false);
      if (iOffsetII % 15 != 0)              return(false);
      if (iOffsetHH == 14 && iOffsetII > 0) return(false);

      iTzOffset = iOffsetHH * HOURS + iOffsetII * MINUTES;
      if (chr == '+') iTzOffset = -iTzOffset;
   }

   // parse date: "08/31/2026"
   size = Explode(sDate, "/", sValues, NULL);
   if (size != 3)                           return(false);

   sYY = sValues[2];
   if (StringLen(sYY) != 4)                 return(false);
   if (!StrIsDigits(sYY))                   return(false);
   iYY = StrToInteger(sYY);
   if (iYY < 1970 || iYY > 2037)            return(false);

   sMM = sValues[0];
   if (StringLen(sMM) != 2)                 return(false);
   if (!StrIsDigits(sMM))                   return(false);
   iMM = StrToInteger(sMM);
   if (iMM < 1 || iMM > 12)                 return(false);

   sDD = sValues[1];
   if (StringLen(sDD) != 2)                 return(false);
   if (!StrIsDigits(sDD))                   return(false);
   iDD = StrToInteger(sDD);
   if (iDD < 1 || iDD > 31)                 return(false);
   if (iDD > 28) {
      if (iMM == FEB) {
         if (iDD > 29)                      return(false);
         if (!IsLeapYear(iYY))              return(false);
      }
      else if (iDD == 31) {
         switch (iMM) {
            case APR:
            case JUN:
            case SEP:
            case NOV:                       return(false);
         }
      }
   }

   // parse time: "02:30:46"
   size = Explode(sTime, ":", sValues, NULL);
   if (size != 3)                           return(false);

   sHH = sValues[0];
   if (StringLen(sHH) != 2)                 return(false);
   if (!StrIsDigits(sHH))                   return(false);
   iHH = StrToInteger(sHH);
   if (iHH < 0 || iHH > 23)                 return(false);

   sII = sValues[1];
   if (StringLen(sII) != 2)                 return(false);
   if (!StrIsDigits(sII))                   return(false);
   iII = StrToInteger(sII);
   if (iII < 0 || iII > 59)                 return(false);

   sSS = sValues[2];
   if (StringLen(sSS) != 2)                 return(false);
   if (!StrIsDigits(sSS))                   return(false);
   iSS = StrToInteger(sSS);
   if (iSS < 0 || iSS > 59)                 return(false);

   // create datetime and add timezone offset
   datetime result = DateTime1(iYY, iMM, iDD, iHH, iII, iSS);
   if (IsNaT(result)) return(false);

   timestamp = result + iTzOffset;
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

   // CsvSymbol
   string symbol = StrTrim(CsvSymbol);
   if (symbol == "") symbol = Symbol();
   CsvSymbol = StrToUpper(symbol);

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
      "CsvSymbol=",   DoubleQuoteStr(CsvSymbol),   ";", NL
   ));
}
