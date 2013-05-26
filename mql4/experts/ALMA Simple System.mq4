/**
 * Simple ALMA Trendchange Strategy (max. eine Position fester Größe mit fixem TP/SL).
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/expert.mqh>


///////////////////////////////////////////////////////////////////// Konfiguration /////////////////////////////////////////////////////////////////////

extern double LotSize      = 0.1;
extern int    TakeProfit   = 30;
extern int    StopLoss     = 30;
extern int    MA.Periods   = 25;
extern int    MA.Timeframe = PERIOD_H1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


//#include <iCustom/icMovingAverage.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {




   /*
   int iNull[];
   if (EventListener.BarOpen(iNull, F_PERIOD_H1)) {
      int    timeframe   = PERIOD_H1;
      string maPeriods   = MA.Periods;
      string maTimeframe = PeriodDescription(MA.Timeframe);
      string maMethod    = "ALMA";

      int trend = icMovingAverage(timeframe, maPeriods, maTimeframe, maMethod, "Close", MovingAverage.MODE_TREND, 1);
      if (trend==1 || trend==-1) {
         if (__LOG) log(StringConcatenate("onTick()   trend change ", ifString(trend > 0, "up  ", "down"), " ", TimeToStr(Tick.Time, TIME_FULL)));
      }
   }
   */
   return(last_error);
}
