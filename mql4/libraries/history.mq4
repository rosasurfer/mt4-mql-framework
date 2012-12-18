/**
 * NOTE: Libraries use predefined variables of the module that called the library.
 */
#property library
#property stacksize 32768

#include <core/define.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stddefine.mqh>
#include <stdlib.mqh>

#include <core/library.mqh>


int      hst.hFile      [16];
string   hst.fileName   [16];
bool     hst.fileRead   [16];
bool     hst.fileWrite  [16];
int      hst.fileSize   [16];
int      hst.fileHeader [16][HISTORY_HEADER.intSize];
int      hst.fileBars   [16];
datetime hst.fileFrom   [16];
datetime hst.fileTo     [16];
int      hst.fileBar    [16];                         // Cache der zuletzt gelesenen/geschriebenen Bardaten
datetime hst.fileBarTime[16];
double   hst.fileBarData[16][5];
int      hst.hFile.valid = -1;                        // Cache des zuletzt validierten Dateihandles


/**
 * Fügt der angegebenen Historydatei einen Tick hinzu. Der Tick wird als letzter Tick (Close) der entsprechenden Bar gespeichert.
 *
 * @param  int      hFile - Dateihandle der Historydatei (muß Schreibzugriff erlauben)
 * @param  datetime time  - Zeitpunkt des Ticks
 * @param  double   value - Wert des Ticks
 * @param  int      flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                          HST_FILL_GAPS: entstehende Gaps werden mit dem Schlußkurs der letzten Bar vor dem Gap gefüllt
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Zur Performancesteigerung werden die Tickdaten nicht zusätzlich validiert.
 */
bool History.AddTick(int hFile, datetime time, double value, int flags=NULL) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_false(catch("History.AddTick(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] == 0)                       return(_false(catch("History.AddTick(2)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <  0)                       return(_false(catch("History.AddTick(3)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hst.hFile.valid = hFile;
   }
   if (time <= 0)                                      return(_false(catch("History.AddTick(4)   invalid parameter time = "+ time, ERR_INVALID_FUNCTION_PARAMVALUE)));

   // (1) OpenTime der entsprechenden Bar berechnen
   time -= time%(hhs.Period(hst.fileHeader, hFile)*MINUTES);

   // (2) Offset der Bar ermitteln
   int  bar;
   bool barExists[] = {true};

   if (hst.fileBarTime[hFile] == time) {
      bar = hst.fileBar[hFile];                                      // möglichst den Cache verwenden
   }
   else {
      bar = History.FindBar(hFile, time, barExists);
      if (bar < 0)
         return(false);
   }

   // (3) existierende Bar aktualisieren...
   if (barExists[0])
      return(History.UpdateBar(hFile, bar, value));

   // (4) ...oder nicht existierende Bar einfügen
   double data[5];
   data[BAR_O] = value;
   data[BAR_H] = value;
   data[BAR_L] = value;
   data[BAR_C] = value;
   data[BAR_V] = 1;

   return(History.InsertBar(hFile, bar, time, data, flags));
}


/**
 * Findet den Offset der Bar innerhalb der angegebenen Historydatei, die den angegebenen Zeitpunkt abdeckt und signalisiert, ob an diesem
 * Offset bereits eine Bar in der Zeitreihe existiert. Eine Bar existiert z.B. dann nicht, wenn die Zeitreihe am angegebenen Zeitpunkt eine
 * Kurslücke enthält oder wenn der Zeitpunkt außerhalb des von der Zeitreihe abgedeckten Datenbereichs liegt.
 *
 * @param  int      hFile          - Dateihandle der Historydatei
 * @param  datetime time           - Zeitpunkt
 * @param  bool    &lpBarExists[1] - Variable, die anzeigt, ob die Bar am zurückgegebenen Offset existiert oder nicht
 *                                   lpBarExists[0]=TRUE:  zum Aktualisieren der Zeitreihe ist History.UpdateBar() zu verwenden
 *                                   lpBarExists[0]=FALSE: zum Aktualisieren der Zeitreihe ist History.InsertBar() zu verwenden
 *
 * @return int - Bar-Offset oder -1, falls ein Fehler auftrat
 */
int History.FindBar(int hFile, datetime time, bool &lpBarExists[]) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_int(-1, catch("History.FindBar(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] == 0)                       return(_int(-1, catch("History.FindBar(2)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <  0)                       return(_int(-1, catch("History.FindBar(3)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hst.hFile.valid = hFile;
   }
   if (time <= 0)                                      return(_int(-1, catch("History.FindBar(4)   invalid parameter time = "+ time, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (ArraySize(lpBarExists) == 0)
      ArrayResize(lpBarExists, 1);

   // OpenTime der entsprechenden Bar berechnen
   time -= time%(hhs.Period(hst.fileHeader, hFile)*MINUTES);

   // (1) Zeitpunkt ist der Zeitpunkt der letzten Bar          // die beiden am häufigsten auftretenden Fälle zu Beginn prüfen
   if (time == hst.fileTo[hFile]) {
      lpBarExists[0] = true;
      return(hst.fileBars[hFile] - 1);
   }

   // (2) Zeitpunkt liegt zeitlich nach der letzten Bar        // die beiden am häufigsten auftretenden Fälle zu Beginn prüfen
   if (time > hst.fileTo[hFile]) {
      lpBarExists[0] = false;
      return(hst.fileBars[hFile]);
   }

   // (3) History leer
   if (hst.fileBars[hFile] == 0) {
      lpBarExists[0] = false;
      return(0);
   }

   // (4) Zeitpunkt ist der Zeitpunkt der ersten Bar
   if (time == hst.fileFrom[hFile]) {
      lpBarExists[0] = true;
      return(0);
   }

   // (5) Zeitpunkt liegt zeitlich vor der ersten Bar
   if (time < hst.fileFrom[hFile]) {
      lpBarExists[0] = false;
      return(0);
   }

   // (6) Zeitpunkt liegt irgendwo innerhalb der Zeitreihe
   int offset;
   return(_int(-1, catch("History.FindBar(5)   Suche nach Zeitpunkt innerhalb der Zeitreihe noch nicht implementiert", ERR_FUNCTION_NOT_IMPLEMENTED)));

   if (IsError(last_error|catch("History.FindBar(6)", ERR_FUNCTION_NOT_IMPLEMENTED)))
      return(-1);
   return(offset);
}


/**
 * Liest die Bar am angegebenen Offset einer Historydatei.
 *
 * @param  int       hFile   - Dateihandle der Historydatei
 * @param  int       bar     - Offset der zu lesenden Bar innerhalb der Zeitreihe
 * @param  datetime &time[1] - Array zur Aufnahme von BAR.Time
 * @param  double   &data[5] - Array zur Aufnahme der Bardaten
 *
 * @return bool - Erfolgsstatus
 */
bool History.ReadBar(int hFile, int bar, datetime &time[], double &data[]) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_false(catch("History.ReadBar(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] == 0)                       return(_false(catch("History.ReadBar(2)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <  0)                       return(_false(catch("History.ReadBar(3)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hst.hFile.valid = hFile;
   }
   if (bar < 0 || bar >= hst.fileBars[hFile])          return(_false(catch("History.ReadBar(4)   invalid parameter bar = "+ bar, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (ArraySize(time) < 1) ArrayResize(time, 1);
   if (ArraySize(data) < 5) ArrayResize(data, 5);

   // Bar lesen                                                      // struct RateInfo {
   int position = HISTORY_HEADER.size + bar*BAR.size;                //    int    time;      //  4
   if (!FileSeek(hFile, position, SEEK_SET))                         //    double open;      //  8
      return(_false(catch("History.ReadBar(5)")));                   //    double low;       //  8
                                                                     //    double high;      //  8
   time[0] = FileReadInteger(hFile);                                 //    double close;     //  8
             FileReadArray  (hFile, data, 0, 5);                     //    double volume;    //  8
                                                                     // };                   // 44 byte
   hst.fileBar    [hFile]        = bar;
   hst.fileBarTime[hFile]        = time[0];                          // Cache aktualisieren
   hst.fileBarData[hFile][BAR_O] = data[BAR_O];
   hst.fileBarData[hFile][BAR_H] = data[BAR_H];
   hst.fileBarData[hFile][BAR_L] = data[BAR_L];
   hst.fileBarData[hFile][BAR_C] = data[BAR_C];
   hst.fileBarData[hFile][BAR_V] = data[BAR_V];

   //int digits = History.FileDigits(hFile);
   //debug("History.ReadBar()   bar="+ bar +"  time="+ TimeToStr(time[0], TIME_FULL) +"   O="+ DoubleToStr(data[BAR_O], digits) +"  H="+ DoubleToStr(data[BAR_H], digits) +"  L="+ DoubleToStr(data[BAR_L], digits) +"  C="+ DoubleToStr(data[BAR_C], digits) +"  V="+ Round(data[BAR_V]));

   return(!last_error|catch("History.ReadBar(6)"));
}


/**
 * Aktualisiert die Bar am angegebenen Offset einer Historydatei.
 *
 * @param  int    hFile - Dateihandle der Historydatei
 * @param  int    bar   - Offset der zu aktualisierenden Bar innerhalb der Zeitreihe
 * @param  double value - hinzuzufügender Wert
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Zur Performancesteigerung werden die Tickdaten nicht zusätzlich validiert.
 */
bool History.UpdateBar(int hFile, int bar, double value) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_false(catch("History.UpdateBar(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] == 0)                       return(_false(catch("History.UpdateBar(2)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <  0)                       return(_false(catch("History.UpdateBar(3)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hst.hFile.valid = hFile;
   }
   if (bar < 0 || bar >= hst.fileBars[hFile])          return(_false(catch("History.UpdateBar(4)   invalid parameter bar = "+ bar, ERR_INVALID_FUNCTION_PARAMVALUE)));

   // (1) Bar lesen
   if (hst.fileBar[hFile] != bar) {                // möglichst den Cache verwenden
      int    iNull[1];
      double dNull[5];
      if (!History.ReadBar(hFile, bar, iNull, dNull))
         return(false);
   }

   // (2) Daten zur Performancesteigerung direkt im Cache modifizieren
   hst.fileBarData[hFile][BAR_H] = MathMax(hst.fileBarData[hFile][BAR_H], value);
   hst.fileBarData[hFile][BAR_L] = MathMin(hst.fileBarData[hFile][BAR_L], value);
   hst.fileBarData[hFile][BAR_C] = value;
   hst.fileBarData[hFile][BAR_V]++;

   // (3) Bar schreiben
   return(History.WriteCachedBar(hFile));
}


/**
 * Fügt eine neue Bar am angegebenen Offset der angegebenen Historydatei ein. Die Funktion überprüft *nicht* die Plausibilität der einzufügenden Daten.
 *
 * @param  int      hFile   - Dateihandle der Historydatei (muß Schreibzugriff erlauben)
 * @param  int      bar     - Offset der einzufügenden Bar innerhalb der Zeitreihe (die erste Bar hat den Offset 0)
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
bool History.InsertBar(int hFile, int bar, datetime time, double data[], int flags=NULL) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_false(catch("History.InsertBar(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] == 0)                       return(_false(catch("History.InsertBar(2)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <  0)                       return(_false(catch("History.InsertBar(3)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hst.hFile.valid = hFile;
   }
   if (bar  <  0)                                      return(_false(catch("History.InsertBar(4)   invalid parameter bar = "+ bar, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (time <= 0)                                      return(_false(catch("History.InsertBar(5)   invalid parameter time = "+ time, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (ArraySize(data) != 5)                           return(_false(catch("History.InsertBar(6)   invalid size of parameter data[] = "+ ArraySize(data), ERR_INCOMPATIBLE_ARRAYS)));

   //int digits = History.FileDigits(hFile);
   //debug("History.InsertBar() bar="+ bar +"  time="+ TimeToStr(time, TIME_FULL) +"   O="+ DoubleToStr(data[BAR_O], digits) +"  H="+ DoubleToStr(data[BAR_H], digits) +"  L="+ DoubleToStr(data[BAR_L], digits) +"  C="+ DoubleToStr(data[BAR_C], digits) +"  V="+ Round(data[BAR_V]));

   // (1) ggf. Lücke für neue Bar schaffen
   if (bar < hst.fileBars[hFile]) {
      if (!History.MoveBars(hFile, bar, bar+1))
         return(false);
   }

   // (2) Bar schreiben
   return(History.WriteBar(hFile, bar, time, data, flags));
}


/**
 * Schreibt eine Bar in die angegebene Historydatei. Eine ggf. vorhandene Bar mit dem selben Open-Zeitpunkt wird überschrieben.
 *
 * @param  int      hFile   - Dateihandle der Historydatei (muß Schreibzugriff erlauben)
 * @param  int      bar     - Offset der zu schreibenden Bar innerhalb der Zeitreihe (die erste Bar hat den Offset 0)
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
bool History.WriteBar(int hFile, int bar, datetime time, double data[], int flags=NULL) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_false(catch("History.WriteBar(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] == 0)                       return(_false(catch("History.WriteBar(2)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <  0)                       return(_false(catch("History.WriteBar(3)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hst.hFile.valid = hFile;
   }
   if (bar  <  0)                                      return(_false(catch("History.WriteBar(4)   invalid parameter bar = "+ bar, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (time <= 0)                                      return(_false(catch("History.WriteBar(5)   invalid parameter time = "+ time, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (ArraySize(data) != 5)                           return(_false(catch("History.WriteBar(6)   invalid size of parameter data[] = "+ ArraySize(data), ERR_INCOMPATIBLE_ARRAYS)));

   //int digits = History.FileDigits(hFile);
   //debug("History.WriteBar()  bar="+ bar +"  time="+ TimeToStr(time, TIME_FULL) +"   O="+ DoubleToStr(data[BAR_O], digits) +"  H="+ DoubleToStr(data[BAR_H], digits) +"  L="+ DoubleToStr(data[BAR_L], digits) +"  C="+ DoubleToStr(data[BAR_C], digits) +"  V="+ Round(data[BAR_V]));


   // (1) Bar schreiben
   int position = HISTORY_HEADER.size + bar*BAR.size;                // struct RateInfo {
   if (!FileSeek(hFile, position, SEEK_SET))                         //    int    time;      //  4
      return(_false(catch("History.WriteBar(7)")));                  //    double open;      //  8
                                                                     //    double low;       //  8
   FileWriteInteger(hFile, time);                                    //    double high;      //  8
   FileWriteArray  (hFile, data, 0, 5);                              //    double close;     //  8
                                                                     //    double volume;    //  8
                                                                     // };                   // 44 byte
   // (2) interne Daten aktualisieren
   if (bar >= hst.fileBars[hFile]) { hst.fileSize   [hFile]        = position + BAR.size;
                                     hst.fileBars   [hFile]        = bar + 1; }
   if (bar == 0)                     hst.fileFrom   [hFile]        = time;
   if (bar == hst.fileBars[hFile]-1) hst.fileTo     [hFile]        = time;
                                     hst.fileBar    [hFile]        = bar;
                                     hst.fileBarTime[hFile]        = time;
                                     hst.fileBarData[hFile][BAR_O] = data[BAR_O];
                                     hst.fileBarData[hFile][BAR_H] = data[BAR_H];
                                     hst.fileBarData[hFile][BAR_L] = data[BAR_L];
                                     hst.fileBarData[hFile][BAR_C] = data[BAR_C];
                                     hst.fileBarData[hFile][BAR_V] = data[BAR_V];

   return(!last_error|catch("History.WriteBar(8)"));
}


/**
 * Schreibt die gecachten Bardaten in die angegebene Historydatei.
 *
 * @param  int hFile - Dateihandle der Historydatei (muß Schreibzugriff erlauben)
 *
 * @return bool - Erfolgsstatus
 */
bool History.WriteCachedBar(int hFile) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_false(catch("History.WriteCachedBar(1)   invalid parameter hFile = "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] == 0)                       return(_false(catch("History.WriteCachedBar(2)   invalid parameter hFile = "+ hFile +" (unknown handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <  0)                       return(_false(catch("History.WriteCachedBar(3)   invalid parameter hFile = "+ hFile +" (closed handle)", ERR_INVALID_FUNCTION_PARAMVALUE)));
      hst.hFile.valid = hFile;
   }
   int bar = hst.fileBar[hFile];
   if (bar < 0)                                        return(_false(catch("History.WriteCachedBar(4)   invalid cached bar value = "+ bar, ERR_RUNTIME_ERROR)));

   //int digits = History.FileDigits(hFile);
   //debug("History.WriteCachedBar()  bar="+ bar +"  time="+ TimeToStr(hst.fileBarTime[hFile], TIME_FULL) +"   O="+ DoubleToStr(hst.fileBarO[hFile], digits) +"  H="+ DoubleToStr(hst.fileBarH[hFile], digits) +"  L="+ DoubleToStr(hst.fileBarL[hFile], digits) +"  C="+ DoubleToStr(hst.fileBarC[hFile], digits) +"  V="+ Round(hst.fileBarV[hFile]));

   // Bar schreiben                                                  // struct RateInfo {
   int position = HISTORY_HEADER.size + bar*BAR.size;                //    int    time;      //  4
   if (!FileSeek(hFile, position, SEEK_SET))                         //    double open;      //  8
      return(_false(catch("History.WriteCachedBar(5)")));            //    double low;       //  8
                                                                     //    double high;      //  8
   FileWriteInteger(hFile, hst.fileBarTime[hFile]       );           //    double close;     //  8
   FileWriteDouble (hFile, hst.fileBarData[hFile][BAR_O]);           //    double volume;    //  8
   FileWriteDouble (hFile, hst.fileBarData[hFile][BAR_L]);           // };                   // 44 byte
   FileWriteDouble (hFile, hst.fileBarData[hFile][BAR_H]);
   FileWriteDouble (hFile, hst.fileBarData[hFile][BAR_C]);
   FileWriteDouble (hFile, hst.fileBarData[hFile][BAR_V]);

   return(!last_error|catch("History.WriteCachedBar(6)"));
}


/**
 *
 * @param  int hFile - Dateihandle der Historydatei (muß Schreibzugriff erlauben)
 * @param  int startOffset
 * @param  int destOffset
 *
 * @return bool - Erfolgsstatus
 */
bool History.MoveBars(int hFile, int startOffset, int destOffset) {
   return(!last_error|catch("History.MoveBars()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Öffnet eine Historydatei und gibt das resultierende Dateihandle zurück. Ist der Access-Mode FILE_WRITE angegeben und die Datei existiert nicht,
 * wird sie erstellt und ein HISTORY_HEADER geschrieben.  Wurde die Datei nicht vorher geschlossen, wird sie bei Programmende automatisch geschlossen.
 *
 * @param  string symbol      - Symbol des Instruments
 * @param  string description - Beschreibung des Instruments (falls die Historydatei neu erstellt wird)
 * @param  int    digits      - Digits der Werte             (falls die Historydatei neu erstellt wird)
 * @param  int    period      - Timeframe der Zeitreihe
 * @param  int    mode        - Access-Mode: FILE_READ | FILE_WRITE
 *
 * @return int - Dateihandle
 *
 *
 * NOTE: Das zurückgegebene Handle darf nicht modul-übergreifend verwendet werden. Mit den MQL-Dateifunktionen können je Modul maximal 32 Dateien
 *       gleichzeitig offen gehalten werden.
 */
int History.OpenFile(string symbol, string description, int digits, int period, int mode) {
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH)                      return(_ZERO(catch("History.OpenFile(1)   illegal parameter symbol = "+ symbol +" (length="+ StringLen(symbol) +")", ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (digits <  0)                                                return(_ZERO(catch("History.OpenFile(2)   illegal parameter digits = "+ digits, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (period <= 0)                                                return(_ZERO(catch("History.OpenFile(3)   illegal parameter period = "+ period, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (_bool(mode & FILE_CSV) || !(mode & (FILE_READ|FILE_WRITE))) return(_ZERO(catch("History.OpenFile(4)   illegal history file access mode "+ FileAccessModeToStr(mode), ERR_INVALID_FUNCTION_PARAMVALUE)));

   string fileName = StringConcatenate(symbol, period, ".hst");
   mode |= FILE_BIN;
   int hFile = FileOpenHistory(fileName, mode);
   if (hFile < 0)
      return(_ZERO(catch("History.OpenFile(5)->FileOpenHistory(\""+ fileName +"\")")));

   /*HISTORY_HEADER*/int hh[]; InitializeBuffer(hh, HISTORY_HEADER.size);

   int bars, from, to, fileSize=FileSize(hFile);

   if (fileSize < HISTORY_HEADER.size) {
      if (!(mode & FILE_WRITE)) {                                    // read-only mode
         FileClose(hFile);
         return(_ZERO(catch("History.OpenFile(6)   history file \""+ fileName +"\" corrupted (size = "+ fileSize +")", ERR_RUNTIME_ERROR)));
      }
      // neuen HISTORY_HEADER schreiben
      datetime now = TimeCurrent();                                  // TODO: ServerTime() implementieren; TimeCurrent() ist nicht die aktuelle Serverzeit
      hh.setVersion      (hh, 400        );
      hh.setDescription  (hh, description);
      hh.setSymbol       (hh, symbol     );
      hh.setPeriod       (hh, period     );
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
   if (hFile >= ArraySize(hst.hFile))
      History.ResizeArrays(hFile+1);

                    hst.hFile      [hFile] = hFile;
                    hst.fileName   [hFile] = fileName;
                    hst.fileRead   [hFile] = mode & FILE_READ;
                    hst.fileWrite  [hFile] = mode & FILE_WRITE;
                    hst.fileSize   [hFile] = fileSize;
   ArraySetIntArray(hst.fileHeader, hFile, hh);                      // entspricht: hst.fileHeader[hFile] = hh;
                    hst.fileBars   [hFile] = bars;
                    hst.fileFrom   [hFile] = from;
                    hst.fileTo     [hFile] = to;
                    hst.fileBar    [hFile] = -1;
                    hst.fileBarTime[hFile] = -1;

   ArrayResize(hh, 0);
   if (IsError(catch("History.OpenFile(7)")))
      return(0);
   return(hFile);
}


/**
 * Schließt die Historydatei mit dem angegebenen Dateihandle. Die Datei muß vorher mit History.OpenFile() geöffnet worden sein.
 *
 * @param  int hFile - Dateihandle
 *
 * @return bool - Erfolgsstatus
 */
bool History.CloseFile(int hFile) {
   if (hFile <= 0)                    return(_false(catch("History.CloseFile(1)   invalid file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (hFile >= ArraySize(hst.hFile)) return(_false(catch("History.CloseFile(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
   if (hst.hFile[hFile] == 0)         return(_false(catch("History.CloseFile(3)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));

   if (hFile == hst.hFile.valid)
      hst.hFile.valid = -1;

   if (hst.hFile[hFile] < 0)                                         // Datei ist bereits geschlossen worden
      return(true);

   int error = GetLastError();
   if (IsError(error))
      return(_false(catch("History.CloseFile(4)", error)));

   FileClose(hFile);
   hst.hFile[hFile] = -1;

   error = GetLastError();
   if (error == ERR_INVALID_FUNCTION_PARAMVALUE) {                   // Datei war bereits geschlossen: kann ignoriert werden
   }
   else if (IsError(error)) {
      return(_false(catch("History.CloseFile(5)", error)));
   }
   return(true);
}


/**
 * Setzt die Größe der History.File-Arrays auf den angegebenen Wert.
 *
 * @param  int size - neue Größe
 *
 * @return int - neue Größe der Arrays
 */
/*private*/ int History.ResizeArrays(int size) {
   if (size != ArraySize(hst.hFile)) {
      ArrayResize(hst.hFile,       size);
      ArrayResize(hst.fileName,    size);
      ArrayResize(hst.fileRead,    size);
      ArrayResize(hst.fileWrite,   size);
      ArrayResize(hst.fileSize,    size);
      ArrayResize(hst.fileHeader,  size);
      ArrayResize(hst.fileBars,    size);
      ArrayResize(hst.fileFrom,    size);
      ArrayResize(hst.fileTo,      size);
      ArrayResize(hst.fileBar,     size);
      ArrayResize(hst.fileBarTime, size);
      ArrayResize(hst.fileBarData, size);
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
string History.FileName(int hFile) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_empty(catch("History.FileName(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <= 0) {
         if (hst.hFile[hFile] == 0)                    return(_empty(catch("History.FileName(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                                       return(_empty(catch("History.FileName(3)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hst.hFile.valid = hFile;
   }
   return(hst.fileName[hFile]);
}


/**
 * Ob das Handle einer Historydatei Lesezugriff erlaubt.
 *
 * @param  int hFile - Dateihandle
 *
 * @return bool - Ergebnis oder FALSE, falls ein Fehler auftrat
 */
bool History.FileRead(int hFile) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_false(catch("History.FileRead(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <= 0) {
         if (hst.hFile[hFile] == 0)                    return(_false(catch("History.FileRead(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                                       return(_false(catch("History.FileRead(3)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hst.hFile.valid = hFile;
   }
   return(hst.fileRead[hFile]);
}


/**
 * Ob das Handle einer Historydatei Schreibzugriff erlaubt.
 *
 * @param  int hFile - Dateihandle
 *
 * @return bool - Ergebnis oder FALSE, falls ein Fehler auftrat
 */
bool History.FileWrite(int hFile) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_false(catch("History.FileWrite(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <= 0) {
         if (hst.hFile[hFile] == 0)                    return(_false(catch("History.FileWrite(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                                       return(_false(catch("History.FileWrite(3)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hst.hFile.valid = hFile;
   }
   return(hst.fileWrite[hFile]);
}


/**
 * Gibt die aktuelle Größe der zu einem Handle gehörenden Historydatei zurück (inkl. noch ungeschriebener Daten im Schreibpuffer).
 *
 * @param  int hFile - Dateihandle
 *
 * @return int - Größe oder -1, falls ein Fehler auftrat
 */
int History.FileSize(int hFile) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_int(-1, catch("History.FileSize(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <= 0) {
         if (hst.hFile[hFile] == 0)                    return(_int(-1, catch("History.FileSize(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                                       return(_int(-1, catch("History.FileSize(3)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hst.hFile.valid = hFile;
   }
   return(hst.fileSize[hFile]);
}


/**
 * Gibt die aktuelle Anzahl der Bars der zu einem Handle gehörenden Historydatei zurück (inkl. noch ungeschriebener Daten im Schreibpuffer).
 *
 * @param  int hFile - Dateihandle
 *
 * @return int - Anzahl oder -1, falls ein Fehler auftrat
 */
int History.FileBars(int hFile) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_int(-1, catch("History.FileBars(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <= 0) {
         if (hst.hFile[hFile] == 0)                    return(_int(-1, catch("History.FileBars(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                                       return(_int(-1, catch("History.FileBars(3)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hst.hFile.valid = hFile;
   }
   return(hst.fileBars[hFile]);
}


/**
 * Gibt den Zeitpunkt der ältesten Bar der zu einem Handle gehörenden Historydatei zurück (inkl. noch ungeschriebener Daten im Schreibpuffer).
 *
 * @param  int hFile - Dateihandle
 *
 * @return datetime - Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime History.FileFrom(int hFile) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_int(-1, catch("History.FileFrom(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <= 0) {
         if (hst.hFile[hFile] == 0)                    return(_int(-1, catch("History.FileFrom(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                                       return(_int(-1, catch("History.FileFrom(3)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hst.hFile.valid = hFile;
   }
   return(hst.fileFrom[hFile]);
}


/**
 * Gibt den Zeitpunkt der jüngsten Bar der zu einem Handle gehörenden Historydatei zurück (inkl. noch ungeschriebener Daten im Schreibpuffer).
 *
 * @param  int hFile - Dateihandle
 *
 * @return datetime - Zeitpunkt oder -1, falls ein Fehler auftrat
 */
datetime History.FileTo(int hFile) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_int(-1, catch("History.FileTo(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <= 0) {
         if (hst.hFile[hFile] == 0)                    return(_int(-1, catch("History.FileTo(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                                       return(_int(-1, catch("History.FileTo(3)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hst.hFile.valid = hFile;
   }
   return(hst.fileTo[hFile]);
}


/**
 * Gibt den Header der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile   - Dateihandle
 * @param  int array[] - Array zur Aufnahme der Headerdaten
 *
 * @return int - Fehlerstatus
 */
int History.FileHeader(int hFile, int array[]) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(catch("History.FileHeader(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE));
      if (hst.hFile[hFile] <= 0) {
         if (hst.hFile[hFile] == 0)                    return(catch("History.FileHeader(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR));
                                                       return(catch("History.FileHeader(3)   closed file handle "+ hFile, ERR_RUNTIME_ERROR));
      }
      hst.hFile.valid = hFile;
   }
   if (ArrayDimension(array) > 1)                      return(catch("History.FileHeader(4)   too many dimensions of parameter array = "+ ArrayDimension(array), ERR_INCOMPATIBLE_ARRAYS));

   ArrayResize(array, HISTORY_HEADER.intSize);                       // entspricht: array = hst.fileHeader[hFile];
   CopyMemory(GetBufferAddress(array), GetBufferAddress(hst.fileHeader) + hFile*HISTORY_HEADER.size, HISTORY_HEADER.size);
   return(NO_ERROR);
}


/**
 * Gibt die Formatversion der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return int - Version oder NULL, falls ein Fehler auftrat
 */
int History.FileVersion(int hFile) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_NULL(catch("History.FileVersion(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <= 0) {
         if (hst.hFile[hFile] == 0)                    return(_NULL(catch("History.FileVersion(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                                       return(_NULL(catch("History.FileVersion(3)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hst.hFile.valid = hFile;
   }
   return(hhs.Version(hst.fileHeader, hFile));
}


/**
 * Gibt das Symbol der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return string - Symbol oder Leerstring, falls ein Fehler auftrat
 */
string History.FileSymbol(int hFile) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_empty(catch("History.FileSymbol(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <= 0) {
         if (hst.hFile[hFile] == 0)                    return(_empty(catch("History.FileSymbol(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                                       return(_empty(catch("History.FileSymbol(3)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hst.hFile.valid = hFile;
   }
   return(hhs.Symbol(hst.fileHeader, hFile));
}


/**
 * Gibt die Beschreibung der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return string - Beschreibung oder Leerstring, falls ein Fehler auftrat
 */
string History.FileDescription(int hFile) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_empty(catch("History.FileDescription(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <= 0) {
         if (hst.hFile[hFile] == 0)                    return(_empty(catch("History.FileDescription(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                                       return(_empty(catch("History.FileDescription(3)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hst.hFile.valid = hFile;
   }
   return(hhs.Description(hst.fileHeader, hFile));
}


/**
 * Gibt den Timeframe der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return int - Timeframe oder NULL, falls ein Fehler auftrat
 */
int History.FilePeriod(int hFile) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_NULL(catch("History.FilePeriod(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <= 0) {
         if (hst.hFile[hFile] == 0)                    return(_NULL(catch("History.FilePeriod(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                                       return(_NULL(catch("History.FilePeriod(3)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hst.hFile.valid = hFile;
   }
   return(hhs.Period(hst.fileHeader, hFile));
}


/**
 * Gibt die Anzahl der Digits der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return int - Digits oder -1, falls ein Fehler auftrat
 */
int History.FileDigits(int hFile) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_int(-1, catch("History.FileDigits(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <= 0) {
         if (hst.hFile[hFile] == 0)                    return(_int(-1, catch("History.FileDigits(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                                       return(_int(-1, catch("History.FileDigits(3)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hst.hFile.valid = hFile;
   }
   return(hhs.Digits(hst.fileHeader, hFile));
}


/**
 * Gibt die DB-Version der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return datetime - Versions-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
int History.FileDbVersion(int hFile) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_int(-1, catch("History.FileDbVersion(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <= 0) {
         if (hst.hFile[hFile] == 0)                    return(_int(-1, catch("History.FileDbVersion(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                                       return(_int(-1, catch("History.FileDbVersion(3)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hst.hFile.valid = hFile;
   }
   return(hhs.DbVersion(hst.fileHeader, hFile));
}


/**
 * Gibt die vorherige DB-Version der zu einem Handle gehörenden Historydatei zurück.
 *
 * @param  int hFile - Dateihandle
 *
 * @return datetime - Versions-Zeitpunkt oder -1, falls ein Fehler auftrat
 */
int History.FilePrevDbVersion(int hFile) {
   if (hFile != hst.hFile.valid) {
      if (hFile <= 0 || hFile >= ArraySize(hst.hFile)) return(_int(-1, catch("History.FilePrevDbVersion(1)   invalid or unknown file handle "+ hFile, ERR_INVALID_FUNCTION_PARAMVALUE)));
      if (hst.hFile[hFile] <= 0) {
         if (hst.hFile[hFile] == 0)                    return(_int(-1, catch("History.FilePrevDbVersion(2)   unknown file handle "+ hFile, ERR_RUNTIME_ERROR)));
                                                       return(_int(-1, catch("History.FilePrevDbVersion(3)   closed file handle "+ hFile, ERR_RUNTIME_ERROR)));
      }
      hst.hFile.valid = hFile;
   }
   return(hhs.PrevDbVersion(hst.fileHeader, hFile));
}


/**
 * Schließt alle noch offenen Dateien (wird bei Programmende automatisch aufgerufen).
 *
 * @param  bool warn - ob für noch offene Dateien eine Warnung ausgegeben werden soll (default: nein)
 *
 * @return bool - Erfolgsstatus
 */
bool CloseFiles(bool warn=false) {
   int error, size=ArraySize(hst.hFile);

   for (int i=0; i < size; i++) {
      if (hst.hFile[i] > 0) {
         if (warn) warn(StringConcatenate("CloseFiles()   open file handle "+ hst.hFile[i] +" found: \"", hst.fileName[i], "\""));

         if (!History.CloseFile(hst.hFile[i]))
            error = last_error;
      }
   }
   return(!error);
}
