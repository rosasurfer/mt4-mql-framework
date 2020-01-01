/**
 * Installiert einen Timer, der einem synthetischen Chart fortwährend Chart-Refresh-Ticks schickt.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <win32api.mqh>

#property indicator_chart_window


int tickTimerId;


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   if (!This.IsTesting()) /*&&*/ if (StrCompareI(GetServerName(), "XTrade-Synthetic")) {
      // Ticker installieren
      int hWnd   = __ExecutionContext[EC.hChart];
      int millis = 1000;
      int flags  = TICK_CHART_REFRESH;

      int timerId = SetupTickTimer(hWnd, millis, flags);
      if (!timerId) return(catch("onInit(1)->SetupTickTimer(hWnd="+ hWnd +", millis="+ millis +", flags="+ flags +") failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;

      // Chart-Markierung anzeigen
      string label = __NAME() +".Status";
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet    (label, OBJPROP_XDISTANCE, 38);
         ObjectSet    (label, OBJPROP_YDISTANCE, 38);
         ObjectSetText(label, "n", 6, "Webdings", LimeGreen);        // Webdings: runder "Online"-Marker
         ObjectRegister(label);
      }
   }

   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   // Ticker ggf. deinstallieren
   if (tickTimerId > NULL) {
      int id = tickTimerId; tickTimerId = NULL;
      if (!RemoveTickTimer(id))  return(catch("onDeinit(1)->RemoveTickTimer(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
   }

   DeleteRegisteredObjects(NULL);
   return(last_error);
}
