/**
 * MT4 structure HISTORY_HEADER
 *
 * HistoryFile-Header (Kursreihen im "history"-Verzeichnis).
 */
#define I_HH.format            0
#define I_HH.description       1
#define I_HH.symbol           17
#define I_HH.period           20
#define I_HH.digits           21
#define I_HH.syncMark         22
#define I_HH.lastSync         23
#define I_HH.timezoneId       24


// Getter
int      hh.Format      (/*HISTORY_HEADER*/int hh[])          {                          return(hh[I_HH.format       ]);                           HISTORY_HEADER.toStr(hh); }
string   hh.Description (/*HISTORY_HEADER*/int hh[])          { return(GetString(GetIntsAddress(hh)+I_HH.description*4));                          HISTORY_HEADER.toStr(hh); }
string   hh.Symbol      (/*HISTORY_HEADER*/int hh[])          { return(GetString(GetIntsAddress(hh)+I_HH.symbol     *4));                          HISTORY_HEADER.toStr(hh); }
int      hh.Period      (/*HISTORY_HEADER*/int hh[])          {                          return(hh[I_HH.period       ]);                           HISTORY_HEADER.toStr(hh); }
int      hh.Digits      (/*HISTORY_HEADER*/int hh[])          {                          return(hh[I_HH.digits       ]);                           HISTORY_HEADER.toStr(hh); }
datetime hh.SyncMark    (/*HISTORY_HEADER*/int hh[])          {                          return(hh[I_HH.syncMark     ]);                           HISTORY_HEADER.toStr(hh); }
datetime hh.LastSync    (/*HISTORY_HEADER*/int hh[])          {                          return(hh[I_HH.lastSync     ]);                           HISTORY_HEADER.toStr(hh); }
int      hh.TimezoneId  (/*HISTORY_HEADER*/int hh[])          {                          return(hh[I_HH.timezoneId   ]);                           HISTORY_HEADER.toStr(hh); }
string   hh.Timezone    (/*HISTORY_HEADER*/int hh[])          {              return(__Timezones[hh[I_HH.timezoneId   ]]);                          HISTORY_HEADER.toStr(hh); }

int      hhs.Format     (/*HISTORY_HEADER*/int hh[][], int i) {                          return(hh[i][I_HH.format    ]);                           HISTORY_HEADER.toStr(hh); }
string   hhs.Description(/*HISTORY_HEADER*/int hh[][], int i) { return(GetString(GetIntsAddress(hh)+ ArrayRange(hh, 1)*i*4 + I_HH.description*4)); HISTORY_HEADER.toStr(hh); }
string   hhs.Symbol     (/*HISTORY_HEADER*/int hh[][], int i) { return(GetString(GetIntsAddress(hh)+ ArrayRange(hh, 1)*i*4 + I_HH.symbol     *4)); HISTORY_HEADER.toStr(hh); }
int      hhs.Period     (/*HISTORY_HEADER*/int hh[][], int i) {                          return(hh[i][I_HH.period    ]);                           HISTORY_HEADER.toStr(hh); }
int      hhs.Digits     (/*HISTORY_HEADER*/int hh[][], int i) {                          return(hh[i][I_HH.digits    ]);                           HISTORY_HEADER.toStr(hh); }
datetime hhs.SyncMark   (/*HISTORY_HEADER*/int hh[][], int i) {                          return(hh[i][I_HH.syncMark  ]);                           HISTORY_HEADER.toStr(hh); }
datetime hhs.LastSync   (/*HISTORY_HEADER*/int hh[][], int i) {                          return(hh[i][I_HH.lastSync  ]);                           HISTORY_HEADER.toStr(hh); }
int      hhs.TimezoneId (/*HISTORY_HEADER*/int hh[][], int i) {                          return(hh[i][I_HH.timezoneId]);                           HISTORY_HEADER.toStr(hh); }
string   hhs.Timezone   (/*HISTORY_HEADER*/int hh[][], int i) {              return(__Timezones[hh[i][I_HH.timezoneId]]);                          HISTORY_HEADER.toStr(hh); }


// Setter
int      hh.setFormat      (/*HISTORY_HEADER*/int &hh[],          int      format     ) { hh[I_HH.format     ] = format;      return(format     ); HISTORY_HEADER.toStr(hh); }
string   hh.setDescription (/*HISTORY_HEADER*/int &hh[],          string   description) {
   if (!StringLen(description)) description = "";                    // sicherstellen, daß der String initialisiert ist
   if ( StringLen(description) > 63)          return(_EMPTY_STR(catch("hh.setDescription(1)  too long parameter description = \""+ description +"\" (max 63 chars)", ERR_INVALID_PARAMETER)));
   int src  = GetStringAddress(description);
   int dest = GetIntsAddress(hh) + I_HH.description*4;
   CopyMemory(dest, src, StringLen(description)+1);                  /*terminierendes <NUL> wird mitkopiert*/                 return(description); HISTORY_HEADER.toStr(hh); }
string   hh.setSymbol      (/*HISTORY_HEADER*/int &hh[],          string   symbol     ) {
   if (!StringLen(symbol))                    return(_EMPTY_STR(catch("hh.setSymbol(1)  invalid parameter symbol = "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER)));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(_EMPTY_STR(catch("hh.setSymbol(2)  too long parameter symbol = \""+ symbol +"\" (max "+ MAX_SYMBOL_LENGTH +" chars)", ERR_INVALID_PARAMETER)));
   int src  = GetStringAddress(symbol);
   int dest = GetIntsAddress(hh) + I_HH.symbol*4;
   CopyMemory(dest, src, StringLen(symbol)+1);                       /*terminierendes <NUL> wird mitkopiert*/                 return(symbol     ); HISTORY_HEADER.toStr(hh); }
int      hh.setPeriod      (/*HISTORY_HEADER*/int &hh[],          int      period     ) { hh[I_HH.period     ] = period;      return(period     ); HISTORY_HEADER.toStr(hh); }
int      hh.setDigits      (/*HISTORY_HEADER*/int &hh[],          int      digits     ) { hh[I_HH.digits     ] = digits;      return(digits     ); HISTORY_HEADER.toStr(hh); }
datetime hh.setSyncMark    (/*HISTORY_HEADER*/int &hh[],          datetime time       ) { hh[I_HH.syncMark   ] = time;        return(time       ); HISTORY_HEADER.toStr(hh); }
datetime hh.setLastSync    (/*HISTORY_HEADER*/int &hh[],          datetime time       ) { hh[I_HH.lastSync   ] = time;        return(time       ); HISTORY_HEADER.toStr(hh); }

int      hhs.setFormat     (/*HISTORY_HEADER*/int &hh[][], int i, int      format     ) { hh[i][I_HH.format  ] = format;      return(format     ); HISTORY_HEADER.toStr(hh); }
string   hhs.setDescription(/*HISTORY_HEADER*/int &hh[][], int i, string   description) {
   if (!StringLen(description)) description = "";                    // sicherstellen, daß der String initialisiert ist
   if ( StringLen(description) > 63)          return(_EMPTY_STR(catch("hhs.setDescription(1)  too long parameter description = \""+ description +"\" (max 63 chars)", ERR_INVALID_PARAMETER)));
   int src  = GetStringAddress(description);
   int dest = GetIntsAddress(hh) + i*ArrayRange(hh, 1)*4 + I_HH.description*4;
   CopyMemory(dest, src, StringLen(description)+1);                  /*terminierendes <NUL> wird mitkopiert*/                 return(description); HISTORY_HEADER.toStr(hh); }
string   hhs.setSymbol     (/*HISTORY_HEADER*/int &hh[][], int i, string   symbol     ) {
   if (!StringLen(symbol))                    return(_EMPTY_STR(catch("hhs.setSymbol(1)  invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_PARAMETER)));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(_EMPTY_STR(catch("hhs.setSymbol(2)  too long parameter symbol = \""+ symbol +"\" (> "+ MAX_SYMBOL_LENGTH +")", ERR_INVALID_PARAMETER)));
   int src  = GetStringAddress(symbol);
   int dest = GetIntsAddress(hh) + i*ArrayRange(hh, 1)*4 + I_HH.symbol*4;
   CopyMemory(dest, src, StringLen(symbol)+1);                       /*terminierendes <NUL> wird mitkopiert*/                 return(symbol     ); HISTORY_HEADER.toStr(hh); }
int      hhs.setPeriod     (/*HISTORY_HEADER*/int &hh[][], int i, int      period     ) { hh[i][I_HH.period  ] = period;      return(period     ); HISTORY_HEADER.toStr(hh); }
int      hhs.setDigits     (/*HISTORY_HEADER*/int &hh[][], int i, int      digits     ) { hh[i][I_HH.digits  ] = digits;      return(digits     ); HISTORY_HEADER.toStr(hh); }
datetime hhs.setSyncMark   (/*HISTORY_HEADER*/int &hh[][], int i, datetime time       ) { hh[i][I_HH.syncMark] = time;        return(time       ); HISTORY_HEADER.toStr(hh); }
datetime hhs.setLastSync   (/*HISTORY_HEADER*/int &hh[][], int i, datetime time       ) { hh[i][I_HH.lastSync] = time;        return(time       ); HISTORY_HEADER.toStr(hh); }


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
      line = StringConcatenate("{format="     ,                   hh.Format     (hh),
                              ", description=",    DoubleQuoteStr(hh.Description(hh)),
                              ", symbol="     ,    DoubleQuoteStr(hh.Symbol     (hh)),
                              ", period="     , PeriodDescription(hh.Period     (hh)),
                              ", digits="     ,                   hh.Digits     (hh),
                              ", syncMark="   ,          ifString(hh.SyncMark   (hh), QuoteStr(TimeToStr(hh.SyncMark(hh), TIME_FULL)), 0),
                              ", lastSync="   ,          ifString(hh.LastSync   (hh), QuoteStr(TimeToStr(hh.LastSync(hh), TIME_FULL)), 0),
                              ", timezone="   ,    DoubleQuoteStr(hh.Timezone   (hh)), "}");
      if (outputDebug)
         debug("HISTORY_HEADER.toStr()  "+ line);
      ArrayPushString(lines, line);
   }
   else {
      // hh ist struct[] HISTORY_HEADER (zwei Dimensionen)
      int size = ArrayRange(hh, 0);

      for (int i=0; i < size; i++) {
         line = StringConcatenate("[", i, "]={format="     ,                   hhs.Format     (hh, i),
                                           ", description=",    DoubleQuoteStr(hhs.Description(hh, i)),
                                           ", symbol="     ,    DoubleQuoteStr(hhs.Symbol     (hh, i)),
                                           ", period="     , PeriodDescription(hhs.Period     (hh, i)),
                                           ", digits="     ,                   hhs.Digits     (hh, i),
                                           ", syncMark="   ,          ifString(hhs.SyncMark   (hh, i), QuoteStr(TimeToStr(hhs.SyncMark(hh, i), TIME_FULL)), 0),
                                           ", lastSync="   ,          ifString(hhs.LastSync   (hh, i), QuoteStr(TimeToStr(hhs.LastSync(hh, i), TIME_FULL)), 0),
                                           ", timezone="   ,    DoubleQuoteStr(hhs.Digits     (hh, i)), "}");
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
   hh.Format        (hh);       hhs.Format        (hh, NULL);
   hh.Description   (hh);       hhs.Description   (hh, NULL);
   hh.Symbol        (hh);       hhs.Symbol        (hh, NULL);
   hh.Period        (hh);       hhs.Period        (hh, NULL);
   hh.Digits        (hh);       hhs.Digits        (hh, NULL);
   hh.SyncMark      (hh);       hhs.SyncMark      (hh, NULL);
   hh.LastSync      (hh);       hhs.LastSync      (hh, NULL);
   hh.Timezone      (hh);       hhs.Timezone      (hh, NULL);
   hh.TimezoneId    (hh);       hhs.TimezoneId    (hh, NULL);

   hh.setFormat     (hh, NULL); hhs.setFormat     (hh, NULL, NULL);
   hh.setDescription(hh, NULL); hhs.setDescription(hh, NULL, NULL);
   hh.setSymbol     (hh, NULL); hhs.setSymbol     (hh, NULL, NULL);
   hh.setPeriod     (hh, NULL); hhs.setPeriod     (hh, NULL, NULL);
   hh.setDigits     (hh, NULL); hhs.setDigits     (hh, NULL, NULL);
   hh.setSyncMark   (hh, NULL); hhs.setSyncMark   (hh, NULL, NULL);
   hh.setLastSync   (hh, NULL); hhs.setLastSync   (hh, NULL, NULL);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


//#import "Expander.dll"
//   int      hh.Format         (/*HISTORY_HEADER*/int hh[]);
//   string   hh.Description    (/*HISTORY_HEADER*/int hh[]);
//   string   hh.Symbol         (/*HISTORY_HEADER*/int hh[]);
//   int      hh.Period         (/*HISTORY_HEADER*/int hh[]);
//   int      hh.Digits         (/*HISTORY_HEADER*/int hh[]);
//   datetime hh.SyncMark       (/*HISTORY_HEADER*/int hh[]);
//   datetime hh.LastSync       (/*HISTORY_HEADER*/int hh[]);

//   int      hhs.Format        (/*HISTORY_HEADER*/int hh[][], int i);
//   string   hhs.Description   (/*HISTORY_HEADER*/int hh[][], int i);
//   string   hhs.Symbol        (/*HISTORY_HEADER*/int hh[][], int i);
//   int      hhs.Period        (/*HISTORY_HEADER*/int hh[][], int i);
//   int      hhs.Digits        (/*HISTORY_HEADER*/int hh[][], int i);
//   datetime hhs.SyncMark      (/*HISTORY_HEADER*/int hh[][], int i);
//   datetime hhs.LastSync      (/*HISTORY_HEADER*/int hh[][], int i);

//   int      hh.setFormat      (/*HISTORY_HEADER*/int hh[], int      format     );
//   string   hh.setDescription (/*HISTORY_HEADER*/int hh[], string   description);
//   string   hh.setSymbol      (/*HISTORY_HEADER*/int hh[], string   symbol     );
//   int      hh.setPeriod      (/*HISTORY_HEADER*/int hh[], int      period     );
//   int      hh.setDigits      (/*HISTORY_HEADER*/int hh[], int      digits     );
//   datetime hh.setSyncMark    (/*HISTORY_HEADER*/int hh[], datetime time       );
//   datetime hh.setLastSync    (/*HISTORY_HEADER*/int hh[], datetime time       );

//   int      hhs.setFormat     (/*HISTORY_HEADER*/int hh[][], int i, int      format     );
//   string   hhs.setDescription(/*HISTORY_HEADER*/int hh[][], int i, string   description);
//   string   hhs.setSymbol     (/*HISTORY_HEADER*/int hh[][], int i, string   symbol     );
//   int      hhs.setPeriod     (/*HISTORY_HEADER*/int hh[][], int i, int      period     );
//   int      hhs.setDigits     (/*HISTORY_HEADER*/int hh[][], int i, int      digits     );
//   datetime hhs.setSyncMark   (/*HISTORY_HEADER*/int hh[][], int i, datetime time       );
//   datetime hhs.setLastSync   (/*HISTORY_HEADER*/int hh[][], int i, datetime time       );

//   string   HISTORY_HEADER.toStr(/*HISTORY_HEADER*/int hh[], int outputDebug);
//#import
