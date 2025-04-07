/**
 * ShowStatus: Update the description of the displayed metric.
 */
void SS.MetricDescription() {
   switch (status.activeMetric) {
      case METRIC_NET_MONEY:
         status.metricDescription = "Net PnL after all costs in "+ AccountCurrency() + NL + "-----------------------------------";
         break;
      case METRIC_NET_UNITS:
         status.metricDescription = "Net PnL after all costs in "+ spUnit + NL + "---------------------------------"+ ifString(spUnit=="point", "--", "");
         break;
      case METRIC_SIG_UNITS:
         status.metricDescription = "Signal PnL before spread/any costs in "+ spUnit + NL + "-------------------------------------------------"+ ifString(spUnit=="point", "--", "");
         break;

      default:
         return(!catch("SS.MetricDescription(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
   }
}
