/**
 * FXTradePro Martingale EA
 *
 * Für jede neue Sequenz muß eine andere Magic-Number angegeben werden.
 *
 *
 * @see FXTradePro Strategy:     http://www.forexfactory.com/showthread.php?t=43221
 *      FXTradePro Journal:      http://www.forexfactory.com/showthread.php?t=82544
 *      FXTradePro Swing Trades: http://www.forexfactory.com/showthread.php?t=87564
 *
 *      PowerSM EA:              http://www.forexfactory.com/showthread.php?t=75394
 *      PowerSM Journal:         http://www.forexfactory.com/showthread.php?t=159789
 */
#include <stdlib.mqh>


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string _1____________________________ = "==== EA Settings ===============";
extern int    MagicNumber                    = 21354;

extern string _2____________________________ = "==== TP and SL Settings =========";
extern int    TakeProfit                     = 40;
extern int    Stoploss                       = 10;

extern string _3____________________________ = "==== Entry Options ==============";
extern bool   FirstOrder.Long                = true;
extern bool   PriceEntry                     = false;
extern double Price                          = 0;

extern string _4____________________________ = "==== Lotsizes ==================";
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


#define RESULT_UNKNOWN     0
#define RESULT_TAKEPROFIT  1
#define RESULT_STOPLOSS    2
#define RESULT_WINNER      3
#define RESULT_LOOSER      4
#define RESULT_BREAKEVEN   5
#define OP_NONE           -1


string globalVarName;

double minAccountBalance;                 // Balance-Minimum, um zu traden
double minAccountEquity;                  // Equity-Minimum, um zu traden

int    breakEvenDistance    = 0;          // Gewinnschwelle in Point (nicht Pip), an der der StopLoss der Position auf BreakEven gesetzt wird
int    trailingStop         = 0;          // TrailingStop in Point (nicht Pip)
bool   trailStopImmediately = true;       // TrailingStop sofort starten oder warten, bis Position <trailingStop> Points im Gewinn ist

int    openPositions, closedPositions;

int    lastPosition.ticket, last_ticket;  // !!! last_ticket ist nicht statisch und verursacht dadurch Fehler bei Timeframe-Wechseln etc.
int    lastPosition.type;
double lastPosition.lots;
int    lastPosition.result;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   InitGlobalVars();
   ShowComment(1);
   return(catch("init()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   ShowComment(99);
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   init = false;

   CountOpenPositions();
   ReadOrderHistory();
   /*
   if (openPositions > 0) {
      if (breakEvenDistance > 0) BreakEvenManager();
      if (trailingStop > 0) TrailingStopManager();
   }
   */
   ShowComment(2);

   if (NewClosedPosition() && Progressing())
      IncreaseProgressionLevel();

   if (closedPositions==0 || lastPosition.result==RESULT_TAKEPROFIT)
      ResetProgressionLevel();

   if (NewOrderPermitted()) {
      if (openPositions == 0) {
         if (lastPosition.type==OP_NONE) {
            if (FirstOrder.Long) SendOrder(OP_BUY);
            else                 SendOrder(OP_SELL);
         }
         else if (Progressing()) {
            if (lastPosition.type==OP_BUY ) SendOrder(OP_SELL);
            if (lastPosition.type==OP_SELL) SendOrder(OP_BUY);
         }
      }
      ShowComment(2);
   }

   last_ticket = lastPosition.ticket;
   return(catch("start()"));
}


/**
 *
 */
bool NewOrderPermitted() {
   if (AccountBalance() < minAccountBalance) {
      ShowComment(14);
      return(false);
   }

   if (AccountEquity() < minAccountEquity) {
      ShowComment(13);
      return(false);
   }

   if (PriceEntry) {
      if (Ask != Price && !Progressing()) {  // Blödsinn
         ShowComment(43);
         return(false);
      }
   }

   return(true);
}


/**
 *
 */
bool IsMyOrder() {
   return(OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber);
}


/**
 * Zählt die offenen Positionen der aktuellen Sequenz.  =>  Sollte eigentlich immer 0 oder 1 sein.
 *
 * @return int - Fehlerstatus
 */
int CountOpenPositions() {
   openPositions = 0;

   for (int i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (IsMyOrder()) {
         if (OrderType()==OP_BUY || OrderType()==OP_SELL) openPositions++;
         else                                             catch("CountOpenPositions()   ignoring "+ OperationTypeDescription(OrderType()) +" order #"+ OrderTicket(), ERR_RUNTIME_ERROR);
      }
   }
   return(catch("CountOpenPositions()"));
}


/**
 * Zählt die geschlossenen Positionen und speichert die Daten der letzten Postion der aktuellen Sequenz.
 *
 * @return int - Fehlerstatus
 */
int ReadOrderHistory() {
   closedPositions = 0;

   for (int i=OrdersHistoryTotal()-1; i >= 0; i--) {
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
   return(catch("ReadOrderHistory()"));
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
                    if (Stoploss   > 0) sl = price - Stoploss  *Point;
                    if (TakeProfit > 0) tp = price + TakeProfit*Point;
                    break;

      case OP_SELL: price = Bid;
                    if (Stoploss   > 0) sl = price + Stoploss  *Point;
                    if (TakeProfit > 0) tp = price - TakeProfit*Point;
                    break;
   }

   double   lotsize    = CurrentLotSize();
   int      slippage   = 3;
   string   comment    = __SCRIPT__ +" "+ Symbol();
   datetime expiration = 0;

   debug("SendOrder()   OrderSend("+ Symbol()+ ", "+ OperationTypeDescription(type) +", "+ NumberToStr(lotsize, ".+") +" lots, price="+ NumberToStr(price, ".+") +", slippage="+ NumberToStr(slippage, ".+") +", sl="+ NumberToStr(sl, ".+") +", tp="+ NumberToStr(tp, ".+") +", comment=\""+ comment +"\", magic="+ MagicNumber +", expires="+ expiration +", Green)");

   int ticket = OrderSend(Symbol(), type, lotsize, price, slippage, sl, tp, comment, MagicNumber, expiration, Green);

   if (ticket > 0) {
      if (OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
         log("SendOrder()   Progression level "+ CurrentLevel() +" ("+ NumberToStr(lotsize, ".+") +" lot) - "+ OperationTypeDescription(type) +" at "+ NumberToStr(OrderOpenPrice(), ".+"));
   }
   else return(catch("SendOrder(2)   error opening "+ OperationTypeDescription(type) +" order"));

   return(catch("SendOrder(3)"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int BreakEvenManager() {
   if (breakEvenDistance <= 0)
      return(NO_ERROR);

   for (int i=0; i < OrdersTotal(); i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (IsMyOrder()) {

         if (OrderType()==OP_BUY) /*&&*/ if (OrderStopLoss() < OrderOpenPrice()) {
            if (Bid - OrderOpenPrice() >= breakEvenDistance*Point)
               OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice(), OrderTakeProfit(), 0, Green);
         }

         if (OrderType()==OP_SELL) /*&&*/ if (OrderStopLoss() > OrderOpenPrice()) {
            if (OrderOpenPrice() - Ask >= breakEvenDistance*Point)
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
            if (trailStopImmediately || Bid - OrderOpenPrice() > trailingStop*Point)
               if (OrderStopLoss() < Bid - trailingStop*Point)
                  OrderModify(OrderTicket(), OrderOpenPrice(), Bid - trailingStop*Point, OrderTakeProfit(), 0, Green);
         }

         if (OrderType() == OP_SELL) {
            if (trailStopImmediately || OrderOpenPrice() - Ask > trailingStop*Point)
               if (OrderStopLoss() > Ask + trailingStop*Point || CompareDoubles(OrderStopLoss(), 0))
                  OrderModify(OrderTicket(), OrderOpenPrice(), Ask + trailingStop*Point, OrderTakeProfit(), 0, Red);
         }
      }
   }
   return(catch("TrailingStopManager()"));
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
      ShowComment(44);
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
int InitGlobalVars() {
   globalVarName = AccountNumber() +"_"+ Symbol() +"_Progression";
   if (!GlobalVariableCheck(globalVarName))
      ResetProgressionLevel();

   return(catch("InitGlobalVars()"));
}


/**
 * Setzt den aktuellen Progression-Level zurück auf die erste Stufe.
 *
 * @return int - Fehlerstatus
 */
int ResetProgressionLevel() {
   GlobalVariableSet(globalVarName, 1);
   return(catch("ResetProgressionLevel()"));
}


/**
 * Setzt den aktuellen Progression-Level auf die nächste Stufe.
 *
 * @return int - Fehlerstatus
 */
int IncreaseProgressionLevel() {
   GlobalVariableSet(globalVarName, CurrentLevel() + 1);
   return(catch("IncreaseProgressionLevel()"));
}


/**
 * Gibt den aktuellen Progression-Level zurück.
 *
 * @return int - Level oder -1, wenn ein Fehler auftrat
 */
int CurrentLevel() {
   int level = GlobalVariableGet(globalVarName);

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
      case -1: return(-1);                   // bei Fehler in CurrentLevel()
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
int ShowComment(int id) {
   string status = __SCRIPT__ +" is trading."
                 + LF
                 + LF + "TakeProfit:  "+ TakeProfit
                 + LF + "Stoploss:  "+ Stoploss
                 + LF + "Progression Level:  "+ CurrentLevel() +"  ("+ NumberToStr(CurrentLotSize(), ".+") +" lot)";

   switch (id) {
      case  1: Comment(LF+LF+ __SCRIPT__ + " is waiting for the next tick."                     ); break;
      case  2: Comment(LF+LF+ status                                                            ); break;
      case 13: Comment(LF+LF+ status +LF +"New Orders Disabled:  Equity below minumum"          ); break;
      case 14: Comment(LF+LF+ status +LF +"New Orders Disabled:  Balance below minimum"         ); break;
      case 15: Comment(LF+LF+ status +LF +"New Orders Disabled:  Existing orders at maximum"    ); break;
      case 43: Comment(LF+LF+ status +LF +"New Orders Disabled:  Out of Price Range"            ); break;
      case 44: Comment(LF+LF+ status +LF +"New Orders Disabled:  Progression has been exhausted"); break;
      case 99: Comment(" "                                                                      ); break;
   }

   return(catch("ShowComment()"));

   if (false) {
      BreakEvenManager();
      TrailingStopManager();
   }
}
