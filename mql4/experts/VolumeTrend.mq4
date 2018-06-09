/**
 * Volume Delta trend system
 *
 * Case study and playground for a trend following strategy combining Volume Delta and regular trend detection.
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

bool isOpenPosition;


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!isOpenPosition) CheckEntrySignal();
   else                 CheckExitSignal();
   return(last_error);
}


/**
 * Check for entry conditions.
 *
 * @return bool - success status (not if a signal occured)
 */
bool CheckEntrySignal() {
   return(true);
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
