/**
 *
 */
#property library

#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];
#include <core/library.mqh>
#include <stdfunctions.mqh>
#include <functions/JoinInts.mqh>
#include <functions/JoinDoubles.mqh>
#include <functions/JoinDoublesEx.mqh>
#include <functions/JoinStrings.mqh>
#include <rsfLibs.mqh>


/**
 * Custom handler called in tester from core/library::init() to reset global variables before the next test.
 */
void onLibraryInit() {
}


/**
 * Konvertiert ein Array mit Ordertickets in einen lesbaren String, der zusätzlich die Lotsize des jeweiligen Tickets enthält.
 *
 * @param  int    tickets[] - für Tickets ungültige Werte werden entsprechend dargestellt
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string TicketsToStr.Lots(int tickets[], string separator=", ") {
   if (ArrayDimension(tickets) != 1)
      return(_EMPTY_STR(catch("TicketsToStr.Lots(1)  illegal dimensions of parameter tickets: "+ ArrayDimension(tickets), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(tickets);
   if (!size)
      return("{}");

   if (separator == "0")      // (string) NULL
      separator = ", ";

   string result="", sValue="";

   OrderPush("TicketsToStr.Lots(2)");

   for (int i=0; i < size; i++) {
      if (tickets[i] > 0) {
         if (OrderSelect(tickets[i], SELECT_BY_TICKET)) {
            if      (IsLongOrderType(OrderType()))  sValue = StringConcatenate("#", tickets[i], ":+", NumberToStr(OrderLots(), ".1+"));
            else if (IsShortOrderType(OrderType())) sValue = StringConcatenate("#", tickets[i], ":-", NumberToStr(OrderLots(), ".1+"));
            else                                    sValue = StringConcatenate("#", tickets[i], ":none");
         }
         else                                       sValue = StringConcatenate("(unknown ticket #", tickets[i], ")");
      }
      else if (!tickets[i]) sValue = "(NULL)";
      else                  sValue = StringConcatenate("(invalid ticket #", tickets[i], ")");

      result = StringConcatenate(result, separator, sValue);
   }

   OrderPop("TicketsToStr.Lots(3)");

   return(StringConcatenate("{", StrSubstr(result, StringLen(separator)), "}"));
}


/**
 * Konvertiert ein Array mit Ordertickets in einen lesbaren String, der zusätzlich die Lotsize und das Symbol des jeweiligen Tickets enthält.
 *
 * @param  int    tickets[] - für Tickets ungültige Werte werden entsprechend dargestellt
 * @param  string separator - Separator (default: NULL = ", ")
 *
 * @return string - resultierender String oder Leerstring, falls ein Fehler auftrat
 */
string TicketsToStr.LotsSymbols(int tickets[], string separator=", ") {
   if (ArrayDimension(tickets) != 1)
      return(_EMPTY_STR(catch("TicketsToStr.LotsSymbols(1)  illegal dimensions of parameter tickets: "+ ArrayDimension(tickets), ERR_INCOMPATIBLE_ARRAYS)));

   int size = ArraySize(tickets);
   if (!size)
      return("{}");

   if (separator == "0")      // (string) NULL
      separator = ", ";

   string result="", sValue="";

   OrderPush("TicketsToStr.LotsSymbols(2)");

   for (int i=0; i < size; i++) {
      if (tickets[i] > 0) {
         if (OrderSelect(tickets[i], SELECT_BY_TICKET)) {
            if      (IsLongOrderType(OrderType()))  sValue = StringConcatenate("#", tickets[i], ":+", NumberToStr(OrderLots(), ".1+"), OrderSymbol());
            else if (IsShortOrderType(OrderType())) sValue = StringConcatenate("#", tickets[i], ":-", NumberToStr(OrderLots(), ".1+"), OrderSymbol());
            else                                    sValue = StringConcatenate("#", tickets[i], ":none");
         }
         else                                       sValue = StringConcatenate("(unknown ticket #", tickets[i], ")");
      }
      else if (!tickets[i]) sValue = "(NULL)";
      else                  sValue = StringConcatenate("(invalid ticket #", tickets[i], ")");

      result = StringConcatenate(result, separator, sValue);
   }

   OrderPop("TicketsToStr.LotsSymbols(3)");

   return(StringConcatenate("{", StrSubstr(result, StringLen(separator)), "}"));
}


/**
 * Ermittelt die Gesamtposition der Tickets eines Arrays und gibt sie als einen lesbaren String zurück.
 *
 * @param  int tickets[]
 *
 * @return string - String mit Gesamtposition oder Leerstring, falls ein Fehler auftrat
 */
string TicketsToStr.Position(int tickets[]) {
   if (ArrayDimension(tickets) != 1)
      return(_EMPTY_STR(catch("TicketsToStr.Position(1)  illegal dimensions of parameter tickets: "+ ArrayDimension(tickets), ERR_INCOMPATIBLE_ARRAYS)));

   int ticketsSize = ArraySize(tickets);
   if (!ticketsSize)
      return("(empty)");

   double long, short, total, hedged;

   OrderPush("TicketsToStr.Position(2)");

   for (int i=0; i < ticketsSize; i++) {
      if (tickets[i] > 0) {
         if (OrderSelect(tickets[i], SELECT_BY_TICKET)) {
            if (IsLongOrderType(OrderType())) long  += OrderLots();
            else                              short += OrderLots();
         }
         else GetLastError();
      }
   }

   OrderPop("TicketsToStr.Position(3)");

   long   = NormalizeDouble(long,  2);
   short  = NormalizeDouble(short, 2);
   total  = NormalizeDouble(long - short, 2);
   hedged = MathMin(long, short);
   bool isPosition = long || short;

   string result = "";
   if (!isPosition) result = "(none)";
   else if (!total) result = "±"+ NumberToStr(long,  ".+")                                                          +" lots (hedged)";
   else             result =      NumberToStr(total, ".+") + ifString(!hedged, "", " ±"+ NumberToStr(hedged, ".+")) +" lots";

   return(result);
}


/**
 * Sortiert die übergebenen Ticketdaten nach {OpenTime, Ticket}.
 *
 * @param  int tickets[] - Array mit Ticketdaten
 *
 * @return bool - Erfolgsstatus
 */
bool SortOpenTickets(int tickets[][/*{OpenTime, Ticket}*/]) {
   if (ArrayRange(tickets, 1) != 2) return(!catch("SortOpenTickets(1)  invalid parameter tickets["+ ArrayRange(tickets, 0) +"]["+ ArrayRange(tickets, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   int rows = ArrayRange(tickets, 0);
   if (rows < 2)
      return(true);                                                  // weniger als 2 Zeilen

   // Zeilen nach OpenTime sortieren
   ArraySort(tickets);

   // Zeilen mit gleicher OpenTime zusätzlich nach Ticket sortieren
   int openTime, lastOpenTime, ticket, sameOpenTimes[][2];
   ArrayResize(sameOpenTimes, 1);

   for (int i=0, n; i < rows; i++) {
      openTime = tickets[i][0];
      ticket   = tickets[i][1];

      if (openTime == lastOpenTime) {
         n++;
         ArrayResize(sameOpenTimes, n+1);
      }
      else if (n > 0) {
         // in sameOpenTimes[] angesammelte Zeilen von keys[] nach Ticket sortieren
         if (!__SOT.SameOpenTimes(tickets, sameOpenTimes))
            return(false);
         ArrayResize(sameOpenTimes, 1);
         n = 0;
      }
      sameOpenTimes[n][0] = ticket;
      sameOpenTimes[n][1] = i;                                       // Originalposition der Zeile in keys[]

      lastOpenTime = openTime;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameOpenTimes[] angesammelte Zeilen müssen auch sortiert werden
      if (!__SOT.SameOpenTimes(tickets, sameOpenTimes))
         return(false);
      n = 0;
   }
   ArrayResize(sameOpenTimes, 0);

   return(!catch("SortOpenTickets(2)"));
}


/**
 * Sortiert die in rowsToSort[] angegebenen Zeilen des Datenarrays ticketData[] nach Ticket. Die OpenTime-Felder dieser Zeilen sind gleich
 * und müssen nicht umsortiert werden.
 *
 * @param  _InOut_ int ticketData[] - zu sortierendes Datenarray
 * @param  _In_    int rowsToSort[] - Array mit aufsteigenden Indizes der umzusortierenden Zeilen des Datenarrays
 *
 * @return bool - Erfolgsstatus
 *
 * @access private
 */
bool __SOT.SameOpenTimes(int &ticketData[][/*{OpenTime, Ticket}*/], int rowsToSort[][/*{Ticket, i}*/]) {
   int rows.copy[][2]; ArrayResize(rows.copy, 0);
   ArrayCopy(rows.copy, rowsToSort);                                 // auf Kopie von rowsToSort[] arbeiten, um das übergebene Array nicht zu modifizieren

   // Zeilen nach Ticket sortieren
   ArraySort(rows.copy);

   int ticket, rows=ArrayRange(rowsToSort, 0);

   // Originaldaten mit den sortierten Werten überschreiben
   for (int i, n=0; n < rows; n++) {
      i                = rowsToSort[n][1];
      ticketData[i][1] = rows.copy [n][0];
   }

   ArrayResize(rows.copy, 0);
   return(!catch("__SOT.SameOpenTimes(1)"));
}


/**
 * Sortiert die übergebenen Ticketdaten nach {CloseTime, OpenTime, Ticket}.
 *
 * @param  int tickets[] - Array mit Ticketdaten
 *
 * @return bool - Erfolgsstatus
 */
bool SortClosedTickets(int tickets[][/*{CloseTime, OpenTime, Ticket}*/]) {
   if (ArrayRange(tickets, 1) != 3) return(!catch("SortClosedTickets(1)  invalid parameter tickets["+ ArrayRange(tickets, 0) +"]["+ ArrayRange(tickets, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   int rows = ArrayRange(tickets, 0);
   if (rows < 2)
      return(true);                                                  // single row, nothing to do


   // (1) alle Zeilen nach CloseTime sortieren
   ArraySort(tickets);


   // (2) Zeilen mit gleicher CloseTime zusätzlich nach OpenTime sortieren
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
         // in sameCloseTimes[] angesammelte Zeilen von tickets[] nach OpenTime sortieren
         __SCT.SameCloseTimes(tickets, sameCloseTimes);
         ArrayResize(sameCloseTimes, 1);
         n = 0;
      }
      sameCloseTimes[n][0] = openTime;
      sameCloseTimes[n][1] = ticket;
      sameCloseTimes[n][2] = i;                                      // Originalposition der Zeile in keys[]

      lastCloseTime = closeTime;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameCloseTimes[] angesammelte Zeilen müssen auch sortiert werden
      __SCT.SameCloseTimes(tickets, sameCloseTimes);
      n = 0;
   }
   ArrayResize(sameCloseTimes, 0);


   // (3) Zeilen mit gleicher Close- und OpenTime zusätzlich nach Ticket sortieren
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
         // in sameOpenTimes[] angesammelte Zeilen von tickets[] nach Ticket sortieren
         __SCT.SameOpenTimes(tickets, sameOpenTimes);
         ArrayResize(sameOpenTimes, 1);
         n = 0;
      }
      sameOpenTimes[n][0] = ticket;
      sameOpenTimes[n][1] = i;                                       // Originalposition der Zeile in tickets[]

      lastCloseTime = closeTime;
      lastOpenTime  = openTime;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameOpenTimes[] angesammelte Zeilen müssen auch sortiert werden
      __SCT.SameOpenTimes(tickets, sameOpenTimes);
   }
   ArrayResize(sameOpenTimes, 0);

   return(!catch("SortClosedTickets(2)"));
}


/**
 * Sortiert die in rowsToSort[] angegebenen Zeilen des Datenarrays ticketData[] nach {OpenTime, Ticket}. Die CloseTime-Felder dieser Zeilen
 * sind gleich und müssen nicht umsortiert werden.
 *
 * @param  _InOut_ int ticketData[] - zu sortierendes Datenarray
 * @param  _In_    int rowsToSort[] - Array mit aufsteigenden Indizes der umzusortierenden Zeilen des Datenarrays
 *
 * @return bool - Erfolgsstatus
 *
 * @access private - Aufruf nur aus SortClosedTickets()
 */
bool __SCT.SameCloseTimes(int &ticketData[][/*{CloseTime, OpenTime, Ticket}*/], int rowsToSort[][/*{OpenTime, Ticket, i}*/]) {
   int rows.copy[][3]; ArrayResize(rows.copy, 0);
   ArrayCopy(rows.copy, rowsToSort);                                 // auf Kopie von rowsToSort[] arbeiten, um das übergebene Array nicht zu modifizieren

   // Zeilen nach OpenTime sortieren
   ArraySort(rows.copy);

   // Original-Daten mit den sortierten Werten überschreiben
   int openTime, ticket, rows=ArrayRange(rowsToSort, 0);

   for (int i, n=0; n < rows; n++) {                                 // Originaldaten mit den sortierten Werten überschreiben
      i                = rowsToSort[n][2];
      ticketData[i][1] = rows.copy [n][0];
      ticketData[i][2] = rows.copy [n][1];
   }

   ArrayResize(rows.copy, 0);
   return(!catch("__SCT.SameCloseTimes(1)"));
}


/**
 * Sortiert die in rowsToSort[] angegebene Zeilen des Datenarrays ticketData[] nach {Ticket}. Die Open- und CloseTime-Felder dieser Zeilen
 * sind gleich und müssen nicht umsortiert werden.
 *
 * @param  _InOut_ int ticketData[] - zu sortierendes Datenarray
 * @param  _In_    int rowsToSort[] - Array mit aufsteigenden Indizes der umzusortierenden Zeilen des Datenarrays
 *
 * @return bool - Erfolgsstatus
 *
 * @access private - Aufruf nur aus SortClosedTickets()
 */
bool __SCT.SameOpenTimes(int &ticketData[][/*{OpenTime, CloseTime, Ticket}*/], int rowsToSort[][/*{Ticket, i}*/]) {
   int rows.copy[][2]; ArrayResize(rows.copy, 0);
   ArrayCopy(rows.copy, rowsToSort);                                 // auf Kopie von rowsToSort[] arbeiten, um das übergebene Array nicht zu modifizieren

   // Zeilen nach Ticket sortieren
   ArraySort(rows.copy);

   int ticket, rows=ArrayRange(rowsToSort, 0);

   for (int i, n=0; n < rows; n++) {                                 // Originaldaten mit den sortierten Werten überschreiben
      i                = rowsToSort[n][1];
      ticketData[i][2] = rows.copy [n][0];
   }

   ArrayResize(rows.copy, 0);
   return(!catch("__SCT.SameOpenTimes(1)"));
}
