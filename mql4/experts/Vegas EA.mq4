/**
 ****************************************************************************************************************************
 *                                           WORK-IN-PROGRESS, DO NOT YET USE                                               *
 ****************************************************************************************************************************
 *
 * Channel Breakout
 *
 * A combination of ideas from the "Vegas H1 Tunnel" system, the "Turtle Trading" system and a grid for scaling in/out.
 *
 *  @see [Vegas H1 Tunnel Method] https://www.forexfactory.com/thread/4365-all-vegas-documents-located-here
 *  @see [Turtle Trading]         https://analyzingalpha.com/turtle-trading
 *  @see [Turtle Trading]         http://web.archive.org/web/20220417032905/https://vantagepointtrading.com/top-trader-richard-dennis-turtle-trading-strategy/
 *
 *
 * Features
 * --------
 *  • A finished test can be loaded into an online chart for trade inspection and further analysis.
 *
 *  • The EA supports a "virtual trading mode" in which all trades are only emulated. This makes it possible to hide all
 *    trading related deviations that impact test or real results (tester bugs, spread, slippage, swap, commission).
 *    It allows the EA to be tested and adjusted under idealised conditions.
 *
 *  • The EA contains a recorder that can record several performance graphs simultaneously at runtime (also in tester).
 *    These recordings are saved as regular chart symbols in the history directory of a second MT4 terminal. From there they
 *    can be displayed and analysed like regular MT4 symbols.
 *
 *
 * Requirements
 * ------------
 *  • MA Tunnel indicator: @see https://github.com/rosasurfer/mt4-mql/blob/master/mql4/indicators/MA%20Tunnel.mq4
 *  • ZigZag indicator:    @see https://github.com/rosasurfer/mt4-mql/blob/master/mql4/indicators/ZigZag.mq4
 *
 *
 * Input parameters
 * ----------------
 *  • Instance.ID:        ...
 *  • Tunnel.Definition:  ...
 *  • Donchian.Periods:   ...
 *  • Lots:               ...
 *  • EA.Recorder:        Metrics to record, for syntax @see https://github.com/rosasurfer/mt4-mql/blob/master/mql4/include/core/expert.recorder.mqh
 *
 *     1: Records PnL after all costs in account currency (net).
 *     2: Records PnL after all costs in price units (net).
 *     3: Records PnL before spread/any costs in price units (synthetic, exact execution).
 *
 *     Metrics in price units are recorded in the best matching unit. That's pip for Forex or full points otherwise.
 *
 *
 * External control
 * ----------------
 * The EA can be controlled via execution of the following scripts (online and in tester):
 *  • EA.Stop
 *  • EA.Restart
 *  • EA.ToggleMetrics
 *  • Chart.ToggleOpenOrders
 *  • Chart.ToggleTradeHistory
 *
 *
 *
 * TODO:
 *  - add break-even stop
 *  - add exit strategies
 *  - add entry strategies
 *  - add virtual trading
 *  - add input "TradingTimeframe"
 *  - document input params, control scripts and general usage
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 0;

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID          = "";                             // instance to load from a status file, format "[T]123"
extern string Tunnel.Definition    = "EMA(9), EMA(36), EMA(144)";    // one or more MA definitions separated by comma
extern string Supported.MA.Methods = "SMA, LWMA, EMA, SMMA";
extern int    Donchian.Periods     = 30;
extern double Lots                 = 1.0;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/IsBarOpen.mqh>
#include <functions/iCustom/MaTunnel.mqh>
#include <functions/iCustom/ZigZag.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define STRATEGY_ID            108                 // unique strategy id (used for magic order numbers)

#define INSTANCE_ID_MIN          1                 // range of valid instance ids
#define INSTANCE_ID_MAX        999                 //

#define STATUS_WAITING           1                 // instance has no open positions and waits for trade signals
#define STATUS_PROGRESSING       2                 // instance manages open positions
#define STATUS_STOPPED           3                 // instance has no open positions and doesn't wait for trade signals

#define SIGNAL_LONG  TRADE_DIRECTION_LONG          // 1 signal types
#define SIGNAL_SHORT TRADE_DIRECTION_SHORT         // 2

#define H_TICKET                 0                 // trade history indexes
#define H_OPENTYPE               1
#define H_LOTS                   2
#define H_OPENTIME               3
#define H_OPENPRICE              4
#define H_OPENPRICE_VIRT         5
#define H_CLOSETIME              6
#define H_CLOSEPRICE             7
#define H_CLOSEPRICE_VIRT        8
#define H_SLIPPAGE               9
#define H_SWAP                  10
#define H_COMMISSION            11
#define H_GROSSPROFIT           12
#define H_NETPROFIT             13
#define H_NETPROFIT_P           14
#define H_VIRTPROFIT_P          15

#define METRIC_TOTAL_NET_MONEY   1                 // custom metrics
#define METRIC_TOTAL_NET_UNITS   2
#define METRIC_TOTAL_VIRT_UNITS  3

#define METRIC_NEXT              1                 // directions for toggling between metrics
#define METRIC_PREVIOUS         -1

// instance data
int      instance.id;                              // used for magic order numbers
string   instance.name = "";
datetime instance.created;
int      instance.status;
bool     instance.isTest;

double   instance.openNetProfit;                   // real PnL in money after all costs (net)
double   instance.closedNetProfit;
double   instance.totalNetProfit;
double   instance.maxNetProfit;                    // max. observed profit:   0...+n
double   instance.maxNetDrawdown;                  // max. observed drawdown: -n...0
double   instance.avgNetProfit = EMPTY_VALUE;

double   instance.openNetProfitP;                  // PnL in point after all costs (net)
double   instance.closedNetProfitP;
double   instance.totalNetProfitP;
double   instance.maxNetProfitP;
double   instance.maxNetDrawdownP;
double   instance.avgNetProfitP = EMPTY_VALUE;

double   instance.openVirtProfitP;                 // virtual PnL in point without any costs (assumes exact execution)
double   instance.closedVirtProfitP;
double   instance.totalVirtProfitP;
double   instance.maxVirtProfitP;
double   instance.maxVirtDrawdownP;
double   instance.avgVirtProfitP = EMPTY_VALUE;

// order data
int      open.ticket;                              // one open position
int      open.type;
double   open.lots;
datetime open.time;
double   open.price;
double   open.priceVirt;
double   open.slippage;
double   open.swap;
double   open.commission;
double   open.grossProfit;
double   open.netProfit;
double   open.netProfitP;
double   open.virtProfitP;
double   history[][16];                            // multiple closed positions

// volatile status data
int      status.activeMetric = 1;
bool     status.showOpenOrders;
bool     status.showTradeHistory;

// other
string   pUnit = "";
int      pDigits;
int      pMultiplier;
int      orders.acceptableSlippage = 1;            // in MQL points

// cache vars to speed-up ShowStatus()
string   sMetric       = "";
string   sOpenLots     = "";
string   sClosedTrades = "";
string   sTotalProfit  = "";
string   sProfitStats  = "";

// debug settings                                  // configurable via framework config, see afterInit()
bool     test.onStopPause        = false;          // whether to pause a test after StopInstance()
bool     test.reduceStatusWrites = true;           // whether to reduce status file I/O in tester

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
      RecordMetrics();
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

   if (cmd == "stop") {
      switch (instance.status) {
         case STATUS_WAITING:
         case STATUS_PROGRESSING:
            logInfo("onCommand(1)  "+ instance.name +" "+ DoubleQuoteStr(fullCmd));
            return(StopInstance());
      }
   }

   else if (cmd == "restart") {
      switch (instance.status) {
         case STATUS_STOPPED:
            logInfo("onCommand(2)  "+ instance.name +" "+ DoubleQuoteStr(fullCmd));
            return(RestartInstance());
      }
   }

   else if (cmd == "toggle-metrics") {
      int direction = ifInt(keys & F_VK_SHIFT, METRIC_PREVIOUS, METRIC_NEXT);
      return(ToggleMetrics(direction));
   }

   else if (cmd == "toggle-open-orders") {
      return(ToggleOpenOrders());
   }

   else if (cmd == "toggle-trade-history") {
      return(ToggleTradeHistory());
   }
   else return(!logNotice("onCommand(3)  "+ instance.name +" unsupported command: "+ DoubleQuoteStr(fullCmd)));

   return(!logWarn("onCommand(4)  "+ instance.name +" cannot execute command "+ DoubleQuoteStr(fullCmd) +" in status "+ StatusToStr(instance.status)));
}


/**
 * Toggle EA status between displayed metrics.
 *
 * @param  int direction - METRIC_NEXT|METRIC_PREVIOUS
 *
 * @return bool - success status
 */
bool ToggleMetrics(int direction) {
   if (direction!=METRIC_NEXT && direction!=METRIC_PREVIOUS) return(!catch("ToggleMetrics(1)  "+ instance.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   int lastMetric = status.activeMetric;

   status.activeMetric += direction;
   if (status.activeMetric < 1) status.activeMetric = 3;    // valid metrics: 1-3
   if (status.activeMetric > 3) status.activeMetric = 1;
   StoreVolatileData();
   SS.All();

   if (lastMetric==METRIC_TOTAL_VIRT_UNITS || status.activeMetric==METRIC_TOTAL_VIRT_UNITS) {
      if (status.showOpenOrders) {
         ToggleOpenOrders(false);
         ToggleOpenOrders(false);
      }
      if (status.showTradeHistory) {
         ToggleTradeHistory(false);
         ToggleTradeHistory(false);
      }
   }
   return(true);
}


/**
 * Toggle the display of open orders.
 *
 * @param  bool soundOnNone [optional] - whether to play a sound if no open orders exist (default: yes)
 *
 * @return bool - success status
 */
bool ToggleOpenOrders(bool soundOnNone = true) {
   soundOnNone = soundOnNone!=0;

   // toggle current status
   bool showOrders = !status.showOpenOrders;

   // ON: display open orders
   if (showOrders) {
      string types[] = {"buy", "sell"};
      color clrs[] = {CLR_OPEN_LONG, CLR_OPEN_SHORT};

      if (open.ticket != NULL) {
         double openPrice = ifDouble(status.activeMetric == METRIC_TOTAL_VIRT_UNITS, open.priceVirt, open.price);
         string label = StringConcatenate("#", open.ticket, " ", types[open.type], " ", NumberToStr(open.lots, ".+"), " at ", NumberToStr(openPrice, PriceFormat));

         if (ObjectFind(label) == -1) if (!ObjectCreate(label, OBJ_ARROW, 0, 0, 0)) return(!catch("ToggleOpenOrders(1)", intOr(GetLastError(), ERR_RUNTIME_ERROR)));
         ObjectSet    (label, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet    (label, OBJPROP_COLOR,  clrs[open.type]);
         ObjectSet    (label, OBJPROP_TIME1,  open.time);
         ObjectSet    (label, OBJPROP_PRICE1, openPrice);
         ObjectSetText(label, instance.name);
      }
      else {
         showOrders = false;                          // Without open orders status must be reset to have the "off" section
         if (soundOnNone) PlaySoundEx("Plonk.wav");   // remove any existing open order markers.
      }
   }

   // OFF: remove open order markers
   if (!showOrders) {
      for (int i=ObjectsTotal()-1; i >= 0; i--) {
         label = ObjectName(i);

         if (StringGetChar(label, 0) == '#') {
            if (ObjectType(label) == OBJ_ARROW) {
               int arrow = ObjectGet(label, OBJPROP_ARROWCODE);
               color clr = ObjectGet(label, OBJPROP_COLOR);

               if (arrow == SYMBOL_ORDEROPEN) {
                  if (clr!=CLR_OPEN_LONG && clr!=CLR_OPEN_SHORT) continue;
               }
               else if (arrow == SYMBOL_ORDERCLOSE) {
                  if (clr!=CLR_OPEN_TAKEPROFIT && clr!=CLR_OPEN_STOPLOSS) continue;
               }
               ObjectDelete(label);
            }
         }
      }
   }

   // store current status
   status.showOpenOrders = showOrders;
   StoreVolatileData();

   if (__isTesting) WindowRedraw();
   return(!catch("ToggleOpenOrders(2)"));
}


/**
 * Toggle the display of closed trades.
 *
 * @param  bool soundOnNone [optional] - whether to play a sound if no closed trades exist (default: yes)
 *
 * @return bool - success status
 */
bool ToggleTradeHistory(bool soundOnNone = true) {
   soundOnNone = soundOnNone!=0;
   // toggle current status
   bool showHistory = !status.showTradeHistory;

   // ON: display closed trades
   if (showHistory) {
      int trades = ShowTradeHistory();
      if (trades == -1) return(false);
      if (!trades) {                                        // Without any closed trades the status must be reset to enable
         showHistory = false;                               // the "off" section to clear existing markers.
         if (soundOnNone) PlaySoundEx("Plonk.wav");
      }
   }

   // OFF: remove all closed trade markers (from this EA or another program)
   if (!showHistory) {
      for (int i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);

         if (StringGetChar(name, 0) == '#') {
            if (ObjectType(name) == OBJ_ARROW) {
               int arrow = ObjectGet(name, OBJPROP_ARROWCODE);
               color clr = ObjectGet(name, OBJPROP_COLOR);

               if (arrow == SYMBOL_ORDEROPEN) {
                  if (clr!=CLR_CLOSED_LONG && clr!=CLR_CLOSED_SHORT) continue;
               }
               else if (arrow == SYMBOL_ORDERCLOSE) {
                  if (clr!=CLR_CLOSED) continue;
               }
            }
            else if (ObjectType(name) != OBJ_TREND) continue;
            ObjectDelete(name);
         }
      }
   }

   // store current status
   status.showTradeHistory = showHistory;
   StoreVolatileData();

   if (__isTesting) WindowRedraw();
   return(!catch("ToggleTradeHistory(1)"));
}


/**
 * Display closed trades.
 *
 * @return int - number of displayed trades or EMPTY (-1) in case of errors
 */
int ShowTradeHistory() {
   string openLabel="", lineLabel="", closeLabel="", sOpenPrice="", sClosePrice="", sOperations[]={"buy", "sell"};
   int iOpenColors[]={CLR_CLOSED_LONG, CLR_CLOSED_SHORT}, iLineColors[]={Blue, Red};

   // process the local trade history
   int orders = ArrayRange(history, 0), closedTrades = 0;

   for (int i=0; i < orders; i++) {
      int      ticket     = history[i][H_TICKET    ];
      int      type       = history[i][H_OPENTYPE  ];
      double   lots       = history[i][H_LOTS      ];
      datetime openTime   = history[i][H_OPENTIME  ];
      double   openPrice  = history[i][H_OPENPRICE ];
      datetime closeTime  = history[i][H_CLOSETIME ];
      double   closePrice = history[i][H_CLOSEPRICE];

      if (status.activeMetric == METRIC_TOTAL_VIRT_UNITS) {
         openPrice  = history[i][H_OPENPRICE_VIRT ];
         closePrice = history[i][H_CLOSEPRICE_VIRT];
      }
      if (!closeTime)                    continue;             // skip open tickets (should not happen)
      if (type!=OP_BUY && type!=OP_SELL) continue;             // skip non-trades   (should not happen)

      sOpenPrice  = NumberToStr(openPrice, PriceFormat);
      sClosePrice = NumberToStr(closePrice, PriceFormat);

      // open marker
      openLabel = StringConcatenate("#", ticket, " ", sOperations[type], " ", NumberToStr(lots, ".+"), " at ", sOpenPrice);
      if (ObjectFind(openLabel) == -1) ObjectCreate(openLabel, OBJ_ARROW, 0, 0, 0);
      ObjectSet    (openLabel, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
      ObjectSet    (openLabel, OBJPROP_COLOR,  iOpenColors[type]);
      ObjectSet    (openLabel, OBJPROP_TIME1,  openTime);
      ObjectSet    (openLabel, OBJPROP_PRICE1, openPrice);
      ObjectSetText(openLabel, instance.name);

      // trend line
      lineLabel = StringConcatenate("#", ticket, " ", sOpenPrice, " -> ", sClosePrice);
      if (ObjectFind(lineLabel) == -1) ObjectCreate(lineLabel, OBJ_TREND, 0, 0, 0, 0, 0);
      ObjectSet(lineLabel, OBJPROP_RAY,    false);
      ObjectSet(lineLabel, OBJPROP_STYLE,  STYLE_DOT);
      ObjectSet(lineLabel, OBJPROP_COLOR,  iLineColors[type]);
      ObjectSet(lineLabel, OBJPROP_BACK,   true);
      ObjectSet(lineLabel, OBJPROP_TIME1,  openTime);
      ObjectSet(lineLabel, OBJPROP_PRICE1, openPrice);
      ObjectSet(lineLabel, OBJPROP_TIME2,  closeTime);
      ObjectSet(lineLabel, OBJPROP_PRICE2, closePrice);

      // close marker
      closeLabel = StringConcatenate(openLabel, " close at ", sClosePrice);
      if (ObjectFind(closeLabel) == -1) ObjectCreate(closeLabel, OBJ_ARROW, 0, 0, 0);
      ObjectSet    (closeLabel, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
      ObjectSet    (closeLabel, OBJPROP_COLOR,  CLR_CLOSED);
      ObjectSet    (closeLabel, OBJPROP_TIME1,  closeTime);
      ObjectSet    (closeLabel, OBJPROP_PRICE1, closePrice);
      ObjectSetText(closeLabel, instance.name);
      closedTrades++;
   }

   if (!catch("ShowTradeHistory(1)"))
      return(closedTrades);
   return(EMPTY);
}


/**
 * Whether a trade signal occurred.
 *
 * @param  _Out_ int &signal - variable receiving the signal identifier of a triggered condition
 *
 * @return bool
 */
bool IsTradeSignal(int &signal) {
   signal = NULL;
   if (last_error != NULL) return(false);

   // MA Tunnel signal ------------------------------------------------------------------------------------------------------
   if (IsMaTunnelSignal(signal)) {
      return(true);
   }

   // ZigZag signal ---------------------------------------------------------------------------------------------------------
   if (false) /*&&*/ if (IsZigZagSignal(signal)) {
      return(true);
   }
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

   static int lastTick, lastResult;

   if (Ticks == lastTick) {
      signal = lastResult;
   }
   else {
      if (IsBarOpen()) {
         int trend = icMaTunnel(NULL, Tunnel.Definition, MaTunnel.MODE_BAR_TREND, 1);
         if      (trend == +1) signal = SIGNAL_LONG;
         else if (trend == -1) signal = SIGNAL_SHORT;

         if (signal != NULL) {
            if (IsLogNotice()) logNotice("IsMaTunnelSignal(1)  "+ instance.name +" "+ ifString(signal==SIGNAL_LONG, "long", "short") +" crossing (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         }
      }
      lastTick = Ticks;
      lastResult = signal;
   }
   return(signal != NULL);
}


/**
 * Whether a new ZigZag reversal occurred.
 *
 * @param  _Out_ int &signal - variable receiving the signal identifier: SIGNAL_LONG | SIGNAL_SHORT
 *
 * @return bool
 */
bool IsZigZagSignal(int &signal) {
   if (last_error != NULL) return(false);
   signal = NULL;

   static int lastTick, lastResult, lastSignal, lastSignalBar;
   int trend, reversal;

   if (Ticks == lastTick) {
      signal = lastResult;
   }
   else {
      // TODO: error on triple-crossing at bar 0 or 1
      //  - extension down, then reversal up, then reversal down           e.g. ZigZag(20), GBPJPY,M5 2023.12.18 00:00
      if (!GetZigZagData(0, trend, reversal)) return(!logError("IsZigZagSignal(1)  "+ instance.name +" GetZigZagData() => FALSE", ERR_RUNTIME_ERROR));
      int absTrend = Abs(trend);

      // The same value denotes a regular reversal, reversal==0 && absTrend==1 denotes a double crossing.
      if (absTrend==reversal || (!reversal && absTrend==1)) {
         if (trend > 0) signal = SIGNAL_LONG;
         else           signal = SIGNAL_SHORT;

         if (Time[0]==lastSignalBar && signal==lastSignal) {
            signal = NULL;
         }
         else {
            if (IsLogNotice()) logNotice("IsZigZagSignal(2)  "+ instance.name +" "+ ifString(signal==SIGNAL_LONG, "long", "short") +" reversal (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            lastSignal = signal;
            lastSignalBar = Time[0];
         }
      }
      lastTick = Ticks;
      lastResult = signal;
   }
   return(signal != NULL);
}


/**
 * Get ZigZag data at the specified bar offset.
 *
 * @param  _In_  int bar       - bar offset
 * @param  _Out_ int &trend    - combined trend value (buffers MODE_KNOWN_TREND + MODE_UNKNOWN_TREND)
 * @param  _Out_ int &reversal - bar offset of current ZigZag reversal to previous ZigZag extreme
 *
 * @return bool - success status
 */
bool GetZigZagData(int bar, int &trend, int &reversal) {
   trend    = MathRound(icZigZag(NULL, Donchian.Periods, ZigZag.MODE_TREND,    bar));
   reversal = MathRound(icZigZag(NULL, Donchian.Periods, ZigZag.MODE_REVERSAL, bar));
   return(!last_error && trend);
}


/**
 * Update order status and PL stats.
 *
 * @param  int signal [optional] - trade signal causing the call (default: none, update status only)
 *
 * @return bool - success status
 */
bool UpdateStatus(int signal = NULL) {
   if (last_error != NULL)                                                     return(false);
   if (instance.status!=STATUS_WAITING && instance.status!=STATUS_PROGRESSING) return(!catch("UpdateStatus(1)  "+ instance.name +" illegal instance status "+ StatusToStr(instance.status), ERR_ILLEGAL_STATE));
   bool positionClosed = false;

   // update open position
   if (open.ticket != NULL) {
      if (!SelectTicket(open.ticket, "UpdateStatus(2)")) return(false);
      open.swap        = NormalizeDouble(OrderSwap(), 2);
      open.commission  = OrderCommission();
      open.grossProfit = OrderProfit();
      open.netProfit   = open.grossProfit + open.swap + open.commission;
      open.netProfitP  = ifDouble(!open.type, Bid-open.price, open.price-Ask); if (open.swap!=0 || open.commission!=0) open.netProfitP += (open.swap + open.commission)/PointValue(open.lots);
      open.virtProfitP = ifDouble(!open.type, Bid-open.priceVirt, open.priceVirt-Bid);

      if (OrderCloseTime() != NULL) {
         int error;
         if (IsError(onPositionClose("UpdateStatus(3)  "+ instance.name +" "+ UpdateStatus.PositionCloseMsg(error), error))) return(false);
         if (!MoveCurrentPositionToHistory(OrderCloseTime(), OrderClosePrice(), OrderClosePrice()))                          return(false);
         positionClosed = true;
      }
   }

   // process signal
   if (signal != NULL) {
      instance.status = STATUS_PROGRESSING;

      // close an existing open position
      if (open.ticket != NULL) {
         if (open.type != ifInt(signal==SIGNAL_SHORT, OP_LONG, OP_SHORT)) return(!catch("UpdateStatus(4)  "+ instance.name +" cannot process "+ SignalToStr(signal) +" with open "+ OperationTypeToStr(open.type) +" position", ERR_ILLEGAL_STATE));

         int oeFlags, oe[];
         if (!OrderCloseEx(open.ticket, NULL, NULL, CLR_CLOSED, oeFlags, oe)) return(!SetLastError(oe.Error(oe)));
         open.slippage += oe.Slippage(oe);
         if (!MoveCurrentPositionToHistory(oe.CloseTime(oe), oe.ClosePrice(oe), Bid)) return(false);
      }

      // open new position
      int      type        = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL);
      double   price       = NULL;
      double   stopLoss    = NULL;
      double   takeProfit  = NULL;
      string   comment     = "Vegas."+ StrPadLeft(instance.id, 3, "0");
      int      magicNumber = CalculateMagicNumber();
      datetime expires     = NULL;
      color    markerColor = ifInt(signal==SIGNAL_LONG, CLR_OPEN_LONG, CLR_OPEN_SHORT);
               oeFlags     = NULL;

      int ticket = OrderSendEx(NULL, type, Lots, price, orders.acceptableSlippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
      if (!ticket) return(!SetLastError(oe.Error(oe)));

      // store the new position
      open.ticket      = ticket;
      open.type        = type;
      open.lots        = oe.Lots(oe); SS.OpenLots();
      open.time        = oe.OpenTime(oe);
      open.price       = oe.OpenPrice(oe);
      open.priceVirt   = Bid;
      open.slippage    = oe.Slippage(oe);
      open.swap        = oe.Swap(oe);
      open.commission  = oe.Commission(oe);
      open.grossProfit = oe.Profit(oe);
      open.netProfit   = open.grossProfit + open.swap + open.commission;
      open.netProfitP  = ifDouble(!open.type, Bid-open.price, open.price-Ask); if (open.swap!=0 || open.commission!=0) open.netProfitP += (open.swap + open.commission)/PointValue(open.lots);
      open.virtProfitP = 0;
   }

   // update PL numbers
   instance.openNetProfit   = open.netProfit;
   instance.openNetProfitP  = open.netProfitP;
   instance.openVirtProfitP = open.virtProfitP;

   instance.totalNetProfit   = instance.openNetProfit   + instance.closedNetProfit;
   instance.totalNetProfitP  = instance.openNetProfitP  + instance.closedNetProfitP;
   instance.totalVirtProfitP = instance.openVirtProfitP + instance.closedVirtProfitP;
   SS.TotalProfit();

   bool updateStats = false;
   if      (instance.totalNetProfit   > instance.maxNetProfit    ) { instance.maxNetProfit     = instance.totalNetProfit;   updateStats = true; }
   else if (instance.totalNetProfit   < instance.maxNetDrawdown  ) { instance.maxNetDrawdown   = instance.totalNetProfit;   updateStats = true; }

   if      (instance.totalNetProfitP  > instance.maxNetProfitP   ) { instance.maxNetProfitP    = instance.totalNetProfitP;  updateStats = true; }
   else if (instance.totalNetProfitP  < instance.maxNetDrawdownP ) { instance.maxNetDrawdownP  = instance.totalNetProfitP;  updateStats = true; }

   if      (instance.totalVirtProfitP > instance.maxVirtProfitP  ) { instance.maxVirtProfitP   = instance.totalVirtProfitP; updateStats = true; }
   else if (instance.totalVirtProfitP < instance.maxVirtDrawdownP) { instance.maxVirtDrawdownP = instance.totalVirtProfitP; updateStats = true; }
   if (updateStats) SS.ProfitStats();

   if (positionClosed || signal)
      return(SaveStatus());
   return(!catch("UpdateStatus(5)"));
}


/**
 * Compose a log message for a closed position. The ticket must be selected.
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

         open.slippage   += oe.Slippage  (oe);
         open.swap        = oe.Swap      (oe);
         open.commission  = oe.Commission(oe);
         open.grossProfit = oe.Profit    (oe);
         open.netProfit   = open.grossProfit + open.swap + open.commission;
         open.netProfitP  = ifDouble(!open.type, oe.ClosePrice(oe)-open.price, open.price-oe.ClosePrice(oe)) + (open.swap + open.commission)/PointValue(open.lots);
         open.virtProfitP = ifDouble(!open.type, Bid-open.priceVirt, open.priceVirt-Bid);
         if (!MoveCurrentPositionToHistory(oe.CloseTime(oe), oe.ClosePrice(oe), Bid)) return(false);

         // update PL numbers
         instance.openNetProfit  = open.netProfit;
         instance.totalNetProfit = instance.openNetProfit + instance.closedNetProfit;
         instance.maxNetProfit   = MathMax(instance.maxNetProfit,   instance.totalNetProfit);
         instance.maxNetDrawdown = MathMin(instance.maxNetDrawdown, instance.totalNetProfit);

         instance.openNetProfitP  = open.netProfitP;
         instance.totalNetProfitP = instance.openNetProfitP + instance.closedNetProfitP;
         instance.maxNetProfitP   = MathMax(instance.maxNetProfitP,   instance.totalNetProfitP);
         instance.maxNetDrawdownP = MathMin(instance.maxNetDrawdownP, instance.totalNetProfitP);

         instance.openVirtProfitP  = open.virtProfitP;
         instance.totalVirtProfitP = instance.openVirtProfitP + instance.closedVirtProfitP;
         instance.maxVirtProfitP   = MathMax(instance.maxVirtProfitP,   instance.totalVirtProfitP);
         instance.maxVirtDrawdownP = MathMin(instance.maxVirtDrawdownP, instance.totalVirtProfitP);
         SS.TotalProfit();
         SS.ProfitStats();
      }
   }

   // update status
   instance.status = STATUS_STOPPED;
   if (IsLogInfo()) logInfo("StopInstance(3)  "+ instance.name +" "+ ifString(__isTesting, "test ", "") +"instance stopped, profit: "+ sTotalProfit +" "+ sProfitStats);
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
 * Move the current open position to the trade history. Assumes the position is closed.
 *
 * @param datetime closeTime      - close time
 * @param double   closePrice     - close price
 * @param double   closePriceVirt - virtual close price
 *
 * @return bool - success status
 */
bool MoveCurrentPositionToHistory(datetime closeTime, double closePrice, double closePriceVirt) {
   if (last_error != NULL)                    return(false);
   if (instance.status != STATUS_PROGRESSING) return(!catch("MoveCurrentPositionToHistory(1)  "+ instance.name +" cannot process current position of "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   if (!open.ticket)                          return(!catch("MoveCurrentPositionToHistory(2)  "+ instance.name +" no open position found (open.ticket=NULL)", ERR_ILLEGAL_STATE));

   // update position data
   open.virtProfitP = ifDouble(!open.type, closePriceVirt-open.priceVirt, open.priceVirt-closePriceVirt);

   // add data to history
   int i = ArrayRange(history, 0);
   ArrayResize(history, i+1);
   history[i][H_TICKET         ] = open.ticket;
   history[i][H_OPENTYPE       ] = open.type;
   history[i][H_LOTS           ] = open.lots;
   history[i][H_OPENTIME       ] = open.time;
   history[i][H_OPENPRICE      ] = open.price;
   history[i][H_OPENPRICE_VIRT ] = open.priceVirt;
   history[i][H_CLOSETIME      ] = closeTime;
   history[i][H_CLOSEPRICE     ] = closePrice;
   history[i][H_CLOSEPRICE_VIRT] = closePriceVirt;
   history[i][H_SLIPPAGE       ] = open.slippage;
   history[i][H_SWAP           ] = open.swap;
   history[i][H_COMMISSION     ] = open.commission;
   history[i][H_GROSSPROFIT    ] = open.grossProfit;
   history[i][H_NETPROFIT      ] = open.netProfit;
   history[i][H_NETPROFIT_P    ] = open.netProfitP;
   history[i][H_VIRTPROFIT_P   ] = open.virtProfitP;

   // update PL numbers
   instance.openNetProfit   = 0;
   instance.openNetProfitP  = 0;
   instance.openVirtProfitP = 0;

   instance.closedNetProfit   += open.netProfit;
   instance.closedNetProfitP  += open.netProfitP;
   instance.closedVirtProfitP += open.virtProfitP;

   // reset open position data
   open.ticket      = NULL;
   open.type        = NULL;
   open.lots        = NULL;
   open.time        = NULL;
   open.price       = NULL;
   open.priceVirt   = NULL;
   open.slippage    = NULL;
   open.swap        = NULL;
   open.commission  = NULL;
   open.grossProfit = NULL;
   open.netProfit   = NULL;
   open.netProfitP  = NULL;
   open.virtProfitP = NULL;
   SS.OpenLots();

   // update trade stats
   CalculateTradeStats();
   SS.ClosedTrades();

   return(!catch("MoveCurrentPositionToHistory(3)"));
}


/**
 * Update trade statistics.
 */
void CalculateTradeStats() {
   static int lastSize = 0;
   static double sumNetProfit=0, sumNetProfitP=0, sumVirtProfitP=0;

   int size = ArrayRange(history, 0);

   if (!size || size < lastSize) {
      sumNetProfit   = 0;
      sumNetProfitP  = 0;
      sumVirtProfitP = 0;
      instance.avgNetProfit   = EMPTY_VALUE;
      instance.avgNetProfitP  = EMPTY_VALUE;
      instance.avgVirtProfitP = EMPTY_VALUE;
      lastSize = 0;
   }

   if (size > lastSize) {
      for (int i=lastSize; i < size; i++) {                 // speed-up by processing only new history entries
         sumNetProfit   += history[i][H_NETPROFIT   ];
         sumNetProfitP  += history[i][H_NETPROFIT_P ];
         sumVirtProfitP += history[i][H_VIRTPROFIT_P];
      }
      instance.avgNetProfit   = sumNetProfit/size;
      instance.avgNetProfitP  = sumNetProfitP/size;
      instance.avgVirtProfitP = sumVirtProfitP/size;
      lastSize = size;
   }
}


/**
 * Whether the current instance was created in the tester. Also returns TRUE if a finished test is loaded into an online chart.
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
   if (STRATEGY_ID < 101 || STRATEGY_ID > 1023)      return(!catch("CalculateMagicNumber(1)  "+ instance.name +" illegal strategy id: "+ STRATEGY_ID, ERR_ILLEGAL_STATE));
   int id = intOr(instanceId, instance.id);
   if (id < INSTANCE_ID_MIN || id > INSTANCE_ID_MAX) return(!catch("CalculateMagicNumber(2)  "+ instance.name +" illegal instance id: "+ id, ERR_ILLEGAL_STATE));

   int strategy = STRATEGY_ID;                              // 101-1023 (10 bit)
   int instance = id;                                       // 001-999  (14 bit, used to be 1000-9999)

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
 * Generate a new instance id. Unique for all instances per symbol (instances of different symbols may use the same id).
 *
 * @return int - instance id in the range of 100-999 or NULL (0) in case of errors
 */
int CreateInstanceId() {
   int instanceId, magicNumber;
   MathSrand(GetTickCount()-__ExecutionContext[EC.hChartWindow]);

   if (__isTesting) {
      // generate next consecutive id from already recorded metrics
      string nextSymbol = Recorder.GetNextMetricSymbol(); if (nextSymbol == "") return(NULL);
      string sCounter = StrRightFrom(nextSymbol, ".", -1);
      if (!StrIsDigits(sCounter)) return(!catch("CreateInstanceId(1)  "+ instance.name +" illegal value for next symbol "+ DoubleQuoteStr(nextSymbol) +" (doesn't end with 3 digits)", ERR_ILLEGAL_STATE));
      int nextMetricId = MathMax(INSTANCE_ID_MIN, StrToInteger(sCounter));

      if (recorder.mode == RECORDER_OFF) {
         int minInstanceId = MathCeil(nextMetricId + 0.2*(INSTANCE_ID_MAX-nextMetricId)); // nextMetricId + 20% of remaining range (leave 20% of range empty for tests with metrics)
         while (instanceId < minInstanceId || instanceId > INSTANCE_ID_MAX) {             // select random id between <minInstanceId> and ID_MAX
            instanceId = MathRand();
         }
      }
      else {
         instanceId = nextMetricId;                                                       // use next metric id
      }
   }
   else {
      // online: generate random id
      while (!magicNumber) {
         // generate a new instance id
         while (instanceId < INSTANCE_ID_MIN || instanceId > INSTANCE_ID_MAX) {
            instanceId = MathRand();                                                      // select random id between ID_MIN and ID_MAX
         }
         magicNumber = CalculateMagicNumber(instanceId); if (!magicNumber) return(NULL);

         // test for uniqueness against open orders
         int openOrders = OrdersTotal();
         for (int i=0; i < openOrders; i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) return(!catch("CreateInstanceId(2)  "+ instance.name, intOr(GetLastError(), ERR_RUNTIME_ERROR)));
            if (OrderMagicNumber() == magicNumber) {
               magicNumber = NULL;
               break;
            }
         }
         if (!magicNumber) continue;

         // test for uniqueness against closed orders
         int closedOrders = OrdersHistoryTotal();
         for (i=0; i < closedOrders; i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) return(!catch("CreateInstanceId(3)  "+ instance.name, intOr(GetLastError(), ERR_RUNTIME_ERROR)));
            if (OrderMagicNumber() == magicNumber) {
               magicNumber = NULL;
               break;
            }
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
   if (iValue < INSTANCE_ID_MIN || iValue > INSTANCE_ID_MAX) {
      error = true;
      if (muteErrors) return(!SetLastError(ERR_INVALID_PARAMETER));
      return(!catch(caller +"->SetInstanceId(2)  invalid instance id value: \""+ valueBak +"\" (range error)", ERR_INVALID_PARAMETER));
   }

   instance.isTest = isTest;
   instance.id     = iValue;
   Instance.ID     = ifString(IsTestInstance(), "T", "") + StrPadLeft(instance.id, 3, "0");
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
 * Read the status file of an instance and restore inputs and runtime variables. Called only from RestoreInstance().
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
   string sAccount     = GetIniStringA(file, section, "Account",     "");                       // string Account     = ICMarkets:12345678 (demo)
   string sThisAccount = GetAccountCompanyId() +":"+ GetAccountNumber();
   string sRealSymbol  = GetIniStringA(file, section, "Symbol",      "");                       // string Symbol      = EURUSD
   string sTestSymbol  = GetIniStringA(file, section, "Test.Symbol", "");                       // string Test.Symbol = EURUSD
   if (sTestSymbol == "") {
      if (!StrCompareI(StrLeftTo(sAccount, " ("), sThisAccount)) return(!catch("ReadStatus(4)  "+ instance.name +" account mis-match: "+ DoubleQuoteStr(sThisAccount) +" vs. "+ DoubleQuoteStr(sAccount) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));
      if (!StrCompareI(sRealSymbol, Symbol()))                   return(!catch("ReadStatus(5)  "+ instance.name +" symbol mis-match: "+ DoubleQuoteStr(Symbol()) +" vs. "+ DoubleQuoteStr(sRealSymbol) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));
   }
   else {
      if (!StrCompareI(sTestSymbol, Symbol()))                   return(!catch("ReadStatus(6)  "+ instance.name +" symbol mis-match: "+ DoubleQuoteStr(Symbol()) +" vs. "+ DoubleQuoteStr(sTestSymbol) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_CONFIG_VALUE));
   }

   // [Inputs]
   section = "Inputs";
   string sInstanceID         = GetIniStringA(file, section, "Instance.ID",       "");          // string Instance.ID       = T123
   string sTunnelDefinition   = GetIniStringA(file, section, "Tunnel.Definition", "");          // string Tunnel.Definition = EMA(1), EMA(2), EMA(3)
   int    iDonchianPeriods    = GetIniInt    (file, section, "Donchian.Periods"     );          // int    Donchian.Periods  = 40
   string sLots               = GetIniStringA(file, section, "Lots",              "");          // double Lots              = 0.1
   string sEaRecorder         = GetIniStringA(file, section, "EA.Recorder",       "");          // string EA.Recorder       = 1,2,4

   if (!StrIsNumeric(sLots)) return(!catch("ReadStatus(7)  "+ instance.name +" invalid input parameter Lots "+ DoubleQuoteStr(sLots) +" in status file "+ DoubleQuoteStr(file), ERR_INVALID_FILE_FORMAT));

   Instance.ID       = sInstanceID;
   Tunnel.Definition = sTunnelDefinition;
   Donchian.Periods  = iDonchianPeriods;
   Lots              = StrToDouble(sLots);
   EA.Recorder       = sEaRecorder;

   // [Runtime status]
   section = "Runtime status";
   recorder.stdEquitySymbol   = GetIniStringA(file, section, "recorder.stdEquitySymbol", "");   // string   recorder.stdEquitySymbol = GBPJPY.001

   // instance data
   instance.id                = GetIniInt    (file, section, "instance.id"      );              // int      instance.id                = 123
   instance.name              = GetIniStringA(file, section, "instance.name", "");              // string   instance.name              = V.123
   instance.created           = GetIniInt    (file, section, "instance.created" );              // datetime instance.created           = 1624924800 (Mon, 2021.05.12 13:22:34)
   instance.isTest            = GetIniBool   (file, section, "instance.isTest"  );              // bool     instance.isTest            = 1
   instance.status            = GetIniInt    (file, section, "instance.status"  );              // int      instance.status            = 1 (waiting)

   instance.openNetProfit     = GetIniDouble (file, section, "instance.openNetProfit"  );       // double   instance.openNetProfit     = 23.45
   instance.closedNetProfit   = GetIniDouble (file, section, "instance.closedNetProfit");       // double   instance.closedNetProfit   = 45.67
   instance.totalNetProfit    = GetIniDouble (file, section, "instance.totalNetProfit" );       // double   instance.totalNetProfit    = 123.45
   instance.maxNetProfit      = GetIniDouble (file, section, "instance.maxNetProfit"   );       // double   instance.maxNetProfit      = 23.45
   instance.maxNetDrawdown    = GetIniDouble (file, section, "instance.maxNetDrawdown" );       // double   instance.maxNetDrawdown    = -11.23

   instance.openNetProfitP    = GetIniDouble (file, section, "instance.openNetProfitP"  );      // double   instance.openNetProfitP    = 0.12345
   instance.closedNetProfitP  = GetIniDouble (file, section, "instance.closedNetProfitP");      // double   instance.closedNetProfitP  = -0.23456
   instance.totalNetProfitP   = GetIniDouble (file, section, "instance.totalNetProfitP" );      // double   instance.totalNetProfitP   = 1.23456
   instance.maxNetProfitP     = GetIniDouble (file, section, "instance.maxNetProfitP"   );      // double   instance.maxNetProfitP     = 0.12345
   instance.maxNetDrawdownP   = GetIniDouble (file, section, "instance.maxNetDrawdownP" );      // double   instance.maxNetDrawdownP   = -0.23456

   instance.openVirtProfitP   = GetIniDouble (file, section, "instance.openVirtProfitP"  );     // double   instance.openVirtProfitP   = 0.12345
   instance.closedVirtProfitP = GetIniDouble (file, section, "instance.closedVirtProfitP");     // double   instance.closedVirtProfitP = -0.23456
   instance.totalVirtProfitP  = GetIniDouble (file, section, "instance.totalVirtProfitP" );     // double   instance.totalVirtProfitP  = 1.23456
   instance.maxVirtProfitP    = GetIniDouble (file, section, "instance.maxVirtProfitP"   );     // double   instance.maxVirtProfitP    = 23.45
   instance.maxVirtDrawdownP  = GetIniDouble (file, section, "instance.maxVirtDrawdownP" );     // double   instance.maxVirtDrawdownP  = -11.23
   SS.InstanceName();

   // open order data
   open.ticket                = GetIniInt    (file, section, "open.ticket"     );               // int      open.ticket      = 123456
   open.type                  = GetIniInt    (file, section, "open.type"       );               // int      open.type        = 1
   open.lots                  = GetIniDouble (file, section, "open.lots"       );               // double   open.lots        = 0.01
   open.time                  = GetIniInt    (file, section, "open.time"       );               // datetime open.time        = 1624924800 (Mon, 2021.05.12 13:22:34)
   open.price                 = GetIniDouble (file, section, "open.price"      );               // double   open.price       = 1.24363
   open.priceVirt             = GetIniDouble (file, section, "open.priceVirt"  );               // double   open.priceVirt   = 1.24363
   open.slippage              = GetIniDouble (file, section, "open.slippage"   );               // double   open.slippage    = 0.00003
   open.swap                  = GetIniDouble (file, section, "open.swap"       );               // double   open.swap        = -1.23
   open.commission            = GetIniDouble (file, section, "open.commission" );               // double   open.commission  = -5.50
   open.grossProfit           = GetIniDouble (file, section, "open.grossProfit");               // double   open.grossProfit = 12.34
   open.netProfit             = GetIniDouble (file, section, "open.netProfit"  );               // double   open.netProfit   = 12.56
   open.netProfitP            = GetIniDouble (file, section, "open.netProfitP" );               // double   open.netProfitP  = 0.12345
   open.virtProfitP           = GetIniDouble (file, section, "open.virtProfitP");               // double   open.virtProfitP = 0.12345

   // history data
   string sKeys[], sOrder="";
   double netProfit, netProfitP, virtProfitP;
   int size = ReadStatus.HistoryKeys(file, section, sKeys); if (size < 0) return(false);

   for (int i=0; i < size; i++) {
      sOrder = GetIniStringA(file, section, sKeys[i], "");                                      // history.{i} = {data}
      int n = ReadStatus.RestoreHistory(sKeys[i], sOrder);
      if (n < 0) return(!catch("ReadStatus(8)  "+ instance.name +" invalid history record in status file "+ DoubleQuoteStr(file) + NL + sKeys[i] +"="+ sOrder, ERR_INVALID_FILE_FORMAT));

      netProfit   += history[n][H_NETPROFIT   ];
      netProfitP  += history[n][H_NETPROFIT_P ];
      virtProfitP += history[n][H_VIRTPROFIT_P];
   }

   // cross-check restored stats
   int precision = MathMax(Digits, 2) + 1;                    // required precision for fractional point values
   if (NE(netProfit,   instance.closedNetProfit, 2))          return(!catch("ReadStatus(9)  "+  instance.name +" sum(history[H_NETPROFIT]) != instance.closedNetProfit ("     + NumberToStr(netProfit, ".2+")              +" != "+ NumberToStr(instance.closedNetProfit, ".2+")              +")", ERR_ILLEGAL_STATE));
   if (NE(netProfitP,  instance.closedNetProfitP, precision)) return(!catch("ReadStatus(10)  "+ instance.name +" sum(history[H_NETPROFIT_P]) != instance.closedNetProfitP ("  + NumberToStr(netProfitP, "."+ Digits +"+")  +" != "+ NumberToStr(instance.closedNetProfitP, "."+ Digits +"+")  +")", ERR_ILLEGAL_STATE));
   if (NE(virtProfitP, instance.closedVirtProfitP, Digits))   return(!catch("ReadStatus(11)  "+ instance.name +" sum(history[H_VIRTPROFIT_P]) != instance.closedVirtProfitP ("+ NumberToStr(virtProfitP, "."+ Digits +"+") +" != "+ NumberToStr(instance.closedVirtProfitP, "."+ Digits +"+") +")", ERR_ILLEGAL_STATE));

   return(!catch("ReadStatus(12)"));
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
 * @return int - index the data record was inserted at or EMPTY (-1) in case of errors
 */
bool ReadStatus.RestoreHistory(string key, string value) {
   if (IsLastError())                    return(EMPTY);
   if (!StrStartsWithI(key, "history.")) return(_EMPTY(catch("ReadStatus.RestoreHistory(1)  "+ instance.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT)));

   // history.i=ticket,openType,lots,openTime,openPrice,openPriceVirt,closeTime,closePrice,closePriceVirt,slippage,swap,commission,grossProfit,netProfit,netProfitP,virtProfitP
   string values[];
   string sId = StrRightFrom(key, ".", -1); if (!StrIsDigits(sId))  return(_EMPTY(catch("ReadStatus.RestoreHistory(2)  "+ instance.name +" illegal history record key "+ DoubleQuoteStr(key), ERR_INVALID_FILE_FORMAT)));
   if (Explode(value, ",", values, NULL) != ArrayRange(history, 1)) return(_EMPTY(catch("ReadStatus.RestoreHistory(3)  "+ instance.name +" illegal number of details ("+ ArraySize(values) +") in history record", ERR_INVALID_FILE_FORMAT)));

   int      ticket         = StrToInteger(values[H_TICKET         ]);
   int      openType       = StrToInteger(values[H_OPENTYPE       ]);
   double   lots           =  StrToDouble(values[H_LOTS           ]);
   datetime openTime       = StrToInteger(values[H_OPENTIME       ]);
   double   openPrice      =  StrToDouble(values[H_OPENPRICE      ]);
   double   openPriceVirt  =  StrToDouble(values[H_OPENPRICE_VIRT ]);
   datetime closeTime      = StrToInteger(values[H_CLOSETIME      ]);
   double   closePrice     =  StrToDouble(values[H_CLOSEPRICE     ]);
   double   closePriceVirt =  StrToDouble(values[H_CLOSEPRICE_VIRT]);
   double   slippage       =  StrToDouble(values[H_SLIPPAGE       ]);
   double   swap           =  StrToDouble(values[H_SWAP           ]);
   double   commission     =  StrToDouble(values[H_COMMISSION     ]);
   double   grossProfit    =  StrToDouble(values[H_GROSSPROFIT    ]);
   double   netProfit      =  StrToDouble(values[H_NETPROFIT      ]);
   double   netProfitP     =  StrToDouble(values[H_NETPROFIT_P    ]);
   double   virtProfitP    =  StrToDouble(values[H_VIRTPROFIT_P   ]);

   return(History.AddRecord(ticket, openType, lots, openTime, openPrice, openPriceVirt, closeTime, closePrice, closePriceVirt, slippage, swap, commission, grossProfit, netProfit, netProfitP, virtProfitP));
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
int History.AddRecord(int ticket, int openType, double lots, datetime openTime, double openPrice, double openPriceVirt, datetime closeTime, double closePrice, double closePriceVirt, double slippage, double swap, double commission, double grossProfit, double netProfit, double netProfitP, double virtProfitP) {
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
   history[i][H_TICKET         ] = ticket;
   history[i][H_OPENTYPE       ] = openType;
   history[i][H_LOTS           ] = lots;
   history[i][H_OPENTIME       ] = openTime;
   history[i][H_OPENPRICE      ] = openPrice;
   history[i][H_OPENPRICE_VIRT ] = openPriceVirt;
   history[i][H_CLOSETIME      ] = closeTime;
   history[i][H_CLOSEPRICE     ] = closePrice;
   history[i][H_CLOSEPRICE_VIRT] = closePriceVirt;
   history[i][H_SLIPPAGE       ] = slippage;
   history[i][H_SWAP           ] = swap;
   history[i][H_COMMISSION     ] = commission;
   history[i][H_GROSSPROFIT    ] = grossProfit;
   history[i][H_NETPROFIT      ] = netProfit;
   history[i][H_NETPROFIT_P    ] = netProfitP;
   history[i][H_VIRTPROFIT_P   ] = virtProfitP;

   if (!catch("History.AddRecord(2)"))
      return(i);
   return(EMPTY);
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

   SS.All();
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
      string baseName  = ProgramName() +", "+ Symbol() +", "+ GmtTimeFormat(instance.created, "%Y-%m-%d %H.%M") +", id="+ StrPadLeft(instance.id, 3, "0") +".set";
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
   if (instanceId < INSTANCE_ID_MIN || instanceId > INSTANCE_ID_MAX) return(_EMPTY_STR(catch("FindStatusFile(1)  "+ instance.name +" invalid parameter instanceId: "+ instanceId, ERR_INVALID_PARAMETER)));
   isTest = isTest!=0;

   string sandboxDir  = GetMqlSandboxPath() +"/";
   string statusDir   = "presets/"+ ifString(isTest, "Tester", GetAccountCompanyId()) +"/";
   string basePattern = ProgramName() +", "+ Symbol() +",*id="+ StrPadLeft(""+ instanceId, 3, "0") +".set";
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
   if (last_error != NULL)               return(false);
   if (!instance.id || Instance.ID=="")  return(!catch("SaveStatus(1)  illegal instance id: "+ instance.id +" (Instance.ID="+ DoubleQuoteStr(Instance.ID) +")", ERR_ILLEGAL_STATE));
   if (__isTesting) {
      if (test.reduceStatusWrites) {                           // in tester skip most writes except file creation, instance stop and test end
         static bool saved = false;
         if (saved && instance.status!=STATUS_STOPPED && __CoreFunction!=CF_DEINIT) return(true);
         saved = true;
      }
   }
   else if (IsTestInstance()) return(true);                    // don't change the status file of a finished test

   string section="", separator="", file=GetStatusFilename();
   if (!IsFile(file, MODE_SYSTEM)) separator = CRLF;           // an empty line as additional section separator

   // [General]
   section = "General";
   WriteIniString(file, section, "Account", GetAccountCompanyId() +":"+ GetAccountNumber() +" ("+ ifString(IsDemoFix(), "demo", "real") +")"+ ifString(__isTesting, separator, ""));

   if (!__isTesting) {
      WriteIniString(file, section, "AccountCurrency", AccountCurrency());
      WriteIniString(file, section, "Symbol",          Symbol() + separator);                                        // conditional section separator
   }
   else {
      WriteIniString(file, section, "Test.Currency",   AccountCurrency());
      WriteIniString(file, section, "Test.Symbol",     Symbol());
      WriteIniString(file, section, "Test.Timeframe",  TimeToStr(Test.GetStartDate(), TIME_DATE) +"-"+ TimeToStr(Test.GetEndDate()-1*DAY, TIME_DATE));
      WriteIniString(file, section, "Test.Period",     PeriodDescription());
      WriteIniString(file, section, "Test.BarModel",   BarModelDescription(__Test.barModel));
      WriteIniString(file, section, "Test.Spread",     DoubleToStr((Ask-Bid) * pMultiplier, pDigits) +" "+ pUnit);
         double commission  = GetCommission();
         string sCommission = DoubleToStr(commission, 2);
         if (NE(commission, 0)) {
            double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
            double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
            double units     = MathDiv(commission, MathDiv(tickValue, tickSize));
            sCommission = sCommission +" ("+ DoubleToStr(units * pMultiplier, pDigits) +" "+ pUnit +")";
         }
      WriteIniString(file, section, "Test.Commission", sCommission + separator);                                     // conditional section separator
   }

   // [Inputs]
   section = "Inputs";
   WriteIniString(file, section, "Instance.ID",                /*string  */ Instance.ID);
   WriteIniString(file, section, "Tunnel.Definition",          /*string  */ Tunnel.Definition);
   WriteIniString(file, section, "Donchian.Periods",           /*int     */ Donchian.Periods);
   WriteIniString(file, section, "Lots",                       /*double  */ NumberToStr(Lots, ".+"));
   WriteIniString(file, section, "EA.Recorder",                /*string  */ EA.Recorder + separator);                // conditional section separator

   // [Runtime status]
   section = "Runtime status";                                 // On deletion of pending orders (if any) the number of stored order records decreases.
   EmptyIniSectionA(file, section);                            // To prevent orphaned status file records the section is emptied before writing to it.
   WriteIniString(file, section, "recorder.stdEquitySymbol",   /*string  */ recorder.stdEquitySymbol + CRLF);

   // instance data
   WriteIniString(file, section, "instance.id",                /*int     */ instance.id);
   WriteIniString(file, section, "instance.name",              /*string  */ instance.name);
   WriteIniString(file, section, "instance.created",           /*datetime*/ instance.created + GmtTimeFormat(instance.created, " (%a, %Y.%m.%d %H:%M:%S)"));
   WriteIniString(file, section, "instance.isTest",            /*bool    */ instance.isTest);
   WriteIniString(file, section, "instance.status",            /*int     */ instance.status +" ("+ StatusDescription(instance.status) +")"+ CRLF);

   WriteIniString(file, section, "instance.openNetProfit",     /*double  */ StrPadRight(DoubleToStr(instance.openNetProfit, 2), 17)        +" ; real PnL after all costs in "+ AccountCurrency() +" (net)");
   WriteIniString(file, section, "instance.closedNetProfit",   /*double  */ DoubleToStr(instance.closedNetProfit, 2));
   WriteIniString(file, section, "instance.totalNetProfit",    /*double  */ DoubleToStr(instance.totalNetProfit, 2));
   WriteIniString(file, section, "instance.maxNetProfit",      /*double  */ DoubleToStr(instance.maxNetProfit, 2));
   WriteIniString(file, section, "instance.maxNetDrawdown",    /*double  */ DoubleToStr(instance.maxNetDrawdown, 2));
   WriteIniString(file, section, "instance.avgNetProfit",      /*double  */ DoubleToStr(ifDouble(IsEmptyValue(instance.avgNetProfit), 0, instance.avgNetProfit), 2) + CRLF);

   WriteIniString(file, section, "instance.openNetProfitP",    /*double  */ StrPadRight(NumberToStr(instance.openNetProfitP, ".1+"), 16)    +" ; real PnL after all costs in point (net)");
   WriteIniString(file, section, "instance.closedNetProfitP",  /*double  */ NumberToStr(instance.closedNetProfitP, ".1+"));
   WriteIniString(file, section, "instance.totalNetProfitP",   /*double  */ NumberToStr(instance.totalNetProfitP, ".1+"));
   WriteIniString(file, section, "instance.maxNetProfitP",     /*double  */ NumberToStr(instance.maxNetProfitP, ".1+"));
   WriteIniString(file, section, "instance.maxNetDrawdownP",   /*double  */ NumberToStr(instance.maxNetDrawdownP, ".1+"));
   WriteIniString(file, section, "instance.avgNetProfitP",     /*double  */ NumberToStr(ifDouble(IsEmptyValue(instance.avgNetProfitP), 0, instance.avgNetProfitP), ".1+") + CRLF);

   WriteIniString(file, section, "instance.openVirtProfitP",   /*double  */ StrPadRight(DoubleToStr(instance.openVirtProfitP, Digits), 15) +" ; synthetic PnL before spread/any costs in point (exact execution)");
   WriteIniString(file, section, "instance.closedVirtProfitP", /*double  */ DoubleToStr(instance.closedVirtProfitP, Digits));
   WriteIniString(file, section, "instance.totalVirtProfitP",  /*double  */ DoubleToStr(instance.totalVirtProfitP, Digits));
   WriteIniString(file, section, "instance.maxVirtProfitP",    /*double  */ DoubleToStr(instance.maxVirtProfitP, Digits));
   WriteIniString(file, section, "instance.maxVirtDrawdownP",  /*double  */ DoubleToStr(instance.maxVirtDrawdownP, Digits));
   WriteIniString(file, section, "instance.avgVirtProfitP",    /*double  */ DoubleToStr(ifDouble(IsEmptyValue(instance.avgVirtProfitP), 0, instance.avgVirtProfitP), Digits+1) + CRLF);

   // open order data
   WriteIniString(file, section, "open.ticket",                /*int     */ open.ticket);
   WriteIniString(file, section, "open.type",                  /*int     */ open.type);
   WriteIniString(file, section, "open.lots",                  /*double  */ NumberToStr(open.lots, ".+"));
   WriteIniString(file, section, "open.time",                  /*datetime*/ open.time + ifString(open.time, GmtTimeFormat(open.time, " (%a, %Y.%m.%d %H:%M:%S)"), ""));
   WriteIniString(file, section, "open.price",                 /*double  */ DoubleToStr(open.price, Digits));
   WriteIniString(file, section, "open.priceVirt",             /*double  */ DoubleToStr(open.priceVirt, Digits));
   WriteIniString(file, section, "open.slippage",              /*double  */ DoubleToStr(open.slippage, Digits));
   WriteIniString(file, section, "open.swap",                  /*double  */ DoubleToStr(open.swap, 2));
   WriteIniString(file, section, "open.commission",            /*double  */ DoubleToStr(open.commission, 2));
   WriteIniString(file, section, "open.grossProfit",           /*double  */ DoubleToStr(open.grossProfit, 2));
   WriteIniString(file, section, "open.netProfit",             /*double  */ DoubleToStr(open.netProfit, 2));
   WriteIniString(file, section, "open.netProfitP",            /*double  */ NumberToStr(open.netProfitP, ".1+"));
   WriteIniString(file, section, "open.virtProfitP",           /*double  */ DoubleToStr(open.virtProfitP, Digits) + CRLF);

   // closed order data
   double netProfit, netProfitP, virtProfitP;
   int size = ArrayRange(history, 0);

   for (int i=0; i < size; i++) {
      WriteIniString(file, section, "history."+ i, SaveStatus.HistoryToStr(i));
      netProfit   += history[i][H_NETPROFIT   ];
      netProfitP  += history[i][H_NETPROFIT_P ];
      virtProfitP += history[i][H_VIRTPROFIT_P];
   }

   // cross-check stored stats
   int precision = MathMax(Digits, 2) + 1;                    // required precision for fractional point values
   if (NE(netProfit,   instance.closedNetProfit, 2))          return(!catch("SaveStatus(2)  "+ instance.name +" sum(history[H_NETPROFIT]) != instance.closedNetProfit ("     + NumberToStr(netProfit, ".2+")              +" != "+ NumberToStr(instance.closedNetProfit, ".2+")              +")", ERR_ILLEGAL_STATE));
   if (NE(netProfitP,  instance.closedNetProfitP, precision)) return(!catch("SaveStatus(3)  "+ instance.name +" sum(history[H_NETPROFIT_P]) != instance.closedNetProfitP ("  + NumberToStr(netProfitP, "."+ Digits +"+")  +" != "+ NumberToStr(instance.closedNetProfitP, "."+ Digits +"+")  +")", ERR_ILLEGAL_STATE));
   if (NE(virtProfitP, instance.closedVirtProfitP, Digits))   return(!catch("SaveStatus(4)  "+ instance.name +" sum(history[H_VIRTPROFIT_P]) != instance.closedVirtProfitP ("+ NumberToStr(virtProfitP, "."+ Digits +"+") +" != "+ NumberToStr(instance.closedVirtProfitP, "."+ Digits +"+") +")", ERR_ILLEGAL_STATE));

   return(!catch("SaveStatus(5)"));
}


/**
 * Return a string representation of a history record to be stored by SaveStatus().
 *
 * @param  int index - index of the history record
 *
 * @return string - string representation or an empty string in case of errors
 */
string SaveStatus.HistoryToStr(int index) {
   // result: ticket,openType,lots,openTime,openPrice,openPriceVirt,closeTime,closePrice,closePriceVirt,slippage,swap,commission,grossProfit,netProfit,netProfitP,virtProfitP

   int      ticket         = history[index][H_TICKET         ];
   int      openType       = history[index][H_OPENTYPE       ];
   double   lots           = history[index][H_LOTS           ];
   datetime openTime       = history[index][H_OPENTIME       ];
   double   openPrice      = history[index][H_OPENPRICE      ];
   double   openPriceVirt  = history[index][H_OPENPRICE_VIRT ];
   datetime closeTime      = history[index][H_CLOSETIME      ];
   double   closePrice     = history[index][H_CLOSEPRICE     ];
   double   closePriceVirt = history[index][H_CLOSEPRICE_VIRT];
   double   slippage       = history[index][H_SLIPPAGE       ];
   double   swap           = history[index][H_SWAP           ];
   double   commission     = history[index][H_COMMISSION     ];
   double   grossProfit    = history[index][H_GROSSPROFIT    ];
   double   netProfit      = history[index][H_NETPROFIT      ];
   double   netProfitP     = history[index][H_NETPROFIT_P    ];
   double   virtProfitP    = history[index][H_VIRTPROFIT_P   ];

   return(StringConcatenate(ticket, ",", openType, ",", DoubleToStr(lots, 2), ",", openTime, ",", DoubleToStr(openPrice, Digits), ",", DoubleToStr(openPriceVirt, Digits), ",", closeTime, ",", DoubleToStr(closePrice, Digits), ",", DoubleToStr(closePriceVirt, Digits), ",", DoubleToStr(slippage, Digits), ",", DoubleToStr(swap, 2), ",", DoubleToStr(commission, 2), ",", DoubleToStr(grossProfit, 2), ",", DoubleToStr(netProfit, 2), ",", NumberToStr(netProfitP, ".1+"), ",", DoubleToStr(virtProfitP, Digits)));
}


// backed-up input parameters
string   prev.Instance.ID = "";
string   prev.Tunnel.Definition = "";
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
   prev.Instance.ID       = StringConcatenate(Instance.ID, "");         // string inputs are references to internal C literals
   prev.Tunnel.Definition = StringConcatenate(Tunnel.Definition, "");   // and must be copied to break the reference
   prev.Donchian.Periods  = Donchian.Periods;
   prev.Lots              = Lots;

   // backup runtime variables affected by changing input parameters
   prev.instance.id      = instance.id;
   prev.instance.created = instance.created;
   prev.instance.isTest  = instance.isTest;
   prev.instance.name    = instance.name;
   prev.instance.status  = instance.status;

   Recorder.BackupInputs();
}


/**
 * Restore backed-up input parameters and runtime variables. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   // restore input parameters
   Instance.ID       = prev.Instance.ID;
   Tunnel.Definition = prev.Tunnel.Definition;
   Donchian.Periods  = prev.Donchian.Periods;
   Lots              = prev.Lots;

   // restore runtime variables
   instance.id      = prev.instance.id;
   instance.created = prev.instance.created;
   instance.isTest  = prev.instance.isTest;
   instance.name    = prev.instance.name;
   instance.status  = prev.instance.status;

   Recorder.RestoreInputs();
}


/**
 * Validate and apply input parameter "Instance.ID".
 *
 * @return bool - whether an instance id value was successfully restored (the status file is not checked)
 */
bool ValidateInputs.ID() {
   bool errorFlag = true;

   if (!SetInstanceId(Instance.ID, errorFlag, "ValidateInputs.ID(1)")) {
      if (errorFlag) onInputError("ValidateInputs.ID(2)  invalid input parameter Instance.ID: \""+ Instance.ID +"\"");
      return(false);
   }
   return(true);
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

   // Tunnel.Definition
   if (isInitParameters && Tunnel.Definition!=prev.Tunnel.Definition) {
      if (hasOpenOrders)                           return(!onInputError("ValidateInputs(2)  "+ instance.name +" cannot change input parameter Tunnel.Definition with open orders"));
   }
   string sValue, sValues[], sMAs[];
   ArrayResize(sMAs, 0);
   int n=0, size=Explode(Tunnel.Definition, ",", sValues, NULL);
   for (int i=0; i < size; i++) {
      sValue = StrTrim(sValues[i]);
      if (sValue == "") continue;

      string sMethod = StrLeftTo(sValue, "(");
      if (sMethod == sValue)                       return(!onInputError("ValidateInputs(3)  "+ instance.name +" invalid value "+ DoubleQuoteStr(sValue) +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition) +" (format not \"MaMethod(int)\")"));
      int iMethod = StrToMaMethod(sMethod, F_ERR_INVALID_PARAMETER);
      if (iMethod == -1)                           return(!onInputError("ValidateInputs(4)  "+ instance.name +" invalid MA method "+ DoubleQuoteStr(sMethod) +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition)));
      if (iMethod > MODE_LWMA)                     return(!onInputError("ValidateInputs(5)  "+ instance.name +" unsupported MA method "+ DoubleQuoteStr(sMethod) +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition)));

      string sPeriods = StrRightFrom(sValue, "(");
      if (!StrEndsWith(sPeriods, ")"))             return(!onInputError("ValidateInputs(6)  "+ instance.name +" invalid value "+ DoubleQuoteStr(sValue) +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition) +" (format not \"MaMethod(int)\")"));
      sPeriods = StrTrim(StrLeft(sPeriods, -1));
      if (!StrIsDigits(sPeriods))                  return(!onInputError("ValidateInputs(7)  "+ instance.name +" invalid value "+ DoubleQuoteStr(sValue) +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition) +" (format not \"MaMethod(int)\")"));
      int iPeriods = StrToInteger(sPeriods);
      if (iPeriods < 1)                            return(!onInputError("ValidateInputs(8)  "+ instance.name +" invalid MA periods "+ iPeriods +" in input parameter Tunnel.Definition: "+ DoubleQuoteStr(Tunnel.Definition) +" (must be > 0)"));

      ArrayResize(sMAs, n+1);
      sMAs[n]  = MaMethodDescription(iMethod) +"("+ iPeriods +")";
      n++;
   }
   if (!n)                                         return(!onInputError("ValidateInputs(9)  "+ instance.name +" missing input parameter Tunnel.Definition (empty)"));
   Tunnel.Definition = JoinStrings(sMAs);

   // Donchian.Periods
   if (isInitParameters && Donchian.Periods!=prev.Donchian.Periods) {
      if (hasOpenOrders)                           return(!onInputError("ValidateInputs(10)  "+ instance.name +" cannot change input parameter Donchian.Periods with open orders"));
   }
   if (Donchian.Periods < 2)                       return(!onInputError("ValidateInputs(11)  "+ instance.name +" invalid input parameter Donchian.Periods: "+ Donchian.Periods +" (must be > 1)"));

   // Lots
   if (LT(Lots, 0))                                return(!onInputError("ValidateInputs(12)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (must be > 0)"));
   if (NE(Lots, NormalizeLots(Lots)))              return(!onInputError("ValidateInputs(13)  "+ instance.name +" invalid input parameter Lots: "+ NumberToStr(Lots, ".1+") +" (must be a multiple of MODE_LOTSTEP="+ NumberToStr(MarketInfo(Symbol(), MODE_LOTSTEP), ".+") +")"));

   // EA.Recorder: on | off* | 1,2,3=1000,...
   if (!Recorder.ValidateInputs(IsTestInstance())) return(false);

   SS.All();
   return(!catch("ValidateInputs(14)"));
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
 * Return a symbol definition for the specified metric to be recorded.
 *
 * @param  _In_  int    id           - metric id; 0 = standard AccountEquity() symbol, positive integer for custom metrics
 * @param  _Out_ bool   &ready       - whether metric details are complete and the metric is ready to be recorded
 * @param  _Out_ string &symbol      - unique MT4 timeseries symbol
 * @param  _Out_ string &description - symbol description as in the MT4 "Symbols" window (if empty a description is generated)
 * @param  _Out_ string &group       - symbol group name as in the MT4 "Symbols" window (if empty a name is generated)
 * @param  _Out_ int    &digits      - symbol digits value
 * @param  _Out_ double &baseValue   - quotes base value (if EMPTY recorder default settings are used)
 * @param  _Out_ int    &multiplier  - quotes multiplier
 *
 * @return int - error status; especially ERR_INVALID_INPUT_PARAMETER if the passed metric id is unknown or not supported
 */
int Recorder_GetSymbolDefinition(int id, bool &ready, string &symbol, string &description, string &group, int &digits, double &baseValue, int &multiplier) {
   string sId = ifString(!instance.id, "???", StrPadLeft(instance.id, 3, "0"));
   string descrSuffix = "";

   ready     = false;
   group     = "";
   baseValue = EMPTY;

   switch (id) {
      // --- standard AccountEquity() symbol for recorder.mode = RECORDER_ON ------------------------------------------------
      case NULL:
         symbol      = recorder.stdEquitySymbol;
         description = "";
         digits      = 2;
         multiplier  = 1;
         ready       = true;
         return(NO_ERROR);

      // --- custom cumulated metrcis ---------------------------------------------------------------------------------------
      case METRIC_TOTAL_NET_MONEY:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"A";       // "US500.123A"
         descrSuffix = ", "+ PeriodDescription() +", net PnL in "+ AccountCurrency() + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         digits      = 2;
         multiplier  = 1;
         break;

      case METRIC_TOTAL_NET_UNITS:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"B";
         descrSuffix = ", "+ PeriodDescription() +", net PnL in "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         digits      = pDigits;
         multiplier  = pMultiplier;
         break;

      case METRIC_TOTAL_VIRT_UNITS:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"C";
         descrSuffix = ", "+ PeriodDescription() +", synthetic PnL in "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         digits      = pDigits;
         multiplier  = pMultiplier;
         break;

      default:
         return(ERR_INVALID_INPUT_PARAMETER);
   }

   description = StrLeft(ProgramName(), 63-StringLen(descrSuffix )) + descrSuffix;
   ready = (instance.id > 0);

   return(NO_ERROR);
}


/**
 * Update the recorder with current metric values.
 */
void RecordMetrics() {
   if (recorder.mode == RECORDER_CUSTOM) {
      int size = ArraySize(metric.ready);
      if (size > METRIC_TOTAL_NET_MONEY ) metric.currValue[METRIC_TOTAL_NET_MONEY ] = instance.totalNetProfit;
      if (size > METRIC_TOTAL_NET_UNITS ) metric.currValue[METRIC_TOTAL_NET_UNITS ] = instance.totalNetProfitP;
      if (size > METRIC_TOTAL_VIRT_UNITS) metric.currValue[METRIC_TOTAL_VIRT_UNITS] = instance.totalVirtProfitP;
   }
}


/**
 * Store volatile runtime vars in chart and chart window (for template reload, terminal restart, recompilation etc).
 *
 * @return bool - success status
 */
bool StoreVolatileData() {
   string name = ProgramName();

   // input string Instance.ID
   string value = ifString(instance.isTest, "T", "") + StrPadLeft(instance.id, 3, "0");
   Instance.ID = value;
   if (__isChart) {
      string key = name +".Instance.ID";
      SetWindowStringA(__ExecutionContext[EC.hChart], key, value);
      Chart.StoreString(key, value);
   }

   // int status.activeMetric
   if (__isChart) {
      key = name +".status.activeMetric";
      SetWindowIntegerA(__ExecutionContext[EC.hChart], key, status.activeMetric);
      Chart.StoreInt(key, status.activeMetric);
   }

   // bool status.showOpenOrders
   if (__isChart) {
      key = name +".status.showOpenOrders";
      SetWindowIntegerA(__ExecutionContext[EC.hChart], key, ifInt(status.showOpenOrders, 1, -1));
      Chart.StoreBool(key, status.showOpenOrders);
   }

   // bool status.showTradeHistory
   if (__isChart) {
      key = name +".status.showTradeHistory";
      SetWindowIntegerA(__ExecutionContext[EC.hChart], key, ifInt(status.showTradeHistory, 1, -1));
      Chart.StoreBool(key, status.showTradeHistory);
   }
   return(!catch("StoreVolatileData(1)"));
}


/**
 * Restore volatile runtime data from chart or chart window (for template reload, terminal restart, recompilation etc).
 *
 * @return bool - whether an instance id was successfully restored
 */
bool RestoreVolatileData() {
   string name = ProgramName();

   // input string Instance.ID
   while (true) {
      bool error = false;
      if (SetInstanceId(Instance.ID, error, "RestoreVolatileData(1)")) break;
      if (error) return(false);

      if (__isChart) {
         string key = name +".Instance.ID";
         string sValue = GetWindowStringA(__ExecutionContext[EC.hChart], key);
         if (SetInstanceId(sValue, error, "RestoreVolatileData(2)")) break;
         if (error) return(false);

         Chart.RestoreString(key, sValue, false);
         if (SetInstanceId(sValue, error, "RestoreVolatileData(3)")) break;
         return(false);
      }
   }

   // int status.activeMetric
   if (__isChart) {
      key = name +".status.activeMetric";
      while (true) {
         int iValue = GetWindowIntegerA(__ExecutionContext[EC.hChart], key);
         if (iValue != 0) {
            if (iValue > 0 && iValue <= 3) {                // valid metrics: 1-3
               status.activeMetric = iValue;
               break;
            }
         }
         if (Chart.RestoreInt(key, iValue, false)) {
            if (iValue > 0 && iValue <= 3) {
               status.activeMetric = iValue;
               break;
            }
         }
         logWarn("RestoreVolatileData(4)  "+ instance.name +"  invalid data: status.activeMetric="+ iValue);
         status.activeMetric = 1;                           // reset to default value
         break;
      }
   }

   // bool status.showOpenOrders
   if (__isChart) {
      key = name +".status.showOpenOrders";
      iValue = GetWindowIntegerA(__ExecutionContext[EC.hChart], key);
      if (iValue != 0) {
         status.showOpenOrders = (iValue > 0);
      }
      else if (!Chart.RestoreBool(key, status.showOpenOrders, false)) {
         status.showOpenOrders = false;                     // reset to default value
      }
   }

   // bool status.showTradeHistory
   if (__isChart) {
      key = name +".status.showTradeHistory";
      iValue = GetWindowIntegerA(__ExecutionContext[EC.hChart], key);
      if (iValue != 0) {
         status.showTradeHistory = (iValue > 0);
      }
      else if (!Chart.RestoreBool(key, status.showTradeHistory, false)) {
         status.showOpenOrders = false;                     // reset to default value
      }
   }
   return(true);
}


/**
 * Remove stored volatile runtime data from chart and chart window.
 *
 * @return bool - success status
 */
bool RemoveVolatileData() {
   string name = ProgramName();

   // input string Instance.ID
   if (__isChart) {
      string key = name +".Instance.ID";
      string sValue = RemoveWindowStringA(__ExecutionContext[EC.hChart], key);
      Chart.RestoreString(key, sValue, true);
   }

   // int status.activeMetric
   if (__isChart) {
      key = name +".status.activeMetric";
      int iValue = RemoveWindowIntegerA(__ExecutionContext[EC.hChart], key);
      Chart.RestoreInt(key, iValue, true);
   }

   // bool status.showOpenOrders
   if (__isChart) {
      key = name +".status.showOpenOrders";
      bool bValue = RemoveWindowIntegerA(__ExecutionContext[EC.hChart], key);
      Chart.RestoreBool(key, bValue, true);
   }

   // bool status.showTradeHistory
   if (__isChart) {
      key = name +".status.showTradeHistory";
      bValue = RemoveWindowIntegerA(__ExecutionContext[EC.hChart], key);
      Chart.RestoreBool(key, bValue, true);
   }

   // event object for chart commands
   if (__isChart) {
      key = "EA.status";
      if (ObjectFind(key) != -1) ObjectDelete(key);
   }
   return(!catch("RemoveVolatileData(1)"));
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
      case NULL              : return("(null)"            );
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
   SS.InstanceName();
   SS.Metric();
   SS.OpenLots();
   SS.ClosedTrades();
   SS.TotalProfit();
   SS.ProfitStats();
}


/**
 * ShowStatus: Update the string representation of the instance name.
 */
void SS.InstanceName() {
   instance.name = "V."+ StrPadLeft(instance.id, 3, "0");
}


/**
 * ShowStatus: Update the description of the displayed metric.
 */
void SS.Metric() {
   switch (status.activeMetric) {
      case METRIC_TOTAL_NET_MONEY:
         sMetric = "Net PnL after all costs in "+ AccountCurrency() + NL + "-----------------------------------";
         break;
      case METRIC_TOTAL_NET_UNITS:
         sMetric = "Net PnL after all costs in "+ pUnit + NL + "---------------------------------"+ ifString(pUnit=="point", "---", "");
         break;
      case METRIC_TOTAL_VIRT_UNITS:
         sMetric = "Synthetic PnL before spread/any costs in "+ pUnit + NL + "------------------------------------------------------"+ ifString(pUnit=="point", "--", "");
         break;

      default: return(!catch("SS.MetricDescription(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
   }
}


/**
 * ShowStatus: Update the string representation of the open position size.
 */
void SS.OpenLots() {
   if      (!open.lots)           sOpenLots = "-";
   else if (open.type == OP_LONG) sOpenLots = "+"+ NumberToStr(open.lots, ".+") +" lot";
   else                           sOpenLots = "-"+ NumberToStr(open.lots, ".+") +" lot";
}


/**
 * ShowStatus: Update the string summary of the closed trades.
 */
void SS.ClosedTrades() {
   int size = ArrayRange(history, 0);
   if (!size) {
      sClosedTrades = "-";
   }
   else {
      if (instance.avgNetProfit == EMPTY_VALUE) CalculateTradeStats();

      switch (status.activeMetric) {
         case METRIC_TOTAL_NET_MONEY:
            sClosedTrades = size +" trades    avg: "+ NumberToStr(instance.avgNetProfit, "R+.2") +" "+ AccountCurrency();
            break;
         case METRIC_TOTAL_NET_UNITS:
            sClosedTrades = size +" trades    avg: "+ NumberToStr(instance.avgNetProfitP * pMultiplier, "R+."+ pDigits) +" "+ pUnit;
            break;
         case METRIC_TOTAL_VIRT_UNITS:
            sClosedTrades = size +" trades    avg: "+ NumberToStr(instance.avgVirtProfitP * pMultiplier, "R+."+ pDigits) +" "+ pUnit;
            break;

         default: return(!catch("SS.ClosedTrades(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
      }
   }
}


/**
 * ShowStatus: Update the string representation of the total instance PnL.
 */
void SS.TotalProfit() {
   // not before a position was opened
   if (!open.ticket && !ArrayRange(history, 0)) {
      sTotalProfit = "-";
   }
   else {
      switch (status.activeMetric) {
         case METRIC_TOTAL_NET_MONEY:
            sTotalProfit = NumberToStr(instance.totalNetProfit, "R+.2") +" "+ AccountCurrency();
            break;
         case METRIC_TOTAL_NET_UNITS:
            sTotalProfit = NumberToStr(instance.totalNetProfitP * pMultiplier, "R+."+ pDigits) +" "+ pUnit;
            break;
         case METRIC_TOTAL_VIRT_UNITS:
            sTotalProfit = NumberToStr(instance.totalVirtProfitP * pMultiplier, "R+."+ pDigits) +" "+ pUnit;
            break;

         default: return(!catch("SS.TotalProfit(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
      }
   }
}


/**
 * ShowStatus: Update the string representaton of the PnL statistics.
 */
void SS.ProfitStats() {
   // not before a position was opened
   if (!open.ticket && !ArrayRange(history, 0)) {
      sProfitStats = "";
   }
   else {
      string sMaxProfit="", sMaxDrawdown="";

      switch (status.activeMetric) {
         case METRIC_TOTAL_NET_MONEY:
            sMaxProfit   = NumberToStr(instance.maxNetProfit,   "R+.2");
            sMaxDrawdown = NumberToStr(instance.maxNetDrawdown, "R+.2");
            break;
         case METRIC_TOTAL_NET_UNITS:
            sMaxProfit   = NumberToStr(instance.maxNetProfitP   * pMultiplier, "R+."+ pDigits);
            sMaxDrawdown = NumberToStr(instance.maxNetDrawdownP * pMultiplier, "R+."+ pDigits);
            break;
         case METRIC_TOTAL_VIRT_UNITS:
            sMaxProfit   = NumberToStr(instance.maxVirtProfitP   * pMultiplier, "R+."+ pDigits);
            sMaxDrawdown = NumberToStr(instance.maxVirtDrawdownP * pMultiplier, "R+."+ pDigits);
            break;

         default: return(!catch("SS.ProfitStats(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
      }
      sProfitStats = StringConcatenate("(", sMaxDrawdown, "/", sMaxProfit, ")");
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

   string text = StringConcatenate(ProgramName(), "    ", sStatus, sError,          NL,
                                                                                    NL,
                                   sMetric,                                         NL,
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
   return(StringConcatenate("Instance.ID=",       DoubleQuoteStr(Instance.ID),       ";", NL,
                            "Tunnel.Definition=", DoubleQuoteStr(Tunnel.Definition), ";", NL,
                            "Donchian.Periods=",  Donchian.Periods,                  ";", NL,
                            "Lots=",              NumberToStr(Lots, ".1+"),          ";")
   );
}
