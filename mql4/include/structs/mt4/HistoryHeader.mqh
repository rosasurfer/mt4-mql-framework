/**
 * MT4 struct HISTORY_HEADER (Header der Kursreihen im "history"-Verzeichnis)
 *
 * HistoryFile Header
 *
 * @see  MT4Expander::header/mql/structs/mt4/HistoryHeader.h
 */
#define I_HH.format            0
#define I_HH.description       1
#define I_HH.symbol           17
#define I_HH.period           20
#define I_HH.digits           21
#define I_HH.syncMarker       22
#define I_HH.lastSyncTime     23


#import "Expander.dll"
   // Getter
   int      hh_BarFormat   (/*HISTORY_HEADER*/int hh[]);    int      hhs_BarFormat   (/*HISTORY_HEADER*/int hhs[], int i);
   string   hh_Description (/*HISTORY_HEADER*/int hh[]);    string   hhs_Description (/*HISTORY_HEADER*/int hhs[], int i);
   string   hh_Symbol      (/*HISTORY_HEADER*/int hh[]);    string   hhs_Symbol      (/*HISTORY_HEADER*/int hhs[], int i);
   int      hh_Period      (/*HISTORY_HEADER*/int hh[]);    int      hhs_Period      (/*HISTORY_HEADER*/int hhs[], int i);
   int      hh_Digits      (/*HISTORY_HEADER*/int hh[]);    int      hhs_Digits      (/*HISTORY_HEADER*/int hhs[], int i);
   datetime hh_SyncMarker  (/*HISTORY_HEADER*/int hh[]);    datetime hhs_SyncMarker  (/*HISTORY_HEADER*/int hhs[], int i);
   datetime hh_LastSyncTime(/*HISTORY_HEADER*/int hh[]);    datetime hhs_LastSyncTime(/*HISTORY_HEADER*/int hhs[], int i);

   // Setter
   bool     hh_SetBarFormat(/*HISTORY_HEADER*/int hh[], int format);   bool hhs_SetBarFormat(/*HISTORY_HEADER*/int hhs[], int i, int format);
#import


// Setter
string   hh.setDescription  (/*HISTORY_HEADER*/int &hh[],          string   description) {
   if (!StringLen(description)) description = "";                    // sicherstellen, daß der String initialisiert ist
   if ( StringLen(description) > 63)          return(_EMPTY_STR(catch("hh.setDescription(1)  too long parameter description = \""+ description +"\" (max 63 chars)", ERR_INVALID_PARAMETER)));
   string array[]; ArrayResize(array, 1); array[0]=description;
   int src  = GetStringAddress(array[0]);
   int dest = GetIntsAddress(hh) + I_HH.description*4;
   CopyMemory(dest, src, StringLen(description)+1);                  /*terminierendes <NUL> wird mitkopiert*/
   ArrayResize(array, 0);                                                                                                      return(description); HISTORY_HEADER.toStr(hh); }
string   hh.setSymbol       (/*HISTORY_HEADER*/int &hh[],          string   symbol     ) {
   if (!StringLen(symbol))                    return(_EMPTY_STR(catch("hh.setSymbol(1)  invalid parameter symbol = "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER)));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(_EMPTY_STR(catch("hh.setSymbol(2)  too long parameter symbol = \""+ symbol +"\" (max "+ MAX_SYMBOL_LENGTH +" chars)", ERR_INVALID_PARAMETER)));
   string array[]; ArrayResize(array, 1); array[0]=symbol;
   int src  = GetStringAddress(array[0]);
   int dest = GetIntsAddress(hh) + I_HH.symbol*4;
   CopyMemory(dest, src, StringLen(symbol)+1);                       /*terminierendes <NUL> wird mitkopiert*/
   ArrayResize(array, 0);                                                                                                      return(symbol     ); HISTORY_HEADER.toStr(hh); }
int      hh.setPeriod       (/*HISTORY_HEADER*/int &hh[],          int      period     ) { hh[I_HH.period      ] = period;     return(period     ); HISTORY_HEADER.toStr(hh); }
int      hh.setDigits       (/*HISTORY_HEADER*/int &hh[],          int      digits     ) { hh[I_HH.digits      ] = digits;     return(digits     ); HISTORY_HEADER.toStr(hh); }
datetime hh.setSyncMarker   (/*HISTORY_HEADER*/int &hh[],          datetime time       ) { hh[I_HH.syncMarker  ] = time;       return(time       ); HISTORY_HEADER.toStr(hh); }
datetime hh.setLastSyncTime (/*HISTORY_HEADER*/int &hh[],          datetime time       ) { hh[I_HH.lastSyncTime] = time;       return(time       ); HISTORY_HEADER.toStr(hh); }

string   hhs.setDescription (/*HISTORY_HEADER*/int &hh[][], int i, string   description) {
   if (!StringLen(description)) description = "";                    // sicherstellen, daß der String initialisiert ist
   if ( StringLen(description) > 63)          return(_EMPTY_STR(catch("hhs.setDescription(1)  too long parameter description = \""+ description +"\" (max 63 chars)", ERR_INVALID_PARAMETER)));
   string array[]; ArrayResize(array, 1); array[0]=description;
   int src  = GetStringAddress(array[0]);
   int dest = GetIntsAddress(hh) + i*ArrayRange(hh, 1)*4 + I_HH.description*4;
   CopyMemory(dest, src, StringLen(description)+1);                  /*terminierendes <NUL> wird mitkopiert*/
   ArrayResize(array, 0);                                                                                                      return(description); HISTORY_HEADER.toStr(hh); }
string   hhs.setSymbol      (/*HISTORY_HEADER*/int &hh[][], int i, string   symbol     ) {
   if (!StringLen(symbol))                    return(_EMPTY_STR(catch("hhs.setSymbol(1)  invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_PARAMETER)));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(_EMPTY_STR(catch("hhs.setSymbol(2)  too long parameter symbol = \""+ symbol +"\" (> "+ MAX_SYMBOL_LENGTH +")", ERR_INVALID_PARAMETER)));
   string array[]; ArrayResize(array, 1); array[0]=symbol;
   int src  = GetStringAddress(array[0]);
   int dest = GetIntsAddress(hh) + i*ArrayRange(hh, 1)*4 + I_HH.symbol*4;
   CopyMemory(dest, src, StringLen(symbol)+1);                       /*terminierendes <NUL> wird mitkopiert*/
   ArrayResize(array, 0);                                                                                                      return(symbol     ); HISTORY_HEADER.toStr(hh); }
int      hhs.setPeriod      (/*HISTORY_HEADER*/int &hh[][], int i, int      period     ) { hh[i][I_HH.period      ] = period;  return(period     ); HISTORY_HEADER.toStr(hh); }
int      hhs.setDigits      (/*HISTORY_HEADER*/int &hh[][], int i, int      digits     ) { hh[i][I_HH.digits      ] = digits;  return(digits     ); HISTORY_HEADER.toStr(hh); }
datetime hhs.setSyncMarker  (/*HISTORY_HEADER*/int &hh[][], int i, datetime time       ) { hh[i][I_HH.syncMarker  ] = time;    return(time       ); HISTORY_HEADER.toStr(hh); }
datetime hhs.setLastSyncTime(/*HISTORY_HEADER*/int &hh[][], int i, datetime time       ) { hh[i][I_HH.lastSyncTime] = time;    return(time       ); HISTORY_HEADER.toStr(hh); }


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
                              ", description=" ,    DoubleQuoteStr(hh_Description (hh)),
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
                                           ", description=" ,    DoubleQuoteStr(hhs_Description (hh, i)),
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

   // Dummy-Calls: unterdrücken unnütze Compilerwarnungen
   hh.setDescription (hh, NULL); hhs.setDescription (hh, NULL, NULL);
   hh.setSymbol      (hh, NULL); hhs.setSymbol      (hh, NULL, NULL);
   hh.setPeriod      (hh, NULL); hhs.setPeriod      (hh, NULL, NULL);
   hh.setDigits      (hh, NULL); hhs.setDigits      (hh, NULL, NULL);
   hh.setSyncMarker  (hh, NULL); hhs.setSyncMarker  (hh, NULL, NULL);
   hh.setLastSyncTime(hh, NULL); hhs.setLastSyncTime(hh, NULL, NULL);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


//#import "Expander.dll"
//   string   hh.setDescription  (/*HISTORY_HEADER*/int hh[], string   description);
//   string   hh.setSymbol       (/*HISTORY_HEADER*/int hh[], string   symbol     );
//   int      hh.setPeriod       (/*HISTORY_HEADER*/int hh[], int      period     );
//   int      hh.setDigits       (/*HISTORY_HEADER*/int hh[], int      digits     );
//   datetime hh.setSyncMarker   (/*HISTORY_HEADER*/int hh[], datetime time       );
//   datetime hh.setLastSyncTime (/*HISTORY_HEADER*/int hh[], datetime time       );

//   string   hhs.setDescription (/*HISTORY_HEADER*/int hh[][], int i, string   description);
//   string   hhs.setSymbol      (/*HISTORY_HEADER*/int hh[][], int i, string   symbol     );
//   int      hhs.setPeriod      (/*HISTORY_HEADER*/int hh[][], int i, int      period     );
//   int      hhs.setDigits      (/*HISTORY_HEADER*/int hh[][], int i, int      digits     );
//   datetime hhs.setSyncMarker  (/*HISTORY_HEADER*/int hh[][], int i, datetime time       );
//   datetime hhs.setLastSyncTime(/*HISTORY_HEADER*/int hh[][], int i, datetime time       );

//   string   HISTORY_HEADER.toStr(/*HISTORY_HEADER*/int hh[], int outputDebug);
//#import
