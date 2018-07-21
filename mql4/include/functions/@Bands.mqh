/**
 * Update a band's chart legend.
 *
 * @param  string   label          - chart label of the legend object
 * @param  string   name           - the band's name (usually the indicator name)
 * @param  string   status         - additional status info (if any)
 * @param  color    bandsColor     - the band color
 * @param  double   upperValue     - current upper band value
 * @param  double   lowerValue     - current lower band value
 * @param  datetime barOpenTime    - current bar opentime
 */
void @Bands.UpdateLegend(string label, string name, string status, color bandsColor, double upperValue, double lowerValue, datetime barOpenTime) {
   static double   lastUpperValue;
   static double   lastLowerValue;
   static datetime lastBarOpenTime;

   upperValue = NormalizeDouble(upperValue, SubPipDigits);
   lowerValue = NormalizeDouble(lowerValue, SubPipDigits);

   // update if values or bar changed
   if (upperValue!=lastUpperValue || lowerValue!=lastLowerValue || barOpenTime!=lastBarOpenTime) {
      string text = StringConcatenate(name, "    ", NumberToStr(upperValue, SubPipPriceFormat), " / ", NumberToStr(lowerValue, SubPipPriceFormat), "    ", status);
      color  textColor = bandsColor;
      if      (textColor == Yellow) textColor = Orange;
      else if (textColor == Gold  ) textColor = Orange;
      ObjectSetText(label, text, 9, "Arial Fett", textColor);

      int error = GetLastError();
      if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // on open "Properties" dialog or on Object::onDrag()
         return(catch("@Bands.UpdateLegend(1)", error));
   }

   lastUpperValue  = upperValue;
   lastLowerValue  = lowerValue;
   lastBarOpenTime = barOpenTime;
}
