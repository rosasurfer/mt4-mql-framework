/**
 * Display open orders.
 *
 * @param  bool show - display status:
 *                      TRUE  - show orders
 *                      FALSE - hide displayed orders
 *
 * @return int - number of displayed orders or EMPTY (-1) in case of errors
 */
int ShowOpenOrders(bool show) {
   show = show!=0;
   int orders = 0;

   if (show) {
      string types[] = {"buy", "sell"};
      color clrs[] = {CLR_OPEN_LONG, CLR_OPEN_SHORT};

      if (open.ticket != NULL) {
         double openPrice = ifDouble(status.activeMetric == METRIC_SIG_UNITS, open.priceSig, open.price);
         string label = StringConcatenate("#", open.ticket, " ", types[open.type], " ", NumberToStr(open.lots, ".+"), " at ", NumberToStr(openPrice, PriceFormat));

         if (ObjectFind(label) == -1) ObjectCreate(label, OBJ_ARROW, 0, 0, 0);
         ObjectSet    (label, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet    (label, OBJPROP_COLOR,  clrs[open.type]);
         ObjectSet    (label, OBJPROP_TIME1,  open.time);
         ObjectSet    (label, OBJPROP_PRICE1, openPrice);
         ObjectSetText(label, instance.name);
         orders++;
      }
   }
   else {
      for (int i=ObjectsTotal()-1; i >= 0; i--) {
         label = ObjectName(i);

         if (StringGetChar(label, 0) == '#') {
            if (ObjectType(label) == OBJ_ARROW) {
               int arrow = ObjectGet(label, OBJPROP_ARROWCODE);
               color clr = ObjectGet(label, OBJPROP_COLOR);

               if (arrow == SYMBOL_ORDEROPEN) {
                  if (clr!=CLR_OPEN_LONG && clr!=CLR_OPEN_SHORT) continue;
               }
               else if (arrow == SYMBOL_ORDERCLOSE) {
                  if (clr!=CLR_OPEN_TAKEPROFIT && clr!=CLR_OPEN_STOPLOSS) continue;
               }
               ObjectDelete(label);
            }
         }
      }
   }

   if (!catch("ShowOpenOrders(1)"))
      return(orders);
   return(EMPTY);
}
