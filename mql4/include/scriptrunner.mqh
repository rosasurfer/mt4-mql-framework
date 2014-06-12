#import "stdlib1.ex4"
   string __whereamiDescription(int id);
   int    Explode(string input, string separator, string results[], int limit);
   int    InitializeStringBuffer(string buffer[], int length);
   string ModuleTypeDescription(int type);
   int    MT4InternalMsg();
   int    win32.GetLastError(int altError);

#import "MT4Lib.dll"
   int    GetStringAddress(string value);
#import


string qc.ScriptParameterChannel;
string qc.ScriptParameterBuffer[];
int    hQC.ScriptParameterSender;


/**
 * Startet im aktuellen Chart ein Script und übergibt die angegebenen Parameter. Darf nicht aus einem Script selbst aufgerufen werden,
 * da im Chart jeweils nur ein Script laufen kann.
 *
 * @param  string scriptName - Name des Scripts
 * @param  string parameters - Parameter im Format "param1Name=param1Value{TAB}param2Name=param2Value[{TAB}...]" (default: keine Parameter)
 *
 * @return bool - Ob die Startanweisung erfolgreich ans System übermittelt wurde.
 *                Nicht, ob das Script erfolgreich gestartet und/oder ausgeführt wurde.
 */
bool RunScript(string scriptName, string parameters="") {
   if (IsScript())
      return(!catch("RunScript(1)   invalid calling context (must not be called from a script)", ERR_RUNTIME_ERROR));

   if (!StringLen(scriptName))
      return(!catch("RunScript(2)   invalid parameter scriptName=\"\"", ERR_INVALID_FUNCTION_PARAMVALUE));

   if (parameters == "0")                                            // (string) NULL
      parameters = "";

   int hWnd = WindowHandle(Symbol(), NULL);
   if (!hWnd)
      return(!catch("RunScript(3)->WindowHandle() = 0 in context "+ ModuleTypeDescription(__TYPE__) +"::"+ __whereamiDescription(__WHEREAMI__), ERR_RUNTIME_ERROR));

   // Parameter hinterlegen
   if (!SetScriptParameters(parameters))
      return(false);
                                                                     // Der Pointer auf 'script' muß zur Zeit der Message-Verarbeitung noch gültig sein,
   static string script; script=StringConcatenate("", scriptName);   // was mit static im Indikator oder Expert auf jeden Fall gegeben ist.

   // Script starten
   if (!PostMessageA(hWnd, MT4InternalMsg(), MT4_LOAD_SCRIPT, GetStringAddress(script)))
      return(!catch("RunScript(4)->user32::PostMessageA()", win32.GetLastError(ERR_WIN32_ERROR)));

   return(true);
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
   if (!hQC.ScriptParameterSender) /*&&*/ if (!QC.StartScriptParameterSender())     // Da Laufzeit und Erfolg des folgenden Scripts unbekannt sind,
      return(false);                                                                // darf der Sender erst beim nächsten deinit() gestoppt werden

   // TODO: bei Mehrfachaufrufen vorhandene Parameter modifizieren

   int result = QC_SendMessage(hQC.ScriptParameterSender, parameters, NULL);
   if (!result)
      return(!catch("SetScriptParameters()->MT4iQuickChannel::QC_SendMessage() = QC_SEND_MSG_ERROR", win32.GetLastError(ERR_WIN32_ERROR)));

   //debug("SetScriptParameters()   parameters sent: \"" + parameters +"\"");
   return(true);
}


/**
 * Gibt die per QuickChannel übergebenen Parameter des aktuellen Scripts zurück.
 *
 * @param  string paramNames [] - Array zur Aufnahme der Parameternamen
 * @param  string paramValues[] - Array zur Aufnahme der Parameterwerte
 *
 * @return int - Anzahl der übergebenen Parameter oder -1, falls ein Fehler auftrat
 */
int GetScriptParameters(string paramNames[], string paramValues[]) {
   if (!IsScript())
      return(_int(-1, catch("GetScriptParameters(1)   invalid calling context (not a script)", ERR_RUNTIME_ERROR)));

   string parameters = "";

   // Um für den QC-Receiver kein Fenster registrieren zu müssen (löst unnötige Ticks aus), benutzen wir zum Lesen des Channels einen weiteren Sender.
   if (!hQC.ScriptParameterSender) /*&&*/ if (!QC.StartScriptParameterSender())
      return(-1);

   // TODO: Channel zuerst prüfen, erst dann Sender starten

   // check channel
   int result = QC_CheckChannel(qc.ScriptParameterChannel);
   if (result < QC_CHECK_CHANNEL_EMPTY) {
      if      (result == QC_CHECK_CHANNEL_ERROR) catch("GetScriptParameters(2)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\") => QC_CHECK_CHANNEL_ERROR", win32.GetLastError(ERR_WIN32_ERROR));
      else if (result == QC_CHECK_CHANNEL_NONE ) catch("GetScriptParameters(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\")   channel doesn't exist", win32.GetLastError(ERR_WIN32_ERROR));
      else                                       catch("GetScriptParameters(4)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\")   unexpected return value = "+ result, win32.GetLastError(ERR_WIN32_ERROR));
   }
   else if (result > QC_CHECK_CHANNEL_EMPTY) {
      // get messages
      result = QC_GetMessages3(hQC.ScriptParameterSender, qc.ScriptParameterBuffer, QC_MAX_BUFFER_SIZE);
      if (result != QC_GET_MSG3_SUCCESS) {
         if      (result == QC_GET_MSG3_CHANNEL_EMPTY) catch("GetScriptParameters(5)->MT4iQuickChannel::QC_GetMessages3()   QC_CheckChannel not empty/QC_GET_MSG3_CHANNEL_EMPTY mismatch error", win32.GetLastError(ERR_WIN32_ERROR));
         else if (result == QC_GET_MSG3_INSUF_BUFFER ) catch("GetScriptParameters(6)->MT4iQuickChannel::QC_GetMessages3()   buffer to small (QC_MAX_BUFFER_SIZE/QC_GET_MSG3_INSUF_BUFFER mismatch)", win32.GetLastError(ERR_WIN32_ERROR));
         else                                          catch("GetScriptParameters(7)->MT4iQuickChannel::QC_GetMessages3()   unexpected return value = "+ result, win32.GetLastError(ERR_WIN32_ERROR));
      }
      else {
         parameters = qc.ScriptParameterBuffer[0];
      }
   }

   // stop sender
   if (!QC.StopScriptParameterSender())
      return(-1);
   if (IsLastError())
      return(-1);


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

   int hWnd = WindowHandle(Symbol(), NULL);
   if (!hWnd)
      return(!catch("QC.StartScriptParameterSender(1)->WindowHandle() = 0 in context "+ ModuleTypeDescription(__TYPE__) +"::"+ __whereamiDescription(__WHEREAMI__), ERR_RUNTIME_ERROR));

   qc.ScriptParameterChannel = "ScriptParameters.0x"+ IntToHexStr(hWnd);

   if (IsScript()) {
      // Der Channel muß bereits existieren, ohne können keine Parameter hinterlegt worden sein.
      int result = QC_CheckChannel(qc.ScriptParameterChannel);
      if (result < QC_CHECK_CHANNEL_EMPTY) {
         if (result == QC_CHECK_CHANNEL_NONE ) return(!catch("QC.StartScriptParameterSender(2)   you cannot manually call this script (channel \""+ qc.ScriptParameterChannel +"\" doesn't exist)", ERR_RUNTIME_ERROR));
         if (result == QC_CHECK_CHANNEL_ERROR) return(!catch("QC.StartScriptParameterSender(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\") => QC_CHECK_CHANNEL_ERROR", win32.GetLastError(ERR_WIN32_ERROR)));
                                               return(!catch("QC.StartScriptParameterSender(4)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\")   unexpected return value = "+ result, win32.GetLastError(ERR_WIN32_ERROR)));
      }
      // Messagebuffer initialisieren (Sender-Handle wird auch zum Lesen benutzt)
      if (!ArraySize(qc.ScriptParameterBuffer))
         InitializeStringBuffer(qc.ScriptParameterBuffer, QC_MAX_BUFFER_SIZE);
   }

   hQC.ScriptParameterSender = QC_StartSender(qc.ScriptParameterChannel);
   if (!hQC.ScriptParameterSender)
      return(!catch("QC.StartScriptParameterSender(5)->MT4iQuickChannel::QC_StartSender(channel=\""+ qc.ScriptParameterChannel +"\")", win32.GetLastError(ERR_WIN32_ERROR)));

   //debug("QC.StartScriptParameterSender()   sender started on \""+ qc.ScriptParameterChannel +"\"");
   return(true);
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
      return(!catch("QC.StopScriptParameterSender(1)->MT4iQuickChannel::QC_ReleaseSender(channel=\""+ channel +"\")   error stopping sender", win32.GetLastError(ERR_WIN32_ERROR)));

   //debug("QC.StopScriptParameterSender()   sender on \""+ channel +"\" stopped");
   return(true);


   // unnütze Compilerwarnungen unterdrücken
   string sNulls[];
   GetScriptParameters(sNulls, sNulls);
   RunScript(NULL, NULL);
   SetScriptParameters(NULL);
}
