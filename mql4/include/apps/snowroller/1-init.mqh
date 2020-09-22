
/**
 * Initialization pre-processing hook.
 *
 * @return int - error status
 */
int onInit() {
   SNOWROLLER = StrStartsWithI(ProgramName(), "SnowRoller");    // MQL4 doesn't allow constant bool definitions
   SISYPHUS   = StrStartsWithI(ProgramName(), "Sisyphus");
   return(NO_ERROR);
}


/**
 * Called after the expert was manually loaded by the user. Also in Strategy Tester with both "VisualMode=On|Off".
 * There was an input dialog.
 *
 * @return int - error status
 */
int onInitUser() {
   bool interactive = true;

   // check for a specified sequence id
   if (ValidateInputs.ID()) {                               // on success a valid sequence id was specified
      SetLogfile(GetLogFilename());

      sequence.status = STATUS_WAITING;
      if (!RestoreSequence(interactive)) SetLogfile("");
      return(last_error);
   }
   else if (StringLen(StrTrim(Sequence.ID)) > 0) {
      return(last_error);                                   // on error: invalid sequence id
   }

   // create a new sequence
   if (ValidateInputs(interactive)) {
      if (!ConfirmFirstTickTrade("", "Do you really want to start a new sequence?"))   // TODO: this must be Confirm() only
         return(SetLastError(ERR_CANCELLED_BY_USER));

      sequence.id      = CreateSequenceId();
      Sequence.ID      = ifString(IsTestSequence(), "T", "") + sequence.id;
      sequence.cycle   = 1;
      sequence.created = Max(TimeCurrentEx(), TimeServer());
      sequence.isTest  = IsTesting();
      sequence.status  = STATUS_WAITING;
      SetLogfile(GetLogFilename());
      SS.SequenceName();
      SaveStatus();

      if (IsLog()) {
         logInfo("onInitUser(1)  sequence "+ sequence.name +" created"+ ifString(start.conditions, ", waiting for start condition", ""));
      }
      else if (IsTesting() && !IsVisualMode()) {
         debug("onInitUser(2)  sequence "+ sequence.name +" created");
      }
   }
   return(last_error);
}


/**
 * Called after the expert was loaded by a chart template. Also at terminal start. There was no input dialog.
 *
 * @return int - error status
 */
int onInitTemplate() {
   // restore sequence data from the chart
   if (RestoreChartStatus()) {
      SetLogfile(GetLogFilename());                         // on success a sequence id was restored
      RestoreSequence(false);
   }
   DeleteChartStatus();
   return(last_error);
}


/**
 * Called after the input parameters were changed through the input dialog.
 *
 * @return int - error status
 */
int onInitParameters() {
   BackupInputStatus();                                     // input itself has been backed-up in onDeinitParameters()

   bool interactive = true;
   if (!ValidateInputs(interactive)) {
      RestoreInputs();
      RestoreInputStatus();
      return(last_error);
   }
   if (sequence.status == STATUS_STOPPED) {
      if (start.conditions) {
         sequence.status = STATUS_WAITING;
      }
   }
   else if (sequence.status == STATUS_WAITING) {
      if (!start.conditions) {                              // TODO: evaluate sessionbreak.waiting
      }
   }
   if (sequence.status != STATUS_UNDEFINED)                 // parameter change of a valid sequence
      SaveStatus();
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
 * Called after the current chart symbol has changed. There was no input dialog.
 *
 * @return int - error status
 */
int onInitSymbolChange() {
   SetLogfile("");
   return(SetLastError(ERR_CANCELLED_BY_USER));
}


/**
 * Called after the expert was recompiled. There was no input dialog.
 *
 * @return int - error status
 */
int onInitRecompile() {
   return(onInitTemplate());                                // same requirements as for onInitTemplate()
}


/**
 * Initialization post-processing hook. Not called if the reason-specific event handler returned with an error.
 *
 * @return int - error status
 */
int afterInit() {
   // initialize status display
   CreateStatusBox();
   SS.All();
   string section = ProgramName();
   limitOrderTrailing = GetConfigInt(section, "LimitOrderTrailing", 3);

   if (IsTesting()) {
      // initialize tester configuration
      section = section +".Tester";
      tester.onStartPause        = GetConfigBool(section, "OnStartPause",        false);
      tester.onStopPause         = GetConfigBool(section, "OnStopPause",         false);
      tester.onSessionBreakPause = GetConfigBool(section, "OnSessionBreakPause", false);
      tester.onTrendChangePause  = GetConfigBool(section, "OnTrendChangePause",  false);
      tester.onTakeProfitPause   = GetConfigBool(section, "OnTakeProfitPause",   false);
      tester.onStopLossPause     = GetConfigBool(section, "OnStopLossPause",     false);
      tester.reduceStatusWrites  = GetConfigBool(section, "ReduceStatusWrites",   true);
      tester.showBreakeven       = GetConfigBool(section, "ShowBreakeven",       false);
   }
   else if (IsTestSequence()) {
      // a finished test loaded into an online chart
      sequence.status = STATUS_STOPPED;                           // TODO: move to SynchronizeStatus()
   }
   return(last_error);
}
