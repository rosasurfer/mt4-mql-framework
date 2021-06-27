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
   if (ValidateInputs()) {                                     // on success create a new sequence
      sequence.id      = CreateSequenceId();
      sequence.created = Max(TimeCurrentEx(), TimeServer());
      sequence.isTest  = IsTesting();
      sequence.status  = STATUS_WAITING;
      long.enabled     = (sequence.directions & D_LONG  && 1);
      short.enabled    = (sequence.directions & D_SHORT && 1);
      SS.All();
      logInfo("onInitUser(1)  sequence "+ sequence.name +" created");

      // prevent starting with too little free margin
      double longLotsPlus=0, longLotsMinus=0, shortLotsPlus=0, shortLotsMinus=0;
      int level=0, maxLevels=15;

      for (level=+1; level <=  maxLevels; level++) longLotsPlus   += CalculateLots(D_LONG, level);
      for (level=-1; level >= -maxLevels; level--) longLotsMinus  += CalculateLots(D_LONG, level);
      for (level=+1; level <=  maxLevels; level++) shortLotsPlus  += CalculateLots(D_SHORT, level);
      for (level=-1; level >= -maxLevels; level--) shortLotsMinus += CalculateLots(D_SHORT, level);

      double maxLongLots  = MathMax(longLotsPlus, longLotsMinus);
      double maxShortLots = MathMax(shortLotsPlus, shortLotsMinus);
      double maxLots      = MathMax(maxLongLots, maxShortLots);               // max lots at level 15 in any direction
      if (IsError(catch("onInitUser(2)"))) return(last_error);                // reset last error
      if (AccountFreeMarginCheck(Symbol(), OP_BUY, maxLots) < 0 || GetLastError()==ERR_NOT_ENOUGH_MONEY) {
         StopSequence();
         logError("onInitUser(3) not enough money to open "+ maxLevels +" levels with a unitsize of "+ NumberToStr(sequence.unitsize, ".+") +" lot", ERR_NOT_ENOUGH_MONEY);
         return(catch("onInitUser(4)"));
      }

      // confirm dangerous live modes
      if (!IsTesting() && !IsDemoFix()) {
         if (sequence.martingaleEnabled || sequence.directions==D_BOTH) {
            PlaySoundEx("Windows Notify.wav");
            if (IDOK != MessageBoxEx(ProgramName() +"::StartSequence()", "WARNING: "+ ifString(sequence.martingaleEnabled, "Martingale", "Bi-directional") +" mode!\n\nDid you check coming news?", MB_ICONQUESTION|MB_OKCANCEL)) {
               StopSequence();
               return(catch("onInitUser(5)"));
            }
         }
      }

      // all good: confirm sequence generation
      SaveStatus();
   }
   return(catch("onInitUser(6)"));
}


/**
 * Called after the input parameters were changed through the input dialog.
 *
 * @return int - error status
 */
int onInitParameters() {
   if (ValidateInputs()) SaveStatus();
   else                  RestoreInputs();
   return(last_error);
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
   return(SetLastError(ERR_ILLEGAL_STATE));
}


/**
 * Called after the expert was loaded by a chart template. Also at terminal start. There was no input dialog.
 *
 * @return int - error status
 */
int onInitTemplate() {
   return(SetLastError(ERR_NOT_IMPLEMENTED));
}


/**
 * Initialization postprocessing. Not called if the reason-specific init handler returned with an error.
 *
 * @return int - error status
 */
int afterInit() {
   SS.All();
   if (!SetLogfile(GetLogFilename())) return(last_error);

   if (IsTesting()) {                                       // read test configuration
      string section = ProgramName() +".Tester";
      tester.onStopPause      = GetConfigBool(section, "OnStopPause",       false);
      test.reduceStatusWrites = GetConfigBool(section, "ReduceStatusWrites", true);
   }
   return(catch("afterInit(1)"));
}
