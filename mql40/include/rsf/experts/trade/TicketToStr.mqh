/**
 * Return a string representation of a ticket id. Handles `signed int` and `unsigned int` values,
 * according to the configuration.
 *
 * @param  int ticket - ticket
 *
 * @return string
 */
string TicketToStr(int ticket) {
   string sTicket;

   if (TradeConfig & TRADE_TICKETS_UINT != 0) {
      double dTicket = ticket;
      if (ticket < 0) {
         dTicket += 4294967296.0;      // 2^32
      }
      sTicket = DoubleToStr(dTicket, 0);
   }
   else {
      sTicket = ticket;
   }
   return(sTicket);
}
