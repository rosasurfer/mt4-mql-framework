/**
 * Toggle the display of open orders.
 *
 * @param  bool soundOnNone [optional] - whether to play a sound if no open orders exist (default: yes)
 *
 * @return bool - success status
 */
bool ToggleOpenOrders(bool soundOnNone = true) {
   soundOnNone = soundOnNone!=0;

   // toggle current status
   bool showOrders = !status.showOpenOrders;

   // ON: display open orders
   if (showOrders) {
      string types[] = {"buy", "sell"};
      color clrs[] = {CLR_OPEN_LONG, CLR_OPEN_SHORT};

      if (open.ticket != NULL) {
         double openPrice = ifDouble(status.activeMetric == METRIC_SIG_UNITS, open.priceSig, open.price);
         string label = StringConcatenate("#", open.ticket, " ", types[open.type], " ", NumberToStr(open.lots, ".+"), " at ", NumberToStr(openPrice, PriceFormat));

         if (ObjectFind(label) == -1) if (!ObjectCreate(label, OBJ_ARROW, 0, 0, 0)) return(!catch("ToggleOpenOrders(1)", intOr(GetLastError(), ERR_RUNTIME_ERROR)));
         ObjectSet    (label, OBJPROP_ARROWCODE, SYMBOL_ORDEROPEN);
         ObjectSet    (label, OBJPROP_COLOR,  clrs[open.type]);
         ObjectSet    (label, OBJPROP_TIME1,  open.time);
         ObjectSet    (label, OBJPROP_PRICE1, openPrice);
         ObjectSetText(label, instance.name);
      }
      else {
         showOrders = false;                          // Without open orders status must be reset to have the "off" section
         if (soundOnNone) PlaySoundEx("Plonk.wav");   // remove any existing open order markers.
      }
   }

   // OFF: remove open order markers
   if (!showOrders) {
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

   // store current status
   status.showOpenOrders = showOrders;
   StoreVolatileStatus();

   if (__isTesting) WindowRedraw();
   return(!catch("ToggleOpenOrders(2)"));
}
