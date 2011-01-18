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
   string filename = "wget";

   string url          = "\"http://sub.domain.tld/uploadAccountHistory.php\"";
   string targetDir    = TerminalPath() +"\\experts\\files";
   string dataFile     = "\""+ targetDir +"\\"+ filename +"\"";
   string responseFile = "\""+ targetDir +"\\"+ filename +".response\"";
   string logFile      = "\""+ targetDir +"\\"+ filename +".log\"";
   //string lpCmdLine    = "wget.exe -b "+ url +" --post-file="+ dataFile +" --header=\"Content-Type: text/plain\" -O "+ responseFile +" -o "+ logFile;
   string cmdLine      = "wget.exe -b "+ url +" --header=\"Content-Type: text/plain\" -O "+ responseFile +" -o "+ logFile;


   int /*STARTUPINFO*/ si[17]; ArrayInitialize(si, 0);
      si.set.cb        (si, 68);
      si.set.Flags     (si, STARTF_USESHOWWINDOW);
      si.set.ShowWindow(si, SW_HIDE);

   int /*PROCESS_INFORMATION*/ pi[4]; ArrayInitialize(pi, 0);

   if (!CreateProcessA(NULL, cmdLine, NULL, NULL, false, 0, NULL, NULL, si, pi))
      return(catch("test(1)   CreateProcess() failed", ERR_WINDOWS_ERROR));

   if (WaitForSingleObject(pi.hProcess(pi), INFINITE) == WAIT_FAILED)
      catch("test(2)   WaitForSingleObject() failed", ERR_WINDOWS_ERROR);

   CloseHandle(pi.hProcess(pi));
   CloseHandle(pi.hThread(pi));

   return(catch("test(3)"));
}

   /*
   SW_HIDE
   SW_SHOWNORMAL
   SW_SHOWMINIMIZED
   SW_SHOWMAXIMIZED
   SW_SHOWNOACTIVATE
   SW_SHOW
   SW_MINIMIZE
   SW_SHOWMINNOACTIVE
   SW_SHOWNA
   SW_RESTORE
   SW_SHOWDEFAULT
   SW_FORCEMINIMIZE
   */
