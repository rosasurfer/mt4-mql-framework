
/**
 * Initialisierung der Library.
 *
 * @return int - Fehlerstatus
 *
int init() {
   return(NO_ERROR);
}
*/


/**
 * Startfunktion für Libraries (Dummy).
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: Für den Compiler v224 muß ab einer unbestimmten Komplexität der Library eine start()-Funktion existieren,
 *       wenn die init()-Funktion implementiert wird.
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
int deinit() {
   return(NO_ERROR);
}
*/


/**
 * Ob das aktuelle ausgeführte Programm ein Expert Adviser ist.
 *
 * @return bool
 */
bool IsExpert() {
   if (__TYPE__ == T_LIBRARY)
      return(_false(catch("IsExpert()   function must not be used before library initialization", ERR_RUNTIME_ERROR)));
   return(__TYPE__ & T_EXPERT);
}


/**
 * Ob das aktuelle ausgeführte Programm ein Indikator ist.
 *
 * @return bool
 */
bool IsIndicator() {
   if (__TYPE__ == T_LIBRARY)
      return(_false(catch("IsIndicator()   function must not be used before library initialization", ERR_RUNTIME_ERROR)));
   return(__TYPE__ & T_INDICATOR);
}


/**
 * Ob das aktuelle ausgeführte Programm ein Script ist.
 *
 * @return bool
 */
bool IsScript() {
   if (__TYPE__ == T_LIBRARY)
      return(_false(catch("IsScript()   function must not be used before library initialization", ERR_RUNTIME_ERROR)));
   return(__TYPE__ & T_SCRIPT);
}


/**
 * Ob das aktuelle ausgeführte Programm eine Library ist.
 *
 * @return bool
 */
bool IsLibrary() {
   return(true);
}
