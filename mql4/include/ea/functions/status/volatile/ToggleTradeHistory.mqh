/**
 * Toggle the display of closed trades.
 *
 * @param  bool soundOnNoTrades [optional] - whether to play a sound if no closed trades exist (default: yes)
 *
 * @return bool - success status
 */
bool ToggleTradeHistory(bool soundOnNoTrades = true) {
   soundOnNoTrades = soundOnNoTrades!=0;

   // toggle status
   bool show = !status.showTradeHistory;

   if (show) {
      int trades = ShowTradeHistory(true);
      if (!trades) {                                           // Without any closed trades status must be set to 'off'
         show = false;                                         // and existing markers cleared.
         if (soundOnNoTrades) PlaySoundEx("Plonk.wav");
      }
   }
   if (!show) trades = ShowTradeHistory(false);
   if (trades < 0) return(false);

   // store status
   status.showTradeHistory = show;
   StoreVolatileStatus();

   if (__isTesting) WindowRedraw();
   return(!catch("ToggleTradeHistory(1)"));
}
