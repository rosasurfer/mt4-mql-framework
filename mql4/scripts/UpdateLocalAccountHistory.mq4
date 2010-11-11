
#include <stdlib.mqh>
#include <win32api.mqh>


//#property show_confirm
//#property show_inputs


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   int error;

   int account = GetAccountNumber();
   if (account == 0)
      return(catch("start()", GetLastLibraryError()));

   int tick   = GetTickCount();
   int orders = OrdersHistoryTotal();


   // Sortierschlüssel: CloseTime, OpenTime, Ticket
   int ticketData[][3];
   ArrayResize(ticketData, 0); ArrayResize(ticketData, orders);


   // Sortierschlüssel aller Tickets aus Online-History auslesen und Tickets sortieren
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         break;
      ticketData[i][0] = OrderCloseTime();
      ticketData[i][1] = OrderOpenTime();
      ticketData[i][2] = OrderTicket();
   }
   SortTickets(ticketData);


   // letztes bereits gespeichertes Ticket und dessen Balance ermitteln
   int    lastTicket;
   double lastBalance;
   string history[][HISTORY_COLUMNS]; ArrayResize(history, 0);
   GetAccountHistory(account, history);

   i = ArrayRange(history, 0);
   if (i > 0) {
      lastTicket  = StrToInteger(history[i-1][HC_TICKET ]);
      lastBalance = StrToDouble (history[i-1][HC_BALANCE]);
   }
   if (orders == 0) if (lastBalance != AccountBalance())
      return(catch("start(1)  balance mismatch, more history data needed", ERR_RUNTIME_ERROR));


   // Index des ersten ungespeicherten Tickets suchen
   int startIndex = 0;
   if (ArrayRange(history, 0) > 0) {
      for (i=0; i < orders; i++) {
         if (ticketData[i][2] == lastTicket) {
            startIndex = i+1;
            break;
         }
      }
   }


   // Hilfsvariablen
   int      n, ticket, type;
   int      tickets[];           ArrayResize(tickets,           0); ArrayResize(tickets,           orders);
   int      types[];             ArrayResize(types,             0); ArrayResize(types,             orders);
   double   sizes[];             ArrayResize(sizes,             0); ArrayResize(sizes,             orders);
   string   symbols[];           ArrayResize(symbols,           0); ArrayResize(symbols,           orders);
   datetime openTimes[];         ArrayResize(openTimes,         0); ArrayResize(openTimes,         orders);
   datetime closeTimes[];        ArrayResize(closeTimes,        0); ArrayResize(closeTimes,        orders);
   double   openPrices[];        ArrayResize(openPrices,        0); ArrayResize(openPrices,        orders);
   double   closePrices[];       ArrayResize(closePrices,       0); ArrayResize(closePrices,       orders);
   double   stopLosses[];        ArrayResize(stopLosses,        0); ArrayResize(stopLosses,        orders);
   double   takeProfits[];       ArrayResize(takeProfits,       0); ArrayResize(takeProfits,       orders);
   double   commissions[];       ArrayResize(commissions,       0); ArrayResize(commissions,       orders);
   double   swaps[];             ArrayResize(swaps,             0); ArrayResize(swaps,             orders);
   double   netProfits[];        ArrayResize(netProfits,        0); ArrayResize(netProfits,        orders);
   double   grossProfits[];      ArrayResize(grossProfits,      0); ArrayResize(grossProfits,      orders);
   double   normalizedProfits[]; ArrayResize(normalizedProfits, 0); ArrayResize(normalizedProfits, orders);
   double   balances[];          ArrayResize(balances,          0); ArrayResize(balances,          orders);
   datetime expTimes[];          ArrayResize(expTimes,          0); ArrayResize(expTimes,          orders);
   int      magicNumbers[];      ArrayResize(magicNumbers,      0); ArrayResize(magicNumbers,      orders);
   string   comments[];          ArrayResize(comments,          0); ArrayResize(comments,          orders);


   // History sortiert auslesen und zwischenspeichern (um gehedgte Positionen korrigieren zu können)
   for (i=startIndex; i < orders; i++) {
      ticket = ticketData[i][2];
      if (!OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
         return(catch("start(2)  OrderSelect(ticket="+ ticket +")"));

      // nur Trades und Ein-/Auszahlungen werden berücksichtigt (keine gecancelten Orders, keine Kreditlinien)
      type = OrderType();
      if (type==OP_BUY || type==OP_SELL || type==OP_BALANCE) {
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
         commissions [n] = OrderCommission();
         swaps       [n] = OrderSwap();
         netProfits  [n] = OrderProfit();
         expTimes    [n] = OrderExpiration();   // GrossProfit, NormalizedProfit und Balance werden später berechnet
         magicNumbers[n] = OrderMagicNumber();
         comments    [n] = OrderComment();
         n++;
      }
   }


   // Arrays justieren
   if (n < orders) {
      ArrayResize(tickets,           n);
      ArrayResize(types,             n);
      ArrayResize(sizes,             n);
      ArrayResize(symbols,           n);
      ArrayResize(openTimes,         n);
      ArrayResize(closeTimes,        n);
      ArrayResize(openPrices,        n);
      ArrayResize(closePrices,       n);
      ArrayResize(stopLosses,        n);
      ArrayResize(takeProfits,       n);
      ArrayResize(commissions,       n);
      ArrayResize(swaps,             n);
      ArrayResize(netProfits,        n);
      ArrayResize(grossProfits,      n);
      ArrayResize(normalizedProfits, n);
      ArrayResize(balances,          n);
      ArrayResize(expTimes,          n);
      ArrayResize(magicNumbers,      n);
      ArrayResize(comments,          n);
      orders = n;
   }


   // gehedgte Positionen korrigieren (Größe, ClosePrice, Commission, Swap, NetProfit)
   for (i=0; i < orders; i++) {
      if (sizes[i] == 0) {
         if (StringSubstr(comments[i], 0, 16) != "close hedge by #")
            return(catch("start(3)  transaction "+ tickets[i] +" - unknown comment for hedged position: "+ comments[i], ERR_RUNTIME_ERROR));

         // Gegenstück der Position suchen
         ticket = StrToInteger(StringSubstr(comments[i], 16));
         for (n=0; n < orders; n++)
            if (tickets[n] == ticket)
               break;
         if (n == orders)
            return(catch("start(4)  cannot find counterpart position #"+ ticket +" for hedged position #"+ tickets[i], ERR_RUNTIME_ERROR));

         // zeitliche Reihenfolge der gehedgten Positionen bestimmen
         int first, second;
         if      (openTimes[i] < openTimes[n]) { first = i; second = n; }
         else if (openTimes[i] > openTimes[n]) { first = n; second = i; }
         else if (tickets[i]   < tickets[n]  ) { first = i; second = n; }  // beide zum selben Zeitpunkt eröffnet: unwahrscheinlich, doch nicht unmöglich
         else                                  { first = n; second = i; }

         // Orderdaten korrigieren
         sizes[i]       = sizes[n];
         closePrices[i] = openPrices[second];   // ClosePrice ist der OpenPrice der späteren Position (sie hedgt die frühere Position)
         closePrices[n] = openPrices[second];

         commissions[first] = commissions[n];   // der gesamte Profit/Loss wird der gehedgten Postion zugerechnet
         swaps      [first] = swaps      [n];
         netProfits [first] = netProfits [n];

         commissions[second] = 0;               // die hedgende Position selbst verursacht keine Kosten
         swaps      [second] = 0;
         netProfits [second] = 0;
      }
   }


   // GrossProfit und Balance berechnen und mit dem in der History gespeicherten letzten Wert gegenprüfen
   for (i=0; i < orders; i++) {
      grossProfits[i] = NormalizeDouble(netProfits[i] + commissions[i] + swaps[i], 2);
      balances[i]     = NormalizeDouble(lastBalance + grossProfits[i], 2);
      lastBalance     = balances[i];
   }
   if (lastBalance != AccountBalance()) {
      Print("start()  balance mismatch, calculated: "+ DoubleToStr(lastBalance, 2) +"   online: "+ DoubleToStr(AccountBalance(), 2));
      return(catch("start(5)  balance mismatch, more history data needed", ERR_RUNTIME_ERROR));
   }


   // Rückkehr, wenn lokale History aktuell ist
   if (orders == 0) {
      Print("start()  local history is up to date");
      MessageBox("History is up to date.", "Script", MB_ICONINFORMATION|MB_OK);
      return(catch("start(6)"));
   }


   // Alle Daten ok: Datei schreiben
   int handle;

   // Ist die Historydatei leer, wird sie neugeschrieben. Anderenfalls werden die neuen Daten am Ende angefügt.
   if (ArrayRange(history, 0) == 0) {
      // Datei neu erzeugen (und ggf. löschen)
      handle = FileOpen(account +"/account history.csv", FILE_CSV|FILE_WRITE, '\t');
      if (handle < 0)
         return(catch("start(7)  FileOpen()"));

      // Header schreiben
      string timezone = GetServerTimezone();
      int iOffset;
      if      (timezone == "EET"     ) iOffset =  2;     // Hier sind evt. Fehler in der Timezone-Berechnung unkritisch,
      else if (timezone == "EET,EEST") iOffset =  2;     // denn das Ergebnis wird nur für den Header verwendet.
      else if (timezone == "CET"     ) iOffset =  1;
      else if (timezone == "CET,CEST") iOffset =  1;
      else if (timezone == "GMT"     ) iOffset =  0;
      else if (timezone == "GMT,BST" ) iOffset =  0;
      else if (timezone == "EST"     ) iOffset = -5;
      else if (timezone == "EST,EDT" ) iOffset = -5;
      string strOffset = DoubleToStr(MathAbs(iOffset), 0);

      if (MathAbs(iOffset) < 10) strOffset = "0"+ strOffset;
      if (iOffset < 0)           strOffset = "-"+ strOffset;
      else                       strOffset = "+"+ strOffset;

      string header = "# History for account no. "+ account +" at "+ AccountCompany() +" (ordered by CloseTime+OpenTime+Ticket, transaction times are GMT"+ strOffset +":00)\n"
                    + "#";
      if (FileWrite(handle, header) < 0) {
         error = GetLastError();
         FileClose(handle);
         return(catch("start(11)  FileWrite()", error));
      }
      if (FileWrite(handle, "Ticket","OpenTime","OpenTimestamp","Description","Type","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","ExpirationTime","ExpirationTimestamp","MagicNumber","Commission","Swap","NetProfit","GrossProfit","NormalizedProfit","Balance","Comment") < 0) {
         error = GetLastError();
         FileClose(handle);
         return(catch("start(8)  FileWrite()", error));
      }
   }
   // Historydatei enthält bereits Daten, öffnen und FilePointer ans Ende setzen
   else {
      handle = FileOpen(account +"/account history.csv", FILE_CSV|FILE_READ|FILE_WRITE, '\t');
      if (handle < 0)
         return(catch("start(9)  FileOpen()"));
      if (!FileSeek(handle, 0, SEEK_END)) {
         error = GetLastError();
         FileClose(handle);
         return(catch("start(10)  FileSeek()", error));
      }
   }


   // Orderdaten schreiben
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

      string strCommission       = DoubleToStr(commissions [i], 2);
      string strSwap             = DoubleToStr(swaps       [i], 2);
      string strNetProfit        = DoubleToStr(netProfits  [i], 2);
      string strGrossProfit      = DoubleToStr(grossProfits[i], 2);
      string strNormalizedProfit = "0.0";
      string strBalance          = DoubleToStr(balances    [i], 2);

      if (FileWrite(handle, tickets[i],strOpenTime,openTimes[i],strType,types[i],strSize,symbols[i],strOpenPrice,strStopLoss,strTakeProfit,strCloseTime,closeTimes[i],strClosePrice,strExpTime,strExpTimestamp,strMagicNumber,strCommission,strSwap,strNetProfit,strGrossProfit,strNormalizedProfit,strBalance,comments[i]) < 0) {
         error = GetLastError();
         FileClose(handle);
         return(catch("start(11)  FileWrite()", error));
      }
   }
   FileClose(handle);


   Print("start()  written history entries: ", orders, ", execution time: ", GetTickCount()-tick, " ms");
   MessageBox("History successfully updated.", "Script", MB_ICONINFORMATION|MB_OK);
   return(catch("start(12)"));
}


/**
 *
 */
int SortTickets(int& tickets[][/*{CloseTime, OpenTime, Ticket}*/]) {
   if (ArrayRange(tickets, 1) != 3)
      return(catch("SortTickets(1)  invalid parameter tickets["+ ArrayRange(tickets, 0) +"]["+ ArrayRange(tickets, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   if (ArrayRange(tickets, 0) < 2)
      return(catch("SortTickets(2)"));


   // zuerst alles nach CloseTime sortieren
   ArraySort(tickets);

   int close, open, ticket;
   int lastClose=0, lastOpen=0, n=0;


   // Datensätze mit derselben CloseTime nach OpenTime sortieren
   int sameClose[][3]; ArrayResize(sameClose, 0); ArrayResize(sameClose, 1);    // {OpenTime, Ticket, index}
   int count = ArrayRange(tickets, 0);

   for (int i=0; i < count; i++) {
      close  = tickets[i][0];
      open   = tickets[i][1];
      ticket = tickets[i][2];

      if (close == lastClose) {
         n++;
         ArrayResize(sameClose, n+1);
      }
      else if (n > 0) {
         // in sameClose gesammelte Werte neu sortieren
         SortSameCloseTickets(sameClose, tickets);
         ArrayResize(sameClose, 1);
         n = 0;
      }

      sameClose[n][0] = open;
      sameClose[n][1] = ticket;
      sameClose[n][2] = i;       // Original-Position des Datensatzes in tickets

      lastClose = close;
   }
   // im letzten Schleifendurchlauf in sameClose gesammelte Werte müssen extra sortiert werden
   if (n > 0) {
      SortSameCloseTickets(sameClose, tickets);
      n = 0;
   }


   // Datensätze mit derselben Close- und OpenTime nach Ticket sortieren
   int sameCloseOpen[][2]; ArrayResize(sameCloseOpen, 0); ArrayResize(sameCloseOpen, 1); // {Ticket, index}

   for (i=0; i < count; i++) {
      close  = tickets[i][0];
      open   = tickets[i][1];
      ticket = tickets[i][2];

      if (close==lastClose && open==lastOpen) {
         n++;
         ArrayResize(sameCloseOpen, n+1);
      }
      else if (n > 0) {
         // in sameCloseOpen gesammelte Werte neu sortieren
         SortSameCloseOpenTickets(sameCloseOpen, tickets);
         ArrayResize(sameCloseOpen, 1);
         n = 0;
      }

      sameCloseOpen[n][0] = ticket;
      sameCloseOpen[n][1] = i;

      lastClose = close;
      lastOpen  = open;
   }
   // im letzten Schleifendurchlauf in sameCloseOpen gesammelte Werte müssen extra sortiert werden
   if (n > 0)
      SortSameCloseOpenTickets(sameCloseOpen, tickets);

   return(catch("SortTickets(3)"));
}


/**
 *
 */
int SortSameCloseTickets(int sameClose[][/*{OpenTime, Ticket, index}*/], int& tickets[][/*{CloseTime, OpenTime, Ticket}*/]) {
   int open, ticket, i;

   int sameCloseCopy[][3]; ArrayResize(sameCloseCopy, 0);
   ArrayCopy(sameCloseCopy, sameClose);   // Original-Reihenfolge der Indizes in Kopie speichern
   ArraySort(sameClose);                  // und nach OpenTime sortieren...

   int count = ArrayRange(sameClose, 0);

   for (int n=0; n < count; n++) {
      open   = sameClose    [n][0];
      ticket = sameClose    [n][1];
      i      = sameCloseCopy[n][2];
      tickets[i][1] = open;               // Original-Daten mit den sortierten Werten überschreiben
      tickets[i][2] = ticket;
   }

   return(catch("SortSameCloseTickets()"));
}


/**
 *
 */
int SortSameCloseOpenTickets(int sameCloseOpen[][/*{Ticket, index}*/], int& tickets[][/*{OpenTime, CloseTime, Ticket}*/]) {
   int ticket=0, i=0;

   int sameCloseOpenCopy[][2]; ArrayResize(sameCloseOpenCopy, 0);
   ArrayCopy(sameCloseOpenCopy, sameCloseOpen); // Original-Reihenfolge der Indizes in Kopie speichern
   ArraySort(sameCloseOpen);                    // und nach Ticket sortieren...

   int count = ArrayRange(sameCloseOpen, 0);

   for (int n=0; n < count; n++) {
      ticket = sameCloseOpen    [n][0];
      i      = sameCloseOpenCopy[n][1];
      tickets[i][2] = ticket;                   // Original-Daten mit den sortierten Werten überschreiben
   }

   return(catch("SortSameCloseOpenTickets()"));
}

