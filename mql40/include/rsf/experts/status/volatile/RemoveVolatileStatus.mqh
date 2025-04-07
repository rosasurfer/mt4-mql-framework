/**
 * Remove stored volatile runtime vars from chart and chart window.
 *
 * @return bool - success status
 */
bool RemoveVolatileStatus() {
   string name = ProgramName();

   // input string Instance.ID
   if (__isChart) {
      string key = name +".Instance.ID";
      string sValue = RemoveWindowStringA(__ExecutionContext[EC.chart], key);
      Chart.RestoreString(key, sValue, true);
   }

   // int status.activeMetric
   if (__isChart) {
      key = name +".status.activeMetric";
      int iValue = RemoveWindowIntegerA(__ExecutionContext[EC.chart], key);
      Chart.RestoreInt(key, iValue, true);
   }

   // bool status.showOpenOrders
   if (__isChart) {
      key = name +".status.showOpenOrders";
      bool bValue = RemoveWindowIntegerA(__ExecutionContext[EC.chart], key);
      Chart.RestoreBool(key, bValue, true);
   }

   // bool status.showTradeHistory
   if (__isChart) {
      key = name +".status.showTradeHistory";
      bValue = RemoveWindowIntegerA(__ExecutionContext[EC.chart], key);
      Chart.RestoreBool(key, bValue, true);
   }

   // event object for chart commands
   if (__isChart) {
      key = "EA.status";
      if (ObjectFind(key) != -1) ObjectDelete(key);
   }
   return(!catch("RemoveVolatileStatus(1)"));
}
