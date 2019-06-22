
/**
 * Called before the input parameters are changed.
 *
 * @return int - error status
 */
int onDeinitParameterChange() {
   // nicht-statische Input-Parameter für Vergleich mit neuen Werten zwischenspeichern
   last.Sequence.ID             = StringConcatenate(Sequence.ID,             "");   // String-Inputvariablen sind C-Literale und read-only (siehe MQL.doc)
   last.Sequence.StatusLocation = StringConcatenate(Sequence.StatusLocation, "");
   last.GridDirection           = StringConcatenate(GridDirection,           "");
   last.GridSize                = GridSize;
   last.LotSize                 = LotSize;
   last.StartConditions         = StringConcatenate(StartConditions,         "");
   last.StopConditions          = StringConcatenate(StopConditions,          "");
   return(-1);
}


/**
 * Called before the current chart symbol or period are changed.
 *
 * @return int - error status
 */
int onDeinitChartChange() {
   // nicht-statische Input-Parameter zwischenspeichern
   return(onDeinitParameterChange());                                // entspricht onDeinitParameterChange()
}


/**
 * Online:    - Called when another chart template is applied.
 *            - Called when the chart profile is changed.
 *            - Called when the chart is closed.
 *            - Called when the terminal shuts down.
 * In tester: - Called if the test was explicitly stopped by using the "Stop" button (manually or by code).
 *            - Called on VisualMode=On when the chart is closed.
 *
 * @return int - error status
 */
int onDeinitChartClose() {
   // (1) Im Tester
   if (IsTesting()) {
      /**
       * !!! Vorsicht: Die start()-Funktion wurde gewaltsam beendet, die primitiven Variablen können Datenmüll enthalten !!!
       *
       * Das Flag "Statusfile nicht löschen" kann nicht über primitive Variablen oder den Chart kommuniziert werden.
       *  => Strings/Arrays testen (ansonsten globale Variable mit Thread-ID)
       */
      if (IsLastError()) {
         // Statusfile löschen
         FileDelete(GetMqlStatusFileName());
         GetLastError();                                             // falls in FileDelete() ein Fehler auftrat

         // Der Fenstertitel des Testers kann nicht zurückgesetzt werden: SendMessage() führt in deinit() zu Deadlock.
      }
      else {
         SetLastError(ERR_CANCELLED_BY_USER);
      }
      return(last_error);
   }


   // (2) Nicht im Tester
   StoreRuntimeStatus();                                             // für Terminal-Restart oder Profilwechsel
   return(last_error);
}


/**
 * Online:    Never encountered. By default tracked in Expander::onDeinitUndefined().
 * In tester: Called if a test finished regularily, i.e. the test period ended.
 *
 * @return int - error status
 */
int onDeinitUndefined() {
   if (IsTesting()) {
      if (IsLastError())
         return(onDeinitChartClose());                               // entspricht gewaltsamen Ende

      if (status==STATUS_WAITING || status==STATUS_PROGRESSING) {
         bool bNull;
         int  iNull[];
         if (UpdateStatus(bNull, iNull))
            StopSequence();                                          // ruft intern SaveStatus() auf
         ShowStatus();
      }
      return(last_error);
   }
   return(catch("onDeinitUndefined(1)", ERR_RUNTIME_ERROR));         // do what the Expander would do
}


/**
 * Online:    Called if an expert is manually removed (Chart->Expert->Remove) or replaced.
 * In tester: Never called.
 *
 * @return int - error status
 */
int onDeinitRemove() {
   DeleteRegisteredObjects(NULL);
   return(NO_ERROR);
}


/**
 * Called before an expert is reloaded after recompilation.
 *
 * @return int - error status
 */
int onDeinitRecompile() {
   StoreRuntimeStatus();
   return(-1);
}
