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
 *  - dropped obsolete input param MoveStopTo
 *  - dropped unused optimization files "All Settings", "All Permutation Settings" and "Master Copy"
 *  - dropped unused hourly optimization file fields "CloseDistance" and "CloseSpread"
 *
 * @link    https://www.forexfactory.com/thread/post/3876758#post3876758                  [@rraygun: Old Dog with New Tricks]
 * @source  https://www.forexfactory.com/thread/post/3922031#post3922031                    [@stevegee58: last fixed version]
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE, INIT_BUFFERED_LOG, INIT_NO_EXTERNAL_REPORTING};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___1___________________________ = "=== Order management ===";
extern double Lots                            = 0.1;        // fix lot size to use if MoneyManagement=FALSE
extern bool   MoneyManagement                 = false;      // TRUE: dynamic lot size using the specified Risk
extern int    Risk                            = 0;          // percent of available margin to use for each position
extern bool   UseTakeProfit                   = true;
extern int    TakeProfit                      = 200;        // takeprofit in point (optimized if ReverseTrades=FALSE)
extern bool   UseStopLoss                     = true;
extern int    StopLoss                        = 200;        // stoploss in point (optimized if ReverseTrades=TRUE)
extern bool   UseTrailingStop                 = false;
extern int    TrailingStop                    = 30;         // trailing stop in point (fix)
extern bool   MoveStopToBreakeven             = false;
extern int    MoveStopToBreakevenWhen         = 50;         // min. profit distance in point to move the stop to breakeven
extern int    MagicNumber                     = 0;
extern int    Slippage                        = 5;          // max. accepted order slippage in point

extern string ___2___________________________ = "=== Order entry conditions ===";
extern bool   EachTickMode                    = true;       // FALSE: open positions only on BarOpen
extern int    MaxSimultaneousTrades           = 10;         // max. number of all open positions at any time
extern bool   ReverseTrades                   = false;      // reverse trades and switch takeprofit/stoploss (allows to separately optimize TP and SL)

extern string ___3___________________________ = "=== Breakout configuration ===";
extern int    InitialRange                    = 60;         // number of bars after Midnight defining the breakout range

extern string ___4___________________________ = "=== Optimization settings===";
extern int    BarsToOptimize                  = 0;          // number of bars to use (0: all available bars)
extern int    MaximumBarShift                 = 1440;       // max. number of bars a test trade can stay open
extern int    MinimumWinRate                  = 50;         // min. required winning rate in percent to make a system decision
extern double MinimumRiskReward               = 0;          // min. required risk/reward ratio required for a system (calculated as tp/sl)
extern double MinimumSuccessScore             = 0;          // min. required system success score (see thread on success scores for calculation)
extern int    MinimumSampleSize               = 10;         // min. required number of trades per parameter combination of trading hour, system and exit condition
extern bool   OptimizeForProfit               = false;      // max. profit
extern bool   OptimizeForWinRate              = false;      // max. number of winning trades
extern bool   OptimizeForRiskReward           = false;      // max. risk/reward ratio (calculated as reward/risk)
extern bool   OptimizeForSuccessScore         = true;       // max. success score (see thread on success scores for calculation)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

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
      lastOptimizationBars  = Optimize(); if (!lastOptimizationBars) return("");
      LastCalcDay           = TimeDayOfYear(Tick.time);
      sLastOptimizationTime = TimeToStr(Tick.time, TIME_FULL);
   }

   // determine day's start
   int DayStart   = iBarShift(NULL, NULL, StrToTime("00:00"), false);
   int RangeStart = DayStart - InitialRange;

   // determine current HiLo
   double HighPrice = High[iHighest(NULL, NULL, MODE_HIGH, RangeStart-1, 1)];
   double LowPrice  =  Low[ iLowest(NULL, NULL, MODE_LOW,  RangeStart-1, 1)];

   // read back optimization values
   static int    CurrentHour, CurrentHighTP, CurrentArraySizes, CurrentArrayNum;
   static double CurrentWinRate, CurrentRiskReward, CurrentSuccessScore;
   static string CurrentTradeStyle;

   if (CurrentHour != TimeHour(Tick.time)) {
      string filename = WindowExpertName() +" "+ Symbol() +" optimization.csv";
      int hFile = FileOpen(filename, FILE_CSV|FILE_READ, ';'); if (hFile < 0) return(_EMPTY_STR(catch("MainFunction(2)->FileOpen(\""+ filename +"\")")));

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
            CurrentWinRate      = HighWinRate;
            CurrentRiskReward   = HighRiskReward;
            CurrentSuccessScore = HighSuccessScore;
            CurrentTradeStyle   = TradeStyle;
            CurrentArraySizes   = ArraySizes;
            CurrentArrayNum     = ArrayNum;
            break;
         }
      }
      FileClose(hFile);
   }

   if (!ReverseTrades) TakeProfit = CurrentHighTP;
   else                StopLoss   = CurrentHighTP;

   // count open positions
   int TradeCount = 0;
   for (int i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol() && OrderType()<=OP_SELL) TradeCount++;
   }

   string TradeTrigger = "None";
   if (!MaxSimultaneousTrades || TradeCount < MaxSimultaneousTrades) {
      if (CurrentArraySizes >= MinimumSampleSize && DayStart > InitialRange && CurrentTradeStyle=="Breakout" && Close[Current] > HighPrice) TradeTrigger = "Open Long";
      if (CurrentArraySizes >= MinimumSampleSize && DayStart > InitialRange && CurrentTradeStyle=="Counter"  && Close[Current] > HighPrice) TradeTrigger = "Open Short";
      if (CurrentArraySizes >= MinimumSampleSize && DayStart > InitialRange && CurrentTradeStyle=="Breakout" && Close[Current] < LowPrice)  TradeTrigger = "Open Short";
      if (CurrentArraySizes >= MinimumSampleSize && DayStart > InitialRange && CurrentTradeStyle=="Counter"  && Close[Current] < LowPrice)  TradeTrigger = "Open Long";
      if (ReverseTrades) {
         if      (TradeTrigger == "Open Long")  TradeTrigger = "Open Short";
         else if (TradeTrigger == "Open Short") TradeTrigger = "Open Long";
      }
   }

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
                                            "Total open trades: ",     TradeCount,                                                NL,
                                            "Trade style: ",           CurrentTradeStyle,                                         NL,
                                            "Trade trigger: ",         TradeTrigger);

   // process open positions
   for (i=OrdersTotal()-1; i >= 0; i--) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;

      if (OrderType() == OP_BUY) {
         if (TradeTrigger=="Open Short" && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars!=CloseBarCount)))) {
            OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, MediumSeaGreen);
            if (!EachTickMode) CloseBarCount = Bars;
            continue;
         }
         PotentialStopLoss = OrderStopLoss();
         BEven             = CalcBreakEven(OrderTicket());
         TrailStop         = CalcTrailingStop(OrderTicket());

         if (BEven     > PotentialStopLoss) PotentialStopLoss = BEven;
         if (TrailStop > PotentialStopLoss) PotentialStopLoss = TrailStop;

         if (OrderStopLoss() != PotentialStopLoss) OrderModify(OrderTicket(), OrderOpenPrice(), PotentialStopLoss, OrderTakeProfit(), 0, MediumSeaGreen);
      }
      else if (OrderType() == OP_SELL) {
         if (TradeTrigger=="Open Long" && ((EachTickMode && !TickCheck) || (!EachTickMode && (Bars!=CloseBarCount)))) {
            OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, DarkOrange);
            if (!EachTickMode) CloseBarCount = Bars;
            continue;
         }
         PotentialStopLoss = OrderStopLoss();
         BEven             = CalcBreakEven(OrderTicket());
         TrailStop         = CalcTrailingStop(OrderTicket());

         if ((BEven     < PotentialStopLoss && BEven)     || (!PotentialStopLoss)) PotentialStopLoss = BEven;
         if ((TrailStop < PotentialStopLoss && TrailStop) || (!PotentialStopLoss)) PotentialStopLoss = TrailStop;

         if (PotentialStopLoss!=OrderStopLoss() || !OrderStopLoss()) OrderModify(OrderTicket(), OrderOpenPrice(), PotentialStopLoss, OrderTakeProfit(), 0, DarkOrange);
      }
   }

   // process signals for new positions
   if (!TradesThisBar && (((EachTickMode && !TickCheck) || (!EachTickMode && (Bars!=OpenBarCount))))) {
      if (TradeTrigger == "Open Long") {
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
      else if (TradeTrigger == "Open Short") {
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
 * @return double
 */
double CalcBreakEven(int ticket) {
   if (MoveStopToBreakeven && MoveStopToBreakevenWhen) {
      OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);

      if (OrderType() == OP_BUY) {
         if (Bid-OrderOpenPrice() >= MoveStopToBreakevenWhen*Point) {
            return(OrderOpenPrice());
         }
      }
      else if (OrderType() == OP_SELL) {
         if (OrderOpenPrice()-Ask >= MoveStopToBreakevenWhen*Point) {
            return(OrderOpenPrice());
         }
      }
   }
   return(NULL);
}


/**
 * @return double
 */
double CalcTrailingStop(int ticket) {
   if (UseTrailingStop && TrailingStop) {
      OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);

      if (OrderType() == OP_BUY) {
         if (Bid-OrderOpenPrice() > TrailingStop*Point) {
            return(Bid - TrailingStop*Point);
         }
      }
      else if (OrderType() == OP_SELL) {
         if (OrderOpenPrice()-Ask > TrailingStop*Point) {
            return(Ask + TrailingStop*Point);
         }
      }
   }
   return(NULL);
}


/**
 * @return int
 */
int Optimize() {
   DeleteFile(WindowExpertName() +" "+ Symbol() +" optimization.csv");

   int OptimizeBars = BarsToOptimize;
   if (!OptimizeBars) OptimizeBars = Bars;
   if (OptimizeBars > Bars) return(!catch("OptimizeSettings(1)  not enough bars to optimize for "+ Symbol(), ERR_RUNTIME_ERROR));

   int HighClose, LowClose;
   double HighValue, LowValue, HighestValue, LowestValue;

   int FBarStart     = OptimizeBars;
   int DayStartShift = FBarStart;
   int RangeEndShift = FBarStart;

   for (int bar=DayStartShift; bar > 1; bar--) {
      // determine if the bar is the daily start
      if (TimeDayOfYear(Time[bar]) != TimeDayOfYear(Time[bar+1])) {
         DayStartShift = bar;
      }

      // find the end of the range and establish initial high and low
      if (DayStartShift-bar == InitialRange) {
         RangeEndShift = bar;
         HighValue = High[iHighest(NULL, NULL, MODE_HIGH, DayStartShift-RangeEndShift, RangeEndShift)];
         LowValue  =  Low[ iLowest(NULL, NULL, MODE_LOW,  DayStartShift-RangeEndShift, RangeEndShift)];
      }

      // determine subsequent high and low
      if (DayStartShift > RangeEndShift) {
         if (High[bar] > HighValue) {
            HighClose    = MathMax(bar-MaximumBarShift, TradeCloseShift("Long", HighValue, bar) + 1);
            HighestValue = High[iHighest(NULL, NULL, MODE_HIGH, bar-HighClose, HighClose)];
            WriteHourlyStats(TimeHour(Time[bar]), "Breakout", ((HighestValue-HighValue) / Point));

            HighClose   = MathMax(bar-MaximumBarShift, TradeCloseShift("Short", HighValue, bar) + 1);
            LowestValue = Low[iLowest(NULL, NULL, MODE_LOW, bar-HighClose, HighClose)];
            WriteHourlyStats(TimeHour(Time[bar]), "Counter", ((HighValue-LowestValue) / Point));
            HighValue   = High[bar];
         }
         if (Low[bar] < LowValue) {
            LowClose     = MathMax(bar - MaximumBarShift, TradeCloseShift("Long", LowValue, bar) + 1);
            HighestValue = High[iHighest(NULL, NULL, MODE_HIGH, bar-LowClose, LowClose)];
            WriteHourlyStats(TimeHour(Time[bar]), "Counter", ((HighestValue-LowValue) / Point));

            LowClose    = MathMax(bar-MaximumBarShift, TradeCloseShift("Short", LowValue, bar) + 1);
            LowestValue = Low[iLowest(NULL, NULL, MODE_LOW, bar-LowClose, LowClose)];
            WriteHourlyStats(TimeHour(Time[bar]), "Breakout", ((LowValue-LowestValue) / Point));
            LowValue    = Low[bar];
         }
      }
   }

   // determine the most profitable combination
   for (int i=0; i <= 23; i++) {
      if (!OptimizeTakeProfit(i)) return(NULL);
   }
   return(ifInt(catch("OptimizeSettings(2)"), 0, OptimizeBars));
}


/**
 * @param  int hour - hour to optimize
 *
 * @return bool - success status
 */
bool OptimizeTakeProfit(int hour) {
   double BOTPArray[]; ArrayResize(BOTPArray, 0);
   double CTTPArray[]; ArrayResize(CTTPArray, 0);

   // read hourly stats
   string filename = WindowExpertName() +" "+ Symbol() +" stats "+ StrRight("0"+ hour, 2) +".csv";
   if (MQL.IsFile(filename)) {
      int hFile = FileOpen(filename, FILE_CSV|FILE_READ, ';'); if (hFile < 0) return(!catch("OptimizeTakeProfit(1)->FileOpen(\""+ filename +"\")"));

      while (!FileIsEnding(hFile)) {
         string TPMax      = FileReadString(hFile); if (!IsValidHourlyStatsField(hFile, filename, 1, TPMax))         break;
         string FoundStyle = FileReadString(hFile); if (!IsValidHourlyStatsField(hFile, filename, 2, FoundStyle))    break;

         if      (FoundStyle == "Breakout") BOTPArray[ArrayResize(BOTPArray, ArraySize(BOTPArray)+1)-1] = StrToDouble(TPMax);
         else if (FoundStyle == "Counter")  CTTPArray[ArrayResize(CTTPArray, ArraySize(CTTPArray)+1)-1] = StrToDouble(TPMax);
         else                               return(!catch("OptimizeTakeProfit(2)  invalid file format in \""+ filename +"\": FoundStyle=\""+ FoundStyle +"\"", ERR_INVALID_FILE_FORMAT));
      }
      if (IsLastError()) return(false);
      FileClose(hFile);
      FileDelete(filename);

      if (ArraySize(BOTPArray) != 0) ArraySort(BOTPArray);
      if (ArraySize(CTTPArray) != 0) ArraySort(CTTPArray);
   }

   // breakout trades: calculate SL total and TP total for each side
   double BOHighProfit, BOHighTP, BOHighWinRate, BOHighRiskReward, BOHighSuccessScore, BOArrayNum;
   int arraySize = ArraySize(BOTPArray);

   for (int i=0; i < arraySize; i++) {
      double BOStopLossValue   = StopLoss * i;
      double BOTakeProfitValue = BOTPArray[i] * (arraySize-i);
      double BOProfit          = BOTakeProfitValue - BOStopLossValue;
      double BOWinRate         = 1 - (i+1.0) / arraySize;
      double BORiskReward      = BOTPArray[i] / StopLoss;
      double BOSS              = BOWinRate * BORiskReward;

      if (BOWinRate >= MinimumWinRate/100. && BORiskReward >= MinimumRiskReward && BOSS >= MinimumSuccessScore) {
         BOHighProfit       = BOProfit;
         BOHighTP           = BOTPArray[i];
         BOArrayNum         = i;
         BOHighWinRate      = BOWinRate;
         BOHighRiskReward   = BORiskReward;
         BOHighSuccessScore = BOSS;
      }
   }

   // counter trades: calculate SL total and TP total for each side.
   double CTHighProfit, CTHighTP, CTHighWinRate, CTHighRiskReward, CTHighSuccessScore, CTArrayNum;
   arraySize = ArraySize(CTTPArray);

   for (i=0; i < arraySize; i++) {
      double CTStopLossValue   = StopLoss * i;
      double CTTakeProfitValue = CTTPArray[i] * (arraySize-i);
      double CTProfit          = CTTakeProfitValue - CTStopLossValue;
      double CTWinRate         = 1 - (i+1.0) / arraySize;
      double CTRiskReward      = CTTPArray[i] / StopLoss;
      double CTSS              = CTWinRate * CTRiskReward;

      if (CTWinRate >= MinimumWinRate/100. && CTRiskReward >= MinimumRiskReward && CTSS >= MinimumSuccessScore) {
         CTHighProfit       = CTProfit;
         CTHighTP           = CTTPArray[i];
         CTArrayNum         = i;
         CTHighWinRate      = CTWinRate;
         CTHighRiskReward   = CTRiskReward;
         CTHighSuccessScore = CTSS;
      }
   }

   double HighTP=-1, HighProfit=-1, HighWinRate=-1, HighRiskReward=-1, HighSuccessScore=-1;
   int    ArraySizes=-1, ArrayNum=-1;
   string TradeStyle = "None";

   if ((OptimizeForProfit && BOHighProfit > CTHighProfit) || (OptimizeForWinRate && BOHighWinRate > CTHighWinRate) || (OptimizeForRiskReward && BOHighRiskReward > CTHighRiskReward) || (OptimizeForSuccessScore && BOHighSuccessScore > CTHighSuccessScore)) {
      HighTP           = BOHighTP;
      HighProfit       = BOHighProfit;
      HighWinRate      = BOHighWinRate;
      HighRiskReward   = BOHighRiskReward;
      HighSuccessScore = BOHighSuccessScore;
      TradeStyle       = "Breakout";
      ArraySizes       = ArraySize(BOTPArray);
      ArrayNum         = BOArrayNum;
   }

   if ((OptimizeForProfit && CTHighProfit > BOHighProfit) || (OptimizeForWinRate && CTHighWinRate > BOHighWinRate) || (OptimizeForRiskReward && CTHighRiskReward > BOHighRiskReward) || (OptimizeForSuccessScore && CTHighSuccessScore > BOHighSuccessScore)) {
      HighTP           = CTHighTP;
      HighProfit       = CTHighProfit;
      HighWinRate      = CTHighWinRate;
      HighRiskReward   = CTHighRiskReward;
      HighSuccessScore = CTHighSuccessScore;
      TradeStyle       = "Counter";
      ArraySizes       = ArraySize(CTTPArray);
      ArrayNum         = CTArrayNum;
   }

   filename = WindowExpertName() +" "+ Symbol() +" optimization.csv";
   hFile = FileOpen(filename, FILE_CSV|FILE_READ|FILE_WRITE, ';'); if (hFile < 0) return(!catch("OptimizeTakeProfit(3)->FileOpen(\""+ filename +"\")"));
   FileSeek(hFile, 0, SEEK_END);
   FileWrite(hFile, hour, HighTP, HighProfit, HighWinRate, HighRiskReward, HighSuccessScore, TradeStyle, ArraySizes, ArrayNum);
   FileClose(hFile);

   return(!catch("OptimizeTakeProfit(5)"));
}


/**
 *
 */
string WriteHourlyStats(int hour, string TradeStyle, int TPMax) {
   int hFile = FileOpen(WindowExpertName() +" "+ Symbol() +" stats "+ StrRight("0"+ hour, 2) +".csv", FILE_CSV|FILE_READ|FILE_WRITE, ';');
   FileSeek(hFile, 0, SEEK_END);
   FileWrite(hFile, TPMax, TradeStyle);
   FileClose(hFile);
}


/**
 *
 */
int TradeCloseShift(string Direction, double EntryPrice, int shift) {
   double TargetPrice = 0;

   if (Direction == "Long") {
      if (!ReverseTrades) TargetPrice = EntryPrice - StopLoss*Point;
      else                TargetPrice = EntryPrice - TakeProfit*Point;
   }
   if (Direction == "Short") {
      if (!ReverseTrades) TargetPrice = EntryPrice + StopLoss*Point;
      else                TargetPrice = EntryPrice + TakeProfit*Point;
   }

   for (int bar=shift; bar > 0; bar--) {
      if (Direction == "Long") {
         if (High[bar] >= TargetPrice && Low[bar] <= TargetPrice) {
            return(bar);
         }
      }
      if (Direction == "Short") {
         if (High[bar] >= TargetPrice && Low[bar] <= TargetPrice) {
            return(bar);
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
