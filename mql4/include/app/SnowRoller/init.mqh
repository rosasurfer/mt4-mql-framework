
/**
 * Called after the expert was manually loaded by the user. Also in Strategy Tester with both "VisualMode=On|Off".
 * There was an input dialog.
 *
 * @return int - error status
 */
int onInitUser() {
   bool interactive = true;

   // Zuerst eine angegebene Sequenz restaurieren...
   if (ValidateInputs.ID(interactive)) {
      sequence.status = STATUS_WAITING;
      RestoreSequence(interactive);
      return(last_error);
   }
   else if (StringLen(StrTrim(Sequence.ID)) > 0) {
      return(last_error);                                // input error (invalid sequence id)
   }

   // ...dann laufende Sequenzen suchen und ggf. eine davon restaurieren...
   int ids[], button;

   if (GetRunningSequences(ids)) {
      int sizeOfIds = ArraySize(ids);
      for (int i=0; i < sizeOfIds; i++) {
         PlaySoundEx("Windows Notify.wav");
         button = MessageBoxEx(__NAME(), ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Running sequence"+ ifString(sizeOfIds==1, " ", "s ") + JoinInts(ids) +" found.\n\nDo you want to load "+ ifString(sizeOfIds==1, "it", ids[i]) +"?", MB_ICONQUESTION|MB_YESNOCANCEL);
         if (button == IDYES) {
            sequence.id     = ids[i];
            Sequence.ID     = sequence.id; SS.SequenceId();
            sequence.isTest = false;
            sequence.status = STATUS_WAITING;
            SetCustomLog(sequence.id, NULL);
            if (RestoreSequence(false)) {
               sequence.name = StrLeft(TradeDirectionDescription(sequence.direction), 1) +"."+ sequence.id;
            }
            return(last_error);
         }
         if (button == IDCANCEL)
            return(SetLastError(ERR_CANCELLED_BY_USER));
      }

      if (!ConfirmFirstTickTrade("", "Do you want to start a new sequence?"))
         return(SetLastError(ERR_CANCELLED_BY_USER));
   }

   // ...zum Schluß neue Sequenz anlegen
   if (ValidateInputs(interactive)) {
      sequence.id      = CreateSequenceId();
      Sequence.ID      = ifString(IsTestSequence(), "T", "") + sequence.id; SS.SequenceId();
      sequence.cycle   = 1;
      sequence.created = Max(TimeCurrentEx(), TimeServer());
      sequence.name    = StrLeft(TradeDirectionDescription(sequence.direction), 1) +"."+ sequence.id;
      sequence.isTest  = IsTesting();
      sequence.status  = STATUS_WAITING;

      string logFile = StrLeft(GetStatusFileName(), -3) +"log";
      SetCustomLog(sequence.id, logFile);

      if (start.conditions) {                            // without start conditions StartSequence() is called immediately and will save the sequence
         if (__LOG()) log("onInitUser(1)  sequence "+ sequence.name +" created at "+ NumberToStr((Bid+Ask)/2, PriceFormat) +", waiting for start condition");
         SaveStatus();
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
   // im Chart gespeicherte Sequenz restaurieren
   if (RestoreChartStatus()) {
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
   BackupInputStatus();                                  // input itself has been backed-up in onDeinitParameters()

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
      if (!start.conditions) {                           // TODO: evaluate sessionbreak.waiting
      }
   }
   if (sequence.status != STATUS_UNDEFINED)              // parameter change of a valid sequence
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
   return(SetLastError(ERR_CANCELLED_BY_USER));
}


/**
 * Called after the expert was recompiled. There was no input dialog.
 *
 * @return int - error status
 */
int onInitRecompile() {
   return(onInitTemplate());                             // same requirements as for onInitTemplate()
}


/**
 * Initialization post-processing hook. Not called if the reason-specific event handler returned with an error.
 *
 * @return int - error status
 */
int afterInit() {
   CreateStatusBox();
   SS.All();

   if (IsTesting()) {
      string section = __NAME() +".Tester";
      tester.onStartPause        = GetConfigBool(section, "OnStartPause",        false);
      tester.onStopPause         = GetConfigBool(section, "OnStopPause",         false);
      tester.onSessionBreakPause = GetConfigBool(section, "OnSessionBreakPause", false);
      tester.onTrendChangePause  = GetConfigBool(section, "OnTrendChangePause",  false);
      tester.onTakeProfitPause   = GetConfigBool(section, "OnTakeProfitPause",   false);
      tester.onStopLossPause     = GetConfigBool(section, "OnStopLossPause",     false);
      tester.reduceStatusWrites  = GetConfigBool(section, "ReduceStatusWrites",   true);
      tester.showBreakeven       = GetConfigBool(section, "ShowBreakeven",       false);
   }
   else if (IsTestSequence() && sequence.status!=STATUS_STOPPED) {
      sequence.status = STATUS_STOPPED;                  // a finished test loaded into an online chart
   }                                                     // TODO: move to SynchronizeStatus()
   return(last_error);
}


/**
 * Create the status display box. It consists of overlapping rectangles made of char "g" in font "Webdings".
 *
 * @return int - error status
 */
int CreateStatusBox() {
   if (!__CHART()) return(NO_ERROR);

   int x[]={2, 101, 165}, y=62, fontSize=75, rectangles=ArraySize(x);
   color  bgColor = C'248,248,248';                      // that's chart background color
   string label;

   for (int i=0; i < rectangles; i++) {
      label = __NAME() +".statusbox."+ (i+1);
      if (ObjectFind(label) != 0) {
         ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
         ObjectRegister(label);
      }
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, x[i]);
      ObjectSet    (label, OBJPROP_YDISTANCE, y   );
      ObjectSetText(label, "g", fontSize, "Webdings", bgColor);
   }
   return(catch("CreateStatusBox(1)"));
}


/**
 * Backup status variables which may change by modifying input parameters. This way status can be restored in case of input
 * errors. Called only from onInitParameters().
 */
void BackupInputStatus() {
   CopyInputStatus(true);
}


/**
 * Restore status variables from the backup. Called only from onInitParameters().
 */
void RestoreInputStatus() {
   CopyInputStatus(false);
}


/**
 * Backup or restore status variables related to input parameter changes.
 *
 * @param  bool store - TRUE:  copy status to internal storage (backup)
 *                      FALSE: copy internal storage to status (restore)
 */
void CopyInputStatus(bool store) {
   store = store!=0;

   static int      _sequence.id;
   static int      _sequence.cycle;
   static string   _sequence.name = "";
   static datetime _sequence.created;
   static bool     _sequence.isTest;
   static int      _sequence.direction;
   static int      _sequence.status;

   static bool     _start.conditions;
   static bool     _start.trend.condition;
   static string   _start.trend.indicator = "";
   static int      _start.trend.timeframe;
   static string   _start.trend.params = "";
   static string   _start.trend.description = "";
   static bool     _start.price.condition;
   static int      _start.price.type;
   static double   _start.price.value;
   static string   _start.price.description = "";
   static bool     _start.time.condition;
   static datetime _start.time.value;
   static string   _start.time.description = "";

   static bool     _stop.trend.condition;
   static string   _stop.trend.indicator = "";
   static int      _stop.trend.timeframe;
   static string   _stop.trend.params = "";
   static string   _stop.trend.description = "";
   static bool     _stop.price.condition;
   static int      _stop.price.type;
   static double   _stop.price.value;
   static string   _stop.price.description = "";
   static bool     _stop.time.condition;
   static datetime _stop.time.value;
   static string   _stop.time.description = "";
   static bool     _stop.profitAbs.condition;
   static double   _stop.profitAbs.value;
   static string   _stop.profitAbs.description = "";
   static bool     _stop.profitPct.condition;
   static double   _stop.profitPct.value;
   static double   _stop.profitPct.absValue;
   static string   _stop.profitPct.description = "";

   static datetime _sessionbreak.starttime;
   static datetime _sessionbreak.endtime;

   if (store) {
      _sequence.id                = sequence.id;
      _sequence.cycle             = sequence.cycle;
      _sequence.name              = sequence.name;
      _sequence.created           = sequence.created;
      _sequence.isTest            = sequence.isTest;
      _sequence.direction         = sequence.direction;
      _sequence.status            = sequence.status;

      _start.conditions           = start.conditions;
      _start.trend.condition      = start.trend.condition;
      _start.trend.indicator      = start.trend.indicator;
      _start.trend.timeframe      = start.trend.timeframe;
      _start.trend.params         = start.trend.params;
      _start.trend.description    = start.trend.description;
      _start.price.condition      = start.price.condition;
      _start.price.type           = start.price.type;
      _start.price.value          = start.price.value;
      _start.price.description    = start.price.description;
      _start.time.condition       = start.time.condition;
      _start.time.value           = start.time.value;
      _start.time.description     = start.time.description;

      _stop.trend.condition       = stop.trend.condition;
      _stop.trend.indicator       = stop.trend.indicator;
      _stop.trend.timeframe       = stop.trend.timeframe;
      _stop.trend.params          = stop.trend.params;
      _stop.trend.description     = stop.trend.description;
      _stop.price.condition       = stop.price.condition;
      _stop.price.type            = stop.price.type;
      _stop.price.value           = stop.price.value;
      _stop.price.description     = stop.price.description;
      _stop.time.condition        = stop.time.condition;
      _stop.time.value            = stop.time.value;
      _stop.time.description      = stop.time.description;
      _stop.profitAbs.condition   = stop.profitAbs.condition;
      _stop.profitAbs.value       = stop.profitAbs.value;
      _stop.profitAbs.description = stop.profitAbs.description;
      _stop.profitPct.condition   = stop.profitPct.condition;
      _stop.profitPct.value       = stop.profitPct.value;
      _stop.profitPct.absValue    = stop.profitPct.absValue;
      _stop.profitPct.description = stop.profitPct.description;

      _sessionbreak.starttime     = sessionbreak.starttime;
      _sessionbreak.endtime       = sessionbreak.endtime;
   }
   else {
      sequence.id                = _sequence.id;
      sequence.cycle             = _sequence.cycle;
      sequence.name              = _sequence.name;
      sequence.created           = _sequence.created;
      sequence.isTest            = _sequence.isTest;
      sequence.direction         = _sequence.direction;
      sequence.status            = _sequence.status;

      start.conditions           = _start.conditions;
      start.trend.condition      = _start.trend.condition;
      start.trend.indicator      = _start.trend.indicator;
      start.trend.timeframe      = _start.trend.timeframe;
      start.trend.params         = _start.trend.params;
      start.trend.description    = _start.trend.description;
      start.price.condition      = _start.price.condition;
      start.price.type           = _start.price.type;
      start.price.value          = _start.price.value;
      start.price.description    = _start.price.description;
      start.time.condition       = _start.time.condition;
      start.time.value           = _start.time.value;
      start.time.description     = _start.time.description;

      stop.trend.condition       = _stop.trend.condition;
      stop.trend.indicator       = _stop.trend.indicator;
      stop.trend.timeframe       = _stop.trend.timeframe;
      stop.trend.params          = _stop.trend.params;
      stop.trend.description     = _stop.trend.description;
      stop.price.condition       = _stop.price.condition;
      stop.price.type            = _stop.price.type;
      stop.price.value           = _stop.price.value;
      stop.price.description     = _stop.price.description;
      stop.time.condition        = _stop.time.condition;
      stop.time.value            = _stop.time.value;
      stop.time.description      = _stop.time.description;
      stop.profitAbs.condition   = _stop.profitAbs.condition;
      stop.profitAbs.value       = _stop.profitAbs.value;
      stop.profitAbs.description = _stop.profitAbs.description;
      stop.profitPct.condition   = _stop.profitPct.condition;
      stop.profitPct.value       = _stop.profitPct.value;
      stop.profitPct.absValue    = _stop.profitPct.absValue;
      stop.profitPct.description = _stop.profitPct.description;

      sessionbreak.starttime     = _sessionbreak.starttime;
      sessionbreak.endtime       = _sessionbreak.endtime;
   }
}
