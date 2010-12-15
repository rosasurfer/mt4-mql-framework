/**
 * UpdateAccountHistory.mq4
 *
 * Synchronisiert die Datenbank mit der aktuellen Accounthistory.
 */
#include <stdlib.mqh>
#include <win32api.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   // (1) verfügbare Historydaten einlesen
   int orders = OrdersHistoryTotal();

   int      tickets        []; ArrayResize(tickets,         orders);    // Hilfsvariablen
   int      types          []; ArrayResize(types,           orders);
   double   sizes          []; ArrayResize(sizes,           orders);
   string   symbols        []; ArrayResize(symbols,         orders);
   datetime openTimes      []; ArrayResize(openTimes,       orders);
   datetime closeTimes     []; ArrayResize(closeTimes,      orders);
   double   openPrices     []; ArrayResize(openPrices,      orders);
   double   closePrices    []; ArrayResize(closePrices,     orders);
   double   stopLosses     []; ArrayResize(stopLosses,      orders);
   double   takeProfits    []; ArrayResize(takeProfits,     orders);
   datetime expirationTimes[]; ArrayResize(expirationTimes, orders);
   double   commissions    []; ArrayResize(commissions,     orders);
   double   swaps          []; ArrayResize(swaps,           orders);
   double   profits        []; ArrayResize(profits,         orders);
   int      magicNumbers   []; ArrayResize(magicNumbers,    orders);
   string   comments       []; ArrayResize(comments,        orders);

   for (int n, i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))     // FALSE rein theoretisch: während des Auslesens ändert sich die Anzahl der Datensätze
         break;
      int type = OrderType();                               // gecancelte Orders überspringen
      if (type==OP_BUYLIMIT || type==OP_SELLLIMIT || type==OP_BUYSTOP || type==OP_SELLSTOP)
         continue;
      tickets        [n] = OrderTicket();
      types          [n] = type;
      sizes          [n] = OrderLots();
      symbols        [n] = OrderSymbol();
      openTimes      [n] = OrderOpenTime();
      closeTimes     [n] = OrderCloseTime();
      openPrices     [n] = OrderOpenPrice();
      closePrices    [n] = OrderClosePrice();
      stopLosses     [n] = OrderStopLoss();
      takeProfits    [n] = OrderTakeProfit();
      expirationTimes[n] = OrderExpiration();
      commissions    [n] = OrderCommission();
      swaps          [n] = OrderSwap();
      profits        [n] = OrderProfit();
      magicNumbers   [n] = OrderMagicNumber();
      comments       [n] = OrderComment();
      n++;
   }

   // Arrays justieren
   if (n < orders) {
      ArrayResize(tickets,         n);
      ArrayResize(types,           n);
      ArrayResize(sizes,           n);
      ArrayResize(symbols,         n);
      ArrayResize(openTimes,       n);
      ArrayResize(closeTimes,      n);
      ArrayResize(openPrices,      n);
      ArrayResize(closePrices,     n);
      ArrayResize(stopLosses,      n);
      ArrayResize(takeProfits,     n);
      ArrayResize(expirationTimes, n);
      ArrayResize(commissions,     n);
      ArrayResize(swaps,           n);
      ArrayResize(profits,         n);
      ArrayResize(magicNumbers,    n);
      ArrayResize(comments,        n);
      orders = n;
   }


   // (2) Daten in CVS-Datei schreiben

   // Datei erzeugen (und ggf. löschen)
   int handle = FileOpen('AccountHistory_'+ AccountNumber() +".csv", FILE_CSV|FILE_WRITE, '\t');
   if (handle < 0)
      return(catch("start(1)  FileOpen()"));

   // Header schreiben
   string header = "# History for account no. "+ AccountNumber() +" ("+ AccountCompany() +")\n"
                 + "#";
   if (FileWrite(handle, header) < 0) {
      int error = GetLastError();
      FileClose(handle);
      return(catch("start(2)  FileWrite()", error));
   }
   if (FileWrite(handle, "Ticket","OpenTime","OpenTimestamp","Description","Type","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","ExpirationTime","ExpirationTimestamp","MagicNumber","Commission","Swap","NetProfit","GrossProfit","Balance","Comment") < 0) {
      error = GetLastError();
      FileClose(handle);
      return(catch("start(3)  FileWrite()", error));
   }











   // (3) Datei per synchronem HTTP-Post-Request auf Server laden
   // (3) Antwort des Servers einlesen
   // (4) Antwort auswerten und Rückmeldung an den User geben

   return(catch("start()"));
   start_old();
}


/**
 * Alte Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start_old() {
   debug("start_old()   enter");

   // (1) Sortierschlüssel aller verfügbaren Tickets auslesen und Daten sortieren
   // (2) letztes, bereits gespeichertes Ticket und entsprechende AccountBalance ermitteln
   // (3) erstes, neu zu speicherndes Ticket suchen
   // (4) aktuelle History sortiert einlesen und zwischenspeichern, um Transaktionsdaten etc. korrigieren zu können
   // (5) Hedges korrigieren (Größe, ClosePrice, Commission, Swap, NetProfit => zur 1. Position, die hedgende Position wird verworfen)
   // (6) GrossProfit und Balance berechnen und mit dem letzten in der History gespeicherten Wert abgleichen
   // (7) Balance stimmt und es sind keine neuen Daten zu schreiben = > lokale History ist aktuell => Rückkehr
   // (8) neue Daten: Ist die Historydatei leer, wird sie neugeschrieben, anderenfalls werden die Daten angefügt.
   // (9) Orderdaten schreiben


   int account = GetAccountNumber();
   if (account == 0)
      return(catch("start_old(1)", stdlib_GetLastError()));

   // (1) Sortierschlüssel aller verfügbaren Tickets auslesen und Daten sortieren
   int orders = OrdersHistoryTotal();
   int ticketData[][3];
   ArrayResize(ticketData, orders);

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
         ArrayResize(ticketData, i);         // theoretischer Fall: während des Auslesens ändert sich die Anzahl der Datensätze
         orders = i;
         break;
      }
      ticketData[i][0] = OrderCloseTime();
      ticketData[i][1] = OrderOpenTime();
      ticketData[i][2] = OrderTicket();
   }
   SortTickets(ticketData);


   // (2) letztes, bereits gespeichertes Ticket und entsprechende AccountBalance ermitteln
   int    lastTicket;
   double lastBalance;
   string history[][HISTORY_COLUMNS]; ArrayResize(history, 0);
   GetAccountHistory(account, history);

   int entries = ArrayRange(history, 0);
   if (entries > 0) {
      lastTicket  = StrToInteger(history[entries-1][HC_TICKET ]);
      lastBalance = StrToDouble (history[entries-1][HC_BALANCE]);
   }
   if (orders==0 && lastBalance!=AccountBalance())
      return(catch("start_old(2)  balance mismatch, more history data needed", ERR_RUNTIME_ERROR));


   // Hilfsvariablen
   int      tickets     []; ArrayResize(tickets,      0); ArrayResize(tickets,      orders);
   int      types       []; ArrayResize(types,        0); ArrayResize(types,        orders);
   double   sizes       []; ArrayResize(sizes,        0); ArrayResize(sizes,        orders);
   string   symbols     []; ArrayResize(symbols,      0); ArrayResize(symbols,      orders);
   datetime openTimes   []; ArrayResize(openTimes,    0); ArrayResize(openTimes,    orders);
   datetime closeTimes  []; ArrayResize(closeTimes,   0); ArrayResize(closeTimes,   orders);
   double   openPrices  []; ArrayResize(openPrices,   0); ArrayResize(openPrices,   orders);
   double   closePrices []; ArrayResize(closePrices,  0); ArrayResize(closePrices,  orders);
   double   stopLosses  []; ArrayResize(stopLosses,   0); ArrayResize(stopLosses,   orders);
   double   takeProfits []; ArrayResize(takeProfits,  0); ArrayResize(takeProfits,  orders);
   datetime expTimes    []; ArrayResize(expTimes,     0); ArrayResize(expTimes,     orders);
   double   commissions []; ArrayResize(commissions,  0); ArrayResize(commissions,  orders);
   double   swaps       []; ArrayResize(swaps,        0); ArrayResize(swaps,        orders);
   double   netProfits  []; ArrayResize(netProfits,   0); ArrayResize(netProfits,   orders);
   double   grossProfits[]; ArrayResize(grossProfits, 0); ArrayResize(grossProfits, orders);
   double   balances    []; ArrayResize(balances,     0); ArrayResize(balances,     orders);
   int      magicNumbers[]; ArrayResize(magicNumbers, 0); ArrayResize(magicNumbers, orders);
   string   comments    []; ArrayResize(comments,     0); ArrayResize(comments,     orders);


   // (3) erstes, neu zu speicherndes Ticket suchen
   int firstNewTicket = 0;
   if (entries > 0) {
      for (i=0; i < orders; i++) {
         if (ticketData[i][2] == lastTicket) {
            firstNewTicket = i+1;
            break;
         }
      }
   }


   // (4) aktuelle History sortiert einlesen und zwischenspeichern, um Transaktionsdaten etc. korrigieren zu können
   int n;
   for (i=firstNewTicket; i < orders; i++) {
      int ticket = ticketData[i][2];
      if (!OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
         return(catch("start_old(3)  OrderSelect(ticket="+ ticket +")"));

      // gecancelte Orders werden nicht berücksichtigt
      int type = OrderType();
      if (type==OP_BUYLIMIT || type==OP_SELLLIMIT || type==OP_BUYSTOP || type==OP_SELLSTOP)
         continue;

      tickets     [n] = ticket;
      types       [n] = type;
      sizes       [n] = OrderLots();
      symbols     [n] = OrderSymbol();
      openTimes   [n] = OrderOpenTime();
      closeTimes  [n] = OrderCloseTime();
      openPrices  [n] = OrderOpenPrice();
      closePrices [n] = OrderClosePrice();
      stopLosses  [n] = OrderStopLoss();
      takeProfits [n] = OrderTakeProfit();
      expTimes    [n] = OrderExpiration();
      commissions [n] = OrderCommission();
      swaps       [n] = OrderSwap();
      netProfits  [n] = OrderProfit();
      magicNumbers[n] = OrderMagicNumber();
      comments    [n] = StringTrim(OrderComment());   // GrossProfit und Balance werden später berechnet
      n++;
   }

   // Arrays justieren
   if (n < orders) {
      ArrayResize(tickets,      n);
      ArrayResize(types,        n);
      ArrayResize(sizes,        n);
      ArrayResize(symbols,      n);
      ArrayResize(openTimes,    n);
      ArrayResize(closeTimes,   n);
      ArrayResize(openPrices,   n);
      ArrayResize(closePrices,  n);
      ArrayResize(stopLosses,   n);
      ArrayResize(takeProfits,  n);
      ArrayResize(commissions,  n);
      ArrayResize(swaps,        n);
      ArrayResize(netProfits,   n);
      ArrayResize(grossProfits, n);
      ArrayResize(balances,     n);
      ArrayResize(expTimes,     n);
      ArrayResize(magicNumbers, n);
      ArrayResize(comments,     n);
      orders = n;
   }


   // (5) Hedges korrigieren (Größe, ClosePrice, Commission, Swap, NetProfit => zur 1. Position, die hedgende Position wird verworfen)
   for (i=0; i < orders; i++) {
      if ((types[i]==OP_BUY || types[i]==OP_SELL) && sizes[i]==0.0) {

         // TODO: prüfen, wie sich die Orderkommentare bei partiellen Closes und custom comments verhalten

         if (!StringIStartsWith(comments[i], "close hedge by #"))
            return(catch("start_old(4)  ticket #"+ tickets[i] +" - unknown comment for assumed hedged position: "+ comments[i], ERR_RUNTIME_ERROR));

         // Gegenstück der Position suchen
         ticket = StrToInteger(StringSubstr(comments[i], 16));
         for (n=0; n < orders; n++)
            if (tickets[n] == ticket)
               break;
         if (n == orders)
            return(catch("start_old(5)  cannot find counterpart for hedged position #"+ tickets[i] +": "+ comments[i], ERR_RUNTIME_ERROR));

         // zeitliche Reihenfolge der Hedges bestimmen
         int first, second;
         if      (openTimes[i] < openTimes[n]) { first = i; second = n; }
         else if (openTimes[i] > openTimes[n]) { first = n; second = i; }
         else if (tickets  [i] < tickets  [n]) { first = i; second = n; }  // beide zum selben Zeitpunkt eröffnet: unwahrscheinlich, doch nicht unmöglich
         else                                  { first = n; second = i; }

         // Orderdaten korrigieren
         if (i == first) {
            sizes      [first] = sizes      [second];    // alle Transaktionsdaten in der 1. Order speichern
            closePrices[first] = openPrices [second];
            commissions[first] = commissions[second];
            swaps      [first] = swaps      [second];
            netProfits [first] = netProfits [second];

            sizes     [second] = 0.0;                    // hedgende Order auf 0 setzen, damit sie später gelöscht werden kann
            comments  [second] = "close hedge by #"+ tickets[first];
         }
         else /*(i == second)*/ {
            // hedgende Order aus den Daten löschen
            // TODO: prüfen, ob ArrayCopy(void dest[], object source[]) auf ein und demselben Array arbeiten kann
            orders--;
         }
         comments[first] = "closed by hedge";
      }
   }


   // (6) GrossProfit und Balance berechnen und mit dem letzten in der History gespeicherten Wert abgleichen
   for (i=0; i < orders; i++) {
      grossProfits[i] = NormalizeDouble(netProfits[i] + commissions[i] + swaps[i], 2);
      balances[i]     = NormalizeDouble(lastBalance + grossProfits[i], 2);
      lastBalance     = balances[i];
   }
   if (lastBalance != AccountBalance()) {
      Print("start_old()  balance mismatch, calculated: "+ DoubleToStr(lastBalance, 2) +"   online: "+ DoubleToStr(AccountBalance(), 2));
      return(catch("start_old(6)  balance mismatch, more history data needed", ERR_RUNTIME_ERROR));
   }


   // (7) Balance stimmt und es sind keine neuen Daten zu schreiben = > lokale History ist aktuell => Rückkehr
   if (orders == 0) {
      MessageBox("History is up to date.", "Script", MB_ICONINFORMATION|MB_OK);
      return(catch("start_old(7)"));
   }


   // (8) neue Daten: Ist die Historydatei leer, wird sie neugeschrieben, anderenfalls werden die Daten angefügt.
   if (ArrayRange(history, 0) == 0) {
      // Datei erzeugen (und ggf. löschen)
      int handle = FileOpen(account +"/account history.csv", FILE_CSV|FILE_WRITE, '\t');
      if (handle < 0)
         return(catch("start_old(8)  FileOpen()"));

      // Header schreiben
      string header = "# History for account no. "+ account +" ("+ AccountCompany() +")\n"
                    + "#";
      if (FileWrite(handle, header) < 0) {
         int error = GetLastError();
         FileClose(handle);
         return(catch("start_old(9)  FileWrite()", error));
      }
      if (FileWrite(handle, "Ticket","OpenTime","OpenTimestamp","Description","Type","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","ExpirationTime","ExpirationTimestamp","MagicNumber","Commission","Swap","NetProfit","GrossProfit","Balance","Comment") < 0) {
         error = GetLastError();
         FileClose(handle);
         return(catch("start_old(10)  FileWrite()", error));
      }
   }
   // Historydatei enthält bereits Daten, öffnen und FilePointer ans Ende setzen
   else {
      handle = FileOpen(account +"/account history.csv", FILE_CSV|FILE_READ|FILE_WRITE, '\t');
      if (handle < 0)
         return(catch("start_old(11)  FileOpen()"));
      if (!FileSeek(handle, 0, SEEK_END)) {
         error = GetLastError();
         FileClose(handle);
         return(catch("start_old(12)  FileSeek()", error));
      }
   }


   // (9) Orderdaten schreiben
   for (i=0; i < orders; i++) {
      string strType = OperationTypeToStr(types[i]);
      string strSize = ""; if (types[i] < OP_BALANCE) strSize = NumberToStr(sizes[i], ".+");

      string strOpenTime  = TimeToStr(openTimes [i], TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      string strCloseTime = TimeToStr(closeTimes[i], TIME_DATE|TIME_MINUTES|TIME_SECONDS);

      string strOpenPrice  = ""; if (openPrices [i] > 0) strOpenPrice  = NumberToStr(openPrices [i], ".2+");
      string strClosePrice = ""; if (closePrices[i] > 0) strClosePrice = NumberToStr(closePrices[i], ".2+");
      string strStopLoss   = ""; if (stopLosses [i] > 0) strStopLoss   = NumberToStr(stopLosses [i], ".2+");
      string strTakeProfit = ""; if (takeProfits[i] > 0) strTakeProfit = NumberToStr(takeProfits[i], ".2+");

      string strExpTime="", strExpTimestamp="";
      if (expTimes[i] > 0) {
         strExpTime      = TimeToStr(expTimes[i], TIME_DATE|TIME_MINUTES|TIME_SECONDS);
         strExpTimestamp = expTimes[i];
      }
      string strMagicNumber = ""; if (magicNumbers[i] != 0) strMagicNumber = magicNumbers[i];

      string strCommission  = DoubleToStr(commissions [i], 2);
      string strSwap        = DoubleToStr(swaps       [i], 2);
      string strNetProfit   = DoubleToStr(netProfits  [i], 2);
      string strGrossProfit = DoubleToStr(grossProfits[i], 2);
      string strBalance     = DoubleToStr(balances    [i], 2);

      if (FileWrite(handle, tickets[i],strOpenTime,openTimes[i],strType,types[i],strSize,symbols[i],strOpenPrice,strStopLoss,strTakeProfit,strCloseTime,closeTimes[i],strClosePrice,strExpTime,strExpTimestamp,strMagicNumber,strCommission,strSwap,strNetProfit,strGrossProfit,strBalance,comments[i]) < 0) {
         error = GetLastError();
         FileClose(handle);
         return(catch("start_old(13)  FileWrite()", error));
      }
   }
   FileClose(handle);

   debug("start_old()   leave");
   MessageBox("History successfully updated.", "Script", MB_ICONINFORMATION|MB_OK);
   return(catch("start_old(14)"));
}


/**
 * Sortiert die übergebenen Ticketdaten nach { CloseTime, OpenTime, Ticket }.
 *
 * @return int - Fehlerstatus
 */
int SortTickets(int& lpTickets[][/*{CloseTime, OpenTime, Ticket}*/]) {
   if (ArrayRange(lpTickets, 1) != 3)
      return(catch("SortTickets(1)  invalid parameter tickets["+ ArrayRange(lpTickets, 0) +"]["+ ArrayRange(lpTickets, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   int count = ArrayRange(lpTickets, 0);
   if (count < 2)
      return(catch("SortTickets(2)"));                // one element only, nothing to do


   // (1) alles nach CloseTime sortieren
   ArraySort(lpTickets);


   // (2) Datensätze mit derselben CloseTime nach OpenTime sortieren
   int close, open, ticket, lastClose, n;
   int sameClose[][3]; ArrayResize(sameClose, 1);                    // { OpenTime, Ticket, index }

   for (int i=0; i < count; i++) {
      close  = lpTickets[i][0];
      open   = lpTickets[i][1];
      ticket = lpTickets[i][2];

      if (close == lastClose) {
         n++;
         ArrayResize(sameClose, n+1);
      }
      else if (n > 0) {
         // in sameClose angesammelte Werte nach OpenTime sortieren und zurück nach lpTickets schreiben
         SortSameCloseTickets(sameClose, lpTickets);
         ArrayResize(sameClose, 1);
         n = 0;
      }
      sameClose[n][0] = open;
      sameClose[n][1] = ticket;
      sameClose[n][2] = i;             // Original-Position des Datensatzes in lpTickets

      lastClose = close;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameClose ggf. angesammelte Werte müssen auch verarbeitet werden
      SortSameCloseTickets(sameClose, lpTickets);
      n = 0;
   }


   // (3) Datensätze mit derselben Close- und OpenTime nach Ticket sortieren
   int lastOpen, sameCloseOpen[][2]; ArrayResize(sameCloseOpen, 1);  // { Ticket, index }
   lastClose = 0;

   for (i=0; i < count; i++) {
      close  = lpTickets[i][0];
      open   = lpTickets[i][1];
      ticket = lpTickets[i][2];

      if (close==lastClose && open==lastOpen) {
         n++;
         ArrayResize(sameCloseOpen, n+1);
      }
      else if (n > 0) {
         // in sameCloseOpen angesammelte Werte nach Ticket sortieren und zurück nach lpTickets schreiben
         SortSameCloseOpenTickets(sameCloseOpen, lpTickets);
         ArrayResize(sameCloseOpen, 1);
         n = 0;
      }
      sameCloseOpen[n][0] = ticket;
      sameCloseOpen[n][1] = i;         // Original-Position des Datensatzes in lpTickets

      lastClose = close;
      lastOpen  = open;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameCloseOpen ggf. angesammelte Werte müssen auch verarbeitet werden
      SortSameCloseOpenTickets(sameCloseOpen, lpTickets);
   }

   return(catch("SortTickets(3)"));
}


/**
 * Sortiert die übergebenen Ticketdaten nach OpenTime und schreibt die Ergebnisse zurück ins Ursprungarray lpTickets.
 *
 * @return int - Fehlerstatus
 */
int SortSameCloseTickets(int sameClose[][/*{OpenTime, Ticket, index}*/], int& lpTickets[][/*{CloseTime, OpenTime, Ticket}*/]) {
   int open, ticket, i;

   int sameCloseCopy[][3]; ArrayResize(sameCloseCopy, 0);
   ArrayCopy(sameCloseCopy, sameClose);         // Original-Reihenfolge der Indizes in Kopie speichern
   ArraySort(sameClose);                        // und nach OpenTime sortieren...

   int count = ArrayRange(sameClose, 0);

   for (int n=0; n < count; n++) {
      open   = sameClose    [n][0];
      ticket = sameClose    [n][1];
      i      = sameCloseCopy[n][2];
      lpTickets[i][1] = open;                   // Original-Daten mit den sortierten Werten überschreiben
      lpTickets[i][2] = ticket;
   }

   return(catch("SortSameCloseTickets()"));
}


/**
 * Sortiert die übergebenen Ticketdaten nach Ticket# und schreibt die Ergebnisse zurück ins Ursprungarray lpTickets.
 *
 * @return int - Fehlerstatus
 */
int SortSameCloseOpenTickets(int sameCloseOpen[][/*{Ticket, index}*/], int& lpTickets[][/*{OpenTime, CloseTime, Ticket}*/]) {
   int ticket=0, i=0;

   int sameCloseOpenCopy[][2]; ArrayResize(sameCloseOpenCopy, 0);
   ArrayCopy(sameCloseOpenCopy, sameCloseOpen); // Original-Reihenfolge der Indizes in Kopie speichern
   ArraySort(sameCloseOpen);                    // und nach Ticket sortieren...

   int count = ArrayRange(sameCloseOpen, 0);

   for (int n=0; n < count; n++) {
      ticket = sameCloseOpen    [n][0];
      i      = sameCloseOpenCopy[n][1];
      lpTickets[i][2] = ticket;                 // Original-Daten mit den sortierten Werten überschreiben
   }

   return(catch("SortSameCloseOpenTickets()"));
}

