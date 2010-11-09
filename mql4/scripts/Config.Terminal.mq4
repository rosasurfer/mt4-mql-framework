/**
 * Config.mq4
 *
 * Lädt die globale und die lokale Konfigurationsdatei der laufenden Instanz in die Defaultanwendung (Editor).
 */
#include <stdlib.mqh>
#include <win32api.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   string files[2];

   files[0] = "\""+ TerminalPath() +"\\..\\metatrader-global-config.ini\"";
   files[1] = "\""+ TerminalPath() +"\\experts\\config\\metatrader-local-config.ini\"";

   for (int i=0; i < 2; i++) {
      int hInstance = ShellExecuteA(0, "open", files[i], "", "", SW_SHOWNORMAL);
      if (hInstance < 32)
         return(catch("start(1)  ShellExecuteA() failed to open "+ files[i] +",    error="+ hInstance +" ("+ GetWindowsErrorDescription(hInstance) +")", ERR_WINDOWS_ERROR));
   }

   return(catch("start(2)"));
}
