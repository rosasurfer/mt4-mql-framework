
/**
 * Initialization pre-processing hook.
 *
 * @return int - error status; in case of errors reason-specific event handlers are not executed
 */
int onInit() {
   string message = "UninitReason="+ UninitReasonToStr(UninitializeReason()) +"  InitReason="+ InitReasonToStr(InitReason()) +"  Window="+ WindowOnDropped() +"  X="+ WindowXOnDropped() +"  Y="+ WindowYOnDropped() +"  ThreadID="+ GetCurrentThreadId() +" ("+ ifString(IsUIThread(), "GUI thread", "non-GUI thread") +")";
   log("onInit(1)  "+ message);

   // catch terminal bug #1 (https://github.com/rosasurfer/mt4-mql/issues/1)
   if (____________________________=="" && WindowXOnDropped()==-1 && WindowYOnDropped()==-1) {
      // use the Win32 API directly as MQL functions might not work
      PlaySoundEx("Siren.wav");
      string caption = __NAME__ +" "+ Symbol() +","+ PeriodDescription(Period());
      int    button  = MessageBoxA(GetApplicationWindow(), "onInit(2)  "+ message, caption, MB_TOPMOST|MB_SETFOREGROUND|MB_ICONERROR|MB_OKCANCEL);
      if (button != IDOK) return(SetLastError(ERR_RUNTIME_ERROR));
   }
   return(last_error);
}


/**
 * Called after the expert was manually loaded by the user via the input dialog. Also in Tester with both VisualMode=On|Off.
 *
 * @return int - error status
 */
int onInit_User() {
   if (__STATUS_OFF)
      return(NO_ERROR);
   ResetRuntimeStatus();                                 // needed if init() is called multiple times
                                                         // (ERS_TERMINAL_NOT_YET_READY or terminal bug #1)
   int sequenceId = FindStartedSequence();
   if (sequenceId < 0) return(last_error);

   if (!sequenceId) {
      // no sequence found
      ResetStoredStatus();
      ValidateConfig(); if (__STATUS_OFF) return(last_error);

      // init new sequence
      chicken.mode = StringToLower(Start.Mode);
         string validModes[] = {"long", "short", "headless", "legless"};
         if (!StringInArray(validModes, chicken.mode)) return(catch("onInit_User(1)  Illegal value of variable chicken.mode: "+ DoubleQuoteStr(chicken.mode), ERR_ILLEGAL_STATE));
      chicken.status      = ifInt   (chicken.mode=="legless", STATUS_PENDING, STATUS_STARTING);
      grid.startDirection = ifString(chicken.mode=="legless" || chicken.mode=="headless", "auto", chicken.mode);
      SetGridMinSize  (Grid.Min.Pips);
      SetPositionTpPip(TakeProfit.Pips);
      exit.trailStop = Exit.Trail.Pips > 0;

      // confirm a headless chicken
      if (chicken.mode == "headless")
         if (!ConfirmHeadlessChicken())       return(SetLastError(ERR_CANCELLED_BY_USER));
   }

   else {
      // already started sequence found
      if (!ConfirmManageSequence(sequenceId)) return(SetLastError(ERR_CANCELLED_BY_USER));
      RestoreRuntimeStatus(sequenceId);
      ReadOpenPositions();                               // read/synchronize positions with restored runtime data



      // Input-Parameter abgleichen: u.U. muß RestoreRuntimeStatus() gespeicherte Input-Params in tmp-Variablen zwischenspeichern
      // falls Input-Parameter von Sequenz abweichen, Bestätigung einholen
   }
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

   if (!IsStoredRuntimeStatus()) {
      catch("onInit_Template(1)  no stored runtime status found", ERR_ILLEGAL_STATE);
      return(-1);                         // hard error
   }

   RestoreRuntimeStatus();                // STATUS_PENDING | STATUS_PROGRESSING | STATUS_STOPPED
   SyncRuntimeStatus();                   // Status mit tatsächlichem Status abgleichen (Sequenz ist evt. bereits gestoppt)
   return(last_error);                    // STATUS_PENDING     => STATUS_PROGRESSING
}                                         // STATUS_PENDING     => STATUS_STOPPED
                                          // STATUS_PROGRESSING => STATUS_STOPPED

/**
 * Called after the input parameters were changed via the input dialog.
 *
 * @return int - error status
 */
int onInit_Parameters() {
   if (__STATUS_OFF)
      return(NO_ERROR);
   catch("onInit_Parameters(1)  input parameter changes not yet supported", ERR_NOT_IMPLEMENTED);
   return(-1);                            // at the moment hard error
}


/**
 * Called after the current chart symbol has changed. No input dialog.
 *
 * @return int - error status
 */
int onInit_SymbolChange() {
   if (__STATUS_OFF)
      return(NO_ERROR);
   catch("onInit_SymbolChange(1)  unsupported symbol change", ERR_ILLEGAL_STATE);
   return(-1);                            // hard stop (must never happen)
}


/**
 * Called after the expert was recompiled. No input dialog.
 *
 * @return int - error status
 */
int onInit_Recompile() {
   if (__STATUS_OFF)
      return(NO_ERROR);

   // temporarily skip onInit_Template()
   return(onInit_User());

   return(onInit_Template());
}


/**
 * Validate the input parameters.
 *
 * @return bool - validation success status
 */
bool ValidateConfig() {
   if (__STATUS_OFF)
      return(false);

   // Start.Mode
   string elems[], sValue = StringToLower(Start.Mode);
   if (Explode(sValue, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      sValue = elems[size-1];
   }
   sValue = StringTrim(sValue);
   if      (StringStartsWith("long",     sValue) && StringLen(sValue) > 1) Start.Mode = "long";
   else if (StringStartsWith("short",    sValue))                          Start.Mode = "short";
   else if (StringStartsWith("headless", sValue))                          Start.Mode = "headless";
   else if (StringStartsWith("legless",  sValue) && StringLen(sValue) > 1) Start.Mode = "legless";
   else if (StringStartsWith("auto",     sValue))                          Start.Mode = "auto";
   else                                                return(catch("ValidateConfig(1)  Invalid input parameter Start.Mode = "+ DoubleQuoteStr(Start.Mode), ERR_INVALID_INPUT_PARAMETER));

   // Lots.StartSize
   if (Lots.StartSize < 0)                             return(catch("ValidateConfig(2)  Invalid input parameter Lots.StartSize = "+ NumberToStr(Lots.StartSize, ".1+"), ERR_INVALID_INPUT_PARAMETER));

   // Lots.StartVola.Percent
   if (Lots.StartVola.Percent < 0)                     return(catch("ValidateConfig(3)  Invalid input parameter Lots.StartVola.Percent = "+ Lots.StartVola.Percent, ERR_INVALID_INPUT_PARAMETER));

   // Lots.Multiplier
   if (Lots.Multiplier <= 0)                           return(catch("ValidateConfig(4)  Invalid input parameter Lots.Multiplier = "+ NumberToStr(Lots.Multiplier, ".1+"), ERR_INVALID_INPUT_PARAMETER));

   // TakeProfit.Pips
   if (TakeProfit.Pips <= 0)                           return(catch("ValidateConfig(5)  Invalid input parameter TakeProfit.Pips = "+ NumberToStr(TakeProfit.Pips, ".1+"), ERR_INVALID_INPUT_PARAMETER));
   if (MathModFix(TakeProfit.Pips, 0.1) != 0)          return(catch("ValidateConfig(6)  Invalid input parameter TakeProfit.Pips = "+ NumberToStr(TakeProfit.Pips, ".1+") +" (not a subpip multiple)", ERR_INVALID_INPUT_PARAMETER));

   // StopLoss.Percent
   if (StopLoss.Percent <=   0)                        return(catch("ValidateConfig(7)  Invalid input parameter StopLoss.Percent = "+ StopLoss.Percent, ERR_INVALID_INPUT_PARAMETER));
   if (StopLoss.Percent >= 100)                        return(catch("ValidateConfig(8)  Invalid input parameter StopLoss.Percent = "+ StopLoss.Percent, ERR_INVALID_INPUT_PARAMETER));

   // Grid.Min.Pips
   if (Grid.Min.Pips <= 0)                             return(catch("ValidateConfig(9)  Invalid input parameter Grid.Min.Pips = "+ NumberToStr(Grid.Min.Pips, ".1+"), ERR_INVALID_INPUT_PARAMETER));
   if (MathModFix(Grid.Min.Pips, 0.1) != 0)            return(catch("ValidateConfig(10)  Invalid input parameter Grid.Min.Pips = "+ NumberToStr(Grid.Min.Pips, ".1+") +" (not a subpip multiple)", ERR_INVALID_INPUT_PARAMETER));

   // Grid.Max.Pips
   if (Grid.Max.Pips < 0)                              return(catch("ValidateConfig(11)  Invalid input parameter Grid.Max.Pips = "+ NumberToStr(Grid.Max.Pips, ".1+"), ERR_INVALID_INPUT_PARAMETER));
   if (MathModFix(Grid.Max.Pips, 0.1) != 0)            return(catch("ValidateConfig(12)  Invalid input parameter Grid.Max.Pips = "+ NumberToStr(Grid.Max.Pips, ".1+") +" (not a subpip multiple)", ERR_INVALID_INPUT_PARAMETER));
   if (Grid.Max.Pips && Grid.Max.Pips > Grid.Max.Pips) return(catch("ValidateConfig(13)  Invalid input parameters Grid.Min.Pips / Grid.Max.Pips = "+ NumberToStr(Grid.Max.Pips, ".1+") +" / "+ NumberToStr(Grid.Max.Pips, ".1+") +" (mis-match)", ERR_INVALID_INPUT_PARAMETER));

   // Grid.Lookback.Periods
   if (Grid.Lookback.Periods < 1)                      return(catch("ValidateConfig(14)  Invalid input parameter Grid.Lookback.Periods = "+ Grid.Lookback.Periods, ERR_INVALID_INPUT_PARAMETER));

   // Grid.Lookback.Divider
   if (Grid.Lookback.Divider < 1)                      return(catch("ValidateConfig(15)  Invalid input parameter Grid.Lookback.Divider = "+ Grid.Lookback.Divider, ERR_INVALID_INPUT_PARAMETER));

   // Exit.Trail.Pips
   if (Exit.Trail.Pips < 0)                            return(catch("ValidateConfig(16)  Invalid input parameter Exit.Trail.Pips = "+ NumberToStr(Exit.Trail.Pips, ".1+"), ERR_INVALID_INPUT_PARAMETER));
   if (MathModFix(Exit.Trail.Pips, 0.1) != 0)          return(catch("ValidateConfig(17)  Invalid input parameter Exit.Trail.Pips = "+ NumberToStr(Exit.Trail.Pips, ".1+") +" (not a subpip multiple)", ERR_INVALID_INPUT_PARAMETER));

   // Exit.Trail.Start.Pips
   if (Exit.Trail.Start.Pips < 0)                      return(catch("ValidateConfig(18)  Invalid input parameter Exit.Trail.Start.Pips = "+ NumberToStr(Exit.Trail.Start.Pips, ".1+"), ERR_INVALID_INPUT_PARAMETER));
   if (MathModFix(Exit.Trail.Start.Pips, 0.1) != 0)    return(catch("ValidateConfig(19)  Invalid input parameter Exit.Trail.Start.Pips = "+ NumberToStr(Exit.Trail.Start.Pips, ".1+") +" (not a subpip multiple)", ERR_INVALID_INPUT_PARAMETER));
}


/**
 * Find a started sequence and return its id.
 *
 * @return int - sequence id or NULL if no started sequence was found;
 *               -1 in case of errors
 */
int FindStartedSequence() {
   int id, orders = OrdersTotal();

   for (int i=0; i < orders; i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==os.magicNumber) {
         id = OrderTicket();                          // the first found order is always the one from level 1
         break;
      }
   }

   if (!catch("FindStartedSequence(1)"))
      return(id);
   return(-1);
}


/**
 * Read the existing open positions and update the internal variables accordingly.
 *
 * @return int - the current grid level of the progressing sequence or -1 in case of errors
 */
int ReadOpenPositions() {
   position.level = 0;

   ArrayResize(position.tickets,    0);
   ArrayResize(position.lots,       0);
   ArrayResize(position.openPrices, 0);

   int    orders = OrdersTotal();
   double profit;
   string comment;

   // read open positions
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
         comment = OrderComment();
      }
   }

   // synchronize grid.level (may have been restored from the chart and differ)
   if  (position.level != 0) grid.level = Abs(position.level);
   else if (grid.level != 0) {                                                   // grid.level was set but all positions are already closed
      __STATUS_OFF        = true;
      __STATUS_OFF.reason = ERR_CANCELLED_BY_USER;
      return(-1);
   }

   // synchronize grid.minSize using the last order (only way to automatically transfer it between terminals)
   if (grid.level && !Grid.Contractable) /*&&*/ if (StringLen(comment) > 0) {    // TODO: Grid.Contractable already needs to be validated
      string sValue = StringRightFrom(comment, "-", 2);                          // "ExpertName-10-2.0" => "2.0"
      if (!StringIsNumeric(sValue))
         return(_EMPTY(catch("ReadOpenPositions(4)  no grid size found in order comment "+ DoubleQuoteStr(comment), ERR_RUNTIME_ERROR)));
      double dValue = StrToDouble(sValue);
      SetGridMinSize(MathMax(MathMax(dValue, grid.minSize), Grid.Min.Pips));     // TODO: Grid.Min.Pips already needs to be validated
   }

   // synchronize position.size and position.avgPrice
   UpdateTotalPosition();

   // synchronize exit conditions: position.startEquity, position.maxDrawdown, position.slPrice, exit.trail*
   if (grid.level > 0) {
      if (!position.startEquity)
         position.startEquity = NormalizeDouble(AccountEquity() - AccountCredit() - profit, 2);
      if (!position.maxDrawdown)
         position.maxDrawdown = NormalizeDouble(position.startEquity * StopLoss.Percent/100, 2);

      double drawdownPips  = position.maxDrawdown / PipValue(position.size);
      SetPositionSlPrice(    NormalizeDouble(position.avgPrice - Sign(position.level) *          drawdownPips*Pips, Digits));
      exit.trailLimitPrice = NormalizeDouble(position.avgPrice + Sign(position.level) * Exit.Trail.Start.Pips*Pips, Digits);
   }
   exit.trailStop = Exit.Trail.Pips > 0;

   return(grid.level);
}


/**
 * Whether or not a sequence's runtime status was found in chart.
 *
 * @return bool
 */
bool IsStoredRuntimeStatus() {
   return(ObjectFind(__NAME__ + ".id") == 0);
}


/**
 * Restore stored runtime status from the chart to continue a sequence after recompilation, terminal re-start or profile
 * change. If a sequence id is specified status is restored only for that specific sequence. Otherwise any found sequence
 * status is restored.
 *
 * @param  int sequenceId [optional] - sequence to restore (default: anyone found)
 *
 * @return bool - whether or not runtime data was found and successfully restored
 */
bool RestoreRuntimeStatus(int sequenceId = INT_MAX) {
   if (__STATUS_OFF)   return(false);
   if (sequenceId < 0) return(!catch("RestoreRuntimeStatus(1)  invalid parameter sequenceId = "+ sequenceId, ERR_INVALID_PARAMETER));

   // sequence id
   string label = __NAME__ + ".id";
   if (ObjectFind(label) != 0)
      return(false);                                                       // no stored data found

   if (sequenceId!=INT_MAX && ObjectDescription(label)!=""+sequenceId)
      return(false);                                                       // skip non-matching sequence data


   // runtime status
   label = __NAME__ + ".runtime.__STATUS_INVALID_INPUT";
   if (ObjectFind(label) == 0) {
      string sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreRuntimeStatus(2)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      __STATUS_INVALID_INPUT = StrToInteger(sValue) != 0;                  // (bool)(int) string
   }

   label = __NAME__ +".runtime.__STATUS_OFF";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreRuntimeStatus(3)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      __STATUS_OFF = StrToInteger(sValue) != 0;                            // (bool)(int) string
   }

   label = __NAME__ +".runtime.__STATUS_OFF.reason";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreRuntimeStatus(4)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      __STATUS_OFF.reason = StrToInteger(sValue);                          // (int) string
   }

   label = __NAME__ +".runtime.lots.calculatedSize";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(5)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      double dValue = StrToDouble(sValue);
      if (LT(dValue, 0))            return(!catch("RestoreRuntimeStatus(6)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      lots.calculatedSize = dValue;                                        // (double) string
   }

   label = __NAME__ +".runtime.lots.startSize";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(7)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      if (LT(dValue, 0))            return(!catch("RestoreRuntimeStatus(8)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      SetLotsStartSize(NormalizeDouble(dValue, 2));                        // (double) string
   }

   label = __NAME__ +".runtime.lots.startVola";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreRuntimeStatus(9)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      lots.startVola = StrToInteger(sValue);                               // (int) string
   }

   label = __NAME__ +".runtime.grid.level";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreRuntimeStatus(10)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      grid.level = StrToInteger(sValue);                                   // (int) string
   }

   label = __NAME__ +".runtime.grid.minSize";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(11)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      if (LT(dValue, 0))            return(!catch("RestoreRuntimeStatus(12)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      SetGridMinSize(NormalizeDouble(dValue, 1));                          // (double) string
   }

   label = __NAME__ +".runtime.grid.marketSize";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(13)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      if (LT(dValue, 0))            return(!catch("RestoreRuntimeStatus(14)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      SetGridMarketSize(NormalizeDouble(dValue, 1));                       // (double) string
   }

   label = __NAME__ +".runtime.position.startEquity";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(15)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      if (LT(dValue, 0))            return(!catch("RestoreRuntimeStatus(16)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      position.startEquity = NormalizeDouble(dValue, 2);                   // (double) string
   }

   label = __NAME__ +".runtime.position.maxDrawdown";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(17)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      if (LT(dValue, 0))            return(!catch("RestoreRuntimeStatus(18)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      position.maxDrawdown = NormalizeDouble(dValue, 2);                   // (double) string
   }

   label = __NAME__ +".runtime.position.slPrice";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(19)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      if (LT(dValue, 0))            return(!catch("RestoreRuntimeStatus(20)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      SetPositionSlPrice(NormalizeDouble(dValue, Digits));                 // (double) string
   }

   label = __NAME__ +".runtime.position.plPip";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(21)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlPip(NormalizeDouble(dValue, 1));                        // (double) string
   }

   label = __NAME__ +".runtime.position.plPipMin";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(22)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlPipMin(NormalizeDouble(dValue, 1));                     // (double) string
   }

   label = __NAME__ +".runtime.position.plPipMax";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(23)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlPipMax(NormalizeDouble(dValue, 1));                     // (double) string
   }

   label = __NAME__ +".runtime.position.plUPip";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(24)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlUPip(NormalizeDouble(dValue, 1));                       // (double) string
   }

   label = __NAME__ +".runtime.position.plUPipMin";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(25)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlUPipMin(NormalizeDouble(dValue, 1));                    // (double) string
   }

   label = __NAME__ +".runtime.position.plUPipMax";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(26)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlUPipMax(NormalizeDouble(dValue, 1));                    // (double) string
   }

   label = __NAME__ +".runtime.position.plPct";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(27)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlPct(NormalizeDouble(dValue, 2));                        // (double) string
   }

   label = __NAME__ +".runtime.position.plPctMin";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(28)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlPctMin(NormalizeDouble(dValue, 2));                     // (double) string
   }

   label = __NAME__ +".runtime.position.plPctMax";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsNumeric(sValue)) return(!catch("RestoreRuntimeStatus(29)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      dValue = StrToDouble(sValue);
      SetPositionPlPctMax(NormalizeDouble(dValue, 2));                     // (double) string
   }

   return(!catch("RestoreRuntimeStatus(30)"));
}


/**
 * Reset all status variables stored in the chart.
 *
 * @return bool - success status
 */
bool ResetStoredStatus() {
   // sequence id
   Chart.DeleteValue(__NAME__ +".id");

   // input parameters
   Chart.DeleteValue(__NAME__ +".input.Start.Mode"               );
   Chart.DeleteValue(__NAME__ +".input.Lots.StartSize"           );
   Chart.DeleteValue(__NAME__ +".input.Lots.StartVola.Percent"   );
   Chart.DeleteValue(__NAME__ +".input.Lots.Multiplier"          );
   Chart.DeleteValue(__NAME__ +".input.TakeProfit.Pips"          );
   Chart.DeleteValue(__NAME__ +".input.TakeProfit.Continue"      );
   Chart.DeleteValue(__NAME__ +".input.StopLoss.Percent"         );
   Chart.DeleteValue(__NAME__ +".input.StopLoss.Continue"        );
   Chart.DeleteValue(__NAME__ +".input.StopLoss.ShowLevels"      );
   Chart.DeleteValue(__NAME__ +".input.Grid.Min.Pips"            );
   Chart.DeleteValue(__NAME__ +".input.Grid.Max.Pips"            );
   Chart.DeleteValue(__NAME__ +".input.Grid.Contractable"        );
   Chart.DeleteValue(__NAME__ +".input.Grid.Range.Periods"       );
   Chart.DeleteValue(__NAME__ +".input.Grid.Range.Divider"       );
   Chart.DeleteValue(__NAME__ +".input.Exit.Trail.Pips"          );
   Chart.DeleteValue(__NAME__ +".input.Exit.Trail.MinProfit.Pips");

   // runtime status
   Chart.DeleteValue(__NAME__ +".runtime.__STATUS_INVALID_INPUT");
   Chart.DeleteValue(__NAME__ +".runtime.__STATUS_OFF"          );
   Chart.DeleteValue(__NAME__ +".runtime.__STATUS_OFF.reason"   );
   Chart.DeleteValue(__NAME__ +".runtime.lots.calculatedSize"   );
   Chart.DeleteValue(__NAME__ +".runtime.lots.startSize"        );
   Chart.DeleteValue(__NAME__ +".runtime.lots.startVola"        );
   Chart.DeleteValue(__NAME__ +".runtime.grid.level"            );
   Chart.DeleteValue(__NAME__ +".runtime.grid.minSize"          );
   Chart.DeleteValue(__NAME__ +".runtime.grid.marketSize"       );
   Chart.DeleteValue(__NAME__ +".runtime.position.startEquity"  );
   Chart.DeleteValue(__NAME__ +".runtime.position.maxDrawdown"  );
   Chart.DeleteValue(__NAME__ +".runtime.position.slPrice"      );
   Chart.DeleteValue(__NAME__ +".runtime.position.plPip"        );
   Chart.DeleteValue(__NAME__ +".runtime.position.plPipMin"     );
   Chart.DeleteValue(__NAME__ +".runtime.position.plPipMax"     );
   Chart.DeleteValue(__NAME__ +".runtime.position.plUPip"       );
   Chart.DeleteValue(__NAME__ +".runtime.position.plUPipMin"    );
   Chart.DeleteValue(__NAME__ +".runtime.position.plUPipMax"    );
   Chart.DeleteValue(__NAME__ +".runtime.position.plPct"        );
   Chart.DeleteValue(__NAME__ +".runtime.position.plPctMin"     );
   Chart.DeleteValue(__NAME__ +".runtime.position.plPctMax"     );

   return(!catch("ResetStoredStatus(1)"));
}


/**
 * Synchronize/update the restored runtime status with the currently active state.
 *
 * @return bool
 */
bool SyncRuntimeStatus() {
   return(!catch("SyncRuntimeStatus(1)", ERR_NOT_IMPLEMENTED));
}


/**
 * Ask for confirmation to manage an already started sequence.
 *
 * @param  int id - sequence id
 *
 * @return bool - confirmation result
 */
bool ConfirmManageSequence(int id) {
   PlaySoundEx("Windows Notify.wav");
   int button = MessageBoxEx(__NAME__, ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you want to manage the already started sequence #"+ id +"?", MB_ICONQUESTION|MB_OKCANCEL);
   return(button == IDOK);
}


/**
 * Ask for confirmation to start a headless chicken.
 *
 * @return bool - confirmation result
 */
bool ConfirmHeadlessChicken() {
   if (!IsTesting()) {
      PlaySoundEx("Windows Notify.wav");
      int button = MessageBoxEx(__NAME__, ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you really want to start the chicken in headless mode?", MB_ICONQUESTION|MB_OKCANCEL);
      return(button == IDOK);
   }
   return(true);
}


