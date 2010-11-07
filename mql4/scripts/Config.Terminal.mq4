/**
 * Config.mq4
 *
 * Lädt die globale und die lokale Konfigurationsdatei der laufenden Instanz in den Texteditor.
 */


#include <stdlib.mqh>
#include <win32api.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   string globalConfigFile = "\""+ TerminalPath() +"\\..\\metatrader-global-config.ini\"";
   string localConfigFile  = "\""+ TerminalPath() +"\\experts\\config\\metatrader-local-config.ini\"";

   string file = globalConfigFile;

   int hInstance = ShellExecuteA(0, "open", file, "", "", SW_SHOWNORMAL);
   if (hInstance < 32)
      return(catch("start(1)  ShellExecuteA() failed to open "+ file +",    error="+ hInstance +" ("+ GetWindowsErrorDescription(hInstance) +")", ERR_WINDOWS_ERROR));

   file = localConfigFile;
   
   hInstance = ShellExecuteA(0, "open", file, "", "", SW_SHOWNORMAL);
   if (hInstance < 32)
      return(catch("start(2)  ShellExecuteA() failed to open "+ file +",    error="+ hInstance +" ("+ GetWindowsErrorDescription(hInstance) +")", ERR_WINDOWS_ERROR));

   return(catch("start(3)"));
}