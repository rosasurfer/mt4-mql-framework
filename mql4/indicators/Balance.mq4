/**
 * Zeigt den Balance-Verlauf des Accounts als Linienchart in Indikatorfenster) an.
 */
#include <stdlib.mqh>

#property indicator_separate_window
#property indicator_buffers 1

#property indicator_color1  Blue
#property indicator_width1  2


bool init       = false;
int  init_error = ERR_NO_ERROR;

double iBufferBalance[];


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true;
   init_error = ERR_NO_ERROR;

   // ERR_TERMINAL_NOT_YET_READY abfangen
   if (!GetAccountNumber()) {
      init_error = stdlib_GetLastError();
      return(init_error);
   }

   SetIndexBuffer(0, iBufferBalance);
   SetIndexLabel (0, "Balance");
   SetIndexStyle (0, DRAW_LINE);
   IndicatorDigits(2);

   // nach Recompilation statische Arrays zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      if (Bars > 0)
         ArrayInitialize(iBufferBalance, EMPTY_VALUE);
   }

   // nach Parameteränderung sofort start() aufrufen und nicht auf den nächsten Tick warten
   if (UninitializeReason() == REASON_PARAMETERS) {
      start();
      WindowRedraw();
   }

   return(catch("init()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   //debug("start()   enter");

   static int error = ERR_NO_ERROR;

   // Trat beim letzten Aufruf ein Fehler auf, wird der Indikator neuberechnet.
   Tick++;
   ValidBars   = ifInt(error!=ERR_NO_ERROR, 0, IndicatorCounted()); error = ERR_NO_ERROR;
   ChangedBars = Bars - ValidBars;
   stdlib_onTick(ValidBars);


   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init) {                                      // Aufruf nach erstem init()
      init = false;
      if (init_error != ERR_NO_ERROR)               return(0);
   }
   else if (init_error != ERR_NO_ERROR) {           // Aufruf nach Tick
      if (init_error != ERR_TERMINAL_NOT_YET_READY) return(0);
      if (init()     != ERR_NO_ERROR)               return(0);
   }


   // Entweder alle Werte berechnen oder...
   if (ValidBars == 0) {
      error = iBalanceSeries(AccountNumber(), iBufferBalance);
      //debug("start()   leave");
      return(catch("start(1)"));
   }

   // ... nur fehlende Werte berechnen
   for (int bar=ChangedBars; bar >= 0; bar--) {
      error = iBalance(AccountNumber(), iBufferBalance, bar);
      if (error != ERR_NO_ERROR)
         break;
   }
   
   //debug("start()   leave");
   return(catch("start(2)"));
}


/**
 * Berechnet den Balanceverlauf eines Accounts für alle Bars des aktuellen Charts und schreibt die Werte in das angegebene Zielarray.
 *
 * @param  int     account  - Account-Nummer
 * @param  double& lpBuffer - Zeiger auf Ergebnisarray (kann Indikatorpuffer sein)
 *
 * @return int - Fehlerstatus
 */
int iBalanceSeries(int account, double& lpBuffer[]) {
   if (ArrayRange(lpBuffer, 0) != Bars) {
      ArrayResize(lpBuffer, Bars);
      ArrayInitialize(lpBuffer, EMPTY_VALUE);
   }

   // Balance-History holen
   datetime times[];  ArrayResize(times , 0);
   double   values[]; ArrayResize(values, 0);

   int error = GetBalanceHistory(account, times, values);   // aufsteigend nach Zeit sortiert (times[0], values[0] sind älteste Werte)
   if (error != ERR_NO_ERROR) {
      catch("iBalanceSeries(1)");
      return(error);
   }

   int bar, lastBar, historySize=ArraySize(values);

   // Balancewerte für Bars des aktuellen Charts ermitteln und ins Ergebnisarray schreiben
   for (int i=0; i < historySize; i++) {
      // Barindex des Zeitpunkts berechnen
      bar = iBarShiftNext(NULL, 0, times[i]);
      if (bar == EMPTY_VALUE)                               // ERR_HISTORY_UPDATE ?
         return(stdlib_GetLastError());
      if (bar == -1)                                        // dieser und alle folgenden Werte sind zu neu für den Chart
         break;

      // Lücken mit vorherigem Balancewert füllen
      if (bar < lastBar-1) {
         for (int z=lastBar-1; z > bar; z--) {
            lpBuffer[z] = lpBuffer[lastBar];
         }
      }

      // aktuellen Balancewert eintragen
      lpBuffer[bar] = values[i];
      lastBar = bar;
   }

   // Ergebnisarray bis zur ersten Bar mit dem letzten bekannten Balancewert füllen
   for (bar=lastBar-1; bar >= 0; bar--) {
      lpBuffer[bar] = lpBuffer[lastBar];
   }

   return(catch("iBalanceSeries(2)"));
}


/**
 * Berechnet den Balancewert eines Accounts am angegebenen Offset des aktuellen Charts und schreibt ihn in das Ergebnisarray.
 *
 * @param  int     account  - Account, für den der Wert berechnet werden soll
 * @param  double& lpBuffer - Zeiger auf Ergebnisarray (kann Indikatorpuffer sein)
 * @param  int     bar      - Barindex des zu berechnenden Wertes (Chart-Offset)
 *
 * @return int - Fehlerstatus
 */
int iBalance(int account, double& lpBuffer[], int bar) {
   // TODO: iBalance(int account, double& lpBuffer, int bar) implementieren

   // zur Zeit wird der Indikator hier noch komplett neuberechnet
   if (iBalanceSeries(account, lpBuffer) == ERR_HISTORY_UPDATE) {
      catch("iBalance(1)");
      return(ERR_HISTORY_UPDATE);
   }

   return(catch("iBalance(2)"));
}


/**
 * Schreibt die Balance-History eines Accounts in die angegebenen Ergebnisarrays (aufsteigend nach Zeitpunkt sortiert).
 *
 * @param  int       account    - Account-Nummer
 * @param  datetime& lpTimes[]  - Zeiger auf Ergebnisarray für die Zeitpunkte der Balanceänderung
 * @param  double&   lpValues[] - Zeiger auf Ergebnisarray der entsprechenden Balancewerte
 *
 * @return int - Fehlerstatus
 */
int GetBalanceHistory(int account, datetime& lpTimes[], double& lpValues[]) {
   int      cache.account[1];
   datetime cache.times[];
   double   cache.values[];

   ArrayResize(lpTimes,  0);
   ArrayResize(lpValues, 0);

   // Daten nach Möglichkeit aus dem Cache liefern       TODO: paralleles Cachen mehrerer Wertereihen ermöglichen
   if (cache.account[0] == account) {
      ArrayCopy(lpTimes , cache.times);
      ArrayCopy(lpValues, cache.values);
      log("GetBalanceHistory()   delivering "+ ArraySize(cache.times) +" cached balance values for account "+ account);
      return(catch("GetBalanceHistory(1)"));
   }

   // Cache-Miss, Balance-Daten aus Account-History auslesen
   string data[][HISTORY_COLUMNS]; ArrayResize(data, 0);
   int error = GetAccountHistory(account, data);
   if (error != ERR_NO_ERROR) {
      catch("GetBalanceHistory(2)");
      return(error);
   }

   // Balancedatensätze einlesen und auswerten (History ist nach CloseTime sortiert)
   datetime time, lastTime;
   double   balance, lastBalance;
   int n, size=ArrayRange(data, 0);

   if (size == 0)
      return(catch("GetBalanceHistory(3)"));

   for (int i=0; i<size; i++) {
      balance = StrToDouble (data[i][HC_BALANCE       ]);
      time    = StrToInteger(data[i][HC_CLOSETIMESTAMP]);

      // der erste Datensatz wird immer geschrieben...
      if (i == 0) {
         ArrayResize(lpTimes,  n+1);
         ArrayResize(lpValues, n+1);
         lpTimes [n] = time;
         lpValues[n] = balance;
         n++;                                // n: Anzahl der existierenden Ergebnisdaten => ArraySize(lpTimes)
      }
      else if (balance != lastBalance) {
         // ... alle weiteren nur, wenn die Balance sich geändert hat
         if (time == lastTime) {             // Existieren mehrere Balanceänderungen zum selben Zeitpunkt,
            lpValues[n-1] = balance;         // wird der letzte Wert nur mit dem aktuellen überschrieben.
         }
         else {
            ArrayResize(lpTimes,  n+1);
            ArrayResize(lpValues, n+1);
            lpTimes [n] = time;
            lpValues[n] = balance;
            n++;
         }
      }
      lastTime    = time;
      lastBalance = balance;
   }

   // Daten cachen
   cache.account[0] = account;
   ArrayResize(cache.times,  0); ArrayCopy(cache.times,  lpTimes );
   ArrayResize(cache.values, 0); ArrayCopy(cache.values, lpValues);
   log("GetBalanceHistory()   cached "+ ArraySize(lpTimes) +" balance values for account "+ account);

   return(catch("GetBalanceHistory(4)"));
}


/**
 * Liest die History eines Accounts aus dem Dateisystem in das angegebene Ergebnisarray ein.  Sämtliche Daten werden als String (Rohdaten) zurückgegeben.
 *
 * @param  int     account                      - Account-Nummer
 * @param  string& lpResults[][HISTORY_COLUMNS] - Zeiger auf Ergenisarray
 *
 * @return int - Fehlerstatus: ERR_CANNOT_OPEN_FILE, wenn die Datei nicht gefunden wurde
 */
int GetAccountHistory(int account, string& lpResults[][HISTORY_COLUMNS]) {
   if (ArrayRange(lpResults, 1) != HISTORY_COLUMNS)
      return(catch("GetAccountHistory(1)  invalid parameter lpResults["+ ArrayRange(lpResults, 0) +"]["+ ArrayRange(lpResults, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   int    cache.account[1];
   string cache[][HISTORY_COLUMNS];

   ArrayResize(lpResults, 0);

   // Daten nach Möglichkeit aus dem Cache liefern
   if (cache.account[0] == account) {
      ArrayCopy(lpResults, cache);
      log("GetAccountHistory()   delivering "+ ArrayRange(cache, 0) +" cached history entries for account "+ account);
      return(catch("GetAccountHistory(2)"));
   }

   // Cache-Miss, History-Datei auslesen
   string header[HISTORY_COLUMNS] = { "Ticket","OpenTime","OpenTimestamp","Description","Type","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","ExpirationTime","ExpirationTimestamp","MagicNumber","Commission","Swap","NetProfit","GrossProfit","Balance","Comment" };
   string filename = StringConcatenate(account, "/account history.csv");
   int hFile = FileOpen(filename, FILE_CSV|FILE_READ, '\t');
   if (hFile < 0)
      return(catch("GetAccountHistory(3)   FileOpen(\""+ filename +"\")"));

   string value;
   bool   newLine=true, blankLine=false, lineEnd=true;
   int    lines=0, row=-2, col=-1;
   string result[][HISTORY_COLUMNS]; ArrayResize(result, 0);   // tmp. Zwischenspeicher für ausgelesene daten

   // Daten feldweise einlesen und Zeilen erkennen
   while (!FileIsEnding(hFile)) {
      newLine = false;
      if (lineEnd) {                                           // Wenn beim letzten Durchlauf das Zeilenende erreicht wurde,
         newLine   = true;                                     // Flags auf Zeilenbeginn setzen.
         blankLine = false;
         lineEnd   = false;
         col = -1;                                             // Spaltenindex vor der ersten Spalte (erste Spalte = 0)
      }

      // nächstes Feld auslesen
      value = FileReadString(hFile);

      // auf Leerzeilen, Zeilen- und Dateiende prüfen
      if (FileIsLineEnding(hFile) || FileIsEnding(hFile)) {
         lineEnd = true;
         if (newLine) {
            if (StringLen(value) == 0) {
               if (FileIsEnding(hFile))                        // Zeilenbeginn + Leervalue + Dateiende  => nichts, also Abbruch
                  break;
               blankLine = true;                               // Zeilenbeginn + Leervalue + Zeilenende => Leerzeile
            }
         }
         lines++;
      }

      // Leerzeilen überspringen
      if (blankLine)
         continue;

      value = StringTrim(value);

      // Kommentarzeilen überspringen
      if (newLine) /*&&*/ if (StringGetChar(value, 0)==35)     // char(35) = #
         continue;

      // Zeilen- und Spaltenindex aktualisieren und Bereich überprüfen
      col++;
      if (lineEnd) /*&&*/ if (col!=HISTORY_COLUMNS-1) {
         int error = catch("GetAccountHistory(4)   data format error in \""+ filename +"\", column count in line "+ lines +" is not "+ HISTORY_COLUMNS, ERR_RUNTIME_ERROR);
         break;
      }
      if (newLine)
         row++;

      // Headerinformationen in der ersten Datenzeile überprüfen und Headerzeile überspringen
      if (row == -1) {
         if (value != header[col]) {
            error = catch("GetAccountHistory(5)   data format error in \""+ filename +"\", unexpected column header \""+ value +"\"", ERR_RUNTIME_ERROR);
            break;
         }
         continue;   // jmp
      }

      // Ergebnisarray vergrößern und Rohdaten speichern (als String)
      if (newLine)
         ArrayResize(result, row+1);
      result[row][col] = value;
   }

   // Hier haben Formatfehler ERR_RUNTIME_ERROR (bereits gemeldet) oder Dateiende END_OF_FILE ausgelöst.
   if (error == ERR_NO_ERROR) {
      error = GetLastError();
      if (error == ERR_END_OF_FILE) {
         error = ERR_NO_ERROR;
      }
      else {
         catch("GetAccountHistory(6)", error);
      }
   }

   // vor evt. Fehler-Rückkehr auf jeden Fall Datei schließen
   FileClose(hFile);

   if (error != ERR_NO_ERROR)    // ret
      return(error);


   // Daten in Zielarray kopieren und cachen
   if (ArrayRange(result, 0) > 0) {       // "leere" Historydaten nicht cachen (falls Datei noch erstellt wird)
      ArrayCopy(lpResults, result);

      cache.account[0] = account;
      ArrayResize(cache, 0); ArrayCopy(cache, result);
      log("GetAccountHistory()   cached "+ ArrayRange(cache, 0) +" history entries for account "+ account);
   }

   return(catch("GetAccountHistory(7)"));
}