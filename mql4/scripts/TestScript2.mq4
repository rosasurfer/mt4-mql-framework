/**
 * TestScript2
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_DOESNT_REQUIRE_BARS };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <history.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   string sender   = "***REMOVED***";
   string receiver = "***REMOVED***";
   string subject  = "squote:' dquote:\" pipe:| halleluhjah";
   string message  = subject;
   string headers[];

   SendEmail(sender, receiver, subject, message, headers);
   return(last_error);
}


#include <win32api.mqh>


/**
 * Verschickt eine E-Mail.
 *
 * @param  string sender    - E-Mailadresse des Senders    (default: der in der Terminal-Konfiguration angegebene Standard-Sender)
 * @param  string receiver  - E-Mailadresse des Empfängers (default: der in der Terminal-Konfiguration angegebene Standard-Empfänger)
 * @param  string subject   - Subject der E-Mail
 * @param  string message   - Text der E-Mail
 * @param  string headers[] - zusätzliche Mail-Header (default: keine)
 *
 * @return bool - Erfolgsstatus: TRUE, wenn die E-Mail zum Versand akzeptiert wurde (nicht, ob sie versendet wurde)
 *                               FALSE andererseits
 */
bool SendEmail(string sender, string receiver, string subject, string message, string headers[]) {
   string mqlDir   = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string filesDir = TerminalPath() + mqlDir +"\\files\\";


   // (1) Validierung
   // Sender
   string _sender = StringTrim(sender);
   if (!StringLen(_sender)) {
      string section = "Mail";
      string key     = "Sender";
      _sender = GetConfigString(section, key);
      if (!StringLen(_sender))                return(!catch("SendEmail(1)  missing global/local configuration ["+ section +"]->"+ key,                                 ERR_INVALID_CONFIG_PARAMVALUE));
      if (!StringIsEmailAddress(_sender))     return(!catch("SendEmail(2)  invalid global/local configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(_sender), ERR_INVALID_CONFIG_PARAMVALUE));
   }
   else if (!StringIsEmailAddress(_sender))   return(!catch("SendEmail(3)  invalid parameter sender = "+ DoubleQuoteStr(sender), ERR_INVALID_PARAMETER));
   sender = _sender;

   // Receiver
   string _receiver = StringTrim(receiver);
   if (!StringLen(_receiver)) {
      section   = "Mail";
      key       = "Receiver";
      _receiver = GetConfigString(section, key);
      if (!StringLen(_receiver))              return(!catch("SendEmail(4)  missing global/local configuration ["+ section +"]->"+ key,                                   ERR_INVALID_CONFIG_PARAMVALUE));
      if (!StringIsEmailAddress(_receiver))   return(!catch("SendEmail(5)  invalid global/local configuration ["+ section +"]->"+ key +" = "+ DoubleQuoteStr(_receiver), ERR_INVALID_CONFIG_PARAMVALUE));
   }
   else if (!StringIsEmailAddress(_receiver)) return(!catch("SendEmail(6)  invalid parameter receiver = "+ DoubleQuoteStr(receiver), ERR_INVALID_PARAMETER));
   receiver = _receiver;

   // Subject
   string _subject = StringTrim(subject);
   if (!StringLen(_subject))                  return(!catch("SendEmail(7)  invalid parameter subject = "+ DoubleQuoteStr(subject), ERR_INVALID_PARAMETER));
   _subject = StringReplace(StringReplace(StringReplace(_subject, "\r\n", "\n"), "\r", " "), "\n", " "); // Linebreaks in Leerzeichen umwandeln
   _subject = StringReplace(_subject, "\"", "\\\"");                                                     // Double-Quotes für email escapen
   _subject = StringReplace(_subject, "'", "'\"'\"'");                                                   // Single-Quotes für bash escapen
   // drive:\path\to\bash.exe -lc 'email -s "squote:'"'"' dquote:\" pipe:|" ...'

   // Message (kann leer sein)
   string _message = StringTrim(message), message.file;
   if (StringLen(_message) > 0) {
      // temporäre Datei erzeugen und Mailbody speichern
      message.file = CreateTempFile(filesDir);
      int hFile    = FileOpen(StringRightFrom(message.file, filesDir), FILE_BIN|FILE_WRITE);
      if (hFile < 0) return(!catch("SendEmail(9)->FileOpen()"));

      int bytes = FileWriteString(hFile, _message, StringLen(_message));
      FileClose(hFile);
      if (bytes <= 0) return(!catch("SendEmail(10)->FileWriteString() => "+ bytes +" written"));
   }

   // Headers: noch nicht unterstützt


   // (2) Mailclient ermitteln und auf Existenz prüfen
   section         = "Mail";
   key             = "Sendmail";
   string sendmail = GetConfigString(section, key);
   if (!StringLen(sendmail)) {
      // kein Mailclient angegeben: Umgebungsvariable $SENDMAIL auswerten
      // sendmail suchen
   }
   // Mailclient auf Existenz prüfen
   //if (!IsFile(sendmail)) return(!catch("SendEmail(10)  mail client not found: "+ DoubleQuoteStr(sendmail), ERR_FILE_NOT_FOUND));
   // (2.1) absoluter Pfad
   // (2.2) relativer Pfad: Systemverzeichnisse durchsuchen; Variable $PATH durchsuchen


   // (3) Befehlszeile für Shellaufruf zusammensetzen
   //
   // cmd.exe:
   // --------
   //  • Redirection in der Befehlszeile ist ein Feature der Shell (funktioniert nur mit z.B. "cmd.exe /c ...").
   //  • Redirection mit WinExec() ist einfacher zu implementieren als mit CreateProcess(), jedoch beschränkt.
   //  • Redirection von Output mit Zeilenumbrüchen funktioniert mit cmd.exe nicht. Fehler: cmd /c echo hello \n world | program
   //  • Escape-Character für cmd-Sonderzeichen außerhalb von Quoted-Strings: ^
   //  • Die ausführbare Datei wird von WinExec() u.U. nicht erkannt, wenn die Datei ein Symlink auf eine andere ausführbare Datei ist.
   //  • Die ausführbare Datei darf u.U. nicht in doppelte Anführungszeichen eingeschlossen sein.
   //  • Bei Verwendung der Shell als ausführendem Programm steht der Exit-Code nicht zur Verfügung.
   //  • Bei Verwendung von CreateProcess() muß der Versand synchron (d.h. blockierend) oder in einem eigenen Thread erfolgen.
   //
   // Cleancode.email:
   // ----------------
   //  • unterstützt keine Exit-Codes
   //  • validiert die übergebenen Adressen nicht
   //
   string mail.log = filesDir +"mail.errors";
   string cmdLine;
   if (!StringLen(_message)) cmdLine = sendmail +" -subject \""+ _subject +"\" -blank-mail -from-addr \""+ sender +"\" \""+ receiver +"\" "                      +">> \""+ mail.log +"\" 2>&1";
   else                      cmdLine = sendmail +" -subject \""+ _subject             +"\" -from-addr \""+ sender +"\" \""+ receiver +"\" < \""+ message.file +"\" >> \""+ mail.log +"\" 2>&1";
   cmdLine = "drive:\path\to\bash.exe -lc '"+ cmdLine +"'";
   //log("SendEmail(11)  cmdLine="+ DoubleQuoteStr(cmdLine));


   // (4) Shellaufruf
   int result = WinExec(cmdLine, SW_HIDE);   // SW_SHOW | SW_HIDE
   if (result < 32) return(!catch("SendEmail(12)->kernel32::WinExec(cmdLine="+ DoubleQuoteStr(cmdLine) +")  "+ ShellExecuteErrorDescription(result), ERR_WIN32_ERROR+result));

   log("SendEmail(13)  Mail to "+ receiver +" transmitted: \""+ subject +"\"");
   return(!catch("SendEmail(14)"));
}


/**
 * Erzeugt eine eindeutige temporäre Datei im angegebenen Verzeichnis.
 *
 * @param  string path   - Name des Verzeichnisses, in dem die Datei erzeugt wird (default: aktuelles Verzeichnis)
 * @param  string prefix - Prefix des Namens der zu erzeugenden Datei (die ersten 3 Zeichen werden verwendet)
 *
 * @return string - Dateiname oder Leerstring, falls ein Fehler auftrat
 */
string CreateTempFile(string path=".", string prefix="mql") {
   int    bufferSize = MAX_PATH;
   string buffer[]; InitializeStringBuffer(buffer, bufferSize);

   int id = GetTempFileNameA(path, prefix, 0, buffer[0]);
   if (!id) return(_EMPTY_STR(catch("GetTempFileName(1)->kernel32::GetTempFileNameA() => 0", ERR_WIN32_ERROR)));

   string tmpFile = buffer[0];
   ArrayResize(buffer, 0);
   return(tmpFile);
}
