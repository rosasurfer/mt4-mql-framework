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
      case ERR_WINDOWS_ERROR              : return("Windows error"                                           );
   }
   return("unknown error");
}


/**
 * Gibt die lesbare Beschreibung eines Windows-Fehlercodes zurück.
 *
 * @param int error - Win32-Fehlercode
 *
 * @return string - lesbare Beschreibung
 */
string GetWindowsErrorDescription(int error) {
   switch (error) {
      case ERR_NO_ERROR: return("no error");
   }
   return("unknown error");

/*
// The operation completed successfully.                                                                                                                                             #define ERROR_SUCCESS                    0
                                                                                                                                                                                     #define NO_ERROR 0
// Incorrect function.                                                                                                                                                               #define ERROR_INVALID_FUNCTION           1

// The system cannot find the file specified.                                                                                                                                        #define ERROR_FILE_NOT_FOUND             2

// The system cannot find the path specified.                                                                                                                                        #define ERROR_PATH_NOT_FOUND             3

// The system cannot open the file.                                                                                                                                                  #define ERROR_TOO_MANY_OPEN_FILES        4

// Access is denied.                                                                                                                                                                 #define ERROR_ACCESS_DENIED              5

// The handle is invalid.                                                                                                                                                            #define ERROR_INVALID_HANDLE             6

// The storage control blocks were destroyed.                                                                                                                                        #define ERROR_ARENA_TRASHED              7

// Not enough storage is available to process this command.                                                                                                                          #define ERROR_NOT_ENOUGH_MEMORY          8

// The storage control block address is invalid.                                                                                                                                     #define ERROR_INVALID_BLOCK              9

// The environment is incorrect.                                                                                                                                                     #define ERROR_BAD_ENVIRONMENT            10

// An attempt was made to load a program with an incorrect format.                                                                                                                   #define ERROR_BAD_FORMAT                 11

// The access code is invalid.                                                                                                                                                       #define ERROR_INVALID_ACCESS             12

// The data is invalid.                                                                                                                                                              #define ERROR_INVALID_DATA               13

// Not enough storage is available to complete this operation.                                                                                                                       #define ERROR_OUTOFMEMORY                14

// The system cannot find the drive specified.                                                                                                                                       #define ERROR_INVALID_DRIVE              15

// The directory cannot be removed.                                                                                                                                                  #define ERROR_CURRENT_DIRECTORY          16

// The system cannot move the file
// to a different disk drive.                                                                                                                                                        #define ERROR_NOT_SAME_DEVICE            17

// There are no more files.                                                                                                                                                          #define ERROR_NO_MORE_FILES              18

// The media is write protected.                                                                                                                                                     #define ERROR_WRITE_PROTECT              19

// The system cannot find the device specified.                                                                                                                                      #define ERROR_BAD_UNIT                   20

// The device is not ready.                                                                                                                                                          #define ERROR_NOT_READY                  21

// The device does not recognize the command.                                                                                                                                        #define ERROR_BAD_COMMAND                22

// Data error (cyclic redundancy check).                                                                                                                                             #define ERROR_CRC                        23

// The program issued a command but the command length is incorrect.                                                                                                                 #define ERROR_BAD_LENGTH                 24

// The drive cannot locate a specific area or track on the disk.                                                                                                                     #define ERROR_SEEK                       25

// The specified disk or diskette cannot be accessed.                                                                                                                                #define ERROR_NOT_DOS_DISK               26

// The drive cannot find the sector requested.                                                                                                                                       #define ERROR_SECTOR_NOT_FOUND           27

// The printer is out of paper.                                                                                                                                                      #define ERROR_OUT_OF_PAPER               28

// The system cannot write to the specified device.                                                                                                                                  #define ERROR_WRITE_FAULT                29

// The system cannot read from the specified device.                                                                                                                                 #define ERROR_READ_FAULT                 30

// A device attached to the system is not functioning.                                                                                                                               #define ERROR_GEN_FAILURE                31

// The process cannot access the file because it is being used by another process.                                                                                                   #define ERROR_SHARING_VIOLATION          32

// The process cannot access the file because another process has locked a portion of the file.                                                                                      #define ERROR_LOCK_VIOLATION             33

// The wrong diskette is in the drive.                                                                                                                                               #define ERROR_WRONG_DISK                 34

// Too many files opened for sharing.                                                                                                                                                #define ERROR_SHARING_BUFFER_EXCEEDED    36

// Reached the end of the file.                                                                                                                                                      #define ERROR_HANDLE_EOF                 38

// The disk is full.                                                                                                                                                                 #define ERROR_HANDLE_DISK_FULL           39

// The network request is not supported.                                                                                                                                             #define ERROR_NOT_SUPPORTED              50

// The remote computer is not available.                                                                                                                                             #define ERROR_REM_NOT_LIST               51

// A duplicate name exists on the network.                                                                                                                                           #define ERROR_DUP_NAME                   52

// The network path was not found.                                                                                                                                                   #define ERROR_BAD_NETPATH                53

// The network is busy.                                                                                                                                                              #define ERROR_NETWORK_BUSY               54

// The specified network resource or device is no longer available.                                                                                                                  #define ERROR_DEV_NOT_EXIST              55

// The network BIOS command limit has been reached.                                                                                                                                  #define ERROR_TOO_MANY_CMDS              56

// A network adapter hardware error occurred.                                                                                                                                        #define ERROR_ADAP_HDW_ERR               57

// The specified server cannot perform the requested operation.                                                                                                                      #define ERROR_BAD_NET_RESP               58

// An unexpected network error occurred.                                                                                                                                             #define ERROR_UNEXP_NET_ERR              59

// The remote adapter is not compatible.                                                                                                                                             #define ERROR_BAD_REM_ADAP               60

// The printer queue is full.                                                                                                                                                        #define ERROR_PRINTQ_FULL                61

// Space to store the file waiting to be printed is not available on the server.                                                                                                     #define ERROR_NO_SPOOL_SPACE             62

// Your file waiting to be printed was deleted.                                                                                                                                      #define ERROR_PRINT_CANCELLED            63

// The specified network name is no longer available.                                                                                                                                #define ERROR_NETNAME_DELETED            64

// Network access is denied.                                                                                                                                                         #define ERROR_NETWORK_ACCESS_DENIED      65

// The network resource type is not correct.                                                                                                                                         #define ERROR_BAD_DEV_TYPE               66

// The network name cannot be found.                                                                                                                                                 #define ERROR_BAD_NET_NAME               67

// The name limit for the local computer network adapter card was exceeded.                                                                                                          #define ERROR_TOO_MANY_NAMES             68

// The network BIOS session limit was exceeded.                                                                                                                                      #define ERROR_TOO_MANY_SESS              69

// The remote server has been paused or is in the process of being started.                                                                                                          #define ERROR_SHARING_PAUSED             70

// No more connections can be made to this remote computer at this time because there are already as many connections as the computer can accept.                                    #define ERROR_REQ_NOT_ACCEP              71

// The specified printer or disk device has been paused.                                                                                                                             #define ERROR_REDIR_PAUSED               72

// The file exists.                                                                                                                                                                  #define ERROR_FILE_EXISTS                80

// The directory or file cannot be created.                                                                                                                                          #define ERROR_CANNOT_MAKE                82

// Fail on INT 24.                                                                                                                                                                   #define ERROR_FAIL_I24                   83

// Storage to process this request is not available.                                                                                                                                 #define ERROR_OUT_OF_STRUCTURES          84

// The local device name is already in use.                                                                                                                                          #define ERROR_ALREADY_ASSIGNED           85

// The specified network password is not correct.                                                                                                                                    #define ERROR_INVALID_PASSWORD           86

// The parameter is incorrect.                                                                                                                                                       #define ERROR_INVALID_PARAMETER          87

// A write fault occurred on the network.                                                                                                                                            #define ERROR_NET_WRITE_FAULT            88

// The system cannot start another process at this time.                                                                                                                             #define ERROR_NO_PROC_SLOTS              89

// Cannot create another system semaphore.                                                                                                                                           #define ERROR_TOO_MANY_SEMAPHORES        100

// The exclusive semaphore is owned by another process.                                                                                                                              #define ERROR_EXCL_SEM_ALREADY_OWNED     101

// The semaphore is set and cannot be closed.                                                                                                                                        #define ERROR_SEM_IS_SET                 102

// The semaphore cannot be set again.                                                                                                                                                #define ERROR_TOO_MANY_SEM_REQUESTS      103

// Cannot request exclusive semaphores at interrupt time.                                                                                                                            #define ERROR_INVALID_AT_INTERRUPT_TIME  104

// The previous ownership of this semaphore has ended.                                                                                                                               #define ERROR_SEM_OWNER_DIED             105

// Insert the diskette for drive %1.                                                                                                                                                 #define ERROR_SEM_USER_LIMIT             106

// The program stopped because an alternate diskette was not inserted.                                                                                                               #define ERROR_DISK_CHANGE                107

// The disk is in use or locked by another process.                                                                                                                                  #define ERROR_DRIVE_LOCKED               108

// The pipe has been ended.                                                                                                                                                          #define ERROR_BROKEN_PIPE                109

// The system cannot open the device or file specified.                                                                                                                              #define ERROR_OPEN_FAILED                110

// The file name is too long.                                                                                                                                                        #define ERROR_BUFFER_OVERFLOW            111

// There is not enough space on the disk.                                                                                                                                            #define ERROR_DISK_FULL                  112

// No more internal file identifiers available.                                                                                                                                      #define ERROR_NO_MORE_SEARCH_HANDLES     113

// The target internal file identifier is incorrect.                                                                                                                                 #define ERROR_INVALID_TARGET_HANDLE      114

// The IOCTL call made by the application program is not correct.                                                                                                                    #define ERROR_INVALID_CATEGORY           117

// The verify-on-write switch parameter value is not correct.                                                                                                                        #define ERROR_INVALID_VERIFY_SWITCH      118

// The system does not support the command requested.                                                                                                                                #define ERROR_BAD_DRIVER_LEVEL           119

// This function is not supported on this system.                                                                                                                                    #define ERROR_CALL_NOT_IMPLEMENTED       120

// The semaphore timeout period has expired.                                                                                                                                         #define ERROR_SEM_TIMEOUT                121

// The data area passed to a system call is too small.                                                                                                                               #define ERROR_INSUFFICIENT_BUFFER        122

// The filename, directory name, or volume label syntax is incorrect.                                                                                                                #define ERROR_INVALID_NAME               123

// The system call level is not correct.                                                                                                                                             #define ERROR_INVALID_LEVEL              124

// The disk has no volume label.                                                                                                                                                     #define ERROR_NO_VOLUME_LABEL            125

// The specified module could not be found.                                                                                                                                          #define ERROR_MOD_NOT_FOUND              126

// The specified procedure could not be found.                                                                                                                                       #define ERROR_PROC_NOT_FOUND             127

// There are no child processes to wait for.                                                                                                                                         #define ERROR_WAIT_NO_CHILDREN           128

// The %1 application cannot be run in Win32 mode.                                                                                                                                   #define ERROR_CHILD_NOT_COMPLETE         129

// Attempt to use a file handle to an open disk partition for an operation other than raw disk I/O.                                                                                  #define ERROR_DIRECT_ACCESS_HANDLE       130

// An attempt was made to move the file pointer before the beginning of the file.                                                                                                    #define ERROR_NEGATIVE_SEEK              131

// The file pointer cannot be set on the specified device or file.                                                                                                                   #define ERROR_SEEK_ON_DEVICE             132

// A JOIN or SUBST command cannot be used for a drive that contains previously joined drives.                                                                                        #define ERROR_IS_JOIN_TARGET             133

// An attempt was made to use a JOIN or SUBST command on a drive that has already been joined.                                                                                       #define ERROR_IS_JOINED                  134

// An attempt was made to use a JOIN or SUBST command on a drive that has already been substituted.                                                                                  #define ERROR_IS_SUBSTED                 135

// The system tried to delete the JOIN of a drive that is not joined.                                                                                                                #define ERROR_NOT_JOINED                 136

// The system tried to delete the substitution of a drive that is not substituted.                                                                                                   #define ERROR_NOT_SUBSTED                137

// The system tried to join a drive to a directory on a joined drive.                                                                                                                #define ERROR_JOIN_TO_JOIN               138

// The system tried to substitute a drive to a directory on a substituted drive.                                                                                                     #define ERROR_SUBST_TO_SUBST             139

// The system tried to join a drive to a directory on a substituted drive.                                                                                                           #define ERROR_JOIN_TO_SUBST              140

// The system tried to SUBST a drive to a directory on a joined drive.                                                                                                               #define ERROR_SUBST_TO_JOIN              141

// The system cannot perform a JOIN or SUBST at this time.                                                                                                                           #define ERROR_BUSY_DRIVE                 142

// The system cannot join or substitute a drive to or for a directory on the same drive.                                                                                             #define ERROR_SAME_DRIVE                 143

// The directory is not a subdirectory of the root directory.                                                                                                                        #define ERROR_DIR_NOT_ROOT               144

// The directory is not empty.                                                                                                                                                       #define ERROR_DIR_NOT_EMPTY              145

// The path specified is being used in a substitute.                                                                                                                                 #define ERROR_IS_SUBST_PATH              146

// Not enough resources are available to process this command.                                                                                                                       #define ERROR_IS_JOIN_PATH               147

// The path specified cannot be used at this time.                                                                                                                                   #define ERROR_PATH_BUSY                  148

// An attempt was made to join or substitute a drive for which a directory on the drive is the target of a previous substitute.                                                      #define ERROR_IS_SUBST_TARGET            149

// System trace information was not specified in your CONFIG.SYS file, or tracing is disallowed.                                                                                     #define ERROR_SYSTEM_TRACE               150

// The number of specified semaphore events for DosMuxSemWait is not correct.                                                                                                        #define ERROR_INVALID_EVENT_COUNT        151

// DosMuxSemWait did not execute; too many semaphores are already set.                                                                                                               #define ERROR_TOO_MANY_MUXWAITERS        152

// The DosMuxSemWait list is not correct.                                                                                                                                            #define ERROR_INVALID_LIST_FORMAT        153

// The volume label you entered exceeds the label character limit of the target file system.                                                                                         #define ERROR_LABEL_TOO_LONG             154

// Cannot create another thread.                                                                                                                                                     #define ERROR_TOO_MANY_TCBS              155

// The recipient process has refused the signal.                                                                                                                                     #define ERROR_SIGNAL_REFUSED             156

// The segment is already discarded and cannot be locked.                                                                                                                            #define ERROR_DISCARDED                  157

// The segment is already unlocked.                                                                                                                                                  #define ERROR_NOT_LOCKED                 158

// The address for the thread ID is not correct.                                                                                                                                     #define ERROR_BAD_THREADID_ADDR          159

// The argument string passed to DosExecPgm is not correct.                                                                                                                          #define ERROR_BAD_ARGUMENTS              160

// The specified path is invalid.                                                                                                                                                    #define ERROR_BAD_PATHNAME               161

// A signal is already pending.                                                                                                                                                      #define ERROR_SIGNAL_PENDING             162

// No more threads can be created in the system.                                                                                                                                     #define ERROR_MAX_THRDS_REACHED          164

// Unable to lock a region of a file.                                                                                                                                                #define ERROR_LOCK_FAILED                167

// The requested resource is in use.                                                                                                                                                 #define ERROR_BUSY                       170

// A lock request was not outstanding for the supplied cancel region.                                                                                                                #define ERROR_CANCEL_VIOLATION           173

// The file system does not support atomic changes to the lock type.                                                                                                                 #define ERROR_ATOMIC_LOCKS_NOT_SUPPORTED 174

// The system detected a segment number that was not correct.                                                                                                                        #define ERROR_INVALID_SEGMENT_NUMBER     180

// The operating system cannot run %1.                                                                                                                                               #define ERROR_INVALID_ORDINAL            182

// Cannot create a file when that file already exists.                                                                                                                               #define ERROR_ALREADY_EXISTS             183

// The flag passed is not correct.                                                                                                                                                   #define ERROR_INVALID_FLAG_NUMBER        186

// The specified system semaphore name was not found.                                                                                                                                #define ERROR_SEM_NOT_FOUND              187

// The operating system cannot run %1.                                                                                                                                               #define ERROR_INVALID_STARTING_CODESEG   188

// The operating system cannot run %1.                                                                                                                                               #define ERROR_INVALID_STACKSEG           189

// The operating system cannot run %1.                                                                                                                                               #define ERROR_INVALID_MODULETYPE         190

// Cannot run %1 in Win32 mode.                                                                                                                                                      #define ERROR_INVALID_EXE_SIGNATURE      191

// The operating system cannot run %1.                                                                                                                                               #define ERROR_EXE_MARKED_INVALID         192

// %1 is not a valid Win32 application.                                                                                                                                              #define ERROR_BAD_EXE_FORMAT             193

// The operating system cannot run %1.                                                                                                                                               #define ERROR_ITERATED_DATA_EXCEEDS_64k  194

// The operating system cannot run %1.                                                                                                                                               #define ERROR_INVALID_MINALLOCSIZE       195

// The operating system cannot run this application program.                                                                                                                         #define ERROR_DYNLINK_FROM_INVALID_RING  196

// The operating system is not presently configured to run this application.                                                                                                         #define ERROR_IOPL_NOT_ENABLED           197

// The operating system cannot run %1.                                                                                                                                               #define ERROR_INVALID_SEGDPL             198

// The operating system cannot run this application program.                                                                                                                         #define ERROR_AUTODATASEG_EXCEEDS_64k    199

// The code segment cannot be greater than or equal to 64K.                                                                                                                          #define ERROR_RING2SEG_MUST_BE_MOVABLE   200

// The operating system cannot run %1.                                                                                                                                               #define ERROR_RELOC_CHAIN_XEEDS_SEGLIM   201

// The operating system cannot run %1.                                                                                                                                               #define ERROR_INFLOOP_IN_RELOC_CHAIN     202

// The system could not find the environment option that was entered.                                                                                                                #define ERROR_ENVVAR_NOT_FOUND           203

// No process in the command subtree has a signal handler.                                                                                                                           #define ERROR_NO_SIGNAL_SENT             205

// The filename or extension is too long.                                                                                                                                            #define ERROR_FILENAME_EXCED_RANGE       206

// The ring 2 stack is in use.                                                                                                                                                       #define ERROR_RING2_STACK_IN_USE         207

// The global filename characters, * or ?, are entered incorrectly or too many global filename characters are specified.                                                             #define ERROR_META_EXPANSION_TOO_LONG    208

// The signal being posted is not correct.                                                                                                                                           #define ERROR_INVALID_SIGNAL_NUMBER      209

// The signal handler cannot be set.                                                                                                                                                 #define ERROR_THREAD_1_INACTIVE          210

// The segment is locked and cannot be reallocated.                                                                                                                                  #define ERROR_LOCKED                     212

// Too many dynamic-link modules are attached to this program or dynamic-link module.                                                                                                #define ERROR_TOO_MANY_MODULES           214

// Can't nest calls to LoadModule.                                                                                                                                                   #define ERROR_NESTING_NOT_ALLOWED        215

// The image file %1 is valid, but is for a machine type other than the current machine.                                                                                             #define ERROR_EXE_MACHINE_TYPE_MISMATCH  216

// The pipe state is invalid.                                                                                                                                                        #define ERROR_BAD_PIPE                   230

// All pipe instances are busy.                                                                                                                                                      #define ERROR_PIPE_BUSY                  231

// The pipe is being closed.                                                                                                                                                         #define ERROR_NO_DATA                    232

// No process is on the other end of the pipe.                                                                                                                                       #define ERROR_PIPE_NOT_CONNECTED         233

// More data is available.                                                                                                                                                           #define ERROR_MORE_DATA                  234

// The session was canceled.                                                                                                                                                         #define ERROR_VC_DISCONNECTED            240

// The specified extended attribute name was invalid.                                                                                                                                #define ERROR_INVALID_EA_NAME            254

// The extended attributes are inconsistent.                                                                                                                                         #define ERROR_EA_LIST_INCONSISTENT       255

// No more data is available.                                                                                                                                                        #define ERROR_NO_MORE_ITEMS              259

// The copy functions cannot be used.                                                                                                                                                #define ERROR_CANNOT_COPY                266

// The directory name is invalid.                                                                                                                                                    #define ERROR_DIRECTORY                  267

// The extended attributes did not fit in the buffer.                                                                                                                                #define ERROR_EAS_DIDNT_FIT              275

// The extended attribute file on the mounted file system is corrupt.                                                                                                                #define ERROR_EA_FILE_CORRUPT            276

// The extended attribute table file is full.                                                                                                                                        #define ERROR_EA_TABLE_FULL              277

// The specified extended attribute handle is invalid.                                                                                                                               #define ERROR_INVALID_EA_HANDLE          278

// The mounted file system does not support extended attributes.                                                                                                                     #define ERROR_EAS_NOT_SUPPORTED          282

// Attempt to release mutex not owned by caller.                                                                                                                                     #define ERROR_NOT_OWNER                  288

// Too many posts were made to a semaphore.                                                                                                                                          #define ERROR_TOO_MANY_POSTS             298

// Only part of a ReadProcessMemoty or WriteProcessMemory request was completed.                                                                                                     #define ERROR_PARTIAL_COPY               299

// The oplock request is denied.                                                                                                                                                     #define ERROR_OPLOCK_NOT_GRANTED         300

// An invalid oplock acknowledgment was received by the system.                                                                                                                      #define ERROR_INVALID_OPLOCK_PROTOCOL    301

// The system cannot find message text for message number 0x%1 in the message file for %2.                                                                                           #define ERROR_MR_MID_NOT_FOUND           317

// Attempt to access invalid address.                                                                                                                                                #define ERROR_INVALID_ADDRESS            487

// Arithmetic result exceeded 32 bits.                                                                                                                                               #define ERROR_ARITHMETIC_OVERFLOW        534

// There is a process on other end of the pipe.                                                                                                                                      #define ERROR_PIPE_CONNECTED             535

// Waiting for a process to open the other end of the pipe.                                                                                                                          #define ERROR_PIPE_LISTENING             536

// Access to the extended attribute was denied.                                                                                                                                      #define ERROR_EA_ACCESS_DENIED           994

// The I/O operation has been aborted because of either a thread exit or an application request.                                                                                     #define ERROR_OPERATION_ABORTED          995

// Overlapped I/O event is not in a signaled state.                                                                                                                                  #define ERROR_IO_INCOMPLETE              996

// Overlapped I/O operation is in progress.                                                                                                                                          #define ERROR_IO_PENDING                 997

// Invalid access to memory location.                                                                                                                                                #define ERROR_NOACCESS                   998

// Error performing inpage operation.                                                                                                                                                #define ERROR_SWAPERROR                  999

// Recursion too deep; the stack overflowed.                                                                                                                                         #define ERROR_STACK_OVERFLOW             1001

// The window cannot act on the sent message.                                                                                                                                        #define ERROR_INVALID_MESSAGE            1002

// Cannot complete this function.                                                                                                                                                    #define ERROR_CAN_NOT_COMPLETE           1003

// Invalid flags.                                                                                                                                                                    #define ERROR_INVALID_FLAGS              1004

// The volume does not contain a recognized file system.                                                                                                                             #define ERROR_UNRECOGNIZED_VOLUME        1005

// The volume for a file has been externally altered so that the opened file is no longer valid.                                                                                     #define ERROR_FILE_INVALID               1006

// The requested operation cannot be performed in full-screen mode.                                                                                                                  #define ERROR_FULLSCREEN_MODE            1007

// An attempt was made to reference a token that does not exist.                                                                                                                     #define ERROR_NO_TOKEN                   1008

// The configuration registry database is corrupt.                                                                                                                                   #define ERROR_BADDB                      1009

// The configuration registry key is invalid.                                                                                                                                        #define ERROR_BADKEY                     1010

// The configuration registry key could not be opened.                                                                                                                               #define ERROR_CANTOPEN                   1011

// The configuration registry key could not be read.                                                                                                                                 #define ERROR_CANTREAD                   1012

// The configuration registry key could not be written.                                                                                                                              #define ERROR_CANTWRITE                  1013

// One of the files in the registry database had to be recovered by use of a log or alternate copy.  The recovery was successful.                                                    #define ERROR_REGISTRY_RECOVERED         1014

// The registry is corrupted.                                                                                                                                                        #define ERROR_REGISTRY_CORRUPT           1015

// An I/O operation initiated by the registry failed unrecoverably.                                                                                                                  #define ERROR_REGISTRY_IO_FAILED         1016

// The system has attempted to load or restore a file into the registry, but the specified file is not in a registry file format.                                                    #define ERROR_NOT_REGISTRY_FILE          1017

// Illegal operation attempted on a registry key that has been marked for deletion.                                                                                                  #define ERROR_KEY_DELETED                1018

// System could not allocate the required space in a registry log.                                                                                                                   #define ERROR_NO_LOG_SPACE               1019

// Cannot create a symbolic link in a registry key that already has subkeys or values.                                                                                               #define ERROR_KEY_HAS_CHILDREN           1020

// Cannot create a stable subkey under a volatile parent key.                                                                                                                        #define ERROR_CHILD_MUST_BE_VOLATILE     1021

// A notify change request is being completed and the information is not being returned in the caller's buffer.  The caller now needs to enumerate the files to find the changes.    #define ERROR_NOTIFY_ENUM_DIR            1022

// A stop control has been sent to a service that other running services are dependent on.                                                                                           #define ERROR_DEPENDENT_SERVICES_RUNNING 1051

// The requested control is not valid for this service.                                                                                                                              #define ERROR_INVALID_SERVICE_CONTROL    1052

// The service did not respond to the start or control request in a timely fashion.                                                                                                  #define ERROR_SERVICE_REQUEST_TIMEOUT    1053

// A thread could not be created for the service.                                                                                                                                    #define ERROR_SERVICE_NO_THREAD          1054

// The service database is locked.                                                                                                                                                   #define ERROR_SERVICE_DATABASE_LOCKED    1055

// An instance of the service is already running.                                                                                                                                    #define ERROR_SERVICE_ALREADY_RUNNING    1056

// The account name is invalid or does not exist.                                                                                                                                    #define ERROR_INVALID_SERVICE_ACCOUNT    1057

// The service cannot be started, either because it is disabled or because it has no enabled devices associated with it.                                                             #define ERROR_SERVICE_DISABLED           1058

// Circular service dependency was specified.                                                                                                                                        #define ERROR_CIRCULAR_DEPENDENCY        1059

// The specified service does not exist as an installed service.                                                                                                                     #define ERROR_SERVICE_DOES_NOT_EXIST     1060

// The service cannot accept control messages at this time.                                                                                                                          #define ERROR_SERVICE_CANNOT_ACCEPT_CTRL 1061

// The service has not been started.                                                                                                                                                 #define ERROR_SERVICE_NOT_ACTIVE         1062

// The service process could not connect to the service controller.                                                                                                                  #define ERROR_FAILED_SERVICE_CONTROLLER_CONNECT 1063

// An exception occurred in the service when handling the control request.                                                                                                           #define ERROR_EXCEPTION_IN_SERVICE       1064

// The database specified does not exist.                                                                                                                                            #define ERROR_DATABASE_DOES_NOT_EXIST    1065

// The service has returned a service-specific error code.                                                                                                                           #define ERROR_SERVICE_SPECIFIC_ERROR     1066

// The process terminated unexpectedly.                                                                                                                                              #define ERROR_PROCESS_ABORTED            1067

// The dependency service or group failed to start.                                                                                                                                  #define ERROR_SERVICE_DEPENDENCY_FAIL    1068

// The service did not start due to a logon failure.                                                                                                                                 #define ERROR_SERVICE_LOGON_FAILED       1069

// After starting, the service hung in a start-pending state.                                                                                                                        #define ERROR_SERVICE_START_HANG         1070

// The specified service database lock is invalid.                                                                                                                                   #define ERROR_INVALID_SERVICE_LOCK       1071

// The specified service has been marked for deletion.                                                                                                                               #define ERROR_SERVICE_MARKED_FOR_DELETE  1072

// The specified service already exists.                                                                                                                                             #define ERROR_SERVICE_EXISTS             1073

// The system is currently running with the last-known-good configuration.                                                                                                           #define ERROR_ALREADY_RUNNING_LKG        1074

// The dependency service does not exist or has been marked for deletion.                                                                                                            #define ERROR_SERVICE_DEPENDENCY_DELETED 1075

// The current boot has already been accepted for use as the last-known-good control set.                                                                                            #define ERROR_BOOT_ALREADY_ACCEPTED      1076

// No attempts to start the service have been made since the last boot.                                                                                                              #define ERROR_SERVICE_NEVER_STARTED      1077

// The name is already in use as either a service name or a service display name.                                                                                                    #define ERROR_DUPLICATE_SERVICE_NAME     1078

// The account specified for this service is different from the account specified for other services running in the same process.                                                    #define ERROR_DIFFERENT_SERVICE_ACCOUNT  1079

// Failure actions can only be set for Win32 services, not for drivers.                                                                                                              #define ERROR_CANNOT_DETECT_DRIVER_FAILURE 1080

// This service runs in the same process as the service control manager.                                                                                                             #define ERROR_CANNOT_DETECT_PROCESS_ABORT 1081

// No recovery program has been configured for this service.                                                                                                                         #define ERROR_NO_RECOVERY_PROGRAM        1082

// The physical end of the tape has been reached.                                                                                                                                    #define ERROR_END_OF_MEDIA               1100

// A tape access reached a filemark.                                                                                                                                                 #define ERROR_FILEMARK_DETECTED          1101

// The beginning of the tape or a partition was encountered.                                                                                                                         #define ERROR_BEGINNING_OF_MEDIA         1102

// A tape access reached the end of a set of files.                                                                                                                                  #define ERROR_SETMARK_DETECTED           1103

// No more data is on the tape.                                                                                                                                                      #define ERROR_NO_DATA_DETECTED           1104

// Tape could not be partitioned.                                                                                                                                                    #define ERROR_PARTITION_FAILURE          1105

// When accessing a new tape of a multivolume partition, the current blocksize is incorrect.                                                                                         #define ERROR_INVALID_BLOCK_LENGTH       1106

// Tape partition information could not be found when loading a tape.                                                                                                                #define ERROR_DEVICE_NOT_PARTITIONED     1107

// Unable to lock the media eject mechanism.                                                                                                                                         #define ERROR_UNABLE_TO_LOCK_MEDIA       1108

// Unable to unload the media.                                                                                                                                                       #define ERROR_UNABLE_TO_UNLOAD_MEDIA     1109

// The media in the drive may have changed.                                                                                                                                          #define ERROR_MEDIA_CHANGED              1110

// The I/O bus was reset.                                                                                                                                                            #define ERROR_BUS_RESET                  1111

// No media in drive.                                                                                                                                                                #define ERROR_NO_MEDIA_IN_DRIVE          1112

// No mapping for the Unicode character exists in the target multi-byte code page.                                                                                                   #define ERROR_NO_UNICODE_TRANSLATION     1113

// A DLL initialization routine failed.                                                                                                                                              #define ERROR_DLL_INIT_FAILED            1114

// A system shutdown is in progress.                                                                                                                                                 #define ERROR_SHUTDOWN_IN_PROGRESS       1115

// Unable to abort the system shutdown because no shutdown was in progress.                                                                                                          #define ERROR_NO_SHUTDOWN_IN_PROGRESS    1116

// The request could not be performed because of an I/O device error.                                                                                                                #define ERROR_IO_DEVICE                  1117

// No serial device was successfully initialized.  The serial driver will unload.                                                                                                    #define ERROR_SERIAL_NO_DEVICE           1118

// Unable to open a device that was sharing an interrupt request (IRQ) with other devices.  At least one other device that uses that IRQ was already opened.                         #define ERROR_IRQ_BUSY                   1119

// A serial I/O operation was completed by another write to the serial port (the IOCTL_SERIAL_XOFF_COUNTER reached zero).                                                            #define ERROR_MORE_WRITES                1120

// A serial I/O operation completed because the timeout period expired (the IOCTL_SERIAL_XOFF_COUNTER did not reach zero).                                                           #define ERROR_COUNTER_TIMEOUT            1121

// No ID address mark was found on the floppy disk.                                                                                                                                  #define ERROR_FLOPPY_ID_MARK_NOT_FOUND   1122

// Mismatch between the floppy disk sector ID field and the floppy disk controller track address.                                                                                    #define ERROR_FLOPPY_WRONG_CYLINDER      1123

// The floppy disk controller reported an error that is not recognized by the floppy disk driver.                                                                                    #define ERROR_FLOPPY_UNKNOWN_ERROR       1124

// The floppy disk controller returned inconsistent results in its registers.                                                                                                        #define ERROR_FLOPPY_BAD_REGISTERS       1125

// While accessing the hard disk, a recalibrate operation failed, even after retries.                                                                                                #define ERROR_DISK_RECALIBRATE_FAILED    1126

// While accessing the hard disk, a disk operation failed even after retries.                                                                                                        #define ERROR_DISK_OPERATION_FAILED      1127

// While accessing the hard disk, a disk controller reset was needed, but even that failed.                                                                                          #define ERROR_DISK_RESET_FAILED          1128

// Physical end of tape encountered.                                                                                                                                                 #define ERROR_EOM_OVERFLOW               1129

// Not enough server storage is available to process this command.                                                                                                                   #define ERROR_NOT_ENOUGH_SERVER_MEMORY   1130

// A potential deadlock condition has been detected.                                                                                                                                 #define ERROR_POSSIBLE_DEADLOCK          1131

// The base address or the file offset specified does not have the proper alignment.                                                                                                 #define ERROR_MAPPED_ALIGNMENT           1132

// An attempt to change the system power state was vetoed by another application or driver.                                                                                          #define ERROR_SET_POWER_STATE_VETOED     1140

// The system BIOS failed an attempt to change the system power state.                                                                                                               #define ERROR_SET_POWER_STATE_FAILED     1141

// An attempt was made to create more links on a file than the file system supports.                                                                                                 #define ERROR_TOO_MANY_LINKS             1142

// The specified program requires a newer version of Windows.                                                                                                                        #define ERROR_OLD_WIN_VERSION            1150

// The specified program is not a Windows or MS-DOS program.                                                                                                                         #define ERROR_APP_WRONG_OS               1151

// Cannot start more than one instance of the specified program.                                                                                                                     #define ERROR_SINGLE_INSTANCE_APP        1152

// The specified program was written for an earlier version of Windows.                                                                                                              #define ERROR_RMODE_APP                  1153

// One of the library files needed to run this application is damaged.                                                                                                               #define ERROR_INVALID_DLL                1154

// No application is associated with the specified file for this operation.                                                                                                          #define ERROR_NO_ASSOCIATION             1155

// An error occurred in sending the command to the application.                                                                                                                      #define ERROR_DDE_FAIL                   1156

// One of the library files needed to run this application cannot be found.                                                                                                          #define ERROR_DLL_NOT_FOUND              1157

// The current process has used all of its system allowance of handles for Window Manager objects.                                                                                   #define ERROR_NO_MORE_USER_HANDLES       1158

// The message can be used only with synchronous operations.                                                                                                                         #define ERROR_MESSAGE_SYNC_ONLY          1159

// The indicated source element has no media.                                                                                                                                        #define ERROR_SOURCE_ELEMENT_EMPTY       1160

// The indicated destination element already contains media.                                                                                                                         #define ERROR_DESTINATION_ELEMENT_FULL   1161

// The indicated element does not exist.                                                                                                                                             #define ERROR_ILLEGAL_ELEMENT_ADDRESS    1162

// The indicated element is part of a magazine that is not present.                                                                                                                  #define ERROR_MAGAZINE_NOT_PRESENT       1163

// The indicated device requires reinitialization due to hardware errors.                                                                                                            #define ERROR_DEVICE_REINITIALIZATION_NEEDED 1164

// The device has indicated that cleaning is required before further operations are attempted.                                                                                       #define ERROR_DEVICE_REQUIRES_CLEANING   1165

// The device has indicated that its door is open.                                                                                                                                   #define ERROR_DEVICE_DOOR_OPEN           1166

// The device is not connected.                                                                                                                                                      #define ERROR_DEVICE_NOT_CONNECTED       1167

// Element not found.                                                                                                                                                                #define ERROR_NOT_FOUND                  1168

// There was no match for the specified key in the index.                                                                                                                            #define ERROR_NO_MATCH                   1169

// The property set specified does not exist on the object.                                                                                                                          #define ERROR_SET_NOT_FOUND              1170

// The point passed to GetMouseMovePoints is not in the buffer.                                                                                                                      #define ERROR_POINT_NOT_FOUND            1171

// The tracking (workstation) service is not running.                                                                                                                                #define ERROR_NO_TRACKING_SERVICE        1172

// The Volume ID could not be found.                                                                                                                                                 #define ERROR_NO_VOLUME_ID               1173

//
// Winnet32 Status Codes
//

// The network connection was made successfully, but the user had to be prompted for a password other than the one originally specified.                                             #define ERROR_CONNECTED_OTHER_PASSWORD   2108

// The specified username is invalid.                                                                                                                                                #define ERROR_BAD_USERNAME               2202

// This network connection does not exist.                                                                                                                                           #define ERROR_NOT_CONNECTED              2250

// This network connection has files open or requests pending.                                                                                                                       #define ERROR_OPEN_FILES                 2401

// Active connections still exist.                                                                                                                                                   #define ERROR_ACTIVE_CONNECTIONS         2402

// The device is in use by an active process and cannot be disconnected.                                                                                                             #define ERROR_DEVICE_IN_USE              2404

// The specified device name is invalid.                                                                                                                                             #define ERROR_BAD_DEVICE                 1200

// The device is not currently connected but it is a remembered connection.                                                                                                          #define ERROR_CONNECTION_UNAVAIL         1201

// An attempt was made to remember a device that had previously been remembered.                                                                                                     #define ERROR_DEVICE_ALREADY_REMEMBERED  1202

// No network provider accepted the given network path.                                                                                                                              #define ERROR_NO_NET_OR_BAD_PATH         1203

// The specified network provider name is invalid.                                                                                                                                   #define ERROR_BAD_PROVIDER               1204

// Unable to open the network connection profile.                                                                                                                                    #define ERROR_CANNOT_OPEN_PROFILE        1205

// The network connection profile is corrupted.                                                                                                                                      #define ERROR_BAD_PROFILE                1206

// Cannot enumerate a noncontainer.                                                                                                                                                  #define ERROR_NOT_CONTAINER              1207

// An extended error has occurred.                                                                                                                                                   #define ERROR_EXTENDED_ERROR             1208

// The format of the specified group name is invalid.                                                                                                                                #define ERROR_INVALID_GROUPNAME          1209

// The format of the specified computer name is invalid.                                                                                                                             #define ERROR_INVALID_COMPUTERNAME       1210

// The format of the specified event name is invalid.                                                                                                                                #define ERROR_INVALID_EVENTNAME          1211

// The format of the specified domain name is invalid.                                                                                                                               #define ERROR_INVALID_DOMAINNAME         1212

// The format of the specified service name is invalid.                                                                                                                              #define ERROR_INVALID_SERVICENAME        1213

// The format of the specified network name is invalid.                                                                                                                              #define ERROR_INVALID_NETNAME            1214

// The format of the specified share name is invalid.                                                                                                                                #define ERROR_INVALID_SHARENAME          1215

// The format of the specified password is invalid.                                                                                                                                  #define ERROR_INVALID_PASSWORDNAME       1216

// The format of the specified message name is invalid.                                                                                                                              #define ERROR_INVALID_MESSAGENAME        1217

// The format of the specified message destination is invalid.                                                                                                                       #define ERROR_INVALID_MESSAGEDEST        1218

// The credentials supplied conflict with an existing set of credentials.                                                                                                            #define ERROR_SESSION_CREDENTIAL_CONFLICT 1219

// An attempt was made to establish a session to a network server, but there are already too many sessions established to that server.                                               #define ERROR_REMOTE_SESSION_LIMIT_EXCEEDED 1220

// The workgroup or domain name is already in use by another computer on the network.                                                                                                #define ERROR_DUP_DOMAINNAME             1221

// The network is not present or not started.                                                                                                                                        #define ERROR_NO_NETWORK                 1222

// The operation was canceled by the user.                                                                                                                                           #define ERROR_CANCELLED                  1223

// The requested operation cannot be performed on a file with a user-mapped section open.                                                                                            #define ERROR_USER_MAPPED_FILE           1224

// The remote system refused the network connection.                                                                                                                                 #define ERROR_CONNECTION_REFUSED         1225

// The network connection was gracefully closed.                                                                                                                                     #define ERROR_GRACEFUL_DISCONNECT        1226

// The network transport endpoint already has an address associated with it.                                                                                                         #define ERROR_ADDRESS_ALREADY_ASSOCIATED 1227

// An address has not yet been associated with the network endpoint.                                                                                                                 #define ERROR_ADDRESS_NOT_ASSOCIATED     1228

// An operation was attempted on a nonexistent network connection.                                                                                                                   #define ERROR_CONNECTION_INVALID         1229

// An invalid operation was attempted on an active network connection.                                                                                                               #define ERROR_CONNECTION_ACTIVE          1230

// The remote network is not reachable by the transport.                                                                                                                             #define ERROR_NETWORK_UNREACHABLE        1231

// The remote system is not reachable by the transport.                                                                                                                              #define ERROR_HOST_UNREACHABLE           1232

// The remote system does not support the transport protocol.                                                                                                                        #define ERROR_PROTOCOL_UNREACHABLE       1233

// No service is operating at the destination network endpoint on the remote system.                                                                                                 #define ERROR_PORT_UNREACHABLE           1234

// The request was aborted.                                                                                                                                                          #define ERROR_REQUEST_ABORTED            1235

// The network connection was aborted by the local system.                                                                                                                           #define ERROR_CONNECTION_ABORTED         1236

// The operation could not be completed.  A retry should be performed.                                                                                                               #define ERROR_RETRY                      1237

// A connection to the server could not be made because the limit on the number of concurrent connections for this account has been reached.                                         #define ERROR_CONNECTION_COUNT_LIMIT     1238

// Attempting to log in during an unauthorized time of day for this account.                                                                                                         #define ERROR_LOGIN_TIME_RESTRICTION     1239

// The account is not authorized to log in from this station.                                                                                                                        #define ERROR_LOGIN_WKSTA_RESTRICTION    1240

// The network address could not be used for the operation requested.                                                                                                                #define ERROR_INCORRECT_ADDRESS          1241

// The service is already registered.                                                                                                                                                #define ERROR_ALREADY_REGISTERED         1242

// The specified service does not exist.                                                                                                                                             #define ERROR_SERVICE_NOT_FOUND          1243

// The operation being requested was not performed because the user has not been authenticated.                                                                                      #define ERROR_NOT_AUTHENTICATED          1244

// The operation being requested was not performed because the user has not logged on to the network.  The specified service does not exist.                                         #define ERROR_NOT_LOGGED_ON              1245

// Continue with work in progress.                                                                                                                                                   #define ERROR_CONTINUE                   1246

// An attempt was made to perform an initialization operation when initialization has already been completed.                                                                        #define ERROR_ALREADY_INITIALIZED        1247

// No more local devices.                                                                                                                                                            #define ERROR_NO_MORE_DEVICES            1248

// The specified site does not exist.                                                                                                                                                #define ERROR_NO_SUCH_SITE               1249

// A domain controller with the specified name already exists.                                                                                                                       #define ERROR_DOMAIN_CONTROLLER_EXISTS   1250

// An error occurred while installing the Windows NT directory service.  Please view the event log for more information.                                                             #define ERROR_DS_NOT_INSTALLED           1251

//
// Security Status Codes
//

// Not all privileges referenced are assigned to the caller.                                                                                                                         #define ERROR_NOT_ALL_ASSIGNED           1300

// Some mapping between account names and security IDs was not done.                                                                                                                 #define ERROR_SOME_NOT_MAPPED            1301

// No system quota limits are specifically set for this account.                                                                                                                     #define ERROR_NO_QUOTAS_FOR_ACCOUNT      1302

// No encryption key is available.  A well-known encryption key was returned.                                                                                                        #define ERROR_LOCAL_USER_SESSION_KEY     1303

// The Windows NT password is too complex to be converted to a LAN Manager password.  The LAN Manager password returned is a NULL string.                                            #define ERROR_NULL_LM_PASSWORD           1304

// The revision level is unknown.                                                                                                                                                    #define ERROR_UNKNOWN_REVISION           1305

// Indicates two revision levels are incompatible.                                                                                                                                   #define ERROR_REVISION_MISMATCH          1306

// This security ID may not be assigned as the owner of this object.                                                                                                                 #define ERROR_INVALID_OWNER              1307

// This security ID may not be assigned as the primary group of an object.                                                                                                           #define ERROR_INVALID_PRIMARY_GROUP      1308

// An attempt has been made to operate on an impersonation token by a thread that is not currently impersonating a client.                                                           #define ERROR_NO_IMPERSONATION_TOKEN     1309

// The group may not be disabled.                                                                                                                                                    #define ERROR_CANT_DISABLE_MANDATORY     1310

// There are currently no logon servers available to service the logon request.                                                                                                      #define ERROR_NO_LOGON_SERVERS           1311

// A specified logon session does not exist.  It may already have been terminated.                                                                                                   #define ERROR_NO_SUCH_LOGON_SESSION      1312

// A specified privilege does not exist.                                                                                                                                             #define ERROR_NO_SUCH_PRIVILEGE          1313

// A required privilege is not held by the client.                                                                                                                                   #define ERROR_PRIVILEGE_NOT_HELD         1314

// The name provided is not a properly formed account name.                                                                                                                          #define ERROR_INVALID_ACCOUNT_NAME       1315

// The specified user already exists.                                                                                                                                                #define ERROR_USER_EXISTS                1316

// The specified user does not exist.                                                                                                                                                #define ERROR_NO_SUCH_USER               1317

// The specified group already exists.                                                                                                                                               #define ERROR_GROUP_EXISTS               1318

// The specified group does not exist.                                                                                                                                               #define ERROR_NO_SUCH_GROUP              1319

// Either the specified user account is already a member of the specified group, or the specified group cannot be deleted because it contains a member.                              #define ERROR_MEMBER_IN_GROUP            1320

// The specified user account is not a member of the specified group account.                                                                                                        #define ERROR_MEMBER_NOT_IN_GROUP        1321

// The last remaining administration account cannot be disabled or deleted.                                                                                                          #define ERROR_LAST_ADMIN                 1322

// Unable to update the password.  The value provided as the current password is incorrect.                                                                                          #define ERROR_WRONG_PASSWORD             1323

// Unable to update the password.  The value provided for the new password contains values that are not allowed in passwords.                                                        #define ERROR_ILL_FORMED_PASSWORD        1324

// Unable to update the password because a password update rule has been violated.                                                                                                   #define ERROR_PASSWORD_RESTRICTION       1325

// Logon failure: unknown user name or bad password.                                                                                                                                 #define ERROR_LOGON_FAILURE              1326

// Logon failure: user account restriction.                                                                                                                                          #define ERROR_ACCOUNT_RESTRICTION        1327

// Logon failure: account logon time restriction violation.                                                                                                                          #define ERROR_INVALID_LOGON_HOURS        1328

// Logon failure: user not allowed to log on to this computer.                                                                                                                       #define ERROR_INVALID_WORKSTATION        1329

// Logon failure: the specified account password has expired.                                                                                                                        #define ERROR_PASSWORD_EXPIRED           1330

// Logon failure: account currently disabled.                                                                                                                                        #define ERROR_ACCOUNT_DISABLED           1331

// No mapping between account names and security IDs was done.                                                                                                                       #define ERROR_NONE_MAPPED                1332

// Too many local user identifiers (LUIDs) were requested at one time.                                                                                                               #define ERROR_TOO_MANY_LUIDS_REQUESTED   1333

// No more local user identifiers (LUIDs) are available.                                                                                                                             #define ERROR_LUIDS_EXHAUSTED            1334

// The subauthority part of a security ID is invalid for this particular use.                                                                                                        #define ERROR_INVALID_SUB_AUTHORITY      1335

// The access control list (ACL) structure is invalid.                                                                                                                               #define ERROR_INVALID_ACL                1336

// The security ID structure is invalid.                                                                                                                                             #define ERROR_INVALID_SID                1337

// The security descriptor structure is invalid.                                                                                                                                     #define ERROR_INVALID_SECURITY_DESCR     1338

// The inherited access control list (ACL) or access control entry (ACE) could not be built.                                                                                         #define ERROR_BAD_INHERITANCE_ACL        1340

// The server is currently disabled.                                                                                                                                                 #define ERROR_SERVER_DISABLED            1341

// The server is currently enabled.                                                                                                                                                  #define ERROR_SERVER_NOT_DISABLED        1342

// The value provided was an invalid value for an identifier authority.                                                                                                              #define ERROR_INVALID_ID_AUTHORITY       1343

// No more memory is available for security information updates.                                                                                                                     #define ERROR_ALLOTTED_SPACE_EXCEEDED    1344

// The specified attributes are invalid, or incompatible with the attributes for the group as a whole.                                                                               #define ERROR_INVALID_GROUP_ATTRIBUTES   1345

// Either a required impersonation level was not provided, or the provided impersonation level is invalid.                                                                           #define ERROR_BAD_IMPERSONATION_LEVEL    1346

// Cannot open an anonymous level security token.                                                                                                                                    #define ERROR_CANT_OPEN_ANONYMOUS        1347

// The validation information class requested was invalid.                                                                                                                           #define ERROR_BAD_VALIDATION_CLASS       1348

// The type of the token is inappropriate for its attempted use.                                                                                                                     #define ERROR_BAD_TOKEN_TYPE             1349

// Unable to perform a security operation on an object that has no associated security.                                                                                              #define ERROR_NO_SECURITY_ON_OBJECT      1350

// Indicates a Windows NT Server could not be contacted or that objects within the domain are protected such that necessary information could not be retrieved.                      #define ERROR_CANT_ACCESS_DOMAIN_INFO    1351

// The security account manager (SAM) or local security authority (LSA) server was in the wrong state to perform the security operation.                                             #define ERROR_INVALID_SERVER_STATE       1352

// The domain was in the wrong state to perform the security operation.                                                                                                              #define ERROR_INVALID_DOMAIN_STATE       1353

// This operation is only allowed for the Primary Domain Controller of the domain.                                                                                                   #define ERROR_INVALID_DOMAIN_ROLE        1354

// The specified domain did not exist.                                                                                                                                               #define ERROR_NO_SUCH_DOMAIN             1355

// The specified domain already exists.                                                                                                                                              #define ERROR_DOMAIN_EXISTS              1356

// An attempt was made to exceed the limit on the number of domains per server.                                                                                                      #define ERROR_DOMAIN_LIMIT_EXCEEDED      1357

// Unable to complete the requested operation because of either a catastrophic media failure or a data structure corruption on the disk.                                             #define ERROR_INTERNAL_DB_CORRUPTION     1358

// The security account database contains an internal inconsistency.                                                                                                                 #define ERROR_INTERNAL_ERROR             1359

// Generic access types were contained in an access mask which should already be mapped to nongeneric types.                                                                         #define ERROR_GENERIC_NOT_MAPPED         1360

// A security descriptor is not in the right format (absolute or self-relative).                                                                                                     #define ERROR_BAD_DESCRIPTOR_FORMAT      1361

// The requested action is restricted for use by logon processes only.  The calling process has not registered as a logon process.                                                   #define ERROR_NOT_LOGON_PROCESS          1362

// Cannot start a new logon session with an ID that is already in use.                                                                                                               #define ERROR_LOGON_SESSION_EXISTS       1363

// A specified authentication package is unknown.                                                                                                                                    #define ERROR_NO_SUCH_PACKAGE            1364

// The logon session is not in a state that is consistent with the requested operation.                                                                                              #define ERROR_BAD_LOGON_SESSION_STATE    1365

// The logon session ID is already in use.                                                                                                                                           #define ERROR_LOGON_SESSION_COLLISION    1366

// A logon request contained an invalid logon type value.                                                                                                                            #define ERROR_INVALID_LOGON_TYPE         1367

// Unable to impersonate using a named pipe until data has been read from that pipe.                                                                                                 #define ERROR_CANNOT_IMPERSONATE         1368

// The transaction state of a registry subtree is incompatible with the requested operation.                                                                                         #define ERROR_RXACT_INVALID_STATE        1369

// An internal security database corruption has been encountered.                                                                                                                    #define ERROR_RXACT_COMMIT_FAILURE       1370

// Cannot perform this operation on built-in accounts.                                                                                                                               #define ERROR_SPECIAL_ACCOUNT            1371

// Cannot perform this operation on this built-in special group.                                                                                                                     #define ERROR_SPECIAL_GROUP              1372

// Cannot perform this operation on this built-in special user.                                                                                                                      #define ERROR_SPECIAL_USER               1373

// The user cannot be removed from a group because the group is currently the user's primary group.                                                                                  #define ERROR_MEMBERS_PRIMARY_GROUP      1374

// The token is already in use as a primary token.                                                                                                                                   #define ERROR_TOKEN_ALREADY_IN_USE       1375

// The specified local group does not exist.                                                                                                                                         #define ERROR_NO_SUCH_ALIAS              1376

// The specified account name is not a member of the local group.                                                                                                                    #define ERROR_MEMBER_NOT_IN_ALIAS        1377

// The specified account name is already a member of the local group.                                                                                                                #define ERROR_MEMBER_IN_ALIAS            1378

// The specified local group already exists.                                                                                                                                         #define ERROR_ALIAS_EXISTS               1379

// Logon failure: the user has not been granted the requested logon type at this computer.                                                                                           #define ERROR_LOGON_NOT_GRANTED          1380

// The maximum number of secrets that may be stored in a single system has been exceeded.                                                                                            #define ERROR_TOO_MANY_SECRETS           1381

// The length of a secret exceeds the maximum length allowed.                                                                                                                        #define ERROR_SECRET_TOO_LONG            1382

// The local security authority database contains an internal inconsistency.                                                                                                         #define ERROR_INTERNAL_DB_ERROR          1383

// During a logon attempt, the user's security context accumulated too many security IDs.                                                                                            #define ERROR_TOO_MANY_CONTEXT_IDS       1384

// Logon failure: the user has not been granted the requested logon type at this computer.                                                                                           #define ERROR_LOGON_TYPE_NOT_GRANTED     1385

// A cross-encrypted password is necessary to change a user password.                                                                                                                #define ERROR_NT_CROSS_ENCRYPTION_REQUIRED 1386

// A new member could not be added to a local group because the member does not exist.                                                                                               #define ERROR_NO_SUCH_MEMBER             1387

// A new member could not be added to a local group because the member has the wrong account type.                                                                                   #define ERROR_INVALID_MEMBER             1388

// Too many security IDs have been specified.                                                                                                                                        #define ERROR_TOO_MANY_SIDS              1389

// A cross-encrypted password is necessary to change this user password.                                                                                                             #define ERROR_LM_CROSS_ENCRYPTION_REQUIRED 1390

// Indicates an ACL contains no inheritable components.                                                                                                                              #define ERROR_NO_INHERITANCE             1391

// The file or directory is corrupted and unreadable.                                                                                                                                #define ERROR_FILE_CORRUPT               1392

// The disk structure is corrupted and unreadable.                                                                                                                                   #define ERROR_DISK_CORRUPT               1393

// There is no user session key for the specified logon session.                                                                                                                     #define ERROR_NO_USER_SESSION_KEY        1394

// The service being accessed is licensed for a particular number of connections.  No more connections can be made to the service at this time.                                      #define ERROR_LICENSE_QUOTA_EXCEEDED     1395

//
// WinUser Error Codes
//

// Invalid window handle.                                                                                                                                                            #define ERROR_INVALID_WINDOW_HANDLE      1400

// Invalid menu handle.                                                                                                                                                              #define ERROR_INVALID_MENU_HANDLE        1401

// Invalid cursor handle.                                                                                                                                                            #define ERROR_INVALID_CURSOR_HANDLE      1402

// Invalid accelerator table handle.                                                                                                                                                 #define ERROR_INVALID_ACCEL_HANDLE       1403

// Invalid hook handle.                                                                                                                                                              #define ERROR_INVALID_HOOK_HANDLE        1404

// Invalid handle to a multiple-window position structure.                                                                                                                           #define ERROR_INVALID_DWP_HANDLE         1405

// Cannot create a top-level child window.                                                                                                                                           #define ERROR_TLW_WITH_WSCHILD           1406

// Cannot find window class.                                                                                                                                                         #define ERROR_CANNOT_FIND_WND_CLASS      1407

// Invalid window; it belongs to other thread.                                                                                                                                       #define ERROR_WINDOW_OF_OTHER_THREAD     1408

// Hot key is already registered.                                                                                                                                                    #define ERROR_HOTKEY_ALREADY_REGISTERED  1409

// Class already exists.                                                                                                                                                             #define ERROR_CLASS_ALREADY_EXISTS       1410

// Class does not exist.                                                                                                                                                             #define ERROR_CLASS_DOES_NOT_EXIST       1411

// Class still has open windows.                                                                                                                                                     #define ERROR_CLASS_HAS_WINDOWS          1412

// Invalid index.                                                                                                                                                                    #define ERROR_INVALID_INDEX              1413

// Invalid icon handle.                                                                                                                                                              #define ERROR_INVALID_ICON_HANDLE        1414

// Using private DIALOG window words.                                                                                                                                                #define ERROR_PRIVATE_DIALOG_INDEX       1415

// The list box identifier was not found.                                                                                                                                            #define ERROR_LISTBOX_ID_NOT_FOUND       1416

// No wildcards were found.                                                                                                                                                          #define ERROR_NO_WILDCARD_CHARACTERS     1417

// Thread does not have a clipboard open.                                                                                                                                            #define ERROR_CLIPBOARD_NOT_OPEN         1418

// Hot key is not registered.                                                                                                                                                        #define ERROR_HOTKEY_NOT_REGISTERED      1419

// The window is not a valid dialog window.                                                                                                                                          #define ERROR_WINDOW_NOT_DIALOG          1420

// Control ID not found.                                                                                                                                                             #define ERROR_CONTROL_ID_NOT_FOUND       1421

// Invalid message for a combo box because it does not have an edit control.                                                                                                         #define ERROR_INVALID_COMBOBOX_MESSAGE   1422

// The window is not a combo box.                                                                                                                                                    #define ERROR_WINDOW_NOT_COMBOBOX        1423

// Height must be less than 256.                                                                                                                                                     #define ERROR_INVALID_EDIT_HEIGHT        1424

// Invalid device context (DC) handle.                                                                                                                                               #define ERROR_DC_NOT_FOUND               1425

// Invalid hook procedure type.                                                                                                                                                      #define ERROR_INVALID_HOOK_FILTER        1426

// Invalid hook procedure.                                                                                                                                                           #define ERROR_INVALID_FILTER_PROC        1427

// Cannot set nonlocal hook without a module handle.                                                                                                                                 #define ERROR_HOOK_NEEDS_HMOD            1428

// This hook procedure can only be set globally.                                                                                                                                     #define ERROR_GLOBAL_ONLY_HOOK           1429

// The journal hook procedure is already installed.                                                                                                                                  #define ERROR_JOURNAL_HOOK_SET           1430

// The hook procedure is not installed.                                                                                                                                              #define ERROR_HOOK_NOT_INSTALLED         1431

// Invalid message for single-selection list box.                                                                                                                                    #define ERROR_INVALID_LB_MESSAGE         1432

// LB_SETCOUNT sent to non-lazy list box.                                                                                                                                            #define ERROR_SETCOUNT_ON_BAD_LB         1433

// This list box does not support tab stops.                                                                                                                                         #define ERROR_LB_WITHOUT_TABSTOPS        1434

// Cannot destroy object created by another thread.                                                                                                                                  #define ERROR_DESTROY_OBJECT_OF_OTHER_THREAD 1435

// Child windows cannot have menus.                                                                                                                                                  #define ERROR_CHILD_WINDOW_MENU          1436

// The window does not have a system menu.                                                                                                                                           #define ERROR_NO_SYSTEM_MENU             1437

// Invalid message box style.                                                                                                                                                        #define ERROR_INVALID_MSGBOX_STYLE       1438

// Invalid system-wide (SPI_*) parameter.                                                                                                                                            #define ERROR_INVALID_SPI_VALUE          1439

// Screen already locked.                                                                                                                                                            #define ERROR_SCREEN_ALREADY_LOCKED      1440

// All handles to windows in a multiple-window position structure must have the same parent.                                                                                         #define ERROR_HWNDS_HAVE_DIFF_PARENT     1441

// The window is not a child window.                                                                                                                                                 #define ERROR_NOT_CHILD_WINDOW           1442

// Invalid GW_* command.                                                                                                                                                             #define ERROR_INVALID_GW_COMMAND         1443

// Invalid thread identifier.                                                                                                                                                        #define ERROR_INVALID_THREAD_ID          1444

// Cannot process a message from a window that is not a multiple document interface (MDI) window.                                                                                    #define ERROR_NON_MDICHILD_WINDOW        1445

// Popup menu already active.                                                                                                                                                        #define ERROR_POPUP_ALREADY_ACTIVE       1446

// The window does not have scroll bars.                                                                                                                                             #define ERROR_NO_SCROLLBARS              1447

// Scroll bar range cannot be greater than 0x7FFF.                                                                                                                                   #define ERROR_INVALID_SCROLLBAR_RANGE    1448

// Cannot show or remove the window in the way specified.                                                                                                                            #define ERROR_INVALID_SHOWWIN_COMMAND    1449

// Insufficient system resources exist to complete the requested service.                                                                                                            #define ERROR_NO_SYSTEM_RESOURCES        1450

// Insufficient system resources exist to complete the requested service.                                                                                                            #define ERROR_NONPAGED_SYSTEM_RESOURCES  1451

// Insufficient system resources exist to complete the requested service.                                                                                                            #define ERROR_PAGED_SYSTEM_RESOURCES     1452

// Insufficient quota to complete the requested service.                                                                                                                             #define ERROR_WORKING_SET_QUOTA          1453

// Insufficient quota to complete the requested service.                                                                                                                             #define ERROR_PAGEFILE_QUOTA             1454

// The paging file is too small for this operation to complete.                                                                                                                      #define ERROR_COMMITMENT_LIMIT           1455

// A menu item was not found.                                                                                                                                                        #define ERROR_MENU_ITEM_NOT_FOUND        1456

// Invalid keyboard layout handle.                                                                                                                                                   #define ERROR_INVALID_KEYBOARD_HANDLE    1457

// Hook type not allowed.                                                                                                                                                            #define ERROR_HOOK_TYPE_NOT_ALLOWED      1458

// This operation requires an interactive window station.                                                                                                                            #define ERROR_REQUIRES_INTERACTIVE_WINDOWSTATION 1459

// This operation returned because the timeout period expired.                                                                                                                       #define ERROR_TIMEOUT                    1460

// Invalid monitor handle.                                                                                                                                                           #define ERROR_INVALID_MONITOR_HANDLE     1461

//
// Eventlog Status Codes
//

// The event log file is corrupted.                                                                                                                                                  #define ERROR_EVENTLOG_FILE_CORRUPT      1500

// No event log file could be opened, so the event logging service did not start.                                                                                                    #define ERROR_EVENTLOG_CANT_START        1501

// The event log file is full.                                                                                                                                                       #define ERROR_LOG_FILE_FULL              1502

// The event log file has changed between read operations.                                                                                                                           #define ERROR_EVENTLOG_FILE_CHANGED      1503

//
// MSI Error Codes
//

// Failure accessing install service.                                                                                                                                                #define ERROR_INSTALL_SERVICE            1601

// The user canceled the installation.                                                                                                                                               #define ERROR_INSTALL_USEREXIT           1602

// Fatal error during installation.                                                                                                                                                  #define ERROR_INSTALL_FAILURE            1603

// Installation suspended, incomplete.                                                                                                                                               #define ERROR_INSTALL_SUSPEND            1604

// Product code not registered.                                                                                                                                                      #define ERROR_UNKNOWN_PRODUCT            1605

// Feature ID not registered.                                                                                                                                                        #define ERROR_UNKNOWN_FEATURE            1606

// Component ID not registered.                                                                                                                                                      #define ERROR_UNKNOWN_COMPONENT          1607

// Unknown property.                                                                                                                                                                 #define ERROR_UNKNOWN_PROPERTY           1608

// Handle is in an invalid state.                                                                                                                                                    #define ERROR_INVALID_HANDLE_STATE       1609

// Configuration data corrupt.                                                                                                                                                       #define ERROR_BAD_CONFIGURATION          1610

// Language not available.                                                                                                                                                           #define ERROR_INDEX_ABSENT               1611

// Install source unavailable.                                                                                                                                                       #define ERROR_INSTALL_SOURCE_ABSENT      1612

// Database version unsupported.                                                                                                                                                     #define ERROR_BAD_DATABASE_VERSION       1613

// Product is uninstalled.                                                                                                                                                           #define ERROR_PRODUCT_UNINSTALLED        1614

// SQL query syntax invalid or unsupported.                                                                                                                                          #define ERROR_BAD_QUERY_SYNTAX           1615

// Record field does not exist.                                                                                                                                                      #define ERROR_INVALID_FIELD              1616

//
// RPC Status Codes
//

// The string binding is invalid.                                                                                                                                                    #define RPC_S_INVALID_STRING_BINDING     1700

// The binding handle is not the correct type.                                                                                                                                       #define RPC_S_WRONG_KIND_OF_BINDING      1701

// The binding handle is invalid.                                                                                                                                                    #define RPC_S_INVALID_BINDING            1702

// The RPC protocol sequence is not supported.                                                                                                                                       #define RPC_S_PROTSEQ_NOT_SUPPORTED      1703

// The RPC protocol sequence is invalid.                                                                                                                                             #define RPC_S_INVALID_RPC_PROTSEQ        1704

// The string universal unique identifier (UUID) is invalid.                                                                                                                         #define RPC_S_INVALID_STRING_UUID        1705

// The endpoint format is invalid.                                                                                                                                                   #define RPC_S_INVALID_ENDPOINT_FORMAT    1706

// The network address is invalid.                                                                                                                                                   #define RPC_S_INVALID_NET_ADDR           1707

// No endpoint was found.                                                                                                                                                            #define RPC_S_NO_ENDPOINT_FOUND          1708

// The timeout value is invalid.                                                                                                                                                     #define RPC_S_INVALID_TIMEOUT            1709

// The object universal unique identifier (UUID) was not found.                                                                                                                      #define RPC_S_OBJECT_NOT_FOUND           1710

// The object universal unique identifier (UUID) has already been registered.                                                                                                        #define RPC_S_ALREADY_REGISTERED         1711

// The type universal unique identifier (UUID) has already been registered.                                                                                                          #define RPC_S_TYPE_ALREADY_REGISTERED    1712

// The RPC server is already listening.                                                                                                                                              #define RPC_S_ALREADY_LISTENING          1713

// No protocol sequences have been registered.                                                                                                                                       #define RPC_S_NO_PROTSEQS_REGISTERED     1714

// The RPC server is not listening.                                                                                                                                                  #define RPC_S_NOT_LISTENING              1715

// The manager type is unknown.                                                                                                                                                      #define RPC_S_UNKNOWN_MGR_TYPE           1716

// The interface is unknown.                                                                                                                                                         #define RPC_S_UNKNOWN_IF                 1717

// There are no bindings.                                                                                                                                                            #define RPC_S_NO_BINDINGS                1718

// There are no protocol sequences.                                                                                                                                                  #define RPC_S_NO_PROTSEQS                1719

// The endpoint cannot be created.                                                                                                                                                   #define RPC_S_CANT_CREATE_ENDPOINT       1720

// Not enough resources are available to complete this operation.                                                                                                                    #define RPC_S_OUT_OF_RESOURCES           1721

// The RPC server is unavailable.                                                                                                                                                    #define RPC_S_SERVER_UNAVAILABLE         1722

// The RPC server is too busy to complete this operation.                                                                                                                            #define RPC_S_SERVER_TOO_BUSY            1723

// The network options are invalid.                                                                                                                                                  #define RPC_S_INVALID_NETWORK_OPTIONS    1724

// There are no remote procedure calls active on this thread.                                                                                                                        #define RPC_S_NO_CALL_ACTIVE             1725

// The remote procedure call failed.                                                                                                                                                 #define RPC_S_CALL_FAILED                1726

// The remote procedure call failed and did not execute.                                                                                                                             #define RPC_S_CALL_FAILED_DNE            1727

// A remote procedure call (RPC) protocol error occurred.                                                                                                                            #define RPC_S_PROTOCOL_ERROR             1728

// The transfer syntax is not supported by the RPC server.                                                                                                                           #define RPC_S_UNSUPPORTED_TRANS_SYN      1730

// The universal unique identifier (UUID) type is not supported.                                                                                                                     #define RPC_S_UNSUPPORTED_TYPE           1732

// The tag is invalid.                                                                                                                                                               #define RPC_S_INVALID_TAG                1733

// The array bounds are invalid.                                                                                                                                                     #define RPC_S_INVALID_BOUND              1734

// The binding does not contain an entry name.                                                                                                                                       #define RPC_S_NO_ENTRY_NAME              1735

// The name syntax is invalid.                                                                                                                                                       #define RPC_S_INVALID_NAME_SYNTAX        1736

// The name syntax is not supported.                                                                                                                                                 #define RPC_S_UNSUPPORTED_NAME_SYNTAX    1737

// No network address is available to use to construct a universal unique identifier (UUID).                                                                                         #define RPC_S_UUID_NO_ADDRESS            1739

// The endpoint is a duplicate.                                                                                                                                                      #define RPC_S_DUPLICATE_ENDPOINT         1740

// The authentication type is unknown.                                                                                                                                               #define RPC_S_UNKNOWN_AUTHN_TYPE         1741

// The maximum number of calls is too small.                                                                                                                                         #define RPC_S_MAX_CALLS_TOO_SMALL        1742

// The string is too long.                                                                                                                                                           #define RPC_S_STRING_TOO_LONG            1743

// The RPC protocol sequence was not found.                                                                                                                                          #define RPC_S_PROTSEQ_NOT_FOUND          1744

// The procedure number is out of range.                                                                                                                                             #define RPC_S_PROCNUM_OUT_OF_RANGE       1745

// The binding does not contain any authentication information.                                                                                                                      #define RPC_S_BINDING_HAS_NO_AUTH        1746

// The authentication service is unknown.                                                                                                                                            #define RPC_S_UNKNOWN_AUTHN_SERVICE      1747

// The authentication level is unknown.                                                                                                                                              #define RPC_S_UNKNOWN_AUTHN_LEVEL        1748

// The security context is invalid.                                                                                                                                                  #define RPC_S_INVALID_AUTH_IDENTITY      1749

// The authorization service is unknown.                                                                                                                                             #define RPC_S_UNKNOWN_AUTHZ_SERVICE      1750

// The entry is invalid.                                                                                                                                                             #define EPT_S_INVALID_ENTRY              1751

// The server endpoint cannot perform the operation.                                                                                                                                 #define EPT_S_CANT_PERFORM_OP            1752

// There are no more endpoints available from the endpoint mapper.                                                                                                                   #define EPT_S_NOT_REGISTERED             1753

// No interfaces have been exported.                                                                                                                                                 #define RPC_S_NOTHING_TO_EXPORT          1754

// The entry name is incomplete.                                                                                                                                                     #define RPC_S_INCOMPLETE_NAME            1755

// The version option is invalid.                                                                                                                                                    #define RPC_S_INVALID_VERS_OPTION        1756

// There are no more members.                                                                                                                                                        #define RPC_S_NO_MORE_MEMBERS            1757

// There is nothing to unexport.                                                                                                                                                     #define RPC_S_NOT_ALL_OBJS_UNEXPORTED    1758

// The interface was not found.                                                                                                                                                      #define RPC_S_INTERFACE_NOT_FOUND        1759

// The entry already exists.                                                                                                                                                         #define RPC_S_ENTRY_ALREADY_EXISTS       1760

// The entry is not found.                                                                                                                                                           #define RPC_S_ENTRY_NOT_FOUND            1761

// The name service is unavailable.                                                                                                                                                  #define RPC_S_NAME_SERVICE_UNAVAILABLE   1762

// The network address family is invalid.                                                                                                                                            #define RPC_S_INVALID_NAF_ID             1763

// The requested operation is not supported.                                                                                                                                         #define RPC_S_CANNOT_SUPPORT             1764

// No security context is available to allow impersonation.                                                                                                                          #define RPC_S_NO_CONTEXT_AVAILABLE       1765

// An internal error occurred in a remote procedure call (RPC).                                                                                                                      #define RPC_S_INTERNAL_ERROR             1766

// The RPC server attempted an integer division by zero.                                                                                                                             #define RPC_S_ZERO_DIVIDE                1767

// An addressing error occurred in the RPC server.                                                                                                                                   #define RPC_S_ADDRESS_ERROR              1768

// A floating-point operation at the RPC server caused a division by zero.                                                                                                           #define RPC_S_FP_DIV_ZERO                1769

// A floating-point underflow occurred at the RPC server.                                                                                                                            #define RPC_S_FP_UNDERFLOW               1770

// A floating-point overflow occurred at the RPC server.                                                                                                                             #define RPC_S_FP_OVERFLOW                1771

// The list of RPC servers available for the binding of auto handles has been exhausted.                                                                                             #define RPC_X_NO_MORE_ENTRIES            1772

// Unable to open the character translation table file.                                                                                                                              #define RPC_X_SS_CHAR_TRANS_OPEN_FAIL    1773

// The file containing the character translation table has fewer than 512 bytes.                                                                                                     #define RPC_X_SS_CHAR_TRANS_SHORT_FILE   1774

// A null context handle was passed from the client to the host during a remote procedure call.                                                                                      #define RPC_X_SS_IN_NULL_CONTEXT         1775

// The context handle changed during a remote procedure call.                                                                                                                        #define RPC_X_SS_CONTEXT_DAMAGED         1777

// The binding handles passed to a remote procedure call do not match.                                                                                                               #define RPC_X_SS_HANDLES_MISMATCH        1778

// The stub is unable to get the remote procedure call handle.                                                                                                                       #define RPC_X_SS_CANNOT_GET_CALL_HANDLE  1779

// A null reference pointer was passed to the stub.                                                                                                                                  #define RPC_X_NULL_REF_POINTER           1780

// The enumeration value is out of range.                                                                                                                                            #define RPC_X_ENUM_VALUE_OUT_OF_RANGE    1781

// The byte count is too small.                                                                                                                                                      #define RPC_X_BYTE_COUNT_TOO_SMALL       1782

// The stub received bad data.                                                                                                                                                       #define RPC_X_BAD_STUB_DATA              1783

// The supplied user buffer is not valid for the requested operation.                                                                                                                #define ERROR_INVALID_USER_BUFFER        1784

// The disk media is not recognized.  It may not be formatted.                                                                                                                       #define ERROR_UNRECOGNIZED_MEDIA         1785

// The workstation does not have a trust secret.                                                                                                                                     #define ERROR_NO_TRUST_LSA_SECRET        1786

// The SAM database on the Windows NT Server does not have a computer account for this workstation trust relationship.                                                               #define ERROR_NO_TRUST_SAM_ACCOUNT       1787

// The trust relationship between the primary domain and the trusted domain failed.                                                                                                  #define ERROR_TRUSTED_DOMAIN_FAILURE     1788

// The trust relationship between this workstation and the primary domain failed.                                                                                                    #define ERROR_TRUSTED_RELATIONSHIP_FAILURE 1789

// The network logon failed.                                                                                                                                                         #define ERROR_TRUST_FAILURE              1790

// A remote procedure call is already in progress for this thread.                                                                                                                   #define RPC_S_CALL_IN_PROGRESS           1791

// An attempt was made to logon, but the network logon service was not started.                                                                                                      #define ERROR_NETLOGON_NOT_STARTED       1792

// The user's account has expired.                                                                                                                                                   #define ERROR_ACCOUNT_EXPIRED            1793

// The redirector is in use and cannot be unloaded.                                                                                                                                  #define ERROR_REDIRECTOR_HAS_OPEN_HANDLES 1794

// The specified printer driver is already installed.                                                                                                                                #define ERROR_PRINTER_DRIVER_ALREADY_INSTALLED 1795

// The specified port is unknown.                                                                                                                                                    #define ERROR_UNKNOWN_PORT               1796

// The printer driver is unknown.                                                                                                                                                    #define ERROR_UNKNOWN_PRINTER_DRIVER     1797

// The print processor is unknown.                                                                                                                                                   #define ERROR_UNKNOWN_PRINTPROCESSOR     1798

// The specified separator file is invalid.                                                                                                                                          #define ERROR_INVALID_SEPARATOR_FILE     1799

// The specified priority is invalid.                                                                                                                                                #define ERROR_INVALID_PRIORITY           1800

// The printer name is invalid.                                                                                                                                                      #define ERROR_INVALID_PRINTER_NAME       1801

// The printer already exists.                                                                                                                                                       #define ERROR_PRINTER_ALREADY_EXISTS     1802

// The printer command is invalid.                                                                                                                                                   #define ERROR_INVALID_PRINTER_COMMAND    1803

// The specified datatype is invalid.                                                                                                                                                #define ERROR_INVALID_DATATYPE           1804

// The environment specified is invalid.                                                                                                                                             #define ERROR_INVALID_ENVIRONMENT        1805

// There are no more bindings.                                                                                                                                                       #define RPC_S_NO_MORE_BINDINGS           1806

// The account used is an interdomain trust account.  Use your global user account or local user account to access this server.                                                      #define ERROR_NOLOGON_INTERDOMAIN_TRUST_ACCOUNT 1807

// The account used is a computer account.  Use your global user account or local user account to access this server.                                                                #define ERROR_NOLOGON_WORKSTATION_TRUST_ACCOUNT 1808

// The account used is a server trust account.  Use your global user account or local user account to access this server.                                                            #define ERROR_NOLOGON_SERVER_TRUST_ACCOUNT 1809

// The name or security ID (SID) of the domain specified is inconsistent with the trust information for that domain.                                                                 #define ERROR_DOMAIN_TRUST_INCONSISTENT  1810

// The server is in use and cannot be unloaded.                                                                                                                                      #define ERROR_SERVER_HAS_OPEN_HANDLES    1811

// The specified image file did not contain a resource section.                                                                                                                      #define ERROR_RESOURCE_DATA_NOT_FOUND    1812

// The specified resource type cannot be found in the image file.                                                                                                                    #define ERROR_RESOURCE_TYPE_NOT_FOUND    1813

// The specified resource name cannot be found in the image file.                                                                                                                    #define ERROR_RESOURCE_NAME_NOT_FOUND    1814

// The specified resource language ID cannot be found in the image file.                                                                                                             #define ERROR_RESOURCE_LANG_NOT_FOUND    1815

// Not enough quota is available to process this command.                                                                                                                            #define ERROR_NOT_ENOUGH_QUOTA           1816

// No interfaces have been registered.                                                                                                                                               #define RPC_S_NO_INTERFACES              1817

// The remote procedure call was cancelled.                                                                                                                                          #define RPC_S_CALL_CANCELLED             1818

// The binding handle does not contain all required information.                                                                                                                     #define RPC_S_BINDING_INCOMPLETE         1819

// A communications failure occurred during a remote procedure call.                                                                                                                 #define RPC_S_COMM_FAILURE               1820

// The requested authentication level is not supported.                                                                                                                              #define RPC_S_UNSUPPORTED_AUTHN_LEVEL    1821

// No principal name registered.                                                                                                                                                     #define RPC_S_NO_PRINC_NAME              1822

// The error specified is not a valid Windows RPC error code.                                                                                                                        #define RPC_S_NOT_RPC_ERROR              1823

// A UUID that is valid only on this computer has been allocated.                                                                                                                    #define RPC_S_UUID_LOCAL_ONLY            1824

// A security package specific error occurred.                                                                                                                                       #define RPC_S_SEC_PKG_ERROR              1825

// Thread is not canceled.                                                                                                                                                           #define RPC_S_NOT_CANCELLED              1826

// Invalid operation on the encoding/decoding handle.                                                                                                                                #define RPC_X_INVALID_ES_ACTION          1827

// Incompatible version of the serializing package.                                                                                                                                  #define RPC_X_WRONG_ES_VERSION           1828

// Incompatible version of the RPC stub.                                                                                                                                             #define RPC_X_WRONG_STUB_VERSION         1829

// The RPC pipe object is invalid or corrupted.                                                                                                                                      #define RPC_X_INVALID_PIPE_OBJECT        1830

// An invalid operation was attempted on an RPC pipe object.                                                                                                                         #define RPC_X_WRONG_PIPE_ORDER           1831

// Unsupported RPC pipe version.                                                                                                                                                     #define RPC_X_WRONG_PIPE_VERSION         1832

// The group member was not found.                                                                                                                                                   #define RPC_S_GROUP_MEMBER_NOT_FOUND     1898

// The endpoint mapper database entry could not be created.                                                                                                                          #define EPT_S_CANT_CREATE                1899

// The object universal unique identifier (UUID) is the nil UUID.                                                                                                                    #define RPC_S_INVALID_OBJECT             1900

// The specified time is invalid.                                                                                                                                                    #define ERROR_INVALID_TIME               1901

// The specified form name is invalid.                                                                                                                                               #define ERROR_INVALID_FORM_NAME          1902

// The specified form size is invalid.                                                                                                                                               #define ERROR_INVALID_FORM_SIZE          1903

// The specified printer handle is already being waited on                                                                                                                           #define ERROR_ALREADY_WAITING            1904

// The specified printer has been deleted.                                                                                                                                           #define ERROR_PRINTER_DELETED            1905

// The state of the printer is invalid.                                                                                                                                              #define ERROR_INVALID_PRINTER_STATE      1906

// The user must change his password before he logs on the first time.                                                                                                               #define ERROR_PASSWORD_MUST_CHANGE       1907

// Could not find the domain controller for this domain.                                                                                                                             #define ERROR_DOMAIN_CONTROLLER_NOT_FOUND 1908

// The referenced account is currently locked out and may not be logged on to.                                                                                                       #define ERROR_ACCOUNT_LOCKED_OUT         1909

// The object exporter specified was not found.                                                                                                                                      #define OR_INVALID_OXID                  1910

// The object specified was not found.                                                                                                                                               #define OR_INVALID_OID                   1911

// The object resolver set specified was not found.                                                                                                                                  #define OR_INVALID_SET                   1912

// Some data remains to be sent in the request buffer.                                                                                                                               #define RPC_S_SEND_INCOMPLETE            1913

// Invalid asynchronous remote procedure call handle.                                                                                                                                #define RPC_S_INVALID_ASYNC_HANDLE       1914

// Invalid asynchronous RPC call handle for this operation.                                                                                                                          #define RPC_S_INVALID_ASYNC_CALL         1915

// The RPC pipe object has already been closed.                                                                                                                                      #define RPC_X_PIPE_CLOSED                1916

// The RPC call completed before all pipes were processed.                                                                                                                           #define RPC_X_PIPE_DISCIPLINE_ERROR      1917

// No more data is available from the RPC pipe.                                                                                                                                      #define RPC_X_PIPE_EMPTY                 1918

// No site name is available for this machine.                                                                                                                                       #define ERROR_NO_SITENAME                1919

// The file can not be accessed by the system.                                                                                                                                       #define ERROR_CANT_ACCESS_FILE           1920

// The name of the file cannot be resolved by the system.                                                                                                                            #define ERROR_CANT_RESOLVE_FILENAME      1921

// The directory service evaluated group memberships locally.                                                                                                                        #define ERROR_DS_MEMBERSHIP_EVALUATED_LOCALLY 1922

// The specified directory service attribute or value does not exist.                                                                                                                #define ERROR_DS_NO_ATTRIBUTE_OR_VALUE   1923

// The attribute syntax specified to the directory service is invalid.                                                                                                               #define ERROR_DS_INVALID_ATTRIBUTE_SYNTAX 1924

// The attribute type specified to the directory service is not defined.                                                                                                             #define ERROR_DS_ATTRIBUTE_TYPE_UNDEFINED 1925

// The specified directory service attribute or value already exists.                                                                                                                #define ERROR_DS_ATTRIBUTE_OR_VALUE_EXISTS 1926

// The directory service is busy.                                                                                                                                                    #define ERROR_DS_BUSY                    1927

// The directory service is unavailable.                                                                                                                                             #define ERROR_DS_UNAVAILABLE             1928

// The directory service was unable to allocate a relative identifier.                                                                                                               #define ERROR_DS_NO_RIDS_ALLOCATED       1929

// The directory service has exhausted the pool of relative identifiers.                                                                                                             #define ERROR_DS_NO_MORE_RIDS            1930

// The requested operation could not be performed because the directory service is not the master for that type of operation.                                                        #define ERROR_DS_INCORRECT_ROLE_OWNER    1931

// The directory service was unable to initialize the subsystem that allocates relative identifiers.                                                                                 #define ERROR_DS_RIDMGR_INIT_ERROR       1932

// The requested operation did not satisfy one or more constraints associated with the class of the object.                                                                          #define ERROR_DS_OBJ_CLASS_VIOLATION     1933

// The directory service can perform the requested operation only on a leaf object.                                                                                                  #define ERROR_DS_CANT_ON_NON_LEAF        1934

// The directory service cannot perform the requested operation on the RDN attribute of an object.                                                                                   #define ERROR_DS_CANT_ON_RDN             1935

// The directory service detected an attempt to modify the object class of an object.                                                                                                #define ERROR_DS_CANT_MOD_OBJ_CLASS      1936

// The requested cross domain move operation could not be performed.                                                                                                                 #define ERROR_DS_CROSS_DOM_MOVE_ERROR    1937

// Unable to contact the global catalog server.                                                                                                                                      #define ERROR_DS_GC_NOT_AVAILABLE        1938

// The list of servers for this workgroup is not currently available                                                                                                                 #define ERROR_NO_BROWSER_SERVERS_FOUND   6118

//
// OpenGL Error Code
//

// The pixel format is invalid.                                                                                                                                                      #define ERROR_INVALID_PIXEL_FORMAT       2000

// The specified driver is invalid.                                                                                                                                                  #define ERROR_BAD_DRIVER                 2001

// The window style or class attribute is invalid for this operation.                                                                                                                #define ERROR_INVALID_WINDOW_STYLE       2002

// The requested metafile operation is not supported.                                                                                                                                #define ERROR_METAFILE_NOT_SUPPORTED     2003

// The requested transformation operation is not supported.                                                                                                                          #define ERROR_TRANSFORM_NOT_SUPPORTED    2004

// The requested clipping operation is not supported.                                                                                                                                #define ERROR_CLIPPING_NOT_SUPPORTED     2005

//
// Image Color Management Error Code
//

// The specified color management module is invalid.                                                                                                                                 #define ERROR_INVALID_CMM                2300

// The specified color profile is invalid.                                                                                                                                           #define ERROR_INVALID_PROFILE            2301

// The specified tag was not found.                                                                                                                                                  #define ERROR_TAG_NOT_FOUND              2302

// A required tag is not present.                                                                                                                                                    #define ERROR_TAG_NOT_PRESENT            2303

// The specified tag is already present.                                                                                                                                             #define ERROR_DUPLICATE_TAG              2304

// The specified color profile is not associated with any device.                                                                                                                    #define ERROR_PROFILE_NOT_ASSOCIATED_WITH_DEVICE 2305

// The specified color profile was not found.                                                                                                                                        #define ERROR_PROFILE_NOT_FOUND          2306

// The specified color space is invalid.                                                                                                                                             #define ERROR_INVALID_COLORSPACE         2307

// Image Color Management is not enabled.                                                                                                                                            #define ERROR_ICM_NOT_ENABLED            2308

// There was an error while deleting the color transform.                                                                                                                            #define ERROR_DELETING_ICM_XFORM         2309

// The specified color transform is invalid.                                                                                                                                         #define ERROR_INVALID_TRANSFORM          2310

// Win32 Spooler Error Codes

// The specified print monitor is unknown.                                                                                                                                           #define ERROR_UNKNOWN_PRINT_MONITOR      3000

// The specified printer driver is currently in use.                                                                                                                                 #define ERROR_PRINTER_DRIVER_IN_USE      3001

// The spool file was not found.                                                                                                                                                     #define ERROR_SPOOL_FILE_NOT_FOUND       3002

// A StartDocPrinter call was not issued.                                                                                                                                            #define ERROR_SPL_NO_STARTDOC            3003

// An AddJob call was not issued.                                                                                                                                                    #define ERROR_SPL_NO_ADDJOB              3004

// The specified print processor has already been installed.                                                                                                                         #define ERROR_PRINT_PROCESSOR_ALREADY_INSTALLED 3005

// The specified print monitor has already been installed.                                                                                                                           #define ERROR_PRINT_MONITOR_ALREADY_INSTALLED 3006

// The specified print monitor does not have the required functions.                                                                                                                 #define ERROR_INVALID_PRINT_MONITOR      3007

// The specified print monitor is currently in use.                                                                                                                                  #define ERROR_PRINT_MONITOR_IN_USE       3008

// The requested operation is not allowed when there are jobs queued to the printer.                                                                                                 #define ERROR_PRINTER_HAS_JOBS_QUEUED    3009

// The requested operation is successful.  Changes will not be effective until the system is rebooted.                                                                               #define ERROR_SUCCESS_REBOOT_REQUIRED    3010

// The requested operation is successful.  Changes will not be effective until the service is restarted.                                                                             #define ERROR_SUCCESS_RESTART_REQUIRED   3011

// Wins Error Codes

// WINS encountered an error while processing the command.                                                                                                                           #define ERROR_WINS_INTERNAL              4000

// The local WINS can not be deleted.                                                                                                                                                #define ERROR_CAN_NOT_DEL_LOCAL_WINS     4001

// The importation from the file failed.                                                                                                                                             #define ERROR_STATIC_INIT                4002

// The backup failed.  Was a full backup done before?                                                                                                                                #define ERROR_INC_BACKUP                 4003

// The backup failed.  Check the directory to which you are backing the database.                                                                                                    #define ERROR_FULL_BACKUP                4004

// The name does not exist in the WINS database.                                                                                                                                     #define ERROR_REC_NON_EXISTENT           4005

// Replication with a nonconfigured partner is not allowed.                                                                                                                          #define ERROR_RPL_NOT_ALLOWED            4006

// DHCP Error Codes

// The DHCP client has obtained an IP address that is already in use on the network.                                                                                                 #define ERROR_DHCP_ADDRESS_CONFLICT      4100

// WMI Error Codes

// The GUID passed was not recognized as valid by a WMI data provider.                                                                                                               #define ERROR_WMI_GUID_NOT_FOUND         4200

// The instance name passed was not recognized as valid by a WMI data provider.                                                                                                      #define ERROR_WMI_INSTANCE_NOT_FOUND     4201

// The data item ID passed was not recognized as valid by a WMI data provider.                                                                                                       #define ERROR_WMI_ITEMID_NOT_FOUND       4202

// The WMI request could not be completed and should be retried.                                                                                                                     #define ERROR_WMI_TRY_AGAIN              4203

// The WMI data provider could not be located.                                                                                                                                       #define ERROR_WMI_DP_NOT_FOUND           4204

// The WMI data provider references an instance set that has not been registered.                                                                                                    #define ERROR_WMI_UNRESOLVED_INSTANCE_REF 4205

// The WMI data block or event notification has already been enabled.                                                                                                                #define ERROR_WMI_ALREADY_ENABLED        4206

// The WMI data block is no longer available.                                                                                                                                        #define ERROR_WMI_GUID_DISCONNECTED      4207

// The WMI data service is not available.                                                                                                                                            #define ERROR_WMI_SERVER_UNAVAILABLE     4208

// The WMI data provider failed to carry out the request.                                                                                                                            #define ERROR_WMI_DP_FAILED              4209

// The WMI MOF information is not valid.                                                                                                                                             #define ERROR_WMI_INVALID_MOF            4210

// The WMI registration information is not valid.                                                                                                                                    #define ERROR_WMI_INVALID_REGINFO        4211

// NT Media Services Error Codes

// The media identifier does not represent a valid medium.                                                                                                                           #define ERROR_INVALID_MEDIA              4300

// The library identifier does not represent a valid library.                                                                                                                        #define ERROR_INVALID_LIBRARY            4301

// The media pool identifier does not represent a valid media pool.                                                                                                                  #define ERROR_INVALID_MEDIA_POOL         4302

// The drive and medium are not compatible or exist in different libraries.                                                                                                          #define ERROR_DRIVE_MEDIA_MISMATCH       4303

// The medium currently exists in an offline library and must be online to perform this operation.                                                                                   #define ERROR_MEDIA_OFFLINE              4304

// The operation cannot be performed on an offline library.                                                                                                                          #define ERROR_LIBRARY_OFFLINE            4305

// The library, drive, or media pool is empty.                                                                                                                                       #define ERROR_EMPTY                      4306

// The library, drive, or media pool must be empty to perform this operation.                                                                                                        #define ERROR_NOT_EMPTY                  4307

// No media is currently available in this media pool or library.                                                                                                                    #define ERROR_MEDIA_UNAVAILABLE          4308

// A resource required for this operation is disabled.                                                                                                                               #define ERROR_RESOURCE_DISABLED          4309

// The media identifier does not represent a valid cleaner.                                                                                                                          #define ERROR_INVALID_CLEANER            4310

// The drive cannot be cleaned or does not support cleaning.                                                                                                                         #define ERROR_UNABLE_TO_CLEAN            4311

// The object identifier does not represent a valid object.                                                                                                                          #define ERROR_OBJECT_NOT_FOUND           4312

// Unable to read from or write to the database.                                                                                                                                     #define ERROR_DATABASE_FAILURE           4313

// The database is full.                                                                                                                                                             #define ERROR_DATABASE_FULL              4314

// The medium is not compatible with the device or media pool.                                                                                                                       #define ERROR_MEDIA_INCOMPATIBLE         4315

// The resource required for this operation does not exist.                                                                                                                          #define ERROR_RESOURCE_NOT_PRESENT       4316

// The operation identifier is not valid.                                                                                                                                            #define ERROR_INVALID_OPERATION          4317

// The media is not mounted or ready for use.                                                                                                                                        #define ERROR_MEDIA_NOT_AVAILABLE        4318

// The device is not ready for use.                                                                                                                                                  #define ERROR_DEVICE_NOT_AVAILABLE       4319

// The operator or administrator has refused the request.                                                                                                                            #define ERROR_REQUEST_REFUSED            4320

//
// NT Remote Storage Service Error Codes
//

// The remote storage service was not able to recall the file.                                                                                                                       #define ERROR_FILE_OFFLINE               4350

// The remote storage service is not operational at this time.                                                                                                                       #define ERROR_REMOTE_STORAGE_NOT_ACTIVE  4351

// The remote storage service encountered a media error.                                                                                                                             #define ERROR_REMOTE_STORAGE_MEDIA_ERROR 4352

//
// NT Reparse Points Error Codes
//

// The file or directory is not a reparse point.                                                                                                                                     #define ERROR_NOT_A_REPARSE_POINT        4390

// The reparse point attribute cannot be set because it conflicts with an existing attribute.                                                                                        #define ERROR_REPARSE_ATTRIBUTE_CONFLICT 4391

// Cluster Error Codes

// The cluster resource cannot be moved to another group because other resources are dependent on it.                                                                                #define ERROR_DEPENDENT_RESOURCE_EXISTS  5001

// The cluster resource dependency cannot be found.                                                                                                                                  #define ERROR_DEPENDENCY_NOT_FOUND       5002

// The cluster resource cannot be made dependent on the specified resource because it is already dependent.                                                                          #define ERROR_DEPENDENCY_ALREADY_EXISTS  5003

// The cluster resource is not online.                                                                                                                                               #define ERROR_RESOURCE_NOT_ONLINE        5004

// A cluster node is not available for this operation.                                                                                                                               #define ERROR_HOST_NODE_NOT_AVAILABLE    5005

// The cluster resource is not available.                                                                                                                                            #define ERROR_RESOURCE_NOT_AVAILABLE     5006

// The cluster resource could not be found.                                                                                                                                          #define ERROR_RESOURCE_NOT_FOUND         5007

// The cluster is being shut down.                                                                                                                                                   #define ERROR_SHUTDOWN_CLUSTER           5008

// A cluster node cannot be evicted from the cluster while it is online.                                                                                                             #define ERROR_CANT_EVICT_ACTIVE_NODE     5009

// The object already exists.                                                                                                                                                        #define ERROR_OBJECT_ALREADY_EXISTS      5010

// The object is already in the list.                                                                                                                                                #define ERROR_OBJECT_IN_LIST             5011

// The cluster group is not available for any new requests.                                                                                                                          #define ERROR_GROUP_NOT_AVAILABLE        5012

// The cluster group could not be found.                                                                                                                                             #define ERROR_GROUP_NOT_FOUND            5013

// The operation could not be completed because the cluster group is not online.                                                                                                     #define ERROR_GROUP_NOT_ONLINE           5014

// The cluster node is not the owner of the resource.                                                                                                                                #define ERROR_HOST_NODE_NOT_RESOURCE_OWNER 5015

// The cluster node is not the owner of the group.                                                                                                                                   #define ERROR_HOST_NODE_NOT_GROUP_OWNER  5016

// The cluster resource could not be created in the specified resource monitor.                                                                                                      #define ERROR_RESMON_CREATE_FAILED       5017

// The cluster resource could not be brought online by the resource monitor.                                                                                                         #define ERROR_RESMON_ONLINE_FAILED       5018

// The operation could not be completed because the cluster resource is online.                                                                                                      #define ERROR_RESOURCE_ONLINE            5019

// The cluster resource could not be deleted or brought offline because it is the quorum resource.                                                                                   #define ERROR_QUORUM_RESOURCE            5020

// The cluster could not make the specified resource a quorum resource because it is not capable of being a quorum resource.                                                         #define ERROR_NOT_QUORUM_CAPABLE         5021

// The cluster software is shutting down.                                                                                                                                            #define ERROR_CLUSTER_SHUTTING_DOWN      5022

// The group or resource is not in the correct state to perform the requested operation.                                                                                             #define ERROR_INVALID_STATE              5023

// The properties were stored but not all changes will take effect until the next time the resource is brought online.                                                               #define ERROR_RESOURCE_PROPERTIES_STORED 5024

// The cluster could not make the specified resource a quorum resource because it does not belong to a shared storage class.                                                         #define ERROR_NOT_QUORUM_CLASS           5025

// The cluster resource could not be deleted since it is a core resource.                                                                                                            #define ERROR_CORE_RESOURCE              5026

// The quorum resource failed to come online.                                                                                                                                        #define ERROR_QUORUM_RESOURCE_ONLINE_FAILED 5027

// The quorum log could not be created or mounted successfully.                                                                                                                      #define ERROR_QUORUMLOG_OPEN_FAILED      5028

// The cluster log is corrupt.                                                                                                                                                       #define ERROR_CLUSTERLOG_CORRUPT         5029

// The record could not be written to the cluster log since it exceeds the maximum size.                                                                                             #define ERROR_CLUSTERLOG_RECORD_EXCEEDS_MAXSIZE 5030

// The cluster log exceeds its maximum size.                                                                                                                                         #define ERROR_CLUSTERLOG_EXCEEDS_MAXSIZE 5031

// No checkpoint record was found in the cluster log.                                                                                                                                #define ERROR_CLUSTERLOG_CHKPOINT_NOT_FOUND 5032

// The minimum required disk space needed for logging is not available.                                                                                                              #define ERROR_CLUSTERLOG_NOT_ENOUGH_SPACE 5033

// EFS Error Codes

// The specified file could not be encrypted.                                                                                                                                        #define ERROR_ENCRYPTION_FAILED          6000

// The specified file could not be decrypted.                                                                                                                                        #define ERROR_DECRYPTION_FAILED          6001

// The specified file is encrypted and the user does not have the ability to decrypt it.                                                                                             #define ERROR_FILE_ENCRYPTED             6002

// There is no encryption recovery policy configured for this system.                                                                                                                #define ERROR_NO_RECOVERY_POLICY         6003

// The required encryption driver is not loaded for this system.                                                                                                                     #define ERROR_NO_EFS                     6004

// The file was encrypted with a different encryption driver than is currently loaded.                                                                                               #define ERROR_WRONG_EFS                  6005

// There are no EFS keys defined for the user.                                                                                                                                       #define ERROR_NO_USER_KEYS               6006

// The specified file is not encrypted.                                                                                                                                              #define ERROR_FILE_NOT_ENCRYPTED         6007

// The specified file is not in the defined EFS export format.                                                                                                                       #define ERROR_NOT_EXPORT_FORMAT          6008
*/
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
 * Gibt die Abweichung der Tradeserverzeit von EET (Eastern European Time) zurück.
 *
 * @return int - Offset in Stunden
 */
int GetTradeServerEETOffset() {
   return(GetTradeServerGMTOffset() - 2);
}


/**
 * Gibt die Abweichung der Tradeserverzeit von GMT (Greenwich Mean Time) zurück.
 *
 * @return int - Offset in Stunden
 */
int GetTradeServerGMTOffset() {
   /**
    * TODO: Haben verschiedene Server desselben Brokers evt. unterschiedliche Offsets?
    *       string server  = AccountServer();
    *       Print("GetTradeServerGMTOffset(): account company: "+ company +", account server: "+ server);
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
      catch("GetTradeServerGMTOffset(1)  cannot resolve trade server GMT offset for unknown account company \""+ company +"\"", ERR_RUNTIME_ERROR);
   }
   else {
      // TODO: Verwendung von TerminalCompany() ist Unfug
      company = TerminalCompany();
      if (company == "Straighthold Investment Group, Inc.") return( 2);
      if (company == "Alpari (UK) Ltd."                   ) return( 1);
      if (company == "Cantor Fitzgerald Europe"           ) return( 0);
      if (company == "FOREX Ltd."                         ) return( 0);
      if (company == "Avail Trading Corp."                ) return(-5);
      catch("GetTradeServerGMTOffset(2)  cannot resolve trade server GMT offset for unknown terminal company \""+ company +"\"", ERR_RUNTIME_ERROR);
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
   int eetOffset     = GetTradeServerEETOffset();
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
 * Vergleicht zwei Strings ohne Berücksichtigung der Groß-/Kleinschreibung.
 *
 * @param string string1
 * @param string string2
 *
 * @return bool
 */
bool StringICompare(string string1, string string2) {
   return(StringToUpper(string1) == StringToUpper(string2));
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

