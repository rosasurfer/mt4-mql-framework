/**
 * Framework struct EXECUTION_CONTEXT
 *
 * Ausführungskontext von MQL-Programmen zur Kommunikation zwischen MQL und DLL
 *
 * @see  https://github.com/rosasurfer/mt4-expander/blob/master/header/struct/rsf/ExecutionContext.h
 *
 * Im Indikator gibt es während eines init()-Cycles in der Zeitspanne vom Verlassen von Indicator::deinit() bis zum Wieder-
 * eintritt in Indicator::init() keinen gültigen Hauptmodulkontext. Der alte Speicherblock wird sofort freigegeben, später
 * wird ein neuer alloziiert. Während dieser Zeitspanne wird der init()-Cycle von bereits geladenen Libraries durchgeführt,
 * also die Funktionen Library::deinit() und Library::init() aufgerufen. In Indikatoren geladene Libraries dürfen daher
 * während ihres init()-Cycles nicht auf den alten, bereits ungültigen Hauptmodulkontext zugreifen (weder lesend noch
 * schreibend).
 *
 * TODO: • In Indikatoren geladene Libraries müssen während ihres init()-Cycles mit einer temporären Kopie des Hauptmodul-
 *         kontexts arbeiten.
 *       • __SMS.alerts        integrieren
 *       • __SMS.receiver      integrieren
 *       • __STATUS_OFF        integrieren
 *       • __STATUS_OFF.reason integrieren
 */
#import "rsfExpander.dll"
   // getters
   int      ec_Pid                (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_PreviousPid        (/*EXECUTION_CONTEXT*/int ec[]);

   int      ec_ProgramType        (/*EXECUTION_CONTEXT*/int ec[]);
   string   ec_ProgramName        (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_ProgramCoreFunction(/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_ProgramInitReason  (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_ProgramUninitReason(/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_ProgramInitFlags   (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_ProgramDeinitFlags (/*EXECUTION_CONTEXT*/int ec[]);

   int      ec_ModuleType         (/*EXECUTION_CONTEXT*/int ec[]);
   string   ec_ModuleName         (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_ModuleCoreFunction (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_ModuleUninitReason (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_ModuleInitFlags    (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_ModuleDeinitFlags  (/*EXECUTION_CONTEXT*/int ec[]);

   string   ec_Symbol             (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_Timeframe          (/*EXECUTION_CONTEXT*/int ec[]);
   //       ec.rates
   int      ec_Bars               (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_ChangedBars        (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_UnchangedBars      (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_Ticks              (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_CycleTicks         (/*EXECUTION_CONTEXT*/int ec[]);
   datetime ec_LastTickTime       (/*EXECUTION_CONTEXT*/int ec[]);
   datetime ec_PrevTickTime       (/*EXECUTION_CONTEXT*/int ec[]);
   double   ec_Bid                (/*EXECUTION_CONTEXT*/int ec[]);
   double   ec_Ask                (/*EXECUTION_CONTEXT*/int ec[]);

   int      ec_Digits             (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_PipDigits          (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_SubPipDigits       (/*EXECUTION_CONTEXT*/int ec[]);
   double   ec_Pip                (/*EXECUTION_CONTEXT*/int ec[]);
   double   ec_Point              (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_PipPoints          (/*EXECUTION_CONTEXT*/int ec[]);
   string   ec_PriceFormat        (/*EXECUTION_CONTEXT*/int ec[]);
   string   ec_PipPriceFormat     (/*EXECUTION_CONTEXT*/int ec[]);
   string   ec_SubPipPriceFormat  (/*EXECUTION_CONTEXT*/int ec[]);

   bool     ec_SuperContext       (/*EXECUTION_CONTEXT*/int ec[], /*EXECUTION_CONTEXT*/int target[]);
   int      ec_lpSuperContext     (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_ThreadId           (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_hChart             (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_hChartWindow       (/*EXECUTION_CONTEXT*/int ec[]);

   //       ec.test
   int      ec_TestId             (/*EXECUTION_CONTEXT*/int ec[]);
   datetime ec_TestCreated        (/*EXECUTION_CONTEXT*/int ec[]);
   datetime ec_TestStartTime      (/*EXECUTION_CONTEXT*/int ec[]);
   datetime ec_TestEndTime        (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_TestBarModel       (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_TestBars           (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_TestTicks          (/*EXECUTION_CONTEXT*/int ec[]);
   double   ec_TestSpread         (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_TestTradeDirections(/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_TestReportId       (/*EXECUTION_CONTEXT*/int ec[]);
   string   ec_TestReportSymbol   (/*EXECUTION_CONTEXT*/int ec[]);
   bool     ec_Testing            (/*EXECUTION_CONTEXT*/int ec[]);
   bool     ec_VisualMode         (/*EXECUTION_CONTEXT*/int ec[]);
   bool     ec_Optimization       (/*EXECUTION_CONTEXT*/int ec[]);

   bool     ec_ExtReporting       (/*EXECUTION_CONTEXT*/int ec[]);
   bool     ec_RecordEquity       (/*EXECUTION_CONTEXT*/int ec[]);

   int      ec_MqlError           (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_DllError           (/*EXECUTION_CONTEXT*/int ec[]);
   //       ec.dllErrorMsg
   int      ec_DllWarning         (/*EXECUTION_CONTEXT*/int ec[]);
   //       ec.dllWarningMsg
   bool     ec_LogEnabled         (/*EXECUTION_CONTEXT*/int ec[]);
   bool     ec_CustomLogging      (/*EXECUTION_CONTEXT*/int ec[]);
   string   ec_CustomLogFile      (/*EXECUTION_CONTEXT*/int ec[]);


   // used setters
   int      ec_SetProgramCoreFunction(/*EXECUTION_CONTEXT*/int ec[], int function);
   int      ec_SetMqlError           (/*EXECUTION_CONTEXT*/int ec[], int error   );
   int      ec_SetDllError           (/*EXECUTION_CONTEXT*/int ec[], int error   );
   bool     ec_SetLogEnabled         (/*EXECUTION_CONTEXT*/int ec[], int status  );


   // helpers
   string EXECUTION_CONTEXT_toStr  (/*EXECUTION_CONTEXT*/int ec[], int outputDebug);
   string lpEXECUTION_CONTEXT_toStr(/*EXECUTION_CONTEXT*/int lpEc, int outputDebug);
#import
