/**
 * Toggle the display of closed trades.
 *
 * @param  bool soundOnNone [optional] - whether to play a sound if no closed trades exist (default: yes)
 *
 * @return bool - success status
 */
bool ToggleTradeHistory(bool soundOnNone = true) {
   soundOnNone = soundOnNone!=0;

   // toggle current status
   bool showHistory = !status.showTradeHistory;

   // ON: display closed trades
   if (showHistory) {
      int trades = ShowTradeHistory();
      if (trades == -1) return(false);
      if (!trades) {                                        // Without any closed trades the status must be reset to enable
         showHistory = false;                               // the "off" section to clear existing markers.
         if (soundOnNone) PlaySoundEx("Plonk.wav");
      }
   }

   // OFF: remove all closed trade markers (from this EA or another program)
   if (!showHistory) {
      for (int i=ObjectsTotal()-1; i >= 0; i--) {
         string name = ObjectName(i);

         if (StringGetChar(name, 0) == '#') {
            if (ObjectType(name) == OBJ_ARROW) {
               int arrow = ObjectGet(name, OBJPROP_ARROWCODE);
               color clr = ObjectGet(name, OBJPROP_COLOR);

               if (arrow == SYMBOL_ORDEROPEN) {
                  if (clr!=CLR_CLOSED_LONG && clr!=CLR_CLOSED_SHORT) continue;
               }
               else if (arrow == SYMBOL_ORDERCLOSE) {
                  if (clr!=CLR_CLOSED) continue;
               }
            }
            else if (ObjectType(name) != OBJ_TREND) continue;
            ObjectDelete(name);
         }
      }
   }

   // store current status
   status.showTradeHistory = showHistory;
   StoreVolatileData();

   if (__isTesting) WindowRedraw();
   return(!catch("ToggleTradeHistory(1)"));
}
