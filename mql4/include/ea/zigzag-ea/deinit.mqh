
/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   if (__isTesting) {
      if (!last_error && instance.status!=STATUS_STOPPED) {
         bool success = true;
         if (instance.status == STATUS_TRADING) {
            success = UpdateStatus();
         }
         double signal[] = {0,0,0};
         if (success) StopInstance(signal);
         RecordMetrics();
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
   if (!__isTesting && instance.status!=STATUS_STOPPED) {
      SS.TotalProfit(ShowProfitInPercent);
      SS.ProfitStats(ShowProfitInPercent);
      logInfo("onDeinitChartClose(1)  "+ instance.name +" expert unloaded in status \""+ StatusDescription(instance.status) +"\", profit: "+ sTotalProfit +" "+ sProfitStats);
      SaveStatus();
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
   if (!__isTesting && instance.status!=STATUS_STOPPED) {
      SS.TotalProfit(ShowProfitInPercent);
      SS.ProfitStats(ShowProfitInPercent);
      logInfo("onDeinitTemplate(1)  "+ instance.name +" expert unloaded in status \""+ StatusDescription(instance.status) +"\", profit: "+ sTotalProfit +" "+ sProfitStats);
      SaveStatus();
   }
   return(NO_ERROR);
}


/**
 * Called when the expert is manually removed (Chart->Expert->Remove) or replaced.
 *
 * @return int - error status
 */
int onDeinitRemove() {
   if (instance.status != STATUS_STOPPED) {
      SS.TotalProfit(ShowProfitInPercent);
      SS.ProfitStats(ShowProfitInPercent);
      logInfo("onDeinitRemove(1)  "+ instance.name +" expert removed in status \""+ StatusDescription(instance.status) +"\", profit: "+ sTotalProfit +" "+ sProfitStats);
      SaveStatus();
   }
   RemoveVolatileStatus();                                           // remove a stored instance id
   return(NO_ERROR);
}


/**
 * Called in terminal builds > 509 when the terminal shuts down.
 *
 * @return int - error status
 */
int onDeinitClose() {
   if (instance.status != STATUS_STOPPED) {
      SS.TotalProfit(ShowProfitInPercent);
      SS.ProfitStats(ShowProfitInPercent);
      logInfo("onDeinitClose(1)  "+ instance.name +" terminal shutdown in status \""+ StatusDescription(instance.status) +"\", profit: "+ sTotalProfit +" "+ sProfitStats);
      SaveStatus();
   }
   return(NO_ERROR);
}
