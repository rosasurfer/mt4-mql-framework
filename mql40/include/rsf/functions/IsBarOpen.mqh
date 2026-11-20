/**
 * Whether the current tick represents a BarOpen event in the specified timeframe.
 * The function can be used with any timeframe and also supports custom timeframes.
 *
 * @param  int timeframe [optional] - timeframe to check (default: current timeframe)
 *
 * @return bool
 *
 *
 * Notes
 * -----
 *  - The function also resolves BarOpen events if the bar alignment of the stored history is incorrect.
 *  - The function needs a previous tick. It cannot resolve BarOpen events on the first tick of a program.
 */
bool IsBarOpen(int timeframe = NULL) {
   static bool contextChecked = false; if (!contextChecked) {
      if (IsScript())          return(!catch("IsBarOpen(1)  can't be used in scripts (no tick support)", ERR_FUNC_NOT_ALLOWED));
      if (IsIndicator()) {
         if (__isSuperContext) return(!catch("IsBarOpen(2)  can't be used in iCustom() (no tick support)", ERR_FUNC_NOT_ALLOWED));
         if (__isTesting) {
            if (!IsTesting())  return(!catch("IsBarOpen(3)  can't be used in standalone indicators in tester (tick time not available)", ERR_FUNC_NOT_ALLOWED));
            // TODO: check tick details/support
            // TODO: check VisualMode On/Off
         }
      }
      contextChecked = true;
   }
   if (__ExecutionContext[EC.programCoreFunction] != CF_START) return(!catch("IsBarOpen(4)  invalid calling context: "+ ProgramTypeDescription(__ExecutionContext[EC.programType]) +"::"+ CoreFunctionDescription(__ExecutionContext[EC.programCoreFunction]), ERR_FUNC_NOT_ALLOWED));
   if (timeframe < 0)                                          return(!catch("IsBarOpen(5)  invalid parameter timeframe: "+ timeframe, ERR_INVALID_PARAMETER));
   if (!timeframe) timeframe = Period();

   if (!Tick.time) return(!catch("IsBarOpen(6)  tick time not available: Tick.time=0", ERR_ILLEGAL_STATE));


   // scenarios
   // -----------------------------------------------------------------------------------------------------------------------
   // 1) online chart with correctly aligned bars

   // 2) online chart with incorrectly aligned bars

   // 3) offline chart: all ticks are synthetic and triggered by the user, a server Tick.time is not available
   //    - only the first tick received for a new bar will be considered a BarOpen event
   //    - on such a first tick OHLC may already be set with different values














   // start/end times of standard timeframes are cached to improve performance
   #define IBO_STARTTIME 0                // period open time
   #define IBO_ENDTIME   1                // period close time
   static int stdTimeframes[9][2];

   bool isStdTimeframe = true;
   datetime starttime = 0;
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

      default:                                              // custom TF: recalculate period start time on every call
         isStdTimeframe = false;
         starttime = Tick.time - Tick.time % (timeframe * MINUTES);
   }

   if (isStdTimeframe) {
      // update + cache current start/end times
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
   datetime lastTickTime = __ExecutionContext[EC.lastRealTickTime];
   if (!lastTickTime) {
      result = IsTesting();                                 // in tester the first tick is always a BarOpen event
   }
   else {
      result = (lastTickTime < starttime);
   }

   int error = GetLastError();
   if (!error) return(result);
   return(!catch("IsBarOpen(7)", error));
}
