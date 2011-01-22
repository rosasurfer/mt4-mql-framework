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
   string directory    = TerminalPath() +"\\experts\\files";
   string dataFile     = "\""+ directory +"\\"+ filename +"\"";
   string responseFile = "\""+ directory +"\\"+ filename +".response\"";
   string logFile      = "\""+ directory +"\\"+ filename +".log\"";
   //string lpCmdLine    = "wget.exe -b "+ url +" --post-file="+ dataFile +" --header=\"Content-Type: text/plain\" -O "+ responseFile +" -o "+ logFile;
   string cmdLine      = "wget.exe -b "+ url +" --header=\"Content-Type: text/plain\" -O "+ responseFile +" -o "+ logFile;

   WinExecAndWait(cmdLine, SW_HIDE);

   return(catch("test()"));
}
/*
SW_SHOW                           5  // Activates the window and displays it in its current size and position.
SW_SHOWNA                         8  // Displays the window in its current size and position. Similar to SW_SHOW, except that the window is not activated.
SW_HIDE                           0  // Hides the window and activates another window.

SW_SHOWMAXIMIZED                  3  // Activates the window and displays it as a maximized window.

SW_SHOWMINIMIZED                  2  // Activates the window and displays it as a minimized window.
SW_SHOWMINNOACTIVE                7  // Displays the window as a minimized window. Similar to SW_SHOWMINIMIZED, except the window is not activated.
SW_MINIMIZE                       6  // Minimizes the specified window and activates the next top-level window in the Z order.
SW_FORCEMINIMIZE                 11  // Minimizes a window, even if the thread that owns the window is not responding. This flag should only be used when
                                     // minimizing windows from a different thread.

SW_SHOWNORMAL                     1  // Activates and displays a window. If the window is minimized or maximized, Windows restores it to its original size and
SW_NORMAL             SW_SHOWNORMAL  // position. An application should specify this flag when displaying the window for the first time.
SW_SHOWNOACTIVATE                 4  // Displays a window in its most recent size and position. Similar to SW_SHOWNORMAL, except that the window is not activated.
SW_RESTORE                        9  // Activates and displays the window. If the window is minimized or maximized, Windows restores it to its original size and
                                     // position. An application should specify this flag when restoring a minimized window.

SW_SHOWDEFAULT                   10  // Sets the show state based on the SW_ flag specified in the STARTUPINFO structure passed to the CreateProcess() function by
                                     // the program that started the application.
*/


/**
 * Führt eine Anwendung aus und wartet, bis sie beendet ist.
 *
 * @param  string cmdLine - Befehlszeile
 * @param  int    cmdShow - ShowWindow() command id
 *
 * @return int - Fehlerstatus
 */
int WinExecAndWait(string cmdLine, int cmdShow) {
   int /*STARTUPINFO*/ si[17]; ArrayInitialize(si, 0);
      si.set.cb        (si, 68);
      si.set.Flags     (si, STARTF_USESHOWWINDOW);
      si.set.ShowWindow(si, cmdShow);
   int /*PROCESS_INFORMATION*/ pi[4]; ArrayInitialize(pi, 0);

   if (!CreateProcessA(NULL, cmdLine, NULL, NULL, false, 0, NULL, NULL, si, pi))
      return(catch("WinExecAndWait(1)   CreateProcess() failed", ERR_WINDOWS_ERROR));

   if (WaitForSingleObject(pi.hProcess(pi), INFINITE) == WAIT_FAILED)
      catch("WinExecAndWait(2)   WaitForSingleObject() failed", ERR_WINDOWS_ERROR);

   CloseHandle(pi.hProcess(pi));
   CloseHandle(pi.hThread(pi));

   return(catch("WinExecAndWait(3)"));
}