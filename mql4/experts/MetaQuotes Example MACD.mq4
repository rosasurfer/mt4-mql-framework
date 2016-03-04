//+------------------------------------------------------------------+
//|                                                  MACD Sample.mq4 |
//|                      Copyright © 2005, MetaQuotes Software Corp. |
//|                                       http://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "(original unmodified MetaQuotes version)"             // pewa: reformatted and final error check added


extern double TakeProfit     = 50;
extern double Lots           = 0.1;
extern double TrailingStop   = 30;
extern double MACDOpenLevel  =  3;
extern double MACDCloseLevel =  2;
extern double MATrendPeriod  = 26;


/**
 *
 */
int start() {
   double MacdCurrent, MacdPrevious, SignalCurrent;
   double SignalPrevious, MaCurrent, MaPrevious;
   int cnt, ticket, total;

   // initial data checks
   // it is important to make sure that the expert works with a normal
   // chart and the user did not make any mistakes setting external
   // variables (Lots, StopLoss, TakeProfit,
   // TrailingStop) in our case, we check TakeProfit
   // on a chart of less than 100 bars
   if (Bars < 100) {
      Print("bars less than 100");
      CheckError("start(1)");
      return(0);
   }
   if (TakeProfit < 10) {
      Print("TakeProfit less than 10");
      CheckError("start(2)");
      return(0);  // check TakeProfit
   }

   // to simplify the coding and speed up access
   // data are put into internal variables
   MacdCurrent    = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN,   0);
   MacdPrevious   = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN,   1);
   SignalCurrent  = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
   SignalPrevious = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 1);
   MaCurrent      =   iMA(NULL, 0, MATrendPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   MaPrevious     =   iMA(NULL, 0, MATrendPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);

   total = OrdersTotal();

   if (total < 1) {
      // no opened orders identified
      if (AccountFreeMargin() < 1000*Lots) {
         Print("We have no money. Free Margin = ", AccountFreeMargin());
         CheckError("start(3)");
         return(0);
      }

      // check for long position (BUY) possibility
      if (MacdCurrent < 0 && MacdCurrent > SignalCurrent && MacdPrevious < SignalPrevious && MathAbs(MacdCurrent) > MACDOpenLevel*Point && MaCurrent > MaPrevious) {
         ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, 3, 0, Ask+TakeProfit*Point, "macd sample", 16384, 0, Green);
         if (ticket > 0) {
            if (OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
               Print("BUY order opened : ", OrderOpenPrice());
         }
         else {
            Print("Error opening BUY order : ", GetLastError());
         }
         CheckError("start(4)");
         return(0);
      }

      // check for short position (SELL) possibility
      if (MacdCurrent > 0 && MacdCurrent < SignalCurrent && MacdPrevious > SignalPrevious && MacdCurrent > MACDOpenLevel*Point && MaCurrent < MaPrevious) {
         ticket = OrderSend(Symbol(), OP_SELL, Lots, Bid, 3, 0, Bid-TakeProfit*Point, "macd sample", 16384, 0, Red);
         if (ticket > 0) {
            if (OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
               Print("SELL order opened : ", OrderOpenPrice());
         }
         else {
            Print("Error opening SELL order : ", GetLastError());
         }
         CheckError("start(5)");
         return(0);
      }
      CheckError("start(6)");
      return(0);
   }

   // it is important to enter the market correctly,
   // but it is more important to exit it correctly...
   for (cnt=0; cnt < total; cnt++) {
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if (OrderType()<=OP_SELL && OrderSymbol()==Symbol()) {            // check for opened position and symbol
         if (OrderType()==OP_BUY) {                                     // long position is opened
            // should it be closed?
            if (MacdCurrent > 0 && MacdCurrent < SignalCurrent && MacdPrevious > SignalPrevious && MacdCurrent > MACDCloseLevel*Point) {
               OrderClose(OrderTicket(), OrderLots(), Bid, 3, Violet);  // close position
               CheckError("start(7)");
               return(0);
            }
            // check for trailing stop
            if (TrailingStop > 0) {
               if (Bid-OrderOpenPrice() > Point*TrailingStop) {
                  if (OrderStopLoss() < Bid-Point*TrailingStop) {
                     OrderModify(OrderTicket(), OrderOpenPrice(), Bid-Point*TrailingStop, OrderTakeProfit(), 0, Green);
                     CheckError("start(8)");
                     return(0);
                  }
               }
            }
         }
         else {                                                         // go to short position
            // should it be closed?
            if (MacdCurrent < 0 && MacdCurrent > SignalCurrent && MacdPrevious < SignalPrevious && MathAbs(MacdCurrent) > MACDCloseLevel*Point) {
               OrderClose(OrderTicket(), OrderLots(), Ask, 3, Violet);  // close position
               CheckError("start(9)");
               return(0);
            }
            // check for trailing stop
            if (TrailingStop > 0) {
               if (OrderOpenPrice()-Ask > Point*TrailingStop) {
                  if (OrderStopLoss() > Ask+Point*TrailingStop || OrderStopLoss()==0) {
                     OrderModify(OrderTicket(), OrderOpenPrice(), Ask+Point*TrailingStop, OrderTakeProfit(), 0, Red);
                     CheckError("start(10)");
                     return(0);
                  }
               }
            }
         }
      }
   }
   CheckError("start(11)");
   return(0);
}


/**
 * pewa: error check and one single alert at the first error
 */
void CheckError(string location) {
   int error = GetLastError();
   if (error != 0) {
      static bool alerted = false;
      if (!alerted) {
         Alert(WindowExpertName() +"::"+ location +"  error="+ error);
         alerted = true;
      }
   }
}
