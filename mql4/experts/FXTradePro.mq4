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
 *  Probleme:
 *  ---------
 *  - Verhältnis Spread/StopLoss: hohe Spreads machen den Einsatz teilweise unmöglich
 *  - Verhältnis Tagesvolatilität/Spread: teilweise wurde innerhalb von 10 Sekunden der nächste Level getriggert
 *  - beim Start müßten die obigen Kennziffern überprüft werden
 *
 *
 *  Voraussetzungen für Produktivbetrieb:
 *  -------------------------------------
 *  - Visualisierung der gesamten Sequenz implementieren
 *  - Hedges müssen sofort aufgelöst werden (MT4-Equity- und -Marginberechnung mit vielen Hedges ist fehlerhaft)
 *  - Visualisierung des Entry.Limits implementieren
 *  - ggf. muß statt nach STATUS_DISABLED nach STATUS_MONITORING gewechselt werden
 *  - Breakeven-Berechnung implementieren und anzeigen
 *  - Sicherheitsabfrage, wenn nach Änderung von TakeProfit sofort FinishSequence() getriggert wird
 *  - bei STATUS_FINISHED und STATUS_DISABLED muß ein REASON_RECOMPILE sich den alten Status merken
 *  - Heartbeat-Order einrichten
 *  - Heartbeat-Order muß signalisieren, wenn die Konfiguration sich geändert hat => erneuter Download vom Server
 *  - OrderCloseMultiple.HedgeSymbol() muß prüfen, ob das Hedge-Volumen mit MarketInfo(MODE_MINLOT) kollidiert
 *
 *
 *  TODO:
 *  -----
 *  - Input-Parameter müssen änderbar sein, ohne den EA anzuhalten
 *  - NumberToStr() reparieren: positives Vorzeichen, 1000-Trennzeichen
 *  - EA muß automatisch in beliebige Templates hineingeladen werden können
 *  - die Konfiguration einer gefundenen Sequenz muß automatisch in den Input-Dialog geladen werden
 *  - CheckStatus(): Commission-Berechnung an OrderCloseBy() anpassen
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


#define STATUS_UNDEFINED      0
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
extern double Lotsize.Level.1                = 0;
extern double Lotsize.Level.2                = 0;
extern double Lotsize.Level.3                = 0;
extern double Lotsize.Level.4                = 0;
extern double Lotsize.Level.5                = 0;
extern double Lotsize.Level.6                = 0;
extern double Lotsize.Level.7                = 0;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Input-Parameter sind nicht statisch und müssen bei REASON_CHARTCHANGE manuell zwischengespeichert und restauriert werden.
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
bool   intern = false;                                // Statusflag: TRUE = zwischengespeicherte Werte vorhanden (siehe deinit())

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int EA.uniqueId = 101;                                // eindeutige ID der Strategie (10 Bits: Bereich 0-1023)


double   Pip;
int      PipDigits;
int      PipPoints;
string   PriceFormat;
double   tickSize;

int      Entry.iDirection = OP_UNDEFINED;
double   Entry.LastBid;

int      sequenceId;
int      sequenceLength;
int      progressionLevel;

int      levels.ticket    [];                         // offenes Ticket des Levels (ein Ticket kann offen und mehrere geschlossen sein)
int      levels.type      [];
double   levels.lots      [], effectiveLots;          // Soll-Lotsize des Levels und aktuelle effektive Lotsize
double   levels.openLots  [];                         // aktuelle Order-Lotsize (inklusive Hedges)
double   levels.openPrice [], last.closePrice;
datetime levels.closeTime [];                         // Unterscheidung zwischen offenen und geschlossenen Positionen

double   levels.swap      [], levels.openSwap      [], levels.closedSwap      [], all.swaps;
double   levels.commission[], levels.openCommission[], levels.closedCommission[], all.commissions;
double   levels.profit    [], levels.openProfit    [], levels.closedProfit    [], all.profits;

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

   tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   int error = GetLastError();                                       // ERR_MARKETINFO_UPDATE abfangen
   if (error != NO_ERROR)                   { status = STATUS_DISABLED; return(catch("init(1)", error));                                                                   }
   if (tickSize < 0.000009 || tickSize > 1) { status = STATUS_DISABLED; return(catch("init(2)   MODE_TICKSIZE = "+ NumberToStr(tickSize,   ".+"), ERR_MARKETINFO_UPDATE)); }


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


   // (2) falls noch keine Sequenz definiert, die erste Sequenz suchen und einlesen
   if (sequenceId == 0) {
      //sequenceId = 10741;     // temporär
      //sequenceId = 13729;

      if (ReadSequence(sequenceId) != NO_ERROR) {
         status = STATUS_DISABLED;
         return(init_error);
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
      ArrayResize(levels.openPrice       , sequenceLength);
      ArrayResize(levels.closeTime       , sequenceLength);

      ArrayResize(levels.swap            , sequenceLength);
      ArrayResize(levels.commission      , sequenceLength);
      ArrayResize(levels.profit          , sequenceLength);

      ArrayResize(levels.openSwap        , sequenceLength);
      ArrayResize(levels.openCommission  , sequenceLength);
      ArrayResize(levels.openProfit      , sequenceLength);

      ArrayResize(levels.closedSwap      , sequenceLength);
      ArrayResize(levels.closedCommission, sequenceLength);
      ArrayResize(levels.closedProfit    , sequenceLength);

      ArrayResize(levels.maxProfit       , sequenceLength);
      ArrayResize(levels.maxDrawdown     , sequenceLength);
      ArrayResize(levels.breakeven       , sequenceLength);
   }


   // (4) neue und geänderte Konfigurationen speichern, alte Konfigurationen restaurieren
   if (newSequence) {
      if (NE(Entry.Limit, 0))                               // ohne Entry.Limit wird Konfiguration erst nach Sicherheitsabfrage in StartSequence() gespeichert
         SaveConfiguration();
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
   if (init_error != NO_ERROR)       status = STATUS_DISABLED;
   if (status != STATUS_DISABLED) {
      if (progressionLevel == 0) {
         if (EQ(Entry.Limit, 0))     status = STATUS_INITIALIZED;
         else                        status = STATUS_ENTRYLIMIT;
      }
      else if (NE(effectiveLots, 0)) status = STATUS_PROGRESSING;
      else                           status = STATUS_FINISHED;
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


   error = GetLastError();
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
         else                                   StartSequence();              // kein Limit definiert oder Limit erreicht
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
 * @param  int sequenceId - ID einer Sequenz (default: NULL)
 *
 * @return bool
 */
bool IsMyOrder(int sequenceId = NULL) {
   if (OrderSymbol() == Symbol()) {
      if (OrderMagicNumber() >> 22 == EA.uniqueId) {
         if (sequenceId == NULL)
            return(true);
         return(sequenceId == OrderMagicNumber() >> 8 & 0x3FFF);     // 14 Bits (Bits 9-22) => sequenceId
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

   levels.ticket   [0] = OrderTicket();
   levels.type     [0] = OrderType();
   levels.openLots [0] = OrderLots();
   levels.openPrice[0] = OrderOpenPrice();

   if (OrderType() == OP_BUY) effectiveLots =  OrderLots();
   else                       effectiveLots = -OrderLots();

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
   double last.lots = levels.lots[last];
   int    new.type  = levels.type[last] ^ 1;                               // 0=>1, 1=>0

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
   levels.ticket   [this] = OrderTicket();
   levels.type     [this] = OrderType();
   levels.openLots [this] = OrderLots();
   levels.openPrice[this] = OrderOpenPrice();

   if (OrderType() == OP_BUY) effectiveLots += OrderLots();
   else                       effectiveLots -= OrderLots();

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
      return(processError(stdlib_PeekLastError()));
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
      processError(stdlib_PeekLastError());

   if (catch("OpenPosition(3)") != NO_ERROR)
      return(-1);
   return(ticket);
}


/**
 * Überprüft die offenen Positionen der Sequenz auf Änderungen und berechnet die aktuellen Kennziffern (P/L, Breakeven etc.)
 *
 * @return bool - Erfolgsstatus
 */
bool CheckStatus() {
   // (1) offene Positionen auf Änderungen prüfen (OrderCloseTime(), OrderLots(), OrderSwap()) und Sequenzdaten ggf. aktualisieren
   for (int i=0; i < progressionLevel; i++) {
      if (levels.closeTime[i] == 0) {                                // Ticket prüfen, wenn es beim letzten Aufruf offen war
         if (!OrderSelect(levels.ticket[i], SELECT_BY_TICKET)) {
            int error = GetLastError();
            if (error == NO_ERROR)
               error = ERR_INVALID_TICKET;
            status = STATUS_DISABLED;
            return(catch("CheckStatus(1)", error)==NO_ERROR);
         }
         if (OrderCloseTime() != 0) {                                // Ticket wurde geschlossen           => Sequenz neu einlesen
            error = ReadSequence(sequenceId);
            break;
         }
         if (NE(OrderLots(), levels.openLots[i])) {                  // Ticket wurde teilweise geschlossen => Sequenz neu einlesen
            error = ReadSequence(sequenceId);
            break;
         }
         if (NE(OrderSwap(), levels.openSwap[i])) {                  // Swap hat sich geändert             => aktualisieren
            levels.openSwap[i] = OrderSwap();
            levels.swap.changed = true;
         }
      }
   }
   if (error != NO_ERROR) {
      status = STATUS_DISABLED;
      return(false);
   }


   // (3) MarketInfo()-Daten auslesen
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   error = GetLastError();                                           // ERR_MARKETINFO_UPDATE abfangen
   if (error != NO_ERROR)                 { status = STATUS_DISABLED; return(catch("CheckStatus(2)", error)==NO_ERROR);                                                                   }
   if (tickValue < 0.5 || tickValue > 20) { status = STATUS_DISABLED; return(catch("CheckStatus(4)   MODE_TICKVALUE = "+ NumberToStr(tickValue, ".+"), ERR_MARKETINFO_UPDATE)==NO_ERROR); }
   double pipValue = Pip / tickSize * tickValue;


   // (2) aktuellen Profit/Loss neu berechnen
   all.swaps       = 0;
   all.commissions = 0;
   all.profits     = 0;

   double priceDiff, tmp.openLots[]; ArrayResize(tmp.openLots, 0);
   ArrayCopy(tmp.openLots, levels.openLots);

   for (i=0; i < progressionLevel; i++) {
      if (levels.closeTime[i] == 0) {                                // offene Position
         if (!OrderSelect(levels.ticket[i], SELECT_BY_TICKET)) {
            error = GetLastError();
            if (error == NO_ERROR)
               error = ERR_INVALID_TICKET;
            status = STATUS_DISABLED;
            return(catch("CheckStatus(5)", error)==NO_ERROR);
         }
         levels.openProfit[i] = 0;

         if (GT(tmp.openLots[i], 0)) {                               // P/L offener Hedges verrechnen
            for (int n=i+1; n < progressionLevel; n++) {
               if (levels.closeTime[n]==0) /*&&*/ if (levels.type[i]!=levels.type[n]) /*&&*/ if (GT(tmp.openLots[n], 0)) { // offener und verrechenbarer Hedge
                  priceDiff = ifDouble(levels.type[i]==OP_BUY, levels.openPrice[n]-levels.openPrice[i], levels.openPrice[i]-levels.openPrice[n]);

                  if (LE(tmp.openLots[i], tmp.openLots[n])) {
                     levels.openProfit[i] += priceDiff / tickSize * tickValue * tmp.openLots[i];
                     tmp.openLots     [n] -= tmp.openLots[i];
                     tmp.openLots     [i]  = 0;
                     break;
                  }
                  else  /*(GT(tmp.openLots[i], tmp.openLots[n]))*/ {
                     levels.openProfit[i] += priceDiff / tickSize * tickValue * tmp.openLots[n];
                     tmp.openLots     [i] -= tmp.openLots[n];
                     tmp.openLots     [n]  = 0;
                  }
               }
            }

            // P/L von Restpositionen anteilmäßig anhand des regulären OrderProfit() ermitteln
            if (GT(tmp.openLots[i], 0))
               levels.openProfit[i] += OrderProfit() / levels.openLots[i] * tmp.openLots[i];
         }

         // TODO: korrekte Commission-Berechnung der Hedges implementieren
         levels.openCommission[i] = OrderCommission();
      }
      levels.swap      [i] = levels.openSwap      [i] + levels.closedSwap      [i];
      levels.commission[i] = levels.openCommission[i] + levels.closedCommission[i];
      levels.profit    [i] = levels.openProfit    [i] + levels.closedProfit    [i];

      all.swaps       += levels.swap      [i];
      all.commissions += levels.commission[i];
      all.profits     += levels.profit    [i];
   }


   // (3) zu erwartenden Profit/Loss neu berechnen
   double sl, prevDrawdown = 0;
   int    level = progressionLevel-1;

   for (i=0; i < sequenceLength; i++) {
      if (progressionLevel > 0 && i < progressionLevel-1) {                                     // tatsächlich angefallenen Verlust verwenden
         if (levels.type[i] == OP_BUY) sl = (levels.openPrice[i  ]-levels.openPrice[i+1]) / Pip;
         else                          sl = (levels.openPrice[i+1]-levels.openPrice[i  ]) / Pip;
      }
      else                             sl = StopLoss;                                           // konfigurierten StopLoss verwenden
      levels.maxProfit  [i] = prevDrawdown + levels.lots[i] * TakeProfit * pipValue;
      levels.maxDrawdown[i] = prevDrawdown - levels.lots[i] * sl         * pipValue;
      prevDrawdown          = levels.maxDrawdown[i];
   }


   if (catch("CheckStatus(6)") != NO_ERROR) {
      status = STATUS_DISABLED;
      return(false);
   }
   return(true);
}


/**
 * Setzt alle internen Daten der Sequenz zurück.
 *
 * @return int - Fehlerstatus
 */
int ResetAll() {
   Entry.iDirection = OP_UNDEFINED;
   Entry.LastBid    = 0;

   sequenceId       = 0;
   sequenceLength   = 0;
   progressionLevel = 0;

   effectiveLots    = 0;
   all.swaps        = 0;
   all.commissions  = 0;
   all.profits      = 0;

   status           = STATUS_UNDEFINED;

   if (ArraySize(levels.ticket) > 0) {
      ArrayResize(levels.ticket          , 0);
      ArrayResize(levels.type            , 0);
      ArrayResize(levels.lots            , 0);
      ArrayResize(levels.openLots        , 0);
      ArrayResize(levels.openPrice       , 0);
      ArrayResize(levels.closeTime       , 0);

      ArrayResize(levels.swap            , 0);
      ArrayResize(levels.commission      , 0);
      ArrayResize(levels.profit          , 0);

      ArrayResize(levels.openSwap        , 0);
      ArrayResize(levels.openCommission  , 0);
      ArrayResize(levels.openProfit      , 0);

      ArrayResize(levels.closedSwap      , 0);
      ArrayResize(levels.closedCommission, 0);
      ArrayResize(levels.closedProfit    , 0);

      ArrayResize(levels.maxProfit       , 0);
      ArrayResize(levels.maxDrawdown     , 0);
      ArrayResize(levels.breakeven       , 0);
   }
   return(catch("ResetAll()"));
}


/**
 * Liest die angegebene Sequenz komplett neu ein. Ohne Angabe einer ID wird die erste gefundene Sequenz eingelesen.
 *
 * @param  int id - ID der einzulesenden Sequenz
 *
 * @return int - Fehlerstatus
 */
int ReadSequence(int id = NULL) {
   levels.swap.changed = true;                                       // alle Flags zurücksetzen

   bool findSequence = false;
   if (id == 0) {
      ResetAll();
      findSequence = true;
   }
   else if (sequenceLength == 0) {                                   // keine internen Daten vorhanden
      ResetAll();
   }
   else if (ArraySize(levels.ticket) != sequenceLength) return(catch("ReadSequence(1)   illegal sequence state, variable sequenceLength ("+ sequenceLength +") doesn't match the number of levels ("+ ArraySize(levels.ticket) +")", ERR_RUNTIME_ERROR));
   sequenceId = id;


   // (1) ggf. Arrays zurücksetzen (außer levels.lots[] => enthält Konfiguration und wird nur in ValidateConfiguration() modifiziert)
   if (ArraySize(levels.ticket) > 0) {
      ArrayInitialize(levels.ticket          , 0.1);                 // Präzisionsfehler beim Casten von Doubles vermeiden: (int) ArrayInitialize()
      ArrayInitialize(levels.type,    OP_UNDEFINED);
      ArrayInitialize(levels.openLots        , 0  );
      ArrayInitialize(levels.openPrice       , 0  );
      ArrayInitialize(levels.closeTime       , 0.1);

      ArrayInitialize(levels.swap            , 0  );
      ArrayInitialize(levels.commission      , 0  );
      ArrayInitialize(levels.profit          , 0  );

      ArrayInitialize(levels.openSwap        , 0  );
      ArrayInitialize(levels.openCommission  , 0  );
      ArrayInitialize(levels.openProfit      , 0  );

      ArrayInitialize(levels.closedSwap      , 0  );
      ArrayInitialize(levels.closedCommission, 0  );
      ArrayInitialize(levels.closedProfit    , 0  );

      ArrayInitialize(levels.maxProfit       , 0  );
      ArrayInitialize(levels.maxDrawdown     , 0  );
      ArrayInitialize(levels.breakeven       , 0  );
   }
   effectiveLots = 0;


   // (2) offene Positionen einlesen
   for (int i=OrdersTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wird in einem anderen Thread eine offene Order entfernt
         continue;

      if (IsMyOrder(sequenceId)) {
         if (sequenceLength == 0) {
            sequenceId     = OrderMagicNumber() >> 8 & 0x3FFF;       // 14 Bits (Bits 9-22) => sequenceId
            sequenceLength = OrderMagicNumber() >> 4 & 0xF;          //  4 Bits (Bits 5-8 ) => sequenceLength

            ArrayResize(levels.ticket          , sequenceLength);
            ArrayResize(levels.type            , sequenceLength); ArrayInitialize(levels.type, OP_UNDEFINED);
            ArrayResize(levels.openLots        , sequenceLength);
            ArrayResize(levels.openPrice       , sequenceLength);
            ArrayResize(levels.closeTime       , sequenceLength);

            ArrayResize(levels.swap            , sequenceLength);
            ArrayResize(levels.commission      , sequenceLength);
            ArrayResize(levels.profit          , sequenceLength);

            ArrayResize(levels.openSwap        , sequenceLength);
            ArrayResize(levels.openCommission  , sequenceLength);
            ArrayResize(levels.openProfit      , sequenceLength);

            ArrayResize(levels.closedSwap      , sequenceLength);
            ArrayResize(levels.closedCommission, sequenceLength);
            ArrayResize(levels.closedProfit    , sequenceLength);

            ArrayResize(levels.maxProfit       , sequenceLength);
            ArrayResize(levels.maxDrawdown     , sequenceLength);
            ArrayResize(levels.breakeven       , sequenceLength);
         }
         if (OrderType() > OP_SELL)                                  // Nicht-Trades überspringen
            continue;

         int level = OrderMagicNumber() & 0xF;                       //  4 Bits (Bits 1-4)  => progressionLevel
         if (level > sequenceLength) return(catch("ReadSequence(2)   illegal sequence state, progression level "+ level +" of ticket #"+ OrderTicket() +" exceeds the value of sequenceLength = "+ sequenceLength, ERR_RUNTIME_ERROR));

         if (level > progressionLevel)
            progressionLevel = level;
         level--;

         levels.ticket        [level] = OrderTicket();
         levels.type          [level] = OrderType();
         levels.openLots      [level] = OrderLots();
         levels.openPrice     [level] = OrderOpenPrice();

         levels.openSwap      [level] = OrderSwap();
         levels.openCommission[level] = OrderCommission();
         levels.openProfit    [level] = OrderProfit();

         if (OrderType() == OP_BUY) effectiveLots += OrderLots();    // effektive Lotsize berechnen
         else                       effectiveLots -= OrderLots();
      }
   }


   // (3) Abbruch, falls keine Sequenz-ID angegeben und keine offenen Positionen gefunden wurden
   if (sequenceId == 0)
      return(catch("ReadSequence(3)"));


   // (4) geschlossene Positionen einlesen
   last.closePrice = 0;
   bool retry = true;

   while (retry) {                                                   // Endlosschleife, bis ausreichend History-Daten verfügbar sind
      int n, closedTickets=OrdersHistoryTotal();
      int      hist.tickets     []; ArrayResize(hist.tickets     , closedTickets);
      int      hist.types       []; ArrayResize(hist.types       , closedTickets);
      double   hist.lots        []; ArrayResize(hist.lots        , closedTickets);
      double   hist.openPrices  []; ArrayResize(hist.openPrices  , closedTickets);
      datetime hist.openTimes   []; ArrayResize(hist.openTimes   , closedTickets);
      double   hist.closePrices []; ArrayResize(hist.closePrices , closedTickets);
      datetime hist.closeTimes  []; ArrayResize(hist.closeTimes  , closedTickets);
      double   hist.swaps       []; ArrayResize(hist.swaps       , closedTickets);
      double   hist.commissions []; ArrayResize(hist.commissions , closedTickets);
      double   hist.profits     []; ArrayResize(hist.profits     , closedTickets);
      int      hist.magicNumbers[]; ArrayResize(hist.magicNumbers, closedTickets);
      string   hist.comments    []; ArrayResize(hist.comments    , closedTickets);

      for (i=0, n=0; i < closedTickets; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))           // FALSE: während des Auslesens wird der Anzeigezeitraum der History vekürzt
            break;

         // (4.1) Daten der geschlossenen Tickets der Sequenz auslesen
         if (IsMyOrder(sequenceId)) {
            if (sequenceLength == 0) {
               sequenceLength = OrderMagicNumber() >> 4 & 0xF;       //  4 Bits (Bits 5-8 ) => sequenceLength

               ArrayResize(levels.ticket          , sequenceLength);
               ArrayResize(levels.type            , sequenceLength); ArrayInitialize(levels.type, OP_UNDEFINED);
               ArrayResize(levels.openLots        , sequenceLength);
               ArrayResize(levels.openPrice       , sequenceLength);
               ArrayResize(levels.closeTime       , sequenceLength);

               ArrayResize(levels.swap            , sequenceLength);
               ArrayResize(levels.commission      , sequenceLength);
               ArrayResize(levels.profit          , sequenceLength);

               ArrayResize(levels.openSwap        , sequenceLength);
               ArrayResize(levels.openCommission  , sequenceLength);
               ArrayResize(levels.openProfit      , sequenceLength);

               ArrayResize(levels.closedSwap      , sequenceLength);
               ArrayResize(levels.closedCommission, sequenceLength);
               ArrayResize(levels.closedProfit    , sequenceLength);

               ArrayResize(levels.maxProfit       , sequenceLength);
               ArrayResize(levels.maxDrawdown     , sequenceLength);
               ArrayResize(levels.breakeven       , sequenceLength);
            }
            if (OrderType() > OP_SELL)                               // Nicht-Trades überspringen
               continue;

            hist.tickets     [n] = OrderTicket();
            hist.types       [n] = OrderType();
            hist.lots        [n] = OrderLots();
            hist.openPrices  [n] = OrderOpenPrice();
            hist.openTimes   [n] = OrderOpenTime();
            hist.closePrices [n] = OrderClosePrice();
            hist.closeTimes  [n] = OrderCloseTime();
            hist.swaps       [n] = OrderSwap();
            hist.commissions [n] = OrderCommission();
            hist.profits     [n] = OrderProfit();
            hist.magicNumbers[n] = OrderMagicNumber();
            hist.comments    [n] = OrderComment();
            n++;
         }
      }
      if (n < closedTickets) {
         ArrayResize(hist.tickets     , n);
         ArrayResize(hist.types       , n);
         ArrayResize(hist.lots        , n);
         ArrayResize(hist.openPrices  , n);
         ArrayResize(hist.openTimes   , n);
         ArrayResize(hist.closePrices , n);
         ArrayResize(hist.closeTimes  , n);
         ArrayResize(hist.swaps       , n);
         ArrayResize(hist.commissions , n);
         ArrayResize(hist.profits     , n);
         ArrayResize(hist.magicNumbers, n);
         ArrayResize(hist.comments    , n);
         closedTickets = n;
      }

      // (4.2) Hedges analysieren: relevante Daten der ersten Position zuordnen, hedgende Position verwerfen
      for (i=0; i < closedTickets; i++) {
         if (hist.tickets[i] == 0)                                   // markierte Tickets sind verworfene Hedges
            continue;

         if (EQ(hist.lots[i], 0)) {                                  // hist.lots = 0.00: Hedge-Position
            if (!StringIStartsWith(hist.comments[i], "close hedge by #"))
               return(catch("ReadSequence(4)  ticket #"+ hist.tickets[i] +" - unknown comment for assumed hedging position: \""+ hist.comments[i] +"\"", ERR_RUNTIME_ERROR));

            // Gegenstück suchen
            int ticket = StrToInteger(StringSubstr(hist.comments[i], 16));
            for (n=0; n < closedTickets; n++)
               if (hist.tickets[n] == ticket)
                  break;
            if (n == closedTickets) return(catch("ReadSequence(5)  cannot find counterpart for hedging position #"+ hist.tickets[i] +": \""+ hist.comments[i] +"\"", ERR_RUNTIME_ERROR));
            if (i == n            ) return(catch("ReadSequence(6)  both hedged and hedging position have the same ticket #"+ hist.tickets[i] +": \""+ hist.comments[i] +"\"", ERR_RUNTIME_ERROR));

            int first, second;
            if      (hist.openTimes[i] < hist.openTimes[n])                                     { first = i; second = n; }
            else if (hist.openTimes[i]==hist.openTimes[n] && hist.tickets[i] < hist.tickets[n]) { first = i; second = n; }
            else                                                                                { first = n; second = i; }

            // Ticketdaten korrigieren
            hist.lots[i] = hist.lots[n];                             // hist.lots[i] == 0.0 korrigieren
            if (i == first) {
               hist.closePrices[first] = hist.openPrices [second];   // alle Transaktionsdaten im ersten Ticket speichern
               hist.swaps      [first] = hist.swaps      [second];
               hist.commissions[first] = hist.commissions[second];
               hist.profits    [first] = hist.profits    [second];
            }
            hist.closeTimes[first] = hist.openTimes[second];
            hist.tickets  [second] = 0;                              // zweites Ticket als ungültig markieren
         }
      }

      datetime last.closeTime;

      // (4.3) levels.* mit den geschlossenen Tickets aktualisieren
      for (i=0; i < closedTickets; i++) {
         if (hist.tickets[i] == 0)                                   // markierte Tickets sind verworfene Hedges
            continue;

         level = hist.magicNumbers[i] & 0xF;                         // 4 Bits (Bits 1-4) => progressionLevel
         if (level > sequenceLength) return(catch("ReadSequence(7)   illegal sequence state, progression level "+ level +" of ticket #"+ hist.magicNumbers[i] +" exceeds the value of sequenceLength = "+ sequenceLength, ERR_RUNTIME_ERROR));

         if (level > progressionLevel)
            progressionLevel = level;
         level--;

         if (levels.ticket[level] == 0) {                            // unbelegter Level
            levels.ticket    [level] = hist.tickets    [i];
            levels.type      [level] = hist.types      [i];
            levels.openLots  [level] = hist.lots       [i];
            levels.openPrice [level] = hist.openPrices [i];
            levels.closeTime [level] = hist.closeTimes [i];
         }
         else if (levels.type[level] != hist.types[i]) {
            return(catch("ReadSequence(8)  illegal sequence state, operation type "+ OperationTypeDescription(levels.type[level]) +" (level "+ (level+1) +") doesn't match "+ OperationTypeDescription(hist.types[i]) +" of closed position #"+ hist.tickets[i], ERR_RUNTIME_ERROR));
         }
         levels.closedSwap      [level] += hist.swaps      [i];
         levels.closedCommission[level] += hist.commissions[i];
         levels.closedProfit    [level] += hist.profits    [i];

         if (hist.closeTimes[i] > last.closeTime) {
            last.closeTime  = hist.closeTimes[i];
            last.closePrice = hist.closePrices[i];
         }
      }


      // (5) offene und geschlossene Tickets auf Vollständigkeit überprüfen
      retry = false;
      for (i=0; i < progressionLevel; i++) {
         if (levels.ticket[i] == 0) {
            PlaySound("notify.wav");
            int button = MessageBox("Ticket for progression level "+ (i+1) +" not found.\nMore history data needed.", __SCRIPT__, MB_ICONEXCLAMATION|MB_RETRYCANCEL);
            if (button == IDRETRY) {
               retry = true;
               break;
            }
            catch("ReadSequence(9)");
            status = STATUS_DISABLED;
            return(processError(ERR_RUNTIME_ERROR));
         }
      }
   }

   return(catch("ReadSequence(10)"));
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

   string msg = "";

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

   double profitLoss, profitLossPips, lastPrice;
   int i;

   if (progressionLevel > 0) {
      i = progressionLevel-1;
      if (status == STATUS_FINISHED) {
         lastPrice = last.closePrice;
      }
      else {                                                         // TODO: NumberToStr(x, "+- ") implementieren
         msg         = StringConcatenate(msg, "  =  ", ifString(levels.type[i]==OP_BUY, "+", ""), NumberToStr(effectiveLots, ".+"), " lot");
         lastPrice = ifDouble(levels.type[i]==OP_BUY, Bid, Ask);
      }
      profitLossPips = ifDouble(levels.type[i]==OP_BUY, lastPrice-levels.openPrice[i], levels.openPrice[i]-lastPrice) / Pip;
      profitLoss     = all.swaps + all.commissions + all.profits;
   }
   else {
      i = 0;                                                         // in Progression-Level 0 TakeProfit- und StopLoss-Anzeige für ersten Level
   }

   msg = StringConcatenate(msg,                                                                                                                                                                      NL,
                          "Lot sizes:               ", str.levels.lots, "  (", DoubleToStr(levels.maxProfit[sequenceLength-1], 2), " / ", DoubleToStr(levels.maxDrawdown[sequenceLength-1], 2), ")", NL,
                          "TakeProfit:            ",   TakeProfit,                         " pip = ", DoubleToStr(levels.maxProfit[i], 2),                                                           NL,
                          "StopLoss:              ",   StopLoss,                           " pip = ", DoubleToStr(levels.maxDrawdown[i], 2),                                                         NL,
                          "Breakeven:           ",     DoubleToStr(0, Digits-PipDigits), " pip = ", NumberToStr(0, PriceFormat),                                                                     NL,
                          "Profit/Loss:           ",   DoubleToStr(profitLossPips, Digits-PipDigits), " pip = ", DoubleToStr(profitLoss, 2),                                                         NL);

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
      case STATUS_UNDEFINED  : return("STATUS_UNDEFINED"  );
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

   // TODO: nach Progressionstart unmögliche Parameteränderungen abfangen
   // z.B. Parameter werden geändert, ohne vorher im Input-Dialog die Konfigurationsdatei der Sequenz zu laden

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

   if (NE(Lotsize.Level.2, 0)) {
      if (LT(Lotsize.Level.2, Lotsize.Level.1)) return(catch("ValidateConfiguration(7)  Invalid input parameter Lotsize.Level.2 = "+ NumberToStr(Lotsize.Level.2, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
      ArrayPushDouble(levels.lots, Lotsize.Level.2);

      if (NE(Lotsize.Level.3, 0)) {
         if (LT(Lotsize.Level.3, Lotsize.Level.2)) return(catch("ValidateConfiguration(8)  Invalid input parameter Lotsize.Level.3 = "+ NumberToStr(Lotsize.Level.3, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
         ArrayPushDouble(levels.lots, Lotsize.Level.3);

         if (NE(Lotsize.Level.4, 0)) {
            if (LT(Lotsize.Level.4, Lotsize.Level.3)) return(catch("ValidateConfiguration(9)  Invalid input parameter Lotsize.Level.4 = "+ NumberToStr(Lotsize.Level.4, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
            ArrayPushDouble(levels.lots, Lotsize.Level.4);

            if (NE(Lotsize.Level.5, 0)) {
               if (LT(Lotsize.Level.5, Lotsize.Level.4)) return(catch("ValidateConfiguration(10)  Invalid input parameter Lotsize.Level.5 = "+ NumberToStr(Lotsize.Level.5, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
               ArrayPushDouble(levels.lots, Lotsize.Level.5);

               if (NE(Lotsize.Level.6, 0)) {
                  if (LT(Lotsize.Level.6, Lotsize.Level.5)) return(catch("ValidateConfiguration(11)  Invalid input parameter Lotsize.Level.6 = "+ NumberToStr(Lotsize.Level.6, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                  ArrayPushDouble(levels.lots, Lotsize.Level.6);

                  if (NE(Lotsize.Level.7, 0)) {
                     if (LT(Lotsize.Level.7, Lotsize.Level.6)) return(catch("ValidateConfiguration(12)  Invalid input parameter Lotsize.Level.7 = "+ NumberToStr(Lotsize.Level.7, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                     ArrayPushDouble(levels.lots, Lotsize.Level.7);
                  }
               }
            }
         }
      }
   }

   // Konfiguration mit aktuellen Daten einer laufenden Sequenz vergleichen
   if (sequenceId == 0) {
      sequenceLength = ArraySize(levels.lots);
   }
   else if (ArraySize(levels.lots) != sequenceLength) return(catch("ValidateConfiguration(13)   illegal sequence state, input parameters Lotsize.* ("+ ArraySize(levels.lots) +" levels) doesn't match sequenceLength "+ sequenceLength +" of sequence "+ sequenceId, ERR_RUNTIME_ERROR));
   else if (progressionLevel > 0) {
      if (NE(effectiveLots, 0)) {
         int last = progressionLevel-1;
         if (NE(levels.lots[last], ifInt(levels.type[last]==OP_BUY, 1, -1) * effectiveLots))
            return(catch("ValidateConfiguration(14)   illegal sequence state, current effective lot size ("+ NumberToStr(effectiveLots, ".+") +" lots) doesn't match the configured lot size of level "+ progressionLevel +" ("+ NumberToStr(levels.lots[last], ".+") +" lots)", ERR_RUNTIME_ERROR));
      }
      if (levels.type[0] != Entry.iDirection)         return(catch("ValidateConfiguration(15)   illegal sequence state, Entry.Direction = \""+ Entry.Direction +"\" doesn't match "+ OperationTypeDescription(levels.type[0]) +" order at level 1", ERR_RUNTIME_ERROR));
   }

   return(catch("ValidateConfiguration(16)"));
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
         return(processError(error));

      debug("RestoreConfiguration()   configuration for sequence #"+ sequenceId +" successfully downloaded");
      FileDelete(fileName +".log");
   }

   // (2) Datei einlesen
   debug("RestoreConfiguration()   restoring configuration for sequence #"+ sequenceId);
   string config[];
   int lines = FileReadLines(fileName, config, true);
   if (lines < 0)
      return(processError(stdlib_PeekLastError()));
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
