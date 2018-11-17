/**
 * Framework struct EXECUTION_CONTEXT
 *
 * Ausführungskontext von MQL-Programmen zur Kommunikation zwischen MQL und DLL
 *
 * @see  MT4Expander::header/struct/xtrade/ExecutionContext.h
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
   int      ec_ProgramType        (/*EXECUTION_CONTEXT*/int ec[]);
   string   ec_ProgramName        (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_ModuleType         (/*EXECUTION_CONTEXT*/int ec[]);
   string   ec_ModuleName         (/*EXECUTION_CONTEXT*/int ec[]);

   int      ec_LaunchType         (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_CoreFunction       (/*EXECUTION_CONTEXT*/int ec[]);
   bool     ec_InitCycle          (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_InitReason         (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_UninitReason       (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_InitFlags          (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_DeinitFlags        (/*EXECUTION_CONTEXT*/int ec[]);

   string   ec_Symbol             (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_Timeframe          (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_Digits             (/*EXECUTION_CONTEXT*/int ec[]);
   //       ec.rates
   int      ec_Bars               (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_ChangedBars        (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_UnchangedBars      (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_Ticks              (/*EXECUTION_CONTEXT*/int ec[]);
   datetime ec_LastTickTime       (/*EXECUTION_CONTEXT*/int ec[]);
   datetime ec_PrevTickTime       (/*EXECUTION_CONTEXT*/int ec[]);
   double   ec_Bid                (/*EXECUTION_CONTEXT*/int ec[]);
   double   ec_Ask                (/*EXECUTION_CONTEXT*/int ec[]);

   bool     ec_SuperContext       (/*EXECUTION_CONTEXT*/int ec[], /*EXECUTION_CONTEXT*/int target[]);
   int      ec_lpSuperContext     (/*EXECUTION_CONTEXT*/int ec[]);

   bool     ec_ExtReporting       (/*EXECUTION_CONTEXT*/int ec[]);
   bool     ec_RecordEquity       (/*EXECUTION_CONTEXT*/int ec[]);
   bool     ec_Optimization       (/*EXECUTION_CONTEXT*/int ec[]);
   bool     ec_VisualMode         (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_hChart             (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_hChartWindow       (/*EXECUTION_CONTEXT*/int ec[]);

   //       ec.test
   int      ec_TestId             (/*EXECUTION_CONTEXT*/int ec[]);
   datetime ec_TestCreated        (/*EXECUTION_CONTEXT*/int ec[]);
   string   ec_TestStrategy       (/*EXECUTION_CONTEXT*/int ec[]);
   string   ec_TestSymbol         (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_TestTimeframe      (/*EXECUTION_CONTEXT*/int ec[]);
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

   int      ec_ThreadId           (/*EXECUTION_CONTEXT*/int ec[]);

   int      ec_MqlError           (/*EXECUTION_CONTEXT*/int ec[]);
   int      ec_DllError           (/*EXECUTION_CONTEXT*/int ec[]);
   //       ec.dllErrorMsg
   int      ec_DllWarning         (/*EXECUTION_CONTEXT*/int ec[]);
   //       ec.dllWarningMsg
   bool     ec_Logging            (/*EXECUTION_CONTEXT*/int ec[]);
   bool     ec_CustomLogging      (/*EXECUTION_CONTEXT*/int ec[]);
   string   ec_CustomLogFile      (/*EXECUTION_CONTEXT*/int ec[]);


   // setters
   //       ...
   int      ec_SetCoreFunction    (/*EXECUTION_CONTEXT*/int ec[], int function);
   //       ...
   bool     ec_SetLogging         (/*EXECUTION_CONTEXT*/int ec[], int status  );
   //       ...
   int      ec_SetMqlError        (/*EXECUTION_CONTEXT*/int ec[], int error   );
   int      ec_SetDllError        (/*EXECUTION_CONTEXT*/int ec[], int error   );


   // master context getters
   int      mec_Pid               (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_ProgramType       (/*EXECUTION_CONTEXT*/int ec[]);
   string   mec_ProgramName       (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_ModuleType        (/*EXECUTION_CONTEXT*/int ec[]);
   string   mec_ModuleName        (/*EXECUTION_CONTEXT*/int ec[]);

   int      mec_LaunchType        (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_CoreFunction      (/*EXECUTION_CONTEXT*/int ec[]);
   bool     mec_InitCycle         (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_InitReason        (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_UninitReason      (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_InitFlags         (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_DeinitFlags       (/*EXECUTION_CONTEXT*/int ec[]);

   string   mec_Symbol            (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_Timeframe         (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_Digits            (/*EXECUTION_CONTEXT*/int ec[]);
   //       mec.rates
   int      mec_Bars              (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_ChangedBars       (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_UnchangedBars     (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_Ticks             (/*EXECUTION_CONTEXT*/int ec[]);
   datetime mec_LastTickTime      (/*EXECUTION_CONTEXT*/int ec[]);
   datetime mec_PrevTickTime      (/*EXECUTION_CONTEXT*/int ec[]);
   double   mec_Bid               (/*EXECUTION_CONTEXT*/int ec[]);
   double   mec_Ask               (/*EXECUTION_CONTEXT*/int ec[]);

   //       mec.test
   bool     mec_Testing           (/*EXECUTION_CONTEXT*/int ec[]);
   bool     mec_VisualMode        (/*EXECUTION_CONTEXT*/int ec[]);
   bool     mec_Optimization      (/*EXECUTION_CONTEXT*/int ec[]);

   bool     mec_ExtReporting      (/*EXECUTION_CONTEXT*/int ec[]);
   bool     mec_RecordEquity      (/*EXECUTION_CONTEXT*/int ec[]);

   bool     mec_SuperContext      (/*EXECUTION_CONTEXT*/int ec[], /*EXECUTION_CONTEXT*/int target[]);
   int      mec_lpSuperContext    (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_ThreadId          (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_hChart            (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_hChartWindow      (/*EXECUTION_CONTEXT*/int ec[]);

   int      mec_MqlError          (/*EXECUTION_CONTEXT*/int ec[]);
   int      mec_DllError          (/*EXECUTION_CONTEXT*/int ec[]);
   //       mec.dllErrorMsg
   int      mec_DllWarning        (/*EXECUTION_CONTEXT*/int ec[]);
   //       mec.dllWarningMsg
   bool     mec_Logging           (/*EXECUTION_CONTEXT*/int ec[]);
   bool     mec_CustomLogging     (/*EXECUTION_CONTEXT*/int ec[]);
   string   mec_CustomLogFile     (/*EXECUTION_CONTEXT*/int ec[]);


   // helpers
   string EXECUTION_CONTEXT_toStr  (/*EXECUTION_CONTEXT*/int ec[], int outputDebug);
   string lpEXECUTION_CONTEXT_toStr(/*EXECUTION_CONTEXT*/int lpEc, int outputDebug);
#import
