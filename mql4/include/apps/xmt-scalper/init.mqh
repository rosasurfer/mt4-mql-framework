/**
 * Called after the expert was manually loaded by the user. Also in tester with both "VisualMode=On|Off". There was an input
 * dialog.
 *
 * @return int - error status
 */
int onInitUser() {
   // check for and validate a specified sequence id
   if (ValidateInputs.SID()) {                                 // on success a sequence id was specified and restored
      if (!RestoreSequence()) return(last_error);
   }
   else if (StringLen(StrTrim(Sequence.ID)) > 0) {
      return(last_error);                                      // on error an invalid sequence id was specified
   }
   else if (ValidateInputs()) {
      sequence.id = CreateSequenceId();
      Sequence.ID = sequence.id;
      logInfo("onInitUser(1)  sequence id "+ sequence.id +" created");
      SS.SequenceName();
      SaveStatus();
   }

   // initialize global vars
   if (UseSpreadMultiplier) { minBarSize = 0;              sMinBarSize = "-";                                }
   else                     { minBarSize = MinBarSize*Pip; sMinBarSize = DoubleToStr(MinBarSize, 1) +" pip"; }
   MaxSpread        = NormalizeDouble(MaxSpread, 1);
   sMaxSpread       = DoubleToStr(MaxSpread, 1);
   commissionPip    = GetCommission(1, MODE_MARKUP)/Pip;
   orderSlippage    = Round(MaxSlippage*Pip/Point);
   orderComment     = "XMT."+ sequence.id + ifString(ChannelBug, ".ChBug", "") + ifString(TakeProfitBug, ".TpBug", "");
   orderMagicNumber = GenerateMagicNumber();

   return(catch("onInitUser(2)"));
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
 * Called after the chart symbol has changed. There was no input dialog.
 *
 * @return int - error status
 */
int onInitSymbolChange() {
   return(SetLastError(ERR_ILLEGAL_STATE));
}


/**
 * Initialization postprocessing. Called only if the reason-specific handler returned without error.
 *
 * @return int - error status
 */
int afterInit() {
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
