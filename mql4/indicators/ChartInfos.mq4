/**
 * Zeigt im Chart verschiedene Informationen zum aktuellen Instrument und zu Positionen eines der folgenden Typen an:
 *
 * (1) interne Positionen: - Positionen, die im aktuellen Account des Terminals gehalten werden
 *                         - Order- und P/L-Daten stammen vom Terminal
 *
 * (2) externe Positionen: - Positionen, die in einem externen Account gehalten werden (z.B. in SimpleTrader-Accounts)
 *                         - Orderdaten stammen aus einer externen Quelle
 *                         - P/L-Daten werden anhand der aktuellen Kurse des Terminals selbst berechnet
 *
 * (3) Remote-Positionen:  - Positionen, die in einem anderen Account gehalten werden (in der Regel synthetische Positionen)
 *                         - Orderdaten stammen aus einer externen Quelle
 *                         - P/L-Daten stammen ebenfalls aus einer externen Quelle
 *                         - Orderlimits können überwacht und die externe Quelle bei Erreichen benachrichtigt werden
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_TIMEZONE };
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern bool CustomPositions.AbsoluteAmounts = true;               // ob die Einzelpositionsanzeige auch absolute Beträge beinhaltet oder nur prozentuale Werte anzeigt
extern bool CustomPositions.LogTickets      = false;              // ob die Tickets der Einzelpositionsanzeige geloggt werden sollen
extern bool Offline.Ticker                  = true;               // ob der Ticker in Offline-Charts standardmäßig aktiviert wird

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>

#include <MT4iQuickChannel.mqh>
#include <win32api.mqh>

#include <core/script.ParameterProvider.mqh>
#include <iFunctions/@ATR.mqh>
#include <iFunctions/iBarShiftNext.mqh>
#include <iFunctions/iBarShiftPrevious.mqh>
#include <account/functions.mqh>
#include <account/quickchannel.mqh>
#include <structs/pewa/LFX_ORDER.mqh>


// Typ der Kursanzeige
int appliedPrice = PRICE_MEDIAN;                                  // Preis: Bid | Ask | Median (default)


// Moneymanagement
#define STANDARD_VOLATILITY  10                                   // Standard-Volatilität einer Unit in Prozent Equity je Woche (willkürlich gewählt)

double mm.realEquity;                                             // real verwendeter Equity-Betrag; nicht der vom Broker berechnete = AccountEquity()
                                                                  //  - enthält externe Assets                                                           !!! doppelte Spreads und      !!!
                                                                  //  - enthält offene Gewinne/Verluste gehedgter Positionen (gehedgt = realisiert)      !!! Commissions herausrechnen !!!
                                                                  //  - enthält offene Verluste ungehedgter Positionen
                                                                  //  - enthält NICHT offene Gewinne ungehedgter Positionen (ungehedgt = unrealisiert)

double mm.lotValue;                                               // Value eines Lots in Account-Currency
double mm.unleveragedLots;                                        // Lotsize bei Hebel von 1:1

double mm.defaultVola;
double mm.defaultLeverage;
double mm.defaultLots;                                            // Default-UnitSize: exakter Wert
double mm.defaultLots.normalized;                                 //                   auf MODE_LOTSTEP normalisierter Wert

double mm.ATRwAbs;                                                // wöchentliche ATR: absoluter Wert
double mm.ATRwPct;                                                // wöchentliche ATR: prozentualer Wert

double mm.stdVola = STANDARD_VOLATILITY;                          // Standard-Volatilität einer Unit in Prozent je Woche (kann per Konfiguration überschrieben werden)
double mm.stdLeverage;                                            // Hebel für Standard-Volatilität
double mm.stdLots;                                                // resultierende Lotsize

double mm.customVola;                                             // benutzerdefinierte Volatilität einer Unit in Prozent je Woche
double mm.customLeverage;                                         // benutzerdefinierter Hebel
double mm.customLots;                                             // resultierende Lotsize

bool   mm.isCustomUnitSize;                                       // ob die Default-UnitSize (mm.defaultLots) nach Std.-Werten oder benutzerdefiniert berechnet wird
bool   mm.ready;                                                  // Flag

double aum.value;                                                 // zusätzliche extern gehaltene bei Equity-Berechnungen zu berücksichtigende Assets


// Konfiguration individueller Positionen
#define POSITION_CONFIG_TERM.size        40
#define POSITION_CONFIG_TERM.doubleSize   5

double positions.config[][POSITION_CONFIG_TERM.doubleSize];       // geparste Konfiguration, Format siehe CustomPositions.ReadConfig()
string positions.config.comments[];                               // Kommentare konfigurierter Positionen (Größe entspricht der Anzahl der konfigurierten Positionen)

#define TERM_OPEN_LONG                  1                         // ConfigTerm-Types
#define TERM_OPEN_SHORT                 2
#define TERM_OPEN_SYMBOL                3
#define TERM_OPEN_ALL                   4
#define TERM_HISTORY_SYMBOL             5
#define TERM_HISTORY_ALL                6
#define TERM_ADJUSTMENT                 7
#define TERM_EQUITY                     8


// interne + externe Positionsdaten
bool   isPosition;                                                // ob offene Positionen existieren = (longPosition || shortPosition);   // die Gesamtposition kann flat sein
double totalPosition;
double longPosition;
double shortPosition;
int    positions.idata[][3];                                      // Positionsdetails: [ConfigType, PositionType, CommentIndex]
double positions.ddata[][9];                                      //                   [DirectionalLots, HedgedLots, BreakevenPrice|PipDistance, OpenProfit, ClosedProfit, AdjustedProfit, FullProfitAbsolut, FullProfitPercent]
bool   positionsAnalyzed;

#define CONFIG_AUTO                     0                         // ConfigTypes:      normale unkonfigurierte offene Position (intern oder extern)
#define CONFIG_REAL                     1                         //                   individuell konfigurierte reale Position
#define CONFIG_VIRTUAL                  2                         //                   individuell konfigurierte virtuelle Position

#define POSITION_LONG                   1                         // PositionTypes
#define POSITION_SHORT                  2                         // (werden in typeDescriptions[] als Arrayindizes benutzt)
#define POSITION_HEDGE                  3
#define POSITION_HISTORY                4
string  typeDescriptions[] = {"", "Long:", "Short:", "Hedge:", "History:"};

#define I_CONFIG_TYPE                   0                         // Arrayindizes von positions.idata[]
#define I_POSITION_TYPE                 1
#define I_COMMENT_INDEX                 2

#define I_DIRECTIONAL_LOTS              0                         // Arrayindizes von positions.ddata[]
#define I_HEDGED_LOTS                   1
#define I_BREAKEVEN_PRICE               2
#define I_PIP_DISTANCE  I_BREAKEVEN_PRICE
#define I_OPEN_EQUITY                   3
#define I_OPEN_PROFIT                   4
#define I_CLOSED_PROFIT                 5
#define I_ADJUSTED_PROFIT               6
#define I_FULL_PROFIT_ABS               7
#define I_FULL_PROFIT_PCT               8


// externe Positionen
string   external.signalProvider = "";          // simpletrader
string   external.signalName     = "";          // FX Viper
string   external.signalAlias    = "";          // fxviper
int      external.signalId       = -1;          // 1234

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
int    lfxOrders.ivolatile[][3];                                  // veränderliche Positionsdaten: = {Ticket, IsOpen, IsLocked}
double lfxOrders.dvolatile[][1];                                  //                               = {Profit}
int    lfxOrders.openPositions;                                   // Anzahl der offenen Positionen in den offenen Orders (IsOpen = 1)

#define I_TICKET           0                                      // Arrayindizes von lfxOrders.~volatile[]
#define I_ISOPEN           1
#define I_ISLOCKED         2
#define I_VPROFIT          0


// Textlabel für die einzelnen Anzeigen
string label.instrument      = "${__NAME__}.Instrument";
string label.ohlc            = "${__NAME__}.OHLC";
string label.price           = "${__NAME__}.Price";
string label.spread          = "${__NAME__}.Spread";
string label.aum             = "${__NAME__}.AuM";
string label.position        = "${__NAME__}.Position";
string label.unitSize        = "${__NAME__}.UnitSize";
string label.orderCounter    = "${__NAME__}.OrderCounter";
string label.externalAccount = "${__NAME__}.ExternalAccount";
string label.lfxTradeAccount = "${__NAME__}.LfxTradeAccount";
string label.stopoutLevel    = "${__NAME__}.StopoutLevel";
string label.time            = "${__NAME__}.Time";


// Font-Settings der CustomPositions-Anzeige
string positions.fontName          = "MS Sans Serif";
int    positions.fontSize          = 8;

color  positions.fontColor.intern  = Blue;
color  positions.fontColor.extern  = Red;
color  positions.fontColor.remote  = Blue;
color  positions.fontColor.virtual = Green;
color  positions.fontColor.history = C'128,128,0';


// Farben für Orderanzeige
#define CLR_PENDING_OPEN         DeepSkyBlue
#define CLR_OPEN_LONG            C'0,0,254'                       // Blue - rgb(1,1,1)
#define CLR_OPEN_SHORT           C'254,0,0'                       // Red  - rgb(1,1,1)
#define CLR_OPEN_TAKEPROFIT      LimeGreen
#define CLR_OPEN_STOPLOSS        Red
#define CLR_CLOSED_LONG          Blue
#define CLR_CLOSED_SHORT         Red
#define CLR_CLOSE                Orange


int tickTimerId;                                                  // ID eines ggf.installierten OfflineTickers


#include <ChartInfos/init.mqh>
#include <ChartInfos/deinit.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   mm.ready          = false;
   positionsAnalyzed = false;

   HandleEvent(EVENT_CHART_CMD);                                                                   // ChartCommands verarbeiten

   if (!UpdatePrice())                     if (CheckLastError("onTick(1)"))  return(last_error);   // aktualisiert die Kursanzeige oben rechts
   if (!UpdateOHLC())                      if (CheckLastError("onTick(2)"))  return(last_error);   // aktualisiert die OHLC-Anzeige oben links           // TODO: unvollständig

   if (mode.remote) {
      if (!QC.HandleLfxTerminalMessages()) if (CheckLastError("onTick(3)"))  return(last_error);   // Quick-Channel: bei einem LFX-Terminal eingehende Messages verarbeiten
      if (!UpdatePositions())              if (CheckLastError("onTick(4)"))  return(last_error);   // aktualisiert die Positionsanzeigen unten rechts (gesamt) und unten links (detailliert)
      if (!CheckLfxLimits())               if (CheckLastError("onTick(5)"))  return(last_error);   // prüft alle Pending-LFX-Limits und verschickt ggf. entsprechende Trade-Commands
   }
   else {
      if (!QC.HandleTradeCommands())       if (CheckLastError("onTick(6)"))  return(last_error);   // Quick-Channel: bei einem Trade-Terminal eingehende Messages verarbeiten
      if (!UpdateSpread())                 if (CheckLastError("onTick(7)"))  return(last_error);
      if (!UpdateUnitSize())               if (CheckLastError("onTick(8)"))  return(last_error);   // akualisiert die UnitSize-Anzeige unten rechts
      if (!UpdatePositions())              if (CheckLastError("onTick(9)"))  return(last_error);   // aktualisiert die Positionsanzeigen unten rechts (gesamt) und unten links (detailliert)
      if (!UpdateStopoutLevel())           if (CheckLastError("onTick(10)")) return(last_error);   // aktualisiert die Markierung des Stopout-Levels im Chart
      if (!UpdateOrderCounter())           if (CheckLastError("onTick(11)")) return(last_error);   // aktualisiert die Anzeige der Anzahl der offenen Orders
   }

   if (IsVisualModeFix()) {                                                                        // nur im Tester:
      if (!UpdateTime())                   if (CheckLastError("onTick(12)")) return(last_error);   // aktualisiert die Anzeige der Serverzeit unten rechts
   }
   return(last_error);
}


/**
 * Prüft, ob ein Fehler gesetzt ist und gibt eine Warnung aus, wenn das nicht der Fall ist. Zum Debugging in onTick()
 *
 * @param  string location - Ort der Prüfung
 *
 * @return bool - ob ein Fehler gesetzt ist
 */
bool CheckLastError(string location) {
   if (IsLastError())
      return(true);
   //debug(location +"  returned FALSE but set no error");
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
 *                "cmd=EditAccountConfig"      - Lädt die Konfigurationsdatei des aktuellen Accounts in den Editor. Im ChartInfos-Indikator,
 *                                               da der aktuelle Account ein im Indikator definierter externer oder LFX-Account sein kann.
 */
bool onChartCommand(string commands[]) {
   int size = ArraySize(commands);
   if (!size) return(!warn("onChartCommand(1)  empty parameter commands = {}"));

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
      warn("onChartCommand(2)  unknown chart command \""+ commands[i] +"\"");
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
         PlaySoundEx("Plonk.wav");                                   // Plonk!!!
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
            if (ObjectCreate(label1, OBJ_ARROW, 0, TimeCurrentEx("ShowOpenOrders(1)"), openPrice)) {
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
               if (ObjectCreate(label2, OBJ_ARROW, 0, TimeCurrentEx("ShowOpenOrders(2)"), takeProfit)) {
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
               if (ObjectCreate(label3, OBJ_ARROW, 0, TimeCurrentEx("ShowOpenOrders(3)"), stopLoss)) {
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
            sTP    = StringConcatenate("TP: ", NumberToStr(takeProfit, SubPipPriceFormat));
            label2 = StringConcatenate(label1, ",  ", sTP);
            if (ObjectFind(label2) == 0)
               ObjectDelete(label2);
            if (ObjectCreate(label2, OBJ_ARROW, 0, TimeCurrentEx("ShowOpenOrders(4)"), takeProfit)) {
               ObjectSet(label2, OBJPROP_ARROWCODE, SYMBOL_ORDERCLOSE  );
               ObjectSet(label2, OBJPROP_COLOR,     CLR_OPEN_TAKEPROFIT);
            }
         }
         else sTP = "";

         // StopLoss anzeigen
         if (stopLoss != NULL) {
            sSL    = StringConcatenate("SL: ", NumberToStr(stopLoss, SubPipPriceFormat));
            label3 = StringConcatenate(label1, ",  ", sSL);
            if (ObjectFind(label3) == 0)
               ObjectDelete(label3);
            if (ObjectCreate(label3, OBJ_ARROW, 0, TimeCurrentEx("ShowOpenOrders(5)"), stopLoss)) {
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
      return(orders);
   }


   // (3) mode.remote
   if (mode.remote) {
      return(_EMPTY(catch("ShowOpenOrders(6)  feature not implemented for mode.remote=1", ERR_NOT_IMPLEMENTED)));
   }

   return(_EMPTY(catch("ShowOpenOrders(7)  unreachable code reached", ERR_RUNTIME_ERROR)));
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

   return(!catch("SetOpenOrderDisplayStatus(1)"));
}


/**
 * Schaltet die Anzeige der Trade-History ein/aus.
 *
 * @return bool - Erfolgsstatus
 */
bool ToggleTradeHistory() {
   // aktuellen Anzeigestatus aus Chart auslesen und umschalten: ON/OFF
   bool status = !GetTradeHistoryDisplayStatus();

   // neuer Status ON: Trade-History anzeigen
   if (status) {
      int trades = ShowTradeHistory();
      if (trades == -1)
         return(false);
      if (!trades) {                                                 // ohne Trade-History bleiben Anzeige und Status unverändert
         status = false;
         PlaySoundEx("Plonk.wav");                                   // Plonk!!!
      }
   }

   // neuer Status OFF: Chartobjekte der Trade-History löschen
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

   // neuen Anzeigestatus im Chart speichern
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

   return(!catch("SetTradeHistoryDisplayStatus(1)"));
}


/**
 * Zeigt die verfügbare Trade-History an.
 *
 * @return int - Anzahl der angezeigten geschlossenen Positionen oder -1 (EMPTY), falls ein Fehler auftrat.
 */
int ShowTradeHistory() {
   int      orders, ticket, type, markerColors[]={CLR_CLOSED_LONG, CLR_CLOSED_SHORT}, lineColors[]={Blue, Red};
   datetime openTime, closeTime;
   double   lots, openPrice, closePrice;
   string   sOpenPrice, sClosePrice, openLabel, lineLabel, closeLabel, sTypes[]={"buy", "sell"};


   // (1) Anzeigekonfiguration auslesen
   string mqlDir  = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string file    = TerminalPath() + mqlDir +"\\files\\"+ ifString(mode.intern, ShortAccountCompany() +"\\"+ GetAccountNumber(), external.signalProvider +"\\"+ external.signalAlias) +"_config.ini";
   string section = "Charts";
   string key     = "TradeHistory.ConnectOrders";

   bool drawConnectors = GetIniBool(file, section, key, GetLocalConfigBool(section, key, true));  // Terminal- und Account-Konfiguration (default = true)


   // (2) mode.intern
   if (mode.intern) {
      // (2.1) Sortierschlüssel aller geschlossenen Positionen auslesen und nach {CloseTime, OpenTime, Ticket} sortieren
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

      // (2.2) Tickets sortiert einlesen
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

      // (2.3) Hedges korrigieren: alle Daten dem ersten Ticket zuordnen und hedgendes Ticket verwerfen
      for (i=0; i < orders; i++) {
         if (tickets[i] && EQ(lotSizes[i], 0)) {                     // lotSize = 0: Hedge-Position

            // TODO: Prüfen, wie sich OrderComment() bei custom comments verhält.
            if (!StringStartsWithI(comments[i], "close hedge by #"))
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

      // (2.4) Orders anzeigen
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
         if (drawConnectors) {
            lineLabel = StringConcatenate("#", tickets[i], " ", sOpenPrice, " -> ", sClosePrice);
            if (ObjectFind(lineLabel) == 0)
               ObjectDelete(lineLabel);
            if (ObjectCreate(lineLabel, OBJ_TREND, 0, openTimes[i], openPrices[i], closeTimes[i], closePrices[i])) {
               ObjectSet(lineLabel, OBJPROP_RAY  , false               );
               ObjectSet(lineLabel, OBJPROP_STYLE, STYLE_DOT           );
               ObjectSet(lineLabel, OBJPROP_COLOR, lineColors[types[i]]);
               ObjectSet(lineLabel, OBJPROP_BACK , true                );
            }
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


   // (3) mode.extern
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
         if (drawConnectors) {
            lineLabel = StringConcatenate("#", ticket, " ", sOpenPrice, " -> ", sClosePrice);
            if (ObjectFind(lineLabel) == 0)
               ObjectDelete(lineLabel);
            if (ObjectCreate(lineLabel, OBJ_TREND, 0, openTime, openPrice, closeTime, closePrice)) {
               ObjectSet(lineLabel, OBJPROP_RAY  , false           );
               ObjectSet(lineLabel, OBJPROP_STYLE, STYLE_DOT       );
               ObjectSet(lineLabel, OBJPROP_COLOR, lineColors[type]);
               ObjectSet(lineLabel, OBJPROP_BACK , true            );
            }
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


   // (4) mode.remote
   if (mode.remote) {
      return(_EMPTY(catch("ShowTradeHistory(8)  feature not implemented for mode.remote=1", ERR_NOT_IMPLEMENTED)));
   }

   return(_EMPTY(catch("ShowTradeHistory(9)  unreachable code reached", ERR_RUNTIME_ERROR)));

   /*
   script ShowTradeHistory.onStart() [
   /*LFX_ORDER int los[][LFX_ORDER.intSize];
   int orders = LFX.GetOrders(Symbol(), OF_CLOSED, los);

   for (int i=0; i < orders; i++) {
      int      ticket      =                     los.Ticket    (los, i);
      int      type        =                     los.Type      (los, i);
      double   units       =                     los.Units     (los, i);
      datetime openTime    =     GmtToServerTime(los.OpenTime  (los, i));
      double   openPrice   =                     los.OpenPrice (los, i);
      datetime closeTime   = GmtToServerTime(Abs(los.CloseTime (los, i)));
      double   closePrice  =                     los.ClosePrice(los, i);
      double   profit      =                     los.Profit    (los, i);
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
      if (mode.intern) { string companyId = ShortAccountCompany(); string accountId = GetAccountNumber();   }
      else             {        companyId = external.signalProvider;      accountId = external.signalAlias; }

      aum.value = RefreshExternalAssets(companyId, accountId);
      if (IsEmptyValue(aum.value))
         return(false);
      string strAum = " ";

      if (mode.intern) {
         strAum = ifString(!aum.value, "Balance:  ", "Assets:  ") + DoubleToStr(AccountBalance() + aum.value, 2) +" "+ AccountCurrency();
      }
      else if (mode.extern) {
         strAum = "Assets:  " + ifString(!aum.value, "n/a", DoubleToStr(aum.value, 2) +" "+ AccountCurrency());
      }
      else /*mode.remote*/{
         status = false;                                             // not implemented
         PlaySoundEx("Plonk.wav");                                   // Plonk!!!
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

   return(!catch("SetAuMDisplayStatus(1)"));
}


/**
 * Schaltet das Signaltracking um.
 *
 * @param  string signal - das anzuzeigende Signal
 *
 * @return bool - Erfolgsstatus
 */
bool TrackSignal(string signal) {
   bool signalChanged = false;

   if (signal == "") {                                               // Leerstring bedeutet: Signaltracking/mode.extern = OFF
      external.signalProvider = "";
      external.signalAlias    = "";
      external.signalName     = "";
      external.signalId       = -1;

      if (!mode.intern) {
         mode.intern   = true;
         mode.extern   = false;
         mode.remote   = false;
         signalChanged = true;
      }
   }
   else {
      string signalProvider="", signalAlias="";
      if (!ParseSignalStr(signal, signalProvider, signalAlias)) return(_true(warn("TrackSignal(1)  invalid or unknown parameter signal=\""+ signal +"\"")));
      int signalId = SignalId(signal);

      if (!mode.extern || signalProvider!=external.signalProvider || signalAlias!=external.signalAlias) {
         mode.intern = false;
         mode.extern = true;
         mode.remote = false;

         external.signalProvider = signalProvider;
         external.signalAlias    = signalAlias;
         external.signalId       = signalId;
            string mqlDir  = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
            string file    = TerminalPath() + mqlDir +"\\files\\"+ signalProvider +"\\"+ signalAlias +"_config.ini"; if (!IsFile(file)) return(!catch("TrackSignal(2)  file not found \""+ file +"\"", ERR_RUNTIME_ERROR));
            string section = "General";
            string key     = "Name";
            string value   = GetIniString(file, section, key, ""); if (!StringLen(value))                                               return(!catch("TrackSignal(3)  invalid ini entry ["+ section +"]->"+ key +" in \""+ file +"\" (empty value)", ERR_RUNTIME_ERROR));
         external.signalName = value;

         external.open.lots.checked = false;
         if (-1 == ReadExternalPositions(signalProvider, signalAlias))
            return(false);
         signalChanged = true;
      }
   }

   if (signalChanged) {
      ArrayResize(positions.config,          0);
      ArrayResize(positions.config.comments, 0);
      if (!UpdateExternalAccount()) return(false);
         if (mode.intern) { string companyId = ShortAccountCompany(); string accountId = GetAccountNumber();   }
         else             {        companyId = external.signalProvider;      accountId = external.signalAlias; }
      if (IsEmptyValue(RefreshExternalAssets(companyId, accountId))) return(false);
   }
   return(!catch("TrackSignal(4)"));
}


#define LIMIT_NONE        -1
#define LIMIT_ENTRY        1
#define LIMIT_STOPLOSS     2
#define LIMIT_TAKEPROFIT   3


/**
 * Überprüft alle Pending-LFX-Limits: Pending-Open, StopLoss, TakeProfit
 *
 * @return bool - Erfolgsstatus
 */
bool CheckLfxLimits() {
   datetime triggerTime, now.gmt=TimeGMT(); if (!now.gmt) return(false);

   int /*LFX_ORDER*/stored[], orders=ArrayRange(lfxOrders, 0);

   for (int i=0; i < orders; i++) {
      triggerTime = NULL;

      // (1) alle Limite einer Order prüfen
      int result = IsLfxLimitTriggered(i, triggerTime);
      if (!result)              return(false);
      if (result == LIMIT_NONE) continue;

      if (!triggerTime) {
         // (2) ein Limit wurde genau jetzt getriggert
         if (result == LIMIT_ENTRY     ) log("CheckLfxLimits(1)  #"+ los.Ticket(lfxOrders, i) +" "+ OperationTypeToStr(los.Type(lfxOrders, i))      +" at "+ NumberToStr(los.OpenPrice (lfxOrders, i), SubPipPriceFormat) +" triggered (Bid="+ NumberToStr(Bid, PriceFormat) +")");
         if (result == LIMIT_STOPLOSS  ) log("CheckLfxLimits(2)  #"+ los.Ticket(lfxOrders, i) +" StopLoss"  + ifString(los.StopLoss  (lfxOrders, i), " at "+ NumberToStr(los.StopLoss  (lfxOrders, i), SubPipPriceFormat), "") + ifString(los.StopLossValue  (lfxOrders, i)!=EMPTY_VALUE, ifString(los.StopLoss  (lfxOrders, i), " or", "") +" value of "+ DoubleToStr(los.StopLossValue  (lfxOrders, i), 2), "") +" triggered");
         if (result == LIMIT_TAKEPROFIT) log("CheckLfxLimits(3)  #"+ los.Ticket(lfxOrders, i) +" TakeProfit"+ ifString(los.TakeProfit(lfxOrders, i), " at "+ NumberToStr(los.TakeProfit(lfxOrders, i), SubPipPriceFormat), "") + ifString(los.TakeProfitValue(lfxOrders, i)!=EMPTY_VALUE, ifString(los.TakeProfit(lfxOrders, i), " or", "") +" value of "+ DoubleToStr(los.TakeProfitValue(lfxOrders, i), 2), "") +" triggered");

         // Auslösen speichern und TradeCommand verschicken
         if (result==LIMIT_ENTRY)       los.setOpenTriggerTime    (lfxOrders, i, now.gmt);
         else {                         los.setCloseTriggerTime   (lfxOrders, i, now.gmt);
            if (result==LIMIT_STOPLOSS) los.setStopLossTriggered  (lfxOrders, i, true   );
            else                        los.setTakeProfitTriggered(lfxOrders, i, true   );
         }
         if (!LFX.SaveOrder(lfxOrders, i))                                                                              return(false);
         if (!QC.SendTradeCommand("LFX:"+ los.Ticket(lfxOrders, i) + ifString(result==LIMIT_ENTRY, ":open", ":close"))) return(false);
      }
      else if (triggerTime + 30*SECONDS >= now.gmt) {
         // (3) ein Limit war bereits vorher getriggert, auf Ausführungsbestätigung warten
      }
      else {
         // (4) ein Limit war bereits vorher getriggert und die Ausführungsbestätigung ist überfällig
         if (LFX.GetOrder(los.Ticket(lfxOrders, i), stored) != 1)    // aktuell gespeicherte Version der Order holen
            return(!catch("CheckLfxLimits(4)->LFX.GetOrder(ticket="+ los.Ticket(lfxOrders, i) +") => "+ result, ERR_RUNTIME_ERROR));

         // prüfen, ob inzwischen ein Open- bzw. Close-Error gesetzt wurde und ggf. Fehler melden und speichern
         if (result == LIMIT_ENTRY) {
            if (!lo.IsOpenError(stored)) {
               warnSMS("CheckLfxLimits(5)  #"+ los.Ticket(lfxOrders, i) +" missing trade confirmation for triggered "+ OperationTypeToStr(los.Type(lfxOrders, i)) +" at "+ NumberToStr(los.OpenPrice(lfxOrders, i), SubPipPriceFormat));
               los.setOpenTime(lfxOrders, i, -now.gmt);
            }
         }
         else if (!lo.IsCloseError(stored)) {
            if (result == LIMIT_STOPLOSS) warnSMS("CheckLfxLimits(6)  #"+ los.Ticket(lfxOrders, i) +" missing trade confirmation for triggered StopLoss"  + ifString(los.StopLoss  (lfxOrders, i), " at "+ NumberToStr(los.StopLoss  (lfxOrders, i), SubPipPriceFormat), "") + ifString(los.StopLossValue  (lfxOrders, i)!=EMPTY_VALUE, ifString(los.StopLoss  (lfxOrders, i), " or", "") +" value of "+ DoubleToStr(los.StopLossValue  (lfxOrders, i), 2), ""));
            else                          warnSMS("CheckLfxLimits(7)  #"+ los.Ticket(lfxOrders, i) +" missing trade confirmation for triggered TakeProfit"+ ifString(los.TakeProfit(lfxOrders, i), " at "+ NumberToStr(los.TakeProfit(lfxOrders, i), SubPipPriceFormat), "") + ifString(los.TakeProfitValue(lfxOrders, i)!=EMPTY_VALUE, ifString(los.TakeProfit(lfxOrders, i), " or", "") +" value of "+ DoubleToStr(los.TakeProfitValue(lfxOrders, i), 2), ""));
            los.setCloseTime(lfxOrders, i, -now.gmt);
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
            triggerTime = NULL;                        return(_NULL(catch("IsLfxLimitTriggered(1)  data constraint violation in #"+ los.Ticket(lfxOrders, i) +": closeTriggerTime="+ los.CloseTriggerTime(lfxOrders, i) +", slTriggered=0, tpTriggered=0", ERR_RUNTIME_ERROR)));
         }
         break;

      default:
         return(LIMIT_NONE);
   }

   switch (type) {
      case OP_BUYLIMIT:
      case OP_SELLSTOP:
         if (LE(Bid, los.OpenPrice(lfxOrders, i))) return(LIMIT_ENTRY);
                                                   return(LIMIT_NONE );
      case OP_SELLLIMIT:
      case OP_BUYSTOP  :
         if (GE(Bid, los.OpenPrice(lfxOrders, i))) return(LIMIT_ENTRY);
                                                   return(LIMIT_NONE );
      default:
         slPrice = los.StopLoss       (lfxOrders, i);
         slValue = los.StopLossValue  (lfxOrders, i);
         tpPrice = los.TakeProfit     (lfxOrders, i);
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

   return(_NULL(catch("IsLfxLimitTriggered(2)  unreachable code reached", ERR_RUNTIME_ERROR)));
}


/**
 * Erzeugt die einzelnen ChartInfo-Label.
 *
 * @return bool - Erfolgsstatus
 */
bool CreateLabels() {
   // Label definieren
   label.instrument      = StringReplace(label.instrument     , "${__NAME__}", __NAME__);
   label.ohlc            = StringReplace(label.ohlc           , "${__NAME__}", __NAME__);
   label.price           = StringReplace(label.price          , "${__NAME__}", __NAME__);
   label.spread          = StringReplace(label.spread         , "${__NAME__}", __NAME__);
   label.aum             = StringReplace(label.aum            , "${__NAME__}", __NAME__);
   label.position        = StringReplace(label.position       , "${__NAME__}", __NAME__);
   label.unitSize        = StringReplace(label.unitSize       , "${__NAME__}", __NAME__);
   label.orderCounter    = StringReplace(label.orderCounter   , "${__NAME__}", __NAME__);
   label.externalAccount = StringReplace(label.externalAccount, "${__NAME__}", __NAME__);
   label.lfxTradeAccount = StringReplace(label.lfxTradeAccount, "${__NAME__}", __NAME__);
   label.time            = StringReplace(label.time           , "${__NAME__}", __NAME__);
   label.stopoutLevel    = StringReplace(label.stopoutLevel   , "${__NAME__}", __NAME__);


   // Instrument-Label: Anzeige wird sofort (und nur) hier gesetzt
   int build = GetTerminalBuild();
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
      if      (StringEndsWithI(Symbol(), "_ask")) name = StringConcatenate(name, " (Ask)");
      else if (StringEndsWithI(Symbol(), "_avg")) name = StringConcatenate(name, " (Avg)");
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


   // OrderCounter-Label
   if (ObjectFind(label.orderCounter) == 0)
      ObjectDelete(label.orderCounter);
   if (ObjectCreate(label.orderCounter, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label.orderCounter, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
      ObjectSet    (label.orderCounter, OBJPROP_XDISTANCE, 380);
      ObjectSet    (label.orderCounter, OBJPROP_YDISTANCE,   9);
      ObjectSetText(label.orderCounter, " ", 1);
      ObjectRegister(label.orderCounter);
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


   // Time-Label: nur im Tester bei VisualMode=On
   if (IsVisualModeFix()) {
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
 * Aktualisiert die Kursanzeige oben rechts.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdatePrice() {
   static string priceFormat;
   if (!StringLen(priceFormat))
      priceFormat = StringConcatenate(",,", PriceFormat);

   double price;

   if (!Bid) {                                                                // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
      price = RoundEx(Close[0], Digits);                                      // Bar-Daten in der History können u.U. unnormalisiert sein
   }                                                                          // (z.B. wenn sie nicht von MetaTrader erstellt wurden)
   else {
      switch (appliedPrice) {
         case PRICE_BID   : price =  Bid;                                   break;
         case PRICE_ASK   : price =  Ask;                                   break;
         case PRICE_MEDIAN: price = NormalizeDouble((Bid + Ask)/2, Digits); break;
      }
   }
   ObjectSetText(label.price, NumberToStr(price, priceFormat), 13, "Microsoft Sans Serif", Black);

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                            // bei offenem Properties-Dialog oder Object::onDrag()
      return(true);
   return(!catch("UpdatePrice(1)", error));
}


/**
 * Aktualisiert die Spreadanzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateSpread() {
   if (!Bid)                                                                  // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
      return(true);

   string strSpread = DoubleToStr(MarketInfo(Symbol(), MODE_SPREAD)/PipPoints, Digits & 1);

   ObjectSetText(label.spread, strSpread, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                            // bei offenem Properties-Dialog oder Object::onDrag()
      return(true);
   return(!catch("UpdateSpread(1)", error));
}


/**
 * Aktualisiert die UnitSize-Anzeige unten rechts.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateUnitSize() {
   if (IsTesting())                                    return(true);          // Anzeige wird im Tester nicht benötigt
   if (!mm.ready) /*&&*/ if (!UpdateMoneyManagement()) return(_false(CheckLastError("UpdateUnitSize(1)->UpdateMoneyManagement()")));
   if (!mm.ready)                                      return(true);

   string strUnitSize;

   // Anzeige nur bei internem Account:              V - Volatilität/Woche                      L - Leverage                                     Unitsize
   if (mode.intern) strUnitSize = StringConcatenate("V", DoubleToStr(mm.defaultVola, 1), "%     L", DoubleToStr(mm.defaultLeverage, 1), "  =  ", NumberToStr(mm.defaultLots.normalized, ", .+"), " lot");
   else             strUnitSize = "";

   // Anzeige aktualisieren (!!! max. 63 Zeichen !!!)
   ObjectSetText(label.unitSize, strUnitSize, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                            // bei offenem Properties-Dialog oder Object::onDrag()
      return(true);
   return(!catch("UpdateUnitSize(1)", error));
}


/**
 * Aktualisiert die Positionsanzeigen unten rechts (Gesamtposition) und unten links (detaillierte Einzelpositionen).
 *
 * @return bool - Erfolgsstatus
 */
bool UpdatePositions() {
   if (!positionsAnalyzed) /*&&*/ if (!AnalyzePositions()     ) return(false);
   if (!mm.ready         ) /*&&*/ if (!UpdateMoneyManagement()) return(false);
   if (!mm.ready         )                                      return(true);


   // (1) Gesamtpositionsanzeige unten rechts
   string strCurrentVola, strCurrentLeverage, strCurrentPosition;
   if      (!isPosition   ) strCurrentPosition = " ";
   else if (!totalPosition) strCurrentPosition = StringConcatenate("Position:   ±", NumberToStr(longPosition, ", .+"), " lot (hedged)");
   else {
      // Leverage der aktuellen Position = MathAbs(totalPosition)/mm.unleveragedLots
      double currentLeverage;
      if (!mm.realEquity) currentLeverage = MathAbs(totalPosition)/((AccountEquity()-AccountCredit())/mm.lotValue);  // Workaround bei negativer AccountBalance:
      else                currentLeverage = MathAbs(totalPosition)/mm.unleveragedLots;                               // die unrealisierten Gewinne werden mit einbezogen !!!
      strCurrentLeverage = StringConcatenate("L", DoubleToStr(currentLeverage, 1), "      ");

      // Volatilität/Woche der aktuellen Position = aktueller Leverage * ATRwPct
      if (mm.ATRwPct != 0)
         strCurrentVola = StringConcatenate("V", DoubleToStr(mm.ATRwPct * 100 * currentLeverage, 1), "%     ");

      strCurrentPosition = StringConcatenate("Position:   " , strCurrentVola, strCurrentLeverage, NumberToStr(totalPosition, "+, .+"), " lot");
   }
   ObjectSetText(label.position, strCurrentPosition, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdatePositions(1)", error));


   // (2) Einzelpositionsanzeige unten links
   static int col.xShifts[], cols, percentCol, commentCol, yDist=3;
   if (!ArraySize(col.xShifts)) {
      if (CustomPositions.AbsoluteAmounts) {
         // Spalten:         Type: Lots   BE:  BePrice   Profit: Amount Percent   Comment
         // col.xShifts[] = {20,   59,    135, 160,      226,    258,   345,      406};
         ArrayResize(col.xShifts, 8);
         col.xShifts[0] =  20;
         col.xShifts[1] =  59;
         col.xShifts[2] = 135;
         col.xShifts[3] = 160;
         col.xShifts[4] = 226;
         col.xShifts[5] = 258;
         col.xShifts[6] = 345;
         col.xShifts[7] = 406;
      }
      else {
         // Spalten:         Type: Lots   BE:  BePrice   Profit: Percent   Comment
         // col.xShifts[] = {20,   59,    135, 160,      226,    258,      319};
         ArrayResize(col.xShifts, 7);
         col.xShifts[0] =  20;
         col.xShifts[1] =  59;
         col.xShifts[2] = 135;
         col.xShifts[3] = 160;
         col.xShifts[4] = 226;
         col.xShifts[5] = 258;
         col.xShifts[6] = 319;
      }
      cols       = ArraySize(col.xShifts);
      percentCol = cols - 2;
      commentCol = cols - 1;
   }
   int iePositions = ArrayRange(positions.idata, 0);
   int positions   = iePositions + lfxOrders.openPositions;          // nur einer der beiden Werte kann ungleich 0 sein

   // (2.1) zusätzlich benötigte Zeilen hinzufügen
   static int lines;
   while (lines < positions) {
      lines++;
      for (int col=0; col < cols; col++) {
         string label = StringConcatenate(label.position, ".line", lines, "_col", col);
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
         label = StringConcatenate(label.position, ".line", lines, "_col", col);
         if (ObjectFind(label) != -1)
            ObjectDelete(label);
      }
      lines--;
   }

   // (2.3) Zeilen von unten nach oben schreiben: "{Type}: {Lots}   BE|Dist: {Price|Pips}   Profit: {Amount} {Percent}   {Comment}"
   string sLotSize, sDistance, sBreakeven, sAdjustedProfit, sProfitPct, sComment;
   color  fontColor;
   int    line;

   // interne/externe Positionsdaten
   for (int i=iePositions-1; i >= 0; i--) {
      line++;
      if      (positions.idata[i][I_CONFIG_TYPE  ] == CONFIG_VIRTUAL  ) fontColor = positions.fontColor.virtual;
      else if (positions.idata[i][I_POSITION_TYPE] == POSITION_HISTORY) fontColor = positions.fontColor.history;
      else if (mode.intern)                                             fontColor = positions.fontColor.intern;
      else                                                              fontColor = positions.fontColor.extern;

      if (!positions.ddata[i][I_ADJUSTED_PROFIT])     sAdjustedProfit = "";
      else                                            sAdjustedProfit = StringConcatenate(" (", DoubleToStr(positions.ddata[i][I_ADJUSTED_PROFIT], 2), ")");

      if ( positions.idata[i][I_COMMENT_INDEX] == -1) sComment = " ";
      else                                            sComment = positions.config.comments[positions.idata[i][I_COMMENT_INDEX]];

      // Nur History
      if (positions.idata[i][I_POSITION_TYPE] == POSITION_HISTORY) {
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col0"           ), typeDescriptions[positions.idata[i][I_POSITION_TYPE]],                   positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col1"           ), " ",                                                                     positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col2"           ), " ",                                                                     positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col3"           ), " ",                                                                     positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col4"           ), "Profit:",                                                               positions.fontSize, positions.fontName, fontColor);
         if (CustomPositions.AbsoluteAmounts)
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col5"           ), DoubleToStr(positions.ddata[i][I_FULL_PROFIT_ABS], 2) + sAdjustedProfit, positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col", percentCol), DoubleToStr(positions.ddata[i][I_FULL_PROFIT_PCT], 2) +"%",              positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col", commentCol), sComment,                                                                positions.fontSize, positions.fontName, fontColor);
      }

      // Directional oder Hedged
      else {
         // Hedged
         if (positions.idata[i][I_POSITION_TYPE] == POSITION_HEDGE) {
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col0"), typeDescriptions[positions.idata[i][I_POSITION_TYPE]],                           positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col1"),      NumberToStr(positions.ddata[i][I_HEDGED_LOTS  ], ".+") +" lot",             positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col2"), "Dist:",                                                                         positions.fontSize, positions.fontName, fontColor);
               if (!positions.ddata[i][I_PIP_DISTANCE]) sDistance = "...";
               else                                     sDistance = DoubleToStr(RoundFloor(positions.ddata[i][I_PIP_DISTANCE], Digits-PipDigits), Digits-PipDigits) +" pip";
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col3"), sDistance,                                                                       positions.fontSize, positions.fontName, fontColor);
         }

         // Not Hedged
         else {
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col0"), typeDescriptions[positions.idata[i][I_POSITION_TYPE]],                           positions.fontSize, positions.fontName, fontColor);
               if (!positions.ddata[i][I_HEDGED_LOTS]) sLotSize = NumberToStr(positions.ddata[i][I_DIRECTIONAL_LOTS], ".+");
               else                                    sLotSize = NumberToStr(positions.ddata[i][I_DIRECTIONAL_LOTS], ".+") +" ±"+ NumberToStr(positions.ddata[i][I_HEDGED_LOTS], ".+");
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col1"), sLotSize +" lot",                                                                positions.fontSize, positions.fontName, fontColor);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col2"), "BE:",                                                                           positions.fontSize, positions.fontName, fontColor);
               if (!positions.ddata[i][I_BREAKEVEN_PRICE]) sBreakeven = "...";
               else                                        sBreakeven = NumberToStr(positions.ddata[i][I_BREAKEVEN_PRICE], PriceFormat);
            ObjectSetText(StringConcatenate(label.position, ".line", line, "_col3"), sBreakeven,                                                                      positions.fontSize, positions.fontName, fontColor);
         }

         // Hedged und Not-Hedged
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col4"           ), "Profit:",                                                               positions.fontSize, positions.fontName, fontColor);
         if (CustomPositions.AbsoluteAmounts)
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col5"           ), DoubleToStr(positions.ddata[i][I_FULL_PROFIT_ABS], 2) + sAdjustedProfit, positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col", percentCol), DoubleToStr(positions.ddata[i][I_FULL_PROFIT_PCT], 2) +"%",              positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col", commentCol), sComment,                                                                positions.fontSize, positions.fontName, fontColor);
      }
   }

   // LFX-Positionsdaten (mode.remote = TRUE)
   for (i=ArrayRange(lfxOrders, 0)-1; i >= 0; i--) {
      if (lfxOrders.ivolatile[i][I_ISOPEN] != 0) {
         line++;
         if (positions.idata[i][I_CONFIG_TYPE] == CONFIG_VIRTUAL) fontColor = positions.fontColor.virtual;
         else                                                     fontColor = positions.fontColor.remote;
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col0"), typeDescriptions[los.Type(lfxOrders, i)+1],                  positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col1"), NumberToStr(los.Units    (lfxOrders, i), ".+") +" units",    positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col2"), "BE:",                                                       positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col3"), NumberToStr(los.OpenPrice(lfxOrders, i), SubPipPriceFormat), positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col4"), "SL:",                                                       positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col5"), NumberToStr(los.StopLoss (lfxOrders, i), SubPipPriceFormat), positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col6"), "Profit:",                                                   positions.fontSize, positions.fontName, fontColor);
         ObjectSetText(StringConcatenate(label.position, ".line", line, "_col7"), DoubleToStr(lfxOrders.dvolatile[i][I_VPROFIT], 2),           positions.fontSize, positions.fontName, fontColor);
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
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                            // bei offenem Properties-Dialog oder Object::onDrag()
      return(true);
   return(!catch("UpdateOrderCounter(1)", error));
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
      ObjectSetText(label.externalAccount, external.signalName, 8, "Arial Fett", Red);
   }

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                            // bei offenem Properties-Dialog oder Object::onDrag()
      return(true);
   return(!catch("UpdateExternalAccount(1)", error));
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
      return(!SetLastError(ERR_SYMBOL_NOT_AVAILABLE));                                 // Symbol (noch) nicht subscribed (Start, Account- oder Templatewechsel) oder Offline-Chart
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
         if (soMode == ASM_PERCENT) string text = StringConcatenate("Stopout  ", Round(AccountStopoutLevel()), "%  =  ", NumberToStr(soPrice, PriceFormat));
         else                              text = StringConcatenate("Stopout  ", DoubleToStr(soEquity, 2), AccountCurrency(), "  =  ", NumberToStr(soPrice, PriceFormat));
      ObjectSetText(label.stopoutLevel, text);
      ObjectRegister(label.stopoutLevel);
   }
   ObjectSet(label.stopoutLevel, OBJPROP_PRICE1, soPrice);


   error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                                     // bei offenem Properties-Dialog oder Object::onDrag()
      return(true);
   return(!catch("UpdateStopoutLevel(2)", error));
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
         SetLastError(ERR_SYMBOL_NOT_AVAILABLE);
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
      if (openBar == EMPTY_VALUE) return(false);                                 // Fehler
      if (openBar ==          -1) return(true);                                  // sessionStart ist zu jung für den Chart
   int closeBar = iBarShiftPrevious(NULL, NULL, sessionEnd);
      if (closeBar == EMPTY_VALUE) return(false);
      if (closeBar ==          -1) return(true);                                 // sessionEnd ist zu alt für den Chart
   if (openBar < closeBar)
      return(!catch("UpdateOHLC(1)  illegal open/close bar offsets for session from="+ DateToStr(sessionStart, "w D.M.Y H:I") +" (bar="+ openBar +")  to="+ DateToStr(sessionEnd, "w D.M.Y H:I") +" (bar="+ closeBar +")", ERR_RUNTIME_ERROR));


   // (4) Baroffsets von Session-High und -Low ermitteln
   int highBar = iHighest(NULL, NULL, MODE_HIGH, openBar-closeBar+1, closeBar);
   int lowBar  = iLowest (NULL, NULL, MODE_LOW , openBar-closeBar+1, closeBar);


   // (5) Anzeige aktualisieren
   string strOHLC = "O="+ NumberToStr(Open[openBar], PriceFormat) +"   H="+ NumberToStr(High[highBar], PriceFormat) +"   L="+ NumberToStr(Low[lowBar], PriceFormat);
   ObjectSetText(label.ohlc, strOHLC, 8, "", Black);

   int error = GetLastError();
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                               // bei offenem Properties-Dialog oder Object::onDrag()
      return(true);
   return(!catch("UpdateOHLC(2)", error));
}


/**
 * Aktualisiert die Zeitanzeige (nur im Tester bei VisualMode=On).
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateTime() {
   if (!IsVisualModeFix())
      return(true);

   static datetime lastTime;

   datetime now = TimeCurrentEx("UpdateTime(1)");
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
   if (!error || error==ERR_OBJECT_DOES_NOT_EXIST)                      // bei offenem Properties-Dialog oder Object::onDrag()
      return(true);
   return(!catch("UpdateTime(2)", error));
}


/**
 * Ermittelt die aktuelle Positionierung, gruppiert sie je nach individueller Konfiguration und berechnet deren Kennziffern.
 *
 * @return bool - Erfolgsstatus
 */
bool AnalyzePositions() {
   if (mode.remote      ) positionsAnalyzed = true;
   if (positionsAnalyzed) return(true);

   int      tickets    [], openPositions;                               // Positionsdetails
   int      types      [];
   double   lots       [];
   datetime openTimes  [];
   double   openPrices [];
   double   commissions[];
   double   swaps      [];
   double   profits    [];


   // (1) Gesamtposition ermitteln
   longPosition  = 0;                                                   // globale Variablen
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

         // LFX-Reporting vorübergehend wegen QuickChannel-Fehler (volle Message-Queue) deaktiviert

         if (false /*LFX.IsMyOrder()*/) {                               // nebenbei P/L gefundener LFX-Positionen aufaddieren
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
         ArrayCopy(openTimes  , external.open.openTime  );
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
   longPosition  = NormalizeDouble(longPosition,  2);                   // globale Variablen
   shortPosition = NormalizeDouble(shortPosition, 2);
   totalPosition = NormalizeDouble(longPosition - shortPosition, 2);
   isPosition    = longPosition || shortPosition;


   // (2) Positionen analysieren und in positions.~data[] speichern
   if (ArrayRange(positions.idata, 0) > 0) {
      ArrayResize(positions.idata, 0);
      ArrayResize(positions.ddata, 0);
   }

   // (2.1) individuelle Konfiguration parsen
   int oldError = last_error;
   SetLastError(NO_ERROR);
   if (ArrayRange(positions.config, 0)==0) /*&&*/ if (!CustomPositions.ReadConfig()) {
      positionsAnalyzed = !last_error;                                  // MarketInfo()-Daten stehen ggf. noch nicht zur Verfügung,
      if (!last_error) SetLastError(oldError);                          // in diesem Fall nächster Versuch beim nächsten Tick.
      return(positionsAnalyzed);
   }
   SetLastError(oldError);

   int    termType, confLineIndex;
   double termValue1, termValue2, termCache1, termCache2, customLongPosition, customShortPosition, customTotalPosition, closedProfit, adjustedProfit, customEquity, _longPosition=longPosition, _shortPosition=shortPosition, _totalPosition=totalPosition;
   bool   isCustomVirtual;
   int    customTickets    [];
   int    customTypes      [];
   double customLots       [];
   double customOpenPrices [];
   double customCommissions[];
   double customSwaps      [];
   double customProfits    [];

   static bool logTickets.done = false;


   // (2.2) individuell konfigurierte Positionen aus den offenen Positionen extrahieren
   int confSize = ArrayRange(positions.config, 0);

   for (i=0, confLineIndex=0; i < confSize; i++) {
      termType   = positions.config[i][0];
      termValue1 = positions.config[i][1];
      termValue2 = positions.config[i][2];
      termCache1 = positions.config[i][3];
      termCache2 = positions.config[i][4];

      if (!termType) {                                               // termType=NULL => "Zeilenende"
         if (CustomPositions.LogTickets) /*&&*/ if (!logTickets.done)
            AnalyzePositions.LogTickets(isCustomVirtual, customTickets, confLineIndex);

         // (2.3) individuell konfigurierte Position speichern
         if (!StorePosition(isCustomVirtual, customLongPosition, customShortPosition, customTotalPosition, customTickets, customTypes, customLots, customOpenPrices, customCommissions, customSwaps, customProfits, closedProfit, adjustedProfit, customEquity, confLineIndex))
            return(false);
         isCustomVirtual     = false;
         customLongPosition  = 0;
         customShortPosition = 0;
         customTotalPosition = 0;
         closedProfit        = 0;
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

   // (2.4) verbleibende Position(en) speichern
   if (CustomPositions.LogTickets) /*&&*/ if (!logTickets.done)
      AnalyzePositions.LogTickets(false, tickets, -1);

   if (!StorePosition(false, _longPosition, _shortPosition, _totalPosition, tickets, types, lots, openPrices, commissions, swaps, profits, 0, 0, 0, -1))
      return(false);

   logTickets.done   = true;
   positionsAnalyzed = true;
   return(!catch("AnalyzePositions(2)"));
}


/**
 * Loggt die Tickets jeder Zeile der Positionsanzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool AnalyzePositions.LogTickets(bool isVirtual, int tickets[], int commentIndex) {
   isVirtual = isVirtual!=0;

   if (CustomPositions.LogTickets) {
      if (ArraySize(tickets) > 0) {
         if (commentIndex > -1) log("LogTickets(2)  conf("+ commentIndex +") = \""+ positions.config.comments[commentIndex] +"\" = "+ TicketsToStr.Position(tickets) +" = "+ TicketsToStr(tickets, NULL));
         else                   log("LogTickets(3)  conf(none) = "                                                                  + TicketsToStr.Position(tickets) +" = "+ TicketsToStr(tickets, NULL));
      }
   }
   return(true);
}


/**
 * Aktualisiert die dynamischen Werte des Money-Managements.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateMoneyManagement() {
   if (mm.ready   ) return(true);
   if (mode.remote) return(true);
 //if (mode.remote) return(_true(debug("UpdateMoneyManagement(1)  feature not implemented for mode.remote=1")));

   mm.realEquity             = 0;
   mm.lotValue               = 0;
   mm.unleveragedLots        = 0;                                             // Lotsize bei Hebel 1:1
   mm.ATRwAbs                = 0;                                             // wöchentliche ATR, absolut
   mm.ATRwPct                = 0;                                             // wöchentliche ATR, prozentual
   mm.stdLeverage            = 0;                                             // Hebel bei wöchentlicher Volatilität einer Unit von {mm.stdVola} Prozent
   mm.stdLots                = 0;                                             // Lotsize für wöchentliche Volatilität einer Unit von {mm.stdVola} Prozent
   mm.customVola             = 0;                                             // Volatilität/Woche bei benutzerdefiniertem Hebel
   mm.customLots             = 0;                                             // Lotsize bei benutzerdefiniertem Hebel
   mm.defaultVola            = 0;
   mm.defaultLeverage        = 0;
   mm.defaultLots            = 0;
   mm.defaultLots.normalized = 0;

   // (1) unleveraged Lots
   double tickSize       = MarketInfo(Symbol(), MODE_TICKSIZE      );
   double tickValue      = MarketInfo(Symbol(), MODE_TICKVALUE     );
   double marginRequired = MarketInfo(Symbol(), MODE_MARGINREQUIRED); if (marginRequired == -92233720368547760.) marginRequired = 0;
      int error = GetLastError();
      if (IsError(error)) {
         if (error == ERR_SYMBOL_NOT_AVAILABLE) {
            SetLastError(ERS_TERMINAL_NOT_YET_READY);
            //debug("UpdateMoneyManagement(2)  MarketInfo(\""+ Symbol() +"\") => ERR_SYMBOL_NOT_AVAILABLE", last_error);
            return(false);
         }
         return(!catch("UpdateMoneyManagement(3)", error));
      }
      if (mode.intern) { string companyId = ShortAccountCompany(); string accountId = GetAccountNumber();   }
      else             {        companyId = external.signalProvider;      accountId = external.signalAlias; }

   double externalAssets = GetExternalAssets(companyId, accountId); if (IsEmptyValue(externalAssets)) return(false);
   if (mode.intern) {                                                         // TODO: !!! falsche Berechnung !!!
      mm.realEquity = MathMin(AccountBalance(), AccountEquity()-AccountCredit()) + externalAssets;
      if (mm.realEquity < 0)                                                  // kann bei negativer AccountBalance negativ sein
         mm.realEquity = 0;
   }
   else {
      mm.realEquity = externalAssets;                                         // ebenfalls falsch (nur Näherungswert)
   }

   if (!Close[0] || !tickSize || !tickValue || !marginRequired) {             // bei Start oder Accountwechsel können einige Werte noch ungesetzt sein
      SetLastError(ERS_TERMINAL_NOT_YET_READY);
      //debug("UpdateMoneyManagement(5)  Tick="+ Tick + ifString(!Close[0], "  Close=0", "") + ifString(!tickSize, "  tickSize=0", "") + ifString(!tickValue, "  tickValue=0", "") + ifString(!marginRequired, "  marginRequired=0", ""), last_error);
      return(false);
   }

   mm.lotValue        = Close[0]/tickSize * tickValue;                        // Value eines Lots in Account-Currency
   mm.unleveragedLots = mm.realEquity/mm.lotValue;                            // ungehebelte Lotsize (Leverage 1:1)


   // (2) Expected TrueRange als Maximalwert von ATR und den letzten beiden Einzelwerten: ATR, TR[1] und TR[0]
   double a = @ATR(NULL, PERIOD_W1, 14, 1); if (a == EMPTY) return(false);    // ATR(14xW):  throws ERS_HISTORY_UPDATE (wenn, dann nur einmal)
      if (last_error == ERS_HISTORY_UPDATE) /*&&*/ if (Period()!=PERIOD_W1) SetLastError(NO_ERROR);
      if (!a)                                               return(false);
   double b = @ATR(NULL, PERIOD_W1,  1, 1); if (b == EMPTY) return(false);    // TrueRange letzte Woche
      if (!b)                                               return(false);
   double c = @ATR(NULL, PERIOD_W1,  1, 0); if (c == EMPTY) return(false);    // TrueRange aktuelle Woche
      if (!c)                                               return(false);
   mm.ATRwAbs = MathMax(a, MathMax(b, c));
      double C = iClose(NULL, PERIOD_W1, 1); if (!C)        return(false);
      double H = iHigh (NULL, PERIOD_W1, 0); if (!H)        return(false);
      double L = iLow  (NULL, PERIOD_W1, 0); if (!L)        return(false);
   mm.ATRwPct = mm.ATRwAbs/((MathMax(C, H) + MathMax(C, L))/2);               // median price


   if (mm.isCustomUnitSize) {
      // (3) customLots
      mm.customLots      = mm.unleveragedLots * mm.customLeverage;            // mit benutzerdefiniertem Hebel gehebelte Lotsize
      mm.customVola      = mm.customLeverage * (mm.ATRwPct*100);              // resultierende wöchentliche Volatilität

      mm.defaultVola     = mm.customVola;
      mm.defaultLeverage = mm.customLeverage;
      mm.defaultLots     = mm.customLots;
   }
   else {
      // (4) stdLots
      if (!mm.ATRwPct)
         return(false);
      mm.stdLeverage     = mm.stdVola/(mm.ATRwPct*100);
      mm.stdLots         = mm.unleveragedLots * mm.stdLeverage;               // auf wöchentliche Volatilität gehebelte Lotsize

      mm.defaultVola     = mm.stdVola;
      mm.defaultLeverage = mm.stdLeverage;
      mm.defaultLots     = mm.stdLots;
   }


   // (5) Lotsize runden
   if (mm.defaultLots > 0) {                                                                                                              // Abstufung max. 6.7% je Schritt
      if      (mm.defaultLots <=    0.03) mm.defaultLots.normalized = NormalizeDouble(MathRound(mm.defaultLots/  0.001) *   0.001, 3);    //     0-0.03: Vielfaches von   0.001
      else if (mm.defaultLots <=   0.075) mm.defaultLots.normalized = NormalizeDouble(MathRound(mm.defaultLots/  0.002) *   0.002, 3);    // 0.03-0.075: Vielfaches von   0.002
      else if (mm.defaultLots <=    0.1 ) mm.defaultLots.normalized = NormalizeDouble(MathRound(mm.defaultLots/  0.005) *   0.005, 3);    //  0.075-0.1: Vielfaches von   0.005
      else if (mm.defaultLots <=    0.3 ) mm.defaultLots.normalized = NormalizeDouble(MathRound(mm.defaultLots/  0.01 ) *   0.01 , 2);    //    0.1-0.3: Vielfaches von   0.01
      else if (mm.defaultLots <=    0.75) mm.defaultLots.normalized = NormalizeDouble(MathRound(mm.defaultLots/  0.02 ) *   0.02 , 2);    //   0.3-0.75: Vielfaches von   0.02
      else if (mm.defaultLots <=    1.2 ) mm.defaultLots.normalized = NormalizeDouble(MathRound(mm.defaultLots/  0.05 ) *   0.05 , 2);    //   0.75-1.2: Vielfaches von   0.05
      else if (mm.defaultLots <=    3.  ) mm.defaultLots.normalized = NormalizeDouble(MathRound(mm.defaultLots/  0.1  ) *   0.1  , 1);    //      1.2-3: Vielfaches von   0.1
      else if (mm.defaultLots <=    7.5 ) mm.defaultLots.normalized = NormalizeDouble(MathRound(mm.defaultLots/  0.2  ) *   0.2  , 1);    //      3-7.5: Vielfaches von   0.2
      else if (mm.defaultLots <=   12.  ) mm.defaultLots.normalized = NormalizeDouble(MathRound(mm.defaultLots/  0.5  ) *   0.5  , 1);    //     7.5-12: Vielfaches von   0.5
      else if (mm.defaultLots <=   30.  ) mm.defaultLots.normalized =       MathRound(MathRound(mm.defaultLots/  1    ) *   1       );    //      12-30: Vielfaches von   1
      else if (mm.defaultLots <=   75.  ) mm.defaultLots.normalized =       MathRound(MathRound(mm.defaultLots/  2    ) *   2       );    //      30-75: Vielfaches von   2
      else if (mm.defaultLots <=  120.  ) mm.defaultLots.normalized =       MathRound(MathRound(mm.defaultLots/  5    ) *   5       );    //     75-120: Vielfaches von   5
      else if (mm.defaultLots <=  300.  ) mm.defaultLots.normalized =       MathRound(MathRound(mm.defaultLots/ 10    ) *  10       );    //    120-300: Vielfaches von  10
      else if (mm.defaultLots <=  750.  ) mm.defaultLots.normalized =       MathRound(MathRound(mm.defaultLots/ 20    ) *  20       );    //    300-750: Vielfaches von  20
      else if (mm.defaultLots <= 1200.  ) mm.defaultLots.normalized =       MathRound(MathRound(mm.defaultLots/ 50    ) *  50       );    //   750-1200: Vielfaches von  50
      else                                mm.defaultLots.normalized =       MathRound(MathRound(mm.defaultLots/100    ) * 100       );    //   1200-...: Vielfaches von 100
   }

   mm.ready = true;
   return(!catch("UpdateMoneyManagement(16)"));
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
 * Liest die individuelle Positionskonfiguration ein und speichert sie in einem binären Format.
 *
 * @return bool - Erfolgsstatus
 *
 *
 * Füllt das Array positions.config[][] mit den Konfigurationsdaten des aktuellen Instruments in der Accountkonfiguration. Das Array enthält danach Elemente
 * im Format {type, value1, value2, ...}.  Ein NULL-Term-Element {NULL, ...} markiert ein Zeilenende bzw. eine leere Konfiguration. Nach einer eingelesenen
 * Konfiguration ist die Größe der ersten Dimension des Arrays niemals 0. Positionskommentare werden in positions.config.comments[] gespeichert.
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
 *   12.34                                           - dem P/L einer Position zuzuschlagender Betrag                          [TERM_ADJUSTMENT    , 12.34           , ...             , ...     , ...     ]
 *   EQ123.00                                        - für Equityberechnungen zu verwendender Wert                            [TERM_EQUITY        , 123.00          , ...             , ...     , ...     ]
 *
 *   Kommentar (Text nach dem ersten Semikolon ";")  - wird als Beschreibung angezeigt
 *   Kommentare in Kommentaren (nach weiterem ";")   - werden ignoriert
 *
 *
 *  Beispiel:
 *  ---------
 *   [CustomPositions]
 *   GBPAUD.0 = #111111, 0.1#222222      ;  komplettes Ticket #111111 und 0.1 Lot von Ticket #222222 (Text wird als Kommentar angezeigt)
 *   GBPAUD.1 = 0.2#L, #222222           ;; virtuelle 0.2 Lot Long-Position und Rest von #222222 (2)
 *   GBPAUD.3 = L,S,-34.56               ;; alle verbleibenden Positionen, inkl. eines Restes von #222222, zzgl. eines Verlustes von -34.56
 *   GBPAUD.3 = 0.5L                     ;; Zeile wird ignoriert, da der Schlüssel "GBPAUD.3" doppelt vorhanden ist und bereits verarbeitet wurde
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
 *  (1) Bei einer Lotsize von 0 wird die entsprechende Teilposition der individuellen Position ignoriert.
 *  (2) Reale Positionen, die mit virtuellen Positionen kombiniert werden, werden nicht von der verbleibenden Gesamtposition abgezogen.
 *      Dies kann in Verbindung mit (1) benutzt werden, um auf die Schnelle eine virtuelle Position zu konfigurieren, die keinen Einfluß
 *      auf die Anzeige später folgender Positionen hat (z.B. durch "0L" innerhalb einer Konfigurationszeile).
 *  (3) Zeitangaben im Format: 2014[.01[.15 [W|12:30[:45]]]]
 *  (4) Einer der beiden Zeitpunkte kann leer sein und steht für "von Beginn" oder "bis Ende".
 *  (5) Ein Historyzeitraum kann tages-, wochen- oder monatsweise gruppiert werden, wenn er nicht mit anderen Positionsdaten kombiniert wird.
 *  (6) Die konfigurierten Positionen werden in der Reihenfolge ihrer Notierung verarbeitet und angezeigt, sie werden nicht sortiert.
 */
bool CustomPositions.ReadConfig() {
   if (ArrayRange(positions.config, 0) > 0) {
      ArrayResize(positions.config,          0);
      ArrayResize(positions.config.comments, 0);
   }

   string   keys[], values[], iniValue, comment, confComment, openComment, hstComment, strSize, strTicket, strPrice, sNull, symbol=Symbol(), stdSymbol=StdSymbol();
   double   termType, termValue1, termValue2, termCache1, termCache2, lotSize, minLotSize=MarketInfo(Symbol(), MODE_MINLOT), lotStep=MarketInfo(Symbol(), MODE_LOTSTEP);
   int      valuesSize, confSize, pos, ticket, positionStartOffset;
   datetime from, to;
   bool     isPositionEmpty, isPositionVirtual, isPositionGrouped, isTotal;
   if (!minLotSize) return(false);                                   // falls MarketInfo()-Daten noch nicht verfügbar sind
   if (!lotStep   ) return(false);

   if (mode.remote) return(!catch("CustomPositions.ReadConfig(1)  feature for mode.remote=1 not yet implemented", ERR_NOT_IMPLEMENTED));

   string mqlDir   = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string file     = TerminalPath() + mqlDir +"\\files\\"+ ifString(mode.intern, ShortAccountCompany() +"\\"+ GetAccountNumber(), external.signalProvider +"\\"+ external.signalAlias) +"_config.ini";
   string section  = "CustomPositions";
   int    keysSize = GetIniKeys(file, section, keys);

   for (int i=0; i < keysSize; i++) {
      if (StringStartsWithI(keys[i], symbol) || StringStartsWithI(keys[i], stdSymbol)) {
         if (SearchStringArrayI(keys, keys[i]) == i) {               // bei gleichnamigen Schlüsseln wird nur der erste verarbeitet
            iniValue = GetRawIniString(file, section, keys[i], "");
            iniValue = StringReplace(iniValue, TAB, " ");

            // Kommentar auswerten
            comment     = "";
            confComment = "";
            openComment = "";
            hstComment  = "";
            pos = StringFind(iniValue, ";");
            if (pos >= 0) {
               confComment = StringRight(iniValue, -pos-1);
               iniValue    = StringTrim(StringLeft(iniValue, pos));
               pos = StringFind(confComment, ";");
               if (pos == -1) confComment = StringTrim(confComment);
               else           confComment = StringTrim(StringLeft(confComment, pos));
               if (StringStartsWith(confComment, "\"") && StringEndsWith(confComment, "\"")) // führende und schließende Anführungszeichen entfernen
                  confComment = StringSubstrFix(confComment, 1, StringLen(confComment)-2);
            }

            // Konfiguration auswerten
            isPositionEmpty   = true;                                // ob die resultierende Position bereits Daten enthält oder nicht
            isPositionVirtual = false;                               // ob die resultierende Position virtuell ist
            isPositionGrouped = false;                               // ob die resultierende Position gruppiert ist
            valuesSize        = Explode(StringToUpper(iniValue), ",", values, NULL);

            for (int n=0; n < valuesSize; n++) {
               values[n] = StringTrim(values[n]);
               if (!StringLen(values[n]))                            // Leervalue
                  continue;

               if (StringStartsWith(values[n], "H")) {               // H[T] = History[Total]
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

               else if (StringStartsWith(values[n], "#")) {          // Ticket
                  strTicket = StringTrim(StringRight(values[n], -1));
                  if (!StringIsDigit(strTicket))                     return(!catch("CustomPositions.ReadConfig(2)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-digits in ticket \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termType   = StrToInteger(strTicket);
                  termValue1 = EMPTY;                                // alle verbleibenden Lots
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StringStartsWith(values[n], "L")) {          // alle verbleibenden Long-Positionen
                  if (values[n] != "L")                              return(!catch("CustomPositions.ReadConfig(3)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termType   = TERM_OPEN_LONG;
                  termValue1 = EMPTY;
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StringStartsWith(values[n], "S")) {          // alle verbleibenden Short-Positionen
                  if (values[n] != "S")                              return(!catch("CustomPositions.ReadConfig(4)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termType   = TERM_OPEN_SHORT;
                  termValue1 = EMPTY;
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StringStartsWith(values[n], "O")) {          // O[T] = die verbleibenden Positionen [aller Symbole] eines Zeitraums
                  if (!CustomPositions.ParseOpenTerm(values[n], openComment, isTotal, from, to)) return(false);
                  termType   = ifInt(!isTotal, TERM_OPEN_SYMBOL, TERM_OPEN_ALL);
                  termValue1 = from;
                  termValue2 = to;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StringStartsWith(values[n], "E")) {          // E[Q] = Equity
                  strSize = StringTrim(StringRight(values[n], ifInt(!StringStartsWith(values[n], "EQ"), -1, -2)));
                  if (!StringIsNumeric(strSize))                     return(!catch("CustomPositions.ReadConfig(5)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric equity \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termType   = TERM_EQUITY;
                  termValue1 = StrToDouble(strSize);
                  if (termValue1 <= 0)                               return(!catch("CustomPositions.ReadConfig(6)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal equity \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StringIsNumeric(values[n])) {                // P/L-Adjustment
                  termType   = TERM_ADJUSTMENT;
                  termValue1 = StrToDouble(values[n]);
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StringEndsWith(values[n], "L")) {            // virtuelle Longposition zum aktuellen Preis
                  termType = TERM_OPEN_LONG;
                  strSize  = StringTrim(StringLeft(values[n], -1));
                  if (!StringIsNumeric(strSize))                     return(!catch("CustomPositions.ReadConfig(7)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termValue1 = StrToDouble(strSize);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(8)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(9)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StringEndsWith(values[n], "S")) {            // virtuelle Shortposition zum aktuellen Preis
                  termType = TERM_OPEN_SHORT;
                  strSize  = StringTrim(StringLeft(values[n], -1));
                  if (!StringIsNumeric(strSize))                     return(!catch("CustomPositions.ReadConfig(10)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termValue1 = StrToDouble(strSize);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(11)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(12)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StringContains(values[n], "L")) {            // virtuelle Longposition zum angegebenen Preis
                  termType = TERM_OPEN_LONG;
                  pos = StringFind(values[n], "L");
                  strSize = StringTrim(StringLeft(values[n], pos));
                  if (!StringIsNumeric(strSize))                     return(!catch("CustomPositions.ReadConfig(13)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termValue1 = StrToDouble(strSize);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(14)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(15)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  strPrice = StringTrim(StringRight(values[n], -pos-1));
                  if (StringStartsWith(strPrice, "@"))
                     strPrice = StringTrim(StringRight(strPrice, -1));
                  if (!StringIsNumeric(strPrice))                    return(!catch("CustomPositions.ReadConfig(16)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termValue2 = StrToDouble(strPrice);
                  if (termValue2 <= 0)                               return(!catch("CustomPositions.ReadConfig(17)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StringContains(values[n], "S")) {            // virtuelle Shortposition zum angegebenen Preis
                  termType = TERM_OPEN_SHORT;
                  pos = StringFind(values[n], "S");
                  strSize = StringTrim(StringLeft(values[n], pos));
                  if (!StringIsNumeric(strSize))                     return(!catch("CustomPositions.ReadConfig(18)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termValue1 = StrToDouble(strSize);
                  if (termValue1 < 0)                                return(!catch("CustomPositions.ReadConfig(19)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (negative lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  if (MathModFix(termValue1, 0.001) != 0)            return(!catch("CustomPositions.ReadConfig(20)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (virtual lot size not a multiple of 0.001 \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  strPrice = StringTrim(StringRight(values[n], -pos-1));
                  if (StringStartsWith(strPrice, "@"))
                     strPrice = StringTrim(StringRight(strPrice, -1));
                  if (!StringIsNumeric(strPrice))                    return(!catch("CustomPositions.ReadConfig(21)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termValue2 = StrToDouble(strPrice);
                  if (termValue2 <= 0)                               return(!catch("CustomPositions.ReadConfig(22)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (illegal price \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termCache1 = NULL;
                  termCache2 = NULL;
               }

               else if (StringContains(values[n], "#")) {            // Lotsizeangabe + # + Ticket
                  pos = StringFind(values[n], "#");
                  strSize = StringTrim(StringLeft(values[n], pos));
                  if (!StringIsNumeric(strSize))                     return(!catch("CustomPositions.ReadConfig(23)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-numeric lot size \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termValue1 = StrToDouble(strSize);
                  if (termValue1 && LT(termValue1, minLotSize))      return(!catch("CustomPositions.ReadConfig(24)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (lot size smaller than MIN_LOTSIZE \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  if (MathModFix(termValue1, lotStep) != 0)          return(!catch("CustomPositions.ReadConfig(25)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (lot size not a multiple of LOTSTEP \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  strTicket = StringTrim(StringRight(values[n], -pos-1));
                  if (!StringIsDigit(strTicket))                     return(!catch("CustomPositions.ReadConfig(26)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (non-digits in ticket \""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
                  termType   = StrToInteger(strTicket);
                  termValue2 = NULL;
                  termCache1 = NULL;
                  termCache2 = NULL;
               }
               else                                                  return(!catch("CustomPositions.ReadConfig(27)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (\""+ values[n] +"\") in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

               // Eine gruppierte Trade-History kann nicht mit anderen Termen kombiniert werden
               if (isPositionGrouped && termType!=TERM_EQUITY)       return(!catch("CustomPositions.ReadConfig(28)  invalid configuration value ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (cannot combine grouped trade history with other entries) in \""+ file +"\"", ERR_INVALID_CONFIG_PARAMVALUE));

               // Die Konfiguration virtueller Positionen muß mit einem virtuellen Term beginnen, damit die realen Lots nicht um die virtuellen Lots reduziert werden, siehe (2).
               if ((termType==TERM_OPEN_LONG || termType==TERM_OPEN_SHORT) && termValue1!=EMPTY) {
                  if (!isPositionEmpty && !isPositionVirtual) {
                     double tmp[POSITION_CONFIG_TERM.doubleSize] = {TERM_OPEN_LONG, 0, NULL, NULL, NULL};   // am Anfang der Zeile virtuellen 0-Term einfügen: 0L
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

            if (!isPositionEmpty) {                                  // Zeile mit Leer-Term abschließen (markiert Zeilenende)
               confSize = ArrayRange(positions.config, 0);
               ArrayResize(positions.config, confSize+1);            // initialisiert Term mit NULL
                  comment = openComment + ifString(StringLen(openComment) && StringLen(hstComment ), ", ", "") + hstComment;
                  comment = comment     + ifString(StringLen(comment    ) && StringLen(confComment), ", ", "") + confComment;
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

   //debug("CustomPositions.ReadConfig(0.3)  conf="+ DoublesToStr(positions.config, NULL));
   return(!catch("CustomPositions.ReadConfig(29)"));
}


/**
 * Parst einen Open-Konfigurations-Term (Open Position).
 *
 * @param  _IN_     string   term         - Konfigurations-Term
 * @param  _IN_OUT_ string   openComments - vorhandene OpenPositions-Kommentare (werden ggf. erweitert)
 * @param  _OUT_    bool     isTotal      - ob die offenen Positionen alle verfügbaren Symbole (TRUE) oder nur das aktuelle Symbol (FALSE) umfassen
 * @param  _OUT_    datetime from         - Beginnzeitpunkt der zu berücksichtigenden Positionen
 * @param  _OUT_    datetime to           - Endzeitpunkt der zu berücksichtigenden Positionen
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

   string term.orig = StringTrim(term);
          term      = StringToUpper(term.orig);
   if (!StringStartsWith(term, "O")) return(!catch("CustomPositions.ParseOpenTerm(1)  invalid parameter term = "+ DoubleQuoteStr(term.orig) +" (not TERM_OPEN_*)", ERR_INVALID_PARAMETER));
   term = StringTrim(StringRight(term, -1));

   if     (!StringStartsWith(term, "T"    )) isTotal = false;
   else if (StringStartsWith(term, "THIS" )) isTotal = false;
   else if (StringStartsWith(term, "TODAY")) isTotal = false;
   else                                      isTotal = true;
   if (isTotal) term = StringTrim(StringRight(term, -1));

   bool     isSingleTimespan, isFullYear1, isFullYear2, isFullMonth1, isFullMonth2, isFullWeek1, isFullWeek2, isFullDay1, isFullDay2, isFullHour1, isFullHour2, isFullMinute1, isFullMinute2;
   datetime dtFrom, dtTo;
   string   comment = "";


   // (1) Beginn- und Endzeitpunkt parsen
   int pos = StringFind(term, "-");
   if (pos >= 0) {                                                   // von-bis parsen
      // {DateTime}-{DateTime}
      // {DateTime}-NULL
      //       NULL-{DateTime}
      dtFrom = ParseDateTime(StringTrim(StringLeft (term,  pos  )), isFullYear1, isFullMonth1, isFullWeek1, isFullDay1, isFullHour1, isFullMinute1); if (IsNaT(dtFrom)) return(false);
      dtTo   = ParseDateTime(StringTrim(StringRight(term, -pos-1)), isFullYear2, isFullMonth2, isFullWeek2, isFullDay2, isFullHour2, isFullMinute2); if (IsNaT(dtTo  )) return(false);
      if (dtTo != NULL) {
         if      (isFullYear2  ) dtTo  = DateTime(TimeYearFix(dtTo)+1)                  - 1*SECOND;   // Jahresende
         else if (isFullMonth2 ) dtTo  = DateTime(TimeYearFix(dtTo), TimeMonth(dtTo)+1) - 1*SECOND;   // Monatsende
         else if (isFullWeek2  ) dtTo += 1*WEEK                                         - 1*SECOND;   // Wochenende
         else if (isFullDay2   ) dtTo += 1*DAY                                          - 1*SECOND;   // Tagesende
         else if (isFullHour2  ) dtTo -=                                                  1*SECOND;   // Ende der vorhergehenden Stunde
       //else if (isFullMinute2) dtTo -=                                                  1*SECOND;   // nicht bei Minuten (deaktivert)
      }
   }
   else {
      // {DateTime}                                                  // einzelnen Zeitraum parsen
      isSingleTimespan = true;
      dtFrom = ParseDateTime(term, isFullYear1, isFullMonth1, isFullWeek1, isFullDay1, isFullHour1, isFullMinute1); if (IsNaT(dtFrom)) return(false);
                                                                                                                         if (!dtFrom)  return(!catch("CustomPositions.ParseOpenTerm(2)  invalid open positions configuration in "+ DoubleQuoteStr(term.orig), ERR_INVALID_CONFIG_PARAMVALUE));
      if      (isFullYear1  ) dtTo = DateTime(TimeYearFix(dtFrom)+1)                    - 1*SECOND;   // Jahresende
      else if (isFullMonth1 ) dtTo = DateTime(TimeYearFix(dtFrom), TimeMonth(dtFrom)+1) - 1*SECOND;   // Monatsende
      else if (isFullWeek1  ) dtTo = dtFrom + 1*WEEK                                    - 1*SECOND;   // Wochenende
      else if (isFullDay1   ) dtTo = dtFrom + 1*DAY                                     - 1*SECOND;   // Tagesende
      else if (isFullHour1  ) dtTo = dtFrom + 1*HOUR                                    - 1*SECOND;   // Ende der Stunde
      else if (isFullMinute1) dtTo = dtFrom + 1*MINUTE                                  - 1*SECOND;   // Ende der Minute
      else                    dtTo = dtFrom;
   }
   //debug("CustomPositions.ParseOpenTerm(0.1)  dtFrom="+ TimeToStr(dtFrom, TIME_FULL) +"  dtTo="+ TimeToStr(dtTo, TIME_FULL));
   if (!dtFrom && !dtTo)      return(!catch("CustomPositions.ParseOpenTerm(3)  invalid open positions configuration in "+ DoubleQuoteStr(term.orig), ERR_INVALID_CONFIG_PARAMVALUE));
   if (dtTo && dtFrom > dtTo) return(!catch("CustomPositions.ParseOpenTerm(4)  invalid open positions configuration in "+ DoubleQuoteStr(term.orig) +" (start time after end time)", ERR_INVALID_CONFIG_PARAMVALUE));


   // (2) Datumswerte definieren und zurückgeben
   if (isSingleTimespan) {
      if      (isFullYear1  ) comment =               DateToStr(dtFrom, "Y");
      else if (isFullMonth1 ) comment =               DateToStr(dtFrom, "Y O");
      else if (isFullWeek1  ) comment = "Woche vom "+ DateToStr(dtFrom, "D.M.Y");
      else if (isFullDay1   ) comment =               DateToStr(dtFrom, "D.M.Y");
      else if (isFullHour1  ) comment =               DateToStr(dtFrom, "D.M.Y H:I") + DateToStr(dtTo+1*SECOND, "-H:I");
      else if (isFullMinute1) comment =               DateToStr(dtFrom, "D.M.Y H:I");
      else                    comment =               DateToStr(dtFrom, "D.M.Y H:I:S");
   }
   else if (!dtTo) {
      if      (isFullYear1  ) comment = "seit "+      DateToStr(dtFrom, "Y");
      else if (isFullMonth1 ) comment = "seit "+      DateToStr(dtFrom, "O Y");
      else if (isFullWeek1  ) comment = "seit "+      DateToStr(dtFrom, "D.M.Y");
      else if (isFullDay1   ) comment = "seit "+      DateToStr(dtFrom, "D.M.Y");
      else if (isFullHour1  ) comment = "seit "+      DateToStr(dtFrom, "D.M.Y H:I");
      else if (isFullMinute1) comment = "seit "+      DateToStr(dtFrom, "D.M.Y H:I");
      else                    comment = "seit "+      DateToStr(dtFrom, "D.M.Y H:I:S");
   }
   else if (!dtFrom) {
      if      (isFullYear2  ) comment =  "bis "+      DateToStr(dtTo,          "Y");
      else if (isFullMonth2 ) comment =  "bis "+      DateToStr(dtTo,          "O Y");
      else if (isFullWeek2  ) comment =  "bis "+      DateToStr(dtTo,          "D.M.Y");
      else if (isFullDay2   ) comment =  "bis "+      DateToStr(dtTo,          "D.M.Y");
      else if (isFullHour2  ) comment =  "bis "+      DateToStr(dtTo+1*SECOND, "D.M.Y H:I");
      else if (isFullMinute2) comment =  "bis "+      DateToStr(dtTo+1*SECOND, "D.M.Y H:I");
      else                    comment =  "bis "+      DateToStr(dtTo,          "D.M.Y H:I:S");
   }
   else {
      // von und bis angegeben
      if      (isFullYear1  ) {
         if      (isFullYear2  ) comment = DateToStr(dtFrom, "Y")           +" bis "+ DateToStr(dtTo,          "Y");                // 2014 - 2015
         else if (isFullMonth2 ) comment = DateToStr(dtFrom, "O Y")         +" bis "+ DateToStr(dtTo,          "O Y");              // 2014 - 2015.01
         else if (isFullWeek2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014 - 2015.01.15W
         else if (isFullDay2   ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014 - 2015.01.15
         else if (isFullHour2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014 - 2015.01.15 12:00
         else if (isFullMinute2) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014 - 2015.01.15 12:34
         else                    comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y H:I:S");      // 2014 - 2015.01.15 12:34:56
      }
      else if (isFullMonth1 ) {
         if      (isFullYear2  ) comment = DateToStr(dtFrom, "O Y")         +" bis "+ DateToStr(dtTo,          "O Y");              // 2014.01 - 2015
         else if (isFullMonth2 ) comment = DateToStr(dtFrom, "O Y")         +" bis "+ DateToStr(dtTo,          "O Y");              // 2014.01 - 2015.01
         else if (isFullWeek2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01 - 2015.01.15W
         else if (isFullDay2   ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01 - 2015.01.15
         else if (isFullHour2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01 - 2015.01.15 12:00
         else if (isFullMinute2) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01 - 2015.01.15 12:34
         else                    comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y H:I:S");      // 2014.01 - 2015.01.15 12:34:56
      }
      else if (isFullWeek1  ) {
         if      (isFullYear2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15W - 2015
         else if (isFullMonth2 ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15W - 2015.01
         else if (isFullWeek2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15W - 2015.01.15W
         else if (isFullDay2   ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15W - 2015.01.15
         else if (isFullHour2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15W - 2015.01.15 12:00
         else if (isFullMinute2) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15W - 2015.01.15 12:34
         else                    comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y H:I:S");      // 2014.01.15W - 2015.01.15 12:34:56
      }
      else if (isFullDay1   ) {
         if      (isFullYear2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 - 2015
         else if (isFullMonth2 ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 - 2015.01
         else if (isFullWeek2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 - 2015.01.15W
         else if (isFullDay2   ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 - 2015.01.15
         else if (isFullHour2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 - 2015.01.15 12:00
         else if (isFullMinute2) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 - 2015.01.15 12:34
         else                    comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y H:I:S");      // 2014.01.15 - 2015.01.15 12:34:56
      }
      else if (isFullHour1  ) {
         if      (isFullYear2  ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:00 - 2015
         else if (isFullMonth2 ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:00 - 2015.01
         else if (isFullWeek2  ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:00 - 2015.01.15W
         else if (isFullDay2   ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:00 - 2015.01.15
         else if (isFullHour2  ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 12:00 - 2015.01.15 12:00
         else if (isFullMinute2) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 12:00 - 2015.01.15 12:34
         else                    comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y H:I:S");      // 2014.01.15 12:00 - 2015.01.15 12:34:56
      }
      else if (isFullMinute1) {
         if      (isFullYear2  ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34 - 2015
         else if (isFullMonth2 ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34 - 2015.01
         else if (isFullWeek2  ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34 - 2015.01.15W
         else if (isFullDay2   ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34 - 2015.01.15
         else if (isFullHour2  ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 12:34 - 2015.01.15 12:00
         else if (isFullMinute2) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 12:34 - 2015.01.15 12:34
         else                    comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y H:I:S");      // 2014.01.15 12:34 - 2015.01.15 12:34:56
      }
      else {
         if      (isFullYear2  ) comment = DateToStr(dtFrom, "D.M.Y H:I:S") +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34:56 - 2015
         else if (isFullMonth2 ) comment = DateToStr(dtFrom, "D.M.Y H:I:S") +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34:56 - 2015.01
         else if (isFullWeek2  ) comment = DateToStr(dtFrom, "D.M.Y H:I:S") +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34:56 - 2015.01.15W
         else if (isFullDay2   ) comment = DateToStr(dtFrom, "D.M.Y H:I:S") +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34:56 - 2015.01.15
         else if (isFullHour2  ) comment = DateToStr(dtFrom, "D.M.Y H:I:S") +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 12:34:56 - 2015.01.15 12:00
         else if (isFullMinute2) comment = DateToStr(dtFrom, "D.M.Y H:I:S") +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 12:34:56 - 2015.01.15 12:34
         else                    comment = DateToStr(dtFrom, "D.M.Y H:I:S") +" bis "+ DateToStr(dtTo,          "D.M.Y H:I:S");      // 2014.01.15 12:34:56 - 2015.01.15 12:34:56
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
 * @param  _IN_     string   term              - Konfigurations-Term
 * @param  _IN_OUT_ string   positionComment   - Kommentar der Position (wird bei Gruppierungen nur bei der ersten Gruppe angezeigt)
 * @param  _IN_OUT_ string   hstComments       - dynamisch generierte History-Kommentare (werden ggf. erweitert)
 * @param  _IN_OUT_ bool     isEmptyPosition   - ob die aktuelle Position noch leer ist
 * @param  _IN_OUT_ bool     isGroupedPosition - ob die aktuelle Position eine Gruppierung enthält
 * @param  _OUT_    bool     isTotalHistory    - ob die History alle verfügbaren Trades (TRUE) oder nur die des aktuellen Symbols (FALSE) einschließt
 * @param  _OUT_    datetime from              - Beginnzeitpunkt der zu berücksichtigenden History
 * @param  _OUT_    datetime to                - Endzeitpunkt der zu berücksichtigenden History
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

   string term.orig = StringTrim(term);
          term      = StringToUpper(term.orig);
   if (!StringStartsWith(term, "H")) return(!catch("CustomPositions.ParseHstTerm(1)  invalid parameter term = "+ DoubleQuoteStr(term.orig) +" (not TERM_HISTORY_*)", ERR_INVALID_PARAMETER));
   term = StringTrim(StringRight(term, -1));

   if     (!StringStartsWith(term, "T"    )) isTotalHistory = false;
   else if (StringStartsWith(term, "THIS" )) isTotalHistory = false;
   else if (StringStartsWith(term, "TODAY")) isTotalHistory = false;
   else                                      isTotalHistory = true;
   if (isTotalHistory) term = StringTrim(StringRight(term, -1));

   bool     isSingleTimespan, groupByDay, groupByWeek, groupByMonth, isFullYear1, isFullYear2, isFullMonth1, isFullMonth2, isFullWeek1, isFullWeek2, isFullDay1, isFullDay2, isFullHour1, isFullHour2, isFullMinute1, isFullMinute2;
   datetime dtFrom, dtTo;
   string   comment = "";


   // (1) auf Group-Modifier prüfen
   if (StringEndsWith(term, " DAILY")) {
      groupByDay = true;
      term       = StringTrim(StringLeft(term, -6));
   }
   else if (StringEndsWith(term, " WEEKLY")) {
      groupByWeek = true;
      term        = StringTrim(StringLeft(term, -7));
   }
   else if (StringEndsWith(term, " MONTHLY")) {
      groupByMonth = true;
      term         = StringTrim(StringLeft(term, -8));
   }

   bool isGroupingTerm = groupByDay || groupByWeek || groupByMonth;
   if (isGroupingTerm && !isEmptyPosition) return(!catch("CustomPositions.ParseHstTerm(2)  cannot combine grouping configuration "+ DoubleQuoteStr(term.orig) +" with another configuration", ERR_INVALID_CONFIG_PARAMVALUE));
   isGroupedPosition = isGroupedPosition || isGroupingTerm;


   // (2) Beginn- und Endzeitpunkt parsen
   int pos = StringFind(term, "-");
   if (pos >= 0) {                                                   // von-bis parsen
      // {DateTime}-{DateTime}
      // {DateTime}-NULL
      //       NULL-{DateTime}
      dtFrom = ParseDateTime(StringTrim(StringLeft (term,  pos  )), isFullYear1, isFullMonth1, isFullWeek1, isFullDay1, isFullHour1, isFullMinute1); if (IsNaT(dtFrom)) return(false);
      dtTo   = ParseDateTime(StringTrim(StringRight(term, -pos-1)), isFullYear2, isFullMonth2, isFullWeek2, isFullDay2, isFullHour2, isFullMinute2); if (IsNaT(dtTo  )) return(false);
      if (dtTo != NULL) {
         if      (isFullYear2  ) dtTo  = DateTime(TimeYearFix(dtTo)+1)                  - 1*SECOND;   // Jahresende
         else if (isFullMonth2 ) dtTo  = DateTime(TimeYearFix(dtTo), TimeMonth(dtTo)+1) - 1*SECOND;   // Monatsende
         else if (isFullWeek2  ) dtTo += 1*WEEK                                         - 1*SECOND;   // Wochenende
         else if (isFullDay2   ) dtTo += 1*DAY                                          - 1*SECOND;   // Tagesende
         else if (isFullHour2  ) dtTo -=                                                  1*SECOND;   // Ende der vorhergehenden Stunde
       //else if (isFullMinute2) dtTo -=                                                  1*SECOND;   // nicht bei Minuten (deaktiviert)
      }
   }
   else {
      // {DateTime}                                                  // einzelnen Zeitraum parsen
      isSingleTimespan = true;
      dtFrom = ParseDateTime(term, isFullYear1, isFullMonth1, isFullWeek1, isFullDay1, isFullHour1, isFullMinute1); if (IsNaT(dtFrom)) return(false);
                                                                                                                         if (!dtFrom)  return(!catch("CustomPositions.ParseHstTerm(3)  invalid history configuration in "+ DoubleQuoteStr(term.orig), ERR_INVALID_CONFIG_PARAMVALUE));
      if      (isFullYear1  ) dtTo = DateTime(TimeYearFix(dtFrom)+1)                    - 1*SECOND;   // Jahresende
      else if (isFullMonth1 ) dtTo = DateTime(TimeYearFix(dtFrom), TimeMonth(dtFrom)+1) - 1*SECOND;   // Monatsende
      else if (isFullWeek1  ) dtTo = dtFrom + 1*WEEK                                    - 1*SECOND;   // Wochenende
      else if (isFullDay1   ) dtTo = dtFrom + 1*DAY                                     - 1*SECOND;   // Tagesende
      else if (isFullHour1  ) dtTo = dtFrom + 1*HOUR                                    - 1*SECOND;   // Ende der Stunde
      else if (isFullMinute1) dtTo = dtFrom + 1*MINUTE                                  - 1*SECOND;   // Ende der Minute
      else                    dtTo = dtFrom;
   }
   //debug("CustomPositions.ParseHstTerm(0.1)  dtFrom="+ TimeToStr(dtFrom, TIME_FULL) +"  dtTo="+ TimeToStr(dtTo, TIME_FULL) +"  grouped="+ isGroupingTerm);
   if (!dtFrom && !dtTo)      return(!catch("CustomPositions.ParseHstTerm(4)  invalid history configuration in "+ DoubleQuoteStr(term.orig), ERR_INVALID_CONFIG_PARAMVALUE));
   if (dtTo && dtFrom > dtTo) return(!catch("CustomPositions.ParseHstTerm(5)  invalid history configuration in "+ DoubleQuoteStr(term.orig) +" (history start after history end)", ERR_INVALID_CONFIG_PARAMVALUE));


   if (isGroupingTerm) {
      //
      // TODO:  Performance verbessern
      //

      // (3) Gruppen anlegen und komplette Zeilen direkt hier einfügen (bei der letzten Gruppe jedoch ohne Zeilenende)
      datetime groupFrom, groupTo, nextGroupFrom, now=TimeCurrentEx("CustomPositions.ParseHstTerm(6)");
      if      (groupByMonth) groupFrom = DateTime(TimeYearFix(dtFrom), TimeMonth(dtFrom));
      else if (groupByWeek ) groupFrom = dtFrom - dtFrom%DAYS - (TimeDayOfWeekFix(dtFrom)+6)%7 * DAYS;
      else if (groupByDay  ) groupFrom = dtFrom - dtFrom%DAYS;

      if (!dtTo) {                                                                                       // {DateTime} - NULL
         if      (groupByMonth) dtTo = DateTime(TimeYearFix(now), TimeMonth(now)+1)        - 1*SECOND;   // aktuelles Monatsende
         else if (groupByWeek ) dtTo = now - now%DAYS + (7-TimeDayOfWeekFix(now))%7 * DAYS - 1*SECOND;   // aktuelles Wochenende
         else if (groupByDay  ) dtTo = now - now%DAYS + 1*DAY                              - 1*SECOND;   // aktuelles Tagesende
      }

      for (bool firstGroup=true; groupFrom < dtTo; groupFrom=nextGroupFrom) {
         if      (groupByMonth) nextGroupFrom = DateTime(TimeYearFix(groupFrom), TimeMonth(groupFrom)+1);
         else if (groupByWeek ) nextGroupFrom = groupFrom + 7*DAYS;
         else if (groupByDay  ) nextGroupFrom = groupFrom + 1*DAY;
         groupTo   = nextGroupFrom - 1*SECOND;
         groupFrom = Max(groupFrom, dtFrom);
         groupTo   = Min(groupTo,   dtTo  );
         //debug("ParseHstTerm(0.2)  group from="+ TimeToStr(groupFrom) +"  to="+ TimeToStr(groupTo));

         // Kommentar erstellen
         if      (groupByMonth) comment =               DateToStr(groupFrom, "Y O");
         else if (groupByWeek ) comment = "Woche vom "+ DateToStr(groupFrom, "D.M.Y");
         else if (groupByDay  ) comment =               DateToStr(groupFrom, "D.M.Y");
         if (isTotalHistory)    comment = comment +" (gesamt)";

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
         if      (isFullYear1  ) comment =               DateToStr(dtFrom, "Y");
         else if (isFullMonth1 ) comment =               DateToStr(dtFrom, "Y O");
         else if (isFullWeek1  ) comment = "Woche vom "+ DateToStr(dtFrom, "D.M.Y");
         else if (isFullDay1   ) comment =               DateToStr(dtFrom, "D.M.Y");
         else if (isFullHour1  ) comment =               DateToStr(dtFrom, "D.M.Y H:I") + DateToStr(dtTo+1*SECOND, "-H:I");
         else if (isFullMinute1) comment =               DateToStr(dtFrom, "D.M.Y H:I");
         else                    comment =               DateToStr(dtFrom, "D.M.Y H:I:S");
      }
      else if (!dtTo) {
         if      (isFullYear1  ) comment = "seit "+      DateToStr(dtFrom, "Y");
         else if (isFullMonth1 ) comment = "seit "+      DateToStr(dtFrom, "O Y");
         else if (isFullWeek1  ) comment = "seit "+      DateToStr(dtFrom, "D.M.Y");
         else if (isFullDay1   ) comment = "seit "+      DateToStr(dtFrom, "D.M.Y");
         else if (isFullHour1  ) comment = "seit "+      DateToStr(dtFrom, "D.M.Y H:I");
         else if (isFullMinute1) comment = "seit "+      DateToStr(dtFrom, "D.M.Y H:I");
         else                    comment = "seit "+      DateToStr(dtFrom, "D.M.Y H:I:S");
      }
      else if (!dtFrom) {
         if      (isFullYear2  ) comment =  "bis "+      DateToStr(dtTo,          "Y");
         else if (isFullMonth2 ) comment =  "bis "+      DateToStr(dtTo,          "O Y");
         else if (isFullWeek2  ) comment =  "bis "+      DateToStr(dtTo,          "D.M.Y");
         else if (isFullDay2   ) comment =  "bis "+      DateToStr(dtTo,          "D.M.Y");
         else if (isFullHour2  ) comment =  "bis "+      DateToStr(dtTo+1*SECOND, "D.M.Y H:I");
         else if (isFullMinute2) comment =  "bis "+      DateToStr(dtTo+1*SECOND, "D.M.Y H:I");
         else                    comment =  "bis "+      DateToStr(dtTo,          "D.M.Y H:I:S");
      }
      else {
         // von und bis angegeben
         if      (isFullYear1  ) {
            if      (isFullYear2  ) comment = DateToStr(dtFrom, "Y")           +" bis "+ DateToStr(dtTo,          "Y");                // 2014 - 2015
            else if (isFullMonth2 ) comment = DateToStr(dtFrom, "O Y")         +" bis "+ DateToStr(dtTo,          "O Y");              // 2014 - 2015.01
            else if (isFullWeek2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014 - 2015.01.15W
            else if (isFullDay2   ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014 - 2015.01.15
            else if (isFullHour2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014 - 2015.01.15 12:00
            else if (isFullMinute2) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014 - 2015.01.15 12:34
            else                    comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y H:I:S");      // 2014 - 2015.01.15 12:34:56
         }
         else if (isFullMonth1 ) {
            if      (isFullYear2  ) comment = DateToStr(dtFrom, "O Y")         +" bis "+ DateToStr(dtTo,          "O Y");              // 2014.01 - 2015
            else if (isFullMonth2 ) comment = DateToStr(dtFrom, "O Y")         +" bis "+ DateToStr(dtTo,          "O Y");              // 2014.01 - 2015.01
            else if (isFullWeek2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01 - 2015.01.15W
            else if (isFullDay2   ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01 - 2015.01.15
            else if (isFullHour2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01 - 2015.01.15 12:00
            else if (isFullMinute2) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01 - 2015.01.15 12:34
            else                    comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y H:I:S");      // 2014.01 - 2015.01.15 12:34:56
         }
         else if (isFullWeek1  ) {
            if      (isFullYear2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15W - 2015
            else if (isFullMonth2 ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15W - 2015.01
            else if (isFullWeek2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15W - 2015.01.15W
            else if (isFullDay2   ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15W - 2015.01.15
            else if (isFullHour2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15W - 2015.01.15 12:00
            else if (isFullMinute2) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15W - 2015.01.15 12:34
            else                    comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y H:I:S");      // 2014.01.15W - 2015.01.15 12:34:56
         }
         else if (isFullDay1   ) {
            if      (isFullYear2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 - 2015
            else if (isFullMonth2 ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 - 2015.01
            else if (isFullWeek2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 - 2015.01.15W
            else if (isFullDay2   ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 - 2015.01.15
            else if (isFullHour2  ) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 - 2015.01.15 12:00
            else if (isFullMinute2) comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 - 2015.01.15 12:34
            else                    comment = DateToStr(dtFrom, "D.M.Y")       +" bis "+ DateToStr(dtTo,          "D.M.Y H:I:S");      // 2014.01.15 - 2015.01.15 12:34:56
         }
         else if (isFullHour1  ) {
            if      (isFullYear2  ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:00 - 2015
            else if (isFullMonth2 ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:00 - 2015.01
            else if (isFullWeek2  ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:00 - 2015.01.15W
            else if (isFullDay2   ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:00 - 2015.01.15
            else if (isFullHour2  ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 12:00 - 2015.01.15 12:00
            else if (isFullMinute2) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 12:00 - 2015.01.15 12:34
            else                    comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y H:I:S");      // 2014.01.15 12:00 - 2015.01.15 12:34:56
         }
         else if (isFullMinute1) {
            if      (isFullYear2  ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34 - 2015
            else if (isFullMonth2 ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34 - 2015.01
            else if (isFullWeek2  ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34 - 2015.01.15W
            else if (isFullDay2   ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34 - 2015.01.15
            else if (isFullHour2  ) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 12:34 - 2015.01.15 12:00
            else if (isFullMinute2) comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 12:34 - 2015.01.15 12:34
            else                    comment = DateToStr(dtFrom, "D.M.Y H:I")   +" bis "+ DateToStr(dtTo,          "D.M.Y H:I:S");      // 2014.01.15 12:34 - 2015.01.15 12:34:56
         }
         else {
            if      (isFullYear2  ) comment = DateToStr(dtFrom, "D.M.Y H:I:S") +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34:56 - 2015
            else if (isFullMonth2 ) comment = DateToStr(dtFrom, "D.M.Y H:I:S") +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34:56 - 2015.01
            else if (isFullWeek2  ) comment = DateToStr(dtFrom, "D.M.Y H:I:S") +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34:56 - 2015.01.15W
            else if (isFullDay2   ) comment = DateToStr(dtFrom, "D.M.Y H:I:S") +" bis "+ DateToStr(dtTo,          "D.M.Y");            // 2014.01.15 12:34:56 - 2015.01.15
            else if (isFullHour2  ) comment = DateToStr(dtFrom, "D.M.Y H:I:S") +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 12:34:56 - 2015.01.15 12:00
            else if (isFullMinute2) comment = DateToStr(dtFrom, "D.M.Y H:I:S") +" bis "+ DateToStr(dtTo+1*SECOND, "D.M.Y H:I");        // 2014.01.15 12:34:56 - 2015.01.15 12:34
            else                    comment = DateToStr(dtFrom, "D.M.Y H:I:S") +" bis "+ DateToStr(dtTo,          "D.M.Y H:I:S");      // 2014.01.15 12:34:56 - 2015.01.15 12:34:56
         }
      }
      if (isTotalHistory) comment = comment +" (gesamt)";
      from = dtFrom;
      to   = dtTo;
   }

   if (!StringLen(hstComments)) hstComments = comment;
   else                         hstComments = hstComments +", "+ comment;
   return(!catch("CustomPositions.ParseHstTerm(7)"));
}


/**
 * Parst eine Zeitpunktbeschreibung. Kann ein allgemeiner Zeitraum (2014.03) oder ein genauer Zeitpunkt (2014.03.12 12:34:56) sein.
 *
 * @param  _IN_  string value    - zu parsender String
 * @param  _OUT_ bool   isYear   - ob ein allgemein formulierter Zeitraum ein Jahr beschreibt,    z.B. "2014"        oder "ThisYear"
 * @param  _OUT_ bool   isMonth  - ob ein allgemein formulierter Zeitraum einen Monat beschreibt, z.B. "2014.02"     oder "LastMonth"
 * @param  _OUT_ bool   isWeek   - ob ein allgemein formulierter Zeitraum eine Woche beschreibt,  z.B. "2014.02.15W" oder "ThisWeek"
 * @param  _OUT_ bool   isDay    - ob ein allgemein formulierter Zeitraum einen Tag beschreibt,   z.B. "2014.02.18"  oder "Yesterday" (Synonym für LastDay)
 * @param  _OUT_ bool   isHour   - ob ein allgemein formulierter Zeitraum eine Stunde beschreibt, z.B. "2014.02.18 12:00"
 * @param  _OUT_ bool   isMinute - ob ein allgemein formulierter Zeitraum eine Minute beschreibt, z.B. "2014.02.18 12:34"
 *
 * @return datetime - Zeitpunkt oder NaT (Not-A-Time), falls ein Fehler auftrat
 *
 *
 * Format:
 * -------
 *  {value} = 2014[.01[.15 [W|12:34[:56]]]]        oder
 *  {value} = (This|Last)(Day|Week|Month|Year)     oder
 *  {value} = Today                                • Synonym für ThisDay
 *  {value} = Yesterday                            • Synonym für LastDay
 */
datetime ParseDateTime(string value, bool &isYear, bool &isMonth, bool &isWeek, bool &isDay, bool &isHour, bool &isMinute) {
   string   value.orig=value, values[], sYY, sMM, sDD, sTime, sHH, sII, sSS;
   int      valuesSize, iYY, iMM, iDD, iHH, iII, iSS, dow;

   static datetime now;
          datetime date;

   value = StringTrim(value);
   if (!StringLen(value)) return(NULL);

   isYear   = false;
   isMonth  = false;
   isWeek   = false;
   isDay    = false;
   isHour   = false;
   isMinute = false;


   // (1) Ausdruck parsen
   if (!StringIsDigit(StringLeft(value, 1))) {
      if (!now) now = TimeFXT(); if (!now) return(NaT);

      // (1.1) alphabetischer Ausdruck
      if (StringEndsWith(value, "DAY")) {
         if      (value == "TODAY"    ) value = "THISDAY";
         else if (value == "YESTERDAY") value = "LASTDAY";

         date = now;
         dow  = TimeDayOfWeekFix(date);
         if      (dow == SATURDAY) date -= 1*DAY;                    // an Wochenenden Datum auf den vorherigen Freitag setzen
         else if (dow == SUNDAY  ) date -= 2*DAYS;

         if (value != "THISDAY") {
            if (value != "LASTDAY")                                  return(_NaT(catch("ParseDateTime(1)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
            if (dow != MONDAY) date -= 1*DAY;                        // Datum auf den vorherigen Tag setzen
            else               date -= 3*DAYS;                       // an Wochenenden Datum auf den vorherigen Freitag setzen
         }
         iYY   = TimeYearFix(date);
         iMM   = TimeMonth  (date);
         iDD   = TimeDayFix (date);
         isDay = true;
      }

      else if (StringEndsWith(value, "WEEK")) {
         date = now - (TimeDayOfWeekFix(now)+6)%7 * DAYS;            // Datum auf Wochenbeginn setzen
         if (value != "THISWEEK") {
            if (value != "LASTWEEK")                                 return(_NaT(catch("ParseDateTime(1)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
            date -= 1*WEEK;                                          // Datum auf die vorherige Woche setzen
         }
         iYY    = TimeYearFix(date);
         iMM    = TimeMonth  (date);
         iDD    = TimeDayFix (date);
         isWeek = true;
      }

      else if (StringEndsWith(value, "MONTH")) {
         date = now;
         if (value != "THISMONTH") {
            if (value != "LASTMONTH")                                return(_NaT(catch("ParseDateTime(1)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
            date = DateTime(TimeYearFix(date), TimeMonth(date)-1);   // Datum auf den vorherigen Monat setzen
         }
         iYY     = TimeYearFix(date);
         iMM     = TimeMonth  (date);
         iDD     = 1;
         isMonth = true;
      }

      else if (StringEndsWith(value, "YEAR")) {
         date = now;
         if (value != "THISYEAR") {
            if (value != "LASTYEAR")                                 return(_NaT(catch("ParseDateTime(1)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
            date = DateTime(TimeYearFix(date)-1);                    // Datum auf das vorherige Jahr setzen
         }
         iYY    = TimeYearFix(date);
         iMM    = 1;
         iDD    = 1;
         isYear = true;
      }
      else                                                           return(_NaT(catch("ParseDateTime(1)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
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
      if (valuesSize > 3)                                            return(_NaT(catch("ParseDateTime(2)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));

      if (valuesSize >= 1) {
         sYY = StringTrim(values[0]);                                // Jahr prüfen
         if (StringLen(sYY) != 4)                                    return(_NaT(catch("ParseDateTime(3)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
         if (!StringIsDigit(sYY))                                    return(_NaT(catch("ParseDateTime(4)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
         iYY = StrToInteger(sYY);
         if (iYY < 1970 || 2037 < iYY)                               return(_NaT(catch("ParseDateTime(5)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
         if (valuesSize == 1) {
            iMM    = 1;
            iDD    = 1;
            isYear = true;
         }
      }

      if (valuesSize >= 2) {
         sMM = StringTrim(values[1]);                                // Monat prüfen
         if (StringLen(sMM) > 2)                                     return(_NaT(catch("ParseDateTime(6)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
         if (!StringIsDigit(sMM))                                    return(_NaT(catch("ParseDateTime(7)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
         iMM = StrToInteger(sMM);
         if (iMM < 1 || 12 < iMM)                                    return(_NaT(catch("ParseDateTime(8)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
         if (valuesSize == 2) {
            iDD     = 1;
            isMonth = true;
         }
      }

      if (valuesSize == 3) {
         sDD = StringTrim(values[2]);
         if (StringEndsWith(sDD, "W")) {                             // Tag + Woche: "2014.01.15 W"
            isWeek = true;
            sDD    = StringTrim(StringLeft(sDD, -1));
         }
         else if (StringLen(sDD) > 2) {                              // Tag + Zeit:  "2014.01.15 12:34:56"
            int pos = StringFind(sDD, " ");
            if (pos == -1)                                           return(_NaT(catch("ParseDateTime(9)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
            sTime = StringTrim(StringRight(sDD, -pos-1));
            sDD   = StringTrim(StringLeft (sDD,  pos  ));
         }
         else {                                                      // nur Tag
            isDay = true;
         }
                                                                     // Tag prüfen
         if (StringLen(sDD) > 2)                                     return(_NaT(catch("ParseDateTime(10)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
         if (!StringIsDigit(sDD))                                    return(_NaT(catch("ParseDateTime(11)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
         iDD = StrToInteger(sDD);
         if (iDD < 1 || 31 < iDD)                                    return(_NaT(catch("ParseDateTime(12)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
         if (iDD > 28) {
            if (iMM == FEB) {
               if (iDD > 29)                                         return(_NaT(catch("ParseDateTime(13)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
               if (!IsLeapYear(iYY))                                 return(_NaT(catch("ParseDateTime(14)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
            }
            else if (iDD==31)
               if (iMM==APR || iMM==JUN || iMM==SEP || iMM==NOV)     return(_NaT(catch("ParseDateTime(15)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
         }

         if (StringLen(sTime) > 0) {                                 // Zeit prüfen
            // hh:ii:ss
            valuesSize = Explode(sTime, ":", values, NULL);
            if (valuesSize < 2 || 3 < valuesSize)                    return(_NaT(catch("ParseDateTime(16)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));

            sHH = StringTrim(values[0]);                             // Stunden
            if (StringLen(sHH) > 2)                                  return(_NaT(catch("ParseDateTime(17)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
            if (!StringIsDigit(sHH))                                 return(_NaT(catch("ParseDateTime(18)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
            iHH = StrToInteger(sHH);
            if (iHH < 0 || 23 < iHH)                                 return(_NaT(catch("ParseDateTime(19)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));

            sII = StringTrim(values[1]);                             // Minuten
            if (StringLen(sII) > 2)                                  return(_NaT(catch("ParseDateTime(20)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
            if (!StringIsDigit(sII))                                 return(_NaT(catch("ParseDateTime(21)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
            iII = StrToInteger(sII);
            if (iII < 0 || 59 < iII)                                 return(_NaT(catch("ParseDateTime(22)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
            if (valuesSize == 2) {
               if (!iII) isHour   = true;
               else      isMinute = true;
            }

            if (valuesSize == 3) {
               sSS = StringTrim(values[2]);                          // Sekunden
               if (StringLen(sSS) > 2)                               return(_NaT(catch("ParseDateTime(23)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
               if (!StringIsDigit(sSS))                              return(_NaT(catch("ParseDateTime(24)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
               iSS = StrToInteger(sSS);
               if (iSS < 0 || 59 < iSS)                              return(_NaT(catch("ParseDateTime(25)  invalid history configuration in "+ DoubleQuoteStr(value.orig), ERR_INVALID_CONFIG_PARAMVALUE)));
            }
         }
      }
   }


   // (2) DateTime aus geparsten Werten erzeugen
   datetime result = DateTime(iYY, iMM, iDD, iHH, iII, iSS);
   if (isWeek)                                                       // wenn volle Woche, dann Zeit auf Wochenbeginn setzen
      result -= (TimeDayOfWeekFix(result)+6)%7 * DAYS;
   return(result);
}


/**
 * Extrahiert aus dem Bestand der übergebenen Positionen {fromVars} eine Teilposition und fügt sie dem Bestand einer CustomPosition {customVars} hinzu.
 *
 *                                                                     -+    struct POSITION_CONFIG_TERM {
 * @param  _IN_     int     type           - zu extrahierender Typ      |       double type;
 * @param  _IN_     double  value1         - zu extrahierende Lotsize   |       double confValue1;
 * @param  _IN_     double  value2         - Preis/Betrag/Equity        +->     double confValue2;
 * @param  _IN_OUT_ double &cache1         - Zwischenspeicher 1         |       double cacheValue1;
 * @param  _IN_OUT_ double &cache2         - Zwischenspeicher 2         |       double cacheValue2;
 *                                                                     -+    };
 *
 * @param  _IN_OUT_ mixed &fromVars        - Variablen, aus denen die Teilposition extrahiert wird (Bestand verringert sich)
 * @param  _IN_OUT_ mixed &customVars      - Variablen, denen die extrahierte Position hinzugefügt wird (Bestand erhöht sich)
 * @param  _IN_OUT_ bool  &isCustomVirtual - ob die resultierende CustomPosition virtuell ist
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
            double openPrice = ifDouble(value2, value2, Ask);
            ArrayPushInt   (customTickets,     TERM_OPEN_LONG                                );
            ArrayPushInt   (customTypes,       OP_BUY                                        );
            ArrayPushDouble(customLots,        lotsize                                       );
            ArrayPushDouble(customOpenPrices,  openPrice                                     );
            ArrayPushDouble(customCommissions, NormalizeDouble(-GetCommission() * lotsize, 2));
            ArrayPushDouble(customSwaps,       0                                             );
            ArrayPushDouble(customProfits,     (Bid-openPrice)/Pips * PipValue(lotsize, true)); // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
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
            openPrice = ifDouble(value2, value2, Bid);
            ArrayPushInt   (customTickets,     TERM_OPEN_SHORT                               );
            ArrayPushInt   (customTypes,       OP_SELL                                       );
            ArrayPushDouble(customLots,        lotsize                                       );
            ArrayPushDouble(customOpenPrices,  openPrice                                     );
            ArrayPushDouble(customCommissions, NormalizeDouble(-GetCommission() * lotsize, 2));
            ArrayPushDouble(customSwaps,       0                                             );
            ArrayPushDouble(customProfits,     (openPrice-Ask)/Pips * PipValue(lotsize, true)); // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
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
      warn("ExtractPosition(1)  type=TERM_OPEN_ALL not yet implemented");
   }

   else if (type==TERM_HISTORY_SYMBOL || type==TERM_HISTORY_ALL) {
      // geschlossene Positionen des aktuellen oder aller Symbole eines Zeitraumes
      from              = value1;
      to                = value2;
      double lastProfit = cache1;
      int    lastOrders = cache2;                                             // Anzahl der Tickets in der History: ändert sie sich, wird der Profit neu berechnet

      int orders=OrdersHistoryTotal(), _orders=orders;

      if (lastProfit==EMPTY_VALUE || orders!=lastOrders) {
         // (1) Sortierschlüssel aller geschlossenen Positionen auslesen und nach {CloseTime, OpenTime, Ticket} sortieren
         int sortKeys[][3], n, hst.ticket;                                    // {CloseTime, OpenTime, Ticket}
         ArrayResize(sortKeys, orders);

         for (i=0; i < orders; i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))                 // FALSE: während des Auslesens wurde der Anzeigezeitraum der History verkürzt
               break;

            // wenn OrderType()==OP_BALANCE, dann OrderSymbol()==Leerstring
            if (OrderType() == OP_BALANCE) {
               // Dividenden                                                  // "Ex Dividend US2000" oder
               if (StringStartsWithI(OrderComment(), "ex dividend ")) {       // "Ex Dividend 17/03/15 US2000"
                  if (type == TERM_HISTORY_SYMBOL)                            // single history
                     if (!StringEndsWithI(OrderComment(), " "+ Symbol()))     // ok, wenn zum aktuellen Symbol gehörend
                        continue;
               }
               // Rollover adjustments
               else if (StringStartsWithI(OrderComment(), "adjustment ")) {   // "Adjustment BRENT"
                  if (type == TERM_HISTORY_SYMBOL)                            // single history
                     if (!StringEndsWithI(OrderComment(), " "+ Symbol()))     // ok, wenn zum aktuellen Symbol gehörend
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
               if (!StringStartsWithI(hst.comments[i], "close hedge by #"))
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
         lastProfit = NormalizeDouble(lastProfit, 2);
         cache1     = lastProfit;
         cache2     = _orders;
         //debug("ExtractPosition(6)  from="+ ifString(from, TimeToStr(from), "start") +"  to="+ ifString(to, TimeToStr(to), "end") +"  profit="+ DoubleToStr(lastProfit, 2) +"  trades="+ n);
      }
      // Betrag zu closedProfit hinzufügen (Ausgangsdaten bleiben unverändert)
      closedProfit += lastProfit;
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
 * Speichert die übergebenen Daten zusammengefaßt (direktionaler und gehedgeter Anteil gemeinsam) als eine Position in den globalen Variablen positions.~data[].
 *
 * @param  _IN_ bool   isVirtual
 *
 * @param  _IN_ double longPosition
 * @param  _IN_ double shortPosition
 * @param  _IN_ double totalPosition
 *
 * @param  _IN_ int    tickets    []
 * @param  _IN_ int    types      []
 * @param  _IN_ double lots       []
 * @param  _IN_ double openPrices []
 * @param  _IN_ double commissions[]
 * @param  _IN_ double swaps      []
 * @param  _IN_ double profits    []
 *
 * @param  _IN_ double closedProfit
 * @param  _IN_ double adjustedProfit
 * @param  _IN_ double customEquity
 * @param  _IN_ int    commentIndex
 *
 * @return bool - Erfolgsstatus
 */
bool StorePosition(bool isVirtual, double longPosition, double shortPosition, double totalPosition, int &tickets[], int types[], double &lots[], double openPrices[], double &commissions[], double &swaps[], double &profits[], double closedProfit, double adjustedProfit, double customEquity, int commentIndex) {
   isVirtual = isVirtual!=0;

   double hedgedLots, remainingLong, remainingShort, factor, openPrice, closePrice, commission, swap, floatingProfit, hedgedProfit, openProfit, fullProfit, equity, pipValue, pipDistance;
   int size, ticketsSize=ArraySize(tickets);

   // Enthält die Position weder OpenProfit (offene Positionen) noch ClosedProfit, wird sie übersprungen.
   if (!longPosition) /*&&*/ if (!shortPosition) /*&&*/ if (!totalPosition) /*&&*/ if (!closedProfit)       // Ein Test auf (ticketsSize != 0) reicht nicht aus, da alle Tickets
      return(true);                                                                                         // in tickets[] bereits auf NULL gesetzt worden sein können.

   static double externalAssets = EMPTY_VALUE;
   if (IsEmptyValue(externalAssets)) {
      if (mode.intern) { string companyId = ShortAccountCompany(); string accountId = GetAccountNumber();   }
      else             {        companyId = external.signalProvider;      accountId = external.signalAlias; }
      externalAssets = GetExternalAssets(companyId, accountId); if (IsEmptyValue(externalAssets)) return(false);
   }

   if (customEquity != NULL) equity  = customEquity;                 // TODO: tatsächlichen Wert von openEquity ermitteln
   else                    { equity  = externalAssets;
      if (mode.intern)       equity += (AccountEquity()-AccountCredit());
   }

   // Die Position besteht aus einem gehedgtem Anteil (konstanter Profit) und einem direktionalen Anteil (variabler Profit).
   // - kein direktionaler Anteil:  BE-Distance in Pips berechnen
   // - direktionaler Anteil:       Breakeven unter Berücksichtigung des Profits eines gehedgten Anteils berechnen


   // (1) Profit und BE-Distance einer eventuellen Hedgeposition ermitteln
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
               openPrice     = NormalizeDouble(openPrice + lots[i] * openPrices[i], 8);
               swap         += swaps      [i];
               commission   += commissions[i];
               remainingLong = NormalizeDouble(remainingLong - lots[i], 3);
               tickets[i]    = NULL;
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor        = remainingLong/lots[i];
               openPrice     = NormalizeDouble(openPrice + remainingLong * openPrices[i], 8);
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
               closePrice     = NormalizeDouble(closePrice + lots[i] * openPrices[i], 8);
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
      if (remainingLong  != 0) return(!catch("StorePosition(1)  illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR));
      if (remainingShort != 0) return(!catch("StorePosition(2)  illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of hedged position = "+ NumberToStr(hedgedLots, ".+"), ERR_RUNTIME_ERROR));

      // BE-Distance und Profit berechnen
      pipValue = PipValue(hedgedLots, true);                                           // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
      if (pipValue != 0) {
         pipDistance  = NormalizeDouble((closePrice-openPrice)/hedgedLots/Pips + (commission+swap)/pipValue, 8);
         hedgedProfit = pipDistance * pipValue;
      }

      // (1.1) Kein direktionaler Anteil: Hedge-Position speichern und Rückkehr
      if (!totalPosition) {
         size = ArrayRange(positions.idata, 0);
         ArrayResize(positions.idata, size+1);
         ArrayResize(positions.ddata, size+1);

         positions.idata[size][I_CONFIG_TYPE     ] = ifInt(isVirtual, CONFIG_VIRTUAL, CONFIG_REAL);
         positions.idata[size][I_POSITION_TYPE   ] = POSITION_HEDGE;
         positions.idata[size][I_COMMENT_INDEX   ] = commentIndex;

         positions.ddata[size][I_DIRECTIONAL_LOTS] = 0;
         positions.ddata[size][I_HEDGED_LOTS     ] = hedgedLots;
         positions.ddata[size][I_PIP_DISTANCE    ] = pipDistance;

         positions.ddata[size][I_OPEN_EQUITY     ] = equity;         openProfit = hedgedProfit;
         positions.ddata[size][I_OPEN_PROFIT     ] = openProfit;
         positions.ddata[size][I_CLOSED_PROFIT   ] = closedProfit;
         positions.ddata[size][I_ADJUSTED_PROFIT ] = adjustedProfit; fullProfit = openProfit + closedProfit + adjustedProfit;
         positions.ddata[size][I_FULL_PROFIT_ABS ] = fullProfit;
         positions.ddata[size][I_FULL_PROFIT_PCT ] = MathDiv(fullProfit, equity-fullProfit) * 100;
         return(!catch("StorePosition(3)"));
      }
   }


   // (2) Direktionaler Anteil: Bei Breakeven-Berechnung den Profit eines gehedgten Anteils und AdjustedProfit berücksichtigen.
   // (2.1) eventuelle Longposition ermitteln
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
               openPrice       = NormalizeDouble(openPrice + lots[i] * openPrices[i], 8);
               swap           += swaps      [i];
               commission     += commissions[i];
               floatingProfit += profits    [i];
               tickets[i]      = NULL;
               remainingLong   = NormalizeDouble(remainingLong - lots[i], 3);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor          = remainingLong/lots[i];
               openPrice       = NormalizeDouble(openPrice + remainingLong * openPrices[i], 8);
               swap           +=          swaps      [i]; swaps      [i]  = 0;
               commission     += factor * commissions[i]; commissions[i] -= factor * commissions[i];
               floatingProfit += factor * profits    [i]; profits    [i] -= factor * profits    [i];
                                                          lots       [i]  = NormalizeDouble(lots[i]-remainingLong, 3);
               remainingLong = 0;
            }
         }
      }
      if (remainingLong != 0) return(!catch("StorePosition(4)  illegal remaining long position = "+ NumberToStr(remainingLong, ".+") +" of long position = "+ NumberToStr(totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      size = ArrayRange(positions.idata, 0);
      ArrayResize(positions.idata, size+1);
      ArrayResize(positions.ddata, size+1);

      positions.idata[size][I_CONFIG_TYPE     ] = ifInt(isVirtual, CONFIG_VIRTUAL, CONFIG_REAL);
      positions.idata[size][I_POSITION_TYPE   ] = POSITION_LONG;
      positions.idata[size][I_COMMENT_INDEX   ] = commentIndex;

      positions.ddata[size][I_DIRECTIONAL_LOTS] = totalPosition;
      positions.ddata[size][I_HEDGED_LOTS     ] = hedgedLots;
      positions.ddata[size][I_BREAKEVEN_PRICE ] = NULL;

      positions.ddata[size][I_OPEN_EQUITY     ] = equity;         openProfit = hedgedProfit + commission + swap + floatingProfit;
      positions.ddata[size][I_OPEN_PROFIT     ] = openProfit;
      positions.ddata[size][I_CLOSED_PROFIT   ] = closedProfit;
      positions.ddata[size][I_ADJUSTED_PROFIT ] = adjustedProfit; fullProfit = openProfit + closedProfit + adjustedProfit;
      positions.ddata[size][I_FULL_PROFIT_ABS ] = fullProfit;
      positions.ddata[size][I_FULL_PROFIT_PCT ] = MathDiv(fullProfit, equity-fullProfit) * 100;

      pipValue = PipValue(totalPosition, true);                      // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
      if (pipValue != 0)
         positions.ddata[size][I_BREAKEVEN_PRICE] = RoundCeil(openPrice/totalPosition - (fullProfit-floatingProfit)/pipValue*Pips, Digits);
      return(!catch("StorePosition(5)"));
   }


   // (2.2) eventuelle Shortposition ermitteln
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
               openPrice       = NormalizeDouble(openPrice + lots[i] * openPrices[i], 8);
               swap           += swaps      [i];
               commission     += commissions[i];
               floatingProfit += profits    [i];
               tickets[i]      = NULL;
               remainingShort  = NormalizeDouble(remainingShort - lots[i], 3);
            }
            else {
               // Daten anteilig übernehmen: Swap komplett, Commission, Profit und Lotsize des Tickets reduzieren
               factor          = remainingShort/lots[i];
               openPrice       = NormalizeDouble(openPrice + remainingShort * openPrices[i], 8);
               swap           +=          swaps      [i]; swaps      [i]  = 0;
               commission     += factor * commissions[i]; commissions[i] -= factor * commissions[i];
               floatingProfit += factor * profits    [i]; profits    [i] -= factor * profits    [i];
                                                          lots       [i]  = NormalizeDouble(lots[i]-remainingShort, 3);
               remainingShort = 0;
            }
         }
      }
      if (remainingShort != 0) return(!catch("StorePosition(6)  illegal remaining short position = "+ NumberToStr(remainingShort, ".+") +" of short position = "+ NumberToStr(-totalPosition, ".+"), ERR_RUNTIME_ERROR));

      // Position speichern
      size = ArrayRange(positions.idata, 0);
      ArrayResize(positions.idata, size+1);
      ArrayResize(positions.ddata, size+1);

      positions.idata[size][I_CONFIG_TYPE     ] = ifInt(isVirtual, CONFIG_VIRTUAL, CONFIG_REAL);
      positions.idata[size][I_POSITION_TYPE   ] = POSITION_SHORT;
      positions.idata[size][I_COMMENT_INDEX   ] = commentIndex;

      positions.ddata[size][I_DIRECTIONAL_LOTS] = -totalPosition;
      positions.ddata[size][I_HEDGED_LOTS     ] = hedgedLots;
      positions.ddata[size][I_BREAKEVEN_PRICE ] = NULL;

      positions.ddata[size][I_OPEN_EQUITY     ] = equity;         openProfit = hedgedProfit + commission + swap + floatingProfit;
      positions.ddata[size][I_OPEN_PROFIT     ] = openProfit;
      positions.ddata[size][I_CLOSED_PROFIT   ] = closedProfit;
      positions.ddata[size][I_ADJUSTED_PROFIT ] = adjustedProfit; fullProfit = openProfit + closedProfit + adjustedProfit;
      positions.ddata[size][I_FULL_PROFIT_ABS ] = fullProfit;
      positions.ddata[size][I_FULL_PROFIT_PCT ] = MathDiv(fullProfit, equity-fullProfit) * 100;


      pipValue = PipValue(-totalPosition, true);                     // Fehler unterdrücken, INIT_PIPVALUE ist u.U. nicht gesetzt
      if (pipValue != 0)
         positions.ddata[size][I_BREAKEVEN_PRICE] = RoundFloor((fullProfit-floatingProfit)/pipValue*Pips - openPrice/totalPosition, Digits);
      return(!catch("StorePosition(7)"));
   }


   // (2.3) ohne offene Positionen muß ClosedProfit gesetzt sein
   if (closedProfit != 0) {
      // History mit leerer Position speichern
      size = ArrayRange(positions.idata, 0);
      ArrayResize(positions.idata, size+1);
      ArrayResize(positions.ddata, size+1);

      positions.idata[size][I_CONFIG_TYPE     ] = ifInt(isVirtual, CONFIG_VIRTUAL, CONFIG_REAL);
      positions.idata[size][I_POSITION_TYPE   ] = POSITION_HISTORY;
      positions.idata[size][I_COMMENT_INDEX   ] = commentIndex;

      positions.ddata[size][I_DIRECTIONAL_LOTS] = NULL;
      positions.ddata[size][I_HEDGED_LOTS     ] = NULL;
      positions.ddata[size][I_BREAKEVEN_PRICE ] = NULL;

      positions.ddata[size][I_OPEN_EQUITY     ] = equity;         openProfit = 0;
      positions.ddata[size][I_OPEN_PROFIT     ] = openProfit;
      positions.ddata[size][I_CLOSED_PROFIT   ] = closedProfit;
      positions.ddata[size][I_ADJUSTED_PROFIT ] = adjustedProfit; fullProfit = openProfit + closedProfit + adjustedProfit;
      positions.ddata[size][I_FULL_PROFIT_ABS ] = fullProfit;
      positions.ddata[size][I_FULL_PROFIT_PCT ] = MathDiv(fullProfit, equity-fullProfit) * 100;
      return(!catch("StorePosition(8)"));
   }

   return(!catch("StorePosition(9)  unreachable code reached", ERR_RUNTIME_ERROR));
}


/**
 * Handler für beim LFX-Terminal eingehende Messages.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.HandleLfxTerminalMessages() {
   if (!__CHART)
      return(true);

   // (1) ggf. Receiver starten
   if (!hQC.TradeToLfxReceiver) /*&&*/ if (!QC.StartLfxReceiver())
      return(false);

   // (2) Channel auf neue Messages prüfen
   int result = QC_CheckChannel(qc.TradeToLfxChannel);
   if (result == QC_CHECK_CHANNEL_EMPTY)
      return(true);
   if (result < QC_CHECK_CHANNEL_EMPTY) {
      if (result == QC_CHECK_CHANNEL_ERROR)    return(!catch("QC.HandleLfxTerminalMessages(1)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeToLfxChannel +"\") => QC_CHECK_CHANNEL_ERROR",           ERR_WIN32_ERROR));
      if (result == QC_CHECK_CHANNEL_NONE )    return(!catch("QC.HandleLfxTerminalMessages(2)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeToLfxChannel +"\")  channel doesn't exist",              ERR_WIN32_ERROR));
                                               return(!catch("QC.HandleLfxTerminalMessages(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeToLfxChannel +"\")  unexpected return value = "+ result, ERR_WIN32_ERROR));
   }

   // (3) neue Messages abholen
   string messageBuffer[]; if (!ArraySize(messageBuffer)) InitializeStringBuffer(messageBuffer, QC_MAX_BUFFER_SIZE);
   result = QC_GetMessages3(hQC.TradeToLfxReceiver, messageBuffer, QC_MAX_BUFFER_SIZE);
   if (result != QC_GET_MSG3_SUCCESS) {
      if (result == QC_GET_MSG3_CHANNEL_EMPTY) return(!catch("QC.HandleLfxTerminalMessages(4)->MT4iQuickChannel::QC_GetMessages3()  QC_CheckChannel not empty/QC_GET_MSG3_CHANNEL_EMPTY mismatch",           ERR_WIN32_ERROR));
      if (result == QC_GET_MSG3_INSUF_BUFFER ) return(!catch("QC.HandleLfxTerminalMessages(5)->MT4iQuickChannel::QC_GetMessages3()  buffer to small (QC_MAX_BUFFER_SIZE/QC_GET_MSG3_INSUF_BUFFER mismatch)", ERR_WIN32_ERROR));
                                               return(!catch("QC.HandleLfxTerminalMessages(6)->MT4iQuickChannel::QC_GetMessages3()  unexpected return value = "+ result,                                     ERR_WIN32_ERROR));
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
 * @return bool - Erfolgsstatus: Ob die Message erfolgreich verarbeitet wurde. Ein falsches Messageformat oder keine zur Message passende Order sind kein Fehler,
 *                               das Auslösen eines Fehlers durch Schicken einer falschen Message ist so nicht möglich. Für nicht unterstützte Messages wird
 *                               stattdessen eine Warnung ausgegeben.
 *
 *  Messageformat: "LFX:{iTicket]:pending={1|0}"   - die angegebene Pending-Order wurde platziert (immer erfolgreich, da im Fehlerfall keine Message generiert wird)
 *                 "LFX:{iTicket]:open={1|0}"      - die angegebene Pending-Order wurde ausgeführt/konnte nicht ausgeführt werden
 *                 "LFX:{iTicket]:close={1|0}"     - die angegebene Position wurde geschlossen/konnte nicht geschlossen werden
 *                 "LFX:{iTicket]:profit={dValue}" - der P/L der angegebenen Position hat sich geändert
 */
bool ProcessLfxTerminalMessage(string message) {
   // Da hier in kurzer Zeit sehr viele Messages eingehen können, werden sie zur Beschleunigung statt mit Explode() manuell zerlegt.
   // LFX-Prefix
   if (StringSubstr(message, 0, 4) != "LFX:")                                        return(_true(warn("ProcessLfxTerminalMessage(1)  unknown message format \""+ message +"\"")));
   // LFX-Ticket
   int from=4, to=StringFind(message, ":", from);                   if (to <= from)  return(_true(warn("ProcessLfxTerminalMessage(2)  unknown message \""+ message +"\" (illegal order ticket)")));
   int ticket = StrToInteger(StringSubstr(message, from, to-from)); if (ticket <= 0) return(_true(warn("ProcessLfxTerminalMessage(3)  unknown message \""+ message +"\" (illegal order ticket)")));
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
      if (success) { if (__LOG) log("ProcessLfxTerminalMessage(4)  #"+ ticket +" pending order "+ ifString(success, "confirmation", "error"                           )); }
      else         {           warn("ProcessLfxTerminalMessage(5)  #"+ ticket +" pending order "+ ifString(success, "confirmation", "error (what use case is this???)")); }
      return(RestoreLfxStatusFromFile());                                     // LFX-Status neu einlesen (auch bei Fehler)
   }

   // :open={1|0}
   if (StringSubstr(message, from, 5) == "open=") {
      success = (StrToInteger(StringSubstr(message, from+5)) != 0);
      if (__LOG) log("ProcessLfxTerminalMessage(6)  #"+ ticket +" open position "+ ifString(success, "confirmation", "error"));
      return(RestoreLfxStatusFromFile());                                     // LFX-Status neu einlesen (auch bei Fehler)
   }

   // :close={1|0}
   if (StringSubstr(message, from, 6) == "close=") {
      success = (StrToInteger(StringSubstr(message, from+6)) != 0);
      if (__LOG) log("ProcessLfxTerminalMessage(7)  #"+ ticket +" close position "+ ifString(success, "confirmation", "error"));
      return(RestoreLfxStatusFromFile());                                     // LFX-Status neu einlesen (auch bei Fehler)
   }

   // ???
   return(_true(warn("ProcessLfxTerminalMessage(8)  unknown message \""+ message +"\"")));
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
 * Handler für beim Terminal eingehende Trade-Commands.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.HandleTradeCommands() {
   if (!__CHART)
      return(true);

   // (1) ggf. Receiver starten
   if (!hQC.TradeCmdReceiver) /*&&*/ if (!QC.StartTradeCmdReceiver())
      return(false);

   // (2) Channel auf neue Messages prüfen
   int result = QC_CheckChannel(qc.TradeCmdChannel);
   if (result == QC_CHECK_CHANNEL_EMPTY)
      return(true);
   if (result < QC_CHECK_CHANNEL_EMPTY) {
      if (result == QC_CHECK_CHANNEL_ERROR)    return(!catch("QC.HandleTradeCommands(1)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeCmdChannel +"\") => QC_CHECK_CHANNEL_ERROR",           ERR_WIN32_ERROR));
      if (result == QC_CHECK_CHANNEL_NONE )    return(!catch("QC.HandleTradeCommands(2)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeCmdChannel +"\")  channel doesn't exist",              ERR_WIN32_ERROR));
                                               return(!catch("QC.HandleTradeCommands(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.TradeCmdChannel +"\")  unexpected return value = "+ result, ERR_WIN32_ERROR));
   }

   // (3) neue Messages abholen
   string messageBuffer[]; if (!ArraySize(messageBuffer)) InitializeStringBuffer(messageBuffer, QC_MAX_BUFFER_SIZE);
   result = QC_GetMessages3(hQC.TradeCmdReceiver, messageBuffer, QC_MAX_BUFFER_SIZE);
   if (result != QC_GET_MSG3_SUCCESS) {
      if (result == QC_GET_MSG3_CHANNEL_EMPTY) return(!catch("QC.HandleTradeCommands(4)->MT4iQuickChannel::QC_GetMessages3()  QC_CheckChannel not empty/QC_GET_MSG3_CHANNEL_EMPTY mismatch",           ERR_WIN32_ERROR));
      if (result == QC_GET_MSG3_INSUF_BUFFER ) return(!catch("QC.HandleTradeCommands(5)->MT4iQuickChannel::QC_GetMessages3()  buffer to small (QC_MAX_BUFFER_SIZE/QC_GET_MSG3_INSUF_BUFFER mismatch)", ERR_WIN32_ERROR));
                                               return(!catch("QC.HandleTradeCommands(6)->MT4iQuickChannel::QC_GetMessages3()  unexpected return value = "+ result,                                     ERR_WIN32_ERROR));
   }

   // (4) Messages verarbeiten
   string msgs[];
   int msgsSize = Explode(messageBuffer[0], TAB, msgs, NULL);

   for (int i=0; i < msgsSize; i++) {
      if (!StringLen(msgs[i]))
         continue;
      log("QC.HandleTradeCommands(7)  received \""+ msgs[i] +"\"");
      if (!RunScript("LFX.ExecuteTradeCmd", "command="+ msgs[i]))    // TODO: Scripte müssen entweder synchron oder parallel ausgeführt werden
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
         if (!hQC.TradeToLfxSenders[i]) /*&&*/ if (!QC.StartLfxSender(i))
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
 * Speichert die mode.extern-Konfiguration im Chartfenster (für Init-Cycle und Laden eines neuen Templates) und im Chart selbst (für Restart des Terminals).
 *
 * @return bool - Erfolgsstatus
 */
bool StoreWindowStatus() {
   // Konfiguration im Chartfenster speichern bzw. löschen
   int hWnd = WindowHandleEx(NULL); if (!hWnd) return(false);
   if (mode.extern) {
      SetPropA(hWnd, "xtrade.ChartInfos.TrackSignal", external.signalId);    // TODO: Schlüssel muß global verwaltet werden und Instanz-ID des Indikators enthalten
   }
   else {
      RemovePropA(hWnd, "xtrade.ChartInfos.TrackSignal");
   }

   // Konfiguration im Chart speichern bzw. löschen
   string label = __NAME__ +".sticky.TrackSignal";
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   if (mode.extern) {
      ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
      ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
      ObjectSetText(label, external.signalProvider +"."+ external.signalAlias);
   }
   return(!catch("StoreWindowStatus(1)"));
}


/**
 * Restauriert die mode.extern-Konfiguration aus dem Chartfenster oder dem Chart.
 *
 * @return bool - Erfolgsstatus
 */
bool RestoreWindowStatus() {
   bool   success = false;
   string signal="", providerName="", signalName="";

   // Konfiguration im Chartfenster suchen
   int hWnd = WindowHandleEx(NULL); if (!hWnd) return(false);
   int id   = RemovePropA(hWnd, "xtrade.ChartInfos.TrackSignal");      // TODO: Schlüssel muß global verwaltet werden und Instanz-ID des Indikators enthalten
   if (id != NULL) {
      if (id == -1) {
         success = true;
      }
      else if (ParseSignalId(id, providerName, signalName)) {
         signal  = providerName +"."+ signalName;
         success = true;
      }
   }

   // Bei Mißerfolg Konfiguration im Chart suchen
   if (!success) {
      string label = __NAME__ +".sticky.TrackSignal";
      if (ObjectFind(label) == 0) {
         signal  = ObjectDescription(label);
         success = (signal=="" || ParseSignalStr(signal, providerName, signalName));
      }
   }

   if (success)
      TrackSignal(signal);
   return(!catch("RestoreWindowStatus(1)"));
}


/**
 * Gibt die Signal-ID eines Signalbezeichners zurück.
 *
 * @param  string signal - Signalbezeichner
 *
 * @return int - Signal-ID der NULL, wenn der Bezeichner unbekannt oder ungültig ist
 */
int SignalId(string signal) {
   signal = StringToLower(signal);

   if (signal == ST_SIGNAL.ALEXPROFIT   ) return(ST_SIGNAL.ID_ALEXPROFIT   );
   if (signal == ST_SIGNAL.ASTA         ) return(ST_SIGNAL.ID_ASTA         );
   if (signal == ST_SIGNAL.CAESAR2      ) return(ST_SIGNAL.ID_CAESAR2      );
   if (signal == ST_SIGNAL.CAESAR21     ) return(ST_SIGNAL.ID_CAESAR21     );
   if (signal == ST_SIGNAL.CONSISTENT   ) return(ST_SIGNAL.ID_CONSISTENT   );
   if (signal == ST_SIGNAL.DAYFOX       ) return(ST_SIGNAL.ID_DAYFOX       );
   if (signal == ST_SIGNAL.FXVIPER      ) return(ST_SIGNAL.ID_FXVIPER      );
   if (signal == ST_SIGNAL.GCEDGE       ) return(ST_SIGNAL.ID_GCEDGE       );
   if (signal == ST_SIGNAL.GOLDSTAR     ) return(ST_SIGNAL.ID_GOLDSTAR     );
   if (signal == ST_SIGNAL.KILIMANJARO  ) return(ST_SIGNAL.ID_KILIMANJARO  );
   if (signal == ST_SIGNAL.NOVOLR       ) return(ST_SIGNAL.ID_NOVOLR       );
   if (signal == ST_SIGNAL.OVERTRADER   ) return(ST_SIGNAL.ID_OVERTRADER   );
   if (signal == ST_SIGNAL.SMARTSCALPER ) return(ST_SIGNAL.ID_SMARTSCALPER );
   if (signal == ST_SIGNAL.SMARTTRADER  ) return(ST_SIGNAL.ID_SMARTTRADER  );
   if (signal == ST_SIGNAL.STEADYCAPTURE) return(ST_SIGNAL.ID_STEADYCAPTURE);
   if (signal == ST_SIGNAL.TWILIGHT     ) return(ST_SIGNAL.ID_TWILIGHT     );
   if (signal == ST_SIGNAL.YENFORTRESS  ) return(ST_SIGNAL.ID_YENFORTRESS  );

   warn("SignalId(1)  invalid or unknown parameter signal=\""+ signal +"\"");
   return(NULL);
}


/**
 * Parst einen Signalbezeichner (Integer).
 *
 * @param  _IN_  int     id         - zu parsender Bezeichner
 * @param  _OUT_ string &lpProvider - Zeiger auf Variable zur Aufnahme des Signalproviders
 * @param  _OUT_ string &lpSignal   - Zeiger auf Variable zur Aufnahme des Signalnamens
 *
 * @return bool - TRUE, wenn der Bezeichner ein gültiges Signal darstellt;
 *                FALSE andererseits
 */
bool ParseSignalId(int id, string &lpProvider, string &lpSignal) {
   if      (id == ST_SIGNAL.ID_ALEXPROFIT   ) { lpProvider="simpletrader"; lpSignal="alexprofit"   ; }
   else if (id == ST_SIGNAL.ID_ASTA         ) { lpProvider="simpletrader"; lpSignal="asta"         ; }
   else if (id == ST_SIGNAL.ID_CAESAR2      ) { lpProvider="simpletrader"; lpSignal="caesar2"      ; }
   else if (id == ST_SIGNAL.ID_CAESAR21     ) { lpProvider="simpletrader"; lpSignal="caesar21"     ; }
   else if (id == ST_SIGNAL.ID_CONSISTENT   ) { lpProvider="simpletrader"; lpSignal="consistent"   ; }
   else if (id == ST_SIGNAL.ID_DAYFOX       ) { lpProvider="simpletrader"; lpSignal="dayfox"       ; }
   else if (id == ST_SIGNAL.ID_FXVIPER      ) { lpProvider="simpletrader"; lpSignal="fxviper"      ; }
   else if (id == ST_SIGNAL.ID_GCEDGE       ) { lpProvider="simpletrader"; lpSignal="gcedge"       ; }
   else if (id == ST_SIGNAL.ID_GOLDSTAR     ) { lpProvider="simpletrader"; lpSignal="goldstar"     ; }
   else if (id == ST_SIGNAL.ID_KILIMANJARO  ) { lpProvider="simpletrader"; lpSignal="kilimanjaro"  ; }
   else if (id == ST_SIGNAL.ID_NOVOLR       ) { lpProvider="simpletrader"; lpSignal="novolr"       ; }
   else if (id == ST_SIGNAL.ID_OVERTRADER   ) { lpProvider="simpletrader"; lpSignal="overtrader"   ; }
   else if (id == ST_SIGNAL.ID_SMARTSCALPER ) { lpProvider="simpletrader"; lpSignal="smartscalper" ; }
   else if (id == ST_SIGNAL.ID_SMARTTRADER  ) { lpProvider="simpletrader"; lpSignal="smarttrader"  ; }
   else if (id == ST_SIGNAL.ID_STEADYCAPTURE) { lpProvider="simpletrader"; lpSignal="steadycapture"; }
   else if (id == ST_SIGNAL.ID_TWILIGHT     ) { lpProvider="simpletrader"; lpSignal="twilight"     ; }
   else if (id == ST_SIGNAL.ID_YENFORTRESS  ) { lpProvider="simpletrader"; lpSignal="yenfortress"  ; }
   else {
      return(false);
   }
   return(true);
}


/**
 * Parst einen Signalbezeichner (String).
 *
 * @param  _IN_  string  value      - zu parsender Bezeichner
 * @param  _OUT_ string &lpProvider - Zeiger auf Variable zur Aufnahme des Signalproviders
 * @param  _OUT_ string &lpSignal   - Zeiger auf Variable zur Aufnahme des Signalnamens
 *
 * @return bool - TRUE, wenn der Bezeichner ein gültiges Signal darstellt;
 *                FALSE andererseits
 */
bool ParseSignalStr(string value, string &lpProvider, string &lpSignal) {
   value = StringToLower(value);

   if      (value == ST_SIGNAL.ALEXPROFIT   ) { lpProvider="simpletrader"; lpSignal="alexprofit"   ; }
   else if (value == ST_SIGNAL.ASTA         ) { lpProvider="simpletrader"; lpSignal="asta"         ; }
   else if (value == ST_SIGNAL.CAESAR2      ) { lpProvider="simpletrader"; lpSignal="caesar2"      ; }
   else if (value == ST_SIGNAL.CAESAR21     ) { lpProvider="simpletrader"; lpSignal="caesar21"     ; }
   else if (value == ST_SIGNAL.CONSISTENT   ) { lpProvider="simpletrader"; lpSignal="consistent"   ; }
   else if (value == ST_SIGNAL.DAYFOX       ) { lpProvider="simpletrader"; lpSignal="dayfox"       ; }
   else if (value == ST_SIGNAL.FXVIPER      ) { lpProvider="simpletrader"; lpSignal="fxviper"      ; }
   else if (value == ST_SIGNAL.GCEDGE       ) { lpProvider="simpletrader"; lpSignal="gcedge"       ; }
   else if (value == ST_SIGNAL.GOLDSTAR     ) { lpProvider="simpletrader"; lpSignal="goldstar"     ; }
   else if (value == ST_SIGNAL.KILIMANJARO  ) { lpProvider="simpletrader"; lpSignal="kilimanjaro"  ; }
   else if (value == ST_SIGNAL.NOVOLR       ) { lpProvider="simpletrader"; lpSignal="novolr"       ; }
   else if (value == ST_SIGNAL.OVERTRADER   ) { lpProvider="simpletrader"; lpSignal="overtrader"   ; }
   else if (value == ST_SIGNAL.SMARTSCALPER ) { lpProvider="simpletrader"; lpSignal="smartscalper" ; }
   else if (value == ST_SIGNAL.SMARTTRADER  ) { lpProvider="simpletrader"; lpSignal="smarttrader"  ; }
   else if (value == ST_SIGNAL.STEADYCAPTURE) { lpProvider="simpletrader"; lpSignal="steadycapture"; }
   else if (value == ST_SIGNAL.TWILIGHT     ) { lpProvider="simpletrader"; lpSignal="twilight"     ; }
   else if (value == ST_SIGNAL.YENFORTRESS  ) { lpProvider="simpletrader"; lpSignal="yenfortress"  ; }
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
      if (!IsFile(file)) return(_EMPTY(catch("ReadExternalPositions(1)  file not found \""+ file +"\"", ERR_RUNTIME_ERROR)));
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
         if (!StringLen(value))                       return(_EMPTY(catch("ReadExternalPositions(2)  invalid ini entry ["+ section +"]->"+ key +" in \""+ file +"\" (empty)", ERR_RUNTIME_ERROR)));

         // (1.2.2) Positionsdaten validieren
         //Symbol.Ticket = Type, Lots, OpenTime, OpenPrice, TakeProfit, StopLoss, Commission, Swap, MagicNumber, Comment
         string sValue, values[];
         if (Explode(value, ",", values, NULL) != 10) return(_EMPTY(catch("ReadExternalPositions(3)  invalid position entry ("+ ArraySize(values) +" substrings) ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // Ticket
         sValue = StringRight(key, -StringLen(symbol));
         if (StringGetChar(sValue, 0) != '.')         return(_EMPTY(catch("ReadExternalPositions(4)  invalid ticket \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         sValue = StringSubstr(sValue, 1);
         if (!StringIsDigit(sValue))                  return(_EMPTY(catch("ReadExternalPositions(5)  invalid ticket \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         int _ticket = StrToInteger(sValue);
         if (_ticket <= 0)                            return(_EMPTY(catch("ReadExternalPositions(6)  invalid ticket \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // Type
         sValue = StringTrim(values[0]);
         int _type = StrToOperationType(sValue);
         if (!IsTradeOperation(_type))                return(_EMPTY(catch("ReadExternalPositions(7)  invalid order type \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // Lots
         sValue = StringTrim(values[1]);
         if (!StringIsNumeric(sValue))                return(_EMPTY(catch("ReadExternalPositions(8)  invalid lot size \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         double _lots = StrToDouble(sValue);
         if (_lots <= 0)                              return(_EMPTY(catch("ReadExternalPositions(9)  invalid lot size \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _lots = NormalizeDouble(_lots, 2);

         // OpenTime
         sValue = StringTrim(values[2]);
         datetime _openTime = StrToTime(sValue);
         if (!_openTime)                              return(_EMPTY(catch("ReadExternalPositions(10)  invalid open time \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // OpenPrice
         sValue = StringTrim(values[3]);
         if (!StringIsNumeric(sValue))                return(_EMPTY(catch("ReadExternalPositions(11)  invalid open price \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         double _openPrice = StrToDouble(sValue);
         if (_openPrice <= 0)                         return(_EMPTY(catch("ReadExternalPositions(12)  invalid open price \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _openPrice = NormalizeDouble(_openPrice, Digits);

         // TakeProfit
         sValue = StringTrim(values[4]);
         double _takeProfit = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(13)  invalid takeprofit \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _takeProfit = StrToDouble(sValue);
            if (_takeProfit < 0)                      return(_EMPTY(catch("ReadExternalPositions(14)  invalid takeprofit \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _takeProfit = NormalizeDouble(_takeProfit, Digits);
         }

         // StopLoss
         sValue = StringTrim(values[5]);
         double _stopLoss = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(15)  invalid stoploss \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _stopLoss = StrToDouble(sValue);
            if (_stopLoss < 0)                        return(_EMPTY(catch("ReadExternalPositions(16)  invalid stoploss \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _stopLoss = NormalizeDouble(_stopLoss, Digits);
         }

         // Commission
         sValue = StringTrim(values[6]);
         double _commission = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(17)  invalid commission value \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _commission = NormalizeDouble(StrToDouble(sValue), 2);
         }

         // Swap
         sValue = StringTrim(values[7]);
         double _swap = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(18)  invalid swap value \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
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
      if (!IsFile(file)) return(_EMPTY(catch("ReadExternalPositions(19)  file not found \""+ file +"\"", ERR_RUNTIME_ERROR)));
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
         if (!StringLen(value))                       return(_EMPTY(catch("ReadExternalPositions(20)  invalid ini entry ["+ section +"]->"+ key +" in \""+ file +"\" (empty)", ERR_RUNTIME_ERROR)));

         // (2.2.2) Positionsdaten validieren
         //Symbol.Ticket = Type, Lots, OpenTime, OpenPrice, CloseTime, ClosePrice, TakeProfit, StopLoss, Commission, Swap, Profit, MagicNumber, Comment
         if (Explode(value, ",", values, NULL) != 13) return(_EMPTY(catch("ReadExternalPositions(21)  invalid position entry ("+ ArraySize(values) +" substrings) ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // Ticket
         sValue = StringRight(key, -StringLen(symbol));
         if (StringGetChar(sValue, 0) != '.')         return(_EMPTY(catch("ReadExternalPositions(22)  invalid ticket \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         sValue = StringSubstr(sValue, 1);
         if (!StringIsDigit(sValue))                  return(_EMPTY(catch("ReadExternalPositions(23)  invalid ticket \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _ticket = StrToInteger(sValue);
         if (_ticket <= 0)                            return(_EMPTY(catch("ReadExternalPositions(24)  invalid ticket \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // Type
         sValue = StringTrim(values[0]);
         _type  = StrToOperationType(sValue);
         if (!IsTradeOperation(_type))                return(_EMPTY(catch("ReadExternalPositions(25)  invalid order type \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // Lots
         sValue = StringTrim(values[1]);
         if (!StringIsNumeric(sValue))                return(_EMPTY(catch("ReadExternalPositions(26)  invalid lot size \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _lots = StrToDouble(sValue);
         if (_lots <= 0)                              return(_EMPTY(catch("ReadExternalPositions(27)  invalid lot size \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _lots = NormalizeDouble(_lots, 2);

         // OpenTime
         sValue    = StringTrim(values[2]);
         _openTime = StrToTime(sValue);
         if (!_openTime)                              return(_EMPTY(catch("ReadExternalPositions(28)  invalid open time \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // OpenPrice
         sValue = StringTrim(values[3]);
         if (!StringIsNumeric(sValue))                return(_EMPTY(catch("ReadExternalPositions(29)  invalid open price \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _openPrice = StrToDouble(sValue);
         if (_openPrice <= 0)                         return(_EMPTY(catch("ReadExternalPositions(30)  invalid open price \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _openPrice = NormalizeDouble(_openPrice, Digits);

         // CloseTime
         sValue = StringTrim(values[4]);
         datetime _closeTime = StrToTime(sValue);
         if (!_closeTime)                             return(_EMPTY(catch("ReadExternalPositions(31)  invalid open time \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));

         // ClosePrice
         sValue = StringTrim(values[5]);
         if (!StringIsNumeric(sValue))                return(_EMPTY(catch("ReadExternalPositions(32)  invalid open price \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         double _closePrice = StrToDouble(sValue);
         if (_closePrice <= 0)                        return(_EMPTY(catch("ReadExternalPositions(33)  invalid open price \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         _closePrice = NormalizeDouble(_closePrice, Digits);

         // TakeProfit
         sValue      = StringTrim(values[6]);
         _takeProfit = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(34)  invalid takeprofit \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _takeProfit = StrToDouble(sValue);
            if (_takeProfit < 0)                      return(_EMPTY(catch("ReadExternalPositions(35)  invalid takeprofit \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _takeProfit = NormalizeDouble(_takeProfit, Digits);
         }

         // StopLoss
         sValue    = StringTrim(values[7]);
         _stopLoss = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(36)  invalid stoploss \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _stopLoss = StrToDouble(sValue);
            if (_stopLoss < 0)                        return(_EMPTY(catch("ReadExternalPositions(37)  invalid stoploss \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _stopLoss = NormalizeDouble(_stopLoss, Digits);
         }

         // Commission
         sValue      = StringTrim(values[8]);
         _commission = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(38)  invalid commission value \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _commission = NormalizeDouble(StrToDouble(sValue), 2);
         }

         // Swap
         sValue = StringTrim(values[9]);
         _swap  = 0;
         if (sValue != "") {
            if (!StringIsNumeric(sValue))             return(_EMPTY(catch("ReadExternalPositions(39)  invalid swap value \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
            _swap = NormalizeDouble(StrToDouble(sValue), 2);
         }

         // Profit
         sValue = StringTrim(values[10]);
         if (sValue == "")                            return(_EMPTY(catch("ReadExternalPositions(40)  invalid profit value \"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
         if (!StringIsNumeric(sValue))                return(_EMPTY(catch("ReadExternalPositions(41)  invalid profit value \""+ sValue +"\" in position entry ["+ section +"]->"+ key +" = \""+ StringReplace.Recursive(StringReplace.Recursive(value, " ,", ","), ",  ", ", ") +"\" in \""+ file +"\"", ERR_RUNTIME_ERROR)));
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
   string mqlDir = TerminalPath() + ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string files[];

   if (mode.intern) {
      ArrayPushString(files, mqlDir +"\\files\\"+ ShortAccountCompany() +"\\"+ GetAccountNumber() +"_config.ini");
   }
   else if (mode.extern) {
      ArrayPushString(files, mqlDir +"\\files\\"+ external.signalProvider +"\\"+ external.signalAlias +"_open.ini"  );
      ArrayPushString(files, mqlDir +"\\files\\"+ external.signalProvider +"\\"+ external.signalAlias +"_closed.ini");
      ArrayPushString(files, mqlDir +"\\files\\"+ external.signalProvider +"\\"+ external.signalAlias +"_config.ini");
   }
   else if (mode.remote) {
      ArrayPushString(files, mqlDir +"\\files\\"+ tradeAccountCompany +"\\"+ tradeAccountNumber +"_config.ini");
   }
   else {
      return(!catch("EditAccountConfig(1)", ERR_WRONG_JUMP));
   }

   if (!EditFiles(files))
      return(!SetLastError(stdlib.GetLastError()));
}


/**
 * String-Repräsentation der Input-Parameter fürs Logging bei Aufruf durch iCustom().
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()  config: ",                     // 'config' statt 'inputs', da die Laufzeitparameter extern konfiguriert werden

                            "appliedPrice=",                PriceTypeToStr(appliedPrice), "; ")
   );
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   bool     AquireLock(string mutexName, bool wait);
   int      ArrayDropInt      (int    array[], int value);
   int      ArrayInsertDoubles(double array[], int offset, double values[]);
   int      ArrayPushDouble   (double array[], double value);
   string   DateToStr(datetime time, string mask);
   int      DeleteRegisteredObjects(string prefix);
   bool     EditFiles(string filenames[]);
   datetime FxtToServerTime(datetime fxtTime);
   double   GetCommission();
   string   GetLocalConfigPath();
   string   GetLongSymbolNameOrAlt(string symbol, string altValue);
   datetime GetPrevSessionStartTime.srv(datetime serverTime);
   string   GetRawIniString(string file, string section, string key, string defaultValue);
   datetime GetSessionStartTime.srv(datetime serverTime);
   string   GetSymbolName(string symbol);
   int      GetTerminalBuild();
   bool     IsCurrency(string value);
   bool     IsFile(string filename);
   bool     ChartMarker.OrderSent_A(int ticket, int digits, color markerColor);
   int      ObjectRegister(string label);
   string   PriceTypeToStr(int type);
   bool     ReleaseLock(string mutexName);
   int      SearchStringArrayI(string haystack[], string needle);
   bool     StringCompareI(string a, string b);

#import "stdlib2.ex4"
   int      ArrayInsertDoubleArray(double array[][], int offset, double values[]);
   int      ChartInfos.CopyLfxStatus(bool direction, /*LFX_ORDER*/int orders[][], int iVolatile[][], double dVolatile[][]);
   bool     SortClosedTickets(int keys[][]);
   bool     SortOpenTickets  (int keys[][]);

   string   DoublesToStr         (double array[], string separator);
   string   StringsToStr         (string array[], string separator);
   string   TicketsToStr         (int    array[], string separator);
   string   TicketsToStr.Lots    (int    array[], string separator);
   string   TicketsToStr.Position(int    array[]);

#import
