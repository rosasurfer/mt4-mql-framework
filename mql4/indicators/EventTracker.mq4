/**
 * EventTracker für verschiedene Ereignisse. Benachrichtigt optisch, akustisch, per HTML-Request, E-Mail und/oder SMS.
 *
 *
 * Zu überwachende Preis-Events werden in der Account-Konfiguration je Instrument konfiguriert. Es liegt in der Verantwortung des Benutzers, nur einen
 * EventTracker je Instrument zu laden. Preis-Events:
 *  - neues Tages-High/Low
 *  - Bruch Vortages-Range
 *  - neues Wochen-High/Low
 *  - Bruch Vorwochen-Range
 *
 * Zu überwachende Order-Events werden mit Indikator-Inputparametern konfiguriert. Ein so konfigurierter EventTracker überwacht alle Symbole des Accounts,
 * nicht nur das des aktuellen Charts. Es liegt in der Verantwortung des Benutzers, nur einen von allen laufenden EventTrackern für die Orderüberwachung
 * zu konfigurieren. Order-Events:
 *  - Orderausführung fehlgeschlagen
 *  - Position geöffnet
 *  - Position geschlossen
 *
 * Die Art der Benachrichtigung (Sound, HTML-Request, E-Mail und/oder SMS) kann je Event konfiguriert werden.
 *
 *
 *
 *
 * TODO:
 * -----
 *  - PositionOpen-/Close-Events während Timeframe- oder Symbolwechsel werden nicht erkannt
 *  - bei Accountwechsel auftretende Fehler werden nicht abgefangen
 *  - Konfiguration per Indikator-Parameter und NICHT per Accountkonfiguration
 *  - Konfiguration während eines init-Cycles im Chart speichern, damit Recompilation überlebt werden kann
 *  - Anzeige der überwachten Kriterien
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern bool   Track.Orders               = false;

extern bool   Order.Alerts.Sound         = true;                     // alle Alerts bis auf Sounds sind per Default inaktiv
extern string Order.Alerts.HTTP.Url      = "";                       // vollständige URL ("system" => global konfigurierte URL    )
extern string Order.Alerts.Mail.Receiver = "email@address.tld";      // E-Mailadresse    ("system" => global konfigurierte Adresse)
extern string Order.Alerts.SMS.Receiver  = "phone-number";           // Telefonnummer    ("system" => global konfigurierte Nummer )

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#include <core/indicator.mqh>


bool     isConfigured;

string   sound.order.failed    = "speech/OrderExecutionFailed.wav";
string   sound.position.opened = "speech/OrderFilled.wav";
string   sound.position.closed = "speech/PositionClosed.wav";

int      knownOrders.ticket[];                                       // vom letzten Aufruf bekannte offene Orders
int      knownOrders.type  [];


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Konfiguration einlesen. Ist die AccountNumber() beim Terminalstart noch nicht verfügbar, wird der Aufruf in onTick() wiederholt.
   Configure();

   SetIndexLabel(0, NULL);                                           // Datenanzeige ausschalten
   return(catch("onInit(1)"));
}


/**
 * Konfiguriert den EventTracker mit Account-spezifischen Einstellungen.
 *
 * @return bool - Erfolgsstatus
 *
 * @throws ERS_TERMINAL_NOT_YET_READY, wenn die AccountNumber bei Terminalstart vorübergehend nicht verfügbar ist
 */
bool Configure() {
   // TODO: Inputparameter auswerten und validieren
   //extern string Order.Alerts.HTTP.Url      = "";
   //extern string Order.Alerts.Mail.Receiver = "email@address.tld";
   //extern string Order.Alerts.SMS.Receiver  = "phone-number";


   int account = GetAccountNumber(); if (!account) return(!SetLastError(ERS_TERMINAL_NOT_YET_READY));

   string mqlDir = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string file   = TerminalPath() + mqlDir +"\\files\\"+ ShortAccountCompany() +"\\"+ account +"_config.ini";

   // SMS.Alerts
   __SMS.alerts = GetIniBool(file, "EventTracker", "SMS.Alerts", false);
   if (__SMS.alerts) {
      __SMS.receiver = GetGlobalConfigString("SMS", "Receiver", "");
      // TODO: Rufnummer validieren
      //if (!StringIsDigit(__SMS.receiver)) return(!catch("Configure(1)   invalid config value [SMS]->Receiver = \""+ __SMS.receiver +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
      if (!StringLen(__SMS.receiver))
         __SMS.alerts = false;
   }


   debug(InputsToStr());                                             // temporär: als externe Anzeige der erfolgreichen Konfiguration

   isConfigured = !catch("Configure(2)");
   return(isConfigured);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // (1) endgültige Prüfung, ob der EventTracker konfiguriert ist
   if (!isConfigured) {
      if (!Configure()) /*&&*/ if (last_error!=ERS_TERMINAL_NOT_YET_READY)
         return(last_error);
   }

   // (2) Pending- und Limit-Orders überwachen
   if (Track.Orders) {
      int failedOrders   []; ArrayResize(failedOrders,    0);
      int openedPositions[]; ArrayResize(openedPositions, 0);
      int closedPositions[]; ArrayResize(closedPositions, 0);

      if (!CheckPositions(failedOrders, openedPositions, closedPositions))
         return(last_error);

      if (ArraySize(failedOrders   ) > 0) onOrderFail    (failedOrders   );
      if (ArraySize(openedPositions) > 0) onPositionOpen (openedPositions);
      if (ArraySize(closedPositions) > 0) onPositionClose(closedPositions);
   }
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

   int type, knownSize=ArraySize(knownOrders.ticket);


   // (1) über alle bekannten Orders iterieren (rückwärts, um beim Entfernen von Elementen die Schleife einfacher managen zu können)
   for (int i=knownSize-1; i >= 0; i--) {
      if (!SelectTicket(knownOrders.ticket[i], "CheckPositions(1)"))
         return(false);
      type = OrderType();

      if (knownOrders.type[i] > OP_SELL) {
         // (1.1) beim letzten Aufruf Pending-Order
         if (type == knownOrders.type[i]) {
            // immer noch Pending-Order
            if (OrderCloseTime() != 0) {
               if (OrderComment() != "cancelled")
                  ArrayPushInt(failedOrders, knownOrders.ticket[i]);             // keine regulär gestrichene Pending-Order: "deleted [no money]" etc.

               // geschlossene Pending-Order aus der Überwachung entfernen
               ArraySpliceInts(knownOrders.ticket, i, 1);
               ArraySpliceInts(knownOrders.type,   i, 1);
               knownSize--;
            }
         }
         else {
            // jetzt offene oder bereits geschlossene Position
            ArrayPushInt(openedPositions, knownOrders.ticket[i]);                // Pending-Order wurde ausgeführt
            knownOrders.type[i] = type;
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
            else {                                                               // manche Broker setzen den OrderComment bei Schließung durch Limit nicht korrekt
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
               ArrayPushInt(closedPositions, knownOrders.ticket[i]);             // Position wurde geschlossen
            ArraySpliceInts(knownOrders.ticket, i, 1);                           // geschlossene Position aus der Überwachung entfernen
            ArraySpliceInts(knownOrders.type,   i, 1);
            knownSize--;
         }
      }
   }


   // (2) über alle OpenOrders iterieren und neue Pending-Orders und Positionen in Überwachung aufnehmen
   while (true) {
      int ordersTotal = OrdersTotal();

      for (i=0; i < ordersTotal; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {          // FALSE: während des Auslesens wurde von dritter Seite eine offene Order geschlossen oder gelöscht
            ordersTotal = -1;                                        // Abbruch, via while-Schleife alle Orders nochmal verarbeiten, bis for fehlerfrei durchläuft
            break;
         }
         for (int n=0; n < knownSize; n++) {
            if (knownOrders.ticket[n] == OrderTicket())              // Order bereits bekannt
               break;
         }
         if (n >= knownSize) {                                       // Order unbekannt: in Überwachung aufnehmen
            ArrayPushInt(knownOrders.ticket, OrderTicket());
            ArrayPushInt(knownOrders.type,   OrderType()  );
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
   if (!Track.Orders)
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
      else if (__LOG) log("onOrderFail(2)   "+ message);
   }

   // ggf. Sound abspielen
   if (Order.Alerts.Sound)
      PlaySoundEx(sound.order.failed);
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
   if (!Track.Orders)
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
      else if (__LOG) log("onPositionOpen(2)   "+ message);
   }

   // ggf. Sound abspielen
   if (Order.Alerts.Sound)
      PlaySoundEx(sound.position.opened);
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
   if (!Track.Orders)
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
      else if (__LOG) log("onPositionClose(2)   "+ message);
   }

   // ggf. Sound abspielen
   if (Order.Alerts.Sound)
      PlaySoundEx(sound.position.closed);
   return(!catch("onPositionClose(3)"));
}


/**
 * String-Repräsentation der Input-Parameter fürs Logging bei Aufruf durch iCustom().
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()   inputs: ",

                            "Order.Alerts.Sound=", BoolToStr(Order.Alerts.Sound), "; ",

                            "SMS.Alerts=",         BoolToStr(__SMS.alerts),       "; ",
                  ifString(__SMS.alerts,
          StringConcatenate("SMS.Receiver=\"",   __SMS.receiver,                "\"; "), ""),

                            "Track.Orders=",       BoolToStr(Track.Orders),       "; ")
   );
}
