/**
 * ShowStatus: Update the description of the displayed metric.
 */
void SS.MetricDescription() {
   switch (status.activeMetric) {
      case METRIC_NET_MONEY:
         if (status.profitInPercent) {                   // always net
            status.metricDescription = StringConcatenate("PnL in %", NL, "-----------");
         }
         else {                                          // always net
            status.metricDescription = StringConcatenate("PnL in ", AccountCurrency(), NL, "-------------");
         }
         break;
      case METRIC_NET_UNITS:
         status.metricDescription = StringConcatenate("PnL in ", spUnit, " (net)", NL, "-------------------", ifString(spUnit=="point", "--", ""));
         break;
      case METRIC_SIG_UNITS:
         status.metricDescription = StringConcatenate("PnL in ", spUnit, " (signal)", NL, "---------------------", ifString(spUnit=="point", "--", ""));
         break;

      default:
         return(!catch("SS.MetricDescription(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
   }
}
