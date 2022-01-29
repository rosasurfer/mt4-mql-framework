/**
 * ZigZag EA
 *
 *
 * TODO:
 *  - start/stop and breaks at specific times of the day
 *  - implement stop condition "pip"
 *  - read/write status file
 *  - permanent performance tracking of all variants (ZZ, ZR) on all symbols
 *  - normalize resulting PL metrics for different accounts/unit sizes
 *  - reverse trading option
 *  - track PL curve per live instance
 *
 *  - double ZigZag reversals during large bars are not recognized and ignored
 *  - track slippage
 *  - reduce slippage on reversal: replace Close+Open by Hedge+CloseBy
 *  - input option to pick-up the last signal on start
 *
 *  - build script for all .ex4 files after deployment
 *  - ToggleOpenOrders() works only after ToggleHistory()
 *  - ChartInfos::onPositionOpen() doesn't log slippage
 *  - ChartInfos::CostumPosition() including/excluding a specific strategy
 *  - on restart delete dead screen sockets
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Sequence.ID         = "";                              // instance to load from a status file (id between 1000-9999)
extern int    ZigZag.Periods      = 40;

extern double Lots                = 0.1;
extern double TakeProfit          = 0;                               // TP value
extern string TakeProfit.Type     = "off* | money | percent | pip";  // may be shortened
extern int    Slippage            = 2;                               // in point

extern bool   ShowProfitInPercent = true;                            // whether PL is displayed in money or percentage terms

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define STRATEGY_ID               107           // unique strategy id between 101-1023 (10 bit)

#define STATUS_WAITING              1           // sequence status values
#define STATUS_PROGRESSING          2
#define STATUS_STOPPED              3

#define D_LONG   TRADE_DIRECTION_LONG           // 1
#define D_SHORT TRADE_DIRECTION_SHORT           // 2

#define SIGNAL_ENTRY_LONG      D_LONG           // 1
#define SIGNAL_ENTRY_SHORT    D_SHORT           // 2
#define SIGNAL_TAKEPROFIT           3

#define H_IDX_SIGNAL                0           // order history indexes
#define H_IDX_TICKET                1
#define H_IDX_LOTS                  2
#define H_IDX_OPENTYPE              3
#define H_IDX_OPENTIME              4
#define H_IDX_OPENPRICE             5
#define H_IDX_CLOSETIME             6
#define H_IDX_CLOSEPRICE            7
#define H_IDX_SLIPPAGE              8
#define H_IDX_SWAP                  9
#define H_IDX_COMMISSION           10
#define H_IDX_PROFIT               11
#define H_IDX_TOTALPROFIT          12

#define TP_TYPE_MONEY               1           // TakeProfit types
#define TP_TYPE_PERCENT             2
#define TP_TYPE_PIP                 3

// sequence data
int      sequence.id;
datetime sequence.created;
string   sequence.name = "";
int      sequence.status;
double   sequence.startEquity;                  //
double   sequence.openPL;                       // PL of all open positions (incl. commissions and swaps)
double   sequence.closedPL;                     // PL of all closed positions (incl. commissions and swaps)
double   sequence.totalPL;                      // total PL of the sequence: openPL + closedPL
double   sequence.maxProfit;                    // max. observed total profit:   0...+n
double   sequence.maxDrawdown;                  // max. observed total drawdown: -n...0

// order data
int      open.signal;                           // one open position
int      open.ticket;                           //
int      open.type;                             //
datetime open.time;                             //
double   open.price;                            //
double   open.slippage;                         //
double   open.swap;                             //
double   open.commission;                       //
double   open.profit;                           //
double   closed.history[][13];                  // multiple closed positions

// stop conditions ("OR" combined)
bool     stop.profitAbs.condition;              // whether a takeprofit condition in money is active
double   stop.profitAbs.value;
string   stop.profitAbs.description = "";

bool     stop.profitPct.condition;              // whether a takeprofit condition in percent is active
double   stop.profitPct.value;
double   stop.profitPct.absValue    = INT_MAX;
string   stop.profitPct.description = "";

bool     stop.profitPip.condition;              // whether a takeprofit condition in pip is active
double   stop.profitPip.value;
string   stop.profitPip.description = "";

// caching vars to speed-up ShowStatus()
string   sLots                = "";
string   sStopConditions      = "";
string   sSequenceTotalPL     = "";
string   sSequenceMaxProfit   = "";
string   sSequenceMaxDrawdown = "";
string   sSequencePlStats     = "";

// debug settings                                  // configurable via framework config, see afterInit()
bool     test.onStopPause    = false;              // whether to pause a test after StopSequence()
bool     test.optimizeStatus = true;               // whether to reduce status file writing in tester

#include <apps/zigzag-ea/init.mqh>
#include <apps/zigzag-ea/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!sequence.status) return(ERR_ILLEGAL_STATE);

   int zigzagSignal, stopSignal;
   bool isZigzagSignal = IsZigZagSignal(zigzagSignal);

   if (sequence.status == STATUS_WAITING) {
      if (isZigzagSignal) StartSequence(zigzagSignal);
   }
   else if (sequence.status == STATUS_PROGRESSING) {
      if (UpdateStatus()) {                                             // update order status and PL
         if (IsStopSignal(stopSignal)) StopSequence(stopSignal);
         else if (isZigzagSignal)      ReverseSequence(zigzagSignal);
      }
   }
   else if (sequence.status == STATUS_STOPPED) {}                       // nothing to do

   return(catch("onTick(1)"));
}


/**
 * Whether a new ZigZag reversal occurred.
 *
 * @param  _Out_ int &signal - variable receiving the signal identifier of an occurred reversal
 *
 * @return bool
 */
bool IsZigZagSignal(int &signal) {
   if (last_error != NULL) return(false);
   signal = NULL;

   static int lastSignal;
   int trend, reversal;

   if (!GetZigZagData(0, trend, reversal)) return(false);

   if (Abs(trend) == reversal) {
      if (trend > 0) {
         if (lastSignal != SIGNAL_ENTRY_LONG)  signal = SIGNAL_ENTRY_LONG;
      }
      else {
         if (lastSignal != SIGNAL_ENTRY_SHORT) signal = SIGNAL_ENTRY_SHORT;
      }
      if (signal != NULL) {
         if (IsLogInfo()) logInfo("IsZigZagSignal(1)  "+ sequence.name +" "+ ifString(signal==SIGNAL_ENTRY_LONG, "long", "short") +" reversal (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         lastSignal = signal;
         return(true);
      }
   }
   return(false);
}


/**
 * Get trend data of the ZigZag indicator at the specified bar offset.
 *
 * @param  _In_  int bar            - bar offset
 * @param  _Out_ int &combinedTrend - combined trend value at the bar offset
 * @param  _Out_ int &reversal      - reversal bar value at the bar offset
 *
 * @return bool - success status
 */
bool GetZigZagData(int bar, int &combinedTrend, int &reversal) {
   combinedTrend = Round(icZigZag(NULL, ZigZag.Periods, false, false, ZigZag.MODE_TREND,    bar));
   reversal      = Round(icZigZag(NULL, ZigZag.Periods, false, false, ZigZag.MODE_REVERSAL, bar));
   return(combinedTrend != 0);
}


/**
 * Start a waiting sequence.
 *
 * @param  int direction - trade direction to start with
 *
 * @return bool - success status
 */
bool StartSequence(int direction) {
   if (last_error != NULL)                      return(false);
   if (sequence.status != STATUS_WAITING)       return(!catch("StartSequence(1)  "+ sequence.name +" cannot start "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("StartSequence(2)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   SetLogfile(GetLogFilename());                               // flush the log on start
   if (IsLogInfo()) logInfo("StartSequence(3)  "+ sequence.name +" starting...");

   sequence.startEquity = NormalizeDouble(AccountEquity() - AccountCredit() + GetExternalAssets(), 2);
   sequence.status      = STATUS_PROGRESSING;

   // open new position
   int      type        = ifInt(direction==D_LONG, OP_BUY, OP_SELL);
   double   price       = NULL;
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ sequence.id;
   int      magicNumber = CalculateMagicNumber();
   color    markerColor = ifInt(direction==D_LONG, CLR_OPEN_LONG, CLR_OPEN_SHORT);
   int      oeFlags     = NULL, oe[];

   int ticket = OrderSendEx(Symbol(), type, Lots, price, Slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (!ticket) return(!SetLastError(oe.Error(oe)));

   // store position data
   open.signal     = direction;
   open.ticket     = ticket;
   open.type       = oe.Type      (oe);
   open.time       = oe.OpenTime  (oe);
   open.price      = oe.OpenPrice (oe);
   open.slippage   = oe.Slippage  (oe);
   open.swap       = oe.Swap      (oe);
   open.commission = oe.Commission(oe);
   open.profit     = oe.Profit    (oe);

   // update PL numbers
   sequence.openPL      = NormalizeDouble(open.swap + open.commission + open.profit, 2);
   sequence.totalPL     = NormalizeDouble(sequence.openPL + sequence.closedPL, 2);
   sequence.maxProfit   = MathMax(sequence.maxProfit, sequence.totalPL);
   sequence.maxDrawdown = MathMin(sequence.maxDrawdown, sequence.totalPL);
   SS.TotalPL();
   SS.PLStats();

   if (IsLogInfo()) logInfo("StartSequence(4)  "+ sequence.name +" sequence started");
   return(SaveStatus());
}


/**
 * Reverse a progressing sequence.
 *
 * @param  int direction - new trade direction to continue with
 *
 * @return bool - success status
 */
bool ReverseSequence(int direction) {
   if (last_error != NULL)                      return(false);
   if (sequence.status != STATUS_PROGRESSING)   return(!catch("ReverseSequence(1)  "+ sequence.name +" cannot reverse "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (direction!=D_LONG && direction!=D_SHORT) return(!catch("ReverseSequence(2)  "+ sequence.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   int lastDirection = ifInt(open.type==OP_BUY, D_LONG, D_SHORT);
   if (direction == lastDirection)              return(!catch("ReverseSequence(3)  "+ sequence.name +" cannot reverse sequence to the same direction: "+ ifString(direction==D_LONG, "long", "short"), ERR_ILLEGAL_STATE));

   // close open position
   int oeFlags, oe[];
   if (!OrderCloseEx(open.ticket, NULL, Slippage, CLR_NONE, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));
   if (!ArchiveClosedPosition(open.signal, open.slippage, oe))            return(false);

   // open new position
   int      type        = ifInt(direction==D_LONG, OP_BUY, OP_SELL);
   double   price       = NULL;
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ sequence.id;
   int      magicNumber = CalculateMagicNumber();
   color    markerColor = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);

   if (!OrderSendEx(Symbol(), type, Lots, price, Slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));
   open.signal     = direction;
   open.ticket     = oe.Ticket    (oe);
   open.type       = oe.Type      (oe);
   open.time       = oe.OpenTime  (oe);
   open.price      = oe.OpenPrice (oe);
   open.slippage   = oe.Slippage  (oe);
   open.swap       = oe.Swap      (oe);
   open.commission = oe.Commission(oe);
   open.profit     = oe.Profit    (oe);

   // update PL numbers
   sequence.openPL      = NormalizeDouble(open.swap + open.commission + open.profit, 2);
   sequence.totalPL     = NormalizeDouble(sequence.openPL + sequence.closedPL, 2);
   sequence.maxProfit   = MathMax(sequence.maxProfit, sequence.totalPL);
   sequence.maxDrawdown = MathMin(sequence.maxDrawdown, sequence.totalPL);
   SS.TotalPL();
   SS.PLStats();

   return(SaveStatus());
}


/**
 * Add the specified closed position data to the local history and reset open position data.
 *
 * @param int    openSignal   - signal which triggered opening of the now closed position
 * @param double openSlippage - opening slippage of the now closed position
 * @param int    oe[]         - order details of the now closed position
 *
 * @return bool - success status
 */
bool ArchiveClosedPosition(int openSignal, double openSlippage, int oe[]) {
   if (last_error != NULL)                    return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("ArchiveClosedPosition(1)  "+ sequence.name +" cannot archive position of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   int i = ArrayRange(closed.history, 0);
   ArrayResize(closed.history, i + 1);

   closed.history[i][H_IDX_SIGNAL     ] = openSignal;
   closed.history[i][H_IDX_TICKET     ] = oe.Ticket    (oe);
   closed.history[i][H_IDX_LOTS       ] = oe.Lots      (oe);
   closed.history[i][H_IDX_OPENTYPE   ] = oe.Type      (oe);
   closed.history[i][H_IDX_OPENTIME   ] = oe.OpenTime  (oe);
   closed.history[i][H_IDX_OPENPRICE  ] = oe.OpenPrice (oe);
   closed.history[i][H_IDX_CLOSETIME  ] = oe.CloseTime (oe);
   closed.history[i][H_IDX_CLOSEPRICE ] = oe.ClosePrice(oe);
   closed.history[i][H_IDX_SLIPPAGE   ] = NormalizeDouble(openSlippage + oe.Slippage(oe), Digits);
   closed.history[i][H_IDX_SWAP       ] = oe.Swap      (oe);
   closed.history[i][H_IDX_COMMISSION ] = oe.Commission(oe);
   closed.history[i][H_IDX_PROFIT     ] = oe.Profit    (oe);
   closed.history[i][H_IDX_TOTALPROFIT] = NormalizeDouble(closed.history[i][H_IDX_SWAP] + closed.history[i][H_IDX_COMMISSION] + closed.history[i][H_IDX_PROFIT], 2);

   open.signal     = NULL;
   open.ticket     = NULL;
   open.type       = NULL;
   open.time       = NULL;
   open.price      = NULL;
   open.slippage   = NULL;
   open.swap       = NULL;
   open.commission = NULL;
   open.profit     = NULL;

   sequence.openPL   = 0;
   sequence.closedPL = NormalizeDouble(sequence.closedPL + closed.history[i][H_IDX_TOTALPROFIT], 2);
   sequence.totalPL  = sequence.closedPL;

   return(!catch("ArchiveClosedPosition(2)"));
}


/**
 * Whether a stop condition is satisfied for a progressing sequence.
 *
 * @param  _Out_ int &signal - variable receiving the signal identifier of a fulfilled stop condition
 *
 * @return bool
 */
bool IsStopSignal(int &signal) {
   signal = NULL;
   if (last_error != NULL)                    return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("IsStopSignal(1)  "+ sequence.name +" cannot check stop signal of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   // stop.profitAbs: -------------------------------------------------------------------------------------------------------
   if (stop.profitAbs.condition) {
      if (sequence.totalPL >= stop.profitAbs.value) {
         if (IsLogNotice()) logNotice("IsStopSignal(2)  "+ sequence.name +" stop condition \"@"+ stop.profitAbs.description +"\" fulfilled (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         signal = SIGNAL_TAKEPROFIT;
         return(true);
      }
   }

   // stop.profitPct: -------------------------------------------------------------------------------------------------------
   if (stop.profitPct.condition) {
      if (stop.profitPct.absValue == INT_MAX)
         stop.profitPct.absValue = stop.profitPct.AbsValue();

      if (sequence.totalPL >= stop.profitPct.absValue) {
         if (IsLogNotice()) logNotice("IsStopSignal(3)  "+ sequence.name +" stop condition \"@"+ stop.profitPct.description +"\" fulfilled (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         signal = SIGNAL_TAKEPROFIT;
         return(true);
      }
   }

   // stop.profitPip: -------------------------------------------------------------------------------------------------------
   if (stop.profitPip.condition) {
      return(!catch("IsStopSignal(4)  stop.profitPip.condition not implemented", ERR_NOT_IMPLEMENTED));
   }

   return(false);
}


/**
 * Return the absolute value of a percentage type TakeProfit condition.
 *
 * @return double - absolute value or INT_MAX if no percentage TakeProfit was configured
 */
double stop.profitPct.AbsValue() {
   if (stop.profitPct.condition) {
      if (stop.profitPct.absValue == INT_MAX) {
         double startEquity = sequence.startEquity;
         if (!startEquity) startEquity = AccountEquity() - AccountCredit() + GetExternalAssets();
         return(stop.profitPct.value/100 * startEquity);
      }
   }
   return(stop.profitPct.absValue);
}


/**
 * Stop a waiting or progressing sequence. Close open positions (if any).
 *
 * @param  int signal - signal which triggered the stop condition or NULL on explicit (i.e. manual) stop
 *
 * @return bool - success status
 */
bool StopSequence(int signal) {
   if (last_error != NULL)                                                     return(false);
   if (sequence.status!=STATUS_WAITING && sequence.status!=STATUS_PROGRESSING) return(!catch("StopSequence(1)  "+ sequence.name +" cannot stop "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   if (sequence.status == STATUS_PROGRESSING) {    // a progressing sequence has an open position to close
      if (IsLogInfo()) logInfo("StopSequence(2)  "+ sequence.name +" stopping...");

      int oeFlags, oe[];
      if (!OrderCloseEx(open.ticket, NULL, Slippage, CLR_NONE, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));
      if (!ArchiveClosedPosition(open.signal, open.slippage, oe))            return(false);

      sequence.maxProfit   = MathMax(sequence.maxProfit, sequence.totalPL);
      sequence.maxDrawdown = MathMin(sequence.maxDrawdown, sequence.totalPL);
      SS.TotalPL();
      SS.PLStats();
   }
   sequence.status = STATUS_STOPPED;

   if (IsLogInfo()) logInfo("StopSequence(3)  "+ sequence.name +" sequence stopped, profit: "+ sSequenceTotalPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   SaveStatus();

   if (IsTesting()) {                              // pause or stop the tester according to the debug configuration
      if (!IsVisualMode())       Tester.Stop ("StopSequence(4)");
      else if (test.onStopPause) Tester.Pause("StopSequence(5)");
   }
   return(!catch("StopSequence(6)"));
}


/**
 * Update order status and PL.
 *
 * @return bool - success status
 */
bool UpdateStatus() {
   if (last_error != NULL)                            return(false);
   if (sequence.status != STATUS_PROGRESSING)         return(!catch("UpdateStatus(1)  "+ sequence.name +" cannot update order status of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (!SelectTicket(open.ticket, "UpdateStatus(2)")) return(false);

   open.swap       = OrderSwap();
   open.commission = OrderCommission();
   open.profit     = OrderProfit();

   sequence.openPL  = NormalizeDouble(open.swap + open.commission + open.profit, 2);
   sequence.totalPL = NormalizeDouble(sequence.openPL + sequence.closedPL, 2); SS.TotalPL();

   if      (sequence.totalPL > sequence.maxProfit  ) { sequence.maxProfit   = sequence.totalPL; SS.PLStats(); }
   else if (sequence.totalPL < sequence.maxDrawdown) { sequence.maxDrawdown = sequence.totalPL; SS.PLStats(); }

   return(!catch("UpdateStatus(3)"));
}


/**
 * Calculate a magic order number for the strategy.
 *
 * @param  int sequenceId [optional] - sequence to calculate the magic number for (default: the current sequence)
 *
 * @return int - magic number or NULL in case of errors
 */
int CalculateMagicNumber(int sequenceId = NULL) {
   if (STRATEGY_ID < 101 || STRATEGY_ID > 1023) return(!catch("CalculateMagicNumber(1)  "+ sequence.name +" illegal strategy id: "+ STRATEGY_ID, ERR_ILLEGAL_STATE));
   int id = intOr(sequenceId, sequence.id);
   if (id < 1000 || id > 9999)                  return(!catch("CalculateMagicNumber(2)  "+ sequence.name +" illegal sequence id: "+ id, ERR_ILLEGAL_STATE));

   int strategy = STRATEGY_ID;                              //  101-1023 (10 bit)
   int sequence = id;                                       // 1000-9999 (14 bit)

   return((strategy<<22) + (sequence<<8));                  // the remaining 8 bit are not used in this strategy
}


/**
 * Generate a new sequence id. Must be unique for all instances of this strategy.
 *
 * @return int - sequence id in the range of 1000-9999 or NULL in case of errors
 */
int CreateSequenceId() {
   MathSrand(GetTickCount()-__ExecutionContext[EC.hChartWindow]);
   int sequenceId, magicNumber;

   while (!magicNumber) {
      while (sequenceId < SID_MIN || sequenceId > SID_MAX) {
         sequenceId = MathRand();                                 // TODO: generate consecutive ids in tester
      }
      magicNumber = CalculateMagicNumber(sequenceId); if (!magicNumber) return(NULL);

      // test for uniqueness against open orders
      int openOrders = OrdersTotal();
      for (int i=0; i < openOrders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) return(!catch("CreateSequenceId(1)  "+ sequence.name, intOr(GetLastError(), ERR_RUNTIME_ERROR)));
         if (OrderMagicNumber() == magicNumber) {
            magicNumber = NULL;
            break;
         }
      }
      if (!magicNumber) continue;

      // test for uniqueness against closed orders
      int closedOrders = OrdersHistoryTotal();
      for (i=0; i < closedOrders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) return(!catch("CreateSequenceId(2)  "+ sequence.name, intOr(GetLastError(), ERR_RUNTIME_ERROR)));
         if (OrderMagicNumber() == magicNumber) {
            magicNumber = NULL;
            break;
         }
      }
   }
   return(sequenceId);
}


/**
 * Return the full name of the instance logfile.
 *
 * @return string - filename or an empty string in case of errors
 */
string GetLogFilename() {
   string name = GetStatusFilename();
   if (!StringLen(name)) return("");
   return(StrLeftTo(name, ".", -1) +".log");
}


/**
 * Return the full name of the instance status file.
 *
 * @param  relative [optional] - whether to return the absolute path or the path relative to the MQL "files" directory
 *                               (default: the absolute path)
 *
 * @return string - filename or an empty string in case of errors
 */
string GetStatusFilename(bool relative = false) {
   relative = relative!=0;
   if (!sequence.id) return(_EMPTY_STR(catch("GetStatusFilename(1)  "+ sequence.name +" illegal value of sequence.id: "+ sequence.id, ERR_ILLEGAL_STATE)));

   static string filename = ""; if (!StringLen(filename)) {
      string directory = "presets\\" + ifString(IsTesting(), "Tester", GetAccountCompany()) +"\\";
      string baseName  = StrToLower(Symbol()) +".ZigZag."+ sequence.id +".set";
      filename = directory + baseName;
   }

   if (relative)
      return(filename);
   return(GetMqlFilesPath() +"\\"+ filename);
}


/**
 * Return a description of a sequence status code.
 *
 * @param  int status
 *
 * @return string - description or an empty string in case of errors
 */
string StatusDescription(int status) {
   switch (status) {
      case NULL              : return("undefined"  );
      case STATUS_WAITING    : return("waiting"    );
      case STATUS_PROGRESSING: return("progressing");
      case STATUS_STOPPED    : return("stopped"    );
   }
   return(_EMPTY_STR(catch("StatusDescription(1)  "+ sequence.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Restore the internal state of the EA from a status file. Requires 'sequence.id' to be set.
 *
 * @return bool - success status
 */
bool RestoreSequence() {
   if (IsLastError())     return(false);
   if (!ReadStatus())     return(false);                 // read and apply the status file
   if (!ValidateInputs()) return(false);                 // validate restored input parameters
   //if (!SynchronizeStatus()) return(false);            // synchronize restored state with the trade server
   return(true);
}


/**
 * Read the status file of the sequence and set input parameters and runtime variables. Called only from RestoreSequence().
 *
 * @return bool - success status
 */
bool ReadStatus() {
   if (IsLastError()) return(false);
   if (!sequence.id)  return(!catch("ReadStatus(1)  illegal value of sequence.id: "+ sequence.id, ERR_ILLEGAL_STATE));

   return(!catch("ReadStatus(2)", ERR_NOT_IMPLEMENTED));
}


/**
 * Write the current sequence status to a file.
 *
 * @return bool - success status
 */
bool SaveStatus() {
   if (last_error != NULL)                       return(false);
   if (!sequence.id || StrTrim(Sequence.ID)=="") return(!catch("SaveStatus(1)  illegal sequence id: input Sequence.ID="+ DoubleQuoteStr(Sequence.ID) +", var sequence.id="+ sequence.id, ERR_ILLEGAL_STATE));

   logInfo("SaveStatus(2)", ERR_NOT_IMPLEMENTED);
   return(true);
}


// backed-up input parameters
string   prev.Sequence.ID = "";
int      prev.ZigZag.Periods;
double   prev.Lots;
double   prev.TakeProfit;
string   prev.TakeProfit.Type = "";
int      prev.Slippage;
bool     prev.ShowProfitInPercent;

// backed-up runtime variables affected by changing input parameters
int      prev.sequence.id;
datetime prev.sequence.created;
string   prev.sequence.name = "";
int      prev.sequence.status;

bool     prev.stop.profitAbs.condition;
double   prev.stop.profitAbs.value;
string   prev.stop.profitAbs.description = "";
bool     prev.stop.profitPct.condition;
double   prev.stop.profitPct.value;
double   prev.stop.profitPct.absValue;
string   prev.stop.profitPct.description = "";
bool     prev.stop.profitPip.condition;
double   prev.stop.profitPip.value;
string   prev.stop.profitPip.description = "";


/**
 * Programatically changed input parameters don't survive init cycles. Therefore inputs are backed-up in deinit() and can be
 * restored in init(). Called in onDeinitParameters() and onDeinitChartChange().
 */
void BackupInputs() {
   // backup input parameters, also accessed for comparison in ValidateInputs()
   prev.Sequence.ID         = StringConcatenate(Sequence.ID, "");    // string inputs are references to internal C literals and must be copied to break the reference
   prev.ZigZag.Periods      = ZigZag.Periods;
   prev.Lots                = Lots;
   prev.TakeProfit          = TakeProfit;
   prev.TakeProfit.Type     = StringConcatenate(TakeProfit.Type, "");
   prev.Slippage            = Slippage;
   prev.ShowProfitInPercent = ShowProfitInPercent;

   // backup runtime variables affected by changing input parameters
   prev.sequence.id                = sequence.id;
   prev.sequence.created           = sequence.created;
   prev.sequence.name              = sequence.name;
   prev.sequence.status            = sequence.status;

   prev.stop.profitAbs.condition   = stop.profitAbs.condition;
   prev.stop.profitAbs.value       = stop.profitAbs.value;
   prev.stop.profitAbs.description = stop.profitAbs.description;
   prev.stop.profitPct.condition   = stop.profitPct.condition;
   prev.stop.profitPct.value       = stop.profitPct.value;
   prev.stop.profitPct.absValue    = stop.profitPct.absValue;
   prev.stop.profitPct.description = stop.profitPct.description;
   prev.stop.profitPip.condition   = stop.profitPip.condition;
   prev.stop.profitPip.value       = stop.profitPip.value;
   prev.stop.profitPip.description = stop.profitPip.description;
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // restore input parameters
   Sequence.ID         = prev.Sequence.ID;
   ZigZag.Periods      = prev.ZigZag.Periods;
   Lots                = prev.Lots;
   TakeProfit          = prev.TakeProfit;
   TakeProfit.Type     = prev.TakeProfit.Type;
   Slippage            = prev.Slippage;
   ShowProfitInPercent = prev.ShowProfitInPercent;

   // restore runtime variables
   sequence.id                = prev.sequence.id;
   sequence.created           = prev.sequence.created;
   sequence.name              = prev.sequence.name;
   sequence.status            = prev.sequence.status;

   stop.profitAbs.condition   = prev.stop.profitAbs.condition;
   stop.profitAbs.value       = prev.stop.profitAbs.value;
   stop.profitAbs.description = prev.stop.profitAbs.description;
   stop.profitPct.condition   = prev.stop.profitPct.condition;
   stop.profitPct.value       = prev.stop.profitPct.value;
   stop.profitPct.absValue    = prev.stop.profitPct.absValue;
   stop.profitPct.description = prev.stop.profitPct.description;
   stop.profitPip.condition   = prev.stop.profitPip.condition;
   stop.profitPip.value       = prev.stop.profitPip.value;
   stop.profitPip.description = prev.stop.profitPip.description;
}


/**
 * Syntactically validate and restore a specified sequence id (id between 1000-9999). Called only from onInitUser().
 *
 * @return bool - whether an id was successfully restored (the status file is not checked)
 */
bool ValidateInputs.SID() {
   string sValue = StrTrim(Sequence.ID);
   if (!StringLen(sValue)) return(false);

   if (!StrIsDigit(sValue))                  return(!onInputError("ValidateInputs.SID(1)  invalid input parameter Sequence.ID: "+ DoubleQuoteStr(Sequence.ID) +" (must be digits only)"));
   int iValue = StrToInteger(sValue);
   if (iValue < SID_MIN || iValue > SID_MAX) return(!onInputError("ValidateInputs.SID(2)  invalid input parameter Sequence.ID: "+ DoubleQuoteStr(Sequence.ID) +" (range error)"));

   sequence.id = iValue;
   Sequence.ID = sequence.id;
   SS.SequenceName();
   return(true);
}


/**
 * Validate the input parameters. Parameters may have been entered through the input dialog, read from a status file or
 * deserialized and applied programmatically by the terminal (e.g. at terminal restart). Called from onInitUser(),
 * onInitParameters() or onInitTemplate().
 *
 * @return bool - whether input parameters are valid
 */
bool ValidateInputs() {
   if (IsLastError()) return(false);
   bool isParameterChange  = (ProgramInitReason()==IR_PARAMETERS);   // whether we validate manual or programatic input
   bool sequenceWasStarted = (open.ticket || ArrayRange(closed.history, 0));

   // Sequence.ID
   if (isParameterChange) {
      string sValues[], sValue=StrTrim(Sequence.ID);
      if (sValue == "") {                                            // the id was deleted or not yet set, re-apply the internal id
         Sequence.ID = prev.Sequence.ID;
      }
      else if (sValue != prev.Sequence.ID)                           return(!onInputError("ValidateInputs(1)  "+ sequence.name +" switching to another sequence is not supported (unload the EA first)"));
   } //else                                                          // onInitUser(): the id is empty (a new sequence) or already validated (an existing sequence is reloaded)

   // ZigZag.Periods
   if (isParameterChange && ZigZag.Periods!=prev.ZigZag.Periods) {
      if (sequenceWasStarted)                                        return(!onInputError("ValidateInputs(2)  "+ sequence.name +" cannot change parameter ZigZag.Periods of "+ StatusDescription(sequence.status) +" sequence"));
   }
   if (ZigZag.Periods < 2)                                           return(!onInputError("ValidateInputs(3)  "+ sequence.name +" invalid parameter ZigZag.Periods: "+ ZigZag.Periods));

   // Lots
   if (isParameterChange && NE(Lots, prev.Lots)) {
      if (sequenceWasStarted)                                        return(!onInputError("ValidateInputs(4)  "+ sequence.name +" cannot change parameter Lots of "+ StatusDescription(sequence.status) +" sequence"));
   }
   if (LT(Lots, 0))                                                  return(!onInputError("ValidateInputs(5)  "+ sequence.name +" invalid parameter Lots: "+ NumberToStr(Lots, ".1+") +" (too small)"));
   if (NE(Lots, NormalizeLots(Lots)))                                return(!onInputError("ValidateInputs(6)  "+ sequence.name +" invalid parameter Lots: "+ NumberToStr(Lots, ".1+") +" (not a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   // TakeProfit
   if (LT(TakeProfit, 0))                                            return(!onInputError("ValidateInputs(7)  "+ sequence.name +" invalid parameter TakeProfit: "+ NumberToStr(TakeProfit, ".1+") +" (too small)"));

   // TakeProfit.Type
   sValue = StrToLower(TakeProfit.Type);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL), type;
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("off",     sValue)) { TakeProfit.Type = "off";     type = NULL;            }
   else if (StrStartsWith("money",   sValue)) { TakeProfit.Type = "money";   type = TP_TYPE_MONEY;   }
   else if (StringLen(sValue) < 2)                                   return(!onInputError("ValidateInputs(8)  invalid parameter TakeProfit.Type "+ DoubleQuoteStr(TakeProfit.Type)));
   else if (StrStartsWith("percent", sValue)) { TakeProfit.Type = "percent"; type = TP_TYPE_PERCENT; }
   else if (StrStartsWith("pip",     sValue)) { TakeProfit.Type = "pip";     type = TP_TYPE_PIP;     }
   else                                                              return(!onInputError("ValidateInputs(9)  invalid parameter TakeProfit.Type "+ DoubleQuoteStr(TakeProfit.Type)));
   stop.profitAbs.condition   = false;
   stop.profitAbs.description = "";
   stop.profitPct.condition   = false;
   stop.profitPct.description = "";
   stop.profitPip.condition   = false;
   stop.profitPip.description = "";

   switch (type) {
      case TP_TYPE_MONEY:
         stop.profitAbs.condition   = true;
         stop.profitAbs.value       = NormalizeDouble(TakeProfit, 2);
         stop.profitAbs.description = "profit("+ DoubleToStr(stop.profitAbs.value, 2) +")";
         break;

      case TP_TYPE_PERCENT:
         stop.profitPct.condition   = true;
         stop.profitPct.value       = TakeProfit;
         stop.profitPct.absValue    = INT_MAX;
         stop.profitPct.description = "profit("+ NumberToStr(stop.profitPct.value, ".+") +"%)";
         break;

      case TP_TYPE_PIP:
         stop.profitPip.condition   = true;
         stop.profitPip.value       = NormalizeDouble(TakeProfit, 1);
         stop.profitPip.description = "profit("+ NumberToStr(stop.profitPip.value, ".+") +" pip)";
         break;
   }

   return(!catch("ValidateInputs(10)"));
}


/**
 * Error handler for invalid input parameters. Depending on the execution context a non-/terminating error is set.
 *
 * @param  string message - error message
 *
 * @return int - error status
 */
int onInputError(string message) {
   int error = ERR_INVALID_PARAMETER;

   if (ProgramInitReason() == IR_PARAMETERS)
      return(logError(message, error));            // non-terminating
   return(catch(message, error));                  // terminating
}


/**
 * Store the current sequence id in the chart (for template changes, terminal restart, recompilation etc).
 *
 * @return bool - success status
 */
bool StoreSequenceId() {
   if (!__isChart) return(false);
   return(Chart.StoreString(ProgramName() +".Sequence.ID", sequence.id));
}


/**
 * Restore a sequence id found in the chart (for template changes, terminal restart, recompilation etc).
 *
 * @return bool - whether a sequence id was successfully restored
 */
bool FindSequenceId() {
   string sValue = "";

   if (Chart.RestoreString(ProgramName() +".Sequence.ID", sValue)) {
      if (StrIsDigit(sValue)) {
         int iValue = StrToInteger(sValue);
         if (iValue > 0) {
            sequence.id = iValue;
            Sequence.ID = sequence.id;
            SS.SequenceName();
            return(true);
         }
      }
   }
   return(false);
}


/**
 * Remove stored sequence data from the chart.
 *
 * @return bool - success status
 */
bool RemoveSequenceData() {
   if (!__isChart) return(false);

   string label = ProgramName() +".status";
   if (ObjectFind(label) != -1)
      ObjectDelete(label);
   Chart.RestoreString(ProgramName() +".Sequence.ID", label);
   return(true);
}


/**
 * ShowStatus: Update all string representations.
 */
void SS.All() {
   if (__isChart) {
      SS.SequenceName();
      SS.Lots();
      SS.StopConditions();
      SS.TotalPL();
      SS.PLStats();
   }
}


/**
 * ShowStatus: Update the string representation of the sequence name.
 */
void SS.SequenceName() {
   sequence.name = "Z."+ sequence.id;
}


/**
 * ShowStatus: Update the string representation of the lotsize.
 */
void SS.Lots() {
   if (__isChart) {
      sLots = NumberToStr(Lots, ".+");
   }
}


/**
 * ShowStatus: Update the string representation of the configured stop conditions.
 */
void SS.StopConditions() {
   if (__isChart) {
      string sValue = "";

      if (stop.profitAbs.description != "") {
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(stop.profitAbs.condition, "@", "!") + stop.profitAbs.description;
      }
      if (stop.profitPct.description != "") {
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(stop.profitPct.condition, "@", "!") + stop.profitPct.description;
      }
      if (stop.profitPip.description != "") {
         sValue = sValue + ifString(sValue=="", "", " | ") + ifString(stop.profitPip.condition, "@", "!") + stop.profitPip.description;
      }
      if (sValue == "") sStopConditions = "-";
      else              sStopConditions = sValue;
   }
}


/**
 * ShowStatus: Update the string representation of "sequence.totalPL".
 */
void SS.TotalPL() {
   if (__isChart) {
      // not before a position was opened
      if (!open.ticket && !ArrayRange(closed.history, 0)) sSequenceTotalPL = "-";
      else if (ShowProfitInPercent)                       sSequenceTotalPL = NumberToStr(MathDiv(sequence.totalPL, sequence.startEquity) * 100, "+.2") +"%";
      else                                                sSequenceTotalPL = NumberToStr(sequence.totalPL, "+.2");
   }
}


/**
 * ShowStatus: Update the string representaton of the PL statistics.
 */
void SS.PLStats() {
   if (__isChart) {
      // not before a position was opened
      if (!open.ticket && !ArrayRange(closed.history, 0)) {
         sSequencePlStats = "";
      }
      else {
         string sSequenceMaxProfit="", sSequenceMaxDrawdown="";
         if (ShowProfitInPercent) {
            sSequenceMaxProfit   = NumberToStr(MathDiv(sequence.maxProfit, sequence.startEquity) * 100, "+.2") +"%";
            sSequenceMaxDrawdown = NumberToStr(MathDiv(sequence.maxDrawdown, sequence.startEquity) * 100, "+.2") +"%";
         }
         else {
            sSequenceMaxProfit   = NumberToStr(sequence.maxProfit, "+.2");
            sSequenceMaxDrawdown = NumberToStr(sequence.maxDrawdown, "+.2");
         }
         sSequencePlStats = StringConcatenate("(", sSequenceMaxProfit, " / ", sSequenceMaxDrawdown, ")");
      }
   }
}


/**
 * Display the current runtime status.
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error or the current error status if no error was specified
 */
int ShowStatus(int error = NO_ERROR) {
   if (!__isChart) return(error);

   static bool isRecursion = false;                   // to prevent recursive calls a specified error is displayed only once
   if (error != 0) {
      if (isRecursion) return(error);
      isRecursion = true;
   }
   string sStatus="", sError="";

   switch (sequence.status) {
      case NULL:               sStatus = "not initialized";                                 break;
      case STATUS_WAITING:     sStatus = StringConcatenate(sequence.name, "  waiting");     break;
      case STATUS_PROGRESSING: sStatus = StringConcatenate(sequence.name, "  progressing"); break;
      case STATUS_STOPPED:     sStatus = StringConcatenate(sequence.name, "  stopped");     break;
      default:
         return(catch("ShowStatus(1)  "+ sequence.name +" illegal sequence status: "+ sequence.status, ERR_ILLEGAL_STATE));
   }
   if (__STATUS_OFF) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason), "]");

   string text = StringConcatenate(ProgramName(), "    ", sStatus, sError,                 NL,
                                                                                           NL,
                                  "Lots:      ", sLots,                                    NL,
                                  "Stop:     ",  sStopConditions,                          NL,
                                  "Profit:   ",  sSequenceTotalPL, "  ", sSequencePlStats, NL
   );

   // 3 lines margin-top for instrument and indicator legends
   Comment(NL, NL, NL, text);
   if (__CoreFunction == CF_INIT) WindowRedraw();

   error = intOr(catch("ShowStatus(2)"), error);
   isRecursion = false;
   return(error);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Sequence.ID=",         DoubleQuoteStr(Sequence.ID),     ";", NL,
                            "ZigZag.Periods=",      ZigZag.Periods,                  ";", NL,
                            "Lots=",                NumberToStr(Lots, ".1+"),        ";", NL,
                            "TakeProfit=",          NumberToStr(TakeProfit, ".1+"),  ";", NL,
                            "TakeProfit.Type=",     DoubleQuoteStr(TakeProfit.Type), ";", NL,
                            "Slippage=",            Slippage,                        ";", NL,
                            "ShowProfitInPercent=", BoolToStr(ShowProfitInPercent),  ";")
   );
}
