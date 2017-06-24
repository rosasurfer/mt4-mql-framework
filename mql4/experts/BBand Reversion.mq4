/**
 * BBTrade v2.0
 *
 * Version 2.0 can handle multiple positions per direction and supports two different exit conditions.
 * It can mirror version 1.0.
 *
 * Long
 * ----
 *  - Buy on bar open if a previous bar closed below BBand(40, MODE_LOWER) and the last bar closed above that value.
 *  - Open another position if another signal occures and the current entry level is below those of the existing positions.
 *  - Skip an entry signal if it occures above the BBand main line.
 *  - Close all positions if the last bar closes above the BBand main line and at least one position is in profit.
 *
 * Short
 * -----
 *  - Sell on bar open if a previous bar closed above BBand(40, MODE_UPPER) and the last bar closed below that value.
 *  - Open another position if another signal occures and the current entry level is above those of the existing positions.
 *  - Skip an entry signal if it occures above the BBand main line.
 *  - Close all positions if the last bar closes below the BBand main line and at least one position is in profit.
 *
 * Do not open more than three positions per direction.
 *
 * Clarify
 * -------
 *  - How are the rules applied if an entry signal occures and the last bar already crossed the BBand main line? Would a new
 *    position at break-even immediately fullfill the exit conditions or not?
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    BB.Periods          = 40;
extern int    BB.Deviation        = 2;
extern int    Open.Max.Positions  = 3;
extern int    Open.Min.Distance   = 0;
extern bool   Close.If.Profitable = true;
extern double Lotsize             = 0.1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>

int      long.positions       = 0;
double   long.lastEntryLevel  = INT_MAX;

int      short.positions      = 0;
double   short.lastEntryLevel = INT_MIN;

int      slippage    = 0;
double   stopLoss    = NULL;
double   takeProfit  = NULL;
datetime expiration  = NULL;
int      magicNumber = NULL;
string   comment     = "";


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   static datetime lastBarOpenTime = NULL;
   if (Time[0] != lastBarOpenTime) {         // simplified Tester BarOpen event
      lastBarOpenTime = Time[0];

      // check long conditions
      int lastPositions = long.positions;
      if (long.positions < Open.Max.Positions)             Long.CheckOpenSignal();
      if (long.positions && long.positions==lastPositions) Long.CheckCloseSignal();    // don't check for close on an open signal

      // check short conditions
      lastPositions = short.positions;
      if (short.positions < Open.Max.Positions)              Short.CheckOpenSignal();
      if (short.positions && short.positions==lastPositions) Short.CheckCloseSignal(); // don't check for close on an open signal
   }
   return(last_error);
}


/**
 * Check for long entry conditions
 */
void Long.CheckOpenSignal() {
   if (Close[2] < iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_LOWER, 2) && Close[1] > iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_LOWER, 1)) {
      if (Close[1] < iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_MAIN, 1)) {
         if (Ask < long.lastEntryLevel - Open.Min.Distance*Pips) {
            int ticket = OrderSend(Symbol(), OP_BUY, Lotsize, Ask, slippage, stopLoss, takeProfit, comment, magicNumber, expiration, Blue);
            if (IsTesting()) {
               OrderSelect(ticket, SELECT_BY_TICKET);
               Test_OpenOrder(__ExecutionContext, OrderTicket(), OrderType(), OrderLots(), OrderSymbol(), OrderOpenPrice(), OrderOpenTime(), OrderStopLoss(), OrderTakeProfit(), OrderCommission(), OrderMagicNumber(), OrderComment());
            }
            long.positions++;
            long.lastEntryLevel = Ask;
         }
      }
   }
}


/**
 * Check for long exit conditions
 */
void Long.CheckCloseSignal() {
   if (Close[1] > iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_MAIN, 1)) {
      if (!Close.If.Profitable || long.lastEntryLevel < Bid) {
         int tickets[]; ArrayResize(tickets, 0);
         int orders = OrdersTotal();

         for (int i=0; i < orders; i++) {
            OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
            if (OrderType() == OP_BUY) {
               ArrayPushInt(tickets, OrderTicket());
            }
         }
         orders = ArraySize(tickets);

         for (i=0; i < orders; i++) {
            int ticket = tickets[i];
            OrderSelect(ticket, SELECT_BY_TICKET);
            OrderClose(ticket, OrderLots(), Bid, slippage, Gold);
            if (IsTesting()) {
               OrderSelect(ticket, SELECT_BY_TICKET);
               Test_CloseOrder(__ExecutionContext, ticket, OrderClosePrice(), OrderCloseTime(), OrderSwap(), OrderProfit());
            }
         }
         long.positions      = 0;
         long.lastEntryLevel = INT_MAX;
      }
   }
}


/**
 * Check for short entry conditions
 */
void Short.CheckOpenSignal() {
   if (Close[2] > iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_UPPER, 2) && Close[1] < iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_UPPER, 1)) {
      if (Close[1] > iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_MAIN, 1)) {
         if (Bid > short.lastEntryLevel + Open.Min.Distance*Pips) {
            int ticket = OrderSend(Symbol(), OP_SELL, Lotsize, Bid, slippage, stopLoss, takeProfit, comment, magicNumber, expiration, Red);
            if (IsTesting()) {
               OrderSelect(ticket, SELECT_BY_TICKET);
               Test_OpenOrder(__ExecutionContext, ticket, OrderType(), OrderLots(), OrderSymbol(), OrderOpenPrice(), OrderOpenTime(), OrderStopLoss(), OrderTakeProfit(), OrderCommission(), OrderMagicNumber(), OrderComment());
            }
            short.positions++;
            short.lastEntryLevel = Bid;
         }
      }
   }
}


/**
 * Check for short exit conditions
 */
void Short.CheckCloseSignal() {
   if (Close[1] < iBands(NULL, NULL, BB.Periods, BB.Deviation, 0, PRICE_CLOSE, MODE_MAIN, 1)) {
      if (!Close.If.Profitable || short.lastEntryLevel > Ask) {
         int tickets[]; ArrayResize(tickets, 0);
         int orders = OrdersTotal();

         for (int i=0; i < orders; i++) {
            OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
            if (OrderType() == OP_SELL) {
               ArrayPushInt(tickets, OrderTicket());
            }
         }
         orders = ArraySize(tickets);

         for (i=0; i < orders; i++) {
            int ticket = tickets[i];
            OrderSelect(ticket, SELECT_BY_TICKET);
            OrderClose(ticket, OrderLots(), Ask, slippage, Gold);
            if (IsTesting()) {
               OrderSelect(ticket, SELECT_BY_TICKET);
               Test_CloseOrder(__ExecutionContext, ticket, OrderClosePrice(), OrderCloseTime(), OrderSwap(), OrderProfit());
            }
         }
         short.positions      = 0;
         short.lastEntryLevel = INT_MIN;
      }
   }
}
