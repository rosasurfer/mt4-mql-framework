/**
 * ShowStatus: Update the string representaton of the PnL statistics.
 *
 * @param  bool moneyInPercent [optional] - whether to display moneys in percent of instance start equity (default: no)
 */
void SS.ProfitStats(bool moneyInPercent = false) {
   // not before a position was opened
   if (!open.ticket && !ArrayRange(history, 0)) {
      sProfitStats = "";
   }
   else {
      string sMaxProfit="", sMaxDrawdown="";

      switch (status.activeMetric) {
         case METRIC_TOTAL_NET_MONEY:
            if (moneyInPercent) {
               sMaxProfit   = NumberToStr(MathDiv(instance.maxNetProfit,   instance.startEquity) * 100, "R+.2");
               sMaxDrawdown = NumberToStr(MathDiv(instance.maxNetDrawdown, instance.startEquity) * 100, "R+.2");
            }
            else {
               sMaxProfit   = NumberToStr(instance.maxNetProfit,   "R+.2");
               sMaxDrawdown = NumberToStr(instance.maxNetDrawdown, "R+.2");
            }
            break;
         case METRIC_TOTAL_NET_UNITS:
            sMaxProfit   = NumberToStr(instance.maxNetProfitP   * pMultiplier, "R+."+ pDigits);
            sMaxDrawdown = NumberToStr(instance.maxNetDrawdownP * pMultiplier, "R+."+ pDigits);
            break;
         case METRIC_TOTAL_SYNTH_UNITS:
            sMaxProfit   = NumberToStr(instance.maxSynthProfitP   * pMultiplier, "R+."+ pDigits);
            sMaxDrawdown = NumberToStr(instance.maxSynthDrawdownP * pMultiplier, "R+."+ pDigits);
            break;

         default:
            return(!catch("SS.ProfitStats(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
      }
      sProfitStats = StringConcatenate("(", sMaxDrawdown, "/", sMaxProfit, ")");
   }
}
