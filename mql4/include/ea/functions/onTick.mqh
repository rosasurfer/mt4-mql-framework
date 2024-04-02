/**
 * Generic template/example for the onTick() function.
 *
 * @return int - error status
 */
int onTick() {
   if (!instance.status) return(catch("onTick(1)  illegal instance.status: "+ instance.status, ERR_ILLEGAL_STATE));
   double signal[3];

   if (__isChart) {
      if (!HandleCommands()) return(last_error);      // process incoming commands, may switch on/off the instance
   }

   if (instance.status != STATUS_STOPPED) {
      if (instance.status == STATUS_WAITING) {
         if (IsStartSignal(signal)) {
            StartInstance(signal);
         }
      }
      else if (instance.status == STATUS_TRADING) {
         UpdateStatus();                              // update client-side status

         if (IsStopSignal(signal)) {
            StopInstance(signal);
         }
         else {                                       // update server-side status
            UpdateOpenPositions();                    // add/reduce/reverse position, take (partial) profits
            UpdatePendingOrders();                    // update entry and/or exit limits
         }
      }
      RecordMetrics();
   }
   return(last_error);
}
