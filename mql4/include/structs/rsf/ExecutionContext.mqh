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
 *       • __STATUS_OFF        integrieren
 *       • __STATUS_OFF.reason integrieren
 */
#import "rsfExpander.dll"
   // getters
   int      ec_Pid                (int ec[]);
   int      ec_PreviousPid        (int ec[]);

   int      ec_ProgramType        (int ec[]);
   string   ec_ProgramName        (int ec[]);
   int      ec_ProgramCoreFunction(int ec[]);
   int      ec_ProgramInitReason  (int ec[]);
   int      ec_ProgramUninitReason(int ec[]);
   int      ec_ProgramInitFlags   (int ec[]);
   int      ec_ProgramDeinitFlags (int ec[]);

   int      ec_ModuleType         (int ec[]);
   string   ec_ModuleName         (int ec[]);
   int      ec_ModuleCoreFunction (int ec[]);
   int      ec_ModuleUninitReason (int ec[]);
   int      ec_ModuleInitFlags    (int ec[]);
   int      ec_ModuleDeinitFlags  (int ec[]);

   string   ec_Symbol             (int ec[]);
   int      ec_Timeframe          (int ec[]);
   //       ec.rates
   int      ec_Bars               (int ec[]);
   int      ec_ChangedBars        (int ec[]);
   int      ec_UnchangedBars      (int ec[]);
   int      ec_Ticks              (int ec[]);
   int      ec_CycleTicks         (int ec[]);
   datetime ec_PrevTickTime       (int ec[]);
   datetime ec_CurrTickTime       (int ec[]);
   double   ec_Bid                (int ec[]);
   double   ec_Ask                (int ec[]);

   int      ec_Digits             (int ec[]);
   int      ec_PipDigits          (int ec[]);
   int      ec_SubPipDigits       (int ec[]);
   double   ec_Pip                (int ec[]);
   double   ec_Point              (int ec[]);
   int      ec_PipPoints          (int ec[]);
   string   ec_PriceFormat        (int ec[]);
   string   ec_PipPriceFormat     (int ec[]);
   string   ec_SubPipPriceFormat  (int ec[]);

   bool     ec_SuperContext       (int ec[], int target[]);
   int      ec_lpSuperContext     (int ec[]);
   int      ec_ThreadId           (int ec[]);
   int      ec_hChart             (int ec[]);
   int      ec_hChartWindow       (int ec[]);

   //       ec.test
   int      ec_TestId             (int ec[]);
   datetime ec_TestCreated        (int ec[]);
   datetime ec_TestStartTime      (int ec[]);
   datetime ec_TestEndTime        (int ec[]);
   int      ec_TestBarModel       (int ec[]);
   int      ec_TestBars           (int ec[]);
   int      ec_TestTicks          (int ec[]);
   double   ec_TestSpread         (int ec[]);
   int      ec_TestTradeDirections(int ec[]);
   int      ec_TestReportId       (int ec[]);
   string   ec_TestReportSymbol   (int ec[]);
   bool     ec_Testing            (int ec[]);
   bool     ec_VisualMode         (int ec[]);
   bool     ec_Optimization       (int ec[]);

   bool     ec_ExtReporting       (int ec[]);
   bool     ec_RecordEquity       (int ec[]);

   int      ec_MqlError           (int ec[]);
   int      ec_DllError           (int ec[]);
   //       ec.dllErrorMsg
   int      ec_DllWarning         (int ec[]);
   //       ec.dllWarningMsg

   int      ec_Loglevel           (int ec[]);
   int      ec_LoglevelTerminal   (int ec[]);
   int      ec_LoglevelAlert      (int ec[]);
   int      ec_LoglevelDebugger   (int ec[]);
   int      ec_LoglevelFile       (int ec[]);
   int      ec_LoglevelMail       (int ec[]);
   int      ec_LoglevelSMS        (int ec[]);
   //       ec.logger
   //       ec.logBuffer
   string   ec_LogFilename        (int ec[]);


   // used setters
   int      ec_SetProgramCoreFunction(int ec[], int id);
   int      ec_SetMqlError           (int ec[], int error);
   int      ec_SetDllError           (int ec[], int error);
   int      ec_SetLoglevel           (int ec[], int level);
   int      ec_SetLoglevelTerminal   (int ec[], int level);
   int      ec_SetLoglevelAlert      (int ec[], int level);
   int      ec_SetLoglevelDebugger   (int ec[], int level);
   int      ec_SetLoglevelFile       (int ec[], int level);
   int      ec_SetLoglevelMail       (int ec[], int level);
   int      ec_SetLoglevelSMS        (int ec[], int level);


   // helpers
   string   EXECUTION_CONTEXT_toStr  (int ec[]);
   string   lpEXECUTION_CONTEXT_toStr(int lpEc);
#import
