/**
 * Funktionen zum Verwalten und Bearbeiten von Historydateien (Kursreihen im "history"-Verzeichnis).
 *
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
 * @param  int    _iCustom           - Speicheradresse der ICUSTOM-Struktur, falls das laufende Programm ein per iCustom() ausgeführter Indikator ist
 * @param  int    initFlags          - durchzuführende Initialisierungstasks (default: keine)
 * @param  int    uninitializeReason - der letzte UninitializeReason() des aufrufenden Programms
 *
 * @return int - Fehlerstatus
 */
int hstlib_init(int type, string name, int whereami, bool isChart, bool isOfflineChart, int _iCustom, int initFlags, int uninitializeReason) {
   prev_error = last_error;
   last_error = NO_ERROR;

   __TYPE__      |= type;
   __NAME__       = StringConcatenate(name, "::", WindowExpertName());
   __WHEREAMI__   = whereami;
   __InitFlags    = SumInts(__INIT_FLAGS__) | initFlags;
   __LOG_CUSTOM   = __InitFlags & INIT_CUSTOMLOG;                       // (bool) int
   __iCustom__    = _iCustom;                                           // (int) lpICUSTOM
      if (IsTesting())
   __LOG          = Tester.IsLogging();                                 // TODO: !!! bei iCustom(indicator) Status aus aufrufendem Modul übernehmen
   IsChart        = isChart;
   IsOfflineChart = isOfflineChart;


   // globale Variablen re-initialisieren
   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = Round(MathPow(10, Digits<<31>>31));                   PipPoint          = PipPoints;
   Pip            = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   return(catch("hstlib_init()"));
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
int hstlib_deinit(int deinitFlags, int uninitializeReason) {
   __WHEREAMI__  = FUNC_DEINIT;
   __DeinitFlags = SumInts(__DEINIT_FLAGS__) | deinitFlags;
   return(NO_ERROR);
}


/**
 * Gibt den letzten in der Library aufgetretenen Fehler zurück. Der Aufruf dieser Funktion setzt den Fehlercode *nicht* zurück.
 *
 * @return int - Fehlerstatus
 */
int hstlib_GetLastError() {
   return(last_error);
}


// Daten einzelner HistoryFiles
int      hf.hFile [];                           // Dateihandle = Arrayindex, wenn Datei offen; kleiner/gleich 0, wenn geschlossen/ungültig
int      hf.hFile.valid = -1;                   // zuletzt validiertes Dateihandle (um nicht bei jedem Funktionsaufruf das übergebene Handle auf Gültigkeit prüfen zu müssen)
string   hf.name  [];                           // Dateiname
bool     hf.read  [];                           // ob das Handle Lese-Zugriff erlaubt
bool     hf.write [];                           // ob das Handle Schreib-Zugriff erlaubt
int      hf.size  [];                           // aktuelle Größe der Datei (inkl. noch ungeschriebener Daten im Schreibpuffer)
int      hf.header[][HISTORY_HEADER.intSize];   // History-Header der Datei
int      hf.bars  [];                           // Anzahl der Bars der Datei
datetime hf.from  [];                           // OpenTime der ersten Bar der Datei
datetime hf.to    [];                           // OpenTime der letzten Bar der Datei

// Cache der zuletzt gelesenen/geschriebenen Bar eines Dateihandles
int      hf.bar    [];                          // Offset der zuletzt gelesenen/geschriebenen Bar
datetime hf.barTime[];                          // OpenTime der zuletzt gelesenen/geschriebenen Bar (Time)
double   hf.barData[][5];                       // RateInfos der zuletzt gelesenen/geschriebenen Bar (OHLCV)


/**
 * Fügt der angegebenen Historydatei einen Tick hinzu. Der Tick wird als letzter Tick (Close) der entsprechenden Bar gespeichert.
 *
 * @param  int      hFile - Dateihandle der Historydatei (muß Schreibzugriff erlauben)
 * @param  datetime time  - Zeitpunkt des Ticks
 * @param  double   value - Datenwert
 * @param  int      flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                          HST_FILL_GAPS: entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
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

   // (1) OpenTime der entsprechenden Bar berechnen
   time -= time%(hhs.Period(hf.header, hFile)*MINUTES);

   // (2) Offset der Bar ermitteln
   int  offset;
   bool barExists[] = {true};

   if (hf.barTime[hFile] == time) {
      offset = hf.bar[hFile];                                        // möglichst den Cache verwenden
   }
   else {
      offset = HistoryFile.FindBar(hFile, time, barExists);
      if (offset < 0)
         return(false);
   }

   // (3) existierende Bar aktualisieren...
   if (barExists[0])
      return(HistoryFile.UpdateBar(hFile, offset, value));

   // (4) ...oder nicht existierende Bar einfügen
   double data[5];
   data[BAR_O] = value;
   data[BAR_H] = value;
   data[BAR_L] = value;
   data[BAR_C] = value;
   data[BAR_V] = 1;

   return(HistoryFile.InsertBar(hFile, offset, time, data, flags));
}


/**
 * Findet den Offset der Bar innerhalb der angegebenen Historydatei, die den angegebenen Zeitpunkt abdeckt, und signalisiert, ob an diesem
 * Offset bereits eine Bar existiert. Eine Bar existiert z.B. dann nicht, wenn die Zeitreihe am angegebenen Zeitpunkt eine Lücke enthält oder
 * wenn der Zeitpunkt außerhalb des von der Historydatei abgedeckten Datenbereichs liegt.
 *
 * @param  int      hFile          - Dateihandle der Historydatei
 * @param  datetime time           - Zeitpunkt
 * @param  bool     lpBarExists[1] - Zeiger auf Variable, die nach Rückkehr anzeigt, ob die Bar am zurückgegebenen Offset bereits existiert.
 *                                   Die Variable ist als Array implementiert, um die Zeigerübergabe an eine Library zu ermöglichen.
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
 * @param  int      offset  - Offset der zu lesenden Bar innerhalb der Zeitreihe
 * @param  datetime time[1] - Array zur Aufnahme von BAR.Time
 * @param  double   data[5] - Array zur Aufnahme der Bardaten
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
   if (ArraySize(data) < 5) ArrayResize(data, 5);

   // Bar lesen                                                      // struct RateInfo {
   int position = HISTORY_HEADER.size + offset*BAR.size;             //    int    time;      //  4
   if (!FileSeek(hFile, position, SEEK_SET))                         //    double open;      //  8
      return(_false(catch("HistoryFile.ReadBar(6)")));               //    double low;       //  8
                                                                     //    double high;      //  8
   time[0] = FileReadInteger(hFile);                                 //    double close;     //  8
             FileReadArray  (hFile, data, 0, 5);                     //    double volume;    //  8
                                                                     // };                   // 44 byte
   hf.bar    [hFile]        = offset;
   hf.barTime[hFile]        = time[0];                               // Cache aktualisieren
   hf.barData[hFile][BAR_O] = data[BAR_O];
   hf.barData[hFile][BAR_H] = data[BAR_H];
   hf.barData[hFile][BAR_L] = data[BAR_L];
   hf.barData[hFile][BAR_C] = data[BAR_C];
   hf.barData[hFile][BAR_V] = data[BAR_V];

   //int digits = hf.Digits(hFile);
   //debug("HistoryFile.ReadBar()   offset="+ offset +"  time="+ TimeToStr(time[0], TIME_FULL) +"   O="+ DoubleToStr(data[BAR_O], digits) +"  H="+ DoubleToStr(data[BAR_H], digits) +"  L="+ DoubleToStr(data[BAR_L], digits) +"  C="+ DoubleToStr(data[BAR_C], digits) +"  V="+ Round(data[BAR_V]));

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
   if (hf.bar[hFile] != offset) {
      int    iNull[1];
      double dNull[5];
      if (!HistoryFile.ReadBar(hFile, offset, iNull, dNull))
         return(false);
   }

   // (2) ...und zur Performancesteigerung direkt im Cache modifizieren
 //hf.barData[hFile][BAR_O] = ...                                    // unverändert
   hf.barData[hFile][BAR_H] = MathMax(hf.barData[hFile][BAR_H], value);
   hf.barData[hFile][BAR_L] = MathMin(hf.barData[hFile][BAR_L], value);
   hf.barData[hFile][BAR_C] = value;
   hf.barData[hFile][BAR_V]++;

   // (3) Bar schreiben
   return(HistoryFile.WriteCachedBar(hFile));
}


/**
 * Fügt eine neue Bar am angegebenen Offset der angegebenen Historydatei ein. Die Funktion überprüft *nicht* die Plausibilität der einzufügenden Daten.
 *
 * @param  int      hFile   - Dateihandle der Historydatei (muß Schreibzugriff erlauben)
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

   //int digits = hf.Digits(hFile);
   //debug("HistoryFile.InsertBar() offset="+ offset +"  time="+ TimeToStr(time, TIME_FULL) +"   O="+ DoubleToStr(data[BAR_O], digits) +"  H="+ DoubleToStr(data[BAR_H], digits) +"  L="+ DoubleToStr(data[BAR_L], digits) +"  C="+ DoubleToStr(data[BAR_C], digits) +"  V="+ Round(data[BAR_V]));

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
 * @param  int      hFile   - Dateihandle der Historydatei (muß Schreibzugriff erlauben)
 * @param  int      offset  - Offset der zu schreibenden Bar innerhalb der Zeitreihe (die erste Bar hat den Offset 0)
 * @param  datetime time    - BAR.Time
 * @param  double   data[5] - Bardaten
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

   //int digits = hf.Digits(hFile);
   //debug("HistoryFile.WriteBar()  offset="+ offset +"  time="+ TimeToStr(time, TIME_FULL) +"   O="+ DoubleToStr(data[BAR_O], digits) +"  H="+ DoubleToStr(data[BAR_H], digits) +"  L="+ DoubleToStr(data[BAR_L], digits) +"  C="+ DoubleToStr(data[BAR_C], digits) +"  V="+ Round(data[BAR_V]));


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
   if (offset >= hf.bars[hFile]) { hf.size   [hFile]        = position + BAR.size;
                                   hf.bars   [hFile]        = offset + 1; }
   if (offset == 0)                hf.from   [hFile]        = time;
   if (offset == hf.bars[hFile]-1) hf.to     [hFile]        = time;

                                   hf.bar    [hFile]        = offset;
                                   hf.barTime[hFile]        = time;
                                   hf.barData[hFile][BAR_O] = data[BAR_O];
                                   hf.barData[hFile][BAR_H] = data[BAR_H];
                                   hf.barData[hFile][BAR_L] = data[BAR_L];
                                   hf.barData[hFile][BAR_C] = data[BAR_C];
                                   hf.barData[hFile][BAR_V] = data[BAR_V];

   return(!last_error|catch("HistoryFile.WriteBar(9)"));
}


/**
 * Schreibt die gecachten Bardaten in die angegebene Historydatei.
 *
 * @param  int hFile - Dateihandle der Historydatei (muß Schreibzugriff erlauben)
 *
 * @return bool - Erfolgsstatus
 */
bool HistoryFile.WriteCachedBar(int hFile) {
   if (hFile <= 0)                      return(_false(catch("HistoryFile.WriteCachedBar(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile != hf.hFile.valid) {
      if (hFile >= ArraySize(hf.hFile)) return(_false(catch("HistoryFile.WriteCachedBar(2)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] == 0)         return(_false(catch("HistoryFile.WriteCachedBar(3)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hf.hFile[hFile] <  0)         return(_false(catch("HistoryFile.WriteCachedBar(4)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hf.hFile.valid = hFile;
   }
   int bar = hf.bar[hFile];
   if (bar < 0)                         return(_false(catch("HistoryFile.WriteCachedBar(5)   invalid cached bar value = "+ bar, ERR_RUNTIME_ERROR)));

   //int digits = hf.Digits(hFile);
   //debug("HistoryFile.WriteCachedBar()  bar="+ bar +"  time="+ TimeToStr(hf.barTime[hFile], TIME_FULL) +"   O="+ DoubleToStr(hf.barO[hFile], digits) +"  H="+ DoubleToStr(hf.barH[hFile], digits) +"  L="+ DoubleToStr(hf.barL[hFile], digits) +"  C="+ DoubleToStr(hf.barC[hFile], digits) +"  V="+ Round(hf.barV[hFile]));

   // Bar schreiben                                                  // struct RateInfo {
   int position = HISTORY_HEADER.size + bar*BAR.size;                //    int    time;      //  4
   if (!FileSeek(hFile, position, SEEK_SET))                         //    double open;      //  8
      return(_false(catch("HistoryFile.WriteCachedBar(6)")));        //    double low;       //  8
                                                                     //    double high;      //  8
   FileWriteInteger(hFile, hf.barTime[hFile]       );                //    double close;     //  8
   FileWriteDouble (hFile, hf.barData[hFile][BAR_O]);                //    double volume;    //  8
   FileWriteDouble (hFile, hf.barData[hFile][BAR_L]);                // };                   // 44 byte
   FileWriteDouble (hFile, hf.barData[hFile][BAR_H]);
   FileWriteDouble (hFile, hf.barData[hFile][BAR_C]);
   FileWriteDouble (hFile, hf.barData[hFile][BAR_V]);

   return(!last_error|catch("HistoryFile.WriteCachedBar(7)"));
}


/**
 *
 * @param  int hFile - Dateihandle der Historydatei (muß Schreibzugriff erlauben)
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
   if (hFile >= ArraySize(hf.hFile))
      hst.ResizeArrays(hFile+1);

                    hf.hFile  [hFile] = hFile;
                    hf.name   [hFile] = fileName;
                    hf.read   [hFile] = mode & FILE_READ;
                    hf.write  [hFile] = mode & FILE_WRITE;
                    hf.size   [hFile] = fileSize;
   ArraySetIntArray(hf.header, hFile, hh);                           // entspricht: hf.header[hFile] = hh;
                    hf.bars   [hFile] = bars;
                    hf.from   [hFile] = from;
                    hf.to     [hFile] = to;
                    hf.bar    [hFile] = -1;
                    hf.barTime[hFile] = -1;

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
 * Setzt die Größe der internen Daten-Arrays auf den angegebenen Wert.
 *
 * @param  int size - neue Größe
 *
 * @return int - neue Größe der Arrays
 */
/*private*/ int hst.ResizeArrays(int size) {
   if (size != ArraySize(hf.hFile)) {
      ArrayResize(hf.hFile,   size);
      ArrayResize(hf.name,    size);
      ArrayResize(hf.read,    size);
      ArrayResize(hf.write,   size);
      ArrayResize(hf.size,    size);
      ArrayResize(hf.header,  size);
      ArrayResize(hf.bars,    size);
      ArrayResize(hf.from,    size);
      ArrayResize(hf.to,      size);
      ArrayResize(hf.bar,     size);
      ArrayResize(hf.barTime, size);
      ArrayResize(hf.barData, size);
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
   return(hhs.Symbol(hf.header, hFile));
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
   return(hhs.Period(hf.header, hFile));
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
   return(hhs.Digits(hf.header, hFile));
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
