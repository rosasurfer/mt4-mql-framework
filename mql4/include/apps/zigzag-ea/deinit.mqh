/**
 * Deinitialization
 *
 * @return int - error status
 *
 * @see  "mql4/experts/ZigZag EA.mq4"
 */
int onDeinit() {
   if (IsTesting()) {
      if (!last_error && sequence.status!=STATUS_STOPPED) {
         bool success = true;
         if (sequence.status == STATUS_PROGRESSING) {
            success = UpdateStatus();
         }
         if (success) StopSequence(NULL);
         ShowStatus();
      }
      return(last_error);
   }
   return(NO_ERROR);
}


/**
 * Called before input parameters change.
 *
 * @return int - error status
 */
int onDeinitParameters() {
   BackupInputs();
   return(-1);                                                    // -1: skip all other deinit tasks
}


/**
 * Called before the current chart symbol or timeframe change.
 *
 * @return int - error status
 */
int onDeinitChartChange() {
   BackupInputs();
   return(-1);                                                    // -1: skip all other deinit tasks
}


/**
 * Online: Called in terminal builds <= 509 when a new chart template is applied.
 *         Called when the chart profile changes.
 *         Called when the chart is closed.
 *         Called in terminal builds <= 509 when the terminal shuts down.
 * Tester: Called when the chart is closed with VisualMode="On".
 *         Called if the test was explicitly stopped by using the "Stop" button (manually or by code). Global scalar variables
 *         may contain invalid values (strings are ok).
 *
 * @return int - error status
 */
int onDeinitChartClose() {
   if (!IsTesting() && sequence.status!=STATUS_STOPPED) {
      logInfo("onDeinitChartClose(1)  "+ sequence.name +" expert unloaded in status \""+ StatusDescription(sequence.status) +"\", profit: "+ sSequenceTotalNetPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   }
   return(NO_ERROR);
}


/**
 * Online: Called in terminal builds > 509 when a new chart template is applied.
 * Tester: ???
 *
 * @return int - error status
 */
int onDeinitTemplate() {
   if (!IsTesting() && sequence.status!=STATUS_STOPPED) {
      logInfo("onDeinitTemplate(1)  "+ sequence.name +" expert unloaded in status \""+ StatusDescription(sequence.status) +"\", profit: "+ sSequenceTotalNetPL +" "+ StrReplace(sSequencePlStats, " ", ""));
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
      logInfo("onDeinitRemove(1)  "+ sequence.name +" expert removed in status \""+ StatusDescription(sequence.status) +"\", profit: "+ sSequenceTotalNetPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   }
   RemoveSequenceData();                                             // remove the sequence data stored in the chart
   return(NO_ERROR);
}


/**
 * Called in terminal builds > 509 when the terminal shuts down.
 *
 * @return int - error status
 */
int onDeinitClose() {
   if (sequence.status != STATUS_STOPPED) {
      logInfo("onDeinitClose(1)  "+ sequence.name +" terminal shutdown in status \""+ StatusDescription(sequence.status) +"\", profit: "+ sSequenceTotalNetPL +" "+ StrReplace(sSequencePlStats, " ", ""));
   }
   return(NO_ERROR);
}
