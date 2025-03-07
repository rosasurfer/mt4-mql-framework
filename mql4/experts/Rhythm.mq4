/**
 * Rewritten version of "Rhythm-v2" by Ronald Raygun.
 *
 *  @source  https://www.forexfactory.com/thread/post/1733378#post1733378
 *
 *
 * Rules
 * -----
 *
 *
 * Changes
 * -------
 *
 *
 * TODO:
 *  - rewrite to standard EA structure
 *
 *  - performance
 *     GBPJPY,M1 2024.02.01-2024.03.02, EveryTick: 14.4 sec, 56 trades, LOG_WARN, Rhythm with framework
 *     GBPJPY,M1 2024.02.01-2024.03.02, EveryTick:  8.2 sec, 56 trades            Rhythm w/o framework
 *     GBPJPY,M1 2024.02.01-2024.03.02, EveryTick: 13.6 sec, 56 trades            Rhythm-v2 2007.11.28 @rraygun
 */
#define STRATEGY_ID  112                                 // unique strategy id

#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 0;

////////////////////////////////////////////////////////// Inputs ///////////////////////////////////////////////////////////

extern string Instance.ID                    = "";       // instance to load from a status file (format "[T]123")

extern int    EntryTimeHour                  = 1;        // server time
extern int    ExitTimeHour                   = 23;       // ...
extern int    MaxDailyTrades                 = 0;

extern double Lots                           = 0.1;
extern int    StopLoss                       = 30;       // in punits
extern int    TakeProfit                     = 60;       // ...
extern bool   BreakevenStop                  = true;
extern bool   TrailingStop                   = false;

extern string ___a__________________________ = "=== Other settings ============";
extern bool   ShowProfitInPercent            = false;    // whether PnL is displayed in money or percent

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// framework
#include <rsf/core/expert.mqh>
#include <rsf/core/expert.recorder.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/HandleCommands.mqh>
#include <rsf/functions/InitializeByteBuffer.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/structs/OrderExecution.mqh>

// EA definitions
#include <rsf/experts/instance/defines.mqh>
#include <rsf/experts/metric/defines.mqh>
#include <rsf/experts/status/defines.mqh>
#include <rsf/experts/test/defines.mqh>
#include <rsf/experts/trade/defines.mqh>
#include <rsf/experts/trade/stats/defines.mqh>

// EA functions
#include <rsf/experts/event/onCommand.mqh>

#include <rsf/experts/instance/CreateInstanceId.mqh>
#include <rsf/experts/instance/IsTestInstance.mqh>
#include <rsf/experts/instance/RestoreInstance.mqh>
#include <rsf/experts/instance/SetInstanceId.mqh>

#include <rsf/experts/log/GetLogFilename.mqh>

#include <rsf/experts/metric/GetMT4SymbolDefinition.mqh>

#include <rsf/experts/status/CreateStatusBox_6.mqh>
#include <rsf/experts/status/ShowOpenOrders.mqh>
#include <rsf/experts/status/ShowTradeHistory.mqh>
#include <rsf/experts/status/SS.All.mqh>
#include <rsf/experts/status/SS.MetricDescription.mqh>
#include <rsf/experts/status/SS.OpenLots.mqh>
#include <rsf/experts/status/SS.ClosedTrades.mqh>
#include <rsf/experts/status/SS.TotalProfit.mqh>
#include <rsf/experts/status/SS.ProfitStats.mqh>
#include <rsf/experts/status/StatusToStr.mqh>
#include <rsf/experts/status/StatusDescription.mqh>

#include <rsf/experts/status/file/FindStatusFile.mqh>
#include <rsf/experts/status/file/GetStatusFilename.mqh>
#include <rsf/experts/status/file/SetStatusFilename.mqh>
#include <rsf/experts/status/file/ReadStatus.General.mqh>
#include <rsf/experts/status/file/ReadStatus.OpenPosition.mqh>
#include <rsf/experts/status/file/ReadStatus.HistoryRecord.mqh>
#include <rsf/experts/status/file/ReadStatus.TradeHistory.mqh>
#include <rsf/experts/status/file/ReadStatus.TradeStats.mqh>
#include <rsf/experts/status/file/SaveStatus.General.mqh>
#include <rsf/experts/status/file/SaveStatus.OpenPosition.mqh>
#include <rsf/experts/status/file/SaveStatus.TradeHistory.mqh>
#include <rsf/experts/status/file/SaveStatus.TradeStats.mqh>

#include <rsf/experts/status/volatile/StoreVolatileStatus.mqh>
#include <rsf/experts/status/volatile/RestoreVolatileStatus.mqh>
#include <rsf/experts/status/volatile/RemoveVolatileStatus.mqh>
#include <rsf/experts/status/volatile/ToggleOpenOrders.mqh>
#include <rsf/experts/status/volatile/ToggleTradeHistory.mqh>
#include <rsf/experts/status/volatile/ToggleMetrics.mqh>

#include <rsf/experts/test/ReadTestConfiguration.mqh>

#include <rsf/experts/trade/AddHistoryRecord.mqh>
#include <rsf/experts/trade/CalculateMagicNumber.mqh>
#include <rsf/experts/trade/HistoryRecordToStr.mqh>
#include <rsf/experts/trade/IsMyOrder.mqh>

#include <rsf/experts/trade/stats/CalculateStats.mqh>

#include <rsf/experts/validation/ValidateInputs.ID.mqh>
#include <rsf/experts/validation/onInputError.mqh>

// init/deinit
#include <rsf/experts/init.mqh>
#include <rsf/experts/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (true) return(start_old());

   // --- new ---------------------------------------------------------------------------------------------------------------
   if (!instance.status) return(catch("onTick(1)  illegal instance.status: "+ instance.status, ERR_ILLEGAL_STATE));
   double signal[3];

   if (__isChart) {
      if (!HandleCommands()) return(last_error);      // process incoming commands, may switch on/off the instance
   }

   if (instance.status != STATUS_STOPPED) {
      if (instance.status == STATUS_WAITING) {
         //if (IsStartSignal(signal)) {                                                                                    // trading-time
         //   StartTrading(signal);                                                                                        // keep existing or open new position => STATUS_TRADING
         //}
      }
      else if (instance.status == STATUS_TRADING) {
         UpdateStatus();                              // update client-side status

         //if (IsStopSignal(signal)) {                                                                                     // no-trading-time || daily-stop-limit || total-profit-target
         //   StopTrading(signal);                                                                                         // close all positions => STATUS_WAITING|STATUS_STOPPED
         //}
         //else {                                     // update server-side status
         //   ManageOpenPositions();                  // add/reduce/reverse position, take (partial) profits
         //   UpdatePendingOrders();                  // update entry and/or exit limits
         //}
      }
      RecordMetrics();
   }
   return(last_error);
}


/**
 * Old main logic.
 *
 * @return int - error status
 */
int start_old() {
   static int entryDirection = -1;
   static double entryLevel = 0;
   int ticket, oe[];

   // find trend (override possible and skip Sundays for Monday trend)
   if (entryDirection < 0) {
      if (DayOfWeek() == MONDAY) int bs = iBarShift(NULL, PERIOD_D1, TimeCurrent()-3*DAYS);
      else                           bs = 1;
      if (iOpen(NULL, PERIOD_D1, bs) < iClose(NULL, PERIOD_D1, bs)) entryDirection = OP_BUY;
      else                                                          entryDirection = OP_SELL;
      entryLevel = ifDouble(entryDirection==OP_SELL, _Bid, _Ask);
   }

   if (IsTradingTime()) {
      // check for open position & whether the daily stop limit is reached
      if (!IsOpenPosition() && !IsDailyStop()) {
         double stoploss   = CalculateStopLoss(entryDirection);
         double takeprofit = CalculateTakeProfit(entryDirection);
         int magicNumber   = CalculateMagicNumber(instance.id);

         if (entryDirection == OP_BUY) {
            if (_Ask >= entryLevel) {
               ticket = OrderSendEx(Symbol(), entryDirection, Lots, NULL, order.slippage, stoploss, takeprofit, "Rhythm", magicNumber, NULL, Blue, NULL, oe);
               if (!ticket) return(!SetLastError(oe.Error(oe)));
            }
         }
         else {
            if (_Bid <= entryLevel) {
               ticket = OrderSendEx(Symbol(), entryDirection, Lots, NULL, order.slippage, stoploss, takeprofit, "Rhythm", magicNumber, NULL, Red, NULL, oe);
               if (!ticket) return(!SetLastError(oe.Error(oe)));
            }
         }
      }

      if (IsOpenPosition()) {                         // selects the ticket
         // find opposite entry level
         if (OrderType() == OP_BUY) entryDirection = OP_SELL;
         else                       entryDirection = OP_BUY;
         stoploss = NormalizeDouble(OrderStopLoss(), Digits);
         entryLevel = stoploss;

         // manage StopLoss
         if (TrailingStop) {
            if (OrderType() == OP_BUY) {
               double newStop = NormalizeDouble(OrderClosePrice() - StopLoss*pUnit, Digits);
               if (newStop > stoploss) {
                  if (!OrderModifyEx(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), NULL, CLR_OPEN_STOPLOSS, NULL, oe)) return(!SetLastError(oe.Error(oe)));
                  entryLevel = newStop;
               }
            }
            else {
               newStop = NormalizeDouble(OrderClosePrice() + StopLoss*pUnit, Digits);
               if (newStop < stoploss) {
                  if (!OrderModifyEx(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), NULL, CLR_OPEN_STOPLOSS, NULL, oe)) return(!SetLastError(oe.Error(oe)));
                  entryLevel = newStop;
               }
            }
         }
         else if (BreakevenStop) {
            newStop = NormalizeDouble(OrderOpenPrice(), Digits);
            if (newStop != stoploss) {
               if (OrderType() == OP_BUY) {
                  double triggerPrice = NormalizeDouble(OrderOpenPrice() + StopLoss*pUnit, Digits);
                  if (_Bid > triggerPrice) {                                                                            // TODO: original tests for ">" instead of ">="
                     if (!OrderModifyEx(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), NULL, CLR_OPEN_STOPLOSS, NULL, oe)) return(!SetLastError(oe.Error(oe)));
                     entryLevel = newStop;
                  }
               }
               else {
                  triggerPrice = NormalizeDouble(OrderOpenPrice() - StopLoss*pUnit, Digits);
                  if (_Ask < triggerPrice) {                                                                            // TODO: original tests for "<" instead of "<="
                     if (!OrderModifyEx(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), NULL, CLR_OPEN_STOPLOSS, NULL, oe)) return(!SetLastError(oe.Error(oe)));
                     entryLevel = newStop;
                  }
               }
            }
         }
      }
   }

   else {
      // close open positions
      for (int i=OrdersTotal()-1; i >= 0; i--) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if (!IsMyOrder(instance.id))                     continue;
         if (!OrderCloseEx(OrderTicket(), NULL, order.slippage, CLR_CLOSED, NULL, oe)) return(!SetLastError(oe.Error(oe)));
      }
      entryDirection = -1;
      entryLevel = 0;
   }
   return(last_error);
}


/**
 * Stop trading and close open positions (if any).
 *
 * @param  double signal[] - signal infos causing the call
 *
 * @return bool - success status
 */
bool StopTrading(double signal[]) {
   return(!catch("StopTrading(1)", ERR_NOT_IMPLEMENTED));
}


/**
 * Update client-side order status.
 *
 * @return bool - success status
 */
bool UpdateStatus() {
   return(!catch("UpdateStatus(1)", ERR_NOT_IMPLEMENTED));
}


/**
 *
 */
bool IsDailyStop() {
   int todayTrades;
   datetime today = iTime(NULL, PERIOD_D1, 0);

   for (int i=OrdersHistoryTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
      if (!IsMyOrder(instance.id)) continue;
      if (OrderOpenTime() < today) continue;
      todayTrades++;

      if (MaxDailyTrades && todayTrades >= MaxDailyTrades) {
         return(true);
      }
      if (TakeProfit > 0) {
         if (StrContains(OrderComment(), "[tp]")) return(true);
      }
   }
   return(false);
}


/**
 *
 */
bool IsOpenPosition() {
   for (int i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderType() <= OP_SELL) {
         if (IsMyOrder(instance.id)) return(true);
      }
   }
  return(false);
}


/**
 *
 */
bool IsTradingTime() {
   int now   = TimeCurrent() % DAY;
   int start = EntryTimeHour*HOURS;
   int end   = ExitTimeHour*HOURS;
   return(start <= now && now < end);
}


/**
 *
 */
double CalculateStopLoss(int type) {
   double sl = 0;
   if (StopLoss > 0) {
      if      (type == OP_BUY)  sl = _Bid - StopLoss*pUnit;
      else if (type == OP_SELL) sl = _Ask + StopLoss*pUnit;
   }
   return(NormalizeDouble(sl, Digits));
}


/**
 *
 */
double CalculateTakeProfit(int type) {
   double tp = 0;
   if (TakeProfit > 0) {
      if      (type == OP_BUY)  tp = _Bid + TakeProfit*pUnit;
      else if (type == OP_SELL) tp = _Ask - TakeProfit*pUnit;
   }
   return(NormalizeDouble(tp, Digits));
}


/**
 * Read the status file of an instance and restore inputs and runtime variables. Called only from RestoreInstance().
 *
 * @return bool - success status
 */
bool ReadStatus() {
   if (IsLastError()) return(false);
   if (!instance.id)  return(!catch("ReadStatus(1)  "+ instance.name +" illegal value of instance.id: "+ instance.id, ERR_ILLEGAL_STATE));

   string section="", file=GetStatusFilename();
   if (file == "")                 return(!catch("ReadStatus(2)  "+ instance.name +" status file not found", ERR_RUNTIME_ERROR));
   if (!IsFile(file, MODE_SYSTEM)) return(!catch("ReadStatus(3)  "+ instance.name +" file \""+ file +"\" not found", ERR_FILE_NOT_FOUND));

   // [General]
   if (!ReadStatus.General(file)) return(false);

   // [Inputs]
   section = "Inputs";
   Instance.ID              = GetIniStringA(file, section, "Instance.ID",     "");           // string   Instance.ID         = T123
   EntryTimeHour            = GetIniInt    (file, section, "EntryTimeHour"      );           // int      EntryTimeHour       = 1
   ExitTimeHour             = GetIniInt    (file, section, "ExitTimeHour"       );           // int      ExitTimeHour        = 23
   MaxDailyTrades           = GetIniInt    (file, section, "MaxDailyTrades"     );           // int      MaxDailyTrades      = 5
   Lots                     = GetIniDouble (file, section, "Lots"               );           // double   Lots                = 0.1
   StopLoss                 = GetIniInt    (file, section, "StopLoss"           );           // int      StopLoss            = 400
   TakeProfit               = GetIniInt    (file, section, "TakeProfit"         );           // int      TakeProfit          = 800
   BreakevenStop            = GetIniBool   (file, section, "BreakevenStop"      );           // bool     BreakevenStop       = 1
   TrailingStop             = GetIniBool   (file, section, "TrailingStop"       );           // bool     Trailin             = 0
   ShowProfitInPercent      = GetIniBool   (file, section, "ShowProfitInPercent");           // bool     ShowProfitInPercent = 1
   EA.Recorder              = GetIniStringA(file, section, "EA.Recorder",     "");           // string   EA.Recorder         = 1,2,4

   // [Runtime status]
   section = "Runtime status";
   instance.id              = GetIniInt    (file, section, "instance.id"      );             // int      instance.id              = 123
   instance.name            = GetIniStringA(file, section, "instance.name", "");             // string   instance.name            = ID.123
   instance.created         = GetIniInt    (file, section, "instance.created" );             // datetime instance.created         = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.started         = GetIniInt    (file, section, "instance.started" );             // datetime instance.started         = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.stopped         = GetIniInt    (file, section, "instance.stopped" );             // datetime instance.stopped         = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.isTest          = GetIniBool   (file, section, "instance.isTest"  );             // bool     instance.isTest          = 1
   instance.status          = GetIniInt    (file, section, "instance.status"  );             // int      instance.status          = 1 (waiting)
   recorder.stdEquitySymbol = GetIniStringA(file, section, "recorder.stdEquitySymbol", "");  // string   recorder.stdEquitySymbol = GBPJPY.001
   SS.InstanceName();

   // open/closed trades and stats
   if (!ReadStatus.OpenPosition(file)) return(false);
   if (!ReadStatus.TradeHistory(file)) return(false);
   if (!ReadStatus.TradeStats(file))   return(false);

   return(!catch("ReadStatus(4)"));
}


/**
 * Synchronize local status with current status on the trade server. Called from RestoreInstance() only.
 *
 * @return bool - success status
 */
bool SynchronizeStatus() {
   if (IsLastError()) return(false);

   // detect and handle orphaned open positions
   int orders = OrdersTotal();
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;        // FALSE: an open order was closed/deleted in another thread
      if (IsMyOrder(instance.id)) {
         if (open.ticket > 0) return(!catch("SynchronizeStatus(1)  illegal second position detected: #"+ OrderTicket(), ERR_ILLEGAL_STATE));
         open.ticket     = OrderTicket();
         open.type       = OrderType();
         open.lots       = OrderLots();
         open.price      = OrderOpenPrice();
         open.stopLoss   = OrderStopLoss();
         open.takeProfit = OrderTakeProfit();
      }
   }

   // detect and handle orphaned closed trades
   orders = OrdersHistoryTotal();
   for (i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) break;       // FALSE: the visible history range was modified in another thread
      if (IsPendingOrderType(OrderType()))              continue;    // skip deleted pending orders
      if (IsMyOrder(instance.id)) {
         // TODO
      }
   }

   SS.All();
   return(!catch("SynchronizeStatus(2)"));
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
      if (test.reduceStatusWrites) {                           // in tester skip all writes except file creation, instance stop and test end
         static bool saved = false;
         if (saved && instance.status!=STATUS_STOPPED && __CoreFunction!=CF_DEINIT) return(true);
         saved = true;
      }
   }
   else if (IsTestInstance()) return(true);                    // don't modify the status file of a finished test

   string section="", separator="", file=GetStatusFilename();
   bool fileExists = IsFile(file, MODE_SYSTEM);
   if (!fileExists) separator = CRLF;                          // an empty line separator
   SS.All();                                                   // update trade stats and global string representations

   // [General]
   if (!SaveStatus.General(file, fileExists)) return(false);   // account, symbol and test infos

   // [Inputs]
   section = "Inputs";
   WriteIniString(file, section, "Instance.ID",                /*string  */ Instance.ID);
   WriteIniString(file, section, "EntryTimeHour",              /*int     */ EntryTimeHour);
   WriteIniString(file, section, "ExitTimeHour",               /*int     */ ExitTimeHour);
   WriteIniString(file, section, "MaxDailyTrades",             /*int     */ MaxDailyTrades);
   WriteIniString(file, section, "Lots",                       /*double  */ NumberToStr(Lots, ".+"));
   WriteIniString(file, section, "StopLoss",                   /*int     */ StopLoss);
   WriteIniString(file, section, "TakeProfit",                 /*int     */ TakeProfit);
   WriteIniString(file, section, "BreakevenStop",              /*bool    */ BreakevenStop);
   WriteIniString(file, section, "TrailingStop",               /*bool    */ TrailingStop);
   WriteIniString(file, section, "ShowProfitInPercent",        /*bool    */ ShowProfitInPercent);
   WriteIniString(file, section, "EA.Recorder",                /*string  */ EA.Recorder + separator);

   // trade stats
   if (!SaveStatus.TradeStats(file, fileExists)) return(false);

   // [Runtime status]
   section = "Runtime status";
   WriteIniString(file, section, "instance.id",                /*int     */ instance.id);
   WriteIniString(file, section, "instance.name",              /*string  */ instance.name);
   WriteIniString(file, section, "instance.created",           /*datetime*/ instance.created + GmtTimeFormat(instance.created, " (%a, %Y.%m.%d %H:%M:%S)"));
   WriteIniString(file, section, "instance.started",           /*datetime*/ instance.started + ifString(!instance.started, "", GmtTimeFormat(instance.started, " (%a, %Y.%m.%d %H:%M:%S)")));
   WriteIniString(file, section, "instance.stopped",           /*datetime*/ instance.stopped + ifString(!instance.stopped, "", GmtTimeFormat(instance.stopped, " (%a, %Y.%m.%d %H:%M:%S)")));
   WriteIniString(file, section, "instance.isTest",            /*bool    */ instance.isTest);
   WriteIniString(file, section, "instance.status",            /*int     */ instance.status +" ("+ StatusDescription(instance.status) +")");
   WriteIniString(file, section, "recorder.stdEquitySymbol",   /*string  */ recorder.stdEquitySymbol + separator);

   // open/closed trades
   if (!SaveStatus.OpenPosition(file, fileExists)) return(false);
   if (!SaveStatus.TradeHistory(file, fileExists)) return(false);

   return(!catch("SaveStatus(2)"));
}


// backed-up input parameters
string   prev.Instance.ID = "";
int      prev.EntryTimeHour;
int      prev.ExitTimeHour;
int      prev.MaxDailyTrades;
double   prev.Lots;
int      prev.StopLoss;
int      prev.TakeProfit;
bool     prev.BreakevenStop;
bool     prev.TrailingStop;
bool     prev.ShowProfitInPercent;


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
   prev.Instance.ID         = StringConcatenate(Instance.ID, "");    // string inputs are references to internal C literals
   prev.EntryTimeHour       = EntryTimeHour;                         // and must be copied to break the reference
   prev.ExitTimeHour        = ExitTimeHour;
   prev.MaxDailyTrades      = MaxDailyTrades;
   prev.Lots                = Lots;
   prev.StopLoss            = StopLoss;
   prev.TakeProfit          = TakeProfit;
   prev.BreakevenStop       = BreakevenStop;
   prev.TrailingStop        = TrailingStop;
   prev.ShowProfitInPercent = ShowProfitInPercent;

   // affected runtime variables
   Recorder_BackupInputs();
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // input parameters
   Instance.ID         = prev.Instance.ID;
   EntryTimeHour       = prev.EntryTimeHour;
   ExitTimeHour        = prev.ExitTimeHour;
   MaxDailyTrades      = prev.MaxDailyTrades;
   Lots                = prev.Lots;
   StopLoss            = prev.StopLoss;
   TakeProfit          = prev.TakeProfit;
   BreakevenStop       = prev.BreakevenStop;
   TrailingStop        = prev.TrailingStop;
   ShowProfitInPercent = prev.ShowProfitInPercent;

   // affected runtime variables
   Recorder_RestoreInputs();
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
      else if (Instance.ID != prev.Instance.ID) return(!onInputError("ValidateInputs(1)  "+ instance.name +" switching to another instance is not supported (unload the EA first)"));
   }

   // EntryTimeHour
   // ExitTimeHour
   // MaxTrades

   // Lots
   if (LT(Lots, 0))                             return(!onInputError("ValidateInputs(2)  "+ instance.name +" invalid input Lots: "+ NumberToStr(Lots, ".1+") +" (must be > 0)"));
   if (NE(Lots, NormalizeLots(Lots)))           return(!onInputError("ValidateInputs(3)  "+ instance.name +" invalid input Lots: "+ NumberToStr(Lots, ".1+") +" (must be a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   // StopLoss
   // TakeProfit

   // BreakevenStop (nothing to do)
   // TrailingStop (nothing to do)

   // ShowProfitInPercent (nothing to do)

   // EA.Recorder: on | off* | 1,2,3=1000,...
   if (!Recorder_ValidateInputs(IsTestInstance())) return(false);

   SS.All();
   return(!catch("ValidateInputs(4)"));
}


/**
 * ShowStatus: Update the string representation of the instance name.
 */
void SS.InstanceName() {
   instance.name = "RHY."+ StrPadLeft(instance.id, 3, "0");
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Instance.ID=",         DoubleQuoteStr(Instance.ID),    ";", NL,

                            "EntryTimeHour=",       EntryTimeHour,                  ";", NL,
                            "ExitTimeHour=",        ExitTimeHour,                   ";", NL,
                            "MaxDailyTrades=",      MaxDailyTrades,                 ";", NL,

                            "Lots=",                NumberToStr(Lots, ".1+"),       ";", NL,
                            "StopLoss=",            StopLoss,                       ";", NL,
                            "TakeProfit=",          TakeProfit,                     ";", NL,
                            "BreakevenStop=",       BoolToStr(BreakevenStop),       ";", NL,
                            "TrailingStop=",        BoolToStr(TrailingStop),        ";", NL,

                            "ShowProfitInPercent=", BoolToStr(ShowProfitInPercent), ";")
   );
}
