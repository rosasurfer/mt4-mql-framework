/**
 * Funktionen zur Verwaltung von Kursreihen im "history"-Verzeichnis.
 *
 *
 * Anwendungsbeispiele
 * -------------------
 *  1. Erzeugen einer neuen History mit Löschen ggf. vorhandener Daten:
 *     int hSet = HistorySet.Create(symbol, description, digits, format);
 *
 *  2. Öffnen einer existierenden History ohne Löschen vorhandener Daten:
 *     int hSet = HistorySet.Get(symbol);
 *
 *
 * TODO: Offsets analog zur Chart-Indizierung implementieren (Offset 0 = jüngste Bar)
 */
#property library

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/library.mqh>
#include <stdfunctions.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>
#include <stdlib.mqh>
#include <structs/mt4/HISTORY_HEADER.mqh>


// Standard-Timeframes ------------------------------------------------------------------------------------------------------------------------------------
int      periods[] = { PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1 };


// Daten kompletter History-Sets --------------------------------------------------------------------------------------------------------------------------
int      hs.hSet       [];                         // Set-Handle: größer 0 = offenes Handle; kleiner 0 = geschlossenes Handle; 0 = ungültiges Handle
int      hs.hSet.lastValid;                        // das letzte gültige, offene Handle (um ein übergebenes Handle nicht ständig neu validieren zu müssen)
string   hs.symbol     [];                         // Symbol
string   hs.symbolU    [];                         // SYMBOL (Upper-Case)
string   hs.description[];                         // Symbol-Beschreibung
int      hs.digits     [];                         // Symbol-Digits
string   hs.server     [];                         // Servername des Sets
int      hs.hFile      [][9];                      // HistoryFile-Handles des Sets je Standard-Timeframe
int      hs.format     [];                         // Datenformat für neu zu erstellende HistoryFiles


// Daten einzelner History-Files --------------------------------------------------------------------------------------------------------------------------
int      hf.hFile      [];                         // Dateihandle: größer 0 = offenes Handle; kleiner 0 = geschlossenes Handle; 0 = ungültiges Handle
int      hf.hFile.lastValid;                       // das letzte gültige, offene Handle (um ein übergebenes Handle nicht ständig neu validieren zu müssen)
string   hf.name       [];                         // Dateiname, ggf. mit Unterverzeichnis "MyFX-Synthetic\"
bool     hf.readAccess [];                         // ob das Handle Lese-Zugriff erlaubt
bool     hf.writeAccess[];                         // ob das Handle Schreib-Zugriff erlaubt
int      hf.size       [];                         // aktuelle Größe der Datei (inkl. noch ungeschriebener Daten im Schreibpuffer)

int      hf.header     [][HISTORY_HEADER.intSize]; // History-Header der Datei
int      hf.format     [];                         // Datenformat: 400 | 401
string   hf.symbol     [];                         // Symbol
string   hf.symbolU    [];                         // SYMBOL (Upper-Case)
int      hf.period     [];                         // Periode
int      hf.periodSecs [];                         // Dauer einer Periode in Sekunden (nicht gültig für Perioden > 1 Tag)
int      hf.digits     [];                         // Digits
string   hf.server     [];                         // Servername der Datei

int      hf.bars       [];                         // Anzahl der Bars der Datei
datetime hf.from       [];                         // OpenTime der ersten Bar der Datei
datetime hf.to         [];                         // OpenTime der letzten Bar der Datei


// Cache der aktuellen Bar einer History-Datei (an der Position des File-Pointers) ------------------------------------------------------------------------
int      hf.currentBar.offset         [];          // Offset relativ zum Header: Offset 0 ist die älteste Bar, initialisiert mit -1
datetime hf.currentBar.openTime       [];          //
datetime hf.currentBar.closeTime      [];          //
datetime hf.currentBar.nextCloseTime  [];          //
double   hf.currentBar.data           [][6];       // Bar-Daten (T-OHLCV)


// Schreibpuffer für gesammelte Ticks einer noch ungespeicherten Bar (bei HST_COLLECT_TICKS = On) ---------------------------------------------------------
int      hf.collectedBar.offset       [];          // Offset relativ zum Header: Offset 0 ist die älteste Bar, initialisiert mit -1
datetime hf.collectedBar.openTime     [];          // z.B.: 12:00:00
datetime hf.collectedBar.closeTime    [];          //       13:00:00 (nicht 12:59:59)
datetime hf.collectedBar.nextCloseTime[];          //       14:00:00 (nicht 13:59:59)
double   hf.collectedBar.data         [][6];       // Bar-Daten (T-OHLCV)


/**
 * Gibt ein Handle für das gesamte HistorySet eines Symbols zurück. Wurde das HistorySet vorher nicht mit HistorySet.Create() erzeugt,
 * muß mindestens ein HistoryFile des Symbols existieren. Nicht existierende HistoryFiles werden dann beim Speichern der ersten hinzugefügten
 * Daten automatisch im alten Datenformat (400) erstellt.
 *
 * - Mehrfachaufrufe dieser Funktion für dasselbe Symbol geben dasselbe Handle zurück.
 * - Die Funktion greift ggf. auf genau eine Historydatei lesend zu. Sie hält keine Dateien offen.
 *
 * @param  __IN__ string symbol - Symbol
 * @param  __IN__ string server - Name des Serververzeichnisses, in dem das Set gespeichert wird (default: aktuelles Serververzeichnis)
 *
 * @return int - • Set-Handle oder -1, falls noch kein einziges HistoryFile dieses Symbols existiert. In diesem Fall muß mit HistorySet.Create() ein neues Set erzeugt werden.
 *               • NULL, falls ein Fehler auftrat.
 *
 *
 * NOTE: evt. Timeframe-Flags für selektive Sets implementieren (z.B. alles außer W1 und MN1)
 */
int HistorySet.Get(string symbol, string server="") {
   if (!StringLen(symbol))                    return(!catch("HistorySet.Get(1)  invalid parameter symbol = "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(!catch("HistorySet.Get(2)  invalid parameter symbol = "+ DoubleQuoteStr(symbol) +" (max "+ MAX_SYMBOL_LENGTH +" characters)", ERR_INVALID_PARAMETER));
   string symbolU = StringToUpper(symbol);
   if (server == "0")      server = "";                                 // (string) NULL
   if (!StringLen(server)) server = GetServerName();


   // (1) offene Set-Handles durchsuchen
   int size = ArraySize(hs.hSet);
   for (int i=0; i < size; i++) {                                       // Das Handle muß offen sein.
      if (hs.hSet[i] > 0) /*&&*/ if (hs.symbolU[i]==symbolU) /*&&*/ if (StringCompareI(hs.server[i], server))
         return(hs.hSet[i]);
   }                                                                    // kein offenes Set-Handle gefunden

   int iH, hSet=-1;

   // (2) offene File-Handles durchsuchen
   size = ArraySize(hf.hFile);
   for (i=0; i < size; i++) {                                           // Das Handle muß offen sein.
      if (hf.hFile[i] > 0) /*&&*/ if (hf.symbolU[i]==symbolU) /*&&*/ if (StringCompareI(hf.server[i], server)) {
         size = Max(ArraySize(hs.hSet), 1) + 1;                         // neues HistorySet erstellen (minSize=2: auf Index[0] kann kein gültiges Handle liegen)
         hs.__ResizeArrays(size);
         iH   = size-1;
         hSet = iH;                                                     // das Set-Handle entspricht jeweils dem Index in hs.*[]

         hs.hSet       [iH] = hSet;
         hs.symbol     [iH] = hf.symbol [i];
         hs.symbolU    [iH] = hf.symbolU[i];
         hs.description[iH] = hhs.Description(hf.header, i);
         hs.digits     [iH] = hf.digits [i];
         hs.server     [iH] = hf.server [i];
         hs.format     [iH] = 400;                                      // Default für neu zu erstellende HistoryFiles

         return(hSet);
      }
   }                                                                    // kein offenes File-Handle gefunden


   // (3) existierende HistoryFiles suchen
   string mqlDir     = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string mqlHstDir  = ".history\\"+ server +"\\";                      // Verzeichnisname für MQL-Dateifunktionen
   string fullHstDir = TerminalPath() + mqlDir +"\\files\\"+ mqlHstDir; // Verzeichnisname für Win32-Dateifunktionen

   string baseName, mqlFileName, fullFileName;
   int hFile, fileSize, sizeOfPeriods=ArraySize(periods);

   for (i=0; i < sizeOfPeriods; i++) {
      baseName     = symbol + periods[i] +".hst";
      mqlFileName  = mqlHstDir  + baseName;                             // Dateiname für MQL-Dateifunktionen
      fullFileName = fullHstDir + baseName;                             // Dateiname für Win32-Dateifunktionen

      if (IsFile(fullFileName)) {                                       // wenn Datei existiert, öffnen
         hFile = FileOpen(mqlFileName, FILE_BIN|FILE_READ);             // FileOpenHistory() kann Unterverzeichnisse nicht handhaben => alle Zugriffe per FileOpen(symlink)
         if (hFile <= 0) return(!catch("HistorySet.Get(3)  hFile(\""+ mqlFileName +"\") = "+ hFile, ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR)));

         fileSize = FileSize(hFile);                                    // Datei geöffnet
         if (fileSize < HISTORY_HEADER.size) {
            FileClose(hFile);
            warn("HistorySet.Get(4)  invalid history file \""+ mqlFileName +"\" found (size="+ fileSize +")");
            continue;
         }
                                                                        // HISTORY_HEADER auslesen
         /*HISTORY_HEADER*/int hh[]; ArrayResize(hh, HISTORY_HEADER.intSize);
         FileReadArray(hFile, hh, 0, HISTORY_HEADER.intSize);
         FileClose(hFile);

         size = Max(ArraySize(hs.hSet), 1) + 1;                         // neues HistorySet erstellen (minSize=2: auf Index[0] kann kein gültiges Handle liegen)
         hs.__ResizeArrays(size);
         iH   = size-1;
         hSet = iH;                                                     // das Set-Handle entspricht jeweils dem Index in hs.*[]

         hs.hSet       [iH] = hSet;
         hs.symbol     [iH] = hh.Symbol     (hh);
         hs.symbolU    [iH] = StringToUpper(hs.symbol[iH]);
         hs.description[iH] = hh.Description(hh);
         hs.digits     [iH] = hh.Digits     (hh);
         hs.server     [iH] = server;
         hs.format     [iH] = 400;                                      // Default für neu zu erstellende HistoryFiles

         //debug("HistorySet.Get(5)  file=\""+ mqlFileName +"\"  symbol=\""+ hs.symbol[iH] +"\"  description=\""+ hs.description[iH] +"\"  digits="+ hs.digits[iH]);
         ArrayResize(hh, 0);
         return(hSet);                                                  // Rückkehr nach der ersten ausgewerteten Datei
      }
   }


   if (!catch("HistorySet.Get(6)"))
      return(-1);
   return(NULL);
}


/**
 * Erzeugt für ein Symbol ein neues HistorySet mit den angegebenen Daten und gibt dessen Handle zurück. Beim Aufruf der Funktion werden
 * bereits existierende HistoryFiles des Symbols zurückgesetzt (vorhandene Bardaten werden gelöscht) und evt. offene HistoryFile-Handles
 * geschlossen. Noch nicht existierende HistoryFiles werden beim ersten Speichern hinzugefügter Daten automatisch erstellt.
 *
 * Mehrfachaufrufe dieser Funktion für dasselbe Symbol geben jeweils ein neues Handle zurück, ein vorheriges Handle wird geschlossen.
 *
 * @param  __IN__ string symbol      - Symbol
 * @param  __IN__ string description - Beschreibung des Symbols
 * @param  __IN__ int    digits      - Digits der Datenreihe
 * @param  __IN__ int    format      - Speicherformat der Datenreihe: 400 - altes Datenformat (wie MetaTrader bis Build 509)
 *                                                                    401 - neues Datenformat (wie MetaTrader ab Build 510)
 * @param  __IN__ string server      - Name des Serververzeichnisses, in dem das Set gespeichert wird (default: aktuelles Serververzeichnis)
 *
 * @return int - Set-Handle oder NULL, falls ein Fehler auftrat.
 *
 *
 * TODO:   Parameter int fTimeframes - Timeframe-Flags implementieren
 */
int HistorySet.Create(string symbol, string description, int digits, int format, string server="") {
   // Parametervalidierung
   if (!StringLen(symbol))                    return(!catch("HistorySet.Create(1)  illegal parameter symbol = "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(!catch("HistorySet.Create(2)  illegal parameter symbol = "+ DoubleQuoteStr(symbol) +" (max "+ MAX_SYMBOL_LENGTH +" characters)", ERR_INVALID_PARAMETER));
   string symbolU = StringToUpper(symbol);
   if (!StringLen(description))     description = "";                            // NULL-Pointer => Leerstring
   if (StringLen(description) > 63) description = StringLeft(description, 63);   // ein zu langer String wird gekürzt
   if (digits < 0)                            return(!catch("HistorySet.Create(3)  invalid parameter digits = "+ digits, ERR_INVALID_PARAMETER));
   if (format!=400) /*&&*/ if (format!=401)   return(!catch("HistorySet.Create(4)  invalid parameter format = "+ format +" (needs to be 400 or 401)", ERR_INVALID_PARAMETER));
   if (server == "0")      server = "";                                          // (string) NULL
   if (!StringLen(server)) server = GetServerName();


   // (1) offene Set-Handles durchsuchen und Sets schließen
   int size = ArraySize(hs.hSet);
   for (int i=0; i < size; i++) {                                       // Das Handle muß offen sein.
      if (hs.hSet[i] > 0) /*&&*/ if (hs.symbolU[i]==symbolU) /*&&*/ if (StringCompareI(hs.server[i], server)) {
         // wenn Symbol gefunden, Set schließen...
         if (hs.hSet.lastValid == hs.hSet[i])
            hs.hSet.lastValid = NULL;
         hs.hSet[i] = -1;

         // Dateien des Sets schließen...
         size = ArrayRange(hs.hFile, 1);
         for (int n=0; n < size; n++) {
            if (hs.hFile[i][n] > 0) {
               if (!HistoryFile.Close(hs.hFile[i][n]))
                  return(NULL);
               hs.hFile[i][n] = -1;
            }
         }
      }
   }


   // (2) offene File-Handles durchsuchen und Dateien schließen
   size = ArraySize(hf.hFile);
   for (i=0; i < size; i++) {                                           // Das Handle muß offen sein.
      if (hf.hFile[i] > 0) /*&&*/ if (hf.symbolU[i]==symbolU) /*&&*/ if (StringCompareI(hf.server[i], server)){
         if (!HistoryFile.Close(hf.hFile[i]))
            return(NULL);
      }
   }


   // (3) existierende HistoryFiles zurücksetzen und ihre Header aktualisieren
   string mqlDir     = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string mqlHstDir  = ".history\\"+ server +"\\";                      // Verzeichnisname für MQL-Dateifunktionen
   string fullHstDir = TerminalPath() + mqlDir +"\\files\\"+ mqlHstDir; // Verzeichnisname für Win32-Dateifunktionen
   string baseName, mqlFileName, fullFileName;
   int hFile, fileSize, sizeOfPeriods=ArraySize(periods), error;

   /*HISTORY_HEADER*/int hh[]; InitializeByteBuffer(hh, HISTORY_HEADER.size);
   hh.setFormat     (hh, format     );
   hh.setDescription(hh, description);
   hh.setSymbol     (hh, symbol     );
   hh.setDigits     (hh, digits     );

   for (i=0; i < sizeOfPeriods; i++) {
      baseName = symbol + periods[i] +".hst";
      mqlFileName  = mqlHstDir  + baseName;                             // Dateiname für MQL-Dateifunktionen
      fullFileName = fullHstDir + baseName;                             // Dateiname für Win32-Dateifunktionen

      if (IsFile(fullFileName)) {                                       // wenn Datei existiert, auf 0 zurücksetzen
         hFile = FileOpen(mqlFileName, FILE_BIN|FILE_WRITE);            // FileOpenHistory() kann Unterverzeichnisse nicht handhaben => alle Zugriffe per FileOpen(symlink)
         if (hFile <= 0) return(!catch("HistorySet.Create(5)  fileName=\""+ mqlFileName +"\"  hFile="+ hFile, ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR)));

         hh.setPeriod(hh, periods[i]);
         FileWriteArray(hFile, hh, 0, ArraySize(hh));                   // neuen HISTORY_HEADER schreiben
         FileClose(hFile);
         if (!catch("HistorySet.Create(6)"))
            continue;
         return(NULL);
      }
   }
   ArrayResize(hh, 0);


   // (4) neues HistorySet erzeugen
   size = Max(ArraySize(hs.hSet), 1) + 1;                               // minSize=2: auf Index[0] kann kein gültiges Handle liegen
   hs.__ResizeArrays(size);
   int iH   = size-1;
   int hSet = iH;                                                       // das Set-Handle entspricht jeweils dem Index in hs.*[]

   hs.hSet       [iH] = hSet;
   hs.symbol     [iH] = symbol;
   hs.symbolU    [iH] = symbolU;
   hs.description[iH] = description;
   hs.digits     [iH] = digits;
   hs.server     [iH] = server;
   hs.format     [iH] = format;


   // (5) ist das Instrument synthetisch, Symboldatensatz aktualisieren
   if (false) {
      // (5.1) "symgroups.raw": Symbolgruppe finden (ggf. anlegen)
      string groupName, prefix=StringLeft(symbolU, 3), suffix=StringRight(symbolU, 3);
      string accountStatSuffixes[] = {".EA", ".EX", ".LA", ".PL"};

      // Gruppe bestimmen und deren Index ermitteln
      bool isAccountStat = StringInArray(accountStatSuffixes, suffix);

      if (This.IsTesting()) {
         if (isAccountStat) groupName = "Tester Results";               // es können nur Testdaten sein
         else               groupName = "Tester Other";
      }
      else {
         if (isAccountStat) groupName = "Account Statistics";           // es können Accountdaten sein
         else               groupName = "Other";                        // es kann etwas anderes sein
      }

      // (5.2) "symbols.raw": Symboldatensatz über- bzw. neuschreiben
   }

   return(hSet);
}


/**
 * Schließt das HistorySet mit dem angegebenen Handle.
 *
 * @param  __IN__ int hSet  - Set-Handle
 *
 * @return bool - Erfolgsstatus
 */
bool HistorySet.Close(int hSet) {
   // Validierung
   if (hSet <= 0)                     return(!catch("HistorySet.Close(1)  invalid set handle "+ hSet, ERR_INVALID_PARAMETER));
   if (hSet != hs.hSet.lastValid) {
      if (hSet >= ArraySize(hs.hSet)) return(!catch("HistorySet.Close(2)  invalid set handle "+ hSet, ERR_INVALID_PARAMETER));
      if (hs.hSet[hSet] == 0)         return(!catch("HistorySet.Close(3)  unknown set handle "+ hSet, ERR_INVALID_PARAMETER));
   }
   else {
      hs.hSet.lastValid = NULL;
   }
   if (hs.hSet[hSet] < 0) return(true);                              // Handle wurde bereits geschlossen (kann ignoriert werden)

   int sizeOfPeriods = ArraySize(periods);

   for (int i=0; i < sizeOfPeriods; i++) {
      if (hs.hFile[hSet][i] > 0) {                                   // alle offenen Dateihandles schließen
         if (!HistoryFile.Close(hs.hFile[hSet][i])) return(false);
         hs.hFile[hSet][i] = -1;
      }
   }
   hs.hSet[hSet] = -1;
   return(true);
}


/**
 * Fügt dem HistorySet eines Symbols einen Tick hinzu. Der Tick wird als letzter Tick (Close) der entsprechenden Bar gespeichert.
 *
 * @param  __IN__ int      hSet  - Set-Handle des Symbols
 * @param  __IN__ datetime time  - Zeitpunkt des Ticks
 * @param  __IN__ double   value - Datenwert
 * @param  __IN__ int      flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                                 • HST_COLLECT_TICKS: sammelt aufeinanderfolgende Ticks und schreibt die Daten erst beim jeweils nächsten BarOpen-Event
 *                                 • HST_FILL_GAPS:     füllt entstehende Gaps mit dem letzten Schlußkurs vor dem Gap
 *
 * @return bool - Erfolgsstatus
 */
bool HistorySet.AddTick(int hSet, datetime time, double value, int flags=NULL) {
   // Validierung
   if (hSet <= 0)                     return(!catch("HistorySet.AddTick(1)  invalid parameter hSet = "+ hSet, ERR_INVALID_PARAMETER));
   if (hSet != hs.hSet.lastValid) {
      if (hSet >= ArraySize(hs.hSet)) return(!catch("HistorySet.AddTick(2)  invalid parameter hSet = "+ hSet, ERR_INVALID_PARAMETER));
      if (hs.hSet[hSet] == 0)         return(!catch("HistorySet.AddTick(3)  invalid parameter hSet = "+ hSet +" (unknown handle)", ERR_INVALID_PARAMETER));
      if (hs.hSet[hSet] <  0)         return(!catch("HistorySet.AddTick(4)  invalid parameter hSet = "+ hSet +" (closed handle)", ERR_INVALID_PARAMETER));
      hs.hSet.lastValid = hSet;
   }
   if (time <= 0)                     return(!catch("HistorySet.AddTick(5)  invalid parameter time = "+ time, ERR_INVALID_PARAMETER));

   // Dateihandles holen und jeweils Tick hinzufügen
   int hFile, sizeOfPeriods=ArraySize(periods);

   for (int i=0; i < sizeOfPeriods; i++) {
      hFile = hs.hFile[hSet][i];
      if (!hFile) {                                                  // noch ungeöffnete Dateien öffnen
         hFile = HistoryFile.Open(hs.symbol[hSet], periods[i], hs.description[hSet], hs.digits[hSet], hs.format[hSet], FILE_READ|FILE_WRITE, hs.server[hSet]);
         if (!hFile) return(false);
         hs.hFile[hSet][i] = hFile;
      }
      if (!HistoryFile.AddTick(hFile, time, value, flags)) return(false);
   }
   return(true);
}


/**
 * Öffnet eine Historydatei im angegeben Access-Mode und gibt deren Handle zurück.
 *
 * • Ist FILE_WRITE angegeben und die Datei existiert nicht, wird sie im angegebenen Format erstellt.
 * • Ist FILE_WRITE, nicht jedoch FILE_READ angegeben und die Datei existiert, wird sie zurückgesetzt und im angegebenen Format neu erstellt.
 *
 * @param  __IN__ string symbol      - Symbol des Instruments
 * @param  __IN__ int    timeframe   - Timeframe der Zeitreihe
 * @param  __IN__ string description - Beschreibung des Instruments (falls die Historydatei neu erstellt wird)
 * @param  __IN__ int    digits      - Digits der Werte             (falls die Historydatei neu erstellt wird)
 * @param  __IN__ int    format      - Datenformat der Zeitreihe    (falls die Historydatei neu erstellt wird)
 * @param  __IN__ int    mode        - Access-Mode: FILE_READ|FILE_WRITE
 * @param  __IN__ string server      - Name des Serververzeichnisses, in dem die Datei gespeichert wird (default: aktuelles Serververzeichnis)
 *
 * @return int - • Dateihandle oder
 *               • -1, falls nur FILE_READ angegeben wurde und die Datei nicht existiert oder
 *               • NULL, falls ein anderer Fehler auftrat
 *
 *
 * NOTES: (1) Das Dateihandle kann nicht modul-übergreifend verwendet werden.
 *        (2) Mit den MQL-Dateifunktionen können je Modul maximal 64 Dateien gleichzeitig offen gehalten werden.
 */
int HistoryFile.Open(string symbol, int timeframe, string description, int digits, int format, int mode, string server="") {
   // Validierung
   if (!StringLen(symbol))                    return(_NULL(catch("HistoryFile.Open(1)  illegal parameter symbol = "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER)));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(_NULL(catch("HistoryFile.Open(2)  illegal parameter symbol = "+ DoubleQuoteStr(symbol) +" (max "+ MAX_SYMBOL_LENGTH +" characters)", ERR_INVALID_PARAMETER)));
   string symbolU = StringToUpper(symbol);
   if (timeframe <= 0)                        return(_NULL(catch("HistoryFile.Open(3)  invalid parameter timeframe = "+ timeframe, ERR_INVALID_PARAMETER)));
   if (!(mode & (FILE_READ|FILE_WRITE)))      return(_NULL(catch("HistoryFile.Open(4)  invalid file access mode = "+ mode +" (needs to be FILE_READ and/or FILE_WRITE)", ERR_INVALID_PARAMETER)));
   mode &= (FILE_READ|FILE_WRITE);                                                  // alle übrigen gesetzten Bits löschen
   bool read_only  = !(mode &  FILE_WRITE);
   bool read_write =  (mode & (FILE_READ|FILE_WRITE) != 0);
   bool write_only = !(mode &  FILE_READ);
   if (server == "0")      server = "";                                             // (string) NULL
   if (!StringLen(server)) server = GetServerName();


   // (1) Datei öffnen
   string mqlDir       = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string mqlHstDir    = ".history\\"+ server +"\\";                                // Verzeichnisname für MQL-Dateifunktionen
   string fullHstDir   = TerminalPath() + mqlDir +"\\files\\"+ mqlHstDir;           // Verzeichnisname für Win32-Dateifunktionen
   string baseName     = symbol + timeframe +".hst";
   string mqlFileName  = mqlHstDir  + baseName;
   string fullFileName = fullHstDir + baseName;
   int    hFile        = FileOpen(mqlFileName, mode|FILE_BIN);                      // FileOpenHistory() kann Unterverzeichnisse nicht handhaben => alle Zugriffe per FileOpen(symlink)

   // (1.1) read-only                                                               // TODO: !!! Bei read-only Existenz mit IsFile() prüfen, da FileOpenHistory()
   if (read_only) {                                                                 // TODO: !!! sonst das Log ggf. mit Warnungen ERR_CANNOT_OPEN_FILE zupflastert !!!
      int error = GetLastError();
      if (error == ERR_CANNOT_OPEN_FILE) return(-1);                                // file not found
      if (hFile <= 0) return(_NULL(catch("HistoryFile.Open(5)->FileOpen(\""+ mqlFileName +"\", FILE_READ) => "+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR))));
   }

   // (1.2) read-write
   else if (read_write) {
      if (hFile <= 0) return(_NULL(catch("HistoryFile.Open(6)->FileOpen(\""+ mqlFileName +"\", FILE_READ|FILE_WRITE) => "+ hFile, ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR))));
   }

   // (1.3) write-only
   else if (write_only) {
      if (hFile <= 0) return(_NULL(catch("HistoryFile.Open(7)->FileOpen(\""+ mqlFileName +"\", FILE_WRITE) => "+ hFile, ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR))));
   }

   int bars, from, to, fileSize=FileSize(hFile), /*HISTORY_HEADER*/hh[]; InitializeByteBuffer(hh, HISTORY_HEADER.size);


   // (2) ggf. neuen HISTORY_HEADER schreiben
   if (write_only || (read_write && fileSize < HISTORY_HEADER.size)) {
      // Parameter validieren
      if (!StringLen(description))     description = "";                            // NULL-Pointer => Leerstring
      if (StringLen(description) > 63) description = StringLeft(description, 63);   // ein zu langer String wird gekürzt
      if (digits < 0)                          return(_NULL(catch("HistoryFile.Open(8)  invalid parameter digits = "+ digits, ERR_INVALID_PARAMETER)));
      if (format!=400) /*&&*/ if (format!=401) return(_NULL(catch("HistoryFile.Open(9)  invalid parameter format = "+ format +" (needs to be 400 or 401)", ERR_INVALID_PARAMETER)));

      hh.setFormat     (hh, format     );
      hh.setDescription(hh, description);
      hh.setSymbol     (hh, symbol     );
      hh.setPeriod     (hh, timeframe  );
      hh.setDigits     (hh, digits     );
      FileWriteArray(hFile, hh, 0, HISTORY_HEADER.intSize);
   }


   // (3.1) ggf. vorhandenen HISTORY_HEADER auslesen
   else if (read_only || fileSize > 0) {
      if (FileReadArray(hFile, hh, 0, HISTORY_HEADER.intSize) != HISTORY_HEADER.intSize) {
         FileClose(hFile);
         return(_NULL(catch("HistoryFile.Open(10)  invalid history file \""+ mqlFileName +"\" (size="+ fileSize +")", ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR))));
      }

      // (3.2) ggf. Bar-Infos auslesen
      if (fileSize > HISTORY_HEADER.size) {
         int barSize = ifInt(format==400, HISTORY_BAR_400.size, HISTORY_BAR_401.size);
         bars        = (fileSize-HISTORY_HEADER.size) / barSize;
         if (bars > 0) {
            from = FileReadInteger(hFile);
            FileSeek(hFile, HISTORY_HEADER.size + (bars-1)*barSize, SEEK_SET);
            to   = FileReadInteger(hFile);
         }
      }
   }


   // (4) Daten zwischenspeichern
   if (hFile >= ArraySize(hf.hFile))                                 // neues Datei-Handle: Arrays vergrößer
      hf.__ResizeArrays(hFile+1);                                    // andererseits von FileOpen() wiederverwendetes Handle

   hf.hFile                     [hFile]        = hFile;
   hf.name                      [hFile]        = baseName;
   hf.readAccess                [hFile]        = !write_only;
   hf.writeAccess               [hFile]        = !read_only;
   hf.size                      [hFile]        = fileSize;

   ArraySetInts(hf.header,       hFile,          hh);                // entspricht: hf.header[hFile] = hh;
   hf.format                    [hFile]        = hh.Format(hh);
   hf.symbol                    [hFile]        = hh.Symbol(hh);
   hf.symbolU                   [hFile]        = symbolU;
   hf.period                    [hFile]        = timeframe;
   hf.periodSecs                [hFile]        = timeframe * MINUTES;
   hf.digits                    [hFile]        = hh.Digits(hh);
   hf.server                    [hFile]        = server;

   hf.bars                      [hFile]        = bars;
   hf.from                      [hFile]        = from;
   hf.to                        [hFile]        = to;

   hf.currentBar.offset         [hFile]        = -1;                 // ggf. vorhandene Bardaten zurücksetzen: wichtig, da MQL die ID eines vorher geschlossenen Dateihandles
   hf.currentBar.openTime       [hFile]        =  0;                 // wiederverwenden kann
   hf.currentBar.closeTime      [hFile]        =  0;
   hf.currentBar.nextCloseTime  [hFile]        =  0;
   hf.currentBar.data           [hFile][BAR_T] =  0;
   hf.currentBar.data           [hFile][BAR_O] =  0;
   hf.currentBar.data           [hFile][BAR_H] =  0;
   hf.currentBar.data           [hFile][BAR_L] =  0;
   hf.currentBar.data           [hFile][BAR_C] =  0;
   hf.currentBar.data           [hFile][BAR_V] =  0;

   hf.collectedBar.offset       [hFile]        = -1;
   hf.collectedBar.openTime     [hFile]        =  0;
   hf.collectedBar.closeTime    [hFile]        =  0;
   hf.collectedBar.nextCloseTime[hFile]        =  0;
   hf.collectedBar.data         [hFile][BAR_T] =  0;
   hf.collectedBar.data         [hFile][BAR_O] =  0;
   hf.collectedBar.data         [hFile][BAR_H] =  0;
   hf.collectedBar.data         [hFile][BAR_L] =  0;
   hf.collectedBar.data         [hFile][BAR_C] =  0;
   hf.collectedBar.data         [hFile][BAR_V] =  0;

   ArrayResize(hh, 0);

   if (!catch("HistoryFile.Open(11)"))
      return(hFile);
   return(NULL);
}


/**
 * Schließt die Historydatei mit dem angegebenen Handle. Alle noch ungespeicherten Tickdaten werden geschrieben.
 * Die Datei muß vorher mit HistoryFile.Open() geöffnet worden sein.
 *
 * @param  __IN__ int hFile - Dateihandle
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile.Close(int hFile) {
   if (hFile <= 0)                      return(!catch("HistoryFile.Close(1)  invalid file handle "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile.Close(2)  unknown file handle "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile.Close(3)  unknown file handle "+ hFile, ERR_INVALID_PARAMETER));
   }
   else hf.hFile.lastValid = NULL;

   if (hf.hFile[hFile] < 0) return(true);                            // Handle wurde bereits geschlossen (kann ignoriert werden)


   // (1) alle ungespeicherten Ticks speichern
   if (hf.collectedBar.offset[hFile] != -1)
      if (!HistoryFile.WriteCollectedBar(hFile)) return(false);


   // (2) Datei schließen
   if (IsError(catch("HistoryFile.Close(4)"))) return(false);        // vor FileClose() alle evt. Fehler abfangen
   FileClose(hFile);
   hf.hFile[hFile] = -1;

   int error = GetLastError();
   if (!error)                         return(true);
   if (error == ERR_INVALID_PARAMETER) return(true);                 // Datei wurde bereits geschlossen (kann ignoriert werden)
   return(!catch("HistoryFile.Close(5)", error));
}


/**
 * Fügt einer einzelnen Historydatei einen Tick hinzu. Der Tick wird als letzter Tick (Close) der entsprechenden Bar gespeichert.
 *
 * @param  __IN__ int      hFile - Handle der Historydatei
 * @param  __IN__ datetime time  - Zeitpunkt des Ticks
 * @param  __IN__ double   value - Datenwert
 * @param  __IN__ int      flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                                 • HST_COLLECT_TICKS: sammelt aufeinanderfolgende Ticks und schreibt die Daten erst beim jeweils nächsten BarOpen-Event
 *                                 • HST_FILL_GAPS:     füllt entstehende Gaps mit dem letzten Schlußkurs vor dem Gap
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Zur Performancesteigerung werden die Tickdaten nicht zusätzlich validiert.
 */
bool HistoryFile.AddTick(int hFile, datetime time, double value, int flags=NULL) {
   // Validierung
   if (hFile <= 0)                      return(!catch("HistoryFile.AddTick(1)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile.AddTick(2)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile.AddTick(3)  invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile.AddTick(4)  invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (time <= 0)                       return(!catch("HistoryFile.AddTick(5)  invalid parameter time = "+ time, ERR_INVALID_PARAMETER));

   value = NormalizeDouble(value, hf.digits[hFile]);

   bool     barExists[1];
   int      offset, dow;
   datetime openTime, closeTime, nextCloseTime;
   double   bar[6];


   // (1) Tick ggf. sammeln -----------------------------------------------------------------------------------------------------------------------
   if (HST_COLLECT_TICKS & flags != 0) {
      if (time < hf.collectedBar.openTime[hFile] || time >= hf.collectedBar.closeTime[hFile]) {
         // (1.1) Collected-Bar leer oder Tick gehört zu neuer Bar (irgendwo dahinter)
         offset = HistoryFile.FindBar(hFile, time, flags, barExists); if (offset < 0) return(false);  // Offset der Bar, zu der der Tick gehört

         if (!hf.collectedBar.openTime[hFile]) {
            // (1.1.1) Collected-Bar leer
            if (barExists[0]) {                                                                       // Bar existiert: Initialisierung
               if (!HistoryFile.ReadBar(hFile, offset, bar)) return(false);                           // vorhandene Bar als Ausgangsbasis einlesen

               hf.collectedBar.data[hFile][BAR_T] =         bar[BAR_T];
               hf.collectedBar.data[hFile][BAR_O] =         bar[BAR_O];                               // Tick hinzufügen
               hf.collectedBar.data[hFile][BAR_H] = MathMax(bar[BAR_H], value);
               hf.collectedBar.data[hFile][BAR_L] = MathMin(bar[BAR_L], value);
               hf.collectedBar.data[hFile][BAR_C] =                     value;
               hf.collectedBar.data[hFile][BAR_V] =         bar[BAR_V] + 1;
            }
            else {
               hf.collectedBar.data[hFile][BAR_O] = value;                                            // Bar existiert nicht: neue Bar beginnen
               hf.collectedBar.data[hFile][BAR_H] = value;
               hf.collectedBar.data[hFile][BAR_L] = value;
               hf.collectedBar.data[hFile][BAR_C] = value;
               hf.collectedBar.data[hFile][BAR_V] = 1;
            }
         }
         else {
            // (1.1.2) Collected-Bar gefüllt und komplett
            if (hf.collectedBar.offset[hFile] >= hf.bars[hFile]) /*&&*/ if (!barExists[0])
               offset++;   // Wenn die Collected-Bar real noch nicht existiert, muß 'offset' vergrößert werden, falls die neue Bar ebenfalls nicht existiert.

            if (!HistoryFile.WriteCollectedBar(hFile, flags)) return(false);

            hf.collectedBar.data[hFile][BAR_O] = value;                                               // neue Bar beginnen
            hf.collectedBar.data[hFile][BAR_H] = value;
            hf.collectedBar.data[hFile][BAR_L] = value;
            hf.collectedBar.data[hFile][BAR_C] = value;
            hf.collectedBar.data[hFile][BAR_V] = 1;
         }

         if (hf.period[hFile] <= PERIOD_D1) {
            hf.collectedBar.openTime     [hFile] = time - time%hf.periodSecs[hFile];
            hf.collectedBar.closeTime    [hFile] = hf.collectedBar.openTime [hFile] + hf.periodSecs[hFile];
            hf.collectedBar.nextCloseTime[hFile] = hf.collectedBar.closeTime[hFile] + hf.periodSecs[hFile];
         }
         else if (hf.period[hFile] == PERIOD_W1) {
            openTime                             = time - time%DAYS - (TimeDayOfWeekFix(time)+6)%7*DAYS;    // 00:00, Montag
            hf.collectedBar.openTime     [hFile] = openTime;
            hf.collectedBar.closeTime    [hFile] = openTime +  7*DAYS;                                      // 00:00, Montag der nächsten Woche
            hf.collectedBar.nextCloseTime[hFile] = openTime + 14*DAYS;                                      // 00:00, Montag der übernächsten Woche
         }
         else if (hf.period[hFile] == PERIOD_MN1) {
            openTime                             = time - time%DAYS - (TimeDayFix(time)-1)*DAYS;            // 00:00, 1. des Monats
            hf.collectedBar.openTime     [hFile] = openTime;
            hf.collectedBar.closeTime    [hFile] = DateTime(TimeYearFix(openTime), TimeMonth(openTime)+1);  // 00:00, 1. des nächsten Monats
            hf.collectedBar.nextCloseTime[hFile] = DateTime(TimeYearFix(openTime), TimeMonth(openTime)+2);  // 00:00, 1. des übernächsten Monats
         }

         hf.collectedBar.offset[hFile]        = offset;
         hf.collectedBar.data  [hFile][BAR_T] = hf.collectedBar.openTime[hFile];
      }
      else {
         // (1.2) Tick gehört zur Collected-Bar
       //hf.collectedBar.data[hFile][BAR_T] = ...                                               // unverändert
       //hf.collectedBar.data[hFile][BAR_O] = ...                                               // unverändert
         hf.collectedBar.data[hFile][BAR_H] = MathMax(hf.collectedBar.data[hFile][BAR_H], value);
         hf.collectedBar.data[hFile][BAR_L] = MathMin(hf.collectedBar.data[hFile][BAR_L], value);
         hf.collectedBar.data[hFile][BAR_C] = value;
         hf.collectedBar.data[hFile][BAR_V]++;
      }
      return(true);
   } // end if (HST_COLLECT_TICKS)


   // (2) gefüllte Collected-Bar schreiben --------------------------------------------------------------------------------------------------------
   if (hf.collectedBar.offset[hFile] >= 0) {                                                    // HST_COLLECT_TICKS wechselte zur Laufzeit
      bool tick_in_collectedBar = (time >= hf.collectedBar.openTime[hFile] && time < hf.collectedBar.closeTime[hFile]);
      if (tick_in_collectedBar) {
       //hf.collectedBar.data[hFile][BAR_T] = ... (unverändert)                                 // Tick zur Collected-Bar hinzufügen
       //hf.collectedBar.data[hFile][BAR_O] = ... (unverändert)
         hf.collectedBar.data[hFile][BAR_H] = MathMax(hf.collectedBar.data[hFile][BAR_H], value);
         hf.collectedBar.data[hFile][BAR_L] = MathMin(hf.collectedBar.data[hFile][BAR_L], value);
         hf.collectedBar.data[hFile][BAR_C] = value;
         hf.collectedBar.data[hFile][BAR_V]++;
      }
      if (!HistoryFile.WriteCollectedBar(hFile, flags)) return(false);                          // Collected-Bar schreiben (unwichtig, ob komplett, da HST_COLLECT_TICKS=Off)

      hf.collectedBar.offset       [hFile] = -1;                                                // Collected-Bar zurücksetzen
      hf.collectedBar.openTime     [hFile] =  0;
      hf.collectedBar.closeTime    [hFile] =  0;
      hf.collectedBar.nextCloseTime[hFile] =  0;

      if (tick_in_collectedBar)
         return(true);
   }


   // (3) Tick schreiben --------------------------------------------------------------------------------------------------------------------------
   if      (hf.period[hFile] <= PERIOD_D1 ) openTime = time - time%hf.periodSecs[hFile];                                // OpenTime der entsprechenden Bar ermitteln
   else if (hf.period[hFile] == PERIOD_W1 ) openTime = time - time%DAYS - (TimeDayOfWeekFix(time)+6)%7*DAYS;            // 00:00, Montag
   else if (hf.period[hFile] == PERIOD_MN1) openTime = time - time%DAYS - (TimeDayFix(time)-1)*DAYS;                    // 00:00, 1. des Monats

   offset = HistoryFile.FindBar(hFile, openTime, flags|HST_IS_BAR_OPENTIME, barExists); if (offset < 0) return(false);  // Offset der entsprechenden Bar ermitteln
   if (barExists[0])                                                                                                    // existierende Bar aktualisieren...
      return(HistoryFile.UpdateBar(hFile, offset, value));

   bar[BAR_T] = openTime;                                                                                               // ...oder neue Bar einfügen
   bar[BAR_O] = value;
   bar[BAR_H] = value;
   bar[BAR_L] = value;
   bar[BAR_C] = value;
   bar[BAR_V] = 1;
   return(HistoryFile.InsertBar(hFile, offset, bar, flags|HST_IS_BAR_OPENTIME));
}


/**
 * Findet in einer Historydatei den Offset der Bar, die den angegebenen Zeitpunkt abdeckt oder abdecken würde, und signalisiert, ob diese Bar
 * bereits existiert. Die Bar existiert z.B. nicht, wenn die Zeitreihe am angegebenen Zeitpunkt eine Lücke aufweist oder wenn der Zeitpunkt
 * außerhalb des von den vorhandenen Daten abgedeckten Bereichs liegt.
 *
 * @param  __IN__  int      hFile          - Handle der Historydatei
 * @param  __IN__  datetime time           - Zeitpunkt
 * @param  __IN__  int      flags          - das Auffinden der Bar steuernde Flags (default: keine)
 *                                           • HST_IS_BAR_OPENTIME: die angegebene Zeit ist die Bar-OpenTime und muß nicht mehr normalisiert werden
 * @param  __OUT__ bool     lpBarExists[1] - Variable, die nach Rückkehr anzeigt, ob die Bar am zurückgegebenen Offset existiert
 *                                           (als Array implementiert, um Zeigerübergabe an eine Library zu ermöglichen)
 *                                           • TRUE:  Bar existiert       (zum Aktualisieren dieser Bar muß HistoryFile.UpdateBar() verwendet werden)
 *                                           • FALSE: Bar existiert nicht (zum Aktualisieren dieser Bar muß HistoryFile.InsertBar() verwendet werden)
 *
 * @return int - Bar-Offset (älteste Bar hat Offset 0) oder -1 (EMPTY), falls ein Fehler auftrat
 */
int HistoryFile.FindBar(int hFile, datetime time, int flags, bool &lpBarExists[]) {
   if (hFile <= 0)                      return(_EMPTY(catch("HistoryFile.FindBar(1)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_EMPTY(catch("HistoryFile.FindBar(2)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] == 0)         return(_EMPTY(catch("HistoryFile.FindBar(3)  invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <  0)         return(_EMPTY(catch("HistoryFile.FindBar(4)  invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_PARAMETER)));
      hf.hFile.lastValid = hFile;
   }
   if (time <= 0)                       return(_EMPTY(catch("HistoryFile.FindBar(5)  invalid parameter time = "+ time, ERR_INVALID_PARAMETER)));
   if (ArraySize(lpBarExists) == 0)
      ArrayResize(lpBarExists, 1);


   // (1) normalisierte BarOpenTime ermitteln
   datetime openTime = time;
   if (!(HST_IS_BAR_OPENTIME & flags)) {
      if      (hf.period[hFile] <= PERIOD_D1 ) openTime = time - time%hf.periodSecs[hFile];
      else if (hf.period[hFile] == PERIOD_W1 ) openTime = time - time%DAYS - (TimeDayOfWeekFix(time)+6)%7*DAYS; // 00:00, Montag
      else if (hf.period[hFile] == PERIOD_MN1) openTime = time - time%DAYS - (TimeDayFix(time)-1)*DAYS;         // 00:00, 1. des Monats
   }

   // (2) Zeitpunkt wird von der letzten Bar abgedeckt         // die beiden am häufigsten auftretenden Fälle zu Beginn prüfen
   if (openTime == hf.to[hFile]) {
      lpBarExists[0] = true;
      return(hf.bars[hFile] - 1);
   }

   // (3) Zeitpunkt würde von der nächsten Bar abgedeckt       // die beiden am häufigsten auftretenden Fälle zu Beginn prüfen
   if (openTime > hf.to[hFile]) {
      lpBarExists[0] = false;
      return(hf.bars[hFile]);                                  // zum Einfügen an diesem Offset müßte die Datei vergrößert werden
   }

   // (4) History leer
   if (!hf.bars[hFile]) {
      lpBarExists[0] = false;
      return(0);                                               // zum Einfügen an Offset 0 müßte die Datei vergrößert werden
   }

   // (5) Zeitpunkt wird von der ersten Bar abgedeckt
   if (openTime == hf.from[hFile]) {
      lpBarExists[0] = true;
      return(0);
   }

   // (6) Zeitpunkt liegt zeitlich vor der ersten Bar
   if (openTime < hf.from[hFile]) {
      lpBarExists[0] = false;
      return(0);                                               // neue Bar müßte an Offset 0 eingefügt werden
   }

   // (7) Zeitpunkt liegt irgendwo innerhalb der Zeitreihe
   int offset;
   return(_EMPTY(catch("HistoryFile.FindBar(6|symbol="+ hf.symbol[hFile]+", period="+ PeriodDescription(hf.period[hFile]) +", bars="+ hf.bars[hFile] +", from='"+ TimeToStr(hf.from[hFile], TIME_FULL) +"', to='"+ TimeToStr(hf.to[hFile], TIME_FULL) +"')  Suche nach time='"+ TimeToStr(time, TIME_FULL) +"' innerhalb der Zeitreihe noch nicht implementiert", ERR_NOT_IMPLEMENTED)));

   if (!catch("HistoryFile.FindBar(7)"))
      return(offset);
   return(EMPTY);
}


/**
 * Liest die Bar am angegebenen Offset einer Historydatei.
 *
 * @param  __IN__  int    hFile  - Handle der Historydatei
 * @param  __IN__  int    offset - Offset der Bar (relativ zum History-Header; Offset 0 ist älteste Bar)
 * @param  __OUT__ double bar[6] - Array zur Aufnahme der Bar-Daten (TOHLCV)
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile.ReadBar(int hFile, int offset, double &bar[]) {
   if (hFile <= 0)                             return(!catch("HistoryFile.ReadBar(1)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile))        return(!catch("HistoryFile.ReadBar(2)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)                return(!catch("HistoryFile.ReadBar(3)  invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)                return(!catch("HistoryFile.ReadBar(4)  invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (offset < 0 || offset >= hf.bars[hFile]) return(!catch("HistoryFile.ReadBar(5)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER));
   if (ArraySize(bar) != 6) ArrayResize(bar, 6);


   // (1) FilePointer positionieren
   int barSize  = ifInt(hf.format[hFile]==400, HISTORY_BAR_400.size, HISTORY_BAR_401.size);
   int position = HISTORY_HEADER.size + offset*barSize;
   if (!FileSeek(hFile, position, SEEK_SET))   return(!catch("HistoryFile.ReadBar(6)"));


   // (2) Bar je nach Format lesen
   if (hf.format[hFile] == 400) {
      bar[BAR_T] = FileReadInteger(hFile);
      bar[BAR_O] = FileReadDouble (hFile);
      bar[BAR_L] = FileReadDouble (hFile);
      bar[BAR_H] = FileReadDouble (hFile);
      bar[BAR_C] = FileReadDouble (hFile);
      bar[BAR_V] = FileReadDouble (hFile);
   }
   else {               // 401
      bar[BAR_T] = FileReadInteger(hFile);      // int64
                   FileReadInteger(hFile);
      bar[BAR_O] = FileReadDouble (hFile);
      bar[BAR_H] = FileReadDouble (hFile);
      bar[BAR_L] = FileReadDouble (hFile);
      bar[BAR_C] = FileReadDouble (hFile);
      bar[BAR_V] = FileReadInteger(hFile);      // uint64: ticks
   }


   // (3) Bar normalisieren
   int digits = hf.digits[hFile];
   bar[BAR_O] = NormalizeDouble(bar[BAR_O], digits);
   bar[BAR_H] = NormalizeDouble(bar[BAR_H], digits);
   bar[BAR_L] = NormalizeDouble(bar[BAR_L], digits);
   bar[BAR_C] = NormalizeDouble(bar[BAR_C], digits);
   bar[BAR_V] =            _int(bar[BAR_V]        );


   // (4) CloseTime/NextCloseTime der Bar ermitteln
   datetime closeTime, nextCloseTime, openTime=bar[BAR_T];
   if (hf.period[hFile] <= PERIOD_D1) {
      closeTime     = openTime  + hf.periodSecs[hFile];
      nextCloseTime = closeTime + hf.periodSecs[hFile];
   }
   else if (hf.period[hFile] == PERIOD_W1) {
      closeTime     = openTime +  7*DAYS;                                        // 00:00, Montag der nächsten Woche
      nextCloseTime = openTime + 14*DAYS;                                        // 00:00, Montag der übernächsten Woche
   }
   else if (hf.period[hFile] == PERIOD_MN1) {
      closeTime     = DateTime(TimeYearFix(openTime), TimeMonth(openTime)+1);    // 00:00, 1. des nächsten Monats
      nextCloseTime = DateTime(TimeYearFix(openTime), TimeMonth(openTime)+2);    // 00:00, 1. des übernächsten Monats
   }


   // (5) CurrentBar-Cache aktualisieren
   hf.currentBar.offset       [hFile]        = offset;
   hf.currentBar.openTime     [hFile]        = openTime;
   hf.currentBar.closeTime    [hFile]        = closeTime;
   hf.currentBar.nextCloseTime[hFile]        = nextCloseTime;
   hf.currentBar.data         [hFile][BAR_T] = bar[BAR_T];
   hf.currentBar.data         [hFile][BAR_O] = bar[BAR_O];
   hf.currentBar.data         [hFile][BAR_H] = bar[BAR_H];
   hf.currentBar.data         [hFile][BAR_L] = bar[BAR_L];
   hf.currentBar.data         [hFile][BAR_C] = bar[BAR_C];
   hf.currentBar.data         [hFile][BAR_V] = bar[BAR_V];

   return(!catch("HistoryFile.ReadBar(7)"));
}


/**
 * Aktualisiert den Schlußkurs der Bar am angegebenen Offset einer Historydatei.
 *
 * @param  __IN__ int    hFile  - Handle der Historydatei
 * @param  __IN__ int    offset - Offset der zu aktualisierenden Bar innerhalb der Zeitreihe
 * @param  __IN__ double value  - hinzuzufügender Wert
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Zur Performancesteigerung werden die Tickdaten nicht zusätzlich validiert.
 */
bool HistoryFile.UpdateBar(int hFile, int offset, double value) {
   if (hFile <= 0)                             return(!catch("HistoryFile.UpdateBar(1)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile))        return(!catch("HistoryFile.UpdateBar(2)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)                return(!catch("HistoryFile.UpdateBar(3)  invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)                return(!catch("HistoryFile.UpdateBar(4)  invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (offset < 0 || offset >= hf.bars[hFile]) return(!catch("HistoryFile.UpdateBar(5)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER));

   value = NormalizeDouble(value, hf.digits[hFile]);


   // (1) Bar ggf. neu einlesen...
   if (hf.currentBar.offset[hFile] != offset) {
      double bar[6];
      if (!HistoryFile.ReadBar(hFile, offset, bar)) return(false);            // aktualisiert alle hf.currentBar.*-Variablen
   }

   // (2) CurrentBar-Cache aktualisieren
 //hf.currentBar.data[hFile][BAR_T] = ...                                     // unverändert
 //hf.currentBar.data[hFile][BAR_O] = ...                                     // unverändert
   hf.currentBar.data[hFile][BAR_H] = MathMax(hf.currentBar.data[hFile][BAR_H], value);
   hf.currentBar.data[hFile][BAR_L] = MathMin(hf.currentBar.data[hFile][BAR_L], value);
   hf.currentBar.data[hFile][BAR_C] = value;
   hf.currentBar.data[hFile][BAR_V]++;

   // (3) CurrentBar-Cache schreiben
   return(HistoryFile.WriteCurrentBar(hFile));
}


/**
 * Fügt eine neue Bar am angegebenen Offset einer Historydatei ein. Die Funktion überprüft *nicht* die Plausibilität der einzufügenden Daten.
 *
 * @param  __IN__ int    hFile  - Handle der Historydatei
 * @param  __IN__ int    offset - Offset der einzufügenden Bar innerhalb der Zeitreihe (die erste Bar hat den Offset 0)
 * @param  __IN__ double bar[6] - Bardaten
 * @param  __IN__ int    flags  - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                                • HST_FILL_GAPS:       beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
 *                                • HST_IS_BAR_OPENTIME: die angegebene Zeit ist die Bar-OpenTime und muß nicht mehr normalisiert werden
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Zur Performancesteigerung werden die Tickdaten nicht zusätzlich validiert.
 */
bool HistoryFile.InsertBar(int hFile, int offset, double bar[], int flags=NULL) {
   if (hFile <= 0)                      return(!catch("HistoryFile.InsertBar(1)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile.InsertBar(2)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile.InsertBar(3)  invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile.InsertBar(4)  invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (offset < 0)                      return(!catch("HistoryFile.InsertBar(5)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER));
   if (ArraySize(bar) != 6)             return(!catch("HistoryFile.InsertBar(6)  invalid size of parameter data[] = "+ ArraySize(bar), ERR_INCOMPATIBLE_ARRAYS));


   // (1) ggf. Lücke für neue Bar schaffen
   if (offset < hf.bars[hFile])
      if (!HistoryFile.MoveBars(hFile, offset, offset+1)) return(false);

   // (2) Bar schreiben
   return(HistoryFile.WriteBar(hFile, offset, bar, flags));
}


/**
 * Schreibt eine Bar in die angegebene Historydatei. Eine ggf. vorhandene Bar mit demselben Open-Zeitpunkt wird überschrieben.
 *
 * @param  __IN__ int    hFile  - Handle der Historydatei
 * @param  __IN__ int    offset - Offset der zu schreibenden Bar (relativ zum Dateiheader; Offset 0 ist die älteste Bar)
 * @param  __IN__ double bar[]  - Bar-Daten (T-OHLCV)
 * @param  __IN__ int    flags  - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                                • HST_FILL_GAPS:       beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
 *                                • HST_IS_BAR_OPENTIME: die angegebene Zeit ist die Bar-OpenTime und muß nicht mehr normalisiert werden
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Zur Performancesteigerung werden die Bardaten nicht zusätzlich validiert.
 */
bool HistoryFile.WriteBar(int hFile, int offset, double bar[], int flags=NULL) {
   if (hFile <= 0)                      return(!catch("HistoryFile.WriteBar(1)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile.WriteBar(2)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile.WriteBar(3)  invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile.WriteBar(4)  invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (offset < 0)                      return(!catch("HistoryFile.WriteBar(5)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER));
   if (ArraySize(bar) != 6)             return(!catch("HistoryFile.WriteBar(6)  invalid size of parameter data[] = "+ ArraySize(bar), ERR_INCOMPATIBLE_ARRAYS));


   // (1) OpenTime/CloseTime/NextCloseTime der Bar ermitteln
   datetime openTime, closeTime, nextCloseTime, time=bar[BAR_T];
   if    (HST_IS_BAR_OPENTIME & flags != 0) openTime = time;
   else if (hf.period[hFile] <= PERIOD_D1 ) openTime = time - time%hf.periodSecs[hFile];
   else if (hf.period[hFile] == PERIOD_W1 ) openTime = time - time%DAYS - (TimeDayOfWeekFix(time)+6)%7*DAYS;   // 00:00, Montag
   else if (hf.period[hFile] == PERIOD_MN1) openTime = time - time%DAYS - (TimeDayFix(time)-1)*DAYS;           // 00:00, 1. des Monats

   if (hf.period[hFile] <= PERIOD_D1) {
      closeTime     = openTime  + hf.periodSecs[hFile];
      nextCloseTime = closeTime + hf.periodSecs[hFile];
   }
   else if (hf.period[hFile] == PERIOD_W1) {
      closeTime     = openTime +  7*DAYS;                                                                      // 00:00, Montag der nächsten Woche
      nextCloseTime = openTime + 14*DAYS;                                                                      // 00:00, Montag der übernächsten Woche
   }
   else if (hf.period[hFile] == PERIOD_MN1) {
      closeTime     = DateTime(TimeYearFix(openTime), TimeMonth(openTime)+1);                                  // 00:00, 1. des nächsten Monats
      nextCloseTime = DateTime(TimeYearFix(openTime), TimeMonth(openTime)+2);                                  // 00:00, 1. des übernächsten Monats
   }


   // (2) FilePointer positionieren
   int barSize  = ifInt(hf.format[hFile]==400, HISTORY_BAR_400.size, HISTORY_BAR_401.size);
   int position = HISTORY_HEADER.size + offset*barSize;
   if (!FileSeek(hFile, position, SEEK_SET)) return(!catch("HistoryFile.WriteBar(7)"));


   // (3) Bardaten normalisieren (Funktionsparameter nicht modifizieren)
   int digits = hf.digits[hFile];
   double O = NormalizeDouble(bar[BAR_O], digits);
   double H = NormalizeDouble(bar[BAR_H], digits);
   double L = NormalizeDouble(bar[BAR_L], digits);
   double C = NormalizeDouble(bar[BAR_C], digits);
   int    V =                 bar[BAR_V];


   // (4) Bardaten schreiben
   if (hf.format[hFile] == 400) {
      FileWriteInteger(hFile, openTime);
      FileWriteDouble (hFile, O       );
      FileWriteDouble (hFile, L       );
      FileWriteDouble (hFile, H       );
      FileWriteDouble (hFile, C       );
      FileWriteDouble (hFile, V       );
   }
   else {               // 401
      FileWriteInteger(hFile, openTime);        // int64
      FileWriteInteger(hFile, 0       );
      FileWriteDouble (hFile, O       );
      FileWriteDouble (hFile, H       );
      FileWriteDouble (hFile, L       );
      FileWriteDouble (hFile, C       );
      FileWriteInteger(hFile, V       );        // uint64: ticks
      FileWriteInteger(hFile, 0       );
      FileWriteInteger(hFile, 0       );        // int:    spread
      FileWriteInteger(hFile, 0       );        // uint64: real_volume
      FileWriteInteger(hFile, 0       );
   }


   // (5) interne Daten aktualisieren
   if (offset >= hf.bars[hFile]) { hf.size                    [hFile]        = position + barSize;
                                   hf.bars                    [hFile]        = offset + 1; }
   if (offset == 0)                hf.from                    [hFile]        = openTime;
   if (offset == hf.bars[hFile]-1) hf.to                      [hFile]        = openTime;

                                   hf.currentBar.offset       [hFile]        = offset;
                                   hf.currentBar.openTime     [hFile]        = openTime;
                                   hf.currentBar.closeTime    [hFile]        = closeTime;
                                   hf.currentBar.nextCloseTime[hFile]        = nextCloseTime;
                                   hf.currentBar.data         [hFile][BAR_T] = openTime;
                                   hf.currentBar.data         [hFile][BAR_O] = O;
                                   hf.currentBar.data         [hFile][BAR_H] = H;
                                   hf.currentBar.data         [hFile][BAR_L] = L;
                                   hf.currentBar.data         [hFile][BAR_C] = C;
                                   hf.currentBar.data         [hFile][BAR_V] = V;

   return(!catch("HistoryFile.WriteBar(8)"));
}


/**
 * Schreibt die aktuellen Bardaten in die Historydatei.
 *
 * @param  __IN__ int hFile - Handle der Historydatei
 * @param  __IN__ int flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                            • HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile.WriteCurrentBar(int hFile, int flags=NULL) {
   if (hFile <= 0)                      return(!catch("HistoryFile.WriteCurrentBar(1)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile.WriteCurrentBar(2)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile.WriteCurrentBar(3)  invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile.WriteCurrentBar(4)  invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }

   datetime time   = hf.currentBar.openTime[hFile];
   int      offset = hf.currentBar.offset  [hFile];
   if (offset < 0)                      return(!catch("HistoryFile.WriteCurrentBar(5)  invalid hf.currentBar.offset["+ hFile +"] value = "+ offset, ERR_RUNTIME_ERROR));


   // (1) FilePointer positionieren
   int barSize  = ifInt(hf.format[hFile]==400, HISTORY_BAR_400.size, HISTORY_BAR_401.size);
   int position = HISTORY_HEADER.size + offset*barSize;
   if (!FileSeek(hFile, position, SEEK_SET)) return(!catch("HistoryFile.WriteCurrentBar(6)"));


   // (2) Bar normalisieren
   int digits = hf.digits[hFile];
   hf.currentBar.data[hFile][BAR_O] = NormalizeDouble(hf.currentBar.data[hFile][BAR_O], digits);
   hf.currentBar.data[hFile][BAR_H] = NormalizeDouble(hf.currentBar.data[hFile][BAR_H], digits);
   hf.currentBar.data[hFile][BAR_L] = NormalizeDouble(hf.currentBar.data[hFile][BAR_L], digits);
   hf.currentBar.data[hFile][BAR_C] = NormalizeDouble(hf.currentBar.data[hFile][BAR_C], digits);
   hf.currentBar.data[hFile][BAR_V] =            _int(hf.currentBar.data[hFile][BAR_V]        );


   // (3) Bar schreiben
   if (hf.format[hFile] == 400) {
      FileWriteInteger(hFile, time                            );
      FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_O]);
      FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_L]);
      FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_H]);
      FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_C]);
      FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_V]);
   }
   else {
      FileWriteInteger(hFile, time                            );     // int64
      FileWriteInteger(hFile, 0                               );
      FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_O]);
      FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_H]);
      FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_L]);
      FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_C]);
      FileWriteInteger(hFile, hf.currentBar.data[hFile][BAR_V]);     // uint64: ticks
      FileWriteInteger(hFile, 0                               );
      FileWriteInteger(hFile, 0                               );     // int:    spread
      FileWriteInteger(hFile, 0                               );     // uint64: volume
      FileWriteInteger(hFile, 0                               );
   }


   // (4) interne Daten aktualisieren
   if (offset >= hf.bars[hFile]) { hf.size[hFile] = position + barSize;
                                   hf.bars[hFile] = offset + 1; }
   if (offset == 0)                hf.from[hFile] = time;
   if (offset == hf.bars[hFile]-1) hf.to  [hFile] = time;

   return(!catch("HistoryFile.WriteCurrentBar(7)"));
}


/**
 * Schreibt die zwischengespeicherten Tickdaten in die Historydatei.
 *
 * @param  __IN__ int hFile - Handle der Historydatei
 * @param  __IN__ int flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                            • HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile.WriteCollectedBar(int hFile, int flags=NULL) {
   if (hFile <= 0)                      return(!catch("HistoryFile.WriteCollectedBar(1)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile.WriteCollectedBar(2)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile.WriteCollectedBar(3)  invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile.WriteCollectedBar(4)  invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }

   datetime time   = hf.collectedBar.openTime[hFile];
   int      offset = hf.collectedBar.offset  [hFile];
   if (offset < 0)                      return(!catch("HistoryFile.WriteCollectedBar(5)  invalid hf.collectedBar.offset["+ hFile +"] value = "+ offset, ERR_RUNTIME_ERROR));


   // (1) FilePointer positionieren
   int barSize  = ifInt(hf.format[hFile]==400, HISTORY_BAR_400.size, HISTORY_BAR_401.size);
   int position = HISTORY_HEADER.size + offset*barSize;
   if (!FileSeek(hFile, position, SEEK_SET)) return(!catch("HistoryFile.WriteCollectedBar(6)"));


   // (2) Bar normalisieren
   int digits = hf.digits[hFile];
   hf.collectedBar.data[hFile][BAR_O] = NormalizeDouble(hf.collectedBar.data[hFile][BAR_O], digits);
   hf.collectedBar.data[hFile][BAR_H] = NormalizeDouble(hf.collectedBar.data[hFile][BAR_H], digits);
   hf.collectedBar.data[hFile][BAR_L] = NormalizeDouble(hf.collectedBar.data[hFile][BAR_L], digits);
   hf.collectedBar.data[hFile][BAR_C] = NormalizeDouble(hf.collectedBar.data[hFile][BAR_C], digits);
   hf.collectedBar.data[hFile][BAR_V] =            _int(hf.collectedBar.data[hFile][BAR_V]        );


   // (3) Bar schreiben
   if (hf.format[hFile] == 400) {
      FileWriteInteger(hFile, time                              );
      FileWriteDouble (hFile, hf.collectedBar.data[hFile][BAR_O]);
      FileWriteDouble (hFile, hf.collectedBar.data[hFile][BAR_L]);
      FileWriteDouble (hFile, hf.collectedBar.data[hFile][BAR_H]);
      FileWriteDouble (hFile, hf.collectedBar.data[hFile][BAR_C]);
      FileWriteDouble (hFile, hf.collectedBar.data[hFile][BAR_V]);
   }
   else {
      FileWriteInteger(hFile, time                              );      // int64
      FileWriteInteger(hFile, 0                                 );
      FileWriteDouble (hFile, hf.collectedBar.data[hFile][BAR_O]);
      FileWriteDouble (hFile, hf.collectedBar.data[hFile][BAR_H]);
      FileWriteDouble (hFile, hf.collectedBar.data[hFile][BAR_L]);
      FileWriteDouble (hFile, hf.collectedBar.data[hFile][BAR_C]);
      FileWriteInteger(hFile, hf.collectedBar.data[hFile][BAR_V]);      // uint64: ticks
      FileWriteInteger(hFile, 0                                 );
      FileWriteInteger(hFile, 0                                 );      // int:    spread
      FileWriteInteger(hFile, 0                                 );      // uint64: volume
      FileWriteInteger(hFile, 0                                 );
   }


   // (4) interne Daten aktualisieren
   if (offset >= hf.bars[hFile]) { hf.size                    [hFile]        = position + barSize;
                                   hf.bars                    [hFile]        = offset + 1; }
   if (offset == 0)                hf.from                    [hFile]        = time;
   if (offset == hf.bars[hFile]-1) hf.to                      [hFile]        = time;

                                   // Das Schreiben macht die Collected-Bar zusätzlich zur aktuellen Bar.
                                   hf.currentBar.offset       [hFile]        = hf.collectedBar.offset       [hFile];
                                   hf.currentBar.openTime     [hFile]        = hf.collectedBar.openTime     [hFile];
                                   hf.currentBar.closeTime    [hFile]        = hf.collectedBar.closeTime    [hFile];
                                   hf.currentBar.nextCloseTime[hFile]        = hf.collectedBar.nextCloseTime[hFile];
                                   hf.currentBar.data         [hFile][BAR_T] = hf.collectedBar.data         [hFile][BAR_T];
                                   hf.currentBar.data         [hFile][BAR_O] = hf.collectedBar.data         [hFile][BAR_O];
                                   hf.currentBar.data         [hFile][BAR_H] = hf.collectedBar.data         [hFile][BAR_H];
                                   hf.currentBar.data         [hFile][BAR_L] = hf.collectedBar.data         [hFile][BAR_L];
                                   hf.currentBar.data         [hFile][BAR_C] = hf.collectedBar.data         [hFile][BAR_C];
                                   hf.currentBar.data         [hFile][BAR_V] = hf.collectedBar.data         [hFile][BAR_V];

   return(!catch("HistoryFile.WriteCollectedBar(7)"));
}


/**
 *
 * @param  __IN__ int hFile       - Handle der Historydatei
 * @param  __IN__ int startOffset
 * @param  __IN__ int destOffset
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile.MoveBars(int hFile, int startOffset, int destOffset) {
   return(!catch("HistoryFile.MoveBars(1)", ERR_NOT_IMPLEMENTED));
}


/**
 * Setzt die Größe der internen HistorySet-Datenarrays auf den angegebenen Wert.
 *
 * @param  int size - neue Größe
 *
 * @return int - neue Größe der Arrays
 *
 * @private
 */
int hs.__ResizeArrays(int size) {
   if (size != ArraySize(hs.hSet)) {
      ArrayResize(hs.hSet,        size);
      ArrayResize(hs.symbol,      size);
      ArrayResize(hs.symbolU,     size);
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
 * @private
 */
int hf.__ResizeArrays(int size) {
   int oldSize = ArraySize(hf.hFile);

   if (size != oldSize) {
      ArrayResize(hf.hFile,                      size);
      ArrayResize(hf.name,                       size);
      ArrayResize(hf.readAccess,                 size);
      ArrayResize(hf.writeAccess,                size);
      ArrayResize(hf.size,                       size);

      ArrayResize(hf.header,                     size);
      ArrayResize(hf.format,                     size);
      ArrayResize(hf.symbol,                     size);
      ArrayResize(hf.symbolU,                    size);
      ArrayResize(hf.period,                     size);
      ArrayResize(hf.periodSecs,                 size);
      ArrayResize(hf.digits,                     size);
      ArrayResize(hf.server,                     size);

      ArrayResize(hf.bars,                       size);
      ArrayResize(hf.from,                       size);
      ArrayResize(hf.to,                         size);

      ArrayResize(hf.currentBar.offset,          size);
      ArrayResize(hf.currentBar.openTime,        size);
      ArrayResize(hf.currentBar.closeTime,       size);
      ArrayResize(hf.currentBar.nextCloseTime,   size);
      ArrayResize(hf.currentBar.data,            size);

      ArrayResize(hf.collectedBar.offset,        size);
      ArrayResize(hf.collectedBar.openTime,      size);
      ArrayResize(hf.collectedBar.closeTime,     size);
      ArrayResize(hf.collectedBar.nextCloseTime, size);
      ArrayResize(hf.collectedBar.data,          size);

      for (int i=size-1; i >= oldSize; i--) {                        // falls Arrays vergrößert werden, neue Offsets initialisieren
         hf.currentBar.offset  [i] = -1;
         hf.collectedBar.offset[i] = -1;
      }
   }
   return(size);
}


/**
 * Gibt den Namen der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return string - Dateiname oder Leerstring, falls ein Fehler auftrat
 */
string hf.Name(int hFile) {
   if (hFile <= 0)                      return(_EMPTY_STR(catch("hf.Name(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_EMPTY_STR(catch("hf.Name(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_EMPTY_STR(catch("hf.Name(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_EMPTY_STR(catch("hf.Name(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.lastValid = hFile;
   }
   return(hf.name[hFile]);
}


/**
 * Ob das Handle einer Historydatei Lesezugriff erlaubt.
 *
 * @param  int hFile - Dateihandle
 *
 * @return bool - Ergebnis oder FALSE, falls ein Fehler auftrat
 */
bool hf.ReadAccess(int hFile) {
   if (hFile <= 0)                      return(!catch("hf.ReadAccess(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("hf.ReadAccess(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(!catch("hf.ReadAccess(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR));
                                        return(!catch("hf.ReadAccess(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR));
      }
      hf.hFile.lastValid = hFile;
   }
   return(hf.readAccess[hFile]);
}


/**
 * Ob das Handle einer Historydatei Schreibzugriff erlaubt.
 *
 * @param  int hFile - Dateihandle
 *
 * @return bool - Ergebnis oder FALSE, falls ein Fehler auftrat
 */
bool hf.WriteAccess(int hFile) {
   if (hFile <= 0)                      return(!catch("hf.WriteAccess(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("hf.WriteAccess(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(!catch("hf.WriteAccess(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR));
                                        return(!catch("hf.WriteAccess(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR));
      }
      hf.hFile.lastValid = hFile;
   }
   return(hf.writeAccess[hFile]);
}


/**
 * Gibt die aktuelle Größe der zu einem Handle gehörenden Historydatei zurück (inkl. noch ungeschriebener Daten im Schreibpuffer).
 *
 * @param  int hFile - Dateihandle
 *
 * @return int - Größe oder -1 (EMPTY), falls ein Fehler auftrat
 */
int hf.Size(int hFile) {
   if (hFile <= 0)                      return(_EMPTY(catch("hf.Size(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_EMPTY(catch("hf.Size(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_EMPTY(catch("hf.Size(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_EMPTY(catch("hf.Size(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.lastValid = hFile;
   }
   return(hf.size[hFile]);
}


/**
 * Gibt die aktuelle Anzahl der Bars der zu einem Handle gehörenden Historydatei zurück (inkl. noch ungeschriebener Daten im Schreibpuffer).
 *
 * @param  int hFile - Dateihandle
 *
 * @return int - Anzahl oder -1 (EMPTY), falls ein Fehler auftrat
 */
int hf.Bars(int hFile) {
   if (hFile <= 0)                      return(_EMPTY(catch("hf.Bars(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_EMPTY(catch("hf.Bars(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_EMPTY(catch("hf.Bars(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_EMPTY(catch("hf.Bars(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.lastValid = hFile;
   }
   return(hf.bars[hFile]);
}


/**
 * Gibt den Zeitpunkt der ältesten Bar der zu einem Handle gehörenden Historydatei zurück (inkl. noch ungeschriebener Daten im Schreibpuffer).
 *
 * @param  int hFile - Dateihandle
 *
 * @return datetime - Zeitpunkt oder -1 (EMPTY), falls ein Fehler auftrat
 */
datetime hf.From(int hFile) {
   if (hFile <= 0)                      return(_EMPTY(catch("hf.From(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_EMPTY(catch("hf.From(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_EMPTY(catch("hf.From(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_EMPTY(catch("hf.From(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.lastValid = hFile;
   }
   return(hf.from[hFile]);
}


/**
 * Gibt den Zeitpunkt der jüngsten Bar der zu einem Handle gehörenden Historydatei zurück (inkl. noch ungeschriebener Daten im Schreibpuffer).
 *
 * @param  int hFile - Dateihandle
 *
 * @return datetime - Zeitpunkt oder -1 (EMPTY), falls ein Fehler auftrat
 */
datetime hf.To(int hFile) {
   if (hFile <= 0)                      return(_EMPTY(catch("hf.To(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_EMPTY(catch("hf.To(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_EMPTY(catch("hf.To(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_EMPTY(catch("hf.To(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.lastValid = hFile;
   }
   return(hf.to[hFile]);
}


/**
 * Gibt den Header der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile   - Dateihandle
 * @param  int array[] - Array zur Aufnahme der Headerdaten
 *
 * @return int - Fehlerstatus
 */
int hf.Header(int hFile, int array[]) {
   if (hFile <= 0)                      return(catch("hf.Header(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(catch("hf.Header(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(catch("hf.Header(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR));
                                        return(catch("hf.Header(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR));
      }
      hf.hFile.lastValid = hFile;
   }
   if (ArrayDimension(array) > 1)       return(catch("hf.Header(5)  too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS));

   ArrayResize(array, HISTORY_HEADER.intSize);                       // entspricht: array = hf.header[hFile];
   int src  = GetIntsAddress(hf.header) + hFile*HISTORY_HEADER.size;
   int dest = GetIntsAddress(array);
   CopyMemory(dest, src, HISTORY_HEADER.size);
   return(NO_ERROR);
}


/**
 * Gibt die Formatversion der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return int - Format-ID oder NULL, falls ein Fehler auftrat
 */
int hf.Format(int hFile) {
   if (hFile <= 0)                      return(_NULL(catch("hf.Format(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_NULL(catch("hf.Format(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_NULL(catch("hf.Format(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_NULL(catch("hf.Format(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.lastValid = hFile;
   }
   return(hf.format[hFile]);
}


/**
 * Gibt das Symbol der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return string - Symbol oder Leerstring, falls ein Fehler auftrat
 */
string hf.Symbol(int hFile) {
   if (hFile <= 0)                      return(_EMPTY_STR(catch("hf.Symbol(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_EMPTY_STR(catch("hf.Symbol(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_EMPTY_STR(catch("hf.Symbol(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_EMPTY_STR(catch("hf.Symbol(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.lastValid = hFile;
   }
   return(hf.symbol[hFile]);
}


/**
 * Gibt die Beschreibung der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return string - Beschreibung oder Leerstring, falls ein Fehler auftrat
 */
string hf.Description(int hFile) {
   if (hFile <= 0)                      return(_EMPTY_STR(catch("hf.Description(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_EMPTY_STR(catch("hf.Description(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_EMPTY_STR(catch("hf.Description(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_EMPTY_STR(catch("hf.Description(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.lastValid = hFile;
   }
   return(hhs.Description(hf.header, hFile));
}


/**
 * Gibt den Timeframe der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return int - Timeframe oder NULL, falls ein Fehler auftrat
 */
int hf.Period(int hFile) {
   if (hFile <= 0)                      return(_NULL(catch("hf.Period(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_NULL(catch("hf.Period(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_NULL(catch("hf.Period(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_NULL(catch("hf.Period(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.lastValid = hFile;
   }
   return(hf.period[hFile]);
}


/**
 * Gibt die Anzahl der Digits der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return int - Digits oder -1 (EMPTY), falls ein Fehler auftrat
 */
int hf.Digits(int hFile) {
   if (hFile <= 0)                      return(_EMPTY(catch("hf.Digits(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_EMPTY(catch("hf.Digits(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_EMPTY(catch("hf.Digits(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_EMPTY(catch("hf.Digits(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.lastValid = hFile;
   }
   return(hf.digits[hFile]);
}


/**
 * Gibt den Namen des Serververzeichnisses einer zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return string - Verzeichnisname oder Leerstring, falls ein Fehler auftrat
 */
string hf.ServerName(int hFile) {
   if (hFile <= 0)                      return(_EMPTY_STR(catch("hf.ServerName(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_EMPTY_STR(catch("hf.ServerName(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_EMPTY_STR(catch("hf.ServerName(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_EMPTY_STR(catch("hf.ServerName(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.lastValid = hFile;
   }
   return(hf.server[hFile]);
}


/**
 * Gibt das Feld 'SyncMark' der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return datetime - Feld 'SyncMark' oder -1 (EMPTY), falls ein Fehler auftrat
 */
datetime hf.SyncMark(int hFile) {
   if (hFile <= 0)                      return(_EMPTY(catch("hf.SyncMark(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_EMPTY(catch("hf.SyncMark(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_EMPTY(catch("hf.SyncMark(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_EMPTY(catch("hf.SyncMark(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.lastValid = hFile;
   }
   return(hhs.SyncMark(hf.header, hFile));
}


/**
 * Gibt das Feld 'LastSync' der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return datetime - Feld 'LastSync' oder -1 (EMPTY), falls ein Fehler auftrat
 */
datetime hf.LastSync(int hFile) {
   // 2 oder mehr Tests
   if (hFile <= 0)                      return(_EMPTY(catch("hf.LastSync(1)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(_EMPTY(catch("hf.LastSync(2)  invalid or unknown file handle "+ hFile, ERR_INVALID_PARAMETER)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_EMPTY(catch("hf.LastSync(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_EMPTY(catch("hf.LastSync(4)  closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.lastValid = hFile;
   }
   return(hhs.LastSync(hf.header, hFile));
}


/**
 * Schließt alle noch offenen History-Dateien.
 *
 * @param  bool warn - ob für noch offene Dateien eine Warnung ausgegeben werden soll (default: nein)
 *
 * @return bool - Erfolgsstatus
 */
bool history.CloseFiles(bool warn=false) {
   bool _warn = warn!=0;

   int error, size=ArraySize(hf.hFile);

   for (int i=0; i < size; i++) {
      if (hf.hFile[i] > 0) {
         if (_warn) warn("history.CloseFiles(1)  open file handle "+ hf.hFile[i] +" found: "+ DoubleQuoteStr(hf.name[i]));

         if (!HistoryFile.Close(hf.hFile[i]))
            error = last_error;
      }
   }
   return(!error);
}


/**
 * Gibt den letzten in der Library aufgetretenen Fehler zurück. Der Aufruf dieser Funktion setzt den Fehlercode *nicht* zurück.
 *
 * @return int - Fehlerstatus
 */
int history.GetLastError() {
   return(last_error);
}


/**
 * Wird nur im Tester aus Library::init() aufgerufen, um alle verwendeten globalen Arrays zurückzusetzen (EA-Bugfix).
 */
void Tester.ResetGlobalArrays() {
   ArrayResize(stack.orderSelections, 0);

   hs.__ResizeArrays(0);
   hf.__ResizeArrays(0);
}


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   return(last_error);
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   history.CloseFiles(true);
   return(last_error);
}
