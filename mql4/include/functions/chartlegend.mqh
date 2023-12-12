
#define CHARTLEGEND_PREFIX  "rsf.Legend."


/**
 * Create a text label object in the main chart for an indicator's chart legend.
 *
 * @return string - object name or an empty string in case of errors
 */
string CreateChartLegend() {
   string name = CHARTLEGEND_PREFIX + __ExecutionContext[EC.pid] +"."+ __ExecutionContext[EC.hChart];

   if (__isChart && !__isSuperContext) {
      if (ObjectFind(name) == -1) {                      // create a new label or reuse an existing one
         if (!ObjectCreateRegister(name, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return("");
         ObjectSetText(name, " ");
      }
      RearrangeChartLegends();
   }
   return(name);

   // suppress compiler warnings
   UpdateBandLegend(NULL, NULL, NULL, NULL, NULL, NULL);
   UpdateTrendLegend(NULL, NULL, NULL, NULL, NULL, NULL, NULL);
}


/**
 * Remove an indicator's chart legend from the chart.
 *
 * @return bool - success status
 */
bool RemoveChartLegend() {
   if (__isChart && !__isSuperContext) {
      string name = CHARTLEGEND_PREFIX + __ExecutionContext[EC.pid] +"."+ __ExecutionContext[EC.hChart];
      if (ObjectFind(name) != -1) {
         ObjectDelete(name);
         return(RearrangeChartLegends());
      }
   }
   return(true);
}


/**
 * Order and rearrange all chart legends. Discards obsolete legends of removed indicators.
 *
 * @return bool - success status
 */
bool RearrangeChartLegends() {
   if (!__isChart || __isSuperContext) return(true);

   // collect the pids of existing legends
   int objects = ObjectsTotal();
   int labels  = ObjectsTotal(OBJ_LABEL);
   int prefixLength = StringLen(CHARTLEGEND_PREFIX);
   int pids[]; ArrayResize(pids, 0);

   for (int i=objects-1; i >= 0 && labels; i--) {
      string name = ObjectName(i);

      if (ObjectType(name) == OBJ_LABEL) {
         if (StrStartsWith(name, CHARTLEGEND_PREFIX)) {
            string data = StrRight(name, -prefixLength);
            int pid     = StrToInteger(data);
            int hChart  = StrToInteger(StrRightFrom(data, "."));

            if (pid && hChart==__ExecutionContext[EC.hChart]) {
               ArrayPushInt(pids, pid);
            }
            else {
               ObjectDelete(name);
            }
         }
         labels--;
      }
   }

   // order and re-position labels by pid
   int xDist      =  5;                               // x-position
   int yDist      = 20;                               // y-position of the top-most legend
   int lineHeight = 19;                               // line height of each legend

   int size = ArraySize(pids);
   if (size > 0) {
      ArraySort(pids);
      for (i=0; i < size; i++) {
         name = CHARTLEGEND_PREFIX + pids[i] +"."+ __ExecutionContext[EC.hChart];
         ObjectSet(name, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet(name, OBJPROP_XDISTANCE, xDist);
         ObjectSet(name, OBJPROP_YDISTANCE, yDist + i*lineHeight);
      }
   }
   return(!catch("RearrangeChartLegends(1)"));
}


/**
 * Update the chart legend of a band indicator.
 *
 * @param  string legendName    - the legend's chart object name
 * @param  string indicatorName - displayed indicator name
 * @param  string status        - additional status info (if any)
 * @param  color  bandsColor    - the band color
 * @param  double upperValue    - current upper band value
 * @param  double lowerValue    - current lower band value
 */
void UpdateBandLegend(string legendName, string indicatorName, string status, color bandsColor, double upperValue, double lowerValue) {
   string sUpperValue = NumberToStr(upperValue, PriceFormat);
   string sLowerValue = NumberToStr(lowerValue, PriceFormat);

   string text = StringConcatenate(indicatorName, "   ", sLowerValue, " / ", sUpperValue, "   ", status);
   color  textColor = bandsColor;
   if      (textColor == Aqua        ) textColor = DeepSkyBlue;
   else if (textColor == Gold        ) textColor = Orange;
   else if (textColor == LightSkyBlue) textColor = C'94,174,255';
   else if (textColor == Lime        ) textColor = LimeGreen;
   else if (textColor == Yellow      ) textColor = Orange;
   ObjectSetText(legendName, text, 9, "Arial Fett", textColor);

   int error = GetLastError();                                    // on ObjectDrag or opened "Properties" dialog
   if (error && error!=ERR_OBJECT_DOES_NOT_EXIST) catch("UpdateBandLegend(1)", error);
}


/**
 * Update the chart legend of a trend indicator.
 *
 * @param  string   legendName     - the legend's chart object name
 * @param  string   indicatorName  - displayed indicator name
 * @param  string   status         - additional status info (if any)
 * @param  color    uptrendColor   - the uptrend color
 * @param  color    downtrendColor - the downtrend color
 * @param  double   value          - indicator value to display
 * @param  double   dTrend         - trend direction of the value to display (type double allows passing of non-normalized values)
 */
void UpdateTrendLegend(string legendName, string indicatorName, string status, color uptrendColor, color downtrendColor, double value, double dTrend) {
   static string lastName = "";
   static double lastValue;
   static int    lastTrend;
   string sValue="", sTrend="", sOnTrendChange="";

   int trend = MathRound(dTrend);

   // update if name, value or trend changed
   if (indicatorName!=lastName || value!=lastValue || trend!=lastTrend) {
      sValue = NumberToStr(value, PriceFormat);

      if (trend  != 0)  sTrend = StringConcatenate("  (", trend, ")");
      if (status != "") status = StringConcatenate("  ", status);

      if (uptrendColor != downtrendColor) {
         if      (trend ==  1) sOnTrendChange = "  turns up";           // intra-bar trend change
         else if (trend == -1) sOnTrendChange = "  turns down";         // ...
      }

      string text = StringConcatenate(indicatorName, "   ", sValue, sTrend, sOnTrendChange, status);
      color  textColor = ifInt(trend > 0, uptrendColor, downtrendColor);
      if      (textColor == Aqua        ) textColor = DeepSkyBlue;
      else if (textColor == Gold        ) textColor = Orange;
      else if (textColor == LightSkyBlue) textColor = C'94,174,255';
      else if (textColor == Lime        ) textColor = LimeGreen;
      else if (textColor == Yellow      ) textColor = Orange;

      ObjectSetText(legendName, text, 9, "Arial Fett", textColor);

      int error = GetLastError();                                       // on ObjectDrag or opened "Properties" dialog
      if (error && error!=ERR_OBJECT_DOES_NOT_EXIST) catch("UpdateTrendLegend(1)", error);
   }

   lastName  = indicatorName;
   lastValue = value;
   lastTrend = trend;
}
