/**
 * Funktionen zum Verwalten und Bearbeiten von Historydateien (Kursreihen im "history"-Verzeichnis).
 */
#import "history.ex4"

   int      History.OpenFile(string symbol, string description, int digits, int timeframe, int mode);
   bool     History.CloseFile(int hFile);
   bool     History.CloseFiles(bool warn);

   string   History.FileName         (int hFile);
   bool     History.FileRead         (int hFile);
   bool     History.FileWrite        (int hFile);
   int      History.FileSize         (int hFile);
   int      History.FileBars         (int hFile);
   datetime History.FileFrom         (int hFile);
   datetime History.FileTo           (int hFile);
   int      History.FileHeader       (int hFile, int array[]);
   int      History.FileVersion      (int hFile);
   string   History.FileSymbol       (int hFile);
   string   History.FileDescription  (int hFile);
   int      History.FilePeriod       (int hFile);
   int      History.FileDigits       (int hFile);
   int      History.FileDbVersion    (int hFile);
   int      History.FilePrevDbVersion(int hFile);

   int      History.FindBar       (int hFile, datetime time, bool lpBarExists[]);
   bool     History.ReadBar       (int hFile, int offset, datetime time[], double data[]);
   bool     History.InsertBar     (int hFile, int offset, datetime time, double data[], int flags);
   bool     History.UpdateBar     (int hFile, int offset, double value);
   bool     History.WriteBar      (int hFile, int offset, datetime time, double data[], int flags);
   bool     History.WriteCachedBar(int hFile);
   bool     History.MoveBars      (int hFile, int startOffset, int destOffset);
   bool     History.AddTick       (int hFile, datetime time, double value, int flags);

   int      hstlib_GetLastError();


   // erweiterte Root-Funktionen
   int      hstlib_init  (int type, string name, int whereami, bool isChart, bool isOfflineChart, int _iCustom, int initFlags, int uninitializeReason);
   int      hstlib_deinit(int deinitFlags, int uninitializeReason);

#import
