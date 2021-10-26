/**
 * Self-Optimizing HiLo Trader
 *
 * Rewritten version of the concept published by FF user Ronald Raygun. Work-in-progress, don't use for real trading!
 *
 * Changes:
 *  - removed obsolete parts: activation, tick db, ECN distinction, signaling, animation, multi-symbol processing
 *  - restored regular start() function
 *  - simplified and slimmed down everything
 *  - converted to and integrated rosasurfer framework
 *
 * @link    https://www.forexfactory.com/thread/post/3876758#post3876758                  [@rraygun: Old Dog with New Tricks]
 * @source  https://www.forexfactory.com/thread/post/3922031#post3922031                    [@stevegee58: last fixed version]
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_BUFFERED_LOG, INIT_NO_EXTERNAL_REPORTING};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Remark1               = "== Main Settings ==";
extern int    MagicNumber           = 0;
extern bool   EachTickMode          = true;
extern int    MaxSimultaneousTrades = 10;
extern double Lots                  = 0.1;
extern bool   MoneyManagement       = false;
extern int    Risk                  = 0;
extern int    Slippage              = 5;
extern bool   UseStopLoss           = true;
extern int    StopLoss              = 200;
extern bool   UseTakeProfit         = true;
extern int    TakeProfit            = 200;
extern bool   UseTrailingStop       = false;
extern int    TrailingStop          = 30;
extern bool   MoveStopOnce          = false;
extern int    MoveStopWhenPrice     = 50;
extern int    MoveStopTo            = 1;

extern string Remark2               = "== Breakout Settings ==";
extern int    BarsToOptimize        = 0;
extern int    InitialRange          = 60;
extern int    MaximumBarShift       = 1440;
extern double MinimumWinRate        = 50;
extern double MinimumRiskReward     = 0;
extern double MinimumSuccessScore   = 0;
extern int    MinimumSampleSize     = 10;
extern bool   ReverseTrades         = false;

extern string Remark3               = "== Optimize Based On ==";
extern bool   HighestProfit         = false;
extern bool   HighestWinRate        = false;
extern bool   HighestRiskReward     = false;
extern bool   HighestSuccessScore   = true;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define SIGNAL_NONE        0
#define SIGNAL_BUY         1
#define SIGNAL_SELL        2
#define SIGNAL_CLOSEBUY    3
#define SIGNAL_CLOSESELL   4

int  TradeBar;
int  TradesThisBar;
int  OpenBarCount;
int  CloseBarCount;
int  Current;
bool TickCheck = false;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   OpenBarCount  = Bars;
   CloseBarCount = Bars;

   if (EachTickMode) Current = 0;
   else              Current = 1;

   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   Comment(MainFunction());
   return(catch("onTick(1)"));
}


/**
 *
 */
string MainFunction() {
   double StopLossLevel, TakeProfitLevel, PotentialStopLoss, BEven, TrailStop;

   if (EachTickMode && Bars!=CloseBarCount) TickCheck = false;
   int Total = OrdersTotal();
   int Order = SIGNAL_NONE;

   // limit trades per bar
   if (TradeBar != Bars) {
      TradeBar      = Bars;
      TradesThisBar = 0;
   }

   // money management
   if (MoneyManagement) {
      if (Risk < 1 || Risk > 100) {
         return(_EMPTY_STR(catch("MainFunction(1)  invalid risk value: "+ Risk, ERR_INVALID_INPUT_PARAMETER)));
      }
      else {
         Lots = MathFloor((AccountFreeMargin() * AccountLeverage() * Risk*Point*PipPoints*100) / (Ask * MarketInfo(Symbol(), MODE_LOTSIZE) * MarketInfo(Symbol(), MODE_MINLOT))) * MarketInfo(Symbol(), MODE_MINLOT);
      }
   }

   // optimization
   static int lastOptimizationBars, LastCalcDay;
   static string sLastOptimizationTime;

   if (TimeDayOfYear(Tick.time) != LastCalcDay) {
      lastOptimizationBars  = SelfOptimize(); if (!lastOptimizationBars) return("");
      LastCalcDay           = TimeDayOfYear(Tick.time);
      sLastOptimizationTime = TimeToStr(Tick.time, TIME_FULL);
   }

   // determine day's start
   int DayStart   = iBarShift(NULL, NULL, StrToTime("00:00"), false);
   int RangeStart = DayStart - InitialRange;

   // determine current HiLo
   int HighShift = iHighest(NULL, NULL, MODE_HIGH, RangeStart-1, 1);
   int LowShift  =  iLowest(NULL, NULL, MODE_LOW,  RangeStart-1, 1);

   double HighPrice = iHigh(NULL, NULL, HighShift);
   double LowPrice  =  iLow(NULL, NULL, LowShift);

   // read back optimization values
   static int    CurrentHour, CurrentHighTP, CurrentHighProfit, CurrentArraySizes, CurrentArrayNum;
   static double CurrentWinRate, CurrentRiskReward, CurrentSuccessScore;
   static string CurrentTradeStyle;

   if (CurrentHour != TimeHour(Tick.time)) {
      int hFile = FileOpen(WindowExpertName() +" "+ Symbol() +" optimized settings.csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
      if (hFile < 0) return(_EMPTY_STR(catch("MainFunction(2)->FileOpen()")));

      if (FileSize(hFile) > 0) {
         while (!FileIsEnding(hFile)) {
            int    HourUsed         = StrToInteger(FileReadString(hFile));
            int    HighTP           = StrToInteger(FileReadString(hFile));
            int    HighProfit       = StrToInteger(FileReadString(hFile));
            double HighWinRate      = StrToDouble(FileReadString(hFile));
            double HighRiskReward   = StrToDouble(FileReadString(hFile));
            double HighSuccessScore = StrToDouble(FileReadString(hFile));
            string TradeStyle       = FileReadString(hFile);
            int    ArraySizes       = StrToInteger(FileReadString(hFile));
            int    ArrayNum         = StrToInteger(FileReadString(hFile));

            if (HourUsed == TimeHour(Tick.time)) {
               CurrentHour         = HourUsed;
               CurrentHighTP       = HighTP;
               CurrentHighProfit   = HighProfit;
               CurrentWinRate      = HighWinRate;
               CurrentRiskReward   = HighRiskReward;
               CurrentSuccessScore = HighSuccessScore;
               CurrentTradeStyle   = TradeStyle;
               CurrentArraySizes   = ArraySizes;
               CurrentArrayNum     = ArrayNum;
               break;
            }
         }
      }
      FileClose(hFile);
   }

   if (!ReverseTrades) TakeProfit = CurrentHighTP;
   else                StopLoss   = CurrentHighTP;

   // count open positions
   int TradeCount = 0;
   for (int i=OrdersTotal(); i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol() && OrderType()<=OP_SELL) TradeCount++;
   }

   string TradeTrigger1 = "None";
   if ((TradeCount < MaxSimultaneousTrades || !MaxSimultaneousTrades) && CurrentArraySizes >= MinimumSampleSize && DayStart > InitialRange && CurrentTradeStyle=="Breakout" && Close[Current] > HighPrice) TradeTrigger1 = "Open Long";
   if ((TradeCount < MaxSimultaneousTrades || !MaxSimultaneousTrades) && CurrentArraySizes >= MinimumSampleSize && DayStart > InitialRange && CurrentTradeStyle=="Counter"  && Close[Current] > HighPrice) TradeTrigger1 = "Open Short";
   if ((TradeCount < MaxSimultaneousTrades || !MaxSimultaneousTrades) && CurrentArraySizes >= MinimumSampleSize && DayStart > InitialRange && CurrentTradeStyle=="Breakout" && Close[Current] < LowPrice)  TradeTrigger1 = "Open Short";
   if ((TradeCount < MaxSimultaneousTrades || !MaxSimultaneousTrades) && CurrentArraySizes >= MinimumSampleSize && DayStart > InitialRange && CurrentTradeStyle=="Counter"  && Close[Current] < LowPrice)  TradeTrigger1 = "Open Long";

   string TradeTrigger = TradeTrigger1;
   if (ReverseTrades && TradeTrigger1=="Open Long")  TradeTrigger = "Open Short";
   if (ReverseTrades && TradeTrigger1=="Open Short") TradeTrigger = "Open Long";

   string CommentString = StringConcatenate("Last optimization: ",     sLastOptimizationTime,                                     NL,
                                            "Bars used: ",             lastOptimizationBars,                                      NL,
                                            "Total bars: ",            Bars,                                                      NL,
                                            "Current hour: ",          CurrentHour,                                               NL,
                                            "Current TP: ",            CurrentHighTP,                                             NL,
                                            "Current win rate: ",      CurrentWinRate * 100.0, "% (", MinimumWinRate, ")",        NL,
                                            "Current risk reward: ",   CurrentRiskReward, " (", MinimumRiskReward, ")",           NL,
                                            "Current success score: ", CurrentSuccessScore * 100, " (", MinimumSuccessScore, ")", NL,
                                            "Array win: ",             CurrentArraySizes - CurrentArrayNum - 1,                   NL,
                                            "Array lose: ",            CurrentArrayNum + 1,                                       NL,
                                            "Total array: ",           CurrentArraySizes,                                         NL,
                                            "Total open Trades: ",     TradeCount,                                                NL,
                                            "Trade style: ",           CurrentTradeStyle,                                         NL,
                                            "Trade trigger: ",         TradeTrigger);
   bool IsTrade = false;

   // close open positions
   for (i=0; i < Total; i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);

      if (OrderType()<=OP_SELL &&  OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
         IsTrade = true;

         if (OrderType() == OP_BUY) {
            if (TradeTrigger == "Open Short") Order = SIGNAL_CLOSEBUY;

            if (Order==SIGNAL_CLOSEBUY && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars!=CloseBarCount)))) {
               OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, MediumSeaGreen);
               if (!EachTickMode) CloseBarCount = Bars;
               IsTrade = false;
               continue;
            }

            PotentialStopLoss = OrderStopLoss();
            BEven             = CalcBreakEven(MoveStopOnce, OrderTicket(), MoveStopTo, MoveStopWhenPrice);
            TrailStop         = CalcTrailingStop(UseTrailingStop, OrderTicket(), TrailingStop);

            if (BEven     > PotentialStopLoss && BEven)     PotentialStopLoss = BEven;
            if (TrailStop > PotentialStopLoss && TrailStop) PotentialStopLoss = TrailStop;

            if (PotentialStopLoss != OrderStopLoss()) OrderModify(OrderTicket(), OrderOpenPrice(), PotentialStopLoss, OrderTakeProfit(), 0, MediumSeaGreen);

         }
         else {
            if (TradeTrigger == "Open Long") Order = SIGNAL_CLOSESELL;

            if (Order==SIGNAL_CLOSESELL && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars!=CloseBarCount)))) {
               OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, DarkOrange);
               if (!EachTickMode) CloseBarCount = Bars;
               IsTrade = false;
               continue;
            }

            PotentialStopLoss = OrderStopLoss();
            BEven             = CalcBreakEven(MoveStopOnce, OrderTicket(), MoveStopTo, MoveStopWhenPrice);
            TrailStop         = CalcTrailingStop(UseTrailingStop, OrderTicket(), TrailingStop);

            if ((BEven     < PotentialStopLoss && BEven)     || (!PotentialStopLoss)) PotentialStopLoss = BEven;
            if ((TrailStop < PotentialStopLoss && TrailStop) || (!PotentialStopLoss)) PotentialStopLoss = TrailStop;

            if (PotentialStopLoss!=OrderStopLoss() || !OrderStopLoss()) OrderModify(OrderTicket(), OrderOpenPrice(), PotentialStopLoss, OrderTakeProfit(), 0, DarkOrange);
         }
      }
   }

   // open new positions
   if (TradeTrigger == "Open Long")  Order = SIGNAL_BUY;
   if (TradeTrigger == "Open Short") Order = SIGNAL_SELL;
   IsTrade = false;

   if (Order==SIGNAL_BUY && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars!=OpenBarCount)))) {
      if (!IsTrade && TradesThisBar < 1) {
         if (UseStopLoss)   StopLossLevel   = Ask - StopLoss*Point;
         else               StopLossLevel   = 0;
         if (UseTakeProfit) TakeProfitLevel = Ask + TakeProfit*Point;
         else               TakeProfitLevel = 0;

         OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, StopLossLevel, TakeProfitLevel, "HiLo long", MagicNumber, 0, DodgerBlue);
         TradesThisBar++;

         if (EachTickMode) TickCheck = true;
         else              OpenBarCount = Bars;
         return(_string(CommentString, catch("MainFunction(3)")));
      }
   }

   if (Order==SIGNAL_SELL && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars!=OpenBarCount)))) {
      if (!IsTrade && TradesThisBar < 1) {
         if (UseStopLoss)   StopLossLevel   = Bid + StopLoss*Point;
         else               StopLossLevel   = 0;
         if (UseTakeProfit) TakeProfitLevel = Bid - TakeProfit*Point;
         else               TakeProfitLevel = 0;

         OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, StopLossLevel, TakeProfitLevel, "HiLo short", MagicNumber, 0, DeepPink);
         TradesThisBar++;

         if (EachTickMode) TickCheck = true;
         else              OpenBarCount = Bars;
         return(_string(CommentString, catch("MainFunction(4)")));
      }
   }

   if (!EachTickMode) CloseBarCount = Bars;
   return(_string(CommentString, catch("MainFunction(5)")));
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
 * @return int
 */
int SelfOptimize() {
   DeleteFile(WindowExpertName() +" "+ Symbol() +" stats all hours.csv");
   DeleteFile(WindowExpertName() +" "+ Symbol() +" optimized settings.csv");
   DeleteFile(WindowExpertName() +" "+ Symbol() +" all settings.csv");
   DeleteFile(WindowExpertName() +" "+ Symbol() +" all permutations.csv");

   int OptimizeBars = BarsToOptimize;
   if (!OptimizeBars) OptimizeBars = iBars(NULL, NULL);
   if (OptimizeBars > iBars(NULL, NULL)) {
      return(!catch("SelfOptimize(1)  Not enough bars to optimize for "+ Symbol(), ERR_RUNTIME_ERROR));
   }

   int HighShift, LowShift, HighClose, LowClose;
   double HighValue, LowValue, HighValue1, LowValue1, HighestValue, LowestValue;

   int FBarStart     = OptimizeBars;
   int DayStartShift = FBarStart;
   int RangeEndShift = FBarStart;

   for (int SearchShift=DayStartShift; SearchShift > 1; SearchShift--) {
      // determine if the bar is the daily start
      if (TimeDayOfYear(Time[SearchShift]) != TimeDayOfYear(Time[SearchShift+1])) {
         DayStartShift = SearchShift;
      }

      // find the end of the range and establish initial high and low
      if (DayStartShift-SearchShift == InitialRange) {
         RangeEndShift = SearchShift;
         HighShift = iHighest(NULL, NULL, MODE_HIGH, DayStartShift-RangeEndShift, RangeEndShift);
         HighValue =    iHigh(NULL, NULL, HighShift);
         LowShift  =  iLowest(NULL, NULL, MODE_LOW,  DayStartShift-RangeEndShift, RangeEndShift);
         LowValue  =     iLow(NULL, NULL, LowShift);
      }

      // determine subsequent high and low
      if (DayStartShift > RangeEndShift) {
         if (iHigh(NULL, NULL, SearchShift) > HighValue) {
            HighValue1   = HighValue;
            HighValue    = iHigh(NULL, NULL, SearchShift);
            HighClose    = MathMax(SearchShift-MaximumBarShift, TradeCloseShift("Long", HighValue1, SearchShift) + 1);
            HighestValue = iHigh(NULL, NULL, iHighest(NULL, NULL, MODE_HIGH, SearchShift-HighClose, HighClose));
            WriteHourlyStats(TimeHour(iTime(NULL, NULL, SearchShift)), "Breakout", ((HighestValue-HighValue1) / MarketInfo(Symbol(), MODE_POINT)));

            HighClose   = MathMax(SearchShift-MaximumBarShift, TradeCloseShift("Short", HighValue1, SearchShift) + 1);
            LowestValue = iLow(NULL, NULL,  iLowest(NULL, NULL, MODE_LOW, SearchShift-HighClose, HighClose));
            WriteHourlyStats(TimeHour(iTime(NULL, NULL, SearchShift)), "Counter", ((HighValue1-LowestValue) / MarketInfo(Symbol(), MODE_POINT)));
         }
         if (iLow(NULL, NULL, SearchShift) < LowValue) {
            LowValue1    = LowValue;
            LowValue     = iLow(NULL, NULL, SearchShift);
            LowClose     = MathMax(SearchShift - MaximumBarShift, TradeCloseShift("Long", LowValue1, SearchShift) + 1);
            HighestValue = iHigh(NULL, NULL, iHighest(NULL, NULL, MODE_HIGH, SearchShift-LowClose, LowClose));
            WriteHourlyStats(TimeHour(iTime(NULL, NULL, SearchShift)), "Counter", ((HighestValue-LowValue1) / MarketInfo(Symbol(), MODE_POINT)));

            LowClose    = MathMax(SearchShift-MaximumBarShift, TradeCloseShift("Short", LowValue1, SearchShift) + 1);
            LowestValue = iLow(NULL, NULL, iLowest(NULL, NULL, MODE_LOW, SearchShift-LowClose, LowClose));
            WriteHourlyStats(TimeHour(iTime(NULL, NULL, SearchShift)), "Breakout", ((LowValue1-LowestValue) / MarketInfo(Symbol(), MODE_POINT)));
         }
      }
   }

   // determine the most profitable combination
   for (int OptimizeHour=0; OptimizeHour <= 23; OptimizeHour++) {
      if (!OptimizeTakeProfit(OptimizeHour)) return(NULL);
   }
   return(ifInt(catch("SelfOptimize(2)"), 0, OptimizeBars));
}


/**
 *
 * @return bool - success status
 */
bool OptimizeTakeProfit(int HourUsed) {
   double BOTPArray[]; ArrayResize(BOTPArray, 0);
   double CTTPArray[]; ArrayResize(CTTPArray, 0);

   // read hourly stats
   string filename = WindowExpertName() +" "+ Symbol() +" stats "+ StrRight("0"+ HourUsed, 2) +".csv";

   if (MQL.IsFile(filename)) {
      int hFile = FileOpen(filename, FILE_CSV|FILE_READ, ';'); if (hFile < 0) return(!catch("OptimizeTakeProfit(1)->FileOpen(\""+ filename +"\")"));
      debug("OptimizeTakeProfit(2)  reading \""+ filename +"\"");

      while (!FileIsEnding(hFile)) {
         string TPMax      = FileReadString(hFile); if (!IsValidHourlyStatsField(hFile, filename, 1, TPMax))         break;
         string FoundStyle = FileReadString(hFile); if (!IsValidHourlyStatsField(hFile, filename, 2, FoundStyle))    break;

         if      (FoundStyle == "Breakout") BOTPArray[ArrayResize(BOTPArray, ArraySize(BOTPArray)+1)-1] = StrToDouble(TPMax);
         else if (FoundStyle == "Counter")  CTTPArray[ArrayResize(CTTPArray, ArraySize(CTTPArray)+1)-1] = StrToDouble(TPMax);
         else                               return(!catch("OptimizeTakeProfit(3)  invalid file format: FoundStyle=\""+ FoundStyle +"\"", ERR_INVALID_FILE_FORMAT));
      }
      if (IsLastError()) return(false);
      FileClose(hFile);
      FileDelete(filename);

      if (ArraySize(BOTPArray) != 0) ArraySort(BOTPArray);
      if (ArraySize(CTTPArray) != 0) ArraySort(CTTPArray);
   }

   // breakout trades: calculate SL total and TP total for each side
   double BOHighProfit, BOHighTP, BOHighWinRate, BOHighRiskReward, BOHighSuccessScore, BOArrayNum;

   for (int BOArray=0; BOArray < ArraySize(BOTPArray); BOArray++) {
      double BOStopLossValue   = StopLoss * BOArray;
      double BOTakeProfitValue = BOTPArray[BOArray] * (ArraySize(BOTPArray)-BOArray);
      double BOProfit          = BOTakeProfitValue - BOStopLossValue;
      double BOWinRate         = 1 - ((BOArray+1) * 1.0 / ArraySize(BOTPArray) * 1.0);
      double BORiskReward      = BOTPArray[BOArray] * 1.0 / StopLoss * 1.0;
      double BOSS              = BOWinRate * BORiskReward;

      int BOhandle = FileOpen(WindowExpertName() +" "+ Symbol() +" all permutations.csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
      FileSeek(BOhandle, 0, SEEK_END);
      FileWrite(BOhandle, HourUsed, BOArray, "Breakout", BOStopLossValue, BOTakeProfitValue, BOProfit, BOWinRate, BORiskReward, BOSS);
      FileClose(BOhandle);

      if (BOWinRate >= MinimumWinRate/100 && BORiskReward >= MinimumRiskReward && BOSS >= MinimumSuccessScore) {
         BOHighProfit       = BOProfit;
         BOHighTP           = BOTPArray[BOArray];
         BOArrayNum         = BOArray;
         BOHighWinRate      = BOWinRate * 1.0;
         BOHighRiskReward   = BORiskReward;
         BOHighSuccessScore = BOSS;
      }
   }

   // counter trades: calculate SL total and TP total for each side.
   double CTHighProfit, CTHighTP, CTHighWinRate, CTHighRiskReward, CTHighSuccessScore, CTArrayNum;

   for (int CTArray=0; CTArray < ArraySize(CTTPArray); CTArray++) {
      double CTStopLossValue   = StopLoss * (CTArray);
      double CTTakeProfitValue = CTTPArray[CTArray] * (ArraySize(CTTPArray)-CTArray);
      double CTProfit          = CTTakeProfitValue - CTStopLossValue;
      double CTWinRate         = 1 - ((CTArray+1) * 1.0 / ArraySize(CTTPArray) * 1.0);
      double CTRiskReward      = CTTPArray[CTArray] * 1.0 / StopLoss * 1.0;
      double CTSS              = CTWinRate * CTRiskReward;

      int CThandle = FileOpen(WindowExpertName() +" "+ Symbol() +" all permutations.csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
      FileSeek(CThandle, 0, SEEK_END);
      FileWrite(CThandle, HourUsed, CTArray, "Counter", CTStopLossValue, CTTakeProfitValue, CTProfit, CTWinRate, CTRiskReward, CTSS);
      FileClose(CThandle);

      if (CTWinRate >= MinimumWinRate/100 && CTRiskReward >= MinimumRiskReward && CTSS >= MinimumSuccessScore) {
         CTHighProfit       = CTProfit;
         CTHighTP           = CTTPArray[CTArray];
         CTArrayNum         = CTArray;
         CTHighWinRate      = CTWinRate * 1.0;
         CTHighRiskReward   = CTRiskReward;
         CTHighSuccessScore = CTSS;
      }
   }

   double HighTP=-1, HighProfit=-1, HighWinRate=-1, HighRiskReward=-1, HighSuccessScore=-1;
   int    ArraySizes=-1, ArrayNum=-1;
   string TradeStyle = "None";

   if ((HighestProfit && BOHighProfit > CTHighProfit) || (HighestWinRate && BOHighWinRate > CTHighWinRate) || (HighestRiskReward && BOHighRiskReward > CTHighRiskReward) || (HighestSuccessScore && BOHighSuccessScore > CTHighSuccessScore)) {
      HighTP           = BOHighTP;
      HighProfit       = BOHighProfit;
      HighWinRate      = BOHighWinRate * 1.0;
      HighRiskReward   = BOHighRiskReward;
      HighSuccessScore = BOHighSuccessScore;
      TradeStyle       = "Breakout";
      ArraySizes       = ArraySize(BOTPArray);
      ArrayNum         = BOArrayNum;
   }

   if ((HighestProfit && CTHighProfit > BOHighProfit) || (HighestWinRate && CTHighWinRate > BOHighWinRate) || (HighestRiskReward && CTHighRiskReward > BOHighRiskReward) || (HighestSuccessScore && CTHighSuccessScore > BOHighSuccessScore)) {
      HighTP           = CTHighTP;
      HighProfit       = CTHighProfit;
      HighWinRate      = CTHighWinRate * 1.0;
      HighRiskReward   = CTHighRiskReward;
      HighSuccessScore = CTHighSuccessScore;
      TradeStyle       = "Counter";
      ArraySizes       = ArraySize(CTTPArray);
      ArrayNum         = CTArrayNum;
   }

   int handle = FileOpen(WindowExpertName() +" "+ Symbol() +" optimized settings.csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle, HourUsed, HighTP, HighProfit, HighWinRate, HighRiskReward, HighSuccessScore, TradeStyle, ArraySizes, ArrayNum);
   FileClose(handle);

   int Mainhandle = FileOpen(WindowExpertName() +" "+ Symbol() +" all settings.csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
   FileSeek(Mainhandle, 0, SEEK_END);
   FileWrite(Mainhandle, HourUsed, BOHighTP, BOHighProfit, BOHighWinRate, BOHighRiskReward, BOHighSuccessScore, "Breakout", ArraySize(BOTPArray), BOArrayNum);
   FileWrite(Mainhandle, HourUsed, CTHighTP, CTHighProfit, CTHighWinRate, CTHighRiskReward, CTHighSuccessScore, "Counter",  ArraySize(CTTPArray), CTArrayNum);
   FileClose(Mainhandle);

   return(!catch("OptimizeTakeProfit(6)"));
}


/**
 *
 */
string WriteHourlyStats(int TradeHour, string TradeStyle, int TPMax) {
   int handle = FileOpen(WindowExpertName() +" "+ Symbol() +" stats "+ StrRight("0"+ TradeHour, 2) +".csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle, TPMax, TradeStyle);
   FileClose(handle);

   handle = FileOpen(WindowExpertName() +" "+ Symbol() +" stats all hours.csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle, TradeHour, TradeStyle, TPMax);
   FileClose(handle);
}


/**
 *
 */
int TradeCloseShift(string Direction, double EntryPrice, int Shift) {
   double TargetPrice = 0;

   if (Direction == "Long") {
      if (!ReverseTrades) TargetPrice = EntryPrice - StopLoss   * MarketInfo(Symbol(), MODE_POINT);
      else                TargetPrice = EntryPrice - TakeProfit * MarketInfo(Symbol(), MODE_POINT);
   }
   if (Direction == "Short") {
      if (!ReverseTrades) TargetPrice = EntryPrice + StopLoss   * MarketInfo(Symbol(), MODE_POINT);
      else                TargetPrice = EntryPrice + TakeProfit * MarketInfo(Symbol(), MODE_POINT);
   }

   for (int FShift=Shift; FShift > 0; FShift--) {
      if (Direction == "Long") {
         if (iHigh(NULL, NULL, FShift) >= TargetPrice && iLow(NULL, NULL, FShift) <= TargetPrice) {
            return(FShift);
         }
      }
      if (Direction == "Short") {
         if (iHigh(NULL, NULL, FShift) >= TargetPrice && iLow(NULL, NULL, FShift) <= TargetPrice) {
            return(FShift);
         }
      }
   }
   return(0);
}


/**
 * @return bool - success status
 */
bool DeleteFile(string name) {
   if (MQL.IsFile(name)) {
      FileDelete(name);
      return(!catch("DeleteFile(1)"));
   }
   return(false);
}


/**
 * @return bool - whether the read value is valid in the current context
 */
bool IsValidHourlyStatsField(int hFile, string filename, int fieldNo, string value) {
   if (FileIsEnding(hFile)) {
      int error = GetLastError();
      if (error && error!=ERR_END_OF_FILE) return(!catch("IsValidHourlyStatsField(1)", error));
   }

   switch (fieldNo) {
      case 1:
         if (FileIsEnding(hFile)) {
            if (value != "") catch("IsValidHourlyStatsField(2)  invalid line format in \""+ filename +"\": EOF but TPMax not empty (\""+ value +"\")", ERR_INVALID_FILE_FORMAT);
            return(false);
         }
         else if (FileIsLineEnding(hFile)) {
            return(!catch("IsValidHourlyStatsField(3)  invalid line format in \""+ filename +"\": EOL after TPMax (\""+ value +"\")", ERR_INVALID_FILE_FORMAT));
         }
         break;

      case 2:
         if (FileIsEnding(hFile)) {
            return(!catch("IsValidHourlyStatsField(4)  invalid line format in \""+ filename +"\": EOF but no EOL after FoundStyle (\""+ value +"\")", ERR_INVALID_FILE_FORMAT));
         }
         else if (!FileIsLineEnding(hFile)) {
            return(!catch("IsValidHourlyStatsField(5)  invalid line format in \""+ filename +"\": no EOL after FoundStyle (\""+ value +"\")", ERR_INVALID_FILE_FORMAT));
         }
         break;

      default:
         return(!catch("IsValidHourlyStatsField(6)  invalid parameter fieldNo: "+ fieldNo, ERR_INVALID_PARAMETER));
   }
   return(true);
}
