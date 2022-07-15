/**
 * Create a new object in the main chart for a program's legend. An existing object is reused.
 *
 * @return string - object name or an empty string in case of errors
 */
string CreateLegend() {
   // TODO: detect and remove legends from old/inactive programs

   string prefix="rsf.Legend.", newName=prefix + __ExecutionContext[EC.pid];
   if (!__isChart || __isSuperContext) return(newName);

   // look-up the pids of existing legends
   int objects=ObjectsTotal(), labels=ObjectsTotal(OBJ_LABEL);
   int pids[]; ArrayResize(pids, 0);

   for (int i=0; i < objects && labels; i++) {
      string name = ObjectName(i);
      if (ObjectType(name) == OBJ_LABEL) {
         if (StrStartsWith(name, prefix)) {
            ArrayPushInt(pids, StrToInteger(StrRight(name, -StringLen(prefix))));
         }
         labels--;
      }
   }

   // create a new label or reuse an existing one
   if (ObjectFind(newName) == -1) {
      if (!ObjectCreateRegister(newName, OBJ_LABEL, 0, 0, 0, 0, 0, 0, 0)) return("");
      ObjectSetText(newName, " ");
      ArrayPushInt(pids, __ExecutionContext[EC.pid]);
   }

   // order and re-position all labels by pid
   int size = ArraySize(pids);
   ArraySort(pids);

   int xDist      =  5;                               // x-position
   int yDist      = 20;                               // y-position of the top-most legend
   int lineHeight = 19;                               // line height of each legend

   for (i=0; i < size; i++) {
      name = prefix + pids[i];
      ObjectSet(name, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(name, OBJPROP_XDISTANCE, xDist);
      ObjectSet(name, OBJPROP_YDISTANCE, yDist + i*lineHeight);
   }

   if (!catch("CreateLegend(1)"))
      return(newName);
   return("");

   // dummy call
   RepositionLegend();
}


/**
 * Positioniert die Legende neu (wird nach Entfernen eines Legendenlabels aufgerufen).
 *
 * @return int - error status
 */
int RepositionLegend() {
   if (__isSuperContext) return(true);

   int objects=ObjectsTotal(), labels=ObjectsTotal(OBJ_LABEL);

   string sLabels[];   ArrayResize(sLabels, 0);    // Namen der gefundenen Label
   int    yDists[][2]; ArrayResize(yDists,  0);    // Y-Distance und sLabels[]-Index, um Label nach Position sortieren zu können

   for (int i=0, n; i < objects && labels; i++) {
      string objName = ObjectName(i);
      if (ObjectType(objName) == OBJ_LABEL) {
         if (StrStartsWith(objName, "rsf.Legend.")) {
            ArrayResize(sLabels, n+1);
            ArrayResize(yDists,  n+1);
            sLabels[n]    = objName;
            yDists [n][0] = ObjectGet(objName, OBJPROP_YDISTANCE);
            yDists [n][1] = n;
            n++;
         }
         labels--;
      }
   }

   if (n > 0) {
      ArraySort(yDists);
      for (i=0; i < n; i++) {
         ObjectSet(sLabels[yDists[i][1]], OBJPROP_YDISTANCE, 20 + i*19);
      }
   }
   return(catch("RepositionLegend(1)"));

   // dummy call
   CreateLegend();
}
