
int scriptrunner.hQC.sender;
int scriptrunner.hQC.receiver;


/**
 * Startet im aktuellen Chart ein Script und übergibt die angegebenen Parameter. Darf nicht aus einem Script aufgerufen
 * werden, da im Chart jeweils nur ein Script laufen kann.
 *
 * @param  string name       - Name des Scripts
 * @param  string parameters - Parameterstring: Das Format ist alleinige Sache vom Aufrufer dieser Funktion und dem
 *                             aufgerufenen Script. (default: keine Parameter)
 *
 * @return bool - Ob die Startanweisung erfolgreich übermittelt wurde. Nicht, ob das Script erfolgreich gestartet oder
 *                ausgeführt wurde.
 */

bool RunScript(string name, string parameters="") {
   if (IsScript())       return(!catch("RunScript(1)  invalid calling context (must not be called from a script)", ERR_RUNTIME_ERROR));
   if (!StringLen(name)) return(!catch("RunScript(2)  invalid parameter name="+ DoubleQuoteStr(name), ERR_INVALID_PARAMETER));
   if (parameters == "0")                             // (string) NULL
      parameters = "";
   string scriptName[]; ArrayResize(scriptName, 1);


   // (1) Prüfen, ob das Script existiert
   string file = GetMqlDirectoryA() +"/scripts/"+ name +".ex4";
   if (!IsFile(file, MODE_SYSTEM)) return(!catch("RunScript(3)  file not found: "+ DoubleQuoteStr(file), ERR_FILE_NOT_FOUND));


   // (2) Prüfen, ob bereits ein Script läuft. Eines läuft, wenn auf dem Parameter-Channel ein Receiver aktiv ist oder dort unabgeholte Messages liegen.
   string channel = ScriptRunner.GetChannelName();
   int    result  = QC_ChannelHasReceiver(channel);
   if (result == QC_CHECK_CHANNEL_ERROR) return(!catch("RunScript(4)->MT4iQuickChannel::QC_ChannelHasReceiver(name="+ DoubleQuoteStr(channel) +") = QC_CHECK_CHANNEL_ERROR", ERR_WIN32_ERROR));
   bool isChannel=(result!=QC_CHECK_CHANNEL_NONE), isChannelReceiver=(result==QC_CHECK_RECEIVER_OK), isChannelEmpty=true;
   if (isChannel) {
      result = QC_CheckChannel(channel);
      if (result < QC_CHECK_CHANNEL_EMPTY) return(!catch("RunScript(5)->MT4iQuickChannel::QC_CheckChannel(name="+ DoubleQuoteStr(channel) +") = "+ result, ERR_WIN32_ERROR));
      isChannelEmpty = (result==QC_CHECK_CHANNEL_EMPTY);
   }
   bool isScriptRunning = isChannelReceiver || !isChannelEmpty;
   //debug("RunScript(6)  isChannel="+ isChannel +"  isChannelEmpty="+ isChannelEmpty +"  isChannelReceiver="+ isChannelReceiver +"  isScriptRunning="+ isScriptRunning);
   if (isScriptRunning) /*&&*/ if (!StrCompareI(name, scriptName[0])) return(!catch("RunScript(7)  cannot run "+ DoubleQuoteStr(name) +" while "+ DoubleQuoteStr(scriptName[0]) +" is running", ERR_RUNTIME_ERROR));


   // (2) Parameter hinterlegen
   if (!ScriptRunner.SetParameters(parameters)) return(false);


   // (3) Script starten, falls es noch nicht läuft                  // Der Zeiger auf den Scriptnamen muß auch nach Verlassen der Funktion gültig sein, was ein String-Array
   if (!isScriptRunning) {                                           // für die Variable bedingt. Dieses Array darf bei Verlassen der Funktion nicht zurückgesetzt werden.
      scriptName[0] = StringConcatenate("", name);                   // Der Zeiger wird beim Aufruf eines anderen Scripts oder beim nächsten deinit() ungültig.
      int hWnd = __ExecutionContext[EC.hChart];
      if (!PostMessageA(hWnd, WM_MT4(), MT4_LOAD_SCRIPT, GetStringAddress(scriptName[0]))) return(!catch("RunScript(8)->user32::PostMessageA()", ERR_WIN32_ERROR));
   }

   return(true);
   ScriptRunner.__DummyCalls();
}


/**
 * Gibt den Namen des Parameter-Channels für Scripte dieses Charts zurück.
 *
 * @return string - Name oder Leerstring, falls ein Fehler auftrat
 */
string ScriptRunner.GetChannelName() {
   static string name=""; if (!StringLen(name)) {
      int hWnd = __ExecutionContext[EC.hChart];
      name = "ScriptParameters."+ IntToHexStr(hWnd);
   }
   return(name);
}


/**
 * Hinterlegt die übergebenen Parameter für das nächste Script im aktuellen Chart.
 *
 * @param  string parameters - Parameterstring (das Format ist nicht Sache dieser Funktion)
 *
 * @return bool - success status
 */
bool ScriptRunner.SetParameters(string parameters) {
   if (IsScript()) return(!catch("ScriptRunner.SetParameters(1)  invalid calling context (must not be called from a script)", ERR_RUNTIME_ERROR));

   // Script-Parameter via QuickChannel hinterlegen
   if (!scriptrunner.hQC.sender) /*&&*/ if (!ScriptRunner.StartParamSender()) // Da Laufzeit und Erfolg des zu startenden Scripts unbekannt sind,
      return(false);                                                          // darf der Sender erst beim nächsten deinit() gestoppt werden.

   parameters = StrReplace(parameters, TAB, HTML_TAB);

   if (!QC_SendMessage(scriptrunner.hQC.sender, parameters, NULL))
      return(!catch("ScriptRunner.SetParameters(2)->MT4iQuickChannel::QC_SendMessage() = QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));

   return(true);
   ScriptRunner.__DummyCalls();
}


/**
 * Gibt die per QuickChannel übertragenen Parameterstrings des aktuellen Scripts zurück. Je Scriptaufruf wird ein Parameter-
 * string übertragen. Das Format der Strings ist nicht Sache dieser Funktion.
 *
 * @param  _Out_ string parameters[] - Array zur Aufnahme der übertragenen Parameterstrings
 * @param  _In_  bool   stopReceiver - ob der Receiver vorm Verlassen der Funktion gestoppt werden soll (default: ja)
 *
 * @return bool - success status
 */
bool ScriptRunner.GetParameters(string &parameters[], bool stopReceiver=true) {
   stopReceiver = stopReceiver!=0;
   if (!IsScript()) return(!catch("ScriptRunner.GetParameters(1)  invalid calling context (not a script)", ERR_RUNTIME_ERROR));

   ArrayResize(parameters, 0);
   int error;

   // ggf. Receiver starten
   if (!scriptrunner.hQC.receiver) /*&&*/ if (!ScriptRunner.StartParamReceiver())
      return(false);

   // Channel auf neue Messages prüfen
   string channel     = ScriptRunner.GetChannelName();
   int    checkResult = QC_CheckChannel(channel);
   if (checkResult < QC_CHECK_CHANNEL_EMPTY) {
      if      (checkResult == QC_CHECK_CHANNEL_ERROR) error = catch("ScriptRunner.GetParameters(2)->MT4iQuickChannel::QC_CheckChannel(name="+ DoubleQuoteStr(channel) +") => QC_CHECK_CHANNEL_ERROR",                ERR_WIN32_ERROR);
      else if (checkResult == QC_CHECK_CHANNEL_NONE ) error = catch("ScriptRunner.GetParameters(3)->MT4iQuickChannel::QC_CheckChannel(name="+ DoubleQuoteStr(channel) +")  channel doesn't exist",                   ERR_WIN32_ERROR);
      else                                            error = catch("ScriptRunner.GetParameters(4)->MT4iQuickChannel::QC_CheckChannel(name="+ DoubleQuoteStr(channel) +")  unexpected return value = "+ checkResult, ERR_WIN32_ERROR);
   }
   else if (checkResult > QC_CHECK_CHANNEL_EMPTY) {
      // neue Messages abholen
      string messageBuffer[]; if (!ArraySize(messageBuffer)) InitializeStringBuffer(messageBuffer, QC_MAX_BUFFER_SIZE);
      int getResult = QC_GetMessages3(scriptrunner.hQC.receiver, messageBuffer, QC_MAX_BUFFER_SIZE);
      if (getResult != QC_GET_MSG3_SUCCESS) {
         if      (getResult == QC_GET_MSG3_CHANNEL_EMPTY) error = catch("ScriptRunner.GetParameters(5)->MT4iQuickChannel::QC_GetMessages3()  QuickChannel mis-match: QC_CheckChannel="+ checkResult +"chars/QC_GetMessages3=CHANNEL_EMPTY", ERR_WIN32_ERROR);
         else if (getResult == QC_GET_MSG3_INSUF_BUFFER ) error = catch("ScriptRunner.GetParameters(6)->MT4iQuickChannel::QC_GetMessages3()  QuickChannel mis-match: QC_CheckChannel="+ checkResult +"chars/QC_MAX_BUFFER_SIZE="+ QC_MAX_BUFFER_SIZE +"/size(buffer)="+ (StringLen(messageBuffer[0])+1) +"/QC_GetMessages3=INSUF_BUFFER", ERR_WIN32_ERROR);
         else                                             error = catch("ScriptRunner.GetParameters(7)->MT4iQuickChannel::QC_GetMessages3()  unexpected return value = "+ getResult, ERR_WIN32_ERROR);
      }
      else {
         // Mesages trennen, konvertieren und im übergebenen Array speichern
         int size = Explode(messageBuffer[0], TAB, parameters, NULL);
         for (int i=0; i < size; i++) {
            parameters[i] = StrReplace(parameters[i], HTML_TAB, TAB);
         }
      }
   }

   // Receiver stoppen, falls angegeben
   if (stopReceiver)
      if (!ScriptRunner.StopParamReceiver()) return(false);

   return(error == NO_ERROR);
   ScriptRunner.__DummyCalls();
}


/**
 * Startet einen QuickChannel-Sender für Scriptparameter.
 *
 * @return bool - success status
 */
bool ScriptRunner.StartParamSender() {
   if (IsScript()) return(!catch("ScriptRunner.StartParamSender(1)  invalid calling context (must not be called from a script)", ERR_RUNTIME_ERROR));

   if (scriptrunner.hQC.sender != NULL)
      return(true);

   scriptrunner.hQC.sender = QC_StartSender(ScriptRunner.GetChannelName());

   if (!scriptrunner.hQC.sender)
      return(!catch("ScriptRunner.StartParamSender(2)->MT4iQuickChannel::QC_StartSender(channel="+ DoubleQuoteStr(ScriptRunner.GetChannelName()) +")", ERR_WIN32_ERROR));
   //debug("ScriptRunner.StartParamSender(3)  sender on "+ DoubleQuoteStr(ScriptRunner.GetChannelName()) +" started");
   return(true);
}


/**
 * Stoppt einen QuickChannel-Sender für Scriptparameter.
 *
 * @return bool - success status
 */
bool ScriptRunner.StopParamSender() {
   if (!scriptrunner.hQC.sender)
      return(true);
   int hTmp = scriptrunner.hQC.sender;
              scriptrunner.hQC.sender = NULL;
   if (!QC_ReleaseSender(hTmp)) return(!catch("ScriptRunner.StopParamSender(1)->MT4iQuickChannel::QC_ReleaseSender(channel="+ DoubleQuoteStr(ScriptRunner.GetChannelName()) +")  error stopping sender", ERR_WIN32_ERROR));
   //debug("ScriptRunner.StopParamSender(2)  sender on "+ DoubleQuoteStr(ScriptRunner.GetChannelName()) +" stopped ("+ CoreFunctionToStr(__ExecutionContext[EC.programCoreFunction]) +")");
   return(true);
}


/**
 * Startet einen QuickChannel-Receiver für Scriptparameter. Der Aufruf muß aus einem Script erfolgen.
 *
 * @return bool - success status
 */
bool ScriptRunner.StartParamReceiver() {
   if (!IsScript()) return(!catch("ScriptRunner.StartParamReceiver(1)  invalid calling context (not a script)", ERR_RUNTIME_ERROR));

   if (scriptrunner.hQC.receiver != NULL)
      return(true);

   int hWnd = __ExecutionContext[EC.hChart];
   scriptrunner.hQC.receiver = QC_StartReceiver(ScriptRunner.GetChannelName(), hWnd);

   if (!scriptrunner.hQC.receiver)
      return(!catch("ScriptRunner.StartParamReceiver(2)->MT4iQuickChannel::QC_StartReceiver(channel="+ DoubleQuoteStr(ScriptRunner.GetChannelName()) +", hWnd="+ IntToHexStr(hWnd) +") => 0", ERR_WIN32_ERROR));
   //debug("ScriptRunner.StartParamReceiver(3)  receiver on "+ DoubleQuoteStr(ScriptRunner.GetChannelName()) +" started");
   return(true);
}


/**
 * Stoppt einen QuickChannel-Receiver für Scriptparameter.
 *
 * @return bool - success status
 */
bool ScriptRunner.StopParamReceiver() {
   if (scriptrunner.hQC.receiver != NULL) {
      int hTmp = scriptrunner.hQC.receiver;
                 scriptrunner.hQC.receiver = NULL;                   // Handle immer zurücksetzen, um mehrfache Stopversuche bei Fehlern zu vermeiden
      if (!QC_ReleaseReceiver(hTmp)) return(!catch("ScriptRunner.StopParamReceiver(1)->MT4iQuickChannel::QC_ReleaseReceiver(channel=\""+ ScriptRunner.GetChannelName() +"\")  error stopping receiver", ERR_WIN32_ERROR));
      //debug("ScriptRunner.StopParamReceiver(2)  receiver on \""+ ScriptRunner.GetChannelName() +"\" stopped ("+ CoreFunctionToStr(__ExecutionContext[EC.programCoreFunction]) +")");
   }
   return(true);
}


/**
 * Dummy-Calls unterdrücken unnütze Compilerwarnungen.
 *
 * @access private - Aufruf nur aus dieser Datei
 */
void ScriptRunner.__DummyCalls() {
   string sNulls[];
   RunScript(NULL);
   ScriptRunner.GetChannelName();
   ScriptRunner.GetParameters(sNulls);
   ScriptRunner.SetParameters(NULL);
   ScriptRunner.StartParamSender();
   ScriptRunner.StopParamSender();
   ScriptRunner.StartParamReceiver();
   ScriptRunner.StopParamReceiver();
}
