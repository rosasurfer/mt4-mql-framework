/**
 * Called after the expert was manually loaded by the user. Also in tester with both "VisualMode=On|Off".
 * There was an input dialog.
 *
 * @return int - error status
 *
 * @see  mql4/experts/SnowRoller.mq4
 */
int onInitUser() {
   // check for a specified sequence id
   if (ValidateInputs.SID()) {                                 // on success a sequence id was specified and restored
      sequence.status = STATUS_WAITING;
      RestoreSequence();
      return(last_error);
   }
   else if (StrTrim(Sequence.ID) == "") {                      // no sequence id was specified
      if (ValidateInputs()) {
         if (!ConfirmFirstTickTrade("", "Do you really want to start a new sequence?"))                        // TODO: this must be Confirm() only
            return(SetLastError(ERR_CANCELLED_BY_USER));

         sequence.id      = CreateSequenceId();
         Sequence.ID      = ifString(IsTestSequence(), "T", "") + sequence.id;
         sequence.cycle   = 1;
         sequence.created = Max(TimeCurrentEx(), TimeServer());
         sequence.isTest  = IsTesting();
         sequence.status  = STATUS_WAITING;
         SS.SequenceName();
         SaveStatus();

         if (IsLogDebug()) {
            logDebug("onInitUser(1)  sequence "+ sequence.name +" created"+ ifString(start.conditions, ", waiting for start condition", ""));
         }
         else if (IsTesting() && !IsVisualMode()) {
            debug("onInitUser(2)  sequence "+ sequence.name +" created");
         }
      }
   }
   //else {}                                                   // an invalid sequence id was specified

   return(last_error);
}


/**
 * Called after the input parameters were changed through the input dialog.
 *
 * @return int - error status
 */
int onInitParameters() {
   if (!ValidateInputs()) {
      RestoreInputs();
      return(last_error);
   }
   if (sequence.status == STATUS_STOPPED) {
      if (start.conditions) {
         sequence.status = STATUS_WAITING;
      }
   }
   else if (sequence.status == STATUS_WAITING) {
      if (!start.conditions) {                                 // TODO: evaluate sessionbreak.waiting
      }
   }
   if (sequence.status != STATUS_UNDEFINED)                    // parameter change of a valid sequence
      SaveStatus();
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
   // restore sequence id from the chart
   if (RestoreChartStatus()) {                                 // on success a sequence id was restored
      RestoreSequence();
      return(last_error);
   }
   return(catch("onInitTemplate(1)  could not restore sequence id from chart profile, aborting...", ERR_RUNTIME_ERROR));
}


/**
 * Called after the expert was recompiled. There was no input dialog.
 *
 * @return int - error status
 */
int onInitRecompile() {                                        // same requirements as for onInitTemplate()
   // restore sequence id from the chart
   if (RestoreChartStatus()) {                                 // on success a sequence id was restored
      RestoreSequence();
      return(last_error);
   }
   return(catch("onInitRecompile(1)  could not restore sequence id from chart profile, aborting...", ERR_RUNTIME_ERROR));
}


/**
 * Initialization postprocessing. Not called if the reason-specific event handler returned with an error.
 *
 * @return int - error status
 */
int afterInit() {
   // initialize status display
   CreateStatusBox();
   SS.All();

   if (!SetLogfile(GetLogFilename())) return(last_error);

   string section = ProgramName();
   limitOrderTrailing = GetConfigInt(section, "LimitOrderTrailing", 3);

   if (IsTesting()) {
      // initialize tester configuration
      section = section +".Tester";
      test.onStartPause        = GetConfigBool(section, "OnStartPause",        false);
      test.onStopPause         = GetConfigBool(section, "OnStopPause",         false);
      test.onSessionBreakPause = GetConfigBool(section, "OnSessionBreakPause", false);
      test.onTrendChangePause  = GetConfigBool(section, "OnTrendChangePause",  false);
      test.onTakeProfitPause   = GetConfigBool(section, "OnTakeProfitPause",   false);
      test.onStopLossPause     = GetConfigBool(section, "OnStopLossPause",     false);
      test.optimizeStatus      = GetConfigBool(section, "OptimizeStatus",       true);
      test.showBreakeven       = GetConfigBool(section, "ShowBreakeven",       false);
   }
   else if (IsTestSequence()) {
      // a finished test loaded into an online chart
      sequence.status = STATUS_STOPPED;                        // TODO: move to SynchronizeStatus()
   }
   return(last_error);
}
