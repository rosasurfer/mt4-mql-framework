
/**
 * Initialization preprocessing.
 *
 * @return int - error status
 */
int onInit() {
   CreateStatusBox();

   int digits = MathMax(Digits, 2);                // transform Digits=1 to 2 (for some indices)
   if (digits > 2) {
      pUnit       = "pip";
      pDigits     = 1;
      pMultiplier = MathRound(1/Pip);
   }
   else {
      pUnit       = "point";
      pDigits     = 2;
      pMultiplier = 1;
   }
   return(catch("onInit(1)"));
}


/**
 * Called after the expert was manually loaded by the user. Also in tester with both "VisualMode=On|Off".
 * There was an input dialog.
 *
 * @return int - error status
 */
int onInitUser() {
   if (ValidateInputs.ID()) {                      // TRUE: a valid instance id was specified
      if (RestoreInstance()) {                     // try to reload the given instance
         logInfo("onInitUser(1)  "+ instance.name +" restored in status \""+ StatusDescription(instance.status) +"\" from file \""+ GetStatusFilename(true) +"\"");
      }
   }
   else if (StrTrim(Instance.ID) == "") {          // no instance id was specified
      if (ValidateInputs()) {
         instance.isTest  = __isTesting;
         instance.id      = CreateInstanceId();
         Instance.ID      = ifString(instance.isTest, "T", "") + StrPadLeft(instance.id, 3, "0"); SS.InstanceName();
         instance.created = GetLocalTime();
         instance.status  = STATUS_WAITING;
         logInfo("onInitUser(2)  instance "+ instance.name +" created");
         SaveStatus();
      }
   }
   //else {}                                       // an invalid instance id was specified
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
   if (RestoreVolatileData()) {                    // an instance id was found and restored
      if (RestoreInstance()) {                     // the instance was restored
         logInfo("onInitTemplate(1)  "+ instance.name +" restored in status \""+ StatusDescription(instance.status) +"\" from file \""+ GetStatusFilename(true) +"\"");
      }
      return(last_error);
   }
   return(catch("onInitTemplate(2)  could not restore instance id from anywhere, aborting...", ERR_RUNTIME_ERROR));
}


/**
 * Called after the expert was recompiled. There was no input dialog.
 *
 * @return int - error status
 */
int onInitRecompile() {
   if (RestoreVolatileData()) {                    // same as for onInitTemplate()
      if (RestoreInstance()) {
         logInfo("onInitRecompile(1)  "+ instance.name +" restored in status \""+ StatusDescription(instance.status) +"\" from file \""+ GetStatusFilename(true) +"\"");
      }
      return(last_error);
   }
   return(catch("onInitRecompile(2)  could not restore instance id from anywhere, aborting...", ERR_RUNTIME_ERROR));
}


/**
 * Initialization postprocessing. Not called if the reason-specific init handler returned with an error.
 *
 * @return int - error status
 */
int afterInit() {                                  // open the log file (flushes the log buffer) but don't touch the file
   if (__isTesting || !IsTestInstance()) {         // of a finished test (i.e. a test loaded into an online chart)
      if (!SetLogfile(GetLogFilename())) return(catch("afterInit(1)"));
   }

   // read debug config
   string section = ifString(__isTesting, "Tester.", "") + ProgramName();
   if (__isTesting) {
      test.disableTickValueWarning = GetConfigBool(section, "DisableTickValueWarning", false);
      test.onStopPause             = GetConfigBool(section, "OnStopPause",             true);
      test.reduceStatusWrites      = GetConfigBool(section, "ReduceStatusWrites",      true);
   }
   StoreVolatileData();                            // store the instance id for templates changes/restart/recompilation etc.
   return(catch("afterInit(2)"));
}


/**
 * Create the status display box. Consists of overlapping rectangles made of font "Webdings", char "g".
 * Called from onInit() only.
 *
 * @return bool - success status
 */
bool CreateStatusBox() {
   if (!__isChart) return(true);

   int x[]={2, 66, 125}, y=50, fontSize=54, sizeofX=ArraySize(x);
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
