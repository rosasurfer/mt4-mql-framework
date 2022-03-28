/**
 * Initialization preprocessing.
 *
 * @return int - error status
 *
 * @see  "mql4/experts/ZigZag EA.mq4"
 */
int onInit() {
   CreateStatusBox();
   return(catch("onInit(1)"));
}


/**
 * Called after the expert was manually loaded by the user. Also in tester with both "VisualMode=On|Off". There was an input
 * dialog.
 *
 * @return int - error status
 */
int onInitUser() {
   // check for and validate a specified sequence id
   if (ValidateInputs.SID()) {
      RestoreSequence();                                       // a valid sequence id was specified
   }
   else if (StrTrim(Sequence.ID) == "") {                      // no sequence id was specified
      if (ValidateInputs()) {
         sequence.isTest  = IsTesting();
         sequence.id      = CreateSequenceId();
         Sequence.ID      = ifString(sequence.isTest, "T", "") + sequence.id; SS.SequenceName();
         sequence.created = TimeServer();
         sequence.status  = STATUS_WAITING;
         logInfo("onInitUser(1)  sequence "+ sequence.name +" created");
         SaveStatus();
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
   return(catch("onInitSymbolChange(1)", ERR_ILLEGAL_STATE));
}


/**
 * Called after the expert was loaded by a chart template. Also at terminal start. There was no input dialog.
 *
 * @return int - error status
 */
int onInitTemplate() {
   // restore sequence id from the chart
   if (FindSequenceId()) {                                  // on success a sequence id was restored
      if (RestoreSequence()) {
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
   // restore sequence id from the chart                    // same as for onInitTemplate()
   if (FindSequenceId()) {
      if (RestoreSequence()) {
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
   if (IsTesting() || !IsTestSequence()) {
      bool sequenceWasStarted = (open.ticket || ArrayRange(history, 0));
      if (sequenceWasStarted) SetLogfile(GetLogFilename());    // don't create the logfile before StartSequence()

      string section = "Tester."+ StrTrim(ProgramName());
      test.onReversalPause     = GetConfigBool(section, "OnReversalPause",     false);
      test.onSessionBreakPause = GetConfigBool(section, "OnSessionBreakPause", false);
      test.onStopPause         = GetConfigBool(section, "OnStopPause",         true);
      test.reduceStatusWrites  = GetConfigBool(section, "ReduceStatusWrites",  true);
   }
   StoreSequenceId();                                          // store the sequence id for other templates/restart/recompilation etc.
   return(catch("afterInit(1)"));
}


/**
 * Create the status display box. It consists of overlapping rectangles made of font "Webdings", char "g".
 * Called from onInit() only.
 *
 * @return int - error status
 */
int CreateStatusBox() {
   if (!__isChart) return(NO_ERROR);

   int x[]={2, 114}, y=46, fontSize=115, sizeofX=ArraySize(x);
   color bgColor = LemonChiffon;

   for (int i=0; i < sizeofX; i++) {
      string label = ProgramName() +".statusbox."+ (i+1);
      if (ObjectFind(label) != 0) {
         ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
         RegisterObject(label);
      }
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE, x[i]);
      ObjectSet(label, OBJPROP_YDISTANCE, y);
      ObjectSetText(label, "g", fontSize, "Webdings", bgColor);
   }
   return(catch("CreateStatusBox(1)"));
}
