/**
 * ShowStatus: Update the string summary of the closed trades.
 */
void SS.ClosedTrades() {
   int size = ArrayRange(history, 0);
   if (!size) {
      sClosedTrades = "-";
   }
   else {
      CalculateStats();

      switch (status.activeMetric) {
         case METRIC_NET_MONEY:
            sClosedTrades = size +" trades    avg: "+ NumberToStr(stats[METRIC_NET_MONEY][S_TRADES_AVG_PROFIT], "R+.2") +" "+ AccountCurrency();
            break;
         case METRIC_NET_UNITS:
            sClosedTrades = size +" trades    avg: "+ NumberToStr(stats[METRIC_NET_UNITS][S_TRADES_AVG_PROFIT] * pMultiplier, "R+."+ pDigits) +" "+ pUnit;
            break;
         case METRIC_SIG_UNITS:
            sClosedTrades = size +" trades    avg: "+ NumberToStr(stats[METRIC_SIG_UNITS][S_TRADES_AVG_PROFIT] * pMultiplier, "R+."+ pDigits) +" "+ pUnit;
            break;

         default:
            return(!catch("SS.ClosedTrades(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
      }
   }
}
