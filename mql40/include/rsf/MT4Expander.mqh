/**
 * MT4Expander import declarations
 *
 * Note: MQL4.0 supports up to 512 arrays per MQL module (in MQL4.5/MQL5 this limit was removed). To prevent hitting that
 *       limit all imports with array parameters are disabled in this file. Import needed functions per program to use them.
 */
#import "rsfMT4Expander.dll"

   // terminal status and interaction
   string   FindHistoryDirectoryA(string filename, int removeFile);
   string   GetExpanderFileNameA();
   string   GetHistoryRootPathA();
   string   GetMqlDirectoryA();
   string   GetMqlSandboxPathA(int inTester);
   int      GetTerminalBuild();
   int      GetTerminalMainWindow();
   string   GetTerminalVersion();
   string   GetTerminalCommonDataPathA();
   string   GetTerminalDataPathA();
   string   GetTerminalFileNameA();
   string   GetTerminalRoamingDataPathA();
   int      GetUIThreadId();
   bool     IsPortableMode();
   bool     IsUIThread(int threadId);
   bool     LoadMqlProgramA(int hChart, int programType, string programName);
   int      MT4InternalMsg();
   bool     ReopenAlertDialog(int sound);
   //int    SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int timeframe, int digits, double point, int isTesting, int isVisualMode, int isOptimization, int recorder, int lpSec, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY, string accountServer, int accountNumber);
   //int    SyncMainContext_start (int ec[], double rates[][], int bars, int changedBars, int ticks, datetime tickTime, int isVirtual, double bid, double ask);
   //int    SyncMainContext_deinit(int ec[], int uninitReason);
   //int    SyncLibContext_init   (int ec[], int uninitReason, int initFlags, int deinitFlags, string libraryName, string symbol, int timeframe, int digits, double point, int isTesting, int isOptimization);
   //int    SyncLibContext_deinit (int ec[], int uninitReason);
   //int    LeaveContext(int ec[]);
   int      WM_MT4();

   // strategy tester
   int      FindTesterWindow();
   int      Tester_GetBarModel();
   datetime Tester_GetStartDate();
   datetime Tester_GetEndDate();
   double   Test_GetCommission(int ec[]);

   // charts and timeframes
   bool     IsCustomTimeframe(int timeframe);
   bool     IsStandardTimeframe(int timeframe);
   int      SetupTickTimer(int hWnd, int millis, int flags);
   bool     ReleaseTickTimer(int timerId);

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
   datetime GetGmtTime32();
   datetime GetLocalTime32();
   string   GmtTimeFormatA(datetime time, string format);
   string   LocalTimeFormatA(datetime time, string format);
 //datetime GmtToLocalTime(datetime time);                     // TODO: finish tests (see ZigZag EA)
 //datetime LocalToGmtTime(datetime time);                     // TODO: finish tests (see ZigZag EA)

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
   bool     IsInfinite(double value);
   bool     IsNaN(double value);
   double   Math_INF();
   double   Math_NaN();
   double   MathLog10(double value);

   // pointer and memory helpers
   int      GetBoolsAddress  (bool   values[]);
   int      GetIntsAddress   (int    values[]);
   int      GetDoublesAddress(double values[]);
   int      GetStringAddress (string value   );                // Warning: GetStringAddress() must be used with string array elements only.
   int      GetStringsAddress(string values[]);                //  Simple strings are passed to DLLs as copies and immediately destroyed
   string   GetStringA(int address);                           //  after the call. Accessing such an address may cause a terminal crash.
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
   bool     StrCompare(string s1, string s2);
   bool     StrEndsWith(string str, string suffix);
   bool     StrEndsWithI(string str, string suffix);
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
   string   ErrorToStrA(int error);
   string   InitFlagsToStr(int flags);
   string   InitReasonToStr(int reason);
   string   IntToHexStr(int value);
   string   LoglevelToStrA(int level);
   string   MessageBoxButtonToStrA(int id);
   string   ModuleTypeDescription(int type);
   string   ModuleTypeToStr(int type);
   string   NumberFormat(double value, string format);
   string   OperationTypeDescription(int type);
   string   OperationTypeToStr(int type);
   string   OrderTypeDescription(int type);                    // alias
   string   OrderTypeToStr(int type);                          // alias
   string   PeriodToStr(int period);
   string   ProgramTypeDescription(int type);
   string   ProgramTypeToStr(int type);
   string   ShowWindowCmdToStr(int cmdShow);
   string   TimeframeToStr(int timeframe);                     // alias of PeriodToStr()
   string   TradeDirectionDescription(int direction);
   string   TradeDirectionToStr(int direction);
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

   // other
   string   GetInternalWindowTextA(int hWnd);
   int      GetLastWin32Error();
   bool     IsProgramType(int type);
   bool     IsVirtualKeyDown(int vKey);
   bool     IsWindowAreaVisible(int hWnd);
   int      PlaySoundA(string soundfile);

   // Virtual no-ops. Automatically overwritten by MQL implementations of the same name.
   int      onInit();
   int      onInitUser();
   int      onInitParameters();
   int      onInitSymbolChange();
   int      onInitTimeframeChange();
   int      onInitAccountChange();
   int      onInitProgram();
   int      onInitProgramAfterTest();
   int      onInitTemplate();
   int      onInitRecompile();
   int      afterInit();

   int      onStart();                                         // scripts
   int      onTick();                                          // indicators and experts

   int      onDeinit();
   int      onDeinitAccountChange();
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

   int      DeleteRegisteredObjects();                         // other virtual no-ops
   void     DummyCalls();
   string   InputsToStr();
   bool     RemoveChartLegend();
   int      ShowStatus(int error);
#import
