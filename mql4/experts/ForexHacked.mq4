//==================================================================================================
// 2012-07-15 by Capella at http://www.worldwide-invest.org
// - Removed protection
// - Cleaned code
// - Renamed functions ot their ori8ginal names
// - Added news-filter - requires indicator FFCal
//==================================================================================================

#property copyright "ForexHacked 2.5"
#property link      "http://www.forexhacked.com"

extern string _________        = "Magic Number Must be UNIQUE for each chart!";
extern int    MagicNumber      = 133714;
extern double Lots             = 0.01;
extern double TakeProfit       = 45.0;
extern double Booster          = 1.7;
extern int    MaxBuyOrders     = 9;
extern int    MaxSellOrders    = 9;
extern bool   AllowiStopLoss   = false;
extern int    iStopLoss        = 300;
extern int    StartHour        = 0;
extern int    StartMinute      = 0;
extern int    StopHour         = 23;
extern int    StopMinute       = 55;
extern int    StartingTradeDay = 0;
extern int    EndingTradeDay   = 7;
extern int    slippage         = 3;
extern bool   allowTrending    = false;
extern int    trendTrigger     = 3;
extern int    trendPips        = 5;
extern int    trendStoploss    = 5;
extern double StopLossPct      = 100.0;
extern double TakeProfitPct    = 100.0;
extern bool   PauseNewTrades   = false;
extern int    StoppedOutPause  = 600;
extern bool   SupportECN       = true;
extern bool   MassHedge        = false;
extern double MassHedgeBooster = 1.01;
extern int    TradesDeep       = 5;
extern string EA_Name          = "ForexHacked 2.5";
extern int    PipStarter       = 31;
extern bool   UseNewsFilter    = false;
extern int    MinsBeforeNews   = 60;
extern int    MinsAfterNews    = 60;
extern int    NewsImpact       = 3;

double earnings        = 0.0;
double priceadd        = 0.0;
int    stoploss        = 0;
int    gi_208          = 5000;
double gd_244;
bool   gi_260;
int    imaaverage      = 7;
int    imamashift      = 0;
int    imamamethod     = MODE_LWMA;
int    imaappliedprice = PRICE_WEIGHTED;
double isarstep        = 0.25;
double isarmax         = 0.2;
int    previoustime;
double point;
int    lotround;
bool   gi_384;
bool   gi_388;
bool   gi_392;
bool   gi_396;
int    ticket;
int    command;
string hedgetext       = "hedged";
int    filename;


/**
 *
 */
int init() {
   if (Digits == 3) {
      priceadd = 10 * TakeProfit;
      stoploss = 10 * iStopLoss;
      point    = 0.01;
   }
   else if (Digits == 5) {
      priceadd = 10 * TakeProfit;
      stoploss = 10 * iStopLoss;
      point    = 0.0001;
   }
   else {
      priceadd = TakeProfit;
      stoploss = iStopLoss;
      point    = Point;
   }

   if (Digits == 3 || Digits == 5) {
      trendTrigger  = 10 * trendTrigger;
      trendPips     = 10 * trendPips;
      trendStoploss = 10 * trendStoploss;
   }

   lotround = MathRound((-MathLog(MarketInfo(Symbol(), MODE_LOTSTEP))) / 2.302585093);
   gi_384 = false;
   gi_388 = false;
   gi_392 = false;
   gi_396 = false;
   ticket = -1;
   gi_260 = false;
   filename = FileOpen(WindowExpertName() +"_"+ Time[0] +"_"+ Symbol() +"_"+ MagicNumber +".log", FILE_WRITE);
   command = -1;

   return(0);
}


/**
 *
 */
int deinit() {
   FileClose(filename);
   return(0);
}


/**
 *
 */
int start() {
   double order_takeprofit_20;
   double price_28;
   double price_36;

   if (allowTrending) {
      for (int pos_0=0; pos_0 < OrdersTotal(); pos_0++) {
         if (OrderSelect(pos_0, SELECT_BY_POS)) {
            if (MagicNumber == OrderMagicNumber()) {
               if (OrderType() == OP_BUY) {
                  if (OrderTakeProfit()-Bid <= trendTrigger*Point && Bid < OrderTakeProfit())
                     OrderModify(OrderTicket(), 0, Bid - trendStoploss*Point, OrderTakeProfit() + trendPips*Point, 0, White);
               }
               if (OrderType() == OP_SELL) {
                  if (Ask-OrderTakeProfit() <= trendTrigger*Point && Ask > OrderTakeProfit())
                     OrderModify(OrderTicket(), 0, Ask + trendStoploss*Point, OrderTakeProfit() - trendPips*Point, 0, White);
               }
            }
         }
      }
   }

   int count_4 = 0;
   int count_8 = 0;

   for (int pos_12=0; pos_12 < OrdersTotal(); pos_12++) {
      if (OrderSelect(pos_12, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderMagicNumber() == MagicNumber) {
            if (StringFind(OrderComment(), hedgetext) == -1) {
               if (OrderType() == OP_BUY ) count_4++;
               if (OrderType() == OP_SELL) count_8++;
            }
         }
      }
   }

   if (count_4 >= TradesDeep) {
      if (!gi_396) {
         Log("Allow long hedge! trades="+ count_4 +",TradesDeep="+ TradesDeep);
         gi_396 = true;
      }
   }
   if (count_8 >= TradesDeep) {
      if (!gi_392) {
         Log("Allow short hedge! trades="+ count_8 +",TradesDeep="+ TradesDeep);
         gi_392 = true;
      }
   }

   bool li_16 = false;
   if ((100-StopLossPct) * AccountBalance()/100 >= AccountEquity()) {
      Log("AccountBalance="+ AccountBalance() +",AccountEquity=" + AccountEquity());
      gi_260 = true;
      li_16  = true;
   }

   if ((TakeProfitPct+100) * AccountBalance()/100 <= AccountEquity())
      gi_260 = true;

   if (gi_260) {
      for (pos_0=OrdersTotal()-1; pos_0 >= 0; pos_0--) {
         if (OrderSelect(pos_0, SELECT_BY_POS)) {
            if (OrderMagicNumber() == MagicNumber) {
               Log("close #"+ OrderTicket());
               if (!OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), MarketInfo(Symbol(), MODE_SPREAD), White)) {
                  Log("error");
                  return(0);
               }
            }
         }
      }

      gi_260 = false;
      if (li_16) {
         Sleep(1000 * StoppedOutPause);
         li_16 = false;
      }

      gi_396 = false;
      gi_392 = false;
   }

   if (SupportECN) {
      order_takeprofit_20 = 0;
      if (OrderSelect(ticket, SELECT_BY_TICKET))
         order_takeprofit_20 = OrderTakeProfit();

      for (pos_0=0; pos_0 < OrdersTotal(); pos_0++) {
         if (OrderSelect(pos_0, SELECT_BY_POS)) {
            if (OrderMagicNumber() == MagicNumber) {
               if (OrderTakeProfit()==0 && StringFind(OrderComment(), hedgetext)==-1) {
                  if (OrderType() == OP_BUY ) OrderModify(OrderTicket(), 0, OrderStopLoss(), OrderOpenPrice() + priceadd*Point, 0, White);
                  if (OrderType() == OP_SELL) OrderModify(OrderTicket(), 0, OrderStopLoss(), OrderOpenPrice() - priceadd*Point, 0, White);
                  continue;
               }
               if (StringFind(OrderComment(), hedgetext)!=-1 && command==OrderType()) {
                  price_28 = order_takeprofit_20 - MarketInfo(Symbol(), MODE_SPREAD) * Point;
                  price_36 = order_takeprofit_20 + MarketInfo(Symbol(), MODE_SPREAD) * Point;
                  if (OrderStopLoss()==0 || (OrderType()==OP_BUY && OrderStopLoss()!=price_28) || (OrderType()==OP_SELL && OrderStopLoss()!=price_36)) {
                     if (OrderType() == OP_BUY ) OrderModify(OrderTicket(), 0, price_28, OrderTakeProfit(), 0, White);
                     if (OrderType() == OP_SELL) OrderModify(OrderTicket(), 0, price_36, OrderTakeProfit(), 0, White);
                  }
               }
            }
         }
      }
   }

   ManageBuy();
   ManageSell();
   if (!PauseNewTrades && IsTradeTime() && (!UseNewsFilter || !NewsTime())) {
      if (gi_388)
         if (OpenBuy(1) == true)
            gi_388 = false;
      if (gi_384)
         if (OpenSell(1) == true)
            gi_384 = false;
   }
   ChartComment();
   return(0);
}


/**
 *
 */
void Log(string as_0) {
   if (filename >= 0)
      FileWrite(filename, TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS) +": "+ as_0);
}


/**
 *
 */
double CalcLots(double a_minlot_0) {
   if (a_minlot_0 < 0)
      Print("ERROR tmp=" + (AccountEquity()-gi_208) + ", AccountEquity()=" + AccountEquity());

   Log("Equity="+ AccountEquity() +", lots="+ a_minlot_0);
   return(a_minlot_0);
}


/**
 *
 */
int IsTradeTime() {
   if (DayOfWeek() < StartingTradeDay || DayOfWeek() > EndingTradeDay)
      return(0);

   int li_0 = 60 * TimeHour(TimeCurrent()) + TimeMinute(TimeCurrent());
   int li_4 = 60 * StartHour + StartMinute;
   int li_8 = 60 * StopHour;

   if (li_4 < li_8) {
      if (li_0 < li_4 || li_0 >= li_8)
         return(0);
      return(1);
   }
   else if (li_4 > li_8) {
      if (li_0 >= li_4 || li_0 < li_8)
         return(1);
      return(0);
   }
   else /*(li_4 == li_8)*/ {
      return(1);
   }
}


/**
 *
 */
double GetLastLotSize(int ai_0) {
   for (int pos_4=OrdersTotal()-1; pos_4 >= 0; pos_4--) {
      if (OrderSelect(pos_4, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MagicNumber) {
            if (StringFind(OrderComment(), hedgetext) == -1) {
               Log("GetLastLotSize "+ ai_0 +", OrderLots()="+ OrderLots());
               return(OrderLots());
            }
         }
      }
   }
   Log("GetLastLotSize "+ ai_0 + " not found");
   return(0);
}


/**
 *
 */
int OpenBuy(bool ai_0 = false) {
   int ticket_4;
   double lots_40;
   double price_8 = 0;
   double price_16 = 0;
   string ls_24 = "";
   bool li_ret_32 = true;

   if (TimeCurrent() - previoustime < 60)
      return(0);
   if (ai_0 && (!gi_392))
      return(0);

   if (!GlobalVariableCheck("PERMISSION")) {
      GlobalVariableSet("PERMISSION", TimeCurrent());
      if (!SupportECN)
      {
         if (ai_0)
         {
            if (OrderSelect(ticket, SELECT_BY_TICKET))
               price_16 = OrderTakeProfit() - MarketInfo(Symbol(), MODE_SPREAD) * Point;
         }
         else
            price_8 = Ask + priceadd * Point;
      }
      if (ai_0)
         ls_24 = hedgetext;
      if (AllowiStopLoss == true)
         price_16 = Ask - stoploss * Point;
      if (ai_0)
         lots_40 = NormalizeDouble(GetLastLotSize(1) * MassHedgeBooster, 2);
      else
         lots_40 = CalcLots(gd_244);
      if (!SupportECN)
         ticket_4 = OrderSend(Symbol(), OP_BUY, lots_40, Ask, slippage, price_16, price_8, EA_Name + ls_24, MagicNumber, 0, Green);
      else {
         ticket_4 = OrderSend(Symbol(), OP_BUY, lots_40, Ask, slippage, 0, 0, EA_Name + ls_24, MagicNumber, 0, Green);
         Sleep(1000);
         OrderModify(ticket_4, OrderOpenPrice(), price_16, price_8, 0, Black);
      }
      previoustime = TimeCurrent();
      if (ticket_4 != -1)
      {
         if (!ai_0)
         {
            ticket = ticket_4;
            Log("BUY hedgedTicket=" + ticket);
         }
         else
         {
            Log("BUY Hacked_ticket=" + ticket_4);
            command = 0;
         }
      }
      else
      {
         Log("failed sell");
         li_ret_32 = false;
      }
   }
   GlobalVariableDel("PERMISSION");
   return(li_ret_32);
}


/**
 *
 */
int OpenSell(bool ai_0 = false) {
   int ticket_4;
   double lots_36;
   double price_8 = 0;
   double price_16 = 0;
   string ls_24 = "";
   bool li_ret_32 = true;
   if (TimeCurrent() - previoustime < 60)
      return(0);
   if (ai_0 && (!gi_396))
   return(0);
   if (!GlobalVariableCheck("PERMISSION"))
   {
      GlobalVariableSet("PERMISSION", TimeCurrent());
      if (!SupportECN)
      {
         if (ai_0)
         {
            if (OrderSelect(ticket, SELECT_BY_TICKET))
               price_16 = OrderTakeProfit() + MarketInfo(Symbol(), MODE_SPREAD) * Point;
         }
         else
            price_8 = Bid - priceadd * Point;
      }
      if (ai_0)
         ls_24 = hedgetext;
      if (AllowiStopLoss == true)
         price_16 = Bid + stoploss * Point;
      if (ai_0)
         lots_36 = NormalizeDouble(GetLastLotSize(0) * MassHedgeBooster, 2);
      else
         lots_36 = CalcLots(gd_244);
      if (!SupportECN)
         ticket_4 = OrderSend(Symbol(), OP_SELL, lots_36, Bid, slippage, price_16, price_8, EA_Name + ls_24, MagicNumber, 0, Pink);
      else
      {
         ticket_4 = OrderSend(Symbol(), OP_SELL, lots_36, Bid, slippage, 0, 0, EA_Name + ls_24, MagicNumber, 0, Pink);
         Sleep(1000);
         OrderModify(ticket_4, OrderOpenPrice(), price_16, price_8, 0, Black);
      }
      previoustime = TimeCurrent();
      if (ticket_4 != -1)
      {
         if (!ai_0)
         {
            ticket = ticket_4;
            Log("SELL hedgedTicket=" + ticket);
         }
         else
         {
            Log("SELL Hacked_ticket=" + ticket_4);
            command = 1;
         }
      }
      else
      {
         Log("failed sell");
         li_ret_32 = false;
      }
   }
   GlobalVariableDel("PERMISSION");
   return(li_ret_32);
}


/**
 *
 */
void ManageBuy() {
   int datetime_0 = 0;
   double order_open_price_4 = 0;
   double order_lots_12 = 0;
   double order_takeprofit_20 = 0;
   int cmd_28 = -1;
   int ticket_32 = 0;
   int pos_36 = 0;
   int count_40 = 0;
   for (pos_36 = 0; pos_36 < OrdersTotal(); pos_36++)
   {
      if (OrderSelect(pos_36, SELECT_BY_POS, MODE_TRADES))
      {
         if (OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY)
         {
            count_40++;
            if (OrderOpenTime() > datetime_0)
            {
               datetime_0 = OrderOpenTime();
               order_open_price_4 = OrderOpenPrice();
               cmd_28 = OrderType();
               ticket_32 = OrderTicket();
               order_takeprofit_20 = OrderTakeProfit();
            }
            if (OrderLots() > order_lots_12)
               order_lots_12 = OrderLots();
         }
      }
   }
   int li_44 = MathRound(MathLog(order_lots_12 / Lots) / MathLog(Booster)) + 1.0;
   if (li_44 < 0)
      li_44 = 0;
   gd_244 = NormalizeDouble(Lots * MathPow(Booster, li_44), lotround);
   if (li_44 == 0 && StrategySignal() == 1 && IsTradeTime() && !(UseNewsFilter && NewsTime()))
   {
      if (OpenBuy() == true)
         if (MassHedge)
            gi_384 = true;
   }
   else
   {
      if (order_open_price_4 - Ask > PipStarter * point && order_open_price_4 > 0.0 && count_40 < MaxBuyOrders)
      {
         if (!(OpenBuy()))
            return;
         if (!(MassHedge))
            return;
         gi_384 = true;
         return;
      }
   }
   for (pos_36 = 0; pos_36 < OrdersTotal(); pos_36++)
   {
      OrderSelect(pos_36, SELECT_BY_POS, MODE_TRADES);
      if (OrderMagicNumber() != MagicNumber || OrderType() != OP_BUY || OrderTakeProfit() == order_takeprofit_20 || order_takeprofit_20 == 0.0)
         continue;
      OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), order_takeprofit_20, 0, Pink);
      Sleep(1000);
   }
}


/**
 *
 */
int StrategySignal() {
   double isar_0 = iSAR(NULL, 0, isarstep, isarmax, 0);
   double ima_8 = iMA(NULL, 0, imaaverage, imamashift, imamamethod, imaappliedprice, 0);
   if (isar_0 > ima_8)
      return(-1);
   if (isar_0 < ima_8)
      return(1);
   return(0);
}


/**
 *
 */
void ManageSell() {
   int datetime_0 = 0;
   double order_open_price_4 = 0;
   double order_lots_12 = 0;
   double order_takeprofit_20 = 0;
   int cmd_28 = -1;
   int ticket_32 = 0;
   int pos_36 = 0;
   int count_40 = 0;
   for (pos_36 = 0; pos_36 < OrdersTotal(); pos_36++)
   {
      if (OrderSelect(pos_36, SELECT_BY_POS, MODE_TRADES))
      {
         if (OrderMagicNumber() == MagicNumber && OrderType() == OP_SELL)
         {
            count_40++;
            if (OrderOpenTime() > datetime_0)
            {
               datetime_0 = OrderOpenTime();
               order_open_price_4 = OrderOpenPrice();
               cmd_28 = OrderType();
               ticket_32 = OrderTicket();
               order_takeprofit_20 = OrderTakeProfit();
            }
            if (OrderLots() > order_lots_12)
               order_lots_12 = OrderLots();
         }
      }
   }
   int li_44 = MathRound(MathLog(order_lots_12 / Lots) / MathLog(Booster)) + 1.0;
   if (li_44 < 0)
      li_44 = 0;
   gd_244 = NormalizeDouble(Lots * MathPow(Booster, li_44), lotround);
   if (li_44 == 0 && StrategySignal() == -1 && IsTradeTime() && !(UseNewsFilter && NewsTime()))
   {
      if (OpenSell() == true)
         if (MassHedge)
            gi_388 = true;
   }
   else
   {
      if (Bid - order_open_price_4 > PipStarter * point && order_open_price_4 > 0.0 && count_40 < MaxSellOrders)
      {
         if (!(OpenSell()))
            return;
         if (!(MassHedge))
            return;
         gi_388 = true;
         return;
      }
   }
   for (pos_36 = 0; pos_36 < OrdersTotal(); pos_36++)
   {
      if (OrderSelect(pos_36, SELECT_BY_POS, MODE_TRADES))
      {
         if (OrderMagicNumber() == MagicNumber && OrderType() == OP_SELL)
         {
            if (OrderTakeProfit() == order_takeprofit_20 || order_takeprofit_20 == 0.0)
               continue;
            OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), order_takeprofit_20, 0, Pink);
         }
      }
   }
}


/**
 *
 */
void ChartComment() {
   string dbl2str_0 = DoubleToStr(BalanceDeviation(2), 2);
   if (UseNewsFilter && NewsTime())
   {
      Comment ("Pending news event...");
   }
   for (int pos_8 = 0; pos_8 < OrdersHistoryTotal(); pos_8++)
      if (OrderSelect(pos_8, SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol() && OrderType() <= OP_SELL)
         earnings += OrderProfit() + OrderCommission() + OrderSwap();
   Comment(" \nForexHacked V2.5 Loaded Successfully™ ",
      "\nAccount Leverage  :  " + "1 : " + AccountLeverage(),
      "\nAccount Type  :  " + AccountServer(),
      "\nServer Time  :  " + TimeToStr(TimeCurrent(), TIME_SECONDS),
      "\nAccount Equity  = ", AccountEquity(),
      "\nFree Margin     = ", AccountFreeMargin(),
   "\nDrawdown  :  ", dbl2str_0, " \n" + Symbol(), " Earnings  :  " + earnings);
}


/**
 *
 */
double BalanceDeviation(int ai_0) {
   double ld_ret_4;
   if (ai_0 == 2)
   {
      ld_ret_4 = (AccountEquity() / AccountBalance() - 1.0) / (-0.01);
      if (ld_ret_4 <= 0.0)
         return(0);
      return(ld_ret_4);
   }
   if (ai_0 == 1)
   {
      ld_ret_4 = 100.0 * (AccountEquity() / AccountBalance() - 1.0);
      if (ld_ret_4 <= 0.0)
         return(0);
      return(ld_ret_4);
   }
   return(0.0);
}


/**
 *
 */
bool NewsTime() {
   bool News = false;
   static int PrevMinute = -1;
   if (Minute() != PrevMinute && !IsTesting())
   {
      PrevMinute = Minute();
      int minutesSincePrevEvent = iCustom(NULL, 0, "FFCal", true, true, false, true, true, 1, 0);
      int minutesUntilNextEvent = iCustom(NULL, 0, "FFCal", true, true, false, true, true, 1, 1);
      if ((minutesUntilNextEvent <= MinsBeforeNews) || (minutesSincePrevEvent <= MinsAfterNews))
      {
         int impactOfNextEvent = iCustom(NULL, 0, "FFCal", true, true, false, true, true, 2, 1);
         if (impactOfNextEvent >= NewsImpact)
         {
            News = true;
            }
         }
      }
   return(News);
}
