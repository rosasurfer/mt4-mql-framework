/**
 * Toggle the displayed profit unit between absolute and percentage values.
 *
 * @return bool - success status
 */
bool ToggleProfitUnit() {
   status.profitInPercent = !status.profitInPercent;
   StoreVolatileStatus();
   SS.All();
   return(true);
}
