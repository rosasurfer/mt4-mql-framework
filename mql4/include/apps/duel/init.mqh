
/**
 * Called after the expert was manually loaded by the user. Also in Strategy Tester with both "VisualMode=On|Off".
 * There was an input dialog.
 *
 * @return int - error status
 */
int onInitUser() {
   // validate inputs
   // GridDirection
   string sValues[], sValue = GridDirection;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sequence.directions = StrToTradeDirection(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (sequence.directions == -1) return(catch("onInitUser(1)  Invalid input parameter GridDirection: "+ DoubleQuoteStr(GridDirection), ERR_INVALID_INPUT_PARAMETER));
   GridDirection = TradeDirectionDescription(sequence.directions);
   // GridSize
   if (GridSize < 1)              return(catch("onInitUser(2)  Invalid input parameter GridSize: "+ GridSize, ERR_INVALID_INPUT_PARAMETER));
   // UnitSize
   if (LT(UnitSize, 0.01))        return(catch("onInitUser(3)  Invalid input parameter UnitSize: "+ NumberToStr(UnitSize, ".1+"), ERR_INVALID_INPUT_PARAMETER));
   sequence.unitsize = UnitSize;
   // Pyramid.Multiplier
   if (Pyramid.Multiplier < 0)    return(catch("onInitUser(4)  Invalid input parameter Pyramid.Multiplier: "+ NumberToStr(Pyramid.Multiplier, ".1+"), ERR_INVALID_INPUT_PARAMETER));
   // Martingale.Multiplier
   if (Martingale.Multiplier < 0) return(catch("onInitUser(5)  Invalid input parameter Martingale.Multiplier: "+ NumberToStr(Martingale.Multiplier, ".1+"), ERR_INVALID_INPUT_PARAMETER));

   // create a new sequence
   sequence.id      = CreateSequenceId();
   sequence.created = Max(TimeCurrentEx(), TimeServer());
   sequence.isTest  = IsTesting();
   long.enabled     = (sequence.directions & D_LONG  && 1);
   short.enabled    = (sequence.directions & D_SHORT && 1);
   sequence.status  = STATUS_WAITING;

   if (__LOG()) log("onInitUser(6)  sequence "+ sequence.name +" created");
   return(catch("onInitUser(7)"));
}
