/**
 * Funktionen zur Verwaltung von Historydateien.
 *
 *
 *  • Alte MetaTrader-Versionen löschen neue Historydateien (nachdem sie auf sie zugegriffen haben).
 *
 *    - Um die Chartperiode von synthetischen Charts dynamisch umschalten zu können, müssen "symbols.raw" und "symbols.sel" modifiziert werden.
 *    - Synthetische Charts müssen in einem Verzeichnis ohne Serververbindung gespeichert werden, damit "symbols.raw" und "symbols.sel" modifiziert werden können.
 *    - In einem Verzeichnis ohne Serververbindung müssen "symbols.raw" und "symbols.sel" nicht extra geschützt werden.
 *    - Synthetische Charts müssen automatisiert aufgerufen werden können (vor allem nach Tests).
 *
 *
 *
 *
 *  • Neue MetaTrader-Versionen setzen die Variablen Digits und Point in Offline-Charts permanent falsch, bei alten Versionen reicht es, das Template neuzuladen.
 *
 *  • Das Wechseln der SuperBar-Timeframes funktioniert in Offline-Charts nicht.
 *
 *
 */
#import "history.ex4"

   int      HistorySet.Create (string symbol, string description, int digits, int format);
   int      HistorySet.Get    (string symbol);
   bool     HistorySet.Close  (int hSet);
   bool     HistorySet.AddTick(int hSet, datetime time, double value, int flags=NULL);

   int      HistoryFile.Open             (string symbol, int timeframe, string description, int digits, int format, int mode);
   bool     HistoryFile.Close            (int hFile);
   int      HistoryFile.FindBar          (int hFile, datetime time, int flags, bool lpBarExists[]);
   bool     HistoryFile.ReadBar          (int hFile, int offset, double bar[]);
   bool     HistoryFile.WriteBar         (int hFile, int offset, double bar[], int flags=NULL);
   bool     HistoryFile.InsertBar        (int hFile, int offset, double bar[], int flags=NULL);
   bool     HistoryFile.UpdateBar        (int hFile, int offset, double value);
   bool     HistoryFile.WriteCurrentBar  (int hFile, int flags=NULL);
   bool     HistoryFile.WriteCollectedBar(int hFile, int flags=NULL);
   bool     HistoryFile.MoveBars         (int hFile, int startOffset, int destOffset);
   bool     HistoryFile.AddTick          (int hFile, datetime time, double value, int flags=NULL);

   string   hf.Name       (int hFile);
   bool     hf.ReadAccess (int hFile);
   bool     hf.WriteAccess(int hFile);
   int      hf.Size       (int hFile);
   int      hf.Bars       (int hFile);
   datetime hf.From       (int hFile);
   datetime hf.To         (int hFile);
   int      hf.Header     (int hFile, int array[]);
   int      hf.Format     (int hFile);
   string   hf.Symbol     (int hFile);
   string   hf.Description(int hFile);
   int      hf.Period     (int hFile);
   int      hf.Digits     (int hFile);
   int      hf.SyncMark   (int hFile);
   int      hf.LastSync   (int hFile);


   // Library-Management
   bool     history.CloseFiles(bool warn=false);
   int      history.GetLastError();

#import
