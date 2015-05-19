/**
 * MQL structure EXECUTION_CONTEXT
 *
 * @see  Definition in Expander.dll::Expander.h
 *
 *
 * TODO: __SMS.alerts        integrieren
 *       __SMS.receiver      integrieren
 *       __STATUS_OFF        integrieren
 *       __STATUS_OFF.reason integrieren
 *
 * Note: Importdeklarationen der entsprechenden Library am Ende dieser Datei
 */
#define I_EC.hThreadId              0        // ohne MQL-Setter
#define I_EC.programId              1        // ohne MQL-Setter
#define I_EC.programType            2
#define I_EC.lpProgramName          3        // TODO: im Struct speichern
#define I_EC.launchType             4
#define I_EC.lpSuperContext         5
#define I_EC.initFlags              6
#define I_EC.deinitFlags            7
#define I_EC.rootFunction           8
#define I_EC.uninitializeReason     9

#define I_EC.symbol                10        // TODO: noch nicht implementiert
#define I_EC.timeframe             13        // TODO: noch nicht implementiert
#define I_EC.hChartWindow          14
#define I_EC.hChart                15
#define I_EC.testFlags             16

#define I_EC.lastError             17
#define I_EC.dllErrors             18        // TODO: noch nicht implementiert
#define I_EC.dllErrorsSize         19        // TODO: noch nicht implementiert
#define I_EC.logging               20        // TODO: auf LOG_LEVEL umstellen
#define I_EC.lpLogFile             21        // TODO: im Struct speichern


// Getter
int    ec.hThreadId            (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.hThreadId         ]);                            EXECUTION_CONTEXT.toStr(ec); }
int    ec.ProgramId            (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.programId         ]);                            EXECUTION_CONTEXT.toStr(ec); }
int    ec.ProgramType          (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.programType       ]);                            EXECUTION_CONTEXT.toStr(ec); }
int    ec.lpProgramName        (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.lpProgramName     ]);                            EXECUTION_CONTEXT.toStr(ec); }
string ec.ProgramName          (/*EXECUTION_CONTEXT*/int ec[]                                ) { return(GetString(ec[I_EC.lpProgramName     ]));                           EXECUTION_CONTEXT.toStr(ec); }
int    ec.LaunchType           (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.launchType        ]);                            EXECUTION_CONTEXT.toStr(ec); }
int    ec.lpSuperContext       (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.lpSuperContext    ]);                            EXECUTION_CONTEXT.toStr(ec); }
int    ec.SuperContext         (/*EXECUTION_CONTEXT*/int ec[], /*EXECUTION_CONTEXT*/int sec[]) {
   if (ArrayDimension(sec) != 1)        return(catch("ec.SuperContext(1)  too many dimensions of parameter sec = "+ ArrayDimension(sec), ERR_INCOMPATIBLE_ARRAYS));
   if (ArraySize(sec) != EXECUTION_CONTEXT.intSize)
      ArrayResize(sec, EXECUTION_CONTEXT.intSize);
   int lpSuperContext = ec.lpSuperContext(ec);
   if (!lpSuperContext) ArrayInitialize(sec, 0);
   else                 CopyMemory(lpSuperContext, GetBufferAddress(sec), EXECUTION_CONTEXT.size);
   return(catch("ec.SuperContext(2)"));                                                                                                                                    EXECUTION_CONTEXT.toStr(ec);
}
int    ec.InitFlags            (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.initFlags         ]);                            EXECUTION_CONTEXT.toStr(ec); }
int    ec.DeinitFlags          (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.deinitFlags       ]);                            EXECUTION_CONTEXT.toStr(ec); }
int    ec.RootFunction         (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.rootFunction      ]);                            EXECUTION_CONTEXT.toStr(ec); }
int    ec.UninitializeReason   (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.uninitializeReason]);                            EXECUTION_CONTEXT.toStr(ec); }
int    ec.hChartWindow         (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.hChartWindow      ]);                            EXECUTION_CONTEXT.toStr(ec); }
int    ec.hChart               (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.hChart            ]);                            EXECUTION_CONTEXT.toStr(ec); }
int    ec.TestFlags            (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.testFlags         ]);                            EXECUTION_CONTEXT.toStr(ec); }
int    ec.LastError            (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.lastError         ]);                            EXECUTION_CONTEXT.toStr(ec); }
bool   ec.Logging              (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.logging           ] != 0);                       EXECUTION_CONTEXT.toStr(ec); }
int    ec.lpLogFile            (/*EXECUTION_CONTEXT*/int ec[]                                ) {           return(ec[I_EC.lpLogFile         ]);                            EXECUTION_CONTEXT.toStr(ec); }
string ec.LogFile              (/*EXECUTION_CONTEXT*/int ec[]                                ) { return(GetString(ec[I_EC.lpLogFile         ]));                           EXECUTION_CONTEXT.toStr(ec); }


// Setter
//     ec.setHThreadId(): ohne MQL-Setter
//     ec.setProgramId(): ohne MQL-Setter
int    ec.setProgramType       (/*EXECUTION_CONTEXT*/int &ec[], int    type              ) { ec[I_EC.programType       ] = type;               return(type              ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setLpProgramName     (/*EXECUTION_CONTEXT*/int &ec[], int    lpName            ) {
   if (lpName < MIN_VALID_POINTER) return(!catch("ec.setLpProgramName(1)  invalid parameter lpName = 0x"+ IntToHexStr(lpName) +" (not a valid pointer)", ERR_INVALID_POINTER));
                                                                                             ec[I_EC.lpProgramName     ] = lpName;             return(lpName            ); EXECUTION_CONTEXT.toStr(ec); }
string ec.setProgramName       (/*EXECUTION_CONTEXT*/int &ec[], string name              ) {
   if (!StringLen(name))           return(_EMPTY_STR(catch("ec.setProgramName(1)  invalid parameter name = "+ StringToStr(name), ERR_INVALID_PARAMETER)));
   if (StringLen(name) > MAX_PATH) return(_EMPTY_STR(catch("ec.setProgramName(2)  illegal parameter name = \""+ name +"\" (max "+ MAX_PATH +" chars)", ERR_TOO_LONG_STRING)));
   int lpName = ec.lpProgramName(ec);
   if (!lpName)                    return(_EMPTY_STR(catch("ec.setProgramName(3)  no memory allocated for string name (lpName = NULL)", ERR_RUNTIME_ERROR)));
   CopyMemory(GetStringAddress(name), lpName, StringLen(name)+1); /*terminierendes <NUL> wird mitkopiert*/                                     return(name              ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setLaunchType        (/*EXECUTION_CONTEXT*/int &ec[], int    type              ) { ec[I_EC.launchType        ] = type;               return(type              ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setLpSuperContext    (/*EXECUTION_CONTEXT*/int &ec[], int    lpSuperContext    ) { ec[I_EC.lpSuperContext    ] = lpSuperContext;     return(lpSuperContext    ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setInitFlags         (/*EXECUTION_CONTEXT*/int &ec[], int    initFlags         ) { ec[I_EC.initFlags         ] = initFlags;          return(initFlags         ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setDeinitFlags       (/*EXECUTION_CONTEXT*/int &ec[], int    deinitFlags       ) { ec[I_EC.deinitFlags       ] = deinitFlags;        return(deinitFlags       ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setRootFunction      (/*EXECUTION_CONTEXT*/int &ec[], int    rootFunction      ) { ec[I_EC.rootFunction      ] = rootFunction;       return(rootFunction      ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setUninitializeReason(/*EXECUTION_CONTEXT*/int &ec[], int    uninitializeReason) { ec[I_EC.uninitializeReason] = uninitializeReason; return(uninitializeReason); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setHChartWindow      (/*EXECUTION_CONTEXT*/int &ec[], int    hChartWindow      ) { ec[I_EC.hChartWindow      ] = hChartWindow;       return(hChartWindow      ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setHChart            (/*EXECUTION_CONTEXT*/int &ec[], int    hChart            ) { ec[I_EC.hChart            ] = hChart;             return(hChart            ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setTestFlags         (/*EXECUTION_CONTEXT*/int &ec[], int    testFlags         ) { ec[I_EC.testFlags         ] = testFlags;          return(testFlags         ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setLastError         (/*EXECUTION_CONTEXT*/int &ec[], int    lastError         ) { ec[I_EC.lastError         ] = lastError;
   int lpSuperContext = ec.lpSuperContext(ec);     // Fehler immer auch im SuperContext setzen
   if (lpSuperContext != 0) CopyMemory(GetBufferAddress(ec)+I_EC.lastError*4, lpSuperContext+I_EC.lastError*4, 4);                             return(lastError         ); EXECUTION_CONTEXT.toStr(ec);
}
bool   ec.setLogging           (/*EXECUTION_CONTEXT*/int &ec[], bool   logging           ) { ec[I_EC.logging           ] = logging != 0;       return(logging != 0      ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setLpLogFile         (/*EXECUTION_CONTEXT*/int &ec[], int    lpLogFile         ) {
   if (lpLogFile < MIN_VALID_POINTER) return(!catch("ec.setLpLogFile(1)  invalid parameter lpLogFile = 0x"+ IntToHexStr(lpLogFile) +" (not a valid pointer)", ERR_INVALID_POINTER));
                                                                                             ec[I_EC.lpLogFile         ] = lpLogFile;          return(lpLogFile         ); EXECUTION_CONTEXT.toStr(ec); }
string ec.setLogFile           (/*EXECUTION_CONTEXT*/int &ec[], string logFile           ) {
   if (!StringLen(logFile))           return(_EMPTY_STR(catch("ec.setLogFile(1)  invalid parameter logFile = "+ StringToStr(logFile), ERR_INVALID_PARAMETER)));
   if (StringLen(logFile) > MAX_PATH) return(_EMPTY_STR(catch("ec.setLogFile(2)  illegal parameter logFile = \""+ logFile +"\" (max. "+ MAX_PATH +" chars)", ERR_TOO_LONG_STRING)));
   int lpLogFile = ec.lpLogFile(ec);
   if (!lpLogFile)                    return(_EMPTY_STR(catch("ec.setLogFile(3)  no memory allocated for string logfile (lpLogFile = NULL)", ERR_RUNTIME_ERROR)));
   CopyMemory(GetStringAddress(logFile), lpLogFile, StringLen(logFile)+1); /*terminierendes <NUL> wird mitkopiert*/                            return(logFile           ); EXECUTION_CONTEXT.toStr(ec);
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

   string result = StringConcatenate("{hThreadId="         ,                         ec.hThreadId         (ec),
                                    ", programId="         ,                         ec.ProgramId         (ec),
                                    ", programType="       ,         ModuleTypeToStr(ec.ProgramType       (ec)),
                                    ", programName="       ,             StringToStr(ec.ProgramName       (ec)),
                                    ", launchType="        ,                         ec.LaunchType        (ec),
                                    ", superContext="      ,               ifString(!ec.lpSuperContext    (ec), "0", "0x"+ IntToHexStr(ec.lpSuperContext(ec))),
                                    ", initFlags="         ,          InitFlagsToStr(ec.InitFlags         (ec)),
                                    ", deinitFlags="       ,        DeinitFlagsToStr(ec.DeinitFlags       (ec)),
                                    ", rootFunction="      ,       RootFunctionToStr(ec.RootFunction      (ec)),
                                    ", uninitializeReason=", UninitializeReasonToStr(ec.UninitializeReason(ec)),
                                    ", hChartWindow="      ,               ifString(!ec.hChartWindow      (ec), "0", "0x"+ IntToHexStr(ec.hChartWindow  (ec))),
                                    ", hChart="            ,               ifString(!ec.hChart            (ec), "0", "0x"+ IntToHexStr(ec.hChart        (ec))),
                                    ", testFlags="         ,          TestFlagsToStr(ec.TestFlags         (ec)),
                                    ", lastError="         ,              ErrorToStr(ec.LastError         (ec)),
                                    ", logging="           ,               BoolToStr(ec.Logging           (ec)),
                                    ", logFile="           ,             StringToStr(ec.LogFile           (ec)), "}");
   if (outputDebug)
      debug("EXECUTION_CONTEXT.toStr()  "+ result);

   catch("EXECUTION_CONTEXT.toStr(3)");
   return(result);


   // Dummy-Calls: unterdrücken unnütze Compilerwarnungen
   ec.hThreadId         (ec    );
   ec.ProgramId         (ec    );
   ec.ProgramType       (ec    ); ec.setProgramType       (ec, NULL);
   ec.lpProgramName     (ec    ); ec.setLpProgramName     (ec, NULL);
   ec.ProgramName       (ec    ); ec.setProgramName       (ec, NULL);
   ec.LaunchType        (ec    ); ec.setLaunchType        (ec, NULL);
   ec.lpSuperContext    (ec    ); ec.setLpSuperContext    (ec, NULL);
   ec.SuperContext      (ec, ec);
   ec.InitFlags         (ec    ); ec.setInitFlags         (ec, NULL);
   ec.DeinitFlags       (ec    ); ec.setDeinitFlags       (ec, NULL);
   ec.RootFunction      (ec    ); ec.setRootFunction      (ec, NULL);
   ec.UninitializeReason(ec    ); ec.setUninitializeReason(ec, NULL);
   ec.hChartWindow      (ec    ); ec.setHChartWindow      (ec, NULL);
   ec.hChart            (ec    ); ec.setHChart            (ec, NULL);
   ec.TestFlags         (ec    ); ec.setTestFlags         (ec, NULL);
   ec.LastError         (ec    ); ec.setLastError         (ec, NULL);
   ec.Logging           (ec    ); ec.setLogging           (ec, NULL);
   ec.lpLogFile         (ec    ); ec.setLpLogFile         (ec, NULL);
   ec.LogFile           (ec    ); ec.setLogFile           (ec, NULL);
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

   if (lpContext <= 0) return(_EMPTY_STR(catch("lpEXECUTION_CONTEXT.toStr(1)  invalid parameter lpContext = 0x"+ IntToHexStr(lpContext) +" (not a valid pointer)", ERR_INVALID_POINTER)));
   int tmp[EXECUTION_CONTEXT.intSize];
   CopyMemory(lpContext, GetBufferAddress(tmp), EXECUTION_CONTEXT.size);

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
   int    GetBufferAddress(int buffer[]);
   int    GetStringAddress(string value);
   string GetString(int address);
   string IntToHexStr(int integer);
#import


// --------------------------------------------------------------------------------------------------------------------------------------------------


//#import "struct.EXECUTION_CONTEXT.ex4"
//   int    ec.hThreadId            (/*EXECUTION_CONTEXT*/int ec[]                                );
//   int    ec.ProgramId            (/*EXECUTION_CONTEXT*/int ec[]                                );
//   int    ec.ProgramType          (/*EXECUTION_CONTEXT*/int ec[]                                );
//   int    ec.lpProgramName        (/*EXECUTION_CONTEXT*/int ec[]                                );
//   string ec.ProgramName          (/*EXECUTION_CONTEXT*/int ec[]                                );
//   int    ec.LaunchType           (/*EXECUTION_CONTEXT*/int ec[]                                );
//   int    ec.lpSuperContext       (/*EXECUTION_CONTEXT*/int ec[]                                );
//   int    ec.SuperContext         (/*EXECUTION_CONTEXT*/int ec[], /*EXECUTION_CONTEXT*/int sec[]);
//   int    ec.InitFlags            (/*EXECUTION_CONTEXT*/int ec[]                                );
//   int    ec.DeinitFlags          (/*EXECUTION_CONTEXT*/int ec[]                                );
//   int    ec.RootFunction         (/*EXECUTION_CONTEXT*/int ec[]                                );
//   int    ec.UninitializeReason   (/*EXECUTION_CONTEXT*/int ec[]                                );
//   int    ec.hChartWindow         (/*EXECUTION_CONTEXT*/int ec[]                                );
//   int    ec.hChart               (/*EXECUTION_CONTEXT*/int ec[]                                );
//   int    ec.TestFlags            (/*EXECUTION_CONTEXT*/int ec[]                                );
//   int    ec.LastError            (/*EXECUTION_CONTEXT*/int ec[]                                );
//   bool   ec.Logging              (/*EXECUTION_CONTEXT*/int ec[]                                );
//   int    ec.lpLogFile            (/*EXECUTION_CONTEXT*/int ec[]                                );
//   string ec.LogFile              (/*EXECUTION_CONTEXT*/int ec[]                                );

//   int    ec.setProgramType       (/*EXECUTION_CONTEXT*/int ec[], int    type              );
//   int    ec.setLpProgramName     (/*EXECUTION_CONTEXT*/int ec[], int    lpName            );
//   string ec.setProgramName       (/*EXECUTION_CONTEXT*/int ec[], string name              );
//   int    ec.setLaunchType        (/*EXECUTION_CONTEXT*/int ec[], int    type              );
//   int    ec.setLpSuperContext    (/*EXECUTION_CONTEXT*/int ec[], int    lpSuperContext    );
//   int    ec.setInitFlags         (/*EXECUTION_CONTEXT*/int ec[], int    initFlags         );
//   int    ec.setDeinitFlags       (/*EXECUTION_CONTEXT*/int ec[], int    deinitFlags       );
//   int    ec.setRootFunction      (/*EXECUTION_CONTEXT*/int ec[], int    rootFunction      );
//   int    ec.setUninitializeReason(/*EXECUTION_CONTEXT*/int ec[], int    uninitializeReason);
//   int    ec.setHChartWindow      (/*EXECUTION_CONTEXT*/int ec[], int    hChartWindow      );
//   int    ec.setHChart            (/*EXECUTION_CONTEXT*/int ec[], int    hChart            );
//   int    ec.setTestFlags         (/*EXECUTION_CONTEXT*/int ec[], int    testFlags         );
//   int    ec.setLastError         (/*EXECUTION_CONTEXT*/int ec[], int    lastError         );
//   bool   ec.setLogging           (/*EXECUTION_CONTEXT*/int ec[], bool   logging           );
//   int    ec.setLpLogFile         (/*EXECUTION_CONTEXT*/int ec[], int    lpLogFile         );
//   string ec.setLogFile           (/*EXECUTION_CONTEXT*/int ec[], string logFile           );

//   string   EXECUTION_CONTEXT.toStr (/*EXECUTION_CONTEXT*/int ec[], bool outputDebug);
//   string lpEXECUTION_CONTEXT.toStr(int lpContext, bool outputDebug);
//#import
