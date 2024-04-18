/**
 * ShowStatus: Update the string representation of the total instance PnL.
 */
void SS.TotalProfit() {
   // not before a position was opened
   if (!open.ticket && !ArrayRange(history, 0)) {
      status.totalProfit = "-";
   }
   else {
      switch (status.activeMetric) {
         case METRIC_NET_MONEY:
            if (ShowProfitInPercent) status.totalProfit = NumberToStr(MathDiv(stats.totalNetProfit, instance.startEquity) * 100, "R+.2") +"%";
            else                     status.totalProfit = NumberToStr(stats.totalNetProfit, "R+.2") +" "+ AccountCurrency();
            break;
         case METRIC_NET_UNITS:
            status.totalProfit = NumberToStr(stats.totalNetProfitP/pUnit, "R+."+ pDigits) +" "+ spUnit;
            break;
         case METRIC_SIG_UNITS:
            status.totalProfit = NumberToStr(stats.totalSigProfitP/pUnit, "R+."+ pDigits) +" "+ spUnit;
            break;

         default:
            return(!catch("SS.TotalProfit(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
      }
   }
}
