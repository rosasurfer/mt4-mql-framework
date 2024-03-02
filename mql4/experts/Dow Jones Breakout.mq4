/**
 * Breakout strategy for DJIA
 *
 *
 * TODO:
 *  - Test schreiben für Breakout aus 16:00-16:30 Range, MinBreakoutDistance=5.00, Target1=30.00, MoveStopTo=1.00
 *  - an News-Tagen statt NY-Open die 15:00-15:30 Range nehmen
 *  - wenn NY-Open an News-Tagen innerhalb der 15:00-15:30 Range, dann auch den Open-Breakout traden
 *  - wird viel Slippage geben, ich sehe aber kaum Loss-Tage
 *
 *  - track spread at range end time
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 0;

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID          = "";     // instance to load from a status file (format "[T]123")

extern double Lots                 = 1.0;
extern int    Initial.TakeProfit   = 100;    // in pip (0: partial targets only or no TP)
extern int    Initial.StopLoss     = 50;     // in pip (0: moving stops only or no SL
extern int    Target1              = 0;      // in pip
extern int    Target1.ClosePercent = 0;      // size to close (0: nothing)
extern int    Target1.MoveStopTo   = 1;      // in pip (0: don't move stop)
extern int    Target2              = 0;      // ...
extern int    Target2.ClosePercent = 30;     //
extern int    Target2.MoveStopTo   = 0;      //
extern int    Target3              = 0;      //
extern int    Target3.ClosePercent = 30;     //
extern int    Target3.MoveStopTo   = 0;      //
extern int    Target4              = 0;      //
extern int    Target4.ClosePercent = 30;     //
extern int    Target4.MoveStopTo   = 0;      //

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/iBarShiftNext.mqh>
#include <functions/iBarShiftPrevious.mqh>
#include <ea/functions/metric/defines.mqh>
#include <ea/functions/trade/defines.mqh>
#include <ea/functions/trade/stats/defines.mqh>

#define STRATEGY_ID         110              // unique strategy id (used for magic order numbers)

#define INSTANCE_ID_MIN       1              // range of valid instance ids
#define INSTANCE_ID_MAX     999              //

#define STATUS_WAITING        1              // instance has no open positions and waits for signals
#define STATUS_PROGRESSING    2              // instance manages open positions
#define STATUS_STOPPED        3              // instance has no open positions and doesn't wait for signals

// instance data
int      instance.id;                        // used for magic order numbers
string   instance.name = "";
datetime instance.created;
bool     instance.isTest;                    // whether the instance is a test
int      instance.status;
double   instance.startEquity;

double   instance.openNetProfit;             // real PnL after all costs in money (net)
double   instance.closedNetProfit;           //
double   instance.totalNetProfit;            //
double   instance.maxNetProfit;              // max. observed profit:   0...+n
double   instance.maxNetDrawdown;            // max. observed drawdown: -n...0

double   instance.openNetProfitP;            // real PnL after all costs in point (net)
double   instance.closedNetProfitP;          //
double   instance.totalNetProfitP;           //
double   instance.maxNetProfitP;             //
double   instance.maxNetDrawdownP;           //

double   instance.openSigProfitP;            // signal PnL before spread/any costs in point
double   instance.closedSigProfitP;          //
double   instance.totalSigProfitP;           //
double   instance.maxSigProfitP;             //
double   instance.maxSigDrawdownP;           //

// order data
int      open.ticket;                        // one open position
int      open.type;
double   open.lots;
datetime open.time;
double   open.price;
double   open.priceSig;
double   open.slippage;
double   open.swap;
double   open.commission;
double   open.grossProfit;
double   open.netProfit;
double   open.netProfitP;
double   open.runupP;                        // max runup distance
double   open.drawdownP;                     // ...
double   open.sigProfitP;
double   open.sigRunupP;                     // max signal runup distance
double   open.sigDrawdownP;                  // ...

// bracket times
int      bracket1Start = 900;                // 15:00 (minutes after Midnight)
int      bracket1End   = 930;                // 15:30 ...
int      bracket2Start = 960;                // 16:00 ...
int      bracket2End   = 990;                // 16:30 ...

// volatile status data
int      status.activeMetric = 1;
bool     status.showOpenOrders;
bool     status.showTradeHistory;

// other
string   pUnit = "";
int      pDigits;
int      pMultiplier;
int      order.slippage = 1;                 // in MQL points

// cache vars to speed-up ShowStatus()
string   sOpenLots     = "";
string   sClosedTrades = "";
string   sTotalProfit  = "";
string   sProfitStats  = "";

// debug settings                            // configurable via framework config, see afterInit()
bool     test.onStopPause        = false;    // whether to pause a test after StopInstance()
bool     test.reduceStatusWrites = true;     // whether to reduce status file I/O in tester

// initialization/deinitialization
#include <ea/dj-breakout/init.mqh>
#include <ea/dj-breakout/deinit.mqh>

// shared functions
#include <ea/functions/CalculateMagicNumber.mqh>
#include <ea/functions/CreateInstanceId.mqh>
#include <ea/functions/IsMyOrder.mqh>
#include <ea/functions/IsTestInstance.mqh>
#include <ea/functions/RestoreInstance.mqh>
#include <ea/functions/SetInstanceId.mqh>

#include <ea/functions/ShowTradeHistory.mqh>
#include <ea/functions/ToggleOpenOrders.mqh>
#include <ea/functions/ToggleTradeHistory.mqh>

#include <ea/functions/log/GetLogFilename.mqh>

#include <ea/functions/metric/Recorder_GetSymbolDefinition.mqh>
#include <ea/functions/metric/ToggleMetrics.mqh>

#include <ea/functions/status/StatusToStr.mqh>
#include <ea/functions/status/StatusDescription.mqh>
#include <ea/functions/status/SS.OpenLots.mqh>
#include <ea/functions/status/SS.ClosedTrades.mqh>
#include <ea/functions/status/SS.TotalProfit.mqh>
#include <ea/functions/status/SS.ProfitStats.mqh>

#include <ea/functions/status/file/FindStatusFile.mqh>
#include <ea/functions/status/file/GetStatusFilename.mqh>
#include <ea/functions/status/file/ReadStatus.General.mqh>
#include <ea/functions/status/file/ReadStatus.Targets.mqh>
#include <ea/functions/status/file/ReadStatus.OpenPosition.mqh>
#include <ea/functions/status/file/ReadStatus.HistoryRecord.mqh>
#include <ea/functions/status/file/ReadStatus.TradeHistory.mqh>
#include <ea/functions/status/file/ReadStatus.TradeStats.mqh>
#include <ea/functions/status/file/SaveStatus.General.mqh>
#include <ea/functions/status/file/SaveStatus.Targets.mqh>
#include <ea/functions/status/file/SaveStatus.OpenPosition.mqh>
#include <ea/functions/status/file/SaveStatus.TradeHistory.mqh>
#include <ea/functions/status/file/SaveStatus.TradeStats.mqh>

#include <ea/functions/status/volatile/StoreVolatileData.mqh>
#include <ea/functions/status/volatile/RestoreVolatileData.mqh>
#include <ea/functions/status/volatile/RemoveVolatileData.mqh>

#include <ea/functions/trade/AddHistoryRecord.mqh>
#include <ea/functions/trade/HistoryRecordToStr.mqh>
#include <ea/functions/trade/stats/CalculateStats.mqh>

#include <ea/functions/validation/ValidateInputs.ID.mqh>
#include <ea/functions/validation/ValidateInputs.Targets.mqh>
#include <ea/functions/validation/onInputError.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!instance.status) return(catch("onTick(1)  illegal instance.status: "+ instance.status, ERR_ILLEGAL_STATE));

   if (__isChart) HandleCommands();                      // process incoming commands

   datetime now = Tick.time % DAYS;                      // offset to Midnight

   if (now >= bracket1Start && now <= bracket1End) {
      debug("onTick(0.1)  inside bracket 1");
      // calculate bracket range
      // update visualization
      // if (no-open-position) update limit orders
   }
   else if (now >= bracket2Start && now <= bracket2End) {
      debug("onTick(0.2)  inside bracket 2");
   }
   return(catch("onTick(2)"));





   // --- old ---------------------------------------------------------------------------------------------------------------
   datetime midnight    = Tick.time - Tick.time % DAYS;
   datetime range1Start = midnight + bracket1Start*MINUTES;
   datetime range1End   = midnight + bracket1End*MINUTES;

   if (Tick.time < range1End-15*SECONDS) {
      return(NO_ERROR);
   }
   else {
      //debug("onTick(0.1)  Tick="+ Ticks +"  range1Start="+ TimeToStr(range1Start, TIME_DATE|TIME_MINUTES) +"  range1End="+ TimeToStr(range1End, TIME_DATE|TIME_MINUTES));

      int period = ifInt(__isTesting, NULL, PERIOD_M5);
      int fromBar = iBarShiftNext    (NULL, period, range1Start); if (fromBar == -1) return(catch("onTick(2)  iBarShiftNext("+ TimeToStr(range1Start, TIME_FULL) +") => -1 no such data (rangeStart too young)", ERR_RUNTIME_ERROR));
      int toBar   = iBarShiftPrevious(NULL, period, range1End-1); if (toBar   == -1) return(catch("onTick(3)  iBarShiftPrevious("+ TimeToStr(range1End-1, TIME_FULL) +") => -1 no such data (rangeEnd too old)", ERR_RUNTIME_ERROR));
      if (fromBar < toBar)                                                           return(catch("onTick(4)  range from bar "+ fromBar +" to "+ toBar +" => no such data (gap in rates)", ERR_RUNTIME_ERROR));

      double high = High[iHighest(NULL, period, MODE_HIGH, fromBar-toBar+1, toBar)];
      double low  =  Low[iLowest (NULL, period, MODE_LOW,  fromBar-toBar+1, toBar)];

      debug("onTick(0.2)  Tick="+ Ticks +"  bracket from["+ fromBar +"]="+ TimeToStr(Time[fromBar], TIME_MINUTES) +"  to["+ toBar +"]="+ TimeToStr(Time[toBar], TIME_MINUTES) +"  H/L="+ NumberToStr(high, PriceFormat) +"/"+ NumberToStr(low, PriceFormat));


      static bool done = false;
      if (IsVisualMode() && !done) {
         Tester.Pause("onTick(0.2)");
         done = true;
      }
   }

   // -----------------------------------------------------------------------------------------------------------------------
   // wait until 15:29:50
   // calculate range and send limit order a few seconds before range end time

   // -----------------------------------------------------------------------------------------------------------------------
   // wait until 15:29, calculate and draw range (similar to Bracket indicator)
   // enter limit orders
   // manage position
   // wait until 16:29, calculate and draw range
   // enter limit orders
   // manage position

   if (instance.status != STATUS_STOPPED) {
      if (instance.status == STATUS_WAITING) {
      }
      else if (instance.status == STATUS_PROGRESSING) {
         UpdateStatus();
      }
   }
   return(catch("onTick(2)"));
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

   if (cmd == "toggle-metrics") {
      int direction = ifInt(keys & F_VK_SHIFT, METRIC_PREVIOUS, METRIC_NEXT);
      return(ToggleMetrics(direction, METRIC_NET_MONEY, METRIC_SIG_UNITS));
   }
   else if (cmd == "toggle-open-orders") {
      return(ToggleOpenOrders());
   }
   else if (cmd == "toggle-trade-history") {
      return(ToggleTradeHistory());
   }
   else return(!logNotice("onCommand(1)  "+ instance.name +" unsupported command: "+ DoubleQuoteStr(fullCmd)));

   return(!logWarn("onCommand(2)  "+ instance.name +" cannot execute command "+ DoubleQuoteStr(fullCmd) +" in status "+ StatusToStr(instance.status)));
}


/**
 * Update order status and PnL stats.
 *
 * @param  int signal [optional] - trade signal causing the call (default: none, update status only)
 *
 * @return bool - success status
 */
bool UpdateStatus(int signal = NULL) {
   if (last_error != NULL)                                                     return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_PROGRESSING) return(!catch("UpdateStatus(1)  "+ instance.name +" illegal instance status "+ StatusToStr(instance.status), ERR_ILLEGAL_STATE));

   return(!catch("UpdateStatus(2)  not implemented", ERR_NOT_IMPLEMENTED));
}


/**
 * Stop a waiting or progressing instance and close open positions (if any).
 *
 * @return bool - success status
 */
bool StopInstance() {
   if (last_error != NULL)                                                     return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_PROGRESSING) return(!catch("StopInstance(1)  "+ instance.name +" cannot stop "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));

   logNotice("StopInstance(0.1)  not implemented", ERR_NOT_IMPLEMENTED);

   return(!catch("StopInstance(2)"));
}


/**
 * Read the status file of an instance and restore inputs and runtime variables. Called only from RestoreInstance().
 *
 * @return bool - success status
 */
bool ReadStatus() {
   if (IsLastError()) return(false);
   if (!instance.id)  return(!catch("ReadStatus(1)  "+ instance.name +" illegal value of instance.id: "+ instance.id, ERR_ILLEGAL_STATE));

   string section="", file=FindStatusFile(instance.id, instance.isTest);
   if (file == "")                 return(!catch("ReadStatus(2)  "+ instance.name +" status file not found", ERR_RUNTIME_ERROR));
   if (!IsFile(file, MODE_SYSTEM)) return(!catch("ReadStatus(3)  "+ instance.name +" file "+ DoubleQuoteStr(file) +" not found", ERR_FILE_NOT_FOUND));

   // [General]
   if (!ReadStatus.General(file)) return(false);

   // [Inputs]
   section = "Inputs";
   Instance.ID              = GetIniStringA(file, section, "Instance.ID", "");               // string   Instance.ID = T123
   Lots                     = GetIniDouble (file, section, "Lots"           );               // double   Lots        = 0.1
   if (!ReadStatus.Targets(file)) return(false);
   EA.Recorder              = GetIniStringA(file, section, "EA.Recorder", "");               // string   EA.Recorder = 1,2,4

   // [Runtime status]
   section = "Runtime status";
   instance.id              = GetIniInt    (file, section, "instance.id"      );             // int      instance.id              = 123
   instance.name            = GetIniStringA(file, section, "instance.name", "");             // string   instance.name            = ID.123
   instance.created         = GetIniInt    (file, section, "instance.created" );             // datetime instance.created         = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.isTest          = GetIniBool   (file, section, "instance.isTest"  );             // bool     instance.isTest          = 1
   instance.status          = GetIniInt    (file, section, "instance.status"  );             // int      instance.status          = 1 (waiting)
   recorder.stdEquitySymbol = GetIniStringA(file, section, "recorder.stdEquitySymbol", "");  // string   recorder.stdEquitySymbol = GBPJPY.001
   SS.InstanceName();

   // open/closed trades and stats
   if (!ReadStatus.TradeStats(file))   return(false);
   if (!ReadStatus.OpenPosition(file)) return(false);
   if (!ReadStatus.TradeHistory(file)) return(false);

   return(!catch("ReadStatus(4)"));
}


/**
 * Synchronize runtime state and vars with current order status on the trade server. Called only from RestoreInstance().
 *
 * @return bool - success status
 */
bool SynchronizeStatus() {
   if (IsLastError()) return(false);

   // detect & handle dangling open positions
   for (int i=OrdersTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;     // FALSE: an open order was closed/deleted in another thread
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

   SS.All();
   return(!catch("SynchronizeStatus(1)"));
}


/**
 * Write the current instance status to a file.
 *
 * @return bool - success status
 */
bool SaveStatus() {
   if (last_error != NULL)              return(false);
   if (!instance.id || Instance.ID=="") return(!catch("SaveStatus(1)  illegal instance id: "+ instance.id +" (Instance.ID="+ DoubleQuoteStr(Instance.ID) +")", ERR_ILLEGAL_STATE));
   if (__isTesting) {
      if (test.reduceStatusWrites) {                           // in tester skip most writes except file creation, instance stop and test end
         static bool saved = false;
         if (saved && instance.status!=STATUS_STOPPED && __CoreFunction!=CF_DEINIT) return(true);
         saved = true;
      }
   }
   else if (IsTestInstance()) return(true);                    // don't change the status file of a finished test

   string section="", separator="", file=GetStatusFilename();
   bool fileExists = IsFile(file, MODE_SYSTEM);
   if (!fileExists) separator = CRLF;                          // an empty line separator
   SS.All();                                                   // update trade stats and global string representations

   // [General]
   if (!SaveStatus.General(file, fileExists)) return(false);   // account and instrument infos

   // [Inputs]
   section = "Inputs";
   WriteIniString(file, section, "Instance.ID",                /*string  */ Instance.ID);
   WriteIniString(file, section, "Lots",                       /*double  */ NumberToStr(Lots, ".+"));
   if (!SaveStatus.Targets(file, true)) return(false);         // StopLoss and TakeProfit targets
   WriteIniString(file, section, "EA.Recorder",                /*string  */ EA.Recorder + separator);

   // trade stats
   if (!SaveStatus.TradeStats(file, fileExists)) return(false);

   // [Runtime status]
   section = "Runtime status";
   WriteIniString(file, section, "instance.id",                /*int     */ instance.id);
   WriteIniString(file, section, "instance.name",              /*string  */ instance.name);
   WriteIniString(file, section, "instance.created",           /*datetime*/ instance.created + GmtTimeFormat(instance.created, " (%a, %Y.%m.%d %H:%M:%S)"));
   WriteIniString(file, section, "instance.isTest",            /*bool    */ instance.isTest);
   WriteIniString(file, section, "instance.status",            /*int     */ instance.status +" ("+ StatusDescription(instance.status) +")" + separator);

   WriteIniString(file, section, "recorder.stdEquitySymbol",   /*string  */ recorder.stdEquitySymbol + separator);

   // open/closed trades
   if (!SaveStatus.OpenPosition(file, fileExists)) return(false);
   if (!SaveStatus.TradeHistory(file, fileExists)) return(false);

   return(!catch("SaveStatus(2)"));
}


// backed-up input parameters
string   prev.Instance.ID = "";
double   prev.Lots;

// backed-up runtime variables affected by changing input parameters
int      prev.instance.id;
datetime prev.instance.created;
bool     prev.instance.isTest;
string   prev.instance.name = "";
int      prev.instance.status;


/**
 * When input parameters are changed at runtime, input errors must be handled gracefully. To enable the EA to continue in
 * case of input errors, it must be possible to restore previous valid inputs. This also applies to programmatic changes to
 * input parameters which do not survive init cycles. The previous input parameters are therefore backed up in deinit() and
 * can be restored in init() if necessary.
 *
 * Called in onDeinitParameters() and onDeinitChartChange().
 */
void BackupInputs() {
   // input parameters, used for comparison in ValidateInputs()
   prev.Instance.ID = StringConcatenate(Instance.ID, "");            // string inputs are references to internal C literals
   prev.Lots        = Lots;

   // affected runtime variables
   prev.instance.id      = instance.id;
   prev.instance.created = instance.created;
   prev.instance.isTest  = instance.isTest;
   prev.instance.name    = instance.name;
   prev.instance.status  = instance.status;

   BackupInputs.Targets();
   BackupInputs.Recorder();
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // input parameters
   Instance.ID = prev.Instance.ID;
   Lots        = prev.Lots;

   // affected runtime variables
   instance.id      = prev.instance.id;
   instance.created = prev.instance.created;
   instance.isTest  = prev.instance.isTest;
   instance.name    = prev.instance.name;
   instance.status  = prev.instance.status;

   RestoreInputs.Targets();
   RestoreInputs.Recorder();
}


/**
 * Validate all input parameters. Parameters may have been entered through the input dialog, read from a status file or were
 * deserialized and set programmatically by the terminal (e.g. at terminal restart). Called from onInitUser(),
 * onInitParameters() or onInitTemplate().
 *
 * @return bool - whether input parameters are valid
 */
bool ValidateInputs() {
   if (IsLastError()) return(false);
   bool isInitParameters = (ProgramInitReason()==IR_PARAMETERS);  // whether we validate manual or programatic input
   bool hasOpenOrders = false;

   // Instance.ID
   if (isInitParameters) {                                        // otherwise the id was validated in ValidateInputs.ID()
      if (StrTrim(Instance.ID) == "") {                           // the id was deleted or not yet set, restore the internal id
         Instance.ID = prev.Instance.ID;
      }
      else if (Instance.ID != prev.Instance.ID)    return(!onInputError("ValidateInputs(1)  "+ instance.name +" switching to another instance is not supported (unload the EA first)"));
   }

   // Lots
   if (LT(Lots, 0))                                return(!onInputError("ValidateInputs(2)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (must be > 0)"));
   if (NE(Lots, NormalizeLots(Lots)))              return(!onInputError("ValidateInputs(3)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (must be a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   // Targets
   if (!ValidateInputs.Targets()) return(false);

   // EA.Recorder: on | off* | 1,2,3=1000,...
   if (!Recorder.ValidateInputs(IsTestInstance())) return(false);

   SS.All();
   return(!catch("ValidateInputs(4)"));
}


/**
 * ShowStatus: Update all string representations.
 */
void SS.All() {
   SS.InstanceName();
   SS.OpenLots();
   SS.ClosedTrades();
   SS.TotalProfit();
   SS.ProfitStats();
}


/**
 * ShowStatus: Update the string representation of the instance name.
 */
void SS.InstanceName() {
   instance.name = "DB."+ StrPadLeft(instance.id, 3, "0");
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

   static bool isRecursion = false;             // to prevent recursive calls a specified error is displayed only once
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

   string text = StringConcatenate(ProgramName(), "    ", sStatus, sError,          NL,
                                                                                    NL,
                                   "Open:    ",   sOpenLots,                        NL,
                                   "Closed:  ",   sClosedTrades,                    NL,
                                   "Profit:    ", sTotalProfit, "  ", sProfitStats, NL
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
   return(StringConcatenate("Instance.ID=",          DoubleQuoteStr(Instance.ID), ";"+ NL +

                            "Lots=",                 NumberToStr(Lots, ".1+"),    ";"+ NL +
                            "Initial.TakeProfit=",   Initial.TakeProfit,          ";"+ NL +
                            "Initial.StopLoss=",     Initial.StopLoss,            ";"+ NL +
                            "Target1=",              Target1,                     ";"+ NL +
                            "Target1.ClosePercent=", Target1.ClosePercent,        ";"+ NL +
                            "Target1.MoveStopTo=",   Target1.MoveStopTo,          ";"+ NL +
                            "Target2=",              Target2,                     ";"+ NL +
                            "Target2.ClosePercent=", Target2.ClosePercent,        ";"+ NL +
                            "Target2.MoveStopTo=",   Target2.MoveStopTo,          ";"+ NL +
                            "Target3=",              Target3,                     ";"+ NL +
                            "Target3.ClosePercent=", Target3.ClosePercent,        ";"+ NL +
                            "Target3.MoveStopTo=",   Target3.MoveStopTo,          ";"+ NL +
                            "Target4=",              Target4,                     ";"+ NL +
                            "Target4.ClosePercent=", Target4.ClosePercent,        ";"+ NL +
                            "Target4.MoveStopTo=",   Target4.MoveStopTo,          ";")
   );
}
