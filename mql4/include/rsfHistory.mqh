/**
 * Functions for managing MT4 symbols, single history files and full history sets (nine timeframes).
 *
 * Notes:
 * ------
 * With terminal builds > 509 the history file format changed. This is reflected by the format id in the history file headers.
 * In terminal builds <= 509 the field HISTORY_HEADER.barFormat is 400, for builds > 509 the field HISTORY_HEADER.barFormat is 401.
 *
 *  @link  https://github.com/rosasurfer/mt4-expander/blob/master/header/struct/mt4/HistoryHeader.h
 *
 * A terminal supporting only the old format (builds <= 509) will delete history files in the new format on shutdown "if it
 * tries to access them". This means history for a symbol may exist in mixed formats. As long as the user doesn't switch to
 * a chart period with history in new format the terminal will keep these new format files untouched. If the user switches to
 * a period with history in new format an old terminal will delete that history on shutdown.
 *
 * A terminal supporting both formats (builds > 509) will automatically convert files in old format to the new format
 * "if it accessed them". This means as long as the user doesn't switch to a chart period with history in old format the
 * terminal will not convert those files.
 */
#import "rsfHistory1.ex4"
   // history set management (1 set manages 9 history files)
   int  HistorySet1.Create (string symbol, string description, int digits, int format, string server = "");
   int  HistorySet1.Get    (string symbol, string server = "");
   bool HistorySet1.Close  (int hSet);
   bool HistorySet1.AddTick(int hSet, datetime time, double value, int flags = NULL);

   // history file management
   int  HistoryFile1.Open     (string symbol, int timeframe, string description, int digits, int format, int mode, string server = "");
   bool HistoryFile1.Close    (int hFile);
   int  HistoryFile1.FindBar  (int hFile, datetime time, bool lpBarExists[]);
   bool HistoryFile1.ReadBar  (int hFile, int offset, double bar[]);
   bool HistoryFile1.WriteBar (int hFile, int offset, double bar[], int flags = NULL);
   bool HistoryFile1.UpdateBar(int hFile, int offset, double value);
   bool HistoryFile1.InsertBar(int hFile, int offset, double bar[], int flags = NULL);
   bool HistoryFile1.MoveBars (int hFile, int fromOffset, int destOffset);
   bool HistoryFile1.AddTick  (int hFile, datetime time, double value, int flags = NULL);

#import "rsfHistory2.ex4"
   // history set management (1 set manages 9 history files)
   int  HistorySet2.Create (string symbol, string description, int digits, int format, string server = "");
   int  HistorySet2.Get    (string symbol, string server = "");
   bool HistorySet2.Close  (int hSet);
   bool HistorySet2.AddTick(int hSet, datetime time, double value, int flags = NULL);

   // history file management
   int  HistoryFile2.Open     (string symbol, int timeframe, string description, int digits, int format, int mode, string server = "");
   bool HistoryFile2.Close    (int hFile);
   int  HistoryFile2.FindBar  (int hFile, datetime time, bool lpBarExists[]);
   bool HistoryFile2.ReadBar  (int hFile, int offset, double bar[]);
   bool HistoryFile2.WriteBar (int hFile, int offset, double bar[], int flags = NULL);
   bool HistoryFile2.UpdateBar(int hFile, int offset, double value);
   bool HistoryFile2.InsertBar(int hFile, int offset, double bar[], int flags = NULL);
   bool HistoryFile2.MoveBars (int hFile, int fromOffset, int destOffset);
   bool HistoryFile2.AddTick  (int hFile, datetime time, double value, int flags = NULL);

#import "rsfHistory3.ex4"
   // history set management (1 set manages 9 history files)
   int  HistorySet3.Create (string symbol, string description, int digits, int format, string server = "");
   int  HistorySet3.Get    (string symbol, string server = "");
   bool HistorySet3.Close  (int hSet);
   bool HistorySet3.AddTick(int hSet, datetime time, double value, int flags = NULL);

   // history file management
   int  HistoryFile3.Open     (string symbol, int timeframe, string description, int digits, int format, int mode, string server = "");
   bool HistoryFile3.Close    (int hFile);
   int  HistoryFile3.FindBar  (int hFile, datetime time, bool lpBarExists[]);
   bool HistoryFile3.ReadBar  (int hFile, int offset, double bar[]);
   bool HistoryFile3.WriteBar (int hFile, int offset, double bar[], int flags = NULL);
   bool HistoryFile3.UpdateBar(int hFile, int offset, double value);
   bool HistoryFile3.InsertBar(int hFile, int offset, double bar[], int flags = NULL);
   bool HistoryFile3.MoveBars (int hFile, int fromOffset, int destOffset);
   bool HistoryFile3.AddTick  (int hFile, datetime time, double value, int flags = NULL);
#import
