/**
 * UpdateLocalAccountHistory
 *
 * Aktualisiert die lokale, dateibasierte Accounthistory. Gewährung und Rückzug von zusätzlichen Credits werden nicht gespeichert.
 */
#include <stdlib.mqh>
#include <win32api.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);
   return(catch("init()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   init = false;
   if (init_error != NO_ERROR)
      return(init_error);
   // -----------------------------------------------------------------------------

   int account = AccountNumber();
   if (account == 0) {
      log("start()  no trade server connection");
      PlaySound("notify.wav");
      MessageBox("No trade server connection.", __SCRIPT__, MB_ICONEXCLAMATION|MB_OK);
      return(ERR_NO_CONNECTION);
   }


   // (1) Sortierschlüssel aller verfügbaren Tickets auslesen und Daten sortieren
   int orders = OrdersHistoryTotal();
   int ticketData[][3];
   ArrayResize(ticketData, orders);

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {      // FALSE ist rein theoretisch: während des Auslesens ändert sich die Zahl der Orderdatensätze
         ArrayResize(ticketData, i);
         orders = i;
         break;
      }
      ticketData[i][0] = OrderCloseTime();
      ticketData[i][1] = OrderOpenTime();
      ticketData[i][2] = OrderTicket();
   }
   SortTickets(ticketData);


   // (2) letztes gespeichertes Ticket und entsprechende AccountBalance ermitteln
   string history[][HISTORY_COLUMNS];

   int error = GetAccountHistory(account, history);
   if (error!=NO_ERROR && error!=ERR_CANNOT_OPEN_FILE)         // ERR_CANNOT_OPEN_FILE ignorieren => History ist leer
      return(catch("start(1)", error));

   int    lastTicket;
   double lastBalance;
   int    histSize = ArrayRange(history, 0);

   if (histSize > 0) {
      lastTicket  = StrToInteger(history[histSize-1][AH_TICKET ]);
      lastBalance = StrToDouble (history[histSize-1][AH_BALANCE]);
      //log("start()   lastTicket = "+ lastTicket +"   lastBalance = "+ NumberToStr(lastBalance, ", .2"));
   }
   if (orders == 0) {
      if (lastBalance != AccountBalance()) {
         PlaySound("notify.wav");
         MessageBox("Balance mismatch, more history data needed.", __SCRIPT__, MB_ICONEXCLAMATION|MB_OK);
         return(catch("start(2)"));
      }
      PlaySound("ding.wav");
      MessageBox("History is up to date.", __SCRIPT__, MB_ICONINFORMATION|MB_OK);
      return(catch("start(3)"));
   }


   // (3) verfügbare Tickets sortiert einlesen
   int      tickets        []; ArrayResize(tickets,         0); ArrayResize(tickets,         orders);
   int      types          []; ArrayResize(types,           0); ArrayResize(types,           orders);
   string   symbols        []; ArrayResize(symbols,         0); ArrayResize(symbols,         orders);
   double   lotSizes       []; ArrayResize(lotSizes,        0); ArrayResize(lotSizes,        orders);
   datetime openTimes      []; ArrayResize(openTimes,       0); ArrayResize(openTimes,       orders);
   datetime closeTimes     []; ArrayResize(closeTimes,      0); ArrayResize(closeTimes,      orders);
   double   openPrices     []; ArrayResize(openPrices,      0); ArrayResize(openPrices,      orders);
   double   closePrices    []; ArrayResize(closePrices,     0); ArrayResize(closePrices,     orders);
   double   stopLosses     []; ArrayResize(stopLosses,      0); ArrayResize(stopLosses,      orders);
   double   takeProfits    []; ArrayResize(takeProfits,     0); ArrayResize(takeProfits,     orders);
   datetime expirationTimes[]; ArrayResize(expirationTimes, 0); ArrayResize(expirationTimes, orders);
   double   commissions    []; ArrayResize(commissions,     0); ArrayResize(commissions,     orders);
   double   swaps          []; ArrayResize(swaps,           0); ArrayResize(swaps,           orders);
   double   netProfits     []; ArrayResize(netProfits,      0); ArrayResize(netProfits,      orders);
   double   grossProfits   []; ArrayResize(grossProfits,    0); ArrayResize(grossProfits,    orders);
   double   balances       []; ArrayResize(balances,        0); ArrayResize(balances,        orders);
   int      magicNumbers   []; ArrayResize(magicNumbers,    0); ArrayResize(magicNumbers,    orders);
   string   comments       []; ArrayResize(comments,        0); ArrayResize(comments,        orders);

   for (i=0; i < orders; i++) {
      int ticket = ticketData[i][2];
      if (!OrderSelect(ticket, SELECT_BY_TICKET)) {                        // FALSE ist rein theoretisch: während der Verarbeitung wird Anzeigezeitraum geändert
         error = GetLastError();
         if (error == NO_ERROR)
            error = ERR_INVALID_TICKET;
         return(catch("start(4)  OrderSelect(ticket="+ ticket +")", error));
      }

      int type = OrderType();                                              // gecancelte Orders und Margin Credits überspringen (0-Tickets werden später verworfen)
      if (type==OP_BUYLIMIT || type==OP_SELLLIMIT || type==OP_BUYSTOP || type==OP_SELLSTOP || type==OP_CREDIT)
         continue;

      tickets        [i] = ticket;
      types          [i] = type;
      symbols        [i] = FindStandardSymbol(OrderSymbol(), OrderSymbol());
      lotSizes       [i] = ifDouble(OrderSymbol()=="", 0, OrderLots());    // OP_BALANCE: OrderLots() enthält fälschlich 0.01
      openTimes      [i] = OrderOpenTime();
      closeTimes     [i] = OrderCloseTime();
      openPrices     [i] = OrderOpenPrice();
      closePrices    [i] = OrderClosePrice();
      stopLosses     [i] = OrderStopLoss();
      takeProfits    [i] = OrderTakeProfit();
      expirationTimes[i] = OrderExpiration();
      commissions    [i] = OrderCommission();
      swaps          [i] = OrderSwap();
      netProfits     [i] = OrderProfit();
      magicNumbers   [i] = OrderMagicNumber();
      comments       [i] = StringTrim(StringReplace(StringReplace(OrderComment(), "\n", " "), "\t", " "));
   }


   // (4) Hedges korrigieren (relevante Daten der ersten Position zuordnen, hedgende Position verwerfen)
   for (i=0; i < orders; i++) {
      if (tickets[i] == 0)                                                 // markierte (= korrigierte) Tickets überspringen
         continue;

      if ((types[i]==OP_BUY || types[i]==OP_SELL) && lotSizes[i]==0) {
         // TODO: Prüfen, wie sich OrderComment() bei partiellem Close und/oder custom comments verhält.

         if (!StringIStartsWith(comments[i], "close hedge by #"))
            return(catch("start(5)  ticket #"+ tickets[i] +" - unknown comment for assumed hedged position: "+ comments[i], ERR_RUNTIME_ERROR));

         // Gegenstück der Order suchen
         ticket = StrToInteger(StringSubstr(comments[i], 16));
         for (int n=0; n < orders; n++)
            if (tickets[n] == ticket)
               break;
         if (n == orders)
            return(catch("start(6)  cannot find counterpart for hedged position #"+ tickets[i] +": "+ comments[i], ERR_RUNTIME_ERROR));
         if (i == n)
            return(catch("start(7)  hedged and counterpart position are the same #"+ tickets[i] +": "+ comments[i], ERR_RUNTIME_ERROR));

         // Reihenfolge beider Positionen bestimmen
         int first;
         if      (closeTimes[i] != closeTimes[n]) first = ifInt(closeTimes[i] < closeTimes[n], i, n);
         else if ( openTimes[i] != openTimes[n] ) first = ifInt( openTimes[i] < openTimes[n] , i, n);
         else                                     first = ifInt(   tickets[i] < tickets[n]   , i, n);
         int second = ifInt(first==n, i, n);

         // Orderdaten korrigieren
         if (i == first) {
            lotSizes   [first] = lotSizes   [second];                      // alle Transaktionsdaten in der 1. Order speichern
            closePrices[first] = openPrices [second];
            commissions[first] = commissions[second];
            swaps      [first] = swaps      [second];
            netProfits [first] = netProfits [second];
         }
         closeTimes[first] = openTimes[second];
         comments  [first] = ifString(comments[first]=="partial close" || comments[second]=="partial close", "partial closed by hedge", "closed by hedge");
         tickets  [second] = 0;                                            // erste Order enthält jetzt alle Daten, hedgende Order markieren (wird später verworfen)
      }
   }


   // TODO: wenn Hedges korrigiert wurden (closeTimes[first] wurde geändert), müssen die Tickets jetzt neu sortiert werden


   // (5) Index des ersten, neu zu speichernden Tickets ermitteln
   int iFirstTicketToSave = 0;
   if (histSize > 0) {
      for (i=0; i < orders; i++) {
         if (ticketData[i][2] == lastTicket) {
            iFirstTicketToSave = i+1;
            break;
            // TODO: iFirstTicketToSave ist nicht unbedingt korrekt, durch Anpassung der Hedges kann es sich ändern
         }
      }
   }
   if (iFirstTicketToSave == orders) {          // alle Tickets sind bereits in der CSV-Datei vorhanden
      if (lastBalance != AccountBalance())
         return(catch("start(8)  data error: balance mismatch between history file ("+ NumberToStr(lastBalance, ", .2") +") and account ("+ NumberToStr(AccountBalance(), ", .2") +")", ERR_RUNTIME_ERROR));
      PlaySound("ding.wav");
      MessageBox("History is up to date.", __SCRIPT__, MB_ICONINFORMATION|MB_OK);
      return(catch("start(9)"));
   }
   //log("start()   firstTicketToSave = "+ ticketData[iFirstTicketToSave][2]);



   // (6) GrossProfit und Balance berechnen und mit dem letzten gespeicherten Wert abgleichen
   for (i=iFirstTicketToSave; i < orders; i++) {
      if (tickets[i] == 0)                                              // verworfene Orders überspringen
         continue;
      grossProfits[i] = NormalizeDouble(netProfits[i] + commissions[i] + swaps[i], 2);
      if (types[i] == OP_CREDIT)
         grossProfits[i] = 0;                                           // Credit-Beträge ignorieren (falls sie hier überhaupt auftauchen)
      balances[i]     = NormalizeDouble(lastBalance + grossProfits[i], 2);
      lastBalance     = balances[i];
   }
   if (lastBalance != AccountBalance()) {
      log("start()  balance mismatch: calculated = "+ NumberToStr(lastBalance, ", .2") +"   current = "+ NumberToStr(AccountBalance(), ", .2"));
      PlaySound("notify.wav");
      MessageBox("Balance mismatch, more history data needed.", __SCRIPT__, MB_ICONEXCLAMATION|MB_OK);
      return(catch("start(10)"));
   }


   // (7) CSV-Datei erzeugen
   string filename = GetTradeServerDirectory() +"/"+ account +"_account_history.csv";

   if (ArrayRange(history, 0) == 0) {
      // Datei erzeugen (und ggf. auf Länge 0 zurücksetzen)
      int hFile = FileOpen(filename, FILE_CSV|FILE_WRITE, '\t');
      if (hFile < 0)
         return(catch("start(11)  FileOpen()"));

      // Header schreiben
      string header = "# Account history for account #"+ account +" ("+ AccountCompany() +") - "+ AccountName() +"\n"
                    + "#";
      if (FileWrite(hFile, header) < 0) {
         error = GetLastError();
         FileClose(hFile);
         return(catch("start(12)  FileWrite()", error));
      }
      if (FileWrite(hFile, "Ticket","OpenTime","OpenTimestamp","Description","Type","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","ExpirationTime","ExpirationTimestamp","MagicNumber","Commission","Swap","NetProfit","GrossProfit","Balance","Comment") < 0) {
         error = GetLastError();
         FileClose(hFile);
         return(catch("start(13)  FileWrite()", error));
      }
   }
   // CSV-Datei enthält bereits Daten, öffnen und FilePointer ans Ende setzen
   else {
      hFile = FileOpen(filename, FILE_CSV|FILE_READ|FILE_WRITE, '\t');
      if (hFile < 0)
         return(catch("start(14)  FileOpen()"));
      if (!FileSeek(hFile, 0, SEEK_END)) {
         error = GetLastError();
         FileClose(hFile);
         return(catch("start(15)  FileSeek()", error));
      }
   }


   // (8) Orderdaten schreiben
   for (i=iFirstTicketToSave; i < orders; i++) {
      if (tickets[i] == 0)                                              // verworfene Hedge-Orders überspringen
         continue;

      string strType         = OperationTypeDescription(types[i]);
      string strSize         = ifString(lotSizes[i]==0, "", NumberToStr(lotSizes[i], ".+"));

      string strOpenTime     = TimeToStr(openTimes [i], TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      string strCloseTime    = TimeToStr(closeTimes[i], TIME_DATE|TIME_MINUTES|TIME_SECONDS);

      string strOpenPrice    = ifString(openPrices [i]==0, "", NumberToStr(openPrices [i], ".2+"));
      string strClosePrice   = ifString(closePrices[i]==0, "", NumberToStr(closePrices[i], ".2+"));
      string strStopLoss     = ifString(stopLosses [i]==0, "", NumberToStr(stopLosses [i], ".2+"));
      string strTakeProfit   = ifString(takeProfits[i]==0, "", NumberToStr(takeProfits[i], ".2+"));

      string strExpTime      = ifString(expirationTimes[i]==0, "", TimeToStr(expirationTimes[i], TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      string strExpTimestamp = ifString(expirationTimes[i]==0, "", expirationTimes[i]);

      string strCommission   = DoubleToStr(commissions [i], 2);
      string strSwap         = DoubleToStr(swaps       [i], 2);
      string strNetProfit    = DoubleToStr(netProfits  [i], 2);
      string strGrossProfit  = DoubleToStr(grossProfits[i], 2);
      string strBalance      = DoubleToStr(balances    [i], 2);

      string strMagicNumber  = ifString(magicNumbers[i]==0, "", magicNumbers[i]);

      if (FileWrite(hFile, tickets[i],strOpenTime,openTimes[i],strType,types[i],strSize,symbols[i],strOpenPrice,strStopLoss,strTakeProfit,strCloseTime,closeTimes[i],strClosePrice,strExpTime,strExpTimestamp,strMagicNumber,strCommission,strSwap,strNetProfit,strGrossProfit,strBalance,comments[i]) < 0) {
         error = GetLastError();
         FileClose(hFile);
         return(catch("start(16)  FileWrite()", error));
      }
   }
   FileClose(hFile);

   PlaySound("ding.wav");
   MessageBox("History successfully updated.", __SCRIPT__, MB_ICONINFORMATION|MB_OK);
   return(catch("start(17)"));
}


/**
 * Sortiert die übergebenen Ticketdaten nach { CloseTime, OpenTime, Ticket }.
 *
 * @param  int& lpTickets[] - Zeiger auf Array mit Ausgangsdaten
 *
 * @return int - Fehlerstatus
 */
int SortTickets(int& lpTickets[][/*{CloseTime, OpenTime, Ticket}*/]) {
   if (ArrayRange(lpTickets, 1) != 3)
      return(catch("SortTickets(1)  invalid parameter tickets["+ ArrayRange(lpTickets, 0) +"]["+ ArrayRange(lpTickets, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   int count = ArrayRange(lpTickets, 0);
   if (count < 2)
      return(catch("SortTickets(2)"));                   // one element only, nothing to do


   // (1) alles nach CloseTime sortieren
   ArraySort(lpTickets);


   // (2) Datensätze mit derselben CloseTime nach OpenTime sortieren
   int close, open, ticket, lastClose, n;
   int sameClose[][3]; ArrayResize(sameClose, 1);        // { OpenTime, Ticket, index }

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
      sameClose[n][2] = i;                               // Original-Position des Datensatzes in lpTickets

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
      sameCloseOpen[n][1] = i;                           // Original-Position des Datensatzes in lpTickets

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
 * Sortiert die in sameClose[] übergebenen Ticketdaten nach OpenTime und aktualisiert die entsprechenden Einträge in lpTickets.
 *
 * @param  int& sameClose[] - Zeiger auf Array mit Ausgangsdaten
 * @param  int& lpTickets[] - Zeiger auf das zu aktualiserende Array
 *
 * @return int - Fehlerstatus
 */
int SortSameCloseTickets(int sameClose[][/*{OpenTime, Ticket, index}*/], int& lpTickets[][/*{CloseTime, OpenTime, Ticket}*/]) {
   int open, ticket, i;

   int sameCloseCopy[][3]; ArrayResize(sameCloseCopy, 0);
   ArrayCopy(sameCloseCopy, sameClose);                  // Original-Reihenfolge der Indizes in Kopie speichern
   ArraySort(sameClose);                                 // und nach OpenTime sortieren...

   int count = ArrayRange(sameClose, 0);

   for (int n=0; n < count; n++) {
      open   = sameClose    [n][0];
      ticket = sameClose    [n][1];
      i      = sameCloseCopy[n][2];
      lpTickets[i][1] = open;                            // Original-Daten mit den sortierten Werten überschreiben
      lpTickets[i][2] = ticket;
   }

   return(catch("SortSameCloseTickets()"));
}


/**
 * Sortiert die in sameCloseOpen[] übergebenen Ticketdaten nach Ticket# und aktualisiert die entsprechenden Einträge in lpTickets.
 *
 * @param  int& sameCloseOpen[] - Zeiger auf Array mit Ausgangsdaten
 * @param  int& lpTickets[]     - Zeiger auf das zu aktualiserende Array
 *
 * @return int - Fehlerstatus
 */
int SortSameCloseOpenTickets(int sameCloseOpen[][/*{Ticket, index}*/], int& lpTickets[][/*{OpenTime, CloseTime, Ticket}*/]) {
   int ticket=0, i=0;

   int sameCloseOpenCopy[][2]; ArrayResize(sameCloseOpenCopy, 0);
   ArrayCopy(sameCloseOpenCopy, sameCloseOpen);          // Original-Reihenfolge der Indizes in Kopie speichern
   ArraySort(sameCloseOpen);                             // und nach Ticket sortieren...

   int count = ArrayRange(sameCloseOpen, 0);

   for (int n=0; n < count; n++) {
      ticket = sameCloseOpen    [n][0];
      i      = sameCloseOpenCopy[n][1];
      lpTickets[i][2] = ticket;                          // Original-Daten mit den sortierten Werten überschreiben
   }

   return(catch("SortSameCloseOpenTickets()"));
}
