/**
 * Functions for managing MT4 symbols, single history files and full history sets (nine timeframes).
 *
 * Notes:
 * ------
 * With terminal builds > 509 the history file format changed. This is reflected by the format id in the history file headers.
 * Up to builds 509 the field HISTORY_HEADER.barFormat is 400, since builds > 509 the field HISTORY_HEADER.barFormat is 401.
 *
 *  @see  https://github.com/rosasurfer/mt4-expander/blob/master/header/struct/mt4/HistoryHeader.h
 *
 * A terminal supporting only the old format (up to build 509) will delete history files in the new format on shutdown "if it
 * tries to access them". This means history for a symbol may exist in mixed formats. As long as the user doesn't switch to
 * a chart period with history in new format the terminal will keep these new format files untouched. If the user switches to
 * a period with history in new format an old terminal will delete that history on shutdown.
 *
 * A terminal supporting both formats (since builds > 509) will automatically convert files in old format to the new format
 * "if it accessed them". This means as long as the user doesn't switch to a chart period with history in old format the
 * terminal will not convert those files.
 */
#import "rsfHistory.ex4"

   // symbol management
   int  CreateSymbol(string name, string description, string group, int digits, string baseCurrency, string marginCurrency, string serverName = "");

   // history set management (1 set = 9 history files)
   int  HistorySet.Create (string symbol, string description, int digits, int format, string server = "");
   int  HistorySet.Get    (string symbol, string server = "");
   bool HistorySet.Close  (int hSet);
   bool HistorySet.AddTick(int hSet, datetime time, double value, int flags = NULL);

   // history file management
   int  HistoryFile.Open     (string symbol, int timeframe, string description, int digits, int format, int mode, string server = "");
   bool HistoryFile.Close    (int hFile);
   int  HistoryFile.FindBar  (int hFile, datetime time, bool lpBarExists[]);
   bool HistoryFile.ReadBar  (int hFile, int offset, double bar[]);
   bool HistoryFile.WriteBar (int hFile, int offset, double bar[], int flags = NULL);
   bool HistoryFile.UpdateBar(int hFile, int offset, double value);
   bool HistoryFile.InsertBar(int hFile, int offset, double bar[], int flags = NULL);
   bool HistoryFile.MoveBars (int hFile, int fromOffset, int destOffset);
   bool HistoryFile.AddTick  (int hFile, datetime time, double value, int flags = NULL);
#import
