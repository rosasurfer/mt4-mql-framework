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
int    ec.Signature            (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 0]);      }
int    ec.lpName               (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 1]);      }
string ec.Name                 (/*EXECUTION_CONTEXT*/int ec[]                                ) { return(GetStringValue(ec[ 1]));     }
int    ec.Type                 (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 2]);      }
int    ec.ChartProperties      (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 3]);      }
int    ec.lpSuperContext       (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 4]);      }
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
   return(catch("ec.SuperContext(3)"));
}
int    ec.InitFlags            (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 5]);      }
int    ec.DeinitFlags          (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 6]);      }
int    ec.UninitializeReason   (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 7]);      }
int    ec.Whereami             (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 8]);      }
bool   ec.Logging              (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[ 9] != 0); }
int    ec.lpLogFile            (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[10]);      }
string ec.LogFile              (/*EXECUTION_CONTEXT*/int ec[]                                ) { return(GetStringValue(ec[10]));     }
int    ec.LastError            (/*EXECUTION_CONTEXT*/int ec[]                                ) {                return(ec[11]);      }


// Setter
int    ec.setSignature         (/*EXECUTION_CONTEXT*/int &ec[], int    signature         ) { ec[ 0] = signature;          return(signature         ); }
int    ec.setLpName            (/*EXECUTION_CONTEXT*/int &ec[], int    lpName            ) { ec[ 1] = lpName;             return(lpName            ); }
string ec.setName              (/*EXECUTION_CONTEXT*/int &ec[], string name              ) {
   if (!StringLen(name))           return(_empty(catch("ec.setName(1)   invalid parameter name = "+ StringToStr(name), ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (StringLen(name) > MAX_PATH) return(_empty(catch("ec.setName(2)   illegal parameter name = \""+ name +"\" (max "+ MAX_PATH +" chars)", ERR_TOO_LONG_STRING)));
   int lpName = ec.lpName(ec);
   if (!lpName)                    return(_empty(catch("ec.setName(3)   no memory allocated for string name (lpName = NULL)", ERR_RUNTIME_ERROR)));
   CopyMemory(GetStringAddress(name), lpName, StringLen(name)+1); /*terminierendes <NUL> wird mitkopiert*/                return(name              ); }
int    ec.setType              (/*EXECUTION_CONTEXT*/int &ec[], int    type              ) { ec[ 2] = type;               return(type              ); }
int    ec.setChartProperties   (/*EXECUTION_CONTEXT*/int &ec[], int    chartProperties   ) { ec[ 3] = chartProperties;    return(chartProperties   ); }
int    ec.setLpSuperContext    (/*EXECUTION_CONTEXT*/int &ec[], int    lpSuperContext    ) { ec[ 4] = lpSuperContext;     return(lpSuperContext    ); }
int    ec.setInitFlags         (/*EXECUTION_CONTEXT*/int &ec[], int    initFlags         ) { ec[ 5] = initFlags;          return(initFlags         ); }
int    ec.setDeinitFlags       (/*EXECUTION_CONTEXT*/int &ec[], int    deinitFlags       ) { ec[ 6] = deinitFlags;        return(deinitFlags       ); }
int    ec.setUninitializeReason(/*EXECUTION_CONTEXT*/int &ec[], int    uninitializeReason) { ec[ 7] = uninitializeReason; return(uninitializeReason); }
int    ec.setWhereami          (/*EXECUTION_CONTEXT*/int &ec[], int    whereami          ) { ec[ 8] = whereami;           return(whereami          ); }
bool   ec.setLogging           (/*EXECUTION_CONTEXT*/int &ec[], bool   logging           ) { ec[ 9] = logging != 0;       return(logging != 0      ); }
int    ec.setLpLogFile         (/*EXECUTION_CONTEXT*/int &ec[], int    lpLogFile         ) { ec[10] = lpLogFile;          return(lpLogFile         ); }
string ec.setLogFile           (/*EXECUTION_CONTEXT*/int &ec[], string logFile           ) {
   if (!StringLen(logFile))           return(_empty(catch("ec.setLogFile(1)   invalid parameter logFile = "+ StringToStr(logFile), ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (StringLen(logFile) > MAX_PATH) return(_empty(catch("ec.setLogFile(2)   illegal parameter logFile = \""+ logFile +"\" (max. "+ MAX_PATH +" chars)", ERR_TOO_LONG_STRING)));
   int lpLogFile = ec.lpLogFile(ec);
   if (!lpLogFile)                    return(_empty(catch("ec.setLogFile(3)   no memory allocated for string logfile (lpLogFile = NULL)", ERR_RUNTIME_ERROR)));
   CopyMemory(GetStringAddress(logFile), lpLogFile, StringLen(logFile)+1); /*terminierendes <NUL> wird mitkopiert*/       return(logFile           ); }
int    ec.setLastError         (/*EXECUTION_CONTEXT*/int &ec[], int    lastError         ) {
   ec[11] = lastError;
   int lpSuperContext = ec.lpSuperContext(ec);
   if (lpSuperContext != 0)
      CopyMemory(ec.Signature(ec)+11*4, lpSuperContext+11*4, 4);     // Fehler immer auch im SuperContext setzen
   return(lastError);
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
          result = result          +", type="+                                       ec.Type              (ec);   // ModuleTypeToStr() gibt für fehlerhafte ID Leerstring zurück
   else   result = result          +", type="+                       ModuleTypeToStr(ec.Type              (ec));
          result = StringConcatenate(result,
                                    ", chartProperties="   ,    ChartPropertiesToStr(ec.ChartProperties   (ec)),
                                    ", superContext="      ,               ifString(!ec.lpSuperContext    (ec), "0", "0x"+ IntToHexStr(ec.lpSuperContext(ec))),
                                    ", initFlags="         ,          InitFlagsToStr(ec.InitFlags         (ec)),
                                    ", deinitFlags="       ,        DeinitFlagsToStr(ec.DeinitFlags       (ec)),
                                    ", uninitializeReason=", UninitializeReasonToStr(ec.UninitializeReason(ec)));
   if (!ec.Whereami(ec))
          result = result          +", whereami="+                                   ec.Whereami          (ec);   // __whereamiToStr() löst für fehlerhafte ID Fehler aus
   else   result = result          +", whereami="+                   __whereamiToStr(ec.Whereami          (ec));
          result = StringConcatenate(result,
                                    ", logging="           ,               BoolToStr(ec.Logging           (ec)),
                                    ", logFile=\""         ,                         ec.LogFile           (ec), "\"",
                                    ", lastError="         ,              ErrorToStr(ec.LastError         (ec)), "}");
   if (debugOutput)
      debug("EXECUTION_CONTEXT.toStr()   "+ result);

   catch("EXECUTION_CONTEXT.toStr(3)");
   return(result);
}
