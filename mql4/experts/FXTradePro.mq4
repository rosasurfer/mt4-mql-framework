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

int      open.ticket;
int      open.type;
datetime open.time;
double   open.price;
double   open.lots;
double   open.swap;
double   open.commission;
double   open.profit;
int      open.magic;
string   open.comment;

// -------------------------------------------------------------

int      breakevenDistance;                  // Gewinnschwelle in Pip, ab der der StopLoss der Position auf BreakEven gesetzt wird
int      trailingStop;                       // TrailingStop in Pip
bool     trailStopImmediately = true;        // TrailingStop sofort starten oder warten, bis Position <trailingStop> Pip im Gewinn ist

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

   if (ReadStatus() == -1)
      return(last_error);

   if (sequenceId == 0) {                                                        // keine aktive Sequenz gefunden
      if (EQ(Entry.Limit, 0)) {                                                  // kein Limit definiert
         StartSequence();
      }
      else if (entryDirection == OP_BUY) {                                       // Limit definiert
         if (LE(Ask, Entry.Limit)) StartSequence();                              // Buy-Limit erreicht
      }
      else {
         if (GE(Bid, Entry.Limit)) StartSequence();                              // Sell-Limit erreicht
      }
   }
   else {                                                                        // aktive Sequenz gefunden
      if (open.type == OP_BUY) {                                                 // Long-Position
         if      (LE(Bid, open.price - StopLoss*Pip  )) IncreaseProgression();   // StopLoss erreicht, auf nächsten Level wechseln (OP_SELL)
         else if (GE(Bid, open.price + TakeProfit*Pip)) FinishSequence();        // TakeProfit erreicht, Position schließen und Sequenz beenden
      }
      else {                                                                     // Short-Position
         if      (GT(Ask, open.price + StopLoss*Pip  )) IncreaseProgression();   // StopLoss erreicht, auf nächsten Level wechseln (OP_BUY)
         else if (LE(Ask, open.price - TakeProfit*Pip)) FinishSequence();        // TakeProfit erreicht, Position schließen und Sequenz beenden
      }
   }

   return(catch("start()"));
}


/**
 * TODO: Ohne Angabe eines Tickets wird noch nach der ersten gefundenen Position des EA's abgebrochen, theoretisch
 *       sind aber mehrere aktive Sequenzen im selben Instrument möglich !!!
 *
 * Liest den Status der im Moment aktiven Sequenz im aktuellen Instrument ein. Wird *kein* Ticket angegeben, werden
 * alle offenen Positionen auf eine aktive Sequenz überprüft. Wird ein Ticket angegeben, wird nur der Status der Sequenz,
 * zu der dieses Ticket gehört, eingelesen.
 *
 * @param  int ticket - Ticket der offenen Position einer aktiven Sequenz (default: NULL)
 *
 * @return int - ID einer aktiven Sequenz oder 0, wenn keine Sequenz aktiv ist bzw. -1, wenn ein Fehler auftrat
 */
int ReadStatus(int ticket = NULL) {
   open.ticket = 0;

   if (ticket == NULL) {
      int orders = OrdersTotal();

      for (int i=0; i < orders; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))   // FALSE ist rein theoretisch: während des Auslesens wird eine Order geschlossen/gestrichen und verschwindet
            break;
         if (IsMyOrder()) {
            open.ticket = OrderTicket();
            break;
         }
      }
   }
   else {
      if (!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) {
         int error = GetLastError();
         if (error == NO_ERROR)
            error = ERR_RUNTIME_ERROR;
         catch("ReadStatus(1)   cannot select ticket #"+ ticket, error);
         return(-1);
      }
      if (!IsMyOrder()) {
         error = GetLastError();
         if (error == NO_ERROR)
            error = ERR_RUNTIME_ERROR;
         catch("ReadStatus(2)   requested ticket #"+ ticket +" doesn't belong to "+ __SCRIPT__, error);
         return(-1);
      }
      open.ticket = ticket;
   }

   if (open.ticket == 0) {
      sequenceId       = 0;
      progressionLevel = 0;
   }
   else {
      open.type        = OrderType();
      open.time        = OrderOpenTime();
      open.price       = OrderOpenPrice();
      open.lots        = OrderLots();
      open.swap        = OrderSwap();
      open.commission  = OrderCommission();
      open.profit      = OrderProfit();
      open.magic       = OrderMagicNumber();
      open.comment     = OrderComment();
                                                               // 10 Bits 23-32 => EA.uniqueId
      sequenceId       = OrderMagicNumber() << 10 >> 18;       // 14 Bits  9-22 => sequenceId
      sequenceLength   = OrderMagicNumber() & 0x00F0 >> 4;     //  4 Bits  5-8  => sequenceLength
      progressionLevel = OrderMagicNumber() & 0x000F;          //  4 Bits  1-4  => progressionLevel
   }

   ShowStatus();

   error = GetLastError();
   if (error != NO_ERROR) {
      catch("ReadStatus(3)", error);
      return(-1);
   }
   return(sequenceId);
}


/**
 * Ob die aktuell selektierte Order von diesem EA erzeugt wurde.
 *
 * @return bool
 */
bool IsMyOrder() {
   if (OrderSymbol()==Symbol()) {
      if (OrderType()==OP_BUY || OrderType()==OP_SELL)
         return(OrderMagicNumber() >> 22 == EA.uniqueId);
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
 * Beginnt eine neue Trade-Sequenz (Progression-Level 1).
 *
 * @return int - Fehlerstatus
 */
int StartSequence() {
   if (sequenceId != 0)
      return(catch("StartSequence(1)  cannot start multiple sequences, current active sequence ="+ sequenceId, ERR_RUNTIME_ERROR));

   if (EQ(Entry.Limit, 0)) {                                            // kein Limit definiert, also Aufruf direkt nach Start
      PlaySound("notify.wav");
      int answer = MessageBox("Do you really want to start a new trade sequence?", __SCRIPT__, MB_ICONQUESTION|MB_OKCANCEL);
      if (answer != IDOK) {
         ShowStatus(STATUS_INACTIVE);
         last_error = ERR_COMMON_ERROR;
         return(last_error);
      }
   }

   if (!NewOrderPermitted()) {                                          // MM verbietet weitere Orders
      last_error = ERR_NOT_ENOUGH_MONEY;
      return(last_error);
   }

   progressionLevel = 1;

   int ticket = SendOrder(entryDirection);                              // Position in Entry.Direction öffnen
   if (ticket == -1)
      return(last_error);

   if (ReadStatus(ticket) == -1)                                        // Status neu einlesen
      return(last_error);

   return(catch("StartSequence(2)"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int IncreaseProgression() {
   debug("IncreaseProgression()");

   // ClosePosition();

   if (!NewOrderPermitted()) {                                          // MM verbietet weitere Orders
      last_error = ERR_NOT_ENOUGH_MONEY;
      return(last_error);
   }

   progressionLevel++;

   int ticket = SendOrder(ifInt(open.type==OP_SELL, OP_BUY, OP_SELL));  // nächste Position öffnen
   if (ticket == -1)
      return(last_error);

   if (ReadStatus(ticket) == -1)                                        // Status neu einlesen
      return(last_error);

   return(catch("IncreaseProgression()"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int FinishSequence() {

   debug("FinishSequence()");

   // ClosePosition();
   // CleanUp();

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

   debug("SendOrder()   "+ ticket +" = OrderSendEx("+ Symbol()+ ", "+ OperationTypeDescription(type) +", "+ NumberToStr(lotsize, ".+") +" lot, slippage="+ NumberToStr(slippage, ".+") +", magic="+ magicNumber +", comment=\""+ comment +"\", Green)");

   if (ticket!=-1) /*&&*/ if (catch("SendOrder(2)")!=NO_ERROR)
      ticket = -1;
   return(ticket);
}


/**
 * Prüft den Account nach Moneymanagement-Gesichtspunkten (Balance, Equity, Marginanforderungen, Leverage) und gibt an,
 * ob die nächste Order ausgeführt werden darf.
 */
bool NewOrderPermitted() {
   if (AccountBalance() < minAccountBalance) {
      ShowStatus(STATUS_UNSUFFICIENT_BALANCE);
      return(false);
   }
   if (AccountEquity() < minAccountEquity) {
      ShowStatus(STATUS_UNSUFFICIENT_EQUITY);
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
      case NULL: if (sequenceId != 0)         msg = ":  trade sequence "+ sequenceId +", #"+ open.ticket;
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
             +"Profit / Loss:          "+ DoubleToStr(open.profit + open.commission + open.swap, 2) + NL;
   }

   // 2 Zeilen Abstand nach oben für Instrumentanzeige
   Comment(NL + NL + status);

   return(catch("ShowStatus(2)"));
   BreakevenManager(); TrailingStopManager();
}


/**
 *
 * @return int - Fehlerstatus
 */
int BreakevenManager() {
   if (breakevenDistance <= 0)
      return(NO_ERROR);

   for (int i=0; i < OrdersTotal(); i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);

      if (IsMyOrder()) {
         if (OrderType()==OP_BUY) /*&&*/ if (OrderStopLoss() < OrderOpenPrice()) {
            if (Bid - OrderOpenPrice() >= breakevenDistance*Pip)
               OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice(), OrderTakeProfit(), 0, Green);
         }

         if (OrderType()==OP_SELL) /*&&*/ if (OrderStopLoss() > OrderOpenPrice()) {
            if (OrderOpenPrice() - Ask >= breakevenDistance*Pip)
               OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice(), OrderTakeProfit(), 0, Red);
         }
      }
   }
   return(catch("BreakEvenManager()"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int TrailingStopManager() {
   int orders = OrdersTotal();

   for (int i=0; i < orders; i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (IsMyOrder()) {
         if (OrderType() == OP_BUY) {
            if (trailStopImmediately || Bid - OrderOpenPrice() > trailingStop*Pip)
               if (OrderStopLoss() < Bid - trailingStop*Pip)
                  OrderModify(OrderTicket(), OrderOpenPrice(), Bid - trailingStop*Pip, OrderTakeProfit(), 0, Green);
         }

         if (OrderType() == OP_SELL) {
            if (trailStopImmediately || OrderOpenPrice() - Ask > trailingStop*Pip)
               if (OrderStopLoss() > Ask + trailingStop*Pip || EQ(OrderStopLoss(), 0))
                  OrderModify(OrderTicket(), OrderOpenPrice(), Ask + trailingStop*Pip, OrderTakeProfit(), 0, Red);
         }
      }
   }
   return(catch("TrailingStopManager()"));
}
