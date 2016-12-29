
int __TYPE__         = MT_LIBRARY;
int __lpSuperContext = NULL;


/**
 * Initialisierung der Library.
 *
 * @return int - Fehlerstatus
 */
int init() {
   // (1) Library-Context mit Hauptmodulkontext synchronisieren
   SyncLibContext_init(__ExecutionContext, UninitializeReason(), SumInts(__INIT_FLAGS__), SumInts(__DEINIT_FLAGS__), WindowExpertName(), Symbol(), Period(), IsOptimization());


   // (2) globale Variablen initialisieren
   __lpSuperContext =                   ec_lpSuperContext(__ExecutionContext);
   __TYPE__        |=                   ec_ProgramType   (__ExecutionContext);
   __NAME__         = StringConcatenate(ec_ProgramName   (__ExecutionContext), "::", WindowExpertName());
   __CHART          =             _bool(ec_hChart        (__ExecutionContext));
   __LOG            =                   ec_Logging       (__ExecutionContext);                        // TODO: noch dauerhaft falsch
   __LOG_CUSTOM     =          __LOG && ec_InitFlags     (__ExecutionContext) & INIT_CUSTOMLOG;       // TODO: noch dauerhaft falsch

   PipDigits        = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints        = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pip              = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat   = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat      = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);
   prev_error       = NO_ERROR;
   last_error       = NO_ERROR;


   // (3) EA-Tasks
   if (IsExpert()) {
      OrderSelect(0, SELECT_BY_TICKET);                              // Orderkontext der Library wegen Bug ausdrücklich zurücksetzen (siehe MQL.doc)

      if (IsTesting() && ec_InitCycle(__ExecutionContext)) {         // Bei Init-Cyle im Tester globale Variablen der Library zurücksetzen.
         ArrayResize(stack.orderSelections, 0);                      // in stdfunctions global definierte Variable
         Tester.ResetGlobalLibraryVars();
      }
   }

   onInit();
   return(catch("init(1)"));
}


/**
 * Dummy-Startfunktion für Libraries. Für den Compiler build 224 muß ab einer unbestimmten Komplexität der Library eine start()-
 * Funktion existieren, damit die init()-Funktion aufgerufen wird.
 *
 * @return int - Fehlerstatus
 */
int start() {
   return(catch("start(1)", ERR_WRONG_JUMP));
}


/**
 * Deinitialisierung der Library.
 *
 * @return int - Fehlerstatus
 *
 *
 * TODO: Bei VisualMode=Off und regulärem Testende (Testperiode zu Ende) bricht das Terminal komplexere Expert::deinit()
 *       Funktionen verfrüht und mitten im Code ab (nicht erst nach 2.5 Sekunden).
 *       - Prüfen, ob in diesem Fall Library::deinit() noch zuverlässig ausgeführt wird.
 *       - Beachten, daß die Library in diesem Fall bei Start des nächsten Tests einen Init-Cycle durchführt.
 */
int deinit() {
   SyncLibContext_deinit(__ExecutionContext, UninitializeReason());

   onDeinit();

   catch("deinit(1)");
   LeaveContext(__ExecutionContext);
   return(last_error);
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
 * Whether or not the current program is an expert.
 *
 * @return bool
 */
bool IsExpert() {
   return(__TYPE__ & MT_EXPERT != 0);
}


/**
 * Whether or not the current program is a script.
 *
 * @return bool
 */
bool IsScript() {
   return(__TYPE__ & MT_SCRIPT != 0);
}


/**
 * Whether or not the current program is an indicator.
 *
 * @return bool
 */
bool IsIndicator() {
   return(__TYPE__ & MT_INDICATOR != 0);
}


/**
 * Whether or not the current module is a library.
 *
 * @return bool
 */
bool IsLibrary() {
   return(true);
}


// ----------------------------------------------------------------------------------------------------------------------------


#import "Expander.dll"
   bool   ec_InitCycle     (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_InitFlags     (/*EXECUTION_CONTEXT*/int ec[]);
   bool   ec_Logging       (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_lpSuperContext(/*EXECUTION_CONTEXT*/int ec[]);
   string ec_ProgramName   (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_RootFunction  (/*EXECUTION_CONTEXT*/int ec[]);

   bool   SyncLibContext_init  (int ec[], int uninitReason, int initFlags, int deinitFlags, string name, string symbol, int period, int isOptimization);
   bool   SyncLibContext_deinit(int ec[], int uninitReason);
#import
