/**
 * Return the description of a timeframe identifier. Supports custom timeframes.
 *
 * @param  int period [optional] - timeframe identifier or number of minutes per period (default: the current chart period)
 *
 * @return string
 */
string PeriodDescription(int period = NULL) {
   // We need an MQL implementation, as DLL calls may be disabled. This one should match the one in the MT4Expander.

   if (!period) period = Period();

   switch (period) {
      case PERIOD_M1:  return("M1");      // 1 minute
      case PERIOD_M2:  return("M2");      // 2 minutes  (custom timeframe)
      case PERIOD_M3:  return("M3");      // 3 minutes  (custom timeframe)
      case PERIOD_M4:  return("M4");      // 4 minutes  (custom timeframe)
      case PERIOD_M5:  return("M5");      // 5 minutes
      case PERIOD_M6:  return("M6");      // 6 minutes  (custom timeframe)
      case PERIOD_M10: return("M10");     // 10 minutes (custom timeframe)
      case PERIOD_M12: return("M12");     // 12 minutes (custom timeframe)
      case PERIOD_M15: return("M15");     // 15 minutes
      case PERIOD_M20: return("M20");     // 20 minutes (custom timeframe)
      case PERIOD_M30: return("M30");     // 30 minutes
      case PERIOD_H1:  return("H1");      // 1 hour
      case PERIOD_H2:  return("H2");      // 2 hours    (custom timeframe)
      case PERIOD_H3:  return("H3");      // 3 hours    (custom timeframe)
      case PERIOD_H4:  return("H4");      // 4 hours
      case PERIOD_H6:  return("H6");      // 6 hours    (custom timeframe)
      case PERIOD_H8:  return("H8");      // 8 hours    (custom timeframe)
      case PERIOD_H12: return("H12");     // 12 hours   (custom timeframe)
      case PERIOD_D1:  return("D1");      // 1 day
      case PERIOD_W1:  return("W1");      // 1 week
      case PERIOD_MN1: return("MN1");     // 1 month
      case PERIOD_Q1:  return("Q1");      // 1 quarter  (custom timeframe)
   }
   return(StringConcatenate("", period));
}
