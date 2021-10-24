/**
 * Rewritten HiLo Trader Self-Optimizing, last version by @stevegee58.
 *
 * History:
 *  - removed tickdatabase functionality
 *
 * @source  https://www.forexfactory.com/thread/post/3922031#post3922031
 */
#define SIGNAL_NONE 0
#define SIGNAL_BUY   1
#define SIGNAL_SELL  2
#define SIGNAL_CLOSEBUY 3
#define SIGNAL_CLOSESELL 4

extern string Remark1 = "== Main Settings ==";
extern int MagicNumber = 0;
extern bool SignalsOnly = False;
extern bool Alerts = False;
extern bool SignalMail = False;
extern bool PlaySounds = False;
extern bool ECNBroker = False;
extern int SleepTime = 100;
extern bool EachTickMode = True;
extern bool AnimateOptimization = True;
extern int MaxSimultaneousTrades = 10;
extern double Lots = 00.1;
extern bool MoneyManagement = False;
extern int Risk = 0;
extern int Slippage = 5;
extern  bool UseStopLoss = True;
extern int StopLoss = 200;
extern bool UseTakeProfit = True;
extern int TakeProfit = 200;
extern bool UseTrailingStop = False;
extern int TrailingStop = 30;
extern bool MoveStopOnce = False;
extern int MoveStopWhenPrice = 50;
extern int MoveStopTo = 1;
extern string Remark2 = "== Breakout Settings ==";
extern int BarsToOptimize = 0;
extern int InitialRange = 60;
extern int MaximumBarShift = 1440;
extern double MinimumWinRate = 50;
extern double MinimumRiskReward = 0;
extern double MinimumSuccessScore = 0;
extern int MinimumSampleSize = 10;
extern bool ReverseTrades = False;
extern string Remark3 = "== Optimize Based On ==";
extern bool HighestProfit = False;
extern bool HighestWinRate = False;
extern bool HighestRiskReward = False;
extern bool HighestSuccessScore = True;


int GMTBar;
string GMTTime;
string BrokerTime;
int GMTShift;

datetime CurGMTTime;
datetime CurBrokerTime;
datetime CurrentGMTTime;

int TradeBar;
int TradesThisBar;

int OpenBarCount;
int CloseBarCount;

int LongMailSignalBarCount;
int ShortMailSignalBarCount;

int LongAlertSignalBarCount;
int ShortAlertSignalBarCount;

int LongSoundSignalBarCount;
int ShortSoundSignalBarCount;

string BrokerType = "4-Digit Broker";
double BrokerMultiplier = 1;

int Current;
bool TickCheck = False;
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
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


   if (EachTickMode) Current = 0; else Current = 1;

   if (!IsTesting() && !IsOptimization()) {
      MasterFunction();
   }
   return(0);
}
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit() {
   return(0);
}
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+

int start() {
   Comment(StartFunction(Symbol()));
   return(0);
}

void MasterFunction()
   {
   int CycleCount = 0;
   int LastTick = 0;
   datetime LastComputerStart;
   datetime LastServerStart;
   datetime LastComputerStop;
   datetime LastServerStop;
   int StartTime;
   string CommentString;
   int TotalTime;
   string Rates = "None";


   while(1 == 1)
      {
      string ServerStartDayOfWeek = "";
      switch(TimeDayOfWeek(LastServerStart))
         {
         case 0:
            ServerStartDayOfWeek = "Sunday";
            break;
         case 1:
            ServerStartDayOfWeek = "Monday";
            break;
         case 2:
            ServerStartDayOfWeek = "Tuesday";
            break;
         case 3:
            ServerStartDayOfWeek = "Wednesday";
            break;
         case 4:
            ServerStartDayOfWeek = "Thursday";
            break;
         case 5:
            ServerStartDayOfWeek = "Friday";
            break;
         case 6:
            ServerStartDayOfWeek = "Saturday";
            break;
         }

      string TerminalStartDayOfWeek = "";
      switch(TimeDayOfWeek(LastComputerStart))
         {
         case 0:
            TerminalStartDayOfWeek = "Sunday";
            break;
         case 1:
            TerminalStartDayOfWeek = "Monday";
            break;
         case 2:
            TerminalStartDayOfWeek = "Tuesday";
            break;
         case 3:
            TerminalStartDayOfWeek = "Wednesday";
            break;
         case 4:
            TerminalStartDayOfWeek = "Thursday";
            break;
         case 5:
            TerminalStartDayOfWeek = "Friday";
            break;
         case 6:
            TerminalStartDayOfWeek = "Saturday";
            break;
         }
      string ServerStopDayOfWeek = "";
      switch(TimeDayOfWeek(LastServerStop))
         {
         case 0:
            ServerStopDayOfWeek = "Sunday";
            break;
         case 1:
            ServerStopDayOfWeek = "Monday";
            break;
         case 2:
            ServerStopDayOfWeek = "Tuesday";
            break;
         case 3:
            ServerStopDayOfWeek = "Wednesday";
            break;
         case 4:
            ServerStopDayOfWeek = "Thursday";
            break;
         case 5:
            ServerStopDayOfWeek = "Friday";
            break;
         case 6:
            ServerStopDayOfWeek = "Saturday";
            break;
         }

      string TerminalStopDayOfWeek = "";
      switch(TimeDayOfWeek(LastComputerStop))
         {
         case 0:
            TerminalStopDayOfWeek = "Sunday";
            break;
         case 1:
            TerminalStopDayOfWeek = "Monday";
            break;
         case 2:
            TerminalStopDayOfWeek = "Tuesday";
            break;
         case 3:
            TerminalStopDayOfWeek = "Wednesday";
            break;
         case 4:
            TerminalStopDayOfWeek = "Thursday";
            break;
         case 5:
            TerminalStopDayOfWeek = "Friday";
            break;
         case 6:
            TerminalStopDayOfWeek = "Saturday";
            break;
         }


      Comment("Last Server Start: "+ServerStartDayOfWeek+" ", TimeToStr(LastServerStart, TIME_DATE|TIME_SECONDS), "\n",
              "Last Computer Start: "+TerminalStartDayOfWeek+" ", TimeToStr(LastComputerStart, TIME_DATE|TIME_SECONDS), "\n",
              "Last Server Stop: "+ServerStopDayOfWeek+" ", TimeToStr(LastServerStop, TIME_DATE|TIME_SECONDS), "\n",
              "Last Computer Stop: "+TerminalStopDayOfWeek+" ", TimeToStr(LastComputerStop, TIME_DATE|TIME_SECONDS), "\n",
              "Last Calculation took ", TotalTime, " miliseconds. \n",
              "Refresh Rates: ", Rates, "\n",
              "Last Tick: ", LastTick, "\n",
              "Cycle Count: ", CycleCount, "\n",
              CommentString);


      if(RefreshRates())
         {
         LastComputerStart = TimeLocal();
         LastServerStart = TimeCurrent();
         StartTime = GetTickCount();
         CommentString = StartFunction(Symbol());

         TotalTime = GetTickCount() - StartTime;
         Rates = "True";
         LastTick = 0;
         }
         else
         {
         CycleCount++;
         LastTick++;
         Rates = "False";
         Sleep(SleepTime);
         }
         LastComputerStop = TimeLocal();
         LastServerStop = TimeCurrent();
      }
   }

string StartFunction(string SymbolUsed)

{
   int Order = SIGNAL_NONE;
   int Total, Ticket;
   double StopLossLevel, TakeProfitLevel;
   double PotentialStopLoss;
   double BEven;
   double TrailStop;



   if (EachTickMode && Bars != CloseBarCount) TickCheck = False;
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

static int LastCalcDay;
static int BarCount;
static string LastOptimize;

if(TimeDayOfYear(TimeCurrent()) != LastCalcDay)
   {
   BarCount = SelfOptimize(SymbolUsed);
   LastCalcDay = TimeDayOfYear(TimeCurrent());
   LastOptimize = TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   }

//Determine Day's start
int DayStart = iBarShift(NULL, 0, StrToTime("00:00"), False);
int RangeStart = DayStart - InitialRange;

//Determine Current Hilo
int HighShift =  iHighest(NULL, 0, MODE_HIGH, RangeStart - 1, 1);
int LowShift = iLowest(NULL, 0, MODE_LOW, RangeStart - 1, 1);

double HighPrice = iHigh(NULL, 0, HighShift);
double LowPrice = iLow(NULL, 0, LowShift);

//Read Back Optimized Values
static int CurrentHour;
static int CurrentHighTP;
static int CurrentHighProfit;
static double CurrentWinRate;
static double CurrentRiskReward;
static double CurrentSuccessScore;
static string CurrentTradeStyle;
static int CurrentArraySizes;
static int CurrentArrayNum;

if(CurrentHour != TimeHour(TimeCurrent()))
   int Handle = FileOpen(WindowExpertName()+" "+SymbolUsed+" Optimized Settings.csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
   if(Handle == -1)
      {
      return(0);
      }
   if(Handle > 0)
      {
      while(!FileIsEnding(Handle))
         {
         int HourUsed = StrToInteger(FileReadString(Handle));
         int HighTP = StrToInteger(FileReadString(Handle));
         int HighProfit =  StrToInteger(FileReadString(Handle));
         double HighWinRate = StrToDouble(FileReadString(Handle));
         double HighRiskReward = StrToDouble(FileReadString(Handle));
         double HighSuccessScore = StrToDouble(FileReadString(Handle));
         string TradeStyle = FileReadString(Handle);
         int ArraySizes = StrToInteger(FileReadString(Handle));
         int ArrayNum = StrToInteger(FileReadString(Handle));

         if(HourUsed == TimeHour(TimeCurrent()))
            {
            CurrentHour = HourUsed;
            CurrentHighTP = HighTP;
            CurrentHighProfit = HighProfit;
            CurrentWinRate = HighWinRate;
            CurrentRiskReward = HighRiskReward;
            CurrentSuccessScore = HighSuccessScore;
            CurrentTradeStyle = TradeStyle;
            CurrentArraySizes = ArraySizes;
            CurrentArrayNum = ArrayNum;
            break;
            }
         }
      }
   if(Handle > 0) FileClose(Handle);

if(!ReverseTrades) TakeProfit = CurrentHighTP;
if(ReverseTrades) StopLoss = CurrentHighTP;

//Count Number of open trades
int TradeCount = 0;
for(int OT = OrdersTotal(); OT >= 0; OT--)
   {
   OrderSelect(OT, SELECT_BY_POS, MODE_TRADES);
   if(OrderMagicNumber() == MagicNumber && OrderSymbol() == SymbolUsed && (OrderType() == OP_BUY || OrderType() == OP_SELL)) TradeCount++;
   }

string TradeTrigger1 = "None";
if((TradeCount < MaxSimultaneousTrades || MaxSimultaneousTrades == 0) && CurrentArraySizes >= MinimumSampleSize && DayStart > InitialRange && CurrentTradeStyle == "Breakout" && Close[Current] > HighPrice) TradeTrigger1 = "Open Long";
if((TradeCount < MaxSimultaneousTrades || MaxSimultaneousTrades == 0) && CurrentArraySizes >= MinimumSampleSize && DayStart > InitialRange && CurrentTradeStyle == "Counter" && Close[Current] > HighPrice) TradeTrigger1 = "Open Short";
if((TradeCount < MaxSimultaneousTrades || MaxSimultaneousTrades == 0) && CurrentArraySizes >= MinimumSampleSize && DayStart > InitialRange && CurrentTradeStyle == "Breakout" && Close[Current] < LowPrice) TradeTrigger1 = "Open Short";
if((TradeCount < MaxSimultaneousTrades || MaxSimultaneousTrades == 0) && CurrentArraySizes >= MinimumSampleSize && DayStart > InitialRange && CurrentTradeStyle == "Counter" && Close[Current] < LowPrice) TradeTrigger1 = "Open Long";

string TradeTrigger = TradeTrigger1;
if(ReverseTrades && TradeTrigger1 == "Open Long") TradeTrigger = "Open Short";
if(ReverseTrades && TradeTrigger1 == "Open Short") TradeTrigger = "Open Long";

string CommentString = StringConcatenate("Broker Type: ", BrokerType, "\n",
                                         "Last Optimized: ", LastOptimize, "\n",
                                         "Bars Used: ", BarCount, "\n",
                                         "Total Bars: ", Bars, "\n",
                                         "Current Hour: ", CurrentHour, "\n",
                                         "Current TP: ", CurrentHighTP, "\n",
                                         "Current Win Rate: ", CurrentWinRate * 100.0, "% (", MinimumWinRate, ")\n",
                                         "Current Risk Reward: ", CurrentRiskReward, " (", MinimumRiskReward, ")\n",
                                         "Current Success Score: ", CurrentSuccessScore * 100, " (", MinimumSuccessScore, ")\n",
                                         "Array Win: ", CurrentArraySizes - CurrentArrayNum - 1, "\n",
                                         "Array Lose: ", CurrentArrayNum + 1, "\n",
                                         "Total Array: ", CurrentArraySizes, "\n",
                                         "Total Open Trades: ", TradeCount, "\n",
                                         "Trade Style: ", CurrentTradeStyle, "\n",
                                         "Trade Trigger: ", TradeTrigger);

   //+------------------------------------------------------------------+
   //| Variable End                                                     |
   //+------------------------------------------------------------------+

   //Check position
   bool IsTrade = False;

   for (int i = 0; i < Total; i ++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if(OrderType() <= OP_SELL &&  OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
         IsTrade = True;
         if(OrderType() == OP_BUY) {


            //Close

            //+------------------------------------------------------------------+
            //| Signal Begin(Exit Buy)                                           |
            //+------------------------------------------------------------------+

            if(TradeTrigger == "Open Short") Order = SIGNAL_CLOSEBUY;

            //+------------------------------------------------------------------+
            //| Signal End(Exit Buy)                                             |
            //+------------------------------------------------------------------+

            if (Order == SIGNAL_CLOSEBUY && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars != CloseBarCount)))) {
               OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, MediumSeaGreen);
               if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Bid, Digits) + " Close Buy");
               if (!EachTickMode) CloseBarCount = Bars;
               IsTrade = False;
               continue;
            }

            PotentialStopLoss = OrderStopLoss();
            BEven = BreakEvenValue(MoveStopOnce, OrderTicket(), MoveStopTo, MoveStopWhenPrice);
            TrailStop = TrailingStopValue(UseTrailingStop, OrderTicket(), TrailingStop);

            if(BEven > PotentialStopLoss && BEven != 0) PotentialStopLoss = BEven;
            if(TrailStop > PotentialStopLoss && TrailStop != 0) PotentialStopLoss = TrailStop;

            if(PotentialStopLoss != OrderStopLoss()) OrderModify(OrderTicket(),OrderOpenPrice(), PotentialStopLoss, OrderTakeProfit(), 0, MediumSeaGreen);

         } else {

            //Close

            //+------------------------------------------------------------------+
            //| Signal Begin(Exit Sell)                                          |
            //+------------------------------------------------------------------+

            if(TradeTrigger == "Open Long") Order = SIGNAL_CLOSESELL;

            //+------------------------------------------------------------------+
            //| Signal End(Exit Sell)                                            |
            //+------------------------------------------------------------------+

            if (Order == SIGNAL_CLOSESELL && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars != CloseBarCount)))) {
               OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, DarkOrange);
               if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Ask, Digits) + " Close Sell");
               if (!EachTickMode) CloseBarCount = Bars;
               IsTrade = False;
               continue;
            }

            PotentialStopLoss = OrderStopLoss();
            BEven = BreakEvenValue(MoveStopOnce, OrderTicket(), MoveStopTo, MoveStopWhenPrice);
            TrailStop = TrailingStopValue(UseTrailingStop, OrderTicket(), TrailingStop);

            if((BEven < PotentialStopLoss && BEven != 0) || (PotentialStopLoss == 0)) PotentialStopLoss = BEven;
            if((TrailStop < PotentialStopLoss && TrailStop != 0) || (PotentialStopLoss == 0)) PotentialStopLoss = TrailStop;

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

IsTrade = False;
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
            return(CommentString);
         }

         if (UseStopLoss) StopLossLevel = Ask - StopLoss * Point; else StopLossLevel = 0.0;
         if (UseTakeProfit) TakeProfitLevel = Ask + TakeProfit * Point; else TakeProfitLevel = 0.0;
         if(ECNBroker)
         {
            Ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, 0, 0, "Buy(#" + MagicNumber + ")", MagicNumber, 0, DodgerBlue);
            if (Ticket > 0)
            {
               OrderSelect(Ticket, SELECT_BY_TICKET);
               OrderModify(OrderTicket(), OrderOpenPrice(), StopLossLevel, TakeProfitLevel, 0, CLR_NONE);
            }
         }
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

         if (EachTickMode) TickCheck = True;
         if (!EachTickMode) OpenBarCount = Bars;
         return(CommentString);
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
            return(CommentString);
         }

         if (UseStopLoss) StopLossLevel = Bid + StopLoss * Point; else StopLossLevel = 0.0;
         if (UseTakeProfit) TakeProfitLevel = Bid - TakeProfit * Point; else TakeProfitLevel = 0.0;

         if(ECNBroker)
         {
            Ticket = OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, 0, 0, "Sell(#" + MagicNumber + ")", MagicNumber, 0, DeepPink);
            if (Ticket > 0)
            {
               OrderSelect(Ticket,SELECT_BY_TICKET);
               OrderModify(OrderTicket(), OrderOpenPrice(), StopLossLevel, TakeProfitLevel, 0, CLR_NONE);
            }
         }
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
         if (EachTickMode) TickCheck = True;
         if (!EachTickMode) OpenBarCount = Bars;
         return(CommentString);
      }
   }

   if (!EachTickMode) CloseBarCount = Bars;

   return(CommentString);
}


double BreakEvenValue (bool Decision, int OrderTicketNum, int MoveStopTo, int MoveStopwhenPrice)
   {
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

double TrailingStopValue (bool Decision, int OrderTicketNum, int TrailingStop)
   {
   //Select the appropriate order ticket
   OrderSelect(OrderTicketNum, SELECT_BY_TICKET, MODE_TRADES);

   //If the Order is a BUY order...
   if(OrderType() == OP_BUY)
      {
      //Check if the user wants to use teh Trailingstop function and did it correctly
      if(Decision && TrailingStop > 0)
         {
         //Check to see that the profit threshold is met
         if(Bid - OrderOpenPrice() > Point * TrailingStop)
            {
            //Return the value of the potential stoploss
            return(Bid - Point * TrailingStop);
            }
         }
      }
   //If the Order is a SELL order...
   if(OrderType() == OP_SELL)
      {
      //Check if the user wants to use teh Trailingstop function and did it correctly
      if(Decision && TrailingStop > 0)
         {
         //Check to see that the profit threshold is met
         if((OrderOpenPrice() - Ask) > (Point * TrailingStop))
            {
            //Return the value of the potential stoploss
            return(Ask + Point * TrailingStop);
            }
         }
      }
   //If the trade is not the right order type, give a stoploss of 0
   if(OrderType() != OP_BUY || OrderType() != OP_SELL) return(0);
   }

int SelfOptimize(string SymbolUsed)
      {
      int OptimizeBars;
      for(int H = 0; H <= 23; H++)
      {
      }
      DeleteFile(WindowExpertName()+" "+SymbolUsed+" Master Copy.csv");
      DeleteFile(WindowExpertName()+" "+SymbolUsed+" Optimized Settings.csv");
      DeleteFile(WindowExpertName()+" "+SymbolUsed+" All Settings.csv");
      DeleteFile(WindowExpertName()+" "+SymbolUsed+" All Permutation Settings.csv");

      OptimizeBars = BarsToOptimize;
      if(BarsToOptimize == 0) OptimizeBars = iBars(SymbolUsed, 0);
      if(BarsToOptimize > iBars(SymbolUsed, 0))
         {
         Alert("Error: Not enough bars to optimize for symbol: "+SymbolUsed+".");
         return(0);
         }

      //Print("There are "+iBars(SymbolUsed, 0)+" bars on the chart. Only "+OptimizeBars+" bars are being used.");


      int SearchShift;

      int FBarStart = OptimizeBars;
      int DayStartShift = FBarStart;
      int RangeEndShift = FBarStart;
      double HighValue = 0;
      double LowValue = 0;
      double HighValue1 = 0;
      double LowValue1 = 0;
      int HighShift = 0;
      int LowShift = 0;
      int HighClose = 0;
      int LowClose = 0;
      double HighestValue = 0;
      double LowestValue = 0;

      for (SearchShift = DayStartShift; SearchShift > 1; SearchShift--)
         {
         OptimizationComments(" Looking for trades on bar "+SearchShift);
         //Determine if the bar is the daily start
         if(TimeDayOfYear(Time[SearchShift]) != TimeDayOfYear(Time[SearchShift + 1]))
            {
            DayStartShift = SearchShift;
            }
         //Find the end of the range and establish initial high and low
         if(DayStartShift - SearchShift == InitialRange)
            {
            RangeEndShift = SearchShift;
            HighShift = iHighest(SymbolUsed, 0, MODE_HIGH, DayStartShift - RangeEndShift, RangeEndShift);
            HighValue = iHigh(SymbolUsed, 0, HighShift);
            LowShift = iLowest(SymbolUsed, 0, MODE_LOW, DayStartShift - RangeEndShift, RangeEndShift);
            LowValue = iLow(SymbolUsed, 0, LowShift);
            }
         //Determine subsequent high and low
         if(DayStartShift > RangeEndShift)
            {
            if(iHigh(NULL, 0, SearchShift) > HighValue)
               {
               HighValue1 = HighValue;
               HighValue = iHigh(NULL, 0, SearchShift);
               HighClose = MathMax(SearchShift - MaximumBarShift, TradeCloseShift(SymbolUsed, "Long", HighValue1, SearchShift) + 1);
               HighestValue = iHigh(SymbolUsed, 0, iHighest(SymbolUsed, 0, MODE_HIGH, SearchShift - HighClose, HighClose));
               FileWriter(SymbolUsed, TimeHour(iTime(SymbolUsed, 0, SearchShift)), "Breakout", ((HighestValue - HighValue1) / MarketInfo(SymbolUsed, MODE_POINT)), HighClose - 1, SearchShift - HighClose);
               HighClose = MathMax(SearchShift - MaximumBarShift, TradeCloseShift(SymbolUsed, "Short", HighValue1, SearchShift) + 1);
               LowestValue = iLow(SymbolUsed, 0,  iLowest(SymbolUsed, 0, MODE_LOW, SearchShift - HighClose, HighClose));
               FileWriter(SymbolUsed, TimeHour(iTime(SymbolUsed, 0, SearchShift)), "Counter", ((HighValue1 - LowestValue) / MarketInfo(SymbolUsed, MODE_POINT)), HighClose - 1, SearchShift - HighClose);
               }
            if(iLow(NULL, 0, SearchShift) < LowValue)
               {
               LowValue1 = LowValue;
               LowValue = iLow(NULL, 0, SearchShift);
               LowClose = MathMax(SearchShift - MaximumBarShift, TradeCloseShift(SymbolUsed, "Long", LowValue1, SearchShift) + 1);
               HighestValue = iHigh(SymbolUsed, 0, iHighest(SymbolUsed, 0, MODE_HIGH, SearchShift - LowClose, LowClose));
               FileWriter(SymbolUsed, TimeHour(iTime(SymbolUsed, 0, SearchShift)), "Counter", ((HighestValue - LowValue1) / MarketInfo(SymbolUsed, MODE_POINT)), LowClose - 1, SearchShift - LowClose);
               LowClose = MathMax(SearchShift - MaximumBarShift, TradeCloseShift(SymbolUsed, "Short", LowValue1, SearchShift) + 1);
               LowestValue = iLow(SymbolUsed, 0, iLowest(SymbolUsed, 0, MODE_LOW, SearchShift - LowClose, LowClose));
               FileWriter(SymbolUsed, TimeHour(iTime(SymbolUsed, 0, SearchShift)), "Breakout", ((LowValue1 - LowestValue) / MarketInfo(SymbolUsed, MODE_POINT)), LowClose - 1, SearchShift - LowClose);
               }
            }
         }

      //Determine the most profitable combination
      for(int OptimizeHour = 0; OptimizeHour <= 23; OptimizeHour++)
         {
         OptimizeTP(SymbolUsed, OptimizeHour);
         FileDelete(WindowExpertName()+" "+SymbolUsed+" "+OptimizeHour+".csv");
         }


      return(OptimizeBars);
      }

void OptimizeTP(string SymbolUsed, int HourUsed)
   {
   double BOTPArray[0];
   double CTTPArray[0];
   ArrayResize(BOTPArray, 0);
   ArrayResize(CTTPArray, 0);
   int Handle = FileOpen(WindowExpertName()+" "+SymbolUsed+" "+HourUsed+".csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
   if(Handle == -1) return(0);
   if(Handle > 0)
      {
      while(!FileIsEnding(Handle))
         {
         string TPMax = FileReadString(Handle);
         string CloseDistance = FileReadString(Handle);
         string CloseSpread = FileReadString(Handle);
         string FoundStyle = FileReadString(Handle);

         if(TPMax != "" && FoundStyle == "Breakout")
            {
            BOTPArray[ArrayResize(BOTPArray, ArraySize(BOTPArray) + 1) - 1] = StrToDouble(TPMax);
            //Print(StrToDouble(TPMax));
            }
         if(TPMax != "" && FoundStyle == "Counter")
            {
            CTTPArray[ArrayResize(CTTPArray, ArraySize(CTTPArray) + 1) - 1] = StrToDouble(TPMax);
            }
         OptimizationComments("Reading trade files for "+HourUsed+":00");
         }
      }
   FileClose(Handle);
   if(ArraySize(BOTPArray) != 0) ArraySort(BOTPArray);
   if(ArraySize(CTTPArray) != 0) ArraySort(CTTPArray);

   double BOHighProfit;
   double BOHighTP;
   double BOHighWinRate;
   double BOHighRiskReward;
   double BOHighSuccessScore;
   double BOArrayNum;

   for(int BOArray = 0; BOArray < ArraySize(BOTPArray); BOArray++)
      {
      //Calculate SL total and TP total for each side.

      double BOStopLossValue = StopLoss * (BOArray);
      double BOTakeProfitValue = BOTPArray[BOArray] * (ArraySize(BOTPArray) - BOArray);
      double BOProfit = BOTakeProfitValue - BOStopLossValue;
      double BOWinRate = 1.0 - ((BOArray + 1) * 1.0 / ArraySize(BOTPArray) * 1.0);
      double BORiskReward = BOTPArray[BOArray] * 1.0 / StopLoss * 1.0;
      double BOSS = BOWinRate * BORiskReward;
      //Print("Hour: ", HourUsed, " Array Number: ", BOArray, " Array Total: ", ArraySize(BOTPArray), " Array Value: ", BOTPArray[BOArray], " SL: ", BOStopLossValue, " TP: ", BOTakeProfitValue);
      int BOhandle = FileOpen(WindowExpertName()+" "+SymbolUsed+" All Permutation Settings.csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
      if(BOhandle > 0)
         {
         FileSeek(BOhandle,0,SEEK_END);
         FileWrite(BOhandle, HourUsed, BOArray, "Breakout", BOStopLossValue, BOTakeProfitValue, BOProfit, BOWinRate, BORiskReward, BOSS);
         FileFlush(BOhandle);
         FileClose(BOhandle);
         }

      if(BOWinRate >= MinimumWinRate / 100.0 && BORiskReward >= MinimumRiskReward && BOSS >= MinimumSuccessScore)
         {
         BOHighProfit = BOProfit;
         BOHighTP = BOTPArray[BOArray];
         BOArrayNum = BOArray;
         BOHighWinRate = BOWinRate * 1.0;
         BOHighRiskReward = BORiskReward;
         BOHighSuccessScore = BOSS;
         }
      OptimizationComments("Optimizing Breakout for "+HourUsed+":00");
      }

   double CTHighProfit;
   double CTHighTP;
   double CTHighWinRate;
   double CTHighRiskReward;
   double CTHighSuccessScore;
   double CTArrayNum;

   for(int CTArray = 0; CTArray < ArraySize(CTTPArray); CTArray++)
      {
      //Calculate SL total and TP total for each side.

      double CTStopLossValue = StopLoss * (CTArray);
      double CTTakeProfitValue = CTTPArray[CTArray] * (ArraySize(CTTPArray) - CTArray);
      double CTProfit = CTTakeProfitValue - CTStopLossValue;
      double CTWinRate = 1.0 - ((CTArray + 1) * 1.0 / ArraySize(CTTPArray) * 1.0);
      double CTRiskReward = CTTPArray[CTArray] * 1.0 / StopLoss * 1.0;
      double CTSS = CTWinRate * CTRiskReward;
      //Print("Hour: ", HourUsed, " Array Number: ", CTArray, " Array Total: ", ArraySize(CTTPArray), " Array Value: ", CTTPArray[CTArray], " SL: ", CTStopLossValue, " TP: ", CTTakeProfitValue);
      int CThandle = FileOpen(WindowExpertName()+" "+SymbolUsed+" All Permutation Settings.csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
      if(CThandle > 0)
         {
         FileSeek(CThandle,0,SEEK_END);
         FileWrite(CThandle, HourUsed, CTArray, "Counter", CTStopLossValue, CTTakeProfitValue, CTProfit, CTWinRate, CTRiskReward, CTSS);
         FileFlush(CThandle);
         FileClose(CThandle);
         }

      if(CTWinRate >= MinimumWinRate / 100.0 && CTRiskReward >= MinimumRiskReward && CTSS >= MinimumSuccessScore)
         {
         CTHighProfit = CTProfit;
         CTHighTP = CTTPArray[CTArray];
         CTArrayNum = CTArray;
         CTHighWinRate = CTWinRate * 1.0;
         CTHighRiskReward = CTRiskReward;
         CTHighSuccessScore = CTSS;
         }
      OptimizationComments("Optimizing Counter for "+HourUsed+":00");
      }

   double HighTP = -1;
   double HighProfit = -1;
   double HighWinRate = -1;
   double HighRiskReward = -1;
   double HighSuccessScore = -1;
   string TradeStyle = "None";
   int ArraySizes = -1;
   int ArrayNum = -1;


   if((HighestProfit && BOHighProfit > CTHighProfit) || (HighestWinRate && BOHighWinRate > CTHighWinRate) || (HighestRiskReward && BOHighRiskReward > CTHighRiskReward) || (HighestSuccessScore && BOHighSuccessScore > CTHighSuccessScore))
      {
      HighTP = BOHighTP;
      HighProfit = BOHighProfit;
      HighWinRate = BOHighWinRate * 1.0;
      HighRiskReward = BOHighRiskReward;
      HighSuccessScore = BOHighSuccessScore;
      TradeStyle = "Breakout";
      ArraySizes = ArraySize(BOTPArray);
      ArrayNum = BOArrayNum;
      }

   if((HighestProfit && CTHighProfit > BOHighProfit) || (HighestWinRate && CTHighWinRate > BOHighWinRate) || (HighestRiskReward && CTHighRiskReward > BOHighRiskReward) || (HighestSuccessScore && CTHighSuccessScore > BOHighSuccessScore))
      {
      HighTP = CTHighTP;
      HighProfit = CTHighProfit;
      HighWinRate = CTHighWinRate * 1.0;
      HighRiskReward = CTHighRiskReward;
      HighSuccessScore = CTHighSuccessScore;
      TradeStyle = "Counter";
      ArraySizes = ArraySize(CTTPArray);
      ArrayNum = CTArrayNum;
      }

   int handle = FileOpen(WindowExpertName()+" "+SymbolUsed+" Optimized Settings.csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
   if(handle > 0)
      {
      FileSeek(handle,0,SEEK_END);
      FileWrite(handle, HourUsed, HighTP, HighProfit, HighWinRate, HighRiskReward, HighSuccessScore, TradeStyle, ArraySizes, ArrayNum);
      FileFlush(handle);
      FileClose(handle);
      }

   int Mainhandle = FileOpen(WindowExpertName()+" "+SymbolUsed+" All Settings.csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
   if(Mainhandle > 0)
      {
      FileSeek(Mainhandle,0,SEEK_END);
      FileWrite(Mainhandle, HourUsed, BOHighTP, BOHighProfit, BOHighWinRate, BOHighRiskReward, BOHighSuccessScore, "Breakout", ArraySize(BOTPArray), BOArrayNum);
      FileFlush(Mainhandle);
      FileClose(Mainhandle);
      }
   Mainhandle = FileOpen(WindowExpertName()+" "+SymbolUsed+" All Settings.csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
   if(Mainhandle > 0)
      {
      FileSeek(Mainhandle,0,SEEK_END);
      FileWrite(Mainhandle, HourUsed, CTHighTP, CTHighProfit, CTHighWinRate, CTHighRiskReward, CTHighSuccessScore, "Counter", ArraySize(CTTPArray), CTArrayNum);
      FileFlush(Mainhandle);
      FileClose(Mainhandle);
      }
   }

string FileWriter(string SymbolUsed, int TradeHour, string TradeStyle, int TPMax, int CloseDistance, int CloseSpread)
   {
   int handle = FileOpen(WindowExpertName()+" "+SymbolUsed+" "+TradeHour+".csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
   if(handle > 0)
      {
      FileSeek(handle,0,SEEK_END);
      FileWrite(handle, TPMax, CloseDistance, CloseSpread, TradeStyle);
      FileFlush(handle);
      FileClose(handle);
      }
   handle = FileOpen(WindowExpertName()+" "+SymbolUsed+" Master Copy.csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
   if(handle > 0)
      {
      FileSeek(handle,0,SEEK_END);
      FileWrite(handle, TradeHour, TradeStyle, TPMax, CloseDistance, CloseSpread);
      FileFlush(handle);
      FileClose(handle);
      }
   }

int TradeCloseShift(string SymbolUsed, string Direction, double EntryPrice, int Shift)
   {
   double TargetPrice = 0;

   if(Direction == "Long")
      {
      if(!ReverseTrades) TargetPrice = EntryPrice - (StopLoss * MarketInfo(SymbolUsed, MODE_POINT));
      if(ReverseTrades)  TargetPrice = EntryPrice - (TakeProfit * MarketInfo(SymbolUsed, MODE_POINT));
      }
   if(Direction == "Short")
      {
      if(!ReverseTrades) TargetPrice = EntryPrice + (StopLoss * MarketInfo(SymbolUsed, MODE_POINT));
      if(ReverseTrades)  TargetPrice = EntryPrice + (TakeProfit * MarketInfo(SymbolUsed, MODE_POINT));
      }
   for (int FShift = Shift; FShift > 0; FShift--)
      {
      if(Direction == "Long")
         {
         if(iHigh(SymbolUsed, 0, FShift) >= TargetPrice && iLow(SymbolUsed, 0, FShift) <= TargetPrice)
            {
            return(FShift);
            }
         }
      if(Direction == "Short")
         {
         if(iHigh(SymbolUsed, 0, FShift) >= TargetPrice && iLow(SymbolUsed, 0, FShift) <= TargetPrice)
            {
            return(FShift);
            }
         }
      }
   return(0);
   }


void DeleteFile(string FileName)
   {
   int DeleteHandle = FileOpen(FileName, FILE_CSV|FILE_READ, ';');

   if(DeleteHandle > 0)
      {
      FileClose(DeleteHandle);
      FileDelete(FileName);
      }
   return(0);
   }


void OptimizationComments(string OptimizationStatus)
   {
   //static string Process = ".................Optimizing.................Original EA Concept by Ronald Raygun (TM)......Contact Ronald Raygun on www.ForexFactory.com for more details.";

  static string Process = "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR.....              ";
 static string Process1 = "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR.....              ";
 static string Process2 = "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR.....              ";
 static string Process3 = "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR.....              ";
 static string Process4 = "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR.....              ";
 static string Process5 = "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR.....              ";
 static string Process6 = "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR.....              ";
 static string Process7 = "RRRRRR               RRRRRRR             RRRRRRRRRRRRR.....";
 static string Process8 = "RRRRRR   RRRRR    RRRRRR  RRRRRR   RRRRRRRRRRR.....        ";
 static string Process9 = "RRRRRR   RRRRRR  RRRRRR  RRRRRRR   RRRRRRRRRR.....         ";
static string Process10 = "RRRRRR   RRRRRR  RRRRRR  RRRRRR   RRRRRRRRRRR.....         ";
static string Process11 = "RRRRRR   RRRRR  RRRRRRR  RRRRR   RRRRRRRRRRRR.....         ";
static string Process12 = "RRRRRR             RRRRRRRR           RRRRRRRRRRRRRR.....  ";
static string Process13 = "RRRRRR   RRRRR  RRRRRRR  RRRRR   RRRRRRRRRRRR.....         ";
static string Process14 = "RRRRRR   RRRRR    RRRRRR  RRRRRR   RRRRRRRRRRR.....        ";
static string Process15 = "RRRRRR   RRRRRR    RRRRR  RRRRRR   RRRRRRRRRRR.....        ";
static string Process16 = "RRRRRR   RRRRRR    RRRRR  RRRRRRR     RRRRRRRRR.....       ";
static string Process17 = "RRRRRR   RRRRRRR    RRRR  RRRRRRR     RRRRRRRRR.....       ";
static string Process18 = "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR.....              ";
static string Process19 = "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR.....              ";
static string Process20 = "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR.....              ";
static string Process21 = "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR.....              ";
static string Process22 = "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR.....              ";
static string Process23 = "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR.....              ";
static string Process24 = "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR.....              ";

   if(AnimateOptimization)
      {
      Process = ShiftString(Process);
      Process1 = ShiftString(Process1);
      Process2 = ShiftString(Process2);
      Process3 = ShiftString(Process3);
      Process4 = ShiftString(Process4);
      Process5 = ShiftString(Process5);
      Process6 = ShiftString(Process6);
      Process7 = ShiftString(Process7);
      Process8 = ShiftString(Process8);
      Process9 = ShiftString(Process9);
      Process10 = ShiftString(Process10);
      Process11 = ShiftString(Process11);
      Process12 = ShiftString(Process12);
      Process13 = ShiftString(Process13);
      Process14 = ShiftString(Process14);
      Process15 = ShiftString(Process15);
      Process16 = ShiftString(Process16);
      Process17 = ShiftString(Process17);
      Process18 = ShiftString(Process18);
      Process19 = ShiftString(Process19);
      Process20 = ShiftString(Process20);
      Process21 = ShiftString(Process21);
      Process22 = ShiftString(Process22);
      Process23 = ShiftString(Process23);
      Process24 = ShiftString(Process24);
      }

   Comment(Process+ "\n",
           Process1+ "\n",
           Process2+ "\n",
           Process3+ "\n",
           Process4+ "\n",
           Process5+ "\n",
           Process6+ "\n",
           Process7+ "\n",
           Process8+ "\n",
           Process9+ "\n",
           Process10+ "\n",
           Process11+ "\n",
           Process12+ "\n",
           Process13+ "\n",
           Process14+ "\n",
           Process15+ "\n",
           Process16+ "\n",
           Process17+ "\n",
           Process18+ "\n",
           Process19+ "\n",
           Process20+ "\n",
           Process21+ "\n",
           Process22+ "\n",
           Process23+ "\n",
           Process24+ "\n",
           OptimizationStatus);
   //Sleep(100);
   return(0);
   }

string ShiftString(string StringShift)
   {
   string Process1 = StringSubstr(StringShift, 0, 1);
   string Process2 = StringSubstr(StringShift, 1, StringLen(StringShift) - 1);
   StringShift = Process2 + Process1;
   return(StringShift);
   }
