/**
 *
 */
#include <stddefine.mqh>


#import "stdlib.ex4"

   // MQL-Status- und Laufzeitumgebungs-Informationen
   bool     IsExpert();
   bool     IsIndicator();
   bool     IsScript();
   bool     IndicatorIsTesting();
   bool     ScriptIsTesting();
   bool     This.IsTesting();                   // kurz für: IsTesting() || IndicatorIsTesting() || ScriptIsTesting()

   string   GetTerminalVersion();
   int      GetTerminalBuild();
   int      GetApplicationMainWindow();
   int      GetTesterWindow();
   int      GetUIThreadId();
   string   GetServerDirectory();
   string   GetServerTimezone();                // throws ERR_INVALID_TIMEZONE_CONFIG
   int      GetAccountNumber();
   string   ShortAccountCompany();


   // Terminal-Interaktionen
   int      Menu.Experts(bool enable);
   int      Chart.Expert.Properties();
   int      Chart.SendTick(bool sound);
   int      Tester.Pause();


   // Arrays
   bool     ArrayPopBool(bool array[]);
   int      ArrayPopInt(int array[]);
   double   ArrayPopDouble(double array[]);
   string   ArrayPopString(string array[]);

   bool     ArrayShiftBool(bool array[]);
   int      ArrayShiftInt(int array[]);
   double   ArrayShiftDouble(double array[]);
   string   ArrayShiftString(string array[]);

   int      ArrayDropBool(bool array[], bool value);
   int      ArrayDropInt(int array[], int value);
   int      ArrayDropDouble(double array[], double value);
   int      ArrayDropString(string array[], string value);

   int      ArraySpliceBools(bool array[], int offset, int length);
   int      ArraySpliceInts(int array[], int offset, int length);
   int      ArraySpliceDoubles(double array[], int offset, int length);
   int      ArraySpliceStrings(string array[], int offset, int length);

   int      ArrayPushBool(bool& array[], bool value);
   int      ArrayPushInt(int array[], int value);
   int      ArrayPushDouble(double array[], double value);
   int      ArrayPushString(string array[], string value);

   int      ArrayUnshiftBool(bool array[], bool value);
   int      ArrayUnshiftInt(int array[], int value);
   int      ArrayUnshiftDouble(double array[], double value);
   int      ArrayUnshiftString(string array[], string value);

   bool     BoolInArray(bool haystack[], bool needle);
   bool     IntInArray(int haystack[], int needle);
   bool     DoubleInArray(double haystack[], double needle);
   bool     StringInArray(string haystack[], string needle);

   int      SearchBoolArray(bool haystack[], bool needle);
   int      SearchIntArray(int haystack[], int needle);
   int      SearchDoubleArray(double haystack[], double needle);
   int      SearchStringArray(string haystack[], string needle);

   bool     ReverseBoolArray(bool array[]);
   bool     ReverseIntArray(int array[]);
   bool     ReverseDoubleArray(double array[]);
   bool     ReverseStringArray(string array[]);

   bool     IsReverseIndexedBoolArray(bool array[]);
   bool     IsReverseIndexedIntArray(int array[]);
   bool     IsReverseIndexedDoubleArray(double array[]);
   bool     IsReverseIndexedSringArray(string array[]);

   string   JoinBools(bool array[], string separator);
   string   JoinInts(int array[], string separator);
   string   JoinDoubles(double array[], string separator);
   string   JoinStrings(string array[], string separator);

   int      SumInts(int array[]);
   double   SumDoubles(double array[]);


   // Buffer-Funktionen
   int      InitializeBuffer(int buffer[], int length);
   int      InitializeStringBuffer(string buffer[], int length);

   string   BufferToStr(int buffer[]);
   string   BufferToHexStr(int buffer[]);

   int      BufferGetChar(int buffer[], int pos);
   //int    BufferSetChar(int buffer[], int pos, int char);

   string   BufferCharsToStr(int buffer[], int from, int length);    //string BufferGetStringA(int buffer[], int from, int length);    // Alias
   string   BufferWCharsToStr(int buffer[], int from, int length);   //string BufferGetStringW(int buffer[], int from, int length);    // Alias

   //int    BufferSetStringA(int buffer[], int pos, string value);   //int BufferSetString(int buffer[], int pos, string value);       // Alias
   //int    BufferSetStringW(int buffer[], int pos, string value);

   int      ExplodeStringsA(int buffer[], string results[]);   int ExplodeStrings(int buffer[], string results[]);                     // Alias
   int      ExplodeStringsW(int buffer[], string results[]);


   // Conditional Statements
   bool     ifBool(bool condition, bool bThen, bool bElse);
   int      ifInt(bool condition, int iThen, int iElse);
   double   ifDouble(bool condition, double dThen, double dElse);
   string   ifString(bool condition, string strThen, string strElse);


   // Configuration
   string   GetLocalConfigPath();
   string   GetGlobalConfigPath();

   bool     IsConfigKey(string section, string key);
   bool     IsLocalConfigKey(string section, string key);
   bool     IsGlobalConfigKey(string section, string key);

   bool     GetConfigBool(string section, string key, bool defaultValue);
   int      GetConfigInt(string section, string key, int defaultValue);
   double   GetConfigDouble(string section, string key, double defaultValue);
   string   GetConfigString(string section, string key, string defaultValue);

   bool     GetLocalConfigBool(string section, string key, bool defaultValue);
   int      GetLocalConfigInt(string section, string key, int defaultValue);
   double   GetLocalConfigDouble(string section, string key, double defaultValue);
   string   GetLocalConfigString(string section, string key, string defaultValue);

   bool     GetGlobalConfigBool(string section, string key, bool defaultValue);
   int      GetGlobalConfigInt(string section, string key, int defaultValue);
   double   GetGlobalConfigDouble(string section, string key, double defaultValue);
   string   GetGlobalConfigString(string section, string key, string defaultValue);


   // Date/Time
   datetime FXTToGMT(datetime fxtTime);
   datetime FXTToServerTime(datetime fxtTime);                    // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime GMTToFXT(datetime gmtTime);
   datetime GMTToServerTime(datetime gmtTime);                    // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime ServerToFXT(datetime serverTime);                     // throws ERR_INVALID_TIMEZONE_CONFIG
   datetime ServerToGMT(datetime serverTime);                     // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetFXTToGMTOffset(datetime fxtTime);
   int      GetFXTToServerTimeOffset(datetime fxtTime);           // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetGMTToFXTOffset(datetime gmtTime);
   int      GetGMTToServerTimeOffset(datetime gmtTime);           // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetServerToFXTOffset(datetime serverTime);            // throws ERR_INVALID_TIMEZONE_CONFIG
   int      GetServerToGMTOffset(datetime serverTime);            // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetLocalToGMTOffset();

   datetime GetFXTPrevSessionStartTime(datetime fxtTime);
   datetime GetFXTPrevSessionEndTime(datetime fxtTime);
   datetime GetFXTSessionStartTime(datetime fxtTime);             // throws ERR_MARKET_CLOSED
   datetime GetFXTSessionEndTime(datetime fxtTime);               // throws ERR_MARKET_CLOSED
   datetime GetFXTNextSessionStartTime(datetime fxtTime);
   datetime GetFXTNextSessionEndTime(datetime fxtTime);

   datetime GetGMTPrevSessionStartTime(datetime gmtTime);
   datetime GetGMTPrevSessionEndTime(datetime gmtTime);
   datetime GetGMTSessionStartTime(datetime gmtTime);             // throws ERR_MARKET_CLOSED
   datetime GetGMTSessionEndTime(datetime gmtTime);               // throws ERR_MARKET_CLOSED
   datetime GetGMTNextSessionStartTime(datetime gmtTime);
   datetime GetGMTNextSessionEndTime(datetime gmtTime);

   datetime GetServerPrevSessionStartTime(datetime serverTime);   // throws ERR_INVALID_TIMEZONE_CONFIG
   datetime GetServerPrevSessionEndTime(datetime serverTime);     // throws ERR_INVALID_TIMEZONE_CONFIG
   datetime GetServerSessionStartTime(datetime serverTime);       // throws ERR_INVALID_TIMEZONE_CONFIG, ERR_MARKET_CLOSED
   datetime GetServerSessionEndTime(datetime serverTime);         // throws ERR_INVALID_TIMEZONE_CONFIG, ERR_MARKET_CLOSED
   datetime GetServerNextSessionStartTime(datetime serverTime);   // throws ERR_INVALID_TIMEZONE_CONFIG
   datetime GetServerNextSessionEndTime(datetime serverTime);     // throws ERR_INVALID_TIMEZONE_CONFIG

   string   GetDayOfWeek(datetime time, bool format);
   datetime TimeGMT();


   // Error-Handling
   bool     IsError(int value);
   bool     IsNoError(int value);
   bool     IsErrorCode(int value);
   bool     IsLastError();
   int      SetLastError(int error);
   int      ResetLastError();
   int      stdlib_GetLastError();
   int      stdlib_PeekLastError();


   // Eventlistener, *können* im Programm überschrieben werden
   bool     EventListener.BarOpen        (int    data[], int criteria);
   bool     EventListener.AccountChange  (int    data[], int criteria);
   bool     EventListener.AccountPayment (int    data[], int criteria);
   bool     EventListener.OrderPlace     (int    data[], int criteria);
   bool     EventListener.OrderChange    (int    data[], int criteria);
   bool     EventListener.OrderCancel    (int    data[], int criteria);
   bool     EventListener.PositionOpen   (int    data[], int criteria);
   bool     EventListener.PositionClose  (int    data[], int criteria);
   bool     EventListener.ChartCommand   (string data[], int criteria);
   bool     EventListener.InternalCommand(string data[], int criteria);
   bool     EventListener.ExternalCommand(string data[], int criteria);


   // abstrakte Eventhandler, müssen bei Verwendung implementiert werden (im Programm, nicht hier)
   int      onBarOpen        (int    data[]);
   int      onAccountChange  (int    data[]);
   int      onAccountPayment (int    data[]);
   int      onOrderPlace     (int    data[]);
   int      onOrderChange    (int    data[]);
   int      onOrderCancel    (int    data[]);
   int      onPositionOpen   (int    data[]);
   int      onPositionClose  (int    data[]);
   int      onChartCommand   (string data[]);
   int      onInternalCommand(string data[]);
   int      onExternalCommand(string data[]);


   // Farben
   color    RGB(int red, int green, int blue);

   int      RGBToHSVColor(color rgb, double hsv[]);
   int      RGBValuesToHSVColor(int red, int green, int blue, double hsv[]);

   color    HSVToRGBColor(double hsv[]);
   color    HSVValuesToRGBColor(double hue, double saturation, double value);

   color    Color.ModifyHSV(color rgb, double hue, double saturation, double value);

   string   ColorToRGBStr(color rgb);
   string   ColorToHtmlStr(color rgb);


   // Files, I/O
   bool     IsFile(string pathName);
   bool     IsDirectory(string pathName);
   int      FileReadLines(string filename, string lines[], bool skipEmptyLines);

   int      GetPrivateProfileSectionNames(string fileName, string names[]);
   int      GetPrivateProfileKeys(string lpFileName, string lpSection, string lpKeys[]);
   string   GetPrivateProfileString(string fileName, string section, string key, string defaultValue);
   int      DeletePrivateProfileKey(string lpFileName, string lpSection, string lpKey);


   // Locks
   bool     AquireLock(string mutexName);
   bool     ReleaseLock(string mutexName);


   // MagicNumbers
   int      StrategyId(int magicNumber);
   string   LFX.Currency(int magicNumber);
   int      LFX.CurrencyId(int magicNumber);
   int      LFX.Counter(int magicNumber);
   double   LFX.Units(int magicNumber);
   int      LFX.Instance(int magicNumber);


   // Math, Numbers
   bool     EQ(double a, double b, int digits); bool CompareDoubles(double a, double b);  // MetaQuotes-Alias
   bool     NE(double a, double b, int digits);

   bool     LT(double a, double b, int digits);
   bool     LE(double a, double b, int digits);

   bool     GT(double a, double b, int digits);
   bool     GE(double a, double b, int digits);

   int      Abs(int value);
   int      Min(int value1, int value2);
   int      Max(int value1, int value2);
   double   MathModFix(double a, double b);
   double   MathRoundFix(double value, int decimals);
   int      Sign(double value);
   int      CountDecimals(double value);


   // Strings
   string   CreateString(int length);

   bool     StringIsDigit(string value);
   bool     StringIsInteger(string value);
   bool     StringIsNumeric(string value);

   bool     StringContains(string object, string substring);
   bool     StringIContains(string object, string substring);

   bool     StringStartsWith(string object, string prefix);
   bool     StringIStartsWith(string object, string prefix);
   bool     StringEndsWith(string object, string postfix);
   bool     StringIEndsWith(string object, string postfix);
   bool     StringICompare(string a, string b);

   string   StringLeft(string value, int n);
   string   StringRight(string value, int n);

   string   StringTrim(string value);
   string   StringLeftPad(string input, int length, string pad_string);
   string   StringRightPad(string input, int length, string pad_string);

   string   StringToLower(string value);  string StrToLower(string value);    // Alias
   string   StringToUpper(string value);  string StrToUpper(string value);    // Alias

   int      StringFindR(string object, string search);
   string   StringRepeat(string input, int times);
   string   StringReplace(string object, string search, string replace);
   string   StringSubstrFix(string object, int start, int length);

   int      Explode(string object, string separator, string results[], int limit);
   string   UrlEncode(string value);


   // Tradefunktionen, Orderhandling
   bool     IsTemporaryTradeError(int error);
   bool     IsPermanentTradeError(int error);
   bool     IsTradeOperation(int value);
   bool     IsLongTradeOperation(int value);
   bool     IsShortTradeOperation(int value);
   bool     IsPendingTradeOperation(int value);

   int      OrderSendEx(string symbol, int type, double lots, double price, double slippage, double stopLoss, double takeProfit, string comment, int magicNumber, datetime expires, color markerColor, double execution[]);
   bool     OrderModifyEx(int ticket, double openPrice, double stopLoss, double takeProfit, datetime expires, color markerColor, double execution[]);
   bool     OrderDeleteEx(int ticket, color markerColor, double execution[]);
   bool     OrderCloseEx(int ticket, double lots, double price, double slippage, color markerColor, double execution[]);
   bool     OrderCloseByEx(int ticket, int opposite, color markerColor, double execution[]);
   bool     OrderMultiClose(int tickets[], double slippage, color markerColor, double execution[]);
   bool     DeletePendingOrders(color markerColor);

   int      OrderPush(string location);
   bool     OrderPop(string location);
   bool     OrderSelectByTicket(int ticket, string location, bool orderPush, bool onErrorOrderPop);
   bool     WaitForTicket(int ticket, bool orderKeep);

   bool     ChartMarker.OrderSent_A(int ticket, int digits, color markerColor);
   bool     ChartMarker.OrderSent_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, double stopLoss, double takeProfit, string comment);
   bool     ChartMarker.OrderDeleted_A(int ticket, int digits, color markerColor);
   bool     ChartMarker.OrderDeleted_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, datetime closeTime, double closePrice);
   bool     ChartMarker.OrderFilled_A(int ticket, int pendingType, double pendingPrice, int digits, color markerColor);
   bool     ChartMarker.OrderFilled_B(int ticket, int pendingType, double pendingPrice, int digits, color markerColor, double lots, string symbol, datetime openTime, double openPrice, string comment);
   bool     ChartMarker.OrderModified_A(int ticket, int digits, color markerColor, datetime modifyTime, double oldOpenPrice, double oldStopLoss, double oldTakeProfit);
   bool     ChartMarker.OrderModified_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, datetime modifyTime, double oldOpenPrice, double openPrice, double oldStopLoss, double stopLoss, double oldTakeProfit, double takeProfit, string comment);
   bool     ChartMarker.PositionClosed_A(int ticket, int digits, color markerColor);
   bool     ChartMarker.PositionClosed_B(int ticket, int digits, color markerColor, int type, double lots, string symbol, datetime openTime, double openPrice, datetime closeTime, double closePrice);


   // sonstiges
   int      GetAccountHistory(int account, string results[]);
   int      GetBalanceHistory(int account, datetime times[], double values[]);
   int      SortTicketsChronological(int tickets[]);

   string   GetCurrency(int id);
   int      GetCurrencyId(string currency);

   string   StdSymbol();                                                 // Alias für GetStandardSymbol(Symbol())
   string   GetStandardSymbol(string symbol);                            // Alias für GetStandardSymbolOrAlt(symbol, symbol)
   string   GetStandardSymbolOrAlt(string symbol, string altValue);
   string   GetStandardSymbolStrict(string symbol);

   string   GetSymbolName(string symbol);                                // Alias für GetSymbolNameOrAlt(symbol, symbol)
   string   GetSymbolNameOrAlt(string symbol, string altName);
   string   GetSymbolNameStrict(string symbol);

   string   GetLongSymbolName(string symbol);                            // Alias für GetLongSymbolNameOrAlt(symbol, symbol)
   string   GetLongSymbolNameOrAlt(string symbol, string altValue);
   string   GetLongSymbolNameStrict(string symbol);

   int      IncreasePeriod(int period);
   int      DecreasePeriod(int period);

   int      MovingAverageMethodToId(string method);
   int      PeriodFlag(int period);
   int      PeriodToId(string description);

   string   AppliedPriceDescription(int appliedPrice);
   string   ErrorDescription(int error);
   string   MovingAverageMethodDescription(int method);
   string   OperationTypeDescription(int type);
   string   PeriodDescription(int period);
   string   UninitializeReasonDescription(int reason);

   string   CreateLegendLabel(string name);
   int      RepositionLegend();
   int      RemoveChartObjects(string objects[]);

   int      iAccountBalance(int account, double buffer[], int bar);
   int      iAccountBalanceSeries(int account, double buffer[]);
   int      iBarShiftNext(string symbol, int period, datetime time);     // throws ERR_HISTORY_UPDATE
   int      iBarShiftPrevious(string symbol, int period, datetime time); // throws ERR_HISTORY_UPDATE

   int      ForceAlert(string s1, string s2, string s3, string s4, string s5, string s6, string s7, string s8, string s9, string s10, string s11, string s12, string s13, string s14, string s15, string s16, string s17, string s18, string s19, string s20, string s21, string s22, string s23, string s24, string s25, string s26, string s27, string s28, string s29, string s30, string s31, string s32, string s33, string s34, string s35, string s36, string s37, string s38, string s39, string s40, string s41, string s42, string s43, string s44, string s45, string s46, string s47, string s48, string s49, string s50, string s51, string s52, string s53, string s54, string s55, string s56, string s57, string s58, string s59, string s60, string s61, string s62, string s63);
   int      ForceMessageBox(string message, string caption, int flags);
   void     ForceSound(string soundfile);
   int      SendSMS(string receiver, string message);


   // toString-Funktionen
   string   BoolToStr(bool value);
   string   DoubleToStrEx(double value, int digits);  string DoubleToStrMorePrecision(double value, int precision);  // MetaQuotes-Alias

   string   IntegerToHexStr(int integer); string DecimalToHexStr(int integer);                                       // Alias
   string   ByteToHexStr(int byte);       string CharToHexStr(int char);                                             // Alias
   string   WordToHexStr(int word);
   string   DwordToHexStr(int dword);     string IntToHexStr(int integer);                                           // Alias
   string   StringToHexStr(string value);

   string   BoolsToStr        (bool array[], string separator);
   string   IntsToStr          (int array[], string separator);
   string   CharsToStr         (int array[], string separator);
   string   OperationTypesToStr(int array[], string separator);
   string   TimesToStr    (datetime array[], string separator);
   string   DoublesToStr    (double array[], string separator);
   string   MoneysToStr     (double array[], string separator);
   string   RatesToStr      (double array[], string separator);
   string   StringsToStr    (string array[], string separator);

   string   __whereamiToStr(int id);
   string   AppliedPriceToStr(int appliedPrice);
   string   ErrorToStr(int error);
   string   EventToStr(int event);
   string   ExecutionToStr(double execution[], bool debugOutput);
   string   MessageBoxCmdToStr(int cmd);
   string   MovingAverageMethodToStr(int method);
   string   NumberToStr(double number, string format);
   string   OperationTypeToStr(int type);
   string   PeriodFlagToStr(int flag);
   string   PeriodToStr(int period);
   string   ShellExecuteErrorToStr(int error);
   string   UninitializeReasonToStr(int reason);
   string   WaitForSingleObjectValueToStr(int value);


   // Win32-Funktionen
   string   GetClassName(int hWnd);
   string   GetComputerName();
   string   GetWin32ShortcutTarget(string lnkFile);
   string   GetWindowText(int hWnd);
   int      LoadCursor(int hInstance, int resourceId);
   int      LoadCursorById(int hInstance, int resourceId);
   int      LoadCursorByName(int hInstance, string cursorName);
   int      WinExecAndWait(string cmdLine, int cmdShow);
   int      WM_MT4();                                                // MetaTrader4_Internal_Message (Pseudo-Konstante)


   // Win32-Structs Getter und Setter
   int      pi.hProcess                   (/*PROCESS_INFORMATION*/int pi[]);
   int      pi.hThread                    (/*PROCESS_INFORMATION*/int pi[]);
   int      pi.ProcessId                  (/*PROCESS_INFORMATION*/int pi[]);
   int      pi.ThreadId                   (/*PROCESS_INFORMATION*/int pi[]);

   int      sa.Length                     (/*SECURITY_ATTRIBUTES*/int sa[]);
   int      sa.SecurityDescriptor         (/*SECURITY_ATTRIBUTES*/int sa[]);
   bool     sa.InheritHandle              (/*SECURITY_ATTRIBUTES*/int sa[]);

   int      si.cb                         (/*STARTUPINFO*/int si[]);
   int      si.Desktop                    (/*STARTUPINFO*/int si[]);
   int      si.Title                      (/*STARTUPINFO*/int si[]);
   int      si.X                          (/*STARTUPINFO*/int si[]);
   int      si.Y                          (/*STARTUPINFO*/int si[]);
   int      si.XSize                      (/*STARTUPINFO*/int si[]);
   int      si.YSize                      (/*STARTUPINFO*/int si[]);
   int      si.XCountChars                (/*STARTUPINFO*/int si[]);
   int      si.YCountChars                (/*STARTUPINFO*/int si[]);
   int      si.FillAttribute              (/*STARTUPINFO*/int si[]);
   int      si.Flags                      (/*STARTUPINFO*/int si[]);
   string   si.FlagsToStr                 (/*STARTUPINFO*/int si[]);
   int      si.ShowWindow                 (/*STARTUPINFO*/int si[]);
   string   si.ShowWindowToStr            (/*STARTUPINFO*/int si[]);
   int      si.hStdInput                  (/*STARTUPINFO*/int si[]);
   int      si.hStdOutput                 (/*STARTUPINFO*/int si[]);
   int      si.hStdError                  (/*STARTUPINFO*/int si[]);

   int      si.setCb                      (/*STARTUPINFO*/int si[], int size);
   int      si.setFlags                   (/*STARTUPINFO*/int si[], int flags);
   int      si.setShowWindow              (/*STARTUPINFO*/int si[], int cmdShow);

   int      st.Year                       (/*SYSTEMTIME*/int st[]);
   int      st.Month                      (/*SYSTEMTIME*/int st[]);
   int      st.DayOfWeek                  (/*SYSTEMTIME*/int st[]);
   int      st.Day                        (/*SYSTEMTIME*/int st[]);
   int      st.Hour                       (/*SYSTEMTIME*/int st[]);
   int      st.Minute                     (/*SYSTEMTIME*/int st[]);
   int      st.Second                     (/*SYSTEMTIME*/int st[]);
   int      st.MilliSec                   (/*SYSTEMTIME*/int st[]);

   int      tzi.Bias                      (/*TIME_ZONE_INFORMATION*/int tzi[]);
   string   tzi.StandardName              (/*TIME_ZONE_INFORMATION*/int tzi[]);
   void     tzi.StandardDate              (/*TIME_ZONE_INFORMATION*/int tzi[], /*SYSTEMTIME*/int st[]);
   int      tzi.StandardBias              (/*TIME_ZONE_INFORMATION*/int tzi[]);
   string   tzi.DaylightName              (/*TIME_ZONE_INFORMATION*/int tzi[]);
   void     tzi.DaylightDate              (/*TIME_ZONE_INFORMATION*/int tzi[], /*SYSTEMTIME*/int st[]);
   int      tzi.DaylightBias              (/*TIME_ZONE_INFORMATION*/int tzi[]);

   int      wfd.FileAttributes            (/*WIN32_FIND_DATA*/int wfd[]);
   string   wfd.FileAttributesToStr       (/*WIN32_FIND_DATA*/int wfd[]);
   bool     wfd.FileAttribute.ReadOnly    (/*WIN32_FIND_DATA*/int wfd[]);
   bool     wfd.FileAttribute.Hidden      (/*WIN32_FIND_DATA*/int wfd[]);
   bool     wfd.FileAttribute.System      (/*WIN32_FIND_DATA*/int wfd[]);
   bool     wfd.FileAttribute.Directory   (/*WIN32_FIND_DATA*/int wfd[]);
   bool     wfd.FileAttribute.Archive     (/*WIN32_FIND_DATA*/int wfd[]);
   bool     wfd.FileAttribute.Device      (/*WIN32_FIND_DATA*/int wfd[]);
   bool     wfd.FileAttribute.Normal      (/*WIN32_FIND_DATA*/int wfd[]);
   bool     wfd.FileAttribute.Temporary   (/*WIN32_FIND_DATA*/int wfd[]);
   bool     wfd.FileAttribute.SparseFile  (/*WIN32_FIND_DATA*/int wfd[]);
   bool     wfd.FileAttribute.ReparsePoint(/*WIN32_FIND_DATA*/int wfd[]);
   bool     wfd.FileAttribute.Compressed  (/*WIN32_FIND_DATA*/int wfd[]);
   bool     wfd.FileAttribute.Offline     (/*WIN32_FIND_DATA*/int wfd[]);
   bool     wfd.FileAttribute.NotIndexed  (/*WIN32_FIND_DATA*/int wfd[]);
   bool     wfd.FileAttribute.Encrypted   (/*WIN32_FIND_DATA*/int wfd[]);
   bool     wfd.FileAttribute.Virtual     (/*WIN32_FIND_DATA*/int wfd[]);
   string   wfd.FileName                  (/*WIN32_FIND_DATA*/int wfd[]);
   string   wfd.AlternateFileName         (/*WIN32_FIND_DATA*/int wfd[]);


   // Default-Implementierungen der MQL-Root- und Userfunktionen (unbenutzt, jedoch notwendig)
   int      onInit();
   int      onInitUndefined();
   int      onInitChartClose();
   int      onInitRemove();
   int      onInitRecompile();
   int      onInitParameterChange();
   int      onInitChartChange();
   int      onInitAccountChange();
   int      afterInit();

   int      onStart();
   int      onTick();

   int      onDeinit();
   int      onDeinitUndefined();
   int      onDeinitChartClose();
   int      onDeinitRemove();
   int      onDeinitRecompile();
   int      onDeinitParameterChange();
   int      onDeinitChartChange();
   int      onDeinitAccountChange();
   int      afterDeinit();


   // erweiterte stdlib Root-Funktionen
   int      stdlib_init(int type, string name, int whereami, int initFlags, int uninitializeReason);
   int      stdlib_start(int tick, int validBars, int changedBars);
   int      stdlib_deinit(int deinitFlags, int uninitializeReason);


   // Tests
   string   StaticString();
   bool     StaticBool();
   int      StaticInt();
   double   StaticDouble();

#import


// ShowWindow()-Konstanten für WinExecWait()
#define SW_SHOW                           5        // Details zu diesen Werten in win32api.mqh
#define SW_SHOWNA                         8
#define SW_HIDE                           0
#define SW_SHOWMAXIMIZED                  3
#define SW_MAXIMIZE        SW_SHOWMAXIMIZED
#define SW_SHOWMINIMIZED                  2
#define SW_SHOWMINNOACTIVE                7
#define SW_MINIMIZE                       6
#define SW_FORCEMINIMIZE                 11
#define SW_MAX             SW_FORCEMINIMIZE
#define SW_SHOWNORMAL                     1
#define SW_NORMAL             SW_SHOWNORMAL
#define SW_SHOWNOACTIVATE                 4
#define SW_RESTORE                        9
#define SW_SHOWDEFAULT                   10
