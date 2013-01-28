
/**
 * Parameteränderung
 *
 * @return int - Fehlerstatus
 */
int onDeinitParameterChange() {
   // nicht-statische Input-Parameter für Vergleich mit neuen Werten zwischenspeichern
   last.Sequence.ID             = StringConcatenate(Sequence.ID,             "");   // Pointer-Bug bei String-Inputvariablen (siehe MQL.doc)
   last.Sequence.StatusLocation = StringConcatenate(Sequence.StatusLocation, "");
   last.GridDirection           = StringConcatenate(GridDirection,           "");
   last.GridSize                = GridSize;
   last.LotSize                 = LotSize;
   last.StartConditions         = StringConcatenate(StartConditions,         "");
   last.StopConditions          = StringConcatenate(StopConditions,          "");
   last.Breakeven.Color         = Breakeven.Color;
   return(-1);
}


/**
 * EA von Hand entfernt (Chart -> Expert -> Remove) oder neuer EA drübergeladen
 *
 * @return int - Fehlerstatus
 */
int onDeinitRemove() {
   // Der Status kann sich seit dem letzten Tick geändert haben.
   if (!IsTest()) /*&&*/ if (status==STATUS_WAITING || status==STATUS_STARTING || status==STATUS_PROGRESSING || status==STATUS_STOPPING) {
      UpdateStatus(bNull, bNull, iNulls);
      SaveStatus();
   }
   return(last_error);
}


/**
 * Symbol- oder Timeframewechsel
 *
 * @return int - Fehlerstatus
 */
int onDeinitChartChange() {
   // nicht-statische Input-Parameter zwischenspeichern
   return(onDeinitParameterChange());                                // entspricht onDeinitParameterChange()
}


/**
 * - Chart geschlossen                       -oder-
 * - Template wird neu geladen               -oder-
 * - Terminal-Shutdown                       -oder-
 * - im Tester nach Betätigen des "Stop"-Buttons oder nach Chart ->Close
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: Der "Stop"-Button des Testers kann vom Code "betätigt" worden sein (nach Fehler oder Testabschluß).
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
      if (__STATUS_ERROR) {
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


   // (2) Nicht im Tester:  Der Status kann sich seit dem letzten Tick geändert haben.
   if (!IsTest()) /*&&*/ if (status==STATUS_WAITING || status==STATUS_STARTING || status==STATUS_PROGRESSING || status==STATUS_STOPPING) {
      UpdateStatus(bNull, bNull, iNulls);
      SaveStatus();
   }
   StoreStickyStatus();                                              // für Terminal-Restart oder Profile-Wechsel
   return(last_error);
}


/**
 * Kein UninitializeReason gesetzt: im Tester nach regulärem Ende (Testperiode zu Ende)
 *
 * @return int - Fehlerstatus
 */
int onDeinitUndefined() {
   if (IsTesting()) {
      if (__STATUS_ERROR)
         return(onDeinitChartClose());                               // entspricht gewaltsamen Ende

      if (status==STATUS_WAITING || status==STATUS_PROGRESSING) {
         if (UpdateStatus(bNull, bNull, iNulls))
            StopSequence();                                          // ruft intern SaveStatus() auf
         ShowStatus();
      }
      return(last_error);
   }
   return(catch("onDeinitUndefined()", ERR_RUNTIME_ERROR));          // mal schaun, wer hier wann reintappt
}


/**
 * Recompilation
 *
 * @return int - Fehlerstatus
 */
int onDeinitRecompile() {
   StoreStickyStatus();
   return(-1);
}
