/**
 * EventTracker für verschiedene Ereignisse. Benachrichtigt optisch, akustisch, per E-Mail, SMS, HTML-Request oder ICQ.
 *
 *
 * (1) Order-Events
 *     Die Orderüberwachung wird im Indikator aktiviert/deaktiviert. Ein so aktivierter EventTracker überwacht alle Symbole eines Accounts, nicht nur das
 *     des aktuellen Charts. Es liegt in der Verantwortung des Benutzers, nur einen aller laufenden EventTracker für die Orderüberwachung zu aktivieren.
 *
 *     Events:
 *      - Orderausführung fehlgeschlagen
 *      - Position geöffnet
 *      - Position geschlossen
 *
 *
 * (2) Preis-Events
 *     Die Preisüberwachung wird im Indikator aktiviert/deaktiviert und die einzelnen Events in der Account-Konfiguration je Instrument konfiguriert. Es liegt
 *     in der Verantwortung des Benutzers, nur einen EventTracker je Instrument für die Preisüberwachung zu aktivieren. Mit den frei kombinierbaren Eventkeys
 *     können beliebige Preis-Events formuliert werden.
 *
 *      • Eventkey:     {Timeframe-ID}.{Signal-ID}
 *
 *      • Timeframe-ID: {number}{[Day|Week|Month][s]}Ago             ; Singular und Plural der Timeframe-Bezeichner sind austauschbar
 *                      Today                                        ; Synonym für 0DaysAgo
 *                      Yesterday                                    ; Synonym für 1DayAgo
 *                      This[Day|Week|Month]                         ; Synonym für 0[Days|Weeks|Months]Ago
 *                      Last[Day|Week|Month]                         ; Synonym für 1[Day|Week|Month]Ago
 *
 *      • Signal-ID:    BarClose          = On | Off                 ; Erreichen des Close-Preises einer Bar
 *                      BarRange          = {90}%                    ; Erreichen der {x}%-Schwelle einer Bar-Range (100% = am bisherigen High/Low)
 *                      BarBreakout       = On | Off                 ; neues High/Low
 *                      BarBreakout.Reset = {5} [minute|hour][s]     ; Zeit, nachdem die Prüfung eines einmal getriggerten Signals reaktiviert wird
 *
 *     Pattern und ihre Konfiguration:
 *      - neues Inside-Range-Pattern auf Tagesbasis
 *      - neues Inside-Range-Pattern auf Wochenbasis
 *      - Auflösung eines Inside-Range-Pattern auf Tagesbasis
 *      - Auflösung eines Inside-Range-Pattern auf Wochenbasis
 *
 *
 * Die Art der Benachrichtigung (akustisch, E-Mail, SMS, HTML-Request, ICQ) kann je Event einzeln konfiguriert werden.
 *
 *
 * TODO:
 * -----
 *  - PositionOpen-/Close-Events während Timeframe- oder Symbolwechsel werden nicht erkannt
 *  - bei Accountwechsel auftretende Fehler werden nicht abgefangen
 *  - Konfiguration während eines init-Cycles im Chart speichern, damit Recompilation überlebt werden kann
 *  - Anzeige der überwachten Kriterien
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////


extern bool   Track.Order.Events   = false;
extern bool   Track.Price.Events   = true;

extern string __________________________;

extern bool   Alerts.Sound         = true;                           // alle Order-Alerts bis auf Sounds sind per Default inaktiv
extern string Alerts.Mail.Receiver = "email@address.tld";            // E-Mailadresse    ("system" => global konfigurierte Adresse)
extern string Alerts.SMS.Receiver  = "phone-number";                 // Telefonnummer    ("system" => global konfigurierte Nummer )
extern string Alerts.HTTP.Url      = "url";                          // vollständige URL ("system" => global konfigurierte URL    )
extern string Alerts.ICQ.UserID    = "contact-id";                   // ICQ-Kontakt      ("system" => global konfigurierte User-ID)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#include <core/indicator.mqh>
#include <iFunctions/iBarShiftNext.mqh>
#include <iFunctions/iBarShiftPrevious.mqh>
#include <iFunctions/iChangedBars.mqh>
#include <iFunctions/iPreviousPeriodTimes.mqh>


bool   track.orders;
bool   track.price;


// Alert-Konfiguration
bool   alerts.sound;
string sound.orderFailed    = "speech/OrderExecutionFailed.wav";
string sound.positionOpened = "speech/OrderFilled.wav";
string sound.positionClosed = "speech/PositionClosed.wav";

bool   alerts.mail;
string alerts.mail.receiver = "";

bool   alerts.sms;
string alerts.sms.receiver = "";

bool   alerts.http;
string alerts.http.url = "";

bool   alerts.icq;
string alerts.icq.userId = "";


// Order-Events
int orders.knownOrders.ticket[];                                     // vom letzten Aufruf bekannte offene Orders
int orders.knownOrders.type  [];


// Price-Events
#define ET_PRICE_BAR_CLOSE          1                                // PriceEvent-Typen
#define ET_PRICE_BAR_RANGE          2
#define ET_PRICE_BAR_BREAKOUT       3

#define I_PRICE_CONFIG_ID           0                                // Signal-ID:       int
#define I_PRICE_CONFIG_ENABLED      1                                // SignalEnabled:   int 0|1
#define I_PRICE_CONFIG_TIMEFRAME    2                                // SignalTimeframe: int PERIOD_D1|PERIOD_W1|PERIOD_MN1
#define I_PRICE_CONFIG_BAR          3                                // SignalBar:       int 0..x (look back)
#define I_PRICE_CONFIG_PARAM1       4                                // SignalParam1:    int ...
#define I_PRICE_CONFIG_PARAM2       5                                // SignalParam2:    int ...
#define I_PRICE_CONFIG_PARAM3       6                                // SignalParam3:    int ...

int    price.config[][7];
double price.rtdata[][8];                                            // je nach Signal unterschiedliche Laufzeitdaten zur Signalverwaltung


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   if (!Configure())                                                 // Konfiguration einlesen
      return(last_error);

   SetIndexLabel(0, NULL);                                           // Datenanzeige ausschalten
   return(catch("onInit(1)"));
}


/**
 * Konfiguriert den EventTracker.
 *
 * @return bool - Erfolgsstatus
 */
bool Configure() {
   // (1) Konfiguration des OrderTrackers einlesen und auswerten
   track.orders = Track.Order.Events;
   if (track.orders) {
   }


   // (2) Konfiguration des PriceTrackers einlesen und auswerten
   track.price = Track.Price.Events;
   if (track.price) {
      int account = GetAccountNumber();
      if (!account) return(!SetLastError(stdlib.GetLastError()));

      string mqlDir = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
      string file   = TerminalPath() + mqlDir +"\\files\\"+ ShortAccountCompany() +"\\"+ account +"_config.ini";

      // Eventkey:     {Timeframe-ID}.{Signal-ID}
      //
      // Timeframe-ID: {number}{[Day|Week|Month][s]}Ago             ; Singular und Plural der Timeframe-Bezeichner sind austauschbar
      //               Today                                        ; Synonym für 0DaysAgo
      //               Yesterday                                    ; Synonym für 1DayAgo
      //               This[Day|Week|Month]                         ; Synonym für 0[Days|Weeks|Months]Ago
      //               Last[Day|Week|Month]                         ; Synonym für 1[Day|Week|Month]Ago
      //
      // Signal-ID:    Close               = On|Off                 ; Erreichen des Close-Preises der Bar
      //               BarRange            = {90}%                  ; Erreichen der {x}%-Schwelle der Bar-Range (100% = am bisherigen High/Low)
      //               BarBreakout         = On|Off                 ; neues High/Low
      //               BarBreakout.OnTouch = 1|0                    ; ob zusätzlich zum Breakout ein Erreichen der Range signalisiert werden soll
      //               BarBreakout.Reset   = {5} [minute|hour][s]   ; Zeit, nachdem die Prüfung eines getriggerten Signals reaktiviert wird

      // Yesterday.Breakout = 1
      int size = 1;
      ArrayResize(price.config, size);
      ArrayResize(price.rtdata, size);
      price.config[0][I_PRICE_CONFIG_ID       ] = ET_PRICE_BAR_BREAKOUT;
      price.config[0][I_PRICE_CONFIG_ENABLED  ] = true;                       // (int) bool
      price.config[0][I_PRICE_CONFIG_TIMEFRAME] = PERIOD_M1;
      price.config[0][I_PRICE_CONFIG_BAR      ] = 1;                          // 1DayAgo
      price.config[0][I_PRICE_CONFIG_PARAM1   ] = false;                      // zusätzliches Signal bei On-Touch
      price.config[0][I_PRICE_CONFIG_PARAM2   ] = 15*MINUTES;                 // Reset nach 15 Minuten
    //price.config[0][I_PRICE_CONFIG_PARAM3   ] = ...                         // für ET_PRICE_BAR_BREAKOUT unbenutzt
   }


   // (3) Alert-Methoden einlesen und auswerten
   if (track.orders || track.price) {
      // (3.1) Order.Alerts.Sound
      alerts.sound = Alerts.Sound;

      // (3.2) Alerts.Mail.Receiver
      // (3.3) Alerts.SMS.Receiver
      string sValue = StringToLower(StringTrim(Alerts.SMS.Receiver));
      if (sValue!="" && sValue!="phone-number") {
         alerts.sms.receiver = ifString(sValue=="system", GetConfigString("SMS", "Receiver", ""), sValue);
         alerts.sms          = StringIsPhoneNumber(alerts.sms.receiver);
         if (!alerts.sms) {
            if (sValue == "system") return(!catch("Configure(1)  "+ ifString(alerts.sms.receiver=="", "Missing", "Invalid") +" global/local config value [SMS]->Receiver = \""+ alerts.sms.receiver +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
            else                    return(!catch("Configure(2)  Invalid input parameter Alerts.SMS.Receiver = \""+ Alerts.SMS.Receiver +"\"", ERR_INVALID_INPUT_PARAMETER));
         }
      }
      else alerts.sms = false;

      // (3.4) Alerts.HTTP.Url
      // (3.5) Alerts.ICQ.UserID

      // SMS.Alerts
      __SMS.alerts = GetIniBool(file, "EventTracker", "SMS.Alerts", false);
      if (__SMS.alerts) {
         __SMS.receiver = GetGlobalConfigString("SMS", "Receiver", "");
         __SMS.alerts   = StringIsPhoneNumber(__SMS.receiver);
         if (!__SMS.alerts) return(!catch("Configure(3)  invalid config value [SMS]->Receiver = \""+ __SMS.receiver +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
      }
   }


   int error = catch("Configure(4)");
   if (!error) {
      ShowStatus();
      if (false) {
         debug("Configure()  "+ StringConcatenate("track.orders=", BoolToStr(track.orders),                                          "; ",
                                                  "track.price=",  BoolToStr(track.price),                                           "; ",
                                                  "alerts.sound=", BoolToStr(alerts.sound),                                          "; ",
                                                  "alerts.mail=" , ifString(alerts.mail, "\""+ alerts.mail.receiver +"\"", "false"), "; ",
                                                  "alerts.sms="  , ifString(alerts.sms,  "\""+ alerts.sms.receiver  +"\"", "false"), "; ",
                                                  "alerts.http=" , ifString(alerts.http, "\""+ alerts.http.url      +"\"", "false"), "; ",
                                                  "alerts.icq="  , ifString(alerts.icq,  "\""+ alerts.icq.userId    +"\"", "false"), "; "
         ));
      }
   }
   return(!error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // (1) Order-Events überwachen
   if (track.orders) {
      int failedOrders   []; ArrayResize(failedOrders,    0);
      int openedPositions[]; ArrayResize(openedPositions, 0);
      int closedPositions[]; ArrayResize(closedPositions, 0);

      if (!CheckPositions(failedOrders, openedPositions, closedPositions))
         return(last_error);

      if (ArraySize(failedOrders   ) > 0) onOrderFail    (failedOrders   );
      if (ArraySize(openedPositions) > 0) onPositionOpen (openedPositions);
      if (ArraySize(closedPositions) > 0) onPositionClose(closedPositions);
   }


   // (2) Price-Events überwachen
   if (track.price) {
      int size = ArrayRange(price.config, 0);

      for (int i=0; i < size; i++) {
         if (price.config[i][I_PRICE_CONFIG_ENABLED] != 0) {
            switch (price.config[i][I_PRICE_CONFIG_ID]) {
               case ET_PRICE_BAR_CLOSE:    CheckClosePriceSignal(i); break;
               case ET_PRICE_BAR_RANGE:    CheckRangeSignal     (i); break;
               case ET_PRICE_BAR_BREAKOUT: CheckBreakoutSignal  (i); break;
               default:
                  catch("onTick(1)  unknow price signal["+ i +"] = "+ price.config[i][I_PRICE_CONFIG_ID], ERR_RUNTIME_ERROR);
            }
         }
         if (__STATUS_OFF)
            break;
      }
   }

   return(ShowStatus(last_error));
}


/**
 * Prüft, ob seit dem letzten Aufruf eine Pending-Order oder ein Close-Limit ausgeführt wurden.
 *
 * @param  int failedOrders   [] - Array zur Aufnahme der Tickets fehlgeschlagener Pening-Orders
 * @param  int openedPositions[] - Array zur Aufnahme der Tickets neuer offener Positionen
 * @param  int closedPositions[] - Array zur Aufnahme der Tickets neuer geschlossener Positionen
 *
 * @return bool - Erfolgsstatus
 */
bool CheckPositions(int failedOrders[], int openedPositions[], int closedPositions[]) {
   /*
   PositionOpen
   ------------
   - ist Ausführung einer Pending-Order
   - Pending-Order muß vorher bekannt sein
     (1) alle bekannten Pending-Orders auf Statusänderung prüfen:  über bekannte Orders iterieren
     (2) alle unbekannten Pending-Orders in Überwachung aufnehmen: über OpenOrders iterieren

   PositionClose
   -------------
   - ist Schließung einer Position
   - Position muß vorher bekannt sein
     (1) alle bekannten Pending-Orders und Positionen auf OrderClose prüfen:            über bekannte Orders iterieren
     (2) alle unbekannten Positionen mit und ohne Close-Limit in Überwachung aufnehmen: über OpenOrders iterieren
         (limitlose Positionen können durch Stopout geschlossen worden sein)

   beides zusammen
   ---------------
     (1.1) alle bekannten Pending-Orders auf Statusänderung prüfen:                 über bekannte Orders iterieren
     (1.2) alle bekannten Pending-Orders und Positionen auf OrderClose prüfen:      über bekannte Orders iterieren

     (2)   alle unbekannten Pending-Orders und Positionen in Überwachung aufnehmen: über OpenOrders iterieren
           - nach (1.1) und (1.2), um sofortige Prüfung neuer zu überwachender Orders zu vermeiden
   */

   int type, knownSize=ArraySize(orders.knownOrders.ticket);


   // (1) über alle bekannten Orders iterieren (rückwärts, um beim Entfernen von Elementen die Schleife einfacher managen zu können)
   for (int i=knownSize-1; i >= 0; i--) {
      if (!SelectTicket(orders.knownOrders.ticket[i], "CheckPositions(1)"))
         return(false);
      type = OrderType();

      if (orders.knownOrders.type[i] > OP_SELL) {
         // (1.1) beim letzten Aufruf Pending-Order
         if (type == orders.knownOrders.type[i]) {
            // immer noch Pending-Order
            if (OrderCloseTime() != 0) {
               if (OrderComment() != "cancelled")
                  ArrayPushInt(failedOrders, orders.knownOrders.ticket[i]);      // keine regulär gestrichene Pending-Order: "deleted [no money]" etc.

               // geschlossene Pending-Order aus der Überwachung entfernen
               ArraySpliceInts(orders.knownOrders.ticket, i, 1);
               ArraySpliceInts(orders.knownOrders.type,   i, 1);
               knownSize--;
            }
         }
         else {
            // jetzt offene oder bereits geschlossene Position
            ArrayPushInt(openedPositions, orders.knownOrders.ticket[i]);         // Pending-Order wurde ausgeführt
            orders.knownOrders.type[i] = type;
            i++; continue;                                                       // ausgeführte Order in Zweig (1.2) nochmal prüfen (anstatt hier die Logik zu duplizieren)
         }
      }
      else {
         // (1.2) beim letzten Aufruf offene Position
         if (!OrderCloseTime()) {
            // immer noch offene Position
         }
         else {
            // jetzt geschlossene Position
            // prüfen, ob die Position durch ein Close-Limit, durch Stopout oder manuell geschlossen wurde
            bool closedByBroker = false;
            string comment = StringToLower(StringTrim(OrderComment()));

            if      (StringStartsWith(comment, "so:" )) closedByBroker = true;   // Margin Stopout erkennen
            else if (StringEndsWith  (comment, "[tp]")) closedByBroker = true;
            else if (StringEndsWith  (comment, "[sl]")) closedByBroker = true;
            else {                                                               // manche Broker setzen den OrderComment bei Schließung durch Limit nicht gemäß MT4-Standard
               if (!EQ(OrderTakeProfit(), 0)) {
                  if (type == OP_BUY ) closedByBroker = closedByBroker || (OrderClosePrice() >= OrderTakeProfit());
                  else                 closedByBroker = closedByBroker || (OrderClosePrice() <= OrderTakeProfit());
               }
               if (!EQ(OrderStopLoss(), 0)) {
                  if (type == OP_BUY ) closedByBroker = closedByBroker || (OrderClosePrice() <= OrderStopLoss());
                  else                 closedByBroker = closedByBroker || (OrderClosePrice() >= OrderStopLoss());
               }
            }
            if (closedByBroker)
               ArrayPushInt(closedPositions, orders.knownOrders.ticket[i]);      // Position wurde geschlossen
            ArraySpliceInts(orders.knownOrders.ticket, i, 1);                    // geschlossene Position aus der Überwachung entfernen
            ArraySpliceInts(orders.knownOrders.type,   i, 1);
            knownSize--;
         }
      }
   }


   // (2) über alle OpenOrders iterieren und neue Pending-Orders und Positionen in Überwachung aufnehmen
   while (true) {
      int ordersTotal = OrdersTotal();

      for (i=0; i < ordersTotal; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {                      // FALSE: während des Auslesens wurde von dritter Seite eine offene Order geschlossen oder gelöscht
            ordersTotal = -1;                                                    // Abbruch, via while-Schleife alle Orders nochmal verarbeiten, bis for fehlerfrei durchläuft
            break;
         }
         for (int n=0; n < knownSize; n++) {
            if (orders.knownOrders.ticket[n] == OrderTicket())                   // Order bereits bekannt
               break;
         }
         if (n >= knownSize) {                                                   // Order unbekannt: in Überwachung aufnehmen
            ArrayPushInt(orders.knownOrders.ticket, OrderTicket());
            ArrayPushInt(orders.knownOrders.type,   OrderType()  );
            knownSize++;
         }
      }

      if (ordersTotal == OrdersTotal())
         break;
   }

   return(!catch("CheckPositions(2)"));
}


/**
 * Handler für OrderFail-Events.
 *
 * @param  int tickets[] - Tickets der fehlgeschlagenen Pending-Orders
 *
 * @return bool - Erfolgsstatus
 */
bool onOrderFail(int tickets[]) {
   if (!track.orders)
      return(true);

   int positions = ArraySize(tickets);

   for (int i=0; i < positions; i++) {
      if (!SelectTicket(tickets[i], "onOrderFail(1)"))
         return(false);

      string type        = OperationTypeDescription(OrderType() & 1);      // Buy-Limit -> Buy, Sell-Stop -> Sell, etc.
      string lots        = DoubleToStr(OrderLots(), 2);
      int    digits      = MarketInfo(OrderSymbol(), MODE_DIGITS);
      int    pipDigits   = digits & (~1);
      string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
      string price       = NumberToStr(OrderOpenPrice(), priceFormat);
      string message     = "Order failed: "+ type +" "+ lots +" "+ GetStandardSymbol(OrderSymbol()) +" at "+ price + NL +"with error: \""+ OrderComment() +"\""+ NL +"("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +")";

      // ggf. SMS verschicken
      if (__SMS.alerts) {
         if (!SendSMS(__SMS.receiver, message))
            return(!SetLastError(stdlib.GetLastError()));
      }
      else if (__LOG) log("onOrderFail(2)  "+ message);
   }

   // ggf. Sound abspielen
   if (alerts.sound)
      PlaySoundEx(sound.orderFailed);
   return(!catch("onOrderFail(3)"));
}


/**
 * Handler für PositionOpen-Events.
 *
 * @param  int tickets[] - Tickets der neu geöffneten Positionen
 *
 * @return bool - Erfolgsstatus
 */
bool onPositionOpen(int tickets[]) {
   if (!track.orders)
      return(true);

   int positions = ArraySize(tickets);

   for (int i=0; i < positions; i++) {
      if (!SelectTicket(tickets[i], "onPositionOpen(1)"))
         return(false);

      string type        = OperationTypeDescription(OrderType());
      string lots        = DoubleToStr(OrderLots(), 2);
      int    digits      = MarketInfo(OrderSymbol(), MODE_DIGITS);
      int    pipDigits   = digits & (~1);
      string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
      string price       = NumberToStr(OrderOpenPrice(), priceFormat);
      string message     = "Position opened: "+ type +" "+ lots +" "+ GetStandardSymbol(OrderSymbol()) +" at "+ price + NL +"("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +")";

      // ggf. SMS verschicken
      if (__SMS.alerts) {
         if (!SendSMS(__SMS.receiver, message))
            return(!SetLastError(stdlib.GetLastError()));
      }
      else if (__LOG) log("onPositionOpen(2)  "+ message);
   }

   // ggf. Sound abspielen
   if (alerts.sound)
      PlaySoundEx(sound.positionOpened);
   return(!catch("onPositionOpen(3)"));
}


/**
 * Handler für PositionClose-Events.
 *
 * @param  int tickets[] - Tickets der geschlossenen Positionen
 *
 * @return bool - Erfolgsstatus
 */
bool onPositionClose(int tickets[]) {
   if (!track.orders)
      return(true);

   int positions = ArraySize(tickets);

   for (int i=0; i < positions; i++) {
      if (!SelectTicket(tickets[i], "onPositionClose(1)"))
         continue;

      string type        = OperationTypeDescription(OrderType());
      string lots        = DoubleToStr(OrderLots(), 2);
      int    digits      = MarketInfo(OrderSymbol(), MODE_DIGITS);
      int    pipDigits   = digits & (~1);
      string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
      string openPrice   = NumberToStr(OrderOpenPrice(), priceFormat);
      string closePrice  = NumberToStr(OrderClosePrice(), priceFormat);
      string message     = "Position closed: "+ type +" "+ lots +" "+ GetStandardSymbol(OrderSymbol()) +" open="+ openPrice +" close="+ closePrice + NL +"("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +")";

      // ggf. SMS verschicken
      if (__SMS.alerts) {
         if (!SendSMS(__SMS.receiver, message))
            return(!SetLastError(stdlib.GetLastError()));
      }
      else if (__LOG) log("onPositionClose(2)  "+ message);
   }

   // ggf. Sound abspielen
   if (alerts.sound)
      PlaySoundEx(sound.positionClosed);
   return(!catch("onPositionClose(3)"));
}


/**
 * Prüft auf ein ClosePrice-Event.
 *
 * @param  int i - Index in den zur Überwachung konfigurierten Signalen
 *
 * @return bool - Erfolgsstatus
 */
bool CheckClosePriceSignal(int i) {
   return(!catch("CheckClosePriceSignal(1)"));
}


//#define I_SIGNAL_DATA_TIMEFRAME  0
//#define I_SIGNAL_START_TIME      1                                   // Startzeit der Referenz-Session (Serverzeit)
//#define I_SIGNAL_START_BAR       2                                   // Baroffset der Startzeit        (max. PERIOD_H1)
//#define I_SIGNAL_END_TIME        3                                   // Endzeit der Referenz-Session   (Serverzeit)
//#define I_SIGNAL_END_BAR         4                                   // Baroffset der Endzeit          (max. PERIOD_H1)
//#define I_SIGNAL_LEVEL_HIGH      5                                   // Signallevel oben
//#define I_SIGNAL_LEVEL_LOW       6                                   // Signallevel unten
//#define I_SIGNAL_BAR_CLOSETIME   7                                   // CloseTime der aktuellen Session


datetime rt.sessionStartTime;             // Session, aus der ein Breakout signalisiert werden soll
datetime rt.sessionEndTime;
double   rt.sessionH;                     // oberer Breakout-Level
double   rt.sessionL;                     // unterer Breakout-Level
int      rt.dataTimeframe;
int      rt.dataStartBar;                 // Bar-Offsets der Breakout-Session innerhalb der verwendeten Datenreihe (weicht i.d.R. vom Signal-Timeframe ab)
int      rt.dataEndBar;
datetime rt.lastSessionEndTime;           // Endzeit der jüngsten Session-Periode innerhalb der verwendeten Datenreihe

bool     rt.done;


/**
 * Prüft auf ein Breakout-Event.
 *
 * @param  int index - Index in den zur Überwachung konfigurierten Signalen
 *
 * @return bool - Erfolgsstatus (nicht, ob ein neues Signal getriggert wurde)
 */
bool CheckBreakoutSignal(int index) {
   if ( price.config[index][I_PRICE_CONFIG_ID     ] != ET_PRICE_BAR_BREAKOUT) return(!catch("CheckBreakoutSignal(1)  signal "+ index +" is not a breakout signal = "+ price.config[index][I_PRICE_CONFIG_ID], ERR_RUNTIME_ERROR));
   if (!price.config[index][I_PRICE_CONFIG_ENABLED])                          return(true);

   int  signal.timeframe  = price.config[index][I_PRICE_CONFIG_TIMEFRAME];
   int  signal.bar        = price.config[index][I_PRICE_CONFIG_BAR      ];
   bool signal.onTouch    = price.config[index][I_PRICE_CONFIG_PARAM1   ] != 0;
   int  signal.resetAfter = price.config[index][I_PRICE_CONFIG_PARAM2   ];
   if (!rt.dataTimeframe)
      rt.dataTimeframe = Min(signal.timeframe, PERIOD_H1);


   // (1) Preislevel initialisieren und prüfen, ob changedBars(rt.dataTimeframe) eine Aktualisierung der Level erfordert (Re-Initialisierung)
   int oldError    = last_error;
   int changedBars = iChangedBars(NULL, rt.dataTimeframe, MUTE_ERR_SERIES_NOT_AVAILABLE);
   if (changedBars == -1) {                                          // Fehler
      if (last_error == ERR_SERIES_NOT_AVAILABLE)
         return(_true(SetLastError(oldError)));                      // ERR_SERIES_NOT_AVAILABLE unterdrücken und fortsetzen, nachdem Daten eingetroffen sind.
      return(false);
   }
   if (!changedBars)                                                 // z.B. bei künstlichem Tick oder Aufruf in init() oder deinit()
      return(true);

   // Eine Aktualisierung ist notwendig, wenn der Bereich der changedBars(rt.dataTimeframe) den Barbereich der Referenzsession einschließt oder
   // wenn die nächste Periode der Referenzsession beginnt.
   if (changedBars > 1) {
      debug("CheckBreakoutSignal(0.1)  changedBars="+ changedBars);
   }
   if (changedBars > rt.dataEndBar) {                                // eine gemeinsame Bedingung für Erst- und Re-Initialisierung
      if (!CheckBreakoutSignal.Init(index)) return(false);
   }
   else if (changedBars > 1) /*&&*/ if (iTime(NULL, rt.dataTimeframe, 0) >= rt.lastSessionEndTime) {
      if (!CheckBreakoutSignal.Init(index)) return(false);           // neue Periode im Timeframe der Referenzsession (zur Performancesteigerung in mehrere Conditions aufgeteilt)
   }


   // (2) Signallevel prüfen
   double price = NormalizeDouble(Bid, Digits);
   if (!rt.done) {
      debug("CheckBreakoutSignal(0.3)  checking H="+ NumberToStr(rt.sessionH, PriceFormat) +"  L="+ NumberToStr(rt.sessionL, PriceFormat));
      rt.done = true;
   }

   if (rt.sessionH != NULL) {
      if (GE(price, rt.sessionH)) {
         if (GT(price, rt.sessionH)) {
            debug("CheckBreakoutSignal(0.4)  new High["+ PeriodDescription(signal.timeframe) +","+ signal.bar +"] = "+ NumberToStr(price, PriceFormat));
            PlaySoundEx("OrderModified.wav");
            rt.sessionH = NULL;
            rt.done     = false;
         }
         //else if (signal.onTouch) debug("CheckBreakoutSignal(0.5)  touch signal: current price "+ NumberToStr(price, PriceFormat) +" = High["+ PeriodDescription(signal.timeframe) +","+ signal.bar +"]="+ NumberToStr(rt.sessionH, PriceFormat));
      }
   }
   if (rt.sessionL != NULL) {
      if (LE(price, rt.sessionL)) {
         if (LT(price, rt.sessionL)) {
            debug("CheckBreakoutSignal(0.6)  new Low["+ PeriodDescription(signal.timeframe) +","+ signal.bar +"] = "+ NumberToStr(price, PriceFormat));
            PlaySoundEx("OrderModified.wav");
            rt.sessionL = NULL;
            rt.done     = false;
         }
         //else if (signal.onTouch) debug("CheckBreakoutSignal(0.7)  touch signal: current price "+ NumberToStr(price, PriceFormat) +" = Low["+ PeriodDescription(signal.timeframe) +","+ signal.bar +"]="+ NumberToStr(rt.sessionL, PriceFormat));
      }
   }

   return(!catch("CheckBreakoutSignal(2)"));
}


/**
 * Initialisiert die Laufzeitdaten zur Verwaltung eines Breakout-Signals.
 *
 * @param  int index - Index in den zur Überwachung konfigurierten Signalen
 *
 * @return bool - Erfolgsstatus
 */
bool CheckBreakoutSignal.Init(int index) {
   if (!price.config[index][I_PRICE_CONFIG_ENABLED])
      return(true);

   int signalTimeframe = price.config[index][I_PRICE_CONFIG_TIMEFRAME];
   int bar             = price.config[index][I_PRICE_CONFIG_BAR      ];
   int dataTimeframe   = Min(signalTimeframe, PERIOD_H1);                              // der zur Ermittlung von Preisleveln benutzte Timeframe (maximal PERIOD_H1)


   // (1) Anfangs- und Endzeitpunkt der Bar und entsprechende Bar-Offsets bestimmen
   datetime openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv, lastSessionEndTime;
   int openBar, closeBar;

   for (int i=0; i<=bar; i++) {
      if (!iPreviousPeriodTimes(signalTimeframe, openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv))   return(false);
      //debug("CheckBreakoutSignal.Init(0.1)  bar="+ i +"  open="+ DateToStr(openTime.fxt, "w, D.M.Y H:I") +"  close="+ DateToStr(closeTime.fxt, "w, D.M.Y H:I"));
      openBar  = iBarShiftNext    (NULL, dataTimeframe, openTime.srv          ); if (openBar  == EMPTY_VALUE) return(false);
      closeBar = iBarShiftPrevious(NULL, dataTimeframe, closeTime.srv-1*SECOND); if (closeBar == EMPTY_VALUE) return(false);
      if (closeBar == -1) {                                                            // nicht ausreichende Daten zum Tracking: Signal deaktivieren und alles andere weiterlaufen lassen
         price.config[index][I_PRICE_CONFIG_ENABLED] = false;
         return(!warn("CheckBreakoutSignal.Init(1)  signal "+ index, ERR_HISTORY_INSUFFICIENT));
      }
      if (openBar < closeBar) {                                                        // Datenlücke, weiter zu den nächsten verfügbaren Daten
         i--;
      }
      else if (i == 0) {                                                               // openTime/closeTime enthalten die Daten der ersten Session mit vorhandenen Daten
         lastSessionEndTime = closeTime.srv;
      }
   }
   //debug("CheckBreakoutSignal.Init(0.2)  bar="+ bar +"  open="+ DateToStr(openTime.fxt, "w, D.M.Y H:I") +"  close="+ DateToStr(closeTime.fxt, "w, D.M.Y H:I"));


   // (2) High/Low bestimmen (openBar ist hier immer >= closeBar und Timeseries-Fehler können nicht mehr auftreten)
   int highBar = iHighest(NULL, dataTimeframe, MODE_HIGH, openBar-closeBar+1, closeBar);
   int lowBar  = iLowest (NULL, dataTimeframe, MODE_LOW , openBar-closeBar+1, closeBar);
   double H    = iHigh   (NULL, dataTimeframe, highBar);
   double L    = iLow    (NULL, dataTimeframe, lowBar );


   // (3) prüfen, ob die Level bereits gebrochen wurden
   if (highBar != iHighest(NULL, dataTimeframe, MODE_HIGH, highBar+1, 0)) H = NULL;    // High ist bereits gebrochen
   if (lowBar  != iLowest (NULL, dataTimeframe, MODE_LOW,  lowBar +1, 0)) L = NULL;    // Low ist bereits gebrochen


   debug("CheckBreakoutSignal.Init(0.3)  "+ PeriodDescription(signalTimeframe) +"["+ bar +"]  H="+ NumberToStr(H, PriceFormat) +"  L="+ NumberToStr(L, PriceFormat));
   rt.done = true;


   // (4) alle Daten speichern
   rt.sessionStartTime   = openTime.srv;
   rt.sessionEndTime     = closeTime.srv;
   rt.sessionH           = NormalizeDouble(H, Digits);
   rt.sessionL           = NormalizeDouble(L, Digits);
   rt.dataTimeframe      = dataTimeframe;
   rt.dataStartBar       = openBar;
   rt.dataEndBar         = closeBar;
   rt.lastSessionEndTime = lastSessionEndTime - 1*SECOND;

   return(!catch("CheckBreakoutSignal.Init(2)"));
}


/**
 * Prüft auf ein BarRange-Event.
 *
 * @param  int index - Index in den zur Überwachung konfigurierten Signalen
 *
 * @return bool - Erfolgsstatus
 */
bool CheckRangeSignal(int index) {
   if (!price.config[index][I_PRICE_CONFIG_ENABLED])
      return(true);

   // Signaldaten ggf. initialisieren
   if (false /*|| !rt.sessionStartTime*/)
      if (!CheckRangeSignal.Init(index)) return(false);

   // Signallevel prüfen
   double levelH = rt.sessionH;
   double levelL = rt.sessionL;
   debug("CheckRangeSignal(0.1)  checking for levelH="+ NumberToStr(levelH, PriceFormat) +"  levelL="+ NumberToStr(levelL, PriceFormat));

   return(!catch("CheckRangeSignal(1)"));
}


/**
 * Initialisiert die Laufzeitdaten zur Verwaltung eines BarRange-Signals.
 *
 * @param  int index - Index in den zur Überwachung konfigurierten Signalen
 *
 * @return bool - Erfolgsstatus
 */
bool CheckRangeSignal.Init(int index) {
   /*
   if (!price.config[index][I_PRICE_CONFIG_ENABLED])
      return(true);

   int timeframe = price.config[index][I_PRICE_CONFIG_TIMEFRAME];
   int bar       = price.config[index][I_PRICE_CONFIG_BAR      ];
   int range     = price.config[index][I_PRICE_CONFIG_PARAM1   ];
   int reset     = price.config[index][I_PRICE_CONFIG_PARAM2   ];


   // (1) Anfangs- und Endzeitpunkt der Bar und entsprechende Bar-Offsets bestimmen (für alle Signale wird PERIOD_H1 benutzt)
   datetime openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv;
   int openBar, closeBar;

   for (int i=0; i<=bar; i++) {
      if (!iPreviousPeriodTimes(timeframe, openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv))     return(false);
      //debug("CheckRangeSignal.Init(0.1)  bar="+ i +"  open="+ DateToStr(openTime.fxt, "w, D.M.Y H:I") +"  close="+ DateToStr(closeTime.fxt, "w, D.M.Y H:I"));
      openBar  = iBarShiftNext    (NULL, PERIOD_H1, openTime.srv          ); if (openBar  == EMPTY_VALUE) return(false);
      closeBar = iBarShiftPrevious(NULL, PERIOD_H1, closeTime.srv-1*SECOND); if (closeBar == EMPTY_VALUE) return(false);
      if (closeBar == -1) {                                       // nicht ausreichende Daten zum Tracking: Signal deaktivieren und alles andere weiterlaufen lassen
         price.config[index][I_PRICE_CONFIG_ENABLED] = false;
         return(!warn("CheckRangeSignal.Init(1)  signal "+ index, ERR_HISTORY_INSUFFICIENT));
      }
      if (openBar < closeBar)                                     // Datenlücke, weiter zu den nächsten verfügbaren Daten
         i--;
   }
   //debug("CheckRangeSignal.Init(0.2)  bar="+ PeriodDescription(timeframe) +","+ bar +"  open="+ DateToStr(openTime.fxt, "w, D.M.Y H:I") +"  close="+ DateToStr(closeTime.fxt, "w, D.M.Y H:I"));


   // (2) High/Low bestimmen (openBar ist hier immer >= closeBar und Timeseries-Fehler können nicht mehr auftreten)
   int highBar = iHighest(NULL, PERIOD_H1, MODE_HIGH, openBar-closeBar+1, closeBar);
   int lowBar  = iLowest (NULL, PERIOD_H1, MODE_LOW , openBar-closeBar+1, closeBar);
   double H    = iHigh   (NULL, PERIOD_H1, highBar);
   double L    = iLow    (NULL, PERIOD_H1, lowBar );
   //debug("CheckRangeSignal.Init(0.3)  bar="+ PeriodDescription(timeframe) +","+ bar +"  H="+ NumberToStr(H, PriceFormat) +"  L="+ NumberToStr(L, PriceFormat));


   // (3) Signalrange berechnen, falls nicht auf Breakout geprüft werden soll
   double dist = (H-L) * Min(range, 100-range)/100;
   double levelH = H - dist;
   double levelL = L + dist;
   //debug("CheckRangeSignal.Init(0.4)  bar="+ PeriodDescription(timeframe) +","+ bar +"  levelH="+ NumberToStr(levelH, PriceFormat) +"  levelL="+ NumberToStr(levelL, PriceFormat));


   // (4) prüfen, ob die Signallevel bereits gebrochen wurden


   // (5) alle Daten speichern
   price.rtdata[index][I_SIGNAL_START_TIME] = openTime.srv;
   price.rtdata[index][I_SIGNAL_START_BAR ] = openBar;
   price.rtdata[index][I_SIGNAL_END_TIME  ] = closeTime.srv;
   price.rtdata[index][I_SIGNAL_END_BAR   ] = closeBar;
   price.rtdata[index][I_SIGNAL_LEVEL_HIGH] = NormalizeDouble(levelH, Digits);
   price.rtdata[index][I_SIGNAL_LEVEL_LOW ] = NormalizeDouble(levelL, Digits);
   */
   return(!catch("CheckRangeSignal.Init(2)"));
}


/**
 * Zeigt den aktuellen Laufzeitstatus optisch an. Ist immer aktiv.
 *
 * @param  int error - anzuzeigender Fehler (default: keiner)
 *
 * @return int - der übergebene Fehler oder der Fehlerstatus der Funktion, falls kein Fehler übergeben wurde
 */
int ShowStatus(int error=NULL) {
   if (__STATUS_OFF)
      error = __STATUS_OFF.reason;

   string msg = __NAME__;
   if (!error) msg = StringConcatenate(msg,                                      NL, NL);
   else        msg = StringConcatenate(msg, "  [", ErrorDescription(error), "]", NL, NL);

   int size = ArrayRange(price.config, 0);

   for (int n, i=0; i < size; i++) {
      n = i + 1;
      switch (price.config[i][I_PRICE_CONFIG_ID]) {
         case ET_PRICE_BAR_CLOSE:    msg = StringConcatenate(msg, "Signal ", n, " ", ifString(price.config[i][I_PRICE_CONFIG_ENABLED], "enabled", "disabled"), ":   Price close of "+ PeriodDescription(price.config[i][I_PRICE_CONFIG_TIMEFRAME]) +"["+ price.config[i][I_PRICE_CONFIG_BAR] +"]", NL); break;
         case ET_PRICE_BAR_RANGE:    msg = StringConcatenate(msg, "Signal ", n, " ", ifString(price.config[i][I_PRICE_CONFIG_ENABLED], "enabled", "disabled"), ":   Price range of "+ PeriodDescription(price.config[i][I_PRICE_CONFIG_TIMEFRAME]) +"["+ price.config[i][I_PRICE_CONFIG_BAR] +"]", NL); break;
         case ET_PRICE_BAR_BREAKOUT: msg = StringConcatenate(msg, "Signal ", n, " ", ifString(price.config[i][I_PRICE_CONFIG_ENABLED], "enabled", "disabled"), ":   Breakout of "   + PeriodDescription(price.config[i][I_PRICE_CONFIG_TIMEFRAME]) +"["+ price.config[i][I_PRICE_CONFIG_BAR] +"]", NL); break;
         default:
            return(catch("ShowStatus(1)  unknow price signal["+ i +"] = "+ price.config[i][I_PRICE_CONFIG_ID], ERR_RUNTIME_ERROR));
      }
   }

   // etwas Abstand nach oben für Instrumentanzeige
   Comment(StringConcatenate(NL, msg));
   if (__WHEREAMI__ == FUNC_INIT)
      WindowRedraw();

   if (!catch("ShowStatus(3)"))
      return(error);
   return(last_error);
}


/**
 * String-Repräsentation der Input-Parameter fürs Logging bei Aufruf durch iCustom().
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()  inputs: ",

                            "Track.Order.Events="    , BoolToStr(Track.Order.Events),  "; ",
                            "Track.Price.Events="    , BoolToStr(Track.Price.Events),  "; ",
                            "Alerts.Sound="          , BoolToStr(Alerts.Sound),        "; ",
                            "Alerts.Mail.Receiver=\"", Alerts.Mail.Receiver,         "\"; ",
                            "Alerts.SMS.Receiver=\"" , Alerts.SMS.Receiver,          "\"; ",
                            "Alerts.HTTP.Url=\""     , Alerts.HTTP.Url,              "\"; ",
                            "Alerts.ICQ.UserID=\""   , Alerts.ICQ.UserID,            "\"; "
                            )
   );
}
