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


//#include <test/testlibrary.mqh>
#include <test/teststatic.mqh>


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
      string maPeriods   = "3";
      string maTimeframe = "D1";
      string maMethod    = "ALMA";
      int    maTrendLag  = 0;

      int trend = icMovingAverage(timeframe, maPeriods, maTimeframe, maMethod, "Close", maTrendLag, MovingAverage.MODE_TREND_LAGGED, 1);
      if (trend==1 || trend==-1) {
         if (__LOG) log(StringConcatenate("onTick()   trend change ", ifString(trend > 0, "up  ", "down"), " ", TimeToStr(Tick.Time, TIME_FULL)));
      }
   }
   */


   /*
   bool st = true;               // static ...
   bool si = true;               // sized array declaration
   bool in = false;              // initializer

   //GlobalPrimitives(st, in);
   //LocalPrimitives (    in);

   //GlobalArrays(st, si, in);
   //LocalArrays (st, si, in);
   */
   return(last_error);
}


/**
 *
 * @return int - Fehlerstatus
 */
void DummyCalls() {
   GlobalPrimitives(NULL, NULL);
   LocalPrimitives(NULL);
   GlobalArrays(NULL, NULL, NULL);
   LocalArrays(NULL, NULL, NULL);
}
