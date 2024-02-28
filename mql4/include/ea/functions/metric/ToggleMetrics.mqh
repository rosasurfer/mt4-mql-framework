/**
 * Toggle the EA display status between available metrics.
 *
 * @param  int direction - METRIC_NEXT|METRIC_PREVIOUS
 * @param  int minId     - min metric id
 * @param  int maxId     - max metric id
 *
 * @return bool - success status
 */
bool ToggleMetrics(int direction, int minId, int maxId) {
   if (direction!=METRIC_NEXT && direction!=METRIC_PREVIOUS) return(!catch("ToggleMetrics(1)  "+ instance.name +" invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   int prevMetric = status.activeMetric;

   status.activeMetric += direction;
   if (status.activeMetric < minId) status.activeMetric = maxId;
   if (status.activeMetric > maxId) status.activeMetric = minId;
   StoreVolatileData();
   SS.All();

   if (prevMetric==METRIC_TOTAL_SIG_UNITS || status.activeMetric==METRIC_TOTAL_SIG_UNITS) {
      if (status.showOpenOrders) {
         ToggleOpenOrders(false);
         ToggleOpenOrders(false);
      }
      if (status.showTradeHistory) {
         ToggleTradeHistory(false);
         ToggleTradeHistory(false);
      }
   }
   return(true);
}
