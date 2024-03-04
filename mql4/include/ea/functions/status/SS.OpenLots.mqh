/**
 * ShowStatus: Update the string representation of the open position size.
 */
void SS.OpenLots() {
   if      (!open.lots)           status.openLots = "-";
   else if (open.type == OP_LONG) status.openLots = "+"+ NumberToStr(open.lots, ".+") +" lot";
   else                           status.openLots = "-"+ NumberToStr(open.lots, ".+") +" lot";
}
