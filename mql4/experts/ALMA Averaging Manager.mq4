/**
 * ALMA Averaging Manager
 *
 *
 * EUR/USD:
 * --------
 *  - Einstieg mit dem Trend bei Trendwechsel ALMA(72xH1=3xD1) mit 1 Unit
 *  - Einstieg gegen den Trend bei Cross BollingerBand(75xH1) mit 1 Unit
 *  - Level 1:   1 Unit @    0 pip,  TP: L1 + 40 pip
 *  - Level 2:   1 Unit @  -40 pip,  TP: L1          (Money-Equivalent von 40 pip in L1)
 *  - Level 3: 2*1 Unit @ -100 pip,  TP: L1 - 50 pip (Money-Equivalent von 40 pip in L1)
 *  - SL: L1 - 150 pip
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/expert.mqh>

#include <Averaging/define.mqh>
#include <Averaging/functions.mqh>
#include <iCustom/icMovingAverage.mqh>


///////////////////////////////////////////////////////////////////// Konfiguration /////////////////////////////////////////////////////////////////////

extern double LotSize         = 0.1;                                 // LotSize der ersten Position
extern int    ProfitTarget    = 40;                                  // ProfitTarget der ersten Position in Pip
extern string StartConditions = "@trend(ALMA:3xD1)";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


bool   start.trend.condition;
string start.trend.condition.txt;
double start.trend.periods;
int    start.trend.timeframe, start.trend.timeframeFlag;             // maximal PERIOD_H1
string start.trend.method;

// -------------------------------------------------------
bool   start.price.condition;
string start.price.condition.txt;
double start.price.value;

// -------------------------------------------------------
int    trade.id            [1];
bool   trade.isTest        [1];
int    trade.direction     [1] = {-1};
double trade.lotSize       [1];
int    trade.profitTarget  [1];
string trade.startCondition[1];
int    trade.status        [1];


#include <Averaging/init.mqh>
#include <Averaging/deinit.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (trade.status[0] == STATUS_STOPPED)
      return(NO_ERROR);

   // (1) Trade wartet entweder auf Startsignal...
   if (trade.status[0] == STATUS_UNINITIALIZED) {
      if (IsStartSignal()) StartTrade();
   }

   // (2) ...oder läuft
   else if (UpdateStatus()) {
      if (IsStopSignal())  StopTrade();
   }

   // (3) Equity-Kurve aufzeichnen
   if (trade.status[0] != STATUS_UNINITIALIZED) {
      RecordEquity();
   }

   return(last_error);
}


/**
 * Signalgeber für StartTrade().
 *
 * @return bool - ob ein Signal aufgetreten ist
 */
bool IsStartSignal() {
   if (__STATUS_ERROR)
      return(false);

   int iNull[];
   if (EventListener.BarOpen(iNull, start.trend.timeframeFlag)) {    // Prüfung nur bei onBarOpen, nicht bei jedem Tick
      int    timeframe   = start.trend.timeframe;
      string maPeriods   = NumberToStr(start.trend.periods, ".+");
      string maTimeframe = PeriodDescription(start.trend.timeframe);
      string maMethod    = start.trend.method;

      int trend = icMovingAverage(timeframe, maPeriods, maTimeframe, maMethod, "Close", MovingAverage.MODE_TREND, 1);
      if (!trend) {
         int error = stdlib.GetLastError();
         if (IsError(error))
            SetLastError(error);
         return(false);
      }

      bool signal;
      if      (trade.direction[0] == D_LONG ) signal = (trend== 1);
      else if (trade.direction[0] == D_SHORT) signal = (trend==-1);
      else                                    signal = (trend== 1 || trend==-1);

      if (signal) {
         if (__LOG) log(StringConcatenate("IsStartSignal(1)   start signal \"", start.trend.condition.txt, "\" ", ifString(trend > 0, "up", "down")));
                  debug(StringConcatenate("IsStartSignal(2)   start signal \"", start.trend.condition.txt, "\" ", ifString(trend > 0, "up", "down")));
         return(true);
      }
   }
   return(false);
}


/**
 * Signalgeber für StopTrade()
 *
 * @return bool - ob ein Signal aufgetreten ist
 */
bool IsStopSignal() {
   if (__STATUS_ERROR)
      return(false);
   return(false);
}


/**
 * Startet einen neuen Trade.
 *
 * @return bool - Erfolgsstatus
 */
bool StartTrade() {
   if (__STATUS_ERROR)
      return(false);
   return(!__STATUS_ERROR);
}


/**
 * Stoppt den aktuellen Trade.
 *
 * @return bool - Erfolgsstatus
 */
bool StopTrade() {
   if (__STATUS_ERROR)
      return(false);
   return(!__STATUS_ERROR);
}


/**
 * Prüft und synchronisiert die im EA gespeicherten mit den aktuellen Laufzeitdaten.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateStatus() {
   if (__STATUS_ERROR)
      return(false);
   return(!__STATUS_ERROR);
}


/**
 * Zeichnet die Equity-Kurve des Trades auf.
 *
 * @return bool - Erfolgsstatus
 */
bool RecordEquity() {
   if (__STATUS_ERROR)
      return(false);
   return(!__STATUS_ERROR);
}
