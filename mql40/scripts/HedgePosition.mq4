/**
 * HedgePosition
 *
 * Hedge open positions of the current symbol.
 *
 *
 * TODO:
 *  - INFO   CloseOrders::rsfStdlib::OrdersHedge(17)  hedging 16 XAUUSD positions...
 *    FATAL  CloseOrders::rsfStdlib::OrderSendEx(28)  error while trying to Buy 0.14 XAUUSD at 2'329.99 after 0.000 s  [ERR_NOT_ENOUGH_MONEY]
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED, INIT_AUTO_TRADING};
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/structs/OrderExecution.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   // read open positions
   int tickets[];
   if (!GetOpenPositions(tickets)) return(last_error);

   // notify user
   int positions = ArraySize(tickets);
   if (!positions) {
      PlaySoundEx("Plonk.wav");
      MessageBox("No open positions found.", WindowExpertName(), MB_ICONEXCLAMATION|MB_OK);
      return(catch("onStart(1)"));
   }

   // get user confirmation
   PlaySoundEx("Windows Notify.wav");
   string msg = "Do you really want to hedge "+ positions +" open position"+ Pluralize(positions) +"?";
   int button = MessageBox(ifString(IsDemoFix(), "", "- Real Account -\n\n") + msg, WindowExpertName(), MB_ICONQUESTION|MB_OKCANCEL);
   if (button != IDOK) return(catch("onStart(2)"));

   // re-read open positions (orders may have changed during waiting for the dialog)
   if (!GetOpenPositions(tickets)) return(last_error);

   // hedge open positions
   int oes[][ORDER_EXECUTION_intSize], slippage = 10;          // acceptable slippage in Points

   if (!OrdersHedge(tickets, slippage, F_OE_HEDGE_NO_CLOSE, oes)) {
      int error = oes.Error(oes, 0);
      if (IsError(error)) return(SetLastError(error));

      PlaySoundEx("Plonk.wav");
      MessageBox("The total position is already flat.", WindowExpertName(), MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(3)"));
}


/**
 * Get a list of open positions of the current symbol.
 *
 * @param  _Out_ int tickets[]
 * @param  _In_  int selection flags (default: none)
 *
 * @return bool - success status
 */
bool GetOpenPositions(int &tickets[], int flags = NULL) {
   static int lastOpenOrders=-1, lastCloseOrders=-1, lastFlags=0, lastTickets[];

   int openOrders = OrdersTotal();
   int closedOrders = OrdersHistoryTotal();

   // return cached results if status unchanged
   if (openOrders==lastOpenOrders && closedOrders==lastCloseOrders && flags==lastFlags) {
      ArrayResize(tickets, 0);
      if (ArraySize(lastTickets) > 0) {
         ArrayCopy(tickets, lastTickets);
      }
      debug("GetOpenPositions(0.1)  returning cached positions");
      return(!catch("GetOpenPositions(1)"));
   }

   // or re-read open positions if status changed
   debug("GetOpenPositions(0.2)  re-reading open positions");
   ArrayResize(tickets, openOrders);
   ArrayInitialize(tickets, NULL);

   int n = 0;
   for (int i=0; i < openOrders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;  // an open order was closed/deleted elsewhere
      if (OrderType() > OP_SELL)     continue;
      if (OrderSymbol() != Symbol()) continue;
      tickets[n] = OrderTicket();
      n++;
   }
   ArrayResize(tickets, n);

   // cache results
   lastOpenOrders = openOrders;
   lastCloseOrders = closedOrders;
   lastFlags = flags;

   ArrayResize(lastTickets, 0);
   if (ArraySize(tickets) > 0) {
      ArrayCopy(lastTickets, tickets);
   }
   return(!catch("GetOpenPositions(2)"));
}
