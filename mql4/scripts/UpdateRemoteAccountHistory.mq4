/**
 * UpdateRemoteAccountHistory
 *
 * Aktualisiert die entfernte Server-Accounthistory. Außer gestrichenen Pending-Orders werden alle Daten übertragen.
 * Die Auswertung und Zuordnung erfolgt auf dem Server
 */
#include <stdlib.mqh>
#include <win32api.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   int account = AccountNumber();
   if (account == 0) {
      log("start()  no trade server connection");
      PlaySound("notify.wav");
      MessageBox("No trade server connection.", WindowExpertName(), MB_ICONEXCLAMATION|MB_OK);
      return(ERR_NO_CONNECTION);
   }

   // (1) verfügbare Historydaten einlesen
   int orders = OrdersHistoryTotal();

   int      tickets        []; ArrayResize(tickets,         orders);
   int      types          []; ArrayResize(types,           orders);
   string   symbols        []; ArrayResize(symbols,         orders);
   int      units          []; ArrayResize(units,           orders);
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

   int n;

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))     // FALSE ist rein theoretisch: während des Auslesens ändert sich die Zahl der Orderdatensätze
         break;
      int type = OrderType();                               // gecancelte Orders überspringen
      if (type==OP_BUYLIMIT || type==OP_SELLLIMIT || type==OP_BUYSTOP || type==OP_SELLSTOP)
         continue;

      tickets        [n] = OrderTicket();
      types          [n] = type;
      symbols        [n] = OrderSymbol();
         if (symbols[n] == "")
            units[n]= 0;
         else {                                             // broker-spezifische Symbole normalisieren
            symbols[n]  = FindNormalizedSymbol(OrderSymbol(), OrderSymbol());
            int lotSize = MarketInfo(OrderSymbol(), MODE_LOTSIZE);
            int error = GetLastError();
            if (error == ERR_UNKNOWN_SYMBOL) {
               log("start()  MarketInfo("+ OrderSymbol() +") - unknown symbol");
               PlaySound("notify.wav");
               MessageBox("Add \""+ OrderSymbol() +"\" to the market watch window !", WindowExpertName(), MB_ICONEXCLAMATION|MB_OK);
               return(error);
            }
            if (error != NO_ERROR)
               return(catch("start(1)", error));
            units[n] = OrderLots() * lotSize;
         }
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
      comments       [n] = StringTrim(StringReplace(StringReplace(OrderComment(), "\n", " "), "\t", " "));
      n++;
   }

   // Arrays justieren
   if (n < orders) {
      ArrayResize(tickets,         n);
      ArrayResize(types,           n);
      ArrayResize(symbols,         n);
      ArrayResize(units,           n);
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
   string filename = GetAccountDirectory(account) +"\\tmp_"+ WindowExpertName() +".txt";
   int hFile = FileOpen(filename, FILE_CSV|FILE_WRITE, '\t');
   if (hFile < 0)
      return(catch("start(2)  FileOpen()"));

   // (2.1) Dateikommentar
   string header = "# Account history update for account #"+ account +" ("+ AccountCompany() +") - "+ AccountName() +"\n#";
   if (FileWrite(hFile, header) < 0) {
      error = GetLastError();
      FileClose(hFile);
      return(catch("start(3)  FileWrite()", error));
   }

   // (2.2) Status
   if (FileWrite(hFile, "\n[Account]\n#AccountCompany","AccountNumber","AccountBalance") < 0) {
      error = GetLastError();
      FileClose(hFile);
      return(catch("start(4)  FileWrite()", error));
   }
   string accountCompany = AccountCompany();
   string accountNumber  = AccountNumber();
   string accountBalance = NumberToStr(AccountBalance(), ".2+");

   if (FileWrite(hFile, accountCompany,accountNumber,accountBalance) < 0) {
      error = GetLastError();
      FileClose(hFile);
      return(catch("start(5)  FileWrite()", error));
   }

   // (2.2) Daten
   if (FileWrite(hFile, "\n[Data]\n#Ticket","OpenTime","OpenTimestamp","Description","Type","Units","Symbol","OpenPrice","StopLoss","TakeProfit","ExpirationTime","ExpirationTimestamp","CloseTime","CloseTimestamp","ClosePrice","Commission","Swap","Profit","MagicNumber","Comment") < 0) {
      error = GetLastError();
      FileClose(hFile);
      return(catch("start(6)  FileWrite()", error));
   }
   for (i=0; i < orders; i++) {
      string strType         = OperationTypeToStr(types[i]);

      string strOpenTime     = TimeToStr(openTimes [i], TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      string strCloseTime    = TimeToStr(closeTimes[i], TIME_DATE|TIME_MINUTES|TIME_SECONDS);

      string strOpenPrice    = ifString(openPrices [i]==0, "", NumberToStr(openPrices [i], ".2+"));
      string strStopLoss     = ifString(stopLosses [i]==0, "", NumberToStr(stopLosses [i], ".2+"));
      string strTakeProfit   = ifString(takeProfits[i]==0, "", NumberToStr(takeProfits[i], ".2+"));
      string strClosePrice   = ifString(closePrices[i]==0, "", NumberToStr(closePrices[i], ".2+"));

      string strExpTime      = ifString(expirationTimes[i]==0, "", TimeToStr(expirationTimes[i], TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      string strExpTimestamp = ifString(expirationTimes[i]==0, "", expirationTimes[i]);

      string strCommission   = DoubleToStr(commissions[i], 2);
      string strSwap         = DoubleToStr(swaps      [i], 2);
      string strProfit       = DoubleToStr(profits    [i], 2);

      string strMagicNumber  = ifString(magicNumbers[i]==0, "", magicNumbers[i]);

      if (FileWrite(hFile, tickets[i],strOpenTime,openTimes[i],strType,types[i],units[i],symbols[i],strOpenPrice,strStopLoss,strTakeProfit,strExpTime,strExpTimestamp,strCloseTime,closeTimes[i],strClosePrice,strCommission,strSwap,strProfit,strMagicNumber,comments[i]) < 0) {
         error = GetLastError();
         FileClose(hFile);
         return(catch("start(7)  FileWrite()", error));
      }
   }

   // (2.3) Datei schließen
   FileClose(hFile);
   error = GetLastError();
   if (error != NO_ERROR)
      return(catch("start(8)  FileClose()", error));


   // (3) Datei zum Server schicken und Antwort entgegennehmen
   string response[];
   int result = UploadDataFile(filename, response);

   if (result >= ERR_RUNTIME_ERROR) {        // bei Fehler Rückkehr
      error = catch("start(9)");
      if (error == NO_ERROR)
         error = ERR_RUNTIME_ERROR;
      return(error);
   }


   // (4) Antwort auswerten und Rückmeldung an den User geben
   if (result == 200) {
      PlaySound("ding.wav");
      MessageBox("UploadDataFile()\nresult = "+ result, WindowExpertName(), MB_ICONINFORMATION|MB_OK);
   }
   else {
      if (ArraySize(response) > 0) {
         string message = StringTrim(response[0]);
         if (StringLen(message) == 0)
            message = "result = "+ result;
      }
      else  message = "result = "+ result;
      PlaySound("notify.wav");
      MessageBox("UploadDataFile()\nerror "+ message, WindowExpertName(), MB_ICONEXCLAMATION|MB_OK);
   }

   return(catch("start(10)"));
}


/**
 * Lädt die angegebene Datei per HTTP-Post-Request auf den Server und gibt die Antwort des Servers zurück.
 *
 * @param  string  filename   - Dateiname, relativ zu "{terminal-directory}\experts\files"
 * @param  string& lpResponse - Zeiger auf ein Array zur Aufnahme der zeilenweisen Serverantwort
 *
 * @return int - Serverresponse-Code (< ERR_RUNTIME_ERROR) oder MQL-Fehlerstatus (>= ERR_RUNTIME_ERROR)
 */
int UploadDataFile(string filename, string& lpResponse[]) {
   // Command-Line zusammensetzen
   string url          = "http://sub.domain.tld/uploadAccountHistory.php";
   string filesDir     = TerminalPath() +"\\experts\\files";
   string dataFile     = filesDir +"\\"+ filename;
   string responseFile = filesDir +"\\"+ filename +".response";
   string logFile      = filesDir +"\\"+ filename +".log";
   string cmdLine      = "wget.exe \""+ url +"\" --post-file=\""+ dataFile +"\" --header=\"Content-Type: text/plain\" -O \""+ responseFile +"\" -o \""+ logFile +"\"";

   // HTTP-Request absetzen
   if (WinExecAndWait(cmdLine, SW_HIDE) != NO_ERROR)                          // SW_SHOWNORMAL|SW_HIDE
      return(ERR_RUNTIME_ERROR);

   // Serverantwort zeilenweise einlesen
   if (FileReadLines(filename +".response", lpResponse, false) != NO_ERROR)   // FileReadLines() erwartet relativen Pfad
      return(ERR_RUNTIME_ERROR);

   // Serverantwort auswerten
   int resultCode, lines = ArraySize(lpResponse);
   if (lines == 0) {
      resultCode = 500;                                                       // Server-Error
   }
   else {
      string values[];
      Explode(lpResponse[0], ":", values);
      string strCode = StringTrim(values[0]);
      if (StringIsDigit(strCode)) resultCode = StrToInteger(strCode);
      else                        resultCode = 500;                           // Server-Error
   }
   //log("UploadDataFile()   result code = "+ resultCode);

   int error = catch("UploadDataFile()");
   if (error != NO_ERROR)
      return(error);
   return(resultCode);
}
