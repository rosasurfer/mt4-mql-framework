/**
 * EventTracker für getriggerte Pending-Orders. Benachrichtigt akustisch und/oder per SMS.
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
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <functions/Configure.Signal.SMS.mqh>
#include <functions/Configure.Signal.Sound.mqh>
#include <rsfLibs.mqh>

#property indicator_chart_window


// Konfiguration
bool   eventTracker.initialized;                                     // Settings sind per Account, der kann bei Terminalstart kurzzeitig unbekannt sein
bool   sound.alerts;

bool   track.orders;
string sound.order.failed   = "speech/OrderCancelled.wav";
string sound.position.open  = "speech/OrderFilled.wav";
string sound.position.close = "speech/PositionClosed.wav";

int    knownOrders.ticket[];                                         // vom letzten Aufruf bekannte offene Orders
int    knownOrders.type  [];

string accountAlias;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // EventTracker initialisieren (kann fehlschlagen, wenn die AccountNumber() beim Terminalstart noch nicht verfügbar ist)
   eventTracker.initialized = EventTracker.init();
   if (!eventTracker.initialized)
      return(last_error);

   SetIndexLabel(0, NULL);                                           // Datenanzeige ausschalten
   return(catch("onInit(1)"));
}


/**
 * Initialisiert und konfiguriert den EventTracker mit Account-spezifischen Einstellungen.
 *
 * @return bool - Erfolgsstatus
 */
bool EventTracker.init() {
   if (!Configure.Signal.Sound("auto", sound.alerts))                  return(false);
   if (!Configure.Signal.SMS  ("auto", __SMS.alerts, __SMS.receiver )) return(false);

   track.orders = GetConfigBool("EventTracker", "Track.Orders");

   // TODO: Orders in Library zwischenspeichern und bei init() daraus restaurieren

   // AccountAlias
   int    account = GetAccountNumber(); if (!account) return(false);
   string section = "Accounts";
   string key     = account +".alias";
   accountAlias = GetGlobalConfigString(section, key);
   if (!StringLen(accountAlias)) return(!catch("EventTracker.init(1)  missing account setting ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));

   debug(InputsToStr());
   return(true);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // (1) endgültige Prüfung, ob der EventTracker initialisiert ist
   if (!eventTracker.initialized) {
      eventTracker.initialized = EventTracker.init();
      if (!eventTracker.initialized) return(last_error);
   }

   // (2) Pending- und Limit-Orders überwachen
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
            string comment = StrToLower(StrTrim(OrderComment()));

            if      (StrStartsWith(comment, "so:" )) closedByBroker = true;      // Margin Stopout erkennen
            else if (StrEndsWith  (comment, "[tp]")) closedByBroker = true;
            else if (StrEndsWith  (comment, "[sl]")) closedByBroker = true;
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
      string message     = "Order failed: "+ type +" "+ lots +" "+ GetStandardSymbol(OrderSymbol()) +" at "+ price + NL +"with error: \""+ OrderComment() +"\""+ NL +"("+ TimeToStr(TimeLocalEx("onOrderFail(2)"), TIME_MINUTES|TIME_SECONDS) +", "+ accountAlias +")";

      // ggf. SMS verschicken
      if (__SMS.alerts) {
         if (!SendSMS(__SMS.receiver, message)) return(false);
      }
      else if (__LOG()) log("onOrderFail(3)  "+ message);
   }

   // ggf. Sound abspielen
   if (sound.alerts)
      PlaySoundEx(sound.order.failed);
   return(!catch("onOrderFail(4)"));
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
      string message     = "Position opened: "+ type +" "+ lots +" "+ GetStandardSymbol(OrderSymbol()) +" at "+ price + NL +"("+ TimeToStr(TimeLocalEx("onPositionOpen(2)"), TIME_MINUTES|TIME_SECONDS) +", "+ accountAlias +")";

      // ggf. SMS verschicken
      if (__SMS.alerts) {
         if (!SendSMS(__SMS.receiver, message)) return(false);
      }
      else if (__LOG()) log("onPositionOpen(3)  "+ message);
   }

   // ggf. Sound abspielen
   if (sound.alerts)
      PlaySoundEx(sound.position.open);
   return(!catch("onPositionOpen(4)"));
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
      string message     = "Position closed: "+ type +" "+ lots +" "+ GetStandardSymbol(OrderSymbol()) +" open="+ openPrice +" close="+ closePrice + NL +"("+ TimeToStr(TimeLocalEx("onPositionClose(2)"), TIME_MINUTES|TIME_SECONDS) +", "+ accountAlias +")";

      // ggf. SMS verschicken
      if (__SMS.alerts) {
         if (!SendSMS(__SMS.receiver, message)) return(false);
      }
      else if (__LOG()) log("onPositionClose(3)  "+ message);
   }

   // ggf. Sound abspielen
   if (sound.alerts)
      PlaySoundEx(sound.position.close);
   return(!catch("onPositionClose(4)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("config:",                                     NL,

                            "sound.alerts=", BoolToStr(sound.alerts), ";", NL,
                            "track.orders=", BoolToStr(track.orders), ";")
   );
}
