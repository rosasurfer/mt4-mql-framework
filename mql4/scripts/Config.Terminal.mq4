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
   /*
   string lpCommandLine = "calc.exe";

   int lpProcessAttributes[3] = {12, 0, 0};
   int lpThreadAttributes [3] = {12, 0, 0};
   int lpEnvironment[1]; lpEnvironment[0] = GetEnvironmentStringsA();

   int lpStartupInfo[17]; lpStartupInfo[0] = 68;
   int lpProcessInformation[4];

   int result = CreateProcessA("",                       // NULL: no module name (use command line)
                               lpCommandLine,            // command line
                               lpProcessAttributes,      // process attributes
                               lpThreadAttributes,       // thread attributes
                               false,                    // set handle inheritance to FALSE
                               0,                        // no special creation flags
                               lpEnvironment,            // environment block
                               "",                       // NULL: use parent's starting directory
                               lpStartupInfo,
                               lpProcessInformation
   );

   if (result == 0) {
      int error = GetLastError();
      if (error == ERR_NO_ERROR)
         error = ERR_WINDOWS_ERROR;
      return(catch("start(0)   CreateProcess() failed", error));
   }
   Print("start()   CreateProcess() success,   result="+ result);
   return(catch("start(1)"));
   */

   string files[2];
   files[0] = "\""+ TerminalPath() +"\\..\\metatrader-global-config.ini\"";
   files[1] = "\""+ TerminalPath() +"\\experts\\config\\metatrader-local-config.ini\"";

   for (int i=0; i < 2; i++) {
      int hInstance = ShellExecuteA(0, "open", files[i], "", "", SW_SHOWNORMAL);
      if (hInstance < 32)
         return(catch("start(1)  ShellExecuteA() failed to open "+ files[i] +",    error="+ hInstance +" ("+ WindowsErrorToStr(hInstance) +")", ERR_WINDOWS_ERROR));
   }

   return(catch("start(2)"));
}
