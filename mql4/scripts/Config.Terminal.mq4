/**
 * Config.mq4
 *
 * Lädt die Konfigurationsdateien der MetaTrader-Instanz in den Editor.
 */
#include <stdlib.mqh>
#include <win32api.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   //return(test());

   string files[2];
   files[0] = "\""+ TerminalPath() +"\\..\\metatrader-global-config.ini\"";
   files[1] = "\""+ TerminalPath() +"\\experts\\config\\metatrader-local-config.ini\"";

   for (int i=0; i < 2; i++) {
      int hInstance = ShellExecuteA(0, "open", files[i], "", "", SW_SHOWNORMAL);
      if (hInstance < 33)
         return(catch("start(1)  ShellExecute() failed to open "+ files[i] +",    error="+ hInstance +" ("+ ShellExecuteErrorToStr(hInstance) +")", ERR_WINDOWS_ERROR));
   }
   return(catch("start(2)"));
   return(test());
}


/**
 *
 */
int test() {
   string lpCommandLine = "calc.exe";
   int /*STARTUPINFO*/         si[17] = {68};
   int /*PROCESS_INFORMATION*/ pi[ 4];

   bool success = CreateProcessA(NULL,            // module name
                                 lpCommandLine,   // command line
                                 NULL,            // process attributes
                                 NULL,            // thread attributes
                                 false,           // handle inheritance
                                 0,               // creation flags
                                 NULL,            // environment block
                                 NULL,            // starting directory
                                 si,              // startup info
                                 pi               // process info
   );
   if (!success)
      return(catch("test(1)   CreateProcess() failed", ERR_WINDOWS_ERROR));

   CloseHandle(pi.hProcess(pi));
   CloseHandle(pi.hThread(pi));

   return(catch("test(2)"));
}