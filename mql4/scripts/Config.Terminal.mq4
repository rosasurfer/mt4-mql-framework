
#include <stdlib.mqh>
#include <win32api.mqh>


//#property show_inputs


/**
 *
 */
int start() {
   string configFile = "\""+ GetMetaTraderDirectory() +"\\experts\\config\\Config.ini\"";
   string lpCmdLine = "notepad.exe "+ configFile;              // um neue Instanz zu starten:  notepad.exe -m

   int error = WinExec(lpCmdLine, SW_SHOWNORMAL);
   if (error < 32)
      return(catch("start(1)  execution of command \'"+ lpCmdLine +"\' failed, error: "+ error +" ("+ GetWindowsErrorDescription(error) +")", ERR_WINDOWS_ERROR));

   return(catch("start(2)"));
}