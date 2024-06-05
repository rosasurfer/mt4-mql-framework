/**
 * Ermittelt den Bar-Offset eines Zeitpunktes innerhalb einer Datenreihe und gibt bei nicht existierender Bar die nächste
 * existierende Bar zurück.
 *
 * @param  string   symbol          - Symbol der zu untersuchenden Datenreihe  (NULL = aktuelles Symbol)
 * @param  int      period          - Periode der zu untersuchenden Datenreihe (NULL = aktuelle Periode)
 * @param  datetime time            - Zeitpunkt (Serverzeit)
 * @param  int      mute [optional] - Ausführungssteuerung: Flags der Fehler, die still gesetzt werden sollen (default: keine)
 *
 * @return int - Bar-Index oder -1, wenn keine entsprechende Bar existiert (Zeitpunkt ist zu jung für die Datenreihe);
 *               EMPTY_VALUE, falls ein Fehler auftrat
 *
 * Note: Ein gemeldeter Status ERS_HISTORY_UPDATE ist kein Fehler und wird nicht weitergemeldet.
 */
int iBarShiftNext(string symbol/*=NULL*/, int period/*=NULL*/, datetime time, int mute=NULL) {
   if (symbol == "0") symbol = Symbol();                                                  // (string) NULL
   if (time < 0) return(_EMPTY_VALUE(catch("iBarShiftNext(1)  invalid parameter time: "+ time, ERR_INVALID_PARAMETER)));

   // int iBarShift(string symbol, int period, datetime time, bool exact);
   //   exact = TRUE : Gibt den Index der Bar zurück, die den angegebenen Zeitpunkt abdeckt oder, falls keine solche Bar existiert, -1.
   //   exact = FALSE: Gibt den Index der Bar zurück, die den angegebenen Zeitpunkt abdeckt oder, falls keine solche Bar existiert, den Index
   //                  der vorhergehenden, älteren Bar. Existiert keine solche vorhergehende Bar, wird der Index der letzten Bar zurückgegeben.
   //
   //   - Existieren keine entsprechenden Daten, gibt iBarShift() -1 zurück.
   //   - Sind Symbol oder Timeframe unbekannt, meldet iBarShift() keinen Fehler.
   //   - Ist das Symbol bekannt, wird ggf. der Status ERS_HISTORY_UPDATE gemeldet.

   int bar = iBarShift(symbol, period, time, true);
   int error = GetLastError();
   if (error!=NO_ERROR) /*&&*/ if (error!=ERS_HISTORY_UPDATE)
      return(_EMPTY_VALUE(catch("iBarShiftNext(2)->iBarShift("+ symbol +","+ PeriodDescription(period) +") => "+ bar, error)));

   if (bar != -1)
      return(bar);

   // exact war TRUE und bar==-1: keine abdeckende Bar gefunden
   // Datenreihe holen
   datetime times[];
   int bars = ArrayCopySeries(times, MODE_TIME, symbol, period);                          // throws ERR_ARRAY_ERROR, wenn solche Daten (noch) nicht existieren
   error = GetLastError();

   if (bars<=0 || error) {                                                                // Da immer beide Bedingungen geprüft werden müssen, braucht das OR nicht optimiert werden.
      if (bars<=0 || error!=ERS_HISTORY_UPDATE) {
         if (!error || error==ERS_HISTORY_UPDATE || error==ERR_ARRAY_ERROR)               // aus ERR_ARRAY_ERROR wird ERR_SERIES_NOT_AVAILABLE
            error = ERR_SERIES_NOT_AVAILABLE;
         if (error==ERR_SERIES_NOT_AVAILABLE && mute & F_ERR_SERIES_NOT_AVAILABLE)
            return(_EMPTY_VALUE(SetLastError(error)));                                    // leise
         return(_EMPTY_VALUE(catch("iBarShiftNext(3)->ArrayCopySeries("+ symbol +","+ PeriodDescription(period) +") => "+ bars, error))); // laut
      }
   }
   // bars ist hier immer größer 0

   // Bars manuell überprüfen
   if (time < times[bars-1]) {                                                            // Zeitpunkt ist zu alt für die Reihe, die älteste Bar zurückgeben
      bar = bars-1;
   }
   else if (time < times[0]) {                                                            // Kurslücke, die nächste existierende Bar zurückgeben
      bar   = iBarShift(symbol, period, time) - 1;
      error = GetLastError();
      if (error!=NO_ERROR) /*&&*/ if (error!=ERS_HISTORY_UPDATE)
         return(_EMPTY_VALUE(catch("iBarShiftNext(4)->iBarShift("+ symbol +","+ PeriodDescription(period) +") => "+ bar, error)));
   }
   else /*time > times[0]*/ {                                                             // Zeitpunkt ist zu jung für die Reihe
      //bar ist und bleibt -1
   }
   return(bar);
}
