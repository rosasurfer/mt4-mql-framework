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
      int metric = status.activeMetric;

      switch (metric) {
         case METRIC_NET_MONEY:
            if (ShowProfitInPercent) {
               sMaxProfit   = NumberToStr(MathDiv(stats[metric][S_MAX_PROFIT      ], instance.startEquity) * 100, "R+.2");
               sMaxDrawdown = NumberToStr(MathDiv(stats[metric][S_MAX_ABS_DRAWDOWN], instance.startEquity) * 100, "R+.2");
            }
            else {
               sMaxProfit   = NumberToStr(stats[metric][S_MAX_PROFIT      ], "R+.2");
               sMaxDrawdown = NumberToStr(stats[metric][S_MAX_ABS_DRAWDOWN], "R+.2");
            }
            break;

         case METRIC_NET_UNITS:
         case METRIC_SIG_UNITS:
            sMaxProfit   = NumberToStr(stats[metric][S_MAX_PROFIT      ]/pUnit, "R+."+ pDigits);
            sMaxDrawdown = NumberToStr(stats[metric][S_MAX_ABS_DRAWDOWN]/pUnit, "R+."+ pDigits);
            break;

         default:
            return(!catch("SS.ProfitStats(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
      }
      status.profitStats = StringConcatenate("(", sMaxDrawdown, "/", sMaxProfit, ")");
   }
}
