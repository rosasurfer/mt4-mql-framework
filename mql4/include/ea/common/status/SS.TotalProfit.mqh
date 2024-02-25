/**
 * ShowStatus: Update the string representation of the total instance PnL.
 *
 * @param  bool inPercent [optional] - whether to display money amounts in percent of strategy start equity (default: no)
 */
void SS.TotalProfit(bool inPercent = false) {
   // not before a position was opened
   if (!open.ticket && !ArrayRange(history, 0)) {
      sTotalProfit = "-";
   }
   else {
      switch (status.activeMetric) {
         case METRIC_TOTAL_NET_MONEY:
            if (inPercent) sTotalProfit = NumberToStr(MathDiv(instance.totalNetProfit, instance.startEquity) * 100, "R+.2") +"%";
            else           sTotalProfit = NumberToStr(instance.totalNetProfit, "R+.2") +" "+ AccountCurrency();
            break;
         case METRIC_TOTAL_NET_UNITS:
            sTotalProfit = NumberToStr(instance.totalNetProfitP * pMultiplier, "R+."+ pDigits) +" "+ pUnit;
            break;
         case METRIC_TOTAL_SYNTH_UNITS:
            sTotalProfit = NumberToStr(instance.totalSynthProfitP * pMultiplier, "R+."+ pDigits) +" "+ pUnit;
            break;

         default:
            return(!catch("SS.TotalProfit(1)  "+ instance.name +" illegal value of status.activeMetric: "+ status.activeMetric, ERR_ILLEGAL_STATE));
      }
   }
}
