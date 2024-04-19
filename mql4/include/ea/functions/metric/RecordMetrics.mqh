/**
 * Update the recorder with current metric values.
 *
 * @return int - error status
 */
int RecordMetrics() {
   if (recorder.mode == RECORDER_CUSTOM) {
      int size = ArraySize(metric.ready);
      if (size > METRIC_NET_MONEY) metric.currValue[METRIC_NET_MONEY] = stats[METRIC_NET_MONEY][S_TOTAL_PROFIT];
      if (size > METRIC_NET_UNITS) metric.currValue[METRIC_NET_UNITS] = stats[METRIC_NET_UNITS][S_TOTAL_PROFIT];
      if (size > METRIC_SIG_UNITS) metric.currValue[METRIC_SIG_UNITS] = stats[METRIC_SIG_UNITS][S_TOTAL_PROFIT];
   }
   return(NO_ERROR);
}
