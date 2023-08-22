/**
 * This indicator displays market data, account infos and trade statistics on the chart.
 *
 *  - The current price and spread.
 *  - The current instrument name (only in terminals <= build 509).
 *  - The pre-calculated unitsize for a standard position.
 *  - The currently open total position with resulting risk and leverage values.
 *  - PL of open positions and/or trade history.
 *  - Current PL target levels and the current account stopout level.
 *  - A warning when the account's open order limit is approached.
 *
 *
 * TODO:
 *  - don't recalculate unitsize on every tick (every few seconds is sufficient)
 *  - set order tracker sound on stopout to "margin-call"
 *  - PositionOpen/PositionClose events during change of chart timeframe/symbol are not detected
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string UnitSize.Corner = "top-left | top-right | bottom-left | bottom-right*";  // or shorter: "tl | tr | bl | br"
extern string Track.Orders    = "on | off | auto*";                                    // whether to signal position open/close events
extern string ___a__________________________;

extern string Signal.Sound    = "on | off | auto*";
extern string Signal.Mail     = "on | off | auto*";
extern string Signal.SMS      = "on | off | auto*";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <functions/ConfigureSignalsByMail.mqh>
#include <functions/ConfigureSignalsBySMS.mqh>
#include <functions/ConfigureSignalsBySound.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/ta/ADR.mqh>
#include <MT4iQuickChannel.mqh>
#include <lfx.mqh>
#include <scriptrunner.mqh>
#include <structs/rsf/LFXOrder.mqh>
#include <win32api.mqh>

#property indicator_chart_window

// chart infos
int displayedPrice = PRICE_MEDIAN;                                // price type: Bid | Ask | Median (default)

// unitsize calculation, see CalculateUnitSize()
bool   mm.done;                                                   // processing flag
double mm.equity;                                                 // equity value used for calculations, incl. external assets and floating losses (but not floating/unrealized profits)

double mm.cfgLeverage;
double mm.cfgRiskPercent;
double mm.cfgRiskRange;
bool   mm.cfgRiskRangeIsADR;                                      // whether the price range is configured as "ADR"

double mm.lotValue;                                               // value of 1 lot in account currency
double mm.unleveragedLots;                                        // unleveraged unitsize
double mm.leveragedLots;                                          // leveraged unitsize
double mm.leveragedLotsNormalized;                                // leveraged unitsize normalized to MODE_LOTSTEP
double mm.leverage;                                               // resulting leverage
double mm.riskPercent;                                            // resulting risk
double mm.riskRange;                                              // resulting price range

// configuration of custom positions
#define POSITION_CONFIG_TERM_size       5                         // in doubles

double  positions.config[][POSITION_CONFIG_TERM_size];            // parsed custom position configuration, @see CustomPositions.ReadConfig() for format
string  positions.config.comments[];                              // comments of custom position configuration, size matches positions.config[]

#define I_TERM_TYPE                     0                         // indexes of positions.config[][]
#define I_TERM_VALUE1                   1
#define I_TERM_VALUE2                   2
#define I_TERM_CACHE1                   3                         // field for caching intermediate results
#define I_TERM_CACHE2                   4                         // ...

#define TERM_TICKET                     1                         // notation term types of the custom position configuration
#define TERM_OPEN_LONG                  2
#define TERM_OPEN_SHORT                 3
#define TERM_OPEN                       4
#define TERM_HISTORY                    5
#define TERM_HISTORY_TOTAL              6                         // intentionally TERM_OPEN_TOTAL is not implemented
#define TERM_PL_ADJUSTMENT              7
#define TERM_EQUITY                     8
#define TERM_PROFIT_MARKER              9
#define TERM_LOSS_MARKER               10

// control flags for AnalyzePositions()
#define F_LOG_TICKETS                   1                         // log tickets of resulting custom positions (configured and unconfigured)
#define F_LOG_SKIP_EMPTY                2                         // skip empty array elements when logging tickets
#define F_SHOW_CUSTOM_POSITIONS         4                         // call ShowOpenOrders() for configured positions (not for unconfigured or pending ones)
#define F_SHOW_CUSTOM_HISTORY           8                         // call ShowTradeHistory() for the configured history (not for total history)

// internal + external position data
bool    isPendings;                                               // ob Pending-Limite im Markt liegen (Orders oder Positions)
bool    isPosition;                                               // ob offene Positionen existieren, die Gesamtposition kann flat sein: (longPosition || shortPosition)
double  totalPosition;
double  longPosition;
double  shortPosition;
int     positions.iData[][3];                                     // position details: [ConfigType, PositionType, CommentIndex]
double  positions.dData[][13];                                    //                   [DirectionalLots, HedgedLots, PipDistance|BreakevenPrice, ProfitMarkerPrice, ProfitMarkerPercent, LossMarkerPrice, LossMarkerPercent, Equity, OpenProfit, ClosedProfit, AdjustedProfit, FullProfitAbs, FullProfitPct]
bool    positions.analyzed;
bool    positions.absoluteProfits;                                // default: online=FALSE, tester=TRUE

#define CONFIG_AUTO                     0                         // ConfigTypes:      normale unkonfigurierte offene Position (intern oder extern)
#define CONFIG_REAL                     1                         //                   individuell konfigurierte reale Position
#define CONFIG_VIRTUAL                  2                         //                   individuell konfigurierte virtuelle Position

#define POSITION_LONG                   1                         // PositionTypes
#define POSITION_SHORT                  2                         // (werden in typeDescriptions[] als Arrayindizes benutzt)
#define POSITION_HEDGE                  3
#define POSITION_HISTORY                4
string  typeDescriptions[] = {"", "Long:", "Short:", "Hedge:", "History:"};

#define I_CONFIG_TYPE                   0                         // Arrayindizes von positions.iData[]
#define I_POSITION_TYPE                 1
#define I_COMMENT_INDEX                 2

#define I_DIRECTIONAL_LOTS              0                         // Arrayindizes von positions.dData[]
#define I_HEDGED_LOTS                   1
#define I_PIP_DISTANCE                  2
#define I_BREAKEVEN_PRICE  I_PIP_DISTANCE
#define I_PROFIT_MARKER_PRICE           3
#define I_PROFIT_MARKER_PERCENT         4
#define I_LOSS_MARKER_PRICE             5
#define I_LOSS_MARKER_PERCENT           6
#define I_OPEN_EQUITY                   7
#define I_OPEN_PROFIT                   8
#define I_CLOSED_PROFIT                 9
#define I_ADJUSTED_PROFIT              10
#define I_FULL_PROFIT_ABS              11
#define I_FULL_PROFIT_PCT              12

// Cache-Variablen für LFX-Orders. Ihre Größe entspricht der Größe von lfxOrders[].
// Dienen der Beschleunigung, um nicht ständig die LFX_ORDER-Getter aufrufen zu müssen.
int     lfxOrders.iCache[][1];                                    // = {Ticket}
bool    lfxOrders.bCache[][3];                                    // = {IsPendingOrder, IsOpenPosition , IsPendingPosition}
double  lfxOrders.dCache[][7];                                    // = {OpenEquity    , Profit         , LastProfit       , TP-Amount , TP-Percent, SL-Amount, SL-Percent}
int     lfxOrders.pendingOrders;                                  // Anzahl der PendingOrders (mit Entry-Limit)  : lo.IsPendingOrder()    = 1
int     lfxOrders.openPositions;                                  // Anzahl der offenen Positionen               : lo.IsOpenPosition()    = 1
int     lfxOrders.pendingPositions;                               // Anzahl der offenen Positionen mit Exit-Limit: lo.IsPendingPosition() = 1

#define IC.ticket                   0                             // Arrayindizes für Cache-Arrays

#define BC.isPendingOrder           0
#define BC.isOpenPosition           1
#define BC.isPendingPosition        2

#define DC.openEquity               0
#define DC.profit                   1
#define DC.lastProfit               2                             // der letzte vorherige Profit-Wert, um PL-Aktionen nur bei Änderungen durchführen zu können
#define DC.takeProfitAmount         3
#define DC.takeProfitPercent        4
#define DC.stopLossAmount           5
#define DC.stopLossPercent          6

// text labels for the different chart infos
string  label.instrument     = "";
string  label.price          = "";
string  label.spread         = "";
string  label.customPosition = "";                                // base value create actual row + column labels
string  label.totalPosition  = "";
string  label.unitSize       = "";
string  label.accountBalance = "";
string  label.orderCounter   = "";
string  label.tradeAccount   = "";
string  label.stopoutLevel   = "";

// chart position of total position and unitsize
int     totalPosition.corner = CORNER_BOTTOM_RIGHT;
int     unitSize.corner      = CORNER_BOTTOM_RIGHT;
string  cornerDescriptions[] = {"top-left", "top-right", "bottom-left", "bottom-right"};

// font settings for detailed positions
string  positions.fontName          = "MS Sans Serif";
int     positions.fontSize          = 8;
color   positions.fontColor.open    = Blue;
color   positions.fontColor.virtual = Green;
color   positions.fontColor.history = C'128,128,0';

// order tracking
#define TI_TICKET          0                                      // order tracker indexes
#define TI_ORDERTYPE       1
#define TI_ENTRYLIMIT      2

bool    orderTracker.enabled;
string  orderTracker.key = "";                                    // key prefix for listener registration
int     hWndDesktop;                                              // handle of the desktop main window (for listener registration)
double  trackedOrders[][3];                                       // {ticket, orderType, openLimit}

// types for server-side closed positions
#define CLOSE_TAKEPROFIT   1
#define CLOSE_STOPLOSS     2
#define CLOSE_STOPOUT      3                                      // margin call

// Konfiguration der Signalisierung
bool    signal.sound;
string  signal.sound.orderFailed    = "speech/OrderCancelled.wav";
string  signal.sound.positionOpened = "speech/OrderFilled.wav";
string  signal.sound.positionClosed = "speech/PositionClosed.wav";
bool    signal.mail;
string  signal.mail.sender   = "";
string  signal.mail.receiver = "";
bool    signal.sms;
string  signal.sms.receiver = "";

#include <apps/chartinfos/init.mqh>
#include <apps/chartinfos/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   mm.done = false;
   positions.analyzed = false;

   if (__isChart) HandleCommands();                                                 // process incoming commands

   if (!UpdatePrice())                     if (IsLastError()) return(last_error);   // update the current price (top-right)

   if (mode.extern) {
      if (!QC.HandleLfxTerminalMessages()) if (IsLastError()) return(last_error);   // process incoming LFX commands
      if (!UpdatePositions())              if (IsLastError()) return(last_error);   // update detailed P/L statistics (bottom-left) and the total open position (bottom-right)
   }
   else {
      if (!QC.HandleTradeCommands())       if (IsLastError()) return(last_error);   // process incoming trade commands
      if (!UpdateSpread())                 if (IsLastError()) return(last_error);   // current spread (top-right)
      if (!UpdateUnitSize())               if (IsLastError()) return(last_error);   // calculated unit size of a standard position (bottom-right)
      if (!UpdatePositions())              if (IsLastError()) return(last_error);   // detailed P/L stats (bottom-left) and total open position (bottom-right)
      if (!UpdateStopoutLevel())           if (IsLastError()) return(last_error);   // stopout level marker
      if (!UpdateOrderCounter())           if (IsLastError()) return(last_error);   // counter for the account's open order limit

      if (orderTracker.enabled) {                                                   // monitor execution of order limits
         double openedPositions[][2]; ArrayResize(openedPositions, 0);              // {ticket, entryLimit}
         int    closedPositions[][2]; ArrayResize(closedPositions, 0);              // {ticket, closedType}
         int    failedOrders   [];    ArrayResize(failedOrders,    0);              // {ticket}

         if (!MonitorOpenOrders(openedPositions, closedPositions, failedOrders)) return(last_error);
         if (ArraySize(openedPositions) > 0) onPositionOpen (openedPositions);
         if (ArraySize(closedPositions) > 0) onPositionClose(closedPositions);
         if (ArraySize(failedOrders   ) > 0) onOrderFail    (failedOrders);
      }
   }
   return(last_error);
}


/**
 * Handle AccountChange events.
 *
 * @param  int previous - previous account number
 * @param  int current  - current account number
 *
 * @return int - error status
 */
int onAccountChange(int previous, int current) {
   ArrayResize(trackedOrders, 0);
   return(onInit());
}


/**
 * Process an incoming command.
 *
 * @param  string cmd    - command name
 * @param  string params - command parameters
 * @param  int    keys   - combination of pressed modifier keys
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params, int keys) {
   if (cmd == "log-custom-positions") {
      int flags = F_LOG_TICKETS;                                  // log tickets
      if (!keys & F_VK_SHIFT) flags |= F_LOG_SKIP_EMPTY;          // without VK_SHIFT: skip empty tickets (default)
      if (!AnalyzePositions(flags)) return(false);                // with VK_SHIFT:    log empty tickets
   }

   else if (cmd == "toggle-account-balance") {
      if (!ToggleAccountBalance()) return(false);
   }

   else if (cmd == "toggle-open-orders") {
      if (keys & F_VK_SHIFT != 0) {
         flags = F_SHOW_CUSTOM_POSITIONS;                         // with VK_SHIFT:
         ArrayResize(positions.config,          0);               // reparse configuration and show only custom positions
         ArrayResize(positions.config.comments, 0);               //
      }                                                           //
      else flags = NULL;                                          // without VK_SHIFT: show all open positions
      if (!ToggleOpenOrders(flags)) return(false);
   }

   else if (cmd == "toggle-trade-history") {
      if (keys & F_VK_SHIFT != 0) {
         flags = F_SHOW_CUSTOM_HISTORY;                           // with VK_SHIFT:
         ArrayResize(positions.config,          0);               // reparse configuration and show only custom history
         ArrayResize(positions.config.comments, 0);               //
      }                                                           //
      else flags = NULL;                                          // without VK_SHIFT: show all available history
      if (!ToggleTradeHistory(flags)) return(false);
   }

   else if (cmd == "toggle-profit-unit") {
      if (!CustomPositions.ToggleProfits()) return(false);
   }

   else if (cmd == "trade-account") {
      string key = StrReplace(params, ",", ":");
      if (!InitTradeAccount(key))  return(false);
      if (!UpdateAccountDisplay()) return(false);
      ArrayResize(positions.config,          0);                  // let the position configuration be reparsed
      ArrayResize(positions.config.comments, 0);
   }
   else return(!logNotice("onCommand(1)  unsupported command: \""+ cmd +":"+ params +":"+ keys +"\""));

   return(!catch("onCommand(2)"));
}


/**
 * Toggle the display of open orders.
 *
 * @param  int flags [optional] - control flags, supported values:
 *                                F_SHOW_CUSTOM_POSITIONS: show configured positions only (no unconfigured or pending ones)
 * @return bool - success status
 */
bool ToggleOpenOrders(int flags = NULL) {
   // read current status and toggle it
   bool showOrders = !GetOpenOrderDisplayStatus();

   // ON: display open orders
   if (showOrders) {
      int iNulls[], orders = ShowOpenOrders(iNulls, flags);
      if (orders == -1) return(false);
      if (!orders) {
         showOrders = false;                          // Reset status without open orders to continue with the "off" section
         PlaySoundEx("Plonk.wav");                    // which clears existing (e.g. orphaned) open order markers.
      }
   }

   // OFF: remove all open order markers
   if (!showOrders) {
      for (int i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);

         if (StringGetChar(name, 0) == '#') {
            if (ObjectType(name)==OBJ_ARROW) {
               int arrow = ObjectGet(name, OBJPROP_ARROWCODE);
               color clr = ObjectGet(name, OBJPROP_COLOR);

               if (arrow == SYMBOL_ORDEROPEN) {
                  if (clr!=CLR_OPEN_PENDING && clr!=CLR_OPEN_LONG && clr!=CLR_OPEN_SHORT) {
                     continue;
                  }
               }
               else if (arrow == SYMBOL_ORDERCLOSE) {
                  if (clr!=CLR_OPEN_TAKEPROFIT && clr!=CLR_OPEN_STOPLOSS) {
                     continue;
                  }
               }
               ObjectDelete(name);
            }
         }
      }
   }

   SetOpenOrderDisplayStatus(showOrders);             // store new status

   if (__isTesting) WindowRedraw();
   return(!catch("ToggleOpenOrders(2)"));
}


/**
 * Display open orders.
 *
 * @param  int customTickets[]  - skip resolving of tickets and display the passed tickets instead
 * @param  int flags [optional] - control flags, supported values:
 *                                F_SHOW_CUSTOM_POSITIONS: display configured custom positions only instead of all open orders
 *
 * @return int - number of displayed orders or EMPTY (-1) in case of errors
 */
int ShowOpenOrders(int customTickets[], int flags = NULL) {
   int      i, orders, ticket, type, colors[]={CLR_OPEN_LONG, CLR_OPEN_SHORT};
   datetime openTime;
   double   lots, units, openPrice, takeProfit, stopLoss;
   string   comment="", label1="", label2="", label3="", sTP="", sSL="", orderTypes[]={"buy", "sell", "buy limit", "sell limit", "buy stop", "sell stop"};
   int      customTicketsSize = ArraySize(customTickets);
   static int returnValue = 0;

   // on flag F_SHOW_CUSTOM_POSITIONS call AnalyzePositions() which recursively calls ShowOpenOrders() for each custom config line
   if (!customTicketsSize || flags & F_SHOW_CUSTOM_POSITIONS) {
      returnValue = 0;
      if (!customTicketsSize && flags & F_SHOW_CUSTOM_POSITIONS) {
         if (!AnalyzePositions(flags)) return(-1);
         return(returnValue);
      }
   }

   // mode.intern or custom tickets
   if (mode.intern || customTicketsSize) {
      orders = intOr(customTicketsSize, OrdersTotal());

      for (i=0; i < orders; i++) {
         if (customTicketsSize > 0) {
            if (customTickets[i] <= 3)                                continue;     // skip virtual positions
            if (!SelectTicket(customTickets[i], "ShowOpenOrders(1)")) break;
         }
         else if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;
         if (OrderSymbol() != Symbol()) continue;

         // read order data
         ticket     = OrderTicket();
         type       = OrderType();
         lots       = OrderLots();
         openTime   = OrderOpenTime();
         openPrice  = OrderOpenPrice();
         takeProfit = OrderTakeProfit();
         stopLoss   = OrderStopLoss();
         comment    = OrderMarkerText(type, OrderMagicNumber(), OrderComment());

         if (type > OP_SELL) {
            // a pending order
            label1 = StringConcatenate("#", ticket, " ", orderTypes[type], " ", DoubleToStr(lots, 2), " at ", NumberToStr(openPrice, PriceFormat));

            // create pending order marker
            if (ObjectFind(label1) == -1) ObjectCreate(label1, OBJ_ARROW, 0, 0, 0);
            ObjectSet    (label1, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
            ObjectSet    (label1, OBJPROP_COLOR,     CLR_OPEN_PENDING);
            ObjectSet    (label1, OBJPROP_TIME1,     Tick.time);
            ObjectSet    (label1, OBJPROP_PRICE1,    openPrice);
            ObjectSetText(label1, comment);
         }
         else {
            // an open position
            label1 = StringConcatenate("#", ticket, " ", orderTypes[type], " ", DoubleToStr(lots, 2), " at ", NumberToStr(openPrice, PriceFormat));

            // create TakeProfit marker
            if (takeProfit != NULL) {
               sTP    = StringConcatenate("TP: ", NumberToStr(takeProfit, PriceFormat));
               label2 = StringConcatenate(label1, ",  ", sTP);
               if (ObjectFind(label2) == -1) ObjectCreate(label2, OBJ_ARROW, 0, 0, 0);
               ObjectSet    (label2, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE  );
               ObjectSet    (label2, OBJPROP_COLOR,     CLR_OPEN_TAKEPROFIT);
               ObjectSet    (label2, OBJPROP_TIME1,     Tick.time);
               ObjectSet    (label2, OBJPROP_PRICE1,    takeProfit);
               ObjectSetText(label2, comment);
            }
            else sTP = "";

            // create StopLoss marker
            if (stopLoss != NULL) {
               sSL    = StringConcatenate("SL: ", NumberToStr(stopLoss, PriceFormat));
               label3 = StringConcatenate(label1, ",  ", sSL);
               if (ObjectFind(label3) == -1) ObjectCreate(label3, OBJ_ARROW, 0, 0, 0);
               ObjectSet    (label3, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
               ObjectSet    (label3, OBJPROP_COLOR,     CLR_OPEN_STOPLOSS);
               ObjectSet    (label3, OBJPROP_TIME1,     Tick.time);
               ObjectSet    (label3, OBJPROP_PRICE1,    stopLoss);
               ObjectSetText(label3, comment);
            }
            else sSL = "";

            // create open position marker
            if (ObjectFind(label1) == -1) ObjectCreate(label1, OBJ_ARROW, 0, 0, 0);
            ObjectSet    (label1, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
            ObjectSet    (label1, OBJPROP_COLOR,     colors[type]);
            ObjectSet    (label1, OBJPROP_TIME1,     openTime);
            ObjectSet    (label1, OBJPROP_PRICE1,    openPrice);
            ObjectSetText(label1, StrTrim(StringConcatenate(comment, "   ", sTP, "   ", sSL)));
         }
         returnValue++;
      }
      return(returnValue);
   }

   // mode.extern
   orders = ArrayRange(lfxOrders, 0);

   for (i=0; i < orders; i++) {
      if (!lfxOrders.bCache[i][BC.isPendingOrder]) /*&&*/ if (!lfxOrders.bCache[i][BC.isOpenPosition])
         continue;

      // Daten auslesen
      ticket     = lfxOrders.iCache[i][IC.ticket];
      type       =                     los.Type           (lfxOrders, i);
      units      =                     los.Units          (lfxOrders, i);
      openTime   = FxtToServerTime(Abs(los.OpenTime       (lfxOrders, i)));
      openPrice  =                     los.OpenPrice      (lfxOrders, i);
      takeProfit =                     los.TakeProfitPrice(lfxOrders, i);
      stopLoss   =                     los.StopLossPrice  (lfxOrders, i);
      comment    =                     los.Comment        (lfxOrders, i);

      if (type > OP_SELL) {
         // Pending-Order
         label1 = StringConcatenate("#", ticket, " ", orderTypes[type], " ", DoubleToStr(units, 1), " at ", NumberToStr(openPrice, PriceFormat));

         // Order anzeigen
         if (ObjectFind(label1) == -1) ObjectCreate(label1, OBJ_ARROW, 0, 0, 0);
         ObjectSet(label1, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet(label1, OBJPROP_COLOR,     CLR_OPEN_PENDING);
         ObjectSet(label1, OBJPROP_TIME1,     Tick.time);
         ObjectSet(label1, OBJPROP_PRICE1,    openPrice);
      }
      else {
         // offene Position
         label1 = StringConcatenate("#", ticket, " ", orderTypes[type], " ", DoubleToStr(units, 1), " at ", NumberToStr(openPrice, PriceFormat));

         // TakeProfit anzeigen                                   // TODO: !!! TP fixen, wenn tpValue oder tpPercent angegeben sind
         if (takeProfit != NULL) {
            sTP    = StringConcatenate("TP: ", NumberToStr(takeProfit, PriceFormat));
            label2 = StringConcatenate(label1, ",  ", sTP);
            if (ObjectFind(label2) == -1) ObjectCreate(label2, OBJ_ARROW, 0, 0, 0);
            ObjectSet(label2, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
            ObjectSet(label2, OBJPROP_COLOR,     CLR_OPEN_TAKEPROFIT);
            ObjectSet(label2, OBJPROP_TIME1,     Tick.time);
            ObjectSet(label2, OBJPROP_PRICE1,    takeProfit);
         }
         else sTP = "";

         // StopLoss anzeigen                                     // TODO: !!! SL fixen, wenn slValue oder slPercent angegeben sind
         if (stopLoss != NULL) {
            sSL    = StringConcatenate("SL: ", NumberToStr(stopLoss, PriceFormat));
            label3 = StringConcatenate(label1, ",  ", sSL);
            if (ObjectFind(label3) == -1) ObjectCreate(label3, OBJ_ARROW, 0, 0, 0);
            ObjectSet(label3, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
            ObjectSet(label3, OBJPROP_COLOR,     CLR_OPEN_STOPLOSS);
            ObjectSet(label3, OBJPROP_TIME1,     Tick.time);
            ObjectSet(label3, OBJPROP_PRICE1,    stopLoss);
         }
         else sSL = "";

         // Order anzeigen
         if (ObjectFind(label1) == -1) ObjectCreate(label1, OBJ_ARROW, 0, 0, 0);
         ObjectSet(label1, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet(label1, OBJPROP_COLOR,     colors[type]);
         ObjectSet(label1, OBJPROP_TIME1,     openTime);
         ObjectSet(label1, OBJPROP_PRICE1,    openPrice);
         if (StrStartsWith(comment, "#")) comment = StringConcatenate(lfxCurrency, ".", StrToInteger(StrSubstr(comment, 1)));
         else                             comment = "";
         ObjectSetText(label1, StrTrim(StringConcatenate(comment, "   ", sTP, "   ", sSL)));
      }
      returnValue++;
   }
   return(returnValue);
}


/**
 * Resolve the current 'ShowOpenOrders' display status.
 *
 * @return bool - ON/OFF
 */
bool GetOpenOrderDisplayStatus() {
   bool status = false;

   // look-up a status stored in the chart
   string label = "rsf."+ ProgramName() +".ShowOpenOrders";
   if (ObjectFind(label) != -1) {
      string sValue = ObjectDescription(label);
      if (StrIsInteger(sValue))
         status = (StrToInteger(sValue) != 0);
   }
   return(status);
}


/**
 * Store the given 'ShowOpenOrders' display status.
 *
 * @param  bool status - display status
 *
 * @return bool - success status
 */
bool SetOpenOrderDisplayStatus(bool status) {
   status = status!=0;

   // store status in the chart
   string label = "rsf."+ ProgramName() +".ShowOpenOrders";
   if (ObjectFind(label) == -1)
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ status);

   return(!catch("SetOpenOrderDisplayStatus(1)"));
}


/**
 * Toggle the display of closed trades.
 *
 * @param  int flags [optional] - control flags, supported values:
 *                                F_SHOW_CUSTOM_HISTORY: show the configured history only (not the total one)
 * @return bool - success status
 */
bool ToggleTradeHistory(int flags = NULL) {
   bool showHistory = !GetTradeHistoryDisplayStatus();   // read current status and toggle it

   // ON: display closed trades
   if (showHistory) {
      int iNulls[], trades = ShowTradeHistory(iNulls, flags);
      if (trades == -1) return(false);
      if (!trades) {                                     // Reset status without history to continue with the "off" section
         showHistory = false;                            // which clears existing (e.g. orphaned) history markers.
         PlaySoundEx("Plonk.wav");
      }
   }

   // OFF: remove closed trade markers
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

   SetTradeHistoryDisplayStatus(showHistory);            // store new status

   if (__isTesting) WindowRedraw();
   return(!catch("ToggleTradeHistory(2)"));
}


/**
 * Resolve the current 'ShowTradeHistory' display status.
 *
 * @return bool - ON/OFF
 */
bool GetTradeHistoryDisplayStatus() {
   bool status = false;

   // on error look-up a status stored in the chart
   string label = "rsf."+ ProgramName() +".ShowTradeHistory";
   if (ObjectFind(label) != -1) {
      string sValue = ObjectDescription(label);
      if (StrIsInteger(sValue))
         status = (StrToInteger(sValue) != 0);
   }
   return(status);
}


/**
 * Store the given 'ShowTradeHistory' display status.
 *
 * @param  bool status - display status
 *
 * @return bool - success status
 */
bool SetTradeHistoryDisplayStatus(bool status) {
   status = status!=0;

   // store status in the chart
   string label = "rsf."+ ProgramName() +".ShowTradeHistory";
   if (ObjectFind(label) == -1)
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ status);

   return(!catch("SetTradeHistoryDisplayStatus(1)"));
}


/**
 * Display the available or a custom trade history.
 *
 * @param  int customTickets[]  - skip history retrieval and display the passed tickets instead
 * @param  int flags [optional] - control flags, supported values:
 *                                F_SHOW_CUSTOM_HISTORY: display the configured history instead of the available one
 *
 * @return int - number of displayed trades or EMPTY (-1) in case of errors
 */
int ShowTradeHistory(int customTickets[], int flags = NULL) {
   // get drawing configuration
   string file    = GetAccountConfigPath(tradeAccount.company, tradeAccount.number); if (!StringLen(file)) return(EMPTY);
   string section = "Chart";
   string key     = "TradeHistory.ConnectTrades";
   bool success, drawConnectors = GetIniBool(file, section, key, GetConfigBool(section, key, true));  // check trade account first

   int      i, n, orders, ticket, type, markerColors[]={CLR_CLOSED_LONG, CLR_CLOSED_SHORT}, lineColors[]={Blue, Red};
   datetime openTime, closeTime;
   double   lots, units, openPrice, closePrice, openEquity, profit;
   string   sOpenPrice="", sClosePrice="", text="", openLabel="", lineLabel="", closeLabel="", sTypes[]={"buy", "sell"};
   int      customTicketsSize = ArraySize(customTickets);
   static int returnValue = 0;

   // on flag F_SHOW_CUSTOM_HISTORY call AnalyzePositions() which recursively calls ShowTradeHistory() for each custom config line
   if (!customTicketsSize || flags & F_SHOW_CUSTOM_HISTORY) {
      returnValue = 0;
      if (!customTicketsSize && flags & F_SHOW_CUSTOM_HISTORY) {
         if (!AnalyzePositions(flags)) return(-1);
         return(returnValue);
      }
   }

   // mode.intern or custom tickets
   if (mode.intern || customTicketsSize) {
      orders = intOr(customTicketsSize, OrdersHistoryTotal());

      // Sortierschlüssel aller geschlossenen Positionen auslesen und nach {CloseTime, OpenTime, Ticket} sortieren
      int sortKeys[][3];                                                // {CloseTime, OpenTime, Ticket}
      ArrayResize(sortKeys, orders);

      for (i=0, n=0; i < orders; i++) {
         if (customTicketsSize > 0) success = SelectTicket(customTickets[i], "ShowTradeHistory(1)");
         else                       success = OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
         if (!success)                  break;                          // während des Auslesens wurde der Anzeigezeitraum der History verkürzt
         if (OrderSymbol() != Symbol()) continue;
         if (OrderType() > OP_SELL)     continue;
         if (!OrderCloseTime())         continue;

         sortKeys[n][0] = OrderCloseTime();
         sortKeys[n][1] = OrderOpenTime();
         sortKeys[n][2] = OrderTicket();
         n++;
      }
      orders = n;
      ArrayResize(sortKeys, orders);
      SortClosedTickets(sortKeys);

      // Tickets sortiert einlesen
      int      tickets    []; ArrayResize(tickets,     orders);
      int      types      []; ArrayResize(types,       orders);
      double   lotSizes   []; ArrayResize(lotSizes,    orders);
      datetime openTimes  []; ArrayResize(openTimes,   orders);
      datetime closeTimes []; ArrayResize(closeTimes,  orders);
      double   openPrices []; ArrayResize(openPrices,  orders);
      double   closePrices[]; ArrayResize(closePrices, orders);
      double   commissions[]; ArrayResize(commissions, orders);
      double   swaps      []; ArrayResize(swaps,       orders);
      double   profits    []; ArrayResize(profits,     orders);
      string   comments   []; ArrayResize(comments,    orders);
      int      magics     []; ArrayResize(magics,      orders);

      for (i=0; i < orders; i++) {
         if (!SelectTicket(sortKeys[i][2], "ShowTradeHistory(2)")) return(-1);
         tickets    [i] = OrderTicket();
         types      [i] = OrderType();
         lotSizes   [i] = OrderLots();
         openTimes  [i] = OrderOpenTime();
         closeTimes [i] = OrderCloseTime();
         openPrices [i] = OrderOpenPrice();
         closePrices[i] = OrderClosePrice();
         commissions[i] = OrderCommission();
         swaps      [i] = OrderSwap();
         profits    [i] = OrderProfit();
         comments   [i] = OrderComment();
         magics     [i] = OrderMagicNumber();
      }

      // Hedges korrigieren: alle Daten dem ersten Ticket zuordnen und hedgendes Ticket verwerfen
      for (i=0; i < orders; i++) {
         if (tickets[i] && EQ(lotSizes[i], 0)) {                     // lotSize = 0: Hedge-Position

            // TODO: Prüfen, wie sich OrderComment() bei custom comments verhält.
            if (!StrStartsWithI(comments[i], "close hedge by #"))
               return(_EMPTY(catch("ShowTradeHistory(3)  #"+ tickets[i] +" - unknown comment for assumed hedging position: \""+ comments[i] +"\"", ERR_RUNTIME_ERROR)));

            // Gegenstück suchen
            ticket = StrToInteger(StringSubstr(comments[i], 16));
            for (n=0; n < orders; n++) {
               if (tickets[n] == ticket) break;
            }
            if (n == orders) return(_EMPTY(catch("ShowTradeHistory(4)  cannot find counterpart for hedging position #"+ tickets[i] +": \""+ comments[i] +"\"", ERR_RUNTIME_ERROR)));
            if (i == n     ) return(_EMPTY(catch("ShowTradeHistory(5)  both hedged and hedging position have the same ticket #"+ tickets[i] +": \""+ comments[i] +"\"", ERR_RUNTIME_ERROR)));

            int first  = Min(i, n);
            int second = Max(i, n);

            // Orderdaten korrigieren
            if (i == first) {
               lotSizes   [first] = lotSizes   [second];             // alle Transaktionsdaten in der ersten Order speichern
               commissions[first] = commissions[second];
               swaps      [first] = swaps      [second];
               profits    [first] = profits    [second];
            }
            closeTimes [first] = openTimes [second];
            closePrices[first] = openPrices[second];
            tickets   [second] = NULL;                               // hedgendes Ticket als verworfen markieren
         }
      }

      // Orders anzeigen
      for (i=0; i < orders; i++) {
         if (!tickets[i]) continue;                                  // verworfene Hedges überspringen
         sOpenPrice  = NumberToStr(openPrices [i], PriceFormat);
         sClosePrice = NumberToStr(closePrices[i], PriceFormat);
         text        = OrderMarkerText(types[i], magics[i], comments[i]);

         // Open-Marker anzeigen
         openLabel = StringConcatenate("#", tickets[i], " ", sTypes[types[i]], " ", DoubleToStr(lotSizes[i], 2), " at ", sOpenPrice);
         if (ObjectFind(openLabel) == -1) ObjectCreate(openLabel, OBJ_ARROW, 0, 0, 0);
         ObjectSet    (openLabel, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet    (openLabel, OBJPROP_COLOR,     markerColors[types[i]]);
         ObjectSet    (openLabel, OBJPROP_TIME1,     openTimes[i]);
         ObjectSet    (openLabel, OBJPROP_PRICE1,    openPrices[i]);
         ObjectSetText(openLabel, text);

         // Trendlinie anzeigen
         if (drawConnectors) {
            lineLabel = StringConcatenate("#", tickets[i], " ", sOpenPrice, " -> ", sClosePrice);
            if (ObjectFind(lineLabel) == -1) ObjectCreate(lineLabel, OBJ_TREND, 0, 0, 0, 0, 0);
            ObjectSet(lineLabel, OBJPROP_RAY,    false);
            ObjectSet(lineLabel, OBJPROP_STYLE,  STYLE_DOT);
            ObjectSet(lineLabel, OBJPROP_COLOR,  lineColors[types[i]]);
            ObjectSet(lineLabel, OBJPROP_BACK,   true);
            ObjectSet(lineLabel, OBJPROP_TIME1,  openTimes[i]);
            ObjectSet(lineLabel, OBJPROP_PRICE1, openPrices[i]);
            ObjectSet(lineLabel, OBJPROP_TIME2,  closeTimes[i]);
            ObjectSet(lineLabel, OBJPROP_PRICE2, closePrices[i]);
         }

         // Close-Marker anzeigen                                    // "#1 buy 0.10 GBPUSD at 1.53024 close[ by tester] at 1.52904"
         closeLabel = StringConcatenate(openLabel, " close at ", sClosePrice);
         if (ObjectFind(closeLabel) == -1) ObjectCreate(closeLabel, OBJ_ARROW, 0, 0, 0);
         ObjectSet    (closeLabel, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
         ObjectSet    (closeLabel, OBJPROP_COLOR,     CLR_CLOSED);
         ObjectSet    (closeLabel, OBJPROP_TIME1,     closeTimes[i]);
         ObjectSet    (closeLabel, OBJPROP_PRICE1,    closePrices[i]);
         ObjectSetText(closeLabel, text);
         returnValue++;
      }
      return(returnValue);
   }


   // mode.extern
   orders = ArrayRange(lfxOrders, 0);

   for (i=0; i < orders; i++) {
      if (!los.IsClosedPosition(lfxOrders, i)) continue;

      ticket      =                     los.Ticket    (lfxOrders, i);
      type        =                     los.Type      (lfxOrders, i);
      units       =                     los.Units     (lfxOrders, i);
      openTime    =     FxtToServerTime(los.OpenTime  (lfxOrders, i));
      openPrice   =                     los.OpenPrice (lfxOrders, i);
      openEquity  =                     los.OpenEquity(lfxOrders, i);
      closeTime   = FxtToServerTime(Abs(los.CloseTime (lfxOrders, i)));
      closePrice  =                     los.ClosePrice(lfxOrders, i);
      profit      =                     los.Profit    (lfxOrders, i);

      sOpenPrice  = NumberToStr(openPrice,  PriceFormat);
      sClosePrice = NumberToStr(closePrice, PriceFormat);

      // Open-Marker anzeigen
      openLabel = StringConcatenate("#", ticket, " ", sTypes[type], " ", DoubleToStr(units, 1), " at ", sOpenPrice);
      if (ObjectFind(openLabel) == -1) ObjectCreate(openLabel, OBJ_ARROW, 0, 0, 0);
      ObjectSet(openLabel, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
      ObjectSet(openLabel, OBJPROP_COLOR,     markerColors[type]);
      ObjectSet(openLabel, OBJPROP_TIME1,     openTime);
      ObjectSet(openLabel, OBJPROP_PRICE1,    openPrice);
         if (positions.absoluteProfits || !openEquity) text = ifString(profit > 0, "+", "") + DoubleToStr(profit, 2);
         else                                          text = ifString(profit > 0, "+", "") + DoubleToStr(profit/openEquity * 100, 2) +"%";
      ObjectSetText(openLabel, text);

      // Trendlinie anzeigen
      if (drawConnectors) {
         lineLabel = StringConcatenate("#", ticket, " ", sOpenPrice, " -> ", sClosePrice);
         if (ObjectFind(lineLabel) == -1) ObjectCreate(lineLabel, OBJ_TREND, 0, 0, 0, 0, 0);
         ObjectSet(lineLabel, OBJPROP_RAY,    false);
         ObjectSet(lineLabel, OBJPROP_STYLE,  STYLE_DOT);
         ObjectSet(lineLabel, OBJPROP_COLOR,  lineColors[type]);
         ObjectSet(lineLabel, OBJPROP_BACK,   true);
         ObjectSet(lineLabel, OBJPROP_TIME1,  openTime);
         ObjectSet(lineLabel, OBJPROP_PRICE1, openPrice);
         ObjectSet(lineLabel, OBJPROP_TIME2,  closeTime);
         ObjectSet(lineLabel, OBJPROP_PRICE2, closePrice);
      }

      // Close-Marker anzeigen                                    // "#1 buy 0.10 GBPUSD at 1.53024 close[ by tester] at 1.52904"
      closeLabel = StringConcatenate(openLabel, " close at ", sClosePrice);
      if (ObjectFind(closeLabel) == -1) ObjectCreate(closeLabel, OBJ_ARROW, 0, 0, 0);
      ObjectSet    (closeLabel, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
      ObjectSet    (closeLabel, OBJPROP_COLOR,     CLR_CLOSED);
      ObjectSet    (closeLabel, OBJPROP_TIME1,     closeTime);
      ObjectSet    (closeLabel, OBJPROP_PRICE1,    closePrice);
      ObjectSetText(closeLabel, text);
      returnValue++;
   }
   return(returnValue);
}


/**
 * Create an order marker text for the specified order details.
 *
 * @param  int    type    - order type
 * @param  int    magic   - magic number
 * @param  string comment - order comment
 *
 * @return string - order marker text or an empty string if the strategy is unknown
 */
string OrderMarkerText(int type, int magic, string comment) {
   string text = "";
   int sid = magic >> 22;                                   // strategy id: 10 bit starting at bit 22

   switch (sid) {
      // Duel
      case 105:
         if (StrStartsWith(comment, "Duel")) {
            text = comment;
         }
         else {
            int sequenceId = magic >> 8 & 0x3FFF;           // sequence id: 14 bit starting at bit 8
            int level      = magic >> 0 & 0xFF;             // level:        8 bit starting at bit 0
            if (level > 127) level -= 256;                  //               0..255 => -128..127      (convert uint to int)
            text = "Duel."+ ifString(IsLongOrderType(type), "L", "S") +"."+ sequenceId +"."+ NumberToStr(level, "+.");
         }
         break;

      default:
         if      (comment == "partial close")                 text = "";
         else if (StrStartsWith(comment, "from #"))           text = "";
         else if (StrStartsWith(comment, "close hedge by #")) text = "";
         else if (StrEndsWith  (comment, "[tp]"))             text = StrLeft(comment, -4);
         else if (StrEndsWith  (comment, "[sl]"))             text = StrLeft(comment, -4);
         else                                                 text = comment;
   }

   return(text);
}


/**
 * Schaltet die Anzeige der PnL-Beträge der Positionen zwischen "absolut" und "prozentual" um.
 *
 * @return bool - success status
 */
bool CustomPositions.ToggleProfits() {
   positions.absoluteProfits = !positions.absoluteProfits;     // toggle status and update positions
   return(UpdatePositions());
}


/**
 * Toggle the chart display of the account balance.
 *
 * @return bool - success status
 */
bool ToggleAccountBalance() {
   bool enabled = !GetAccountBalanceDisplayStatus();           // get current display status and toggle it

   if (enabled) {
      string sBalance = " ";
      if (mode.intern) {
         sBalance = "Balance: " + DoubleToStr(AccountBalance(), 2) +" "+ AccountCurrency();
      }
      else {
         enabled = false;                                      // mode.extern not yet implemented
         PlaySoundEx("Plonk.wav");
      }
      ObjectSetText(label.accountBalance, sBalance, 9, "Tahoma", SlateGray);
   }
   else {
      ObjectSetText(label.accountBalance, " ", 1);
   }

   int error = GetLastError();
   if (error && error!=ERR_OBJECT_DOES_NOT_EXIST)              // on ObjectDrag or opened "Properties" dialog
      return(!catch("AccountBalance(1)", error));

   SetAccountBalanceDisplayStatus(enabled);                    // store new display status

   if (__isTesting) WindowRedraw();
   return(!catch("ToggleAccountBalance(2)"));
}


/**
 * Return the stored account balance display status.
 *
 * @return bool - status: enabled/disabled
 */
bool GetAccountBalanceDisplayStatus() {
   string label = ProgramName() +".ShowAccountBalance";        // TODO: also store status in the chart window
   if (ObjectFind(label) != -1)
      return(StrToInteger(ObjectDescription(label)) != 0);
   return(false);
}


/**
 * Store the account balance display status.
 *
 * @param  bool status - Status
 *
 * @return bool - success status
 */
bool SetAccountBalanceDisplayStatus(bool status) {
   status = status!=0;

   string label = ProgramName() +".ShowAccountBalance";        // TODO: also read status from the chart window
   if (ObjectFind(label) == -1)
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ status, 0);

   return(!catch("SetAccountBalanceDisplayStatus(1)"));
}


/**
 * Create text labels for the different chart infos.
 *
 * @return bool - success status
 */
bool CreateLabels() {
   // define labels
   string programName = ProgramName();
   label.instrument     = programName +".Instrument";
   label.price          = programName +".Price";
   label.spread         = programName +".Spread";
   label.customPosition = programName +".CustomPosition";                           // base value for actual row/column labels
   label.totalPosition  = programName +".TotalPosition";
   label.unitSize       = programName +".UnitSize";
   label.accountBalance = programName +".AccountBalance";
   label.orderCounter   = programName +".OrderCounter";
   label.tradeAccount   = programName +".TradeAccount";
   label.stopoutLevel   = programName +".StopoutLevel";

   int corner, xDist, yDist, build=GetTerminalBuild();

   // instrument name (the text is set immediately here)
   if (build <= 509) {                                                              // only builds <= 509, newer builds already display the symbol here
      if (ObjectFind(label.instrument) == -1) if (!ObjectCreateRegister(label.instrument, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
      ObjectSet(label.instrument, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label.instrument, OBJPROP_XDISTANCE, ifInt(build < 479, 4, 13));    // On builds > 478 the label is inset to account for the arrow of the
      ObjectSet(label.instrument, OBJPROP_YDISTANCE, ifInt(build < 479, 1,  3));    // "One-Click-Trading" feature.
      string name = GetLongSymbolNameOrAlt(Symbol(), GetSymbolName(Symbol()));
      if      (StrEndsWithI(Symbol(), "_ask")) name = name +" (Ask)";
      else if (StrEndsWithI(Symbol(), "_avg")) name = name +" (Avg)";
      ObjectSetText(label.instrument, name, 9, "Tahoma Fett", Black);
   }

   // price
   if (ObjectFind(label.price) == -1) if (!ObjectCreateRegister(label.price, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
   ObjectSet    (label.price, OBJPROP_CORNER, CORNER_TOP_RIGHT);
   ObjectSet    (label.price, OBJPROP_XDISTANCE, 14);
   ObjectSet    (label.price, OBJPROP_YDISTANCE, 15);
   ObjectSetText(label.price, " ", 1);

   // spread
   corner = CORNER_TOP_RIGHT;
   xDist  = 33;
   yDist  = 38;
   if (ObjectFind(label.spread) == -1) if (!ObjectCreateRegister(label.spread, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
   ObjectSet    (label.spread, OBJPROP_CORNER,   corner);
   ObjectSet    (label.spread, OBJPROP_XDISTANCE, xDist);
   ObjectSet    (label.spread, OBJPROP_YDISTANCE, yDist);
   ObjectSetText(label.spread, " ", 1);

   // unit size
   corner = unitSize.corner;
   xDist  = 9;
   switch (corner) {
      case CORNER_TOP_LEFT:                 break;
      case CORNER_TOP_RIGHT:    yDist = 58; break;                // y(spread) + 20
      case CORNER_BOTTOM_LEFT:              break;
      case CORNER_BOTTOM_RIGHT: yDist = 9;  break;
   }
   if (ObjectFind(label.unitSize) == -1) if (!ObjectCreateRegister(label.unitSize, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
   ObjectSet    (label.unitSize, OBJPROP_CORNER,   corner);
   ObjectSet    (label.unitSize, OBJPROP_XDISTANCE, xDist);
   ObjectSet    (label.unitSize, OBJPROP_YDISTANCE, yDist);
   ObjectSetText(label.unitSize, " ", 1);

   // total position
   corner = totalPosition.corner;
   xDist  = 9;
   yDist  = ObjectGet(label.unitSize, OBJPROP_YDISTANCE) + 20;    // 1 line above unitsize
   if (ObjectFind(label.totalPosition) == -1) if (!ObjectCreateRegister(label.totalPosition, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
   ObjectSet    (label.totalPosition, OBJPROP_CORNER,   corner);
   ObjectSet    (label.totalPosition, OBJPROP_XDISTANCE, xDist);
   ObjectSet    (label.totalPosition, OBJPROP_YDISTANCE, yDist);
   ObjectSetText(label.totalPosition, " ", 1);

   // account balance
   if (ObjectFind(label.accountBalance) == -1) if (!ObjectCreateRegister(label.accountBalance, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
   ObjectSet    (label.accountBalance, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet    (label.accountBalance, OBJPROP_XDISTANCE, 330);
   ObjectSet    (label.accountBalance, OBJPROP_YDISTANCE,   9);
   ObjectSetText(label.accountBalance, " ", 1);

   // order counter
   if (ObjectFind(label.orderCounter) == -1) if (!ObjectCreateRegister(label.orderCounter, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
   ObjectSet    (label.orderCounter, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet    (label.orderCounter, OBJPROP_XDISTANCE, 500);
   ObjectSet    (label.orderCounter, OBJPROP_YDISTANCE,   9);
   ObjectSetText(label.orderCounter, " ", 1);

   // trade account
   if (ObjectFind(label.tradeAccount) == -1) if (!ObjectCreateRegister(label.tradeAccount, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
   ObjectSet    (label.tradeAccount, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet    (label.tradeAccount, OBJPROP_XDISTANCE, 6);
   ObjectSet    (label.tradeAccount, OBJPROP_YDISTANCE, 4);
   ObjectSetText(label.tradeAccount, " ", 1);

   return(!catch("CreateLabels(1)"));
}


/**
 * Update the current price (top-right).
 *
 * @return bool - success status
 */
bool UpdatePrice() {
   double price = Bid;

   if (!Bid) {                                           // fall-back to Close[0]: Symbol (noch) nicht subscribed (Start, Account-/Templatewechsel, Offline-Chart)
      price = NormalizeDouble(Close[0], Digits);         // History-Daten können unnormalisiert sein, wenn sie nicht von MetaTrader erstellt wurden
   }
   else {
      switch (displayedPrice) {
         case PRICE_BID   : price =  Bid;                                   break;
         case PRICE_ASK   : price =  Ask;                                   break;
         case PRICE_MEDIAN: price = NormalizeDouble((Bid + Ask)/2, Digits); break;
      }
   }
   ObjectSetText(label.price, NumberToStr(price, PriceFormat), 13, "Microsoft Sans Serif", Black);

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)       // on ObjectDrag or opened "Properties" dialog
      return(true);
   return(!catch("UpdatePrice(1)", error));
}


/**
 * Update the current spread (top-right).
 *
 * @return bool - success status
 */
bool UpdateSpread() {
   string sSpread = " ";
   if (Bid > 0) {                                        // don't use MarketInfo(MODE_SPREAD) as in tester it's invalid
      sSpread = PipToStr((Ask-Bid)/Pip);                 // no display if the symbol is not yet subscribed (e.g. start, account/template change, offline chart)
   }
   ObjectSetText(label.spread, sSpread, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)       // on ObjectDrag or opened "Properties" dialog
      return(true);
   return(!catch("UpdateSpread(1)", error));
}


/**
 * Calculate and update the displayed unitsize for the configured risk profile (bottom-right).
 *
 * @return bool - success status
 */
bool UpdateUnitSize() {
   if (__isTesting)             return(true);            // skip in tester
   if (!mm.done) {
      if (!CalculateUnitSize()) return(false);           // on error
      if (!mm.done)             return(true);            // on terminal not yet ready
   }

   string text = "";

   if (mode.intern) {
      if (mm.riskPercent != NULL) {
         text = StringConcatenate("R", DoubleToStr(mm.riskPercent, 0), "%/");
      }

      if (mm.riskRange != NULL) {
         double range = mm.riskRange;
         if (mm.cfgRiskRangeIsADR) {
            if (Close[0] > 300 && range >= 3) range = MathRound(range);
            else                              range = NormalizeDouble(range, PipDigits);
            text = StringConcatenate(text, "ADR=");
         }
         if (Close[0] > 300 && range >= 3) string sRange = NumberToStr(range, ",'.2+");
         else                                     sRange = NumberToStr(NormalizeDouble(range/Pip, 1), ".+") +" pip";
         text = StringConcatenate(text, sRange);
      }

      if (mm.leverage != NULL) {
         text = StringConcatenate(text, "     L", DoubleToStr(mm.leverage, 1), "      ", NumberToStr(mm.leveragedLotsNormalized, ".+"), " lot");
      }
   }
   ObjectSetText(label.unitSize, text, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)       // on ObjectDrag or opened "Properties" dialog
      return(true);
   return(!catch("UpdateUnitSize(1)", error));
}


/**
 * Update detailed P/L stats (bottom-left) and total open position (bottom-right).
 *
 * @return bool - success status
 */
bool UpdatePositions() {
   if (!positions.analyzed) {
      if (!AnalyzePositions())  return(false);
   }
   if (mode.intern && !mm.done) {
      if (!CalculateUnitSize()) return(false);
      if (!mm.done)             return(true);                  // on terminal not yet ready
   }

   // total open position bottom-right
   string sCurrentPosition = "";
   if      (!isPosition)    sCurrentPosition = " ";
   else if (!totalPosition) sCurrentPosition = StringConcatenate("Position:    ±", NumberToStr(longPosition, ",'.+"), " lot (hedged)");
   else {
      double currentUnits = 0;
      string sCurrentUnits = "";
      if (mm.leveragedLots != 0) {
         currentUnits  = MathAbs(totalPosition)/mm.leveragedLots;
         sCurrentUnits = StringConcatenate("U", NumberToStr(currentUnits, ",'.1R"), "    ");
      }
      string sRisk = "";
      if (mm.riskPercent && currentUnits) {
         sRisk = StringConcatenate("R", NumberToStr(mm.riskPercent * currentUnits, ",'.0R"), "%    ");
      }
      string sCurrentLeverage = "";
      if (mm.unleveragedLots != 0) sCurrentLeverage = StringConcatenate("L", NumberToStr(MathAbs(totalPosition)/mm.unleveragedLots, ",'.1R"), "    ");

      sCurrentPosition = StringConcatenate("Position:    ", sRisk, sCurrentUnits, sCurrentLeverage, NumberToStr(totalPosition, "+,'.+"), " lot");
   }
   ObjectSetText(label.totalPosition, sCurrentPosition, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (error && error!=ERR_OBJECT_DOES_NOT_EXIST)              // on ObjectDrag or opened "Properties" dialog
      return(!catch("UpdatePositions(1)", error));

   // pending order marker bottom-right
   string label = ProgramName() +".PendingTickets";
   if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
   ObjectSet(label, OBJPROP_CORNER,     CORNER_BOTTOM_RIGHT);
   ObjectSet(label, OBJPROP_XDISTANCE,  12);
   ObjectSet(label, OBJPROP_YDISTANCE,  ifInt(isPosition, 48, 30));
   ObjectSet(label, OBJPROP_TIMEFRAMES, ifInt(isPendings, OBJ_PERIODS_ALL, OBJ_PERIODS_NONE));
   ObjectSetText(label, "n", 6, "Webdings", Orange);           // a Webdings "dot"

   // prepare rows for custom positions bottom-left
   static int  lines, cols, percentCol, commentCol, xPrev, xOffset[], xDist, yStart=6, yDist;
   static bool lastAbsoluteProfits;
   if (!ArraySize(xOffset) || positions.absoluteProfits!=lastAbsoluteProfits) {
      ArrayResize(xOffset, 0);
      if (positions.absoluteProfits) {
         // 8 columns: Type:  Lots  BE:  BePrice  Profit:  Amount  Percent  Comment
         int cols8[] = {9,    46,   83,  28,      66,      39,     87,      61};    // offsets to the previous column
         ArrayCopy(xOffset, cols8);
      }
      else {
         // 7 columns: Type:  Lots  BE:  BePrice  Profit:  Percent  Comment
         int cols7[] = {9,    46,   83,  28,      66,      39,      61};
         ArrayCopy(xOffset, cols7);
      }
      cols                = ArraySize(xOffset);
      percentCol          = cols - 2;
      commentCol          = cols - 1;
      lastAbsoluteProfits = positions.absoluteProfits;

      // nach Reinitialisierung alle vorhandenen Zeilen löschen
      while (lines > 0) {
         for (int col=0; col < 8; col++) {                     // always test all possible columns
            label = StringConcatenate(label.customPosition, ".line", lines, "_col", col);
            if (ObjectFind(label) != -1) ObjectDelete(label);
         }
         label = StringConcatenate(label.customPosition, ".line", lines, "_pm");
         if (ObjectFind(label) != -1) ObjectDelete(label);
         label = StringConcatenate(label.customPosition, ".line", lines, "_lm");
         if (ObjectFind(label) != -1) ObjectDelete(label);
         lines--;
      }
   }

   // create new rows as needed
   int positions = ArrayRange(positions.iData, 0);
   if (mode.extern) positions = lfxOrders.openPositions;

   while (lines < positions) {
      lines++;
      xPrev = 0;
      yDist = yStart + (lines-1)*(positions.fontSize+8);

      for (col=0; col < cols; col++) {
         label = StringConcatenate(label.customPosition, ".line", lines, "_col", col);
         xDist = xPrev + xOffset[col];
         if (!ObjectCreateRegister(label, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
         ObjectSet    (label, OBJPROP_CORNER, CORNER_BOTTOM_LEFT);
         ObjectSet    (label, OBJPROP_XDISTANCE, xDist);
         ObjectSet    (label, OBJPROP_YDISTANCE, yDist);
         ObjectSetText(label, " ", 1);
         xPrev = xDist;
      }
      label = StringConcatenate(label.customPosition, ".line", lines, "_pm");
      if (!ObjectCreateRegister(label, OBJ_HLINE, 0, 0, 0, 0, 0, 0, 0)) return(false);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
      label = StringConcatenate(label.customPosition, ".line", lines, "_lm");
      if (!ObjectCreateRegister(label, OBJ_HLINE, 0, 0, 0, 0, 0, 0, 0)) return(false);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   }

   // remove existing surplus rows
   while (lines > positions) {
      for (col=0; col < cols; col++) {
         label = StringConcatenate(label.customPosition, ".line", lines, "_col", col);
         if (ObjectFind(label) != -1) ObjectDelete(label);
      }
      label = StringConcatenate(label.customPosition, ".line", lines, "_pm");
      if (ObjectFind(label) != -1) ObjectDelete(label);
      label = StringConcatenate(label.customPosition, ".line", lines, "_lm");
      if (ObjectFind(label) != -1) ObjectDelete(label);
      lines--;
   }

   // write custom position rows from bottom to top: "{Type}: {Lots}   BE|Dist: {Price|Pip}   Profit: [{Amount} ]{Percent}   {Comment}"
   string sLotSize="", sDistance="", sBreakeven="", sAdjustedProfit="", sProfitPct="", sComment="";
   color  fontColor;
   int    line;

   // update display of internal custom positions
   if (mode.intern) {
      for (int i=positions-1; i >= 0; i--) {
         line++;
         if      (positions.iData[i][I_CONFIG_TYPE  ] == CONFIG_VIRTUAL  ) fontColor = positions.fontColor.virtual;
         else if (positions.iData[i][I_POSITION_TYPE] == POSITION_HISTORY) fontColor = positions.fontColor.history;
         else                                                              fontColor = positions.fontColor.open;

         if (!positions.dData[i][I_ADJUSTED_PROFIT])    sAdjustedProfit = "";
         else                                           sAdjustedProfit = StringConcatenate(" (", DoubleToStr(positions.dData[i][I_ADJUSTED_PROFIT], 2), ")");

         if (positions.iData[i][I_COMMENT_INDEX] == -1) sComment = " ";
         else                                           sComment = positions.config.comments[positions.iData[i][I_COMMENT_INDEX]];

         // history only
         if (positions.iData[i][I_POSITION_TYPE] == POSITION_HISTORY) {
            // "{Type}: {Lots}   BE|Dist: {Price|Pip}   Profit: [{Amount} ]{Percent}   {Comment}"
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col0"           ), typeDescriptions[positions.iData[i][I_POSITION_TYPE]],                   positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col1"           ), " ",                                                                     positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col2"           ), " ",                                                                     positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col3"           ), " ",                                                                     positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col4"           ), "Profit:",                                                               positions.fontSize, positions.fontName, fontColor);
            if (positions.absoluteProfits)
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col5"           ), DoubleToStr(positions.dData[i][I_FULL_PROFIT_ABS], 2) + sAdjustedProfit, positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col", percentCol), DoubleToStr(positions.dData[i][I_FULL_PROFIT_PCT], 2) +"%",              positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col", commentCol), sComment,                                                                positions.fontSize, positions.fontName, fontColor);
         }

         // directional or hedged
         else {
            // "{Type}: {Lots}   BE|Dist: {Price|Pip}   Profit: [{Amount} ]{Percent}   {Comment}"
            // hedged
            if (positions.iData[i][I_POSITION_TYPE] == POSITION_HEDGE) {
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col0"), typeDescriptions[positions.iData[i][I_POSITION_TYPE]],                           positions.fontSize, positions.fontName, fontColor);
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col1"),      NumberToStr(positions.dData[i][I_HEDGED_LOTS  ], ".+") +" lot",             positions.fontSize, positions.fontName, fontColor);
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col2"), "Dist:",                                                                         positions.fontSize, positions.fontName, fontColor);
                  if (!positions.dData[i][I_PIP_DISTANCE]) sDistance = "...";
                  else                                     sDistance = PipToStr(positions.dData[i][I_PIP_DISTANCE], true, true);
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col3"), sDistance,                                                                       positions.fontSize, positions.fontName, fontColor);
            }

            // not hedged
            else {
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col0"), typeDescriptions[positions.iData[i][I_POSITION_TYPE]],                           positions.fontSize, positions.fontName, fontColor);
                  if (!positions.dData[i][I_HEDGED_LOTS]) sLotSize = NumberToStr(positions.dData[i][I_DIRECTIONAL_LOTS], ".+");
                  else                                    sLotSize = NumberToStr(positions.dData[i][I_DIRECTIONAL_LOTS], ".+") +" ±"+ NumberToStr(positions.dData[i][I_HEDGED_LOTS], ".+");
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col1"), sLotSize +" lot",                                                                positions.fontSize, positions.fontName, fontColor);
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col2"), "BE:",                                                                           positions.fontSize, positions.fontName, fontColor);
                  if (!positions.dData[i][I_BREAKEVEN_PRICE]) sBreakeven = "...";
                  else                                        sBreakeven = NumberToStr(positions.dData[i][I_BREAKEVEN_PRICE], PriceFormat);
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col3"), sBreakeven,                                                                      positions.fontSize, positions.fontName, fontColor);
            }

            // hedged and not-hedged
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col4"           ), "Profit:",                                                               positions.fontSize, positions.fontName, fontColor);
            if (positions.absoluteProfits)
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col5"           ), DoubleToStr(positions.dData[i][I_FULL_PROFIT_ABS], 2) + sAdjustedProfit, positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col", percentCol), DoubleToStr(positions.dData[i][I_FULL_PROFIT_PCT], 2) +"%",              positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col", commentCol), sComment,                                                                positions.fontSize, positions.fontName, fontColor);
         }

         // update PL markers
         label = StringConcatenate(label.customPosition, ".line", line, "_pm");
         if (!positions.dData[i][I_PROFIT_MARKER_PRICE]) {
            ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
         }
         else {
            ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_ALL);
            ObjectSet    (label, OBJPROP_STYLE,      STYLE_DASHDOTDOT);
            ObjectSet    (label, OBJPROP_COLOR,      DodgerBlue);
            ObjectSet    (label, OBJPROP_BACK,       false);
            ObjectSet    (label, OBJPROP_PRICE1,     positions.dData[i][I_PROFIT_MARKER_PRICE]);
            ObjectSetText(label, ifString(positions.iData[i][I_POSITION_TYPE]==POSITION_LONG, "L ", "S ") + sLotSize +" x "+ sBreakeven +"  PL "+ NumberToStr(positions.dData[i][I_PROFIT_MARKER_PERCENT], "+.+") +"%");
         }

         label = StringConcatenate(label.customPosition, ".line", line, "_lm");
         if (!positions.dData[i][I_LOSS_MARKER_PRICE]) {
            ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
         }
         else {
            ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_ALL);
            ObjectSet    (label, OBJPROP_STYLE,      STYLE_DASHDOTDOT);
            ObjectSet    (label, OBJPROP_COLOR,      OrangeRed);
            ObjectSet    (label, OBJPROP_BACK,       false);
            ObjectSet    (label, OBJPROP_PRICE1,     positions.dData[i][I_LOSS_MARKER_PRICE]);
            ObjectSetText(label, ifString(positions.iData[i][I_POSITION_TYPE]==POSITION_LONG, "L ", "S ") + sLotSize +" x "+ sBreakeven +"  DD "+ NumberToStr(positions.dData[i][I_LOSS_MARKER_PERCENT], "+.+") +"%");
         }
      }
   }

   // update display of external custom positions
   if (mode.extern) {
      fontColor = positions.fontColor.open;
      for (i=ArrayRange(lfxOrders, 0)-1; i >= 0; i--) {
         if (lfxOrders.bCache[i][BC.isOpenPosition]) {
            line++;
            // "{Type}: {Lots}   BE|Dist: {Price|Pip}   Profit: [{Amount} ]{Percent}   {Comment}"
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col0"           ), typeDescriptions[los.Type(lfxOrders, i)+1],                              positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col1"           ), NumberToStr(los.Units    (lfxOrders, i), ".+") +" units",                positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col2"           ), "BE:",                                                                   positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col3"           ), NumberToStr(los.OpenPrice(lfxOrders, i), PriceFormat),                   positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col4"           ), "Profit:",                                                               positions.fontSize, positions.fontName, fontColor);
            if (positions.absoluteProfits)
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col5"           ), DoubleToStr(lfxOrders.dCache[i][DC.profit], 2),                          positions.fontSize, positions.fontName, fontColor);
               double profitPct = lfxOrders.dCache[i][DC.profit] / los.OpenEquity(lfxOrders, i) * 100;
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col", percentCol), DoubleToStr(profitPct, 2) +"%",                                          positions.fontSize, positions.fontName, fontColor);
               sComment = StringConcatenate(los.Comment(lfxOrders, i), " ");
               if (StringGetChar(sComment, 0) == '#')
                  sComment = StringConcatenate(lfxCurrency, ".", StrSubstr(sComment, 1));
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col", commentCol), sComment,                                                                positions.fontSize, positions.fontName, fontColor);
         }
      }
   }

   return(!catch("UpdatePositions(3)"));
}


/**
 * Update the number of open orders and the account's open order limit.
 *
 * @return bool - success status
 */
bool UpdateOrderCounter() {
   static int showLimit=INT_MAX, warnLimit=INT_MAX, alertLimit=INT_MAX, maxOpenOrders;
   static color defaultColor=SlateGray, warnColor=DarkOrange, alertColor=Red;

   if (!maxOpenOrders) {
      maxOpenOrders = GetGlobalConfigInt("Accounts", GetAccountNumber() +".maxOpenTickets.total", -1);
      if (!maxOpenOrders) maxOpenOrders = -1;

      if (maxOpenOrders > 0) {
         alertLimit = Min(Round(0.9  * maxOpenOrders), maxOpenOrders-5);
         warnLimit  = Min(Round(0.75 * maxOpenOrders), alertLimit   -5);
         showLimit  = Min(Round(0.5  * maxOpenOrders), warnLimit    -5);
      }
   }

   string sText = " ";
   color objectColor = defaultColor;

   int orders = OrdersTotal();
   if (orders >= showLimit) {
      if      (orders >= alertLimit) objectColor = alertColor;
      else if (orders >= warnLimit ) objectColor = warnColor;
      sText = StringConcatenate(orders, " open orders (max. ", maxOpenOrders, ")");
   }
   ObjectSetText(label.orderCounter, sText, 8, "Tahoma Fett", objectColor);

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                                     // on ObjectDrag or opened "Properties" dialog
      return(true);
   return(!catch("UpdateOrderCounter(1)", error));
}


/**
 * Aktualisiert die Anzeige eines externen oder Remote-Accounts.
 *
 * @return bool - success status
 */
bool UpdateAccountDisplay() {
   string text = "";

   if (mode.intern) {
      ObjectSetText(label.tradeAccount, " ", 1);
   }
   else {
      ObjectSetText(label.unitSize, " ", 1);
      text = tradeAccount.name +": "+ tradeAccount.company +", "+ tradeAccount.number +", "+ tradeAccount.currency;
      ObjectSetText(label.tradeAccount, text, 8, "Arial Fett", ifInt(tradeAccount.type==ACCOUNT_TYPE_DEMO, LimeGreen, DarkOrange));
   }

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                                     // on ObjectDrag or opened "Properties" dialog
      return(true);
   return(!catch("UpdateAccountDisplay(1)", error));
}


/**
 * Update the account's stopout level marker.
 *
 * @return bool - success status
 */
bool UpdateStopoutLevel() {
   if (!positions.analyzed) /*&&*/ if (!AnalyzePositions())
      return(false);

   if (!mode.intern || !totalPosition) {                                               // keine effektive Position im Markt: vorhandene Marker löschen
      ObjectDelete(label.stopoutLevel);
      int error = GetLastError();
      if (error && error!=ERR_OBJECT_DOES_NOT_EXIST)                                   // on ObjectDrag or opened "Properties" dialog
         return(!catch("UpdateStopoutLevel(1)", error));
      return(true);
   }

   // Stopout-Preis berechnen
   double equity     = AccountEquity();
   double usedMargin = AccountMargin();
   int    soMode     = AccountStopoutMode();
   double soEquity   = AccountStopoutLevel();  if (soMode != MSM_ABSOLUTE) soEquity = usedMargin * soEquity/100;
   double tickSize   = MarketInfoEx(Symbol(), MODE_TICKSIZE, error, "UpdateStopoutLevel(2)");
   double tickValue  = MarketInfoEx(Symbol(), MODE_TICKVALUE, error, "UpdateStopoutLevel(3)") * MathAbs(totalPosition);
   if (!Bid || !tickSize || !tickValue) {
      if (!Bid || error==ERR_SYMBOL_NOT_AVAILABLE)
         return(SetLastError(ERS_TERMINAL_NOT_YET_READY));                             // Symbol noch nicht subscribed (possible on start, change of account/template, offline chart, MarketWatch -> Hide all)
      return(!catch("UpdateStopoutLevel(4)", error));
   }
   double soDistance = (equity - soEquity)/tickValue * tickSize;
   double soPrice;
   if (totalPosition > 0) soPrice = NormalizeDouble(Bid - soDistance, Digits);
   else                   soPrice = NormalizeDouble(Ask + soDistance, Digits);

   // Stopout-Preis anzeigen
   if (ObjectFind(label.stopoutLevel) == -1) if (!ObjectCreateRegister(label.stopoutLevel, OBJ_HLINE, 0, 0, 0, 0, 0, 0, 0)) return(false);
   ObjectSet(label.stopoutLevel, OBJPROP_STYLE,  STYLE_SOLID);
   ObjectSet(label.stopoutLevel, OBJPROP_COLOR,  OrangeRed);
   ObjectSet(label.stopoutLevel, OBJPROP_BACK,   true);
   ObjectSet(label.stopoutLevel, OBJPROP_PRICE1, soPrice);
      if (soMode == MSM_PERCENT) string text = StringConcatenate("Stopout  ", Round(AccountStopoutLevel()), "%  =  ", NumberToStr(soPrice, PriceFormat));
      else                              text = StringConcatenate("Stopout  ", DoubleToStr(soEquity, 2), AccountCurrency(), "  =  ", NumberToStr(soPrice, PriceFormat));
   ObjectSetText(label.stopoutLevel, text);

   error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                                     // on ObjectDrag or opened "Properties" dialog
      return(true);
   return(!catch("UpdateStopoutLevel(5)", error));
}


/**
 * Resolve the total open position, group/store it according to the custom configuration and calculate PL stats.
 *
 * @param  int flags [optional] - control flags, supported values:
 *                                F_LOG_TICKETS:           log all tickets of resulting custom positions
 *                                F_LOG_SKIP_EMPTY:        skip empty array elements when logging tickets
 *                                F_SHOW_CUSTOM_POSITIONS: call ShowOpenOrders() for the configured open positions
 *                                F_SHOW_CUSTOM_HISTORY:   call ShowTradeHistory() for the configured history
 * @return bool - success status
 */
 bool AnalyzePositions(int flags = NULL) {                                        // reparse configuration on chart command flags
   if (flags & (F_LOG_TICKETS|F_SHOW_CUSTOM_POSITIONS) != 0) positions.analyzed = false;
   if (mode.extern)        positions.analyzed = true;
   if (positions.analyzed) return(true);

   int      tickets    [], openPositions;                                        // position details
   int      types      [];
   double   lots       [];
   datetime openTimes  [];
   double   openPrices [];
   double   commissions[];
   double   swaps      [];
   double   profits    [];

   // resolve total open position
   longPosition  = 0;                                                            // global vars
   shortPosition = 0;
   isPendings    = false;

   // mode.intern
   if (mode.intern) {
      bool lfxProfits = false;
      int pos, orders = OrdersTotal();
      int sortKeys[][2];                                                         // Sortierschlüssel der offenen Positionen: {OpenTime, Ticket}
      ArrayResize(sortKeys, orders);

      // Sortierschlüssel auslesen und dabei PnL von LFX-Positionen erfassen (alle Symbole).
      for (int n, i=0; i < orders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;                 // FALSE: während des Auslesens wurde woanders ein offenes Ticket entfernt
         if (OrderType() > OP_SELL) {
            if (!isPendings) /*&&*/ if (OrderSymbol()==Symbol())
               isPendings = true;
            continue;
         }

         // PL gefundener LFX-Positionen aufaddieren
         while (true) {                                                          // Pseudo-Schleife, dient dem einfacherem Verlassen des Blocks
            if (!lfxOrders.openPositions) break;

            if (LFX.IsMyOrder()) {                                               // Index des Tickets in lfxOrders.iCache[] ermitteln:
               if (OrderMagicNumber() != lfxOrders.iCache[pos][IC.ticket]) {     // Quickcheck mit letztem verwendeten Index, erst danach Vollsuche (schneller)
                  pos = SearchLfxTicket(OrderMagicNumber());                     // (ist lfxOrders.openPositions!=0, muß nicht auf size(*.iCache)==0 geprüft werden)
                  if (pos == -1) {
                     pos = 0;
                     break;
                  }
               }
               if (!lfxProfits) {                                                // Profits in lfxOrders.dCache[] beim ersten Zugriff in lastProfit speichern und zurücksetzen
                  for (int j=0; j < lfxOrders.openPositions; j++) {
                     lfxOrders.dCache[j][DC.lastProfit] = lfxOrders.dCache[j][DC.profit];
                     lfxOrders.dCache[j][DC.profit    ] = 0;
                  }
               }
               lfxOrders.dCache[pos][DC.profit] += OrderCommission() + OrderSwap() + OrderProfit();
               lfxProfits = true;
            }
            break;
         }

         if (OrderSymbol() != Symbol()) continue;
         if (OrderType() == OP_BUY) longPosition  += OrderLots();                // Gesamtposition je Richtung aufaddieren
         else                       shortPosition += OrderLots();
         if (!isPendings) /*&&*/ if (OrderStopLoss() || OrderTakeProfit())       // Pendings-Status tracken
            isPendings = true;

         sortKeys[n][0] = OrderOpenTime();                                       // Sortierschlüssel der Tickets auslesen
         sortKeys[n][1] = OrderTicket();
         n++;
      }
      if (lfxProfits) /*&&*/if (!AnalyzePos.ProcessLfxProfits()) return(false);  // PL gefundener LFX-Positionen verarbeiten

      if (n < orders)
         ArrayResize(sortKeys, n);
      openPositions = n;

      // offene Positionen sortieren und einlesen
      if (openPositions > 1) /*&&*/ if (!SortOpenTickets(sortKeys))
         return(false);

      ArrayResize(tickets    , openPositions);                                   // interne Positionsdetails werden bei jedem Tick zurückgesetzt
      ArrayResize(types      , openPositions);
      ArrayResize(lots       , openPositions);
      ArrayResize(openTimes  , openPositions);
      ArrayResize(openPrices , openPositions);
      ArrayResize(commissions, openPositions);
      ArrayResize(swaps      , openPositions);
      ArrayResize(profits    , openPositions);

      for (i=0; i < openPositions; i++) {
         if (!SelectTicket(sortKeys[i][1], "AnalyzePositions(1)"))
            return(false);
         tickets    [i] = OrderTicket();
         types      [i] = OrderType();
         lots       [i] = NormalizeDouble(OrderLots(), 2);
         openTimes  [i] = OrderOpenTime();
         openPrices [i] = OrderOpenPrice();
         commissions[i] = OrderCommission();
         swaps      [i] = OrderSwap();
         profits    [i] = OrderProfit();
      }
   }

   // Ergebnisse intern + extern
   longPosition  = NormalizeDouble(longPosition,  2);                            // global vars
   shortPosition = NormalizeDouble(shortPosition, 2);
   totalPosition = NormalizeDouble(longPosition - shortPosition, 2);
   isPosition    = longPosition || shortPosition;

   // Positionen analysieren und in positions.*Data[] speichern
   if (ArrayRange(positions.iData, 0) > 0) {
      ArrayResize(positions.iData, 0);
      ArrayResize(positions.dData, 0);
   }

   // individuelle Konfiguration parsen
   int prevError = last_error;
   SetLastError(NO_ERROR);
   if (!ArrayRange(positions.config, 0)) /*&&*/ if (!CustomPositions.ReadConfig()) {
      positions.analyzed = !last_error;                                          // MarketInfo()-Daten stehen ggf. noch nicht zur Verfügung,
      if (!last_error) SetLastError(prevError);                                  // in diesem Fall nächster Versuch beim nächsten Tick.
      return(positions.analyzed);
   }
   SetLastError(prevError);

   // individuelle Positionen aus offenen Positionen extrahieren und in positions.*Data[] speichern
   int    termType, confLineIndex, confSize = ArrayRange(positions.config, 0);
   double termValue1, termValue2, termCache1, termCache2, customLongPosition, customShortPosition, customTotalPosition, closedProfit=EMPTY_VALUE, adjustedProfit, customEquity, profitMarkerPrice, profitMarkerPercent=EMPTY_VALUE, lossMarkerPrice, lossMarkerPercent=EMPTY_VALUE, _longPosition=longPosition, _shortPosition=shortPosition, _totalPosition=totalPosition;
   bool   isCustomVirtual;
   int    customTickets    [];
   int    customTypes      [];
   double customLots       [];
   double customOpenPrices [];
   double customCommissions[];
   double customSwaps      [];
   double customProfits    [];

   for (i=0, confLineIndex=0; i < confSize; i++) {
      termType   = positions.config[i][I_TERM_TYPE  ];
      termValue1 = positions.config[i][I_TERM_VALUE1];
      termValue2 = positions.config[i][I_TERM_VALUE2];
      termCache1 = positions.config[i][I_TERM_CACHE1];
      termCache2 = positions.config[i][I_TERM_CACHE2];

      if (!termType) {                                                           // termType NULL => EOL (Ende einer individuellen Konfigurationszeile)
         if (flags & F_LOG_TICKETS != 0) CustomPositions.LogTickets(customTickets, confLineIndex, flags);
         if (flags & F_SHOW_CUSTOM_POSITIONS && ArraySize(customTickets)) ShowOpenOrders(customTickets);

         // individuelle Position speichern
         if (!StorePosition(isCustomVirtual, customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLots, customOpenPrices, customCommissions, customSwaps, customProfits, closedProfit, adjustedProfit, customEquity, profitMarkerPrice, profitMarkerPercent, lossMarkerPrice, lossMarkerPercent, confLineIndex))
            return(false);
         isCustomVirtual     = false;
         customLongPosition  = 0;
         customShortPosition = 0;
         customTotalPosition = 0;
         closedProfit        = EMPTY_VALUE;
         adjustedProfit      = 0;
         customEquity        = 0;
         profitMarkerPrice   = 0;
         profitMarkerPercent = EMPTY_VALUE;
         lossMarkerPrice     = 0;
         lossMarkerPercent   = EMPTY_VALUE;
         ArrayResize(customTickets,     0);
         ArrayResize(customTypes,       0);
         ArrayResize(customLots,        0);
         ArrayResize(customOpenPrices,  0);
         ArrayResize(customCommissions, 0);
         ArrayResize(customSwaps,       0);
         ArrayResize(customProfits,     0);
         confLineIndex++;
         continue;
      }
      // individuelle Position extrahieren
      if (!ExtractPosition(termType, termValue1, termValue2, termCache1, termCache2,
                           _longPosition,      _shortPosition,      _totalPosition,      tickets,       types,       lots,       openTimes, openPrices,       commissions,       swaps,       profits,
                           customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLots,            customOpenPrices, customCommissions, customSwaps, customProfits, closedProfit, adjustedProfit, customEquity, profitMarkerPrice, profitMarkerPercent, lossMarkerPrice, lossMarkerPercent,
                           isCustomVirtual, flags))
         return(false);
      positions.config[i][I_TERM_CACHE1] = termCache1;
      positions.config[i][I_TERM_CACHE2] = termCache2;
   }

   if (flags & F_LOG_TICKETS != 0) CustomPositions.LogTickets(tickets, -1, flags);

   // evt. verbleibende offene Position als letzten Eintrag speichern (wird von keiner Konfiguration abgedeckt)
   if (!StorePosition(false, _longPosition, _shortPosition, _totalPosition, tickets, types, lots, openPrices, commissions, swaps, profits, EMPTY_VALUE, NULL, NULL, NULL, EMPTY_VALUE, NULL, EMPTY_VALUE, -1))
      return(false);

   positions.analyzed = true;
   return(!catch("AnalyzePositions(2)"));
}


/**
 * Log tickets of custom positions.
 *
 * @param  int tickets[]
 * @param  int commentIndex
 * @param  int flags [optional] - control flags, supported values:
 *                                F_LOG_SKIP_EMPTY: skip empty array elements when logging tickets
 * @return bool - success status
 */
bool CustomPositions.LogTickets(int tickets[], int commentIndex, int flags = NULL) {
   int copy[]; ArrayResize(copy, 0);
   if (ArraySize(tickets) > 0) {
      ArrayCopy(copy, tickets);
      if (flags & F_LOG_SKIP_EMPTY != 0) ArrayDropInt(copy, 0);
   }

   if (ArraySize(copy) > 0) {
      string sIndex="-", sComment="";

      if (commentIndex > -1) {
         sIndex = commentIndex;
         if (StringLen(positions.config.comments[commentIndex]) > 0) {
            sComment = "\""+ positions.config.comments[commentIndex] +"\" = ";
         }
      }

      string sPosition = TicketsToStr.Position(copy);
      sPosition = ifString(sPosition=="0 lot", "", sPosition +" = ");
      string sTickets = TicketsToStr.Lots(copy, NULL);

      debug("LogTickets(1)  conf("+ sIndex +"): "+ sComment + sPosition + sTickets);
   }
   return(!catch("CustomPositions.LogTickets(2)"));
}


/**
 * Calculate the unitsize according to the configured profile. Calculation is risk-based and/or leverage-based.
 *
 *  - Default configuration settings for risk-based calculation:
 *    [Unitsize]
 *    Default.RiskPercent = <numeric>                    ; risked percent of account equity
 *    Default.RiskRange   = (<numeric> [pip] | ADR)      ; price range (absolute, in pip or the value "ADR") for the risked percent
 *
 *  - Default configuration settings for leverage-based calculation:
 *    [Unitsize]
 *    Default.Leverage = <numeric>                       ; leverage per unit
 *
 *  - Symbol-specific configuration:
 *    [Unitsize]
 *    GBPUSD.RiskPercent = <numeric>                     ; per symbol: risked percent of account equity
 *    EURUSD.Leverage    = <numeric>                     ; per symbol: leverage per unit
 *
 * The default settings apply if no symbol-specific settings are provided. For symbol-specific settings the term "Default"
 * is replaced by the broker's symbol name or the symbol's standard name. The broker's symbol name has preference over the
 * standard name. E.g. if a broker offers the symbol "EURUSDm" and the configuration provides the settings "Default.Leverage",
 * "EURUSD.Leverage" and "EURUSDm.Leverage" the calculation uses the settings for "EURUSDm".
 *
 * If both risk and leverage settings are provided the resulting unitsize is the smaller of both calculations.
 * The configuration is read in onInit().
 *
 * @return bool - success status
 */
bool CalculateUnitSize() {
   if (mode.extern || mm.done) return(true);                         // skip for external accounts

   //debug("CalculateUnitSize(0.1)  recalculating...");

   // see declaration of global vars mm.* for their descriptions
   mm.lotValue                = 0;
   mm.unleveragedLots         = 0;
   mm.leveragedLots           = 0;
   mm.leveragedLotsNormalized = 0;
   mm.leverage                = 0;
   mm.riskPercent             = 0;
   mm.riskRange               = 0;

   // recalculate equity used for calculations
   double accountEquity = AccountEquity()-AccountCredit();
   if (AccountBalance() > 0) accountEquity = MathMin(AccountBalance(), accountEquity);
   mm.equity = accountEquity + GetExternalAssets(tradeAccount.company, tradeAccount.number);

   // recalculate lot value and unleveraged unitsize
   int error;
   double tickSize = MarketInfoEx(Symbol(), MODE_TICKSIZE, error);
   double tickValue = MarketInfoEx(Symbol(), MODE_TICKVALUE, error);    // don't log ERR_SYMBOL_NOT_AVAILABLE
   if (!Close[0] || !tickSize || !tickValue || !mm.equity) {            // may happen on terminal start, on account/template change, in offline charts
      if (!error || error==ERR_SYMBOL_NOT_AVAILABLE)
         return(SetLastError(ERS_TERMINAL_NOT_YET_READY));
      return(!catch("CalculateUnitSize(1)", error));
   }
   mm.lotValue        = Close[0]/tickSize * tickValue;                  // value of 1 lot in account currency
   mm.unleveragedLots = mm.equity/mm.lotValue;                          // unleveraged unitsize

   // update the current ADR
   if (mm.cfgRiskRangeIsADR) {
      mm.cfgRiskRange = GetADR();
      if (!mm.cfgRiskRange) return(last_error == ERS_TERMINAL_NOT_YET_READY);
   }

   // recalculate the unitsize
   if (mm.cfgRiskPercent && mm.cfgRiskRange) {
      double riskedAmount = mm.equity * mm.cfgRiskPercent/100;          // risked amount in account currency
      double ticks        = mm.cfgRiskRange/tickSize;                   // risk range in tick
      double riskPerTick  = riskedAmount/ticks;                         // risked amount per tick
      mm.leveragedLots    = riskPerTick/tickValue;                      // resulting unitsize
      mm.leverage         = mm.leveragedLots/mm.unleveragedLots;        // resulting leverage
      mm.riskPercent      = mm.cfgRiskPercent;
      mm.riskRange        = mm.cfgRiskRange;
   }

   if (mm.cfgLeverage != NULL) {
      if (!mm.leverage || mm.leverage > mm.cfgLeverage) {               // if both risk and leverage are configured the smaller result of both calculations is used
         mm.leverage      = mm.cfgLeverage;
         mm.leveragedLots = mm.unleveragedLots * mm.leverage;           // resulting unitsize

         if (mm.cfgRiskRange != NULL) {
            ticks          = mm.cfgRiskRange/tickSize;                  // risk range in tick
            riskPerTick    = mm.leveragedLots * tickValue;              // risked amount per tick
            riskedAmount   = riskPerTick * ticks;                       // total risked amount
            mm.riskPercent = riskedAmount/mm.equity * 100;              // resulting risked percent for the configured range
            mm.riskRange   = mm.cfgRiskRange;
         }
      }
   }

   // normalize the result to a sound value
   if (mm.leveragedLots > 0) {                                                                                                                  // max. 6.7% per step
      if      (mm.leveragedLots <=    0.03) mm.leveragedLotsNormalized = NormalizeDouble(MathRound(mm.leveragedLots/  0.001) *   0.001, 3);     //     0-0.03: multiple of   0.001
      else if (mm.leveragedLots <=   0.075) mm.leveragedLotsNormalized = NormalizeDouble(MathRound(mm.leveragedLots/  0.002) *   0.002, 3);     // 0.03-0.075: multiple of   0.002
      else if (mm.leveragedLots <=    0.1 ) mm.leveragedLotsNormalized = NormalizeDouble(MathRound(mm.leveragedLots/  0.005) *   0.005, 3);     //  0.075-0.1: multiple of   0.005
      else if (mm.leveragedLots <=    0.3 ) mm.leveragedLotsNormalized = NormalizeDouble(MathRound(mm.leveragedLots/  0.01 ) *   0.01 , 2);     //    0.1-0.3: multiple of   0.01
      else if (mm.leveragedLots <=    0.75) mm.leveragedLotsNormalized = NormalizeDouble(MathRound(mm.leveragedLots/  0.02 ) *   0.02 , 2);     //   0.3-0.75: multiple of   0.02
      else if (mm.leveragedLots <=    1.2 ) mm.leveragedLotsNormalized = NormalizeDouble(MathRound(mm.leveragedLots/  0.05 ) *   0.05 , 2);     //   0.75-1.2: multiple of   0.05
      else if (mm.leveragedLots <=   10.  ) mm.leveragedLotsNormalized = NormalizeDouble(MathRound(mm.leveragedLots/  0.1  ) *   0.1  , 1);     //     1.2-10: multiple of   0.1
      else if (mm.leveragedLots <=   30.  ) mm.leveragedLotsNormalized =       MathRound(MathRound(mm.leveragedLots/  1    ) *   1       );     //      12-30: multiple of   1
      else if (mm.leveragedLots <=   75.  ) mm.leveragedLotsNormalized =       MathRound(MathRound(mm.leveragedLots/  2    ) *   2       );     //      30-75: multiple of   2
      else if (mm.leveragedLots <=  120.  ) mm.leveragedLotsNormalized =       MathRound(MathRound(mm.leveragedLots/  5    ) *   5       );     //     75-120: multiple of   5
      else if (mm.leveragedLots <=  300.  ) mm.leveragedLotsNormalized =       MathRound(MathRound(mm.leveragedLots/ 10    ) *  10       );     //    120-300: multiple of  10
      else if (mm.leveragedLots <=  750.  ) mm.leveragedLotsNormalized =       MathRound(MathRound(mm.leveragedLots/ 20    ) *  20       );     //    300-750: multiple of  20
      else if (mm.leveragedLots <= 1200.  ) mm.leveragedLotsNormalized =       MathRound(MathRound(mm.leveragedLots/ 50    ) *  50       );     //   750-1200: multiple of  50
      else                                  mm.leveragedLotsNormalized =       MathRound(MathRound(mm.leveragedLots/100    ) * 100       );     //   1200-...: multiple of 100
   }

   mm.done = true;
   return(!catch("CalculateUnitSize(2)"));
}


/**
 * Durchsucht das globale Cache-Array lfxOrders.iCache[] nach dem übergebenen Ticket.
 *
 * @param  int ticket - zu findendes LFX-Ticket
 *
 * @return int - Index des gesuchten Tickets oder -1, wenn das Ticket unbekannt ist
 */
int SearchLfxTicket(int ticket) {
   int size = ArrayRange(lfxOrders.iCache, 0);
   for (int i=0; i < size; i++) {
      if (lfxOrders.iCache[i][IC.ticket] == ticket)
         return(i);
   }
   return(-1);
}


/**
 * Read & parse the custom position configuration and store it in a machine-readable format.
 *
 * @return bool - success status
 *
 *
 * Fills positions.config[] with parsed configuration data of the current chart symbol. The array enthält danach Elemente
 * {type, value1, value2, value3, value4}. Ein NULL-Element {NULL, ...} markiert EOL (Zeilenende bzw. leere Konfiguration).
 * Nach Rückkehr ist das Array niemals leer (enthält imer mindestens einen EOL-Marker).
 *
 * +------------------------------------------------+-------------------------------------------------------------------------------+------------------------------------------------------------------------+
 * | Notation                                       | Description                                                                   | Content of positions.config[][] (7)                                    |
 * +------------------------------------------------+-------------------------------------------------------------------------------+------------------------------------------------------------------------+
 * |    #123456                                     | komplettes Ticket oder verbleibender Rest eines Tickets                       | [TERM_TICKET       , 123456          , EMPTY           , ...  , ...  ] |
 * | 0.1#123456                                     | O.1 Lot eines Tickets (1)                                                     | [TERM_TICKET       , 123456          , 0.1             , ...  , ...  ] |
 * |    L                                           | ohne Lotsize: alle übrigen offenen Long-Positionen                            | [TERM_OPEN_LONG    , EMPTY           , ...             , ...  , ...  ] |
 * |    S                                           | ohne Lotsize: alle übrigen offenen Short-Positionen                           | [TERM_OPEN_SHORT   , EMPTY           , ...             , ...  , ...  ] |
 * | 0.2L                                           | mit Lotsize: virtuelle Long-Position zum aktuellen Preis (2)                  | [TERM_OPEN_LONG    , 0.2             , NULL            , ...  , ...  ] |
 * | 0.3S[@]1.2345                                  | mit Lotsize: virtuelle Short-Position zum angegebenen Preis (2)               | [TERM_OPEN_SHORT   , 0.3             , 1.2345          , ...  , ...  ] |
 * | O{DateTime}                                    | offene Positionen des aktuellen Symbols eines Standard-Zeitraums (3)          | [TERM_OPEN         , 2014.01.01 00:00, 2014.12.31 23:59, ...  , ...  ] |
 * | O{DateTime}-{DateTime}                         | offene Positionen des aktuellen Symbols von und bis zu einem Zeitpunkt (3)(4) | [TERM_OPEN         , 2014.02.01 08:00, 2014.02.10 18:00, ...  , ...  ] |
 * | H{DateTime}             [Monthly|Weekly|Daily] | Trade-History des aktuellen Symbols eines Standard-Zeitraums (3)(5)           | [TERM_HISTORY      , 2014.01.01 00:00, 2014.12.31 23:59, ...  , ...  ] |
 * | HT{DateTime}-{DateTime} [Monthly|Weekly|Daily] | Trade-History aller Symbole von und bis zu einem Zeitpunkt (3)(4)(5)          | [TERM_HISTORY_TOTAL, 2014.02.01 08:00, 2014.02.10 18:00, ...  , ...  ] |
 * | 12.34                                          | dem PL einer Position zuzuschlagender Betrag                                  | [TERM_ADJUSTMENT   , 12.34           , ...             , ...  , ...  ] |
 * | E=123.00                                       | für Equityberechnungen zu verwendender Wert                                   | [TERM_EQUITY       , 123.00          , ...             , ...  , ...  ] |
 * | PM=1.2345                                      | draw a profit marker and calculate PL at the specified price                  | [TERM_PROFIT_MARKER, 1.2345          , ...             , ...  , ...  ] |
 * | PM=3%                                          | draw a profit marker at a PL of the specified percent amount                  | [TERM_PROFIT_MARKER, ...             , 3.0             , ...  , ...  ] |
 * | LM=2.3456                                      | draw a loss marker and calculate PL at the specified price                    | [TERM_LOSS_MARKER  , 2.3456          , ...             , ...  , ...  ] |
 * | LM=-5%                                         | draw a loss marker at a PL of the specified percent amount                    | [TERM_LOSS_MARKER  , ...             , -5.0            , ...  , ...  ] |
 * +------------------------------------------------+-------------------------------------------------------------------------------+------------------------------------------------------------------------+
 * | text after a semikolon ";" aka .ini comment    | displayed as position description                                             | string: stored in positions.config.comments[]                          |
 * | text after a 2nd semikolon ";;"                | comment (ignored)                                                             |                                                                        |
 * +------------------------------------------------+-------------------------------------------------------------------------------+------------------------------------------------------------------------+
 *
 *  Example configuration (6)
 *  -------------------------
 *   [CustomPositions]
 *   GBPAUD.a = #111111, 0.1#222222                // full ticket #111111, plus 0.1 lot of ticket #222222
 *   GBPAUD.b = 0.2L, #222222                      // virtual long position of 0.2 lot, plus remainder of #222222 (2)
 *   GBPAUD.c = L,S,-34.56,LM=-3%                  // all remaining positions incl. remainder of #222222, plus loss of -34.56, loss marker at PL=-3%
 *   GBPAUD.d = 0.3S                               // virtual short position of 0.3 lot
 *
 *
 *  Resulting array of the above example (7)
 *  ----------------------------------------
 *  double positions.config = [
 *     [TERM_TICKET, 111111, EMPTY, ..., ...],
 *     [TERM_TICKET, 222222, 0.1  , ..., ...],
 *     [NULL  , ...  , ..., ..., ...],             // EOL marker of GBPAUD.a
 *
 *     [TERM_OPEN_LONG, 0.2   , NULL , ..., ...],
 *     [TERM_TICKET   , 222222, EMPTY, ..., ...],
 *     [NULL          , ...   , ...  , ..., ...],  // EOL marker of GBPAUD.b
 *
 *     [TERM_OPEN_LONG  , EMPTY , ... , ..., ...],
 *     [TERM_OPEN_SHORT , EMPTY , ... , ..., ...],
 *     [TERM_ADJUSTMENT , -34.45, ... , ..., ...],
 *     [TERM_LOSS_MARKER, ...   , -3.0, ..., ...],
 *     [NULL            , ...   , ... , ..., ...], // EOL marker of GBPAUD.c
 *
 *     [TERM_OPEN_SHORT, 0.3, NULL, ..., ...],
 *     [NULL           , ..., ... , ..., ...],     // EOL marker of GBPAUD.d
 *  ];
 *
 *
 *  (1) Bei einer Lotsize von 0 wird die Teilposition ignoriert.
 *  (2) Werden reale mit virtuellen Positionen kombiniert, wird die Position virtuell und nicht von der aktuellen Gesamtposition abgezogen.
 *      Dies kann in Verbindung mit (1) benutzt werden, um eine virtuelle Position zu konfigurieren, die die folgenden Positionen nicht
 *      beeinflußt (z.B. durch "0L").
 *  (3) Zeitangaben im Format: 2014[.01[.15 [W|12:30[:45]]]]
 *  (4) Einer der beiden Zeitpunkte kann leer sein und steht jeweils für "von Beginn" oder "bis Ende".
 *  (5) Ein Historyzeitraum kann tages-, wochen- oder monatsweise gruppiert werden, solange er nicht mit anderen Positionen kombiniert wird.
 *  (6) Die Positionen werden nicht sortiert und in der Reihenfolge ihrer Notierung angezeigt.
 *  (7) "..." denotes fields not used by the term
 */
bool CustomPositions.ReadConfig() {
   if (ArrayRange(positions.config, 0) > 0) {
      ArrayResize(positions.config,          0);
      ArrayResize(positions.config.comments, 0);
   }

   string   keys[], values[], iniValue="", sValue="", comment="", confComment="", openComment="", hstComment="", sNull, symbol=Symbol(), stdSymbol=StdSymbol();
   double   termType, termValue1, termValue2, termCache1, termCache2, dValue, lotSize, minLotSize=MarketInfo(symbol, MODE_MINLOT), lotStep=MarketInfo(symbol, MODE_LOTSTEP);
   int      valuesSize, confSize, pos, ticket, positionStartOffset;
   datetime from, to;
   bool     isPositionEmpty, isPositionVirtual, isPositionGrouped, containsEquityValue, containsProfitMarker, containsLossMarker, isTotal, isPercent;

   if (!minLotSize || !lotStep) return(false);                       // falls MarketInfo()-Daten noch nicht verfügbar sind
   if (mode.extern)             return(!catch("CustomPositions.ReadConfig(1)  feature for mode.extern=true not yet implemented", ERR_NOT_IMPLEMENTED));

   string file     = GetAccountConfigPath(tradeAccount.company, tradeAccount.number); if (!StringLen(file)) return(false);
   string section  = "CustomPositions";
   int    keysSize = GetIniKeys(file, section, keys);

   for (int i=0; i < keysSize; i++) {
      if (StrStartsWithI(keys[i], symbol) || StrStartsWithI(keys[i], stdSymbol)) {
         if (SearchStringArrayI(keys, keys[i]) == i) {               // bei gleichnamigen Schlüsseln wird nur der erste verarbeitet
            iniValue = GetIniStringRawA(file, section, keys[i], "");
            iniValue = StrReplace(iniValue, TAB, " ");

            // first parse an existing line comment
            comment     = "";
            confComment = "";
            openComment = "";
            hstComment  = "";
            pos = StringFind(iniValue, ";");
            if (pos >= 0) {
               confComment = StrSubstr(iniValue, pos+1);
               iniValue    = StrTrim(StrLeft(iniValue, pos));
               pos = StringFind(confComment, ";");
               if (pos == -1) confComment = StrTrim(confComment);
               else           confComment = StrTrim(StrLeft(confComment, pos));
               if (StrStartsWith(confComment, "\"") && StrEndsWith(confComment, "\"")) // führende und schließende Anführungszeichen entfernen
                  confComment = StrSubstr(confComment, 1, StringLen(confComment)-2);
            }

            // now parse the configuration terms
            isPositionEmpty      = true;                             // whether the resulting position doesn't yet contain data of any term type
            isPositionVirtual    = false;                            // whether the resulting position is virtual
            isPositionGrouped    = false;                            // whether the resulting position is grouped
            containsEquityValue  = false;                            // whether the resulting position contains a custom equity value
            containsProfitMarker = false;                            // whether the resulting position contains a TP marker
            containsLossMarker   = false;                            // whether the resulting position contains a SL marker
            valuesSize           = Explode(StrToUpper(iniValue), ",", values, NULL);

            for (int n=0; n < valuesSize; n++) {
               values[n] = StrTrim(values[n]);
               if (!StringLen(values[n]))                            // Leervalue
                  continue;

               if (StrStartsWith(values[n], "#")) {                  // ticket: #123456
                  sValue = StrTrim(StrSubstr(values[n], 1));
                  if (!StrIsDigits(sValue))                          return(!catch("CustomPositions.ReadConfig(2)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-digits in ticket \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termType   = TERM_TICKET;
                  termValue1 = StrToInteger(sValue);
                  termValue2 = EMPTY;                                // all remaining lots
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrContains(values[n], "#")) {               // partial ticket: 0.1#123456
                  pos = StringFind(values[n], "#");
                  sValue = StrTrim(StrLeft(values[n], pos));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(3)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termType   = TERM_TICKET;
                  termValue2 = StrToDouble(sValue);
                  if (termValue2 && LT(termValue2, minLotSize))      return(!catch("CustomPositions.ReadConfig(4)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (lot size smaller than MIN_LOTSIZE \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  if (MathModFix(termValue2, lotStep) != 0)          return(!catch("CustomPositions.ReadConfig(5)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (lot size not a multiple of LOTSTEP \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  sValue = StrTrim(StrSubstr(values[n], pos+1));
                  if (!StrIsDigits(sValue))                          return(!catch("CustomPositions.ReadConfig(6)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-digits in ticket \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue1 = StrToInteger(sValue);
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrStartsWith(values[n], "H")) {             // H[T] = History[Total]
                  if (!CustomPositions.ParseHstTerm(values[n], confComment, hstComment, isPositionEmpty, isPositionGrouped, isTotal, from, to)) return(false);
                  if (isPositionGrouped) {
                     isPositionEmpty = false;
                     continue;                                       // gruppiert: die Konfiguration wurde bereits in CustomPositions.ParseHstTerm() gespeichert
                  }
                  termType   = ifInt(!isTotal, TERM_HISTORY, TERM_HISTORY_TOTAL);
                  termValue1 = from;                                 // nicht gruppiert
                  termValue2 = to;
                  termCache1 = EMPTY_VALUE;                          // EMPTY_VALUE, da NULL bei TERM_HISTORY_* ein gültiger Wert ist
                  termCache2 = EMPTY_VALUE;
               }

               else if (StrStartsWith(values[n], "E")) {             // equity value: E=123.56
                  sValue = StrTrim(StrSubstr(values[n], 1));
                  if (!StrStartsWith(sValue, "="))                   return(!catch("CustomPositions.ReadConfig(7)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (missing = in equity term \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  sValue = StrTrim(StrSubstr(sValue, 1));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(8)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric value in equity term \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termType   = TERM_EQUITY;
                  termValue1 = StrToDouble(sValue);
                  if (termValue1 <= 0)                               return(!catch("CustomPositions.ReadConfig(9)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal value in equity term \""+ values[n] +"\", must be > 0) in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
                  if (containsEquityValue)                           return(!catch("CustomPositions.ReadConfig(10)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (multiple equity terms \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  containsEquityValue = true;
               }

               else if (StrStartsWith(values[n], "PM")) {            // profit marker: PM=3[%]
                  sValue = StrTrim(StrSubstr(values[n], 2));
                  if (!StrStartsWith(sValue, "="))                   return(!catch("CustomPositions.ReadConfig(11)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (missing = in PM term \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  sValue = StrTrim(StrSubstr(sValue, 1));
                  isPercent = StrEndsWith(sValue, "%");
                  if (isPercent) sValue = StrTrim(StrLeft(sValue, -1));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(12)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric value in PM term \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  dValue = StrToDouble(sValue);
                  termType   = TERM_PROFIT_MARKER;
                  termValue1 = ifDouble(isPercent, NULL, NormalizeDouble(dValue, Digits));
                  if (!isPercent && termValue1 <= 0)                 return(!catch("CustomPositions.ReadConfig(13)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal value in PM term \""+ values[n] +"\", must be > 0) in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = ifDouble(isPercent, dValue, NULL);
                  if (isPercent && termValue2 <= -100)               return(!catch("CustomPositions.ReadConfig(14)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal value in PM term \""+ values[n] +"\", must be > -100) in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termCache1 = NULL;
                  termCache2 = NULL;
                  if (containsProfitMarker)                          return(!catch("CustomPositions.ReadConfig(15)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (multiple PM terms \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  containsProfitMarker = true;
               }

               else if (StrStartsWith(values[n], "LM")) {            // loss marker: LM=-5[%]
                  sValue = StrTrim(StrSubstr(values[n], 2));
                  if (!StrStartsWith(sValue, "="))                   return(!catch("CustomPositions.ReadConfig(16)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (missing = in LM term \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  sValue = StrTrim(StrSubstr(sValue, 1));
                  isPercent = StrEndsWith(sValue, "%");
                  if (isPercent) sValue = StrTrim(StrLeft(sValue, -1));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(17)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric value in LM term \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  dValue = StrToDouble(sValue);
                  termType   = TERM_LOSS_MARKER;
                  termValue1 = ifDouble(isPercent, NULL, NormalizeDouble(dValue, Digits));
                  if (!isPercent && termValue1 <= 0)                 return(!catch("CustomPositions.ReadConfig(18)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal value in LM term \""+ values[n] +"\", must be > 0) in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = ifDouble(isPercent, dValue, NULL);
                  if (isPercent && termValue2 <= -100)               return(!catch("CustomPositions.ReadConfig(19)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal value in LM term \""+ values[n] +"\", must be > -100) in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termCache1 = NULL;
                  termCache2 = NULL;
                  if (containsLossMarker)                            return(!catch("CustomPositions.ReadConfig(20)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (multiple LM terms \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  containsLossMarker = true;
               }

               else if (StrStartsWith(values[n], "L")) {             // alle verbleibenden Long-Positionen
                  if (values[n] != "L")                              return(!catch("CustomPositions.ReadConfig(21)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termType   = TERM_OPEN_LONG;
                  termValue1 = EMPTY;
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrStartsWith(values[n], "S")) {             // alle verbleibenden Short-Positionen
                  if (values[n] != "S")                              return(!catch("CustomPositions.ReadConfig(22)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termType   = TERM_OPEN_SHORT;
                  termValue1 = EMPTY;
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrStartsWith(values[n], "O")) {             // O = die verbleibenden Positionen [aller Symbole] eines Zeitraums
                  if (!CustomPositions.ParseOpenTerm(values[n], openComment, from, to)) return(false);
                  termType   = TERM_OPEN;                            // intentionally TERM_OPEN_TOTAL is not implemented
                  termValue1 = from;
                  termValue2 = to;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrIsNumeric(values[n])) {                   // PL adjustment
                  termType   = TERM_PL_ADJUSTMENT;
                  termValue1 = StrToDouble(values[n]);
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrEndsWith(values[n], "L")) {               // virtuelle Longposition zum aktuellen Preis
                  termType = TERM_OPEN_LONG;
                  sValue   = StrTrim(StrLeft(values[n], -1));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(23)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue1 = StrToDouble(sValue);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(24)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(25)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrEndsWith(values[n], "S")) {               // virtuelle Shortposition zum aktuellen Preis
                  termType = TERM_OPEN_SHORT;
                  sValue   = StrTrim(StrLeft(values[n], -1));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(26)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue1 = StrToDouble(sValue);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(27)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(28)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrContains(values[n], "L")) {               // virtuelle Longposition zum angegebenen Preis
                  termType = TERM_OPEN_LONG;
                  pos = StringFind(values[n], "L");
                  sValue = StrTrim(StrLeft(values[n], pos));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(29)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue1 = StrToDouble(sValue);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(30)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(31)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  sValue = StrTrim(StrSubstr(values[n], pos+1));
                  if (StrStartsWith(sValue, "@"))
                     sValue = StrTrim(StrSubstr(sValue, 1));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(32)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = StrToDouble(sValue);
                  if (termValue2 <= 0)                               return(!catch("CustomPositions.ReadConfig(33)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrContains(values[n], "S")) {               // virtuelle Shortposition zum angegebenen Preis
                  termType = TERM_OPEN_SHORT;
                  pos = StringFind(values[n], "S");
                  sValue = StrTrim(StrLeft(values[n], pos));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(34)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue1 = StrToDouble(sValue);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(35)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(36)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  sValue = StrTrim(StrSubstr(values[n], pos+1));
                  if (StrStartsWith(sValue, "@"))
                     sValue = StrTrim(StrSubstr(sValue, 1));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(37)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = StrToDouble(sValue);
                  if (termValue2 <= 0)                               return(!catch("CustomPositions.ReadConfig(38)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termCache1 = NULL;
                  termCache2 = NULL;
               }
               else                                                  return(!catch("CustomPositions.ReadConfig(39)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));

               // Eine gruppierte Trade-History kann nicht mit anderen Termen kombiniert werden
               if (isPositionGrouped && termType!=TERM_EQUITY)       return(!catch("CustomPositions.ReadConfig(40)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (cannot combine grouped trade history with other entries) in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));

               // Die Konfiguration virtueller Positionen muß mit einem virtuellen Term beginnen, damit die realen Lots nicht um die virtuellen Lots reduziert werden, siehe (2).
               if ((termType==TERM_OPEN_LONG || termType==TERM_OPEN_SHORT) && termValue1!=EMPTY) {
                  if (!isPositionEmpty && !isPositionVirtual) {
                     double tmp[POSITION_CONFIG_TERM_size] = {TERM_OPEN_LONG, 0, NULL, NULL, NULL};   // am Anfang der Zeile virtuellen 0-Term einfügen: 0L
                     ArrayInsertDoubleArray(positions.config, positionStartOffset, tmp);
                  }
                  isPositionVirtual = true;
               }

               // Konfigurations-Term speichern
               confSize = ArrayRange(positions.config, 0);
               ArrayResize(positions.config, confSize+1);
               positions.config[confSize][I_TERM_TYPE  ] = termType;
               positions.config[confSize][I_TERM_VALUE1] = termValue1;
               positions.config[confSize][I_TERM_VALUE2] = termValue2;
               positions.config[confSize][I_TERM_CACHE1] = termCache1;
               positions.config[confSize][I_TERM_CACHE2] = termCache2;
               isPositionEmpty = false;
            }

            if (!isPositionEmpty) {                                  // Zeile mit Leer-Term abschließen (markiert Zeilenende)
               confSize = ArrayRange(positions.config, 0);
               ArrayResize(positions.config, confSize+1);            // initialisiert Term mit NULL
               if (!StringLen(confComment)) comment = openComment + ifString(StringLen(openComment) && StringLen(hstComment ), ", ", "") + hstComment;
               else                         comment = confComment;   // configured comments override generated ones
               ArrayPushString(positions.config.comments, comment);
               positionStartOffset = confSize + 1;                   // Start-Offset der nächsten Custom-Position speichern (falls noch eine weitere Position folgt)
            }
         }
      }
   }

   confSize = ArrayRange(positions.config, 0);
   if (!confSize) {                                                  // leere Konfiguration mit Leer-Term markieren
      ArrayResize(positions.config, 1);                              // initialisiert Term mit NULL
      ArrayPushString(positions.config.comments, "");
   }
   return(!catch("CustomPositions.ReadConfig(41)"));
}


/**
 * Parst einen Open-Konfigurations-Term (Open Position).
 *
 * @param  _In_    string   term         - Konfigurations-Term
 * @param  _InOut_ string   openComments - vorhandene OpenPositions-Kommentare (werden ggf. erweitert)
 * @param  _Out_   datetime from         - Beginnzeitpunkt der zu berücksichtigenden Positionen
 * @param  _Out_   datetime to           - Endzeitpunkt der zu berücksichtigenden Positionen
 *
 * @return bool - success status
 *
 *
 * Format:
 * -------
 *  O{DateTime}
 *  O{DateTime}-{DateTime}                            • intentionally TERM_OPEN_TOTAL is not implemented
 *
 *  {DateTime} = 2014[.01[.15 [W|12:34[:56]]]]        oder
 *  {DateTime} = (This|Last)(Day|Week|Month|Year)     oder
 *  {DateTime} = Today                                • Synonym für ThisDay
 *  {DateTime} = Yesterday                            • Synonym für LastDay
 */
bool CustomPositions.ParseOpenTerm(string term, string &openComments, datetime &from, datetime &to) {
   string origTerm = term;

   term = StrToUpper(StrTrim(term));
   if (!StrStartsWith(term, "O")) return(!catch("CustomPositions.ParseOpenTerm(1)  invalid parameter term: "+ DoubleQuoteStr(origTerm) +" (not TERM_OPEN)", ERR_INVALID_PARAMETER));
   term = StrTrim(StrSubstr(term, 1));

   bool     isSingleTimespan, isFullYear1, isFullYear2, isFullMonth1, isFullMonth2, isFullWeek1, isFullWeek2, isFullDay1, isFullDay2, isFullHour1, isFullHour2, isFullMinute1, isFullMinute2;
   datetime dtFrom, dtTo;
   string   comment = "";

   // (1) Beginn- und Endzeitpunkt parsen
   int pos = StringFind(term, "-");
   if (pos >= 0) {                                                   // von-bis parsen
      // {DateTime}-{DateTime}
      // {DateTime}-NULL
      //       NULL-{DateTime}
      dtFrom = ParseDateTimeEx(StrTrim(StrLeft  (term, pos  )), isFullYear1, isFullMonth1, isFullWeek1, isFullDay1, isFullHour1, isFullMinute1); if (IsNaT(dtFrom)) return(false);
      dtTo   = ParseDateTimeEx(StrTrim(StrSubstr(term, pos+1)), isFullYear2, isFullMonth2, isFullWeek2, isFullDay2, isFullHour2, isFullMinute2); if (IsNaT(dtTo  )) return(false);
      if (dtTo != NULL) {
         if      (isFullYear2  ) dtTo  = DateTime1(TimeYearEx(dtTo)+1)                  - 1*SECOND;   // Jahresende
         else if (isFullMonth2 ) dtTo  = DateTime1(TimeYearEx(dtTo), TimeMonth(dtTo)+1) - 1*SECOND;   // Monatsende
         else if (isFullWeek2  ) dtTo += 1*WEEK                                         - 1*SECOND;   // Wochenende
         else if (isFullDay2   ) dtTo += 1*DAY                                          - 1*SECOND;   // Tagesende
         else if (isFullHour2  ) dtTo -=                                                  1*SECOND;   // Ende der vorhergehenden Stunde
       //else if (isFullMinute2) dtTo -=                                                  1*SECOND;   // nicht bei Minuten (deaktivert)
      }
   }
   else {
      // {DateTime}                                                  // einzelnen Zeitraum parsen
      isSingleTimespan = true;
      dtFrom = ParseDateTimeEx(term, isFullYear1, isFullMonth1, isFullWeek1, isFullDay1, isFullHour1, isFullMinute1); if (IsNaT(dtFrom)) return(false);
      if (!dtFrom) return(!catch("CustomPositions.ParseOpenTerm(2)  invalid open positions configuration in "+ DoubleQuoteStr(origTerm), ERR_INVALID_CONFIG_VALUE));

      if      (isFullYear1  ) dtTo = DateTime1(TimeYearEx(dtFrom)+1)                    - 1*SECOND;   // Jahresende
      else if (isFullMonth1 ) dtTo = DateTime1(TimeYearEx(dtFrom), TimeMonth(dtFrom)+1) - 1*SECOND;   // Monatsende
      else if (isFullWeek1  ) dtTo = dtFrom + 1*WEEK                                    - 1*SECOND;   // Wochenende
      else if (isFullDay1   ) dtTo = dtFrom + 1*DAY                                     - 1*SECOND;   // Tagesende
      else if (isFullHour1  ) dtTo = dtFrom + 1*HOUR                                    - 1*SECOND;   // Ende der Stunde
      else if (isFullMinute1) dtTo = dtFrom + 1*MINUTE                                  - 1*SECOND;   // Ende der Minute
      else                    dtTo = dtFrom;
   }
   //debug("CustomPositions.ParseOpenTerm(0.1)  dtFrom="+ TimeToStr(dtFrom, TIME_FULL) +"  dtTo="+ TimeToStr(dtTo, TIME_FULL));
   if (!dtFrom && !dtTo)      return(!catch("CustomPositions.ParseOpenTerm(3)  invalid open positions configuration in "+ DoubleQuoteStr(origTerm), ERR_INVALID_CONFIG_VALUE));
   if (dtTo && dtFrom > dtTo) return(!catch("CustomPositions.ParseOpenTerm(4)  invalid open positions configuration in "+ DoubleQuoteStr(origTerm) +" (start time after end time)", ERR_INVALID_CONFIG_VALUE));


   // (2) Datumswerte definieren und zurückgeben
   if (isSingleTimespan) {
      if      (isFullYear1  ) comment =             GmtTimeFormat(dtFrom, "%Y");
      else if (isFullMonth1 ) comment =             GmtTimeFormat(dtFrom, "%Y %B");
      else if (isFullWeek1  ) comment = "Week of "+ GmtTimeFormat(dtFrom, "%d.%m.%Y");
      else if (isFullDay1   ) comment =             GmtTimeFormat(dtFrom, "%d.%m.%Y");
      else if (isFullHour1  ) comment =             GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M") + GmtTimeFormat(dtTo+1*SECOND, "-%H:%M");
      else if (isFullMinute1) comment =             GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M");
      else                    comment =             GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S");
   }
   else if (!dtTo) {
      if      (isFullYear1  ) comment = "since "+   GmtTimeFormat(dtFrom, "%Y");
      else if (isFullMonth1 ) comment = "since "+   GmtTimeFormat(dtFrom, "%B %Y");
      else if (isFullWeek1  ) comment = "since "+   GmtTimeFormat(dtFrom, "%d.%m.%Y");
      else if (isFullDay1   ) comment = "since "+   GmtTimeFormat(dtFrom, "%d.%m.%Y");
      else if (isFullHour1  ) comment = "since "+   GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M");
      else if (isFullMinute1) comment = "since "+   GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M");
      else                    comment = "since "+   GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S");
   }
   else if (!dtFrom) {
      if      (isFullYear2  ) comment =  "to "+     GmtTimeFormat(dtTo,          "%Y");
      else if (isFullMonth2 ) comment =  "to "+     GmtTimeFormat(dtTo,          "%B %Y");
      else if (isFullWeek2  ) comment =  "to "+     GmtTimeFormat(dtTo,          "%d.%m.%Y");
      else if (isFullDay2   ) comment =  "to "+     GmtTimeFormat(dtTo,          "%d.%m.%Y");
      else if (isFullHour2  ) comment =  "to "+     GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");
      else if (isFullMinute2) comment =  "to "+     GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");
      else                    comment =  "to "+     GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S");
   }
   else {
      // von und bis angegeben
      if      (isFullYear1  ) {
         if      (isFullYear2  ) comment = GmtTimeFormat(dtFrom, "%Y")                +" to "+ GmtTimeFormat(dtTo,          "%Y");                // 2014 - 2015
         else if (isFullMonth2 ) comment = GmtTimeFormat(dtFrom, "%B %Y")             +" to "+ GmtTimeFormat(dtTo,          "%B %Y");             // 2014 - 2015.01
         else if (isFullWeek2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014 - 2015.01.15W
         else if (isFullDay2   ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014 - 2015.01.15
         else if (isFullHour2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014 - 2015.01.15 12:00
         else if (isFullMinute2) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014 - 2015.01.15 12:34
         else                    comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S"); // 2014 - 2015.01.15 12:34:56
      }
      else if (isFullMonth1 ) {
         if      (isFullYear2  ) comment = GmtTimeFormat(dtFrom, "%B %Y")             +" to "+ GmtTimeFormat(dtTo,          "%B %Y");             // 2014.01 - 2015
         else if (isFullMonth2 ) comment = GmtTimeFormat(dtFrom, "%B %Y")             +" to "+ GmtTimeFormat(dtTo,          "%B %Y");             // 2014.01 - 2015.01
         else if (isFullWeek2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.Y%")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01 - 2015.01.15W
         else if (isFullDay2   ) comment = GmtTimeFormat(dtFrom, "%d.%m.Y%")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01 - 2015.01.15
         else if (isFullHour2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.Y%")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01 - 2015.01.15 12:00
         else if (isFullMinute2) comment = GmtTimeFormat(dtFrom, "%d.%m.Y%")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01 - 2015.01.15 12:34
         else                    comment = GmtTimeFormat(dtFrom, "%d.%m.Y%")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S"); // 2014.01 - 2015.01.15 12:34:56
      }
      else if (isFullWeek1  ) {
         if      (isFullYear2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15W - 2015
         else if (isFullMonth2 ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15W - 2015.01
         else if (isFullWeek2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15W - 2015.01.15W
         else if (isFullDay2   ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15W - 2015.01.15
         else if (isFullHour2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15W - 2015.01.15 12:00
         else if (isFullMinute2) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15W - 2015.01.15 12:34
         else                    comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S"); // 2014.01.15W - 2015.01.15 12:34:56
      }
      else if (isFullDay1   ) {
         if      (isFullYear2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 - 2015
         else if (isFullMonth2 ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 - 2015.01
         else if (isFullWeek2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 - 2015.01.15W
         else if (isFullDay2   ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 - 2015.01.15
         else if (isFullHour2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 - 2015.01.15 12:00
         else if (isFullMinute2) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 - 2015.01.15 12:34
         else                    comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S"); // 2014.01.15 - 2015.01.15 12:34:56
      }
      else if (isFullHour1  ) {
         if      (isFullYear2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:00 - 2015
         else if (isFullMonth2 ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:00 - 2015.01
         else if (isFullWeek2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:00 - 2015.01.15W
         else if (isFullDay2   ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:00 - 2015.01.15
         else if (isFullHour2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 12:00 - 2015.01.15 12:00
         else if (isFullMinute2) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 12:00 - 2015.01.15 12:34
         else                    comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S"); // 2014.01.15 12:00 - 2015.01.15 12:34:56
      }
      else if (isFullMinute1) {
         if      (isFullYear2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34 - 2015
         else if (isFullMonth2 ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34 - 2015.01
         else if (isFullWeek2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34 - 2015.01.15W
         else if (isFullDay2   ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34 - 2015.01.15
         else if (isFullHour2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 12:34 - 2015.01.15 12:00
         else if (isFullMinute2) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 12:34 - 2015.01.15 12:34
         else                    comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S"); // 2014.01.15 12:34 - 2015.01.15 12:34:56
      }
      else {
         if      (isFullYear2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S") +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34:56 - 2015
         else if (isFullMonth2 ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S") +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34:56 - 2015.01
         else if (isFullWeek2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S") +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34:56 - 2015.01.15W
         else if (isFullDay2   ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S") +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34:56 - 2015.01.15
         else if (isFullHour2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S") +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 12:34:56 - 2015.01.15 12:00
         else if (isFullMinute2) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S") +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 12:34:56 - 2015.01.15 12:34
         else                    comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S") +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S"); // 2014.01.15 12:34:56 - 2015.01.15 12:34:56
      }
   }
   from = dtFrom;
   to   = dtTo;

   if (!StringLen(openComments)) openComments = comment;
   else                          openComments = openComments +", "+ comment;
   return(!catch("CustomPositions.ParseOpenTerm(5)"));
}


/**
 * Parst einen History-Konfigurations-Term (Closed Position).
 *
 * @param  _In_    string   term              - Konfigurations-Term
 * @param  _InOut_ string   positionComment   - Kommentar der Position (wird bei Gruppierungen nur bei der ersten Gruppe angezeigt)
 * @param  _InOut_ string   hstComments       - dynamisch generierte History-Kommentare (werden ggf. erweitert)
 * @param  _InOut_ bool     isEmptyPosition   - ob die aktuelle Position noch leer ist
 * @param  _InOut_ bool     isGroupedPosition - ob die aktuelle Position eine Gruppierung enthält
 * @param  _Out_   bool     isTotalHistory    - ob die History alle verfügbaren Trades (TRUE) oder nur die des aktuellen Symbols (FALSE) einschließt
 * @param  _Out_   datetime from              - Beginnzeitpunkt der zu berücksichtigenden History
 * @param  _Out_   datetime to                - Endzeitpunkt der zu berücksichtigenden History
 *
 * @return bool - success status
 *
 *
 * Format:
 * -------
 *  H{DateTime}             [Monthly|Weekly|Daily]    • Trade-History eines Symbols eines Standard-Zeitraums
 *  HT{DateTime}-{DateTime} [Monthly|Weekly|Daily]    • Trade-History aller Symbole von und bis zu einem Zeitpunkt
 *
 *  {DateTime} = 2014[.01[.15 [W|12:34[:56]]]]        oder
 *  {DateTime} = (This|Last)(Day|Week|Month|Year)     oder
 *  {DateTime} = Today                                • Synonym für ThisDay
 *  {DateTime} = Yesterday                            • Synonym für LastDay
 */
bool CustomPositions.ParseHstTerm(string term, string &positionComment, string &hstComments, bool &isEmptyPosition, bool &isGroupedPosition, bool &isTotalHistory, datetime &from, datetime &to) {
   isEmptyPosition   = isEmptyPosition  !=0;
   isGroupedPosition = isGroupedPosition!=0;
   isTotalHistory    = isTotalHistory   !=0;

   string term.orig = StrTrim(term);
          term      = StrToUpper(term.orig);
   if (!StrStartsWith(term, "H")) return(!catch("CustomPositions.ParseHstTerm(1)  invalid parameter term: "+ DoubleQuoteStr(term.orig) +" (not TERM_HISTORY_*)", ERR_INVALID_PARAMETER));
   term = StrTrim(StrSubstr(term, 1));

   if     (!StrStartsWith(term, "T"    )) isTotalHistory = false;
   else if (StrStartsWith(term, "THIS" )) isTotalHistory = false;
   else if (StrStartsWith(term, "TODAY")) isTotalHistory = false;
   else                                   isTotalHistory = true;
   if (isTotalHistory) term = StrTrim(StrSubstr(term, 1));

   bool     isSingleTimespan, groupByDay, groupByWeek, groupByMonth, isFullYear1, isFullYear2, isFullMonth1, isFullMonth2, isFullWeek1, isFullWeek2, isFullDay1, isFullDay2, isFullHour1, isFullHour2, isFullMinute1, isFullMinute2;
   datetime dtFrom, dtTo;
   string   comment = "";


   // (1) auf Group-Modifier prüfen
   if (StrEndsWith(term, " DAILY")) {
      groupByDay = true;
      term       = StrTrim(StrLeft(term, -6));
   }
   else if (StrEndsWith(term, " WEEKLY")) {
      groupByWeek = true;
      term        = StrTrim(StrLeft(term, -7));
   }
   else if (StrEndsWith(term, " MONTHLY")) {
      groupByMonth = true;
      term         = StrTrim(StrLeft(term, -8));
   }

   bool isGroupingTerm = groupByDay || groupByWeek || groupByMonth;
   if (isGroupingTerm && !isEmptyPosition) return(!catch("CustomPositions.ParseHstTerm(2)  cannot combine grouping configuration "+ DoubleQuoteStr(term.orig) +" with another configuration", ERR_INVALID_CONFIG_VALUE));
   isGroupedPosition = isGroupedPosition || isGroupingTerm;


   // (2) Beginn- und Endzeitpunkt parsen
   int pos = StringFind(term, "-");
   if (pos >= 0) {                                                   // von-bis parsen
      // {DateTime}-{DateTime}
      // {DateTime}-NULL
      //       NULL-{DateTime}
      dtFrom = ParseDateTimeEx(StrTrim(StrLeft (term,  pos  )), isFullYear1, isFullMonth1, isFullWeek1, isFullDay1, isFullHour1, isFullMinute1); if (IsNaT(dtFrom)) return(false);
      dtTo   = ParseDateTimeEx(StrTrim(StrSubstr(term, pos+1)), isFullYear2, isFullMonth2, isFullWeek2, isFullDay2, isFullHour2, isFullMinute2); if (IsNaT(dtTo  )) return(false);
      if (dtTo != NULL) {
         if      (isFullYear2  ) dtTo  = DateTime1(TimeYearEx(dtTo)+1)                  - 1*SECOND;   // Jahresende
         else if (isFullMonth2 ) dtTo  = DateTime1(TimeYearEx(dtTo), TimeMonth(dtTo)+1) - 1*SECOND;   // Monatsende
         else if (isFullWeek2  ) dtTo += 1*WEEK                                         - 1*SECOND;   // Wochenende
         else if (isFullDay2   ) dtTo += 1*DAY                                          - 1*SECOND;   // Tagesende
         else if (isFullHour2  ) dtTo -=                                                  1*SECOND;   // Ende der vorhergehenden Stunde
       //else if (isFullMinute2) dtTo -=                                                  1*SECOND;   // nicht bei Minuten (deaktiviert)
      }
   }
   else {
      // {DateTime}                                                  // einzelnen Zeitraum parsen
      isSingleTimespan = true;
      dtFrom = ParseDateTimeEx(term, isFullYear1, isFullMonth1, isFullWeek1, isFullDay1, isFullHour1, isFullMinute1); if (IsNaT(dtFrom)) return(false);
                                                                                                                      if (!dtFrom)       return(!catch("CustomPositions.ParseHstTerm(3)  invalid history configuration in "+ DoubleQuoteStr(term.orig), ERR_INVALID_CONFIG_VALUE));
      if      (isFullYear1  ) dtTo = DateTime1(TimeYearEx(dtFrom)+1)                    - 1*SECOND;   // Jahresende
      else if (isFullMonth1 ) dtTo = DateTime1(TimeYearEx(dtFrom), TimeMonth(dtFrom)+1) - 1*SECOND;   // Monatsende
      else if (isFullWeek1  ) dtTo = dtFrom + 1*WEEK                                    - 1*SECOND;   // Wochenende
      else if (isFullDay1   ) dtTo = dtFrom + 1*DAY                                     - 1*SECOND;   // Tagesende
      else if (isFullHour1  ) dtTo = dtFrom + 1*HOUR                                    - 1*SECOND;   // Ende der Stunde
      else if (isFullMinute1) dtTo = dtFrom + 1*MINUTE                                  - 1*SECOND;   // Ende der Minute
      else                    dtTo = dtFrom;
   }
   //debug("CustomPositions.ParseHstTerm(0.1)  dtFrom="+ TimeToStr(dtFrom, TIME_FULL) +"  dtTo="+ TimeToStr(dtTo, TIME_FULL) +"  grouped="+ isGroupingTerm);
   if (!dtFrom && !dtTo)      return(!catch("CustomPositions.ParseHstTerm(4)  invalid history configuration in "+ DoubleQuoteStr(term.orig), ERR_INVALID_CONFIG_VALUE));
   if (dtTo && dtFrom > dtTo) return(!catch("CustomPositions.ParseHstTerm(5)  invalid history configuration in "+ DoubleQuoteStr(term.orig) +" (history start after history end)", ERR_INVALID_CONFIG_VALUE));


   if (isGroupingTerm) {
      //
      // TODO:  Performance verbessern
      //

      // (3) Gruppen anlegen und komplette Zeilen direkt hier einfügen (bei der letzten Gruppe jedoch ohne Zeilenende)
      datetime groupFrom, groupTo, nextGroupFrom, now=Tick.time;
      if      (groupByMonth) groupFrom = DateTime1(TimeYearEx(dtFrom), TimeMonth(dtFrom));
      else if (groupByWeek ) groupFrom = dtFrom - dtFrom%DAYS - (TimeDayOfWeekEx(dtFrom)+6)%7 * DAYS;
      else if (groupByDay  ) groupFrom = dtFrom - dtFrom%DAYS;

      if (!dtTo) {                                                                                       // {DateTime} - NULL
         if      (groupByMonth) dtTo = DateTime1(TimeYearEx(now), TimeMonth(now)+1)       - 1*SECOND;    // aktuelles Monatsende
         else if (groupByWeek ) dtTo = now - now%DAYS + (7-TimeDayOfWeekEx(now))%7 * DAYS - 1*SECOND;    // aktuelles Wochenende
         else if (groupByDay  ) dtTo = now - now%DAYS + 1*DAY                             - 1*SECOND;    // aktuelles Tagesende
      }

      for (bool firstGroup=true; groupFrom < dtTo; groupFrom=nextGroupFrom) {
         if      (groupByMonth) nextGroupFrom = DateTime1(TimeYearEx(groupFrom), TimeMonth(groupFrom)+1);
         else if (groupByWeek ) nextGroupFrom = groupFrom + 7*DAYS;
         else if (groupByDay  ) nextGroupFrom = groupFrom + 1*DAY;
         groupTo   = nextGroupFrom - 1*SECOND;
         groupFrom = Max(groupFrom, dtFrom);
         groupTo   = Min(groupTo,   dtTo  );
         //debug("ParseHstTerm(0.2)  group from="+ TimeToStr(groupFrom) +"  to="+ TimeToStr(groupTo));

         // Kommentar erstellen
         if      (groupByMonth) comment =             GmtTimeFormat(groupFrom, "%Y %B");
         else if (groupByWeek ) comment = "Week of "+ GmtTimeFormat(groupFrom, "%d.%m.%Y");
         else if (groupByDay  ) comment =             GmtTimeFormat(groupFrom, "%d.%m.%Y");
         if (isTotalHistory)    comment = comment +" (total)";

         // Gruppe der globalen Konfiguration hinzufügen
         int confSize = ArrayRange(positions.config, 0);
         ArrayResize(positions.config, confSize+1);
         positions.config[confSize][I_TERM_TYPE]   = ifInt(!isTotalHistory, TERM_HISTORY, TERM_HISTORY_TOTAL);
         positions.config[confSize][I_TERM_VALUE1] = groupFrom;
         positions.config[confSize][I_TERM_VALUE2] = groupTo;
         positions.config[confSize][I_TERM_CACHE1] = EMPTY_VALUE;
         positions.config[confSize][I_TERM_CACHE2] = EMPTY_VALUE;
         isEmptyPosition = false;

         // Zeile mit Zeilenende abschließen (außer bei der letzten Gruppe)
         if (nextGroupFrom <= dtTo) {
            ArrayResize    (positions.config, confSize+2);           // initialisiert Element mit NULL
            ArrayPushString(positions.config.comments, comment + ifString(StringLen(positionComment), ", ", "") + positionComment);
            if (firstGroup) positionComment = "";                    // für folgende Gruppen wird der konfigurierte Kommentar nicht ständig wiederholt
         }
      }
   }
   else {
      // (4) normale Rückgabewerte ohne Gruppierung
      if (isSingleTimespan) {
         if      (isFullYear1  ) comment =             GmtTimeFormat(dtFrom, "%Y");
         else if (isFullMonth1 ) comment =             GmtTimeFormat(dtFrom, "%Y %B");
         else if (isFullWeek1  ) comment = "Week of "+ GmtTimeFormat(dtFrom, "%d.%m.%Y");
         else if (isFullDay1   ) comment =             GmtTimeFormat(dtFrom, "%d.%m.%Y");
         else if (isFullHour1  ) comment =             GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M") + GmtTimeFormat(dtTo+1*SECOND, "-%H:%M");
         else if (isFullMinute1) comment =             GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M");
         else                    comment =             GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S");
      }
      else if (!dtTo) {
         if      (isFullYear1  ) comment = "since "+   GmtTimeFormat(dtFrom, "%Y");
         else if (isFullMonth1 ) comment = "since "+   GmtTimeFormat(dtFrom, "%B %Y");
         else if (isFullWeek1  ) comment = "since "+   GmtTimeFormat(dtFrom, "%d.%m.%Y");
         else if (isFullDay1   ) comment = "since "+   GmtTimeFormat(dtFrom, "%d.%m.%Y");
         else if (isFullHour1  ) comment = "since "+   GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M");
         else if (isFullMinute1) comment = "since "+   GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M");
         else                    comment = "since "+   GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S");
      }
      else if (!dtFrom) {
         if      (isFullYear2  ) comment = "to "+      GmtTimeFormat(dtTo,          "%Y");
         else if (isFullMonth2 ) comment = "to "+      GmtTimeFormat(dtTo,          "%B %Y");
         else if (isFullWeek2  ) comment = "to "+      GmtTimeFormat(dtTo,          "%d.%m.%Y");
         else if (isFullDay2   ) comment = "to "+      GmtTimeFormat(dtTo,          "%d.%m.%Y");
         else if (isFullHour2  ) comment = "to "+      GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");
         else if (isFullMinute2) comment = "to "+      GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");
         else                    comment = "to "+      GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S");
      }
      else {
         // von und bis angegeben
         if      (isFullYear1  ) {
            if      (isFullYear2  ) comment = GmtTimeFormat(dtFrom, "%Y")                +" to "+ GmtTimeFormat(dtTo,          "%Y");                // 2014 - 2015
            else if (isFullMonth2 ) comment = GmtTimeFormat(dtFrom, "%B %Y")             +" to "+ GmtTimeFormat(dtTo,          "%B %Y");             // 2014 - 2015.01
            else if (isFullWeek2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014 - 2015.01.15W
            else if (isFullDay2   ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014 - 2015.01.15
            else if (isFullHour2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014 - 2015.01.15 12:00
            else if (isFullMinute2) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014 - 2015.01.15 12:34
            else                    comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S"); // 2014 - 2015.01.15 12:34:56
         }
         else if (isFullMonth1 ) {
            if      (isFullYear2  ) comment = GmtTimeFormat(dtFrom, "%B %Y")             +" to "+ GmtTimeFormat(dtTo,          "%B %Y");             // 2014.01 - 2015
            else if (isFullMonth2 ) comment = GmtTimeFormat(dtFrom, "%B %Y")             +" to "+ GmtTimeFormat(dtTo,          "%B %Y");             // 2014.01 - 2015.01
            else if (isFullWeek2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01 - 2015.01.15W
            else if (isFullDay2   ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01 - 2015.01.15
            else if (isFullHour2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01 - 2015.01.15 12:00
            else if (isFullMinute2) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01 - 2015.01.15 12:34
            else                    comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S"); // 2014.01 - 2015.01.15 12:34:56
         }
         else if (isFullWeek1  ) {
            if      (isFullYear2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15W - 2015
            else if (isFullMonth2 ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15W - 2015.01
            else if (isFullWeek2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15W - 2015.01.15W
            else if (isFullDay2   ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15W - 2015.01.15
            else if (isFullHour2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15W - 2015.01.15 12:00
            else if (isFullMinute2) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15W - 2015.01.15 12:34
            else                    comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S"); // 2014.01.15W - 2015.01.15 12:34:56
         }
         else if (isFullDay1   ) {
            if      (isFullYear2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 - 2015
            else if (isFullMonth2 ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 - 2015.01
            else if (isFullWeek2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 - 2015.01.15W
            else if (isFullDay2   ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 - 2015.01.15
            else if (isFullHour2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 - 2015.01.15 12:00
            else if (isFullMinute2) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 - 2015.01.15 12:34
            else                    comment = GmtTimeFormat(dtFrom, "%d.%m.%Y")          +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S"); // 2014.01.15 - 2015.01.15 12:34:56
         }
         else if (isFullHour1  ) {
            if      (isFullYear2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:00 - 2015
            else if (isFullMonth2 ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:00 - 2015.01
            else if (isFullWeek2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:00 - 2015.01.15W
            else if (isFullDay2   ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:00 - 2015.01.15
            else if (isFullHour2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 12:00 - 2015.01.15 12:00
            else if (isFullMinute2) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 12:00 - 2015.01.15 12:34
            else                    comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S"); // 2014.01.15 12:00 - 2015.01.15 12:34:56
         }
         else if (isFullMinute1) {
            if      (isFullYear2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34 - 2015
            else if (isFullMonth2 ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34 - 2015.01
            else if (isFullWeek2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34 - 2015.01.15W
            else if (isFullDay2   ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34 - 2015.01.15
            else if (isFullHour2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 12:34 - 2015.01.15 12:00
            else if (isFullMinute2) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 12:34 - 2015.01.15 12:34
            else                    comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M")    +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S"); // 2014.01.15 12:34 - 2015.01.15 12:34:56
         }
         else {
            if      (isFullYear2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S") +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34:56 - 2015
            else if (isFullMonth2 ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S") +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34:56 - 2015.01
            else if (isFullWeek2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S") +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34:56 - 2015.01.15W
            else if (isFullDay2   ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S") +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y");          // 2014.01.15 12:34:56 - 2015.01.15
            else if (isFullHour2  ) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S") +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 12:34:56 - 2015.01.15 12:00
            else if (isFullMinute2) comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S") +" to "+ GmtTimeFormat(dtTo+1*SECOND, "%d.%m.%Y %H:%M");    // 2014.01.15 12:34:56 - 2015.01.15 12:34
            else                    comment = GmtTimeFormat(dtFrom, "%d.%m.%Y %H:%M:%S") +" to "+ GmtTimeFormat(dtTo,          "%d.%m.%Y %H:%M:%S"); // 2014.01.15 12:34:56 - 2015.01.15 12:34:56
         }
      }
      if (isTotalHistory) comment = comment +" (total)";
      from = dtFrom;
      to   = dtTo;
   }

   if (!StringLen(hstComments)) hstComments = comment;
   else                         hstComments = hstComments +", "+ comment;
   return(!catch("CustomPositions.ParseHstTerm(6)"));
}


/**
 * Parst eine Zeitpunktbeschreibung. Kann ein allgemeiner Zeitraum (2014.03) oder ein genauer Zeitpunkt (2014.03.12 12:34:56) sein.
 *
 * @param  _In_  string value    - zu parsender String
 * @param  _Out_ bool   isYear   - ob ein allgemein formulierter Zeitraum ein Jahr beschreibt,    z.B. "2014"        oder "ThisYear"
 * @param  _Out_ bool   isMonth  - ob ein allgemein formulierter Zeitraum einen Monat beschreibt, z.B. "2014.02"     oder "LastMonth"
 * @param  _Out_ bool   isWeek   - ob ein allgemein formulierter Zeitraum eine Woche beschreibt,  z.B. "2014.02.15W" oder "ThisWeek"
 * @param  _Out_ bool   isDay    - ob ein allgemein formulierter Zeitraum einen Tag beschreibt,   z.B. "2014.02.18"  oder "Yesterday" (Synonym für LastDay)
 * @param  _Out_ bool   isHour   - ob ein allgemein formulierter Zeitraum eine Stunde beschreibt, z.B. "2014.02.18 12:00"
 * @param  _Out_ bool   isMinute - ob ein allgemein formulierter Zeitraum eine Minute beschreibt, z.B. "2014.02.18 12:34"
 *
 * @return datetime - Zeitpunkt oder NaT (Not-A-Time), falls ein Fehler auftrat
 *
 *
 * Format:
 * -------
 *  {value} = 2014[.01[.15 [W|12:34[:56]]]]    oder
 *  {value} = (This|Last)(Day|Week|Month|Year) oder
 *  {value} = Today                            • Synonym für ThisDay
 *  {value} = Yesterday                        • Synonym für LastDay
 */
datetime ParseDateTimeEx(string value, bool &isYear, bool &isMonth, bool &isWeek, bool &isDay, bool &isHour, bool &isMinute) {
   string values[], origValue=value, sYY, sMM, sDD, sTime, sHH, sII, sSS;
   int valuesSize, iYY, iMM, iDD, iHH, iII, iSS, dow;

   isYear   = false;
   isMonth  = false;
   isWeek   = false;
   isDay    = false;
   isHour   = false;
   isMinute = false;

   value = StrTrim(value); if (value == "") return(NULL);

   // (1) Ausdruck parsen
   if (!StrIsDigits(StrLeft(value, 1))) {
      datetime date, now = TimeFXT(); if (!now) return(_NaT(logInfo("ParseDateTimeEx(1)->TimeFXT() => 0", ERR_RUNTIME_ERROR)));

      // (1.1) alphabetischer Ausdruck
      if (StrEndsWith(value, "DAY")) {
         if      (value == "TODAY"    ) value = "THISDAY";
         else if (value == "YESTERDAY") value = "LASTDAY";

         date = now;
         dow  = TimeDayOfWeekEx(date);
         if      (dow == SATURDAY) date -= 1*DAY;                    // an Wochenenden Datum auf den vorherigen Freitag setzen
         else if (dow == SUNDAY  ) date -= 2*DAYS;

         if (value != "THISDAY") {
            if (value != "LASTDAY")                                  return(_NaT(catch("ParseDateTimeEx(1)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            if (dow != MONDAY) date -= 1*DAY;                        // Datum auf den vorherigen Tag setzen
            else               date -= 3*DAYS;                       // an Wochenenden Datum auf den vorherigen Freitag setzen
         }
         iYY   = TimeYearEx(date);
         iMM   = TimeMonth (date);
         iDD   = TimeDayEx (date);
         isDay = true;
      }

      else if (StrEndsWith(value, "WEEK")) {
         date = now - (TimeDayOfWeekEx(now)+6)%7 * DAYS;             // Datum auf Wochenbeginn setzen
         if (value != "THISWEEK") {
            if (value != "LASTWEEK")                                 return(_NaT(catch("ParseDateTimeEx(2)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            date -= 1*WEEK;                                          // Datum auf die vorherige Woche setzen
         }
         iYY    = TimeYearEx(date);
         iMM    = TimeMonth (date);
         iDD    = TimeDayEx (date);
         isWeek = true;
      }

      else if (StrEndsWith(value, "MONTH")) {
         date = now;
         if (value != "THISMONTH") {
            if (value != "LASTMONTH")                                return(_NaT(catch("ParseDateTimeEx(3)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            date = DateTime1(TimeYearEx(date), TimeMonth(date)-1);   // Datum auf den vorherigen Monat setzen
         }
         iYY     = TimeYearEx(date);
         iMM     = TimeMonth (date);
         iDD     = 1;
         isMonth = true;
      }

      else if (StrEndsWith(value, "YEAR")) {
         date = now;
         if (value != "THISYEAR") {
            if (value != "LASTYEAR")                                 return(_NaT(catch("ParseDateTimeEx(4)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            date = DateTime1(TimeYearEx(date)-1);                    // Datum auf das vorherige Jahr setzen
         }
         iYY    = TimeYearEx(date);
         iMM    = 1;
         iDD    = 1;
         isYear = true;
      }
      else                                                           return(_NaT(catch("ParseDateTimeEx(5)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
   }

   else {
      // (1.2) numerischer Ausdruck
      // 2014
      // 2014.01
      // 2014.01.15
      // 2014.01.15W
      // 2014.01.15 12:34
      // 2014.01.15 12:34:56
      valuesSize = Explode(value, ".", values, NULL);
      if (valuesSize > 3)                                            return(_NaT(catch("ParseDateTimeEx(6)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));

      if (valuesSize >= 1) {
         sYY = StrTrim(values[0]);                                   // Jahr prüfen
         if (StringLen(sYY) != 4)                                    return(_NaT(catch("ParseDateTimeEx(7)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         if (!StrIsDigits(sYY))                                      return(_NaT(catch("ParseDateTimeEx(8)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         iYY = StrToInteger(sYY);
         if (iYY < 1970 || 2037 < iYY)                               return(_NaT(catch("ParseDateTimeEx(9)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         if (valuesSize == 1) {
            iMM    = 1;
            iDD    = 1;
            isYear = true;
         }
      }

      if (valuesSize >= 2) {
         sMM = StrTrim(values[1]);                                   // Monat prüfen
         if (StringLen(sMM) > 2)                                     return(_NaT(catch("ParseDateTimeEx(10)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         if (!StrIsDigits(sMM))                                      return(_NaT(catch("ParseDateTimeEx(11)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         iMM = StrToInteger(sMM);
         if (iMM < 1 || 12 < iMM)                                    return(_NaT(catch("ParseDateTimeEx(12)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         if (valuesSize == 2) {
            iDD     = 1;
            isMonth = true;
         }
      }

      if (valuesSize == 3) {
         sDD = StrTrim(values[2]);
         if (StrEndsWith(sDD, "W")) {                                // Tag + Woche: "2014.01.15 W"
            isWeek = true;
            sDD    = StrTrim(StrLeft(sDD, -1));
         }
         else if (StringLen(sDD) > 2) {                              // Tag + Zeit:  "2014.01.15 12:34:56"
            int pos = StringFind(sDD, " ");
            if (pos == -1)                                           return(_NaT(catch("ParseDateTimeEx(13)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            sTime = StrTrim(StrSubstr(sDD, pos+1));
            sDD   = StrTrim(StrLeft (sDD,  pos  ));
         }
         else {                                                      // nur Tag
            isDay = true;
         }
                                                                     // Tag prüfen
         if (StringLen(sDD) > 2)                                     return(_NaT(catch("ParseDateTimeEx(14)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         if (!StrIsDigits(sDD))                                      return(_NaT(catch("ParseDateTimeEx(15)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         iDD = StrToInteger(sDD);
         if (iDD < 1 || 31 < iDD)                                    return(_NaT(catch("ParseDateTimeEx(16)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         if (iDD > 28) {
            if (iMM == FEB) {
               if (iDD > 29)                                         return(_NaT(catch("ParseDateTimeEx(17)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
               if (!IsLeapYear(iYY))                                 return(_NaT(catch("ParseDateTimeEx(18)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            }
            else if (iDD==31)
               if (iMM==APR || iMM==JUN || iMM==SEP || iMM==NOV)     return(_NaT(catch("ParseDateTimeEx(19)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         }

         if (StringLen(sTime) > 0) {                                 // Zeit prüfen
            // hh:ii:ss
            valuesSize = Explode(sTime, ":", values, NULL);
            if (valuesSize < 2 || 3 < valuesSize)                    return(_NaT(catch("ParseDateTimeEx(20)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));

            sHH = StrTrim(values[0]);                                // Stunden
            if (StringLen(sHH) > 2)                                  return(_NaT(catch("ParseDateTimeEx(21)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            if (!StrIsDigits(sHH))                                   return(_NaT(catch("ParseDateTimeEx(22)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            iHH = StrToInteger(sHH);
            if (iHH < 0 || 23 < iHH)                                 return(_NaT(catch("ParseDateTimeEx(23)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));

            sII = StrTrim(values[1]);                                // Minuten
            if (StringLen(sII) > 2)                                  return(_NaT(catch("ParseDateTimeEx(24)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            if (!StrIsDigits(sII))                                   return(_NaT(catch("ParseDateTimeEx(25)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            iII = StrToInteger(sII);
            if (iII < 0 || 59 < iII)                                 return(_NaT(catch("ParseDateTimeEx(26)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            if (valuesSize == 2) {
               if (!iII) isHour   = true;
               else      isMinute = true;
            }

            if (valuesSize == 3) {
               sSS = StrTrim(values[2]);                             // Sekunden
               if (StringLen(sSS) > 2)                               return(_NaT(catch("ParseDateTimeEx(27)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
               if (!StrIsDigits(sSS))                                return(_NaT(catch("ParseDateTimeEx(28)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
               iSS = StrToInteger(sSS);
               if (iSS < 0 || 59 < iSS)                              return(_NaT(catch("ParseDateTimeEx(29)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            }
         }
      }
   }


   // (2) DateTime aus geparsten Werten erzeugen
   datetime result = DateTime1(iYY, iMM, iDD, iHH, iII, iSS);
   if (isWeek)                                                       // wenn volle Woche, dann Zeit auf Wochenbeginn setzen
      result -= (TimeDayOfWeekEx(result)+6)%7 * DAYS;
   return(result);
}


/**
 * Extrahiert aus dem Bestand der übergebenen Positionen {fromVars} eine Teilposition und fügt sie dem Bestand einer
 * CustomPosition {customVars} hinzu.
 *
 * @param  _In_    int    termType        -+
 * @param  _In_    double termValue1       |
 * @param  _In_    double termValue2       +--> struct POSITION_CONFIG_TERM { int type; double value1; double value2; double cache1; double cache2; }
 * @param  _InOut_ double termCache1       |
 * @param  _InOut_ double termCache2      -+
 *
 * @param  _InOut_ mixed  fromVars            - Variablen, aus denen die Teilposition extrahiert wird (Bestand verringert sich)
 *                 ....
 * @param  _InOut_ mixed  customVars          - Variablen, denen die extrahierte Position hinzugefügt wird (Bestand erhöht sich)
 *                 ....
 * @param  _Out_   double profitMarkerPrice   - PL marker price level (if configured)
 * @param  _Out_   double profitMarkerPercent - PL marker percent level (if configured)
 * @param  _Out_   double lossMarkerPrice     - PL marker price level (if configured)
 * @param  _Out_   double lossMarkerPercent   - PL marker percent level (if configured)
 * @param  _InOut_ bool   isCustomVirtual     - ob die resultierende CustomPosition virtuell ist
 * @param  _In_    int    flags [optional]    - control flags, supported values:
 *                                               F_SHOW_CUSTOM_HISTORY: call ShowTradeHistory() for the configured history
 * @return bool - success status
 */
bool ExtractPosition(int termType, double termValue1, double termValue2, double &termCache1, double &termCache2,
                     double &longPosition,       double &shortPosition,       double &totalPosition,       int &tickets[],       int &types[],       double &lots[],       datetime &openTimes[], double &openPrices[],       double &commissions[],       double &swaps[],       double &profits[],
                     double &customLongPosition, double &customShortPosition, double &customTotalPosition, int &customTickets[], int &customTypes[], double &customLots[],                        double &customOpenPrices[], double &customCommissions[], double &customSwaps[], double &customProfits[], double &closedProfit, double &adjustedProfit, double &customEquity, double &profitMarkerPrice, double &profitMarkerPercent, double &lossMarkerPrice, double &lossMarkerPercent,
                     bool   &isCustomVirtual, int flags = NULL) {
   isCustomVirtual = isCustomVirtual!=0;

   double   lotsize;
   datetime from, to;
   int ticket, sizeTickets = ArraySize(tickets);

   if (termType == TERM_OPEN_LONG) {
      lotsize = termValue1;

      if (lotsize == EMPTY) {
         // alle übrigen Long-Positionen
         if (longPosition > 0) {
            for (int i=0; i < sizeTickets; i++) {
               if (!tickets[i])
                  continue;
               if (types[i] == OP_BUY) {
                  // Daten nach custom.* übernehmen und Ticket ggf. auf NULL setzen
                  ArrayPushInt   (customTickets,     tickets    [i]);
                  ArrayPushInt   (customTypes,       types      [i]);
                  ArrayPushDouble(customLots,        lots       [i]);
                  ArrayPushDouble(customOpenPrices,  openPrices [i]);
                  ArrayPushDouble(customCommissions, commissions[i]);
                  ArrayPushDouble(customSwaps,       swaps      [i]);
                  ArrayPushDouble(customProfits,     profits    [i]);
                  if (!isCustomVirtual) {
                     longPosition  = NormalizeDouble(longPosition - lots[i],       2);
                     totalPosition = NormalizeDouble(longPosition - shortPosition, 2);
                     tickets[i]    = NULL;
                  }
                  customLongPosition  = NormalizeDouble(customLongPosition + lots[i],             3);
                  customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 3);
               }
            }
         }
      }
      else {
         // virtuelle Long-Position zu custom.* hinzufügen (Ausgangsdaten bleiben unverändert)
         if (lotsize != 0) {                                         // 0-Lots-Positionen werden übersprungen (es gibt nichts abzuziehen oder hinzuzufügen)
            double openPrice = ifDouble(termValue2!=0, termValue2, Ask);
            ArrayPushInt   (customTickets,     TERM_OPEN_LONG                                );
            ArrayPushInt   (customTypes,       OP_BUY                                        );
            ArrayPushDouble(customLots,        lotsize                                       );
            ArrayPushDouble(customOpenPrices,  openPrice                                     );
            ArrayPushDouble(customCommissions, NormalizeDouble(-GetCommission(lotsize), 2)   );
            ArrayPushDouble(customSwaps,       0                                             );
            ArrayPushDouble(customProfits,     (Bid-openPrice)/Pip * PipValue(lotsize, true));  // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
            customLongPosition  = NormalizeDouble(customLongPosition + lotsize,             3);
            customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 3);
         }
         isCustomVirtual = true;
      }
   }

   else if (termType == TERM_OPEN_SHORT) {
      lotsize = termValue1;

      if (lotsize == EMPTY) {
         // alle übrigen Short-Positionen
         if (shortPosition > 0) {
            for (i=0; i < sizeTickets; i++) {
               if (!tickets[i])
                  continue;
               if (types[i] == OP_SELL) {
                  // Daten nach custom.* übernehmen und Ticket ggf. auf NULL setzen
                  ArrayPushInt   (customTickets,     tickets    [i]);
                  ArrayPushInt   (customTypes,       types      [i]);
                  ArrayPushDouble(customLots,        lots       [i]);
                  ArrayPushDouble(customOpenPrices,  openPrices [i]);
                  ArrayPushDouble(customCommissions, commissions[i]);
                  ArrayPushDouble(customSwaps,       swaps      [i]);
                  ArrayPushDouble(customProfits,     profits    [i]);
                  if (!isCustomVirtual) {
                     shortPosition = NormalizeDouble(shortPosition - lots[i],       2);
                     totalPosition = NormalizeDouble(longPosition  - shortPosition, 2);
                     tickets[i]    = NULL;
                  }
                  customShortPosition = NormalizeDouble(customShortPosition + lots[i],             3);
                  customTotalPosition = NormalizeDouble(customLongPosition  - customShortPosition, 3);
               }
            }
         }
      }
      else {
         // virtuelle Short-Position zu custom.* hinzufügen (Ausgangsdaten bleiben unverändert)
         if (lotsize != 0) {                                         // 0-Lots-Positionen werden übersprungen (es gibt nichts abzuziehen oder hinzuzufügen)
            openPrice = ifDouble(termValue2!=0, termValue2, Bid);
            ArrayPushInt   (customTickets,     TERM_OPEN_SHORT                               );
            ArrayPushInt   (customTypes,       OP_SELL                                       );
            ArrayPushDouble(customLots,        lotsize                                       );
            ArrayPushDouble(customOpenPrices,  openPrice                                     );
            ArrayPushDouble(customCommissions, NormalizeDouble(-GetCommission(lotsize), 2)   );
            ArrayPushDouble(customSwaps,       0                                             );
            ArrayPushDouble(customProfits,     (openPrice-Ask)/Pip * PipValue(lotsize, true));  // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
            customShortPosition = NormalizeDouble(customShortPosition + lotsize,            3);
            customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 3);
         }
         isCustomVirtual = true;
      }
   }

   else if (termType == TERM_OPEN) {
      from = termValue1;
      to   = termValue2;

      // offene Positionen des aktuellen Symbols eines Zeitraumes
      if (longPosition || shortPosition) {
         for (i=0; i < sizeTickets; i++) {
            if (!tickets[i])                 continue;
            if (from && openTimes[i] < from) continue;
            if (to   && openTimes[i] > to  ) continue;

            // Daten nach custom.* übernehmen und Ticket ggf. auf NULL setzen
            ArrayPushInt   (customTickets,     tickets    [i]);
            ArrayPushInt   (customTypes,       types      [i]);
            ArrayPushDouble(customLots,        lots       [i]);
            ArrayPushDouble(customOpenPrices,  openPrices [i]);
            ArrayPushDouble(customCommissions, commissions[i]);
            ArrayPushDouble(customSwaps,       swaps      [i]);
            ArrayPushDouble(customProfits,     profits    [i]);
            if (!isCustomVirtual) {
               if (types[i] == OP_BUY) longPosition     = NormalizeDouble(longPosition  - lots[i]      , 2);
               else                    shortPosition    = NormalizeDouble(shortPosition - lots[i]      , 2);
                                       totalPosition    = NormalizeDouble(longPosition  - shortPosition, 2);
                                       tickets[i]       = NULL;
            }
            if (types[i] == OP_BUY) customLongPosition  = NormalizeDouble(customLongPosition  + lots[i]            , 3);
            else                    customShortPosition = NormalizeDouble(customShortPosition + lots[i]            , 3);
                                    customTotalPosition = NormalizeDouble(customLongPosition  - customShortPosition, 3);
         }
      }
   }

   else if (termType==TERM_HISTORY || termType==TERM_HISTORY_TOTAL) {
      // geschlossene Positionen des aktuellen oder aller Symbole eines Zeitraumes
      from              = termValue1;
      to                = termValue2;
      double lastProfit = termCache1;     // default: EMPTY_VALUE
      int    lastOrders = termCache2;     // default: EMPTY_VALUE                // Anzahl der Tickets in der History: ändert sie sich, wird der PL neu berechnet

      int orders=OrdersHistoryTotal(), _orders=orders;

      if (orders != lastOrders) {
         // Sortierschlüssel aller geschlossenen Positionen auslesen und nach {CloseTime, OpenTime, Ticket} sortieren
         int sortKeys[][3], n, hst.ticket;                                 // {CloseTime, OpenTime, Ticket}
         ArrayResize(sortKeys, orders);

         for (i=0; i < orders; i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) break;             // FALSE: während des Auslesens wurde der Anzeigezeitraum der History verkürzt

            // wenn OrderType()==OP_BALANCE, dann OrderSymbol()==Leerstring
            if (OrderType() == OP_BALANCE) {
               // Dividenden                                                     // "Ex Dividend US2000" oder
               if (StrStartsWithI(OrderComment(), "ex dividend ")) {             // "Ex Dividend 17/03/15 US2000"
                  if (termType == TERM_HISTORY)                                  // single history
                     if (!StrEndsWithI(OrderComment(), " "+ Symbol())) continue; // ok, wenn zum aktuellen Symbol gehörend
               }
               // Rollover adjustments
               else if (StrStartsWithI(OrderComment(), "adjustment ")) {         // "Adjustment BRENT"
                  if (termType == TERM_HISTORY)                                  // single history
                     if (!StrEndsWithI(OrderComment(), " "+ Symbol())) continue; // ok, wenn zum aktuellen Symbol gehörend
               }
               else continue;                                                    // sonstige Balance-Einträge
            }
            else {
               if (OrderType() > OP_SELL)                                      continue;
               if (termType==TERM_HISTORY) /*&&*/ if (OrderSymbol()!=Symbol()) continue;    // ggf. Positionen aller Symbole
            }

            sortKeys[n][0] = OrderCloseTime();
            sortKeys[n][1] = OrderOpenTime();
            sortKeys[n][2] = OrderTicket();
            n++;
         }
         orders = n;
         ArrayResize(sortKeys, orders);
         SortClosedTickets(sortKeys);

         // Tickets sortiert einlesen
         int      hst.tickets    []; ArrayResize(hst.tickets,     orders);
         int      hst.types      []; ArrayResize(hst.types,       orders);
         double   hst.lotSizes   []; ArrayResize(hst.lotSizes,    orders);
         datetime hst.openTimes  []; ArrayResize(hst.openTimes,   orders);
         datetime hst.closeTimes []; ArrayResize(hst.closeTimes,  orders);
         double   hst.openPrices []; ArrayResize(hst.openPrices,  orders);
         double   hst.closePrices[]; ArrayResize(hst.closePrices, orders);
         double   hst.commissions[]; ArrayResize(hst.commissions, orders);
         double   hst.swaps      []; ArrayResize(hst.swaps,       orders);
         double   hst.profits    []; ArrayResize(hst.profits,     orders);
         string   hst.comments   []; ArrayResize(hst.comments,    orders);
         bool     hst.valid      []; ArrayResize(hst.valid,       orders);

         for (i=0; i < orders; i++) {
            if (!SelectTicket(sortKeys[i][2], "ExtractPosition(1)")) return(false);
            hst.tickets    [i] = OrderTicket();
            hst.types      [i] = OrderType();
            hst.lotSizes   [i] = OrderLots();
            hst.openTimes  [i] = OrderOpenTime();
            hst.closeTimes [i] = OrderCloseTime();
            hst.openPrices [i] = OrderOpenPrice();
            hst.closePrices[i] = OrderClosePrice();
            hst.commissions[i] = OrderCommission();
            hst.swaps      [i] = OrderSwap();
            hst.profits    [i] = OrderProfit();
            hst.comments   [i] = OrderComment();
            hst.valid      [i] = true;
         }

         // Hedges korrigieren: alle Daten dem ersten Ticket zuordnen und hedgendes Ticket verwerfen (auch Positionen mehrerer Symbole werden korrekt zugeordnet)
         for (i=0; i < orders; i++) {
            if (hst.tickets[i] && EQ(hst.lotSizes[i], 0)) {                      // lotSize = 0: Hedge-Position
               // TODO: Prüfen, wie sich OrderComment() bei custom comments verhält.
               if (!StrStartsWithI(hst.comments[i], "close hedge by #"))
                  return(!catch("ExtractPosition(2)  #"+ hst.tickets[i] +" - unknown comment for assumed hedging position "+ DoubleQuoteStr(hst.comments[i]), ERR_RUNTIME_ERROR));

               // Gegenstück suchen
               hst.ticket = StrToInteger(StringSubstr(hst.comments[i], 16));
               for (n=0; n < orders; n++) {
                  if (hst.tickets[n] == hst.ticket) break;
               }
               if (n == orders) return(!catch("ExtractPosition(3)  cannot find counterpart for hedging position #"+ hst.tickets[i] +" "+ DoubleQuoteStr(hst.comments[i]), ERR_RUNTIME_ERROR));
               if (i == n     ) return(!catch("ExtractPosition(4)  both hedged and hedging position have the same ticket #"+ hst.tickets[i] +" "+ DoubleQuoteStr(hst.comments[i]), ERR_RUNTIME_ERROR));

               int first  = Min(i, n);
               int second = Max(i, n);

               // Orderdaten korrigieren
               if (i == first) {
                  hst.lotSizes   [first] = hst.lotSizes   [second];              // alle Transaktionsdaten in der ersten Order speichern
                  hst.commissions[first] = hst.commissions[second];
                  hst.swaps      [first] = hst.swaps      [second];
                  hst.profits    [first] = hst.profits    [second];
               }
               hst.closeTimes [first] = hst.openTimes [second];
               hst.closePrices[first] = hst.openPrices[second];

               hst.closeTimes[second] = hst.closeTimes[first];                   // CloseTime des hedgenden Tickets auf die erste Order setzen, damit es durch den Zeitfilter kommt und an ShowTradeHistory() übergeben werden kann
               hst.valid     [second] = false;                                   // hedgendes Ticket als verworfen markieren
            }
         }

         // Trades auswerten
         int showTickets[]; ArrayResize(showTickets, 0);
         lastProfit=0; n=0;

         for (i=0; i < orders; i++) {
            if (from && hst.closeTimes[i] < from) continue;
            if (to   && hst.closeTimes[i] > to  ) continue;
            ArrayPushInt(showTickets, hst.tickets[i]);                           // collect tickets to pass to ShowTradeHistory()
            if (!hst.valid[i])                    continue;                      // verworfene Hedges überspringen
            lastProfit += hst.commissions[i] + hst.swaps[i] + hst.profits[i];
            n++;
         }                                                                       // call ShowTradeHistory() if specified
         if (flags & F_SHOW_CUSTOM_HISTORY && ArraySize(showTickets)) ShowTradeHistory(showTickets);

         if (!n) lastProfit = EMPTY_VALUE;                                       // keine passenden geschlossenen Trades gefunden
         else    lastProfit = NormalizeDouble(lastProfit, 2);
         termCache1         = lastProfit;
         termCache2         = _orders;
         //debug("ExtractPosition(0.1)  from="+ ifString(from, TimeToStr(from), "start") +"  to="+ ifString(to, TimeToStr(to), "end") +"  profit="+ ifString(IsEmptyValue(lastProfit), "empty", DoubleToStr(lastProfit, 2)) +"  closed trades="+ n);
      }
      // lastProfit zu closedProfit hinzufügen, wenn geschlossene Trades existierten (Ausgangsdaten bleiben unverändert)
      if (lastProfit != EMPTY_VALUE) {
         if (closedProfit == EMPTY_VALUE) closedProfit  = lastProfit;
         else                             closedProfit += lastProfit;
      }
   }

   else if (termType == TERM_PL_ADJUSTMENT) {
      // Betrag zu adjustedProfit hinzufügen (Ausgangsdaten bleiben unverändert)
      adjustedProfit += termValue1;
   }

   else if (termType == TERM_EQUITY) {
      // vorhandenen Betrag überschreiben (Ausgangsdaten bleiben unverändert)
      customEquity = termValue1;
   }

   else if (termType == TERM_PROFIT_MARKER) {
      profitMarkerPrice   = termValue1;
      profitMarkerPercent = termValue2;
   }

   else if (termType == TERM_LOSS_MARKER) {
      lossMarkerPrice   = termValue1;
      lossMarkerPercent = termValue2;
   }

   else if (termType == TERM_TICKET) {
      ticket  = termValue1;
      lotsize = termValue2;

      if (lotsize == EMPTY) {
         // komplettes Ticket
         for (i=0; i < sizeTickets; i++) {
            if (tickets[i] == ticket) {
               // Daten nach custom.* übernehmen und Ticket ggf. auf NULL setzen
               ArrayPushInt   (customTickets,     tickets    [i]);
               ArrayPushInt   (customTypes,       types      [i]);
               ArrayPushDouble(customLots,        lots       [i]);
               ArrayPushDouble(customOpenPrices,  openPrices [i]);
               ArrayPushDouble(customCommissions, commissions[i]);
               ArrayPushDouble(customSwaps,       swaps      [i]);
               ArrayPushDouble(customProfits,     profits    [i]);
               if (!isCustomVirtual) {
                  if (types[i] == OP_BUY) longPosition        = NormalizeDouble(longPosition  - lots[i],       2);
                  else                    shortPosition       = NormalizeDouble(shortPosition - lots[i],       2);
                                          totalPosition       = NormalizeDouble(longPosition  - shortPosition, 2);
                                          tickets[i]          = NULL;
               }
               if (types[i] == OP_BUY)    customLongPosition  = NormalizeDouble(customLongPosition  + lots[i],             3);
               else                       customShortPosition = NormalizeDouble(customShortPosition + lots[i],             3);
                                          customTotalPosition = NormalizeDouble(customLongPosition  - customShortPosition, 3);
               break;
            }
         }
      }
      else if (lotsize != 0) {                                       // 0-Lots-Positionen werden übersprungen (es gibt nichts abzuziehen oder hinzuzufügen)
         // partielles Ticket
         for (i=0; i < sizeTickets; i++) {
            if (tickets[i] == ticket) {
               if (GT(lotsize, lots[i])) return(!catch("ExtractPosition(5)  illegal partial lotsize "+ NumberToStr(lotsize, ".+") +" for ticket #"+ tickets[i] +" (only "+ NumberToStr(lots[i], ".+") +" lot remaining)", ERR_RUNTIME_ERROR));
               if (EQ(lotsize, lots[i])) {
                  // komplettes Ticket übernehmen
                  if (!ExtractPosition(TERM_TICKET, ticket, EMPTY, termCache1, termCache2,
                                       longPosition,       shortPosition,       totalPosition,       tickets,       types,       lots,       openTimes, openPrices,       commissions,       swaps,       profits,
                                       customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLots,            customOpenPrices, customCommissions, customSwaps, customProfits, closedProfit, adjustedProfit, customEquity, profitMarkerPrice, profitMarkerPercent, lossMarkerPrice, lossMarkerPercent,
                                       isCustomVirtual))
                     return(false);
               }
               else {
                  // Daten anteilig nach custom.* übernehmen und Ticket ggf. reduzieren
                  double factor = lotsize/lots[i];
                  ArrayPushInt   (customTickets,     tickets    [i]         );
                  ArrayPushInt   (customTypes,       types      [i]         );
                  ArrayPushDouble(customLots,        lotsize                ); if (!isCustomVirtual) lots       [i]  = NormalizeDouble(lots[i]-lotsize, 2); // reduzieren
                  ArrayPushDouble(customOpenPrices,  openPrices [i]         );
                  ArrayPushDouble(customSwaps,       swaps      [i]         ); if (!isCustomVirtual) swaps      [i]  = NULL;                                // komplett
                  ArrayPushDouble(customCommissions, commissions[i] * factor); if (!isCustomVirtual) commissions[i] *= (1-factor);                          // anteilig
                  ArrayPushDouble(customProfits,     profits    [i] * factor); if (!isCustomVirtual) profits    [i] *= (1-factor);                          // anteilig
                  if (!isCustomVirtual) {
                     if (types[i] == OP_BUY) longPosition        = NormalizeDouble(longPosition  - lotsize, 2);
                     else                    shortPosition       = NormalizeDouble(shortPosition - lotsize, 2);
                                             totalPosition       = NormalizeDouble(longPosition  - shortPosition, 2);
                  }
                  if (types[i] == OP_BUY)    customLongPosition  = NormalizeDouble(customLongPosition  + lotsize, 3);
                  else                       customShortPosition = NormalizeDouble(customShortPosition + lotsize, 3);
                                             customTotalPosition = NormalizeDouble(customLongPosition  - customShortPosition, 3);
               }
               break;
            }
         }
      }
   }
   else return(!catch("ExtractPosition(6)  illegal or unknown termType: "+ termType, ERR_RUNTIME_ERROR));

   return(!catch("ExtractPosition(7)"));
}


/**
 * Speichert die übergebenen Daten zusammengefaßt (direktionaler und gehedgeter Anteil gemeinsam) als eine Position in den globalen Variablen
 * positions.*Data[].
 *
 * @param  _In_    bool   isVirtual
 *
 * @param  _In_    double longPosition
 * @param  _In_    double shortPosition
 * @param  _In_    double totalPosition
 *
 * @param  _InOut_ int    tickets    []
 * @param  _In_    int    types      []
 * @param  _InOut_ double lots       []
 * @param  _In_    double openPrices []
 * @param  _InOut_ double commissions[]
 * @param  _InOut_ double swaps      []
 * @param  _InOut_ double profits    []
 *
 * @param  _In_    double closedProfit
 * @param  _In_    double adjustedProfit
 * @param  _In_    double customEquity
 * @param  _In_    double profitMarkerPrice
 * @param  _In_    double profitMarkerPercent
 * @param  _In_    double lossMarkerPrice
 * @param  _In_    double lossMarkerPercent
 * @param  _In_    int    commentIndex
 *
 * @return bool - success status
 */
bool StorePosition(bool isVirtual, double longPosition, double shortPosition, double totalPosition, int &tickets[], int types[], double &lots[], double openPrices[], double &commissions[], double &swaps[], double &profits[], double closedProfit, double adjustedProfit, double customEquity, double profitMarkerPrice, double profitMarkerPercent, double lossMarkerPrice, double lossMarkerPercent, int commentIndex) {
   isVirtual = isVirtual!=0;

   double hedgedLots, remainingLong, remainingShort, factor, openPrice, closePrice, commission, swap, floatingProfit, hedgedProfit, openProfit, fullProfit, equity, equity100Pct, pipValue, pipDistance;
   int size, ticketsSize=ArraySize(tickets);

   // Enthält die Position weder OpenProfit (offene Positionen), ClosedProfit noch AdjustedProfit, wird sie übersprungen.
   // Ein Test auf size(tickets) != 0 reicht nicht aus, da einige Tickets in tickets[] bereits auf NULL gesetzt worden sein können.
   if (!longPosition) /*&&*/ if (!shortPosition) /*&&*/ if (!totalPosition) /*&&*/ if (closedProfit==EMPTY_VALUE) /*&&*/ if (!adjustedProfit) {
      return(true);
   }
   if (closedProfit == EMPTY_VALUE) {
      closedProfit = 0;                                                    // 0.00 ist gültiger PL
   }

   static double externalAssets = EMPTY_VALUE;
   if (IsEmptyValue(externalAssets)) externalAssets = GetExternalAssets(tradeAccount.company, tradeAccount.number);

   if (customEquity != NULL) equity  = customEquity;
   else {                    equity  = externalAssets;
      if (mode.intern)       equity += (AccountEquity()-AccountCredit());  // TODO: tatsächlichen Wert von openEquity ermitteln
   }

   // Die Position besteht aus einem gehedgtem Anteil (konstanter Profit) und einem direktionalen Anteil (variabler Profit).
   // - kein direktionaler Anteil:  BE-Distance in Pip berechnen
   // - direktionaler Anteil:       Breakeven unter Berücksichtigung des Profits eines gehedgten Anteils berechnen

   // Profit und BE-Distance einer eventuellen Hedgeposition ermitteln
   if (longPosition && shortPosition) {
      hedgedLots     = MathMin(longPosition, shortPosition);
      remainingLong  = hedgedLots;
      remainingShort = hedgedLots;

      for (int i=0; i < ticketsSize; i++) {
         if (!tickets[i]) continue;

         if (types[i] == OP_BUY) {
            if (!remainingLong) continue;
            if (remainingLong >= lots[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice    += lots[i] * openPrices[i];
               swap         += swaps[i];
               commission   += commissions[i];
               remainingLong = NormalizeDouble(remainingLong - lots[i], 3);
               tickets[i]    = NULL;
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor        = remainingLong/lots[i];
               openPrice    += remainingLong * openPrices[i];
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
               // Daten komplett übernehmen, Ticket auf NULL setzen
               closePrice    += lots[i] * openPrices[i];
               swap          += swaps[i];
               //commission  += commissions[i];                                        // Commission wird nur für Long-Leg übernommen
               remainingShort = NormalizeDouble(remainingShort - lots[i], 3);
               tickets[i]     = NULL;
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor         = remainingShort/lots[i];
               closePrice    += remainingShort * openPrices[i];
               swap          += swaps[i]; swaps      [i]  = 0;
                                          commissions[i] -= factor * commissions[i];   // Commission wird nur für Long-Leg übernommen
                                          profits    [i] -= factor * profits    [i];
                                          lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 3);
               remainingShort = 0;
            }
         }
      }
      if (remainingLong  != 0) return(!catch("StorePosition(1)  illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR));
      if (remainingShort != 0) return(!catch("StorePosition(2)  illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR));

      // BE-Distance und Profit berechnen
      pipValue = PipValue(hedgedLots, true);                                           // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
      if (pipValue != 0) {
         pipDistance  = NormalizeDouble((closePrice-openPrice)/hedgedLots/Pip + (commission+swap)/pipValue, 8);
         hedgedProfit = pipDistance * pipValue;
      }

      // (1.1) Kein direktionaler Anteil: Hedge-Position speichern und Rückkehr
      if (!totalPosition) {
         size = ArrayRange(positions.iData, 0);
         ArrayResize(positions.iData, size+1);
         ArrayResize(positions.dData, size+1);

         positions.iData[size][I_CONFIG_TYPE          ] = ifInt(isVirtual, CONFIG_VIRTUAL, CONFIG_REAL);
         positions.iData[size][I_POSITION_TYPE        ] = POSITION_HEDGE;
         positions.iData[size][I_COMMENT_INDEX        ] = commentIndex;

         positions.dData[size][I_DIRECTIONAL_LOTS     ] = 0;
         positions.dData[size][I_HEDGED_LOTS          ] = hedgedLots;
         positions.dData[size][I_PIP_DISTANCE         ] = pipDistance;
         positions.dData[size][I_PROFIT_MARKER_PRICE  ] = NULL;
         positions.dData[size][I_PROFIT_MARKER_PERCENT] = NULL;
         positions.dData[size][I_LOSS_MARKER_PRICE    ] = NULL;
         positions.dData[size][I_LOSS_MARKER_PERCENT  ] = NULL;

         positions.dData[size][I_OPEN_EQUITY          ] = equity;         openProfit   = hedgedProfit;
         positions.dData[size][I_OPEN_PROFIT          ] = openProfit;
         positions.dData[size][I_CLOSED_PROFIT        ] = closedProfit;
         positions.dData[size][I_ADJUSTED_PROFIT      ] = adjustedProfit; fullProfit   = openProfit + closedProfit + adjustedProfit;
         positions.dData[size][I_FULL_PROFIT_ABS      ] = fullProfit;     equity100Pct = equity - ifDouble(!customEquity && equity > fullProfit, fullProfit, 0);
         positions.dData[size][I_FULL_PROFIT_PCT      ] = MathDiv(fullProfit, equity100Pct) * 100;

         debug("StorePosition(0.1)  flat:     absProfit="+ NumberToStr(fullProfit, ".3") +"  equity="+ NumberToStr(equity, ".3") +"  100%="+ NumberToStr(equity100Pct, ".3") +"  %Profit="+ NumberToStr(positions.dData[size][I_FULL_PROFIT_PCT], ".3"));
         return(!catch("StorePosition(3)"));
      }
   }

   // Direktionaler Anteil: Bei Breakeven-Berechnung den Profit eines gehedgten Anteils und AdjustedProfit berücksichtigen.
   // eventuelle Longposition ermitteln
   if (totalPosition > 0) {
      remainingLong  = totalPosition;
      openPrice      = 0;
      swap           = 0;
      commission     = 0;
      floatingProfit = 0;

      for (i=0; i < ticketsSize; i++) {
         if (!tickets[i]   ) continue;
         if (!remainingLong) continue;

         if (types[i] == OP_BUY) {
            if (remainingLong >= lots[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice      += lots[i] * openPrices[i];
               swap           += swaps[i];
               commission     += commissions[i];
               floatingProfit += profits[i];
               tickets[i]      = NULL;
               remainingLong   = NormalizeDouble(remainingLong - lots[i], 3);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor          = remainingLong/lots[i];
               openPrice      += remainingLong * openPrices[i];
               swap           +=          swaps[i];       swaps      [i]  = 0;
               commission     += factor * commissions[i]; commissions[i] -= factor * commissions[i];
               floatingProfit += factor * profits[i];     profits    [i] -= factor * profits    [i];
                                                          lots       [i]  = NormalizeDouble(lots[i]-remainingLong, 3);
               remainingLong = 0;
            }
         }
      }
      if (remainingLong != 0) return(!catch("StorePosition(4)  illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of long position = "+ NumberToStr(totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      size = ArrayRange(positions.iData, 0);
      ArrayResize(positions.iData, size+1);
      ArrayResize(positions.dData, size+1);

      positions.iData[size][I_CONFIG_TYPE          ] = ifInt(isVirtual, CONFIG_VIRTUAL, CONFIG_REAL);
      positions.iData[size][I_POSITION_TYPE        ] = POSITION_LONG;
      positions.iData[size][I_COMMENT_INDEX        ] = commentIndex;

      positions.dData[size][I_DIRECTIONAL_LOTS     ] = totalPosition;
      positions.dData[size][I_HEDGED_LOTS          ] = hedgedLots;
      positions.dData[size][I_BREAKEVEN_PRICE      ] = NULL;
      positions.dData[size][I_PROFIT_MARKER_PRICE  ] = NULL;
      positions.dData[size][I_PROFIT_MARKER_PERCENT] = NULL;
      positions.dData[size][I_LOSS_MARKER_PRICE    ] = NULL;
      positions.dData[size][I_LOSS_MARKER_PERCENT  ] = NULL;

      positions.dData[size][I_OPEN_EQUITY          ] = equity;         openProfit   = hedgedProfit + commission + swap + floatingProfit;
      positions.dData[size][I_OPEN_PROFIT          ] = openProfit;
      positions.dData[size][I_CLOSED_PROFIT        ] = closedProfit;
      positions.dData[size][I_ADJUSTED_PROFIT      ] = adjustedProfit; fullProfit   = openProfit + closedProfit + adjustedProfit;
      positions.dData[size][I_FULL_PROFIT_ABS      ] = fullProfit;     equity100Pct = equity - ifDouble(!customEquity && equity > fullProfit, fullProfit, 0);
      positions.dData[size][I_FULL_PROFIT_PCT      ] = MathDiv(fullProfit, equity100Pct) * 100;

      pipValue = PipValue(totalPosition, true);                         // suppress a possible ERR_SYMBOL_NOT_AVAILABLE
      if (pipValue != 0) {
         positions.dData[size][I_BREAKEVEN_PRICE] = NormalizeDouble(openPrice/totalPosition - (fullProfit-floatingProfit)/pipValue*Pip, Digits);

         if (profitMarkerPrice != NULL) {
            positions.dData[size][I_PROFIT_MARKER_PRICE  ] = profitMarkerPrice;
            positions.dData[size][I_PROFIT_MARKER_PERCENT] = NormalizeDouble((fullProfit - floatingProfit - (profitMarkerPrice-openPrice/totalPosition)/Pip*pipValue)/equity100Pct*100, 1);
         }
         else if (!IsEmptyValue(profitMarkerPercent)) {
            positions.dData[size][I_PROFIT_MARKER_PRICE  ] = NormalizeDouble(openPrice/totalPosition - (fullProfit-floatingProfit-profitMarkerPercent/100*equity100Pct)/pipValue*Pip, Digits);
            positions.dData[size][I_PROFIT_MARKER_PERCENT] = profitMarkerPercent;
         }

         if (lossMarkerPrice != NULL) {
            positions.dData[size][I_LOSS_MARKER_PRICE  ] = lossMarkerPrice;
            positions.dData[size][I_LOSS_MARKER_PERCENT] = NormalizeDouble((fullProfit - floatingProfit + (lossMarkerPrice-openPrice/totalPosition)/Pip*pipValue)/equity100Pct*100, 1);
         }
         else if (!IsEmptyValue(lossMarkerPercent)) {
            positions.dData[size][I_LOSS_MARKER_PRICE  ] = NormalizeDouble(openPrice/totalPosition - (fullProfit-floatingProfit-lossMarkerPercent/100*equity100Pct)/pipValue*Pip, Digits);
            positions.dData[size][I_LOSS_MARKER_PERCENT] = lossMarkerPercent;
         }
      }
      return(!catch("StorePosition(5)"));
   }

   // eventuelle Shortposition ermitteln
   if (totalPosition < 0) {
      remainingShort = -totalPosition;
      openPrice      = 0;
      swap           = 0;
      commission     = 0;
      floatingProfit = 0;

      for (i=0; i < ticketsSize; i++) {
         if (!tickets[i]    ) continue;
         if (!remainingShort) continue;

         if (types[i] == OP_SELL) {
            if (remainingShort >= lots[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice      += lots[i] * openPrices[i];
               swap           += swaps[i];
               commission     += commissions[i];
               floatingProfit += profits[i];
               tickets[i]      = NULL;
               remainingShort  = NormalizeDouble(remainingShort - lots[i], 3);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor          = remainingShort/lots[i];
               openPrice      += lots[i] * openPrices[i];
               swap           +=          swaps[i];       swaps      [i]  = 0;
               commission     += factor * commissions[i]; commissions[i] -= factor * commissions[i];
               floatingProfit += factor * profits[i];     profits    [i] -= factor * profits    [i];
                                                          lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 3);
               remainingShort = 0;
            }
         }
      }
      if (remainingShort != 0) return(!catch("StorePosition(6)  illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of short position = "+ NumberToStr(-totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      size = ArrayRange(positions.iData, 0);
      ArrayResize(positions.iData, size+1);
      ArrayResize(positions.dData, size+1);

      positions.iData[size][I_CONFIG_TYPE          ] = ifInt(isVirtual, CONFIG_VIRTUAL, CONFIG_REAL);
      positions.iData[size][I_POSITION_TYPE        ] = POSITION_SHORT;
      positions.iData[size][I_COMMENT_INDEX        ] = commentIndex;

      positions.dData[size][I_DIRECTIONAL_LOTS     ] = -totalPosition;
      positions.dData[size][I_HEDGED_LOTS          ] = hedgedLots;
      positions.dData[size][I_BREAKEVEN_PRICE      ] = NULL;
      positions.dData[size][I_PROFIT_MARKER_PRICE  ] = NULL;
      positions.dData[size][I_PROFIT_MARKER_PERCENT] = NULL;
      positions.dData[size][I_LOSS_MARKER_PRICE    ] = NULL;
      positions.dData[size][I_LOSS_MARKER_PERCENT  ] = NULL;

      positions.dData[size][I_OPEN_EQUITY          ] = equity;         openProfit   = hedgedProfit + commission + swap + floatingProfit;
      positions.dData[size][I_OPEN_PROFIT          ] = openProfit;
      positions.dData[size][I_CLOSED_PROFIT        ] = closedProfit;
      positions.dData[size][I_ADJUSTED_PROFIT      ] = adjustedProfit; fullProfit   = openProfit + closedProfit + adjustedProfit;
      positions.dData[size][I_FULL_PROFIT_ABS      ] = fullProfit;     equity100Pct = equity - ifDouble(!customEquity && equity > fullProfit, fullProfit, 0);
      positions.dData[size][I_FULL_PROFIT_PCT      ] = MathDiv(fullProfit, equity100Pct) * 100;

      pipValue = PipValue(-totalPosition, true);                        // suppress a possible ERR_SYMBOL_NOT_AVAILABLE
      if (pipValue != 0) {
         positions.dData[size][I_BREAKEVEN_PRICE] = NormalizeDouble((fullProfit-floatingProfit)/pipValue*Pip - openPrice/totalPosition, Digits);

         if (profitMarkerPrice != NULL) {
            positions.dData[size][I_PROFIT_MARKER_PRICE  ] = profitMarkerPrice;
            positions.dData[size][I_PROFIT_MARKER_PERCENT] = NormalizeDouble((fullProfit - floatingProfit - (profitMarkerPrice + openPrice/totalPosition)/Pip*pipValue)/equity100Pct*100, 1);
         }
         else if (!IsEmptyValue(profitMarkerPercent)) {
            positions.dData[size][I_PROFIT_MARKER_PRICE  ] = NormalizeDouble((fullProfit-floatingProfit-profitMarkerPercent/100*equity100Pct)/pipValue*Pip - openPrice/totalPosition, Digits);
            positions.dData[size][I_PROFIT_MARKER_PERCENT] = profitMarkerPercent;
         }

         if (lossMarkerPrice != NULL) {
            positions.dData[size][I_LOSS_MARKER_PRICE  ] = lossMarkerPrice;
            positions.dData[size][I_LOSS_MARKER_PERCENT] = NormalizeDouble((fullProfit - floatingProfit - (lossMarkerPrice + openPrice/totalPosition)/Pip*pipValue)/equity100Pct*100, 1);
         }
         else if (!IsEmptyValue(lossMarkerPercent)) {
            positions.dData[size][I_LOSS_MARKER_PRICE  ] = NormalizeDouble((fullProfit-floatingProfit-lossMarkerPercent/100*equity100Pct)/pipValue*Pip - openPrice/totalPosition, Digits);
            positions.dData[size][I_LOSS_MARKER_PERCENT] = lossMarkerPercent;
         }
      }
      return(!catch("StorePosition(7)"));
   }

   // ohne offene Positionen muß ClosedProfit (kann 0.00 sein) oder AdjustedProfit gesetzt sein
   // History mit leerer Position speichern
   size = ArrayRange(positions.iData, 0);
   ArrayResize(positions.iData, size+1);
   ArrayResize(positions.dData, size+1);

   positions.iData[size][I_CONFIG_TYPE          ] = ifInt(isVirtual, CONFIG_VIRTUAL, CONFIG_REAL);
   positions.iData[size][I_POSITION_TYPE        ] = POSITION_HISTORY;
   positions.iData[size][I_COMMENT_INDEX        ] = commentIndex;

   positions.dData[size][I_DIRECTIONAL_LOTS     ] = NULL;
   positions.dData[size][I_HEDGED_LOTS          ] = NULL;
   positions.dData[size][I_BREAKEVEN_PRICE      ] = NULL;
   positions.dData[size][I_PROFIT_MARKER_PRICE  ] = NULL;
   positions.dData[size][I_PROFIT_MARKER_PERCENT] = NULL;
   positions.dData[size][I_LOSS_MARKER_PRICE    ] = NULL;
   positions.dData[size][I_LOSS_MARKER_PERCENT  ] = NULL;

   positions.dData[size][I_OPEN_EQUITY          ] = equity;         openProfit   = 0;
   positions.dData[size][I_OPEN_PROFIT          ] = openProfit;
   positions.dData[size][I_CLOSED_PROFIT        ] = closedProfit;
   positions.dData[size][I_ADJUSTED_PROFIT      ] = adjustedProfit; fullProfit   = openProfit + closedProfit + adjustedProfit;
   positions.dData[size][I_FULL_PROFIT_ABS      ] = fullProfit;     equity100Pct = equity - ifDouble(!customEquity && equity > fullProfit, fullProfit, 0);
   positions.dData[size][I_FULL_PROFIT_PCT      ] = MathDiv(fullProfit, equity100Pct) * 100;

   debug("StorePosition(0.2)  history:  absProfit="+ NumberToStr(fullProfit, ".3") +"  equity="+ NumberToStr(equity, ".3") +"  100%="+ NumberToStr(equity100Pct, ".3") +"  %Profit="+ NumberToStr(positions.dData[size][I_FULL_PROFIT_PCT], ".3"));
   return(!catch("StorePosition(8)"));
}


/**
 * Sortiert die übergebenen Ticketdaten nach {CloseTime, OpenTime, Ticket}.
 *
 * @param  _InOut_ int tickets[]
 *
 * @return bool - success status
 */
bool SortClosedTickets(int &tickets[][/*{CloseTime, OpenTime, Ticket}*/]) {
   if (ArrayRange(tickets, 1) != 3) return(!catch("SortClosedTickets(1)  invalid parameter tickets["+ ArrayRange(tickets, 0) +"]["+ ArrayRange(tickets, 1) +"]", ERR_INCOMPATIBLE_ARRAY));

   int rows = ArrayRange(tickets, 0);
   if (rows < 2) return(true);                                       // single row, nothing to do

   // alle Zeilen nach CloseTime sortieren
   ArraySort(tickets);

   // Zeilen mit gleicher CloseTime zusätzlich nach OpenTime sortieren
   int closeTime, openTime, ticket, lastCloseTime, sameCloseTimes[][3];
   ArrayResize(sameCloseTimes, 1);

   for (int n, i=0; i < rows; i++) {
      closeTime = tickets[i][0];
      openTime  = tickets[i][1];
      ticket    = tickets[i][2];

      if (closeTime == lastCloseTime) {
         n++;
         ArrayResize(sameCloseTimes, n+1);
      }
      else if (n > 0) {
         // in sameCloseTimes[] angesammelte Zeilen von tickets[] nach OpenTime sortieren
         __SCT.SameCloseTimes(tickets, sameCloseTimes);
         ArrayResize(sameCloseTimes, 1);
         n = 0;
      }
      sameCloseTimes[n][0] = openTime;
      sameCloseTimes[n][1] = ticket;
      sameCloseTimes[n][2] = i;                                      // Originalposition der Zeile in keys[]

      lastCloseTime = closeTime;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameCloseTimes[] angesammelte Zeilen müssen auch sortiert werden
      __SCT.SameCloseTimes(tickets, sameCloseTimes);
      n = 0;
   }
   ArrayResize(sameCloseTimes, 0);

   // Zeilen mit gleicher Close- und OpenTime zusätzlich nach Ticket sortieren
   int lastOpenTime, sameOpenTimes[][2];
   ArrayResize(sameOpenTimes, 1);
   lastCloseTime = 0;

   for (i=0; i < rows; i++) {
      closeTime = tickets[i][0];
      openTime  = tickets[i][1];
      ticket    = tickets[i][2];

      if (closeTime==lastCloseTime && openTime==lastOpenTime) {
         n++;
         ArrayResize(sameOpenTimes, n+1);
      }
      else if (n > 0) {
         // in sameOpenTimes[] angesammelte Zeilen von tickets[] nach Ticket sortieren
         __SCT.SameOpenTimes(tickets, sameOpenTimes);
         ArrayResize(sameOpenTimes, 1);
         n = 0;
      }
      sameOpenTimes[n][0] = ticket;
      sameOpenTimes[n][1] = i;                                       // Originalposition der Zeile in tickets[]

      lastCloseTime = closeTime;
      lastOpenTime  = openTime;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameOpenTimes[] angesammelte Zeilen müssen auch sortiert werden
      __SCT.SameOpenTimes(tickets, sameOpenTimes);
   }
   ArrayResize(sameOpenTimes, 0);

   return(!catch("SortClosedTickets(2)"));
}


/**
 * Internal helper for SortClosedTickets().
 *
 * Sortiert die in rowsToSort[] angegebenen Zeilen des Datenarrays ticketData[] nach {OpenTime, Ticket}. Die CloseTime-Felder dieser Zeilen
 * sind gleich und müssen nicht umsortiert werden.
 *
 * @param  _InOut_ int ticketData[] - zu sortierendes Datenarray
 * @param  _In_    int rowsToSort[] - Array mit aufsteigenden Indizes der umzusortierenden Zeilen des Datenarrays
 *
 * @return bool - success status
 *
 * @access private
 */
bool __SCT.SameCloseTimes(int &ticketData[][/*{CloseTime, OpenTime, Ticket}*/], int rowsToSort[][/*{OpenTime, Ticket, i}*/]) {
   int rows.copy[][3]; ArrayResize(rows.copy, 0);
   ArrayCopy(rows.copy, rowsToSort);                                 // auf Kopie von rowsToSort[] arbeiten, um das übergebene Array nicht zu modifizieren

   // Zeilen nach OpenTime sortieren
   ArraySort(rows.copy);

   // Original-Daten mit den sortierten Werten überschreiben
   int openTime, ticket, rows=ArrayRange(rowsToSort, 0);

   for (int i, n=0; n < rows; n++) {                                 // Originaldaten mit den sortierten Werten überschreiben
      i                = rowsToSort[n][2];
      ticketData[i][1] = rows.copy [n][0];
      ticketData[i][2] = rows.copy [n][1];
   }

   ArrayResize(rows.copy, 0);
   return(!catch("__SCT.SameCloseTimes(1)"));
}


/**
 * Internal helper for SortClosedTickets().
 *
 * Sortiert die in rowsToSort[] angegebene Zeilen des Datenarrays ticketData[] nach {Ticket}. Die Open- und CloseTime-Felder dieser Zeilen
 * sind gleich und müssen nicht umsortiert werden.
 *
 * @param  _InOut_ int ticketData[] - zu sortierendes Datenarray
 * @param  _In_    int rowsToSort[] - Array mit aufsteigenden Indizes der umzusortierenden Zeilen des Datenarrays
 *
 * @return bool - success status
 *
 * @access private
 */
bool __SCT.SameOpenTimes(int &ticketData[][/*{OpenTime, CloseTime, Ticket}*/], int rowsToSort[][/*{Ticket, i}*/]) {
   int rows.copy[][2]; ArrayResize(rows.copy, 0);
   ArrayCopy(rows.copy, rowsToSort);                                 // auf Kopie von rowsToSort[] arbeiten, um das übergebene Array nicht zu modifizieren

   // Zeilen nach Ticket sortieren
   ArraySort(rows.copy);

   int ticket, rows=ArrayRange(rowsToSort, 0);

   for (int i, n=0; n < rows; n++) {                                 // Originaldaten mit den sortierten Werten überschreiben
      i                = rowsToSort[n][1];
      ticketData[i][2] = rows.copy [n][0];
   }

   ArrayResize(rows.copy, 0);
   return(!catch("__SCT.SameOpenTimes(1)"));
}


/**
 * Handler für beim LFX-Terminal eingehende Messages.
 *
 * @return bool - success status
 */
bool QC.HandleLfxTerminalMessages() {
   if (!__isChart) return(true);

   // (1) ggf. Receiver starten
   if (!hQC.TradeToLfxReceiver) /*&&*/ if (!QC.StartLfxReceiver())
      return(false);

   // (2) Channel auf neue Messages prüfen
   int checkResult = QC_CheckChannel(qc.TradeToLfxChannel);
   if (checkResult == QC_CHECK_CHANNEL_EMPTY)
      return(true);
   if (checkResult < QC_CHECK_CHANNEL_EMPTY) {
      if (checkResult == QC_CHECK_CHANNEL_ERROR)  return(!catch("QC.HandleLfxTerminalMessages(1)->MT4iQuickChannel::QC_CheckChannel(name="+ DoubleQuoteStr(qc.TradeToLfxChannel) +") => QC_CHECK_CHANNEL_ERROR",                ERR_WIN32_ERROR));
      if (checkResult == QC_CHECK_CHANNEL_NONE )  return(!catch("QC.HandleLfxTerminalMessages(2)->MT4iQuickChannel::QC_CheckChannel(name="+ DoubleQuoteStr(qc.TradeToLfxChannel) +")  channel doesn't exist",                   ERR_WIN32_ERROR));
                                                  return(!catch("QC.HandleLfxTerminalMessages(3)->MT4iQuickChannel::QC_CheckChannel(name="+ DoubleQuoteStr(qc.TradeToLfxChannel) +")  unexpected return value = "+ checkResult, ERR_WIN32_ERROR));
   }

   // (3) neue Messages abholen
   string messageBuffer[]; if (!ArraySize(messageBuffer)) InitializeStringBuffer(messageBuffer, QC_MAX_BUFFER_SIZE);
   int getResult = QC_GetMessages3(hQC.TradeToLfxReceiver, messageBuffer, QC_MAX_BUFFER_SIZE);
   if (getResult != QC_GET_MSG3_SUCCESS) {
      if (getResult == QC_GET_MSG3_CHANNEL_EMPTY) return(!catch("QC.HandleLfxTerminalMessages(4)->MT4iQuickChannel::QC_GetMessages3()  QuickChannel mis-match: QC_CheckChannel="+ checkResult +"chars/QC_GetMessages3=CHANNEL_EMPTY", ERR_WIN32_ERROR));
      if (getResult == QC_GET_MSG3_INSUF_BUFFER ) return(!catch("QC.HandleLfxTerminalMessages(5)->MT4iQuickChannel::QC_GetMessages3()  QuickChannel mis-match: QC_CheckChannel="+ checkResult +"chars/QC_MAX_BUFFER_SIZE="+ QC_MAX_BUFFER_SIZE +"/size(buffer)="+ (StringLen(messageBuffer[0])+1) +"/QC_GetMessages3=INSUF_BUFFER", ERR_WIN32_ERROR));
                                                  return(!catch("QC.HandleLfxTerminalMessages(6)->MT4iQuickChannel::QC_GetMessages3()  unexpected return value = "+ getResult, ERR_WIN32_ERROR));
   }

   // (4) Messages verarbeiten: Da hier sehr viele Messages in kurzer Zeit eingehen können, werden sie zur Beschleunigung statt mit Explode() manuell zerlegt.
   string msgs = messageBuffer[0];
   int from=0, to=StringFind(msgs, TAB, from);
   while (to != -1) {                                                            // mind. ein TAB gefunden
      if (to != from)
         if (!ProcessLfxTerminalMessage(StringSubstr(msgs, from, to-from)))
            return(false);
      from = to+1;
      to = StringFind(msgs, TAB, from);
   }
   if (from < StringLen(msgs))
      if (!ProcessLfxTerminalMessage(StringSubstr(msgs, from)))
         return(false);

   return(true);
}


/**
 * Verarbeitet beim LFX-Terminal eingehende Messages.
 *
 * @param  string message - QuickChannel-Message, siehe Formatbeschreibung
 *
 * @return bool - success status: Ob die Message erfolgreich verarbeitet wurde. Ein falsches Messageformat oder keine zur Message passende
 *                               Order sind kein Fehler, das Auslösen eines Fehlers durch Schicken einer falschen Message ist so nicht
 *                               möglich. Für nicht unterstützte Messages wird stattdessen eine Warnung ausgegeben.
 *
 * Messageformat: "LFX:{iTicket]:pending={1|0}"   - die angegebene Pending-Order wurde platziert (immer erfolgreich, da im Fehlerfall keine Message generiert wird)
 *                "LFX:{iTicket]:open={1|0}"      - die angegebene Pending-Order wurde ausgeführt/konnte nicht ausgeführt werden
 *                "LFX:{iTicket]:close={1|0}"     - die angegebene Position wurde geschlossen/konnte nicht geschlossen werden
 *                "LFX:{iTicket]:profit={dValue}" - der PL der angegebenen Position hat sich geändert
 */
bool ProcessLfxTerminalMessage(string message) {
   //debug("ProcessLfxTerminalMessage(1)  tick="+ Ticks +"  msg=\""+ message +"\"");

   // Da hier in kurzer Zeit sehr viele Messages eingehen können, werden sie zur Beschleunigung statt mit Explode() manuell zerlegt.
   // LFX-Prefix
   if (StringSubstr(message, 0, 4) != "LFX:")                                        return(!logWarn("ProcessLfxTerminalMessage(2)  unknown message format \""+ message +"\""));
   // LFX-Ticket
   int from=4, to=StringFind(message, ":", from);                   if (to <= from)  return(!logWarn("ProcessLfxTerminalMessage(3)  unknown message \""+ message +"\" (illegal order ticket)"));
   int ticket = StrToInteger(StringSubstr(message, from, to-from)); if (ticket <= 0) return(!logWarn("ProcessLfxTerminalMessage(4)  unknown message \""+ message +"\" (illegal order ticket)"));
   // LFX-Parameter
   double profit;
   bool   success;
   from = to+1;

   // :profit={dValue}
   if (StringSubstr(message, from, 7) == "profit=") {                         // die häufigste Message wird zuerst geprüft
      int size = ArrayRange(lfxOrders, 0);
      for (int i=0; i < size; i++) {
         if (lfxOrders.iCache[i][IC.ticket] == ticket) {                      // geladene LFX-Orders durchsuchen und PL aktualisieren
            if (lfxOrders.bCache[i][BC.isOpenPosition]) {
               lfxOrders.dCache[i][DC.lastProfit] = lfxOrders.dCache[i][DC.profit];
               lfxOrders.dCache[i][DC.profit    ] = NormalizeDouble(StrToDouble(StringSubstr(message, from+7)), 2);
            }
            break;
         }
      }
      return(true);
   }

   // :pending={1|0}
   if (StringSubstr(message, from, 8) == "pending=") {
      success = (StrToInteger(StringSubstr(message, from+8)) != 0);
      if (success) { if (IsLogDebug()) logDebug("ProcessLfxTerminalMessage(5)  #"+ ticket +" pending order "+ ifString(success, "notification", "error"                           )); }
      else         {                    logWarn("ProcessLfxTerminalMessage(6)  #"+ ticket +" pending order "+ ifString(success, "notification", "error (what use case is this???)")); }
      return(RestoreLfxOrders(false));                                        // LFX-Orders neu einlesen (auch bei Fehler)
   }

   // :open={1|0}
   if (StringSubstr(message, from, 5) == "open=") {
      success = (StrToInteger(StringSubstr(message, from+5)) != 0);
      if (IsLogDebug()) logDebug("ProcessLfxTerminalMessage(7)  #"+ ticket +" open position "+ ifString(success, "notification", "error"));
      return(RestoreLfxOrders(false));                                        // LFX-Orders neu einlesen (auch bei Fehler)
   }

   // :close={1|0}
   if (StringSubstr(message, from, 6) == "close=") {
      success = (StrToInteger(StringSubstr(message, from+6)) != 0);
      if (IsLogDebug()) logDebug("ProcessLfxTerminalMessage(8)  #"+ ticket +" close position "+ ifString(success, "notification", "error"));
      return(RestoreLfxOrders(false));                                        // LFX-Orders neu einlesen (auch bei Fehler)
   }

   // ???
   return(!logWarn("ProcessLfxTerminalMessage(9)  unknown message \""+ message +"\""));
}


/**
 * Liest die LFX-Orderdaten neu ein bzw. restauriert sie aus dem Cache.
 *
 * @param  bool fromCache - Ob die Orderdaten aus zwischengespeicherten Daten restauriert oder komplett neu eingelesen werden.
 *
 *                          TRUE:  Restauriert die Orderdaten aus in der Library zwischengespeicherten Daten.
 *
 *                          FALSE: Liest die LFX-Orderdaten im aktuellen Kontext neu ein. Für offene Positionen wird im Dateisystem kein PL
 *                                 gespeichert (ändert sich ständig). Stattdessen wird dieser PL in globalen Terminal-Variablen zwischen-
 *                                 gespeichert (schneller) und von dort restauriert.
 * @return bool - success status
 */
bool RestoreLfxOrders(bool fromCache) {
   fromCache = fromCache!=0;

   if (fromCache) {
      // (1) LFX-Orders aus in der Library zwischengespeicherten Daten restaurieren
      int size = ChartInfos.CopyLfxOrders(false, lfxOrders, lfxOrders.iCache, lfxOrders.bCache, lfxOrders.dCache);
      if (size == -1) return(!SetLastError(ERR_RUNTIME_ERROR));

      // Order-Zähler aktualisieren
      lfxOrders.pendingOrders    = 0;                                               // Diese Zähler dienen der Beschleunigung, um nicht ständig über alle Orders
      lfxOrders.openPositions    = 0;                                               // iterieren zu müssen.
      lfxOrders.pendingPositions = 0;

      for (int i=0; i < size; i++) {
         lfxOrders.pendingOrders    += lfxOrders.bCache[i][BC.isPendingOrder   ];
         lfxOrders.openPositions    += lfxOrders.bCache[i][BC.isOpenPosition   ];
         lfxOrders.pendingPositions += lfxOrders.bCache[i][BC.isPendingPosition];
      }
      return(true);
   }

   // (2) Orderdaten neu einlesen: Sind wir nicht in einem init()-Cycle, werden im Cache noch vorhandene Daten vorm Überschreiben gespeichert.
   if (ArrayRange(lfxOrders.iCache, 0) > 0) {
      if (!SaveLfxOrderCache()) return(false);
   }
   ArrayResize(lfxOrders.iCache, 0);
   ArrayResize(lfxOrders.bCache, 0);
   ArrayResize(lfxOrders.dCache, 0);
   lfxOrders.pendingOrders    = 0;
   lfxOrders.openPositions    = 0;
   lfxOrders.pendingPositions = 0;

   // solange in mode.extern noch lfxCurrency und lfxCurrencyId benutzt werden, bei Nicht-LFX-Instrumenten hier abbrechen
   if (mode.extern) /*&&*/ if (!StrEndsWith(Symbol(), "LFX"))
      return(true);

   // LFX-Orders einlesen
   string currency = "";
   int    flags    = NULL;
   if      (mode.intern) {                         flags = OF_OPENPOSITION;     }   // offene Positionen aller LFX-Währungen (zum Managen von Profitbetrags-Exit-Limiten)
   else if (mode.extern) { currency = lfxCurrency; flags = OF_OPEN | OF_CLOSED; }   // alle Orders der aktuellen LFX-Währung (zur Anzeige)

   size = LFX.GetOrders(currency, flags, lfxOrders); if (size==-1) return(false);

   ArrayResize(lfxOrders.iCache, size);
   ArrayResize(lfxOrders.bCache, size);
   ArrayResize(lfxOrders.dCache, size);

   // Zähler-Variablen und PL-Daten aktualisieren
   for (i=0; i < size; i++) {
      lfxOrders.iCache[i][IC.ticket           ] = los.Ticket           (lfxOrders, i);
      lfxOrders.bCache[i][BC.isPendingOrder   ] = los.IsPendingOrder   (lfxOrders, i);
      lfxOrders.bCache[i][BC.isOpenPosition   ] = los.IsOpenPosition   (lfxOrders, i);
      lfxOrders.bCache[i][BC.isPendingPosition] = los.IsPendingPosition(lfxOrders, i);

      lfxOrders.pendingOrders    += lfxOrders.bCache[i][BC.isPendingOrder   ];
      lfxOrders.openPositions    += lfxOrders.bCache[i][BC.isOpenPosition   ];
      lfxOrders.pendingPositions += lfxOrders.bCache[i][BC.isPendingPosition];

      if (los.IsOpenPosition(lfxOrders, i)) {                        // TODO: !!! Der Account muß Teil des Schlüssels sein.
         string varName = StringConcatenate("LFX.#", lfxOrders.iCache[i][IC.ticket], ".profit");
         double value   = GlobalVariableGet(varName);
         if (!value) {                                               // 0 oder Fehler
            int error = GetLastError();
            if (error!=NO_ERROR) /*&&*/ if (error!=ERR_GLOBAL_VARIABLE_NOT_FOUND)
               return(!catch("RestoreLfxOrders(1)->GlobalVariableGet(name=\""+ varName +"\")", error));
         }
         lfxOrders.dCache[i][DC.profit] = value;
      }
      else {
         lfxOrders.dCache[i][DC.profit] = los.Profit(lfxOrders, i);
      }

      lfxOrders.dCache[i][DC.openEquity       ] = los.OpenEquity       (lfxOrders, i);
      lfxOrders.dCache[i][DC.lastProfit       ] = lfxOrders.dCache[i][DC.profit];      // Wert ist auf jeden Fall bereits verarbeitet worden.
      lfxOrders.dCache[i][DC.takeProfitAmount ] = los.TakeProfitValue  (lfxOrders, i);
      lfxOrders.dCache[i][DC.takeProfitPercent] = los.TakeProfitPercent(lfxOrders, i);
      lfxOrders.dCache[i][DC.stopLossAmount   ] = los.StopLossValue    (lfxOrders, i);
      lfxOrders.dCache[i][DC.stopLossPercent  ] = los.StopLossPercent  (lfxOrders, i);
   }
   return(true);
}


/**
 * Speichert die aktuellen LFX-Order-PLs in globalen Terminal-Variablen. So steht der letzte bekannte PL auch dann zur Verfügung,
 * wenn das Trade-Terminal nicht läuft.
 *
 * @return bool - success status
 */
bool SaveLfxOrderCache() {
   string varName = "";
   int size = ArrayRange(lfxOrders.iCache, 0);

   for (int i=0; i < size; i++) {
      if (lfxOrders.bCache[i][BC.isOpenPosition]) {                  // TODO: !!! Der Account muß Teil des Schlüssels sein.
         varName = StringConcatenate("LFX.#", lfxOrders.iCache[i][IC.ticket], ".profit");

         if (!GlobalVariableSet(varName, lfxOrders.dCache[i][DC.profit])) {
            int error = GetLastError();
            return(!catch("SaveLfxOrderCache(1)->GlobalVariableSet(name=\""+ varName +"\", value="+ DoubleToStr(lfxOrders.dCache[i][DC.profit], 2) +")", ifInt(!error, ERR_RUNTIME_ERROR, error)));
         }
      }
   }
   return(true);
}


/**
 * Handler für beim Terminal eingehende Trade-Commands.
 *
 * @return bool - success status
 */
bool QC.HandleTradeCommands() {
   if (!__isChart) return(true);

   // (1) ggf. Receiver starten
   if (!hQC.TradeCmdReceiver) /*&&*/ if (!QC.StartTradeCmdReceiver())
      return(false);

   // (2) Channel auf neue Messages prüfen
   int checkResult = QC_CheckChannel(qc.TradeCmdChannel);
   if (checkResult == QC_CHECK_CHANNEL_EMPTY)
      return(true);
   if (checkResult < QC_CHECK_CHANNEL_EMPTY) {
      if (checkResult == QC_CHECK_CHANNEL_ERROR)  return(!catch("QC.HandleTradeCommands(1)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeCmdChannel +"\") => QC_CHECK_CHANNEL_ERROR",                ERR_WIN32_ERROR));
      if (checkResult == QC_CHECK_CHANNEL_NONE )  return(!catch("QC.HandleTradeCommands(2)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeCmdChannel +"\")  channel doesn't exist",                   ERR_WIN32_ERROR));
                                                  return(!catch("QC.HandleTradeCommands(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeCmdChannel +"\")  unexpected return value = "+ checkResult, ERR_WIN32_ERROR));
   }

   // (3) neue Messages abholen
   string messageBuffer[]; if (!ArraySize(messageBuffer)) InitializeStringBuffer(messageBuffer, QC_MAX_BUFFER_SIZE);
   int getResult = QC_GetMessages3(hQC.TradeCmdReceiver, messageBuffer, QC_MAX_BUFFER_SIZE);
   if (getResult != QC_GET_MSG3_SUCCESS) {
      if (getResult == QC_GET_MSG3_CHANNEL_EMPTY) return(!catch("QC.HandleTradeCommands(4)->MT4iQuickChannel::QC_GetMessages3()  QuickChannel mis-match: QC_CheckChannel="+ checkResult +"chars/QC_GetMessages3=CHANNEL_EMPTY", ERR_WIN32_ERROR));
      if (getResult == QC_GET_MSG3_INSUF_BUFFER ) return(!catch("QC.HandleTradeCommands(5)->MT4iQuickChannel::QC_GetMessages3()  QuickChannel mis-match: QC_CheckChannel="+ checkResult +"chars/QC_MAX_BUFFER_SIZE="+ QC_MAX_BUFFER_SIZE +"/size(buffer)="+ (StringLen(messageBuffer[0])+1) +"/QC_GetMessages3=INSUF_BUFFER", ERR_WIN32_ERROR));
                                                  return(!catch("QC.HandleTradeCommands(6)->MT4iQuickChannel::QC_GetMessages3()  unexpected return value = "+ getResult, ERR_WIN32_ERROR));
   }

   // (4) Messages verarbeiten
   string msgs[];
   int msgsSize = Explode(messageBuffer[0], TAB, msgs, NULL);

   for (int i=0; i < msgsSize; i++) {
      if (!StringLen(msgs[i])) continue;
      msgs[i] = StrReplace(msgs[i], HTML_TAB, TAB);
      logDebug("QC.HandleTradeCommands(7)  received \""+ msgs[i] +"\"");

      string cmdType = StrTrim(StrLeftTo(msgs[i], "{"));

      if      (cmdType == "LfxOrderCreateCommand" ) { if (!RunScript("LFX.ExecuteTradeCmd", msgs[i])) return(false); }
      else if (cmdType == "LfxOrderOpenCommand"   ) { if (!RunScript("LFX.ExecuteTradeCmd", msgs[i])) return(false); }
      else if (cmdType == "LfxOrderCloseCommand"  ) { if (!RunScript("LFX.ExecuteTradeCmd", msgs[i])) return(false); }
      else if (cmdType == "LfxOrderCloseByCommand") { if (!RunScript("LFX.ExecuteTradeCmd", msgs[i])) return(false); }
      else if (cmdType == "LfxOrderHedgeCommand"  ) { if (!RunScript("LFX.ExecuteTradeCmd", msgs[i])) return(false); }
      else if (cmdType == "LfxOrderModifyCommand" ) { if (!RunScript("LFX.ExecuteTradeCmd", msgs[i])) return(false); }
      else if (cmdType == "LfxOrderDeleteCommand" ) { if (!RunScript("LFX.ExecuteTradeCmd", msgs[i])) return(false); }
      else {
         return(!catch("QC.HandleTradeCommands(8)  unsupported trade command = "+ DoubleQuoteStr(cmdType), ERR_RUNTIME_ERROR));
      }
  }
   return(true);
}


/**
 * Schickt den Profit der LFX-Positionen ans LFX-Terminal. Prüft absolute und prozentuale Limite, wenn sich der Wert seit dem letzten
 * Aufruf geändert hat, und triggert entsprechende Trade-Command.
 *
 * @return bool - success status
 */
bool AnalyzePos.ProcessLfxProfits() {
   string messages[]; ArrayResize(messages, 0); ArrayResize(messages, ArraySize(hQC.TradeToLfxSenders));    // 2 x ArrayResize() = ArrayInitialize()

   int size = ArrayRange(lfxOrders, 0);

   // Ursprünglich enthält lfxOrders[] nur OpenPositions, bei Ausbleiben einer Ausführungsbenachrichtigung können daraus geschlossene Positionen werden.
   for (int i=0; i < size; i++) {
      if (!EQ(lfxOrders.dCache[i][DC.profit], lfxOrders.dCache[i][DC.lastProfit], 2)) {
         // Profit hat sich geändert: Betrag zu Messages des entsprechenden Channels hinzufügen
         double profit = lfxOrders.dCache[i][DC.profit];
         int    cid    = LFX.CurrencyId(lfxOrders.iCache[i][IC.ticket]);
         if (!StringLen(messages[cid])) messages[cid] = StringConcatenate(                    "LFX:", lfxOrders.iCache[i][IC.ticket], ":profit=", DoubleToStr(profit, 2));
         else                           messages[cid] = StringConcatenate(messages[cid], TAB, "LFX:", lfxOrders.iCache[i][IC.ticket], ":profit=", DoubleToStr(profit, 2));

         if (!lfxOrders.bCache[i][BC.isPendingPosition])
            continue;

         // Profitbetrag-Limite prüfen (Preis-Limite werden vom LFX-Monitor geprüft)
         int limitResult = LFX.CheckLimits(lfxOrders, i, NULL, NULL, profit); if (!limitResult) return(false);
         if (limitResult == NO_LIMIT_TRIGGERED)
            continue;

         // Position schließen
         if (!LFX.SendTradeCommand(lfxOrders, i, limitResult)) return(false);

         // Ohne Ausführungsbenachrichtigung wurde die Order nach TimeOut neu eingelesen und die PendingPosition ggf. zu einer ClosedPosition.
         if (los.IsClosed(lfxOrders, i)) {
            lfxOrders.bCache[i][BC.isOpenPosition   ] = false;
            lfxOrders.bCache[i][BC.isPendingPosition] = false;
            lfxOrders.openPositions--;
            lfxOrders.pendingPositions--;
         }
      }
   }

   // angesammelte Messages verschicken: Messages je Channel werden gemeinsam und nicht einzeln verschickt, um beim Empfänger unnötige Ticks zu vermeiden.
   size = ArraySize(messages);
   for (i=1; i < size; i++) {                                        // Index 0 ist unbenutzt, denn 0 ist keine gültige CurrencyId
      if (StringLen(messages[i]) > 0) {
         if (!hQC.TradeToLfxSenders[i]) /*&&*/ if (!QC.StartLfxSender(i))
            return(false);
         if (!QC_SendMessage(hQC.TradeToLfxSenders[i], messages[i], QC_FLAG_SEND_MSG_IF_RECEIVER))
            return(!catch("AnalyzePos.ProcessLfxProfits(1)->MT4iQuickChannel::QC_SendMessage() = QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));
      }
   }
   return(!catch("AnalyzePos.ProcessLfxProfits(2)"));
}


/**
 * Store runtime status in chart (for terminal restart) and chart window (for loading of templates).
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (!__isChart) return(true);

   // stored vars:
   // bool positions.absoluteProfits
   string key = ProgramName() +".status.positions.absoluteProfits";    // TODO: Schlüssel global verwalten und Instanz-ID des Indikators integrieren
   int value = ifInt(positions.absoluteProfits, 1, -1);

   // chart window
   SetWindowIntegerA(__ExecutionContext[EC.hChart], key, value);

   // chart
   if (ObjectFind(key) == -1)
      ObjectCreate(key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, ""+ value);

   return(!catch("StoreStatus(1)"));
}


/**
 * Restore a runtime status stored in the chart or the chart window.
 *
 * @return bool - success status
 */
bool RestoreStatus() {
   if (!__isChart) return(true);

   // restored vars:
   // bool positions.absoluteProfits
   string key = ProgramName() +".status.positions.absoluteProfits";    // TODO: Schlüssel global verwalten und Instanz-ID des Indikators integrieren
   bool result = false;

   // prefer chart window
   int value = GetWindowIntegerA(__ExecutionContext[EC.hChart], key);
   result = (value != 0);

   // then check chart
   if (!result) {
      if (ObjectFind(key) == 0) {
         value = StrToInteger(ObjectDescription(key));
         result = (value != 0);
      }
   }
   if (result) positions.absoluteProfits = (value > 0);

   return(!catch("RestoreStatus(1)"));
}


// data array indexes for PositionOpen/PositionClose events
#define TICKET       0
#define ENTRYLIMIT   1
#define CLOSETYPE    1


/**
 * Monitor execution of pending order limits and opening/closing of positions. Orders with a magic number (managed by an EA)
 * are not monitored as this is the responsibility of the EA.
 *
 * @param  _Out_ double &openedPositions[][] - executed entry limits: {ticket, entryLimit}
 * @param  _Out_ int    &closedPositions[][] - executed exit limits:  {ticket, closeType}
 * @param  _Out_ int    &failedOrders   []   - failed executions:     {ticket}
 *
 * @return bool - success status
 */
bool MonitorOpenOrders(double &openedPositions[][], int &closedPositions[][], int &failedOrders[]) {
   if (__isAccountChange) return(true);                                          // skip to prevent synchronization errors

   /*
   monitoring of entry limits (pendings must be known before)
   ----------------------------------------------------------
   - alle bekannten Pending-Orders auf Statusänderung prüfen:                    über bekannte Orders iterieren
   - alle unbekannten Pending-Orders registrieren:                               über alle Tickets(MODE_TRADES) iterieren

   monitoring of exit limits (positions must be known before)
   ----------------------------------------------------------
   - alle bekannten Pending-Orders und Positionen auf OrderClose prüfen:         über bekannte Orders iterieren
   - alle unbekannten Positionen mit und ohne Exit-Limit registrieren:           über alle Tickets(MODE_TRADES) iterieren
     (limitlose Positionen können durch Stopout geschlossen werden/worden sein)

   both together
   -------------
   - alle bekannten Pending-Orders auf Statusänderung prüfen:                    über bekannte Orders iterieren
   - alle bekannten Pending-Orders und Positionen auf OrderClose prüfen:         über bekannte Orders iterieren
   - alle unbekannten Pending-Orders und Positionen registrieren:                über alle Tickets(MODE_TRADES) iterieren
   */

   // (1) über alle bekannten Orders iterieren (rückwärts, um beim Entfernen von Elementen die Schleife einfacher managen zu können)
   int sizeOfTrackedOrders = ArrayRange(trackedOrders, 0);
   double dData[2];

   for (int i=sizeOfTrackedOrders-1; i >= 0; i--) {
      if (!SelectTicket(trackedOrders[i][TI_TICKET], "MonitorOpenOrders(1)")) return(false);
      int orderType = OrderType();

      if (trackedOrders[i][TI_ORDERTYPE] > OP_SELL) {                      // last time a pending order
         if (orderType == trackedOrders[i][TI_ORDERTYPE]) {                // still pending
            trackedOrders[i][TI_ENTRYLIMIT] = OrderOpenPrice();            // track entry limit changes

            if (OrderCloseTime() != 0) {
               if (OrderComment() != "cancelled") {                        // cancelled: client-side cancellation
                  ArrayPushInt(failedOrders, trackedOrders[i][TI_TICKET]); // otherwise: server-side cancellation, "deleted [no money]" etc.
               }
               ArraySpliceDoubles(trackedOrders, i, 1);                    // remove cancelled order from monitoring
               sizeOfTrackedOrders--;
            }
         }
         else {                                                            // now an open or closed position
            trackedOrders[i][TI_ORDERTYPE] = orderType;
            int size = ArrayRange(openedPositions, 0);
            ArrayResize(openedPositions, size+1);
            openedPositions[size][TICKET    ] = trackedOrders[i][TI_TICKET    ];
            openedPositions[size][ENTRYLIMIT] = trackedOrders[i][TI_ENTRYLIMIT];
            i++;                                                           // reset loop counter and check order again for an immediate close
            continue;
         }
      }
      else {                                                               // (1.2) last time an open position
         if (OrderCloseTime() != 0) {                                      // now closed: check for client-side or server-side close (i.e. exit limit, stopout)
            bool serverSideClose = false;
            int closeType;
            string comment = StrToLower(StrTrim(OrderComment()));

            if      (StrStartsWith(comment, "so:" )) { serverSideClose=true; closeType=CLOSE_STOPOUT;    }
            else if (StrEndsWith  (comment, "[tp]")) { serverSideClose=true; closeType=CLOSE_TAKEPROFIT; }
            else if (StrEndsWith  (comment, "[sl]")) { serverSideClose=true; closeType=CLOSE_STOPLOSS;   }
            else {
               if (!EQ(OrderTakeProfit(), 0)) {                            // some brokers don't update the order comment accordingly
                  if (ifBool(orderType==OP_BUY, OrderClosePrice() >= OrderTakeProfit(), OrderClosePrice() <= OrderTakeProfit())) {
                     serverSideClose = true;
                     closeType       = CLOSE_TAKEPROFIT;
                  }
               }
               if (!EQ(OrderStopLoss(), 0)) {
                  if (ifBool(orderType==OP_BUY, OrderClosePrice() <= OrderStopLoss(), OrderClosePrice() >= OrderStopLoss())) {
                     serverSideClose = true;
                     closeType       = CLOSE_STOPLOSS;
                  }
               }
            }
            if (serverSideClose) {
               size = ArrayRange(closedPositions, 0);
               ArrayResize(closedPositions, size+1);
               closedPositions[size][TICKET   ] = trackedOrders[i][TI_TICKET];
               closedPositions[size][CLOSETYPE] = closeType;
            }
            ArraySpliceDoubles(trackedOrders, i, 1);                       // remove closed position from monitoring
            sizeOfTrackedOrders--;
         }
      }
   }


   // (2) über Tickets(MODE_TRADES) iterieren und alle unbekannten Tickets registrieren (immer Pending-Order oder offene Position)
   while (true) {
      int ordersTotal = OrdersTotal();

      for (i=0; i < ordersTotal; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {                // FALSE: während des Auslesens wurde von dritter Seite eine Order geschlossen oder gelöscht
            ordersTotal = -1;                                              // Abbruch und via while-Schleife alles nochmal verarbeiten, bis for() fehlerfrei durchläuft
            break;
         }
         if (OrderMagicNumber() != 0) continue;                            // skip orders managed by an EA

         for (int n=0; n < sizeOfTrackedOrders; n++) {
            if (trackedOrders[n][TI_TICKET] == OrderTicket()) break;       // Order bereits bekannt
         }
         if (n >= sizeOfTrackedOrders) {                                   // Order unbekannt: in Überwachung aufnehmen
            ArrayResize(trackedOrders, sizeOfTrackedOrders+1);
            trackedOrders[sizeOfTrackedOrders][TI_TICKET    ] = OrderTicket();
            trackedOrders[sizeOfTrackedOrders][TI_ORDERTYPE ] = OrderType();
            trackedOrders[sizeOfTrackedOrders][TI_ENTRYLIMIT] = ifDouble(OrderType() > OP_SELL, OrderOpenPrice(), 0);
            sizeOfTrackedOrders++;
         }
      }
      if (ordersTotal == OrdersTotal()) break;
   }
   return(!catch("MonitorOpenOrders(2)"));
}


/**
 * Handle a PositionOpen event.
 *
 * @param  double data[][] - executed entry limits: {ticket, entryLimit}
 *
 * @return bool - success status
 */
bool onPositionOpen(double data[][]) {
   bool isLogInfo=IsLogInfo(), eventLogged=false;
   int size = ArrayRange(data, 0);
   if (!isLogInfo || !size || __isTesting) return(true);

   OrderPush();
   for (int i=0; i < size; i++) {
      if (!SelectTicket(data[i][TICKET], "onPositionOpen(1)")) return(false);
      if (OrderType() > OP_SELL)                               continue;      // skip pending orders (should not happen)
      if (OrderMagicNumber() != 0)                             continue;      // skip orders managed by an EA (should not happen)

      bool isMySymbol=(OrderSymbol()==Symbol()), isOtherListener=false;
      if (!isMySymbol) isOtherListener = IsOrderEventListener(OrderSymbol());

      if (isMySymbol || !isOtherListener) {
         string event = "PositionOpen::#"+ OrderTicket();

         if (!IsOrderEventLogged(event)) {
            // #1 Sell 0.1 GBPUSD "L.8692.+3" at 1.5524'8[ instead of 1.5522'0 (better|worse: -2.8 pip)]
            string sType       = OperationTypeDescription(OrderType());
            string sLots       = NumberToStr(OrderLots(), ".+");
            string sComment    = ifString(StringLen(OrderComment()), " \""+ OrderComment() +"\"", "");
            int    digits      = MarketInfo(OrderSymbol(), MODE_DIGITS);
            int    pipDigits   = digits & (~1);
            string priceFormat = ",'R."+ pipDigits + ifString(digits==pipDigits, "", "'");
            string sPrice      = NumberToStr(OrderOpenPrice(), priceFormat);
            double slippage    = NormalizeDouble(ifDouble(OrderType()==OP_BUY, data[i][ENTRYLIMIT]-OrderOpenPrice(), OrderOpenPrice()-data[i][ENTRYLIMIT]), digits);
            if (NE(slippage, 0)) {
               sPrice = sPrice +" instead of "+ NumberToStr(data[i][ENTRYLIMIT], priceFormat) +" ("+ ifString(GT(slippage, 0), "better", "worse") +": "+ NumberToStr(slippage/Pip, "+."+ (digits & 1)) +" pip)";
            }
            string message = "#"+ OrderTicket() +" "+ sType +" "+ sLots +" "+ OrderSymbol() + sComment +" at "+ sPrice;
            logInfo("onPositionOpen(2)  "+ message);
            eventLogged = SetOrderEventLogged(event, true);
         }
      }
   }
   OrderPop();

   if (eventLogged && signal.sound)
      return(!PlaySoundEx(signal.sound.positionOpened));
   return(!catch("onPositionOpen(3)"));
}


/**
 * Handle a PositionClose event.
 *
 * @param  int data[][] - executed exit limits: {ticket, closeType}
 *
 * @return bool - success status
 */
bool onPositionClose(int data[][]) {
   bool isLogInfo=IsLogInfo(), eventLogged=false;
   int size = ArrayRange(data, 0);
   if (!isLogInfo || !size || __isTesting) return(true);

   string sCloseTypeDescr[] = {"", " [tp]", " [sl]", " [so]"};
   OrderPush();

   for (int i=0; i < size; i++) {
      if (!SelectTicket(data[i][TICKET], "onPositionClose(1)")) return(false);
      if (OrderType() > OP_SELL)                                continue;     // skip pending orders (should not happen)
      if (!OrderCloseTime())                                    continue;     // skip open positions (should not happen)
      if (OrderMagicNumber() != 0)                              continue;     // skip orders managed by an EA (should not happen)

      bool isMySymbol=(OrderSymbol()==Symbol()), isOtherListener=false;
      if (!isMySymbol) isOtherListener = IsOrderEventListener(OrderSymbol());

      if (isMySymbol || !isOtherListener) {
         string event = "PositionClose::#"+ OrderTicket();

         if (!IsOrderEventLogged(event)) {
            // #1 Buy 0.6 GBPUSD "SR.1234.+2" from 1.5520'0 at 1.5534'4[ instead of 1.5532'2 (better|worse: -2.8 pip)] [tp]
            string sType       = OperationTypeDescription(OrderType());
            string sLots       = NumberToStr(OrderLots(), ".+");
            string sComment    = ifString(StringLen(OrderComment()), " \""+ OrderComment() +"\"", "");
            int    digits      = MarketInfo(OrderSymbol(), MODE_DIGITS);
            int    pipDigits   = digits & (~1);
            string priceFormat = ",'R."+ pipDigits + ifString(digits==pipDigits, "", "'");
            string sOpenPrice  = NumberToStr(OrderOpenPrice(), priceFormat);
            string sClosePrice = NumberToStr(OrderClosePrice(), priceFormat);
            double slippage    = 0;
            if      (data[i][CLOSETYPE] == CLOSE_TAKEPROFIT) slippage = NormalizeDouble(ifDouble(OrderType()==OP_BUY, OrderClosePrice()-OrderTakeProfit(), OrderTakeProfit()-OrderClosePrice()), digits);
            else if (data[i][CLOSETYPE] == CLOSE_STOPLOSS)   slippage = NormalizeDouble(ifDouble(OrderType()==OP_BUY, OrderClosePrice()-OrderStopLoss(),   OrderStopLoss()-OrderClosePrice()),   digits);
            if (NE(slippage, 0)) {
               sClosePrice = sClosePrice +" instead of "+ NumberToStr(ifDouble(data[i][CLOSETYPE]==CLOSE_TAKEPROFIT, OrderTakeProfit(), OrderStopLoss()), priceFormat) +" ("+ ifString(GT(slippage, 0), "better", "worse") +": "+ NumberToStr(slippage/Pip, "+."+ (digits & 1)) +" pip)";
            }
            string sCloseType = sCloseTypeDescr[data[i][CLOSETYPE]];
            if (data[i][CLOSETYPE] == CLOSE_STOPOUT) {
               sComment   = "";
               sCloseType = " ["+ OrderComment() +"]";
            }
            string message = "#"+ OrderTicket() +" "+ sType +" "+ sLots +" "+ OrderSymbol() + sComment +" from "+ sOpenPrice +" at "+ sClosePrice + sCloseType;
            logInfo("onPositionClose(2)  "+ message);
            eventLogged = SetOrderEventLogged(event, true);
         }
      }
   }
   OrderPop();

   if (eventLogged && signal.sound)
      return(!PlaySoundEx(signal.sound.positionClosed));
   return(!catch("onPositionClose(3)"));
}


/**
 * Handle an OrderFail event.
 *
 * @param  int tickets[] - ticket ids of the failed pending orders
 *
 * @return bool - success status
 */
bool onOrderFail(int tickets[]) {
   int size = ArraySize(tickets);
   if (!size || __isTesting) return(true);

   bool eventLogged = false;
   OrderPush();

   for (int i=0; i < size; i++) {
      if (!SelectTicket(tickets[i], "onOrderFail(1)")) return(false);

      bool isMySymbol=(OrderSymbol()==Symbol()), isOtherListener=false;
      if (!isMySymbol) isOtherListener = IsOrderEventListener(OrderSymbol());

      if (isMySymbol || !isOtherListener) {
         string event = "OrderFail::#"+ OrderTicket();

         if (!IsOrderEventLogged(event)) {
            string sType       = OperationTypeDescription(OrderType() & 1);      // BuyLimit => Buy, SellStop => Sell...
            string sLots       = NumberToStr(OrderLots(), ".+");
            int    digits      = MarketInfo(OrderSymbol(), MODE_DIGITS);
            int    pipDigits   = digits & (~1);
            string priceFormat = StringConcatenate(",'R.", pipDigits, ifString(digits==pipDigits, "", "'"));
            string sPrice      = NumberToStr(OrderOpenPrice(), priceFormat);
            string sError      = ifString(StringLen(OrderComment()), " ("+ DoubleQuoteStr(OrderComment()) +")", " (unknown error)");
            string message     = "order failed: #"+ OrderTicket() +" "+ sType +" "+ sLots +" "+ OrderSymbol() +" at "+ sPrice + sError;
            logWarn("onOrderFail(2)  "+ message);
            eventLogged = SetOrderEventLogged(event, true);
         }
      }
   }
   OrderPop();

   if (eventLogged && signal.sound)
      return(!PlaySoundEx(signal.sound.orderFailed));
   return(!catch("onOrderFail(3)"));
}


/**
 * Whether there is a registered order event listener for the specified account and symbol. Supports multiple terminals
 * running in parallel.
 *
 * @param  string symbol
 *
 * @return bool
 */
bool IsOrderEventListener(string symbol) {
   if (!hWndDesktop) return(false);

   string name = orderTracker.key + StrToLower(symbol);
   return(GetPropA(hWndDesktop, name) > 0);
}


/**
 * Whether the specified order event was already logged. Supports multiple terminals running in parallel.
 *
 * @param  string event - event identifier
 *
 * @return bool
 */
bool IsOrderEventLogged(string event) {
   if (!hWndDesktop) return(false);

   string name = orderTracker.key + event;
   return(GetPropA(hWndDesktop, name) != 0);
}


/**
 * Set the logging status of the specified order event. Supports multiple terminals running in parallel.
 *
 * @param  string event  - event identifier
 * @param  bool   status - logging status
 *
 * @return bool - success status
 */
bool SetOrderEventLogged(string event, bool status) {
   if (!hWndDesktop) return(false);

   string name = orderTracker.key + event;
   int value = status!=0;
   return(SetPropA(hWndDesktop, name, status) != 0);
}


/**
 * Resolve the current Average Daily Range.
 *
 * @return double - ADR value or NULL in case of errors
 */
double GetADR() {
   static double adr = 0;                                   // TODO: invalidate static var on BarOpen(D1)

   if (!adr) {
      adr = iADR(F_ERR_NO_HISTORY_DATA);

      if (!adr && last_error==ERR_NO_HISTORY_DATA) {
         SetLastError(ERS_TERMINAL_NOT_YET_READY);
      }
   }
   return(adr);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("UnitSize.Corner=", DoubleQuoteStr(UnitSize.Corner), ";", NL,
                            "Track.Orders=",    DoubleQuoteStr(Track.Orders),    ";", NL,
                            "Signal.Sound=",    DoubleQuoteStr(Signal.Sound),    ";", NL,
                            "Signal.Mail=",     DoubleQuoteStr(Signal.Mail),     ";", NL,
                            "Signal.SMS=",      DoubleQuoteStr(Signal.SMS),      ";")
   );
}


#import "rsfLib.ex4"
   bool     AquireLock(string mutexName, bool wait);
   int      ArrayDropInt          (int    &array[], int value);
   int      ArrayInsertDoubleArray(double &array[][], int offset, double values[]);
   int      ArrayInsertDoubles    (double &array[], int offset, double values[]);
   int      ArrayPushDouble       (double &array[], double value);
   int      ArrayPushDoubles      (double &array[], double values[]);
   int      ArraySpliceDoubles    (double &array[], int offset, int length);
   int      ChartInfos.CopyLfxOrders(bool direction, int orders[][], int iData[][], bool bData[][], double dData[][]);
   bool     ChartMarker.OrderSent_A(int ticket, int digits, color markerColor);
   string   GetHostName();
   string   GetLongSymbolNameOrAlt(string symbol, string altValue);
   string   GetSymbolName(string symbol);
   string   IntsToStr(int array[], string separator);
   bool     ReleaseLock(string mutexName);
   int      SearchStringArrayI(string haystack[], string needle);
   bool     SortOpenTickets(int &keys[][]);
   string   StringsToStr(string array[], string separator);
   string   TicketsToStr.Lots    (int array[], string separator);
   string   TicketsToStr.Position(int array[]);
#import
