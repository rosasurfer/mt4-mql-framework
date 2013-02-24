
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
   bool interactive = true;
   ValidateConfiguration(interactive);
   return(last_error);
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
 * Kein UninitializeReason gesetzt
 *
 * - nach Terminal-Neustart: neues Chartfenster, vorheriger EA, kein Input-Dialog
 * - nach File->New->Chart:  neues Chartfenster, neuer EA, Input-Dialog
 * - im Tester:              neues Chartfenster bei VisualMode=On, neuer EA, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 */
int onInitUndefined() {
   // Prüfen, ob im Chart Statusdaten existieren (einziger Unterschied zwischen vorherigem/neuem EA)
   if (RestoreStickyStatus())
      return(onInitRecompile());    // ja:   vorheriger EA -> kein Input-Dialog: Funktionalität entspricht onInitRecompile()

   if (__STATUS_ERROR)
      return(last_error);

   return(onInitChartClose());      // nein: neuer EA      -> Input-Dialog:      Funktionalität entspricht onInitChartClose()
}


/**
 * Nach Recompilation
 *
 * - altes Chartfenster, vorheriger EA, kein Input-Dialog, Statusdaten im Chart
 *
 * @return int - Fehlerstatus
 */
int onInitRecompile() {
   bool interactive = false;

   // im Chart gespeicherte Daten restaurieren
   if (RestoreStickyStatus())
      ValidateConfiguration(interactive);

   ClearStickyStatus();
   return(last_error);
}
