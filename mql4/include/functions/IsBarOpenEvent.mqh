/**
 * Whether the current tick represents a BarOpen event in the specified timeframe. Returns the same result if called multiple
 * times during the same tick.
 *
 * @param  int timeframe [optional] - timeframe to check (default: the current timeframe)
 *
 * @return bool
 *
 * Note: The function doesn't recognize a BarOpen event if called at the first tick after program start or recompilation.
 */
bool IsBarOpenEvent(int timeframe = NULL) {
   if (IsLibrary())                                       return(!catch("IsBarOpenEvent(1)  function can't be used in a library (ticks not available)", ERR_FUNC_NOT_ALLOWED));
   if (IsIndicator()) {
      // TODO: The check with IsSuperContext() is not sufficient, the super program must be an expert.
      if (This.IsTesting()) /*&&*/ if (!IsSuperContext()) return(!catch("IsBarOpenEvent(2)  function can'ot be used in Tester in standalone indicator (Tick.Time not available)", ERR_FUNC_NOT_ALLOWED_IN_TESTER));
   }

   static int      i, timeframes[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
   static datetime bar.openTimes[], bar.closeTimes[];                      // Open/CloseTimes of each timeframe
   if (!ArraySize(bar.openTimes)) {
      ArrayResize(bar.openTimes,  ArraySize(timeframes));
      ArrayResize(bar.closeTimes, ArraySize(timeframes));
   }

   if (!timeframe)
      timeframe = Period();

   switch (timeframe) {
      case PERIOD_M1 : i = 0; break;
      case PERIOD_M5 : i = 1; break;
      case PERIOD_M15: i = 2; break;
      case PERIOD_M30: i = 3; break;
      case PERIOD_H1 : i = 4; break;
      case PERIOD_H4 : i = 5; break;
      case PERIOD_D1 : i = 6; break;
      case PERIOD_W1 :                                                     // intentionally not supported
      case PERIOD_MN1: return(false);                                      // ...
      default:
         return(!catch("IsBarOpenEvent(3)  invalid parameter timeframe = "+ timeframe, ERR_INVALID_PARAMETER));
   }

   // re-calculate bar open/close time of the timeframe in question
   if (Tick.Time >= bar.closeTimes[i]) {                                   // TRUE at first call and at BarOpen
      bar.openTimes [i] = Tick.Time - Tick.Time % (timeframes[i]*MINUTES);
      bar.closeTimes[i] = bar.openTimes[i]      + (timeframes[i]*MINUTES);
   }

   bool result = false;

   // resolve event status by checking the previous tick
   if (__ExecutionContext[I_EC.prevTickTime] < bar.openTimes[i]) {
      if (!__ExecutionContext[I_EC.prevTickTime]) {
         if (IsExpert()) /*&&*/ if (IsTesting())                           // in Tester the first tick is always a BarOpen event
            result = true;
      }
      else {
         result = true;
      }
   }
   return(result);
}
