/**
 * Ermittelt die Anzahl der seit dem letzten Tick modifizierten Bars einer Datenreihe. Entspricht der manuellen Ermittlung
 * der Variable ChangedBars für eine andere als die aktuelle Datenreihe.
 *
 * @param  string symbol    - Symbol der zu untersuchenden Zeitreihe  (NULL = aktuelles Symbol)
 * @param  int    period    - Periode der zu untersuchenden Zeitreihe (NULL = aktuelle Periode)
 * @param  int    execFlags - Ausführungssteuerung: Flags der Fehler, die still gesetzt werden sollen (default: keine)
 *
 * @return int - Baranzahl oder EMPTY (-1), falls ein Fehler auftrat
 *
 *
 * @throws ERR_SERIES_NOT_AVAILABLE - Wird still gesetzt, wenn im Parameter execFlags das Flag MUTE_ERR_SERIES_NOT_AVAILABLE gesetzt ist.
 */
int iChangedBars(string symbol/*=NULL*/, int period/*=NULL*/, int execFlags=NULL) {
   if (symbol == "0")                                                // (string) NULL
      symbol = Symbol();

   /*
   NOTE: Die Anzahl der gemeldeten Bars einer Datenreihe ändert sich innerhalb eines Ticks nicht, auch wenn die Datenreihe selbst sich ändert.
         Ein Programm, das z.B. innerhalb einer Schleife iBars() aufruft, wird während desselben Ticks immer dieselbe konstante Anzahl Bars "sehen".

   TODO:
   -----
   - statische Variablen müssen je Symbol und Periode zwischengespeichert werden
   - statische Variablen in Library speichern, um Timeframewechsel zu überdauern
   - statische Variablen bei Accountwechsel zurücksetzen
   */

   static int      prev.tick         = -1;
   static int      prev.bars         = -1;
   static int      prev.changedBars  = -1;
   static datetime prev.lastBarTime  =  0;
   static datetime prev.firstBarTime =  0;

   if (__WHEREAMI__ != FUNC_START) return(0);                        // in init() oder deinit()
   if (Tick == prev.tick)          return(prev.changedBars);         // Mehrfachaufruf innerhalb desselben Ticks


   int bars  = iBars(symbol, period);
   int error = GetLastError();

   // - Beim ersten Zugriff auf eine leere Datenreihe wird statt ERR_SERIES_NOT_AVAILABLE gewöhnlich ERS_HISTORY_UPDATE gesetzt.
   // - Bei weiteren Zugriffen auf eine leere Datenreihe wird ERR_SERIES_NOT_AVAILABLE gesetzt.
   // - Ohne Server-Connection ist nach Recompilation jedoch u.U. gar kein Fehler gesetzt (trotz fehlender Daten).
   if (!bars || error) {                                             // in jedem Fall müssen immer beide Bedingungen geprüft werden, eine Optimierung würde also nichts bringen
      if (!bars || error!=ERS_HISTORY_UPDATE) {
         if (!error || error==ERS_HISTORY_UPDATE)
            error = ERR_SERIES_NOT_AVAILABLE;
         if (error==ERR_SERIES_NOT_AVAILABLE && execFlags & MUTE_ERR_SERIES_NOT_AVAILABLE)               // der Fehlerfall wird nicht unnötig "optimiert"
            return(_EMPTY(SetLastError(error)));                                                         // leise
         return(_EMPTY(catch("iChangedBars(1: "+ symbol +","+ PeriodDescription(period) +")", error)));  // laut
      }
   }
   // bars ist hier immer größer 0


   datetime lastBarTime  = iTime(symbol, period, bars-1);
   datetime firstBarTime = iTime(symbol, period, 0     );
   int      changedBars;

   if      (prev.bars==-1)                                    changedBars = bars;                  // erster Zugriff auf die Zeitreihe
   else if (bars==prev.bars && lastBarTime==prev.lastBarTime) changedBars = 1;                     // Baranzahl gleich und älteste Bar noch dieselbe = normaler Tick (mit/ohne Lücke)
   else {
      if (bars == prev.bars) {
         // Wenn dies passiert (im Tester???) und Bars "hinten hinausgeschoben" wurden, muß die Bar mit prev.firstBarTime
         // manuell gesucht und der Wert von changedBars daraus abgeleitet werden.
         warn("iChangedBars(2)  bars==prev.bars="+ bars +" (we probably hit MAX_CHART_BARS)");
      }
      if (firstBarTime != prev.firstBarTime)                  changedBars = bars - prev.bars + 1;  // neue Bars zu Beginn hinzugekommen
      else                                                    changedBars = bars;                  // neue Bars in Lücke eingefügt: nicht eindeutig => alle als modifiziert melden
   }

   prev.tick         = Tick;
   prev.bars         = bars;
   prev.changedBars  = changedBars;
   prev.lastBarTime  = lastBarTime;
   prev.firstBarTime = firstBarTime;

   return(changedBars);
}
