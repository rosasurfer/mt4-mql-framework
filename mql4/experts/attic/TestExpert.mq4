/**
 * TestExpert
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string sParameter = "dummy";
extern int    iParameter = 12345;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <structs/xtrade/ExecutionContext.mqh>


#import "Expander.dll"
#import


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   return(last_error);
}


/**
 * @return int - error status
 */
int onDeinit() {
   return(NO_ERROR);
}


/**
 * Return a string presentation of the input parameters.
 *
 * @return string
 */
string InputsToStr() {
   return(EMPTY_STR);
}
