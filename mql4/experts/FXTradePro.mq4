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
 *  - Konfiguration der Instanz auf Server speichern und bei Reload ggf. von dort einlesen
 *  - bei fehlender Konfiguration muß die laufende Instanz weitmöglichst eingelesen werden
 *  - ReadStatus() muß die offenen Positionen auf Vollständigkeit und auf Änderungen (partielle Closes) prüfen
 *  - Verfahrensweise für einzelne geschlossene Positionen entwickeln (z.B. letzte Position wurde manuell geschlossen)
 *  - ggf. muß statt nach STATUS_DISABLED nach STATUS_MONITORING gewechselt werden
 *  - Symbolwechsel (REASON_CHARTCHANGE) und Accountwechsel (REASON_ACCOUNT) abfangen
 *  - gesamte Sequenz vorher auf [TradeserverLimits] prüfen
 *  - einzelne Tradefunktionen vorher auf [TradeserverLimits] prüfen lassen
 *  - Visualisierung des Entry.Limits implementieren
 *  - Visualisierung der gesamten Sequenz implementieren
 *  - Spreadänderungen bei Limit-Checks berücksichtigen
 *  - korrekte Verarbeitung bereits geschlossener Hedge-Positionen implementieren (@see "multiple tickets found...")
 *  - in FinishSequence(): OrderCloseBy() implementieren
 *  - in ReadStatus(): Commission- und Profit-Berechnung an Verwendung von OrderCloseBy() anpassen
 *  - in ReadStatus(): Breakeven-Berechnung implementieren
 *  - Breakeven-Anzeige (in ShowStatus()???)
 *  - StopLoss -> Breakeven und TakeProfit -> Breakeven implementieren
 *  - SMS-Benachrichtigungen implementieren
 *  - Heartbeat-Order einrichten
 *  - Equity-Chart der laufenden Sequenz implementieren
 *  - ShowStatus() übersichtlicher gestalten (mit Textlabeln statt Comment()-Funktion)
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
extern double Lotsize.Level.1                = 0.5;
extern double Lotsize.Level.2                = 0.6;
extern double Lotsize.Level.3                = 2.2;
extern double Lotsize.Level.4                = 2.6;
extern double Lotsize.Level.5                = 3.2;
extern double Lotsize.Level.6                = 3.8;
extern double Lotsize.Level.7                = 4.6;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int EA.uniqueId = 101;                          // eindeutige ID der Strategie (10 Bits: Bereich 0-1023)


double   Pip;
int      PipDigits;
string   PriceFormat;

int      Entry.iDirection = OP_UNDEFINED;       // -1
int      Entry.LimitType  = OP_UNDEFINED;
double   Entry.LastPrice;

int      sequenceId;
int      sequenceLength;
int      progressionLevel;

int      levels.ticket    [];
int      levels.type      [];
double   levels.openPrice [];
double   levels.lotsize   [];
double   levels.swap      [], all.swaps;
double   levels.commission[], all.commissions;
double   levels.profit    [], all.profits;
datetime levels.closeTime [];                   // Unterscheidung zwischen offenen und geschlossenen Positionen

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
         case 'L': Entry.Direction = "long";  Entry.iDirection = OP_BUY;  break;
         case 'S': Entry.Direction = "short"; Entry.iDirection = OP_SELL; break;
         default:
            return(catch("init(2)  Invalid input parameter Entry.Direction = \""+ Entry.Direction +"\"", ERR_INVALID_INPUT_PARAMVALUE));
      }

      // Entry.Limit
      if (LT(Entry.Limit, 0))
         return(catch("init(3)  Invalid input parameter Entry.Limit = "+ NumberToStr(Entry.Limit, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
      if (GT(Entry.Limit, 0)) {
         if (Entry.iDirection == OP_BUY) Entry.LimitType = ifInt(LT(Entry.Limit, Ask), OP_BUYLIMIT , OP_BUYSTOP );
         else                            Entry.LimitType = ifInt(GT(Entry.Limit, Bid), OP_SELLLIMIT, OP_SELLSTOP);
      }

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

               if (level & 1 == 1) Entry.iDirection = OrderType();
               else                Entry.iDirection = OrderType() ^ 1;  // 0=>1, 1=>0
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
   bool newSequence = false;
   if (sequenceId == 0) {
      sequenceId  = CreateSequenceId();
      newSequence = true;
      ArrayResize(levels.ticket    , sequenceLength);
      ArrayResize(levels.type      , sequenceLength);
      ArrayResize(levels.openPrice , sequenceLength);
      ArrayResize(levels.lotsize   , sequenceLength);
      ArrayResize(levels.swap      , sequenceLength);
      ArrayResize(levels.commission, sequenceLength);
      ArrayResize(levels.profit    , sequenceLength);
      ArrayResize(levels.closeTime , sequenceLength);
   }


   // (4) Konfiguration neuer Sequenzen speichern und existierender Sequenzen restaurieren
   if (newSequence || UninitializeReason()==REASON_PARAMETERS) {
      SaveConfiguration();
   }
   else if (UninitializeReason()!=REASON_CHARTCHANGE) {
      RestoreConfiguration();
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
   ShowStatus();


   // (6) bei Start ggf. EA's aktivieren
   int reasons1[] = { REASON_REMOVE, REASON_CHARTCLOSE, REASON_APPEXIT };
   if (!IsExpertEnabled()) /*&&*/ if (IntInArray(UninitializeReason(), reasons1))
      ToggleEAs(true);


   // (7) nach Start oder Reload nicht auf den ersten Tick warten
   int reasons2[] = { REASON_REMOVE, REASON_CHARTCLOSE, REASON_APPEXIT, REASON_PARAMETERS, REASON_RECOMPILE };
   if (IntInArray(UninitializeReason(), reasons2))
      SendTick(false);


   int error = GetLastError();
   if (error      != NO_ERROR) catch("init(15)", error);
   if (init_error != NO_ERROR) status = STATUS_DISABLED;
   return(init_error);
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


   if (ReadStatus()) {
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
            int error = GetLastError();
            if (error == NO_ERROR)
               error = ERR_INVALID_TICKET;
            status = STATUS_DISABLED;
            return(catch("ReadStatus(1)", error)==NO_ERROR);
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
   double price = ifDouble(Entry.iDirection==OP_SELL, Bid, Ask);     // Das Limit ist erreicht, wenn der Preis es seit dem letzten Tick berührt oder gekreuzt hat.

   if (EQ(price, Entry.Limit) || EQ(Entry.LastPrice, Entry.Limit)) { // Preis liegt oder lag beim letzten Tick exakt auf dem Limit
      debug("IsEntryLimitReached()   Tick="+ NumberToStr(price, PriceFormat) +" liegt genau auf dem Limit="+ NumberToStr(Entry.Limit, PriceFormat));
      Entry.LastPrice = Entry.Limit;                                 // Tritt während der weiteren Verarbeitung des Ticks ein behandelbarer Fehler auf, wird durch
      return(true);                                                  // Entry.LastPrice = Entry.Limit das Limit, einmal getriggert, nachfolgend immer wieder getriggert.
   }


   static bool lastPrice.init = false;

   if (EQ(Entry.LastPrice, 0)) {                                     // Entry.LastPrice muß initialisiert sein => ersten Aufruf überspringen und Status merken,
      lastPrice.init = true;                                         // um firstTick bei erstem tatsächlichen Test gegen Entry.LastPrice auf TRUE zurückzusetzen
   }
   else {
      if (LT(Entry.LastPrice, Entry.Limit)) {
         if (GT(price, Entry.Limit)) {                               // Tick hat Limit von unten nach oben gekreuzt
            debug("IsEntryLimitReached()   Tick hat Limit="+ NumberToStr(Entry.Limit, PriceFormat) +" von unten (lastPrice="+ NumberToStr(Entry.LastPrice, PriceFormat) +") nach oben (price="+ NumberToStr(price, PriceFormat) +") gekreuzt");
            Entry.LastPrice = Entry.Limit;
            return(true);
         }
      }
      else if (LT(price, Entry.Limit)) {                             // Tick hat Limit von oben nach unten gekreuzt
         debug("IsEntryLimitReached()   Tick hat Limit="+ NumberToStr(Entry.Limit, PriceFormat) +" von oben (lastPrice="+ NumberToStr(Entry.LastPrice, PriceFormat) +") nach unten (price="+ NumberToStr(price, PriceFormat) +") gekreuzt");
         Entry.LastPrice = Entry.Limit;
         return(true);
      }
      if (lastPrice.init) {
         lastPrice.init = false;
         firstTick      = true;                                      // firstTick nach erstem tatsächlichen Test gegen Entry.LastPrice auf TRUE zurückzusetzen
      }
   }
   Entry.LastPrice = price;

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
      int button = MessageBox(ifString(!IsDemo(), "Live Account\n\n", "") +"Do you really want to start a new trade sequence?", __SCRIPT__ +" - StartSequence", MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) {
         status = STATUS_DISABLED;
         return(catch("StartSequence(1)"));
      }
   }

   progressionLevel = 1;

   int ticket = OpenPosition(Entry.iDirection, CurrentLotSize());          // Position in Entry.Direction öffnen
   if (ticket == -1) {
      status = STATUS_DISABLED;
      return(catch("StartSequence(2)"));
   }

   // Sequenzdaten aktualisieren
   if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      int error = GetLastError();
      if (error == NO_ERROR)
         error = ERR_INVALID_TICKET;
      status = STATUS_DISABLED;
      return(catch("StartSequence(3)", error));
   }

   levels.ticket    [0] = OrderTicket();
   levels.type      [0] = OrderType();
   levels.openPrice [0] = OrderOpenPrice();
   levels.lotsize   [0] = OrderLots();
   levels.swap      [0] = 0;
   levels.commission[0] = 0;                                               // Werte werden in ReadStatus() ausgelesen
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
   if (firstTick) {                                                        // Sicherheitsabfrage, wenn der erste Tick sofort einen Trade triggert
      PlaySound("notify.wav");
      int button = MessageBox(ifString(!IsDemo(), "Live Account\n\n", "") +"Do you really want to increase the progression level?", __SCRIPT__ +" - IncreaseProgression", MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) {
         status = STATUS_DISABLED;
         return(catch("IncreaseProgression(1)"));
      }
   }

   int    last         = progressionLevel-1;
   double last.lotsize = levels.lotsize[last];
   int    new.type     = levels.type   [last] ^ 1;                         // 0=>1, 1=>0

   progressionLevel++;

   int ticket = OpenPosition(new.type, last.lotsize + CurrentLotSize());   // alte Position hedgen und nächste öffnen
   if (ticket == -1) {
      status = STATUS_DISABLED;
      return(catch("IncreaseProgression(2)"));
   }

   // Sequenzdaten aktualisieren
   if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      int error = GetLastError();
      if (error == NO_ERROR)
         error = ERR_INVALID_TICKET;
      status = STATUS_DISABLED;
      return(catch("IncreaseProgression(3)", error));
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

   return(catch("IncreaseProgression(4)"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int FinishSequence() {
   if (firstTick) {                                                        // Sicherheitsabfrage, wenn der erste Tick sofort einen Trade triggert
      PlaySound("notify.wav");
      int button = MessageBox(ifString(!IsDemo(), "Live Account\n\n", "") +"Do you really want to finish the sequence?", __SCRIPT__ +" - FinishSequence", MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) {
         status = STATUS_DISABLED;
         return(catch("FinishSequence(1)"));
      }
   }

   // TODO: OrderCloseBy() implementieren
   for (int i=0; i < sequenceLength; i++) {
      if (levels.ticket[i] > 0) /*&&*/ if (levels.closeTime[i] == 0) {
         if (!OrderCloseEx(levels.ticket[i], NULL, NULL, 1, Orange)) {
            status = STATUS_DISABLED;
            return(processLibError(stdlib_PeekLastError()));
         }
         if (!OrderSelect(levels.ticket[i], SELECT_BY_TICKET)) {
            int error = GetLastError();
            if (error == NO_ERROR)
               error = ERR_INVALID_TICKET;
            status = STATUS_DISABLED;
            return(catch("FinishSequence(2)", error));
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

   return(catch("FinishSequence(3)"));
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
      processLibError(stdlib_PeekLastError());

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
      case STATUS_INITIALIZED: msg = StringConcatenate(":  trade sequence ", sequenceId, " initialized");                                                                                            break;
      case STATUS_ENTRYLIMIT : msg = StringConcatenate(":  trade sequence ", sequenceId, " waiting for ", OperationTypeDescription(Entry.LimitType), " at ", NumberToStr(Entry.Limit, PriceFormat)); break;
      case STATUS_PROGRESSING: msg = StringConcatenate(":  trade sequence ", sequenceId, " progressing...");                                                                                         break;
      case STATUS_FINISHED:    msg = StringConcatenate(":  trade sequence ", sequenceId, " finished");                                                                                               break;
      case STATUS_DISABLED:    msg = StringConcatenate(":  trade sequence ", sequenceId, " disabled");
                               int error = ifInt(init, init_error, last_error);
                               if (error != NO_ERROR)
                                  msg = StringConcatenate(msg, "  [", ErrorDescription(error), "]");
                               break;
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
      case STATUS_INITIALIZED: return("STATUS_INITIALIZED");
      case STATUS_ENTRYLIMIT : return("STATUS_ENTRYLIMIT" );
      case STATUS_PROGRESSING: return("STATUS_PROGRESSING");
      case STATUS_FINISHED   : return("STATUS_FINISHED"   );
      case STATUS_DISABLED   : return("STATUS_DISABLED"   );
   }
   catch("StatusToStr()  invalid parameter status: "+ status, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt die lesbare Konstante eines Operation-Types zurück (überschreibt die Version in der Library)
 *
 * @param  int type - Operation-Type
 *
 * @return string
 */
string OperationTypeToStr(int type) {
   switch (type) {
      case OP_UNDEFINED: return("OP_UNDEFINED");
      case OP_BUY      : return("OP_BUY"      );
      case OP_SELL     : return("OP_SELL"     );
      case OP_BUYLIMIT : return("OP_BUYLIMIT" );
      case OP_SELLLIMIT: return("OP_SELLLIMIT");
      case OP_BUYSTOP  : return("OP_BUYSTOP"  );
      case OP_SELLSTOP : return("OP_SELLSTOP" );
      case OP_BALANCE  : return("OP_BALANCE"  );
      case OP_CREDIT   : return("OP_CREDIT"   );
   }
   catch("OperationTypeToStr()  invalid parameter type: "+ type, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
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
   //debug("SaveConfiguration()   saving configuration for sequence #"+ sequenceId);


   // (1) Daten zusammenstellen
   string lines[]; ArrayResize(lines, 0);
   string company = GetShortAccountCompany();
   ArrayPushString(lines, /*string*/ "AccountCompany="  +             company                 );
   ArrayPushString(lines, /*int   */ "AccountNumber="   +             AccountNumber()         );
   ArrayPushString(lines, /*string*/ "Symbol="          +             Symbol()                );
   // ------------------------------------------------------------------------------------------
   ArrayPushString(lines, /*int   */ "sequenceId="      +             sequenceId              );
   ArrayPushString(lines, /*string*/ "Entry.Direction=" +             Entry.Direction         );
   ArrayPushString(lines, /*double*/ "Entry.Limit="     + DoubleToStr(Entry.Limit, Digits)    );
   ArrayPushString(lines, /*int   */ "Entry.LimitType=" +             Entry.LimitType         );
   ArrayPushString(lines, /*int   */ "TakeProfit="      +             TakeProfit              );
   ArrayPushString(lines, /*int   */ "StopLoss="        +             StopLoss                );
   ArrayPushString(lines, /*double*/ "Lotsize.Level.1=" + NumberToStr(Lotsize.Level.1, ".+")  );
   ArrayPushString(lines, /*double*/ "Lotsize.Level.2=" + NumberToStr(Lotsize.Level.2, ".+")  );
   ArrayPushString(lines, /*double*/ "Lotsize.Level.3=" + NumberToStr(Lotsize.Level.3, ".+")  );
   ArrayPushString(lines, /*double*/ "Lotsize.Level.4=" + NumberToStr(Lotsize.Level.4, ".+")  );
   ArrayPushString(lines, /*double*/ "Lotsize.Level.5=" + NumberToStr(Lotsize.Level.5, ".+")  );
   ArrayPushString(lines, /*double*/ "Lotsize.Level.6=" + NumberToStr(Lotsize.Level.6, ".+")  );
   ArrayPushString(lines, /*double*/ "Lotsize.Level.7=" + NumberToStr(Lotsize.Level.7, ".+")  );


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
   error = UploadConfiguration(company, AccountNumber(), Symbol(), filename);
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
   string url          = "http://sub.domain.tld/uploadFTPConfiguration.php?company="+ UrlEncode(company) +"&account=account&symbol="+ UrlEncode(symbol) +"&name="+ UrlEncode(parts[size-1]);
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
   if (sequenceId == 0) {
      status = STATUS_DISABLED;
      return(catch("RestoreConfiguration(1)   illegal value of sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR));
   }

   // (1) bei nicht existierender lokaler Konfiguration die Datei vom Server laden
   string filesDir = TerminalPath() +"\\experts\\files\\";
   string fileName = "presets\\FTP."+ sequenceId +".set";

   if (!IsFile(filesDir + fileName)) {
      string url        = "http://sub.domain.tld/getFTPConfiguration.php?sequenceId="+ sequenceId;
      string targetFile = filesDir +"\\"+ fileName;
      string logFile    = filesDir +"\\"+ fileName +".log";
      string cmdLine    = "wget.exe \""+ url +"\" -O \""+ targetFile +"\" -o \""+ logFile +"\"";

      debug("RestoreConfiguration()   downloading configuration for sequence #"+ sequenceId);

      int error = WinExecAndWait(cmdLine, SW_HIDE);      // SW_SHOWNORMAL|SW_HIDE
      if (error != NO_ERROR) {
         status = STATUS_DISABLED;
         return(processLibError(error));
      }
   }

   // (2) Datei einlesen
   debug("RestoreConfiguration()   restoring configuration for sequence #"+ sequenceId);
   string config[];
   int lines = FileReadLines(fileName, config, true);
   if (lines <= 0) {
      status = STATUS_DISABLED;
      if (lines == 0) {
         FileDelete(fileName);
         return(catch("RestoreConfiguration(2)   no configuration found for sequence #"+ sequenceId, ERR_RUNTIME_ERROR));
      }
      return(processLibError(stdlib_PeekLastError()));
   }

   // (3) Zeilen in Schlüssel-Wert-Paare aufbrechen, Daten valideren und übernehmen
   int parameters[13]; ArrayInitialize(parameters, 0);
   int I_SEQUENCEID      =  0;
   int I_ENTRY_DIRECTION =  1;
   int I_ENTRY_LIMIT     =  2;
   int I_ENTRY_LIMITTYPE =  3;
   int I_TAKEPROFIT      =  4;
   int I_STOPLOSS        =  5;
   int I_LOTSIZE_LEVEL_1 =  6;
   int I_LOTSIZE_LEVEL_2 =  7;
   int I_LOTSIZE_LEVEL_3 =  8;
   int I_LOTSIZE_LEVEL_4 =  9;
   int I_LOTSIZE_LEVEL_5 = 10;
   int I_LOTSIZE_LEVEL_6 = 11;
   int I_LOTSIZE_LEVEL_7 = 12;

   string parts[];
   for (int i=0; i < lines; i++) {
      if (Explode(config[i], "=", parts, 2) != 2) {
         status = STATUS_DISABLED;
         return(catch("RestoreConfiguration(3)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR));
      }
      string key=parts[0], value=parts[1];

      if (key == "sequenceId") {
         if (!StringIsDigit(value) || StrToInteger(value)!=sequenceId)   { status = STATUS_DISABLED; return(catch("RestoreConfiguration(4)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)); }
         parameters[I_SEQUENCEID] = 1;
      }
      else if (key == "Entry.Direction") {
         if (value!="long" && value!="short")                            { status = STATUS_DISABLED; return(catch("RestoreConfiguration(5)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)); }
         Entry.Direction  = value;
         Entry.iDirection = ifInt(Entry.Direction=="long", OP_BUY, OP_SELL);
         parameters[I_ENTRY_DIRECTION] = 1;
      }
      else if (key == "Entry.Limit") {
         double dValue = StrToDouble(value);
         if (!StringIsNumeric(value) || LT(dValue, 0))                   { status = STATUS_DISABLED; return(catch("RestoreConfiguration(6)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)); }
         Entry.Limit = dValue;
         parameters[I_ENTRY_LIMIT] = 1;
      }
      else if (key == "Entry.LimitType") {
         int iValue       = StrToInteger(value);
         int validTypes[] = {OP_UNDEFINED, OP_BUYLIMIT, OP_SELLLIMIT, OP_BUYSTOP, OP_SELLSTOP};
         if (!StringIsInteger(value) || !IntInArray(iValue, validTypes)) { status = STATUS_DISABLED; return(catch("RestoreConfiguration(7)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)); }
         Entry.LimitType = iValue;
         parameters[I_ENTRY_LIMITTYPE] = 1;
      }
      else if (key == "TakeProfit") {
         iValue = StrToInteger(value);
         if (!StringIsDigit(value) || iValue==0)                         { status = STATUS_DISABLED; return(catch("RestoreConfiguration(8)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)); }
         TakeProfit = iValue;
         parameters[I_TAKEPROFIT] = 1;
      }
      else if (key == "StopLoss") {
         iValue = StrToInteger(value);
         if (!StringIsDigit(value) || iValue==0)                         { status = STATUS_DISABLED; return(catch("RestoreConfiguration(9)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)); }
         StopLoss = iValue;
         parameters[I_STOPLOSS] = 1;
      }
      else if (key == "Lotsize.Level.1") {
         dValue = StrToDouble(value);
         if (!StringIsNumeric(value) || LE(dValue, 0))                   { status = STATUS_DISABLED; return(catch("RestoreConfiguration(10)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)); }
         Lotsize.Level.1 = dValue;
         parameters[I_LOTSIZE_LEVEL_1] = 1;
      }
      else if (key == "Lotsize.Level.2") {
         dValue = StrToDouble(value);
         if (!StringIsNumeric(value) || LE(dValue, 0))                   { status = STATUS_DISABLED; return(catch("RestoreConfiguration(11)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)); }
         Lotsize.Level.2 = dValue;
         parameters[I_LOTSIZE_LEVEL_2] = 1;
      }
      else if (key == "Lotsize.Level.3") {
         dValue = StrToDouble(value);
         if (!StringIsNumeric(value) || LE(dValue, 0))                   { status = STATUS_DISABLED; return(catch("RestoreConfiguration(12)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)); }
         Lotsize.Level.3 = dValue;
         parameters[I_LOTSIZE_LEVEL_3] = 1;
      }
      else if (key == "Lotsize.Level.4") {
         dValue = StrToDouble(value);
         if (!StringIsNumeric(value) || LE(dValue, 0))                   { status = STATUS_DISABLED; return(catch("RestoreConfiguration(13)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)); }
         Lotsize.Level.4 = dValue;
         parameters[I_LOTSIZE_LEVEL_4] = 1;
      }
      else if (key == "Lotsize.Level.5") {
         dValue = StrToDouble(value);
         if (!StringIsNumeric(value) || LE(dValue, 0))                   { status = STATUS_DISABLED; return(catch("RestoreConfiguration(14)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)); }
         Lotsize.Level.5 = dValue;
         parameters[I_LOTSIZE_LEVEL_5] = 1;
      }
      else if (key == "Lotsize.Level.6") {
         dValue = StrToDouble(value);
         if (!StringIsNumeric(value) || LE(dValue, 0))                   { status = STATUS_DISABLED; return(catch("RestoreConfiguration(15)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)); }
         Lotsize.Level.6 = dValue;
         parameters[I_LOTSIZE_LEVEL_6] = 1;
      }
      else if (key == "Lotsize.Level.7") {
         dValue = StrToDouble(value);
         if (!StringIsNumeric(value) || LE(dValue, 0))                   { status = STATUS_DISABLED; return(catch("RestoreConfiguration(16)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)); }
         Lotsize.Level.7 = dValue;
         parameters[I_LOTSIZE_LEVEL_7] = 1;
      }
   }

   if ((Entry.LimitType==OP_UNDEFINED && NE(Entry.Limit, 0)) || (Entry.LimitType!=OP_UNDEFINED && EQ(Entry.Limit, 0))) {
      status = STATUS_DISABLED;
      return(catch("RestoreConfiguration(17)   invalid configuration file \""+ fileName +"\" (Entry.Limit="+ NumberToStr(Entry.Limit, ".+") +" doesn't match Entry.LimitType="+ OperationTypeToStr(Entry.LimitType) +")", ERR_RUNTIME_ERROR));
   }
   if (IntInArray(0, parameters)) {
      status = STATUS_DISABLED;
      return(catch("RestoreConfiguration(18)   one or more configuration values missing in file \""+ fileName +"\"", ERR_RUNTIME_ERROR));
   }


   error = GetLastError();
   if (error != NO_ERROR) {
      status = STATUS_DISABLED;
      catch("RestoreConfiguration(19)", error);
   }
   return(error);
}
