/**
 * FXTradePro Martingale EA
 *
 * @see FXTradePro Strategy:     http://www.forexfactory.com/showthread.php?t=43221
 *      FXTradePro Journal:      http://www.forexfactory.com/showthread.php?t=82544
 *      FXTradePro Swing Trades: http://www.forexfactory.com/showthread.php?t=87564
 *
 *      PowerSM EA:              http://www.forexfactory.com/showthread.php?t=75394
 *      PowerSM Journal:         http://www.forexfactory.com/showthread.php?t=159789
 *
 * ---------------------------------------------------------------------------------
 *
 *  Voraussetzungen für Produktivbetrieb:
 *  -------------------------------------
 *  - korrekte Verarbeitung bereits geschlossener Hedge-Positionen implementieren (@see "multiple tickets found...")
 *  - Verfahrensweise für einzelne geschlossene Positionen entwickeln (z.B. letzte Position wurde manuell geschlossen)
 *  - Heartbeat-Order einrichten
 *  - Heartbeat-Order muß signalisieren, wenn die Konfiguration sich geändert hat => erneuter Download vom Server
 *  - ggf. muß statt nach STATUS_DISABLED nach STATUS_MONITORING gewechselt werden
 *  - ShowStatus(): erwarteten P/L der Sequenz anzeigen
 *  - Breakeven-Berechnung implementieren und anzeigen
 *  - Visualisierung der gesamten Sequenz implementieren
 *
 *  TODO:
 *  -----
 *  - CheckStatus(): Commission-Berechnung an OrderCloseBy() anpassen
 *  - Visualisierung des Entry.Limits implementieren
 *  - bei fehlender Konfiguration müssen die Daten aus der laufenden Instanz weitmöglichst ausgelesen werden
 *  - Symbolwechsel (REASON_CHARTCHANGE) und Accountwechsel (REASON_ACCOUNT) abfangen
 *  - gesamte Sequenz vorher auf [TradeserverLimits] prüfen
 *  - einzelne Tradefunktionen vorher auf [TradeserverLimits] prüfen lassen
 *  - Spreadänderungen bei Limit-Checks berücksichtigen
 *  - StopLoss -> Breakeven und TakeProfit -> Breakeven implementieren
 *  - SMS-Benachrichtigungen implementieren
 *  - Equity-Chart der laufenden Sequenz implementieren
 *  - ShowStatus() übersichtlicher gestalten (Textlabel statt Comment())
 */
#include <stdlib.mqh>
#include <win32api.mqh>


#define STATUS_INITIALIZED    1
#define STATUS_ENTRYLIMIT     2
#define STATUS_PROGRESSING    3
#define STATUS_FINISHED       4
#define STATUS_DISABLED       5



//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string _1____________________________ = "==== Entry Options ===================";
extern string Entry.Direction                = "long";
extern double Entry.Limit                    = 0;

extern string _2____________________________ = "==== TP and SL Settings ==============";
extern int    TakeProfit                     = 50;
extern int    StopLoss                       = 10;

extern string _3____________________________ = "==== Lotsizes =======================";
//extern double Lotsize.Level.1                = 0;
//extern double Lotsize.Level.2                = 0;
//extern double Lotsize.Level.3                = 0;
//extern double Lotsize.Level.4                = 0;
//extern double Lotsize.Level.5                = 0;
//extern double Lotsize.Level.6                = 0;
//extern double Lotsize.Level.7                = 0;

extern double Lotsize.Level.1                = 0.1;
extern double Lotsize.Level.2                = 0.2;
extern double Lotsize.Level.3                = 0.3;
extern double Lotsize.Level.4                = 0.4;
extern double Lotsize.Level.5                = 0.5;
extern double Lotsize.Level.6                = 0.6;
extern double Lotsize.Level.7                = 0.7;

// Externe Input-Parameter sind nicht statisch und müssen bei REASON_CHARTCHANGE manuell zwischengespeichert und restauriert werden.
string intern.Entry.Direction;
double intern.Entry.Limit;
int    intern.TakeProfit;
int    intern.StopLoss;
double intern.Lotsize.Level.1;
double intern.Lotsize.Level.2;
double intern.Lotsize.Level.3;
double intern.Lotsize.Level.4;
double intern.Lotsize.Level.5;
double intern.Lotsize.Level.6;
double intern.Lotsize.Level.7;
bool   intern = false;                             // Statusflag: TRUE => zwischengespeicherte Werte vorhanden (siehe deinit())

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int EA.uniqueId = 101;                             // eindeutige ID der Strategie (10 Bits: Bereich 0-1023)


double   Pip;
int      PipDigits;
int      PipPoints;
string   PriceFormat;

int      Entry.iDirection = OP_UNDEFINED;          // -1
double   Entry.LastBid;

int      sequenceId;
int      sequenceLength;
int      progressionLevel;

int      levels.ticket       [];                   // offenes Ticket des Levels (ein Ticket kann offen und mehrere geschlossen sein)
int      levels.type         [];
double   levels.lots         [];                   // Soll-Lotsize des Levels
double   levels.openLots     [];                   // aktuelle Order-Lotsize (inklusive Hedges)
double   levels.effectiveLots[];                   // effektive Ist-Lotsize (kann bei manueller Intervention von Soll-Lotsize abweichen)
double   levels.openPrice    [];
datetime levels.closeTime    [];                   // Unterscheidung zwischen offenen und geschlossenen Positionen

double   levels.openSwap      [], levels.closedSwap      [], levels.cumSwaps      [];
double   levels.openCommission[], levels.closedCommission[], levels.cumCommissions[];
double   levels.openProfit    [], levels.closedProfit    [], levels.cumProfits    [];

double   levels.maxProfit  [];
double   levels.maxDrawdown[];
double   levels.breakeven  [];

bool     levels.lots.changed = true;
bool     levels.swap.changed = true;

bool     firstTick = true;
int      status;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   PipDigits   = Digits & (~1);
   PipPoints   = MathPow(10, Digits-PipDigits) + 0.1;
   Pip         = 1/MathPow(10, PipDigits);
   PriceFormat = "."+ PipDigits + ifString(Digits==PipDigits, "", "'");


   // (1) ggf. Input-Parameter restaurieren
   if (UninitializeReason()!=REASON_PARAMETERS) /*&&*/ if (intern) {
      Entry.Direction = intern.Entry.Direction;
      Entry.Limit     = intern.Entry.Limit;
      TakeProfit      = intern.TakeProfit;
      StopLoss        = intern.StopLoss;
      Lotsize.Level.1 = intern.Lotsize.Level.1;
      Lotsize.Level.2 = intern.Lotsize.Level.2;
      Lotsize.Level.3 = intern.Lotsize.Level.3;
      Lotsize.Level.4 = intern.Lotsize.Level.4;
      Lotsize.Level.5 = intern.Lotsize.Level.5;
      Lotsize.Level.6 = intern.Lotsize.Level.6;
      Lotsize.Level.7 = intern.Lotsize.Level.7;
   }


   // (2) Sequenzdaten einlesen
   if (sequenceId == 0) {                                               // noch keine Sequenz definiert
      progressionLevel = 0;

      // erste aktive Sequenz finden und offene Positionen einlesen
      for (int i=OrdersTotal()-1; i >= 0; i--) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wird in einem anderen Thread eine offene Order entfernt
            continue;

         if (IsMyOrder(sequenceId)) {
            int level = OrderMagicNumber() & 0xF;                       //  4 Bits (Bits 1-4)  => progressionLevel
            if (level > progressionLevel)
               progressionLevel = level;

            if (sequenceId == 0) {
               sequenceId     = OrderMagicNumber() >> 8 & 0x3FFF;       // 14 Bits (Bits 9-22) => sequenceId
               sequenceLength = OrderMagicNumber() >> 4 & 0xF;          //  4 Bits (Bits 5-8 ) => sequenceLength

               ArrayResize(levels.ticket          , sequenceLength);
               ArrayResize(levels.type            , sequenceLength);
               ArrayResize(levels.lots            , sequenceLength);
               ArrayResize(levels.openLots        , sequenceLength);
               ArrayResize(levels.effectiveLots   , sequenceLength);
               ArrayResize(levels.openPrice       , sequenceLength);
               ArrayResize(levels.closeTime       , sequenceLength);

               ArrayResize(levels.openSwap        , sequenceLength);
               ArrayResize(levels.openCommission  , sequenceLength);
               ArrayResize(levels.openProfit      , sequenceLength);

               ArrayResize(levels.closedSwap      , sequenceLength);
               ArrayResize(levels.closedCommission, sequenceLength);
               ArrayResize(levels.closedProfit    , sequenceLength);

               ArrayResize(levels.cumSwaps        , sequenceLength);
               ArrayResize(levels.cumCommissions  , sequenceLength);
               ArrayResize(levels.cumProfits      , sequenceLength);

               ArrayResize(levels.maxProfit       , sequenceLength);
               ArrayResize(levels.maxDrawdown     , sequenceLength);
               ArrayResize(levels.breakeven       , sequenceLength);

               if (level & 1 == 1) Entry.iDirection = OrderType();
               else                Entry.iDirection = OrderType() ^ 1;  // 0=>1, 1=>0
               Entry.Direction = ifString(Entry.iDirection==OP_BUY, "long", "short");
            }
            level--;
            levels.ticket   [level] = OrderTicket();
            levels.type     [level] = OrderType();
            levels.openLots [level] = OrderLots();
            levels.openPrice[level] = OrderOpenPrice();
         }
      }

      // fehlende Positionen aus der History auslesen
      if (sequenceId != 0) /*&&*/ if (IntInArray(0, levels.ticket)) {
         int orders = OrdersHistoryTotal();
         for (i=0; i < orders; i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))           // FALSE: während des Auslesens wird der Anzeigezeitraum der History geändert
               break;

            if (IsMyOrder(sequenceId)) {
               level = OrderMagicNumber() & 0xF;                        // 4 Bits (Bits 1-4) => progressionLevel
               if (level > progressionLevel)
                  progressionLevel = level;
               level--;

               // TODO: möglich bei gehedgten Positionen
               if (levels.ticket[level] != 0)
                  return(catch("init(1)   multiple tickets found for progression level "+ (level+1) +": #"+ levels.ticket[level] +", #"+ OrderTicket(), ERR_RUNTIME_ERROR));

               levels.ticket          [level] = OrderTicket();
               levels.type            [level] = OrderType();
               levels.openLots        [level] = OrderLots();            // ist das richtig ???
               levels.effectiveLots   [level] = OrderLots();            // ist das richtig ???
               levels.openPrice       [level] = OrderOpenPrice();
               levels.closeTime       [level] = OrderCloseTime();

               levels.closedSwap      [level] = OrderSwap();
               levels.closedCommission[level] = OrderCommission();
               levels.closedProfit    [level] = OrderProfit();
            }
         }
      }

      // Tickets auf Vollständigkeit prüfen und Volumen der Hedge-Positionen ausgleichen
      double total;
      for (i=0; i < progressionLevel; i++) {
         if (levels.ticket[i] == 0)
            return(catch("init(2)   order not found for progression level "+ (i+1) +", more history data needed.", ERR_RUNTIME_ERROR));

         if (levels.closeTime[i] == 0) {
            if (levels.type[i] == OP_BUY) total += levels.openLots[i];
            else                          total -= levels.openLots[i];
            levels.effectiveLots[i] = MathAbs(total);                   // ist es richtig, effectiveLots nur anhand der offenen Positionen zu berechnen ???
         }
      }
   }


   // (3) ggf. neue Sequenz anlegen
   bool newSequence = false;
   if (sequenceId == 0) {
      newSequence = true;
      if (ValidateConfiguration() != NO_ERROR) {
         status = STATUS_DISABLED;
         ShowStatus();
         return(init_error);
      }
      sequenceId  = CreateSequenceId();
      ArrayResize(levels.ticket          , sequenceLength);
      ArrayResize(levels.type            , sequenceLength);
      ArrayResize(levels.lots            , sequenceLength);
      ArrayResize(levels.openLots        , sequenceLength);
      ArrayResize(levels.effectiveLots   , sequenceLength);
      ArrayResize(levels.openPrice       , sequenceLength);
      ArrayResize(levels.closeTime       , sequenceLength);

      ArrayResize(levels.openSwap        , sequenceLength);
      ArrayResize(levels.openCommission  , sequenceLength);
      ArrayResize(levels.openProfit      , sequenceLength);

      ArrayResize(levels.closedSwap      , sequenceLength);
      ArrayResize(levels.closedCommission, sequenceLength);
      ArrayResize(levels.closedProfit    , sequenceLength);

      ArrayResize(levels.cumSwaps        , sequenceLength);
      ArrayResize(levels.cumCommissions  , sequenceLength);
      ArrayResize(levels.cumProfits      , sequenceLength);

      ArrayResize(levels.maxProfit       , sequenceLength);
      ArrayResize(levels.maxDrawdown     , sequenceLength);
      ArrayResize(levels.breakeven       , sequenceLength);
   }


   // (4) neue und geänderte Konfigurationen speichern, alte Konfigurationen restaurieren
   if (newSequence) {
      if (NE(Entry.Limit, 0))                                           // ohne Entry.Limit wird die Konfiguration erst nach der Sicherheitsabfrage
         SaveConfiguration();                                           // in StartSequence() gespeichert
   }
   else if (UninitializeReason() == REASON_PARAMETERS) {
      if (ValidateConfiguration() == NO_ERROR)
         SaveConfiguration();
   }
   else if (UninitializeReason() != REASON_CHARTCHANGE) {
      if (RestoreConfiguration() == NO_ERROR)
         ValidateConfiguration();
   }


   // (5) aktuellen Status bestimmen und anzeigen
   if (init_error != NO_ERROR)            status = STATUS_DISABLED;
   else if (status == 0) {
      if (progressionLevel == 0) {
         if (EQ(Entry.Limit, 0))          status = STATUS_INITIALIZED;
         else                             status = STATUS_ENTRYLIMIT;
      }
      else {
         int last = progressionLevel-1;
         if (levels.closeTime[last] == 0) status = STATUS_PROGRESSING;
         else                             status = STATUS_FINISHED;
      }
   }
   CheckStatus();
   ShowStatus();


   if (init_error == NO_ERROR) {
      // (6) bei Start ggf. EA's aktivieren
      int reasons1[] = { REASON_REMOVE, REASON_CHARTCLOSE, REASON_APPEXIT };
      if (!IsExpertEnabled()) /*&&*/ if (IntInArray(UninitializeReason(), reasons1))
         ToggleEAs(true);


      // (7) nach Start oder Reload nicht auf den ersten Tick warten
      int reasons2[] = { REASON_REMOVE, REASON_CHARTCLOSE, REASON_APPEXIT, REASON_PARAMETERS, REASON_RECOMPILE };
      if (IntInArray(UninitializeReason(), reasons2))
         SendTick(false);
   }


   int error = GetLastError();
   if (error      != NO_ERROR) catch("init(3)", error);
   if (init_error != NO_ERROR) status = STATUS_DISABLED;
   return(init_error);
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   // externe Input-Parameter sind nicht statisch und müssen im nächsten init() restauriert werden
   intern.Entry.Direction = Entry.Direction;
   intern.Entry.Limit     = Entry.Limit;
   intern.TakeProfit      = TakeProfit;
   intern.StopLoss        = StopLoss;
   intern.Lotsize.Level.1 = Lotsize.Level.1;
   intern.Lotsize.Level.2 = Lotsize.Level.2;
   intern.Lotsize.Level.3 = Lotsize.Level.3;
   intern.Lotsize.Level.4 = Lotsize.Level.4;
   intern.Lotsize.Level.5 = Lotsize.Level.5;
   intern.Lotsize.Level.6 = Lotsize.Level.6;
   intern.Lotsize.Level.7 = Lotsize.Level.7;
   intern                 = true;               // Statusflag setzen

   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   init = false;
   if (init_error != NO_ERROR) return(init_error);
   if (last_error != NO_ERROR) return(last_error);

   // temporäre Laufzeitanalyse
   if (Bid < 0.00000001) catch("start()   Bid = "+ NumberToStr(Bid, PriceFormat), ERR_RUNTIME_ERROR);
   if (Ask < 0.00000001) catch("start()   Ask = "+ NumberToStr(Ask, PriceFormat), ERR_RUNTIME_ERROR);
   if (last_error != NO_ERROR)
      return(last_error);
   // --------------------------------------------


   if (status==STATUS_FINISHED || status==STATUS_DISABLED)
      return(NO_ERROR);


   if (CheckStatus()) {
      if (progressionLevel == 0) {
         if (!IsEntryLimitReached())            status = STATUS_ENTRYLIMIT;
         else                                   StartSequence();                 // kein Limit definiert oder Limit erreicht
      }
      else if (IsStopLossReached()) {
         if (progressionLevel < sequenceLength) IncreaseProgression();
         else                                   FinishSequence();
      }
      else if (IsProfitTargetReached())         FinishSequence();
   }
   ShowStatus();

   firstTick = false;
   return(catch("start()"));
}


/**
 * Ob die aktuell selektierte Order zu dieser Strategie gehört. Wird eine Sequenz-ID angegeben, wird zusätzlich überprüft,
 * ob die Order zur angegebenen Sequenz gehört.
 *
 * @param  int sequenceId - ID einer aktiven Sequenz (default: NULL)
 *
 * @return bool
 */
bool IsMyOrder(int sequenceId = NULL) {
   if (OrderSymbol()==Symbol()) {
      if (OrderType()==OP_BUY || OrderType()==OP_SELL) {
         if (OrderMagicNumber() >> 22 == EA.uniqueId) {
            if (sequenceId == NULL)
               return(true);
            return(sequenceId == OrderMagicNumber() >> 8 & 0x3FFF);       // 14 Bits (Bits 9-22) => sequenceId
         }
      }
   }
   return(false);
}


/**
 * Generiert eine neue Sequenz-ID.
 *
 * @return int - Sequenze-ID im Bereich 1000-16383 (14 bit)
 */
int CreateSequenceId() {
   MathSrand(GetTickCount());

   int id;
   while (id < 2000) {                    // Das abschließende Shiften halbiert den Wert und wir wollen mindestens eine 4-stellige ID haben.
      id = MathRand();
   }
   return(id >> 1);
}


/**
 * Generiert aus den internen Daten einen Wert für OrderMagicNumber().
 *
 * @return int - MagicNumber oder -1, falls ein Fehler auftrat
 */
int CreateMagicNumber() {
   if (sequenceId < 1000) {
      catch("CreateMagicNumber()   illegal sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR);
      return(-1);
   }

   int ea       = EA.uniqueId & 0x3FF << 22;          // 10 bit (Bits größer 10 löschen und auf 32 Bit erweitern) | in MagicNumber: Bits 23-32
   int sequence = sequenceId & 0x3FFF << 8;           // 14 bit (Bits größer 14 löschen und auf 22 Bit erweitern  | in MagicNumber: Bits  9-22
   int length   = sequenceLength & 0xF << 4;          //  4 bit (Bits größer 4 löschen und auf 8 bit erweitern)   | in MagicNumber: Bits  5-8
   int level    = progressionLevel & 0xF;             //  4 bit (Bits größer 4 löschen)                           | in MagicNumber: Bits  1-4

   return(ea + sequence + length + level);
}


/**
 * Ob das konfigurierte EntryLimit erreicht oder überschritten wurde.  Wurde kein Limit angegeben, gibt die Funktion ebenfalls TRUE zurück.
 *
 * @return bool
 */
bool IsEntryLimitReached() {
   if (EQ(Entry.Limit, 0))                                           // kein Limit definiert
      return(true);

   // Das Limit ist erreicht, wenn der Bid-Preis es seit dem letzten Tick berührt oder gekreuzt hat.
   if (EQ(Bid, Entry.Limit) || EQ(Entry.LastBid, Entry.Limit)) {     // Bid liegt oder lag beim letzten Tick exakt auf dem Limit
      log("IsEntryLimitReached()   Bid="+ NumberToStr(Bid, PriceFormat) +" liegt genau auf dem Limit="+ NumberToStr(Entry.Limit, PriceFormat));
      Entry.LastBid = Entry.Limit;                                   // Tritt während der weiteren Verarbeitung des Ticks ein behandelbarer Fehler auf, wird durch
      return(true);                                                  // Entry.LastPrice = Entry.Limit das Limit, einmal getriggert, nachfolgend immer wieder getriggert.
   }

   static bool lastBid.init = false;

   if (EQ(Entry.LastBid, 0)) {                                       // Entry.LastBid muß initialisiert sein => ersten Aufruf überspringen und Status merken,
      lastBid.init = true;                                           // um firstTick bei erstem tatsächlichen Test gegen Entry.LastBid auf TRUE zurückzusetzen
   }
   else {
      if (LT(Entry.LastBid, Entry.Limit)) {
         if (GT(Bid, Entry.Limit)) {                                 // Bid hat Limit von unten nach oben gekreuzt
            log("IsEntryLimitReached()   Tick hat Limit="+ NumberToStr(Entry.Limit, PriceFormat) +" von unten (lastBid="+ NumberToStr(Entry.LastBid, PriceFormat) +") nach oben (Bid="+ NumberToStr(Bid, PriceFormat) +") gekreuzt");
            Entry.LastBid = Entry.Limit;
            return(true);
         }
      }
      else if (LT(Bid, Entry.Limit)) {                               // Bid hat Limit von oben nach unten gekreuzt
         log("IsEntryLimitReached()   Tick hat Limit="+ NumberToStr(Entry.Limit, PriceFormat) +" von oben (lastBid="+ NumberToStr(Entry.LastBid, PriceFormat) +") nach unten (Bid="+ NumberToStr(Bid, PriceFormat) +") gekreuzt");
         Entry.LastBid = Entry.Limit;
         return(true);
      }
      if (lastBid.init) {
         lastBid.init = false;
         firstTick    = true;                                        // firstTick nach erstem tatsächlichen Test gegen Entry.LastBid auf TRUE zurückzusetzen
      }
   }
   Entry.LastBid = Bid;

   return(false);
}


/**
 * Ob der konfigurierte StopLoss erreicht oder überschritten wurde.
 *
 * @return bool
 */
bool IsStopLossReached() {
   int    last           = progressionLevel-1;
   int    last.type      = levels.type     [last];
   double last.openPrice = levels.openPrice[last];

   double last.price, last.loss;

   static string last.directions[] = {"long", "short"};
   static string last.priceNames[] = {"Bid" , "Ask"  };

   if (last.type == OP_BUY) {
      last.price = Bid;
      last.loss  = last.openPrice-Bid;
   }
   else {
      last.price = Ask;
      last.loss  = Ask-last.openPrice;
   }

   if (GT(last.loss, StopLoss*Pip)) {
      log("IsStopLossReached()   Stoploss für "+ last.directions[last.type] +" position erreicht: "+ DoubleToStr(last.loss/Pip, Digits-PipDigits) +" pip (openPrice="+ NumberToStr(last.openPrice, PriceFormat) +", "+ last.priceNames[last.type] +"="+ NumberToStr(last.price, PriceFormat) +")");
      return(true);
   }
   return(false);
}


/**
 * Ob der konfigurierte TakeProfit-Level erreicht oder überschritten wurde.
 *
 * @return bool
 */
bool IsProfitTargetReached() {
   int    last           = progressionLevel-1;
   int    last.type      = levels.type     [last];
   double last.openPrice = levels.openPrice[last];

   double last.price, last.profit;

   static string last.directions[] = { "long", "short" };
   static string last.priceNames[] = { "Bid" , "Ask"   };

   if (last.type == OP_BUY) {
      last.price  = Bid;
      last.profit = Bid-last.openPrice;
   }
   else {
      last.price  = Ask;
      last.profit = last.openPrice-Ask;
   }

   if (GE(last.profit, TakeProfit*Pip)) {
      log("IsProfitTargetReached()   Profit target für "+ last.directions[last.type] +" position erreicht: "+ DoubleToStr(last.profit/Pip, Digits-PipDigits) +" pip (openPrice="+ NumberToStr(last.openPrice, PriceFormat) +", "+ last.priceNames[last.type] +"="+ NumberToStr(last.price, PriceFormat) +")");
      return(true);
   }
   return(false);
}


/**
 * Beginnt eine neue Trade-Sequenz (Progression-Level 1).
 *
 * @return int - Fehlerstatus
 */
int StartSequence() {
   if (firstTick) {                                                        // Sicherheitsabfrage, wenn der erste Tick sofort einen Trade triggert
      PlaySound("notify.wav");
      int button = MessageBox(ifString(!IsDemo(), "Live Account\n\n", "") +"Do you want to start a new trade sequence now?", __SCRIPT__ +" - StartSequence", MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) {
         status = STATUS_DISABLED;
         return(catch("StartSequence(1)"));
      }
      SaveConfiguration();                                                 // bei firstTick=TRUE Konfiguration nach Bestätigung speichern
   }

   progressionLevel = 1;

   int ticket = OpenPosition(Entry.iDirection, levels.lots[0]);            // Position in Entry.Direction öffnen
   if (ticket == -1) {
      status = STATUS_DISABLED;
      progressionLevel--;
      return(catch("StartSequence(2)"));
   }

   // Sequenzdaten aktualisieren
   if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      int error = GetLastError();
      if (error == NO_ERROR)
         error = ERR_INVALID_TICKET;
      status = STATUS_DISABLED;
      progressionLevel--;
      return(catch("StartSequence(3)", error));
   }

   levels.ticket       [0] = OrderTicket();
   levels.type         [0] = OrderType();
   levels.openLots     [0] = OrderLots();
   levels.effectiveLots[0] = OrderLots();                                  // Level 1: openLots = effectiveLots
   levels.openPrice    [0] = OrderOpenPrice();

   // Status aktualisieren
   status = STATUS_PROGRESSING;
   CheckStatus();

   return(catch("StartSequence(4)"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int IncreaseProgression() {
   if (firstTick) {                                                        // Sicherheitsabfrage, wenn der erste Tick sofort einen Trade triggert
      PlaySound("notify.wav");
      int button = MessageBox(ifString(!IsDemo(), "Live Account\n\n", "") +"Do you want to increase the progression level now?", __SCRIPT__ +" - IncreaseProgression", MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) {
         status = STATUS_DISABLED;
         return(catch("IncreaseProgression(1)"));
      }
   }

   int    last      = progressionLevel-1;
   double last.lots = levels.effectiveLots[last];
   int    new.type  = levels.type         [last] ^ 1;                      // 0=>1, 1=>0

   progressionLevel++;

   int ticket = OpenPosition(new.type, last.lots + levels.lots[last+1]);   // alte Position hedgen und nächste öffnen
   if (ticket == -1) {
      status = STATUS_DISABLED;
      progressionLevel--;
      return(catch("IncreaseProgression(2)"));
   }

   // Sequenzdaten aktualisieren
   if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      int error = GetLastError();
      if (error == NO_ERROR)
         error = ERR_INVALID_TICKET;
      status = STATUS_DISABLED;
      progressionLevel--;
      return(catch("IncreaseProgression(3)", error));
   }

   int this = progressionLevel-1;
   levels.ticket       [this] = OrderTicket();
   levels.type         [this] = OrderType();
   levels.openLots     [this] = OrderLots();
   levels.effectiveLots[this] = levels.lots[this];
   levels.openPrice    [this] = OrderOpenPrice();

   // Status aktualisieren
   CheckStatus();

   return(catch("IncreaseProgression(4)"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int FinishSequence() {
   if (firstTick) {                                                        // Sicherheitsabfrage, wenn der erste Tick sofort einen Trade triggert
      PlaySound("notify.wav");
      int button = MessageBox(ifString(!IsDemo(), "Live Account\n\n", "") +"Do you want to finish the sequence now?", __SCRIPT__ +" - FinishSequence", MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) {
         status = STATUS_DISABLED;
         return(catch("FinishSequence(1)"));
      }
   }

   // zu schließende Tickets ermitteln
   int tickets[]; ArrayResize(tickets, 0);

   for (int i=0; i < sequenceLength; i++) {
      if (levels.ticket[i] > 0) /*&&*/ if (levels.closeTime[i] == 0)
         ArrayPushInt(tickets, levels.ticket[i]);
   }

   // Tickets schließen
   if (!OrderCloseMultiple(tickets, 0.1, Orange)) {
      status = STATUS_DISABLED;
      return(processLibError(stdlib_PeekLastError()));
   }

   // Status aktualisieren
   status = STATUS_FINISHED;
   CheckStatus();

   return(catch("FinishSequence(2)"));
}


/**
 * @param  int    type    - Ordertyp: OP_BUY | OP_SELL
 * @param  double lotsize - Lotsize der Order (variiert je nach Progression-Level und Hedging-Fähigkeit des Accounts)
 *
 * @return int - Ticket der neuen Position oder -1, falls ein Fehler auftrat
 */
int OpenPosition(int type, double lotsize) {
   if (type!=OP_BUY && type!=OP_SELL) {
      catch("OpenPosition(1)   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   if (LE(lotsize, 0)) {
      catch("OpenPosition(2)   illegal parameter lotsize = "+ NumberToStr(lotsize, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   int    magicNumber = CreateMagicNumber();
   string comment     = "FTP."+ sequenceId +"."+ progressionLevel;
   double slippage    = 0.1;
   color  markerColor = ifInt(type==OP_BUY, Blue, Red);

   int ticket = OrderSendEx(Symbol(), type, lotsize, NULL, slippage, NULL, NULL, comment, magicNumber, NULL, markerColor);
   if (ticket == -1)
      processLibError(stdlib_PeekLastError());

   if (catch("OpenPosition(3)") != NO_ERROR)
      return(-1);
   return(ticket);
}


/**
 * Prüft/aktualisiert den Sequenzstatus und berechnet die aktuellen Kennziffern (P/L, Breakeven etc.)
 *
 * @return bool - Erfolgsstatus
 */
bool CheckStatus() {
   if (progressionLevel == 0)                               // vorerst nichts zu tun
      return(true);

   // (1) offene Positionen auf Änderungen prüfen: OrderCloseTime(), OrderLots(), OrderSwap()
   for (int i=0; i < sequenceLength; i++) {
      if (levels.ticket[i] == 0)
         break;
      if (levels.closeTime[i] == 0) {                       // Ticket prüfen, wenn es beim letzten Aufruf offen war
         if (!OrderSelect(levels.ticket[i], SELECT_BY_TICKET)) {
            int error = GetLastError();
            if (error == NO_ERROR)
               error = ERR_INVALID_TICKET;
            status = STATUS_DISABLED;
            return(catch("CheckStatus(1)", error)==NO_ERROR);
         }
         if (OrderCloseTime() != 0) {                       // Ticket ist geschlossen           => Sequenz neu einlesen
            error = ReadSequence(); break;
         }
         if (NE(OrderLots(), levels.openLots[i])) {         // Ticket ist teilweise geschlossen => Sequenz neu einlesen
            error = ReadSequence(); break;
         }
         if (NE(OrderSwap(), levels.openSwap[i])) {         // Swap hat sich geändert           => aktualisieren
            levels.openSwap[i] = OrderSwap();
            levels.swap.changed = true;
         }
      }
   }
   if (error != NO_ERROR) {
      status = STATUS_DISABLED;
      return(false);
   }


   // (2) Sequenzdaten sind jetzt aktuell


   // (3) Profit/Loss neu berechnen
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE );
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   error = GetLastError();                                    // ERR_MARKETINFO_UPDATE ???
   if (error != NO_ERROR)                      { status = STATUS_DISABLED; return(catch("CheckStatus(2)", error)==NO_ERROR);                                                                   }
   if (tickSize  < 0.000009 || tickSize  >  1) { status = STATUS_DISABLED; return(catch("CheckStatus(3)   MODE_TICKSIZE = "+ NumberToStr(tickSize,   ".+"), ERR_MARKETINFO_UPDATE)==NO_ERROR); }
   if (tickValue < 0.5      || tickValue > 20) { status = STATUS_DISABLED; return(catch("CheckStatus(4)   MODE_TICKVALUE = "+ NumberToStr(tickValue, ".+"), ERR_MARKETINFO_UPDATE)==NO_ERROR); }

   double profits, swaps, commissions, difference, tmp.openLots[];
   ArrayCopy(tmp.openLots, levels.openLots);

   for (i=0; i < sequenceLength; i++) {
      if (levels.ticket[i] == 0)
         break;

      if (levels.closeTime[i] == 0) {                             // offene Position
         if (!OrderSelect(levels.ticket[i], SELECT_BY_TICKET)) {
            error = GetLastError();
            if (error == NO_ERROR)
               error = ERR_INVALID_TICKET;
            status = STATUS_DISABLED;
            return(catch("CheckStatus(5)", error)==NO_ERROR);
         }
         if (OrderCloseTime() != 0) {
            status = STATUS_DISABLED;
            return(catch("CheckStatus(6)   illegal sequence state, ticket #"+ levels.ticket[i] +"(level "+ (i+1) +") is already closed", ERR_RUNTIME_ERROR)==NO_ERROR);
         }

         levels.openProfit[i] = 0;

         if (GT(tmp.openLots[i], 0)) {
            // P/L offener Hedges verrechnen
            for (int n=i+1; n < sequenceLength; n++) {
               if (levels.ticket[n] == 0)
                  break;
               if (levels.closeTime[n]==0) /*&&*/ if (levels.type[i]!=levels.type[n]) /*&&*/ if (GT(tmp.openLots[n], 0)) { // offener und verrechenbarer Hedge
                  difference = ifDouble(levels.type[i]==OP_BUY, levels.openPrice[n]-levels.openPrice[i], levels.openPrice[i]-levels.openPrice[n]);

                  if (LE(tmp.openLots[i], tmp.openLots[n])) {
                     levels.openProfit[i] += difference / tickSize * tickValue * tmp.openLots[i];
                     tmp.openLots     [n] -= tmp.openLots[i];
                     tmp.openLots     [i]  = 0;
                     break;
                  }
                  else  /*(GT(tmp.openLots[i], tmp.openLots[n]))*/ {
                     levels.openProfit[i] += difference / tickSize * tickValue * tmp.openLots[n];
                     tmp.openLots     [i] -= tmp.openLots[n];
                     tmp.openLots     [n]  = 0;
                  }
               }
            }

            // P/L von Restpositionen anteilmäßig anhand des regulären OrderProfit() ermitteln
            if (GT(tmp.openLots[i], 0))
               levels.openProfit[i] += OrderProfit() / levels.openLots[i] * tmp.openLots[i];
         }

         // Swap und Commission normal übernehmen
         levels.openSwap      [i] = OrderSwap();
         levels.openCommission[i] = OrderCommission();         // TODO: korrekte Commission-Berechnung der Hedges implementieren
      }
      swaps       += levels.openSwap      [i];
      commissions += levels.openCommission[i];
      profits     += levels.openProfit    [i];
   }

   int last = progressionLevel-1;
   levels.cumSwaps      [last] = swaps;
   levels.cumCommissions[last] = commissions;
   levels.cumProfits    [last] = profits;

   if (catch("CheckStatus(7)") != NO_ERROR) {
      status = STATUS_DISABLED;
      return(false);
   }
   return(true);
}


/**
 * Liest die aktuelle Sequenz komplett neu ein.
 *
 * @return int - Fehlerstatus
 */
int ReadSequence() {
   if (sequenceId       == 0)                      return(catch("ReadSequence(1)   illegal sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR));
   if (progressionLevel == 0)                      return(catch("ReadSequence(2)   illegal progressionLevel = "+ progressionLevel, ERR_RUNTIME_ERROR));
   if (ArraySize(levels.ticket) != sequenceLength) return(catch("ReadSequence(3)   illegal sequence state, sequenceLength ("+ sequenceLength +") != sizeOf(levels.ticket) = "+ ArraySize(levels.ticket), ERR_RUNTIME_ERROR));


   // (1) alle Arrays außer levels.lots[] zurücksetzen (levels.lots[] wird in ValidateConfiguration() belegt)
   ArrayInitialize(levels.ticket          , 0.1);                    // Präzisionsfehler beim Casten von Doubles vermeiden: (int) ArrayInitialize()
   ArrayInitialize(levels.type,    OP_UNDEFINED);
   ArrayInitialize(levels.openLots        , 0  );
   ArrayInitialize(levels.effectiveLots   , 0  );
   ArrayInitialize(levels.openPrice       , 0  );
   ArrayInitialize(levels.closeTime       , 0.1);

   ArrayInitialize(levels.openSwap        , 0  );
   ArrayInitialize(levels.openCommission  , 0  );
   ArrayInitialize(levels.openProfit      , 0  );

   ArrayInitialize(levels.closedSwap      , 0  );
   ArrayInitialize(levels.closedCommission, 0  );
   ArrayInitialize(levels.closedProfit    , 0  );

   ArrayInitialize(levels.cumSwaps        , 0  );
   ArrayInitialize(levels.cumCommissions  , 0  );
   ArrayInitialize(levels.cumProfits      , 0  );

   ArrayInitialize(levels.maxProfit       , 0  );
   ArrayInitialize(levels.maxDrawdown     , 0  );
   ArrayInitialize(levels.breakeven       , 0  );


   // (2) offene Positionen einlesen
   for (int i=OrdersTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wird in einem anderen Thread eine offene Order entfernt
         continue;

      if (IsMyOrder(sequenceId)) {
         int level = OrderMagicNumber() & 0xF;                       //  4 Bits (Bits 1-4)  => progressionLevel
         level--;
         levels.ticket        [level] = OrderTicket();
         levels.type          [level] = OrderType();
         levels.openLots      [level] = OrderLots();
         levels.openPrice     [level] = OrderOpenPrice();

         levels.openSwap      [level] = OrderSwap();
         levels.openCommission[level] = OrderCommission();
         levels.openProfit    [level] = OrderProfit();
      }
   }


   // (3) geschlossene Positionen einlesen
   int size = OrdersHistoryTotal();
   int      hist.tickets    []; ArrayResize(hist.tickets    , size);
   int      hist.types      []; ArrayResize(hist.types      , size);
   double   hist.lots       []; ArrayResize(hist.lots       , size);
   double   hist.openPrices []; ArrayResize(hist.openPrices , size);
   datetime hist.openTimes  []; ArrayResize(hist.openTimes  , size);
   datetime hist.closeTimes []; ArrayResize(hist.closeTimes , size);
   double   hist.swaps      []; ArrayResize(hist.swaps      , size);
   double   hist.commissions[]; ArrayResize(hist.commissions, size);
   double   hist.profits    []; ArrayResize(hist.profits    , size);
   string   hist.comments   []; ArrayResize(hist.comments   , size);
   int n;

   for (i=0, n=0; i < size; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))              // FALSE: während des Auslesens wird der Anzeigezeitraum der History geändert
         break;

      // (3.1) Daten der geschlossenen Tickets der Sequenz auslesen
      if (IsMyOrder(sequenceId)) {
         int type = OrderType();
         if (type!=OP_BUY) /*&&*/ if (type!=OP_SELL)                 // Nicht-Trades überspringen
            continue;
         hist.tickets    [n] = OrderTicket();
         hist.types      [n] = type;
         hist.lots       [n] = OrderLots();
         hist.openPrices [n] = OrderOpenPrice();
         hist.openTimes  [n] = OrderOpenTime();
         hist.closeTimes [n] = OrderCloseTime();
         hist.swaps      [n] = OrderSwap();
         hist.commissions[n] = OrderCommission();
         hist.profits    [n] = OrderProfit();
         hist.comments   [n] = OrderComment();
         n++;
      }
   }
   if (n < size) {
      ArrayResize(hist.tickets    , n);
      ArrayResize(hist.types      , n);
      ArrayResize(hist.lots       , n);
      ArrayResize(hist.openPrices , n);
      ArrayResize(hist.openTimes  , n);
      ArrayResize(hist.closeTimes , n);
      ArrayResize(hist.swaps      , n);
      ArrayResize(hist.commissions, n);
      ArrayResize(hist.profits    , n);
      ArrayResize(hist.comments   , n);
      size = n;
   }

   // (3.2) Hedges analysieren: relevante Daten der ersten Position zuordnen, hedgende Position verwerfen
   for (i=0; i < size; i++) {
      if (hist.tickets[i] == 0)                                      // markierte Tickets sind verworfene Hedges
         continue;
      if (EQ(hist.lots[i], 0)) {                                     // hist.lots = 0.00: Hedge-Position
         if (!StringIStartsWith(hist.comments[i], "close hedge by #"))
            return(catch("ReadSequence(4)  ticket #"+ hist.tickets[i] +" - unknown comment for assumed hedging position: \""+ hist.comments[i] +"\"", ERR_RUNTIME_ERROR));

         // Gegenstück suchen
         int ticket = StrToInteger(StringSubstr(hist.comments[i], 16));
         for (n=0; n < size; n++)
            if (hist.tickets[n] == ticket)
               break;
         if (n == size) return(catch("ReadSequence(5)  cannot find counterpart for hedging position #"+ hist.tickets[i] +": \""+ hist.comments[i] +"\"", ERR_RUNTIME_ERROR));
         if (i == n   ) return(catch("ReadSequence(6)  both hedged and hedging position have the same ticket #"+ hist.tickets[i] +": \""+ hist.comments[i] +"\"", ERR_RUNTIME_ERROR));

         int first, second;
         if      (hist.openTimes[i] < hist.openTimes[n])                                     { first = i; second = n; }
         else if (hist.openTimes[i]==hist.openTimes[n] && hist.tickets[i] < hist.tickets[n]) { first = i; second = n; }
         else                                                                                { first = n; second = i; }

         // Ticketdaten korrigieren
         hist.lots[i] = hist.lots[n];                                // hist.lots[i] == 0.0 korrigieren
         if (i == first) {
            hist.swaps      [first ] = hist.swaps      [second];     // alle Transaktionsdaten im ersten Ticket speichern
            hist.commissions[first ] = hist.commissions[second];
            hist.profits    [first ] = hist.profits    [second];
         }
         hist.tickets[second] = 0;                                   // zweites Ticket als ungültig markieren
      }
   }

   // (3.3) levels.* mit den verbleibenden Ticketdaten aktualisieren
   for (i=0; i < size; i++) {
      if (hist.tickets[i] == 0)                                      // markierte Tickets sind verworfene Hedges
         continue;

      level = OrderMagicNumber() & 0xF;                              // 4 Bits (Bits 1-4) => progressionLevel
      level--;

      if (levels.ticket[level] == 0) {                               // unbelegter Level
         levels.ticket   [level] = hist.tickets   [i];
         levels.type     [level] = hist.types     [i];
         levels.openLots [level] = hist.lots      [i];
         levels.openPrice[level] = hist.openPrices[i];
         levels.closeTime[level] = hist.closeTimes[i];
      }
      else if (levels.type[level] != hist.types[i])
         return(catch("ReadSequence(7)  illegal sequence state: operation type "+ OperationTypeDescription(levels.type[level]) +" in level "+ (level+1) +" doesn't match "+ OperationTypeDescription(hist.types[i]) +" of closed position #"+ hist.tickets[i], ERR_RUNTIME_ERROR));

      levels.closedSwap      [level] += hist.swaps      [i];
      levels.closedCommission[level] += hist.commissions[i];
      levels.closedProfit    [level] += hist.profits    [i];
   }

   return(catch("ReadSequence(8)"));
}


/**
 * Zeigt den aktuellen Status der Sequenz an.
 *
 * @return int - Fehlerstatus
 */
int ShowStatus() {
   if (last_error != NO_ERROR)
      status = STATUS_DISABLED;


   // Comment -> Zeile 3: Lotsizes der gesamten Sequenz
   static string str.levels.lots = "";
   if (levels.lots.changed) {
      str.levels.lots = JoinDoubles(levels.lots, ",  ");
      levels.lots.changed = false;
   }


   string msg="", strProfitLoss="0";
   double profitLoss, profitLossPips;

   switch (status) {
      case STATUS_INITIALIZED: msg = StringConcatenate(":  sequence ", sequenceId, " initialized");                                                                                                  break;
      case STATUS_ENTRYLIMIT : msg = StringConcatenate(":  sequence ", sequenceId, " waiting for Stop ", OperationTypeDescription(Entry.iDirection), " at ", NumberToStr(Entry.Limit, PriceFormat)); break;
      case STATUS_PROGRESSING: msg = StringConcatenate(":  sequence ", sequenceId, " progressing...");                                                                                               break;
      case STATUS_FINISHED:    msg = StringConcatenate(":  sequence ", sequenceId, " finished");                                                                                                     break;
      case STATUS_DISABLED:    msg = StringConcatenate(":  sequence ", sequenceId, " disabled");
                               int error = ifInt(init, init_error, last_error);
                               if (error != NO_ERROR)
                                  msg = StringConcatenate(msg, "  [", ErrorDescription(error), "]");
                               break;
      default:
         return(catch("ShowStatus(1)   illegal sequence status = "+ status, ERR_RUNTIME_ERROR));
   }

   msg = StringConcatenate(__SCRIPT__, msg,                                              NL,
                                                                                         NL,
                          "Progression Level:   ", progressionLevel, " / ", sequenceLength);

   int last = 0;
   if (progressionLevel > 0) {
      last = progressionLevel-1;
      msg            = StringConcatenate(msg, "  =  ", ifString(levels.type[last]==OP_BUY, "+", "-"), NumberToStr(levels.effectiveLots[last], ".+"), " lot");
      profitLoss     = levels.cumProfits[last] + levels.cumCommissions[last] + levels.cumSwaps[last];
      profitLossPips = ifDouble(levels.type[progressionLevel-1]==OP_BUY, Bid-levels.openPrice[last], levels.openPrice[last]-Ask) / Pip;
   }

   msg = StringConcatenate(msg,                                                                                                              NL,
                          "Lot sizes:               ", str.levels.lots, "  (+0.00/-0.00)",                                                   NL,
                          "TakeProfit:            ",   TakeProfit,                         " pip = +", DoubleToStr(0, 2),                    NL,
                          "StopLoss:              ",   StopLoss,                           " pip = ", DoubleToStr(-0.01, 2),                 NL,
                          "Breakeven:           ",     DoubleToStr(0, Digits-PipDigits), " pip = ", NumberToStr(0, PriceFormat),             NL,
                          "Profit/Loss:           ",   DoubleToStr(profitLossPips, Digits-PipDigits), " pip = ", DoubleToStr(profitLoss, 2), NL);

   // 2 Zeilen Abstand nach oben für Instrumentanzeige
   Comment(StringConcatenate(NL, NL, msg));

   return(catch("ShowStatus(2)"));
   StatusToStr(NULL);
}


/**
 * Gibt die lesbare Konstante eines Status-Codes zurück.
 *
 * @param  int status - Status-Code
 *
 * @return string
 */
string StatusToStr(int status) {
   switch (status) {
      case STATUS_INITIALIZED: return("STATUS_INITIALIZED");
      case STATUS_ENTRYLIMIT : return("STATUS_ENTRYLIMIT" );
      case STATUS_PROGRESSING: return("STATUS_PROGRESSING");
      case STATUS_FINISHED   : return("STATUS_FINISHED"   );
      case STATUS_DISABLED   : return("STATUS_DISABLED"   );
   }
   catch("StatusToStr()  invalid parameter status = "+ status, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Validiert die aktuelle Konfiguration.
 *
 * @return int - Fehlerstatus
 */
int ValidateConfiguration() {
   debug("ValidateConfiguration()   validating configuration...");

   // Entry.Direction
   string direction = StringToUpper(StringTrim(Entry.Direction));
   if (StringLen(direction) == 0)
      return(catch("ValidateConfiguration(1)  Invalid input parameter Entry.Direction = \""+ Entry.Direction +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   switch (StringGetChar(direction, 0)) {
      case 'B':
      case 'L': Entry.Direction = "long";  Entry.iDirection = OP_BUY;  break;
      case 'S': Entry.Direction = "short"; Entry.iDirection = OP_SELL; break;
      default:
         return(catch("ValidateConfiguration(2)  Invalid input parameter Entry.Direction = \""+ Entry.Direction +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   }

   // Entry.Limit
   if (LT(Entry.Limit, 0))
      return(catch("ValidateConfiguration(3)  Invalid input parameter Entry.Limit = "+ NumberToStr(Entry.Limit, ".+"), ERR_INVALID_INPUT_PARAMVALUE));

   // TakeProfit
   if (TakeProfit < 1)
      return(catch("ValidateConfiguration(4)  Invalid input parameter TakeProfit = "+ TakeProfit, ERR_INVALID_INPUT_PARAMVALUE));

   // StopLoss
   if (StopLoss < 1)
      return(catch("ValidateConfiguration(5)  Invalid input parameter StopLoss = "+ StopLoss, ERR_INVALID_INPUT_PARAMVALUE));

   // Lotsizes
   ArrayResize(levels.lots, 0);
   levels.lots.changed = true;

   if (LE(Lotsize.Level.1, 0)) return(catch("ValidateConfiguration(6)  Invalid input parameter Lotsize.Level.1 = "+ NumberToStr(Lotsize.Level.1, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
   ArrayPushDouble(levels.lots, Lotsize.Level.1);
   if      (EQ(Lotsize.Level.2, 0))               sequenceLength = 1;
   else if (LT(Lotsize.Level.2, Lotsize.Level.1)) return(catch("ValidateConfiguration(7)  Invalid input parameter Lotsize.Level.2 = "+ NumberToStr(Lotsize.Level.2, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
   else {
      ArrayPushDouble(levels.lots, Lotsize.Level.2);
      if      (EQ(Lotsize.Level.3, 0))               sequenceLength = 2;
      else if (LT(Lotsize.Level.3, Lotsize.Level.2)) return(catch("ValidateConfiguration(8)  Invalid input parameter Lotsize.Level.3 = "+ NumberToStr(Lotsize.Level.3, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
      else {
         ArrayPushDouble(levels.lots, Lotsize.Level.3);
         if      (EQ(Lotsize.Level.4, 0))               sequenceLength = 3;
         else if (LT(Lotsize.Level.4, Lotsize.Level.3)) return(catch("ValidateConfiguration(9)  Invalid input parameter Lotsize.Level.4 = "+ NumberToStr(Lotsize.Level.4, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
         else {
            ArrayPushDouble(levels.lots, Lotsize.Level.4);
            if      (EQ(Lotsize.Level.5, 0))               sequenceLength = 4;
            else if (LT(Lotsize.Level.5, Lotsize.Level.4)) return(catch("ValidateConfiguration(10)  Invalid input parameter Lotsize.Level.5 = "+ NumberToStr(Lotsize.Level.5, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
            else {
               ArrayPushDouble(levels.lots, Lotsize.Level.5);
               if      (EQ(Lotsize.Level.6, 0))               sequenceLength = 5;
               else if (LT(Lotsize.Level.6, Lotsize.Level.5)) return(catch("ValidateConfiguration(11)  Invalid input parameter Lotsize.Level.6 = "+ NumberToStr(Lotsize.Level.6, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
               else {
                  ArrayPushDouble(levels.lots, Lotsize.Level.6);
                  if      (EQ(Lotsize.Level.7, 0))               sequenceLength = 6;
                  else if (LT(Lotsize.Level.7, Lotsize.Level.6)) return(catch("ValidateConfiguration(12)  Invalid input parameter Lotsize.Level.7 = "+ NumberToStr(Lotsize.Level.7, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                  else {
                     ArrayPushDouble(levels.lots, Lotsize.Level.7);
                     sequenceLength = 7;
                  }
               }
            }
         }
      }
   }
   return(catch("ValidateConfiguration(13)"));
}


/**
 * Speichert die aktuelle Konfiguration und Laufzeitdaten der Instanz, um die korrekte und nahtlose Wiederauf- und Übernahme
 * durch eine andere Instanz im selben oder einem anderen Terminal zu ermöglichen.
 *
 * @return int - Fehlerstatus
 */
int SaveConfiguration() {
   if (sequenceId == 0) {
      status = STATUS_DISABLED;
      return(catch("SaveConfiguration(1)   illegal value of sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR));
   }
   debug("SaveConfiguration()   saving configuration for sequence #"+ sequenceId);


   // (1) Daten zusammenstellen
   string lines[];  ArrayResize(lines, 0);

   ArrayPushString(lines, /*int   */ "sequenceId="      +             sequenceId            );
   ArrayPushString(lines, /*string*/ "Entry.Direction=" +             Entry.Direction       );
   ArrayPushString(lines, /*double*/ "Entry.Limit="     + NumberToStr(Entry.Limit, ".+")    );
   ArrayPushString(lines, /*int   */ "TakeProfit="      +             TakeProfit            );
   ArrayPushString(lines, /*int   */ "StopLoss="        +             StopLoss              );
   ArrayPushString(lines, /*double*/ "Lotsize.Level.1=" + NumberToStr(Lotsize.Level.1, ".+"));
   ArrayPushString(lines, /*double*/ "Lotsize.Level.2=" + NumberToStr(Lotsize.Level.2, ".+"));
   ArrayPushString(lines, /*double*/ "Lotsize.Level.3=" + NumberToStr(Lotsize.Level.3, ".+"));
   ArrayPushString(lines, /*double*/ "Lotsize.Level.4=" + NumberToStr(Lotsize.Level.4, ".+"));
   ArrayPushString(lines, /*double*/ "Lotsize.Level.5=" + NumberToStr(Lotsize.Level.5, ".+"));
   ArrayPushString(lines, /*double*/ "Lotsize.Level.6=" + NumberToStr(Lotsize.Level.6, ".+"));
   ArrayPushString(lines, /*double*/ "Lotsize.Level.7=" + NumberToStr(Lotsize.Level.7, ".+"));


   // (2) Daten in lokale Datei schreiben
   string filename = "presets\\FTP."+ sequenceId +".set";

   int hFile = FileOpen(filename, FILE_CSV|FILE_WRITE);
   if (hFile < 0) {
      status = STATUS_DISABLED;
      return(catch("SaveConfiguration(2)  FileOpen(file=\""+ filename +"\")"));
   }
   for (int i=0; i < ArraySize(lines); i++) {
      if (FileWrite(hFile, lines[i]) < 0) {
         int error = GetLastError();
         FileClose(hFile);
         status = STATUS_DISABLED;
         return(catch("SaveConfiguration(3)  FileWrite(line #"+ (i+1) +")", error));
      }
   }
   FileClose(hFile);


   // (3) Datei auf Server laden
   error = UploadConfiguration(GetShortAccountCompany(), AccountNumber(), Symbol(), filename);
   if (error != NO_ERROR) {
      status = STATUS_DISABLED;
      return(error);
   }

   error = GetLastError();
   if (error != NO_ERROR) {
      status = STATUS_DISABLED;
      catch("SaveConfiguration(4)", error);
   }
   return(error);
}


/**
 * Lädt die angegebene Konfigurationsdatei auf den Server.
 *
 * @param  string company  - Account-Company
 * @param  int    account  - Account-Number
 * @param  string symbol   - Symbol der Konfiguration
 * @param  string filename - Dateiname, relativ zu "{terminal-directory}\experts\files"
 *
 * @return int - Fehlerstatus
 */
int UploadConfiguration(string company, int account, string symbol, string filename) {
   string parts[]; int size = Explode(filename, "\\", parts, NULL);

   // Befehlszeile für Shellaufruf zusammensetzen
   string url          = "http://sub.domain.tld/uploadFTPConfiguration.php?company="+ UrlEncode(company) +"&account="+ account +"&symbol="+ UrlEncode(symbol) +"&name="+ UrlEncode(parts[size-1]);
   string filesDir     = TerminalPath() +"\\experts\\files\\";
   string dataFile     = filesDir + filename;
   string responseFile = filesDir + filename +".response";
   string logFile      = filesDir + filename +".log";
   string cmdLine      = "wget.exe -b \""+ url +"\" --post-file=\""+ dataFile +"\" --header=\"Content-Type: text/plain\" -O \""+ responseFile +"\" -a \""+ logFile +"\"";

   // Existenz der Datei prüfen
   if (!IsFile(dataFile))
      return(catch("UploadConfiguration(1)   file not found: \""+ dataFile +"\"", ERR_FILE_NOT_FOUND));

   // Datei hochladen, WinExec() kehrt ohne zu warten zurück, wget -b beschleunigt zusätzlich
   int error = WinExec(cmdLine, SW_HIDE);                // SW_SHOWNORMAL|SW_HIDE
   if (error < 32)
      return(catch("UploadConfiguration(2)   execution of \""+ cmdLine +"\" failed with error="+ error +" ("+ ShellExecuteErrorToStr(error) +")", ERR_WINDOWS_ERROR));

   return(catch("UploadConfiguration(3)"));
}


/**
 * Liest die Konfiguration einer Sequenz ein und setzt die internen Variablen entsprechend. Ohne lokale Konfiguration
 * wird die Konfiguration vom Server zu laden und lokal gespeichert.
 *
 * @return int - Fehlerstatus
 */
int RestoreConfiguration() {
   if (sequenceId == 0)
      return(catch("RestoreConfiguration(1)   illegal value of sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR));

   // (1) bei nicht existierender lokaler Konfiguration die Datei vom Server laden
   string filesDir = TerminalPath() +"\\experts\\files\\";
   string fileName = "presets\\FTP."+ sequenceId +".set";

   if (!IsFile(filesDir + fileName)) {
      // Befehlszeile für Shellaufruf zusammensetzen
      string url        = "http://sub.domain.tld/downloadFTPConfiguration.php?company="+ UrlEncode(GetShortAccountCompany()) +"&account="+ AccountNumber() +"&symbol="+ UrlEncode(Symbol()) +"&sequence="+ sequenceId;
      string targetFile = filesDir +"\\"+ fileName;
      string logFile    = filesDir +"\\"+ fileName +".log";
      string cmdLine    = "wget.exe \""+ url +"\" -O \""+ targetFile +"\" -o \""+ logFile +"\"";

      debug("RestoreConfiguration()   downloading configuration for sequence #"+ sequenceId);

      int error = WinExecAndWait(cmdLine, SW_HIDE);      // SW_SHOWNORMAL|SW_HIDE
      if (error != NO_ERROR)
         return(processLibError(error));

      debug("RestoreConfiguration()   configuration for sequence #"+ sequenceId +" successfully downloaded");
      FileDelete(fileName +".log");
   }

   // (2) Datei einlesen
   debug("RestoreConfiguration()   restoring configuration for sequence #"+ sequenceId);
   string config[];
   int lines = FileReadLines(fileName, config, true);
   if (lines < 0)
      return(processLibError(stdlib_PeekLastError()));
   if (lines == 0) {
      FileDelete(fileName);
      return(catch("RestoreConfiguration(2)   no configuration found for sequence #"+ sequenceId, ERR_RUNTIME_ERROR));
   }

   // (3) Zeilen in Schlüssel-Wert-Paare aufbrechen, Datentypen validieren und Daten übernehmen
   int parameters[12]; ArrayInitialize(parameters, 0);
   #define I_SEQUENCEID       0
   #define I_ENTRY_DIRECTION  1
   #define I_ENTRY_LIMIT      2
   #define I_TAKEPROFIT       3
   #define I_STOPLOSS         4
   #define I_LOTSIZE_LEVEL_1  5
   #define I_LOTSIZE_LEVEL_2  6
   #define I_LOTSIZE_LEVEL_3  7
   #define I_LOTSIZE_LEVEL_4  8
   #define I_LOTSIZE_LEVEL_5  9
   #define I_LOTSIZE_LEVEL_6 10
   #define I_LOTSIZE_LEVEL_7 11

   string parts[];
   for (int i=0; i < lines; i++) {
      if (Explode(config[i], "=", parts, 2) != 2)                      return(catch("RestoreConfiguration(3)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR));
      string key=parts[0], value=parts[1];

      if (key == "sequenceId") {
         if (!StringIsDigit(value) || StrToInteger(value)!=sequenceId) return(catch("RestoreConfiguration(4)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR));
         parameters[I_SEQUENCEID] = 1;
      }
      else if (key == "Entry.Direction") {
         Entry.Direction = value;
         parameters[I_ENTRY_DIRECTION] = 1;
      }
      else if (key == "Entry.Limit") {
         if (!StringIsNumeric(value))                                  return(catch("RestoreConfiguration(5)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR));
         Entry.Limit = StrToDouble(value);
         parameters[I_ENTRY_LIMIT] = 1;
      }
      else if (key == "TakeProfit") {
         if (!StringIsDigit(value))                                    return(catch("RestoreConfiguration(6)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR));
         TakeProfit = StrToInteger(value);
         parameters[I_TAKEPROFIT] = 1;
      }
      else if (key == "StopLoss") {
         if (!StringIsDigit(value))                                    return(catch("RestoreConfiguration(7)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR));
         StopLoss = StrToInteger(value);
         parameters[I_STOPLOSS] = 1;
      }
      else if (key == "Lotsize.Level.1") {
         if (!StringIsNumeric(value))                                  return(catch("RestoreConfiguration(8)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR));
         Lotsize.Level.1 = StrToDouble(value);
         parameters[I_LOTSIZE_LEVEL_1] = 1;
      }
      else if (key == "Lotsize.Level.2") {
         if (!StringIsNumeric(value))                                  return(catch("RestoreConfiguration(9)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR));
         Lotsize.Level.2 = StrToDouble(value);
         parameters[I_LOTSIZE_LEVEL_2] = 1;
      }
      else if (key == "Lotsize.Level.3") {
         if (!StringIsNumeric(value))                                  return(catch("RestoreConfiguration(10)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR));
         Lotsize.Level.3 = StrToDouble(value);
         parameters[I_LOTSIZE_LEVEL_3] = 1;
      }
      else if (key == "Lotsize.Level.4") {
         if (!StringIsNumeric(value))                                  return(catch("RestoreConfiguration(11)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR));
         Lotsize.Level.4 = StrToDouble(value);
         parameters[I_LOTSIZE_LEVEL_4] = 1;
      }
      else if (key == "Lotsize.Level.5") {
         if (!StringIsNumeric(value))                                  return(catch("RestoreConfiguration(12)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR));
         Lotsize.Level.5 = StrToDouble(value);
         parameters[I_LOTSIZE_LEVEL_5] = 1;
      }
      else if (key == "Lotsize.Level.6") {
         if (!StringIsNumeric(value))                                  return(catch("RestoreConfiguration(13)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR));
         Lotsize.Level.6 = StrToDouble(value);
         parameters[I_LOTSIZE_LEVEL_6] = 1;
      }
      else if (key == "Lotsize.Level.7") {
         if (!StringIsNumeric(value))                                  return(catch("RestoreConfiguration(14)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR));
         Lotsize.Level.7 = StrToDouble(value);
         parameters[I_LOTSIZE_LEVEL_7] = 1;
      }
   }
   if (IntInArray(0, parameters))                                      return(catch("RestoreConfiguration(15)   one or more configuration values missing in file \""+ fileName +"\"", ERR_RUNTIME_ERROR));

   return(catch("RestoreConfiguration(16)"));
}
