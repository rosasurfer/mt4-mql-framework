
/**
 * Initialization pre-processing hook.
 *
 * @return int - error status; in case of errors scenario-specific event handlers are not executed
 */
int onInit() {
   return(NO_ERROR);
}


/**
 * Called after the expert was manually loaded by the user via the input dialog.
 * Also in Tester with both VisualMode=On|Off.
 *
 * @return int - error status
 */
int onInit_User() {
   if (__STATUS_OFF)
      return(NO_ERROR);

   // look for a running sequence
   // if sequence found:
   // - ask whether or not to manage the running sequence
   // - if yes: validate input in the context of the running sequence
   //   - overwrite Lots.StartSize, Start.Direction
   //
   // if no sequence found:
   // - validate input as a new sequence


   // validate input parameters
   // Start.Direction
   string value, elems[];
   if (Explode(Start.Direction, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      value = elems[size-1];
   }
   else value = Start.Direction;
   value = StringToLower(StringTrim(value));

   if      (value=="l" || value=="long" )             Start.Direction = "long";
   else if (value=="s" || value=="short")             Start.Direction = "short";
   else if (value=="a" || value=="auto" || value=="") Start.Direction = "auto";
   else return(catch("onInit_User(1)  Invalid input parameter Start.Direction = "+ DoubleQuoteStr(Start.Direction), ERR_INVALID_INPUT_PARAMETER));

   if (Start.Direction == "auto") {
      if (!IsTesting() && (InitReason()==IR_USER || InitReason()==IR_PARAMETERS)) {
         PlaySoundEx("Windows Notify.wav");
         int button = MessageBoxEx(__NAME__, ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you really want to start the chicken in headless mode?", MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK) return(SetLastError(ERR_CANCELLED_BY_USER));
      }
   }
   //grid.timeframe    = Period();
   grid.startDirection = Start.Direction;


   // read open positions and data
   int    lastTicket, orders=OrdersTotal();
   double profit;
   string lastComment = "";

   for (int i=0; i < orders; i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber) {
         if (OrderType() == OP_BUY) {
            if (position.level < 0) return(catch("onInit_User(2)  found open long and short positions", ERR_ILLEGAL_STATE));
            position.level++;
         }
         else if (OrderType() == OP_SELL) {
            if (position.level > 0) return(catch("onInit_User(3)  found open long and short positions", ERR_ILLEGAL_STATE));
            position.level--;
         }
         else continue;

         ArrayPushInt   (position.tickets,    OrderTicket());
         ArrayPushDouble(position.lots,       OrderLots());
         ArrayPushDouble(position.openPrices, OrderOpenPrice());
         profit += OrderProfit();

         if (OrderTicket() > lastTicket) {
            lastTicket  = OrderTicket();
            lastComment = OrderComment();
         }
      }
   }
   grid.level = Abs(position.level);


   // restoring grid.minSize from order comments is a last resort
   if (!grid.minSize) {
      if (!Grid.Contractable && StringLen(lastComment)) {      // comments can be changed by the broker
         lastComment = StringRightFrom(lastComment, "-", 2);   // "ExpertName-10-2.0" => "2.0"
         if (StringLen(lastComment) > 0)                       // positions at level 1 don't have a grid size in the comment
            grid.minSize = StrToDouble(lastComment);
      }
      grid.minSize = MathMax(grid.minSize, Grid.Min.Pips);
   }


   // update Lots.StartSize and exit conditions
   UpdateTotalPosition();
   if (!position.maxDrawdown) {
      double startEquity   = NormalizeDouble(AccountEquity() - AccountCredit() - profit, 2);
      position.maxDrawdown = NormalizeDouble(startEquity * StopLoss.Percent/100, 2);
   }
   if (grid.level > 0) {
      double maxDrawdownPips   = position.maxDrawdown/PipValue(position.totalSize);
      position.slPrice         = NormalizeDouble(position.totalPrice - Sign(position.level) * maxDrawdownPips          *Pips, Digits);
      str.position.slPrice     = NumberToStr(position.slPrice, SubPipPriceFormat);
      position.trailLimitPrice = NormalizeDouble(position.totalPrice + Sign(position.level) * Exit.Trail.MinProfit.Pips*Pips, Digits);
   }
   useTrailingStop = Exit.Trail.Pips > 0;

   return(catch("onInit_User(4)"));
}


/**
 * Called after the expert was loaded by a chart template. Also at terminal start. No input dialog.
 *
 * @return int - error status
 */
int onInit_Template() {
   if (__STATUS_OFF)
      return(NO_ERROR);
   RestoreRuntimeStatus();
   return(onInit_User());
}


/**
 * Called after the input parameters were changed via the input dialog.
 *
 * @return int - error status
 */
int onInit_Parameters() {
   if (__STATUS_OFF)
      return(NO_ERROR);
   return(catch("onInit_Parameters(1)  input parameter changes not yet supported", ERR_NOT_IMPLEMENTED));
}


/**
 * Called after the current chart period has changed. No input dialog.
 *
 * @return int - error status
 */
int onInit_TimeframeChange() {
   if (__STATUS_OFF)
      return(NO_ERROR);
   return(NO_ERROR);
}


/**
 * Called after the current chart symbol has changed. No input dialog.
 *
 * @return int - error status
 */
int onInit_SymbolChange() {
   if (__STATUS_OFF)
      return(NO_ERROR);
   // must never happen
   catch("onInit_SymbolChange(1)  unsupported symbol change", ERR_ILLEGAL_STATE);
   return(-1);                // hard stop
}


/**
 * Called after the expert was recompiled. No input dialog.
 *
 * @return int - error status
 */
int onInit_Recompile() {
   if (__STATUS_OFF)
      return(NO_ERROR);
   RestoreRuntimeStatus();
   return(onInit_User());
}


/**
 * Initialization post-processing hook. Executed only if neither the pre-processing hook nor the scenario-specific event
 * handlers returned with -1 (which is a hard stop as opposite to a regular error).
 *
 * @return int - error status
 */
int afterInit() {
   return(NO_ERROR);
}
