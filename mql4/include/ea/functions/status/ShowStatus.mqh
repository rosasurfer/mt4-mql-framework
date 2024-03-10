/**
 * Display the current instance status.
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error
 */
int ShowStatus(int error = NO_ERROR) {
   if (!__isChart) return(error);

   static bool isRecursion = false;          // to prevent recursive calls a specified error is displayed only once
   if (error != 0) {
      if (isRecursion) return(error);
      isRecursion = true;
   }
   string sStatus="", sError="";

   switch (instance.status) {
      case NULL:           sStatus = "  (not initialized)"; break;
      case STATUS_WAITING: sStatus = "  (waiting)";         break;
      case STATUS_TRADING: sStatus = "  (trading)";         break;
      case STATUS_STOPPED: sStatus = "  (stopped)";         break;
      default:
         return(catch("ShowStatus(1)  "+ instance.name +" illegal instance status: "+ instance.status, ERR_ILLEGAL_STATE));
   }
   if (__STATUS_OFF) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason), "]");

   string text = StringConcatenate(WindowExpertName(), "    ID: ", instance.id, sStatus, sError, NL,
                                                                                                 NL,
                                   status.metricDescription,                                     NL,
                                   "Open:    ",   status.openLots,                               NL,
                                   "Closed:  ",   status.closedTrades,                           NL,
                                   "Profit:    ", status.totalProfit, "  ", status.profitStats,  NL
   );

   // 3 lines margin-top for instrument and indicator legends
   Comment(NL, NL, NL, text);
   if (__CoreFunction == CF_INIT) WindowRedraw();

   // store status in the chart to enable sending of chart commands
   string label = "EA.status";
   if (ObjectFind(label) != 0) {
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   }
   ObjectSetText(label, StringConcatenate(Instance.ID, "|", StatusDescription(instance.status)));

   error = intOr(catch("ShowStatus(2)"), error);
   isRecursion = false;
   return(error);
}
