/**
 * Generic template for the onTick() function. Adjust it to your needs.
 *
 * @return int - error status
 */
int onTick() {
   if (!instance.status) return(catch("onTick(1)  illegal instance.status: "+ instance.status, ERR_ILLEGAL_STATE));

   if (__isChart) HandleCommands();                   // process incoming commands, may switch on/off the instance

   if (instance.status != STATUS_STOPPED) {
      if (instance.status == STATUS_WAITING) {
         if (IsStopSignal()) {
            StopInstance();                           // due to a time/price condition
         }
         else if (IsEntrySignal()) {
            OpenPendingOrders();
            OpenPosition();
         }
      }
      else if (instance.status == STATUS_TRADING) {
         UpdateStatus();                              // update order status

         if (IsStopSignal()) {
            StopInstance();                           // due to any stop condition
         }
         else {
            UpdateOpenPosition();                     // add/reduce/reverse position, take (partial) profits
            UpdatePendingOrders();                    // update entry and/or exit limits
         }
      }
      RecordMetrics();
   }
   return(catch("onTick(2)"));
}
