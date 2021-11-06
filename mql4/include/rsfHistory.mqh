/**
 * Functions for managing MT4 symbols, single history files and full history sets (1 set = 9 timeframes).
 *
 *
 * Notes:
 * ------
 *  - The MQL4 language in terminal builds <= 509 imposes a limit of 16 open files per MQL module. In terminal builds > 509
 *    this limit was extended to 64 open files per MQL module. It means older terminals can manage max. 1 full history set
 *    and newer terminals max. 7 full history sets per MQL module. For some use cases this is still not sufficient.
 *    To overcome this limits there are 3 fully identical history libraries, extending the limits for newer terminal builds
 *    to max. 21 full history sets per MQL program.
 *
 *  - Since terminal builds > 509 MT4 supports two history file formats. The format is identified in history files by the
 *    field HISTORY_HEADER.barFormat. The default bar format in builds <= 509 is "400" and in builds > 509 "401".
 *    Builds <= 509 can only read/write format "400". Builds > 509 can read both formats but write only format "401".
 *
 *  - If a terminal build <= 509 accesses history files in new format (401) it will delete those files on shutdown.
 *
 *  - If a terminal build > 509 accesses history files in old format (400) it will convert them to the new format (401) except
 *    offline history files for custom symbols. Such offline history files will not be converted.
 *
 *  @see  https://github.com/rosasurfer/mt4-expander/blob/master/header/struct/mt4/HistoryHeader.h
 */
#import "rsfHistory1.ex4"
   // history set management (1 set contains 9 history files)
   int  HistorySet1.Create (string symbol, string description, int digits, int format, string directory = "");
   int  HistorySet1.Get    (string symbol, string directory = "");
   bool HistorySet1.Close  (int hSet);
   bool HistorySet1.AddTick(int hSet, datetime time, double value, int flags = NULL);

   // history file management
   int  HistoryFile1.Open     (string symbol, int timeframe, string description, int digits, int format, int mode, string directory = "");
   bool HistoryFile1.Close    (int hFile);
   int  HistoryFile1.FindBar  (int hFile, datetime time, bool lpBarExists[]);
   bool HistoryFile1.ReadBar  (int hFile, int offset, double bar[]);
   bool HistoryFile1.WriteBar (int hFile, int offset, double bar[], int flags = NULL);
   bool HistoryFile1.UpdateBar(int hFile, int offset, double value);
   bool HistoryFile1.InsertBar(int hFile, int offset, double bar[], int flags = NULL);
   bool HistoryFile1.MoveBars (int hFile, int fromOffset, int destOffset);
   bool HistoryFile1.AddTick  (int hFile, datetime time, double value, int flags = NULL);

#import "rsfHistory2.ex4"
   // history set management (1 set contains 9 history files)
   int  HistorySet2.Create (string symbol, string description, int digits, int format, string directory = "");
   int  HistorySet2.Get    (string symbol, string directory = "");
   bool HistorySet2.Close  (int hSet);
   bool HistorySet2.AddTick(int hSet, datetime time, double value, int flags = NULL);

   // history file management
   int  HistoryFile2.Open     (string symbol, int timeframe, string description, int digits, int format, int mode, string directory = "");
   bool HistoryFile2.Close    (int hFile);
   int  HistoryFile2.FindBar  (int hFile, datetime time, bool lpBarExists[]);
   bool HistoryFile2.ReadBar  (int hFile, int offset, double bar[]);
   bool HistoryFile2.WriteBar (int hFile, int offset, double bar[], int flags = NULL);
   bool HistoryFile2.UpdateBar(int hFile, int offset, double value);
   bool HistoryFile2.InsertBar(int hFile, int offset, double bar[], int flags = NULL);
   bool HistoryFile2.MoveBars (int hFile, int fromOffset, int destOffset);
   bool HistoryFile2.AddTick  (int hFile, datetime time, double value, int flags = NULL);

#import "rsfHistory3.ex4"
   // history set management (1 set contains 9 history files)
   int  HistorySet3.Create (string symbol, string description, int digits, int format, string directory = "");
   int  HistorySet3.Get    (string symbol, string directory = "");
   bool HistorySet3.Close  (int hSet);
   bool HistorySet3.AddTick(int hSet, datetime time, double value, int flags = NULL);

   // history file management
   int  HistoryFile3.Open     (string symbol, int timeframe, string description, int digits, int format, int mode, string directory = "");
   bool HistoryFile3.Close    (int hFile);
   int  HistoryFile3.FindBar  (int hFile, datetime time, bool lpBarExists[]);
   bool HistoryFile3.ReadBar  (int hFile, int offset, double bar[]);
   bool HistoryFile3.WriteBar (int hFile, int offset, double bar[], int flags = NULL);
   bool HistoryFile3.UpdateBar(int hFile, int offset, double value);
   bool HistoryFile3.InsertBar(int hFile, int offset, double bar[], int flags = NULL);
   bool HistoryFile3.MoveBars (int hFile, int fromOffset, int destOffset);
   bool HistoryFile3.AddTick  (int hFile, datetime time, double value, int flags = NULL);
#import
