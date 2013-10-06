
int __TYPE__         = T_LIBRARY;
int __lpSuperContext = NULL;


/**
 * Initialisierung der Library.
 *
 * @return int - Fehlerstatus
 */
int init() {
   // Im Tester globale Arrays zurücksetzen (zur Zeit kein besserer Workaround).
   Tester.ResetGlobalArrays();
   return(catch("init()"));
}


/**
 * Startfunktion für Libraries (Dummy).
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: Für den Compiler v224 muß ab einer unbestimmten Komplexität der Library eine start()-Funktion existieren,
 *       wenn die init()-Funktion implementiert wurde.
 */
int start() {
   return(catch("start()", ERR_WRONG_JUMP));
}


/**
 * Deinitialisierung der Library.
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: 1) Bei VisualMode=Off und regulärem Testende (Testperiode zu Ende = REASON_UNDEFINED) bricht das Terminal komplexere EA-deinit()-Funktionen
 *          verfrüht und nicht erst nach 2.5 Sekunden ab. In diesem Fall wird diese deinit()-Funktion u.U. auch nicht mehr ausgeführt.
 *
 *       2) Bei Testende wird diese deinit()-Funktion (wenn implementiert) u.U. zweimal aufgerufen. Beim zweiten mal ist die Library zurückgesetzt,
 *          der Variablen-Status also undefiniert.
*/
int deinit() {
   return(catch("deinit()"));
}


/**
 * Ob das aktuell ausgeführte Programm ein Expert ist.
 *
 * @return bool
 */
bool IsExpert() {
   if (__TYPE__ == T_LIBRARY)
      return(!catch("IsExpert()   function must not be called before library initialization", ERR_RUNTIME_ERROR));
   return(1 && __TYPE__ & T_EXPERT);
}


/**
 * Ob das aktuell ausgeführte Programm ein im Tester laufender Expert ist.
 *
 * @return bool
 */
bool Expert.IsTesting() {
   if (__TYPE__ == T_LIBRARY)
      return(!catch("Expert.IsTesting()   function must not be called before library initialization", ERR_RUNTIME_ERROR));

   if (IsTesting()) /*&&*/ if (IsExpert())
      return(true);
   return(false);
}


/**
 * Ob das aktuell ausgeführte Programm ein Indikator ist.
 *
 * @return bool
 */
bool IsIndicator() {
   if (__TYPE__ == T_LIBRARY)
      return(!catch("IsIndicator()   function must not be called before library initialization", ERR_RUNTIME_ERROR));
   return(1 && __TYPE__ & T_INDICATOR);
}


/**
 * Ob das aktuelle Programm durch ein anderes Programm ausgeführt wird.
 *
 * @return bool
 */
bool Indicator.IsSuperContext() {
   if (__TYPE__ == T_LIBRARY)
      return(!catch("Indicator.IsSuperContext()   function must not be called before library initialization", ERR_RUNTIME_ERROR));
   return(__lpSuperContext != 0);
}


/**
 * Ob das aktuell ausgeführte Programm ein Script ist.
 *
 * @return bool
 */
bool IsScript() {
   if (__TYPE__ == T_LIBRARY)
      return(!catch("IsScript()   function must not be called before library initialization", ERR_RUNTIME_ERROR));
   return(__TYPE__ & T_SCRIPT);
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
 * Ob das aktuelle Programm im Tester ausgeführt wird.
 *
 * @return bool
 */
bool This.IsTesting() {
   if (__TYPE__ == T_LIBRARY)
      return(!catch("This.IsTesting()   function must not be called before library initialization", ERR_RUNTIME_ERROR));

   if (   IsExpert()) return(   Expert.IsTesting());
   if (   IsScript()) return(   Script.IsTesting());
   if (IsIndicator()) return(Indicator.IsTesting());

   return(false);
}


#import "structs1.ex4"
   int ec.setLastError(/*EXECUTION_CONTEXT*/int ec[], int lastError);
#import


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
   last_error = error;

   // __STATUS_ERROR ist ein Status des Hauptprogramms und wird in Libraries nicht gesetzt

   return(ec.setLastError(__ExecutionContext, last_error));
}
