
/**
 * Neu geladener EA. Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit_User() {
   bool interactive = true;
   ValidateConfiguration(interactive);
   return(last_error);
}


/**
 * EA durch Template geladen. Kein Input-Dialog. Statusdaten im Chart.
 *
 * @return int - Fehlerstatus
 */
int onInit_Template() {
   bool interactive = false;

   // im Chart gespeicherte Daten restaurieren
   if (RestoreRuntimeStatus())
      ValidateConfiguration(interactive);

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

   if (!ValidateConfiguration(interactive))
      RestoreConfiguration();

   return(last_error);
}


/**
 * Nach Timeframe-Wechsel. Kein Input-Dialog.
 *
 * @return int - Fehlerstatus
 */
int onInit_TimeframeChange() {
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
