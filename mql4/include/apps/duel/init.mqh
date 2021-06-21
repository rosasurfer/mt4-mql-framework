/**
 * Called after the expert was manually loaded by the user. Also in tester with both "VisualMode=On|Off".
 * There was an input dialog.
 *
 * @return int - error status
 *
 * @see  mql4/experts/Duel.mq4
 */
int onInitUser() {
   if (ValidateInputs()) {                                     // on success create a new sequence
      sequence.id      = CreateSequenceId();
      sequence.created = Max(TimeCurrentEx(), TimeServer());
      sequence.isTest  = IsTesting();
      sequence.status  = STATUS_WAITING;
      long.enabled     = (sequence.directions & D_LONG  && 1);
      short.enabled    = (sequence.directions & D_SHORT && 1);
      SS.SequenceName();
      logInfo("onInitUser(1)  sequence "+ sequence.name +" created");
      SaveStatus();
   }
   return(catch("onInitUser(2)"));
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
   CreateStatusBox();
   SS.All();

   if (!SetLogfile(GetLogFilename())) return(last_error);

   if (IsTesting()) {                                       // read test configuration
      string section = ProgramName() +".Tester";
      tester.onStopPause      = GetConfigBool(section, "OnStopPause",       false);
      test.reduceStatusWrites = GetConfigBool(section, "ReduceStatusWrites", true);
   }
   return(catch("afterInit(1)"));
}
