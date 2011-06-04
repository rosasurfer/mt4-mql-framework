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

int EA.uniqueId = 101;           // eindeutige ID dieses EA's (im Bereich 0-1023)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#include <stdlib.mqh>


#define STATUS_INACTIVE                1
#define STATUS_FINISHED                2
#define STATUS_UNSUFFICIENT_BALANCE    3
#define STATUS_UNSUFFICIENT_EQUITY     4


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string _1____________________________ = "==== Entry Options ===================";
//extern string Entry.Direction                = "{ long | short }";
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


double   Pip;
int      PipDigits;
string   PriceFormat;

int      sequenceId;
int      sequenceLength;
int      progressionLevel;
int      entryDirection = OP_UNDEFINED;

int      levels.ticket    [], last.ticket;
int      levels.type      [], last.type;
double   levels.openPrice [], last.openPrice;
double   levels.lotsize   [], last.lotsize;
double   levels.swap      [], last.swap,       all.swaps;
double   levels.commission[], last.commission, all.commissions;
double   levels.profit    [], last.profit,     all.profits;
datetime levels.closeTime [], last.closeTime;


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

   // Parameter überprüfen
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

   // nicht auf den nächsten Tick warten sondern sofort start() aufrufen
   SendTick(false);

   return(catch("init(18)"));
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

   if (ReadStatus(sequenceId) != NO_ERROR)
      return(last_error);

   if (sequenceId == 0) {                                               // keine Sequenz aktiv
      if (IsEntryLimitReached())             StartSequence();           // Limit erreicht oder kein Limit definiert
   }
   else if (IsStopLossReached()) {                                      // aktive Sequenz gefunden, wenn StopLoss erreicht ...
      if (progressionLevel < sequenceLength) IncreaseProgression();     // auf nächsten Level wechseln ...
      else                                   FinishSequence();          // ... oder Sequenz beenden
   }
   else if (IsProfitTargetReached())         FinishSequence();          // wenn TakeProfit erreicht -> Sequenz beenden

   return(catch("start()"));
}


/**
 * Liest den Status einer aktiven Sequenz im aktuellen Instrument ein. Wird *keine* ID angegeben, werden alle offenen Positionen
 * auf eine aktive Sequenz überprüft. Wird eine ID angegeben, wird nur der Status dieser Sequenz eingelesen.
 *
 * @param  int sequence - ID einer aktiven Sequenz (default: NULL)
 *
 * @return int - Fehlerstatus
 *
 *
 * TODO: Ohne Angabe einer Sequenz wird immer die erste gefundene Sequenz ausgelesen. Theoretisch sind jedoch mehrere aktive Sequenzen
 *       je Instrument möglich und für diesen Fall benötigen wir eine Auswahlmöglichkeit.
 */
int ReadStatus(int sequence = NULL) {
   int orders = OrdersTotal();

   // falls keine Sequenz angegeben wurde, die erste aktive Sequenz finden
   if (sequence == NULL) {
      for (int i=0; i < orders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wird in einem anderen Thread eine aktive Order geschlossen oder gestrichen
            break;
         if (IsMyOrder()) {
            sequence = OrderMagicNumber() << 10 >> 18;                  // 14 Bits  9-22 => sequenceId
            break;
         }
      }
   }

   if (sequence == NULL) {                                              // keine Sequenz angegeben und auch keine aktive Sequenz gefunden
      // globale Variablen zurücksetzen
      sequenceId       = 0;
      progressionLevel = 0;
   }
   else {
      // alle offenen Positionen der Sequenz einlesen
      int n;                                                            // Hedge-Erkennung: Anzahl der offenen Positionen
      sequenceId      = sequence;
      all.swaps       = 0;
      all.commissions = 0;
      all.profits     = 0;

      for (i=0, n=0; i < orders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wird in einem anderen Thread eine aktive Order geschlossen oder gestrichen
            break;
         if (IsMyOrder(sequenceId)) {
            n++;
            sequenceLength = OrderMagicNumber() & 0x00F0 >> 4;          // 4 Bits  5-8
            int level      = OrderMagicNumber() & 0x000F;               // 4 Bits  1-4
            if (level > progressionLevel)
               progressionLevel = level;

            if (ArraySize(levels.ticket) != sequenceLength) {
               ArrayResize(levels.ticket    , sequenceLength);
               ArrayResize(levels.type      , sequenceLength);
               ArrayResize(levels.openPrice , sequenceLength);
               ArrayResize(levels.lotsize   , sequenceLength);
               ArrayResize(levels.swap      , sequenceLength);
               ArrayResize(levels.commission, sequenceLength);
               ArrayResize(levels.profit    , sequenceLength);
               ArrayResize(levels.closeTime , sequenceLength);
            }
            level--;
            levels.ticket    [level] = OrderTicket();
            levels.type      [level] = OrderType();
            levels.openPrice [level] = OrderOpenPrice();
            levels.lotsize   [level] = OrderLots();
            levels.swap      [level] = OrderSwap();       all.swaps       += levels.swap      [level];
            levels.commission[level] = OrderCommission(); all.commissions += levels.commission[level];
            levels.profit    [level] = OrderProfit();     all.profits     += levels.profit    [level];
            levels.closeTime [level] = OrderCloseTime();                // Unterscheidung zwischen offenen und geschlossenen Positionen
         }
      }

      // Lotsizes offener Hedges korrigieren
      if (n > 1) {
         double previous;
         for (i=0; i < sequenceLength; i++) {
            if (NE(previous, 0))
               levels.lotsize[i] = MathAbs(levels.lotsize[i] - previous);
            previous = levels.lotsize[i];
         }
      }

      // Daten der letzten Position in last.* speichern
      if (progressionLevel > 0) {
         i = progressionLevel-1;
         last.ticket     = levels.ticket    [i];
         last.type       = levels.type      [i];
         last.openPrice  = levels.openPrice [i];
         last.lotsize    = levels.lotsize   [i];
         last.swap       = levels.swap      [i];
         last.commission = levels.commission[i];
         last.profit     = levels.profit    [i];
         last.closeTime  = levels.closeTime [i];
      }

      // versuchen, fehlende Positionen aus der Trade-History auszulesen
   }

   ShowStatus();

   return(catch("ReadStatus()"));
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
 * Generiert aus der übergebenen Sequenz-ID und den internen Daten einen Wert für OrderMagicNumber()
 *
 * @param  int sequenceId - eindeutige ID der Trade-Sequenz
 *
 * @return int - magic number
 */
int MagicNumber(int sequenceId) {
   int ea       = EA.uniqueId << 22;                  // 10 bit (Bereich 0-1023)                              | in MagicNumber: Bits 23-32
   int sequence = sequenceId  << 18 >> 10;            // Bits größer 14 löschen und Wert auf 22 Bit erweitern | in MagicNumber: Bits  9-22
   int length   = sequenceLength   & 0x000F << 4;     // 4 bit (Bereich 1-12), auf 8 bit erweitern            | in MagicNumber: Bits  5-8
   int level    = progressionLevel & 0x000F;          // 4 bit (Bereich 1-12)                                 | in MagicNumber: Bits  1-4

   return(ea + sequence + length + level);
}


/**
 * Gibt die ID der aktuellen Sequenz zurück. Existiert noch keine ID, wird eine neue generiert.
 *
 * @return int - Sequenze-ID im Bereich 1000-16383 (14 bit)
 */
int SequenceId() {
   if (sequenceId == 0) {                 // Bei Timeframe-Wechseln wird die ID durch ReadStatus() aus der offenen Position ausgelesen.
      MathSrand(GetTickCount());          // Ohne offene Position kann sie jedesmal problemlos neu generiert werden.

      while (sequenceId < 2000) {         // Das spätere Shiften eines Bits halbiert den Wert und wir wollen mindestens eine 4-stellige ID.
         sequenceId = MathRand();
      }
      sequenceId >>= 1;
   }
   return(sequenceId);
}


/**
 * Ob das eingestellte EntryLimit erreicht oder überschritten wurde.  Wurde kein Limit definiert, gibt die Funktion immer TRUE zurück.
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
      return(GT(Ask, last.openPrice + StopLoss*Pip));

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
   if (sequenceId != 0)
      return(catch("StartSequence(1)  cannot start multiple sequences, current active sequence ="+ sequenceId, ERR_RUNTIME_ERROR));

   if (EQ(Entry.Limit, 0)) {                                               // kein Limit definiert, also Aufruf direkt nach Start
      PlaySound("notify.wav");
      int answer = MessageBox("Do you really want to start a new trade sequence?", __SCRIPT__, MB_ICONQUESTION|MB_OKCANCEL);
      if (answer != IDOK) {
         ShowStatus(STATUS_INACTIVE);
         last_error = ERR_COMMON_ERROR;
         return(last_error);
      }
   }

   progressionLevel = 1;

   int ticket = SendOrder(entryDirection, CurrentLotSize());               // Position in Entry.Direction öffnen
   if (ticket == -1)
      return(last_error);

   if (ReadStatus(sequenceId) != NO_ERROR)                                 // Status neu einlesen
      return(last_error);

   return(catch("StartSequence(2)"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int IncreaseProgression() {
   debug("IncreaseProgression()   StopLoss für "+ OperationTypeDescription(last.type) +" erreicht: "+ DoubleToStr(ifDouble(last.type==OP_BUY, last.openPrice-Bid, Ask-last.openPrice)/Pip, 1) +" pip");

   progressionLevel++;
   int    direction = ifInt(last.type==OP_SELL, OP_BUY, OP_SELL);
   double lotsize   = CurrentLotSize();

   // Je nach Hedging-Fähigkeit des Accounts die letzte Position schließen oder hedgen.
   bool hedgingEnabled = true;                                          // IsHedgingEnabled()

   if (hedgingEnabled) {
      int ticket = SendOrder(direction, last.lotsize + lotsize);        // nächste Position öffnen
      if (ticket == -1) {
         if (last_error != ERR_TRADE_HEDGE_PROHIBITED)
            return(last_error);
         hedgingEnabled = false;                                        // Fallback
      }
   }

   if (!hedgingEnabled) {
      // ClosePosition();
      ticket = SendOrder(direction, lotsize);                           // nächste Position öffnen
      if (ticket == -1)
         return(last_error);
   }

   if (ReadStatus(sequenceId) != NO_ERROR)                              // Status neu einlesen
      return(last_error);

   return(catch("IncreaseProgression()"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int FinishSequence() {
   if (IsProfitTargetReached()) debug("FinishSequence()   TakeProfit für "+ OperationTypeDescription(last.type) +" erreicht: "+ DoubleToStr(ifDouble(last.type==OP_BUY, Bid-last.openPrice, last.openPrice-Ask)/Pip, 1) +" pip");
   else                         debug("FinishSequence()   Letzter StopLoss für "+ OperationTypeDescription(last.type) +" erreicht: "+ DoubleToStr(ifDouble(last.type==OP_BUY, last.openPrice-Bid, Ask-last.openPrice)/Pip, 1) +" pip");

   // ClosePosition();

   ShowStatus(STATUS_FINISHED);

   return(catch("FinishSequence()"));
}


/**
 * @param  int    type    - Ordertyp: OP_BUY | OP_SELL
 * @param  double lotsize - Lotsize der Order (variiert je nach Progression-Level und Hedging-Fähigkeit des Accounts)
 *
 * @return int - Ticket der neuen Position oder -1, falls ein Fehler auftrat
 */
int SendOrder(int type, double lotsize) {
   if (type!=OP_BUY && type!=OP_SELL)
      return(catch("SendOrder(1)   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (LE(lotsize, 0))
      return(catch("SendOrder(2)   illegal parameter lotsize = "+ NumberToStr(lotsize, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE));

   int    sequenceId  = SequenceId();
   int    magicNumber = MagicNumber(sequenceId);
   string comment     = "FTP."+ sequenceId +"."+ progressionLevel;
   int    slippage    = 1;

   int ticket = OrderSendEx(Symbol(), type, lotsize, NULL, slippage, NULL, NULL, comment, magicNumber, NULL, Green);

   if (ticket!=-1) /*&&*/ if (catch("SendOrder(3)")!=NO_ERROR)
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
 *
 * @return int - Fehlerstatus
 */
int ShowStatus(int id=NULL) {
   string status=__SCRIPT__, msg="";

   switch (id) {
      case NULL: if (sequenceId != 0)         msg = ":  trade sequence "+ sequenceId +", #"+ last.ticket;
                 else if (EQ(Entry.Limit, 0)) msg = ":  waiting";
                 else                         msg = ":  waiting for entry limit "+ NumberToStr(Entry.Limit, PriceFormat); break;
      case STATUS_INACTIVE            :       msg = ":  inactive";                                                        break;
      case STATUS_FINISHED            :       msg = ":  trade sequence "+ sequenceId +" finished.";                       break;
      case STATUS_UNSUFFICIENT_BALANCE:       msg = ":  new orders disabled (balance below minimum).";                    break;
      case STATUS_UNSUFFICIENT_EQUITY :       msg = ":  new orders disabled (equity below minimum)." ;                    break;
      default:
         return(catch("ShowStatus(1)   illegal parameter id = "+ id, ERR_INVALID_FUNCTION_PARAMVALUE));
   }

      status = status + msg + NL + NL;

   if (progressionLevel == 0) {
      status = status
             +"Progression Level:  "+ progressionLevel +" / "+ sequenceLength + NL;
   }
   else {
      status = status
             +"Progression Level:  "+ progressionLevel +" / "+ sequenceLength +"  =  "+ NumberToStr(CurrentLotSize(), ".+") +" lot" + NL;
   }
      status = status
             +"TakeProfit:            "+ TakeProfit +" pip" + NL
             +"Stoploss:               "+ StopLoss +" pip"  + NL;

   if (sequenceId != 0) {
      status = status
             +"Breakeven:           "+ "-"                                 + NL
             +"Profit / Loss:          "+ DoubleToStr(all.profits + all.commissions + all.swaps, 2) + NL;
   }

   // 2 Zeilen Abstand nach oben für Instrumentanzeige
   Comment(NL + NL + status);

   return(catch("ShowStatus(2)"));
}
