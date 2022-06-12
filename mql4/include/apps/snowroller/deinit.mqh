/**
 * Called before input parameters are changed.
 *
 * @return int - error status
 */
int onDeinitParameters() {
   BackupInputs();
   return(-1);                                                    // -1: skip all other deinit tasks
}


/**
 * Called before the current chart symbol or timeframe are changed.
 *
 * @return int - error status
 */
int onDeinitChartChange() {
   BackupInputs();
   return(-1);                                                    // -1: skip all other deinit tasks
}


/**
 * Online: - Called when a new chart template is applied.
 *         - Called when the chart profile changes.
 *         - Called when the chart is closed.
 *         - Called in terminal builds <= 509 when the terminal shuts down.
 * Tester: - Called when the chart is closed (with VisualMode=On).
 *         - Called if the test was explicitly stopped by using the "Stop" button (manually or by code). Scalar variables
 *           may contain invalid values (strings are ok).
 *
 * @return int - error status
 */
int onDeinitChartClose() {
   if (IsTesting()) {
      if (!IsLastError()) SetLastError(ERR_CANCELLED_BY_USER);
   }
   else {
      // online
      StoreSequenceId();                                          // for profile changes and terminal restart
   }
   return(catch("onDeinitChartClose(1)"));
}


/**
 * Online: - Never encountered. Tracked in MT4Expander::onDeinitUndefined().
 * Tester: - Called if a test finished regularily, i.e. the test period ended.
 *         - Called if a test prematurely stopped because of a margin stopout (enforced by the tester).
 *
 * @return int - error status
 */
int onDeinitUndefined() {
   if (IsTesting()) {
      if (IsLastError()) return(last_error);

      bool success = true;
      if (sequence.status == STATUS_PROGRESSING) {
         bool bNull;
         success = UpdateStatus(bNull);
      }
      if (sequence.status==STATUS_WAITING || sequence.status==STATUS_PROGRESSING) {
         if (success) StopSequence(NULL);
         ShowStatus();
      }
      return(catch("onDeinitUndefined(1)"));
   }
   return(catch("onDeinitUndefined(2)", ERR_UNDEFINED_STATE));       // do what the Expander would do
}


/**
 * Called before an expert is reloaded after recompilation.
 *
 * @return int - error status
 */
int onDeinitRecompile() {
   StoreSequenceId();
   return(-1);                                                       // -1: skip all other deinit tasks
}


/**
 * Called when the expert is manually removed (Chart->Expert->Remove) or replaced.
 *
 * @return int - error status
 */
int onDeinitRemove() {
   RemoveSequenceId();                                               // remove a stored sequence id
   return(NO_ERROR);
}


/**
 * Called in terminal builds > 509 when the terminal shuts down.
 *
 * @return int - error status
 */
int onDeinitClose() {
   StoreSequenceId();
   return(last_error);
}
