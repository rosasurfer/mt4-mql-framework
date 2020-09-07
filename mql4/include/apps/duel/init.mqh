
/**
 * Called after the expert was manually loaded by the user. Also in Strategy Tester with both "VisualMode=On|Off".
 * There was an input dialog.
 *
 * @return int - error status
 */
int onInitUser() {
   // validate inputs
   // GridDirections
   string sValues[], sValue = GridDirections;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sequence.directions = StrToTradeDirection(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (sequence.directions == -1) return(catch("onInitUser(1)  Invalid input parameter GridDirections: "+ DoubleQuoteStr(GridDirections), ERR_INVALID_INPUT_PARAMETER));
   GridDirections = TradeDirectionDescription(sequence.directions);
   // GridSize
   if (GridSize < 1)              return(catch("onInitUser(2)  Invalid input parameter GridSize: "+ GridSize, ERR_INVALID_INPUT_PARAMETER));
   // UnitSize
   if (LT(UnitSize, 0.01))        return(catch("onInitUser(3)  Invalid input parameter UnitSize: "+ NumberToStr(UnitSize, ".1+"), ERR_INVALID_INPUT_PARAMETER));
   sequence.unitsize = UnitSize;
   // Pyramid.Multiplier
   if (Pyramid.Multiplier < 0)    return(catch("onInitUser(4)  Invalid input parameter Pyramid.Multiplier: "+ NumberToStr(Pyramid.Multiplier, ".1+"), ERR_INVALID_INPUT_PARAMETER));
   sequence.isPyramid = (Pyramid.Multiplier > 0);
   // Martingale.Multiplier
   if (Martingale.Multiplier < 0) return(catch("onInitUser(5)  Invalid input parameter Martingale.Multiplier: "+ NumberToStr(Martingale.Multiplier, ".1+"), ERR_INVALID_INPUT_PARAMETER));
   sequence.isMartingale = (Martingale.Multiplier > 0);
   // TakeProfit
   sValue = StrTrim(TakeProfit);
   bool isPercent = StrEndsWith(sValue, "%");
   if (isPercent) sValue = StrTrim(StrLeft(sValue, -1));
   if (!StrIsNumeric(sValue))     return(catch("onInitUser(6)  Invalid input parameter TakeProfit: "+ DoubleQuoteStr(TakeProfit), ERR_INVALID_INPUT_PARAMETER));
   double dValue = StrToDouble(sValue);
   if (isPercent) {
      tpPct.condition   = true;
      tpPct.value       = dValue;
      tpPct.absValue    = INT_MAX;
      tpPct.description = "profit("+ NumberToStr(dValue, ".+") +"%)";
   }
   else {
      tpAbs.condition   = true;
      tpAbs.value       = NormalizeDouble(dValue, 2);
      tpAbs.description = "profit("+ DoubleToStr(dValue, 2) +")";
   }
   // StopLoss
   sValue = StrTrim(StopLoss);
   isPercent = StrEndsWith(sValue, "%");
   if (isPercent) sValue = StrTrim(StrLeft(sValue, -1));
   if (!StrIsNumeric(sValue))     return(catch("onInitUser(7)  Invalid input parameter StopLoss: "+ DoubleQuoteStr(StopLoss), ERR_INVALID_INPUT_PARAMETER));
   dValue = StrToDouble(sValue);
   if (isPercent) {
      slPct.condition   = true;
      slPct.value       = dValue;
      slPct.absValue    = INT_MIN;
      slPct.description = "loss("+ NumberToStr(dValue, ".+") +"%)";
   }
   else {
      slAbs.condition   = true;
      slAbs.value       = NormalizeDouble(dValue, 2);
      slAbs.description = "loss("+ DoubleToStr(dValue, 2) +")";
   }

   // create a new sequence
   sequence.id      = CreateSequenceId();
   sequence.created = Max(TimeCurrentEx(), TimeServer());
   sequence.isTest  = IsTesting();
   sequence.status  = STATUS_WAITING;
   long.enabled     = (sequence.directions & D_LONG  && 1);
   short.enabled    = (sequence.directions & D_SHORT && 1);
   SS.SequenceName();

   if (__LOG()) log("onInitUser(8)  sequence "+ sequence.name +" created");
   return(catch("onInitUser(9)"));
}


/**
 * Initialization post-processing hook. Not called if the reason-specific init handler returned with an error.
 *
 * @return int - error status
 */
int afterInit() {
   CreateStatusBox();
   SS.All();

   if (IsTesting()) {                                    // initialize tester configuration
      string section = __NAME() +".Tester";
      tester.onStopPause = GetConfigBool(section, "OnStopPause", false);
   }
   return(catch("afterInit(1)"));
}
