/**
 * Creates a status display box for 6 lines. Consists of overlapping rectangles made of font "Webdings", character "g".
 * Called from onInit() only.
 *
 * @return int - y-offset of the created status box, or NULL in case of errors. Check `last_error` to distinguish between
 *               an error and offset 0 (zero). Used by ShowStatus() to calculate display margins.
 */
int CreateStatusBox() {
   if (!__isChart) return(0);

   int x[] = {2, 66, 136};                   // x-offset of the rectangles forming the status box
   int sizeofX = ArraySize(x);               // number of rectangles
   int y = GetChartLegendsHeight();          // minimum y-offset of the status box to create
   int fontSize = 54;                        // rectangle fontsize
   color bgColor = LemonChiffon;             // rectangle color

   for (int i=0; i < sizeofX; i++) {
      string label = StringConcatenate(WindowExpertName(), ".statusbox.", (i+1));
      if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_LABEL)) return(0);
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(label, OBJPROP_XDISTANCE, x[i]);
      ObjectSet(label, OBJPROP_YDISTANCE, y);
      ObjectSetText(label, "g", fontSize, "Webdings", bgColor);
   }
   return(y);
}
