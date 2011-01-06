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
   static int error = ERR_NO_ERROR;

   // Trat beim letzten Aufruf ein Fehler auf, werden alle Indikatorwerte neuberechnet.
   if (error == ERR_HISTORY_UPDATE) ValidBars = 0;
   else                             ValidBars = IndicatorCounted();
   error = ERR_NO_ERROR;

   Tick++;
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
      return(catch("start(1)"));
   }


   // ... nur fehlende Werte berechnen
   for (int bar=ChangedBars; bar >= 0; bar--) {
      error = iBalance(AccountNumber(), iBufferBalance, bar);
      if (error != ERR_NO_ERROR)
         break;
   }
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

   int error = GetBalanceHistory(account, times, values);   // aufsteigend nach Zeit sortiert (times/values[0] = älteste Werte)
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

   // der Indikator wird hier noch komplett neuberechnet
   if (iBalanceSeries(account, lpBuffer) == ERR_HISTORY_UPDATE) {
      catch("iBalance(1)");
      return(ERR_HISTORY_UPDATE);
   }

   return(catch("iBalance(2)"));
}


/**
 * Schreibt die Balance-History eines Accounts in die angegebenen Zielarrays (aufsteigend nach Zeitpunkt sortiert).
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

   // Daten nach Möglichkeit aus dem Cache liefern
   if (account == cache.account[0]) {
      if (ArraySize(cache.times) > 0) {
         ArrayCopy(lpTimes , cache.times);
         ArrayCopy(lpValues, cache.values);
         log("GetBalanceHistory()   Delivering "+ ArraySize(lpTimes) +" cached balance history values for account "+ account);
         return(catch("GetBalanceHistory(1)"));
      }
   }

   // Cache-Miss, Balance-Daten aus Account-History auslesen
   string data[][HISTORY_COLUMNS]; ArrayResize(data, 0);
   int error = GetAccountHistory(account, data);
   if (error != ERR_NO_ERROR) {
      catch("GetBalanceHistory(2)");
      return(error);
   }

   ArrayResize(lpTimes,  0);
   ArrayResize(lpValues, 0);

   // Balancedatensätze einlesen und auswerten (History ist nach CloseTime sortiert)
   datetime time, lastTime;
   double   balance, lastBalance;
   int n, size=ArrayRange(data, 0);

   for (int i=0; i<size; i++) {
      balance = StrToDouble(data[i][HC_BALANCE]);

      if (balance != lastBalance) {
         time = StrToInteger(data[i][HC_CLOSETIMESTAMP]);

         if (time == lastTime) {       // existieren mehrere Balanceänderungen zum selben Zeitpunkt,
            lpValues[n-1] = balance;   // den vorherigen Balancewert mit dem aktuellen überschreiben
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
   if (ArraySize(lpTimes) == 0) {
      ArrayResize(cache.times,  0);
      ArrayResize(cache.values, 0);
   }
   else {
      ArrayCopy(cache.times , lpTimes );
      ArrayCopy(cache.values, lpValues);
   }
   cache.account[0] = account;
   log("GetBalanceHistory()   Cached "+ ArraySize(lpTimes) +" balance history values for account "+ account);

   return(catch("GetBalanceHistory(3)"));
}