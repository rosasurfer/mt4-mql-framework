/**
 * ShowStatus: Update the string summary of the closed trades.
 */
void SS.ClosedTrades() {
   int size = ArrayRange(history, 0);
   if (!size) {
      status.closedTrades = "-";
   }
   else {
      if (!CalculateStats()) return;
      string trades = " trade"+ Pluralize(size);

      switch (status.activeMetric) {
         case METRIC_NET_MONEY:
            if (status.profitInPercent) {
               double totalPerformance = 1 + MathDiv(stats[METRIC_NET_MONEY][S_TOTAL_PROFIT], instance.startEquity);
               double avgPerformance   = MathPow(totalPerformance, 1./size);
               double avgTrade         = (avgPerformance - 1) * 100;
               status.closedTrades = size + trades +"    avg: "+ NumberToStr(avgTrade, "R+.2") +"%";
            }
            else {
               status.closedTrades = size + trades +"    avg: "+ NumberToStr(stats[METRIC_NET_MONEY][S_TRADES_AVG_PROFIT], "R+.2") +" "+ AccountCurrency();
            }
            break;
         case METRIC_NET_UNITS:
            status.closedTrades = size + trades +"    avg: "+ NumberToStr(stats[METRIC_NET_UNITS][S_TRADES_AVG_PROFIT]/pUnit, "R+."+ pDigits) +" "+ spUnit;
            break;
         case METRIC_SIG_UNITS:
            status.closedTrades = size + trades +"    avg: "+ NumberToStr(stats[METRIC_SIG_UNITS][S_TRADES_AVG_PROFIT]/pUnit, "R+."+ pDigits) +" "+ spUnit;
            break;

         default:
            return(!catch("SS.ClosedTrades(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
      }
   }
}
