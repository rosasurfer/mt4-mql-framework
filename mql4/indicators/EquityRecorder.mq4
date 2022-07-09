/**
 * EquityRecorder
 *
 *
 * Records the current account's equity curve.
 * The recorded value is adjusted for inflated transaction costs (doubled spreads and fees).
 *
 *
 * TODO:
 *  - document both equity curves
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Recording.HistoryDirectory = "Synthetic-History";      // name of the directory to store recorded data
extern int    Recording.HistoryFormat    = 401;                      // written history format: 400 | 401

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <rsfHistory.mqh>

#property indicator_chart_window
#property indicator_buffers      1              // there's a minimum of 1 buffer
#property indicator_color1       CLR_NONE

#define I_EQUITY_ACCOUNT         0              // equity values
#define I_EQUITY_ACCOUNT_EXT     1              // equity values plus external assets (if configured for the account)

bool     isOpenPosition;                        // whether we have any open positions
datetime lastTickTime;                          // last tick time of all symbols with open positions
double   currEquity[2];                         // current equity values
double   prevEquity[2];                         // previous equity values
int      hSet      [2];                         // HistorySet handles

string symbolSuffixes    [] = {".EA"                               , ".EX"                                                    };
string symbolDescriptions[] = {"Equity of account {account-number}", "Equity of account {account-number} plus external assets"};

string recordingDirectory = "";                 // directory to store data
int    recordingFormat;                         // format of new history files: 400 | 401
int    tickTimerId;                             // id of the tick timer registered for the chart

string indicatorName = "";
string legendLabel   = "";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // read auto-configuration
   string indicator = ProgramName(MODE_NICE);
   if (AutoConfiguration) {
      Recording.HistoryDirectory = GetConfigString(indicator, "Recording.HistoryDirectory", Recording.HistoryDirectory);
      Recording.HistoryFormat    = GetConfigInt   (indicator, "Recording.HistoryFormat",    Recording.HistoryFormat);
   }

   // validate inputs
   // Recording.HistoryDirectory
   recordingDirectory = StrTrim(Recording.HistoryDirectory);
   if (IsAbsolutePath(recordingDirectory))                           return(catch("onInit(1)  illegal input parameter Recording.HistoryDirectory: "+ DoubleQuoteStr(Recording.HistoryDirectory) +" (not an allowed directory name)", ERR_INVALID_INPUT_PARAMETER));
   int illegalChars[] = {':', '*', '?', '"', '<', '>', '|'};
   if (StrContainsChars(recordingDirectory, illegalChars))           return(catch("onInit(2)  invalid input parameter Recording.HistoryDirectory: "+ DoubleQuoteStr(Recording.HistoryDirectory) +" (not a valid directory name)", ERR_INVALID_INPUT_PARAMETER));
   recordingDirectory = StrReplace(recordingDirectory, "\\", "/");
   if (StrStartsWith(recordingDirectory, "/"))                       return(catch("onInit(3)  invalid input parameter Recording.HistoryDirectory: "+ DoubleQuoteStr(Recording.HistoryDirectory) +" (must not start with a slash)", ERR_INVALID_INPUT_PARAMETER));
   if (!UseTradeServerPath(recordingDirectory, "onInit(4)"))         return(last_error);

   // Recording.HistoryFormat
   if (Recording.HistoryFormat!=400 && Recording.HistoryFormat!=401) return(catch("onInit(5)  invalid input parameter Recording.HistoryFormat: "+ Recording.HistoryFormat +" (must be 400 or 401)", ERR_INVALID_INPUT_PARAMETER));
   recordingFormat = Recording.HistoryFormat;

   // setup a chart ticker (online only)
   if (!__isTesting) {
      int hWnd         = __ExecutionContext[EC.hChart];
      int milliseconds = 1000;                           // a virtual tick every second (1000 milliseconds)
      int timerId      = SetupTickTimer(hWnd, milliseconds, NULL);
      if (!timerId) return(catch("onInit(6)->SetupTickTimer(hWnd="+ IntToHexStr(hWnd) +") failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;
   }

   // indicator labels and display options
   if (!__isSuperContext) {
       legendLabel = CreateLegendLabel();
       RegisterObject(legendLabel);
   }
   indicatorName = ProgramName(MODE_NICE);
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
   if (tickTimerId > NULL) {
      int id = tickTimerId; tickTimerId = NULL;
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
   if (!CollectData()) return(last_error);
   if (!RecordData())  return(last_error);

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
bool CollectData() {
   string symbols      []; ArrayResize(symbols,       0);            // symbols with open positions
   double symbolProfits[]; ArrayResize(symbolProfits, 0);            // each symbol's total PL

   // read open positions
   int orders = OrdersTotal();
   int    symbolsIdx []; ArrayResize(symbolsIdx,  orders);           // an order's symbol index in symbols[]
   int    tickets    []; ArrayResize(tickets,     orders);
   int    types      []; ArrayResize(types,       orders);
   double lots       []; ArrayResize(lots,        orders);
   double openPrices []; ArrayResize(openPrices,  orders);
   double commissions[]; ArrayResize(commissions, orders);
   double swaps      []; ArrayResize(swaps,       orders);
   double profits    []; ArrayResize(profits,     orders);

   for (int n, si, i=0; i < orders; i++) {                           // si => actual symbol index
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;
      if (OrderType() > OP_SELL) continue;
      if (!n) {
         si = ArrayPushString(symbols, OrderSymbol()) - 1;
      }
      else if (symbols[si] != OrderSymbol()) {
         si = SearchStringArray(symbols, OrderSymbol());
         if (si == -1)
            si = ArrayPushString(symbols, OrderSymbol()) - 1;
      }
      symbolsIdx [n] = si;
      tickets    [n] = OrderTicket();
      types      [n] = OrderType();
      lots       [n] = NormalizeDouble(OrderLots(), 2);
      openPrices [n] = OrderOpenPrice();
      commissions[n] = OrderCommission();
      swaps      [n] = OrderSwap();
      profits    [n] = OrderProfit();
      n++;
   }
   if (n < orders) {
      ArrayResize(symbolsIdx , n);
      ArrayResize(tickets,     n);
      ArrayResize(types,       n);
      ArrayResize(lots,        n);
      ArrayResize(openPrices,  n);
      ArrayResize(commissions, n);
      ArrayResize(swaps,       n);
      ArrayResize(profits,     n);
      orders = n;
   }
   isOpenPosition = (n > 0);

   // determine each symbol's PL
   int symbolsSize = ArraySize(symbols), error;
   ArrayResize(symbolProfits, symbolsSize);

   for (i=0; i < symbolsSize; i++) {
      symbolProfits[i]  = CalculateProfit(symbols[i], i, symbolsIdx, tickets, types, lots, openPrices, commissions, swaps, profits); if (IsEmptyValue(symbolProfits[i])) return(false);
      symbolProfits[i]  = NormalizeDouble(symbolProfits[i], 2);
      datetime tickTime = MarketInfoEx(symbols[i], MODE_TIME, error, "CollectData(1)"); if (error != NULL) return(false);
      lastTickTime      = Max(lastTickTime, tickTime);
   }

   // calculate resulting equity values
   double fullPL         = SumDoubles(symbolProfits);
   double externalAssets = GetExternalAssets(); if (IsEmptyValue(externalAssets)) return(false);

   currEquity[I_EQUITY_ACCOUNT    ] = NormalizeDouble(AccountBalance()             + fullPL,         2);
   currEquity[I_EQUITY_ACCOUNT_EXT] = NormalizeDouble(currEquity[I_EQUITY_ACCOUNT] + externalAssets, 2);

   return(!catch("CollectData(2)"));
}


/**
 * Calculate the total PL of a single symbol.
 *
 * @param  string symbol        - symbol
 * @param  int    index         - symbol index in symbolsIdx[]
 * @param  int    symbolsIdx []
 * @param  int    tickets    []
 * @param  int    types      []
 * @param  double lots       []
 * @param  double openPrices []
 * @param  double commissions[]
 * @param  double swaps      []
 * @param  double profits    []
 *
 * @return double - PL-Value oder EMPTY_VALUE, falls ein Fehler auftrat
 */
double CalculateProfit(string symbol, int index, int symbolsIdx[], int &tickets[], int types[], double &lots[], double openPrices[], double &commissions[], double &swaps[], double &profits[]) {
   double longPosition, shortPosition, totalPosition, hedgedLots, remainingLong, remainingShort, factor, openPrice, closePrice, commission, swap, floatingProfit, fullProfit, hedgedProfit, vtmProfit, pipValue, pipDistance;
   int error, ticketsSize = ArraySize(tickets);

   // resolve the symbol's total position: hedged volume (constant PL) + directional volume (variable PL)
   for (int i=0; i < ticketsSize; i++) {
      if (symbolsIdx[i] != index) continue;

      if (types[i] == OP_BUY) longPosition  += lots[i];              // add-up total volume per market direction
      else                    shortPosition += lots[i];
   }
   longPosition  = NormalizeDouble(longPosition,  2);
   shortPosition = NormalizeDouble(shortPosition, 2);
   totalPosition = NormalizeDouble(longPosition-shortPosition, 2);

   // TODO: digits may be erroneous
   int    digits     = MarketInfoEx(symbol, MODE_DIGITS, error, "CalculateProfit(1)"); if (error != NULL) return(EMPTY_VALUE);
   int    pipDigits  = digits & (~1);
   double pipSize    = NormalizeDouble(1/MathPow(10, pipDigits), pipDigits);
   double spread     = MarketInfoEx(symbol, MODE_SPREAD, error, "CalculateProfit(2)"); if (error != NULL) return(EMPTY_VALUE);
   double spreadPips = spread/MathPow(10, digits & 1);               // spread in pip

   // resolve the constant PL of a hedged position
   if (longPosition && shortPosition) {
      hedgedLots     = MathMin(longPosition, shortPosition);
      remainingLong  = hedgedLots;
      remainingShort = hedgedLots;

      for (i=0; i < ticketsSize; i++) {
         if (symbolsIdx[i] != index) continue;
         if (!tickets[i])            continue;

         if (types[i] == OP_BUY) {
            if (!remainingLong) continue;
            if (remainingLong >= lots[i]) {
               // take-over all data and nullify ticket
               openPrice     = NormalizeDouble(openPrice + lots[i] * openPrices[i], 8);
               swap         += swaps      [i];
               commission   += commissions[i];
               remainingLong = NormalizeDouble(remainingLong - lots[i], 3);
               tickets[i]    = NULL;
            }
            else {
               // take-over full swap and reduce the ticket's commission, PL and lotsize
               factor        = remainingLong/lots[i];
               openPrice     = NormalizeDouble(openPrice + remainingLong * openPrices[i], 8);
               swap         += swaps[i];                swaps      [i]  = 0;
               commission   += factor * commissions[i]; commissions[i] -= factor * commissions[i];
                                                        profits    [i] -= factor * profits    [i];
                                                        lots       [i]  = NormalizeDouble(lots[i]-remainingLong, 3);
               remainingLong = 0;
            }
         }
         else /*types[i] == OP_SELL*/ {
            if (!remainingShort) continue;
            if (remainingShort >= lots[i]) {
               // take-over all data and nullify ticket
               closePrice     = NormalizeDouble(closePrice + lots[i] * openPrices[i], 8);
               swap          += swaps      [i];
               //commission  += commissions[i];                                        // take-over commission only for the long leg
               remainingShort = NormalizeDouble(remainingShort - lots[i], 3);
               tickets[i]     = NULL;
            }
            else {
               // take-over full swap and reduce the ticket's commission, PL and lotsize
               factor         = remainingShort/lots[i];
               closePrice     = NormalizeDouble(closePrice + remainingShort * openPrices[i], 8);
               swap          += swaps[i]; swaps      [i]  = 0;
                                          commissions[i] -= factor * commissions[i];   // take-over commission only for the long leg
                                          profits    [i] -= factor * profits    [i];
                                          lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 3);
               remainingShort = 0;
            }
         }
      }
      if (remainingLong  != 0) return(_EMPTY_VALUE(catch("CalculateProfit(3)  illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR)));
      if (remainingShort != 0) return(_EMPTY_VALUE(catch("CalculateProfit(4)  illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR)));

      // calculate BE distance and the resulting PL
      pipValue     = PipValueEx(symbol, hedgedLots, error, "CalculateProfit(5)"); if (error != NULL) return(EMPTY_VALUE);
      pipDistance  = (closePrice-openPrice)/hedgedLots/pipSize + (commission+swap)/pipValue;
      hedgedProfit = pipDistance * pipValue;

      // without directional position return PL of the hedged position only
      if (!totalPosition) {
         fullProfit = NormalizeDouble(hedgedProfit, 2);
         return(ifDouble(!catch("CalculateProfit(6)"), fullProfit, EMPTY_VALUE));
      }
   }

   // calculate PL of a long position (if any)
   if (totalPosition > 0) {
      swap           = 0;
      commission     = 0;
      floatingProfit = 0;

      for (i=0; i < ticketsSize; i++) {
         if (symbolsIdx[i] != index) continue;
         if (!tickets[i])            continue;

         if (types[i] == OP_BUY) {
            swap           += swaps      [i];
            commission     += commissions[i];
            floatingProfit += profits    [i];
            tickets[i]      = NULL;
         }
      }
      // add the PL value of half of the spread
      pipDistance = spreadPips/2;
      pipValue    = PipValueEx(symbol, totalPosition, error, "CalculateProfit(7)"); if (error != NULL) return(EMPTY_VALUE);
      vtmProfit   = pipDistance * pipValue;
      fullProfit  = NormalizeDouble(hedgedProfit + floatingProfit + vtmProfit + swap + commission, 2);
      return(ifDouble(!catch("CalculateProfit(8)"), fullProfit, EMPTY_VALUE));
   }

   // calculate PL of a short position (if any)
   if (totalPosition < 0) {
      swap           = 0;
      commission     = 0;
      floatingProfit = 0;

      for (i=0; i < ticketsSize; i++) {
         if (symbolsIdx[i] != index) continue;
         if (!tickets[i])            continue;

         if (types[i] == OP_SELL) {
            swap           += swaps      [i];
            commission     += commissions[i];
            floatingProfit += profits    [i];
            tickets[i]      = NULL;
         }
      }
      // add the PL value of half of the spread
      pipDistance = spreadPips/2;
      pipValue    = PipValueEx(symbol, totalPosition, error, "CalculateProfit(9)"); if (error != NULL) return(EMPTY_VALUE);
      vtmProfit   = pipDistance * pipValue;
      fullProfit  = NormalizeDouble(hedgedProfit + floatingProfit + vtmProfit + swap + commission, 2);
      return(ifDouble(!catch("CalculateProfit(10)"), fullProfit, EMPTY_VALUE));
   }

   return(_EMPTY_VALUE(catch("CalculateProfit(11)  unreachable code reached", ERR_RUNTIME_ERROR)));
}


/**
 * Record the calculated equity values.
 *
 * @return bool - success status
 */
bool RecordData() {
   if (__isTesting) return(true);

   datetime now = TimeFXT();
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

         hSet[i] = HistorySet1.Get(symbol, recordingDirectory);
         if (hSet[i] == -1)
            hSet[i] = HistorySet1.Create(symbol, description, 2, recordingFormat, recordingDirectory);
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
   return(StringConcatenate("Recording.HistoryDirectory=", DoubleQuoteStr(Recording.HistoryDirectory), ";", NL,
                            "Recording.HistoryFormat=",    Recording.HistoryFormat,                    ";")
   );
}
