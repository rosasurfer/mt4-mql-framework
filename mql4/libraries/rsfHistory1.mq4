/**
 * Management of single history files (1 timeframe) and full history sets (9 timeframes).
 *
 *
 * Usage examples
 * --------------
 *  - Open an existing history (all timeframes) with existing data (e.g. for appending data):
 *     int hSet = HistorySet1.Get(symbol);
 *
 *  - Create a new history and delete all existing data (e.g. for writing a new history):
 *     int hSet = HistorySet1.Create(symbol, description, digits, format);
 *
 *  - How to sync rsfHistory{1-3}.mq4:
 *     search:  (HistoryFile|HistorySet)[1-3]\>
 *     replace: \1{1-3}
 *
 *
 * Notes:
 * ------
 *  - The MQL4 language in terminal builds <= 509 imposes a limit of 16 open files per MQL module. In terminal builds > 509
 *    this limit was extended to 64 open files per MQL module. It means older terminals can manage max. 1 full history set
 *    and newer terminals max. 7 full history sets per MQL module. For some use cases this is still not sufficient.
 *    To overcome this limits there are 3 fully identical history libraries, extending the limits for newer terminal builds
 *    to max. 21 full history sets per MQL program.
 *
 *  - Since terminal builds > 509 MT4 supports two history file formats. The format is identified in history files by the
 *    field HISTORY_HEADER.barFormat. The default bar format in builds <= 509 is "400" and in builds > 509 "401".
 *    Builds <= 509 can only read/write format "400". Builds > 509 can read both formats but write only format "401".
 *
 *  - If a terminal build <= 509 accesses history files in new format (401) it will delete those files on shutdown.
 *
 *  - If a terminal build > 509 accesses history files in old format (400) it will convert them to the new format (401) except
 *    offline history files for custom symbols. Such offline history files will not be converted.
 *
 *  @see  https://github.com/rosasurfer/mt4-expander/blob/master/header/struct/mt4/HistoryHeader.h
 */
#property library

#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];
#include <core/library.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/mt4/HistoryHeader.mqh>


// Standard-Timeframes ------------------------------------------------------------------------------------------------------------------------------------
int      periods[] = { PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1 };


// Daten kompletter History-Sets --------------------------------------------------------------------------------------------------------------------------
int      hs.hSet       [];                            // Set-Handle: größer 0 = offenes Handle; kleiner 0 = geschlossenes Handle; 0 = ungültiges Handle
int      hs.hSet.lastValid;                           // das letzte gültige, offene Handle (um ein übergebenes Handle nicht ständig neu validieren zu müssen)
string   hs.symbol     [];                            // Symbol
string   hs.symbolUpper[];                            // SYMBOL (Upper-Case)
string   hs.description[];                            // Beschreibung
int      hs.digits     [];                            // Symbol-Digits
string   hs.server     [];                            // Servername des Sets
int      hs.hFile      [][9];                         // HistoryFile-Handles des Sets je Standard-Timeframe
int      hs.format     [];                            // Datenformat für neu zu erstellende HistoryFiles


// Daten einzelner History-Files --------------------------------------------------------------------------------------------------------------------------
int      hf.hFile      [];                            // Dateihandle: größer 0 = offenes Handle; kleiner 0 = geschlossenes Handle; 0 = ungültiges Handle
int      hf.hFile.lastValid;                          // das letzte gültige, offene Handle (um ein übergebenes Handle nicht ständig neu validieren zu müssen)
string   hf.name       [];                            // Dateiname, ggf. mit Unterverzeichnis "XTrade-Synthetic\"
bool     hf.readAccess [];                            // ob das Handle Lese-Zugriff erlaubt
bool     hf.writeAccess[];                            // ob das Handle Schreib-Zugriff erlaubt

int      hf.header     [][HISTORY_HEADER_intSize];    // History-Header der Datei
int      hf.format     [];                            // Datenformat: 400 | 401
int      hf.barSize    [];                            // Größe einer Bar entsprechend dem Datenformat
string   hf.symbol     [];                            // Symbol
string   hf.symbolUpper[];                            // SYMBOL (Upper-Case)
int      hf.period     [];                            // Periode
int      hf.periodSecs [];                            // Dauer einer Periode in Sekunden (nicht gültig für Perioden > 1 Woche)
int      hf.digits     [];                            // Digits
string   hf.server     [];                            // Servername der Datei

int      hf.stored.bars              [];              // Metadaten: Anzahl der gespeicherten Bars der Datei
int      hf.stored.from.offset       [];              // Offset der ersten gespeicherten Bar der Datei
datetime hf.stored.from.openTime     [];              // OpenTime der ersten gespeicherten Bar der Datei
datetime hf.stored.from.closeTime    [];              // CloseTime der ersten gespeicherten Bar der Datei
datetime hf.stored.from.nextCloseTime[];              // CloseTime der der ersten gespeicherten Bar der Datei folgenden Bar
int      hf.stored.to.offset         [];              // Offset der letzten gespeicherten Bar der Datei
datetime hf.stored.to.openTime       [];              // OpenTime der letzten gespeicherten Bar der Datei
datetime hf.stored.to.closeTime      [];              // CloseTime der letzten gespeicherten Bar der Datei
datetime hf.stored.to.nextCloseTime  [];              // CloseTime der der letzten gespeicherten Bar der Datei folgenden Bar

int      hf.full.bars                [];              // Metadaten: Anzahl der Bars der Datei inkl. ungespeicherter Daten im Schreibpuffer
int      hf.full.from.offset         [];              // Offset der ersten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer
datetime hf.full.from.openTime       [];              // OpenTime der ersten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer
datetime hf.full.from.closeTime      [];              // CloseTime der ersten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer
datetime hf.full.from.nextCloseTime  [];              // CloseTime der der ersten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer folgenden Bar
int      hf.full.to.offset           [];              // Offset der letzten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer
datetime hf.full.to.openTime         [];              // OpenTime der letzten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer
datetime hf.full.to.closeTime        [];              // CloseTime der letzten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer
datetime hf.full.to.nextCloseTime    [];              // CloseTime dre der letzten Bar der Datei inkl. ungespeicherter Daten im Schreibpuffer folgenden Bar


// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Cache der Bar, die in der Historydatei zuletzt gelesen oder geschrieben wurde (eine beliebige in der Datei existierende Bar).
//
// (1) Beim Aktualisieren dieser Bar mit neuen Ticks braucht die Bar nicht jedesmal neu eingelesen werden: siehe HistoryFile1.UpdateBar().
// (2) Bei funktionsübergreifenden Abläufen muß diese Bar nicht überall als Parameter durchgeschleift werden (durch unterschiedliche Arraydimensionen schwierig).
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
int      hf.lastStoredBar.offset       [];            // Offset relativ zum Header: Offset 0 ist die älteste Bar, initialisiert mit -1
datetime hf.lastStoredBar.openTime     [];            // z.B. 12:00:00      |                  time < openTime:      time liegt irgendwo in einer vorherigen Bar
datetime hf.lastStoredBar.closeTime    [];            //      13:00:00      |      openTime <= time < closeTime:     time liegt genau in der Bar
datetime hf.lastStoredBar.nextCloseTime[];            //      14:00:00      |     closeTime <= time < nextCloseTime: time liegt genau in der nächsten Bar
double   hf.lastStoredBar.data         [][6];         // Bardaten (T-OHLCV) | nextCloseTime <= time:                 time liegt irgendwo vor der nächsten Bar


// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Schreibpuffer für eintreffende Ticks einer bereits gespeicherten oder noch nicht gespeicherten Bar. Die Variable hf.bufferedBar.modified signalisiert, ob die
// Bardaten in hf.bufferedBar von den in der Datei gespeicherten Daten abweichen.
//
// (1) Diese Bar stimmt mit hf.lastStoredBar nur dann überein, wenn hf.lastStoredBar die jüngste Bar der Datei ist und mit HST_BUFFER_TICKS=On weitere Ticks für diese
//     jüngste Bar gepuffert werden. Stimmen beide Bars überein, werden sie bei Änderungen an einer der Bars jeweils synchronisiert.
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
int      hf.bufferedBar.offset       [];              // Offset relativ zum Header: Offset 0 ist die älteste Bar, initialisiert mit -1
datetime hf.bufferedBar.openTime     [];              // z.B. 12:00:00      |                  time < openTime:      time liegt irgendwo in einer vorherigen Bar
datetime hf.bufferedBar.closeTime    [];              //      13:00:00      |      openTime <= time < closeTime:     time liegt genau in der Bar
datetime hf.bufferedBar.nextCloseTime[];              //      14:00:00      |     closeTime <= time < nextCloseTime: time liegt genau in der nächsten Bar
double   hf.bufferedBar.data         [][6];           // Bardaten (T-OHLCV) | nextCloseTime <= time:                 time liegt irgendwo vor der nächsten Bar
bool     hf.bufferedBar.modified     [];              // ob die Daten seit dem letzten Schreiben modifiziert wurden


/**
 * Erzeugt für ein Symbol ein neues HistorySet mit den angegebenen Daten und gibt dessen Handle zurück. Beim Aufruf der Funktion werden
 * bereits existierende HistoryFiles des Symbols zurückgesetzt (vorhandene Bardaten werden gelöscht) und evt. offene HistoryFile-Handles
 * geschlossen. Noch nicht existierende HistoryFiles werden beim ersten Speichern hinzugefügter Daten automatisch erstellt.
 *
 * Mehrfachaufrufe dieser Funktion für dasselbe Symbol geben jeweils ein neues Handle zurück, ein vorheriges Handle wird geschlossen.
 *
 * @param  string symbol      - Symbol
 * @param  string description - Beschreibung
 * @param  int    digits      - Digits der Datenreihe
 * @param  int    format      - Speicherformat der Datenreihe: 400 - altes Datenformat (wie MetaTrader <= Build 509)
 *                                                             401 - neues Datenformat (wie MetaTrader  > Build 509)
 * @param  string server      - Name des Serververzeichnisses, in dem das Set gespeichert wird (default: aktuelles Serververzeichnis)
 *
 * @return int - Set-Handle oder NULL, falls ein Fehler auftrat.
 */
int HistorySet1.Create(string symbol, string description, int digits, int format, string server="") {
   // Parametervalidierung
   if (!StringLen(symbol))                    return(!catch("HistorySet1.Create(1)  invalid parameter symbol: "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(!catch("HistorySet1.Create(2)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (max "+ MAX_SYMBOL_LENGTH +" characters)", ERR_INVALID_PARAMETER));
   if (StrContains(symbol, " "))              return(!catch("HistorySet1.Create(3)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (must not contain spaces)", ERR_INVALID_PARAMETER));
   string symbolUpper = StrToUpper(symbol);
   if (!StringLen(description)) {
      description = "";                                                          // NULL-Pointer => Leerstring
   }
   else if (StringLen(description) > 63) {                                       // ein zu langer String wird gekürzt
      logNotice("HistorySet1.Create(4)  truncating too long history description "+ DoubleQuoteStr(description) +" to 63 chars...");
      description = StrLeft(description, 63);
   }
   if (digits < 0)                            return(!catch("HistorySet1.Create(5)  invalid parameter digits: "+ digits +" [hstSet="+ DoubleQuoteStr(symbol) +"]", ERR_INVALID_PARAMETER));
   if (format!=400) /*&&*/ if (format!=401)   return(!catch("HistorySet1.Create(6)  invalid parameter format: "+ format +" (can be 400 or 401) [hstSet="+ DoubleQuoteStr(symbol) +"]", ERR_INVALID_PARAMETER));
   if (server == "0")      server = "";                                          // (string) NULL
   if (!StringLen(server)) server = GetAccountServer();


   // (1) offene Set-Handles durchsuchen und Sets schließen
   int size = ArraySize(hs.hSet);
   for (int i=0; i < size; i++) {                                       // Das Handle muß offen sein.
      if (hs.hSet[i] > 0) /*&&*/ if (hs.symbolUpper[i]==symbolUpper) /*&&*/ if (StrCompareI(hs.server[i], server)) {
         // wenn Symbol gefunden, Set schließen...
         if (hs.hSet.lastValid == hs.hSet[i])
            hs.hSet.lastValid = NULL;
         hs.hSet[i] = -1;

         // Dateien des Sets schließen...
         size = ArrayRange(hs.hFile, 1);
         for (int n=0; n < size; n++) {
            if (hs.hFile[i][n] > 0) {
               if (!HistoryFile1.Close(hs.hFile[i][n]))
                  return(NULL);
               hs.hFile[i][n] = -1;
            }
         }
      }
   }


   // (2) offene File-Handles durchsuchen und Dateien schließen
   size = ArraySize(hf.hFile);
   for (i=0; i < size; i++) {                                           // Das Handle muß offen sein.
      if (hf.hFile[i] > 0) /*&&*/ if (hf.symbolUpper[i]==symbolUpper) /*&&*/ if (StrCompareI(hf.server[i], server)){
         if (!HistoryFile1.Close(hf.hFile[i]))
            return(NULL);
      }
   }


   // (3) existierende HistoryFiles zurücksetzen und ihre Header aktualisieren
   string mqlHstDir  = "history\\"+ server +"\\";                       // Verzeichnisname für MQL-Dateifunktionen
   string fullHstDir = GetMqlFilesPath()+"\\"+ mqlHstDir;               // Verzeichnisname für Win32-Dateifunktionen
   string baseName="", mqlFileName="", fullFileName="";
   int hFile, fileSize, sizeOfPeriods=ArraySize(periods), error;

   /*HISTORY_HEADER*/int hh[]; InitializeByteBuffer(hh, HISTORY_HEADER_size);
   hh_SetBarFormat  (hh, format     );
   hh_SetDescription(hh, description);
   hh_SetSymbol     (hh, symbol     );
   hh_SetDigits     (hh, digits     );

   for (i=0; i < sizeOfPeriods; i++) {
      baseName = symbol + periods[i] +".hst";
      mqlFileName  = mqlHstDir  + baseName;                             // Dateiname für MQL-Dateifunktionen
      fullFileName = fullHstDir + baseName;                             // Dateiname für Win32-Dateifunktionen

      if (IsFileA(fullFileName)) {                                      // wenn Datei existiert, auf 0 zurücksetzen
         hFile = FileOpen(mqlFileName, FILE_BIN|FILE_WRITE);
         if (hFile <= 0) return(!catch("HistorySet1.Create(7)  fileName=\""+ mqlFileName +"\"  hFile="+ hFile, ifIntOr(GetLastError(), ERR_RUNTIME_ERROR)));

         hh_SetPeriod(hh, periods[i]);
         FileWriteArray(hFile, hh, 0, ArraySize(hh));                   // neuen HISTORY_HEADER schreiben
         FileClose(hFile);
         if (!catch("HistorySet1.Create(8)  [hstSet="+ DoubleQuoteStr(symbol) +"]"))
            continue;
         return(NULL);
      }
   }
   ArrayResize(hh, 0);


   // (4) neues HistorySet erzeugen
   size = Max(ArraySize(hs.hSet), 1) + 1;                               // minSize=2: auf Index[0] kann kein gültiges Handle liegen
   ResizeSetArrays(size);
   int iH   = size-1;
   int hSet = iH;                                                       // das Set-Handle entspricht jeweils dem Index in hs.*[]

   hs.hSet       [iH] = hSet;
   hs.symbol     [iH] = symbol;
   hs.symbolUpper[iH] = symbolUpper;
   hs.description[iH] = description;
   hs.digits     [iH] = digits;
   hs.server     [iH] = server;
   hs.format     [iH] = format;

   return(hSet);
}


/**
 * Gibt ein Handle für das gesamte HistorySet eines Symbols zurück. Wurde das HistorySet vorher nicht mit HistorySet1.Create() erzeugt, muß
 * mindestens ein HistoryFile des Symbols existieren. Noch nicht existierende HistoryFiles werden beim Speichern der ersten hinzugefügten
 * Daten automatisch im alten Datenformat (400) erstellt.
 *
 * - Mehrfachaufrufe dieser Funktion für dasselbe Symbol geben dasselbe Handle zurück.
 * - Die Funktion greift ggf. auf genau eine Historydatei lesend zu. Sie hält keine Dateien offen.
 *
 * @param  string symbol - Symbol
 * @param  string server - Name des Serververzeichnisses, in dem das Set gespeichert wird (default: aktuelles Serververzeichnis)
 *
 * @return int - • Set-Handle oder -1, falls kein HistoryFile dieses Symbols existiert. In diesem Fall muß mit HistorySet1.Create() ein neues
 *                 Set erzeugt werden.
 *               • NULL, falls ein Fehler auftrat.
 */
int HistorySet1.Get(string symbol, string server = "") {
   if (!StringLen(symbol))                    return(!catch("HistorySet1.Get(1)  invalid parameter symbol: "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(!catch("HistorySet1.Get(2)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (max "+ MAX_SYMBOL_LENGTH +" chars)", ERR_INVALID_PARAMETER));
   if (StrContains(symbol, " "))              return(!catch("HistorySet1.Get(3)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (must not contain spaces)", ERR_INVALID_PARAMETER));
   string symbolUpper = StrToUpper(symbol);
   if (server == "0")      server = "";                                 // (string) NULL
   if (!StringLen(server)) server = GetAccountServer();


   // (1) offene Set-Handles durchsuchen
   int size = ArraySize(hs.hSet);
   for (int i=0; i < size; i++) {                                       // Das Handle muß offen sein.
      if (hs.hSet[i] > 0) /*&&*/ if (hs.symbolUpper[i]==symbolUpper) /*&&*/ if (StrCompareI(hs.server[i], server))
         return(hs.hSet[i]);
   }                                                                    // kein offenes Set-Handle gefunden

   int iH, hSet=-1;

   // (2) offene File-Handles durchsuchen
   size = ArraySize(hf.hFile);
   for (i=0; i < size; i++) {                                           // Das Handle muß offen sein.
      if (hf.hFile[i] > 0) /*&&*/ if (hf.symbolUpper[i]==symbolUpper) /*&&*/ if (StrCompareI(hf.server[i], server)) {
         size = Max(ArraySize(hs.hSet), 1) + 1;                         // neues HistorySet erstellen (minSize=2: auf Index[0] kann kein gültiges Handle liegen)
         ResizeSetArrays(size);
         iH   = size-1;
         hSet = iH;                                                     // das Set-Handle entspricht jeweils dem Index in hs.*[]

         hs.hSet       [iH] = hSet;
         hs.symbol     [iH] = hf.symbol     [i];
         hs.symbolUpper[iH] = hf.symbolUpper[i];
         hs.description[iH] = hhs_Description(hf.header, i);
         hs.digits     [iH] = hf.digits     [i];
         hs.server     [iH] = hf.server     [i];
         hs.format     [iH] = 400;                                      // Default für neu zu erstellende HistoryFiles

         return(hSet);
      }
   }                                                                    // kein offenes File-Handle gefunden


   // (3) existierende HistoryFiles suchen
   string mqlHstDir  = "history\\"+ server +"\\";                       // Verzeichnisname für MQL-Dateifunktionen
   string fullHstDir = GetMqlFilesPath() +"\\"+ mqlHstDir;              // Verzeichnisname für Win32-Dateifunktionen

   string baseName="", mqlFileName="", fullFileName="";
   int hFile, fileSize, sizeOfPeriods=ArraySize(periods);

   for (i=0; i < sizeOfPeriods; i++) {
      baseName     = symbol + periods[i] +".hst";
      mqlFileName  = mqlHstDir  + baseName;                             // Dateiname für MQL-Dateifunktionen
      fullFileName = fullHstDir + baseName;                             // Dateiname für Win32-Dateifunktionen

      if (IsFileA(fullFileName)) {                                      // wenn Datei existiert, öffnen
         hFile = FileOpen(mqlFileName, FILE_BIN|FILE_READ);             // FileOpenHistory() kann Unterverzeichnisse nicht handhaben => alle Zugriffe per FileOpen(symlink)
         if (hFile <= 0) return(!catch("HistorySet1.Get(4)  hFile(\""+ mqlFileName +"\") = "+ hFile, ifIntOr(GetLastError(), ERR_RUNTIME_ERROR)));

         fileSize = FileSize(hFile);                                    // Datei geöffnet
         if (fileSize < HISTORY_HEADER_size) {
            FileClose(hFile);
            logWarn("HistorySet1.Get(5)  invalid history file \""+ mqlFileName +"\" found (size="+ fileSize +")");
            continue;
         }
                                                                        // HISTORY_HEADER auslesen
         /*HISTORY_HEADER*/int hh[]; ArrayResize(hh, HISTORY_HEADER_intSize);
         FileReadArray(hFile, hh, 0, HISTORY_HEADER_intSize);
         FileClose(hFile);

         size = Max(ArraySize(hs.hSet), 1) + 1;                         // neues HistorySet erstellen (minSize=2: auf Index[0] kann kein gültiges Handle liegen)
         ResizeSetArrays(size);
         iH   = size-1;
         hSet = iH;                                                     // das Set-Handle entspricht jeweils dem Index in hs.*[]

         hs.hSet       [iH] = hSet;
         hs.symbol     [iH] = hh_Symbol   (hh);
         hs.symbolUpper[iH] = StrToUpper(hs.symbol[iH]);
         hs.description[iH] = hh_Description(hh);
         hs.digits     [iH] = hh_Digits   (hh);
         hs.server     [iH] = server;
         hs.format     [iH] = 400;                                      // Default für neu zu erstellende HistoryFiles

         ArrayResize(hh, 0);
         return(hSet);                                                  // Rückkehr nach der ersten ausgewerteten Datei
      }
   }


   if (!catch("HistorySet1.Get(6)  [hstSet="+ DoubleQuoteStr(symbol) +"]"))
      return(-1);
   return(NULL);
}


/**
 * Schließt das HistorySet mit dem angegebenen Handle.
 *
 * @param  int hSet - Set-Handle
 *
 * @return bool - Erfolgsstatus
 */
bool HistorySet1.Close(int hSet) {
   // Validierung
   if (hSet <= 0)                     return(!catch("HistorySet1.Close(1)  invalid set handle "+ hSet, ERR_INVALID_PARAMETER));
   if (hSet != hs.hSet.lastValid) {
      if (hSet >= ArraySize(hs.hSet)) return(!catch("HistorySet1.Close(2)  invalid set handle "+ hSet, ERR_INVALID_PARAMETER));
      if (hs.hSet[hSet] == 0)         return(!catch("HistorySet1.Close(3)  unknown set handle "+ hSet +" [hstSet="+ DoubleQuoteStr(hs.symbol[hSet]) +"]", ERR_INVALID_PARAMETER));
   }
   else {
      hs.hSet.lastValid = NULL;
   }
   if (hs.hSet[hSet] < 0) return(true);                              // Handle wurde bereits geschlossen (kann ignoriert werden)

   int sizeOfPeriods = ArraySize(periods);

   for (int i=0; i < sizeOfPeriods; i++) {
      if (hs.hFile[hSet][i] > 0) {                                   // alle offenen Dateihandles schließen
         if (!HistoryFile1.Close(hs.hFile[hSet][i])) return(false);
         hs.hFile[hSet][i] = -1;
      }
   }
   hs.hSet[hSet] = -1;
   return(true);
}


/**
 * Fügt dem HistorySet eines Symbols einen Tick hinzu. Der Tick wird als letzter Tick (Close) der entsprechenden Bar gespeichert.
 *
 * @param  int      hSet  - Set-Handle des Symbols
 * @param  datetime time  - Zeitpunkt des Ticks
 * @param  double   value - Datenwert
 * @param  int      flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                          • HST_BUFFER_TICKS: buffert aufeinanderfolgende Ticks und schreibt die Daten erst beim jeweils nächsten
 *                            BarOpen-Event
 *                          • HST_FILL_GAPS:    füllt entstehende Gaps mit dem letzten Schlußkurs vor dem Gap
 *
 * @return bool - Erfolgsstatus
 */
bool HistorySet1.AddTick(int hSet, datetime time, double value, int flags=NULL) {
   // Validierung
   if (hSet <= 0)                     return(!catch("HistorySet1.AddTick(1)  invalid parameter hSet: "+ hSet, ERR_INVALID_PARAMETER));
   if (hSet != hs.hSet.lastValid) {
      if (hSet >= ArraySize(hs.hSet)) return(!catch("HistorySet1.AddTick(2)  invalid parameter hSet: "+ hSet, ERR_INVALID_PARAMETER));
      if (hs.hSet[hSet] == 0)         return(!catch("HistorySet1.AddTick(3)  invalid parameter hSet: "+ hSet +" (unknown handle) [hstSet="+ DoubleQuoteStr(hs.symbol[hSet]) +"]", ERR_INVALID_PARAMETER));
      if (hs.hSet[hSet] <  0)         return(!catch("HistorySet1.AddTick(4)  invalid parameter hSet: "+ hSet +" (closed handle) [hstSet="+ DoubleQuoteStr(hs.symbol[hSet]) +"]", ERR_INVALID_PARAMETER));
      hs.hSet.lastValid = hSet;
   }
   if (time <= 0)                     return(!catch("HistorySet1.AddTick(5)  invalid parameter time: "+ time +" [hstSet="+ DoubleQuoteStr(hs.symbol[hSet]) +"]", ERR_INVALID_PARAMETER));

   // Dateihandles holen und jeweils Tick hinzufügen
   int hFile, sizeOfPeriods=ArraySize(periods);

   for (int i=0; i < sizeOfPeriods; i++) {
      hFile = hs.hFile[hSet][i];
      if (!hFile) {                                                  // noch ungeöffnete Dateien öffnen
         hFile = HistoryFile1.Open(hs.symbol[hSet], periods[i], hs.description[hSet], hs.digits[hSet], hs.format[hSet], FILE_READ|FILE_WRITE, hs.server[hSet]);
         if (!hFile) return(false);
         hs.hFile[hSet][i] = hFile;
      }
      if (!HistoryFile1.AddTick(hFile, time, value, flags)) return(false);
   }
   return(true);
}


/**
 * Öffnet eine Historydatei im angegeben Access-Mode und gibt ihr Handle zurück.
 *
 * • Ist FILE_WRITE angegeben und die Datei existiert nicht, wird sie erstellt.
 * • Ist FILE_WRITE, jedoch nicht FILE_READ angegeben und die Datei existiert, wird sie zurückgesetzt und vorhandene Daten gelöscht.
 *
 * @param  string symbol            - Symbol des Instruments
 * @param  int    timeframe         - Timeframe der Zeitreihe
 * @param  string description       - Copyright oder Beschreibung (falls die Historydatei neu erstellt wird)
 * @param  int    digits            - Digits der Werte            (falls die Historydatei neu erstellt wird)
 * @param  int    format            - Datenformat der Zeitreihe   (falls die Historydatei neu erstellt wird)
 * @param  int    mode              - Access-Mode: FILE_READ|FILE_WRITE
 * @param  string server [optional] - Serververzeichnis, in dem die Datei gespeichert wird (default: aktuelles Serververzeichnis)
 *
 * @return int - Dateihandle oder
 *               -1, falls nur FILE_READ angegeben wurde und die Datei nicht existiert oder
 *               NULL, falls ein anderer Fehler auftrat
 */
int HistoryFile1.Open(string symbol, int timeframe, string description, int digits, int format, int mode, string server = "") {
   if (!StringLen(symbol))                    return(!catch("HistoryFile1.Open(1)  invalid parameter symbol: "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(!catch("HistoryFile1.Open(2)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (max. "+ MAX_SYMBOL_LENGTH +" chars)", ERR_INVALID_PARAMETER));
   if (StrContains(symbol, " "))              return(!catch("HistoryFile1.Open(3)  invalid parameter symbol: "+ DoubleQuoteStr(symbol) +" (must not contain spaces)", ERR_INVALID_PARAMETER));
   string symbolUpper = StrToUpper(symbol);
   if (timeframe <= 0)                        return(!catch("HistoryFile1.Open(4)  invalid parameter timeframe: "+ timeframe +" ("+ symbol +")", ERR_INVALID_PARAMETER));
   if (!(mode & (FILE_READ|FILE_WRITE)))      return(!catch("HistoryFile1.Open(5)  invalid parameter mode: "+ mode +" (must be FILE_READ and/or FILE_WRITE) ("+ symbol +","+ PeriodDescription(timeframe) +")", ERR_INVALID_PARAMETER));
   mode &= (FILE_READ|FILE_WRITE);                                                  // alle anderen Bits löschen
   bool read_only  = !(mode & FILE_WRITE);
   bool write_only = !(mode & FILE_READ);
   bool read_write =  (mode & FILE_READ) && (mode & FILE_WRITE);

   if (server == "0")      server = "";                                             // (string) NULL
   if (!StringLen(server)) server = GetAccountServer();

   // (1) Datei öffnen
   string mqlHstDir   = server +"/";                                                // Verzeichnis für MQL-Dateifunktionen
   string fullHstDir  = GetMqlFilesPath() +"/"+ mqlHstDir;                          // Verzeichnis für Win32-Dateifunktionen
   string baseName    = symbol + timeframe +".hst";
   string mqlFileName = mqlHstDir  + baseName;
   // on write access make sure the directory exists
   if (!read_only) /*&&*/ if (!CreateDirectory(fullHstDir, MODE_OS|MODE_MKPARENT)) return(!catch("HistoryFile1.Open(6)  cannot create directory "+ DoubleQuoteStr(fullHstDir) +" ("+ symbol +","+ PeriodDescription(timeframe) +")", ERR_RUNTIME_ERROR));

   // (1.1) read-only                                                               // Bei read-only kann die Existenz nicht mit FileOpen() geprüft werden, da die
   int hFile;
   if (read_only) {                                                                 // Funktion das Log bei fehlender Datei mit Warnungen ERR_CANNOT_OPEN_FILE zumüllt.
      if (!MQL.IsFile(mqlFileName)) return(-1);                                     // file not found
      hFile = FileOpen(mqlFileName, mode|FILE_BIN);
      if (hFile <= 0) return(!catch("HistoryFile1.Open(7)->FileOpen(\""+ mqlFileName +"\") => "+ hFile +" ("+ symbol +","+ PeriodDescription(timeframe) +")", ifIntOr(GetLastError(), ERR_RUNTIME_ERROR)));
   }

   // (1.2) read-write
   else if (read_write) {
      hFile = FileOpen(mqlFileName, mode|FILE_BIN);
      if (hFile <= 0) return(!catch("HistoryFile1.Open(8)->FileOpen(\""+ mqlFileName +"\") => "+ hFile +" ("+ symbol +","+ PeriodDescription(timeframe) +")", ifIntOr(GetLastError(), ERR_RUNTIME_ERROR)));
   }

   // (1.3) write-only
   else if (write_only) {
      hFile = FileOpen(mqlFileName, mode|FILE_BIN);
      if (hFile <= 0) return(!catch("HistoryFile1.Open(9)->FileOpen(\""+ mqlFileName +"\") => "+ hFile +" ("+ symbol +","+ PeriodDescription(timeframe) +")", ifIntOr(GetLastError(), ERR_RUNTIME_ERROR)));
   }

   /*HISTORY_HEADER*/int hh[]; InitializeByteBuffer(hh, HISTORY_HEADER_size);
   int      bars=0, from.offset=-1, to.offset=-1, fileSize=FileSize(hFile), periodSecs=timeframe * MINUTES;
   datetime from.openTime=0, from.closeTime=0, from.nextCloseTime=0, to.openTime=0, to.closeTime=0, to.nextCloseTime=0;

   // (2) ggf. neuen HISTORY_HEADER schreiben
   if (write_only || (read_write && fileSize < HISTORY_HEADER_size)) {
      // Parameter validieren
      if (!StringLen(description))     description = "";                            // NULL-Pointer => Leerstring
      if (StringLen(description) > 63) description = StrLeft(description, 63);      // ein zu langer String wird gekürzt
      if (digits < 0)                          return(!catch("HistoryFile1.Open(10)  invalid parameter digits: "+ digits +" ("+ symbol +","+ PeriodDescription(timeframe) +")", ERR_INVALID_PARAMETER));
      if (format!=400) /*&&*/ if (format!=401) return(!catch("HistoryFile1.Open(11)  invalid parameter format: "+ format +" (must be 400 or 401, symbol="+ symbol +","+ PeriodDescription(timeframe) +")", ERR_INVALID_PARAMETER));

      hh_SetBarFormat  (hh, format     );
      hh_SetDescription(hh, description);
      hh_SetSymbol     (hh, symbol     );
      hh_SetPeriod     (hh, timeframe  );
      hh_SetDigits     (hh, digits     );
      FileWriteArray(hFile, hh, 0, HISTORY_HEADER_intSize);
   }

   // (3.1) ggf. vorhandenen HISTORY_HEADER auslesen
   else if (read_only || fileSize > 0) {
      if (FileReadArray(hFile, hh, 0, HISTORY_HEADER_intSize) != HISTORY_HEADER_intSize) {
         FileClose(hFile);
         return(!catch("HistoryFile1.Open(12)  invalid history file \""+ mqlFileName +"\" (size="+ fileSize +", symbol="+ symbol +","+ PeriodDescription(timeframe) +")", ifIntOr(GetLastError(), ERR_RUNTIME_ERROR)));
      }

      // (3.2) ggf. Bar-Statistik auslesen
      if (fileSize > HISTORY_HEADER_size) {
         int barSize = ifInt(hh_BarFormat(hh)==400, HISTORY_BAR_400_size, HISTORY_BAR_401_size);
         bars        = (fileSize-HISTORY_HEADER_size) / barSize;
         if (bars > 0) {
            from.offset   = 0;
            from.openTime = FileReadInteger(hFile);
            to.offset     = bars-1; FileSeek(hFile, HISTORY_HEADER_size + to.offset*barSize, SEEK_SET);
            to.openTime   = FileReadInteger(hFile);

            if (timeframe <= PERIOD_W1) {
               from.closeTime     = from.openTime  + periodSecs;
               from.nextCloseTime = from.closeTime + periodSecs;
               to.closeTime       = to.openTime    + periodSecs;
               to.nextCloseTime   = to.closeTime   + periodSecs;
            }
            else if (timeframe == PERIOD_MN1) {
               from.closeTime     = DateTime(TimeYearEx(from.openTime), TimeMonth(from.openTime)+1);     // 00:00, 1. des nächsten Monats
               from.nextCloseTime = DateTime(TimeYearEx(from.openTime), TimeMonth(from.openTime)+2);     // 00:00, 1. des übernächsten Monats
               to.closeTime       = DateTime(TimeYearEx(to.openTime  ), TimeMonth(to.openTime  )+1);     // 00:00, 1. des nächsten Monats
               to.nextCloseTime   = DateTime(TimeYearEx(to.openTime  ), TimeMonth(to.openTime  )+2);     // 00:00, 1. des übernächsten Monats
            }
         }
      }
   }

   // (4) Daten zwischenspeichern
   if (hFile >= ArraySize(hf.hFile))                                 // neues Datei-Handle: Arrays vergrößer
      ResizeFileArrays(hFile+1);                                     // andererseits von FileOpen() wiederverwendetes Handle

   hf.hFile                      [hFile]        = hFile;
   hf.name                       [hFile]        = baseName;
   hf.readAccess                 [hFile]        = !write_only;
   hf.writeAccess                [hFile]        = !read_only;

   ArraySetInts(hf.header,        hFile,          hh);               // entspricht: hf.header[hFile] = hh;
   hf.format                     [hFile]        = hh_BarFormat(hh);
   hf.barSize                    [hFile]        = ifInt(hf.format[hFile]==400, HISTORY_BAR_400_size, HISTORY_BAR_401_size);
   hf.symbol                     [hFile]        = hh_Symbol(hh);
   hf.symbolUpper                [hFile]        = symbolUpper;
   hf.period                     [hFile]        = timeframe;
   hf.periodSecs                 [hFile]        = periodSecs;
   hf.digits                     [hFile]        = hh_Digits(hh);
   hf.server                     [hFile]        = server;

   hf.stored.bars                [hFile]        = bars;                 // bei leerer History: 0
   hf.stored.from.offset         [hFile]        = from.offset;          // ...                -1
   hf.stored.from.openTime       [hFile]        = from.openTime;        // ...                 0
   hf.stored.from.closeTime      [hFile]        = from.closeTime;       // ...                 0
   hf.stored.from.nextCloseTime  [hFile]        = from.nextCloseTime;   // ...                 0
   hf.stored.to.offset           [hFile]        = to.offset;            // ...                -1
   hf.stored.to.openTime         [hFile]        = to.openTime;          // ...                 0
   hf.stored.to.closeTime        [hFile]        = to.closeTime;         // ...                 0
   hf.stored.to.nextCloseTime    [hFile]        = to.nextCloseTime;     // ...                 0

   hf.full.bars                  [hFile]        = hf.stored.bars              [hFile];
   hf.full.from.offset           [hFile]        = hf.stored.from.offset       [hFile];
   hf.full.from.openTime         [hFile]        = hf.stored.from.openTime     [hFile];
   hf.full.from.closeTime        [hFile]        = hf.stored.from.closeTime    [hFile];
   hf.full.from.nextCloseTime    [hFile]        = hf.stored.from.nextCloseTime[hFile];
   hf.full.to.offset             [hFile]        = hf.stored.to.offset         [hFile];
   hf.full.to.openTime           [hFile]        = hf.stored.to.openTime       [hFile];
   hf.full.to.closeTime          [hFile]        = hf.stored.to.closeTime      [hFile];
   hf.full.to.nextCloseTime      [hFile]        = hf.stored.to.nextCloseTime  [hFile];

   hf.lastStoredBar.offset       [hFile]        = -1;                   // vorhandene Bardaten zurücksetzen: wichtig, da MQL die ID eines vorher geschlossenen Dateihandles
   hf.lastStoredBar.openTime     [hFile]        =  0;                   //                                   wiederverwenden kann
   hf.lastStoredBar.closeTime    [hFile]        =  0;
   hf.lastStoredBar.nextCloseTime[hFile]        =  0;
   hf.lastStoredBar.data         [hFile][BAR_T] =  0;
   hf.lastStoredBar.data         [hFile][BAR_O] =  0;
   hf.lastStoredBar.data         [hFile][BAR_H] =  0;
   hf.lastStoredBar.data         [hFile][BAR_L] =  0;
   hf.lastStoredBar.data         [hFile][BAR_C] =  0;
   hf.lastStoredBar.data         [hFile][BAR_V] =  0;

   hf.bufferedBar.offset         [hFile]        = -1;
   hf.bufferedBar.openTime       [hFile]        =  0;
   hf.bufferedBar.closeTime      [hFile]        =  0;
   hf.bufferedBar.nextCloseTime  [hFile]        =  0;
   hf.bufferedBar.data           [hFile][BAR_T] =  0;
   hf.bufferedBar.data           [hFile][BAR_O] =  0;
   hf.bufferedBar.data           [hFile][BAR_H] =  0;
   hf.bufferedBar.data           [hFile][BAR_L] =  0;
   hf.bufferedBar.data           [hFile][BAR_C] =  0;
   hf.bufferedBar.data           [hFile][BAR_V] =  0;
   hf.bufferedBar.modified       [hFile]        = false;

   ArrayResize(hh, 0);

   int error = GetLastError();
   if (!error)
      return(hFile);
   return(!catch("HistoryFile1.Open(13)  "+ symbol +","+ PeriodDescription(timeframe), error));
}


/**
 * Schließt die Historydatei mit dem angegebenen Handle. Ungespeicherte Daten im Schreibpuffer werden geschrieben.
 * Die Datei muß vorher mit HistoryFile1.Open() geöffnet worden sein.
 *
 * @param  int hFile - Dateihandle
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile1.Close(int hFile) {
   if (hFile <= 0)                      return(!catch("HistoryFile1.Close(1)  invalid file handle: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile1.Close(2)  unknown file handle: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile1.Close(3)  unknown file handle: "+ hFile +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   }
   else hf.hFile.lastValid = NULL;

   if (hf.hFile[hFile] < 0) return(true);                            // Handle wurde bereits geschlossen (kann ignoriert werden)


   // (1) alle ungespeicherten Daten speichern
   if (hf.bufferedBar.offset[hFile] != -1) if (!HistoryFile1.WriteBufferedBar(hFile)) return(false);
   hf.bufferedBar.offset  [hFile] = -1;                              // BufferedBar sicherheitshalber zurücksetzen
   hf.lastStoredBar.offset[hFile] = -1;                              // LastStoredBar sicherheitshalber zurücksetzen


   // (2) Datei schließen
   int error = GetLastError();                                       // vor FileClose() alle Fehler abfangen
   if (IsError(error)) return(!catch("HistoryFile1.Close(4)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]), error));

   hf.hFile[hFile] = -1;                                             // Handle vorm Schließen zurücksetzen
   FileClose(hFile);

   error = GetLastError();
   if (!error)                         return(true);
   if (error == ERR_INVALID_PARAMETER) return(true);                 // Datei wurde bereits geschlossen (kann ignoriert werden)
   return(!catch("HistoryFile1.Close(5)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]), error));
}


/**
 * Findet den Offset der Bar, die den angegebenen Zeitpunkt abdeckt oder abdecken würde, und signalisiert, ob diese Bar bereits existiert.
 * Die Bar existiert z.B. nicht, wenn die Zeitreihe am angegebenen Zeitpunkt eine Lücke aufweist (am zurückgegebenen Offset befindet sich
 * eine andere Bar) oder wenn der Zeitpunkt außerhalb des von den vorhandenen Daten abgedeckten Bereichs liegt.
 *
 * @param  _In_  int      hFile          - Handle der Historydatei
 * @param  _In_  datetime time           - Zeitpunkt
 * @param  _Out_ bool     lpBarExists[1] - Variable, die nach Rückkehr anzeigt, ob die Bar am zurückgegebenen Offset existiert
 *                                         (als Array implementiert, um Zeigerübergabe an eine Library zu ermöglichen)
 *                                         • TRUE:  Bar existiert          @see  HistoryFile1.UpdateBar() und HistoryFile1.WriteBar()
 *                                         • FALSE: Bar existiert nicht    @see  HistoryFile1.InsertBar()
 *
 * @return int - Bar-Offset relativ zum Dateiheader (Offset 0 ist die älteste Bar) oder EMPTY (-1), falls ein Fehler auftrat
 */
int HistoryFile1.FindBar(int hFile, datetime time, bool &lpBarExists[]) {
   // NOTE: Der Parameter lpBarExists ist für den externen Gebrauch implementiert (Aufruf der Funktion von außerhalb der Library). Beim internen Gebrauch
   //       läßt sich über die Metadaten der Historydatei einfacher herausfinden, ob eine Bar an einem Offset existiert oder nicht.
   //       @see  int hf.full.bars[]
   if (hFile <= 0)                      return(_EMPTY(catch("HistoryFile1.FindBar(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_EMPTY(catch("HistoryFile1.FindBar(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] == 0)         return(_EMPTY(catch("HistoryFile1.FindBar(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <  0)         return(_EMPTY(catch("HistoryFile1.FindBar(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER)));
      hf.hFile.lastValid = hFile;
   }
   if (time <= 0)                       return(_EMPTY(catch("HistoryFile1.FindBar(5)  invalid parameter time: "+ time +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER)));
   if (ArraySize(lpBarExists) == 0)
      ArrayResize(lpBarExists, 1);

   // History leer?
   if (!hf.full.bars[hFile]) {
      lpBarExists[0] = false;
      return(0);
   }

   datetime openTime = time;
   int      offset;

   // alle bekannten Daten abprüfen
   if (hf.stored.bars[hFile] > 0) {
      // hf.stored.from
      if (openTime < hf.stored.from.openTime     [hFile]) { lpBarExists[0] = false;                     return(0); }    // Zeitpunkt liegt zeitlich vor der ersten Bar
      if (openTime < hf.stored.from.closeTime    [hFile]) { lpBarExists[0] = true;                      return(0); }    // Zeitpunkt liegt in der ersten Bar
      if (openTime < hf.stored.from.nextCloseTime[hFile]) { lpBarExists[0] = (hf.full.bars[hFile] > 1); return(1); }    // Zeitpunkt liegt in der zweiten Bar

      // hf.stored.to
      if      (openTime < hf.stored.to.openTime     [hFile]) {}
      else if (openTime < hf.stored.to.closeTime    [hFile]) { lpBarExists[0] = true;                                          return(hf.stored.to.offset[hFile]); }    // Zeitpunkt liegt in der letzten gespeicherten Bar
      else if (openTime < hf.stored.to.nextCloseTime[hFile]) { lpBarExists[0] = (hf.full.bars[hFile] > hf.stored.bars[hFile]); return(hf.stored.bars     [hFile]); }    // Zeitpunkt liegt in der darauf folgenden Bar
      else                                                   { lpBarExists[0] = false;                                         return(hf.full.bars       [hFile]); }    // Zeitpunkt liegt in der ersten neuen Bar

      // hf.lastStoredBar
      if (hf.lastStoredBar.offset[hFile] > 0) {                         // LastStoredBar ist definiert und entspricht nicht hf.stored.from (schon geprüft)
         if (hf.lastStoredBar.offset[hFile] != hf.stored.to.offset[hFile]) {
            if      (openTime < hf.lastStoredBar.openTime     [hFile]) {}
            else if (openTime < hf.lastStoredBar.closeTime    [hFile]) { lpBarExists[0] = true;                                 return(hf.lastStoredBar.offset[hFile]); }   // Zeitpunkt liegt in LastStoredBar
            else if (openTime < hf.lastStoredBar.nextCloseTime[hFile]) { offset         = hf.lastStoredBar.offset[hFile] + 1;
                                                                         lpBarExists[0] = (hf.full.to.offset[hFile] >= offset); return(offset); }                           // Zeitpunkt liegt in der darauf folgenden Bar
            else                                                       { offset = hf.lastStoredBar.offset[hFile] + 1 + (hf.full.to.offset[hFile] > hf.lastStoredBar.offset[hFile]);
                                                                         lpBarExists[0] = (hf.full.to.offset[hFile] >= offset); return(offset); }                           // Zeitpunkt liegt in der ersten neuen Bar
         }
      }
   }

   if (hf.bufferedBar.offset[hFile] >= 0) {                             // BufferedBar ist definiert
      // hf.full.from
      if (hf.full.from.offset[hFile] != hf.stored.from.offset[hFile]) { // bei Gleichheit identisch zu hf.stored.from (schon geprüft)
         if (openTime < hf.full.from.openTime     [hFile]) { lpBarExists[0] = false;                     return(0); }                           // Zeitpunkt liegt zeitlich vor der ersten Bar
         if (openTime < hf.full.from.closeTime    [hFile]) { lpBarExists[0] = true;                      return(0); }                           // Zeitpunkt liegt in der ersten Bar
         if (openTime < hf.full.from.nextCloseTime[hFile]) { lpBarExists[0] = (hf.full.bars[hFile] > 1); return(1); }                           // Zeitpunkt liegt in der zweiten Bar
      }

      // hf.full.to
      if (hf.full.to.offset[hFile] != hf.stored.to.offset[hFile]) {     // bei Gleichheit identisch zu hf.stored.to (schon geprüft)
         if      (openTime < hf.full.to.openTime [hFile]) {}
         else if (openTime < hf.full.to.closeTime[hFile]) { lpBarExists[0] = true;                       return(hf.full.to.offset[hFile]); }    // Zeitpunkt liegt in der letzten absoluten Bar
         else                                             { lpBarExists[0] = false;                      return(hf.full.bars     [hFile]); }    // Zeitpunkt liegt in der ersten neuen Bar
      }

      // hf.bufferedBar                                                 // eine definierte BufferedBar ist immer identisch zu hf.full.to (schon geprüft)
   }

   // binäre Suche in der Datei                                         // TODO: implementieren
   return(_EMPTY(catch("HistoryFile1.FindBar(6)  bars="+ hf.full.bars[hFile] +", from='"+ TimeToStr(hf.full.from.openTime[hFile], TIME_FULL) +"', to='"+ TimeToStr(hf.full.to.openTime[hFile], TIME_FULL) +"')  time look-up in a timeseries not yet implemented ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_NOT_IMPLEMENTED)));
}


/**
 * Liest die Bar am angegebenen Offset einer Historydatei.
 *
 * @param  _In_  int    hFile  - Handle der Historydatei
 * @param  _In_  int    offset - Offset der zu lesenden Bar relativ zum Dateiheader (Offset 0 ist die älteste Bar)
 * @param  _Out_ double bar[6] - Array zur Aufnahme der Bar-Daten (TOHLCV)
 *
 * @return bool - Erfolgsstatus
 *
 * NOTE: Time und Volume der gelesenen Bar werden validert, nicht jedoch die Barform.
 */
bool HistoryFile1.ReadBar(int hFile, int offset, double &bar[]) {
   if (hFile <= 0)                      return(!catch("HistoryFile1.ReadBar(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile1.ReadBar(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile1.ReadBar(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile1.ReadBar(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (offset < 0)                      return(!catch("HistoryFile1.ReadBar(5)  invalid parameter offset: "+ offset +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (offset >= hf.full.bars[hFile])   return(!catch("HistoryFile1.ReadBar(6)  invalid parameter offset: "+ offset +" ("+ hf.full.bars[hFile] +" full bars, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (ArraySize(bar) != 6) ArrayResize(bar, 6);

   // vorzugsweise bereits bekannte Bars zurückgeben                 // ACHTUNG: hf.lastStoredBar wird nur aktualisiert, wenn die Bar tatsächlich neu gelesen wurde.
   if (offset == hf.lastStoredBar.offset[hFile]) {
      bar[BAR_T] = hf.lastStoredBar.data[hFile][BAR_T];
      bar[BAR_O] = hf.lastStoredBar.data[hFile][BAR_O];
      bar[BAR_H] = hf.lastStoredBar.data[hFile][BAR_H];
      bar[BAR_L] = hf.lastStoredBar.data[hFile][BAR_L];
      bar[BAR_C] = hf.lastStoredBar.data[hFile][BAR_C];
      bar[BAR_V] = hf.lastStoredBar.data[hFile][BAR_V];
      return(true);
   }
   if (offset == hf.bufferedBar.offset[hFile]) {
      bar[BAR_T] = hf.bufferedBar.data[hFile][BAR_T];
      bar[BAR_O] = hf.bufferedBar.data[hFile][BAR_O];
      bar[BAR_H] = hf.bufferedBar.data[hFile][BAR_H];
      bar[BAR_L] = hf.bufferedBar.data[hFile][BAR_L];
      bar[BAR_C] = hf.bufferedBar.data[hFile][BAR_C];
      bar[BAR_V] = hf.bufferedBar.data[hFile][BAR_V];
      return(true);
   }

   // FilePointer positionieren, Bar lesen, normalisieren und validieren
   int position = HISTORY_HEADER_size + offset*hf.barSize[hFile], digits=hf.digits[hFile];
   if (!FileSeek(hFile, position, SEEK_SET)) return(!catch("HistoryFile1.ReadBar(7)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile])));

   if (hf.format[hFile] == 400) {
      bar[BAR_T] =                 FileReadInteger(hFile);
      bar[BAR_O] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_L] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_H] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_C] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_V] =           Round(FileReadDouble (hFile));
   }
   else {               // 401
      bar[BAR_T] =                 FileReadInteger(hFile);           // int64
                                   FileReadInteger(hFile);
      bar[BAR_O] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_H] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_L] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_C] = NormalizeDouble(FileReadDouble (hFile), digits);
      bar[BAR_V] =                 FileReadInteger(hFile);           // uint64: ticks
   }
   datetime openTime = bar[BAR_T]; if (!openTime) return(!catch("HistoryFile1.ReadBar(8)  invalid bar["+ offset +"].time: "+ openTime +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_RUNTIME_ERROR));
   int      V        = bar[BAR_V]; if (!V)        return(!catch("HistoryFile1.ReadBar(9)  invalid bar["+ offset +"].volume: "+ V +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_RUNTIME_ERROR));

   // CloseTime/NextCloseTime ermitteln und hf.lastStoredBar aktualisieren
   datetime closeTime, nextCloseTime;
   if (hf.period[hFile] <= PERIOD_W1) {
      closeTime     = openTime  + hf.periodSecs[hFile];
      nextCloseTime = closeTime + hf.periodSecs[hFile];
   }
   else if (hf.period[hFile] == PERIOD_MN1) {
      closeTime     = DateTime(TimeYearEx(openTime), TimeMonth(openTime)+1);     // 00:00, 1. des nächsten Monats
      nextCloseTime = DateTime(TimeYearEx(openTime), TimeMonth(openTime)+2);     // 00:00, 1. des übernächsten Monats
   }

   hf.lastStoredBar.offset       [hFile]        = offset;
   hf.lastStoredBar.openTime     [hFile]        = openTime;
   hf.lastStoredBar.closeTime    [hFile]        = closeTime;
   hf.lastStoredBar.nextCloseTime[hFile]        = nextCloseTime;
   hf.lastStoredBar.data         [hFile][BAR_T] = bar[BAR_T];
   hf.lastStoredBar.data         [hFile][BAR_O] = bar[BAR_O];
   hf.lastStoredBar.data         [hFile][BAR_H] = bar[BAR_H];
   hf.lastStoredBar.data         [hFile][BAR_L] = bar[BAR_L];
   hf.lastStoredBar.data         [hFile][BAR_C] = bar[BAR_C];
   hf.lastStoredBar.data         [hFile][BAR_V] = bar[BAR_V];

   int error = GetLastError();
   if (!error)
      return(true);
   return(!catch("HistoryFile1.ReadBar(10)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]), error));
}


/**
 * Schreibt eine Bar am angegebenen Offset einer Historydatei. Eine dort vorhandene Bar wird überschrieben. Ist die Bar noch nicht vorhanden,
 * muß ihr Offset an die vorhandenen Bars genau anschließen. Sie darf kein physisches Gap verursachen.
 *
 * @param  int    hFile  - Handle der Historydatei
 * @param  int    offset - Offset der zu schreibenden Bar relativ zum Dateiheader (Offset 0 ist die älteste Bar)
 * @param  double bar[]  - Bardaten (T-OHLCV):
 * @param  int    flags  - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                         • HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
 *
 * @return bool - Erfolgsstatus
 *
 * NOTE: Time und Volume der zu schreibenden Bar werden auf != NULL validert, alles andere nicht. Insbesondere wird nicht überprüft, ob die
 *       Bar-Time eine normalisierte OpenTime für den Timeframe der Historydatei ist.
 */
bool HistoryFile1.WriteBar(int hFile, int offset, double bar[], int flags=NULL) {
   if (hFile <= 0)                      return(!catch("HistoryFile1.WriteBar(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile1.WriteBar(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile1.WriteBar(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile1.WriteBar(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (offset < 0)                      return(!catch("HistoryFile1.WriteBar(5)  invalid parameter offset: "+ offset +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (offset > hf.full.bars[hFile])    return(!catch("HistoryFile1.WriteBar(6)  invalid parameter offset: "+ offset +" ("+ hf.full.bars[hFile] +" full bars, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (ArraySize(bar) != 6)             return(!catch("HistoryFile1.WriteBar(7)  invalid size of parameter bar[]: "+ ArraySize(bar) +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INCOMPATIBLE_ARRAYS));

   // Bar validieren
   datetime openTime = Round(bar[BAR_T]); if (!openTime) return(!catch("HistoryFile1.WriteBar(8)  invalid bar["+ offset +"].time: "+ openTime +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   int      V        = Round(bar[BAR_V]); if (!V)        return(!catch("HistoryFile1.WriteBar(9)  invalid bar["+ offset +"].volume: "+ V +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));

   // Sicherstellen, daß bekannte Bars nicht mit einer anderen Bar überschrieben werden               // TODO: if-Tests reduzieren
   if (offset==hf.stored.from.offset  [hFile]) /*&&*/ if (openTime!=hf.stored.from.openTime  [hFile]) return(!catch("HistoryFile1.WriteBar(10)  bar["+ offset +"].time="+ TimeToStr(openTime, TIME_FULL) +" collides with hf.stored.from.time="                                        + TimeToStr(hf.stored.from.openTime  [hFile], TIME_FULL) +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_ILLEGAL_STATE));
   if (offset==hf.stored.to.offset    [hFile]) /*&&*/ if (openTime!=hf.stored.to.openTime    [hFile]) return(!catch("HistoryFile1.WriteBar(11)  bar["+ offset +"].time="+ TimeToStr(openTime, TIME_FULL) +" collides with hf.stored.to.time="                                          + TimeToStr(hf.stored.to.openTime    [hFile], TIME_FULL) +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_ILLEGAL_STATE));
   if (offset==hf.full.to.offset      [hFile]) /*&&*/ if (openTime!=hf.full.to.openTime      [hFile]) return(!catch("HistoryFile1.WriteBar(12)  bar["+ offset +"].time="+ TimeToStr(openTime, TIME_FULL) +" collides with hf.full.to.time="                                            + TimeToStr(hf.full.to.openTime      [hFile], TIME_FULL) +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_ILLEGAL_STATE));
   if (offset==hf.lastStoredBar.offset[hFile]) /*&&*/ if (openTime!=hf.lastStoredBar.openTime[hFile]) return(!catch("HistoryFile1.WriteBar(13)  bar["+ offset +"].time="+ TimeToStr(openTime, TIME_FULL) +" collides with hf.lastStoredBar["+ hf.lastStoredBar.offset[hFile] +"].time="+ TimeToStr(hf.lastStoredBar.openTime[hFile], TIME_FULL) +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_ILLEGAL_STATE));
   // hf.bufferedBar.offset: entspricht hf.full.to.offset (schon geprüft)

   // TODO: Sicherstellen, daß nach bekannten Bars keine älteren Bars geschrieben werden              // TODO: if-Tests reduzieren
   if (offset==hf.stored.from.offset  [hFile]+1) {}
   if (offset==hf.stored.to.offset    [hFile]+1) {}
   if (offset==hf.full.to.offset      [hFile]+1) {}
   if (offset==hf.lastStoredBar.offset[hFile]+1) {}

   // Löst die Bar für eine BufferedBar ein BarClose-Event aus, zuerst die BufferedBar schreiben
   if (hf.bufferedBar.offset[hFile] >= 0) /*&&*/ if (offset > hf.bufferedBar.offset[hFile]) {
      if (!HistoryFile1.WriteBufferedBar(hFile, flags)) return(false);
      hf.bufferedBar.offset[hFile] = -1;                                                              // BufferedBar zurücksetzen
   }

   // FilePointer positionieren, Bar normalisieren (Funktionsparameter nicht modifizieren) und schreiben
   int position = HISTORY_HEADER_size + offset*hf.barSize[hFile], digits=hf.digits[hFile];
   if (!FileSeek(hFile, position, SEEK_SET)) return(!catch("HistoryFile1.WriteBar(14)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile])));

   double O = NormalizeDouble(bar[BAR_O], digits);
   double H = NormalizeDouble(bar[BAR_H], digits);
   double L = NormalizeDouble(bar[BAR_L], digits);
   double C = NormalizeDouble(bar[BAR_C], digits);

   if (hf.format[hFile] == 400) {
      FileWriteInteger(hFile, openTime);
      FileWriteDouble (hFile, O       );
      FileWriteDouble (hFile, L       );
      FileWriteDouble (hFile, H       );
      FileWriteDouble (hFile, C       );
      FileWriteDouble (hFile, V       );
   }
   else {               // 401
      FileWriteInteger(hFile, openTime);     // int64
      FileWriteInteger(hFile, 0       );
      FileWriteDouble (hFile, O       );
      FileWriteDouble (hFile, H       );
      FileWriteDouble (hFile, L       );
      FileWriteDouble (hFile, C       );
      FileWriteInteger(hFile, V       );     // uint64: ticks
      FileWriteInteger(hFile, 0       );
      FileWriteInteger(hFile, 0       );     // int:    spread
      FileWriteInteger(hFile, 0       );     // uint64: real_volume
      FileWriteInteger(hFile, 0       );
   }
   FileFlush(hFile);                         // doesn't update last-modified timestamp even if the file size changes

   datetime closeTime=hf.lastStoredBar.closeTime[hFile], nextCloseTime=hf.lastStoredBar.nextCloseTime[hFile];

   // hf.lastStoredBar aktualisieren
   if (offset != hf.lastStoredBar.offset[hFile]) {
      if (hf.period[hFile] <= PERIOD_W1) {
         closeTime     = openTime  + hf.periodSecs[hFile];
         nextCloseTime = closeTime + hf.periodSecs[hFile];
      }
      else if (hf.period[hFile] == PERIOD_MN1) {
         closeTime     = DateTime(TimeYearEx(openTime), TimeMonth(openTime)+1);  // 00:00, 1. des nächsten Monats
         nextCloseTime = DateTime(TimeYearEx(openTime), TimeMonth(openTime)+2);  // 00:00, 1. des übernächsten Monats
      }
      hf.lastStoredBar.offset       [hFile] = offset;
      hf.lastStoredBar.openTime     [hFile] = openTime;
      hf.lastStoredBar.closeTime    [hFile] = closeTime;
      hf.lastStoredBar.nextCloseTime[hFile] = nextCloseTime;
   }
   hf.lastStoredBar.data[hFile][BAR_T] = openTime;
   hf.lastStoredBar.data[hFile][BAR_O] = O;
   hf.lastStoredBar.data[hFile][BAR_H] = H;
   hf.lastStoredBar.data[hFile][BAR_L] = L;
   hf.lastStoredBar.data[hFile][BAR_C] = C;
   hf.lastStoredBar.data[hFile][BAR_V] = V;

   // Metadaten aktualisieren: - Die Bar kann (a) erste Bar einer leeren History sein, (b) mittendrin liegen oder (c) neue Bar am Ende sein.
   //                          - Die Bar kann auf einer ungespeicherten BufferedBar liegen, jedoch nicht jünger als diese sein: siehe (3).
   //                          - Die Bar kann zwischen der letzten gespeicherten Bar und einer ungespeicherten BufferedBar liegen. Dazu muß sie
   //                            mit HistoryFile1.InsertBar() eingefügt worden sein, das die entsprechende Lücke zwischen beiden Bars einrichtet.
   //                            Ohne diese Lücke wurde oben bereits abgebrochen.
   //
   // Bar ist neue Bar: (a) erste Bar leerer History oder (c) neue Bar am Ende der gespeicherten Bars
   if (offset >= hf.stored.bars[hFile]) {
                         hf.stored.bars              [hFile] = offset + 1;

      if (offset == 0) { hf.stored.from.offset       [hFile] = 0;                hf.full.from.offset       [hFile] = hf.stored.from.offset       [hFile];
                         hf.stored.from.openTime     [hFile] = openTime;         hf.full.from.openTime     [hFile] = hf.stored.from.openTime     [hFile];
                         hf.stored.from.closeTime    [hFile] = closeTime;        hf.full.from.closeTime    [hFile] = hf.stored.from.closeTime    [hFile];
                         hf.stored.from.nextCloseTime[hFile] = nextCloseTime;    hf.full.from.nextCloseTime[hFile] = hf.stored.from.nextCloseTime[hFile]; }
                                                                                 //                ^               ^               ^
                         hf.stored.to.offset         [hFile] = offset;           // Wird die Bar wie in (6.3) eingefügt, wurde der Offset der BufferedBar um eins
                         hf.stored.to.openTime       [hFile] = openTime;         // vergrößert. Ist die History noch leer und die BufferedBar war die erste Bar, steht
                         hf.stored.to.closeTime      [hFile] = closeTime;        // hf.full.from bis zu dieser Zuweisung *über mir* auf 0 (Zeiten unbekannt, da die
                         hf.stored.to.nextCloseTime  [hFile] = nextCloseTime;    // neue Startbar gerade eingefügt wird).
   }
   if (hf.stored.bars[hFile] > hf.full.bars[hFile]) {
      hf.full.bars            [hFile] = hf.stored.bars            [hFile];

      hf.full.to.offset       [hFile] = hf.stored.to.offset       [hFile];
      hf.full.to.openTime     [hFile] = hf.stored.to.openTime     [hFile];
      hf.full.to.closeTime    [hFile] = hf.stored.to.closeTime    [hFile];
      hf.full.to.nextCloseTime[hFile] = hf.stored.to.nextCloseTime[hFile];
   }

   // Ist die geschriebene Bar gleichzeitig die BufferedBar, wird deren veränderlicher Status aktualisiert.
   if (offset == hf.bufferedBar.offset[hFile]) {
      hf.bufferedBar.data    [hFile][BAR_O] = hf.lastStoredBar.data[hFile][BAR_O];
      hf.bufferedBar.data    [hFile][BAR_H] = hf.lastStoredBar.data[hFile][BAR_H];
      hf.bufferedBar.data    [hFile][BAR_L] = hf.lastStoredBar.data[hFile][BAR_L];
      hf.bufferedBar.data    [hFile][BAR_C] = hf.lastStoredBar.data[hFile][BAR_C];
      hf.bufferedBar.data    [hFile][BAR_V] = hf.lastStoredBar.data[hFile][BAR_V];
      hf.bufferedBar.modified[hFile]        = false;                             // Bar wurde gerade gespeichert
   }

   int error = GetLastError();
   if (!error)
      return(true);
   return(!catch("HistoryFile1.WriteBar(15)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]), error));
}


/**
 * Aktualisiert den Schlußkurs der Bar am angegebenen Offset einer Historydatei. Die Bar muß existieren, entweder in der Datei (gespeichert)
 * oder im Barbuffer (ungespeichert).
 *
 * @param  int    hFile  - Handle der Historydatei
 * @param  int    offset - Offset der zu aktualisierenden Bar relativ zum Dateiheader (Offset 0 ist die älteste Bar)
 * @param  double value  - neuer Schlußkurs (z.B. ein weiterer Tick der jüngsten Bar)
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile1.UpdateBar(int hFile, int offset, double value) {
   if (hFile <= 0)                      return(!catch("HistoryFile1.UpdateBar(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile1.UpdateBar(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile1.UpdateBar(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile1.UpdateBar(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (offset < 0 )                     return(!catch("HistoryFile1.UpdateBar(5)  invalid parameter offset: "+ offset +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (offset >= hf.full.bars[hFile])   return(!catch("HistoryFile1.UpdateBar(6)  invalid parameter offset: "+ offset +" ("+ hf.full.bars[hFile] +" full bars, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));

   // vorzugsweise bekannte Bars aktualisieren
   if (offset == hf.bufferedBar.offset[hFile]) {                                 // BufferedBar
      //.bufferedBar.data[hFile][BAR_T] = ...                                    // unverändert
      //.bufferedBar.data[hFile][BAR_O] = ...                                    // unverändert
      hf.bufferedBar.data[hFile][BAR_H] = MathMax(hf.bufferedBar.data[hFile][BAR_H], value);
      hf.bufferedBar.data[hFile][BAR_L] = MathMin(hf.bufferedBar.data[hFile][BAR_L], value);
      hf.bufferedBar.data[hFile][BAR_C] = value;
      hf.bufferedBar.data[hFile][BAR_V]++;
      return(HistoryFile1.WriteBufferedBar(hFile));
   }

   // ist die zu aktualisierende Bar nicht die LastStoredBar, gesuchte Bar einlesen und damit zur LastStoredBar machen
   if (offset != hf.lastStoredBar.offset[hFile]) {
      double bar[6];                                                             // bar[] wird in Folge nicht verwendet
      if (!HistoryFile1.ReadBar(hFile, offset, bar)) return(false);              // setzt LastStoredBar auf die gelesene Bar
   }

   // LastStoredBar aktualisieren und speichern
   //.lastStoredBar.data[hFile][BAR_T] = ...                                     // unverändert
   //.lastStoredBar.data[hFile][BAR_O] = ...                                     // unverändert
   hf.lastStoredBar.data[hFile][BAR_H] = MathMax(hf.lastStoredBar.data[hFile][BAR_H], value);
   hf.lastStoredBar.data[hFile][BAR_L] = MathMin(hf.lastStoredBar.data[hFile][BAR_L], value);
   hf.lastStoredBar.data[hFile][BAR_C] = value;
   hf.lastStoredBar.data[hFile][BAR_V]++;
   return(HistoryFile1.WriteLastStoredBar(hFile));
}


/**
 * Fügt eine Bar am angegebenen Offset einer Historydatei ein. Eine dort vorhandene Bar wird nicht überschrieben, stattdessen werden die
 * vorhandene und alle folgenden Bars um eine Position nach vorn verschoben. Ist die einzufügende Bar die jüngste Bar, muß ihr Offset an die
 * vorhandenen Bars genau anschließen. Sie darf kein physisches Gap verursachen.
 *
 * @param  int    hFile  - Handle der Historydatei
 * @param  int    offset - Offset der einzufügenden Bar relativ zum Dateiheader (Offset 0 ist die älteste Bar)
 * @param  double bar[6] - Bardaten (T-OHLCV)
 * @param  int    flags  - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                         • HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
 *
 * @return bool - Erfolgsstatus
 *
 * NOTE: Time und Volume der einzufügenden Bar werden auf != NULL validert, alles andere nicht. Insbesondere wird nicht überprüft, ob die
 *       Bar-Time eine normalisierte OpenTime für den Timeframe der Historydatei ist.
 */
bool HistoryFile1.InsertBar(int hFile, int offset, double bar[], int flags=NULL) {
   if (hFile <= 0)                      return(!catch("HistoryFile1.InsertBar(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile1.InsertBar(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile1.InsertBar(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile1.InsertBar(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (offset < 0)                      return(!catch("HistoryFile1.InsertBar(5)  invalid parameter offset: "+ offset +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (offset > hf.full.bars[hFile])    return(!catch("HistoryFile1.InsertBar(6)  invalid parameter offset: "+ offset +" ("+ hf.full.bars[hFile] +" full bars, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (ArraySize(bar) != 6)             return(!catch("HistoryFile1.InsertBar(7)  invalid size of parameter data[]: "+ ArraySize(bar) +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INCOMPATIBLE_ARRAYS));

   // ggf. Lücke für einzufügende Bar schaffen
   if (offset < hf.full.bars[hFile])
      if (!HistoryFile1.MoveBars(hFile, offset, offset+1)) return(false);

   // Bar schreiben, HistoryFile1.WriteBar() führt u.a. folgende Tasks aus: - validiert die Bar
   return(HistoryFile1.WriteBar(hFile, offset, bar, flags));             // - speichert eine durch die einzufügende Bar geschlossene BufferedBar
}                                                                        // - aktualisiert die Metadaten der Historydatei


/**
 * Schreibt die LastStoredBar in die Historydatei. Die Bar existiert in der Historydatei bereits.
 *
 * @param  int hFile - Handle der Historydatei
 * @param  int flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                     • HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
 *
 * @return bool - Erfolgsstatus
 *
 * @access private
 */
bool HistoryFile1.WriteLastStoredBar(int hFile, int flags=NULL) {
   if (hFile <= 0)                      return(!catch("HistoryFile1.WriteLastStoredBar(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile1.WriteLastStoredBar(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile1.WriteLastStoredBar(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile1.WriteLastStoredBar(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   int offset = hf.lastStoredBar.offset[hFile];
   if (offset < 0)                      return(_true(logWarn("HistoryFile1.WriteLastStoredBar(5)  undefined lastStoredBar: hf.lastStoredBar.offset="+ offset +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")")));
   if (offset >= hf.stored.bars[hFile]) return(!catch("HistoryFile1.WriteLastStoredBar(6)  invalid hf.lastStoredBar.offset: "+ offset +" ("+ hf.stored.bars[hFile] +" stored bars, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));

   // Bar validieren
   datetime openTime = hf.lastStoredBar.openTime[hFile];         if (!openTime) return(!catch("HistoryFile1.WriteLastStoredBar(8)  invalid hf.lastStoredBar["+ offset +"].time: "+ openTime +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_RUNTIME_ERROR));
   int      V  = Round(hf.lastStoredBar.data    [hFile][BAR_V]); if (!V)        return(!catch("HistoryFile1.WriteLastStoredBar(9)  invalid hf.lastStoredBar["+ offset +"].volume: "+ V +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_RUNTIME_ERROR));

   // FilePointer positionieren, Daten normalisieren und schreiben
   int position = HISTORY_HEADER_size + offset*hf.barSize[hFile], digits=hf.digits[hFile];
   if (!FileSeek(hFile, position, SEEK_SET)) return(!catch("HistoryFile1.WriteLastStoredBar(7)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile])));

   if (hf.format[hFile] == 400) {
      FileWriteInteger(hFile, openTime);
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_O], digits));
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_L], digits));
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_H], digits));
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_C], digits));
      FileWriteDouble (hFile, V);
   }
   else {               // 401
      FileWriteInteger(hFile, openTime);                                                     // int64
      FileWriteInteger(hFile, 0);
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_O], digits));
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_H], digits));
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_L], digits));
      FileWriteDouble (hFile, NormalizeDouble(hf.lastStoredBar.data[hFile][BAR_C], digits));
      FileWriteInteger(hFile, V);                                                            // uint64: ticks
      FileWriteInteger(hFile, 0);
      FileWriteInteger(hFile, 0);                                                            // int:    spread
      FileWriteInteger(hFile, 0);                                                            // uint64: volume
      FileWriteInteger(hFile, 0);
   }
   FileFlush(hFile);                                        // doesn't update last-modified timestamp even if the file size changes

   // Die Bar existierte bereits in der History, die Metadaten ändern sich nicht.

   // Ist die LastStoredBar gleichzeitig die BufferedBar, wird deren veränderlicher Status auch aktualisiert.
   if (offset == hf.bufferedBar.offset[hFile])
      hf.bufferedBar.modified[hFile] = false;               // Bar wurde gerade gespeichert

   int error = GetLastError();
   if (!error)
      return(true);
   return(!catch("HistoryFile1.WriteLastStoredBar(8)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]), error));
}


/**
 * Schreibt den Inhalt der BufferedBar in die Historydatei. Sie ist immer die jüngste Bar und kann in der History bereits existieren, muß es
 * aber nicht.
 *
 * @param  int hFile - Handle der Historydatei
 * @param  int flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                     • HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
 *
 * @return bool - Erfolgsstatus
 *
 * @access private
 */
bool HistoryFile1.WriteBufferedBar(int hFile, int flags=NULL) {
   if (hFile <= 0)                      return(!catch("HistoryFile1.WriteBufferedBar(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile1.WriteBufferedBar(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile1.WriteBufferedBar(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile1.WriteBufferedBar(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   int offset = hf.bufferedBar.offset[hFile];
   if (offset < 0)                      return(_true(logWarn("HistoryFile1.WriteBufferedBar(5)  undefined bufferedBar: hf.bufferedBar.offset="+ offset +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")")));
   if (offset != hf.full.bars[hFile]-1) return(!catch("HistoryFile1.WriteBufferedBar(6)  invalid hf.bufferedBar.offset: "+ offset +" ("+ hf.full.bars[hFile] +" full bars, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_RUNTIME_ERROR));

   // Die Bar wird nur dann geschrieben, wenn sie sich seit dem letzten Schreiben geändert hat.
   if (hf.bufferedBar.modified[hFile]) {
      // Bar validieren
      datetime openTime = hf.bufferedBar.openTime[hFile];         if (!openTime) return(!catch("HistoryFile1.WriteBufferedBar(7)  invalid hf.lastStoredBar["+ offset +"].time: "+ openTime +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_RUNTIME_ERROR));
      int      V  = Round(hf.bufferedBar.data    [hFile][BAR_V]); if (!V)        return(!catch("HistoryFile1.WriteBufferedBar(8)  invalid hf.lastStoredBar["+ offset +"].volume: "+ V +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_RUNTIME_ERROR));

      // FilePointer positionieren, Daten normalisieren und schreiben
      int position = HISTORY_HEADER_size + offset*hf.barSize[hFile], digits=hf.digits[hFile];
      if (!FileSeek(hFile, position, SEEK_SET)) return(!catch("HistoryFile1.WriteBufferedBar(9)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile])));

      hf.bufferedBar.data[hFile][BAR_O] = NormalizeDouble(hf.bufferedBar.data[hFile][BAR_O], digits);
      hf.bufferedBar.data[hFile][BAR_H] = NormalizeDouble(hf.bufferedBar.data[hFile][BAR_H], digits);
      hf.bufferedBar.data[hFile][BAR_L] = NormalizeDouble(hf.bufferedBar.data[hFile][BAR_L], digits);
      hf.bufferedBar.data[hFile][BAR_C] = NormalizeDouble(hf.bufferedBar.data[hFile][BAR_C], digits);
      hf.bufferedBar.data[hFile][BAR_V] = V;

      if (hf.format[hFile] == 400) {
         FileWriteInteger(hFile, openTime);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_O]);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_L]);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_H]);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_C]);
         FileWriteDouble (hFile, V);
      }
      else {               // 401
         FileWriteInteger(hFile, openTime);                             // int64
         FileWriteInteger(hFile, 0);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_O]);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_H]);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_L]);
         FileWriteDouble (hFile, hf.bufferedBar.data[hFile][BAR_C]);
         FileWriteInteger(hFile, V);                                    // uint64: ticks
         FileWriteInteger(hFile, 0);
         FileWriteInteger(hFile, 0);                                    // int:    spread
         FileWriteInteger(hFile, 0);                                    // uint64: volume
         FileWriteInteger(hFile, 0);
      }
      hf.bufferedBar.modified[hFile] = false;

      // Das Schreiben macht die BufferedBar zusätzlich zur LastStoredBar.
      hf.lastStoredBar.offset       [hFile]        = hf.bufferedBar.offset       [hFile];
      hf.lastStoredBar.openTime     [hFile]        = hf.bufferedBar.openTime     [hFile];
      hf.lastStoredBar.closeTime    [hFile]        = hf.bufferedBar.closeTime    [hFile];
      hf.lastStoredBar.nextCloseTime[hFile]        = hf.bufferedBar.nextCloseTime[hFile];
      hf.lastStoredBar.data         [hFile][BAR_T] = hf.bufferedBar.data         [hFile][BAR_T];
      hf.lastStoredBar.data         [hFile][BAR_O] = hf.bufferedBar.data         [hFile][BAR_O];
      hf.lastStoredBar.data         [hFile][BAR_H] = hf.bufferedBar.data         [hFile][BAR_H];
      hf.lastStoredBar.data         [hFile][BAR_L] = hf.bufferedBar.data         [hFile][BAR_L];
      hf.lastStoredBar.data         [hFile][BAR_C] = hf.bufferedBar.data         [hFile][BAR_C];
      hf.lastStoredBar.data         [hFile][BAR_V] = hf.bufferedBar.data         [hFile][BAR_V];

      // Metadaten aktualisieren: - Die Bar kann (a) erste Bar einer leeren History sein, (b) existierende jüngste Bar oder (c) neue jüngste Bar sein.
      //                          - Die Bar ist immer die jüngste (letzte) Bar.
      //                          - Die Metadaten von hf.full.* ändern sich nicht.
      //                          - Nach dem Speichern stimmen hf.stored.* und hf.full.* überein.
      hf.stored.bars              [hFile] = hf.full.bars              [hFile];

      hf.stored.from.offset       [hFile] = hf.full.from.offset       [hFile];
      hf.stored.from.openTime     [hFile] = hf.full.from.openTime     [hFile];
      hf.stored.from.closeTime    [hFile] = hf.full.from.closeTime    [hFile];
      hf.stored.from.nextCloseTime[hFile] = hf.full.from.nextCloseTime[hFile];

      hf.stored.to.offset         [hFile] = hf.full.to.offset         [hFile];
      hf.stored.to.openTime       [hFile] = hf.full.to.openTime       [hFile];
      hf.stored.to.closeTime      [hFile] = hf.full.to.closeTime      [hFile];
      hf.stored.to.nextCloseTime  [hFile] = hf.full.to.nextCloseTime  [hFile];
   }

   int error = GetLastError();
   if (!error)
      return(true);
   return(!catch("HistoryFile1.WriteBufferedBar(10)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]), error));
}


/**
 * Verschiebt alle Bars beginnend vom angegebenen from-Offset bis zum Ende der Historydatei an den angegebenen Ziel-Offset.
 *
 * @param  int hFile      - Handle der Historydatei
 * @param  int fromOffset - Start-Offset
 * @param  int destOffset - Ziel-Offset: Ist dieser Wert kleiner als der Start-Offset, wird die Historydatei entsprechend gekürzt.
 *
 * @return bool - Erfolgsstatus                                            TODO: Implementieren
 */
bool HistoryFile1.MoveBars(int hFile, int fromOffset, int destOffset) {
   return(!catch("HistoryFile1.MoveBars(1)  "+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_NOT_IMPLEMENTED));
}


/**
 * Fügt einer Historydatei einen weiteren Tick hinzu. Der Tick muß zur jüngsten Bar der Datei gehören und wird als Close-Preis gespeichert.
 *
 * @param  int      hFile - Handle der Historydatei
 * @param  datetime time  - Zeitpunkt des Ticks
 * @param  double   value - Datenwert
 * @param  int      flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                          • HST_BUFFER_TICKS: puffert aufeinanderfolgende Ticks und schreibt die Daten erst beim jeweils nächsten
 *                            BarOpen-Event
 *                          • HST_FILL_GAPS:    füllt entstehende Gaps mit dem letzten Schlußkurs vor dem Gap
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile1.AddTick(int hFile, datetime time, double value, int flags=NULL) {
   if (hFile <= 0)                        return(!catch("HistoryFile1.AddTick(1)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile))   return(!catch("HistoryFile1.AddTick(2)  invalid parameter hFile: "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)           return(!catch("HistoryFile1.AddTick(3)  invalid parameter hFile: "+ hFile +" (unknown handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)           return(!catch("HistoryFile1.AddTick(4)  invalid parameter hFile: "+ hFile +" (closed handle, symbol="+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (time <= 0)                         return(!catch("HistoryFile1.AddTick(5)  invalid parameter time: "+ time +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));
   if (time < hf.full.to.openTime[hFile]) return(!catch("HistoryFile1.AddTick(6)  cannot add tick to a closed bar: tickTime="+ TimeToStr(time, TIME_FULL) +", last bar.time="+ TimeToStr(hf.full.to.openTime[hFile], TIME_FULL) +" ("+ hf.symbol[hFile] +","+ PeriodDescription(hf.period[hFile]) +")", ERR_INVALID_PARAMETER));

   double bar[6];
   bool   barExists[1];

   // Offset und OpenTime der Tick-Bar bestimmen
   datetime tick.time=time, tick.openTime;
   int      tick.offset      = -1;                                                     // Offset der Bar, zu der der Tick gehört
   double   tick.value       = NormalizeDouble(value, hf.digits[hFile]);
   bool     bufferedBarClose = false;                                                  // ob der Tick für die BufferedBar ein BarClose-Event auslöst

   // Vorzugsweise (häufigster Fall) BufferedBar benutzen (bevor diese ggf. durch ein BarClose-Event geschlossen wird).
   if (hf.bufferedBar.offset[hFile] >= 0) {                                            // BufferedBar ist definiert (und ist immer jüngste Bar)
      if (tick.time < hf.bufferedBar.closeTime[hFile]) {
         tick.offset   = hf.bufferedBar.offset  [hFile];                               // Tick liegt in BufferedBar
         tick.openTime = hf.bufferedBar.openTime[hFile];
      }
      else {
         if (tick.time < hf.bufferedBar.nextCloseTime[hFile]) {
            tick.offset   = hf.bufferedBar.offset   [hFile] + 1;                       // Tick liegt in der BufferedBar folgenden Bar
            tick.openTime = hf.bufferedBar.closeTime[hFile];
         }
         bufferedBarClose = true;                                                      // und löst für die BufferedBar ein BarClose-Event aus
      }
   }
   // Danach LastStoredBar benutzen (bevor diese ggf. von HistoryFile1._WriteBufferedBar() überschrieben wird).
   if (tick.offset==-1) /*&&*/ if (hf.lastStoredBar.offset[hFile] >= 0) {              // LastStoredBar ist definiert
      if (time >= hf.lastStoredBar.openTime[hFile]) {
         if (tick.time < hf.lastStoredBar.closeTime[hFile]) {
            tick.offset   = hf.lastStoredBar.offset  [hFile];                          // Tick liegt in LastStoredBar
            tick.openTime = hf.lastStoredBar.openTime[hFile];
         }
         else if (tick.time < hf.lastStoredBar.nextCloseTime[hFile]) {
            tick.offset   = hf.lastStoredBar.offset   [hFile] + 1;                     // Tick liegt in der LastStoredBar folgenden Bar
            tick.openTime = hf.lastStoredBar.closeTime[hFile];
         }
      }
   }
   // eine geschlossene BufferedBar schreiben
   if (bufferedBarClose) {
      if (!HistoryFile1.WriteBufferedBar(hFile, flags)) return(false);
      hf.bufferedBar.offset[hFile] = -1;                                               // BufferedBar zurücksetzen
   }

   // HST_BUFFER_TICKS = TRUE:  Tick buffern
   if (HST_BUFFER_TICKS & flags && 1) {
      // ist BufferedBar leer, Tickbar laden oder neue Bar beginnen und zur BufferedBar machen
      if (hf.bufferedBar.offset[hFile] < 0) {                                          // BufferedBar ist leer
         if (tick.offset == -1) {
            if      (hf.period[hFile] <= PERIOD_D1 ) tick.openTime = tick.time - tick.time%hf.periodSecs[hFile];
            else if (hf.period[hFile] == PERIOD_W1 ) tick.openTime = tick.time - tick.time%DAYS - (TimeDayOfWeekEx(tick.time)+6)%7*DAYS;        // 00:00, Montag
            else if (hf.period[hFile] == PERIOD_MN1) tick.openTime = tick.time - tick.time%DAYS - (TimeDayEx(tick.time)-1)*DAYS;                // 00:00, 1. des Monats
            tick.offset = HistoryFile1.FindBar(hFile, tick.openTime, barExists); if (tick.offset < 0) return(false);
         }
         if (tick.offset < hf.full.bars[hFile]) {                                      // Tickbar existiert, laden
            if (!HistoryFile1.ReadBar(hFile, tick.offset, bar)) return(false);          // ReadBar() setzt LastStoredBar auf die Tickbar
            hf.bufferedBar.offset       [hFile]        = hf.lastStoredBar.offset       [hFile];
            hf.bufferedBar.openTime     [hFile]        = hf.lastStoredBar.openTime     [hFile];
            hf.bufferedBar.closeTime    [hFile]        = hf.lastStoredBar.closeTime    [hFile];
            hf.bufferedBar.nextCloseTime[hFile]        = hf.lastStoredBar.nextCloseTime[hFile];
            hf.bufferedBar.data         [hFile][BAR_T] = hf.lastStoredBar.data         [hFile][BAR_T];
            hf.bufferedBar.data         [hFile][BAR_O] = hf.lastStoredBar.data         [hFile][BAR_O];
            hf.bufferedBar.data         [hFile][BAR_H] = hf.lastStoredBar.data         [hFile][BAR_H];
            hf.bufferedBar.data         [hFile][BAR_L] = hf.lastStoredBar.data         [hFile][BAR_L];
            hf.bufferedBar.data         [hFile][BAR_C] = hf.lastStoredBar.data         [hFile][BAR_C];
            hf.bufferedBar.data         [hFile][BAR_V] = hf.lastStoredBar.data         [hFile][BAR_V];
            hf.bufferedBar.modified     [hFile]        = false;
         }
         else {                                                                        // Tickbar existiert nicht, neue BufferedBar initialisieren
            datetime closeTime, nextCloseTime;
            if (hf.period[hFile] <= PERIOD_W1) {
               closeTime     = tick.openTime + hf.periodSecs[hFile];
               nextCloseTime = closeTime     + hf.periodSecs[hFile];
            }
            else if (hf.period[hFile] == PERIOD_MN1) {
               closeTime     = DateTime(TimeYearEx(tick.openTime), TimeMonth(tick.openTime)+1);    // 00:00, 1. des nächsten Monats
               nextCloseTime = DateTime(TimeYearEx(tick.openTime), TimeMonth(tick.openTime)+2);    // 00:00, 1. des übernächsten Monats
            }
            hf.bufferedBar.offset       [hFile]        = tick.offset;
            hf.bufferedBar.openTime     [hFile]        = tick.openTime;
            hf.bufferedBar.closeTime    [hFile]        = closeTime;
            hf.bufferedBar.nextCloseTime[hFile]        = nextCloseTime;
            hf.bufferedBar.data         [hFile][BAR_T] = tick.openTime;
            hf.bufferedBar.data         [hFile][BAR_O] = tick.value;
            hf.bufferedBar.data         [hFile][BAR_H] = tick.value;
            hf.bufferedBar.data         [hFile][BAR_L] = tick.value;
            hf.bufferedBar.data         [hFile][BAR_C] = tick.value;
            hf.bufferedBar.data         [hFile][BAR_V] = 0;                                        // das Volume wird erst im nächsten Schritt auf 1 gesetzt
            hf.bufferedBar.modified     [hFile]        = true;

            // Metadaten aktualisieren: - Die Bar kann (a) erste Bar einer leeren History oder (b) neue Bar am Ende sein.
            //                          - Die Bar ist immer die jüngste (letzte) Bar.
            //                          - Die Bar existiert in der Historydatei nicht, die Metadaten von hf.stored.* ändern sich daher nicht.
                                    hf.full.bars              [hFile] = tick.offset + 1;

            if (tick.offset == 0) { hf.full.from.offset       [hFile] = tick.offset;
                                    hf.full.from.openTime     [hFile] = tick.openTime;
                                    hf.full.from.closeTime    [hFile] = closeTime;
                                    hf.full.from.nextCloseTime[hFile] = nextCloseTime; }

                                    hf.full.to.offset         [hFile] = tick.offset;
                                    hf.full.to.openTime       [hFile] = tick.openTime;
                                    hf.full.to.closeTime      [hFile] = closeTime;
                                    hf.full.to.nextCloseTime  [hFile] = nextCloseTime;
         }
      }

      // BufferedBar aktualisieren
      //.bufferedBar.data    [hFile][BAR_T] = ...                                      // unverändert
      //.bufferedBar.data    [hFile][BAR_O] = ...                                      // unverändert
      hf.bufferedBar.data    [hFile][BAR_H] = MathMax(hf.bufferedBar.data[hFile][BAR_H], tick.value);
      hf.bufferedBar.data    [hFile][BAR_L] = MathMin(hf.bufferedBar.data[hFile][BAR_L], tick.value);
      hf.bufferedBar.data    [hFile][BAR_C] = tick.value;
      hf.bufferedBar.data    [hFile][BAR_V]++;
      hf.bufferedBar.modified[hFile]        = true;

      return(true);
   }// end if HST_BUFFER_TICKS = TRUE


   // HST_BUFFER_TICKS = FALSE:  Tick schreiben
   // ist BufferedBar definiert (HST_BUFFER_TICKS war beim letzten Tick ON und ist jetzt OFF), BufferedBar mit Tick aktualisieren, schreiben und zurücksetzen
   if (hf.bufferedBar.offset[hFile] >= 0) {                                            // BufferedBar ist definiert, der Tick muß dazu gehören
      //.bufferedBar.data[hFile][BAR_T] = ...                                          // unverändert
      //.bufferedBar.data[hFile][BAR_O] = ...                                          // unverändert
      hf.bufferedBar.data[hFile][BAR_H] = MathMax(hf.bufferedBar.data[hFile][BAR_H], tick.value);
      hf.bufferedBar.data[hFile][BAR_L] = MathMin(hf.bufferedBar.data[hFile][BAR_L], tick.value);
      hf.bufferedBar.data[hFile][BAR_C] = tick.value;
      hf.bufferedBar.data[hFile][BAR_V]++;
      if (!HistoryFile1.WriteBufferedBar(hFile, flags)) return(false);
      hf.bufferedBar.offset[hFile] = -1;                                               // BufferedBar zurücksetzen
      return(true);
   }

   // BufferedBar ist leer: Tickbar mit Tick aktualisieren oder neue Bar mit Tick zu History hinzufügen
   if (tick.offset == -1) {
      if      (hf.period[hFile] <= PERIOD_D1 ) tick.openTime = tick.time - tick.time%hf.periodSecs[hFile];
      else if (hf.period[hFile] == PERIOD_W1 ) tick.openTime = tick.time - tick.time%DAYS - (TimeDayOfWeekEx(tick.time)+6)%7*DAYS;          // 00:00, Montag
      else if (hf.period[hFile] == PERIOD_MN1) tick.openTime = tick.time - tick.time%DAYS - (TimeDayEx(tick.time)-1)*DAYS;                  // 00:00, 1. des Monats
      tick.offset = HistoryFile1.FindBar(hFile, tick.openTime, barExists); if (tick.offset < 0) return(false);
   }
   if (tick.offset < hf.full.bars[hFile]) {
      if (!HistoryFile1.UpdateBar(hFile, tick.offset, tick.value)) return(false);      // existierende Bar aktualisieren
   }
   else {
      bar[BAR_T] = tick.openTime;                                                      // oder neue Bar einfügen
      bar[BAR_O] = tick.value;
      bar[BAR_H] = tick.value;
      bar[BAR_L] = tick.value;
      bar[BAR_C] = tick.value;
      bar[BAR_V] = 1;
      if (!HistoryFile1.InsertBar(hFile, tick.offset, bar, flags|HST_TIME_IS_OPENTIME)) return(false);
   }
   return(true);
}


/**
 * Setzt die Größe der internen HistorySet-Datenarrays auf den angegebenen Wert.
 *
 * @param  int size - neue Größe
 *
 * @return int - neue Größe der Arrays
 *
 * @access private
 */
int ResizeSetArrays(int size) {
   if (size != ArraySize(hs.hSet)) {
      ArrayResize(hs.hSet,        size);
      ArrayResize(hs.symbol,      size);
      ArrayResize(hs.symbolUpper, size);
      ArrayResize(hs.description, size);
      ArrayResize(hs.digits,      size);
      ArrayResize(hs.server,      size);
      ArrayResize(hs.hFile,       size);
      ArrayResize(hs.format,      size);
   }
   return(size);
}


/**
 * Setzt die Größe der internen HistoryFile-Datenarrays auf den angegebenen Wert.
 *
 * @param  int size - neue Größe
 *
 * @return int - neue Größe der Arrays
 *
 * @access private
 */
int ResizeFileArrays(int size) {
   int oldSize = ArraySize(hf.hFile);

   if (size != oldSize) {
      ArrayResize(hf.hFile,                       size);
      ArrayResize(hf.name,                        size);
      ArrayResize(hf.readAccess,                  size);
      ArrayResize(hf.writeAccess,                 size);

      ArrayResize(hf.header,                      size);
      ArrayResize(hf.format,                      size);
      ArrayResize(hf.barSize,                     size);
      ArrayResize(hf.symbol,                      size);
      ArrayResize(hf.symbolUpper,                 size);
      ArrayResize(hf.period,                      size);
      ArrayResize(hf.periodSecs,                  size);
      ArrayResize(hf.digits,                      size);
      ArrayResize(hf.server,                      size);

      ArrayResize(hf.stored.bars,                 size);
      ArrayResize(hf.stored.from.offset,          size);
      ArrayResize(hf.stored.from.openTime,        size);
      ArrayResize(hf.stored.from.closeTime,       size);
      ArrayResize(hf.stored.from.nextCloseTime,   size);
      ArrayResize(hf.stored.to.offset,            size);
      ArrayResize(hf.stored.to.openTime,          size);
      ArrayResize(hf.stored.to.closeTime,         size);
      ArrayResize(hf.stored.to.nextCloseTime,     size);

      ArrayResize(hf.full.bars,                   size);
      ArrayResize(hf.full.from.offset,            size);
      ArrayResize(hf.full.from.openTime,          size);
      ArrayResize(hf.full.from.closeTime,         size);
      ArrayResize(hf.full.from.nextCloseTime,     size);
      ArrayResize(hf.full.to.offset,              size);
      ArrayResize(hf.full.to.openTime,            size);
      ArrayResize(hf.full.to.closeTime,           size);
      ArrayResize(hf.full.to.nextCloseTime,       size);

      ArrayResize(hf.lastStoredBar.offset,        size);
      ArrayResize(hf.lastStoredBar.openTime,      size);
      ArrayResize(hf.lastStoredBar.closeTime,     size);
      ArrayResize(hf.lastStoredBar.nextCloseTime, size);
      ArrayResize(hf.lastStoredBar.data,          size);

      ArrayResize(hf.bufferedBar.offset,          size);
      ArrayResize(hf.bufferedBar.openTime,        size);
      ArrayResize(hf.bufferedBar.closeTime,       size);
      ArrayResize(hf.bufferedBar.nextCloseTime,   size);
      ArrayResize(hf.bufferedBar.data,            size);
      ArrayResize(hf.bufferedBar.modified,        size);

      for (int i=size-1; i >= oldSize; i--) {                        // falls Arrays vergrößert werden, neue Offsets initialisieren
         hf.lastStoredBar.offset [i] = -1;
         hf.bufferedBar.offset[i] = -1;
      }
   }
   return(size);
}


/**
 * Clean up opened files and issue a warning if an unclosed file was found.
 *
 * @return bool - success status
 *
 * @access private
 */
bool CheckFileHandles() {
   int error, size=ArraySize(hf.hFile);

   for (int i=0; i < size; i++) {
      if (hf.hFile[i] > 0) {
         logWarn("CheckFileHandles(1)  open file handle #"+ hf.hFile[i] +" found ("+ hf.symbol[i] +","+ PeriodDescription(hf.period[i]) +")");
         if (!HistoryFile1.Close(hf.hFile[i]))
            error = last_error;
      }
   }
   return(!error);
}


/**
 * Custom handler called in tester from core/library::init() to reset global variables before the next test.
 */
void onLibraryInit() {
   ResizeSetArrays(0);
   ResizeFileArrays(0);
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   CheckFileHandles();
   return(last_error);
}
