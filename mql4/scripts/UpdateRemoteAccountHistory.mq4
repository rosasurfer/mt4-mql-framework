/**
 * UpdateRemoteAccountHistory.mq4
 *
 * Aktualisiert die entfernte Server-Accounthistory.
 */
#include <stdlib.mqh>


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


   // (2) CSV-Datei schreiben
   // Datei erzeugen (bzw. existierende Datei auf Länge 0 zurücksetzen)
   int handle = FileOpen("AccountHistory_"+ AccountNumber() +".csv", FILE_CSV|FILE_WRITE, '\t');   // Spaltentrennzeichen: Tab
   if (handle < 0)
      return(catch("start(1)  FileOpen()"));

   // Dateikommentar schreiben
   string header = "# Account history for account #"+ AccountNumber() +" ("+ AccountCompany() +") - "+ AccountName();
   if (FileWrite(handle, header) < 0) {
      int error = GetLastError();
      FileClose(handle);
      return(catch("start(2)  FileWrite()", error));
   }

   // Status-Header schreiben
   if (FileWrite(handle, "[Status]\naccount status informations") < 0) {
      error = GetLastError();
      FileClose(handle);
      return(catch("start(3)  FileWrite()", error));
   }

   // Daten-Header schreiben
   if (FileWrite(handle, "[Data]\nTicket","OpenTime","OpenTimestamp","TypeDescription","Type","Size","Symbol","OpenPrice","StopLoss","TakeProfit","ExpirationTime","ExpirationTimestamp","CloseTime","CloseTimestamp","ClosePrice","Commission","Swap","Profit","MagicNumber","Comment") < 0) {
      error = GetLastError();
      FileClose(handle);
      return(catch("start(4)  FileWrite()", error));
   }

   // Datei schließen
   FileClose(handle);




   // (3) Datei per HTTP-Post-Request zum Server schicken und auf Antwort warten
   // (4) Antwort auswerten und Rückmeldung an den User geben

   return(catch("start()"));
}

