/**
 * Whether or not the current tick represents a BarOpen event in the specified timeframe.
 *
 * Doesn't recognize a BarOpen event if called at the first tick after program start or recompilation. Returns the same
 * result if called multiple times during the same tick.
 *
 * @param  int timeframe - timeframe to check the tick against
 *
 * @return bool
 */
bool EventListener.BarOpen(int timeframe) {
   if (IsIndicator()) /*&&*/ if (This.IsTesting()) /*&&*/ if (!IsSuperContext()) // TODO: IsSuperContext() isn't sufficient, root program must be an expert
      return(!catch("EventListener.BarOpen(1)  function cannot be used in Tester in standalone indicator (Tick.Time not available)", ERR_FUNC_NOT_ALLOWED_IN_TESTER));

   static int      i, timeframes[]={PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
   static datetime bar.openTimes[], bar.closeTimes[];                            // Open/CloseTimes of each timeframe
   if (!ArraySize(bar.openTimes)) {
      ArrayResize(bar.openTimes,  ArraySize(timeframes));
      ArrayResize(bar.closeTimes, ArraySize(timeframes));
   }

   switch (timeframe) {
      case PERIOD_M1 : i = 0; break;
      case PERIOD_M5 : i = 1; break;
      case PERIOD_M15: i = 2; break;
      case PERIOD_M30: i = 3; break;
      case PERIOD_H1 : i = 4; break;
      case PERIOD_H4 : i = 5; break;
      case PERIOD_D1 : i = 6; break;
      case PERIOD_W1 : i = 7; return(false);                                     // intentionally not supported
      case PERIOD_MN1: i = 8; return(false);                                     // ...
      default:
         return(!catch("EventListener.BarOpen(2)  invalid parameter timeframe = "+ timeframe, ERR_INVALID_PARAMETER));
   }

   // re-calculate bar open/close time of the timeframe in question
   if (Tick.Time >= bar.closeTimes[i]) {                                         // TRUE at first call and at BarOpen
      bar.openTimes [i] = Tick.Time - Tick.Time % (timeframes[i]*MINUTES);
      bar.closeTimes[i] = bar.openTimes[i]      + (timeframes[i]*MINUTES);
   }

   bool result = false;

   // resolve event status by help of the previous tick
   if (Tick.prevTime < bar.openTimes[i]) {
      if (!Tick.prevTime) {
         if (IsExpert()) /*&&*/ if (IsTesting())                                 // in Tester the first tick is always a BarOpen event
            result = true;
      }
      else {
         result = true;
      }
   }
   return(result);
}
