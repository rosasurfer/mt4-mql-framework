/**
 * Opto123 Pattern EA
 *
 * A simplified, streamlined and fixed version of the original 123 Pattern EA v1.0 published by Ronald Raygun. The trading
 * logic is unchanged.
 *
 *
 * @source  https://www.forexfactory.com/thread/post/4090801#post4090801                            [Opto123 Pattern EA v1.0]
 */
#define SIGNAL_NONE        0
#define SIGNAL_BUY         1
#define SIGNAL_SELL        2
#define SIGNAL_CLOSEBUY    3
#define SIGNAL_CLOSESELL   4

extern string Remark1           = "== Main Settings ==";
extern int    MagicNumber       = 0;
extern int    PipBuffer         = 0;
extern double Lots              = 0;
extern bool   MoneyManagement   = false;
extern int    Risk              = 0;
extern int    Slippage          = 5;
extern bool   UseStopLoss       = true;
extern int    StopLoss          = 100;
extern bool   UseTakeProfit     = false;
extern int    TakeProfit        = 60;
extern bool   UseTrailingStop   = false;
extern int    TrailingStop      = 30;
extern bool   MoveStopOnce      = false;
extern int    MoveStopWhenPrice = 50;
extern string Remark2           = "== Zig Zag Settings ==";
extern int    ExtDepth          = 2;
extern int    ExtDeviation      = 1;
extern int    ExtBackstep       = 1;

int BrokerMultiplier = 1;


/**
 * Initialization
 *
 * @return int - error status
 */
int init() {
   if (Digits==3 || Digits==5) BrokerMultiplier = 10;

   if (MoneyManagement && (Risk < 1 || Risk > 100)) {
      Comment("Invalid Risk Value.");
      return(1);
   }
   return(0);
}


/**
 * Main function
 *
 * @return int - error status
 */
int start() {
   // get ZigZag values and check entry signals
   double ZZ1, ZZ2, ZZ3;
   int PointShift1 = 1;
   string ConfirmedPoint = "Not Found";
   string PointShiftDirection = "None";

   while (ConfirmedPoint != "Found") {
      ZZ1 = iCustom(NULL, NULL, "ZigZag", ExtDepth, ExtDeviation, ExtBackstep, 0, PointShift1);

      if (High[PointShift1]==ZZ1 || Low[PointShift1]==ZZ1) {
         ConfirmedPoint = "Found";

         if (High[PointShift1] == ZZ1) {
            PointShiftDirection = "High";
            break;
         }
         if (Low[PointShift1] == ZZ1) {
            PointShiftDirection = "Low";
            break;
         }
      }
      PointShift1++;
   }

   int PointShift2 = PointShift1;
   string ConfirmedPoint2 = "Not Found";

   while (ConfirmedPoint2 != "Found") {
      ZZ2 = iCustom(NULL, NULL, "ZigZag", ExtDepth, ExtDeviation, ExtBackstep, 0, PointShift2);

      if (High[PointShift2]==ZZ2 && PointShiftDirection=="Low") {
         ConfirmedPoint2 = "Found";
         break;
      }
      if (Low[PointShift2]==ZZ2 && PointShiftDirection=="High") {
         ConfirmedPoint2 = "Found";
         break;
      }
      PointShift2++;
   }

   int PointShift3 = PointShift2;
   string ConfirmedPoint3 = "Not Found";

   while (ConfirmedPoint3 != "Found") {
      ZZ3 = iCustom(NULL, NULL, "ZigZag", ExtDepth, ExtDeviation, ExtBackstep, 0, PointShift3);

      if (High[PointShift3]==ZZ3 && PointShiftDirection=="High") {
         ConfirmedPoint3 = "Found";
         break;
      }
      if (Low[PointShift3]==ZZ3 && PointShiftDirection=="Low") {
         ConfirmedPoint3 = "Found";
         break;
      }
      PointShift3++;
   }

   ZZ1 = iCustom(NULL, NULL, "ZigZag", ExtDepth, ExtDeviation, ExtBackstep, 0, PointShift1);
   ZZ2 = iCustom(NULL, NULL, "ZigZag", ExtDepth, ExtDeviation, ExtBackstep, 0, PointShift2);
   ZZ3 = iCustom(NULL, NULL, "ZigZag", ExtDepth, ExtDeviation, ExtBackstep, 0, PointShift3);

   double LongEntry, ShortEntry;
   if (ZZ3 < ZZ2 && ZZ2 > ZZ1 && ZZ1 > ZZ3) LongEntry  = ZZ2 + PipBuffer*Point;
   if (ZZ3 > ZZ2 && ZZ2 < ZZ1 && ZZ1 < ZZ3) ShortEntry = ZZ2 - PipBuffer*Point;

   string TradeTrigger = "None";
   if (Open[0] < LongEntry  && Close[0] >= LongEntry ) TradeTrigger = "Open Long";
   if (Open[0] > ShortEntry && Close[0] <= ShortEntry) TradeTrigger = "Open Short";

   Comment("Long Entry: ",    LongEntry,  "\n",
           "Short Entry: ",   ShortEntry, "\n",
           "Trade Trigger: ", TradeTrigger);

   // manage open positions
   double StopLossLevel, TakeProfitLevel, PotentialStopLoss, BEven, TrailStop;
   int orders = OrdersTotal();
   bool isOpenPosition = false;

   for (int i=0; i < orders; i ++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderType() > OP_SELL || OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      isOpenPosition = true;

      // long
      if (OrderType() == OP_BUY) {
         PotentialStopLoss = OrderStopLoss();
         BEven             = CalcBreakEven(OrderTicket());
         TrailStop         = CalcTrailingStop(OrderTicket());

         if (BEven     > PotentialStopLoss && BEven)     PotentialStopLoss = BEven;
         if (TrailStop > PotentialStopLoss && TrailStop) PotentialStopLoss = TrailStop;

         if (PotentialStopLoss != OrderStopLoss()) OrderModify(OrderTicket(), OrderOpenPrice(), PotentialStopLoss, OrderTakeProfit(), 0, MediumSeaGreen);
      }

      // short
      else {
         PotentialStopLoss = OrderStopLoss();
         BEven             = CalcBreakEven(OrderTicket());
         TrailStop         = CalcTrailingStop(OrderTicket());

         if ((BEven     < PotentialStopLoss && BEven)     || !PotentialStopLoss) PotentialStopLoss = BEven;
         if ((TrailStop < PotentialStopLoss && TrailStop) || !PotentialStopLoss) PotentialStopLoss = TrailStop;

         if (PotentialStopLoss != OrderStopLoss() || !OrderStopLoss()) OrderModify(OrderTicket(), OrderOpenPrice(), PotentialStopLoss, OrderTakeProfit(), 0, DarkOrange);
      }
   }

   // open new positions
   if (!isOpenPosition) {
      int signal = SIGNAL_NONE;
      if (TradeTrigger == "Open Long")  signal = SIGNAL_BUY;
      if (TradeTrigger == "Open Short") signal = SIGNAL_SELL;

      if (MoneyManagement) Lots = MathFloor((AccountFreeMargin()*AccountLeverage()*Risk*Point*BrokerMultiplier*100) / (Ask*MarketInfo(Symbol(), MODE_LOTSIZE)*MarketInfo(Symbol(), MODE_MINLOT))) * MarketInfo(Symbol(), MODE_MINLOT);

      if (signal == SIGNAL_BUY) {
         if (UseStopLoss)   StopLossLevel   = Ask -   StopLoss*Point; else StopLossLevel   = 0;
         if (UseTakeProfit) TakeProfitLevel = Ask + TakeProfit*Point; else TakeProfitLevel = 0;
         OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, StopLossLevel, TakeProfitLevel, "Opto123 Buy", MagicNumber, 0, DodgerBlue);
      }
      if (signal == SIGNAL_SELL) {
         if (UseStopLoss)   StopLossLevel   = Bid +   StopLoss*Point; else StopLossLevel   = 0;
         if (UseTakeProfit) TakeProfitLevel = Bid - TakeProfit*Point; else TakeProfitLevel = 0;
         OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, StopLossLevel, TakeProfitLevel, "Opto123 Sell", MagicNumber, 0, DeepPink);
      }
   }
   return(0);
}


/**
 * @return double
 */
double CalcBreakEven(int ticket) {
   if (MoveStopOnce && MoveStopWhenPrice) {
      OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);

      if (OrderType() == OP_BUY) {
         if (Bid-OrderOpenPrice() >= MoveStopWhenPrice*Point) {
            return(OrderOpenPrice());
         }
      }
      else if (OrderType() == OP_SELL) {
         if (OrderOpenPrice()-Ask >= MoveStopWhenPrice*Point) {
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
