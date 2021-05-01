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
bool iPreviousPeriodTimes(int timeframe/*=NULL*/, datetime &openTime.fxt/*=NULL*/, datetime &closeTime.fxt, datetime &openTime.srv, datetime &closeTime.srv) {
   if (!timeframe)
      timeframe = Period();
   int month, dom, dow, monthOpenTime, monthNow;
   datetime now.fxt;


   // (1) PERIOD_M1
   if (timeframe == PERIOD_M1) {
      // ist openTime.fxt nicht gesetzt, Variable mit Zeitpunkt der nächste Minute initialisieren
      if (!openTime.fxt) {
         now.fxt      = TimeFXT(); if (!now.fxt) return(false);
         openTime.fxt = now.fxt + 1*MINUTE;
      }

      // openTime.fxt auf den Beginn der vorherigen Minute setzen
      openTime.fxt -= (openTime.fxt%MINUTES + 1*MINUTE);

      // Wochenenden in openTime.fxt überspringen
      dow = TimeDayOfWeekEx(openTime.fxt);
      if      (dow == SATURDAY) openTime.fxt -= (1*DAY  + openTime.fxt%DAYS - 23*HOURS - 59*MINUTES);    // Freitag 23:59
      else if (dow == SUNDAY  ) openTime.fxt -= (2*DAYS + openTime.fxt%DAYS - 23*HOURS - 59*MINUTES);

      // closeTime.fxt auf das Ende der Minute setzen
      closeTime.fxt = openTime.fxt + 1*MINUTE;
   }


   // (2) PERIOD_M5
   else if (timeframe == PERIOD_M5) {
      // ist openTime.fxt nicht gesetzt, Variable mit Zeitpunkt der nächsten 5 Minuten initialisieren
      if (!openTime.fxt) {
         now.fxt      = TimeFXT(); if (!now.fxt) return(false);
         openTime.fxt = now.fxt + 5*MINUTES;
      }

      // openTime.fxt auf den Beginn der vorherigen 5 Minuten setzen
      openTime.fxt -= (openTime.fxt%(5*MINUTES) + 5*MINUTES);

      // Wochenenden in openTime.fxt überspringen
      dow = TimeDayOfWeekEx(openTime.fxt);
      if      (dow == SATURDAY) openTime.fxt -= (1*DAY  + openTime.fxt%DAYS - 23*HOURS - 55*MINUTES);    // Freitag 23:55
      else if (dow == SUNDAY  ) openTime.fxt -= (2*DAYS + openTime.fxt%DAYS - 23*HOURS - 55*MINUTES);

      // closeTime.fxt auf das Ende der 5 Minuten setzen
      closeTime.fxt = openTime.fxt + 5*MINUTES;
   }


   // (3) PERIOD_M15
   else if (timeframe == PERIOD_M15) {
      // ist openTime.fxt nicht gesetzt, Variable mit Zeitpunkt der nächsten Viertelstunde initialisieren
      if (!openTime.fxt) {
         now.fxt      = TimeFXT(); if (!now.fxt) return(false);
         openTime.fxt = now.fxt + 15*MINUTES;
      }

      // openTime.fxt auf den Beginn der vorherigen Viertelstunde setzen
      openTime.fxt -= (openTime.fxt%(15*MINUTES) + 15*MINUTES);

      // Wochenenden in openTime.fxt überspringen
      dow = TimeDayOfWeekEx(openTime.fxt);
      if      (dow == SATURDAY) openTime.fxt -= (1*DAY  + openTime.fxt%DAYS - 23*HOURS - 45*MINUTES);    // Freitag 23:45
      else if (dow == SUNDAY  ) openTime.fxt -= (2*DAYS + openTime.fxt%DAYS - 23*HOURS - 45*MINUTES);

      // closeTime.fxt auf das Ende der Viertelstunde setzen
      closeTime.fxt = openTime.fxt + 15*MINUTES;
   }


   // (4) PERIOD_M30
   else if (timeframe == PERIOD_M30) {
      // ist openTime.fxt nicht gesetzt, Variable mit Zeitpunkt der nächsten halben Stunde initialisieren
      if (!openTime.fxt) {
         now.fxt      = TimeFXT(); if (!now.fxt) return(false);
         openTime.fxt = now.fxt + 30*MINUTES;
      }

      // openTime.fxt auf den Beginn der vorherigen halben Stunde setzen
      openTime.fxt -= (openTime.fxt%(30*MINUTES) + 30*MINUTES);

      // Wochenenden in openTime.fxt überspringen
      dow = TimeDayOfWeekEx(openTime.fxt);
      if      (dow == SATURDAY) openTime.fxt -= (1*DAY  + openTime.fxt%DAYS - 23*HOURS - 30*MINUTES);    // Freitag 23:30
      else if (dow == SUNDAY  ) openTime.fxt -= (2*DAYS + openTime.fxt%DAYS - 23*HOURS - 30*MINUTES);

      // closeTime.fxt auf das Ende der halben Stunde setzen
      closeTime.fxt = openTime.fxt + 30*MINUTES;
   }


   // (5) PERIOD_H1
   else if (timeframe == PERIOD_H1) {
      // ist openTime.fxt nicht gesetzt, Variable mit Zeitpunkt der nächsten Stunde initialisieren
      if (!openTime.fxt) {
         now.fxt      = TimeFXT(); if (!now.fxt) return(false);
         openTime.fxt = now.fxt + 1*HOUR;
      }

      // openTime.fxt auf den Beginn der vorherigen Stunde setzen
      openTime.fxt -= (openTime.fxt%HOURS + 1*HOUR);

      // Wochenenden in openTime.fxt überspringen
      dow = TimeDayOfWeekEx(openTime.fxt);
      if      (dow == SATURDAY) openTime.fxt -= (1*DAY  + openTime.fxt%DAYS - 23*HOURS);                 // Freitag 23:00
      else if (dow == SUNDAY  ) openTime.fxt -= (2*DAYS + openTime.fxt%DAYS - 23*HOURS);

      // closeTime.fxt auf das Ende der Stunde setzen
      closeTime.fxt = openTime.fxt + 1*HOUR;
   }


   // (6) PERIOD_H4
   else if (timeframe == PERIOD_H4) {
      // ist openTime.fxt nicht gesetzt, Variable mit Zeitpunkt der nächsten H4-Periode initialisieren
      if (!openTime.fxt) {
         now.fxt      = TimeFXT(); if (!now.fxt) return(false);
         openTime.fxt = now.fxt + 4*HOURS;
      }

      // openTime.fxt auf den Beginn der vorherigen H4-Periode setzen
      openTime.fxt -= (openTime.fxt%(4*HOURS) + 4*HOURS);

      // Wochenenden in openTime.fxt überspringen
      dow = TimeDayOfWeekEx(openTime.fxt);
      if      (dow == SATURDAY) openTime.fxt -= (1*DAY  + openTime.fxt%DAYS - 20*HOURS);                 // Freitag 20:00
      else if (dow == SUNDAY  ) openTime.fxt -= (2*DAYS + openTime.fxt%DAYS - 20*HOURS);

      // closeTime.fxt auf das Ende der H4-Periode setzen
      closeTime.fxt = openTime.fxt + 4*HOURS;
   }


   // (7) PERIOD_D1
   else if (timeframe == PERIOD_D1) {
      // ist openTime.fxt nicht gesetzt, Variable mit Zeitpunkt des nächsten Tages initialisieren
      if (!openTime.fxt) {
         now.fxt      = TimeFXT(); if (!now.fxt) return(false);
         openTime.fxt = now.fxt + 1*DAY;
      }

      // openTime.fxt auf 00:00 Uhr des vorherigen Tages setzen
      openTime.fxt -= (openTime.fxt%DAYS + 1*DAY);

      // Wochenenden in openTime.fxt überspringen
      dow = TimeDayOfWeekEx(openTime.fxt);
      if      (dow == SATURDAY) openTime.fxt -= 1*DAY;
      else if (dow == SUNDAY  ) openTime.fxt -= 2*DAYS;

      // closeTime.fxt auf das Ende des Tages setzen
      closeTime.fxt = openTime.fxt + 1*DAY;
   }


   // (8) PERIOD_W1
   else if (timeframe == PERIOD_W1) {
      // ist openTime.fxt nicht gesetzt, Variable mit Zeitpunkt der nächsten Woche initialisieren
      if (!openTime.fxt) {
         now.fxt      = TimeFXT(); if (!now.fxt) return(false);
         openTime.fxt = now.fxt + 7*DAYS;
      }

      // openTime.fxt auf Montag, 00:00 Uhr der vorherigen Woche setzen
      openTime.fxt -= openTime.fxt % DAYS;                                                               // 00:00 des aktuellen Tages
      openTime.fxt -= (TimeDayOfWeekEx(openTime.fxt)+6)%7 * DAYS;                                        // Montag der aktuellen Woche
      openTime.fxt -= 7*DAYS;                                                                            // Montag der Vorwoche

      // closeTime.fxt auf 00:00 des folgenden Samstags setzen
      closeTime.fxt = openTime.fxt + 5*DAYS;
   }


   // (9) PERIOD_MN1
   else if (timeframe == PERIOD_MN1) {
      // ist openTime.fxt nicht gesetzt, Variable mit Zeitpunkt des nächsten Monats initialisieren
      if (!openTime.fxt) {
         now.fxt      = TimeFXT(); if (!now.fxt) return(false);
         openTime.fxt = now.fxt + 1*MONTH;

         monthNow      = TimeMonth(now.fxt     );                                                        // MONTH ist nicht fix: Sicherstellen, daß openTime.fxt
         monthOpenTime = TimeMonth(openTime.fxt);                                                        // nicht schon auf den übernächsten Monat zeigt.
         if (monthNow > monthOpenTime)
            monthOpenTime += 12;
         if (monthOpenTime > monthNow+1)
            openTime.fxt -= 4*DAYS;
      }

      openTime.fxt -= openTime.fxt % DAYS;                                                               // 00:00 des aktuellen Tages

      // closeTime.fxt auf den 1. des folgenden Monats, 00:00 setzen
      dom = TimeDayEx(openTime.fxt);
      closeTime.fxt = openTime.fxt - (dom-1)*DAYS;                                                       // erster des aktuellen Monats

      // openTime.fxt auf den 1. des vorherigen Monats, 00:00 Uhr setzen
      openTime.fxt  = closeTime.fxt - 1*DAYS;                                                            // letzter Tag des vorherigen Monats
      openTime.fxt -= (TimeDayEx(openTime.fxt)-1)*DAYS;                                                  // erster Tag des vorherigen Monats

      // Wochenenden in openTime.fxt überspringen
      dow = TimeDayOfWeekEx(openTime.fxt);
      if      (dow == SATURDAY) openTime.fxt += 2*DAYS;
      else if (dow == SUNDAY  ) openTime.fxt += 1*DAY;

      // Wochenenden in closeTime.fxt überspringen
      dow = TimeDayOfWeekEx(closeTime.fxt);
      if      (dow == SUNDAY) closeTime.fxt -= 1*DAY;
      else if (dow == MONDAY) closeTime.fxt -= 2*DAYS;
   }


   // (10) PERIOD_Q1
   else if (timeframe == PERIOD_Q1) {
      // ist openTime.fxt nicht gesetzt, Variable mit Zeitpunkt des nächsten Quartals initialisieren
      if (!openTime.fxt) {
         now.fxt      = TimeFXT(); if (!now.fxt) return(false);
         openTime.fxt = now.fxt + 1*QUARTER;

         monthNow      = TimeMonth(now.fxt     );                                                        // QUARTER ist nicht fix: Sicherstellen, daß openTime.fxt
         monthOpenTime = TimeMonth(openTime.fxt);                                                        // nicht schon auf das übernächste Quartal zeigt.
         if (monthNow > monthOpenTime)
            monthOpenTime += 12;
         if (monthOpenTime > monthNow+3)
            openTime.fxt -= 1*MONTH;
      }

      openTime.fxt -= openTime.fxt % DAYS;                                                               // 00:00 des aktuellen Tages

      // closeTime.fxt auf den ersten Tag des folgenden Quartals, 00:00 setzen
      switch (TimeMonth(openTime.fxt)) {
         case JANUARY  :
         case FEBRUARY :
         case MARCH    : closeTime.fxt = openTime.fxt -   (TimeDayOfYear(openTime.fxt)-1)*DAYS; break;   // erster Tag des aktuellen Quartals (01.01.)
         case APRIL    : closeTime.fxt = openTime.fxt -       (TimeDayEx(openTime.fxt)-1)*DAYS; break;
         case MAY      : closeTime.fxt = openTime.fxt - (30+   TimeDayEx(openTime.fxt)-1)*DAYS; break;
         case JUNE     : closeTime.fxt = openTime.fxt - (30+31+TimeDayEx(openTime.fxt)-1)*DAYS; break;   // erster Tag des aktuellen Quartals (01.04.)
         case JULY     : closeTime.fxt = openTime.fxt -       (TimeDayEx(openTime.fxt)-1)*DAYS; break;
         case AUGUST   : closeTime.fxt = openTime.fxt - (31+   TimeDayEx(openTime.fxt)-1)*DAYS; break;
         case SEPTEMBER: closeTime.fxt = openTime.fxt - (31+31+TimeDayEx(openTime.fxt)-1)*DAYS; break;   // erster Tag des aktuellen Quartals (01.07.)
         case OCTOBER  : closeTime.fxt = openTime.fxt -       (TimeDayEx(openTime.fxt)-1)*DAYS; break;
         case NOVEMBER : closeTime.fxt = openTime.fxt - (31+   TimeDayEx(openTime.fxt)-1)*DAYS; break;
         case DECEMBER : closeTime.fxt = openTime.fxt - (31+30+TimeDayEx(openTime.fxt)-1)*DAYS; break;   // erster Tag des aktuellen Quartals (01.10.)
      }

      // openTime.fxt auf den ersten Tag des vorherigen Quartals, 00:00 Uhr setzen
      openTime.fxt = closeTime.fxt - 1*DAY;                                                              // letzter Tag des vorherigen Quartals
      switch (TimeMonth(openTime.fxt)) {
         case MARCH    : openTime.fxt -=   (TimeDayOfYear(openTime.fxt)-1)*DAYS; break;                  // erster Tag des vorherigen Quartals (01.01.)
         case JUNE     : openTime.fxt -= (30+31+TimeDayEx(openTime.fxt)-1)*DAYS; break;                  // erster Tag des vorherigen Quartals (01.04.)
         case SEPTEMBER: openTime.fxt -= (31+31+TimeDayEx(openTime.fxt)-1)*DAYS; break;                  // erster Tag des vorherigen Quartals (01.07.)
         case DECEMBER : openTime.fxt -= (31+30+TimeDayEx(openTime.fxt)-1)*DAYS; break;                  // erster Tag des vorherigen Quartals (01.10.)
      }

      // Wochenenden in openTime.fxt überspringen
      dow = TimeDayOfWeekEx(openTime.fxt);
      if      (dow == SATURDAY) openTime.fxt += 2*DAYS;
      else if (dow == SUNDAY  ) openTime.fxt += 1*DAY;

      // Wochenenden in closeTime.fxt überspringen
      dow = TimeDayOfWeekEx(closeTime.fxt);
      if      (dow == SUNDAY) closeTime.fxt -= 1*DAY;
      else if (dow == MONDAY) closeTime.fxt -= 2*DAYS;
   }
   else return(!catch("iPreviousPeriodTimes(1)  invalid parameter timeframe: "+ timeframe, ERR_INVALID_PARAMETER));


   // entsprechende Serverzeiten ermitteln und setzen
   openTime.srv  = FxtToServerTime(openTime.fxt ); if (openTime.srv  == NaT) return(false);
   closeTime.srv = FxtToServerTime(closeTime.fxt); if (closeTime.srv == NaT) return(false);

   return(!catch("iPreviousPeriodTimes(2)"));
}
