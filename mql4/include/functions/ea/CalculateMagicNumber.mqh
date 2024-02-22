/**
 * Calculate a magic order number for the instance.
 *
 * @param  int instanceId - instance id
 *
 * @return int - magic number or NULL in case of errors
 */
int CalculateMagicNumber(int instanceId) {
   if (STRATEGY_ID < 101 || STRATEGY_ID > 1023)                      return(!catch("CalculateMagicNumber(1)  "+ instance.name +" illegal strategy id: "+ STRATEGY_ID, ERR_ILLEGAL_STATE));
   if (instanceId < INSTANCE_ID_MIN || instanceId > INSTANCE_ID_MAX) return(!catch("CalculateMagicNumber(2)  "+ instance.name +" invalid parameter instanceId: "+ instanceId, ERR_INVALID_PARAMETER));

   int strategy = STRATEGY_ID;                  // 101-1023 (10 bit)
   int instance = instanceId;                   // 001-999  (14 bit, used to be 1000-9999)

   return((strategy<<22) + (instance<<8));      // the remaining 8 bit are not used
}
