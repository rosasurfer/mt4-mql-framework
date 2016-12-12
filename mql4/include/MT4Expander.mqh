/**
 * Importdeklarationen für Expanderfunktionen
 *
 * Note: Je MQL-Modul können bis zu 512 Arrays deklariert werden. Um ein Überschreiten dieses Limits zu vermeiden,
 *       müssen die auskommentierten Funktionen (mit Array-Parametern) manuell importiert werden.
 */
#import "Expander.dll"

   // Application-Status/Interaktion und Laufzeit-Informationen
   int      GetApplicationWindow();
   string   GetTerminalVersion();
   int      GetTerminalBuild();
 //bool     GetTerminalVersionNumbers(int major[], int minor[], int hotfix[], int build[]);
   int      GetUIThreadId();
   bool     IsUIThread();
   int      MT4InternalMsg();
 //bool     SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int period, int lpSec, int isTesting, int isVisualMode, int isOptimization, int hChart, int subChartDropped);
 //bool     SyncMainContext_start (int ec[]);
 //bool     SyncMainContext_deinit(int ec[], int uninitReason);
 //bool     SyncLibContext_init   (int ec[], int uninitReason, string libraryName, string symbol, int period);
 //bool     SyncLibContext_deinit (int ec[], int uninitReason);

   // Chart-Status/Interaktion
   int      SetupTickTimer(int hWnd, int millis, int flags);
   bool     RemoveTickTimer(int timerId);

   // Date/Time
   datetime GetGmtTime();
   datetime GetLocalTime();

   // Pointer-Handling (Speicheradressen von Arrays und Strings)
   int      GetBoolsAddress  (bool   values[]);
   int      GetIntsAddress   (int    values[]);
   int      GetDoublesAddress(double values[]);
   int      GetStringAddress (string value   );       // Achtung: GetStringAddress() darf nur mit Array-Elementen verwendet werden. Ist der Parameter ein einfacher String,
   int      GetStringsAddress(string values[]);       //          wird an die DLL eine Kopie dieses Strings übergeben. Diese Kopie wird u.U. sofort nach Rückkehr freigegeben
   string   GetString(int address);                   //          und die erhaltene Adresse ist ungültig (z.B. im Tester bei mehrfachen Tests).

   // Strings
   bool     StringCompare(string s1, string s2);
   bool     StringIsNull(string value);
   string   StringToStr(string value);

   // toString-Funktionen
   string   BoolToStr(int value);
   string   DeinitFlagsToStr(int flags);
   string   DoubleQuoteStr(string value);
   string   ErrorToStr(int error);
   string   InitFlagsToStr(int flags);
   string   InitReasonToStr      (int reason);
   string   InitializeReasonToStr(int reason);        // Alias
   string   IntToHexStr(int value);
   string   ModuleTypeDescription(int type);
   string   ModuleTypeToStr(int type);
   string   PeriodDescription(int period);    string TimeframeDescription(int timeframe);    // Alias
   string   PeriodToStr(int period);          string TimeframeToStr(int timeframe);          // Alias
   string   ProgramTypeDescription(int type);
   string   ProgramTypeToStr(int type);
   string   RootFunctionDescription(int id);
   string   RootFunctionToStr(int id);
   string   ShowWindowCmdToStr(int cmdShow);
   string   UninitReasonToStr      (int reason);
   string   UninitializeReasonToStr(int reason);      // Alias

   // sonstiges
   bool     IsCustomTimeframe(int timeframe);
   bool     IsStdTimeframe(int timeframe);

   // Win32 Helper
   int      GetLastWin32Error();
   int      GetWindowProperty(int hWnd, string name);
   bool     SetWindowProperty(int hWnd, string name, int value);
   int      RemoveWindowProperty(int hWnd, string name);

   // Stubs, können im Modul durch konkrete Versionen "überschrieben" werden.
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

   int      onStart();                                      // Scripte
   int      onTick();                                       // EA's + Indikatoren

   int      onDeinit();
   int      afterDeinit();
#import
