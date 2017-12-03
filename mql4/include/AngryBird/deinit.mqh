
/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   int uninitReason = UninitializeReason();

   // clean-up created chart objects
   if (uninitReason!=UR_CHARTCHANGE && uninitReason!=UR_PARAMETERS) {
      if (!IsTesting()) DeleteRegisteredObjects(NULL);
   }

   // store runtime status
   if (uninitReason==UR_CLOSE || uninitReason==UR_CHARTCLOSE || uninitReason==UR_RECOMPILE) {
      if (!IsTesting()) StoreRuntimeStatus();
   }
   return(last_error);
}
