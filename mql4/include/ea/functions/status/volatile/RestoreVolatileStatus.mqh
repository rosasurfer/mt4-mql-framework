/**
 * Restore volatile runtime vars from chart or chart window (for template reload, terminal restart, recompilation etc).
 *
 * @return bool - whether an instance id was successfully restored
 */
bool RestoreVolatileStatus() {
   string name = ProgramName();

   // input string Instance.ID
   while (true) {
      bool error = false;
      if (SetInstanceId(Instance.ID, error, "RestoreVolatileStatus(1)")) break;
      if (error) return(false);

      if (__isChart) {
         string key = name +".Instance.ID";
         string sValue = GetWindowStringA(__ExecutionContext[EC.hChart], key);
         if (SetInstanceId(sValue, error, "RestoreVolatileStatus(2)")) break;
         if (error) return(false);

         Chart.RestoreString(key, sValue, false);
         if (SetInstanceId(sValue, error, "RestoreVolatileStatus(3)")) break;
         return(false);
      }
   }

   // int status.activeMetric
   if (__isChart) {
      key = name +".status.activeMetric";
      while (true) {
         int iValue = GetWindowIntegerA(__ExecutionContext[EC.hChart], key);
         if (iValue != 0) {
            if (iValue > 0 && iValue <= 3) {                // valid metrics: 1-3
               status.activeMetric = iValue;
               break;
            }
         }
         if (Chart.RestoreInt(key, iValue, false)) {
            if (iValue > 0 && iValue <= 3) {
               status.activeMetric = iValue;
               break;
            }
         }
         logWarn("RestoreVolatileStatus(4)  "+ instance.name +"  invalid data: status.activeMetric="+ iValue);
         status.activeMetric = 1;                           // reset to default value
         break;
      }
   }

   // bool status.showOpenOrders
   if (__isChart) {
      key = name +".status.showOpenOrders";
      iValue = GetWindowIntegerA(__ExecutionContext[EC.hChart], key);
      if (iValue != 0) {
         status.showOpenOrders = (iValue > 0);
      }
      else if (!Chart.RestoreBool(key, status.showOpenOrders, false)) {
         status.showOpenOrders = false;                     // reset to default value
      }
   }

   // bool status.showTradeHistory
   if (__isChart) {
      key = name +".status.showTradeHistory";
      iValue = GetWindowIntegerA(__ExecutionContext[EC.hChart], key);
      if (iValue != 0) {
         status.showTradeHistory = (iValue > 0);
      }
      else if (!Chart.RestoreBool(key, status.showTradeHistory, false)) {
         status.showOpenOrders = false;                     // reset to default value
      }
   }
   return(true);
}
