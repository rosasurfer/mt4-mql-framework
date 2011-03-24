/**
 * stdlib.mqh
 */
#include <stddefine.mqh>         // constants definition etc.


#import "stdlib.ex4"

   // Laufzeitfunktionen
   void     stdlib_init(string scriptName);
   void     stdlib_onTick(int validBars);
   int      stdlib_GetLastError();
   int      stdlib_PeekLastError();

   // Arrays
   int      ArrayPushDouble(double& array[], double value);
   int      ArrayPushInt(int& array[], int value);
   int      ArrayPushString(string& array[], string value);
   bool     IsReverseIndexedDoubleArray(double& array[]);
   bool     IsReverseIndexedIntArray(int& array[]);
   bool     IsReverseIndexedSringArray(string& array[]);
   string   JoinBools(bool& values[], string separator);
   string   JoinDoubles(double& values[], string separator);
   string   JoinInts(int& values[], string separator);
   string   JoinStrings(string& values[], string separator);
   bool     ReverseDoubleArray(double& array[]);
   bool     ReverseIntArray(int& array[]);
   bool     ReverseStringArray(string& array[]);

   // Conditional Statements
   double   ifDouble(bool condition, double dThen, double dElse);
   int      ifInt(bool condition, int iThen, int iElse);
   string   ifString(bool condition, string strThen, string strElse);

   // Config
   string   GetLocalConfigPath();
   string   GetGlobalConfigPath();
   bool     GetConfigBool(string section, string key, bool defaultValue);
   double   GetConfigDouble(string section, string key, double defaultValue);
   int      GetConfigInt(string section, string key, int defaultValue);
   string   GetConfigString(string section, string key, string defaultValue);
   bool     GetGlobalConfigBool(string section, string key, bool defaultValue);
   double   GetGlobalConfigDouble(string section, string key, double defaultValue);
   int      GetGlobalConfigInt(string section, string key, int defaultValue);
   string   GetGlobalConfigString(string section, string key, string defaultValue);
   bool     GetLocalConfigBool(string section, string key, bool defaultValue);
   double   GetLocalConfigDouble(string section, string key, double defaultValue);
   int      GetLocalConfigInt(string section, string key, int defaultValue);
   string   GetLocalConfigString(string section, string key, string defaultValue);

   // Date/Time
   datetime EasternToGMT(datetime easternTime);
 //datetime EasternToLocalTime(datetime easternTime);
   datetime EasternToServerTime(datetime easternTime);
   datetime GmtToEasternTime(datetime gmtTime);
 //datetime GmtToLocalTime(datetime gmtTime);
   datetime GmtToServerTime(datetime gmtTime);
 //datetime LocalToEasternTime(datetime localTime);
 //datetime LocalToGMT(datetime localTime);
 //datetime LocalToServerTime(datetime localTime);
   datetime ServerToEasternTime(datetime serverTime);
   datetime ServerToGMT(datetime serverTime);
 //datetime ServerToLocalTime(datetime serverTime);

   int      GetEasternToGmtOffset(datetime easternTime);
 //int      GetEasternToLocalTimeOffset(datetime easternTime);
   int      GetEasternToServerTimeOffset(datetime easternTime);
   int      GetGmtToEasternTimeOffset(datetime gmtTime);
 //int      GetGmtToLocalTimeOffset(datetime gmtTime);
   int      GetGmtToServerTimeOffset(datetime gmtTime);
 //int      GetLocalToEasternTimeOffset();
   int      GetLocalToGmtOffset(datetime localTime);
 //int      GetLocalToServerTimeOffset();
   int      GetServerToEasternTimeOffset(datetime serverTime);
   int      GetServerToGmtOffset(datetime serverTime);
 //int      GetServerToLocalTimeOffset(datetime serverTime);

   datetime GetEasternNextSessionEndTime(datetime easternTime);
   datetime GetEasternNextSessionStartTime(datetime easternTime);
   datetime GetEasternPrevSessionEndTime(datetime easternTime);
   datetime GetEasternPrevSessionStartTime(datetime easternTime);
   datetime GetEasternSessionEndTime(datetime easternTime);
   datetime GetEasternSessionStartTime(datetime easternTime);

   datetime GetGmtNextSessionEndTime(datetime gtmTime);
   datetime GetGmtNextSessionStartTime(datetime gtmTime);
   datetime GetGmtPrevSessionEndTime(datetime gtmTime);
   datetime GetGmtPrevSessionStartTime(datetime gtmTime);
   datetime GetGmtSessionEndTime(datetime gmtTime);
   datetime GetGmtSessionStartTime(datetime gmtTime);

 //datetime GetLocalNextSessionEndTime(datetime localTime);
 //datetime GetLocalNextSessionStartTime(datetime localTime);
 //datetime GetLocalPrevSessionEndTime(datetime localTime);
 //datetime GetLocalPrevSessionStartTime(datetime localTime);
 //datetime GetLocalSessionEndTime(datetime localTime);
 //datetime GetLocalSessionStartTime(datetime localTime);

   datetime GetServerNextSessionEndTime(datetime serverTime);
   datetime GetServerNextSessionStartTime(datetime serverTime);
   datetime GetServerPrevSessionEndTime(datetime serverTime);
   datetime GetServerPrevSessionStartTime(datetime serverTime);
   datetime GetServerSessionEndTime(datetime serverTime);
   datetime GetServerSessionStartTime(datetime serverTime);

   string   GetDayOfWeek(datetime time, bool format);
   string   GetTradeServerTimezone();
   datetime TimeGMT();

   // Eventlistener
   bool     EventListener(int event, int& lpResults[], int flags);
   bool     EventListener.AccountChange(int& lpResults[], int flags);
   bool     EventListener.AccountPayment(int& lpResults[], int flags);
   bool     EventListener.BarOpen(int& lpResults[], int flags);
   bool     EventListener.HistoryChange(int& lpResults[], int flags);
   bool     EventListener.OrderCancel(int& lpResults[], int flags);
   bool     EventListener.OrderChange(int& lpResults[], int flags);
   bool     EventListener.OrderPlace(int& lpResults[], int flags);
   bool     EventListener.PositionClose(int& lpResults[], int flags);
   bool     EventListener.PositionOpen(int& lpResults[], int flags);

   // Eventhandler
   int      onAccountChange(int details[]);
   int      onAccountPayment(int tickets[]);
   int      onBarOpen(int details[]);
   int      onHistoryChange(int tickets[]);
   int      onOrderCancel(int tickets[]);
   int      onOrderChange(int tickets[]);
   int      onOrderPlace(int tickets[]);
   int      onPositionClose(int tickets[]);
   int      onPositionOpen(int tickets[]);

   // EventTracker (Indikator)
   bool     EventTracker.GetBandLimits(double& lpLimits[3]);
   bool     EventTracker.SetBandLimits(double& lpLimits[3]);
   bool     EventTracker.GetGridLimits(double& lpLimits[2]);
   int      EventTracker.SaveGridLimits(double upperLimit, double lowerLimit);

   // Files, I/O
   int      FileReadLines(string filename, string& lpResult[], bool skipEmptyLines);
   string   GetShortcutTarget(string lnkFile);
   bool     IsDir(string pathName);
   bool     IsFile(string pathName);

   // Math, Numbers
   bool     CompareDoubles(double double1, double double2);
   int      CountDecimals(double number);
   string   DecimalToHex(int number);
   string   FormatNumber(double number, string mask);
   double   MathModFix(double a, double b);
   double   MathRoundFix(double number, int decimals);
   int      MathSign(double number);

   // Strings
   int      Explode(string object, string separator, string& lpResults[]);
   bool     StringContains(string object, string substring);
   bool     StringEndsWith(string object, string postfix);
   int      StringFindR(string object, string search);
   bool     StringICompare(string string1, string string2);
   bool     StringIContains(string object, string substring);
   bool     StringIEndsWith(string object, string postfix);
   bool     StringIStartsWith(string object, string prefix);
   bool     StringIsDigit(string value);
   string   StringLeft(string value, int n);
   string   StringRepeat(string input, int times);
   string   StringReplace(string object, string search, string replace);
   string   StringRight(string value, int n);
   bool     StringStartsWith(string object, string prefix);
   string   StringSubstrFix(string object, int start, int length);
   string   StringToLower(string value);
   string   StringToUpper(string value);
   string   StringTrim(string value);
   string   UrlEncode(string value);


   // Trade-Funktionen
   bool     IsPermanentTradeError(int error);
   bool     IsTemporaryTradeError(int error);
   bool     IsTradeOperationType(int value);
   int      OrderSendEx(string symbol, int operation, double volume, double price, int slippage, double stopLoss, double takeProfit, string comment, int magicNumber, datetime expiration, color marker);


   // sonstiges
   int      DecreasePeriod(int period);
   string   ErrorDescription(int error);
   string   FindStandardSymbol(string symbol, string defaultValue);
   string   GetAccountDirectory(int account);
   int      GetAccountHistory(int account, string& lpResults[][HISTORY_COLUMNS]);
   int      GetAccountNumber();
   double   GetAverageSpread(string symbol);
   int      GetBalanceHistory(int account, datetime& lpTimes[], double& lpValues[]);
   string   GetComputerName();
   int      GetMovingAverageCode(string description);
   int      GetPeriod(string description);
   int      GetPeriodFlag(int period);
   string   GetStandardSymbol(string symbol);
   string   GetSymbolLongName(string symbol, string defaultName);
   string   GetSymbolName(string symbol, string defaultName);
   int      GetTerminalWindow();
   string   GetTradeServerDirectory();
   string   GetWindowText(int hWnd);
   int      IncreasePeriod(int period);
   int      RegisterChartObject(string label, string& lpObjects[]);
   int      RemoveChartObjects(string& lpObjects[]);
   int      SendTextMessage(string receiver, string message);
   int      SendTick(bool sound);
   int      SetWindowText(int hWnd, string text);
   string   UninitializeReasonDescription(int reason);
   int      WinExecAndWait(string cmdLine, int cmdShow);
   int      iBalance(int account, double& lpBuffer[], int bar);
   int      iBalanceSeries(int account, double& lpBuffer[]);
   int      iBarShiftNext(string symbol, int period, datetime time);
   int      iBarShiftPrevious(string symbol, int period, datetime time);

   // toString-Funktionen
   string   BoolArrayToStr(bool& values[]);
   string   BoolToStr(bool value);
   string   DoubleArrayToStr(double& values[]);
   string   ErrorToStr(int error);
   string   EventToStr(int event);
   string   IntArrayToStr(int& values[]);
   string   IntToHexStr(int integer);
   string   IntegerToHexStr(int integer);                            // MetaQuotes-Alias
   string   NumberToStr(double number, string mask);
   string   OperationTypeToStr(int type);
   string   PeriodFlagToStr(int flag);
   string   PeriodToStr(int period);
   string   ShellExecuteErrorToStr(int error);
   string   StringArrayToStr(string& values[]);
   string   StructCharToStr(int& lpStruct[], int from, int len);
   string   StructToHexStr(int& lpStruct[]);
   string   StructToStr(int& lpStruct[]);
   string   StructWCharToStr(int& lpStruct[], int from, int len);
   string   TimeframeToStr(int timeframe);
   string   UninitializeReasonToStr(int reason);
   string   WaitForSingleObjectValueToStr(int value);

   // Win32-Structs Getter und Setter
   int      pi.hProcess          (/*PROCESS_INFORMATION*/ int& pi[]);
   int      pi.hThread           (/*PROCESS_INFORMATION*/ int& pi[]);
   int      pi.ProcessId         (/*PROCESS_INFORMATION*/ int& pi[]);
   int      pi.ThreadId          (/*PROCESS_INFORMATION*/ int& pi[]);

   int      sa.Length            (/*SECURITY_ATTRIBUTES*/ int& sa[]);
   int      sa.SecurityDescriptor(/*SECURITY_ATTRIBUTES*/ int& sa[]);
   bool     sa.InheritHandle     (/*SECURITY_ATTRIBUTES*/ int& sa[]);

   int      si.cb                (/*STARTUPINFO*/ int& si[]);
   int      si.Desktop           (/*STARTUPINFO*/ int& si[]);
   int      si.Title             (/*STARTUPINFO*/ int& si[]);
   int      si.X                 (/*STARTUPINFO*/ int& si[]);
   int      si.Y                 (/*STARTUPINFO*/ int& si[]);
   int      si.XSize             (/*STARTUPINFO*/ int& si[]);
   int      si.YSize             (/*STARTUPINFO*/ int& si[]);
   int      si.XCountChars       (/*STARTUPINFO*/ int& si[]);
   int      si.YCountChars       (/*STARTUPINFO*/ int& si[]);
   int      si.FillAttribute     (/*STARTUPINFO*/ int& si[]);
   int      si.Flags             (/*STARTUPINFO*/ int& si[]);
   string   si.FlagsToStr        (/*STARTUPINFO*/ int& si[]);
   int      si.ShowWindow        (/*STARTUPINFO*/ int& si[]);
   string   si.ShowWindowToStr   (/*STARTUPINFO*/ int& si[]);
   int      si.hStdInput         (/*STARTUPINFO*/ int& si[]);
   int      si.hStdOutput        (/*STARTUPINFO*/ int& si[]);
   int      si.hStdError         (/*STARTUPINFO*/ int& si[]);

   int      si.setCb             (/*STARTUPINFO*/ int& si[], int size);
   int      si.setFlags          (/*STARTUPINFO*/ int& si[], int flags);
   int      si.setShowWindow     (/*STARTUPINFO*/ int& si[], int cmdShow);

   int      st.Year              (/*SYSTEMTIME*/ int& st[]);
   int      st.Month             (/*SYSTEMTIME*/ int& st[]);
   int      st.DayOfWeek         (/*SYSTEMTIME*/ int& st[]);
   int      st.Day               (/*SYSTEMTIME*/ int& st[]);
   int      st.Hour              (/*SYSTEMTIME*/ int& st[]);
   int      st.Minute            (/*SYSTEMTIME*/ int& st[]);
   int      st.Second            (/*SYSTEMTIME*/ int& st[]);
   int      st.MilliSec          (/*SYSTEMTIME*/ int& st[]);

   int      tzi.Bias             (/*TIME_ZONE_INFORMATION*/ int& tzi[]);
   string   tzi.StandardName     (/*TIME_ZONE_INFORMATION*/ int& tzi[]);
   void     tzi.StandardDate     (/*TIME_ZONE_INFORMATION*/ int& tzi[], /*SYSTEMTIME*/ int& st[]);
   int      tzi.StandardBias     (/*TIME_ZONE_INFORMATION*/ int& tzi[]);
   string   tzi.DaylightName     (/*TIME_ZONE_INFORMATION*/ int& tzi[]);
   void     tzi.DaylightDate     (/*TIME_ZONE_INFORMATION*/ int& tzi[], /*SYSTEMTIME*/ int& st[]);
   int      tzi.DaylightBias     (/*TIME_ZONE_INFORMATION*/ int& tzi[]);

   int      wfd.FileAttributes            (/*WIN32_FIND_DATA*/ int& wfd[]);
   string   wdf.FileAttributesToStr       (/*WIN32_FIND_DATA*/ int& wdf[]);
   bool     wfd.FileAttribute.ReadOnly    (/*WIN32_FIND_DATA*/ int& wfd[]);
   bool     wfd.FileAttribute.Hidden      (/*WIN32_FIND_DATA*/ int& wfd[]);
   bool     wfd.FileAttribute.System      (/*WIN32_FIND_DATA*/ int& wfd[]);
   bool     wfd.FileAttribute.Directory   (/*WIN32_FIND_DATA*/ int& wfd[]);
   bool     wfd.FileAttribute.Archive     (/*WIN32_FIND_DATA*/ int& wfd[]);
   bool     wfd.FileAttribute.Device      (/*WIN32_FIND_DATA*/ int& wfd[]);
   bool     wfd.FileAttribute.Normal      (/*WIN32_FIND_DATA*/ int& wfd[]);
   bool     wfd.FileAttribute.Temporary   (/*WIN32_FIND_DATA*/ int& wfd[]);
   bool     wfd.FileAttribute.SparseFile  (/*WIN32_FIND_DATA*/ int& wfd[]);
   bool     wfd.FileAttribute.ReparsePoint(/*WIN32_FIND_DATA*/ int& wfd[]);
   bool     wfd.FileAttribute.Compressed  (/*WIN32_FIND_DATA*/ int& wfd[]);
   bool     wfd.FileAttribute.Offline     (/*WIN32_FIND_DATA*/ int& wfd[]);
   bool     wfd.FileAttribute.NotIndexed  (/*WIN32_FIND_DATA*/ int& wfd[]);
   bool     wfd.FileAttribute.Encrypted   (/*WIN32_FIND_DATA*/ int& wfd[]);
   bool     wfd.FileAttribute.Virtual     (/*WIN32_FIND_DATA*/ int& wfd[]);
   string   wfd.FileName                  (/*WIN32_FIND_DATA*/ int& wfd[]);
   string   wfd.AlternateFileName         (/*WIN32_FIND_DATA*/ int& wfd[]);



   // ----------------------------------------------------------------------------------
   // Original-MetaQuotes Funktionen   !!! NICHT VERWENDEN !!!
   //
   // Diese Funktionen sind teilweise noch fehlerhaft.
   // ----------------------------------------------------------------------------------
   string   DoubleToStrMorePrecision(double number, int precision);
   int      RGB(int red, int green, int blue);

#import
