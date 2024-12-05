/**
 * Whether the currently selected ticket belongs to the current strategy and/or the current instance.
 *
 * @param  int instanceId - instance to check the ticket against (NULL: check against strategy only)
 *
 * @return bool
 */
bool IsMyOrder(int instanceId) {
   if (OrderSymbol() == Symbol()) {
      int strategy = OrderMagicNumber() >> 22;
      if (strategy == STRATEGY_ID) {
         int instance = OrderMagicNumber() >> 8 & 0x3FFF;   // 14 bit starting at bit 8: instance id
         return(!instanceId || instance==instanceId);
      }
   }
   return(false);
}
