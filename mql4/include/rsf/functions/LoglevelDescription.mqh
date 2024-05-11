/**
 * Return the description of a loglevel constant.
 *
 * @param  int level - loglevel
 *
 * @return string
 */
string LoglevelDescription(int level) {
   // Also implemented in the Expander but here I prefer static MQL strings, as it's in the hot path of the logger.

   switch (level) {
      case LOG_DEBUG : return("DEBUG" );
      case LOG_INFO  : return("INFO"  );
      case LOG_NOTICE: return("NOTICE");
      case LOG_WARN  : return("WARN"  );
      case LOG_ERROR : return("ERROR" );
      case LOG_FATAL : return("FATAL" );
      case LOG_OFF   : return("OFF"   );        // not a regular loglevel
   }
   return(StringConcatenate("", level));
}
