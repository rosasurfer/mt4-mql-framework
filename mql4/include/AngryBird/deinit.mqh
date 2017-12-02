
/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   int uninitReason = UninitializeReason();

   // clean-up created chart objects
   if (uninitReason!=UR_PARAMETERS && uninitReason!=UR_CHARTCHANGE) {
      if (!IsTesting())
         DeleteRegisteredObjects(NULL);
   }

   // store runtime status
   if (uninitReason==UR_RECOMPILE || uninitReason==UR_CHARTCLOSE || uninitReason==UR_CLOSE) {
      if (!IsTesting())
         StoreRuntimeStatus();
   }
   return(last_error);
}
