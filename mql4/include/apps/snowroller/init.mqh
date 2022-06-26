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
   // check for a specified sequence id
   if (ValidateInputs.SID()) {                                 // a valid sequence id was specified and restored
      sequence.status = STATUS_WAITING;
      RestoreSequence();                                       // the sequence was restored
      return(last_error);
   }
   else if (StrTrim(Sequence.ID) == "") {                      // no sequence id was specified
      if (ValidateInputs()) {
         if (!ConfirmFirstTickTrade("", "Do you really want to start a new sequence?"))                        // TODO: this must be Confirm() only
            return(SetLastError(ERR_CANCELLED_BY_USER));

         sequence.isTest  = __isTesting;
         sequence.id      = CreateSequenceId();
         Sequence.ID      = ifString(sequence.isTest, "T", "") + sequence.id; SS.SequenceName();
         sequence.cycle   = 1;
         sequence.created = TimeLocal();
         sequence.status  = STATUS_WAITING;
         SaveStatus();

         if (IsLogDebug()) {
            logDebug("onInitUser(1)  sequence "+ sequence.name +" created"+ ifString(start.conditions, ", waiting for start condition", ""));
         }
         else if (__isTesting && !IsVisualMode()) {
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
   if (RestoreSequenceId()) {                                  // a sequence id was found and restored
      RestoreSequence();                                       // the sequence was restored
      return(last_error);
   }
   return(catch("onInitTemplate(1)  could not restore sequence id from anywhere, aborting...", ERR_RUNTIME_ERROR));
}


/**
 * Called after the expert was recompiled. There was no input dialog.
 *
 * @return int - error status
 */
int onInitRecompile() {
   if (RestoreSequenceId()) {                         // same as for onInitTemplate()
      RestoreSequence();
      return(last_error);
   }
   return(catch("onInitRecompile(1)  could not restore sequence id from anywhere, aborting...", ERR_RUNTIME_ERROR));
}


/**
 * Initialization postprocessing. Not called if the reason-specific event handler returned with an error.
 *
 * @return int - error status
 */
int afterInit() {
   if (__isTesting || !IsTestSequence()) {            // open the log file (flushes the log buffer) but don't touch the file
      SetLogfile(GetLogFilename());                   // of a finished test (i.e. a test loaded into an online chart)
   }

   string section = ProgramName(MODE_NICE);
   limitOrderTrailing = GetConfigInt(section, "LimitOrderTrailing", 3);

   if (__isTesting) {
      // initialize tester configuration
      section = "Tester."+ section;
      test.onStartPause        = GetConfigBool(section, "OnStartPause",        false);
      test.onStopPause         = GetConfigBool(section, "OnStopPause",         false);
      test.onSessionBreakPause = GetConfigBool(section, "OnSessionBreakPause", false);
      test.onTrendChangePause  = GetConfigBool(section, "OnTrendChangePause",  false);
      test.onTakeProfitPause   = GetConfigBool(section, "OnTakeProfitPause",   false);
      test.onStopLossPause     = GetConfigBool(section, "OnStopLossPause",     false);
      test.reduceStatusWrites  = GetConfigBool(section, "ReduceStatusWrites",   true);
      test.showBreakeven       = GetConfigBool(section, "ShowBreakeven",       false);
   }
   else if (IsTestSequence()) {
      // a finished test loaded into an online chart
      sequence.status = STATUS_STOPPED;               // TODO: move to SynchronizeStatus()
   }
   return(last_error);
}
