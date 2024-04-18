/**
 * ShowStatus: Update the string representaton of the PnL statistics.
 */
void SS.ProfitStats() {
   // not before a position was opened
   if (!open.ticket && !ArrayRange(history, 0)) {
      status.profitStats = "";
   }
   else {
      string sMaxProfit="", sMaxDrawdown="";

      switch (status.activeMetric) {
         case METRIC_NET_MONEY:
            if (ShowProfitInPercent) {
               sMaxProfit   = NumberToStr(MathDiv(stats.maxNetProfit,      instance.startEquity) * 100, "R+.2");
               sMaxDrawdown = NumberToStr(MathDiv(stats.maxNetAbsDrawdown, instance.startEquity) * 100, "R+.2");
            }
            else {
               sMaxProfit   = NumberToStr(stats.maxNetProfit,      "R+.2");
               sMaxDrawdown = NumberToStr(stats.maxNetAbsDrawdown, "R+.2");
            }
            break;
         case METRIC_NET_UNITS:
            sMaxProfit   = NumberToStr(stats.maxNetProfitP     /pUnit, "R+."+ pDigits);
            sMaxDrawdown = NumberToStr(stats.maxNetAbsDrawdownP/pUnit, "R+."+ pDigits);
            break;
         case METRIC_SIG_UNITS:
            sMaxProfit   = NumberToStr(stats.maxSigProfitP     /pUnit, "R+."+ pDigits);
            sMaxDrawdown = NumberToStr(stats.maxSigAbsDrawdownP/pUnit, "R+."+ pDigits);
            break;

         default:
            return(!catch("SS.ProfitStats(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
      }
      status.profitStats = StringConcatenate("(", sMaxDrawdown, "/", sMaxProfit, ")");
   }
}
