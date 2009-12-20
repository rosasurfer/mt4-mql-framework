/**
 * Zeichnet den Balance-Verlauf des Accounts (als Vorstufe zum Equity-Indikator).
 */

#include <stdlib.mqh>


#property indicator_separate_window

#property indicator_buffers 1
#property indicator_color1  Blue
#property indicator_width1  1


double Balance[];


/**
 *
 */
int init() {
   SetIndexBuffer(0, Balance);
   SetIndexLabel (0, "Balance");
   SetIndexStyle (0, DRAW_LINE);

   IndicatorDigits(2);

   return(catch("init()"));
}


/**
 *
 */
int start() {
   ArrayInitialize(Balance, EMPTY_VALUE);

   // Zeitreihen mit Balance-Werten holen
   datetime times[];
   double   values[];

   GetBalanceData(times, values);
   int bar, firstBar, size=ArrayRange(times, 0);

   // Balance-Werte in Indikator eintragen...
   for (int i=0; i<size; i++) {
      bar = iBarShift(NULL, 0, times[i]);
      if (i == 0)
         firstBar = bar;
      Balance[bar] = values[i];
   }
   
   // ... und Lücken ohne Balanceänderung füllen
   double lastBalance = values[0];

   for (i=firstBar; i>=0; i--) {
      if (Balance[i] == EMPTY_VALUE)
         Balance[i] = lastBalance;
      lastBalance = Balance[i];
   }

   

   return(catch("start()"));
}


/**
 *
 */
int GetBalanceData(datetime& times[], double& values[]) {
   // Header-Werte und Array-Indizes definieren
   string header[21] = { "Ticket","OpenTime","OpenTimestamp","Type","TypeNum","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","Commission","Swap","NetProfit","GrossProfit","ExpirationTime","ExpirationTimestamp","MagicNumber","Comment" };

   int TICKET              =  0,
       OPENTIME            =  1,
       OPENTIMESTAMP       =  2,
       TYPE                =  3,
       TYPENUM             =  4,
       SIZE                =  5,
       SYMBOL              =  6,
       OPENPRICE           =  7,
       STOPLOSS            =  8,
       TAKEPROFIT          =  9,
       CLOSETIME           = 10,
       CLOSETIMESTAMP      = 11,
       CLOSEPRICE          = 12,
       COMMISSION          = 13,
       SWAP                = 14,
       NETPROFIT           = 15,
       GROSSPROFIT         = 16,
       EXPIRATIONTIME      = 17,
       EXPIRATIONTIMESTAMP = 18,
       MAGICNUMBER         = 19,
       COMMENT             = 20;


   // Rohdaten der Account-History holen
   string data[][21];
   GetRawHistoryData(data);


   double profits[][2], profit;
   int n=0, size=ArrayRange(data, 0);
  
   // Profitdatensätze auslesen
   for (int i=0; i<size; i++) {
      if (StrToInteger(data[i][TYPENUM]) != OP_CREDIT) { // credit lines ignorieren

         profit = StrToDouble(data[i][GROSSPROFIT]);

         if (profit != 0.0) {
            ArrayResize(profits, n+1);
            profits[n][0] = StrToInteger(data[i][CLOSETIMESTAMP]);
            profits[n][1] = profit;
            n++;
         }
      }
   }

   // Profitdatensätze nach CloseTime sortieren und Größe der Zielarrays anpassen
   ArraySort(profits);
   size = ArrayRange(profits, 0);
   ArrayResize(times, size);
   ArrayResize(values, size);


   // Balance-Werte berechnen und Ergebnisse in Zielarrays schreiben
   double balance = 0.00;

   for (i=0; i<size; i++) {
      balance += profits[i][1];

      times [i] = profits[i][0];
      values[i] = balance;
   }

   return(catch("GetBalanceData()"));
}


/**
 * Liest die Account-History aus dem Dateisystem in das übergebene Zielarray ein.  Alle gelesenen Werte werden als Strings (Rohdaten) zurückgegeben.
 *
 * @param string& data[][21] - Zeiger auf ein zweidimensionales Zielarray zur Aufnahme der gelesenen Daten
 *
 * @return int - 0 bei Erfolg, andererseits ein entsprechender Fehler-Code
 */
int GetRawHistoryData(string& data[][]) {
   if (ArrayRange(data, 1) != 21)
      return(catch("GetRawHistoryData(), invalid array parameter: array["+ ArrayRange(data, 0) +"]["+ ArrayRange(data, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   int tick = GetTickCount();

   string header[21] = { "Ticket","OpenTime","OpenTimestamp","Type","TypeNum","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","Commission","Swap","NetProfit","GrossProfit","ExpirationTime","ExpirationTimestamp","MagicNumber","Comment" };
   int error;


   // Datei öffnen
   string filename = AccountNumber() +"/account history.csv";
   int handle = FileOpen(filename, FILE_CSV|FILE_READ, '\t');
   if (handle < 0) {
      //error = GetLastError(); if (error == ERR_CANNOT_OPEN_FILE) {}
      return(catch("GetRawHistoryData(), FileOpen(filename="+ filename +")"));
   }

   string value;
   bool   newLine=true, blankLine=false, lineEnd=true, comment=false;
   int    lines=0, row=-2, col=-1;


   // Daten auslesen
   while (!FileIsEnding(handle)) {
      newLine = false;

      if (lineEnd) {             // Wenn im letzten Durchlauf das Zeilenende erreicht wurde,
         newLine   = true;       // Flags auf Zeilenbeginn setzen.
         lineEnd   = false;
         comment   = false;
         blankLine = false;
         col = -1;               // Spaltenindex vor der ersten Spalte
      }

      value = FileReadString(handle);

      if (FileIsLineEnding(handle) || FileIsEnding(handle)) {
         lineEnd = true;

         if (newLine && StringLen(value)==0) {
            if (FileIsEnding(handle))     // Zeilenbeginn, Leervalue und Dateiende => keine Zeile (nichts), also Abbruch
               break;

            // Zeilenbeginn, Leervalue und Zeilenende => Leerzeile
            blankLine = true;
         }
         lines++;
      }

      // Leerzeilen überspringen
      if (blankLine)
         continue;


      value = StringTrimLeft(StringTrimRight(value));


      // Kommentarzeilen überspringen
      if (newLine) {
         if (StringGetChar(value, 0) == 35)  // char code 35: #
            comment = true;
      }
      if (comment)
         continue;


      // Zeilen- und Spaltenindex aktualisieren und Bereich überprüfen
      col++;
      if (lineEnd && col < 20 || col > 20) {
         Alert("GetRawHistoryData(): Data format error in file \"", filename, "\", column count in line ", lines, " is not 21");
         error = ERR_SOME_FILE_ERROR;
         break;
      }
      if (newLine)
         row++;

      // Headerinformationen in der ersten Datenzeile überprüfen und Headerzeile überspringen
      if (row == -1) {
         if (value != header[col]) {
            Alert("GetRawHistoryData(): Data format error in file \"", filename, "\", unexpected column header \"", value, "\"");
            error = ERR_SOME_FILE_ERROR;
            break;
         }
         continue;
      }


      // Datenarray vergrößern und Rohdaten speichern (alle als String)
      if (newLine)
         ArrayResize(data, row+1);
      data[row][col] = value;
   }

   // END_OF_FILE Error zurücksetzen
   error = GetLastError();
   if (error != ERR_END_OF_FILE)
      catch("GetRawHistoryData(1)", error);

   // Datei schließen
   FileClose(handle);


   Print("Read history file, data rows: ", row+1, ", used time: ", GetTickCount()-tick, " ms");


   if (error != ERR_NO_ERROR)
      return(error);
   return(catch("GetRawHistoryData(2)"));
}


/**
 *
 */
int deinit() {
   return(catch("deinit()"));
}