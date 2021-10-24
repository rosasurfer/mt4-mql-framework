/**
 * Rewritten and enhanced version of Generic Breakout v7 [TD] by Ronald Raygun
 *
 * rsf-History:
 *  - removed tickdatabase functionality
 *
 * @source  https://www.forexfactory.com/thread/post/3775867#post3775867                  [RonaldRaygun: Generic Breakout v7]
 */
extern string Remark1 = "== Main Settings ==";
extern int    MagicNumber = 0;
extern bool   SignalsOnly = false;
extern bool   Alerts = false;
extern bool   SignalMail = false;
extern bool   PlaySounds = false;
extern bool   ECNBroker = false;
extern bool   UseTradingTimes = false;
extern int    StartHour = 0;
extern int    StartMinute = 0;
extern int    StopHour = 0;
extern int    StopMinute = 0;
extern bool   CloseOnOppositeSignal = true;
extern bool   AutoDetect5DigitBroker = false;
extern bool   EachTickMode = true;
extern double Lots = 0;
extern bool   MoneyManagement = false;
extern int    Risk = 0;
extern int    Slippage = 5;
extern bool   UseStopLoss = true;
extern int    StopLoss = 100;
extern double SLMultiplier = 0.0;
extern int    SLMultiplierBuffer = 0;
extern bool   UseTakeProfit = false;
extern int    TakeProfit = 60;
extern double TPMultiplier = 0.0;
extern int    TPMultiplierBuffer = 0;
extern bool   UseTrailingStop = false;
extern int    TrailingStop = 30;
extern bool   UseMultipleTrailingStop = false;
extern double TSMultiple = 1.0;
extern int    TSMultipleBuffer = 1.0;
extern bool   MoveStopOnce = false;
extern int    MoveStopWhenPrice = 50;
extern int    MoveStopTo = 1;
extern bool   UseMultipleMoveStopOnce = false;
extern double MoveStopWhenRangeMultiple = 1.0;
extern int    MoveStopWhenRangeMultipleBuffer = 0;
extern double MoveStopToMultiple = 0.0;
extern int    MoveStopToMultipleBuffer = 1;
extern string Remark2 = "";
extern string Remark3 = "== Breakout Settings ==";
extern int    RangeStartHour = 0;
extern int    RangeStartMinute = 0;
extern int    RangeStopHour = 0;
extern int    RangeStopMinute = 0;
extern string TSDescription = "Trading Style: 1 - Breakout | 2 - Counter Trend";
extern int    TradingStyle = 0;
extern double EntryMultiplier = 0.0;
extern int    EntryBuffer = 0;
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

#define maxreadlen 200

string   SymbolUsed;
int      TickCount = 0;
int      RecordDay = -1;
string   UserName = "";
bool     ShowDiagnostics = false;

int      Internet_Open_Type_Direct = 1;
string   URL;
int      URLHandle = 0;
int      SessionHandle = 0;
int      MaxTries = 0;

string   FinalStr ;
int      bytesreturned[1];
int      readresult;

int      GMTBar;
string   GMTTime;
string   BrokerTime;
int      GMTShift;

datetime CurGMTTime;
datetime CurBrokerTime;
datetime CurrentGMTTime;

string   TempStr = "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

int      TradeBar;
int      TradesThisBar;

int      OpenBarCount;
int      CloseBarCount;

int      LongMailSignalBarCount;
int      ShortMailSignalBarCount;

int      LongAlertSignalBarCount;
int      ShortAlertSignalBarCount;

int      LongSoundSignalBarCount;
int      ShortSoundSignalBarCount;

string   BrokerType = "4-Digit Broker";
double   BrokerMultiplier = 1;

int      Current;
bool     TickCheck = false;


/**
 * Initialization
 *
 * @return int - error status
 */
int init() {
   OpenBarCount = Bars;
   CloseBarCount = Bars;

   LongMailSignalBarCount = Bars;
   ShortMailSignalBarCount = Bars;

   LongAlertSignalBarCount = Bars;
   ShortAlertSignalBarCount = Bars;

   LongAlertSignalBarCount = Bars;
   ShortAlertSignalBarCount = Bars;

   if(Digits == 3 || Digits == 5)
      {
      BrokerType = "5-Digit Broker";
      BrokerMultiplier = 10;
      }

   if(AutoDetect5DigitBroker)
      {
      Slippage *= BrokerMultiplier;
      StopLoss *= BrokerMultiplier;
      SLMultiplierBuffer *= BrokerMultiplier;
      TakeProfit *= BrokerMultiplier;
      TPMultiplierBuffer *= BrokerMultiplier;
      TrailingStop *= BrokerMultiplier;
      TSMultipleBuffer *= BrokerMultiplier;
      MoveStopWhenPrice *= BrokerMultiplier;
      MoveStopTo *= BrokerMultiplier;
      MoveStopWhenRangeMultipleBuffer *= BrokerMultiplier;
      MoveStopToMultipleBuffer *= BrokerMultiplier;
      EntryBuffer *= BrokerMultiplier;
      }

   if (EachTickMode) Current = 0; else Current = 1;

   return(0);
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int deinit() {

   for(int OT = ObjectsTotal(); OT >= 0; OT--)
      {
      if(StringFind(ObjectName(OT), WindowExpertName(), 0) == 0)
         {
         ObjectDelete(ObjectName(OT));
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

   if(TradingStyle == 0)
      {
      Alert("Please set the trading style to something other than 0.");
      return(0);
      }

   int Order = SIGNAL_NONE;
   int Total, Ticket;
   double StopLossLevel, TakeProfitLevel;
   double PotentialStopLoss;
   double BEven;
   double BEven1;
   double TrailStop;
   double TrailStop1;



   if (EachTickMode && Bars != CloseBarCount) TickCheck = false;
   Total = OrdersTotal();
   Order = SIGNAL_NONE;

//Limit Trades Per Bar
if(TradeBar != Bars)
   {
   TradeBar = Bars;
   TradesThisBar = 0;
   }


//Money Management sequence
 if (MoneyManagement)
   {
      if (Risk<1 || Risk>100)
      {
         Comment("Invalid Risk Value.");
         return(0);
      }
      else
      {
         Lots=MathFloor((AccountFreeMargin()*AccountLeverage()*Risk*Point*BrokerMultiplier*100)/(Ask*MarketInfo(Symbol(),MODE_LOTSIZE)*MarketInfo(Symbol(),MODE_MINLOT)))*MarketInfo(Symbol(),MODE_MINLOT);
      }
   }

   //+------------------------------------------------------------------+
   //| Variable Begin                                                   |
   //+------------------------------------------------------------------+

   static double PreviousTick;
   static double CurrentTick;

   PreviousTick = CurrentTick;
   CurrentTick = iClose(NULL, 0, Current + 0);

   string TradingTimes = "Outside Trading Times";
   datetime StartTime = StrToTime(TimeYear(TimeCurrent())+"."+TimeMonth(TimeCurrent())+"."+TimeDay(TimeCurrent())+" "+StartHour+":"+StartMinute);
   datetime StopTime = StrToTime(TimeYear(TimeCurrent())+"."+TimeMonth(TimeCurrent())+"."+TimeDay(TimeCurrent())+" "+StopHour+":"+StopMinute);
   if(UseTradingTimes)
      {
      if(StopTime > StartTime && TimeCurrent() >= StartTime && TimeCurrent() < StopTime) TradingTimes = "Inside Trading Times";
      if(StopTime < StartTime && (TimeCurrent() >= StartTime || TimeCurrent() < StopTime)) TradingTimes = "Inside Trading Times";
      }
   if(!UseTradingTimes) TradingTimes = "Not Used";

   //Calculate the Day's Range
   datetime RangeStartTime = StrToTime(TimeYear(TimeCurrent())+"."+TimeMonth(TimeCurrent())+"."+TimeDay(TimeCurrent())+" "+RangeStartHour+":"+RangeStartMinute);
   datetime RangeStopTime = StrToTime(TimeYear(TimeCurrent())+"."+TimeMonth(TimeCurrent())+"."+TimeDay(TimeCurrent())+" "+RangeStopHour+":"+RangeStopMinute);

   if(RangeStopTime >= TimeCurrent())
      {
      RangeStartTime = RangeStartTime - 86400;
      RangeStopTime = RangeStopTime - 86400;
      }
   if(RangeStartTime > RangeStopTime)
      {
      RangeStartTime = RangeStartTime - 86400;
      }
   int RangeStartShift = iBarShift(NULL, 0, RangeStartTime, false);
   int RangeStopShift = iBarShift(NULL, 0, RangeStopTime, false);

   double HighPrice = iHigh(NULL, 0, iHighest(NULL, 0, MODE_HIGH, RangeStartShift - RangeStopShift, RangeStopShift));
   double LowPrice = iLow(NULL, 0, iLowest(NULL, 0, MODE_LOW, RangeStartShift - RangeStopShift, RangeStopShift));

   double Range = HighPrice - LowPrice;

   double Buffer = (Range * EntryMultiplier) + (EntryBuffer * Point);

   double LongEntry = 0.0;
   double ShortEntry = 0.0;
   switch (TradingStyle)
      {
      case 1:
         LongEntry = HighPrice + Buffer;
         ShortEntry = LowPrice - Buffer;
         break;
      case 2:
         LongEntry = LowPrice - Buffer;
         ShortEntry = HighPrice + Buffer;
         break;
      }

   string RangeFilter = "No Trade";
   string MaxRangeFilter = "No Trade";
   string MinRangeFilter = "No Trade";
   if(MaxRangePips * Point >= Range) MaxRangeFilter = "Can Trade";
   if(MinRangePips * Point <= Range) MinRangeFilter = "Can Trade";
   if(MaxRangePips == 0) MaxRangeFilter = "Not Used";
   if(MinRangePips == 0) MinRangeFilter = "Not Used";
   if(MaxRangeFilter == "Can Trade" && MinRangeFilter == "Can Trade") RangeFilter = "Between Min and Max Range";
   if(MaxRangeFilter == "Can Trade" && MinRangeFilter == "Not Used") RangeFilter = "Inside Max Range";
   if(MaxRangeFilter == "Not Used" && MinRangeFilter == "Can Trade") RangeFilter = "Outside Min Range";
   if(MaxRangeFilter == "Not Used" && MinRangeFilter == "Not Used") RangeFilter = "Not Used";

   //Count Trades Taken
   int TotalTrades = 0;
   int LongTrades = 0;
   int ShortTrades = 0;
   int ProfitTrades = 0;
   int LossTrades = 0;
   int SimultaneousTrades = 0;
   int SimultaneousLongTrades = 0;
   int SimultaneousShortTrades = 0;

   for(int OC = OrdersTotal(); OC >= 0; OC--)
      {
      OrderSelect(OC, SELECT_BY_POS, MODE_TRADES);
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && (OrderType() == OP_BUY || OrderType() == OP_SELL) && OrderOpenTime() >= RangeStopTime)
         {
         TotalTrades++;
         SimultaneousTrades++;
         if(OrderType() == OP_BUY)
            {
            LongTrades++;
            SimultaneousLongTrades++;
            }
         if(OrderType() == OP_SELL)
            {
            ShortTrades++;
            SimultaneousShortTrades++;
            }
         if(CountOpenTrades)
            {
            if(OrderProfit() > 0.0) ProfitTrades++;
            if(OrderProfit() < 0.0) LossTrades++;
            }
         }
      }
   for(OC = OrdersHistoryTotal(); OC >= 0; OC--)
      {
      OrderSelect(OC, SELECT_BY_POS, MODE_HISTORY);
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && (OrderType() == OP_BUY || OrderType() == OP_SELL) && OrderOpenTime() >= RangeStopTime)
         {
         TotalTrades++;
         if(OrderType() == OP_BUY) LongTrades++;
         if(OrderType() == OP_SELL) ShortTrades++;
         if(OrderProfit() > 0.0) ProfitTrades++;
         if(OrderProfit() < 0.0) LossTrades++;
         }
      }

   string TradeCheck = "Can Trade";
   if(MaxSimultaneousTrades != 0 && SimultaneousTrades >= MaxSimultaneousTrades) TradeCheck = "No Trade";
   if(MaxTrades != 0 && TotalTrades >= MaxTrades) TradeCheck = "No Trade";
   if(MaxProfitTrades != 0 && ProfitTrades >= MaxProfitTrades) TradeCheck = "No Trade";
   if(MaxLossTrades != 0 && LossTrades >= MaxLossTrades) TradeCheck = "No Trade";


   string LongTradeCheck = "Can Trade";
   if(MaxSimultaneousLongTrades != 0 && SimultaneousLongTrades >= MaxSimultaneousLongTrades) LongTradeCheck = "No Trade";
   if(MaxLongTrades != 0 && LongTrades >= MaxLongTrades) LongTradeCheck = "No Trade";

   string ShortTradeCheck = "Can Trade";
   if(MaxSimultaneousShortTrades != 0 && SimultaneousShortTrades >= MaxSimultaneousShortTrades) ShortTradeCheck = "No Trade";
   if(MaxShortTrades != 0 && ShortTrades >= MaxShortTrades) ShortTradeCheck = "No Trade";

   string TradeTrigger = "None";
   if(TradeCheck == "Can Trade" && RangeFilter != "No Trade" && TradingTimes != "Outside Trading Times")
      {
      if(LongTradeCheck == "Can Trade" && CurrentTick >= LongEntry && PreviousTick < LongEntry && iOpen(NULL, 0, Current + 0) < LongEntry) TradeTrigger = "Open Long";
      if(ShortTradeCheck == "Can Trade" && CurrentTick <= ShortEntry && PreviousTick > ShortEntry && iOpen(NULL, 0, Current + 0) > ShortEntry) TradeTrigger = "Open Short";
      }

   Comment("Broker Type: ", BrokerType, "\n",
           "Trading Times: ", TradingTimes, "\n",
           "Range Filter: ", RangeFilter, "\n",
           "Trade Check: ", TradeCheck, "\n",
           "Long Trade Check: ", LongTradeCheck, "\n",
           "Short Trade Check: ", ShortTradeCheck, "\n",
           "Trade Trigger: ", TradeTrigger);

   if(RangeStartTime != RangeStopTime)
      {
      ObjectDelete(WindowExpertName()+" "+"RangeStart");
      ObjectCreate(WindowExpertName()+" "+"RangeStart", OBJ_TREND, 0, RangeStartTime, HighPrice, RangeStartTime, LowPrice);
      ObjectSet(WindowExpertName()+" "+"RangeStart", OBJPROP_RAY, false);
      ObjectSet(WindowExpertName()+" "+"RangeStart", OBJPROP_COLOR, Yellow);
      ObjectSet(WindowExpertName()+" "+"RangeStart", OBJPROP_STYLE, STYLE_DASHDOTDOT);
      ObjectSet(WindowExpertName()+" "+"RangeStart", OBJPROP_BACK, true);

      ObjectDelete(WindowExpertName()+" "+"RangeStop");
      ObjectCreate(WindowExpertName()+" "+"RangeStop", OBJ_TREND, 0, RangeStopTime, HighPrice, RangeStopTime, LowPrice);
      ObjectSet(WindowExpertName()+" "+"RangeStop", OBJPROP_RAY, false);
      ObjectSet(WindowExpertName()+" "+"RangeStop", OBJPROP_COLOR, Yellow);
      ObjectSet(WindowExpertName()+" "+"RangeStop", OBJPROP_STYLE, STYLE_DASHDOTDOT);
      ObjectSet(WindowExpertName()+" "+"RangeStop", OBJPROP_BACK, true);

      ObjectDelete(WindowExpertName()+" "+"RangeHigh");
      ObjectCreate(WindowExpertName()+" "+"RangeHigh", OBJ_TREND, 0, RangeStartTime, HighPrice, RangeStopTime, HighPrice);
      ObjectSet(WindowExpertName()+" "+"RangeHigh", OBJPROP_RAY, false);
      ObjectSet(WindowExpertName()+" "+"RangeHigh", OBJPROP_COLOR, Yellow);
      ObjectSet(WindowExpertName()+" "+"RangeHigh", OBJPROP_STYLE, STYLE_DASHDOTDOT);
      ObjectSet(WindowExpertName()+" "+"RangeHigh", OBJPROP_BACK, true);

      ObjectDelete(WindowExpertName()+" "+"RangeLow");
      ObjectCreate(WindowExpertName()+" "+"RangeLow", OBJ_TREND, 0, RangeStartTime, LowPrice, RangeStopTime, LowPrice);
      ObjectSet(WindowExpertName()+" "+"RangeLow", OBJPROP_RAY, false);
      ObjectSet(WindowExpertName()+" "+"RangeLow", OBJPROP_COLOR, Yellow);
      ObjectSet(WindowExpertName()+" "+"RangeLow", OBJPROP_STYLE, STYLE_DASHDOTDOT);
      ObjectSet(WindowExpertName()+" "+"RangeLow", OBJPROP_BACK, true);

      ObjectDelete(WindowExpertName()+" "+"LongEntry");
      ObjectCreate(WindowExpertName()+" "+"LongEntry", OBJ_TREND, 0, RangeStartTime, LongEntry, RangeStopTime, LongEntry);
      ObjectSet(WindowExpertName()+" "+"LongEntry", OBJPROP_RAY, true);
      ObjectSet(WindowExpertName()+" "+"LongEntry", OBJPROP_COLOR, Lime);
      ObjectSet(WindowExpertName()+" "+"LongEntry", OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSet(WindowExpertName()+" "+"LongEntry", OBJPROP_BACK, true);

      ObjectDelete(WindowExpertName()+" "+"ShortEntry");
      ObjectCreate(WindowExpertName()+" "+"ShortEntry", OBJ_TREND, 0, RangeStartTime, ShortEntry, RangeStopTime, ShortEntry);
      ObjectSet(WindowExpertName()+" "+"ShortEntry", OBJPROP_RAY, true);
      ObjectSet(WindowExpertName()+" "+"ShortEntry", OBJPROP_COLOR, Red);
      ObjectSet(WindowExpertName()+" "+"ShortEntry", OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSet(WindowExpertName()+" "+"ShortEntry", OBJPROP_BACK, true);
      }

   //+------------------------------------------------------------------+
   //| Variable End                                                     |
   //+------------------------------------------------------------------+

   //Check position
   bool IsTrade = false;

   for (int i = 0; i < Total; i ++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if(OrderType() <= OP_SELL &&  OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
         IsTrade = true;
         if(OrderType() == OP_BUY) {


            //Close

            //+------------------------------------------------------------------+
            //| Signal Begin(Exit Buy)                                           |
            //+------------------------------------------------------------------+

            if(CloseOnOppositeSignal && TradeTrigger == "Open Short") Order = SIGNAL_CLOSEBUY;

            //+------------------------------------------------------------------+
            //| Signal End(Exit Buy)                                             |
            //+------------------------------------------------------------------+

            if (Order == SIGNAL_CLOSEBUY && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars != CloseBarCount)))) {
               OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, MediumSeaGreen);
               if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Bid, Digits) + " Close Buy");
               if (!EachTickMode) CloseBarCount = Bars;
               IsTrade = false;
               continue;
            }

            PotentialStopLoss = OrderStopLoss();
            BEven = BreakEvenValue(MoveStopOnce, OrderTicket(), MoveStopTo, MoveStopWhenPrice);
            BEven1 = BreakEvenValue(UseMultipleMoveStopOnce, OrderTicket(), (CalculateRange(OrderOpenTime()) * MoveStopToMultiple) / Point + (MoveStopToMultipleBuffer), (CalculateRange(OrderOpenTime()) * MoveStopWhenRangeMultiple) / Point + (MoveStopWhenRangeMultipleBuffer));
            TrailStop = TrailingStopValue(UseTrailingStop, OrderTicket(), TrailingStop);
            TrailStop1 = TrailingStopValue(UseMultipleTrailingStop, OrderTicket(), (CalculateRange(OrderOpenTime()) * TSMultiple) / Point + (TSMultipleBuffer));

            if(BEven > PotentialStopLoss && BEven != 0) PotentialStopLoss = BEven;
            if(BEven1 > PotentialStopLoss && BEven1 != 0) PotentialStopLoss = BEven1;
            if(TrailStop > PotentialStopLoss && TrailStop != 0) PotentialStopLoss = TrailStop;
            if(TrailStop1 > PotentialStopLoss && TrailStop1 != 0) PotentialStopLoss = TrailStop1;

            if(PotentialStopLoss != OrderStopLoss()) OrderModify(OrderTicket(),OrderOpenPrice(), PotentialStopLoss, OrderTakeProfit(), 0, MediumSeaGreen);

         } else {

            //Close

            //+------------------------------------------------------------------+
            //| Signal Begin(Exit Sell)                                          |
            //+------------------------------------------------------------------+

            if(CloseOnOppositeSignal && TradeTrigger == "Open Long") Order = SIGNAL_CLOSESELL;

            //+------------------------------------------------------------------+
            //| Signal End(Exit Sell)                                            |
            //+------------------------------------------------------------------+

            if (Order == SIGNAL_CLOSESELL && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars != CloseBarCount)))) {
               OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, DarkOrange);
               if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Ask, Digits) + " Close Sell");
               if (!EachTickMode) CloseBarCount = Bars;
               IsTrade = false;
               continue;
            }

            PotentialStopLoss = OrderStopLoss();
            BEven = BreakEvenValue(MoveStopOnce, OrderTicket(), MoveStopTo, MoveStopWhenPrice);
            BEven1 = BreakEvenValue(UseMultipleMoveStopOnce, OrderTicket(), (CalculateRange(OrderOpenTime()) * MoveStopToMultiple) / Point + (MoveStopToMultipleBuffer), (CalculateRange(OrderOpenTime()) * MoveStopWhenRangeMultiple) / Point + (MoveStopWhenRangeMultipleBuffer));
            TrailStop = TrailingStopValue(UseTrailingStop, OrderTicket(), TrailingStop);
            TrailStop1 = TrailingStopValue(UseMultipleTrailingStop, OrderTicket(), (CalculateRange(OrderOpenTime()) * TSMultiple) / Point + (TSMultipleBuffer));


            if((BEven < PotentialStopLoss && BEven != 0) || (PotentialStopLoss == 0)) PotentialStopLoss = BEven;
            if((BEven1 < PotentialStopLoss && BEven1 != 0) || (PotentialStopLoss == 0)) PotentialStopLoss = BEven1;
            if((TrailStop < PotentialStopLoss && TrailStop != 0) || (PotentialStopLoss == 0)) PotentialStopLoss = TrailStop;
            if((TrailStop1 < PotentialStopLoss && TrailStop1 != 0) || (PotentialStopLoss == 0)) PotentialStopLoss = TrailStop1;

            if(PotentialStopLoss != OrderStopLoss() || OrderStopLoss() == 0) OrderModify(OrderTicket(),OrderOpenPrice(), PotentialStopLoss, OrderTakeProfit(), 0, DarkOrange);

         }
      }
   }

   //+------------------------------------------------------------------+
   //| Signal Begin(Entry)                                              |
   //+------------------------------------------------------------------+

if(TradeTrigger == "Open Long") Order = SIGNAL_BUY;
if(TradeTrigger == "Open Short") Order = SIGNAL_SELL;

   //+------------------------------------------------------------------+
   //| Signal End                                                       |
   //+------------------------------------------------------------------+

   //Buy
   if (Order == SIGNAL_BUY && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars != OpenBarCount)))) {
      if(SignalsOnly) {
         if (SignalMail && LongMailSignalBarCount != Bars)
            {
            SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Ask, Digits) + "Buy Signal");
            LongMailSignalBarCount = Bars;
            }
         if (Alerts && LongAlertSignalBarCount != Bars)
            {
            Alert("[" + Symbol() + "] " + DoubleToStr(Ask, Digits) + "Buy Signal");
            LongAlertSignalBarCount = Bars;
            }
         if (PlaySounds && LongSoundSignalBarCount != Bars)
            {
            PlaySound("alert.wav");
            LongSoundSignalBarCount = Bars;
            }
      }

      if(!IsTrade && !SignalsOnly && TradesThisBar < 1) {
         //Check free margin
         if (AccountFreeMarginCheck(Symbol(), OP_BUY, Lots) < 0) {
            Print("We have no money. Free Margin = ", AccountFreeMargin());
            return(0);
         }
         StopLossLevel = 0.0;
         TakeProfitLevel = 0.0;
         if (UseStopLoss)
            {
            if(StopLoss != 0 && Ask - StopLoss * Point > StopLossLevel) StopLossLevel = Ask - StopLoss * Point;
            if(SLMultiplier != 0.0 && Ask - (Range * SLMultiplier) - (SLMultiplierBuffer * Point) > StopLossLevel) StopLossLevel = Ask - (Range * SLMultiplier) - (SLMultiplierBuffer * Point);
            }
         if(!UseStopLoss) StopLossLevel = 0.0;

         if (UseTakeProfit)
            {
            if(TakeProfit != 0 && Ask + TakeProfit * Point >= TakeProfitLevel) TakeProfitLevel = Ask + TakeProfit * Point;
            if(TPMultiplier != 0.0 && Ask + (Range * TPMultiplier) + (TPMultiplierBuffer * Point) > TakeProfitLevel) TakeProfitLevel = Ask + (Range * TPMultiplier) + (TPMultiplierBuffer * Point);
            }

         if (!UseTakeProfit) TakeProfitLevel = 0.0;
         if(ECNBroker) Ticket = OrderModify(OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, 0, 0, "Buy(#" + MagicNumber + ")", MagicNumber, 0, DodgerBlue), OrderOpenPrice(), StopLossLevel, TakeProfitLevel, 0, CLR_NONE);
         if(!ECNBroker) Ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, StopLossLevel, TakeProfitLevel, "Buy(#" + MagicNumber + ")", MagicNumber, 0, DodgerBlue);
            if(Ticket > 0) {
               if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES)) {
              Print("BUY order opened : ", OrderOpenPrice());
                  if (SignalMail && LongMailSignalBarCount != Bars)
                     {
                     SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Ask, Digits) + "Buy Signal");
                     LongMailSignalBarCount = Bars;
                     }
                  if (Alerts && LongAlertSignalBarCount != Bars)
                     {
                     Alert("[" + Symbol() + "] " + DoubleToStr(Ask, Digits) + "Buy Signal");
                     LongAlertSignalBarCount = Bars;
                     }
                  if (PlaySounds && LongSoundSignalBarCount != Bars)
                     {
                     PlaySound("alert.wav");
                     LongSoundSignalBarCount = Bars;
                     }
                  TradesThisBar++;
            } else {
               Print("Error opening BUY order : ", GetLastError());
            }
            }

         if (EachTickMode) TickCheck = true;
         if (!EachTickMode) OpenBarCount = Bars;
         return(0);
      }
   }

   //Sell
   if (Order == SIGNAL_SELL && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars != OpenBarCount)))) {
      if(SignalsOnly) {
          if (SignalMail && ShortMailSignalBarCount != Bars)
            {
            SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Bid, Digits) + "Sell Signal");
            ShortMailSignalBarCount = Bars;
            }
          if (Alerts && ShortAlertSignalBarCount != Bars)
            {
            Alert("[" + Symbol() + "] " + DoubleToStr(Bid, Digits) + "Sell Signal");
            ShortAlertSignalBarCount = Bars;
            }
          if (PlaySounds && ShortSoundSignalBarCount != Bars)
            {
            PlaySound("alert.wav");
            ShortSoundSignalBarCount = Bars;
            }
         }
      if(!IsTrade && !SignalsOnly && TradesThisBar < 1) {
         //Check free margin
         if (AccountFreeMarginCheck(Symbol(), OP_SELL, Lots) < 0) {
            Print("We have no money. Free Margin = ", AccountFreeMargin());
            return(0);
         }
         StopLossLevel = 0.0;
         TakeProfitLevel = 0.0;
         if (UseStopLoss)
            {
            if(StopLoss != 0 && ((Bid + StopLoss * Point <= StopLossLevel) || StopLossLevel == 0.0)) StopLossLevel = Bid + StopLoss * Point;
            if(SLMultiplier != 0 && (((Bid + (SLMultiplier * Range) + (SLMultiplierBuffer * Point)) <= StopLossLevel) || StopLossLevel == 0.0)) StopLossLevel = Bid + (SLMultiplier * Range) + (SLMultiplierBuffer * Point);
            }

         if (!UseStopLoss) StopLossLevel = 0.0;


         if (UseTakeProfit)
            {
            if(TakeProfit != 0 && ((Bid - TakeProfit * Point <= TakeProfitLevel) || TakeProfitLevel == 0)) TakeProfitLevel = Bid - TakeProfit * Point;
            if(TPMultiplier != 0.0 && (((Bid - (Range * TPMultiplier) + (TPMultiplierBuffer * Point)) < TakeProfitLevel) || TakeProfitLevel == 0)) TakeProfitLevel = Bid - (Range * TPMultiplier) + (TPMultiplierBuffer * Point);
            }
         if (!UseTakeProfit) TakeProfitLevel = 0.0;

         if(ECNBroker) Ticket = OrderModify(OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, 0, 0, "Sell(#" + MagicNumber + ")", MagicNumber, 0, DeepPink), OrderOpenPrice(), StopLossLevel, TakeProfitLevel, 0, CLR_NONE);
         if(!ECNBroker) Ticket = OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, StopLossLevel, TakeProfitLevel, "Sell(#" + MagicNumber + ")", MagicNumber, 0, DeepPink);
         if(Ticket > 0) {
            if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES)) {
            Print("SELL order opened : ", OrderOpenPrice());
                if (SignalMail && ShortMailSignalBarCount != Bars)
                  {
                  SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Bid, Digits) + "Sell Signal");
                  ShortMailSignalBarCount = Bars;
                  }
               if (Alerts && ShortAlertSignalBarCount != Bars)
                  {
                  Alert("[" + Symbol() + "] " + DoubleToStr(Bid, Digits) + "Sell Signal");
                  ShortAlertSignalBarCount = Bars;
                  }
               if (PlaySounds && ShortSoundSignalBarCount != Bars)
                  {
                  PlaySound("alert.wav");
                  ShortSoundSignalBarCount = Bars;
                  }
                TradesThisBar++;
         } else {
            Print("Error opening SELL order : ", GetLastError());
         }
         }
         if (EachTickMode) TickCheck = true;
         if (!EachTickMode) OpenBarCount = Bars;
         return(0);
      }
   }

   if (!EachTickMode) CloseBarCount = Bars;
   return(0);
}


/**
 *
 */
double BreakEvenValue(bool Decision, int OrderTicketNum, int MoveStopTo, int MoveStopwhenPrice) {
   //Select the appropriate order ticket
   OrderSelect(OrderTicketNum, SELECT_BY_TICKET, MODE_TRADES);

   //If the Order is a BUY order...
   if(OrderType() == OP_BUY)
      {
      //Check if the user wants to use the MoveStopOnce function and did it correctly
      if(Decision && MoveStopWhenPrice > 0)
         {
         //Check if the trade is above the required profit threshold
         if(Bid - OrderOpenPrice() >= Point * MoveStopWhenPrice)
            {
            //Return the value of the stoploss
            return(OrderOpenPrice() + Point * MoveStopTo);
            }
         }
      }

   //If the Order is a SELL order...
   if(OrderType() == OP_SELL)
      {
      //Check if the user wants to use the MoveStopOnce function and did it correctly
      if(Decision && MoveStopWhenPrice > 0)
         {
         //Check if the trade is above the required profit threshold
         if(OrderOpenPrice() - Ask >= Point * MoveStopWhenPrice)
            {
            //Return the value of the stoploss
            return(OrderOpenPrice() - Point * MoveStopTo);
            }
         }
      }

   if(OrderType() != OP_BUY || OrderType() != OP_SELL) return(0);
}


/**
 *
 */
double TrailingStopValue(bool Decision, int OrderTicketNum, int FTrailingStop) {
   //Select the appropriate order ticket
   OrderSelect(OrderTicketNum, SELECT_BY_TICKET, MODE_TRADES);

   //If the Order is a BUY order...
   if(OrderType() == OP_BUY)
      {
      //Check if the user wants to use teh Trailingstop function and did it correctly
      if(Decision && FTrailingStop > 0)
         {
         //Check to see that the profit threshold is met
         if(Bid - OrderOpenPrice() > Point * FTrailingStop)
            {
            //Return the value of the potential stoploss
            return(Bid - Point * FTrailingStop);
            }
         }
      }
   //If the Order is a SELL order...
   if(OrderType() == OP_SELL)
      {
      //Check if the user wants to use teh Trailingstop function and did it correctly
      if(Decision && FTrailingStop > 0)
         {
         //Check to see that the profit threshold is met
         if((OrderOpenPrice() - Ask) > (Point * FTrailingStop))
            {
            //Return the value of the potential stoploss
            return(Ask + Point * FTrailingStop);
            }
         }
      }
   //If the trade is not the right order type, give a stoploss of 0
   if(OrderType() != OP_BUY || OrderType() != OP_SELL) return(0);
}


/**
 *
 */
double CalculateRange(datetime TimeReference) {
   datetime RangeStartTime = StrToTime(RangeStartHour+":"+RangeStartMinute);
   datetime RangeStopTime = StrToTime(RangeStopHour+":"+RangeStopMinute);

   while(RangeStopTime >= TimeReference)
      {
      RangeStartTime = RangeStartTime - 86400;
      RangeStopTime = RangeStopTime - 86400;
      }
   while(RangeStartTime > RangeStopTime)
      {
      RangeStartTime = RangeStartTime - 86400;
      }
   int RangeStartShift = iBarShift(NULL, 0, RangeStartTime, false);
   int RangeStopShift = iBarShift(NULL, 0, RangeStopTime, false);

   double HighPrice = iHigh(NULL, 0, iHighest(NULL, 0, PRICE_HIGH, RangeStartShift - RangeStopShift, RangeStopShift));
   double LowPrice = iLow(NULL, 0, iLowest(NULL, 0, PRICE_LOW, RangeStartShift - RangeStopShift, RangeStopShift));

   return(HighPrice - LowPrice);
}
