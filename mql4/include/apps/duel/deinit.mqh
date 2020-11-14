/**
 * Called before input parameters are changed.
 *
 * @return int - error status
 */
int onDeinitParameters() {
   BackupInputs();
   return(-1);                                                 // -1: skip all other deinit tasks
}


/**
 * Called before the current chart symbol or timeframe are changed.
 *
 * @return int - error status
 */
int onDeinitChartChange() {
   BackupInputs();
   return(-1);                                                 // -1: skip all other deinit tasks
}
