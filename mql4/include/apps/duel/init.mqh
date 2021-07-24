/**
 * Initialization preprocessing.
 *
 * @return int - error status
 *
 * @see  mql4/experts/Duel.mq4
 */
int onInit() {
   CreateStatusBox();
   return(catch("onInit(1)"));
}


/**
 * Called after the expert was manually loaded by the user. Also in tester with both "VisualMode=On|Off".
 * There was an input dialog.
 *
 * @return int - error status
 */
int onInitUser() {
   // check for and validate a specified sequence id
   if (ValidateInputs.SID()) {
      if (RestoreSequence()) {                                       // a valid sequence id was specified
         logInfo("onInitUser(1)  "+ sequence.name +" restored in status "+ DoubleQuoteStr(StatusDescription(sequence.status)) +" from file "+ DoubleQuoteStr(GetStatusFilename(true)));
      }
   }
   else if (StrTrim(Sequence.ID) == "") {                            // no sequence id was specified
      if (ValidateInputs()) {
         sequence.id      = CreateSequenceId();
         Sequence.ID      = sequence.id;
         sequence.created = Max(TimeCurrentEx(), TimeServer());
         sequence.isTest  = IsTesting(); SS.SequenceName();
         sequence.cycle   = 1;
         sequence.status  = STATUS_WAITING;
         if (!ConfigureGrid(sequence.gridvola, sequence.gridsize, sequence.unitsize)) {
            return(onInputError("onInitUser(2)  invalid parameter combination GridVolatility="+ DoubleQuoteStr(GridVolatility) +" / GridSize="+ DoubleQuoteStr(GridSize) +" / UnitSize="+ NumberToStr(UnitSize, ".+")));
         }
         SS.All();

         // prevent starting with too little free margin
         double longLotsPlus=0, longLotsMinus=0, shortLotsPlus=0, shortLotsMinus=0;
         int level = 0;

         for (level=+1; level <=  MaxGridLevels; level++) longLotsPlus   += CalculateLots(D_LONG, level);
         for (level=-1; level >= -MaxGridLevels; level--) longLotsMinus  += CalculateLots(D_LONG, level);
         for (level=+1; level <=  MaxGridLevels; level++) shortLotsPlus  += CalculateLots(D_SHORT, level);
         for (level=-1; level >= -MaxGridLevels; level--) shortLotsMinus += CalculateLots(D_SHORT, level);

         double maxLongLots  = MathMax(longLotsPlus, longLotsMinus);
         double maxShortLots = MathMax(shortLotsPlus, shortLotsMinus);
         double maxLots      = MathMax(maxLongLots, maxShortLots);   // max. lots at maxGridLevel in any direction
         if (IsError(catch("onInitUser(3)"))) return(last_error);    // reset last error
         if (AccountFreeMarginCheck(Symbol(), OP_BUY, maxLots) < 0 || GetLastError()==ERR_NOT_ENOUGH_MONEY) {
            StopSequence(NULL);
            logError("onInitUser(4)  "+ sequence.name +" not enough money to open "+ MaxGridLevels +" levels with a unitsize of "+ NumberToStr(sequence.unitsize, ".+") +" lot", ERR_NOT_ENOUGH_MONEY);
            return(catch("onInitUser(5)"));
         }

         // confirm dangerous live modes
         if (!IsTesting() && !IsDemoFix()) {
            if (sequence.martingaleEnabled || sequence.direction==D_BOTH) {
               PlaySoundEx("Windows Notify.wav");
               if (IDOK != MessageBoxEx(ProgramName() +"::StartSequence()", "WARNING: "+ ifString(sequence.martingaleEnabled, "Martingale", "Bi-directional") +" mode!\n\nDid you check news and holidays?", MB_ICONQUESTION|MB_OKCANCEL)) {
                  StopSequence(NULL);
                  return(catch("onInitUser(6)"));
               }
            }
         }
         SaveStatus();
      }
   }
   //else {}                                                         // an invalid sequence id was specified

   return(last_error);
}


/**
 * Called after the input parameters were changed through the input dialog.
 *
 * @return int - error status
 */
int onInitParameters() {
   int error = NO_ERROR;

   if (ValidateInputs()) {
      if (ConfigureGrid(sequence.gridvola, sequence.gridsize, sequence.unitsize)) {
         SaveStatus();
         return(last_error);
      }
      error = logError("onInitParameters(1)  invalid parameter combination GridVolatility="+ DoubleQuoteStr(GridVolatility) +" / GridSize="+ DoubleQuoteStr(GridSize) +" / UnitSize="+ NumberToStr(UnitSize, ".+"), ERR_INVALID_INPUT_PARAMETER);
   }

   RestoreInputs();
   return(error);
}


/**
 * Called after the chart timeframe has changed. There was no input dialog.
 *
 * @return int - error status
 */
int onInitTimeframeChange() {
   RestoreInputs();
   return(NO_ERROR);
}


/**
 * Called after the chart symbol has changed. There was no input dialog.
 *
 * @return int - error status
 */
int onInitSymbolChange() {
   return(catch("onInitSymbolChange(1)", ERR_ILLEGAL_STATE));
}


/**
 * Called after the expert was loaded by a chart template. Also at terminal start. There was no input dialog.
 *
 * @return int - error status
 */
int onInitTemplate() {
   return(catch("onInitTemplate(1)", ERR_NOT_IMPLEMENTED));
}


/**
 * Initialization postprocessing. Not called if the reason-specific init handler returned with an error.
 *
 * @return int - error status
 */
int afterInit() {
   SS.All();

   bool sequenceWasStarted = (ArraySize(long.ticket) || ArraySize(short.ticket));
   if (sequenceWasStarted) SetLogfile(GetLogFilename());    // don't create the logfile before StartSequence()

   if (IsTesting()) {                                       // read test configuration
      string section = ProgramName() +".Tester";
      test.onStopPause    = GetConfigBool(section, "OnStopPause",   false);
      test.optimizeStatus = GetConfigBool(section, "OptimizeStatus", true);
   }
   return(catch("afterInit(1)"));
}
