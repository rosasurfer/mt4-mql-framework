/**
 * MT4 struct HISTORY_HEADER (Header der Kursreihen im "history"-Verzeichnis)
 *
 * HistoryFile Header
 *
 * @link  https://github.com/rosasurfer/mt4-expander/blob/master/header/struct/mt4/HistoryHeader.h
 */
#import "rsfMT4Expander.dll"
   // Getter
   int      hh_BarFormat      (/*HISTORY_HEADER*/int hh[]);                         int      hhs_BarFormat      (/*HISTORY_HEADER*/int hhs[], int i);
   string   hh_Copyright      (/*HISTORY_HEADER*/int hh[]);                         string   hhs_Copyright      (/*HISTORY_HEADER*/int hhs[], int i);
   string   hh_Symbol         (/*HISTORY_HEADER*/int hh[]);                         string   hhs_Symbol         (/*HISTORY_HEADER*/int hhs[], int i);
   int      hh_Period         (/*HISTORY_HEADER*/int hh[]);                         int      hhs_Period         (/*HISTORY_HEADER*/int hhs[], int i);
   int      hh_Timeframe      (/*HISTORY_HEADER*/int hh[]);                         int      hhs_Timeframe      (/*HISTORY_HEADER*/int hhs[], int i);
   int      hh_Digits         (/*HISTORY_HEADER*/int hh[]);                         int      hhs_Digits         (/*HISTORY_HEADER*/int hhs[], int i);
   datetime hh_SyncMarker     (/*HISTORY_HEADER*/int hh[]);                         datetime hhs_SyncMarker     (/*HISTORY_HEADER*/int hhs[], int i);
   datetime hh_LastSyncTime   (/*HISTORY_HEADER*/int hh[]);                         datetime hhs_LastSyncTime   (/*HISTORY_HEADER*/int hhs[], int i);

   // Setter
   int      hh_SetBarFormat   (/*HISTORY_HEADER*/int hh[], int      format   );     int      hhs_SetBarFormat   (/*HISTORY_HEADER*/int hhs[], int i, int      format   );
   string   hh_SetCopyright   (/*HISTORY_HEADER*/int hh[], string   copyright);     string   hhs_SetCopyright   (/*HISTORY_HEADER*/int hhs[], int i, string   copyright);
   string   hh_SetSymbol      (/*HISTORY_HEADER*/int hh[], string   symbol   );     string   hhs_SetSymbol      (/*HISTORY_HEADER*/int hhs[], int i, string   symbol   );
   int      hh_SetPeriod      (/*HISTORY_HEADER*/int hh[], int      period   );     int      hhs_SetPeriod      (/*HISTORY_HEADER*/int hhs[], int i, int      period   );
   int      hh_SetTimeframe   (/*HISTORY_HEADER*/int hh[], int      timeframe);     int      hhs_SetTimeframe   (/*HISTORY_HEADER*/int hhs[], int i, int      timeframe);
   int      hh_SetDigits      (/*HISTORY_HEADER*/int hh[], int      digits   );     int      hhs_SetDigits      (/*HISTORY_HEADER*/int hhs[], int i, int      digits   );
   datetime hh_SetSyncMarker  (/*HISTORY_HEADER*/int hh[], datetime time     );     datetime hhs_SetSyncMarker  (/*HISTORY_HEADER*/int hhs[], int i, datetime time     );
   datetime hh_SetLastSyncTime(/*HISTORY_HEADER*/int hh[], datetime time     );     datetime hhs_SetLastSyncTime(/*HISTORY_HEADER*/int hhs[], int i, datetime time     );
#import


/**
 * Gibt die lesbare Repräsentation ein oder mehrerer struct HISTORY_HEADER zurück.
 *
 * @param  int  hh[]        - struct HISTORY_HEADER
 * @param  bool outputDebug - ob die Ausgabe zusätzlich zum Debugger geschickt werden soll (default: nein)
 *
 * @return string
 */
string HISTORY_HEADER.toStr(/*HISTORY_HEADER*/int hh[], bool outputDebug=false) {
   outputDebug = outputDebug!=0;

   int dimensions = ArrayDimension(hh);

   if (dimensions > 2)                                         return(_EMPTY_STR(catch("HISTORY_HEADER.toStr(1)  too many dimensions of parameter hh = "+ dimensions, ERR_INVALID_PARAMETER)));
   if (ArrayRange(hh, dimensions-1) != HISTORY_HEADER.intSize) return(_EMPTY_STR(catch("HISTORY_HEADER.toStr(2)  invalid size of parameter hh ("+ ArrayRange(hh, dimensions-1) +")", ERR_INVALID_PARAMETER)));

   string line, lines[]; ArrayResize(lines, 0);

   if (dimensions == 1) {
      // hh ist struct HISTORY_HEADER (eine Dimension)
      line = StringConcatenate("{format="      ,                   hh_BarFormat   (hh),
                              ", copyright="   ,    DoubleQuoteStr(hh_Copyright   (hh)),
                              ", symbol="      ,    DoubleQuoteStr(hh_Symbol      (hh)),
                              ", period="      , PeriodDescription(hh_Period      (hh)),
                              ", digits="      ,                   hh_Digits      (hh),
                              ", syncMarker="  ,          ifString(hh_SyncMarker  (hh), QuoteStr(TimeToStr(hh_SyncMarker  (hh), TIME_FULL)), 0),
                              ", lastSyncTime=",          ifString(hh_LastSyncTime(hh), QuoteStr(TimeToStr(hh_LastSyncTime(hh), TIME_FULL)), 0), "}");
      if (outputDebug)
         debug("HISTORY_HEADER.toStr()  "+ line);
      ArrayPushString(lines, line);
   }
   else {
      // hh ist struct[] HISTORY_HEADER (zwei Dimensionen)
      int size = ArrayRange(hh, 0);

      for (int i=0; i < size; i++) {
         line = StringConcatenate("[", i, "]={format="      ,                   hhs_BarFormat   (hh, i),
                                           ", copyright="   ,    DoubleQuoteStr(hhs_Copyright   (hh, i)),
                                           ", symbol="      ,    DoubleQuoteStr(hhs_Symbol      (hh, i)),
                                           ", period="      , PeriodDescription(hhs_Period      (hh, i)),
                                           ", digits="      ,                   hhs_Digits      (hh, i),
                                           ", syncMarker="  ,          ifString(hhs_SyncMarker  (hh, i), QuoteStr(TimeToStr(hhs_SyncMarker  (hh, i), TIME_FULL)), 0),
                                           ", lastSyncTime=",          ifString(hhs_LastSyncTime(hh, i), QuoteStr(TimeToStr(hhs_LastSyncTime(hh, i), TIME_FULL)), 0), "}");
         if (outputDebug)
            debug("HISTORY_HEADER.toStr()  "+ line);
         ArrayPushString(lines, line);
      }
   }

   string output = JoinStrings(lines, NL);
   ArrayResize(lines, 0);

   catch("HISTORY_HEADER.toStr(3)");
   return(output);
}
