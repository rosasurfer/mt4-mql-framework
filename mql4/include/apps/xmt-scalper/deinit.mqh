/**
 * Deinitialization
 *
 * @return int - error status
 *
 * @see  mql4/experts/XMT-Scalper.mq4
 */
int onDeinit() {
   int size = ArraySize(metrics.hSet);
   for (int i=0; i < size; i++) {
      CloseHistorySet(i);
   }

   if (IsTesting()) {
      if (!last_error || last_error==ERR_CANCELLED_BY_USER) {
         if (IsLogInfo()) {
            if (tradingMode!=TRADINGMODE_REGULAR || virt.closedPositions) logInfo("onDeinit(1)  "+ sequence.name +" test stop: "+ virt.closedPositions +" virtual trade"+ Pluralize(virt.closedPositions) +", pl="+ DoubleToStr(virt.closedPl, 2) +", plNet="+ DoubleToStr(virt.closedPlNet, 2));
            if (tradingMode!=TRADINGMODE_VIRTUAL || real.closedPositions) logInfo("onDeinit(2)  "+ sequence.name +" test stop: "+ real.closedPositions +" real trade"+ Pluralize(real.closedPositions) +", pl="+ DoubleToStr(real.closedPl, 2) +", plNet="+ DoubleToStr(real.closedPlNet, 2));
         }
         if (!SaveStatus()) return(last_error);
      }
   }
   return(catch("onDeinit(2)"));
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
