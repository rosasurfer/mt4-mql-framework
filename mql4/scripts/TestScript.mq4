/**
 * TestScript
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/script.mqh>
#include <win32api.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   debug("onStart(1) running, hWnd=0x"+ IntToHexStr(WindowHandle(Symbol(), NULL)));

   if (Symbol() != "AUDUSD") {
      LoadScript(WindowHandle("AUDUSD", NULL), "LFX.OpenPosition");
   }

   if (Symbol() == "AUDUSD") {
      Comment(NL, __NAME__, ":  ", TimeToStr(TimeLocal(), TIME_FULL));
   }

   return(last_error);
}


/**
 * Schickt dem Fenster mit dem angegebenen Handle eine Nachricht, das angegebene Script zu laden. Die Funktion prüft weder, ob das Script
 * tatsächlich existiert noch, ob es erfolgreich geladen wurde.
 *
 * @param  int    hWnd       - Fenster-Handle
 * @param  string scriptName - Name des zu ladenden Scriptes
 *
 * @return bool - ob die Nachricht erfolgreich verschickt wurde
 */
bool LoadScript(int hWnd, string scriptName) {
   // Vorsicht im Kontext des Aufrufs: der ermittelte Pointer muß zur Zeit der Message-Verarbeitung noch gültig sein
   if (!PostMessageA(hWnd, MT4InternalMsg(), MT4_LOAD_SCRIPT, GetStringAddress(scriptName)))
      return(!catch("LoadScript(1)->user32::PostMessageA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));

   //int result = SendMessageA(hWnd, MT4InternalMsg(), MT4_LOAD_SCRIPT, GetStringAddress(scriptName));
   return(true);
}
