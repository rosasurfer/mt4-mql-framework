/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   if (metrics.hSetEquity != 0) {
      int tmp=metrics.hSetEquity; metrics.hSetEquity=NULL;
      if (!HistorySet.Close(tmp)) return(__ExecutionContext[EC.mqlError]);    // that's a library error
   }
   return(NO_ERROR);
}


/**
 * Online: Never encountered. Tracked in MT4Expander::onDeinitUndefined().
 * Tester: Called if a test finished regularily, i.e. the test period ended.
 *         Called if a test prematurely stopped because of a margin stopout (enforced by the tester).
 *
 * @return int - error status
 */
int onDeinitUndefined() {
   if (IsTesting()) {
      if (IsLastError()) return(last_error);

      if (IsLogInfo()) {
         if (tradingMode != TRADINGMODE_REGULAR) logInfo("onDeinitUndefined(1)  test stop: "+ virt.closedPositions +" virtual trade"+ Pluralize(virt.closedPositions) +", pl="+ DoubleToStr(virt.closedPl, 2) +", plNet="+ DoubleToStr(virt.closedPlNet, 2));
         if (tradingMode != TRADINGMODE_VIRTUAL) logInfo("onDeinitUndefined(2)  test stop: "+ real.closedPositions +" real trade"+ Pluralize(real.closedPositions) +", pl="+ DoubleToStr(real.closedPl, 2) +", plNet="+ DoubleToStr(real.closedPlNet, 2));
      }
      return(catch("onDeinitUndefined(3)"));
   }
   return(catch("onDeinitUndefined(4)", ERR_UNDEFINED_STATE));                // do what the Expander would do
}

