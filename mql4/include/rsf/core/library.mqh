/**
 * Framework struct EXECUTION_CONTEXT
 *
 * Ausf�hrungskontext von MQL-Programmen zur Kommunikation zwischen MQL und DLL
 *
 * @link  https://github.com/rosasurfer/mt4-expander/blob/master/header/struct/rsf/ExecutionContext.h
 *
 * Im Indikator gibt es w�hrend eines init()-Cycles in der Zeitspanne vom Verlassen von Indicator::deinit() bis zum Wieder-
 * eintritt in Indicator::init() keinen g�ltigen Hauptmodulkontext. Der alte Speicherblock wird sofort freigegeben, sp�ter
 * wird ein neuer alloziiert. W�hrend dieser Zeitspanne wird der init()-Cycle von bereits geladenen Libraries durchgef�hrt,
 * also die Funktionen Library::deinit() und Library::init() aufgerufen. In Indikatoren geladene Libraries d�rfen daher
 * w�hrend ihres init()-Cycles nicht auf den alten, bereits ung�ltigen Hauptmodulkontext zugreifen (weder lesend noch
 * schreibend).
 *
 * TODO:
 *  - indicators loaded in a library must use a temporary copy of the main module context for their init() cycles
 *  - integrate __STATUS_OFF and __STATUS_OFF.reason
 */
int __lpSuperContext = NULL;


/**
 * Initialization
 *
 * @return int - error status
 */
int init() {
   int error = SyncLibContext_init(__ExecutionContext, UninitializeReason(), SumInts(__InitFlags), SumInts(__DeinitFlags), WindowExpertName(), Symbol(), Period(), Digits, Point, IsTesting(), IsOptimization());
   if (IsError(error)) return(error);

   // initialize global vars
   __lpSuperContext =  __ExecutionContext[EC.superContext];
   __isSuperContext = (__lpSuperContext != 0);
   __isChart        = (__ExecutionContext[EC.chart] != 0);
   __isTesting      = (__ExecutionContext[EC.testing] || IsTesting());

   if (__isTesting && IsIndicator()) {
      int initReason = ProgramInitReason();
      if (initReason == IR_TEMPLATE && !__isChart) {        // an indicator in template "Tester.tpl" with VisualMode=off
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = last_error;
         return(last_error);
      }
      if (initReason == IR_PROGRAM_AFTERTEST) {             // an indicator loaded by iCustom() after the test finished
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = last_error;
         return(last_error);
      }
   }

   int digits  = MathMax(Digits, 2);                        // treat Digits=1 as 2 (for some indices)
   HalfPoint   = Point/2;
   PipDigits   = digits & (~1);
   Pip         = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits);
   PriceFormat = ",'R."+ PipDigits + ifString(digits==PipDigits, "", "'");    // TODO: in library::deinit() global strings are already destroyed

   if (digits > 2 || Close[0] < 20) {
      pUnit   = Pip;
      pDigits = 1;                                          // always represent pips with subpips
      spUnit  = "pip";
   }
   else {
      pUnit   = 1.00;
      pDigits = 2;
      spUnit  = "point";
   }
   pUnitFormat = ",'R."+ pDigits;

   prev_error = NO_ERROR;
   last_error = NO_ERROR;

   // don't use MathLog() as in terminals (509 < build && build < 603) it fails to produce NaN/-INF
   INF = Math_INF();                                        // positive infinity
   NaN = INF-INF;                                           // not-a-number

   // EA-Tasks
   if (IsExpert()) {
      OrderSelect(0, SELECT_BY_TICKET);                     // Orderkontext der Library wegen Bug ausdr�cklich zur�cksetzen (siehe MQL.doc)
      error = GetLastError();
      if (error && error!=ERR_NO_TICKET_SELECTED) return(catch("init(1)", error));

      if (__isTesting) {                                    // Im Tester globale Variablen der Library zur�cksetzen.
         ArrayResize(__orderStack, 0);                      // in stdfunctions global definierte Variable
         onLibraryInit();
      }
   }

   onInit();
   return(catch("init(2)"));
}


/**
 * Dummy-Startfunktion f�r Libraries. F�r den Compiler build 224 mu� ab einer unbestimmten Komplexit�t der Library eine
 * start()-Funktion existieren, damit die init()-Funktion aufgerufen wird.
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
 * TODO: Bei VisualMode=Off und regul�rem Testende (Testperiode zu Ende) bricht das Terminal komplexere Expert::deinit()
 *       Funktionen verfr�ht und mitten im Code ab (nicht erst nach 2.5 Sekunden).
 *       - Pr�fen, ob in diesem Fall Library::deinit() noch zuverl�ssig ausgef�hrt wird.
 *       - Beachten, da� die Library in diesem Fall bei Start des n�chsten Tests einen Init-Cycle durchf�hrt.
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
 * Gibt die ID des aktuellen Deinit()-Szenarios zur�ck. Kann nur in deinit() aufgerufen werden.
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
