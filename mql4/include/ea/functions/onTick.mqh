/**
 * Generic template/example for an EA's onTick() function.
 *
 * @return int - error status
 */
int onTick() {
   if (!instance.status) return(catch("onTick(1)  illegal instance.status: "+ instance.status, ERR_ILLEGAL_STATE));
   double signal[3];

   if (__isChart) {
      if (!HandleCommands()) return(last_error);      // process incoming commands (may switch on/off the instance)
   }

   if (instance.status != STATUS_STOPPED) {
      if (instance.status == STATUS_WAITING) {
         if (IsStartSignal(signal)) {
            StartTrading(signal);
         }
      }
      else if (instance.status == STATUS_TRADING) {
         UpdateStatus();                              // update client-side status

         if (IsStopSignal(signal)) {
            StopTrading(signal);
         }
         else {                                       // update server-side status
            ManageOpenPositions();                    // add/reduce/reverse positions, take (partial) profits
            UpdatePendingOrders();                    // update entry and/or exit limits
         }
      }
      RecordMetrics();
   }
   return(last_error);
}
