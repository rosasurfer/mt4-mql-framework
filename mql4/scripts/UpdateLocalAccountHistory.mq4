/**
 * Aktualisiert die lokale, dateibasierte Accounthistory. Gewährung oder Rückzug von Margin Credits werden nicht gespeichert.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   int account = GetAccountNumber();
   if (!account) {
      PlaySound("notify.wav");
      MessageBox("No trade server connection.", __NAME__, MB_ICONEXCLAMATION|MB_OK);
      return(SetLastError(ERR_NO_CONNECTION));
   }


   // (1) Sortierschlüssel aller verfügbaren Tickets auslesen und Tickets aufsteigend nach {CloseTime,OpenTime,Ticket} sortieren
   int orders = OrdersHistoryTotal();
   int sortKeys[][3];
   ArrayResize(sortKeys, orders);

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {            // FALSE: während des Auslesens wurde der Anzeigezeitraum der History verkürzt
         ArrayResize(sortKeys, i);
         orders = i;
         break;
      }
      sortKeys[i][0] = OrderCloseTime();
      sortKeys[i][1] = OrderOpenTime();
      sortKeys[i][2] = OrderTicket();
   }
   SortTickets(sortKeys);


   // (2) Tickets sortiert einlesen
   int      tickets     [];
   int      types       [];
   string   symbols     [];
   double   lotSizes    [];
   datetime openTimes   [];
   datetime closeTimes  [];
   double   openPrices  [];
   double   closePrices [];
   double   stopLosses  [];
   double   takeProfits [];
   double   commissions [];
   double   swaps       [];
   double   netProfits  [];
   double   grossProfits[];
   double   balances    [];
   int      magicNumbers[];
   string   comments    [];

   for (i=0; i < orders; i++) {
      int ticket = sortKeys[i][2];
      if (!SelectTicket(ticket, "onStart(1)"))
         return(last_error);
      int type = OrderType();                                                       // gecancelte Orders und Margin Credits überspringen
      if (type==OP_BUYLIMIT || type==OP_SELLLIMIT || type==OP_BUYSTOP || type==OP_SELLSTOP || type==OP_CREDIT)
         continue;
      ArrayPushInt   (tickets     , ticket            );
      ArrayPushInt   (types       , type              );
      ArrayPushString(symbols     , OrderSymbol()     ); if (type != OP_BALANCE) symbols[ArraySize(symbols)-1] = GetStandardSymbol(OrderSymbol());
      ArrayPushDouble(lotSizes    , ifDouble(type==OP_BALANCE, 0, OrderLots()));    // OP_BALANCE: OrderLots() enthält fälschlich 0.01
      ArrayPushInt   (openTimes   , OrderOpenTime()   );
      ArrayPushInt   (closeTimes  , OrderCloseTime()  );
      ArrayPushDouble(openPrices  , OrderOpenPrice()  );
      ArrayPushDouble(closePrices , OrderClosePrice() );
      ArrayPushDouble(stopLosses  , OrderStopLoss()   );
      ArrayPushDouble(takeProfits , OrderTakeProfit() );
      ArrayPushDouble(commissions , OrderCommission() );
      ArrayPushDouble(swaps       , OrderSwap()       );
      ArrayPushDouble(netProfits  , OrderProfit()     );
      ArrayPushDouble(grossProfits, 0                 );
      ArrayPushDouble(balances    , 0                 );
      ArrayPushInt   (magicNumbers, OrderMagicNumber());
      ArrayPushString(comments    , OrderComment()    );
   }
   orders = ArraySize(tickets);


   // (3) Hedges korrigieren: relevante Daten der ersten Position zuordnen und hedgende Position korrigieren
   for (i=0; i < orders; i++) {
      if ((types[i]==OP_BUY || types[i]==OP_SELL) && EQ(lotSizes[i], 0)) {    // lotSize = 0.00: Hedge-Position
         // TODO: Prüfen, wie sich OrderComment() bei partiellem Close und/oder custom comments verhält.

         if (!StringIStartsWith(comments[i], "close hedge by #"))
            return(catch("onStart(2)   #"+ tickets[i] +" - unknown comment for assumed hedging position: \""+ comments[i] +"\"", ERR_RUNTIME_ERROR));

         // Gegenstück der Order suchen
         ticket = StrToInteger(StringSubstr(comments[i], 16));
         for (int n=0; n < orders; n++) {
            if (tickets[n] == ticket)
               break;
         }
         if (n == orders) return(catch("onStart(3)   cannot find counterpart for hedging position #"+ tickets[i] +": \""+ comments[i] +"\"", ERR_RUNTIME_ERROR));
         if (i == n     ) return(catch("onStart(4)   both hedged and hedging position have the same ticket #"+ tickets[i] +": \""+ comments[i] +"\"", ERR_RUNTIME_ERROR));

         int first  = Min(i, n);
         int second = Max(i, n);

         // Orderdaten korrigieren
         lotSizes[i] = lotSizes[n];                                           // lotSizes[i] == 0 korrigieren
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
   string history[][AH_COLUMNS];

   int error = GetAccountHistory(account, history);
   if (IsError(error)) /*&&*/ if (error!=ERR_CANNOT_OPEN_FILE)                // ERR_CANNOT_OPEN_FILE ignorieren => History ist leer
      return(catch("onStart(5)", error));

   int    lastTicket;
   double lastBalance;
   int    histSize = ArrayRange(history, 0);

   if (histSize > 0) {
      lastTicket  = StrToInteger(history[histSize-1][I_AH_TICKET ]);
      lastBalance = StrToDouble (history[histSize-1][I_AH_BALANCE]);
      //debug("onStart()   lastTicket = "+ lastTicket +"   lastBalance = "+ NumberToStr(lastBalance, ", .2"));
   }
   if (!orders) {
      if (NE(lastBalance, AccountBalance())) {
         PlaySound("notify.wav");
         MessageBox("Balance mismatch, more history data needed.", __NAME__, MB_ICONEXCLAMATION|MB_OK);
         return(catch("onStart(6)"));
      }
      PlaySound("ding.wav");
      MessageBox("History is up-to-date.", __NAME__, MB_ICONINFORMATION|MB_OK);
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
         return(catch("onStart(8)   data error: balance mismatch between history file ("+ NumberToStr(lastBalance, ", .2") +") and account ("+ NumberToStr(AccountBalance(), ", .2") +")", ERR_RUNTIME_ERROR));
      PlaySound("ding.wav");
      MessageBox("History is up-to-date.", __NAME__, MB_ICONINFORMATION|MB_OK);
      return(catch("onStart(9)"));
   }


   // (6) GrossProfit und Balance berechnen und mit dem letzten gespeicherten Wert abgleichen
   for (i=iFirstTicketToSave; i < orders; i++) {
      grossProfits[i] = NormalizeDouble(netProfits[i] + commissions[i] + swaps[i], 2);
      if (types[i] == OP_CREDIT)
         grossProfits[i] = 0;                                              // Credit-Beträge ignorieren (falls sie hier überhaupt auftauchen)
      balances[i]     = NormalizeDouble(lastBalance + grossProfits[i], 2);
      lastBalance     = balances[i];
   }
   if (NE(lastBalance, AccountBalance())) {
      if (__LOG) log("onStart(11)   balance mismatch: calculated = "+ NumberToStr(lastBalance, ", .2") +"   current = "+ NumberToStr(AccountBalance(), ", .2"));
      PlaySound("notify.wav");
      MessageBox("Balance mismatch, more history data needed.", __NAME__, MB_ICONEXCLAMATION|MB_OK);
      return(catch("onStart(12)"));
   }


   // (7) CSV-Datei erzeugen
   string filename = ShortAccountCompany() +"/"+ account +"_account_history.csv";

   if (ArrayRange(history, 0) == 0) {
      // (7.1) Datei erzeugen (und ggf. auf Länge 0 zurücksetzen)
      int hFile = FileOpen(filename, FILE_CSV|FILE_WRITE, '\t');
      if (hFile < 0)
         return(catch("onStart(13)->FileOpen()"));

      // Header schreiben
      string header = "# Account history for "+ ifString(IsDemo(), "demo", "real")  +" account #"+ account +" (name: "+ AccountName() +") at "+ AccountCompany() +" (server: "+ GetServerDirectory() +")\n"
                    + "#";
      if (FileWrite(hFile, header) < 0) {
         catch("onStart(14)->FileWrite()");
         FileClose(hFile);
         return(last_error);
      }
      if (FileWrite(hFile, "Ticket","OpenTime","OpenTimestamp","Description","Type","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","MagicNumber","Commission","Swap","NetProfit","GrossProfit","Balance","Comment") < 0) {
         catch("onStart(15)->FileWrite()");
         FileClose(hFile);
         return(last_error);
      }
   }

   else {
      // (7.2) CSV-Datei enthält bereits Daten, öffnen und FilePointer ans Ende setzen
      hFile = FileOpen(filename, FILE_CSV|FILE_READ|FILE_WRITE, '\t');
      if (hFile < 0)
         return(catch("onStart(16)->FileOpen()"));
      if (!FileSeek(hFile, 0, SEEK_END)) {
         catch("onStart(17)->FileSeek()");
         FileClose(hFile);
         return(last_error);
      }
   }


   // (8) Orderdaten schreiben
   for (i=iFirstTicketToSave; i < orders; i++) {
      if (!tickets[i])                                               // verworfene Hedge-Orders überspringen
         continue;

      string strType        = OperationTypeDescription(types[i]);
      string strSize        = ifString(EQ(lotSizes[i], 0), "", NumberToStr(lotSizes[i], ".+"));

      string strOpenTime    = TimeToStr(openTimes [i], TIME_FULL);
      string strCloseTime   = TimeToStr(closeTimes[i], TIME_FULL);

      string strOpenPrice   = ifString(EQ(openPrices [i], 0), "", NumberToStr(openPrices [i], ".2+"));
      string strClosePrice  = ifString(EQ(closePrices[i], 0), "", NumberToStr(closePrices[i], ".2+"));
      string strStopLoss    = ifString(EQ(stopLosses [i], 0), "", NumberToStr(stopLosses [i], ".2+"));
      string strTakeProfit  = ifString(EQ(takeProfits[i], 0), "", NumberToStr(takeProfits[i], ".2+"));

      string strCommission  = DoubleToStr(commissions [i], 2);
      string strSwap        = DoubleToStr(swaps       [i], 2);
      string strNetProfit   = DoubleToStr(netProfits  [i], 2);
      string strGrossProfit = DoubleToStr(grossProfits[i], 2);
      string strBalance     = DoubleToStr(balances    [i], 2);

      string strMagicNumber = ifString(!magicNumbers[i], "", magicNumbers[i]);

      if (FileWrite(hFile, tickets[i], strOpenTime, openTimes[i], strType, types[i], strSize, symbols[i], strOpenPrice, strStopLoss, strTakeProfit, strCloseTime, closeTimes[i], strClosePrice, strMagicNumber, strCommission, strSwap, strNetProfit, strGrossProfit, strBalance, comments[i]) < 0) {
         catch("onStart(18)->FileWrite()");
         FileClose(hFile);
         return(last_error);
      }
   }
   FileClose(hFile);

   PlaySound("ding.wav");
   MessageBox("History successfully updated.", __NAME__, MB_ICONINFORMATION|MB_OK);
   return(last_error);
}


/**
 * Sortiert die übergebenen Ticketdaten nach CloseTime_asc, OpenTime_asc, Ticket_asc.
 *
 * @param  int keys[] - Array mit Sortierschlüsseln
 *
 * @return int - Fehlerstatus
 */
int SortTickets(int keys[][/*{CloseTime, OpenTime, Ticket}*/]) {
   if (ArrayRange(keys, 1) != 3)
      return(catch("SortTickets(1)   invalid parameter keys["+ ArrayRange(keys, 0) +"]["+ ArrayRange(keys, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   int rows = ArrayRange(keys, 0);
   if (rows < 2)
      return(catch("SortTickets(2)"));                      // single row, nothing to do


   // (1) alle Zeilen nach CloseTime sortieren
   ArraySort(keys);


   // (2) Zeilen mit derselben CloseTime nach OpenTime sortieren
   int close, open, ticket, lastClose, n, sameCloses[][3];
   ArrayResize(sameCloses, 1);

   for (int i=0; i < rows; i++) {
      close  = keys[i][0];
      open   = keys[i][1];
      ticket = keys[i][2];

      if (close == lastClose) {
         n++;
         ArrayResize(sameCloses, n+1);
      }
      else if (n > 0) {
         // in sameCloses[] angesammelte Zeilen nach OpenTime sortieren und zurück nach keys[] schreiben
         SortTickets.SameClose(sameCloses, keys);
         ArrayResize(sameCloses, 1);
         n = 0;
      }
      sameCloses[n][0] = open;
      sameCloses[n][1] = ticket;
      sameCloses[n][2] = i;                                 // Originalposition der Zeile in keys[]

      lastClose = close;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameCloses[] angesammelte Zeilen müssen auch verarbeitet werden
      SortTickets.SameClose(sameCloses, keys);
      n = 0;
   }


   // (3) Zeilen mit derselben Close- und OpenTime nach Ticket sortieren
   int lastOpen, sameOpens[][2];
   ArrayResize(sameOpens, 1);
   lastClose = 0;

   for (i=0; i < rows; i++) {
      close  = keys[i][0];
      open   = keys[i][1];
      ticket = keys[i][2];

      if (close==lastClose && open==lastOpen) {
         n++;
         ArrayResize(sameOpens, n+1);
      }
      else if (n > 0) {
         // in sameOpens[] angesammelte Werte nach Ticket sortieren und zurück nach keys[] schreiben
         SortTickets.SameOpen(sameOpens, keys);
         ArrayResize(sameOpens, 1);
         n = 0;
      }
      sameOpens[n][0] = ticket;
      sameOpens[n][1] = i;                                  // Originalposition der Zeile in keys[]

      lastClose = close;
      lastOpen  = open;
   }
   if (n > 0) {
      // im letzten Schleifendurchlauf in sameOpens[] angesammelte Werte müssen auch verarbeitet werden
      SortTickets.SameOpen(sameOpens, keys);
   }

   return(catch("SortTickets(3)"));
}


/**
 * Sortiert die in sameCloses[] übergebenen Daten und aktualisiert die entsprechenden Einträge in data[].
 *
 * @param  int  sameCloses[] - Array mit Ausgangsdaten
 * @param  int &data[]       - das zu aktualisierende Originalarray
 *
 * @return int - Fehlerstatus
 */
int SortTickets.SameClose(int sameCloses[][/*{OpenTime, Ticket, i}*/], int &data[][/*{CloseTime, OpenTime, Ticket}*/]) {
   int sameCloses.copy[][3]; ArrayResize(sameCloses.copy, 0);
   ArrayCopy(sameCloses.copy, sameCloses);               // Originalreihenfolge der Indizes in Kopie speichern

   // Zeilen nach OpenTime sortieren
   ArraySort(sameCloses);

   // Original-Daten mit den sortierten Werten überschreiben
   int open, ticket, i, rows=ArrayRange(sameCloses, 0);

   for (int n=0; n < rows; n++) {
      open   = sameCloses     [n][0];
      ticket = sameCloses     [n][1];
      i      = sameCloses.copy[n][2];
      data[i][1] = open;                                 // Originaldaten mit den sortierten Werten überschreiben
      data[i][2] = ticket;
   }

   return(catch("SortTickets.SameClose()"));
}


/**
 * Sortiert die in sameOpens[] übergebenen Daten nach Ticket und aktualisiert die entsprechenden Einträge in data[].
 *
 * @param  int  sameOpens[] - Array mit Ausgangsdaten
 * @param  int &data[]      - das zu aktualisierende Originalarray
 *
 * @return int - Fehlerstatus
 */
int SortTickets.SameOpen(int sameOpens[][/*{Ticket, i}*/], int &data[][/*{OpenTime, CloseTime, Ticket}*/]) {
   int sameOpens.copy[][2]; ArrayResize(sameOpens.copy, 0);
   ArrayCopy(sameOpens.copy, sameOpens);                 // Originalreihenfolge der Indizes in Kopie speichern

   // alle Zeilen nach Ticket sortieren
   ArraySort(sameOpens);

   int ticket, i, rows=ArrayRange(sameOpens, 0);

   for (int n=0; n < rows; n++) {
      ticket = sameOpens     [n][0];
      i      = sameOpens.copy[n][1];
      data[i][2] = ticket;                               // Originaldaten mit den sortierten Werten überschreiben
   }

   return(catch("SortTickets.SameOpen()"));
}
