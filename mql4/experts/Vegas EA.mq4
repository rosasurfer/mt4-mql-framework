/**
 * WORK-IN-PROGRESS, DO NOT YET USE
 *
 * Vegas EA
 *
 * A mixture of ideas from the "Vegas H1 Tunnel" system, the "Turtle Trading" system and a grid for scaling in and out.
 *
 *
 * Features:
 * ---------
 * • A finished test can be loaded into an online chart for trade inspection and further analysis.
 *
 * • The EA supports a "virtual trading mode" in which all trades are only emulated. This makes it possible to hide all
 *   trade related deviations that impact test results or real trading (tester bugs, spread, slippage, swap, commission).
 *   It allows the EA to be tested and calibrated under idealised conditions.
 *
 * • The EA contains a recorder that can record several performance graphs simultaneously at runtime (also in the tester).
 *   These recordings are saved as regular chart symbols in the history directory of a second MT4 terminal. They can be
 *   displayed and analysed like regular MetaTrader charts.
 *
 *
 * Input parameters:
 * -----------------
 * • Instance.ID:  ...
 * • Donchian.Periods:  ...
 * • Lots:  ...
 *
 *
 *  @see  [Vegas H1 Tunnel Method] https://www.forexfactory.com/thread/4365-all-vegas-documents-located-here
 *  @see  [Turtle Trading]         https://analyzingalpha.com/turtle-trading
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 0;

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID      = "";               // instance to load from a status file, format "[T]123"
extern int    Donchian.Periods = 30;
extern double Lots             = 0.1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/IsBarOpen.mqh>
#include <functions/iCustom/MaTunnel.mqh>
#include <functions/iCustom/ZigZag.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define STRATEGY_ID         108                    // unique strategy id (used for magic order numbers)
#define IID_MIN             100                    // min/max range of valid instance id values
#define IID_MAX             999

#define STATUS_WAITING        1                    // instance has no open positions and waits for trade signals
#define STATUS_PROGRESSING    2                    // instance manages open positions
#define STATUS_STOPPED        3                    // instance has no open positions and doesn't wait for trade signals

#define SIGNAL_LONG  TRADE_DIRECTION_LONG          // 1 signal types
#define SIGNAL_SHORT TRADE_DIRECTION_SHORT         // 2

#define H_TICKET              0                    // trade history indexes
#define H_LOTS                1
#define H_OPENTYPE            2
#define H_OPENTIME            3
#define H_OPENPRICE           4
#define H_CLOSETIME           5
#define H_CLOSEPRICE          6
#define H_SLIPPAGE            7
#define H_SWAP                8
#define H_COMMISSION          9
#define H_GROSSPROFIT        10
#define H_NETPROFIT          11

// instance data
int      instance.id;                              // instance id (100-999, used for magic order numbers)
datetime instance.created;
string   instance.name = "";
int      instance.status;
bool     instance.isTest;

double   instance.openNetProfit;
double   instance.closedNetProfit;
double   instance.totalNetProfit;
double   instance.maxNetProfit;                    // max. observed total net profit:   0...+n
double   instance.maxNetDrawdown;                  // max. observed total net drawdown: -n...0

// order data
int      open.ticket;                              // one open position
int      open.type;
datetime open.time;
double   open.price;
double   open.slippage;
double   open.swap;
double   open.commission;
double   open.grossProfit;
double   open.netProfit;
double   history[][12];                            // multiple closed positions

// caching vars to speed-up ShowStatus()
string   sLots               = "";
string   sInstanceTotalNetPL = "";
string   sInstancePlStats    = "";

// debug settings                                  // configurable via framework config, see afterInit()
bool     test.onStopPause        = false;          // whether to pause a test after StopInstance()
bool     test.reduceStatusWrites = true;           // whether to reduce status file writes in tester

#include <apps/vegas-ea/init.mqh>
#include <apps/vegas-ea/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!instance.status) return(ERR_ILLEGAL_STATE);

   if (__isChart) HandleCommands();                // process incoming commands

   if (instance.status != STATUS_STOPPED) {
      int signal;
      IsTradeSignal(signal);
      UpdateStatus(signal);
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

   if (cmd == "restart") {
      switch (instance.status) {
         case STATUS_STOPPED:
            logInfo("onCommand(1)  "+ instance.name +" "+ DoubleQuoteStr(fullCmd));
            return(RestartInstance());
      }
   }
   else if (cmd == "stop") {
      switch (instance.status) {
         case STATUS_WAITING:
         case STATUS_PROGRESSING:
            logInfo("onCommand(2)  "+ instance.name +" "+ DoubleQuoteStr(fullCmd));
            return(StopInstance());
      }
   }
   else return(!logNotice("onCommand(3)  "+ instance.name +" unsupported command: "+ DoubleQuoteStr(fullCmd)));

   return(!logWarn("onCommand(4)  "+ instance.name +" cannot execute command "+ DoubleQuoteStr(fullCmd) +" in status "+ StatusToStr(instance.status)));
}


/**
 * Whether a trade signal occurred.
 *
 * @param  _Out_ int &signal - variable receiving the signal identifier of a satisfied condition
 *
 * @return bool
 */
bool IsTradeSignal(int &signal) {
   signal = NULL;
   if (last_error != NULL) return(false);

   // MA Tunnel signal ------------------------------------------------------------------------------------------------------
   if (IsMaTunnelSignal(signal)) {
      logInfo("IsTradeSignal(1)  "+ instance.name +" MA tunnel "+ ifString(signal==SIGNAL_LONG, "long", "short") +" crossing (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
      return(true);
   }

   // Donchian signal -------------------------------------------------------------------------------------------------------
   //if (IsDonchianSignal(signal)) {
   //   logInfo("IsTradeSignal(2)  "+ instance.name +" Donchian channel "+ ifString(signal==SIGNAL_LONG, "long", "short") +" crossing (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
   //   return(true);
   //}
   return(false);
}


/**
 * Whether a new MA tunnel crossing occurred.
 *
 * @param  _Out_ int &signal - variable receiving the signal identifier: SIGNAL_LONG | SIGNAL_SHORT
 *
 * @return bool
 */
bool IsMaTunnelSignal(int &signal) {
   if (last_error != NULL) return(false);
   signal = NULL;

   if (IsBarOpen()) {
      string tunnelDefinition = "EMA(9), EMA(36), EMA(144)";
      int trend = icMaTunnel(NULL, tunnelDefinition, MaTunnel.MODE_BAR_TREND, 1);

      if      (trend == +1) signal = SIGNAL_LONG;
      else if (trend == -1) signal = SIGNAL_SHORT;
   }
   return(signal != NULL);
}


/**
 * Whether a new Donchian channel reversal occurred.
 *
 * @param  _Out_ int &signal - variable receiving the signal identifier: SIGNAL_LONG | SIGNAL_SHORT
 *
 * @return bool
 */
bool IsDonchianSignal(int &signal) {
   if (last_error != NULL) return(false);
   signal = NULL;

   static int lastTick, lastResult, lastSignal;
   int trend, reversal;

   if (Ticks == lastTick) {
      signal = lastResult;
   }
   else {
      if (!GetZigZagTrendData(0, trend, reversal)) return(false);

      if (Abs(trend)==reversal || !reversal) {     // reversal=0 denotes a double crossing, trend is +1 or -1
         if (trend > 0) {
            if (lastSignal != SIGNAL_LONG)  signal = SIGNAL_LONG;
         }
         else {
            if (lastSignal != SIGNAL_SHORT) signal = SIGNAL_SHORT;
         }
         if (signal != NULL) {
            if (instance.status == STATUS_PROGRESSING) {
               if (IsLogInfo()) logInfo("IsDonchianSignal(1)  "+ instance.name +" "+ ifString(signal==SIGNAL_LONG, "long", "short") +" crossing (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            }
            lastSignal = signal;
         }
      }
      lastTick   = Ticks;
      lastResult = signal;
   }
   return(signal != NULL);
}


/**
 * Get ZigZag trend data at the specified bar offset.
 *
 * @param  _In_  int bar            - bar offset
 * @param  _Out_ int &combinedTrend - combined trend value (MODE_KNOWN_TREND + MODE_UNKNOWN_TREND buffers)
 * @param  _Out_ int &reversal      - bar offset of current ZigZag reversal to the previous ZigZag semaphore
 *
 * @return bool - success status
 */
bool GetZigZagTrendData(int bar, int &combinedTrend, int &reversal) {
   combinedTrend = MathRound(icZigZag(NULL, Donchian.Periods, ZigZag.MODE_TREND,    bar));
   reversal      = MathRound(icZigZag(NULL, Donchian.Periods, ZigZag.MODE_REVERSAL, bar));
   return(combinedTrend != 0);
}


/**
 * Update order status and PL stats.
 *
 * @param  int signal [optional] - trade signal causing the call (default: stats update only)
 *
 * @return bool - success status
 */
bool UpdateStatus(int signal = NULL) {
   if (last_error != NULL)                                                     return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_PROGRESSING) return(!catch("UpdateStatus(1)  "+ instance.name +" illegal instance status "+ StatusToStr(instance.status), ERR_ILLEGAL_STATE));
   int error;

   if (!signal) {
      if (open.ticket != NULL) {
         if (!SelectTicket(open.ticket, "UpdateStatus(2)")) return(false);
         if (OrderCloseTime() > 0) {
            if (IsError(onPositionClose("UpdateStatus(3)  "+ instance.name +" "+ UpdateStatus.PositionCloseMsg(error), error))) return(false);
            if (!ArchiveClosedPosition(open.ticket, NULL)) return(false);
         }
         else {
            open.swap        = OrderSwap();
            open.commission  = OrderCommission();
            open.grossProfit = OrderProfit();
            open.netProfit   = open.grossProfit + open.swap + open.commission;
         }
      }
   }
   else {
      if (signal!=SIGNAL_LONG && signal!=SIGNAL_SHORT) return(!catch("UpdateStatus(4)  "+ instance.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER));
      instance.status = STATUS_PROGRESSING;

      // close an existing open position
      if (open.ticket != NULL) {
         if (open.type != ifInt(signal==SIGNAL_SHORT, OP_LONG, OP_SHORT)) return(!catch("UpdateStatus(5)  "+ instance.name +" cannot process "+ SignalToStr(signal) +" with open "+ OperationTypeToStr(open.type) +" position", ERR_ILLEGAL_STATE));

         int oeFlags = NULL, oe[];
         bool success = OrderCloseEx(open.ticket, NULL, NULL, CLR_CLOSED, oeFlags, oe);
         if (!success) return(!SetLastError(oe.Error(oe)));
         if (!ArchiveClosedPosition(open.ticket, -oe.Slippage(oe))) return(false);
      }

      // open a new position
      int      type        = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL);
      double   price       = NULL;
      int      slippage    = NULL;
      double   stopLoss    = NULL;
      double   takeProfit  = NULL;
      string   comment     = "Vegas."+ instance.id;
      int      magicNumber = CalculateMagicNumber();
      datetime expires     = NULL;
      color    markerColor = ifInt(signal==SIGNAL_LONG, CLR_OPEN_LONG, CLR_OPEN_SHORT);
               oeFlags     = NULL;

      int ticket = OrderSendEx(Symbol(), type, Lots, price, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
      if (!ticket) return(!SetLastError(oe.Error(oe)));

      // store the new position
      open.ticket      = ticket;
      open.type        = type;
      open.time        = oe.OpenTime  (oe);
      open.price       = oe.OpenPrice (oe);
      open.slippage    = -oe.Slippage (oe);
      open.swap        = oe.Swap      (oe);
      open.commission  = oe.Commission(oe);
      open.grossProfit = oe.Profit    (oe);
      open.netProfit   = open.grossProfit + open.swap + open.commission;
   }

   // update PL numbers
   instance.totalNetProfit = open.netProfit + instance.closedNetProfit;
   if      (instance.totalNetProfit > instance.maxNetProfit  ) { instance.maxNetProfit   = instance.totalNetProfit; SS.PLStats(); }
   else if (instance.totalNetProfit < instance.maxNetDrawdown) { instance.maxNetDrawdown = instance.totalNetProfit; SS.PLStats(); }
   SS.TotalPL();

   if (signal != NULL)
      return(SaveStatus());
   return(!catch("UpdateStatus(6)"));
}


/**
 * Compose a log message for a closed position. The ticket is selected.
 *
 * @param  _Out_ int error - error code to be returned from the call (if any)
 *
 * @return string - log message or an empty string in case of errors
 */
string UpdateStatus.PositionCloseMsg(int &error) {
   // #1 Sell 0.1 GBPUSD at 1.5457'2 ("V.869") was [unexpectedly ]closed [by SL ]at 1.5457'2 (market: Bid/Ask[, so: 47.7%/169.20/354.40])
   error = NO_ERROR;

   int    ticket      = OrderTicket();
   double lots        = OrderLots();
   string sType       = OperationTypeDescription(OrderType());
   string sOpenPrice  = NumberToStr(OrderOpenPrice(), PriceFormat);
   string sClosePrice = NumberToStr(OrderClosePrice(), PriceFormat);
   string sUnexpected = ifString(__isTesting && __CoreFunction==CF_DEINIT, "", "unexpectedly ");
   string message     = "#"+ ticket +" "+ sType +" "+ NumberToStr(lots, ".+") +" "+ OrderSymbol() +" at "+ sOpenPrice +" (\""+ instance.name +"\") was "+ sUnexpected +"closed at "+ sClosePrice;

   string sStopout = "";
   if (StrStartsWithI(OrderComment(), "so:")) {       error = ERR_MARGIN_STOPOUT; sStopout = ", "+ OrderComment(); }
   else if (__isTesting && __CoreFunction==CF_DEINIT) error = NO_ERROR;
   else                                               error = ERR_CONCURRENT_MODIFICATION;

   return(message +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) + sStopout +")");
}


/**
 * Event handler for an unexpectedly closed position.
 *
 * @param  string message - error message
 * @param  int    error   - error code
 *
 * @return int - error status, i.e. whether to interrupt program execution
 */
int onPositionClose(string message, int error) {
   if (!error) return(logInfo(message));                    // no error

   if (error == ERR_ORDER_CHANGED)                          // expected in a fast market: a SL was triggered
      return(!logNotice(message, error));                   // continue

   if (__isTesting) return(catch(message, error));          // in tester treat everything else as terminating

   logWarn(message, error);                                 // online
   if (error == ERR_CONCURRENT_MODIFICATION)                // unexpected: most probably manually closed
      return(NO_ERROR);                                     // continue
   return(error);
}


/**
 * Add trade details of the specified closed ticket to the local history and reset open position data.
 *
 * @param int    ticket   - closed ticket
 * @param double slippage - close slippage in pip
 *
 * @return bool - success status
 */
bool ArchiveClosedPosition(int ticket, double slippage) {
   if (last_error != NULL)                    return(false);
   if (instance.status != STATUS_PROGRESSING) return(!catch("ArchiveClosedPosition(1)  "+ instance.name +" cannot archive position of "+ StatusDescription(instance.status) +" sequence", ERR_ILLEGAL_STATE));

   SelectTicket(ticket, "ArchiveClosedPosition(2)", /*push=*/true);

   // update now closed position data
   open.swap        = OrderSwap();
   open.commission  = OrderCommission();
   open.grossProfit = OrderProfit();
   open.netProfit   = open.grossProfit + open.swap + open.commission;

   // update history
   int i = ArrayRange(history, 0);
   ArrayResize(history, i+1);
   history[i][H_TICKET     ] = ticket;
   history[i][H_LOTS       ] = OrderLots();
   history[i][H_OPENTYPE   ] = OrderType();
   history[i][H_OPENTIME   ] = OrderOpenTime();
   history[i][H_OPENPRICE  ] = OrderOpenPrice();
   history[i][H_CLOSETIME  ] = OrderCloseTime();
   history[i][H_CLOSEPRICE ] = OrderClosePrice();
   history[i][H_SLIPPAGE   ] = open.slippage + slippage;
   history[i][H_SWAP       ] = open.swap;
   history[i][H_COMMISSION ] = open.commission;
   history[i][H_GROSSPROFIT] = open.grossProfit;
   history[i][H_NETPROFIT  ] = open.netProfit;
   OrderPop("ArchiveClosedPosition(3)");

   // update PL numbers
   instance.openNetProfit    = 0;
   instance.closedNetProfit += open.netProfit;
   instance.totalNetProfit   = instance.closedNetProfit;

   // reset open position data
   open.ticket      = NULL;
   open.type        = NULL;
   open.time        = NULL;
   open.price       = NULL;
   open.slippage    = NULL;
   open.swap        = NULL;
   open.commission  = NULL;
   open.grossProfit = NULL;
   open.netProfit   = NULL;

   return(!catch("ArchiveClosedPosition(4)"));
}


/**
 * Stop a waiting or progressing instance and close open positions (if any).
 *
 * @return bool - success status
 */
bool StopInstance() {
   if (last_error != NULL)                                                     return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_PROGRESSING) return(!catch("StopInstance(1)  "+ instance.name +" cannot stop "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));

   // close an open position
   if (instance.status == STATUS_PROGRESSING) {
      if (open.ticket > 0) {
         if (IsLogInfo()) logInfo("StopInstance(2)  "+ instance.name +" stopping");
         int oeFlags, oe[];
         if (!OrderCloseEx(open.ticket, NULL, NULL, CLR_CLOSED, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));
         if (!ArchiveClosedPosition(open.ticket, -oe.Slippage(oe)))           return(false);

         instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
         instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);
         SS.TotalPL();
         SS.PLStats();
      }
   }

   // update status
   instance.status = STATUS_STOPPED;
   if (IsLogInfo()) logInfo("StopInstance(3)  "+ instance.name +" "+ ifString(__isTesting, "test ", "") +"instance stopped, profit: "+ sInstanceTotalNetPL +" "+ sInstancePlStats);
   SaveStatus();

   // pause/stop the tester according to the debug configuration
   if (__isTesting) {
      if      (!IsVisualMode())  Tester.Stop ("StopInstance(4)");
      else if (test.onStopPause) Tester.Pause("StopInstance(5)");
   }
   return(!catch("StopInstance(6)"));
}


/**
 * Restart a stopped instance.
 *
 * @return bool - success status
 */
bool RestartInstance() {
   if (last_error != NULL)                return(false);
   if (instance.status != STATUS_STOPPED) return(!catch("RestartInstance(1)  "+ instance.name +" cannot restart "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   return(!catch("RestartInstance(2)", ERR_NOT_IMPLEMENTED));
}


/**
 * Whether the current instance was created in the tester. Considers that a finished test may have been loaded into an online
 * chart for visualization and further analysis.
 *
 * @return bool
 */
bool IsTestInstance() {
   return(instance.isTest || __isTesting);
}


/**
 * Calculate a magic order number for the strategy.
 *
 * @param  int instanceId [optional] - intance to calculate the magic number for (default: the current instance)
 *
 * @return int - magic number or NULL in case of errors
 */
int CalculateMagicNumber(int instanceId = NULL) {
   if (STRATEGY_ID < 101 || STRATEGY_ID > 1023) return(!catch("CalculateMagicNumber(1)  "+ instance.name +" illegal strategy id: "+ STRATEGY_ID, ERR_ILLEGAL_STATE));
   int id = intOr(instanceId, instance.id);
   if (id < IID_MIN || id > IID_MAX)            return(!catch("CalculateMagicNumber(2)  "+ instance.name +" illegal instance id: "+ id, ERR_ILLEGAL_STATE));

   int strategy = STRATEGY_ID;                              // 101-1023 (10 bit)
   int instance = id;                                       // 100-999  (14 bit, used to be 1000-9999)

   return((strategy<<22) + (instance<<8));                  // the remaining 8 bit are currently not used in this strategy
}


/**
 * Whether the currently selected ticket belongs to the current strategy and optionally instance.
 *
 * @param  int instanceId [optional] - instance to check the ticket against (default: check for matching strategy only)
 *
 * @return bool
 */
bool IsMyOrder(int instanceId = NULL) {
   if (OrderSymbol() == Symbol()) {
      int strategy = OrderMagicNumber() >> 22;
      if (strategy == STRATEGY_ID) {
         int instance = OrderMagicNumber() >> 8 & 0x3FFF;   // 14 bit starting at bit 8: instance id
         return(!instanceId || instanceId==instance);
      }
   }
   return(false);
}


/**
 * Generate a new instance id. Must be unique for all instances of this strategy.
 *
 * @return int - instances id in the range of 100-999 or NULL in case of errors
 */
int CreateInstanceId() {
   MathSrand(GetTickCount()-__ExecutionContext[EC.hChartWindow]);
   int instanceId, magicNumber;

   while (!magicNumber) {
      while (instanceId < IID_MIN || instanceId > IID_MAX) {
         instanceId = MathRand();                           // TODO: generate consecutive ids when in tester
      }
      magicNumber = CalculateMagicNumber(instanceId); if (!magicNumber) return(NULL);

      // test for uniqueness against open orders
      int openOrders = OrdersTotal();
      for (int i=0; i < openOrders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) return(!catch("CreateInstanceId(1)  "+ instance.name, intOr(GetLastError(), ERR_RUNTIME_ERROR)));
         if (OrderMagicNumber() == magicNumber) {
            magicNumber = NULL;
            break;
         }
      }
      if (!magicNumber) continue;

      // test for uniqueness against closed orders
      int closedOrders = OrdersHistoryTotal();
      for (i=0; i < closedOrders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) return(!catch("CreateInstanceIdId(2)  "+ instance.name, intOr(GetLastError(), ERR_RUNTIME_ERROR)));
         if (OrderMagicNumber() == magicNumber) {
            magicNumber = NULL;
            break;
         }
      }
   }
   return(instanceId);
}


/**
 * Parse and set the passed instance id value. Format: "[T]123"
 *
 * @param  _In_    string value  - instance id value
 * @param  _InOut_ bool   error  - in:  mute parse errors (TRUE) or trigger a fatal error (FALSE)
 *                                 out: whether parse errors occurred (stored in last_error)
 * @param  _In_    string caller - caller identification for error messages
 *
 * @return bool - whether the instance id value was successfully set
 */
bool SetInstanceId(string value, bool &error, string caller) {
   string valueBak = value;
   bool muteErrors = error!=0;
   error = false;

   value = StrTrim(value);
   if (!StringLen(value)) return(false);

   bool isTest = false;
   int instanceId = 0;

   if (StrStartsWith(value, "T")) {
      isTest = true;
      value = StringTrimLeft(StrSubstr(value, 1));
   }

   if (!StrIsDigits(value)) {
      error = true;
      if (muteErrors) return(!SetLastError(ERR_INVALID_PARAMETER));
      return(!catch(caller +"->SetInstanceId(1)  invalid instance id value: \""+ valueBak +"\" (must be digits only)", ERR_INVALID_PARAMETER));
   }

   int iValue = StrToInteger(value);
   if (iValue < IID_MIN || iValue > IID_MAX) {
      error = true;
      if (muteErrors) return(!SetLastError(ERR_INVALID_PARAMETER));
      return(!catch(caller +"->SetInstanceId(2)  invalid instance id value: \""+ valueBak +"\" (range error)", ERR_INVALID_PARAMETER));
   }

   instance.isTest = isTest;
   instance.id     = iValue;
   Instance.ID     = ifString(IsTestInstance(), "T", "") + instance.id;
   SS.InstanceName();
   return(true);
}


/**
 * Restore the internal state of the EA from a status file. Requires 'instance.id' and 'instance.isTest' to be set.
 *
 * @return bool - success status
 */
bool RestoreInstance() {
   if (IsLastError())        return(false);
   if (!ReadStatus())        return(false);              // read and apply the status file
   if (!ValidateInputs())    return(false);              // validate restored input parameters
   if (!SynchronizeStatus()) return(false);              // synchronize restored state with current order state
   return(true);
}


/**
 * Read the status file of an instance and restore inputs and runtime variables. Called only from RestoreSequence().
 *
 * @return bool - success status
 */
bool ReadStatus() {
   if (IsLastError()) return(false);
   if (!instance.id)  return(!catch("ReadStatus(1)  "+ instance.name +" illegal value of instance.id: "+ instance.id, ERR_ILLEGAL_STATE));

   string file = FindStatusFile(instance.id, instance.isTest);
   if (file == "")                 return(!catch("ReadStatus(2)  "+ instance.name +" status file not found", ERR_RUNTIME_ERROR));
   if (!IsFile(file, MODE_SYSTEM)) return(!catch("ReadStatus(3)  "+ instance.name +" file "+ DoubleQuoteStr(file) +" not found", ERR_FILE_NOT_FOUND));

   // [General]
   string section      = "General";
   string sAccount     = GetIniStringA(file, section, "Account", "");                     // string Account = ICMarkets:12345678 (demo)
   string sSymbol      = GetIniStringA(file, section, "Symbol",  "");                     // string Symbol  = EURUSD
   string sThisAccount = GetAccountCompanyId() +":"+ GetAccountNumber();
   if (!StrCompareI(StrLeftTo(sAccount, " ("), sThisAccount)) return(!catch("ReadStatus(4)  "+ instance.name +" account mis-match: "+ DoubleQuoteStr(sThisAccount) +" vs. "+ DoubleQuoteStr(sAccount) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));
   if (!StrCompareI(sSymbol, Symbol()))                       return(!catch("ReadStatus(5)  "+ instance.name +" symbol mis-match: "+ Symbol() +" vs. "+ sSymbol +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));

   // [Inputs]
   section = "Inputs";
   string sInstanceID       = GetIniStringA(file, section, "Instance.ID",  "");           // string Instance.ID      = T123
   int    iDonchianPeriods  = GetIniInt    (file, section, "Donchian.Periods");           // int    Donchian.Periods = 40
   string sLots             = GetIniStringA(file, section, "Lots",         "");           // double Lots             = 0.1

   if (!StrIsNumeric(sLots)) return(!catch("ReadStatus(6)  "+ instance.name +" invalid input parameter Lots "+ DoubleQuoteStr(sLots) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));

   Instance.ID      = sInstanceID;
   Donchian.Periods = iDonchianPeriods;
   Lots             = StrToDouble(sLots);

   // [Runtime status]
   section = "Runtime status";
   instance.id              = GetIniInt    (file, section, "instance.id"      );          // int      instance.id              = 123
   instance.created         = GetIniInt    (file, section, "instance.created" );          // datetime instance.created         = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.isTest          = GetIniBool   (file, section, "instance.isTest"  );          // bool     instance.isTest          = 1
   instance.name            = GetIniStringA(file, section, "instance.name", "");          // string   instance.name            = V.123
   instance.status          = GetIniInt    (file, section, "instance.status"  );          // int      instance.status          = 1

   instance.openNetProfit   = GetIniDouble (file, section, "instance.openNetProfit"  );   // double   instance.openNetProfit   = 23.45
   instance.closedNetProfit = GetIniDouble (file, section, "instance.closedNetProfit");   // double   instance.closedNetProfit = 45.67
   instance.totalNetProfit  = GetIniDouble (file, section, "instance.totalNetProfit" );   // double   instance.totalNetProfit  = 123.45
   instance.maxNetProfit    = GetIniDouble (file, section, "instance.maxNetProfit"   );   // double   instance.maxNetProfit    = 23.45
   instance.maxNetDrawdown  = GetIniDouble (file, section, "instance.maxNetDrawdown" );   // double   instance.maxNetDrawdown  = -11.23
   SS.InstanceName();

   // open order data
   open.ticket              = GetIniInt    (file, section, "open.ticket"     );           // int      open.ticket              = 123456
   open.type                = GetIniInt    (file, section, "open.type"       );           // int      open.type                = 1
   open.time                = GetIniInt    (file, section, "open.time"       );           // datetime open.time                = 1624924800 (Mon, 2021.05.12 13:22:34)
   open.price               = GetIniDouble (file, section, "open.price"      );           // double   open.price               = 1.24363
   open.slippage            = GetIniDouble (file, section, "open.slippage"   );           // double   open.slippage            = 1.0
   open.swap                = GetIniDouble (file, section, "open.swap"       );           // double   open.swap                = -1.23
   open.commission          = GetIniDouble (file, section, "open.commission" );           // double   open.commission          = -5.50
   open.grossProfit         = GetIniDouble (file, section, "open.grossProfit");           // double   open.grossProfit         = 12.34
   open.netProfit           = GetIniDouble (file, section, "open.netProfit"  );           // double   open.netProfit           = 12.56

   // history data
   string sKeys[], sOrder="";
   int size = ReadStatus.HistoryKeys(file, section, sKeys); if (size < 0) return(false);
   for (int i=0; i < size; i++) {
      sOrder = GetIniStringA(file, section, sKeys[i], "");                                // history.{i} = {data}
      if (!ReadStatus.ParseHistory(sKeys[i], sOrder)) return(!catch("ReadStatus(7)  "+ instance.name +" invalid history record in status file "+ DoubleQuoteStr(file) + NL + sKeys[i] +"="+ sOrder, ERR_INVALID_FILE_FORMAT));
   }
   return(!catch("ReadStatus(8)"));
}


/**
 * Read and return the keys of all trade history records found in the status file (sorting order doesn't matter).
 *
 * @param  _In_  string file    - status filename
 * @param  _In_  string section - status section
 * @param  _Out_ string &keys[] - array receiving the found keys
 *
 * @return int - number of found keys or EMPTY (-1) in case of errors
 */
int ReadStatus.HistoryKeys(string file, string section, string &keys[]) {
   int size = GetIniKeys(file, section, keys);
   if (size < 0) return(EMPTY);

   for (int i=size-1; i >= 0; i--) {
      if (StrStartsWithI(keys[i], "history."))
         continue;
      ArraySpliceStrings(keys, i, 1);     // drop all non-order keys
      size--;
   }
   return(size);                          // no need to sort as records are inserted at the correct position
}


/**
 * Parse the string representation of a closed order record and store the parsed data.
 *
 * @param  string key   - order key
 * @param  string value - order string to parse
 *
 * @return bool - success status
 */
bool ReadStatus.ParseHistory(string key, string value) {
   if (IsLastError())                    return(false);
   if (!StrStartsWithI(key, "history.")) return(!catch("ReadStatus.ParseHistory(1)  "+ instance.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT));

   // history.i=ticket,lots,openType,openTime,openPrice,closeTime,closePrice,slippage,swap,commission,grossProfit,netProfit
   string values[];
   string sId = StrRightFrom(key, ".", -1); if (!StrIsDigits(sId))  return(!catch("ReadStatus.ParseHistory(2)  "+ instance.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT));
   if (Explode(value, ",", values, NULL) != ArrayRange(history, 1)) return(!catch("ReadStatus.ParseHistory(3)  "+ instance.name +" illegal number of details ("+ ArraySize(values) +") in history record", ERR_INVALID_FILE_FORMAT));

   int      ticket      = StrToInteger(values[H_TICKET     ]);
   double   lots        =  StrToDouble(values[H_LOTS       ]);
   int      openType    = StrToInteger(values[H_OPENTYPE   ]);
   datetime openTime    = StrToInteger(values[H_OPENTIME   ]);
   double   openPrice   =  StrToDouble(values[H_OPENPRICE  ]);
   datetime closeTime   = StrToInteger(values[H_CLOSETIME  ]);
   double   closePrice  =  StrToDouble(values[H_CLOSEPRICE ]);
   double   slippage    =  StrToDouble(values[H_SLIPPAGE   ]);
   double   swap        =  StrToDouble(values[H_SWAP       ]);
   double   commission  =  StrToDouble(values[H_COMMISSION ]);
   double   grossProfit =  StrToDouble(values[H_GROSSPROFIT]);
   double   netProfit   =  StrToDouble(values[H_NETPROFIT  ]);

   return(!IsEmpty(History.AddRecord(ticket, lots, openType, openTime, openPrice, closeTime, closePrice, slippage, swap, commission, grossProfit, netProfit)));
}


/**
 * Add an order record to the history array. Records are ordered ascending by {OpenTime;Ticket} and the new record is inserted
 * at the correct position. No data is overwritten.
 *
 * @param  int ticket - order record details
 * @param  ...
 *
 * @return int - index the record was inserted at or EMPTY (-1) in case of errors
 */
int History.AddRecord(int ticket, double lots, int openType, datetime openTime, double openPrice, datetime closeTime, double closePrice, double slippage, double swap, double commission, double grossProfit, double netProfit) {
   int size = ArrayRange(history, 0);

   for (int i=0; i < size; i++) {
      if (EQ(ticket,   history[i][H_TICKET  ])) return(_EMPTY(catch("History.AddRecord(1)  "+ instance.name +" cannot add record, ticket #"+ ticket +" already exists (offset: "+ i +")", ERR_INVALID_PARAMETER)));
      if (GT(openTime, history[i][H_OPENTIME])) continue;
      if (LT(openTime, history[i][H_OPENTIME])) break;
      if (LT(ticket,   history[i][H_TICKET  ])) break;
   }

   // 'i' now holds the array index to insert at
   if (i == size) {
      ArrayResize(history, size+1);                                  // add a new empty slot or...
   }
   else {
      int dim2=ArrayRange(history, 1), from=i*dim2, to=from+dim2;    // ...free an existing slot by shifting existing data
      ArrayCopy(history, history, to, from);
   }

   // insert the new data
   history[i][H_TICKET     ] = ticket;
   history[i][H_LOTS       ] = lots;
   history[i][H_OPENTYPE   ] = openType;
   history[i][H_OPENTIME   ] = openTime;
   history[i][H_OPENPRICE  ] = openPrice;
   history[i][H_CLOSETIME  ] = closeTime;
   history[i][H_CLOSEPRICE ] = closePrice;
   history[i][H_SLIPPAGE   ] = slippage;
   history[i][H_SWAP       ] = swap;
   history[i][H_COMMISSION ] = commission;
   history[i][H_GROSSPROFIT] = grossProfit;
   history[i][H_NETPROFIT  ] = netProfit;

   if (!catch("History.AddRecord(2)"))
      return(i);
   return(EMPTY);
}


/**
 * Synchronize restored state and runtime vars with current order status on the trade server.
 * Called only from RestoreSequence().
 *
 * @return bool - success status
 */
bool SynchronizeStatus() {
   if (IsLastError()) return(false);

   // detect & handle dangling open positions
   for (int i=OrdersTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (IsMyOrder(instance.id)) {
         // TODO
      }
   }

   // detect & handle dangling closed positions
   for (i=OrdersHistoryTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if (IsPendingOrderType(OrderType()))              continue;    // skip deleted pending orders (atm not supported)

      if (IsMyOrder(instance.id)) {
         // TODO
      }
   }
   return(!catch("SynchronizeStatus(1)"));
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
 * Return the name of the status file.
 *
 * @param  bool relative [optional] - whether to return an absolute path or a path relative to the MQL "files" directory
 *                                    (default: absolute path)
 *
 * @return string - filename or an empty string in case of errors
 */
string GetStatusFilename(bool relative = false) {
   relative = relative!=0;
   if (!instance.id)      return(_EMPTY_STR(catch("GetStatusFilename(1)  "+ instance.name +" illegal value of instance.id: 0", ERR_ILLEGAL_STATE)));
   if (!instance.created) return(_EMPTY_STR(catch("GetStatusFilename(2)  "+ instance.name +" illegal value of instance.created: 0", ERR_ILLEGAL_STATE)));

   static string filename = ""; if (!StringLen(filename)) {
      string directory = "presets/"+ ifString(IsTestInstance(), "Tester", GetAccountCompanyId()) +"/";
      string baseName  = Symbol() +"."+ GmtTimeFormat(instance.created, "%Y.%m.%d %H.%M") +".Vegas."+ instance.id +".set";
      filename = directory + baseName;
   }

   if (relative)
      return(filename);
   return(GetMqlSandboxPath() +"/"+ filename);
}


/**
 * Find an existing status file for the specified instance.
 *
 * @param  int  instanceId - instance id
 * @param  bool isTest     - whether the instance is a test instance
 *
 * @return string - absolute filename or an empty string in case of errors
 */
string FindStatusFile(int instanceId, bool isTest) {
   if (instanceId < IID_MIN || instanceId > IID_MAX) return(_EMPTY_STR(catch("FindStatusFile(1)  "+ instance.name +" invalid parameter instanceId: "+ instanceId, ERR_INVALID_PARAMETER)));
   isTest = isTest!=0;

   string sandboxDir  = GetMqlSandboxPath() +"/";
   string statusDir   = "presets/"+ ifString(isTest, "Tester", GetAccountCompanyId()) +"/";
   string basePattern = Symbol() +".*.Vegas."+ instanceId +".set";
   string pathPattern = sandboxDir + statusDir + basePattern;

   string result[];
   int size = FindFileNames(pathPattern, result, FF_FILESONLY);

   if (size != 1) {
      if (size > 1) return(_EMPTY_STR(logError("FindStatusFile(2)  "+ instance.name +" multiple matching files found for pattern "+ DoubleQuoteStr(pathPattern), ERR_ILLEGAL_STATE)));
   }
   return(sandboxDir + statusDir + result[0]);
}


/**
 * Write the current instance status to a file.
 *
 * @return bool - success status
 */
bool SaveStatus() {
   if (last_error != NULL)                       return(false);
   if (!instance.id || StrTrim(Instance.ID)=="") return(!catch("SaveStatus(1)  illegal instance id: "+ instance.id +" (Instance.ID="+ DoubleQuoteStr(Instance.ID) +")", ERR_ILLEGAL_STATE));
   if (IsTestInstance() && !__isTesting)         return(true);  // don't change the status file of a finished test

   if (__isTesting && test.reduceStatusWrites) {                // in tester skip most writes except file creation, instance stop and test end
      static bool saved = false;
      if (saved && instance.status!=STATUS_STOPPED && __CoreFunction!=CF_DEINIT) return(true);
      saved = true;
   }

   string section="", separator="", file=GetStatusFilename();
   if (!IsFile(file, MODE_SYSTEM)) separator = CRLF;            // an empty line as additional section separator

   // [General]
   section = "General";
   WriteIniString(file, section, "Account", GetAccountCompanyId() +":"+ GetAccountNumber() +" ("+ ifString(IsDemoFix(), "demo", "real") +")");
   WriteIniString(file, section, "Symbol",  Symbol());
   WriteIniString(file, section, "Created", GmtTimeFormat(instance.created, "%a, %Y.%m.%d %H:%M:%S") + separator);   // conditional section separator

   // [Inputs]
   section = "Inputs";
   WriteIniString(file, section, "Instance.ID",              /*string*/ Instance.ID);
   WriteIniString(file, section, "Donchian.Periods",         /*int   */ Donchian.Periods);
   WriteIniString(file, section, "Lots",                     /*double*/ NumberToStr(Lots, ".+") + separator);        // conditional section separator

   // [Runtime status]
   section = "Runtime status";                               // On deletion of pending orders the number of stored order records decreases. To prevent
   EmptyIniSectionA(file, section);                          // orphaned status file records the section is emptied before writing to it.

   // instance data
   WriteIniString(file, section, "instance.id",              /*int     */ instance.id);
   WriteIniString(file, section, "instance.created",         /*datetime*/ instance.created + GmtTimeFormat(instance.created, " (%a, %Y.%m.%d %H:%M:%S)"));
   WriteIniString(file, section, "instance.isTest",          /*bool    */ instance.isTest);
   WriteIniString(file, section, "instance.name",            /*string  */ instance.name);
   WriteIniString(file, section, "instance.status",          /*int     */ instance.status + CRLF);

   WriteIniString(file, section, "instance.openNetProfit",   /*double  */ DoubleToStr(instance.openNetProfit, 2));
   WriteIniString(file, section, "instance.closedNetProfit", /*double  */ DoubleToStr(instance.closedNetProfit, 2));
   WriteIniString(file, section, "instance.totalNetProfit",  /*double  */ DoubleToStr(instance.totalNetProfit, 2));
   WriteIniString(file, section, "instance.maxNetProfit",    /*double  */ DoubleToStr(instance.maxNetProfit, 2));
   WriteIniString(file, section, "instance.maxNetDrawdown",  /*double  */ DoubleToStr(instance.maxNetDrawdown, 2) + CRLF);

   // open order data
   WriteIniString(file, section, "open.ticket",              /*int     */ open.ticket);
   WriteIniString(file, section, "open.type",                /*int     */ open.type);
   WriteIniString(file, section, "open.time",                /*datetime*/ open.time + ifString(open.time, GmtTimeFormat(open.time, " (%a, %Y.%m.%d %H:%M:%S)"), ""));
   WriteIniString(file, section, "open.price",               /*double  */ DoubleToStr(open.price, Digits));
   WriteIniString(file, section, "open.slippage",            /*double  */ DoubleToStr(open.slippage, 1));
   WriteIniString(file, section, "open.swap",                /*double  */ DoubleToStr(open.swap, 2));
   WriteIniString(file, section, "open.commission",          /*double  */ DoubleToStr(open.commission, 2));
   WriteIniString(file, section, "open.grossProfit",         /*double  */ DoubleToStr(open.grossProfit, 2));
   WriteIniString(file, section, "open.netProfit",           /*double  */ DoubleToStr(open.netProfit, 2) + CRLF);

   // closed order data
   int size = ArrayRange(history, 0);
   for (int i=0; i < size; i++) {
      WriteIniString(file, section, "history."+ i, SaveStatus.HistoryToStr(i) + ifString(i+1 < size, "", CRLF));
   }
   return(!catch("SaveStatus(2)"));
}


/**
 * Return a string representation of a history record to be stored by SaveStatus().
 *
 * @param  int index - index of the history record
 *
 * @return string - string representation or an empty string in case of errors
 */
string SaveStatus.HistoryToStr(int index) {
   // result: ticket,lots,openType,openTime,openPrice,closeTime,closePrice,slippage,swap,commission,grossProfit,netProfit

   int      ticket      = history[index][H_TICKET     ];
   double   lots        = history[index][H_LOTS       ];
   int      openType    = history[index][H_OPENTYPE   ];
   datetime openTime    = history[index][H_OPENTIME   ];
   double   openPrice   = history[index][H_OPENPRICE  ];
   datetime closeTime   = history[index][H_CLOSETIME  ];
   double   closePrice  = history[index][H_CLOSEPRICE ];
   double   slippage    = history[index][H_SLIPPAGE   ];
   double   swap        = history[index][H_SWAP       ];
   double   commission  = history[index][H_COMMISSION ];
   double   grossProfit = history[index][H_GROSSPROFIT];
   double   netProfit   = history[index][H_NETPROFIT  ];

   return(StringConcatenate(ticket, ",", DoubleToStr(lots, 2), ",", openType, ",", openTime, ",", DoubleToStr(openPrice, Digits), ",", closeTime, ",", DoubleToStr(closePrice, Digits), ",", DoubleToStr(slippage, 1), ",", DoubleToStr(swap, 2), ",", DoubleToStr(commission, 2), ",", DoubleToStr(grossProfit, 2), ",", DoubleToStr(netProfit, 2)));
}


// backed-up input parameters
string   prev.Instance.ID = "";
int      prev.Donchian.Periods;
double   prev.Lots;

// backed-up runtime variables affected by changing input parameters
int      prev.instance.id;
datetime prev.instance.created;
bool     prev.instance.isTest;
string   prev.instance.name = "";
int      prev.instance.status;


/**
 * Programatically changed input parameters don't survive init cycles. Therefore inputs are backed-up in deinit() and can be
 * restored in init(). Called in onDeinitParameters() and onDeinitChartChange().
 */
void BackupInputs() {
   // backup input parameters, used for comparison in ValidateInputs()
   prev.Instance.ID      = StringConcatenate(Instance.ID, "");    // string inputs are references to internal C literals and must be copied to break the reference
   prev.Donchian.Periods = Donchian.Periods;
   prev.Lots             = Lots;

   // backup runtime variables affected by changing input parameters
   prev.instance.id      = instance.id;
   prev.instance.created = instance.created;
   prev.instance.isTest  = instance.isTest;
   prev.instance.name    = instance.name;
   prev.instance.status  = instance.status;
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // restore input parameters
   Instance.ID      = prev.Instance.ID;
   Donchian.Periods = prev.Donchian.Periods;
   Lots             = prev.Lots;

   // restore runtime variables
   instance.id      = prev.instance.id;
   instance.created = prev.instance.created;
   instance.isTest  = prev.instance.isTest;
   instance.name    = prev.instance.name;
   instance.status  = prev.instance.status;
}


/**
 * Validate and apply input parameter "Instance.ID".
 *
 * @return bool - whether an instance id value was successfully restored (the status file is not checked)
 */
bool ValidateInputs.IID() {
   bool errorFlag = true;

   if (!SetInstanceId(Instance.ID, errorFlag, "ValidateInputs.IID(1)")) {
      if (errorFlag) onInputError("ValidateInputs.IID(2)  invalid input parameter Instance.ID: \""+ Instance.ID +"\"");
      return(false);
   }
   return(true);
}


/**
 * Validate all input parameters. Parameters may have been entered through the input dialog, read from a status file or
 * deserialized and applied programmatically by the terminal (e.g. at terminal restart). Called from onInitUser(),
 * onInitParameters() or onInitTemplate().
 *
 * @return bool - whether input parameters are valid
 */
bool ValidateInputs() {
   if (IsLastError()) return(false);
   bool isInitParameters = (ProgramInitReason()==IR_PARAMETERS);  // whether we validate manual or programatic input
   bool isInitUser       = (ProgramInitReason()==IR_USER);
   bool isInitTemplate   = (ProgramInitReason()==IR_TEMPLATE);
   bool hasOpenOrders    = false;

   // Instance.ID
   if (isInitParameters) {                                        // otherwise the id was validated in ValidateInputs.IID()
      string sValue = StrTrim(Instance.ID);
      if (sValue == "") {                                         // the id was deleted or not yet set, restore the internal id
         Instance.ID = prev.Instance.ID;
      }
      else if (sValue != prev.Instance.ID) return(!onInputError("ValidateInputs(1)  "+ instance.name +" switching to another instance is not supported (unload the EA first)"));
   }

   // Donchian.Periods
   if (isInitParameters && Donchian.Periods!=prev.Donchian.Periods) {
      if (hasOpenOrders)                   return(!onInputError("ValidateInputs(2)  "+ instance.name +" cannot change input parameter Donchian.Periods with open orders"));
   }
   if (Donchian.Periods < 2)               return(!onInputError("ValidateInputs(3)  "+ instance.name +" invalid input parameter Donchian.Periods: "+ Donchian.Periods +" (must be > 1)"));

   // Lots
   if (LT(Lots, 0))                        return(!onInputError("ValidateInputs(4)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (must be > 0)"));
   if (NE(Lots, NormalizeLots(Lots)))      return(!onInputError("ValidateInputs(5)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (must be a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   SS.All();
   return(!catch("ValidateInputs(6)"));
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
      return(logError(message, error));                           // non-terminating error
   return(catch(message, error));                                 // terminating error
}


/**
 * Store the current instance id in the terminal (for template changes, terminal restart, recompilation etc).
 *
 * @return bool - success status
 */
bool StoreInstanceId() {
   string name = ProgramName() +".Instance.ID";
   string value = ifString(instance.isTest, "T", "") + instance.id;

   Instance.ID = value;                                              // store in input parameter

   if (__isChart) {
      Chart.StoreString(name, value);                                // store in chart
      SetWindowStringA(__ExecutionContext[EC.hChart], name, value);  // store in chart window
   }
   return(!catch("StoreInstanceId(1)"));
}


/**
 * Find and restore a stored instance id (for template changes, terminal restart, recompilation etc).
 *
 * @return bool - whether an instance id was successfully restored
 */
bool RestoreInstanceId() {
   bool isError, muteErrors=false;

   // check input parameter
   string value = Instance.ID;
   if (SetInstanceId(value, muteErrors, "RestoreInstanceId(1)")) return(true);
   isError = muteErrors;
   if (isError) return(false);

   if (__isChart) {
      // check chart window
      string name = ProgramName() +".Instance.ID";
      value = GetWindowStringA(__ExecutionContext[EC.hChart], name);
      muteErrors = false;
      if (SetInstanceId(value, muteErrors, "RestoreInstanceId(2)")) return(true);
      isError = muteErrors;
      if (isError) return(false);

      // check chart
      if (Chart.RestoreString(name, value, false)) {
         muteErrors = false;
         if (SetInstanceId(value, muteErrors, "RestoreInstanceId(3)")) return(true);
      }
   }
   return(false);
}


/**
 * Remove a stored instance id.
 *
 * @return bool - success status
 */
bool RemoveInstanceId() {
   if (__isChart) {
      // chart window
      string name = ProgramName() +".Instance.ID";
      RemoveWindowStringA(__ExecutionContext[EC.hChart], name);

      // chart
      Chart.RestoreString(name, name, true);

      // remove a chart status for chart commands
      name = "EA.status";
      if (ObjectFind(name) != -1) ObjectDelete(name);
   }
   return(!catch("RemoveInstanceId(1)"));
}


/**
 * Return a readable representation of an instance status code.
 *
 * @param  int status
 *
 * @return string
 */
string StatusToStr(int status) {
   switch (status) {
      case NULL              : return("(NULL)"            );
      case STATUS_WAITING    : return("STATUS_WAITING"    );
      case STATUS_PROGRESSING: return("STATUS_PROGRESSING");
      case STATUS_STOPPED    : return("STATUS_STOPPED"    );
   }
   return(_EMPTY_STR(catch("StatusToStr(1)  "+ instance.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Return a description of an instance status code.
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
   return(_EMPTY_STR(catch("StatusDescription(1)  "+ instance.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Return a readable representation of a signal constant.
 *
 * @param  int signal
 *
 * @return string - readable constant or an empty string in case of errors
 */
string SignalToStr(int signal) {
   switch (signal) {
      case NULL        : return("no signal"   );
      case SIGNAL_LONG : return("SIGNAL_LONG" );
      case SIGNAL_SHORT: return("SIGNAL_SHORT");
   }
   return(_EMPTY_STR(catch("SignalToStr(1)  "+ instance.name +" invalid parameter signal: "+ signal, ERR_INVALID_PARAMETER)));
}


/**
 * ShowStatus: Update all string representations.
 */
void SS.All() {
   if (__isChart) {
      SS.InstanceName();
      SS.Lots();
      SS.TotalPL();
      SS.PLStats();
   }
}


/**
 * ShowStatus: Update the string representation of the instance name.
 */
void SS.InstanceName() {
   instance.name = "V."+ instance.id;
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
 * ShowStatus: Update the string representation of "instance.netTotalPL".
 */
void SS.TotalPL() {
   if (__isChart) {
      // not before a position was opened
      if (!open.ticket && !ArrayRange(history, 0)) sInstanceTotalNetPL = "-";
      else                                         sInstanceTotalNetPL = NumberToStr(instance.totalNetProfit, "R+.2");
   }
}


/**
 * ShowStatus: Update the string representaton of the PL statistics.
 */
void SS.PLStats() {
   if (__isChart) {
      // not before a position was opened
      if (!open.ticket && !ArrayRange(history, 0)) {
         sInstancePlStats = "";
      }
      else {
         string sMaxProfit   = NumberToStr(instance.maxNetProfit, "+.2");
         string sMaxDrawdown = NumberToStr(instance.maxNetDrawdown, "+.2");
         sInstancePlStats = StringConcatenate("(", sMaxDrawdown, "/", sMaxProfit, ")");
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

   switch (instance.status) {
      case NULL:               sStatus = StringConcatenate(instance.name, "  not initialized"); break;
      case STATUS_WAITING:     sStatus = StringConcatenate(instance.name, "  waiting");         break;
      case STATUS_PROGRESSING: sStatus = StringConcatenate(instance.name, "  progressing");     break;
      case STATUS_STOPPED:     sStatus = StringConcatenate(instance.name, "  stopped");         break;
      default:
         return(catch("ShowStatus(1)  "+ instance.name +" illegal instance status: "+ instance.status, ERR_ILLEGAL_STATE));
   }
   if (__STATUS_OFF) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason), "]");

   string text = StringConcatenate(ProgramName(), "    ", sStatus, sError,                    NL,
                                                                                              NL,
                                  "Lots:     ", sLots,                                        NL,
                                  "Profit:   ",  sInstanceTotalNetPL, "  ", sInstancePlStats, NL
   );

   // 3 lines margin-top for instrument and indicator legends
   Comment(NL, NL, NL, text);
   if (__CoreFunction == CF_INIT) WindowRedraw();

   // store status in the chart to enable sending of chart commands
   string label = "EA.status";
   if (ObjectFind(label) != 0) {
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   }
   ObjectSetText(label, StringConcatenate(Instance.ID, "|", StatusDescription(instance.status)));

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
   return(StringConcatenate("Instance.ID=",      DoubleQuoteStr(Instance.ID), ";", NL,
                            "Donchian.Periods=", Donchian.Periods,            ";", NL,
                            "Lots=",             NumberToStr(Lots, ".1+"),    ";")
   );

   // suppress compiler warnings
   int signal;
   IsDonchianSignal(signal);
}
