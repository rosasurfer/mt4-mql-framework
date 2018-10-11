/**
 * Importdeklarationen
 *
 * Note: Je MQL-Modul können bis zu 512 Arrays deklariert werden. Um ein Überschreiten dieses Limits zu vermeiden, müssen die
 *       auskommentierten Funktionen (die mit Array-Parametern) manuell importiert werden.
 */
#import "rsfExpander.dll"

   // Application-Status/Interaktion und Laufzeit-Informationen
   int      GetApplicationWindow();
   string   GetTerminalVersion();
   int      GetTerminalBuild();
   string   GetTerminalCommonDataPathA();
   string   GetTerminalDataPathA();
   string   GetTerminalModuleFileNameA();
   string   GetTerminalRoamingDataPathA();
   int      GetUIThreadId();
   string   InputParamsDiff(string initial, string current);
   bool     IsUIThread();
   int      MT4InternalMsg();
 //int      SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int period, int lpSec, int isTesting, int isVisualMode, int isOptimization, int hChart, int droppedOnChart, int droppedOnPosX, int droppedOnPosY);
 //int      SyncMainContext_start (int ec[], datetime time, double bid, double ask, int volume);
 //int      SyncMainContext_deinit(int ec[], int uninitReason);
 //int      SyncLibContext_init   (int ec[], int uninitReason, int initFlags, int deinitFlags, string libraryName, string symbol, int period, int isOptimization);
 //int      SyncLibContext_deinit (int ec[], int uninitReason);
   bool     TerminalIsPortableMode();

   // Chart-Status/Interaktion
   int      SetupTickTimer(int hWnd, int millis, int flags);
   bool     RemoveTickTimer(int timerId);

   // configuration
   string   GetGlobalConfigPathA();
   string   GetLocalConfigPathA();

   // date/time
   datetime GetGmtTime();
   datetime GetLocalTime();

   // file functions
   int      CreateDirectoryRecursive(string path);
   string   GetFinalPathNameA(string name);
   string   GetReparsePointTargetA(string name);
   bool     IsDirectoryA(string name);
   bool     IsFileA(string name);
   bool     IsJunctionA(string name);
   bool     IsSymlinkA(string name);

   // Pointer-Handling (Speicheradressen von Arrays und Strings)
   int      GetBoolsAddress  (bool   values[]);
   int      GetIntsAddress   (int    values[]);
   int      GetDoublesAddress(double values[]);
   int      GetStringAddress (string value   );       // Achtung: GetStringAddress() darf nur mit Array-Elementen verwendet werden. Ein einfacher einzelner String
   int      GetStringsAddress(string values[]);       //          wird an DLLs als Kopie übergeben und diese Kopie nach Rückkehr sofort freigegeben. Die erhaltene
   string   GetString(int address);                   //          Adresse ist ungültig und kann einen Crash auslösen.

   // string functions
   //int    AnsiToWCharStr(string source, int dest[], int destSize);
   //string MD5Hash(int buffer[], int size);
   string   MD5HashA(string str);
   bool     StringCompare(string s1, string s2);
   bool     StrEndsWith(string str, string suffix);
   bool     StringIsNull(string str);
   bool     StringStartsWith(string str, string prefix);
   string   StringToStr(string str);

   // conversion functions
   string   BoolToStr(int value);
   string   DeinitFlagsToStr(int flags);
   string   DoubleQuoteStr(string value);
   string   ErrorToStr(int error);
   string   InitFlagsToStr(int flags);
   string   InitializeReasonToStr(int reason);        // Alias for InitReasonToStr()
   string   InitReasonToStr(int reason);
   string   IntToHexStr(int value);
   string   ModuleTypeDescription(int type);
   string   ModuleTypeToStr(int type);
   string   OperationTypeDescription(int type);
   string   OperationTypeToStr(int type);
   string   OrderTypeDescription(int type);           // Alias
   string   OrderTypeToStr(int type);                 // Alias
   string   PeriodDescription(int period);
   string   PeriodToStr(int period);
   string   ProgramTypeDescription(int type);
   string   ProgramTypeToStr(int type);
   string   RootFunctionDescription(int func);
   string   RootFunctionToStr(int func);
   string   ShowWindowCmdToStr(int cmdShow);
   string   TimeframeDescription(int timeframe);      // Alias for PeriodDescription()
   string   TimeframeToStr(int timeframe);            // Alias for PeriodToStr();
   string   TradeDirectionDescription(int direction);
   string   TradeDirectionToStr(int direction);
   string   UninitializeReasonToStr(int reason);      // Alias for UninitReasonToStr()
   string   UninitReasonToStr(int reason);

   // sonstiges
   bool     IsCustomTimeframe(int timeframe);
   bool     IsStdTimeframe(int timeframe);

   // Win32 Helper
   int      GetLastWin32Error();
   int      GetWindowProperty(int hWnd, string name);
   bool     SetWindowProperty(int hWnd, string name, int value);
   int      RemoveWindowProperty(int hWnd, string name);

   // Stubs, können im Modul durch konkrete Versionen überschrieben werden.
   int      onInit();
   int      onInit_User();
   int      onInit_Template();
   int      onInit_Program();
   int      onInit_ProgramAfterTest();
   int      onInit_Parameters();
   int      onInit_TimeframeChange();
   int      onInit_SymbolChange();
   int      onInit_Recompile();
   int      afterInit();

   int      onStart();                                // Scripte
   int      onTick();                                 // EA's + Indikatoren

   int      onDeinit();
   int      afterDeinit();
#import
