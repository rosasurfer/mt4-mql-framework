/**
 * Xtrade struct EXECUTION_CONTEXT
 *
 * Ausführungskontext von MQL-Programmen zur Kommunikation zwischen MQL und DLL
 *
 * @see  MT4Expander::header/mql/structs/mt4/ExecutionContext.h
 *
 * Im Indikator gibt es während eines init()-Cycles in der Zeitspanne vom Verlassen von Indicator::deinit() bis zum Wiedereintritt in Indicator::init()
 * keinen gültigen Hauptmodulkontext. Der alte Speicherblock wird sofort freigegeben, später wird ein neuer alloziiert. Während dieser Zeitspanne wird
 * der init()-Cycle von bereits geladenen Libraries durchgeführt, also die Funktionen Library::deinit() und Library::init() aufgerufen. In Indikatoren
 * geladene Libraries dürfen daher während ihres init()-Cycles nicht auf den alten, bereits ungültigen Hauptmodulkontext zugreifen (weder lesend noch
 * schreibend).
 *
 * TODO: • In Indikatoren geladene Libraries müssen während ihres init()-Cycles mit einer temporären Kopie des Hauptmodulkontexts arbeiten.
 *       • __SMS.alerts        integrieren
 *       • __SMS.receiver      integrieren
 *       • __STATUS_OFF        integrieren
 *       • __STATUS_OFF.reason integrieren
 */
#import "Expander.dll"
   // Getter
   int    ec_ProgramId        (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_ProgramType      (/*EXECUTION_CONTEXT*/int ec[]);
   string ec_ProgramName      (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_ModuleType       (/*EXECUTION_CONTEXT*/int ec[]);
   string ec_ModuleName       (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_LaunchType       (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_RootFunction     (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec_InitCycle        (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_InitReason       (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_UninitReason     (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec_Testing          (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec_VisualMode       (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec_Optimization     (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_InitFlags        (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_DeinitFlags      (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec_Logging          (/*EXECUTION_CONTEXT*/int ec[]);
   string ec_CustomLogFile    (/*EXECUTION_CONTEXT*/int ec[]);
   string ec_Symbol           (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_Timeframe        (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_hChart           (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_hChartWindow     (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec_SuperContext     (/*EXECUTION_CONTEXT*/int ec[], /*EXECUTION_CONTEXT*/int sec[]);
   int    ec_lpSuperContext   (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_ThreadId         (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_Ticks            (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_MqlError         (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_DllError         (/*EXECUTION_CONTEXT*/int ec[]);
   //     ...
   int    ec_DllWarning       (/*EXECUTION_CONTEXT*/int ec[]);
   //     ...

   // Setter
   int    ec_SetProgramId     (/*EXECUTION_CONTEXT*/int ec[], int    id       );
   int    ec_SetProgramType   (/*EXECUTION_CONTEXT*/int ec[], int    type     );
   string ec_SetProgramName   (/*EXECUTION_CONTEXT*/int ec[], string name     );
   int    ec_SetModuleType    (/*EXECUTION_CONTEXT*/int ec[], int    type     );
   string ec_SetModuleName    (/*EXECUTION_CONTEXT*/int ec[], string name     );
   int    ec_SetLaunchType    (/*EXECUTION_CONTEXT*/int ec[], int    type     );
   int    ec_SetRootFunction  (/*EXECUTION_CONTEXT*/int ec[], int    function );
   bool   ec_SetInitCycle     (/*EXECUTION_CONTEXT*/int ec[], int    status   );
   int    ec_SetInitReason    (/*EXECUTION_CONTEXT*/int ec[], int    reason   );
   int    ec_SetUninitReason  (/*EXECUTION_CONTEXT*/int ec[], int    reason   );
   bool   ec_SetTesting       (/*EXECUTION_CONTEXT*/int ec[], int    status   );
   bool   ec_SetVisualMode    (/*EXECUTION_CONTEXT*/int ec[], int    status   );
   bool   ec_SetOptimization  (/*EXECUTION_CONTEXT*/int ec[], int    status   );
   int    ec_SetInitFlags     (/*EXECUTION_CONTEXT*/int ec[], int    flags    );
   int    ec_SetDeinitFlags   (/*EXECUTION_CONTEXT*/int ec[], int    flags    );
   bool   ec_SetLogging       (/*EXECUTION_CONTEXT*/int ec[], int    status   );
   string ec_SetCustomLogFile (/*EXECUTION_CONTEXT*/int ec[], string logFile  );
   string ec_SetSymbol        (/*EXECUTION_CONTEXT*/int ec[], string symbol   );
   int    ec_SetTimeframe     (/*EXECUTION_CONTEXT*/int ec[], int    timeframe);
   int    ec_SetHChart        (/*EXECUTION_CONTEXT*/int ec[], int    hWnd     );
   int    ec_SetHChartWindow  (/*EXECUTION_CONTEXT*/int ec[], int    hWnd     );
   int    ec_SetSuperContext  (/*EXECUTION_CONTEXT*/int ec[], int    sec[]    );
   int    ec_SetLpSuperContext(/*EXECUTION_CONTEXT*/int ec[], int    lpSec    );
   int    ec_SetThreadId      (/*EXECUTION_CONTEXT*/int ec[], int    id       );
   int    ec_SetTicks         (/*EXECUTION_CONTEXT*/int ec[], int    count    );
   int    ec_SetMqlError      (/*EXECUTION_CONTEXT*/int ec[], int    error    );
   int    ec_SetDllError      (/*EXECUTION_CONTEXT*/int ec[], int    error    );
   //     ...
   int    ec_SetDllWarning    (/*EXECUTION_CONTEXT*/int ec[], int    error    );
   //     ...

   // Master Getter
   int    mec_RootFunction    (/*EXECUTION_CONTEXT*/int ec[]);
   int    mec_UninitReason    (/*EXECUTION_CONTEXT*/int ec[]);
   int    mec_InitFlags       (/*EXECUTION_CONTEXT*/int ec[]);

   string EXECUTION_CONTEXT_toStr  (/*EXECUTION_CONTEXT*/int ec[], int outputDebug);
   string lpEXECUTION_CONTEXT_toStr(/*EXECUTION_CONTEXT*/int lpEc, int outputDebug);
#import
