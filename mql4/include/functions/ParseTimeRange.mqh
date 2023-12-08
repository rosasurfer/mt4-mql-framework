/**
 * Parse a time range description and return the resulting time parts.
 *
 * @param  _In_  string range  - time range description (format: 09:12-18:34)
 * @param  _Out_ int    from   - range start time in minutes since Midnight (server time)
 * @param  _Out_ int    to     - range end time in minutes since Midnight (server time)
 * @param  _Out_ int    period - largest price period usable for matching range calculations
 *
 * @return bool - success status
 */
bool ParseTimeRange(string range, int &from, int &to, int &period) {
   if (!StrContains(range, "-")) return(false);
   int result[];

   string sFrom = StrTrim(StrLeftTo(range, "-"));
   if (!ParseDateTime(sFrom, DATE_OPTIONAL, result)) return(false);
   if (result[PT_HAS_DATE] || result[PT_SECOND])     return(false);
   int _from = result[PT_HOUR]*60 + result[PT_MINUTE];

   string sTo = StrTrim(StrRightFrom(range, "-"));
   if (!ParseDateTime(sTo, DATE_OPTIONAL, result)) return(false);
   if (result[PT_HAS_DATE] || result[PT_SECOND])   return(false);
   int _to = result[PT_HOUR]*60 + result[PT_MINUTE];

   if (_from >= _to) return(false);
   from = _from;
   to   = _to;

   if      (!(from % PERIOD_H1  + to % PERIOD_H1))  period = PERIOD_H1;
   else if (!(from % PERIOD_M30 + to % PERIOD_M30)) period = PERIOD_M30;
   else if (!(from % PERIOD_M15 + to % PERIOD_M15)) period = PERIOD_M15;
   else if (!(from % PERIOD_M5  + to % PERIOD_M5))  period = PERIOD_M5;
   else                                             period = PERIOD_M1;

   return(true);
}
