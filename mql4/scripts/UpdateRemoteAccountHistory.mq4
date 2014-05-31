/**
 * Aktualisiert die entfernte Server-Accounthistory. Außer gestrichenen Pending-Orders werden alle Daten übertragen.
 * Die Auswertung und Zuordnung erfolgt auf dem Server.
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
   if (!account)
      return(HandleScriptError("", "No trade server connection.", ERR_NO_CONNECTION));

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
      if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))           // FALSE: während des Auslesens wurde der Anzeigezeitraum der History verändert
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
               if (__LOG) log("onStart(1)   MarketInfo("+ OrderSymbol() +") - unknown symbol");
               PlaySound("notify.wav");
               MessageBox("Add \""+ OrderSymbol() +"\" to the \"Market Watch\" window !", __NAME__, MB_ICONEXCLAMATION|MB_OK);
               return(SetLastError(error));
            }
            if (IsError(error))
               return(catch("onStart(2)", error));
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
      comments    [n] = OrderComment();
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
   string filename = ShortAccountCompany() +"\\tmp_"+ __NAME__ +".txt";
   int hFile = FileOpen(filename, FILE_CSV|FILE_WRITE, '\t');
   if (hFile < 0)
      return(catch("onStart(3)->FileOpen(\""+ filename +"\")"));

   // (2.1) Dateikommentar
   string header = "# Account history update for account #"+ account +" ("+ AccountCompany() +") - "+ AccountName() +"\n#";
   if (FileWrite(hFile, header) < 0) {
      catch("onStart(4)->FileWrite()");
      FileClose(hFile);
      return(last_error);
   }

   // (2.2) Status
   if (FileWrite(hFile, "\n[Account]\n#AccountCompany","AccountNumber","AccountBalance") < 0) {
      catch("onStart(5)->FileWrite()");
      FileClose(hFile);
      return(last_error);
   }
   string accountCompany = AccountCompany();
   string accountNumber  = GetAccountNumber();
   string accountBalance = NumberToStr(AccountBalance(), ".2+");

   if (FileWrite(hFile, accountCompany,accountNumber,accountBalance) < 0) {
      catch("onStart(6)->FileWrite()");
      FileClose(hFile);
      return(last_error);
   }

   // (2.2) Daten
   if (FileWrite(hFile, "\n[Data]\n#Ticket","OpenTime","OpenTimestamp","Description","Type","Units","Symbol","OpenPrice","CloseTime","CloseTimestamp","ClosePrice","Commission","Swap","Profit","MagicNumber","Comment") < 0) {
      catch("onStart(7)->FileWrite()");
      FileClose(hFile);
      return(last_error);
   }
   for (i=0; i < orders; i++) {
      string strType        = OperationTypeDescription(types[i]);

      string strOpenTime    = TimeToStr(openTimes [i], TIME_FULL);
      string strCloseTime   = TimeToStr(closeTimes[i], TIME_FULL);

      string strOpenPrice   = ifString(!openPrices [i], "", NumberToStr(openPrices [i], ".2+"));
      string strClosePrice  = ifString(!closePrices[i], "", NumberToStr(closePrices[i], ".2+"));

      string strCommission  = DoubleToStr(commissions[i], 2);
      string strSwap        = DoubleToStr(swaps      [i], 2);
      string strProfit      = DoubleToStr(profits    [i], 2);

      string strMagicNumber = ifString(!magicNumbers[i], "", magicNumbers[i]);

      if (FileWrite(hFile, tickets[i],strOpenTime,openTimes[i],strType,types[i],units[i],symbols[i],strOpenPrice,strCloseTime,closeTimes[i],strClosePrice,strCommission,strSwap,strProfit,strMagicNumber,comments[i]) < 0) {
         catch("onStart(8)->FileWrite()");
         FileClose(hFile);
         return(last_error);
      }
   }

   // (2.3) Datei schließen
   FileClose(hFile);
   error = GetLastError();
   if (IsError(error))
      return(catch("onStart(9)->FileClose()", error));


   // (3) Datei zum Server schicken und Antwort entgegennehmen
   string errorMsg = "";
   int result = UploadDataFile(filename, errorMsg);

   if (result >= ERR_RUNTIME_ERROR) {        // bei Fehler Rückkehr
      error = catch("onStart(10)");
      if (!error)
         error = ERR_RUNTIME_ERROR;
      return(SetLastError(error));
   }


   // (4) Antwort auswerten und Rückmeldung an den User geben
   if (result==200 || result==201) {
      PlaySound("ding.wav");
      MessageBox(ifString(result==200, "History is up-to-date.", "History successfully updated."), __NAME__, MB_ICONINFORMATION|MB_OK);
   }
   else {
      PlaySound("notify.wav");
      MessageBox(ifString(errorMsg=="", "error "+ result, errorMsg), __NAME__, MB_ICONEXCLAMATION|MB_OK);
   }


   ArrayResize(tickets,      0);
   ArrayResize(types,        0);
   ArrayResize(symbols,      0);
   ArrayResize(units,        0);
   ArrayResize(openTimes,    0);
   ArrayResize(closeTimes,   0);
   ArrayResize(openPrices,   0);
   ArrayResize(closePrices,  0);
   ArrayResize(commissions,  0);
   ArrayResize(swaps,        0);
   ArrayResize(profits,      0);
   ArrayResize(magicNumbers, 0);
   ArrayResize(comments,     0);

   return(last_error);
}


/**
 * Lädt die angegebene Datei per HTTP-Post-Request auf den Server und gibt die Antwort des Servers zurück.
 *
 * @param  string  filename   - Dateiname relativ zu ".\experts\files\"
 * @param  string &lpErrorMsg - Zeiger auf einen String zur Aufnahme einer Fehlermeldung
 *
 * @return int - Serverresponse-Code (< ERR_RUNTIME_ERROR) oder MQL-Fehlerstatus (>= ERR_RUNTIME_ERROR)
 */
int UploadDataFile(string filename, string &lpErrorMsg) {
   // Befehlszeile für Shellaufruf zusammensetzen
   string url          = "http://sub.domain.tld/uploadAccountHistory.php";
   string filesDir     = TerminalPath() +"\\experts\\files";
   string dataFile     = filesDir +"\\"+ filename;
   string responseFile = filesDir +"\\"+ filename +".response";
   string logFile      = filesDir +"\\"+ filename +".log";
   string cmdLine      = "wget.exe \""+ url +"\" --post-file=\""+ dataFile +"\" --header=\"Content-Type: text/plain\" -O \""+ responseFile +"\" -o \""+ logFile +"\"";

   // HTTP-Request absetzen
   if (WinExecAndWait(cmdLine, SW_HIDE) != NO_ERROR)                          // SW_SHOWNORMAL|SW_HIDE
      return(SetLastError(ERR_RUNTIME_ERROR));

   // Serverantwort zeilenweise einlesen
   string response[], values[];
   if (FileReadLines(filename +".response", response, false) == -1)           // FileReadLines() erwartet relativen Pfad
      return(SetLastError(ERR_RUNTIME_ERROR));

   // Serverantwort auswerten
   int errorCode, lines = ArraySize(response);
   if (!lines) {
      errorCode  = 500;
      lpErrorMsg = "Server error, try again later.";
   }
   else {
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
   //if (__LOG) log("UploadDataFile(1)   result = "+ errorCode +"   msg = \""+ lpErrorMsg +"\"");


   ArrayResize(response, 0);
   ArrayResize(values,   0);

   if (!catch("UploadDataFile(2)"))
      return(errorCode);
   return(last_error);
}
