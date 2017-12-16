
/**
 * Neu geladener EA. Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit_User() {
   bool interactive = true;

   // (1) Zuerst eine angegebene Sequenz restaurieren...
   if (ValidateConfig.ID(interactive)) {
      status = STATUS_WAITING;
      if (RestoreStatus())
         if (ValidateConfig(interactive))
            SynchronizeStatus();
      return(last_error);
   }
   else if (StringLen(StringTrim(Sequence.ID)) > 0) {
      return(last_error);                                            // Falscheingabe
   }


   // (2) ...dann laufende Sequenzen suchen und ggf. eine davon restaurieren...
   int ids[], button;

   if (GetRunningSequences(ids)) {
      int sizeOfIds = ArraySize(ids);
      for (int i=0; i < sizeOfIds; i++) {
         PlaySoundEx("Windows Notify.wav");
         button = MessageBoxEx(__NAME__, ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Running sequence"+ ifString(sizeOfIds==1, " ", "s ") + JoinInts(ids, ", ") +" found.\n\nDo you want to load "+ ifString(sizeOfIds==1, "it", ids[i]) +"?", MB_ICONQUESTION|MB_YESNOCANCEL);
         if (button == IDYES) {
            isTest      = false;
            sequenceId  = ids[i];
            Sequence.ID = sequenceId; SS.Sequence.Id();
            status      = STATUS_WAITING;
            SetCustomLog(sequenceId, NULL);
            if (RestoreStatus())                                     // TODO: Erkennen, ob einer der anderen Parameter von Hand geändert wurde und
               if (ValidateConfig(false))                            //       sofort nach neuer Sequenz fragen.
                  SynchronizeStatus();
            return(last_error);
         }
         if (button == IDCANCEL)
            return(SetLastError(ERR_CANCELLED_BY_USER));
      }

      if (!ConfirmFirstTickTrade("", "Do you want to start a new sequence?"))
         return(SetLastError(ERR_CANCELLED_BY_USER));
   }


   // (3) ...zum Schluß neue Sequenz anlegen.
   if (ValidateConfig(true)) {
      isTest      = IsTesting();
      sequenceId  = CreateSequenceId();
      Sequence.ID = ifString(IsTest(), "T", "") + sequenceId; SS.Sequence.Id();
      status      = STATUS_WAITING;
      InitStatusLocation();
      SetCustomLog(sequenceId, status.directory + status.file);

      if (start.conditions)                                          // Ohne StartConditions speichert der sofortige Sequenzstart automatisch.
         SaveStatus();
      RedrawStartStop();
   }
   return(last_error);
}


/**
 * EA durch Template geladen. Kein Input-Dialog. Statusdaten im Chart.
 *
 * @return int - Fehlerstatus
 */
int onInit_Template() {
   bool interactive = false;

   // im Chart gespeicherte Sequenz restaurieren
   if (RestoreRuntimeStatus()) {
      if (RestoreStatus())
         if (ValidateConfig(interactive))
            SynchronizeStatus();
   }
   ResetRuntimeStatus();
   return(last_error);
}


/**
 * Nach Parameteränderung. Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit_Parameters() {
   bool interactive = true;

   StoreConfiguration();

   if (!ValidateConfig(interactive)) {                               // interactive = true
      RestoreConfiguration();
      return(last_error);
   }

   if (status == STATUS_UNINITIALIZED) {
      // neue Sequenz anlegen
      isTest      = IsTesting();
      sequenceId  = CreateSequenceId();
      Sequence.ID = ifString(IsTest(), "T", "") + sequenceId; SS.Sequence.Id();
      status      = STATUS_WAITING;
      InitStatusLocation();
      SetCustomLog(sequenceId, status.directory + status.file);

      if (start.conditions)                                          // Ohne StartConditions speichert der sofortige Sequenzstart automatisch.
         SaveStatus();
      RedrawStartStop();
   }
   else {
      // Parameteränderung einer existierenden Sequenz
      SaveStatus();
   }
   return(last_error);
}


/**
 * Nach Timeframe-Wechsel. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit_TimeframeChange() {
   // nicht-statische Input-Parameter restaurieren
   Sequence.ID             = last.Sequence.ID;
   Sequence.StatusLocation = last.Sequence.StatusLocation;
   GridDirection           = last.GridDirection;
   GridSize                = last.GridSize;
   LotSize                 = last.LotSize;
   StartConditions         = last.StartConditions;
   StopConditions          = last.StopConditions;
   return(NO_ERROR);
}


/**
 * Nach Symbolwechsel. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit_SymbolChange() {
   return(SetLastError(ERR_CANCELLED_BY_USER));
}


/**
 * Nach Recompilation. Kein Input-Dialog. Statusdaten im Chart.
 *
 * @return int - Fehlerstatus
 */
int onInit_Recompile() {
   return(onInit_Template());                                        // Funktionalität entspricht onInit_Template()
}


/**
 * Postprocessing-Hook nach Initialisierung
 *
 * @return int - Fehlerstatus
 */
int afterInit() {
   CreateStatusBox();
   SS.All();
   return(last_error);
}


/**
 * Die Statusbox besteht aus untereinander angeordneten Quadraten (Font "Webdings", Zeichen 'g').
 *
 * @return int - Fehlerstatus
 */
int CreateStatusBox() {
   if (!__CHART)
      return(NO_ERROR);

 //int x[]={0,  89, 145}, y=22, fontSize=67;                         // eine Zeile für Start/StopCondition
   int x[]={0, 101, 133}, y=22, fontSize=76;                         // zwei Zeilen für Start/StopCondition
   color color.Background = C'248,248,248';                          // entspricht Chart-Background


   // 1. Quadrat
   string label = StringConcatenate(__NAME__, ".statusbox.1");
   if (ObjectFind(label) != 0) {
      if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))
         return(catch("CreateStatusBox(1)"));
      ObjectRegister(label);
   }
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
   ObjectSet    (label, OBJPROP_XDISTANCE, x[0]);
   ObjectSet    (label, OBJPROP_YDISTANCE, y   );
   ObjectSetText(label, "g", fontSize, "Webdings", color.Background);


   // 2. Quadrat
   label = StringConcatenate(__NAME__, ".statusbox.2");
   if (ObjectFind(label) != 0) {
      if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))
         return(catch("CreateStatusBox(2)"));
      ObjectRegister(label);
   }
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
   ObjectSet    (label, OBJPROP_XDISTANCE, x[1]);
   ObjectSet    (label, OBJPROP_YDISTANCE, y   );
   ObjectSetText(label, "g", fontSize, "Webdings", color.Background);


   // 3. Quadrat (überlappt 2.)
   label = StringConcatenate(__NAME__, ".statusbox.3");
   if (ObjectFind(label) != 0) {
      if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))
         return(catch("CreateStatusBox(3)"));
      ObjectRegister(label);
   }
   ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
   ObjectSet    (label, OBJPROP_XDISTANCE, x[2]);
   ObjectSet    (label, OBJPROP_YDISTANCE, y   );
   ObjectSetText(label, "g", fontSize, "Webdings", color.Background);

   return(catch("CreateStatusBox(4)"));
}
