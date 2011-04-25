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


#define OP_NONE                       -1

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
extern double Lotsize.Level.13               =  4.7;
extern double Lotsize.Level.14               =  6.2;
extern double Lotsize.Level.15               =  8.0;
extern double Lotsize.Level.16               = 10.2;
extern double Lotsize.Level.17               = 13.0;
extern double Lotsize.Level.18               = 16.5;
extern double Lotsize.Level.19               = 20.8;
extern double Lotsize.Level.20               = 26.3;
extern double Lotsize.Level.21               = 33.1;
extern double Lotsize.Level.22               = 41.6;
extern double Lotsize.Level.23               = 52.2;
extern double Lotsize.Level.24               = 65.5;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double Pip;
int    PipDigits;
string PriceFormat;

int    entryDirection;

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

int    lastPosition.ticket, last_ticket;  // !!! last_ticket ist nicht statisch und verursacht Fehler bei Timeframe-Wechseln etc.
int    lastPosition.type = OP_NONE;
double lastPosition.lots;
int    lastPosition.result;

int    breakevenDistance;                 // Gewinnschwelle in Pip, ab der der StopLoss der Position auf BreakEven gesetzt wird
int    trailingStop;                      // TrailingStop in Pip
bool   trailStopImmediately = true;       // TrailingStop sofort starten oder warten, bis Position <trailingStop> Pip im Gewinn ist

double minAccountBalance;                 // Balance-Minimum, um zu traden
double minAccountEquity;                  // Equity-Minimum, um zu traden


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


   // nicht auf den nächsten Tick warten sondern sofort start() aufrufen
   SendTick(false);

   return(catch("init(6)"));
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

   // 1) aktuellen Status einlesen
   //ReadOrderStatus();
   log("start()   ReadOrderStatus() = "+ ReadOrderStatus());

   // 2) -> im Markt ?

   // 2.1) nein, nicht im Markt -> Entry.Limit definiert ?
   //    nein) in Entry.Direction in den Markt gehen
   //    ja)   -> Limit erreicht ?
   //       nein) warten
   //       ja)   in Entry.Direction in den Markt gehen

   // 2.2) ja, im Markt, Sequenz übernehmen und fortsetzen

   ShowStatus();

   if (NewOrderPermitted()) {
      if (openPositions == 0) {
         if (lastPosition.type==OP_NONE) {
                                            SendOrder(entryDirection);
         }
         else if (Progressing()) {
            if (lastPosition.type==OP_SELL) SendOrder(OP_BUY);
            else                            SendOrder(OP_SELL);
         }
      }
      ShowStatus();
   }

   last_ticket = lastPosition.ticket;
   return(catch("start()"));
}


/**
 * Liest die Orderdaten der im Moment laufenden Sequenzen im aktuellen Instrument ein.
 *
 * @return int - Anzahl der gefundenen Sequenzen
 */
int ReadOrderStatus() {
   openPositions = 0;

   int orders = OrdersTotal();

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))   // FALSE ist rein theoretisch: während des Auslesens wird eine Order geschlossen/gestrichen und verschwindet
         break;
      if (IsMyOrder()) {
         openPositions++;
         open.ticket     = OrderTicket();
         open.type       = OrderType();
         open.time       = OrderOpenTime();
         open.price      = OrderOpenPrice();
         open.lots       = OrderLots();
         open.swap       = OrderSwap();
         open.commission = OrderCommission();
         open.profit     = OrderProfit();
         open.magic      = OrderMagicNumber();
         open.comment    = OrderComment();

         sequenceId       = 0;
         sequenceLength   = 7;
         progressionLevel = 1;
         break;
      }
   }




   // --------------------------------------------------------------
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

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("ReadOrderStatus()", error);
      return(0);
}
   return(openPositions);
}


/**
 * Ob die aktuell selektierte Order von diesem EA erzeugt wurde.
 *
 * @return bool
 */
bool IsMyOrder() {
   if (OrderSymbol()==Symbol()) {
      if (OrderType()==OP_BUY || OrderType()==OP_SELL) {

         return(true);

         int number = OrderMagicNumber() >> 22;
         return(number == EA.uniqueId);
      }
   }
   return(false);
}


/**
 * Generiert aus den übergebenen Daten und der ID des EA's einen Wert für OrderMagicNumber()
 *
 * @param  int sequenceId - eindeutige ID der Trade-Sequenz
 * @param  int length     - Anzahl der Schritte der Sequenz (Länge)
 * @param  int level      - Progression-Level
 *
 * @return int - magic number
 */
int MagicNumber(int sequenceId, int length, int level) {
   // 10 Bit für EA.uniqueId, 22 Bit für Laufzeit-spezifische Werte
   int magicNumber = EA.uniqueId << 22;

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("MagicNumber()", error);
      return(0);
   }
   return(magicNumber);
}


/**
 *
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

   if (Entry.Limit != 0) {
      if (Ask != Entry.Limit && !Progressing()) {  // Blödsinn
         ShowStatus(STATUS_ENTRYLIMIT_WAIT);
         return(false);
      }
   }

   return(true);
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


/**
 *
 * @return int - Fehlerstatus
 */
int SendOrder(int type) {
   if (type!=OP_BUY && type!=OP_SELL)
      return(catch("SendOrder(1)   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE));

   double price, sl, tp;

   switch (type) {
      case OP_BUY:  price = Ask;
                    if (Stoploss   > 0) sl = price - Stoploss  *Pip;
                    if (TakeProfit > 0) tp = price + TakeProfit*Pip;
                    break;

      case OP_SELL: price = Bid;
                    if (Stoploss   > 0) sl = price + Stoploss  *Pip;
                    if (TakeProfit > 0) tp = price - TakeProfit*Pip;
                    break;
   }

   double   lotsize    = CurrentLotSize();
   int      slippage   = 1;
   string   comment    = "FTP."+ MagicNumber() +"."+ CurrentLevel();
   datetime expiration = 0;

   debug("SendOrder()   OrderSend("+ Symbol()+ ", "+ OperationTypeDescription(type) +", "+ NumberToStr(lotsize, ".+") +" lot, price="+ NumberToStr(price, PriceFormat) +", slippage="+ NumberToStr(slippage, ".+") +", sl="+ NumberToStr(sl, PriceFormat) +", tp="+ NumberToStr(tp, PriceFormat) +", comment=\""+ comment +"\", magic="+ MagicNumber() +", expires="+ expiration +", Green)");

   if (false) {
      int ticket = OrderSend(Symbol(), type, lotsize, price, slippage, sl, tp, comment, MagicNumber(), expiration, Green);
      if (ticket > 0) {
         if (OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
            log("SendOrder()   Progression level "+ CurrentLevel() +" ("+ NumberToStr(lotsize, ".+") +" lot) - "+ OperationTypeDescription(type) +" at "+ NumberToStr(OrderOpenPrice(), PriceFormat));
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
 * Setzt den aktuellen Progression-Level auf die nächste Stufe.
 *
 * @return int - Fehlerstatus
 */
int IncreaseProgressionLevel() {
   return(catch("IncreaseProgressionLevel()"));
}


/**
 * Gibt den aktuellen Progression-Level zurück.
 *
 * @return int - Level oder -1, wenn ein Fehler auftrat
 */
int CurrentLevel() {
   int level = 1;

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("CurrentLevel()", error);
      return(-1);
   }
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
      case  0: return(0);                    // bei Fehler in CurrentLevel()
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
      case 13: return(Lotsize.Level.13);
      case 14: return(Lotsize.Level.14);
      case 15: return(Lotsize.Level.15);
      case 16: return(Lotsize.Level.16);
      case 17: return(Lotsize.Level.17);
      case 18: return(Lotsize.Level.18);
      case 19: return(Lotsize.Level.19);
      case 20: return(Lotsize.Level.20);
      case 21: return(Lotsize.Level.21);
      case 22: return(Lotsize.Level.22);
      case 23: return(Lotsize.Level.23);
      case 24: return(Lotsize.Level.24);
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
      case STATUS_ENTRYLIMIT_WAIT     : msg = " waiting for entry limit to reach";               break;
      case STATUS_FINISHED            : msg = ":  Trading sequence finished.";                   break;
      case STATUS_UNSUFFICIENT_BALANCE: msg = ":  New orders disabled (balance below minimum)."; break;
      case STATUS_UNSUFFICIENT_EQUITY : msg = ":  New orders disabled (equity below minimum)." ; break;
   }

   string status = __SCRIPT__ + msg + LF
                 + LF
                 + "Progression Level:  "+ CurrentLevel() +"  =  "+ NumberToStr(CurrentLotSize(), ".+") +" lot" + LF
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
