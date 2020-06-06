
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
 * Online:    - Called when another chart template is applied.
 *            - Called when the chart profile is changed.
 *            - Called when the chart is closed.
 *            - Called in terminal versions up to build 509 when the terminal shuts down.
 * In tester: - Called if the test was explicitly stopped by using the "Stop" button (manually or by code).
 *            - Called when the chart is closed (with VisualMode=On).
 *
 * @return int - error status
 */
int onDeinitChartClose() {
   if (IsTesting()) {
      // start() was interrupted by the "Stop" button and primitive vars (bool, int, double) may contain invalid values
      if (!IsLastError())
         SetLastError(ERR_CANCELLED_BY_USER);
      return(last_error);
   }

   // online
   StoreChartStatus();                                            // for profile changes and terminal restart
   return(last_error);
}


/**
 * Online:    Never encountered, and therefore tracked in Expander::onDeinitUndefined().
 * In tester: Called if a test finished regularily, i.e. the test period ended.
 *
 * @return int - error status
 */
int onDeinitUndefined() {
   if (IsTesting()) {
      if (IsLastError())
         return(onDeinitChartClose());                            // same as a test interruption

      bool success = true;
      if (sequence.status == STATUS_PROGRESSING) {
         bool bNull;
         success = UpdateStatus(bNull);
      }
      if (sequence.status==STATUS_WAITING || sequence.status==STATUS_PROGRESSING) {
         if (success) StopSequence(NULL);
         ShowStatus();
      }
      return(last_error);
   }
   return(catch("onDeinitUndefined(1)", ERR_RUNTIME_ERROR));      // do what the Expander would do
}


/**
 * Called before an expert is reloaded after recompilation.
 *
 * @return int - error status
 */
int onDeinitRecompile() {
   StoreChartStatus();
   return(-1);                                                    // -1: skip all other deinit tasks
}


/**
 * Called in terminal versions > build 509 when the terminal shuts down.
 *
 * @return int - error status
 */
int onDeinitClose() {
   StoreChartStatus();
   return(last_error);
}
