/**
 * Update the recorder with current metric values.
 */
void RecordMetrics() {
   if (recorder.mode == RECORDER_CUSTOM) {
      int size = ArraySize(metric.ready);
      if (size > METRIC_TOTAL_NET_MONEY) metric.currValue[METRIC_TOTAL_NET_MONEY] = instance.totalNetProfit;
      if (size > METRIC_TOTAL_NET_UNITS) metric.currValue[METRIC_TOTAL_NET_UNITS] = instance.totalNetProfitP;
      if (size > METRIC_TOTAL_SIG_UNITS) metric.currValue[METRIC_TOTAL_SIG_UNITS] = instance.totalSigProfitP;
   }
}
