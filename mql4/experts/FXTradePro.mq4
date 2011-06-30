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
 *  TODO:
 *  -----
 *  - Konfiguration der Instanz extern speichern und bei Reload von dort einlesen
 *  - bei Recompilation zur Laufzeit (REASON_RECOMPILE) Sequenzdaten neu einlesen
 *  - bei Recompilation zur Laufzeit aktuelle Konfiguration aus dem externen Speicher laden
 *  - ReadStatus() muß die offenen Positionen auf Vollständigkeit und auf Änderungen (partielle Closes) prüfen
 *  - Symbolwechsel (REASON_CHARTCHANGE) und Accountwechsel (REASON_ACCOUNT) abfangen
 *  - gesamte Sequenz vorher auf [TradeserverLimits] prüfen
 *  - einzelne Tradefunktionen vorher auf [TradeserverLimits] prüfen lassen
 *  - falsche Zuweisung bei Restart, wenn das Limit während der Auszeit erreicht wurde => lastPrice auswerten
 *  - Visualisierung des Entry.Limits implementieren
 *  - Visualisierung der gesamten Sequenz implementieren
 *  - Spreadänderungen bei Limit-Checks berücksichtigen
 *  - korrekte Verarbeitung bereits geschlossener Hedge-Positionen implementieren (@see "multiple tickets found...")
 *  - in FinishSequence(): OrderCloseBy() implementieren
 *  - in ReadStatus(): Commission- und Profit-Berechnung an Verwendung von OrderCloseBy() anpassen
 *  - in ReadStatus(): Breakeven-Berechnung implementieren
 *  - Breakeven-Anzeige (in ShowStatus()???)
 *  - StopLoss->Breakeven und TakeProfit->Breakeven implementieren
 *  - SMS-Benachrichtigungen implementieren
 *  - Heartbeat-Order einrichten
 *  - Equity-Chart der laufenden Sequenz implementieren
 *  - ShowStatus() übersichtlicher gestalten (mit Textlabeln statt Comment()-Funktion)
 */
#include <stdlib.mqh>


#define STATUS_INITIALIZED       1
#define STATUS_WAIT_ENTRYLIMIT   2
#define STATUS_PROGRESSING       3
#define STATUS_FINISHED          4
#define STATUS_DISABLED          5



//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string _1____________________________ = "==== Entry Options ===================";
extern string Entry.Direction                = "long";
extern double Entry.Limit                    = 0;
//extern double Entry.Limit                    = 2.0;

extern string _2____________________________ = "==== TP and SL Settings ==============";
extern int    TakeProfit                     = 50;
extern int    StopLoss                       = 10;

extern string _3____________________________ = "==== Lotsizes =======================";
extern double Lotsize.Level.1                = 0.1;
extern double Lotsize.Level.2                = 0.1;
extern double Lotsize.Level.3                = 0.2;
extern double Lotsize.Level.4                = 0.3;
extern double Lotsize.Level.5                = 0.4;
extern double Lotsize.Level.6                = 0.6;
extern double Lotsize.Level.7                = 0.8;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int EA.uniqueId = 101;                          // eindeutige ID der Strategie (10 Bits: Bereich 0-1023)


double   Pip;
int      PipDigits;
string   PriceFormat;

int      sequenceId;
int      sequenceLength;
int      progressionLevel;
int      entryDirection = OP_UNDEFINED;
double   entryLastPrice;
string   entryLimitType;
int      status;

int      levels.ticket    [];
int      levels.type      [];
double   levels.openPrice [];
double   levels.lotsize   [];
double   levels.swap      [], all.swaps;
double   levels.commission[], all.commissions;
double   levels.profit    [], all.profits;
datetime levels.closeTime [];                   // Unterscheidung zwischen offenen und geschlossenen Positionen

bool     firstTick = true;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   PipDigits   = Digits & (~1);
   Pip         = 1/MathPow(10, PipDigits);
   PriceFormat = "."+ PipDigits + ifString(Digits==PipDigits, "", "'");


   // (1) Parametervalidierung
   if (UninitializeReason() != REASON_CHARTCHANGE) {                       // bei REASON_CHARTCHANGE wurde bereits vorher validiert
      // Entry.Direction
      string direction = StringToUpper(StringTrim(Entry.Direction));
      if (StringLen(direction) == 0)
         return(catch("init(1)  Invalid input parameter Entry.Direction = \""+ Entry.Direction +"\"", ERR_INVALID_INPUT_PARAMVALUE));
      switch (StringGetChar(direction, 0)) {
         case 'B':
         case 'L': entryDirection = OP_BUY;  break;
         case 'S': entryDirection = OP_SELL; break;
         default:
            return(catch("init(2)  Invalid input parameter Entry.Direction = \""+ Entry.Direction +"\"", ERR_INVALID_INPUT_PARAMVALUE));
      }

      // Entry.Limit
      if (LT(Entry.Limit, 0))
         return(catch("init(3)  Invalid input parameter Entry.Limit = "+ NumberToStr(Entry.Limit, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
      // TODO: falsche Zuweisung bei Restart, wenn das Limit während der Auszeit erreicht wurde => lastPrice auswerten
      if (entryDirection == OP_BUY) entryLimitType = ifString(LT(Entry.Limit, Ask), "Buy Limit" , "Stop Buy" );
      else                          entryLimitType = ifString(GT(Entry.Limit, Bid), "Sell Limit", "Stop Sell");

      // TakeProfit
      if (TakeProfit < 1)
         return(catch("init(4)  Invalid input parameter TakeProfit = "+ TakeProfit, ERR_INVALID_INPUT_PARAMVALUE));

      // StopLoss
      if (StopLoss < 1)
         return(catch("init(5)  Invalid input parameter StopLoss = "+ StopLoss, ERR_INVALID_INPUT_PARAMVALUE));

      // Lotsizes
      if (LE(Lotsize.Level.1, 0)) return(catch("init(6)  Invalid input parameter Lotsize.Level.1 = "+ NumberToStr(Lotsize.Level.1, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
      if (LT(Lotsize.Level.2, 0)) return(catch("init(7)  Invalid input parameter Lotsize.Level.2 = "+ NumberToStr(Lotsize.Level.2, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
      if (EQ(Lotsize.Level.2, 0)) sequenceLength = 1;
      else {
         if (LT(Lotsize.Level.3, 0)) return(catch("init(8)  Invalid input parameter Lotsize.Level.3 = "+ NumberToStr(Lotsize.Level.3, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
         if (EQ(Lotsize.Level.3, 0)) sequenceLength = 2;
         else {
            if (LT(Lotsize.Level.4, 0)) return(catch("init(9)  Invalid input parameter Lotsize.Level.4 = "+ NumberToStr(Lotsize.Level.4, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
            if (EQ(Lotsize.Level.4, 0)) sequenceLength = 3;
            else {
               if (LT(Lotsize.Level.5, 0)) return(catch("init(10)  Invalid input parameter Lotsize.Level.5 = "+ NumberToStr(Lotsize.Level.5, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
               if (EQ(Lotsize.Level.5, 0)) sequenceLength = 4;
               else {
                  if (LT(Lotsize.Level.6, 0)) return(catch("init(11)  Invalid input parameter Lotsize.Level.6 = "+ NumberToStr(Lotsize.Level.6, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                  if (EQ(Lotsize.Level.6, 0)) sequenceLength = 5;
                  else {
                     if (LT(Lotsize.Level.7, 0)) return(catch("init(12)  Invalid input parameter Lotsize.Level.7 = "+ NumberToStr(Lotsize.Level.7, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                     if (EQ(Lotsize.Level.7, 0)) sequenceLength = 6;
                     else                        sequenceLength = 7;
                  }
               }
            }
         }
      }
   }


   // (2) Sequenzdaten einlesen
   if (sequenceId == 0) {                                               // noch keine Sequenz definiert
      progressionLevel = 0;
      ArrayResize(levels.ticket    , 0);                                // ggf. vorhandene Daten löschen (Arrays sind statisch)
      ArrayResize(levels.type      , 0);
      ArrayResize(levels.openPrice , 0);
      ArrayResize(levels.lotsize   , 0);
      ArrayResize(levels.swap      , 0);
      ArrayResize(levels.commission, 0);
      ArrayResize(levels.profit    , 0);
      ArrayResize(levels.closeTime , 0);

      // erste aktive Sequenz finden und offene Positionen einlesen
      for (int i=OrdersTotal()-1; i >= 0; i--) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wird in einem anderen Thread eine offene Order entfernt
            continue;

         if (IsMyOrder(sequenceId)) {
            int level = OrderMagicNumber() & 0x000F;                    //  4 Bits (Bits 1-4)  => progressionLevel
            if (level > progressionLevel)
               progressionLevel = level;

            if (sequenceId == 0) {
               sequenceId     = OrderMagicNumber() << 10 >> 18;         // 14 Bits (Bits 9-22) => sequenceId
               sequenceLength = OrderMagicNumber() & 0x00F0 >> 4;       //  4 Bits (Bits 5-8 ) => sequenceLength

               ArrayResize(levels.ticket    , sequenceLength);
               ArrayResize(levels.type      , sequenceLength);
               ArrayResize(levels.openPrice , sequenceLength);
               ArrayResize(levels.lotsize   , sequenceLength);
               ArrayResize(levels.swap      , sequenceLength);
               ArrayResize(levels.commission, sequenceLength);
               ArrayResize(levels.profit    , sequenceLength);
               ArrayResize(levels.closeTime , sequenceLength);

               if (level&1 == 1) entryDirection = OrderType();
               else              entryDirection = OrderType() ^ 1;      // 0=>1, 1=>0
            }
            level--;
            levels.ticket    [level] = OrderTicket();
            levels.type      [level] = OrderType();
            levels.openPrice [level] = OrderOpenPrice();
            levels.lotsize   [level] = OrderLots();
            levels.swap      [level] = 0;                               // Beträge offener Positionen werden in ReadStatus() ausgelesen
            levels.commission[level] = 0;
            levels.profit    [level] = 0;
            levels.closeTime [level] = 0;                               // closeTime == 0: offene Position
         }
      }

      // fehlende Positionen aus der History auslesen
      if (sequenceId != 0) /*&&*/ if (IntInArray(0, levels.ticket)) {
         int orders = OrdersHistoryTotal();
         for (i=0; i < orders; i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))           // FALSE: während des Auslesens wird der Anzeigezeitraum der History geändert
               break;

            if (IsMyOrder(sequenceId)) {
               level = OrderMagicNumber() & 0x000F;                     // 4 Bits (Bits 1-4) => progressionLevel
               if (level > progressionLevel)
                  progressionLevel = level;
               level--;

               // TODO: möglich bei gehedgten Positionen
               if (levels.ticket[level] != 0)
                  return(catch("init(13)   multiple tickets found for progression level "+ (level+1) +": #"+ levels.ticket[level] +", #"+ OrderTicket(), ERR_RUNTIME_ERROR));

               levels.ticket    [level] = OrderTicket();
               levels.type      [level] = OrderType();
               levels.openPrice [level] = OrderOpenPrice();
               levels.lotsize   [level] = OrderLots();
               levels.swap      [level] = OrderSwap();
               levels.commission[level] = OrderCommission();
               levels.profit    [level] = OrderProfit();
               levels.closeTime [level] = OrderCloseTime();             // closeTime != 0: geschlossene Position
            }
         }
      }

      // Tickets auf Vollständigkeit prüfen und Volumen der Hedge-Positionen ausgleichen
      double total;
      for (i=0; i < progressionLevel; i++) {
         if (levels.ticket[i] == 0)
            return(catch("init(14)   order not found for progression level "+ (i+1) +", more history data needed.", ERR_RUNTIME_ERROR));

         if (levels.closeTime[i] == 0) {
            if (levels.type[i] == OP_BUY) total += levels.lotsize[i];
            else                          total -= levels.lotsize[i];
            levels.lotsize[i] = MathAbs(total);
         }
      }
   }


   // (3) ggf. neue Sequenz anlegen
   if (sequenceId == 0) {
      sequenceId = CreateSequenceId();
      ArrayResize(levels.ticket    , sequenceLength);
      ArrayResize(levels.type      , sequenceLength);
      ArrayResize(levels.openPrice , sequenceLength);
      ArrayResize(levels.lotsize   , sequenceLength);
      ArrayResize(levels.swap      , sequenceLength);
      ArrayResize(levels.commission, sequenceLength);
      ArrayResize(levels.profit    , sequenceLength);
      ArrayResize(levels.closeTime , sequenceLength);
   }


   // (4) aktuellen Status bestimmen und anzeigen
   if (status == 0) {
      if (progressionLevel == 0) {
         if (EQ(Entry.Limit, 0))          status = STATUS_INITIALIZED;
         else                             status = STATUS_WAIT_ENTRYLIMIT;
      }
      else {
         int last = progressionLevel-1;
         if (levels.closeTime[last] == 0) status = STATUS_PROGRESSING;
         else                             status = STATUS_FINISHED;
      }
   }
   ShowStatus();


   // (5) Konfiguration speichern
   /*
   // Entry Options
   string Entry.Direction = "long";
   double Entry.Limit     = 0;
   // TP and SL Settings
   int    TakeProfit      = 40;
   int    StopLoss        = 10;
   // Lotsizes
   double Lotsize.Level.1 = 0.1;
   double Lotsize.Level.2 = 0.1;
   double Lotsize.Level.3 = 0.2;
   double Lotsize.Level.4 = 0.3;
   double Lotsize.Level.5 = 0.4;
   double Lotsize.Level.6 = 0.6;
   double Lotsize.Level.7 = 0.8;
   // Laufzeitdaten
   int    sequenceId;
   double entryLastPrice;
   */


   // (6) bei Start ggf. EA's aktivieren
   int reasons1[] = { REASON_REMOVE, REASON_CHARTCLOSE, REASON_APPEXIT };
   if (!IsExpertEnabled()) /*&&*/ if (IntInArray(UninitializeReason(), reasons1))
      ToggleEAs(true);


   // (7) nach Start oder Reload nicht auf den nächsten Tick warten
   int reasons2[] = { REASON_REMOVE, REASON_CHARTCLOSE, REASON_APPEXIT, REASON_PARAMETERS, REASON_RECOMPILE };
   if (IntInArray(UninitializeReason(), reasons2))
      SendTick(false);


   int error = GetLastError();
   if (error      != NO_ERROR) catch("init(15)", error);
   if (last_error != NO_ERROR) status = STATUS_DISABLED;
   return(last_error);
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   init = false;
   if (last_error != NO_ERROR) return(last_error);

   // temporäre Laufzeitanalyse
   bool priceError;
   if (Bid < 0.00000001) { priceError = true; catch("start()   Bid = "+ NumberToStr(Bid, PriceFormat), ERR_RUNTIME_ERROR); }
   if (Ask < 0.00000001) { priceError = true; catch("start()   Ask = "+ NumberToStr(Ask, PriceFormat), ERR_RUNTIME_ERROR); }
   if (priceError) {
      last_error = NO_ERROR;
      return(last_error);
   }
   // --------------------------------------------


   if (status==STATUS_FINISHED || status==STATUS_DISABLED)
      return(NO_ERROR);


   if (ReadStatus()) {
      if (progressionLevel == 0) {
         if (!IsEntryLimitReached())            status = STATUS_WAIT_ENTRYLIMIT;
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
 * Überprüft den Status der aktuellen Sequenz.
 *
 * @return bool - Erfolgsstatus
 */
bool ReadStatus() {
   double swaps, commissions, profits;

   for (int i=0; i < sequenceLength; i++) {
      if (levels.ticket[i] == 0)
         break;

      if (levels.closeTime[i] == 0) {                             // offene Position
         if (!OrderSelect(levels.ticket[i], SELECT_BY_TICKET)) {
            status = STATUS_DISABLED;
            return(catch("ReadStatus(1)")==NO_ERROR);
         }
         if (OrderCloseTime() != 0) {
            status = STATUS_DISABLED;
            return(catch("ReadStatus(2)   illegal sequence state, ticket #"+ levels.ticket[i] +"(level "+ (i+1) +") is already closed", ERR_RUNTIME_ERROR)==NO_ERROR);
         }
         levels.swap      [i] = OrderSwap();
         levels.commission[i] = OrderCommission();
         levels.profit    [i] = OrderProfit();
      }
      swaps       += levels.swap      [i];
      commissions += levels.commission[i];
      profits     += levels.profit    [i];

      // TODO: korrekte Commission- und Profit-Berechnung bei Verwendung von OrderCloseBy() implementieren
   }

   all.swaps       = swaps;                                       // zum Schluß globale Variablen überschreiben
   all.commissions = commissions;
   all.profits     = profits;

   if (catch("ReadStatus(3)") != NO_ERROR) {
      status = STATUS_DISABLED;
      return(false);
   }
   return(true);
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
            return(sequenceId == OrderMagicNumber() << 10 >> 18);       // 14 Bits (Bits 9-22) => sequenceId
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

   int ea       = EA.uniqueId << 22;                  // 10 bit (Bereich 0-1023)                                 | in MagicNumber: Bits 23-32
   int sequence = sequenceId  << 18 >> 10;            // 14 bit (Bits größer 14 löschen und auf 22 Bit erweitern | in MagicNumber: Bits  9-22
   int length   = sequenceLength   & 0x000F << 4;     //  4 bit (Bereich 1-7), auf 8 bit erweitern               | in MagicNumber: Bits  5-8
   int level    = progressionLevel & 0x000F;          //  4 bit (Bereich 1-7)                                    | in MagicNumber: Bits  1-4

   return(ea + sequence + length + level);
}


/**
 * Ob das konfigurierte EntryLimit erreicht oder überschritten wurde.  Wurde kein Limit angegeben, gibt die Funktion immer TRUE zurück.
 *
 * @return bool
 */
bool IsEntryLimitReached() {
   if (EQ(Entry.Limit, 0))                                           // kein Limit definiert
      return(true);

   // Limit ist definiert
   double price = ifDouble(entryDirection==OP_SELL, Bid, Ask);       // Das Limit ist erreicht, wenn der Preis es seit dem letzten Tick berührt oder gekreuzt hat.

   if (EQ(price, Entry.Limit) || EQ(entryLastPrice, Entry.Limit)) {  // Preis liegt oder lag beim letzten Tick exakt auf dem Limit
      debug("IsEntryLimitReached()   Tick="+ NumberToStr(price, PriceFormat) +" liegt genau auf dem Limit="+ NumberToStr(Entry.Limit, PriceFormat));
      entryLastPrice = Entry.Limit;                                  // Tritt während der weiteren Verarbeitung des Ticks ein behandelbarer Fehler auf, wird durch
      return(true);                                                  // entryLastPrice = Entry.Limit das Limit, einmal getriggert, nachfolgend immer wieder getriggert.
   }

   if (NE(entryLastPrice, 0)) {                                      // entryLastPrice muß initialisiert sein => ersten Aufruf überspringen
      if (LT(entryLastPrice, Entry.Limit)) {
         if (GT(price, Entry.Limit)) {                               // Tick hat Limit von unten nach oben gekreuzt
            debug("IsEntryLimitReached()   Tick hat Limit="+ NumberToStr(Entry.Limit, PriceFormat) +" von unten (lastPrice="+ NumberToStr(entryLastPrice, PriceFormat) +") nach oben (price="+ NumberToStr(price, PriceFormat) +") gekreuzt");
            entryLastPrice = Entry.Limit;
            return(true);
         }
      }
      else if (LT(price, Entry.Limit)) {                             // Tick hat Limit von oben nach unten gekreuzt
         debug("IsEntryLimitReached()   Tick hat Limit="+ NumberToStr(Entry.Limit, PriceFormat) +" von oben (lastPrice="+ NumberToStr(entryLastPrice, PriceFormat) +") nach unten (price="+ NumberToStr(price, PriceFormat) +") gekreuzt");
         entryLastPrice = Entry.Limit;
         return(true);
      }
   }
   entryLastPrice = price;

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

   static string last.directions[] = { "long", "short" };
   static string last.priceNames[] = { "Bid" , "Ask"   };

   if (last.type == OP_BUY) {
      last.price = Bid;
      last.loss  = last.openPrice-Bid;
   }
   else {
      last.price = Ask;
      last.loss  = Ask-last.openPrice;
   }

   if (GT(last.loss, StopLoss*Pip)) {
      log("IsStopLossReached()   StopLoss für "+ last.directions[last.type] +" position erreicht: "+ DoubleToStr(last.loss/Pip, Digits-PipDigits) +" pip (openPrice="+ NumberToStr(last.openPrice, PriceFormat) +", "+ last.priceNames[last.type] +"="+ NumberToStr(last.price, PriceFormat) +")");
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
      log("IsProfitTargetReached()   TakeProfit für "+ last.directions[last.type] +" position erreicht: "+ DoubleToStr(last.profit/Pip, Digits-PipDigits) +" pip (openPrice="+ NumberToStr(last.openPrice, PriceFormat) +", "+ last.priceNames[last.type] +"="+ NumberToStr(last.price, PriceFormat) +")");
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
   if (firstTick) {                                               // Sicherheitsabfrage, wenn Sequenzstart sofort beim ersten Tick erfolgt
      PlaySound("notify.wav");
      int button = MessageBox(ifString(!IsDemo(), "Live Account\n\n", "") +"Do you really want to start a new trade sequence?", __SCRIPT__, MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) {
         status = STATUS_DISABLED;
         return(catch("StartSequence(1)"));
      }
   }

   progressionLevel = 1;

   int ticket = OpenPosition(entryDirection, CurrentLotSize());   // Position in Entry.Direction öffnen
   if (ticket == -1) {
      status = STATUS_DISABLED;
      return(catch("StartSequence(2)"));
   }

   // Sequenzdaten aktualisieren
   if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      status = STATUS_DISABLED;
      return(catch("StartSequence(3)"));
   }

   levels.ticket    [0] = OrderTicket();
   levels.type      [0] = OrderType();
   levels.openPrice [0] = OrderOpenPrice();
   levels.lotsize   [0] = OrderLots();
   levels.swap      [0] = 0;
   levels.commission[0] = 0;                                      // Werte werden in ReadStatus() ausgelesen
   levels.profit    [0] = 0;
   levels.closeTime [0] = 0;

   // Status aktualisieren
   status = STATUS_PROGRESSING;
   ReadStatus();

   return(catch("StartSequence(4)"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int IncreaseProgression() {
   int    last         = progressionLevel-1;
   double last.lotsize = levels.lotsize[last];
   int    new.type     = levels.type   [last] ^ 1;                         // 0=>1, 1=>0

   progressionLevel++;

   int ticket = OpenPosition(new.type, last.lotsize + CurrentLotSize());   // alte Position hedgen und nächste öffnen
   if (ticket == -1) {
      status = STATUS_DISABLED;
      return(catch("IncreaseProgression(1)"));
   }

   // Sequenzdaten aktualisieren
   if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      status = STATUS_DISABLED;
      return(catch("IncreaseProgression(2)"));
   }

   last = progressionLevel-1;
   levels.ticket    [last] = OrderTicket();
   levels.type      [last] = OrderType();
   levels.openPrice [last] = OrderOpenPrice();
   levels.lotsize   [last] = CurrentLotSize();                             // wegen Hedge nicht OrderLots() verwenden
   levels.swap      [last] = 0;
   levels.commission[last] = 0;                                            // Werte werden in ReadStatus() ausgelesen
   levels.profit    [last] = 0;
   levels.closeTime [last] = 0;

   // Status aktualisieren
   ReadStatus();

   return(catch("IncreaseProgression(3)"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int FinishSequence() {
   // TODO: OrderCloseBy() implementieren
   for (int i=0; i < sequenceLength; i++) {
      if (levels.ticket[i] > 0) /*&&*/ if (levels.closeTime[i] == 0) {
         if (!OrderCloseEx(levels.ticket[i], NULL, NULL, 1, Orange)) {
            status = STATUS_DISABLED;
            last_error = stdlib_PeekLastError();
            return(last_error);
         }
         if (!OrderSelect(levels.ticket[i], SELECT_BY_TICKET)) {
            status = STATUS_DISABLED;
            return(catch("FinishSequence(1)"));
         }
         levels.swap      [i] = OrderSwap();
         levels.commission[i] = OrderCommission();
         levels.profit    [i] = OrderProfit();
         levels.closeTime [i] = OrderCloseTime();
      }
   }

   // Status aktualisieren
   status = STATUS_FINISHED;
   ReadStatus();

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
   int    slippage    = 1;
   color  markerColor = ifInt(type==OP_BUY, Blue, Red);

   int ticket = OrderSendEx(Symbol(), type, lotsize, NULL, slippage, NULL, NULL, comment, magicNumber, NULL, markerColor);
   if (ticket == -1)
      last_error = stdlib_PeekLastError();

   if (catch("OpenPosition(3)") != NO_ERROR)
      return(-1);
   return(ticket);
}


/**
 * Gibt die Lotsize des aktuellen Progression-Levels zurück.
 *
 * @return double - Lotsize oder -1, wenn ein Fehler auftrat
 */
double CurrentLotSize() {
   switch (progressionLevel) {
      case 1: return(Lotsize.Level.1);
      case 2: return(Lotsize.Level.2);
      case 3: return(Lotsize.Level.3);
      case 4: return(Lotsize.Level.4);
      case 5: return(Lotsize.Level.5);
      case 6: return(Lotsize.Level.6);
      case 7: return(Lotsize.Level.7);
   }

   catch("CurrentLotSize()   illegal progression level = "+ progressionLevel, ERR_RUNTIME_ERROR);
   return(-1);
}


/**
 * TODO: Nach Fertigstellung alles auf StringConcatenate() umstellen.
 *
 * @return int - Fehlerstatus
 */
int ShowStatus() {
   if (last_error != NO_ERROR)
      status = STATUS_DISABLED;

   string msg = "";

   switch (status) {
      case STATUS_INITIALIZED:     msg =                   ":  initialized";                                                                  break;
      case STATUS_WAIT_ENTRYLIMIT: msg = StringConcatenate(":  waiting for ", entryLimitType, " at ", NumberToStr(Entry.Limit, PriceFormat)); break;
      case STATUS_PROGRESSING:     msg = StringConcatenate(":  trade sequence ", sequenceId, ", progressing ...");                            break;
      case STATUS_FINISHED:        msg = StringConcatenate(":  trade sequence ", sequenceId, " finished");                                    break;
      case STATUS_DISABLED:        msg =                   ":  disabled";
                                   if (last_error != NO_ERROR) msg = StringConcatenate(msg, "  [", ErrorDescription(last_error), "]");        break;
      default:
         return(catch("ShowStatus(1)   illegal sequence status = "+ status, ERR_RUNTIME_ERROR));
   }

   msg = StringConcatenate(__SCRIPT__, msg,                                            NL,
                                                                                       NL,
                          "Progression Level:  ", progressionLevel, " / ", sequenceLength);

   if (progressionLevel > 0)
      msg = StringConcatenate(msg, "  =  ", ifString(levels.type[progressionLevel-1]==OP_BUY, "+", "-"), NumberToStr(CurrentLotSize(), ".+"), " lot");

   msg = StringConcatenate(msg,                                                                                  NL,
                          "TakeProfit:            ", TakeProfit +" pip = ",                                      NL,
                          "StopLoss:              ", StopLoss +" pip = ",                                        NL,
                        //"Breakeven:           ", "-",                                                          NL,
                          "Profit / Loss:          ", DoubleToStr(all.profits + all.commissions + all.swaps, 2), NL);

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
      case STATUS_INITIALIZED    : return("STATUS_INITIALIZED"    );
      case STATUS_WAIT_ENTRYLIMIT: return("STATUS_WAIT_ENTRYLIMIT");
      case STATUS_PROGRESSING    : return("STATUS_PROGRESSING"    );
      case STATUS_FINISHED       : return("STATUS_FINISHED"       );
      case STATUS_DISABLED       : return("STATUS_DISABLED"       );
   }
   catch("StatusToStr()  invalid parameter status: "+ status, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}
