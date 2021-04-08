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
      SS.SequenceName();
      logDebug("onInitUser(1)  sequence "+ sequence.name +" created");
      SetLogfile(GetLogFilename());
   }
   return(catch("onInitUser(2)"));
}


/**
 * Called after the input parameters were changed through the input dialog.
 *
 * @return int - error status
 */
int onInitParameters() {
   BackupInputStatus();                                        // input itself has been backed-up in onDeinitParameters()

   if (!ValidateInputs()) {
      RestoreInputs();
      RestoreInputStatus();
      return(last_error);
   }
   return(last_error);
}


/**
 * Called after the current chart period has changed. There was no input dialog.
 *
 * @return int - error status
 */
int onInitTimeframeChange() {
   RestoreInputs();
   return(NO_ERROR);
}


/**
 * Initialization postprocessing. Not called if the reason-specific init handler returned with an error.
 *
 * @return int - error status
 */
int afterInit() {
   CreateStatusBox();
   SS.All();

   if (IsTesting()) {                                          // initialize tester configuration
      string section = ProgramName() +".Tester";
      tester.onStopPause = GetConfigBool(section, "OnStopPause", false);
   }
   return(catch("afterInit(1)"));
}
