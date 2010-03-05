/**
 * stdlib.mq4
 */

#property library


#include <stddefine.mqh>
#include <win32api.mqh>


/**
 * Prüft, ob seit dem letzten Aufruf ein Event des angegebenen Typs aufgetreten ist.
 *
 * @param int  event     - Event
 * @param int& results[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param int  flags     - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool CheckEvent(int event, int& results[], int flags=0) {
   switch (event) {
      case EVENT_BAR_OPEN       : return(CheckEvent.BarOpen       (results, flags));
      case EVENT_ORDER_PLACE    : return(CheckEvent.OrderPlace    (results, flags));
      case EVENT_ORDER_CHANGE   : return(CheckEvent.OrderChange   (results, flags));
      case EVENT_ORDER_CANCEL   : return(CheckEvent.OrderCancel   (results, flags));
      case EVENT_POSITION_OPEN  : return(CheckEvent.PositionOpen  (results, flags));
      case EVENT_POSITION_CLOSE : return(CheckEvent.PositionClose (results, flags));
      case EVENT_ACCOUNT_PAYMENT: return(CheckEvent.AccountPayment(results, flags));
      case EVENT_HISTORY_CHANGE : return(CheckEvent.HistoryChange (results, flags));
   }
   catch("CheckEvent()  invalid parameter event: "+ event, ERR_INVALID_FUNCTION_PARAMVALUE);
   return(false);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein BarOpen-Event aufgetreten ist.  Das Event bezieht sich immer auf den aktuellen Chart.
 *
 * @param int& results[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param int  flags     - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool CheckEvent.BarOpen(int& results[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(results) > 0)
      ArrayResize(results, 0);

   //Print("CheckEvent.BarOpen()  eventStatus: "+ eventStatus);
   catch("CheckEvent.BarOpen()");
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein OrderPlace-Event aufgetreten ist.
 *
 * @param int& results[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param int  flags     - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool CheckEvent.OrderPlace(int& results[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(results) > 0)
      ArrayResize(results, 0);

   //Print("CheckEvent.OrderPlace()  eventStatus: "+ eventStatus);
   catch("CheckEvent.OrderPlace()");
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein OrderChange-Event aufgetreten ist.
 *
 * @param int& results[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param int  flags     - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool CheckEvent.OrderChange(int& results[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(results) > 0)
      ArrayResize(results, 0);

   //Print("CheckEvent.OrderChange()  eventStatus: "+ eventStatus);
   catch("CheckEvent.OrderChange()");
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein OrderCancel-Event aufgetreten ist.
 *
 * @param int& results[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param int  flags     - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool CheckEvent.OrderCancel(int& results[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(results) > 0)
      ArrayResize(results, 0);

   //Print("CheckEvent.OrderCancel()  eventStatus: "+ eventStatus);
   catch("CheckEvent.OrderCancel()");
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein PositionOpen-Event aufgetreten ist.
 *
 * @param int& results[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param int  flags     - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool CheckEvent.PositionOpen(int& results[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(results) > 0)
      ArrayResize(results, 0);

   //Print("CheckEvent.PositionOpen()  eventStatus: "+ eventStatus);
   catch("CheckEvent.PositionOpen()");
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein PositionClose-Event aufgetreten ist.
 *
 * @param int& results[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param int  flags     - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool CheckEvent.PositionClose(int& results[], int flags=0) {
   // TODO:
   // Tritt auf, wenn eine offene Position während der Programmausführung verschwindet.  Kann auch beim Programmstart auftreten, wenn seit dem letzten Start
   // neue Positionen geöffnet UND geschlossen wurden.  Da die offenen Positionen in diesem Fall unbekannt waren, muß beim Programmstart die Online-History
   // einmal auf neue geschlossene Positionen geprüft werden.  Programmstart-übergreifend wird dafür die letzte geschlossene Position gespeichert.
   if (ArraySize(results) > 0)
      ArrayResize(results, 0);

   static bool firstRun = true;

   bool eventStatus = false;

   int  tickets[], n, positions=ArraySize(tickets);
   // wenn eine der vorher offenen Positionen verschwindet, kann sie nur geschlossen sein
   for (int i=0; i < positions; i++) {
      if (!OrderSelect(tickets[i], SELECT_BY_TICKET, MODE_TRADES)) {
         eventStatus = true;
         n++;
         ArrayResize(results, n);
         results[n-1] = tickets[i];    // Ticket im Ergebnisarray speichern
      }
   }
   // offene Positionen für nächsten Aufruf speichern
   ArrayResize(tickets, 0);
   n = 0;
   positions = OrdersTotal();

   for (i=0; i < positions; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         break;   // OrdersTotal() hat sich während der Ausführung geändert

      if (OrderType()==OP_BUY || OrderType()==OP_SELL) {
         n++;
         ArrayResize(tickets, n);
         tickets[n-1] = OrderTicket(); // tickets[] ist statisch
      }
   }

   //Print("CheckEvent.PositionClose()  eventStatus: "+ eventStatus);
   catch("CheckEvent.PositionClose()");
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein AccountPayment-Event aufgetreten ist.
 *
 * @param int& results[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param int  flags     - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool CheckEvent.AccountPayment(int& results[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(results) > 0)
      ArrayResize(results, 0);

   //Print("CheckEvent.AccountPayment()  eventStatus: "+ eventStatus);
   catch("CheckEvent.AccountPayment()");
   return(eventStatus);
}


/**
 * Prüft, ob seit dem letzten Aufruf ein HistoryChange-Event aufgetreten ist.
 *
 * @param int& results[] - im Erfolgsfall eventspezifische Detailinformationen
 * @param int  flags     - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - Ergebnis
 */
bool CheckEvent.HistoryChange(int& results[], int flags=0) {
   bool eventStatus = false;

   if (ArraySize(results) > 0)
      ArrayResize(results, 0);

   //Print("CheckEvent.HistoryChange()  eventStatus: "+ eventStatus);
   catch("CheckEvent.HistoryChange()");
   return(eventStatus);
}


/**
 * Korrekter Vergleich zweier Doubles.
 *
 * @param double1 - erster Wert
 * @param double2 - zweiter Wert
 *
 * @return bool - TRUE, wenn die Werte gleich sind; FALSE andererseits
 */
bool CompareDoubles(double double1, double double2) {
   return(NormalizeDouble(double1 - double2, 8) == 0);
}


/**
 * Gibt die nächstkleinere Periode der angegebenen Periode zurück.
 *
 * @param int period - Timeframe-Periode (default: 0 - die aktuelle Periode)
 *
 * @return int - Nächstkleinere Periode oder der ursprüngliche Wert, wenn keine kleinere Periode existiert.
 */
int DecreasePeriod(int period = 0) {
   if (period == 0)
      period = Period();

   switch (period) {
      case PERIOD_M1 : return(PERIOD_M1 );
      case PERIOD_M5 : return(PERIOD_M1 );
      case PERIOD_M15: return(PERIOD_M5 );
      case PERIOD_M30: return(PERIOD_M15);
      case PERIOD_H1 : return(PERIOD_M30);
      case PERIOD_H4 : return(PERIOD_H1 );
      case PERIOD_D1 : return(PERIOD_H4 );
      case PERIOD_W1 : return(PERIOD_D1 );
      case PERIOD_MN1: return(PERIOD_W1 );
   }

   catch("DecreasePeriod()  invalid parameter period: "+ period, ERR_INVALID_FUNCTION_PARAMVALUE);
   return(0);
}


/**
 * Konvertiert einen Double in einen String ohne abschließende Nullstellen oder Dezimalpunkt.
 *
 * @param number - Double
 *
 * @return string
 */
string DoubleToStrTrim(double number) {
   string result = number;
   int len = StringLen(result);

   bool alter = false;

   while (StringSubstr(result, len-1, 1) == "0") {
      len--;
      alter = true;
   }
   if (StringSubstr(result, len-1, 1) == ".") {
      len--;
      alter = true;
   }

   if (alter)
      result = StringSubstr(result, 0, len);

   //catch("DoubleToStrTrim()");
   return(result);
}


/**
 * Formatiert einen Währungsbetrag.
 *
 * @param double value - Betrag
 *
 * @return string
 */
string FormatMoney(double value) {
   string result = DoubleToStr(value, 0);

   int len = StringLen(result);

   if (len > 3) {
      string major = StringSubstr(result, 0, len-3);
      string minor = StringSubstr(result, len-3);
      result = StringConcatenate(major, " ", minor, ".00");
   }

   catch("FormatMoney()");
   return(result);
}


/**
 * TODO: Tausender-Stellen und Subticks müssen in getrennten if-Abfragen formatiert werden (Bug z.B. bei FormatPrice(1100.23, 2))
 */
string FormatPrice(double price, int digits) {
   string major="", minor="", strPrice = DoubleToStr(price, digits);

   // wenn Tausender-Stellen oder Subticks, dann reformatieren
   if (price >= 1000.0 || digits==3 || digits==5) {
      // Subticks
      if (digits==3 || digits==5) {
         int pos = StringFind(strPrice, ".");
         major = StringSubstr(strPrice, 0, pos);
         minor = StringSubstr(strPrice, pos+1);
         if    (digits == 3)  minor = StringConcatenate(StringSubstr(minor, 0, 2), "\'", StringSubstr(minor, 2));
         else /*digits == 5*/ minor = StringConcatenate(StringSubstr(minor, 0, 4), "\'", StringSubstr(minor, 4));
      }
      else {
         major = strPrice;
      }

      // Tausender-Stellen
      int len = StringLen(major);
      if (len > 3)
         major = StringConcatenate(StringSubstr(major, 0, len-3), ",", StringSubstr(major, len-3));

      // Vor- und Nachkommastellen zu Gesamtwert zusammensetzen
      if (digits==3 || digits==5) strPrice = StringConcatenate(major, ".", minor);
      else                        strPrice = major;
   }

   catch("FormatPrice()");
   return(strPrice);
}


/**
 * Liest die History eines Accounts aus dem Dateisystem in das übergebene Zielarray ein.  Die Datensätze werden als Strings (Rohdaten) zurückgegeben.
 *
 * @param int     account                        - Account-Nummer
 * @param string& destination[][HISTORY_COLUMNS] - Zeiger auf ein zweidimensionales Array
 *
 * @return int - Fehlerstatus
 */
int GetAccountHistory(int account, string& destination[][HISTORY_COLUMNS]) {
   if (ArrayRange(destination, 1) != HISTORY_COLUMNS)
      return(catch("GetAccountHistory(1)  invalid parameter destination["+ ArrayRange(destination, 0) +"]["+ ArrayRange(destination, 1) +"]", ERR_INCOMPATIBLE_ARRAYS));

   int    cache.account[1];
   string cache[][HISTORY_COLUMNS];

   // Daten nach Möglichkeit aus dem Cache liefern
   if (account == cache.account[0]) {
      if (ArrayRange(cache, 0) > 0) {
         ArrayCopy(destination, cache);
         //Print("GetAccountHistory()  delivering ", ArrayRange(destination, 0), " cached raw history entries for account "+ account);
         return(catch("GetAccountHistory(2)"));
      }
   }


   // Cache-Miss, History-Datei auslesen
   int error, tick = GetTickCount();
   string header[HISTORY_COLUMNS] = { "Ticket","OpenTime","OpenTimestamp","Description","Type","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","ExpirationTime","ExpirationTimestamp","MagicNumber","Commission","Swap","NetProfit","GrossProfit","NormalizedProfit","Balance","Comment" };
   ArrayResize(header, HISTORY_COLUMNS);

   // Datei öffnen
   string filename = account +"/account history.csv";
   int handle = FileOpen(filename, FILE_CSV|FILE_READ, '\t');
   if (handle < 0) {
      error = GetLastError();
      if (error == ERR_CANNOT_OPEN_FILE) {
         Print("GetAccountHistory()  cannot open file \""+ filename +"\" - does it exist?");
         return(error);
      }
      return(catch("GetAccountHistory(3)  FileOpen(filename="+ filename +")", error));
   }

   string value;
   bool   newLine=true, blankLine=false, lineEnd=true, comment=false;
   int    lines=0, row=-2, col=-1;
   string result[][HISTORY_COLUMNS]; ArrayResize(result, 0);


   // Daten zeilenweise auslesen
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

         if (newLine) {
            if (StringLen(value) == 0) {
               if (FileIsEnding(handle))     // Zeilenbeginn, Leervalue und Dateiende => keine Zeile (nichts), also Abbruch
                  break;
               // Zeilenbeginn, Leervalue und Zeilenende => Leerzeile
               blankLine = true;
            }
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
      if (lineEnd) {
         if (col < HISTORY_COLUMNS-1 || col > HISTORY_COLUMNS-1) {
            Alert("GetAccountHistory(4)  data format error in file \"", filename, "\", column count in line ", lines, " is not ", HISTORY_COLUMNS);
            error = ERR_SOME_FILE_ERROR;
            break;
         }
      }
      if (newLine)
         row++;

      // Headerinformationen in der ersten Datenzeile überprüfen und Headerzeile überspringen
      if (row == -1) {
         if (value != header[col]) {
            Alert("GetAccountHistory(5)  data format error in file \"", filename, "\", unexpected column header \"", value, "\"");
            error = ERR_SOME_FILE_ERROR;
            break;
         }
         continue;
      }

      // Datenarray vergrößern und Rohdaten speichern (alle als String)
      if (newLine)
         ArrayResize(result, row+1);
      result[row][col] = value;
   }

   // END_OF_FILE Error zurücksetzen
   error = GetLastError();
   if (error != ERR_END_OF_FILE)
      catch("GetAccountHistory(6)", error);

   // Datei schließen
   FileClose(handle);
   Print("GetAccountHistory()  history file data rows: ", row+1, "   used time: ", GetTickCount()-tick, " ms");


   // Daten in Zielarray kopieren und cachen
   if (ArrayRange(result, 0) == 0) {
      ArrayResize(destination, 0);
   }
   else {
      ArrayCopy(destination, result);
      ArrayCopy(cache, result);
   }
   cache.account[0] = account;
   //Print("GetAccountHistory()  cached ", ArrayRange(cache, 0), " raw history entries for account "+ account);

   return(catch("GetAccountHistory(7)"));
}


/**
 * Gibt den durchschnittlichen Spread des angegebenen Instruments zurück.
 *
 * @param string symbol - Instrument
 *
 * @return double - Spread
 */
double GetAverageSpread(string symbol) {
   double spread;

   if      (symbol == "EURUSD") spread = 0.00015;
   else if (symbol == "GBPJPY") spread = 0.05;
   else if (symbol == "GBPUSD") spread = 0.00025;
   else {
      //spread = MarketInfo(symbol, MODE_POINT) * MarketInfo(symbol, MODE_SPREAD); // aktueller Spread in Points
      catch("GetAverageSpread()  average spread for "+ symbol +" not found", ERR_UNKNOWN_SYMBOL);
   }
   return(spread);
}


/**
 * Schreibt die Balance-History eines Accounts in die angegebenen Zielarrays. Die Werte sind aufsteigend nach Zeitpunkt sortiert.
 *
 * @param int       account  - Account-Nummer
 * @param datetime& times[]  - Zeiger auf ein Array zur Aufnahme der Zeitpunkte der Balanceänderung
 * @param double&   values[] - Zeiger auf ein Array zur Aufnahme der Balance zum jeweiligen Zeitpunkt
 *
 * @return int - Fehlerstatus
 */
int GetBalanceHistory(int account, datetime& times[], double& values[]) {
   int      cache.account[1];
   datetime cache.times[];
   double   cache.values[];

   // Daten nach Möglichkeit aus dem Cache liefern
   if (account == cache.account[0]) {
      if (ArraySize(cache.times) > 0) {
         ArrayCopy(times, cache.times);
         ArrayCopy(values, cache.values);
         //Print("Delivering ", ArraySize(times), " cached balance entries for account "+ account);
         return(catch("GetBalanceHistory(1)"));
      }
   }

   // Cache-Miss, Balance-Daten aus Account-History auslesen
   string data[][HISTORY_COLUMNS]; ArrayResize(data, 0);
   GetAccountHistory(account, data);

   ArrayResize(times,  0);
   ArrayResize(values, 0);

   // Balancedatensätze auslesen (History ist nach CloseTime sortiert)
   datetime time=0, lastTime=0;
   double   balance=0.0, lastBalance=0.0;
   int n=0, size=ArrayRange(data, 0);

   for (int i=0; i<size; i++) {
      balance = StrToDouble(data[i][HC_BALANCE]);

      if (balance != lastBalance) {
         time = StrToInteger(data[i][HC_CLOSETIMESTAMP]);

         if (time == lastTime) {       // existieren mehrere Balanceänderungen zum selben Zeitpunkt,
            values[n-1] = balance;     // den vorherigen Balancewert mit dem aktuellen überschreiben
         }
         else {
            ArrayResize(times,  n+1);
            ArrayResize(values, n+1);
            times [n] = time;
            values[n] = balance;
            n++;
         }
      }

      lastTime    = time;
      lastBalance = balance;
   }

   // Daten cachen
   if (ArraySize(times) == 0) {
      ArrayResize(cache.times,  0);
      ArrayResize(cache.values, 0);
   }
   else {
      ArrayCopy(cache.times, times);
      ArrayCopy(cache.values, values);
   }
   cache.account[0] = account;
   //Print("Cached ", ArraySize(cache.times), " balance entries for account "+ account);

   return(catch("GetBalanceHistory(2)"));
}


/**
 * Gibt den Rechnernamen des laufenden Systems zurück.
 *
 * @return string - Name
 */
string GetComputerName() {
   string buffer[1]; buffer[0] = StringConcatenate(MAX_LEN_STRING, "");    // Kopie von MAX_LEN_STRING erzeugen (siehe MetaTrader.doc: Zeigerproblematik)
   int    lpSize[1]; lpSize[0] = StringLen(buffer[0]);

   if (!GetComputerNameA(buffer[0], lpSize)) {
      int error = GetLastError();
      if (error == ERR_NO_ERROR)
         error = ERR_NO_MEMORY_FOR_RETURNED_STR;
      catch("GetComputerName()   kernel32.GetComputerNameA(buffer, "+ lpSize[0] +")    result: 0", error);
      return("");
   }
   //Print("GetComputerName()   GetComputerNameA()   result: 1   copied: "+ lpSize[0] +"   buffer: "+ buffer[0]);

   catch("GetComputerName()");
   return(buffer[0]);
}


/**
 * Gibt den Wochentag des angegebenen Zeitpunkts zurück.
 *
 * @param datetime time - Zeitpunkt
 * @param bool     long - TRUE, um die Langform zurückzugeben (default)
 *                        FALSE, um die Kurzform zurückzugeben
 *
 * @return string - Wochentag
 */
string GetDayOfWeek(datetime time, bool long=true) {
   static string weekDays[] = {"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"};

   string day = weekDays[TimeDayOfWeek(time)];

   if (!long)
      day = StringSubstr(day, 0, 3);

   return(day);
}


/**
 * Gibt eine lesbare Beschreibung eines MQL-Fehlercodes zurück.
 *
 * @param int error - MQL-Fehlercode
 *
 * @return string - lesbare Beschreibung
 */
string GetErrorDescription(int error) {
   switch (error) {
      case ERR_NO_ERROR                   : return("no error"                                                );

      // trade server errors
      case ERR_NO_RESULT                  : return("no result"                                               );
      case ERR_COMMON_ERROR               : return("common error"                                            );
      case ERR_INVALID_TRADE_PARAMETERS   : return("invalid trade parameters"                                );
      case ERR_SERVER_BUSY                : return("trade server is busy"                                    );
      case ERR_OLD_VERSION                : return("old version of client terminal"                          );
      case ERR_NO_CONNECTION              : return("no connection to trade server"                           );
      case ERR_NOT_ENOUGH_RIGHTS          : return("not enough rights"                                       );
      case ERR_TOO_FREQUENT_REQUESTS      : return("too frequent requests"                                   );
      case ERR_MALFUNCTIONAL_TRADE        : return("malfunctional trade operation (never returned error)"    );
      case ERR_ACCOUNT_DISABLED           : return("account disabled"                                        );
      case ERR_INVALID_ACCOUNT            : return("invalid account"                                         );
      case ERR_TRADE_TIMEOUT              : return("trade timeout"                                           );
      case ERR_INVALID_PRICE              : return("invalid price"                                           );
      case ERR_INVALID_STOPS              : return("invalid stop"                                            );
      case ERR_INVALID_TRADE_VOLUME       : return("invalid trade volume"                                    );
      case ERR_MARKET_CLOSED              : return("market is closed"                                        );
      case ERR_TRADE_DISABLED             : return("trading is disabled"                                     );
      case ERR_NOT_ENOUGH_MONEY           : return("not enough money"                                        );
      case ERR_PRICE_CHANGED              : return("price changed"                                           );
      case ERR_OFF_QUOTES                 : return("off quotes"                                              );
      case ERR_BROKER_BUSY                : return("broker is busy (never returned error)"                   );
      case ERR_REQUOTE                    : return("requote"                                                 );
      case ERR_ORDER_LOCKED               : return("order is locked"                                         );
      case ERR_LONG_POSITIONS_ONLY_ALLOWED: return("long positions only allowed"                             );
      case ERR_TOO_MANY_REQUESTS          : return("too many requests"                                       );
      case ERR_TRADE_MODIFY_DENIED        : return("modification denied because too close to market"         );
      case ERR_TRADE_CONTEXT_BUSY         : return("trade context is busy"                                   );
      case ERR_TRADE_EXPIRATION_DENIED    : return("expiration settings denied by broker"                    );
      case ERR_TRADE_TOO_MANY_ORDERS      : return("number of open and pending orders has reached the limit" );
      case ERR_TRADE_HEDGE_PROHIBITED     : return("hedging prohibited"                                      );
      case ERR_TRADE_PROHIBITED_BY_FIFO   : return("prohibited by FIFO rules"                                );

      // runtime errors
      case ERR_RUNTIME_ERROR              : return("runtime error"                                           );
      case ERR_WRONG_FUNCTION_POINTER     : return("wrong function pointer"                                  );
      case ERR_ARRAY_INDEX_OUT_OF_RANGE   : return("array index out of range"                                );
      case ERR_NO_MEMORY_FOR_CALL_STACK   : return("no memory for function call stack"                       );
      case ERR_RECURSIVE_STACK_OVERFLOW   : return("recursive stack overflow"                                );
      case ERR_NOT_ENOUGH_STACK_FOR_PARAM : return("not enough stack for parameter"                          );
      case ERR_NO_MEMORY_FOR_PARAM_STRING : return("no memory for parameter string"                          );
      case ERR_NO_MEMORY_FOR_TEMP_STRING  : return("no memory for temp string"                               );
      case ERR_NOT_INITIALIZED_STRING     : return("not initialized string"                                  );
      case ERR_NOT_INITIALIZED_ARRAYSTRING: return("not initialized string in array"                         );
      case ERR_NO_MEMORY_FOR_ARRAYSTRING  : return("no memory for string in array"                           );
      case ERR_TOO_LONG_STRING            : return("string too long"                                         );
      case ERR_REMAINDER_FROM_ZERO_DIVIDE : return("remainder from division by zero"                         );
      case ERR_ZERO_DIVIDE                : return("division by zero"                                        );
      case ERR_UNKNOWN_COMMAND            : return("unknown command"                                         );
      case ERR_WRONG_JUMP                 : return("wrong jump (never generated error)"                      );
      case ERR_NOT_INITIALIZED_ARRAY      : return("array not initialized"                                   );
      case ERR_DLL_CALLS_NOT_ALLOWED      : return("DLL calls are not allowed"                               );
      case ERR_CANNOT_LOAD_LIBRARY        : return("cannot load library"                                     );
      case ERR_CANNOT_CALL_FUNCTION       : return("cannot call function"                                    );
      case ERR_EXTERNAL_CALLS_NOT_ALLOWED : return("expert function calls are not allowed"                   );
      case ERR_NO_MEMORY_FOR_RETURNED_STR : return("not enough memory for temp string returned from function");
      case ERR_SYSTEM_BUSY                : return("system busy (never generated error)"                     );
      case ERR_INVALID_FUNCTION_PARAMSCNT : return("invalid function parameter count"                        );
      case ERR_INVALID_FUNCTION_PARAMVALUE: return("invalid function parameter value"                        );
      case ERR_STRING_FUNCTION_INTERNAL   : return("string function internal error"                          );
      case ERR_SOME_ARRAY_ERROR           : return("array error"                                             );
      case ERR_INCORRECT_SERIESARRAY_USING: return("incorrect series array using"                            );
      case ERR_CUSTOM_INDICATOR_ERROR     : return("custom indicator error"                                  );
      case ERR_INCOMPATIBLE_ARRAYS        : return("incompatible arrays"                                     );
      case ERR_GLOBAL_VARIABLES_PROCESSING: return("global variables processing error"                       );
      case ERR_GLOBAL_VARIABLE_NOT_FOUND  : return("global variable not found"                               );
      case ERR_FUNC_NOT_ALLOWED_IN_TESTING: return("function not allowed in test mode"                       );
      case ERR_FUNCTION_NOT_CONFIRMED     : return("function not confirmed"                                  );
      case ERR_SEND_MAIL_ERROR            : return("send mail error"                                         );
      case ERR_STRING_PARAMETER_EXPECTED  : return("string parameter expected"                               );
      case ERR_INTEGER_PARAMETER_EXPECTED : return("integer parameter expected"                              );
      case ERR_DOUBLE_PARAMETER_EXPECTED  : return("double parameter expected"                               );
      case ERR_ARRAY_AS_PARAMETER_EXPECTED: return("array parameter expected"                                );
      case ERR_HISTORY_WILL_UPDATED       : return("requested history data in update state"                  );
      case ERR_TRADE_ERROR                : return("ERR_TRADE_ERROR"                                         ); // ???
      case ERR_END_OF_FILE                : return("end of file"                                             );
      case ERR_SOME_FILE_ERROR            : return("file error"                                              );
      case ERR_WRONG_FILE_NAME            : return("wrong file name"                                         );
      case ERR_TOO_MANY_OPENED_FILES      : return("too many opened files"                                   );
      case ERR_CANNOT_OPEN_FILE           : return("cannot open file"                                        );
      case ERR_INCOMPATIBLE_FILEACCESS    : return("incompatible file access"                                );
      case ERR_NO_ORDER_SELECTED          : return("no order selected"                                       );
      case ERR_UNKNOWN_SYMBOL             : return("unknown symbol"                                          );
      case ERR_INVALID_PRICE_PARAM        : return("invalid price parameter for trade function"              );
      case ERR_INVALID_TICKET             : return("invalid ticket"                                          );
      case ERR_TRADE_NOT_ALLOWED          : return("trading is not allowed in expert properties"             );
      case ERR_LONGS_NOT_ALLOWED          : return("long trades are not allowed in expert properties"        );
      case ERR_SHORTS_NOT_ALLOWED         : return("short trades are not allowed in expert properties"       );
      case ERR_OBJECT_ALREADY_EXISTS      : return("object already exists"                                   );
      case ERR_UNKNOWN_OBJECT_PROPERTY    : return("unknown object property"                                 );
      case ERR_OBJECT_DOES_NOT_EXIST      : return("object doesn\'t exist"                                   );
      case ERR_UNKNOWN_OBJECT_TYPE        : return("unknown object type"                                     );
      case ERR_NO_OBJECT_NAME             : return("no object name"                                          );
      case ERR_OBJECT_COORDINATES_ERROR   : return("object coordinates error"                                );
      case ERR_NO_SPECIFIED_SUBWINDOW     : return("no specified subwindow"                                  );
      case ERR_SOME_OBJECT_ERROR          : return("object error"                                            );
   }
   return("unknown error");
}


/**
 * Gibt eine lesbare Beschreibung eines Win32-Fehlercodes zurück.
 *
 * @param int error - Win32-Fehlercode
 *
 * @return string - lesbare Beschreibung
 */
string GetWinErrorDescription(int error) {
   switch (error) {
      case ERR_NO_ERROR: return("no error");
   }
   return("unknown error");
}


/**
 * Gibt die lesbare Version eines Events zurück.
 *
 * @param int event - Event
 *
 * @return string - lesbare Version
 */
string GetEventDescription(int event) {
   string description = "";

   switch (event) {
      case EVENT_BAR_OPEN       : description = "BarOpen"       ; break;
      case EVENT_ORDER_PLACE    : description = "OrderPlace"    ; break;
      case EVENT_ORDER_CHANGE   : description = "OrderChange"   ; break;
      case EVENT_ORDER_CANCEL   : description = "OrderCancel"   ; break;
      case EVENT_POSITION_OPEN  : description = "PositionOpen"  ; break;
      case EVENT_POSITION_CLOSE : description = "PositionClose" ; break;
      case EVENT_ACCOUNT_PAYMENT: description = "AccountPayment"; break;
      case EVENT_HISTORY_CHANGE : description = "HistoryChange" ; break;

      default:
         catch("GetEventDescription() - unknown event: "+ event, ERR_INVALID_FUNCTION_PARAMVALUE);
   }

   return(description);
}


/**
 * Alias für GetModuleDirectoryName().
 *
 * @return string - Verzeichnis
 */
string GetMetaTraderDirectory() {
   return(GetModuleDirectoryName());
}


/**
 * Gibt das Modulverzeichnis des laufenden Prozesses zurück.
 *
 * @return string - Verzeichnisname
 */
string GetModuleDirectoryName() {
   static string directory = "";

   // Das Verzeichnis kann sich nicht ändern und wird zwischengespeichert.
   if (directory == "") {
      string buffer[1]; buffer[0] = StringConcatenate(MAX_LEN_STRING, "");       // Kopie von MAX_LEN_STRING erzeugen (siehe MetaTrader.doc: Zeigerproblematik)

      if (!GetModuleFileNameA(0, buffer[0], StringLen(buffer[0]))) {
         int error = GetLastError();
         if (error == ERR_NO_ERROR)
            error = ERR_RUNTIME_ERROR;
         catch("GetModuleDirectoryName()   kernel32.GetModuleFileNameA()  result: 0", error);
         return("");
      }

      directory = StringSubstr(buffer[0], 0, StringFindR(buffer[0], "\\"));      // Pfadangabe extrahieren
      //Print("GetModuleDirectoryName()   module filename: "+ buffer[0] +"   directory: "+ directory);
   }

   catch("GetModuleDirectoryName()");
   return(directory);
}


/**
 * Gibt die lesbare Version eines Operation-Types zurück.
 *
 * @param int type - Operation-Type
 *
 * @return string - lesbare Version
 */
string GetOperationTypeDescription(int type) {
   string description = "";

   switch (type) {
      case OP_BUY         : description = "Buy"          ; break;
      case OP_SELL        : description = "Sell"         ; break;
      case OP_BUYLIMIT    : description = "Buy Limit"    ; break;
      case OP_SELLLIMIT   : description = "Sell Limit"   ; break;
      case OP_BUYSTOP     : description = "Stop Buy"     ; break;
      case OP_SELLSTOP    : description = "Stop Sell"    ; break;
      case OP_BALANCE     : description = "Balance"      ; break;
      case OP_MARGINCREDIT: description = "Margin Credit"; break;

      default:
         catch("GetOperationTypeDescription()  invalid paramter type: "+ type, ERR_INVALID_FUNCTION_PARAMVALUE);
   }
   return(description);
}


/**
 * Gibt die lesbare Version eines Timeframe-Codes zurück.
 *
 * @param int period - Timeframe-Code bzw. Anzahl der Minuten je Chart-Bar (default: Periode des aktuellen Charts)
 *
 * @return string - lesbare Version
 */
string GetPeriodDescription(int period=0) {
   if (period == 0)
      period = Period();

   string description = "";

   switch (period) {
      case PERIOD_M1 : description = "M1" ; break;    //     1  1 minute
      case PERIOD_M5 : description = "M5" ; break;    //     5  5 minutes
      case PERIOD_M15: description = "M15"; break;    //    15  15 minutes
      case PERIOD_M30: description = "M30"; break;    //    30  30 minutes
      case PERIOD_H1 : description = "H1" ; break;    //    60  1 hour
      case PERIOD_H4 : description = "H4" ; break;    //   240  4 hour
      case PERIOD_D1 : description = "D1" ; break;    //  1440  daily
      case PERIOD_W1 : description = "W1" ; break;    // 10080  weekly
      case PERIOD_MN1: description = "MN1"; break;    // 43200  monthly

      default:
         catch("GetPeriodDescription()  invalid parameter period: "+ period, ERR_INVALID_FUNCTION_PARAMVALUE);
   }
   return(description);
}


/**
 * Gibt die lesbare Version eines Timeframe-Flags zurück.
 *
 * @param int flags - binäre Kombination verschiedener Timeframe-Flags
 *
 * @return string - lesbare Version
 */
string GetPeriodFlagDescription(int flags) {
   string description = "";

   if (flags & PERIODFLAG_M1  != 0) description = StringConcatenate(description, " | M1");
   if (flags & PERIODFLAG_M5  != 0) description = StringConcatenate(description, " | M5");
   if (flags & PERIODFLAG_M15 != 0) description = StringConcatenate(description, " | M15");
   if (flags & PERIODFLAG_M30 != 0) description = StringConcatenate(description, " | M30");
   if (flags & PERIODFLAG_H1  != 0) description = StringConcatenate(description, " | H1");
   if (flags & PERIODFLAG_H4  != 0) description = StringConcatenate(description, " | H4");
   if (flags & PERIODFLAG_D1  != 0) description = StringConcatenate(description, " | D1");
   if (flags & PERIODFLAG_W1  != 0) description = StringConcatenate(description, " | W1");
   if (flags & PERIODFLAG_MN1 != 0) description = StringConcatenate(description, " | MN1");

   if (StringLen(description) > 0)
      return(StringSubstr(description, 3));
   return(description);
}


/**
 * Gibt die Abweichung der Serverzeit von EET (Eastern European Time) zurück.
 *
 * @return int - Offset in Stunden
 */
int GetServerEETOffset() {
   return(GetServerGMTOffset() - 2);
}


/**
 * Gibt die Abweichung der Serverzeit von GMT (Greenwich Mean Time) zurück.
 *
 * @return int - Offset in Stunden
 */
int GetServerGMTOffset() {
   /**
    * TODO: Haben verschiedene Server desselben Brokers evt. unterschiedliche Offsets?
    *       string server  = AccountServer();
    *       Print("GetServerGMTOffset(): account company: "+ company +", account server: "+ server);
    *
    * TODO: Zeitverschiebungen von 30 Minuten integrieren (evt. Rückgabewert in Minuten)
    */
   string company = AccountCompany();

   if (company != "") {
      if (company == "Straighthold Investment Group, Inc.") return( 2);
      if (company == "Alpari (UK) Ltd."                   ) return( 1);
      if (company == "Cantor Fitzgerald"                  ) return( 0);
      if (company == "Forex Ltd."                         ) return( 0);
      if (company == "ATC Brokers - Main"                 ) return(-5);
      if (company == "ATC Brokers - $8 Commission"        ) return(-5);
      catch("GetServerGMTOffset(1)  cannot resolve GMT trade server offset for unknown account company \""+ company +"\"", ERR_RUNTIME_ERROR);
   }
   else {
      // TODO: Verwendung von TerminalCompany() ist Unfug
      company = TerminalCompany();
      if (company == "Straighthold Investment Group, Inc.") return( 2);
      if (company == "Alpari (UK) Ltd."                   ) return( 1);
      if (company == "Cantor Fitzgerald Europe"           ) return( 0);
      if (company == "FOREX Ltd."                         ) return( 0);
      if (company == "Avail Trading Corp."                ) return(-5);
      catch("GetServerGMTOffset(2)  cannot resolve GMT trade server offset for unknown terminal company \""+ company +"\"", ERR_RUNTIME_ERROR);
   }

   return(EMPTY_VALUE);
}


/**
 * Gibt die Startzeit der den angegebenen Zeitpunkt abdeckenden Handelssession.
 *
 * @param datetime time - Zeitpunkt (Serverzeit)
 *
 * @return datetime - Zeitpunkt (Serverzeit)
 */
datetime GetSessionStartTime(datetime time) {
   // Die Handelssessions beginnen um 00:00 EET (= 22:00 GMT).

   // Serverzeit in EET konvertieren, Tagesbeginn berechnen und zurück in Serverzeit konvertieren
   int eetOffset     = GetServerEETOffset();
   datetime eetTime  = time - eetOffset * HOURS;
   datetime eetStart = eetTime - TimeHour(eetTime)*HOURS - TimeMinute(eetTime)*MINUTES - TimeSeconds(eetTime);
   datetime result   = eetStart + eetOffset * HOURS;

   //Print("GetSessionStartTime()  time: "+ TimeToStr(time) +"   EET: "+ TimeToStr(eetTime) +"   eetStart: "+ TimeToStr(eetStart) +"   serverStart: "+ TimeToStr(result));

   catch("GetSessionStartTime()");
   return(result);
}


/**
 * Gibt die lesbare Version eines UninitializeReason-Codes zurück (siehe UninitializeReason()).
 *
 * @param int reason - Code
 *
 * @return string - lesbare Version
 */
string GetUninitReasonDescription(int reason) {
   string result = "";

   switch (reason) {
      case REASON_FINISHED   : result = "execution finished ";                    break;
      case REASON_REMOVE     : result = "expert or indicator removed from chart"; break;
      case REASON_RECOMPILE  : result = "expert or indicator recompiled";         break;
      case REASON_CHARTCHANGE: result = "chart symbol or timeframe changed";      break;
      case REASON_CHARTCLOSE : result = "chart closed";                           break;
      case REASON_PARAMETERS : result = "input parameters changed by user";       break;
      case REASON_ACCOUNT    : result = "account changed";                        break;
      default:
         catch("GetUninitReasonDescription()  invalid parameter reason: "+ reason, ERR_INVALID_FUNCTION_PARAMVALUE);
   }
   return(result);
}


/**
 * Berechnet den vollständigen Verlauf der Balance für den aktuellen Chart und schreibt die Werte in das übergebene
 * Zielarray.  Diese Funktion ist vorzuziehen, wenn der Indikator vollständig neu berechnet werden soll.
 *
 * @param int     account - Account, für den der Indikator berechnet werden soll
 * @param double& iBuffer - Indikatorpuffer oder Array
 *
 * @return int - Fehlerstatus
 */
int iBalanceSeries(int account, double& iBuffer[]) {
   if (ArrayRange(iBuffer, 0) != Bars) {
      ArrayResize(iBuffer, Bars);
      ArrayInitialize(iBuffer, EMPTY_VALUE);
   }

   datetime times[];  ArrayResize(times, 0);
   double   values[]; ArrayResize(values, 0);

   // Balance-History holen
   GetBalanceHistory(account, times, values);

   int bar, lastBar, z, size=ArraySize(times);

   // Balancewerte in Zielarray übertragen (die History ist nach CloseTime sortiert)
   for (int i=0; i < size; i++) {
      // Barindex des Zeitpunkts berechnen
      bar = iBarShiftNext(NULL, 0, times[i]);
      if (bar == -1)    // dieser und alle folgenden Werte sind zu neu für den Chart
         break;

      // Indikatorlücken mit vorherigem Balancewert füllen
      if (bar < lastBar-1) {
         for (z=lastBar-1; z > bar; z--)
            iBuffer[z] = iBuffer[lastBar];
      }

      // Balancewert eintragen
      iBuffer[bar] = values[i];
      lastBar = bar;
   }

   // Indikator bis zur ersten Bar mit dem letzten bekannten Wert füllen
   for (bar=lastBar-1; bar >= 0; bar--) {
      iBuffer[bar] = iBuffer[lastBar];
   }

   return(catch("iBalanceSeries()"));
}


/**
 * Ermittelt den Chart-Offset (Bar) eines Zeitpunktes und gibt bei nicht existierender Bar die nächste existierende Bar zurück.
 *
 * @param string   symbol    - Symbol der zu verwendenden Datenreihe (default: NULL = aktuelles Symbol)
 * @param int      timeframe - Periode der zu verwendenden Datenreihe (default: 0 = aktuelle Periode)
 * @param datetime time - Zeitpunkt
 *
 * @return int - Bar-Index im Chart
 *
 * NOTE:
 * ----
 * Kann den Fehler ERR_HISTORY_WILL_UPDATED auslösen.
 */
int iBarShiftNext(string symbol/*=NULL*/, int timeframe/*=0*/, datetime time) {
   if (symbol == "0")                                    // MQL: NULL ist ein Integer
      symbol = Symbol();

   int bar = iBarShift(symbol, timeframe, time, true);   // evt. ERR_HISTORY_WILL_UPDATED

   if (bar == -1) {                                      // falls die Bar nicht existiert:
      if (time < Time[Bars-1])                           // Zeitpunkt ist zu alt für den Chart, die älteste Bar zurückgeben
         bar = Bars-1;
      else if (time < Time[0]) {                         // Kurslücke, die nächste existierende Bar wird zurückgeben
         bar = iBarShift(symbol, timeframe, time) + 1;
      }
    //else: (time > Time[0]) -> bar = -1                 // Zeitpunkt ist zu neu für den Chart
   }

   //catch("iBarShiftNext()");
   return(bar);
}


/**
 * Ermittelt den Chart-Offset (Bar) eines Zeitpunktes und gibt bei nicht existierender Bar die vorherige existierende Bar zurück.
 *
 * @param string   symbol    - Symbol der zu verwendenden Datenreihe (default: NULL = aktuelles Symbol)
 * @param int      timeframe - Periode der zu verwendenden Datenreihe (default: 0 = aktuelle Periode)
 * @param datetime time - Zeitpunkt
 *
 * @return int - Bar-Index im Chart
 *
 * NOTE:
 * ----
 * Kann den Fehler ERR_HISTORY_WILL_UPDATED auslösen.
 */
int iBarShiftPrevious(string symbol/*=NULL*/, int timeframe/*=0*/, datetime time) {
   if (symbol == "0")                              // MQL: NULL ist ein Integer
      symbol = Symbol();

   int bar = iBarShift(symbol, timeframe, time);   // evt. ERR_HISTORY_WILL_UPDATED

   if (time < Time[Bars-1])                        // Korrektur von iBarShift(), falls Zeitpunkt zu alt für den Chart ist
      bar = -1;

   //catch("iBarShiftPrevious()");
   return(bar);
}


/**
 * Gibt die nächstgrößere Periode der angegebenen Periode zurück.
 *
 * @param int period - Timeframe-Periode (default: 0 - die aktuelle Periode)
 *
 * @return int - Nächstgrößere Periode oder der ursprüngliche Wert, wenn keine größere Periode existiert.
 */
int IncreasePeriod(int period = 0) {
   if (period == 0)
      period = Period();

   switch (period) {
      case PERIOD_M1 : return(PERIOD_M5 );
      case PERIOD_M5 : return(PERIOD_M15);
      case PERIOD_M15: return(PERIOD_M30);
      case PERIOD_M30: return(PERIOD_H1 );
      case PERIOD_H1 : return(PERIOD_H4 );
      case PERIOD_H4 : return(PERIOD_D1 );
      case PERIOD_D1 : return(PERIOD_W1 );
      case PERIOD_W1 : return(PERIOD_MN1);
      case PERIOD_MN1: return(PERIOD_MN1);
   }

   catch("IncreasePeriod()  invalid parameter period: "+ period, ERR_INVALID_FUNCTION_PARAMVALUE);
   return(0);
}


/**
 *
 */
int onAccountPayment(int details[]) {
   return(catch("onAccountPayment()    implementation not found", ERR_FUNCTION_NOT_CONFIRMED));
}


/**
 *
 */
int onBarOpen(int details[]) {
   return(catch("onBarOpen()    implementation not found", ERR_FUNCTION_NOT_CONFIRMED));
}


/**
 *
 */
int onHistoryChange(int details[]) {
   return(catch("onHistoryChange()    implementation not found", ERR_FUNCTION_NOT_CONFIRMED));
}


/**
 *
 */
int onOrderPlace(int details[]) {
   return(catch("onOrderPlace()    implementation not found", ERR_FUNCTION_NOT_CONFIRMED));
}


/**
 *
 */
int onOrderChange(int details[]) {
   return(catch("onOrderChange()    implementation not found", ERR_FUNCTION_NOT_CONFIRMED));
}


/**
 *
 */
int onOrderCancel(int details[]) {
   return(catch("onOrderCancel()    implementation not found", ERR_FUNCTION_NOT_CONFIRMED));
}


/**
 *
 */
int onPositionOpen(int details[]) {
   return(catch("onPositionOpen()    implementation not found", ERR_FUNCTION_NOT_CONFIRMED));
}


/**
 *
 */
int onPositionClose(int details[]) {
   return(catch("onPositionClose()    implementation not found", ERR_FUNCTION_NOT_CONFIRMED));
}


/**
 * Hilfsfunktion zur Timeframe-übergreifenden Speicherung der aktuellen QuoteTracker-Soundlimite
 * (Variablen bleiben nur in Libraries Timeframe-übergreifend erhalten).
 *
 * @param string  symbol    - Instrument, für das Limite verwaltet werden (default: NULL = das aktuelle Symbol)
 * @param double& limits[2] - Array mit den aktuellen Limiten (0: lower limit, 1: upper limit)
 *
 * @return bool - Erfolgsstatus: TRUE, wenn die Daten erfolgreich gelesen oder geschrieben wurden;
 *                               FALSE andererseits (z.B. Leseversuch nicht existierender Daten)
 */
bool QuoteTracker.SoundLimits(string symbol, double& limits[]) {
   if (symbol == "0")      // MQL: NULL ist ein Integer
      symbol = Symbol();

   if (ArraySize(limits) != 2) {
      catch("QuoteTracker.SoundLimits(1)  invalid parameter limits["+ ArraySize(limits) +"]", ERR_INCOMPATIBLE_ARRAYS);
      return(false);
   }

   string cache.symbols[];
   double cache.limits[][2];

   // Lese- oder Schreiboperation?
   bool get=false, set=false;
   if (limits[0]==0 || limits[1]==0) get = true;
   else                              set = true;

   // Index des Symbols ermitteln
   for (int i=ArraySize(cache.symbols)-1; i >= 0; i--) {
      if (cache.symbols[i] == symbol)
         break;
   }

   // Lesen
   if (get) {
      limits[0] = 0;
      limits[1] = 0;

      if (i == -1)                        // Symbol nicht gefunden
         return(false);

      limits[0] = cache.limits[i][0];
      limits[1] = cache.limits[i][1];

      if (limits[0]==0 || limits[1]==0)   // nur theoretisch: Symbol gefunden, Limite sind aber nicht initialisiert
         return(false);
   }

   // Schreiben
   else {
      if (i == -1) {                      // Symbol nicht gefunden -> Eintrag anlegen
         i = ArraySize(cache.symbols);
         ArrayResize(cache.symbols, i + 1);
         ArrayResize(cache.limits , i + 1);
      }
      cache.symbols[i]   = symbol;
      cache.limits[i][0] = limits[0];
      cache.limits[i][1] = limits[1];
   }

   catch("QuoteTracker.SoundLimits(2)");
   return(true);
}


/**
 * Hilfsfunktion zur Timeframe-übergreifenden Speicherung der aktuellen QuoteTracker-SMS-Limite
 * (Variablen bleiben nur in Libraries Timeframe-übergreifend erhalten).
 *
 * @param string  symbol    - Instrument, für das Limite verwaltet werden (default: NULL = das aktuelle Symbol)
 * @param double& limits[2] - Array mit den aktuellen Limiten (0: lower limit, 1: upper limit)
 *
 * @return bool - Erfolgsstatus: TRUE, wenn die Daten erfolgreich gelesen oder geschrieben wurden;
 *                               FALSE andererseits (z.B. Leseversuch nicht existierender Daten)
 */
bool QuoteTracker.SMSLimits(string symbol, double& limits[]) {
   if (symbol == "0")      // MQL: NULL ist ein Integer
      symbol = Symbol();

   if (ArraySize(limits) != 2) {
      catch("QuoteTracker.SMSLimits(1)  invalid parameter limits["+ ArraySize(limits) +"]", ERR_INCOMPATIBLE_ARRAYS);
      return(false);
   }

   string cache.symbols[];
   double cache.limits[][2];

   // Lese- oder Schreiboperation?
   bool get=false, set=false;
   if (limits[0]==0 || limits[1]==0) get = true;
   else                              set = true;

   // Index des Symbols ermitteln
   for (int i=ArraySize(cache.symbols)-1; i >= 0; i--) {
      if (cache.symbols[i] == symbol)
         break;
   }

   // Lesen
   if (get) {
      limits[0] = 0;
      limits[1] = 0;

      if (i == -1)                        // Symbol nicht gefunden
         return(false);

      limits[0] = cache.limits[i][0];
      limits[1] = cache.limits[i][1];

      if (limits[0]==0 || limits[1]==0)   // nur theoretisch: Symbol gefunden, Limite sind aber nicht initialisiert
         return(false);
   }

   // Schreiben
   else {
      if (i == -1) {
         i = ArraySize(cache.symbols);
         ArrayResize(cache.symbols, i + 1);
         ArrayResize(cache.limits , i + 1);
      }
      cache.symbols[i]   = symbol;
      cache.limits[i][0] = limits[0];
      cache.limits[i][1] = limits[1];
   }

   catch("QuoteTracker.SMSLimits(2)");
   return(true);
}


/**
 * Fügt das angegebene Objektlabel den bereits gespeicherten Labels hinzu.
 *
 * @param string  label     - zu speicherndes Label
 * @param string& objects[] - Array mit bereits gespeicherten Labels
 *
 * @return int - Fehlerstatus
 */
int RegisterChartObject(string label, string& objects[]) {
   int size = ArraySize(objects);
   ArrayResize(objects, size+1);
   objects[size] = label;

   return(0);
}


/**
 * Entfernt alle Objekte mit den im übergebenen Array gespeicherten Labels aus dem aktuellen Chart.
 *
 * @param string& objects[] - Array mit gespeicherten Objektlabels
 *
 * @return int - Fehlerstatus
 */
int RemoveChartObjects(string& objects[]) {
   int size = ArraySize(objects);
   if (size == 0)
      return(0);

   for (int i=0; i < size; i++) {
      ObjectDelete(objects[i]);
   }
   ArrayResize(objects, 0);

   int error = GetLastError();
   if (error == ERR_OBJECT_DOES_NOT_EXIST) return(ERR_NO_ERROR);
   if (error == ERR_NO_ERROR             ) return(ERR_NO_ERROR);

   return(catch("RemoveChartObjects()", error));
}


/**
 * Vergleicht zwei Strings miteinander.
 *
 * @param string string1
 * @param string string2
 * @param bool   ignorCase - ob Groß-/Kleinschreibung ignoriert werden soll (default: TRUE)
 *
 * @return bool
 */
bool StringCompare(string string1, string string2, bool ignoreCase=true) {
   if (ignoreCase)
      return(StringToUpper(string1) == StringToUpper(string2));

   return(string1 == string2);
}


/**
 * Durchsucht einen String vom Ende aus nach einem Substring und gibt dessen Position zurück.
 *
 * @param string subject - zu durchsuchender String
 * @param string search  - zu suchender Substring
 *
 * @return int - letzte Position des Substrings oder -1, wenn der Substring nicht gefunden wurde
 */
int StringFindR(string subject, string search) {
   int lenSubject = StringLen(subject),
       lastFound  = -1,
       result     =  0;

   for (int i=0; i < lenSubject; i++) {
      result = StringFind(subject, search, i);
      if (result == -1)
         break;
      lastFound = result;
   }

   catch("StringFindR()");
   return(lastFound);
}


/**
 * Konvertiert einen String in Kleinschreibweise.
 *
 * @param string value
 *
 * @return string
 */
string StringToLower(string value) {
   string result = value;
   int char, len = StringLen(value);

   for (int i=0; i < len; i++) {
      char = StringGetChar(value, i);
      if ( 64 < char) if (char <  91) result = StringSetChar(result, i, char+32);   // Conditions für MQL optimiert
      if (191 < char) if (char < 224) result = StringSetChar(result, i, char+32);
   }

   catch("StringToLower()");
   return(result);
}


/**
 * Konvertiert einen String in Großschreibweise.
 *
 * @param string value
 *
 * @return string
 */
string StringToUpper(string value) {
   string result = value;
   int char, len = StringLen(value);

   for (int i=0; i < len; i++) {
      char = StringGetChar(value, i);
      if ( 96 < char) if (char < 123) result = StringSetChar(result, i, char-32);   // Conditions für MQL optimiert
      if (223 < char)                 result = StringSetChar(result, i, char-32);
   }

   catch("StringToUpper()");
   return(result);
}


/**
 * Trimmt einen String beidseitig.
 *
 * @param string value
 *
 * @return string
 */
string StringTrim(string value) {
   return(StringTrimLeft(StringTrimRight(value)));
}




// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! //
// Original-MetaQuotes Funktionen             !!! NICHT VERWENDEN !!!                 //
//                                                                                    //
// Diese Funktionen stehen hier nur zur Dokumentation. Sie sind teilweise fehlerhaft. //
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! //

/**
 * convert red, green and blue values to color
 */
int RGB(int red, int green, int blue) {
   //---- check parameters
   if (red   <   0) red   =   0;
   if (red   > 255) red   = 255;
   if (green <   0) green =   0;
   if (green > 255) green = 255;
   if (blue  <   0) blue  =   0;
   if (blue  > 255) blue  = 255;

   green <<=  8;
   blue  <<= 16;

   return (red + green + blue);
}


/**
 * up to 16 digits after decimal point
 */
string DoubleToStrMorePrecision(double number, int precision) {
   double rem, integer, integer2;
   double DecimalArray[17] = { 1.0,
                              10.0,
                             100.0,
                            1000.0,
                           10000.0,
                          100000.0,
                         1000000.0,
                        10000000.0,
                       100000000.0,
                      1000000000.0,
                     10000000000.0,
                    100000000000.0,
                   1000000000000.0,
                  10000000000000.0,
                 100000000000000.0,
                1000000000000000.0,
               10000000000000000.0 };
   string intstring, remstring, retstring;
   bool   isnegative = false;
   int    rem2;

   if (precision <  0) precision =  0;
   if (precision > 16) precision = 16;

   double p = DecimalArray[precision];
   if (number < 0.0) {
      isnegative = true;
      number = -number;
   }

   integer = MathFloor(number);
   rem = MathRound((number-integer) * p);
   remstring = "";

   for (int i=0; i<precision; i++) {
      integer2 = MathFloor(rem/10);
      rem2 = NormalizeDouble(rem-integer2 * 10, 0);
      remstring = rem2 + remstring;
      rem = integer2;
   }

   intstring = DoubleToStr(integer, 0);

   if (isnegative) retstring = "-"+ intstring;
   else            retstring = intstring;

   if (precision > 0)
      retstring = retstring +"."+ remstring;

   return(retstring);
}


/**
 * convert integer to string contained input's hexadecimal notation
 */
string IntegerToHexString(int integer_number) {
   string hex_string = "00000000";
   int    value, shift = 28;
   // Print("Parameter for IntegerHexToString is ", integer_number);

   for (int i=0; i<8; i++) {
      value = (integer_number>>shift) & 0x0F;
      if (value < 10) hex_string = StringSetChar(hex_string, i,  value     +'0');
      else            hex_string = StringSetChar(hex_string, i, (value-10) +'A');
      shift -= 4;
   }
   return(hex_string);
}

