/**
 * Ermittelt die Anzahl der seit dem letzten Tick modifizierten Bars einer Datenreihe. Entspricht der manuellen Ermittlung
 * der Variable ChangedBars für eine andere als die aktuelle Datenreihe.
 *
 * @param  string symbol    - Symbol der zu untersuchenden Zeitreihe  (NULL = aktuelles Symbol)
 * @param  int    period    - Periode der zu untersuchenden Zeitreihe (NULL = aktuelle Periode)
 * @param  int    muteFlags - Ausführungssteuerung: Flags der Fehler, die still gesetzt werden sollen (default: keine)
 *
 * @return int - Baranzahl oder -1 (EMPTY), falls ein Fehler auftrat
 */
int iChangedBars(string symbol/*=NULL*/, int period/*=NULL*/, int muteFlags=NULL) {
   if (__ExecutionContext[EC.programCoreFunction] != CF_START) return(0);     // in init() oder deinit()
   if (symbol == "0")                                                         // (string) NULL
      symbol = Symbol();

   // Während der Verarbeitung eines Ticks geben die Bar-Funktionen und Bar-Variablen immer dieselbe Anzahl zurück, auch wenn die reale
   // Datenreihe sich bereits geändert haben sollte (in einem anderen Thread).
   // Ein Programm, das während desselben Ticks mehrmals iBars() aufruft, wird während dieses Ticks also immer dieselbe Anzahl Bars "sehen".

   // TODO: - statische Variablen in Library speichern, um Timeframewechsel zu überdauern
   //       - statische Variablen bei Accountwechsel zurücksetzen

   #define CB.tick               0                                   // Tick                     (beim letzten Aufruf)
   #define CB.bars               1                                   // Anzahl aller Bars        (beim letzten Aufruf)
   #define CB.changedBars        2                                   // Anzahl der ChangedBars   (beim letzten Aufruf)
   #define CB.oldestBarTime      3                                   // Zeit der ältesten Bar    (beim letzten Aufruf)
   #define CB.newestBarTime      4                                   // Zeit der neuesten Bar    (beim letzten Aufruf)


   // (1) Die Speicherung der statischen Daten je Parameterkombination "Symbol,Periode" ermöglicht den parallelen Aufruf für mehrere Datenreihen.
   string keys[];
   int    last[][5];
   int    keysSize = ArraySize(keys);
   string key = StringConcatenate(symbol, ",", period);              // "Hash" der aktuellen Parameterkombination

   for (int i=0; i < keysSize; i++) {
      if (keys[i] == key)
         break;
   }
   if (i == keysSize) {                                              // Schlüssel nicht gefunden: erster Aufruf für Symbol,Periode
      ArrayResize(keys, keysSize+1);
      ArrayResize(last, keysSize+1);
      keys[i] = key;                                                 // Schlüssel hinzufügen
      last[i][CB.tick         ] = -1;                                // last[] initialisieren
      last[i][CB.bars         ] = -1;
      last[i][CB.changedBars  ] = -1;
      last[i][CB.oldestBarTime] =  0;
      last[i][CB.newestBarTime] =  0;
   }
   // Index i zeigt hier immer auf den aktuellen Datensatz


   // (2) Mehrfachaufruf für eine Datenreihe innerhalb desselben Ticks
   if (Tick == last[i][CB.tick])
      return(last[i][CB.changedBars]);


   /*
   int iBars(symbol, period);

      - Beim ersten Zugriff auf eine leere Datenreihe wird statt ERR_SERIES_NOT_AVAILABLE gewöhnlich ERS_HISTORY_UPDATE gesetzt.
      - Bei weiteren Zugriffen auf eine leere Datenreihe wird ERR_SERIES_NOT_AVAILABLE gesetzt.
      - Ohne Server-Connection ist nach Recompilation und bei fehlenden Daten u.U. gar kein Fehler gesetzt.
   */

   // (3) ChangedBars ermitteln
   int bars  = iBars(symbol, period);
   int error = GetLastError();

   if (!bars || error) {                                             // Da immer beide Bedingungen geprüft werden müssen, braucht das ODER nicht optimiert werden.
      if (!bars || error!=ERS_HISTORY_UPDATE) {
         if (!error || error==ERS_HISTORY_UPDATE)
            error = ERR_SERIES_NOT_AVAILABLE;
         if (error==ERR_SERIES_NOT_AVAILABLE && muteFlags & F_ERR_SERIES_NOT_AVAILABLE)
            return(_EMPTY(SetLastError(error)));                                                                           // leise
         return(_EMPTY(catch("iChangedBars(1)->iBars("+ symbol +","+ PeriodDescription(period) +") => "+ bars, error)));   // laut
      }
   }
   // bars ist hier immer größer 0

   datetime oldestBarTime = iTime(symbol, period, bars-1);
   datetime newestBarTime = iTime(symbol, period, 0     );
   int      changedBars;

   if (last[i][CB.bars]==-1) {                        changedBars = bars;                          // erster Zugriff auf die Zeitreihe
   }
   else if (bars==last[i][CB.bars] && oldestBarTime==last[i][CB.oldestBarTime]) {                  // Baranzahl gleich und älteste Bar noch dieselbe
                                                      changedBars = 1;                             // normaler Tick (mit/ohne Lücke) oder synthetischer/sonstiger Tick: iVolume()
   }                                                                                               // kann nicht zur Unterscheidung zwischen changedBars=0|1 verwendet werden
   else {
    //if (bars == last[i][CB.bars])                                                                // Die letzte Bar hat sich geändert, Bars wurden hinten "hinausgeschoben".
    //   warn("iChangedBars(2)  bars==lastBars = "+ bars +" (did we hit MAX_CHART_BARS?)");        // (*) In diesem Fall muß die Bar mit last.newestBarTime gesucht und der Wert
                                                                                                   //     von changedBars daraus abgeleitet werden.
      if (newestBarTime != last[i][CB.newestBarTime]) changedBars = bars - last[i][CB.bars] + 1;   // neue Bars zu Beginn hinzugekommen
      else                                            changedBars = bars;                          // neue Bars in Lücke eingefügt: nicht eindeutig => alle als modifiziert melden

      if (bars == last[i][CB.bars])                   changedBars = bars;                          // solange die Suche (*) noch nicht implementiert ist
   }

   last[i][CB.tick         ] = Tick;
   last[i][CB.bars         ] = bars;
   last[i][CB.changedBars  ] = changedBars;
   last[i][CB.oldestBarTime] = oldestBarTime;
   last[i][CB.newestBarTime] = newestBarTime;

   return(changedBars);
}
