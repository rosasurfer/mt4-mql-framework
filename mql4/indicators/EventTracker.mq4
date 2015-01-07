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
 *  - großflächige Anzeige der überwachten Kriterien
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/indicator.mqh>


// Konfiguration
datetime init.time;                                                  // Zeitpunkt des letzten init()-Cycles
bool     eventTracker.initialized;                                   // Settings sind per Account, der kann bei Terminalstart kurzzeitig unbekannt sein
bool     sound.alerts;

bool     track.positions;
string   sound.order.failed   = "Order-Execution-Failed.wav";
string   sound.position.open  = "OrderFilled.wav";
string   sound.position.close = "PositionClosed.wav";

int      knownOrders.ticket[];                                       // vom letzten Aufruf bekannte offene Orders
int      knownOrders.type  [];


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // EventTracker initialisieren (kann fehlschlagen, wenn die AccountNumber() beim Terminalstart noch nicht verfügbar ist)
   eventTracker.initialized = EventTracker.init();
   if (!eventTracker.initialized) /*&&*/ if (IsLastError()) /*&&*/ if (last_error!=ERS_TERMINAL_NOT_YET_READY)
      return(last_error);

   SetIndexLabel(0, NULL);                                           // Datenanzeige ausschalten
   return(catch("onInit(1)"));
}


/**
 * Initialisiert und konfiguriert den EventTracker mit Account-spezifischen Einstellungen.
 *
 * @return bool - Erfolgsstatus
 */
bool EventTracker.init() { //throws ERS_TERMINAL_NOT_YET_READY
   int account = GetAccountNumber();
   if (!account)
      return(!SetLastError(ERS_TERMINAL_NOT_YET_READY));

   string mqlDir = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string file   = TerminalPath() + mqlDir +"\\files\\"+ ShortAccountCompany() +"\\"+ account +"_config.ini";

   // Sound.Alerts
   sound.alerts = GetIniBool(file, "EventTracker", "Sound.Alerts", false);

   // SMS.Alerts
   __SMS.alerts = GetIniBool(file, "EventTracker", "SMS.Alerts", false);
   if (__SMS.alerts) {
      __SMS.receiver = GetGlobalConfigString("SMS", "Receiver", "");
      // TODO: Rufnummer validieren
      //if (!StringIsDigit(__SMS.receiver)) return(!catch("EventTracker.init(1)   invalid config value [SMS]->Receiver = \""+ __SMS.receiver +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
      if (!StringLen(__SMS.receiver))
         __SMS.alerts = false;
   }

   // Track.Positions
   track.positions = GetIniBool(file, "EventTracker", "Track.Positions", false);

   // TODO: Orders in Library zwischenspeichern und bei init() daraus restaurieren

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
      if (!eventTracker.initialized) /*&&*/ if (IsLastError()) /*&&*/ if (last_error!=ERS_TERMINAL_NOT_YET_READY)
         return(last_error);
   }

   // (2) Pending- und Limit-Orders überwachen
   if (track.positions) {
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
     (1) alle bekannten Pending-Orders und Positionen auf OrderClose prüfen:    über bekannte Orders iterieren
     (2) alle unbekannten Positionen mit Close-Limits in Überwachung aufnehmen: über OpenOrders iterieren

   beides zusammen
   ---------------
     (1.1) alle bekannten Pending-Orders auf Statusänderung prüfen:                                  über bekannte Orders iterieren
     (1.2) alle bekannten Pending-Orders und Positionen auf OrderClose prüfen:                       über bekannte Orders iterieren

     (2)   alle unbekannten Pending-Orders und Positionen mit Close-Limits in Überwachung aufnehmen: über OpenOrders iterieren
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
            if (EQ(OrderTakeProfit(), 0)) /*&&*/ if (EQ(OrderStopLoss(), 0)) {
               // keine Close-Limits mehr gesetzt: aus der Überwachung entfernen
               ArraySpliceInts(knownOrders.ticket, i, 1);
               ArraySpliceInts(knownOrders.type,   i, 1);
               knownSize--;
            }
         }
         else {
            // jetzt geschlossene Position
            // prüfen, ob die Position durch ein Close-Limit oder manuell geschlossen wurde
            bool closedByLimit = false;
            string comment = StringToLower(StringTrim(OrderComment()));

            if      (StringStartsWith(comment, "so:" )) closedByLimit = true;    // Margin Stopout wie StopLoss-Limit behandeln
            else if (StringEndsWith  (comment, "[tp]")) closedByLimit = true;
            else if (StringEndsWith  (comment, "[sl]")) closedByLimit = true;
            else {                                                               // manche Broker setzen den OrderComment bei Schließung durch Limit nicht korrekt
               if (!EQ(OrderTakeProfit(), 0)) {
                  if (type == OP_BUY ) closedByLimit = closedByLimit || (OrderClosePrice() >= OrderTakeProfit());
                  else                 closedByLimit = closedByLimit || (OrderClosePrice() <= OrderTakeProfit());
               }
               if (!EQ(OrderStopLoss(), 0)) {
                  if (type == OP_BUY ) closedByLimit = closedByLimit || (OrderClosePrice() <= OrderStopLoss());
                  else                 closedByLimit = closedByLimit || (OrderClosePrice() >= OrderStopLoss());
               }
            }
            if (closedByLimit)
               ArrayPushInt(closedPositions, knownOrders.ticket[i]);             // Close-Limit wurde ausgeführt
            ArraySpliceInts(knownOrders.ticket, i, 1);                           // geschlossene Position aus der Überwachung entfernen
            ArraySpliceInts(knownOrders.type,   i, 1);
            knownSize--;
         }
      }
   }


   // (2) über alle OpenOrders iterieren und neue Pending-Orders und offene Positionen mit Close-Limits in Überwachung aufnehmen
   while (true) {
      int ordersTotal = OrdersTotal();

      for (i=0; i < ordersTotal; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {          // FALSE: während des Auslesens wurde von dritter Seite eine offene Order geschlossen oder gelöscht
            ordersTotal = -1;
            break;
         }
         for (int n=0; n < knownSize; n++) {
            if (knownOrders.ticket[n] == OrderTicket())              // Order bereits bekannt
               break;
         }
         if (n >= knownSize) {                                       // Order unbekannt: in Überwachung aufnehmen, wenn sie ein Limit hat
            if (OrderType()<=OP_SELL) /*&&*/ if (EQ(OrderTakeProfit(), 0)) /*&&*/ if (EQ(OrderStopLoss(), 0))
               continue;
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
   if (!track.positions)
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
   if (sound.alerts)
      PlaySound(sound.order.failed);
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
   if (!track.positions)
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
   if (sound.alerts)
      PlaySound(sound.position.open);
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
   if (!track.positions)
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
   if (sound.alerts)
      PlaySound(sound.position.close);
   return(!catch("onPositionClose(3)"));
}


/**
 * String-Repräsentation der Input-Parameter fürs Logging bei Aufruf durch iCustom().
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()   inputs: ",

                            "Sound.Alerts=",    BoolToStr(sound.alerts),    "; ",

                            "SMS.Alerts=",      BoolToStr(__SMS.alerts),    "; ",
                  ifString(__SMS.alerts,
          StringConcatenate("SMS.Receiver=\"",  __SMS.receiver,           "\"; "), ""),

                            "Track.Positions=", BoolToStr(track.positions), "; ")
   );
}
