
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
      if (RestoreStatus())
         if (ValidateInputs(interactive))
            SynchronizeStatus();
      return(last_error);
   }
   else if (StringLen(StrTrim(Sequence.ID)) > 0) {
      return(last_error);                                   // Falscheingabe
   }

   // ...dann laufende Sequenzen suchen und ggf. eine davon restaurieren...
   int ids[], button;

   if (GetRunningSequences(ids)) {
      int sizeOfIds = ArraySize(ids);
      for (int i=0; i < sizeOfIds; i++) {
         PlaySoundEx("Windows Notify.wav");
         button = MessageBoxEx(__NAME(), ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Running sequence"+ ifString(sizeOfIds==1, " ", "s ") + JoinInts(ids, ", ") +" found.\n\nDo you want to load "+ ifString(sizeOfIds==1, "it", ids[i]) +"?", MB_ICONQUESTION|MB_YESNOCANCEL);
         if (button == IDYES) {
            sequence.isTest = false;
            sequence.id     = ids[i];
            Sequence.ID     = sequence.id; SS.SequenceId();
            sequence.name   = StrLeft(directionDescr[sequence.direction], 1) +"."+ sequence.id;
            sequence.status = STATUS_WAITING;
            SetCustomLog(sequence.id, NULL);
            if (RestoreStatus())                            // TODO: Erkennen, ob einer der anderen Parameter von Hand geändert wurde und
               if (ValidateInputs(false))                   //       sofort nach neuer Sequenz fragen.
                  SynchronizeStatus();
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
      sequence.isTest  = IsTesting();
      sequence.id      = CreateSequenceId();
      Sequence.ID      = ifString(IsTestSequence(), "T", "") + sequence.id; SS.SequenceId();
      sequence.created = GmtTimeFormat(TimeServer(), "%a, %Y.%m.%d %H:%M:%S");
      sequence.name    = StrLeft(directionDescr[sequence.direction], 1) +"."+ sequence.id;
      sequence.status  = STATUS_WAITING;
      InitStatusLocation();
      SetCustomLog(sequence.id, statusDirectory + statusFile);

      if (start.conditions) {                               // without start conditions StartSequence() is called immediately and saves
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
   bool interactive = false;

   // im Chart gespeicherte Sequenz restaurieren
   if (RestoreRuntimeStatus()) {
      if (RestoreStatus())
         if (ValidateInputs(interactive))
            SynchronizeStatus();
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
   BackupInputStatus();                                     // inputs itself have been backed-up in onDeinitParameterChange()

   bool interactive = true;
   if (!ValidateInputs(interactive)) {
      RestoreInputs();
      RestoreInputStatus();
      return(last_error);
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
   return(SetLastError(ERR_CANCELLED_BY_USER));
}


/**
 * Called after the expert was recompiled. There was no input dialog.
 *
 * @return int - error status
 */
int onInitRecompile() {
   return(onInitTemplate());                                // Funktionalität entspricht onInitTemplate()
}


/**
 * Initialization post-processing hook. Called only if neither the pre-processing hook nor the reason-specific event handler
 * returned with -1 (which signals a hard stop as opposite to a regular error).
 *
 * @return int - error status
 */
int afterInit() {
   CreateStatusBox();
   SS.All();
   return(last_error);
}


/**
 * Create the status display box. It consists of overlapping rectangles made of char "g" in font "Webdings".
 *
 * @return int - error status
 */
int CreateStatusBox() {
   if (!__CHART()) return(NO_ERROR);

   int x[]={2, 101, 110}, y=25, fontSize=76, rectangles=ArraySize(x);
   color  bgColor = C'248,248,248';                         // that's chart background color
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
 * Backup input parameter related status variables before parameter changes. In case of input errors the variables can be
 * restored afterwards. Called only from onInitParameters().
 */
void BackupInputStatus() {
   CopyInputStatus(true);
}


/**
 * Restore input parameter related status variables. Called only from onInitParameters().
 */
void RestoreInputStatus() {
   CopyInputStatus(false);
}


/**
 * Backup or restore input parameter related status variables. These are all variables which change if one or more input
 * parameters change. Or in other words all variables modified by ValidateInputs().
 *
 * @param  bool store - TRUE:  copy global values to internal storage (backup)
 *                      FALSE: copy internal values to global storage (restore)
 */
void CopyInputStatus(bool store) {
   store = store!=0;

   static int      _sequence.id;
   static string   _sequence.created;
   static string   _sequence.name;
   static bool     _sequence.isTest;
   static int      _sequence.direction;

   static bool     _start.conditions;
   static bool     _start.price.condition;
   static int      _start.price.type;
   static double   _start.price.value;
   static bool     _start.time.condition;
   static datetime _start.time.value;

   static bool     _stop.price.condition;
   static int      _stop.price.type;
   static double   _stop.price.value;
   static bool     _stop.time.condition;
   static datetime _stop.time.value;
   static bool     _stop.profitAbs.condition;
   static double   _stop.profitAbs.value;
   static bool     _stop.profitPct.condition;
   static double   _stop.profitPct.value;
   static double   _stop.profitPct.absValue;

   static datetime _sessionbreak.starttime;
   static datetime _sessionbreak.endtime;

   if (store) {
      _sequence.id              = sequence.id;
      _sequence.created         = sequence.created;
      _sequence.name            = sequence.name;
      _sequence.isTest          = sequence.isTest;
      _sequence.direction       = sequence.direction;

      _start.conditions         = start.conditions;
      _start.price.condition    = start.price.condition;
      _start.price.type         = start.price.type;
      _start.price.value        = start.price.value;
      _start.time.condition     = start.time.condition;
      _start.time.value         = start.time.value;

      _stop.price.condition     = stop.price.condition;
      _stop.price.type          = stop.price.type;
      _stop.price.value         = stop.price.value;
      _stop.time.condition      = stop.time.condition;
      _stop.time.value          = stop.time.value;
      _stop.profitAbs.condition = stop.profitAbs.condition;
      _stop.profitAbs.value     = stop.profitAbs.value;
      _stop.profitPct.condition = stop.profitPct.condition;
      _stop.profitPct.value     = stop.profitPct.value;
      _stop.profitPct.absValue  = stop.profitPct.absValue;

      _sessionbreak.starttime   = sessionbreak.starttime;
      _sessionbreak.endtime     = sessionbreak.endtime;
   }
   else {
      sequence.id               = _sequence.id;
      sequence.created          = _sequence.created;
      sequence.name             = _sequence.name;
      sequence.isTest           = _sequence.isTest;
      sequence.direction        = _sequence.direction;

      start.conditions          = _start.conditions;
      start.price.condition     = _start.price.condition;
      start.price.type          = _start.price.type;
      start.price.value         = _start.price.value;
      start.time.condition      = _start.time.condition;
      start.time.value          = _start.time.value;

      stop.price.condition      = _stop.price.condition;
      stop.price.type           = _stop.price.type;
      stop.price.value          = _stop.price.value;
      stop.time.condition       = _stop.time.condition;
      stop.time.value           = _stop.time.value;
      stop.profitAbs.condition  = _stop.profitAbs.condition;
      stop.profitAbs.value      = _stop.profitAbs.value;
      stop.profitPct.condition  = _stop.profitPct.condition;
      stop.profitPct.value      = _stop.profitPct.value;
      stop.profitPct.absValue   = _stop.profitPct.absValue;

      sessionbreak.starttime    = _sessionbreak.starttime;
      sessionbreak.endtime      = _sessionbreak.endtime;
   }
}
