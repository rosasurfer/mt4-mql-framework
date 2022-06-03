/**
 * MT4Expander import declarations
 *
 * Note: MQL4 supports up to 512 arrays per MQL module (in MQL5 this limit was removed). In this file all functions with array
 *       parameters are commented out to prevent hitting that limit. Import needed functions manually to use them.
 */
#import "rsfMT4Expander.dll"

   // terminal status, terminal interaction
   string   GetExpanderFileNameA();
   string   GetHistoryRootPathA();
   string   GetMqlDirectoryA();
   int      GetTerminalBuild();
   int      GetTerminalMainWindow();
   string   GetTerminalVersion();
   string   GetTerminalCommonDataPathA();
   string   GetTerminalDataPathA();
   string   GetTerminalFileNameA();
   string   GetTerminalRoamingDataPathA();
   int      GetUIThreadId();
   bool     IsUIThread(int threadId);
   bool     LoadMqlProgramA(int hChart, int programType, string programName);
   bool     LoadMqlProgramW(int hChart, int programType, string programName);
   int      MT4InternalMsg();
   bool     ReopenAlertDialog(int sound);
   //int    SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int timeframe, int digits, double point, int recordMode, int isTesting, int isVisualMode, int isOptimization, int isExternalReporting, int lpSec, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);
   //int    SyncMainContext_start (int ec[], double rates[][], int bars, int changedBars, int ticks, datetime tickTime, double bid, double ask);
   //int    SyncMainContext_deinit(int ec[], int uninitReason);
   //int    SyncLibContext_init   (int ec[], int uninitReason, int initFlags, int deinitFlags, string libraryName, string symbol, int timeframe, int digits, double point, int isTesting, int isOptimization);
   //int    SyncLibContext_deinit (int ec[], int uninitReason);
   //int    LeaveContext(int ec[]);
   bool     TerminalIsPortableMode();
   int      WM_MT4();

   // strategy tester
   int      FindTesterWindow();
   int      Tester_GetBarModel();
   datetime Tester_GetStartDate();
   datetime Tester_GetEndDate();
   double   Test_GetCommission(int ec[], double lots);
   //bool   Test_InitReporting  (int ec[], datetime from, int bars);
   //bool   Test_onPositionOpen (int ec[], int ticket, int type, double lots, string symbol, datetime openTime, double openPrice, double stopLoss, double takeProfit, double commission, int magicNumber, string comment);
   //bool   Test_onPositionClose(int ec[], int ticket, datetime closeTime, double closePrice, double swap, double profit);
   //bool   Test_StopReporting  (int ec[], datetime to,   int bars);

   // charts and timeframes
   bool     IsCustomTimeframe(int timeframe);
   bool     IsStdTimeframe(int timeframe);
   int      SetupTickTimer(int hWnd, int millis, int flags);
   bool     RemoveTickTimer(int timerId);

   // configuration
   string   GetGlobalConfigPathA();
   string   GetTerminalConfigPathA();

   bool     DeleteIniKeyA(string fileName, string section, string key);
   bool     DeleteIniSectionA(string fileName, string section);
   bool     EmptyIniSectionA(string fileName, string section);
   //int    GetIniKeysA(string fileName, string section, int buffer[], int bufferSize);
   //int    GetIniSectionsA(string fileName, int buffer[], int bufferSize);
   string   GetIniStringA(string fileName, string section, string key, string defaultValue);
   string   GetIniStringRawA(string fileName, string section, string key, string defaultValue);
   bool     IsGlobalConfigKeyA(string section, string key);
   bool     IsIniKeyA(string fileName, string section, string key);
   bool     IsIniSectionA(string fileName, string section);
   bool     IsTerminalConfigKeyA(string section, string key);

   // date/time
   datetime GetGmtTime();
   datetime GetLocalTime();
   string   GmtTimeFormatA(datetime timestamp, string format);
   string   LocalTimeFormatA(datetime timestamp, string format);

   // file functions
   int      CreateDirectoryA(string path, int flags);
   string   GetFinalPathNameA(string name);
   string   GetReparsePointTargetA(string name);
   bool     IsDirectoryA(string path, int mode);
   bool     IsFileA(string path, int mode);
   bool     IsFileOrDirectoryA(string path);
   bool     IsJunctionA(string path);
   bool     IsSymlinkA(string path);

   // math
   int      DoubleExp(double value);
   double   MathLog10(double value);

   // pointer and memory helpers
   int      GetBoolsAddress  (bool   values[]);
   int      GetIntsAddress   (int    values[]);
   int      GetDoublesAddress(double values[]);
   int      GetStringAddress (string value   );          // Warning: GetStringAddress() must be used with string array elements only.
   int      GetStringsAddress(string values[]);          //          Simple strings are passed to DLLs as copies. The resulting address
   string   GetStringA(int address);                     //          is a dangling pointer and accessing it may cause a terminal crash.
   //string GetStringW(int address);
   bool     MemCompare(int lpBufferA, int lpBufferB, int size);

   // array functions
   //bool   InitializeBOOLArray  (bool   &values[], int size, int    initValue, int from, int count);
   //bool   InitializeBoolArray  (bool   &values[], int size, bool   initValue, int from, int count);
   //bool   InitializeCharArray  (char   &values[], int size, char   initValue, int from, int count);
   //bool   InitializeShortArray (short  &values[], int size, short  initValue, int from, int count);
   //bool   InitializeIntArray   (int    &values[], int size, int    initValue, int from, int count);
   //bool   InitializeLongArray  (long   &values[], int size, long   initValue, int from, int count);
   //bool   InitializeFloatArray (float  &values[], int size, float  initValue, int from, int count);
   //bool   InitializeDoubleArray(double &values[], int size, double initValue, int from, int count);

   //bool   ShiftBOOLIndicatorBuffer  (bool   &buffer[], int size, int count, int    emptyValue);
   //bool   ShiftBoolIndicatorBuffer  (bool   &buffer[], int size, int count, bool   emptyValue);
   //bool   ShiftCharIndicatorBuffer  (char   &buffer[], int size, int count, char   emptyValue);
   //bool   ShiftShortIndicatorBuffer (short  &buffer[], int size, int count, short  emptyValue);
   //bool   ShiftIntIndicatorBuffer   (int    &buffer[], int size, int count, int    emptyValue);
   //bool   ShiftLongIndicatorBuffer  (long   &buffer[], int size, int count, long   emptyValue);
   //bool   ShiftFloatIndicatorBuffer (float  &buffer[], int size, int count, float  emptyValue);
   //bool   ShiftDoubleIndicatorBuffer(double &buffer[], int size, int count, double emptyValue);

   // string functions
   //string MD5Hash(int buffer[], int size);
   string   MD5HashA(string str);
   //bool   SortMqlStringsA(string values[], int size);
   //bool   SortMqlStringsW(string values[], int size);
   bool     StrCompare(string s1, string s2);
   bool     StrEndsWith(string str, string suffix);
   bool     StrIsNull(string str);
   bool     StrStartsWith(string str, string prefix);
   string   StringToStr(string str);

   // conversion functions
   string   BarModelDescription(int id);
   string   BarModelToStr(int id);
   string   BoolToStr(int value);
   string   CoreFunctionDescription(int func);
   string   CoreFunctionToStr(int func);
   string   DeinitFlagsToStr(int flags);
   string   DoubleQuoteStr(string value);
   string   ErrorToStrA(int error);
   string   InitFlagsToStr(int flags);
   string   InitializeReasonToStr(int reason);           // alias of InitReasonToStr()
   string   InitReasonToStr(int reason);
   string   IntToHexStr(int value);
   string   LoglevelToStr(int level);
   string   ModuleTypeDescription(int type);
   string   ModuleTypeToStr(int type);
   string   NumberFormat(double value, string format);
   string   OperationTypeDescription(int type);
   string   OperationTypeToStr(int type);
   string   OrderTypeDescription(int type);              // alias
   string   OrderTypeToStr(int type);                    // alias
   string   PeriodToStr(int period);
   string   ProgramTypeDescription(int type);
   string   ProgramTypeToStr(int type);
   string   ShowWindowCmdToStr(int cmdShow);
   string   TimeframeToStr(int timeframe);               // alias of PeriodToStr()
   string   TradeDirectionDescription(int direction);
   string   TradeDirectionToStr(int direction);
   string   UninitializeReasonToStr(int reason);         // alias of UninitReasonToStr()
   string   UninitReasonToStr(int reason);

   // window property management
   bool     SetWindowIntegerA   (int hWnd, string name, int value);
   int      GetWindowIntegerA   (int hWnd, string name);
   int      RemoveWindowIntegerA(int hWnd, string name);

   bool     SetWindowDoubleA   (int hWnd, string name, double value);
   double   GetWindowDoubleA   (int hWnd, string name);
   double   RemoveWindowDoubleA(int hWnd, string name);

   bool     SetWindowStringA   (int hWnd, string name, string value);
   string   GetWindowStringA   (int hWnd, string name);
   string   RemoveWindowStringA(int hWnd, string name);

   // other helpers
   string   GetInternalWindowTextA(int hWnd);
   int      GetLastWin32Error();
   bool     IsAsyncKeyDown(int vKey);
   bool     IsProgramType(int type);

   // Empty stubs for optional MQL event handlers. Overwritten by custom MQL implementations.
   int      onInit();
   int      onInitUser();
   int      onInitParameters();
   int      onInitTimeframeChange();
   int      onInitSymbolChange();
   int      onInitProgram();
   int      onInitProgramAfterTest();
   int      onInitTemplate();
   int      onInitRecompile();
   int      afterInit();

   int      onStart();                                         // scripts
   int      onTick();                                          // indicators and experts
   int      onAccountChange(int oldAccount, int newAccount);   // indicators

   int      onDeinit();
   int      onDeinitAccountChange();                           // experts
   int      onDeinitChartChange();
   int      onDeinitChartClose();
   int      onDeinitParameters();
   int      onDeinitRecompile();
   int      onDeinitRemove();
   int      onDeinitUndefined();
   int      onDeinitClose();                                   // terminal builds > 509
   int      onDeinitFailed();                                  // ...
   int      onDeinitTemplate();                                // ...
   int      afterDeinit();

   // Error handlers for missing MQL implementations (if such functionality is used).
   bool     onBarOpen();

   // no-ops
   void     DummyCalls();
   string   InputsToStr();
   bool     Recorder_GetSymbolDefinitionA(int i, bool &enabled, string &symbol, string &symbolDescr, string &symbolGroup, int &symbolDigits, double &hstBase, int &hstMultiplier, string &hstDirectory, int &hstFormat);
   int      ShowStatus(int error);
#import
