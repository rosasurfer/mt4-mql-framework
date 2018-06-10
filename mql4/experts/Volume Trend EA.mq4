/**
 * Volume trend system
 *
 * Case study and playground for a trend following strategy combining volume delta and regular trend detection.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern double Lotsize = 0.1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/EventListener.BarOpen.mqh>
#include <iCustom/icVolumeDelta.mqh>

bool isOpenPosition;


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!isOpenPosition) {
      if (EventListener.BarOpen()) {                              // current timeframe
         int signal = GetVolumeSignal(1);
         if (signal == 1) {
            debug("onTick(1)  "+ TimeToStr(TimeCurrent(), TIME_FULL) +"  Volume Delta turned up");
         }
         else if (signal == -1) {
            debug("onTick(2)  "+ TimeToStr(TimeCurrent(), TIME_FULL) +"  Volume Delta turned down");
         }
      }
   }
   else {
      CheckExitSignal();
   }
   return(last_error);
}


/**
 * Return a "Volume Delta" signal value.
 *
 * @param  int bar - bar index of the value to return
 *
 * @return double - signal value or NULL in case of errors
 */
double GetVolumeSignal(int bar) {
   int signalLevel = 17;
   return(icVolumeDelta(NULL, signalLevel, VolumeDelta.MODE_SIGNAL, bar));
}


/**
 * Check for exit conditions.
 *
 * @return bool - success status (not if a signal occured)
 */
bool CheckExitSignal() {
   return(true);
}


/**
 * Return a string representation of the input parameters (used for logging).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "Lotsize=", NumberToStr(Lotsize, ".1+"), "; ")
   );
}
