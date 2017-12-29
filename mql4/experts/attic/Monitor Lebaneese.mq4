/**
 * Monitor the market for a Lebaneese signal and execute a trade command.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern double Lotsize = 0.1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   return(last_error);
}


/**
 * Return a string representation of the input parameters (for logging).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "Lotsize=", NumberToStr(Lotsize, ".1+"), "; ")
   );
}
