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

int EA.uniqueId = 101;           // eindeutige ID dieses EA's im Bereich 0-1023

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

int      levels.ticket[],     current.ticket;
int      levels.type[],       current.type;
double   levels.price[],      current.price;
double   levels.lots[],       current.lots;
double   levels.swap[],       current.swap,       all.swaps;
double   levels.commission[], current.commission, all.commissions;
double   levels.profit[],     current.profit,     all.profits;
datetime levels.closeTime[],  current.closeTime;

// -------------------------------------------------------------

double   minAccountBalance;                  // Balance-Minimum, um zu traden
double   minAccountEquity;                   // Equity-Minimum, um zu traden


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

   if (ReadStatus(sequenceId) == -1)
      return(last_error);

   if (sequenceId == 0) {                                                  // keine Sequenz aktiv
      if (EQ(Entry.Limit, 0)) {                                            // kein Limit definiert
         StartSequence();
      }
      else if (entryDirection == OP_BUY) {                                 // Limit definiert
         if (LE(Ask, Entry.Limit))              StartSequence();           // Buy-Limit erreicht
      }
      else {
         if (GE(Bid, Entry.Limit))              StartSequence();           // Sell-Limit erreicht
      }
   }
   else {                                                                  // aktive Sequenz gefunden
      if (IsStopLossReached()) {                                           // StopLoss erreicht
         if (progressionLevel < sequenceLength) IncreaseProgression();     // auf nächsten Level wechseln ...
         else                                   FinishSequence();          // ... oder Sequenz beenden
      }
      else if (IsProfitTargetReached())         FinishSequence();          // TakeProfit erreicht, Sequenz beenden
   }

   return(catch("start()"));
}


/**
 * TODO: Ohne Angabe eines Tickets wird nach der ersten gefundenen Sequenz des EA's abgebrochen, theoretisch sind aber mehrere
 *       aktive Sequenzen je Instrument möglich!
 *
 * Liest den Status einer aktiven Sequenz im aktuellen Instrument ein. Wird *keine* ID angegeben, werden alle offenen Positionen
 * auf eine aktive Sequenz überprüft. Wird eine ID angegeben, wird nur der Status dieser Sequenz eingelesen.
 *
 * @param  int sequence - ID einer aktiven Sequenz (default: NULL)
 *
 * @return int - Sequenz-ID oder 0, wenn keine Sequenz aktiv ist bzw. -1, wenn ein Fehler auftrat
 */
int ReadStatus(int sequence = NULL) {
   int orders = OrdersTotal();

   // falls keine Sequenz angegeben wurde, erste aktive Sequenz finden
   if (sequence == NULL) {
      for (int i=0; i < orders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))         // FALSE ist rein theoretisch: während des Auslesens wird eine aktive Order geschlossen oder gestrichen
            break;
         if (IsMyOrder()) {
            sequence = OrderMagicNumber() << 10 >> 18;            // 14 Bits  9-22 => sequenceId
            break;
         }
      }
   }

   if (sequence == NULL) {                                        // keine Sequenz angegeben und auch keine aktive Sequenz gefunden
      // globale Variablen zurücksetzen
      sequenceId       = 0;
      progressionLevel = 0;
   }
   else {
      // alle offenen Positionen der Sequenz einlesen
      sequenceId      = sequence;
      all.swaps       = 0;
      all.commissions = 0;
      all.profits     = 0;

      for (i=0; i < orders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))         // FALSE ist rein theoretisch: während des Auslesens wird eine aktive Order geschlossen oder gestrichen
            break;
         if (IsMyOrder(sequenceId)) {
            sequenceLength = OrderMagicNumber() & 0x00F0 >> 4;    //  4 Bits  5-8
            int n          = OrderMagicNumber() & 0x000F;         //  4 Bits  1-4
            if (n > progressionLevel)
               progressionLevel = n;

            if (ArraySize(levels.ticket) != sequenceLength) {
               ArrayResize(levels.ticket    , sequenceLength);
               ArrayResize(levels.type      , sequenceLength);
               ArrayResize(levels.price     , sequenceLength);
               ArrayResize(levels.lots      , sequenceLength);
               ArrayResize(levels.swap      , sequenceLength);
               ArrayResize(levels.commission, sequenceLength);
               ArrayResize(levels.profit    , sequenceLength);
               ArrayResize(levels.closeTime , sequenceLength);
            }
            n--;
            levels.ticket    [n] = OrderTicket();
            levels.type      [n] = OrderType();
            levels.price     [n] = OrderOpenPrice();
            levels.lots      [n] = OrderLots();
            levels.swap      [n] = OrderSwap();       all.swaps       += levels.swap      [n];
            levels.commission[n] = OrderCommission(); all.commissions += levels.commission[n];
            levels.profit    [n] = OrderProfit();     all.profits     += levels.profit    [n];
            levels.closeTime [n] = OrderCloseTime();              // Unterscheidung zwischen offenen und geschlossenen Positionen

         }
      }
      if (progressionLevel > 0) {
         i = progressionLevel-1;
         current.ticket     = levels.ticket    [i];
         current.type       = levels.type      [i];
         current.price      = levels.price     [i];
         current.lots       = levels.lots      [i];
         current.swap       = levels.swap      [i];
         current.commission = levels.commission[i];
         current.profit     = levels.profit    [i];
         current.closeTime  = levels.closeTime [i];
      }

      // versuchen, fehlende Positionen aus der Trade-History auszulesen
   }

   ShowStatus();

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("ReadStatus(3)", error);
      return(-1);
   }
   return(sequenceId);
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
            return(sequenceId == OrderMagicNumber() << 10 >> 18);    // 14 Bits  9-22 => sequenceId
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
   if (sequenceId == 0) {                    // Bei Timeframe-Wechseln wird die ID durch ReadStatus() aus der offenen Position ausgelesen.
      MathSrand(GetTickCount());             // Ohne offene Position kann sie jedesmal problemlos neu generiert werden.

      while (sequenceId < 2000) {            // Das spätere Shiften eines Bits halbiert den Wert und wir wollen mindestens eine 4-stellige ID.
         sequenceId = MathRand();
      }
      sequenceId >>= 1;
   }
   return(sequenceId);
}


/**
 * Ob der eingestellte StopLoss erreicht oder überschritten wurde.
 *
 * @return bool
 */
bool IsStopLossReached() {
   if (current.type == OP_BUY)
      return(LE(Bid, current.price - StopLoss*Pip));

   if (current.type == OP_SELL)
      return(GT(Ask, current.price + StopLoss*Pip));

   catch("IsStopLossReached()   illegal value for variable current.type = "+ current.type, ERR_RUNTIME_ERROR);
   return(false);
}


/**
 * Ob der eingestellte TakeProfit-Level erreicht oder überschritten wurde.
 *
 * @return bool
 */
bool IsProfitTargetReached() {
   if (current.type == OP_BUY)
      return(GE(Bid, current.price + TakeProfit*Pip));

   if (current.type == OP_SELL)
      return(LE(Ask, current.price - TakeProfit*Pip));

   catch("IsProfitTargetReached()   illegal value for variable current.type = "+ current.type, ERR_RUNTIME_ERROR);
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

   if (!NewOrderPermitted())                                               // Moneymanagement verbietet weitere Orders
      return(last_error);

   int ticket = SendOrder(entryDirection);                                 // Position in Entry.Direction öffnen
   if (ticket == -1)
      return(last_error);

   if (ReadStatus(sequenceId) == -1)                                       // Status neu einlesen
      return(last_error);

   return(catch("StartSequence(2)"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int IncreaseProgression() {
   debug("IncreaseProgression()   StopLoss für "+ OperationTypeDescription(current.type) +" erreicht: "+ DoubleToStr(ifDouble(current.type==OP_BUY, current.price-Bid, Ask-current.price)/Pip, 1) +" pip");

   // ClosePosition();

   progressionLevel++;

   if (!NewOrderPermitted())
      return(last_error);

   int ticket = SendOrder(ifInt(current.type==OP_SELL, OP_BUY, OP_SELL));  // nächste Position öffnen
   if (ticket == -1)
      return(last_error);

   if (ReadStatus(sequenceId) == -1)                                          // Status neu einlesen
      return(last_error);

   return(catch("IncreaseProgression()"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int FinishSequence() {
   debug("FinishSequence()   TakeProfit für "+ OperationTypeDescription(current.type) +" erreicht: "+ DoubleToStr(ifDouble(current.type==OP_BUY, Bid-current.price, current.price-Ask)/Pip, 1) +" pip");

   // ClosePosition();

   ShowStatus(STATUS_FINISHED);

   return(catch("FinishSequence()"));
}


/**
 *
 * @return int - Ticket der neuen Position oder -1, falls ein Fehler auftrat
 */
int SendOrder(int type) {
   if (type!=OP_BUY && type!=OP_SELL)
      return(catch("SendOrder(1)   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE));

   int    sequenceId  = SequenceId();
   int    magicNumber = MagicNumber(sequenceId);
   double lotsize     = CurrentLotSize();
   string comment     = "FTP."+ sequenceId +"."+ progressionLevel;
   int    slippage    = 1;

   int ticket = OrderSendEx(Symbol(), type, lotsize, NULL, slippage, NULL, NULL, comment, magicNumber, NULL, Green);

   if (ticket!=-1) /*&&*/ if (catch("SendOrder(2)")!=NO_ERROR)
      ticket = -1;
   return(ticket);
}


/**
 * Prüft den Account nach Moneymanagement-Gesichtspunkten (Balance, Equity, Marginanforderungen, Leverage) und gibt an,
 * ob die nächste Order ausgeführt werden darf.
 */
bool NewOrderPermitted() {
   if (progressionLevel > sequenceLength) {
      catch("NewOrderPermitted()   illegal progressionLevel = "+ progressionLevel +" (sequenceLength="+ sequenceLength +")", ERR_RUNTIME_ERROR);
      return(false);
   }
   if (AccountBalance() < minAccountBalance) {
      ShowStatus(STATUS_UNSUFFICIENT_BALANCE);
      last_error = ERR_NOT_ENOUGH_MONEY;
      return(false);
   }
   if (AccountEquity() < minAccountEquity) {
      ShowStatus(STATUS_UNSUFFICIENT_EQUITY);
      last_error = ERR_NOT_ENOUGH_MONEY;
      return(false);
   }
   return(true);
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
      case NULL: if (sequenceId != 0)         msg = ":  trade sequence "+ sequenceId +", #"+ current.ticket;
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
             +"Breakeven:           "+ NumberToStr(Bid, PriceFormat)                                + NL
             +"Profit / Loss:          "+ DoubleToStr(all.profits + all.commissions + all.swaps, 2) + NL;
   }

   // 2 Zeilen Abstand nach oben für Instrumentanzeige
   Comment(NL + NL + status);

   return(catch("ShowStatus(2)"));
}
