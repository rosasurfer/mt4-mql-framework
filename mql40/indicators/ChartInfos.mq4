/**
 * ChartInfos
 *
 * The indicator displays various market infos, account infos and trade statistics.
 *
 *  - The current instrument name (in terminals <= build 509).
 *  - The current price and spread.
 *  - The pre-calculated unitsize for a standard position.
 *  - The total open position with resulting risk and leverage values.
 *  - PnL of customizable open positions and/or trade history.
 *  - Breakeven and PnL target levels.
 *  - The account's current stopout level.
 *  - A visual warning with increasing intensity when the account's open order limit is approached.
 *
 *
 * TODO:
 *  - CustomPosition()
 *     "L,S, O 2024.06.06 19:17-" counts open positions twice, "L,S, O 2024.06.06-, O 2024.06.06-" counts them thrice...
 *     history parsing/config term HT... freezes the terminal if full history is active
 *      ExtractPosition()
 *       SortClosedTickets()           time=0.271 sec => move to Expander
 *       nested loop "correct hedges"  time=13.5 sec  => move to Expander
 *     weekend configuration/timespans don't work (H Today on Bitcoin)
 *     including/excluding a specific strategy is not supported
 *  - don't recalculate unitsize on every tick (every few seconds is sufficient)
 *  - set order tracker sound on stopout to "margin-call"
 *  - order events during chart change (symbol/timeframe) are not detected
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern bool Track.Orders = true;                                  // whether to track and signal position open/close events

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/MT4iQuickChannel.mqh>
#include <rsf/win32api.mqh>

#include <rsf/functions/HandleCommands.mqh>
#include <rsf/functions/InitializeByteBuffer.mqh>
#include <rsf/functions/lfx.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/functions/SortClosedTickets.mqh>
#include <rsf/functions/scriptrunner.mqh>
#include <rsf/functions/ta/ADR.mqh>
#include <rsf/structs/LFXOrder.mqh>

#property indicator_chart_window

// unitsize calculation
bool    mm.done;                                                  // processing flag
double  mm.externalAssets;                                        // external assets
bool    mm.externalAssetsCached;                                  // whether mm.externalAssets holds a valid cached value
double  mm.equity;                                                // equity value used for calculations, incl. external assets and floating losses (but w/o floating/unrealized profits)

bool    mm.cfgIsValid;                                            // whether the unitsize configuration is valid/initialized
double  mm.cfgRiskRange;                                          //
bool    mm.cfgRiskRangeIsADR;                                     // whether the price range is configured as "ADR"
double  mm.cfgRiskPercent;                                        //
double  mm.cfgLeverage;                                           //

double  mm.lotValue;                                              // value of 1 lot in account currency
double  mm.unleveragedLots;                                       // unleveraged unitsize
double  mm.leveragedLots;                                         // leveraged unitsize
double  mm.leveragedLotsNormalized;                               // leveraged unitsize normalized to MODE_LOTSTEP
double  mm.leveragePerUnit;                                       // resulting leverage per unit
bool    mm.usesLeverage;                                          // whether the calculated unitsize uses leverage or a risk range

// internal or external position data
bool    isPendings;                                               // ob Pending-Limits im Markt liegen (Orders oder Positions)
bool    isPosition;                                               // ob offene Positionen existieren, die Gesamtposition kann flat sein: longPosition || shortPosition
double  totalPosition;
double  longPosition;
double  shortPosition;

// a custom virtual position (if any)
bool    isVirtualPosition;
double  virtualTotalPosition;
double  virtualLongPosition;
double  virtualShortPosition;

// parsed configuration of custom positions
double  config.terms[][5];                                        // @see CustomPositions.ReadConfig() for format

// indexes of config.terms[]
#define I_TERM_TYPE                     0                         //
#define I_TERM_VALUE1                   1                         //
#define I_TERM_VALUE2                   2                         //
#define I_TERM_RESULT1                  3                         // intermediate calculation results
#define I_TERM_RESULT2                  4                         // ...

#define TERM_TICKET                     1                         // supported config terms (possible values of config.terms[][I_TERM_TYPE])
#define TERM_OPEN_LONG                  2                         //
#define TERM_OPEN_SHORT                 3                         //
#define TERM_OPEN                       4                         // intentionally there's no TERM_OPEN_TOTAL
#define TERM_HISTORY                    5                         //
#define TERM_HISTORY_TOTAL              6                         //
#define TERM_PL_ADJUSTMENT              7                         //
#define TERM_EQUITY                     8                         //
#define TERM_MFAE                       9                         //
#define TERM_MFAE_SIGNAL               10                         //
#define TERM_BE_MARKER                 11                         //
#define TERM_PROFIT_MARKER             12                         //
#define TERM_LOSS_MARKER               13                         //

// data of configured custom positions: size(config.sData) == size(config.dData) == number-of-configured-custom-positions
string  config.sData[][2];                                        // data: {Key, Comment}
double  config.dData[][8];                                        // data: {BemEnabled, MfaeEnabled, MfaeSignal, MfeMark, MfeValueM, MaeValueM, MaxLots, MaxRisk}

// indexes of config.sData[]
#define I_CONFIG_KEY                    0                         //
#define I_CONFIG_COMMENT                1                         //

// indexes of config.dData[]
#define I_BEM_ENABLED                   0                         // whether to display the breakeven marker of a custom position
#define I_MFAE_ENABLED                  1                         // whether to track MFE/MAE of a custom position
#define I_MFAE_SIGNAL                   2                         // whether to signal new MFE/MAE of a custom position
#define I_MARK_MFE                      3                         // whether to mark MFE levels
#define I_PROFIT_MFE                    4                         // MFE in money
#define I_PROFIT_MAE                    5                         // MAE in money
#define I_MAX_LOTS                      6                         //
#define I_MAX_RISK                      7                         //

// displayed custom position entries (may be larger than configured entries)
double  positions.data[][17];                                     // data: {ConfigLine, CustomType, PositionType, DirectionalLots, HedgedLots, PipDistance|BreakevenPrice, AdjustedProfit, TotalProfitM, TotalProfitPct, MfePrice, MfePct, MaePrice, MaePct, ProfitMarkerPrice, ProfitMarkerPct, LossMarkerPrice, LossMarkerPct}
bool    positions.analyzed;                                       //
bool    positions.showAbsProfits;                                 // for column adjustment (default: online=FALSE, tester=TRUE)
bool    positions.showMfae;                                       // for column adjustment: whether at least one active config entry has the MFAE tracker enabled
bool    positions.showMaxRisk;                                    // default: FALSE

#define CUSTOM_REAL_POSITION            1                         // config line types: real position
#define CUSTOM_VIRTUAL_POSITION         2                         //                    virtual position (pure virtual or composite virtual/real)

#define VIRTUAL_TICKET_LONG            -1                         // synthetic tickets of virtual positions
#define VIRTUAL_TICKET_SHORT           -2                         //

#define POSITION_LONG                   1                         // position type ids, also array indexes of typeDescriptions[]
#define POSITION_SHORT                  2                         //
#define POSITION_HEDGE                  3                         //
#define POSITION_HISTORY                4                         //
string  typeDescriptions[] = {"", "Long:", "Short:", "Hedge:", "History:"};

// indexes of positions.data[]
#define I_CONFIG_LINE                   0                         //
#define I_CUSTOM_TYPE                   1                         //
#define I_POSITION_TYPE                 2                         //
#define I_DIRECTIONAL_LOTS              3                         //
#define I_HEDGED_LOTS                   4                         //
#define I_PIP_DISTANCE                  5                         //
#define I_BREAKEVEN_PRICE  I_PIP_DISTANCE                         // union: on-position=BreakevenPrice, on-hedged=PipDistance
#define I_ADJUSTED_PROFIT               6                         //
#define I_PROFIT                        7                         // total profit in money
#define I_PROFIT_PCT                    8                         // total profit in percent
#define I_PROFIT_MFE_PRICE              9                         // MFE price
#define I_PROFIT_MFE_PCT               10                         // MFE in percent
#define I_PROFIT_MAE_PRICE             11                         // MAE price
#define I_PROFIT_MAE_PCT               12                         // MAE in percent
#define I_PROFIT_MARKER_PRICE          13                         //
#define I_PROFIT_MARKER_PCT            14                         //
#define I_LOSS_MARKER_PRICE            15                         //
#define I_LOSS_MARKER_PCT              16                         //

// control flags for AnalyzePositions()
#define F_LOG_TICKETS                   1                         // log tickets of resulting custom positions
#define F_LOG_SKIP_EMPTY                2                         // skip empty array elements when logging tickets
#define F_SHOW_CUSTOM_POSITIONS         4                         // call ShowOpenOrders() for custom positions
#define F_SHOW_CUSTOM_HISTORY           8                         // call ShowTradeHistory() for custom history

// Cache-Variablen f�r LFX-Orders. Ihre Gr��e entspricht der Gr��e von lfxOrders[].
// Dienen der Beschleunigung, um nicht st�ndig die LFX_ORDER-Getter aufrufen zu m�ssen.
int     lfxOrders.iCache[][1];                                    // = [Ticket]
bool    lfxOrders.bCache[][3];                                    // = [IsPendingOrder, IsOpenPosition, IsPendingPosition]
double  lfxOrders.dCache[][7];                                    // = [OpenEquity, Profit, LastProfit, TP-Amount, TP-Percent, SL-Amount, SL-Percent]
int     lfxOrders.pendingOrders;                                  // Anzahl der PendingOrders (mit Entry-Limit)  : lo.IsPendingOrder()    = 1
int     lfxOrders.openPositions;                                  // Anzahl der offenen Positionen               : lo.IsOpenPosition()    = 1
int     lfxOrders.pendingPositions;                               // Anzahl der offenen Positionen mit Exit-Limit: lo.IsPendingPosition() = 1

#define IC.ticket                   0                             // Arrayindizes f�r Cache-Arrays

#define BC.isPendingOrder           0
#define BC.isOpenPosition           1
#define BC.isPendingPosition        2

#define DC.openEquity               0
#define DC.profit                   1
#define DC.lastProfit               2                             // der letzte vorherige Profit-Wert, um PL-Aktionen nur bei �nderungen durchf�hren zu k�nnen
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

// chart location of unitsize and total position
int     position.unitsize.corner;
int     position.unitsize.yLine1;
int     position.unitsize.yLine2;

// font settings for custom positions
string  positions.fontName          = "MS Sans Serif";
int     positions.fontSize          = 8;
color   positions.fontColor.open    = Blue;
color   positions.fontColor.virtual = Green;
color   positions.fontColor.history = C'128,128,0';

// order tracking
#define TI_TICKET          0                                      // order tracker indexes
#define TI_ORDERTYPE       1
#define TI_ENTRYLIMIT      2

int     hWndDesktop;                                              // handle of the desktop main window (for listener registration)
double  trackedOrders[][3];                                       // {ticket, orderType, openLimit}
string  orderTracker.key = "";                                    // prefix for listener registration
string  orderTracker.orderFailed    = "speech/OrderCancelled.wav";
string  orderTracker.positionOpened = "speech/OrderFilled.wav";
string  orderTracker.positionClosed = "speech/PositionClosed.wav";

// display flags
bool    display.balance         = false;
bool    display.externalBalance = false;

// types for server-side closed positions
#define CLOSE_TAKEPROFIT   1
#define CLOSE_STOPLOSS     2
#define CLOSE_STOPOUT      3

// initialization/deinitialization
#include <rsf/indicators/chartinfos/init.mqh>
#include <rsf/indicators/chartinfos/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!__isChart) return(last_error);

   mm.done = false;
   positions.analyzed = false;

   if (!HandleCommands()) return(last_error);                                       // process incoming commands

   if (mode.extern) {
      if (!QC.HandleLfxTerminalMessages()) if (IsLastError()) return(last_error);   // process incoming LFX commands
      if (!UpdatePrice())                  if (IsLastError()) return(last_error);   // current price (top-right)
      if (!UpdatePositions())              if (IsLastError()) return(last_error);   // custom positions (bottom-left) and total open position (bottom-right)
   }
   else {
      if (!QC.HandleTradeCommands())       if (IsLastError()) return(last_error);   // process incoming trade commands
      if (!UpdatePrice())                  if (IsLastError()) return(last_error);   // current price (top-right)
      if (!UpdateSpread())                 if (IsLastError()) return(last_error);   // current spread (top-right)
      if (!UpdateUnitSize())               if (IsLastError()) return(last_error);   // unit size of a standard position (bottom-right)
      if (!UpdatePositions())              if (IsLastError()) return(last_error);   // custom positions (bottom-left) and total open position (bottom-right)
      if (!UpdateStopoutLevel())           if (IsLastError()) return(last_error);   // stopout level marker
      if (!UpdateOrderCounter())           if (IsLastError()) return(last_error);   // counter for the account's open order limit

      if (Track.Orders) {                                                           // monitor order execution
         double openedPositions[][2]; ArrayResize(openedPositions, 0);              // {ticket, entryLimit}
         int    closedPositions[][2]; ArrayResize(closedPositions, 0);              // {ticket, closedType}
         int    failedOrders   [];    ArrayResize(failedOrders,    0);              // {ticket}

         if (!MonitorOpenOrders(openedPositions, closedPositions, failedOrders)) return(last_error);
         if (ArraySize(openedPositions) > 0) onPositionOpen(openedPositions);
         if (ArraySize(closedPositions) > 0) onPositionClose(closedPositions);
         if (ArraySize(failedOrders   ) > 0) onOrderFail(failedOrders);
      }
   }
   UpdateBalanceDisplay();                                                          // account balance with/wo external assets

   return(last_error);
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
      int flags = F_LOG_TICKETS;                                        // log tickets
      if (!keys & F_VK_SHIFT) flags |= F_LOG_SKIP_EMPTY;                // without VK_SHIFT: skip empty tickets (default)
      if (!AnalyzePositions(flags)) return(false);                      // with VK_SHIFT:    log empty tickets
   }

   else if (cmd == "toggle-account-balance") {
      if (!ToggleAccountBalance(keys & F_VK_SHIFT && 1)) return(false);
   }

   else if (cmd == "toggle-open-orders") {
      flags = NULL;
      if (keys & F_VK_SHIFT && 1) {
         flags = F_SHOW_CUSTOM_POSITIONS;                               // with VK_SHIFT: show custom positions only
         mm.cfgIsValid = false;                                         // invalidate cached unitsize configuration
         mm.externalAssetsCached = false;                               // invalidate cached external assets
         ArrayResize(config.terms, 0);                                  // trigger reparsing of the configuration
      }
      if (!ToggleOpenOrders(flags)) return(false);
   }

   else if (cmd == "toggle-trade-history") {
      flags = NULL;
      if (keys & F_VK_SHIFT && 1) {
         flags = F_SHOW_CUSTOM_HISTORY;                                 // with VK_SHIFT: show custom history only
         mm.cfgIsValid = false;                                         // invalidate cached unitsize configuration
         mm.externalAssetsCached = false;                               // invalidate cached external assets
         ArrayResize(config.terms, 0);                                  // trigger reparsing of the configuration
      }
      if (!ToggleTradeHistory(flags)) return(false);
   }

   else if (cmd == "toggle-profit") {
      if (!CustomPositions.ToggleProfits()) return(false);
   }

   else if (cmd == "toggle-risk") {
      if (!CustomPositions.ToggleRisk()) return(false);
   }

   else if (cmd == "trade-account") {
      string key = StrReplace(params, ",", ":");
      if (!InitTradeAccount(key))  return(false);
      if (!UpdateAccountDisplay()) return(false);
         mm.cfgIsValid = false;                                         // invalidate cached unitsize configuration
      mm.externalAssetsCached = false;                                  // invalidate cached external assets
      ArrayResize(config.terms, 0);                                     // trigger reparsing of the configuration
   }

   else if (cmd == "toggle-unit-size") {
      position.unitsize.corner = ifInt(position.unitsize.corner == CORNER_BOTTOM_RIGHT, CORNER_TOP_RIGHT, CORNER_BOTTOM_RIGHT);
      if (!CreateLabels()) return(false);
   }

   else {
      return(!logNotice("onCommand(1)  unsupported command: \""+ cmd +":"+ params +":"+ keys +"\""));
   }
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

         if (StringGetChar(name, 0)=='#' && ObjectType(name)==OBJ_ARROW) {
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
         else if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;               // FALSE: an open order was closed/deleted in another thread
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

      // Sortierschl�ssel aller geschlossenen Positionen auslesen und nach {CloseTime, OpenTime, Ticket} sortieren
      int sortKeys[][3];                                                // {CloseTime, OpenTime, Ticket}
      ArrayResize(sortKeys, orders);

      for (i=0, n=0; i < orders; i++) {
         if (customTicketsSize > 0) success = SelectTicket(customTickets[i], "ShowTradeHistory(1)");
         else                       success = OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
         if (!success)                  break;                          // FALSE: the visible history range was modified in another thread
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

            // TODO: Pr�fen, wie sich OrderComment() bei custom comments verh�lt.
            if (!StrStartsWithI(comments[i], "close hedge by #"))
               return(_EMPTY(catch("ShowTradeHistory(3)  #"+ tickets[i] +" - unknown comment for assumed hedging position: \""+ comments[i] +"\"", ERR_RUNTIME_ERROR)));

            // Gegenst�ck suchen
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
         if (!tickets[i]) continue;                                  // verworfene Hedges �berspringen
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
         if (positions.showAbsProfits || !openEquity) text = ifString(profit > 0, "+", "") + DoubleToStr(profit, 2);
         else                                         text = ifString(profit > 0, "+", "") + DoubleToStr(profit/openEquity * 100, 2) +"%";
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
 * Toggle the MaxLots/MaxRisk display of custom positions.
 *
 * @return bool - success status
 */
bool CustomPositions.ToggleRisk() {
   positions.showMaxRisk = !positions.showMaxRisk;             // toggle status and update positions
   return(UpdatePositions());
}


/**
 * Toggle PnL amounts of custom positions between "absolute" und "percentage".
 *
 * @return bool - success status
 */
bool CustomPositions.ToggleProfits() {
   positions.showAbsProfits = !positions.showAbsProfits;       // toggle status and update positions
   return(UpdatePositions());
}


/**
 * Toggle the display of the current account balance.
 *
 * @param  bool externalAssets - whether to show external assets (if any)
 *
 * @return bool - success status
 */
bool ToggleAccountBalance(bool externalAssets) {
   externalAssets = externalAssets!=0;
   display.balance = !GetAccountBalanceDisplayStatus();        // get current display status and toggle it

   if (display.balance) {
      if (!mode.intern) {
         display.balance = false;                              // mode.extern not yet implemented
         PlaySoundEx("Plonk.wav");
         return(true);
      }
      mm.externalAssetsCached = false;                         // invalidate cached external assets
   }
   display.externalBalance = externalAssets;
   UpdateBalanceDisplay();
   if (__isTesting) WindowRedraw();

   SetAccountBalanceDisplayStatus(display.balance);            // store new display status
   return(!catch("ToggleAccountBalance(1)"));
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
      if (ObjectFind(label.instrument) == -1) if (!ObjectCreateRegister(label.instrument, OBJ_LABEL)) return(false);
      ObjectSet(label.instrument, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label.instrument, OBJPROP_XDISTANCE, ifInt(build < 479, 4, 13));    // On builds > 478 the label is inset to account for the arrow of the
      ObjectSet(label.instrument, OBJPROP_YDISTANCE, ifInt(build < 479, 1,  3));    // "One-Click-Trading" feature.
      string name = GetLongSymbolNameOrAlt(Symbol(), GetSymbolName(Symbol()));
      if      (StrEndsWithI(Symbol(), "_ask")) name = name +" (Ask)";
      else if (StrEndsWithI(Symbol(), "_avg")) name = name +" (Avg)";
      ObjectSetText(label.instrument, name, 9, "Tahoma Fett", Black);
   }

   // price
   if (ObjectFind(label.price) == -1) if (!ObjectCreateRegister(label.price, OBJ_LABEL)) return(false);
   ObjectSet    (label.price, OBJPROP_CORNER, CORNER_TOP_RIGHT);
   ObjectSet    (label.price, OBJPROP_XDISTANCE, 14);
   ObjectSet    (label.price, OBJPROP_YDISTANCE, 15);
   ObjectSetText(label.price, " ", 1);

   // spread
   corner = CORNER_TOP_RIGHT;
   xDist  = 33;
   yDist  = 38;
   if (ObjectFind(label.spread) == -1) if (!ObjectCreateRegister(label.spread, OBJ_LABEL)) return(false);
   ObjectSet    (label.spread, OBJPROP_CORNER,   corner);
   ObjectSet    (label.spread, OBJPROP_XDISTANCE, xDist);
   ObjectSet    (label.spread, OBJPROP_YDISTANCE, yDist);
   ObjectSetText(label.spread, " ", 1);

   // unit size
   corner = position.unitsize.corner;
   xDist  = 9;
   switch (corner) {
      case CORNER_TOP_RIGHT:    yDist = 58; break;    // yDist of spread + 20
      case CORNER_BOTTOM_RIGHT: yDist =  9; break;
   }
   position.unitsize.yLine1 = yDist;
   if (ObjectFind(label.unitSize) == -1) if (!ObjectCreateRegister(label.unitSize, OBJ_LABEL)) return(false);
   ObjectSet    (label.unitSize, OBJPROP_CORNER,   corner);
   ObjectSet    (label.unitSize, OBJPROP_XDISTANCE, xDist);
   ObjectSet    (label.unitSize, OBJPROP_YDISTANCE, yDist);
   ObjectSetText(label.unitSize, " ", 1);

   // total position
   corner = position.unitsize.corner;
   xDist  = 9;
   yDist += 20;                                                   // 1 line above/below unitsize
   position.unitsize.yLine2 = yDist;
   if (ObjectFind(label.totalPosition) == -1) if (!ObjectCreateRegister(label.totalPosition, OBJ_LABEL)) return(false);
   ObjectSet    (label.totalPosition, OBJPROP_CORNER,   corner);
   ObjectSet    (label.totalPosition, OBJPROP_XDISTANCE, xDist);
   ObjectSet    (label.totalPosition, OBJPROP_YDISTANCE, yDist);
   ObjectSetText(label.totalPosition, " ", 1);

   // account balance
   if (ObjectFind(label.accountBalance) == -1) if (!ObjectCreateRegister(label.accountBalance, OBJ_LABEL)) return(false);
   ObjectSet    (label.accountBalance, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet    (label.accountBalance, OBJPROP_XDISTANCE, 330);
   ObjectSet    (label.accountBalance, OBJPROP_YDISTANCE,   9);
   ObjectSetText(label.accountBalance, " ", 1);

   // order counter
   if (ObjectFind(label.orderCounter) == -1) if (!ObjectCreateRegister(label.orderCounter, OBJ_LABEL)) return(false);
   ObjectSet    (label.orderCounter, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet    (label.orderCounter, OBJPROP_XDISTANCE, 500);
   ObjectSet    (label.orderCounter, OBJPROP_YDISTANCE,   9);
   ObjectSetText(label.orderCounter, " ", 1);

   // trade account
   if (ObjectFind(label.tradeAccount) == -1) if (!ObjectCreateRegister(label.tradeAccount, OBJ_LABEL)) return(false);
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
   double price = _Bid;                                     // fall-back to Close[0]: Symbol (noch) nicht subscribed (Start, Account-/Templatewechsel, Offline-Chart)
   if (!price) price = NormalizeDouble(Close[0], Digits);   // History-Daten k�nnen unnormalisiert sein, wenn sie nicht von MetaTrader erstellt wurden

   ObjectSetText(label.price, NumberToStr(price, PriceFormat), 13, "Microsoft Sans Serif", Black);

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)          // on ObjectDrag or opened "Properties" dialog
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
   color spreadColor = SlateGray;
                                                            // don't use MarketInfo(MODE_SPREAD) as in tester it's invalid
   if (_Bid > 0) {                                          // skip if the symbol is not yet subscribed (e.g. start, account/template change, offline chart)
      double spread = NormalizeDouble(_Ask - _Bid, Digits);
      if (pUnit == 1) sSpread = DoubleToStr(spread, 2);
      else            sSpread = DoubleToStr(spread/pUnit, (Digits & 1));

      if (Symbol() == "BTCUSD") {
         if      (spread >= 40) spreadColor = Red;
         else if (spread >= 30) spreadColor = DarkOrange;
      }
   }

   ObjectSetText(label.spread, sSpread, 9, "Tahoma", spreadColor);

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)          // on ObjectDrag or opened "Properties" dialog
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
   string text = " ";

   if (mode.intern) {
      if (mm.cfgRiskRange != NULL) {
         double range = mm.cfgRiskRange;
         string sRiskRange = "";
         if (mm.cfgRiskRangeIsADR) {
            if (Close[0] > 300 && range >= 3) range = MathRound(range);
            else                              range = NormalizeDouble(range, PipDigits);
            sRiskRange = "ADR=";
         }
         if (Close[0] > 300 && range >= 3) sRiskRange = StringConcatenate(sRiskRange, NumberToStr(range, ",'.2+"));
         else                              sRiskRange = StringConcatenate(sRiskRange, NumberToStr(NormalizeDouble(range/Pip, 1), ".+"), " pip");
         text = sRiskRange;
      }

      if (mm.usesLeverage) text = StringConcatenate(text, "     L", DoubleToStr(mm.leveragePerUnit, 1));
      else                 text = StringConcatenate(text, "     R", NumberToStr(NormalizeDouble(mm.cfgRiskPercent, 1), ".+"), "%");
      text = StringConcatenate(text, "     ", NumberToStr(mm.leveragedLotsNormalized, ".+"), " lot");
   }

   bool noPosition = !isPosition && !isVirtualPosition;
   ObjectSet    (label.unitSize, OBJPROP_YDISTANCE, ifInt(position.unitsize.corner == CORNER_BOTTOM_RIGHT || noPosition, position.unitsize.yLine1, position.unitsize.yLine2));
   ObjectSetText(label.unitSize, text, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)       // on ObjectDrag or opened "Properties" dialog
      return(true);
   return(!catch("UpdateUnitSize(1)", error));
}


/**
 * Update total open position (bottom-right) and custom positions (bottom-left).
 *
 * @return bool - success status
 */
bool UpdatePositions() {
   if (mode.intern && !mm.done) {
      if (!CalculateUnitSize()) return(false);
      if (!mm.done)             return(true);            // terminal not yet ready
   }

   if (!positions.analyzed) {
      if (!AnalyzePositions())  return(false);
      if (!positions.analyzed)  return(true);            // terminal not yet ready
   }

   // total virtual/real position bottom-right
   bool   _isPosition = false;
   double _totalPosition, _longPosition, _shortPosition;
   string sCurrentPosition = " ";

   if (isPosition) {                                     // real position data
      _isPosition    = isPosition;
      _totalPosition = totalPosition;
      _longPosition  = longPosition;
      _shortPosition = shortPosition;
   }
   else if (isVirtualPosition) {                         // virtual position data
      _isPosition    = isVirtualPosition;
      _totalPosition = virtualTotalPosition;
      _longPosition  = virtualLongPosition;
      _shortPosition = virtualShortPosition;
      sCurrentPosition = "Virt. ";
   }

   if (_isPosition) {
      if (!_totalPosition) {
         sCurrentPosition = StringConcatenate(sCurrentPosition, "Position:    �", NumberToStr(_longPosition, ",'.+"), " lot (hedged)");
      }
      else {
         double currentUnits = 0;
         string sCurrentUnits = "";
         if (mm.leveragedLots != 0) {
            currentUnits  = MathAbs(_totalPosition)/mm.leveragedLots;
            sCurrentUnits = StringConcatenate("U", NumberToStr(currentUnits, ",'.1R"), "    ");
         }
         string sCurrentLeverage = "";
         if (mm.unleveragedLots != 0) sCurrentLeverage = StringConcatenate("L", NumberToStr(MathAbs(_totalPosition)/mm.unleveragedLots, ",'.1R"), "   ");
         sCurrentPosition = StringConcatenate(sCurrentPosition, "Position:    ", sCurrentUnits, sCurrentLeverage, NumberToStr(_totalPosition, "+,'.+"), " lot");
      }
   }
   ObjectSet    (label.totalPosition, OBJPROP_YDISTANCE, ifInt(position.unitsize.corner == CORNER_BOTTOM_RIGHT, position.unitsize.yLine2, position.unitsize.yLine1));
   ObjectSetText(label.totalPosition, sCurrentPosition, 9, "Tahoma", SlateGray);

   int error = GetLastError();                                             // on ObjectDrag or opened "Properties" dialog
   if (error && error!=ERR_OBJECT_DOES_NOT_EXIST) return(!catch("UpdatePositions(1)", error));

   // pending order marker bottom-right
   string label = ProgramName() +".PendingTickets";
   if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL)) return(false);
   ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
   ObjectSet(label, OBJPROP_XDISTANCE, 12);
      int yDist = 12;
      if (position.unitsize.corner == CORNER_BOTTOM_RIGHT) {
         yDist += 18;
         if (isPosition || isVirtualPosition) {
            yDist += 18;
         }
      }
   ObjectSet(label, OBJPROP_YDISTANCE, yDist);
   ObjectSet(label, OBJPROP_TIMEFRAMES, ifInt(isPendings, OBJ_PERIODS_ALL, OBJ_PERIODS_NONE));
   ObjectSetText(label, "n", 6, "Webdings", Orange);                       // a Webdings "dot"

   // prepare rows for custom positions bottom-left
   int xDist, xPrev, yStart=6, maxCols=9;
   static int lines, cols, percentCol=-1, mfaeCol=-1, commentCol=-1, xOffset[];
   static bool lastShowAbsProfits, lastShowMfae;

   if (!ArraySize(xOffset) || positions.showAbsProfits!=lastShowAbsProfits || positions.showMfae!=lastShowMfae) {
      // offsets:     Type:  Lots  BE:  BePrice  Profit:  Percent  Comment
      int offsets[] = {9,    46,   83,  28,      68,      39,      61};
      ArrayResize(offsets, 7);
      percentCol = 5;
      commentCol = 6;

      if (positions.showAbsProfits) {
         //           Type:  Lots  BE:  BePrice  Profit:  Abs   Percent  Comment
         // offsets = {9,    46,   83,  28,      68,      39,   87,      61};
         ArrayInsertInt(offsets, 6, 87);                                   // add column for AbsProfit
         percentCol++;
         commentCol++;
      }
      if (positions.showMfae) {
         //           Type:  Lots  BE:  BePrice  Profit:  Abs   Percent  MFE/MAE  Comment
         // offsets = {9,    46,   83,  28,      68,      39,   87,      51,      90};
         ArrayPushInt(offsets, 90);                                        // add column for MFE/MAE
         mfaeCol = percentCol + 1;
         offsets[mfaeCol] = 51;
         commentCol++;
      }
      ArrayResize(xOffset, 0);
      cols = ArrayCopy(xOffset, offsets);

      lastShowAbsProfits = positions.showAbsProfits;
      lastShowMfae       = positions.showMfae;

      // after re-initialization: delete all existing lines and markers
      while (lines > 0) {
         for (int col=0; col < maxCols; col++) {                           // test for all possible columns
            label = StringConcatenate(label.customPosition, ".line", lines, "_col", col);
            if (ObjectFind(label) != -1) ObjectDelete(label);
         }
         label = StringConcatenate(label.customPosition, ".line", lines, "_bem");
         if (ObjectFind(label) != -1) ObjectDelete(label);
         label = StringConcatenate(label.customPosition, ".line", lines, "_pm");
         if (ObjectFind(label) != -1) ObjectDelete(label);
         label = StringConcatenate(label.customPosition, ".line", lines, "_lm");
         if (ObjectFind(label) != -1) ObjectDelete(label);
         label = StringConcatenate(label.customPosition, ".line", lines, "_mfem");
         if (ObjectFind(label) != -1) ObjectDelete(label);
         lines--;
      }
   }

   // create new rows as needed
   int positions = ArrayRange(positions.data, 0);
   if (mode.extern) positions = lfxOrders.openPositions;

   while (lines < positions) {
      lines++;
      xPrev = 0;
      yDist = yStart + (lines-1)*(positions.fontSize+8);

      // test existence of labels again: on terminal shutdown via power button deinit() is not always executed
      for (col=0; col < cols; col++) {
         label = StringConcatenate(label.customPosition, ".line", lines, "_col", col);
         xDist = xPrev + xOffset[col];
         if (ObjectFind(label) == -1) /*&&*/ if (!ObjectCreateRegister(label, OBJ_LABEL)) return(false);
         ObjectSet(label, OBJPROP_CORNER, CORNER_BOTTOM_LEFT);
         ObjectSet(label, OBJPROP_XDISTANCE, xDist);
         ObjectSet(label, OBJPROP_YDISTANCE, yDist);
         ObjectSetText(label, " ", 1);
         xPrev = xDist;
      }
      label = StringConcatenate(label.customPosition, ".line", lines, "_bem");
      if (ObjectFind(label) == -1) /*&&*/ if (!ObjectCreateRegister(label, OBJ_HLINE)) return(false);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
      label = StringConcatenate(label.customPosition, ".line", lines, "_pm");
      if (ObjectFind(label) == -1) /*&&*/ if (!ObjectCreateRegister(label, OBJ_HLINE)) return(false);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
      label = StringConcatenate(label.customPosition, ".line", lines, "_lm");
      if (ObjectFind(label) == -1) /*&&*/ if (!ObjectCreateRegister(label, OBJ_HLINE)) return(false);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
      label = StringConcatenate(label.customPosition, ".line", lines, "_mfem");
      if (ObjectFind(label) == -1) /*&&*/ if (!ObjectCreateRegister(label, OBJ_ARROW)) return(false);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   }

   // remove existing surplus rows
   while (lines > positions) {
      for (col=0; col < maxCols; col++) {                                  // test for all possible columns
         label = StringConcatenate(label.customPosition, ".line", lines, "_col", col);
         if (ObjectFind(label) != -1) ObjectDelete(label);
      }
      label = StringConcatenate(label.customPosition, ".line", lines, "_bem");
      if (ObjectFind(label) != -1) ObjectDelete(label);
      label = StringConcatenate(label.customPosition, ".line", lines, "_pm");
      if (ObjectFind(label) != -1) ObjectDelete(label);
      label = StringConcatenate(label.customPosition, ".line", lines, "_lm");
      if (ObjectFind(label) != -1) ObjectDelete(label);
      label = StringConcatenate(label.customPosition, ".line", lines, "_mfem");
      if (ObjectFind(label) != -1) ObjectDelete(label);
      lines--;
   }

   // write custom position rows from bottom to top: "{Type}: {Lots}   BE|Dist: {Price|Pip}   Profit: [{Abs} ]{Percent}[ {MAE/MFE}]   {Comment}"
   string sPositionType="", sLotSize="", sDistance="", sBreakeven="", sAdjustment="", sProfitAbs="", sProfitPct="", sProfitMin="", sProfitMax="", sProfitMinMax="", sMaxRisk="", sComment="", markerText="", priceFormat="", _spUnit=ifString(pUnit==1, "", " "+ spUnit);
   color fontColor;
   int line, configLine, index;

   // update display of internal custom positions
   if (mode.intern) {
      if (Digits==2 && Close[0] < 500) priceFormat = PriceFormat +"'";
      else                             priceFormat = PriceFormat;

      for (int i=positions-1; i >= 0; i--) {
         line++;
         if      (positions.data[i][I_CUSTOM_TYPE  ] == CUSTOM_VIRTUAL_POSITION) fontColor = positions.fontColor.virtual;
         else if (positions.data[i][I_POSITION_TYPE] == POSITION_HISTORY)        fontColor = positions.fontColor.history;
         else                                                                    fontColor = positions.fontColor.open;

         index = positions.data[i][I_POSITION_TYPE];                       // (int) double
         sPositionType = typeDescriptions[index];

         if (positions.showAbsProfits) {
            sProfitAbs = NumberToStr(positions.data[i][I_PROFIT], ",'.2");
            if (positions.data[i][I_ADJUSTED_PROFIT] != NULL) sProfitAbs = StringConcatenate(sProfitAbs, " (", NumberToStr(positions.data[i][I_ADJUSTED_PROFIT], "+,'.2"), ")");
         }
         sProfitPct    = StringConcatenate(DoubleToStr(positions.data[i][I_PROFIT_PCT], 2), "%");
         sProfitMin    = " ";
         sProfitMax    = " ";
         sProfitMinMax = " ";
         sComment      = " ";

         configLine = positions.data[i][I_CONFIG_LINE];                    // (int) double
         if (configLine > -1) {
            if (positions.showMfae && config.dData[configLine][I_MFAE_ENABLED]) {
               sProfitMin    = DoubleToStr(positions.data[i][I_PROFIT_MAE_PCT], 2);
               sProfitMax    = DoubleToStr(positions.data[i][I_PROFIT_MFE_PCT], 2);
               sProfitMinMax = StringConcatenate("(", sProfitMin, "/", sProfitMax, ")");
            }
            sComment = config.sData[configLine][I_CONFIG_COMMENT];
            if (positions.showMaxRisk) {
               sComment = StringConcatenate("(", NumberToStr(config.dData[configLine][I_MAX_LOTS], ".+"), " lot/R?%)   ", sComment);
            }
         }

         // history only
         if (positions.data[i][I_POSITION_TYPE] == POSITION_HISTORY) {
            // "{Type}: {Lots}   BE|Dist: {Price|Pip}   Profit: [{Abs} ]{Percent}[ {MAE/MFE}]   {Comment}"
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col0"           ), sPositionType,                                         positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col1"           ), " ",                                                   positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col2"           ), " ",                                                   positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col3"           ), " ",                                                   positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col4"           ), "Profit:",                                             positions.fontSize, positions.fontName, fontColor);
            if (positions.showAbsProfits)
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col5"           ), sProfitAbs,                                            positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col", percentCol), sProfitPct,                                            positions.fontSize, positions.fontName, fontColor);
            if (positions.showMfae)
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col", mfaeCol   ), sProfitMinMax,                                         positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col", commentCol), sComment,                                              positions.fontSize, positions.fontName, fontColor);
         }

         // directional or hedged
         else {
            // "{Type}: {Lots}   BE|Dist: {Price|Pip}   Profit: [{Abs} ]{Percent}[ {MAE/MFE}]   {Comment}"
            // hedged
            if (positions.data[i][I_POSITION_TYPE] == POSITION_HEDGE) {
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col0"), sPositionType,                                                 positions.fontSize, positions.fontName, fontColor);
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col1"), NumberToStr(positions.data[i][I_HEDGED_LOTS  ], ".+") +" lot", positions.fontSize, positions.fontName, fontColor);
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col2"), "Dist:",                                                       positions.fontSize, positions.fontName, fontColor);
                  if (!positions.data[i][I_PIP_DISTANCE]) sDistance = "...";
                  else                                    sDistance = DoubleToStr(positions.data[i][I_PIP_DISTANCE]*Pip/pUnit, pDigits) + _spUnit;
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col3"), sDistance,                                                     positions.fontSize, positions.fontName, fontColor);
            }

            // not hedged
            else {
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col0"), sPositionType,                                                 positions.fontSize, positions.fontName, fontColor);
                  if (!positions.data[i][I_HEDGED_LOTS]) sLotSize = NumberToStr(positions.data[i][I_DIRECTIONAL_LOTS], ".+");
                  else                                   sLotSize = NumberToStr(positions.data[i][I_DIRECTIONAL_LOTS], ".+") +" �"+ NumberToStr(positions.data[i][I_HEDGED_LOTS], ".+");
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col1"), sLotSize +" lot",                                              positions.fontSize, positions.fontName, fontColor);
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col2"), "BE:",                                                         positions.fontSize, positions.fontName, fontColor);
                  if (!positions.data[i][I_BREAKEVEN_PRICE]) sBreakeven = "...";
                  else                                       sBreakeven = NumberToStr(positions.data[i][I_BREAKEVEN_PRICE], priceFormat);
               ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col3"), sBreakeven,                                                    positions.fontSize, positions.fontName, fontColor);
            }

            // hedged and not-hedged
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col4"           ), "Profit:",                                             positions.fontSize, positions.fontName, fontColor);
            if (positions.showAbsProfits)
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col5"           ), sProfitAbs,                                            positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col", percentCol), sProfitPct,                                            positions.fontSize, positions.fontName, fontColor);
            if (positions.showMfae)
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col", mfaeCol   ), sProfitMinMax,                                         positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col", commentCol), sComment,                                              positions.fontSize, positions.fontName, fontColor);
         }

         // update BE marker
         bool showBeMarker = false;
         if (configLine >= 0) {
            showBeMarker = (config.dData[configLine][I_BEM_ENABLED] && positions.data[i][I_POSITION_TYPE]!=POSITION_HEDGE && positions.data[i][I_POSITION_TYPE]!=POSITION_HISTORY);
         }
         label = StringConcatenate(label.customPosition, ".line", line, "_bem");
         if (!showBeMarker) {
            ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
         }
         else {
            markerText = StringSubstr(sPositionType, 0, 1) +" "+ sLotSize +"   BE";
            ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_ALL);
            ObjectSet(label, OBJPROP_STYLE,      STYLE_DASHDOTDOT);
            ObjectSet(label, OBJPROP_COLOR,      DarkTurquoise);
            ObjectSet(label, OBJPROP_BACK,       false);
            ObjectSet(label, OBJPROP_PRICE1,     positions.data[i][I_BREAKEVEN_PRICE]);
            ObjectSetText(label, markerText);
         }

         // update PL markers
         label = StringConcatenate(label.customPosition, ".line", line, "_pm");
         if (!positions.data[i][I_PROFIT_MARKER_PRICE]) {
            ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
         }
         else {
            markerText = StringSubstr(sPositionType, 0, 1) +" "+ sLotSize +"   PL "+ NumberToStr(NormalizeDouble(positions.data[i][I_PROFIT_MARKER_PCT], 2), "+.+") +"%";
            ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_ALL);
            ObjectSet(label, OBJPROP_STYLE,      STYLE_DASHDOTDOT);
            ObjectSet(label, OBJPROP_COLOR,      ifInt(positions.data[i][I_PROFIT_MARKER_PCT] < 0, OrangeRed, DodgerBlue));
            ObjectSet(label, OBJPROP_BACK,       false);
            ObjectSet(label, OBJPROP_PRICE1,     positions.data[i][I_PROFIT_MARKER_PRICE]);
            ObjectSetText(label, markerText);
         }

         label = StringConcatenate(label.customPosition, ".line", line, "_lm");
         if (!positions.data[i][I_LOSS_MARKER_PRICE]) {
            ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
         }
         else {
            markerText = StringSubstr(sPositionType, 0, 1) +" "+ sLotSize +"   PL "+ NumberToStr(NormalizeDouble(positions.data[i][I_LOSS_MARKER_PCT], 2), "+.+") +"%";
            ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_ALL);
            ObjectSet    (label, OBJPROP_STYLE,      STYLE_DASHDOTDOT);
            ObjectSet    (label, OBJPROP_COLOR,      ifInt(positions.data[i][I_LOSS_MARKER_PCT] < 0, OrangeRed, DodgerBlue));
            ObjectSet    (label, OBJPROP_BACK,       false);
            ObjectSet    (label, OBJPROP_PRICE1,     positions.data[i][I_LOSS_MARKER_PRICE]);
            ObjectSetText(label, markerText);
         }

         // update MFE marker
         label = StringConcatenate(label.customPosition, ".line", line, "_mfem");
         if (!positions.data[i][I_PROFIT_MFE_PRICE]) {
            ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
         }
         else {
            markerText = StringSubstr(sPositionType, 0, 1) +" "+ sLotSize +"  MFE  "+ NumberToStr(positions.data[i][I_PROFIT_MFE_PRICE], PriceFormat) +"  "+ sProfitMax +"%";
            ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_ALL);
            ObjectSet    (label, OBJPROP_ARROWCODE, SYMBOL_DASH);
            ObjectSet    (label, OBJPROP_COLOR,     CLR_OPEN_LONG);
            ObjectSet    (label, OBJPROP_TIME1,     Time[0] + 5*Period()*MINUTES);
            ObjectSet    (label, OBJPROP_PRICE1,    positions.data[i][I_PROFIT_MFE_PRICE]);
            ObjectSetText(label, markerText);
         }
      }
   }

   // update display of external custom positions
   if (mode.extern) {
      fontColor = positions.fontColor.open;
      for (i=ArrayRange(lfxOrders, 0)-1; i >= 0; i--) {
         if (lfxOrders.bCache[i][BC.isOpenPosition]) {
            line++;
            double profitPct = lfxOrders.dCache[i][DC.profit] / los.OpenEquity(lfxOrders, i) * 100;
            sComment = StringConcatenate(los.Comment(lfxOrders, i), " ");
            if (StringGetChar(sComment, 0) == '#') sComment = StringConcatenate(lfxCurrency, ".", StrSubstr(sComment, 1));

            // "{Type}: {Lots}   BE|Dist: {Price|Pip}   Profit: [{Abs} ]{Percent}   {Comment}"
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col0"           ), typeDescriptions[los.Type(lfxOrders, i)+1],               positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col1"           ), NumberToStr(los.Units    (lfxOrders, i), ".+") +" units", positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col2"           ), "BE:",                                                    positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col3"           ), NumberToStr(los.OpenPrice(lfxOrders, i), PriceFormat),    positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col4"           ), "Profit:",                                                positions.fontSize, positions.fontName, fontColor);
            if (positions.showAbsProfits)
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col5"           ), DoubleToStr(lfxOrders.dCache[i][DC.profit], 2),           positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col", percentCol), DoubleToStr(profitPct, 2) +"%",                           positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.customPosition, ".line", line, "_col", commentCol), sComment,                                                 positions.fontSize, positions.fontName, fontColor);
         }
      }
   }

   return(!catch("UpdatePositions(3)"));
}


/**
 * Update the current amount of open tickets and the account's open ticket limit.
 *
 * @return bool - success status
 */
bool UpdateOrderCounter() {
   static int showLimit=INT_MAX, warnLimit=INT_MAX, alertLimit=INT_MAX, maxOpenTickets;
   static color defaultColor=SlateGray, warnColor=DarkOrange, alertColor=Red;

   if (!maxOpenTickets) {
      maxOpenTickets = GetAccountConfigInt("Account", "MaxOpenTickets", -1);
      if (!maxOpenTickets) maxOpenTickets = -1;

      if (maxOpenTickets > 0) {
         alertLimit = Min(Round(0.9 * maxOpenTickets), maxOpenTickets-1);
         warnLimit  = Min(Round(0.8 * maxOpenTickets), alertLimit    -1);
         showLimit  = Min(Round(0.7 * maxOpenTickets), warnLimit     -1);
      }
   }
   string sText = " ";
   color objectColor = defaultColor;

   int orders = OrdersTotal();
   if (orders >= showLimit) {
      if      (orders >= alertLimit) objectColor = alertColor;
      else if (orders >= warnLimit ) objectColor = warnColor;
      sText = StringConcatenate(orders, " open orders (max. ", maxOpenTickets, ")");
   }
   ObjectSetText(label.orderCounter, sText, 8, "Tahoma Fett", objectColor);

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                                     // on ObjectDrag or opened "Properties" dialog
      return(true);
   return(!catch("UpdateOrderCounter(1)", error));
}


/**
 * Update the display of the current account balance.
 *
 * @return bool - success status
 */
bool UpdateBalanceDisplay() {
   if (__isSuperContext) return(true);
   static bool   lastStatus = -1;
   static double lastBalance = -1, lastExternalAssets = EMPTY_VALUE;
   double balance = -1, externalAssets = EMPTY_VALUE;

   if (display.balance) {
      balance = AccountBalance();
      externalAssets = GetExternalBalance();

      if (display.balance!=lastStatus || balance!=lastBalance || (display.externalBalance && externalAssets!=lastExternalAssets)) {
         string sBalance = "";

         if (display.externalBalance) {
            sBalance = "Balance: "+ NumberToStr(balance + externalAssets, ",'.2") +" "+ AccountCurrency() +" ("+ NumberToStr(externalAssets, "+,'.2") +")";
         }
         else {
            sBalance = "Balance: " + NumberToStr(balance, ",'.2") +" "+ AccountCurrency();
         }
         ObjectSetText(label.accountBalance, sBalance, 9, "Tahoma", SlateGray);
         ObjectSet(label.accountBalance, OBJPROP_TIMEFRAMES, OBJ_PERIODS_ALL);
      }
   }
   else if (display.balance != lastStatus) {
      ObjectSet(label.accountBalance, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   }
   lastStatus         = display.balance;
   lastBalance        = balance;
   lastExternalAssets = externalAssets;

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                                     // on ObjectDrag or opened "Properties" dialog
      return(true);
   return(!catch("UpdateAccountBalance(1)", error));
}


/**
 * Update the display indicating an external or remote account.
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
      text = StringConcatenate(tradeAccount.name, ": ", tradeAccount.company, ", ", tradeAccount.number, ", ", tradeAccount.currency);
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

   if (!mode.intern || !totalPosition) {                                               // keine effektive Position im Markt: vorhandene Marker l�schen
      ObjectDelete(label.stopoutLevel);
      int error = GetLastError();
      if (error && error!=ERR_OBJECT_DOES_NOT_EXIST)                                   // on ObjectDrag or opened "Properties" dialog
         return(!catch("UpdateStopoutLevel(1)", error));
      return(true);
   }

   // calculate the stopout level
   double extAssets   = GetExternalBalance();
   double realBalance = AccountBalance(), virtBalance = realBalance + extAssets;
   double realEquity  = AccountEquity();
   double usedMargin  = AccountMargin();
   int    soMode      = AccountStopoutMode();
   double soEquity    = AccountStopoutLevel();  if (soMode != MSM_ABSOLUTE) soEquity *= usedMargin/100;
   double tickSize    = MarketInfoEx(Symbol(), MODE_TICKSIZE, error);
   double tickValue   = MarketInfoEx(Symbol(), MODE_TICKVALUE, error) * MathAbs(totalPosition);
   if (!_Bid || !tickSize || !tickValue) {
      if (!_Bid || error==ERR_SYMBOL_NOT_AVAILABLE)
         return(SetLastError(ERS_TERMINAL_NOT_YET_READY));                             // Symbol noch nicht subscribed (possible on start, change of account/template, offline chart, MarketWatch -> Hide all)
      return(!catch("UpdateStopoutLevel(2)", error));
   }
   double soDistance = (realEquity - soEquity)/tickValue * tickSize;
   if (totalPosition > 0) double soPrice = _Bid - soDistance;
   else                          soPrice = _Ask + soDistance;
   double soDrawdown = MathMax(MathDiv(soEquity + extAssets, virtBalance) - 1, -1);

   // display stopout level
   if (ObjectFind(label.stopoutLevel) == -1) if (!ObjectCreateRegister(label.stopoutLevel, OBJ_HLINE)) return(false);
   ObjectSet(label.stopoutLevel, OBJPROP_STYLE,  STYLE_SOLID);
   ObjectSet(label.stopoutLevel, OBJPROP_COLOR,  OrangeRed);
   ObjectSet(label.stopoutLevel, OBJPROP_BACK,   false);
   ObjectSet(label.stopoutLevel, OBJPROP_PRICE1, soPrice);                             // TODO: fix the drawdown percentage relative to the start balance of the position
   ObjectSetText(label.stopoutLevel, StringConcatenate("Stopout: ", DoubleToStr(100 * soDrawdown, 0), "%"));

   error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                                     // on ObjectDrag or opened "Properties" dialog
      return(true);
   return(!catch("UpdateStopoutLevel(3)", error));
}


/**
 * Resolve the total open position, group/store it according to the custom configuration and calculate PnL stats.
 *
 * @param  int flags [optional] - control flags, supported values:
 *                                F_LOG_TICKETS:           log all tickets of resulting custom positions
 *                                F_LOG_SKIP_EMPTY:        skip empty array elements when logging tickets
 *                                F_SHOW_CUSTOM_POSITIONS: call ShowOpenOrders() for the configured open positions
 *                                F_SHOW_CUSTOM_HISTORY:   call ShowTradeHistory() for the configured history
 * @return bool - success status
 */
 bool AnalyzePositions(int flags = NULL) {                                       // reparse configuration on chart command flags
   if (flags & (F_LOG_TICKETS|F_SHOW_CUSTOM_POSITIONS) != 0) positions.analyzed = false;
   if (mode.extern) positions.analyzed = true;
   if (positions.analyzed) return(true);

   if (mode.intern && !mm.done) {
      if (!CalculateUnitSize()) return(false);
      if (!mm.done)             return(true);                                    // terminal not yet ready
   }

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
      int sortKeys[][2];                                                         // Sortierschl�ssel der offenen Positionen: {OpenTime, Ticket}
      ArrayResize(sortKeys, orders);

      // Sortierschl�ssel auslesen und dabei PnL von LFX-Positionen erfassen (alle Symbole).
      for (int n, i=0; i < orders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;                 // FALSE: an open order was closed/deleted in another thread
         if (OrderType() > OP_SELL) {
            if (!isPendings) /*&&*/ if (OrderSymbol()==Symbol())
               isPendings = true;
            continue;
         }

         // PnL gefundener LFX-Positionen aufaddieren
         while (true) {                                                          // Pseudo-Schleife, dient dem einfacherem Verlassen des Blocks
            if (!lfxOrders.openPositions) break;

            if (LFX.IsMyOrder()) {                                               // Index des Tickets in lfxOrders.iCache[] ermitteln:
               if (OrderMagicNumber() != lfxOrders.iCache[pos][IC.ticket]) {     // Quickcheck mit letztem verwendeten Index, erst danach Vollsuche (schneller)
                  pos = SearchLfxTicket(OrderMagicNumber());                     // (ist lfxOrders.openPositions!=0, mu� nicht auf size(*.iCache)==0 gepr�ft werden)
                  if (pos == -1) {
                     pos = 0;
                     break;
                  }
               }
               if (!lfxProfits) {                                                // Profits in lfxOrders.dCache[] beim ersten Zugriff in lastProfit speichern und zur�cksetzen
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

         sortKeys[n][0] = OrderOpenTime();                                       // Sortierschl�ssel der Tickets auslesen
         sortKeys[n][1] = OrderTicket();
         n++;
      }
      if (lfxProfits) /*&&*/if (!AnalyzePos.ProcessLfxProfits()) return(false);  // PnL gefundener LFX-Positionen verarbeiten

      if (n < orders) ArrayResize(sortKeys, n);
      openPositions = n;

      // offene Positionen sortieren und einlesen
      if (openPositions > 1) /*&&*/ if (!SortOpenTickets(sortKeys)) return(false);

      ArrayResize(tickets,     openPositions);                                   // interne Positionsdetails werden bei jedem Tick zur�ckgesetzt
      ArrayResize(types,       openPositions);
      ArrayResize(lots,        openPositions);
      ArrayResize(openTimes,   openPositions);
      ArrayResize(openPrices,  openPositions);
      ArrayResize(commissions, openPositions);
      ArrayResize(swaps,       openPositions);
      ArrayResize(profits,     openPositions);

      for (i=0; i < openPositions; i++) {
         if (!SelectTicket(sortKeys[i][1], "AnalyzePositions(1)")) return(false);
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

   // results intern + extern
   double prevTotalPosition = totalPosition;
   longPosition      = NormalizeDouble(longPosition,  2);
   shortPosition     = NormalizeDouble(shortPosition, 2);
   totalPosition     = NormalizeDouble(longPosition - shortPosition, 2);
   isPosition        = longPosition || shortPosition;
   isVirtualPosition = false;

   int prevError = last_error;
   SetLastError(NO_ERROR);

   // make sure the configuration of custom positions is parsed
   if (!ArraySize(config.terms)) /*&&*/ if (!CustomPositions.ReadConfig()) {
      positions.analyzed = !last_error;                                          // MarketInfo()-Daten stehen ggf. noch nicht zur Verf�gung,
      if (!last_error) SetLastError(prevError);                                  // in diesem Fall n�chster Versuch beim n�chsten Tick.
      return(positions.analyzed);
   }
   SetLastError(prevError);

   // extract individual tickets/partial positions from all open positions and store it in positions.data[]
   int    line, termType, termsSize = ArrayRange(config.terms, 0);
   double termValue1, termValue2, termResult1, termResult2, customLongPosition, customShortPosition, customTotalPosition, closedProfit=EMPTY_VALUE, adjustedProfit, customEquity, profitMarkerPrice, profitMarkerPct=EMPTY_VALUE, lossMarkerPrice, lossMarkerPct=EMPTY_VALUE, _longPosition=longPosition, _shortPosition=shortPosition, _totalPosition=totalPosition;
   int    customTickets[], customTypes[];
   double customLots[], customOpenPrices[], customCommissions[], customSwaps[], customProfits[];
   bool   lineSkipped, isVirtual;

   ArrayResize(positions.data, 0);
   positions.showMfae = false;                                                   // global flag to control positioning/display width of chart objects

   for (i=0, line=0; i < termsSize; i++) {
      termType    = config.terms[i][I_TERM_TYPE   ];
      termValue1  = config.terms[i][I_TERM_VALUE1 ];
      termValue2  = config.terms[i][I_TERM_VALUE2 ];
      termResult1 = config.terms[i][I_TERM_RESULT1];
      termResult2 = config.terms[i][I_TERM_RESULT2];

      if (!termType) {                                                           // termType NULL => EOL of a config line for costum positions
         if (i == 0) line = -1;                                                  // an empty configuration has no lines
         if (flags & F_LOG_TICKETS != 0) CustomPositions.LogTickets(customTickets, line, flags);
         if (flags & F_SHOW_CUSTOM_POSITIONS && ArraySize(customTickets)) ShowOpenOrders(customTickets);

         // store custom position for display
         if (!StoreCustomPosition(isVirtual, customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLots, customOpenPrices, customCommissions, customSwaps, customProfits, closedProfit, adjustedProfit, customEquity, profitMarkerPrice, profitMarkerPct, lossMarkerPrice, lossMarkerPct, line, lineSkipped)) {
            return(false);
         }

         if (line >= 0) {
            if (lineSkipped) {
               // if the line is skipped we can reset a set MFE/MAE signaling flag
               int hWnd;
               string sEvent = "";
               if (config.dData[line][I_PROFIT_MFE] != 0) {
                  hWnd = ifInt(__isTesting, __ExecutionContext[EC.chart], GetDesktopWindow());
                  sEvent = GetMfaeSignalKey(config.sData[line][I_CONFIG_KEY], I_PROFIT_MFE);
                  SetPropA(hWnd, sEvent, 0);
               }
               if (config.dData[line][I_PROFIT_MAE] != 0) {
                  hWnd = ifInt(__isTesting, __ExecutionContext[EC.chart], GetDesktopWindow());
                  sEvent = GetMfaeSignalKey(config.sData[line][I_CONFIG_KEY], I_PROFIT_MAE);
                  SetPropA(hWnd, sEvent, 0);
               }

               // reset existing stats
               config.dData[line][I_PROFIT_MFE] = 0;
               config.dData[line][I_PROFIT_MAE] = 0;
               config.dData[line][I_MAX_LOTS  ] = 0;
               config.dData[line][I_MAX_RISK  ] = 0;
            }
            else {
               positions.showMfae = positions.showMfae || config.dData[line][I_MFAE_ENABLED];

               // track the first (top-most) virtual position
               if (!isVirtualPosition && isVirtual && (customLongPosition || customShortPosition)) {
                  isVirtualPosition    = true;
                  virtualTotalPosition = customTotalPosition;
                  virtualLongPosition  = customLongPosition;
                  virtualShortPosition = customShortPosition;
               }
            }
         }

         isVirtual           = false;
         customLongPosition  = 0;
         customShortPosition = 0;
         customTotalPosition = 0;
         closedProfit        = EMPTY_VALUE;
         adjustedProfit      = 0;
         customEquity        = 0;
         profitMarkerPrice   = 0;
         profitMarkerPct     = EMPTY_VALUE;
         lossMarkerPrice     = 0;
         lossMarkerPct       = EMPTY_VALUE;
         ArrayResize(customTickets,     0);
         ArrayResize(customTypes,       0);
         ArrayResize(customLots,        0);
         ArrayResize(customOpenPrices,  0);
         ArrayResize(customCommissions, 0);
         ArrayResize(customSwaps,       0);
         ArrayResize(customProfits,     0);
         line++;
         continue;
      }

      // extract individual tickets/partial positions
      if (!ExtractPosition(termType, termValue1, termValue2, termResult1, termResult2,
                           _longPosition,      _shortPosition,      _totalPosition,      tickets,       types,       lots, openTimes, openPrices,       commissions,       swaps,       profits,
                           customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLots,      customOpenPrices, customCommissions, customSwaps, customProfits, closedProfit, adjustedProfit, customEquity, profitMarkerPrice, profitMarkerPct, lossMarkerPrice, lossMarkerPct,
                           isVirtual, flags)) {
         return(false);
      }
      config.terms[i][I_TERM_RESULT1] = termResult1;
      config.terms[i][I_TERM_RESULT2] = termResult2;
   }

   // handle a remaining open position as implicit last config entry (not covered by any previous configuration)
   line = -1;
   if (flags & F_LOG_TICKETS != 0) CustomPositions.LogTickets(tickets, line, flags);

   if (!StoreCustomPosition(false, _longPosition, _shortPosition, _totalPosition, tickets, types, lots, openPrices, commissions, swaps, profits, EMPTY_VALUE, NULL, NULL, NULL, EMPTY_VALUE, NULL, EMPTY_VALUE, line, lineSkipped)) {
      return(false);
   }
   positions.analyzed = true;
   return(!catch("AnalyzePositions(3)"));
}


/**
 * Log tickets of custom positions.
 *
 * @param  int tickets[]
 * @param  int configLine       - config line index
 * @param  int flags [optional] - control flags, supported values:
 *                                F_LOG_SKIP_EMPTY: skip empty array elements when logging tickets
 * @return bool - success status
 */
bool CustomPositions.LogTickets(int tickets[], int configLine, int flags = NULL) {
   int copy[]; ArrayResize(copy, 0);
   if (ArraySize(tickets) > 0) {
      ArrayCopy(copy, tickets);
      if (flags & F_LOG_SKIP_EMPTY != 0) ArrayDropInt(copy, 0);
   }

   if (ArraySize(copy) > 0) {
      string sLine="-", sComment="";

      if (configLine > -1) {
         sLine = configLine;
         if (StringLen(config.sData[configLine][I_CONFIG_COMMENT]) > 0) {
            sComment = "\""+ config.sData[configLine][I_CONFIG_COMMENT] +"\" = ";
         }
      }

      string sPosition = TicketsToStr.Position(copy);
      sPosition = ifString(sPosition=="0 lot", "", sPosition +" = ");
      string sTickets = TicketsToStr.Lots(copy, NULL);

      debug("LogTickets(1)  conf("+ sLine +"): "+ sComment + sPosition + sTickets);
   }
   return(!catch("CustomPositions.LogTickets(2)"));
}


/**
 * Calculate the unitsize according to the configuration. Calculation is risk-based and/or leverage-based.
 *
 *  Default configuration
 *  [Unitsize]
 *  RiskRange   = (<numeric> [pip] | ADR)                ; range for risk calculation: absolute value or "ADR" = ADR(20)
 *  RiskPercent = <numeric>                              ; max. risked percent per RiskRange and unit (0: no restriction)
 *  Leverage    = <numeric>                              ; max. leverage per unit (0: no restriction)
 *
 *  Symbol-specific configuration (merged with defaults)
 *  [Unitsize]
 *  GBPUSD.RiskPercent = <numeric>
 *  EURUSD.Leverage    = <numeric>
 *
 * Symbol-specific settings take precedence over default settings. If multiple settings are found for the same standard
 * symbol (e.g. "EURUSDm.Leverage" and "EURUSD.Leverage"), the broker-specific settings take precedence.
 *
 * @return bool - success status
 */
bool CalculateUnitSize() {
   if (mm.done) return(true);

   // see global vars for descriptions
   mm.externalAssets          = GetExternalBalance();
   mm.lotValue                = 0;
   mm.unleveragedLots         = 0;
   mm.leveragedLots           = 0;
   mm.leveragedLotsNormalized = 0;
   mm.leveragePerUnit         = 0;

   if (mode.extern) return(true);                                       // skip everything else for external accounts

   // recalculate available equity
   double equity = AccountEquity() - AccountCredit();
   if (AccountBalance() > 0.005) equity = MathMin(AccountBalance(), equity);
   if (equity < 0.005)    return(true);                                 // account empty or terminal not yet ready
   mm.equity = equity + mm.externalAssets;
   if (mm.equity < 0.005) return(true);                                 // if negative external assets are too large (for scaling down purposes)

   // recalculate lot value and unleveraged unitsize
   int error;
   double tickSize = MarketInfoEx(Symbol(), MODE_TICKSIZE, error);
   double tickValue = MarketInfoEx(Symbol(), MODE_TICKVALUE, error);    // don't log ERR_SYMBOL_NOT_AVAILABLE
   if (!Close[0] || !tickSize || !tickValue) {                          // may happen on terminal start, on account/template change, in offline charts
      if (!error || error==ERR_SYMBOL_NOT_AVAILABLE) return(SetLastError(ERS_TERMINAL_NOT_YET_READY));
      return(!catch("CalculateUnitSize(1)", error));
   }
   mm.lotValue        = Close[0]/tickSize * tickValue;                  // value of 1 lot in account currency
   mm.unleveragedLots = mm.equity/mm.lotValue;                          // unleveraged unitsize

   // ensure a valid unitsize configuration
   if (!mm.cfgIsValid) {
      if (!ReadUnitSizeConfiguration()) return(last_error == ERS_TERMINAL_NOT_YET_READY);
   }

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
      mm.leveragePerUnit  = mm.leveragedLots/mm.unleveragedLots;        // resulting leverage per unit
      mm.usesLeverage     = false;
   }

   if (mm.cfgLeverage != NULL) {
      if (!mm.leveragePerUnit || mm.leveragePerUnit > mm.cfgLeverage) { // if both risk and leverage are configured the smaller result of both calculations is used
         mm.leveragePerUnit = mm.cfgLeverage;
         mm.leveragedLots   = mm.unleveragedLots * mm.leveragePerUnit;  // resulting unitsize
         mm.usesLeverage    = true;
      }
   }

   // normalize the result to a sound value
   if (mm.leveragedLots > 0) {                                                                                                                  // max. 6.7% per step
      if      (mm.leveragedLots <=    0.03) mm.leveragedLotsNormalized = NormalizeDouble(MathRound(mm.leveragedLots/  0.001) *   0.001, 3);     //     0-0.03: multiple of   0.001
      else if (mm.leveragedLots <=   0.075) mm.leveragedLotsNormalized = NormalizeDouble(MathRound(mm.leveragedLots/  0.002) *   0.002, 3);     // 0.03-0.075: multiple of   0.002
      else if (mm.leveragedLots <=    0.1 ) mm.leveragedLotsNormalized = NormalizeDouble(MathRound(mm.leveragedLots/  0.005) *   0.005, 3);     //  0.075-0.1: multiple of   0.005
      else if (mm.leveragedLots <=    0.3 ) mm.leveragedLotsNormalized = NormalizeDouble(MathRound(mm.leveragedLots/  0.01 ) *   0.01,  2);     //    0.1-0.3: multiple of   0.01
      else if (mm.leveragedLots <=    0.75) mm.leveragedLotsNormalized = NormalizeDouble(MathRound(mm.leveragedLots/  0.02 ) *   0.02,  2);     //   0.3-0.75: multiple of   0.02
      else if (mm.leveragedLots <=    1.2 ) mm.leveragedLotsNormalized = NormalizeDouble(MathRound(mm.leveragedLots/  0.05 ) *   0.05,  2);     //   0.75-1.2: multiple of   0.05
      else if (mm.leveragedLots <=   10.  ) mm.leveragedLotsNormalized = NormalizeDouble(MathRound(mm.leveragedLots/  0.1  ) *   0.1,   1);     //     1.2-10: multiple of   0.1
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
 * Read the unitsize configuration.
 *
 * @return bool - success status
 */
bool ReadUnitSizeConfiguration() {
   string sValue = "";
   if (!ReadUnitSizeConfigValue("Leverage",    sValue)) return(false); mm.cfgLeverage    = StrToDouble(sValue);
   if (!ReadUnitSizeConfigValue("RiskPercent", sValue)) return(false); mm.cfgRiskPercent = StrToDouble(sValue);
   if (!ReadUnitSizeConfigValue("RiskRange",   sValue)) return(false); mm.cfgRiskRange   = StrToDouble(sValue);
   mm.cfgRiskRangeIsADR = StrCompareI(sValue, "ADR");

   mm.cfgIsValid = true;
   return(!catch("ReadUnitSizeConfiguration(1)"));
}


/**
 * Find the applicable configuration value for the unitsize calculation.
 *
 * @param _In_  string key    - unitsize configuration identifier
 * @param _Out_ string &value - configuration value
 *
 * @return bool - success status
 */
bool ReadUnitSizeConfigValue(string key, string &value) {
   string section="Unitsize", sValue="";
   value = "";

   string iniKey = Symbol() +"."+ key;
   if (IsConfigKey(section, iniKey)) {
      if (!ValidateUnitSizeConfigValue(section, iniKey, sValue)) return(false);
      value = sValue;
      return(true);
   }

   iniKey = StdSymbol() +"."+ key;
   if (IsConfigKey(section, iniKey)) {
      if (!ValidateUnitSizeConfigValue(section, iniKey, sValue)) return(false);
      value = sValue;
      return(true);
   }

   iniKey = key;
   if (IsConfigKey(section, iniKey)) {
      if (!ValidateUnitSizeConfigValue(section, iniKey, sValue)) return(false);
      value = sValue;
      return(true);
   }
   return(true);           // success also if no configuration was found (returns an empty string)
}


/**
 * Validate the passed unitsize configuration value.
 *
 * @param _In_  string section - configuration section
 * @param _In_  string key     - configuration key
 * @param _Out_ string &value  - configuration value
 *
 * @return bool - success status
 */
bool ValidateUnitSizeConfigValue(string section, string key, string &value) {
   string sValue = GetConfigString(section, key), sValueBak = sValue;

   if (StrEndsWithI(key, "RiskPercent") || StrEndsWithI(key, "Leverage")) {
      if (!StrIsNumeric(sValue))    return(!catch("ValidateUnitSizeConfigValue(1)  invalid configuration value ["+ section +"]->"+ key +": \""+ sValueBak +"\" (non-numeric)", ERR_INVALID_CONFIG_VALUE));
      double dValue = StrToDouble(sValue);
      if (dValue < 0)               return(!catch("ValidateUnitSizeConfigValue(2)  invalid configuration value ["+ section +"]->"+ key +": "+ sValueBak +" (non-positive)", ERR_INVALID_CONFIG_VALUE));
      value = sValue;
      return(true);
   }

   if (StrEndsWithI(key, "RiskRange")) {
      if (StrCompareI(sValue, "ADR")) {
         value = sValue;
         return(true);
      }
      if (!StrEndsWith(sValue, "pip")) {
         if (!StrIsNumeric(sValue)) return(!catch("ValidateUnitSizeConfigValue(3)  invalid configuration value ["+ section +"]->"+ key +": \""+ sValueBak +"\" (non-numeric)", ERR_INVALID_CONFIG_VALUE));
         dValue = StrToDouble(sValue);
         if (dValue < 0)            return(!catch("ValidateUnitSizeConfigValue(4)  invalid configuration value ["+ section +"]->"+ key +": "+ sValueBak +" (non-positive)", ERR_INVALID_CONFIG_VALUE));
         value = sValue;
         return(true);
      }
      sValue = StrTrim(StrLeft(sValue, -3));
      if (!StrIsNumeric(sValue))    return(!catch("ValidateUnitSizeConfigValue(5)  invalid configuration value ["+ section +"]->"+ key +": \""+ sValueBak +"\" (non-numeric pip value)", ERR_INVALID_CONFIG_VALUE));
      dValue = StrToDouble(sValue);
      if (dValue < 0)               return(!catch("ValidateUnitSizeConfigValue(6)  invalid configuration value ["+ section +"]->"+ key +": "+ sValueBak +" (non-positive)", ERR_INVALID_CONFIG_VALUE));
      value = dValue * Pip;
      return(true);
   }

   return(!catch("ValidateUnitSizeConfigValue(7)  unsupported [UnitSize] config key: \""+ key +"\"", ERR_INVALID_PARAMETER));
}


/**
 * Resolve and cache the amount of externally hold assets.
 *
 * @return double - asset value in account currency or EMPTY_VALUE in case of errors
 */
double GetExternalBalance() {
   static string lastCompany = "";
   static int    lastAccount = 0;
   static double lastAssets = 0;

   if (!mm.externalAssetsCached || tradeAccount.company!=lastCompany || tradeAccount.number!=lastAccount) {
      double assets = GetExternalAssets(tradeAccount.company, tradeAccount.number);
      if (IsEmptyValue(assets)) return(EMPTY_VALUE);

      lastCompany = tradeAccount.company;
      lastAccount = tradeAccount.number;
      lastAssets  = assets;
      mm.externalAssetsCached = true;
   }
   return(lastAssets);
}


/**
 * Durchsucht das globale Cache-Array lfxOrders.iCache[] nach dem �bergebenen Ticket.
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
 * Read and parse the configuration of custom positions, and store it in a binary format.
 *
 * @return bool - success status
 *
 * Fills config.sData[], config.dData[] und config.terms[] with parsed configuration data of the current chart symbol. On return
 * config.terms[] holds elements {type, value1, value2, value3, value4}. An empty element (all fields NULL) marks the end of a
 * configuration line and also an empty configuration. On return config.terms[] is never empty and holds at least one EOL marker.
 *
 * +-------------------------------------------------+--------------------------------------------------------------------------+--------------------------------------------------------------------+
 * | Syntax                                          | Description                                                              | Content of config.terms[][] (7)                                    |
 * +-------------------------------------------------+--------------------------------------------------------------------------+--------------------------------------------------------------------+
 * |    #123456                                      | complete unprocessed ticket or remainder of processed ticket             | [TERM_TICKET,        123456,           EMPTY,            ..., ...] |
 * | 0.1#123456                                      | O.1 lot of a ticket (1)                                                  | [TERM_TICKET,        123456,           0.1,              ..., ...] |
 * |    L                                            | w/o lotsize: all remaining long positions                                | [TERM_OPEN_LONG,     EMPTY,            ...,              ..., ...] |
 * |    S                                            | w/o lotsize: all remaining short positions                               | [TERM_OPEN_SHORT,    EMPTY,            ...,              ..., ...] |
 * | 0.2L                                            | with lotsize: virtual long position at current price (2)                 | [TERM_OPEN_LONG,     0.2,              NULL,             ..., ...] |
 * | 0.3S[@]1.2345                                   | with lotsize: virtual short position at specified price (2)              | [TERM_OPEN_SHORT,    0.3,              1.2345,           ..., ...] |
 * | O{DateTime}                                     | current symbol: all positions opened in a standard time period (3)       | [TERM_OPEN,          2014.01.01 00:00, 2014.12.31 23:59, ..., ...] |
 * | O{DateTime}-{DateTime}                          | current symbol: all positions opened in the specified time period (3)(4) | [TERM_OPEN,          2014.02.01 08:00, 2014.02.10 18:00, ..., ...] |
 * | H{DateTime}             [Monthly|Weekly|Daily]  | current symbol: all trades closed in a standard time period (3)(5)       | [TERM_HISTORY,       2014.01.01 00:00, 2014.12.31 23:59, ..., ...] |
 * | HT{DateTime}-{DateTime} [Monthly|Weekly|Daily]  | all symbols: all trades closed in the specified time period (3)(4)(5)    | [TERM_HISTORY_TOTAL, 2014.02.01 08:00, 2014.02.10 18:00, ..., ...] |
 * | 12.34                                           | PnL amount to add to a custom position                                   | [TERM_ADJUSTMENT,    12.34,            ...,              ..., ...] |
 * | E=123.00                                        | equity value to use                                                      | [TERM_EQUITY,        123.00,           ...,              ..., ...] |
 * | PM=1.2345                                       | draw a profit marker and calculate % PnL at the specified price          | [TERM_PROFIT_MARKER, 1.2345,           ...,              ..., ...] |
 * | PM=3%                                           | calculate price of the specified % PnL and draw a profit marker          | [TERM_PROFIT_MARKER, ...,              3.0,              ..., ...] |
 * | LM=2.3456                                       | draw a loss marker and calculate % PnL at the specified price            | [TERM_LOSS_MARKER,   2.3456,           ...,              ..., ...] |
 * | LM=-5%                                          | calculate price of the specified %PnL and draw a loss marker             | [TERM_LOSS_MARKER,   ...,              -5.0,             ..., ...] |
 * +-------------------------------------------------+--------------------------------------------------------------------------+--------------------------------------------------------------------+
 * | MFE                                             | track MFE/MAE                                                            | TERM_MFAE, stored in config.dData[]                                |
 * | MFE[-MS]                                        | track MFE/MAE + flags: M - mark level, S - signal new high/low           | TERM_MFAE + flags, stored in config.dData[]                        |
 * +-------------------------------------------------+--------------------------------------------------------------------------+--------------------------------------------------------------------+
 * | any text after a semicolon ";" aka .ini comment | displayed as position description                                        | stored in config.sData[]                                           |
 * | any text after a 2nd semicolon ";...;"          | configuration comment, ignored                                           |                                                                    |
 * +-------------------------------------------------+--------------------------------------------------------------------------+--------------------------------------------------------------------+
 *
 *  Example configuration (6)
 *  -------------------------
 *  [CustomPositions]
 *  GBPAUD.a = #111111, 0.1#222222                    // full ticket #111111, plus 0.1 lot of ticket #222222
 *  GBPAUD.b = 0.2L@1.6500, #222222                   // virtual long position of 0.2 lot at 1.6500, plus remainder of #222222 (2)
 *  GBPAUD.c = L, S, -34.56, LM=-3%                   // all remaining positions incl. remainder of #222222, plus loss of -34.56, loss marker at PL=-3%
 *  GBPAUD.d = 0.3S                                   // virtual short position of 0.3 lot at current price
 *
 *
 *  Resulting array config.terms[] for the above example (7)
 *  --------------------------------------------------------
 *  double config.terms = [
 *     [TERM_TICKET,      111111, EMPTY, ..., ...],
 *     [TERM_TICKET,      222222, 0.1,   ..., ...],
 *     [NULL,             ...,    ...,   ..., ...],   // EOL marker of line GBPAUD.a
 *
 *     [TERM_OPEN_LONG,   0.2,    NULL,  ..., ...],
 *     [TERM_TICKET,      222222, EMPTY, ..., ...],
 *     [NULL,             ...,    ...,   ..., ...],   // EOL marker of line GBPAUD.b
 *
 *     [TERM_OPEN_LONG,   EMPTY,  ...,   ..., ...],
 *     [TERM_OPEN_SHORT,  EMPTY,  ...,   ..., ...],
 *     [TERM_ADJUSTMENT,  -34.45, ...,   ..., ...],
 *     [TERM_LOSS_MARKER, ...,    -3.0,  ..., ...],
 *     [NULL,             ...,    ...,   ..., ...],   // EOL marker of line GBPAUD.c
 *
 *     [TERM_OPEN_SHORT,  0.3,    NULL,  ..., ...],
 *     [NULL,             ...,    ...,   ..., ...],   // EOL marker of line GBPAUD.d
 *  ];
 *
 *
 *  (1) Bei einer Lotsize von 0 wird die Teilposition ignoriert.
 *  (2) Werden reale mit virtuellen Positionen kombiniert, wird die gesamte Position virtuell und nicht von der aktuellen Gesamtposition abgezogen.
 *      Dies kann in Verbindung mit (1) benutzt werden, um eine virtuelle Position zu konfigurieren, die die folgenden Positionen nicht
 *      beeinflu�t (z.B. durch "0L").
 *  (3) Zeitangaben im Format: 2014[.01[.15 [W|12:30[:45]]]]
 *  (4) Einer der beiden Zeitpunkte kann leer sein und steht jeweils f�r "von Beginn" oder "bis Ende".
 *  (5) Ein Historyzeitraum kann tages-, wochen- oder monatsweise gruppiert werden, solange er nicht mit anderen Positionen kombiniert wird.
 *  (6) Die Positionen werden unabh�ngig von den Schl�sseln in der Reihenfolge ihrer Notierung angezeigt.
 *  (7) "..." denotes fields not used by the term
 */
bool CustomPositions.ReadConfig() {
   double confTerms[][5]; ArrayResize(confTerms, 0); if (ArrayRange(confTerms, 1) != ArrayRange(config.terms, 1)) return(!catch("CustomPositions.ReadConfig(1)  array mis-match config.terms[] / confTerms[]", ERR_INCOMPATIBLE_ARRAY));
   string confsData[][2]; ArrayResize(confsData, 0); if (ArrayRange(confsData, 1) != ArrayRange(config.sData, 1)) return(!catch("CustomPositions.ReadConfig(2)  array mis-match config.sData[] / confsData[]", ERR_INCOMPATIBLE_ARRAY));
   double confdData[][8]; ArrayResize(confdData, 0); if (ArrayRange(confdData, 1) != ArrayRange(config.dData, 1)) return(!catch("CustomPositions.ReadConfig(3)  array mis-match config.dData[] / confdData[]", ERR_INCOMPATIBLE_ARRAY));

   // parse configuration
   string   keys[], values[], iniValue="", sValue="", comment="", confComment="", openComment="", hstComment="", sNull, symbol=Symbol(), stdSymbol=StdSymbol();
   double   termType, termValue1, termValue2, termResult1, termResult2, dValue, lotSize, minLotSize=MarketInfo(symbol, MODE_MINLOT), lotStep=MarketInfo(symbol, MODE_LOTSTEP);
   int      valuesSize, termsSize, pos, len, ticket, nextPositionStartOffset;
   datetime from, to;
   bool     isEmptyPosition, isVirtualPosition, isGroupedPosition, containsEquityValue, containsProfitMarker, containsLossMarker, isBemEnabled, isMfaeEnabled, isMfaeSignal, markMfe, isTotal, isPercent;

   if (!minLotSize || !lotStep) return(false);                       // falls MarketInfo()-Daten noch nicht verf�gbar sind
   if (mode.extern)             return(!catch("CustomPositions.ReadConfig(4)  feature for mode.extern=true not yet implemented", ERR_NOT_IMPLEMENTED));

   string file     = GetAccountConfigPath(tradeAccount.company, tradeAccount.number); if (!StringLen(file)) return(false);
   string section  = "CustomPositions";
   int    keysSize = GetIniKeys(file, section, keys);

   for (int i=0; i < keysSize; i++) {
      if (StrStartsWithI(keys[i], symbol) || StrStartsWithI(keys[i], stdSymbol)) {
         if (SearchStringArrayI(keys, keys[i]) == i) {               // bei gleichnamigen Schl�sseln wird nur der erste verarbeitet
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
               if (StrStartsWith(confComment, "\"") && StrEndsWith(confComment, "\"")) // f�hrende und schlie�ende Anf�hrungszeichen entfernen
                  confComment = StrSubstr(confComment, 1, StringLen(confComment)-2);
            }

            // now parse the configuration terms
            isEmptyPosition      = true;                             // whether the position entry holds trade data (not only flags=MFA/MAE/BE)
            isVirtualPosition    = false;                            // whether the position entry is virtual
            isGroupedPosition    = false;                            // whether the position entry is grouped
            containsEquityValue  = false;                            // whether the position entry contains a custom equity value
            containsProfitMarker = false;                            // whether the position entry contains a TP marker
            containsLossMarker   = false;                            // whether the position entry contains a SL marker
            isBemEnabled         = false;                            // whether to display the BE marker for the position
            isMfaeEnabled        = false;                            // whether to enable the MFE/MAE tracker for the position
            isMfaeSignal         = false;                            // whether the MFE/MAE tracker signals new highs/lows
            markMfe              = false;                            // whether to visualize the MFE level
            valuesSize           = Explode(StrToUpper(iniValue), ",", values, NULL);

            for (int n=0; n < valuesSize; n++) {
               values[n] = StrTrim(values[n]);
               if (!StringLen(values[n])) continue;                  // empty string

               if (StrStartsWith(values[n], "BEM")) {                // flag: display BE marker
                  if (values[n] != "BEM")                            return(!catch("CustomPositions.ReadConfig(5)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  isBemEnabled = true;
                  continue;
               }
               if (StrStartsWith(values[n], "MFE")) {                // flag: enable MFE/MAE tracker
                  sValue = values[n];
                  if (sValue != "MFE") {
                     sValue = StrSubstr(sValue, 3);
                     if (!StrStartsWith(sValue, "-"))                return(!catch("CustomPositions.ReadConfig(6)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                     sValue = StrSubstr(sValue, 1);
                     len = StringLen(sValue);
                     if (len > 2)                                    return(!catch("CustomPositions.ReadConfig(7)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                     while (len > 0) {
                        len--;
                        switch (StringGetChar(sValue, len)) {
                           case 'M': markMfe = true;      break;     // flag: mark MFE level
                           case 'S': isMfaeSignal = true; break;     // flag: signal new MFE/MAE
                           default:                                  return(!catch("CustomPositions.ReadConfig(8)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                        }
                     }
                  }
                  isMfaeEnabled = true;
                  continue;
               }

               if (StrStartsWith(values[n], "#")) {                  // ticket: #123456
                  sValue = StrTrim(StrSubstr(values[n], 1));
                  if (!StrIsDigits(sValue))                          return(!catch("CustomPositions.ReadConfig(9)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-digits in ticket \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termType    = TERM_TICKET;
                  termValue1  = StrToInteger(sValue);
                  termValue2  = EMPTY;                               // all remaining lots
                  termResult1 = NULL;
                  termResult2 = NULL;
               }

               else if (StrContains(values[n], "#")) {               // partial ticket: 0.1#123456
                  pos = StringFind(values[n], "#");
                  sValue = StrTrim(StrLeft(values[n], pos));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(10)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termType   = TERM_TICKET;
                  termValue2 = StrToDouble(sValue);
                  if (termValue2 && LT(termValue2, minLotSize))      return(!catch("CustomPositions.ReadConfig(11)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (lot size smaller than MIN_LOTSIZE \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  if (MathModFix(termValue2, lotStep) != 0)          return(!catch("CustomPositions.ReadConfig(12)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (lot size not a multiple of LOTSTEP \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  sValue = StrTrim(StrSubstr(values[n], pos+1));
                  if (!StrIsDigits(sValue))                          return(!catch("CustomPositions.ReadConfig(13)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-digits in ticket \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue1  = StrToInteger(sValue);
                  termResult1 = NULL;
                  termResult2 = NULL;
               }

               else if (StrStartsWith(values[n], "H")) {             // H[T] = History[Total]
                  if (!CustomPositions.ParseHstTerm(values[n], confComment, hstComment, isEmptyPosition, isGroupedPosition, isTotal, from, to, confTerms, confsData, confdData)) return(false);
                  if (isGroupedPosition) {
                     isEmptyPosition = false;
                     continue;                                       // gruppiert: die Konfiguration wurde bereits in CustomPositions.ParseHstTerm() gespeichert
                  }
                  termType    = ifInt(!isTotal, TERM_HISTORY, TERM_HISTORY_TOTAL);
                  termValue1  = from;                                // nicht gruppiert
                  termValue2  = to;
                  termResult1 = EMPTY_VALUE;                         // EMPTY_VALUE, da NULL bei TERM_HISTORY_* ein g�ltiger Wert ist
                  termResult2 = EMPTY_VALUE;
               }

               else if (StrStartsWith(values[n], "E=")) {            // equity value: E=123.56
                  sValue = StrTrimLeft(StrSubstr(values[n], 2));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(14)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric value in equity term \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termType   = TERM_EQUITY;
                  termValue1 = StrToDouble(sValue);
                  if (termValue1 <= 0)                               return(!catch("CustomPositions.ReadConfig(15)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal value in equity term \""+ values[n] +"\", must be > 0) in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2  = NULL;
                  termResult1 = NULL;
                  termResult2 = NULL;
                  if (containsEquityValue)                           return(!catch("CustomPositions.ReadConfig(16)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (multiple equity terms \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  containsEquityValue = true;
               }

               else if (StrStartsWith(values[n], "PM")) {            // profit marker: PM=3.0[%]
                  sValue = StrTrim(StrSubstr(values[n], 2));
                  if (!StrStartsWith(sValue, "="))                   return(!catch("CustomPositions.ReadConfig(17)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (missing = in PM term \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  sValue = StrTrim(StrSubstr(sValue, 1));
                  isPercent = StrEndsWith(sValue, "%");
                  if (isPercent) sValue = StrTrim(StrLeft(sValue, -1));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(18)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric value in PM term \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  dValue = StrToDouble(sValue);
                  termType   = TERM_PROFIT_MARKER;
                  termValue1 = ifDouble(isPercent, NULL, NormalizeDouble(dValue, Digits));
                  if (!isPercent && termValue1 <= 0)                 return(!catch("CustomPositions.ReadConfig(19)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal value in PM term \""+ values[n] +"\", must be > 0) in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = ifDouble(isPercent, dValue, NULL);
                  if (isPercent && termValue2 <= -100)               return(!catch("CustomPositions.ReadConfig(20)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal value in PM term \""+ values[n] +"\", must be > -100) in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termResult1 = NULL;
                  termResult2 = NULL;
                  if (containsProfitMarker)                          return(!catch("CustomPositions.ReadConfig(21)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (multiple PM terms \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  containsProfitMarker = true;
               }

               else if (StrStartsWith(values[n], "LM")) {            // loss marker: LM=-5.0[%]
                  sValue = StrTrim(StrSubstr(values[n], 2));
                  if (!StrStartsWith(sValue, "="))                   return(!catch("CustomPositions.ReadConfig(22)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (missing = in LM term \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  sValue = StrTrim(StrSubstr(sValue, 1));
                  isPercent = StrEndsWith(sValue, "%");
                  if (isPercent) sValue = StrTrim(StrLeft(sValue, -1));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(23)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric value in LM term \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  dValue = StrToDouble(sValue);
                  termType   = TERM_LOSS_MARKER;
                  termValue1 = ifDouble(isPercent, NULL, NormalizeDouble(dValue, Digits));
                  if (!isPercent && termValue1 <= 0)                 return(!catch("CustomPositions.ReadConfig(24)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal value in LM term \""+ values[n] +"\", must be > 0) in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = ifDouble(isPercent, dValue, NULL);
                  if (isPercent && termValue2 <= -100)               return(!catch("CustomPositions.ReadConfig(25)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal value in LM term \""+ values[n] +"\", must be > -100) in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termResult1 = NULL;
                  termResult2 = NULL;
                  if (containsLossMarker)                            return(!catch("CustomPositions.ReadConfig(26)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (multiple LM terms \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  containsLossMarker = true;
               }

               else if (StrStartsWith(values[n], "L")) {             // alle verbleibenden Long-Positionen
                  if (values[n] != "L")                              return(!catch("CustomPositions.ReadConfig(27)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termType    = TERM_OPEN_LONG;
                  termValue1  = EMPTY;
                  termValue2  = NULL;
                  termResult1 = NULL;
                  termResult2 = NULL;
               }

               else if (StrStartsWith(values[n], "S")) {             // alle verbleibenden Short-Positionen
                  if (values[n] != "S")                              return(!catch("CustomPositions.ReadConfig(28)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termType    = TERM_OPEN_SHORT;
                  termValue1  = EMPTY;
                  termValue2  = NULL;
                  termResult1 = NULL;
                  termResult2 = NULL;
               }

               else if (StrStartsWith(values[n], "O")) {             // O = die verbleibenden Positionen eines Zeitraums
                  if (!CustomPositions.ParseOpenTerm(values[n], openComment, from, to)) return(false);
                  termType    = TERM_OPEN;                           // intentionally TERM_OPEN_TOTAL is not implemented
                  termValue1  = from;
                  termValue2  = to;
                  termResult1 = NULL;
                  termResult2 = NULL;
               }

               else if (StrIsNumeric(values[n])) {                   // PnL adjustment
                  termType    = TERM_PL_ADJUSTMENT;
                  termValue1  = StrToDouble(values[n]);
                  termValue2  = NULL;
                  termResult1 = NULL;
                  termResult2 = NULL;
               }

               else if (StrEndsWith(values[n], "L")) {               // virtuelle Longposition zum aktuellen Preis
                  termType = TERM_OPEN_LONG;
                  sValue   = StrTrim(StrLeft(values[n], -1));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(29)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue1 = StrToDouble(sValue);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(30)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(31)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2  = NULL;
                  termResult1 = NULL;
                  termResult2 = NULL;
               }

               else if (StrEndsWith(values[n], "S")) {               // virtuelle Shortposition zum aktuellen Preis
                  termType = TERM_OPEN_SHORT;
                  sValue   = StrTrim(StrLeft(values[n], -1));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(32)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue1 = StrToDouble(sValue);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(33)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(34)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2  = NULL;
                  termResult1 = NULL;
                  termResult2 = NULL;
               }

               else if (StrContains(values[n], "L")) {               // virtuelle Longposition zum angegebenen Preis
                  termType = TERM_OPEN_LONG;
                  pos = StringFind(values[n], "L");
                  sValue = StrTrim(StrLeft(values[n], pos));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(35)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue1 = StrToDouble(sValue);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(36)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(37)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  sValue = StrTrim(StrSubstr(values[n], pos+1));
                  if (StrStartsWith(sValue, "@"))
                     sValue = StrTrim(StrSubstr(sValue, 1));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(38)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = StrToDouble(sValue);
                  if (termValue2 <= 0)                               return(!catch("CustomPositions.ReadConfig(39)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termResult1 = NULL;
                  termResult2 = NULL;
               }

               else if (StrContains(values[n], "S")) {               // virtuelle Shortposition zum angegebenen Preis
                  termType = TERM_OPEN_SHORT;
                  pos = StringFind(values[n], "S");
                  sValue = StrTrim(StrLeft(values[n], pos));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(40)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue1 = StrToDouble(sValue);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(41)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(42)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  sValue = StrTrim(StrSubstr(values[n], pos+1));
                  if (StrStartsWith(sValue, "@"))
                     sValue = StrTrim(StrSubstr(sValue, 1));
                  if (!StrIsNumeric(sValue))                         return(!catch("CustomPositions.ReadConfig(43)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = StrToDouble(sValue);
                  if (termValue2 <= 0)                               return(!catch("CustomPositions.ReadConfig(44)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termResult1 = NULL;
                  termResult2 = NULL;
               }
               else                                                  return(!catch("CustomPositions.ReadConfig(45)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));

               // Eine gruppierte Trade-History kann nicht mit anderen Termen kombiniert werden
               if (isGroupedPosition && termType!=TERM_EQUITY)       return(!catch("CustomPositions.ReadConfig(46)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (cannot combine grouped trade history with other entries) in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));

               // Die Konfiguration virtueller Positionen mu� mit einem virtuellen Term beginnen, damit die realen Lots nicht um die virtuellen Lots reduziert werden, siehe (2).
               if ((termType==TERM_OPEN_LONG || termType==TERM_OPEN_SHORT) && termValue1!=EMPTY) {
                  if (!isEmptyPosition && !isVirtualPosition) {
                     double dTmp[] = {TERM_OPEN_LONG, 0, NULL, NULL, NULL};    // am Anfang der Zeile virtuellen 0-Term einf�gen: 0L
                     ArrayInsertDoubleArray(confTerms, nextPositionStartOffset, dTmp);
                  }
                  isVirtualPosition = true;
               }
               isEmptyPosition = false;

               // Konfigurations-Term speichern
               termsSize = ArrayRange(confTerms, 0);
               ArrayResize(confTerms, termsSize+1);
               confTerms[termsSize][I_TERM_TYPE   ] = termType;
               confTerms[termsSize][I_TERM_VALUE1 ] = termValue1;
               confTerms[termsSize][I_TERM_VALUE2 ] = termValue2;
               confTerms[termsSize][I_TERM_RESULT1] = termResult1;
               confTerms[termsSize][I_TERM_RESULT2] = termResult2;
            }

            if (!isEmptyPosition) {                                  // Zeile mit Leer-Term abschlie�en (markiert Zeilenende)
               termsSize = ArrayRange(confTerms, 0);
               ArrayResize(confTerms, termsSize+1);                  // initializes with NULL

               int lines = ArrayRange(confsData, 0);
               ArrayResize(confsData, lines+1);
               if (!StringLen(confComment)) comment = openComment + ifString(StringLen(openComment) && StringLen(hstComment ), ", ", "") + hstComment;
               else                         comment = confComment;   // configured comments override generated ones
               confsData[lines][I_CONFIG_KEY    ] = keys[i];
               confsData[lines][I_CONFIG_COMMENT] = comment;

               ArrayResize(confdData, lines+1);
               if (isBemEnabled)  confdData[lines][I_BEM_ENABLED ] = 1;
               if (isMfaeEnabled) confdData[lines][I_MFAE_ENABLED] = 1;
               if (isMfaeSignal)  confdData[lines][I_MFAE_SIGNAL ] = 1;
               if (markMfe)       confdData[lines][I_MARK_MFE    ] = 1;

               nextPositionStartOffset = termsSize + 1;              // Start-Offset der n�chsten Custom-Position merken (falls eine weitere Position folgt)
            }
         }
      }
   }

   // mark an empty configuration with an EOL term
   if (!ArrayRange(confTerms, 0)) {
      ArrayResize(confTerms, 1);                                     // initializes with NULL
   }

   // keep existing position stats
   int oldLines = ArrayRange(config.sData, 0);
   int newLines = ArrayRange(confsData, 0);

   if (oldLines > 0) {
      for (i=0; i < newLines; i++) {
         for (n=0; n < oldLines; n++) {
            if (confsData[i][I_CONFIG_KEY] == config.sData[n][I_CONFIG_KEY]) {
               if (confdData[i][I_MFAE_ENABLED] && 1) {
                  confdData[i][I_PROFIT_MFE] = config.dData[n][I_PROFIT_MFE];
                  confdData[i][I_PROFIT_MAE] = config.dData[n][I_PROFIT_MAE];
               }
               confdData[i][I_MAX_LOTS] = config.dData[n][I_MAX_LOTS];
               confdData[i][I_MAX_RISK] = config.dData[n][I_MAX_RISK];
               break;
            }
         }
      }
   }

   // finally overwrite global vars (thus on error they are not touched)
   ArrayResize(config.terms, 0); if (ArraySize(confTerms) > 0) ArrayCopy(config.terms, confTerms);
   ArrayResize(config.sData, 0); if (ArraySize(confsData) > 0) ArrayCopy(config.sData, confsData);
   ArrayResize(config.dData, 0); if (ArraySize(confdData) > 0) ArrayCopy(config.dData, confdData);
   return(!catch("CustomPositions.ReadConfig(47)"));
}


/**
 * Parst einen Open-Position-Konfigurationsterm.
 *
 * @param  _In_    string   term         - Konfigurationsterm
 * @param  _InOut_ string   openComments - vorhandene OpenPositions-Kommentare (werden ggf. erweitert)
 * @param  _Out_   datetime from         - Beginnzeitpunkt der zu ber�cksichtigenden Positionen
 * @param  _Out_   datetime to           - Endzeitpunkt der zu ber�cksichtigenden Positionen
 *
 * @return bool - success status
 *
 *
 * possible formats:
 * -----------------
 *  O{DateTime}                                       // intentionally there's no TERM_OPEN_TOTAL
 *  O{DateTime}-{DateTime}
 *
 *  {DateTime} = 2014[.01[.15 [W|12:34[:56]]]]        or
 *  {DateTime} = (This|Last)(Day|Week|Month|Year)     or
 *  {DateTime} = Today                                alias for ThisDay
 *  {DateTime} = Yesterday                            alias for LastDay
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


   // (2) Datumswerte definieren und zur�ckgeben
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
 * Parst einen History-Term (closed position).
 *
 * @param  _In_    string   term              - Konfigurations-Term
 * @param  _InOut_ string   positionComment   - Kommentar der Position (wird bei Gruppierungen nur bei der ersten Gruppe angezeigt)
 * @param  _InOut_ string   hstComments       - dynamisch generierte History-Kommentare (werden ggf. erweitert)
 * @param  _InOut_ bool     isEmptyPosition   - ob die aktuelle Position noch leer ist
 * @param  _InOut_ bool     isGroupedPosition - ob die aktuelle Position eine Gruppierung enth�lt
 * @param  _Out_   bool     isTotalHistory    - ob die History alle verf�gbaren Trades (TRUE) oder nur die des aktuellen Symbols (FALSE) einschlie�t
 * @param  _Out_   datetime from              - Beginnzeitpunkt der zu ber�cksichtigenden History
 * @param  _Out_   datetime to                - Endzeitpunkt der zu ber�cksichtigenden History
 * @param  _InOut_ double   confTerms[][]     - config terms[] for grouped histories (directly modified here)
 * @param  _InOut_ string   confsData[][]     - config line string data for grouped histories (directly modified here)
 * @param  _InOut_ double   confdData[][]     - config line double data for grouped histories (directly modified here)
 *
 * @return bool - success status
 *
 *
 * Format:
 * -------
 *  H{DateTime}             [Monthly|Weekly|Daily]    � Trade-History eines Symbols eines Standard-Zeitraums
 *  HT{DateTime}-{DateTime} [Monthly|Weekly|Daily]    � Trade-History aller Symbole von und bis zu einem Zeitpunkt
 *
 *  {DateTime} = 2014[.01[.15 [W|12:34[:56]]]]        oder
 *  {DateTime} = (This|Last)(Day|Week|Month|Year)     oder
 *  {DateTime} = Today                                � Synonym f�r ThisDay
 *  {DateTime} = Yesterday                            � Synonym f�r LastDay
 */
bool CustomPositions.ParseHstTerm(string term, string &positionComment, string &hstComments, bool &isEmptyPosition, bool &isGroupedPosition, bool &isTotalHistory, datetime &from, datetime &to, double &confTerms[][], string &confsData[][], double &confdData[][]) {
   isEmptyPosition   = isEmptyPosition  !=0;
   isGroupedPosition = isGroupedPosition!=0;
   isTotalHistory    = isTotalHistory   !=0;

   string termOrig = StrTrim(term);
   term = StrToUpper(termOrig);
   if (!StrStartsWith(term, "H")) return(!catch("CustomPositions.ParseHstTerm(1)  invalid parameter term: "+ DoubleQuoteStr(termOrig) +" (not TERM_HISTORY_*)", ERR_INVALID_PARAMETER));
   term = StrTrim(StrSubstr(term, 1));

   if     (!StrStartsWith(term, "T"    )) isTotalHistory = false;
   else if (StrStartsWith(term, "THIS" )) isTotalHistory = false;
   else if (StrStartsWith(term, "TODAY")) isTotalHistory = false;
   else                                   isTotalHistory = true;
   if (isTotalHistory) term = StrTrim(StrSubstr(term, 1));

   bool isSingleTimespan, groupByDay, groupByWeek, groupByMonth, isFullYear1, isFullYear2, isFullMonth1, isFullMonth2, isFullWeek1, isFullWeek2, isFullDay1, isFullDay2, isFullHour1, isFullHour2, isFullMinute1, isFullMinute2;
   datetime dtFrom, dtTo;
   string comment = "";

   // auf Group-Modifier pr�fen
   if (StrEndsWith(term, " DAILY")) {
      groupByDay = true;
      term = StrTrim(StrLeft(term, -6));
   }
   else if (StrEndsWith(term, " WEEKLY")) {
      groupByWeek = true;
      term = StrTrim(StrLeft(term, -7));
   }
   else if (StrEndsWith(term, " MONTHLY")) {
      groupByMonth = true;
      term = StrTrim(StrLeft(term, -8));
   }

   bool isGroupingTerm = groupByDay || groupByWeek || groupByMonth;
   if (isGroupingTerm && !isEmptyPosition) return(!catch("CustomPositions.ParseHstTerm(2)  cannot combine grouping configuration "+ DoubleQuoteStr(termOrig) +" with another configuration", ERR_INVALID_CONFIG_VALUE));
   isGroupedPosition = isGroupedPosition || isGroupingTerm;

   // Beginn- und Endzeitpunkt parsen
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
                                                                                                                      if (!dtFrom)       return(!catch("CustomPositions.ParseHstTerm(3)  invalid history configuration in "+ DoubleQuoteStr(termOrig), ERR_INVALID_CONFIG_VALUE));
      if      (isFullYear1  ) dtTo = DateTime1(TimeYearEx(dtFrom)+1)                    - 1*SECOND;   // Jahresende
      else if (isFullMonth1 ) dtTo = DateTime1(TimeYearEx(dtFrom), TimeMonth(dtFrom)+1) - 1*SECOND;   // Monatsende
      else if (isFullWeek1  ) dtTo = dtFrom + 1*WEEK                                    - 1*SECOND;   // Wochenende
      else if (isFullDay1   ) dtTo = dtFrom + 1*DAY                                     - 1*SECOND;   // Tagesende
      else if (isFullHour1  ) dtTo = dtFrom + 1*HOUR                                    - 1*SECOND;   // Ende der Stunde
      else if (isFullMinute1) dtTo = dtFrom + 1*MINUTE                                  - 1*SECOND;   // Ende der Minute
      else                    dtTo = dtFrom;
   }
   if (!dtFrom && !dtTo)      return(!catch("CustomPositions.ParseHstTerm(4)  invalid history configuration in "+ DoubleQuoteStr(termOrig), ERR_INVALID_CONFIG_VALUE));
   if (dtTo && dtFrom > dtTo) return(!catch("CustomPositions.ParseHstTerm(5)  invalid history configuration in "+ DoubleQuoteStr(termOrig) +" (history start after history end)", ERR_INVALID_CONFIG_VALUE));


   if (isGroupingTerm) {
      //
      // TODO:  Performance verbessern
      //
      // Gruppen anlegen und komplette Zeilen direkt hier einf�gen (bei der letzten Gruppe jedoch ohne Zeilenende)
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

         // Kommentar erstellen
         if      (groupByMonth) comment =             GmtTimeFormat(groupFrom, "%Y %B");
         else if (groupByWeek ) comment = "Week of "+ GmtTimeFormat(groupFrom, "%d.%m.%Y");
         else if (groupByDay  ) comment =             GmtTimeFormat(groupFrom, "%d.%m.%Y");
         if (isTotalHistory)    comment = comment +" (total)";

         // Gruppe der Konfiguration hinzuf�gen
         int termsSize = ArrayRange(confTerms, 0);
         ArrayResize(confTerms, termsSize+1);
         confTerms[termsSize][I_TERM_TYPE   ] = ifInt(!isTotalHistory, TERM_HISTORY, TERM_HISTORY_TOTAL);
         confTerms[termsSize][I_TERM_VALUE1 ] = groupFrom;
         confTerms[termsSize][I_TERM_VALUE2 ] = groupTo;
         confTerms[termsSize][I_TERM_RESULT1] = EMPTY_VALUE;
         confTerms[termsSize][I_TERM_RESULT2] = EMPTY_VALUE;
         isEmptyPosition = false;

         // Zeile mit Zeilenende abschlie�en (au�er bei der letzten Gruppe)
         if (nextGroupFrom <= dtTo) {
            ArrayResize(confTerms, termsSize+2);                     // ArrayResize() initialisiert mit NULL
            int lines = ArrayRange(confdData, 0);
            ArrayResize(confdData, lines+1);
            ArrayResize(confsData, lines+1);
            confsData[lines][I_CONFIG_KEY    ] = "";
            confsData[lines][I_CONFIG_COMMENT] = comment + ifString(StringLen(positionComment), ", ", "") + positionComment;
            if (firstGroup) positionComment = "";                    // f�r folgende Gruppen wird der konfigurierte Kommentar nicht st�ndig wiederholt
         }
      }
   }
   else {
      // normale R�ckgabewerte ohne Gruppierung
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
 * @param  _Out_ bool   isDay    - ob ein allgemein formulierter Zeitraum einen Tag beschreibt,   z.B. "2014.02.18"  oder "Yesterday" (Synonym f�r LastDay)
 * @param  _Out_ bool   isHour   - ob ein allgemein formulierter Zeitraum eine Stunde beschreibt, z.B. "2014.02.18 12:00"
 * @param  _Out_ bool   isMinute - ob ein allgemein formulierter Zeitraum eine Minute beschreibt, z.B. "2014.02.18 12:34"
 *
 * @return datetime - Zeitpunkt oder NaT (Not-A-Time), falls ein Fehler auftrat
 *
 * Format:
 * -------
 * "2014[.01[.15 [W|12:34[:56]]]]"    oder
 * "(This|Last)(Day|Week|Month|Year)" oder
 * "Today"                            Synonym f�r "ThisDay"
 * "Yesterday"                        Synonym f�r "LastDay"
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
            if (value != "LASTDAY")                                  return(_NaT(catch("ParseDateTimeEx(1)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
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
            if (value != "LASTWEEK")                                 return(_NaT(catch("ParseDateTimeEx(2)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
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
            if (value != "LASTMONTH")                                return(_NaT(catch("ParseDateTimeEx(3)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
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
            if (value != "LASTYEAR")                                 return(_NaT(catch("ParseDateTimeEx(4)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            date = DateTime1(TimeYearEx(date)-1);                    // Datum auf das vorherige Jahr setzen
         }
         iYY    = TimeYearEx(date);
         iMM    = 1;
         iDD    = 1;
         isYear = true;
      }
      else                                                           return(_NaT(catch("ParseDateTimeEx(5)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
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
      if (valuesSize > 3)                                            return(_NaT(catch("ParseDateTimeEx(6)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));

      if (valuesSize >= 1) {
         sYY = StrTrim(values[0]);                                   // Jahr pr�fen
         if (StringLen(sYY) != 4)                                    return(_NaT(catch("ParseDateTimeEx(7)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         if (!StrIsDigits(sYY))                                      return(_NaT(catch("ParseDateTimeEx(8)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         iYY = StrToInteger(sYY);
         if (iYY < 1970 || 2037 < iYY)                               return(_NaT(catch("ParseDateTimeEx(9)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         if (valuesSize == 1) {
            iMM    = 1;
            iDD    = 1;
            isYear = true;
         }
      }

      if (valuesSize >= 2) {
         sMM = StrTrim(values[1]);                                   // Monat pr�fen
         if (StringLen(sMM) > 2)                                     return(_NaT(catch("ParseDateTimeEx(10)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         if (!StrIsDigits(sMM))                                      return(_NaT(catch("ParseDateTimeEx(11)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         iMM = StrToInteger(sMM);
         if (iMM < 1 || 12 < iMM)                                    return(_NaT(catch("ParseDateTimeEx(12)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
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
            if (pos == -1)                                           return(_NaT(catch("ParseDateTimeEx(13)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            sTime = StrTrim(StrSubstr(sDD, pos+1));
            sDD   = StrTrim(StrLeft (sDD,  pos  ));
         }
         else {                                                      // nur Tag
            isDay = true;
         }
                                                                     // Tag pr�fen
         if (StringLen(sDD) > 2)                                     return(_NaT(catch("ParseDateTimeEx(14)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         if (!StrIsDigits(sDD))                                      return(_NaT(catch("ParseDateTimeEx(15)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         iDD = StrToInteger(sDD);
         if (iDD < 1 || 31 < iDD)                                    return(_NaT(catch("ParseDateTimeEx(16)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         if (iDD > 28) {
            if (iMM == FEB) {
               if (iDD > 29)                                         return(_NaT(catch("ParseDateTimeEx(17)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
               if (!IsLeapYear(iYY))                                 return(_NaT(catch("ParseDateTimeEx(18)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            }
            else if (iDD==31)
               if (iMM==APR || iMM==JUN || iMM==SEP || iMM==NOV)     return(_NaT(catch("ParseDateTimeEx(19)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
         }

         if (StringLen(sTime) > 0) {                                 // Zeit pr�fen
            // hh:ii:ss
            valuesSize = Explode(sTime, ":", values, NULL);
            if (valuesSize < 2 || 3 < valuesSize)                    return(_NaT(catch("ParseDateTimeEx(20)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));

            sHH = StrTrim(values[0]);                                // Stunden
            if (StringLen(sHH) > 2)                                  return(_NaT(catch("ParseDateTimeEx(21)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            if (!StrIsDigits(sHH))                                   return(_NaT(catch("ParseDateTimeEx(22)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            iHH = StrToInteger(sHH);
            if (iHH < 0 || 23 < iHH)                                 return(_NaT(catch("ParseDateTimeEx(23)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));

            sII = StrTrim(values[1]);                                // Minuten
            if (StringLen(sII) > 2)                                  return(_NaT(catch("ParseDateTimeEx(24)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            if (!StrIsDigits(sII))                                   return(_NaT(catch("ParseDateTimeEx(25)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            iII = StrToInteger(sII);
            if (iII < 0 || 59 < iII)                                 return(_NaT(catch("ParseDateTimeEx(26)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            if (valuesSize == 2) {
               if (!iII) isHour   = true;
               else      isMinute = true;
            }

            if (valuesSize == 3) {
               sSS = StrTrim(values[2]);                             // Sekunden
               if (StringLen(sSS) > 2)                               return(_NaT(catch("ParseDateTimeEx(27)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
               if (!StrIsDigits(sSS))                                return(_NaT(catch("ParseDateTimeEx(28)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
               iSS = StrToInteger(sSS);
               if (iSS < 0 || 59 < iSS)                              return(_NaT(catch("ParseDateTimeEx(29)  invalid datetime configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
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
 * Extrahiert aus dem Bestand der �bergebenen Positionen {fromVars} eine Teilposition und f�gt sie dem Bestand einer
 * CustomPosition {customVars} hinzu.
 *
 * @param  _In_    int      termType    -+
 * @param  _In_    double   termValue1   |
 * @param  _In_    double   termValue2   +--> struct POSITION_CONFIG_TERM { int type; double value1; double value2; double result1; double result2; }
 * @param  _InOut_ double   termResult1  |
 * @param  _InOut_ double   termResult2 -+
 *
 * @param  _InOut_ double   fromLongPosition  - Variablen, aus denen die Teilposition extrahiert wird (Bestand verringert sich)
 * @param  _InOut_ double   fromShortPosition
 * @param  _InOut_ double   fromTotalPosition
 * @param  _InOut_ int      fromTickets[]
 * @param  _In_    int      fromTypes[]
 * @param  _InOut_ double   fromLots[]
 * @param  _In_    datetime fromOpenTimes[]
 * @param  _In_    double   fromOpenPrices[]
 * @param  _InOut_ double   fromCommissions[]
 * @param  _InOut_ double   fromSwaps[]
 * @param  _InOut_ double   fromPprofits[]
 *
 * @param  _Out_   double   profitMarkerPrice - PL marker price level (if configured)
 * @param  _Out_   double   profitMarkerPct   - PL marker percent level (if configured)
 * @param  _Out_   double   lossMarkerPrice   - PL marker price level (if configured)
 * @param  _Out_   double   lossMarkerPct     - PL marker percent level (if configured)
 * @param  _InOut_ bool     isVirtual         - whether the resulting custom position is virtual
 * @param  _In_    int      flags [optional]  - control flags, supported values:
 *                                              F_SHOW_CUSTOM_HISTORY: call ShowTradeHistory() for the configured history
 * @return bool - success status
 */
bool ExtractPosition(int termType, double termValue1, double termValue2, double &termResult1, double &termResult2,
                     double &fromLongPosition,   double &fromShortPosition,   double &fromTotalPosition,   int &fromTickets[],   int fromTypes[],    double &fromLots[], datetime fromOpenTimes[], double fromOpenPrices[],    double &fromCommissions[],   double &fromSwaps[],   double &fromProfits[],
                     double &customLongPosition, double &customShortPosition, double &customTotalPosition, int &customTickets[], int &customTypes[], double &customLots[],                         double &customOpenPrices[], double &customCommissions[], double &customSwaps[], double &customProfits[], double &closedProfit, double &adjustedProfit, double &customEquity, double &profitMarkerPrice, double &profitMarkerPct, double &lossMarkerPrice, double &lossMarkerPct,
                     bool   &isVirtual, int flags = NULL) {
   isVirtual = isVirtual!=0;

   double lotsize;
   datetime from, to;
   int ticket, sizeFromTickets = ArraySize(fromTickets);

   if (termType == TERM_OPEN_LONG) {
      lotsize = termValue1;

      if (lotsize == EMPTY) {
         // alle �brigen Long-Positionen
         if (fromLongPosition > 0) {
            for (int i=0; i < sizeFromTickets; i++) {
               if (!fromTickets[i]) continue;

               if (fromTypes[i] == OP_BUY) {
                  // Daten nach custom.* �bernehmen und Ticket ggf. auf NULL setzen
                  ArrayPushInt   (customTickets,     fromTickets    [i]);
                  ArrayPushInt   (customTypes,       fromTypes      [i]);
                  ArrayPushDouble(customLots,        fromLots       [i]);
                  ArrayPushDouble(customOpenPrices,  fromOpenPrices [i]);
                  ArrayPushDouble(customCommissions, fromCommissions[i]);
                  ArrayPushDouble(customSwaps,       fromSwaps      [i]);
                  ArrayPushDouble(customProfits,     fromProfits    [i]);
                  if (!isVirtual) {
                     fromLongPosition  = NormalizeDouble(fromLongPosition - fromLots[i],       2);
                     fromTotalPosition = NormalizeDouble(fromLongPosition - fromShortPosition, 2);
                     fromTickets[i]    = NULL;
                  }
                  customLongPosition  = NormalizeDouble(customLongPosition + fromLots[i],         3);
                  customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 3);
               }
            }
         }
      }
      else {
         // virtuelle Long-Position zu custom.* hinzuf�gen (Ausgangsdaten bleiben unver�ndert)
         if (lotsize != 0) {                                         // 0-Lots-Positionen werden �bersprungen (es gibt nichts abzuziehen oder hinzuzuf�gen)
            double openPrice = ifDouble(termValue2!=0, termValue2, Ask);
            ArrayPushInt   (customTickets,     VIRTUAL_TICKET_LONG                        );
            ArrayPushInt   (customTypes,       OP_BUY                                     );
            ArrayPushDouble(customLots,        lotsize                                    );
            ArrayPushDouble(customOpenPrices,  openPrice                                  );
            ArrayPushDouble(customCommissions, NormalizeDouble(-GetCommission(lotsize), 2));
            ArrayPushDouble(customSwaps,       0                                          );
            ArrayPushDouble(customProfits,     (Bid-openPrice)/Pip * PipValue(lotsize, true));  // Fehler unterdr�cken, INIT_PIPVALUE ist u.U. nicht gesetzt
            customLongPosition  = NormalizeDouble(customLongPosition + lotsize,             3);
            customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 3);
         }
         isVirtual = true;
      }
   }

   else if (termType == TERM_OPEN_SHORT) {
      lotsize = termValue1;

      if (lotsize == EMPTY) {
         // alle �brigen Short-Positionen
         if (fromShortPosition > 0) {
            for (i=0; i < sizeFromTickets; i++) {
               if (!fromTickets[i]) continue;

               if (fromTypes[i] == OP_SELL) {
                  // Daten nach custom.* �bernehmen und Ticket ggf. auf NULL setzen
                  ArrayPushInt   (customTickets,     fromTickets    [i]);
                  ArrayPushInt   (customTypes,       fromTypes      [i]);
                  ArrayPushDouble(customLots,        fromLots       [i]);
                  ArrayPushDouble(customOpenPrices,  fromOpenPrices [i]);
                  ArrayPushDouble(customCommissions, fromCommissions[i]);
                  ArrayPushDouble(customSwaps,       fromSwaps      [i]);
                  ArrayPushDouble(customProfits,     fromProfits    [i]);
                  if (!isVirtual) {
                     fromShortPosition = NormalizeDouble(fromShortPosition - fromLots[i],      2);
                     fromTotalPosition = NormalizeDouble(fromLongPosition - fromShortPosition, 2);
                     fromTickets[i]    = NULL;
                  }
                  customShortPosition = NormalizeDouble(customShortPosition + fromLots[i],         3);
                  customTotalPosition = NormalizeDouble(customLongPosition  - customShortPosition, 3);
               }
            }
         }
      }
      else {
         // virtuelle Short-Position zu custom.* hinzuf�gen (Ausgangsdaten bleiben unver�ndert)
         if (lotsize != 0) {                                         // 0-Lots-Positionen werden �bersprungen (es gibt nichts abzuziehen oder hinzuzuf�gen)
            openPrice = ifDouble(termValue2!=0, termValue2, Bid);
            ArrayPushInt   (customTickets,     VIRTUAL_TICKET_SHORT                       );
            ArrayPushInt   (customTypes,       OP_SELL                                    );
            ArrayPushDouble(customLots,        lotsize                                    );
            ArrayPushDouble(customOpenPrices,  openPrice                                  );
            ArrayPushDouble(customCommissions, NormalizeDouble(-GetCommission(lotsize), 2));
            ArrayPushDouble(customSwaps,       0                                          );
            ArrayPushDouble(customProfits,     (openPrice-Ask)/Pip * PipValue(lotsize, true));  // Fehler unterdr�cken, INIT_PIPVALUE ist u.U. nicht gesetzt
            customShortPosition = NormalizeDouble(customShortPosition + lotsize,            3);
            customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 3);
         }
         isVirtual = true;
      }
   }

   else if (termType == TERM_OPEN) {
      from = termValue1;
      to   = termValue2;

      // alle offenen Positionen des aktuellen Symbols eines Zeitraumes
      if (fromLongPosition || fromShortPosition) {
         for (i=0; i < sizeFromTickets; i++) {
            if (!fromTickets[i])                 continue;
            if (from && fromOpenTimes[i] < from) continue;
            if (to   && fromOpenTimes[i] > to  ) continue;

            // Daten nach custom.* �bernehmen und Ticket ggf. auf NULL setzen
            ArrayPushInt   (customTickets,     fromTickets    [i]);
            ArrayPushInt   (customTypes,       fromTypes      [i]);
            ArrayPushDouble(customLots,        fromLots       [i]);
            ArrayPushDouble(customOpenPrices,  fromOpenPrices [i]);
            ArrayPushDouble(customCommissions, fromCommissions[i]);
            ArrayPushDouble(customSwaps,       fromSwaps      [i]);
            ArrayPushDouble(customProfits,     fromProfits    [i]);
            if (!isVirtual) {
               if (fromTypes[i] == OP_BUY) fromLongPosition  = NormalizeDouble(fromLongPosition  - fromLots[i], 2);
               else                        fromShortPosition = NormalizeDouble(fromShortPosition - fromLots[i], 2);
                                           fromTotalPosition = NormalizeDouble(fromLongPosition - fromShortPosition, 2);
                                           fromTickets[i]    = NULL;
            }
            if (fromTypes[i] == OP_BUY) customLongPosition  = NormalizeDouble(customLongPosition  + fromLots[i], 3);
            else                        customShortPosition = NormalizeDouble(customShortPosition + fromLots[i], 3);
                                        customTotalPosition = NormalizeDouble(customLongPosition  - customShortPosition, 3);
         }
      }
   }

   else if (termType==TERM_HISTORY || termType==TERM_HISTORY_TOTAL) {
      // geschlossene Positionen des aktuellen oder aller Symbole eines Zeitraumes
      from              = termValue1;
      to                = termValue2;
      double lastProfit = termResult1;    // default: EMPTY_VALUE
      int    lastOrders = termResult2;    // default: EMPTY_VALUE                // Anzahl der Tickets in der History: �ndert sie sich, wird der PL neu berechnet

      int orders=OrdersHistoryTotal(), _orders=orders;
      if (orders != lastOrders) {

         // Sortierschl�ssel aller geschlossenen Positionen auslesen und nach {CloseTime, OpenTime, Ticket} sortieren
         int sortKeys[][3], n, hst.ticket;                                 // {CloseTime, OpenTime, Ticket}
         ArrayResize(sortKeys, orders);

         for (i=0; i < orders; i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) break;             // FALSE: the visible history range was modified in another thread

            // wenn OrderType()==OP_BALANCE, dann OrderSymbol()==Leerstring
            if (OrderType() == OP_BALANCE) {
               // Dividenden                                                     // "Ex Dividend US2000" oder
               if (StrStartsWithI(OrderComment(), "ex dividend ")) {             // "Ex Dividend 17/03/15 US2000"
                  if (termType == TERM_HISTORY)                                  // single history
                     if (!StrEndsWithI(OrderComment(), " "+ Symbol())) continue; // ok, wenn zum aktuellen Symbol geh�rend
               }
               // Rollover adjustments
               else if (StrStartsWithI(OrderComment(), "adjustment ")) {         // "Adjustment BRENT"
                  if (termType == TERM_HISTORY)                                  // single history
                     if (!StrEndsWithI(OrderComment(), " "+ Symbol())) continue; // ok, wenn zum aktuellen Symbol geh�rend
               }
               else continue;                                                    // sonstige Balance-Eintr�ge
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
         SortClosedTickets(sortKeys);                       // TODO: move to Expander (bad performance)

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
         // TODO: the nested loop freezes the terminal if full history is active => move to Expander
         for (i=0; i < orders; i++) {
            if (!hst.valid[i]) continue;                                      // skip processed hedging orders

            if (hst.lotSizes[i] < 0.005) {                                    // lotSize = 0: Hedge-Position
               // TODO: Pr�fen, wie sich OrderComment() bei custom comments verh�lt.
               if (!StrStartsWith(hst.comments[i], "close hedge by #")) {
                  return(!catch("ExtractPosition(2)  #"+ hst.tickets[i] +" - unknown comment for assumed hedging position "+ DoubleQuoteStr(hst.comments[i]), ERR_RUNTIME_ERROR));
               }

               // Gegenst�ck suchen
               hst.ticket = StrToInteger(StringSubstr(hst.comments[i], 16));
               for (n=0; n < orders; n++) {                                   // TODO: move to Expander
                  if (hst.tickets[n] == hst.ticket) break;
               }
               if (n == orders) return(!catch("ExtractPosition(3)  cannot find counterpart for hedging position #"+ hst.tickets[i] +" "+ DoubleQuoteStr(hst.comments[i]), ERR_RUNTIME_ERROR));
               if (i == n     ) return(!catch("ExtractPosition(4)  both hedged and hedging position have the same ticket #"+ hst.tickets[i] +" "+ DoubleQuoteStr(hst.comments[i]), ERR_RUNTIME_ERROR));

               int first  = Min(i, n);
               int second = Max(i, n);

               // Orderdaten korrigieren
               if (i == first) {
                  hst.lotSizes   [first] = hst.lotSizes   [second];           // alle Transaktionsdaten in der ersten Order speichern
                  hst.commissions[first] = hst.commissions[second];
                  hst.swaps      [first] = hst.swaps      [second];
                  hst.profits    [first] = hst.profits    [second];
               }
               hst.closeTimes [first] = hst.openTimes [second];
               hst.closePrices[first] = hst.openPrices[second];

               hst.closeTimes[second] = hst.closeTimes[first];                // CloseTime des hedgenden Tickets auf die erste Order setzen, damit es durch den Zeitfilter kommt und an ShowTradeHistory() �bergeben werden kann
               hst.valid     [second] = false;                                // hedgendes Ticket als verworfen markieren
            }
         }

         // Trades auswerten
         int showTickets[];
         ArrayResize(showTickets, 0);
         lastProfit=0; n=0;

         for (i=0; i < orders; i++) {
            if (from && hst.closeTimes[i] < from) continue;
            if (to   && hst.closeTimes[i] > to  ) continue;
            ArrayPushInt(showTickets, hst.tickets[i]);                        // collect tickets to pass to ShowTradeHistory()
            if (!hst.valid[i])                    continue;                   // verworfene Hedges �berspringen
            lastProfit += hst.commissions[i] + hst.swaps[i] + hst.profits[i];
            n++;
         }                                                                    // call ShowTradeHistory() if specified
         if (flags & F_SHOW_CUSTOM_HISTORY && ArraySize(showTickets)) ShowTradeHistory(showTickets);

         if (!n) lastProfit = EMPTY_VALUE;                                    // keine passenden geschlossenen Trades gefunden
         else    lastProfit = NormalizeDouble(lastProfit, 2);
         termResult1        = lastProfit;
         termResult2        = _orders;
         //debug("ExtractPosition(0.1)  from="+ ifString(from, TimeToStr(from), "start") +"  to="+ ifString(to, TimeToStr(to), "end") +"  profit="+ ifString(IsEmptyValue(lastProfit), "empty", DoubleToStr(lastProfit, 2)) +"  closed trades="+ n);
      }

      // lastProfit zu closedProfit hinzuf�gen, wenn geschlossene Trades existierten (Ausgangsdaten bleiben unver�ndert)
      if (lastProfit != EMPTY_VALUE) {
         if (closedProfit == EMPTY_VALUE) closedProfit  = lastProfit;
         else                             closedProfit += lastProfit;
      }
   }

   else if (termType == TERM_PL_ADJUSTMENT) {
      // Betrag zu adjustedProfit hinzuf�gen (Ausgangsdaten bleiben unver�ndert)
      adjustedProfit += termValue1;
   }

   else if (termType == TERM_EQUITY) {
      // vorhandenen Betrag �berschreiben (Ausgangsdaten bleiben unver�ndert)
      customEquity = termValue1;
   }

   else if (termType == TERM_PROFIT_MARKER) {
      profitMarkerPrice = termValue1;
      profitMarkerPct = termValue2;
   }

   else if (termType == TERM_LOSS_MARKER) {
      lossMarkerPrice = termValue1;
      lossMarkerPct = termValue2;
   }

   else if (termType == TERM_TICKET) {
      ticket = termValue1;
      lotsize = termValue2;

      if (lotsize == EMPTY) {
         // komplettes Ticket
         for (i=0; i < sizeFromTickets; i++) {
            if (fromTickets[i] == ticket) {
               // Daten nach custom.* �bernehmen und Ticket ggf. auf NULL setzen
               ArrayPushInt   (customTickets,     fromTickets    [i]);
               ArrayPushInt   (customTypes,       fromTypes      [i]);
               ArrayPushDouble(customLots,        fromLots       [i]);
               ArrayPushDouble(customOpenPrices,  fromOpenPrices [i]);
               ArrayPushDouble(customCommissions, fromCommissions[i]);
               ArrayPushDouble(customSwaps,       fromSwaps      [i]);
               ArrayPushDouble(customProfits,     fromProfits    [i]);
               if (!isVirtual) {
                  if (fromTypes[i] == OP_BUY) fromLongPosition  = NormalizeDouble(fromLongPosition  - fromLots[i], 2);
                  else                        fromShortPosition = NormalizeDouble(fromShortPosition - fromLots[i], 2);
                                              fromTotalPosition = NormalizeDouble(fromLongPosition - fromShortPosition, 2);
                                              fromTickets[i]    = NULL;
               }
               if (fromTypes[i] == OP_BUY) customLongPosition  = NormalizeDouble(customLongPosition  + fromLots[i], 3);
               else                        customShortPosition = NormalizeDouble(customShortPosition + fromLots[i], 3);
                                           customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 3);
               break;
            }
         }
      }
      else if (lotsize != 0) {                                       // 0-Lots-Positionen werden �bersprungen (es gibt nichts abzuziehen oder hinzuzuf�gen)
         // partielles Ticket
         for (i=0; i < sizeFromTickets; i++) {
            if (fromTickets[i] == ticket) {
               if (GT(lotsize, fromLots[i])) return(!catch("ExtractPosition(5)  illegal partial lotsize "+ NumberToStr(lotsize, ".+") +" for ticket #"+ fromTickets[i] +" (only "+ NumberToStr(fromLots[i], ".+") +" lot remaining)", ERR_RUNTIME_ERROR));
               if (EQ(lotsize, fromLots[i])) {
                  // komplettes Ticket �bernehmen
                  if (!ExtractPosition(TERM_TICKET, ticket, EMPTY, termResult1, termResult2,
                                       fromLongPosition,   fromShortPosition,   fromTotalPosition,   fromTickets,   fromTypes,   fromLots, fromOpenTimes, fromOpenPrices,   fromCommissions,   fromSwaps,   fromProfits,
                                       customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLots,              customOpenPrices, customCommissions, customSwaps, customProfits, closedProfit, adjustedProfit, customEquity, profitMarkerPrice, profitMarkerPct, lossMarkerPrice, lossMarkerPct,
                                       isVirtual))
                     return(false);
               }
               else {
                  // Daten anteilig nach custom.* �bernehmen und Ticket ggf. reduzieren
                  double factor = lotsize/fromLots[i];
                  ArrayPushInt   (customTickets,     fromTickets    [i]         );
                  ArrayPushInt   (customTypes,       fromTypes      [i]         );
                  ArrayPushDouble(customLots,        lotsize                    ); if (!isVirtual) fromLots       [i]  = NormalizeDouble(fromLots[i]-lotsize, 2); // reduzieren
                  ArrayPushDouble(customOpenPrices,  fromOpenPrices [i]         );
                  ArrayPushDouble(customSwaps,       fromSwaps      [i]         ); if (!isVirtual) fromSwaps      [i]  = NULL;                                    // komplett
                  ArrayPushDouble(customCommissions, fromCommissions[i] * factor); if (!isVirtual) fromCommissions[i] *= (1-factor);                              // anteilig
                  ArrayPushDouble(customProfits,     fromProfits    [i] * factor); if (!isVirtual) fromProfits    [i] *= (1-factor);                              // anteilig
                  if (!isVirtual) {
                     if (fromTypes[i] == OP_BUY) fromLongPosition  = NormalizeDouble(fromLongPosition  - lotsize, 2);
                     else                        fromShortPosition = NormalizeDouble(fromShortPosition - lotsize, 2);
                                                 fromTotalPosition = NormalizeDouble(fromLongPosition - fromShortPosition, 2);
                  }
                  if (fromTypes[i] == OP_BUY) customLongPosition  = NormalizeDouble(customLongPosition  + lotsize, 3);
                  else                        customShortPosition = NormalizeDouble(customShortPosition + lotsize, 3);
                                              customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 3);
               }
               break;
            }
         }
      }
   }

   else if (termType==TERM_MFAE || termType==TERM_MFAE_SIGNAL || termType==TERM_BE_MARKER) {
      // flags: nothing to do
   }
   else return(!catch("ExtractPosition(6)  illegal or unknown termType: "+ termType, ERR_RUNTIME_ERROR));

   return(!catch("ExtractPosition(7)"));
}


/**
 * Stores all collected data of a single custom config line as a new record in positions.data[].
 * The record n positions.data[] represents a single row displayed in the chart.
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
 * @param  _In_    double profitMarkerPct
 * @param  _In_    double lossMarkerPrice
 * @param  _In_    double lossMarkerPct
 *
 * @param  _In_    int    configLine - index of the config line
 * @param  _Out_   bool   skipped    - whether the resulting custom position is empty and the config line can be skipped
 *
 * @return bool - success status
 */
bool StoreCustomPosition(bool isVirtual, double longPosition, double shortPosition, double totalPosition, int &tickets[], int types[], double &lots[], double openPrices[], double &commissions[], double &swaps[], double &profits[], double closedProfit, double adjustedProfit, double customEquity, double profitMarkerPrice, double profitMarkerPct, double lossMarkerPrice, double lossMarkerPct, int configLine, bool &skipped) {
   isVirtual = isVirtual!=0;

   double hedgedLots, remainingLong, remainingShort, factor, openPrice, closePrice, swap, commission, hedgedProfit, floatingProfit, pipValue, pipDistance;
   double openProfit;                                                      // effective sum of: hedgedProfit + floatingProfit
   double totalProfit;                                                     // effective sum of: openProfit + closedProfit + adjustedProfit
   double openProfitTerminal;                                              // open profit as seen by the terminal (not optimized for hedged positions)
   double totalProfitTerminal;                                             // total profit as seen by the terminal (not optimized for hedged positions)
   double equity, equity100Pct;                                            // current equity value of the position and 100% base value for calculation of MFE/MAE
   double mfePrice, maePrice;
   bool   isNewMfe, isNewMae, markMfe;
   int    ticketsSize = ArraySize(tickets);

   // Enth�lt die Position weder OpenProfit (offene Positionen), ClosedProfit (History) noch AdjustedProfit, wird sie �bersprungen.
   // Ein Test auf size(tickets) != 0 reicht nicht aus, da einige Tickets in tickets[] bereits auf NULL gesetzt worden sein k�nnen.
   if (!longPosition) /*&&*/ if (!shortPosition) /*&&*/ if (!totalPosition) /*&&*/ if (closedProfit==EMPTY_VALUE) /*&&*/ if (!adjustedProfit) {
      skipped = true;
      return(true);
   }
   skipped = false;

   if (closedProfit == EMPTY_VALUE) closedProfit = 0;                      // 0.00 ist g�ltiger PL

   equity = customEquity;
   if (!equity) {
      equity = mm.externalAssets;
      if (mode.intern) equity += (AccountEquity() - AccountCredit());
   }

   int n = ArrayRange(positions.data, 0);
   ArrayResize(positions.data, n+1);

   // Die Position besteht aus einem gehedgtem Anteil (konstanter Profit) und einem direktionalen Anteil (variabler Profit).
   // - kein direktionaler Anteil:  BE-Distance in Pip berechnen
   // - direktionaler Anteil:       Breakeven unter Ber�cksichtigung des Profits eines gehedgten Anteils berechnen

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
               // Daten komplett �bernehmen, Ticket auf NULL setzen
               openPrice    += lots[i] * openPrices[i];
               if (tickets[i] > 0) {                                                   // skip open profits of virtual positions
                  openProfitTerminal += swaps[i] + commissions[i] + profits[i];
               }
               swap         += swaps[i];
               commission   += commissions[i];
               remainingLong = NormalizeDouble(remainingLong - lots[i], 3);
               tickets[i]    = NULL;
            }
            else {
               // Daten anteilig �bernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor      = remainingLong/lots[i];
               openPrice  += remainingLong * openPrices[i];
               if (tickets[i] > 0) {
                  openProfitTerminal += swaps[i] + factor * (commissions[i] + profits[i]);
               }
               swap       += swaps[i];                swaps      [i]  = 0;
               commission += factor * commissions[i]; commissions[i] -= factor * commissions[i];
                                                      profits    [i] -= factor * profits    [i];
                                                      lots       [i]  = NormalizeDouble(lots[i]-remainingLong, 3);
               remainingLong = 0;
            }
         }
         else /*types[i] == OP_SELL*/ {
            if (!remainingShort) continue;
            if (remainingShort >= lots[i]) {
               // Daten komplett �bernehmen, Ticket auf NULL setzen
               closePrice    += lots[i] * openPrices[i];
               if (tickets[i] > 0) {                                                   // skip open profits of virtual positions
                  openProfitTerminal += swaps[i] + commissions[i] + profits[i];
               }
               swap          += swaps[i];
               //commission  += commissions[i];                                        // Commission wird nur f�r Long-Leg �bernommen
               remainingShort = NormalizeDouble(remainingShort - lots[i], 3);
               tickets[i]     = NULL;
            }
            else {
               // Daten anteilig �bernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor      = remainingShort/lots[i];
               closePrice += remainingShort * openPrices[i];
               if (tickets[i] > 0) {
                  openProfitTerminal += swaps[i] + factor * (commissions[i] + profits[i]);
               }
               swap       += swaps[i]; swaps      [i]  = 0;
                                       commissions[i] -= factor * commissions[i];      // Commission wird nur f�r Long-Leg �bernommen
                                       profits    [i] -= factor * profits    [i];
                                       lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 3);
               remainingShort = 0;
            }
         }
      }
      if (remainingLong  != 0) return(!catch("StoreCustomPosition(1)  illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR));
      if (remainingShort != 0) return(!catch("StoreCustomPosition(2)  illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR));

      // BE-Distance und Profit berechnen
      pipValue = PipValue(hedgedLots, true);                                           // Fehler unterdr�cken, INIT_PIPVALUE ist u.U. nicht gesetzt
      if (pipValue != 0) {
         pipDistance  = (closePrice-openPrice)/hedgedLots/Pip + (swap+commission)/pipValue;
         hedgedProfit = pipDistance * pipValue;
      }

      // (1.1) Kein direktionaler Anteil: Hedge-Position speichern und R�ckkehr
      if (!totalPosition) {
         positions.data[n][I_CONFIG_LINE     ] = configLine;
         positions.data[n][I_CUSTOM_TYPE     ] = ifInt(isVirtual, CUSTOM_VIRTUAL_POSITION, CUSTOM_REAL_POSITION);
         positions.data[n][I_POSITION_TYPE   ] = POSITION_HEDGE;
         positions.data[n][I_DIRECTIONAL_LOTS] = 0;
         positions.data[n][I_HEDGED_LOTS     ] = hedgedLots;     openProfit          = hedgedProfit;
         positions.data[n][I_PIP_DISTANCE    ] = pipDistance;    totalProfit         = openProfit + closedProfit + adjustedProfit;
         positions.data[n][I_ADJUSTED_PROFIT ] = adjustedProfit; totalProfitTerminal = openProfitTerminal + closedProfit + adjustedProfit;
         positions.data[n][I_PROFIT          ] = totalProfit;    equity100Pct        = equity - ifDouble(!customEquity && equity > totalProfitTerminal, totalProfitTerminal, 0);
         positions.data[n][I_PROFIT_PCT      ] = MathDiv(totalProfit, equity100Pct) * 100;
         totalProfit = NormalizeDouble(totalProfit, 2);

         if (configLine >= 0) {
            config.dData[configLine][I_PROFIT_MFE] = MathMax(totalProfit, config.dData[configLine][I_PROFIT_MFE]);
            config.dData[configLine][I_PROFIT_MAE] = MathMin(totalProfit, config.dData[configLine][I_PROFIT_MAE]);
            positions.data[n][I_PROFIT_MFE_PCT]    = MathDiv(config.dData[configLine][I_PROFIT_MFE], equity100Pct) * 100;
            positions.data[n][I_PROFIT_MAE_PCT]    = MathDiv(config.dData[configLine][I_PROFIT_MAE], equity100Pct) * 100;
         }

         positions.data[n][I_PROFIT_MFE_PRICE   ] = NULL;
         positions.data[n][I_PROFIT_MAE_PRICE   ] = NULL;
         positions.data[n][I_PROFIT_MARKER_PRICE] = NULL;
         positions.data[n][I_PROFIT_MARKER_PCT  ] = NULL;
         positions.data[n][I_LOSS_MARKER_PRICE  ] = NULL;
         positions.data[n][I_LOSS_MARKER_PCT    ] = NULL;

         //debug("StoreCustomPosition(0.1)  hedged:  totalPL="+ DoubleToStr(totalProfit, 2) +"  equity="+ DoubleToStr(equity, 2) +"  equity100%="+ DoubleToStr(equity100Pct, 2) +"  totalProfitTerminal="+ DoubleToStr(totalProfitTerminal, 2));
         return(!catch("StoreCustomPosition(3)"));
      }
   }

   // Direktionaler Anteil: Bei Breakeven-Berechnung den Profit eines gehedgten Anteils und AdjustedProfit ber�cksichtigen.
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
               // Daten komplett �bernehmen, Ticket auf NULL setzen
               openPrice      += lots[i] * openPrices[i];
               if (tickets[i] > 0) {                                                   // skip open profits of virtual positions
                  openProfitTerminal += swaps[i] + commissions[i] + profits[i];
               }
               swap           += swaps[i];
               commission     += commissions[i];
               floatingProfit += profits[i];
               tickets[i]      = NULL;
               remainingLong   = NormalizeDouble(remainingLong - lots[i], 3);
            }
            else {
               // Daten anteilig �bernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor          = remainingLong/lots[i];
               openPrice      += remainingLong * openPrices[i];
               if (tickets[i] > 0) {
                  openProfitTerminal += swaps[i] + factor * (commissions[i] + profits[i]);
               }
               swap           +=          swaps[i];       swaps      [i]  = 0;
               commission     += factor * commissions[i]; commissions[i] -= factor * commissions[i];
               floatingProfit += factor * profits[i];     profits    [i] -= factor * profits    [i];
                                                          lots       [i]  = NormalizeDouble(lots[i]-remainingLong, 3);
               remainingLong = 0;
            }
         }
      }
      if (remainingLong != 0) return(!catch("StoreCustomPosition(4)  illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of long position = "+ NumberToStr(totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      positions.data[n][I_CONFIG_LINE     ] = configLine;
      positions.data[n][I_CUSTOM_TYPE     ] = ifInt(isVirtual, CUSTOM_VIRTUAL_POSITION, CUSTOM_REAL_POSITION);
      positions.data[n][I_POSITION_TYPE   ] = POSITION_LONG;
      positions.data[n][I_DIRECTIONAL_LOTS] = totalPosition;
      positions.data[n][I_HEDGED_LOTS     ] = hedgedLots;     openProfit          = hedgedProfit + floatingProfit + swap + commission;
      positions.data[n][I_BREAKEVEN_PRICE ] = NULL;           totalProfit         = openProfit + closedProfit + adjustedProfit;
      positions.data[n][I_ADJUSTED_PROFIT ] = adjustedProfit; totalProfitTerminal = openProfitTerminal + closedProfit + adjustedProfit;
      positions.data[n][I_PROFIT          ] = totalProfit;    equity100Pct        = equity - ifDouble(!customEquity && equity > totalProfitTerminal, totalProfitTerminal, 0);
      positions.data[n][I_PROFIT_PCT      ] = MathDiv(totalProfit, equity100Pct) * 100;
      totalProfit = NormalizeDouble(totalProfit, 2);

      markMfe = false;
      if (configLine >= 0) {
         isNewMfe = (config.dData[configLine][I_MFAE_SIGNAL]  && config.dData[configLine][I_PROFIT_MFE] && totalProfit > config.dData[configLine][I_PROFIT_MFE]);
         isNewMae = (config.dData[configLine][I_MFAE_SIGNAL]  && config.dData[configLine][I_PROFIT_MAE] && totalProfit < config.dData[configLine][I_PROFIT_MAE]);
         markMfe  = (config.dData[configLine][I_MFAE_ENABLED] && config.dData[configLine][I_MARK_MFE]);

         config.dData[configLine][I_PROFIT_MFE] = MathMax(totalProfit,   config.dData[configLine][I_PROFIT_MFE]);
         config.dData[configLine][I_PROFIT_MAE] = MathMin(totalProfit,   config.dData[configLine][I_PROFIT_MAE]);
         config.dData[configLine][I_MAX_LOTS  ] = MathMax(totalPosition, config.dData[configLine][I_MAX_LOTS  ]);
         positions.data[n][I_PROFIT_MFE_PCT]    = MathDiv(config.dData[configLine][I_PROFIT_MFE], equity100Pct) * 100;
         positions.data[n][I_PROFIT_MAE_PCT]    = MathDiv(config.dData[configLine][I_PROFIT_MAE], equity100Pct) * 100;

         if (isNewMfe) onNewMFE(config.sData[configLine][I_CONFIG_KEY], totalProfit);
         if (isNewMae) onNewMAE(config.sData[configLine][I_CONFIG_KEY], totalProfit);
      }

      positions.data[n][I_PROFIT_MFE_PRICE   ] = NULL;
      positions.data[n][I_PROFIT_MAE_PRICE   ] = NULL;
      positions.data[n][I_PROFIT_MARKER_PRICE] = NULL;
      positions.data[n][I_PROFIT_MARKER_PCT  ] = NULL;
      positions.data[n][I_LOSS_MARKER_PRICE  ] = NULL;
      positions.data[n][I_LOSS_MARKER_PCT    ] = NULL;

      pipValue = PipValue(totalPosition, true);                         // suppress a possible ERR_SYMBOL_NOT_AVAILABLE
      if (pipValue != 0) {
         // re-calculate BE level
         positions.data[n][I_BREAKEVEN_PRICE] = NormalizeDouble(openPrice/totalPosition - (totalProfit-floatingProfit)/pipValue*Pip, 8);

         // re-calculate MFE/MAE levels
         if (markMfe) {
            if (config.dData[configLine][I_PROFIT_MFE] != 0) {
               positions.data[n][I_PROFIT_MFE_PRICE] = NormalizeDouble(openPrice/totalPosition - (totalProfit-floatingProfit-config.dData[configLine][I_PROFIT_MFE])/pipValue*Pip, 8);
            }
            if (config.dData[configLine][I_PROFIT_MAE] != 0) {
               positions.data[n][I_PROFIT_MAE_PRICE] = NormalizeDouble(openPrice/totalPosition - (totalProfit-floatingProfit-config.dData[configLine][I_PROFIT_MAE])/pipValue*Pip, 8);
            }
         }

         // re-calculate PM level
         if (profitMarkerPrice != NULL) {
            positions.data[n][I_PROFIT_MARKER_PRICE] = profitMarkerPrice;
            positions.data[n][I_PROFIT_MARKER_PCT  ] = NormalizeDouble((totalProfit - floatingProfit - (openPrice/totalPosition-profitMarkerPrice)/Pip*pipValue)/equity100Pct*100, 1);
         }
         else if (!IsEmptyValue(profitMarkerPct)) {
            positions.data[n][I_PROFIT_MARKER_PRICE] = NormalizeDouble(openPrice/totalPosition - (totalProfit-floatingProfit-profitMarkerPct/100*equity100Pct)/pipValue*Pip, 8);
            positions.data[n][I_PROFIT_MARKER_PCT  ] = profitMarkerPct;
         }

         // re-calculate LM level
         if (lossMarkerPrice != NULL) {
            positions.data[n][I_LOSS_MARKER_PRICE] = lossMarkerPrice;
            positions.data[n][I_LOSS_MARKER_PCT  ] = NormalizeDouble((totalProfit - floatingProfit + (lossMarkerPrice-openPrice/totalPosition)/Pip*pipValue)/equity100Pct*100, 1);
         }
         else if (!IsEmptyValue(lossMarkerPct)) {
            positions.data[n][I_LOSS_MARKER_PRICE] = NormalizeDouble(openPrice/totalPosition - (totalProfit-floatingProfit-lossMarkerPct/100*equity100Pct)/pipValue*Pip, 8);
            positions.data[n][I_LOSS_MARKER_PCT  ] = lossMarkerPct;
         }
      }
      //debug("StoreCustomPosition(0.2)  long:    totalPL="+ DoubleToStr(totalProfit, 2) +"  equity="+ DoubleToStr(equity, 2) +"  equity100%="+ DoubleToStr(equity100Pct, 2) +"  totalProfitTerminal="+ DoubleToStr(totalProfitTerminal, 2));
      return(!catch("StoreCustomPosition(5)"));
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
               // Daten komplett �bernehmen, Ticket auf NULL setzen
               openPrice      += lots[i] * openPrices[i];
               if (tickets[i] > 0) {                                                   // skip open profits of virtual positions
                  openProfitTerminal += swaps[i] + commissions[i] + profits[i];
               }
               swap           += swaps[i];
               commission     += commissions[i];
               floatingProfit += profits[i];
               tickets[i]      = NULL;
               remainingShort  = NormalizeDouble(remainingShort - lots[i], 3);
            }
            else {
               // Daten anteilig �bernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor          = remainingShort/lots[i];
               openPrice      += lots[i] * openPrices[i];
               if (tickets[i] > 0) {
                  openProfitTerminal += swaps[i] + factor * (commissions[i] + profits[i]);
               }
               swap           +=          swaps[i];       swaps      [i]  = 0;
               commission     += factor * commissions[i]; commissions[i] -= factor * commissions[i];
               floatingProfit += factor * profits[i];     profits    [i] -= factor * profits    [i];
                                                          lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 3);
               remainingShort = 0;
            }
         }
      }
      if (remainingShort != 0) return(!catch("StoreCustomPosition(6)  illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of short position = "+ NumberToStr(-totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      positions.data[n][I_CONFIG_LINE     ] = configLine;
      positions.data[n][I_CUSTOM_TYPE     ] = ifInt(isVirtual, CUSTOM_VIRTUAL_POSITION, CUSTOM_REAL_POSITION);
      positions.data[n][I_POSITION_TYPE   ] = POSITION_SHORT;
      positions.data[n][I_DIRECTIONAL_LOTS] = -totalPosition;
      positions.data[n][I_HEDGED_LOTS     ] = hedgedLots;     openProfit          = hedgedProfit + floatingProfit + swap + commission;
      positions.data[n][I_BREAKEVEN_PRICE ] = NULL;           totalProfit         = openProfit + closedProfit + adjustedProfit;
      positions.data[n][I_ADJUSTED_PROFIT ] = adjustedProfit; totalProfitTerminal = openProfitTerminal + closedProfit + adjustedProfit;
      positions.data[n][I_PROFIT          ] = totalProfit;    equity100Pct        = equity - ifDouble(!customEquity && equity > totalProfitTerminal, totalProfitTerminal, 0);
      positions.data[n][I_PROFIT_PCT      ] = MathDiv(totalProfit, equity100Pct) * 100;
      totalProfit = NormalizeDouble(totalProfit, 2);

      markMfe = false;
      if (configLine >= 0) {
         isNewMfe = (config.dData[configLine][I_MFAE_SIGNAL]  && config.dData[configLine][I_PROFIT_MFE] && totalProfit > config.dData[configLine][I_PROFIT_MFE]);
         isNewMae = (config.dData[configLine][I_MFAE_SIGNAL]  && config.dData[configLine][I_PROFIT_MAE] && totalProfit < config.dData[configLine][I_PROFIT_MAE]);
         markMfe  = (config.dData[configLine][I_MFAE_ENABLED] && config.dData[configLine][I_MARK_MFE]);

         config.dData[configLine][I_PROFIT_MFE] = MathMax(totalProfit,    config.dData[configLine][I_PROFIT_MFE]);
         config.dData[configLine][I_PROFIT_MAE] = MathMin(totalProfit,    config.dData[configLine][I_PROFIT_MAE]);
         config.dData[configLine][I_MAX_LOTS  ] = MathMax(-totalPosition, config.dData[configLine][I_MAX_LOTS  ]);
         positions.data[n][I_PROFIT_MFE_PCT]    = MathDiv(config.dData[configLine][I_PROFIT_MFE], equity100Pct) * 100;
         positions.data[n][I_PROFIT_MAE_PCT]    = MathDiv(config.dData[configLine][I_PROFIT_MAE], equity100Pct) * 100;

         if (isNewMfe) onNewMFE(config.sData[configLine][I_CONFIG_KEY], totalProfit);
         if (isNewMae) onNewMAE(config.sData[configLine][I_CONFIG_KEY], totalProfit);
      }

      positions.data[n][I_PROFIT_MFE_PRICE   ] = NULL;
      positions.data[n][I_PROFIT_MAE_PRICE   ] = NULL;
      positions.data[n][I_PROFIT_MARKER_PRICE] = NULL;
      positions.data[n][I_PROFIT_MARKER_PCT  ] = NULL;
      positions.data[n][I_LOSS_MARKER_PRICE  ] = NULL;
      positions.data[n][I_LOSS_MARKER_PCT    ] = NULL;

      pipValue = PipValue(-totalPosition, true);                        // suppress a possible ERR_SYMBOL_NOT_AVAILABLE
      if (pipValue != 0) {
         // re-calculate BE level
         positions.data[n][I_BREAKEVEN_PRICE] = NormalizeDouble((totalProfit-floatingProfit)/pipValue*Pip - openPrice/totalPosition, 8);

         // re-calculate MFE/MAE levels
         if (markMfe) {
            if (config.dData[configLine][I_PROFIT_MFE] != 0) {
               positions.data[n][I_PROFIT_MFE_PRICE] = NormalizeDouble((totalProfit-floatingProfit-config.dData[configLine][I_PROFIT_MFE])/pipValue*Pip - openPrice/totalPosition, 8);
            }
            if (config.dData[configLine][I_PROFIT_MAE] != 0) {
               positions.data[n][I_PROFIT_MAE_PRICE] = NormalizeDouble((totalProfit-floatingProfit-config.dData[configLine][I_PROFIT_MAE])/pipValue*Pip - openPrice/totalPosition, 8);
            }
         }

         // re-calculate PM level
         if (profitMarkerPrice != NULL) {
            positions.data[n][I_PROFIT_MARKER_PRICE] = profitMarkerPrice;
            positions.data[n][I_PROFIT_MARKER_PCT  ] = NormalizeDouble((totalProfit - floatingProfit - (profitMarkerPrice + openPrice/totalPosition)/Pip*pipValue)/equity100Pct*100, 1);
         }
         else if (!IsEmptyValue(profitMarkerPct)) {
            positions.data[n][I_PROFIT_MARKER_PRICE] = NormalizeDouble((totalProfit-floatingProfit-profitMarkerPct/100*equity100Pct)/pipValue*Pip - openPrice/totalPosition, 8);
            positions.data[n][I_PROFIT_MARKER_PCT  ] = profitMarkerPct;
         }

         // re-calculate LM level
         if (lossMarkerPrice != NULL) {
            positions.data[n][I_LOSS_MARKER_PRICE] = lossMarkerPrice;
            positions.data[n][I_LOSS_MARKER_PCT  ] = NormalizeDouble((totalProfit - floatingProfit - (lossMarkerPrice + openPrice/totalPosition)/Pip*pipValue)/equity100Pct*100, 1);
         }
         else if (!IsEmptyValue(lossMarkerPct)) {
            positions.data[n][I_LOSS_MARKER_PRICE] = NormalizeDouble((totalProfit-floatingProfit-lossMarkerPct/100*equity100Pct)/pipValue*Pip - openPrice/totalPosition, 8);
            positions.data[n][I_LOSS_MARKER_PCT  ] = lossMarkerPct;
         }
      }
      //debug("StoreCustomPosition(0.3)  short:   totalPL="+ DoubleToStr(totalProfit, 2) +"  equity="+ DoubleToStr(equity, 2) +"  equity100%="+ DoubleToStr(equity100Pct, 2) +"  totalProfitTerminal="+ DoubleToStr(totalProfitTerminal, 2));
      return(!catch("StoreCustomPosition(7)"));
   }

   // ohne offene Positionen mu� ClosedProfit (kann 0.00 sein) oder AdjustedProfit gesetzt sein
   // History mit leerer Position speichern
   positions.data[n][I_CONFIG_LINE     ] = configLine;
   positions.data[n][I_CUSTOM_TYPE     ] = ifInt(isVirtual, CUSTOM_VIRTUAL_POSITION, CUSTOM_REAL_POSITION);
   positions.data[n][I_POSITION_TYPE   ] = POSITION_HISTORY;
   positions.data[n][I_DIRECTIONAL_LOTS] = NULL;
   positions.data[n][I_HEDGED_LOTS     ] = NULL;
   positions.data[n][I_BREAKEVEN_PRICE ] = NULL;
   positions.data[n][I_ADJUSTED_PROFIT ] = adjustedProfit; totalProfit  = closedProfit + adjustedProfit;
   positions.data[n][I_PROFIT          ] = totalProfit;    equity100Pct = equity - ifDouble(!customEquity && equity > totalProfit, totalProfit, 0);
   positions.data[n][I_PROFIT_PCT      ] = MathDiv(totalProfit, equity100Pct) * 100;
   totalProfit = NormalizeDouble(totalProfit, 2);

   if (configLine >= 0) {
      config.dData[configLine][I_PROFIT_MFE] = MathMax(totalProfit, config.dData[configLine][I_PROFIT_MFE]);
      config.dData[configLine][I_PROFIT_MAE] = MathMin(totalProfit, config.dData[configLine][I_PROFIT_MAE]);
      positions.data[n][I_PROFIT_MFE_PCT]    = MathDiv(config.dData[configLine][I_PROFIT_MFE], equity100Pct) * 100;
      positions.data[n][I_PROFIT_MAE_PCT]    = MathDiv(config.dData[configLine][I_PROFIT_MAE], equity100Pct) * 100;
   }

   positions.data[n][I_PROFIT_MFE_PRICE   ] = NULL;
   positions.data[n][I_PROFIT_MAE_PRICE   ] = NULL;
   positions.data[n][I_PROFIT_MARKER_PRICE] = NULL;
   positions.data[n][I_PROFIT_MARKER_PCT  ] = NULL;
   positions.data[n][I_LOSS_MARKER_PRICE  ] = NULL;
   positions.data[n][I_LOSS_MARKER_PCT    ] = NULL;

   //debug("StoreCustomPosition(0.4)  history: totalPL="+ DoubleToStr(totalProfit, 2) +"  equity="+ DoubleToStr(equity, 2) +"  equity100%="+ DoubleToStr(equity100Pct, 2));
   return(!catch("StoreCustomPosition(8)"));
}


/**
 * Handler f�r beim LFX-Terminal eingehende Messages.
 *
 * @return bool - success status
 */
bool QC.HandleLfxTerminalMessages() {
   if (!__isChart) return(true);

   // (1) ggf. Receiver starten
   if (!hQC.TradeToLfxReceiver) /*&&*/ if (!QC.StartLfxReceiver())
      return(false);

   // (2) Channel auf neue Messages pr�fen
   int checkResult = QC_CheckChannelA(qc.TradeToLfxChannel);
   if (checkResult == QC_CHECK_CHANNEL_EMPTY)
      return(true);
   if (checkResult < QC_CHECK_CHANNEL_EMPTY) {
      if (checkResult == QC_CHECK_CHANNEL_ERROR)  return(!catch("QC.HandleLfxTerminalMessages(1)->MT4iQuickChannel::QC_CheckChannel(name="+ DoubleQuoteStr(qc.TradeToLfxChannel) +") => QC_CHECK_CHANNEL_ERROR",                ERR_WIN32_ERROR));
      if (checkResult == QC_CHECK_CHANNEL_NONE )  return(!catch("QC.HandleLfxTerminalMessages(2)->MT4iQuickChannel::QC_CheckChannel(name="+ DoubleQuoteStr(qc.TradeToLfxChannel) +")  channel doesn't exist",                   ERR_WIN32_ERROR));
                                                  return(!catch("QC.HandleLfxTerminalMessages(3)->MT4iQuickChannel::QC_CheckChannel(name="+ DoubleQuoteStr(qc.TradeToLfxChannel) +")  unexpected return value = "+ checkResult, ERR_WIN32_ERROR));
   }

   // (3) neue Messages abholen
   string messageBuffer[]; if (!ArraySize(messageBuffer)) InitializeStringBuffer(messageBuffer, QC_MAX_BUFFER_SIZE);
   int getResult = QC_GetMessages3A(hQC.TradeToLfxReceiver, messageBuffer, QC_MAX_BUFFER_SIZE);
   if (getResult != QC_GET_MSG3_SUCCESS) {
      if (getResult == QC_GET_MSG3_CHANNEL_EMPTY) return(!catch("QC.HandleLfxTerminalMessages(4)->MT4iQuickChannel::QC_GetMessages3()  QuickChannel mis-match: QC_CheckChannel="+ checkResult +"chars/QC_GetMessages3=CHANNEL_EMPTY", ERR_WIN32_ERROR));
      if (getResult == QC_GET_MSG3_INSUF_BUFFER ) return(!catch("QC.HandleLfxTerminalMessages(5)->MT4iQuickChannel::QC_GetMessages3()  QuickChannel mis-match: QC_CheckChannel="+ checkResult +"chars/QC_MAX_BUFFER_SIZE="+ QC_MAX_BUFFER_SIZE +"/size(buffer)="+ (StringLen(messageBuffer[0])+1) +"/QC_GetMessages3=INSUF_BUFFER", ERR_WIN32_ERROR));
                                                  return(!catch("QC.HandleLfxTerminalMessages(6)->MT4iQuickChannel::QC_GetMessages3()  unexpected return value = "+ getResult, ERR_WIN32_ERROR));
   }

   // (4) Messages verarbeiten: Da hier sehr viele Messages in kurzer Zeit eingehen k�nnen, werden sie zur Beschleunigung statt mit Explode() manuell zerlegt.
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
 *                               Order sind kein Fehler, das Ausl�sen eines Fehlers durch Schicken einer falschen Message ist so nicht
 *                               m�glich. F�r nicht unterst�tzte Messages wird stattdessen eine Warnung ausgegeben.
 *
 * Messageformat: "LFX:{iTicket]:pending={1|0}"   - die angegebene Pending-Order wurde platziert (immer erfolgreich, da im Fehlerfall keine Message generiert wird)
 *                "LFX:{iTicket]:open={1|0}"      - die angegebene Pending-Order wurde ausgef�hrt/konnte nicht ausgef�hrt werden
 *                "LFX:{iTicket]:close={1|0}"     - die angegebene Position wurde geschlossen/konnte nicht geschlossen werden
 *                "LFX:{iTicket]:profit={dValue}" - der PL der angegebenen Position hat sich ge�ndert
 */
bool ProcessLfxTerminalMessage(string message) {
   //debug("ProcessLfxTerminalMessage(1)  tick="+ Ticks +"  msg=\""+ message +"\"");

   // Da hier in kurzer Zeit sehr viele Messages eingehen k�nnen, werden sie zur Beschleunigung statt mit Explode() manuell zerlegt.
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
   if (StringSubstr(message, from, 7) == "profit=") {                         // die h�ufigste Message wird zuerst gepr�ft
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
 *                          FALSE: Liest die LFX-Orderdaten im aktuellen Kontext neu ein. F�r offene Positionen wird im Dateisystem kein PL
 *                                 gespeichert (�ndert sich st�ndig). Stattdessen wird dieser PL in globalen Terminal-Variablen zwischen-
 *                                 gespeichert (schneller) und von dort restauriert.
 * @return bool - success status
 */
bool RestoreLfxOrders(bool fromCache) {
   fromCache = fromCache!=0;

   if (fromCache) {
      // (1) LFX-Orders aus in der Library zwischengespeicherten Daten restaurieren
      int size = ChartInfos.CopyLfxOrders(false, lfxOrders, lfxOrders.iCache, lfxOrders.bCache, lfxOrders.dCache);
      if (size == -1) return(!SetLastError(ERR_RUNTIME_ERROR));

      // Order-Z�hler aktualisieren
      lfxOrders.pendingOrders    = 0;                                               // Diese Z�hler dienen der Beschleunigung, um nicht st�ndig �ber alle Orders
      lfxOrders.openPositions    = 0;                                               // iterieren zu m�ssen.
      lfxOrders.pendingPositions = 0;

      for (int i=0; i < size; i++) {
         lfxOrders.pendingOrders    += lfxOrders.bCache[i][BC.isPendingOrder   ];
         lfxOrders.openPositions    += lfxOrders.bCache[i][BC.isOpenPosition   ];
         lfxOrders.pendingPositions += lfxOrders.bCache[i][BC.isPendingPosition];
      }
      return(true);
   }

   // (2) Orderdaten neu einlesen: Sind wir nicht in einem init()-Cycle, werden im Cache noch vorhandene Daten vorm �berschreiben gespeichert.
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
   if      (mode.intern) {                         flags = OF_OPENPOSITION;     }   // offene Positionen aller LFX-W�hrungen (zum Managen von Profitbetrags-Exit-Limiten)
   else if (mode.extern) { currency = lfxCurrency; flags = OF_OPEN | OF_CLOSED; }   // alle Orders der aktuellen LFX-W�hrung (zur Anzeige)

   size = LFX.GetOrders(currency, flags, lfxOrders); if (size==-1) return(false);

   ArrayResize(lfxOrders.iCache, size);
   ArrayResize(lfxOrders.bCache, size);
   ArrayResize(lfxOrders.dCache, size);

   // Z�hler-Variablen und PL-Daten aktualisieren
   for (i=0; i < size; i++) {
      lfxOrders.iCache[i][IC.ticket           ] = los.Ticket           (lfxOrders, i);
      lfxOrders.bCache[i][BC.isPendingOrder   ] = los.IsPendingOrder   (lfxOrders, i);
      lfxOrders.bCache[i][BC.isOpenPosition   ] = los.IsOpenPosition   (lfxOrders, i);
      lfxOrders.bCache[i][BC.isPendingPosition] = los.IsPendingPosition(lfxOrders, i);

      lfxOrders.pendingOrders    += lfxOrders.bCache[i][BC.isPendingOrder   ];
      lfxOrders.openPositions    += lfxOrders.bCache[i][BC.isOpenPosition   ];
      lfxOrders.pendingPositions += lfxOrders.bCache[i][BC.isPendingPosition];

      if (los.IsOpenPosition(lfxOrders, i)) {                        // TODO: !!! Der Account mu� Teil des Schl�ssels sein.
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
 * Speichert die aktuellen LFX-Order-PLs in globalen Terminal-Variablen. So steht der letzte bekannte PL auch dann zur Verf�gung,
 * wenn das Trade-Terminal nicht l�uft.
 *
 * @return bool - success status
 */
bool SaveLfxOrderCache() {
   string varName = "";
   int size = ArrayRange(lfxOrders.iCache, 0);

   for (int i=0; i < size; i++) {
      if (lfxOrders.bCache[i][BC.isOpenPosition]) {                  // TODO: !!! Der Account mu� Teil des Schl�ssels sein.
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
 * Handler f�r beim Terminal eingehende Trade-Commands.
 *
 * @return bool - success status
 */
bool QC.HandleTradeCommands() {
   if (!__isChart) return(true);

   // (1) ggf. Receiver starten
   if (!hQC.TradeCmdReceiver) /*&&*/ if (!QC.StartTradeCmdReceiver())
      return(false);

   // (2) Channel auf neue Messages pr�fen
   int checkResult = QC_CheckChannelA(qc.TradeCmdChannel);
   if (checkResult == QC_CHECK_CHANNEL_EMPTY)
      return(true);
   if (checkResult < QC_CHECK_CHANNEL_EMPTY) {
      if (checkResult == QC_CHECK_CHANNEL_ERROR)  return(!catch("QC.HandleTradeCommands(1)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeCmdChannel +"\") => QC_CHECK_CHANNEL_ERROR",                ERR_WIN32_ERROR));
      if (checkResult == QC_CHECK_CHANNEL_NONE )  return(!catch("QC.HandleTradeCommands(2)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeCmdChannel +"\")  channel doesn't exist",                   ERR_WIN32_ERROR));
                                                  return(!catch("QC.HandleTradeCommands(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeCmdChannel +"\")  unexpected return value = "+ checkResult, ERR_WIN32_ERROR));
   }

   // (3) neue Messages abholen
   string messageBuffer[]; if (!ArraySize(messageBuffer)) InitializeStringBuffer(messageBuffer, QC_MAX_BUFFER_SIZE);
   int getResult = QC_GetMessages3A(hQC.TradeCmdReceiver, messageBuffer, QC_MAX_BUFFER_SIZE);
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
 * Schickt den Profit der LFX-Positionen ans LFX-Terminal. Pr�ft absolute und prozentuale Limite, wenn sich der Wert seit dem letzten
 * Aufruf ge�ndert hat, und triggert entsprechende Trade-Command.
 *
 * @return bool - success status
 */
bool AnalyzePos.ProcessLfxProfits() {
   string messages[]; ArrayResize(messages, 0); ArrayResize(messages, ArraySize(hQC.TradeToLfxSenders));    // 2 x ArrayResize() = ArrayInitialize()

   int size = ArrayRange(lfxOrders, 0);

   // Urspr�nglich enth�lt lfxOrders[] nur OpenPositions, bei Ausbleiben einer Ausf�hrungsbenachrichtigung k�nnen daraus geschlossene Positionen werden.
   for (int i=0; i < size; i++) {
      if (!EQ(lfxOrders.dCache[i][DC.profit], lfxOrders.dCache[i][DC.lastProfit], 2)) {
         // Profit hat sich ge�ndert: Betrag zu Messages des entsprechenden Channels hinzuf�gen
         double profit = lfxOrders.dCache[i][DC.profit];
         int    cid    = LFX.CurrencyId(lfxOrders.iCache[i][IC.ticket]);
         if (!StringLen(messages[cid])) messages[cid] = StringConcatenate(                    "LFX:", lfxOrders.iCache[i][IC.ticket], ":profit=", DoubleToStr(profit, 2));
         else                           messages[cid] = StringConcatenate(messages[cid], TAB, "LFX:", lfxOrders.iCache[i][IC.ticket], ":profit=", DoubleToStr(profit, 2));

         if (!lfxOrders.bCache[i][BC.isPendingPosition])
            continue;

         // Profitbetrag-Limite pr�fen (Preis-Limite werden vom LFX-Monitor gepr�ft)
         int limitResult = LFX.CheckLimits(lfxOrders, i, NULL, NULL, profit); if (!limitResult) return(false);
         if (limitResult == NO_LIMIT_TRIGGERED)
            continue;

         // Position schlie�en
         if (!LFX.SendTradeCommand(lfxOrders, i, limitResult)) return(false);

         // Ohne Ausf�hrungsbenachrichtigung wurde die Order nach TimeOut neu eingelesen und die PendingPosition ggf. zu einer ClosedPosition.
         if (los.IsClosed(lfxOrders, i)) {
            lfxOrders.bCache[i][BC.isOpenPosition   ] = false;
            lfxOrders.bCache[i][BC.isPendingPosition] = false;
            lfxOrders.openPositions--;
            lfxOrders.pendingPositions--;
         }
      }
   }

   // angesammelte Messages verschicken: Messages je Channel werden gemeinsam und nicht einzeln verschickt, um beim Empf�nger unn�tige Ticks zu vermeiden.
   size = ArraySize(messages);
   for (i=1; i < size; i++) {                                        // Index 0 ist unbenutzt, denn 0 ist keine g�ltige CurrencyId
      if (StringLen(messages[i]) > 0) {
         if (!hQC.TradeToLfxSenders[i]) /*&&*/ if (!QC.StartLfxSender(i))
            return(false);
         if (!QC_SendMessageA(hQC.TradeToLfxSenders[i], messages[i], QC_FLAG_SEND_MSG_IF_RECEIVER))
            return(!catch("AnalyzePos.ProcessLfxProfits(1)->MT4iQuickChannel::QC_SendMessage() = QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));
      }
   }
   return(!catch("AnalyzePos.ProcessLfxProfits(2)"));
}


/**
 * Store the runtime status.
 *  - in the chart:        for init cycles and terminal restart
 *  - in the chart window: for loading of templates
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (!__isChart) return(true);
   string indicatorName = ProgramName();

   // int position.unitsize.corner
   string key = indicatorName +".position.unitsize.corner";
   string sValue = position.unitsize.corner;                               // GetWindowInteger() cannot restore integer 0
   SetWindowStringA(__ExecutionContext[EC.chart], key, sValue);            // chart window
   Chart.StoreString(key, sValue);                                         // chart

   // bool positions.showAbsProfits
   key = indicatorName +".positions.showAbsProfits";
   int iValue = ifInt(positions.showAbsProfits, 1, -1);                    // GetWindowInteger() cannot restore integer 0
   SetWindowIntegerA(__ExecutionContext[EC.chart], key, iValue);           // chart window
   Chart.StoreInt(key, iValue);                                            // chart

   // bool positions.showMaxRisk
   key = indicatorName +".positions.showMaxRisk";
   iValue = ifInt(positions.showMaxRisk, 1, -1);                           // GetWindowInteger() cannot restore integer 0
   SetWindowIntegerA(__ExecutionContext[EC.chart], key, iValue);           // chart window
   Chart.StoreInt(key, iValue);                                            // chart

   // risk/MFE/MAE stats of custom positions
   string keys="", configKey="";
   int size = ArrayRange(config.sData, 0);
   for (int i=0; i < size; i++) {
      configKey = config.sData[i][I_CONFIG_KEY];
      key = indicatorName +"."+ Symbol() +".config."+ configKey +".risk";
      sValue = NumberToStr(config.dData[i][I_MAX_LOTS], ".1+") +"|"+ NumberToStr(config.dData[i][I_MAX_RISK], ".1+");
      SetWindowStringA(__ExecutionContext[EC.chart], key, sValue);         // chart window
      Chart.StoreString(key, sValue);                                      // chart

      if (config.dData[i][I_MFAE_ENABLED] > 0) {
         key = indicatorName +"."+ Symbol() +".config."+ configKey +".mfae";
         sValue = NumberToStr(config.dData[i][I_PROFIT_MFE], ".1+") +"|"+ NumberToStr(config.dData[i][I_PROFIT_MAE], ".1+");
         SetWindowStringA(__ExecutionContext[EC.chart], key, sValue);      // chart window
         Chart.StoreString(key, sValue);                                   // chart
      }
      keys = keys +"="+ configKey;                                         // config keys can't contain equal signs "="
   }

   // config keys of custom positions
   if (size > 0) {
      key = indicatorName +"."+ Symbol() +".config.keys";
      sValue = StrRight(keys, -1);
      SetWindowStringA(__ExecutionContext[EC.chart], key, sValue);         // chart window
      Chart.StoreString(key, sValue);                                      // chart
   }

   // bool display.balance
   key = indicatorName +".display.balance";
   iValue = ifInt(display.balance, 1, -1);                                 // GetWindowInteger() cannot restore integer 0
   SetWindowIntegerA(__ExecutionContext[EC.chart], key, iValue);           // chart window
   Chart.StoreInt(key, iValue);                                            // chart

   // bool display.externalBalance
   key = indicatorName +".display.externalBalance";
   iValue = ifInt(display.externalBalance, 1, -1);                         // GetWindowInteger() cannot restore integer 0
   SetWindowIntegerA(__ExecutionContext[EC.chart], key, iValue);           // chart window
   Chart.StoreInt(key, iValue);                                            // chart

   return(!catch("StoreStatus(1)"));
}


/**
 * Restore a stored runtime status.
 *
 * @return bool - success status
 */
bool RestoreStatus() {
   if (!__isChart) return(true);
   string indicatorName = ProgramName();

   // int position.unitsize.corner
   string key = indicatorName +".position.unitsize.corner";
   string sValue1 = RemoveWindowStringA(__ExecutionContext[EC.chart], key), sValue2="";
   Chart.RestoreString(key, sValue2);
   if (!StringLen(sValue1)) sValue1 = sValue2;
   int iValue = StrToInteger(sValue1);
   position.unitsize.corner = ifInt(iValue == CORNER_TOP_RIGHT, iValue, CORNER_BOTTOM_RIGHT);

   // bool positions.showAbsProfits
   key = indicatorName +".positions.showAbsProfits";
   int iValue1 = RemoveWindowIntegerA(__ExecutionContext[EC.chart], key);  // +1 || -1
   int iValue2 = 0;
   Chart.RestoreInt(key, iValue2);
   positions.showAbsProfits = (iValue1==1 || iValue2==1);

   // bool positions.showMaxRisk
   key = indicatorName +".positions.showMaxRisk";
   iValue1 = RemoveWindowIntegerA(__ExecutionContext[EC.chart], key);      // +1 || -1
   iValue2 = 0;
   Chart.RestoreInt(key, iValue2);
   positions.showMaxRisk = (iValue1==1 || iValue2==1);

   // config keys of custom positions
   string configKeys[];
   key = indicatorName +"."+ Symbol() +".config.keys";
   sValue1 = RemoveWindowStringA(__ExecutionContext[EC.chart], key);
   Chart.RestoreString(key, sValue2);
   if (!StringLen(sValue1)) sValue1 = sValue2;

   // risk/MFE/MAE stats of custom positions
   ArrayResize(config.sData, 0);
   ArrayResize(config.dData, 0);
   int size = Explode(sValue1, "=", configKeys, NULL);

   for (int i=0; i < size; i++) {
      ArrayResize(config.sData, i+1);
      ArrayResize(config.dData, i+1);
      config.sData[i][I_CONFIG_KEY    ] = configKeys[i];
      config.sData[i][I_CONFIG_COMMENT] = "";

      key = indicatorName +"."+ Symbol() +".config."+ configKeys[i] +".risk";
      sValue1 = RemoveWindowStringA(__ExecutionContext[EC.chart], key);
      sValue2 = "";
      Chart.RestoreString(key, sValue2);
      if (!StringLen(sValue1)) sValue1 = sValue2;
      config.dData[i][I_MAX_LOTS] = StrToDouble(StrLeftTo(sValue1, "|"));
      config.dData[i][I_MAX_RISK] = StrToDouble(StrRightFrom(sValue1, "|"));

      key = indicatorName +"."+ Symbol() +".config."+ configKeys[i] +".mfae";
      sValue1 = RemoveWindowStringA(__ExecutionContext[EC.chart], key);
      sValue2 = "";
      Chart.RestoreString(key, sValue2);
      if (!StringLen(sValue1)) sValue1 = sValue2;
      config.dData[i][I_MFAE_ENABLED] = (sValue1 != "");
      config.dData[i][I_PROFIT_MFE  ] = StrToDouble(StrLeftTo(sValue1, "|"));
      config.dData[i][I_PROFIT_MAE  ] = StrToDouble(StrRightFrom(sValue1, "|"));
   }

   // bool display.balance
   key = indicatorName +".display.balance";
   iValue1 = RemoveWindowIntegerA(__ExecutionContext[EC.chart], key);      // +1 || -1
   iValue2 = 0;
   Chart.RestoreInt(key, iValue2);
   display.balance = (iValue1==1 || iValue2==1);

   // bool display.externalBalance
   key = indicatorName +".display.externalBalance";
   iValue1 = RemoveWindowIntegerA(__ExecutionContext[EC.chart], key);      // +1 || -1
   iValue2 = 0;
   Chart.RestoreInt(key, iValue2);
   display.externalBalance = (iValue1==1 || iValue2==1);

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
   /*
   monitoring of entry limits (pendings must be known before)
   ----------------------------------------------------------
   - alle bekannten Pending-Orders auf Status�nderung pr�fen:                    �ber bekannte Orders iterieren
   - alle unbekannten Pending-Orders registrieren:                               �ber alle Tickets(MODE_TRADES) iterieren

   monitoring of exit limits (positions must be known before)
   ----------------------------------------------------------
   - alle bekannten Pending-Orders und Positionen auf OrderClose pr�fen:         �ber bekannte Orders iterieren
   - alle unbekannten Positionen mit und ohne Exit-Limit registrieren:           �ber alle Tickets(MODE_TRADES) iterieren
     (limitlose Positionen k�nnen durch Stopout geschlossen werden/worden sein)

   both together
   -------------
   - alle bekannten Pending-Orders auf Status�nderung pr�fen:                    �ber bekannte Orders iterieren
   - alle bekannten Pending-Orders und Positionen auf OrderClose pr�fen:         �ber bekannte Orders iterieren
   - alle unbekannten Pending-Orders und Positionen registrieren:                �ber alle Tickets(MODE_TRADES) iterieren
   */

   // (1) �ber alle bekannten Orders iterieren (r�ckw�rts, um beim Entfernen von Elementen die Schleife einfacher managen zu k�nnen)
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


   // (2) �ber Tickets(MODE_TRADES) iterieren und alle unbekannten Tickets registrieren (immer Pending-Order oder offene Position)
   while (true) {
      int ordersTotal = OrdersTotal();

      for (i=0; i < ordersTotal; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {                // FALSE: an open order was closed/deleted in another thread
            ordersTotal = -1;                                              // Abbruch und via while-Schleife alles nochmal verarbeiten, bis for() fehlerfrei durchl�uft
            break;
         }
         if (OrderMagicNumber() != 0) continue;                            // skip orders managed by an EA

         for (int n=0; n < sizeOfTrackedOrders; n++) {
            if (trackedOrders[n][TI_TICKET] == OrderTicket()) break;       // Order bereits bekannt
         }
         if (n >= sizeOfTrackedOrders) {                                   // Order unbekannt: in �berwachung aufnehmen
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
      if (OrderType() > OP_SELL)   continue;                // skip pending orders (should not happen)
      if (OrderMagicNumber() != 0) continue;                // skip orders managed by an EA (should not happen)

      bool isMySymbol=(OrderSymbol()==Symbol()), isOtherListener=false;
      if (!isMySymbol) isOtherListener = IsOrderEventListener(OrderSymbol());

      if (isMySymbol || !isOtherListener) {
         string event = "PositionOpen::#"+ OrderTicket();

         if (!IsOrderEventLogged(event)) {
            eventLogged = SetOrderEventLogged(event, true); // immediately update status to prevent parallel execution on slow CPUs

            // #1 Sell 0.1 GBPUSD "L.8692.+3" at 1.5524'8[ instead of 1.5522'0 (better|worse: -2.8 pip)]
            int    digits      = MarketInfo(OrderSymbol(), MODE_DIGITS);
            int    pipDigits   = digits & (~1);
            string priceFormat = ",'R."+ pipDigits + ifString(digits==pipDigits, "", "'");

            if (digits > 2 || OrderOpenPrice() < 20) {      // local vars overlay global vars
               double pUnit   = Pip;
               int    pDigits = 1;
               string spUnit  = " pip";
            }
            else {
               pUnit   = 1.00;
               pDigits = 2;
               spUnit  = "";
            }

            string sType    = OperationTypeDescription(OrderType());
            string sLots    = NumberToStr(OrderLots(), ".+");
            string sComment = ifString(StringLen(OrderComment()), " \""+ OrderComment() +"\"", "");
            string sPrice   = NumberToStr(OrderOpenPrice(), priceFormat);
            double slippage = NormalizeDouble(ifDouble(OrderType()==OP_BUY, data[i][ENTRYLIMIT]-OrderOpenPrice(), OrderOpenPrice()-data[i][ENTRYLIMIT]), digits);
            if (NE(slippage, 0)) {
               sPrice = sPrice +" instead of "+ NumberToStr(data[i][ENTRYLIMIT], priceFormat) +" ("+ ifString(GT(slippage, 0), "better", "worse") +": "+ NumberToStr(slippage/pUnit, "+."+ pDigits) + spUnit +")";
            }
            string message = "#"+ OrderTicket() +" "+ sType +" "+ sLots +" "+ OrderSymbol() + sComment +" at "+ sPrice;
            logInfo("onPositionOpen(2)  "+ message);
            PlaySoundEx(orderTracker.positionOpened);
         }
      }
   }
   OrderPop();

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
      if (OrderType() > OP_SELL)   continue;                // skip pending orders (should not happen)
      if (!OrderCloseTime())       continue;                // skip open positions (should not happen)
      if (OrderMagicNumber() != 0) continue;                // skip orders managed by an EA (should not happen)

      bool isMySymbol=(OrderSymbol()==Symbol()), isOtherListener=false;
      if (!isMySymbol) isOtherListener = IsOrderEventListener(OrderSymbol());

      if (isMySymbol || !isOtherListener) {
         string event = "PositionClose::#"+ OrderTicket();

         if (!IsOrderEventLogged(event)) {
            eventLogged = SetOrderEventLogged(event, true); // immediately update status to prevent parallel execution on slow CPUs

            // #1 Buy 0.6 GBPUSD "SR.1234.+2" from 1.5520'0 at 1.5534'4[ instead of 1.5532'2 (better|worse: -2.8 pip)] [tp]
            int    digits      = MarketInfo(OrderSymbol(), MODE_DIGITS);
            int    pipDigits   = digits & (~1);
            string priceFormat = ",'R."+ pipDigits + ifString(digits==pipDigits, "", "'");

            if (digits > 2 || OrderOpenPrice() < 20) {      // local vars overlay global vars
               double pUnit   = Pip;
               int    pDigits = 1;
               string spUnit  = " pip";
            }
            else {
               pUnit   = 1.00;
               pDigits = 2;
               spUnit  = "";
            }

            string sType       = OperationTypeDescription(OrderType());
            string sLots       = NumberToStr(OrderLots(), ".+");
            string sComment    = ifString(StringLen(OrderComment()), " \""+ OrderComment() +"\"", "");
            string sOpenPrice  = NumberToStr(OrderOpenPrice(), priceFormat);
            string sClosePrice = NumberToStr(OrderClosePrice(), priceFormat);
            double slippage    = 0;
            if      (data[i][CLOSETYPE] == CLOSE_TAKEPROFIT) slippage = NormalizeDouble(ifDouble(OrderType()==OP_BUY, OrderClosePrice()-OrderTakeProfit(), OrderTakeProfit()-OrderClosePrice()), digits);
            else if (data[i][CLOSETYPE] == CLOSE_STOPLOSS)   slippage = NormalizeDouble(ifDouble(OrderType()==OP_BUY, OrderClosePrice()-OrderStopLoss(),   OrderStopLoss()-OrderClosePrice()),   digits);
            if (NE(slippage, 0)) {
               sClosePrice = sClosePrice +" instead of "+ NumberToStr(ifDouble(data[i][CLOSETYPE]==CLOSE_TAKEPROFIT, OrderTakeProfit(), OrderStopLoss()), priceFormat) +" ("+ ifString(GT(slippage, 0), "better", "worse") +": "+ NumberToStr(slippage/pUnit, "+."+ pDigits) + spUnit +")";
            }
            string sCloseType = sCloseTypeDescr[data[i][CLOSETYPE]];
            if (data[i][CLOSETYPE] == CLOSE_STOPOUT) {
               sComment   = "";
               sCloseType = " ["+ OrderComment() +"]";
            }
            string message = "#"+ OrderTicket() +" "+ sType +" "+ sLots +" "+ OrderSymbol() + sComment +" from "+ sOpenPrice +" at "+ sClosePrice + sCloseType;
            logInfo("onPositionClose(2)  "+ message);
            PlaySoundEx(orderTracker.positionClosed);
         }
      }
   }
   OrderPop();

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
            eventLogged = SetOrderEventLogged(event, true);                // immediately update status to prevent parallel execution on slow CPUs

            int    digits      = MarketInfo(OrderSymbol(), MODE_DIGITS);
            int    pipDigits   = digits & (~1);
            string priceFormat = StringConcatenate(",'R.", pipDigits, ifString(digits==pipDigits, "", "'"));

            string sType   = OperationTypeDescription(OrderType() & 1);    // BuyLimit => Buy, SellStop => Sell...
            string sLots   = NumberToStr(OrderLots(), ".+");
            string sPrice  = NumberToStr(OrderOpenPrice(), priceFormat);

            string comment = OrderComment();
            int error = ifInt(comment=="deleted [no money]", ERR_NOT_ENOUGH_MONEY, ERR_RUNTIME_ERROR);
            if (comment != "") comment = " (\""+ comment +"\")";

            string message = "order failed: #"+ OrderTicket() +" "+ sType +" "+ sLots +" "+ OrderSymbol() +" at "+ sPrice + comment;
            logError("onOrderFail(2)  "+ message, error);
            PlaySoundEx(orderTracker.orderFailed);
         }
      }
   }
   OrderPop();

   return(!catch("onOrderFail(3)"));
}


/**
 * Event handler signaling a new PnL high of a custom position.
 *
 * @param  string configKey - key of the custom position
 * @param  double profit    - new PnL value in money
 *
 * @return bool - success status
 */
bool onNewMFE(string configKey, double profit) {
   // convert profit value to cent units (simplifies Get/SetProp)
   int iProfit = MathRound(profit * 100);

   // skip the signal if it already has been signaled elsewhere
   int hWnd = ifInt(__isTesting, __ExecutionContext[EC.chart], GetDesktopWindow());
   string sEvent = GetMfaeSignalKey(configKey, I_PROFIT_MFE);
   if (GetPropA(hWnd, sEvent) >= iProfit) return(true);
   SetPropA(hWnd, sEvent, iProfit);

   PlaySoundEx("Beacon.wav");
   return(!catch("onNewMFE(2)"));

   // used sound files:
   //  Windows Chord.wav
   //  Windows Confirm.wav
   //  Windows Notify.wav
   //  Windows Ping.wav
}


/**
 * Event handler signaling a new PnL low of a custom position.
 *
 * @param  string configKey - key of the custom position
 * @param  double profit    - new PnL value in money
 *
 * @return bool - success status
 */
bool onNewMAE(string configKey, double profit) {
   // convert profit value to cent units (simplifies Get/SetProp)
   int iProfit = MathRound(profit * 100);

   // skip the signal if it already has been signaled elsewhere
   int hWnd = ifInt(__isTesting, __ExecutionContext[EC.chart], GetDesktopWindow());
   string sEvent = GetMfaeSignalKey(configKey, I_PROFIT_MAE);
   if (GetPropA(hWnd, sEvent) <= iProfit) return(true);
   SetPropA(hWnd, sEvent, iProfit);

   PlaySoundEx("Windows Ping.wav");
   return(!catch("onNewMAE(2)"));
}


/**
 * Return the window properties key for a MFE/MAE event.
 *
 * @param  string configKey - configuration key of the custom position
 * @param  int    type      - resulting key type: I_PROFIT_MFE | I_PROFIT_MAE
 *
 * @return string - properties key or an empty string in case of errors
 */
string GetMfaeSignalKey(string configKey, int type) {
   switch (type) {
      case I_PROFIT_MFE: return("rsf::"+ GetAccountNumber() +"."+ configKey +".MFE");
      case I_PROFIT_MAE: return("rsf::"+ GetAccountNumber() +"."+ configKey +".MAE");
   }
   return(_EMPTY_STR(catch("GetMfaeSignalKey(1)  invalid parameter type: "+ type, ERR_INVALID_PARAMETER)));
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
 * Return a readable version of a custom position config term type (values of config.terms[][I_TERM_TYPE]).
 *
 * @param  int type
 *
 * @return string
 */
string ConfigTermTypeToStr(int type) {
   switch (type) {
      case NULL              : return("NULL"              );
      case TERM_TICKET       : return("TERM_TICKET"       );
      case TERM_OPEN_LONG    : return("TERM_OPEN_LONG"    );
      case TERM_OPEN_SHORT   : return("TERM_OPEN_SHORT"   );
      case TERM_OPEN         : return("TERM_OPEN"         );
      case TERM_HISTORY      : return("TERM_HISTORY"      );
      case TERM_HISTORY_TOTAL: return("TERM_HISTORY_TOTAL");
      case TERM_PL_ADJUSTMENT: return("TERM_PL_ADJUSTMENT");
      case TERM_EQUITY       : return("TERM_EQUITY"       );
      case TERM_MFAE         : return("TERM_MFAE"         );
      case TERM_MFAE_SIGNAL  : return("TERM_MFAE_SIGNAL"  );
      case TERM_BE_MARKER    : return("TERM_BE_MARKER"    );
      case TERM_PROFIT_MARKER: return("TERM_PROFIT_MARKER");
      case TERM_LOSS_MARKER  : return("TERM_LOSS_MARKER"  );
   }
   return(_EMPTY_STR(catch("ConfigTermTypeToStr(1)  invalid parameter type: "+ type, ERR_INVALID_PARAMETER)));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Track.Orders=", BoolToStr(Track.Orders), ";"));

   // dummy call to prevent compiler warnings
   ConfigTermTypeToStr(NULL);
}


#import "rsfStdlib.ex4"
   int      ArrayDropInt          (int    &array[], int value);
   int      ArrayInsertDoubleArray(double &array[][], int offset, double values[]);
   int      ArrayInsertDoubles    (double &array[], int offset, double values[]);
   int      ArrayInsertInt        (int    &array[], int offset, int value);
   int      ArrayPushDouble       (double &array[], double value);
   int      ArrayPushDoubles      (double &array[], double values[]);
   int      ArrayPushStrings      (string &array[][], string values[]);
   int      ArraySpliceDoubles    (double &array[], int offset, int length);
   int      ChartInfos.CopyLfxOrders(bool direction, int orders[][], int iData[][], bool bData[][], double dData[][]);
   bool     ChartMarker.OrderSent_A(int ticket, int digits, color markerColor);
   string   DoublesToStr(double array[], string separator);
   string   GetHostName();
   string   GetLongSymbolNameOrAlt(string symbol, string altValue);
   string   GetSymbolName(string symbol);
   string   IntsToStr(int array[], string separator);
   string   PricesToStr(double &array[], string separator);
   int      SearchStringArrayI(string haystack[], string needle);
   bool     SortOpenTickets(int &keys[][]);
   string   StringsToStr(string array[], string separator);
   string   TicketsToStr.Lots    (int array[], string separator);
   string   TicketsToStr.Position(int array[]);
#import
