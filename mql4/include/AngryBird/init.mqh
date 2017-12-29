
/**
 * Initialization pre-processing hook.
 *
 * @return int - error status; in case of errors reason-specific event handlers are not executed
 */
int onInit() {
   // try to catch the terminal init bug (build 1065)
   if (Lots.StartVola.Percent==30 || Start.Direction=="Long | Short | Auto*") {
      string message = "onInit(1)  UninitializeReason="+ UninitReasonToStr(UninitializeReason()) +"  InitReason="+ InitReasonToStr(InitReason()) +"  Lots.StartVola.Percent="+ Lots.StartVola.Percent +"  Start.Direction="+ DoubleQuoteStr(Start.Direction);
      log(message);

      // use the Win32 API directly as MQL functions might not work at all
      PlaySoundEx("Siren.wav");
      string caption = __NAME__ +" "+ Symbol() +","+ PeriodDescription(Period());
      int    button  = MessageBoxA(GetApplicationWindow(), message, caption, MB_TOPMOST|MB_SETFOREGROUND|MB_ICONERROR|MB_OKCANCEL);
      if (button != IDOK) return(SetLastError(ERR_RUNTIME_ERROR));
   }
   return(last_error);
}


/**
 * Called after the expert was manually loaded by the user via the input dialog. Also in Tester with both
 * VisualMode=On|Off. All program properties are in their initial state.
 *
 * @return int - error status
 */
int onInit_User() {
   if (__STATUS_OFF)
      return(NO_ERROR);

   // look for a running sequence
   if (IsOpenPosition()) {
      RestoreRuntimeStatus();                   // on IR_USER there will be rarely data
      ReadOpenPositions();                      // TODO: make sure if data was restored it belongs to the open positions (Sequence-ID)
      // TODO: overwrite input parameters in RestoreRuntimeStatus()
      status = STATUS_PROGRESSING;
   }
   else {
      // no sequence found

      //   look for stored runtime data
      //   1. stored runtime data found
      //      ask whether or not to restore the stored sequence
      //      - yes: restore sequence status (status can be anything)
      //      - no:  delete stored runtime data, continue at 1.2
      //
      //   2. no stored runtime data found
      //      validate input in context of a new sequence
      //      result: STATUS_PENDING | STATUS_STARTING
   }




   // string Start.Mode = "Long | Short | Headless | Legless | Auto"
   // long        STATUS_STARTING, immediate Long trade
   // short       STATUS_STARTING, immediate Short trade
   // headless    STATUS_STARTING, trade any direction at next BarOpen
   // legless     STATUS_PENDING;  wait
   // auto


   // validate input parameters
   // Start.Direction
   string value, elems[];
   if (Explode(Start.Mode, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      value = elems[size-1];
   }
   else value = Start.Mode;
   value = StringToLower(StringTrim(value));

   if      (value=="l" || value=="long" )             Start.Mode = "long";
   else if (value=="s" || value=="short")             Start.Mode = "short";
   else if (value=="a" || value=="auto" || value=="") Start.Mode = "auto";
   else return(catch("onInit_User(1)  Invalid input parameter Start.Mode = "+ DoubleQuoteStr(Start.Mode), ERR_INVALID_INPUT_PARAMETER));

   if (Start.Mode == "auto") {
      if (!IsTesting() && (InitReason()==IR_USER || InitReason()==IR_PARAMETERS)) {
         PlaySoundEx("Windows Notify.wav");
         int button = MessageBoxEx(__NAME__, ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you really want to start the chicken in headless mode?", MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK) return(SetLastError(ERR_CANCELLED_BY_USER));
      }
   }
   //grid.timeframe    = Period();
   grid.startDirection = Start.Mode;
   SetPositionTpPip(TakeProfit.Pips);


   // read open positions and data
   int    lastTicket, orders = OrdersTotal();
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
   if  (position.level != 0) grid.level = Abs(position.level);
   else if (grid.level != 0) ResetRuntimeStatus(REASON_TAKEPROFIT);  // grid.level was restored and positions are already closed
   if (__STATUS_OFF)
      return(__STATUS_OFF.reason);


   // restore grid.minSize from order comments (only way to automatically transfer it between terminals)
   if (!grid.minSize) {
      double minSize;
      if (!Grid.Contractable && StringLen(lastComment)) {
         string gridSize = StringRightFrom(lastComment, "-", 2);     // "ExpertName-10-2.0" => "2.0"
         if (!StringIsNumeric(gridSize))
            return(catch("onInit_User(4)  grid size not found in order comment "+ DoubleQuoteStr(lastComment), ERR_RUNTIME_ERROR));
         minSize = StrToDouble(gridSize);
      }
      SetGridMinSize(MathMax(minSize, Grid.Min.Pips));
   }
   UpdateTotalPosition();


   // update exit conditions
   if (grid.level > 0) {
      if (!position.startEquity)
         position.startEquity = NormalizeDouble(AccountEquity() - AccountCredit() - profit, 2);
      if (!position.maxDrawdown)
         position.maxDrawdown = NormalizeDouble(position.startEquity * StopLoss.Percent/100, 2);

      double maxDrawdownPips = position.maxDrawdown / PipValue(position.totalSize);
      SetPositionSlPrice(    NormalizeDouble(position.totalPrice - Sign(position.level) * maxDrawdownPips          *Pips, Digits));
      exit.trailLimitPrice = NormalizeDouble(position.totalPrice + Sign(position.level) * Exit.Trail.MinProfit.Pips*Pips, Digits);
   }
   exit.trailStop = Exit.Trail.Pips > 0;

   return(catch("onInit_User(5)"));
}


/**
 * Called after the expert was loaded by a chart template. Also at terminal start. No input dialog.
 *
 * @return int - error status
 */
int onInit_Template() {
   if (__STATUS_OFF)
      return(NO_ERROR);

   // status options at leave
   // -----------------------
   // STATUS_PENDING
   // STATUS_STARTING
   // STATUS_PROGRESSING
   // STATUS_STOPPING
   // STATUS_STOPPED

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

   // status options at leave
   // -----------------------
   // STATUS_PENDING
   // STATUS_STARTING
   // STATUS_PROGRESSING
   // STATUS_STOPPED

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

   // status options at leave
   // -----------------------
   // unverändert

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

   // status options at leave
   // -----------------------
   // unverändert

   catch("onInit_SymbolChange(1)  unsupported symbol change", ERR_ILLEGAL_STATE);
   return(-1);                // hard stop (must never happen)
}


/**
 * Called after the expert was recompiled. No input dialog.
 *
 * @return int - error status
 */
int onInit_Recompile() {
   if (__STATUS_OFF)
      return(NO_ERROR);

   // status options at leave
   // -----------------------
   // STATUS_PENDING
   // STATUS_STARTING
   // STATUS_PROGRESSING
   // STATUS_STOPPING
   // STATUS_STOPPED

   RestoreRuntimeStatus();
   return(onInit_User());
}


/**
 * Initialization post-processing hook. Executed only if neither the pre-processing hook nor the reason-specific event
 * handlers returned with -1 (which is a hard stop as opposite to a regular error).
 *
 * @return int - error status
 */
int afterInit() {
   return(NO_ERROR);
}


/**
 * Whether or not there are currently open positions.
 *
 * @return bool
 */
bool IsOpenPosition() {
   int orders = OrdersTotal();

   for (int i=0; i < orders; i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);

      if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber)
         return(true);
   }
   return(false);
}


/**
 * Read the existing open positions and update grid.level and position.level accordingly.
 *
 * @return int - the grid level of the found open positions or -1 in case of errors
 */
int ReadOpenPositions() {
   grid.level     = 0;
   position.level = 0;

   ArrayResize(position.tickets,    0);
   ArrayResize(position.lots,       0);
   ArrayResize(position.openPrices, 0);

   int    orders = OrdersTotal();
   double profit;

   // read open positions and data
   for (int i=0; i < orders; i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);

      if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber) {
         if (OrderType() == OP_BUY) {
            if (position.level < 0) return(_EMPTY(catch("ReadOpenPositions(1)  found both open long and short positions", ERR_ILLEGAL_STATE)));
            position.level++;
         }
         else if (OrderType() == OP_SELL) {
            if (position.level > 0) return(_EMPTY(catch("ReadOpenPositions(2)  found both open long and short positions", ERR_ILLEGAL_STATE)));
            position.level--;
         }
         else                       return(_EMPTY(catch("ReadOpenPositions(3)  found unexpected position type: "+ OperationTypeToStr(OrderType()), ERR_ILLEGAL_STATE)));

         ArrayPushInt   (position.tickets,    OrderTicket()   );
         ArrayPushDouble(position.lots,       OrderLots()     );
         ArrayPushDouble(position.openPrices, OrderOpenPrice());
         profit += OrderProfit();
      }
   }
   grid.level = ArraySize(position.tickets);

   // restore grid.minSize from order comments (only way to automatically transfer it between terminals)
   if (grid.level && !Grid.Contractable) /*&&*/ if (StringLen(OrderComment()) > 0) {
      string gridSize = StringRightFrom(OrderComment(), "-", 2);     // "ExpertName-10-2.0" => "2.0"
      if (!StringIsNumeric(gridSize))
         return(catch("ReadOpenPositions(4)  grid size not found in order comment "+ DoubleQuoteStr(OrderComment()), ERR_RUNTIME_ERROR));
      SetGridMinSize(MathMax(grid.minSize, StrToDouble(gridSize)));
   }
   UpdateTotalPosition();

   // update exit conditions
   if (grid.level > 0) {
      if (!position.startEquity)
         position.startEquity = NormalizeDouble(AccountEquity() - AccountCredit() - profit, 2);
      if (!position.maxDrawdown)
         position.maxDrawdown = NormalizeDouble(position.startEquity * StopLoss.Percent/100, 2);

      double maxDrawdownPips = position.maxDrawdown / PipValue(position.totalSize);
      SetPositionSlPrice(    NormalizeDouble(position.totalPrice - Sign(position.level) * maxDrawdownPips          *Pips, Digits));
      exit.trailLimitPrice = NormalizeDouble(position.totalPrice + Sign(position.level) * Exit.Trail.MinProfit.Pips*Pips, Digits);
   }
   exit.trailStop = Exit.Trail.Pips > 0;

   return(grid.level);
}
