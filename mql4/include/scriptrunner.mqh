
string  qc.ScriptParameterChannel;
int    hQC.ScriptParameterSender;


/**
 * Startet im aktuellen Chart ein Script und übergibt die angegebenen Parameter. Darf nicht aus einem Script aufgerufen werden,
 * da im Chart jeweils nur ein Script laufen kann.
 *
 * @param  string name       - Name des Scripts
 * @param  string parameters - Parameterstring: Das Format ist alleinige Sache vom Aufrufer dieser Funktion und dem aufgerufenen Script.
 *                             (default: keine Parameter)
 *
 * @return bool - Ob die Startanweisung erfolgreich übermittelt wurde. Nicht, ob das Script erfolgreich gestartet oder ausgeführt wurde.
 */
bool RunScript(string name, string parameters="") {
   if (IsScript())       return(!catch("RunScript(1)  invalid calling context (must not be called from a script)", ERR_RUNTIME_ERROR));
   if (!StringLen(name)) return(!catch("RunScript(2)  invalid parameter name="+ DoubleQuoteStr(name), ERR_INVALID_PARAMETER));

   // TODO: Mehrere Scripte müssen synchron ausgeführt werden.

   if (parameters == "0")                                            // (string) NULL
      parameters = "";

   int hWnd = WindowHandleEx(NULL); if (!hWnd) return(false);

   // Parameter hinterlegen
   if (!ScriptRunner.SetParameters(parameters))
      return(false);

   string scriptName[]; ArrayResize(scriptName, 1);                  // Der Zeiger auf den Scriptnamen muß nach Verlassen der Funktion weiter gültig sein, was ein String-Array
   scriptName[0] = StringConcatenate("", name);                      // für die Variable bedingt. Dieses Array darf bei Verlassen der Funktion nicht zurückgesetzt werden.
                                                                     // Der Zeiger wird beim nächsten Aufruf dieser Funktion oder beim nächsten init-Cycle ungültig.
   // Script starten
   if (!PostMessageA(hWnd, MT4InternalMsg(), MT4_LOAD_SCRIPT, GetStringAddress(scriptName[0])))
      return(!catch("RunScript(3)->user32::PostMessageA()", ERR_WIN32_ERROR));

   return(true);
   ScriptRunner.__DummyCalls();
}


/**
 * Hinterlegt die übergebenen Parameter für das nächste Script im aktuellen Chart.
 *
 * @param  string parameters - Parameterstring (das Format ist nicht Sache dieser Funktion)
 *
 * @return bool - Erfolgsstatus
 */
bool ScriptRunner.SetParameters(string parameters) {
   // Script-Parameter via QuickChannel hinterlegen
   if (!hQC.ScriptParameterSender) /*&&*/ if (!ScriptRunner.StartParamsSender())    // Da Laufzeit und Erfolg des zu startenden Scripts unbekannt sind,
      return(false);                                                                // darf der Sender erst beim nächsten deinit() gestoppt werden.

   parameters = StringReplace(parameters, TAB, HTML_TAB);

   int result = QC_SendMessage(hQC.ScriptParameterSender, parameters, NULL);
   if (!result) return(!catch("ScriptRunner.SetParameters(1)->MT4iQuickChannel::QC_SendMessage() = QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));

   return(true);
   ScriptRunner.__DummyCalls();
}


/**
 * Gibt die per QuickChannel übertragenen Parameterstrings des aktuellen Scripts zurück. Wird dasselbe Script während der Laufzeit erneut aufgerufen,
 * wird der Parameterstring der MessageQueue der vorhandenen Parameter hinzugefügt (eine QuickChannel-Message enthält die Parameter eines Scriptaufrufes).
 * Das Format der Parameterstrings ist nicht Sache dieser Funktion.
 *
 * @param  _Out_ string parameters[] - Array zur Aufnahme der in der Queue hinterlegten Parameterstrings (je Scriptaufruf einer)
 *
 * @return bool - Erfolgsstatus
 */
bool ScriptRunner.GetParameters(string &parameters[]) {
   if (!IsScript()) return(!catch("ScriptRunner.GetParameters(1)  invalid calling context (not a script)", ERR_RUNTIME_ERROR));

   // Um für den QC-Receiver kein Fenster registrieren zu müssen (löst unnötige Ticks aus), benutzen wir zum Lesen des Channels einen weiteren Sender.
   if (!hQC.ScriptParameterSender) /*&&*/ if (!ScriptRunner.StartParamsSender())
      return(false);
   // TODO: Channel zuerst prüfen, erst dann Sender starten

   int error;

   // check channel
   int checkResult = QC_CheckChannel(qc.ScriptParameterChannel);
   if (checkResult < QC_CHECK_CHANNEL_EMPTY) {
      if      (checkResult == QC_CHECK_CHANNEL_ERROR) error = catch("ScriptRunner.GetParameters(2)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\") => QC_CHECK_CHANNEL_ERROR",                ERR_WIN32_ERROR);
      else if (checkResult == QC_CHECK_CHANNEL_NONE ) error = catch("ScriptRunner.GetParameters(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\")  channel doesn't exist",                   ERR_WIN32_ERROR);
      else                                            error = catch("ScriptRunner.GetParameters(4)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\")  unexpected return value = "+ checkResult, ERR_WIN32_ERROR);
   }
   else if (checkResult > QC_CHECK_CHANNEL_EMPTY) {
      // get messages
      string messageBuffer[]; if (!ArraySize(messageBuffer)) InitializeStringBuffer(messageBuffer, QC_MAX_BUFFER_SIZE);
      int getResult = QC_GetMessages3(hQC.ScriptParameterSender, messageBuffer, QC_MAX_BUFFER_SIZE);
      if (getResult != QC_GET_MSG3_SUCCESS) {
         if      (getResult == QC_GET_MSG3_CHANNEL_EMPTY) error = catch("ScriptRunner.GetParameters(5)->MT4iQuickChannel::QC_GetMessages3()  QuickChannel mis-match: QC_CheckChannel="+ checkResult +"chars/QC_GetMessages3=CHANNEL_EMPTY", ERR_WIN32_ERROR);
         else if (getResult == QC_GET_MSG3_INSUF_BUFFER ) error = catch("ScriptRunner.GetParameters(6)->MT4iQuickChannel::QC_GetMessages3()  QuickChannel mis-match: QC_CheckChannel="+ checkResult +"chars/QC_MAX_BUFFER_SIZE="+ QC_MAX_BUFFER_SIZE +"/size(buffer)="+ (StringLen(messageBuffer[0])+1) +"/QC_GetMessages3=INSUF_BUFFER", ERR_WIN32_ERROR);
         else                                             error = catch("ScriptRunner.GetParameters(7)->MT4iQuickChannel::QC_GetMessages3()  unexpected return value = "+ getResult, ERR_WIN32_ERROR);
      }
      else {
         // split and translate messages
         int size = Explode(messageBuffer[0], TAB, parameters, NULL);
         for (int i=0; i < size; i++) {
            parameters[i] = StringReplace(parameters[i], HTML_TAB, TAB);
         }
         debug("ScriptRunner.GetParameters(8)  parameters="+ StringsToStr(parameters, NULL));
      }
   }

   // stop sender
   if (!ScriptRunner.StopParamsSender())
      return(false);

   return(!IsError(error));
   ScriptRunner.__DummyCalls();
}


/**
 * Startet einen QuickChannel-Sender für Scriptparameter. Bei Aufruf aus einem Script muß der Channel bereits existieren, ohne können
 * keine Parameter hinterlegt worden sein.
 *
 * @return bool - Erfolgsstatus
 */
bool ScriptRunner.StartParamsSender() {
   if (hQC.ScriptParameterSender != 0)
      return(true);

   int hWnd = WindowHandleEx(NULL);
   if (!hWnd) return(false);

   qc.ScriptParameterChannel = "ScriptParameters.0x"+ IntToHexStr(hWnd);

   if (IsScript()) {
      // Der Channel muß bereits existieren, ohne können keine Parameter hinterlegt worden sein.
      int result = QC_CheckChannel(qc.ScriptParameterChannel);
      if (result < QC_CHECK_CHANNEL_EMPTY) {
         if (result == QC_CHECK_CHANNEL_NONE ) return(!catch("ScriptRunner.StartParamsSender(1)  you cannot manually call this script (channel \""+ qc.ScriptParameterChannel +"\" doesn't exist)",                ERR_RUNTIME_ERROR));
         if (result == QC_CHECK_CHANNEL_ERROR) return(!catch("ScriptRunner.StartParamsSender(2)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\") => QC_CHECK_CHANNEL_ERROR",            ERR_WIN32_ERROR  ));
                                               return(!catch("ScriptRunner.StartParamsSender(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\")  unexpected return value = "+ result, ERR_WIN32_ERROR  ));
      }
   }

   hQC.ScriptParameterSender = QC_StartSender(qc.ScriptParameterChannel);
   if (!hQC.ScriptParameterSender)
      return(!catch("ScriptRunner.StartParamsSender(4)->MT4iQuickChannel::QC_StartSender(channel=\""+ qc.ScriptParameterChannel +"\")", ERR_WIN32_ERROR));

   return(true);
   ScriptRunner.__DummyCalls();
}


/**
 * Stoppt einen QuickChannel-Sender für Scriptparameter.
 *
 * @return bool - Erfolgsstatus
 */
bool ScriptRunner.StopParamsSender() {
   if (!hQC.ScriptParameterSender)
      return(true);

   // TODO: prüfen, ob alle Messages abgeholt sind und der Channel leer ist

   int hTmp = hQC.ScriptParameterSender;
              hQC.ScriptParameterSender = NULL;

   if (!QC_ReleaseSender(hTmp))
      return(!catch("ScriptRunner.StopParamsSender(1)->MT4iQuickChannel::QC_ReleaseSender(ch=\""+ qc.ScriptParameterChannel +"\")  error stopping sender", ERR_WIN32_ERROR));

   return(true);
   ScriptRunner.__DummyCalls();
}


/**
 * Dummy-Calls unterdrücken unnütze Compilerwarnungen.
 *
 * @access private - Aufruf nur aus dieser Datei
 */
void ScriptRunner.__DummyCalls() {
   string sNulls[];
   RunScript(NULL);
   ScriptRunner.GetParameters(sNulls);
   ScriptRunner.SetParameters(NULL);
   ScriptRunner.StartParamsSender();
   ScriptRunner.StopParamsSender();
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   int Explode(string input, string separator, string results[], int limit);
#import
