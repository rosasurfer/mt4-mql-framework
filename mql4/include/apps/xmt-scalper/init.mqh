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
         sequence.id = CreateSequenceId();
         Sequence.ID = sequence.id;
         SS.SequenceName();
         logInfo("onInitUser(1)  sequence id "+ sequence.id +" created");
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
   if (ValidateInputs()) {
      SaveStatus();                                            // successful parameter change
   }
   else {
      RestoreInputs();                                         // failed parameter change
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
 * Initialization postprocessing. Called only if the reason-specific handler returned without error.
 *
 * @return int - error status
 */
int afterInit() {
   // initialize global vars
   if (UseSpreadMultiplier) { minBarSize = 0;              sMinBarSize = "-";                                }
   else                     { minBarSize = MinBarSize*Pip; sMinBarSize = DoubleToStr(MinBarSize, 1) +" pip"; }
   MaxSpread        = NormalizeDouble(MaxSpread, 1);
   sMaxSpread       = DoubleToStr(MaxSpread, 1);
   commissionPip    = GetCommission(1, MODE_MARKUP)/Pip;
   orderSlippage    = Round(MaxSlippage*Pip/Point);
   orderMagicNumber = CalculateMagicNumber();
   SS.All();

   if (!SetLogfile(GetLogFilename())) return(last_error);
   if (!InitMetrics())                return(last_error);

   if (IsTesting()) {                                       // read test configuration
      string section = ProgramName() +".Tester";
      test.onPositionOpenPause = GetConfigBool(section, "OnPositionOpenPause", false);
      test.reduceStatusWrites  = GetConfigBool(section, "ReduceStatusWrites",   true);
   }
   return(catch("afterInit(1)"));
}
