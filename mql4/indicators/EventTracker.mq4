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
 *      • Eventkey:      {Timeframe-Key}.{Signal-Key}
 *
 *      • Timeframe-Key: {number}{[Day|Week|Month][s]}Ago            ; Singular und Plural der Timeframe-Bezeichner sind austauschbar
 *                       Today                                       ; Synonym für 0DaysAgo
 *                       Yesterday                                   ; Synonym für 1DayAgo
 *                       This[Day|Week|Month]                        ; Synonym für 0[Days|Weeks|Months]Ago
 *                       Last[Day|Week|Month]                        ; Synonym für 1[Day|Week|Month]Ago
 *
 *      • Signal-Key:    Close           = On | Off                  ; Erreichen des Close-Preises der Bar
 *                       Range           = {90}%                     ; Erreichen der {x}%-Schwelle der Bar-Range
 *                       RangeBreak      = On | Off                  ; Bruch der Bar-Range = neues High/Low
 *                       RangeBreak.Wait = {5} [minute|hour][s]      ; Wartezeit, bevor das nächste neue High/Low signalisiert wird
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
#define ET_PRICESIGNAL_CLOSE        1
#define ET_PRICESIGNAL_RANGE        2
#define ET_PRICESIGNAL_RANGEBREAK   3

#define I_PRICESIGNAL_ID            0                                // Signal-ID:       int
#define I_PRICESIGNAL_ENABLED       1                                // SignalEnabled:   int 0|1
#define I_PRICESIGNAL_TIMEFRAME     2                                // SignalTimeframe: int PERIOD_D1|PERIOD_W1|PERIOD_MN1
#define I_PRICESIGNAL_BAR           3                                // SignalBar:       int 0..x
#define I_PRICESIGNAL_PARAM1        4                                // SignalParam1:    int
#define I_PRICESIGNAL_PARAM2        5                                // SignalParam2:    int
#define I_PRICESIGNAL_PARAM3        6                                // SignalParam3:    int

int price.signals[][7];


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

      // Eventkey:      {Timeframe-Key}.{Signal-Key}
      //
      // Timeframe-Key: {number}{[Day|Week|Month][s]}Ago            ; Singular und Plural der Timeframe-Bezeichner sind austauschbar
      //                Today                                       ; Synonym für 0DaysAgo
      //                Yesterday                                   ; Synonym für 1DayAgo
      //                This[Day|Week|Month]                        ; Synonym für 0[Days|Weeks|Months]Ago
      //                Last[Day|Week|Month]                        ; Synonym für 1[Day|Week|Month]Ago
      //
      // Signal-Key:    Close           = On | Off                  ; Erreichen des Close-Preises der Bar
      //                Range           = {90}%                     ; Erreichen der {x}%-Schwelle der Bar-Range
      //                RangeBreak      = On | Off                  ; Bruch der Bar-Range = neues High/Low
      //                RangeBreak.Wait = {5} [minute|hour][s]      ; Wartezeit, bevor das nächste neue High/Low signalisiert wird
      //
      // Yesterday.RangeBreak = 1
      ArrayResize(price.signals, 1);
      price.signals[0][I_PRICESIGNAL_ID       ] = ET_PRICESIGNAL_RANGEBREAK;
      price.signals[0][I_PRICESIGNAL_ENABLED  ] = true;                       // (int) bool
      price.signals[0][I_PRICESIGNAL_TIMEFRAME] = PERIOD_D1;
      price.signals[0][I_PRICESIGNAL_BAR      ] = 1;
      price.signals[0][I_PRICESIGNAL_PARAM1   ] = 15*MINUTES;                 // RangeBreak.Wait
      price.signals[0][I_PRICESIGNAL_PARAM2   ] = NULL;
      price.signals[0][I_PRICESIGNAL_PARAM3   ] = NULL;
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
            else                    return(!catch("Configure(2)  Invalid input parameter Alerts.SMS.Receiver = \""+ Alerts.SMS.Receiver +"\"", ERR_INVALID_INPUT_PARAMVALUE));
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
      debug("Configure()  "+ StringConcatenate("track.orders=", BoolToStr(track.orders),                                          "; ",
                                               "track.price=",  BoolToStr(track.price),                                           "; ",
                                               "alerts.sound=", BoolToStr(alerts.sound),                                          "; ",
                                               "alerts.mail=" , ifString(alerts.mail, "\""+ alerts.mail.receiver +"\"", "false"), "; ",
                                               "alerts.sms="  , ifString(alerts.sms,  "\""+ alerts.sms.receiver  +"\"", "false"), "; ",
                                               "alerts.http=" , ifString(alerts.http, "\""+ alerts.http.url      +"\"", "false"), "; ",
                                               "alerts.icq="  , ifString(alerts.icq,  "\""+ alerts.icq.userId    +"\"", "false"), "; "
      ));
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
      int size = ArrayRange(price.signals, 0);

      for (int i=0; i < size; i++) {
         if (price.signals[i][I_PRICESIGNAL_ENABLED] != 0) {
            switch (price.signals[i][I_PRICESIGNAL_ID]) {
               case ET_PRICESIGNAL_CLOSE     : CheckClosePriceSignal(i); break;
               case ET_PRICESIGNAL_RANGE     : CheckRangeSignal     (i); break;
               case ET_PRICESIGNAL_RANGEBREAK: CheckRangeBreakSignal(i); break;
               default:
                  catch("onTick(1)  unknow price signal["+ i +"] = "+ price.signals[i][I_PRICESIGNAL_ID], ERR_RUNTIME_ERROR);
            }
         }
         if (__STATUS_OFF)
            break;
      }
   }

   return(ShowStatus(last_error));
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

   int size = ArrayRange(price.signals, 0);

   for (int n, i=0; i < size; i++) {
      n = i + 1;
      switch (price.signals[i][I_PRICESIGNAL_ID]) {
         case ET_PRICESIGNAL_CLOSE     : msg = StringConcatenate(msg, "Price signal ", n, " ", ifString(price.signals[i][I_PRICESIGNAL_ENABLED], "enabled", "disabled"), ":   Close of 1 day ago",      NL); break;
         case ET_PRICESIGNAL_RANGE     : msg = StringConcatenate(msg, "Price signal ", n, " ", ifString(price.signals[i][I_PRICESIGNAL_ENABLED], "enabled", "disabled"), ":   Range of 1 day ago 10%",  NL); break;
         case ET_PRICESIGNAL_RANGEBREAK: msg = StringConcatenate(msg, "Price signal ", n, " ", ifString(price.signals[i][I_PRICESIGNAL_ENABLED], "enabled", "disabled"), ":   Break of bar "+ price.signals[i][I_PRICESIGNAL_BAR] +" day ago", NL); break;
         default:
            return(catch("ShowStatus(1)  unknow price signal["+ i +"] = "+ price.signals[i][I_PRICESIGNAL_ID], ERR_RUNTIME_ERROR));
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
 * Prüft auf ein Price-Event.
 *
 * @param  int i - Index in den zur Überwachung konfigurierten Signalen
 *
 * @return bool - Erfolgsstatus
 */
bool CheckClosePriceSignal(int i) {
   return(!catch("CheckClosePriceSignal(1)"));
}


/**
 * Prüft auf ein Price-Event.
 *
 * @param  int i - Index in den zur Überwachung konfigurierten Signalen
 *
 * @return bool - Erfolgsstatus
 */
bool CheckRangeSignal(int i) {
   return(!catch("CheckRangeSignal(1)"));
}


/**
 * Prüft auf ein Price-Event.
 *
 * @param  int i - Index in den zur Überwachung konfigurierten Signalen
 *
 * @return bool - ob ein neues Signal detektiert wurde
 */
bool CheckRangeBreakSignal(int i) {
   if (!price.signals[i][I_PRICESIGNAL_ENABLED])
      return(false);

   debug("CheckRangeBreakSignal()  i="+ i);

   int timeframe = price.signals[i][I_PRICESIGNAL_TIMEFRAME];
   int bar       = price.signals[i][I_PRICESIGNAL_BAR      ];
   int wait      = price.signals[i][I_PRICESIGNAL_PARAM1   ];


   // zur Berechnung zu nutzende Datenreihe bestimmen
   // Anfangs- und Endzeitpunkt der Bar bestimmen
   // High/Low-Kurse bestimmen





   switch (timeframe) {
      case PERIOD_D1 :
      case PERIOD_W1 :
      case PERIOD_MN1:

      default: return(!catch("CheckRangeBreakSignal(1)  unsupported signal timeframe = "+ TimeframeToStr(timeframe, MUTE_ERR_INVALID_PARAMETER)));
   }
   return(!catch("CheckRangeBreakSignal(2)"));
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
