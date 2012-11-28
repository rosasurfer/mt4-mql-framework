/**
 * Multi-Color/Multi-Timeframe Moving Average
 */
#include <core/define.mqh>
#define     __TYPE__   T_INDICATOR
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stddefine.mqh>
#include <stdlib.mqh>

#include <core/indicator.mqh>


#property indicator_chart_window

#property indicator_buffers 3

#property indicator_width1  2
#property indicator_width2  2
#property indicator_width3  2


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern int    MA.Periods        = 200;                // averaging period
extern string MA.Timeframe      = "";                 // averaging timeframe [M1 | M5 | M15] etc. ("" = aktueller Timeframe)

extern string AppliedPrice      = "Close";            // price used for MA calculation
extern string AppliedPrice.Help = "Open | High | Low | Close | Median | Typical | Weighted";
extern double PctReversalFilter = 0.0;                // minimum percentage MA change to indicate a trend change
extern int    Max.Values        = 2000;               // maximum number of indicator values to display: -1 = all

extern color  Color.UpTrend     = DodgerBlue;         // Farben werden hier konfiguriert, damit der Code zur Laufzeit Zugriff hat
extern color  Color.DownTrend   = Orange;
extern color  Color.Reversal    = Yellow;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double bufferMA       [];                             // Datenanzeige im "Data Window" (unsichtbar: IndexStyle = DRAW_NONE|CLR_NONE)
double bufferUpTrend  [];                             // UpTrend-Linie                 (sichtbar)
double bufferDownTrend[];                             // DownTrendTrend-Linie          (sichtbar)


/**
 * Kein UninitializeReason gesetzt: altes oder neues Chartfenster, Template mit Indikator, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 */
int onInitUndefined() {
   return(NO_ERROR);
}


/**
 * Parameter-Wechsel: altes Chartfenster, alter oder neuer Indikator, Input-Dialog
 *
 * @return int - Fehlerstatus
 */
int onInitParameterChange() {
   return(NO_ERROR);
}


/**
 * Symbol- oder Timeframe-Wechsel: altes Chartfenster, alter Indikator, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 */
int onInitChartChange() {
   return(NO_ERROR);
}


/**
 * Recompilation: altes Chartfenster, alter Indikator, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 */
int onInitRecompile() {
   return(NO_ERROR);
}


// --------------------------------------------------------------------------------------------------------------------


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   return(catch("onTick()"));
}
