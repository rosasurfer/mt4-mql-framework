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
   string commandLine = "notepad.exe -m";
   int /*STARTUPINFO*/         si[17] = {68};
   int /*PROCESS_INFORMATION*/ pi[ 4];

   Print("test()   si = "+ StructToHexStr(si));
   Print("test()   si.Flags = "+ si.FlagsToStr(si) +"     si.ShowWindow = "+ si.ShowWindowToStr(si));

   return(catch("test(2)"));

   if (!CreateProcessA(NULL, commandLine, NULL, NULL, false, 0, NULL, NULL, si, pi))
      return(catch("test(1)   CreateProcess() failed", ERR_WINDOWS_ERROR));

   CloseHandle(pi.hProcess(pi));
   CloseHandle(pi.hThread(pi));

   return(catch("test(2)"));
}
