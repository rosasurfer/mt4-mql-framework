/**
 * Initialization preprocessing.
 *
 * @return int - error status
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
   if (ValidateInputs.SID()) {                                       // a valid sequence id was specified and restored
      if (RestoreSequence()) {                                       // the sequence was restored
         ComputeTargets();
         SS.All();
         logInfo("onInitUser(1)  "+ sequence.name +" restored in status "+ DoubleQuoteStr(StatusDescription(sequence.status)) +" from file "+ DoubleQuoteStr(GetStatusFilename(true)));
      }
   }
   else if (StrTrim(Sequence.ID) == "") {                            // no sequence id was specified
      if (ValidateInputs()) {
         sequence.isTest  = __isTesting;
         sequence.id      = CreateSequenceId();
         Sequence.ID      = ifString(sequence.isTest, "T", "") + sequence.id; SS.SequenceName();
         sequence.created = TimeLocalEx("onInitUser(2)");
         sequence.cycle   = 1;
         sequence.status  = STATUS_WAITING;
         if (!ConfigureGrid(sequence.gridvola, sequence.gridsize, sequence.unitsize)) {
            return(onInputError("onInitUser(3)  "+ sequence.name +" invalid parameter combination GridVolatility="+ DoubleQuoteStr(GridVolatility) +" / GridSize="+ DoubleQuoteStr(GridSize) +" / UnitSize="+ NumberToStr(UnitSize, ".+")));
         }

         // warn if starting with too little free margin
         double longLotsPlus=0, longLotsMinus=0, shortLotsPlus=0, shortLotsMinus=0;
         int level = 0;

         for (level=+1; level <=  MaxUnits; level++) longLotsPlus   += CalculateLots(D_LONG, level);
         for (level=-1; level >= -MaxUnits; level--) longLotsMinus  += CalculateLots(D_LONG, level);
         for (level=+1; level <=  MaxUnits; level++) shortLotsPlus  += CalculateLots(D_SHORT, level);
         for (level=-1; level >= -MaxUnits; level--) shortLotsMinus += CalculateLots(D_SHORT, level);

         double maxLongLots  = MathMax(longLotsPlus, longLotsMinus);
         double maxShortLots = MathMax(shortLotsPlus, shortLotsMinus);
         double maxLots      = MathMax(maxLongLots, maxShortLots);   // max. lots at maxGridLevel in any direction
         if (IsError(catch("onInitUser(4)"))) return(last_error);    // reset last error
         if (AccountFreeMarginCheck(Symbol(), OP_BUY, maxLots) < 0 || GetLastError()==ERR_NOT_ENOUGH_MONEY) {
            logWarn("onInitUser(5)  "+ sequence.name +" not enough money to open "+ MaxUnits +" units with a size of "+ NumberToStr(sequence.unitsize, ".+") +" lot", ERR_NOT_ENOUGH_MONEY);
         }

         // confirm dangerous live modes
         if (!__isTesting && !IsDemoFix()) {
            if (sequence.martingaleEnabled || sequence.direction==D_BOTH) {
               PlaySoundEx("Windows Notify.wav");
               if (IDOK != MessageBoxEx(ProgramName() +"::StartSequence()", "WARNING: "+ ifString(sequence.martingaleEnabled, "Martingale", "Bi-directional") +" mode!\n\nDid you check news and holidays?", MB_ICONQUESTION|MB_OKCANCEL)) {
                  StopSequence(NULL);
                  return(catch("onInitUser(6)"));
               }
            }
         }
         ComputeTargets();
         SS.All();
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
         ComputeTargets();
         SS.All();
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
   if (RestoreSequenceId()) {                            // a sequence id was found and restored
      if (RestoreSequence()) {                           // the sequence was restored
         ComputeTargets();
         SS.All();
         logInfo("onInitTemplate(1)  "+ sequence.name +" restored in status \""+ StatusDescription(sequence.status) +"\" from file \""+ GetStatusFilename(true) +"\"");
      }
      return(last_error);
   }
   return(catch("onInitTemplate(2)  could not restore sequence id from anywhere, aborting...", ERR_RUNTIME_ERROR));
}


/**
 * Called after the expert was recompiled. There was no input dialog.
 *
 * @return int - error status
 */
int onInitRecompile() {
   if (RestoreSequenceId()) {                            // same as for onInitTemplate()
      if (RestoreSequence()) {
         ComputeTargets();
         SS.All();
         logInfo("onInitRecompile(1)  "+ sequence.name +" restored in status \""+ StatusDescription(sequence.status) +"\" from file \""+ GetStatusFilename(true) +"\"");
      }
      return(last_error);
   }
   return(catch("onInitRecompile(2)  could not restore sequence id from anywhere, aborting...", ERR_RUNTIME_ERROR));
}


/**
 * Initialization postprocessing. Not called if the reason-specific init handler returned with an error.
 *
 * @return int - error status
 */
int afterInit() {
   if (__isTesting || !IsTestSequence()) {         // open the log file (flushes the log buffer) but don't touch the file
      SetLogfile(GetLogFilename());                // of a finished test (i.e. a test loaded into an online chart)
   }

   if (__isTesting) {                              // read test configuration
      string section          = "Tester."+ ProgramName();
      test.onStopPause        = GetConfigBool(section, "OnStopPause",       false);
      test.reduceStatusWrites = GetConfigBool(section, "ReduceStatusWrites", true);
   }

   StoreSequenceId();                              // store the sequence id for other templates/restart/recompilation etc.
   return(catch("afterInit(1)"));
}
