
/**
 * Neu geladener EA. Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInitUser() {
   ValidateConfig(true);                                      // interactive = true
   return(last_error);
}


/**
 * EA durch Template geladen. Kein Input-Dialog. Statusdaten im Chart.
 *
 * @return int - Fehlerstatus
 */
int onInitTemplate() {
   // im Chart gespeicherte Daten restaurieren
   if (RestoreRuntimeStatus())
      ValidateConfig(false);                                  // interactive = false

   ResetRuntimeStatus();
   return(last_error);
}


/**
 * Nach Parameteränderung. Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInitParameters() {
   StoreConfiguration();

   if (!ValidateConfig(true))                                 // interactive = true
      RestoreConfiguration();

   return(last_error);
}


/**
 * Nach Timeframe-Wechsel. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInitTimeframeChange() {
   // nicht-statische Input-Parameter restaurieren
   GridSize        = last.GridSize;
   LotSize         = last.LotSize;
   StartConditions = last.StartConditions;
   return(NO_ERROR);
}


/**
 * Nach Symbolwechsel. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInitSymbolChange() {
   return(SetLastError(ERR_CANCELLED_BY_USER));
}


/**
 * Nach Recompilation. Kein Input-Dialog. Statusdaten im Chart.
 *
 * @return int - Fehlerstatus
 */
int onInitRecompile() {
   return(onInitTemplate());                                         // Funktionalität entspricht onInitTemplate()
}
