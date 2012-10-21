/**
 *
 */
#import "history.ex4"

   int      History.OpenFile(string symbol, string description, int digits, int period, int mode);
   bool     History.CloseFile(int hFile);
   bool     CloseFiles(bool warn);

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
   bool     History.ReadBar       (int hFile, int bar, datetime time[], double data[]);
   bool     History.InsertBar     (int hFile, int bar, datetime time, double data[], int flags);
   bool     History.UpdateBar     (int hFile, int bar, double value);
   bool     History.WriteBar      (int hFile, int bar, datetime time, double data[], int flags);
   bool     History.WriteCachedBar(int hFile);
   bool     History.MoveBars      (int hFile, int startOffset, int destOffset);
   bool     History.AddTick       (int hFile, datetime time, double value, int flags);

#import
