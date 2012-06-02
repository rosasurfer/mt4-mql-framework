/**
 * Aktualisiert die lokale, dateibasierte Accounthistory. Gewährung und Rückzug von zusätzlichen Margin Credits werden nicht mitgespeichert.
 */
#include <types.mqh>
#define     __TYPE__    T_SCRIPT
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   int account = AccountNumber();
   if (account == 0) {
      PlaySound("notify.wav");
      MessageBox("No trade server connection.", __NAME__, MB_ICONEXCLAMATION|MB_OK);
      return(SetLastError(ERR_NO_CONNECTION));
   }


   // (1) Sortierschlüssel der verfügbaren Tickets auslesen und Tickets sortieren
   int orders = OrdersHistoryTotal();
   int sortData[][3];
   ArrayResize(sortData, orders);

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {            // FALSE: während des Auslesens wurde der Anzeigezeitraum der History verändert
         ArrayResize(sortData, i);
         orders = i;
         break;
      }
      sortData[i][0] = OrderCloseTime();
      sortData[i][1] = OrderOpenTime();
      sortData[i][2] = OrderTicket();
   }
   SortTickets(sortData);


   // (2) Ticketdaten sortiert einlesen
   int      tickets        []; ArrayResize(tickets,         orders);
   int      types          []; ArrayResize(types,           orders);
   string   symbols        []; ArrayResize(symbols,         orders);
   double   lotSizes       []; ArrayResize(lotSizes,        orders);
   datetime openTimes      []; ArrayResize(openTimes,       orders);
   datetime closeTimes     []; ArrayResize(closeTimes,      orders);
   double   openPrices     []; ArrayResize(openPrices,      orders);
   double   closePrices    []; ArrayResize(closePrices,     orders);
   double   stopLosses     []; ArrayResize(stopLosses,      orders);
   double   takeProfits    []; ArrayResize(takeProfits,     orders);
   datetime expirationTimes[]; ArrayResize(expirationTimes, orders);
   double   commissions    []; ArrayResize(commissions,     orders);
   double   swaps          []; ArrayResize(swaps,           orders);
   double   netProfits     []; ArrayResize(netProfits,      orders);
   double   grossProfits   []; ArrayResize(grossProfits,    orders);
   double   balances       []; ArrayResize(balances,        orders);
   int      magicNumbers   []; ArrayResize(magicNumbers,    orders);
   string   comments       []; ArrayResize(comments,        orders);
   int n;

   for (i=0, n=0; i < orders; i++) {
      int ticket = sortData[i][2];
      if (!OrderSelectByTicket(ticket, "onStart(1)"))
         return(last_error);

      int type = OrderType();                                        // gecancelte Orders und Margin Credits überspringen
      if (type==OP_BUYLIMIT || type==OP_SELLLIMIT || type==OP_BUYSTOP || type==OP_SELLSTOP || type==OP_CREDIT)
         continue;
      tickets        [n] = ticket;
      types          [n] = type;
      symbols        [n] = OrderSymbol(); if (type!=OP_BALANCE) symbols[n] = GetStandardSymbol(OrderSymbol());
      lotSizes       [n] = ifDouble(type==OP_BALANCE, 0, OrderLots());  // OP_BALANCE: OrderLots() enthält fälschlich 0.01
      openTimes      [n] = OrderOpenTime();
      closeTimes     [n] = OrderCloseTime();
      openPrices     [n] = OrderOpenPrice();
      closePrices    [n] = OrderClosePrice();
      stopLosses     [n] = OrderStopLoss();
      takeProfits    [n] = OrderTakeProfit();
      expirationTimes[n] = OrderExpiration();
      commissions    [n] = OrderCommission();
      swaps          [n] = OrderSwap();
      netProfits     [n] = OrderProfit();
      magicNumbers   [n] = OrderMagicNumber();
      comments       [n] = OrderComment();
      n++;
   }
   if (n < orders) {
      ArrayResize(tickets,         n);
      ArrayResize(types,           n);
      ArrayResize(symbols,         n);
      ArrayResize(lotSizes,        n);
      ArrayResize(openTimes,       n);
      ArrayResize(closeTimes,      n);
      ArrayResize(openPrices,      n);
      ArrayResize(closePrices,     n);
      ArrayResize(stopLosses,      n);
      ArrayResize(takeProfits,     n);
      ArrayResize(expirationTimes, n);
      ArrayResize(commissions,     n);
      ArrayResize(swaps,           n);
      ArrayResize(netProfits,      n);
      ArrayResize(grossProfits,    n);
      ArrayResize(balances,        n);
      ArrayResize(magicNumbers,    n);
      ArrayResize(comments,        n);
      orders = n;
   }


   // (3) Hedges korrigieren: relevante Daten der ersten Position zuordnen und hedgende Position korrigieren
   for (i=0; i < orders; i++) {
      if ((types[i]==OP_BUY || types[i]==OP_SELL) && EQ(lotSizes[i], 0)) {    // lotSize = 0.00: Hedge-Position
         // TODO: Prüfen, wie sich OrderComment() bei partiellem Close und/oder custom comments verhält.

         if (!StringIStartsWith(comments[i], "close hedge by #"))
            return(catch("onStart(2)  #"+ tickets[i] +" - unknown comment for assumed hedging position: \""+ comments[i] +"\"", ERR_RUNTIME_ERROR));

         // Gegenstück der Order suchen
         ticket = StrToInteger(StringSubstr(comments[i], 16));
         for (n=0; n < orders; n++)
            if (tickets[n] == ticket)
               break;
         if (n == orders) return(catch("onStart(3)  cannot find counterpart for hedging position #"+ tickets[i] +": \""+ comments[i] +"\"", ERR_RUNTIME_ERROR));
         if (i == n     ) return(catch("onStart(4)  both hedged and hedging position have the same ticket #"+ tickets[i] +": \""+ comments[i] +"\"", ERR_RUNTIME_ERROR));

         int first  = Min(i, n);
         int second = Max(i, n);

         // Orderdaten korrigieren
         lotSizes[i] = lotSizes[n];                                           // lotSizes[i] == 0.0 korrigieren
         if (i == first) {
            commissions[first ] = commissions[second];                        // alle Transaktionsdaten in der ersten Order speichern
            swaps      [first ] = swaps      [second];
            netProfits [first ] = netProfits [second];
            commissions[second] = 0;
            swaps      [second] = 0;
            netProfits [second] = 0;
         }
         comments[first ] = ifString(comments[n]=="partial close", "partial close", "closed") +" by hedge #"+ tickets[second];
         comments[second] = "hedge for #"+ tickets[first];
      }
   }


   // (4) letztes gespeichertes Ticket und entsprechende AccountBalance ermitteln
   string history[][HISTORY_COLUMNS];

   int error = GetAccountHistory(account, history);
   if (IsError(error)) /*&&*/ if (error!=ERR_CANNOT_OPEN_FILE)                // ERR_CANNOT_OPEN_FILE ignorieren => History ist leer
      return(catch("onStart(5)", error));

   int    lastTicket;
   double lastBalance;
   int    histSize = ArrayRange(history, 0);

   if (histSize > 0) {
      lastTicket  = StrToInteger(history[histSize-1][AH_TICKET ]);
      lastBalance = StrToDouble (history[histSize-1][AH_BALANCE]);
      //debug("onStart()   lastTicket = "+ lastTicket +"   lastBalance = "+ NumberToStr(lastBalance, ", .2"));
   }
   if (orders == 0) {
      if (NE(lastBalance, AccountBalance())) {
         PlaySound("notify.wav");
         MessageBox("Balance mismatch, more history data needed.", __NAME__, MB_ICONEXCLAMATION|MB_OK);
         return(catch("onStart(6)"));
      }
      PlaySound("ding.wav");
      MessageBox("History is up to date.", __NAME__, MB_ICONINFORMATION|MB_OK);
      return(catch("onStart(7)"));
   }


   // (5) Index des ersten, neu zu speichernden Tickets ermitteln
   int iFirstTicketToSave = 0;
   if (histSize > 0) {
      for (i=0; i < orders; i++) {
         if (tickets[i] == lastTicket) {
            iFirstTicketToSave = i+1;
            break;
         }
      }
   }
   if (iFirstTicketToSave == orders) {                                     // alle Tickets sind bereits in der CSV-Datei vorhanden
      if (NE(lastBalance, AccountBalance()))
         return(catch("onStart(8)  data error: balance mismatch between history file ("+ NumberToStr(lastBalance, ", .2") +") and account ("+ NumberToStr(AccountBalance(), ", .2") +")", ERR_RUNTIME_ERROR));
      PlaySound("ding.wav");
      MessageBox("History is up to date.", __NAME__, MB_ICONINFORMATION|MB_OK);
      return(catch("onStart(9)"));
   }
   //log("onStart()   firstTicketToSave = "+ tickets[iFirstTicketToSave]);


   // (6) GrossProfit und Balance berechnen und mit dem letzten gespeicherten Wert abgleichen
   for (i=iFirstTicketToSave; i < orders; i++) {
      grossProfits[i] = NormalizeDouble(netProfits[i] + commissions[i] + swaps[i], 2);
      if (types[i] == OP_CREDIT)
         grossProfits[i] = 0;                                              // Credit-Beträge ignorieren (falls sie hier überhaupt auftauchen)
      balances[i]     = NormalizeDouble(lastBalance + grossProfits[i], 2);
      lastBalance     = balances[i];
   }
   if (NE(lastBalance, AccountBalance())) {
      log("onStart()  balance mismatch: calculated = "+ NumberToStr(lastBalance, ", .2") +"   current = "+ NumberToStr(AccountBalance(), ", .2"));
      PlaySound("notify.wav");
      MessageBox("Balance mismatch, more history data needed.", __NAME__, MB_ICONEXCLAMATION|MB_OK);
      return(catch("onStart(10)"));
   }


   // (7) CSV-Datei erzeugen
   string filename = ShortAccountCompany() +"/"+ account +"_account_history.csv";

   if (ArrayRange(history, 0) == 0) {
      // Datei erzeugen (und ggf. auf Länge 0 zurücksetzen)
      int hFile = FileOpen(filename, FILE_CSV|FILE_WRITE, '\t');
      if (hFile < 0)
         return(catch("onStart(11) ->FileOpen()"));

      // Header schreiben
      string header = "# Account history for "+ ifString(IsDemo(), "demo", "live")  +" account #"+ account +" (name: "+ AccountName() +") at "+ AccountCompany() +" (server: "+ GetServerDirectory() +")\n"
                    + "#";
      if (FileWrite(hFile, header) < 0) {
         catch("onStart(12) ->FileWrite()");
         FileClose(hFile);
         return(last_error);
      }
      if (FileWrite(hFile, "Ticket","OpenTime","OpenTimestamp","Description","Type","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","ExpirationTime","ExpirationTimestamp","MagicNumber","Commission","Swap","NetProfit","GrossProfit","Balance","Comment") < 0) {
         catch("onStart(13) ->FileWrite()");
         FileClose(hFile);
         return(last_error);
      }
   }
   // CSV-Datei enthält bereits Daten, öffnen und FilePointer ans Ende setzen
   else {
      hFile = FileOpen(filename, FILE_CSV|FILE_READ|FILE_WRITE, '\t');
      if (hFile < 0)
         return(catch("onStart(14) ->FileOpen()"));
      if (!FileSeek(hFile, 0, SEEK_END)) {
         catch("onStart(15) ->FileSeek()");
         FileClose(hFile);
         return(last_error);
      }
   }


   // (8) Orderdaten schreiben
   for (i=iFirstTicketToSave; i < orders; i++) {
      if (tickets[i] == 0)                                              // verworfene Hedge-Orders überspringen
         continue;

      string strType         = OperationTypeDescription(types[i]);
      string strSize         = ifString(EQ(lotSizes[i], 0), "", NumberToStr(lotSizes[i], ".+"));

      string strOpenTime     = TimeToStr(openTimes [i], TIME_FULL);
      string strCloseTime    = TimeToStr(closeTimes[i], TIME_FULL);

      string strOpenPrice    = ifString(EQ(openPrices [i], 0), "", NumberToStr(openPrices [i], ".2+"));
      string strClosePrice   = ifString(EQ(closePrices[i], 0), "", NumberToStr(closePrices[i], ".2+"));
      string strStopLoss     = ifString(EQ(stopLosses [i], 0), "", NumberToStr(stopLosses [i], ".2+"));
      string strTakeProfit   = ifString(EQ(takeProfits[i], 0), "", NumberToStr(takeProfits[i], ".2+"));

      string strExpTime      = ifString(expirationTimes[i]==0, "", TimeToStr(expirationTimes[i], TIME_FULL));
      string strExpTimestamp = ifString(expirationTimes[i]==0, "", expirationTimes[i]);

      string strCommission   = DoubleToStr(commissions [i], 2);
      string strSwap         = DoubleToStr(swaps       [i], 2);
      string strNetProfit    = DoubleToStr(netProfits  [i], 2);
      string strGrossProfit  = DoubleToStr(grossProfits[i], 2);
      string strBalance      = DoubleToStr(balances    [i], 2);

      string strMagicNumber  = ifString(magicNumbers[i]==0, "", magicNumbers[i]);

      if (FileWrite(hFile, tickets[i],strOpenTime,openTimes[i],strType,types[i],strSize,symbols[i],strOpenPrice,strStopLoss,strTakeProfit,strCloseTime,closeTimes[i],strClosePrice,strExpTime,strExpTimestamp,strMagicNumber,strCommission,strSwap,strNetProfit,strGrossProfit,strBalance,comments[i]) < 0) {
         catch("onStart(16) ->FileWrite()");
         FileClose(hFile);
         return(last_error);
      }
   }
   FileClose(hFile);

   PlaySound("ding.wav");
   MessageBox("History successfully updated.", __NAME__, MB_ICONINFORMATION|MB_OK);
   return(catch("onStart(17)"));
}


/**
 * Sortiert die übergebenen Ticketdaten nach CloseTime ASC, OpenTime ASC, Ticket ASC.
 *
 * @param  int sortData[] - Array mit Sortierschlüsseln
 *
 * @return int - Fehlerstatus
 */
int SortTickets(int sortData[][/*{CloseTime, OpenTime, Ticket}*/]) {
   if (ArrayRange(sortData, 1) != 3)
      return(catch("SortTickets(1)  invalid parameter sortData["+ ArrayRange(sortData, 0) +"]["+ ArrayRange(sortData, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   int rows = ArrayRange(sortData, 0);
   if (rows < 2)
      return(catch("SortTickets(2)"));                      // single row, nothing to do


   // (1) alle Zeilen nach CloseTime sortieren
   ArraySort(sortData);


   // (2) Zeilen mit derselben CloseTime nach OpenTime sortieren
   int close, open, ticket, lastClose, n, sameCloses[][3];
   ArrayResize(sameCloses, 1);

   for (int i=0; i < rows; i++) {
      close  = sortData[i][0];
      open   = sortData[i][1];
      ticket = sortData[i][2];

      if (close == lastClose) {
         n++;
         ArrayResize(sameCloses, n+1);
      }
      else if (n > 0) {
         // in sameCloses[] angesammelte Zeilen nach OpenTime sortieren und zurück nach sortData[] schreiben
         SortTickets.SameClose(sameCloses, sortData);
         ArrayResize(sameCloses, 1);
         n = 0;
      }
      sameCloses[n][0] = open;
      sameCloses[n][1] = ticket;
      sameCloses[n][2] = i;                                 // Originalposition der Zeile in sortData[]

      lastClose = close;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameCloses[] angesammelte Zeilen müssen auch verarbeitet werden
      SortTickets.SameClose(sameCloses, sortData);
      n = 0;
   }


   // (3) Zeilen mit derselben Close- und OpenTime nach Ticket sortieren
   int lastOpen, sameOpens[][2];
   ArrayResize(sameOpens, 1);
   lastClose = 0;

   for (i=0; i < rows; i++) {
      close  = sortData[i][0];
      open   = sortData[i][1];
      ticket = sortData[i][2];

      if (close==lastClose && open==lastOpen) {
         n++;
         ArrayResize(sameOpens, n+1);
      }
      else if (n > 0) {
         // in sameOpens[] angesammelte Werte nach Ticket sortieren und zurück nach sortData[] schreiben
         SortTickets.SameOpen(sameOpens, sortData);
         ArrayResize(sameOpens, 1);
         n = 0;
      }
      sameOpens[n][0] = ticket;
      sameOpens[n][1] = i;                                  // Originalposition der Zeile in sortData[]

      lastClose = close;
      lastOpen  = open;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameOpens[] angesammelte Werte müssen auch verarbeitet werden
      SortTickets.SameOpen(sameOpens, sortData);
   }

   return(catch("SortTickets(3)"));
}


/**
 * Sortiert die in sameCloses[] übergebenen Daten und aktualisiert die entsprechenden Einträge in data[].
 *
 * @param  int  sameCloses[] - Array mit Ausgangsdaten
 * @param  int& data[]       - das zu aktualisierende Originalarray
 *
 * @return int - Fehlerstatus
 */
int SortTickets.SameClose(int sameCloses[][/*{OpenTime, Ticket, i}*/], int& data[][/*{CloseTime, OpenTime, Ticket}*/]) {
   int sameClosesCopy[][3]; ArrayResize(sameClosesCopy, 0);
   ArrayCopy(sameClosesCopy, sameCloses);                // Originalreihenfolge der Indizes in Kopie speichern

   // Zeilen nach OpenTime sortieren
   ArraySort(sameCloses);

   // Original-Daten mit den sortierten Werten überschreiben
   int open, ticket, i, rows=ArrayRange(sameCloses, 0);

   for (int n=0; n < rows; n++) {
      open   = sameCloses    [n][0];
      ticket = sameCloses    [n][1];
      i      = sameClosesCopy[n][2];
      data[i][1] = open;                                 // Originaldaten mit den sortierten Werten überschreiben
      data[i][2] = ticket;
   }

   return(catch("SortTickets.SameClose()"));
}


/**
 * Sortiert die in sameOpens[] übergebenen Daten nach Ticket und aktualisiert die entsprechenden Einträge in data[].
 *
 * @param  int  sameOpens[] - Array mit Ausgangsdaten
 * @param  int& data[]      - das zu aktualisierende Originalarray
 *
 * @return int - Fehlerstatus
 */
int SortTickets.SameOpen(int sameOpens[][/*{Ticket, i}*/], int& data[][/*{OpenTime, CloseTime, Ticket}*/]) {
   int sameOpensCopy[][2]; ArrayResize(sameOpensCopy, 0);
   ArrayCopy(sameOpensCopy, sameOpens);                  // Originalreihenfolge der Indizes in Kopie speichern

   // alle Zeilen nach Ticket sortieren
   ArraySort(sameOpens);

   int ticket, i, rows=ArrayRange(sameOpens, 0);

   for (int n=0; n < rows; n++) {
      ticket = sameOpens    [n][0];
      i      = sameOpensCopy[n][1];
      data[i][2] = ticket;                               // Originaldaten mit den sortierten Werten überschreiben
   }

   return(catch("SortTickets.SameOpen()"));
}
