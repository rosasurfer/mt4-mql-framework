/**
 * TestExpert
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/expert.mqh>


///////////////////////////////////////////////////////////////////// Konfiguration /////////////////////////////////////////////////////////////////////

extern string sParameter = "dummy";
extern int    iParameter = 12345;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {

   int iNull[];
   if (EventListener.BarOpen(iNull, F_PERIOD_H1)) {
      int    timeframe   = PERIOD_H1;
      string maPeriods   = "25";
      string maTimeframe = "H1";
      string maMethod    = "ALMA";

      int trend = icMovingAverage(timeframe, maPeriods, maTimeframe, maMethod, "Close", MovingAverage.MODE_TREND, 1);
      if (trend==1 || trend==-1) {
         if (__LOG) log(StringConcatenate("onTick()   trend change ", ifString(trend > 0, "up  ", "down"), " ", TimeToStr(Tick.Time, TIME_FULL)));
      }
   }

   return(last_error);
}
