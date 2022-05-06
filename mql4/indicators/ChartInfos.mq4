/**
 * Displays additional market and account infos on the chart.
 *
 *
 *  - The current price and spread.
 *  - In terminal builds <= 509 the current instrument name.
 *  - The calculated unitsize according to the configured risk profile, see CalculateUnitSize().
 *  - The open position and the used leverage.
 *  - The current account stopout level.
 *  - A warning in different colors when the account's open order limit is approached.
 *  - PL of open positions and/or trade history in two different modes, i.e.
 *     internal: positions and/or history from the current account,
 *               PL as provided by the current account,
 *               order execution notifications
 *     external: positions and/or history from an external account (e.g. synthetic instruments),
 *               PL as provided by the external source,
 *               limit monitoring and notifications
 *
 * TODO:
 *  - don't recalculate unitsize on every tick (every few seconds is sufficient)
 *  - FATAL GER30,M15 ChartInfos::iADR(1)  [ERR_NO_HISTORY_DATA]
 *  - set order tracker sound on stopout to "margin-call"
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Track.Orders   = "on | off | auto*";
extern bool   Offline.Ticker = true;                        // whether to enable self-ticking of offline charts
extern string ___a__________________________;

extern string Signal.Sound   = "on | off | auto*";
extern string Signal.Mail    = "on | off | auto*";
extern string Signal.SMS     = "on | off | auto*";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <functions/ConfigureSignalsByMail.mqh>
#include <functions/ConfigureSignalsBySMS.mqh>
#include <functions/ConfigureSignalsBySound.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <MT4iQuickChannel.mqh>
#include <lfx.mqh>
#include <scriptrunner.mqh>
#include <structs/rsf/LFXOrder.mqh>

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
#define POSITION_CONFIG_TERM_size      40                         // in Bytes
#define POSITION_CONFIG_TERM_doubleSize 5                         // in Doubles

double  positions.config[][POSITION_CONFIG_TERM_doubleSize];      // geparste Konfiguration, Format siehe CustomPositions.ReadConfig()
string  positions.config.comments[];                              // Kommentare konfigurierter Positionen (Arraygröße entspricht positions.config[])

#define TERM_OPEN_LONG                  1                         // ConfigTerm-Types
#define TERM_OPEN_SHORT                 2
#define TERM_OPEN_SYMBOL                3
#define TERM_OPEN_ALL                   4
#define TERM_HISTORY_SYMBOL             5
#define TERM_HISTORY_ALL                6
#define TERM_ADJUSTMENT                 7
#define TERM_EQUITY                     8

// internal + external position data
bool    isPendings;                                               // ob Pending-Limite im Markt liegen (Orders oder Positions)
bool    isPosition;                                               // ob offene Positionen existieren = (longPosition || shortPosition);   // die Gesamtposition kann flat sein
double  totalPosition;
double  longPosition;
double  shortPosition;
int     positions.iData[][3];                                     // Positionsdetails: [ConfigType, PositionType, CommentIndex]
double  positions.dData[][9];                                     //                   [DirectionalLots, HedgedLots, BreakevenPrice|PipDistance, Equity, OpenProfit, ClosedProfit, AdjustedProfit, FullProfitAbs, FullProfitPct]
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
#define I_BREAKEVEN_PRICE               2
#define I_PIP_DISTANCE  I_BREAKEVEN_PRICE
#define I_OPEN_EQUITY                   3
#define I_OPEN_PROFIT                   4
#define I_CLOSED_PROFIT                 5
#define I_ADJUSTED_PROFIT               6
#define I_FULL_PROFIT_ABS               7
#define I_FULL_PROFIT_PCT               8

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

// Textlabel für die einzelnen Anzeigen
string  label.instrument     = "${__NAME__}.Instrument";
string  label.price          = "${__NAME__}.Price";
string  label.spread         = "${__NAME__}.Spread";
string  label.externalAssets = "${__NAME__}.ExternalAssets";
string  label.position       = "${__NAME__}.Position";
string  label.unitSize       = "${__NAME__}.UnitSize";
string  label.orderCounter   = "${__NAME__}.OrderCounter";
string  label.tradeAccount   = "${__NAME__}.TradeAccount";
string  label.stopoutLevel   = "${__NAME__}.StopoutLevel";

// Font-Settings der CustomPositions-Anzeige
string  positions.fontName          = "MS Sans Serif";
int     positions.fontSize          = 8;
color   positions.fontColor.intern  = Blue;
color   positions.fontColor.extern  = Red;
color   positions.fontColor.remote  = Blue;
color   positions.fontColor.virtual = Green;
color   positions.fontColor.history = C'128,128,0';

// Offline-Chartticker
int     tickTimerId;                                              // ID eines ggf. installierten Offline-Tickers
int     hWndTerminal;                                             // handle of the terminal main window (for listener registration)

// order tracking
bool    orderTracker.enabled;
int     orderTracker.tickets[];                                   // order tickets known at the last call
int     orderTracker.types  [];                                   // types of known orders

// Close-Typen für automatisch geschlossene Positionen
#define CLOSE_TYPE_TP               1                             // TakeProfit
#define CLOSE_TYPE_SL               2                             // StopLoss
#define CLOSE_TYPE_SO               3                             // StopOut (Margin-Call)

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
   mm.done            = false;
   positions.analyzed = false;

   HandleCommands();                                                                // ChartCommands verarbeiten

   if (!UpdatePrice())                     if (IsLastError()) return(last_error);   // aktualisiert die Kursanzeige oben rechts

   if (mode.extern) {
      if (!QC.HandleLfxTerminalMessages()) if (IsLastError()) return(last_error);   // bei einem LFX-Terminal eingehende QuickChannel-Messages verarbeiten
      if (!UpdatePositions())              if (IsLastError()) return(last_error);   // aktualisiert die Positionsanzeigen unten rechts (gesamt) und links (detailliert)
   }
   else {
      if (!QC.HandleTradeCommands())       if (IsLastError()) return(last_error);   // bei einem Trade-Terminal eingehende QuickChannel-Messages verarbeiten
      if (!UpdateSpread())                 if (IsLastError()) return(last_error);
      if (!UpdateUnitSize())               if (IsLastError()) return(last_error);   // akualisiert die UnitSize-Anzeige unten rechts
      if (!UpdatePositions())              if (IsLastError()) return(last_error);   // aktualisiert die Positionsanzeigen unten rechts (gesamt) und unten links (detailliert)
      if (!UpdateStopoutLevel())           if (IsLastError()) return(last_error);   // aktualisiert die Markierung des Stopout-Levels im Chart
      if (!UpdateOrderCounter())           if (IsLastError()) return(last_error);   // aktualisiert die Anzeige der Anzahl der offenen Orders

      if (mode.intern && orderTracker.enabled) {                                    // order tracking
         int failedOrders   [];    ArrayResize(failedOrders,    0);
         int openedPositions[];    ArrayResize(openedPositions, 0);
         int closedPositions[][2]; ArrayResize(closedPositions, 0);                 // {Ticket, CloseType=[CLOSE_TYPE_TP|CLOSE_TYPE_SL|CLOSE_TYPE_SO]}

         if (!OrderTracker.CheckPositions(failedOrders, openedPositions, closedPositions))
            return(last_error);

         if (ArraySize(failedOrders   ) > 0) onOrderFail    (failedOrders);
         if (ArraySize(openedPositions) > 0) onPositionOpen (openedPositions);
         if (ArraySize(closedPositions) > 0) onPositionClose(closedPositions);
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
   ArrayResize(orderTracker.tickets, 0);
   ArrayResize(orderTracker.types,   0);
   return(onInit());
}


/**
 * Handle incoming commands.
 *
 * @param  string commands[] - received external commands
 *
 * @return bool - success status
 *
 * Messageformat: "cmd=account:[{companyId}:{account}]" - Schaltet den externen Account um.
 *                "cmd=ToggleOpenOrders"                - Schaltet die Anzeige der offenen Orders ein/aus.
 *                "cmd=ToggleTradeHistory"              - Schaltet die Anzeige der Trade-History ein/aus.
 *                "cmd=ToggleAccountBalance"            - Schaltet die AccountBalance-Anzeige ein/aus.
 */
bool onCommand(string commands[]) {
   int size = ArraySize(commands);
   if (!size) return(!logWarn("onCommand(1)  empty parameter commands: {}"));

   for (int i=0; i < size; i++) {
      if (commands[i] == "cmd=LogPositionTickets") {
         if (!Positions.LogTickets())
            return(false);
         continue;
      }
      if (commands[i] == "cmd=ToggleProfits") {
         if (!Positions.ToggleProfits())
            return(false);
         continue;
      }
      if (commands[i] == "cmd=ToggleAccountBalance") {
         if (!ToggleAccountBalance())
            return(false);
         continue;
      }
      if (commands[i] == "cmd=ToggleOpenOrders") {
         if (!ToggleOpenOrders())
            return(false);
         continue;
      }
      if (commands[i] == "cmd=ToggleTradeHistory") {
         if (!ToggleTradeHistory())
            return(false);
         continue;
      }
      if (StrStartsWith(commands[i], "cmd=account:")) {
         string key = StrRightFrom(commands[i], ":");
         if (!InitTradeAccount(key))  return(false);
         if (!UpdateAccountDisplay()) return(false);
         ArrayResize(positions.config,          0);
         ArrayResize(positions.config.comments, 0);
         continue;
      }
      logWarn("onCommand(2)  unknown command: \""+ commands[i] +"\"");
   }
   return(!catch("onCommand(3)"));
}


/**
 * Whether a chart command was sent to the indicator. If true the command is retrieved and returned.
 *
 * @param  _InOut_ string &commands[] - array to add received commands to
 *
 * @return bool
 */
bool EventListener_ChartCommand(string &commands[]) {
   if (!__isChart) return(false);

   static string label="", mutex=""; if (!StringLen(label)) {
      label = ProgramName() +".command";
      mutex = "mutex."+ label;
   }

   // check for a command non-synchronized (read-only access) to prevent aquiring the lock on every tick
   if (ObjectFind(label) == 0) {
      // now aquire the lock for read-write access
      if (AquireLock(mutex, true)) {
         ArrayPushString(commands, ObjectDescription(label));
         ObjectDelete(label);
         return(ReleaseLock(mutex));
      }
   }
   return(false);
}


/**
 * Toggle the display of open orders.
 *
 * @return bool - success status
 */
bool ToggleOpenOrders() {
   // read current status and toggle it
   bool showOrders = !GetOpenOrderDisplayStatus();

   // ON: display open orders
   if (showOrders) {
      int orders = ShowOpenOrders();
      if (orders == -1) return(false);
      if (!orders) {                                  // Without open orders status must be reset to have the "off" section
         showOrders = false;                          // remove any existing open order markers.
         PlaySoundEx("Plonk.wav");
      }
   }

   // OFF: remove open order markers
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

   // store current status in the chart
   SetOpenOrderDisplayStatus(showOrders);

   if (This.IsTesting())
      WindowRedraw();
   return(!catch("ToggleOpenOrders(1)"));
}


/**
 * Display the currently open orders.
 *
 * @return int - number of displayed orders or EMPTY (-1) in case of errors
 */
int ShowOpenOrders() {
   int      orders, ticket, type, colors[]={CLR_OPEN_LONG, CLR_OPEN_SHORT};
   datetime openTime;
   double   lots, units, openPrice, takeProfit, stopLoss;
   string   comment="", label1="", label2="", label3="", sTP="", sSL="", types[]={"buy", "sell", "buy limit", "sell limit", "buy stop", "sell stop"};

   // mode.intern
   if (mode.intern) {
      orders = OrdersTotal();

      for (int i=0, n; i < orders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))         // FALSE: an order was closed/deleted in another thread
            break;
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

         if (OrderType() > OP_SELL) {
            // a pending order
            label1 = StringConcatenate("#", ticket, " ", types[type], " ", DoubleToStr(lots, 2), " at ", NumberToStr(openPrice, PriceFormat));

            // display pending order marker
            if (ObjectFind(label1) == 0)
               ObjectDelete(label1);
            if (ObjectCreate(label1, OBJ_ARROW, 0, TimeServer(), openPrice)) {
               ObjectSet    (label1, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
               ObjectSet    (label1, OBJPROP_COLOR,     CLR_OPEN_PENDING);
               ObjectSetText(label1, comment);
            }
         }
         else {
            // an open position
            label1 = StringConcatenate("#", ticket, " ", types[type], " ", DoubleToStr(lots, 2), " at ", NumberToStr(openPrice, PriceFormat));

            // display TakeProfit marker
            if (takeProfit != NULL) {
               sTP    = StringConcatenate("TP: ", NumberToStr(takeProfit, PriceFormat));
               label2 = StringConcatenate(label1, ",  ", sTP);
               if (ObjectFind(label2) == 0)
                  ObjectDelete(label2);
               if (ObjectCreate(label2, OBJ_ARROW, 0, TimeServer(), takeProfit)) {
                  ObjectSet    (label2, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE  );
                  ObjectSet    (label2, OBJPROP_COLOR,     CLR_OPEN_TAKEPROFIT);
                  ObjectSetText(label2, comment);
               }
            }
            else sTP = "";

            // display StopLoss marker
            if (stopLoss != NULL) {
               sSL    = StringConcatenate("SL: ", NumberToStr(stopLoss, PriceFormat));
               label3 = StringConcatenate(label1, ",  ", sSL);
               if (ObjectFind(label3) == 0)
                  ObjectDelete(label3);
               if (ObjectCreate(label3, OBJ_ARROW, 0, TimeServer(), stopLoss)) {
                  ObjectSet    (label3, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
                  ObjectSet    (label3, OBJPROP_COLOR,     CLR_OPEN_STOPLOSS);
                  ObjectSetText(label3, comment);
               }
            }
            else sSL = "";

            // display open position marker
            if (ObjectFind(label1) == 0)
               ObjectDelete(label1);
            if (ObjectCreate(label1, OBJ_ARROW, 0, openTime, openPrice)) {
               ObjectSet    (label1, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
               ObjectSet    (label1, OBJPROP_COLOR,     colors[type]    );
               ObjectSetText(label1, StrTrim(StringConcatenate(comment, "   ", sTP, "   ", sSL)));
            }
         }
         n++;
      }
      return(n);
   }

   // mode.extern
   orders = ArrayRange(lfxOrders, 0);

   for (i=0, n=0; i < orders; i++) {
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
         label1 = StringConcatenate("#", ticket, " ", types[type], " ", DoubleToStr(units, 1), " at ", NumberToStr(openPrice, PriceFormat));

         // Order anzeigen
         if (ObjectFind(label1) == 0)
            ObjectDelete(label1);
         if (ObjectCreate(label1, OBJ_ARROW, 0, TimeServer(), openPrice)) {
            ObjectSet(label1, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
            ObjectSet(label1, OBJPROP_COLOR,     CLR_OPEN_PENDING);
         }
      }
      else {
         // offene Position
         label1 = StringConcatenate("#", ticket, " ", types[type], " ", DoubleToStr(units, 1), " at ", NumberToStr(openPrice, PriceFormat));

         // TakeProfit anzeigen                                   // TODO: !!! TP fixen, wenn tpValue oder tpPercent angegeben sind
         if (takeProfit != NULL) {
            sTP    = StringConcatenate("TP: ", NumberToStr(takeProfit, PriceFormat));
            label2 = StringConcatenate(label1, ",  ", sTP);
            if (ObjectFind(label2) == 0)
               ObjectDelete(label2);
            if (ObjectCreate(label2, OBJ_ARROW, 0, TimeServer(), takeProfit)) {
               ObjectSet(label2, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE  );
               ObjectSet(label2, OBJPROP_COLOR,     CLR_OPEN_TAKEPROFIT);
            }
         }
         else sTP = "";

         // StopLoss anzeigen                                     // TODO: !!! SL fixen, wenn slValue oder slPercent angegeben sind
         if (stopLoss != NULL) {
            sSL    = StringConcatenate("SL: ", NumberToStr(stopLoss, PriceFormat));
            label3 = StringConcatenate(label1, ",  ", sSL);
            if (ObjectFind(label3) == 0)
               ObjectDelete(label3);
            if (ObjectCreate(label3, OBJ_ARROW, 0, TimeServer(), stopLoss)) {
               ObjectSet(label3, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
               ObjectSet(label3, OBJPROP_COLOR,     CLR_OPEN_STOPLOSS);
            }
         }
         else sSL = "";

         // Order anzeigen
         if (ObjectFind(label1) == 0)
            ObjectDelete(label1);
         if (ObjectCreate(label1, OBJ_ARROW, 0, openTime, openPrice)) {
            ObjectSet(label1, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
            ObjectSet(label1, OBJPROP_COLOR,     colors[type]    );
            if (StrStartsWith(comment, "#")) comment = StringConcatenate(lfxCurrency, ".", StrToInteger(StrSubstr(comment, 1)));
            else                             comment = "";
            ObjectSetText(label1, StrTrim(StringConcatenate(comment, "   ", sTP, "   ", sSL)));
         }
      }
      n++;
   }
   return(n);
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
   if (ObjectFind(label) == 0) {
      string sValue = ObjectDescription(label);
      if (StrIsInteger(sValue))
         status = (StrToInteger(sValue) != 0);
      ObjectDelete(label);
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
 * @return bool - success status
 */
bool ToggleTradeHistory() {
   // read current status and toggle it
   bool showHistory = !GetTradeHistoryDisplayStatus();

   // ON: display closed trades
   if (showHistory) {
      int trades = ShowTradeHistory();
      if (trades == -1) return(false);
      if (!trades) {                                  // Without closed trades status must be reset to have the "off" section
         showHistory = false;                         // remove any existing closed trade markers.
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

   // store current status in the chart
   SetTradeHistoryDisplayStatus(showHistory);

   if (This.IsTesting())
      WindowRedraw();
   return(!catch("ToggleTradeHistory(1)"));
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
   if (ObjectFind(label) == 0) {
      string sValue = ObjectDescription(label);
      if (StrIsInteger(sValue))
         status = (StrToInteger(sValue) != 0);
      ObjectDelete(label);
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
 * Display the currently available trade history.
 *
 * @return int - number of displayed closed positions or EMPTY (-1) in case of errors
 */
int ShowTradeHistory() {
   int      orders, ticket, type, markerColors[]={CLR_CLOSED_LONG, CLR_CLOSED_SHORT}, lineColors[]={Blue, Red};
   datetime openTime, closeTime;
   double   lots, units, openPrice, closePrice, openEquity, profit;
   string   sOpenPrice="", sClosePrice="", text="", openLabel="", lineLabel="", closeLabel="", sTypes[]={"buy", "sell"};

   // Anzeigekonfiguration auslesen
   string file    = GetAccountConfigPath(tradeAccount.company, tradeAccount.number); if (!StringLen(file)) return(EMPTY);
   string section = "Chart";
   string key     = "TradeHistory.ConnectTrades";
   bool drawConnectors = GetIniBool(file, section, key, GetConfigBool(section, key, true));  // prefer trade account configuration

   // mode.intern
   if (mode.intern) {
      // Sortierschlüssel aller geschlossenen Positionen auslesen und nach {CloseTime, OpenTime, Ticket} sortieren
      orders = OrdersHistoryTotal();
      int sortKeys[][3];                                                // {CloseTime, OpenTime, Ticket}
      ArrayResize(sortKeys, orders);

      for (int n, i=0; i < orders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {            // FALSE: während des Auslesens wurde der Anzeigezeitraum der History verkürzt
            orders = i;
            break;
         }
         if (OrderSymbol() != Symbol()) continue;
         if (OrderType()   >  OP_SELL ) continue;

         sortKeys[n][0] = OrderCloseTime();
         sortKeys[n][1] = OrderOpenTime();
         sortKeys[n][2] = OrderTicket();
         n++;
      }
      orders = n;
      ArrayResize(sortKeys, orders);
      SortClosedTickets(sortKeys);

      // Tickets sortiert einlesen
      int      tickets    []; ArrayResize(tickets,     0);
      int      types      []; ArrayResize(types,       0);
      double   lotSizes   []; ArrayResize(lotSizes,    0);
      datetime openTimes  []; ArrayResize(openTimes,   0);
      datetime closeTimes []; ArrayResize(closeTimes,  0);
      double   openPrices []; ArrayResize(openPrices,  0);
      double   closePrices[]; ArrayResize(closePrices, 0);
      double   commissions[]; ArrayResize(commissions, 0);
      double   swaps      []; ArrayResize(swaps,       0);
      double   profits    []; ArrayResize(profits,     0);
      string   comments   []; ArrayResize(comments,    0);
      int      magics     []; ArrayResize(magics,      0);

      for (i=0; i < orders; i++) {
         if (!SelectTicket(sortKeys[i][2], "ShowTradeHistory(1)"))
            return(-1);
         ArrayPushInt   (tickets,     OrderTicket()     );
         ArrayPushInt   (types,       OrderType()       );
         ArrayPushDouble(lotSizes,    OrderLots()       );
         ArrayPushInt   (openTimes,   OrderOpenTime()   );
         ArrayPushInt   (closeTimes,  OrderCloseTime()  );
         ArrayPushDouble(openPrices,  OrderOpenPrice()  );
         ArrayPushDouble(closePrices, OrderClosePrice() );
         ArrayPushDouble(commissions, OrderCommission() );
         ArrayPushDouble(swaps,       OrderSwap()       );
         ArrayPushDouble(profits,     OrderProfit()     );
         ArrayPushString(comments,    OrderComment()    );
         ArrayPushInt   (magics,      OrderMagicNumber());
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
               if (tickets[n] == ticket)
                  break;
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
         if (!tickets[i])                                            // verworfene Hedges überspringen
            continue;
         sOpenPrice  = NumberToStr(openPrices [i], PriceFormat);
         sClosePrice = NumberToStr(closePrices[i], PriceFormat);
         text        = OrderMarkerText(types[i], magics[i], comments[i]);

         // Open-Marker anzeigen
         openLabel = StringConcatenate("#", tickets[i], " ", sTypes[types[i]], " ", DoubleToStr(lotSizes[i], 2), " at ", sOpenPrice);
         if (ObjectFind(openLabel) == 0)
            ObjectDelete(openLabel);
         if (ObjectCreate(openLabel, OBJ_ARROW, 0, openTimes[i], openPrices[i])) {
            ObjectSet    (openLabel, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
            ObjectSet    (openLabel, OBJPROP_COLOR, markerColors[types[i]]);
            ObjectSetText(openLabel, text);
         }

         // Trendlinie anzeigen
         if (drawConnectors) {
            lineLabel = StringConcatenate("#", tickets[i], " ", sOpenPrice, " -> ", sClosePrice);
            if (ObjectFind(lineLabel) == 0)
               ObjectDelete(lineLabel);
            if (ObjectCreate(lineLabel, OBJ_TREND, 0, openTimes[i], openPrices[i], closeTimes[i], closePrices[i])) {
               ObjectSet    (lineLabel, OBJPROP_RAY  , false               );
               ObjectSet    (lineLabel, OBJPROP_STYLE, STYLE_DOT           );
               ObjectSet    (lineLabel, OBJPROP_COLOR, lineColors[types[i]]);
               ObjectSet    (lineLabel, OBJPROP_BACK , true                );
            }
         }

         // Close-Marker anzeigen                                    // "#1 buy 0.10 GBPUSD at 1.53024 close[ by tester] at 1.52904"
         closeLabel = StringConcatenate(openLabel, " close at ", sClosePrice);
         if (ObjectFind(closeLabel) == 0)
            ObjectDelete(closeLabel);
         if (ObjectCreate(closeLabel, OBJ_ARROW, 0, closeTimes[i], closePrices[i])) {
            ObjectSet    (closeLabel, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
            ObjectSet    (closeLabel, OBJPROP_COLOR, CLR_CLOSED);
            ObjectSetText(closeLabel, text);
         }
         n++;
      }
      return(n);
   }


   // mode.extern
   orders = ArrayRange(lfxOrders, 0);

   for (i=0, n=0; i < orders; i++) {
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
      if (ObjectFind(openLabel) == 0)
         ObjectDelete(openLabel);
      if (ObjectCreate(openLabel, OBJ_ARROW, 0, openTime, openPrice)) {
         ObjectSet    (openLabel, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN  );
         ObjectSet    (openLabel, OBJPROP_COLOR    , markerColors[type]);
            if (positions.absoluteProfits || !openEquity) text = ifString(profit > 0, "+", "") + DoubleToStr(profit, 2);
            else                                          text = ifString(profit > 0, "+", "") + DoubleToStr(profit/openEquity * 100, 2) +"%";
         ObjectSetText(openLabel, text);
      }

      // Trendlinie anzeigen
      if (drawConnectors) {
         lineLabel = StringConcatenate("#", ticket, " ", sOpenPrice, " -> ", sClosePrice);
         if (ObjectFind(lineLabel) == 0)
            ObjectDelete(lineLabel);
         if (ObjectCreate(lineLabel, OBJ_TREND, 0, openTime, openPrice, closeTime, closePrice)) {
            ObjectSet    (lineLabel, OBJPROP_RAY  , false           );
            ObjectSet    (lineLabel, OBJPROP_STYLE, STYLE_DOT       );
            ObjectSet    (lineLabel, OBJPROP_COLOR, lineColors[type]);
            ObjectSet    (lineLabel, OBJPROP_BACK , true            );
         }
      }

      // Close-Marker anzeigen                                    // "#1 buy 0.10 GBPUSD at 1.53024 close[ by tester] at 1.52904"
      closeLabel = StringConcatenate(openLabel, " close at ", sClosePrice);
      if (ObjectFind(closeLabel) == 0)
         ObjectDelete(closeLabel);
      if (ObjectCreate(closeLabel, OBJ_ARROW, 0, closeTime, closePrice)) {
         ObjectSet    (closeLabel, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
         ObjectSet    (closeLabel, OBJPROP_COLOR    , CLR_CLOSED       );
         ObjectSetText(closeLabel, text);
      }
      n++;
   }
   return(n);
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
 * Schaltet die Anzeige der PL-Beträge der Positionen zwischen "absolut" und "prozentual" um.
 *
 * @return bool - Erfolgsstatus
 */
bool Positions.ToggleProfits() {
   positions.absoluteProfits = !positions.absoluteProfits;     // aktuellen Anzeigestatus umschalten

   if (!UpdatePositions()) return(false);                      // Positionsanzeige aktualisieren
   if (GetTradeHistoryDisplayStatus())                         // ggf. TradeHistory aktualisieren
      ShowTradeHistory();

   return(!catch("Positions.ToggleProfits(1)"));
}


/**
 * Toggle the display of the account balance.
 *
 * @return bool - success status
 */
bool ToggleAccountBalance() {
   // get current display status and toggle it
   bool enabled = !GetAccountBalanceDisplayStatus();

   if (enabled) {
      string sBalance = " ";
      if (mode.intern) {
         sBalance = "Balance: " + DoubleToStr(AccountBalance(), 2) +" "+ AccountCurrency();
      }
      else {
         enabled = false;                                      // mode.extern not yet implemented
         PlaySoundEx("Plonk.wav");
      }
      ObjectSetText(label.externalAssets, sBalance, 9, "Tahoma", SlateGray);
   }
   else {
      ObjectSetText(label.externalAssets, " ", 1);
   }

   int error = GetLastError();
   if (error && error!=ERR_OBJECT_DOES_NOT_EXIST)              // on ObjectDrag or opened "Properties" dialog
      return(!catch("AccountBalance(1)", error));

   // store current display status
   SetAuMDisplayStatus(enabled);

   if (This.IsTesting())
      WindowRedraw();
   return(!catch("AccountBalance(2)"));
}


/**
 * Return the stored account balance display status.
 *
 * @return bool - status: enabled/disabled
 */
bool GetAccountBalanceDisplayStatus() {
   // TODO: Status statt im Chart im Fenster lesen/schreiben
   string label = ProgramName() +".AuMDisplay.status";
   if (ObjectFind(label) != -1)
      return(StrToInteger(ObjectDescription(label)) != 0);
   return(false);
}


/**
 * Speichert den angegebenen AuM-Anzeigestatus im Chart.
 *
 * @param  bool status - Status
 *
 * @return bool - Erfolgsstatus
 */
bool SetAuMDisplayStatus(bool status) {
   status = status!=0;

   // TODO: Status statt im Chart im Fenster lesen/schreiben
   string label = ProgramName() +".AuMDisplay.status";
   if (ObjectFind(label) == -1)
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);

   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, ""+ status, 0);

   return(!catch("SetAuMDisplayStatus(1)"));
}


/**
 * Erzeugt die einzelnen ChartInfo-Label.
 *
 * @return bool - Erfolgsstatus
 */
bool CreateLabels() {
   // Label definieren
   string programName = ProgramName();
   label.instrument     = StrReplace(label.instrument,     "${__NAME__}", programName);
   label.price          = StrReplace(label.price,          "${__NAME__}", programName);
   label.spread         = StrReplace(label.spread,         "${__NAME__}", programName);
   label.externalAssets = StrReplace(label.externalAssets, "${__NAME__}", programName);
   label.position       = StrReplace(label.position,       "${__NAME__}", programName);
   label.unitSize       = StrReplace(label.unitSize,       "${__NAME__}", programName);
   label.orderCounter   = StrReplace(label.orderCounter,   "${__NAME__}", programName);
   label.tradeAccount   = StrReplace(label.tradeAccount,   "${__NAME__}", programName);
   label.stopoutLevel   = StrReplace(label.stopoutLevel,   "${__NAME__}", programName);

   // Instrument-Label: Anzeige wird sofort (und nur hier) gesetzt
   int build = GetTerminalBuild();
   if (build <= 509) {                                                                    // Builds größer 509 haben oben links eine {Symbol,Period}-Anzeige, die das
      if (ObjectFind(label.instrument) == 0)                                              // Label überlagert und sich nicht ohne weiteres ausblenden läßt.
         ObjectDelete(label.instrument);
      if (ObjectCreate(label.instrument, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label.instrument, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet    (label.instrument, OBJPROP_XDISTANCE, ifInt(build < 479, 4, 13));   // Builds größer 478 haben oben links einen Pfeil fürs One-Click-Trading,
         ObjectSet    (label.instrument, OBJPROP_YDISTANCE, ifInt(build < 479, 1,  3));   // das Instrument-Label wird dort entsprechend versetzt positioniert.
         RegisterObject(label.instrument);
      }
      else GetLastError();
      string name = GetLongSymbolNameOrAlt(Symbol(), GetSymbolName(Symbol()));
      if      (StrEndsWithI(Symbol(), "_ask")) name = StringConcatenate(name, " (Ask)");
      else if (StrEndsWithI(Symbol(), "_avg")) name = StringConcatenate(name, " (Avg)");
      ObjectSetText(label.instrument, name, 9, "Tahoma Fett", Black);
   }

   // Price-Label
   if (ObjectFind(label.price) == 0)
      ObjectDelete(label.price);
   if (ObjectCreate(label.price, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.price, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label.price, OBJPROP_XDISTANCE, 14);
      ObjectSet    (label.price, OBJPROP_YDISTANCE, 15);
      ObjectSetText(label.price, " ", 1);
      RegisterObject(label.price);
   }
   else GetLastError();

   // Spread-Label
   if (ObjectFind(label.spread) == 0)
      ObjectDelete(label.spread);
   if (ObjectCreate(label.spread, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.spread, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label.spread, OBJPROP_XDISTANCE, 33);
      ObjectSet    (label.spread, OBJPROP_YDISTANCE, 38);
      ObjectSetText(label.spread, " ", 1);
      RegisterObject(label.spread);
   }
   else GetLastError();

   // OrderCounter-Label
   if (ObjectFind(label.orderCounter) == 0)
      ObjectDelete(label.orderCounter);
   if (ObjectCreate(label.orderCounter, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.orderCounter, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet    (label.orderCounter, OBJPROP_XDISTANCE, 500);
      ObjectSet    (label.orderCounter, OBJPROP_YDISTANCE,   9);
      ObjectSetText(label.orderCounter, " ", 1);
      RegisterObject(label.orderCounter);
   }
   else GetLastError();

   // Assets-under-Management-Label
   if (ObjectFind(label.externalAssets) == 0)
      ObjectDelete(label.externalAssets);
   if (ObjectCreate(label.externalAssets, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.externalAssets, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet    (label.externalAssets, OBJPROP_XDISTANCE, 330);
      ObjectSet    (label.externalAssets, OBJPROP_YDISTANCE,   9);
      ObjectSetText(label.externalAssets, " ", 1);
      RegisterObject(label.externalAssets);
   }
   else GetLastError();


   // Gesamt-Positions-Label
   if (ObjectFind(label.position) == 0)
      ObjectDelete(label.position);
   if (ObjectCreate(label.position, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.position, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet    (label.position, OBJPROP_XDISTANCE,  9);
      ObjectSet    (label.position, OBJPROP_YDISTANCE, 29);
      ObjectSetText(label.position, " ", 1);
      RegisterObject(label.position);
   }
   else GetLastError();


   // UnitSize-Label
   if (ObjectFind(label.unitSize) == 0)
      ObjectDelete(label.unitSize);
   if (ObjectCreate(label.unitSize, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.unitSize, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet    (label.unitSize, OBJPROP_XDISTANCE, 9);
      ObjectSet    (label.unitSize, OBJPROP_YDISTANCE, 9);
      ObjectSetText(label.unitSize, " ", 1);
      RegisterObject(label.unitSize);
   }
   else GetLastError();


   // TradeAccount-Label
   if (ObjectFind(label.tradeAccount) == 0)
      ObjectDelete(label.tradeAccount);
   if (ObjectCreate(label.tradeAccount, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.tradeAccount, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet    (label.tradeAccount, OBJPROP_XDISTANCE, 6);
      ObjectSet    (label.tradeAccount, OBJPROP_YDISTANCE, 4);
      ObjectSetText(label.tradeAccount, " ", 1);
      RegisterObject(label.tradeAccount);
   }
   else GetLastError();

   return(!catch("CreateLabels(1)"));
}


/**
 * Aktualisiert die Kursanzeige oben rechts.
 *
 * @return bool - Erfolgsstatus
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
 * Update the spread display.
 *
 * @return bool - success status
 */
bool UpdateSpread() {
   string sSpread = " ";
   if (Bid > 0)                                          // no display if the symbol is not yet subscribed (e.g. start, account/template change, offline chart)
      sSpread = PipToStr((Ask-Bid)/Pip);                 // don't use MarketInfo(MODE_SPREAD) as in tester it's invalid

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
   if (IsTesting())             return(true);            // skip in tester
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
 * Update the position display bottom-right (total postion) and bottom-left (custom positions).
 *
 * @return bool - success status
 */
bool UpdatePositions() {
   if (!positions.analyzed) {
      if (!AnalyzePositions())   return(false);                // on error
   }
   if (mode.intern && !mm.done) {
      if (!CalculateUnitSize())  return(false);                // on error
      if (!mm.done)              return(true);                 // on terminal not yet ready
   }

   // total position bottom-right
   string sCurrentPosition = "";
   if      (!isPosition)    sCurrentPosition = " ";
   else if (!totalPosition) sCurrentPosition = StringConcatenate("Position:    ±", NumberToStr(longPosition, ",'.+"), " lot (hedged)");
   else {
      string sUnits = "";
      double currentUnits;
      if (mm.leveragedLotsNormalized != 0) {
         currentUnits = MathAbs(totalPosition)/mm.leveragedLotsNormalized;
         sUnits = StringConcatenate("U", DoubleToStr(currentUnits, 1), "    ");
      }
      string sRisk = "";
      if (mm.riskPercent && currentUnits) {
         sRisk = StringConcatenate("R", DoubleToStr(mm.riskPercent * currentUnits, 0), "%    ");
      }
      string sCurrentLeverage = "";
      if (mm.unleveragedLots != 0) sCurrentLeverage = StringConcatenate("L", DoubleToStr(MathAbs(totalPosition)/mm.unleveragedLots, 1), "    ");

      sCurrentPosition = StringConcatenate("Position:    ", sRisk, sUnits, sCurrentLeverage, NumberToStr(totalPosition, "+, .+"), " lot");
   }
   ObjectSetText(label.position, sCurrentPosition, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (error && error!=ERR_OBJECT_DOES_NOT_EXIST)              // on ObjectDrag or opened "Properties" dialog
      return(!catch("UpdatePositions(1)", error));

   // PendingOrder-Marker unten rechts ein-/ausblenden
   string label = ProgramName() +".PendingTickets";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (isPendings) {
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE,                       12);
         ObjectSet    (label, OBJPROP_YDISTANCE, ifInt(isPosition, 48, 30));
         ObjectSetText(label, "n", 6, "Webdings", Orange);     // Webdings: runder Marker, orange="Notice"
         RegisterObject(label);
      }
   }

   // Einzelpositionsanzeige unten links
   static int  col.xShifts[], cols, percentCol, commentCol, yDist=3, lines;
   static bool lastAbsoluteProfits;
   if (!ArraySize(col.xShifts) || positions.absoluteProfits!=lastAbsoluteProfits) {
      if (positions.absoluteProfits) {
         // Spalten:         Type: Lots   BE:  BePrice   Profit: Amount Percent   Comment
         // col.xShifts[] = {20,   66,    149, 177,      243,    282,   369,      430};
         ArrayResize(col.xShifts, 8);
         col.xShifts[0] =  20;
         col.xShifts[1] =  66;
         col.xShifts[2] = 149;
         col.xShifts[3] = 177;
         col.xShifts[4] = 243;
         col.xShifts[5] = 282;
         col.xShifts[6] = 369;
         col.xShifts[7] = 430;
      }
      else {
         // Spalten:         Type: Lots   BE:  BePrice   Profit: Percent   Comment
         // col.xShifts[] = {20,   66,    149, 177,      243,    282,      343};
         ArrayResize(col.xShifts, 7);
         col.xShifts[0] =  20;
         col.xShifts[1] =  66;
         col.xShifts[2] = 149;
         col.xShifts[3] = 177;
         col.xShifts[4] = 243;
         col.xShifts[5] = 282;
         col.xShifts[6] = 343;
      }
      cols                = ArraySize(col.xShifts);
      percentCol          = cols - 2;
      commentCol          = cols - 1;
      lastAbsoluteProfits = positions.absoluteProfits;

      // nach Reinitialisierung alle vorhandenen Zeilen löschen
      while (lines > 0) {
         for (int col=0; col < 8; col++) {                     // alle Spalten testen: mit und ohne absoluten Beträgen
            label = StringConcatenate(label.position, ".line", lines, "_col", col);
            if (ObjectFind(label) != -1)
               ObjectDelete(label);
         }
         lines--;
      }
   }
   int iePositions = ArrayRange(positions.iData, 0), positions;
   if (mode.extern) positions = lfxOrders.openPositions;
   else             positions = iePositions;

   // zusätzlich benötigte Zeilen hinzufügen
   while (lines < positions) {
      lines++;
      for (col=0; col < cols; col++) {
         label = StringConcatenate(label.position, ".line", lines, "_col", col);
         if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
            ObjectSet    (label, OBJPROP_CORNER, CORNER_BOTTOM_LEFT);
            ObjectSet    (label, OBJPROP_XDISTANCE, col.xShifts[col]              );
            ObjectSet    (label, OBJPROP_YDISTANCE, yDist + (lines-1)*(positions.fontSize+8));
            ObjectSetText(label, " ", 1);
            RegisterObject(label);
         }
         else GetLastError();
      }
   }

   // nicht benötigte Zeilen löschen
   while (lines > positions) {
      for (col=0; col < cols; col++) {
         label = StringConcatenate(label.position, ".line", lines, "_col", col);
         if (ObjectFind(label) != -1)
            ObjectDelete(label);
      }
      lines--;
   }

   // Zeilen von unten nach oben schreiben: "{Type}: {Lots}   BE|Dist: {Price|Pip}   Profit: [{Amount} ]{Percent}   {Comment}"
   string sLotSize="", sDistance="", sBreakeven="", sAdjustedProfit="", sProfitPct="", sComment="";
   color  fontColor;
   int    line;

   // Anzeige interne/externe Positionsdaten
   if (!mode.extern) {
      for (int i=iePositions-1; i >= 0; i--) {
         line++;
         if      (positions.iData[i][I_CONFIG_TYPE  ] == CONFIG_VIRTUAL  ) fontColor = positions.fontColor.virtual;
         else if (positions.iData[i][I_POSITION_TYPE] == POSITION_HISTORY) fontColor = positions.fontColor.history;
         else if (mode.intern)                                             fontColor = positions.fontColor.intern;
         else                                                              fontColor = positions.fontColor.extern;

         if (!positions.dData[i][I_ADJUSTED_PROFIT])     sAdjustedProfit = "";
         else                                            sAdjustedProfit = StringConcatenate(" (", DoubleToStr(positions.dData[i][I_ADJUSTED_PROFIT], 2), ")");

         if ( positions.iData[i][I_COMMENT_INDEX] == -1) sComment = " ";
         else                                            sComment = positions.config.comments[positions.iData[i][I_COMMENT_INDEX]];

         // Nur History
         if (positions.iData[i][I_POSITION_TYPE] == POSITION_HISTORY) {
            // "{Type}: {Lots}   BE|Dist: {Price|Pip}   Profit: [{Amount} ]{Percent}   {Comment}"
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col0"           ), typeDescriptions[positions.iData[i][I_POSITION_TYPE]],                   positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col1"           ), " ",                                                                     positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col2"           ), " ",                                                                     positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col3"           ), " ",                                                                     positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col4"           ), "Profit:",                                                               positions.fontSize, positions.fontName, fontColor);
            if (positions.absoluteProfits)
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col5"           ), DoubleToStr(positions.dData[i][I_FULL_PROFIT_ABS], 2) + sAdjustedProfit, positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col", percentCol), DoubleToStr(positions.dData[i][I_FULL_PROFIT_PCT], 2) +"%",              positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col", commentCol), sComment,                                                                positions.fontSize, positions.fontName, fontColor);
         }

         // Directional oder Hedged
         else {
            // "{Type}: {Lots}   BE|Dist: {Price|Pip}   Profit: [{Amount} ]{Percent}   {Comment}"
            // Hedged
            if (positions.iData[i][I_POSITION_TYPE] == POSITION_HEDGE) {
               ObjectSetText(StringConcatenate(label.position, ".line", line, "_col0"), typeDescriptions[positions.iData[i][I_POSITION_TYPE]],                           positions.fontSize, positions.fontName, fontColor);
               ObjectSetText(StringConcatenate(label.position, ".line", line, "_col1"),      NumberToStr(positions.dData[i][I_HEDGED_LOTS  ], ".+") +" lot",             positions.fontSize, positions.fontName, fontColor);
               ObjectSetText(StringConcatenate(label.position, ".line", line, "_col2"), "Dist:",                                                                         positions.fontSize, positions.fontName, fontColor);
                  if (!positions.dData[i][I_PIP_DISTANCE]) sDistance = "...";
                  else                                     sDistance = PipToStr(positions.dData[i][I_PIP_DISTANCE], true, true);
               ObjectSetText(StringConcatenate(label.position, ".line", line, "_col3"), sDistance,                                                                       positions.fontSize, positions.fontName, fontColor);
            }

            // Not Hedged
            else {
               ObjectSetText(StringConcatenate(label.position, ".line", line, "_col0"), typeDescriptions[positions.iData[i][I_POSITION_TYPE]],                           positions.fontSize, positions.fontName, fontColor);
                  if (!positions.dData[i][I_HEDGED_LOTS]) sLotSize = NumberToStr(positions.dData[i][I_DIRECTIONAL_LOTS], ".+");
                  else                                    sLotSize = NumberToStr(positions.dData[i][I_DIRECTIONAL_LOTS], ".+") +" ±"+ NumberToStr(positions.dData[i][I_HEDGED_LOTS], ".+");
               ObjectSetText(StringConcatenate(label.position, ".line", line, "_col1"), sLotSize +" lot",                                                                positions.fontSize, positions.fontName, fontColor);
               ObjectSetText(StringConcatenate(label.position, ".line", line, "_col2"), "BE:",                                                                           positions.fontSize, positions.fontName, fontColor);
                  if (!positions.dData[i][I_BREAKEVEN_PRICE]) sBreakeven = "...";
                  else                                        sBreakeven = NumberToStr(positions.dData[i][I_BREAKEVEN_PRICE], PriceFormat);
               ObjectSetText(StringConcatenate(label.position, ".line", line, "_col3"), sBreakeven,                                                                      positions.fontSize, positions.fontName, fontColor);
            }

            // Hedged und Not-Hedged
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col4"           ), "Profit:",                                                               positions.fontSize, positions.fontName, fontColor);
            if (positions.absoluteProfits)
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col5"           ), DoubleToStr(positions.dData[i][I_FULL_PROFIT_ABS], 2) + sAdjustedProfit, positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col", percentCol), DoubleToStr(positions.dData[i][I_FULL_PROFIT_PCT], 2) +"%",              positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col", commentCol), sComment,                                                                positions.fontSize, positions.fontName, fontColor);
         }
      }
   }

   // Anzeige Remote-Positionsdaten
   if (mode.extern) {
      fontColor = positions.fontColor.remote;
      for (i=ArrayRange(lfxOrders, 0)-1; i >= 0; i--) {
         if (lfxOrders.bCache[i][BC.isOpenPosition]) {
            line++;
            // "{Type}: {Lots}   BE|Dist: {Price|Pip}   Profit: [{Amount} ]{Percent}   {Comment}"
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col0"           ), typeDescriptions[los.Type(lfxOrders, i)+1],                              positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col1"           ), NumberToStr(los.Units    (lfxOrders, i), ".+") +" units",                positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col2"           ), "BE:",                                                                   positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col3"           ), NumberToStr(los.OpenPrice(lfxOrders, i), PriceFormat),                   positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col4"           ), "Profit:",                                                               positions.fontSize, positions.fontName, fontColor);
            if (positions.absoluteProfits)
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col5"           ), DoubleToStr(lfxOrders.dCache[i][DC.profit], 2),                          positions.fontSize, positions.fontName, fontColor);
               double profitPct = lfxOrders.dCache[i][DC.profit] / los.OpenEquity(lfxOrders, i) * 100;
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col", percentCol), DoubleToStr(profitPct, 2) +"%",                                          positions.fontSize, positions.fontName, fontColor);
               sComment = StringConcatenate(los.Comment(lfxOrders, i), " ");
               if (StringGetChar(sComment, 0) == '#')
                  sComment = StringConcatenate(lfxCurrency, ".", StrSubstr(sComment, 1));
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col", commentCol), sComment,                                                                positions.fontSize, positions.fontName, fontColor);
         }
      }
   }

   return(!catch("UpdatePositions(3)"));
}


/**
 * Aktualisiert die Anzeige der aktuellen Anzahl und des Limits der offenen Orders.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateOrderCounter() {
   static int   showLimit   =INT_MAX,   warnLimit=INT_MAX,    alertLimit=INT_MAX, maxOpenOrders;
   static color defaultColor=SlateGray, warnColor=DarkOrange, alertColor=Red;

   if (!maxOpenOrders) {
      maxOpenOrders = GetGlobalConfigInt("Accounts", GetAccountNumber() +".maxOpenTickets.total", -1);
      if (!maxOpenOrders)
         maxOpenOrders = -1;
      if (maxOpenOrders > 0) {
         alertLimit = Min(Round(0.9  * maxOpenOrders), maxOpenOrders-5);
         warnLimit  = Min(Round(0.75 * maxOpenOrders), alertLimit   -5);
         showLimit  = Min(Round(0.5  * maxOpenOrders), warnLimit    -5);
      }
   }

   string sText = " ";
   color  objectColor = defaultColor;

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
 * @return bool - Erfolgsstatus
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
 * Aktualisiert die Anzeige des aktuellen Stopout-Levels.
 *
 * @return bool - Erfolgsstatus
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
   double soEquity   = AccountStopoutLevel(); if (soMode != MSM_ABSOLUTE) soEquity /= (100/usedMargin);
   double tickSize   = MarketInfo(Symbol(), MODE_TICKSIZE );
   double tickValue  = MarketInfo(Symbol(), MODE_TICKVALUE) * MathAbs(totalPosition);  // TickValue der aktuellen Position
   if (!Bid || !tickSize || !tickValue)
      return(!SetLastError(ERR_SYMBOL_NOT_AVAILABLE));                                 // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
   double soDistance = (equity - soEquity)/tickValue * tickSize;
   double soPrice;
   if (totalPosition > 0) soPrice = NormalizeDouble(Bid - soDistance, Digits);
   else                   soPrice = NormalizeDouble(Ask + soDistance, Digits);

   // Stopout-Preis anzeigen
   if (ObjectFind(label.stopoutLevel) == -1) {
      ObjectCreate (label.stopoutLevel, OBJ_HLINE, 0, 0, 0);
      ObjectSet    (label.stopoutLevel, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet    (label.stopoutLevel, OBJPROP_COLOR, OrangeRed  );
      ObjectSet    (label.stopoutLevel, OBJPROP_BACK , true       );
      RegisterObject(label.stopoutLevel);
   }
   ObjectSet(label.stopoutLevel, OBJPROP_PRICE1, soPrice);
      if (soMode == MSM_PERCENT) string text = StringConcatenate("Stopout  ", Round(AccountStopoutLevel()), "%  =  ", NumberToStr(soPrice, PriceFormat));
      else                              text = StringConcatenate("Stopout  ", DoubleToStr(soEquity, 2), AccountCurrency(), "  =  ", NumberToStr(soPrice, PriceFormat));
   ObjectSetText(label.stopoutLevel, text);

   error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                               // on ObjectDrag or opened "Properties" dialog
      return(true);
   return(!catch("UpdateStopoutLevel(2)", error));
}


/**
 * Wrapper für AnalyzePositions(bool logTickets=TRUE) für onCommand()-Handler.
 *
 * @return bool - Erfolgsstatus
 */
bool Positions.LogTickets() {
   return(AnalyzePositions(true));
}


/**
 * Ermittelt die aktuelle Positionierung, gruppiert sie je nach individueller Konfiguration und berechnet deren Kennziffern.
 *
 * @param  bool logTickets [optional] - ob die Tickets der einzelnen Positionen geloggt werden sollen (default: nein)
 *
 * @return bool - Erfolgsstatus
 */
bool AnalyzePositions(bool logTickets = false) {
   logTickets = logTickets!=0;
   if (logTickets)         positions.analyzed = false;                           // vorm Loggen werden die Positionen immer re-evaluiert
   if (mode.extern)        positions.analyzed = true;
   if (positions.analyzed) return(true);

   int      tickets    [], openPositions;                                        // Positionsdetails
   int      types      [];
   double   lots       [];
   datetime openTimes  [];
   double   openPrices [];
   double   commissions[];
   double   swaps      [];
   double   profits    [];

   // Gesamtposition ermitteln
   longPosition  = 0;                                                            // globale Variablen
   shortPosition = 0;
   isPendings    = false;

   // mode.intern
   if (mode.intern) {
      bool lfxProfits = false;
      int pos, orders = OrdersTotal();
      int sortKeys[][2];                                                         // Sortierschlüssel der offenen Positionen: {OpenTime, Ticket}
      ArrayResize(sortKeys, orders);

      // Sortierschlüssel auslesen und dabei PL von LFX-Positionen erfassen (alle Symbole).
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
   longPosition  = NormalizeDouble(longPosition,  2);                            // globale Variablen
   shortPosition = NormalizeDouble(shortPosition, 2);
   totalPosition = NormalizeDouble(longPosition - shortPosition, 2);
   isPosition    = longPosition || shortPosition;

   // Positionen analysieren und in positions.*Data[] speichern
   if (ArrayRange(positions.iData, 0) > 0) {
      ArrayResize(positions.iData, 0);
      ArrayResize(positions.dData, 0);
   }

   // individuelle Konfiguration parsen
   int oldError = last_error;
   SetLastError(NO_ERROR);
   if (ArrayRange(positions.config, 0)==0) /*&&*/ if (!CustomPositions.ReadConfig()) {
      positions.analyzed = !last_error;                                          // MarketInfo()-Daten stehen ggf. noch nicht zur Verfügung,
      if (!last_error) SetLastError(oldError);                                   // in diesem Fall nächster Versuch beim nächsten Tick.
      return(positions.analyzed);
   }
   SetLastError(oldError);

   int    termType, confLineIndex;
   double termValue1, termValue2, termCache1, termCache2, customLongPosition, customShortPosition, customTotalPosition, closedProfit=EMPTY_VALUE, adjustedProfit, customEquity, _longPosition=longPosition, _shortPosition=shortPosition, _totalPosition=totalPosition;
   bool   isCustomVirtual;
   int    customTickets    [];
   int    customTypes      [];
   double customLots       [];
   double customOpenPrices [];
   double customCommissions[];
   double customSwaps      [];
   double customProfits    [];

   // individuell konfigurierte Positionen aus den offenen Positionen extrahieren
   int confSize = ArrayRange(positions.config, 0);

   for (i=0, confLineIndex=0; i < confSize; i++) {
      termType   = positions.config[i][0];
      termValue1 = positions.config[i][1];
      termValue2 = positions.config[i][2];
      termCache1 = positions.config[i][3];
      termCache2 = positions.config[i][4];

      if (!termType) {                                                           // termType=NULL => "Zeilenende"
         if (logTickets) LogTickets(customTickets, confLineIndex);

         // individuell konfigurierte Position speichern
         if (!StorePosition(isCustomVirtual, customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLots, customOpenPrices, customCommissions, customSwaps, customProfits, closedProfit, adjustedProfit, customEquity, confLineIndex))
            return(false);
         isCustomVirtual     = false;
         customLongPosition  = 0;
         customShortPosition = 0;
         customTotalPosition = 0;
         closedProfit        = EMPTY_VALUE;
         adjustedProfit      = 0;
         customEquity        = 0;
         ArrayResize(customTickets    , 0);
         ArrayResize(customTypes      , 0);
         ArrayResize(customLots       , 0);
         ArrayResize(customOpenPrices , 0);
         ArrayResize(customCommissions, 0);
         ArrayResize(customSwaps      , 0);
         ArrayResize(customProfits    , 0);
         confLineIndex++;
         continue;
      }
      if (!ExtractPosition(termType, termValue1, termValue2, termCache1, termCache2,
                           _longPosition,      _shortPosition,      _totalPosition,      tickets,       types,       lots,       openTimes, openPrices,       commissions,       swaps,       profits,
                           customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLots,            customOpenPrices, customCommissions, customSwaps, customProfits, closedProfit, adjustedProfit, customEquity,
                           isCustomVirtual))
         return(false);
      positions.config[i][3] = termCache1;
      positions.config[i][4] = termCache2;
   }

   if (logTickets) LogTickets(tickets, -1);

   // verbleibende Position(en) speichern
   if (!StorePosition(false, _longPosition, _shortPosition, _totalPosition, tickets, types, lots, openPrices, commissions, swaps, profits, EMPTY_VALUE, 0, 0, -1))
      return(false);

   positions.analyzed = true;
   return(!catch("AnalyzePositions(2)"));
}


/**
 * Loggt die Tickets einer Zeile der Positionsanzeige.
 *
 * @return bool - success status
 */
bool LogTickets(int tickets[], int commentIndex) {
   if (ArraySize(tickets) > 0) {
      string sIndex = "-";
      string sComment = "";

      if (commentIndex > -1) {
         sIndex = commentIndex;
         if (StringLen(positions.config.comments[commentIndex]) > 0) {
            sComment = "\""+ positions.config.comments[commentIndex] +"\" = ";
         }
      }
      string sPosition = TicketsToStr.Position(tickets);
      sPosition = ifString(sPosition=="0 lot", "", sPosition +" = ");

      string sTickets = TicketsToStr.Lots(tickets, NULL);

      logDebug("LogTickets(1)  conf("+ sIndex +"): "+ sComment + sPosition + sTickets);
   }
   return(true);
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

   // @see declaration of global vars mm.* for their descriptions
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
   mm.equity = accountEquity + GetExternalAssets(tradeAccount.company, tradeAccount.number, false);

   // recalculate lot value and unleveraged unitsize
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   int error = GetLastError();
   if (error || !Close[0] || !tickSize || !tickValue || !mm.equity) {   // may happen on terminal start, on account change, on template change or in offline charts
      if (!error || error==ERR_SYMBOL_NOT_AVAILABLE)
         return(!SetLastError(ERS_TERMINAL_NOT_YET_READY));
      return(!catch("CalculateUnitSize(1)", error));
   }
   mm.lotValue        = Close[0]/tickSize * tickValue;                  // value of 1 lot in account currency
   mm.unleveragedLots = mm.equity/mm.lotValue;                          // unleveraged unitsize

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
 * Liest die individuelle Positionskonfiguration ein und speichert sie in einem binären Format.
 *
 * @return bool - Erfolgsstatus
 *
 *
 * Füllt das Array positions.config[][] mit den Konfigurationsdaten des aktuellen Instruments in der Accountkonfiguration. Das Array enthält
 * danach Elemente im Format {type, value1, value2, ...}.  Ein NULL-Term-Element {NULL, ...} markiert ein Zeilenende bzw. eine leere
 * Konfiguration. Nach einer eingelesenen Konfiguration ist die Größe der ersten Dimension des Arrays niemals 0. Positionskommentare werden
 * in positions.config.comments[] gespeichert.
 *
 *
 *  Notation:                                        Beschreibung:                                                            Arraydarstellung:
 *  ---------                                        -------------                                                            -----------------
 *   0.1#123456                                      - O.1 Lot eines Tickets (1)                                              [123456             , 0.1             , ...             , ...     , ...     ]
 *      #123456                                      - komplettes Ticket oder verbleibender Rest eines Tickets                [123456             , EMPTY           , ...             , ...     , ...     ]
 *   0.2L                                            - mit Lotsize: virtuelle Long-Position zum aktuellen Preis (2)           [TERM_OPEN_LONG     , 0.2             , NULL            , ...     , ...     ]
 *   0.3S[@]1.2345                                   - mit Lotsize: virtuelle Short-Position zum angegebenen Preis (2)        [TERM_OPEN_SHORT    , 0.3             , 1.2345          , ...     , ...     ]
 *      L                                            - ohne Lotsize: alle verbleibenden Long-Positionen                       [TERM_OPEN_LONG     , EMPTY           , ...             , ...     , ...     ]
 *      S                                            - ohne Lotsize: alle verbleibenden Short-Positionen                      [TERM_OPEN_SHORT    , EMPTY           , ...             , ...     , ...     ]
 *   O{DateTime}                                     - offene Positionen des aktuellen Symbols eines Standard-Zeitraums (3)   [TERM_OPEN_SYMBOL   , 2014.01.01 00:00, 2014.12.31 23:59, ...     , ...     ]
 *   OT{DateTime}-{DateTime}                         - offene Positionen aller Symbole von und bis zu einem Zeitpunkt (3)(4)  [TERM_OPEN_ALL      , 2014.02.01 08:00, 2014.02.10 18:00, ...     , ...     ]
 *   H{DateTime}             [Monthly|Weekly|Daily]  - Trade-History des aktuellen Symbols eines Standard-Zeitraums (3)(5)    [TERM_HISTORY_SYMBOL, 2014.01.01 00:00, 2014.12.31 23:59, {cache1}, {cache2}]
 *   HT{DateTime}-{DateTime} [Monthly|Weekly|Daily]  - Trade-History aller Symbole von und bis zu einem Zeitpunkt (3)(4)(5)   [TERM_HISTORY_ALL   , 2014.02.01 08:00, 2014.02.10 18:00, {cache1}, {cache2}]
 *   12.34                                           - dem PL einer Position zuzuschlagender Betrag                           [TERM_ADJUSTMENT    , 12.34           , ...             , ...     , ...     ]
 *   E123.00                                         - für Equityberechnungen zu verwendender Wert                            [TERM_EQUITY        , 123.00          , ...             , ...     , ...     ]
 *
 *   Kommentar (Text nach dem ersten Semikolon ";")  - wird als Beschreibung angezeigt
 *   Kommentare in Kommentaren (nach weiterem ";")   - werden ignoriert
 *
 *
 *  Beispiel:
 *  ---------
 *   [CustomPositions]
 *   GBPAUD.0 = #111111, 0.1#222222      ;  komplettes Ticket #111111 und 0.1 Lot von Ticket #222222
 *   GBPAUD.1 = 0.2L, #222222            ;; virtuelle 0.2 Lot Long-Position und Rest von #222222 (2)
 *   GBPAUD.3 = L,S,-34.56               ;; alle verbleibenden Positionen, inkl. eines Restes von #222222, zzgl. eines Verlustes von -34.56
 *   GBPAUD.3 = 0.5L                     ;; Zeile wird ignoriert, da der Schlüssel "GBPAUD.3" bereits verarbeitet wurde
 *   GBPAUD.2 = 0.3S                     ;; virtuelle 0.3 Lot Short-Position, wird als letzte angezeigt (6)
 *
 *
 *  Resultierendes Array:
 *  ---------------------
 *  positions.config = [
 *     [111111         , EMPTY, ... , ..., ...], [222222         , 0.1  , ..., ..., ...],                                           [NULL, ..., ..., ..., ...],
 *     [TERM_OPEN_LONG , 0.2  , NULL, ..., ...], [222222         , EMPTY, ..., ..., ...],                                           [NULL, ..., ..., ..., ...],
 *     [TERM_OPEN_LONG , EMPTY, ... , ..., ...], [TERM_OPEN_SHORT, EMPTY, ..., ..., ...], [TERM_ADJUSTMENT, -34.45, ..., ..., ...], [NULL, ..., ..., ..., ...],
 *     [TERM_OPEN_SHORT, 0.3  , NULL, ..., ...],                                                                                    [NULL, ..., ..., ..., ...],
 *  ];
 *
 *  (1) Bei einer Lotsize von 0 wird die Teilposition ignoriert.
 *  (2) Werden reale mit virtuellen Positionen kombiniert, wird die Position virtuell und nicht von der aktuellen Gesamtposition abgezogen.
 *      Dies kann in Verbindung mit (1) benutzt werden, um eine virtuelle Position zu konfigurieren, die die folgenden Positionen nicht
        beeinflußt (z.B. durch "0L").
 *  (3) Zeitangaben im Format: 2014[.01[.15 [W|12:30[:45]]]]
 *  (4) Einer der beiden Zeitpunkte kann leer sein und steht jeweils für "von Beginn" oder "bis Ende".
 *  (5) Ein Historyzeitraum kann tages-, wochen- oder monatsweise gruppiert werden, solange er nicht mit anderen Positionen kombiniert wird.
 *  (6) Die Positionen werden nicht sortiert und in der Reihenfolge ihrer Notierung angezeigt.
 */
bool CustomPositions.ReadConfig() {
   if (ArrayRange(positions.config, 0) > 0) {
      ArrayResize(positions.config,          0);
      ArrayResize(positions.config.comments, 0);
   }

   string   keys[], values[], iniValue="", comment="", confComment="", openComment="", hstComment="", strSize="", strTicket="", strPrice="", sNull, symbol=Symbol(), stdSymbol=StdSymbol();
   double   termType, termValue1, termValue2, termCache1, termCache2, lotSize, minLotSize=MarketInfo(symbol, MODE_MINLOT), lotStep=MarketInfo(symbol, MODE_LOTSTEP);
   int      valuesSize, confSize, pos, ticket, positionStartOffset;
   datetime from, to;
   bool     isPositionEmpty, isPositionVirtual, isPositionGrouped, isTotal;
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

            // Kommentar auswerten
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

            // Konfiguration auswerten
            isPositionEmpty   = true;                                // ob die resultierende Position bereits Daten enthält oder nicht
            isPositionVirtual = false;                               // ob die resultierende Position virtuell ist
            isPositionGrouped = false;                               // ob die resultierende Position gruppiert ist
            valuesSize        = Explode(StrToUpper(iniValue), ",", values, NULL);

            for (int n=0; n < valuesSize; n++) {
               values[n] = StrTrim(values[n]);
               if (!StringLen(values[n]))                            // Leervalue
                  continue;

               if (StrStartsWith(values[n], "H")) {                  // H[T] = History[Total]
                  if (!CustomPositions.ParseHstTerm(values[n], confComment, hstComment, isPositionEmpty, isPositionGrouped, isTotal, from, to)) return(false);
                  if (isPositionGrouped) {
                     isPositionEmpty = false;
                     continue;                                       // gruppiert: die Konfiguration wurde bereits in CustomPositions.ParseHstTerm() gespeichert
                  }
                  termType   = ifInt(!isTotal, TERM_HISTORY_SYMBOL, TERM_HISTORY_ALL);
                  termValue1 = from;                                 // nicht gruppiert
                  termValue2 = to;
                  termCache1 = EMPTY_VALUE;                          // EMPTY_VALUE, da NULL bei TERM_HISTORY_* ein gültiger Wert ist
                  termCache2 = EMPTY_VALUE;
               }

               else if (StrStartsWith(values[n], "#")) {             // Ticket
                  strTicket = StrTrim(StrSubstr(values[n], 1));
                  if (!StrIsDigit(strTicket))                        return(!catch("CustomPositions.ReadConfig(2)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-digits in ticket \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termType   = StrToInteger(strTicket);
                  termValue1 = EMPTY;                                // alle verbleibenden Lots
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrStartsWith(values[n], "L")) {             // alle verbleibenden Long-Positionen
                  if (values[n] != "L")                              return(!catch("CustomPositions.ReadConfig(3)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termType   = TERM_OPEN_LONG;
                  termValue1 = EMPTY;
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrStartsWith(values[n], "S")) {             // alle verbleibenden Short-Positionen
                  if (values[n] != "S")                              return(!catch("CustomPositions.ReadConfig(4)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termType   = TERM_OPEN_SHORT;
                  termValue1 = EMPTY;
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrStartsWith(values[n], "O")) {             // O[T] = die verbleibenden Positionen [aller Symbole] eines Zeitraums
                  if (!CustomPositions.ParseOpenTerm(values[n], openComment, isTotal, from, to)) return(false);
                  termType   = ifInt(!isTotal, TERM_OPEN_SYMBOL, TERM_OPEN_ALL);
                  termValue1 = from;
                  termValue2 = to;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrStartsWith(values[n], "E")) {             // E = Equity
                  strSize = StrTrim(StrSubstr(values[n], 1));
                  if (!StrIsNumeric(strSize))                        return(!catch("CustomPositions.ReadConfig(5)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric equity \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termType   = TERM_EQUITY;
                  termValue1 = StrToDouble(strSize);
                  if (termValue1 <= 0)                               return(!catch("CustomPositions.ReadConfig(6)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal equity \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrIsNumeric(values[n])) {                   // PL-Adjustment
                  termType   = TERM_ADJUSTMENT;
                  termValue1 = StrToDouble(values[n]);
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrEndsWith(values[n], "L")) {               // virtuelle Longposition zum aktuellen Preis
                  termType = TERM_OPEN_LONG;
                  strSize  = StrTrim(StrLeft(values[n], -1));
                  if (!StrIsNumeric(strSize))                        return(!catch("CustomPositions.ReadConfig(7)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue1 = StrToDouble(strSize);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(8)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(9)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrEndsWith(values[n], "S")) {               // virtuelle Shortposition zum aktuellen Preis
                  termType = TERM_OPEN_SHORT;
                  strSize  = StrTrim(StrLeft(values[n], -1));
                  if (!StrIsNumeric(strSize))                        return(!catch("CustomPositions.ReadConfig(10)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue1 = StrToDouble(strSize);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(11)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(12)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrContains(values[n], "L")) {               // virtuelle Longposition zum angegebenen Preis
                  termType = TERM_OPEN_LONG;
                  pos = StringFind(values[n], "L");
                  strSize = StrTrim(StrLeft(values[n], pos));
                  if (!StrIsNumeric(strSize))                        return(!catch("CustomPositions.ReadConfig(13)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue1 = StrToDouble(strSize);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(14)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(15)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  strPrice = StrTrim(StrSubstr(values[n], pos+1));
                  if (StrStartsWith(strPrice, "@"))
                     strPrice = StrTrim(StrSubstr(strPrice, 1));
                  if (!StrIsNumeric(strPrice))                       return(!catch("CustomPositions.ReadConfig(16)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = StrToDouble(strPrice);
                  if (termValue2 <= 0)                               return(!catch("CustomPositions.ReadConfig(17)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrContains(values[n], "S")) {               // virtuelle Shortposition zum angegebenen Preis
                  termType = TERM_OPEN_SHORT;
                  pos = StringFind(values[n], "S");
                  strSize = StrTrim(StrLeft(values[n], pos));
                  if (!StrIsNumeric(strSize))                        return(!catch("CustomPositions.ReadConfig(18)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue1 = StrToDouble(strSize);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(19)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(20)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  strPrice = StrTrim(StrSubstr(values[n], pos+1));
                  if (StrStartsWith(strPrice, "@"))
                     strPrice = StrTrim(StrSubstr(strPrice, 1));
                  if (!StrIsNumeric(strPrice))                       return(!catch("CustomPositions.ReadConfig(21)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue2 = StrToDouble(strPrice);
                  if (termValue2 <= 0)                               return(!catch("CustomPositions.ReadConfig(22)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StrContains(values[n], "#")) {               // Lotsizeangabe + # + Ticket
                  pos = StringFind(values[n], "#");
                  strSize = StrTrim(StrLeft(values[n], pos));
                  if (!StrIsNumeric(strSize))                        return(!catch("CustomPositions.ReadConfig(23)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termValue1 = StrToDouble(strSize);
                  if (termValue1 && LT(termValue1, minLotSize))      return(!catch("CustomPositions.ReadConfig(24)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (lot size smaller than MIN_LOTSIZE \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  if (MathModFix(termValue1, lotStep) != 0)          return(!catch("CustomPositions.ReadConfig(25)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (lot size not a multiple of LOTSTEP \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  strTicket = StrTrim(StrSubstr(values[n], pos+1));
                  if (!StrIsDigit(strTicket))                        return(!catch("CustomPositions.ReadConfig(26)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-digits in ticket \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));
                  termType   = StrToInteger(strTicket);
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }
               else                                                  return(!catch("CustomPositions.ReadConfig(27)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));

               // Eine gruppierte Trade-History kann nicht mit anderen Termen kombiniert werden
               if (isPositionGrouped && termType!=TERM_EQUITY)       return(!catch("CustomPositions.ReadConfig(28)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (cannot combine grouped trade history with other entries) in \""+ file +"\"", ERR_INVALID_CONFIG_VALUE));

               // Die Konfiguration virtueller Positionen muß mit einem virtuellen Term beginnen, damit die realen Lots nicht um die virtuellen Lots reduziert werden, siehe (2).
               if ((termType==TERM_OPEN_LONG || termType==TERM_OPEN_SHORT) && termValue1!=EMPTY) {
                  if (!isPositionEmpty && !isPositionVirtual) {
                     double tmp[POSITION_CONFIG_TERM_doubleSize] = {TERM_OPEN_LONG, 0, NULL, NULL, NULL};   // am Anfang der Zeile virtuellen 0-Term einfügen: 0L
                     ArrayInsertDoubleArray(positions.config, positionStartOffset, tmp);
                  }
                  isPositionVirtual = true;
               }

               // Konfigurations-Term speichern
               confSize = ArrayRange(positions.config, 0);
               ArrayResize(positions.config, confSize+1);
               positions.config[confSize][0] = termType;
               positions.config[confSize][1] = termValue1;
               positions.config[confSize][2] = termValue2;
               positions.config[confSize][3] = termCache1;
               positions.config[confSize][4] = termCache2;
               isPositionEmpty = false;
            }

            if (!isPositionEmpty) {                                     // Zeile mit Leer-Term abschließen (markiert Zeilenende)
               confSize = ArrayRange(positions.config, 0);
               ArrayResize(positions.config, confSize+1);               // initialisiert Term mit NULL
                  if (!StringLen(confComment)) comment = openComment + ifString(StringLen(openComment) && StringLen(hstComment ), ", ", "") + hstComment;
                  else                         comment = confComment;   // configured comments override generated ones
               ArrayPushString(positions.config.comments, comment);
               positionStartOffset = confSize + 1;                      // Start-Offset der nächsten Custom-Position speichern (falls noch eine weitere Position folgt)
            }
         }
      }
   }

   confSize = ArrayRange(positions.config, 0);
   if (!confSize) {                                                  // leere Konfiguration mit Leer-Term markieren
      ArrayResize(positions.config, 1);                              // initialisiert Term mit NULL
      ArrayPushString(positions.config.comments, "");
   }

   return(!catch("CustomPositions.ReadConfig(29)"));
}


/**
 * Parst einen Open-Konfigurations-Term (Open Position).
 *
 * @param  _In_    string   term         - Konfigurations-Term
 * @param  _InOut_ string   openComments - vorhandene OpenPositions-Kommentare (werden ggf. erweitert)
 * @param  _Out_   bool     isTotal      - ob die offenen Positionen alle verfügbaren Symbole (TRUE) oder nur das aktuelle Symbol (FALSE) umfassen
 * @param  _Out_   datetime from         - Beginnzeitpunkt der zu berücksichtigenden Positionen
 * @param  _Out_   datetime to           - Endzeitpunkt der zu berücksichtigenden Positionen
 *
 * @return bool - Erfolgsstatus
 *
 *
 * Format:
 * -------
 *  O{DateTime}                                       • Trade-History eines Symbols eines Standard-Zeitraums
 *  OT{DateTime}-{DateTime}                           • Trade-History aller Symbole von und bis zu einem Zeitpunkt
 *
 *  {DateTime} = 2014[.01[.15 [W|12:34[:56]]]]        oder
 *  {DateTime} = (This|Last)(Day|Week|Month|Year)     oder
 *  {DateTime} = Today                                • Synonym für ThisDay
 *  {DateTime} = Yesterday                            • Synonym für LastDay
 */
bool CustomPositions.ParseOpenTerm(string term, string &openComments, bool &isTotal, datetime &from, datetime &to) {
   isTotal = isTotal!=0;
   string origTerm = term;

   term = StrToUpper(StrTrim(term));
   if (!StrStartsWith(term, "O")) return(!catch("CustomPositions.ParseOpenTerm(1)  invalid parameter term: "+ DoubleQuoteStr(origTerm) +" (not TERM_OPEN_*)", ERR_INVALID_PARAMETER));
   term = StrTrim(StrSubstr(term, 1));

   if     (!StrStartsWith(term, "T"    )) isTotal = false;
   else if (StrStartsWith(term, "THIS" )) isTotal = false;
   else if (StrStartsWith(term, "TODAY")) isTotal = false;
   else                                   isTotal = true;
   if (isTotal) term = StrTrim(StrSubstr(term, 1));

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
   if (isTotal) comment = comment +" (gesamt)";
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
 * @return bool - Erfolgsstatus
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
         positions.config[confSize][0] = ifInt(!isTotalHistory, TERM_HISTORY_SYMBOL, TERM_HISTORY_ALL);
         positions.config[confSize][1] = groupFrom;
         positions.config[confSize][2] = groupTo;
         positions.config[confSize][3] = EMPTY_VALUE;
         positions.config[confSize][4] = EMPTY_VALUE;
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
   if (!StrIsDigit(StrLeft(value, 1))) {
      datetime date, now = TimeFXT(); if (!now) return(NaT);

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
         if (!StrIsDigit(sYY))                                       return(_NaT(catch("ParseDateTimeEx(8)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
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
         if (!StrIsDigit(sMM))                                       return(_NaT(catch("ParseDateTimeEx(11)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
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
         if (!StrIsDigit(sDD))                                       return(_NaT(catch("ParseDateTimeEx(15)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
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
            if (!StrIsDigit(sHH))                                    return(_NaT(catch("ParseDateTimeEx(22)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            iHH = StrToInteger(sHH);
            if (iHH < 0 || 23 < iHH)                                 return(_NaT(catch("ParseDateTimeEx(23)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));

            sII = StrTrim(values[1]);                                // Minuten
            if (StringLen(sII) > 2)                                  return(_NaT(catch("ParseDateTimeEx(24)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            if (!StrIsDigit(sII))                                    return(_NaT(catch("ParseDateTimeEx(25)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            iII = StrToInteger(sII);
            if (iII < 0 || 59 < iII)                                 return(_NaT(catch("ParseDateTimeEx(26)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
            if (valuesSize == 2) {
               if (!iII) isHour   = true;
               else      isMinute = true;
            }

            if (valuesSize == 3) {
               sSS = StrTrim(values[2]);                             // Sekunden
               if (StringLen(sSS) > 2)                               return(_NaT(catch("ParseDateTimeEx(27)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
               if (!StrIsDigit(sSS))                                 return(_NaT(catch("ParseDateTimeEx(28)  invalid history configuration in "+ DoubleQuoteStr(origValue), ERR_INVALID_CONFIG_VALUE)));
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
 * Extrahiert aus dem Bestand der übergebenen Positionen {fromVars} eine Teilposition und fügt sie dem Bestand einer CustomPosition
 * {customVars} hinzu.
 *
 *                                                                    +-+    struct POSITION_CONFIG_TERM {
 * @param  _In_    int    type           - zu extrahierender Typ      |       double type;
 * @param  _In_    double value1         - zu extrahierende Lotsize   |       double confValue1;
 * @param  _In_    double value2         - Preis/Betrag/Equity        +->     double confValue2;
 * @param  _InOut_ double cache1         - Zwischenspeicher 1         |       double cacheValue1;
 * @param  _InOut_ double cache2         - Zwischenspeicher 2         |       double cacheValue2;
 *                                                                    +-+    };
 *
 * @param  _InOut_ mixed fromVars        - Variablen, aus denen die Teilposition extrahiert wird (Bestand verringert sich)
 * @param  _InOut_ mixed customVars      - Variablen, denen die extrahierte Position hinzugefügt wird (Bestand erhöht sich)
 * @param  _InOut_ bool  isCustomVirtual - ob die resultierende CustomPosition virtuell ist
 *
 * @return bool - Erfolgsstatus
 */
bool ExtractPosition(int type, double value1, double value2, double &cache1, double &cache2,
                     double &longPosition,       double &shortPosition,       double &totalPosition,       int &tickets[],       int &types[],       double &lots[],       datetime &openTimes[], double &openPrices[],       double &commissions[],       double &swaps[],       double &profits[],
                     double &customLongPosition, double &customShortPosition, double &customTotalPosition, int &customTickets[], int &customTypes[], double &customLots[],                        double &customOpenPrices[], double &customCommissions[], double &customSwaps[], double &customProfits[], double &closedProfit, double &adjustedProfit, double &customEquity,
                     bool   &isCustomVirtual) {
   isCustomVirtual = isCustomVirtual!=0;

   double   lotsize;
   datetime from, to;
   int sizeTickets = ArraySize(tickets);

   if (type == TERM_OPEN_LONG) {
      lotsize = value1;

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
            double openPrice = ifDouble(value2!=0, value2, Ask);
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

   else if (type == TERM_OPEN_SHORT) {
      lotsize = value1;

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
            openPrice = ifDouble(value2!=0, value2, Bid);
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

   else if (type == TERM_OPEN_SYMBOL) {
      from = value1;
      to   = value2;

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

   else if (type == TERM_OPEN_ALL) {
      // offene Positionen aller Symbole eines Zeitraumes
      logWarn("ExtractPosition(1)  type=TERM_OPEN_ALL not yet implemented");
   }

   else if (type==TERM_HISTORY_SYMBOL || type==TERM_HISTORY_ALL) {
      // geschlossene Positionen des aktuellen oder aller Symbole eines Zeitraumes
      from              = value1;
      to                = value2;
      double lastProfit = cache1;      // default: EMPTY_VALUE
      int    lastOrders = cache2;      // default: EMPTY_VALUE                // Anzahl der Tickets in der History: ändert sie sich, wird der Profit neu berechnet

      int orders=OrdersHistoryTotal(), _orders=orders;

      if (orders != lastOrders) {
         // (1) Sortierschlüssel aller geschlossenen Positionen auslesen und nach {CloseTime, OpenTime, Ticket} sortieren
         int sortKeys[][3], n, hst.ticket;                                    // {CloseTime, OpenTime, Ticket}
         ArrayResize(sortKeys, orders);

         for (i=0; i < orders; i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))                 // FALSE: während des Auslesens wurde der Anzeigezeitraum der History verkürzt
               break;

            // wenn OrderType()==OP_BALANCE, dann OrderSymbol()==Leerstring
            if (OrderType() == OP_BALANCE) {
               // Dividenden                                                  // "Ex Dividend US2000" oder
               if (StrStartsWithI(OrderComment(), "ex dividend ")) {          // "Ex Dividend 17/03/15 US2000"
                  if (type == TERM_HISTORY_SYMBOL)                            // single history
                     if (!StrEndsWithI(OrderComment(), " "+ Symbol()))        // ok, wenn zum aktuellen Symbol gehörend
                        continue;
               }
               // Rollover adjustments
               else if (StrStartsWithI(OrderComment(), "adjustment ")) {      // "Adjustment BRENT"
                  if (type == TERM_HISTORY_SYMBOL)                            // single history
                     if (!StrEndsWithI(OrderComment(), " "+ Symbol()))        // ok, wenn zum aktuellen Symbol gehörend
                        continue;
               }
               else {
                  continue;                                                   // sonstige Balance-Einträge
               }
            }

            else {
               if (OrderType() > OP_SELL)                                         continue;
               if (type==TERM_HISTORY_SYMBOL) /*&&*/ if (OrderSymbol()!=Symbol()) continue;  // ggf. Positionen aller Symbole
            }

            sortKeys[n][0] = OrderCloseTime();
            sortKeys[n][1] = OrderOpenTime();
            sortKeys[n][2] = OrderTicket();
            n++;
         }
         orders = n;
         ArrayResize(sortKeys, orders);
         SortClosedTickets(sortKeys);

         // (2) Tickets sortiert einlesen
         int      hst.tickets    []; ArrayResize(hst.tickets    , 0);
         int      hst.types      []; ArrayResize(hst.types      , 0);
         double   hst.lotSizes   []; ArrayResize(hst.lotSizes   , 0);
         datetime hst.openTimes  []; ArrayResize(hst.openTimes  , 0);
         datetime hst.closeTimes []; ArrayResize(hst.closeTimes , 0);
         double   hst.openPrices []; ArrayResize(hst.openPrices , 0);
         double   hst.closePrices[]; ArrayResize(hst.closePrices, 0);
         double   hst.commissions[]; ArrayResize(hst.commissions, 0);
         double   hst.swaps      []; ArrayResize(hst.swaps      , 0);
         double   hst.profits    []; ArrayResize(hst.profits    , 0);
         string   hst.comments   []; ArrayResize(hst.comments   , 0);

         for (i=0; i < orders; i++) {
            if (!SelectTicket(sortKeys[i][2], "ExtractPosition(2)"))
               return(false);
            ArrayPushInt   (hst.tickets    , OrderTicket()    );
            ArrayPushInt   (hst.types      , OrderType()      );
            ArrayPushDouble(hst.lotSizes   , OrderLots()      );
            ArrayPushInt   (hst.openTimes  , OrderOpenTime()  );
            ArrayPushInt   (hst.closeTimes , OrderCloseTime() );
            ArrayPushDouble(hst.openPrices , OrderOpenPrice() );
            ArrayPushDouble(hst.closePrices, OrderClosePrice());
            ArrayPushDouble(hst.commissions, OrderCommission());
            ArrayPushDouble(hst.swaps      , OrderSwap()      );
            ArrayPushDouble(hst.profits    , OrderProfit()    );
            ArrayPushString(hst.comments   , OrderComment()   );
         }

         // (3) Hedges korrigieren: alle Daten dem ersten Ticket zuordnen und hedgendes Ticket verwerfen (auch Positionen mehrerer Symbole werden korrekt zugeordnet)
         for (i=0; i < orders; i++) {
            if (hst.tickets[i] && EQ(hst.lotSizes[i], 0)) {          // lotSize = 0: Hedge-Position
               // TODO: Prüfen, wie sich OrderComment() bei custom comments verhält.
               if (!StrStartsWithI(hst.comments[i], "close hedge by #"))
                  return(!catch("ExtractPosition(3)  #"+ hst.tickets[i] +" - unknown comment for assumed hedging position "+ DoubleQuoteStr(hst.comments[i]), ERR_RUNTIME_ERROR));

               // Gegenstück suchen
               hst.ticket = StrToInteger(StringSubstr(hst.comments[i], 16));
               for (n=0; n < orders; n++) {
                  if (hst.tickets[n] == hst.ticket)
                     break;
               }
               if (n == orders) return(!catch("ExtractPosition(4)  cannot find counterpart for hedging position #"+ hst.tickets[i] +" "+ DoubleQuoteStr(hst.comments[i]), ERR_RUNTIME_ERROR));
               if (i == n     ) return(!catch("ExtractPosition(5)  both hedged and hedging position have the same ticket #"+ hst.tickets[i] +" "+ DoubleQuoteStr(hst.comments[i]), ERR_RUNTIME_ERROR));

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
               hst.tickets   [second] = NULL;                                    // hedgendes Ticket als verworfen markieren
            }
         }

         // (4) Trades auswerten
         lastProfit=0; n=0;
         for (i=0; i < orders; i++) {
            if (!hst.tickets[i])                  continue;                      // verworfene Hedges überspringen
            if (from && hst.closeTimes[i] < from) continue;
            if (to   && hst.closeTimes[i] > to  ) continue;
            lastProfit += hst.commissions[i] + hst.swaps[i] + hst.profits[i];
            n++;
         }
         if (!n) lastProfit = EMPTY_VALUE;                                       // keine passenden geschlossenen Trades gefunden
         else    lastProfit = NormalizeDouble(lastProfit, 2);
         cache1             = lastProfit;
         cache2             = _orders;
         //debug("ExtractPosition(6)  from="+ ifString(from, TimeToStr(from), "start") +"  to="+ ifString(to, TimeToStr(to), "end") +"  profit="+ ifString(IsEmptyValue(lastProfit), "empty", DoubleToStr(lastProfit, 2)) +"  closed trades="+ n);
      }
      // lastProfit zu closedProfit hinzufügen, wenn geschlossene Trades existierten (Ausgangsdaten bleiben unverändert)
      if (lastProfit != EMPTY_VALUE) {
         if (closedProfit == EMPTY_VALUE) closedProfit  = lastProfit;
         else                             closedProfit += lastProfit;
      }
   }

   else if (type == TERM_ADJUSTMENT) {
      // Betrag zu adjustedProfit hinzufügen (Ausgangsdaten bleiben unverändert)
      adjustedProfit += value1;
   }

   else if (type == TERM_EQUITY) {
      // vorhandenen Betrag überschreiben (Ausgangsdaten bleiben unverändert)
      customEquity = value1;
   }

   else { // type = Ticket
      lotsize = value1;

      if (lotsize == EMPTY) {
         // komplettes Ticket
         for (i=0; i < sizeTickets; i++) {
            if (tickets[i] == type) {
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
            if (tickets[i] == type) {
               if (GT(lotsize, lots[i])) return(!catch("ExtractPosition(7)  illegal partial lotsize "+ NumberToStr(lotsize, ".+") +" for ticket #"+ tickets[i] +" (only "+ NumberToStr(lots[i], ".+") +" lot remaining)", ERR_RUNTIME_ERROR));
               if (EQ(lotsize, lots[i])) {
                  // komplettes Ticket übernehmen
                  if (!ExtractPosition(type, EMPTY, value2, cache1, cache2,
                                       longPosition,       shortPosition,       totalPosition,       tickets,       types,       lots,       openTimes, openPrices,       commissions,       swaps,       profits,
                                       customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLots,            customOpenPrices, customCommissions, customSwaps, customProfits, closedProfit, adjustedProfit, customEquity,
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
   return(!catch("ExtractPosition(8)"));
}


/**
 * Speichert die übergebenen Daten zusammengefaßt (direktionaler und gehedgeter Anteil gemeinsam) als eine Position in den globalen Variablen
 * positions.*Data[].
 *
 * @param  _In_ bool   isVirtual
 *
 * @param  _In_ double longPosition
 * @param  _In_ double shortPosition
 * @param  _In_ double totalPosition
 *
 * @param  _In_ int    tickets    []
 * @param  _In_ int    types      []
 * @param  _In_ double lots       []
 * @param  _In_ double openPrices []
 * @param  _In_ double commissions[]
 * @param  _In_ double swaps      []
 * @param  _In_ double profits    []
 *
 * @param  _In_ double closedProfit
 * @param  _In_ double adjustedProfit
 * @param  _In_ double customEquity
 * @param  _In_ int    commentIndex
 *
 * @return bool - Erfolgsstatus
 */
bool StorePosition(bool isVirtual, double longPosition, double shortPosition, double totalPosition, int &tickets[], int types[], double &lots[], double openPrices[], double &commissions[], double &swaps[], double &profits[], double closedProfit, double adjustedProfit, double customEquity, int commentIndex) {
   isVirtual = isVirtual!=0;

   double hedgedLots, remainingLong, remainingShort, factor, openPrice, closePrice, commission, swap, floatingProfit, hedgedProfit, openProfit, fullProfit, equity, pipValue, pipDistance;
   int size, ticketsSize=ArraySize(tickets);

   // Enthält die Position weder OpenProfit (offene Positionen), ClosedProfit noch AdjustedProfit, wird sie übersprungen.
   // Ein Test auf size(tickets) != 0 reicht nicht aus, da einige Tickets in tickets[] bereits auf NULL gesetzt worden sein können.
   if (!longPosition) /*&&*/ if (!shortPosition) /*&&*/ if (!totalPosition) /*&&*/ if (closedProfit==EMPTY_VALUE) /*&&*/ if (!adjustedProfit)
      return(true);

   if (closedProfit == EMPTY_VALUE)
      closedProfit = 0;                                                    // 0.00 ist gültiger PL

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

         positions.iData[size][I_CONFIG_TYPE     ] = ifInt(isVirtual, CONFIG_VIRTUAL, CONFIG_REAL);
         positions.iData[size][I_POSITION_TYPE   ] = POSITION_HEDGE;
         positions.iData[size][I_COMMENT_INDEX   ] = commentIndex;

         positions.dData[size][I_DIRECTIONAL_LOTS] = 0;
         positions.dData[size][I_HEDGED_LOTS     ] = hedgedLots;
         positions.dData[size][I_PIP_DISTANCE    ] = pipDistance;

         positions.dData[size][I_OPEN_EQUITY     ] = equity;         openProfit = hedgedProfit;
         positions.dData[size][I_OPEN_PROFIT     ] = openProfit;
         positions.dData[size][I_CLOSED_PROFIT   ] = closedProfit;
         positions.dData[size][I_ADJUSTED_PROFIT ] = adjustedProfit; fullProfit = openProfit + closedProfit + adjustedProfit;
         positions.dData[size][I_FULL_PROFIT_ABS ] = fullProfit;        // Bei customEquity wird der gemachte Profit nicht vom Equitywert abgezogen.
         positions.dData[size][I_FULL_PROFIT_PCT ] = MathDiv(fullProfit, equity-ifDouble(!customEquity, fullProfit, 0)) * 100;

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

      positions.iData[size][I_CONFIG_TYPE     ] = ifInt(isVirtual, CONFIG_VIRTUAL, CONFIG_REAL);
      positions.iData[size][I_POSITION_TYPE   ] = POSITION_LONG;
      positions.iData[size][I_COMMENT_INDEX   ] = commentIndex;

      positions.dData[size][I_DIRECTIONAL_LOTS] = totalPosition;
      positions.dData[size][I_HEDGED_LOTS     ] = hedgedLots;
      positions.dData[size][I_BREAKEVEN_PRICE ] = NULL;

      positions.dData[size][I_OPEN_EQUITY     ] = equity;         openProfit = hedgedProfit + commission + swap + floatingProfit;
      positions.dData[size][I_OPEN_PROFIT     ] = openProfit;
      positions.dData[size][I_CLOSED_PROFIT   ] = closedProfit;
      positions.dData[size][I_ADJUSTED_PROFIT ] = adjustedProfit; fullProfit = openProfit + closedProfit + adjustedProfit;
      positions.dData[size][I_FULL_PROFIT_ABS ] = fullProfit;           // Bei customEquity wird der gemachte Profit nicht vom Equitywert abgezogen.
      positions.dData[size][I_FULL_PROFIT_PCT ] = MathDiv(fullProfit, equity-ifDouble(!customEquity, fullProfit, 0)) * 100;

      pipValue = PipValue(totalPosition, true);                         // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
      if (pipValue != 0)
         positions.dData[size][I_BREAKEVEN_PRICE] = RoundCeil(openPrice/totalPosition - (fullProfit-floatingProfit)/pipValue*Pip, Digits);
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

      positions.iData[size][I_CONFIG_TYPE     ] = ifInt(isVirtual, CONFIG_VIRTUAL, CONFIG_REAL);
      positions.iData[size][I_POSITION_TYPE   ] = POSITION_SHORT;
      positions.iData[size][I_COMMENT_INDEX   ] = commentIndex;

      positions.dData[size][I_DIRECTIONAL_LOTS] = -totalPosition;
      positions.dData[size][I_HEDGED_LOTS     ] = hedgedLots;
      positions.dData[size][I_BREAKEVEN_PRICE ] = NULL;

      positions.dData[size][I_OPEN_EQUITY     ] = equity;         openProfit = hedgedProfit + commission + swap + floatingProfit;
      positions.dData[size][I_OPEN_PROFIT     ] = openProfit;
      positions.dData[size][I_CLOSED_PROFIT   ] = closedProfit;
      positions.dData[size][I_ADJUSTED_PROFIT ] = adjustedProfit; fullProfit = openProfit + closedProfit + adjustedProfit;
      positions.dData[size][I_FULL_PROFIT_ABS ] = fullProfit;           // Bei customEquity wird der gemachte Profit nicht vom Equitywert abgezogen.
      positions.dData[size][I_FULL_PROFIT_PCT ] = MathDiv(fullProfit, equity-ifDouble(!customEquity, fullProfit, 0)) * 100;

      pipValue = PipValue(-totalPosition, true);                        // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
      if (pipValue != 0)
         positions.dData[size][I_BREAKEVEN_PRICE] = RoundFloor((fullProfit-floatingProfit)/pipValue*Pip - openPrice/totalPosition, Digits);
      return(!catch("StorePosition(7)"));
   }


   // ohne offene Positionen muß ClosedProfit (kann 0.00 sein) oder AdjustedProfit gesetzt sein
   // History mit leerer Position speichern
   size = ArrayRange(positions.iData, 0);
   ArrayResize(positions.iData, size+1);
   ArrayResize(positions.dData, size+1);

   positions.iData[size][I_CONFIG_TYPE     ] = ifInt(isVirtual, CONFIG_VIRTUAL, CONFIG_REAL);
   positions.iData[size][I_POSITION_TYPE   ] = POSITION_HISTORY;
   positions.iData[size][I_COMMENT_INDEX   ] = commentIndex;

   positions.dData[size][I_DIRECTIONAL_LOTS] = NULL;
   positions.dData[size][I_HEDGED_LOTS     ] = NULL;
   positions.dData[size][I_BREAKEVEN_PRICE ] = NULL;

   positions.dData[size][I_OPEN_EQUITY     ] = equity;         openProfit = 0;
   positions.dData[size][I_OPEN_PROFIT     ] = openProfit;
   positions.dData[size][I_CLOSED_PROFIT   ] = closedProfit;
   positions.dData[size][I_ADJUSTED_PROFIT ] = adjustedProfit; fullProfit = openProfit + closedProfit + adjustedProfit;
   positions.dData[size][I_FULL_PROFIT_ABS ] = fullProfit;              // Bei customEquity wird der gemachte Profit nicht vom Equitywert abgezogen.
   positions.dData[size][I_FULL_PROFIT_PCT ] = MathDiv(fullProfit, equity-ifDouble(!customEquity, fullProfit, 0)) * 100;

   return(!catch("StorePosition(8)"));
}


/**
 * Sortiert die übergebenen Ticketdaten nach {CloseTime, OpenTime, Ticket}.
 *
 * @param  _InOut_ int tickets[]
 *
 * @return bool - Erfolgsstatus
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
 * @return bool - Erfolgsstatus
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
 * @return bool - Erfolgsstatus
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
 * @return bool - Erfolgsstatus
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
 * @return bool - Erfolgsstatus: Ob die Message erfolgreich verarbeitet wurde. Ein falsches Messageformat oder keine zur Message passende
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
 * @return bool - Erfolgsstatus
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
 * @return bool - Erfolgsstatus
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
 * @return bool - Erfolgsstatus
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
 * @return bool - Erfolgsstatus
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
 * Speichert die Laufzeitkonfiguration im Fenster (für Init-Cycle und neue Templates) und im Chart (für Terminal-Restart).
 *
 * @return bool - Erfolgsstatus
 */
bool StoreRuntimeStatus() {
   // bool positions.absoluteProfits

   // Konfiguration im Fenster speichern
   int   hWnd = __ExecutionContext[EC.hChart];
   string key = ProgramName() +".runtime.positions.absoluteProfits";    // TODO: Schlüssel global verwalten und Instanz-ID des Indikators integrieren
   int  value = ifInt(positions.absoluteProfits, 1, -1);
   SetWindowIntegerA(hWnd, key, value);

   // Konfiguration im Chart speichern
   if (ObjectFind(key) == 0)
      ObjectDelete(key);
   ObjectCreate (key, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (key, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(key, ""+ value);

   return(!catch("StoreRuntimeStatus(1)"));
}


/**
 * Restauriert eine im Fenster oder im Chart gespeicherte Laufzeitkonfiguration.
 *
 * @return bool - Erfolgsstatus
 */
bool RestoreRuntimeStatus() {
   // bool positions.absoluteProfits

   // Konfiguration im Fenster suchen
   int   hWnd = __ExecutionContext[EC.hChart];
   string key = ProgramName() +".runtime.positions.absoluteProfits";    // TODO: Schlüssel global verwalten und Instanz-ID des Indikators integrieren
   int value  = GetWindowIntegerA(hWnd, key);
   bool success = (value != 0);
   // bei Mißerfolg Konfiguration im Chart suchen
   if (!success) {
      if (ObjectFind(key) == 0) {
         value   = StrToInteger(ObjectDescription(key));
         success = (value != 0);
      }
   }
   if (success) positions.absoluteProfits = (value > 0);

   return(!catch("RestoreRuntimeStatus(1)"));
}


/**
 * Prüft, ob seit dem letzten Aufruf eine Pending-Order oder ein Close-Limit ausgeführt wurden.
 *
 * @param  _Out_ int failedOrders   []    - Array zur Aufnahme der Tickets fehlgeschlagener Pening-Orders
 * @param  _Out_ int openedPositions[]    - Array zur Aufnahme der Tickets neuer offener Positionen
 * @param  _Out_ int closedPositions[][2] - Array zur Aufnahme der Tickets neuer geschlossener Positionen
 *
 * @return bool - Erfolgsstatus
 */
bool OrderTracker.CheckPositions(int &failedOrders[], int &openedPositions[], int &closedPositions[][]) {
   /*
   PositionOpen
   ------------
   - ist Ausführung einer Pending-Order
   - Pending-Order muß vorher bekannt sein
     (1) alle bekannten Pending-Orders auf Statusänderung prüfen:              über bekannte Orders iterieren
     (2) alle unbekannten Pending-Orders registrieren:                         über alle Tickets(MODE_TRADES) iterieren

   PositionClose
   -------------
   - ist Schließung einer Position
   - Position muß vorher bekannt sein
     (1) alle bekannten Pending-Orders und Positionen auf OrderClose prüfen:   über bekannte Orders iterieren
     (2) alle unbekannten Positionen mit und ohne Exit-Limit registrieren:     über alle Tickets(MODE_TRADES) iterieren
         (limitlose Positionen können durch Stopout geschlossen werden/worden sein)

   beides zusammen
   ---------------
     (1.1) alle bekannten Pending-Orders auf Statusänderung prüfen:            über bekannte Orders iterieren
     (1.2) alle bekannten Pending-Orders und Positionen auf OrderClose prüfen: über bekannte Orders iterieren
     (2)   alle unbekannten Pending-Orders und Positionen registrieren:        über alle Tickets(MODE_TRADES) iterieren
           - nach (1), um neue Orders nicht sofort zu prüfen (unsinnig)
   */

   int type, knownSize = ArraySize(orderTracker.tickets);


   // (1) über alle bekannten Orders iterieren (rückwärts, um beim Entfernen von Elementen die Schleife einfacher managen zu können)
   for (int i=knownSize-1; i >= 0; i--) {
      if (!SelectTicket(orderTracker.tickets[i], "OrderTracker.CheckPositions(1)"))
         return(false);
      type = OrderType();

      if (orderTracker.types[i] > OP_SELL) {
         // (1.1) beim letzten Aufruf Pending-Order
         if (type == orderTracker.types[i]) {
            // immer noch Pending-Order
            if (OrderCloseTime() != 0) {
               if (OrderComment() != "cancelled")
                  ArrayPushInt(failedOrders, orderTracker.tickets[i]);           // keine regulär gestrichene Pending-Order: "deleted [no money]" etc.

               // geschlossene Pending-Order aus der Überwachung entfernen
               ArraySpliceInts(orderTracker.tickets, i, 1);
               ArraySpliceInts(orderTracker.types,   i, 1);
               knownSize--;
            }
         }
         else {
            // jetzt offene oder bereits geschlossene Position
            ArrayPushInt(openedPositions, orderTracker.tickets[i]);              // Pending-Order wurde ausgeführt
            orderTracker.types[i] = type;
            i++;
            continue;                                                            // ausgeführte Order in Zweig (1.2) nochmal prüfen (anstatt hier die Logik zu duplizieren)
         }
      }
      else {
         // (1.2) beim letzten Aufruf offene Position
         if (!OrderCloseTime()) {
            // immer noch offene Position
         }
         else {
            // jetzt geschlossene Position
            // prüfen, ob die Position manuell oder automatisch geschlossen wurde (durch ein Close-Limit oder durch Stopout)
            bool   closedByLimit=false, autoClosed=false;
            int    closeType, closeData[2];
            string comment = StrToLower(StrTrim(OrderComment()));

            if      (StrStartsWith(comment, "so:" )) { autoClosed=true; closeType=CLOSE_TYPE_SO; }    // Margin Stopout erkennen
            else if (StrEndsWith  (comment, "[tp]")) { autoClosed=true; closeType=CLOSE_TYPE_TP; }
            else if (StrEndsWith  (comment, "[sl]")) { autoClosed=true; closeType=CLOSE_TYPE_SL; }
            else {
               if (!EQ(OrderTakeProfit(), 0)) {                                                       // manche Broker setzen den OrderComment bei getriggertem Limit nicht
                  closedByLimit = false;                                                              // gemäß MT4-Standard
                  if (type == OP_BUY ) { closedByLimit = (OrderClosePrice() >= OrderTakeProfit()); }
                  else                 { closedByLimit = (OrderClosePrice() <= OrderTakeProfit()); }
                  if (closedByLimit) {
                     autoClosed = true;
                     closeType  = CLOSE_TYPE_TP;
                  }
               }
               if (!EQ(OrderStopLoss(), 0)) {
                  closedByLimit = false;
                  if (type == OP_BUY ) { closedByLimit = (OrderClosePrice() <= OrderStopLoss()); }
                  else                 { closedByLimit = (OrderClosePrice() >= OrderStopLoss()); }
                  if (closedByLimit) {
                     autoClosed = true;
                     closeType  = CLOSE_TYPE_SL;
                  }
               }
            }
            if (autoClosed) {
               closeData[0] = orderTracker.tickets[i];
               closeData[1] = closeType;
               ArrayPushInts(closedPositions, closeData);            // Position wurde automatisch geschlossen
            }
            ArraySpliceInts(orderTracker.tickets, i, 1);             // geschlossene Position aus der Überwachung entfernen
            ArraySpliceInts(orderTracker.types,   i, 1);
            knownSize--;
         }
      }
   }


   // (2) über Tickets(MODE_TRADES) iterieren und alle unbekannten Tickets registrieren (immer Pending-Order oder offene Position)
   while (true) {
      int ordersTotal = OrdersTotal();

      for (i=0; i < ordersTotal; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {                      // FALSE: während des Auslesens wurde von dritter Seite eine Order geschlossen oder gelöscht
            ordersTotal = -1;                                                    // Abbruch und via while-Schleife alles nochmal verarbeiten, bis for() fehlerfrei durchläuft
            break;
         }
         for (int n=0; n < knownSize; n++) {
            if (orderTracker.tickets[n] == OrderTicket())                        // Order bereits bekannt
               break;
         }
         if (n >= knownSize) {                                                   // Order unbekannt: in Überwachung aufnehmen
            ArrayPushInt(orderTracker.tickets, OrderTicket());
            ArrayPushInt(orderTracker.types,   OrderType());
            knownSize++;
         }
      }

      if (ordersTotal == OrdersTotal())
         break;
   }

   return(!catch("OrderTracker.CheckPositions(2)"));
}


/**
 * Handle a PositionOpen event.
 *
 * @param  int tickets[] - ticket ids of the opened positions
 *
 * @return bool - success status
 */
bool onPositionOpen(int tickets[]) {
   // #1 Sell 0.1 GBPUSD at 1.5457'2 ("L.8692.+3")
   bool isLogInfo=IsLogInfo(), eventLogged=false;
   int size = ArraySize(tickets);
   if (!size || !isLogInfo) return(true);

   OrderPush();
   for (int i=0; i < size; i++) {
      if (!SelectTicket(tickets[i], "onPositionOpen(1)")) return(false);

      bool isMySymbol=(OrderSymbol()==Symbol()), isOtherListener=false;
      if (!isMySymbol) isOtherListener = IsOrderEventListener(OrderSymbol());

      if (isMySymbol || !isOtherListener) {
         string event = "rsf::PositionOpen::#"+ OrderTicket();

         if (!IsOrderEventLogged(event)) {
            string sType       = OperationTypeDescription(OrderType());
            string sLots       = NumberToStr(OrderLots(), ".+");
            int    digits      = MarketInfo(OrderSymbol(), MODE_DIGITS);
            int    pipDigits   = digits & (~1);
            string priceFormat = StringConcatenate(",'R.", pipDigits, ifString(digits==pipDigits, "", "'"));
            string sPrice      = NumberToStr(OrderOpenPrice(), priceFormat);
            string comment     = ifString(StringLen(OrderComment()), " ("+ DoubleQuoteStr(OrderComment()) +")", "");
            string message     = "position opened: #"+ OrderTicket() +" "+ sType +" "+ sLots +" "+ OrderSymbol() +" at "+ sPrice + comment;
            logInfo("onPositionOpen(2)  "+ message);
            eventLogged = SetOrderEventLogged(event, true);
         }
      }
   }
   OrderPop();

   if (eventLogged && signal.sound)
      return(PlaySoundEx(signal.sound.positionOpened));
   return(!catch("onPositionOpen(3)"));
}


/**
 * Handle a PositionClose event.
 *
 * @param  int tickets[][] - ticket ids of the closed positions
 *
 * @return bool - success status
 */
bool onPositionClose(int tickets[][]) {
   bool isLogInfo=IsLogInfo(), eventLogged=false;
   int size = ArrayRange(tickets, 0);
   if (!size || !isLogInfo) return(true);

   string sCloseTypeDescr[] = {"", " (TakeProfit)", " (StopLoss)", " (StopOut)"};
   OrderPush();

   for (int i=0; i < size; i++) {
      if (!SelectTicket(tickets[i][0], "onPositionClose(1)")) continue;

      bool isMySymbol=(OrderSymbol()==Symbol()), isOtherListener=false;
      if (!isMySymbol) isOtherListener = IsOrderEventListener(OrderSymbol());

      if (isMySymbol || !isOtherListener) {
         string event = "rsf::PositionClose::#"+ OrderTicket();

         if (!IsOrderEventLogged(event)) {
            string sType       = OperationTypeDescription(OrderType());
            string sLots       = NumberToStr(OrderLots(), ".+");
            int    digits      = MarketInfo(OrderSymbol(), MODE_DIGITS);
            int    pipDigits   = digits & (~1);
            string priceFormat = StringConcatenate(",'R.", pipDigits, ifString(digits==pipDigits, "", "'"));
            string sOpenPrice  = NumberToStr(OrderOpenPrice(), priceFormat);
            string sClosePrice = NumberToStr(OrderClosePrice(), priceFormat);
            string comment     = ifString(StringLen(OrderComment()), " ("+ DoubleQuoteStr(OrderComment()) +")", "");
            string message     = "position closed: #"+ OrderTicket() +" "+ sType +" "+ sLots +" "+ OrderSymbol() + comment +" open="+ sOpenPrice +" close="+ sClosePrice + sCloseTypeDescr[tickets[i][1]];
            logInfo("onPositionClose(2)  "+ message);
            eventLogged = SetOrderEventLogged(event, true);
         }
      }
   }
   OrderPop();

   if (eventLogged && signal.sound)
      return(PlaySoundEx(signal.sound.positionClosed));
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
   if (!size) return(true);

   bool eventLogged = false;
   OrderPush();

   for (int i=0; i < size; i++) {
      if (!SelectTicket(tickets[i], "onOrderFail(1)")) return(false);

      bool isMySymbol=(OrderSymbol()==Symbol()), isOtherListener=false;
      if (!isMySymbol) isOtherListener = IsOrderEventListener(OrderSymbol());

      if (isMySymbol || !isOtherListener) {
         string event = "rsf::OrderFail::#"+ OrderTicket();

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
      return(PlaySoundEx(signal.sound.orderFailed));
   return(!catch("onOrderFail(3)"));
}


/**
 * Whether there is a registered order event listener for the specified symbol.
 *
 * @param  string symbol
 *
 * @return bool
 */
bool IsOrderEventListener(string symbol) {
   string name = "rsf::order-tracker::"+ StrToLower(symbol);
   return(GetWindowIntegerA(hWndTerminal, name) > 0);
}


/**
 * Whether the specified order event was already logged.
 *
 * @param  string event - event identifier
 *
 * @return bool
 */
bool IsOrderEventLogged(string event) {
   return(GetWindowIntegerA(hWndTerminal, event) > 0);
}


/**
 * Set the logging status of the specified order event.
 *
 * @param  string event  - event identifier
 * @param  bool   status - logging status
 *
 * @return bool - success status
 */
bool SetOrderEventLogged(string event, bool status) {
   status = status!=0;
   return(SetWindowIntegerA(hWndTerminal, event, status) != 0);
}


/**
 * Calculate and return the average daily range. Implemented as LWMA(20, ATR(1)).
 *
 * @return double - ADR in absolute terms or NULL in case of errors
 */
double iADR() {
   static double adr;                                    // TODO: invalidate static cache on BarOpen(D1)

   if (!adr) {                                           // TODO: convert to current timeframe for non-FXT brokers
      double ranges[];
      int maPeriods = 20;
      ArrayResize(ranges, maPeriods);
      ArraySetAsSeries(ranges, true);
      for (int i=0; i < maPeriods; i++) {
         ranges[i] = iATR(NULL, PERIOD_D1, 1, i+1);
      }
      double ma = iMAOnArray(ranges, WHOLE_ARRAY, maPeriods, 0, MODE_LWMA, 0);

      int error = GetLastError();
      if (error != NO_ERROR) {
         if (error == ERS_HISTORY_UPDATE) return(ma);    // don't store result in cache to resolve it another time
         return(!catch("iADR(1)", error));
      }
      adr = ma;
   }
   return(adr);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("displayedPrice=", PriceTypeToStr(displayedPrice), ";", NL,
                            "Track.Orders=",   DoubleQuoteStr(Track.Orders),   ";", NL,
                            "Offline.Ticker=", BoolToStr(Offline.Ticker),      ";", NL,
                            "Signal.Sound=",   DoubleQuoteStr(Signal.Sound),   ";", NL,
                            "Signal.Mail=",    DoubleQuoteStr(Signal.Mail),    ";", NL,
                            "Signal.SMS=",     DoubleQuoteStr(Signal.SMS),     ";")
   );
}


#import "rsfLib.ex4"
   bool     AquireLock(string mutexName, bool wait);
   int      ArrayDropInt          (int    &array[], int value);
   int      ArrayInsertDoubleArray(double &array[][], int offset, double values[]);
   int      ArrayInsertDoubles    (double &array[], int offset, double values[]);
   int      ArrayPushDouble       (double &array[], double value);
   int      ArraySpliceInts       (int    &array[], int offset, int length);
   int      ChartInfos.CopyLfxOrders(bool direction, /*LFX_ORDER*/int orders[][], int iData[][], bool bData[][], double dData[][]);
   bool     ChartMarker.OrderSent_A(int ticket, int digits, color markerColor);
   int      DeleteRegisteredObjects();
   datetime FxtToServerTime(datetime fxtTime);
   string   GetHostName();
   string   GetLongSymbolNameOrAlt(string symbol, string altValue);
   string   GetSymbolName(string symbol);
   string   IntsToStr(int array[], string separator);
   int      RegisterObject(string label);
   bool     ReleaseLock(string mutexName);
   int      SearchStringArrayI(string haystack[], string needle);
   bool     SortOpenTickets(int &keys[][]);
   string   StringsToStr(string array[], string separator);
   string   TicketsToStr.Lots    (int array[], string separator);
   string   TicketsToStr.Position(int array[]);
#import
