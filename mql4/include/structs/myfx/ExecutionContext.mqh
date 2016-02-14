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
 * @see  Definition in MT4Expander::Expander.h
 *
 *
 * TODO: In Indikatoren geladene Libraries müssen während ihres init()-Cycles mit einer temporären Kopie des Hauptmodulkontexts arbeiten.
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


// Getter
int    ec.ProgramId            (/*EXECUTION_CONTEXT*/int ec[]                                ) {                          return(ec[I_EC.programId         ]);                      EXECUTION_CONTEXT.toStr(ec); }
int    ec.ProgramType          (/*EXECUTION_CONTEXT*/int ec[]                                ) {                          return(ec[I_EC.programType       ]);                      EXECUTION_CONTEXT.toStr(ec); }
string ec.ProgramName          (/*EXECUTION_CONTEXT*/int ec[]                                ) { return(GetString(GetIntsAddress(ec)+I_EC.programName*4));                          EXECUTION_CONTEXT.toStr(ec); }
int    ec.LaunchType           (/*EXECUTION_CONTEXT*/int ec[]                                ) {                          return(ec[I_EC.launchType        ]);                      EXECUTION_CONTEXT.toStr(ec); }
int    ec.lpSuperContext       (/*EXECUTION_CONTEXT*/int ec[]                                ) {                          return(ec[I_EC.lpSuperContext    ]);                      EXECUTION_CONTEXT.toStr(ec); }
int    ec.SuperContext         (/*EXECUTION_CONTEXT*/int ec[], /*EXECUTION_CONTEXT*/int sec[]) {
   if (ArrayDimension(sec) != 1)        return(catch("ec.SuperContext(1)  too many dimensions of parameter sec = "+ ArrayDimension(sec), ERR_INCOMPATIBLE_ARRAYS));
   if (ArraySize(sec) != EXECUTION_CONTEXT.intSize)
      ArrayResize(sec, EXECUTION_CONTEXT.intSize);
   int lpSuperContext = ec.lpSuperContext(ec);
   if (!lpSuperContext) ArrayInitialize(sec, 0);
   else                 CopyMemory(GetIntsAddress(sec), lpSuperContext, EXECUTION_CONTEXT.size);
   return(catch("ec.SuperContext(2)"));                                                                                                                                             EXECUTION_CONTEXT.toStr(ec);
}
int    ec.InitFlags            (/*EXECUTION_CONTEXT*/int ec[]                                ) {                          return(ec[I_EC.initFlags         ]);                      EXECUTION_CONTEXT.toStr(ec); }
int    ec.DeinitFlags          (/*EXECUTION_CONTEXT*/int ec[]                                ) {                          return(ec[I_EC.deinitFlags       ]);                      EXECUTION_CONTEXT.toStr(ec); }
int    ec.RootFunction         (/*EXECUTION_CONTEXT*/int ec[]                                ) {                          return(ec[I_EC.rootFunction      ]);                      EXECUTION_CONTEXT.toStr(ec); }
int    ec.UninitializeReason   (/*EXECUTION_CONTEXT*/int ec[]                                ) {                          return(ec[I_EC.uninitializeReason]);                      EXECUTION_CONTEXT.toStr(ec); }
string ec.Symbol               (/*EXECUTION_CONTEXT*/int ec[]                                ) { return(GetString(GetIntsAddress(ec)+I_EC.symbol*4));                               EXECUTION_CONTEXT.toStr(ec); }
int    ec.Timeframe            (/*EXECUTION_CONTEXT*/int ec[]                                ) {                          return(ec[I_EC.timeframe         ]);                      EXECUTION_CONTEXT.toStr(ec); }
int    ec.hChartWindow         (/*EXECUTION_CONTEXT*/int ec[]                                ) {                          return(ec[I_EC.hChartWindow      ]);                      EXECUTION_CONTEXT.toStr(ec); }
int    ec.hChart               (/*EXECUTION_CONTEXT*/int ec[]                                ) {                          return(ec[I_EC.hChart            ]);                      EXECUTION_CONTEXT.toStr(ec); }
int    ec.TestFlags            (/*EXECUTION_CONTEXT*/int ec[]                                ) {                          return(ec[I_EC.testFlags         ]);                      EXECUTION_CONTEXT.toStr(ec); }
int    ec.LastError            (/*EXECUTION_CONTEXT*/int ec[]                                ) {                          return(ec[I_EC.lastError         ]);                      EXECUTION_CONTEXT.toStr(ec); }
bool   ec.Logging              (/*EXECUTION_CONTEXT*/int ec[]                                ) {                          return(ec[I_EC.logging           ] != 0);                 EXECUTION_CONTEXT.toStr(ec); }
string ec.LogFile              (/*EXECUTION_CONTEXT*/int ec[]                                ) { return(GetString(GetIntsAddress(ec)+I_EC.logFile*4));                              EXECUTION_CONTEXT.toStr(ec); }


// Setter
int    ec.setProgramId         (/*EXECUTION_CONTEXT*/int &ec[], int    id                ) { ec[I_EC.programId         ] = id;                          return(id                ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setProgramType       (/*EXECUTION_CONTEXT*/int &ec[], int    type              ) { ec[I_EC.programType       ] = type;                        return(type              ); EXECUTION_CONTEXT.toStr(ec); }
string ec.setProgramName       (/*EXECUTION_CONTEXT*/int &ec[], string name              ) {
   if (!StringLen(name))             return(_EMPTY_STR(catch("ec.setProgramName(1)  invalid parameter name = "+ DoubleQuoteStr(name), ERR_INVALID_PARAMETER)));
   if (StringLen(name) > MAX_PATH-1) return(_EMPTY_STR(catch("ec.setProgramName(2)  illegal parameter name = \""+ name +"\" (max "+ (MAX_PATH-1) +" chars)", ERR_TOO_LONG_STRING)));
   int src  = GetStringAddress(name);
   int dest = GetIntsAddress(ec) + I_EC.programName*4;
   CopyMemory(dest, src, StringLen(name)+1);                         /*terminierendes <NUL> wird mitkopiert*/                                           return(name              ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setLaunchType        (/*EXECUTION_CONTEXT*/int &ec[], int    type              ) { ec[I_EC.launchType        ] = type;                        return(type              ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setSuperContext      (/*EXECUTION_CONTEXT*/int  ec[], int    sec[]             ) { int lpSec = ec.setLpSuperContext(ec, GetIntsAddress(sec)); return(lpSec             ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setLpSuperContext    (/*EXECUTION_CONTEXT*/int &ec[], int    lpSuperContext    ) {
   if (lpSuperContext && lpSuperContext>=0 && lpSuperContext<MIN_VALID_POINTER) return(!catch("ec.setLpSuperContext(1)  invalid parameter lpSuperContext = 0x"+ IntToHexStr(lpSuperContext) +" (not a valid pointer)", ERR_INVALID_POINTER));
                                                                                             ec[I_EC.lpSuperContext    ] = lpSuperContext;              return(lpSuperContext    ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setInitFlags         (/*EXECUTION_CONTEXT*/int &ec[], int    initFlags         ) { ec[I_EC.initFlags         ] = initFlags;                   return(initFlags         ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setDeinitFlags       (/*EXECUTION_CONTEXT*/int &ec[], int    deinitFlags       ) { ec[I_EC.deinitFlags       ] = deinitFlags;                 return(deinitFlags       ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setRootFunction      (/*EXECUTION_CONTEXT*/int &ec[], int    rootFunction      ) { ec[I_EC.rootFunction      ] = rootFunction;                return(rootFunction      ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setUninitializeReason(/*EXECUTION_CONTEXT*/int &ec[], int    uninitializeReason) { ec[I_EC.uninitializeReason] = uninitializeReason;          return(uninitializeReason); EXECUTION_CONTEXT.toStr(ec); }
string ec.setSymbol            (/*EXECUTION_CONTEXT*/int &ec[], string symbol            ) {
   if (!StringLen(symbol))                    return(_EMPTY_STR(catch("ec.setSymbol(1)  invalid parameter symbol = "+ DoubleQuoteStr(symbol), ERR_INVALID_PARAMETER)));
   if (StringLen(symbol) > MAX_SYMBOL_LENGTH) return(_EMPTY_STR(catch("ec.setSymbol(2)  too long parameter symbol = \""+ symbol +"\" (max "+ MAX_SYMBOL_LENGTH +" chars)", ERR_INVALID_PARAMETER)));
   int src  = GetStringAddress(symbol);
   int dest = GetIntsAddress(ec) + I_EC.symbol*4;
   CopyMemory(dest, src, StringLen(symbol)+1);                       /*terminierendes <NUL> wird mitkopiert*/                                           return(symbol            ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setTimeframe         (/*EXECUTION_CONTEXT*/int &ec[], int    timeframe         ) { ec[I_EC.timeframe         ] = timeframe;                   return(timeframe         ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setHChartWindow      (/*EXECUTION_CONTEXT*/int &ec[], int    hChartWindow      ) { ec[I_EC.hChartWindow      ] = hChartWindow;                return(hChartWindow      ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setHChart            (/*EXECUTION_CONTEXT*/int &ec[], int    hChart            ) { ec[I_EC.hChart            ] = hChart;                      return(hChart            ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setTestFlags         (/*EXECUTION_CONTEXT*/int &ec[], int    testFlags         ) { ec[I_EC.testFlags         ] = testFlags;                   return(testFlags         ); EXECUTION_CONTEXT.toStr(ec); }

int    ec.setLastError         (/*EXECUTION_CONTEXT*/int &ec[], int    lastError         ) { ec[I_EC.lastError         ] = lastError;
   int lpSuperContext = ec.lpSuperContext(ec);
   if (lpSuperContext != 0) {
      int sec[];
      ec.SuperContext(ec, sec);
      ec.setLastError(sec, lastError);                               // Fehler rekursiv in allen SuperContexten setzen
      ArrayResize(sec, 0);
   }                                                                                                                                                    return(lastError         ); EXECUTION_CONTEXT.toStr(ec); }
bool   ec.setLogging           (/*EXECUTION_CONTEXT*/int &ec[], bool   logging           ) { ec[I_EC.logging           ] = logging != 0;                return(logging != 0      ); EXECUTION_CONTEXT.toStr(ec); }
string ec.setLogFile           (/*EXECUTION_CONTEXT*/int &ec[], string logFile           ) {
   if (StringIsNull(logFile)) logFile = "";                                                          // sicherstellen, daß der String initialisiert ist
   if (StringLen(logFile) > MAX_PATH-1) return(_EMPTY_STR(catch("ec.setLogFile(1)  illegal parameter logFile = \""+ logFile +"\" (max. "+ (MAX_PATH-1) +" chars)", ERR_TOO_LONG_STRING)));
   int src  = GetStringAddress(logFile);
   int dest = GetIntsAddress(ec) + I_EC.logFile*4;
   CopyMemory(dest, src, StringLen(logFile)+1);                      /*terminierendes <NUL> wird mitkopiert*/                                           return(logFile           ); EXECUTION_CONTEXT.toStr(ec);
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

   if (lpContext>=0 && lpContext<MIN_VALID_POINTER) return(_EMPTY_STR(catch("lpEXECUTION_CONTEXT.toStr(1)  invalid parameter lpContext = 0x"+ IntToHexStr(lpContext) +" (not a valid pointer)", ERR_INVALID_POINTER)));

   int tmp[EXECUTION_CONTEXT.intSize];
   CopyMemory(GetIntsAddress(tmp), lpContext, EXECUTION_CONTEXT.size);

   string result = EXECUTION_CONTEXT.toStr(tmp, outputDebug);
   ArrayResize(tmp, 0);
   return(result);

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

   string result = StringConcatenate("{programId="         ,                         ec.ProgramId         (ec),
                                    ", programType="       ,        ModuleTypesToStr(ec.ProgramType       (ec)),
                                    ", programName="       ,          DoubleQuoteStr(ec.ProgramName       (ec)),
                                    ", launchType="        ,                         ec.LaunchType        (ec),
                                    ", superContext="      ,               ifString(!ec.lpSuperContext    (ec), "0", "0x"+ IntToHexStr(ec.lpSuperContext(ec))),
                                    ", initFlags="         ,          InitFlagsToStr(ec.InitFlags         (ec)),
                                    ", deinitFlags="       ,        DeinitFlagsToStr(ec.DeinitFlags       (ec)),
                                    ", rootFunction="      ,       RootFunctionToStr(ec.RootFunction      (ec)),
                                    ", uninitializeReason=", UninitializeReasonToStr(ec.UninitializeReason(ec)),
                                    ", symbol="            ,          DoubleQuoteStr(ec.Symbol            (ec)),
                                    ", timeframe="         ,             PeriodToStr(ec.Timeframe         (ec)),
                                    ", hChartWindow="      ,               ifString(!ec.hChartWindow      (ec), "0", "0x"+ IntToHexStr(ec.hChartWindow  (ec))),
                                    ", hChart="            ,               ifString(!ec.hChart            (ec), "0", "0x"+ IntToHexStr(ec.hChart        (ec))),
                                    ", testFlags="         ,          TestFlagsToStr(ec.TestFlags         (ec)),
                                    ", lastError="         ,              ErrorToStr(ec.LastError         (ec)),
                                    ", logging="           ,               BoolToStr(ec.Logging           (ec)),
                                    ", logFile="           ,          DoubleQuoteStr(ec.LogFile           (ec)), "}");
   if (outputDebug)
      debug("EXECUTION_CONTEXT.toStr()  "+ result);

   catch("EXECUTION_CONTEXT.toStr(3)");
   return(result);


   // Dummy-Calls: unterdrücken unnütze Compilerwarnungen
   int iNulls[];
   ec.ProgramId            (iNulls        );
   ec.ProgramType          (iNulls        );
   ec.ProgramName          (iNulls        );
   ec.LaunchType           (iNulls        );
   ec.lpSuperContext       (iNulls        );
   ec.SuperContext         (iNulls, iNulls);
   ec.InitFlags            (iNulls        );
   ec.DeinitFlags          (iNulls        );
   ec.RootFunction         (iNulls        );
   ec.UninitializeReason   (iNulls        );
   ec.Symbol               (iNulls        );
   ec.Timeframe            (iNulls        );
   ec.hChartWindow         (iNulls        );
   ec.hChart               (iNulls        );
   ec.TestFlags            (iNulls        );
   ec.LastError            (iNulls        );
   ec.Logging              (iNulls        );
   ec.LogFile              (iNulls        );

   ec.setProgramId         (iNulls, NULL  );
   ec.setProgramType       (iNulls, NULL  );
   ec.setProgramName       (iNulls, NULL  );
   ec.setLaunchType        (iNulls, NULL  );
   ec.setSuperContext      (iNulls, iNulls);
   ec.setLpSuperContext    (iNulls, NULL  );
   ec.setInitFlags         (iNulls, NULL  );
   ec.setDeinitFlags       (iNulls, NULL  );
   ec.setRootFunction      (iNulls, NULL  );
   ec.setUninitializeReason(iNulls, NULL  );
   ec.setSymbol            (iNulls, NULL  );
   ec.setTimeframe         (iNulls, NULL  );
   ec.setHChartWindow      (iNulls, NULL  );
   ec.setHChart            (iNulls, NULL  );
   ec.setTestFlags         (iNulls, NULL  );
   ec.setLastError         (iNulls, NULL  );
   ec.setLogging           (iNulls, NULL  );
   ec.setLogFile           (iNulls, NULL  );

   lpEXECUTION_CONTEXT.toStr(NULL, NULL);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   string DeinitFlagsToStr(int flags);
   string ErrorToStr(int error);
   string InitFlagsToStr(int flags);
   string TestFlagsToStr(int flags);

#import "Expander.dll"
   int    ec_ProgramId            (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_ProgramType          (/*EXECUTION_CONTEXT*/int ec[]);
   string ec_ProgramName          (/*EXECUTION_CONTEXT*/int ec[]);
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
   //     ...
   bool   ec_Logging              (/*EXECUTION_CONTEXT*/int ec[]);
   string ec_LogFile              (/*EXECUTION_CONTEXT*/int ec[]);


   int    ec_setProgramId         (/*EXECUTION_CONTEXT*/int ec[], int    id       );
   int    ec_setProgramType       (/*EXECUTION_CONTEXT*/int ec[], int    type     );
   string ec_setProgramName       (/*EXECUTION_CONTEXT*/int ec[], string name     );
   int    ec_setLaunchType        (/*EXECUTION_CONTEXT*/int ec[], int    type     );
   int    ec_setSuperContext      (/*EXECUTION_CONTEXT*/int ec[], int    sec[]    );
   int    ec_setLpSuperContext    (/*EXECUTION_CONTEXT*/int ec[], int    lpSec    );
   int    ec_setInitFlags         (/*EXECUTION_CONTEXT*/int ec[], int    flags    );
   int    ec_setDeinitFlags       (/*EXECUTION_CONTEXT*/int ec[], int    flags    );
   int    ec_setRootFunction      (/*EXECUTION_CONTEXT*/int ec[], int    function );
   int    ec_setUninitializeReason(/*EXECUTION_CONTEXT*/int ec[], int    reason   );
   string ec_setSymbol            (/*EXECUTION_CONTEXT*/int ec[], string symbol   );
   int    ec_setTimeframe         (/*EXECUTION_CONTEXT*/int ec[], int    timeframe);
   int    ec_setHChartWindow      (/*EXECUTION_CONTEXT*/int ec[], int    hWnd     );
   int    ec_setHChart            (/*EXECUTION_CONTEXT*/int ec[], int    hWnd     );
   int    ec_setTestFlags         (/*EXECUTION_CONTEXT*/int ec[], int    testFlags);
   int    ec_setLastError         (/*EXECUTION_CONTEXT*/int ec[], int    error    );
   //     ...
   //     ...
   bool   ec_setLogging           (/*EXECUTION_CONTEXT*/int ec[], int    logging  );
   string ec_setLogFile           (/*EXECUTION_CONTEXT*/int ec[], string logFile  );

   string PeriodToStr(int period);
   string RootFunctionToStr(int id);
   string UninitializeReasonToStr(int reason);
#import


