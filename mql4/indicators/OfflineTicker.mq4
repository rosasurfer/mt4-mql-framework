/**
 * Installiert einen Timer, der einem synthetischen Chart fortwährend Chart-Refresh-Ticks schickt.
 */
#property indicator_chart_window
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <win32api.mqh>


#import "Expander.dll"
   int  SetupTickTimer(int hWnd, int millis, int flags);
   bool RemoveTickTimer(int timerId);
#import


int tickTimerId;


/**
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   if (!This.IsTesting() && GetServerName()=="MyFX-Synthetic") {
      // Ticker installieren
      int hWnd   = WindowHandleEx(NULL); if (!hWnd) return(last_error);
      int millis = 1000;
      int flags  = TICK_OFFLINE_REFRESH;

      int timerId = SetupTickTimer(hWnd, millis, flags);
      if (!timerId) return(catch("onInit(1)->SetupTickTimer(hWnd="+ hWnd +", millis="+ millis +", flags="+ flags +") failed", ERR_RUNTIME_ERROR));
      tickTimerId = timerId;

      // Chart-Markierung anzeigen
      string label = __NAME__+".Status";
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

   /*
   int rect[4];
   int hChart = WindowHandleEx(NULL); if (!hChart) return(last_error);
   int hDC    = GetDC(hChart);
   int region = GetClipBox(hDC, rect);
   ReleaseDC(hChart, hDC);

   if (region != NULLREGION)
      // Ticker aktivieren
   }
   else {
      // Ticker deaktivieren
   }

   string rgnCodes[] = {"RGN_ERROR", "NULLREGION", "SIMPLEREGION", "COMPLEXREGION"};
   debug("onTick()  Rgn(hChart)="+ rgnCodes[region]);
   */

   //debug("onTick()  Tick="+ Tick);

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