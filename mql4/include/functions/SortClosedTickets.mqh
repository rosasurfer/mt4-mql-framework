/**
 * Sort the passed tickets by {CloseTime, OpenTime, Ticket}.
 *
 * @param  _InOut_ int tickets[]
 *
 * @return bool - success status
 */
bool SortClosedTickets(int &tickets[][3]) {
   if (ArrayRange(tickets, 1) != 3) return(!catch("SortClosedTickets(1)  invalid parameter tickets["+ ArrayRange(tickets, 0) +"]["+ ArrayRange(tickets, 1) +"]", ERR_INCOMPATIBLE_ARRAY));

   int rows = ArrayRange(tickets, 0);
   if (rows < 2) return(true);                                       // single row, nothing to do

   // sort all rows by CloseTime
   ArraySort(tickets);

   // sort rows with equal CloseTime by OpenTime
   int closeTime, openTime, ticket, lastCloseTime, sameCloseTimes[][3];
   ArrayResize(sameCloseTimes, 1);

   for (int n, i=0; i < rows; i++) {
      closeTime = tickets[i][0];
      openTime  = tickets[i][1];
      ticket    = tickets[i][2];

      if (closeTime == lastCloseTime) {
         n++;
         ArrayResize(sameCloseTimes, n+1);
      }
      else if (n > 0) {
         // sort rows collected in sameCloseTimes[] by OpenTime
         if (!SortClosedTickets.SameClose(tickets, sameCloseTimes)) return(false);
         ArrayResize(sameCloseTimes, 1);
         n = 0;
      }
      sameCloseTimes[n][0] = openTime;
      sameCloseTimes[n][1] = ticket;
      sameCloseTimes[n][2] = i;                                      // original row position in tickets[]

      lastCloseTime = closeTime;
   }
   if (n > 0) {
      // rows collected in the last loop cycle must be sorted, too
      if (!SortClosedTickets.SameClose(tickets, sameCloseTimes)) return(false);
      n = 0;
   }
   ArrayResize(sameCloseTimes, 0);

   // sort rows with equal CloseTime and equal OpenTime by Ticket
   int lastOpenTime, sameOpenTimes[][2];
   ArrayResize(sameOpenTimes, 1);
   lastCloseTime = 0;

   for (i=0; i < rows; i++) {
      closeTime = tickets[i][0];
      openTime  = tickets[i][1];
      ticket    = tickets[i][2];

      if (closeTime==lastCloseTime && openTime==lastOpenTime) {
         n++;
         ArrayResize(sameOpenTimes, n+1);
      }
      else if (n > 0) {
         // sort rows collected in sameOpenTimes[] by Ticket
         if (!SortClosedTickets.SameOpen(tickets, sameOpenTimes)) return(false);
         ArrayResize(sameOpenTimes, 1);
         n = 0;
      }
      sameOpenTimes[n][0] = ticket;
      sameOpenTimes[n][1] = i;                                       // original row position in tickets[]

      lastCloseTime = closeTime;
      lastOpenTime  = openTime;
   }
   if (n > 0) {
      // rows collected in the last loop cycle must be sorted, too
      if (!SortClosedTickets.SameOpen(tickets, sameOpenTimes)) return(false);
   }
   ArrayResize(sameOpenTimes, 0);

   return(!catch("SortClosedTickets(2)"));
}


/**
 * Should be called from SortClosedTickets() only.
 *
 * Sort the rows of tickets[] specified in rowsToSort[] by {OpenTime, Ticket}.
 *
 * @param  _InOut_ int tickets[]    - tickets to process
 * @param  _In_    int rowsToSort[] - array indexes of the ticket rows to sort
 *
 * @return bool - success status
 */
bool SortClosedTickets.SameClose(int &tickets[][/*{CloseTime, OpenTime, Ticket}*/], int rowsToSort[][/*{OpenTime, Ticket, i}*/]) {
   int rowsCopy[][3]; ArrayResize(rowsCopy, 0);
   ArrayCopy(rowsCopy, rowsToSort);                                  // auf Kopie von rowsToSort[] arbeiten, um das übergebene Array nicht zu modifizieren

   // Zeilen nach OpenTime sortieren
   ArraySort(rowsCopy);

   // Original-Daten mit den sortierten Werten überschreiben
   int openTime, ticket, rows=ArrayRange(rowsToSort, 0);

   for (int i, n=0; n < rows; n++) {                                 // Originaldaten mit den sortierten Werten überschreiben
      i             = rowsToSort[n][2];
      tickets[i][1] = rowsCopy  [n][0];
      tickets[i][2] = rowsCopy  [n][1];
   }
   return(!catch("SortClosedTickets.SameClose(1)"));
}


/**
 * Should be called from SortClosedTickets() only.
 *
 * Sort the rows of tickets[] specified in rowsToSort[] by {Ticket}.
 *
 * @param  _InOut_ int tickets[]    - tickets to process
 * @param  _In_    int rowsToSort[] - array indexes of the ticket rows to sort
 *
 * @return bool - success status
 */
bool SortClosedTickets.SameOpen(int &tickets[][/*{OpenTime, CloseTime, Ticket}*/], int rowsToSort[][/*{Ticket, i}*/]) {
   int rowsCopy[][2]; ArrayResize(rowsCopy, 0);
   ArrayCopy(rowsCopy, rowsToSort);                                  // auf Kopie von rowsToSort[] arbeiten, um das übergebene Array nicht zu modifizieren

   // Zeilen nach Ticket sortieren
   ArraySort(rowsCopy);

   int ticket, rows=ArrayRange(rowsToSort, 0);

   for (int i, n=0; n < rows; n++) {                                 // Originaldaten mit den sortierten Werten überschreiben
      i             = rowsToSort[n][1];
      tickets[i][2] = rowsCopy  [n][0];
   }
   return(!catch("SortClosedTickets.SameOpen(1)"));
}
