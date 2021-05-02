/**
 * Resolve start and end times of the period preceding parameter 'openTimeFxt' and return the result in the passed variables.
 * If 'openTimeFxt' is not specified (NULL) the returned times describe start and end of the first (current) period.
 *
 * @param  _In_    int      timeframe     - period timeframe (NULL: the current timeframe)
 * @param  _InOut_ datetime &openTimeFxt  - variable receiving the starttime of the resulting period in FXT
 * @param  _Out_   datetime &closeTimeFxt - variable receiving the endtime of the resulting period in FXT
 * @param  _Out_   datetime &openTimeSrv  - variable receiving the starttime of the resulting period in server time
 * @param  _Out_   datetime &closeTimeSrv - variable receiving the endtime of the resulting period in server time
 *
 * @return bool - success status
 *
 * NOTE: The function doesn't access the underlying price timeseries. Results are purely calculated using the system time.
 */
bool iPreviousPeriodTimes(int timeframe/*=NULL*/, datetime &openTimeFxt/*=NULL*/, datetime &closeTimeFxt, datetime &openTimeSrv, datetime &closeTimeSrv) {
   if (!timeframe)
      timeframe = Period();
   int month, dom, dow, monthOpenTime, monthNow;
   datetime nowFxt;


   // (1) PERIOD_M1
   if (timeframe == PERIOD_M1) {
      // ist openTimeFxt nicht gesetzt, Variable mit Zeitpunkt der nächste Minute initialisieren
      if (!openTimeFxt) {
         nowFxt      = TimeFXT(); if (!nowFxt) return(false);
         openTimeFxt = nowFxt + 1*MINUTE;
      }

      // openTimeFxt auf den Beginn der vorherigen Minute setzen
      openTimeFxt -= (openTimeFxt % MINUTES + 1*MINUTE);

      // Wochenenden in openTimeFxt überspringen
      dow = TimeDayOfWeekEx(openTimeFxt);
      if      (dow == SATURDAY) openTimeFxt -= (1*DAY  + openTimeFxt % DAYS - 23*HOURS - 59*MINUTES);    // Freitag 23:59
      else if (dow == SUNDAY  ) openTimeFxt -= (2*DAYS + openTimeFxt % DAYS - 23*HOURS - 59*MINUTES);

      // closeTimeFxt auf das Ende der Minute setzen
      closeTimeFxt = openTimeFxt + 1*MINUTE;
   }


   // (2) PERIOD_M5
   else if (timeframe == PERIOD_M5) {
      // ist openTimeFxt nicht gesetzt, Variable mit Zeitpunkt der nächsten 5 Minuten initialisieren
      if (!openTimeFxt) {
         nowFxt      = TimeFXT(); if (!nowFxt) return(false);
         openTimeFxt = nowFxt + 5*MINUTES;
      }

      // openTimeFxt auf den Beginn der vorherigen 5 Minuten setzen
      openTimeFxt -= (openTimeFxt % (5*MINUTES) + 5*MINUTES);

      // Wochenenden in openTimeFxt überspringen
      dow = TimeDayOfWeekEx(openTimeFxt);
      if      (dow == SATURDAY) openTimeFxt -= (1*DAY  + openTimeFxt % DAYS - 23*HOURS - 55*MINUTES);    // Freitag 23:55
      else if (dow == SUNDAY  ) openTimeFxt -= (2*DAYS + openTimeFxt % DAYS - 23*HOURS - 55*MINUTES);

      // closeTimeFxt auf das Ende der 5 Minuten setzen
      closeTimeFxt = openTimeFxt + 5*MINUTES;
   }


   // (3) PERIOD_M15
   else if (timeframe == PERIOD_M15) {
      // ist openTimeFxt nicht gesetzt, Variable mit Zeitpunkt der nächsten Viertelstunde initialisieren
      if (!openTimeFxt) {
         nowFxt      = TimeFXT(); if (!nowFxt) return(false);
         openTimeFxt = nowFxt + 15*MINUTES;
      }

      // openTimeFxt auf den Beginn der vorherigen Viertelstunde setzen
      openTimeFxt -= (openTimeFxt % (15*MINUTES) + 15*MINUTES);

      // Wochenenden in openTimeFxt überspringen
      dow = TimeDayOfWeekEx(openTimeFxt);
      if      (dow == SATURDAY) openTimeFxt -= (1*DAY  + openTimeFxt % DAYS - 23*HOURS - 45*MINUTES);    // Freitag 23:45
      else if (dow == SUNDAY  ) openTimeFxt -= (2*DAYS + openTimeFxt % DAYS - 23*HOURS - 45*MINUTES);

      // closeTimeFxt auf das Ende der Viertelstunde setzen
      closeTimeFxt = openTimeFxt + 15*MINUTES;
   }


   // (4) PERIOD_M30
   else if (timeframe == PERIOD_M30) {
      // ist openTimeFxt nicht gesetzt, Variable mit Zeitpunkt der nächsten halben Stunde initialisieren
      if (!openTimeFxt) {
         nowFxt      = TimeFXT(); if (!nowFxt) return(false);
         openTimeFxt = nowFxt + 30*MINUTES;
      }

      // openTimeFxt auf den Beginn der vorherigen halben Stunde setzen
      openTimeFxt -= (openTimeFxt % (30*MINUTES) + 30*MINUTES);

      // Wochenenden in openTimeFxt überspringen
      dow = TimeDayOfWeekEx(openTimeFxt);
      if      (dow == SATURDAY) openTimeFxt -= (1*DAY  + openTimeFxt % DAYS - 23*HOURS - 30*MINUTES);    // Freitag 23:30
      else if (dow == SUNDAY  ) openTimeFxt -= (2*DAYS + openTimeFxt % DAYS - 23*HOURS - 30*MINUTES);

      // closeTimeFxt auf das Ende der halben Stunde setzen
      closeTimeFxt = openTimeFxt + 30*MINUTES;
   }


   // (5) PERIOD_H1
   else if (timeframe == PERIOD_H1) {
      // ist openTimeFxt nicht gesetzt, Variable mit Zeitpunkt der nächsten Stunde initialisieren
      if (!openTimeFxt) {
         nowFxt      = TimeFXT(); if (!nowFxt) return(false);
         openTimeFxt = nowFxt + 1*HOUR;
      }

      // openTimeFxt auf den Beginn der vorherigen Stunde setzen
      openTimeFxt -= (openTimeFxt % HOURS + 1*HOUR);

      // Wochenenden in openTimeFxt überspringen
      dow = TimeDayOfWeekEx(openTimeFxt);
      if      (dow == SATURDAY) openTimeFxt -= (1*DAY  + openTimeFxt % DAYS - 23*HOURS);                 // Freitag 23:00
      else if (dow == SUNDAY  ) openTimeFxt -= (2*DAYS + openTimeFxt % DAYS - 23*HOURS);

      // closeTimeFxt auf das Ende der Stunde setzen
      closeTimeFxt = openTimeFxt + 1*HOUR;
   }


   // (6) PERIOD_H4
   else if (timeframe == PERIOD_H4) {
      // ist openTimeFxt nicht gesetzt, Variable mit Zeitpunkt der nächsten H4-Periode initialisieren
      if (!openTimeFxt) {
         nowFxt      = TimeFXT(); if (!nowFxt) return(false);
         openTimeFxt = nowFxt + 4*HOURS;
      }

      // openTimeFxt auf den Beginn der vorherigen H4-Periode setzen
      openTimeFxt -= (openTimeFxt % (4*HOURS) + 4*HOURS);

      // Wochenenden in openTimeFxt überspringen
      dow = TimeDayOfWeekEx(openTimeFxt);
      if      (dow == SATURDAY) openTimeFxt -= (1*DAY  + openTimeFxt % DAYS - 20*HOURS);                 // Freitag 20:00
      else if (dow == SUNDAY  ) openTimeFxt -= (2*DAYS + openTimeFxt % DAYS - 20*HOURS);

      // closeTimeFxt auf das Ende der H4-Periode setzen
      closeTimeFxt = openTimeFxt + 4*HOURS;
   }


   // (7) PERIOD_D1
   else if (timeframe == PERIOD_D1) {
      // ist openTimeFxt nicht gesetzt, Variable mit Zeitpunkt des nächsten Tages initialisieren
      if (!openTimeFxt) {
         nowFxt      = TimeFXT(); if (!nowFxt) return(false);
         openTimeFxt = nowFxt + 1*DAY;
      }

      // openTimeFxt auf 00:00 Uhr des vorherigen Tages setzen
      openTimeFxt -= (openTimeFxt % DAYS + 1*DAY);

      // Wochenenden in openTimeFxt überspringen
      dow = TimeDayOfWeekEx(openTimeFxt);
      if      (dow == SATURDAY) openTimeFxt -= 1*DAY;
      else if (dow == SUNDAY  ) openTimeFxt -= 2*DAYS;

      // closeTimeFxt auf das Ende des Tages setzen
      closeTimeFxt = openTimeFxt + 1*DAY;
   }


   // (8) PERIOD_W1
   else if (timeframe == PERIOD_W1) {
      // ist openTimeFxt nicht gesetzt, Variable mit Zeitpunkt der nächsten Woche initialisieren
      if (!openTimeFxt) {
         nowFxt      = TimeFXT(); if (!nowFxt) return(false);
         openTimeFxt = nowFxt + 7*DAYS;
      }

      // openTimeFxt auf Montag, 00:00 Uhr der vorherigen Woche setzen
      openTimeFxt -= openTimeFxt % DAYS;                                                              // 00:00 des aktuellen Tages
      openTimeFxt -= (TimeDayOfWeekEx(openTimeFxt)+6)%7 * DAYS;                                       // Montag der aktuellen Woche
      openTimeFxt -= 7*DAYS;                                                                          // Montag der Vorwoche

      // closeTimeFxt auf 00:00 des folgenden Samstags setzen
      closeTimeFxt = openTimeFxt + 5*DAYS;
   }


   // (9) PERIOD_MN1
   else if (timeframe == PERIOD_MN1) {
      // ist openTimeFxt nicht gesetzt, Variable mit Zeitpunkt des nächsten Monats initialisieren
      if (!openTimeFxt) {
         nowFxt      = TimeFXT(); if (!nowFxt) return(false);
         openTimeFxt = nowFxt + 1*MONTH;

         monthNow      = TimeMonth(nowFxt     );                                                      // MONTH ist nicht fix: Sicherstellen, daß openTimeFxt
         monthOpenTime = TimeMonth(openTimeFxt);                                                      // nicht schon auf den übernächsten Monat zeigt.
         if (monthNow > monthOpenTime)
            monthOpenTime += 12;
         if (monthOpenTime > monthNow+1)
            openTimeFxt -= 4*DAYS;
      }

      openTimeFxt -= openTimeFxt % DAYS;                                                              // 00:00 des aktuellen Tages

      // closeTimeFxt auf den 1. des folgenden Monats, 00:00 setzen
      dom = TimeDayEx(openTimeFxt);
      closeTimeFxt = openTimeFxt - (dom-1)*DAYS;                                                      // erster des aktuellen Monats

      // openTimeFxt auf den 1. des vorherigen Monats, 00:00 Uhr setzen
      openTimeFxt  = closeTimeFxt - 1*DAYS;                                                           // letzter Tag des vorherigen Monats
      openTimeFxt -= (TimeDayEx(openTimeFxt)-1)*DAYS;                                                 // erster Tag des vorherigen Monats

      // Wochenenden in openTimeFxt überspringen
      dow = TimeDayOfWeekEx(openTimeFxt);
      if      (dow == SATURDAY) openTimeFxt += 2*DAYS;
      else if (dow == SUNDAY  ) openTimeFxt += 1*DAY;

      // Wochenenden in closeTimeFxt überspringen
      dow = TimeDayOfWeekEx(closeTimeFxt);
      if      (dow == SUNDAY) closeTimeFxt -= 1*DAY;
      else if (dow == MONDAY) closeTimeFxt -= 2*DAYS;
   }


   // (10) PERIOD_Q1
   else if (timeframe == PERIOD_Q1) {
      // ist openTimeFxt nicht gesetzt, Variable mit Zeitpunkt des nächsten Quartals initialisieren
      if (!openTimeFxt) {
         nowFxt      = TimeFXT(); if (!nowFxt) return(false);
         openTimeFxt = nowFxt + 1*QUARTER;

         monthNow      = TimeMonth(nowFxt     );                                                      // QUARTER ist nicht fix: Sicherstellen, daß openTimeFxt
         monthOpenTime = TimeMonth(openTimeFxt);                                                      // nicht schon auf das übernächste Quartal zeigt.
         if (monthNow > monthOpenTime)
            monthOpenTime += 12;
         if (monthOpenTime > monthNow+3)
            openTimeFxt -= 1*MONTH;
      }

      openTimeFxt -= openTimeFxt % DAYS;                                                              // 00:00 des aktuellen Tages

      // closeTimeFxt auf den ersten Tag des folgenden Quartals, 00:00 setzen
      switch (TimeMonth(openTimeFxt)) {
         case JANUARY  :
         case FEBRUARY :
         case MARCH    : closeTimeFxt = openTimeFxt -   (TimeDayOfYear(openTimeFxt)-1)*DAYS; break;   // erster Tag des aktuellen Quartals (01.01.)
         case APRIL    : closeTimeFxt = openTimeFxt -       (TimeDayEx(openTimeFxt)-1)*DAYS; break;
         case MAY      : closeTimeFxt = openTimeFxt - (30+   TimeDayEx(openTimeFxt)-1)*DAYS; break;
         case JUNE     : closeTimeFxt = openTimeFxt - (30+31+TimeDayEx(openTimeFxt)-1)*DAYS; break;   // erster Tag des aktuellen Quartals (01.04.)
         case JULY     : closeTimeFxt = openTimeFxt -       (TimeDayEx(openTimeFxt)-1)*DAYS; break;
         case AUGUST   : closeTimeFxt = openTimeFxt - (31+   TimeDayEx(openTimeFxt)-1)*DAYS; break;
         case SEPTEMBER: closeTimeFxt = openTimeFxt - (31+31+TimeDayEx(openTimeFxt)-1)*DAYS; break;   // erster Tag des aktuellen Quartals (01.07.)
         case OCTOBER  : closeTimeFxt = openTimeFxt -       (TimeDayEx(openTimeFxt)-1)*DAYS; break;
         case NOVEMBER : closeTimeFxt = openTimeFxt - (31+   TimeDayEx(openTimeFxt)-1)*DAYS; break;
         case DECEMBER : closeTimeFxt = openTimeFxt - (31+30+TimeDayEx(openTimeFxt)-1)*DAYS; break;   // erster Tag des aktuellen Quartals (01.10.)
      }

      // openTimeFxt auf den ersten Tag des vorherigen Quartals, 00:00 Uhr setzen
      openTimeFxt = closeTimeFxt - 1*DAY;                                                             // letzter Tag des vorherigen Quartals
      switch (TimeMonth(openTimeFxt)) {
         case MARCH    : openTimeFxt -=   (TimeDayOfYear(openTimeFxt)-1)*DAYS; break;                 // erster Tag des vorherigen Quartals (01.01.)
         case JUNE     : openTimeFxt -= (30+31+TimeDayEx(openTimeFxt)-1)*DAYS; break;                 // erster Tag des vorherigen Quartals (01.04.)
         case SEPTEMBER: openTimeFxt -= (31+31+TimeDayEx(openTimeFxt)-1)*DAYS; break;                 // erster Tag des vorherigen Quartals (01.07.)
         case DECEMBER : openTimeFxt -= (31+30+TimeDayEx(openTimeFxt)-1)*DAYS; break;                 // erster Tag des vorherigen Quartals (01.10.)
      }

      // Wochenenden in openTimeFxt überspringen
      dow = TimeDayOfWeekEx(openTimeFxt);
      if      (dow == SATURDAY) openTimeFxt += 2*DAYS;
      else if (dow == SUNDAY  ) openTimeFxt += 1*DAY;

      // Wochenenden in closeTimeFxt überspringen
      dow = TimeDayOfWeekEx(closeTimeFxt);
      if      (dow == SUNDAY) closeTimeFxt -= 1*DAY;
      else if (dow == MONDAY) closeTimeFxt -= 2*DAYS;
   }
   else return(!catch("iPreviousPeriodTimes(1)  invalid parameter timeframe: "+ timeframe, ERR_INVALID_PARAMETER));


   // entsprechende Serverzeiten ermitteln und setzen
   openTimeSrv  = FxtToServerTime(openTimeFxt ); if (openTimeSrv  == NaT) return(false);
   closeTimeSrv = FxtToServerTime(closeTimeFxt); if (closeTimeSrv == NaT) return(false);

   return(!catch("iPreviousPeriodTimes(2)"));
}
