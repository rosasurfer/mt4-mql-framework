/**
 * Config.mq4
 *
 * Lädt die globale und die lokale Konfigurationsdatei der laufenden Instanz in den Texteditor.
 */


#include <stdlib.mqh>
#include <win32api.mqh>


/**
 *
 */
int start() {
   // TODO: mit ShellExecute() implementieren

   string globalConfigFile = "\""+ TerminalPath() +"\\..\\metatrader-global-config.ini\"";
   string localConfigFile  = "\""+ TerminalPath() +"\\experts\\config\\metatrader-local-config.ini\"";

   string lpCmdLine = "notepad.exe "+ globalConfigFile +" "+ localConfigFile;      // um neue Instanz zu starten:  notepad.exe -m

   int error = WinExec(lpCmdLine, SW_SHOWNORMAL);
   if (error < 32)
      return(catch("start(1)  execution of \'"+ lpCmdLine +"\' failed, error: "+ error +" ("+ GetWindowsErrorDescription(error) +")", ERR_WINDOWS_ERROR));

   return(catch("start(2)"));
}