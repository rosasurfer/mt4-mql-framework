/**
 * Startet den MetaEditor. Workaround für Terminals ab Build 509, die einen älteren MetaEditor nicht mehr starten.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/win32api.mqh>


/**
 * Main-Funktion
 *
 * @return int - error status
 */
int onStart() {
   string file = TerminalPath() +"/metaeditor.exe";
   if (!IsFile(file, MODE_SYSTEM)) return(catch("onStart(1)  file not found: "+ DoubleQuoteStr(file), ERR_FILE_NOT_FOUND));

   // WinExec() kehrt ohne zu warten zurück
   int result = WinExec(file, SW_SHOWNORMAL);
   if (result < 32) return(catch("onStart(2)->kernel32::WinExec(cmd="+ DoubleQuoteStr(file) +")  "+ ShellExecuteErrorDescription(result), ERR_WIN32_ERROR+result));

   return(catch("onStart(3)"));
}
