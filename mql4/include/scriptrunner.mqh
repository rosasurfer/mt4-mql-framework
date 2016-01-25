
string  qc.ScriptParameterChannel;
int    hQC.ScriptParameterSender;


/**
 * Startet im aktuellen Chart ein Script und übergibt die angegebenen Parameter. Darf nicht aus einem Script selbst aufgerufen werden,
 * da im Chart jeweils nur ein Script laufen kann.
 *
 * @param  string name       - Name des Scripts
 * @param  string parameters - Parameter im Format "param1Name=param1Value{TAB}param2Name=param2Value[{TAB}...]" (default: keine Parameter)
 *
 * @return bool - Ob die Startanweisung erfolgreich ans System übermittelt wurde.
 *                Nicht, ob das Script erfolgreich gestartet und/oder ausgeführt wurde.
 */
bool RunScript(string name, string parameters="") {
   if (IsScript())       return(!catch("RunScript(1)  invalid calling context (must not be called from a script)", ERR_RUNTIME_ERROR));
   if (!StringLen(name)) return(!catch("RunScript(2)  invalid parameter name=\"\"", ERR_INVALID_PARAMETER));

   if (parameters == "0")                                            // (string) NULL
      parameters = "";

   int hWnd = WindowHandleEx(NULL);
   if (!hWnd) return(false);

   // Parameter hinterlegen
   if (!SetScriptParameters(parameters))
      return(false);

   string scriptName[1]; scriptName[0]=StringConcatenate("", name);  // Der Pointer auf 'name' muß während der Script-Ausführung noch gültig sein,
                                                                     // was im Indikator oder Expert nur mit einem String-Array sichergestellt ist.
   // Script starten
   if (!PostMessageA(hWnd, MT4InternalMsg(), MT4_LOAD_SCRIPT, GetStringAddress(scriptName[0])))
      return(!catch("RunScript(3)->user32::PostMessageA()", ERR_WIN32_ERROR));

   return(true);
   DummyCalls.ParameterProvider();
}


/**
 * Hinterlegt die übergebenen Parameter für den automatischen Aufruf des nächsten Scripts im aktuellen Chart.
 *
 * @param  string parameters - dem Script entsprechender Parameterstring im Format "param1Name=param1Value{TAB}param2Name=param2Value[{TAB}...]"
 *
 * @return bool - Erfolgsstatus
 */
bool SetScriptParameters(string parameters) {
   // Script-Parameter via QuickChannel hinterlegen
   if (!hQC.ScriptParameterSender) /*&&*/ if (!QC.StartScriptParameterSender())     // Da Laufzeit und Erfolg des zu startenden Scripts unbekannt sind,
      return(false);                                                                // darf der Sender erst beim nächsten deinit() gestoppt werden

   // TODO: bei Mehrfachaufrufen vorhandene Parameter modifizieren

   int result = QC_SendMessage(hQC.ScriptParameterSender, parameters, NULL);
   if (!result)
      return(!catch("SetScriptParameters()->MT4iQuickChannel::QC_SendMessage() = QC_SEND_MSG_ERROR", ERR_WIN32_ERROR));

   return(true);
   DummyCalls.ParameterProvider();
}


/**
 * Gibt die per QuickChannel übergebenen Parameter des aktuellen Scripts zurück.
 *
 * @param  string paramNames [] - Array zur Aufnahme der Parameternamen
 * @param  string paramValues[] - Array zur Aufnahme der Parameterwerte
 *
 * @return int - Anzahl der übergebenen Parameter oder -1 (EMPTY), falls ein Fehler auftrat
 */
int GetScriptParameters(string paramNames[], string paramValues[]) {
   if (!IsScript())
      return(_EMPTY(catch("GetScriptParameters(1)  invalid calling context (not a script)", ERR_RUNTIME_ERROR)));

   string parameters = "";

   // Um für den QC-Receiver kein Fenster registrieren zu müssen (löst unnötige Ticks aus), benutzen wir zum Lesen des Channels einen weiteren Sender.
   if (!hQC.ScriptParameterSender) /*&&*/ if (!QC.StartScriptParameterSender())
      return(EMPTY);

   // TODO: Channel zuerst prüfen, erst dann Sender starten

   // check channel
   int result = QC_CheckChannel(qc.ScriptParameterChannel);
   if (result < QC_CHECK_CHANNEL_EMPTY) {
      if      (result == QC_CHECK_CHANNEL_ERROR) catch("GetScriptParameters(2)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\") => QC_CHECK_CHANNEL_ERROR",           ERR_WIN32_ERROR);
      else if (result == QC_CHECK_CHANNEL_NONE ) catch("GetScriptParameters(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\")  channel doesn't exist",              ERR_WIN32_ERROR);
      else                                       catch("GetScriptParameters(4)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\")  unexpected return value = "+ result, ERR_WIN32_ERROR);
   }
   else if (result > QC_CHECK_CHANNEL_EMPTY) {
      // get messages
      string messageBuffer[]; if (!ArraySize(messageBuffer)) InitializeStringBuffer(messageBuffer, QC_MAX_BUFFER_SIZE);
      result = QC_GetMessages3(hQC.ScriptParameterSender, messageBuffer, QC_MAX_BUFFER_SIZE);
      if (result != QC_GET_MSG3_SUCCESS) {
         if      (result == QC_GET_MSG3_CHANNEL_EMPTY) catch("GetScriptParameters(5)->MT4iQuickChannel::QC_GetMessages3()  QC_CheckChannel not empty/QC_GET_MSG3_CHANNEL_EMPTY mismatch",           ERR_WIN32_ERROR);
         else if (result == QC_GET_MSG3_INSUF_BUFFER ) catch("GetScriptParameters(6)->MT4iQuickChannel::QC_GetMessages3()  buffer to small (QC_MAX_BUFFER_SIZE/QC_GET_MSG3_INSUF_BUFFER mismatch)", ERR_WIN32_ERROR);
         else                                          catch("GetScriptParameters(7)->MT4iQuickChannel::QC_GetMessages3()  unexpected return value = "+ result,                                     ERR_WIN32_ERROR);
      }
      else {
         parameters = messageBuffer[0];
      }
   }

   // stop sender
   if (!QC.StopScriptParameterSender())
      return(EMPTY);
   if (IsLastError())
      return(EMPTY);


   // Parameter parsen
   ArrayResize(paramNames,  0);
   ArrayResize(paramValues, 0);

   string pairs[], param[];
   int size = Explode(parameters, TAB, pairs, NULL);

   for (int i=0; i < size; i++) {
      if (Explode(pairs[i], "=", param, 2) < 2)                      // kein "="-Separator, Parameter wird verworfen
         continue;
      ArrayPushString(paramNames,  param[0]);
      ArrayPushString(paramValues, param[1]);
   }

   return(ArraySize(paramNames));
   DummyCalls.ParameterProvider();
}


/**
 * Startet einen QuickChannel-Sender für Scriptparameter. Bei Aufruf aus einem Script muß der Channel bereits existieren, ohne können
 * keine Parameter hinterlegt worden sein.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StartScriptParameterSender() {
   if (hQC.ScriptParameterSender != 0)
      return(true);

   int hWnd = WindowHandleEx(NULL);
   if (!hWnd) return(false);

   qc.ScriptParameterChannel = "ScriptParameters.0x"+ IntToHexStr(hWnd);

   if (IsScript()) {
      // Der Channel muß bereits existieren, ohne können keine Parameter hinterlegt worden sein.
      int result = QC_CheckChannel(qc.ScriptParameterChannel);
      if (result < QC_CHECK_CHANNEL_EMPTY) {
         if (result == QC_CHECK_CHANNEL_NONE ) return(!catch("QC.StartScriptParameterSender(1)  you cannot manually call this script (channel \""+ qc.ScriptParameterChannel +"\" doesn't exist)",                ERR_RUNTIME_ERROR));
         if (result == QC_CHECK_CHANNEL_ERROR) return(!catch("QC.StartScriptParameterSender(2)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\") => QC_CHECK_CHANNEL_ERROR",            ERR_WIN32_ERROR  ));
                                               return(!catch("QC.StartScriptParameterSender(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\")  unexpected return value = "+ result, ERR_WIN32_ERROR  ));
      }
   }

   hQC.ScriptParameterSender = QC_StartSender(qc.ScriptParameterChannel);
   if (!hQC.ScriptParameterSender)
      return(!catch("QC.StartScriptParameterSender(4)->MT4iQuickChannel::QC_StartSender(channel=\""+ qc.ScriptParameterChannel +"\")", ERR_WIN32_ERROR));

   return(true);
   DummyCalls.ParameterProvider();
}


/**
 * Stoppt einen QuickChannel-Sender für Scriptparameter.
 *
 * @return bool - Erfolgsstatus
 */
bool QC.StopScriptParameterSender() {
   if (!hQC.ScriptParameterSender)
      return(true);

   // TODO: prüfen, ob alle Messages abgeholt sind und der Channel leer ist

   int    hTmp    = hQC.ScriptParameterSender;
   string channel = qc.ScriptParameterChannel;

   hQC.ScriptParameterSender = NULL;
   qc.ScriptParameterChannel = "";

   if (!QC_ReleaseSender(hTmp))
      return(!catch("QC.StopScriptParameterSender(1)->MT4iQuickChannel::QC_ReleaseSender(channel=\""+ channel +"\")  error stopping sender", ERR_WIN32_ERROR));

   return(true);
   DummyCalls.ParameterProvider();
}


/**
 * Dummy-Calls unterdrücken unnütze Compilerwarnungen.
 *
 */
void DummyCalls.ParameterProvider() {
   string sNulls[];
   GetScriptParameters(sNulls, sNulls);
   QC.StartScriptParameterSender();
   QC.StopScriptParameterSender();
   RunScript(NULL);
   SetScriptParameters(NULL);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   int Explode(string input, string separator, string results[], int limit);
#import
