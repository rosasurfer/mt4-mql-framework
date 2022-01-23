/**
 * ZigZag EA
 *
 *
 * TODO:
 *  - add sequence initialization
 *  - store closed positions in history
 *  - every instance needs to track its PL curve
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

extern string Sequence.ID                    = "";       // instance to load from a status file (id between 1000-9999)

extern string ___a__________________________ = "=== Signal settings ========================";
extern int    ZigZag.Periods                 = 40;

extern string ___b__________________________ = "=== Trade settings ========================";
extern double Lots                           = 0.1;
extern int    Slippage                       = 2;        // in point

extern string ___c__________________________ = "=== Status display =================";
extern bool   ShowProfitInPercent            = true;     // whether PL is displayed as absolute or percentage value

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
int      sequence.status;
string   sequence.name = "";                 // "ZigZag.{sequence-id}"
double   sequence.startEquity;               //
double   sequence.openPL;                    // PL of all open positions (incl. commissions and swaps)
double   sequence.closedPL;                  // PL of all closed positions (incl. commissions and swaps)
double   sequence.totalPL;                   // total PL of the sequence: openPL + closedPL
double   sequence.maxProfit;                 // max. observed total profit:   0...+n
double   sequence.maxDrawdown;               // max. observed total drawdown: -n...0

// order data
int      openTicket;                         // one open position
int      openType;                           //
datetime openTime;                           //
double   openPrice;                          //
double   openSwap;                           //
double   openCommission;                     //
double   openProfit;                         //
double   history[][23];                      // multiple closed positions

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
   int signal;

   if (sequence.status == STATUS_WAITING) {
      if (IsZigZagSignal(signal))         StartSequence(signal);
   }
   else if (sequence.status == STATUS_PROGRESSING) {
      if (UpdateStatus()) {                                          // update order status and PL
         if      (IsStopSignal())         StopSequence();
         else if (IsZigZagSignal(signal)) ReverseSequence();
      }
   }
   return(catch("onTick(1)"));
}


/**
 * Whether a ZigZag reversal occurred for a waiting sequence.
 *
 * @param  _Out_ int &signal - variable receiving the identifier of the occurred reversal
 *
 * @return bool
 */
bool IsZigZagSignal(int &signal) {
   signal = NULL;
   if (last_error || sequence.status!=STATUS_WAITING) return(false);

   int trend, reversal;
   if (!GetZigZagData(0, trend, reversal)) return(false);

   if (Abs(trend) == reversal) {
      signal = ifInt(trend > 0, SIGNAL_LONG, SIGNAL_SHORT);
      return(true);
   }
   return(false);
}


/**
 * Get the data of the last ZigZag semaphore preceding the specified bar.
 *
 * @param  _In_  int startbar       - startbar to look for the next semaphore
 * @param  _Out_ int &combinedTrend - combined trend value at the startbar offset
 * @param  _Out_ int &reversal      - reversal bar value at the startbar offset
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
   sequence.status = STATUS_PROGRESSING;

   // open new position
   int      type        = ifInt(direction==D_LONG, OP_BUY, OP_SELL);
   double   price       = NULL;
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ sequence.id;
   int      magicNumber = CreateMagicNumber();
   color    markerColor = ifInt(direction==D_LONG, CLR_OPEN_LONG, CLR_OPEN_SHORT);
   int      oeFlags     = NULL, oe[];

   int ticket = OrderSendEx(Symbol(), type, Lots, price, Slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (!ticket) return(!SetLastError(oe.Error(oe)));

   // store position data
   openTicket     = ticket;
   openType       = oe.Type      (oe);
   openTime       = oe.OpenTime  (oe);
   openPrice      = oe.OpenPrice (oe);
   openSwap       = oe.Swap      (oe);
   openCommission = oe.Commission(oe);
   openProfit     = oe.Profit    (oe);

   if (IsLogInfo()) logInfo("StartSequence(4)  "+ sequence.name +" sequence started");
   return(SaveStatus());
}


/**
 * Reverse a progressing sequence.
 *
 * @return bool - success status
 */
bool ReverseSequence() {
   if (last_error != NULL)                    return(false);
   if (sequence.status != STATUS_PROGRESSING) return(!catch("ReverseSequence(1)  "+ sequence.name +" cannot reverse "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));

   // close open position
   int lastDirection = ifInt(openType==OP_BUY, D_LONG, D_SHORT);
   int oe[], oeFlags;
   if (!OrderCloseEx(openTicket, NULL, Slippage, CLR_NONE, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));

   openTicket     = NULL;
   openType       = NULL;
   openTime       = NULL;
   openPrice      = NULL;
   openSwap       = NULL;
   openCommission = NULL;
   openProfit     = NULL;                          // TODO: add closed position to history

   sequence.openPL   = 0;                          // update total PL numbers
   sequence.closedPL = NormalizeDouble(sequence.closedPL + oe.Swap(oe) + oe.Commission(oe) + oe.Profit(oe), 2);
   sequence.totalPL  = sequence.closedPL;

   // open new position
   int      type        = ifInt(lastDirection==D_LONG, OP_SELL, OP_BUY);
   double   price       = NULL;
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   datetime expires     = NULL;
   string   comment     = "ZigZag."+ sequence.id;
   int      magicNumber = CreateMagicNumber();
   color    markerColor = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);

   int ticket = OrderSendEx(Symbol(), type, Lots, price, Slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (!ticket) return(!SetLastError(oe.Error(oe)));

   openTicket     = ticket;
   openType       = oe.Type      (oe);
   openTime       = oe.OpenTime  (oe);
   openPrice      = oe.OpenPrice (oe);
   openSwap       = oe.Swap      (oe);
   openCommission = oe.Commission(oe);
   openProfit     = oe.Profit    (oe);

   sequence.openPL      = NormalizeDouble(openSwap + openCommission + openProfit, 2);
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
      if (!OrderCloseEx(openTicket, NULL, Slippage, CLR_NONE, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));

      openTicket     = NULL;
      openType       = NULL;
      openTime       = NULL;
      openPrice      = NULL;
      openSwap       = NULL;
      openCommission = NULL;
      openProfit     = NULL;                       // TODO: add closed position to history

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
   if (last_error != NULL)                           return(false);
   if (sequence.status != STATUS_PROGRESSING)        return(!catch("UpdateStatus(1)  "+ sequence.name +" cannot update order status of "+ StatusDescription(sequence.status) +" sequence", ERR_ILLEGAL_STATE));
   if (!SelectTicket(openTicket, "UpdateStatus(2)")) return(false);

   openSwap       = OrderSwap();
   openCommission = OrderCommission();
   openProfit     = OrderProfit();

   sequence.openPL  = NormalizeDouble(openSwap + openCommission + openProfit, 2);
   sequence.totalPL = NormalizeDouble(sequence.openPL + sequence.closedPL, 2); SS.TotalPL();

   if      (sequence.totalPL > sequence.maxProfit  ) { sequence.maxProfit   = sequence.totalPL; SS.MaxProfit();   }
   else if (sequence.totalPL < sequence.maxDrawdown) { sequence.maxDrawdown = sequence.totalPL; SS.MaxDrawdown(); }

   return(!catch("UpdateStatus(3)"));
}


/**
 * Generate a unique magic order number for the sequence.
 *
 * @return int - magic number or NULL in case of errors
 */
int CreateMagicNumber() {
   if (STRATEGY_ID <  101 || STRATEGY_ID > 1023) return(!catch("CreateMagicNumber(1)  "+ sequence.name +" illegal strategy id: "+ STRATEGY_ID, ERR_ILLEGAL_STATE));
   if (sequence.id < 1000 || sequence.id > 9999) return(!catch("CreateMagicNumber(2)  "+ sequence.name +" illegal sequence.id: "+ sequence.id, ERR_ILLEGAL_STATE));

   int strategy = STRATEGY_ID;                              //  101-1023 (10 bit)
   int sequence = sequence.id;                              // 1000-9999 (14 bit)

   return((strategy<<22) + (sequence<<8));
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
      case NULL:               sStatus = "not initialized";                               break;
      case STATUS_WAITING:     sStatus = StringConcatenate(sequence.id, "  waiting");     break;
      case STATUS_PROGRESSING: sStatus = StringConcatenate(sequence.id, "  progressing"); break;
      case STATUS_STOPPED:     sStatus = StringConcatenate(sequence.id, "  stopped");     break;
      default:
         return(catch("ShowStatus(1)  "+ sequence.name +" illegal sequence status: "+ sequence.status, ERR_ILLEGAL_STATE));
   }
   if (__STATUS_OFF) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason), "]");

   string text = StringConcatenate(ProgramName(), "    ", sStatus, sError,                  NL,
                                                                                            NL,
                                  "Profit:    ",  sSequenceTotalPL, "  ", sSequencePlStats, NL
   );

   // 3 lines margin-top for instrument and indicator legends
   Comment(NL, NL, NL, text);
   if (__CoreFunction == CF_INIT) WindowRedraw();

   error = intOr(catch("ShowStatus(2)"), error);
   isRecursion = false;
   return(error);
}


/**
 * ShowStatus: Update the string representation of "sequence.totalPL".
 */
void SS.TotalPL() {
   if (!__isChart) return;

   // not before a position was opened
   if (!openTicket && !ArrayRange(history, 0)) sSequenceTotalPL = "-";
   else if (ShowProfitInPercent)               sSequenceTotalPL = NumberToStr(MathDiv(sequence.totalPL, sequence.startEquity) * 100, "+.2") +"%";
   else                                        sSequenceTotalPL = NumberToStr(sequence.totalPL, "+.2");
}


/**
 * ShowStatus: Update the string representation of "sequence.maxDrawdown".
 */
void SS.MaxDrawdown() {
   if (!__isChart) return;

   if (ShowProfitInPercent) sSequenceMaxDrawdown = NumberToStr(MathDiv(sequence.maxDrawdown, sequence.startEquity) * 100, "+.2") +"%";
   else                     sSequenceMaxDrawdown = NumberToStr(sequence.maxDrawdown, "+.2");
   SS.PLStats();
}


/**
 * ShowStatus: Update the string representation of "sequence.maxProfit".
 */
void SS.MaxProfit() {
   if (!__isChart) return;

   if (ShowProfitInPercent) sSequenceMaxProfit = NumberToStr(MathDiv(sequence.maxProfit, sequence.startEquity) * 100, "+.2") +"%";
   else                     sSequenceMaxProfit = NumberToStr(sequence.maxProfit, "+.2");
   SS.PLStats();
}


/**
 * ShowStatus: Update the string representaton of the PL statistics.
 */
void SS.PLStats() {
   if (!__isChart) return;

   // not before a position was opened
   if (!openTicket && !ArrayRange(history, 0)) {
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
