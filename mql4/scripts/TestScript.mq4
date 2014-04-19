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
 *
 * @return bool - Erfolgsstatus
 */
bool LoadScript(int hWnd, string scriptName) {
   if (!PostMessageA(hWnd, MT4InternalMsg(), MT4_LOAD_SCRIPT, GetStringAddress(scriptName)))
      return(!catch("LoadScript(1)->user32::PostMessageA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR));

   //int result = SendMessageA(hWnd, MT4InternalMsg(), MT4_LOAD_SCRIPT, GetStringAddress(scriptName));
   return(true);
}
