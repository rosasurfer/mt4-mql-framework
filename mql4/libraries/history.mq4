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
#include <stdlib.mqh>
#include <structs/mt4/HISTORY_HEADER.mqh>


// Standard-Timeframes ------------------------------------------------------------------------------------------------------------------------------------
int      periods[] = { PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1 };


// Daten kompletter History-Sets --------------------------------------------------------------------------------------------------------------------------
int      hs.hSet      [];                          // Set-Handle: größer 0 = offenes Handle; kleiner 0 = geschlossenes Handle; 0 = ungültiges Handle
int      hs.hSet.lastValid;                        // das letzte gültige, offene Handle (um ein übergebenes Handle nicht ständig neu validieren zu müssen)
string   hs.symbol     [];                         // Symbol
string   hs.symbolU    [];                         // Symbol in Upper-Case
string   hs.description[];                         // Symbol-Beschreibung
int      hs.digits     [];                         // Symbol-Digits
int      hs.hFile      [][9];                      // HistoryFile-Handles des Sets je Standard-Timeframe
int      hs.format     [];                         // Datenformat für neu zu erstellende HistoryFiles


// Daten einzelner History-Files --------------------------------------------------------------------------------------------------------------------------
int      hf.hFile      [];                         // Dateihandle: größer 0 = offenes Handle; kleiner 0 = geschlossenes Handle; 0 = ungültiges Handle
int      hf.hFile.lastValid;                       // das letzte gültige, offene Handle (um ein übergebenes Handle nicht ständig neu validieren zu müssen)
string   hf.name       [];                         // Dateiname
bool     hf.readAccess [];                         // ob das Handle Lese-Zugriff erlaubt
bool     hf.writeAccess[];                         // ob das Handle Schreib-Zugriff erlaubt
int      hf.size       [];                         // aktuelle Größe der Datei (inkl. noch ungeschriebener Daten im Schreibpuffer)

int      hf.header     [][HISTORY_HEADER.intSize]; // History-Header der Datei
int      hf.format     [];                         // Datenformat: 400 | 401
string   hf.symbol     [];                         // Symbol
string   hf.symbolU    [];                         // Symbol in Upper-Case
int      hf.period     [];                         // Periode
int      hf.periodSecs [];                         // Dauer einer Periode in Sekunden
int      hf.digits     [];                         // Digits

int      hf.bars       [];                         // Anzahl der Bars der Datei
datetime hf.from       [];                         // OpenTime der ersten Bar der Datei
datetime hf.to         [];                         // OpenTime der letzten Bar der Datei


// Cache der aktuellen Bar einer History-Datei (an der Position des File-Pointers) ------------------------------------------------------------------------
int      hf.currentBar.offset         [];          // Offset relativ zum Header: Offset 0 ist die älteste Bar
datetime hf.currentBar.openTime       [];          //
datetime hf.currentBar.closeTime      [];          //
datetime hf.currentBar.nextCloseTime  [];          //
double   hf.currentBar.data           [][5];       // Bar-Daten (OHLCV)


// Schreibpuffer für gesammelte Ticks einer noch ungespeicherten Bar (bei HST_COLLECT_TICKS = On) ---------------------------------------------------------
int      hf.collectedBar.offset       [];          // Offset relativ zum Header: Offset 0 ist die älteste Bar
datetime hf.collectedBar.openTime     [];          //
datetime hf.collectedBar.closeTime    [];          //
datetime hf.collectedBar.nextCloseTime[];          //
double   hf.collectedBar.data         [][5];       // Bar-Daten (OHLCV)


/**
 * Gibt ein Handle für das gesamte HistorySet eines Symbols zurück. Wurde das HistorySet vorher nicht mit HistorySet.Create() erzeugt,
 * muß mindestens ein HistoryFile des Symbols existieren. Nicht existierende HistoryFiles werden dann beim Speichern der ersten hinzugefügten
 * Daten automatisch erstellt (altes Datenformat).
 *
 * Mehrfachaufrufe dieser Funktion für dasselbe Symbol geben dasselbe Handle zurück.
 *
 * @param  string symbol - Symbol
 *
 * @return int - • Set-Handle oder -1, falls weder ein HistorySet noch ein HistoryFile dieses Symbols existieren. In diesem Fall kann
 *                 mit HistorySet.Create() ein neues Set erzeugt werden.
 *               • NULL, falls ein Fehler auftrat.
 *
 *
 * TODO:   Parameter int fTimeframes - Timeframe-Flags implementieren
 */
int HistorySet.Get(string symbol) {
   if (!StringLen(symbol))                    return(!catch("HistorySet.Get(1)  invalid parameter symbol = "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(!catch("HistorySet.Get(2)  invalid parameter symbol = "+ DoubleQuoteStr(symbol) +" (max "+ MAX_SYMBOL_LENGTH +" characters)", ERR_INVALID_PARAMETER));
   string symbolU = StringToUpper(symbol);

   // (1) offene Set-Handles durchsuchen
   int size = ArraySize(hs.hSet);
   for (int i=0; i < size; i++) {
      if (hs.hSet[i] > 0) /*&&*/ if (hs.symbolU[i]==symbolU) {       // Das Handle muß offen sein.
         debug("HistorySet.Get(0.1)  hSet="+ hs.hSet[i] +"  symbol=\""+ hs.symbol[i] +"\"  description=\""+ hs.description[i] +"\"  digits="+ hs.digits[i]);
         return(hs.hSet[i]);
      }
   }                                                                 // kein offenes Set-Handle gefunden

   int iH, hSet=-1;

   // (2) offene File-Handles durchsuchen
   size = ArraySize(hf.hFile);
   for (i=0; i < size; i++) {
      if (hf.hFile[i] > 0) /*&&*/ if (hf.symbolU[i]==symbolU) {      // Das Handle muß offen sein.
         size = Max(ArraySize(hs.hSet), 1) + 1;                      // neues HistorySet erstellen (minSize=2: auf Index[0] kann kein gültiges Handle liegen)
         hs.__ResizeInternalArrays(size);
         iH   = size-1;
         hSet = iH;                                                  // das Set-Handle entspricht jeweils dem Index in hs.*[]

         hs.hSet       [iH] = hSet;
         hs.symbol     [iH] = hf.symbol [i];
         hs.symbolU    [iH] = hf.symbolU[i];
         hs.description[iH] = hhs.Description(hf.header, i);
         hs.digits     [iH] = hf.digits [i];
         hs.format     [iH] = 400;                                   // Default für neu zu erstellende HistoryFiles

         debug("HistorySet.Get(0.2)  hFile="+ hf.hFile[i] +"  symbol=\""+ hs.symbol[iH] +"\"  description=\""+ hs.description[iH] +"\"  digits="+ hs.digits[iH]);
         return(hSet);
      }
   }                                                                 // kein offenes File-Handle gefunden

   // (3) existierende HistoryFiles suchen
   string fileName;
   int hFile, fileSize, sizeOfPeriods=ArraySize(periods);

   for (i=0; i < sizeOfPeriods; i++) {
      fileName = StringConcatenate(symbol, periods[i], ".hst");
      hFile    = FileOpenHistory(fileName, FILE_BIN|FILE_READ);      // Datei nur öffnen, wenn sie existiert

      if (hFile > 0) {                                               // Datei gefunden und geöffnet
         fileSize = FileSize(hFile);
         if (fileSize < HISTORY_HEADER.size) {
            FileClose(hFile);
            warn("HistorySet.Get(3)  invalid history file \""+ fileName +"\" found (size="+ fileSize +")");
            continue;
         }
                                                                     // HISTORY_HEADER auslesen
         /*HISTORY_HEADER*/int hh[]; ArrayResize(hh, HISTORY_HEADER.intSize);
         FileReadArray(hFile, hh, 0, HISTORY_HEADER.intSize);
         FileClose(hFile);

         size = Max(ArraySize(hs.hSet), 1) + 1;                      // neues HistorySet erstellen (minSize=2: auf Index[0] kann kein gültiges Handle liegen)
         hs.__ResizeInternalArrays(size);
         iH   = size-1;
         hSet = iH;                                                  // das Set-Handle entspricht jeweils dem Index in hs.*[]

         hs.hSet       [iH] = hSet;
         hs.symbol     [iH] = hh.Symbol     (hh);
         hs.symbolU    [iH] = StringToUpper(hs.symbol[iH]);
         hs.description[iH] = hh.Description(hh);
         hs.digits     [iH] = hh.Digits     (hh);
         hs.format     [iH] = 400;                                   // Default für neu zu erstellende HistoryFiles

         debug("HistorySet.Get(0.3)  file=\""+ fileName +"\"  symbol=\""+ hs.symbol[iH] +"\"  description=\""+ hs.description[iH] +"\"  digits="+ hs.digits[iH]);
         ArrayResize(hh, 0);
         return(hSet);
      }

      int error = GetLastError();                                    // Datei konnte nicht geöffnet werden
      if (error != ERR_CANNOT_OPEN_FILE) return(!catch("HistorySet.Get(4)  hFile("+ DoubleQuoteStr(fileName) +") = "+ hFile + ifString(error, "", " (NO_ERROR)"), ifInt(error, error, ERR_RUNTIME_ERROR)));
   }


   if (!catch("HistorySet.Get(5)"))
      return(-1);
   return(NULL);
}


/**
 * Erzeugt für ein Symbol ein neues HistorySet mit den angegebenen Daten und gibt dessen Handle zurück. Beim Aufruf der Funktion werden
 * bereits existierende HistoryFiles des Symbol zurückgesetzt (vorhandene Bardaten werden gelöscht) und evt. offene HistoryFile-Handles
 * ungültig. Noch nicht existierende HistoryFiles werden beim Speichern der ersten hinzugefügten Daten automatisch erstellt.
 *
 * Mehrfachaufrufe dieser Funktion für dasselbe Symbol geben jeweils ein neues Handle zurück, ein vorheriges Handle wird geschlossen.
 *
 * @param  string symbol      - Symbol
 * @param  string description - Beschreibung des Symbols
 * @param  int    digits      - Digits der Datenreihe
 * @param  int    format      - Speicherformat der Datenreihe: 400 - altes Datenformat (wie MetaTrader bis Build 509)
 *                                                             401 - neues Datenformat (wie MetaTrader ab Build 510)
 *
 * @return int - Set-Handle oder NULL, falls ein Fehler auftrat.
 *
 *
 * TODO:   Parameter int fTimeframes - Timeframe-Flags implementieren
 */
int HistorySet.Create(string symbol, string description, int digits, int format) {
   // Parametervalidierung
   if (!StringLen(symbol))                    return(!catch("HistorySet.Create(1)  illegal parameter symbol = "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(!catch("HistorySet.Create(2)  illegal parameter symbol = "+ DoubleQuoteStr(symbol) +" (max "+ MAX_SYMBOL_LENGTH +" characters)", ERR_INVALID_PARAMETER));
   string symbolU = StringToUpper(symbol);
   if (!StringLen(description))     description = "";                            // NULL-Pointer => Leerstring
   if (StringLen(description) > 63) description = StringLeft(description, 63);   // ein zu langer String wird gekürzt
   if (digits < 0)                            return(!catch("HistorySet.Create(3)  invalid parameter digits = "+ digits, ERR_INVALID_PARAMETER));
   if (format!=400) /*&&*/ if (format!=401)   return(!catch("HistorySet.Create(4)  invalid parameter format = "+ format +" (needs to be 400 or 401)", ERR_INVALID_PARAMETER));


   // (1) offene Set-Handles durchsuchen und Sets schließen
   int size = ArraySize(hs.hSet);
   for (int i=0; i < size; i++) {
      if (hs.hSet[i] > 0) /*&&*/ if (hs.symbolU[i]==symbolU) {       // Das Handle muß offen sein.
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
   for (i=0; i < size; i++) {
      if (hf.hFile[i] > 0) /*&&*/ if (hf.symbolU[i]==symbolU) {      // Das Handle muß offen sein.
         if (!HistoryFile.Close(hf.hFile[i]))
            return(NULL);
      }
   }


   // (3) existierende HistoryFiles zurücksetzen und ihre Header aktualisieren
   string fileName;
   int hFile, fileSize, sizeOfPeriods=ArraySize(periods), error;

   /*HISTORY_HEADER*/int hh[]; InitializeByteBuffer(hh, HISTORY_HEADER.size);
   hh.setFormat     (hh, format     );
   hh.setDescription(hh, description);
   hh.setSymbol     (hh, symbol     );
   hh.setDigits     (hh, digits     );

   for (i=0; i < sizeOfPeriods; i++) {
      fileName = StringConcatenate(symbol, periods[i], ".hst");
      hFile    = FileOpenHistory(fileName, FILE_BIN|FILE_READ);      // Datei nur öffnen, wenn sie existiert

      if (hFile > 0) {                                               // Datei gefunden und geöffnet
         FileClose(hFile);
         hFile = FileOpenHistory(fileName, FILE_BIN|FILE_WRITE);     // Datei auf Größe 0 zurücksetzen
         if (hFile > 0) {
            hh.setPeriod(hh, periods[i]);
            FileWriteArray(hFile, hh, 0, ArraySize(hh));             // neuen HISTORY_HEADER schreiben
            FileClose(hFile);
            if (!catch("HistorySet.Create(5)")) continue;
            return(NULL);
         }
         error = GetLastError();                                     // Datei konnte nicht geöffnet werden
         return(!catch("HistorySet.Create(6)  fileName=\""+ fileName +"\"  hFile="+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR)));
      }
      error = GetLastError();                                        // Datei konnte nicht geöffnet werden
      if (error != ERR_CANNOT_OPEN_FILE) return(!catch("HistorySet.Create(7)  fileName=\""+ fileName +"\"  hFile="+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR)));
   }
   ArrayResize(hh, 0);


   // (4) neues HistorySet erzeugen
   size = Max(ArraySize(hs.hSet), 1) + 1;                            // minSize=2: auf Index[0] kann kein gültiges Handle liegen
   hs.__ResizeInternalArrays(size);
   int iH   = size-1;
   int hSet = iH;                                                    // das Set-Handle entspricht jeweils dem Index in hs.*[]

   hs.hSet       [iH] = hSet;
   hs.symbol     [iH] = symbol;
   hs.symbolU    [iH] = symbolU;
   hs.description[iH] = description;
   hs.digits     [iH] = digits;
   hs.format     [iH] = format;

   return(hSet);
}


/**
 * Fügt dem HistorySet eines Symbols einen Tick hinzu (außer PERIOD_W1 und PERIOD_MN1). Der Tick wird als letzter Tick (Close) der entsprechenden Bars gespeichert.
 *
 * @param  int      hSet  - Set-Handle des Symbols
 * @param  datetime time  - Zeitpunkt des Ticks
 * @param  double   value - Datenwert
 * @param  int      flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                          HST_COLLECT_TICKS: sammelt aufeinanderfolgende Ticks und schreibt die Daten erst beim jeweils nächsten BarOpen-Event
 *                          HST_FILL_GAPS:     füllt entstehende Gaps mit dem letzten Schlußkurs vor dem Gap
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
         hFile = HistoryFile.Open(hs.symbol[hSet], periods[i], hs.description[hSet], hs.digits[hSet], hs.format[hSet], FILE_READ|FILE_WRITE);
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
 * @param  string symbol      - Symbol des Instruments
 * @param  int    timeframe   - Timeframe der Zeitreihe
 * @param  string description - Beschreibung des Instruments (falls die Historydatei neu erstellt wird)
 * @param  int    digits      - Digits der Werte             (falls die Historydatei neu erstellt wird)
 * @param  int    format      - Datenformat der Zeitreihe    (falls die Historydatei neu erstellt wird)
 * @param  int    mode        - Access-Mode: FILE_READ|FILE_WRITE
 *
 * @return int - • Dateihandle
 *               • -1, falls nur FILE_READ angegeben wurde und die Datei nicht existiert
 *               • NULL, falls ein anderer Fehler auftrat
 *
 *
 * NOTES: (1) Das Dateihandle kann nicht modul-übergreifend verwendet werden.
 *        (2) Mit den MQL-Dateifunktionen können je Modul maximal 32 Dateien gleichzeitig offen gehalten werden.
 */
int HistoryFile.Open(string symbol, int timeframe, string description, int digits, int format, int mode) {
   // Validierung
   if (!StringLen(symbol))                    return(_NULL(catch("HistoryFile.Open(1)  illegal parameter symbol = "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER)));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(_NULL(catch("HistoryFile.Open(2)  illegal parameter symbol = "+ DoubleQuoteStr(symbol) +" (max "+ MAX_SYMBOL_LENGTH +" characters)", ERR_INVALID_PARAMETER)));
   string symbolU = StringToUpper(symbol);
   if (timeframe <= 0)                        return(_NULL(catch("HistoryFile.Open(3)  invalid parameter timeframe = "+ timeframe, ERR_INVALID_PARAMETER)));
   if (!(mode & (FILE_READ|FILE_WRITE)))      return(_NULL(catch("HistoryFile.Open(4)  invalid file access mode = "+ mode +" (needs to be FILE_READ and/or FILE_WRITE)", ERR_INVALID_PARAMETER)));
   mode &= (FILE_READ|FILE_WRITE);                                   // alle übrigen gesetzten Bits löschen
   bool read_only  = !(mode &  FILE_WRITE);
   bool read_write =  (mode & (FILE_READ|FILE_WRITE) != 0);
   bool write_only = !(mode &  FILE_READ);


   // (1) Datei öffnen
   string fileName = StringConcatenate(symbol, timeframe, ".hst");
   int    hFile    = FileOpenHistory(fileName, mode|FILE_BIN);

   // (1.1) read-only
   if (read_only) {
      int error = GetLastError();                                                   // ERR_FILE_NOT_FOUND abfangen
      if (hFile==999) /*&&*/ if (error==ERR_FILE_NOT_FOUND) return(-1);
      if (hFile <= 0) return(_NULL(catch("HistoryFile.Open(5)->FileOpenHistory(\""+ fileName +"\", FILE_READ) => "+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR))));
      // HistoryHeader auslesen
   }

   // (1.2) read-write
   else if (read_write) {
      if (hFile <= 0) return(_NULL(catch("HistoryFile.Open(6)->FileOpenHistory(\""+ fileName +"\", FILE_READ|FILE_WRITE) => "+ hFile, ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR))));
      // je nach Dateigröße HistoryHeader auslesen oder neuschreiben
   }

   // (1.3) write-only
   else if (write_only) {
      if (hFile <= 0) return(_NULL(catch("HistoryFile.Open(7)->FileOpenHistory(\""+ fileName +"\", FILE_WRITE) => "+ hFile, ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR))));
   }

   int bars, from, to, fileSize=FileSize(hFile), /*HISTORY_HEADER*/hh[]; InitializeByteBuffer(hh, HISTORY_HEADER.size);


   // (2) ggf. neuen HISTORY_HEADER schreiben
   if (write_only || (read_write && fileSize<HISTORY_HEADER.size)) {
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
    //hh.setSyncMark   (hh, 0          );                                           // wird beim Online-Refresh mit Server-SyncMark überschrieben
    //hh.setLastSync   (hh, 0          );                                           // wird beim Online-Refresh *nicht* überschrieben
      FileWriteArray(hFile, hh, 0, HISTORY_HEADER.intSize);
   }


   // (3.1) ggf. vorhandenen HISTORY_HEADER auslesen
   else if (read_only || fileSize > 0) {
      if (FileReadArray(hFile, hh, 0, HISTORY_HEADER.intSize) != HISTORY_HEADER.intSize) {
         FileClose(hFile);
         return(_NULL(catch("HistoryFile.Open(10)  invalid history file \""+ fileName +"\" (size="+ fileSize +")", ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR))));
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
   if (hFile >= ArraySize(hf.hFile))
      hf.__ResizeInternalArrays(hFile+1);

                    hf.hFile      [hFile] = hFile;
                    hf.name       [hFile] = fileName;
                    hf.readAccess [hFile] = mode & FILE_READ;
                    hf.writeAccess[hFile] = mode & FILE_WRITE;
                    hf.size       [hFile] = fileSize;

   ArraySetIntArray(hf.header,     hFile, hh);                       // entspricht: hf.header[hFile] = hh;
                    hf.format     [hFile] = hh.Format(hh);
                    hf.symbol     [hFile] = hh.Symbol(hh);
                    hf.symbolU    [hFile] = symbolU;
                    hf.period     [hFile] = timeframe;
                    hf.periodSecs [hFile] = timeframe * MINUTES;
                    hf.digits     [hFile] = hh.Digits(hh);

                    hf.bars       [hFile] = bars;
                    hf.from       [hFile] = from;
                    hf.to         [hFile] = to;

   ArrayResize(hh, 0);

   if (!catch("HistoryFile.Open(11)"))
      return(hFile);
   return(NULL);
}


/**
 * Schließt die Historydatei mit dem angegebenen Handle. Die Datei muß vorher mit HistoryFile.Open() geöffnet worden sein.
 *
 * @param  int hFile - Dateihandle
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile.Close(int hFile) {
   if (hFile <= 0)                      return(!catch("HistoryFile.Close(1)  invalid file handle "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile.Close(2)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile.Close(3)  unknown file handle "+ hFile, ERR_RUNTIME_ERROR));
   }
   else hf.hFile.lastValid = NULL;

   if (hf.hFile[hFile] < 0)                    return(true);         // Handle wurde bereits geschlossen (kann ignoriert werden)
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
 * @param  int      hFile - Dateihandle der Historydatei
 * @param  datetime time  - Zeitpunkt des Ticks
 * @param  double   value - Datenwert
 * @param  int      flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                          HST_COLLECT_TICKS: sammelt aufeinanderfolgende Ticks und schreibt die Daten erst beim jeweils nächsten BarOpen-Event
 *                          HST_FILL_GAPS:     füllt entstehende Gaps mit dem letzten Schlußkurs vor dem Gap
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


   bool   barExists[1], bHST_COLLECT_TICKS=flags & HST_COLLECT_TICKS, bHST_FILL_GAPS=flags & HST_FILL_GAPS;
   int    offset, iNull[];
   double data[5];


   // (1) Tick ggf. sammeln -----------------------------------------------------------------------------------------------------------------------
   if (bHST_COLLECT_TICKS) {
      if (time < hf.collectedBar.openTime[hFile] || time >= hf.collectedBar.closeTime[hFile]) {
         // (1.1) Collected-Bar leer oder Tick gehört zu anderer Bar (davor oder dahinter)
         offset = HistoryFile.FindBar(hFile, time, barExists);                   // Offset der Bar, zu der der Tick gehört
         if (offset < 0)
            return(false);

         if (hf.collectedBar.openTime[hFile] == 0) {
            // (1.1.1) Collected-Bar leer
            if (barExists[0]) {                                                  // Bar-Initialisierung
               if (!HistoryFile.ReadBar(hFile, offset, iNull, data))             // vorhandene Bar in Collected-Bar einlesen (als Ausgangsbasis)
                  return(false);
               hf.collectedBar.data[hFile][BAR_O] =         data[BAR_O];         // Tick hinzufügen
               hf.collectedBar.data[hFile][BAR_H] = MathMax(data[BAR_H], value);
               hf.collectedBar.data[hFile][BAR_L] = MathMin(data[BAR_L], value);
               hf.collectedBar.data[hFile][BAR_C] =                      value;
               hf.collectedBar.data[hFile][BAR_V] =         data[BAR_V] + 1;
            }
            else {
               hf.collectedBar.data[hFile][BAR_O] = value;                       // Bar existiert nicht: neue Bar beginnen
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

            if (!HistoryFile.WriteTickBar(hFile, flags))
               return(false);
            hf.collectedBar.data[hFile][BAR_O] = value;                          // neue Bar beginnen
            hf.collectedBar.data[hFile][BAR_H] = value;
            hf.collectedBar.data[hFile][BAR_L] = value;
            hf.collectedBar.data[hFile][BAR_C] = value;
            hf.collectedBar.data[hFile][BAR_V] = 1;
         }
         hf.collectedBar.offset       [hFile] = offset;
         hf.collectedBar.openTime     [hFile] = time - time % hf.periodSecs[hFile];
         hf.collectedBar.closeTime    [hFile] = hf.collectedBar.openTime [hFile] + hf.periodSecs[hFile];
         hf.collectedBar.nextCloseTime[hFile] = hf.collectedBar.closeTime[hFile] + hf.periodSecs[hFile];
      }
      else {
         // (1.2) Tick gehört zur Collected-Bar
         //.collectedBar.data[hFile][BAR_O] = ...                                // unverändert
         hf.collectedBar.data[hFile][BAR_H] = MathMax(hf.collectedBar.data[hFile][BAR_H], value);
         hf.collectedBar.data[hFile][BAR_L] = MathMin(hf.collectedBar.data[hFile][BAR_L], value);
         hf.collectedBar.data[hFile][BAR_C] = value;
         hf.collectedBar.data[hFile][BAR_V]++;
      }
      return(true);
   }
   // ---------------------------------------------------------------------------------------------------------------------------------------------


   // (2) gefüllte Collected-Bar schreiben --------------------------------------------------------------------------------------------------------
   if (hf.collectedBar.offset[hFile] >= 0) {                                     // HST_COLLECT_TICKS wechselte zur Laufzeit
      bool tick_in_collectedBar = (time >= hf.collectedBar.openTime[hFile] && time < hf.collectedBar.closeTime[hFile]);
      if (tick_in_collectedBar) {
       //hf.collectedBar.data[hFile][BAR_O] = ... (unverändert)                  // Tick zur Collected-Bar hinzufügen
         hf.collectedBar.data[hFile][BAR_H] = MathMax(hf.collectedBar.data[hFile][BAR_H], value);
         hf.collectedBar.data[hFile][BAR_L] = MathMin(hf.collectedBar.data[hFile][BAR_L], value);
         hf.collectedBar.data[hFile][BAR_C] = value;
         hf.collectedBar.data[hFile][BAR_V]++;
      }
      if (!HistoryFile.WriteTickBar(hFile, flags))                               // Collected-Bar schreiben (unwichtig, ob komplett, da HST_COLLECT_TICKS=Off)
         return(false);
      hf.collectedBar.offset       [hFile] = -1;                                 // Collected-Bar zurücksetzen
      hf.collectedBar.openTime     [hFile] =  0;
      hf.collectedBar.closeTime    [hFile] =  0;
      hf.collectedBar.nextCloseTime[hFile] =  0;

      if (tick_in_collectedBar)
         return(true);
   }
   // ---------------------------------------------------------------------------------------------------------------------------------------------


   // (3) Tick schreiben --------------------------------------------------------------------------------------------------------------------------
   datetime openTime = time - time%hf.periodSecs[hFile];                      // OpenTime der Tickbar ermitteln
   offset = HistoryFile.FindBar(hFile, openTime, barExists);                  // Offset der Tickbar ermitteln
   if (offset < 0)
      return(false);

   if (barExists[0])                                                          // existierende Bar aktualisieren...
      return(HistoryFile.UpdateBar(hFile, offset, value));

   data[BAR_O] = value;                                                       // ...oder neue Bar einfügen
   data[BAR_H] = value;
   data[BAR_L] = value;
   data[BAR_C] = value;
   data[BAR_V] = 1;
   return(HistoryFile.InsertBar(hFile, offset, openTime, data, flags));
   // ---------------------------------------------------------------------------------------------------------------------------------------------
}


/**
 * Findet den Offset der Bar innerhalb einer Historydatei, die den angegebenen Zeitpunkt abdeckt, und signalisiert, ob an diesem Offset
 * bereits eine Bar existiert. Eine Bar existiert z.B. dann nicht, wenn die Zeitreihe am angegebenen Zeitpunkt eine Lücke aufweist oder
 * wenn der Zeitpunkt außerhalb des von der Zeitreihe abgedeckten Datenbereichs liegt.
 *
 * @param  int      hFile          - Dateihandle der Historydatei
 * @param  datetime time           - Zeitpunkt
 * @param  bool     lpBarExists[1] - Zeiger auf Variable, die nach Rückkehr anzeigt, ob die Bar am zurückgegebenen Offset existiert
 *                                   (als Array implementiert, um Zeigerübergabe an eine Library zu ermöglichen)
 *                                   TRUE:  Bar existiert       (zum Aktualisieren dieser Bar muß HistoryFile.UpdateBar() verwendet werden)
 *                                   FALSE: Bar existiert nicht (zum Aktualisieren dieser Bar muß HistoryFile.InsertBar() verwendet werden)
 *
 * @return int - Bar-Offset oder -1 (EMPTY), falls ein Fehler auftrat
 */
int HistoryFile.FindBar(int hFile, datetime time, bool &lpBarExists[]) {
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

   // OpenTime der entsprechenden Bar berechnen
   time -= time%(hhs.Period(hf.header, hFile)*MINUTES);

   // (1) Zeitpunkt ist der Zeitpunkt der letzten Bar          // die beiden am häufigsten auftretenden Fälle zu Beginn prüfen
   if (time == hf.to[hFile]) {
      lpBarExists[0] = true;
      return(hf.bars[hFile] - 1);
   }

   // (2) Zeitpunkt liegt zeitlich nach der letzten Bar        // die beiden am häufigsten auftretenden Fälle zu Beginn prüfen
   if (time > hf.to[hFile]) {
      lpBarExists[0] = false;
      return(hf.bars[hFile]);
   }

   // (3) History leer
   if (hf.bars[hFile] == 0) {
      lpBarExists[0] = false;
      return(0);
   }

   // (4) Zeitpunkt ist der Zeitpunkt der ersten Bar
   if (time == hf.from[hFile]) {
      lpBarExists[0] = true;
      return(0);
   }

   // (5) Zeitpunkt liegt zeitlich vor der ersten Bar
   if (time < hf.from[hFile]) {
      lpBarExists[0] = false;
      return(0);
   }

   // (6) Zeitpunkt liegt irgendwo innerhalb der Zeitreihe
   int offset;
   return(_EMPTY(catch("HistoryFile.FindBar(6)  Suche nach Zeitpunkt innerhalb der Zeitreihe noch nicht implementiert", ERR_NOT_IMPLEMENTED)));

   if (!catch("HistoryFile.FindBar(7)", ERR_NOT_IMPLEMENTED))
      return(offset);
   return(EMPTY);
}


/**
 * Liest die Bar am angegebenen Offset einer Historydatei.
 *
 * @param  int      hFile   - Dateihandle der Historydatei
 * @param  int      offset  - Offset der Bar (relativ zum History-Header; Offset 0 ist älteste Bar)
 * @param  datetime time[1] - Array zur Aufnahme von Bar-Time
 * @param  double   data[5] - Array zur Aufnahme der übrigen Bar-Daten (OHLCV)
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile.ReadBar(int hFile, int offset, datetime &time[], double &data[]) {
   if (hFile <= 0)                             return(!catch("HistoryFile.ReadBar(1)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile))        return(!catch("HistoryFile.ReadBar(2)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)                return(!catch("HistoryFile.ReadBar(3)  invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)                return(!catch("HistoryFile.ReadBar(4)  invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (offset < 0 || offset >= hf.bars[hFile]) return(!catch("HistoryFile.ReadBar(5)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER));
   if (ArraySize(time) < 1) ArrayResize(time, 1);
   if (ArraySize(data) < 5) ArrayResize(data, 5);

   // Bar lesen
   int position = HISTORY_HEADER.size + offset*HISTORY_BAR_400.size;
   if (!FileSeek(hFile, position, SEEK_SET))
      return(!catch("HistoryFile.ReadBar(6)"));

   time[0] = FileReadInteger(hFile);
             FileReadArray  (hFile, data, 0, 5);

   hf.currentBar.offset       [hFile]        = offset;                              // Cache aktualisieren
   hf.currentBar.openTime     [hFile]        = time[0];
   hf.currentBar.closeTime    [hFile]        = time[0] + hf.periodSecs[hFile];
   hf.currentBar.nextCloseTime[hFile]        = time[0] + hf.periodSecs[hFile]<<1;   // schneller für * 2
   hf.currentBar.data         [hFile][BAR_O] = data[BAR_O];
   hf.currentBar.data         [hFile][BAR_H] = data[BAR_H];
   hf.currentBar.data         [hFile][BAR_L] = data[BAR_L];
   hf.currentBar.data         [hFile][BAR_C] = data[BAR_C];
   hf.currentBar.data         [hFile][BAR_V] = data[BAR_V];

   return(!catch("HistoryFile.ReadBar(7)"));
}


/**
 * Aktualisiert die Bar am angegebenen Offset einer Historydatei.
 *
 * @param  int    hFile  - Dateihandle der Historydatei
 * @param  int    offset - Offset der zu aktualisierenden Bar innerhalb der Zeitreihe
 * @param  double value  - hinzuzufügender Wert
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

   // (1) Bar ggf. neu in den Cache einlesen...
   if (offset != hf.currentBar.offset[hFile]) {
      int    time[1];
      double data[5];
      if (!HistoryFile.ReadBar(hFile, offset, time, data))
         return(false);
   }

   // (2) ...und zur Performancesteigerung direkt im Cache modifizieren
 //hf.currentBar.data[hFile][BAR_O] = ...                                     // unverändert
   hf.currentBar.data[hFile][BAR_H] = MathMax(hf.currentBar.data[hFile][BAR_H], value);
   hf.currentBar.data[hFile][BAR_L] = MathMin(hf.currentBar.data[hFile][BAR_L], value);
   hf.currentBar.data[hFile][BAR_C] = value;
   hf.currentBar.data[hFile][BAR_V]++;

   // (3) Bar schreiben
   return(HistoryFile.WriteCurrentBar(hFile));
}


/**
 * Fügt eine neue Bar am angegebenen Offset einer Historydatei ein. Die Funktion überprüft *nicht* die Plausibilität der einzufügenden Daten.
 *
 * @param  int      hFile   - Dateihandle der Historydatei
 * @param  int      offset  - Offset der einzufügenden Bar innerhalb der Zeitreihe (die erste Bar hat den Offset 0)
 * @param  datetime time    - Bar-Time
 * @param  double   data[5] - Bardaten
 * @param  int      flags   - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                            HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Zur Performancesteigerung werden die Tickdaten nicht zusätzlich validiert.
 */
bool HistoryFile.InsertBar(int hFile, int offset, datetime time, double data[], int flags=NULL) {
   if (hFile <= 0)                      return(!catch("HistoryFile.InsertBar(1)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile.InsertBar(2)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile.InsertBar(3)  invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile.InsertBar(4)  invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (offset < 0)                      return(!catch("HistoryFile.InsertBar(5)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER));
   if (time  <= 0)                      return(!catch("HistoryFile.InsertBar(6)  invalid parameter time = "+ time, ERR_INVALID_PARAMETER));
   if (ArraySize(data) != 5)            return(!catch("HistoryFile.InsertBar(7)  invalid size of parameter data[] = "+ ArraySize(data), ERR_INCOMPATIBLE_ARRAYS));


   // (1) ggf. Lücke für neue Bar schaffen
   if (offset < hf.bars[hFile]) {
      if (!HistoryFile.MoveBars(hFile, offset, offset+1))
         return(false);
   }

   // (2) Bar schreiben
   return(HistoryFile.WriteBar(hFile, offset, time, data, flags));
}


/**
 * Schreibt eine Bar in die angegebene Historydatei. Eine ggf. vorhandene Bar mit dem selben Open-Zeitpunkt wird überschrieben.
 *
 * @param  int      hFile   - Dateihandle der Historydatei
 * @param  int      offset  - Offset der zu schreibenden Bar (relativ zum Dateiheader; Offset 0 ist die älteste Bar)
 * @param  datetime time    - Bar-Time
 * @param  double   data[5] - Bar-Daten (OHLCV)
 * @param  int      flags   - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                            HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Zur Performancesteigerung werden die Bardaten *nicht* zusätzlich validiert.
 */
bool HistoryFile.WriteBar(int hFile, int offset, datetime time, double data[], int flags=NULL) {
   if (hFile <= 0)                      return(!catch("HistoryFile.WriteBar(1)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile.WriteBar(2)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile.WriteBar(3)  invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile.WriteBar(4)  invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }
   if (offset < 0)                      return(!catch("HistoryFile.WriteBar(5)  invalid parameter offset = "+ offset, ERR_INVALID_PARAMETER));
   if (time  <= 0)                      return(!catch("HistoryFile.WriteBar(6)  invalid parameter time = "+ time, ERR_INVALID_PARAMETER));
   if (ArraySize(data) != 5)            return(!catch("HistoryFile.WriteBar(7)  invalid size of parameter data[] = "+ ArraySize(data), ERR_INCOMPATIBLE_ARRAYS));


   // (1) Bar schreiben
   int position = HISTORY_HEADER.size + offset*HISTORY_BAR_400.size;
   if (!FileSeek(hFile, position, SEEK_SET))
      return(!catch("HistoryFile.WriteBar(8)"));

   FileWriteInteger(hFile, time);
   FileWriteArray  (hFile, data, 0, 5);


   // (2) interne Daten aktualisieren
   if (offset >= hf.bars[hFile]) { hf.size                    [hFile]        = position + HISTORY_BAR_400.size;
                                   hf.bars                    [hFile]        = offset + 1; }
   if (offset == 0)                hf.from                    [hFile]        = time;
   if (offset == hf.bars[hFile]-1) hf.to                      [hFile]        = time;

                                   hf.currentBar.offset       [hFile]        = offset;
                                   hf.currentBar.openTime     [hFile]        = time;
                                   hf.currentBar.closeTime    [hFile]        = time + hf.periodSecs[hFile];
                                   hf.currentBar.nextCloseTime[hFile]        = time + hf.periodSecs[hFile]<<1;
                                   hf.currentBar.data         [hFile][BAR_O] = data[BAR_O];
                                   hf.currentBar.data         [hFile][BAR_H] = data[BAR_H];
                                   hf.currentBar.data         [hFile][BAR_L] = data[BAR_L];
                                   hf.currentBar.data         [hFile][BAR_C] = data[BAR_C];
                                   hf.currentBar.data         [hFile][BAR_V] = data[BAR_V];

   return(!catch("HistoryFile.WriteBar(9)"));
}


/**
 * Schreibt die aktuellen Bardaten in die Historydatei.
 *
 * @param  int hFile - Dateihandle der Historydatei
 * @param  int flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                     HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
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

   // (1) Bar schreiben
   int position = HISTORY_HEADER.size + offset*HISTORY_BAR_400.size;
   if (!FileSeek(hFile, position, SEEK_SET))
      return(!catch("HistoryFile.WriteCurrentBar(6)"));

   FileWriteInteger(hFile, time                            );
   FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_O]);
   FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_L]);
   FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_H]);
   FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_C]);
   FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_V]);


   // (2) interne Daten aktualisieren
   if (offset >= hf.bars[hFile]) { hf.size[hFile] = position + HISTORY_BAR_400.size;
                                   hf.bars[hFile] = offset + 1; }
   if (offset == 0)                hf.from[hFile] = time;
   if (offset == hf.bars[hFile]-1) hf.to  [hFile] = time;

   return(!catch("HistoryFile.WriteCurrentBar(7)"));
}


/**
 * Schreibt die zwischengespeicherten Tickdaten in die Historydatei.
 *
 * @param  int hFile - Dateihandle der Historydatei
 * @param  int flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                     HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile.WriteTickBar(int hFile, int flags=NULL) {
   if (hFile <= 0)                      return(!catch("HistoryFile.WriteTickBar(1)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
   if (hFile != hf.hFile.lastValid) {
      if (hFile >= ArraySize(hf.hFile)) return(!catch("HistoryFile.WriteTickBar(2)  invalid parameter hFile = "+ hFile, ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] == 0)         return(!catch("HistoryFile.WriteTickBar(3)  invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_PARAMETER));
      if (hf.hFile[hFile] <  0)         return(!catch("HistoryFile.WriteTickBar(4)  invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_PARAMETER));
      hf.hFile.lastValid = hFile;
   }

   datetime time   = hf.collectedBar.openTime[hFile];
   int      offset = hf.collectedBar.offset  [hFile];
   if (offset < 0)                      return(!catch("HistoryFile.WriteTickBar(5)  invalid hf.collectedBar.offset["+ hFile +"] value = "+ offset, ERR_RUNTIME_ERROR));


   // (1) Bar schreiben
   int position = HISTORY_HEADER.size + offset*HISTORY_BAR_400.size;
   if (!FileSeek(hFile, position, SEEK_SET))
      return(!catch("HistoryFile.WriteTickBar(6)"));

   FileWriteInteger(hFile, time                         );
   FileWriteDouble (hFile, hf.collectedBar.data[hFile][BAR_O]);
   FileWriteDouble (hFile, hf.collectedBar.data[hFile][BAR_L]);
   FileWriteDouble (hFile, hf.collectedBar.data[hFile][BAR_H]);
   FileWriteDouble (hFile, hf.collectedBar.data[hFile][BAR_C]);
   FileWriteDouble (hFile, hf.collectedBar.data[hFile][BAR_V]);


   // (2) interne Daten aktualisieren
   if (offset >= hf.bars[hFile]) { hf.size                    [hFile]        = position + HISTORY_BAR_400.size;
                                   hf.bars                    [hFile]        = offset + 1; }
   if (offset == 0)                hf.from                    [hFile]        = time;
   if (offset == hf.bars[hFile]-1) hf.to                      [hFile]        = time;

                                   // Das Schreiben macht die Collected-Bar zusätzlich zur aktuellen Bar.
                                   hf.currentBar.offset       [hFile]        = hf.collectedBar.offset       [hFile];
                                   hf.currentBar.openTime     [hFile]        = hf.collectedBar.openTime     [hFile];
                                   hf.currentBar.closeTime    [hFile]        = hf.collectedBar.closeTime    [hFile];
                                   hf.currentBar.nextCloseTime[hFile]        = hf.collectedBar.nextCloseTime[hFile];
                                   hf.currentBar.data         [hFile][BAR_O] = hf.collectedBar.data         [hFile][BAR_O];
                                   hf.currentBar.data         [hFile][BAR_L] = hf.collectedBar.data         [hFile][BAR_L];
                                   hf.currentBar.data         [hFile][BAR_H] = hf.collectedBar.data         [hFile][BAR_H];
                                   hf.currentBar.data         [hFile][BAR_C] = hf.collectedBar.data         [hFile][BAR_C];
                                   hf.currentBar.data         [hFile][BAR_V] = hf.collectedBar.data         [hFile][BAR_V];

   return(!catch("HistoryFile.WriteTickBar(7)"));
}


/**
 *
 * @param  int hFile       - Dateihandle der Historydatei
 * @param  int startOffset
 * @param  int destOffset
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile.MoveBars(int hFile, int startOffset, int destOffset) {
   return(!catch("HistoryFile.MoveBars(1)", ERR_NOT_IMPLEMENTED));
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
int hf.__ResizeInternalArrays(int size) {
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
   }

   for (int i=size-1; i >= oldSize; i--) {                           // falls Arrays vergrößert werden, neue Offsets initialisieren
      hf.currentBar.offset[i] = -1;
      hf.collectedBar.offset   [i] = -1;
   }
   return(size);
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
int hs.__ResizeInternalArrays(int size) {
   if (size != ArraySize(hs.hSet)) {
      ArrayResize(hs.hSet,        size);
      ArrayResize(hs.symbol,      size);
      ArrayResize(hs.symbolU,     size);
      ArrayResize(hs.description, size);
      ArrayResize(hs.digits,      size);
      ArrayResize(hs.hFile,       size);
      ArrayResize(hs.format,      size);
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
 * Gibt den SyncMarker der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return datetime - SyncMarker oder -1 (EMPTY), falls ein Fehler auftrat
 */
int hf.SyncMark(int hFile) {
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
 * Gibt den Zeitpunkt der letzten Synchronisation der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return datetime - Zeitpunkt oder -1 (EMPTY), falls ein Fehler auftrat
 */
int hf.LastSync(int hFile) {
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
   warn = warn!=0;

   int error, size=ArraySize(hf.hFile);

   for (int i=0; i < size; i++) {
      if (hf.hFile[i] > 0) {
         if (warn) warn("history.CloseFiles(1)  open file handle "+ hf.hFile[i] +" found: "+ DoubleQuoteStr(hf.name[i]));

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
   ArrayResize(stack.orderSelections        , 0);

   // Daten einzelner HistoryFiles
   ArrayResize(hf.hFile                     , 0);
   ArrayResize(hf.name                      , 0);
   ArrayResize(hf.readAccess                , 0);
   ArrayResize(hf.writeAccess               , 0);
   ArrayResize(hf.size                      , 0);

   ArrayResize(hf.header                    , 0);
   ArrayResize(hf.format                    , 0);
   ArrayResize(hf.symbol                    , 0);
   ArrayResize(hf.symbolU                   , 0);
   ArrayResize(hf.period                    , 0);
   ArrayResize(hf.periodSecs                , 0);
   ArrayResize(hf.digits                    , 0);

   ArrayResize(hf.bars                      , 0);
   ArrayResize(hf.from                      , 0);
   ArrayResize(hf.to                        , 0);

   // Cache der aktuellen Bar
   ArrayResize(hf.currentBar.offset         , 0);
   ArrayResize(hf.currentBar.openTime       , 0);
   ArrayResize(hf.currentBar.closeTime      , 0);
   ArrayResize(hf.currentBar.nextCloseTime  , 0);
   ArrayResize(hf.currentBar.data           , 0);

   // Ticks einer ungespeicherten Bar
   ArrayResize(hf.collectedBar.offset       , 0);
   ArrayResize(hf.collectedBar.openTime     , 0);
   ArrayResize(hf.collectedBar.closeTime    , 0);
   ArrayResize(hf.collectedBar.nextCloseTime, 0);
   ArrayResize(hf.collectedBar.data         , 0);

   // Daten einzelner History-Sets
   ArrayResize(hs.hSet                      , 0);
   ArrayResize(hs.symbol                    , 0);
   ArrayResize(hs.symbolU                   , 0);
   ArrayResize(hs.description               , 0);
   ArrayResize(hs.digits                    , 0);
   ArrayResize(hs.hFile                     , 0);
   ArrayResize(hs.format                    , 0);
 //ArrayResize(periods...                                            // hat Initializer und wird nicht modifiziert
}
