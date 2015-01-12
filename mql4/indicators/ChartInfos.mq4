/**
 * Zeigt im Chart verschiedene Informationen zum Instrument und den aktuell offenen Positionen eines der folgenden Typen an:
 *
 * (1) interne Positionen: - Positionen, die im aktuellen Account gehalten werden
 *                         - Order- und P/L-Daten stammen vom Terminal
 *
 * (2) externe Positionen: - Positionen, die in einem anderen Account gehalten werden
 *                         - Orderdaten stammen aus einer externen Quelle
 *                         - P/L-Daten werden anhand der aktuellen Kurse selbst berechnet
 *
 * (3) Remote-Positionen:  - Positionen, die in einem anderen Account gehalten werden (typischerweise LFX-Positionen)
 *                         - Orderdaten stammen aus einer externen Quelle
 *                         - P/L-Daten stammen ebenfalls aus einer externen Quelle
 *                         - aktive Limit-Orders können überwacht und die externe Quelle vom Erreichen benachrichtigt werden
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>

#include <MT4iQuickChannel.mqh>
#include <win32api.mqh>

#include <core/script.ParameterProvider.mqh>
#include <LFX/functions.mqh>
#include <LFX/quickchannel.mqh>
#include <structs/pewa/LFX_ORDER.mqh>


// Kursanzeige
int appliedPrice = PRICE_MEDIAN;                                     // Preis: Bid | Ask | Median (default)


// Moneymanagement
#define DEFAULT_VOLATILITY     2.5                                   // Default-Volatilität einer Unit in Prozent Equity je Woche (Erfahrungswert)

bool   mm.done;
double mm.unleveragedLots;                                           // Lotsize bei Hebel 1:1
double mm.ATRwAbs;                                                   // ATR: absoluter Wert
double mm.ATRwPct;                                                   // ATR: prozentualer Wert

double mm.vola = DEFAULT_VOLATILITY;
double mm.volaLeverage;                                              // Hebel für wöchentliche Volatilität einer Unit von {mm.vola} Prozent
double mm.volaLots;                                                  // resultierende Lotsize

bool   mm.isCustomLeverage;                                          // ob die Lotsize nach benutzerdefiniertem Hebel oder nach Volatility berechnet wird
double mm.customLeverage;                                            // benutzerdefinierter Hebel einer Unit
double mm.customLots;                                                // resultierende Lotsize

double aum.value;                                                    // zusätzliche extern verwaltete und bei Equity-Berechnungen zu berücksichtigende Assets
string aum.currency = "";


// Status
bool   positionsAnalyzed;                                            // - Interne Positionsdaten stammen aus dem Terminal selbst, sie werden bei jedem Tick zurückgesetzt und neu
bool   mode.intern;                                                  //   eingelesen, Orderänderungen werden automatisch erkannt.
bool   mode.extern;                                                  // - Externe und Remote-Positionsdaten stammen aus einer externen Quelle und werden nur bei Timeframe-Wechsel
bool   mode.remote;                                                  //   oder nach Eintreffen einer entsprechenden Nachricht zurückgesetzt und aus der Quelle neu eingelesen,
                                                                     //   Orderänderungen werden nicht automatisch erkannt.

// individuelle Positionskonfiguration
double custom.position.conf      [][3];                              // Format siehe ReadCustomPositionConfig()
string custom.position.conf.comments[];


// interne + externe Positionsdaten
bool   isPosition;                                                   // ob offene Positionen existieren = (longPosition || shortPosition);   // die Gesamtposition kann flat sein
double totalPosition;
double longPosition;
double shortPosition;
int    positions.idata[][3];                                         // Positionsdetails: [] = {PositionType, DirectionType, idxComment}
double positions.ddata[][7];                                         //                   [] = {DirectionalLotSize, HedgedLotSize, BreakevenPrice|Pips, Profit, Amount, OpenEquity, Drawdown}

#define TYPE_DEFAULT       0                                         // PositionTypes:    normale Position (intern oder extern)
#define TYPE_CUSTOM        1                                         //                   individuell konfigurierte reale Position
#define TYPE_VIRTUAL       2                                         //                   individuell konfigurierte virtuelle Position

#define TYPE_LONG          1                                         // DirectionTypes
#define TYPE_SHORT         2
#define TYPE_HEDGE         3
#define TYPE_EQUITY        4
#define TYPE_AMOUNT        5

#define I_POSITION_TYPE    0                                         // Arrayindizes von positions.idata[]
#define I_DIRECTION_TYPE   1
#define I_COMMENT          2

#define I_DIRECT_LOTSIZE   0                                         // Arrayindizes von positions.ddata[]
#define I_HEDGED_LOTSIZE   1
#define I_BREAKEVEN        2
#define I_PROFIT           3
#define I_CUSTOM_AMOUNT    4
#define I_OPEN_EQUITY      5
#define I_PROFIT_PERCENT   6


// externe Positionen
string   external.provider = "";
string   external.signal   = "";
string   external.name     = "";

// externe Positionen: open
int      external.open.ticket    [];
int      external.open.type      [];
double   external.open.lots      [];
datetime external.open.openTime  [];
double   external.open.openPrice [];
double   external.open.takeProfit[];
double   external.open.stopLoss  [];
double   external.open.commission[];
double   external.open.swap      [];
double   external.open.profit    [];
bool     external.open.lots.checked;
double   external.open.longPosition, external.open.shortPosition;

// externe Positionen: closed
int      external.closed.ticket    [];
int      external.closed.type      [];
double   external.closed.lots      [];
datetime external.closed.openTime  [];
double   external.closed.openPrice [];
datetime external.closed.closeTime [];
double   external.closed.closePrice[];
double   external.closed.takeProfit[];
double   external.closed.stopLoss  [];
double   external.closed.commission[];
double   external.closed.swap      [];
double   external.closed.profit    [];


// LFX-Positionensdaten (remote)
int    lfxOrders.ivolatile[][3];                                     // veränderliche Positionsdaten: = {Ticket, IsOpen, IsLocked}
double lfxOrders.dvolatile[][1];                                     //                               = {Profit}
int    lfxOrders.openPositions;                                      // Anzahl der offenen Positionen in den offenen Orders (IsOpen = 1)

#define I_TICKET           0                                         // Arrayindizes von lfxOrders.~volatile[]
#define I_ISOPEN           1
#define I_ISLOCKED         2
#define I_VPROFIT          0


// Textlabel für die einzelnen Anzeigen
string label.instrument      = "Instrument";
string label.ohlc            = "OHLC";
string label.price           = "Price";
string label.spread          = "Spread";
string label.aum             = "AuM";
string label.position        = "Position";
string label.unitSize        = "UnitSize";
string label.externalAccount = "ExternalAccount";
string label.lfxTradeAccount = "LfxTradeAccount";
string label.stopoutLevel    = "StopoutLevel";
string label.time            = "Time";


// Font-Settings der detaillierten Positionsanzeige
string positions.fontName          = "MS Sans Serif";
int    positions.fontSize          = 8;
color  positions.fontColor.intern  = Blue;
color  positions.fontColor.extern  = Red;
color  positions.fontColor.remote  = Blue;
color  positions.fontColor.virtual = Green;


// Farben für Orderanzeige
#define CLR_PENDING_OPEN         DeepSkyBlue
#define CLR_OPEN_LONG            C'0,0,254'                          // Blue - rgb(1,1,1)
#define CLR_OPEN_SHORT           C'254,0,0'                          // Red  - rgb(1,1,1)
#define CLR_OPEN_TAKEPROFIT      LimeGreen
#define CLR_OPEN_STOPLOSS        Red
#define CLR_CLOSED_LONG          Blue
#define CLR_CLOSED_SHORT         Red
#define CLR_CLOSE                Orange


#include <ChartInfos/init.mqh>
#include <ChartInfos/deinit.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   mm.done           = false;
   positionsAnalyzed = false;


   HandleEvent(EVENT_CHART_CMD);                                     // ChartCommands verarbeiten


   if (!UpdatePrice())                     return(last_error);
   if (!UpdateOHLC())                      return(last_error);

   if (isLfxInstrument) {
      if (!QC.HandleLfxTerminalMessages()) return(last_error);       // Listener für beim LFX-Terminal eingehende Messages
      if (!UpdatePositions())              return(last_error);
      if (!CheckLfxLimits())               return(last_error);
   }
   else {
      if (!QC.HandleTradeCommands())       return(last_error);       // Listener für beim Terminal eingehende Trade-Commands
      if (!UpdateSpread())                 return(last_error);
      if (!UpdateUnitSize())               return(last_error);
      if (!UpdatePositions())              return(last_error);
      if (!UpdateStopoutLevel())           return(last_error);
   }

   if (IsVisualMode())                                               // nur im Tester
      UpdateTime();
   return(last_error);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein ChartCommand für diesen Indikator eingetroffen ist.
 *
 * @param  string commands[] - Array zur Aufnahme der eingetroffenen Commands
 * @param  int    flags      - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 */
bool EventListener.ChartCommand(string &commands[], int flags=NULL) {
   if (!IsChart)
      return(false);

   static string label, mutex; if (!StringLen(label)) {
      label = __NAME__ +".command";
      mutex = "mutex."+ label;
   }

   // (1) zuerst nur Lesezugriff (unsynchronisiert möglich), um nicht bei jedem Tick das Lock erwerben zu müssen
   if (ObjectFind(label) == 0) {

      // (2) erst wenn ein Command eingetroffen ist, Lock für Schreibzugriff holen
      if (!AquireLock(mutex, true))
         return(!SetLastError(stdlib.GetLastError()));

      // (3) Command auslesen und Command-Object löschen
      ArrayResize(commands, 1);
      commands[0] = ObjectDescription(label);
      ObjectDelete(label);

      // (4) Lock wieder freigeben
      if (!ReleaseLock(mutex))
         return(!SetLastError(stdlib.GetLastError()));

      return(!catch("EventListener.ChartCommand(1)"));
   }
   return(false);
}


/**
 * Handler für ChartCommands.
 *
 * @param  string commands[] - die eingetroffenen Commands
 *
 * @return bool - Erfolgsstatus
 *
 *
 * Messageformat: "cmd=TrackSignal,{signalId}" - Schaltet das Signaltracking auf das angegebene Signal um.
 *                "cmd=ToggleOpenOrders"       - Schaltet die Anzeige der offenen Orders ein/aus.
 *                "cmd=ToggleTradeHistory"     - Schaltet die Anzeige der Trade-History ein/aus.
 *                "cmd=ToggleAuM"              - Schaltet die Assets-under-Management-Anzeige ein/aus.
 *                "cmd=EditAccountConfig"      - Lädt die Konfigurationsdatei des aktuellen Accounts in den Editor.
 */
bool onChartCommand(string commands[]) {
   int size = ArraySize(commands);
   if (!size) return(!warn("onChartCommand(1)   empty parameter commands = {}"));

   for (int i=0; i < size; i++) {
      if (StringFind(commands[i], "cmd=TrackSignal,") == 0) {
         if (!TrackSignal(StringSubstr(commands[i], 16)))
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
      if (commands[i] == "cmd=ToggleAuM") {
         if (!ToggleAuM())
            return(false);
         continue;
      }
      if (commands[i] == "cmd=EditAccountConfig") {
         if (!EditAccountConfig())
            return(false);
         continue;
      }
      warn("onChartCommand(2)   unknown chart command \""+ commands[i] +"\"");
   }
   return(!catch("onChartCommand(3)"));
}


/**
 * Schaltet die Anzeige der offenen Orders ein/aus.
 *
 * @return bool - Erfolgsstatus
 */
bool ToggleOpenOrders() {
   // aktuellen Anzeigestatus aus Chart auslesen und umschalten: ON/OFF
   bool status = !GetOpenOrderDisplayStatus();

   // Status ON: offene Orders anzeigen
   if (status) {
      int orders = ShowOpenOrders();
      if (orders == -1)
         return(false);
      if (!orders) {                                                 // ohne offene Orders bleibt die Anzeige unverändert
         status = false;
         ForceSound("Plonk.wav");                                    // Plonk!!!
      }
   }

   // Status OFF: Chartobjekte offener Orders löschen
   else {
      for (int i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);
         if (StringGetChar(name, 0) == '#') {
            if (ObjectType(name)==OBJ_ARROW) {
               int arrow = ObjectGet(name, OBJPROP_ARROWCODE);
               color clr = ObjectGet(name, OBJPROP_COLOR    );
               if (arrow == SYMBOL_ORDEROPEN)
                  if (clr!=CLR_PENDING_OPEN) /*&&*/ if (clr!=CLR_OPEN_LONG) /*&&*/ if (clr!=CLR_OPEN_SHORT)
                     continue;
               if (arrow == SYMBOL_ORDERCLOSE)
                  if (clr!=CLR_OPEN_TAKEPROFIT) /*&&*/ if (clr!=CLR_OPEN_STOPLOSS)
                     continue;
               ObjectDelete(name);
            }
         }
      }
   }

   // Anzeigestatus im Chart speichern
   SetOpenOrderDisplayStatus(status);

   if (This.IsTesting())
      WindowRedraw();
   return(!catch("ToggleOpenOrders(1)"));
}


/**
 * Zeigt alle aktuell offenen Orders an.
 *
 * @return int - Anzahl der angezeigten offenen Orders oder -1 (EMPTY), falls ein Fehler auftrat.
 */
int ShowOpenOrders() {
   int      orders, ticket, type, colors[]={CLR_OPEN_LONG, CLR_OPEN_SHORT};
   datetime openTime;
   double   lots, openPrice, takeProfit, stopLoss;
   string   label1, label2, label3, sTP, sSL, types[]={"buy", "sell", "buy limit", "sell limit", "buy stop", "sell stop"};


   // (1) mode.intern
   if (mode.intern) {
      orders = OrdersTotal();

      for (int i=0, n; i < orders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))                  // FALSE: während des Auslesens wurde von dritter Seite eine offene Order geschlossen oder gelöscht
            break;
         if (OrderSymbol() != Symbol()) continue;

         // Daten auslesen
         ticket     = OrderTicket();
         type       = OrderType();
         lots       = OrderLots();
         openTime   = OrderOpenTime();
         openPrice  = OrderOpenPrice();
         takeProfit = OrderTakeProfit();
         stopLoss   = OrderStopLoss();

         if (OrderType() > OP_SELL) {
            // Pending-Order
            label1 = StringConcatenate("#", ticket, " ", types[type], " ", DoubleToStr(lots, 2), " at ", NumberToStr(openPrice, PriceFormat));

            // Order anzeigen
            if (ObjectFind(label1) == 0)
               ObjectDelete(label1);
            if (ObjectCreate(label1, OBJ_ARROW, 0, TimeCurrent(), openPrice)) {
               ObjectSet(label1, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
               ObjectSet(label1, OBJPROP_COLOR,     CLR_PENDING_OPEN);
            }
         }
         else {
            // offene Position
            label1 = StringConcatenate("#", ticket, " ", types[type], " ", DoubleToStr(lots, 2), " at ", NumberToStr(openPrice, PriceFormat));

            // TakeProfit anzeigen
            if (takeProfit != NULL) {
               sTP    = StringConcatenate("TP: ", NumberToStr(takeProfit, PriceFormat));
               label2 = StringConcatenate(label1, ",  ", sTP);
               if (ObjectFind(label2) == 0)
                  ObjectDelete(label2);
               if (ObjectCreate(label2, OBJ_ARROW, 0, TimeCurrent(), takeProfit)) {
                  ObjectSet(label2, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE  );
                  ObjectSet(label2, OBJPROP_COLOR,     CLR_OPEN_TAKEPROFIT);
               }
            }
            else sTP = "";

            // StopLoss anzeigen
            if (stopLoss != NULL) {
               sSL    = StringConcatenate("SL: ", NumberToStr(stopLoss, PriceFormat));
               label3 = StringConcatenate(label1, ",  ", sSL);
               if (ObjectFind(label3) == 0)
                  ObjectDelete(label3);
               if (ObjectCreate(label3, OBJ_ARROW, 0, TimeCurrent(), stopLoss)) {
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
               ObjectSetText(label1, StringConcatenate(sTP, "   ", sSL));
            }
         }
         n++;
      }
      return(n);
   }


   // (2) mode.extern
   if (mode.extern) {
      orders = ArraySize(external.open.ticket);

      for (i=0; i < orders; i++) {
         // Daten auslesen
         ticket     =                 external.open.ticket    [i];
         type       =                 external.open.type      [i];
         lots       =                 external.open.lots      [i];
         openTime   = FxtToServerTime(external.open.openTime  [i]);
         openPrice  =                 external.open.openPrice [i];
         takeProfit =                 external.open.takeProfit[i];
         stopLoss   =                 external.open.stopLoss  [i];

         // Hauptlabel erstellen
         label1 = StringConcatenate("#", ticket, " ", types[type], " ", DoubleToStr(lots, 2), " at ", NumberToStr(openPrice, SubPipPriceFormat));

         // TakeProfit anzeigen
         if (takeProfit != NULL) {
            sTP = StringConcatenate("TP: ", NumberToStr(takeProfit, SubPipPriceFormat));
         }
         else sTP = "";

         // StopLoss anzeigen
         if (stopLoss != NULL) {
            sSL = StringConcatenate("SL: ", NumberToStr(stopLoss, SubPipPriceFormat));
         }
         else sSL = "";

         // Order anzeigen
         if (ObjectFind(label1) == 0)
            ObjectDelete(label1);
         if (ObjectCreate(label1, OBJ_ARROW, 0, openTime, openPrice)) {
            ObjectSet(label1, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
            ObjectSet(label1, OBJPROP_COLOR,     colors[type]    );
            ObjectSetText(label1, StringConcatenate(sTP, "   ", sSL));
         }
      }
      return(orders);
   }


   // (3) mode.remote
   if (mode.remote) {
      return(_EMPTY(catch("ShowOpenOrders(1)   feature not implemented for mode.remote=1", ERR_NOT_IMPLEMENTED)));
   }

   return(_EMPTY(catch("ShowOpenOrder(2)   unreachable code reached", ERR_RUNTIME_ERROR)));
}


/**
 * Liest den im Chart gespeicherten aktuellen OpenOrder-Anzeigestatus aus.
 *
 * @return bool - Status: ON/OFF
 */
bool GetOpenOrderDisplayStatus() {
   // TODO: Status statt im Chart im Fenster lesen/schreiben
   string label = __NAME__ +".OpenOrderDisplay.status";
   if (ObjectFind(label) != -1)
      return(StrToInteger(ObjectDescription(label)) != 0);
   return(false);
}


/**
 * Speichert den angegebenen OpenOrder-Anzeigestatus im Chart.
 *
 * @param  bool status - Status
 *
 * @return bool - Erfolgsstatus
 */
bool SetOpenOrderDisplayStatus(bool status) {
   status = status!=0;

   // TODO: Status statt im Chart im Fenster lesen/schreiben
   string label = __NAME__ +".OpenOrderDisplay.status";
   if (ObjectFind(label) == -1)
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);

   ObjectSet    (label, OBJPROP_XDISTANCE, -1000);                   // Label in unsichtbaren Bereich setzen
   ObjectSetText(label, ""+ status, 0);

   return(!catch("SetOpenOrderDisplayStatus()"));
}


/**
 * Schaltet die Anzeige der Trade-History (geschlossene Positionen) ein/aus.
 *
 * @return bool - Erfolgsstatus
 */
bool ToggleTradeHistory() {
   // aktuellen Anzeigestatus aus Chart auslesen und umschalten: ON/OFF
   bool status = !GetTradeHistoryDisplayStatus();

   // Status ON: Trade-History anzeigen
   if (status) {
      int trades = ShowTradeHistory();
      if (trades == -1)
         return(false);
      if (!trades) {                                                 // ohne Trade-History bleibt die Anzeige unverändert
         status = false;
         ForceSound("Plonk.wav");                                    // Plonk!!!
      }
   }

   // Status OFF: Chartobjekte der Trade-History löschen
   else {
      for (int i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);
         if (StringGetChar(name, 0) == '#') {
            if (ObjectType(name) == OBJ_ARROW) {
               int arrow = ObjectGet(name, OBJPROP_ARROWCODE);
               color clr = ObjectGet(name, OBJPROP_COLOR    );
               if (arrow == SYMBOL_ORDEROPEN)
                  if (clr!=CLR_CLOSED_LONG) /*&&*/ if (clr!=CLR_CLOSED_SHORT)
                     continue;
               if (arrow == SYMBOL_ORDERCLOSE)
                  if (clr!=CLR_CLOSE)
                     continue;
               ObjectDelete(name);
            }
            else if (ObjectType(name) == OBJ_TREND) {
               ObjectDelete(name);
            }
         }
      }
   }

   // Anzeigestatus im Chart speichern
   SetTradeHistoryDisplayStatus(status);

   if (This.IsTesting())
      WindowRedraw();
   return(!catch("ToggleTradeHistory(1)"));
}


/**
 * Liest den im Chart gespeicherten aktuellen TradeHistory-Anzeigestatus aus.
 *
 * @return bool - Status: ON/OFF
 */
bool GetTradeHistoryDisplayStatus() {
   // TODO: Status statt im Chart im Fenster lesen/schreiben
   string label = __NAME__ +".TradeHistoryDisplay.status";
   if (ObjectFind(label) != -1)
      return(StrToInteger(ObjectDescription(label)) != 0);
   return(false);
}


/**
 * Speichert den angegebenen TradeHistory-Anzeigestatus im Chart.
 *
 * @param  bool status - Status
 *
 * @return bool - Erfolgsstatus
 */
bool SetTradeHistoryDisplayStatus(bool status) {
   status = status!=0;

   // TODO: Status statt im Chart im Fenster lesen/schreiben
   string label = __NAME__ +".TradeHistoryDisplay.status";
   if (ObjectFind(label) == -1)
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);

   ObjectSet    (label, OBJPROP_XDISTANCE, -1000);                   // Label in unsichtbaren Bereich setzen
   ObjectSetText(label, ""+ status, 0);

   return(!catch("SetTradeHistoryDisplayStatus()"));
}


#import "stdlib2.ex4"
   string IntsToStr (int array[], string separator);
#import


/**
 * Zeigt die Trade-History an.
 *
 * @return int - Anzahl der angezeigten geschlossenen Positionen oder -1 (EMPTY), falls ein Fehler auftrat.
 */
int ShowTradeHistory() {
   int      orders, ticket, type, markerColors[]={CLR_CLOSED_LONG, CLR_CLOSED_SHORT}, lineColors[]={Blue, Red};
   datetime openTime, closeTime;
   double   lots, openPrice, closePrice;
   string   sOpenPrice, sClosePrice, openLabel, lineLabel, closeLabel, sTypes[]={"buy", "sell"};


   // (1) mode.intern
   if (mode.intern) {
      // (1.1) Sortierschlüssel aller geschlossenen Positionen auslesen und nach {CloseTime, OpenTime, Ticket} sortieren
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

      // (1.2) Tickets sortiert einlesen
      int      tickets    []; ArrayResize(tickets    , 0);
      int      types      []; ArrayResize(types      , 0);
      double   lotSizes   []; ArrayResize(lotSizes   , 0);
      datetime openTimes  []; ArrayResize(openTimes  , 0);
      datetime closeTimes []; ArrayResize(closeTimes , 0);
      double   openPrices []; ArrayResize(openPrices , 0);
      double   closePrices[]; ArrayResize(closePrices, 0);
      double   commissions[]; ArrayResize(commissions, 0);
      double   swaps      []; ArrayResize(swaps      , 0);
      double   profits    []; ArrayResize(profits    , 0);
      string   comments   []; ArrayResize(comments   , 0);

      for (i=0; i < orders; i++) {
         if (!SelectTicket(sortKeys[i][2], "ShowTradeHistory(1)"))
            return(-1);
         ArrayPushInt   (tickets    , OrderTicket()    );
         ArrayPushInt   (types      , OrderType()      );
         ArrayPushDouble(lotSizes   , OrderLots()      );
         ArrayPushInt   (openTimes  , OrderOpenTime()  );
         ArrayPushInt   (closeTimes , OrderCloseTime() );
         ArrayPushDouble(openPrices , OrderOpenPrice() );
         ArrayPushDouble(closePrices, OrderClosePrice());
         ArrayPushDouble(commissions, OrderCommission());
         ArrayPushDouble(swaps      , OrderSwap()      );
         ArrayPushDouble(profits    , OrderProfit()    );
         ArrayPushString(comments   , OrderComment()   );
      }
      /*
      for (i=0; i < orders; i++) {
         if (!SelectTicket(sortKeys[i][2], "ShowTradeHistory(2)"))
            return(-1);
         debug("ShowTradeHistory(0.1)   #"+ OrderTicket() +"  from="+ TimeToStr(OrderOpenTime(), TIME_FULL) +"  to="+ TimeToStr(OrderCloseTime(), TIME_FULL) +", "+ OperationTypeDescription(OrderType()) +" "+ DoubleToStr(OrderLots(), 2) +" "+ OrderSymbol() +"  O="+ NumberToStr(OrderOpenPrice(), PriceFormat) +"  C="+ NumberToStr(OrderClosePrice(), PriceFormat) +" for "+ DoubleToStr(OrderProfit(), 2));
      }
      */

      // (1.3) Hedges korrigieren: alle Daten dem ersten Ticket zuordnen und hedgendes Ticket verwerfen
      for (i=0; i < orders; i++) {
         if (tickets[i] && EQ(lotSizes[i], 0)) {                     // lotSize = 0: Hedge-Position
            // TODO: Prüfen, wie sich OrderComment() bei custom comments verhält.

            if (!StringIStartsWith(comments[i], "close hedge by #"))
               return(_EMPTY(catch("ShowTradeHistory(3)   #"+ tickets[i] +" - unknown comment for assumed hedging position: \""+ comments[i] +"\"", ERR_RUNTIME_ERROR)));

            // Gegenstück suchen
            ticket = StrToInteger(StringSubstr(comments[i], 16));
            for (n=0; n < orders; n++) {
               if (tickets[n] == ticket)
                  break;
            }
            if (n == orders) return(_EMPTY(catch("ShowTradeHistory(4)   cannot find counterpart for hedging position #"+ tickets[i] +": \""+ comments[i] +"\"", ERR_RUNTIME_ERROR)));
            if (i == n     ) return(_EMPTY(catch("ShowTradeHistory(5)   both hedged and hedging position have the same ticket #"+ tickets[i] +": \""+ comments[i] +"\"", ERR_RUNTIME_ERROR)));

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

      // (1.4) Orders anzeigen
      for (i=0; i < orders; i++) {
         if (!tickets[i])                                            // verworfene Hedges überspringen
            continue;
         sOpenPrice  = NumberToStr(openPrices [i], PriceFormat);
         sClosePrice = NumberToStr(closePrices[i], PriceFormat);

         // Open-Marker anzeigen
         openLabel = StringConcatenate("#", tickets[i], " ", sTypes[types[i]], " ", DoubleToStr(lotSizes[i], 2), " at ", sOpenPrice);
         if (ObjectFind(openLabel) == 0)
            ObjectDelete(openLabel);
         if (ObjectCreate(openLabel, OBJ_ARROW, 0, openTimes[i], openPrices[i])) {
            ObjectSet(openLabel, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN      );
            ObjectSet(openLabel, OBJPROP_COLOR    , markerColors[types[i]]);
         }

         // Trendlinie anzeigen
         lineLabel = StringConcatenate("#", tickets[i], " ", sOpenPrice, " -> ", sClosePrice);
         if (ObjectFind(lineLabel) == 0)
            ObjectDelete(lineLabel);
         if (ObjectCreate(lineLabel, OBJ_TREND, 0, openTimes[i], openPrices[i], closeTimes[i], closePrices[i])) {
            ObjectSet(lineLabel, OBJPROP_RAY  , false               );
            ObjectSet(lineLabel, OBJPROP_STYLE, STYLE_DOT           );
            ObjectSet(lineLabel, OBJPROP_COLOR, lineColors[types[i]]);
            ObjectSet(lineLabel, OBJPROP_BACK , true                );
         }

         // Close-Marker anzeigen                                    // "#1 buy 0.10 GBPUSD at 1.53024 close[ by tester] at 1.52904"
         closeLabel = StringConcatenate(openLabel, " close at ", sClosePrice);
         if (ObjectFind(closeLabel) == 0)
            ObjectDelete(closeLabel);
         if (ObjectCreate(closeLabel, OBJ_ARROW, 0, closeTimes[i], closePrices[i])) {
            ObjectSet(closeLabel, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
            ObjectSet(closeLabel, OBJPROP_COLOR    , CLR_CLOSE        );
         }
         n++;
      }
      return(n);
   }


   // (2) mode.extern
   if (mode.extern) {
      orders = ArraySize(external.closed.ticket);

      for (i=0; i < orders; i++) {
         // Daten auslesen
         ticket     =                 external.closed.ticket    [i];
         type       =                 external.closed.type      [i];
         lots       =                 external.closed.lots      [i];
         openTime   = FxtToServerTime(external.closed.openTime  [i]);
         openPrice  =                 external.closed.openPrice [i];  sOpenPrice  = NumberToStr(openPrice, PriceFormat);
         closeTime  = FxtToServerTime(external.closed.closeTime [i]);
         closePrice =                 external.closed.closePrice[i];  sClosePrice = NumberToStr(closePrice, PriceFormat);

         // Open-Marker anzeigen
         openLabel = StringConcatenate("#", ticket, " ", sTypes[type], " ", DoubleToStr(lots, 2), " at ", sOpenPrice);
         if (ObjectFind(openLabel) == 0)
            ObjectDelete(openLabel);
         if (ObjectCreate(openLabel, OBJ_ARROW, 0, openTime, openPrice)) {
            ObjectSet(openLabel, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN  );
            ObjectSet(openLabel, OBJPROP_COLOR    , markerColors[type]);
         }

         // Trendlinie anzeigen
         lineLabel = StringConcatenate("#", ticket, " ", sOpenPrice, " -> ", sClosePrice);
         if (ObjectFind(lineLabel) == 0)
            ObjectDelete(lineLabel);
         if (ObjectCreate(lineLabel, OBJ_TREND, 0, openTime, openPrice, closeTime, closePrice)) {
            ObjectSet(lineLabel, OBJPROP_RAY  , false           );
            ObjectSet(lineLabel, OBJPROP_STYLE, STYLE_DOT       );
            ObjectSet(lineLabel, OBJPROP_COLOR, lineColors[type]);
            ObjectSet(lineLabel, OBJPROP_BACK , true            );
         }

         // Close-Marker anzeigen                                    // "#1 buy 0.10 GBPUSD at 1.53024 close[ by tester] at 1.52904"
         closeLabel = StringConcatenate(openLabel, " close at ", sClosePrice);
         if (ObjectFind(closeLabel) == 0)
            ObjectDelete(closeLabel);
         if (ObjectCreate(closeLabel, OBJ_ARROW, 0, closeTime, closePrice)) {
            ObjectSet(closeLabel, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE);
            ObjectSet(closeLabel, OBJPROP_COLOR    , CLR_CLOSE        );
         }
      }
      return(orders);
   }


   // (3) mode.remote
   if (mode.remote) {
      return(_EMPTY(catch("ShowTradeHistory(8)   feature not implemented for mode.remote=1", ERR_NOT_IMPLEMENTED)));
   }

   return(_EMPTY(catch("ShowTradeHistory(9)   unreachable code reached", ERR_RUNTIME_ERROR)));

   /*
   script ShowTradeHistory.onStart() [
   /*LFX_ORDER int los[][LFX_ORDER.intSize];
   int orders = LFX.GetOrders(Symbol(), OF_CLOSED, los);

   for (int i=0; i < orders; i++) {
      int      ticket      =                     los.Ticket       (los, i);
      int      type        =                     los.Type         (los, i);
      double   units       =                     los.Units        (los, i);
      datetime openTime    =     GmtToServerTime(los.OpenTime     (los, i));
      double   openPrice   =                     los.OpenPriceLfx (los, i);
      datetime closeTime   = GmtToServerTime(Abs(los.CloseTime    (los, i)));
      double   closePrice  =                     los.ClosePriceLfx(los, i);
      double   profit      =                     los.Profit       (los, i);
      color    markerColor = ifInt(type==OP_BUY, Blue, Red);
      string   comment     = "Profit: "+ DoubleToStr(profit, 2);

      if (!ChartMarker.OrderSent_B(ticket, SubPipDigits, markerColor, type, units, Symbol(), openTime, openPrice, NULL, NULL, comment)) {
         SetLastError(stdlib.GetLastError());
         break;
      }
      if (!ChartMarker.PositionClosed_B(ticket, SubPipDigits, Orange, type, units, Symbol(), openTime, openPrice, closeTime, closePrice)) {
         SetLastError(stdlib.GetLastError());
         break;
      }
   }
   ArrayResize(los, 0);
   return(last_error);
   */
}


/**
 * Schaltet die Assets-under-Management-Anzeige ein/aus.
 *
 * @return bool - Erfolgsstatus
 */
bool ToggleAuM() {
   // aktuellen Anzeigestatus aus Chart auslesen und umschalten: ON/OFF
   bool status = !GetAuMDisplayStatus();

   // Status ON
   if (status) {
      if (!RefreshExternalAssets())
         return(false);
      string strAum = " ";

      if (mode.intern) {
         strAum = ifString(!aum.value, "Balance:  ", "Assets:  ") + DoubleToStr(AccountBalance() + aum.value, 2) +" "+ AccountCurrency();
      }
      else if (mode.extern) {
         strAum = "Assets:  " + ifString(!aum.value, "n/a", DoubleToStr(aum.value, 2) +" "+ aum.currency);
      }
      else /*mode.remote*/{
         status = false;                                             // not implemented
         ForceSound("Plonk.wav");                                    // Plonk!!!
      }
      ObjectSetText(label.aum, strAum, 9, "Tahoma", SlateGray);
   }

   // Status OFF
   else {
      ObjectSetText(label.aum, " ", 1);
   }

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)              // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("ToggleAuM(1)", error));

   // Anzeigestatus im Chart speichern
   SetAuMDisplayStatus(status);

   if (This.IsTesting())
      WindowRedraw();
   return(!catch("ToggleAuM(2)"));
}


/**
 * Gibt den Wert der extern verwalteten Assets zurück.
 *
 * @return double - Wert oder NULL, falls keine AuM konfiguriert sind
 */
double GetExternalAssets() {
   static bool refreshed;
   if (!refreshed) {
      if (!RefreshExternalAssets())
         return(NULL);
      refreshed = true;
   }
   return(aum.value);
}


/**
 * Liest die Konfiguration der extern verwalteten Assets ernuet ein.
 *
 * @return bool - Erfolgsstatus
 */
bool RefreshExternalAssets() {
   string mqlDir   = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string file     = TerminalPath() + mqlDir +"\\files\\";
      if (mode.intern) file = file + ShortAccountCompany() +"\\"+ GetAccountNumber() +"_config.ini";
      else             file = file + external.provider     +"\\"+ external.signal    +"_config.ini";
   string section  = "General";
   string key      = "AuM.Value";

   double value = GetIniDouble(file, section, key, 0);
   if (!value) {
      aum.value    = 0;
      aum.currency = "";
      return(!catch("RefreshExternalAssets(1)"));
   }
   if (value < 0) return(!catch("RefreshExternalAssets(2)   invalid ini entry ["+ section +"]->"+ key +"=\""+ GetIniString(file, section, key, "") +"\" (negative value) in \""+ file +"\"", ERR_RUNTIME_ERROR));


   key = "AuM.Currency";
   string currency = GetIniString(file, section, key, "");
   if (!StringLen(currency)) {
      if (!IsIniKey(file, section, key)) return(!catch("RefreshExternalAssets(3)   missing ini entry ["+ section +"]->"+ key +" in \""+ file +"\"", ERR_RUNTIME_ERROR));
                                         return(!catch("RefreshExternalAssets(4)   invalid ini entry ["+ section +"]->"+ key +"=\"\" (empty value) in \""+ file +"\"", ERR_RUNTIME_ERROR));
   }
   aum.value    = value;
   aum.currency = StringToUpper(currency);

   return(!catch("RefreshExternalAssets(5)"));
}


/**
 * Liest den im Chart gespeicherten aktuellen AuM-Anzeigestatus aus.
 *
 * @return bool - Status: ON/OFF
 */
bool GetAuMDisplayStatus() {
   // TODO: Status statt im Chart im Fenster lesen/schreiben
   string label = __NAME__ +".AuMDisplay.status";
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
   string label = __NAME__ +".AuMDisplay.status";
   if (ObjectFind(label) == -1)
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);

   ObjectSet    (label, OBJPROP_XDISTANCE, -1000);                   // Label in unsichtbaren Bereich setzen
   ObjectSetText(label, ""+ status, 0);

   return(!catch("SetAuMDisplayStatus()"));
}


/**
 * Schaltet das Signaltracking um.
 *
 * @param  string signalId - das anzuzeigende Signal
 *
 * @return bool - Erfolgsstatus
 */
bool TrackSignal(string signalId) {
   bool signalChanged = false;

   if (signalId == "") {                                             // Leerstring bedeutet: Signaltracking/mode.extern = OFF
      if (!mode.intern) {
         mode.intern   = true;
         mode.extern   = false;
         mode.remote   = false;
         signalChanged = true;
      }
   }
   else {
      string provider="", signal="";
      if (!ParseSignal(signalId, provider, signal)) return(_true(warn("TrackSignal(1)   invalid or unknown parameter signalId=\""+ signalId +"\"")));

      if (!mode.extern || provider!=external.provider || signal!=external.signal) {
         mode.intern = false;
         mode.extern = true;
         mode.remote = false;

         external.provider = provider;
         external.signal   = signal;
            string mqlDir  = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
            string file    = TerminalPath() + mqlDir +"\\files\\"+ provider +"\\"+ signal +"_config.ini"; if (!IsFile(file)) return(!catch("TrackSignal(2)   file not found \""+ file +"\"", ERR_RUNTIME_ERROR));
            string section = "General";
            string key     = "Name";
            string value   = GetIniString(file, section, key, ""); if (!StringLen(value))                                    return(!catch("TrackSignal(3)   invalid ini entry ["+ section +"]->"+ key +" in \""+ file +"\" (empty value)", ERR_RUNTIME_ERROR));
         external.name     = value;

         external.open.lots.checked = false;
         if (-1 == ReadExternalPositions(provider, signal))
            return(false);
         signalChanged = true;
      }
   }

   if (signalChanged) {
      ArrayResize(custom.position.conf,          0);
      ArrayResize(custom.position.conf.comments, 0);
      if (!UpdateExternalAccount()) return(false);
      if (!RefreshExternalAssets()) return(false);
   }
   return(!catch("TrackSignal(4)"));
}


#define LIMIT_NONE        -1
#define LIMIT_ENTRY        1
#define LIMIT_STOPLOSS     2
#define LIMIT_TAKEPROFIT   3


/**
 * Überprüft alle LFX-Orders auf erreichte Limite: Pending-Open, StopLoss, TakeProfit
 *
 * @return bool - Erfolgsstatus
 */
bool CheckLfxLimits() {
   datetime triggerTime;
   int /*LFX_ORDER*/stored[], orders=ArrayRange(lfxOrders, 0);

   for (int i=0; i < orders; i++) {
      triggerTime = NULL;

      // (1) alle Limite einer Order prüfen
      int result = IsLfxLimitTriggered(i, triggerTime);
      if (!result)              return(false);
      if (result == LIMIT_NONE) continue;

      if (!triggerTime) {
         // (2) ein Limit wurde genau jetzt getriggert
         if (result == LIMIT_ENTRY     ) log("CheckLfxLimits(1)   #"+ los.Ticket(lfxOrders, i) +" "+ OperationTypeToStr(los.Type(lfxOrders, i))         +" at "+ NumberToStr(los.OpenPriceLfx (lfxOrders, i), SubPipPriceFormat) +" triggered (Bid="+ NumberToStr(Bid, PriceFormat) +")");
         if (result == LIMIT_STOPLOSS  ) log("CheckLfxLimits(2)   #"+ los.Ticket(lfxOrders, i) +" StopLoss"  + ifString(los.StopLossLfx  (lfxOrders, i), " at "+ NumberToStr(los.StopLossLfx  (lfxOrders, i), SubPipPriceFormat), "") + ifString(los.StopLossValue  (lfxOrders, i)!=EMPTY_VALUE, ifString(los.StopLossLfx  (lfxOrders, i), " or", "") +" value of "+ DoubleToStr(los.StopLossValue  (lfxOrders, i), 2), "") +" triggered");
         if (result == LIMIT_TAKEPROFIT) log("CheckLfxLimits(3)   #"+ los.Ticket(lfxOrders, i) +" TakeProfit"+ ifString(los.TakeProfitLfx(lfxOrders, i), " at "+ NumberToStr(los.TakeProfitLfx(lfxOrders, i), SubPipPriceFormat), "") + ifString(los.TakeProfitValue(lfxOrders, i)!=EMPTY_VALUE, ifString(los.TakeProfitLfx(lfxOrders, i), " or", "") +" value of "+ DoubleToStr(los.TakeProfitValue(lfxOrders, i), 2), "") +" triggered");

         // Auslösen speichern und TradeCommand verschicken
         if (result==LIMIT_ENTRY)       los.setOpenTriggerTime    (lfxOrders, i, TimeGMT());
         else {                         los.setCloseTriggerTime   (lfxOrders, i, TimeGMT());
            if (result==LIMIT_STOPLOSS) los.setStopLossTriggered  (lfxOrders, i, true     );
            else                        los.setTakeProfitTriggered(lfxOrders, i, true     );
         }
         if (!LFX.SaveOrder(lfxOrders, i))                                                                              return(false);
         if (!QC.SendTradeCommand("LFX:"+ los.Ticket(lfxOrders, i) + ifString(result==LIMIT_ENTRY, ":open", ":close"))) return(false);
      }
      else if (triggerTime + 30*SECONDS >= TimeGMT()) {
         // (3) ein Limit war bereits vorher getriggert, auf Ausführungsbestätigung warten
      }
      else {
         // (4) ein Limit war bereits vorher getriggert und die Ausführungsbestätigung ist überfällig
         if (LFX.GetOrder(los.Ticket(lfxOrders, i), stored) != 1)    // aktuell gespeicherte Version der Order holen
            return(!catch("CheckLfxLimits(4)->LFX.GetOrder(ticket="+ los.Ticket(lfxOrders, i) +") => "+ result, ERR_RUNTIME_ERROR));

         // prüfen, ob inzwischen ein Open- bzw. Close-Error gesetzt wurde und ggf. Fehler melden und speichern
         if (result == LIMIT_ENTRY) {
            if (!lo.IsOpenError(stored)) {
               warnSMS("CheckLfxLimits(5)   #"+ los.Ticket(lfxOrders, i) +" missing trade confirmation for triggered "+ OperationTypeToStr(los.Type(lfxOrders, i)) +" at "+ NumberToStr(los.OpenPriceLfx(lfxOrders, i), SubPipPriceFormat));
               los.setOpenTime(lfxOrders, i, -TimeGMT());
            }
         }
         else if (!lo.IsCloseError(stored)) {
            if (result == LIMIT_STOPLOSS) warnSMS("CheckLfxLimits(6)   #"+ los.Ticket(lfxOrders, i) +" missing trade confirmation for triggered StopLoss"  + ifString(los.StopLossLfx  (lfxOrders, i), " at "+ NumberToStr(los.StopLossLfx  (lfxOrders, i), SubPipPriceFormat), "") + ifString(los.StopLossValue  (lfxOrders, i)!=EMPTY_VALUE, ifString(los.StopLossLfx  (lfxOrders, i), " or", "") +" value of "+ DoubleToStr(los.StopLossValue  (lfxOrders, i), 2), ""));
            else                          warnSMS("CheckLfxLimits(7)   #"+ los.Ticket(lfxOrders, i) +" missing trade confirmation for triggered TakeProfit"+ ifString(los.TakeProfitLfx(lfxOrders, i), " at "+ NumberToStr(los.TakeProfitLfx(lfxOrders, i), SubPipPriceFormat), "") + ifString(los.TakeProfitValue(lfxOrders, i)!=EMPTY_VALUE, ifString(los.TakeProfitLfx(lfxOrders, i), " or", "") +" value of "+ DoubleToStr(los.TakeProfitValue(lfxOrders, i), 2), ""));
            los.setCloseTime(lfxOrders, i, -TimeGMT());
         }

         // Order speichern und beim nächsten Tick offene Orders neu einlesen
         if (!LFX.SaveOrder(lfxOrders, i))                                                                                                      return(false);
         if (!QC.SendOrderNotification(lfxCurrencyId, "LFX:"+ los.Ticket(lfxOrders, i) + ifString(result==LIMIT_ENTRY, ":open=0", ":close=0"))) return(false);
      }
   }
   return(true);
}


/**
 * Ob die angegebene LFX-Order ein Limit erreicht hat. Alle Preise werden gegen das Bid geprüft (LFX-Chart).
 *
 * @param  int       i           - Index der zu überprüfenden Order im globalen LFX_ORDER[]-Array
 * @param  datetime &triggerTime - Variable zur Aufnahme des Zeitpunktes eines bereits als getriggert markierten Limits
 *
 * @return int - Ergebnis, LIMIT_NONE:       wenn kein Limit erreicht wurde
 *                         LIMIT_ENTRY:      wenn ein Entry-Limit erreicht wurde
 *                         LIMIT_STOPLOSS:   wenn ein StopLoss-Limit erreicht wurde
 *                         LIMIT_TAKEPROFIT: wenn ein TakeProfit-Limit erreicht wurde
 *                         0:                wenn ein Fehler auftrat
 *
 * Ist ein Limit bereits als getriggert markiert, wird zusätzlich der Triggerzeitpunkt in der Variable triggerTime gespeichert.
 */
int IsLfxLimitTriggered(int i, datetime &triggerTime) {
   triggerTime = NULL;
   if (los.IsClosed(lfxOrders, i))
      return(LIMIT_NONE);

   double slPrice, slValue, tpPrice, tpValue, profit;

   int type = los.Type(lfxOrders, i);

   switch (type) {
      case OP_BUYLIMIT :
      case OP_BUYSTOP  :
      case OP_SELLLIMIT:
      case OP_SELLSTOP :
         if (los.IsOpenError(lfxOrders, i))            return(LIMIT_NONE);
         triggerTime = los.OpenTriggerTime(lfxOrders, i);
         if (triggerTime != 0)                         return(LIMIT_ENTRY);
         break;

      case OP_BUY :
      case OP_SELL:
         if (los.IsCloseError(lfxOrders, i))           return(LIMIT_NONE);
         triggerTime = los.CloseTriggerTime(lfxOrders, i);
         if (triggerTime != 0) {
            if (los.StopLossTriggered  (lfxOrders, i)) return(LIMIT_STOPLOSS  );
            if (los.TakeProfitTriggered(lfxOrders, i)) return(LIMIT_TAKEPROFIT);
            triggerTime = NULL;                        return(_NULL(catch("IsLfxLimitTriggered(1)   data constraint violation in #"+ los.Ticket(lfxOrders, i) +": closeTriggerTime="+ los.CloseTriggerTime(lfxOrders, i) +", slTriggered=0, tpTriggered=0", ERR_RUNTIME_ERROR)));
         }
         break;

      default:
         return(LIMIT_NONE);
   }

   switch (type) {
      case OP_BUYLIMIT:
      case OP_SELLSTOP:
         if (LE(Bid, los.OpenPriceLfx(lfxOrders, i))) return(LIMIT_ENTRY);
                                                      return(LIMIT_NONE );
      case OP_SELLLIMIT:
      case OP_BUYSTOP  :
         if (GE(Bid, los.OpenPriceLfx(lfxOrders, i))) return(LIMIT_ENTRY);
                                                      return(LIMIT_NONE );
      default:
         slPrice = los.StopLossLfx    (lfxOrders, i);
         slValue = los.StopLossValue  (lfxOrders, i);
         tpPrice = los.TakeProfitLfx  (lfxOrders, i);
         tpValue = los.TakeProfitValue(lfxOrders, i);
         profit  = lfxOrders.dvolatile[i][I_VPROFIT];
   }

   switch (type) {
      // Um Auslösefehler bei nicht initialisiertem P/L zu verhindern, wird dieser nur geprüft, wenn er ungleich 0.00 ist.
      case OP_BUY:
                                     if (slPrice != 0) if (LE(Bid,    slPrice)) return(LIMIT_STOPLOSS  );
         if (slValue != EMPTY_VALUE) if (profit  != 0) if (LE(profit, slValue)) return(LIMIT_STOPLOSS  );
                                     if (tpPrice != 0) if (GE(Bid,    tpPrice)) return(LIMIT_TAKEPROFIT);
         if (tpValue != EMPTY_VALUE) if (profit  != 0) if (GE(profit, tpValue)) return(LIMIT_TAKEPROFIT);
                                                                                return(LIMIT_NONE      );
      case OP_SELL:
                                     if (slPrice != 0) if (GE(Bid,    slPrice)) return(LIMIT_STOPLOSS  );
         if (slValue != EMPTY_VALUE) if (profit  != 0) if (LE(profit, slValue)) return(LIMIT_STOPLOSS  );
                                     if (tpPrice != 0) if (LE(Bid,    tpPrice)) return(LIMIT_TAKEPROFIT);
         if (tpValue != EMPTY_VALUE) if (profit  != 0) if (GE(profit, tpValue)) return(LIMIT_TAKEPROFIT);
                                                                                return(LIMIT_NONE      );
   }

   return(_NULL(catch("IsLfxLimitTriggered(2)   unreachable code reached", ERR_RUNTIME_ERROR)));
}


/**
 * Erzeugt die einzelnen ChartInfo-Label.
 *
 * @return bool - Erfolgsstatus
 */
bool CreateLabels() {
   // Label definieren
   label.instrument      = __NAME__ +"."+ label.instrument;
   label.ohlc            = __NAME__ +"."+ label.ohlc;
   label.price           = __NAME__ +"."+ label.price;
   label.spread          = __NAME__ +"."+ label.spread;
   label.aum             = __NAME__ +"."+ label.aum;
   label.position        = __NAME__ +"."+ label.position;
   label.unitSize        = __NAME__ +"."+ label.unitSize;
   label.externalAccount = __NAME__ +"."+ label.externalAccount;
   label.lfxTradeAccount = __NAME__ +"."+ label.lfxTradeAccount;
   label.time            = __NAME__ +"."+ label.time;
   label.stopoutLevel    = __NAME__ +"."+ label.stopoutLevel;

   int build = GetTerminalBuild();


   // Instrument-Label: Anzeige wird sofort und nur hier gesetzt
   if (build <= 509) {                                                                    // Builds größer 509 haben oben links eine {Symbol,Period}-Anzeige, die das
      if (ObjectFind(label.instrument) == 0)                                              // Label überlagert und sich nicht ohne weiteres ausblenden läßt.
         ObjectDelete(label.instrument);
      if (ObjectCreate(label.instrument, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label.instrument, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet    (label.instrument, OBJPROP_XDISTANCE, ifInt(build < 479, 4, 13));   // Builds größer 478 haben oben links einen Pfeil fürs One-Click-Trading,
         ObjectSet    (label.instrument, OBJPROP_YDISTANCE, ifInt(build < 479, 1,  3));   // das Instrument-Label wird dort entsprechend versetzt positioniert.
         ObjectRegister(label.instrument);
      }
      else GetLastError();
      string name = GetLongSymbolNameOrAlt(Symbol(), GetSymbolName(Symbol()));
      if      (StringIEndsWith(Symbol(), "_ask")) name = StringConcatenate(name, " (Ask)");
      else if (StringIEndsWith(Symbol(), "_avg")) name = StringConcatenate(name, " (Avg)");
      ObjectSetText(label.instrument, name, 9, "Tahoma Fett", Black);
   }


   // OHLC-Label
   if (ObjectFind(label.ohlc) == 0)
      ObjectDelete(label.ohlc);
   if (ObjectCreate(label.ohlc, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.ohlc, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label.ohlc, OBJPROP_XDISTANCE, 110);
      ObjectSet    (label.ohlc, OBJPROP_YDISTANCE, 4  );
      ObjectSetText(label.ohlc, " ", 1);
      ObjectRegister(label.ohlc);
   }
   else GetLastError();


   // Price-Label
   if (ObjectFind(label.price) == 0)
      ObjectDelete(label.price);
   if (ObjectCreate(label.price, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.price, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet    (label.price, OBJPROP_XDISTANCE, 14);
      ObjectSet    (label.price, OBJPROP_YDISTANCE, 15);
      ObjectSetText(label.price, " ", 1);
      ObjectRegister(label.price);
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
      ObjectRegister(label.spread);
   }
   else GetLastError();


   // Assets-under-Management-Label
   if (ObjectFind(label.aum) == 0)
      ObjectDelete(label.aum);
   if (ObjectCreate(label.aum, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.aum, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet    (label.aum, OBJPROP_XDISTANCE, 240);
      ObjectSet    (label.aum, OBJPROP_YDISTANCE,   9);
      ObjectSetText(label.aum, " ", 1);
      ObjectRegister(label.aum);
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
      ObjectRegister(label.position);
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
      ObjectRegister(label.unitSize);
   }
   else GetLastError();


   // External-Account-Label
   if (ObjectFind(label.externalAccount) == 0)
      ObjectDelete(label.externalAccount);
   if (ObjectCreate(label.externalAccount, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.externalAccount, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet    (label.externalAccount, OBJPROP_XDISTANCE, 6);
      ObjectSet    (label.externalAccount, OBJPROP_YDISTANCE, 8);
      ObjectSetText(label.externalAccount, " ", 1);
      ObjectRegister(label.externalAccount);
   }
   else GetLastError();


   // LFX-Trade-Account-Label
   if (ObjectFind(label.lfxTradeAccount) == 0)
      ObjectDelete(label.lfxTradeAccount);
   if (ObjectCreate(label.lfxTradeAccount, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.lfxTradeAccount, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet    (label.lfxTradeAccount, OBJPROP_XDISTANCE, 6);
      ObjectSet    (label.lfxTradeAccount, OBJPROP_YDISTANCE, 4);
      ObjectSetText(label.lfxTradeAccount, " ", 1);
      ObjectRegister(label.lfxTradeAccount);
   }
   else GetLastError();


   // Time-Label: nur im Tester bei VisualMode = ON
   if (IsVisualMode()) {
      if (ObjectFind(label.time) == 0)
         ObjectDelete(label.time);
      if (ObjectCreate(label.time, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label.time, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet    (label.time, OBJPROP_XDISTANCE,  9);
         ObjectSet    (label.time, OBJPROP_YDISTANCE, 49);
         ObjectSetText(label.time, " ", 1);
         ObjectRegister(label.time);
      }
      else GetLastError();
   }

   return(!catch("CreateLabels(1)"));
}


/**
 * Aktualisiert die Kursanzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdatePrice() {
   static string priceFormat;
   if (!StringLen(priceFormat))
      priceFormat = StringConcatenate(",,", PriceFormat);

   double price;

   if (!Bid) {                                                                // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
      price = Close[0];
   }
   else {
      switch (appliedPrice) {
         case PRICE_BID   : price =  Bid;          break;
         case PRICE_ASK   : price =  Ask;          break;
         case PRICE_MEDIAN: price = (Bid + Ask)/2; break;
      }
   }
   ObjectSetText(label.price, NumberToStr(price, priceFormat), 13, "Microsoft Sans Serif", Black);

   int error = GetLastError();
   if (!error)                             return(true);
   if (error == ERR_OBJECT_DOES_NOT_EXIST) return(true);                      // bei offenem Properties-Dialog oder Object::onDrag()

   return(!catch("UpdatePrice(2)", error));
}


/**
 * Aktualisiert die Spreadanzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateSpread() {
   if (!Bid)                                                                  // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
      return(true);

   string strSpread = DoubleToStr(MarketInfo(Symbol(), MODE_SPREAD)/PipPoints, Digits<<31>>31);

   ObjectSetText(label.spread, strSpread, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)           // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateSpread()", error));
   return(true);
}


/**
 * Aktualisiert die UnitSize-Anzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateUnitSize() {
   if (IsTesting())                                   return(true );          // Anzeige wird im Tester nicht benötigt
   if (!mm.done) /*&&*/ if (!UpdateMoneyManagement()) return(false);

   string strUnitSize = " ";

   // Anzeige wird nur mit internem Account benötigt
   if (mode.intern) {
      if (mm.isCustomLeverage) { double leverage=mm.customLeverage, lotsize=mm.customLots; }
      else                     {        leverage=mm.volaLeverage;   lotsize=mm.volaLots;   }

      // Lotsize runden
      if (lotsize > 0) {                                                                                    // Abstufung max. 6.7% je Schritt
         if      (lotsize <=    0.03) lotsize = NormalizeDouble(MathRound(lotsize/  0.001) *   0.001, 3);   //     0-0.03: Vielfaches von   0.001
         else if (lotsize <=   0.075) lotsize = NormalizeDouble(MathRound(lotsize/  0.002) *   0.002, 3);   // 0.03-0.075: Vielfaches von   0.002
         else if (lotsize <=    0.1 ) lotsize = NormalizeDouble(MathRound(lotsize/  0.005) *   0.005, 3);   //  0.075-0.1: Vielfaches von   0.005
         else if (lotsize <=    0.3 ) lotsize = NormalizeDouble(MathRound(lotsize/  0.01 ) *   0.01 , 2);   //    0.1-0.3: Vielfaches von   0.01
         else if (lotsize <=    0.75) lotsize = NormalizeDouble(MathRound(lotsize/  0.02 ) *   0.02 , 2);   //   0.3-0.75: Vielfaches von   0.02
         else if (lotsize <=    1.2 ) lotsize = NormalizeDouble(MathRound(lotsize/  0.05 ) *   0.05 , 2);   //   0.75-1.2: Vielfaches von   0.05
         else if (lotsize <=    3.  ) lotsize = NormalizeDouble(MathRound(lotsize/  0.1  ) *   0.1  , 1);   //      1.2-3: Vielfaches von   0.1
         else if (lotsize <=    7.5 ) lotsize = NormalizeDouble(MathRound(lotsize/  0.2  ) *   0.2  , 1);   //      3-7.5: Vielfaches von   0.2
         else if (lotsize <=   12.  ) lotsize = NormalizeDouble(MathRound(lotsize/  0.5  ) *   0.5  , 1);   //     7.5-12: Vielfaches von   0.5
         else if (lotsize <=   30.  ) lotsize =       MathRound(MathRound(lotsize/  1    ) *   1       );   //      12-30: Vielfaches von   1
         else if (lotsize <=   75.  ) lotsize =       MathRound(MathRound(lotsize/  2    ) *   2       );   //      30-75: Vielfaches von   2
         else if (lotsize <=  120.  ) lotsize =       MathRound(MathRound(lotsize/  5    ) *   5       );   //     75-120: Vielfaches von   5
         else if (lotsize <=  300.  ) lotsize =       MathRound(MathRound(lotsize/ 10    ) *  10       );   //    120-300: Vielfaches von  10
         else if (lotsize <=  750.  ) lotsize =       MathRound(MathRound(lotsize/ 20    ) *  20       );   //    300-750: Vielfaches von  20
         else if (lotsize <= 1200.  ) lotsize =       MathRound(MathRound(lotsize/ 50    ) *  50       );   //   750-1200: Vielfaches von  50
         else                         lotsize =       MathRound(MathRound(lotsize/100    ) * 100       );   //   1200-...: Vielfaches von 100

         // !!! max. 63 Zeichen           V - Volatilität/Woche                      L - Leverage                           Unitsize
         strUnitSize = StringConcatenate("V", DoubleToStr(mm.ATRwPct*100, 1), "%     L"+ DoubleToStr(leverage, 1) +"  =  ", NumberToStr(lotsize, ", .+"), " lot");
      }
   }

   // Anzeige aktualisieren
   ObjectSetText(label.unitSize, strUnitSize, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)              // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateUnitSize(1)", error));
   return(true);
}


/**
 * Aktualisiert die Positionsanzeigen: Gesamtposition unten rechts, Einzelpositionen unten links.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdatePositions() {
   if (!positionsAnalyzed) /*&&*/ if (!AnalyzePositions()     ) return(false);
   if (!mm.done          ) /*&&*/ if (!UpdateMoneyManagement()) return(false);


   // (1) Gesamtpositionsanzeige unten rechts
   string strCurrentVola, strCurrentLeverage, strPosition;
   if      (!isPosition   ) strPosition = " ";
   else if (!totalPosition) strPosition = StringConcatenate("Position:   ±", NumberToStr(longPosition, ", .+"), " lot (hedged)");
   else {
      // Leverage der aktuellen Position = MathAbs(totalPosition)/mm.unleveragedLots
      if (mm.unleveragedLots != 0) {
         double currentLeverage = MathAbs(totalPosition)/mm.unleveragedLots;
         strCurrentLeverage = StringConcatenate("L", DoubleToStr(currentLeverage, 1), "      ");

         // Volatilität/Woche der aktuellen Position = aktueller Leverage * ATRwPct
         if (mm.ATRwPct != 0)
            strCurrentVola = StringConcatenate("V", DoubleToStr(mm.ATRwPct * 100 * currentLeverage, 1), "%      ");
      }
      strPosition = StringConcatenate("Position:   " , strCurrentVola, strCurrentLeverage, NumberToStr(totalPosition, "+, .+"), " lot");
   }
   ObjectSetText(label.position, strPosition, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdatePositions(1)", error));


   // (2) Einzelpositionsanzeige unten links
   // Spalten:          Direction:, LotSize, BE:, BePrice, Profit:, ProfitAmount, ProfitPercent, Comment
   int col.xShifts[] = {20,         59,      135, 160,     231,     263,          366,           411}, cols=ArraySize(col.xShifts), yDist=3;
   int iePositions   = ArrayRange(positions.idata, 0);
   int positions     = iePositions + lfxOrders.openPositions;        // nur einer der beiden Werte kann ungleich 0 sein

   // (2.1) zusätzlich benötigte Zeilen hinzufügen
   static int lines;
   while (lines < positions) {
      lines++;
      for (int col=0; col < cols; col++) {
         string label = label.position +".line"+ lines +"_col"+ col;
         if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
            ObjectSet    (label, OBJPROP_CORNER, CORNER_BOTTOM_LEFT);
            ObjectSet    (label, OBJPROP_XDISTANCE, col.xShifts[col]              );
            ObjectSet    (label, OBJPROP_YDISTANCE, yDist + (lines-1)*(positions.fontSize+8));
            ObjectSetText(label, " ", 1);
            ObjectRegister(label);
         }
         else GetLastError();
      }
   }
   // (2.2) nicht benötigte Zeilen löschen
   while (lines > positions) {
      for (col=0; col < cols; col++) {
         label = label.position +".line"+ lines +"_col"+ col;
         if (ObjectFind(label) != -1)
            ObjectDelete(label);
      }
      lines--;
   }

   // (2.3) Zeilen von unten nach oben schreiben: "{Type}: {LotSize}   BE|Dist: {BePrice}   Profit: {ProfitAmount}   {ProfitPercent}   {Comment}"
   string strLotSize, strCustomAmount, strProfitPct, strComment, strTypes[]={"", "Long:", "Short:", "Hedge:"};   // DirectionTypes (1, 2, 3) werden als Indizes benutzt
   color  fontColor;
   int    line;

   // interne/externe Positionsdaten
   for (int i=iePositions-1; i >= 0; i--) {
      line++;
      if (positions.idata[i][I_POSITION_TYPE] == TYPE_VIRTUAL) fontColor = positions.fontColor.virtual;
      else if (mode.intern)                                    fontColor = positions.fontColor.intern;
      else                                                     fontColor = positions.fontColor.extern;

      if (positions.idata[i][I_DIRECTION_TYPE] == TYPE_HEDGE) {
         // Hedged
         ObjectSetText(label.position +".line"+ line +"_col0",    strTypes[positions.idata[i][I_DIRECTION_TYPE]],                                                    positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(label.position +".line"+ line +"_col1", NumberToStr(positions.ddata[i][I_HEDGED_LOTSIZE], ".+") +" lot",                                      positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(label.position +".line"+ line +"_col2", "Dist:",                                                                                              positions.fontSize, positions.fontName, fontColor);
            if (!positions.ddata[i][I_BREAKEVEN])
         ObjectSetText(label.position +".line"+ line +"_col3", "...",                                                                                                positions.fontSize, positions.fontName, fontColor);
            else
         ObjectSetText(label.position +".line"+ line +"_col3", DoubleToStr(RoundFloor(positions.ddata[i][I_BREAKEVEN], Digits-PipDigits), Digits-PipDigits) +" pip", positions.fontSize, positions.fontName, fontColor);
      }
      else {
         // Not Hedged
         ObjectSetText(label.position +".line"+ line +"_col0",         strTypes[positions.idata[i][I_DIRECTION_TYPE]],                                               positions.fontSize, positions.fontName, fontColor);
            if (!positions.ddata[i][I_HEDGED_LOTSIZE]) strLotSize = NumberToStr(positions.ddata[i][I_DIRECT_LOTSIZE], ".+");
            else                                       strLotSize = NumberToStr(positions.ddata[i][I_DIRECT_LOTSIZE], ".+") +" ±"+ NumberToStr(positions.ddata[i][I_HEDGED_LOTSIZE], ".+");
         ObjectSetText(label.position +".line"+ line +"_col1", strLotSize +" lot",                                                                                   positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(label.position +".line"+ line +"_col2", "BE:",                                                                                                positions.fontSize, positions.fontName, fontColor);
            if (!positions.ddata[i][I_BREAKEVEN])
         ObjectSetText(label.position +".line"+ line +"_col3", "...",                                                                                                positions.fontSize, positions.fontName, fontColor);
            else if (positions.idata[i][I_DIRECTION_TYPE] == TYPE_LONG)
         ObjectSetText(label.position +".line"+ line +"_col3", NumberToStr(RoundCeil (positions.ddata[i][I_BREAKEVEN], Digits), PriceFormat),                        positions.fontSize, positions.fontName, fontColor);
            else
         ObjectSetText(label.position +".line"+ line +"_col3", NumberToStr(RoundFloor(positions.ddata[i][I_BREAKEVEN], Digits), PriceFormat),                        positions.fontSize, positions.fontName, fontColor);
      }
         // Hedged und Not-Hedged
         ObjectSetText(label.position +".line"+ line +"_col4", "Profit:",                                                                                            positions.fontSize, positions.fontName, fontColor);
            if (!positions.ddata[i][I_CUSTOM_AMOUNT]) strCustomAmount = "";
            else                                      strCustomAmount = " ("+ DoubleToStr(positions.ddata[i][I_CUSTOM_AMOUNT], 2) +")";
         ObjectSetText(label.position +".line"+ line +"_col5", DoubleToStr(positions.ddata[i][I_PROFIT], 2) + strCustomAmount,                                       positions.fontSize, positions.fontName, fontColor);
            if (!positions.ddata[i][I_OPEN_EQUITY])   strProfitPct = "";
            else                                      strProfitPct = DoubleToStr(positions.ddata[i][I_PROFIT_PERCENT], 1) +"%";
         ObjectSetText(label.position +".line"+ line +"_col6", strProfitPct,                                                                                         positions.fontSize, positions.fontName, fontColor);
            if (positions.idata[i][I_COMMENT] == -1)  strComment = "";
            else                                      strComment = custom.position.conf.comments[positions.idata[i][I_COMMENT]];
         ObjectSetText(label.position +".line"+ line +"_col7", strComment +" ",                                                                                      positions.fontSize, positions.fontName, fontColor);
   }

   // LFX-Positionsdaten
   for (i=ArrayRange(lfxOrders, 0)-1; i >= 0; i--) {
      if (lfxOrders.ivolatile[i][I_ISOPEN] != 0) {
         line++;
         if (positions.idata[i][I_POSITION_TYPE] == TYPE_VIRTUAL) fontColor = positions.fontColor.virtual;
         else                                                     fontColor = positions.fontColor.remote;
         ObjectSetText(label.position +".line"+ line +"_col0",    strTypes[los.Type        (lfxOrders, i)+1],                  positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(label.position +".line"+ line +"_col1", NumberToStr(los.Units       (lfxOrders, i), ".+") +" units",    positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(label.position +".line"+ line +"_col2", "BE:",                                                          positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(label.position +".line"+ line +"_col3", NumberToStr(los.OpenPriceLfx(lfxOrders, i), SubPipPriceFormat), positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(label.position +".line"+ line +"_col4", "SL:",                                                          positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(label.position +".line"+ line +"_col5", NumberToStr(los.StopLossLfx(lfxOrders, i), SubPipPriceFormat),  positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(label.position +".line"+ line +"_col6", "Profit:",                                                      positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(label.position +".line"+ line +"_col7", DoubleToStr(lfxOrders.dvolatile[i][I_VPROFIT], 2),              positions.fontSize, positions.fontName, fontColor);
      }
   }
   return(!catch("UpdatePositions(2)"));
}


/**
 * Aktualisiert die Anzeige eines externen Accounts.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateExternalAccount() {
   if (!mode.extern) {
      ObjectSetText(label.externalAccount, " ", 1);
   }
   else {
      ObjectSetText(label.unitSize, " ", 1);
      ObjectSetText(label.externalAccount, external.name, 8, "Arial Fett", Red);
   }

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)           // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateExternalAccount(1)", error));
   return(true);
}


/**
 * Aktualisiert die Anzeige des aktuellen Stopout-Levels.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateStopoutLevel() {
   if (!positionsAnalyzed) /*&&*/ if (!AnalyzePositions())
      return(false);

   if (!mode.intern || !totalPosition) {                                               // keine effektive Position im Markt: vorhandene Marker löschen
      ObjectDelete(label.stopoutLevel);
      int error = GetLastError();
      if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)                 // bei offenem Properties-Dialog oder Object::onDrag()
         return(!catch("UpdateStopoutLevel(1)", error));
      return(true);
   }


   // (1) Stopout-Preis berechnen
   double equity     = AccountEquity();
   double usedMargin = AccountMargin();
   int    soMode     = AccountStopoutMode();
   double soEquity   = AccountStopoutLevel(); if (soMode != ASM_ABSOLUTE) soEquity /= (100/usedMargin);
   double tickSize   = MarketInfo(Symbol(), MODE_TICKSIZE );
   double tickValue  = MarketInfo(Symbol(), MODE_TICKVALUE) * MathAbs(totalPosition);  // TickValue der aktuellen Position
      if (!tickSize || !tickValue)
         return(!SetLastError(ERR_UNKNOWN_SYMBOL));                                    // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
   double soDistance = (equity - soEquity)/tickValue * tickSize;
   double soPrice;
   if (totalPosition > 0) soPrice = NormalizeDouble(Bid - soDistance, Digits);
   else                   soPrice = NormalizeDouble(Ask + soDistance, Digits);


   // (2) Stopout-Preis anzeigen
   if (ObjectFind(label.stopoutLevel) == -1) {
      ObjectCreate (label.stopoutLevel, OBJ_HLINE, 0, 0, 0);
      ObjectSet    (label.stopoutLevel, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet    (label.stopoutLevel, OBJPROP_COLOR, OrangeRed  );
      ObjectSet    (label.stopoutLevel, OBJPROP_BACK , true       );
         if (soMode == ASM_PERCENT) string description = StringConcatenate("Stopout  ", Round(AccountStopoutLevel()), "%");
         else                              description = StringConcatenate("Stopout  ", DoubleToStr(soEquity, 2), AccountCurrency());
      ObjectSetText(label.stopoutLevel, description);
      ObjectRegister(label.stopoutLevel);
   }
   ObjectSet(label.stopoutLevel, OBJPROP_PRICE1, soPrice);


   error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)                    // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateStopoutLevel(2)", error));
   return(true);
}


/**
 * Aktualisiert die OHLC-Anzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateOHLC() {
   // TODO: noch nicht zufriedenstellend implementiert
   return(true);


   // (1) Zeit des letzten Ticks holen
   datetime lastTickTime = MarketInfo(Symbol(), MODE_TIME);
   if (!lastTickTime) {                                                          // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
      if (!SetLastError(GetLastError()))
         SetLastError(ERR_UNKNOWN_SYMBOL);
      return(false);
   }


   // (2) Beginn und Ende der aktuellen Session ermitteln
   datetime sessionStart = GetSessionStartTime.srv(lastTickTime);                // throws ERR_MARKET_CLOSED
   if (sessionStart == NaT) {
      if (SetLastError(stdlib.GetLastError()) != ERR_MARKET_CLOSED)              // am Wochenende die letzte Session verwenden
         return(false);
      sessionStart = GetPrevSessionStartTime.srv(lastTickTime);
   }
   datetime sessionEnd = sessionStart + 1*DAY;


   // (3) Baroffsets von Sessionbeginn und -ende ermitteln
   int openBar = iBarShiftNext(NULL, NULL, sessionStart);
      if (openBar == EMPTY_VALUE) return(!SetLastError(stdlib.GetLastError()));  // Fehler
      if (openBar ==          -1) return(true);                                  // sessionStart ist zu jung für den Chart
   int closeBar = iBarShiftPrevious(NULL, NULL, sessionEnd);
      if (closeBar == EMPTY_VALUE) return(!SetLastError(stdlib.GetLastError())); // Fehler
      if (closeBar ==          -1) return(true);                                 // sessionEnd ist zu alt für den Chart
   if (openBar < closeBar)
      return(!catch("UpdateOHLC(1)   illegal open/close bar offsets for session from="+ DateToStr(sessionStart, "w D.M.Y H:I") +" (bar="+ openBar +")  to="+ DateToStr(sessionEnd, "w D.M.Y H:I") +" (bar="+ closeBar +")", ERR_RUNTIME_ERROR));


   // (4) Baroffsets von Session-High und -Low ermitteln
   int highBar = iHighest(NULL, NULL, MODE_HIGH, openBar-closeBar+1, closeBar);
   int lowBar  = iLowest (NULL, NULL, MODE_LOW , openBar-closeBar+1, closeBar);


   // (5) Anzeige aktualisieren
   string strOHLC = "O="+ NumberToStr(Open[openBar], PriceFormat) +"   H="+ NumberToStr(High[highBar], PriceFormat) +"   L="+ NumberToStr(Low[lowBar], PriceFormat);
   ObjectSetText(label.ohlc, strOHLC, 8, "", Black);


   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)              // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateOHLC(2)", error));
   return(true);
}


/**
 * Aktualisiert die Zeitanzeige (nur im Tester bei VisualMode = On).
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateTime() {
   if (!IsVisualMode())
      return(true);

   static datetime lastTime;

   datetime now = TimeCurrent();
   if (now == lastTime)
      return(true);

   string date = TimeToStr(now, TIME_DATE),
          yyyy = StringSubstr(date, 0, 4),
          mm   = StringSubstr(date, 5, 2),
          dd   = StringSubstr(date, 8, 2),
          time = TimeToStr(now, TIME_MINUTES|TIME_SECONDS);

   ObjectSetText(label.time, StringConcatenate(dd, ".", mm, ".", yyyy, " ", time), 9, "Tahoma", SlateGray);

   lastTime = now;

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)     // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateTime()", error));
   return(true);
}


/**
 * Ermittelt die aktuelle Positionierung, gruppiert sie je nach individueller Konfiguration und berechnet deren Kennziffern.
 *
 * @return bool - Erfolgsstatus
 */
bool AnalyzePositions() {
   if (mode.remote      ) positionsAnalyzed = true;
   if (positionsAnalyzed) return(true);

   int    tickets    [], openPositions;                                 // Positionsdetails
   int    types      [];
   double lots       [];
   double openPrices [];
   double commissions[];
   double swaps      [];
   double profits    [];


   // (1) Gesamtposition ermitteln
   longPosition  = 0;
   shortPosition = 0;

   // (1.1) mode.intern
   if (mode.intern) {
      int orders = OrdersTotal();
      int sortKeys[][2];                                                // Sortierschlüssel der offenen Positionen: {OpenTime, Ticket}
      ArrayResize(sortKeys, orders);

      int pos, lfxMagics []={0}; ArrayResize(lfxMagics , 1);            // Die Arrays für die P/L-Daten detektierter LFX-Positionen werden mit Größe 1 initialisiert.
      double   lfxProfits[]={0}; ArrayResize(lfxProfits, 1);            // So sparen wir in Zeile (1.1.1) den ständigen Test auf ein leeres Array.

      // Sortierschlüssel auslesen und dabei P/L's sämtlicher LFX-Positionen verarbeiten (alle Symbole, Update bei jedem Tick)
      for (int n, i=0; i < orders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;        // FALSE: während des Auslesens wurde woanders ein offenes Ticket entfernt
         if (OrderType() > OP_SELL) continue;
         if (LFX.IsMyOrder()) {                                         // nebenbei P/L gefundener LFX-Positionen aufaddieren
            if (OrderMagicNumber() != lfxMagics[pos]) {                 // Zeile (1.1.1): Quickcheck mit dem letzten verwendeten Index, erst dann Suche (schnellste Variante)
               pos = SearchMagicNumber(lfxMagics, OrderMagicNumber());
               if (pos == -1)
                  pos = ArrayResize(lfxProfits, ArrayPushInt(lfxMagics, OrderMagicNumber()))-1;
            }
            lfxProfits[pos] += OrderCommission() + OrderSwap() + OrderProfit();
         }
         if (OrderSymbol() != Symbol()) continue;
         if (OrderType() == OP_BUY) longPosition  += OrderLots();       // Gesamtposition je Richtung aufaddieren
         else                       shortPosition += OrderLots();

         sortKeys[n][0] = OrderOpenTime();                              // Sortierschlüssel der Tickets auslesen
         sortKeys[n][1] = OrderTicket();
         n++;
      }
      if (pos != 0) LFX.ProcessProfits(lfxMagics, lfxProfits);          // P/L's gefundener LFX-Positionen verarbeiten
      if (n < orders)
         ArrayResize(sortKeys, n);
      openPositions = n;

      // (1.1.2) offene Positionen sortieren und einlesen
      if (openPositions > 1) /*&&*/ if (!SortOpenTickets(sortKeys))
         return(false);

      ArrayResize(tickets    , openPositions);                          // interne Positionsdetails werden bei jedem Tick zurückgesetzt
      ArrayResize(types      , openPositions);
      ArrayResize(lots       , openPositions);
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
         openPrices [i] = OrderOpenPrice();
         commissions[i] = OrderCommission();
         swaps      [i] = OrderSwap();
         profits    [i] = OrderProfit();
      }
   }

   // (1.2) mode.extern
   if (mode.extern) {
      openPositions = ArraySize(external.open.ticket);

      // offene Positionen werden nicht bei jedem Tick, sondern nur in init() oder nach entsprechendem Event neu eingelesen
      if (!external.open.lots.checked) {
         external.open.longPosition  = 0;
         external.open.shortPosition = 0;
         for (i=0; i < openPositions; i++) {                            // Gesamtposition je Richtung aufaddieren
            if (external.open.type[i] == OP_BUY) external.open.longPosition  += external.open.lots[i];
            else                                 external.open.shortPosition += external.open.lots[i];
         }
         external.open.lots.checked = true;
      }
      longPosition  = external.open.longPosition;
      shortPosition = external.open.shortPosition;

      if (openPositions > 0) {
         ArrayCopy(tickets    , external.open.ticket    );              // ExtractPosition() modifiziert die übergebenen Arrays, also Kopie der Originaldaten erstellen
         ArrayCopy(types      , external.open.type      );
         ArrayCopy(lots       , external.open.lots      );
         ArrayCopy(openPrices , external.open.openPrice );
         ArrayCopy(commissions, external.open.commission);
         ArrayCopy(swaps      , external.open.swap      );
         ArrayCopy(profits    , external.open.profit    );

         for (i=0; i < openPositions; i++) {
            profits[i] = ifDouble(types[i]==OP_LONG, Bid-openPrices[i], openPrices[i]-Ask)/Pips * PipValue(lots[i], true); // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         }
      }
   }

   // (1.3) Ergebnisse intern + extern
   longPosition  = NormalizeDouble(longPosition,  2);
   shortPosition = NormalizeDouble(shortPosition, 2);
   totalPosition = NormalizeDouble(longPosition - shortPosition, 2);
   isPosition    = longPosition || shortPosition;


   // (2) Positionen analysieren und in positions.~data[] speichern
   if (ArrayRange(positions.idata, 0) > 0) {
      ArrayResize(positions.idata, 0);
      ArrayResize(positions.ddata, 0);
   }

   // (2.1) individuelle Konfiguration parsen
   if (ArrayRange(custom.position.conf, 0)==0) /*&&*/ if (!ReadCustomPositionConfig()) {
      positionsAnalyzed = !last_error;                                  // MarketInfo()-Daten stehen ggf. noch nicht zur Verfügung,
      return(positionsAnalyzed);                                        // in diesem Fall nächster Versuch beim nächsten Tick.
   }
   int    type, confLine;
   double size, value, customLongPosition, customShortPosition, customTotalPosition, customAmount, customEquity, _longPosition=longPosition, _shortPosition=shortPosition, _totalPosition=totalPosition;
   bool   isVirtual;
   int    customTickets    [];
   int    customTypes      [];
   double customLots       [];
   double customOpenPrices [];
   double customCommissions[];
   double customSwaps      [];
   double customProfits    [];

   // (2.2) individuelle Positionen aus den offenen Positionen extrahieren
   int confSize = ArrayRange(custom.position.conf, 0);

   for (i=0, confLine=0; i < confSize; i++) {
      size  = custom.position.conf[i][0];
      type  = custom.position.conf[i][1];
      value = custom.position.conf[i][2];

      if (!type) {                                                      // type==NULL => "Zeilenende"
         // (2.3) individuelle Position speichern (zusammengefaßt: Long+Short+Hedged)
         if (ArraySize(customTickets) > 0)
            if (!StoreCustomPosition(isVirtual, customLongPosition, customShortPosition, customTotalPosition, customAmount, customEquity, confLine, customTickets, customTypes, customLots, customOpenPrices, customCommissions, customSwaps, customProfits))
               return(false);
         isVirtual           = false;
         customLongPosition  = 0;
         customShortPosition = 0;
         customTotalPosition = 0;
         customAmount        = 0;
         customEquity        = 0;
         ArrayResize(customTickets    , 0);
         ArrayResize(customTypes      , 0);
         ArrayResize(customLots       , 0);
         ArrayResize(customOpenPrices , 0);
         ArrayResize(customCommissions, 0);
         ArrayResize(customSwaps      , 0);
         ArrayResize(customProfits    , 0);
         confLine++;
         continue;
      }
      if (!ExtractPosition(size, type, value, _longPosition,      _shortPosition,      _totalPosition,                                  tickets,       types,       lots,       openPrices,       commissions,       swaps,       profits,
                           isVirtual,         customLongPosition, customShortPosition, customTotalPosition, customAmount, customEquity, customTickets, customTypes, customLots, customOpenPrices, customCommissions, customSwaps, customProfits))
         return(false);
   }

   // (2.4) reguläre (Rest-)Positionen speichern (einzeln: Long, Short, Hedged)
   if (!StoreRegularPositions(_longPosition, _shortPosition, _totalPosition, tickets, types, lots, openPrices, commissions, swaps, profits))
      return(false);

   positionsAnalyzed = true;
   return(!catch("AnalyzePositions(2)"));
}


/**
 * Aktualisiert die dynamischen Werte des Money-Managements.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateMoneyManagement() {
   if (mm.done    ) return(true);
   if (mode.remote) return(_false(debug("UpdateMoneyManagement(1)   feature not implemented for mode.remote=1")));
 //if (mode.remote) return(!catch("UpdateMoneyManagement(1)   feature not implemented for mode.remote=1", ERR_NOT_IMPLEMENTED));

   mm.unleveragedLots = 0;                                                                   // Lotsize bei Hebel 1:1
   mm.ATRwAbs         = 0;                                                                   // wöchentliche ATR, absolut
   mm.ATRwPct         = 0;                                                                   // wöchentliche ATR, prozentual
   mm.volaLots        = 0;                                                                   // Lotsize für wöchentliche Volatilität einer Unit von {mm.stdRisk} Prozent
   mm.volaLeverage    = 0;                                                                   // resultierender Hebel bei wöchentlicher Volatilität
   mm.customLots      = 0;                                                                   // Lotsize bei benutzerdefiniertem Hebel


   // (1) unleveraged Lots
   double tickSize       = MarketInfo(Symbol(), MODE_TICKSIZE      );
   double tickValue      = MarketInfo(Symbol(), MODE_TICKVALUE     );
   double marginRequired = MarketInfo(Symbol(), MODE_MARGINREQUIRED); if (marginRequired == -92233720368547760.) marginRequired = 0;
      int error = GetLastError();
      if (IsError(error)) {
         if (error == ERR_UNKNOWN_SYMBOL) return(false);
         return(!catch("UpdateMoneyManagement(2)", error));
      }
   double equity = GetExternalAssets();
   if (mode.intern)
      equity += MathMin(AccountBalance(), AccountEquity()-AccountCredit());
   //debug("UpdateMoneyManagement()   equity="+ DoubleToStr(equity, 2));

   if (!Close[0] || !tickSize || !tickValue || !marginRequired || equity <= 0)               // bei Start oder Accountwechsel können einige Werte noch ungesetzt sein
      return(false);

   double lotValue    = Close[0]/tickSize * tickValue;                                       // Value eines Lots in Account-Currency
   mm.unleveragedLots = equity/lotValue;                                                     // ungehebelte Lotsize (Leverage 1:1)


   // (2) Expected TrueRange als Maximalwert von ATR und den letzten beiden Einzelwerten: ATR, TR[1] und TR[0]
   double a = ixATR(NULL, PERIOD_W1, 14, 1); if (a == EMPTY)                return(false);   // ATR(14xW)
      if (last_error == ERS_HISTORY_UPDATE) /*&&*/ if (Period()!=PERIOD_W1) SetLastError(NO_ERROR);//throws ERS_HISTORY_UPDATE (wenn, dann nur einmal)
   double b = ixATR(NULL, PERIOD_W1,  1, 1); if (b == EMPTY)                return(false);   // TrueRange letzte Woche
   double c = ixATR(NULL, PERIOD_W1,  1, 0); if (c == EMPTY)                return(false);   // TrueRange aktuelle Woche
   mm.ATRwAbs = MathMax(a, MathMax(b, c));
      double C = iClose(NULL, PERIOD_W1, 1);
      double H = iHigh (NULL, PERIOD_W1, 0);
      double L = iLow  (NULL, PERIOD_W1, 0);
   mm.ATRwPct = mm.ATRwAbs/((MathMax(C, H) + MathMax(C, L))/2);                              // median price

   if (mm.isCustomLeverage) {
      // (3) customLots
      mm.customLots = mm.unleveragedLots * mm.customLeverage;                                // mit benutzerdefiniertem Hebel gehebelte Lotsize
   }
   else {
      // (4) volaLots
      if (!mm.ATRwPct)
         return(false);
      mm.volaLeverage = mm.vola/(mm.ATRwPct*100);
      mm.volaLots     = mm.unleveragedLots * mm.volaLeverage;                                // auf wöchentliche Volatilität gehebelte Lotsize
   }


   mm.done = true;
   return(!catch("UpdateMoneyManagement(3)"));
}


/**
 * Durchsucht das übergebene Integer-Array nach der angegebenen MagicNumber. Schnellerer Ersatz für SearchIntArray(int haystack[], int needle),
 * da kein Library-Aufruf.
 *
 * @param  int array[] - zu durchsuchendes Array
 * @param  int number  - zu suchende MagicNumber
 *
 * @return int - Index der MagicNumber oder -1, wenn der Wert nicht im Array enthalten ist
 */
int SearchMagicNumber(int array[], int number) {
   int size = ArraySize(array);
   for (int i=0; i < size; i++) {
      if (array[i] == number)
         return(i);
   }
   return(-1);
}


/**
 * Liest die individuell konfigurierten Positionsdaten neu ein.
 *
 * @return bool - Erfolgsstatus
 *
 *
 * Füllt das Array custom.position.conf[][3] mit den Konfigurationsdaten des aktuellen Instruments. Das Array enthält Elemente im Format
 * {Size, Type, Value}.  Ein NULL-Type-Element {*, NULL, *} markiert ein Zeilenende bzw. eine leere Konfiguration. Nach einer eingelesenen
 * Konfiguration ist die Größe des Arrays immer != 0.
 * Zeilenkommentare werden in custom.position.conf.comments[] gespeichert.
 *
 *
 *  Notation:                                                                                      Arraydarstellung:                   Konstanten:
 *  ---------                                                                                      -----------------                   -----------
 *   0.1#123456               - O.1 Lot eines Tickets (1)                                          {  0.1, 123456     , NULL  }        EMPTY:        -1
 *      #123456               - komplettes Ticket oder verbleibender Rest eines Tickets            {EMPTY, 123456     , NULL  }        NULL:          0
 *   0.2L                     - mit Lotsize: virtuelle Long-Position zum aktuellen Preis (2)       {  0.2, TYPE_LONG  , NULL  }        TYPE_LONG:     1
 *   0.3S1.2345               - mit Lotsize: virtuelle Short-Position zum angegebenen Preis (2)    {  0.3, TYPE_SHORT , 1.2345}        TYPE_SHORT:    2
 *      L                     - ohne Lotsize: alle verbleibenden Long-Positionen                   {EMPTY, TYPE_LONG  , NULL  }        TYPE_EQUITY:   4
 *      S                     - ohne Lotsize: alle verbleibenden Short-Positionen                  {EMPTY, TYPE_SHORT , NULL  }        TYPE_AMOUNT:   5
 *   EQ{123.00}{[+-/*]456.00} - für Equityberechnungen zu verwendender Wert (3)                    {NULL , TYPE_EQUITY, 123.00}
 *   12.34                    - dem P/L einer Position zuzuschlagender Betrag                      {NULL , TYPE_AMOUNT, 12.34 }
 *
 *   Kommentare (alles nach ";")                    - werden als Beschreibung angezeigt
 *   Kommentare in Kommentaren (alles nach ";...;") - werden ignoriert
 *
 * ! - noch nicht implementiert
 *
 *
 *  Beispiel:
 *  ---------
 *   [BreakevenCalculation]
 *   GBPAUD.1 = #111111, 0.1#222222      ;; komplettes Ticket #111111 und 0.1 Lot von Ticket #222222
 *   GBPAUD.2 = 0.2#L, #222222           ;; virtuelle 0.2 Lot Long-Position und Rest von #222222 (2)
 *   GBPAUD.3 = L,S,-34.56               ;; alle verbleibenden Positionen, inkl. eines Restes von #222222, zzgl. eines P/L's von -34.45
 *   GBPAUD.3 = 0.5L                     ;; Zeile wird ignoriert, da der Schlüssel "GBPAUD.3" bereits verarbeitet wurde
 *   GBPAUD.0 = 0.3S                     ;; virtuelle 0.3 Lot Short-Position, wird als letzte angezeigt (4)
 *
 *
 *  Resultierendes Array:
 *  ---------------------
 *  custom.position.conf = {{EMPTY, 111111,     NULL}, {  0.1, 222222,     NULL},                              {*, NULL, *},
 *                          {  0.2, TYPE_LONG,  NULL}, {EMPTY, 222222,     NULL},                              {*, NULL, *},
 *                          {EMPTY, TYPE_LONG,  NULL}, {EMPTY, TYPE_SHORT, NULL}, {NULL, TYPE_AMOUNT, -34.45}, {*, NULL, *},
 *                          {  0.3, TYPE_SHORT, NULL},                                                         {*, NULL, *}
 *                         }
 *
 *  (1) Bei einer Lotsize von 0 wird die entsprechende Teilposition der individuellen Position ignoriert.
 *  (2) Reale Positionen, die mit virtuellen Positionen kombiniert werden, werden nicht von der verbleibenden Gesamtposition abgezogen.
 *      Dies kann in Verbindung mit (1) benutzt werden, um auf die Schnelle eine virtuelle Position zu konfigurieren, die keinen Einfluß
 *      auf später folgende Positionen hat (z.B. durch "0L" innerhalb einer Konfigurationszeile).
 *  (3) Der Equitywert kann aus einer Formel in der Form "value_A operator value_B" bestehen.
 *  (4) Die konfigurierten Positionen werden unsortiert verarbeitet und nicht nach Schlüssel sortiert.
 */
bool ReadCustomPositionConfig() {
   if (ArrayRange(custom.position.conf, 0) > 0) {
      ArrayResize(custom.position.conf,          0);
      ArrayResize(custom.position.conf.comments, 0);
   }

   string keys[], values[], value, comment, strSize, strTicket, strPrice, sNull, symbol=Symbol(), stdSymbol=StdSymbol();
   double confSizeValue, confTypeValue, confValue, lotSize, minLotSize=MarketInfo(Symbol(), MODE_MINLOT), lotStep=MarketInfo(Symbol(), MODE_LOTSTEP);
   int    valuesSize, confSize, pos, ticket, offsetStartOfPosition=0;
   bool   isConfigEmpty, isConfigVirtual;
   if (!minLotSize) return(false);                                         // falls MarketInfo()-Daten noch nicht verfügbar sind
   if (!lotStep   ) return(false);

   if (mode.remote) return(!catch("ReadCustomPositionConfig(1)   feature for mode.remote=1 not yet implemented", ERR_NOT_IMPLEMENTED));

   string mqlDir   = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string file     = TerminalPath() + mqlDir +"\\files\\"+ ifString(mode.intern, ShortAccountCompany() +"\\"+ GetAccountNumber(), external.provider +"\\"+ external.signal) +"_config.ini";
   string section  = "BreakevenCalculation";
   int    keysSize = GetIniKeys(file, section, keys);

   for (int i=0; i < keysSize; i++) {
      if (StringIStartsWith(keys[i], symbol) || StringIStartsWith(keys[i], stdSymbol)) {
         if (SearchStringArrayI(keys, keys[i]) == i) {                     // bei gleichnamigen Schlüsseln wird nur der erste verarbeitet
            value = GetRawIniString(file, section, keys[i], "");

            // Konfigurationskommentar auswerten
            pos = StringFind(value, ";");
            if (pos >= 0) {
               comment = StringSubstr(value, pos+1);
               value   = StringTrimRight(StringSubstrFix(value, 0, pos));
               pos = StringFind(comment, ";");
               if (pos == -1) comment = StringTrimLeft(comment);
               else           comment = StringTrim(StringLeft(comment, pos));
            }
            else comment = "";

            // Konfigurationsdaten auswerten
            isConfigEmpty   = true;                                        // ob der Parser für diese Zeile bereits gültige Konfigurationsdaten erkannt hat oder nicht
            isConfigVirtual = false;                                       // ob diese Zeile virtuelle Konfigurationsdaten enthält oder nicht^
            valuesSize      = Explode(StringToUpper(value), ",", values, NULL);

            for (int n=0; n < valuesSize; n++) {
               values[n] = StringTrim(values[n]);
               if (!StringLen(values[n]))                                  // Leervalue
                  continue;

               if (StringStartsWith(values[n], "#")) {                     // Ticket bzw. verbleibender Rest eines Tickets
                  strTicket = StringTrimLeft(StringRight(values[n], -1));
                  if (!StringIsDigit(strTicket))                      return(!catch("ReadCustomPositionConfig(2)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (non-digits in ticket \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confSizeValue = EMPTY;
                  confTypeValue = StrToInteger(strTicket);
                  confValue     = NULL;
               }

               else if (StringStartsWith(values[n], "L")) {                // alle verbleibenden Long-Positionen
                  if (values[n] != "L")                               return(!catch("ReadCustomPositionConfig(3)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confSizeValue = EMPTY;
                  confTypeValue = TYPE_LONG;
                  confValue     = NULL;
               }

               else if (StringStartsWith(values[n], "S")) {                // alle verbleibenden Short-Positionen
                  if (values[n] != "S")                               return(!catch("ReadCustomPositionConfig(4)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confSizeValue = EMPTY;
                  confTypeValue = TYPE_SHORT;
                  confValue     = NULL;
               }

               else if (StringStartsWith(values[n], "EQ")) {               // Equity
                  strSize = StringTrimLeft(StringRight(values[n], -2));
                  if (!StringIsNumeric(strSize))                      return(!catch("ReadCustomPositionConfig(5)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (non-numeric equity \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confSizeValue = NULL;
                  confTypeValue = TYPE_EQUITY;
                  confValue     = StrToDouble(strSize);
                  if (confValue <= 0)                                 return(!catch("ReadCustomPositionConfig(6)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (illegal equity \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
               }

               else if (StringIsNumeric(values[n])) {                      // P/L-Betrag
                  confSizeValue = NULL;
                  confTypeValue = TYPE_AMOUNT;
                  confValue     = StrToDouble(values[n]);
               }

               else if (StringEndsWith(values[n], "L")) {                  // virtuelle Longposition zum aktuellen Preis
                  strSize = StringTrimRight(StringLeft(values[n], -1));
                  if (!StringIsNumeric(strSize))                      return(!catch("ReadCustomPositionConfig(7)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confSizeValue = StrToDouble(strSize);
                  if (confSizeValue < 0)                              return(!catch("ReadCustomPositionConfig(8)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  if (MathModFix(confSizeValue, 0.001) != 0)          return(!catch("ReadCustomPositionConfig(9)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confTypeValue = TYPE_LONG;
                  confValue     = NULL;
               }

               else if (StringEndsWith(values[n], "S")) {                  // virtuelle Shortposition zum aktuellen Preis
                  strSize = StringTrimRight(StringLeft(values[n], -1));
                  if (!StringIsNumeric(strSize))                      return(!catch("ReadCustomPositionConfig(10)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confSizeValue = StrToDouble(strSize);
                  if (confSizeValue < 0)                              return(!catch("ReadCustomPositionConfig(11)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  if (MathModFix(confSizeValue, 0.001) != 0)          return(!catch("ReadCustomPositionConfig(12)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confTypeValue = TYPE_SHORT;
                  confValue     = NULL;
               }

               else if (StringContains(values[n], "L")) {                  // virtuelle Longposition zum angegebenen Preis
                  pos = StringFind(values[n], "L");
                  strSize = StringTrimRight(StringLeft(values[n], pos));
                  if (!StringIsNumeric(strSize))                      return(!catch("ReadCustomPositionConfig(13)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confSizeValue = StrToDouble(strSize);
                  if (confSizeValue < 0)                              return(!catch("ReadCustomPositionConfig(14)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  if (MathModFix(confSizeValue, 0.001) != 0)          return(!catch("ReadCustomPositionConfig(15)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confTypeValue = TYPE_LONG;
                  strPrice = StringTrimLeft(StringSubstr(values[n], pos+1));
                  if (!StringIsNumeric(strPrice))                     return(!catch("ReadCustomPositionConfig(16)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (non-numeric price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confValue = StrToDouble(strPrice);
                  if (confValue <= 0)                                 return(!catch("ReadCustomPositionConfig(17)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (illegal price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
               }

               else if (StringContains(values[n], "S")) {                  // virtuelle Shortposition zum angegebenen Preis
                  pos = StringFind(values[n], "S");
                  strSize = StringTrimRight(StringLeft(values[n], pos));
                  if (!StringIsNumeric(strSize))                      return(!catch("ReadCustomPositionConfig(18)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confSizeValue  = StrToDouble(strSize);
                  if (confSizeValue < 0)                              return(!catch("ReadCustomPositionConfig(19)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  if (MathModFix(confSizeValue, 0.001) != 0)          return(!catch("ReadCustomPositionConfig(20)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confTypeValue = TYPE_SHORT;
                  strPrice = StringTrimLeft(StringSubstr(values[n], pos+1));
                  if (!StringIsNumeric(strPrice))                     return(!catch("ReadCustomPositionConfig(21)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (non-numeric price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confValue = StrToDouble(strPrice);
                  if (confValue <= 0)                                 return(!catch("ReadCustomPositionConfig(22)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (illegal price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
               }

               else if (StringContains(values[n], "#")) {                  // Lotsizeangabe + # + Ticket
                  pos = StringFind(values[n], "#");
                  strSize = StringTrimRight(StringLeft(values[n], pos));
                  if (!StringIsNumeric(strSize))                      return(!catch("ReadCustomPositionConfig(23)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confSizeValue  = StrToDouble(strSize);
                  if (confSizeValue && LT(confSizeValue, minLotSize)) return(!catch("ReadCustomPositionConfig(24)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (lot size smaller than MIN_LOTSIZE \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  if (MathModFix(confSizeValue, lotStep) != 0)        return(!catch("ReadCustomPositionConfig(25)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (lot size not a multiple of LOTSTEP \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  strTicket  = StringTrimLeft(StringSubstr(values[n], pos+1));
                  if (!StringIsDigit(strTicket))                      return(!catch("ReadCustomPositionConfig(26)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (non-digits in ticket \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  confTypeValue = StrToInteger(strTicket);
                  confValue     = NULL;
               }

               else                                                   return(!catch("ReadCustomPositionConfig(27)   invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ value +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

               // Die Konfiguration virtueller Positionen muß mit einer virtuellen Position beginnen, damit die virtuellen Lots später nicht von den realen Lots abgezogen werden, siehe (2).
               if (confSizeValue!=EMPTY && (confTypeValue==TYPE_LONG || confTypeValue==TYPE_SHORT)) {
                  if (!isConfigEmpty && !isConfigVirtual) {
                     double tmp[3] = {0, TYPE_LONG, NULL};                 // am Anfang der Zeile virtuelle 0-Position einfügen
                     ArrayInsertDoubleArray(custom.position.conf, offsetStartOfPosition, tmp);
                  }
                  isConfigVirtual = true;
               }

               // Konfiguration hinzufügen
               confSize = ArrayRange(custom.position.conf, 0);
               ArrayResize(custom.position.conf, confSize+1);
               custom.position.conf[confSize][0] = confSizeValue;
               custom.position.conf[confSize][1] = confTypeValue;
               custom.position.conf[confSize][2] = confValue;
               isConfigEmpty = false;
            }

            if (!isConfigEmpty) {                                          // Zeilenende mit Leerelement markieren
               confSize = ArrayRange(custom.position.conf, 0);
               ArrayResize(custom.position.conf, confSize+1);              // initialisiert Element mit {NULL, NULL, NULL}
               ArrayPushString(custom.position.conf.comments, comment);
               offsetStartOfPosition = confSize + 1;                       // Start-Offset der nächsten Custom-Position (falls zutreffend)
            }
         }
      }
   }

   confSize = ArrayRange(custom.position.conf, 0);
   if (!confSize) {                                                        // leere Konfiguration mit Leerelement {NULL, NULL, NULL} markieren
      ArrayResize(custom.position.conf, 1);                                // initialisiert Element mit {NULL, NULL, NULL}
      ArrayPushString(custom.position.conf.comments, "");
   }
   return(!catch("ReadCustomPositionConfig(28)"));
}


/**
 * Extrahiert aus den übergebenen Positionen eine Teilposition.
 *
 * @param  _in_     double lotsize    - zu extrahierende Lotsize
 * @param  _in_     int    type       - zu extrahierender Typ: virtualLong/virtualShort/Ticket/Betrag/Equity
 * @param  _in_     double value      - Wert: Preis/Betrag/Equity
 *
 * @param  _in_out_ mixed  vars       - Variablen, aus denen die Teilposition extrahiert wird (Bestand verringert sich)
 * @param  _in_out_ bool   isVirtual  - ob die extrahierte Position virtuell ist
 * @param  _in_out_ mixed  customVars - Variablen, denen die extrahierte Position hinzugefügt wird (Bestand erhöht sich)
 *
 * @return bool - Erfolgsstatus
 */
bool ExtractPosition(double lotsize, int type, double value,
                     double       &longPosition, double       &shortPosition, double       &totalPosition,                                             int       &tickets[], int       &types[], double       &lots[], double       &openPrices[], double       &commissions[], double       &swaps[], double       &profits[],
                     bool            &isVirtual,
                     double &customLongPosition, double &customShortPosition, double &customTotalPosition, double &customAmount, double &customEquity, int &customTickets[], int &customTypes[], double &customLots[], double &customOpenPrices[], double &customCommissions[], double &customSwaps[], double &customProfits[]) {
   int sizeTickets = ArraySize(tickets);

   if (type == TYPE_LONG) {
      if (lotsize == EMPTY) {
         // alle (noch) existierenden Long-Positionen
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
                  if (!isVirtual) {
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
         if (lotsize != 0) {                                         // 0-Lots-Positionen werden ignoriert
            double openPrice = ifDouble(value, value, Ask);
            ArrayPushInt   (customTickets,     TYPE_LONG                                     );
            ArrayPushInt   (customTypes,       OP_BUY                                        );
            ArrayPushDouble(customLots,        lotsize                                       );
            ArrayPushDouble(customOpenPrices,  openPrice                                     );
            ArrayPushDouble(customCommissions, NormalizeDouble(-GetCommission() * lotsize, 2));
            ArrayPushDouble(customSwaps,       0                                             );
            ArrayPushDouble(customProfits,     (Bid-openPrice)/Pips * PipValue(lotsize, true)); // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
            customLongPosition  = NormalizeDouble(customLongPosition + lotsize,             3);
            customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 3);
         }
         isVirtual = true;
      }
   }

   else if (type == TYPE_SHORT) {
      if (lotsize == EMPTY) {
         // alle Short-Positionen
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
                  if (!isVirtual) {
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
         if (lotsize != 0) {                                         // 0-Lots-Positionen werden ignoriert
            openPrice = ifDouble(value, value, Bid);
            ArrayPushInt   (customTickets,     TYPE_SHORT                                    );
            ArrayPushInt   (customTypes,       OP_SELL                                       );
            ArrayPushDouble(customLots,        lotsize                                       );
            ArrayPushDouble(customOpenPrices,  openPrice                                     );
            ArrayPushDouble(customCommissions, NormalizeDouble(-GetCommission() * lotsize, 2));
            ArrayPushDouble(customSwaps,       0                                             );
            ArrayPushDouble(customProfits,     (openPrice-Ask)/Pips * PipValue(lotsize, true)); // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
            customShortPosition = NormalizeDouble(customShortPosition + lotsize,            3);
            customTotalPosition = NormalizeDouble(customLongPosition - customShortPosition, 3);
         }
         isVirtual = true;
      }
   }

   else if (type == TYPE_AMOUNT) {
      // Betrag zu customAmount hinzufügen (Ausgangsdaten bleiben unverändert)
      if (value != 0)                                                // 0.00-Beträge werden ignoriert
         customAmount += value;
   }

   else if (type == TYPE_EQUITY) {
      // vorhandenen Betrag überschreiben (Ausgangsdaten bleiben unverändert)
      customEquity = value;
   }

   else {
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
               if (!isVirtual) {
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
      else if (lotsize != 0) {                                       // 0-Lots-Positionen werden ignoriert
         // partielles Ticket
         for (i=0; i < sizeTickets; i++) {
            if (tickets[i] == type) {
               if (GT(lotsize, lots[i])) return(!catch("ExtractPosition(1)   illegal partial lotsize "+ NumberToStr(lotsize, ".+") +" for ticket #"+ tickets[i] +" (only "+ NumberToStr(lots[i], ".+") +" lot remaining)", ERR_RUNTIME_ERROR));
               if (EQ(lotsize, lots[i])) {
                  // komplettes Ticket übernehmen
                  if (!ExtractPosition(EMPTY, type, value,
                                       longPosition,       shortPosition,       totalPosition,                                   tickets,       types,       lots,       openPrices,       commissions,       swaps,       profits,
                                       isVirtual,
                                       customLongPosition, customShortPosition, customTotalPosition, customAmount, customEquity, customTickets, customTypes, customLots, customOpenPrices, customCommissions, customSwaps, customProfits))
                     return(false);
               }
               else {
                  // Daten anteilig nach custom.* übernehmen und Ticket ggf. reduzieren
                  double factor = lotsize/lots[i];
                  ArrayPushInt   (customTickets,     tickets    [i]         );
                  ArrayPushInt   (customTypes,       types      [i]         );
                  ArrayPushDouble(customLots,        lotsize                ); if (!isVirtual) lots       [i]  = NormalizeDouble(lots[i]-lotsize, 2); // reduzieren
                  ArrayPushDouble(customOpenPrices,  openPrices [i]         );
                  ArrayPushDouble(customSwaps,       swaps      [i]         ); if (!isVirtual) swaps      [i]  = NULL;                                // komplett
                  ArrayPushDouble(customCommissions, commissions[i] * factor); if (!isVirtual) commissions[i] *= (1-factor);                          // anteilig
                  ArrayPushDouble(customProfits,     profits    [i] * factor); if (!isVirtual) profits    [i] *= (1-factor);                          // anteilig
                  if (!isVirtual) {
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
   return(!catch("ExtractPosition(2)"));
}


/**
 * Speichert die übergebene Teilposition zusammengefaßt (direktionaler und gehedgeter Anteil gemeinsam) in den globalen Variablen positions.~data[].
 *
 * @return bool - Erfolgsstatus
 */
bool StoreCustomPosition(bool isVirtual, double longPosition, double shortPosition, double totalPosition, double customAmount, double customEquity, int iCommentLine, int &tickets[], int &types[], double &lots[], double &openPrices[], double &commissions[], double &swaps[], double &profits[]) {
   isVirtual = isVirtual!=0;

   // Existieren zu dieser Position keine offenen Tickets mehr, wird sie übersprungen
   if (!totalPosition) /*&&*/ if (!longPosition) /*&&*/ if (!shortPosition)
      return(true);


   double hedgedLotSize, remainingLong, remainingShort, factor, openPrice, closePrice, commission, swap, profit, hedgedProfit, openEquity, pipDistance, pipValue;
   int size, ticketsSize=ArraySize(tickets);

   if (customEquity != NULL) openEquity = customEquity;
   else {
      openEquity = GetExternalAssets();
      if (mode.intern)
         openEquity += MathMin(AccountBalance(), AccountEquity()-AccountCredit());
   }

   // Die Gesamtposition besteht aus einem gehedgtem Anteil (konstanter Profit) und einem direktionalen Anteil (variabler Profit).
   // - kein direktionaler Anteil:  BE-Distance berechnen
   // - direktionaler Anteil:       Breakeven unter Berücksichtigung des Profits eines gehedgten Anteils berechnen


   // (1) BE-Distance und Profit einer eventuellen Hedgeposition ermitteln
   if (longPosition && shortPosition) {
      hedgedLotSize  = MathMin(longPosition, shortPosition);
      remainingLong  = hedgedLotSize;
      remainingShort = hedgedLotSize;

      for (int i=0; i < ticketsSize; i++) {
         if (!tickets[i]) continue;

         if (types[i] == OP_BUY) {
            if (!remainingLong) continue;
            if (remainingLong >= lots[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice     = NormalizeDouble(openPrice     + lots[i] * openPrices[i], 8);
               swap         += swaps      [i];
               commission   += commissions[i];
               remainingLong = NormalizeDouble(remainingLong - lots[i], 3);
               tickets[i]    = NULL;
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor        = remainingLong/lots[i];
               openPrice     = NormalizeDouble(openPrice + remainingLong * openPrices [i], 8);
               swap         += swaps[i];                swaps      [i]  = 0;
               commission   += factor * commissions[i]; commissions[i] -= factor * commissions[i];
                                                        profits    [i] -= factor * profits    [i];
                                                        lots       [i]  = NormalizeDouble(lots[i]-remainingLong, 3);
               remainingLong = 0;
            }
         }
         else { /*OP_SELL*/
            if (!remainingShort) continue;
            if (remainingShort >= lots[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               closePrice     = NormalizeDouble(closePrice     + lots[i] * openPrices[i], 8);
               swap          += swaps      [i];
               //commission  += commissions[i];                                        // Commission wird nur für Long-Leg übernommen
               remainingShort = NormalizeDouble(remainingShort - lots[i], 3);
               tickets[i]     = NULL;
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor         = remainingShort/lots[i];
               closePrice     = NormalizeDouble(closePrice + remainingShort * openPrices[i], 8);
               swap          += swaps[i]; swaps      [i]  = 0;
                                          commissions[i] -= factor * commissions[i];   // Commission wird nur für Long-Leg übernommen
                                          profits    [i] -= factor * profits    [i];
                                          lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 3);
               remainingShort = 0;
            }
         }
      }
      if (remainingLong  != 0) return(!catch("StoreCustomPosition(1)   illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of custom hedged position = "+ NumberToStr(hedgedLotSize, ".+"), ERR_RUNTIME_ERROR));
      if (remainingShort != 0) return(!catch("StoreCustomPosition(2)   illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of custom hedged position = "+ NumberToStr(hedgedLotSize, ".+"), ERR_RUNTIME_ERROR));

      // BE-Distance und Profit berechnen
      pipValue = PipValue(hedgedLotSize, true);                                        // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
      if (pipValue != 0) {
         pipDistance  = NormalizeDouble((closePrice-openPrice)/hedgedLotSize/Pips + (commission+swap)/pipValue, 8);
         hedgedProfit = pipDistance * pipValue;
      }

      // (1.1) Kein direktionaler Anteil: Position speichern und Rückkehr
      if (!totalPosition) {
         size = ArrayRange(positions.idata, 0);
         ArrayResize(positions.idata, size+1);
         ArrayResize(positions.ddata, size+1);

         positions.idata[size][I_POSITION_TYPE ] = TYPE_CUSTOM + isVirtual;
         positions.idata[size][I_DIRECTION_TYPE] = TYPE_HEDGE;
         positions.idata[size][I_COMMENT       ] = iCommentLine;
         positions.ddata[size][I_DIRECT_LOTSIZE] = 0;
         positions.ddata[size][I_HEDGED_LOTSIZE] = hedgedLotSize;
         positions.ddata[size][I_BREAKEVEN     ] = pipDistance;
         positions.ddata[size][I_PROFIT        ] = hedgedProfit + customAmount;
         positions.ddata[size][I_CUSTOM_AMOUNT ] = customAmount;
         positions.ddata[size][I_OPEN_EQUITY   ] = openEquity;
         positions.ddata[size][I_PROFIT_PERCENT] = MathDiv(positions.ddata[size][I_PROFIT], positions.ddata[size][I_OPEN_EQUITY]) * 100;
         return(!catch("StoreCustomPosition(3)"));
      }
   }


   // (2) Direktionaler Anteil: Bei Breakeven-Berechnung den Profit eines gehedgten Anteils und einen zusätzlich angegebenen Betrag berücksichtigen.
   // (2.1) eventuelle Longposition ermitteln
   if (totalPosition > 0) {
      remainingLong = totalPosition;
      openPrice     = 0;
      swap          = 0;
      commission    = 0;
      profit        = 0;

      for (i=0; i < ticketsSize; i++) {
         if (!tickets[i]   ) continue;
         if (!remainingLong) continue;

         if (types[i] == OP_BUY) {
            if (remainingLong >= lots[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice     = NormalizeDouble(openPrice     + lots[i] * openPrices[i], 8);
               swap         += swaps      [i];
               commission   += commissions[i];
               profit       += profits    [i];
               tickets[i]    = NULL;
               remainingLong = NormalizeDouble(remainingLong - lots[i], 3);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor        = remainingLong/lots[i];
               openPrice     = NormalizeDouble(openPrice + remainingLong * openPrices [i], 8);
               swap         +=          swaps      [i]; swaps      [i]  = 0;
               commission   += factor * commissions[i]; commissions[i] -= factor * commissions[i];
               profit       += factor * profits    [i]; profits    [i] -= factor * profits    [i];
                                                        lots       [i]  = NormalizeDouble(lots[i]-remainingLong, 3);
               remainingLong = 0;
            }
         }
      }
      if (remainingLong != 0) return(!catch("StoreCustomPosition(4)   illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of custom long position = "+ NumberToStr(totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      size = ArrayRange(positions.idata, 0);
      ArrayResize(positions.idata, size+1);
      ArrayResize(positions.ddata, size+1);

      positions.idata[size][I_POSITION_TYPE ] = TYPE_CUSTOM + isVirtual;
      positions.idata[size][I_DIRECTION_TYPE] = TYPE_LONG;
      positions.idata[size][I_COMMENT       ] = iCommentLine;
      positions.ddata[size][I_DIRECT_LOTSIZE] = totalPosition;
      positions.ddata[size][I_HEDGED_LOTSIZE] = hedgedLotSize;
         pipValue = PipValue(totalPosition, true);                   // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0) {
      positions.ddata[size][I_BREAKEVEN     ] = NormalizeDouble(openPrice/totalPosition - (hedgedProfit + customAmount + commission + swap)/pipValue*Pips, 8);
         }
      positions.ddata[size][I_PROFIT        ] = hedgedProfit + customAmount + commission + swap + profit;
      positions.ddata[size][I_CUSTOM_AMOUNT ] = customAmount;
      positions.ddata[size][I_OPEN_EQUITY   ] = openEquity;
      positions.ddata[size][I_PROFIT_PERCENT] = MathDiv(positions.ddata[size][I_PROFIT], positions.ddata[size][I_OPEN_EQUITY]) * 100;
      return(!catch("StoreCustomPosition(5)"));
   }


   // (2.2) eventuelle Shortposition ermitteln
   if (totalPosition < 0) {
      remainingShort = -totalPosition;
      openPrice      = 0;
      swap           = 0;
      commission     = 0;
      profit         = 0;

      for (i=0; i < ticketsSize; i++) {
         if (!tickets[i]    ) continue;
         if (!remainingShort) continue;

         if (types[i] == OP_SELL) {
            if (remainingShort >= lots[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice      = NormalizeDouble(openPrice      + lots[i] * openPrices[i], 8);
               swap          += swaps      [i];
               commission    += commissions[i];
               profit        += profits    [i];
               tickets[i]     = NULL;
               remainingShort = NormalizeDouble(remainingShort - lots[i], 3);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor         = remainingShort/lots[i];
               openPrice      = NormalizeDouble(openPrice + remainingShort * openPrices [i], 8);
               swap          +=          swaps      [i]; swaps      [i]  = 0;
               commission    += factor * commissions[i]; commissions[i] -= factor * commissions[i];
               profit        += factor * profits    [i]; profits    [i] -= factor * profits    [i];
                                                         lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 3);
               remainingShort = 0;
            }
         }
      }
      if (remainingShort != 0) return(!catch("StoreCustomPosition(6)   illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of custom short position = "+ NumberToStr(-totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      size = ArrayRange(positions.idata, 0);
      ArrayResize(positions.idata, size+1);
      ArrayResize(positions.ddata, size+1);

      positions.idata[size][I_POSITION_TYPE ] = TYPE_CUSTOM + isVirtual;
      positions.idata[size][I_DIRECTION_TYPE] = TYPE_SHORT;
      positions.idata[size][I_COMMENT       ] = iCommentLine;
      positions.ddata[size][I_DIRECT_LOTSIZE] = -totalPosition;
      positions.ddata[size][I_HEDGED_LOTSIZE] = hedgedLotSize;
         pipValue = PipValue(-totalPosition, true);                  // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0) {
      positions.ddata[size][I_BREAKEVEN     ] = NormalizeDouble((hedgedProfit + customAmount + commission + swap)/pipValue*Pips - openPrice/totalPosition, 8);
         }
      positions.ddata[size][I_PROFIT        ] = hedgedProfit + customAmount + commission + swap + profit;
      positions.ddata[size][I_CUSTOM_AMOUNT ] = customAmount;
      positions.ddata[size][I_OPEN_EQUITY   ] = openEquity;
      positions.ddata[size][I_PROFIT_PERCENT] = MathDiv(positions.ddata[size][I_PROFIT], positions.ddata[size][I_OPEN_EQUITY]) * 100;
      return(!catch("StoreCustomPosition(7)"));
   }

   return(!catch("StoreCustomPosition(8)   unreachable code reached", ERR_RUNTIME_ERROR));
}


/**
 * Speichert die übergebenen Teilpositionen getrennt nach Long/Short/Hedge in den globalen Variablen positions.~data[].
 *
 * @return bool - Erfolgsstatus
 */
bool StoreRegularPositions(double longPosition, double shortPosition, double totalPosition, int &tickets[], int &types[], double &lots[], double &openPrices[], double &commissions[], double &swaps[], double &profits[]) {
   double hedgedLotSize, remainingLong, remainingShort, factor, openPrice, closePrice, commission, swap, profit, openEquity, pipValue;
   int ticketsSize = ArraySize(tickets);

   longPosition  = NormalizeDouble(longPosition,  2);
   shortPosition = NormalizeDouble(shortPosition, 2);
   totalPosition = NormalizeDouble(totalPosition, 2);

   openEquity = GetExternalAssets();
   if (mode.intern)
      openEquity += MathMin(AccountBalance(), AccountEquity()-AccountCredit());


   // (1) eventuelle Longposition selektieren
   if (totalPosition > 0) {
      remainingLong = totalPosition;
      openPrice     = 0;
      swap          = 0;
      commission    = 0;
      profit        = 0;

      for (int i=ticketsSize-1; i >= 0; i--) {                       // jüngstes Ticket zuerst
         if (!tickets[i]   ) continue;
         if (!remainingLong) continue;

         if (types[i] == OP_BUY) {
            lots[i] = NormalizeDouble(lots[i], 2);

            if (remainingLong >= lots[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice     = NormalizeDouble(openPrice     + lots[i] * openPrices[i], 8);
               swap         += swaps      [i];
               commission   += commissions[i];
               profit       += profits    [i];
               tickets[i]    = NULL;
               remainingLong = NormalizeDouble(remainingLong - lots[i], 2);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor        = remainingLong/lots[i];
               openPrice     = NormalizeDouble(openPrice + remainingLong * openPrices [i], 8);
               swap         +=          swaps      [i]; swaps      [i]  = 0;
               commission   += factor * commissions[i]; commissions[i] -= factor * commissions[i];
               profit       += factor * profits    [i]; profits    [i] -= factor * profits    [i];
                                                        lots       [i]  = NormalizeDouble(lots[i]-remainingLong, 2);
               remainingLong = 0;
            }
         }
      }
      if (remainingLong != 0) return(!catch("StoreRegularPositions(1)   illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of effective long position = "+ NumberToStr(totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      int size = ArrayRange(positions.idata, 0);
      ArrayResize(positions.idata, size+1);
      ArrayResize(positions.ddata, size+1);

      positions.idata[size][I_POSITION_TYPE ] = TYPE_DEFAULT;
      positions.idata[size][I_DIRECTION_TYPE] = TYPE_LONG;
      positions.idata[size][I_COMMENT       ] = -1;                  // kein Kommentar
      positions.ddata[size][I_DIRECT_LOTSIZE] = totalPosition;
      positions.ddata[size][I_HEDGED_LOTSIZE] = 0;
         pipValue = PipValue(totalPosition, true);                   // TRUE = Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0) {
      positions.ddata[size][I_BREAKEVEN     ] = NormalizeDouble(openPrice/totalPosition - (commission+swap)/pipValue*Pips, 8);
         }
      positions.ddata[size][I_PROFIT        ] = commission + swap + profit;
      positions.ddata[size][I_CUSTOM_AMOUNT ] = 0;
      positions.ddata[size][I_OPEN_EQUITY   ] = openEquity;
      positions.ddata[size][I_PROFIT_PERCENT] = MathDiv(positions.ddata[size][I_PROFIT], positions.ddata[size][I_OPEN_EQUITY]) * 100;
   }


   // (2) eventuelle Shortposition selektieren
   if (totalPosition < 0) {
      remainingShort = -totalPosition;
      openPrice      = 0;
      swap           = 0;
      commission     = 0;
      profit         = 0;

      for (i=ticketsSize-1; i >= 0; i--) {                                 // jüngstes Ticket zuerst
         if (!tickets[i]    ) continue;
         if (!remainingShort) continue;

         if (types[i] == OP_SELL) {
            lots[i] = NormalizeDouble(lots[i], 2);

            if (remainingShort >= lots[i]) {
               // Daten komplett übernehmen, Ticket auf NULL setzen
               openPrice      = NormalizeDouble(openPrice      + lots[i] * openPrices[i], 8);
               swap          += swaps      [i];
               commission    += commissions[i];
               profit        += profits    [i];
               tickets[i]     = NULL;
               remainingShort = NormalizeDouble(remainingShort - lots[i], 2);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor         = remainingShort/lots[i];
               openPrice      = NormalizeDouble(openPrice + remainingShort * openPrices [i], 8);
               swap          +=          swaps      [i]; swaps      [i]  = 0;
               commission    += factor * commissions[i]; commissions[i] -= factor * commissions[i];
               profit        += factor * profits    [i]; profits    [i] -= factor * profits    [i];
                                                         lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 2);
               remainingShort = 0;
            }
         }
      }
      if (remainingShort != 0) return(!catch("StoreRegularPositions(2)   illegal remaining short position ("+ NumberToStr(remainingShort, ".+") +" lots) of effective short position of "+ NumberToStr(-totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      size = ArrayRange(positions.idata, 0);
      ArrayResize(positions.idata, size+1);
      ArrayResize(positions.ddata, size+1);

      positions.idata[size][I_POSITION_TYPE ] = TYPE_DEFAULT;
      positions.idata[size][I_DIRECTION_TYPE] = TYPE_SHORT;
      positions.idata[size][I_COMMENT       ] = -1;                  // kein Kommentar
      positions.ddata[size][I_DIRECT_LOTSIZE] = -totalPosition;
      positions.ddata[size][I_HEDGED_LOTSIZE] = 0;
         pipValue = PipValue(-totalPosition, true);                  // TRUE = Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0) {
      positions.ddata[size][I_BREAKEVEN     ] = NormalizeDouble((commission+swap)/pipValue*Pips - openPrice/totalPosition, 8);
         }
      positions.ddata[size][I_PROFIT        ] = commission + swap + profit;
      positions.ddata[size][I_CUSTOM_AMOUNT ] = 0;
      positions.ddata[size][I_OPEN_EQUITY   ] = openEquity;
      positions.ddata[size][I_PROFIT_PERCENT] = MathDiv(positions.ddata[size][I_PROFIT], positions.ddata[size][I_OPEN_EQUITY]) * 100;
   }


   // (3) verbleibende Hedgeposition selektieren
   if (longPosition && shortPosition) {
      hedgedLotSize  = MathMin(longPosition, shortPosition);
      remainingLong  = hedgedLotSize;
      remainingShort = hedgedLotSize;
      openPrice      = 0;
      closePrice     = 0;
      swap           = 0;
      commission     = 0;

      for (i=ticketsSize-1; i >= 0; i--) {                           // jüngstes Ticket zuerst
         if (!tickets[i]) continue;
         lots[i] = NormalizeDouble(lots[i], 2);

         if (types[i] == OP_BUY) {
            if (!remainingLong) continue;
            if (remainingLong < lots[i]) return(!catch("StoreRegularPositions(3)   illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of hedged position = "+ NumberToStr(hedgedLotSize, ".+"), ERR_RUNTIME_ERROR));

            // Daten komplett übernehmen, Ticket auf NULL setzen
            openPrice     = NormalizeDouble(openPrice     + lots[i] * openPrices[i], 8);
            swap         += swaps      [i];
            commission   += commissions[i];
            remainingLong = NormalizeDouble(remainingLong - lots[i], 2);
            tickets[i]    = NULL;
         }
         else { /*OP_SELL*/
            if (!remainingShort) continue;
            if (remainingShort < lots[i]) return(!catch("StoreRegularPositions(4)   illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of hedged position = "+ NumberToStr(hedgedLotSize, ".+"), ERR_RUNTIME_ERROR));

            // Daten komplett übernehmen, Ticket auf NULL setzen
            closePrice     = NormalizeDouble(closePrice     + lots[i] * openPrices[i], 8);
            swap          += swaps      [i];
            //commission  += commissions[i];                         // Commissions nur für eine Seite übernehmen
            remainingShort = NormalizeDouble(remainingShort - lots[i], 2);
            tickets[i]     = NULL;
         }
      }

      // Position speichern
      size = ArrayRange(positions.idata, 0);
      ArrayResize(positions.idata, size+1);
      ArrayResize(positions.ddata, size+1);

      positions.idata[size][I_POSITION_TYPE ] = TYPE_DEFAULT;
      positions.idata[size][I_DIRECTION_TYPE] = TYPE_HEDGE;
      positions.idata[size][I_COMMENT       ] = -1;                  // kein Kommentar
      positions.ddata[size][I_DIRECT_LOTSIZE] = 0;
      positions.ddata[size][I_HEDGED_LOTSIZE] = hedgedLotSize;
         pipValue = PipValue(hedgedLotSize, true);                   // TRUE = Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
         if (pipValue != 0)
      positions.ddata[size][I_BREAKEVEN     ] = NormalizeDouble((closePrice-openPrice)/hedgedLotSize/Pips + (commission+swap)/pipValue, 8);
      positions.ddata[size][I_PROFIT        ] = positions.ddata[size][I_BREAKEVEN] * pipValue;
      positions.ddata[size][I_CUSTOM_AMOUNT ] = 0;
      positions.ddata[size][I_OPEN_EQUITY   ] = openEquity;
      positions.ddata[size][I_PROFIT_PERCENT] = MathDiv(positions.ddata[size][I_PROFIT], positions.ddata[size][I_OPEN_EQUITY]) * 100;
   }

   return(!catch("StoreRegularPositions(5)"));
}


/**
 * Handler für beim LFX-Terminal eingehende Messages.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.HandleLfxTerminalMessages() {
   if (!IsChart)
      return(true);

   // (1) ggf. Receiver starten
   if (!hQC.TradeToLfxReceiver) /*&&*/ if (!QC.StartTradeToLfxReceiver())
      return(false);

   // (2) Channel auf neue Messages prüfen
   int result = QC_CheckChannel(qc.TradeToLfxChannel);
   if (result < QC_CHECK_CHANNEL_EMPTY) {
      if (result == QC_CHECK_CHANNEL_ERROR) return(!catch("QC.HandleLfxTerminalMessages(1)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeToLfxChannel +"\") => QC_CHECK_CHANNEL_ERROR",            ERR_WIN32_ERROR));
      if (result == QC_CHECK_CHANNEL_NONE ) return(!catch("QC.HandleLfxTerminalMessages(2)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeToLfxChannel +"\")   channel doesn't exist",              ERR_WIN32_ERROR));
                                            return(!catch("QC.HandleLfxTerminalMessages(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeToLfxChannel +"\")   unexpected return value = "+ result, ERR_WIN32_ERROR));
   }
   if (result == QC_CHECK_CHANNEL_EMPTY)
      return(true);

   // (3) neue Messages abholen
   result = QC_GetMessages3(hQC.TradeToLfxReceiver, qc.TradeToLfxBuffer, QC_MAX_BUFFER_SIZE);
   if (result != QC_GET_MSG3_SUCCESS) {
      if (result == QC_GET_MSG3_CHANNEL_EMPTY) return(!catch("QC.HandleLfxTerminalMessages(4)->MT4iQuickChannel::QC_GetMessages3()   QC_CheckChannel not empty/QC_GET_MSG3_CHANNEL_EMPTY mismatch error",     ERR_WIN32_ERROR));
      if (result == QC_GET_MSG3_INSUF_BUFFER ) return(!catch("QC.HandleLfxTerminalMessages(5)->MT4iQuickChannel::QC_GetMessages3()   buffer to small (QC_MAX_BUFFER_SIZE/QC_GET_MSG3_INSUF_BUFFER mismatch)", ERR_WIN32_ERROR));
                                               return(!catch("QC.HandleLfxTerminalMessages(6)->MT4iQuickChannel::QC_GetMessages3()   unexpected return value = "+ result,                                     ERR_WIN32_ERROR));
   }

   // (4) Messages verarbeiten: Da hier sehr viele Messages eingehen, werden sie zur Beschleunigung statt mit Explode() manuell zerlegt.
   string msgs = qc.TradeToLfxBuffer[0];
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
 * @return bool - Erfolgsstatus: Ob die Message erfolgreich verarbeitet wurde. Ein falsches Messageformat oder keine zur Message passende Order sind kein Fehler,
 *                               ein Programmabbruch von außen durch Schicken einer falschen Message ist nicht möglich. Für unerkannte Messages wird eine
 *                               Warnung ausgegeben.
 *
 *  Messageformat: "LFX:{iTicket]:pending={1|0}"   - die angegebene Pending-Order wurde platziert (immer erfolgreich, da im Fehlerfall keine Message generiert wird)
 *                 "LFX:{iTicket]:open={1|0}"      - die angegebene Pending-Order wurde ausgeführt/konnte nicht ausgeführt werden
 *                 "LFX:{iTicket]:close={0|1}"     - die angegebene Position wurde geschlossen/konnte nicht geschlossen werden
 *                 "LFX:{iTicket]:profit={dValue}" - der P/L-Wert der angegebenen Position hat sich geändert
 */
bool ProcessLfxTerminalMessage(string message) {
   // Da hier sehr viele Messages eingehen, werden sie zur Beschleunigung statt mit Explode() manuell zerlegt.
   // LFX-Prefix
   if (StringSubstr(message, 0, 4) != "LFX:")                                        return(_true(warn("ProcessLfxTerminalMessage(1)   unknown message format \""+ message +"\"")));
   // LFX-Ticket
   int from=4, to=StringFind(message, ":", from);                   if (to <= from)  return(_true(warn("ProcessLfxTerminalMessage(2)   unknown message \""+ message +"\" (illegal order ticket)")));
   int ticket = StrToInteger(StringSubstr(message, from, to-from)); if (ticket <= 0) return(_true(warn("ProcessLfxTerminalMessage(3)   unknown message \""+ message +"\" (illegal order ticket)")));
   // LFX-Parameter
   double profit;
   bool   success;
   from = to+1;

   // :profit={dValue}
   if (StringSubstr(message, from, 7) == "profit=") {                         // die häufigste Message wird zuerst geprüft
      int size = ArrayRange(lfxOrders, 0);
      for (int i=0; i < size; i++) {
         if (lfxOrders.ivolatile[i][I_TICKET] == ticket) {                    // geladene LFX-Orders durchsuchen und P/L aktualisieren
            if (lfxOrders.ivolatile[i][I_ISOPEN] && !lfxOrders.ivolatile[i][I_ISLOCKED])
               lfxOrders.dvolatile[i][I_VPROFIT] = NormalizeDouble(StrToDouble(StringSubstr(message, from+7)), 2);
            break;
         }
      }
      return(true);
   }

   // :pending={1|0}
   if (StringSubstr(message, from, 8) == "pending=") {
      success = (StrToInteger(StringSubstr(message, from+8)) != 0);
      if (success) { if (__LOG) log("ProcessLfxTerminalMessage(4)   #"+ ticket +" pending order "+ ifString(success, "confirmation", "error"                           )); }
      else         {           warn("ProcessLfxTerminalMessage(5)   #"+ ticket +" pending order "+ ifString(success, "confirmation", "error (what use case is this???)")); }
      return(RestoreLfxStatusFromFile());                                     // LFX-Status neu einlesen (auch bei Fehler)
   }

   // :open={1|0}
   if (StringSubstr(message, from, 5) == "open=") {
      success = (StrToInteger(StringSubstr(message, from+5)) != 0);
      if (__LOG) log("ProcessLfxTerminalMessage(6)   #"+ ticket +" open position "+ ifString(success, "confirmation", "error"));
      return(RestoreLfxStatusFromFile());                                     // LFX-Status neu einlesen (auch bei Fehler)
   }

   // :close={1|0}
   if (StringSubstr(message, from, 6) == "close=") {
      success = (StrToInteger(StringSubstr(message, from+6)) != 0);
      if (__LOG) log("ProcessLfxTerminalMessage(7)   #"+ ticket +" close position "+ ifString(success, "confirmation", "error"));
      return(RestoreLfxStatusFromFile());                                     // LFX-Status neu einlesen (auch bei Fehler)
   }

   // ???
   return(_true(warn("ProcessLfxTerminalMessage(8)   unknown message \""+ message +"\"")));
}


/**
 * Liest den aktuellen LFX-Status komplett neu ein.
 *
 * @return bool - Erfolgsstatus
 */
bool RestoreLfxStatusFromFile() {
   // Sind wir nicht in einem init()-Cycle, werden die vorhandenen volatilen Daten vorm Überschreiben gespeichert.
   if (ArrayRange(lfxOrders.ivolatile, 0) > 0) {
      if (!SaveVolatileLfxStatus())
         return(false);
   }
   ArrayResize(lfxOrders.ivolatile, 0);
   ArrayResize(lfxOrders.dvolatile, 0);
   lfxOrders.openPositions = 0;


   // offene Orders einlesen
   int size = LFX.GetOrders(lfxCurrency, OF_OPEN, lfxOrders);
   if (size == -1)
      return(false);
   ArrayResize(lfxOrders.ivolatile, size);
   ArrayResize(lfxOrders.dvolatile, size);


   // Zähler der offenen Positionen und volatile P/L-Daten aktualisieren
   for (int i=0; i < size; i++) {
      lfxOrders.ivolatile[i][I_TICKET] = los.Ticket(lfxOrders, i);
      lfxOrders.ivolatile[i][I_ISOPEN] = los.IsOpen(lfxOrders, i);
      if (lfxOrders.ivolatile[i][I_ISOPEN] == 0) {
         lfxOrders.dvolatile[i][I_VPROFIT] = 0;
         continue;
      }
      lfxOrders.openPositions++;

      string varName = StringConcatenate("LFX.#", lfxOrders.ivolatile[i][I_TICKET], ".profit");
      double value   = GlobalVariableGet(varName);
      if (!value) {                                                  // 0 oder Fehler
         int error = GetLastError();
         if (error!=NO_ERROR) /*&&*/ if (error!=ERR_GLOBAL_VARIABLE_NOT_FOUND)
            return(!catch("RestoreLfxStatusFromFile(1)->GlobalVariableGet(name=\""+ varName +"\")", error));
      }
      lfxOrders.dvolatile[i][I_VPROFIT] = value;
   }
   return(true);
}


/**
 * Restauriert den LFX-Status aus den in der Library zwischengespeicherten Daten.
 *
 * @return bool - Erfolgsstatus
 */
bool RestoreLfxStatusFromLib() {
   int size = ChartInfos.CopyLfxStatus(false, lfxOrders, lfxOrders.ivolatile, lfxOrders.dvolatile);
   if (size == -1)
      return(!SetLastError(ERR_RUNTIME_ERROR));

   lfxOrders.openPositions = 0;

   // Zähler der offenen Positionen aktualisieren
   for (int i=0; i < size; i++) {
      if (lfxOrders.ivolatile[i][I_ISOPEN] != 0)
         lfxOrders.openPositions++;
   }
   return(true);
}


/**
 * Speichert die volatilen LFX-P/L-Daten in globalen Variablen.
 *
 * @return bool - Erfolgsstatus
 */
bool SaveVolatileLfxStatus() {
   string varName;
   int size = ArrayRange(lfxOrders.ivolatile, 0);

   for (int i=0; i < size; i++) {
      if (lfxOrders.ivolatile[i][I_ISOPEN] != 0) {
         varName = StringConcatenate("LFX.#", lfxOrders.ivolatile[i][I_TICKET], ".profit");

         if (!GlobalVariableSet(varName, lfxOrders.dvolatile[i][I_VPROFIT])) {
            int error = GetLastError();
            return(!catch("SaveVolatileLfxStatus(1)->GlobalVariableSet(name=\""+ varName +"\", value="+ DoubleToStr(lfxOrders.dvolatile[i][I_VPROFIT], 2) +")", ifInt(!error, ERR_RUNTIME_ERROR, error)));
         }
      }
   }
   return(true);
}


/**
 * Listener + Handler für beim Terminal eingehende Trade-Commands.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.HandleTradeCommands() {
   if (!IsChart)
      return(true);

   // (1) ggf. Receiver starten
   if (!hQC.TradeCmdReceiver) /*&&*/ if (!QC.StartTradeCmdReceiver())
      return(false);

   // (2) Channel auf neue Messages prüfen
   int result = QC_CheckChannel(qc.TradeCmdChannel);
   if (result < QC_CHECK_CHANNEL_EMPTY) {
      if (result == QC_CHECK_CHANNEL_ERROR)    return(!catch("QC.HandleTradeCommands(1)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeCmdChannel +"\") => QC_CHECK_CHANNEL_ERROR",            ERR_WIN32_ERROR));
      if (result == QC_CHECK_CHANNEL_NONE )    return(!catch("QC.HandleTradeCommands(2)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeCmdChannel +"\")   channel doesn't exist",              ERR_WIN32_ERROR));
                                               return(!catch("QC.HandleTradeCommands(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeCmdChannel +"\")   unexpected return value = "+ result, ERR_WIN32_ERROR));
   }
   if (result == QC_CHECK_CHANNEL_EMPTY)
      return(true);

   // (3) neue Messages abholen
   result = QC_GetMessages3(hQC.TradeCmdReceiver, qc.TradeCmdBuffer, QC_MAX_BUFFER_SIZE);
   if (result != QC_GET_MSG3_SUCCESS) {
      if (result == QC_GET_MSG3_CHANNEL_EMPTY) return(!catch("QC.HandleTradeCommands(4)->MT4iQuickChannel::QC_GetMessages3()   QC_CheckChannel not empty/QC_GET_MSG3_CHANNEL_EMPTY mismatch error",     ERR_WIN32_ERROR));
      if (result == QC_GET_MSG3_INSUF_BUFFER ) return(!catch("QC.HandleTradeCommands(5)->MT4iQuickChannel::QC_GetMessages3()   buffer to small (QC_MAX_BUFFER_SIZE/QC_GET_MSG3_INSUF_BUFFER mismatch)", ERR_WIN32_ERROR));
                                               return(!catch("QC.HandleTradeCommands(6)->MT4iQuickChannel::QC_GetMessages3()   unexpected return value = "+ result,                                     ERR_WIN32_ERROR));
   }

   // (4) Messages verarbeiten
   string msgs[];
   int msgsSize = Explode(qc.TradeCmdBuffer[0], TAB, msgs, NULL);

   for (int i=0; i < msgsSize; i++) {
      if (!StringLen(msgs[i]))
         continue;
      log("QC.HandleTradeCommands(7)   received \""+ msgs[i] +"\"");
      if (!RunScript("LFX.ExecuteTradeCmd", "command="+ msgs[i]))    // TODO: Scripte dürfen nicht in Schleife gestartet werden
         return(false);
   }
   return(true);
}


/**
 * Aufruf nur in ChartInfos::AnalyzePositions()
 *
 * Schickt den aktuellen P/L der offenen LFX-Positionen ans LFX-Terminal, wenn er sich seit dem letzten Aufruf geändert hat.
 *
 * @return bool - Erfolgsstatus
 */
bool LFX.ProcessProfits(int &lfxMagics[], double &lfxProfits[]) {
   double lastLfxProfit;
   string lfxMessages[]; ArrayResize(lfxMessages, 0); ArrayResize(lfxMessages, ArraySize(hQC.TradeToLfxSenders));    // 2 x ArrayResize() = ArrayInitialize()
   string globalVarLfxProfit;

   for (int i=ArraySize(lfxMagics)-1; i > 0; i--) {                  // Index 0 ist unbenutzt
      // (1) prüfen, ob sich der aktuelle vom letzten verschickten Wert unterscheidet
      globalVarLfxProfit = StringConcatenate("LFX.#", lfxMagics[i], ".profit");
      lastLfxProfit      = GlobalVariableGet(globalVarLfxProfit);
      if (!lastLfxProfit) {                                          // 0 oder Fehler
         int error = GetLastError();
         if (error!=NO_ERROR) /*&&*/ if (error!=ERR_GLOBAL_VARIABLE_NOT_FOUND)
            return(!catch("LFX.ProcessProfits(1)->GlobalVariableGet()", error));
      }

      // TODO: Prüfung auf Wertänderung nur innerhalb der Woche, nicht am Wochenende

      if (EQ(lfxProfits[i], lastLfxProfit)) {                        // Wert hat sich nicht geändert
         lfxMagics[i] = NULL;                                        // MagicNumber zurücksetzen, um in (4) Marker für Speichern in globaler Variable zu haben
         continue;
      }

      // (2) geänderten Wert zu Messages des entsprechenden Channels hinzufügen (Messages eines Channels werden gemeinsam, nicht einzeln verschickt)
      int cid = LFX.CurrencyId(lfxMagics[i]);
      if (!StringLen(lfxMessages[cid])) lfxMessages[cid] = StringConcatenate(                       "LFX:", lfxMagics[i], ":profit=", DoubleToStr(lfxProfits[i], 2));
      else                              lfxMessages[cid] = StringConcatenate(lfxMessages[cid], TAB, "LFX:", lfxMagics[i], ":profit=", DoubleToStr(lfxProfits[i], 2));
   }

   // (3) angesammelte Messages verschicken: Messages je Channel werden gemeinsam, nicht einzeln verschickt, um beim Empfänger unnötige Ticks zu vermeiden
   for (i=ArraySize(lfxMessages)-1; i > 0; i--) {                    // Index 0 ist unbenutzt
      if (StringLen(lfxMessages[i]) > 0) {
         if (!hQC.TradeToLfxSenders[i]) /*&&*/ if (!QC.StartTradeToLfxSender(i))
            return(false);
         if (!QC_SendMessage(hQC.TradeToLfxSenders[i], lfxMessages[i], QC_FLAG_SEND_MSG_IF_RECEIVER))
            return(!catch("LFX.ProcessProfits(2)->MT4iQuickChannel::QC_SendMessage() = QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));
      }
   }

   // (4) verschickte Werte jeweils in globaler Variable speichern
   for (i=ArraySize(lfxMagics)-1; i > 0; i--) {                      // Index 0 ist unbenutzt
      // Marker aus (1) verwenden: MagicNumbers unveränderter Werte wurden zurückgesetzt
      if (lfxMagics[i] != 0) {
         globalVarLfxProfit = StringConcatenate("LFX.#", lfxMagics[i], ".profit");
         if (!GlobalVariableSet(globalVarLfxProfit, lfxProfits[i])) {
            error = GetLastError();
            return(!catch("LFX.ProcessProfits(3)->GlobalVariableSet(name=\""+ globalVarLfxProfit +"\", value="+ lfxProfits[i] +")", ifInt(!error, ERR_RUNTIME_ERROR, error)));
         }
      }
   }

   return(!catch("LFX.ProcessProfits(4)"));
}


/**
 * Speichert die Fenster-relevanten Konfigurationsdaten im Chart und in der lokalen Terminalkonfiguration.
 * Dadurch gehen sie auch beim Laden eines neuen Chart-Templates nicht verloren.
 *
 * @return bool - Erfolgsstatus
 */
bool StoreWindowStatus() {
   // (1) Signaltracking
   // Konfiguration im Chart speichern (oder löschen)
   string label = __NAME__ +".sticky.TrackSignal";
   string value = external.provider +"."+ external.signal;
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (mode.extern) {
      ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
      ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
      ObjectSetText(label, value);
   }
   // Konfiguration in Terminalkonfiguration speichern (oder löschen)
   string file    = GetLocalConfigPath();
   string section = "WindowStatus";
      int hWnd    = WindowHandle(Symbol(), NULL); if (!hWnd) hWnd = __WND_HANDLE;
      if (!hWnd) return(!catch("StoreWindowStatus(1)->WindowHandle() = 0 in context "+ ModuleTypeDescription(__TYPE__) +"::"+ __whereamiDescription(__WHEREAMI__), ERR_RUNTIME_ERROR));
   string key     = "TrackSignal.0x"+ IntToHexStr(hWnd);
   if (mode.extern) {
      if (!WritePrivateProfileStringA(section, key, value, file)) return(!catch("StoreWindowStatus(2)->kernel32::WritePrivateProfileStringA(section=\""+ section +"\", key=\""+ key +"\", value=\""+ value +"\", fileName=\""+ file +"\")", ERR_WIN32_ERROR));
   }
   else if (!DeleteIniKey(file, section, key))                    return(!SetLastError(stdlib.GetLastError()));

   return(!catch("StoreWindowStatus(3)"));
}


/**
 * Restauriert die Fenster-relevanten Konfigurationsdaten aus dem Chart oder der Terminalkonfiguration.
 *
 *  - SignalTracking
 *
 * @return bool - Erfolgsstatus
 */
bool RestoreWindowStatus() {
   // (1) Signaltracking
   bool restoreSignal.success = false;
   // Versuchen, die Konfiguration aus dem Chart zu restaurieren (kann nach Laden eines neuen Templates fehlschlagen).
   string label = __NAME__ +".sticky.TrackSignal", empty="";
   if (ObjectFind(label) == 0) {
      string signal = ObjectDescription(label);
      restoreSignal.success = (signal=="" || ParseSignal(signal, empty, empty));
   }
   // Bei Mißerfolg Konfiguration aus der Terminalkonfiguration restaurieren.
   if (!restoreSignal.success) {
      int hWnd = WindowHandle(Symbol(), NULL); if (!hWnd) hWnd = __WND_HANDLE;
      if (hWnd != 0) {
         string section = "WindowStatus";
         string key     = "TrackSignal.0x"+ IntToHexStr(hWnd);
         signal = GetLocalConfigString(section, key, "");
         restoreSignal.success = (signal=="" || ParseSignal(signal, empty, empty));
      }
   }
   if (restoreSignal.success)
      TrackSignal(signal);

   return(!catch("RestoreWindowStatus(1)"));
}


/**
 * Parst einen Signalbezeichner.
 *
 * @param  string  value    - zu parsender String
 * @param  string &provider - Zeiger auf Variable zur Aufnahme des Signalproviders
 * @param  string &signal   - Zeiger auf Variable zur Aufnahme des Signalnamens
 *
 * @return bool - TRUE, wenn der Bezeichner ein bekanntes Signal darstellt;
 *                FALSE andererseits
 */
bool ParseSignal(string value, string &provider, string &signal) {
   value = StringToLower(value);

   if      (value == "simpletrader.alexprofit"  ) { provider="simpletrader"; signal="alexprofit"  ; }
   if      (value == "simpletrader.asta"        ) { provider="simpletrader"; signal="asta"        ; }
   else if (value == "simpletrader.caesar2"     ) { provider="simpletrader"; signal="caesar2"     ; }
   else if (value == "simpletrader.caesar21"    ) { provider="simpletrader"; signal="caesar21"    ; }
   else if (value == "simpletrader.dayfox"      ) { provider="simpletrader"; signal="dayfox"      ; }
   else if (value == "simpletrader.fxviper"     ) { provider="simpletrader"; signal="fxviper"     ; }
   else if (value == "simpletrader.goldstar"    ) { provider="simpletrader"; signal="goldstar"    ; }
   else if (value == "simpletrader.smartscalper") { provider="simpletrader"; signal="smartscalper"; }
   else if (value == "simpletrader.smarttrader" ) { provider="simpletrader"; signal="smarttrader" ; }
   else if (value == "simpletrader.yenfortress" ) { provider="simpletrader"; signal="yenfortress" ; }
   else {
      return(false);
   }
   return(true);
}


/**
 * Liest die externen offenen und geschlossenen Positionen des aktiven Signals ein. Die Positionen sind bereits sortiert gespeichert und müssen nicht
 * nochmal sortiert werden.
 *
 * @param  string provider - Signalprovider
 * @param  string signal   - Signal
 *
 * @return int - Anzahl der gelesenen Positionen oder -1 (EMPTY), falls ein Fehler auftrat
 */
int ReadExternalPositions(string provider, string signal) {
   // (1.1) offene Positionen: alle Schlüssel einlesen
   string mqlDir  = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string file    = TerminalPath() + mqlDir +"\\files\\"+ provider +"\\"+ signal +"_open.ini";
      if (!IsFile(file)) return(_EMPTY(catch("ReadExternalPositions(1)   file not found \""+ file +"\"", ERR_RUNTIME_ERROR)));
   string section = provider +"."+ signal;
   string keys[], symbol = StdSymbol();
   int keysSize = GetIniKeys(file, section, keys);

   ArrayResize(external.open.ticket    , 0);
   ArrayResize(external.open.type      , 0);
   ArrayResize(external.open.lots      , 0);
   ArrayResize(external.open.openTime  , 0);
   ArrayResize(external.open.openPrice , 0);
   ArrayResize(external.open.takeProfit, 0);
   ArrayResize(external.open.stopLoss  , 0);
   ArrayResize(external.open.commission, 0);
   ArrayResize(external.open.swap      , 0);
   ArrayResize(external.open.profit    , 0);

   // (1.2) Schlüssel gegen aktuelles Symbol prüfen und Positionen einlesen
   for (int i=0; i < keysSize; i++) {
      string key = keys[i];
      if (StringStartsWith(key, symbol +".")) {

         // (1.2.1) Zeile lesen
         string value = GetIniString(file, section, key, "");
         if (!StringLen(value))                       return(_EMPTY(catch("ReadExternalPositions(2)   invalid ini entry ["+ section +"]->"+ key +" in \""+ file +"\" (empty)", ERR_RUNTIME_ERROR)));

         // (1.2.2) Positionsdaten validieren
         //Symbol.Ticket = Type, Lots, OpenTime, OpenPrice, TakeProfit, StopLoss, Commission, Swap, MagicNumber, Comment
         string sValue, values[];
         if (Explode(value, ",", values, NULL) != 10) return(_EMPTY(catch("ReadExternalPositions(3)   invalid position entry ("+ ArraySize(values) +" substrings) ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // Ticket
         sValue = StringRight(key, -StringLen(symbol));
         if (StringGetChar(sValue, 0) != '.')         return(_EMPTY(catch("ReadExternalPositions(4)   invalid ticket \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         sValue = StringSubstr(sValue, 1);
         if (!StringIsDigit(sValue))                  return(_EMPTY(catch("ReadExternalPositions(5)   invalid ticket \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         int _ticket = StrToInteger(sValue);
         if (_ticket <= 0)                            return(_EMPTY(catch("ReadExternalPositions(6)   invalid ticket \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // Type
         sValue = StringTrim(values[0]);
         int _type = StrToOperationType(sValue);
         if (!IsTradeOperation(_type))                return(_EMPTY(catch("ReadExternalPositions(7)   invalid order type \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // Lots
         sValue = StringTrim(values[1]);
         if (!StringIsNumeric(sValue))                return(_EMPTY(catch("ReadExternalPositions(8)   invalid lot size \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         double _lots = StrToDouble(sValue);
         if (_lots <= 0)                              return(_EMPTY(catch("ReadExternalPositions(9)   invalid lot size \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _lots = NormalizeDouble(_lots, 2);

         // OpenTime
         sValue = StringTrim(values[2]);
         datetime _openTime = StrToTime(sValue);
         if (!_openTime)                              return(_EMPTY(catch("ReadExternalPositions(10)   invalid open time \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // OpenPrice
         sValue = StringTrim(values[3]);
         if (!StringIsNumeric(sValue))                return(_EMPTY(catch("ReadExternalPositions(11)   invalid open price \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         double _openPrice = StrToDouble(sValue);
         if (_openPrice <= 0)                         return(_EMPTY(catch("ReadExternalPositions(12)   invalid open price \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _openPrice = NormalizeDouble(_openPrice, Digits);

         // TakeProfit
         sValue = StringTrim(values[4]);
         double _takeProfit = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(13)   invalid takeprofit \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _takeProfit = StrToDouble(sValue);
            if (_takeProfit < 0)                      return(_EMPTY(catch("ReadExternalPositions(14)   invalid takeprofit \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _takeProfit = NormalizeDouble(_takeProfit, Digits);
         }

         // StopLoss
         sValue = StringTrim(values[5]);
         double _stopLoss = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(15)   invalid stoploss \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _stopLoss = StrToDouble(sValue);
            if (_stopLoss < 0)                        return(_EMPTY(catch("ReadExternalPositions(16)   invalid stoploss \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _stopLoss = NormalizeDouble(_stopLoss, Digits);
         }

         // Commission
         sValue = StringTrim(values[6]);
         double _commission = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(17)   invalid commission value \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _commission = NormalizeDouble(StrToDouble(sValue), 2);
         }

         // Swap
         sValue = StringTrim(values[7]);
         double _swap = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(18)   invalid swap value \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _swap = NormalizeDouble(StrToDouble(sValue), 2);
         }

         // MagicNumber: vorerst nicht benötigt
         // Comment:     vorerst nicht benötigt

         // (1.2.3) Position in die globalen Arrays schreiben (erst nach vollständiger erfolgreicher Validierung)
         int size=ArraySize(external.open.ticket), newSize=size+1;
         ArrayResize(external.open.ticket    , newSize);
         ArrayResize(external.open.type      , newSize);
         ArrayResize(external.open.lots      , newSize);
         ArrayResize(external.open.openTime  , newSize);
         ArrayResize(external.open.openPrice , newSize);
         ArrayResize(external.open.takeProfit, newSize);
         ArrayResize(external.open.stopLoss  , newSize);
         ArrayResize(external.open.commission, newSize);
         ArrayResize(external.open.swap      , newSize);
         ArrayResize(external.open.profit    , newSize);

         external.open.ticket    [size] = _ticket;
         external.open.type      [size] = _type;
         external.open.lots      [size] = _lots;
         external.open.openTime  [size] = _openTime;
         external.open.openPrice [size] = _openPrice;
         external.open.takeProfit[size] = _takeProfit;
         external.open.stopLoss  [size] = _stopLoss;
         external.open.commission[size] = _commission;
         external.open.swap      [size] = _swap;
         external.open.profit    [size] = ifDouble(_type==OP_LONG, Bid-_openPrice, _openPrice-Ask)/Pips * PipValue(_lots, true);   // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
      }
   }


   // (2.1) geschlossene Positionen: alle Schlüssel einlesen
   file = TerminalPath() + mqlDir +"\\files\\"+ provider +"\\"+ signal +"_closed.ini";
      if (!IsFile(file)) return(_EMPTY(catch("ReadExternalPositions(19)   file not found \""+ file +"\"", ERR_RUNTIME_ERROR)));
   section  = provider +"."+ signal;
   keysSize = GetIniKeys(file, section, keys);

   ArrayResize(external.closed.ticket    , 0);
   ArrayResize(external.closed.type      , 0);
   ArrayResize(external.closed.lots      , 0);
   ArrayResize(external.closed.openTime  , 0);
   ArrayResize(external.closed.openPrice , 0);
   ArrayResize(external.closed.closeTime , 0);
   ArrayResize(external.closed.closePrice, 0);
   ArrayResize(external.closed.takeProfit, 0);
   ArrayResize(external.closed.stopLoss  , 0);
   ArrayResize(external.closed.commission, 0);
   ArrayResize(external.closed.swap      , 0);
   ArrayResize(external.closed.profit    , 0);

   // (2.2) Schlüssel gegen aktuelles Symbol prüfen und Positionen einlesen
   for (i=0; i < keysSize; i++) {
      key = keys[i];
      if (StringStartsWith(key, symbol +".")) {
         // (2.2.1) Zeile lesen
         value = GetIniString(file, section, key, "");
         if (!StringLen(value))                       return(_EMPTY(catch("ReadExternalPositions(20)   invalid ini entry ["+ section +"]->"+ key +" in \""+ file +"\" (empty)", ERR_RUNTIME_ERROR)));

         // (2.2.2) Positionsdaten validieren
         //Symbol.Ticket = Type, Lots, OpenTime, OpenPrice, CloseTime, ClosePrice, TakeProfit, StopLoss, Commission, Swap, Profit, MagicNumber, Comment
         if (Explode(value, ",", values, NULL) != 13) return(_EMPTY(catch("ReadExternalPositions(21)   invalid position entry ("+ ArraySize(values) +" substrings) ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // Ticket
         sValue = StringRight(key, -StringLen(symbol));
         if (StringGetChar(sValue, 0) != '.')         return(_EMPTY(catch("ReadExternalPositions(22)   invalid ticket \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         sValue = StringSubstr(sValue, 1);
         if (!StringIsDigit(sValue))                  return(_EMPTY(catch("ReadExternalPositions(23)   invalid ticket \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _ticket = StrToInteger(sValue);
         if (_ticket <= 0)                            return(_EMPTY(catch("ReadExternalPositions(24)   invalid ticket \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // Type
         sValue = StringTrim(values[0]);
         _type  = StrToOperationType(sValue);
         if (!IsTradeOperation(_type))                return(_EMPTY(catch("ReadExternalPositions(25)   invalid order type \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // Lots
         sValue = StringTrim(values[1]);
         if (!StringIsNumeric(sValue))                return(_EMPTY(catch("ReadExternalPositions(26)   invalid lot size \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _lots = StrToDouble(sValue);
         if (_lots <= 0)                              return(_EMPTY(catch("ReadExternalPositions(27)   invalid lot size \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _lots = NormalizeDouble(_lots, 2);

         // OpenTime
         sValue    = StringTrim(values[2]);
         _openTime = StrToTime(sValue);
         if (!_openTime)                              return(_EMPTY(catch("ReadExternalPositions(28)   invalid open time \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // OpenPrice
         sValue = StringTrim(values[3]);
         if (!StringIsNumeric(sValue))                return(_EMPTY(catch("ReadExternalPositions(29)   invalid open price \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _openPrice = StrToDouble(sValue);
         if (_openPrice <= 0)                         return(_EMPTY(catch("ReadExternalPositions(30)   invalid open price \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _openPrice = NormalizeDouble(_openPrice, Digits);

         // CloseTime
         sValue = StringTrim(values[4]);
         datetime _closeTime = StrToTime(sValue);
         if (!_closeTime)                             return(_EMPTY(catch("ReadExternalPositions(31)   invalid open time \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // ClosePrice
         sValue = StringTrim(values[5]);
         if (!StringIsNumeric(sValue))                return(_EMPTY(catch("ReadExternalPositions(32)   invalid open price \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         double _closePrice = StrToDouble(sValue);
         if (_closePrice <= 0)                        return(_EMPTY(catch("ReadExternalPositions(33)   invalid open price \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _closePrice = NormalizeDouble(_closePrice, Digits);

         // TakeProfit
         sValue      = StringTrim(values[6]);
         _takeProfit = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(34)   invalid takeprofit \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _takeProfit = StrToDouble(sValue);
            if (_takeProfit < 0)                      return(_EMPTY(catch("ReadExternalPositions(35)   invalid takeprofit \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _takeProfit = NormalizeDouble(_takeProfit, Digits);
         }

         // StopLoss
         sValue    = StringTrim(values[7]);
         _stopLoss = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(36)   invalid stoploss \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _stopLoss = StrToDouble(sValue);
            if (_stopLoss < 0)                        return(_EMPTY(catch("ReadExternalPositions(37)   invalid stoploss \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _stopLoss = NormalizeDouble(_stopLoss, Digits);
         }

         // Commission
         sValue      = StringTrim(values[8]);
         _commission = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(38)   invalid commission value \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _commission = NormalizeDouble(StrToDouble(sValue), 2);
         }

         // Swap
         sValue = StringTrim(values[9]);
         _swap  = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(39)   invalid swap value \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _swap = NormalizeDouble(StrToDouble(sValue), 2);
         }

         // Profit
         sValue = StringTrim(values[10]);
         if (sValue == "")                            return(_EMPTY(catch("ReadExternalPositions(40)   invalid profit value \"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         if (!StringIsNumeric(sValue))                return(_EMPTY(catch("ReadExternalPositions(41)   invalid profit value \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         double _profit = NormalizeDouble(StrToDouble(sValue), 2);

         // MagicNumber: vorerst nicht benötigt
         // Comment:     vorerst nicht benötigt

         // (2.2.3) Position in die globalen Arrays schreiben (erst nach vollständiger erfolgreicher Validierung)
         size=ArraySize(external.closed.ticket); newSize=size+1;
         ArrayResize(external.closed.ticket    , newSize);
         ArrayResize(external.closed.type      , newSize);
         ArrayResize(external.closed.lots      , newSize);
         ArrayResize(external.closed.openTime  , newSize);
         ArrayResize(external.closed.openPrice , newSize);
         ArrayResize(external.closed.closeTime , newSize);
         ArrayResize(external.closed.closePrice, newSize);
         ArrayResize(external.closed.takeProfit, newSize);
         ArrayResize(external.closed.stopLoss  , newSize);
         ArrayResize(external.closed.commission, newSize);
         ArrayResize(external.closed.swap      , newSize);
         ArrayResize(external.closed.profit    , newSize);

         external.closed.ticket    [size] = _ticket;
         external.closed.type      [size] = _type;
         external.closed.lots      [size] = _lots;
         external.closed.openTime  [size] = _openTime;
         external.closed.openPrice [size] = _openPrice;
         external.closed.closeTime [size] = _closeTime;
         external.closed.closePrice[size] = _closePrice;
         external.closed.takeProfit[size] = _takeProfit;
         external.closed.stopLoss  [size] = _stopLoss;
         external.closed.commission[size] = _commission;
         external.closed.swap      [size] = _swap;
         external.closed.profit    [size] = _profit;
      }
   }


   ArrayResize(keys,   0);
   ArrayResize(values, 0);
   if (!catch("ReadExternalPositions(42)"))
      return(ArraySize(external.open.ticket) + ArraySize(external.closed.ticket));
   return(-1);
}


/**
 * Lädt die Konfigurationsdatei des aktuellen Accounts in den Editor.
 *
 * @return bool - Erfolgsstatus
 */
bool EditAccountConfig() {
   string mqlDir   = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string file     = TerminalPath() + mqlDir +"\\files\\";
      if      (mode.intern) file = file + ShortAccountCompany() +"\\"+ GetAccountNumber() +"_config.ini";
      else if (mode.extern) file = file + external.provider     +"\\"+ external.signal    +"_config.ini";
      else if (mode.remote) file = file +"LiteForex\\remote_positions.ini";
      else return(!catch("EditAccountConfig(1)", ERR_WRONG_JUMP));

   if (!EditFile(file))
      return(!SetLastError(stdlib.GetLastError()));
}


/**
 * String-Repräsentation der Input-Parameter fürs Logging bei Aufruf durch iCustom().
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()   config: ",                     // 'config' statt 'inputs', da die Laufzeitparameter extern konfiguriert werden

                            "appliedPrice=",                PriceTypeToStr(appliedPrice), "; ")
   );
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   bool     AquireLock(string mutexName, bool wait);
   int      ArrayInsertDoubles(double array[], int offset, double values[]);
   int      ArrayPushDouble(double array[], double value);
   string   BoolToStr(bool value);
   string   DateToStr(datetime time, string mask);
   bool     DeleteIniKey(string file, string section, string key);
   int      DeleteRegisteredObjects(string prefix);
   bool     EditFile(string filename);
   datetime FxtToServerTime(datetime fxtTime);
   double   GetCommission();
   string   GetConfigString(string section, string key, string defaultValue);
   double   GetGlobalConfigDouble(string section, string key, double defaultValue);
   double   GetIniDouble(string fileName, string section, string key, double defaultValue);
   string   GetLocalConfigPath();
   string   GetLongSymbolNameOrAlt(string symbol, string altValue);
   datetime GetPrevSessionStartTime.srv(datetime serverTime);
   string   GetRawIniString(string file, string section, string key, string defaultValue);
   datetime GetSessionStartTime.srv(datetime serverTime);
   string   GetSymbolName(string symbol);
   int      GetTerminalBuild();
   int      iBarShiftNext(string symbol, int period, datetime time);
   int      iBarShiftPrevious(string symbol, int period, datetime time);
   bool     IsCurrency(string value);
   bool     IsFile(string filename);
   bool     IsGlobalConfigKey(string section, string key);
   double   MathModFix(double a, double b);
   int      ObjectRegister(string label);
   bool     ChartMarker.OrderSent_A(int ticket, int digits, color markerColor);
   string   PriceTypeToStr(int type);
   bool     ReleaseLock(string mutexName);
   int      SearchStringArrayI(string haystack[], string needle);
   string   ShortAccountCompany();
   bool     StringEndsWith(string object, string postfix);
   bool     StringIEndsWith(string object, string postfix);
   string   StringSubstrFix(string object, int start, int length);
   string   StringToUpper(string value);
   string   UninitializeReasonToStr(int reason);

#import "stdlib2.ex4"
   int      ArrayInsertDoubleArray(double array[][], int offset, double values[]);
   int      ChartInfos.CopyLfxStatus(bool direction, /*LFX_ORDER*/int orders[][], int iVolatile[][], double dVolatile[][]);
   bool     SortClosedTickets(int keys[][]);
   bool     SortOpenTickets(int keys[][]);

   string   DoublesToStr(double array[], string separator);
   string   StringsToStr(string array[], string separator);
#import
