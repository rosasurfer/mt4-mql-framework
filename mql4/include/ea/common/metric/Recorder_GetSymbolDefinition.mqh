/**
 * Return a symbol definition for the specified metric to be recorded.
 *
 * @param  _In_  int    id          - metric id; 0 = standard AccountEquity() symbol, positive integer for custom metrics
 * @param  _Out_ bool   &ready      - whether metric details are complete and the metric is ready to be recorded
 * @param  _Out_ string &symbol     - unique MT4 timeseries symbol
 * @param  _Out_ string &descr      - symbol description as in the MT4 "Symbols" window (if empty a description is generated)
 * @param  _Out_ string &group      - symbol group name as in the MT4 "Symbols" window (if empty a name is generated)
 * @param  _Out_ int    &digits     - symbol digits value
 * @param  _Out_ double &baseValue  - quotes base value (if EMPTY recorder default settings are used)
 * @param  _Out_ int    &multiplier - quotes multiplier
 *
 * @return int - error status; especially ERR_INVALID_INPUT_PARAMETER if the passed metric id is unknown or not supported
 */
int Recorder_GetSymbolDefinition(int id, bool &ready, string &symbol, string &descr, string &group, int &digits, double &baseValue, int &multiplier) {
   string sId = ifString(!instance.id, "???", StrPadLeft(instance.id, 3, "0"));
   string descrSuffix="", sBarModel="";
   switch (__Test.barModel) {
      case MODE_EVERYTICK:     sBarModel = "EveryTick"; break;
      case MODE_CONTROLPOINTS: sBarModel = "ControlP";  break;
      case MODE_BAROPEN:       sBarModel = "BarOpen";   break;
      default:                 sBarModel = "Live";      break;
   }

   ready     = false;
   group     = "";
   baseValue = EMPTY;

   switch (id) {
      // --- symbol for recorder.mode = RECORDER_ON (standard account equity graph) -----------------------------------------
      case NULL:
         symbol     = recorder.stdEquitySymbol;
         descr      = "";
         digits     = 2;
         multiplier = 1;
         ready      = true;
         return(NO_ERROR);

      // --- default metrics ------------------------------------------------------------------------------------------------
      case METRIC_TOTAL_NET_MONEY:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"A";       // "US500.123A"
         descrSuffix = ", "+ PeriodDescription() +", "+ sBarModel +", net PnL, "+ AccountCurrency() + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         digits      = 2;
         multiplier  = 1;
         break;

      case METRIC_TOTAL_NET_UNITS:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"B";
         descrSuffix = ", "+ PeriodDescription() +", "+ sBarModel +", net PnL, "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         digits      = pDigits;
         multiplier  = pMultiplier;
         break;

      case METRIC_TOTAL_SIG_UNITS:
         symbol      = StrLeft(Symbol(), 6) +"."+ sId +"C";
         descrSuffix = ", "+ PeriodDescription() +", "+ sBarModel +", signal PnL, "+ pUnit + LocalTimeFormat(GetGmtTime(), ", %d.%m.%Y %H:%M");
         digits      = pDigits;
         multiplier  = pMultiplier;
         break;

      default:
         return(ERR_INVALID_INPUT_PARAMETER);
   }

   descr = StrLeft(ProgramName(), 63-StringLen(descrSuffix )) + descrSuffix;
   ready = (instance.id > 0);

   return(NO_ERROR);
}
