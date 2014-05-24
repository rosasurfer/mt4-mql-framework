/**
 * Funktionen zum Verwalten und Bearbeiten von Historydateien (Kursreihen im "history"-Verzeichnis).
 *
 * Dateiformat ".hst":
 * -------------------
 * struct HISTORY_HEADER {
 *   int  version;               //   4      => hh[ 0]      // HST-Formatversion (MT4: immer 400)
 *   char description[64];       //  64      => hh[ 1]      // Beschreibung
 *   char symbol[12];            //  12      => hh[17]      // Symbol
 *   int  period;                //   4      => hh[20]      // Timeframe
 *   int  digits;                //   4      => hh[21]      // Digits
 *   int  dbVersion;             //   4      => hh[22]      // Server-Datenbankversion (timestamp)
 *   int  prevDbVersion;         //   4      => hh[23]      // LastSync                (timestamp)    // unbenutzt
 *   int  reserved[13];          //  52      => hh[24]      //                                        // unbenutzt
 * } hh;                         // 148 byte = int[37]
 */

#import "history.ex4"

   int      CreateHistory(string symbol, string description, int digits);
   int      FindHistory(string symbol);
   bool     ResetHistory(int hHst);
   bool     History.AddTick(int hHst, datetime time, double value, bool flags=NULL);
   bool     History.CloseFiles(bool warn);

   int      HistoryFile.Open           (string symbol, string description, int digits, int timeframe, int mode);
   bool     HistoryFile.Close          (int hFile);
   int      HistoryFile.FindBar        (int hFile, datetime time, bool lpBarExists[]);
   bool     HistoryFile.ReadBar        (int hFile, int offset, datetime time[], double data[]);
   bool     HistoryFile.InsertBar      (int hFile, int offset, datetime time, double data[], int flags=NULL);
   bool     HistoryFile.UpdateBar      (int hFile, int offset, double value);
   bool     HistoryFile.WriteBar       (int hFile, int offset, datetime time, double data[], int flags=NULL);
   bool     HistoryFile.WriteCurrentBar(int hFile, int flags=NULL);
   bool     HistoryFile.WriteTickBar   (int hFile, int flags=NULL);
   bool     HistoryFile.MoveBars       (int hFile, int startOffset, int destOffset);
   bool     HistoryFile.AddTick        (int hFile, datetime time, double value, int flags=NULL);

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
   int      history_init  (/*EXECUTION_CONTEXT*/int ec[]);
   int      history_deinit(/*EXECUTION_CONTEXT*/int ec[]);
   int      history_GetLastError();

#import
