/**
 * Whether the current tick represents a BarOpen event in the specified timeframe. This function can be used to determine
 * BarOpen events for a timeframe other than the current chart timeframe. If called multiple times during a tick, each call
 * returns the same result. Supports custom timeframes.
 *
 * @param  int timeframe [optional] - timeframe to check (default: the current timeframe)
 *
 * @return bool
 *
 *
 * Notes
 * -----
 *  - This function correctly resolves BarOpen events even if the bar alignment of the stored history is incorrect.
 *  - This function cannot resolve BarOpen events without a previous tick (except in tester).
 */
bool IsBarOpen(int timeframe = NULL) {
   static bool contextChecked = false; if (!contextChecked) {
      if (IsLibrary())         return(!catch("IsBarOpen(1)  can't be used in a library (no tick support)", ERR_FUNC_NOT_ALLOWED));
      if (IsScript())          return(!catch("IsBarOpen(2)  can't be used in a script (no tick support)", ERR_FUNC_NOT_ALLOWED));
      if (IsIndicator()) {
         if (__isSuperContext) return(!catch("IsBarOpen(3)  can't be used in iCustom() (no tick support)", ERR_FUNC_NOT_ALLOWED));
         if (__isTesting) {
            if (!IsTesting())  return(!catch("IsBarOpen(4)  can't be used in a standalone indicator in tester (tick time not available)", ERR_FUNC_NOT_ALLOWED));
            // TODO: check tick details/support
            // TODO: check VisualMode On/Off
         }
      }
      contextChecked = true;
   }
   if (__CoreFunction != CF_START) return(!catch("IsBarOpen(5)  invalid calling context: "+ ProgramTypeDescription(__ExecutionContext[EC.programType]) +"::"+ CoreFunctionDescription(__CoreFunction), ERR_FUNC_NOT_ALLOWED));
   if (timeframe < 0)              return(!catch("IsBarOpen(6)  invalid parameter timeframe: "+ timeframe, ERR_INVALID_PARAMETER));
   if (!timeframe) timeframe = Period();

   // to improve performance start/end times of standard timeframes are cached
   #define IBO_STARTTIME 0                // period open time
   #define IBO_ENDTIME   1                // period close time
   static int stdTimeframes[9][2];

   datetime starttime;
   int i = -1;

   switch (timeframe) {
      case PERIOD_M1:  i = 0; break;
      case PERIOD_M5:  i = 1; break;
      case PERIOD_M15: i = 2; break;
      case PERIOD_M30: i = 3; break;
      case PERIOD_H1:  i = 4; break;
      case PERIOD_H4:  i = 5; break;
      case PERIOD_D1:  i = 6; break;
      case PERIOD_W1:  i = 7; break;
      case PERIOD_MN1: i = 8; break;

      // custom timeframe: recalculate period start time on every call
      default:
         starttime = Tick.time - Tick.time % (timeframe * MINUTES);
         break;
   }

   // standard timeframe: update + cache current start/end times
   if (!starttime) {
      if (Tick.time >= stdTimeframes[i][IBO_ENDTIME]) {     // TRUE at first call and at BarOpen
         if (i < 7) {
            stdTimeframes[i][IBO_STARTTIME] = Tick.time - Tick.time % (timeframe * MINUTES);
            stdTimeframes[i][IBO_ENDTIME  ] = stdTimeframes[i][IBO_STARTTIME] + (timeframe * MINUTES);
         }
         else if (timeframe == PERIOD_W1) {
            stdTimeframes[i][IBO_STARTTIME] = Tick.time - Tick.time % DAYS - (TimeDayOfWeek(Tick.time) + 6) % 7 * DAYS;
            stdTimeframes[i][IBO_ENDTIME  ] = stdTimeframes[i][IBO_STARTTIME] + (timeframe * MINUTES);
         }
         else if (timeframe == PERIOD_MN1) {
            stdTimeframes[i][IBO_STARTTIME] = Tick.time - Tick.time % DAYS - (TimeDay(Tick.time) - 1) * DAYS;
            stdTimeframes[i][IBO_ENDTIME  ] = stdTimeframes[i][IBO_STARTTIME] + 28 * DAYS;

            while (TimeMonth(stdTimeframes[i][IBO_STARTTIME]) == TimeMonth(stdTimeframes[i][IBO_ENDTIME])) {
               stdTimeframes[i][IBO_ENDTIME] += DAY;
            }
         }
      }
      starttime = stdTimeframes[i][IBO_STARTTIME];
   }

   // resolve event status by checking the previous tick
   bool result = false;
   datetime lastTick = __ExecutionContext[EC.lastRealTick];
   if (!lastTick) {
      result = IsTesting();                                 // in tester the first tick is always a BarOpen event
   }
   else {
      result = (lastTick < starttime);
   }
   return(result);
}
