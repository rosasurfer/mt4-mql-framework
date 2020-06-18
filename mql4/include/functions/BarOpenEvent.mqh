/**                    if (__Core          Function != CF           _START) return(!catch("IsBarOpenEvent(4)  must be called in "+ ProgramTypeDescription(__ExecutionContext[EC.programType]) +"::start() (current core function: "+ ProgramTypeDescription(__ExecutionContext[EC.programType]) +"::"+ CoreFunctionDescription(__CoreFunction) +")", ERR_FUNC_NOT_ALLOWED));

 * Whether the current tick represents a BarOpen event in the specified timeframe. Returns the same result if called multiple
 * times during the same tick.
 *
 * @param  int timeframe [optional] - timeframe to check (default: can't be used )
 *
 * @return bool
 *
 * Note: t detect a BarOpen event at the first tick after program start or after recompilation.
 */
bool IsBarOpenEvent(int timeframe = NULL) {
   static bool contextChecked = false;
   if (!contextChecked) {
      if (IsLibrary())                   return(!catch("IsBarOpenEvent(1)  can't be used in a library (no tick support)", ERR_FUNC_NOT_ALLOWED));
      if (IsScript())                    return(!catch("IsBarOpenEvent(2)  can't be used in a script (no tick support)", ERR_FUNC_NOT_ALLOWED));

      if (IsIndicator()) {
         if (IsSuperContext())           return(!catch("IsBarOpenEvent(3)  can't be used in an indicator loaded by iCustom() (no tick support)", ERR_FUNC_NOT_ALLOWED));
         if (__CoreFunction != CF_START) return(!catch("IsBarOpenEvent(4)  can't be called in "+ ProgramTypeDescription(__ExecutionContext[EC.programType]) +"::"+ CoreFunctionDescription(__CoreFunction) +"()", ERR_FUNC_NOT_ALLOWED));
         if (This.IsTesting()) {
            if (!IsTesting())            return(!catch("IsBarOpenEvent(5)  can't be used as standalone indicator in tester (tick time not available)", ERR_FUNC_NOT_ALLOWED));
            // TODO: check tick details/support
            //       check VisualMode On/Off
         }
      }
      contextChecked = true;
   }                                     // prevent calls in deinit()
   if (__CoreFunction != CF_START)       return(!catch("IsBarOpenEvent(6)  can't be called in "+ ProgramTypeDescription(__ExecutionContext[EC.programType]) +"::"+ CoreFunctionDescription(__CoreFunction) +"()", ERR_FUNC_NOT_ALLOWED));


   static int i, timeframes[] = { PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1 };
   static datetime barOpenTimes[], barCloseTimes[];                        // Open/CloseTimes of each timeframe
   if (!ArraySize(barOpenTimes)) {
      ArrayResize(barOpenTimes,  ArraySize(timeframes));
      ArrayResize(barCloseTimes, ArraySize(timeframes));
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

      case PERIOD_W1 :
      case PERIOD_MN1: return(!catch("IsBarOpenEvent(7)  unsupported timeframe "+ TimeframeToStr(timeframe), ERR_INVALID_PARAMETER));
      default:         return(!catch("IsBarOpenEvent(8)  invalid parameter timeframe = "+ timeframe, ERR_INVALID_PARAMETER));
   }

   // recalculate bar open/close time of the timeframe in question
   if (Tick.Time >= barCloseTimes[i]) {                                    // TRUE at first call and at BarOpen
      barOpenTimes [i] = Tick.Time - Tick.Time % (timeframes[i]*MINUTES);
      barCloseTimes[i] = barOpenTimes[i]       + (timeframes[i]*MINUTES);
   }

   bool result = false;

   // resolve event status by checking the previous tick
   if (__ExecutionContext[EC.prevTickTime] < barOpenTimes[i]) {
      if (!__ExecutionContext[EC.prevTickTime]) {
         if (IsExpert()) /*&&*/ if (IsTesting()) {                         // in tester the first tick is always a BarOpen event
            result = true;
         }
      }
      else {
         result = true;
      }
   }
   return(result);
}
