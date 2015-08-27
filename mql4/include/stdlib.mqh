/**
 * letzte Version mit vollständigem Funktions-Listing: v1.484
 */
#import "stdlib1.ex4"

   // Status- und Laufzeit-Informationen
   bool     Init.IsNoTick();
   bool     Init.IsNewSymbol(string symbol);
   void     Init.StoreSymbol(string symbol);

   int      SetCustomLog(int id, string file);
   int      GetCustomLogID();
   string   GetCustomLogFile(int id);

   int      stdlib.GetLastError();

   string   GetTerminalVersion();
   int      GetTerminalBuild();
#import "stdlib2.ex4"
   int      GetTerminalRuntime();
#import "stdlib1.ex4"
   int      GetTesterWindow();
   string   GetServerName();
   string   GetComputerName();


   // Account-Informationen
   int      GetAccountNumber();
   string   ShortAccountCompany();
   string   GetServerTimezone(); // throws ERR_INVALID_TIMEZONE_CONFIG
   double   GetCommission();


   // Terminal-Interaktionen
   int      Chart.Objects.UnselectAll();
   int      Chart.Refresh();
   int      Chart.SendTick(bool sound);


   // Arrays
   int      ArraySetInts        (int array[][], int i, int values[]);

   int      ArrayPushBool       (bool   array[],   bool   value   );
   int      ArrayPushInt        (int    array[],   int    value   );
   int      ArrayPushInts       (int    array[][], int    values[]);
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

   string   JoinBools    (bool   array[], string separator);
   string   JoinInts     (int    array[], string separator);
   string   JoinDoubles  (double array[], string separator);
   string   JoinDoublesEx(double array[], string separator, int digits);
   string   JoinStrings  (string array[], string separator);

   double   SumDoubles(double array[]);


   // Buffer-Funktionen
   int      InitializeDoubleBuffer(double buffer[], int size  );
   int      InitializeStringBuffer(string buffer[], int length);

   string   BufferToStr   (int buffer[]);
   string   BufferToHexStr(int buffer[]);

   int      BufferGetChar(int buffer[], int pos);
   //int    BufferSetChar(int buffer[], int pos, int char);

   string   BufferWCharsToStr(int buffer[], int from, int length);  //string BufferGetStringW(int buffer[], int from, int length);     // Alias


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

   int      GetIniSections (string fileName, string names[]);
   bool     IsIniSection   (string fileName, string section);

   bool     IsIniKey       (string fileName, string section, string key);
   bool     DeleteIniKey   (string fileName, string section, string key);

   bool     GetIniBool     (string fileName, string section, string key, bool   defaultValue);
   int      GetIniInt      (string fileName, string section, string key, int    defaultValue);
   double   GetIniDouble   (string fileName, string section, string key, double defaultValue);
   string   GetIniString   (string fileName, string section, string key, string defaultValue);
   string   GetRawIniString(string fileName, string section, string key, string defaultValue);


   // Date/Time
   datetime GetFxtTime();                       // immer aktuelle FXT-Zeit

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
   bool     GetTimezoneTransitions(datetime serverTime, int prevTransition[], int nextTransition[]);  // throws ERR_INVALID_TIMEZONE_CONFIG

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


   // Event-Listener: Diese Library-Versionen können durch spezielle lokale Versionen überschrieben werden.
   bool     EventListener.BarOpen        (int    data[], int param);
   bool     EventListener.AccountChange  (int    data[], int param);
   bool     EventListener.ChartCommand   (string data[], int param);
   bool     EventListener.InternalCommand(string data[], int param);
   bool     EventListener.ExternalCommand(string data[], int param);


   // Event-Handler: Diese Library-Versionen sind leere Stubs, bei Verwendung *müssen* die Handler im Programm implementiert werden.
   bool     onNewTick        (int    data[]);
   bool     onBarOpen        (int    data[]);
   bool     onAccountChange  (int    data[]);
   bool     onChartCommand   (string data[]);
   bool     onInternalCommand(string data[]);
   bool     onExternalCommand(string data[]);


   // Farben
   color    RGB(int red, int green, int blue);

   int      RGBToHSV(color rgb, double hsv[]);
   int      RGBValuesToHSV(int red, int green, int blue, double hsv[]);

   color    HSVToRGB(double hsv[]);
   color    HSVValuesToRGB(double hue, double saturation, double value);

   color    Color.ModifyHSV(color rgb, double hue, double saturation, double value);

   string   ColorToStr(color rgb);
   string   ColorToRGBStr(color rgb);
   string   ColorToHtmlStr(color rgb);


   // Files, I/O
   bool     IsFile(string filename);
   bool     IsDirectory(string filename);
   int      FindFileNames(string pattern, string results[], int flags);
   int      FileReadLines(string filename, string lines[], bool skipEmptyLines);

   bool     EditFile (string filename   );
   bool     EditFiles(string filenames[]);


   // Locks
   bool     AquireLock(string mutexName, bool wait);
   bool     ReleaseLock(string mutexName);
   bool     ReleaseLocks(bool warn);


   // Strings
   bool     StringIsDigit(string value);
   bool     StringIsInteger(string value);
   bool     StringIsNumeric(string value);
   bool     StringIsPhoneNumber(string value);

   bool     StringContains(string object, string substring);
   bool     StringIContains(string object, string substring);

   bool     StringICompare(string a, string b);

   string   StringPad(string input, int length, string pad_string, int pad_type);

   int      StringFindR(string object, string search);
   string   StringRepeat(string input, int times);
   string   StringReplace.Recursive(string object, string search, string replace);

   int      Explode(string input, string separator, string results[], int limit);


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
#import "stdlib2.ex4"
   bool     SortClosedTickets(int keys[][]);
   bool     SortOpenTickets(int keys[][]);

#import "stdlib1.ex4"
   string   GetCurrency(int id);
   int      GetCurrencyId(string currency);
   bool     IsCurrency(string value);

   string   StdSymbol();                                                            // Alias für GetStandardSymbol(Symbol())
   string   GetStandardSymbol(string symbol);                                       // Alias für GetStandardSymbolOrAlt(symbol, symbol)
   string   GetStandardSymbolOrAlt(string symbol, string altValue);
   string   GetStandardSymbolStrict(string symbol);

   string   GetSymbolName(string symbol);                                           // Alias für GetSymbolNameOrAlt(symbol, symbol)
   string   GetSymbolNameOrAlt(string symbol, string altName);
   string   GetSymbolNameStrict(string symbol);

   string   GetLongSymbolName(string symbol);                                       // Alias für GetLongSymbolNameOrAlt(symbol, symbol)
   string   GetLongSymbolNameOrAlt(string symbol, string altValue);
   string   GetLongSymbolNameStrict(string symbol);

   int      IncreasePeriod(int period);
   int      DecreasePeriod(int period);

   int      StrToPeriod(string value);  int StrToTimeframe(string value);           // Alias
   int      PeriodFlag(int period);
   int      StrToOperationType(string value);
   int      StrToPriceType(string value);

   string   CreateLegendLabel(string name);
   int      RepositionLegend();
   bool     ObjectDeleteSilent(string label, string location);
   int      ObjectRegister(string label);  int RegisterChartObject(string label);   // Alias
   int      DeleteRegisteredObjects(string prefix);

   int      iAccountBalance(int account, double buffer[], int bar);
   int      iAccountBalanceSeries(int account, double buffer[]);

   bool     SendSMS(string receiver, string message);


   // toString-Funktionen
   string   DoubleToStrEx(double value, int digits/*=0..16*/);

   string   IntegerToBinaryStr(int integer);

   string   IntegerToHexStr(int decimal);
   string   ByteToHexStr(int byte);
   string   WordToHexStr(int word);

#import "stdlib2.ex4"
   string   BoolsToStr        (bool array[], string separator);
   string   IntsToStr          (int array[], string separator);
   string   CharsToStr         (int array[], string separator);
   string   TicketsToStr       (int array[], string separator);
   string   OperationTypesToStr(int array[], string separator);
   string   TimesToStr    (datetime array[], string separator);
   string   DoublesToStr    (double array[], string separator);
   string   DoublesToStrEx  (double array[], string separator, int digits/*=0..16*/);
   string   iBufferToStr    (double array[], string separator);
   string   MoneysToStr     (double array[], string separator);
   string   RatesToStr      (double array[], string separator); string PricesToStr(double array[], string separator);   // Alias
   string   StringsToStr    (string array[], string separator);

#import "stdlib1.ex4"
   string   InitFlagsToStr(int flags);
   string   DateToStr(datetime time, string format);  string DateTimeToStr(datetime time, string format);               // Alias
   string   DeinitFlagsToStr(int flags);
   string   EventToStr(int event);
   string   FileAccessModeToStr(int mode);
   string   MessageBoxCmdToStr(int cmd);
   string   ModuleTypeDescription(int type);
   string   MaMethodDescription(int method);          string MovingAverageMethodDescription(int method);                // Alias
   string   MaMethodToStr      (int method);          string MovingAverageMethodToStr      (int method);                // Alias
   string   NumberToStr(double number, string format);
   string   OperationTypeDescription(int type);       string OrderTypeDescription(int type);                            // Alias
   string   OperationTypeToStr      (int type);       string OrderTypeToStr      (int type);                            // Alias
   string   PeriodFlagToStr(int flag);
   string   PriceTypeDescription(int type);
   string   PriceTypeToStr      (int type);
   string   ShellExecuteErrorDescription(int error);
   string   SwapCalculationModeToStr(int mode);
   string   TestFlagsToStr(int flags);
   string   UninitializeReasonDescription(int reason);
   string   InitReasonDescription(int reason);
   string   InitReasonToStr      (int reason);
   string   WaitForSingleObjectValueToStr(int value);


   // Win32-Funktionen (an MQL angepaßt)
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
   int      ShowStatus(int error);
   void     DummyCalls();


   // erweiterte MQL-Root-Funktionen
   int      stdlib.init  (/*EXECUTION_CONTEXT*/int ec[], int tickData[]);
   int      stdlib.start (/*EXECUTION_CONTEXT*/int ec[], int tick, datetime tickTime, int validBars, int changedBars);
   int      stdlib.deinit(/*EXECUTION_CONTEXT*/int ec[]);
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
