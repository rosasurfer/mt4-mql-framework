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
 *     GBPJPY,M1 2024.02.01-2024.03.02, EveryTick: 12.4 sec, 56 trades        Rhythm with framework, built-in order functions
 *     GBPJPY,M1 2024.02.01-2024.03.02, EveryTick:  8.2 sec, 56 trades        Rhythm w/o framework
 *     GBPJPY,M1 2024.02.01-2024.03.02, EveryTick: 13.6 sec, 56 trades        Rhythm-v2 2007.11.28 @rraygun
 */
#define STRATEGY_ID  112                     // unique strategy id (used for generation of magic order numbers)

#include <stddefines.mqh>
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
extern bool   ShowProfitInPercent            = false;    // whether PnL is displayed in money amounts or percent

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// framework
#include <core/expert.mqh>
#include <core/expert.recorder.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/InitializeByteBuffer.mqh>

// EA definitions
#include <ea/functions/instance/defines.mqh>
#include <ea/functions/metric/defines.mqh>
#include <ea/functions/status/defines.mqh>
#include <ea/functions/test/defines.mqh>
#include <ea/functions/trade/defines.mqh>
#include <ea/functions/trade/stats/defines.mqh>

// EA functions
#include <ea/functions/onCommand.mqh>

#include <ea/functions/instance/CreateInstanceId.mqh>
#include <ea/functions/instance/IsTestInstance.mqh>
#include <ea/functions/instance/RestoreInstance.mqh>
#include <ea/functions/instance/SetInstanceId.mqh>

#include <ea/functions/log/GetLogFilename.mqh>

#include <ea/functions/metric/GetMT4SymbolDefinition.mqh>

#include <ea/functions/status/CreateStatusBox_6.mqh>
#include <ea/functions/status/ShowOpenOrders.mqh>
#include <ea/functions/status/ShowTradeHistory.mqh>
#include <ea/functions/status/SS.All.mqh>
#include <ea/functions/status/SS.MetricDescription.mqh>
#include <ea/functions/status/SS.OpenLots.mqh>
#include <ea/functions/status/SS.ClosedTrades.mqh>
#include <ea/functions/status/SS.TotalProfit.mqh>
#include <ea/functions/status/SS.ProfitStats.mqh>
#include <ea/functions/status/StatusToStr.mqh>
#include <ea/functions/status/StatusDescription.mqh>

#include <ea/functions/status/file/FindStatusFile.mqh>
#include <ea/functions/status/file/GetStatusFilename.mqh>
#include <ea/functions/status/file/ReadStatus.General.mqh>
#include <ea/functions/status/file/ReadStatus.OpenPosition.mqh>
#include <ea/functions/status/file/ReadStatus.HistoryRecord.mqh>
#include <ea/functions/status/file/ReadStatus.TradeHistory.mqh>
#include <ea/functions/status/file/ReadStatus.TradeStats.mqh>
#include <ea/functions/status/file/SaveStatus.General.mqh>
#include <ea/functions/status/file/SaveStatus.OpenPosition.mqh>
#include <ea/functions/status/file/SaveStatus.TradeHistory.mqh>
#include <ea/functions/status/file/SaveStatus.TradeStats.mqh>

#include <ea/functions/status/volatile/StoreVolatileStatus.mqh>
#include <ea/functions/status/volatile/RestoreVolatileStatus.mqh>
#include <ea/functions/status/volatile/RemoveVolatileStatus.mqh>
#include <ea/functions/status/volatile/ToggleOpenOrders.mqh>
#include <ea/functions/status/volatile/ToggleTradeHistory.mqh>
#include <ea/functions/status/volatile/ToggleMetrics.mqh>

#include <ea/functions/test/ReadTestConfiguration.mqh>

#include <ea/functions/trade/AddHistoryRecord.mqh>
#include <ea/functions/trade/CalculateMagicNumber.mqh>
#include <ea/functions/trade/HistoryRecordToStr.mqh>
#include <ea/functions/trade/IsMyOrder.mqh>

#include <ea/functions/trade/stats/CalculateStats.mqh>

#include <ea/functions/validation/ValidateInputs.ID.mqh>
#include <ea/functions/validation/onInputError.mqh>

// init/deinit
#include <ea/init.mqh>
#include <ea/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!instance.status) return(catch("onTick(1)  illegal instance.status: "+ instance.status, ERR_ILLEGAL_STATE));
   double signal[3];

   if (__isChart) HandleCommands();                   // process incoming commands, may switch on/off the instance

   if (instance.status != STATUS_STOPPED) {
      if (instance.status == STATUS_WAITING) {
         //if (IsStartSignal(signal)) {                                                                                    // trading-time
         //   StartInstance(signal);                                                                                       // keep existing or open new position => STATUS_TRADING
         //}
      }
      else if (instance.status == STATUS_TRADING) {
         UpdateStatus();                              // update client-side status

         //if (IsStopSignal(signal)) {                                                                                     // no-trading-time || daily-stop-limit || total-profit-target
         //   StopInstance(signal);                                                                                        // close all positions => STATUS_WAITING|STATUS_STOPPED
         //}
         //else {                                     // update server-side status
         //   UpdateOpenPositions();                  // add/reduce/reverse position, take (partial) profits
         //   UpdatePendingOrders();                  // update entry and/or exit limits
         //}
      }
      RecordMetrics();
   }
   return(last_error);

   start_old();
}


/**
 * Old start() function
 *
 * @return int - error status
 */
int start_old() {
   static int entryDirection = -1;
   static double entryLevel = 0;

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
         double sl = CalculateStopLoss(entryDirection);
         double tp = CalculateTakeProfit(entryDirection);
         int magicNumber = CalculateMagicNumber(instance.id);

         if (entryDirection == OP_BUY) {
            if (_Ask >= entryLevel) {
               OrderSend(Symbol(), entryDirection, Lots, _Ask, order.slippage, sl, tp, "Rhythm", magicNumber, 0, Blue);
            }
         }
         else {
            if (_Bid <= entryLevel) {
               OrderSend(Symbol(), entryDirection, Lots, _Bid, order.slippage, sl, tp, "Rhythm", magicNumber, 0, Red);
            }
         }
      }

      if (IsOpenPosition()) {                         // selects the ticket
         // find opposite entry level
         if (OrderType() == OP_BUY) entryDirection = OP_SELL;
         else                       entryDirection = OP_BUY;
         sl = NormalizeDouble(OrderStopLoss(), Digits);
         entryLevel = sl;

         // manage StopLoss
         if (TrailingStop) {
            if (OrderType() == OP_BUY) {
               double newSL = NormalizeDouble(OrderClosePrice() - StopLoss*pUnit, Digits);
               if (newSL > sl) {
                  OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), OrderExpiration(), Blue);
                  entryLevel = newSL;
               }
            }
            else {
               newSL = NormalizeDouble(OrderClosePrice() + StopLoss*pUnit, Digits);
               if (newSL < sl) {
                  OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), OrderExpiration(), Red);
                  entryLevel = newSL;
               }
            }
         }
         else if (BreakevenStop) {
            newSL = NormalizeDouble(OrderOpenPrice(), Digits);
            if (newSL != sl) {
               if (OrderType() == OP_BUY) {
                  double triggerPrice = NormalizeDouble(OrderOpenPrice() + StopLoss*pUnit, Digits);
                  if (_Bid > triggerPrice) {                                                                            // TODO: original tests for ">" instead of ">="
                     OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), OrderExpiration(), Blue);
                     entryLevel = newSL;
                  }
               }
               else {
                  triggerPrice = NormalizeDouble(OrderOpenPrice() - StopLoss*pUnit, Digits);
                  if (_Ask < triggerPrice) {                                                                            // TODO: original tests for "<" instead of "<="
                     OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), OrderExpiration(), Blue);
                     entryLevel = newSL;
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
         OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 1);
      }
      entryDirection = -1;
      entryLevel = 0;
   }
   return(last_error);
}


/**
 * Stop a running instance and close open positions (if any).
 *
 * @param  double signal[] - signal infos causing the call
 *
 * @return bool - success status
 */
bool StopInstance(double signal[]) {
   return(!catch("StopInstance(1)", ERR_NOT_IMPLEMENTED));
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

   string section="", file=FindStatusFile(instance.id, instance.isTest);
   if (file == "")                 return(!catch("ReadStatus(2)  "+ instance.name +" status file not found", ERR_RUNTIME_ERROR));
   if (!IsFile(file, MODE_SYSTEM)) return(!catch("ReadStatus(3)  "+ instance.name +" file "+ DoubleQuoteStr(file) +" not found", ERR_FILE_NOT_FOUND));

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

   // detect and handle orphaned open positions
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
   if (!SaveStatus.General(file, fileExists)) return(false);   // account and instrument infos

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

// backed-up runtime variables affected by changing input parameters
int      prev.instance.id;
string   prev.instance.name = "";
datetime prev.instance.created;
bool     prev.instance.isTest;
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
   prev.instance.id      = instance.id;
   prev.instance.name    = instance.name;
   prev.instance.created = instance.created;
   prev.instance.isTest  = instance.isTest;
   prev.instance.status  = instance.status;

   BackupInputs.Recorder();
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
   instance.id      = prev.instance.id;
   instance.name    = prev.instance.name;
   instance.created = prev.instance.created;
   instance.isTest  = prev.instance.isTest;
   instance.status  = prev.instance.status;

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
   if (!Recorder.ValidateInputs(IsTestInstance())) return(false);

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
 * Return a string representation of the input parameters (for logging purposes).
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
