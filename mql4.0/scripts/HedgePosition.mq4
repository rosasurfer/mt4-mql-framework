/**
 * Hedge the directional open position of the current symbol.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];

//#property show_inputs

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/structs/OrderExecution.mqh>


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // enable auto-trading if disabled
   if (!IsExpertEnabled()) {
      int error = Toolbar.Experts(true);
      if (IsError(error)) return(error);

      PlaySoundEx("Windows Notify.wav");                          // we must return as scripts don't update their internal auto-trading status
      MessageBox("Please call the script again!"+ NL +"(\"auto-trading\" was not enabled)", ProgramName(), MB_ICONINFORMATION|MB_OK);
      return(SetLastError(ERR_TERMINAL_AUTOTRADE_DISABLED));
   }
   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   // read tickets of currently open positions
   int orders = OrdersTotal(), tickets[];
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;     // FALSE: an open order was closed/deleted in another thread
      if (OrderType() > OP_SELL)     continue;
      if (OrderSymbol() != Symbol()) continue;
      ArrayPushInt(tickets, OrderTicket());
   }
   int positions = ArraySize(tickets);

   // notify
   if (!positions) {
      PlaySoundEx("Plonk.wav");
      MessageBox("No open positions found.", ProgramName(), MB_ICONEXCLAMATION|MB_OK);
      return(catch("onStart(1)"));
   }

   // get confirmation
   PlaySoundEx("Windows Notify.wav");
   string msg = "Do you really want to hedge "+ positions +" open position"+ Pluralize(positions) +"?";
   int button = MessageBox(ifString(IsDemoFix(), "", "- Real Account -\n\n") + msg, ProgramName(), MB_ICONQUESTION|MB_OKCANCEL);
   if (button != IDOK) return(catch("onStart(2)"));

   // hedge positions
   int oes[][ORDER_EXECUTION_intSize];

   if (!OrdersHedge(tickets, 10, F_OE_HEDGE_NO_CLOSE, oes)) {     // 10 points acceptable slippage
      int error = oes.Error(oes, 0);
      if (!error) {
         PlaySoundEx("Plonk.wav");
         MessageBox("The total position is already flat.", ProgramName(), MB_ICONEXCLAMATION|MB_OK);
      }
      else {
         return(SetLastError(error));
      }
   }
   return(catch("onStart(3)"));
}
