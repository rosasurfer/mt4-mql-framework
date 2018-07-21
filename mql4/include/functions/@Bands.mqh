/**
 * Indikator-Styles setzen. Workaround um diverse Terminalbugs (Farb-/Styleänderungen nach Recompilation), die erfordern, daß
 * die Styles normalerweise in init(), nach Recompilation jedoch in start() gesetzt werden müssen, um korrekt angezeigt zu
 * werden.
 */
void @Bands.SetIndicatorStyles(color mainColor, color bandsColor) {
   int drawType = ifInt(mainColor == CLR_NONE, DRAW_NONE, DRAW_LINE);

   SetIndexStyle(Bands.MODE_MA,    drawType,  EMPTY, EMPTY, mainColor);
   SetIndexStyle(Bands.MODE_UPPER, DRAW_LINE, EMPTY, EMPTY, bandsColor);
   SetIndexStyle(Bands.MODE_LOWER, DRAW_LINE, EMPTY, EMPTY, bandsColor);
}


/**
 * Aktualisiert die Legende eines Band-Indikators.
 */
void @Bands.UpdateLegend(string legendLabel, string legendDescription, color bandsColor, double currentUpperValue, double currentLowerValue) {
   static double lastUpperValue;                                        // Value des vorherigen Ticks

   currentUpperValue = NormalizeDouble(currentUpperValue, SubPipDigits);

   if (currentUpperValue != lastUpperValue) {
      ObjectSetText(legendLabel, StringConcatenate(legendDescription, "    ", NumberToStr(currentUpperValue, SubPipPriceFormat), " / ", NumberToStr(NormalizeDouble(currentLowerValue, SubPipDigits), SubPipPriceFormat)), 9, "Arial Fett", bandsColor);
      int error = GetLastError();
      if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
         return(catch("@Bands.UpdateLegend()", error));
   }
   lastUpperValue = currentUpperValue;
}
