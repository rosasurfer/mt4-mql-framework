/**
 * MT4 structure HISTORY_HEADER
 *
 * Header der Historydateien (Kursreihen im "history"-Verzeichnis).
 *
 *                                  size         offset
 * struct HISTORY_HEADER {          ----         ------
 *   int    version;                   4      => hh[ 0]     // HST-Formatversion (MT4: immer 400)
 *   szchar description[64];          64      => hh[ 1]     // Beschreibung, <NUL>-terminiert
 *   szchar symbol[12];               12      => hh[17]     // Symbol, <NUL>-terminiert
 *   int    period;                    4      => hh[20]     // Timeframe
 *   int    digits;                    4      => hh[21]     // Digits
 *   int    dbVersion;                 4      => hh[22]     // Server-Datenbankversion (timestamp)
 *   int    prevDbVersion;             4      => hh[23]     // LastSync                (timestamp)   unbenutzt
 *   int    reserved[13];             52      => hh[24]     //                                       unbenutzt
 * } hh;                           = 148 byte = int[37]
 *
 *
 * @see  Importdeklarationen der entsprechenden Library am Ende dieser Datei
 */

// Getter
int      hh.Version          (/*HISTORY_HEADER*/int hh[])          {                  return(hh[ 0]);                                                                         HISTORY_HEADER.toStr(hh); }
string   hh.Description      (/*HISTORY_HEADER*/int hh[])          { return(BufferCharsToStr(hh, 4, 64));                                                                     HISTORY_HEADER.toStr(hh); }
string   hh.Symbol           (/*HISTORY_HEADER*/int hh[])          { return(BufferCharsToStr(hh,68, 12));                                                                     HISTORY_HEADER.toStr(hh); }
int      hh.Period           (/*HISTORY_HEADER*/int hh[])          {                  return(hh[20]);                                                                         HISTORY_HEADER.toStr(hh); }
int      hh.Digits           (/*HISTORY_HEADER*/int hh[])          {                  return(hh[21]);                                                                         HISTORY_HEADER.toStr(hh); }
datetime hh.DbVersion        (/*HISTORY_HEADER*/int hh[])          {                  return(hh[22]);                                                                         HISTORY_HEADER.toStr(hh); }
datetime hh.PrevDbVersion    (/*HISTORY_HEADER*/int hh[])          {                  return(hh[23]);                                                                         HISTORY_HEADER.toStr(hh); }

int      hhs.Version         (/*HISTORY_HEADER*/int hh[][], int i) {                  return(hh[i][ 0]);                                                                      HISTORY_HEADER.toStr(hh); }
string   hhs.Description     (/*HISTORY_HEADER*/int hh[][], int i) { return(BufferCharsToStr(hh, ArrayRange(hh, 1)*i*4 +  4, 64));                                            HISTORY_HEADER.toStr(hh); }
string   hhs.Symbol          (/*HISTORY_HEADER*/int hh[][], int i) { return(BufferCharsToStr(hh, ArrayRange(hh, 1)*i*4 + 68, 12));                                            HISTORY_HEADER.toStr(hh); }
int      hhs.Period          (/*HISTORY_HEADER*/int hh[][], int i) {                  return(hh[i][20]);                                                                      HISTORY_HEADER.toStr(hh); }
int      hhs.Digits          (/*HISTORY_HEADER*/int hh[][], int i) {                  return(hh[i][21]);                                                                      HISTORY_HEADER.toStr(hh); }
datetime hhs.DbVersion       (/*HISTORY_HEADER*/int hh[][], int i) {                  return(hh[i][22]);                                                                      HISTORY_HEADER.toStr(hh); }
datetime hhs.PrevDbVersion   (/*HISTORY_HEADER*/int hh[][], int i) {                  return(hh[i][23]);                                                                      HISTORY_HEADER.toStr(hh); }

// Setter
int      hh.setVersion       (/*HISTORY_HEADER*/int &hh[],          int      version    ) { hh[ 0] = version;                                            return(version    ); HISTORY_HEADER.toStr(hh); }
string   hh.setDescription   (/*HISTORY_HEADER*/int &hh[],          string   description) {
   if (!StringLen(description)) description = "";                    // sicherstellen, daß der String initialisiert ist
   if ( StringLen(description) > 63)          return(_empty(catch("hh.setDescription(1)   too long parameter description = \""+ description +"\" (max 63 chars)", ERR_INVALID_FUNCTION_PARAMVALUE)));
   CopyMemory(GetStringAddress(description), GetBufferAddress(hh)+4, StringLen(description)+1); /*terminierendes <NUL> wird mitkopiert*/                 return(description); HISTORY_HEADER.toStr(hh); }
string   hh.setSymbol        (/*HISTORY_HEADER*/int &hh[],          string   symbol     ) {
   if (!StringLen(symbol))                    return(_empty(catch("hh.setSymbol(1)   invalid parameter symbol = "+ StringToStr(symbol), ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(_empty(catch("hh.setSymbol(2)   too long parameter symbol = \""+ symbol +"\" (max "+ MAX_SYMBOL_LENGTH +" chars)", ERR_INVALID_FUNCTION_PARAMVALUE)));
   CopyMemory(GetStringAddress(symbol), GetBufferAddress(hh)+68, StringLen(symbol)+1); /*terminierendes <NUL> wird mitkopiert*/                          return(symbol     ); HISTORY_HEADER.toStr(hh); }
int      hh.setPeriod        (/*HISTORY_HEADER*/int &hh[],          int      period     ) { hh[20] = period;                                             return(period     ); HISTORY_HEADER.toStr(hh); }
int      hh.setDigits        (/*HISTORY_HEADER*/int &hh[],          int      digits     ) { hh[21] = digits;                                             return(digits     ); HISTORY_HEADER.toStr(hh); }
datetime hh.setDbVersion     (/*HISTORY_HEADER*/int &hh[],          datetime dbVersion  ) { hh[22] = dbVersion;                                          return(dbVersion  ); HISTORY_HEADER.toStr(hh); }
datetime hh.setPrevDbVersion (/*HISTORY_HEADER*/int &hh[],          datetime dbVersion  ) { hh[23] = dbVersion;                                          return(dbVersion  ); HISTORY_HEADER.toStr(hh); }

int      hhs.setVersion      (/*HISTORY_HEADER*/int &hh[][], int i, int      version    ) { hh[i][ 0] = version;                                         return(version    ); HISTORY_HEADER.toStr(hh); }
string   hhs.setDescription  (/*HISTORY_HEADER*/int &hh[][], int i, string   description) {
   if (!StringLen(description)) description = "";                    // sicherstellen, daß der String initialisiert ist
   if ( StringLen(description) > 63)          return(_empty(catch("hhs.setDescription(1)   too long parameter description = \""+ description +"\" (max 63 chars)", ERR_INVALID_FUNCTION_PARAMVALUE)));
   CopyMemory(GetStringAddress(description), GetBufferAddress(hh)+ i*ArrayRange(hh, 1)*4 + 4, StringLen(description)+1); /*term. <NUL> wird mitkopiert*/ return(description); HISTORY_HEADER.toStr(hh); }
string   hhs.setSymbol       (/*HISTORY_HEADER*/int &hh[][], int i, string   symbol     ) {
   if (!StringLen(symbol))                    return(_empty(catch("hhs.setSymbol(1)   invalid parameter symbol = \""+ symbol +"\"", ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(_empty(catch("hhs.setSymbol(2)   too long parameter symbol = \""+ symbol +"\" (> "+ MAX_SYMBOL_LENGTH +")", ERR_INVALID_FUNCTION_PARAMVALUE)));
   CopyMemory(GetStringAddress(symbol), GetBufferAddress(hh)+ i*ArrayRange(hh, 1)*4 + 68, StringLen(symbol)+1); /*terminierendes <NUL> wird mitkopiert*/ return(symbol     ); HISTORY_HEADER.toStr(hh); }
int      hhs.setPeriod       (/*HISTORY_HEADER*/int &hh[][], int i, int      period     ) { hh[i][20] = period;                                          return(period     ); HISTORY_HEADER.toStr(hh); }
int      hhs.setDigits       (/*HISTORY_HEADER*/int &hh[][], int i, int      digits     ) { hh[i][21] = digits;                                          return(digits     ); HISTORY_HEADER.toStr(hh); }
datetime hhs.setDbVersion    (/*HISTORY_HEADER*/int &hh[][], int i, datetime dbVersion  ) { hh[i][22] = dbVersion;                                       return(dbVersion  ); HISTORY_HEADER.toStr(hh); }
datetime hhs.setPrevDbVersion(/*HISTORY_HEADER*/int &hh[][], int i, datetime dbVersion  ) { hh[i][23] = dbVersion;                                       return(dbVersion  ); HISTORY_HEADER.toStr(hh); }


/**
 * Gibt die lesbare Repräsentation ein oder mehrerer HISTORY_HEADER-Strukturen zurück.
 *
 * @param  int  hh[]     - HISTORY_HEADER
 * @param  bool debugger - ob die Ausgabe zusätzlich zum Debugger geschickt werden soll (default: nein)
 *
 * @return string
 */
string HISTORY_HEADER.toStr(/*HISTORY_HEADER*/int hh[], bool debugger=false) {
   debugger = debugger!=0;

   int dimensions = ArrayDimension(hh);

   if (dimensions > 2)                                         return(_empty(catch("HISTORY_HEADER.toStr(1)   too many dimensions of parameter hh = "+ dimensions, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (ArrayRange(hh, dimensions-1) != HISTORY_HEADER.intSize) return(_empty(catch("HISTORY_HEADER.toStr(2)   invalid size of parameter hh ("+ ArrayRange(hh, dimensions-1) +")", ERR_INVALID_FUNCTION_PARAMVALUE)));

   string line, lines[]; ArrayResize(lines, 0);

   if (dimensions == 1) {
      // hh ist struct HISTORY_HEADER (eine Dimension)
      line = StringConcatenate("{version="      ,                   hh.Version      (hh),
                              ", description=\"",                   hh.Description  (hh), "\"",
                              ", symbol=\""     ,                   hh.Symbol       (hh), "\"",
                              ", period="       , PeriodDescription(hh.Period       (hh)),
                              ", digits="       ,                   hh.Digits       (hh),
                              ", dbVersion="    ,          ifString(hh.DbVersion    (hh), "'"+ TimeToStr(hh.DbVersion    (hh), TIME_FULL) +"'", 0),
                              ", prevDbVersion=",          ifString(hh.PrevDbVersion(hh), "'"+ TimeToStr(hh.PrevDbVersion(hh), TIME_FULL) +"'", 0), "}");
      if (debugger)
         debug("HISTORY_HEADER.toStr()   "+ line);
      ArrayPushString(lines, line);
   }
   else {
      // hh ist struct[] HISTORY_HEADER (zwei Dimensionen)
      int size = ArrayRange(hh, 0);

      for (int i=0; i < size; i++) {
         line = StringConcatenate("[", i, "]={version="      ,                   hhs.Version      (hh, i),
                                           ", description=\"",                   hhs.Description  (hh, i), "\"",
                                           ", symbol=\""     ,                   hhs.Symbol       (hh, i), "\"",
                                           ", period="       , PeriodDescription(hhs.Period       (hh, i)),
                                           ", digits="       ,                   hhs.Digits       (hh, i),
                                           ", dbVersion="    ,          ifString(hhs.DbVersion    (hh, i), "'"+ TimeToStr(hhs.DbVersion    (hh, i), TIME_FULL) +"'", 0),
                                           ", prevDbVersion=",          ifString(hhs.PrevDbVersion(hh, i), "'"+ TimeToStr(hhs.PrevDbVersion(hh, i), TIME_FULL) +"'", 0), "}");
         if (debugger)
            debug("HISTORY_HEADER.toStr()   "+ line);
         ArrayPushString(lines, line);
      }
   }

   string output = JoinStrings(lines, NL);
   ArrayResize(lines, 0);

   catch("HISTORY_HEADER.toStr(3)");
   return(output);


   // Dummy-Calls: unterdrücken unnütze Compilerwarnungen
   hh.Version         (hh);       hhs.Version         (hh, NULL);
   hh.Description     (hh);       hhs.Description     (hh, NULL);
   hh.Symbol          (hh);       hhs.Symbol          (hh, NULL);
   hh.Period          (hh);       hhs.Period          (hh, NULL);
   hh.Digits          (hh);       hhs.Digits          (hh, NULL);
   hh.DbVersion       (hh);       hhs.DbVersion       (hh, NULL);
   hh.PrevDbVersion   (hh);       hhs.PrevDbVersion   (hh, NULL);

   hh.setVersion      (hh, NULL); hhs.setVersion      (hh, NULL, NULL);
   hh.setDescription  (hh, NULL); hhs.setDescription  (hh, NULL, NULL);
   hh.setSymbol       (hh, NULL); hhs.setSymbol       (hh, NULL, NULL);
   hh.setPeriod       (hh, NULL); hhs.setPeriod       (hh, NULL, NULL);
   hh.setDigits       (hh, NULL); hhs.setDigits       (hh, NULL, NULL);
   hh.setDbVersion    (hh, NULL); hhs.setDbVersion    (hh, NULL, NULL);
   hh.setPrevDbVersion(hh, NULL); hhs.setPrevDbVersion(hh, NULL, NULL);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   string BufferCharsToStr(int buffer[], int from, int length);
   void   CopyMemory(int source, int destination, int bytes);
   string JoinStrings(string array[], string separator);
   string StringToStr(string value);

#import "StdLib.dll"
   int    GetBufferAddress(int buffer[]);
   int    GetStringAddress(string value);
#import


// --------------------------------------------------------------------------------------------------------------------------------------------------


//#import "struct.HISTORY_HEADER.ex4"
//   int      hh.Version          (/*HISTORY_HEADER*/int hh[]);
//   string   hh.Description      (/*HISTORY_HEADER*/int hh[]);
//   string   hh.Symbol           (/*HISTORY_HEADER*/int hh[]);
//   int      hh.Period           (/*HISTORY_HEADER*/int hh[]);
//   int      hh.Digits           (/*HISTORY_HEADER*/int hh[]);
//   datetime hh.DbVersion        (/*HISTORY_HEADER*/int hh[]);
//   datetime hh.PrevDbVersion    (/*HISTORY_HEADER*/int hh[]);

//   int      hhs.Version         (/*HISTORY_HEADER*/int hh[][], int i);
//   string   hhs.Description     (/*HISTORY_HEADER*/int hh[][], int i);
//   string   hhs.Symbol          (/*HISTORY_HEADER*/int hh[][], int i);
//   int      hhs.Period          (/*HISTORY_HEADER*/int hh[][], int i);
//   int      hhs.Digits          (/*HISTORY_HEADER*/int hh[][], int i);
//   datetime hhs.DbVersion       (/*HISTORY_HEADER*/int hh[][], int i);
//   datetime hhs.PrevDbVersion   (/*HISTORY_HEADER*/int hh[][], int i);

//   int      hh.setVersion       (/*HISTORY_HEADER*/int hh[], int      version    );
//   string   hh.setDescription   (/*HISTORY_HEADER*/int hh[], string   description);
//   string   hh.setSymbol        (/*HISTORY_HEADER*/int hh[], string   symbol     );
//   int      hh.setPeriod        (/*HISTORY_HEADER*/int hh[], int      period     );
//   int      hh.setDigits        (/*HISTORY_HEADER*/int hh[], int      digits     );
//   datetime hh.setDbVersion     (/*HISTORY_HEADER*/int hh[], datetime dbVersion  );
//   datetime hh.setPrevDbVersion (/*HISTORY_HEADER*/int hh[], datetime dbVersion  );

//   int      hhs.setVersion      (/*HISTORY_HEADER*/int hh[][], int i, int      version    );
//   string   hhs.setDescription  (/*HISTORY_HEADER*/int hh[][], int i, string   description);
//   string   hhs.setSymbol       (/*HISTORY_HEADER*/int hh[][], int i, string   symbol     );
//   int      hhs.setPeriod       (/*HISTORY_HEADER*/int hh[][], int i, int      period     );
//   int      hhs.setDigits       (/*HISTORY_HEADER*/int hh[][], int i, int      digits     );
//   datetime hhs.setDbVersion    (/*HISTORY_HEADER*/int hh[][], int i, datetime dbVersion  );
//   datetime hhs.setPrevDbVersion(/*HISTORY_HEADER*/int hh[][], int i, datetime dbVersion  );

//   string   HISTORY_HEADER.toStr(/*HISTORY_HEADER*/int hh[], bool debugger);
//#import
