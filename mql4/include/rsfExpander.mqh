/**
 * Importdeklarationen
 *
 * Note: Je MQL-Modul können bis zu 512 Arrays deklariert werden. Um ein Überschreiten dieses Limits zu vermeiden, müssen die
 *       auskommentierten Funktionen (die mit Array-Parametern) manuell importiert werden.
 */
#import "rsfExpander.dll"

   // terminal status/interaction
   int      FindInputDialog(int programType, string programName);
   string   GetMqlDirectoryA();
   int      GetTerminalBuild();
   int      GetTerminalMainWindow();
   string   GetTerminalVersion();
   string   GetTerminalCommonDataPathA();
   string   GetTerminalDataPathA();
   string   GetTerminalModuleFileNameA();
   string   GetTerminalRoamingDataPathA();
   int      GetUIThreadId();
   string   InputParamsDiff(string initial, string current);
   bool     IsUIThread(int threadId);
   bool     LoadMqlProgramA(int hChart, int programType, string programName);
   bool     LoadMqlProgramW(int hChart, int programType, string programName);
   int      MT4InternalMsg();
   //int    SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int timeframe, int digits, double point, int extReporting, int recordEquity, int isTesting, int isVisualMode, int isOptimization, int lpSec, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);
   //int    SyncMainContext_start (int ec[], double rates[][], int bars, int changedBars, int ticks, datetime time, double bid, double ask);
   //int    SyncMainContext_deinit(int ec[], int uninitReason);
   //int    SyncLibContext_init   (int ec[], int uninitReason, int initFlags, int deinitFlags, string libraryName, string symbol, int timeframe, int digits, double point, int isTesting, int isOptimization);
   //int    SyncLibContext_deinit (int ec[], int uninitReason);
   bool     TerminalIsPortableMode();
   int      WM_MT4();

   // strategy tester
   int      FindTesterWindow();
   int      Tester_GetBarModel();
   datetime Tester_GetStartDate();
   datetime Tester_GetEndDate();
   double   Test_GetCommission(int ec[], double lots);
   //bool   Test_StartReporting(int ec[], datetime from, int bars, int reportId, string reportSymbol);
   //bool   Test_StopReporting (int ec[], datetime to,   int bars);
   //bool   Test_onPositionOpen (int ec[], int ticket, int type, double lots, string symbol, double openPrice, datetime openTime, double stopLoss, double takeProfit, double commission, int magicNumber, string comment);
   //bool   Test_onPositionClose(int ec[], int ticket, double closePrice, datetime closeTime, double swap, double profit);

   // chart status/interaction
   int      SetupTickTimer(int hWnd, int millis, int flags);
   bool     RemoveTickTimer(int timerId);

   // configuration
   bool     DeleteIniKeyA(string fileName, string section, string key);
   bool     DeleteIniSectionA(string fileName, string section);
   bool     EmptyIniSectionA(string fileName, string section);
   string   GetGlobalConfigPathA();
   //int    GetIniKeysA(string fileName, string section, int buffer[], int bufferSize);
   //int    GetIniSectionsA(string fileName, int buffer[], int bufferSize);
   string   GetIniStringA(string fileName, string section, string key, string defaultValue);
   string   GetIniStringRawA(string fileName, string section, string key, string defaultValue);
   string   GetLocalConfigPathA();
   bool     IsGlobalConfigKeyA(string section, string key);
   bool     IsIniKeyA(string fileName, string section, string key);
   bool     IsIniSectionA(string fileName, string section);
   bool     IsLocalConfigKeyA(string section, string key);

   // date/time
   datetime GetGmtTime();
   datetime GetLocalTime();
   string   GmtTimeFormat(datetime timestamp, string format);
   string   LocalTimeFormat(datetime timestamp, string format);

   // file functions
   int      CreateDirectoryRecursiveA(string path);
   string   GetFinalPathNameA(string name);
   string   GetReparsePointTargetA(string name);
   bool     IsDirectoryA(string name);
   bool     IsFileA(string name);
   bool     IsJunctionA(string name);
   bool     IsSymlinkA(string name);

   // logging
   bool     LogMessageA(int ec[], string message, int error);

   // pointer utlities
   int      GetBoolsAddress  (bool   values[]);
   int      GetIntsAddress   (int    values[]);
   int      GetDoublesAddress(double values[]);       // Achtung: GetStringAddress() darf nur mit Array-Elementen verwendet werden. Ein einfacher einzelner String
   int      GetStringAddress (string value   );       //          wird an DLLs als Kopie übergeben und diese Kopie nach Rückkehr sofort freigegeben. Die erhaltene
   int      GetStringsAddress(string values[]);       //          Adresse ist ungültig und kann einen Crash auslösen.

   string   GetStringA(int address);
   //string GetStringW(int address);
   bool     MemCompare(int lpBufferA, int lpBufferB, int size);

   // string functions
   //int    AnsiToWCharStr(string source, int dest[], int destSize);
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
   string   ErrorToStr(int error);
   string   InitFlagsToStr(int flags);
   string   InitializeReasonToStr(int reason);        // alias of InitReasonToStr()
   string   InitReasonToStr(int reason);
   string   IntToHexStr(int value);
   string   ModuleTypeDescription(int type);
   string   ModuleTypeToStr(int type);
   string   NumberFormat(double value, string format);
   string   OperationTypeDescription(int type);
   string   OperationTypeToStr(int type);
   string   OrderTypeDescription(int type);           // alias
   string   OrderTypeToStr(int type);                 // alias
   string   PeriodDescription(int period);
   string   PeriodToStr(int period);
   string   ProgramTypeDescription(int type);
   string   ProgramTypeToStr(int type);
   string   ShowWindowCmdToStr(int cmdShow);
   string   TimeframeDescription(int timeframe);      // alias of PeriodDescription()
   string   TimeframeToStr(int timeframe);            // alias of PeriodToStr();
   string   TradeDirectionDescription(int direction);
   string   TradeDirectionToStr(int direction);
   string   UninitializeReasonToStr(int reason);      // alias of UninitReasonToStr()
   string   UninitReasonToStr(int reason);

   // other
   bool     IsCustomTimeframe(int timeframe);
   bool     IsStdTimeframe(int timeframe);

   // Win32 helpers
   int      GetLastWin32Error();
   int      GetWindowProperty(int hWnd, string name);
   bool     SetWindowProperty(int hWnd, string name, int value);
   int      RemoveWindowProperty(int hWnd, string name);

   // Empty stubs of optional functions. May be overwritten by custom MQL implementations.
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

   int      onStart();
   int      onTick();

   int      onDeinit();
   int      onDeinitAccountChange();
   int      onDeinitChartChange();
   int      onDeinitChartClose();
   int      onDeinitParameters();
   int      onDeinitRecompile();
   int      onDeinitRemove();
   int      onDeinitUndefined();
   int      onDeinitClose();              // builds > 509
   int      onDeinitFailed();             // ...
   int      onDeinitTemplate();           // ...
   int      afterDeinit();

   void     DummyCalls();
   bool     EventListener_ChartCommand(string data[]);
   string   InputsToStr();
   int      ShowStatus(int error);
#import
