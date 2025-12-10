/**
 * Resolve the top-distance of the status box to create. The box is placed below all existing chart legends.
 *
 * @return int - offset from top
 */
int ResolveTopDistance() {
   // count existing chart legends
   int objects = ObjectsTotal();
   int labels  = ObjectsTotal(OBJ_LABEL);
   int prefixLength = StringLen(CHARTLEGEND_PREFIX);
   int legends = 0;

   for (int i=objects-1; i >= 0 && labels; i--) {
      string name = ObjectName(i);

      if (ObjectType(name) == OBJ_LABEL) {
         if (StrStartsWith(name, CHARTLEGEND_PREFIX)) {
            string data = StrRight(name, -prefixLength);
            int pid     = StrToInteger(data);
            int hChart  = StrToInteger(StrRightFrom(data, "."));

            if (pid && hChart==__ExecutionContext[EC.chart]) {
               legends++;
            }
         }
         labels--;
      }
   }

   // calculate position of the next line
   int yDist = 20;                              // y-position of the top-most legend
   int lineHeight = 19;                         // line height of legends
   int y = yDist + legends * lineHeight;
   return(y);
}
