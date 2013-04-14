/**
 * Funktionen zum Verwalten und Bearbeiten von Historydateien (Kursreihen im "history"-Verzeichnis).
 *
 * TODO: Alle Offsets analog zur Chart-Indizierung implementieren (Offset 0 = jüngste Bar)
 *
 * NOTE: Libraries use predefined variables of the module that called the library.
 */
#property library
#property stacksize 32768

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/library.mqh>


/**
 * Initialisierung
 *
 * @param  int    type               - Typ des aufrufenden Programms
 * @param  string name               - Name des aufrufenden Programms
 * @param  int    whereami           - ID der vom Terminal ausgeführten Root-Funktion: FUNC_INIT | FUNC_START | FUNC_DEINIT
 * @param  bool   isChart            - Hauptprogramm-Variable IsChart
 * @param  bool   isOfflineChart     - Hauptprogramm-Variable IsOfflineChart
 * @param  bool   loggingEnabled     - Hauptprogramm-Variable __LOG
 * @param  int    lpICUSTOM          - Speicheradresse der ICUSTOM-Struktur, falls das laufende Programm ein per iCustom() ausgeführter Indikator ist
 * @param  int    initFlags          - durchzuführende Initialisierungstasks (default: keine)
 * @param  int    uninitializeReason - der letzte UninitializeReason() des aufrufenden Programms
 *
 * @return int - Fehlerstatus
 */
int history_init(int type, string name, int whereami, bool isChart, bool isOfflineChart, bool loggingEnabled, int lpICUSTOM, int initFlags, int uninitializeReason) {
   prev_error = last_error;
   last_error = NO_ERROR;

   __TYPE__            |= type;
   __NAME__             = StringConcatenate(name, "::", WindowExpertName());
   __WHEREAMI__         = whereami;
   __InitFlags          = SumInts(__INIT_FLAGS__) | initFlags;
   IsChart              = isChart;
   IsOfflineChart       = isOfflineChart;
   __LOG                = loggingEnabled;
   __LOG_CUSTOM         = _bool(__InitFlags & INIT_CUSTOMLOG);
   __lpExecutionContext = lpICUSTOM;


   // globale Variablen re-initialisieren
   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits<<31>>31));               PipPoint          = PipPoints;
   Pip            = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   return(catch("history_init()"));
}


/**
 * Deinitialisierung
 *
 * @param  int deinitFlags        - durchzuführende Deinitialisierungstasks (default: keine)
 * @param  int uninitializeReason - der letzte UninitializeReason() des aufrufenden Programms
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: Bei VisualMode=Off und regulärem Testende (Testperiode zu Ende = REASON_UNDEFINED) bricht das Terminal komplexere deinit()-Funktionen
 *       verfrüht und nicht erst nach 2.5 Sekunden ab. Diese deinit()-Funktion wird deswegen u.U. nicht mehr ausgeführt.
 */
int history_deinit(int deinitFlags, int uninitializeReason) {
   __WHEREAMI__  = FUNC_DEINIT;
   __DeinitFlags = SumInts(__DEINIT_FLAGS__) | deinitFlags;
   return(NO_ERROR);
}


/**
 * Gibt den letzten in der Library aufgetretenen Fehler zurück. Der Aufruf dieser Funktion setzt den Fehlercode *nicht* zurück.
 *
 * @return int - Fehlerstatus
 */
int history_GetLastError() {
   return(last_error);
}


// Daten einzelner HistoryFiles ----------------------------------------------------------------------------------------------------------------------------
int      hf.hFile     [];                          // Dateihandle: Arrayindex, wenn Datei offen; kleiner/gleich 0, wenn geschlossen/ungültig
int      hf.hFile.valid = -1;                      // das zuletzt benutzte gültige Handle (um ein übergebenes Handle nicht ständig neu validieren zu müssen)
string   hf.name      [];                          // Dateiname
bool     hf.read      [];                          // ob das Handle Lese-Zugriff erlaubt
bool     hf.write     [];                          // ob das Handle Schreib-Zugriff erlaubt
int      hf.size      [];                          // aktuelle Größe der Datei (inkl. noch ungeschriebener Daten im Schreibpuffer)

int      hf.header    [][HISTORY_HEADER.intSize];  // History-Header der Datei
string   hf.symbol    [];                          // Symbol  (wie im History-Header)
int      hf.period    [];                          // Periode (wie im History-Header)
int      hf.periodSecs[];                          // Dauer einer Periode in Sekunden
int      hf.digits    [];                          // Digits  (wie im History-Header)

int      hf.bars      [];                          // Anzahl der Bars der Datei
datetime hf.from      [];                          // OpenTime der ersten Bar der Datei
datetime hf.to        [];                          // OpenTime der letzten Bar der Datei

// Cache der aktuellen Bar (Position des File-Pointers)
int      hf.currentBar.offset       [];            // relativ zum Header: Offset 0 ist älteste Bar
datetime hf.currentBar.openTime     [];            //
datetime hf.currentBar.closeTime    [];            //
datetime hf.currentBar.nextCloseTime[];            //
double   hf.currentBar.data         [][5];         // RateInfos (OHLCV)

// Ticks einer ungespeicherten Bar (bei HST_CACHE_TICKS=On)
int      hf.tickBar.offset          [];            // relativ zum Header: Offset 0 ist älteste Bar
datetime hf.tickBar.openTime        [];            //
datetime hf.tickBar.closeTime       [];            //
datetime hf.tickBar.nextCloseTime   [];            //
double   hf.tickBar.data            [][5];         // RateInfos (OHLCV)


// Daten einzelner History-Sets ----------------------------------------------------------------------------------------------------------------------------
int    h.hHst       [];                            // History-Handle: Arrayindex, wenn Handle gültig; kleiner/gleich 0, wenn Handle geschlossen/ungültig
int    h.hHst.valid = -1;                          // das zuletzt benutzte gültige Handle (um ein übergebenes Handle nicht ständig neu validieren zu müssen)
string h.symbol     [];                            // Symbol
string h.description[];                            // Symbolbeschreibung
int    h.digits     [];                            // Symboldigits
int    h.hFile      [][9];                         // HistoryFile-Handles des Sets je Timeframe
int    h.periods    [] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};


/**
 * Erzeugt für das angegebene Symbol eine neue History und gibt deren Handle zurück. Existiert für das angegebene Symbol bereits eine History,
 * wird sie gelöscht. Offene History-Handles für dasselbe Symbol werden geschlossen.
 *
 * @param  string symbol      - Symbol
 * @param  string description - Beschreibung des Symbols
 * @param  int    digits      - Digits der Datenreihe
 *
 * @return int - History-Handle oder 0, falls ein Fehler auftrat
 */
int CreateHistory(string symbol, string description, int digits) {
   int size = Max(ArraySize(h.hHst), 1);                             // ersten Index überspringen (0 ist kein gültiges Handle)
   h.ResizeArrays(size+1);

   // (1) neuen History-Datensatz erstellen
   h.hHst       [size] = size;
   h.symbol     [size] = symbol;
   h.description[size] = description;
   h.digits     [size] = digits;

   int sizeOfPeriods = ArraySize(h.periods);

   for (int i=0; i < sizeOfPeriods; i++) {
      int hFile = HistoryFile.Open(symbol, description, digits, h.periods[i], FILE_READ|FILE_WRITE);
      if (hFile <= 0)
         return(_ZERO(h.ResizeArrays(size)));                        // interne Arrays auf Ausgangsgröße zurücksetzen
      h.hFile[size][i] = hFile;
   }

   // (2) offene History-Handles desselben Symbols schließen
   for (i=size-1; i > 0; i--) {                                      // erstes (ungültiges) und letztes (gerade erzeugtes) Handle überspringen
      if (h.symbol[i] == symbol) {
         if (h.hHst[i] > 0)
            h.hHst[i] = -1;
      }
   }

   h.hHst.valid = size;
   return(size);
}


/**
 * Sucht die History des angegebenen Symbols und gibt ein Handle für sie zurück.
 *
 * @param  string symbol - Symbol
 *
 * @return int - History-Handle oder 0, falls keine History gefunden wurde oder ein Fehler auftrat
 */
int FindHistory(string symbol) {
   int size = ArraySize(h.hHst);

   // Schleife, da es mehrere Handles je Symbol, jedoch nur ein offenes (das letzte) geben kann
   for (int i=size-1; i > 0; i--) {                                  // auf Index 0 kann kein gültiges Handle liegen
      if (h.symbol[i] == symbol) {
         if (h.hHst[i] > 0)
            return(h.hHst[i]);
      }
   }
   return(0);
}


/**
 * Setzt die angegebene History zurück. Alle gespeicherten Kursreihen werden gelöscht.
 *
 * @param  int hHst - History-Handle
 *
 * @return bool - Erfolgsstatus
 */
bool ResetHistory(int hHst) {
   return(!catch("ResetHistory()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Fügt der History eines Symbols einen Tick hinzu. Der Tick wird in allen Timeframes als letzter Tick (Close) der entsprechenden Bars gespeichert.
 *
 * @param  int      hHst  - History-Handle des Symbols; @see GetHistory()
 * @param  datetime time  - Zeitpunkt des Ticks
 * @param  double   value - Datenwert
 * @param  int      flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                          HST_CACHE_TICKS: speichert aufeinanderfolgende Ticks zwischen und schreibt die Daten beim jeweils nächsten BarOpen-Event
 *                          HST_FILL_GAPS:   füllt entstehende Gaps mit dem letzten Schlußkurs vor dem Gap
 *
 * @return bool - Erfolgsstatus
 */
bool History.AddTick(int hHst, datetime time, double value, bool flags=NULL) {
   // Validierung
   if (hHst <= 0)                    return(_false(catch("History.AddTick(1)   invalid parameter hHst = "+ hHst, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hHst != h.hHst.valid) {
      if (hHst >= ArraySize(h.hHst)) return(_false(catch("History.AddTick(2)   invalid parameter hHst = "+ hHst, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (h.hHst[hHst] == 0)         return(_false(catch("History.AddTick(3)   invalid parameter hHst = "+ hHst +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (h.hHst[hHst] <  0)         return(_false(catch("History.AddTick(4)   invalid parameter hHst = "+ hHst +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      h.hHst.valid = hHst;
   }
   if (time <= 0)                    return(_false(catch("History.AddTick(5)   invalid parameter time = "+ time, ERR_INVALID_FUNCTION_PARAMVALUE)));

   // Dateihandles bis D1 (=> 7) holen und Tick jeweils hinzufügen
   for (int i=0; i < 7; i++) {
      if (!HistoryFile.AddTick(h.hFile[hHst][i], time, value, flags))
         return(false);
   }
   return(true);
}


/**
 * Fügt einer Historydatei einen Tick hinzu. Der Tick wird als letzter Tick (Close) der entsprechenden Bar gespeichert.
 *
 * @param  int      hFile - Dateihandle der Historydatei
 * @param  datetime time  - Zeitpunkt des Ticks
 * @param  double   value - Datenwert
 * @param  int      flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                          HST_CACHE_TICKS: speichert aufeinanderfolgende Ticks zwischen und schreibt die Daten beim jeweils nächsten BarOpen-Event
 *                          HST_FILL_GAPS:   füllt entstehende Gaps mit dem letzten Schlußkurs vor dem Gap
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Zur Performancesteigerung werden die Tickdaten nicht zusätzlich validiert.
 */
bool HistoryFile.AddTick(int hFile, datetime time, double value, int flags=NULL) {
   if (hFile <= 0)                      return(_false(catch("HistoryFile.AddTick(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_false(catch("HistoryFile.AddTick(2)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] == 0)         return(_false(catch("HistoryFile.AddTick(3)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <  0)         return(_false(catch("HistoryFile.AddTick(4)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hf.hFile.valid = hFile;
   }
   if (time <= 0)                       return(_false(catch("HistoryFile.AddTick(5)   invalid parameter time = "+ time, ERR_INVALID_FUNCTION_PARAMVALUE)));


   bool   barExists[1], bHST_CACHE_TICKS=flags & HST_CACHE_TICKS, bHST_FILL_GAPS=flags & HST_FILL_GAPS;
   int    offset, iNull[];
   double data[5];


   // (1) Tick zwischenspeichern --------------------------------------------------------------------------------------
   if (bHST_CACHE_TICKS) {
      if (time < hf.tickBar.openTime[hFile] || time >= hf.tickBar.closeTime[hFile]) {
         // (1.1) Queue leer oder Tick gehört zu anderer Bar (davor oder dahinter)
         offset = HistoryFile.FindBar(hFile, time, barExists);                // Offset der Bar, zu der der Tick gehört
         if (offset < 0)
            return(false);

         if (hf.tickBar.openTime[hFile] == 0) {
            // (1.1.1) Queue leer
            if (barExists[0]) {                                               // Bar-Initialisierung
               if (!HistoryFile.ReadBar(hFile, offset, iNull, data))          // vorhandene Bar in Queue einlesen (als Ausgangsbasis)
                  return(false);
               hf.tickBar.data[hFile][BAR_O] =         data[BAR_O];           // Tick hinzufügen
               hf.tickBar.data[hFile][BAR_H] = MathMax(data[BAR_H], value);
               hf.tickBar.data[hFile][BAR_L] = MathMin(data[BAR_L], value);
               hf.tickBar.data[hFile][BAR_C] =                      value;
               hf.tickBar.data[hFile][BAR_V] =         data[BAR_V] + 1;
            }
            else {
               hf.tickBar.data[hFile][BAR_O] = value;                         // Bar existiert nicht: neue Bar beginnen
               hf.tickBar.data[hFile][BAR_H] = value;
               hf.tickBar.data[hFile][BAR_L] = value;
               hf.tickBar.data[hFile][BAR_C] = value;
               hf.tickBar.data[hFile][BAR_V] = 1;
            }
         }
         else {
            // (1.1.2) Queue gefüllt und Queue-Bar ist komplett
            if (hf.tickBar.offset[hFile] >= hf.bars[hFile]) /*&&*/ if (!barExists[0])
               offset++;   // Wenn die Queue-Bar real noch nicht existiert, muß 'offset' vergrößert werden, falls die neue Bar ebenfalls nicht existiert.

            if (!HistoryFile.WriteTickBar(hFile, flags))
               return(false);
            hf.tickBar.data[hFile][BAR_O] = value;                            // neue Bar beginnen
            hf.tickBar.data[hFile][BAR_H] = value;
            hf.tickBar.data[hFile][BAR_L] = value;
            hf.tickBar.data[hFile][BAR_C] = value;
            hf.tickBar.data[hFile][BAR_V] = 1;
         }
         hf.tickBar.offset       [hFile] = offset;
         hf.tickBar.openTime     [hFile] = time - time % hf.periodSecs[hFile];
         hf.tickBar.closeTime    [hFile] = hf.tickBar.openTime [hFile] + hf.periodSecs[hFile];
         hf.tickBar.nextCloseTime[hFile] = hf.tickBar.closeTime[hFile] + hf.periodSecs[hFile];
      }
      else {
         // (1.2) Tick gehört zur Queue-Bar
         //.tickBar.data[hFile][BAR_O] = ...                                  // unverändert
         hf.tickBar.data[hFile][BAR_H] = MathMax(hf.tickBar.data[hFile][BAR_H], value);
         hf.tickBar.data[hFile][BAR_L] = MathMin(hf.tickBar.data[hFile][BAR_L], value);
         hf.tickBar.data[hFile][BAR_C] = value;
         hf.tickBar.data[hFile][BAR_V]++;
      }
      return(true);
   }
   // -----------------------------------------------------------------------------------------------------------------


   // (2) gefüllte Queue-Bar schreiben --------------------------------------------------------------------------------
   if (hf.tickBar.offset[hFile] >= 0) {                                       // HST_CACHE_TICKS wechselte zur Laufzeit
      bool tick_in_queue = (time >= hf.tickBar.openTime[hFile] && time < hf.tickBar.closeTime[hFile]);
      if (tick_in_queue) {
         //.tickBar.data[hFile][BAR_O] = ...                                  // Tick zur Queue hinzufügen
         hf.tickBar.data[hFile][BAR_H] = MathMax(hf.tickBar.data[hFile][BAR_H], value);
         hf.tickBar.data[hFile][BAR_L] = MathMin(hf.tickBar.data[hFile][BAR_L], value);
         hf.tickBar.data[hFile][BAR_C] = value;
         hf.tickBar.data[hFile][BAR_V]++;
      }
      if (!HistoryFile.WriteTickBar(hFile, flags))                            // Queue-Bar schreiben (unwichtig, ob komplett, da HST_CACHE_TICKS=Off)
         return(false);
      hf.tickBar.offset       [hFile] = -1;                                   // Queue-Bar zurücksetzen
      hf.tickBar.openTime     [hFile] =  0;
      hf.tickBar.closeTime    [hFile] =  0;
      hf.tickBar.nextCloseTime[hFile] =  0;

      if (tick_in_queue)
         return(true);
   }
   // -----------------------------------------------------------------------------------------------------------------


   // (3) Tick schreiben ----------------------------------------------------------------------------------------------
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
   // -----------------------------------------------------------------------------------------------------------------
}


/**
 * Findet den Offset der Bar innerhalb einer Historydatei, die den angegebenen Zeitpunkt abdeckt, und signalisiert, ob an diesem
 * Offset bereits eine Bar existiert. Eine Bar existiert z.B. dann nicht, wenn die Zeitreihe am angegebenen Zeitpunkt eine Lücke enthält oder
 * wenn der Zeitpunkt außerhalb des von der Zeitreihe abgedeckten Datenbereichs liegt.
 *
 * @param  int      hFile          - Dateihandle der Historydatei
 * @param  datetime time           - Zeitpunkt
 * @param  bool     lpBarExists[1] - Zeiger auf Variable, die nach Rückkehr anzeigt, ob die Bar am zurückgegebenen Offset existiert
 *                                   (als Array implementiert, um Zeigerübergabe an eine Library zu ermöglichen)
 *                                   TRUE:  Bar existiert       (zum Aktualisieren dieser Bar ist HistoryFile.UpdateBar() zu verwenden)
 *                                   FALSE: Bar existiert nicht (zum Aktualisieren dieser Bar ist HistoryFile.InsertBar() zu verwenden)
 *
 * @return int - Bar-Offset oder -1, falls ein Fehler auftrat
 */
int HistoryFile.FindBar(int hFile, datetime time, bool &lpBarExists[]) {
   if (hFile <= 0)                      return(_int(-1, catch("HistoryFile.FindBar(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_int(-1, catch("HistoryFile.FindBar(2)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] == 0)         return(_int(-1, catch("HistoryFile.FindBar(3)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <  0)         return(_int(-1, catch("HistoryFile.FindBar(4)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hf.hFile.valid = hFile;
   }
   if (time <= 0)                       return(_int(-1, catch("HistoryFile.FindBar(5)   invalid parameter time = "+ time, ERR_INVALID_FUNCTION_PARAMVALUE)));
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
   return(_int(-1, catch("HistoryFile.FindBar(6)   Suche nach Zeitpunkt innerhalb der Zeitreihe noch nicht implementiert", ERR_FUNCTION_NOT_IMPLEMENTED)));

   if (IsError(last_error|catch("HistoryFile.FindBar(7)", ERR_FUNCTION_NOT_IMPLEMENTED)))
      return(-1);
   return(offset);
}


/**
 * Liest die Bar am angegebenen Offset einer Historydatei.
 *
 * @param  int      hFile   - Dateihandle der Historydatei
 * @param  int      offset  - Offset der Bar (relativ zum History-Header; Offset 0 ist älteste Bar)
 * @param  datetime time[1] - Array zur Aufnahme von RateInfo.Time
 * @param  double   data[5] - Array zur Aufnahme der übrigen RateInfo-Daten (OHLCV)
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile.ReadBar(int hFile, int offset, datetime &time[], double &data[]) {
   if (hFile <= 0)                             return(_false(catch("HistoryFile.ReadBar(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile))        return(_false(catch("HistoryFile.ReadBar(2)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] == 0)                return(_false(catch("HistoryFile.ReadBar(3)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <  0)                return(_false(catch("HistoryFile.ReadBar(4)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hf.hFile.valid = hFile;
   }
   if (offset < 0 || offset >= hf.bars[hFile]) return(_false(catch("HistoryFile.ReadBar(5)   invalid parameter offset = "+ offset, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (ArraySize(time) < 1) ArrayResize(time, 1);
   if (ArraySize(data) < 5) ArrayResize(data, 5);                    // struct RateInfo {
                                                                     //    int    time;      //  4
   // Bar lesen                                                      //    double open;      //  8
   int position = HISTORY_HEADER.size + offset*BAR.size;             //    double low;       //  8
   if (!FileSeek(hFile, position, SEEK_SET))                         //    double high;      //  8
      return(_false(catch("HistoryFile.ReadBar(6)")));               //    double close;     //  8
                                                                     //    double volume;    //  8
   time[0] = FileReadInteger(hFile);                                 // };                   // 44 byte
             FileReadArray  (hFile, data, 0, 5);

   hf.currentBar.offset       [hFile]        = offset;               // Cache aktualisieren
   hf.currentBar.openTime     [hFile]        = time[0];
   hf.currentBar.closeTime    [hFile]        = time[0] + hf.periodSecs[hFile];
   hf.currentBar.nextCloseTime[hFile]        = time[0] + hf.periodSecs[hFile]<<1;   // schneller für * 2
   hf.currentBar.data         [hFile][BAR_O] = data[BAR_O];
   hf.currentBar.data         [hFile][BAR_H] = data[BAR_H];
   hf.currentBar.data         [hFile][BAR_L] = data[BAR_L];
   hf.currentBar.data         [hFile][BAR_C] = data[BAR_C];
   hf.currentBar.data         [hFile][BAR_V] = data[BAR_V];

   return(!last_error|catch("HistoryFile.ReadBar(7)"));
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
   if (hFile <= 0)                             return(_false(catch("HistoryFile.UpdateBar(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile))        return(_false(catch("HistoryFile.UpdateBar(2)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] == 0)                return(_false(catch("HistoryFile.UpdateBar(3)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <  0)                return(_false(catch("HistoryFile.UpdateBar(4)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hf.hFile.valid = hFile;
   }
   if (offset < 0 || offset >= hf.bars[hFile]) return(_false(catch("HistoryFile.UpdateBar(5)   invalid parameter offset = "+ offset, ERR_INVALID_FUNCTION_PARAMVALUE)));

   // (1) Bar ggf. neu in den Cache einlesen...
   if (offset != hf.currentBar.offset[hFile]) {
      int    time[1];
      double data[5];
      if (!HistoryFile.ReadBar(hFile, offset, time, data))
         return(false);
   }

   // (2) ...und zur Performancesteigerung direkt im Cache modifizieren
 //hf.currentBar.data[hFile][BAR_O] = ...                            // unverändert
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
 * @param  datetime time    - BAR.Time
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
   if (hFile <= 0)                      return(_false(catch("HistoryFile.InsertBar(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_false(catch("HistoryFile.InsertBar(2)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] == 0)         return(_false(catch("HistoryFile.InsertBar(3)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <  0)         return(_false(catch("HistoryFile.InsertBar(4)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hf.hFile.valid = hFile;
   }
   if (offset < 0)                      return(_false(catch("HistoryFile.InsertBar(5)   invalid parameter offset = "+ offset, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (time  <= 0)                      return(_false(catch("HistoryFile.InsertBar(6)   invalid parameter time = "+ time, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (ArraySize(data) != 5)            return(_false(catch("HistoryFile.InsertBar(7)   invalid size of parameter data[] = "+ ArraySize(data), ERR_INCOMPATIBLE_ARRAYS)));


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
 * @param  datetime time    - RateInfo.Time
 * @param  double   data[5] - RateInfo-Daten (OHLCV)
 * @param  int      flags   - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                            HST_FILL_GAPS: beim Schreiben entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Zur Performancesteigerung werden die Bardaten *nicht* zusätzlich validiert.
 */
bool HistoryFile.WriteBar(int hFile, int offset, datetime time, double data[], int flags=NULL) {
   if (hFile <= 0)                      return(_false(catch("HistoryFile.WriteBar(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_false(catch("HistoryFile.WriteBar(2)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] == 0)         return(_false(catch("HistoryFile.WriteBar(3)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <  0)         return(_false(catch("HistoryFile.WriteBar(4)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hf.hFile.valid = hFile;
   }
   if (offset < 0)                      return(_false(catch("HistoryFile.WriteBar(5)   invalid parameter offset = "+ offset, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (time  <= 0)                      return(_false(catch("HistoryFile.WriteBar(6)   invalid parameter time = "+ time, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (ArraySize(data) != 5)            return(_false(catch("HistoryFile.WriteBar(7)   invalid size of parameter data[] = "+ ArraySize(data), ERR_INCOMPATIBLE_ARRAYS)));


   // (1) Bar schreiben
   int position = HISTORY_HEADER.size + offset*BAR.size;             // struct RateInfo {
   if (!FileSeek(hFile, position, SEEK_SET))                         //    int    time;      //  4
      return(_false(catch("HistoryFile.WriteBar(8)")));              //    double open;      //  8
                                                                     //    double low;       //  8
   FileWriteInteger(hFile, time);                                    //    double high;      //  8
   FileWriteArray  (hFile, data, 0, 5);                              //    double close;     //  8
                                                                     //    double volume;    //  8
                                                                     // };                   // 44 byte
   // (2) interne Daten aktualisieren
   if (offset >= hf.bars[hFile]) { hf.size                    [hFile]        = position + BAR.size;
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

   return(!last_error|catch("HistoryFile.WriteBar(9)"));
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
   if (hFile <= 0)                      return(_false(catch("HistoryFile.WriteCurrentBar(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_false(catch("HistoryFile.WriteCurrentBar(2)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] == 0)         return(_false(catch("HistoryFile.WriteCurrentBar(3)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <  0)         return(_false(catch("HistoryFile.WriteCurrentBar(4)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hf.hFile.valid = hFile;
   }

   datetime time   = hf.currentBar.openTime[hFile];
   int      offset = hf.currentBar.offset  [hFile];
   if (offset < 0)                      return(_false(catch("HistoryFile.WriteCurrentBar(5)   invalid hf.currentBar.offset["+ hFile +"] value = "+ offset, ERR_RUNTIME_ERROR)));

   // (1) Bar schreiben                                              // struct RateInfo {
   int position = HISTORY_HEADER.size + offset*BAR.size;             //    int    time;      //  4
   if (!FileSeek(hFile, position, SEEK_SET))                         //    double open;      //  8
      return(_false(catch("HistoryFile.WriteCurrentBar(6)")));       //    double low;       //  8
                                                                     //    double high;      //  8
   FileWriteInteger(hFile, time                            );        //    double close;     //  8
   FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_O]);        //    double volume;    //  8
   FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_L]);        // };                   // 44 byte
   FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_H]);
   FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_C]);
   FileWriteDouble (hFile, hf.currentBar.data[hFile][BAR_V]);


   // (2) interne Daten aktualisieren
   if (offset >= hf.bars[hFile]) { hf.size[hFile] = position + BAR.size;
                                   hf.bars[hFile] = offset + 1; }
   if (offset == 0)                hf.from[hFile] = time;
   if (offset == hf.bars[hFile]-1) hf.to  [hFile] = time;

   return(!last_error|catch("HistoryFile.WriteCurrentBar(7)"));
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
   if (hFile <= 0)                      return(_false(catch("HistoryFile.WriteTickBar(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_false(catch("HistoryFile.WriteTickBar(2)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] == 0)         return(_false(catch("HistoryFile.WriteTickBar(3)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <  0)         return(_false(catch("HistoryFile.WriteTickBar(4)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hf.hFile.valid = hFile;
   }

   datetime time   = hf.tickBar.openTime[hFile];
   int      offset = hf.tickBar.offset  [hFile];
   if (offset < 0)                      return(_false(catch("HistoryFile.WriteTickBar(5)   invalid hf.tickBar.offset["+ hFile +"] value = "+ offset, ERR_RUNTIME_ERROR)));


   // (1) Bar schreiben                                              // struct RateInfo {
   int position = HISTORY_HEADER.size + offset*BAR.size;             //    int    time;      //  4
   if (!FileSeek(hFile, position, SEEK_SET))                         //    double open;      //  8
      return(_false(catch("HistoryFile.WriteTickBar(6)")));          //    double low;       //  8
                                                                     //    double high;      //  8
   FileWriteInteger(hFile, time                         );           //    double close;     //  8
   FileWriteDouble (hFile, hf.tickBar.data[hFile][BAR_O]);           //    double volume;    //  8
   FileWriteDouble (hFile, hf.tickBar.data[hFile][BAR_L]);           // };                   // 44 byte
   FileWriteDouble (hFile, hf.tickBar.data[hFile][BAR_H]);
   FileWriteDouble (hFile, hf.tickBar.data[hFile][BAR_C]);
   FileWriteDouble (hFile, hf.tickBar.data[hFile][BAR_V]);


   // (2) interne Daten aktualisieren
   if (offset >= hf.bars[hFile]) { hf.size                    [hFile]        = position + BAR.size;
                                   hf.bars                    [hFile]        = offset + 1; }
   if (offset == 0)                hf.from                    [hFile]        = time;
   if (offset == hf.bars[hFile]-1) hf.to                      [hFile]        = time;

                                   // Das Schreiben macht die TickBar zusätzlich zur aktuellen Bar.
                                   hf.currentBar.offset       [hFile]        = hf.tickBar.offset       [hFile];
                                   hf.currentBar.openTime     [hFile]        = hf.tickBar.openTime     [hFile];
                                   hf.currentBar.closeTime    [hFile]        = hf.tickBar.closeTime    [hFile];
                                   hf.currentBar.nextCloseTime[hFile]        = hf.tickBar.nextCloseTime[hFile];
                                   hf.currentBar.data         [hFile][BAR_O] = hf.tickBar.data         [hFile][BAR_O];
                                   hf.currentBar.data         [hFile][BAR_L] = hf.tickBar.data         [hFile][BAR_L];
                                   hf.currentBar.data         [hFile][BAR_H] = hf.tickBar.data         [hFile][BAR_H];
                                   hf.currentBar.data         [hFile][BAR_C] = hf.tickBar.data         [hFile][BAR_C];
                                   hf.currentBar.data         [hFile][BAR_V] = hf.tickBar.data         [hFile][BAR_V];

   return(!last_error|catch("HistoryFile.WriteTickBar(7)"));
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
   return(!last_error|catch("HistoryFile.MoveBars()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Öffnet eine Historydatei und gibt das resultierende Dateihandle zurück. Ist der Access-Mode FILE_WRITE angegeben und die Datei existiert nicht,
 * wird sie erstellt und ein HISTORY_HEADER geschrieben.
 *
 * @param  string symbol      - Symbol des Instruments
 * @param  string description - Beschreibung des Instruments (falls die Historydatei neu erstellt wird)
 * @param  int    digits      - Digits der Werte             (falls die Historydatei neu erstellt wird)
 * @param  int    timeframe   - Timeframe der Zeitreihe
 * @param  int    mode        - Access-Mode: FILE_READ | FILE_WRITE
 *
 * @return int - Dateihandle
 *
 *
 * NOTE: Das zurückgegebene Handle darf nicht modul-übergreifend verwendet werden. Mit den MQL-Dateifunktionen können je Modul maximal 32 Dateien
 *       gleichzeitig offen gehalten werden.
 */
int HistoryFile.Open(string symbol, string description, int digits, int timeframe, int mode) {
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH)                      return(_ZERO(catch("HistoryFile.Open(1)   illegal parameter symbol = "+ symbol +" (length="+ StringLen(symbol) +")", ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (digits <  0)                                                return(_ZERO(catch("HistoryFile.Open(2)   illegal parameter digits = "+ digits, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (timeframe <= 0)                                             return(_ZERO(catch("HistoryFile.Open(3)   illegal parameter timeframe = "+ timeframe, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (_bool(mode & FILE_CSV) || !(mode & (FILE_READ|FILE_WRITE))) return(_ZERO(catch("HistoryFile.Open(4)   illegal history file access mode "+ FileAccessModeToStr(mode), ERR_INVALID_FUNCTION_PARAMVALUE)));

   string fileName = StringConcatenate(symbol, timeframe, ".hst");
   mode |= FILE_BIN;
   int hFile = FileOpenHistory(fileName, mode);
   if (hFile < 0)
      return(_ZERO(catch("HistoryFile.Open(5)->FileOpenHistory(\""+ fileName +"\")")));

   /*HISTORY_HEADER*/int hh[]; InitializeBuffer(hh, HISTORY_HEADER.size);

   int bars, from, to, fileSize=FileSize(hFile);

   if (fileSize < HISTORY_HEADER.size) {
      if (!(mode & FILE_WRITE)) {                                    // read-only mode
         FileClose(hFile);
         return(_ZERO(catch("HistoryFile.Open(6)   corrupted history file \""+ fileName +"\" (size = "+ fileSize +")", ERR_RUNTIME_ERROR)));
      }
      // neuen HISTORY_HEADER schreiben
      datetime now = TimeCurrent();                                  // TODO: ServerTime() implementieren (TimeCurrent() ist Zeit des letzten Ticks)
      hh.setVersion      (hh, 400        );
      hh.setDescription  (hh, description);
      hh.setSymbol       (hh, symbol     );
      hh.setPeriod       (hh, timeframe  );
      hh.setDigits       (hh, digits     );
      hh.setDbVersion    (hh, now        );                          // wird beim nächsten Online-Refresh mit Server-DbVersion überschrieben
      hh.setPrevDbVersion(hh, now        );                          // derselbe Wert, wird beim nächsten Online-Refresh *nicht* überschrieben
      FileWriteArray(hFile, hh, 0, ArraySize(hh));
      fileSize = HISTORY_HEADER.size;
   }
   else {
      // vorhandenen HISTORY_HEADER auslesen
      FileReadArray(hFile, hh, 0, ArraySize(hh));

      // Bar-Infos auslesen
      if (fileSize > HISTORY_HEADER.size) {
         bars = (fileSize-HISTORY_HEADER.size) / BAR.size;
         if (bars > 0) {
            from = FileReadInteger(hFile);
            FileSeek(hFile, HISTORY_HEADER.size + (bars-1)*BAR.size, SEEK_SET);
            to   = FileReadInteger(hFile);
         }
      }
   }

   // Daten zwischenspeichern
   if (hFile >= ArraySize(hf.hFile)) {
      hf.ResizeArrays(hFile+1);
   }
                    hf.hFile     [hFile] = hFile;
                    hf.name      [hFile] = fileName;
                    hf.read      [hFile] = mode & FILE_READ;
                    hf.write     [hFile] = mode & FILE_WRITE;
                    hf.size      [hFile] = fileSize;

   ArraySetIntArray(hf.header,    hFile, hh);                        // entspricht: hf.header[hFile] = hh;
                    hf.symbol    [hFile] = symbol;
                    hf.period    [hFile] = timeframe;
                    hf.periodSecs[hFile] = timeframe * MINUTES;
                    hf.digits    [hFile] = digits;

                    hf.bars      [hFile] = bars;
                    hf.from      [hFile] = from;
                    hf.to        [hFile] = to;

   hf.hFile.valid = hFile;

   ArrayResize(hh, 0);
   if (IsError(catch("HistoryFile.Open(7)")))
      return(0);
   return(hFile);
}


/**
 * Schließt die Historydatei mit dem angegebenen Dateihandle. Die Datei muß vorher mit HistoryFile.Open() geöffnet worden sein.
 *
 * @param  int hFile - Dateihandle
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile.Close(int hFile) {
   if (hFile <= 0)                      return(_false(catch("HistoryFile.Close(1)   invalid file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_false(catch("HistoryFile.Close(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
      if (hf.hFile[hFile] == 0)         return(_false(catch("HistoryFile.Close(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
   }
   else {
      hf.hFile.valid = -1;
   }

   if (hf.hFile[hFile] < 0)                                          // Datei ist bereits geschlossen worden
      return(true);

   int error = GetLastError();
   if (IsError(error))
      return(_false(catch("HistoryFile.Close(4)", error)));

   FileClose(hFile);
   hf.hFile[hFile] = -1;

   error = GetLastError();
   if (error == ERR_INVALID_FUNCTION_PARAMVALUE) {                   // Datei war bereits geschlossen: kann ignoriert werden
   }
   else if (IsError(error)) {
      return(_false(catch("HistoryFile.Close(5)", error)));
   }
   return(true);
}


/**
 * Setzt die Größe der internen HistoryFile-Datenarrays auf den angegebenen Wert.
 *
 * @param  int size - neue Größe
 *
 * @return int - neue Größe der Arrays
 */
/*private*/ int hf.ResizeArrays(int size) {
   int oldSize = ArraySize(hf.hFile);

   if (size != oldSize) {
      ArrayResize(hf.hFile,                    size);
      ArrayResize(hf.name,                     size);
      ArrayResize(hf.read,                     size);
      ArrayResize(hf.write,                    size);
      ArrayResize(hf.size,                     size);

      ArrayResize(hf.header,                   size);
      ArrayResize(hf.symbol,                   size);
      ArrayResize(hf.period,                   size);
      ArrayResize(hf.periodSecs,               size);
      ArrayResize(hf.digits,                   size);

      ArrayResize(hf.bars,                     size);
      ArrayResize(hf.from,                     size);
      ArrayResize(hf.to,                       size);

      ArrayResize(hf.currentBar.offset,        size);
      ArrayResize(hf.currentBar.openTime,      size);
      ArrayResize(hf.currentBar.closeTime,     size);
      ArrayResize(hf.currentBar.nextCloseTime, size);
      ArrayResize(hf.currentBar.data,          size);

      ArrayResize(hf.tickBar.offset,           size);
      ArrayResize(hf.tickBar.openTime,         size);
      ArrayResize(hf.tickBar.closeTime,        size);
      ArrayResize(hf.tickBar.nextCloseTime,    size);
      ArrayResize(hf.tickBar.data,             size);
   }

   for (int i=size-1; i >= oldSize; i--) {                           // falls Arrays vergrößert werden, neue Offsets initialisieren
      hf.currentBar.offset[i] = -1;
      hf.tickBar.offset   [i] = -1;
   }

   return(size);
}


/**
 * Setzt die Größe der internen History-Datenarrays auf den angegebenen Wert.
 *
 * @param  int size - neue Größe
 *
 * @return int - neue Größe der Arrays
 */
/*private*/ int h.ResizeArrays(int size) {
   if (size != ArraySize(h.hHst)) {
      ArrayResize(h.hHst,        size);
      ArrayResize(h.symbol,      size);
      ArrayResize(h.description, size);
      ArrayResize(h.digits,      size);
      ArrayResize(h.hFile,       size);
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
   if (hFile <= 0)                      return(_empty(catch("hf.Name(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_empty(catch("hf.Name(2)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_empty(catch("hf.Name(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_empty(catch("hf.Name(4)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.valid = hFile;
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
bool hf.Read(int hFile) {
   if (hFile <= 0)                      return(_false(catch("hf.Read(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_false(catch("hf.Read(2)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_false(catch("hf.Read(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_false(catch("hf.Read(4)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.valid = hFile;
   }
   return(hf.read[hFile]);
}


/**
 * Ob das Handle einer Historydatei Schreibzugriff erlaubt.
 *
 * @param  int hFile - Dateihandle
 *
 * @return bool - Ergebnis oder FALSE, falls ein Fehler auftrat
 */
bool hf.Write(int hFile) {
   if (hFile <= 0)                      return(_false(catch("hf.Write(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_false(catch("hf.Write(2)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_false(catch("hf.Write(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_false(catch("hf.Write(4)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.valid = hFile;
   }
   return(hf.write[hFile]);
}


/**
 * Gibt die aktuelle Größe der zu einem Handle gehörenden Historydatei zurück (inkl. noch ungeschriebener Daten im Schreibpuffer).
 *
 * @param  int hFile - Dateihandle
 *
 * @return int - Größe oder -1, falls ein Fehler auftrat
 */
int hf.Size(int hFile) {
   if (hFile <= 0)                      return(_int(-1, catch("hf.Size(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_int(-1, catch("hf.Size(2)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_int(-1, catch("hf.Size(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_int(-1, catch("hf.Size(4)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.valid = hFile;
   }
   return(hf.size[hFile]);
}


/**
 * Gibt die aktuelle Anzahl der Bars der zu einem Handle gehörenden Historydatei zurück (inkl. noch ungeschriebener Daten im Schreibpuffer).
 *
 * @param  int hFile - Dateihandle
 *
 * @return int - Anzahl oder -1, falls ein Fehler auftrat
 */
int hf.Bars(int hFile) {
   if (hFile <= 0)                      return(_int(-1, catch("hf.Bars(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_int(-1, catch("hf.Bars(2)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_int(-1, catch("hf.Bars(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_int(-1, catch("hf.Bars(4)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.valid = hFile;
   }
   return(hf.bars[hFile]);
}


/**
 * Gibt den Zeitpunkt der ältesten Bar der zu einem Handle gehörenden Historydatei zurück (inkl. noch ungeschriebener Daten im Schreibpuffer).
 *
 * @param  int hFile - Dateihandle
 *
 * @return datetime - Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime hf.From(int hFile) {
   if (hFile <= 0)                      return(_int(-1, catch("hf.From(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_int(-1, catch("hf.From(2)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_int(-1, catch("hf.From(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_int(-1, catch("hf.From(4)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.valid = hFile;
   }
   return(hf.from[hFile]);
}


/**
 * Gibt den Zeitpunkt der jüngsten Bar der zu einem Handle gehörenden Historydatei zurück (inkl. noch ungeschriebener Daten im Schreibpuffer).
 *
 * @param  int hFile - Dateihandle
 *
 * @return datetime - Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime hf.To(int hFile) {
   if (hFile <= 0)                      return(_int(-1, catch("hf.To(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_int(-1, catch("hf.To(2)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_int(-1, catch("hf.To(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_int(-1, catch("hf.To(4)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.valid = hFile;
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
   if (hFile <= 0)                      return(catch("hf.Header(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(catch("hf.Header(2)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(catch("hf.Header(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR));
                                        return(catch("hf.Header(4)   closed file handle "+ hFile, ERR_RUNTIME_ERROR));
      }
      hf.hFile.valid = hFile;
   }
   if (ArrayDimension(array) > 1)       return(catch("hf.Header(5)   too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS));

   ArrayResize(array, HISTORY_HEADER.intSize);                       // entspricht: array = hf.header[hFile];
   CopyMemory(GetBufferAddress(array), GetBufferAddress(hf.header) + hFile*HISTORY_HEADER.size, HISTORY_HEADER.size);
   return(NO_ERROR);
}


/**
 * Gibt die Formatversion der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return int - Version oder NULL, falls ein Fehler auftrat
 */
int hf.Version(int hFile) {
   if (hFile <= 0)                      return(_NULL(catch("hf.Version(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_NULL(catch("hf.Version(2)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_NULL(catch("hf.Version(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_NULL(catch("hf.Version(4)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.valid = hFile;
   }
   return(hhs.Version(hf.header, hFile));
}


/**
 * Gibt das Symbol der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return string - Symbol oder Leerstring, falls ein Fehler auftrat
 */
string hf.Symbol(int hFile) {
   if (hFile <= 0)                      return(_empty(catch("hf.Symbol(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_empty(catch("hf.Symbol(2)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_empty(catch("hf.Symbol(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_empty(catch("hf.Symbol(4)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.valid = hFile;
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
   if (hFile <= 0)                      return(_empty(catch("hf.Description(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_empty(catch("hf.Description(2)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_empty(catch("hf.Description(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_empty(catch("hf.Description(4)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.valid = hFile;
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
   if (hFile <= 0)                      return(_NULL(catch("hf.Period(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_NULL(catch("hf.Period(2)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_NULL(catch("hf.Period(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_NULL(catch("hf.Period(4)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.valid = hFile;
   }
   return(hf.period[hFile]);
}


/**
 * Gibt die Anzahl der Digits der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return int - Digits oder -1, falls ein Fehler auftrat
 */
int hf.Digits(int hFile) {
   if (hFile <= 0)                      return(_int(-1, catch("hf.Digits(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_int(-1, catch("hf.Digits(2)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_int(-1, catch("hf.Digits(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_int(-1, catch("hf.Digits(4)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.valid = hFile;
   }
   return(hf.digits[hFile]);
}


/**
 * Gibt die DB-Version der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return datetime - Versions-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
int hf.DbVersion(int hFile) {
   if (hFile <= 0)                      return(_int(-1, catch("hf.DbVersion(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_int(-1, catch("hf.DbVersion(2)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_int(-1, catch("hf.DbVersion(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_int(-1, catch("hf.DbVersion(4)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.valid = hFile;
   }
   return(hhs.DbVersion(hf.header, hFile));
}


/**
 * Gibt die vorherige DB-Version der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return datetime - Versions-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
int hf.PrevDbVersion(int hFile) {
   // 2 oder mehr Tests
   if (hFile <= 0)                      return(_int(-1, catch("hf.PrevDbVersion(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_int(-1, catch("hf.PrevDbVersion(2)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <= 0) {
         if (hf.hFile[hFile] == 0)      return(_int(-1, catch("hf.PrevDbVersion(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                        return(_int(-1, catch("hf.PrevDbVersion(4)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hf.hFile.valid = hFile;
   }
   return(hhs.PrevDbVersion(hf.header, hFile));
}


/**
 * Schließt alle noch offenen Dateien.
 *
 * @param  bool warn - ob für noch offene Dateien eine Warnung ausgegeben werden soll (default: nein)
 *
 * @return bool - Erfolgsstatus
 */
bool History.CloseFiles(bool warn=false) {
   int error, size=ArraySize(hf.hFile);

   for (int i=0; i < size; i++) {
      if (hf.hFile[i] > 0) {
         if (warn) warn(StringConcatenate("History.CloseFiles()   open file handle "+ hf.hFile[i] +" found: \"", hf.name[i], "\""));

         if (!HistoryFile.Close(hf.hFile[i]))
            error = last_error;
      }
   }
   return(!error);
}


/**
 * Setzt die globalen Arrays zurück. Wird nur im Tester und in library::init() aufgerufen.
 */
void Tester.ResetGlobalArrays() {
   if (IsTesting()) {
      ArrayResize(stack.orderSelections      , 0);

      // Daten einzelner HistoryFiles
      ArrayResize(hf.hFile                   , 0);
      ArrayResize(hf.name                    , 0);
      ArrayResize(hf.read                    , 0);
      ArrayResize(hf.write                   , 0);
      ArrayResize(hf.size                    , 0);

      ArrayResize(hf.header                  , 0);
      ArrayResize(hf.symbol                  , 0);
      ArrayResize(hf.period                  , 0);
      ArrayResize(hf.periodSecs              , 0);
      ArrayResize(hf.digits                  , 0);

      ArrayResize(hf.bars                    , 0);
      ArrayResize(hf.from                    , 0);
      ArrayResize(hf.to                      , 0);

      // Cache der aktuellen Bar
      ArrayResize(hf.currentBar.offset       , 0);
      ArrayResize(hf.currentBar.openTime     , 0);
      ArrayResize(hf.currentBar.closeTime    , 0);
      ArrayResize(hf.currentBar.nextCloseTime, 0);
      ArrayResize(hf.currentBar.data         , 0);

      // Ticks einer ungespeicherten Bar
      ArrayResize(hf.tickBar.offset          , 0);
      ArrayResize(hf.tickBar.openTime        , 0);
      ArrayResize(hf.tickBar.closeTime       , 0);
      ArrayResize(hf.tickBar.nextCloseTime   , 0);
      ArrayResize(hf.tickBar.data            , 0);

      // Daten einzelner History-Sets
      ArrayResize(h.hHst                     , 0);
      ArrayResize(h.symbol                   , 0);
      ArrayResize(h.description              , 0);
      ArrayResize(h.digits                   , 0);
      ArrayResize(h.hFile                    , 0);
    //ArrayResize(h.periods...                           // hat Initializer und wird nicht modifiziert
   }
}
