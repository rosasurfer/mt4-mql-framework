/**
 * ZigZag EA
 *
 *
 * TODO:
 *  - store closed positions in history
 *  - track PL curve per instance
 *  - TakeProfit in {percent|pip}
 *
 *  - double ZigZag reversals during large bars are not recognized and ignored
 *  - build script for all .ex4 files after deployment
 *  - track slippage
 *  - input option to pick-up the last signal on start
 *
 *  - delete old/dead screen sockets on restart
 *  - ToggleOpenOrders() works only after ToggleHistory()
 *  - ChartInfos::onPositionOpen() doesn't log slippage
 *  - reduce slippage on reversal: replace Close+Open by Hedge+CloseBy
 *  - configuration/start at a specific time of day
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_BUFFERED_LOG};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Sequence.ID         = "";      // instance to load from a status file (id between 1000-9999)
extern int    ZigZag.Periods      = 40;
extern double Lots                = 0.1;
extern int    Slippage            = 2;       // in point
extern bool   ShowProfitInPercent = true;    // whether PL is displayed as absolute or percentage value

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define STRATEGY_ID               107        // unique strategy id between 101-1023 (10 bit)

#define STATUS_WAITING              1        // sequence status values
#define STATUS_PROGRESSING          2
#define STATUS_STOPPED              3

#define D_LONG   TRADE_DIRECTION_LONG        // 1
#define D_SHORT TRADE_DIRECTION_SHORT        // 2

#define SIGNAL_LONG            D_LONG        // 1
#define SIGNAL_SHORT          D_SHORT        // 2

// sequence data
int      sequence.id;
datetime sequence.created;
string   sequence.name;
int      sequence.status;
double   sequence.startEquity;               //
double   sequence.openPL;                    // PL of all open positions (incl. commissions and swaps)
double   sequence.closedPL;                  // PL of all closed positions (incl. commissions and swaps)
double   sequence.totalPL;                   // total PL of the sequence: openPL + closedPL
double   sequence.maxProfit;                 // max. observed total profit:   0...+n
double   sequence.maxDrawdown;               // max. observed total drawdown: -n...0

// order data
int      open.ticket;                        // one open position
int      open.type;                          //
datetime open.time;                          //
double   open.price;                         //
double   open.swap;                          //
double   open.commission;                    //
double   open.profit;                        //
double   closed.history[][23];               // multiple closed positions

// cache vars to speed-up ShowStatus()
string   sSequenceTotalPL     = "";
string   sSequenceMaxProfit   = "";
string   sSequenceMaxDrawdown = "";
string   sSequencePlStats     = "";

#include <apps/zigzag-ea/init.mqh>
#include <apps/zigzag-ea/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!sequence.status) return(ERR_ILLEGAL_STATE);

   int signal;
   bool isSignal = IsZigZagSignal(signal);

   if (sequence.status == STATUS_WAITING) {
      if (isSignal) StartSequence(signal);
   }
   else if (sequence.status == STATUS_PROGRESSING) {
      if (UpdateStatus()) {                              // update order status and PL
         if      (IsStopSignal()) StopSequence();
         else if (isSignal)       ReverseSequence(signal);
      }
   }
   else if (sequence.status == STATUS_STOPPED) {}        // nothing to do

   return(catch("onTick(1)"));
}


/**
 * Whether a new ZigZag reversal occurred.
 *
 * @param  _Out_ int &signal - variable receiving the identifier of an occurred reversal
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
         if (lastSignal != SIGNAL_LONG)  signal = SIGNAL_LONG;
      }
      else {
         if (lastSignal != SIGNAL_SHORT) signal = SIGNAL_SHORT;
      }
      if (signal != NULL) {
         if (IsLogInfo()) logInfo("IsZigZagSignal(1)  "+ sequence.name +" "+ ifString(signal==SIGNAL_LONG, "long", "short") +" reversal (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
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
   open.ticket     = ticket;
   open.type       = oe.Type      (oe);
   open.time       = oe.OpenTime  (oe);
   open.price      = oe.OpenPrice (oe);
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
   if (direction == lastDirection)              return(!catch("ReverseSequence(3)  "+ sequence.name +" cannot reverse sequence into the same direction: "+ ifString(direction==D_LONG, "long", "short"), ERR_ILLEGAL_STATE));

   // close open position
   int oe[], oeFlags;
   if (!OrderCloseEx(open.ticket, NULL, Slippage, CLR_NONE, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));

   open.ticket     = NULL;
   open.type       = NULL;
   open.time       = NULL;
   open.price      = NULL;
   open.swap       = NULL;
   open.commission = NULL;
   open.profit     = NULL;                         // TODO: add closed position to history

   sequence.openPL   = 0;                          // update PL numbers
   sequence.closedPL = NormalizeDouble(sequence.closedPL + oe.Swap(oe) + oe.Commission(oe) + oe.Profit(oe), 2);
   sequence.totalPL  = sequence.closedPL;

   // open new position
   int      type        = ifInt(direction==D_LONG, OP_BUY, OP_SELL);
   double   price       = NULL;
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ sequence.id;
   int      magicNumber = CalculateMagicNumber();
   color    markerColor = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);

   int ticket = OrderSendEx(Symbol(), type, Lots, price, Slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (!ticket) return(!SetLastError(oe.Error(oe)));

   open.ticket     = ticket;
   open.type       = oe.Type      (oe);
   open.time       = oe.OpenTime  (oe);
   open.price      = oe.OpenPrice (oe);
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
 * Whether a stop condition is satisfied for a progressing sequence.
 *
 * @return bool
 */
bool IsStopSignal() {
   if (last_error != NULL)                    return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("IsStopSignal(1)  "+ sequence.name +" cannot check stop signal of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   return(false);
}


/**
 * Stop a waiting or progressing sequence. Closes open positions (if any).
 *
 * @return bool - success status
 */
bool StopSequence() {
   if (last_error != NULL)                                                     return(false);
   if (sequence.status!=STATUS_WAITING && sequence.status!=STATUS_PROGRESSING) return(!catch("StopSequence(1)  "+ sequence.name +" cannot stop "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   if (sequence.status == STATUS_PROGRESSING) {    // a progressing sequence has an open position to close
      if (IsLogInfo()) logInfo("StopSequence(2)  "+ sequence.name +" stopping...");

      int oe[], oeFlags;
      if (!OrderCloseEx(open.ticket, NULL, Slippage, CLR_NONE, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));

      open.ticket     = NULL;
      open.type       = NULL;
      open.time       = NULL;
      open.price      = NULL;
      open.swap       = NULL;
      open.commission = NULL;
      open.profit     = NULL;                       // TODO: add closed position to history

      sequence.openPL      = 0;                    // update total PL numbers
      sequence.closedPL    = NormalizeDouble(sequence.closedPL + oe.Swap(oe) + oe.Commission(oe) + oe.Profit(oe), 2);
      sequence.totalPL     = sequence.closedPL;
      sequence.maxProfit   = MathMax(sequence.maxProfit, sequence.totalPL);
      sequence.maxDrawdown = MathMin(sequence.maxDrawdown, sequence.totalPL);
      SS.TotalPL();
      SS.PLStats();
   }
   sequence.status = STATUS_STOPPED;

   if (IsLogInfo()) logInfo("StopSequence(3)  "+ sequence.name +" sequence stopped, profit: "+ sSequenceTotalPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   return(SaveStatus());
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

   debug("SaveStatus(2)", ERR_NOT_IMPLEMENTED);
   return(true);
}


// backed-up input parameters
string   prev.Sequence.ID = "";
int      prev.ZigZag.Periods;
double   prev.Lots;
int      prev.Slippage;
bool     prev.ShowProfitInPercent;

// backed-up runtime variables affected by changing input parameters
int      prev.sequence.id;
datetime prev.sequence.created;
string   prev.sequence.name;
int      prev.sequence.status;


/**
 * Programatically changed input parameters don't survive init cycles. Therefore inputs are backed-up in deinit() and can be
 * restored in init(). Called in onDeinitParameters() and onDeinitChartChange().
 */
void BackupInputs() {
   // backup input parameters, also accessed for comparison in ValidateInputs()
   prev.Sequence.ID         = StringConcatenate(Sequence.ID, "");    // string inputs are references to internal C literals and must be copied to break the reference
   prev.ZigZag.Periods      = ZigZag.Periods;
   prev.Lots                = Lots;
   prev.Slippage            = Slippage;
   prev.ShowProfitInPercent = ShowProfitInPercent;

   // backup runtime variables affected by changing input parameters
   prev.sequence.id      = sequence.id;
   prev.sequence.created = sequence.created;
   prev.sequence.name    = sequence.name;
   prev.sequence.status  = sequence.status;
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // restore input parameters
   Sequence.ID         = prev.Sequence.ID;
   ZigZag.Periods      = prev.ZigZag.Periods;
   Lots                = prev.Lots;
   Slippage            = prev.Slippage;
   ShowProfitInPercent = prev.ShowProfitInPercent;

   // restore runtime variables
   sequence.id      = prev.sequence.id;
   sequence.created = prev.sequence.created;
   sequence.name    = prev.sequence.name;
   sequence.status  = prev.sequence.status;
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
   bool isParameterChange  = (ProgramInitReason()==IR_PARAMETERS);   // whether we validate manual or programmatic inputs
   bool sequenceWasStarted = (open.ticket || ArrayRange(closed.history, 0));

   // Sequence.ID
   if (isParameterChange) {
      string sValue = StrTrim(Sequence.ID);
      if (sValue == "") {                                            // the id was deleted or not yet set, re-apply the internal id
         Sequence.ID = prev.Sequence.ID;
      }
      else if (sValue != prev.Sequence.ID)                           return(!onInputError("ValidateInputs(1)  "+ sequence.name +" switching to another sequence is not supported (unload the EA first)"));
   } //else                                                          // onInitUser(): the id is empty (a new sequence) or validated (an existing sequence is reloaded)

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

   return(!catch("ValidateInputs(7)"));
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

   string text = StringConcatenate(ProgramName(), "    ", sStatus, sError,                NL,
                                                                                          NL,
                                  "Profit:   ", sSequenceTotalPL, "  ", sSequencePlStats, NL
   );

   // 3 lines margin-top for instrument and indicator legends
   Comment(NL, NL, NL, text);
   if (__CoreFunction == CF_INIT) WindowRedraw();

   error = intOr(catch("ShowStatus(2)"), error);
   isRecursion = false;
   return(error);
}
