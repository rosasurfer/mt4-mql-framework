/**
 * UpdateRemoteAccountHistory
 *
 * Aktualisiert die entfernte Server-Accounthistory. Außer gestrichenen Pending-Orders werden alle Daten übertragen.
 * Die Auswertung und Zuordnung erfolgt auf dem Server.
 *
 *
 *
 */
#include <stdlib.mqh>


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
   // ------------------------


   int account = AccountNumber();
   if (account == 0) {
      log("start()  no trade server connection");
      PlaySound("notify.wav");
      MessageBox("No trade server connection.", __SCRIPT__, MB_ICONEXCLAMATION|MB_OK);
      return(ERR_NO_CONNECTION);
   }

   // (1) verfügbare Historydaten einlesen
   int orders = OrdersHistoryTotal();

   int      tickets     []; ArrayResize(tickets,      orders);
   int      types       []; ArrayResize(types,        orders);
   string   symbols     []; ArrayResize(symbols,      orders);
   int      units       []; ArrayResize(units,        orders);
   datetime openTimes   []; ArrayResize(openTimes,    orders);
   datetime closeTimes  []; ArrayResize(closeTimes,   orders);
   double   openPrices  []; ArrayResize(openPrices,   orders);
   double   closePrices []; ArrayResize(closePrices,  orders);
   double   commissions []; ArrayResize(commissions,  orders);
   double   swaps       []; ArrayResize(swaps,        orders);
   double   profits     []; ArrayResize(profits,      orders);
   int      magicNumbers[]; ArrayResize(magicNumbers, orders);
   string   comments    []; ArrayResize(comments,     orders);

   int n;

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))           // FALSE: während des Auslesens wird der Anzeigezeitraum der History verändert
         break;
      int type = OrderType();                                     // gecancelte Orders überspringen
      if (type==OP_BUYLIMIT || type==OP_SELLLIMIT || type==OP_BUYSTOP || type==OP_SELLSTOP)
         continue;

      tickets[n] = OrderTicket();
      types  [n] = type;
      symbols[n] = OrderSymbol();
         if (symbols[n] == "")
            units[n]= 0;
         else {
            symbols[n]  = GetStandardSymbol(OrderSymbol());       // möglichst das Standardsymbol verwenden
            int lotSize = MarketInfo(OrderSymbol(), MODE_LOTSIZE);
            int error = GetLastError();
            if (error == ERR_UNKNOWN_SYMBOL) {
               log("start()  MarketInfo("+ OrderSymbol() +") - unknown symbol");
               PlaySound("notify.wav");
               MessageBox("Add \""+ OrderSymbol() +"\" to the Market Watch window !", __SCRIPT__, MB_ICONEXCLAMATION|MB_OK);
               return(error);
            }
            if (error != NO_ERROR)
               return(catch("start(1)", error));
            units[n] = OrderLots() * lotSize;
         }
      openTimes   [n] = OrderOpenTime();
      closeTimes  [n] = OrderCloseTime();
      openPrices  [n] = OrderOpenPrice();
      closePrices [n] = OrderClosePrice();
      commissions [n] = OrderCommission();
      swaps       [n] = OrderSwap();
      profits     [n] = OrderProfit();
      magicNumbers[n] = OrderMagicNumber();
      comments    [n] = StringTrim(StringReplace(StringReplace(OrderComment(), "\n", " "), "\t", " "));
      n++;
   }

   // Arrays justieren
   if (n < orders) {
      ArrayResize(tickets,     n);
      ArrayResize(types,       n);
      ArrayResize(symbols,     n);
      ArrayResize(units,       n);
      ArrayResize(openTimes,   n);
      ArrayResize(closeTimes,  n);
      ArrayResize(openPrices,  n);
      ArrayResize(closePrices, n);
      ArrayResize(commissions, n);
      ArrayResize(swaps,       n);
      ArrayResize(profits,     n);
      ArrayResize(magicNumbers,n);
      ArrayResize(comments,    n);
      orders = n;
   }


   // (2) CSV-Datei schreiben
   string filename = ShortAccountCompany() +"\\tmp_"+ WindowExpertName() +".txt";
   int hFile = FileOpen(filename, FILE_CSV|FILE_WRITE, '\t');
   if (hFile < 0)
      return(catch("start(2)  FileOpen(filename=\""+ filename +"\")"));

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
   if (FileWrite(hFile, "\n[Data]\n#Ticket","OpenTime","OpenTimestamp","Description","Type","Units","Symbol","OpenPrice","CloseTime","CloseTimestamp","ClosePrice","Commission","Swap","Profit","MagicNumber","Comment") < 0) {
      error = GetLastError();
      FileClose(hFile);
      return(catch("start(6)  FileWrite()", error));
   }
   for (i=0; i < orders; i++) {
      string strType        = OperationTypeDescription(types[i]);

      string strOpenTime    = TimeToStr(openTimes [i], TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      string strCloseTime   = TimeToStr(closeTimes[i], TIME_DATE|TIME_MINUTES|TIME_SECONDS);

      string strOpenPrice   = ifString(openPrices [i]==0, "", NumberToStr(openPrices [i], ".2+"));
      string strClosePrice  = ifString(closePrices[i]==0, "", NumberToStr(closePrices[i], ".2+"));

      string strCommission  = DoubleToStr(commissions[i], 2);
      string strSwap        = DoubleToStr(swaps      [i], 2);
      string strProfit      = DoubleToStr(profits    [i], 2);

      string strMagicNumber = ifString(magicNumbers[i]==0, "", magicNumbers[i]);

      if (FileWrite(hFile, tickets[i],strOpenTime,openTimes[i],strType,types[i],units[i],symbols[i],strOpenPrice,strCloseTime,closeTimes[i],strClosePrice,strCommission,strSwap,strProfit,strMagicNumber,comments[i]) < 0) {
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
   string errorMsg = "";
   int result = UploadDataFile(filename, errorMsg);

   if (result >= ERR_RUNTIME_ERROR) {        // bei Fehler Rückkehr
      error = catch("start(9)");
      if (error == NO_ERROR)
         error = ERR_RUNTIME_ERROR;
      return(error);
   }


   // (4) Antwort auswerten und Rückmeldung an den User geben
   if (result==200 || result==201) {
      PlaySound("ding.wav");
      MessageBox(ifString(result==200, "History is up to date.", "History successfully updated."), __SCRIPT__, MB_ICONINFORMATION|MB_OK);
   }
   else {
      PlaySound("notify.wav");
      MessageBox(ifString(errorMsg=="", "error "+ result, errorMsg), __SCRIPT__, MB_ICONEXCLAMATION|MB_OK);
   }

   return(catch("start(10)"));
}


/**
 * Lädt die angegebene Datei per HTTP-Post-Request auf den Server und gibt die Antwort des Servers zurück.
 *
 * @param  string  filename   - Dateiname, relativ zu "{terminal-directory}\experts\files"
 * @param  string& lpErrorMsg - Zeiger auf einen String zur Aufnahme einer Fehlermeldung
 *
 * @return int - Serverresponse-Code (< ERR_RUNTIME_ERROR) oder MQL-Fehlerstatus (>= ERR_RUNTIME_ERROR)
 */
int UploadDataFile(string filename, string& lpErrorMsg) {
   // Befehlszeile für Shellaufruf zusammensetzen
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
   string response[];
   if (FileReadLines(filename +".response", response, false) == -1)           // FileReadLines() erwartet relativen Pfad
      return(ERR_RUNTIME_ERROR);

   // Serverantwort auswerten
   int errorCode, lines = ArraySize(response);
   if (lines == 0) {
      errorCode  = 500;
      lpErrorMsg = "Server error, try again later.";
   }
   else {
      string values[];
      Explode(response[0], ":", values, NULL);
      string strErrorCode = StringTrim(values[0]);

      if (StringIsDigit(strErrorCode)) {
         errorCode = StrToInteger(strErrorCode);
         if (ArraySize(values) > 1) lpErrorMsg = StringTrim(values[1]);
         else                       lpErrorMsg = "";                          // keine Meldung, nur der Code
      }
      else {
         errorCode  = 500;
         lpErrorMsg = "Server error, try again later.";
      }
   }
   //log("UploadDataFile()   result = "+ errorCode +"   msg = \""+ lpErrorMsg +"\"");

   int error = catch("UploadDataFile()");
   if (error != NO_ERROR)
      return(error);
   return(errorCode);
}
