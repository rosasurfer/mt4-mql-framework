/**
 * Toggle the display of open orders.
 *
 * @param  bool soundOnNoOrders [optional] - whether to play a sound if no open orders exist (default: yes)
 *
 * @return bool - success status
 */
bool ToggleOpenOrders(bool soundOnNoOrders = true) {
   soundOnNoOrders = soundOnNoOrders!=0;

   // toggle status
   bool show = !status.showOpenOrders;

   if (show) {
      int orders = ShowOpenOrders(true);
      if (!orders) {                                           // Without any open orders status must be set to 'off'
         show = false;                                         // and existing markers cleared.
         if (soundOnNoOrders) PlaySoundEx("Plonk.wav");
      }
   }
   if (!show) orders = ShowOpenOrders(false);
   if (orders < 0) return(false);

   // store status
   status.showOpenOrders = show;
   StoreVolatileStatus();

   if (__isTesting) WindowRedraw();
   return(!catch("ToggleOpenOrders(2)"));
}
