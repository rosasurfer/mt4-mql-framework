/**
 * UpdateRemoteAccountHistory.mq4
 *
 * Aktualisiert die entfernte Server-Accounthistory.
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
      sizes          [n] = OrderLots(); if (types[n]==OP_BALANCE || types[n]==OP_CREDIT) sizes[n] = 0;
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
      comments       [n] = StringTrim(OrderComment());
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


   // (2) CSV-Datei neu schreiben
   string filename = "tmp_accounthistory_"+ AccountNumber() +".csv";
   int hFile = FileOpen(filename, FILE_CSV|FILE_WRITE, '\t');     // Spaltentrennzeichen: Tab
   if (hFile < 0)
      return(catch("start(1)  FileOpen()"));

   // (2.1) Dateikommentar
   string header = "# Account history for account #"+ AccountNumber() +" ("+ AccountCompany() +") - "+ AccountName();
   if (FileWrite(hFile, header) < 0) {
      int error = GetLastError();
      FileClose(hFile);
      return(catch("start(2)  FileWrite()", error));
   }

   // (2.2) Status
   if (FileWrite(hFile, "[Status]") < 0) {
      error = GetLastError();
      FileClose(hFile);
      return(catch("start(3)  FileWrite()", error));
   }
   if (FileWrite(hFile, "account status information") < 0) {
      error = GetLastError();
      FileClose(hFile);
      return(catch("start(4)  FileWrite()", error));
   }

   // (2.2) Daten
   if (FileWrite(hFile, "[Data]\nTicket","OpenTime","OpenTimestamp","TypeStr","Type","Size","Symbol","OpenPrice","StopLoss","TakeProfit","ExpirationTime","ExpirationTimestamp","CloseTime","CloseTimestamp","ClosePrice","Commission","Swap","Profit","MagicNumber","Comment") < 0) {
      error = GetLastError();
      FileClose(hFile);
      return(catch("start(5)  FileWrite()", error));
   }
   for (i=0; i < orders; i++) {
      string strOpenTime    = TimeToStr(openTimes[i], TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      string strType        = OperationTypeToStr(types[i]);
      string strSize        = NumberToStr(sizes[i], ".+");
      string strOpenPrice   = ""; if (openPrices [i] > 0) strOpenPrice  = NumberToStr(openPrices [i], ".2+");
      string strStopLoss    = ""; if (stopLosses [i] > 0) strStopLoss   = NumberToStr(stopLosses [i], ".2+");
      string strTakeProfit  = ""; if (takeProfits[i] > 0) strTakeProfit = NumberToStr(takeProfits[i], ".2+");
      string strExpirationTime="", strExpirationTimestamp="";
      if (expirationTimes[i] > 0) {
         strExpirationTime      = TimeToStr(expirationTimes[i], TIME_DATE|TIME_MINUTES|TIME_SECONDS);
         strExpirationTimestamp = expirationTimes[i];
      }
      string strCloseTime   = TimeToStr(closeTimes[i], TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      string strClosePrice  = ""; if (closePrices[i] > 0) strClosePrice = NumberToStr(closePrices[i], ".2+");
      string strCommission  = DoubleToStr(commissions[i], 2);
      string strSwap        = DoubleToStr(swaps      [i], 2);
      string strProfit      = DoubleToStr(profits    [i], 2);
      string strMagicNumber = ""; if (magicNumbers[i] != 0) strMagicNumber = magicNumbers[i];

      if (FileWrite(hFile, tickets[i],strOpenTime,openTimes[i],strType,types[i],strSize,symbols[i],strOpenPrice,strStopLoss,strTakeProfit,strExpirationTime,strExpirationTimestamp,strCloseTime,closeTimes[i],strClosePrice,strCommission,strSwap,strProfit,strMagicNumber,comments[i]) < 0) {
         error = GetLastError();
         FileClose(hFile);
         return(catch("start(6)  FileWrite()", error));
      }
   }

   // (2.3) Datei schließen
   FileClose(hFile);
   error = GetLastError();
   if (error != ERR_NO_ERROR)
      return(catch("start(7)  FileClose()", error));


   // (3) Datei zum Server schicken und Antwort entgegennehmen
   string response = UploadHistoryFile(filename);


   // (4) Antwort auswerten und Rückmeldung an den User geben

   return(catch("start(7)"));
}


/**
 * Lädt die angegebene Datei per HTTP-Post-Request auf den Server und gibt die Antwort des Servers zurück.
 *
 * @param  string filename - Dateiname
 *
 * @return int - Fehlerstatus
 */
int UploadHistoryFile(string filename) {
   string url          = "\"http://sub.domain.tld/uploadAccountHistory.php\"";
   string targetDir    = TerminalPath() +"\\experts\\files";
   string dataFile     = "\""+ targetDir +"\\"+ filename +"\"";
   string responseFile = "\""+ targetDir +"\\"+ filename +".response\"";
   string logFile      = "\""+ targetDir +"\\"+ filename +".log\"";
   string lpCmdLine    = "wget.exe "+ url +" --post-file="+ dataFile +" -O "+ responseFile +" -o "+ logFile;

   //Print("UploadHistoryFile()  strLen(lpCmdLine)="+ StringLen(lpCmdLine) +": "+ lpCmdLine);
   //return(catch("UploadHistoryFile()"));

   int error = WinExec(lpCmdLine, SW_SHOWNORMAL);     // SW_SHOWNORMAL|SW_HIDE
   if (error < 32)
      return(catch("UploadHistoryFile(1)  execution of \'"+ lpCmdLine +"\' failed with error: "+ error +" ("+ WindowsErrorToStr(error) +")", ERR_WINDOWS_ERROR));

   return(catch("UploadHistoryFile(2)"));
}

