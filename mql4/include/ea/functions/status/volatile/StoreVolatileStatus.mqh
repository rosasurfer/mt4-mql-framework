/**
 * Store volatile runtime vars in chart and chart window (for template reload, terminal restart, recompilation etc).
 *
 * @return bool - success status
 */
bool StoreVolatileStatus() {
   string name = ProgramName();

   // input string Instance.ID
   string value = ifString(instance.isTest, "T", "") + StrPadLeft(instance.id, 3, "0");
   Instance.ID = value;
   if (__isChart) {
      string key = name +".Instance.ID";
      SetWindowStringA(__ExecutionContext[EC.hChart], key, value);
      Chart.StoreString(key, value);
   }

   // int status.activeMetric
   if (__isChart) {
      key = name +".status.activeMetric";
      SetWindowIntegerA(__ExecutionContext[EC.hChart], key, status.activeMetric);
      Chart.StoreInt(key, status.activeMetric);
   }

   // bool status.showOpenOrders
   if (__isChart) {
      key = name +".status.showOpenOrders";
      SetWindowIntegerA(__ExecutionContext[EC.hChart], key, ifInt(status.showOpenOrders, 1, -1));
      Chart.StoreBool(key, status.showOpenOrders);
   }

   // bool status.showTradeHistory
   if (__isChart) {
      key = name +".status.showTradeHistory";
      SetWindowIntegerA(__ExecutionContext[EC.hChart], key, ifInt(status.showTradeHistory, 1, -1));
      Chart.StoreBool(key, status.showTradeHistory);
   }
   return(!catch("StoreVolatileStatus(1)"));
}
