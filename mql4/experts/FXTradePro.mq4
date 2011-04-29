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


#define RESULT_UNKNOWN                 0
#define RESULT_TAKEPROFIT              1
#define RESULT_STOPLOSS                2
#define RESULT_WINNER                  3
#define RESULT_LOOSER                  4
#define RESULT_BREAKEVEN               5

#define STATUS_ENTRYLIMIT_WAIT         1
#define STATUS_FINISHED                2
#define STATUS_UNSUFFICIENT_BALANCE    3
#define STATUS_UNSUFFICIENT_EQUITY     4


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string _1____________________________ = "==== Entry Options ==============";
//extern string Entry.Direction                = "{ long | short }";
extern string Entry.Direction                = "long";
extern double Entry.Limit                    = 0;

extern string _2____________________________ = "==== TP and SL Settings =========";
extern int    TakeProfit                     = 40;
extern int    Stoploss                       = 10;

extern string _3____________________________ = "==== Lotsizes ==================";
extern double Lotsize.Level.1                =  0.1;
extern double Lotsize.Level.2                =  0.1;
extern double Lotsize.Level.3                =  0.2;
extern double Lotsize.Level.4                =  0.3;
extern double Lotsize.Level.5                =  0.4;
extern double Lotsize.Level.6                =  0.6;
extern double Lotsize.Level.7                =  0.8;
extern double Lotsize.Level.8                =  1.1;
extern double Lotsize.Level.9                =  1.5;
extern double Lotsize.Level.10               =  2.0;
extern double Lotsize.Level.11               =  2.7;
extern double Lotsize.Level.12               =  3.6;

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
int    openPositions, closedPositions;

int    lastPosition.ticket, last_ticket;     // !!! last_ticket ist nicht statisch und verursacht Fehler bei Timeframe-Wechseln etc.
int    lastPosition.type = OP_UNDEFINED;
double lastPosition.lots;
int    lastPosition.result;

int    breakevenDistance;                    // Gewinnschwelle in Pip, ab der der StopLoss der Position auf BreakEven gesetzt wird
int    trailingStop;                         // TrailingStop in Pip
bool   trailStopImmediately = true;          // TrailingStop sofort starten oder warten, bis Position <trailingStop> Pip im Gewinn ist

double minAccountBalance;                    // Balance-Minimum, um zu traden
double minAccountEquity;                     // Equity-Minimum, um zu traden


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   PipDigits   = Digits - Digits%2;
   Pip         = 1 / MathPow(10, PipDigits);
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
   if (Entry.Limit < 0)
      return(catch("init(3)  Invalid input parameter Entry.Limit = "+ NumberToStr(Entry.Limit, ".+"), ERR_INVALID_INPUT_PARAMVALUE));

   // TakeProfit
   if (TakeProfit < 1)
      return(catch("init(4)  Invalid input parameter TakeProfit = "+ TakeProfit, ERR_INVALID_INPUT_PARAMVALUE));

   // Stoploss
   if (Stoploss < 1)
      return(catch("init(5)  Invalid input parameter Stoploss = "+ Stoploss, ERR_INVALID_INPUT_PARAMVALUE));

   // Lotsizes
   if (Lotsize.Level.1 <= 0) return(catch("init(6)  Invalid input parameter Lotsize.Level.1 = "+ NumberToStr(Lotsize.Level.1, ".+"), ERR_INVALID_INPUT_PARAMVALUE));

   if (Lotsize.Level.2 <  0) return(catch("init(7)  Invalid input parameter Lotsize.Level.2 = "+ NumberToStr(Lotsize.Level.2, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
   if (Lotsize.Level.2 == 0) sequenceLength = 1;
   else {
      if (Lotsize.Level.3 <  0) return(catch("init(8)  Invalid input parameter Lotsize.Level.3 = "+ NumberToStr(Lotsize.Level.3, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
      if (Lotsize.Level.3 == 0) sequenceLength = 2;
      else {
         if (Lotsize.Level.4 <  0) return(catch("init(9)  Invalid input parameter Lotsize.Level.4 = "+ NumberToStr(Lotsize.Level.4, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
         if (Lotsize.Level.4 == 0) sequenceLength = 3;
         else {
            if (Lotsize.Level.5 <  0) return(catch("init(10)  Invalid input parameter Lotsize.Level.5 = "+ NumberToStr(Lotsize.Level.5, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
            if (Lotsize.Level.5 == 0) sequenceLength = 4;
            else {
               if (Lotsize.Level.6 <  0) return(catch("init(11)  Invalid input parameter Lotsize.Level.6 = "+ NumberToStr(Lotsize.Level.6, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
               if (Lotsize.Level.6 == 0) sequenceLength = 5;
               else {
                  if (Lotsize.Level.7 <  0) return(catch("init(12)  Invalid input parameter Lotsize.Level.7 = "+ NumberToStr(Lotsize.Level.7, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                  if (Lotsize.Level.7 == 0) sequenceLength = 6;
                  else {
                     if (Lotsize.Level.8 <  0) return(catch("init(13)  Invalid input parameter Lotsize.Level.8 = "+ NumberToStr(Lotsize.Level.8, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                     if (Lotsize.Level.8 == 0) sequenceLength = 7;
                     else {
                        if (Lotsize.Level.9 <  0) return(catch("init(14)  Invalid input parameter Lotsize.Level.9 = "+ NumberToStr(Lotsize.Level.9, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                        if (Lotsize.Level.9 == 0) sequenceLength = 8;
                        else {
                           if (Lotsize.Level.10 <  0) return(catch("init(15)  Invalid input parameter Lotsize.Level.10 = "+ NumberToStr(Lotsize.Level.10, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                           if (Lotsize.Level.10 == 0) sequenceLength = 9;
                           else {
                              if (Lotsize.Level.11 <  0) return(catch("init(16)  Invalid input parameter Lotsize.Level.11 = "+ NumberToStr(Lotsize.Level.11, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                              if (Lotsize.Level.11 == 0) sequenceLength = 10;
                              else {
                                 if (Lotsize.Level.12 <  0) return(catch("init(17)  Invalid input parameter Lotsize.Level.12 = "+ NumberToStr(Lotsize.Level.12, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
                                 if (Lotsize.Level.12 == 0) sequenceLength = 11;
                                 else                       sequenceLength = 12;
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

   // aktuellen Status einlesen und auswerten
   if (ReadOrderStatus()) {
      // im Markt, Position managen
   }
   else {
      // nicht im Markt, Entry.Limit prüfen
      if (CompareDoubles(Entry.Limit, 0)) {  // kein Limit definiert
         StartSequence();
      }
      else {
         // Limit definiert, Limit erreicht ?
         //    nein) warten
         //    ja)   in Entry.Direction in den Markt gehen
      }
   }
   ShowStatus();




   if (false && NewOrderPermitted()) {
      if (openPositions == 0) {
         if (lastPosition.type==OP_UNDEFINED) {
                                            // SendOrder(entryDirection);
         }
         else if (Progressing()) {
            // if (lastPosition.type==OP_SELL) SendOrder(OP_BUY);
            // else                            SendOrder(OP_SELL);
         }
      }
      ShowStatus();
   }
   last_ticket = lastPosition.ticket;

   return(catch("start()"));
}


/**
 * TODO: Im Moment wird nach der ersten gefundenen Order des EA's abgebrochen !!!
 *
 *
 * Liest die Orderdaten der im Moment laufenden Sequenzen im aktuellen Instrument ein.
 *
 * @return bool - ob im Moment eine Sequenz aktiv ist oder nicht
 */
bool ReadOrderStatus() {
   sequenceId = 0;

   int orders = OrdersTotal();

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))   // FALSE ist rein theoretisch: während des Auslesens wird eine Order geschlossen/gestrichen und verschwindet
         break;
      if (IsMyOrder()) {
         open.ticket      = OrderTicket();
         open.type        = OrderType();
         open.time        = OrderOpenTime();
         open.price       = OrderOpenPrice();
         open.lots        = OrderLots();
         open.swap        = OrderSwap();
         open.commission  = OrderCommission();
         open.profit      = OrderProfit();
         open.magic       = OrderMagicNumber();
         open.comment     = OrderComment();
                                                                  // in MagicNumber: 10 Bits 23-32 => EA.uniqueId
         sequenceId       = OrderMagicNumber() << 10 >> 18;       // in MagicNumber: 14 Bits  9-22
         sequenceLength   = OrderMagicNumber() << 24 >> 28;       // in MagicNumber:  4 Bits  5-8
         progressionLevel = OrderMagicNumber() << 28 >> 32;       // in MagicNumber:  4 Bits  1-4

         log("ReadOrderStatus()   active sequence found = "+ sequenceId);
         break;
      }
   }

   /*
   // closedPositions
   closedPositions = 0;
   for (i=OrdersHistoryTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
      if (IsMyOrder()) {
         closedPositions++;
                                                                        lastPosition.ticket = OrderTicket();
                                                                        lastPosition.type   = OrderType();
                                                                        lastPosition.lots   = OrderLots();
         if      (CompareDoubles(OrderClosePrice(), OrderTakeProfit())) lastPosition.result = RESULT_TAKEPROFIT;
         else if (CompareDoubles(OrderClosePrice(), OrderStopLoss()))   lastPosition.result = RESULT_STOPLOSS;
         else if (OrderProfit() > 0)                                    lastPosition.result = RESULT_WINNER;
         else if (OrderProfit() < 0)                                    lastPosition.result = RESULT_LOOSER;
         else                                                           lastPosition.result = RESULT_BREAKEVEN;
      }
   }
   */

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("ReadOrderStatus()", error);
      return(false);
   }
   return(sequenceId != 0);
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
   int ea       = EA.uniqueId << 22;               // 10 bit (0-1023)                                      | in MagicNumber: Bits 23-32
   int sequence = sequenceId  << 18 >> 10;         // Bits größer 14 löschen und Wert auf 22 Bit erweitern | in MagicNumber: Bits  9-22
   int length   = sequenceLength << 4;             // 4 bit (1-12), auf 8 bit erweitern                    | in MagicNumber: Bits  5-8
   int level    = progressionLevel;                // 4 bit (1-12)                                         | in MagicNumber: Bits  1-4

   return(ea + sequence + length + level);         // alles addieren
}


/**
 * Gibt die ID der aktuellen Sequenz zurück. Existiert noch keine ID, wird eine neue generiert.
 *
 * @return int - Sequenze-ID im Bereich 1000-16383 (14 bit)
 */
int SequenceId() {
   if (sequenceId == 0) {              // Bei Timeframe-Wechseln wird die ID durch ReadOrderStatus() anhand der offenen Postion gesetzt.
      MathSrand(GetTickCount());       // Ohne Position kann sie problemlos jedesmal neu generiert werden.

      while (sequenceId < 2002) {      // das spätere Shiften eines Bits halbiert den Wert und wir wollen mindestens eine 4-stellige ID
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
      return(catch("StartSequence(1)  Cannot start multiple sequences, current active sequence ="+ sequenceId, ERR_RUNTIME_ERROR));

   if (NewOrderPermitted())
      SendOrder(entryDirection);    // Position in Entry.Direction öffnen

   return(catch("StartSequence()"));
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
 *
 * @return int - Fehlerstatus
 */
int SendOrder(int type) {
   if (type!=OP_BUY && type!=OP_SELL)
      return(catch("SendOrder(1)   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE));

   int sequenceId  = SequenceId();
   int level       = CurrentLevel();
   int magicNumber = MagicNumber(sequenceId);

   double   price      = ifDouble(type==OP_SELL, Bid, Ask);
   double   lotsize    = CurrentLotSize();
   int      slippage   = 1;
   double   sl         = 0;
   double   tp         = 0;
   string   comment    = "FTP."+ sequenceId +"."+ level;
   datetime expiration = 0;

   log("SendOrder()   OrderSend("+ Symbol()+ ", "+ OperationTypeDescription(type) +", "+ NumberToStr(lotsize, ".+") +" lot, price="+ NumberToStr(price, PriceFormat) +", slippage="+ NumberToStr(slippage, ".+") +", sl="+ NumberToStr(sl, PriceFormat) +", tp="+ NumberToStr(tp, PriceFormat) +", comment=\""+ comment +"\", magic="+ magicNumber +", expires="+ expiration +", Green)");

   if (true) {
      int ticket = OrderSend(Symbol(), type, lotsize, price, slippage, sl, tp, comment, magicNumber, expiration, Green);
      if (ticket > 0) {
         if (OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
            log("SendOrder()   Progression level "+ level +" ("+ NumberToStr(lotsize, ".+") +" lot) - "+ OperationTypeDescription(type) +" at "+ NumberToStr(OrderOpenPrice(), PriceFormat));
      }
      else return(catch("SendOrder(2)   error opening "+ OperationTypeDescription(type) +" order"));
   }

   return(catch("SendOrder(3)"));
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
               if (OrderStopLoss() > Ask + trailingStop*Pip || CompareDoubles(OrderStopLoss(), 0))
                  OrderModify(OrderTicket(), OrderOpenPrice(), Ask + trailingStop*Pip, OrderTakeProfit(), 0, Red);
         }
      }
   }
   return(catch("TrailingStopManager()"));
}


/**
 * Gibt den aktuellen Progression-Level zurück.
 *
 * @return int - Progression-Level
 */
int CurrentLevel() {
   int level = 1;
   return(level);
}


/**
 * Setzt den aktuellen Progression-Level auf die nächste Stufe.
 *
 * @return int - der resultierende Progression-Level
 */
int IncreaseProgressionLevel() {
   int level = 1;
   level++;
   return(level);
}


/**
 * Gibt die Lotsize des aktuellen Progression-Levels zurück.
 *
 * @return double - Lotsize oder -1, wenn ein Fehler auftrat
 */
double CurrentLotSize() {
   int level = CurrentLevel();

   switch (level) {
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

   catch("CurrentLotSize()   illegal progression level = "+ level, ERR_RUNTIME_ERROR);
   return(-1);
}


/**
 *
 * @return int - Fehlerstatus
 */
int ShowStatus(int id=NULL) {
   string msg = "";

   switch (id) {
      case NULL                       : msg = "";                                                break;
      case STATUS_ENTRYLIMIT_WAIT     : msg = " waiting for entry limit";                        break;
      case STATUS_FINISHED            : msg = ":  Trading sequence finished.";                   break;
      case STATUS_UNSUFFICIENT_BALANCE: msg = ":  New orders disabled (balance below minimum)."; break;
      case STATUS_UNSUFFICIENT_EQUITY : msg = ":  New orders disabled (equity below minimum)." ; break;
   }

   string status = __SCRIPT__ + msg + LF
                 + LF
                 + "Progression Level:  "+ CurrentLevel() +" / "+ sequenceLength +"  =  "+ NumberToStr(CurrentLotSize(), ".+") +" lot" + LF
                 + "TakeProfit:            "+ TakeProfit +" pip"                                                + LF
                 + "Stoploss:               "+ Stoploss +" pip"                                                 + LF
                 + "Breakeven:           "+ NumberToStr(Bid, PriceFormat)                                       + LF
                 + "Profit / Loss:          "+ DoubleToStr(0, 2)                                                + LF;
   // 2 Zeilen Abstand nach oben für Instrumentanzeige
   Comment(LF+LF+ status);

   return(catch("ShowStatus(2)"));

   if (false) {
      BreakevenManager();
      TrailingStopManager();
      NewClosedPosition();
      IncreaseProgressionLevel();
   }
}


/**
 *
 */
bool NewClosedPosition() {
   return(lastPosition.ticket!=last_ticket && last_ticket!=0);
}


/**
 *
 */
bool Progressing() {
   if (CompareDoubles(CurrentLotSize(), 0)) {
      ShowStatus(STATUS_FINISHED);
      return(false);
   }

   if (lastPosition.result == RESULT_STOPLOSS)
      return(true);

   return(false);
}
