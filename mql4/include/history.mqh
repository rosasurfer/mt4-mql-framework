/**
 * Funktionen zum Verwalten und Bearbeiten von Historydateien (Kursreihen im "history"-Verzeichnis).
 */
#import "history.ex4"

   int      HistoryFile.Open          (string symbol, string description, int digits, int timeframe, int mode);
   bool     HistoryFile.Close         (int hFile);
   int      HistoryFile.FindBar       (int hFile, datetime time, bool lpBarExists[]);
   bool     HistoryFile.ReadBar       (int hFile, int offset, datetime time[], double data[]);
   bool     HistoryFile.InsertBar     (int hFile, int offset, datetime time, double data[], int flags);
   bool     HistoryFile.UpdateBar     (int hFile, int offset, double value);
   bool     HistoryFile.WriteBar      (int hFile, int offset, datetime time, double data[], int flags);
   bool     HistoryFile.WriteCachedBar(int hFile);
   bool     HistoryFile.MoveBars      (int hFile, int startOffset, int destOffset);
   bool     HistoryFile.AddTick       (int hFile, datetime time, double value, int flags);

   bool     History.CloseFiles(bool warn);

   string   hf.Name         (int hFile);
   bool     hf.Read         (int hFile);
   bool     hf.Write        (int hFile);
   int      hf.Size         (int hFile);
   int      hf.Bars         (int hFile);
   datetime hf.From         (int hFile);
   datetime hf.To           (int hFile);
   int      hf.Header       (int hFile, int array[]);
   int      hf.Version      (int hFile);
   string   hf.Symbol       (int hFile);
   string   hf.Description  (int hFile);
   int      hf.Period       (int hFile);
   int      hf.Digits       (int hFile);
   int      hf.DbVersion    (int hFile);
   int      hf.PrevDbVersion(int hFile);


   // Library-Management
   int      hstlib_init  (int type, string name, int whereami, bool isChart, bool isOfflineChart, int _iCustom, int initFlags, int uninitializeReason);
   int      hstlib_deinit(int deinitFlags, int uninitializeReason);
   int      hstlib_GetLastError();

#import
