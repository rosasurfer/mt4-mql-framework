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
#include <stdlib.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/mt4/HISTORY_HEADER.mqh>
#include <structs/mt4/SYMBOL.mqh>
#include <structs/mt4/SYMBOL_GROUP.mqh>


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
int      hf.hFile        [];                          // Dateihandle: größer 0 = offenes Handle; kleiner 0 = geschlossenes Handle; 0 = ungültiges Handle
int      hf.hFile.lastValid;                          // das letzte gültige, offene Handle (um ein übergebenes Handle nicht ständig neu validieren zu müssen)
string   hf.name         [];                          // Dateiname, ggf. mit Unterverzeichnis "MyFX-Synthetic\"
bool     hf.readAccess   [];                          // ob das Handle Lese-Zugriff erlaubt
bool     hf.writeAccess  [];                          // ob das Handle Schreib-Zugriff erlaubt
int      hf.size         [];                          // aktuelle Größe der Datei (inkl. noch ungeschriebener Daten im Schreibpuffer)

int      hf.header       [][HISTORY_HEADER.intSize];  // History-Header der Datei
int      hf.format       [];                          // Datenformat: 400 | 401
string   hf.symbol       [];                          // Symbol
string   hf.symbolU      [];                          // SYMBOL (Upper-Case)
int      hf.period       [];                          // Periode
int      hf.periodSecs   [];                          // Dauer einer Periode in Sekunden (nicht gültig für Perioden > 1 Tag)
int      hf.digits       [];                          // Digits
string   hf.server       [];                          // Servername der Datei

int      hf.bars         [];                          // Anzahl der Bars der Datei
datetime hf.from.openTime[];                          // OpenTime der ersten Bar der Datei
datetime hf.to.openTime  [];                          // OpenTime der letzten Bar der Datei


// Cache der aktuellen Bar einer History-Datei (an der Position des File-Pointers) ------------------------------------------------------------------------
int      hf.currentBar.offset         [];             // Offset relativ zum Header: Offset 0 ist die älteste Bar, initialisiert mit -1
datetime hf.currentBar.openTime       [];             // z.B. 12:00:00
datetime hf.currentBar.closeTime      [];             //      13:00:00 (nicht 12:59:59)
datetime hf.currentBar.nextCloseTime  [];             //      14:00:00 (nicht 13:59:59)
double   hf.currentBar.data           [][6];          // Bar-Daten (T-OHLCV)


// Schreibpuffer für gesammelte Ticks einer noch ungespeicherten Bar (bei HST_COLLECT_TICKS = On) ---------------------------------------------------------
int      hf.collectedBar.offset       [];             // Offset relativ zum Header: Offset 0 ist die älteste Bar, initialisiert mit -1
datetime hf.collectedBar.openTime     [];             // z.B. 12:00:00
datetime hf.collectedBar.closeTime    [];             //      13:00:00 (nicht 12:59:59)
datetime hf.collectedBar.nextCloseTime[];             //      14:00:00 (nicht 13:59:59)
double   hf.collectedBar.data         [][6];          // Bar-Daten (T-OHLCV)


/**
 * Erzeugt für ein Symbol ein neues HistorySet mit den angegebenen Daten und gibt dessen Handle zurück. Beim Aufruf der Funktion werden
 * bereits existierende HistoryFiles des Symbols zurückgesetzt (vorhandene Bardaten werden gelöscht) und evt. offene HistoryFile-Handles
 * geschlossen. Noch nicht existierende HistoryFiles werden beim ersten Speichern hinzugefügter Daten automatisch erstellt.
 *
 * Mehrfachaufrufe dieser Funktion für dasselbe Symbol geben jeweils ein neues Handle zurück, ein vorheriges Handle wird geschlossen.
 *
 * @param  _In_ string symbol      - Symbol
 * @param  _In_ string description - Beschreibung des Symbols
 * @param  _In_ int    digits      - Digits der Datenreihe
 * @param  _In_ int    format      - Speicherformat der Datenreihe: 400 - altes Datenformat (wie MetaTrader <= Build 509)
 *                                                                  401 - neues Datenformat (wie MetaTrader  > Build 509)
 * @param  _In_ string server      - Name des Serververzeichnisses, in dem das Set gespeichert wird (default: aktuelles Serververzeichnis)
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
   if (format!=400) /*&&*/ if (format!=401)   return(!catch("HistorySet.Create(4)  invalid parameter format = "+ format +" (can be 400 or 401)", ERR_INVALID_PARAMETER));
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
   hs.ResizeArrays(size);
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
 * Gibt ein Handle für das gesamte HistorySet eines Symbols zurück. Wurde das HistorySet vorher nicht mit HistorySet.Create() erzeugt,
 * muß mindestens ein HistoryFile des Symbols existieren. Nicht existierende HistoryFiles werden dann beim Speichern der ersten hinzugefügten
 * Daten automatisch im alten Datenformat (400) erstellt.
 *
 * - Mehrfachaufrufe dieser Funktion für dasselbe Symbol geben dasselbe Handle zurück.
 * - Die Funktion greift ggf. auf genau eine Historydatei lesend zu. Sie hält keine Dateien offen.
 *
 * @param  _In_ string symbol - Symbol
 * @param  _In_ string server - Name des Serververzeichnisses, in dem das Set gespeichert wird (default: aktuelles Serververzeichnis)
 *
 * @return int - • Set-Handle oder -1, falls kein HistoryFile dieses Symbols existiert. In diesem Fall muß mit HistorySet.Create() ein neues Set erzeugt werden.
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
         hs.ResizeArrays(size);
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
         hs.ResizeArrays(size);
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
 * Schließt das HistorySet mit dem angegebenen Handle.
 *
 * @param  _In_ int hSet - Set-Handle
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
 * @param  _In_ int      hSet  - Set-Handle des Symbols
 * @param  _In_ datetime time  - Zeitpunkt des Ticks
 * @param  _In_ double   value - Datenwert
 * @param  _In_ int      flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                               • HST_COLLECT_TICKS: sammelt aufeinanderfolgende Ticks und schreibt die Daten erst beim jeweils nächsten BarOpen-Event
 *                               • HST_FILL_GAPS:     füllt entstehende Gaps mit dem letzten Schlußkurs vor dem Gap
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
 * • Ist FILE_WRITE angegeben und die Datei existiert nicht, wird sie erstellt.
 * • Ist FILE_WRITE jedoch nicht FILE_READ angegeben und die Datei existiert, wird sie zurückgesetzt und vorhandene Daten gelöscht.
 *
 * @param  _In_ string symbol      - Symbol des Instruments
 * @param  _In_ int    timeframe   - Timeframe der Zeitreihe
 * @param  _In_ string description - Beschreibung des Instruments (falls die Historydatei neu erstellt wird)
 * @param  _In_ int    digits      - Digits der Werte             (falls die Historydatei neu erstellt wird)
 * @param  _In_ int    format      - Datenformat der Zeitreihe    (falls die Historydatei neu erstellt wird)
 * @param  _In_ int    mode        - Access-Mode: FILE_READ|FILE_WRITE
 * @param  _In_ string server      - Name des Serververzeichnisses, in dem die Datei gespeichert wird (default: aktuelles Serververzeichnis)
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
   // Schreibzugriffe werden nur auf ein existierendes Serververzeichnis erlaubt.
   if (!read_only) /*&&*/ if (!IsDirectory(fullHstDir)) return(_NULL(catch("HistoryFile.Open(5)  directory "+ DoubleQuoteStr(fullHstDir) +" doesn't exist", ERR_RUNTIME_ERROR)));

   int hFile = FileOpen(mqlFileName, mode|FILE_BIN);                                // FileOpenHistory() kann Unterverzeichnisse nicht handhaben => alle Zugriffe per FileOpen(symlink)

   // (1.1) read-only                                                               // TODO: !!! Bei read-only Existenz mit IsFile() prüfen, da FileOpen[History]()
   if (read_only) {                                                                 // TODO: !!! sonst das Log ggf. mit Warnungen ERR_CANNOT_OPEN_FILE zupflastert !!!
      int error = GetLastError();
      if (error == ERR_CANNOT_OPEN_FILE) return(-1);                                // file not found
      if (hFile <= 0) return(_NULL(catch("HistoryFile.Open(6)->FileOpen(\""+ mqlFileName +"\", FILE_READ) => "+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR))));
   }

   // (1.2) read-write
   else if (read_write) {
      if (hFile <= 0) return(_NULL(catch("HistoryFile.Open(7)->FileOpen(\""+ mqlFileName +"\", FILE_READ|FILE_WRITE) => "+ hFile, ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR))));
   }

   // (1.3) write-only
   else if (write_only) {
      if (hFile <= 0) return(_NULL(catch("HistoryFile.Open(8)->FileOpen(\""+ mqlFileName +"\", FILE_WRITE) => "+ hFile, ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR))));
   }

   int bars, from, to, fileSize=FileSize(hFile), /*HISTORY_HEADER*/hh[]; InitializeByteBuffer(hh, HISTORY_HEADER.size);


   // (2) ggf. neuen HISTORY_HEADER schreiben
   if (write_only || (read_write && fileSize < HISTORY_HEADER.size)) {
      // Parameter validieren
      if (!StringLen(description))     description = "";                            // NULL-Pointer => Leerstring
      if (StringLen(description) > 63) description = StringLeft(description, 63);   // ein zu langer String wird gekürzt
      if (digits < 0)                          return(_NULL(catch("HistoryFile.Open(9)  invalid parameter digits = "+ digits, ERR_INVALID_PARAMETER)));
      if (format!=400) /*&&*/ if (format!=401) return(_NULL(catch("HistoryFile.Open(10)  invalid parameter format = "+ format +" (needs to be 400 or 401)", ERR_INVALID_PARAMETER)));

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
         return(_NULL(catch("HistoryFile.Open(11)  invalid history file \""+ mqlFileName +"\" (size="+ fileSize +")", ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR))));
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
      hf.ResizeArrays(hFile+1);                                      // andererseits von FileOpen() wiederverwendetes Handle

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

   hf.bars                      [hFile]        = bars;               // bei leerer History: 0
   hf.from.openTime             [hFile]        = from;               // ...                 0
   hf.to.openTime               [hFile]        = to;                 // ...                 0

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

   if (!catch("HistoryFile.Open(12)"))
      return(hFile);
   return(NULL);
}


/**
 * Schließt die Historydatei mit dem angegebenen Handle. Alle noch ungespeicherten Tickdaten werden geschrieben.
 * Die Datei muß vorher mit HistoryFile.Open() geöffnet worden sein.
 *
 * @param  _In_ int hFile - Dateihandle
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
 * Findet in einer Historydatei den Offset der Bar, die den angegebenen Zeitpunkt abdeckt oder abdecken würde, und signalisiert, ob diese Bar
 * bereits existiert. Die Bar existiert z.B. nicht, wenn die Zeitreihe am angegebenen Zeitpunkt eine Lücke aufweist oder wenn der Zeitpunkt
 * außerhalb des von den vorhandenen Daten abgedeckten Bereichs liegt.
 *
 * @param  _In_  int      hFile          - Handle der Historydatei
 * @param  _In_  datetime time           - Zeitpunkt
 * @param  _In_  int      flags          - das Auffinden der Bar steuernde Flags (default: keine)
 *                                         • HST_IS_BAR_OPENTIME: die angegebene Zeit ist die Bar-OpenTime und muß nicht mehr normalisiert werden
 * @param  _Out_ bool     lpBarExists[1] - Variable, die nach Rückkehr anzeigt, ob die Bar am zurückgegebenen Offset existiert
 *                                         (als Array implementiert, um Zeigerübergabe an eine Library zu ermöglichen)
 *                                         • TRUE:  Bar existiert       (zum Aktualisieren dieser Bar muß HistoryFile.UpdateBar() verwendet werden)
 *                                         • FALSE: Bar existiert nicht (zum Aktualisieren dieser Bar muß HistoryFile.InsertBar() verwendet werden)
 *
 * @return int - Bar-Offset relativ zum Dateiheader (Offset 0 ist die älteste Bar) oder -1 (EMPTY), falls ein Fehler auftrat
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
   if (openTime == hf.to.openTime[hFile]) {
      lpBarExists[0] = true;
      return(hf.bars[hFile] - 1);
   }

   // (3) Zeitpunkt würde von der nächsten Bar abgedeckt       // die beiden am häufigsten auftretenden Fälle zu Beginn prüfen
   if (openTime > hf.to.openTime[hFile]) {
      lpBarExists[0] = false;
      return(hf.bars[hFile]);                                  // zum Einfügen an diesem Offset müßte die Datei vergrößert werden
   }

   // (4) History leer
   if (!hf.bars[hFile]) {
      lpBarExists[0] = false;
      return(0);                                               // zum Einfügen an Offset 0 müßte die Datei vergrößert werden
   }

   // (5) Zeitpunkt wird von der ersten Bar abgedeckt
   if (openTime == hf.from.openTime[hFile]) {
      lpBarExists[0] = true;
      return(0);
   }

   // (6) Zeitpunkt liegt zeitlich vor der ersten Bar
   if (openTime < hf.from.openTime[hFile]) {
      lpBarExists[0] = false;
      return(0);                                               // neue Bar müßte an Offset 0 eingefügt werden
   }

   // (7) Zeitpunkt liegt irgendwo innerhalb der Zeitreihe
   int offset;
   return(_EMPTY(catch("HistoryFile.FindBar(6|symbol="+ hf.symbol[hFile]+", period="+ PeriodDescription(hf.period[hFile]) +", bars="+ hf.bars[hFile] +", from.open='"+ TimeToStr(hf.from.openTime[hFile], TIME_FULL) +"', to.open='"+ TimeToStr(hf.to.openTime[hFile], TIME_FULL) +"')  Suche nach time='"+ TimeToStr(time, TIME_FULL) +"' innerhalb der Zeitreihe noch nicht implementiert", ERR_NOT_IMPLEMENTED)));

   if (!catch("HistoryFile.FindBar(7)"))
      return(offset);
   return(EMPTY);
}


/**
 * Liest eine Bar am angegebenen Offset einer Historydatei.
 *
 * @param  _In_  int    hFile  - Handle der Historydatei
 * @param  _In_  int    offset - Offset der zu lesenden Bar relativ zum Dateiheader (Offset 0 ist die älteste Bar)
 * @param  _Out_ double bar[6] - Array zur Aufnahme der Bar-Daten (TOHLCV)
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
 * Schreibt eine Bar am angegebenen Offset einer Historydatei. Eine vorhandene Bar wird überschrieben.
 *
 * @param  _In_ int    hFile  - Handle der Historydatei
 * @param  _In_ int    offset - Offset der zu schreibenden Bar relativ zum Dateiheader (Offset 0 ist die älteste Bar)
 * @param  _In_ double bar[]  - Bardaten (TOHLCV)
 * @param  _In_ int    flags  - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                              • HST_FILL_GAPS:       beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
 *                              • HST_IS_BAR_OPENTIME: die angegebene Zeit ist die Bar-OpenTime und muß nicht mehr normalisiert werden
 *
 * @return bool - Erfolgsstatus
 *
 * NOTE: Zur Performancesteigerung werden die Bardaten nicht validiert.
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
   datetime openTime, closeTime, nextCloseTime, barTime=bar[BAR_T];
   if    (HST_IS_BAR_OPENTIME & flags != 0) openTime = barTime;
   else if (hf.period[hFile] <= PERIOD_D1 ) openTime = barTime - barTime%hf.periodSecs[hFile];
   else if (hf.period[hFile] == PERIOD_W1 ) openTime = barTime - barTime%DAYS - (TimeDayOfWeekFix(barTime)+6)%7*DAYS;   // 00:00, Montag
   else if (hf.period[hFile] == PERIOD_MN1) openTime = barTime - barTime%DAYS - (TimeDayFix(barTime)-1)*DAYS;           // 00:00, 1. des Monats

   if (hf.period[hFile] <= PERIOD_D1) {
      closeTime     = openTime  + hf.periodSecs[hFile];
      nextCloseTime = closeTime + hf.periodSecs[hFile];
   }
   else if (hf.period[hFile] == PERIOD_W1) {
      closeTime     = openTime +  7*DAYS;                                                                               // 00:00, Montag der nächsten Woche
      nextCloseTime = openTime + 14*DAYS;                                                                               // 00:00, Montag der übernächsten Woche
   }
   else if (hf.period[hFile] == PERIOD_MN1) {
      closeTime     = DateTime(TimeYearFix(openTime), TimeMonth(openTime)+1);                                           // 00:00, 1. des nächsten Monats
      nextCloseTime = DateTime(TimeYearFix(openTime), TimeMonth(openTime)+2);                                           // 00:00, 1. des übernächsten Monats
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
   if (offset >= hf.bars[hFile]) { hf.size         [hFile] = position + barSize;
                                   hf.bars         [hFile] = offset + 1; }
   if (offset == 0)                hf.from.openTime[hFile] = openTime;
   if (offset == hf.bars[hFile]-1) hf.to.openTime  [hFile] = openTime;

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
 * Fügt eine Bar am angegebenen Offset einer Historydatei ein.
 *
 * @param  _In_ int    hFile  - Handle der Historydatei
 * @param  _In_ int    offset - Offset der einzufügenden Bar relativ zum Dateiheader (Offset 0 ist die älteste Bar)
 * @param  _In_ double bar[6] - Bardaten (TOHLCV)
 * @param  _In_ int    flags  - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                              • HST_FILL_GAPS:       beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
 *                              • HST_IS_BAR_OPENTIME: die angegebene Zeit ist die Bar-OpenTime und muß nicht mehr normalisiert werden
 * @return bool - Erfolgsstatus
 *
 * NOTE: Zur Performancesteigerung werden die Bardaten nicht validiert.
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
 * Aktualisiert den Schlußkurs der Bar am angegebenen Offset einer Historydatei.
 *
 * @param  _In_ int    hFile  - Handle der Historydatei
 * @param  _In_ int    offset - Offset der zu aktualisierenden Bar relativ zum Dateiheader (Offset 0 ist die älteste Bar)
 * @param  _In_ double value  - hinzuzufügender Wert
 *
 * @return bool - Erfolgsstatus
 *
 * NOTE: Zur Performancesteigerung werden die Bardaten nicht validiert.
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
 * Schreibt die aktuellen Bardaten in die Historydatei.
 *
 * @param  _In_ int hFile - Handle der Historydatei
 * @param  _In_ int flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                          • HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
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
   if (offset >= hf.bars[hFile]) { hf.size         [hFile] = position + barSize;
                                   hf.bars         [hFile] = offset + 1; }
   if (offset == 0)                hf.from.openTime[hFile] = time;
   if (offset == hf.bars[hFile]-1) hf.to.openTime  [hFile] = time;

   return(!catch("HistoryFile.WriteCurrentBar(7)"));
}


/**
 * Schreibt die zwischengespeicherten Tickdaten in die Historydatei.
 *
 * @param  _In_ int hFile - Handle der Historydatei
 * @param  _In_ int flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                          • HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
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
   if (offset == 0)                hf.from.openTime           [hFile]        = time;
   if (offset == hf.bars[hFile]-1) hf.to.openTime             [hFile]        = time;

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
 * @param  _In_ int hFile      - Handle der Historydatei
 * @param  _In_ int fromOffset - Start-Offset
 * @param  _In_ int destOffset - Ziel-Offset
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile.MoveBars(int hFile, int fromOffset, int destOffset) {
   return(!catch("HistoryFile.MoveBars(1)", ERR_NOT_IMPLEMENTED));
}


/**
 * Fügt einer einzelnen Historydatei einen Tick hinzu. Der Tick wird als letzter Tick (Close) der entsprechenden Bar gespeichert.
 *
 * @param  _In_ int      hFile - Handle der Historydatei
 * @param  _In_ datetime time  - Zeitpunkt des Ticks
 * @param  _In_ double   value - Datenwert
 * @param  _In_ int      flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                               • HST_COLLECT_TICKS: sammelt aufeinanderfolgende Ticks und schreibt die Daten erst beim jeweils nächsten BarOpen-Event
 *                               • HST_FILL_GAPS:     füllt entstehende Gaps mit dem letzten Schlußkurs vor dem Gap
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
   if (time < hf.to.openTime[hFile])    return(!catch("HistoryFile.AddTick(6)  cannot add tick to a closed bar: tickTime="+ TimeToStr(time, TIME_FULL) +", last bar openTime="+ TimeToStr(hf.to.openTime[hFile], TIME_FULL), ERR_RUNTIME_ERROR));

   double   tickValue = NormalizeDouble(value, hf.digits[hFile]);
   bool     barExists[1];
   int      offset, dow;
   datetime openTime, closeTime, nextCloseTime, tickTime=time;
   double   bar[6];


   // (1) Tick ggf. sammeln -----------------------------------------------------------------------------------------------------------------------
   if (HST_COLLECT_TICKS & flags != 0) {
      if (tickTime < hf.collectedBar.openTime[hFile] || tickTime >= hf.collectedBar.closeTime[hFile]) {
         // (1.1) Collected-Bar leer oder Tick gehört zu neuer Bar (irgendwo dahinter)
         offset = HistoryFile.FindBar(hFile, tickTime, flags, barExists); if (offset < 0) return(false); // Offset der Bar, zu der der Tick gehört

         if (!hf.collectedBar.openTime[hFile]) {
            // (1.1.1) Collected-Bar leer
            if (barExists[0]) {                                                                          // Bar existiert: Initialisierung
               if (!HistoryFile.ReadBar(hFile, offset, bar)) return(false);                              // vorhandene Bar als Ausgangsbasis einlesen

               hf.collectedBar.data[hFile][BAR_T] =         bar[BAR_T];
               hf.collectedBar.data[hFile][BAR_O] =         bar[BAR_O];                                  // Tick hinzufügen
               hf.collectedBar.data[hFile][BAR_H] = MathMax(bar[BAR_H], tickValue);
               hf.collectedBar.data[hFile][BAR_L] = MathMin(bar[BAR_L], tickValue);
               hf.collectedBar.data[hFile][BAR_C] =                     tickValue;
               hf.collectedBar.data[hFile][BAR_V] =         bar[BAR_V] + 1;
            }
            else {
               hf.collectedBar.data[hFile][BAR_O] = tickValue;                                           // Bar existiert nicht: neue Bar beginnen
               hf.collectedBar.data[hFile][BAR_H] = tickValue;
               hf.collectedBar.data[hFile][BAR_L] = tickValue;
               hf.collectedBar.data[hFile][BAR_C] = tickValue;
               hf.collectedBar.data[hFile][BAR_V] = 1;
            }
         }
         else {
            // (1.1.2) Collected-Bar gefüllt und komplett
            if (hf.collectedBar.offset[hFile] >= hf.bars[hFile]) /*&&*/ if (!barExists[0])
               offset++;   // Wenn die Collected-Bar real noch nicht existiert, muß 'offset' vergrößert werden, falls die neue Bar ebenfalls nicht existiert.

            if (!HistoryFile.WriteCollectedBar(hFile, flags)) return(false);

            hf.collectedBar.data[hFile][BAR_O] = tickValue;                                                          // neue Bar beginnen
            hf.collectedBar.data[hFile][BAR_H] = tickValue;
            hf.collectedBar.data[hFile][BAR_L] = tickValue;
            hf.collectedBar.data[hFile][BAR_C] = tickValue;
            hf.collectedBar.data[hFile][BAR_V] = 1;
         }

         if (hf.period[hFile] <= PERIOD_D1) {
            hf.collectedBar.openTime     [hFile] = tickTime - tickTime%hf.periodSecs[hFile];
            hf.collectedBar.closeTime    [hFile] = hf.collectedBar.openTime [hFile] + hf.periodSecs[hFile];
            hf.collectedBar.nextCloseTime[hFile] = hf.collectedBar.closeTime[hFile] + hf.periodSecs[hFile];
         }
         else if (hf.period[hFile] == PERIOD_W1) {
            openTime                             = tickTime - tickTime%DAYS - (TimeDayOfWeekFix(tickTime)+6)%7*DAYS; // 00:00, Montag
            hf.collectedBar.openTime     [hFile] = openTime;
            hf.collectedBar.closeTime    [hFile] = openTime +  7*DAYS;                                               // 00:00, Montag der nächsten Woche
            hf.collectedBar.nextCloseTime[hFile] = openTime + 14*DAYS;                                               // 00:00, Montag der übernächsten Woche
         }
         else if (hf.period[hFile] == PERIOD_MN1) {
            openTime                             = tickTime - tickTime%DAYS - (TimeDayFix(tickTime)-1)*DAYS;         // 00:00, 1. des Monats
            hf.collectedBar.openTime     [hFile] = openTime;
            hf.collectedBar.closeTime    [hFile] = DateTime(TimeYearFix(openTime), TimeMonth(openTime)+1);           // 00:00, 1. des nächsten Monats
            hf.collectedBar.nextCloseTime[hFile] = DateTime(TimeYearFix(openTime), TimeMonth(openTime)+2);           // 00:00, 1. des übernächsten Monats
         }

         hf.collectedBar.offset[hFile]        = offset;
         hf.collectedBar.data  [hFile][BAR_T] = hf.collectedBar.openTime[hFile];
      }
      else {
         // (1.2) Tick gehört zur Collected-Bar
       //hf.collectedBar.data[hFile][BAR_T] = ...                                                                    // unverändert
       //hf.collectedBar.data[hFile][BAR_O] = ...                                                                    // unverändert
         hf.collectedBar.data[hFile][BAR_H] = MathMax(hf.collectedBar.data[hFile][BAR_H], tickValue);
         hf.collectedBar.data[hFile][BAR_L] = MathMin(hf.collectedBar.data[hFile][BAR_L], tickValue);
         hf.collectedBar.data[hFile][BAR_C] = tickValue;
         hf.collectedBar.data[hFile][BAR_V]++;
      }
      return(true);
   } // end if (HST_COLLECT_TICKS)


   // (2) gefüllte Collected-Bar schreiben --------------------------------------------------------------------------------------------------------
   if (hf.collectedBar.offset[hFile] >= 0) {                                                    // HST_COLLECT_TICKS wechselte zur Laufzeit und ist jetzt OFF
      bool isTickInCollectedBar = tickTime < hf.collectedBar.closeTime[hFile];
      if (isTickInCollectedBar) {
       //hf.collectedBar.data[hFile][BAR_T] = ... (unverändert)                                 // Tick zur Collected-Bar hinzufügen
       //hf.collectedBar.data[hFile][BAR_O] = ... (unverändert)
         hf.collectedBar.data[hFile][BAR_H] = MathMax(hf.collectedBar.data[hFile][BAR_H], tickValue);
         hf.collectedBar.data[hFile][BAR_L] = MathMin(hf.collectedBar.data[hFile][BAR_L], tickValue);
         hf.collectedBar.data[hFile][BAR_C] = tickValue;
         hf.collectedBar.data[hFile][BAR_V]++;
      }
      if (!HistoryFile.WriteCollectedBar(hFile, flags)) return(false);                          // Collected-Bar schreiben (unwichtig, ob komplett, da HST_COLLECT_TICKS=Off)

      hf.collectedBar.offset       [hFile] = -1;                                                // Collected-Bar zurücksetzen
      hf.collectedBar.openTime     [hFile] =  0;
      hf.collectedBar.closeTime    [hFile] =  0;
      hf.collectedBar.nextCloseTime[hFile] =  0;

      if (isTickInCollectedBar)
         return(true);
   }


   // (3) Tick schreiben --------------------------------------------------------------------------------------------------------------------------
   if      (hf.period[hFile] <= PERIOD_D1 ) openTime = tickTime - tickTime%hf.periodSecs[hFile];                           // OpenTime der entsprechenden Bar ermitteln
   else if (hf.period[hFile] == PERIOD_W1 ) openTime = tickTime - tickTime%DAYS - (TimeDayOfWeekFix(tickTime)+6)%7*DAYS;   // 00:00, Montag
   else if (hf.period[hFile] == PERIOD_MN1) openTime = tickTime - tickTime%DAYS - (TimeDayFix(tickTime)-1)*DAYS;           // 00:00, 1. des Monats

   offset = HistoryFile.FindBar(hFile, openTime, flags|HST_IS_BAR_OPENTIME, barExists); if (offset < 0) return(false);     // Offset der entsprechenden Bar ermitteln
   if (barExists[0])                                                                                                       // existierende Bar aktualisieren...
      return(HistoryFile.UpdateBar(hFile, offset, tickValue));

   bar[BAR_T] = openTime;                                                                                                  // ...oder neue Bar einfügen
   bar[BAR_O] = tickValue;
   bar[BAR_H] = tickValue;
   bar[BAR_L] = tickValue;
   bar[BAR_C] = tickValue;
   bar[BAR_V] = 1;
   return(HistoryFile.InsertBar(hFile, offset, bar, flags|HST_IS_BAR_OPENTIME));
}


/**
 * Setzt die Größe der internen HistorySet-Datenarrays auf den angegebenen Wert.
 *
 * @param  int size - neue Größe
 *
 * @return int - neue Größe der Arrays
 */
int hs.ResizeArrays(int size) {
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
 */
int hf.ResizeArrays(int size) {
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
      ArrayResize(hf.from.openTime,              size);
      ArrayResize(hf.to.openTime,                size);

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

   hs.ResizeArrays(0);
   hf.ResizeArrays(0);
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


/**
 * Erzeugt in der Konfiguration des angegebenen AccountServers ein neues Symbol.
 *
 * @param  string symbol         - Symbol
 * @param  string description    - Symbolbeschreibung
 * @param  string groupname      - Name der Gruppe, in der das Symbol gelistet wird
 * @param  int    digits         - Digits
 * @param  string baseCurrency   - Basiswährung
 * @param  string marginCurrency - Marginwährung
 * @param  string serverName     - Name des Accountservers, in dessen Konfiguration das Symbol angelegt wird (default: der aktuelle AccountServer)
 *
 * @return int - ID des Symbols (Wert >= 0) oder -1, falls ein Fehler auftrat (z.B. wenn das angegebene Symbol bereits existiert)
 */
int CreateSymbol(string symbolName, string description, string groupName, int digits, string baseCurrency, string marginCurrency, string serverName="") {
   int   groupIndex;
   color groupColor = CLR_NONE;

   // alle Symbolgruppen einlesen
   /*SYMBOL_GROUP[]*/int sgs[];
   int size = GetSymbolGroups(sgs, serverName); if (size < 0) return(-1);

   // angegebene Gruppe suchen
   for (int i=0; i < size; i++) {
      if (sgs_Name(sgs, i) == groupName)
         break;
   }
   if (i == size) {                                                  // Gruppe nicht gefunden, neu anlegen
      i = AddSymbolGroup(sgs, groupName, groupName, groupColor); if (i < 0) return(-1);
      if (!SaveSymbolGroups(sgs, serverName))                               return(-1);
   }
   groupIndex = i;
   groupColor = sgs_BackgroundColor(sgs, i);

   // Symbol alegen
   /*SYMBOL*/int symbol[]; InitializeByteBuffer(symbol, SYMBOL.size);
   if (!SetSymbolTemplate        (symbol, SYMBOL_TYPE_INDEX)) return(-1);
   if (!symbol_SetName           (symbol, symbolName       )) return(_EMPTY(catch("CreateSymbol(1)->symbol_SetName() => FALSE", ERR_RUNTIME_ERROR)));
   if (!symbol_SetDescription    (symbol, description      )) return(_EMPTY(catch("CreateSymbol(2)->symbol_SetDescription() => FALSE", ERR_RUNTIME_ERROR)));
   if (!symbol_SetDigits         (symbol, digits           )) return(_EMPTY(catch("CreateSymbol(3)->symbol_SetDigits() => FALSE", ERR_RUNTIME_ERROR)));
   if (!symbol_SetBaseCurrency   (symbol, baseCurrency     )) return(_EMPTY(catch("CreateSymbol(4)->symbol_SetBaseCurrency() => FALSE", ERR_RUNTIME_ERROR)));
   if (!symbol_SetMarginCurrency (symbol, marginCurrency   )) return(_EMPTY(catch("CreateSymbol(5)->symbol_SetMarginCurrency() => FALSE", ERR_RUNTIME_ERROR)));
   if (!symbol_SetGroup          (symbol, groupIndex       )) return(_EMPTY(catch("CreateSymbol(6)->symbol_SetGroup() => FALSE", ERR_RUNTIME_ERROR)));
   if (!symbol_SetBackgroundColor(symbol, groupColor       )) return(_EMPTY(catch("CreateSymbol(7)->symbol_SetBackgroundColor() => FALSE", ERR_RUNTIME_ERROR)));

   if (!InsertSymbol(symbol, serverName)) return(-1);
   return(symbol_Id(symbol));
}


/**
 * Gibt alle Symbolgruppen des angegebenen AccountServers zurück.
 *
 * @param  SYMBOL_GROUP sgs[]      - Array zur Aufnahme der eingelesenen Symbolgruppen
 * @param  string       serverName - Name des AccountServers (default: der aktuelle AccountServer)
 *
 * @return int - Anzahl der gelesenen Gruppen oder -1 (EMPTY), falls ein Fehler auftrat
 */
int GetSymbolGroups(/*SYMBOL_GROUP*/int sgs[], string serverName="") {
   if (serverName == "0")      serverName = "";                      // (string) NULL
   if (!StringLen(serverName)) serverName = GetServerName(); if (serverName == "") return(_EMPTY(SetLastError(stdlib.GetLastError())));

   ArrayResize(sgs, 0);

   // (1) "symgroups.raw" auf Existenz prüfen                        // Extra-Prüfung, da bei Read-only-Zugriff FileOpen[History]() bei nicht existierender
   string mqlFileName = ".history\\"+ serverName +"\\symgroups.raw"; // Datei das Log mit Warnungen ERR_CANNOT_OPEN_FILE überschwemmt.
   if (!IsMqlFile(mqlFileName))
      return(0);

   // (2) Datei öffnen und Größe validieren
   int hFile = FileOpen(mqlFileName, FILE_READ|FILE_BIN);
   int error = GetLastError();
   if (IsError(error) || hFile <= 0)  return(_EMPTY(catch("GetSymbolGroups(1)->FileOpen(\""+ mqlFileName +"\", FILE_READ) => "+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR))));
   int fileSize = FileSize(hFile);
   if (fileSize % SYMBOL_GROUP.size != 0) {
      FileClose(hFile);               return(_EMPTY(catch("GetSymbolGroups(2)  invalid size of \""+ mqlFileName +"\" (not an even SYMBOL_GROUP size, "+ (fileSize % SYMBOL_GROUP.size) +" trailing bytes)", ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR))));
   }
   if (!fileSize) { FileClose(hFile); return(0); }                   // Eine leere Datei wird akzeptiert. Eigentlich muß sie immer 32 * SYMBOL_GROUP.size groß sein,
                                                                     // doch im Moment der Erstellung (von jemand anderem) kann sie vorübergehend 0 Bytes groß sein.
   // (3) Datei einlesen
   InitializeByteBuffer(sgs, fileSize);
   int ints = FileReadArray(hFile, sgs, 0, fileSize/4);
   error = GetLastError();
   FileClose(hFile);
   if (IsError(error) || ints!=fileSize/4) return(_EMPTY(catch("GetSymbolGroups(3)  error reading \""+ mqlFileName +"\" ("+ ints*4 +" of "+ fileSize +" bytes read)", ifInt(error, error, ERR_RUNTIME_ERROR))));

   return(fileSize/SYMBOL_GROUP.size);
}


/**
 * Fügt einer Liste von Symbolgruppen eine weitere hinzu. Die Gruppe wird an der ersten verfügbaren Position der Liste gespeichert.
 *
 * @param  SYMBOL_GROUP sgs[] - Liste von Symbolgruppen, der die neue Gruppe hinzugefügt werden soll
 * @param  string name        - Gruppenname
 * @param  string description - Gruppenbeschreibung
 * @param  color  bgColor     - Hintergrundfarbe der Symbolgruppe im "Market Watch"-Window
 *
 * @return int - Index der Gruppe innerhalb der Liste oder -1 (EMPTY), falls ein Fehler auftrat (z.B. wenn die angegebene Gruppe bereits existiert)
 */
int AddSymbolGroup(/*SYMBOL_GROUP*/int sgs[], string name, string description, color bgColor) {
   int byteSize = ArraySize(sgs) * 4;
   if (byteSize % SYMBOL_GROUP.size != 0)         return(_EMPTY(catch("AddSymbolGroup(1)  invalid size of sgs[] (not an even SYMBOL_GROUP size, "+ (byteSize % SYMBOL_GROUP.size) +" trailing bytes)", ERR_RUNTIME_ERROR)));
   if (name == "0") name = "";                    // (string) NULL
   if (!StringLen(name))                          return(_EMPTY(catch("AddSymbolGroup(2)  invalid parameter name = "+ DoubleQuoteStr(name), ERR_INVALID_PARAMETER)));
   if (description == "0") description = "";      // (string) NULL
   if (bgColor!=CLR_NONE && bgColor & 0xFF000000) return(_EMPTY(catch("AddSymbolGroup(3)  invalid parameter bgColor = 0x"+ IntToHexStr(bgColor) +" (not a color)", ERR_INVALID_PARAMETER)));

   // überprüfen, ob die angegebene Gruppe bereits existiert und dabei den ersten freien Index ermitteln
   int groupsSize = byteSize/SYMBOL_GROUP.size;
   int iFree = -1;
   for (int i=0; i < groupsSize; i++) {
      string foundName = sgs_Name(sgs, i);
      if (name == foundName)                      return(_EMPTY(catch("AddSymbolGroup(4)  a group named "+ DoubleQuoteStr(name) +" already exists", ERR_RUNTIME_ERROR)));
      if (iFree==-1) /*&&*/ if (foundName=="")
         iFree = i;
   }

   // ohne freien Index das Array entsprechend vergrößern
   if (iFree == -1) {
      ArrayResize(sgs, (groupsSize+1)*SYMBOL_GROUP.intSize);
      iFree = groupsSize;
      groupsSize++;
   }

   // neue Gruppe erstellen und an freien Index kopieren
   /*SYMBOL_GROUP*/int sg[]; InitializeByteBuffer(sg, SYMBOL_GROUP.size);
   if (!sg_SetName           (sg, name       )) return(_EMPTY(catch("AddSymbolGroup(5)->sg_SetName() => FALSE", ERR_RUNTIME_ERROR)));
   if (!sg_SetDescription    (sg, description)) return(_EMPTY(catch("AddSymbolGroup(6)->sg_SetDescription() => FALSE", ERR_RUNTIME_ERROR)));
   if (!sg_SetBackgroundColor(sg, bgColor    )) return(_EMPTY(catch("AddSymbolGroup(7)->sg_SetBackgroundColor() => FALSE", ERR_RUNTIME_ERROR)));

   int src  = GetIntsAddress(sg);
   int dest = GetIntsAddress(sgs) + iFree*SYMBOL_GROUP.size;
   CopyMemory(dest, src, SYMBOL_GROUP.size);
   ArrayResize(sg, 0);

   return(iFree);
}


/**
 * Speichert die übergebenen Symbolgruppen in der Datei "symgroups.raw" des angegebenen AccountServers. Eine existierende Datei wird überschrieben.
 *
 * @param  SYMBOL_GROUP sgs[]      - Array von Symbolgruppen
 * @param  string       serverName - Name des Accountservers, in dessen Verzeichnis die Gruppen gespeichert werden (default: der aktuelle AccountServer)
 *
 * @return bool - Erfolgsstatus
 */
bool SaveSymbolGroups(/*SYMBOL_GROUP*/int sgs[], string serverName="") {
   int byteSize = ArraySize(sgs) * 4;
   if (byteSize % SYMBOL_GROUP.size != 0)                                          return(!catch("SaveSymbolGroups(1)  invalid size of sgs[] (not an even SYMBOL_GROUP size, "+ (byteSize % SYMBOL_GROUP.size) +" trailing bytes)", ERR_RUNTIME_ERROR));
   if (byteSize > 32*SYMBOL_GROUP.size)                                            return(!catch("SaveSymbolGroups(2)  invalid number of groups in sgs[] (max 32)", ERR_RUNTIME_ERROR));
   if (serverName == "0")      serverName = "";                      // (string) NULL
   if (!StringLen(serverName)) serverName = GetServerName(); if (serverName == "") return(!SetLastError(stdlib.GetLastError()));

   // "symgroups.raw" muß immer 32 Gruppen enthalten (ggf. undefiniert)
   int sgs.copy[]; ArrayResize(sgs.copy, 0);
   if (ArraySize(sgs) < 32*SYMBOL_GROUP.intSize)
      InitializeByteBuffer(sgs.copy, 32*SYMBOL_GROUP.size);          // um das übergebene Array nicht zu verändern, erweitern wir ggf. eine Kopie
   ArrayCopy(sgs.copy, sgs);

   // Datei öffnen                                                   // TODO: Verzeichnis überprüfen und ggf. erstellen
   string mqlFileName = ".history\\"+ serverName +"\\symgroups.raw";
   int hFile = FileOpen(mqlFileName, FILE_WRITE|FILE_BIN);
   int error = GetLastError();
   if (IsError(error) || hFile <= 0)  return(!catch("SaveSymbolGroups(3)->FileOpen(\""+ mqlFileName +"\", FILE_WRITE) => "+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR)));

   // Daten schreiben
   int arraySize = ArraySize(sgs.copy);
   int ints = FileWriteArray(hFile, sgs.copy, 0, arraySize);
   error = GetLastError();
   FileClose(hFile);
   if (IsError(error) || ints!=arraySize) return(!catch("SaveSymbolGroups(4)  error writing SYMBOL_GROUP[] to \""+ mqlFileName +"\" ("+ ints*4 +" of "+ arraySize*4 +" bytes written)", ifInt(error, error, ERR_RUNTIME_ERROR)));

   ArrayResize(sgs.copy, 0);
   return(true);
}


/**
 * Kopiert das Template des angegebenen Symbol-Typs in das übergebene Symbol.
 *
 * @param  SYMBOL symbol[] - Symbol
 * @param  int    type     - Symbol-Typ
 *
 * @return bool - Erfolgsstatus
 */
bool SetSymbolTemplate(/*SYMBOL*/int symbol[], int type) {
   // Parameter validieren und Template-Datei bestimmen
   string fileName;
   switch (type) {
      case SYMBOL_TYPE_FOREX  : fileName = "templates/SYMBOL_TYPE_FOREX.raw";   break;
      case SYMBOL_TYPE_CFD    : fileName = "templates/SYMBOL_TYPE_CFD.raw";     break;
      case SYMBOL_TYPE_INDEX  : fileName = "templates/SYMBOL_TYPE_INDEX.raw";   break;
      case SYMBOL_TYPE_FUTURES: fileName = "templates/SYMBOL_TYPE_FUTURES.raw"; break;

      default: return(!catch("SetSymbolTemplate(1)  invalid parameter type = "+ type +" (not a symbol type)", ERR_INVALID_PARAMETER));
   }

   // Template-File auf Existenz prüfen                              // Extra-Prüfung, da bei Read-only-Zugriff FileOpen() bei nicht existierender
   if (!IsMqlFile(fileName))                                         // Datei das Log mit Warnungen ERR_CANNOT_OPEN_FILE zumüllt.
      return(false);

   // Datei öffnen und Größe validieren
   int hFile = FileOpen(fileName, FILE_READ|FILE_BIN);
   int error = GetLastError();
   if (IsError(error) || hFile <= 0)       return(!catch("SetSymbolTemplate(2)->FileOpen(\""+ fileName +"\", FILE_READ) => "+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR)));
   int fileSize = FileSize(hFile);
   if (fileSize != SYMBOL.size) {
      FileClose(hFile);                    return(!catch("SetSymbolTemplate(3)  invalid size "+ fileSize +" of \""+ fileName +"\" (not a SYMBOL size)", ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR)));
   }

   // Datei in das übergebene Symbol einlesen
   InitializeByteBuffer(symbol, fileSize);
   int ints = FileReadArray(hFile, symbol, 0, fileSize/4);
   error = GetLastError();
   FileClose(hFile);
   if (IsError(error) || ints!=fileSize/4) return(!catch("SetSymbolTemplate(3)  error reading \""+ fileName +"\" ("+ ints*4 +" of "+ fileSize +" bytes read)", ifInt(error, error, ERR_RUNTIME_ERROR)));

   return(true);
}


/**
 * Fügt das Symbol der angegebenen AccountServer-Konfiguration hinzu.
 *
 * @param  SYMBOL symbol[]   - Symbol
 * @param  string serverName - Name des Accountservers (default: der aktuelle AccountServer)
 *
 * @return bool - Erfolgsstatus
 */
bool InsertSymbol(/*SYMBOL*/int symbol[], string serverName="") {
   if (ArraySize(symbol) != SYMBOL.intSize)                                        return(!catch("InsertSymbol(1)  invalid size "+ ArraySize(symbol) +" of parameter symbol[] (not SYMBOL.intSize)", ERR_RUNTIME_ERROR));
   string name, newName=symbol_Name(symbol);
   if (!StringLen(newName))                                                        return(!catch("InsertSymbol(2)  invalid parameter symbol[], SYMBOL.name = "+ DoubleQuoteStr(newName), ERR_RUNTIME_ERROR));
   if (serverName == "0")      serverName = "";    // (string) NULL
   if (!StringLen(serverName)) serverName = GetServerName(); if (serverName == "") return(!SetLastError(stdlib.GetLastError()));


   // (1.1) Symboldatei öffnen und Größe validieren
   string mqlFileName = ".history\\"+ serverName +"\\symbols.raw";
   int hFile = FileOpen(mqlFileName, FILE_READ|FILE_WRITE|FILE_BIN);
   int error = GetLastError();
   if (IsError(error) || hFile <= 0) return(!catch("InsertSymbol(3)->FileOpen(\""+ mqlFileName +"\", FILE_READ|FILE_WRITE) => "+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR)));
   int fileSize = FileSize(hFile);
   if (fileSize % SYMBOL.size != 0) {
      FileClose(hFile); return(!catch("InsertSymbol(4)  invalid size of \""+ mqlFileName +"\" (not an even SYMBOL size, "+ (fileSize % SYMBOL.size) +" trailing bytes)", ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR)));
   }
   int symbolsSize=fileSize/SYMBOL.size, maxId=-1;
   /*SYMBOL[]*/int symbols[]; InitializeByteBuffer(symbols, fileSize);

   if (fileSize > 0) {
      // (1.2) vorhandene Symbole einlesen
      int ints = FileReadArray(hFile, symbols, 0, fileSize/4);
      error = GetLastError();
      if (IsError(error) || ints!=fileSize/4) { FileClose(hFile); return(!catch("InsertSymbol(5)  error reading \""+ mqlFileName +"\" ("+ ints*4 +" of "+ fileSize +" bytes read)", ifInt(error, error, ERR_RUNTIME_ERROR))); }

      // (1.3) sicherstellen, daß das neue Symbol noch nicht existiert und größte Symbol-ID finden
      for (int i=0; i < symbolsSize; i++) {
         if (symbols_Name(symbols, i) == newName) { FileClose(hFile); return(!catch("InsertSymbol(6)   a symbol named "+ DoubleQuoteStr(newName) +" already exists", ERR_RUNTIME_ERROR)); }
         maxId = Max(maxId, symbols_Id(symbols, i));
      }
   }

   // (2) neue Symbol-ID setzen und Symbol am Ende anfügen
   if (!symbol_SetId(symbol, maxId+1)) { FileClose(hFile); return(!catch("InsertSymbol(7)->symbols_SetId() => FALSE", ERR_RUNTIME_ERROR)); }

   ArrayResize(symbols, (symbolsSize+1)*SYMBOL.intSize);
   i = symbolsSize;
   symbolsSize++;
   int src  = GetIntsAddress(symbol);
   int dest = GetIntsAddress(symbols) + i*SYMBOL.size;
   CopyMemory(dest, src, SYMBOL.size);


   // (3) Array sortieren und Symbole speichern                      // TODO: "symbols.sel" synchronisieren oder löschen
   if (!symbols_Sort(symbols, symbolsSize)) { FileClose(hFile); return(!catch("InsertSymbol(8)->symbols_Sort() => FALSE", ERR_RUNTIME_ERROR)); }

   if (!FileSeek(hFile, 0, SEEK_SET)) { FileClose(hFile);       return(!catch("InsertSymbol(9)->FileSeek(hFile, 0, SEEK_SET) => FALSE", ERR_RUNTIME_ERROR)); }
   int elements = symbolsSize * SYMBOL.size / 4;
   ints  = FileWriteArray(hFile, symbols, 0, elements);
   error = GetLastError();
   FileClose(hFile);
   if (IsError(error) || ints!=elements)                        return(!catch("InsertSymbol(10)  error writing SYMBOL[] to \""+ mqlFileName +"\" ("+ ints*4 +" of "+ symbolsSize*SYMBOL.size +" bytes written)", ifInt(error, error, ERR_RUNTIME_ERROR)));

   return(true);
}
