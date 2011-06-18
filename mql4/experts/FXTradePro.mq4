/**
 * FXTradePro Martingale EA
 *
 * @see FXTradePro Strategy:     http://www.forexfactory.com/showthread.php?t=43221
 *      FXTradePro Journal:      http://www.forexfactory.com/showthread.php?t=82544
 *      FXTradePro Swing Trades: http://www.forexfactory.com/showthread.php?t=87564
 *
 *      PowerSM EA:              http://www.forexfactory.com/showthread.php?t=75394
 *      PowerSM Journal:         http://www.forexfactory.com/showthread.php?t=159789
 */
#include <stdlib.mqh>


#define STATUS_INITIALIZED       1
#define STATUS_WAIT_ENTRYLIMIT   2
#define STATUS_PROGRESSING       3
#define STATUS_FINISHED          4
#define STATUS_DISABLED          5



//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string _1____________________________ = "==== Entry Options ===================";
//extern string Entry.Direction                = "[ Long | Short ]";
extern string Entry.Direction                = "long";
extern double Entry.Limit                    = 0;

extern string _2____________________________ = "==== TP and SL Settings ==============";
extern int    TakeProfit                     = 40;
extern int    StopLoss                       = 10;

extern string _3____________________________ = "==== Lotsizes =======================";
extern double Lotsize.Level.1                = 0.1;
extern double Lotsize.Level.2                = 0.1;
extern double Lotsize.Level.3                = 0.2;
extern double Lotsize.Level.4                = 0.3;
extern double Lotsize.Level.5                = 0.4;
extern double Lotsize.Level.6                = 0.6;
extern double Lotsize.Level.7                = 0.8;
extern double Lotsize.Level.8                = 1.1;
extern double Lotsize.Level.9                = 1.5;
extern double Lotsize.Level.10               = 2.0;
extern double Lotsize.Level.11               = 2.7;
extern double Lotsize.Level.12               = 3.6;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int EA.uniqueId = 101;                                            // eindeutige ID der Strategie (im Bereich 0-1023)


double   Pip;
int      PipDigits;
string   PriceFormat;

int      sequenceId;
int      sequenceLength;
int      progressionLevel;
int      entryDirection = OP_UNDEFINED;
int      status;

int      levels.ticket    [], last.ticket;
int      levels.type      [], last.type;
double   levels.openPrice [], last.openPrice;
double   levels.lotsize   [], last.lotsize;
double   levels.swap      [], last.swap,       all.swaps;
double   levels.commission[], last.commission, all.commissions;
double   levels.profit    [], last.profit,     all.profits;
datetime levels.closeTime [], last.closeTime;                     // Unterscheidung zwischen offenen und geschlossenen Positionen


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   PipDigits   = Digits - Digits%2;
   Pip         = 1/MathPow(10, PipDigits);
   PriceFormat = "."+ PipDigits + ifString(Digits==PipDigits, "", "'");


   // (1) Beginn Parametervalidierung
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
                  else {
                     if (LT(Lotsize.Level.8, 0)) return(catch("init(13)  Invalid input parameter Lotsize.Level.8 = "+ NumberToStr(Lotsize.Level.8, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                     if (EQ(Lotsize.Level.8, 0)) sequenceLength = 7;
                     else {
                        if (LT(Lotsize.Level.9, 0)) return(catch("init(14)  Invalid input parameter Lotsize.Level.9 = "+ NumberToStr(Lotsize.Level.9, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                        if (EQ(Lotsize.Level.9, 0)) sequenceLength = 8;
                        else {
                           if (LT(Lotsize.Level.10, 0)) return(catch("init(15)  Invalid input parameter Lotsize.Level.10 = "+ NumberToStr(Lotsize.Level.10, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                           if (EQ(Lotsize.Level.10, 0)) sequenceLength = 9;
                           else {
                              if (LT(Lotsize.Level.11, 0)) return(catch("init(16)  Invalid input parameter Lotsize.Level.11 = "+ NumberToStr(Lotsize.Level.11, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                              if (EQ(Lotsize.Level.11, 0)) sequenceLength = 10;
                              else {
                                 if (LT(Lotsize.Level.12, 0)) return(catch("init(17)  Invalid input parameter Lotsize.Level.12 = "+ NumberToStr(Lotsize.Level.12, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                                 if (EQ(Lotsize.Level.12, 0)) sequenceLength = 11;
                                 else                         sequenceLength = 12;
                              }
                           }
                        }
                     }
                  }
               }
            }
         }
      }
   }
   // Ende Parametervalidierung


   // (2) Sequenzdaten einlesen
   if (sequenceId == 0) {                                               // noch keine Sequenz definiert
      progressionLevel = 0;
      if (ArraySize(levels.ticket) > 0) {
         ArrayResize(levels.ticket    , 0);                             // alte Daten ggf. löschen (Arrays sind statisch)
         ArrayResize(levels.type      , 0);
         ArrayResize(levels.openPrice , 0);
         ArrayResize(levels.lotsize   , 0);
         ArrayResize(levels.swap      , 0);
         ArrayResize(levels.commission, 0);
         ArrayResize(levels.profit    , 0);
         ArrayResize(levels.closeTime , 0);
      }

      // erste aktive Sequenz finden und offene Positionen einlesen
      for (int i=OrdersTotal()-1; i >= 0; i--) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wird in einem anderen Thread eine offene Order entfernt
            continue;

         if (IsMyOrder(sequenceId)) {
            int level = OrderMagicNumber() & 0x000F;                    //  4 Bits  1-4  => progressionLevel
            if (level > progressionLevel)
               progressionLevel = level;

            if (sequenceId == 0) {
               sequenceId     = OrderMagicNumber() << 10 >> 18;         // 14 Bits  9-22 => sequenceId
               sequenceLength = OrderMagicNumber() & 0x00F0 >> 4;       //  4 Bits  5-8  => sequenceLength

               ArrayResize(levels.ticket    , sequenceLength);
               ArrayResize(levels.type      , sequenceLength);
               ArrayResize(levels.openPrice , sequenceLength);
               ArrayResize(levels.lotsize   , sequenceLength);
               ArrayResize(levels.swap      , sequenceLength);
               ArrayResize(levels.commission, sequenceLength);
               ArrayResize(levels.profit    , sequenceLength);
               ArrayResize(levels.closeTime , sequenceLength);

               if (level%2==1) entryDirection =  OrderType();
               else            entryDirection = ~OrderType() & 1;       // 0=>1, 1=>0
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
               level = OrderMagicNumber() & 0x000F;                     //  4 Bits  1-4  => progressionLevel
               if (level > progressionLevel)
                  progressionLevel = level;
               level--;

               // TODO: möglich bei gehedgten Positionen
               if (levels.ticket[level] != 0)
                  return(catch("init(18)   multiple tickets found for progression level "+ (level+1) +": #"+ levels.ticket[level] +", #"+ OrderTicket(), ERR_RUNTIME_ERROR));

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

      // Tickets auf Vollständigkeit prüfen
      for (i=0; i < progressionLevel; i++) {
         if (levels.ticket[i] == 0)
            return(catch("init(19)   order not found for progression level "+ (i+1) +", more history data needed.", ERR_RUNTIME_ERROR));
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


   // (4) aktuellen Status bestimmen
   if (progressionLevel == 0) {
      if (EQ(Entry.Limit, 0))    status = STATUS_INITIALIZED;
      else                       status = STATUS_WAIT_ENTRYLIMIT;
   }
   else if (last.closeTime == 0) status = STATUS_PROGRESSING;
   else                          status = STATUS_FINISHED;


   // (5) bei Start ggf. EA's aktivieren
   int reasons1[] = { REASON_REMOVE, REASON_CHARTCLOSE, REASON_APPEXIT };
   if (!IsExpertEnabled()) /*&&*/ if (IntInArray(UninitializeReason(), reasons1))
      ToggleEAs(true);


   // (6) nach Start oder Reload nicht auf den nächsten Tick warten
   int reasons2[] = { REASON_REMOVE, REASON_CHARTCLOSE, REASON_APPEXIT, REASON_PARAMETERS, REASON_RECOMPILE };
   if (IntInArray(UninitializeReason(), reasons2))
      SendTick(false);

   return(catch("init(20)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   if (UninitializeReason() != REASON_CHARTCHANGE)
      Comment("");
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
   // --------------------------------------------


   if (status == STATUS_DISABLED) return(NO_ERROR);
   if (status == STATUS_FINISHED) return(NO_ERROR);


   if (ReadStatus()) {
      if (progressionLevel == 0) {
         if (!IsEntryLimitReached())            status = STATUS_WAIT_ENTRYLIMIT;
         else                                   StartSequence();                    // kein Limit definiert oder Limit erreicht
      }
      else if (IsStopLossReached()) {                                               // wenn StopLoss erreicht ...
         if (progressionLevel < sequenceLength) IncreaseProgression();              // auf nächsten Level wechseln ...
         else                                   FinishSequence();                   // ... oder Sequenz beenden
      }
      else if (IsProfitTargetReached())         FinishSequence();                   // wenn TakeProfit erreicht, Sequenz beenden
   }

   ShowStatus();

   if (last_error != NO_ERROR) {
      status = STATUS_DISABLED;
      return(last_error);
   }
   return(catch("start()"));
}


/**
 * Überprüft den Status der aktuellen Sequenz.
 *
 * @return bool - Erfolgsstatus
 */
bool ReadStatus() {
   all.swaps       = 0;
   all.commissions = 0;
   all.profits     = 0;

   for (int i=0; i < sequenceLength; i++) {
      if (levels.ticket[i] == 0)
         break;

      if (levels.closeTime[i] == 0) {                 // offene Position
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
      all.swaps       += levels.swap      [i];
      all.commissions += levels.commission[i];
      all.profits     += levels.profit    [i];
   }

   return(catch("ReadStatus(3)")==NO_ERROR);
}


/**
 * Ob die aktuell selektierte Order von diesem EA erzeugt wurde. Wird eine Sequenz-ID angegeben, wird zusätzlich überprüft,
 * ob die Order zur angegebeben Sequenz gehört.
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
            return(sequenceId == OrderMagicNumber() << 10 >> 18);       // 14 Bits  9-22 => sequenceId
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
   if (sequenceId <= 1000) {
      catch("CreateMagicNumber()   illegal sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR);
      return(-1);
   }

   int ea       = EA.uniqueId << 22;                  // 10 bit (Bereich 0-1023)                              | in MagicNumber: Bits 23-32
   int sequence = sequenceId  << 18 >> 10;            // Bits größer 14 löschen und Wert auf 22 Bit erweitern | in MagicNumber: Bits  9-22
   int length   = sequenceLength   & 0x000F << 4;     // 4 bit (Bereich 1-12), auf 8 bit erweitern            | in MagicNumber: Bits  5-8
   int level    = progressionLevel & 0x000F;          // 4 bit (Bereich 1-12)                                 | in MagicNumber: Bits  1-4

   return(ea + sequence + length + level);
}


/**
 * Ob das eingestellte EntryLimit erreicht oder überschritten wurde.  Wurde kein Limit definiert, gibt die Funktion ebenfalls TRUE zurück.
 *
 * @return bool
 */
bool IsEntryLimitReached() {
   if (EQ(Entry.Limit, 0))
      return(true);

   // Limit definiert
   if (entryDirection == OP_BUY) {
      if (LE(Ask, Entry.Limit))           // Buy-Limit erreicht
         return(true);
   }
   else if (GE(Bid, Entry.Limit))         // Sell-Limit erreicht
      return(true);

   return(false);
}


/**
 * Ob der eingestellte StopLoss erreicht oder überschritten wurde.
 *
 * @return bool
 */
bool IsStopLossReached() {
   if (last.type == OP_BUY)
      return(LE(Bid, last.openPrice - StopLoss*Pip));

   if (last.type == OP_SELL)
      return(GE(Ask, last.openPrice + StopLoss*Pip));

   catch("IsStopLossReached()   illegal value for variable last.type = "+ last.type, ERR_RUNTIME_ERROR);
   return(false);
}


/**
 * Ob der eingestellte TakeProfit-Level erreicht oder überschritten wurde.
 *
 * @return bool
 */
bool IsProfitTargetReached() {
   if (last.type == OP_BUY)
      return(GE(Bid, last.openPrice + TakeProfit*Pip));

   if (last.type == OP_SELL)
      return(LE(Ask, last.openPrice - TakeProfit*Pip));

   catch("IsProfitTargetReached()   illegal value for variable last.type = "+ last.type, ERR_RUNTIME_ERROR);
   return(false);
}


/**
 * Beginnt eine neue Trade-Sequenz (Progression-Level 1).
 *
 * @return int - Fehlerstatus
 */
int StartSequence() {
   if (EQ(Entry.Limit, 0)) {                                                        // kein Limit definiert, also Aufruf direkt nach Start
      PlaySound("notify.wav");
      int answer = MessageBox(ifString(!IsDemo(), "Live Account\n\n", "") +"Do you really want to start a new trade sequence?", __SCRIPT__, MB_ICONQUESTION|MB_OKCANCEL);
      if (answer != IDOK) {
         status = STATUS_DISABLED;
         return(catch("StartSequence(1)"));
      }
   }

   progressionLevel = 1;

   int ticket = OpenPosition(entryDirection, CurrentLotSize());                     // Position in Entry.Direction öffnen
   if (ticket == -1) {
      status = STATUS_DISABLED;
      return(last_error);
   }

   // Sequenzdaten aktualisieren
   if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      status = STATUS_DISABLED;
      return(catch("StartSequence(2)"));
   }

   levels.ticket    [0] = OrderTicket();    last.ticket     = OrderTicket();
   levels.type      [0] = OrderType();      last.type       = OrderType();
   levels.openPrice [0] = OrderOpenPrice(); last.openPrice  = OrderOpenPrice();
   levels.lotsize   [0] = OrderLots();      last.lotsize    = OrderLots();
   levels.swap      [0] = 0;                last.swap       = 0;
   levels.commission[0] = 0;                last.commission = 0;                    // Werte werden in ReadStatus() ausgelesen
   levels.profit    [0] = 0;                last.profit     = 0;
   levels.closeTime [0] = 0;                last.closeTime  = 0;

   // Status aktualisieren
   status = STATUS_PROGRESSING;

   if (!ReadStatus()) {
      status = STATUS_DISABLED;
      return(last_error);
   }
   return(catch("StartSequence(3)"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int IncreaseProgression() {
   debug("IncreaseProgression()   StopLoss für "+ ifString(last.type==OP_BUY, "long", "short") +" position erreicht: "+ DoubleToStr(ifDouble(last.type==OP_BUY, last.openPrice-Bid, Ask-last.openPrice)/Pip, 1) +" pip");

   progressionLevel++;
   int    direction = ifInt(last.type==OP_SELL, OP_BUY, OP_SELL);
   double lotsize   = CurrentLotSize();

   int ticket = OpenPosition(direction, last.lotsize + lotsize);                    // alte Position hedgen und nächste öffnen
   if (ticket == -1) {
      status = STATUS_DISABLED;
      return(last_error);
   }

   // Sequenzdaten aktualisieren
   if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      status = STATUS_DISABLED;
      return(catch("IncreaseProgression(1)"));
   }

   int level = progressionLevel - 1;
   levels.ticket    [level] = OrderTicket();    last.ticket     = OrderTicket();
   levels.type      [level] = OrderType();      last.type       = OrderType();
   levels.openPrice [level] = OrderOpenPrice(); last.openPrice  = OrderOpenPrice();
   levels.lotsize   [level] = lotsize;          last.lotsize    = lotsize;          // wegen Hedges nicht OrderLots() verwenden
   levels.swap      [level] = 0;                last.swap       = 0;
   levels.commission[level] = 0;                last.commission = 0;                // Werte werden in ReadStatus() ausgelesen
   levels.profit    [level] = 0;                last.profit     = 0;
   levels.closeTime [level] = 0;                last.closeTime  = 0;

   // Status aktualisieren
   if (!ReadStatus()) {
      status = STATUS_DISABLED;
      return(last_error);
   }
   return(catch("IncreaseProgression(2)"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int FinishSequence() {
   if (IsProfitTargetReached()) debug("FinishSequence()   TakeProfit für "+ ifString(last.type==OP_BUY, "long", "short") +" position erreicht: "+ DoubleToStr(ifDouble(last.type==OP_BUY, Bid-last.openPrice, last.openPrice-Ask)/Pip, 1) +" pip");
   else                         debug("FinishSequence()   Letzter StopLoss für "+ ifString(last.type==OP_BUY, "long", "short") +" position erreicht: "+ DoubleToStr(ifDouble(last.type==OP_BUY, last.openPrice-Bid, Ask-last.openPrice)/Pip, 1) +" pip");

   for (int i=0; i < sequenceLength; i++) {
      if (levels.ticket[i] > 0) /*&&*/ if (levels.closeTime[i] == 0) {
         if (!OrderCloseEx(levels.ticket[i], NULL, NULL, 1, Orange)) {
            status = STATUS_DISABLED;
            return(last_error);                                      // TODO: später durch stdlib_PeekLastError() ersetzen
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

   if (!ReadStatus()) {
      status = STATUS_DISABLED;
      return(last_error);
   }
   return(catch("FinishSequence(2)"));
}


/**
 * @param  int    type    - Ordertyp: OP_BUY | OP_SELL
 * @param  double lotsize - Lotsize der Order (variiert je nach Progression-Level und Hedging-Fähigkeit des Accounts)
 *
 * @return int - Ticket der neuen Position oder -1, falls ein Fehler auftrat
 */
int OpenPosition(int type, double lotsize) {
   if (type!=OP_BUY && type!=OP_SELL)
      return(catch("OpenPosition(1)   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (LE(lotsize, 0))
      return(catch("OpenPosition(2)   illegal parameter lotsize = "+ NumberToStr(lotsize, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE));

   int    magicNumber = CreateMagicNumber();
   string comment     = "FTP."+ sequenceId +"."+ progressionLevel;
   int    slippage    = 1;
   color  markerColor = ifInt(type==OP_BUY, Blue, Red);

   int ticket = OrderSendEx(Symbol(), type, lotsize, NULL, slippage, NULL, NULL, comment, magicNumber, NULL, markerColor);

   if (ticket!=-1) /*&&*/ if (catch("OpenPosition(3)")!=NO_ERROR)
      ticket = -1;
   return(ticket);
}


/**
 * Gibt die Lotsize des aktuellen Progression-Levels zurück.
 *
 * @return double - Lotsize oder -1, wenn ein Fehler auftrat
 */
double CurrentLotSize() {
   switch (progressionLevel) {
      case  0: return(0);
      case  1: return(Lotsize.Level.1);
      case  2: return(Lotsize.Level.2);
      case  3: return(Lotsize.Level.3);
      case  4: return(Lotsize.Level.4);
      case  5: return(Lotsize.Level.5);
      case  6: return(Lotsize.Level.6);
      case  7: return(Lotsize.Level.7);
      case  8: return(Lotsize.Level.8);
      case  9: return(Lotsize.Level.9);
      case 10: return(Lotsize.Level.10);
      case 11: return(Lotsize.Level.11);
      case 12: return(Lotsize.Level.12);
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
   string msg = "";

   switch (status) {
      case STATUS_INITIALIZED:     msg = ":  waiting";                                                         break;
      case STATUS_WAIT_ENTRYLIMIT: msg = ":  waiting for entry limit "+ NumberToStr(Entry.Limit, PriceFormat); break;
      case STATUS_PROGRESSING:     msg = ":  trade sequence "+ sequenceId;                                     break;
      case STATUS_FINISHED:        msg = ":  trade sequence "+ sequenceId +" finished";                        break;
      case STATUS_DISABLED:        msg = ":  inactive";                                                        break;
      default:
         return(catch("ShowStatus(1)   illegal sequence status = "+ status, ERR_RUNTIME_ERROR));
   }

   msg = __SCRIPT__ + msg + NL
                          + NL
       +"Progression Level:  "+ progressionLevel +" / "+ sequenceLength;

   if (progressionLevel > 0)
      msg = msg +"  =  "+ NumberToStr(CurrentLotSize(), ".+") +" lot";

   msg = msg                                                                                  + NL
       +"TakeProfit:            "+ TakeProfit +" pip"                                         + NL
       +"StopLoss:               "+ StopLoss +" pip"                                          + NL
     //+"Breakeven:           "+ "-"                                                          + NL
       +"Profit / Loss:          "+ DoubleToStr(all.profits + all.commissions + all.swaps, 2) + NL;

   // 2 Zeilen Abstand nach oben für Instrumentanzeige
   Comment(NL + NL + msg);

   return(catch("ShowStatus(2)"));
}

