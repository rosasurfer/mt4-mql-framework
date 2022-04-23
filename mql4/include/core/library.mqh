
int __lpSuperContext = NULL;


/**
 * Initialization
 *
 * @return int - error status
 */
int init() {
   int error = SyncLibContext_init(__ExecutionContext, UninitializeReason(), SumInts(__InitFlags), SumInts(__DeinitFlags), WindowExpertName(), Symbol(), Period(), Digits, Point, IsTesting(), IsOptimization());
   if (IsError(error)) return(error);

   // globale Variablen initialisieren
   __isChart         = (__ExecutionContext[EC.hChart] != 0);
   __lpSuperContext  = __ExecutionContext[EC.superContext];
   PipDigits         = Digits & (~1);                        SubPipDigits      = PipDigits+1;
   PipPoints         = MathRound(MathPow(10, Digits & 1));
   Pip               = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits);
   PipPriceFormat    = StringConcatenate(",'R.", PipDigits);                              // TODO: lost in deinit()
   SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");                            // ...
   PriceFormat       = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);    // ...
   prev_error        = NO_ERROR;
   last_error        = NO_ERROR;

   N_INF = MathLog(0);                                               // negative infinity
   P_INF = -N_INF;                                                   // positive infinity
   NaN   =  N_INF - N_INF;                                           // not-a-number

   // EA-Tasks
   if (IsExpert()) {
      OrderSelect(0, SELECT_BY_TICKET);                              // Orderkontext der Library wegen Bug ausdrücklich zurücksetzen (siehe MQL.doc)
      error = GetLastError();
      if (error && error!=ERR_NO_TICKET_SELECTED) return(catch("init(1)", error));

      if (IsTesting()) {                                             // Im Tester globale Variablen der Library zurücksetzen.
         ArrayResize(__orderStack, 0);                               // in stdfunctions global definierte Variable
         onLibraryInit();
      }
   }

   onInit();
   return(catch("init(2)"));
}


/**
 * Dummy-Startfunktion für Libraries. Für den Compiler build 224 muß ab einer unbestimmten Komplexität der Library eine start()-
 * Funktion existieren, damit die init()-Funktion aufgerufen wird.
 *
 * @return int - error status
 */
int start() {
   return(catch("start(1)", ERR_WRONG_JUMP));
}


/**
 * Deinitialisierung der Library.
 *
 * @return int - error status
 *
 *
 * TODO: Bei VisualMode=Off und regulärem Testende (Testperiode zu Ende) bricht das Terminal komplexere Expert::deinit()
 *       Funktionen verfrüht und mitten im Code ab (nicht erst nach 2.5 Sekunden).
 *       - Prüfen, ob in diesem Fall Library::deinit() noch zuverlässig ausgeführt wird.
 *       - Beachten, daß die Library in diesem Fall bei Start des nächsten Tests einen Init-Cycle durchführt.
 */
int deinit() {
   int error = SyncLibContext_deinit(__ExecutionContext, UninitializeReason());
   if (!error) {
      onDeinit();
      catch("deinit(1)");
   }
   return(error|last_error|LeaveContext(__ExecutionContext));
}


/**
 * Gibt die ID des aktuellen Deinit()-Szenarios zurück. Kann nur in deinit() aufgerufen werden.
 *
 * @return int - ID oder NULL, falls ein Fehler auftrat
 */
int DeinitReason() {
   return(!catch("DeinitReason(1)", ERR_NOT_IMPLEMENTED));
}


/**
 * Whether the current program is an expert.
 *
 * @return bool
 */
bool IsExpert() {
   return(__ExecutionContext[EC.programType] & MT_EXPERT != 0);
}


/**
 * Whether the current program is a script.
 *
 * @return bool
 */
bool IsScript() {
   return(__ExecutionContext[EC.programType] & MT_SCRIPT != 0);
}


/**
 * Whether the current program is an indicator.
 *
 * @return bool
 */
bool IsIndicator() {
   return(__ExecutionContext[EC.programType] & MT_INDICATOR != 0);
}


/**
 * Whether the current module is a library.
 *
 * @return bool
 */
bool IsLibrary() {
   return(true);
}


/**
 * Check and update the program's error status and activate the flag __STATUS_OFF accordingly.
 *
 * @param  string caller   - location identifier of the caller
 * @param  int    setError - error to enforce
 *
 * @return bool - whether the flag __STATUS_OFF is set
 */
bool CheckErrors(string caller, int setError = NULL) {
   // empty library stub
   return(false);
}


#import "rsfMT4Expander.dll"
   int SyncLibContext_init  (int ec[], int uninitReason, int initFlags, int deinitFlags, string name, string symbol, int timeframe, int digits, double point, int isTesting, int isOptimization);
   int SyncLibContext_deinit(int ec[], int uninitReason);
#import
