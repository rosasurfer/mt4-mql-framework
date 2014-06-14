/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>
#include <win32api.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   string exec="cal.exe", args="", cmdLine=exec +" "+ args;

   int result = WinExec(cmdLine, SW_HIDE);                           // SW_SHOWNORMAL|SW_HIDE
   if (result < 32)
      return(!catch("onStart(1)->kernel32::WinExec(exec=\""+ exec +"\")   "+ ShellExecuteErrorDescription(result), ifInt(!result, ERR_RUNTIME_ERROR, ERR_WIN32_ERROR+result)));

   // TODO: Prüfen, ob wget.exe im Pfad gefunden werden kann:  =>  error=2 [File not found]

   return(last_error);
}
