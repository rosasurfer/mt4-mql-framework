/**
 * Whether the current tick represents a BarOpen event in the specified timeframe. If called multiple times during the same
 * tick the function returns the same result.
 *
 * @param  int timeframe [optional] - timeframe to check (default: the current timeframe)
 *
 * @return bool
 *
 * Note: The function cannot detect a BarOpen event at the first tick after program start or after recompilation.
 */
bool IsBarOpen(int timeframe = NULL) {
   static bool contextChecked = false;
   if (!contextChecked) {
      if (IsLibrary())                   return(!catch("IsBarOpen(1)  can't be used in a library (no tick support)", ERR_FUNC_NOT_ALLOWED));
      if (IsScript())                    return(!catch("IsBarOpen(2)  can't be used in a script (no tick support)", ERR_FUNC_NOT_ALLOWED));

      if (IsIndicator()) {
         if (IsSuperContext())           return(!catch("IsBarOpen(3)  can't be used in an indicator loaded by iCustom() (no tick support)", ERR_FUNC_NOT_ALLOWED));
         if (__CoreFunction != CF_START) return(!catch("IsBarOpen(4)  can only be used in the program's start() function", ERR_FUNC_NOT_ALLOWED));
         if (This.IsTesting()) {
            if (!IsTesting())            return(!catch("IsBarOpen(5)  can't be used in a standalone indicator in tester (tick time not available)", ERR_FUNC_NOT_ALLOWED));
            // TODO: check tick details/support
            //       check VisualMode On/Off
         }
      }
      contextChecked = true;
   }                                     // prevent calls in deinit()
   if (__CoreFunction != CF_START)       return(!catch("IsBarOpen(6)  can only be used in the program's start() function", ERR_FUNC_NOT_ALLOWED));


   static int i, timeframes[] = { PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H2, PERIOD_H3, PERIOD_H4, PERIOD_H6, PERIOD_H8, PERIOD_D1, PERIOD_W1, PERIOD_MN1 };
   static datetime barOpenTime[], barCloseTime[];                          // Open/CloseTime of each timeframe
   if (!ArraySize(barOpenTime)) {
      ArrayResize(barOpenTime,  ArraySize(timeframes));
      ArrayResize(barCloseTime, ArraySize(timeframes));
   }

   if (!timeframe)
      timeframe = Period();

   switch (timeframe) {
      case PERIOD_M1 : i = 0;  break;
      case PERIOD_M5 : i = 1;  break;
      case PERIOD_M15: i = 2;  break;
      case PERIOD_M30: i = 3;  break;
      case PERIOD_H1 : i = 4;  break;
      case PERIOD_H2 : i = 5;  break;
      case PERIOD_H3 : i = 6;  break;
      case PERIOD_H4 : i = 7;  break;
      case PERIOD_H6 : i = 8;  break;
      case PERIOD_H8 : i = 9;  break;
      case PERIOD_D1 : i = 10; break;

      case PERIOD_W1 :
      case PERIOD_MN1: return(!catch("IsBarOpen(7)  unsupported timeframe "+ TimeframeToStr(timeframe), ERR_INVALID_PARAMETER));
      default:         return(!catch("IsBarOpen(8)  invalid parameter timeframe: "+ timeframe, ERR_INVALID_PARAMETER));
   }

   // recalculate bar open/close time of the timeframe in question
   if (Tick.Time >= barCloseTime[i]) {                                     // TRUE at first call and at BarOpen
      barOpenTime [i] = Tick.Time - Tick.Time % (timeframes[i]*MINUTES);
      barCloseTime[i] = barOpenTime[i]        + (timeframes[i]*MINUTES);
   }

   bool result = false;

   // resolve event status by checking the previous tick
   if (__ExecutionContext[EC.prevTickTime] < barOpenTime[i]) {
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
