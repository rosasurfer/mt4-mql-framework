/**
 * Startet den MetaEditor. Workaround für Terminals ab Build 509, die einen älteren MetaEditor nicht mehr starten.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <win32api.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   string file = TerminalPath() +"\\metaeditor.exe";
   if (!IsFileA(file))
      return(HandleScriptError("", "File not found: "+ DoubleQuoteStr(file), ERR_RUNTIME_ERROR));


   // WinExec() kehrt ohne zu warten zurück
   int result = WinExec(file, SW_SHOWNORMAL);
   if (result < 32)
      return(catch("onStart(1)->kernel32::WinExec(cmd="+ DoubleQuoteStr(file) +")  "+ ShellExecuteErrorDescription(result), ERR_WIN32_ERROR+result));

   return(catch("onStart(2)"));
}
