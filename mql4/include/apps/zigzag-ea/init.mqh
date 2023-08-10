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
 * Called after the expert was manually loaded by the user. Also in tester with both "VisualMode=On|Off". There was an input
 * dialog.
 *
 * @return int - error status
 */
int onInitUser() {
   // check for & validate a specified sequence id
   if (ValidateInputs.SID()) {                     // a sequence id was restored
      RestoreSequence();                           // the sequence was restored
   }
   else if (StrTrim(Sequence.ID) == "") {          // no sequence id was specified
      if (ValidateInputs()) {
         sequence.isTest  = __isTesting;
         sequence.id      = CreateSequenceId();
         Sequence.ID      = ifString(sequence.isTest, "T", "") + sequence.id; SS.SequenceName();
         sequence.created = TimeLocalEx("onInitUser(1)");
         sequence.status  = STATUS_WAITING;
         logInfo("onInitUser(2)  sequence "+ sequence.name +" created");
         SaveStatus();
      }
   }
   //else {}                                       // an invalid sequence id was specified
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
   if (RestoreSequenceId()) {                      // a sequence id was found and restored
      if (RestoreSequence()) {                     // the sequence was restored
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
   if (RestoreSequenceId()) {                      // same as for onInitTemplate()
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
int afterInit() {                                  // open the log file (flushes the log buffer) but don't touch the file
   if (__isTesting || !IsTestSequence()) {         // of a finished test (i.e. a test loaded into an online chart)
      if (!SetLogfile(GetLogFilename())) return(catch("afterInit(1)"));
   }

   // read debug config
   string section = ifString(__isTesting, "Tester.", "") + ProgramName();
   if (__isTesting) {
      test.onReversalPause     = GetConfigBool(section, "OnReversalPause",     false);
      test.onSessionBreakPause = GetConfigBool(section, "OnSessionBreakPause", false);
      test.onStopPause         = GetConfigBool(section, "OnStopPause",         true);
      test.reduceStatusWrites  = GetConfigBool(section, "ReduceStatusWrites",  true);
   }

   int size = ArraySize(recorder.symbol);
   for (int i=0; i < size; i++) {
      recorder.debug[i] = GetConfigBool(section, "DebugRecorder."+ i, false);
   }

   StoreSequenceId();                              // store the sequence id for templates changes/restart/recompilation etc.
   return(catch("afterInit(2)"));
}


/**
 * Create the status display box. It consists of overlapping rectangles made of font "Webdings", char "g".
 * Called from onInit() only.
 *
 * @return bool - success status
 */
bool CreateStatusBox() {
   if (!__isChart) return(true);

   int x[]={2, 70, 120}, y=50, fontSize=47, sizeofX=ArraySize(x);
   color bgColor = LemonChiffon;

   for (int i=0; i < sizeofX; i++) {
      string label = ProgramName() +".statusbox."+ (i+1);
      if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return(false);
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE, x[i]);
      ObjectSet(label, OBJPROP_YDISTANCE, y);
      ObjectSetText(label, "g", fontSize, "Webdings", bgColor);
   }
   return(!catch("CreateStatusBox(1)"));
}
