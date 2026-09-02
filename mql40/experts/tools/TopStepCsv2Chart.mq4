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

   debug("ParseLines(0.1)  found "+ sizeLines +" lines");

   // define file format
   string csvHeader = "Id,ContractName,EnteredAt,ExitedAt,EntryPrice,ExitPrice,Fees,PnL,Size,Type,TradeDay,TradeDuration,Commissions";
   int sizeCols = 13;

   #define I_TICKET            0    // Id
   #define I_SYMBOL            1    // ContractName
   #define I_OPENTIME          2    // EnteredAt (with TZ offset)
   #define I_CLOSETIME         3    // ExitedAt (with TZ offset)
   #define I_OPENPRICE         4    // EntryPrice
   #define I_CLOSEPRICE        5    // ExitPrice
   #define I_FEE               6    // Fees (absolute value)
   #define I_PROFIT            7    // PnL
   #define I_LOTS              8    // Size
   #define I_TYPE              9    // Type
   #define I_TRADE_DAY        10    // TradeDay (skipped)
   #define I_TRADE_DURATION   11    // TradeDuration (skipped)
   #define I_COMMISSION       12    // Commissions (absolute value)

   // parse lines
   for (int i=0; i < sizeLines; i++) {
      string line = StrTrim(lines[i]), cols[];

      // validate file header
      if (i == 0) {
         if (StrStartsWith(line, UTF8_BOM)) {            // remove an existing UTF-8 BOM
            line = StrSubstr(line, StringLen(UTF8_BOM));
         }
         if (!StrCompareI(line, csvHeader)) return(!catch("ParseLines(2)  invalid file format: TopStep CSV header not found", ERR_INVALID_FILE_FORMAT));
         continue;
      }
      if (line == "") continue;                          // skip empty lines

      // split line into columns and parse cells
      int foundCols = Explode(line, ",", cols, NULL);
      if (foundCols != sizeCols) return(!catch("ParseLines(3)  invalid file format in line "+ (i+1) +": found "+ foundCols +" cols (expected "+ sizeCols +")", ERR_INVALID_FILE_FORMAT));

      // ticket
      string sTicket = StrTrim(cols[I_TICKET]);
      if (!StrIsDigits(sTicket)) return(!catch("ParseLines(4)  invalid ticket in line "+ (i+1) +": "+ DoubleQuoteStr(sTicket), ERR_INVALID_FILE_FORMAT));
      int ticket = StrToInteger(sTicket);
      if (!ticket)               return(!catch("ParseLines(5)  invalid ticket in line "+ (i+1) +": "+ DoubleQuoteStr(sTicket), ERR_INVALID_FILE_FORMAT));

      // symbol
      string symbol = StrTrim(cols[I_SYMBOL]);
      if (symbol == "")          return(!catch("ParseLines(6)  invalid symbol in line "+ (i+1) +": \"\" (empty)", ERR_INVALID_FILE_FORMAT));

      // type
      string sType = StrToLower(StrTrim(cols[I_TYPE]));
      if      (sType == "long") int type = OP_BUY;
      else if (sType == "short")    type = OP_SELL;
      else                       return(!catch("ParseLines(7)  invalid trade type in line "+ (i+1) +": "+ DoubleQuoteStr(sType), ERR_INVALID_FILE_FORMAT));

      // lots
      string sLots = StrTrim(cols[I_LOTS]);
      if (!StrIsDigits(sLots))   return(!catch("ParseLines(8)  invalid amount of traded contracts in line "+ (i+1) +": "+ DoubleQuoteStr(sLots), ERR_INVALID_FILE_FORMAT));
      int lots = StrToInteger(sLots);
      if (!lots)                 return(!catch("ParseLines(9)  invalid amount of traded contracts in line "+ (i+1) +": "+ DoubleQuoteStr(sLots), ERR_INVALID_FILE_FORMAT));

      // --- validation done ------------------------------------------------------------------------------------------------



      // openTime: 08/31/2026 02:13:26 +03:00
      string sOpenTime = StrTrim(cols[I_OPENTIME]);
      datetime openTime;

      // closeTime: 08/31/2026 02:13:26 +03:00
      string sCloseTime = StrTrim(cols[I_CLOSETIME]);
      datetime closeTime;

      // openPrice
      string sOpenPrice = StrTrim(cols[I_OPENPRICE]);
      double openPrice;

      // closePrice
      string sClosePrice = StrTrim(cols[I_CLOSEPRICE]);
      double closePrice;

      // profit
      string sProfit = StrTrim(cols[I_PROFIT]);
      double profit;

      // commission (absolute value)
      string sCommission = StrTrim(cols[I_COMMISSION]);
      double commission;

      // fee (absolute value)
      string sFee = StrTrim(cols[I_FEE]);
      double fee;

      // add history record if the row belongs to the mapped symbol
      if (symbol == MapSymbol) {
         if (AddHistoryRecord(ticket, NULL, NULL, type, lots, 1, openTime, openPrice, 0, 0, 0, closeTime, closePrice, 0, 0, 0, commission+fee, profit, 0, 0, 0, 0, 0, 0, 0) == EMPTY) return(false);
      }
   }
   return(true);
}


/**
 * Parse and validate a datetime string in format "08/31/2026 02:30:46 +03:00".
 * Without a timezone offset GMT time (offset +00:00) is assumed.
 *
 * @param  string value - datetime string to parse
 * @param  int    line  - CSV line containing the string (for error messages)
 *
 * @return datetime - GMT timestamp or NaT (Not-A-Time) in case of errors
 */
datetime ParseDateTimeEx(string value, int line) {
   string sValue, sValues[], sDate, sYY, sMM, sDD, sTime, sHH, sII, sSS, sOffsetHH, sOffsetII;
   string sError = "unsupported datetime format in line "+ line +": "+ DoubleQuoteStr(value);
   int size, iYY, iMM, iDD, iHH, iII, iSS, iTzOffset, iOffsetHH, iOffsetII, chr;

   value = StrTrim(value);

   // explode words by " " (space)
   size = Explode(value, " ", sValues, NULL);
   if (size < 2 || size > 3)                return(_NaT(catch("ParseDateTimeEx(1)  "+ sError, ERR_INVALID_FILE_FORMAT)));
   sDate = sValues[0];
   sTime = sValues[1];

   // parse timezone offset: +03:00
   if (size == 3) {
      sValue = sValues[2];
      if (StringLen(sValue) != 6)           return(_NaT(catch("ParseDateTimeEx(2)  "+ sError, ERR_INVALID_FILE_FORMAT)));
      chr = StringGetChar(sValue, 0);
      if (chr != '+' && chr != '-')         return(_NaT(catch("ParseDateTimeEx(3)  "+ sError, ERR_INVALID_FILE_FORMAT)));

      if (StringGetChar(sValue, 3) != ':')  return(_NaT(catch("ParseDateTimeEx(4)  "+ sError, ERR_INVALID_FILE_FORMAT)));

      sOffsetHH = StrSubstr(sValue, 1, 2);
      if (!StrIsDigits(sOffsetHH))          return(_NaT(catch("ParseDateTimeEx(5)  "+ sError, ERR_INVALID_FILE_FORMAT)));
      iOffsetHH = StrToInteger(sOffsetHH);
      if (iOffsetHH > 14)                   return(_NaT(catch("ParseDateTimeEx(6)  "+ sError, ERR_INVALID_FILE_FORMAT)));

      sOffsetII = StrSubstr(sValue, 4, 2);
      if (!StrIsDigits(sOffsetII))          return(_NaT(catch("ParseDateTimeEx(7)  "+ sError, ERR_INVALID_FILE_FORMAT)));
      iOffsetII = StrToInteger(sOffsetII);
      if (iOffsetII > 45)                   return(_NaT(catch("ParseDateTimeEx(8)  "+ sError, ERR_INVALID_FILE_FORMAT)));
      if (iOffsetII % 15 != 0)              return(_NaT(catch("ParseDateTimeEx(9)  "+ sError, ERR_INVALID_FILE_FORMAT)));
      if (iOffsetHH == 14 && iOffsetII > 0) return(_NaT(catch("ParseDateTimeEx(10)  "+ sError, ERR_INVALID_FILE_FORMAT)));

      iTzOffset = iOffsetHH * HOURS + iOffsetII * MINUTES;
      if (chr == '+') iTzOffset = -iTzOffset;
   }

   // parse date: "08/31/2026"
   size = Explode(sDate, "/", sValues, NULL);
   if (size != 3)                           return(_NaT(catch("ParseDateTimeEx(11)  "+ sError, ERR_INVALID_FILE_FORMAT)));

   sYY = sValues[2];
   if (StringLen(sYY) != 4)                 return(_NaT(catch("ParseDateTimeEx(11)  "+ sError, ERR_INVALID_FILE_FORMAT)));
   if (!StrIsDigits(sYY))                   return(_NaT(catch("ParseDateTimeEx(11)  "+ sError, ERR_INVALID_FILE_FORMAT)));
   iYY = StrToInteger(sYY);
   if (iYY < 1970 || iYY > 2037)            return(_NaT(catch("ParseDateTimeEx(11)  "+ sError, ERR_INVALID_FILE_FORMAT)));

   sMM = sValues[0];
   if (StringLen(sMM) != 2)                 return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));
   if (!StrIsDigits(sMM))                   return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));
   iMM = StrToInteger(sMM);
   if (iMM < 1 || iMM > 12)                 return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));

   sDD = sValues[1];
   if (StringLen(sDD) != 2)                 return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));
   if (!StrIsDigits(sDD))                   return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));
   iDD = StrToInteger(sDD);
   if (iDD < 1 || iDD > 31)                 return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));
   if (iDD > 28) {
      if (iMM == FEB) {
         if (iDD > 29)                      return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));
         if (!IsLeapYear(iYY))              return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));
      }
      else if (iDD == 31) {
         switch (iMM) {
            case APR:
            case JUN:
            case SEP:
            case NOV:                       return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));
         }
      }
   }

   // parse time: "02:30:46"
   size = Explode(sTime, ":", sValues, NULL);
   if (size != 3)                           return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));

   sHH = sValues[0];
   if (StringLen(sHH) != 2)                 return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));
   if (!StrIsDigits(sHH))                   return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));
   iHH = StrToInteger(sHH);
   if (iHH < 0 || iHH > 23)                 return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));

   sII = sValues[1];
   if (StringLen(sII) != 2)                 return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));
   if (!StrIsDigits(sII))                   return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));
   iII = StrToInteger(sII);
   if (iII < 0 || iII > 59)                 return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));

   sSS = sValues[2];
   if (StringLen(sSS) != 2)                 return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));
   if (!StrIsDigits(sSS))                   return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));
   iSS = StrToInteger(sSS);
   if (iSS < 0 || iSS > 59)                 return(_NaT(catch("ParseDateTimeEx(12)  "+ sError, ERR_INVALID_FILE_FORMAT)));

   // create datetime
   datetime result = DateTime1(iYY, iMM, iDD, iHH, iII, iSS);

   // add timezone offset
   return(result + iTzOffset);
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
   string symbol = StrTrim(MapSymbol);
   if (symbol == "") symbol = Symbol();
   MapSymbol = StrToUpper(symbol);

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
