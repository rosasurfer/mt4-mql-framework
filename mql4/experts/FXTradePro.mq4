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
extern bool   Enable.Comments                = true;
extern string _2____________________________ = "==== TP and SL Settings =========";
extern int    TakeProfit                     = 40;
extern int    Stoploss                       = 10;
bool gb_01 = false;

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


string gs_508;

int gi_388 = 0;
int gi_392 = 0;

int  gi_396 = 0;
bool gb_400 = false;

bool gb_404 = false;
bool gb_408 = false;

int gi_420 = 0;
int gi_424 = 0;

int openPositions, closedPositions;
int gi_484;

int gia_488[1];
int gia_492[1];

double gda_496[1];

int gi_500;
int gi_504;

bool gb_516 = false;
bool gb_520 = false;
bool gb_524 = false;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   DynaReset();
   MakeGlobals();
   ShowComment(91);
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

   HouseKeeper();
   ShowComment(98);

   if (NewClosing() && Progressing())
      IncreaseProgressionLevel();

   if (gia_492[0]==2 || closedPositions==0)
      ResetProgressionLevel();

   if (NewOrderPermitted(1)) {
      CountOpenPositions();
      if (openPositions == 0) {
         if (LastOrderType()==9 && FirstOrder.Long) SendLongOrder();
         if (LastOrderType()==1 && Progressing()  ) SendLongOrder();
         if (LastOrderType()==0 && NewSeries()    ) SendLongOrder();
      }
   }

   if (NewOrderPermitted(2)) {
      CountOpenPositions();
      if (openPositions == 0) {
         if (LastOrderType()==9                 ) SendShortOrder();
         if (LastOrderType()==0 && Progressing()) SendShortOrder();
         if (LastOrderType()==1 && NewSeries()  ) SendShortOrder();
      }
      gi_484 = closedPositions;
      ShowComment(98);
   }

   return(catch("start()"));
}


/**
 *
 */
void HouseKeeper() {
   gb_516 = false;
   gb_520 = false;
   openPositions = 0;

   CountOpenPositions();
   CountClosedPositions();
   HistoryLogger();

   if (openPositions > 0) {
      if (gi_388 > 0) BreakEvenManager();
      if (gi_396 > 0) TrailingStopManager();
   }
   catch("HouseKeeper()");
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
 * Zählt die geschlossenen (ausgestoppt + final) Positionen der aktuellen Sequenz.
 *
 */
void CountClosedPositions() {
   closedPositions = 0;
   int orders = OrdersHistoryTotal();

   for (int i=0; i < orders; i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
      if (IsMyOrder())
         closedPositions++;
   }
   catch("CountClosedPositions()");
}


/**
 *
 */
void HistoryLogger() {
   if (closedPositions > 0) {
      if (closedPositions > 1) {
         ArrayResize(gia_488, closedPositions);
         ArrayResize(gda_496, closedPositions);
         ArrayResize(gia_492, closedPositions);
      }

      int n;

      for (int i=OrdersHistoryTotal()-1; i >= 0; i--) {
         OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
         if (IsMyOrder()) {
            gia_488[n] = i;
            gda_496[n] = OrderLots();
            if      (CompareDoubles(OrderClosePrice(), OrderTakeProfit())) gia_492[n] =  2;
            else if (CompareDoubles(OrderClosePrice(), OrderStopLoss()))   gia_492[n] = -2;
            else if (OrderProfit() > 0)                                    gia_492[n] =  1;
            else if (OrderProfit() < 0)                                    gia_492[n] = -1;
            else                                                           gia_492[n] =  0;
            n++;
         }
      }
   }
   catch("HistoryLogger()");
}


/**
 *
 */
bool NewOrderPermitted(int ai_0) {
   if (gb_404 && gb_408) {
      ShowComment(11);
      return(false);
   }
   if (gb_516 && gb_520) {
      ShowComment(12);
      return(false);
   }
   if (AccountEquity() < gi_420) {
      ShowComment(13);
      return(false);
   }
   if (AccountBalance() < gi_424) {
      ShowComment(14);
      return(false);
   }
   if (PriceEntry) {
      if (Ask != Price && Progressing() == 0) {
         ShowComment(43);
         return(false);
      }
   }
   if (ai_0 == 1) {
      if (gb_404) {
         ShowComment(21);
         return(false);
      }
      if (gb_516) {
         ShowComment(22);
         return(false);
      }
      return(true);
   }
   if (ai_0 == 2) {
      if (gb_408) {
         ShowComment(31);
         return(false);
      }
      if (gb_520) {
         ShowComment(32);
         return(false);
      }
      return(true);
   }
   return(false);
}


/**
 *
 * @return int - Fehlerstatus
 */
void SendLongOrder() {
   VersatileOrderTaker(OP_BUY, -1, Ask);
   return(catch("SendLongOrder()"));
}


/**
 *
 * @return int - Fehlerstatus
 */
void SendShortOrder() {
   VersatileOrderTaker(OP_SELL, -1, Bid);
   return(catch("SendShortOrder()"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int VersatileOrderTaker(int type, int ai_4, double price) {
   if (type!=OP_BUY && type!=OP_SELL)
      return(catch("VersatileOrderTaker(1)   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE));

   double sl, tp, lotsize;

   if (ai_4 < 0) lotsize = CurrentLotSize();
   else          lotsize = ai_4;

   if (NewClosing())
      DynaAdjust();

   if (gia_492[0]==2 || closedPositions==0)
      DynaReset();

   switch (type) {
      case OP_BUY:  price = Ask;
                    if (Stoploss   > 0) sl = price - gi_500*Point;
                    if (TakeProfit > 0) tp = price + gi_504*Point;
                    break;

      case OP_SELL: price = Bid;
                    if (Stoploss   > 0) sl = price + gi_500*Point;
                    if (TakeProfit > 0) tp = price - gi_504*Point;
                    break;
   }

   if (!gb_524) {
      int      slippage   = 3;
      string   comment    = __SCRIPT__ +" "+ Symbol();
      datetime expiration = 0;

      debug("VersatileOrderTaker()   OrderSend("+ Symbol()+ ", "+ OperationTypeDescription(type) +", "+ NumberToStr(lotsize, ".+") +" lots, price="+ NumberToStr(price, ".+") +", slippage="+ NumberToStr(slippage, ".+") +", sl="+ NumberToStr(sl, ".+") +", tp="+ NumberToStr(tp, ".+") +", comment=\""+ comment +"\", magic="+ MagicNumber +", expires="+ expiration +", Green)");

      int ticket = OrderSend(Symbol(), type, lotsize, price, slippage, sl, tp, comment, MagicNumber, expiration, Green);

      if (ticket > 0) {
         if (OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
            log("VersatileOrderTaker()   Progression level "+ CurrentLevel() +" ("+ NumberToStr(lotsize, ".+") +" lots) - "+ OperationTypeDescription(type) +" at "+ NumberToStr(OrderOpenPrice(), ".+"));
      }
      else return(catch("VersatileOrderTaker(2)   error opening "+ OperationTypeDescription(type) +" order"));
   }
   return(catch("VersatileOrderTaker(3)"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int BreakEvenManager() {
   if (gi_388 <= 0)
      return(NO_ERROR);

   for (int i=0; i < OrdersTotal(); i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (IsMyOrder()) {
         if (OrderType() == OP_BUY) {
            if (Bid - OrderOpenPrice() >= Point*gi_388)
               if (OrderStopLoss() < OrderOpenPrice() + gi_392*Point)
                  OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice() + gi_392*Point, OrderTakeProfit(), 0, Green);
         }
         else if (OrderType() == OP_SELL) {
            if (OrderOpenPrice() - Ask >= Point*gi_388)
               if (OrderStopLoss() > OrderOpenPrice() - gi_392*Point)
                  OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice() - gi_392*Point, OrderTakeProfit(), 0, Red);
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
      if (gi_396 > 0 && IsMyOrder()) {
         if (OrderType() == OP_BUY) {
            if (Bid - OrderOpenPrice() > Point*gi_396 || !gb_400)
               if (OrderStopLoss() < Bid - Point*gi_396)
                  OrderModify(OrderTicket(), OrderOpenPrice(), Bid - Point*gi_396, OrderTakeProfit(), 0, Green);
         }
         else if (OrderType() == OP_SELL) {
            if (OrderOpenPrice() - Ask > Point*gi_396 || !gb_400)
               if (OrderStopLoss() > Ask + Point*gi_396 || CompareDoubles(OrderStopLoss(), 0))
                  OrderModify(OrderTicket(), OrderOpenPrice(), Ask + Point*gi_396, OrderTakeProfit(), 0, Red);
         }
      }
   }
   return(catch("TrailingStopManager()"));
}


/**
 *
 */
int LastOrderType() {
   if (closedPositions == 0)
      return(9);

   OrderSelect(gia_488[0], SELECT_BY_POS, MODE_HISTORY);
   if (OrderType()==OP_BUY || OrderType()==OP_SELL)
      return(OrderType());

   return(9);
}


/**
 *
 */
void DynaAdjust() {
   if (gb_01) {
      gi_504++;
      gi_500--;
   }
}


/**
 *
 */
void DynaReset() {
   gi_504 = TakeProfit;
   gi_500 = Stoploss;
}


/**
 *
 */
bool NewClosing() {
   return(closedPositions != gi_484);
}


/**
 *
 */
int Progressing() {
   if (CompareDoubles(CurrentLotSize(), 0)) {
      ShowComment(44);
      return(0);
   }
   if (gia_492[0] == -2)
      return(1);

   return(0);
}


/**
 *
 */
int NewSeries() {
   return(gia_492[0] == 2);
}


/**
 *
 * @return int - Fehlerstatus
 */
int MakeGlobals() {
   gs_508 = AccountNumber() +"_"+ Symbol() +"_Progression";
   if (!GlobalVariableCheck(gs_508))
      ResetProgressionLevel();

   return(catch("MakeGlobals()"));
}


/**
 * Gibt den aktuellen Progression-Level zurück.
 *
 * @return int - Level oder -1, wenn ein Fehler auftrat
 */
int CurrentLevel() {
   int level = GlobalVariableGet(gs_508);

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("CurrentLevel()", error);
      return(-1);
   }
   return(level);
}


/**
 * Setzt den aktuellen Progression-Level auf die nächste Stufe.
 *
 * @return int - Fehlerstatus
 */
int IncreaseProgressionLevel() {
   GlobalVariableSet(gs_508, CurrentLevel() + 1);
   return(catch("IncreaseProgressionLevel()"));
}


/**
 * Setzt den aktuellen Progression-Level zurück auf die erste Stufe.
 *
 * @return int - Fehlerstatus
 */
int ResetProgressionLevel() {
   GlobalVariableSet(gs_508, 1);
   return(catch("ResetProgressionLevel()"));
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
int ShowComment(int ai_0) {
   if (!Enable.Comments)
      return(NO_ERROR);

   string ls_44 = __SCRIPT__ +" is trading.";

   if (gb_01) string ls_36 = "Dynamic";
   else              ls_36 = "Regular";

   string ls_52 = LF
                + LF + ls_36 + " TakeProfit:  "+ gi_504
                + LF + ls_36 + " Stoploss:  "+ gi_500
                + LF + "Progression Level:  "+ CurrentLevel() +" ("+ NumberToStr(CurrentLotSize(), ".+") + lot")";

   switch (ai_0) {
      case 91: Comment(LF+LF+ __SCRIPT__ + " is waiting for the next tick."                             ); break;
      case 98: Comment(LF+LF+ ls_44 + ls_52                                                             ); break;
      case 11: Comment(LF+LF+ ls_44 + ls_52 + LF +"New Orders Disabled:  User option"                   ); break;
      case 12: Comment(LF+LF+ ls_44 + ls_52 + LF +"New Orders Disabled:  User Settings"                 ); break;
      case 13: Comment(LF+LF+ ls_44 + ls_52 + LF +"New Orders Disabled:  Equity below minumum"          ); break;
      case 14: Comment(LF+LF+ ls_44 + ls_52 + LF +"New Orders Disabled:  Balance below minimum"         ); break;
      case 15: Comment(LF+LF+ ls_44 + ls_52 + LF +"New Orders Disabled:  Existing orders at maximum"    ); break;
      case 21: Comment(LF+LF+ ls_44 + ls_52 + LF +"New Long Orders Disabled:  User option"              ); break;
      case 22: Comment(LF+LF+ ls_44 + ls_52 + LF +"New Long Orders Disabled:  Internal calculation"     ); break;
      case 31: Comment(LF+LF+ ls_44 + ls_52 + LF +"New Short Orders Disabled:  User option"             ); break;
      case 32: Comment(LF+LF+ ls_44 + ls_52 + LF +"New Short Orders Disabled:  Internal calculation"    ); break;
      case 43: Comment(LF+LF+ ls_44 + ls_52 + LF +"New Orders Disabled:  Out of Price Range"            ); break;
      case 44: Comment(LF+LF+ ls_44 + ls_52 + LF +"New Orders Disabled:  Progression has been exhausted"); break;
      case 99: Comment(" "                                                                              ); break;
   }

   return(catch("ShowComment()"));
}
