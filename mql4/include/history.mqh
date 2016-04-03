/**
 * Funktionen zur Verwaltung von Historydateien.
 *
 *  • Alte MetaTrader-Versionen (Format 400) löschen beim Beenden neue Historydateien, wenn sie auf sie zugegriffen haben.
 *  • Neue MetaTrader-Versionen (Format 401) konvertieren beim Beenden alte Historydateien ins neue Format, wenn sie auf sie zugegriffen haben.
 */
#import "history.ex4"

   // Symbol-Management
   int CreateSymbol(string name, string description, string group, int digits, string baseCurrency, string marginCurrency, string serverName="");

   // HistorySet-Management
   int      HistorySet.Create (string symbol, string description, int digits, int format, string server="");
   int      HistorySet.Get    (string symbol, string server="");
   bool     HistorySet.Close  (int hSet);
   bool     HistorySet.AddTick(int hSet, datetime time, double value, int flags=NULL);

   // HistoryFile-Management
   int      HistoryFile.Open     (string symbol, int timeframe, string description, int digits, int format, int mode, string server="");
   bool     HistoryFile.Close    (int hFile);
   int      HistoryFile.FindBar  (int hFile, datetime time, bool lpBarExists[]);
   bool     HistoryFile.ReadBar  (int hFile, int offset, double bar[]);
   bool     HistoryFile.WriteBar (int hFile, int offset, double bar[], int flags=NULL);
   bool     HistoryFile.UpdateBar(int hFile, int offset, double value);
   bool     HistoryFile.InsertBar(int hFile, int offset, double bar[], int flags=NULL);
   bool     HistoryFile.MoveBars (int hFile, int fromOffset, int destOffset);
   bool     HistoryFile.AddTick  (int hFile, datetime time, double value, int flags=NULL);

   // Library-Management
   bool     history.CloseFiles(bool warn=false);
   int      history.GetLastError();

#import
