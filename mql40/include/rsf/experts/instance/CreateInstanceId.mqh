/**
 * Generate a new instance id. Unique for all instances per symbol (instances on different symbols may have the same id).
 *
 * @return int - instance id in the range of INSTANCE_ID_MIN...INSTANCE_ID_MAX or NULL (0) in case of errors
 *
 *
 * TODO:
 *  - instances on different symbols can have the same id, so the ticket symbol must be checked against, too
 *  - use IsMyOrder() for checking tickets (magicNumber may be dynamic)
 */
int CreateInstanceId() {
   int instanceId, magicNumber;
   MathSrand(GetTickCount() - __ExecutionContext[EC.chartWindow]);

   if (__isTesting) {
      // generate next consecutive id from already recorded metrics
      string nextSymbol = Recorder_GetNextMetricSymbol(); if (nextSymbol == "") return(NULL);
      string sCounter = StrRightFrom(nextSymbol, ".", -1);
      if (!StrIsDigits(sCounter)) return(!catch("CreateInstanceId(1)  "+ instance.name +" illegal value for next symbol \""+ nextSymbol +"\" (doesn't end with 3 digits)", ERR_ILLEGAL_STATE));
      int nextMetricId = MathMax(INSTANCE_ID_MIN, StrToInteger(sCounter));

      if (recorder.mode == NULL) {
         int minInstanceId = MathCeil(nextMetricId + 0.2*(INSTANCE_ID_MAX-nextMetricId));    // nextMetricId + 20% of remaining range (leave 20% of range empty for tests with metrics)
         while (instanceId < minInstanceId || instanceId > INSTANCE_ID_MAX) {                // select random id between <minInstanceId> and ID_MAX
            instanceId = MathRand();
         }
      }
      else {
         instanceId = nextMetricId;                                                          // use next metric id
      }
   }
   else {
      // online: generate a random id
      while (!magicNumber) {
         instanceId = 0;
         while (instanceId < INSTANCE_ID_MIN || instanceId > INSTANCE_ID_MAX) {
            instanceId = MathRand();                                                         // pseudo-random id between ID_MIN and ID_MAX
         }
         magicNumber = CalculateMagicNumber(instanceId); if (!magicNumber) return(NULL);

         // test for uniqueness against open orders
         int openOrders = OrdersTotal();
         for (int i=0; i < openOrders; i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;                          // FALSE: an open order was closed/deleted in another thread
            if (OrderMagicNumber() == magicNumber) {
               magicNumber = NULL;
               break;
            }
         }
         if (!magicNumber) continue;

         // test for uniqueness against closed orders
         int closedOrders = OrdersHistoryTotal();
         for (i=0; i < closedOrders; i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) break;                         // FALSE: the visible history range was modified in another thread
            if (OrderMagicNumber() == magicNumber) {
               magicNumber = NULL;
               break;
            }
         }
      }
   }
   return(instanceId);
}
