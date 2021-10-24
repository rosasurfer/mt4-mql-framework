/**
 * Rewritten Generic Breakout EA v7. Work-in-progress, don't use for real trading!
 *
 * History:
 *  - removed tickdatabase functionality
 *  - removed obsolete parts and simplified logic
 *
 * @source  https://www.forexfactory.com/thread/post/3775867#post3775867                 [Ronald Raygun: Generic Breakout v7]
 */
extern string Remark1 = "== Main Settings ==";
extern int    MagicNumber = 0;
extern bool   Alerts = false;
extern bool   PlaySounds = false;
extern bool   UseTradingTimes = false;
extern int    StartHour = 0;
extern int    StartMinute = 0;
extern int    StopHour = 0;
extern int    StopMinute = 0;
extern bool   CloseOnOppositeSignal = true;
extern bool   EachTickMode = true;
extern double Lots = 0;
extern bool   MoneyManagement = false;
extern int    Risk = 0;
extern int    Slippage.Points = 5;
extern bool   UseStopLoss = true;
extern int    StopLoss.Points = 1000;
extern double SLMultiplier = 0.0;
extern int    SLMultiplierBuffer.Points = 0;
extern bool   UseTakeProfit = false;
extern int    TakeProfit.Points = 600;
extern double TPMultiplier = 0.0;
extern int    TPMultiplierBuffer.Points = 0;
extern bool   UseTrailingStop = false;
extern int    TrailingStop.Points = 300;
extern bool   UseMultipleTrailingStop = false;
extern double TSMultiple = 1.0;
extern int    TSMultipleBuffer.Points = 10;
extern bool   MoveStopOnce = false;
extern int    MoveStopWhenPrice.Points = 500;
extern int    MoveStopTo.Points = 10;
extern bool   UseMultipleMoveStopOnce = false;
extern double MoveStopWhenRangeMultiple = 1.0;
extern int    MoveStopWhenRangeMulBuf.Points = 0;
extern double MoveStopToMultiple = 0.0;
extern int    MoveStopToMultipleBuffer.Points = 10;

extern string Remark2 = "== Breakout Settings ==";
extern int    RangeStartHour = 0;
extern int    RangeStartMinute = 0;
extern int    RangeStopHour = 0;
extern int    RangeStopMinute = 0;
extern string TSDescription = "Trading Style: 1 - Breakout | 2 - Counter Trend";
extern int    TradingStyle = 0;
extern double EntryMultiplier = 0.0;
extern int    EntryBuffer.Points = 0;
extern int    MaxRangePips = 0;
extern int    MinRangePips = 0;
extern int    MaxTrades = 0;
extern int    MaxLongTrades = 0;
extern int    MaxShortTrades = 0;
extern int    MaxProfitTrades = 0;
extern bool   CountOpenTrades = true;
extern int    MaxLossTrades = 0;
extern int    MaxSimultaneousTrades = 1;
extern int    MaxSimultaneousLongTrades = 0;
extern int    MaxSimultaneousShortTrades = 0;

#define SIGNAL_NONE 0
#define SIGNAL_BUY   1
#define SIGNAL_SELL  2
#define SIGNAL_CLOSEBUY 3
#define SIGNAL_CLOSESELL 4

int      GMTBar;
string   GMTTime;
string   BrokerTime;
int      GMTShift;

datetime CurGMTTime;
datetime CurBrokerTime;
datetime CurrentGMTTime;

int      TradeBar;
int      TradesThisBar;
int      OpenBarCount;
int      CloseBarCount;

int      LongSoundSignalBarCount;
int      ShortSoundSignalBarCount;
int      LongAlertSignalBarCount;
int      ShortAlertSignalBarCount;

int      Current;
bool     TickCheck = false;


/**
 * Initialization
 *
 * @return int - error status
 */
int init() {
   OpenBarCount             = Bars;
   CloseBarCount            = Bars;
   LongAlertSignalBarCount  = Bars;
   ShortAlertSignalBarCount = Bars;

   if (EachTickMode) Current = 0;
   else              Current = 1;

   return(0);
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int deinit() {
   for (int i=ObjectsTotal(); i >= 0; i--) {
      if (StringFind(ObjectName(i), WindowExpertName(), 0) == 0) {
         ObjectDelete(ObjectName(i));
      }
   }
   return(0);
}


/**
 * Main function
 *
 * @return int - error status
 */
int start() {
   if (TradingStyle == 0) {
      Alert("Please set the trading style to something other than 0.");
      return(0);
   }

   int Ticket;
   double StopLossLevel, TakeProfitLevel, PotentialStopLoss, BEven, BEven1, TrailStop, TrailStop1;

   if (EachTickMode && Bars!=CloseBarCount) TickCheck = false;
   int Total = OrdersTotal();
   int Order = SIGNAL_NONE;

   // limit trades per bar
   if (TradeBar != Bars) {
      TradeBar      = Bars;
      TradesThisBar = 0;
   }

   // money management sequence
   if (MoneyManagement) {
      if (Risk < 1 || Risk > 100) {
         Comment("Invalid risk value.");
         return(0);
      }
      else {
         Lots = MathFloor((AccountFreeMargin()*AccountLeverage()*Risk*Point*100) / (Ask*MarketInfo(Symbol(), MODE_LOTSIZE)*MarketInfo(Symbol(), MODE_MINLOT))) * MarketInfo(Symbol(), MODE_MINLOT);
      }
   }

   // variable begin
   static double PreviousTick;
   static double CurrentTick;

   PreviousTick = CurrentTick;
   CurrentTick  = iClose(NULL, NULL, Current);

   string TradingTimes = "Outside Trading Times";
   datetime StartTime = StrToTime(TimeYear(TimeCurrent()) +"."+ TimeMonth(TimeCurrent()) +"."+ TimeDay(TimeCurrent()) +" "+ StartHour +":"+ StartMinute);
   datetime StopTime  = StrToTime(TimeYear(TimeCurrent()) +"."+ TimeMonth(TimeCurrent()) +"."+ TimeDay(TimeCurrent()) +" "+ StopHour  +":"+ StopMinute);

   if (UseTradingTimes) {
      if (StopTime > StartTime &&  TimeCurrent() >= StartTime && TimeCurrent() < StopTime)  TradingTimes = "Inside Trading Times";
      if (StopTime < StartTime && (TimeCurrent() >= StartTime || TimeCurrent() < StopTime)) TradingTimes = "Inside Trading Times";
   }
   else TradingTimes = "Not Used";

   // calculate the day's range
   datetime RangeStartTime = StrToTime(TimeYear(TimeCurrent()) +"."+ TimeMonth(TimeCurrent()) +"."+ TimeDay(TimeCurrent()) +" "+ RangeStartHour +":"+ RangeStartMinute);
   datetime RangeStopTime  = StrToTime(TimeYear(TimeCurrent()) +"."+ TimeMonth(TimeCurrent()) +"."+ TimeDay(TimeCurrent()) +" "+ RangeStopHour  +":"+ RangeStopMinute);

   if (RangeStopTime >= TimeCurrent()) {
      RangeStartTime = RangeStartTime - 86400;
      RangeStopTime  = RangeStopTime  - 86400;
   }
   if (RangeStartTime > RangeStopTime) {
      RangeStartTime = RangeStartTime - 86400;
   }
   int RangeStartShift = iBarShift(NULL, NULL, RangeStartTime, false);
   int RangeStopShift  = iBarShift(NULL, NULL, RangeStopTime, false);

   double HighPrice = iHigh(NULL, NULL, iHighest(NULL, NULL, MODE_HIGH, RangeStartShift - RangeStopShift, RangeStopShift));
   double LowPrice  =  iLow(NULL, NULL,  iLowest(NULL, NULL, MODE_LOW,  RangeStartShift - RangeStopShift, RangeStopShift));

   double Range = HighPrice - LowPrice;
   double Buffer = Range*EntryMultiplier + EntryBuffer.Points*Point;

   double LongEntry, ShortEntry;

   switch (TradingStyle) {
      case 1:
         LongEntry  = HighPrice + Buffer;
         ShortEntry = LowPrice  - Buffer;
         break;
      case 2:
         LongEntry  = LowPrice  - Buffer;
         ShortEntry = HighPrice + Buffer;
         break;
   }

   string RangeFilter    = "No Trade";
   string MaxRangeFilter = "No Trade";
   string MinRangeFilter = "No Trade";

   if (MaxRangePips * Point >= Range) MaxRangeFilter = "Can Trade";
   if (MinRangePips * Point <= Range) MinRangeFilter = "Can Trade";
   if (MaxRangePips == 0)             MaxRangeFilter = "Not Used";
   if (MinRangePips == 0)             MinRangeFilter = "Not Used";
   if (MaxRangeFilter=="Can Trade" && MinRangeFilter=="Can Trade") RangeFilter = "Between Min and Max Range";
   if (MaxRangeFilter=="Can Trade" && MinRangeFilter=="Not Used" ) RangeFilter = "Inside Max Range";
   if (MaxRangeFilter=="Not Used"  && MinRangeFilter=="Can Trade") RangeFilter = "Outside Min Range";
   if (MaxRangeFilter=="Not Used"  && MinRangeFilter=="Not Used" ) RangeFilter = "Not Used";

   // count trades taken
   int TotalTrades, LongTrades, ShortTrades, ProfitTrades, LossTrades, SimultaneousTrades, SimultaneousLongTrades, SimultaneousShortTrades;

   for (int i=OrdersTotal(); i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber && (OrderType()==OP_BUY || OrderType()==OP_SELL) && OrderOpenTime() >= RangeStopTime) {
         TotalTrades++;
         SimultaneousTrades++;
         if (OrderType() == OP_BUY) { LongTrades++;  SimultaneousLongTrades++;  }
         else                       { ShortTrades++; SimultaneousShortTrades++; }
         if (CountOpenTrades) {
            if (OrderProfit() > 0) ProfitTrades++;
            if (OrderProfit() < 0) LossTrades++;
         }
      }
   }

   for (i=OrdersHistoryTotal(); i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
      if (OrderSymbol()== Symbol() && OrderMagicNumber()==MagicNumber && (OrderType()==OP_BUY || OrderType()==OP_SELL) && OrderOpenTime() >= RangeStopTime) {
         TotalTrades++;
         if (OrderType() == OP_BUY) LongTrades++;
         else                       ShortTrades++;
         if (OrderProfit() > 0) ProfitTrades++;
         if (OrderProfit() < 0) LossTrades++;
      }
   }

   string TradeCheck = "Can Trade";
   if (MaxSimultaneousTrades && SimultaneousTrades >= MaxSimultaneousTrades) TradeCheck = "No Trade";
   if (MaxTrades             && TotalTrades        >= MaxTrades)             TradeCheck = "No Trade";
   if (MaxProfitTrades       && ProfitTrades       >= MaxProfitTrades)       TradeCheck = "No Trade";
   if (MaxLossTrades         && LossTrades         >= MaxLossTrades)         TradeCheck = "No Trade";

   string LongTradeCheck = "Can Trade";
   if (MaxSimultaneousLongTrades && SimultaneousLongTrades >= MaxSimultaneousLongTrades) LongTradeCheck = "No Trade";
   if (MaxLongTrades             && LongTrades             >= MaxLongTrades)             LongTradeCheck = "No Trade";

   string ShortTradeCheck = "Can Trade";
   if (MaxSimultaneousShortTrades && SimultaneousShortTrades >= MaxSimultaneousShortTrades) ShortTradeCheck = "No Trade";
   if (MaxShortTrades             && ShortTrades             >= MaxShortTrades)             ShortTradeCheck = "No Trade";

   string TradeTrigger = "None";
   if (TradeCheck=="Can Trade" && RangeFilter!="No Trade" && TradingTimes!="Outside Trading Times") {
      if (LongTradeCheck =="Can Trade" && CurrentTick >= LongEntry  && PreviousTick < LongEntry  && iOpen(NULL, NULL, Current) < LongEntry)  TradeTrigger = "Open Long";
      if (ShortTradeCheck=="Can Trade" && CurrentTick <= ShortEntry && PreviousTick > ShortEntry && iOpen(NULL, NULL, Current) > ShortEntry) TradeTrigger = "Open Short";
   }

   Comment("Trading Times: ",     TradingTimes, "\n",
           "Range Filter: ",      RangeFilter, "\n",
           "Trade Check: ",       TradeCheck, "\n",
           "Long Trade Check: ",  LongTradeCheck, "\n",
           "Short Trade Check: ", ShortTradeCheck, "\n",
           "Trade Trigger: ",     TradeTrigger);

   if (RangeStartTime != RangeStopTime) {
      ObjectDelete(WindowExpertName() +" RangeStart");
      ObjectCreate(WindowExpertName() +" RangeStart", OBJ_TREND, 0, RangeStartTime, HighPrice, RangeStartTime, LowPrice);
         ObjectSet(WindowExpertName() +" RangeStart", OBJPROP_RAY, false);
         ObjectSet(WindowExpertName() +" RangeStart", OBJPROP_COLOR, Yellow);
         ObjectSet(WindowExpertName() +" RangeStart", OBJPROP_STYLE, STYLE_DASHDOTDOT);
         ObjectSet(WindowExpertName() +" RangeStart", OBJPROP_BACK, true);

      ObjectDelete(WindowExpertName() +" RangeStop");
      ObjectCreate(WindowExpertName() +" RangeStop", OBJ_TREND, 0, RangeStopTime, HighPrice, RangeStopTime, LowPrice);
         ObjectSet(WindowExpertName() +" RangeStop", OBJPROP_RAY, false);
         ObjectSet(WindowExpertName() +" RangeStop", OBJPROP_COLOR, Yellow);
         ObjectSet(WindowExpertName() +" RangeStop", OBJPROP_STYLE, STYLE_DASHDOTDOT);
         ObjectSet(WindowExpertName() +" RangeStop", OBJPROP_BACK, true);

      ObjectDelete(WindowExpertName() +" RangeHigh");
      ObjectCreate(WindowExpertName() +" RangeHigh", OBJ_TREND, 0, RangeStartTime, HighPrice, RangeStopTime, HighPrice);
         ObjectSet(WindowExpertName() +" RangeHigh", OBJPROP_RAY, false);
         ObjectSet(WindowExpertName() +" RangeHigh", OBJPROP_COLOR, Yellow);
         ObjectSet(WindowExpertName() +" RangeHigh", OBJPROP_STYLE, STYLE_DASHDOTDOT);
         ObjectSet(WindowExpertName() +" RangeHigh", OBJPROP_BACK, true);

      ObjectDelete(WindowExpertName() +" RangeLow");
      ObjectCreate(WindowExpertName() +" RangeLow", OBJ_TREND, 0, RangeStartTime, LowPrice, RangeStopTime, LowPrice);
         ObjectSet(WindowExpertName() +" RangeLow", OBJPROP_RAY, false);
         ObjectSet(WindowExpertName() +" RangeLow", OBJPROP_COLOR, Yellow);
         ObjectSet(WindowExpertName() +" RangeLow", OBJPROP_STYLE, STYLE_DASHDOTDOT);
         ObjectSet(WindowExpertName() +" RangeLow", OBJPROP_BACK, true);

      ObjectDelete(WindowExpertName() +" LongEntry");
      ObjectCreate(WindowExpertName() +" LongEntry", OBJ_TREND, 0, RangeStartTime, LongEntry, RangeStopTime, LongEntry);
         ObjectSet(WindowExpertName() +" LongEntry", OBJPROP_RAY, true);
         ObjectSet(WindowExpertName() +" LongEntry", OBJPROP_COLOR, Lime);
         ObjectSet(WindowExpertName() +" LongEntry", OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSet(WindowExpertName() +" LongEntry", OBJPROP_BACK, true);

      ObjectDelete(WindowExpertName() +" ShortEntry");
      ObjectCreate(WindowExpertName() +" ShortEntry", OBJ_TREND, 0, RangeStartTime, ShortEntry, RangeStopTime, ShortEntry);
         ObjectSet(WindowExpertName() +" ShortEntry", OBJPROP_RAY, true);
         ObjectSet(WindowExpertName() +" ShortEntry", OBJPROP_COLOR, Red);
         ObjectSet(WindowExpertName() +" ShortEntry", OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSet(WindowExpertName() +" ShortEntry", OBJPROP_BACK, true);
   }

   // check position
   bool IsTrade = false;

   for (i=0; i < Total; i ++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);

      if (OrderType() <= OP_SELL &&  OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
         IsTrade = true;

         if (OrderType() == OP_BUY) {
            // close buy
            if (CloseOnOppositeSignal && TradeTrigger=="Open Short") Order = SIGNAL_CLOSEBUY;

            if (Order==SIGNAL_CLOSEBUY && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars!=CloseBarCount)))) {
               OrderClose(OrderTicket(), OrderLots(), Bid, Slippage.Points, MediumSeaGreen);
               if (!EachTickMode) CloseBarCount = Bars;
               IsTrade = false;
               continue;
            }

            PotentialStopLoss = OrderStopLoss();
            BEven             = CalcBreakEven(MoveStopOnce, OrderTicket(), MoveStopTo.Points, MoveStopWhenPrice.Points);
            BEven1            = CalcBreakEven(UseMultipleMoveStopOnce, OrderTicket(), (CalculateRange(OrderOpenTime()) * MoveStopToMultiple) / Point + (MoveStopToMultipleBuffer.Points), (CalculateRange(OrderOpenTime()) * MoveStopWhenRangeMultiple) / Point + MoveStopWhenRangeMulBuf.Points);
            TrailStop         = CalcTrailingStop(UseTrailingStop, OrderTicket(), TrailingStop.Points);
            TrailStop1        = CalcTrailingStop(UseMultipleTrailingStop, OrderTicket(), (CalculateRange(OrderOpenTime()) * TSMultiple) / Point + TSMultipleBuffer.Points);

            if (BEven      > PotentialStopLoss && BEven)      PotentialStopLoss = BEven;
            if (BEven1     > PotentialStopLoss && BEven1)     PotentialStopLoss = BEven1;
            if (TrailStop  > PotentialStopLoss && TrailStop)  PotentialStopLoss = TrailStop;
            if (TrailStop1 > PotentialStopLoss && TrailStop1) PotentialStopLoss = TrailStop1;

            if (PotentialStopLoss != OrderStopLoss()) OrderModify(OrderTicket(), OrderOpenPrice(), PotentialStopLoss, OrderTakeProfit(), 0, MediumSeaGreen);
         }
         else {
            // close sell
            if (CloseOnOppositeSignal && TradeTrigger=="Open Long") Order = SIGNAL_CLOSESELL;

            if (Order==SIGNAL_CLOSESELL && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars!=CloseBarCount)))) {
               OrderClose(OrderTicket(), OrderLots(), Ask, Slippage.Points, DarkOrange);
               if (!EachTickMode) CloseBarCount = Bars;
               IsTrade = false;
               continue;
            }

            PotentialStopLoss = OrderStopLoss();
            BEven             = CalcBreakEven(MoveStopOnce, OrderTicket(), MoveStopTo.Points, MoveStopWhenPrice.Points);
            BEven1            = CalcBreakEven(UseMultipleMoveStopOnce, OrderTicket(), (CalculateRange(OrderOpenTime()) * MoveStopToMultiple) / Point + (MoveStopToMultipleBuffer.Points), (CalculateRange(OrderOpenTime()) * MoveStopWhenRangeMultiple) / Point + MoveStopWhenRangeMulBuf.Points);
            TrailStop         = CalcTrailingStop(UseTrailingStop, OrderTicket(), TrailingStop.Points);
            TrailStop1        = CalcTrailingStop(UseMultipleTrailingStop, OrderTicket(), (CalculateRange(OrderOpenTime()) * TSMultiple) / Point + TSMultipleBuffer.Points);

            if ((BEven      < PotentialStopLoss && BEven)      || !PotentialStopLoss) PotentialStopLoss = BEven;
            if ((BEven1     < PotentialStopLoss && BEven1)     || !PotentialStopLoss) PotentialStopLoss = BEven1;
            if ((TrailStop  < PotentialStopLoss && TrailStop)  || !PotentialStopLoss) PotentialStopLoss = TrailStop;
            if ((TrailStop1 < PotentialStopLoss && TrailStop1) || !PotentialStopLoss) PotentialStopLoss = TrailStop1;

            if (PotentialStopLoss != OrderStopLoss() || !OrderStopLoss()) OrderModify(OrderTicket(), OrderOpenPrice(), PotentialStopLoss, OrderTakeProfit(), 0, DarkOrange);
         }
      }
   }

   // entry signal
   if (TradeTrigger == "Open Long")  Order = SIGNAL_BUY;
   if (TradeTrigger == "Open Short") Order = SIGNAL_SELL;

   // buy
   if (Order==SIGNAL_BUY && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars!=OpenBarCount)))) {
      if (!IsTrade && TradesThisBar < 1) {
         StopLossLevel = 0;
         if (UseStopLoss) {
            if (StopLoss.Points && Ask - StopLoss.Points*Point                                > StopLossLevel) StopLossLevel = Ask - StopLoss.Points*Point;
            if (SLMultiplier    && Ask - Range*SLMultiplier - SLMultiplierBuffer.Points*Point > StopLossLevel) StopLossLevel = Ask - Range*SLMultiplier - SLMultiplierBuffer.Points*Point;
         }

         TakeProfitLevel = 0;
         if (UseTakeProfit) {
            if (TakeProfit.Points && Ask + TakeProfit.Points*Point                              > TakeProfitLevel) TakeProfitLevel = Ask + TakeProfit.Points*Point;
            if (TPMultiplier      && Ask + Range*TPMultiplier + TPMultiplierBuffer.Points*Point > TakeProfitLevel) TakeProfitLevel = Ask + Range*TPMultiplier + TPMultiplierBuffer.Points*Point;
         }

         Ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage.Points, StopLossLevel, TakeProfitLevel, "breakout long", MagicNumber, 0, DodgerBlue);
         if (Ticket > 0) {
            if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES)) {
               if (Alerts     && LongAlertSignalBarCount != Bars) LongAlertSignalBarCount = Bars;
               if (PlaySounds && LongSoundSignalBarCount != Bars) LongSoundSignalBarCount = Bars;
               TradesThisBar++;
            }
            else Alert("Error opening long order: ", GetLastError());
         }
         if (EachTickMode) TickCheck = true;
         else              OpenBarCount = Bars;
         return(0);
      }
   }

   // sell
   if (Order==SIGNAL_SELL && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars!=OpenBarCount)))) {
      if (!IsTrade && TradesThisBar < 1) {
         StopLossLevel = 0;
         if (UseStopLoss) {
            if (StopLoss.Points && ((Bid + StopLoss.Points*Point <= StopLossLevel) || !StopLossLevel))                                StopLossLevel = Bid + StopLoss.Points*Point;
            if (SLMultiplier    && ((Bid + SLMultiplier*Range + SLMultiplierBuffer.Points*Point <= StopLossLevel) || !StopLossLevel)) StopLossLevel = Bid + SLMultiplier*Range + SLMultiplierBuffer.Points*Point;
         }

         TakeProfitLevel = 0;
         if (UseTakeProfit) {
            if (TakeProfit.Points && ((Bid - TakeProfit.Points*Point <= TakeProfitLevel) || !TakeProfitLevel))                             TakeProfitLevel = Bid - TakeProfit.Points*Point;
            if (TPMultiplier      && ((Bid - Range*TPMultiplier + TPMultiplierBuffer.Points*Point < TakeProfitLevel) || !TakeProfitLevel)) TakeProfitLevel = Bid - Range*TPMultiplier + TPMultiplierBuffer.Points*Point;
         }

         Ticket = OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage.Points, StopLossLevel, TakeProfitLevel, "breakout short", MagicNumber, 0, DeepPink);
         if (Ticket > 0) {
            if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES)) {
               if (Alerts     && ShortAlertSignalBarCount != Bars) ShortAlertSignalBarCount = Bars;
               if (PlaySounds && ShortSoundSignalBarCount != Bars) ShortSoundSignalBarCount = Bars;
               TradesThisBar++;
            }
            else Alert("Error opening short order: ", GetLastError());
         }
         if (EachTickMode) TickCheck = true;
         else              OpenBarCount = Bars;
         return(0);
      }
   }

   if (!EachTickMode) CloseBarCount = Bars;
   return(0);
}


/**
 *
 */
double CalcBreakEven(bool condition, int ticket, int moveStopTo, int moveStopWhenPrice) {
   OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);

   if (OrderType() == OP_BUY) {
      if (condition && moveStopWhenPrice > 0) {
         if (Bid-OrderOpenPrice() >= moveStopWhenPrice*Point) {
            return(OrderOpenPrice() + moveStopTo*Point);
         }
      }
   }
   else if (OrderType() == OP_SELL) {
      if (condition && moveStopWhenPrice > 0) {
         if (OrderOpenPrice()-Ask >= moveStopWhenPrice*Point) {
            return(OrderOpenPrice() - moveStopTo*Point);
         }
      }
   }
   return(0);
}


/**
 *
 */
double CalcTrailingStop(bool condition, int ticket, int trailingStop) {
   OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);

   if (OrderType() == OP_BUY) {
      if (condition && trailingStop > 0) {
         if (Bid-OrderOpenPrice() > trailingStop*Point) {
            return(Bid - trailingStop*Point);
         }
      }
   }
   else if (OrderType() == OP_SELL) {
      if (condition && trailingStop > 0) {
         if (OrderOpenPrice()-Ask > trailingStop*Point) {
            return(Ask + trailingStop*Point);
         }
      }
   }
   return(0);
}


/**
 *
 */
double CalculateRange(datetime time) {
   datetime RangeStartTime = StrToTime(RangeStartHour +":"+ RangeStartMinute);
   datetime RangeStopTime  = StrToTime(RangeStopHour  +":"+ RangeStopMinute);

   while (RangeStopTime >= time) {
      RangeStartTime = RangeStartTime - 86400;
      RangeStopTime  = RangeStopTime  - 86400;
   }

   while (RangeStartTime > RangeStopTime) {
      RangeStartTime = RangeStartTime - 86400;
   }
   int RangeStartShift = iBarShift(NULL, NULL, RangeStartTime, false);
   int RangeStopShift  = iBarShift(NULL, NULL, RangeStopTime, false);

   double HighPrice = iHigh(NULL, NULL, iHighest(NULL, NULL, MODE_HIGH, RangeStartShift-RangeStopShift, RangeStopShift));
   double LowPrice  =  iLow(NULL, NULL,  iLowest(NULL, NULL, MODE_LOW,  RangeStartShift-RangeStopShift, RangeStopShift));

   return(HighPrice - LowPrice);
}
