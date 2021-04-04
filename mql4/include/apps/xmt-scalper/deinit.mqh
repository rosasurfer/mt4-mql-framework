/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   int size = ArraySize(metrics.hSet);
   bool success = true;

   for (int i=0; i < size; i++) {
      if (metrics.hSet[i] != 0) {
         if      (i <  6) success = success && HistorySet1.Close(metrics.hSet[i]);
         else if (i < 12) success = success && HistorySet2.Close(metrics.hSet[i]);
         else             success = success && HistorySet3.Close(metrics.hSet[i]);
         metrics.hSet[i] = NULL;
      }
   }
   return(ifInt(success, NO_ERROR, __ExecutionContext[EC.mqlError]));      // an error is a library error
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
         if (tradingMode != TRADINGMODE_REGULAR) logInfo("onDeinitUndefined(1)  "+ sequence.name +" test stop: "+ virt.closedPositions +" virtual trade"+ Pluralize(virt.closedPositions) +", pl="+ DoubleToStr(virt.closedPl, 2) +", plNet="+ DoubleToStr(virt.closedPlNet, 2));
         if (tradingMode != TRADINGMODE_VIRTUAL) logInfo("onDeinitUndefined(2)  "+ sequence.name +" test stop: "+ real.closedPositions +" real trade"+ Pluralize(real.closedPositions) +", pl="+ DoubleToStr(real.closedPl, 2) +", plNet="+ DoubleToStr(real.closedPlNet, 2));
      }
      if (!SaveStatus()) return(last_error);

      return(catch("onDeinitUndefined(3)"));
   }
   return(catch("onDeinitUndefined(4)", ERR_UNDEFINED_STATE));             // do what the Expander would do
}

