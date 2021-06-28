/**
 * Called before input parameters are changed.
 *
 * @return int - error status
 *
 * @see  mql4/experts/Duel.mq4
 */
int onDeinitParameters() {
   BackupInputs();
   return(-1);                                                       // -1: skip all other deinit tasks
}


/**
 * Called before the current chart symbol or timeframe are changed.
 *
 * @return int - error status
 */
int onDeinitChartChange() {
   BackupInputs();
   return(-1);                                                       // -1: skip all other deinit tasks
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

      if (sequence.status == STATUS_PROGRESSING) {
         if (IsLogDebug()) logDebug("onDeinitUndefined(1)  "+ sequence.name +" test stopped in status "+ DoubleQuoteStr(StatusDescription(sequence.status)));
      }
      if (!SaveStatus()) return(last_error);
      return(catch("onDeinitUndefined(2)"));
   }
   return(catch("onDeinitUndefined(3)", ERR_UNDEFINED_STATE));       // do what the Expander would do
}

