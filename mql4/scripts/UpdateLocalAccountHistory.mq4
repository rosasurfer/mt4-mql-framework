/**
 * UpdateLocalAccountHistory
 *
 * Aktualisiert die lokale, dateibasierte Accounthistory. Gewährung und Rückzug von zusätzlichen Credits werden nicht gespeichert.
 */
#include <stdlib.mqh>
#include <win32api.mqh>


int      tickets        [];
int      types          [];
string   symbols        [];
double   lotSizes       [];
datetime openTimes      [];
datetime closeTimes     [];
double   openPrices     [];
double   closePrices    [];
double   stopLosses     [];
double   takeProfits    [];
datetime expirationTimes[];
double   commissions    [];
double   swaps          [];
double   netProfits     [];
double   grossProfits   [];
double   balances       [];
int      magicNumbers   [];
string   comments       [];


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


   // (1) verfügbare Tickets einlesen
   int orders = OrdersHistoryTotal();

   ArrayResize(tickets,         orders);
   ArrayResize(types,           orders);
   ArrayResize(symbols,         orders);
   ArrayResize(lotSizes,        orders);
   ArrayResize(openTimes,       orders);
   ArrayResize(closeTimes,      orders);
   ArrayResize(openPrices,      orders);
   ArrayResize(closePrices,     orders);
   ArrayResize(stopLosses,      orders);
   ArrayResize(takeProfits,     orders);
   ArrayResize(expirationTimes, orders);
   ArrayResize(commissions,     orders);
   ArrayResize(swaps,           orders);
   ArrayResize(netProfits,      orders);
   ArrayResize(grossProfits,    orders);
   ArrayResize(balances,        orders);
   ArrayResize(magicNumbers,    orders);
   ArrayResize(comments,        orders);

   for (int i, n=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))        // FALSE ist rein theoretisch: während der Verarbeitung wird Anzeigezeitraum geändert
         break;
      int type = OrderType();                                  // gecancelte Orders und Margin Credits überspringen
      if (type==OP_BUYLIMIT || type==OP_SELLLIMIT || type==OP_BUYSTOP || type==OP_SELLSTOP || type==OP_CREDIT)
         continue;
      tickets        [n] = OrderTicket();
      types          [n] = type;
      symbols        [n] = FindStandardSymbol(OrderSymbol(), OrderSymbol());
      lotSizes       [n] = ifDouble(OrderSymbol()=="", 0, OrderLots());    // OP_BALANCE: OrderLots() enthält fälschlich 0.01
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
      comments       [n] = StringTrim(StringReplace(StringReplace(OrderComment(), "\n", " "), "\t", " "));
      n++;
   }


   // (2) Hedges korrigieren (relevante Daten der ersten Position zuordnen, hedgende Position verwerfen)
   for (i=0; i < orders; i++) {
      if (tickets[i] == 0)                                                 // markierte (= korrigierte) Tickets überspringen
         continue;

      if ((types[i]==OP_BUY || types[i]==OP_SELL) && EQ(lotSizes[i], 0)) {
         // TODO: Prüfen, wie sich OrderComment() bei partiellem Close und/oder custom comments verhält.

         if (!StringIStartsWith(comments[i], "close hedge by #"))
            return(catch("start(1)  ticket #"+ tickets[i] +" - unknown comment for assumed hedged position: "+ comments[i], ERR_RUNTIME_ERROR));

         // Gegenstück der Order suchen
         int ticket = StrToInteger(StringSubstr(comments[i], 16));
         for (n=0; n < orders; n++)
            if (tickets[n] == ticket)
               break;
         if (n == orders) return(catch("start(2)  cannot find counterpart for hedged position #"+ tickets[i] +": "+ comments[i], ERR_RUNTIME_ERROR));
         if (i == n     ) return(catch("start(3)  hedged and counterpart position are the same #"+ tickets[i] +": "+ comments[i], ERR_RUNTIME_ERROR));

         // Reihenfolge der beiden Positionen bestimmen
         int first;
         if      (closeTimes[i] != closeTimes[n]) first = ifInt(closeTimes[i] < closeTimes[n], i, n);
         else if ( openTimes[i] != openTimes[n] ) first = ifInt( openTimes[i] < openTimes[n] , i, n);
         else                                     first = ifInt(   tickets[i] < tickets[n]   , i, n);
         int second = ifInt(first==n, i, n);

         // Orderdaten korrigieren
         if (i == first) {
            lotSizes   [first] = lotSizes   [second];                      // alle Transaktionsdaten in der ersten Order speichern
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


   // (3) markierte (= korrigierte) Tickets löschen
   for (i=0, n=0; i < orders; i++) {
      if (tickets[i] != 0) {
         tickets        [n] = tickets        [i];
         types          [n] = types          [i];
         symbols        [n] = symbols        [i];
         lotSizes       [n] = lotSizes       [i];
         openTimes      [n] = openTimes      [i];
         closeTimes     [n] = closeTimes     [i];
         openPrices     [n] = openPrices     [i];
         closePrices    [n] = closePrices    [i];
         stopLosses     [n] = stopLosses     [i];
         takeProfits    [n] = takeProfits    [i];
         expirationTimes[n] = expirationTimes[i];
         commissions    [n] = commissions    [i];
         swaps          [n] = swaps          [i];
         netProfits     [n] = netProfits     [i];
         magicNumbers   [n] = magicNumbers   [i];
         comments       [n] = comments       [i];
         n++;
      }
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


   // (4) Daten sortieren
   SortTickets();


   // (5) letztes gespeichertes Ticket und entsprechende AccountBalance ermitteln
   string history[][HISTORY_COLUMNS];

   int error = GetAccountHistory(account, history);
   if (error!=NO_ERROR && error!=ERR_CANNOT_OPEN_FILE)                     // ERR_CANNOT_OPEN_FILE ignorieren => History ist leer
      return(catch("start(4)", error));

   int    lastTicket;
   double lastBalance;
   int    histSize = ArrayRange(history, 0);

   if (histSize > 0) {
      lastTicket  = StrToInteger(history[histSize-1][AH_TICKET ]);
      lastBalance = StrToDouble (history[histSize-1][AH_BALANCE]);
      //log("start()   lastTicket = "+ lastTicket +"   lastBalance = "+ NumberToStr(lastBalance, ", .2"));
   }
   if (orders == 0) {
      if (NE(lastBalance, AccountBalance())) {
         PlaySound("notify.wav");
         MessageBox("Balance mismatch, more history data needed.", __SCRIPT__, MB_ICONEXCLAMATION|MB_OK);
         return(catch("start(5)"));
      }
      PlaySound("ding.wav");
      MessageBox("History is up to date.", __SCRIPT__, MB_ICONINFORMATION|MB_OK);
      return(catch("start(6)"));
   }


   // (6) Index des ersten, neu zu speichernden Tickets ermitteln
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
         return(catch("start(7)  data error: balance mismatch between history file ("+ NumberToStr(lastBalance, ", .2") +") and account ("+ NumberToStr(AccountBalance(), ", .2") +")", ERR_RUNTIME_ERROR));
      PlaySound("ding.wav");
      MessageBox("History is up to date.", __SCRIPT__, MB_ICONINFORMATION|MB_OK);
      return(catch("start(8)"));
   }
   //log("start()   firstTicketToSave = "+ tickets[iFirstTicketToSave]);


   // (7) GrossProfit und Balance berechnen und mit dem letzten gespeicherten Wert abgleichen
   for (i=iFirstTicketToSave; i < orders; i++) {
      grossProfits[i] = NormalizeDouble(netProfits[i] + commissions[i] + swaps[i], 2);
      if (types[i] == OP_CREDIT)
         grossProfits[i] = 0;                                              // Credit-Beträge ignorieren (falls sie hier überhaupt auftauchen)
      balances[i]     = NormalizeDouble(lastBalance + grossProfits[i], 2);
      lastBalance     = balances[i];
   }
   if (NE(lastBalance, AccountBalance())) {
      log("start()  balance mismatch: calculated = "+ NumberToStr(lastBalance, ", .2") +"   current = "+ NumberToStr(AccountBalance(), ", .2"));
      PlaySound("notify.wav");
      MessageBox("Balance mismatch, more history data needed.", __SCRIPT__, MB_ICONEXCLAMATION|MB_OK);
      return(catch("start(9)"));
   }


   // (8) CSV-Datei erzeugen
   string filename = GetTradeServerDirectory() +"/"+ account +"_account_history.csv";

   if (ArrayRange(history, 0) == 0) {
      // Datei erzeugen (und ggf. auf Länge 0 zurücksetzen)
      int hFile = FileOpen(filename, FILE_CSV|FILE_WRITE, '\t');
      if (hFile < 0)
         return(catch("start(10)  FileOpen()"));

      // Header schreiben
      string header = "# Account history for account #"+ account +" ("+ AccountCompany() +") - "+ AccountName() +"\n"
                    + "#";
      if (FileWrite(hFile, header) < 0) {
         error = GetLastError();
         FileClose(hFile);
         return(catch("start(11)  FileWrite()", error));
      }
      if (FileWrite(hFile, "Ticket","OpenTime","OpenTimestamp","Description","Type","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","ExpirationTime","ExpirationTimestamp","MagicNumber","Commission","Swap","NetProfit","GrossProfit","Balance","Comment") < 0) {
         error = GetLastError();
         FileClose(hFile);
         return(catch("start(12)  FileWrite()", error));
      }
   }
   // CSV-Datei enthält bereits Daten, öffnen und FilePointer ans Ende setzen
   else {
      hFile = FileOpen(filename, FILE_CSV|FILE_READ|FILE_WRITE, '\t');
      if (hFile < 0)
         return(catch("start(13)  FileOpen()"));
      if (!FileSeek(hFile, 0, SEEK_END)) {
         error = GetLastError();
         FileClose(hFile);
         return(catch("start(14)  FileSeek()", error));
      }
   }


   // (9) Orderdaten schreiben
   for (i=iFirstTicketToSave; i < orders; i++) {
      if (tickets[i] == 0)                                              // verworfene Hedge-Orders überspringen
         continue;

      string strType         = OperationTypeDescription(types[i]);
      string strSize         = ifString(EQ(lotSizes[i], 0), "", NumberToStr(lotSizes[i], ".+"));

      string strOpenTime     = TimeToStr(openTimes [i], TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      string strCloseTime    = TimeToStr(closeTimes[i], TIME_DATE|TIME_MINUTES|TIME_SECONDS);

      string strOpenPrice    = ifString(EQ(openPrices [i], 0), "", NumberToStr(openPrices [i], ".2+"));
      string strClosePrice   = ifString(EQ(closePrices[i], 0), "", NumberToStr(closePrices[i], ".2+"));
      string strStopLoss     = ifString(EQ(stopLosses [i], 0), "", NumberToStr(stopLosses [i], ".2+"));
      string strTakeProfit   = ifString(EQ(takeProfits[i], 0), "", NumberToStr(takeProfits[i], ".2+"));

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
         return(catch("start(15)  FileWrite()", error));
      }
   }
   FileClose(hFile);

   PlaySound("ding.wav");
   MessageBox("History successfully updated.", __SCRIPT__, MB_ICONINFORMATION|MB_OK);
   return(catch("start(16)"));
}


/**
 * Sortiert die Ticketdaten nach CloseTime ASC, OpenTime ASC, Ticket ASC.
 *
 * @return int - Fehlerstatus
 */
int SortTickets() {
   int rows = ArraySize(tickets);
   if (rows < 2)
      return(catch("SortTickets(1)"));                // single row, nothing to do

   // (1) Sortierspalten extrahieren
   int sortData[][4];
   ArrayResize(sortData, rows);
   for (int i=0; i < rows; i++) {
      sortData[i][0] = closeTimes[i];
      sortData[i][1] = openTimes [i];
      sortData[i][2] = tickets   [i];
      sortData[i][3] = i;                             // Spalte mit Original-Keys (werden mitsortiert)
   }


   // (2) alle Zeilen nach CloseTime sortieren
   ArraySort(sortData);


   // (3) Zeilen mit derselben CloseTime nach OpenTime sortieren
   int close, lastClose, open, ticket, index, n, sameCloses[][4];
   ArrayResize(sameCloses, 1);

   for (i=0; i < rows; i++) {
      close  = sortData[i][0];
      open   = sortData[i][1];
      ticket = sortData[i][2];
      index  = sortData[i][3];

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
      sameCloses[n][2] = index;
      sameCloses[n][3] = i;                           // Originalposition der Zeile in sortData[]

      lastClose = close;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameCloses[] angesammelte Zeilen müssen auch verarbeitet werden
      SortTickets.SameClose(sameCloses, sortData);
      n = 0;
   }


   // (4) Zeilen mit derselben Close- und OpenTime nach Ticket sortieren
   int lastOpen, sameOpens[][3];
   ArrayResize(sameOpens, 1);
   lastClose = 0;

   for (i=0; i < rows; i++) {
      close  = sortData[i][0];
      open   = sortData[i][1];
      ticket = sortData[i][2];
      index  = sortData[i][3];

      if (close==lastClose && open==lastOpen) {
         n++;
         ArrayResize(sameOpens, n+1);
      }
      else if (n > 0) {
         // in sameOpens[] angesammelte Werte nach Ticket sortieren und zurück nach sortData[] schreiben
         SortTickets.SameOpens(sameOpens, sortData);
         ArrayResize(sameOpens, 1);
         n = 0;
      }
      sameOpens[n][0] = ticket;
      sameOpens[n][1] = index;
      sameOpens[n][2] = i;                            // Originalposition der Zeile in sortData[]

      lastClose = close;
      lastOpen  = open;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameOpens[] angesammelte Werte müssen auch verarbeitet werden
      SortTickets.SameOpens(sameOpens, sortData);
   }


   // (5) Datenarrays nach Sortierreihenfolge in sortData[][3] sortieren
   int      tmp_tickets        []; ArrayResize(tmp_tickets,         rows);
   int      tmp_types          []; ArrayResize(tmp_types,           rows);
   string   tmp_symbols        []; ArrayResize(tmp_symbols,         rows);
   double   tmp_lotSizes       []; ArrayResize(tmp_lotSizes,        rows);
   datetime tmp_openTimes      []; ArrayResize(tmp_openTimes,       rows);
   datetime tmp_closeTimes     []; ArrayResize(tmp_closeTimes,      rows);
   double   tmp_openPrices     []; ArrayResize(tmp_openPrices,      rows);
   double   tmp_closePrices    []; ArrayResize(tmp_closePrices,     rows);
   double   tmp_stopLosses     []; ArrayResize(tmp_stopLosses,      rows);
   double   tmp_takeProfits    []; ArrayResize(tmp_takeProfits,     rows);
   datetime tmp_expirationTimes[]; ArrayResize(tmp_expirationTimes, rows);
   double   tmp_commissions    []; ArrayResize(tmp_commissions,     rows);
   double   tmp_swaps          []; ArrayResize(tmp_swaps,           rows);
   double   tmp_netProfits     []; ArrayResize(tmp_netProfits,      rows);
   int      tmp_magicNumbers   []; ArrayResize(tmp_magicNumbers,    rows);
   string   tmp_comments       []; ArrayResize(tmp_comments,        rows);

   for (i=0; i < rows; i++) {
      n = sortData[i][3];

      tmp_tickets        [i] = tickets        [n];
      tmp_types          [i] = types          [n];
      tmp_symbols        [i] = symbols        [n];
      tmp_lotSizes       [i] = lotSizes       [n];
      tmp_openTimes      [i] = openTimes      [n];
      tmp_closeTimes     [i] = closeTimes     [n];
      tmp_openPrices     [i] = openPrices     [n];
      tmp_closePrices    [i] = closePrices    [n];
      tmp_stopLosses     [i] = stopLosses     [n];
      tmp_takeProfits    [i] = takeProfits    [n];
      tmp_expirationTimes[i] = expirationTimes[n];
      tmp_commissions    [i] = commissions    [n];
      tmp_swaps          [i] = swaps          [n];
      tmp_netProfits     [i] = netProfits     [n];
      tmp_magicNumbers   [i] = magicNumbers   [n];
      tmp_comments       [i] = comments       [n];
   }

   ArrayCopy(tickets        , tmp_tickets        );
   ArrayCopy(types          , tmp_types          );
   ArrayCopy(symbols        , tmp_symbols        );
   ArrayCopy(lotSizes       , tmp_lotSizes       );
   ArrayCopy(openTimes      , tmp_openTimes      );
   ArrayCopy(closeTimes     , tmp_closeTimes     );
   ArrayCopy(openPrices     , tmp_openPrices     );
   ArrayCopy(closePrices    , tmp_closePrices    );
   ArrayCopy(stopLosses     , tmp_stopLosses     );
   ArrayCopy(takeProfits    , tmp_takeProfits    );
   ArrayCopy(expirationTimes, tmp_expirationTimes);
   ArrayCopy(commissions    , tmp_commissions    );
   ArrayCopy(swaps          , tmp_swaps          );
   ArrayCopy(netProfits     , tmp_netProfits     );
   ArrayCopy(magicNumbers   , tmp_magicNumbers   );
   ArrayCopy(comments       , tmp_comments       );

   return(catch("SortTickets(2)"));
}


/**
 * Sortiert die in sameCloses[] übergebenen Daten und aktualisiert die entsprechenden Einträge in lpData[].
 *
 * @param  int& sameCloses[] - Zeiger auf Array mit Ausgangsdaten
 * @param  int& lpData[]     - Zeiger auf das zu aktualisierende Originalarray
 *
 * @return int - Fehlerstatus
 */
int SortTickets.SameClose(int sameCloses[][/*{OpenTime, Ticket, Index, i}*/], int& lpData[][/*{CloseTime, OpenTime, Ticket, Index}*/]) {
   int sameClosesCopy[][4]; ArrayResize(sameClosesCopy, 0);
   ArrayCopy(sameClosesCopy, sameCloses);                // Originalreihenfolge der Indizes in Kopie speichern

   // Zeilen nach OpenTime sortieren
   ArraySort(sameCloses);

   // Original-Daten mit den sortierten Werten überschreiben
   int open, ticket, index, i, rows=ArrayRange(sameCloses, 0);

   for (int n=0; n < rows; n++) {
      open   = sameCloses    [n][0];
      ticket = sameCloses    [n][1];
      index  = sameCloses    [n][2];
      i      = sameClosesCopy[n][3];
      lpData[i][1] = open;                               // Originaldaten mit den sortierten Werten überschreiben
      lpData[i][2] = ticket;
      lpData[i][3] = index;
   }

   return(catch("SortTickets.SameClose()"));
}


/**
 * Sortiert die in sameOpens[] übergebenen Daten nach Ticket und aktualisiert die entsprechenden Einträge in lpData[].
 *
 * @param  int& sameOpens[] - Zeiger auf Array mit Ausgangsdaten
 * @param  int& lpData[]    - Zeiger auf das zu aktualisierende Originalarray
 *
 * @return int - Fehlerstatus
 */
int SortTickets.SameOpens(int sameOpens[][/*{Ticket, Index, i}*/], int& lpData[][/*{OpenTime, CloseTime, Ticket, Index}*/]) {
   int sameOpensCopy[][3]; ArrayResize(sameOpensCopy, 0);
   ArrayCopy(sameOpensCopy, sameOpens);                  // Originalreihenfolge der Indizes in Kopie speichern

   // alle Zeilen nach Ticket sortieren
   ArraySort(sameOpens);

   int ticket, index, i, rows=ArrayRange(sameOpens, 0);

   for (int n=0; n < rows; n++) {
      ticket = sameOpens    [n][0];
      index  = sameOpens    [n][1];
      i      = sameOpensCopy[n][2];
      lpData[i][2] = ticket;                             // Originaldaten mit den sortierten Werten überschreiben
      lpData[i][3] = index;
   }

   return(catch("SortTickets.SameOpens()"));
}
