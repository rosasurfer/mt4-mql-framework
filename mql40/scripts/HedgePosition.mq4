/**
 * HedgePosition
 *
 * Hedges open positions of the current symbol. By default positions managed by an EA are skipped. If the Ctrl key (VK_CONTROL)
 * is pressed at script launch time positions managed by an EA are hedged, too.
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
   bool skipManaged = !IsVirtualKeyDown(VK_CONTROL);

   // get tickets of open positions
   int tickets[];
   if (!CollectTickets(tickets, skipManaged)) return(last_error);

   // notify user
   int positions = ArraySize(tickets);
   if (!positions) {
      PlaySoundEx("Plonk.wav");
      MessageBox("No open positions found.", WindowExpertName(), MB_ICONEXCLAMATION|MB_OK);
      return(catch("onStart(1)"));
   }

   // get user confirmation
   PlaySoundEx("Windows Notify.wav");
   string sManaged = ifString(skipManaged, "", " (including EAs)");
   string msg = "Do you really want to hedge "+ positions +" open position"+ Pluralize(positions) + sManaged +"?";
   int button = MessageBox(ifString(IsDemoFix(), "", "- Real Account -\n\n") + msg, WindowExpertName(), MB_ICONQUESTION|MB_OKCANCEL);
   if (button != IDOK) return(catch("onStart(2)"));

   // refresh selected tickets (orders may have changed during wait for confirmation)
   if (!CollectTickets(tickets, skipManaged)) return(last_error);

   // hedge positions
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
 * Collect the tickets of all open positions to hedge.
 *
 * @param  _Out_ int  tickets[]
 * @param  _In_  bool skipManaged [optional] - whether to skip tickets managed by an EA (default: yes)
 *
 * @return bool - success status
 */
bool CollectTickets(int &tickets[], bool skipManaged = true) {
   skipManaged = (skipManaged != 0);

   // Don't cache the results. Order counters don't change if pending entry orders are executed.
   int orders = OrdersTotal();

   ArrayResize(tickets, orders);
   ArrayInitialize(tickets, 0);

   int n = 0;
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;  // an open order was closed/deleted elsewhere
      if (OrderType() > OP_SELL)             continue;
      if (OrderSymbol() != Symbol())         continue;
      if (OrderMagicNumber() && skipManaged) continue;

      tickets[n] = OrderTicket();
      n++;
   }
   ArrayResize(tickets, n);

   return(!catch("CollectTickets(1)"));
}
