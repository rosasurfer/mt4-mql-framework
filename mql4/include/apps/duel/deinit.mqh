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
 * Called if a test finished regularily, i.e. the test period ended.
 * Called if a test prematurely stopped because of a margin stopout (enforced by the tester).
 *
 * @return int - error status
 */
int onDeinitUndefined() {
   if (IsTesting()) {
      if (IsLastError()) return(last_error);

      if (sequence.status == STATUS_PROGRESSING) {
         logDebug("onDeinitUndefined(1)  "+ sequence.name +" test stopped in status "+ DoubleQuoteStr(StatusDescription(sequence.status)));
      }
      if (!SaveStatus()) return(last_error);
      return(catch("onDeinitUndefined(2)"));
   }
   return(catch("onDeinitUndefined(3)", ERR_UNDEFINED_STATE));       // never encountered, do what the Expander would do
}


/**
 * Online: Called in terminal builds <= 509 when another chart template is applied.
 *         Called when the chart profile is changed.
 *         Called when the chart is closed.
 *         Called in terminal builds <= 509 when the terminal shuts down.
 * Tester: Called when the chart is closed with VisualMode="On".
 *         Called if the test was explicitly stopped by using the "Stop" button (manually or by code). Global scalar variables
 *          may contain invalid values (strings are ok).
 *
 * @return int - error status
 */
int onDeinitChartClose() {
   if (!IsTesting()) {
      if (sequence.status != STATUS_STOPPED) {
         logInfo("onDeinitChartClose(1)  "+ sequence.name +" expert unloaded in status "+ DoubleQuoteStr(StatusDescription(sequence.status)) +", profit: "+ sSequenceTotalPL +" "+ StrReplace(sSequencePlStats, " ", ""));
      }
   }
   return(NO_ERROR);
}


/**
 * Online: Called in terminal builds > 509 when another chart template is applied.
 * Tester: ???
 *
 * @return int - error status
 */
int onDeinitTemplate() {
   if (!IsTesting()) {
      if (sequence.status != STATUS_STOPPED) {
         logInfo("onDeinitTemplate(1)  "+ sequence.name +" expert unloaded in status "+ DoubleQuoteStr(StatusDescription(sequence.status)) +", profit: "+ sSequenceTotalPL +" "+ StrReplace(sSequencePlStats, " ", ""));
      }
   }
   return(NO_ERROR);
}


/**
 * Called when the expert is manually removed (Chart->Expert->Remove) or replaced.
 *
 * @return int - error status
 */
int onDeinitRemove() {
   if (sequence.status != STATUS_STOPPED) {
      logInfo("onDeinitRemove(1)  "+ sequence.name +" expert removed in status "+ DoubleQuoteStr(StatusDescription(sequence.status)) +", profit: "+ sSequenceTotalPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   }
   return(NO_ERROR);
}


/**
 * Called in terminal builds > 509 when the terminal shuts down.
 *
 * @return int - error status
 */
int onDeinitClose() {
   if (sequence.status != STATUS_STOPPED) {
      logInfo("onDeinitClose(1)  "+ sequence.name +" terminal shutdown in status "+ DoubleQuoteStr(StatusDescription(sequence.status)) +", profit: "+ sSequenceTotalPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   }
   return(NO_ERROR);
}
