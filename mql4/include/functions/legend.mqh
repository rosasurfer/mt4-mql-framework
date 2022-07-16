
#define CHARTLEGEND_PREFIX  "rsf.Legend."


/**
 * Create a text label object in the main chart for a program's chart legend.
 *
 * @return string - object name or an empty string in case of errors
 */
string CreateLegend() {
   string name = CHARTLEGEND_PREFIX + __ExecutionContext[EC.pid] +"."+ __ExecutionContext[EC.hChart];

   if (__isChart && !__isSuperContext) {
      if (ObjectFind(name) == -1) {                      // create a new label or reuse an existing one
         if (!ObjectCreateRegister(name, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return("");
         ObjectSetText(name, " ");
      }
      RearrangeLegends();
   }
   return(name);
}


/**
 * Remove a program's chart legend from the main chart.
 *
 * @return bool - success status
 */
bool RemoveLegend() {
   if (__isChart && !__isSuperContext) {
      string name = CHARTLEGEND_PREFIX + __ExecutionContext[EC.pid] +"."+ __ExecutionContext[EC.hChart];
      if (ObjectFind(name) != -1) {
         ObjectDelete(name);
         return(RearrangeLegends());
      }
   }
   return(true);
}


/**
 * Order and rearrange all chart legends. Discards obsolete legends of old or inactive programs.
 *
 * @return bool - success status
 */
bool RearrangeLegends() {
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
   return(!catch("RearrangeLegends(1)"));
}
