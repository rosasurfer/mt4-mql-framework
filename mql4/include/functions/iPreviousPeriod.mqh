/**
 * Calculate start/end times of the timeframe period preceding parameter 'openTimeFxt'. Supports MT4 standard timeframes plus
 * the custom timeframe PERIOD_Q1. If 'openTimeFxt' is NULL the calculated period is the current still unfinished time period.
 *
 * @param  _In_    int      timeframe               - target timeframe (NULL: the current timeframe)
 * @param  _InOut_ datetime &openTimeFxt            - IN:  reference time in FXT (NULL: interpreted as in the future of the current time period
 *                                                    OUT: start time of the resulting time period in FXT
 * @param  _Out_   datetime &closeTimeFxt           - end time of the resulting time period in FXT
 * @param  _Out_   datetime &openTimeSrv            - start time of the resulting time period in server time
 * @param  _Out_   datetime &closeTimeSrv           - end time of the resulting time period in server time
 * @param  _In_    bool     skipWeekends [optional] - skip weekend times in the calculations (default: yes)
 *
 * @return bool - success status
 *
 * NOTE: This function doesn't access any timeseries. Results are purely calculated.
 */
bool iPreviousPeriod(int timeframe/*=NULL*/, datetime &openTimeFxt, datetime &closeTimeFxt, datetime &openTimeSrv, datetime &closeTimeSrv, bool skipWeekends = true) {
   skipWeekends = skipWeekends!=0;
   if (!timeframe) timeframe = Period();

   if (!openTimeFxt) {
      datetime nowFxt = TimeFXT(); if (!nowFxt) return(!logInfo("iPreviousPeriod(1)->TimeFXT() => 0", ERR_RUNTIME_ERROR));
   }

   // --- PERIOD_M1 ---------------------------------------------------------------------------------------------------------
   if (timeframe == PERIOD_M1) {
      if (!openTimeFxt) openTimeFxt = nowFxt + 1*MINUTE;             // if NULL set reference time to the next minute

      openTimeFxt -= openTimeFxt % MINUTES;                          // start of the previous period
      openTimeFxt -= 1*MINUTE;

      if (skipWeekends) {                                            // handle weekend times
         int dow = TimeDayOfWeekEx(openTimeFxt);
         if      (dow == SATURDAY) openTimeFxt -= (1*DAY  + openTimeFxt % DAYS - 23*HOURS - 59*MINUTES);    // Friday 23:59
         else if (dow == SUNDAY  ) openTimeFxt -= (2*DAYS + openTimeFxt % DAYS - 23*HOURS - 59*MINUTES);
      }

      closeTimeFxt = openTimeFxt + 1*MINUTE;                         // end of the previous period
   }

   // --- PERIOD_M5 ---------------------------------------------------------------------------------------------------------
   else if (timeframe == PERIOD_M5) {
      if (!openTimeFxt) openTimeFxt = nowFxt + 5*MINUTES;            // if NULL set reference time 5 minutes in the future

      openTimeFxt -= openTimeFxt % (5*MINUTES);                      // start of the previous period
      openTimeFxt -= 5*MINUTES;

      if (skipWeekends) {                                            // handle weekend times
         dow = TimeDayOfWeekEx(openTimeFxt);
         if      (dow == SATURDAY) openTimeFxt -= (1*DAY  + openTimeFxt % DAYS - 23*HOURS - 55*MINUTES);    // Friday 23:55
         else if (dow == SUNDAY  ) openTimeFxt -= (2*DAYS + openTimeFxt % DAYS - 23*HOURS - 55*MINUTES);
      }

      closeTimeFxt = openTimeFxt + 5*MINUTES;                        // end of the previous period
   }

   // --- PERIOD_M15 --------------------------------------------------------------------------------------------------------
   else if (timeframe == PERIOD_M15) {
      if (!openTimeFxt) openTimeFxt = nowFxt + 15*MINUTES;           // if NULL set reference time 15 minutes in the future

      openTimeFxt -= openTimeFxt % (15*MINUTES);                     // start of the previous period
      openTimeFxt -= 15*MINUTES;

      if (skipWeekends) {                                            // handle weekend times
         dow = TimeDayOfWeekEx(openTimeFxt);
         if      (dow == SATURDAY) openTimeFxt -= (1*DAY  + openTimeFxt % DAYS - 23*HOURS - 45*MINUTES);    // Friday 23:45
         else if (dow == SUNDAY  ) openTimeFxt -= (2*DAYS + openTimeFxt % DAYS - 23*HOURS - 45*MINUTES);
      }

      closeTimeFxt = openTimeFxt + 15*MINUTES;
   }                                                                 // end of the previous period

   // --- PERIOD_M30 --------------------------------------------------------------------------------------------------------
   else if (timeframe == PERIOD_M30) {
      if (!openTimeFxt) openTimeFxt = nowFxt + 30*MINUTES;           // if NULL set reference time 30 minutes in the future

      openTimeFxt -= openTimeFxt % (30*MINUTES);                     // start of the previous period
      openTimeFxt -= 30*MINUTES;

      if (skipWeekends) {                                            // handle weekend times
         dow = TimeDayOfWeekEx(openTimeFxt);
         if      (dow == SATURDAY) openTimeFxt -= (1*DAY  + openTimeFxt % DAYS - 23*HOURS - 30*MINUTES);    // Friday 23:30
         else if (dow == SUNDAY  ) openTimeFxt -= (2*DAYS + openTimeFxt % DAYS - 23*HOURS - 30*MINUTES);
      }

      closeTimeFxt = openTimeFxt + 30*MINUTES;                       // end of the previous period
   }

   // --- PERIOD_H1 ---------------------------------------------------------------------------------------------------------
   else if (timeframe == PERIOD_H1) {
      if (!openTimeFxt) openTimeFxt = nowFxt + 1*HOUR;               // if NULL set reference time to the next hour

      openTimeFxt -= openTimeFxt % HOURS;                            // start of the previous period
      openTimeFxt -= 1*HOUR;

      if (skipWeekends) {                                            // handle weekend times
         dow = TimeDayOfWeekEx(openTimeFxt);
         if      (dow == SATURDAY) openTimeFxt -= (1*DAY  + openTimeFxt % DAYS - 23*HOURS);                 // Friday 23:00
         else if (dow == SUNDAY  ) openTimeFxt -= (2*DAYS + openTimeFxt % DAYS - 23*HOURS);
      }

      closeTimeFxt = openTimeFxt + 1*HOUR;                           // end of the previous period
   }

   // --- PERIOD_H4 ---------------------------------------------------------------------------------------------------------
   else if (timeframe == PERIOD_H4) {
      if (!openTimeFxt) openTimeFxt = nowFxt + 4*HOURS;              // if NULL set reference time 4 hours in the future

      openTimeFxt -= openTimeFxt % (4*HOURS);                        // start of the previous period
      openTimeFxt -= 4*HOURS;

      if (skipWeekends) {                                            // handle weekend times
         dow = TimeDayOfWeekEx(openTimeFxt);
         if      (dow == SATURDAY) openTimeFxt -= (1*DAY  + openTimeFxt % DAYS - 20*HOURS);                 // Friday 20:00
         else if (dow == SUNDAY  ) openTimeFxt -= (2*DAYS + openTimeFxt % DAYS - 20*HOURS);
      }

      closeTimeFxt = openTimeFxt + 4*HOURS;                          // end of the previous period
   }

   // --- PERIOD_D1 ---------------------------------------------------------------------------------------------------------
   else if (timeframe == PERIOD_D1) {
      if (!openTimeFxt) openTimeFxt = nowFxt + 1*DAY;                // if NULL set reference time to the next day

      openTimeFxt -= openTimeFxt % DAYS;                             // start of the previous period
      openTimeFxt -= 1*DAY;

      if (skipWeekends) {                                            // handle weekend times
         dow = TimeDayOfWeekEx(openTimeFxt);
         if      (dow == SATURDAY) openTimeFxt -= 1*DAY;                                                    // Friday 00:00
         else if (dow == SUNDAY  ) openTimeFxt -= 2*DAYS;
      }

      closeTimeFxt = openTimeFxt + 1*DAY;                            // end of the previous period
   }

   // --- PERIOD_W1 ---------------------------------------------------------------------------------------------------------
   else if (timeframe == PERIOD_W1) {
      if (!openTimeFxt) openTimeFxt = nowFxt + 7*DAYS;               // if NULL set reference time to the next week

      openTimeFxt -= openTimeFxt % DAYS;                             // start of the previous period     // 00:00 of the referenced day
      openTimeFxt -= (TimeDayOfWeekEx(openTimeFxt)+6) % 7 * DAYS;                                        // Monday 00:00 of the referenced week
      openTimeFxt -= 7*DAYS;                                                                             // previous Monday 00:00

      if (skipWeekends) closeTimeFxt = openTimeFxt + 5*DAYS;         // handle weekend times
      else              closeTimeFxt = openTimeFxt + 7*DAYS;
   }

   // --- PERIOD_MN1 --------------------------------------------------------------------------------------------------------
   else if (timeframe == PERIOD_MN1) {
      if (!openTimeFxt) {
         openTimeFxt = nowFxt + 1*MONTH;                             // if NULL set reference time to the next month
         int monthNow  = TimeMonth(nowFxt);                          // make sure it doesn't point 2 months ahead
         int monthThen = TimeMonth(openTimeFxt);
         if (monthNow  > monthThen)  monthThen   += 12;
         if (monthThen > monthNow+1) openTimeFxt -= 4*DAYS;
      }

      openTimeFxt -= openTimeFxt % DAYS;                             // 00:00 of the referenced day
      closeTimeFxt = openTimeFxt - (TimeDayEx(openTimeFxt)-1)*DAYS;  // 1st day 00:00 of the referenced month

      openTimeFxt  = closeTimeFxt - 1*DAY;                           // last day 00:00 of the previous month
      openTimeFxt -= (TimeDayEx(openTimeFxt)-1)*DAYS;                // 1st day 00:00 of the previous month

      if (skipWeekends) {                                            // handle weekend times
         dow = TimeDayOfWeekEx(openTimeFxt);
         if      (dow == SATURDAY) openTimeFxt += 2*DAYS;
         else if (dow == SUNDAY  ) openTimeFxt += 1*DAY;

         dow = TimeDayOfWeekEx(closeTimeFxt);
         if      (dow == SUNDAY) closeTimeFxt -= 1*DAY;
         else if (dow == MONDAY) closeTimeFxt -= 2*DAYS;
      }
   }

   // --- PERIOD_Q1 ---------------------------------------------------------------------------------------------------------
   else if (timeframe == PERIOD_Q1) {
      if (!openTimeFxt) {
         openTimeFxt = nowFxt + 1*QUARTER;                           // if NULL set reference time 3 months in the future
         monthNow  = TimeMonth(nowFxt);                              // make it doesn't point 2 quarters ahead
         monthThen = TimeMonth(openTimeFxt);
         if (monthNow > monthThen)   monthThen   += 12;
         if (monthThen > monthNow+3) openTimeFxt -= 1*MONTH;
      }

      openTimeFxt -= openTimeFxt % DAYS;                                                              // 00:00 of the referenced day

      switch (TimeMonth(openTimeFxt)) {                                                               // 1st day 00:00 of the referenced quarter
         case JANUARY  :                                                                              //
         case FEBRUARY :                                                                              //
         case MARCH    : closeTimeFxt = openTimeFxt -   (TimeDayOfYear(openTimeFxt)-1)*DAYS; break;   // 01.01.
         case APRIL    : closeTimeFxt = openTimeFxt -       (TimeDayEx(openTimeFxt)-1)*DAYS; break;   //
         case MAY      : closeTimeFxt = openTimeFxt - (30+   TimeDayEx(openTimeFxt)-1)*DAYS; break;   //
         case JUNE     : closeTimeFxt = openTimeFxt - (30+31+TimeDayEx(openTimeFxt)-1)*DAYS; break;   // 01.04.
         case JULY     : closeTimeFxt = openTimeFxt -       (TimeDayEx(openTimeFxt)-1)*DAYS; break;   //
         case AUGUST   : closeTimeFxt = openTimeFxt - (31+   TimeDayEx(openTimeFxt)-1)*DAYS; break;   //
         case SEPTEMBER: closeTimeFxt = openTimeFxt - (31+31+TimeDayEx(openTimeFxt)-1)*DAYS; break;   // 01.07.
         case OCTOBER  : closeTimeFxt = openTimeFxt -       (TimeDayEx(openTimeFxt)-1)*DAYS; break;   //
         case NOVEMBER : closeTimeFxt = openTimeFxt - (31+   TimeDayEx(openTimeFxt)-1)*DAYS; break;   //
         case DECEMBER : closeTimeFxt = openTimeFxt - (31+30+TimeDayEx(openTimeFxt)-1)*DAYS; break;   // 01.10.
      }

      openTimeFxt = closeTimeFxt - 1*DAY;                                                             // last day 00:00 of the previous quarter
      switch (TimeMonth(openTimeFxt)) {                                                               // 1st day 00:00 of the previous quarter
         case MARCH    : openTimeFxt -=   (TimeDayOfYear(openTimeFxt)-1)*DAYS; break;                 // 01.01.
         case JUNE     : openTimeFxt -= (30+31+TimeDayEx(openTimeFxt)-1)*DAYS; break;                 // 01.04.
         case SEPTEMBER: openTimeFxt -= (31+31+TimeDayEx(openTimeFxt)-1)*DAYS; break;                 // 01.07.
         case DECEMBER : openTimeFxt -= (31+30+TimeDayEx(openTimeFxt)-1)*DAYS; break;                 // 01.10.
      }

      if (skipWeekends) {                                            // handle weekend times
         dow = TimeDayOfWeekEx(openTimeFxt);
         if      (dow == SATURDAY) openTimeFxt += 2*DAYS;
         else if (dow == SUNDAY  ) openTimeFxt += 1*DAY;

         dow = TimeDayOfWeekEx(closeTimeFxt);
         if      (dow == SUNDAY) closeTimeFxt -= 1*DAY;
         else if (dow == MONDAY) closeTimeFxt -= 2*DAYS;
      }
   }
   else return(!catch("iPreviousPeriod(2)  invalid parameter timeframe: "+ timeframe, ERR_INVALID_PARAMETER));

   // calculate corresponding server times
   openTimeSrv  = FxtToServerTime(openTimeFxt);  if (openTimeSrv  == NaT) return(false);
   closeTimeSrv = FxtToServerTime(closeTimeFxt); if (closeTimeSrv == NaT) return(false);
   return(!catch("iPreviousPeriod(3)"));
}
