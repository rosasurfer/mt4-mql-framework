/**
 * XTrade struct EXECUTION_CONTEXT
 *
 * Ausführungskontext von und Kommunikation mit MQL-Programmen und DLL
 *
 * @see  MT4Expander::header/mql/structs/mt4/ExecutionContext.h
 *
 *
 * Im Indikator gibt es während eines init()-Cycles in der Zeitspanne vom Verlassen von Indicator::deinit() bis zum Wiedereintritt in
 * Indicator::init() keinen gültigen Hauptmodulkontext. Der alte Speicherblock wird sofort freigegeben, später wird ein neuer alloziiert.
 * Während dieser Zeitspanne wird der init()-Cycle von bereits geladenen Libraries durchgeführt, also die Funktionen Library::deinit()
 * und Library::init() aufgerufen. In Indikatoren geladene Libraries dürfen also während ihres init()-Cycles nicht auf den alten, bereits
 * ungültigen Hauptmodulkontext zugreifen (weder lesend noch schreibend).
 *
 *
 * TODO: • In Indikatoren geladene Libraries müssen während ihres init()-Cycles mit einer temporären Kopie des Hauptmodulkontexts arbeiten.
 *       • __SMS.alerts        integrieren
 *       • __SMS.receiver      integrieren
 *       • __STATUS_OFF        integrieren
 *       • __STATUS_OFF.reason integrieren
 */
#import "Expander.dll"
   // Getter
   int    ec_ProgramId            (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_ProgramType          (/*EXECUTION_CONTEXT*/int ec[]);
   string ec_ProgramName          (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_ModuleType           (/*EXECUTION_CONTEXT*/int ec[]);
   string ec_ModuleName           (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_LaunchType           (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec_SuperContext         (/*EXECUTION_CONTEXT*/int ec[], /*EXECUTION_CONTEXT*/int sec[]);
   int    ec_lpSuperContext       (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_InitFlags            (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_DeinitFlags          (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_RootFunction         (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_UninitializeReason   (/*EXECUTION_CONTEXT*/int ec[]);
   string ec_Symbol               (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_Timeframe            (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_hChartWindow         (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_hChart               (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_TestFlags            (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_LastError            (/*EXECUTION_CONTEXT*/int ec[]);
   //     ...
   bool   ec_Logging              (/*EXECUTION_CONTEXT*/int ec[]);
   string ec_LogFile              (/*EXECUTION_CONTEXT*/int ec[]);

   // Setter
   int    ec_SetProgramId         (/*EXECUTION_CONTEXT*/int ec[], int    id       );
   int    ec_SetProgramType       (/*EXECUTION_CONTEXT*/int ec[], int    type     );
   string ec_SetProgramName       (/*EXECUTION_CONTEXT*/int ec[], string name     );
   int    ec_SetModuleType        (/*EXECUTION_CONTEXT*/int ec[], int    type     );
   string ec_SetModuleName        (/*EXECUTION_CONTEXT*/int ec[], string name     );
   int    ec_SetLaunchType        (/*EXECUTION_CONTEXT*/int ec[], int    type     );
   int    ec_SetSuperContext      (/*EXECUTION_CONTEXT*/int ec[], int    sec[]    );
   int    ec_SetLpSuperContext    (/*EXECUTION_CONTEXT*/int ec[], int    lpSec    );
   int    ec_SetInitFlags         (/*EXECUTION_CONTEXT*/int ec[], int    flags    );
   int    ec_SetDeinitFlags       (/*EXECUTION_CONTEXT*/int ec[], int    flags    );
   int    ec_SetRootFunction      (/*EXECUTION_CONTEXT*/int ec[], int    function );
   int    ec_SetUninitializeReason(/*EXECUTION_CONTEXT*/int ec[], int    reason   );
   string ec_SetSymbol            (/*EXECUTION_CONTEXT*/int ec[], string symbol   );
   int    ec_SetTimeframe         (/*EXECUTION_CONTEXT*/int ec[], int    timeframe);
   int    ec_SetHChartWindow      (/*EXECUTION_CONTEXT*/int ec[], int    hWnd     );
   int    ec_SetHChart            (/*EXECUTION_CONTEXT*/int ec[], int    hWnd     );
   int    ec_SetTestFlags         (/*EXECUTION_CONTEXT*/int ec[], int    testFlags);
   int    ec_SetLastError         (/*EXECUTION_CONTEXT*/int ec[], int    error    );
   //     ...
   bool   ec_SetLogging           (/*EXECUTION_CONTEXT*/int ec[], int    logging  );
   string ec_SetLogFile           (/*EXECUTION_CONTEXT*/int ec[], string logFile  );
#import


/**
 * Gibt die lesbare Repräsentation eines an einer Adresse gespeicherten EXECUTION_CONTEXT zurück.
 *
 * @param  int  lpContext   - Adresse des EXECUTION_CONTEXT
 * @param  bool outputDebug - ob die Ausgabe zusätzlich zum Debugger geschickt werden soll (default: nein)
 *
 * @return string
 */
string lpEXECUTION_CONTEXT.toStr(int lpContext, bool outputDebug=false) {
   outputDebug = outputDebug!=0;

   if (lpContext>=0 && lpContext<MIN_VALID_POINTER) return(_EMPTY_STR(catch("lpEXECUTION_CONTEXT.toStr(1)  invalid parameter lpContext = 0x"+ IntToHexStr(lpContext) +" (not a valid pointer)", ERR_INVALID_POINTER)));

   int tmp[EXECUTION_CONTEXT.intSize];
   CopyMemory(GetIntsAddress(tmp), lpContext, EXECUTION_CONTEXT.size);

   string result = EXECUTION_CONTEXT.toStr(tmp, outputDebug);
   ArrayResize(tmp, 0);
   return(result);

   // dummy call to suppress useless compiler warning
   EXECUTION_CONTEXT.toStr(tmp);
}


/**
 * Gibt die lesbare Repräsentation eines EXECUTION_CONTEXT zurück.
 *
 * @param  int  ec[]        - EXECUTION_CONTEXT
 * @param  bool outputDebug - ob die Ausgabe zusätzlich zum Debugger geschickt werden soll (default: nein)
 *
 * @return string
 */
string EXECUTION_CONTEXT.toStr(/*EXECUTION_CONTEXT*/int ec[], bool outputDebug=false) {
   outputDebug = outputDebug!=0;

   if (ArrayDimension(ec) > 1)                     return(_EMPTY_STR(catch("EXECUTION_CONTEXT.toStr(1)  too many dimensions of parameter ec: "+ ArrayDimension(ec), ERR_INVALID_PARAMETER)));
   if (ArraySize(ec) != EXECUTION_CONTEXT.intSize) return(_EMPTY_STR(catch("EXECUTION_CONTEXT.toStr(2)  invalid size of parameter ec: "+ ArraySize(ec), ERR_INVALID_PARAMETER)));

   string result = StringConcatenate("{programId="         ,                         ec_ProgramId         (ec),
                                    ", programType="       ,        ProgramTypeToStr(ec_ProgramType       (ec)),
                                    ", programName="       ,          DoubleQuoteStr(ec_ProgramName       (ec)),
                                    ", moduleType="        ,         ModuleTypeToStr(ec_ProgramType       (ec)),
                                    ", moduleName="        ,          DoubleQuoteStr(ec_ModuleName        (ec)),
                                    ", launchType="        ,                         ec_LaunchType        (ec),
                                    ", superContext="      ,               ifString(!ec_lpSuperContext    (ec), "0", "0x"+ IntToHexStr(ec_lpSuperContext(ec))),
                                    ", initFlags="         ,          InitFlagsToStr(ec_InitFlags         (ec)),
                                    ", deinitFlags="       ,        DeinitFlagsToStr(ec_DeinitFlags       (ec)),
                                    ", rootFunction="      ,       RootFunctionToStr(ec_RootFunction      (ec)),
                                    ", uninitializeReason=", UninitializeReasonToStr(ec_UninitializeReason(ec)),
                                    ", symbol="            ,          DoubleQuoteStr(ec_Symbol            (ec)),
                                    ", timeframe="         ,             PeriodToStr(ec_Timeframe         (ec)),
                                    ", hChartWindow="      ,               ifString(!ec_hChartWindow      (ec), "0", "0x"+ IntToHexStr(ec_hChartWindow  (ec))),
                                    ", hChart="            ,               ifString(!ec_hChart            (ec), "0", "0x"+ IntToHexStr(ec_hChart        (ec))),
                                    ", testFlags="         ,          TestFlagsToStr(ec_TestFlags         (ec)),
                                    ", lastError="         ,              ErrorToStr(ec_LastError         (ec)),
                                    ", logging="           ,               BoolToStr(ec_Logging           (ec)),
                                    ", logFile="           ,          DoubleQuoteStr(ec_LogFile           (ec)), "}");
   if (outputDebug)
      debug("EXECUTION_CONTEXT.toStr()  "+ result);

   catch("EXECUTION_CONTEXT.toStr(3)");
   return(result);

   // dummy call to suppress useless compiler warning
   lpEXECUTION_CONTEXT.toStr(NULL, NULL);
}
