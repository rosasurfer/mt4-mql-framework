/**
 * je Modultyp implementierte Statusfunktionen (core):
 * ---------------------------------------------------
 *  bool IsExpert();
 *  bool IsScript();
 *  bool IsIndicator();
 *  bool IsLibrary();
 *
 *  bool Expert.IsTesting();
 *  bool Script.IsTesting();
 *  bool Indicator.IsTesting();
 *  bool This.IsTesting();
 *
 *  int  InitReason();
 *  int  DeinitReason();
 *  int  InitExecutionContext();                                     // außer in Libraries (dort nicht notwendig)
 *  bool IsSuperContext();
 *
 *  int  SetLastError(int error, int param);
 *  int  CheckProgramStatus(int value);
 */

#import "stdlib1.ex4"

   // Status- und Laufzeit-Informationen
   bool     Init.IsNoTick();
   bool     Init.IsNewSymbol(string symbol);
   void     Init.StoreSymbol(string symbol);

   bool     IsLogging();
   int      SetCustomLog(int id, string file);
   int      GetCustomLogID();
   string   GetCustomLogFile(int id);

   bool     IsError(int value);
   int      stdlib.GetLastError();

   string   GetTerminalVersion();
   int      GetTerminalBuild();
   int      GetApplicationWindow();
   int      GetTesterWindow();
   int      GetUIThreadId();
   string   GetServerDirectory();

   bool     Tester.IsPaused();
   bool     Tester.IsStopped();

   int      MT4InternalMsg(); int WM_MT4();  // Alias                // MetaTrader4_Internal_Message (kann wie Pseudo-Konstante benutzt werden)


   // Account-Informationen
   int      GetAccountNumber();
   string   ShortAccountCompany();
   string   GetServerTimezone(); // throws ERR_INVALID_TIMEZONE_CONFIG
   double   GetCommission();
   int      DebugMarketInfo(string location);


   // Terminal-Interaktionen
   int      Toolbar.Experts(bool enable);
   int      Chart.Expert.Properties();
   int      Chart.Objects.UnselectAll();
   int      Chart.Refresh();
   int      Chart.SendTick(bool sound);
   int      MarketWatch.Symbols();
   int      Tester.Pause();
   int      Tester.Stop();


   // Arrays
   int      ArraySetIntArray    (int array[][], int i, int values[]);

   int      ArrayPushBool       (bool   array[],   bool   value   );
   int      ArrayPushInt        (int    array[],   int    value   );
   int      ArrayPushIntArray   (int    array[][], int    values[]);
   int      ArrayPushDouble     (double array[],   double value   );
   int      ArrayPushString     (string array[],   string value   );

   bool     ArrayPopBool        (bool   array[]);
   int      ArrayPopInt         (int    array[]);
   double   ArrayPopDouble      (double array[]);
   string   ArrayPopString      (string array[]);

   int      ArrayUnshiftBool    (bool   array[], bool   value);
   int      ArrayUnshiftInt     (int    array[], int    value);
   int      ArrayUnshiftDouble  (double array[], double value);
   int      ArrayUnshiftString  (string array[], string value);

   bool     ArrayShiftBool      (bool   array[]);
   int      ArrayShiftInt       (int    array[]);
   double   ArrayShiftDouble    (double array[]);
   string   ArrayShiftString    (string array[]);

   int      ArrayDropBool       (bool   array[], bool   value);
   int      ArrayDropInt        (int    array[], int    value);
   int      ArrayDropDouble     (double array[], double value);
   int      ArrayDropString     (string array[], string value);

   int      ArraySpliceBools    (bool   array[],   int offset, int length);
   int      ArraySpliceInts     (int    array[],   int offset, int length);
   int      ArraySpliceIntArrays(int    array[][], int offset, int length);
   int      ArraySpliceDoubles  (double array[],   int offset, int length);
   int      ArraySpliceStrings  (string array[],   int offset, int length);

   int      ArrayInsertBool       (bool   array[],   int offset, bool   value   );
   int      ArrayInsertBools      (bool   array[],   int offset, bool   values[]);
   int      ArrayInsertInt        (int    array[],   int offset, int    value   );
   int      ArrayInsertInts       (int    array[],   int offset, int    values[]);
   int      ArrayInsertDouble     (double array[],   int offset, double value   );
   int      ArrayInsertDoubles    (double array[],   int offset, double values[]);
#import "stdlib2.ex4"
   int      ArrayInsertDoubleArray(double array[][], int offset, double values[]);
   int      ArrayInsertString     (string array[],   int offset, string value   );
   int      ArrayInsertStrings    (string array[],   int offset, string values[]);

#import "stdlib1.ex4"
   bool     BoolInArray   (bool   haystack[], bool   needle);
   bool     IntInArray    (int    haystack[], int    needle);
   bool     DoubleInArray (double haystack[], double needle);
   bool     StringInArray (string haystack[], string needle);
   bool     StringInArrayI(string haystack[], string needle);

   int      SearchBoolArray   (bool   haystack[], bool   needle);
   int      SearchIntArray    (int    haystack[], int    needle);
   int      SearchDoubleArray (double haystack[], double needle);
   int      SearchStringArray (string haystack[], string needle);
   int      SearchStringArrayI(string haystack[], string needle);

   bool     ReverseBoolArray  (bool   array[]);
   bool     ReverseIntArray   (int    array[]);
   bool     ReverseDoubleArray(double array[]);
   bool     ReverseStringArray(string array[]);

   bool     IsReverseIndexedBoolArray  (bool   array[]);
   bool     IsReverseIndexedIntArray   (int    array[]);
   bool     IsReverseIndexedDoubleArray(double array[]);
   bool     IsReverseIndexedSringArray (string array[]);

   int      MergeBoolArrays  (bool   array1[], bool   array2[], bool   merged[]);
   int      MergeIntArrays   (int    array1[], int    array2[], int    merged[]);
   int      MergeDoubleArrays(double array1[], double array2[], double merged[]);
   int      MergeStringArrays(string array1[], string array2[], string merged[]);

   string   JoinBools  (bool   array[], string separator);
   string   JoinInts   (int    array[], string separator);
   string   JoinDoubles(double array[], string separator);
   string   JoinStrings(string array[], string separator);

   int      SumInts   (int    array[]);
   double   SumDoubles(double array[]);


   // Buffer-Funktionen
   int      InitializeCharBuffer  (int    buffer[], int length);  int InitializeByteBuffer(int buffer[], int length);                  // Alias
   int      InitializeDoubleBuffer(double buffer[], int size  );
   int      InitializeStringBuffer(string buffer[], int length);

   string   BufferToStr   (int buffer[]);
   string   BufferToHexStr(int buffer[]);

   int      BufferGetChar(int buffer[], int pos);
   //int    BufferSetChar(int buffer[], int pos, int char);

   string   BufferCharsToStr (int buffer[], int from, int length);  //string BufferGetStringA(int buffer[], int from, int length);     // Alias
   string   BufferWCharsToStr(int buffer[], int from, int length);  //string BufferGetStringW(int buffer[], int from, int length);     // Alias

   int      ExplodeStringsA(int buffer[], string results[]);   int ExplodeStrings(int buffer[], string results[]);                     // Alias
   int      ExplodeStringsW(int buffer[], string results[]);


   // Conditional Statements
   bool     ifBool  (bool condition, bool   bThen, bool   bElse);
   int      ifInt   (bool condition, int    iThen, int    iElse);
   double   ifDouble(bool condition, double dThen, double dElse);
   string   ifString(bool condition, string sThen, string sElse);


   // Configuration
   string   GetLocalConfigPath();
   string   GetGlobalConfigPath();

   bool     IsConfigKey      (string section, string key);
   bool     IsLocalConfigKey (string section, string key);
   bool     IsGlobalConfigKey(string section, string key);

   bool     GetConfigBool     (string section, string key, bool   defaultValue);
   int      GetConfigInt      (string section, string key, int    defaultValue);
   double   GetConfigDouble   (string section, string key, double defaultValue);
   string   GetConfigString   (string section, string key, string defaultValue);
   string   GetRawConfigString(string section, string key, string defaultValue);

   bool     GetLocalConfigBool     (string section, string key, bool   defaultValue);
   int      GetLocalConfigInt      (string section, string key, int    defaultValue);
   double   GetLocalConfigDouble   (string section, string key, double defaultValue);
   string   GetLocalConfigString   (string section, string key, string defaultValue);
   string   GetRawLocalConfigString(string section, string key, string defaultValue);

   bool     GetGlobalConfigBool     (string section, string key, bool   defaultValue);
   int      GetGlobalConfigInt      (string section, string key, int    defaultValue);
   double   GetGlobalConfigDouble   (string section, string key, double defaultValue);
   string   GetGlobalConfigString   (string section, string key, string defaultValue);
   string   GetRawGlobalConfigString(string section, string key, string defaultValue);

   int      GetIniSections(string fileName, string names[]);
   bool     IsIniSection  (string fileName, string section);

   int      GetIniKeys  (string fileName, string section, string names[]);
   bool     IsIniKey    (string fileName, string section, string key    );
   bool     DeleteIniKey(string fileName, string section, string key    );
   bool     GetIniBool     (string fileName, string section, string key, bool   defaultValue);
   int      GetIniInt      (string fileName, string section, string key, int    defaultValue);
   double   GetIniDouble   (string fileName, string section, string key, double defaultValue);
   string   GetIniString   (string fileName, string section, string key, string defaultValue);
   string   GetRawIniString(string fileName, string section, string key, string defaultValue);


   // Date/Time
   datetime FxtToGmtTime   (datetime fxtTime);
   datetime FxtToServerTime(datetime fxtTime);                                                        // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime GmtToFxtTime   (datetime gmtTime);
   datetime GmtToServerTime(datetime gmtTime);                                                        // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime ServerToFxtTime(datetime serverTime);                                                     // throws ERR_INVALID_TIMEZONE_CONFIG
   datetime ServerToGmtTime(datetime serverTime);                                                     // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetFxtToGmtTimeOffset   (datetime fxtTime);
   int      GetFxtToServerTimeOffset(datetime fxtTime);                                               // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetGmtToFxtTimeOffset   (datetime gmtTime);
   int      GetGmtToServerTimeOffset(datetime gmtTime);                                               // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetServerToFxtTimeOffset(datetime serverTime);                                            // throws ERR_INVALID_TIMEZONE_CONFIG
   int      GetServerToGmtTimeOffset(datetime serverTime);                                            // throws ERR_INVALID_TIMEZONE_CONFIG

   int      GetLocalToGmtTimeOffset();

   datetime GetPrevSessionStartTime.fxt(datetime fxtTime   );
   datetime GetPrevSessionStartTime.gmt(datetime gmtTime   );
   datetime GetPrevSessionStartTime.srv(datetime serverTime);                                         // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime GetPrevSessionEndTime.fxt  (datetime fxtTime   );
   datetime GetPrevSessionEndTime.gmt  (datetime gmtTime   );
   datetime GetPrevSessionEndTime.srv  (datetime serverTime);                                         // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime GetSessionStartTime.fxt    (datetime fxtTime   );                                         // throws ERR_MARKET_CLOSED
   datetime GetSessionStartTime.gmt    (datetime gmtTime   );                                         // throws ERR_MARKET_CLOSED
   datetime GetSessionStartTime.srv    (datetime serverTime);                                         // throws ERR_MARKET_CLOSED, ERR_INVALID_TIMEZONE_CONFIG

   datetime GetSessionEndTime.fxt      (datetime fxtTime   );                                         // throws ERR_MARKET_CLOSED
   datetime GetSessionEndTime.gmt      (datetime gmtTime   );                                         // throws ERR_MARKET_CLOSED
   datetime GetSessionEndTime.srv      (datetime serverTime);                                         // throws ERR_MARKET_CLOSED, ERR_INVALID_TIMEZONE_CONFIG

   datetime GetNextSessionStartTime.fxt(datetime fxtTime   );
   datetime GetNextSessionStartTime.gmt(datetime gmtTime   );
   datetime GetNextSessionStartTime.srv(datetime serverTime);                                         // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime GetNextSessionEndTime.fxt  (datetime fxtTime   );
   datetime GetNextSessionEndTime.gmt  (datetime gmtTime   );
   datetime GetNextSessionEndTime.srv  (datetime serverTime);                                         // throws ERR_INVALID_TIMEZONE_CONFIG

   datetime mql.GetLocalTime();
   datetime mql.GetSystemTime();
   string   GetDayOfWeek(datetime time, bool longFormat);
   bool     GetTimezoneTransitions(datetime serverTime, int prevTransition[], int nextTransition[]);  // throws ERR_INVALID_TIMEZONE_CONFIG
   datetime TimeGMT();


   // Event-Listener: Diese allgemeinen Library-Versionen können durch spezielle lokale Versionen überschrieben werden.
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


   // Event-Handler: Diese Library-Versionen sind leere Stubs, bei Verwendung *müssen* die Handler im Programm implementiert werden.
   bool     onBarOpen        (int    data[]);
   bool     onAccountChange  (int    data[]);
   bool     onAccountPayment (int    data[]);
   bool     onOrderPlace     (int    data[]);
   bool     onOrderChange    (int    data[]);
   bool     onOrderCancel    (int    data[]);
   bool     onPositionOpen   (int    data[]);
   bool     onPositionClose  (int    data[]);
   bool     onChartCommand   (string data[]);
   bool     onInternalCommand(string data[]);
   bool     onExternalCommand(string data[]);


   // Farben
   color    RGB(int red, int green, int blue);

   int      RGBToHSVColor(color rgb, double hsv[]);
   int      RGBValuesToHSVColor(int red, int green, int blue, double hsv[]);

   color    HSVToRGBColor(double hsv[]);
   color    HSVValuesToRGBColor(double hue, double saturation, double value);

   color    Color.ModifyHSV(color rgb, double hue, double saturation, double value);

   string   ColorToStr(color rgb);
   string   ColorToRGBStr(color rgb);
   string   ColorToHtmlStr(color rgb);


   // Files, I/O
   bool     IsFile(string filename);
   bool     IsDirectory(string filename);
   bool     IsMqlFile(string filename);
   bool     IsMqlDirectory(string dirname);
   int      FindFileNames(string pattern, string results[], int flags);
   int      FileReadLines(string filename, string lines[], bool skipEmptyLines);

   bool     EditFile (string filename   );
   bool     EditFiles(string filenames[]);


   // Locks
   bool     AquireLock(string mutexName, bool wait);
   bool     ReleaseLock(string mutexName);
   bool     ReleaseLocks(bool warn);


   // Math, Numbers
   bool     EQ(double a, double b, int digits); bool CompareDoubles(double a, double b);  // MetaQuotes-Alias
   bool     NE(double a, double b, int digits);

   bool     LT(double a, double b, int digits);
   bool     LE(double a, double b, int digits);

   bool     GT(double a, double b, int digits);
   bool     GE(double a, double b, int digits);

   int      Div       (int    a, int    b, int    onZero);
   double   MathDiv   (double a, double b, double onZero);
   double   MathModFix(double a, double b);

   int      Abs(int value);
   int      Min(int a, int b);
   int      Max(int a, int b);
   int      Floor     (double value);
   int      Ceil      (double value);
   int      Sign      (double value);
   int      Round     (double value);
   double   RoundEx   (double value, int decimals);
   double   RoundFloor(double value, int decimals);
   double   RoundCeil (double value, int decimals);

   int      CountDecimals(double value);


   // Strings
   string   CreateString(int length);
   string   StringToStr(string value);                               // "value" (mit Anführungszeichen) oder NULL (ohne Anführungszeichen)

   bool     StringIsDigit(string value);
   bool     StringIsInteger(string value);
   bool     StringIsNumeric(string value);
   bool     StringIsNull(string value);

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
   string   StringPad     (string input, int length, string pad_string, int pad_type);
   string   StringPadLeft (string input, int length, string pad_string);   string StringLeftPad (string input, int length, string pad_string);
   string   StringPadRight(string input, int length, string pad_string);   string StringRightPad(string input, int length, string pad_string);

   string   StringToLower(string value);
   string   StringToUpper(string value);

   int      StringFindR(string object, string search);
   string   StringRepeat(string input, int times);
   string   StringReplace          (string object, string search, string replace);
   string   StringReplace.Recursive(string object, string search, string replace);
   string   StringSubstrFix(string object, int start, int length);

   int      Explode(string input, string separator, string results[], int limit);
   string   UrlEncode(string value);


   // Tradefunktionen, Orderhandling
   bool     IsTemporaryTradeError(int error);
   bool     IsPermanentTradeError(int error);
   bool     IsTradeOperation(int value);
   bool     IsLongTradeOperation(int value);
   bool     IsShortTradeOperation(int value);
   bool     IsPendingTradeOperation(int value);

   // s: StopDistance/FreezeDistance integriert
   int /*s*/OrderSendEx(string symbol, int type, double lots, double price, double slippage, double stopLoss, double takeProfit, string comment, int magicNumber, datetime expires, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]);
   bool/*s*/OrderModifyEx(int ticket, double openPrice, double stopLoss, double takeProfit, datetime expires, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]);
   bool     OrderDeleteEx(int ticket, color markerColor, int oeFlags, int /*ORDER_EXECUTION*/oe[]);
   bool     OrderCloseEx(int ticket, double lots, double price, double slippage, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]);
   bool     OrderCloseByEx(int ticket, int opposite, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oe[]);
   bool     OrderMultiClose(int tickets[], double slippage, color markerColor, int oeFlags, /*ORDER_EXECUTION*/int oes[][]);
   bool     DeletePendingOrders(color markerColor);

   int      OrderPush(string location);
   bool     OrderPop(string location);
   bool     SelectTicket(int ticket, string location, bool orderPush, bool onErrorOrderPop);
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
   bool     IsEmpty      (double   value);
   bool     IsEmptyString(string   value);
   bool     IsEmptyValue (double   value);
   bool     IsNaT        (datetime value);

   int      GetAccountHistory(int account, string results[]);
   int      GetBalanceHistory(int account, datetime times[], double values[]);
   double   PipValue(double lots, bool hideErrors);
   int      SortTicketsChronological(int tickets[]);

   string   GetCurrency(int id);
   int      GetCurrencyId(string currency);
   bool     IsCurrency(string value);

   string   StdSymbol();                                                               // Alias für GetStandardSymbol(Symbol())
   string   GetStandardSymbol(string symbol);                                          // Alias für GetStandardSymbolOrAlt(symbol, symbol)
   string   GetStandardSymbolOrAlt(string symbol, string altValue);
   string   GetStandardSymbolStrict(string symbol);

   string   GetSymbolName(string symbol);                                              // Alias für GetSymbolNameOrAlt(symbol, symbol)
   string   GetSymbolNameOrAlt(string symbol, string altName);
   string   GetSymbolNameStrict(string symbol);

   string   GetLongSymbolName(string symbol);                                          // Alias für GetLongSymbolNameOrAlt(symbol, symbol)
   string   GetLongSymbolNameOrAlt(string symbol, string altValue);
   string   GetLongSymbolNameStrict(string symbol);

   int      IncreasePeriod(int period);
   int      DecreasePeriod(int period);

   int      StrToMovAvgMethod(string method);
   int      StrToPeriod(string value);  int StrToTimeframe(string value);              // Alias
   int      PeriodFlag(int period);
   int      StrToOperationType(string value);
   int      StrToPriceType(string value);

   string   CreateLegendLabel(string name);
   int      RepositionLegend();
   bool     ObjectDeleteSilent(string label, string location);
   int      ObjectRegister(string label);  int RegisterObject(string label);           // Alias
   int      DeleteRegisteredObjects(string prefix);

   int      iAccountBalance(int account, double buffer[], int bar);
   int      iAccountBalanceSeries(int account, double buffer[]);
   int      iBarShiftNext(string symbol, int period, datetime time);                   // throws ERS_HISTORY_UPDATE
   int      iBarShiftPrevious(string symbol, int period, datetime time);               // throws ERS_HISTORY_UPDATE

   int      ForceMessageBox(string caption, string message, int flags);
   int      ForceSound(string soundfile);
   bool     SendSMS(string receiver, string message);


   // toString-Funktionen
   string   BoolToStr(bool value);
   string   DoubleToStrEx(double value, int digits/*=0..16*/);  string DoubleToStrMorePrecision(double value, int precision);   // MetaQuotes-Alias

   string   IntegerToBinaryStr(int integer);

   string   IntegerToHexStr(int integer);
   string   ByteToHexStr(int byte);   string CharToHexStr(int char);                                                          // Alias
   string   WordToHexStr(int word);
   string   DwordToHexStr(int dword); string IntToHexStr(int integer); string IntegerToHexString(int integer);                // Alias + MetaQuotes-Alias
   string   StringToHexStr(string value);

#import "stdlib2.ex4"
   string   BoolsToStr        (bool array[], string separator);
   string   IntsToStr          (int array[], string separator);
   string   CharsToStr         (int array[], string separator);
   string   TicketsToStr       (int array[], string separator);
   string   OperationTypesToStr(int array[], string separator);
   string   TimesToStr    (datetime array[], string separator);
   string   DoublesToStr    (double array[], string separator);
   string   iBufferToStr    (double array[], string separator);
   string   MoneysToStr     (double array[], string separator);
   string   RatesToStr      (double array[], string separator); string PricesToStr(double array[], string separator);   // Alias
   string   StringsToStr    (string array[], string separator);

#import "stdlib1.ex4"
   string   ChartPropertiesToStr(int flags);
   string   InitFlagsToStr(int flags);
   string   DateToStr(datetime time, string mask);
   string   DeinitFlagsToStr(int flags);
   string   ErrorDescription(int error);
   string   ErrorToStr      (int error);
   string   EventToStr(int event);
   string   FileAccessModeToStr(int mode);
   string   MessageBoxCmdToStr(int cmd);
   string   ModuleTypeDescription(int type);
   string   ModuleTypeToStr      (int type);
   string   MovAvgMethodDescription(int method);   string MovingAverageMethodDescription(int method); // Alias
   string   MovAvgMethodToStr      (int method);   string MovingAverageMethodToStr      (int method); // Alias
   string   NumberToStr(double number, string format);
   string   OperationTypeDescription(int type);
   string   OperationTypeToStr      (int type);
   string   PeriodFlagToStr(int flag);
   string   PeriodDescription(int period);         string TimeframeDescription(int timeframe);        // Alias
   string   PeriodToStr      (int period);         string TimeframeToStr      (int timeframe);        // Alias
   string   PriceTypeDescription(int type);
   string   PriceTypeToStr      (int type);
   string   ShellExecuteErrorDescription(int error);
   string   SwapCalculationMethodToStr(int method);
   string   UninitializeReasonDescription(int reason);
   string   UninitializeReasonToStr      (int reason);
   string   InitReasonDescription(int reason);
   string   InitReasonToStr      (int reason);
   string   WaitForSingleObjectValueToStr(int value);
   string   __whereamiDescription(int id);
   string   __whereamiToStr(int id);


   // Win32-Funktionen (an MQL angepaßt)
   void     CopyMemory(int source, int destination, int bytes);      // intern als MoveMemory() implementiert
   string   GetClassName(int hWnd);
   string   GetComputerName();
   string   GetWindowsShortcutTarget(string lnkFile);
   string   GetWindowText(int hWnd);
   int      WinExecAndWait(string cmdLine, int cmdShow);


   // leere Library-Stubs, können wenn nötig im Hauptmodul "überschrieben" werden
   int      onInit();
   int      onInit.User();
   int      onInit.Template();
   int      onInit.Program();
   int      onInit.ProgramClearTest();
   int      onInit.Parameters();
   int      onInit.TimeframeChange();
   int      onInit.SymbolChange();
   int      onInit.Recompile();
   int      afterInit();

   int      onStart();                                               // Scripte
   int      onTick();                                                // EA's + Indikatoren

   // alt
   int      onInitParameterChange();
   int      onInitChartChange();
   int      onInitAccountChange();
   int      onInitChartClose();
   int      onInitUndefined();
   int      onInitRemove();
   int      onInitRecompile();
   int      onInitTemplate();                                        // build > 509
   int      onInitFailed();                                          // build > 509
   int      onInitClose();                                           // build > 509

   int      onDeinit();
   int      onDeinitParameterChange();
   int      onDeinitChartChange();
   int      onDeinitAccountChange();
   int      onDeinitChartClose();
   int      onDeinitUndefined();
   int      onDeinitRemove();
   int      onDeinitRecompile();
   int      onDeinitTemplate();                                      // build > 509
   int      onDeinitFailed();                                        // build > 509
   int      onDeinitClose();                                         // build > 509
   int      afterDeinit();

   string   InputsToStr();
   int      ShowStatus(int error);                                   // EA's
   void     DummyCalls();


   // erweiterte Root-Funktionen
   int      stdlib.init  (/*EXECUTION_CONTEXT*/int ec[], int tickData[]);
   int      stdlib.start (/*EXECUTION_CONTEXT*/int ec[], int tick, datetime tickTime, int validBars, int changedBars);
   int      stdlib.deinit(/*EXECUTION_CONTEXT*/int ec[]);


#import "StdLib.dll"
   int      GetBoolsAddress  (bool   array[]);
   int      GetIntsAddress   (int    array[]);  int GetBufferAddress(int buffer[]); // Alias
   int      GetDoublesAddress(double array[]);
   int      GetStringAddress (string value  );
   int      GetStringsAddress(string array[]);
   string   GetString(int address);

   int      GetLastWin32Error();

   bool     IsBuiltinTimeframe(int timeframe);
   bool     IsCustomTimeframe(int timeframe);
#import


// ShowWindow()-Konstanten für WinExecWait(), Details siehe win32api.mqh
#define SW_SHOW                  5
#define SW_SHOWNA                8
#define SW_HIDE                  0
#define SW_SHOWMAXIMIZED         3
#define SW_SHOWMINIMIZED         2
#define SW_SHOWMINNOACTIVE       7
#define SW_MINIMIZE              6
#define SW_FORCEMINIMIZE        11
#define SW_SHOWNORMAL            1
#define SW_SHOWNOACTIVATE        4
#define SW_RESTORE               9
#define SW_SHOWDEFAULT          10
