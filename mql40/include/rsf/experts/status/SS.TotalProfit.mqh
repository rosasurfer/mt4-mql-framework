/**
 * ShowStatus: Update the string representation of the total instance PnL.
 */
void SS.TotalProfit() {
   // not before a position was opened
   if (!open.ticket && !ArrayRange(history, 0)) {
      status.totalProfit = "-";
   }
   else {
      int metric = status.activeMetric;
      switch (metric) {
         case METRIC_NET_MONEY:
            if (status.profitInPercent) status.totalProfit = NumberToStr(MathDiv(stats[metric][S_TOTAL_PROFIT], instance.startEquity) * 100, "R+.2") +"%";
            else                        status.totalProfit = NumberToStr(stats[metric][S_TOTAL_PROFIT], "R+.2") +" "+ AccountCurrency();
            break;

         case METRIC_NET_UNITS:
         case METRIC_SIG_UNITS:
            status.totalProfit = NumberToStr(stats[metric][S_TOTAL_PROFIT]/pUnit, "R+."+ pDigits) +" "+ spUnit;
            break;

         default:
            return(!catch("SS.TotalProfit(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
      }
   }
}
