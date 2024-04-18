/**
 * Update the recorder with current metric values.
 *
 * @return int - error status
 */
int RecordMetrics() {
   if (recorder.mode == RECORDER_CUSTOM) {
      int size = ArraySize(metric.ready);
      if (size > METRIC_NET_MONEY) metric.currValue[METRIC_NET_MONEY] = stats.totalNetProfit;
      if (size > METRIC_NET_UNITS) metric.currValue[METRIC_NET_UNITS] = stats.totalNetProfitP;
      if (size > METRIC_SIG_UNITS) metric.currValue[METRIC_SIG_UNITS] = stats.totalSigProfitP;
   }
   return(NO_ERROR);
}
