/**
 * ShowStatus: Update the description of the displayed metric.
 */
void SS.MetricDescription() {
   switch (status.activeMetric) {
      case METRIC_TOTAL_NET_MONEY:
         sMetricDescription = "Net PnL after all costs in "+ AccountCurrency() + NL + "-----------------------------------";
         break;
      case METRIC_TOTAL_NET_UNITS:
         sMetricDescription = "Net PnL after all costs in "+ pUnit + NL + "---------------------------------"+ ifString(pUnit=="point", "---", "");
         break;
      case METRIC_TOTAL_SYNTH_UNITS:
         sMetricDescription = "Synthetic PnL before spread/any costs in "+ pUnit + NL + "------------------------------------------------------"+ ifString(pUnit=="point", "--", "");
         break;

      default:
         return(!catch("SS.MetricDescription(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
   }
}
