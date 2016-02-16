
int __TYPE__         = MT_LIBRARY;
int __lpSuperContext = NULL;


/**
 * Initialisierung der Library.
 *
 * @return int - Fehlerstatus
 */
int init() {
   prev_error = last_error;
   last_error = NO_ERROR;

   // !!! TODO: Wird in init() eine andere Library das erste Mal geladen, trifft sie im Indikator-init-Cycle u.U. auf einen zurückgesetzten Hautpkontext.
   //
   // !!! TODO: In Libraries, die vor Finalisierung des Hauptmodulkontexts geladen werden, sind die markierten (*) globalen Variablen dauerhaft falsch gesetzt.

   // (1) lokalen Context mit dem Hauptmodulkontext synchronisieren
   SyncLibExecutionContext(__ExecutionContext, WindowExpertName(), RF_INIT, Symbol(), Period());


   // (2) globale Variablen (re-)initialisieren
   __lpSuperContext =                   ec_lpSuperContext(__ExecutionContext);                              // (*)
   __TYPE__        |=                   ec_ProgramType   (__ExecutionContext);
   __NAME__         = StringConcatenate(ec_ProgramName   (__ExecutionContext), "::", WindowExpertName());
   __WHEREAMI__     =                   RF_INIT;
   __CHART          =                  (ec_hChart        (__ExecutionContext) != 0);                        // (*)
   __LOG            =                   ec_Logging       (__ExecutionContext);                              // (*)
      int initFlags =                   ec_InitFlags     (__ExecutionContext) | SumInts(__INIT_FLAGS__);
   __LOG_CUSTOM     = (initFlags & INIT_CUSTOMLOG != 0);                                                    // (*)

   PipDigits        = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints        = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pip              = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat   = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat      = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);


   // (3) Im Tester globale Arrays eines EA's zurücksetzen.
   if (IsTesting())
      Tester.ResetGlobalArrays();                                                // Workaround für die ansonsten im Speicher verbleibenden Variablen des vorherigen Tests.

   onInit();
   return(catch("init(1)"));
}


/**
 * Dummy-Startfunktion für Libraries. Für den Compiler v224 muß ab einer unbestimmten Komplexität der Library eine start()-Funktion existieren,
 * damit die init()-Funktion aufgerufen wird.
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
 * NOTE: 1) Bei VisualMode=Off und regulärem Testende (Testperiode zu Ende) bricht das Terminal komplexere EA-deinit()-Funktionen verfrüht und nicht
 *          erst nach 2.5 Sekunden ab. In diesem Fall wird diese deinit()-Funktion u.U. nicht mehr ausgeführt.
 *
 *       2) Bei Testende wird diese deinit()-Funktion u.U. zweimal aufgerufen. Beim zweiten Mal ist die Library zurückgesetzt, der Variablen-Status also
 *          undefiniert.
 */
int deinit() {
   __WHEREAMI__ = RF_DEINIT;
   SyncLibExecutionContext(__ExecutionContext, WindowExpertName(), RF_DEINIT, Symbol(), Period());
   onDeinit();
   return(catch("deinit(1)")); __DummyCalls();
}


/**
 * Gibt die ID des aktuellen oder letzten Init()-Szenarios zurück. Kann außer in deinit() überall aufgerufen werden.
 *
 * @return int - ID oder NULL, falls ein Fehler auftrat
 */
int InitReason() {
   return(_NULL(catch("InitReason(1)", ERR_NOT_IMPLEMENTED)));
}


/**
 * Gibt die ID des aktuellen Deinit()-Szenarios zurück. Kann nur in deinit() aufgerufen werden.
 *
 * @return int - ID oder NULL, falls ein Fehler auftrat
 */
int DeinitReason() {
   return(_NULL(catch("DeinitReason(1)", ERR_NOT_IMPLEMENTED)));
}


/**
 * Ob das aktuell ausgeführte Programm ein Expert ist.
 *
 * @return bool
 */
bool IsExpert() {
   if (__TYPE__ == MT_LIBRARY) return(!catch("IsExpert(1)  library not initialized", ERR_RUNTIME_ERROR));

   return(__TYPE__ & MT_EXPERT != 0);
}


/**
 * Ob das aktuell ausgeführte Programm ein Script ist.
 *
 * @return bool
 */
bool IsScript() {
   if (__TYPE__ == MT_LIBRARY) return(!catch("IsScript(1)  library not initialized", ERR_RUNTIME_ERROR));

   return(__TYPE__ & MT_SCRIPT != 0);
}


/**
 * Ob das aktuell ausgeführte Programm ein Indikator ist.
 *
 * @return bool
 */
bool IsIndicator() {
   if (__TYPE__ == MT_LIBRARY) return(!catch("IsIndicator(1)  library not initialized", ERR_RUNTIME_ERROR));

   return(__TYPE__ & MT_INDICATOR != 0);
}


/**
 * Ob das aktuell ausgeführte Modul eine Library ist.
 *
 * @return bool
 */
bool IsLibrary() {
   return(true);
}


/**
 * Ob das aktuelle Programm durch ein anderes Programm ausgeführt wird.
 *
 * @return bool
 */
bool IsSuperContext() {
   if (__TYPE__ == MT_LIBRARY) return(!catch("IsSuperContext(1)  library not initialized", ERR_RUNTIME_ERROR));

   return(__lpSuperContext != 0);
}


/**
 * Setzt den internen Fehlercode des Moduls.
 *
 * @param  int error - Fehlercode
 *
 * @return int - derselbe Fehlercode (for chaining)
 *
 *
 * NOTE: Akzeptiert einen weiteren beliebigen Parameter, der bei der Verarbeitung jedoch ignoriert wird.
 */
int SetLastError(int error, int param=NULL) {
   last_error = ec_setLastError(__ExecutionContext, error);
   return(error);
}


/**
 * Überprüft und aktualisiert den aktuellen Programmstatus. Darf in Libraries nicht verwendet werden, dort kann der Programmstatus aus dem
 * EXECUTION_CONTEXT ausgelesen, jedoch nicht modifiziert werden.
 *
 * @param  int value - der zurückzugebende Wert (default: NULL)
 *
 * @return int - der übergebene Wert
 */
int UpdateProgramStatus(int value=NULL) {
   catch("UpdateProgramStatus(1)", ERR_FUNC_NOT_ALLOWED);
   return(value);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "Expander.dll"
  bool   SyncLibExecutionContext(int ec[], string name, int rootFunction, string symbol, int period);

  int    ec_InitFlags     (/*EXECUTION_CONTEXT*/int ec[]);
  bool   ec_Logging       (/*EXECUTION_CONTEXT*/int ec[]);
  int    ec_lpSuperContext(/*EXECUTION_CONTEXT*/int ec[]);
  string ec_ProgramName   (/*EXECUTION_CONTEXT*/int ec[]);
  int    ec_RootFunction  (/*EXECUTION_CONTEXT*/int ec[]);

  int    ec_setLastError  (/*EXECUTION_CONTEXT*/int ec[], int lastError);
#import
