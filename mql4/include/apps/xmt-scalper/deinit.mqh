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

      switch (tradingMode) {
         case TRADING_MODE_REGULAR: logInfo("onDeinitUndefined(1)  test stop: "+ real.closedPositions +" trade"+ Pluralize(real.closedPositions) +", pl="+ DoubleToStr(real.closedPl, 2) +", plNet="+ DoubleToStr(real.closedPlNet, 2)); break;
         case TRADING_MODE_VIRTUAL: logInfo("onDeinitUndefined(2)  test stop: "+ virt.closedPositions +" trade"+ Pluralize(virt.closedPositions) +", pl="+ DoubleToStr(virt.closedPl, 2) +", plNet="+ DoubleToStr(virt.closedPlNet, 2)); break;
         case TRADING_MODE_MIRROR:  break;
      }
      return(catch("onDeinitUndefined(3)"));
   }
   return(catch("onDeinitUndefined(4)", ERR_UNDEFINED_STATE));       // do what the Expander would do
}

