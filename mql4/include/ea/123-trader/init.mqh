/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (IsLastError()) return(last_error);

   switch (ProgramInitReason()) {
      case IR_USER:
      case IR_TEMPLATE:
      case IR_RECOMPILE:
         // find and select an open position
         int orders = OrdersTotal();
         for (int i=0; i < orders; i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;     // FALSE: an open order was closed/deleted in another thread
            if (OrderType() > OP_SELL || OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
            if (open.ticket > 0) return(catch("onInit(1)  illegal second position detected: #"+ OrderTicket(), ERR_ILLEGAL_STATE));
            open.ticket     = OrderTicket();
            open.type       = OrderType();
            open.lots       = OrderLots();
            open.price      = OrderOpenPrice();
            open.stoploss   = OrderStopLoss();
            open.takeprofit = OrderTakeProfit();
         }

         // pre-calculate partial profit sizes
         int closedPercent  = Target1.ClosePercent;
         double t1Close     = MathMin(Lots, NormalizeLots(Lots * closedPercent/100));
         double t1Remainder = NormalizeDouble(Lots - t1Close, 2);

         closedPercent     += Target2.ClosePercent;
         double t2Close     = MathMin(t1Remainder, NormalizeLots(Lots * closedPercent/100 - t1Close));
         double t2Remainder = NormalizeDouble(t1Remainder - t2Close, 2);

         closedPercent     += Target3.ClosePercent;
         double t3Close     = MathMin(t2Remainder, NormalizeLots(Lots * closedPercent/100 - t1Close - t2Close));
         double t3Remainder = NormalizeDouble(t2Remainder - t3Close, 2);

         closedPercent     += Target4.ClosePercent;
         double t4Close     = MathMin(t3Remainder, NormalizeLots(Lots * closedPercent/100 - t1Close - t2Close - t3Close));
         double t4Remainder = NormalizeDouble(t3Remainder - t4Close, 2);

         // convert target configuration to array (optimizes processing)
         targets[0][T_LEVEL    ] = Target1;
         targets[0][T_CLOSE_PCT] = Target1.ClosePercent;
         targets[0][T_REMAINDER] = t1Remainder;
         targets[0][T_MOVE_STOP] = Target1.MoveStopTo;

         targets[1][T_LEVEL    ] = Target2;
         targets[1][T_CLOSE_PCT] = Target2.ClosePercent;
         targets[1][T_REMAINDER] = t2Remainder;
         targets[1][T_MOVE_STOP] = Target2.MoveStopTo;

         targets[2][T_LEVEL    ] = Target3;
         targets[2][T_CLOSE_PCT] = Target3.ClosePercent;
         targets[2][T_REMAINDER] = t3Remainder;
         targets[2][T_MOVE_STOP] = Target3.MoveStopTo;

         targets[3][T_LEVEL    ] = Target4;
         targets[3][T_CLOSE_PCT] = Target4.ClosePercent;
         targets[3][T_REMAINDER] = t4Remainder;
         targets[3][T_MOVE_STOP] = Target4.MoveStopTo;
         break;
   }
   return(catch("onInit(2)"));
}
