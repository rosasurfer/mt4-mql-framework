
/**
 * Nach Parameteränderung
 *
 *  - altes Chartfenster, alter EA, Input-Dialog
 *
 * @return int - Fehlerstatus
 */
int onInitParameterChange() {
   StoreConfiguration();

   if (!ValidateConfiguration(true))                                 // interactive = true
      RestoreConfiguration();

   return(last_error);
}


/**
 * Nach Symbol- oder Timeframe-Wechsel
 *
 * - altes Chartfenster, alter EA, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 */
int onInitChartChange() {
   // nicht-statische Input-Parameter restaurieren
   GridSize        = last.GridSize;
   LotSize         = last.LotSize;
   StartConditions = last.StartConditions;

   // TODO: Symbolwechsel behandeln
   return(NO_ERROR);
}


/**
 * Altes Chartfenster mit neu geladenem Template
 *
 * - neuer EA, Input-Dialog, keine Statusdaten im Chart
 *
 * @return int - Fehlerstatus
 */
int onInitChartClose() {
   ValidateConfiguration(true);                                      // interactive = true
   return(last_error);
}


/**
 * Kein UninitializeReason gesetzt
 *
 * - nach Terminal-Neustart: neues Chartfenster, vorheriger EA, kein Input-Dialog
 * - nach File->New->Chart:  neues Chartfenster, neuer EA, Input-Dialog
 * - im Tester:              neues Chartfenster bei VisualMode=On, neuer EA, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 */
int onInitUndefined() {
   // Prüfen, ob im Chart Statusdaten existieren (einziger Unterschied zwischen vorherigem und neuem EA)
   if (RestoreStickyStatus())
      return(onInitRecompile());    // ja: vorheriger EA -> kein Input-Dialog: Funktionalität entspricht onInitRecompile()

   if (IsLastError())
      return(last_error);

   return(onInitChartClose());      // nein: neuer EA    -> Input-Dialog:      Funktionalität entspricht onInitChartClose()
}


/**
 * Vorheriger EA von Hand entfernt (Chart->Expert->Remove) oder neuer EA drübergeladen
 *
 * - altes Chartfenster, neuer EA, Input-Dialog
 *
 * @return int - Fehlerstatus
 */
int onInitRemove() {
   return(onInitChartClose());                                       // Funktionalität entspricht onInitChartClose()
}


/**
 * Nach Recompilation
 *
 * - altes Chartfenster, vorheriger EA, kein Input-Dialog, Statusdaten im Chart
 *
 * @return int - Fehlerstatus
 */
int onInitRecompile() {
   // im Chart gespeicherte Daten restaurieren
   if (RestoreStickyStatus())
      ValidateConfiguration(false);                                  // interactive = false

   ClearStickyStatus();
   return(last_error);
}


/**
 * Postprocessing-Hook nach Initialisierung
 *
 * @return int - Fehlerstatus
 */
int afterInit() {
   CreateStatusBox();
   return(last_error);
}


/**
 * Die Statusbox besteht aus untereinander angeordneten Quadraten (Font "Webdings", Zeichen 'g').
 *
 * @return int - Fehlerstatus
 */
int CreateStatusBox() {
   if (!IsChart)
      return(false);

   int x=0, y[]={33, 66}, fontSize=115, rectangles=ArraySize(y);
   color  bgColor = C'248,248,248';                                  // entspricht Chart-Background
   string label;

   for (int i=0; i < rectangles; i++) {
      label = StringConcatenate(__NAME__, ".statusbox."+ (i+1));
      if (ObjectFind(label) != 0) {
         if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))
            return(!catch("CreateStatusBox(1)"));
         ObjectRegister(label);
      }
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, x   );
      ObjectSet    (label, OBJPROP_YDISTANCE, y[i]);
      ObjectSetText(label, "g", fontSize, "Webdings", bgColor);
   }
   return(!catch("CreateStatusBox(2)"));
}
