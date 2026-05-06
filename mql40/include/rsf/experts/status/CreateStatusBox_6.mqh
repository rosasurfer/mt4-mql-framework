/**
 * Creates a status display box for 6 lines. Consists of overlapping rectangles made of font "Webdings", character "g".
 * Called from onInit() only.
 *
 * @return string - comment prefix to be used by composition of the status display (adapts to existing chart legends)
 */
string CreateStatusBox() {
   if (!__isChart) return(0);

   int x[] = {2, 66, 136};                                  // x-offset of the rectangles forming the status box
   int sizeofX = ArraySize(x);                              // number of used rectangles
   int legends = CountChartLegends();                       // number of existing chart legends
   int fontSize = 54;                                       // rectangle fontsize
   color bgColor = LemonChiffon;                            // rectangle color

   // comment line tops: 16, 28, 40, 52, 64 ... => x * 12 + 4
   // legend lines bottoms: 36, 55, 74, 93 ...  => x * 19 + 17

   // calculate the bottom offset of existing chart legends
   int legendsBottomOffset = 0;
   if (legends > 0) {
      legendsBottomOffset = legends * chartlegend.lineHeight + (chartlegend.lineHeight-chartlegend.lineDistance);
   }

   // add 1px statusbox distance + 1px statusbox padding (2px)
   int commentsOffset = legendsBottomOffset + 2;
   int firstLine = MathCeil((commentsOffset - 4)/12.0);
   firstLine = Max(firstLine, 2);                           // terminal comments start at offset of line 2
   int statusboxOffset = firstLine * 12 + 4 - 1;            // -1px padding top

   // create status box
   for (int i=0; i < sizeofX; i++) {
      string label = StringConcatenate(WindowExpertName(), ".statusbox.", i+1);
      if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL)) return(0);
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE, x[i]);
      ObjectSet(label, OBJPROP_YDISTANCE, statusboxOffset);
      ObjectSetText(label, "g", fontSize, "Webdings", bgColor);
   }

   // return the resulting comment prefix/spacer
   return(StrRepeat(NL, firstLine-1));
}
