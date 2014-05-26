/**
 * MQL structure EXECUTION_CONTEXT
 *
 *                                    size         offset
 * struct EXECUTION_CONTEXT {         ----         ------
 *    int    signature;                  4      => ec[ 0]      // Signatur                           (konstant)   => Validierung des Speicherblocks
 *    LPTSTR lpName;                     4      => ec[ 1]      // Zeiger auf Programmnamen           (konstant)   => wie heiße ich
 *    int    type;                       4      => ec[ 2]      // Programmtyp                        (konstant)   => was bin ich
 *    int    chartProperties;            4      => ec[ 3]      // Chart-Flags: Offline|Chart         (konstant)   => wie sehe ich aus
 *    LPTR   lpSuperContext;             4      => ec[ 4]      // übergeordneter Execution-Context   (konstant)   => wie wurde ich geladen
 *    int    initFlags;                  4      => ec[ 5]      // init-Flags                         (konstant)   => wie werde ich initialisiert
 *    int    deinitFlags;                4      => ec[ 6]      // deinit-Flags                       (konstant)   => wie werde ich deinitialisiert
 *    int    uninitializeReason;         4      => ec[ 7]      // letzter Uninitialize-Reason        (variabel)   => woher komme ich
 *    int    whereami;                   4      => ec[ 8]      // MQL-Rootfunktion des Programms     (variabel)   => wo bin ich
 *    BOOL   logging;                    4      => ec[ 9]      // Logstatus                          (konstant)   => wie verhalte ich mich
 *    LPTSTR lpLogFile;                  4      => ec[10]      // Zeiger auf Pfad+Namen der Logdatei (konstant)   => wie verhalte ich mich
 *    int    lastError;                  4      => ec[11]      // letzter aufgetretener Fehler       (variabel)   => Fehlerrückmeldung
 * } ec;                              = 48 byte = int[12]
 */

// Getter
int    ec.Signature            (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 0]);                       EXECUTION_CONTEXT.toStr(ec); }
int    ec.lpName               (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 1]);                       EXECUTION_CONTEXT.toStr(ec); }
string ec.Name                 (/*EXECUTION_CONTEXT*/int ec[]                                ) { return(GetStringValue(ec[ 1]));                      EXECUTION_CONTEXT.toStr(ec); }
int    ec.Type                 (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 2]);                       EXECUTION_CONTEXT.toStr(ec); }
int    ec.ChartProperties      (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 3]);                       EXECUTION_CONTEXT.toStr(ec); }
int    ec.lpSuperContext       (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 4]);                       EXECUTION_CONTEXT.toStr(ec); }
int    ec.SuperContext         (/*EXECUTION_CONTEXT*/int ec[], /*EXECUTION_CONTEXT*/int sec[]) {
   if (ArrayDimension(sec) != 1)               return(catch("ec.SuperContext(1)   too many dimensions of parameter sec = "+ ArrayDimension(sec), ERR_INCOMPATIBLE_ARRAYS));
   if (ArraySize(sec) != EXECUTION_CONTEXT.intSize)
      ArrayResize(sec, EXECUTION_CONTEXT.intSize);

   int lpSuperContext = ec.lpSuperContext(ec);
   if (!lpSuperContext) {
      ArrayInitialize(sec, 0);
   }
   else {
      CopyMemory(lpSuperContext, GetBufferAddress(sec), EXECUTION_CONTEXT.size);
      // primitive Zeigervalidierung, es gilt: PTR==*PTR (der Wert des Zeigers ist an der Adresse selbst gespeichert)
      if (ec.Signature(sec) != lpSuperContext) return(catch("ec.SuperContext(2)   invalid super-EXECUTION_CONTEXT found at address 0x"+ IntToHexStr(lpSuperContext), ERR_RUNTIME_ERROR));
   }
   return(catch("ec.SuperContext(3)"));                                                                                                               EXECUTION_CONTEXT.toStr(ec);
}
int    ec.InitFlags            (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 5]);                       EXECUTION_CONTEXT.toStr(ec); }
int    ec.DeinitFlags          (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 6]);                       EXECUTION_CONTEXT.toStr(ec); }
int    ec.UninitializeReason   (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 7]);                       EXECUTION_CONTEXT.toStr(ec); }
int    ec.Whereami             (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 8]);                       EXECUTION_CONTEXT.toStr(ec); }
bool   ec.Logging              (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 9] != 0);                  EXECUTION_CONTEXT.toStr(ec); }
int    ec.lpLogFile            (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[10]);                       EXECUTION_CONTEXT.toStr(ec); }
string ec.LogFile              (/*EXECUTION_CONTEXT*/int ec[]                                ) { return(GetStringValue(ec[10]));                      EXECUTION_CONTEXT.toStr(ec); }
int    ec.LastError            (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[11]);                       EXECUTION_CONTEXT.toStr(ec); }


// Setter
int    ec.setSignature         (/*EXECUTION_CONTEXT*/int &ec[], int    signature         ) { ec[ 0] = signature;          return(signature         ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setLpName            (/*EXECUTION_CONTEXT*/int &ec[], int    lpName            ) { ec[ 1] = lpName;             return(lpName            ); EXECUTION_CONTEXT.toStr(ec); }
string ec.setName              (/*EXECUTION_CONTEXT*/int &ec[], string name              ) {
   if (!StringLen(name))           return(_empty(catch("ec.setName(1)   invalid parameter name = "+ StringToStr(name), ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (StringLen(name) > MAX_PATH) return(_empty(catch("ec.setName(2)   illegal parameter name = \""+ name +"\" (max "+ MAX_PATH +" chars)", ERR_TOO_LONG_STRING)));
   int lpName = ec.lpName(ec);
   if (!lpName)                    return(_empty(catch("ec.setName(3)   no memory allocated for string name (lpName = NULL)", ERR_RUNTIME_ERROR)));
   CopyMemory(GetStringAddress(name), lpName, StringLen(name)+1); /*terminierendes <NUL> wird mitkopiert*/                return(name              ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setType              (/*EXECUTION_CONTEXT*/int &ec[], int    type              ) { ec[ 2] = type;               return(type              ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setChartProperties   (/*EXECUTION_CONTEXT*/int &ec[], int    chartProperties   ) { ec[ 3] = chartProperties;    return(chartProperties   ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setLpSuperContext    (/*EXECUTION_CONTEXT*/int &ec[], int    lpSuperContext    ) { ec[ 4] = lpSuperContext;     return(lpSuperContext    ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setInitFlags         (/*EXECUTION_CONTEXT*/int &ec[], int    initFlags         ) { ec[ 5] = initFlags;          return(initFlags         ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setDeinitFlags       (/*EXECUTION_CONTEXT*/int &ec[], int    deinitFlags       ) { ec[ 6] = deinitFlags;        return(deinitFlags       ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setUninitializeReason(/*EXECUTION_CONTEXT*/int &ec[], int    uninitializeReason) { ec[ 7] = uninitializeReason; return(uninitializeReason); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setWhereami          (/*EXECUTION_CONTEXT*/int &ec[], int    whereami          ) { ec[ 8] = whereami;           return(whereami          ); EXECUTION_CONTEXT.toStr(ec); }
bool   ec.setLogging           (/*EXECUTION_CONTEXT*/int &ec[], bool   logging           ) { ec[ 9] = logging != 0;       return(logging != 0      ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setLpLogFile         (/*EXECUTION_CONTEXT*/int &ec[], int    lpLogFile         ) { ec[10] = lpLogFile;          return(lpLogFile         ); EXECUTION_CONTEXT.toStr(ec); }
string ec.setLogFile           (/*EXECUTION_CONTEXT*/int &ec[], string logFile           ) {
   if (!StringLen(logFile))           return(_empty(catch("ec.setLogFile(1)   invalid parameter logFile = "+ StringToStr(logFile), ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (StringLen(logFile) > MAX_PATH) return(_empty(catch("ec.setLogFile(2)   illegal parameter logFile = \""+ logFile +"\" (max. "+ MAX_PATH +" chars)", ERR_TOO_LONG_STRING)));
   int lpLogFile = ec.lpLogFile(ec);
   if (!lpLogFile)                    return(_empty(catch("ec.setLogFile(3)   no memory allocated for string logfile (lpLogFile = NULL)", ERR_RUNTIME_ERROR)));
   CopyMemory(GetStringAddress(logFile), lpLogFile, StringLen(logFile)+1); /*terminierendes <NUL> wird mitkopiert*/       return(logFile           ); EXECUTION_CONTEXT.toStr(ec); }
int    ec.setLastError         (/*EXECUTION_CONTEXT*/int &ec[], int    lastError         ) {
   ec[11] = lastError;
   int lpSuperContext = ec.lpSuperContext(ec);
   if (lpSuperContext != 0)
      CopyMemory(ec.Signature(ec)+11*4, lpSuperContext+11*4, 4);     // Fehler immer auch im SuperContext setzen
   return(lastError);                                                                                                                                 EXECUTION_CONTEXT.toStr(ec);
}


/**
 * Gibt die lesbare Repräsentation eines EXECUTION_CONTEXT zurück.
 *
 * @param  int  ec[]        - EXECUTION_CONTEXT
 * @param  bool debugOutput - ob die Ausgabe zusätzlich zum Debugger geschickt werden soll (default: nein)
 *
 * @return string
 */
string EXECUTION_CONTEXT.toStr(/*EXECUTION_CONTEXT*/int ec[], bool debugOutput=false) {
   if (ArrayDimension(ec) > 1)                     return(_empty(catch("EXECUTION_CONTEXT.toStr(1)   too many dimensions of parameter ec: "+ ArrayDimension(ec), ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (ArraySize(ec) != EXECUTION_CONTEXT.intSize) return(_empty(catch("EXECUTION_CONTEXT.toStr(2)   invalid size of parameter ec: "+ ArraySize(ec), ERR_INVALID_FUNCTION_PARAMVALUE)));

   string result = StringConcatenate("{signature="         ,               ifString(!ec.Signature         (ec), "0", "0x"+ IntToHexStr(ec.Signature(ec))),
                                    ", name=\""            ,                         ec.Name              (ec), "\"");
   if (!ec.Type(ec))
          result = result          +", type="+                                       ec.Type              (ec);   // ModuleTypeToStr() gibt für ungültige ID Leerstring zurück
   else   result = result          +", type="+                       ModuleTypeToStr(ec.Type              (ec));
          result = StringConcatenate(result,
                                    ", chartProperties="   ,    ChartPropertiesToStr(ec.ChartProperties   (ec)),
                                    ", superContext="      ,               ifString(!ec.lpSuperContext    (ec), "0", "0x"+ IntToHexStr(ec.lpSuperContext(ec))),
                                    ", initFlags="         ,          InitFlagsToStr(ec.InitFlags         (ec)),
                                    ", deinitFlags="       ,        DeinitFlagsToStr(ec.DeinitFlags       (ec)),
                                    ", uninitializeReason=", UninitializeReasonToStr(ec.UninitializeReason(ec)));
   if (!ec.Whereami(ec))
          result = result          +", whereami="+                                   ec.Whereami          (ec);   // __whereamiToStr() löst für ungültige ID Fehler aus
   else   result = result          +", whereami="+                   __whereamiToStr(ec.Whereami          (ec));
          result = StringConcatenate(result,
                                    ", logging="           ,               BoolToStr(ec.Logging           (ec)),
                                    ", logFile=\""         ,                         ec.LogFile           (ec), "\"",
                                    ", lastError="         ,              ErrorToStr(ec.LastError         (ec)), "}");
   if (debugOutput)
      debug("EXECUTION_CONTEXT.toStr()   "+ result);

   catch("EXECUTION_CONTEXT.toStr(3)");
   return(result);


   // unnütze Compilerwarnungen unterdrücken
   ec.Signature         (ec    ); ec.setSignature         (ec, NULL);
   ec.lpName            (ec    ); ec.setLpName            (ec, NULL);
   ec.Name              (ec    ); ec.setName              (ec, NULL);
   ec.Type              (ec    ); ec.setType              (ec, NULL);
   ec.ChartProperties   (ec    ); ec.setChartProperties   (ec, NULL);
   ec.lpSuperContext    (ec    ); ec.setLpSuperContext    (ec, NULL);
   ec.SuperContext      (ec, ec);
   ec.InitFlags         (ec    ); ec.setInitFlags         (ec, NULL);
   ec.DeinitFlags       (ec    ); ec.setDeinitFlags       (ec, NULL);
   ec.UninitializeReason(ec    ); ec.setUninitializeReason(ec, NULL);
   ec.Whereami          (ec    ); ec.setWhereami          (ec, NULL);
   ec.Logging           (ec    ); ec.setLogging           (ec, NULL);
   ec.lpLogFile         (ec    ); ec.setLpLogFile         (ec, NULL);
   ec.LogFile           (ec    ); ec.setLogFile           (ec, NULL);
   ec.LastError         (ec    ); ec.setLastError         (ec, NULL);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   string BoolToStr(bool value);
   string ChartPropertiesToStr(int flags);
   void   CopyMemory(int source, int destination, int bytes);
   string DeinitFlagsToStr(int flags);
   string ErrorToStr(int error);
   string InitFlagsToStr(int flags);
   string IntToHexStr(int integer);
   string ModuleTypeToStr(int type);
   string StringToStr(string value);
   string UninitializeReasonToStr(int reason);
   string __whereamiToStr(int id);

#import "MetaQuotes2.ex4"
   int    GetBufferAddress(int buffer[]);

#import "MetaQuotes5.ex4"
   int    GetStringAddress(string value);

#import "MetaQuotes.dll"
   string GetStringValue(int address);
#import
