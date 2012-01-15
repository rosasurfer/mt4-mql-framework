/**
 * FXTradePro Martingale EA
 *
 * @see FXTradePro strategy:     http://www.forexfactory.com/showthread.php?t=43221
 *      FXTradePro journal:      http://www.forexfactory.com/showthread.php?t=82544
 *      FXTradePro swing trades: http://www.forexfactory.com/showthread.php?t=87564
 *
 *      PowerSM EA:              http://www.forexfactory.com/showthread.php?t=75394
 *      PowerSM journal:         http://www.forexfactory.com/showthread.php?t=159789
 *
 * ---------------------------------------------------------------------------------
 *
 *  Probleme:
 *  ---------
 *  - Verhältnis Spread/StopLoss: hohe Spreads machen den Einsatz teilweise unmöglich
 *  - Verhältnis Tagesvolatilität/Spread: teilweise wurde innerhalb von 10 Sekunden der nächste Level getriggert
 *  - gleiche Volatilität bedeutet gleicher StopLoss, unabhängig vom variablen Spread
 *
 *
 *  Voraussetzungen für Produktivbetrieb:
 *  -------------------------------------
 *  - Testbarkeit
 *  - parallele Verwaltung mehrerer Instanzen ermöglichen (ständige sich überschneidende Instanzen)
 *  - Breakeven berechnen und anzeigen
 *  - Sequenzlänge veränderbar machen und 7/7-Sequenz implementieren
 *  - für alle Signalberechnungen MedianPrice vom ursprünglichen Signal verwenden (die tatsächlich erzielten Entry-Preise und Slippage sind sekundär)
 *  - Hedges müssen sofort aufgelöst werden (MT4-Equity- und -Marginberechnung mit offenen Hedges ist fehlerhaft)
 *  - ggf. muß statt nach STATUS_DISABLED nach STATUS_MONITORING gewechselt werden
 *  - Sicherheitsabfrage, wenn nach Änderung von TakeProfit sofort FinishSequence() getriggert wird
 *  - Sicherheitsabfrage, wenn nach Änderung der Konfiguration sofort Trade getriggert wird
 *  - bei STATUS_DISABLED muß ein REASON_RECOMPILE sich den alten Status merken
 *  - Heartbeat-Order einrichten
 *  - Heartbeat-Order muß signalisieren, wenn die Konfiguration sich geändert hat => erneuter Download vom Server
 *  - OrderMultiClose.Flatten() muß prüfen, ob das Hedge-Volumen mit MarketInfo(MODE_MINLOT) kollidiert
 *  - Visualisierung des Entry.Limits implementieren
 *  - gesamte Sequenz vorher auf [TradeserverLimits] prüfen
 *  - einzelne Tradefunktionen vorher auf [TradeserverLimits] prüfen lassen
 *  - mehrere EA's schalten sich gegenseitig ab, wenn sie ohne Lock SwitchExperts(true) aufrufen
 *
 *
 *  TODO:
 *  -----
 *  - Input-Parameter müssen änderbar sein, ohne den EA anzuhalten
 *  - NumberToStr() reparieren: positives Vorzeichen, 1000-Trennzeichen
 *  - EA muß automatisch in beliebige Templates hineingeladen werden können
 *  - die Konfiguration einer gefundenen Sequenz muß automatisch in den Input-Dialog geladen werden
 *  - UpdateProfitLoss(): Commission-Berechnung an OrderCloseBy() anpassen
 *  - Symbolwechsel (REASON_CHARTCHANGE) und Accountwechsel (REASON_ACCOUNT) abfangen
 *  - Spreadänderungen bei Limit-Checks berücksichtigen
 *  - StopLoss -> Breakeven und TakeProfit -> Breakeven implementieren
 *  - SMS-Benachrichtigungen implementieren
 *  - Equity-Chart der laufenden Sequenz implementieren
 *  - ShowStatus() übersichtlicher gestalten (Textlabel statt Comment())
 */
#include <stdlib.mqh>
#include <win32api.mqh>


#define STATUS_WAITING                   0            // mögliche Sequenzstatus-Werte
#define STATUS_PROGRESSING               1
#define STATUS_FINISHED                  2
#define STATUS_DISABLED                  3

#define ENTRYTYPE_UNDEFINED              0
#define ENTRYTYPE_LIMIT                  1
#define ENTRYTYPE_BANDS                  2
#define ENTRYTYPE_ENVELOPES              3

#define ENTRYDIRECTION_UNDEFINED        -1
#define ENTRYDIRECTION_LONG        OP_LONG            // 0
#define ENTRYDIRECTION_SHORT      OP_SHORT            // 1
#define ENTRYDIRECTION_LONGSHORT         2


int Strategy.Id = 101;                                // eindeutige ID der Strategie (Bereich 101-1023)


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string _1____________________________ = "==== Entry Options ===================";
extern string Entry.Condition                = "BollingerBands(35xM15, EMA, 2.0)";        // {LimitValue} | [Bollinger]Bands(35xM5,EMA,2.0) | Env[elopes](75xM15,ALMA,2.0)
extern string Entry.Direction                = "";                                        // long | short

extern string _2____________________________ = "==== TP and SL Settings ==============";
extern int    TakeProfit                     = 50;
extern int    StopLoss                       = 12;

extern string _3____________________________ = "==== Lotsizes =======================";
extern double Lotsize.Level.1                = 0.1;
extern double Lotsize.Level.2                = 0.2;
extern double Lotsize.Level.3                = 0.3;
extern double Lotsize.Level.4                = 0.4;
extern double Lotsize.Level.5                = 0.5;
extern double Lotsize.Level.6                = 0.6;
extern double Lotsize.Level.7                = 0.7;

extern string _4____________________________ = "==== Sequence to Manage =============";
extern string Sequence.ID                    = "";

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string   intern.Entry.Condition;                         // Werden die Input-Parameter aus einer Preset-Datei geladen, werden sie bei REASON_CHARTCHANGE
string   intern.Entry.Direction;                         // mit den obigen Default-Werten überschrieben. Um dies zu verhindern, werden sie in deinit()
int      intern.TakeProfit;                              // in intern.* zwischengespeichert und in init() wieder daraus restauriert.
int      intern.StopLoss;
double   intern.Lotsize.Level.1;
double   intern.Lotsize.Level.2;
double   intern.Lotsize.Level.3;
double   intern.Lotsize.Level.4;
double   intern.Lotsize.Level.5;
double   intern.Lotsize.Level.6;
double   intern.Lotsize.Level.7;
string   intern.Sequence.ID;

int      Entry.type        = ENTRYTYPE_UNDEFINED;
int      Entry.iDirection  = ENTRYDIRECTION_UNDEFINED;
int      Entry.MA.periods,   Entry.MA.periods.orig;      // *.orig: Werte vor Umrechnung nach M5
int      Entry.MA.timeframe, Entry.MA.timeframe.orig;
int      Entry.MA.method;
double   Entry.MA.deviation;
double   Entry.limit;
double   Entry.lastBid;

int      sequenceId;
int      sequenceLength;
int      sequenceStatus    = STATUS_WAITING;
int      progressionLevel;

double   levels.lots[];                                  // Lotsizes der Konfiguration
string   str.levels.lots;                                // (string) levels.lots, für ShowStatus()

int      levels.ticket    [];
int      levels.type      [];
double   levels.openLots  [];                            // offene Orderlotsize des Levels (Erläuterungen bei ReadSequence())
datetime levels.openTime  [];
double   levels.openPrice [];
datetime levels.closeTime [];
double   levels.closePrice[];

double   levels.swap      [], levels.openSwap      [], levels.closedSwap      [];   // Werte des einzelnen Levels
double   levels.commission[], levels.openCommission[], levels.closedCommission[];
double   levels.profit    [], levels.openProfit    [], levels.closedProfit    [];

double   levels.sumProfit  [];                           // Gesamtprofit aller Level
double   levels.maxProfit  [];                           // maximal möglicher P/L
double   levels.maxDrawdown[];                           // maximal möglicher Drawdown
double   levels.breakeven  [];                           // Breakeven in ???

double   all.swaps;
double   all.commissions;
double   all.profits;

bool     firstTick = true;

double   TickSize;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   if (IsError(onInit(T_EXPERT)))
      return(ShowStatus());

   TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);

   int error = GetLastError();
   if (IsError(error) || TickSize < 0.00000001) {
      catch("init(1)   TickSize = "+ NumberToStr(TickSize, ".+"), ifInt(IsError(error), error, ERR_INVALID_MARKETINFO));
      return(ShowStatus());
   }

   /*
   Zuerst wird die aktuelle Sequenz-ID bestimmt, dann deren Konfiguration geladen und validiert. Zum Schluß werden die Daten der ggf. laufenden Sequenz restauriert.
   Es gibt 4 unterschiedliche init()-Szenarien:

   (1.1) Neustart des EA, evt. im Tester (keine internen Daten, externe Sequenz-ID evt. vorhanden)
   (1.2) Recompilation                   (keine internen Daten, externe Sequenz-ID immer vorhanden)
   (1.3) Parameteränderung               (alle internen Daten vorhanden, externe Sequenz-ID unnötig)
   (1.4) Timeframe-Wechsel               (alle internen Daten vorhanden, externe Sequenz-ID unnötig)
   */

   // (1) Sind keine internen Daten vorhanden, befinden wir uns in Szenario 1.1 oder 1.2.
   if (sequenceId == 0) {

      // (1.1) Neustart ---------------------------------------------------------------------------------------------------------------------------------------
      if (UninitializeReason() != REASON_RECOMPILE) {
         if (IsInputSequenceId()) {                                  // Zuerst eine ausdrücklich angegebene Sequenz-ID restaurieren...
            if (RestoreInputSequenceId())
               if (RestoreConfiguration())
                  if (ValidateConfiguration())
                     ReadSequence();
         }
         else if (RestoreChartSequenceId()) {                        // ...dann ggf. eine im Chart gespeicherte Sequenz-ID restaurieren...
            if (RestoreConfiguration())
               if (ValidateConfiguration())
                  ReadSequence();
         }
         else if (RestoreRunningSequenceId()) {                      // ...dann ID aus laufender Sequenz restaurieren.
            if (RestoreConfiguration())
               if (ValidateConfiguration())
                  ReadSequence();
         }
         else if (ValidateConfiguration()) {
            sequenceId = CreateSequenceId();                         // Zum Schluß neue Sequenz anlegen.
            if (Entry.type!=ENTRYTYPE_LIMIT || NE(Entry.limit, 0))   // Bei ENTRYTYPE_LIMIT und Entry.Limit=0 erfolgt sofortiger Einstieg, in diesem Fall
               SaveConfiguration();                                  // wird die Konfiguration erst nach Sicherheitsabfrage in StartSequence() gespeichert.
            ResizeArrays(sequenceLength);
            UpdateMaxProfitLoss();
            VisualizeSequence();
         }
      }

      // (1.2) Recompilation ----------------------------------------------------------------------------------------------------------------------------------
      else if (RestoreChartSequenceId()) {                           // externe Referenz immer vorhanden: restaurieren und validieren
         if (RestoreConfiguration())
            if (ValidateConfiguration())
               ReadSequence();
      }
      else catch("init(2)   REASON_RECOMPILE, no stored sequence id found in chart", ERR_RUNTIME_ERROR);
   }

   // (1.3) Parameteränderung ---------------------------------------------------------------------------------------------------------------------------------
   else if (UninitializeReason() == REASON_PARAMETERS) {             // Alle internen Daten sind vorhanden.
      if (ValidateConfiguration()) {
         SaveConfiguration();

         // TODO: die manuelle Sequence.ID kann geändert worden sein

         UpdateBreakeven();                                          // nur zwingend nötig, wenn die Lotsizes geändert wurden
         UpdateMaxProfitLoss();                                      // nur zwingend nötig, wenn die Limits oder die Lotsizes geändert wurden
         VisualizeSequence();
      }
   }

   // (1.4) Timeframewechsel ----------------------------------------------------------------------------------------------------------------------------------
   else if (UninitializeReason() == REASON_CHARTCHANGE) {
      Entry.Condition = intern.Entry.Condition;                      // Alle internen Daten sind vorhanden, es werden nur die nicht-statischen
      Entry.Direction = intern.Entry.Direction;                      // Inputvariablen restauriert.
      TakeProfit      = intern.TakeProfit;
      StopLoss        = intern.StopLoss;
      Lotsize.Level.1 = intern.Lotsize.Level.1;
      Lotsize.Level.2 = intern.Lotsize.Level.2;
      Lotsize.Level.3 = intern.Lotsize.Level.3;
      Lotsize.Level.4 = intern.Lotsize.Level.4;
      Lotsize.Level.5 = intern.Lotsize.Level.5;
      Lotsize.Level.6 = intern.Lotsize.Level.6;
      Lotsize.Level.7 = intern.Lotsize.Level.7;
      Sequence.ID     = intern.Sequence.ID;
   }

   // ---------------------------------------------------------------------------------------------------------------------------------------------------------
   else catch("init(3)   unknown init() scenario", ERR_RUNTIME_ERROR);


   // (2) Status anzeigen
   ShowStatus();
   if (IsLastError())
      return(last_error);


   // (3) ggf. EA's aktivieren
   int reasons1[] = { REASON_REMOVE, REASON_CHARTCLOSE, REASON_APPEXIT };
   if (IntInArray(UninitializeReason(), reasons1)) /*&&*/ if (!IsExpertEnabled())
      SwitchExperts(true);                                        // TODO: Bug, wenn mehrere EA's den EA-Modus gleichzeitig einschalten


   // (4) nach Reload nicht auf den nächsten Tick warten (nur bei REASON_CHARTCHANGE oder REASON_ACCOUNT)
   int reasons2[] = { REASON_REMOVE, REASON_CHARTCLOSE, REASON_APPEXIT, REASON_PARAMETERS, REASON_RECOMPILE };
   if (IntInArray(UninitializeReason(), reasons2)) /*&&*/ if (!IsTesting())
      SendTick(false);

   return(catch("init(4)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   if (UninitializeReason() == REASON_CHARTCHANGE) {
      // Input-Parameter sind nicht statisch: für's nächste init() intern.* speichern
      intern.Entry.Condition = Entry.Condition;
      intern.Entry.Direction = Entry.Direction;
      intern.TakeProfit      = TakeProfit;
      intern.StopLoss        = StopLoss;
      intern.Lotsize.Level.1 = Lotsize.Level.1;
      intern.Lotsize.Level.2 = Lotsize.Level.2;
      intern.Lotsize.Level.3 = Lotsize.Level.3;
      intern.Lotsize.Level.4 = Lotsize.Level.4;
      intern.Lotsize.Level.5 = Lotsize.Level.5;
      intern.Lotsize.Level.6 = Lotsize.Level.6;
      intern.Lotsize.Level.7 = Lotsize.Level.7;
      intern.Sequence.ID     = Sequence.ID;
   }
   else {
      // aktuelle Sequenze-ID im Chart speichern
      StoreChartSequenceId();
   }
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (sequenceStatus==STATUS_FINISHED || sequenceStatus==STATUS_DISABLED)
      return(last_error);


   // Sequenzdaten prüfen und aktualisieren
   bool success;
   if (!CheckOpenPositions()) success = ReadSequence();              // offene Positionen haben sich geändert => Sequenz neu einlesen
   else                       success = UpdateProfitLoss();          // nur P/L aktualisieren (für Breakeven-Handler)


   // Handelslogik ausführen
   if (success) {
      if (progressionLevel == 0) {
         if (IsEntrySignal())                   StartSequence();     // kein Limit definiert oder Limit erreicht
      }
      else if (IsStopLossReached()) {
         if (progressionLevel < sequenceLength) IncreaseProgression();
         else                                   FinishSequence();
      }
      else if (IsProfitTargetReached())         FinishSequence();
   }
   firstTick = false;


   // Status anzeigen
   ShowStatus();

   if (IsLastError())
      return(last_error);
   return(catch("onTick()"));
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
      if (OrderMagicNumber() >> 22 == Strategy.Id) {
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
 * @return int - Sequenz-ID im Bereich 1000-16383 (14 bit)
 */
int CreateSequenceId() {
   MathSrand(GetTickCount());
   int id;
   while (id < 2000) {                                               // Das abschließende Shiften halbiert den Wert und wir wollen mindestens eine 4-stellige ID haben.
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

   int ea       = Strategy.Id & 0x3FF << 22;                         // 10 bit (Bits größer 10 löschen und auf 32 Bit erweitern) | in MagicNumber: Bits 23-32
   int sequence = sequenceId & 0x3FFF << 8;                          // 14 bit (Bits größer 14 löschen und auf 22 Bit erweitern  | in MagicNumber: Bits  9-22
   int length   = sequenceLength & 0xF << 4;                         //  4 bit (Bits größer 4 löschen und auf 8 bit erweitern)   | in MagicNumber: Bits  5-8
   int level    = progressionLevel & 0xF;                            //  4 bit (Bits größer 4 löschen)                           | in MagicNumber: Bits  1-4

   return(ea + sequence + length + level);
}


#include <bollingerbandCrossing.mqh>


/**
 * Signalgeber für StartSequence(). Wurde ein Limit von 0 angegeben, gibt die Funktion TRUE zurück und die neue Sequenz wird mit dem
 * nächsten Tick gestartet.
 *
 * @return bool - ob die konfigurierte Entry.Condition erfüllt ist
 */
bool IsEntrySignal() {
   double event[3];
   int    crossing;

   switch (Entry.type) {
      // ---------------------------------------------------------------------------------------------------------------------------------
      // Das Limit ist erreicht, wenn der Bid-Preis es seit dem letzten Tick berührt oder gekreuzt hat.
      case ENTRYTYPE_LIMIT:
         if (EQ(Entry.limit, 0))                                        // kein Limit definiert => immer TRUE
            return(true);

         if (EQ(Bid, Entry.limit) || EQ(Entry.lastBid, Entry.limit)) {  // Bid liegt oder lag beim letzten Tick exakt auf dem Limit
            //debug(StringConcatenate("IsEntrySignal()   Bid=", NumberToStr(Bid, PriceFormat), " liegt genau auf dem Entry.limit=", NumberToStr(Entry.limit, PriceFormat)));
            Entry.lastBid = Entry.limit;                                // Tritt während der weiteren Verarbeitung des Ticks ein behandelbarer Fehler auf, wird durch
            return(true);                                               // Entry.lastPrice = Entry.limit das Limit, einmal getriggert, nachfolgend immer wieder getriggert.
         }

         static bool lastBid.init = false;

         if (EQ(Entry.lastBid, 0)) {                                    // Entry.lastBid muß initialisiert sein => ersten Aufruf überspringen und Status merken,
            lastBid.init = true;                                        // um firstTick bei erstem tatsächlichen Test gegen Entry.lastBid auf TRUE zurückzusetzen
         }
         else {
            if (LT(Entry.lastBid, Entry.limit)) {
               if (GT(Bid, Entry.limit)) {                              // Bid hat Limit von unten nach oben gekreuzt
                  Entry.lastBid = Entry.limit;
                  return(true);
               }
            }
            else if (LT(Bid, Entry.limit)) {                            // Bid hat Limit von oben nach unten gekreuzt
               Entry.lastBid = Entry.limit;
               return(true);
            }
            if (lastBid.init) {
               lastBid.init = false;
               firstTick    = true;                                     // firstTick nach erstem tatsächlichen Test gegen Entry.lastBid auf TRUE zurückzusetzen
            }
         }
         Entry.lastBid = Bid;
         return(false);

      // ---------------------------------------------------------------------------------------------------------------------------------
      case ENTRYTYPE_BANDS:                                             // EventListener aufrufen und ggf. Event signalisieren
         if (EventListener.BandsCrossing(Entry.MA.periods, Entry.MA.timeframe, Entry.MA.method, Entry.MA.deviation, event, DeepSkyBlue)) {
            crossing         = event[CROSSING_TYPE] +0.1;               // (int) double
            Entry.limit      = ifDouble(crossing==CROSSING_LOW, event[CROSSING_LOW_VALUE], event[CROSSING_HIGH_VALUE]);
            Entry.iDirection = ifInt(crossing==CROSSING_LOW, OP_SELL, OP_BUY);
            return(true);
         }
         else {
            crossing = event[CROSSING_TYPE] +0.1;                       // (int) double
            if (crossing == CROSSING_UNKNOWN) {
               Entry.limit      = 0;
               Entry.iDirection = ENTRYDIRECTION_UNDEFINED;
            }
            else {
               Entry.limit      = ifDouble(crossing==CROSSING_LOW, event[CROSSING_HIGH_VALUE], event[CROSSING_LOW_VALUE]);
               Entry.iDirection = ifInt(crossing==CROSSING_LOW, OP_BUY, OP_SELL);
            }
         }
         return(false);

      // ---------------------------------------------------------------------------------------------------------------------------------
      case ENTRYTYPE_ENVELOPES:                                         // EventListener aufrufen und ggf. Event signalisieren
         if (EventListener.EnvelopesCrossing(Entry.MA.periods, Entry.MA.timeframe, Entry.MA.method, Entry.MA.deviation, event, DeepSkyBlue)) {
            crossing         = event[CROSSING_TYPE] +0.1;               // (int) double
            Entry.limit      = ifDouble(crossing==CROSSING_LOW, event[CROSSING_LOW_VALUE], event[CROSSING_HIGH_VALUE]);
            Entry.iDirection = ifInt(crossing==CROSSING_LOW, OP_SELL, OP_BUY);
            return(true);
         }
         else {
            crossing = event[CROSSING_TYPE] +0.1;                       // (int) double
            if (crossing == CROSSING_UNKNOWN) {
               Entry.limit      = 0;
               Entry.iDirection = ENTRYDIRECTION_UNDEFINED;
            }
            else {
               Entry.limit      = ifDouble(crossing==CROSSING_LOW, event[CROSSING_HIGH_VALUE], event[CROSSING_LOW_VALUE]);
               Entry.iDirection = ifInt(crossing==CROSSING_LOW, OP_BUY, OP_SELL);
            }
         }
         return(false);

      // ---------------------------------------------------------------------------------------------------------------------------------
      default:
         return(_false(catch("IsEntrySignal()   illegal Entry.type = "+ Entry.type, ERR_RUNTIME_ERROR)));
   }
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
      //debug(StringConcatenate("IsStopLossReached()   Stoploss für ", last.directions[last.type], " position erreicht: ", DoubleToStr(last.loss/Pip, Digits-PipDigits), " pip (openPrice=", NumberToStr(last.openPrice, PriceFormat), ", ", last.priceNames[last.type], "=", NumberToStr(last.price, PriceFormat), ")"));
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
      //debug(StringConcatenate("IsProfitTargetReached()   Profit target für ", last.directions[last.type], " position erreicht: ", DoubleToStr(last.profit/Pip, Digits-PipDigits), " pip (openPrice=", NumberToStr(last.openPrice, PriceFormat), ", ", last.priceNames[last.type], "=", NumberToStr(last.price, PriceFormat), ")"));
      return(true);
   }
   return(false);
}


/**
 * Restauriert die Sequenz-ID einer laufenden Sequenz.
 *
 * @return bool - ob eine laufende Sequenz gefunden und die ID restauriert wurde
 */
bool RestoreRunningSequenceId() {
   // offene Positionen einlesen
   for (int i=OrdersTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wird in einem anderen Thread eine offene Order entfernt
         continue;

      if (IsMyOrder()) {
         sequenceId = OrderMagicNumber() >> 8 & 0x3FFF;              // 14 Bits (Bits 9-22) => sequenceId
         catch("RestoreRunningSequenceId(1)");
         return(true);
      }
   }

   catch("RestoreRunningSequenceId(2)");
   return(false);
}


/**
 * Liest die aktuelle Sequenz komplett neu ein. Die Konfiguration der Sequenz ist beim Aufruf immer gültig,
 * die Variablen sequenceId, sequenceLength und levels.lots[] können also benutzt werden.
 *
 * @return bool - Erfolgsstatus
 */
bool ReadSequence() {
   /*
   Nicht alle Sequenzdaten können beim Einlesen exakt restauriert werden, für einen einwandfreien Ablauf sind sie auch nicht zwingend notwendig.

   Die P/L-Daten von geschlossenen Positionen werden beim Einlesen je nach Hedge-Reihenfolge auf andere Level verteilt. Die Daten in den einzelnen Leveln
   stimmen daher nicht mit den tatsächlichen Werten überein, ihre Summe entspricht jedoch der korrekten Gesamtsumme des letzten Levels und der gesamten Sequenz.

   int      levels.ticket    [];
   int      levels.type      [];
   double   levels.openLots  [];    // nur die aktuell *offene* Lotsize des Levels (nicht nötig für geschlossene Positionen)
   datetime levels.openTime  [];
   double   levels.openPrice [];
   datetime levels.closeTime [];    // 0, solange es offene (Teil-)Positionen in diesem Level gibt
   double   levels.closePrice[];    // für Anzeige des Sequenzendes (nicht nötig für die einzelnen Positionen)

   double   levels.swap      [];    // Summe aus Werten der offenen und geschlossenen Positionen
   double   levels.commission[];
   double   levels.profit    [];

   double   levels.sumProfit  [];   // Gesamtprofit der Sequenz zum jeweiligen Zeitpunkt
   double   levels.maxProfit  [];   // maximal möglicher P/L
   double   levels.maxDrawdown[];   // maximal möglicher Drawdown
   double   levels.breakeven  [];   // Breakeven in ???
   */

   // (1) Arrays zurücksetzen
   if (ArraySize(levels.ticket) > 0)
      ResizeArrays(0);
   ResizeArrays(sequenceLength);


   // (2) Offene Positionen einlesen. Je Level kann es höchstens eine offene Position geben.
   progressionLevel = 0;
   bool   openPositions = false;
   double effectiveLots;

   for (int i=OrdersTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))                  // FALSE: während des Auslesens wird woanders eine offene Order entfernt
         continue;

      if (IsMyOrder(sequenceId)) {
         if (OrderType() > OP_SELL)                                     // Nicht-Positionen überspringen
            continue;
         openPositions = true;

         int level = OrderMagicNumber() & 0xF;                          //  4 Bits (Bits 1-4)  => progressionLevel
         if (level > sequenceLength) return(_false(catch("ReadSequence(1)   illegal sequence state, progression level "+ level +" of ticket #"+ OrderTicket() +" exceeds the value of sequenceLength = "+ sequenceLength, ERR_RUNTIME_ERROR)));

         if (level > progressionLevel)
            progressionLevel = level;

         int n = level-1;
         levels.ticket        [n] = OrderTicket();
         levels.type          [n] = OrderType();
         levels.openLots      [n] = OrderLots();
         levels.openTime      [n] = OrderOpenTime();
         levels.openPrice     [n] = OrderOpenPrice();
         levels.openSwap      [n] = OrderSwap();
         levels.openCommission[n] = OrderCommission();
         levels.openProfit    [n] = OrderProfit();

         if (OrderType() == OP_BUY) effectiveLots += OrderLots();       // tatsächliche aktuelle Lotsize ermitteln
         else                       effectiveLots -= OrderLots();
      }
   }


   // (3) Geschlossene Positionen einlesen.
   bool retry = true;

   while (retry) {                                                      // Endlosschleife, bis ausreichend History-Daten verfügbar sind oder manuell abgebrochen wird
      retry = false;
      int closedTickets = OrdersHistoryTotal();

      // (3.1) Alle Daten zwischenspeichern, da wir zur Zuordnung von Hedges über die Positionen iterieren können müssen.
      int      hist.tickets     []; ArrayResize(hist.tickets     , closedTickets);
      int      hist.types       []; ArrayResize(hist.types       , closedTickets);
      double   hist.lots        []; ArrayResize(hist.lots        , closedTickets);
      datetime hist.openTimes   []; ArrayResize(hist.openTimes   , closedTickets);
      double   hist.openPrices  []; ArrayResize(hist.openPrices  , closedTickets);
      datetime hist.closeTimes  []; ArrayResize(hist.closeTimes  , closedTickets);
      double   hist.closePrices []; ArrayResize(hist.closePrices , closedTickets);
      double   hist.swaps       []; ArrayResize(hist.swaps       , closedTickets);
      double   hist.commissions []; ArrayResize(hist.commissions , closedTickets);
      double   hist.profits     []; ArrayResize(hist.profits     , closedTickets);
      int      hist.magicNumbers[]; ArrayResize(hist.magicNumbers, closedTickets);
      string   hist.comments    []; ArrayResize(hist.comments    , closedTickets);
      int      closeTrades      []; ArrayResize(closeTrades, 0);        // Index-Zwischenspeicher für Teilpositionen des Schlußtrades

      for (i=0, n=0; i < closedTickets; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))              // FALSE: während des Auslesens wird der Anzeigezeitraum der History verändert
            break;
         if (OrderType() > OP_SELL || OrderSymbol()!=Symbol())          // Nicht-Trades und Einträge anderer Symbole überspringen
            continue;
         hist.tickets     [n] = OrderTicket();
         hist.types       [n] = OrderType();
         hist.lots        [n] = OrderLots();
         hist.openTimes   [n] = OrderOpenTime();
         hist.openPrices  [n] = OrderOpenPrice();
         hist.closeTimes  [n] = OrderCloseTime();
         hist.closePrices [n] = OrderClosePrice();
         hist.swaps       [n] = OrderSwap();
         hist.commissions [n] = OrderCommission();
         hist.profits     [n] = OrderProfit();
         hist.magicNumbers[n] = ifInt(IsMyOrder(sequenceId), OrderMagicNumber(), 0);   // MagicNumber unterscheidet die eigenen von fremden Positionen bzw. von Schlußtrade(s)
         hist.comments    [n] = OrderComment();
         n++;
      }
      if (n < closedTickets) {
         ArrayResize(hist.tickets     , n);
         ArrayResize(hist.types       , n);
         ArrayResize(hist.lots        , n);
         ArrayResize(hist.openTimes   , n);
         ArrayResize(hist.openPrices  , n);
         ArrayResize(hist.closeTimes  , n);
         ArrayResize(hist.closePrices , n);
         ArrayResize(hist.swaps       , n);
         ArrayResize(hist.commissions , n);
         ArrayResize(hist.profits     , n);
         ArrayResize(hist.magicNumbers, n);
         ArrayResize(hist.comments    , n);
         closedTickets = n;
      }


      // TODO:   Es reicht nicht, auf lots = 0.0 zu prüfen. Der fremde Trade kann auf lots=0.0 stehen. In diesem Fall sollte der Comment des Sequenztrades
      //         auf "partial close" stehen, doch MetaTrader modifiziert den Comment bei manuellem MultipleCloseBy() teilweise nicht (z.B. FTP.5347 in GBP/USD
      //         am 22.09.2011 in Alpari {account-no}).
      // Lösung: Über alle fremden Trades iterieren und auf Referenzen auf die Sequenz prüfen.


      // (3.2) Sequenztrades auf Cross-Referenzen auf Schlußtrades durchsuchen und Schlußtrades zwischenspeichern
      string splitPrefix = ifString(IsTesting(), "split from #", "from #");
      int splitPrefixLen = StringLen(splitPrefix);                      // OrderComment()-Prefix für Restpositionen
      int referenceTicket;

      for (i=0; i < closedTickets; i++) {
         if (hist.magicNumbers[i] == 0)
            continue;                                                   // fremde Position, die evt. Teil des Schlußtrades ist, werden in (6) analysiert
         referenceTicket = 0;

         if (EQ(hist.lots[i], 0.0)) {                                   // Hedge-Position
            if (!StringIStartsWith(hist.comments[i], "close hedge by #"))
               return(_false(catch("ReadSequence(2)  ticket #"+ hist.tickets[i] +": unknown comment for assumed hedging position = \""+ hist.comments[i] +"\"", ERR_RUNTIME_ERROR)));
            referenceTicket = StrToInteger(StringSubstr(hist.comments[i], 16));
         }
         else if (StringIStartsWith(hist.comments[i], splitPrefix)) {   // Restposition
            referenceTicket = StrToInteger(StringSubstr(hist.comments[i], splitPrefixLen));
         }
         if (referenceTicket != 0) {
            if (hist.tickets[i] == referenceTicket)
               return(_false(catch("ReadSequence(3)  comment of #"+ hist.tickets[i] +" is pointing to itself (comment=\""+ hist.comments[i] +"\")", ERR_RUNTIME_ERROR)));

            // Gegenstück suchen
            n = ArraySearchInt(referenceTicket, hist.tickets);
            if (n == -1) return(_false(catch("ReadSequence(4)  cannot find counterpart for #"+ hist.tickets[i] +" (comment=\""+ hist.comments[i] +"\")", ERR_RUNTIME_ERROR)));
            if (hist.magicNumbers[n] == 0)
               ArrayPushInt(closeTrades, n);                            // Schlußtrade, Zeiger auf Schlußposition zwischenspeichern
         }

         debug("ReadSequence()   #"+ StringRightPad(hist.tickets[i], 8, " ") +"   "+ StringRightPad("FTP."+ sequenceId +"."+ (hist.magicNumbers[i]&0xF), 11, " ") +"   "+ TimeToStr(hist.openTimes[i], TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"   "+ NumberToStr(hist.openPrices[i], PriceFormat) +"   "+ StringRightPad(OperationTypeDescription(hist.types[i]), 4, " ") +"   "+ StringRightPad(NumberToStr(hist.lots[i], ".+"), 4, " ") +"   "+ TimeToStr(hist.closeTimes[i], TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"   "+ NumberToStr(hist.closePrices[i], PriceFormat) +"   "+ ifString(hist.comments[i]=="", "", StringConcatenate("\"", hist.comments[i], "\"")));
         if (!ReadSequence.AddClosedPosition(hist.magicNumbers[i], hist.tickets[i], hist.types[i], hist.openTimes[i], hist.openPrices[i], hist.swaps[i], hist.commissions[i], hist.profits[i], hist.comments[i]))
            return(false);
      }


      // (4) falls kein Ticket existiert, anhand der Konfigurationsdatei prüfen, ob der EA im STATUS_WAITING läuft
      if (progressionLevel == 0) {
         if (IsFile(TerminalPath() +"\\experts\\presets\\FTP."+ sequenceId +".set")) {
            sequenceStatus = STATUS_WAITING;
            if (UpdateMaxProfitLoss() && VisualizeSequence())        // im STATUS_WAITING sind Profit/Loss und Breakeven 0.00 und brauchen nicht berechnet werden
               return(IsNoError(catch("ReadSequence(5)")));          // regular exit for progressionLevel = 0
            return(false);
         }

         ForceSound("notify.wav");
         int button = ForceMessageBox("No tickets found for sequence "+ sequenceId +".\nMore history data needed?", __SCRIPT__ +" - ReadSequence()", MB_ICONEXCLAMATION|MB_RETRYCANCEL);
         if (button == IDRETRY) {
            retry = true;
            continue;
         }
         SetLastError(ERR_CANCELLED_BY_USER);
         catch("ReadSequence(6)");
         return(false);
      }


      // (5) Tickets auf Vollständigkeit prüfen
      for (i=0; i < progressionLevel; i++) {
         if (levels.ticket[i] == 0) {
            ForceSound("notify.wav");
            button = ForceMessageBox("Ticket for progression level "+ (i+1) +" not found.\nMore history data needed.", __SCRIPT__ +" - ReadSequence()", MB_ICONEXCLAMATION|MB_RETRYCANCEL);
            if (button == IDRETRY) {
               retry = true;
               break;
            }
            SetLastError(ERR_CANCELLED_BY_USER);
            catch("ReadSequence(7)");
            return(false);
         }
      }


      // (6) Erst jetzt, nach (5), Nicht-Sequenztrades auf Cross-Referenzen zur Sequenz durchsuchen und weitere Schlußtrades ermitteln
      for (i=0; i < closedTickets; i++) {
         if (hist.magicNumbers[i] != 0)
            continue;                                                   // Sequenztrade, wurde bereits in (3.2) analysiert
         referenceTicket = 0;

         if (EQ(hist.lots[i], 0.0)) {                                   // Hedge-Position
            if (!StringIStartsWith(hist.comments[i], "close hedge by #"))
               return(_false(catch("ReadSequence(8)  ticket #"+ hist.tickets[i] +": unknown comment for assumed hedging position = \""+ hist.comments[i] +"\"", ERR_RUNTIME_ERROR)));
            referenceTicket = StrToInteger(StringSubstr(hist.comments[i], 16));
         }
         else if (StringIStartsWith(hist.comments[i], splitPrefix)) {   // Restposition
            referenceTicket = StrToInteger(StringSubstr(hist.comments[i], splitPrefixLen));
         }
         if (referenceTicket != 0) {
            if (hist.tickets[i] == referenceTicket)
               return(_false(catch("ReadSequence(9)  comment of #"+ hist.tickets[i] +" is pointing to itself (comment=\""+ hist.comments[i] +"\")", ERR_RUNTIME_ERROR)));

            // Gegenstück suchen
            n = ArraySearchInt(referenceTicket, hist.tickets);
            if (n == -1)
               continue;

            if (hist.magicNumbers[n]!=0) /*&&*/ if (!IntInArray(i, closeTrades))
               ArrayPushInt(closeTrades, i);                            // referenceTicket gehört zur Sequenz, i ist also Schlußtrade
         }                                                              // Zeiger auf Schlußposition zwischenspeichern
      }


      // (7) CloseTime und ClosePrice aktualisieren (nicht zwingend notwendig, vereinfacht jedoch spätere P/L-Berechnungen)
      for (i=1; i < progressionLevel; i++) {
         if (levels.closeTime[i-1] != 0)                                // closeTime nur überschreiben, wenn es im Level keine offene Position mehr gibt
            levels.closeTime [i-1] = levels.openTime [i];
         levels.closePrice[i-1] = levels.openPrice[i];
      }


      // (8) Status setzen
      sequenceStatus = ifInt(openPositions, STATUS_PROGRESSING, STATUS_FINISHED);


      // (9) Schlußtrade(s) analysieren
      //
      // Der Schlußtrade bestimmt CloseTime und ClosePrice des letzten Levels und der Sequenz. Der Trade kann aus einer oder mehreren Positionen bestehen. Je nachdem,
      // in welcher Reihenfolge eine Schlußposition gegen die Positionen der Sequenz geschlossen wurde, kann in der History auch ein einzelner Schlußtrade in mehrere
      // Teilpositionen aufgebrochen worden sein. Der Schlußzeitpunkt der Sequenz ist der Moment, an dem die gesamte offene Position zum ersten Mal gehedgt war.
      if (sequenceStatus == STATUS_FINISHED) {
         int size = ArraySize(closeTrades);
         if (size == 0) return(_false(catch("ReadSequence(10)   illegal sequence state, no close trades found for finished sequence", ERR_RUNTIME_ERROR)));

         datetime lastOpenTime, lastCloseTime;
         double   lastOpenPrice, lastClosePrice;
         int      last = progressionLevel-1;

         for (i=0; i < size; i++) {
            debug("ReadSequence()   #"+ StringRightPad(hist.tickets[i], 8, " ") +"   - close -     "+ TimeToStr(hist.openTimes[i], TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"   "+ NumberToStr(hist.openPrices[i], PriceFormat) +"   "+ StringRightPad(OperationTypeDescription(hist.types[i]), 4, " ") +"   "+ StringRightPad(NumberToStr(hist.lots[i], ".+"), 4, " ") +"   "+ TimeToStr(hist.closeTimes[i], TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"   "+ NumberToStr(hist.closePrices[i], PriceFormat) +"   "+ ifString(hist.comments[i]=="", "", StringConcatenate("\"", hist.comments[i], "\"")));
            if (hist.openTimes[closeTrades[i]] > lastOpenTime) {
               lastOpenTime  = hist.openTimes [closeTrades[i]];
               lastOpenPrice = hist.openPrices[closeTrades[i]];
            }
            if (hist.closeTimes[closeTrades[i]] > lastCloseTime) {
               lastCloseTime  = hist.closeTimes [closeTrades[i]];
               lastClosePrice = hist.closePrices[closeTrades[i]];
            }
            levels.closedSwap      [last] += hist.swaps      [closeTrades[i]];   // vorhandene Beträge aufaddieren
            levels.closedCommission[last] += hist.commissions[closeTrades[i]];
            levels.closedProfit    [last] += hist.profits    [closeTrades[i]];
         }

         if (lastOpenTime > levels.openTime[last]) {                             // wenn mindestens ein Schlußtrade nach Eröffnung des letzten Levels initiiert wurde
            levels.closeTime[last] = lastOpenTime;  levels.closePrice[last] = lastOpenPrice;
         }
         else {
            levels.closeTime[last] = lastCloseTime; levels.closePrice[last] = lastClosePrice;
         }
      }
   }


   // (10) Sequenz mit Konfiguration abgleichen
   if (sequenceStatus == STATUS_PROGRESSING) {
      last = progressionLevel-1;
      if (NE(MathAbs(effectiveLots), levels.lots[last]))
         return(_false(catch("ReadSequence(11)   illegal sequence state, current effective lot size ("+ NumberToStr(effectiveLots, ".+") +" lots) doesn't match the configured level "+ progressionLevel +" lot size ("+ NumberToStr(levels.lots[last], ".+") +" lots)", ERR_RUNTIME_ERROR)));
   }


   // (11) P/L und Breakeven neuberechnen und Sequenz visualisieren
   if (!UpdateProfitLoss()   ) return(false);
   if (!UpdateBreakeven()    ) return(false);
   if (!UpdateMaxProfitLoss()) return(false);
   if (!VisualizeSequence()  ) return(false);

   return(IsNoError(catch("ReadSequence(12)")));
}


/**
 *
 * @return bool - Erfolgsstatus
 */
bool ReadSequence.AddClosedPosition(int magicNumber, int ticket, int type, datetime openTime, double openPrice, double swap, double commission, double profit, string comment) {
   int level = magicNumber & 0xF;                                       // 4 Bits (Bits 1-4) => progressionLevel
   if (level > sequenceLength) return(_false(catch("ReadSequence.AddClosedPosition(1)   illegal sequence state, progression level "+ level +" of ticket #"+ ticket +" exceeds the value of sequenceLength = "+ sequenceLength, ERR_RUNTIME_ERROR)));

   if (level > progressionLevel)
      progressionLevel = level;

   level--;
   if (levels.ticket[level] == 0) {                                     // unbelegter Level
      levels.ticket   [level] = ticket;
      levels.type     [level] = type;
      levels.openTime [level] = openTime;                               // levels.openLots[] wird für geschlossene Positionen nicht benötigt
      levels.openPrice[level] = openPrice;
      levels.closeTime[level] = 1;                                      // closeTime *muß* hier ungleich 0 sein (0=offene Position), wird in der Folge entsprechend korrigiert
   }
   else {                                                               // bereits belegter Level
      if (   levels.type     [level]!=type      ) return(_false(catch("ReadSequence.AddClosedPosition(2)  illegal sequence state, trade direction \""+ OperationTypeDescription(levels.type[level]) +"\" of occupied level "+ (level+1) +" doesn't match \""+ OperationTypeDescription(type) +"\" of closed #"+ ticket, ERR_RUNTIME_ERROR)));
      if (NE(levels.openPrice[level], openPrice)) return(_false(catch("ReadSequence.AddClosedPosition(4)  illegal sequence state, open price "+ NumberToStr(levels.openPrice[level], PriceFormat) +" of occupied level "+ (level+1) +" doesn't match open price "+ NumberToStr(openPrice, PriceFormat) +" of closed #"+ ticket, ERR_RUNTIME_ERROR)));
      if (   levels.openTime [level]!=openTime  )
         if (!IsTesting())                                              // Tester-Bug (kann vorerst nur hier ignoriert werden)
            return(_false(catch("ReadSequence.AddClosedPosition(3)  illegal sequence state, open time \""+ TimeToStr(levels.openTime[level], TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"\" of occupied level "+ (level+1) +" doesn't match open time \""+ TimeToStr(openTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"\" of closed #"+ ticket, ERR_RUNTIME_ERROR)));
   }
   levels.closedSwap      [level] += swap;                              // vorhandene Beträge aufaddieren
   levels.closedCommission[level] += commission;
   levels.closedProfit    [level] += profit;

   return(IsNoError(catch("ReadSequence.AddClosedPosition(5)")));
}


/**
 * Beginnt eine neue Trade-Sequenz (Progression-Level 1).
 *
 * @return bool - Erfolgsstatus
 */
bool StartSequence() {
   if (firstTick) {                                                  // Sicherheitsabfrage, wenn der erste Tick sofort einen Trade triggert
      ForceSound("notify.wav");
      int button = ForceMessageBox(ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to start a new trade sequence now?", __SCRIPT__ +" - StartSequence()", MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) {
         SetLastError(ERR_CANCELLED_BY_USER);
         catch("StartSequence(1)");
         return(false);
      }
      SaveConfiguration();                                           // bei firstTick=TRUE Konfiguration nach Bestätigung speichern
   }

   progressionLevel = 1;

   int ticket = OpenPosition(Entry.iDirection, levels.lots[0]);      // Position in Entry.Direction öffnen
   if (ticket == -1) {
      progressionLevel--;
      return(IsNoError(catch("StartSequence(2)")));
   }

   // Sequenzdaten aktualisieren
   if (!OrderSelectByTicket(ticket)) {
      progressionLevel--;
      return(last_error);
   }

   levels.ticket   [0] = OrderTicket();
   levels.type     [0] = OrderType();
   levels.openLots [0] = OrderLots();
   levels.openTime [0] = OrderOpenTime();
   levels.openPrice[0] = OrderOpenPrice();

   // Sequenz neu einlesen
   if (!ReadSequence())
      return(false);

   return(IsNoError(catch("StartSequence(3)")));
}


/**
 * Wechselt in den nächsten Level.
 *
 * @return bool - Erfolgsstatus
 */
bool IncreaseProgression() {
   if (firstTick) {                                                        // Sicherheitsabfrage, wenn der erste Tick sofort einen Trade triggert
      ForceSound("notify.wav");
      int button = ForceMessageBox(ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to increase the progression level now?", __SCRIPT__ +" - IncreaseProgression()", MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) {
         SetLastError(ERR_CANCELLED_BY_USER);
         catch("IncreaseProgression(1)");
         return(false);
      }
   }

   int    last      = progressionLevel-1;
   double last.lots = levels.lots[last];
   int    new.type  = levels.type[last] ^ 1;                               // 0=>1, 1=>0

   progressionLevel++;

   int ticket = OpenPosition(new.type, last.lots + levels.lots[last+1]);   // nächste Position öffnen und alte dabei hedgen
   if (ticket == -1) {
      progressionLevel--;
      catch("IncreaseProgression(2)");
      return(false);
   }

   // Sequenzdaten aktualisieren
   if (!OrderSelectByTicket(ticket)) {
      progressionLevel--;
      return(false);
   }

   int this = progressionLevel-1;
   levels.ticket   [this] = OrderTicket();
   levels.type     [this] = OrderType();
   levels.openLots [this] = OrderLots();
   levels.openTime [this] = OrderOpenTime();
   levels.openPrice[this] = OrderOpenPrice();

   // Sequenz neu einlesen
   if (!ReadSequence())
      return(false);

   return(IsNoError(catch("IncreaseProgression(3)")));
}


/**
 * Schließt alle offenen Positionen der aktuellen Sequenz.
 *
 * @return bool - Erfolgsstatus
 */
bool FinishSequence() {
   if (firstTick) {                                                  // Sicherheitsabfrage, wenn der erste Tick sofort einen Trade triggert
      ForceSound("notify.wav");
      int button = ForceMessageBox(ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to finish the sequence now?", __SCRIPT__ +" - FinishSequence()", MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) {
         SetLastError(ERR_CANCELLED_BY_USER);
         catch("FinishSequence(1)");
         return(false);
      }
   }

   // zu schließende Tickets ermitteln
   int tickets[]; ArrayResize(tickets, 0);

   for (int i=0; i < sequenceLength; i++) {
      if (levels.ticket[i] > 0) /*&&*/ if (levels.closeTime[i] == 0)
         ArrayPushInt(tickets, levels.ticket[i]);
   }

   // Tickets schließen
   if (!OrderMultiClose(tickets, 0.5, CLR_NONE)) {
      SetLastError(stdlib_PeekLastError());
      catch("FinishSequence(2)");
      return(false);
   }

   // Sequenz neu einlesen
   if (!ReadSequence())
      return(false);

   return(IsNoError(catch("FinishSequence(3)")));
}


/**
 * Öffnet eine neue Position in angegebener Richtung und Größe.
 *
 * @param  int    type    - Ordertyp: OP_BUY | OP_SELL
 * @param  double lotsize - Lotsize der Order
 *
 * @return int - Ticket der neuen Position oder -1, falls ein Fehler auftrat
 */
int OpenPosition(int type, double lotsize) {
   if (type!=OP_BUY && type!=OP_SELL) {
      catch("OpenPosition(1)   illegal parameter type: "+ type, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   if (LE(lotsize, 0)) {
      catch("OpenPosition(2)   illegal parameter lotsize: "+ NumberToStr(lotsize, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }

   int    magicNumber = CreateMagicNumber();
   string comment     = "FTP."+ sequenceId +"."+ progressionLevel;
   double slippage    = 0.5;

   int ticket = OrderSendEx(Symbol(), type, lotsize, NULL, slippage, NULL, NULL, comment, magicNumber, NULL, CLR_NONE);
   if (ticket == -1)
      SetLastError(stdlib_PeekLastError());

   if (IsError(catch("OpenPosition(3)")))
      return(-1);
   return(ticket);
}


/**
 * Überprüft die offenen Positionen der Sequenz auf Übereinstimmung mit den im EA gespeicherten Daten.
 *
 * @return bool - TRUE, wenn die gespeicherten Daten mit den offenen Positionen übereinstimmen,
 *                FALSE andererseits
 */
bool CheckOpenPositions() {
   for (int i=0; i < progressionLevel; i++) {
      if (levels.closeTime[i] == 0) {                                // Ticket prüfen, wenn es beim letzten Aufruf noch offen war
         if (!OrderSelectByTicket(levels.ticket[i]))
            return(false);

         if (OrderCloseTime() != 0)                                  // Ticket wurde geschlossen
            return(false);

         if (NE(OrderLots(), levels.openLots[i]))                    // Ticket wurde teilweise geschlossen
            return(false);

         if (NE(OrderSwap(), levels.openSwap[i]))                    // Swap-Betrag hat sich geändert => Wert kann hier aktualisiert werden
            levels.openSwap[i] = OrderSwap();
      }
   }
   return(true);
}


/**
 * Berechnet den aktuellen P/L der Sequenz neu.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateProfitLoss() {
   // (1) aktuellen TickValue für P/L-Berechnung bestimmen           !!! TODO: wenn QuoteCurrency == AccountCurrency, ist dies nur ein statt jedes Mal notwendig
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   int error = GetLastError();
   if (IsError(error) || tickValue < 0.1)                            // ERR_INVALID_MARKETINFO abfangen
      return(_false(catch("UpdateProfitLoss(1)   TickValue = "+ NumberToStr(tickValue, ".+"), ifInt(IsError(error), error, ERR_INVALID_MARKETINFO))));


   // (2) Profit/Loss der Level mit offenen Positionen neu berechnen
   all.swaps       = 0;
   all.commissions = 0;
   all.profits     = 0;

   double priceDiff, tmp.openLots[];
   ArrayResize(tmp.openLots, 0);
   ArrayCopy(tmp.openLots, levels.openLots);

   for (int i=0; i < progressionLevel; i++) {
      if (levels.closeTime[i] == 0) {
         if (!OrderSelectByTicket(levels.ticket[i]))
            return(false);
         levels.openProfit[i] = 0;

         if (GT(tmp.openLots[i], 0)) {                               // P/L offener Hedges verrechnen
            for (int n=i+1; n < progressionLevel; n++) {
               if (levels.closeTime[n]==0) /*&&*/ if (levels.type[i]!=levels.type[n]) /*&&*/ if (GT(tmp.openLots[n], 0)) { // offener und verrechenbarer Hedge
                  priceDiff = ifDouble(levels.type[i]==OP_BUY, levels.openPrice[n]-levels.openPrice[i], levels.openPrice[i]-levels.openPrice[n]);

                  if (LE(tmp.openLots[i], tmp.openLots[n])) {
                     levels.openProfit[i] += priceDiff / TickSize * tickValue * tmp.openLots[i];
                     tmp.openLots     [n] -= tmp.openLots[i];
                     tmp.openLots     [i]  = 0;
                     break;
                  }
                  else /*(tmp.openLots[i] > tmp.openLots[n])*/ {
                     levels.openProfit[i] += priceDiff / TickSize * tickValue * tmp.openLots[n];
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

   return(IsNoError(catch("UpdateProfitLoss(2)")));
}


/**
 * Aktualisiert den Breakeven-Point (in Pip und als absoluten Kurswert). Die Berechnung benötigt einen korrekten P/L-Wert (erfordert
 * vorheriges UpdateProfitLoss() und erfolgt je einmal nach Wechsel auf den nächsten Level oder nach Neueinlesen der Sequenz.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateBreakeven() {
   double breakeven;

   if (progressionLevel > 0) {
      int last = progressionLevel-1;
      double pipValue = GetPipValue();
      if (EQ(pipValue, 0))
         return(false);

      double profitLoss     = all.swaps + all.commissions + all.profits;
      double profitLossPips = profitLoss / pipValue;

      //debug("UpdateBreakeven()   profitLoss="+ DoubleToStr(profitLoss, 2) +"   profitLossPips="+ NumberToStr(profitLossPips, ".1+"));
   }

   return(IsNoError(catch("UpdateBreakeven()")));
}


/**
 * Gibt den PipValue der angegebenen Lotsize im aktuellen Instrument zurück (mit Fehlerkontrolle).
 *
 * @param  double lots - Lotsize
 *
 * @return double - PipValue oder 0, wenn ein Fehler auftrat
 */
double GetPipValue(double lots = 1.0) {
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);          // !!! TODO: wenn QuoteCurrency == AccountCurrency, ist dies nur ein einziges Mal notwendig

   int error = GetLastError();
   if (IsError(error) || tickValue < 0.1)                            // ERR_INVALID_MARKETINFO abfangen
      return(_false(catch("GetPipValue()   TickValue = "+ NumberToStr(tickValue, ".+"), ifInt(IsError(error), error, ERR_INVALID_MARKETINFO))));

   return(Pip / TickSize * tickValue * lots);
}


/**
 * Aktualisiert die maximal erreichbaren P/L-Werte der einzelnen Level. Wird nur einmal nach Wechsel auf den jeweils nächsten Level ausgeführt.
 * Erfordert in einer laufenden Sequenz die vorherige Ausführung von UpdateProfitLoss().
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateMaxProfitLoss() {
   // aktuellen PipValue bestimmen                                   !!! TODO: wenn QuoteCurrency == AccountCurrency, ist dies nur ein einziges Mal notwendig
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   int error = GetLastError();
   if (IsError(error) || tickValue < 0.1)                            // ERR_INVALID_MARKETINFO abfangen
      return(_false(catch("UpdateMaxProfitLoss(1)   TickValue = "+ NumberToStr(tickValue, ".+"), ifInt(IsError(error), error, ERR_INVALID_MARKETINFO))));
   double pipValue = Pip / TickSize * tickValue;

   // maximale P/L-Werte neu berechnen
   double drawdown, prevDrawdown;                                    // Drawdown in Pips

   for (int i=0; i < sequenceLength; i++) {
      if (i >= progressionLevel-1)       drawdown = StopLoss;                                               // aktueller und folgende Level: konfigurierten StopLoss verwenden
      else if (levels.type[i] == OP_BUY) drawdown = (levels.openPrice[i  ] - levels.openPrice[i+1]) / Pip;  // vorherige Level: tatsächlichen Drawdown verwenden
      else                               drawdown = (levels.openPrice[i+1] - levels.openPrice[i  ]) / Pip;

      // TODO: der tatsächliche Drawdown ist die Summe von Drawdown + Swaps + Commissions

      levels.maxDrawdown[i] = prevDrawdown - levels.lots[i] * drawdown   * pipValue;
      levels.maxProfit  [i] = prevDrawdown + levels.lots[i] * TakeProfit * pipValue;
      prevDrawdown          = levels.maxDrawdown[i];
   }

   return(IsNoError(catch("UpdateMaxProfitLoss(2)")));
}


/**
 * Setzt die Größe der internen Arrays auf den angegebenen Wert.
 *
 * @param  int size - neue Größe
 *
 * @return void
 */
void ResizeArrays(int size) {
   // alle Arrays außer levels.lots[]: enthält Konfiguration und wird nur in ValidateConfiguration() modifiziert

   ArrayResize(levels.ticket          , size);
   ArrayResize(levels.type            , size); if (size > 0) ArrayInitialize(levels.type, OP_UNDEFINED);
   ArrayResize(levels.openLots        , size);
   ArrayResize(levels.openTime        , size);
   ArrayResize(levels.openPrice       , size);
   ArrayResize(levels.closeTime       , size);
   ArrayResize(levels.closePrice      , size);

   ArrayResize(levels.swap            , size);
   ArrayResize(levels.commission      , size);
   ArrayResize(levels.profit          , size);

   ArrayResize(levels.openSwap        , size);
   ArrayResize(levels.openCommission  , size);
   ArrayResize(levels.openProfit      , size);

   ArrayResize(levels.closedSwap      , size);
   ArrayResize(levels.closedCommission, size);
   ArrayResize(levels.closedProfit    , size);

   ArrayResize(levels.sumProfit       , size);
   ArrayResize(levels.maxProfit       , size);
   ArrayResize(levels.maxDrawdown     , size);
   ArrayResize(levels.breakeven       , size);
}


/**
 * Visualisiert die Sequenz.
 *
 * @return bool - Erfolgsstatus
 */
bool VisualizeSequence() {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return(true);

   string arrow, line;

   for (int i=0; i < progressionLevel; i++) {
      int type = levels.type[i];

      // Positionsmarker
      arrow = "FTP."+ sequenceId +"."+ (i+1) +"   "+ ifString(type==OP_BUY, "Buy", "Sell") +" "+ NumberToStr(levels.lots[i], ".+") +" lot at "+ NumberToStr(levels.openPrice[i], PriceFormat);
      if (ObjectFind(arrow) > -1)
         ObjectDelete(arrow);
      if (ObjectCreate(arrow, OBJ_ARROW, 0, levels.openTime[i], levels.openPrice[i])) {
         ObjectSet(arrow, OBJPROP_ARROWCODE, 1);
         ObjectSet(arrow, OBJPROP_COLOR, ifInt(type==OP_BUY, Blue, Red));
      }
      else GetLastError();

      // Verbinder zum vorherigen Level
      if (i > 0) {
         line = "FTP."+ sequenceId +"."+ i +" > "+ (i+1);
         if (ObjectFind(line) > -1)
            ObjectDelete(line);
         if (ObjectCreate(line, OBJ_TREND, 0, levels.openTime[i-1], levels.openPrice[i-1], levels.openTime[i], levels.openPrice[i])) {
            ObjectSet(line, OBJPROP_COLOR, ifInt(type==OP_SELL, Blue, Red));
            ObjectSet(line, OBJPROP_RAY,   false);
            ObjectSet(line, OBJPROP_STYLE, STYLE_DOT);
         }
         else GetLastError();
      }
   }

   // Sequenzende
   if (sequenceStatus == STATUS_FINISHED) {
      // Verbinder zum Sequenzende
      line = "FTP."+ sequenceId +"."+ progressionLevel;
      if (ObjectFind(line) > -1)
         ObjectDelete(line);
      if (ObjectCreate(line, OBJ_TREND, 0, levels.openTime[i-1], levels.openPrice[i-1], levels.closeTime[i-1], levels.closePrice[i-1])) {
         ObjectSet(line, OBJPROP_COLOR, ifInt(levels.type[i-1]==OP_BUY, Blue, Red));
         ObjectSet(line, OBJPROP_RAY,   false);
         ObjectSet(line, OBJPROP_STYLE, STYLE_DOT);
      }
      else GetLastError();

      // letzter Marker
      arrow = "FTP."+ sequenceId +"."+ progressionLevel +"   Sequence finished at "+ NumberToStr(levels.closePrice[i-1], PriceFormat);
      if (ObjectFind(arrow) > -1)
         ObjectDelete(arrow);
      if (ObjectCreate(arrow, OBJ_ARROW, 0, levels.closeTime[i-1], levels.closePrice[i-1])) {
         ObjectSet(arrow, OBJPROP_ARROWCODE, 3);
         ObjectSet(arrow, OBJPROP_COLOR, Orange);
      }
      else GetLastError();
   }

   return(IsNoError(catch("VisualizeSequence()")));
}


/**
 * Zeigt den aktuellen Status der Sequenz an.
 *
 * @return int - Fehlerstatus
 */
int ShowStatus() {
   if (IsTesting() && !IsVisualMode())
      return(last_error);

   int error = last_error;                                           // bei Funktionseintritt bereits existierenden Fehler zwischenspeichern
   if (IsLastError())
      sequenceStatus = STATUS_DISABLED;

   string msg = "";
   switch (sequenceStatus) {
      case STATUS_WAITING:     if (Entry.type == ENTRYTYPE_LIMIT) {                   msg = StringConcatenate(":  sequence ", sequenceId, " waiting to ", OperationTypeDescription(Entry.iDirection));
                                  if (NE(Entry.limit, 0))                             msg = StringConcatenate(msg, " at ", NumberToStr(Entry.limit, PriceFormat)); }
                               else if (Entry.iDirection == ENTRYDIRECTION_UNDEFINED) msg = StringConcatenate(":  sequence ", sequenceId, " waiting for next ", Entry.Condition, " crossing");
                               else                                                   msg = StringConcatenate(":  sequence ", sequenceId, " waiting for ", Entry.Condition, ifString(Entry.iDirection==OP_BUY, " high", " low"), " crossing to ", OperationTypeDescription(Entry.iDirection), ":  ", NumberToStr(Entry.limit, PriceFormat));
                               break;
      case STATUS_PROGRESSING: msg = StringConcatenate(":  sequence ", sequenceId, " progressing..."); break;
      case STATUS_FINISHED:    msg = StringConcatenate(":  sequence ", sequenceId, " finished");       break;
      case STATUS_DISABLED:    msg = StringConcatenate(":  sequence ", sequenceId, " disabled");
                               if (IsLastError())
                                  msg = StringConcatenate(msg, "  [", ErrorDescription(last_error), "]");
                               break;
      default:
         return(catch("ShowStatus(1)   illegal sequence status = "+ sequenceStatus, ERR_RUNTIME_ERROR));
   }
   msg = StringConcatenate(__SCRIPT__, msg,                                  NL,
                                                                             NL,
                          "Level:           ", progressionLevel, " / ", sequenceLength);

   double profitLoss, profitLossPips, lastPrice;
   int i;

   if (progressionLevel > 0) {
      i = progressionLevel-1;
      if (sequenceStatus == STATUS_FINISHED) {
         lastPrice = levels.closePrice[i];
      }
      else {                                                         // TODO: NumberToStr(x, "+- ") implementieren
         msg         = StringConcatenate(msg, "  =  ", ifString(levels.type[i]==OP_BUY, "+", "-"), NumberToStr(levels.lots[i], ".+"), " lot");
         lastPrice = ifDouble(levels.type[i]==OP_BUY, Bid, Ask);
      }
      profitLossPips = ifDouble(levels.type[i]==OP_BUY, lastPrice-levels.openPrice[i], levels.openPrice[i]-lastPrice) / Pip;
      profitLoss     = all.swaps + all.commissions + all.profits;
   }
   else {
      i = 0;                                                         // in Progression-Level 0 TakeProfit- und StopLoss-Anzeige für ersten Level
   }

   if (sequenceLength > 0) {
      msg = StringConcatenate(msg,                                                                                                                                                                      NL,
                             "Lot sizes:       ", str.levels.lots, "  (", DoubleToStr(levels.maxProfit[sequenceLength-1], 2), " / ", DoubleToStr(levels.maxDrawdown[sequenceLength-1], 2), ")", NL,
                             "TakeProfit:    ",   TakeProfit, " pip = ", DoubleToStr(levels.maxProfit[i], 2),                                                                                   NL,
                             "StopLoss:      ",   StopLoss,   " pip = ", DoubleToStr(levels.maxDrawdown[i], 2),                                                                                 NL);
   }
   else {
      msg = StringConcatenate(msg,                                       NL,
                             "Lot sizes:       ", str.levels.lots,       NL,
                             "TakeProfit:    ",   TakeProfit, " pip = ", NL,
                             "StopLoss:      ",   StopLoss,   " pip = ", NL);
   }
      msg = StringConcatenate(msg,
                             "Breakeven:   ",   DoubleToStr(0, Digits-PipDigits), " pip = ", NumberToStr(0, PriceFormat),              NL,
                             "Profit/Loss:    ", DoubleToStr(profitLossPips, Digits-PipDigits), " pip = ", DoubleToStr(profitLoss, 2), NL);

   // einige Zeilen Abstand nach oben für Instrumentanzeige und ggf. vorhandene Legende
   Comment(StringConcatenate(NL, NL, NL, NL, msg));

   if (IsNoError(catch("ShowStatus(2)")))
      last_error = error;                                            // bei Funktionseintritt bereits existierenden Fehler restaurieren
   return(last_error);
}


/**
 * Ob in den Input-Parametern ausdrücklich eine zu benutzende Sequenz-ID angegeben wurde. Hier wird nur geprüft,
 * ob ein Wert angegeben wurde. Die Gültigkeit einer ID wird erst in RestoreInputSequenceId() überprüft.
 *
 * @return bool
 */
bool IsInputSequenceId() {
   return(StringLen(StringTrim(Sequence.ID)) > 0);
}


/**
 * Validiert und setzt die in der Konfiguration angegebene Sequenz-ID.
 *
 * @return bool - ob eine gültige Sequenz-ID gefunden und restauriert wurde
 */
bool RestoreInputSequenceId() {
   if (IsInputSequenceId()) {
      string strValue = StringTrim(Sequence.ID);

      if (StringIsInteger(strValue)) {
         int iValue = StrToInteger(strValue);
         if (1000 <= iValue) /*&&*/ if (iValue <= 16383) {
            sequenceId  = iValue;
            Sequence.ID = strValue;
            return(true);
         }
      }
      catch("RestoreInputSequenceId()  Invalid input parameter Sequence.ID = \""+ Sequence.ID +"\"", ERR_INVALID_INPUT_PARAMVALUE);
   }
   return(false);
}


/**
 * Validiert die aktuelle Konfiguration. Die Variablen levels.lots[] und sequenceLength werden immer neugesetzt.
 *
 * @return bool - ob die Konfiguration gültig ist
 */
bool ValidateConfiguration() {
   // TODO: Nach Progressionstart unmögliche Parameteränderungen abfangen, z.B. Parameter werden geändert,
   //       ohne vorher im Input-Dialog die Konfigurationsdatei der Sequenz zu laden.

   // Entry.Condition
   string strValue = StringReplace(Entry.Condition, " ", "");
   string values[];
   // LimitValue | BollingerBands(35xM5, EMA, 2.0) | Envelopes(75xM15, ALMA, 2.0)
   if (Explode(strValue, "|", values, NULL) != 1)                    // vorerst wird nur eine Entry.Condition akzeptiert
      return(_false(catch("ValidateConfiguration(1)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ strValue +")", ERR_INVALID_INPUT_PARAMVALUE)));
   strValue = values[0];
   if (StringLen(strValue) == 0)
      return(_false(catch("ValidateConfiguration(2)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ strValue +")", ERR_INVALID_INPUT_PARAMVALUE)));
   // LimitValue
   if (StringIsNumeric(strValue)) {
      Entry.limit = StrToDouble(strValue);
      if (LT(Entry.limit, 0))
         return(_false(catch("ValidateConfiguration(3)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ strValue +")", ERR_INVALID_INPUT_PARAMVALUE)));
      Entry.type = ENTRYTYPE_LIMIT;
   }
   else if (!StringEndsWith(strValue, ")")) {
      return(_false(catch("ValidateConfiguration(4)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ strValue +")", ERR_INVALID_INPUT_PARAMVALUE)));
   }
   else {
      // [[Bollinger]Bands|Envelopes](35xM5, EMA, 2.0)
      strValue = StringToLower(StringLeft(strValue, -1));
      if (Explode(strValue, "(", values, NULL) != 2)
         return(_false(catch("ValidateConfiguration(5)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ strValue +")", ERR_INVALID_INPUT_PARAMVALUE)));
      if      (values[0] == "bands"         ) Entry.type = ENTRYTYPE_BANDS;
      else if (values[0] == "bollingerbands") Entry.type = ENTRYTYPE_BANDS;
      else if (values[0] == "env"           ) Entry.type = ENTRYTYPE_ENVELOPES;
      else if (values[0] == "envelopes"     ) Entry.type = ENTRYTYPE_ENVELOPES;
      else
         return(_false(catch("ValidateConfiguration(6)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ values[0] +")", ERR_INVALID_INPUT_PARAMVALUE)));
      // 35xM5, EMA, 2.0
      if (Explode(values[1], ",", values, NULL) != 3)
         return(_false(catch("ValidateConfiguration(7)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ values[1] +")", ERR_INVALID_INPUT_PARAMVALUE)));
      // MA-Deviation
      if (!StringIsNumeric(values[2]))
         return(_false(catch("ValidateConfiguration(8)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ values[2] +")", ERR_INVALID_INPUT_PARAMVALUE)));
      Entry.MA.deviation = StrToDouble(values[2]);
      if (LE(Entry.MA.deviation, 0))
         return(_false(catch("ValidateConfiguration(9)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ values[2] +")", ERR_INVALID_INPUT_PARAMVALUE)));
      // MA-Method
      Entry.MA.method = MovingAverageMethodToId(values[1]);
      if (Entry.MA.method == -1)
         return(_false(catch("ValidateConfiguration(10)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ values[1] +")", ERR_INVALID_INPUT_PARAMVALUE)));
      // MA-Periods(x)MA-Timeframe
      if (Explode(values[0], "x", values, NULL) != 2)
         return(_false(catch("ValidateConfiguration(11)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ values[0] +")", ERR_INVALID_INPUT_PARAMVALUE)));
      // MA-Periods
      if (!StringIsDigit(values[0]))
         return(_false(catch("ValidateConfiguration(12)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ values[0] +")", ERR_INVALID_INPUT_PARAMVALUE)));
      Entry.MA.periods = StrToInteger(values[0]);
      if (Entry.MA.periods < 1)
         return(_false(catch("ValidateConfiguration(13)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ values[0] +")", ERR_INVALID_INPUT_PARAMVALUE)));
      // MA-Timeframe
      Entry.MA.timeframe = PeriodToId(values[1]);
      if (Entry.MA.timeframe == -1)
         return(_false(catch("ValidateConfiguration(14)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ values[1] +")", ERR_INVALID_INPUT_PARAMVALUE)));

      // Für konstante Berechnungen bei Timeframe-Wechseln Timeframe möglichst nach M5 umrechnen.
      Entry.MA.periods.orig   = Entry.MA.periods;
      Entry.MA.timeframe.orig = Entry.MA.timeframe;
      if (Entry.MA.timeframe > PERIOD_M5) {
         Entry.MA.periods   = Entry.MA.periods * Entry.MA.timeframe / PERIOD_M5;
         Entry.MA.timeframe = PERIOD_M5;
      }
   }

   // Entry.Direction
   strValue = StringToLower(StringTrim(Entry.Direction));
   if (StringLen(strValue) == 0) { Entry.Direction = "";  Entry.iDirection = ENTRYDIRECTION_LONGSHORT; }
   else {
      switch (StringGetChar(strValue, 0)) {
         case 'b':
         case 'l': Entry.Direction = "long";  Entry.iDirection = ENTRYDIRECTION_LONG;  break;
         case 's': Entry.Direction = "short"; Entry.iDirection = ENTRYDIRECTION_SHORT; break;
         default:
            return(_false(catch("ValidateConfiguration(15)  Invalid input parameter Entry.Direction = \""+ Entry.Direction +"\" ("+ strValue +")", ERR_INVALID_INPUT_PARAMVALUE)));
      }
   }

   // Entry.Condition <-> Entry.Direction
   if (Entry.type == ENTRYTYPE_LIMIT) {
      if (Entry.iDirection == ENTRYDIRECTION_LONGSHORT)
         return(_false(catch("ValidateConfiguration(16)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ EntryTypeToStr(Entry.type) +" <-> "+ Entry.Direction +")", ERR_INVALID_INPUT_PARAMVALUE)));
   }
   else if (Entry.iDirection != ENTRYDIRECTION_LONGSHORT)
      return(_false(catch("ValidateConfiguration(17)  Invalid input parameter Entry.Condition = \""+ Entry.Condition +"\" ("+ EntryTypeToStr(Entry.type) +" <-> "+ Entry.Direction +")", ERR_INVALID_INPUT_PARAMVALUE)));
   Entry.Condition = StringTrim(Entry.Condition);

   // TakeProfit
   if (TakeProfit < 1)
      return(_false(catch("ValidateConfiguration(18)  Invalid input parameter TakeProfit = "+ TakeProfit, ERR_INVALID_INPUT_PARAMVALUE)));

   // StopLoss
   if (StopLoss < 1)
      return(_false(catch("ValidateConfiguration(19)  Invalid input parameter StopLoss = "+ StopLoss, ERR_INVALID_INPUT_PARAMVALUE)));

   // Lotsizes
   int levels = ArrayResize(levels.lots, 0);

   if (LE(Lotsize.Level.1, 0)) return(_false(catch("ValidateConfiguration(20)  Invalid input parameter Lotsize.Level.1 = "+ NumberToStr(Lotsize.Level.1, ".+"), ERR_INVALID_INPUT_PARAMVALUE)));
   levels = ArrayPushDouble(levels.lots, Lotsize.Level.1);

   if (NE(Lotsize.Level.2, 0)) {
      if (LT(Lotsize.Level.2, Lotsize.Level.1)) return(_false(catch("ValidateConfiguration(21)  Invalid input parameter Lotsize.Level.2 = "+ NumberToStr(Lotsize.Level.2, ".+"), ERR_INVALID_INPUT_PARAMVALUE)));
      levels = ArrayPushDouble(levels.lots, Lotsize.Level.2);

      if (NE(Lotsize.Level.3, 0)) {
         if (LT(Lotsize.Level.3, Lotsize.Level.2)) return(_false(catch("ValidateConfiguration(22)  Invalid input parameter Lotsize.Level.3 = "+ NumberToStr(Lotsize.Level.3, ".+"), ERR_INVALID_INPUT_PARAMVALUE)));
         levels = ArrayPushDouble(levels.lots, Lotsize.Level.3);

         if (NE(Lotsize.Level.4, 0)) {
            if (LT(Lotsize.Level.4, Lotsize.Level.3)) return(_false(catch("ValidateConfiguration(23)  Invalid input parameter Lotsize.Level.4 = "+ NumberToStr(Lotsize.Level.4, ".+"), ERR_INVALID_INPUT_PARAMVALUE)));
            levels = ArrayPushDouble(levels.lots, Lotsize.Level.4);

            if (NE(Lotsize.Level.5, 0)) {
               if (LT(Lotsize.Level.5, Lotsize.Level.4)) return(_false(catch("ValidateConfiguration(24)  Invalid input parameter Lotsize.Level.5 = "+ NumberToStr(Lotsize.Level.5, ".+"), ERR_INVALID_INPUT_PARAMVALUE)));
               levels = ArrayPushDouble(levels.lots, Lotsize.Level.5);

               if (NE(Lotsize.Level.6, 0)) {
                  if (LT(Lotsize.Level.6, Lotsize.Level.5)) return(_false(catch("ValidateConfiguration(25)  Invalid input parameter Lotsize.Level.6 = "+ NumberToStr(Lotsize.Level.6, ".+"), ERR_INVALID_INPUT_PARAMVALUE)));
                  levels = ArrayPushDouble(levels.lots, Lotsize.Level.6);

                  if (NE(Lotsize.Level.7, 0)) {
                     if (LT(Lotsize.Level.7, Lotsize.Level.6)) return(_false(catch("ValidateConfiguration(26)  Invalid input parameter Lotsize.Level.7 = "+ NumberToStr(Lotsize.Level.7, ".+"), ERR_INVALID_INPUT_PARAMVALUE)));
                     levels = ArrayPushDouble(levels.lots, Lotsize.Level.7);
                  }
               }
            }
         }
      }
   }
   str.levels.lots = JoinDoubles(levels.lots, ",  ");

   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   int error = GetLastError();
   if (IsError(error))                                return(_false(catch("ValidateConfiguration(27)   symbol=\""+ Symbol() +"\"", error)));

   for (int i=0; i < levels; i++) {
      if (LT(levels.lots[i], minLot))                 return(_false(catch("ValidateConfiguration(28)   Invalid input parameter Lotsize.Level."+ (i+1) +" = "+ NumberToStr(levels.lots[i], ".+") +" (MinLot="+  NumberToStr(minLot, ".+" ) +")", ERR_INVALID_INPUT_PARAMVALUE)));
      if (GT(levels.lots[i], maxLot))                 return(_false(catch("ValidateConfiguration(29)   Invalid input parameter Lotsize.Level."+ (i+1) +" = "+ NumberToStr(levels.lots[i], ".+") +" (MaxLot="+  NumberToStr(maxLot, ".+" ) +")", ERR_INVALID_INPUT_PARAMVALUE)));
      if (NE(MathModFix(levels.lots[i], lotStep), 0)) return(_false(catch("ValidateConfiguration(30)   Invalid input parameter Lotsize.Level."+ (i+1) +" = "+ NumberToStr(levels.lots[i], ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", ERR_INVALID_INPUT_PARAMVALUE)));
   }
   sequenceLength = ArraySize(levels.lots);

   // Sequence.ID: falls gesetzt, wurde sie schon in RestoreInputSequenceId() validiert

   // Nach Parameteränderung die neue Konfiguration mit der aktuellen Sequenz vergleichen
   if (progressionLevel > 0) {
      // TODO: Wurden die Level geändert, sicherstellen, daß nur zukünftige Level geändert wurden.
      if (Entry.type==ENTRYTYPE_LIMIT) /*&&*/ if (levels.type[0]!=Entry.iDirection)
         return(_false(catch("ValidateConfiguration(31)   illegal input parameter Entry.Direction = \""+ Entry.Direction +"\", it doesn't match "+ OperationTypeDescription(levels.type[0]) +" order at level 1", ERR_INVALID_INPUT_PARAMVALUE)));
   }

   return(IsNoError(catch("ValidateConfiguration(32)")));
}


/**
 * Speichert aktuelle Konfiguration und Laufzeitdaten der Instanz, um die nahtlose Wiederauf- und Übernahme durch eine
 * andere Instanz im selben oder einem anderen Terminal zu ermöglichen.
 *
 * @return int - Fehlerstatus
 */
int SaveConfiguration() {
   if (sequenceId == 0)
      return(catch("SaveConfiguration(1)   illegal value of sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR));
   //debug("SaveConfiguration()   saving configuration for sequence "+ sequenceId);


   // (1) Daten zusammenstellen
   string lines[];  ArrayResize(lines, 0);
   ArrayPushString(lines, /*string*/ "Sequence.ID="     +             sequenceId            );
   ArrayPushString(lines, /*string*/ "Entry.Condition=" +             Entry.Condition       );
   ArrayPushString(lines, /*string*/ "Entry.Direction=" +             Entry.Direction       );
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
   string filename = "presets\\FTP."+ sequenceId +".set";            // ".\experts\files\presets" ist ein Softlink auf ".\experts\presets", dadurch ist
                                                                     // das Presets-Verzeichnis für die MQL-Dateifunktionen erreichbar.
   int hFile = FileOpen(filename, FILE_CSV|FILE_WRITE);
   if (hFile < 0)
      return(catch("SaveConfiguration(2)  FileOpen(file=\""+ filename +"\")"));

   for (int i=0; i < ArraySize(lines); i++) {
      if (FileWrite(hFile, lines[i]) < 0) {
         int error = GetLastError();
         FileClose(hFile);
         return(catch("SaveConfiguration(3)  FileWrite(line #"+ (i+1) +")", error));
      }
   }
   FileClose(hFile);


   // (3) Datei auf Server laden
   if (!IsTesting()) {
      error = UploadConfiguration(ShortAccountCompany(), AccountNumber(), GetStandardSymbol(Symbol()), filename);
      if (IsError(error))
         return(error);
   }
   return(catch("SaveConfiguration(4)"));
}


/**
 * Lädt die angegebene Konfigurationsdatei auf den Server.
 *
 * @param  string company     - Account-Company
 * @param  int    account     - Account-Number
 * @param  string symbol      - Symbol der Konfiguration
 * @param  string presetsFile - Dateiname, relativ zu "{terminal-directory}\experts"
 *
 * @return int - Fehlerstatus
 */
int UploadConfiguration(string company, int account, string symbol, string presetsFile) {
   if (IsTesting())
      return(_NO_ERROR(debug("UploadConfiguration()   skipping in tester")));

   // TODO: Existenz von wget.exe prüfen

   string parts[]; int size = Explode(presetsFile, "\\", parts, NULL);
   string file = parts[size-1];                                         // einfacher Dateiname ohne Verzeichnisse

   // Befehlszeile für Shellaufruf zusammensetzen
   string presetsPath  = TerminalPath() +"\\experts\\" + presetsFile;   // Dateinamen mit vollständigen Pfaden
   string responsePath = presetsPath +".response";
   string logPath      = presetsPath +".log";
   string url          = "http://sub.domain.tld/uploadFTPConfiguration.php?company="+ UrlEncode(company) +"&account="+ account +"&symbol="+ UrlEncode(symbol) +"&name="+ UrlEncode(file);
   string cmdLine      = "wget.exe -b \""+ url +"\" --post-file=\""+ presetsPath +"\" --header=\"Content-Type: text/plain\" -O \""+ responsePath +"\" -a \""+ logPath +"\"";

   // Existenz der Datei prüfen
   if (!IsFile(presetsPath))
      return(catch("UploadConfiguration(1)   file not found: \""+ presetsPath +"\"", ERR_FILE_NOT_FOUND));

   // Datei hochladen, WinExec() kehrt ohne zu warten zurück, wget -b beschleunigt zusätzlich
   int error = WinExec(cmdLine, SW_HIDE);                               // SW_SHOWNORMAL|SW_HIDE
   if (error < 32)
      return(catch("UploadConfiguration(2) ->kernel32.WinExec(cmdLine=\""+ cmdLine +"\"), error="+ error +" ("+ ShellExecuteErrorToStr(error) +")", ERR_WIN32_ERROR));

   return(catch("UploadConfiguration(3)"));
}


/**
 * Liest die Konfiguration einer Sequenz ein und setzt die internen Variablen entsprechend. Ohne lokale Konfiguration
 * wird die Konfiguration vom Server geladen und lokal gespeichert.
 *
 * @return bool - ob die Konfiguration erfolgreich restauriert wurde
 */
bool RestoreConfiguration() {
   if (sequenceId == 0)
      return(_false(catch("RestoreConfiguration(1)   illegal value of sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR)));

   // TODO: Existenz von wget.exe prüfen

   // (1) bei nicht existierender lokaler Konfiguration die Datei vom Server laden
   string filesDir = TerminalPath() +"\\experts\\files\\";           // ".\experts\files\presets" ist ein Softlink auf ".\experts\presets", dadurch
   string fileName = "presets\\FTP."+ sequenceId +".set";            // ist das Presets-Verzeichnis für die MQL-Dateifunktionen erreichbar.

   if (!IsFile(filesDir + fileName)) {
      // Befehlszeile für Shellaufruf zusammensetzen
      string url        = "http://sub.domain.tld/downloadFTPConfiguration.php?company="+ UrlEncode(ShortAccountCompany()) +"&account="+ AccountNumber() +"&symbol="+ UrlEncode(GetStandardSymbol(Symbol())) +"&sequence="+ sequenceId;
      string targetFile = filesDir +"\\"+ fileName;
      string logFile    = filesDir +"\\"+ fileName +".log";
      string cmdLine    = "wget.exe \""+ url +"\" -O \""+ targetFile +"\" -o \""+ logFile +"\"";

      debug("RestoreConfiguration()   downloading configuration for sequence "+ sequenceId);

      int error = WinExecAndWait(cmdLine, SW_HIDE);                  // SW_SHOWNORMAL|SW_HIDE
      if (IsError(error))
         return(_false(SetLastError(error)));

      debug("RestoreConfiguration()   configuration for sequence "+ sequenceId +" successfully downloaded");
      FileDelete(fileName +".log");
   }

   // (2) Datei einlesen
   string config[];
   int lines = FileReadLines(fileName, config, true);
   if (lines < 0)
      return(_false(SetLastError(stdlib_PeekLastError())));
   if (lines == 0) {
      FileDelete(fileName);
      return(_false(catch("RestoreConfiguration(2)   no configuration found for sequence "+ sequenceId, ERR_RUNTIME_ERROR)));
   }

   // (3) Zeilen in Schlüssel-Wert-Paare aufbrechen, Datentypen validieren und Daten übernehmen
   int keys[11]; ArrayInitialize(keys, 0);
   #define I_ENTRY_CONDITION  0
   #define I_ENTRY_DIRECTION  1
   #define I_TAKEPROFIT       2
   #define I_STOPLOSS         3
   #define I_LOTSIZE_LEVEL_1  4
   #define I_LOTSIZE_LEVEL_2  5
   #define I_LOTSIZE_LEVEL_3  6
   #define I_LOTSIZE_LEVEL_4  7
   #define I_LOTSIZE_LEVEL_5  8
   #define I_LOTSIZE_LEVEL_6  9
   #define I_LOTSIZE_LEVEL_7 10

   string parts[];
   for (int i=0; i < lines; i++) {
      if (Explode(config[i], "=", parts, 2) != 2) return(_false(catch("RestoreConfiguration(3)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)));
      string key=parts[0], value=parts[1];

      if (key == "Entry.Condition") {
         Entry.Condition = value;
         keys[I_ENTRY_CONDITION] = 1;
      }
      else if (key == "Entry.Direction") {
         Entry.Direction = value;
         keys[I_ENTRY_DIRECTION] = 1;
      }
      else if (key == "TakeProfit") {
         if (!StringIsDigit(value))               return(_false(catch("RestoreConfiguration(4)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)));
         TakeProfit = StrToInteger(value);
         keys[I_TAKEPROFIT] = 1;
      }
      else if (key == "StopLoss") {
         if (!StringIsDigit(value))               return(_false(catch("RestoreConfiguration(5)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)));
         StopLoss = StrToInteger(value);
         keys[I_STOPLOSS] = 1;
      }
      else if (key == "Lotsize.Level.1") {
         if (!StringIsNumeric(value))             return(_false(catch("RestoreConfiguration(6)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)));
         Lotsize.Level.1 = StrToDouble(value);
         keys[I_LOTSIZE_LEVEL_1] = 1;
      }
      else if (key == "Lotsize.Level.2") {
         if (!StringIsNumeric(value))             return(_false(catch("RestoreConfiguration(7)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)));
         Lotsize.Level.2 = StrToDouble(value);
         keys[I_LOTSIZE_LEVEL_2] = 1;
      }
      else if (key == "Lotsize.Level.3") {
         if (!StringIsNumeric(value))             return(_false(catch("RestoreConfiguration(8)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)));
         Lotsize.Level.3 = StrToDouble(value);
         keys[I_LOTSIZE_LEVEL_3] = 1;
      }
      else if (key == "Lotsize.Level.4") {
         if (!StringIsNumeric(value))             return(_false(catch("RestoreConfiguration(9)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)));
         Lotsize.Level.4 = StrToDouble(value);
         keys[I_LOTSIZE_LEVEL_4] = 1;
      }
      else if (key == "Lotsize.Level.5") {
         if (!StringIsNumeric(value))             return(_false(catch("RestoreConfiguration(10)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)));
         Lotsize.Level.5 = StrToDouble(value);
         keys[I_LOTSIZE_LEVEL_5] = 1;
      }
      else if (key == "Lotsize.Level.6") {
         if (!StringIsNumeric(value))             return(_false(catch("RestoreConfiguration(11)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)));
         Lotsize.Level.6 = StrToDouble(value);
         keys[I_LOTSIZE_LEVEL_6] = 1;
      }
      else if (key == "Lotsize.Level.7") {
         if (!StringIsNumeric(value))             return(_false(catch("RestoreConfiguration(12)   invalid configuration file \""+ fileName +"\" (line \""+ config[i] +"\")", ERR_RUNTIME_ERROR)));
         Lotsize.Level.7 = StrToDouble(value);
         keys[I_LOTSIZE_LEVEL_7] = 1;
      }
   }
   if (IntInArray(0, keys))                       return(_false(catch("RestoreConfiguration(13)   one or more configuration values missing in file \""+ fileName +"\"", ERR_RUNTIME_ERROR)));
   Sequence.ID = sequenceId;

   return(IsNoError(catch("RestoreConfiguration(14)")));
}


/**
 * Gibt die lesbare Konstante eines Sequenzstatus-Codes zurück.
 *
 * @param  int status - Status-Code
 *
 * @return string
 */
string SequenceStatusToStr(int status) {
   switch (status) {
      case STATUS_WAITING    : return("STATUS_WAITING"    );
      case STATUS_PROGRESSING: return("STATUS_PROGRESSING");
      case STATUS_FINISHED   : return("STATUS_FINISHED"   );
      case STATUS_DISABLED   : return("STATUS_DISABLED"   );
   }
   catch("SequenceStatusToStr()  invalid parameter status: "+ status, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt die lesbare Konstante eines Entry-Types zurück.
 *
 * @param  int type - Entry-Type
 *
 * @return string
 */
string EntryTypeToStr(int type) {
   switch (type) {
      case ENTRYTYPE_UNDEFINED: return("ENTRYTYPE_UNDEFINED");
      case ENTRYTYPE_LIMIT    : return("ENTRYTYPE_LIMIT"    );
      case ENTRYTYPE_BANDS    : return("ENTRYTYPE_BANDS"    );
      case ENTRYTYPE_ENVELOPES: return("ENTRYTYPE_ENVELOPES");
   }
   catch("EntryTypeToStr()  invalid parameter type: "+ type, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Gibt die Beschreibung eines Entry-Types zurück.
 *
 * @param  int type - Entry-Type
 *
 * @return string
 */
string EntryTypeDescription(int type) {
   switch (type) {
      case ENTRYTYPE_UNDEFINED: return("(undefined)"   );
      case ENTRYTYPE_LIMIT    : return("Limit"         );
      case ENTRYTYPE_BANDS    : return("BollingerBands");
      case ENTRYTYPE_ENVELOPES: return("Envelopes"     );
   }
   catch("EntryTypeToStr()  invalid parameter type: "+ type, ERR_INVALID_FUNCTION_PARAMVALUE);
   return("");
}


/**
 * Speichert die aktuelle Sequenz-ID im Chart, sodaß sie nach einem deinit() restauriert werden kann.
 *
 * @return int - Fehlerstatus
 */
int StoreChartSequenceId() {
   string label = __SCRIPT__ +".sequence_id";

   if (ObjectFind(label) != -1)
      ObjectDelete(label);
   ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
   ObjectSet(label, OBJPROP_XDISTANCE, -sequenceId);                 // negativer Wert (nicht sichtbarer Bereich)

   return(catch("StoreChartSequenceId()"));
}


/**
 * Restauriert eine im Chart gespeicherte Sequenz-ID.
 *
 * @return bool - ob eine Sequenz-ID gefunden und restauriert wurde
 */
bool RestoreChartSequenceId() {
   string label = __SCRIPT__ +".sequence_id";

   if (ObjectFind(label)!=-1) /*&&*/ if (ObjectType(label)==OBJ_LABEL) {
      sequenceId = MathAbs(ObjectGet(label, OBJPROP_XDISTANCE)) +0.1;   // (int) double
      return(_true(catch("RestoreChartSequenceId(1)")));
   }
   return(_false(catch("RestoreChartSequenceId(2)")));

   // Dummy-Calls, unterdrücken Compilerwarnungen über unbenutzte Funktionen
   EntryTypeDescription(NULL);
   EntryTypeToStr(NULL);
   SequenceStatusToStr(NULL);
}
