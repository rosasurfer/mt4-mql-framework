
string qc.ScriptParameterChannel;
string qc.ScriptParameterBuffer[];
int    hQC.ScriptParameterSender;


/**
 * Startet einen QuickChannel-Sender für Scriptparameter. Bei Aufruf aus einem Script muß der Channel bereits existieren, ohne können
 * keine Parameter übergeben worden sein.
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
      // Der Channel muß bereits existieren, ohne können keine Parameter existieren.
      int result = QC_CheckChannel(qc.ScriptParameterChannel);
      if (result < QC_CHECK_CHANNEL_EMPTY) {
         if (result == QC_CHECK_CHANNEL_NONE ) return(!catch("QC.StartScriptParameterSender(2)   you cannot manually call this script (channel \""+ qc.ScriptParameterChannel +"\" doesn't exist)", ERR_RUNTIME_ERROR));
         if (result == QC_CHECK_CHANNEL_ERROR) return(!catch("QC.StartScriptParameterSender(3)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\") = QC_CHECK_CHANNEL_ERROR", ERR_WIN32_ERROR));
                                               return(!catch("QC.StartScriptParameterSender(4)->MT4iQuickChannel::QC_CheckChannel(name=\""+ qc.ScriptParameterChannel +"\") unexpected return value = "+ result, ERR_WIN32_ERROR));
      }
      // Messagebuffer initialisieren (Sender-Handle wird auch zum Lesen benutzt)
      if (!ArraySize(qc.ScriptParameterBuffer))
         InitializeStringBuffer(qc.ScriptParameterBuffer, QC_MAX_BUFFER_SIZE);
   }

   hQC.ScriptParameterSender = QC_StartSender(qc.ScriptParameterChannel);
   if (!hQC.ScriptParameterSender)
      return(!catch("QC.StartScriptParameterSender(5)->MT4iQuickChannel::QC_StartSender(channel=\""+ qc.ScriptParameterChannel +"\")   error ="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));

   //debug("QC.StartScriptParameterSender()   sender started on \""+ qc.ScriptParameterChannel +"\"");
   return(true);
}


/**
 * Stoppt einen QuickChannel-Sender für Script-Parameter.
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
      return(!catch("QC.StopScriptParameterSender(1)->MT4iQuickChannel::QC_ReleaseSender(channel=\""+ channel +"\")   error stopping sender = "+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));

   //debug("QC.StopScriptParameterSender()   sender on \""+ channel +"\" stopped");
   return(true);
}
