/**
 * MQL structure EXECUTION_CONTEXT
 *
 * Ausführungskontext eines MQL-Programms für Laufzeitinformationen und Datenaustausch zwischen MQL-Modulen und DLL
 *
 * Im Indikator gibt es während eines init()-Cycles in der Zeitspanne vom Verlassen von Indicator::deinit() bis zum Wiedereintritt in
 * Indicator::init() keinen gültigen Hauptmodulkontext. Der alte Speicherblock wird sofort freigegeben, später wird ein neuer alloziiert.
 * Während dieser Zeitspanne wird der init()-Cycle von bereits geladenen Libraries durchgeführt, also die Funktionen Library::deinit()
 * und Library::init() aufgerufen. In Indikatoren geladene Libraries dürfen also während ihres init()-Cycles nicht auf den alten, bereits
 * ungültigen Hauptmodulkontext zugreifen (weder lesend noch schreibend).
 *
 *
 * @see  Definition in Expander.dll::Expander.h
 *
 *
 * TODO: In Indikatoren geladene Libraries müssen während ihres init()-Cycles mit einer temporären Kopie des Kauptmodulkontexts arbeiten.
 *       __SMS.alerts        integrieren
 *       __SMS.receiver      integrieren
 *       __STATUS_OFF        integrieren
 *       __STATUS_OFF.reason integrieren
 */
#define I_EC.programId              0
#define I_EC.programType            1
#define I_EC.programName            2
#define I_EC.launchType            67
#define I_EC.lpSuperContext        68
#define I_EC.initFlags             69
#define I_EC.deinitFlags           70
#define I_EC.rootFunction          71
#define I_EC.uninitializeReason    72

#define I_EC.symbol                73
#define I_EC.timeframe             76
#define I_EC.hChartWindow          77
#define I_EC.hChart                78
#define I_EC.testFlags             79

#define I_EC.lastError             80
#define I_EC.dllErrors             81        // TODO: noch nicht implementiert
#define I_EC.dllErrorsSize         82        // TODO: noch nicht implementiert
#define I_EC.logging               83        // TODO: auf LOG_LEVEL umstellen
#define I_EC.logFile               84


// Setter
int    ec.setLaunchType        (/*EXECUTION_CONTEXT*/int &ec[], int    type              ) { ec[I_EC.launchType        ] = type;               return(type              ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setLpSuperContext    (/*EXECUTION_CONTEXT*/int &ec[], int    lpSuperContext    ) {
   if (lpSuperContext && lpSuperContext < MIN_VALID_POINTER) return(!catch("ec.setLpSuperContext(1)  invalid parameter lpSuperContext = 0x"+ IntToHexStr(lpSuperContext) +" (not a valid pointer)", ERR_INVALID_POINTER));
                                                                                             ec[I_EC.lpSuperContext    ] = lpSuperContext;     return(lpSuperContext    ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setInitFlags         (/*EXECUTION_CONTEXT*/int &ec[], int    initFlags         ) { ec[I_EC.initFlags         ] = initFlags;          return(initFlags         ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setDeinitFlags       (/*EXECUTION_CONTEXT*/int &ec[], int    deinitFlags       ) { ec[I_EC.deinitFlags       ] = deinitFlags;        return(deinitFlags       ); EXECUTION_CONTEXT.toStr(ec); }
string ec.setSymbol            (/*EXECUTION_CONTEXT*/int &ec[], string symbol            ) {
   if (!StringLen(symbol))                    return(_EMPTY_STR(catch("ec.setSymbol(1)  invalid parameter symbol = "+ StringToStr(symbol), ERR_INVALID_PARAMETER)));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(_EMPTY_STR(catch("ec.setSymbol(2)  too long parameter symbol = \""+ symbol +"\" (max "+ MAX_SYMBOL_LENGTH +" chars)", ERR_INVALID_PARAMETER)));
   int src  = GetStringAddress(symbol);
   int dest = GetBufferAddress(ec) + I_EC.symbol*4;
   CopyMemory(dest, src, StringLen(symbol)+1);                       /*terminierendes <NUL> wird mitkopiert*/                                  return(symbol            ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setTimeframe         (/*EXECUTION_CONTEXT*/int &ec[], int    timeframe         ) { ec[I_EC.timeframe         ] = timeframe;          return(timeframe         ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setHChartWindow      (/*EXECUTION_CONTEXT*/int &ec[], int    hChartWindow      ) { ec[I_EC.hChartWindow      ] = hChartWindow;       return(hChartWindow      ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setHChart            (/*EXECUTION_CONTEXT*/int &ec[], int    hChart            ) { ec[I_EC.hChart            ] = hChart;             return(hChart            ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setTestFlags         (/*EXECUTION_CONTEXT*/int &ec[], int    testFlags         ) { ec[I_EC.testFlags         ] = testFlags;          return(testFlags         ); EXECUTION_CONTEXT.toStr(ec); }
bool   ec.setLogging           (/*EXECUTION_CONTEXT*/int &ec[], bool   logging           ) { ec[I_EC.logging           ] = logging != 0;       return(logging != 0      ); EXECUTION_CONTEXT.toStr(ec); }
string ec.setLogFile           (/*EXECUTION_CONTEXT*/int &ec[], string logFile           ) {
   if (StringIsNull(logFile)) logFile = "";                                                          // sicherstellen, daß der String initialisiert ist
   if (StringLen(logFile) > MAX_PATH-1) return(_EMPTY_STR(catch("ec.setLogFile(1)  illegal parameter logFile = \""+ logFile +"\" (max. "+ (MAX_PATH-1) +" chars)", ERR_TOO_LONG_STRING)));
   int src  = GetStringAddress(logFile);
   int dest = GetBufferAddress(ec) + I_EC.logFile*4;
   CopyMemory(dest, src, StringLen(logFile)+1);                      /*terminierendes <NUL> wird mitkopiert*/  return(logFile           ); EXECUTION_CONTEXT.toStr(ec);
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
                                    ", programType="       ,        ModuleTypesToStr(ec_ProgramType       (ec)),
                                    ", programName="       ,             StringToStr(ec_ProgramName       (ec)),
                                    ", launchType="        ,                         ec_LaunchType        (ec),
                                    ", superContext="      ,               ifString(!ec_lpSuperContext    (ec), "0", "0x"+ IntToHexStr(ec_lpSuperContext(ec))),
                                    ", initFlags="         ,          InitFlagsToStr(ec_InitFlags         (ec)),
                                    ", deinitFlags="       ,        DeinitFlagsToStr(ec_DeinitFlags       (ec)),
                                    ", rootFunction="      ,       RootFunctionToStr(ec_RootFunction      (ec)),
                                    ", uninitializeReason=", UninitializeReasonToStr(ec_UninitializeReason(ec)),
                                    ", symbol="            ,             StringToStr(ec_Symbol            (ec)),
                                    ", timeframe="         ,             PeriodToStr(ec_Timeframe         (ec)),
                                    ", hChartWindow="      ,               ifString(!ec_hChartWindow      (ec), "0", "0x"+ IntToHexStr(ec_hChartWindow  (ec))),
                                    ", hChart="            ,               ifString(!ec_hChart            (ec), "0", "0x"+ IntToHexStr(ec_hChart        (ec))),
                                    ", testFlags="         ,          TestFlagsToStr(ec_TestFlags         (ec)),
                                    ", lastError="         ,              ErrorToStr(ec_LastError         (ec)),
                                    ", logging="           ,               BoolToStr(ec_Logging           (ec)),
                                    ", logFile="           ,             StringToStr(ec_LogFile           (ec)), "}");
   if (outputDebug)
      debug("EXECUTION_CONTEXT.toStr()  "+ result);

   catch("EXECUTION_CONTEXT.toStr(3)");
   return(result);


   // Dummy-Calls: unterdrücken unnütze Compilerwarnungen
   ec.setLaunchType    (ec, NULL);
   ec.setLpSuperContext(ec, NULL);
   ec.setInitFlags     (ec, NULL);
   ec.setDeinitFlags   (ec, NULL);
   ec.setSymbol        (ec, NULL);
   ec.setTimeframe     (ec, NULL);
   ec.setHChartWindow  (ec, NULL);
   ec.setHChart        (ec, NULL);
   ec.setTestFlags     (ec, NULL);
   ec.setLogging       (ec, NULL);
   ec.setLogFile       (ec, NULL);
   lpEXECUTION_CONTEXT.toStr(NULL);
}


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

   if (lpContext < MIN_VALID_POINTER) return(_EMPTY_STR(catch("lpEXECUTION_CONTEXT.toStr(1)  invalid parameter lpContext = 0x"+ IntToHexStr(lpContext) +" (not a valid pointer)", ERR_INVALID_POINTER)));

   int tmp[EXECUTION_CONTEXT.intSize];
   CopyMemory(GetBufferAddress(tmp), lpContext, EXECUTION_CONTEXT.size);

   string result = EXECUTION_CONTEXT.toStr(tmp, outputDebug);
   ArrayResize(tmp, 0);
   return(result);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   string DeinitFlagsToStr(int flags);
   string ErrorToStr(int error);
   string InitFlagsToStr(int flags);
   string TestFlagsToStr(int flags);

#import "Expander.dll"
   int    ec_ProgramId         (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_ProgramType       (/*EXECUTION_CONTEXT*/int ec[]);
   string ec_ProgramName       (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_LaunchType        (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_lpSuperContext    (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_InitFlags         (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_DeinitFlags       (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_RootFunction      (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_UninitializeReason(/*EXECUTION_CONTEXT*/int ec[]);
   string ec_Symbol            (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_Timeframe         (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_hChartWindow      (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_hChart            (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_TestFlags         (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_LastError         (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec_Logging           (/*EXECUTION_CONTEXT*/int ec[]);
   string ec_LogFile           (/*EXECUTION_CONTEXT*/int ec[]);

   int    GetBufferAddress(int buffer[]);
   int    GetStringAddress(string value);
   string IntToHexStr(int integer);
#import


// --------------------------------------------------------------------------------------------------------------------------------------------------


//#import "struct.EXECUTION_CONTEXT.ex4"
//   int    ec.setLaunchType        (/*EXECUTION_CONTEXT*/int ec[], int    type              );
//   int    ec.setLpSuperContext    (/*EXECUTION_CONTEXT*/int ec[], int    lpSuperContext    );
//   int    ec.setInitFlags         (/*EXECUTION_CONTEXT*/int ec[], int    initFlags         );
//   int    ec.setDeinitFlags       (/*EXECUTION_CONTEXT*/int ec[], int    deinitFlags       );
//   string ec.setSymbol            (/*EXECUTION_CONTEXT*/int ec[], string symbol            );
//   int    ec.setTimeframe         (/*EXECUTION_CONTEXT*/int ec[], int    timeframe         );
//   int    ec.setHChartWindow      (/*EXECUTION_CONTEXT*/int ec[], int    hChartWindow      );
//   int    ec.setHChart            (/*EXECUTION_CONTEXT*/int ec[], int    hChart            );
//   int    ec.setTestFlags         (/*EXECUTION_CONTEXT*/int ec[], int    testFlags         );
//   bool   ec.setLogging           (/*EXECUTION_CONTEXT*/int ec[], bool   logging           );
//   string ec.setLogFile           (/*EXECUTION_CONTEXT*/int ec[], string logFile           );

//   string   EXECUTION_CONTEXT.toStr(/*EXECUTION_CONTEXT*/int ec[], bool outputDebug);
//   string lpEXECUTION_CONTEXT.toStr(int lpContext                , bool outputDebug);
//#import
